open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Journal.I) (Journal.O)

let ( <--. ) = Bits.( <--. )

module Stimulus = struct
  type t =
    { pads : int
    ; command : Journal.Code.t (** One of the first four. *)
    ; fault : bool
    }

  let idle pads = { pads; command = Pads; fault = false }
end

(* Runs the journal over [stimuli], arming it on the first and disarming it after the last
   unless [disarm] is false, with a slot every other cycle, and returns the ring. *)
let record ?(disarm = true) ?(slot = fun n -> n % 2 = 1) ?(waves = false) stimuli =
  let ring = Array.create ~len:Journal.words 0 in
  let print_waves_after_test waves =
    Waveform.print
      ~display_rules:
        [ Display_rule.port_name_is "arm$valid"
        ; Display_rule.port_name_is "arm$on"
        ; Display_rule.port_name_is "pads" ~wave_format:Unsigned_int
        ; Display_rule.port_name_is "command" ~wave_format:Unsigned_int
        ; Display_rule.port_name_is "slot"
        ; Display_rule.port_name_is "write$valid"
        ; Display_rule.port_name_is "write$addr" ~wave_format:Hex
        ]
      ~signals_width:14
      ~display_width:90
      ~wave_width:0
      waves
  in
  Harness.run
    ~random_initial_state:`All
    ?print_waves_after_test:(Option.some_if waves print_waves_after_test)
    ~create:Journal.hierarchical
    (fun (h @ local) ~inputs:i ~outputs ->
       let o = Before_and_after_edge.before_edge outputs in
       let n = ref 0 in
       let cycle () =
         Lws.cycle h;
         if Bits.to_bool !(o.write.valid)
         then
           ring.(Bits.to_unsigned_int !(o.write.addr) - Journal.base)
           <- Bits.to_unsigned_int !(o.write.data);
         Int.incr n
       in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       let apply (s : Stimulus.t) =
         i.pads <--. s.pads;
         i.command <--. Journal.Code.to_int s.command;
         i.fault := Bits.of_bool s.fault;
         i.slot := Bits.of_bool (slot !n);
         cycle ();
         i.arm.valid := Bits.gnd
       in
       List.iteri stimuli ~f:(fun k s ->
         if k = 0
         then (
           i.arm.valid := Bits.vdd;
           i.arm.on := Bits.vdd);
         apply s);
       let last = List.last_exn stimuli in
       if disarm
       then (
         i.arm.valid := Bits.vdd;
         i.arm.on := Bits.gnd);
       for _ = 1 to 12 do
         apply (Stimulus.idle last.pads)
       done);
  Array.to_list ring
;;

(* The entries the journal should keep of [stimuli], from the arm to the disarm. *)
let reference (stimuli : Stimulus.t list) =
  let first = List.hd_exn stimuli in
  let arm = { Journal.Entry.code = Arm; pads = first.pads; delta = 0 } in
  let entries, since, previous =
    List.fold
      (List.tl_exn stimuli)
      ~init:([ arm ], 1, first.pads)
      ~f:(fun (entries, since, previous) (s : Stimulus.t) ->
        if s.pads <> previous || not ([%equal: Journal.Code.t] s.command Pads)
        then
          ( { Journal.Entry.code = s.command; pads = s.pads; delta = since } :: entries
          , 1
          , s.pads )
        else entries, since + 1, previous)
  in
  List.rev ({ Journal.Entry.code = Disarm; pads = previous; delta = since } :: entries)
;;

let random_stimuli ~seed ~cycles ~gap =
  let random = Random.State.make [| seed |] in
  let pads = ref (Random.State.int random (1 lsl Journal.pad_bits)) in
  let quiet = ref 0 in
  List.init cycles ~f:(fun _ ->
    if !quiet > 0 || Random.State.int random 3 > 0
    then (
      Int.decr quiet;
      Stimulus.idle !pads)
    else (
      quiet := gap;
      match Random.State.int random 5 with
      | 0 -> { pads = !pads; command = Control; fault = false }
      | 1 -> { pads = !pads; command = Tx; fault = false }
      | 2 -> { pads = !pads; command = Rx_pop; fault = false }
      | _ ->
        pads := !pads lxor (1 lsl Random.State.int random Journal.pad_bits);
        Stimulus.idle !pads))
;;

let%expect_test "an arm, two pad changes, a host push and the disarm" =
  let pads = [ 0x0; 0x0; 0x1; 0x1; 0x1; 0x1; 0x3; 0x3; 0x3; 0x3; 0x3 ] in
  let stimuli = List.map pads ~f:Stimulus.idle in
  let stimuli =
    List.mapi stimuli ~f:(fun k s -> if k = 8 then { s with command = Tx } else s)
  in
  let ring = record ~waves:true stimuli in
  let log = Journal.decode ring |> ok_exn in
  print_s [%message (log : Journal.Log.t)];
  [%test_result: Journal.Entry.t list] log.entries ~expect:(reference stimuli);
  [%expect
    {|
    ┌Signals─────┐┌Waves─────────────────────────────────────────────────────────────────────┐
    │arm$valid   ││  ┌─┐                   ┌─┐                                               │
    │            ││──┘ └───────────────────┘ └───────────────────────                        │
    │arm$on      ││  ┌─────────────────────┐                                                 │
    │            ││──┘                     └─────────────────────────                        │
    │            ││──────┬───────┬───────────────────────────────────                        │
    │pads        ││ 0    │1      │3                                                          │
    │            ││──────┴───────┴───────────────────────────────────                        │
    │            ││──────────────────┬─┬─────────────────────────────                        │
    │command     ││ 0                │2│0                                                    │
    │            ││──────────────────┴─┴─────────────────────────────                        │
    │slot        ││  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌───                        │
    │            ││──┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘                           │
    │write$valid ││      ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐                             │
    │            ││──────┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─────                        │
    │            ││──┬─────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬─────                        │
    │write$addr  ││ .│100  │101│102│103│104│105│106│107│108│109│10A                          │
    │            ││──┴─────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴─────                        │
    └────────────┘└──────────────────────────────────────────────────────────────────────────┘
    (log
     ((from_arm true)
      (entries
       (((code Arm) (pads 0) (delta 0)) ((code Pads) (pads 1) (delta 2))
        ((code Pads) (pads 3) (delta 4)) ((code Tx) (pads 3) (delta 2))
        ((code Disarm) (pads 3) (delta 3))))))
    |}]
;;

let%expect_test "random pads and host actions come back exactly" =
  List.iter [ 1; 2; 3 ] ~f:(fun seed ->
    let stimuli = random_stimuli ~seed ~cycles:400 ~gap:4 in
    let log = Journal.decode (record stimuli) |> ok_exn in
    [%test_result: bool] log.from_arm ~expect:true;
    [%test_result: Journal.Entry.t list] log.entries ~expect:(reference stimuli);
    print_s [%message (seed : int) ~entries:(List.length log.entries : int)]);
  [%expect
    {|
    ((seed 1) (entries 61))
    ((seed 2) (entries 59))
    ((seed 3) (entries 60))
    |}]
;;

let%expect_test "a burst it cannot keep ends the journal at the first entry lost" =
  let stimuli = List.init 12 ~f:Stimulus.idle in
  let log = Journal.decode (record stimuli) |> ok_exn in
  print_s [%message (log : Journal.Log.t)];
  [%expect
    {|
    (log
     ((from_arm true)
      (entries
       (((code Arm) (pads 0) (delta 0)) ((code Pads) (pads 1) (delta 1))
        ((code Lost) (pads 4) (delta 1))))))
    |}]
;;

let%expect_test "a fault ends the journal" =
  let stimuli =
    List.init 10 ~f:(fun k ->
      { (Stimulus.idle (Bool.to_int (k >= 3))) with fault = k >= 6 })
  in
  let log = Journal.decode (record ~disarm:false stimuli) |> ok_exn in
  print_s [%message (log : Journal.Log.t)];
  [%expect
    {|
    (log
     ((from_arm true)
      (entries
       (((code Arm) (pads 0) (delta 0)) ((code Pads) (pads 1) (delta 3))
        ((code Fault) (pads 1) (delta 3))))))
    |}]
;;

let%expect_test "past the ring the last entries stay, the arm gone" =
  let stimuli = List.init 700 ~f:(fun k -> Stimulus.idle (k / 5)) in
  let log = Journal.decode (record stimuli) |> ok_exn in
  let expected = reference stimuli in
  [%test_result: Journal.Entry.t list]
    log.entries
    ~expect:(List.drop expected (List.length expected - (Journal.words / 2)));
  print_s
    [%message
      (log.from_arm : bool)
        ~entries:(List.length log.entries : int)
        ~first:(List.hd_exn log.entries : Journal.Entry.t)];
  [%expect
    {|
    ((log.from_arm false) (entries 128)
     (first ((code Pads) (pads 13) (delta 5))))
    |}]
;;

let%expect_test "a long quiet spell is cut into full deltas" =
  let stimuli =
    List.init 70_000 ~f:(fun k -> Stimulus.idle (Bool.to_int (k >= 69_990)))
  in
  let log = Journal.decode (record stimuli) |> ok_exn in
  print_s [%message (log : Journal.Log.t)];
  [%expect
    {|
    (log
     ((from_arm true)
      (entries
       (((code Arm) (pads 0) (delta 0)) ((code Pads) (pads 0) (delta 65535))
        ((code Pads) (pads 1) (delta 4455)) ((code Disarm) (pads 1) (delta 10))))))
    |}]
;;

(* What [System_lockstep] feeds the chip from the arm to the first cycle it compares: the
   arm, idle cycles, the start and the cycle after it. *)
let lockstep_lead =
  List.init 8 ~f:(fun _ -> Stimulus.idle 0)
  @ [ { (Stimulus.idle 0) with command = Control }; Stimulus.idle 0 ]
;;

(* Random programs on both engines with the journal armed, pads and one host action at a
   time now and then: the chip holds with the model, which has no journal, and the ring
   says what came in, up to the first fault. Engine 0 streams from the low half only; an
   engine 1 streaming data keeps its turns and the journal writes nothing. *)
let%expect_test "random programs on two engines hold in lockstep and are journaled" =
  let random = Splittable_random.of_int 7 in
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let outcomes =
    List.init 32 ~f:(fun run ->
      let setups =
        List.init 2 ~f:(fun engine ->
          let config = Random_program.config random in
          let config =
            if engine = 0 || run % 4 > 0
            then { config with autopull_data = false }
            else config
          in
          { System_lockstep.Setup.config
          ; program = Random_program.program ~waits:`Input_pins random ~config
          ; preload = []
          ; data = []
          })
      in
      let levels = ref [ 0; 0 ] in
      let seen = Queue.create () in
      let level = ref 0 in
      (* every other run leaves the journal time to write each entry *)
      let quiet = ref 0 in
      let calm () = run % 2 = 1 || !quiet = 0 in
      let pads _ =
        if calm () && int 15 = 0
        then (
          level := !level lxor (1 lsl int (Isa.num_pins - 1));
          quiet := 5);
        !level
      in
      let host _ =
        let engine = int 1 in
        let action : Lockstep.Host.t =
          match if calm () then int 47 else 47 with
          | 0 when List.nth_exn !levels engine < Machine.fifo_depth ->
            { Lockstep.Host.idle with tx = Some (int 0xffff) }
          | 1 -> { Lockstep.Host.idle with pop_rx = true }
          | 2 -> { Lockstep.Host.idle with clear_irq = true }
          | _ -> Lockstep.Host.idle
        in
        let command : Journal.Code.t =
          match action with
          | { tx = Some _; _ } -> Tx
          | { pop_rx = true; _ } -> Rx_pop
          | { clear_irq = true; _ } -> Control
          | _ -> Pads
        in
        if not ([%equal: Journal.Code.t] command Pads) then quiet := 5;
        quiet := Int.max 0 (!quiet - 1);
        Queue.enqueue
          seen
          { Stimulus.pads = Journal.pads_of_pins !level; command; fault = false };
        List.init 2 ~f:(fun n -> if n = engine then action else Lockstep.Host.idle)
      in
      let faulted_at = ref None in
      let react (system : System.t) =
        levels := List.map system.engines ~f:(fun m -> List.length m.tx_fifo);
        if Option.is_none !faulted_at
           && List.exists system.engines ~f:(fun m ->
             not (Machine.Fault.equal m.fault Machine.Fault.none))
        then faulted_at := Some (Queue.length seen)
      in
      let ring = Array.create ~len:Journal.words 0 in
      match System_lockstep.run ~cycles:600 ~journal:ring ~host ~react ~pads setups with
      | _, Some mismatch ->
        print_s [%message "MISMATCH" (mismatch : System_lockstep.Mismatch.t)];
        "mismatch"
      | _, None ->
        let streams = (List.nth_exn setups 1).config.autopull_data in
        if streams
        then (
          [%test_result: int list]
            (Array.to_list ring)
            ~expect:(List.init Journal.words ~f:(fun _ -> 0));
          "engine 1 streams")
        else (
          let log = Journal.decode (Array.to_list ring) |> ok_exn in
          let stimuli = lockstep_lead @ Queue.to_list seen in
          let expected = reference stimuli in
          let kept = List.drop_last_exn log.entries in
          [%test_result: Journal.Entry.t list]
            kept
            ~expect:(List.take expected (List.length kept));
          let ended_at = List.sum (module Int) log.entries ~f:(fun e -> e.delta) in
          match (List.last_exn log.entries).code, !faulted_at with
          | Disarm, None ->
            [%test_result: Journal.Entry.t list] log.entries ~expect:expected;
            "whole"
          | Fault, Some run_cycle ->
            (* the fault shows the cycle after the step that raised it *)
            [%test_result: int] ended_at ~expect:(List.length lockstep_lead + run_cycle);
            "to the fault"
          | Lost, _ ->
            (* two entries too close, and the next one is where the journal stopped *)
            [%test_result: int]
              (List.last_exn log.entries).delta
              ~expect:(List.nth_exn expected (List.length kept)).delta;
            "to a burst"
          | code, faulted_at ->
            raise_s
              [%message
                "unexpected end" (code : Journal.Code.t) (faulted_at : int option)]))
  in
  let outcomes =
    List.sort_and_group outcomes ~compare:String.compare
    |> List.map ~f:(fun runs -> List.hd_exn runs, List.length runs)
  in
  print_s [%message (outcomes : (string * int) list)];
  [%expect
    {|
    (outcomes
     (("engine 1 streams" 6) ("to a burst" 6) ("to the fault" 18) (whole 2)))
    |}]
;;

(* The data memory in use by both sides at once: engine 0 streams the low half onto IO0-7
   while the journal writes the top half in engine 1's turns, and engine 1 takes a byte
   off IN0. *)
let%expect_test "engine 0 streams data while the journal writes" =
  let period = 16 in
  let byte = 0xa5 in
  let line n =
    match (n - 40) / period with
    | bit when n < 40 || bit >= 9 -> 1
    | 0 -> 0
    | bit -> (byte lsr (bit - 1)) land 1
  in
  let seen = Queue.create () in
  let pads n =
    Queue.enqueue seen (Stimulus.idle (line n));
    line n
  in
  let ring = Array.create ~len:Journal.words 0 in
  let system =
    System_lockstep.lockstep
      ~cycles:(40 + (10 * period))
      ~journal:ring
      ~pads
      [ { config =
            { Program_config.default with
              out_base = Isa.first_bidir_pin
            ; out_count = 8
            ; autopull = true
            ; autopull_data = true
            }
        ; program = Firmware.assemble (In_channel.read_all "data_stream.asm")
        ; preload = []
        ; data = [ 0x2211; 0x4433; 0x6655; 0x8877 ]
        }
      ; { config = Firmware.rx_config
        ; program = Firmware.assemble (Firmware.uart_rx ~period)
        ; preload = []
        ; data = []
        }
      ]
  in
  let log = Journal.decode (Array.to_list ring) |> ok_exn in
  let stimuli = lockstep_lead @ Queue.to_list seen in
  [%test_result: Journal.Entry.t list] log.entries ~expect:(reference stimuli);
  List.iteri system.engines ~f:(fun engine m ->
    print_s [%message (engine : int) (m.rx_fifo : int list) (m.fault : Machine.Fault.t)]);
  print_s [%message (log : Journal.Log.t)];
  [%expect
    {|
    ("lockstep held" (cycles 200))
    ((engine 0) (m.rx_fifo ())
     (m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((engine 1) (m.rx_fifo (165))
     (m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (log
     ((from_arm true)
      (entries
       (((code Arm) (pads 0) (delta 0)) ((code Control) (pads 0) (delta 8))
        ((code Pads) (pads 1) (delta 2)) ((code Pads) (pads 0) (delta 40))
        ((code Pads) (pads 1) (delta 16)) ((code Pads) (pads 0) (delta 16))
        ((code Pads) (pads 1) (delta 16)) ((code Pads) (pads 0) (delta 16))
        ((code Pads) (pads 1) (delta 32)) ((code Pads) (pads 0) (delta 16))
        ((code Pads) (pads 1) (delta 16)) ((code Disarm) (pads 1) (delta 32))))))
    |}]
;;
