open! Core
open Hardcaml
open Hardcaml_lws
open Protocol_emulator
open Manchester_line
module Harness = Hardcaml_test_harness.Lws_harness.Make (Frame_rx.I) (Frame_rx.O)

let ( <--. ) = Bits.( <--. )

module Result = struct
  type t =
    { writes : (int * int) list
    ; words : int
    ; finished : bool
    ; fcs_ok : bool
    ; half : bool
    ; dropped : bool
    }
  [@@deriving sexp_of]
end

(* Arms the receiver at [base], then plays [lines], each a frame's samples, with
   [may_write] asked every cycle; [rearm] arms it again before a line. *)
let receive ?(rearm = fun _ -> false) ~fifty ~base ~may_write lines =
  Harness.run
    ~random_initial_state:`All
    ~create:Frame_rx.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let cycle () = Lws.step h in
       let o = Before_and_after_edge.after_edge outputs in
       (* what the edge just took *)
       let taken = (Before_and_after_edge.before_edge outputs).write in
       let flag r = Bits.to_bool !r in
       inputs.clocking.clear := Bits.vdd;
       cycle ();
       inputs.clocking.clear := Bits.gnd;
       inputs.control.base <--. base;
       inputs.control.fifty := Bits.of_bool fifty;
       let arm () =
         inputs.control.arm := Bits.vdd;
         cycle ();
         inputs.control.arm := Bits.gnd
       in
       arm ();
       let writes = ref [] in
       let n = ref 0 in
       let lines = Array.of_list (List.map lines ~f:Array.of_list) in
       for line = 0 to Array.length lines - 1 do
         if line > 0 && rearm line then arm ();
         for k = 0 to Array.length lines.(line) - 1 do
           inputs.rd := Bits.of_bit_list (List.rev lines.(line).(k));
           inputs.may_write := Bits.of_bool (may_write !n);
           Int.incr n;
           cycle ();
           if flag taken.valid
           then
             writes
             := (Bits.to_unsigned_int !(taken.addr), Bits.to_unsigned_int !(taken.data))
                :: !writes
         done
       done;
       let s = o.status in
       { Result.writes = List.rev !writes
       ; words = Bits.to_unsigned_int !(s.words)
       ; finished = flag s.finished
       ; fcs_ok = flag s.fcs_ok
       ; half = flag s.half
       ; dropped = flag s.dropped
       })
;;

let per_bit ~fifty = if fifty then 10 else 8

let line ~random ~fifty ~ppm ~jitter frame =
  transitions ~random ~ppm ~jitter (bits_of_bytes (preamble @ frame))
  |> sample ~random ~per_bit:(per_bit ~fifty) ~per_cycle:2
;;

let%expect_test "the FCS of a known frame, against zlib's check value" =
  let check = crc32 (String.to_list "123456789" |> List.map ~f:Char.to_int) in
  let residue =
    List.fold
      (bits_of_bytes (with_fcs [ 1; 2; 3 ]))
      ~init:0xffffffff
      ~f:(fun crc bit -> Crc.step ~width:32 ~poly:Frame_rx.poly ~reflect:true crc ~bit)
  in
  print_s [%message (check : Int.Hex.t) (residue : Int.Hex.t)];
  [%expect {| ((check 0xcbf43926) (residue 0xdebb20e3)) |}]
;;

(* Random frames at either clock, up to 10 ns of jitter on every edge and the sender 100
   ppm off, some with a byte spoilt, some landing near the memory's end, some with the
   memory busy now and then: every word lands where it should or is counted as dropped,
   and the FCS verdict is right. *)
let%expect_test "frames land in the data memory with their FCS judged" =
  let tally = Hashtbl.create (module String) in
  let count name = Hashtbl.incr tally name in
  Quickcheck.test
    ~trials:120
    (let open Quickcheck.Generator.Let_syntax in
     let%bind payload = List.gen_with_length 1 (Int.gen_incl 0 255) in
     let%bind more = List.gen_non_empty (Int.gen_incl 0 255) in
     let%bind spoil = Int.gen_incl 0 3 in
     let%bind fifty = Bool.quickcheck_generator in
     let%bind jitter = Float.gen_incl 0. 10. in
     let%bind ppm = Float.gen_incl (-100.) 100. in
     let%bind near_end = Int.gen_incl 0 4 in
     let%bind busy = Int.gen_incl 0 3 in
     let%map seed = Int.gen_incl 0 1_000_000 in
     ( List.take (payload @ more) 40
     , spoil = 0
     , fifty
     , jitter
     , ppm
     , near_end = 0
     , busy = 0
     , seed ))
    ~f:(fun (payload, spoil, fifty, jitter, ppm, near_end, busy, seed) ->
      let random = Random.State.make [| seed |] in
      let frame = with_fcs payload in
      let frame =
        if spoil
        then List.mapi frame ~f:(fun n b -> if n = 0 then b lxor 0x10 else b)
        else frame
      in
      let words = Manchester_line.words frame in
      let base =
        if near_end
        then (1 lsl Isa.data_addr_bits) - (List.length words / 2)
        else Random.State.int random 256
      in
      let may_write _ = (not busy) || Random.State.int random 8 > 0 in
      let r =
        receive ~fifty ~base ~may_write [ line ~random ~fifty ~ppm ~jitter frame ]
      in
      let landed =
        List.for_all r.writes ~f:(fun (addr, word) ->
          addr >= base && [%equal: int option] (List.nth words (addr - base)) (Some word))
      in
      let all_landed = List.length r.writes = List.length words in
      let ok =
        landed
        && r.finished
        && r.words = List.length words
        && Bool.equal r.fcs_ok (not spoil)
        && Bool.equal r.half (List.length frame % 2 = 1)
        && Bool.equal r.dropped (not all_landed)
      in
      if not ok
      then
        raise_s
          [%message
            "frame wrong"
              (r : Result.t)
              (base : int)
              (frame : int list)
              (fifty : bool)
              (jitter : float)
              (ppm : float)];
      count (if spoil then "spoilt, refused" else "good, accepted");
      if r.half then count "odd length";
      if r.dropped then count "words dropped";
      if fifty then count "at 50 MHz");
  print_s
    [%message
      ""
        ~_:
          (Hashtbl.to_alist tally |> List.sort ~compare:[%compare: string * int]
           : (string * int) list)];
  [%expect
    {|
    (("at 50 MHz" 59) ("good, accepted" 81) ("odd length" 46)
     ("spoilt, refused" 39) ("words dropped" 38))
    |}]
;;

(* One frame per arm: the second lands nowhere until the host arms again. *)
let%expect_test "a frame disarms the receiver until the host arms it again" =
  let random = Random.State.make [| 3 |] in
  let frame bytes = line ~random ~fifty:true ~ppm:0. ~jitter:5. (with_fcs bytes) in
  let once =
    receive
      ~fifty:true
      ~base:8
      ~may_write:(Fn.const true)
      [ frame [ 1; 2; 3; 4 ]; frame [ 5; 6; 7; 8 ] ]
  in
  let again =
    receive
      ~rearm:(Fn.const true)
      ~fifty:true
      ~base:8
      ~may_write:(Fn.const true)
      [ frame [ 1; 2; 3; 4 ]; frame [ 5; 6; 7; 8 ] ]
  in
  let show (r : Result.t) =
    List.map r.writes ~f:(fun (addr, word) -> sprintf "%d:%04x" addr word)
  in
  print_s
    [%message (show once : string list) (once.fcs_ok : bool) (show again : string list)];
  [%expect
    {|
    (("show once" (8:0201 9:0403 10:fbcd 11:b63c)) (once.fcs_ok true)
     ("show again" (8:0201 9:0403 10:fbcd 11:b63c 8:0605 9:0807 10:4d69 11:538d)))
    |}]
;;

module Two = Engines.Make (struct
    let engines = 2
  end)

module Chip = Hardcaml_test_harness.Lws_harness.Make (Two.I) (Two.O)

(* Engine 0 drives a pin, as link pulses would, and never pulls data. Engine 1 hands what
   sits at [base] to its host a word at a time. *)
let pulses = {|
loop:
    set pins, 1 [7]
    set pins, 0 [7]
    jmp loop
|}

let base = 16

let hand_over =
  {|
    set x, 16
    seek [2]
loop:
    out isr, 16
    wait rx
    push
    jmp loop
|}
;;

let pulses_config = { Program_config.default with set_base = 5; set_count = 1 }

let hand_over_config =
  { Program_config.default with
    autopull = true
  ; autopull_data = true
  ; pull_threshold = 16
  }
;;

module Run = struct
  type t =
    { status : int Frame_rx.Status.t
    ; handed : int list
    ; mismatch : (int * int * Lockstep.State.t * Lockstep.State.t) option
    }
end

(* Both engines against [System] every cycle. Engine 1 starts once the frame is in, or
   with [early] before it comes, when its pulls hold the receiver off. *)
let on_chip ~early frame =
  let random = Random.State.make [| 11 |] in
  let samples = line ~random ~fifty:true ~ppm:50. ~jitter:5. frame |> Array.of_list in
  let program0 = Firmware.assemble pulses in
  let program1 = Firmware.assemble hand_over in
  Chip.run
    ~random_initial_state:`All
    ~create:(Two.hierarchical ~gated:false ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Lws.cycle h in
       let o = Before_and_after_edge.after_edge outputs in
       let int r = Bits.to_unsigned_int !r in
       let port n = List.nth_exn i.hosts n in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       List.iteri
         [ pulses_config, program0; hand_over_config, program1 ]
         ~f:(fun n (config, program) ->
           let p = port n in
           Engine.Config.iter2 p.config (Engine.Config.of_program_config config) ~f:( := );
           List.iteri program ~f:(fun addr word ->
             p.program_write.valid := Bits.vdd;
             p.program_write.addr <--. addr;
             p.program_write.data <--. word;
             cycle ());
           p.program_write.valid := Bits.gnd);
       (* zeros everywhere, so what engine 1 reads past the frame is known *)
       let p = port 0 in
       for addr = 0 to (1 lsl Isa.data_addr_bits) - 1 do
         p.data_write.valid := Bits.vdd;
         p.data_write.addr <--. addr;
         p.data_write.data <--. 0;
         cycle ()
       done;
       p.data_write.valid := Bits.gnd;
       i.frame.base <--. base;
       i.frame.fifty := Bits.vdd;
       i.frame.arm := Bits.vdd;
       cycle ();
       i.frame.arm := Bits.gnd;
       let machine config program = Machine.create ~config ~program |> ok_exn in
       (* held off, the frame leaves the zeros *)
       let landed =
         List.init (1 lsl Isa.data_addr_bits) ~f:(fun addr ->
           if early
           then 0
           else List.nth (words frame) (addr - base) |> Option.value ~default:0)
       in
       let model =
         ref
           (System.create
              [ machine pulses_config program0
              ; machine hand_over_config program1 |> Machine.stop
              ])
       in
       let running = ref [ true; false ] in
       (* a start pulse, a cycle for the fetch, then the core as [Machine.create] has it *)
       let start engines =
         List.iter engines ~f:(fun n -> (port n).start := Bits.vdd);
         cycle ();
         List.iter engines ~f:(fun n -> (port n).start := Bits.gnd);
         cycle ()
       in
       start [ 0 ];
       let fresh_one () =
         model
         := System.update !model 1 ~f:(fun _ ->
              Machine.load_data (machine hand_over_config program1) landed |> ok_exn);
         running := [ true; true ]
       in
       let step () =
         i.pads <--. 0;
         cycle ();
         model := System.step !model ~pads:0
       in
       (* engine 0 keeps time with the model while engine 1 starts *)
       let start_one () =
         (port 1).start := Bits.vdd;
         step ();
         (port 1).start := Bits.gnd;
         step ();
         fresh_one ()
       in
       if early then start_one ();
       let handed = ref [] in
       let mismatch = ref None in
       let n = ref 0 in
       let compare () =
         List.iteri (List.zip_exn !model.engines o.engines) ~f:(fun engine (m, out) ->
           let expected = Lockstep.State.of_machine m in
           let actual = Lockstep.State.of_outputs out in
           if List.nth_exn !running engine
              && Option.is_none !mismatch
              && not (Lockstep.State.equal expected actual)
           then mismatch := Some (!n, engine, expected, actual))
       in
       let total = Array.length samples + 600 in
       while !n < total && Option.is_none !mismatch do
         compare ();
         if !n = Array.length samples && not early then start_one ();
         let rd = if !n < Array.length samples then samples.(!n) else [ 0; 0 ] in
         i.rd := Bits.of_bit_list (List.rev rd);
         let one = List.nth_exn !model.engines 1 in
         let pop = List.nth_exn !running 1 && not (List.is_empty one.rx_fifo) in
         (port 1).rx_pop := Bits.of_bool pop;
         if pop
         then (
           handed := List.hd_exn one.rx_fifo :: !handed;
           model
           := System.update !model 1 ~f:(fun m ->
                Machine.read_rx m |> Option.value_exn |> snd));
         step ();
         Int.incr n
       done;
       (port 1).rx_pop := Bits.gnd;
       { Run.status = Frame_rx.Status.map o.frame ~f:int
       ; handed = List.rev !handed
       ; mismatch = !mismatch
       })
;;

(* A frame lands while engine 0 runs in lockstep with the model, then engine 1, whose
   model starts from the memory the frame should have left, hands it to the host word for
   word. With engine 1 pulling from the start, the receiver keeps off and says so. *)
let%expect_test "a frame on the chip, beside running engines in lockstep" =
  let frame = with_fcs (List.init 23 ~f:(fun n -> ((n * 37) + 5) land 0xff)) in
  let expected = words frame in
  List.iter [ false; true ] ~f:(fun early ->
    let r = on_chip ~early frame in
    let handed = List.take r.handed (List.length expected) in
    print_s
      [%message
        ""
          (early : bool)
          ~lockstep:
            (Option.map r.mismatch ~f:(fun (cycle, engine, _, _) -> cycle, engine)
             : (int * int) option)
          ~status:(r.status : int Frame_rx.Status.t)
          ~handed_as_sent:([%equal: int list] handed expected : bool)
          ~handed:(List.length r.handed : int)];
    Option.iter r.mismatch ~f:(fun (_, _, e, a) ->
      print_s [%message (e : Lockstep.State.t) (a : Lockstep.State.t)]));
  [%expect
    {|
    ((early false) (lockstep ())
     (status
      ((words 14) (finished 1) (fcs_ok 1) (half 1) (dropped 0) (receiving 0)
       (armed 0)))
     (handed_as_sent true) (handed 119))
    ((early true) (lockstep ())
     (status
      ((words 14) (finished 1) (fcs_ok 1) (half 1) (dropped 1) (receiving 0)
       (armed 0)))
     (handed_as_sent false) (handed 419))
    |}]
;;
