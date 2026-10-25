open! Core
open Protocol_emulator
open Nec

(* 18 cycles a unit, as a 32 kHz clock gives: a key held for two repeat codes, then two
   keys tapped, the second at the extremes of the address and the command. *)
let unit = 18
let clock_hz = 32_000
let keys = [ 0x04, 0x08, 2; 0x00, 0x45, 0; 0xff, 0x00, 0 ]

let host_words =
  unit
  :: List.concat_map keys ~f:(fun (address, command, repeats) ->
    words ~address ~command ~repeats)
;;

let sent =
  List.concat_map keys ~f:(fun (address, command, repeats) ->
    Message.Frame { address; command } :: List.init repeats ~f:(fun _ -> Message.Repeat))
;;

(* what the receiver pushes for them: a frame's two words, then 0xffff a repeat code *)
let pushed =
  List.concat_map keys ~f:(fun (address, command, repeats) ->
    List.drop (words ~address ~command ~repeats) 1
    @ List.init repeats ~f:(fun _ -> 0xffff))
;;

(* the keys' six periods, and a few cycles before the first *)
let cycles = (6 * 192 * unit) + 100

(* the line from its first rise, as the firmware leaves reset's low *)
let print_decoded levels =
  match decode ~clock_hz (List.drop_while levels ~f:not) with
  | Ok (messages, measured) ->
    print_s
      [%message
        ""
          (messages : Message.t list)
          ~as_sent:([%equal: Message.t list] messages sent : bool)
          ~measured_ns:(measured : Measured.t)]
  | Error error -> print_s [%message "refused" (error : Error.t)]
;;

let line (m : Machine.t) = (m.pin_out lsr pin) land 1 = 1

(* the transmitter on the model, the host writing each word once the fifo has room *)
let tx_levels source =
  let machine =
    Machine.create ~config:(Timed_program.config tx) ~program:(Firmware.assemble source)
    |> ok_exn
  in
  List.folding_map
    (List.range 0 cycles)
    ~init:(machine, host_words)
    ~f:(fun (machine, pending) _ ->
      let machine, pending =
        match pending with
        | w :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine w |> ok_exn, rest
        | pending -> machine, pending
      in
      let machine = Machine.step machine ~inputs:0 in
      (machine, pending), line machine)
;;

let%expect_test "every mark and space to the nominal, and 108 ms a key" =
  print_decoded (tx_levels (Timed_program.source tx));
  [%expect
    {|
    ((messages
      ((Frame (address 4) (command 8)) Repeat Repeat
       (Frame (address 0) (command 69)) (Frame (address 255) (command 0))))
     (as_sent true)
     (measured_ns
      (("leader mark" (9000000 9000000)) ("leader space" (4500000 4500000))
       ("bit mark" (562500 562500)) ("zero space" (562500 562500))
       ("one space" (1687500 1687500)) ("final mark" (562500 562500))
       (period (108000000 108468750)) ("repeat space" (2250000 2250000)))))
    |}]
;;

(* A leader one unit short, 8.44 ms, is 6% off. *)
let%expect_test "the decoder refuses a leader a unit short" =
  let source =
    Bench.patch
      (Timed_program.source tx)
      ~pattern:"set pins, 0              ; leader, 9 ms\n    set x, 14"
      ~with_:"set pins, 0              ; leader, 9 ms\n    set x, 13"
  in
  print_decoded (tx_levels source);
  [%expect {| (refused (error ("out of spec" "leader mark" (ns 8437500)))) |}]
;;

let%expect_test "nec_tx in lockstep" =
  let levels = ref [] in
  let pending = ref host_words in
  let room = ref Machine.fifo_depth in
  let model =
    Lockstep.lockstep
      ~cycles
      ~config:(Timed_program.config tx)
      ~program:(Timed_program.words tx)
      ~inputs:(fun _ -> 0)
      ~host:(fun _ ->
        let tx =
          match !pending with
          | w :: rest when !room > 0 ->
            pending := rest;
            Some w
          | _ -> None
        in
        { Lockstep.Host.idle with tx })
      ~react:(fun m ->
        room := Machine.fifo_depth - List.length m.tx_fifo;
        levels := line m :: !levels)
      ()
  in
  print_s [%message "" ~fault:(model.fault : Machine.Fault.t)];
  print_decoded (List.rev !levels);
  [%expect
    {|
    ("lockstep held" (cycles 20836))
    (fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    ((messages
      ((Frame (address 4) (command 8)) Repeat Repeat
       (Frame (address 0) (command 69)) (Frame (address 255) (command 0))))
     (as_sent true)
     (measured_ns
      (("leader mark" (9000000 9000000)) ("leader space" (4500000 4500000))
       ("bit mark" (562500 562500)) ("zero space" (562500 562500))
       ("one space" (1687500 1687500)) ("final mark" (562500 562500))
       (period (108000000 108468750)) ("repeat space" (2250000 2250000)))))
    |}]
;;

(* the transmitter on engine 0 and the receiver on engine 1, on a wire between them *)
let%expect_test "the receiver reads back what the transmitter sends" =
  let wire = Isa.num_pins in
  let on_wire =
    Timed_program.of_source_exn
      ~period_floor:shortest_unit
      ~config:{ config with set_base = wire }
      (Timed_program.source tx)
  in
  let controller = { Both_roles.Side.timed = on_wire; words = host_words }
  and target =
    { Both_roles.Side.timed = receiver ~pin:wire ~half:(unit / 2); words = [ unit / 2 ] }
  in
  List.iter
    [ "model", Both_roles.model; "rtl", Both_roles.rtl ]
    ~f:(fun (name, run) ->
      let outcome = run ~cycles ~controller ~target () in
      print_s
        [%message
          name
            ~pushed:(List.map outcome.target ~f:(sprintf "%04x") : string list)
            ~as_sent:([%equal: int list] outcome.target pushed : bool)
            ~faults:(outcome.faults : Machine.Fault.t list)
            ~mismatch:(Option.is_some outcome.mismatch : bool)]);
  [%expect
    {|
    (model (pushed (fb04 f708 ffff ffff ff00 ba45 00ff ff00)) (as_sent true)
     (faults
      (((underflow false) (overflow false) (missed_deadline false)
        (decode false))
       ((underflow false) (overflow false) (missed_deadline false)
        (decode false))))
     (mismatch false))
    (rtl (pushed (fb04 f708 ffff ffff ff00 ba45 00ff ff00)) (as_sent true)
     (faults
      (((underflow false) (overflow false) (missed_deadline false)
        (decode false))
       ((underflow false) (overflow false) (missed_deadline false)
        (decode false))))
     (mismatch false))
    |}]
;;

(* A remote whose unit is [remote] cycles: a frame, then a repeat code, each 192 units. *)
let remote ~remote (address, command) =
  let level high n = List.init (n * remote) ~f:(fun _ -> high) in
  let bits =
    List.concat_map
      [ address; lnot address; command; lnot command ]
      ~f:(fun byte -> List.init 8 ~f:(fun i -> (byte lsr i) land 1 = 1))
  in
  let frame =
    level false 16
    @ level true 8
    @ List.concat_map bits ~f:(fun one ->
      level false 1 @ level true (if one then 3 else 1))
    @ level false 1
  in
  let repeat = level false 16 @ level true 4 @ level false 1 in
  let padded levels = levels @ level true (192 - (List.length levels / remote)) in
  level true 4 @ padded frame @ padded repeat
;;

(* The receiver at 100 cycles a half unit against remotes from 25% fast to 25% slow, in
   steps of 2.5%. The repeat code's final mark, 4 to 5 units past the leader's end, has to
   cover the sample at 4.5: under 10% fast, to 12.5% slow. *)
let%expect_test "the units the receiver reads a remote at" =
  let half = 100 in
  let reads remote_unit =
    let timed = receiver ~pin:rx_pin ~half in
    let machine =
      Machine.create
        ~config:(Timed_program.config timed)
        ~program:(Timed_program.words timed)
      |> ok_exn
    in
    let machine = Machine.write_tx machine half |> ok_exn in
    let machine, words =
      List.fold
        (remote ~remote:remote_unit (0x04, 0x08))
        ~init:(machine, [])
        ~f:(fun (machine, words) high ->
          let machine = Machine.step machine ~inputs:(Bool.to_int high lsl rx_pin) in
          match Machine.read_rx machine with
          | Some (w, machine) -> machine, w :: words
          | None -> machine, words)
    in
    Machine.Fault.equal machine.fault Machine.Fault.none
    && [%equal: int list] (List.rev words) [ 0xfb04; 0xf708; 0xffff ]
  in
  let read = List.filter (List.range ~stride:5 150 251) ~f:reads in
  print_s
    [%message
      ""
        ~unit:(2 * half : int)
        ~least:(List.hd_exn read : int)
        ~most:(List.last_exn read : int)
        ~all_between:
          (List.length read = ((List.last_exn read - List.hd_exn read) / 5) + 1 : bool)];
  [%expect {| ((unit 200) (least 185) (most 225) (all_between true)) |}]
;;

let%expect_test "every edge and every sample is placed by a deadline" =
  Timing_report.print ~config ~period:standard_unit (Timed_program.source tx);
  Timing_report.print
    ~single_capture_edge:true
    ~config:(rx_config ~pin:rx_pin)
    ~period:standard_half
    (Timed_program.source rx);
  [%expect
    {|
      1  set pins, 1                  phase 1  edge 2  gap ?..?
     11  set pins, 0                  phase -26999  edge -26998  gap 27008..?
     16  set pins, 1                  phase -26999  edge -26998  gap 54000..?
     26  set pins, 0                  phase -26999  edge -26998  gap 27000..?
     29  set pins, 1                  phase -26999  edge -26998  gap 27000
     34  set pins, 0                  phase -26999  edge -26998  gap 26999..81003
     37  set pins, 1                  phase -26999  edge -26998  gap 27000
     41  set pins, 0                  phase -26999  edge -26998  gap 27000..81000
     43  set pins, 1                  phase -26999  edge -26998  gap 27000
     51  set pins, 0                  phase -26999  edge -26998  gap 53995..?
     56  set pins, 1                  phase -26999  edge -26998  gap 54000..?
     61  set pins, 0                  phase -26999  edge -26998  gap 54000..?
     63  set pins, 1                  phase -26999  edge -26998  gap 27000
    ((words 80) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
     33  in pins, 1                   phase 1  sample 1
    ((words 37) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

module G = Hardcaml_verify.Comb_gates

(* The host picks the unit, so the analyser's rows are for every load of the floor or
   more, and the kernel accepts them at each, by checked SAT; at one less it refuses. *)
let%expect_test "the kernel accepts every unit from the shortest up" =
  let accepts name timed ~floor ~single_capture_edge =
    let program = Timed_program.program timed in
    let config = Timed_program.config timed in
    let words = Timed_program.words timed in
    let table ~floor =
      Analyser.analyse
        ~period_floor:floor
        ~single_capture_edge
        ~config
        program.instructions
      |> Kernel.Table.of_analyser
    in
    let check ~floor =
      Kernel.check ~period:floor ~single_capture_edge ~config ~words (table ~floor)
    in
    print_s
      [%message
        name
          ~kernel:(check ~floor : unit Or_error.t)
          ~one_less:(Result.is_ok (check ~floor:(floor - 1)) : bool)];
    let loads_from at =
      Table_query.every_load_from
        ~floor:at
        ~single_capture_edge
        ~config
        ~words
        (table ~floor)
    in
    Checked_unsat.prove
      [%string "%{name}: every load of %{floor#Int} or more"]
      ~cases:[ G.vdd ]
      ~claim:(loads_from floor);
    Checked_unsat.prove
      ~show:[ "loaded" ]
      [%string "%{name}: every load of %{floor - 1#Int} or more"]
      ~cases:[ G.vdd ]
      ~claim:(loads_from (floor - 1))
  in
  accepts "nec_tx" tx ~floor:shortest_unit ~single_capture_edge:false;
  [%expect
    {|
    (nec_tx (kernel (Ok ())) (one_less false))
    (QED "nec_tx: every load of 11 or more")
    (counterexample "nec_tx: every load of 10 or more"
     (model ((loaded 0000000000001010))))
    |}]
;;

(* The receiver anchors each bit on a capture, which the analyser bounds at one load at a
   time: the least half unit the kernel accepts, and every one from it to 200. *)
let%expect_test "the least half unit the receiver keeps up with" =
  let accepts half =
    Result.is_ok
      (Timed_program.check
         ~period:half
         ~single_capture_edge:true
         ~config:(rx_config ~pin:rx_pin)
         (rx_on ~pin:rx_pin))
  in
  let least = List.find_exn (List.range 1 200) ~f:accepts in
  print_s
    [%message
      "nec_rx"
        (least : int)
        ~every_one_to_200:(List.for_all (List.range least 201) ~f:accepts : bool)];
  [%expect {| (nec_rx (least 7) (every_one_to_200 true)) |}]
;;
