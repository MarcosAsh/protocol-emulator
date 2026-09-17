open! Core
open Protocol_emulator

let tx_pin = 5

let assemble ?(side_set_count = 0) program =
  List.map program ~f:(fun t -> Isa.to_word ~side_set_count t |> ok_exn)
;;

let op ?(delay = 0) ?(side_set = 0) op : Isa.t = Op { op; delay; side_set }

let run t ~cycles ~inputs =
  let rec loop t n acc =
    if n = 0
    then t, List.rev acc
    else (
      let t = Machine.step t ~inputs in
      loop t (n - 1) (((t.pin_out lsr tx_pin) land 1) :: acc))
  in
  loop t cycles []
;;

let runs levels =
  List.group levels ~break:(fun a b -> a <> b)
  |> List.map ~f:(fun g -> List.hd_exn g, List.length g)
;;

(* 8N1 at [period] cycles per bit, LSB first, sampled mid bit after each start edge. *)
let decode_uart levels ~period =
  let levels = Array.of_list levels in
  let rec frames i acc =
    if i + (10 * period) > Array.length levels
    then List.rev acc
    else if levels.(i) = 0 && (i = 0 || levels.(i - 1) = 1)
    then (
      let byte =
        List.init 8 ~f:(fun b -> levels.(i + ((b + 1) * period) + (period / 2)) lsl b)
        |> List.fold ~init:0 ~f:( lor )
      in
      frames (i + (10 * period)) (byte :: acc))
    else frames (i + 1) acc
  in
  frames 0 []
;;

let uart_tx ~period : Isa.t list =
  [ op (Set { dest = P; value = period })
  ; op (Set { dest = Pins; value = 1 })
  ; op (Wait (Fifo Tx_not_empty))
  ; op (Sys Pull)
  ; op (Set { dest = X; value = 7 })
  ; op (Mov { dest = T; op = Copy; source = Now })
  ; op (Set { dest = Pins; value = 0 })
  ; op (Alu { dest = T; op = Add; operand = Reg P })
  ; op (Wait (Deadline { advance = true }))
  ; op (Out { dest = Pins; count = 1 })
  ; Jmp { cond = X_dec; target = 8 }
  ; op (Wait (Deadline { advance = true }))
  ; op (Set { dest = Pins; value = 1 })
  ; op (Wait (Deadline { advance = false }))
  ; Jmp { cond = Always; target = 2 }
  ]
;;

let%expect_test "uart tx sends two bytes with exact bit periods" =
  let period = 16 in
  let t =
    Machine.create ~config:Program_config.default ~program:(assemble (uart_tx ~period))
    |> ok_exn
  in
  let t = Machine.write_tx t 0x55 |> ok_exn in
  let t = Machine.write_tx t 0xa3 |> ok_exn in
  let t, levels = run t ~cycles:400 ~inputs:0 in
  print_s [%message (runs levels : (int * int) list)];
  print_s [%message (decode_uart levels ~period : int list)];
  print_s [%message (t.fault : Machine.Fault.t) (t.pc : int) (t.now : int)];
  [%expect
    {|
    ("runs levels"
     ((0 1) (1 5) (0 16) (1 16) (0 16) (1 16) (0 16) (1 16) (0 16) (1 16)
      (0 16) (1 22) (0 16) (1 32) (0 48) (1 16) (0 16) (1 100)))
    ("decode_uart levels ~period" (85 163))
    ((t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 2) (t.now 400))
    |}]
;;

let%expect_test "a deadline that is already past releases at once and is a fault" =
  let program =
    assemble
      [ op (Mov { dest = T; op = Copy; source = Now })
      ; op (Wait (Deadline { advance = false }))
      ; op (Sys Halt)
      ]
  in
  let t = Machine.create ~config:Program_config.default ~program |> ok_exn in
  let t, _ = run t ~cycles:6 ~inputs:0 in
  print_s [%message (t.fault : Machine.Fault.t) (t.halted : bool) (t.now : int)];
  [%expect
    {|
    ((t.fault
      ((underflow false) (overflow false) (missed_deadline true) (decode false)))
     (t.halted true) (t.now 6))
    |}]
;;

let%expect_test "pull from an empty fifo faults instead of stalling" =
  let program = assemble [ op (Sys Pull); op (Sys Halt) ] in
  let t = Machine.create ~config:Program_config.default ~program |> ok_exn in
  let t, _ = run t ~cycles:4 ~inputs:0 in
  print_s [%message (t.fault : Machine.Fault.t) (t.halted : bool)];
  [%expect
    {|
    ((t.fault
      ((underflow true) (overflow false) (missed_deadline false) (decode false)))
     (t.halted true))
    |}]
;;

let%expect_test "input capture timestamps a rising edge" =
  let program =
    assemble
      [ op (Sys Capture_arm)
      ; op (Wait (Pin_edge { pin = 0; rising = true }))
      ; op (Mov { dest = X; op = Copy; source = Capture })
      ; op (Mov { dest = Y; op = Copy; source = Now })
      ; op (Sys Halt)
      ]
  in
  let t = Machine.create ~config:Program_config.default ~program |> ok_exn in
  let t, _ = run t ~cycles:10 ~inputs:0 in
  let t, _ = run t ~cycles:10 ~inputs:1 in
  print_s [%message (t.x : int) (t.y : int) (t.halted : bool)];
  [%expect {| ((t.x 10) (t.y 12) (t.halted true)) |}]
;;

let%expect_test "a word that does not decode halts with a fault" =
  let t = Machine.create ~config:Program_config.default ~program:[ 0xe0ff ] |> ok_exn in
  let t, _ = run t ~cycles:3 ~inputs:0 in
  print_s [%message (t.fault : Machine.Fault.t) (t.halted : bool) (t.pc : int)];
  [%expect
    {|
    ((t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode true)))
     (t.halted true) (t.pc 0))
    |}]
;;
