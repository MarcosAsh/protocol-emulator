open! Core
open Protocol_emulator
open Firmware

(* The cycle the assumption fault rose, if it did, with the core and the model in step. *)
let run ?(cycles = 120) ?(preload = []) ~premises ~config ~inputs source =
  let rose = ref None in
  let cycle = ref 0 in
  let react (m : Machine.t) =
    if m.fault.assumption && Option.is_none !rose then rose := Some !cycle;
    incr cycle
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles
      ~preload
      ~premises
      ~config
      ~program:(assemble source)
      ~inputs
      ~react
      ()
  in
  print_s [%message "" ~assumption_at:(!rose : int option)]
;;

(* a period from the host, then a deadline every period *)
let periodic = {|
    pull
    mov p, osr
    mov t, now
loop:
    wait t+
    jmp loop
|}

let%expect_test "a period other than the loaded one faults at its first use" =
  let exactly period = { Machine.Premises.none with period = Some period } in
  let at_least period = { (exactly period) with floor = true } in
  List.iter
    [ "loaded", exactly 10, 10
    ; "another", exactly 10, 11
    ; "above the floor", at_least 10, 11
    ; "below the floor", at_least 10, 9
    ]
    ~f:(fun (name, premises, period) ->
      print_endline name;
      run
        ~preload:[ period ]
        ~premises
        ~config:Program_config.default
        ~inputs:(fun _ -> 0)
        periodic);
  [%expect
    {|
    loaded
    ("lockstep held" (cycles 120))
    (assumption_at ())
    another
    ("lockstep held" (cycles 120))
    (assumption_at (3))
    above the floor
    ("lockstep held" (cycles 120))
    (assumption_at ())
    below the floor
    ("lockstep held" (cycles 120))
    (assumption_at (3))
    |}]
;;

(* p may hold anything between uses: a set replaces a loaded value, and a value never
   taken as a period is never judged *)
let%expect_test "p as a scratch register between uses" =
  run
    ~preload:[ 3; 10 ]
    ~premises:{ Machine.Premises.none with period = Some 10 }
    ~config:Program_config.default
    ~inputs:(fun _ -> 0)
    {|
    pull
    mov p, osr               ; 3, not the period
    add x, p                 ; used as data
    set p, 7                 ; a set, which the certificate knows
    mov t, now
    wait t+
    pull
    mov p, osr               ; 10, the period
    wait t+
    add t, p
    wait t
    halt
|};
  [%expect {|
    ("lockstep held" (cycles 120))
    (assumption_at ())
    |}]
;;

let line = 0

(* arm, then a long way before the wait for the falling edge on [line] *)
let receiver =
  {|
    capture_arm
    nop [15]
    nop [15]
    wait 0 pin 0
    mov t, capture
    halt
|}
;;

let%expect_test "the capture pin breaks the single edge" =
  let config =
    { Program_config.default with capture_pin = line; capture_rising = false }
  in
  let premises = { Machine.Premises.none with single_edge = true } in
  let level_at intervals n =
    if List.exists intervals ~f:(fun (lo, hi) -> n >= lo && n < hi) then 0 else 1
  in
  List.iter
    [ "falls and stays low", [ 10, 1000 ]
    ; "low at the arm", [ 0, 1000 ]
    ; "falls and rises before the wait", [ 10, 12 ]
    ; "falls after the wait issues", [ 50, 1000 ]
    ; "falls twice, low by the wait", [ 10, 12; 20, 1000 ]
    ]
    ~f:(fun (name, low) ->
      print_endline name;
      run ~premises ~config ~inputs:(fun n -> level_at low n lsl line) receiver);
  [%expect
    {|
    falls and stays low
    ("lockstep held" (cycles 120))
    (assumption_at ())
    low at the arm
    ("lockstep held" (cycles 120))
    (assumption_at (0))
    falls and rises before the wait
    ("lockstep held" (cycles 120))
    (assumption_at (12))
    falls after the wait issues
    ("lockstep held" (cycles 120))
    (assumption_at ())
    falls twice, low by the wait
    ("lockstep held" (cycles 120))
    (assumption_at (12))
    |}]
;;

(* the same capture pin, without the premise: nothing is judged *)
let%expect_test "no premise, no fault" =
  let config =
    { Program_config.default with capture_pin = line; capture_rising = false }
  in
  run
    ~premises:Machine.Premises.none
    ~config
    ~inputs:(fun n -> if n >= 10 && n < 12 then 0 else 1)
    receiver;
  run
    ~preload:[ 11 ]
    ~premises:Machine.Premises.none
    ~config:Program_config.default
    ~inputs:(fun _ -> 0)
    periodic;
  [%expect
    {|
    ("lockstep held" (cycles 120))
    (assumption_at ())
    ("lockstep held" (cycles 120))
    (assumption_at ())
    |}]
;;
