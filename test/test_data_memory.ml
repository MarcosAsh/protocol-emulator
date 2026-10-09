open! Core
open Protocol_emulator

let data = List.init 12 ~f:(fun n -> 0x1000 * (n + 1) lor n)

(* Sixteen pins from IO0, so a whole word shows at once. *)
let config =
  { Program_config.default with
    out_base = Isa.first_bidir_pin
  ; out_count = Isa.data_bits
  ; autopull = true
  ; autopull_data = true
  }
;;

(* Runs [source] with [data] in lockstep and prints every word on the sixteen pins. *)
let stream ?(preload = []) ~cycles source =
  let shown = ref [] in
  let react (m : Machine.t) =
    let word = (m.pin_out lsr Isa.first_bidir_pin) land 0xffff in
    match !shown with
    | last :: _ when last = word -> ()
    | _ -> shown := word :: !shown
  in
  let program = Asm.assemble source |> ok_exn in
  let m =
    Lockstep.lockstep
      ~cycles
      ~preload
      ~data
      ~config:(Asm.Program.configure program config)
      ~program:(Asm.Program.words program |> ok_exn)
      ~inputs:(fun _ -> 0)
      ~react
      ()
  in
  print_s
    [%message
      "" ~shown:(List.rev !shown : Int.Hex.t list) ~underflow:(m.fault.underflow : bool)];
  (match Analyser.check ~config program with
   | Ok verdict -> print_endline (Analyser.Verdict.to_string verdict)
   | Error error -> print_endline (Error.to_string_hum error));
  (* and every pull the model refuses is one the analyser warned of *)
  let { Soundness.issues; violations; _ } =
    Soundness.check
      ~preload
      ~config:(Asm.Program.configure program config)
      (List.init 4 ~f:(fun n -> Soundness.Stimulus.random ~seed:(n + 1) ~cycles))
      (Asm.Program.words program |> ok_exn)
  in
  print_s [%message (issues : int) (violations : (int * int * int * int) list)]
;;

(* An autopull every other cycle, the fastest the shared memory is ever read. *)
let%expect_test "every other cycle takes the next word from where seek pointed" =
  stream
    ~cycles:22
    {|
    set x, 3
    seek [1]
.wrap_target
    out pins, 16 [1]
.wrap
|};
  [%expect
    {|
    ("lockstep held" (cycles 22))
    ((shown
      (0x0 0x4003 0x5004 0x6005 0x7006 0x8007 0x9008 0xa009 0xb00a 0xc00b 0x0))
     (underflow false))
    3 words, 0 deadline waits
    ((issues 48) (violations ()))
    |}]
;;

(* A pull the cycle after the pointer moved is refused, since the word may not have
   arrived; the next one takes it. *)
let%expect_test "a data pull the cycle after a seek or a pull is refused" =
  stream ~cycles:12 {|
    set x, 3
    seek
.wrap_target
    out pins, 16
.wrap
|};
  [%expect
    {|
    ("lockstep held" (cycles 12))
    ((shown (0x0 0x4003 0x0 0x5004 0x0 0x6005 0x0 0x7006 0x0 0x8007))
     (underflow true))
    1 data pull may come within 1 cycle of the pointer moving
      2  out pins, 16                 phase ?..?  edge ?..?  jitter ?  gap 1 from 2, ?..? from 1  MAY UNDERRUN
    ((issues 12) (violations ()))
    |}]
;;

(* The host's word gives the count; the data comes through autopull. *)
let%expect_test "a pull reads the host while autopull reads the data" =
  stream
    ~preload:[ 3 ]
    ~cycles:40
    {|
    wait tx
    pull
    mov y, osr
    out null, 16
loop:
    out pins, 16
    jmp y--, loop
    halt
|};
  [%expect
    {|
    ("lockstep held" (cycles 40))
    ((shown (0x0 0x1000 0x2001 0x3002 0x4003)) (underflow false))
    7 words, 0 deadline waits
    ((issues 52) (violations ()))
    |}]
;;

let%expect_test "a data memory serves one or two engines" =
  List.iter [ 0; 3 ] ~f:(fun engines ->
    let made =
      Or_error.try_with (fun () ->
        let module _ =
          Data_memory.Make (struct
            let engines = engines
          end)
        in
        ())
    in
    print_s [%message (made : unit Or_error.t)]);
  [%expect
    {|
    (made (Error ("BUG: one data memory serves one or two engines" (engines 0))))
    (made (Error ("BUG: one data memory serves one or two engines" (engines 3))))
    |}]
;;

module Two = Data_memory.Make (struct
    let engines = 2
  end)

module Harness = Hardcaml_test_harness.Lws_harness.Make (Two.I) (Two.O)

let%expect_test "a write lands only while both engines are halted" =
  Harness.run
    ~random_initial_state:`All
    ~create:(Two.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let open Hardcaml in
       let words = (Before_and_after_edge.after_edge outputs).words in
       let write = List.hd_exn i.writes in
       let halt halted =
         List.iter2_exn i.halted halted ~f:(fun r b -> r := Bits.of_bool b)
       in
       i.clocking.clear := Bits.vdd;
       Hardcaml_lws.Lws.cycle h;
       i.clocking.clear := Bits.gnd;
       List.iter
         [ [ true; true ], 0, 0x1111
         ; [ true; true ], 1, 0x2222
         ; [ true; false ], 0, 0xdead
         ; [ false; true ], 1, 0xbeef
         ]
         ~f:(fun (halted, addr, data) ->
           halt halted;
           write.valid := Bits.vdd;
           Bits.(write.addr <--. addr);
           Bits.(write.data <--. data);
           Hardcaml_lws.Lws.cycle h);
       write.valid := Bits.gnd;
       halt [ true; true ];
       List.iteri i.reads ~f:(fun n r -> Bits.(r <--. n));
       List.iter (List.range 0 4) ~f:(fun _ -> Hardcaml_lws.Lws.cycle h);
       print_s [%message "" ~words:(List.map words ~f:( ! ) : Bits.Hex.t list)]);
  [%expect {| (words (16'h1111 16'h2222)) |}]
;;
