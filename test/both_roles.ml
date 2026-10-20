open! Core
open Protocol_emulator

let wire n = Isa.num_pins + n

module Wire_i2c = struct
  let controller = I2c.master_on_wires
  let controller_config = I2c.master_on_wires_config
  let target = I2c.slave_on_wires
  let target_config = I2c.slave_on_wires_config
end

module Wire_spi = struct
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

module Wire_uart = struct
  let line = wire 6
  let transmitter = Uart.tx_host_rate

  let transmitter_config =
    { Program_config.default with out_base = line; set_base = line }
  ;;

  let receiver = Uart.rx_host_rate_on ~pin:line

  let receiver_config =
    { Uart.rx_config with in_base = line; jmp_pin = line; capture_pin = line }
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
      ~config:Wire_i2c.controller_config
      Wire_i2c.controller
  ;;

  let i2c_target =
    Timed_program.of_source_exn ~config:Wire_i2c.target_config Wire_i2c.target
  ;;

  let spi_controller mode =
    Timed_program.of_source_exn
      ~config:Wire_spi.controller_config
      (Wire_spi.controller mode)
  ;;

  let spi_target mode =
    Timed_program.of_source_exn ~config:Wire_spi.target_config (Wire_spi.target mode)
  ;;

  let uart_transmitter =
    Timed_program.of_source_exn
      ~period_floor:4
      ~config:Wire_uart.transmitter_config
      Wire_uart.transmitter
  ;;

  let uart_receiver =
    Timed_program.of_source_exn
      ~period_floor:4
      ~single_capture_edge:true
      ~config:Wire_uart.receiver_config
      Wire_uart.receiver
  ;;

  let mode_name mode = Int.to_string (Spi_cs.Mode.to_int mode)

  let firmware =
    [ "i2c_controller_wire", i2c_controller; "i2c_target_wire", i2c_target ]
    @ List.concat_map Spi_cs.Mode.all ~f:(fun mode ->
      [ "spi_controller_wire_mode" ^ mode_name mode, spi_controller mode
      ; "spi_target_wire_mode" ^ mode_name mode, spi_target mode
      ])
    @ [ "uart_tx_wire", uart_transmitter; "uart_rx_wire", uart_receiver ]
  ;;

  let address = 0x42

  (* a write of two bytes, a read of two after a repeated start, then a call to 0x77,
     which nothing on the wires or the bench's bus answers *)
  let i2c_words quarter =
    let word = I2c.word in
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

  let i2c ~name quarter =
    { name
    ; controller_name = "i2c_controller_wire"
    ; controller = i2c_controller
    ; target_name = "i2c_target_wire"
    ; target = i2c_target
    ; controller_words = i2c_words quarter
    ; target_words = [ address lsl 1; 0x12; 0x34 ]
    ; pads = 0
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
    [ i2c ~name:"I2C Standard-mode on wires" I2c.standard_quarter
    ; i2c ~name:"I2C Fast-mode on wires" I2c.fast_quarter
    ]
    @ List.map Spi_cs.Mode.all ~f:spi
    @ List.map Uart.bauds ~f:uart
  ;;
end
