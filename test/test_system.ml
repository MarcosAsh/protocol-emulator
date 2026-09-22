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
    List.init 32 ~f:(fun seed ->
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
      match System_lockstep.run ~cycles:1000 ~host ~react ~pads setups with
      | _, None -> None
      | _, Some mismatch ->
        print_s [%message "MISMATCH" (seed : int) (mismatch : System_lockstep.Mismatch.t)];
        Some seed)
    |> List.filter_opt
  in
  print_s [%message (failed : int list)];
  [%expect {| (failed ()) |}]
;;

(* The chip checks its own timing: engine 0 sends two bytes at 115200 baud over a wire,
   engine 1 stamps every edge on it, and the host pops the stamps whenever it likes. The
   certificate says every edge of the transmitter lands a fixed number of cycles after a
   deadline with no jitter, and the deadlines move by the bit period, so each edge of a
   frame is a whole number of bit periods after its start bit: what the table predicts.
   The one unbounded edge is the line going idle, before there is a deadline at all. *)
let%expect_test "one engine times the other's uart edges" =
  let line = Isa.num_pins in
  let period = 434 in
  let bytes = [ 0x55; 0xa3 ] in
  let transmitter = { Program_config.default with set_base = line; out_base = line } in
  Timing_report.print ~config:transmitter ~period uart_tx_host_rate;
  let random = Splittable_random.of_int 1 in
  let fifo = ref [] in
  let stamps = ref [] in
  let host _ =
    let pop = (not (List.is_empty !fifo)) && Splittable_random.bool random in
    if pop then stamps := List.hd_exn !fifo :: !stamps;
    [ Lockstep.Host.idle; { Lockstep.Host.idle with pop_rx = pop } ]
  in
  let react (system : System.t) = fifo := (List.nth_exn system.engines 1).rx_fifo in
  let (_ : System.t) =
    System_lockstep.lockstep
      ~cycles:10_000
      ~host
      ~react
      ~pads:(fun _ -> 0)
      [ { config = transmitter
        ; program = assemble uart_tx_host_rate
        ; preload = period :: bytes
        }
      ; { config = edge_logger_config ~pin:line
        ; program = assemble (edge_logger ~pin:line)
        ; preload = []
        }
      ]
  in
  (* the first stamp is the line going idle; then each frame, start bit first *)
  let frame byte =
    let levels = (0 :: List.init 8 ~f:(fun i -> (byte lsr i) land 1)) @ [ 1 ] in
    List.filter_mapi levels ~f:(fun bit level ->
      let before = if bit = 0 then 1 else List.nth_exn levels (bit - 1) in
      Option.some_if (level <> before) (level, bit * period))
  in
  let rec table stamps = function
    | [] -> ()
    | byte :: rest ->
      let edges = frame byte in
      let #(measured, stamps) = List.split_n stamps (List.length edges) in
      let start = List.hd_exn measured in
      List.iter2_exn edges measured ~f:(fun (level, predicted) stamp ->
        printf
          "0x%02x  %s  %9d  %8d\n"
          byte
          (if level = 1 then "rise" else "fall")
          predicted
          ((stamp - start) land 0xffff));
      table stamps rest
  in
  print_endline "byte  edge  predicted  measured";
  table (List.drop (List.rev !stamps) 1) bytes;
  [%expect
    {|
      3  set pins, 1                  phase ?..?  edge ?..?  jitter ?  gap ?..?
      8  set pins, 0                  phase 1  edge 2  gap 5..?
     11  out pins, 1                  phase -433  edge -432  gap 433..435
     14  set pins, 1                  phase -433  edge -432  gap 434
    ((words 17) (edge_jitter unbounded) (sample_jitter 0) (side_jitter 0)
     (may_miss 0))
    ("lockstep held" (cycles 10000))
    byte  edge  predicted  measured
    0x55  fall          0         0
    0x55  rise        434       434
    0x55  fall        868       868
    0x55  rise       1302      1302
    0x55  fall       1736      1736
    0x55  rise       2170      2170
    0x55  fall       2604      2604
    0x55  rise       3038      3038
    0x55  fall       3472      3472
    0x55  rise       3906      3906
    0xa3  fall          0         0
    0xa3  rise        434       434
    0xa3  fall       1302      1302
    0xa3  rise       2604      2604
    0xa3  fall       3038      3038
    0xa3  rise       3472      3472
    |}]
;;
