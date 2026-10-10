open! Core
open Protocol_emulator

let wire n = Isa.num_pins + n

(* a line of code as tokens, its comment kept apart *)
let split line =
  let code, comment =
    match String.lsplit2 line ~on:';' with
    | Some (code, comment) -> code, Some comment
    | None -> line, None
  in
  String.split code ~on:' ' |> List.filter ~f:(Fn.non String.is_empty), comment
;;

(* the comment kept at its column *)
let join ?(column = 0) ?comment tokens =
  let code = "    " ^ String.concat ~sep:" " tokens in
  match comment with
  | None -> code
  | Some comment ->
    let code = String.pad_right code ~len:(Int.max column (String.length code + 1)) in
    [%string "%{code};%{comment}"]
;;

let renumber ~pins token =
  match List.Assoc.find pins ~equal:Int.equal (Int.of_string token) with
  | Some moved -> Int.to_string moved
  | None -> raise_s [%message "BUG: a pin with nowhere to go" token]
;;

let move_pins ~pins source =
  String.split_lines source
  |> List.map ~f:(fun line ->
    let column = String.index line ';' |> Option.value ~default:0 in
    match split line with
    | "wait" :: level :: "pin" :: n :: rest, comment ->
      join ~column ?comment ("wait" :: level :: "pin" :: renumber ~pins n :: rest)
    | _ -> line)
  |> String.concat_lines
;;

let open_drain_on_wire ~pins source =
  let pin = renumber ~pins in
  let flip = function
    | "0" -> "1"
    | "1" -> "0"
    | "rise" -> "fall"
    | "fall" -> "rise"
    | level -> raise_s [%message "BUG: not a level" level]
  in
  String.split_lines source
  |> List.concat_map ~f:(fun line ->
    let column = String.index line ';' |> Option.value ~default:0 in
    let join = join ~column in
    match split line with
    | (("set" | "mov") as op) :: "pindirs," :: rest, comment ->
      [ join ?comment (op :: "pins," :: rest) ]
    | "in" :: "pins," :: count :: rest, comment ->
      [ join ?comment ("mov" :: "y," :: "!pins" :: rest)
      ; join ("in" :: "y," :: count :: rest)
      ]
    | "wait" :: level :: "pin" :: n :: rest, comment ->
      [ join ?comment ("wait" :: flip level :: "pin" :: pin n :: rest) ]
    | "jmp" :: "pin," :: rest, comment -> [ join ?comment ("jmp" :: "!pin," :: rest) ]
    | "jmp" :: "!pin," :: rest, comment -> [ join ?comment ("jmp" :: "pin," :: rest) ]
    | tokens, _ ->
      if List.exists tokens ~f:(String.is_substring ~substring:"pin")
      then raise_s [%message "BUG: a pin use with no rewrite" line];
      [ line ])
  |> String.concat_lines
;;

(* the library's I2C configuration with SDA and SCL moved *)
let i2c_pins ~pins (config : Program_config.t) =
  let pin p = List.Assoc.find_exn pins ~equal:Int.equal p in
  { config with
    side_set_base =
      (if config.side_set_count > 0
       then pin config.side_set_base
       else config.side_set_base)
  ; in_base = pin config.in_base
  ; out_base = pin config.out_base
  ; set_base = pin config.set_base
  ; jmp_pin = pin config.jmp_pin
  }
;;

module I2c = struct
  let sda = wire 0
  let scl = wire 1
  let pins = [ Firmware.sda, sda; Firmware.scl, scl ]
  let on_wire config = { (i2c_pins ~pins config) with side_set_pindirs = false }

  let controller =
    open_drain_on_wire ~pins Firmware.i2c_master_host_rate_without_bus_clear
  ;;

  let controller_config = on_wire Firmware.i2c_config
  let target = open_drain_on_wire ~pins (Timed_program.source Firmware.i2c_slave)
  let target_config = on_wire Firmware.i2c_slave_config
end

module Bus = struct
  let pins = [ Firmware.sda, Bench.sda; Firmware.scl, Bench.scl ]
  let controller = Firmware.i2c_master_host_rate_held ~clear_bus:false ~quarters:2 ()
  let controller_config = i2c_pins ~pins Firmware.i2c_config
  let target = move_pins ~pins (Timed_program.source Firmware.i2c_slave)
  let target_config = i2c_pins ~pins Firmware.i2c_slave_config
  let pads = (1 lsl Bench.sda) lor (1 lsl Bench.scl)
end

module Spi = struct
  let pins = { Spi_target.Pins.mosi = wire 2; sck = wire 3; cs = wire 4; miso = wire 5 }

  (* 1.5 MHz at 48 MHz, CS a half period either side of the clock *)
  let half_period = 16

  let controller mode =
    Spi_cs.master
      ~mode
      ~half_period
      ~setup:half_period
      ~hold:half_period
      ~deselect:half_period
  ;;

  let controller_config =
    { Spi_cs.config with
      out_base = pins.mosi
    ; set_base = pins.mosi
    ; side_set_base = pins.sck
    ; in_base = pins.miso
    }
  ;;

  let target mode = Spi_target.firmware ~mode pins
  let target_config = Spi_target.config pins
end

module Uart = struct
  let line = wire 6
  let transmitter = Firmware.uart_tx_host_rate

  let transmitter_config =
    { Program_config.default with out_base = line; set_base = line }
  ;;

  let receiver = Firmware.uart_rx_host_rate_on ~pin:line

  let receiver_config =
    { Firmware.rx_config with in_base = line; jmp_pin = line; capture_pin = line }
  ;;
end

module Side = struct
  type t =
    { timed : Timed_program.t
    ; words : int list
    }
end

module Outcome = struct
  type t =
    { controller : int list
    ; target : int list
    ; faults : Machine.Fault.t list
    ; irq : bool list
    ; mismatch : System_lockstep.Mismatch.t option
    }
  [@@deriving sexp_of]
end

(* the host fills each tx fifo before the start, as a bench host does *)
let preloaded = Machine.fifo_depth

(* The host of both engines: a word to each as its tx fifo has room, and a pop of each
   word the core pushes. [after] sees the model once a cycle has stepped, and [actions]
   gives the next cycle's. *)
module Host = struct
  type t =
    { queued : int list array
    ; room : int array
    ; popping : bool array
    ; received : int Queue.t array
    }

  let create sides =
    { queued =
        Array.of_list_map sides ~f:(fun (s : Side.t) -> List.drop s.words preloaded)
    ; room =
        Array.of_list_map sides ~f:(fun (s : Side.t) ->
          Machine.fifo_depth - Int.min preloaded (List.length s.words))
    ; popping = Array.of_list_map sides ~f:(fun _ -> false)
    ; received = Array.of_list_map sides ~f:(fun _ -> Queue.create ())
    }
  ;;

  let actions t =
    List.init (Array.length t.queued) ~f:(fun n ->
      let tx =
        match t.queued.(n) with
        | word :: rest when t.room.(n) > 0 ->
          t.queued.(n) <- rest;
          t.room.(n) <- t.room.(n) - 1;
          Some word
        | _ -> None
      in
      let pop_rx = t.popping.(n) in
      t.popping.(n) <- false;
      { Lockstep.Host.idle with tx; pop_rx })
  ;;

  let after t (system : System.t) =
    List.iteri system.engines ~f:(fun n (m : Machine.t) ->
      t.room.(n) <- Machine.fifo_depth - List.length m.tx_fifo;
      match m.rx_fifo with
      | word :: _ ->
        Queue.enqueue t.received.(n) word;
        t.popping.(n) <- true
      | [] -> ())
  ;;
end

let setup (side : Side.t) =
  { System_lockstep.Setup.config = Timed_program.config side.timed
  ; program = Timed_program.words side.timed
  ; preload = List.take side.words preloaded
  ; data = []
  }
;;

let outcome (host : Host.t) (system : System.t) mismatch =
  { Outcome.controller = Queue.to_list host.received.(0)
  ; target = Queue.to_list host.received.(1)
  ; faults = List.map system.engines ~f:(fun m -> m.fault)
  ; irq = List.map system.engines ~f:(fun m -> m.irq)
  ; mismatch
  }
;;

(* as [System_lockstep] steps the model: pops before the step, tx words after it *)
let model ?(pads = 0) ~cycles ~controller ~target () =
  let sides = [ controller; target ] in
  let host = Host.create sides in
  let system =
    List.map sides ~f:(fun side ->
      let setup = setup side in
      List.fold
        setup.preload
        ~init:(Machine.create ~config:setup.config ~program:setup.program |> ok_exn)
        ~f:(fun m word -> Machine.write_tx m word |> ok_exn))
    |> System.create
  in
  let step system =
    let actions = Host.actions host in
    let update system ~f =
      List.foldi actions ~init:system ~f:(fun n system action ->
        System.update system n ~f:(fun m -> f m action))
    in
    let system =
      update system ~f:(fun m action ->
        match Machine.read_rx m with
        | Some (_, popped) when action.pop_rx -> popped
        | Some _ | None -> m)
    in
    let system =
      update (System.step system ~pads) ~f:(fun m action ->
        match action.tx with
        | Some word -> Machine.write_tx m word |> ok_exn
        | None -> m)
    in
    Host.after host system;
    system
  in
  outcome host (Fn.apply_n_times ~n:cycles step system) None
;;

let rtl ?(pads = 0) ~cycles ~controller ~target () =
  let host = Host.create [ controller; target ] in
  let system, mismatch =
    System_lockstep.run
      ~cycles
      ~host:(fun _ -> Host.actions host)
      ~react:(Host.after host)
      ~pads:(Fn.const pads)
      [ setup controller; setup target ]
  in
  outcome host system mismatch
;;

module Case = struct
  type t =
    { name : string
    ; controller_name : string
    ; controller : Timed_program.t
    ; target_name : string
    ; target : Timed_program.t
    ; controller_words : int list
    ; target_words : int list
    ; pads : int
    ; cycles : int
    }

  let i2c_controller =
    Timed_program.of_source_exn
      ~period_floor:31
      ~config:I2c.controller_config
      I2c.controller
  ;;

  let i2c_target = Timed_program.of_source_exn ~config:I2c.target_config I2c.target

  let bus_controller =
    Timed_program.of_source_exn
      ~period_floor:31
      ~config:Bus.controller_config
      Bus.controller
  ;;

  let bus_target = Timed_program.of_source_exn ~config:Bus.target_config Bus.target

  let spi_controller mode =
    Timed_program.of_source_exn ~config:Spi.controller_config (Spi.controller mode)
  ;;

  let spi_target mode =
    Timed_program.of_source_exn ~config:Spi.target_config (Spi.target mode)
  ;;

  let uart_transmitter =
    Timed_program.of_source_exn
      ~period_floor:4
      ~config:Uart.transmitter_config
      Uart.transmitter
  ;;

  let uart_receiver =
    Timed_program.of_source_exn
      ~period_floor:4
      ~single_capture_edge:true
      ~config:Uart.receiver_config
      Uart.receiver
  ;;

  let mode_name mode = Int.to_string (Spi_cs.Mode.to_int mode)

  let firmware =
    [ "i2c_controller_wire", i2c_controller
    ; "i2c_target_wire", i2c_target
    ; "i2c_controller_bus", bus_controller
    ; "i2c_target_bus", bus_target
    ]
    @ List.concat_map Spi_cs.Mode.all ~f:(fun mode ->
      [ "spi_controller_wire_mode" ^ mode_name mode, spi_controller mode
      ; "spi_target_wire_mode" ^ mode_name mode, spi_target mode
      ])
    @ [ "uart_tx_wire", uart_transmitter; "uart_rx_wire", uart_receiver ]
  ;;

  (* Standard-mode and Fast-mode at the bench's 48 MHz *)
  let standard = 121
  let fast = 32
  let address = 0x42

  (* a write of two bytes, a read of two after a repeated start, then a call to 0x77,
     which nothing on the wires or the bench's bus answers *)
  let i2c_words quarter =
    let word = Firmware.i2c_word in
    quarter
    :: [ word ~start:true (address lsl 1)
       ; word 0x10
       ; word ~stop:true 0x5a
       ; word ~start:true (address lsl 1)
       ; word 0x01
       ; word ~start:true ((address lsl 1) lor 1)
       ; word ~read:true 0
       ; word ~read:true ~stop:true 0
       ; word ~start:true ~stop:true (0x77 lsl 1)
       ]
  ;;

  let i2c ~name ~bus quarter =
    { name
    ; controller_name = (if bus then "i2c_controller_bus" else "i2c_controller_wire")
    ; controller = (if bus then bus_controller else i2c_controller)
    ; target_name = (if bus then "i2c_target_bus" else "i2c_target_wire")
    ; target = (if bus then bus_target else i2c_target)
    ; controller_words = i2c_words quarter
    ; target_words = [ address lsl 1; 0x12; 0x34 ]
    ; pads = (if bus then Bus.pads else 0)
    ; cycles = 1000 + (13 * 9 * 4 * quarter * 2)
    }
  ;;

  let spi_frames = [ [ 0x9f; 0x00; 0x00 ]; [ 0xa5 ]; [ 0x3c; 0xc3 ] ]
  let spi_replies = [ 0x11; 0x22; 0x33; 0x44; 0x55; 0x66 ]

  let spi mode =
    { name = [%string "SPI mode %{mode_name mode} on wires"]
    ; controller_name = "spi_controller_wire_mode" ^ mode_name mode
    ; controller = spi_controller mode
    ; target_name = "spi_target_wire_mode" ^ mode_name mode
    ; target = spi_target mode
    ; controller_words = List.concat_map spi_frames ~f:Spi_cs.words
    ; target_words = List.map spi_replies ~f:(fun byte -> byte lsl 8)
    ; pads = 0
    ; cycles = 3000
    }
  ;;

  let uart_bytes = [ 0x55; 0xa3; 0x00; 0xff ]

  (* the receiver gets half the bit period, the transmitter the whole *)
  let uart_half baud = ((Bench.clock_hz / baud) + 1) / 2

  let uart baud =
    let half = uart_half baud in
    { name = [%string "UART %{baud#Int} baud on a wire"]
    ; controller_name = "uart_tx_wire"
    ; controller = uart_transmitter
    ; target_name = "uart_rx_wire"
    ; target = uart_receiver
    ; controller_words = (2 * half) :: uart_bytes
    ; target_words = [ half ]
    ; pads = 0
    ; cycles = 100 + (List.length uart_bytes * 11 * 2 * half)
    }
  ;;

  let all =
    [ i2c ~name:"I2C Standard-mode on wires" ~bus:false standard
    ; i2c ~name:"I2C Fast-mode on wires" ~bus:false fast
    ; i2c ~name:"I2C Fast-mode on the bench's bus" ~bus:true fast
    ]
    @ List.map Spi_cs.Mode.all ~f:spi
    @ List.map Rates.bauds ~f:uart
  ;;
end
