open! Core
open Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Protocol_emulator
open Protocol_models

let bit_ns = 1000. /. 12.
let in_ = 0x69

let pins : Usb_ls.Line.t -> int * int = function
  | J -> 1, 0
  | K -> 0, 1
  | Se0 -> 0, 0
;;

(* Packets on D+ and D- from J, [gap] bits of J around each, the sender's bit [ppm] long.
   Each change of line state moves by up to [jitter] ns, and D- follows D+ by [skew] ns.
   [corrupt] edits a packet's states, for a stuffing error. *)
let line ?(corrupt = Fn.id) ~random ~ppm ~jitter ~skew ~gap packets =
  let idle = List.init gap ~f:(fun _ -> Usb_ls.Line.J) in
  let states =
    idle @ List.concat_map packets ~f:(fun p -> corrupt (Usb_ls.encode p) @ idle)
  in
  let length = bit_ns *. (1. +. (ppm /. 1e6)) in
  let edges = Queue.create () in
  let (_ : Usb_ls.Line.t) =
    List.foldi states ~init:Usb_ls.Line.J ~f:(fun n before state ->
      if not (Usb_ls.Line.equal before state)
      then (
        let moved =
          if Float.(jitter = 0.)
          then 0.
          else Random.State.float random (2. *. jitter) -. jitter
        in
        let at = 100. +. (Float.of_int n *. length) +. moved in
        let dp, dm = pins before in
        let dp', dm' = pins state in
        if dp <> dp' then Queue.enqueue edges (at, `Dp, dp');
        if dm <> dm' then Queue.enqueue edges (at +. skew, `Dm, dm'));
      state)
  in
  ( Queue.to_list edges
    |> List.stable_sort ~compare:(fun (a, _, _) (b, _, _) -> Float.compare a b)
  , 200. +. (Float.of_int (List.length states) *. length) )
;;

(* D+ and D- sampled [per_bit] times a bit from a random phase, [per_cycle] to a cycle,
   earliest first *)
let sample ~random ~per_bit ~per_cycle (edges, stop) =
  let period = bit_ns /. Float.of_int per_bit in
  let first = Random.State.float random period in
  let count = Float.iround_down_exn ((stop -. first) /. period) / per_cycle in
  let edges = ref edges in
  let dp = ref 1 in
  let dm = ref 0 in
  let at time =
    let rec catch_up () =
      match !edges with
      | (t, wire, level) :: rest when Float.(t <= time) ->
        (match wire with
         | `Dp -> dp := level
         | `Dm -> dm := level);
        edges := rest;
        catch_up ()
      | _ -> ()
    in
    catch_up ();
    !dp, !dm
  in
  (* in time order, as [at] carries the levels on *)
  let cycles = Queue.create () in
  for cycle = 0 to count - 1 do
    let samples = Queue.create () in
    for k = 0 to per_cycle - 1 do
      Queue.enqueue
        samples
        (at (first +. (Float.of_int ((cycle * per_cycle) + k) *. period)))
    done;
    Queue.enqueue cycles (List.unzip (Queue.to_list samples))
  done;
  Queue.to_list cycles
;;

let random_packet random =
  let byte () = if Random.State.bool random then 0xff else Random.State.int random 256 in
  Usb.data ~pid:Usb.data0 (List.init 32 ~f:(fun _ -> byte ()))
;;

module Result = struct
  type t =
    { words : int list
    ; aligned : bool
    ; stuff_error : bool
    }
  [@@deriving sexp_of, equal]

  let of_packet bytes =
    { words = Manchester_line.words bytes; aligned = true; stuff_error = false }
  ;;
end

module Run (Config : Usb_rx.Config) = struct
  module Rx = Usb_rx.Make (Config)
  module Harness = Hardcaml_test_harness.Lws_harness.Make (Rx.I) (Rx.O)

  (* the packets the receiver ends, in order *)
  let run ?(random_initial_state = false) cycles =
    let results = ref [] in
    Harness.run
      ?random_initial_state:(Option.some_if random_initial_state `All)
      ~create:Rx.hierarchical
      (fun (h @ local) ~inputs ~outputs ->
         let outputs = Before_and_after_edge.after_edge outputs in
         let words = ref [] in
         inputs.clocking.clear := Bits.vdd;
         Lws.step h;
         inputs.clocking.clear := Bits.gnd;
         List.iter cycles ~f:(fun (dp, dm) ->
           inputs.dp := Bits.of_bit_list (List.rev dp);
           inputs.dm := Bits.of_bit_list (List.rev dm);
           Lws.step h;
           let flag x = Bits.to_bool !x in
           if flag outputs.sync_seen then words := [];
           if flag outputs.word.valid
           then words := Bits.to_unsigned_int !(outputs.word.value) :: !words;
           if flag outputs.packet_end
           then
             results
             := { Result.words = List.rev !words
                ; aligned = flag outputs.aligned
                ; stuff_error = flag outputs.stuff_error
                }
                :: !results)
         [@nontail]);
    List.rev !results
  ;;
end

module Both_edges_8 = Run (struct
    let samples_per_bit = 8
    let samples_per_cycle = 2
  end)

module Rising_4 = Run (struct
    let samples_per_bit = 4
    let samples_per_cycle = 1
  end)

let intact ~per_bit ~per_cycle ~run ~ppm ~jitter ~skew ~seed =
  let random = Random.State.make [| seed |] in
  let packets = List.init 40 ~f:(fun _ -> random_packet random) in
  let got =
    line ~random ~ppm ~jitter ~skew ~gap:3 packets
    |> sample ~random ~per_bit ~per_cycle
    |> run
  in
  let want = List.map packets ~f:Result.of_packet in
  (* a lost packet shifts the rest, so match each packet against all the results *)
  List.count want ~f:(fun w -> List.mem got w ~equal:Result.equal)
;;

(* Forty DATA0 packets of 32 bytes, half of them 0xff so a stuffed 0 comes every few
   bytes, back to back with three bits of J between, the sender 0.25% fast and slow (the
   standard's limit). Jitter is uniform and independent per line-state change, so two
   edges in a row are up to twice it apart from their spacing: 9.25 ns is the standard's
   18.5 ns to the next transition. Each cell: packets intact of 40. *)
let%expect_test "packets intact under jitter, both edges against one" =
  let jitters = [ 0.; 2.; 5.; 9.25; 12.; 15.; 18. ] in
  printf "%-12s %6s" "sampling" "ppm";
  List.iter jitters ~f:(fun j -> printf " %6s" (sprintf "%gns" j));
  printf "\n";
  List.iter
    [ "8 a bit", 8, 2, Both_edges_8.run ?random_initial_state:None
    ; "4 a bit", 4, 1, Rising_4.run ?random_initial_state:None
    ]
    ~f:(fun (name, per_bit, per_cycle, run) ->
      List.iter [ 2500.; -2500. ] ~f:(fun ppm ->
        printf "%-12s %+6.0f" name ppm;
        List.iter jitters ~f:(fun jitter ->
          printf
            " %6s"
            (sprintf
               "%d/40"
               (intact ~per_bit ~per_cycle ~run ~ppm ~jitter ~skew:0. ~seed:3)));
        printf "\n"));
  [%expect
    {|
    sampling        ppm    0ns    2ns    5ns 9.25ns   12ns   15ns   18ns
    8 a bit       +2500  40/40  40/40  40/40  40/40  40/40  40/40  38/40
    8 a bit       -2500  40/40  40/40  40/40  40/40  40/40  40/40  34/40
    4 a bit       +2500  40/40  40/40  40/40  40/40  40/40  25/40   5/40
    4 a bit       -2500  40/40  40/40  40/40  40/40  36/40  12/40   1/40
    |}]
;;

(* The margin on rate: past the standard's 0.25% at 2 ns of jitter. Seven bits at most
   between edges, the last centre half a bit and a sample from the next edge, gives about
   5%. *)
let%expect_test "packets intact off rate" =
  List.iter [ 10000.; 20000.; 40000.; 50000.; 60000. ] ~f:(fun ppm ->
    printf "%4.0f%%" (ppm /. 1e4);
    List.iter [ ppm; -.ppm ] ~f:(fun ppm ->
      printf
        " %6s"
        (sprintf
           "%d/40"
           (intact
              ~per_bit:8
              ~per_cycle:2
              ~run:(Both_edges_8.run ?random_initial_state:None)
              ~ppm
              ~jitter:2.
              ~skew:0.
              ~seed:7)));
    printf "\n");
  [%expect
    {|
    1%  40/40  40/40
    2%  40/40  40/40
    4%  40/40  40/40
    5%  40/40  35/40
    6%  40/40   0/40
    |}]
;;

(* D- late on D+ by [skew], at 2 ns of jitter and 0.25% slow: SE0 and SE1 glitches at
   every J/K change, which only the centre sample has to miss. The centre is 42 to 52 ns
   after the D+ edge it counts from, so D- may lead by about 30 ns and lag by 40. *)
let%expect_test "packets intact with D- skewed against D+" =
  List.iter [ 0.; 10.; 20.; 30.; -10.; -20.; -30. ] ~f:(fun skew ->
    printf
      "skew %+3.0fns: %d/40\n"
      skew
      (intact
         ~per_bit:8
         ~per_cycle:2
         ~run:(Both_edges_8.run ?random_initial_state:None)
         ~ppm:(-2500.)
         ~jitter:2.
         ~skew
         ~seed:5));
  [%expect
    {|
    skew  +0ns: 40/40
    skew +10ns: 40/40
    skew +20ns: 40/40
    skew +30ns: 40/40
    skew -10ns: 40/40
    skew -20ns: 40/40
    skew -30ns: 4/40
    |}]
;;

(* A token, a data packet with a stuffed run and an odd length, and the data packet again
   with seven 1s on the line, from a random power-up state: words, CRCs and the stuffing
   error as the data memory and the status would see them. *)
let%expect_test "a token, a stuffed data packet and a stuffing error into the data memory"
  =
  let module Harness =
    Hardcaml_test_harness.Lws_harness.Make (Usb_frame_rx.I) (Usb_frame_rx.O)
  in
  let token = Usb.token ~address:5 ~pid:in_ ~endpoint:1 in
  let data = Usb.data ~pid:Usb.data1 [ 0xff; 0xff; 0x3c; 0x7e; 0x01 ] in
  (* the first stuffed 0 held at J: the line stays put a seventh bit *)
  let seventh_one states =
    let rec go ~ones ~before = function
      | [] -> []
      | (state : Usb_ls.Line.t) :: rest ->
        if ones = 6 && not (Usb_ls.Line.equal state before)
        then before :: rest
        else (
          let ones = if Usb_ls.Line.equal state before then ones + 1 else 0 in
          state :: go ~ones ~before:state rest)
    in
    go ~ones:0 ~before:J states
  in
  let random = Random.State.make [| 9 |] in
  let cycles packet ~corrupt =
    line ~corrupt ~random ~ppm:2500. ~jitter:2. ~skew:0. ~gap:3 [ packet ]
    |> sample ~random ~per_bit:8 ~per_cycle:2
  in
  Harness.run
    ~random_initial_state:`All
    ~create:Usb_frame_rx.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let outputs = Before_and_after_edge.after_edge outputs in
       inputs.clocking.clear := Bits.vdd;
       Lws.step h;
       inputs.clocking.clear := Bits.gnd;
       inputs.may_write := Bits.vdd;
       List.iter
         [ "token", token, Fn.id; "data", data, Fn.id; "seventh 1", data, seventh_one ]
         ~f:(fun (name, packet, corrupt) ->
           inputs.control.arm := Bits.vdd;
           inputs.control.base := Bits.of_unsigned_int ~width:Isa.data_addr_bits 0x40;
           Lws.step h;
           inputs.control.arm := Bits.gnd;
           let writes = ref [] in
           List.iter (cycles packet ~corrupt) ~f:(fun (dp, dm) ->
             inputs.dp := Bits.of_bit_list (List.rev dp);
             inputs.dm := Bits.of_bit_list (List.rev dm);
             Lws.step h;
             if Bits.to_bool !(outputs.write.valid)
             then
               writes
               := (Bits.to_unsigned_int !(outputs.write.addr), !(outputs.write.data))
                  :: !writes);
           let s = outputs.status in
           let flag x = Bits.to_bool !x in
           print_s
             [%message
               name
                 ~sent:(Manchester_line.words packet : Int.Hex.t list)
                 ~writes:(List.rev !writes : (Int.Hex.t * Bits.Hex.t) list)
                 ~words:(Bits.to_unsigned_int !(s.words) : int)
                 ~finished:(flag s.finished : bool)
                 ~crc5_ok:(flag s.crc5_ok : bool)
                 ~crc16_ok:(flag s.crc16_ok : bool)
                 ~half:(flag s.half : bool)
                 ~aligned:(flag s.aligned : bool)
                 ~stuff_error:(flag s.stuff_error : bool)
                 ~dropped:(flag s.dropped : bool)]) [@nontail]);
  [%expect
    {|
    (token (sent (0x8569 0x60)) (writes ((0x40 16'h8569) (0x41 16'h0060)))
     (words 2) (finished true) (crc5_ok true) (crc16_ok false) (half true)
     (aligned true) (stuff_error false) (dropped false))
    (data (sent (0xff4b 0x3cff 0x17e 0x93df))
     (writes ((0x40 16'hff4b) (0x41 16'h3cff) (0x42 16'h017e) (0x43 16'h93df)))
     (words 4) (finished true) (crc5_ok false) (crc16_ok true) (half false)
     (aligned true) (stuff_error false) (dropped false))
    ("seventh 1" (sent (0xff4b 0x3cff 0x17e 0x93df)) (writes ()) (words 0)
     (finished true) (crc5_ok false) (crc16_ok false) (half false)
     (aligned false) (stuff_error true) (dropped false))
    |}]
;;

(* An ACK at 0 ppm and no jitter, from SYNC's last bits: the PID alone in a low half, then
   the EOP. *)
let%expect_test "waveform of an ACK" =
  let module Harness =
    Hardcaml_test_harness.Lws_harness.Make (Both_edges_8.Rx.I) (Both_edges_8.Rx.O)
  in
  let random = Random.State.make [| 1 |] in
  let cycles =
    line ~random ~ppm:0. ~jitter:0. ~skew:0. ~gap:1 [ [ Usb.ack ] ]
    |> sample ~random ~per_bit:8 ~per_cycle:2
  in
  let display_rules =
    List.map
      [ "bit$valid"; "bit$value"; "sync_seen"; "packet_active"; "packet_end" ]
      ~f:(fun name -> Display_rule.port_name_is name ~wave_format:Bit)
    @ [ Display_rule.port_name_is "dp" ~wave_format:Binary
      ; Display_rule.port_name_is "dm" ~wave_format:Binary
      ; Display_rule.port_name_is "word$valid" ~wave_format:Bit
      ; Display_rule.port_name_is "word$value" ~wave_format:Hex
      ; Display_rule.port_name_is "usb_rx$phase" ~wave_format:Unsigned_int
      ]
  in
  Harness.run
    ~create:Both_edges_8.Rx.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~start_cycle:36
        ~signals_width:16
        ~display_width:150
        ~wave_width:0
        waves)
    (fun (h @ local) ~inputs ~outputs:_ ->
      inputs.clocking.clear := Bits.vdd;
      Lws.step h;
      inputs.clocking.clear := Bits.gnd;
      List.iter cycles ~f:(fun (dp, dm) ->
        inputs.dp := Bits.of_bit_list (List.rev dp);
        inputs.dm := Bits.of_bit_list (List.rev dm);
        Lws.step h)
      [@nontail]);
  [%expect
    {|
    ┌Signals───────┐┌Waves───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
    │bit$valid     ││                ┌─┐     ┌─┐     ┌─┐     ┌─┐     ┌─┐     ┌─┐     ┌─┐     ┌─┐                                                         │
    │              ││────────────────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └───────────────────────────────────────────              │
    │bit$value     ││                        ┌───────┐               ┌───────┐       ┌─────────────────────────────────────────────────────              │
    │              ││────────────────────────┘       └───────────────┘       └───────┘                                                                   │
    │sync_seen     ││        ┌─┐                                                                                                                         │
    │              ││────────┘ └───────────────────────────────────────────────────────────────────────────────────────────────────────────              │
    │packet_active ││        ┌───────────────────────────────────────────────────────────────────────┐                                                   │
    │              ││────────┘                                                                       └─────────────────────────────────────              │
    │packet_end    ││                                                                                ┌─┐                                                 │
    │              ││────────────────────────────────────────────────────────────────────────────────┘ └───────────────────────────────────              │
    │              ││──────────┬─┬─────────────┬─┬─────┬─┬─────────────┬─┬─────────────────────────────────────┬─┬─────────────────────────              │
    │dp            ││ 00       │.│11           │.│00   │.│11           │.│00                                   │.│11                                     │
    │              ││──────────┴─┴─────────────┴─┴─────┴─┴─────────────┴─┴─────────────────────────────────────┴─┴─────────────────────────              │
    │              ││──────────┬─┬─────────────┬─┬─────┬─┬─────────────┬─┬─────────────────────┬─┬─────────────────────────────────────────              │
    │dm            ││ 11       │.│00           │.│11   │.│00           │.│11                   │.│00                                                     │
    │              ││──────────┴─┴─────────────┴─┴─────┴─┴─────────────┴─┴─────────────────────┴─┴─────────────────────────────────────────              │
    │word$valid    ││                                                                                ┌─┐                                                 │
    │              ││────────────────────────────────────────────────────────────────────────────────┘ └───────────────────────────────────              │
    │              ││────────────────────────────────────────────────────────────────────────────────┬─────────────────────────────────────              │
    │word$value    ││ 0000                                                                           │00D2                                               │
    │              ││────────────────────────────────────────────────────────────────────────────────┴─────────────────────────────────────              │
    │              ││──┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─              │
    │usb_rx$phase  ││ 4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0│2│4│6│0              │
    │              ││──┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─              │
    └──────────────┘└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

let%expect_test "the residues are the CRCs of a good packet" =
  let residue ~width ~poly bits =
    List.fold
      bits
      ~init:((1 lsl width) - 1)
      ~f:(fun crc bit -> Crc.step ~width ~poly ~reflect:true crc ~bit)
  in
  let token = List.tl_exn (Usb.token ~address:5 ~pid:in_ ~endpoint:1) in
  let data = List.tl_exn (Usb.data ~pid:Usb.data0 [ 1; 2; 3 ]) in
  print_s
    [%message
      ""
        ~crc5:(residue ~width:5 ~poly:0x14 (Usb_ls.bits_of_bytes token) : Int.Hex.t)
        ~crc16:(residue ~width:16 ~poly:0xa001 (Usb_ls.bits_of_bytes data) : Int.Hex.t)
        ~rtl:(Usb_frame_rx.crc5_residue : Int.Hex.t)
        ~rtl16:(Usb_frame_rx.crc16_residue : Int.Hex.t)];
  [%expect {| ((crc5 0x6) (crc16 0xb001) (rtl 0x6) (rtl16 0xb001)) |}]
;;

(* Full speed transmit, a bit every four cycles: the 10BASE-T sender's loop with the line
   table's NRZI on D+ and D-, the bits from the data memory and stuffed beforehand, as
   [jmp stuff] would cost the loop two cycles more. The pins, sampled twice a cycle, go
   back through the receiver. *)
let fs_transmitter =
  {|
    set pins, 1              ; J
    set pindirs, 3
    pull                     ; the line bits less one
    mov y, osr
    set x, 0
    seek
    out null, 16             ; so the next out pulls from the data memory
bit:
    out pins, 1 [1]
    jmp y--, bit
    set pins, 0 [7]          ; SE0, two bits
    set pins, 1 [3]          ; J
    set pindirs, 0
    halt
|}
;;

let%expect_test "full speed transmit at four cycles a bit, back through the receiver" =
  let pair = Isa.first_bidir_pin in
  let config =
    { Program_config.default with
      out_base = pair
    ; out_count = 2
    ; set_base = pair
    ; set_count = 2
    ; autopull = true
    ; autopull_data = true
    ; line_code = true
    }
  in
  let packet = Usb.data ~pid:Usb.data0 [ 0xff; 0xff; 0x3c; 0x7e; 0x01; 0xfe; 0xff ] in
  let stuffed =
    Usb_ls.bits_of_bytes (0x80 :: packet)
    |> List.folding_map ~init:0 ~f:(fun ones bit ->
      match bit, ones with
      | 1, 5 -> 0, [ 1; 0 ]
      | 1, _ -> ones + 1, [ 1 ]
      | _ -> 0, [ 0 ])
    |> List.concat
  in
  let words =
    List.chunks_of stuffed ~length:16
    |> List.map ~f:(List.foldi ~init:0 ~f:(fun n word bit -> word lor (bit lsl n)))
  in
  let line = Queue.create () in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(40 + (4 * List.length stuffed) + 24)
      ~preload:[ List.length stuffed - 1 ]
      ~data:words
      ~line_table:Line_code.nrzi
      ~config
      ~program:(Firmware.assemble fs_transmitter)
      ~inputs:(fun _ -> 0)
      ~react:(fun m ->
        let driven = (m.pin_dir lsr pair) land 3 = 3 in
        Queue.enqueue line (if driven then (m.pin_out lsr pair) land 3 else 1))
      ()
  in
  let line = Queue.to_list line in
  let edges =
    List.filter_mapi
      (List.zip_exn (List.drop_last_exn (1 :: line)) line)
      ~f:(fun n (before, now) -> Option.some_if (before land 1 <> now land 1) n)
  in
  let gaps =
    List.zip_exn (List.drop_last_exn edges) (List.tl_exn edges)
    |> List.map ~f:(fun (a, b) -> b - a)
  in
  let cycles =
    List.map line ~f:(fun pins ->
      let dp = pins land 1 in
      let dm = (pins lsr 1) land 1 in
      [ dp; dp ], [ dm; dm ])
  in
  let got = Both_edges_8.run cycles in
  print_s
    [%message
      ""
        ~line_bits:(List.length stuffed : int)
        ~stuffed_zeros:(List.length stuffed - (8 * (1 + List.length packet)) : int)
        ~edge_gaps_all_fours:(List.for_all gaps ~f:(fun g -> g % 4 = 0) : bool)
        ~shortest_gap:(List.min_elt gaps ~compare : int option)
        ~received:([%equal: Result.t list] got [ Result.of_packet packet ] : bool)];
  [%expect
    {|
    ("lockstep held" (cycles 440))
    ((line_bits 94) (stuffed_zeros 6) (edge_gaps_all_fours true)
     (shortest_gap (4)) (received true))
    |}]
;;
