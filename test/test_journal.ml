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
