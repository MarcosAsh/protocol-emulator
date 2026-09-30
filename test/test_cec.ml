open! Core
open Protocol_emulator
open Cec

let frame ~to_ data = { Frame.initiator = 4; destination = to_; data }

(* From a playback device, 4, to the TV at 0: a poll, <Image View On>, <Set OSD Name>
   "CEC", then a poll of 5, where no one answers. *)
let frames =
  [ frame ~to_:0 []
  ; frame ~to_:0 [ 0x04 ]
  ; frame ~to_:0 [ 0x47; Char.to_int 'C'; Char.to_int 'E'; Char.to_int 'C' ]
  ; frame ~to_:5 []
  ]
;;

let master_low (m : Machine.t) = (m.pin_dir lsr pin) land 1 = 1

let bus (m : Machine.t) follower =
  if master_low m || Follower.drive_low follower then 0 else 1 lsl pin
;;

let print_follower follower ~acks (fault : Machine.Fault.t) =
  print_s
    [%message
      ""
        ~frames:(Follower.frames follower : (Frame.t * bool list) list)
        (acks : int list)
        ~measured_ns:(Follower.measured follower : Measured.t)
        ~violations:
          (Follower.violations follower |> List.dedup_and_sort ~compare:String.compare
           : string list)
        (fault : Machine.Fault.t)]
;;

(* The follower at 0 on the line, times scaled so a unit of [unit] cycles is 50 us. *)
let run ?(source = firmware) ~unit ~cycles () =
  let t = Machine.create ~config ~program:(Firmware.assemble source) |> ok_exn in
  let rec loop (t : Machine.t) follower pending n acks =
    if n = 0
    then t, follower, List.rev acks
    else (
      let t, pending =
        match pending with
        | w :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx t w |> ok_exn, rest
        | pending -> t, pending
      in
      let line = bus t follower in
      let t' = Machine.step t ~inputs:line in
      let follower = Follower.step follower ~low:(line = 0) in
      let acks, t' =
        match Machine.read_rx t' with
        | Some (a, t') -> a :: acks, t'
        | None -> acks, t'
      in
      loop t' follower pending (n - 1) acks)
  in
  let t, follower, acks =
    loop
      t
      (Follower.create ~cycle_ns:(50_000 / unit) ~address:0)
      (unit :: List.concat_map frames ~f:words)
      cycles
      []
  in
  print_follower follower ~acks t.fault
;;

let%expect_test "the words of a frame" =
  List.iter frames ~f:(fun frame ->
    let words = words frame |> List.map ~f:(sprintf "0x%04x") in
    print_s [%message "" ~_:(words : string list)]);
  [%expect
    {|
    (0x0000 0x4080)
    (0x0001 0x4000 0x0480)
    (0x0004 0x4000 0x4700 0x4300 0x4500 0x4380)
    (0x0000 0x4580)
    |}]
;;

(* A unit of 25 cycles, as a 500 kHz clock would give. *)
let%expect_test "four frames, acknowledged by the TV but the last" =
  run ~unit:25 ~cycles:145_000 ();
  [%expect
    {|
    ((frames
      ((((initiator 4) (destination 0) (data ())) (true))
       (((initiator 4) (destination 0) (data (4))) (true true))
       (((initiator 4) (destination 0) (data (71 67 69 67)))
        (true true true true true))
       (((initiator 4) (destination 5) (data ())) (false))))
     (acks (0 0 0 0 0 0 0 0 1))
     (measured_ns
      (("start low" (3700000 3700000)) (start (4500000 4500000))
       ("zero low" (1500000 1500000)) (bit (2400000 2400000))
       ("one low" (600000 600000)) (free (16820000 16820000))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* Five bit periods between frames, the wait a new initiator owes, is short by two for
   this one's next frame. *)
let%expect_test "the follower refuses five bit periods free before the same initiator" =
  let pattern = "set y, 6" in
  if not (String.is_substring firmware ~substring:pattern)
  then raise_s [%message "BUG: not in the source" pattern];
  let source = String.substr_replace_first firmware ~pattern ~with_:"set y, 4" in
  run ~source ~unit:25 ~cycles:145_000 ();
  [%expect
    {|
    ((frames
      ((((initiator 4) (destination 0) (data ())) (true))
       (((initiator 4) (destination 0) (data (4))) (true true))
       (((initiator 4) (destination 0) (data (71 67 69 67)))
        (true true true true true))
       (((initiator 4) (destination 5) (data ())) (false))))
     (acks (0 0 0 0 0 0 0 0 1))
     (measured_ns
      (("start low" (3700000 3700000)) (start (4500000 4500000))
       ("zero low" (1500000 1500000)) (bit (2400000 2400000))
       ("one low" (600000 600000)) (free (12020000 12020000))))
     (violations ("free of 12020000 ns"))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* A line driven by an initiator drawn in 50 us units, a cycle each, with the followers at
   [addresses] on it. Each frame comes [free] bit periods after the last one's final bit,
   and is [from] an initiator to [to_]. The initiator holds its ACK slots low for
   [ack_units], and the frame at each index in [cuts] is cut to its first so many units,
   the initiator giving it up. *)
let followers_see ?(addresses = [ 0 ]) ?(ack_units = 12) ?(cuts = []) sends =
  let bit one = List.init 48 ~f:(fun i -> i < if one then 12 else 30) in
  let lows =
    List.concat_mapi sends ~f:(fun n (free, from, to_, data) ->
      let bytes = ((from lsl 4) lor to_) :: data in
      let last = List.length bytes - 1 in
      let frame =
        List.init 90 ~f:(fun i -> i < 74)
        @ List.concat_mapi bytes ~f:(fun i byte ->
          List.concat_map (List.range ~stride:(-1) 7 (-1)) ~f:(fun b ->
            bit ((byte lsr b) land 1 = 1))
          @ bit (i = last)
          @ List.init 48 ~f:(fun i -> i < ack_units))
      in
      List.init (free * 48) ~f:(fun _ -> false)
      @
      match List.Assoc.find cuts n ~equal:Int.equal with
      | Some cut -> List.take frame cut
      | None -> frame)
  in
  let followers =
    List.fold
      lows
      ~init:
        (List.map addresses ~f:(fun address -> Follower.create ~cycle_ns:50_000 ~address))
      ~f:(fun followers low ->
        let low = low || List.exists followers ~f:Follower.drive_low in
        List.map followers ~f:(Follower.step ~low))
  in
  List.iter followers ~f:(fun follower ->
    print_s
      [%message
        ""
          ~frames:(List.length (Follower.frames follower) : int)
          ~violations:(Follower.violations follower : string list)])
;;

(* 4 polls 5, where no one answers, so the frame fails: a retry of it may come 3 bit
   periods on, but a new frame of 4's owes 7 and one from a new initiator, 3, owes 5. *)
let%expect_test "the free time the follower asks of each next frame" =
  let failed = 0, 4, 5, [] in
  let ok = 0, 4, 0, [] in
  List.iter
    [ "retry at 3", [ failed; 3, 4, 5, [] ]
    ; "retry at 2", [ failed; 2, 4, 5, [] ]
    ; "new initiator at 5", [ ok; 5, 3, 0, [] ]
    ; "new initiator at 4", [ ok; 4, 3, 0, [] ]
    ; "new initiator at 3 after a failure", [ failed; 3, 3, 0, [] ]
    ; "another frame at 3 after a failure", [ failed; 3, 4, 0, [] ]
    ; "another frame at 7 after a failure", [ failed; 7, 4, 0, [ 0x04 ] ]
    ]
    ~f:(fun (name, sends) ->
      print_endline name;
      followers_see sends);
  [%expect
    {|
    retry at 3
    ((frames 2) (violations ()))
    retry at 2
    ((frames 2) (violations ("free of 4800000 ns")))
    new initiator at 5
    ((frames 2) (violations ()))
    new initiator at 4
    ((frames 2) (violations ("free of 9600000 ns")))
    new initiator at 3 after a failure
    ((frames 2) (violations ("free of 7200000 ns")))
    another frame at 3 after a failure
    ((frames 2) (violations ("free of 7200000 ns")))
    another frame at 7 after a failure
    ((frames 2) (violations ()))
    |}]
;;

(* The ACK slot's low is a one's, or a zero's when a follower acknowledges, whoever pulls
   it: 4 holding it 1.8 ms under 0's ACK is too long, and 5's ACK, seen by 0, is not. *)
let%expect_test "the follower times the ACK slot as a one or a zero" =
  followers_see ~ack_units:36 [ 0, 4, 0, [] ];
  followers_see ~addresses:[ 0; 5 ] [ 0, 4, 5, [] ];
  [%expect
    {|
    ((frames 1) (violations ("zero low of 1800000 ns")))
    ((frames 1) (violations ()))
    ((frames 1) (violations ()))
    |}]
;;

(* The first frame stops after its start bit and 5 bits, so the next start bit comes long
   after the last fall; the follower drops the frame and takes the next whole. *)
let%expect_test "a frame cut short is dropped" =
  followers_see ~cuts:[ 0, 90 + (5 * 48) ] [ 0, 4, 0, [ 0x04 ]; 7, 4, 0, [] ];
  [%expect {| ((frames 1) (violations ())) |}]
;;

(* A frame given up after its header is still the frame before the next: 4's header to 5
   goes unanswered and 4 stops there, as Linux does, so 4 may send it whole 3 bit periods
   on. The header is 90 units of start bit and 10 bit periods. *)
let%expect_test "a retry after a frame given up at a NACK" =
  followers_see
    ~cuts:[ 1, 90 + 480 ]
    [ 0, 4, 0, []; 7, 4, 5, [ 0x04 ]; 3, 4, 5, [ 0x04 ] ];
  [%expect {| ((frames 2) (violations ())) |}]
;;

let%expect_test "cec in lockstep" =
  let unit = shortest_unit + 1 in
  let follower = ref (Follower.create ~cycle_ns:(50_000 / unit) ~address:0) in
  let pending = ref (unit :: List.concat_map frames ~f:words) in
  let acks = ref [] in
  let last = ref None in
  let model =
    Lockstep.lockstep
      ~cycles:46_000
      ~config
      ~program:(Firmware.assemble firmware)
      ~inputs:(fun _ ->
        Option.value_map !last ~default:(1 lsl pin) ~f:(fun m -> bus m !follower))
      ~host:(fun _ ->
        let tx_level, rx_head =
          Option.value_map !last ~default:(0, None) ~f:(fun (m : Machine.t) ->
            List.length m.tx_fifo, List.hd m.rx_fifo)
        in
        Option.iter rx_head ~f:(fun a -> acks := a :: !acks);
        let tx =
          match !pending with
          | w :: rest when tx_level < Machine.fifo_depth ->
            pending := rest;
            Some w
          | _ -> None
        in
        { Lockstep.Host.idle with tx; pop_rx = Option.is_some rx_head })
      ~react:(fun m ->
        Option.iter !last ~f:(fun before ->
          follower := Follower.step !follower ~low:(bus before !follower = 0));
        last := Some m)
      ()
  in
  print_follower !follower ~acks:(List.rev !acks) model.fault;
  [%expect
    {|
    ("lockstep held" (cycles 46000))
    ((frames
      ((((initiator 4) (destination 0) (data ())) (true))
       (((initiator 4) (destination 0) (data (4))) (true true))
       (((initiator 4) (destination 0) (data (71 67 69 67)))
        (true true true true true))
       (((initiator 4) (destination 5) (data ())) (false))))
     (acks (0 0 0 0 0 0 0 0 1))
     (measured_ns
      (("start low" (3700000 3700000)) (start (4500000 4500000))
       ("zero low" (1500000 1500000)) (bit (2400000 2400000))
       ("one low" (600000 600000)) (free (16862500 16862500))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge and every sample is placed by a deadline" =
  Timing_report.print ~config ~period:standard_unit firmware;
  [%expect
    {|
      4  set pins, 0                  phase 1  edge 2  gap ?..?
      5  set pindirs, 0               phase 2  edge 3  gap 1
     12  set pindirs, 1               phase -2499  edge -2498  gap 2505..?
     23  set pindirs, 0               phase -2499  edge -2498  gap 10000..?
     30  set pindirs, 1               phase -2499  edge -2498  gap 4998..?
     35  out pindirs, 1               phase -2499  edge -2498  gap 5000..?
     40  set pindirs, 0               phase -2499  edge -2498  gap 5000..?
     46  set pindirs, 1               phase -2499  edge -2498  gap 5000..?
     51  set pindirs, 0               phase -2499  edge -2498  gap 5000..?
     56  in pins, 1                   phase -2499  sample -2499
    ((words 71) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

module G = Hardcaml_verify.Comb_gates

(* As first written, but for the anchor before the line is let go, which only makes that
   edge's report exact. The host picks the unit, so the analyser's rows are for every load
   of the floor or more and the kernel accepts them at each, by checked SAT; at one less
   it refuses. *)
let%expect_test "the kernel accepts every unit from the shortest up" =
  let program = Asm.assemble firmware |> ok_exn in
  let config = Asm.Program.configure program config in
  let words = Asm.Program.words program |> ok_exn in
  let table ~floor =
    Analyser.analyse ~period_floor:floor ~config program.instructions
    |> Kernel.Table.of_analyser
  in
  let check ~floor = Kernel.check ~period:floor ~config ~words (table ~floor) in
  print_s
    [%message
      ""
        ~kernel:(check ~floor:shortest_unit : unit Or_error.t)
        ~one_less:(check ~floor:(shortest_unit - 1) : unit Or_error.t)];
  let loads_from floor =
    Table_query.every_load_from
      ~floor
      ~single_capture_edge:false
      ~config
      ~words
      (table ~floor:shortest_unit)
  in
  Checked_unsat.prove
    [%string "cec: every load of %{shortest_unit#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from shortest_unit);
  Checked_unsat.prove
    ~show:[ "loaded" ]
    [%string "cec: every load of %{shortest_unit - 1#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from (shortest_unit - 1));
  [%expect
    {|
    ((kernel (Ok ()))
     (one_less
      (Error
       ("rows the kernel rejects"
        (rejected (((pc 29) (fails ("in time"))) ((pc 64) (fails ("in time")))))))))
    (QED "cec: every load of 7 or more")
    (counterexample "cec: every load of 6 or more"
     (model ((loaded 0000000000000110))))
    |}]
;;
