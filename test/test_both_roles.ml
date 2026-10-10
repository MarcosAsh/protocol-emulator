open! Core
open Protocol_emulator
open Both_roles

let ok (outcome : Outcome.t) =
  List.for_all outcome.faults ~f:(Machine.Fault.equal Machine.Fault.none)
  && Option.is_none outcome.mismatch
;;

(* Every case on the RTL beside the model, each engine's pushes as the host pops them: the
   controller's acks (0 for an ACK) and read bytes or MISO bytes, the target's address and
   written bytes, MOSI bytes or received bytes. *)
let%expect_test "both roles on one chip, on the rtl" =
  List.iter Case.all ~f:(fun (c : Case.t) ->
    let outcome =
      rtl
        ~pads:c.pads
        ~cycles:c.cycles
        ~controller:{ timed = c.controller; words = c.controller_words }
        ~target:{ timed = c.target; words = c.target_words }
        ()
    in
    let hex = List.map ~f:(sprintf "%02x") in
    print_s
      [%message
        c.name
          ~controller:(hex outcome.controller : string list)
          ~target:(hex outcome.target : string list)
          ~irq:(outcome.irq : bool list)
          ~ok:(ok outcome : bool)]);
  [%expect
    {|
    ("I2C Standard-mode on wires" (controller (00 00 00 00 00 00 12 34 01))
     (target (84 10 5a 84 01 85)) (irq (false false)) (ok true))
    ("I2C Fast-mode on wires" (controller (00 00 00 00 00 00 12 34 01))
     (target (84 10 5a 84 01 85)) (irq (false false)) (ok true))
    ("SPI mode 0 on wires" (controller (11 22 33 44 55 66))
     (target (9f 00 00 a5 3c c3)) (irq (false false)) (ok true))
    ("SPI mode 1 on wires" (controller (11 22 33 44 55 66))
     (target (9f 00 00 a5 3c c3)) (irq (false false)) (ok true))
    ("SPI mode 2 on wires" (controller (11 22 33 44 55 66))
     (target (9f 00 00 a5 3c c3)) (irq (false false)) (ok true))
    ("SPI mode 3 on wires" (controller (11 22 33 44 55 66))
     (target (9f 00 00 a5 3c c3)) (irq (false false)) (ok true))
    ("UART 9600 baud on a wire" (controller ()) (target (55 a3 00 ff))
     (irq (false false)) (ok true))
    ("UART 19200 baud on a wire" (controller ()) (target (55 a3 00 ff))
     (irq (false false)) (ok true))
    ("UART 38400 baud on a wire" (controller ()) (target (55 a3 00 ff))
     (irq (false false)) (ok true))
    ("UART 57600 baud on a wire" (controller ()) (target (55 a3 00 ff))
     (irq (false false)) (ok true))
    ("UART 115200 baud on a wire" (controller ()) (target (55 a3 00 ff))
     (irq (false false)) (ok true))
    ("UART 230400 baud on a wire" (controller ()) (target (55 a3 00 ff))
     (irq (false false)) (ok true))
    |}]
;;

(* The rewrite for wires, each line of the library's I2C target it changes. *)
let%expect_test "the target's reads and drives on wires" =
  let library = Timed_program.source I2c.slave |> String.split_lines in
  let wire = I2c.slave_on_wires |> String.split_lines in
  let rec walk library wire =
    match library, wire with
    | l :: library, w :: wire when String.equal l w -> walk library wire
    | l :: library, w :: v :: wire when String.is_substring w ~substring:"!pins" ->
      printf "- %s\n+ %s\n+ %s\n" l w v;
      walk library wire
    | l :: library, w :: wire ->
      printf "- %s\n+ %s\n" l w;
      walk library wire
    | _ -> ()
  in
  walk library wire;
  [%expect
    {|
    -     set pindirs, 0           ; release SDA
    +     set pins, 0              ; release SDA
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     wait fall pin 12
    +     wait rise pin 20
    -     jmp pin, start           ; SCL still high: a start
    +     jmp !pin, start          ; SCL still high: a start
    -     wait 0 pin 13
    +     wait 1 pin 21
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     in pins, 1
    +     mov y, !pins
    +     in y, 1
    -     wait 0 pin 13
    +     wait 1 pin 21
    -     set pindirs, 1           ; ack
    +     set pins, 1              ; ack
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     wait 0 pin 13
    +     wait 1 pin 21
    -     set pindirs, 0
    +     set pins, 0
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     in pins, 2               ; SCL and SDA together
    +     mov y, !pins             ; SCL and SDA together
    +     in y, 2
    -     in pins, 2
    +     mov y, !pins
    +     in y, 2
    -     jmp pin, control
    +     jmp !pin, control
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     in pins, 1
    +     mov y, !pins
    +     in y, 1
    -     wait 0 pin 13
    +     wait 1 pin 21
    -     set pindirs, 1           ; ack
    +     set pins, 1              ; ack
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     wait 0 pin 13
    +     wait 1 pin 21
    -     set pindirs, 0
    +     set pins, 0
    -     in pins, 1
    +     mov y, !pins
    +     in y, 1
    -     set pindirs, 1           ; ack
    +     set pins, 1              ; ack
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     wait 0 pin 13
    +     wait 1 pin 21
    -     mov pindirs, !y          ; SDA follows the bit
    +     mov pins, !y             ; SDA follows the bit
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     wait 0 pin 13
    +     wait 1 pin 21
    -     set pindirs, 0           ; release SDA for the master's ack
    +     set pins, 0              ; release SDA for the master's ack
    -     wait 1 pin 13
    +     wait 0 pin 21
    -     in pins, 1
    +     mov y, !pins
    +     in y, 1
    -     wait 0 pin 13
    +     wait 1 pin 21
    |}]
;;

(* The tooth: the library's open drain firmware moved to wires unchanged drives them by
   [pindirs], which a wire ignores, so the wires stay 0: the controller reads an ACK and 0
   bits from nobody, and the target a bus held low, and takes nothing. *)
let%expect_test "the library's firmware on wires without the rewrite" =
  let pins = [ I2c.sda, I2c.wire_sda; I2c.scl, I2c.wire_scl ] in
  let unrewritten ?period_floor source config =
    Timed_program.of_source_exn
      ?period_floor
      ~config:{ config with Program_config.side_set_pindirs = true }
      (On_wire.move_pins ~pins source)
  in
  let c = List.hd_exn Case.all in
  let outcome =
    model
      ~cycles:c.cycles
      ~controller:
        { timed =
            unrewritten
              ~period_floor:31
              I2c.master_host_rate_without_bus_clear
              I2c.master_on_wires_config
        ; words = c.controller_words
        }
      ~target:
        { timed = unrewritten (Timed_program.source I2c.slave) I2c.slave_on_wires_config
        ; words = c.target_words
        }
      ()
  in
  print_s [%message (outcome.controller : int list) (outcome.target : int list)];
  [%expect {| ((outcome.controller (0 0 0 0 0 0 0 0 0)) (outcome.target ())) |}]
;;

(* The sender's bit off the receiver's by a whole percent at a time, both ways, at each
   rate and two above them. *)
let%expect_test "the uart receiver's tolerance at each rate" =
  let uart =
    List.find_exn Case.all ~f:(fun c -> String.is_prefix c.name ~prefix:"UART")
  in
  List.iter
    (Uart.bauds @ [ 460800; 921600 ])
    ~f:(fun baud ->
      let half = ((Bench.clock_hz / baud) + 1) / 2 in
      let bytes = List.tl_exn uart.controller_words in
      let tolerated percent =
        let sent =
          Float.iround_nearest_exn (Float.of_int (2 * half) *. (1. +. (percent /. 100.)))
        in
        let outcome =
          model
            ~cycles:(100 + (List.length bytes * 11 * sent))
            ~controller:{ timed = uart.controller; words = sent :: bytes }
            ~target:{ timed = uart.target; words = [ half ] }
            ()
        in
        [%equal: int list] outcome.target bytes && not (List.nth_exn outcome.irq 1)
      in
      let widest ~sign =
        List.range 0 10
        |> List.take_while ~f:(fun n -> tolerated (Float.of_int (sign * n)))
        |> List.last
      in
      print_s
        [%message
          ""
            (baud : int)
            ~bit:(2 * half : int)
            ~slow_percent:(widest ~sign:1 : int option)
            ~fast_percent:(widest ~sign:(-1) : int option)]);
  [%expect
    {|
    ((baud 9600) (bit 5000) (slow_percent (5)) (fast_percent (5)))
    ((baud 19200) (bit 2500) (slow_percent (5)) (fast_percent (5)))
    ((baud 38400) (bit 1250) (slow_percent (5)) (fast_percent (5)))
    ((baud 57600) (bit 834) (slow_percent (5)) (fast_percent (5)))
    ((baud 115200) (bit 416) (slow_percent (5)) (fast_percent (5)))
    ((baud 230400) (bit 208) (slow_percent (5)) (fast_percent (5)))
    ((baud 460800) (bit 104) (slow_percent (5)) (fast_percent (5)))
    ((baud 921600) (bit 52) (slow_percent (4)) (fast_percent (4)))
    |}]
;;
