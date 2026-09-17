open! Core
open Protocol_emulator

let tx_pin = 5
let assemble source = Asm.assemble source |> ok_exn |> Asm.Program.words |> ok_exn

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

let uart_tx ~period =
  [%string
    {|
    set p, %{period#Int}
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov t, now               ; anchor the frame
    set pins, 0              ; start bit
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    wait t
    jmp idle
|}]
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

(* Receive on IN0, sampling mid bit from a deadline anchored to the captured start edge.
   The capture unit is armed again right after the last data bit, so a start edge that
   arrives while the core is still checking the stop bit is not lost. The sample lands one
   cycle after the deadline releases, so the half period is one short. The byte is shifted
   in LSB first and [in null, 8] moves it down from the top of the isr. *)
let uart_rx ~period =
  [%string
    {|
    set p, %{period#Int}
    set y, %{(period / 2) - 1#Int}
    wait 1 pin 0             ; line idle
    capture_arm
idle:
    wait 0 pin 0             ; start bit, its edge cycle is in capture
    mov t, capture
    add t, y
    add t, p                 ; middle of bit 0
    set x, 7
bit:
    wait t+
    in pins, 1
    jmp x--, bit
    capture_arm              ; watch for the next start edge from here on
    in null, 8
    push
    wait t                   ; middle of the stop bit
    jmp pin, idle
    irq                      ; framing error
    wait 1 pin 0
    capture_arm
    jmp idle
|}]
;;

let rx_config =
  { Program_config.default with
    in_base = 0
  ; jmp_pin = 0
  ; capture_pin = 0
  ; capture_rising = false
  }
;;

(* Idle high, then each byte as start, eight data bits LSB first and a stop bit. *)
let serial_levels bytes ~period ~stop =
  let bit b = List.init period ~f:(fun _ -> b) in
  List.init 20 ~f:(fun _ -> 1)
  @ List.concat_map bytes ~f:(fun byte ->
    List.concat_map
      ((0 :: List.init 8 ~f:(fun i -> (byte lsr i) land 1)) @ [ stop ])
      ~f:bit)
  @ List.init (4 * period) ~f:(fun _ -> 1)
;;

let receive levels ~period =
  let t =
    Machine.create ~config:rx_config ~program:(assemble (uart_rx ~period)) |> ok_exn
  in
  let t, received =
    List.fold levels ~init:(t, []) ~f:(fun (t, received) level ->
      let t = Machine.step t ~inputs:level in
      match Machine.read_rx t with
      | Some (byte, t) -> t, byte :: received
      | None -> t, received)
  in
  print_s
    [%message
      (List.rev received : int list)
        (t.fault : Machine.Fault.t)
        (t.irq : bool)
        (t.pc : int)]
;;

let%expect_test "uart rx receives bytes sampled mid bit" =
  let period = 16 in
  receive (serial_levels [ 0x55; 0xa3; 0xff; 0x00 ] ~period ~stop:1) ~period;
  [%expect
    {|
    (("List.rev received" (85 163 255 0))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq false) (t.pc 4))
    |}]
;;

(* 8N1 must survive a baud error of a few percent. The sample lands one cycle after the
   release, so the receiver already leans late and a fast sender is the harder direction. *)
let%expect_test "uart rx tolerates the sender being four percent off" =
  List.iter [ 24; 26 ] ~f:(fun sender_period ->
    receive (serial_levels [ 0x55; 0xa3; 0x0f ] ~period:sender_period ~stop:1) ~period:25);
  [%expect
    {|
    (("List.rev received" (85 163 15))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq false) (t.pc 4))
    (("List.rev received" (85 163 15))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq false) (t.pc 4))
    |}]
;;

let%expect_test "a missing stop bit raises the interrupt" =
  let period = 16 in
  receive (serial_levels [ 0x42 ] ~period ~stop:0) ~period;
  [%expect
    {|
    (("List.rev received" (66))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.irq true) (t.pc 4))
    |}]
;;

let%expect_test "a deadline that is already past releases at once and is a fault" =
  let program = assemble {|
    mov t, now
    wait t
    halt
|} in
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
  let program = assemble {|
    pull
    halt
|} in
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
      {|
    capture_arm
    wait rise pin 0
    mov x, capture
    mov y, now
    halt
|}
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
