open! Core
open Protocol_emulator
open Firmware

let period = 16

(* a transmitter on one engine and a receiver on the other, with nothing outside the chip *)
let cross_wired ~line ~transmitter =
  let rx_config = { rx_config with in_base = line; jmp_pin = line; capture_pin = line } in
  let system =
    System_lockstep.lockstep
      ~cycles:500
      ~pads:(fun _ -> 0)
      [ { config = { Program_config.default with set_base = line; out_base = line }
        ; program = assemble transmitter
        ; preload = [ 0x55; 0xa3 ]
        }
      ; { config = rx_config
        ; program = assemble (uart_rx_on ~pin:line ~period)
        ; preload = []
        }
      ]
  in
  List.iteri system.engines ~f:(fun engine m ->
    print_s
      [%message
        ""
          (engine : int)
          (m.rx_fifo : int list)
          (m.irq : bool)
          (m.fault : Machine.Fault.t)])
;;

let%expect_test "uart from one engine to the other over a pin" =
  cross_wired
    ~line:Isa.first_bidir_pin
    ~transmitter:("    set pindirs, 1\n" ^ uart_tx ~period);
  [%expect
    {|
    ("lockstep held" (cycles 500))
    ((engine 0) (m.rx_fifo ()) (m.irq false)
     (m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((engine 1) (m.rx_fifo (85 163)) (m.irq false)
     (m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "uart from one engine to the other over a wire" =
  cross_wired ~line:Isa.num_pins ~transmitter:(uart_tx ~period);
  [%expect
    {|
    ("lockstep held" (cycles 500))
    ((engine 0) (m.rx_fifo ()) (m.irq false)
     (m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((engine 1) (m.rx_fifo (85 163)) (m.irq false)
     (m.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* random programs on both engines, random pads and both hosts busy: whatever the engines
   do to each other's pins and wires, the chip and the model agree *)
let%expect_test "random programs on two engines in lockstep" =
  let random = Splittable_random.of_int 5 in
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let failed =
    List.init 12 ~f:(fun seed ->
      let setups =
        List.init 2 ~f:(fun _ ->
          let config = Random_program.config random in
          { System_lockstep.Setup.config
          ; program = Random_program.program ~waits:`Input_pins random ~config
          ; preload = []
          })
      in
      let levels = ref [ 0; 0 ] in
      let host _ =
        List.map !levels ~f:(fun level ->
          { Lockstep.Host.idle with
            tx =
              (if level < Machine.fifo_depth && int 3 = 0 then Some (int 0xffff) else None)
          ; pop_rx = int 3 = 0
          })
      in
      let react (system : System.t) =
        levels := List.map system.engines ~f:(fun m -> List.length m.tx_fifo)
      in
      let pads _ = int ((1 lsl Isa.num_pins) - 1) in
      match System_lockstep.run ~cycles:200 ~host ~react ~pads setups with
      | _, None -> None
      | _, Some mismatch ->
        print_s [%message "MISMATCH" (seed : int) (mismatch : System_lockstep.Mismatch.t)];
        Some seed)
    |> List.filter_opt
  in
  print_s [%message (failed : int list)];
  [%expect {| (failed ()) |}]
;;
