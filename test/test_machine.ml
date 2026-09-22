open! Core
open Protocol_emulator
open Firmware
open Protocol_models
open Machine_run

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

(* P3: the host reaches the pins through the words it sends, never through when it sends
   them. Two runs of one program get the same words in the same order, one whenever the
   fifo has room and one at random, and pop the rx fifo on different schedules. Their pins
   agree every cycle unless the random schedule starved or flooded a fifo, which the fault
   register reports. Programs with [wait tx] or [wait rx] block on the host on purpose and
   are left out. *)
let%expect_test "host timing never reaches the pins" =
  let random = Splittable_random.of_int 3 in
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let cycles = 2000 in
  let words_pulled = ref 0 in
  let trial () =
    let config = Random_program.config random in
    let program = Random_program.program ~waits:`Input_pins random ~config in
    let inputs = List.init cycles ~f:(fun _ -> int ((1 lsl Isa.pin_space) - 1)) in
    let words = Array.init (cycles + Machine.fifo_depth) ~f:(fun _ -> int 0xffff) in
    let run ~push ~pop =
      let next = ref 0 in
      let feed (t : Machine.t) =
        if push (List.length t.tx_fifo)
        then (
          let t = Machine.write_tx t words.(!next) |> ok_exn in
          Int.incr next;
          t)
        else t
      in
      let preload (t : Machine.t) =
        if List.length t.tx_fifo < Machine.fifo_depth
        then Machine.write_tx t words.(!next) |> ok_exn
        else t
      in
      let t = Machine.create ~config ~program |> ok_exn in
      let t =
        Fn.apply_n_times
          ~n:Machine.fifo_depth
          (fun t ->
            Int.incr next;
            preload t)
          t
      in
      let t, trace =
        List.fold_map inputs ~init:t ~f:(fun t levels ->
          let t =
            match Machine.read_rx t with
            | Some (_, popped) when pop () -> popped
            | _ -> t
          in
          let t = Machine.step t ~inputs:levels |> feed in
          t, (t.pin_out, t.pin_dir))
      in
      t, trace, !next - Machine.fifo_depth
    in
    let _, eager, pulled =
      run ~push:(fun level -> level < Machine.fifo_depth) ~pop:(fun () -> true)
    in
    words_pulled := !words_pulled + pulled;
    let (t : Machine.t), lazily, _ =
      run
        ~push:(fun level -> level < Machine.fifo_depth && int 3 > 0)
        ~pop:(fun () -> int 1 = 0)
    in
    if t.fault.underflow || t.fault.overflow
    then `Inconclusive
    else if List.equal [%equal: int * int] eager lazily
    then `Agree
    else `Disagree
  in
  let programs = 64 in
  let results = List.init programs ~f:(fun _ -> trial ()) in
  let count outcome = List.count results ~f:(fun r -> Poly.equal r outcome) in
  let agree = count `Agree in
  let disagree = count `Disagree in
  let words_pulled = !words_pulled in
  print_s [%message (programs : int) (words_pulled : int) (agree : int) (disagree : int)];
  [%expect {| ((programs 64) (words_pulled 344) (agree 64) (disagree 0)) |}]
;;

(* the check values of CRC-16/USB and CRC-5/USB over "123456789" are 0xb4c8 and 0x19, both
   after the final inversion the firmware does with [mov] *)
let crc_of_bytes ~config bytes =
  let program =
    assemble
      {|
byte:
    wait tx
    pull
    set x, 7
bit:
    out pins, 1
    jmp x--, bit
    jmp byte
|}
  in
  let t = Machine.create ~config ~program |> ok_exn in
  let feed t bytes =
    match bytes with
    | b :: rest when List.length t.Machine.tx_fifo < Machine.fifo_depth ->
      Machine.write_tx t b |> ok_exn, rest
    | bytes -> t, bytes
  in
  let rec loop t bytes n =
    if n = 0
    then t
    else (
      let t, bytes = feed t bytes in
      loop (Machine.step t ~inputs:0) bytes (n - 1))
  in
  let t = loop t bytes (50 * List.length bytes) in
  t.crc, t.fault
;;

let check_bytes = String.to_list "123456789" |> List.map ~f:Char.to_int

let%expect_test "crc-16/usb over the check string" =
  let crc, fault = crc_of_bytes ~config:Program_config.default check_bytes in
  print_s [%message (crc lxor 0xffff : Int.Hex.t) (fault : Machine.Fault.t)];
  [%expect
    {|
    (("crc lxor 0xffff" 0xb4c8)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "crc-5/usb over the check string" =
  let config =
    { Program_config.default with crc_width = 5; crc_poly = 0x14; crc_init = 0x1f }
  in
  let crc, fault = crc_of_bytes ~config check_bytes in
  print_s [%message (crc lxor 0x1f : Int.Hex.t) (fault : Machine.Fault.t)];
  [%expect
    {|
    (("crc lxor 0x1f" 0x19)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "crc-16/xmodem shifts the other way" =
  let config =
    { Program_config.default with
      out_shift = Left
    ; crc_poly = 0x1021
    ; crc_init = 0
    ; crc_reflect = false
    }
  in
  let crc, fault = crc_of_bytes ~config (List.map check_bytes ~f:(fun b -> b lsl 8)) in
  print_s [%message (crc : Int.Hex.t) (fault : Machine.Fault.t)];
  [%expect
    {|
    ((crc 0x31c3)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "a stuffed zero follows every six ones" =
  let config = { Program_config.default with stuff_threshold = 6 } in
  let program =
    assemble
      {|
    pull
    set x, 15
bit:
    out pins, 1
    jmp stuff, stuff
    jmp x--, bit
    halt
stuff:
    set pins, 0
    stuff_reset
    jmp x--, bit
    halt
|}
  in
  let t = Machine.create ~config ~program |> ok_exn in
  let t = Machine.write_tx t 0xffff |> ok_exn in
  let t, levels = run t ~cycles:120 ~inputs:0 in
  print_s
    [%message (runs levels : (int * int) list) (t.halted : bool) (t.crc : Int.Hex.t)];
  [%expect
    {|
    (("runs levels" ((0 2) (1 28) (0 4) (1 28) (0 4) (1 54))) (t.halted true)
     (t.crc 0x0))
    |}]
;;

let%expect_test "a wrapped loop costs no cycles" =
  let program =
    assemble
      {|
    set p, 2
    mov t, now
    add t, p
    wait t+
    mov pins, !pins
|}
  in
  let config =
    { Program_config.default with in_base = 5; wrap_bottom = 3; wrap_top = 4 }
  in
  let t = Machine.create ~config ~program |> ok_exn in
  let t, levels = run t ~cycles:20 ~inputs:0 in
  print_s [%message (runs levels : (int * int) list) (t.fault : Machine.Fault.t)];
  [%expect
    {|
    (("runs levels" ((0 4) (1 2) (0 2) (1 2) (0 2) (1 2) (0 2) (1 2) (0 2)))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
