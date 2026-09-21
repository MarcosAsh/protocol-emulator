open! Core
open! Hardcaml
open! Hardcaml_test_harness
open Protocol_emulator
module Harness = Lws_harness.Make (Engine.I) (Engine.O)

let debug = false
let ( <--. ) = Bits.( <--. )

module State = struct
  type t =
    { pc : int
    ; x : int
    ; y : int
    ; p : int
    ; t : int
    ; osr : int
    ; osr_count : int
    ; isr : int
    ; isr_count : int
    ; now : int
    ; pin_out : int
    ; pin_dir : int
    ; stall : int
    ; halted : bool
    ; irq : bool
    ; fault : Machine.Fault.t
    ; capture : int
    ; capture_armed : bool
    ; tx_level : int
    ; rx_level : int
    ; rx_head : int option
    ; crc : int
    ; stuff_run : int
    }
  [@@deriving sexp_of, compare, equal]

  let of_machine (m : Machine.t) =
    { pc = m.pc
    ; x = m.x
    ; y = m.y
    ; p = m.p
    ; t = m.t
    ; osr = m.osr
    ; osr_count = m.osr_count
    ; isr = m.isr
    ; isr_count = m.isr_count
    ; now = m.now
    ; pin_out = m.pin_out
    ; pin_dir = m.pin_dir
    ; stall = m.stall
    ; halted = m.halted
    ; irq = m.irq
    ; fault = m.fault
    ; capture = m.capture
    ; capture_armed = m.capture_armed
    ; tx_level = List.length m.tx_fifo
    ; rx_level = List.length m.rx_fifo
    ; rx_head = List.hd m.rx_fifo
    ; crc = m.crc
    ; stuff_run = m.stuff_run
    }
  ;;

  let of_outputs (o : Bits.t ref Engine.O.t) =
    let int r = Bits.to_unsigned_int !r in
    let bool r = Bits.to_bool !r in
    let rx_level = int o.rx_level in
    { pc = int o.pc
    ; x = int o.x
    ; y = int o.y
    ; p = int o.p
    ; t = int o.t
    ; osr = int o.osr
    ; osr_count = int o.osr_count
    ; isr = int o.isr
    ; isr_count = int o.isr_count
    ; now = int o.now
    ; pin_out = int o.pin_out
    ; pin_dir = int o.pin_dir
    ; stall = int o.stall
    ; halted = bool o.halted
    ; irq = bool o.irq
    ; fault =
        { underflow = bool o.fault.underflow
        ; overflow = bool o.fault.overflow
        ; missed_deadline = bool o.fault.missed_deadline
        ; decode = bool o.fault.decode
        }
    ; capture = int o.capture
    ; capture_armed = bool o.capture_armed
    ; tx_level = int o.tx_level
    ; rx_level
    ; rx_head = (if rx_level = 0 then None else Some (int o.rx_head))
    ; crc = int o.crc
    ; stuff_run = int o.stuff_run
    }
  ;;
end

module Host = struct
  type t =
    { tx : int option
    ; pop_rx : bool
    ; clear_irq : bool
    }

  let idle = { tx = None; pop_rx = false; clear_irq = false }
end

let run
  ?(cycles = 400)
  ?(preload = [])
  ?(host = fun _ -> Host.idle)
  ?(react = fun (_ : Machine.t) -> ())
  ?coverage
  ~config
  ~program
  ~inputs
  ()
  =
  Harness.run
    ~waves_config:
      (if debug then Waves_config.to_home_subdirectory () else Waves_config.no_waves)
    ~random_initial_state:`All
    ~create:(Engine.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
      let cycle () = Hardcaml_lws.Lws.cycle h in
      let after () = Before_and_after_edge.after_edge outputs in
      i.clocking.clear := Bits.vdd;
      cycle ();
      i.clocking.clear := Bits.gnd;
      Engine.Config.iter2 i.config (Engine.Config.of_program_config config) ~f:( := );
      List.iteri program ~f:(fun addr word ->
        i.program_write.valid := Bits.vdd;
        i.program_write.addr <--. addr;
        i.program_write.data <--. word;
        cycle ());
      i.program_write.valid := Bits.gnd;
      let model = ref (Machine.create ~config ~program |> ok_exn) in
      List.iter preload ~f:(fun word ->
        i.tx.valid := Bits.vdd;
        i.tx.value <--. word;
        cycle ();
        model := Machine.write_tx !model word |> ok_exn);
      i.tx.valid := Bits.gnd;
      i.start := Bits.vdd;
      cycle ();
      i.start := Bits.gnd;
      cycle ();
      let mismatch = ref None in
      let cycle_number = ref 0 in
      while !cycle_number < cycles && Option.is_none !mismatch do
        let n = !cycle_number in
        let expected = State.of_machine !model in
        let actual = State.of_outputs (after ()) in
        if not (State.equal expected actual)
        then mismatch := Some (n, expected, actual)
        else (
          let levels = inputs n in
          let action = host n in
          i.inputs <--. levels;
          (match action.tx with
           | Some word ->
             i.tx.valid := Bits.vdd;
             i.tx.value <--. word
           | None -> i.tx.valid := Bits.gnd);
          i.rx_pop := Bits.of_bool action.pop_rx;
          i.clear_irq := Bits.of_bool action.clear_irq;
          if action.clear_irq then model := Machine.clear_irq !model;
          if action.pop_rx
          then (
            match Machine.read_rx !model with
            | Some (_, m) -> model := m
            | None -> ());
          cycle ();
          let before = !model in
          model := Machine.step before ~inputs:levels;
          Option.iter coverage ~f:(fun c -> Coverage.record c ~before ~after:!model);
          (match action.tx with
           | Some word -> model := Machine.write_tx !model word |> ok_exn
           | None -> ());
          react !model;
          Int.incr cycle_number)
      done;
      !model, !mismatch)
;;

let lockstep ?(cycles = 400) ?preload ?host ?react ?coverage ~config ~program ~inputs () =
  let model, mismatch =
    run ~cycles ?preload ?host ?react ?coverage ~config ~program ~inputs ()
  in
  (match mismatch with
   | None -> print_s [%message "lockstep held" (cycles : int)]
   | Some (cycle, expected, actual) ->
     print_s [%message "MISMATCH" (cycle : int) (expected : State.t) (actual : State.t)]);
  model
;;
