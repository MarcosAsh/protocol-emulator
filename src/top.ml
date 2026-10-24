open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

let create ~memory ~engines (scope : Scope.t) (i : Signal.t I.t) =
  let module Config = struct
    let engines = engines
  end
  in
  let module Host = Host_port.Make (Config) in
  let module Engines = Engines.Make (Config) in
  let async = Reg_spec.create ~clock:i.clk ~reset:~:(i.rst_n) () in
  let%hw reset_meta = reg async vdd in
  let%hw reset_done = reg async reset_meta in
  (* Both_edges' falling pair clears from a flop of its own, a cycle behind reset_done,
     not from the clear's tree, which a falling flop gives only half a cycle *)
  let%hw reset_late = reg (Reg_spec.create ~clock:i.clk ()) reset_done in
  let clocking = { Clocking.clock = i.clk; clear = ~:reset_done } in
  let%hw ui_meta = Clocking.reg clocking i.ui_in.:[7, 3] in
  let%hw ui_sync = Clocking.reg clocking ui_meta in
  let%hw uio_meta = Clocking.reg clocking i.uio_in in
  let%hw uio_sync = Clocking.reg clocking uio_meta in
  let pads = concat_msb [ i.uio_in; zero 7; i.ui_in.:[7, 3] ] in
  let%hw inputs = concat_msb [ uio_sync; zero 7; ui_sync ] in
  let frame = Frame_rx.Status.Of_signal.wires () in
  let usb = Usb_frame_rx.Status.Of_signal.wires () in
  let stamps = Edge_stamps.O.Of_signal.wires () in
  let%hw frame_pin = wire Frame_rx.pin_bits in
  (* straight off the pad, so the falling edge samples it too *)
  let sample pin =
    Both_edges.hierarchical
      scope
      { clocking; falling_clear = ~:reset_late; pad = mux pin (bits_lsb pads) }
  in
  let rd = sample frame_pin in
  (* USB's D- on the pad after D+ *)
  let dm = sample (frame_pin +:. 1) in
  let engine_outs = List.init engines ~f:(fun _ -> Engine.O.Of_signal.wires ()) in
  let check = Engines.Check.Of_signal.wires () in
  let host =
    Host.hierarchical
      scope
      { clocking
      ; sck = i.ui_in.:(0)
      ; mosi = i.ui_in.:(1)
      ; cs_n = i.ui_in.:(2)
      ; status =
          List.map3_exn
            engine_outs
            check.certified
            check.refused
            ~f:(fun (engine : _ Engine.O.t) certified refused ->
              { Host_port.Status.pc = engine.pc
              ; now = engine.now
              ; capture = engine.capture
              ; halted = engine.halted
              ; irq = engine.irq
              ; fault = engine.fault
              ; tx_level = engine.tx_level
              ; rx_level = engine.rx_level
              ; rx_head = engine.rx_head
              ; certified
              ; refused
              })
      ; check = check.verdicts
      ; frame
      ; usb
      ; stamps
      }
  in
  frame_pin <-- host.frame_pin;
  let cores =
    Engines.hierarchical
      ~memory
      scope
      { clocking
      ; hosts = host.engines
      ; pads = inputs
      ; check_setup = host.check_setup
      ; start_all = host.start_all
      ; rd = rd.samples
      ; dm = dm.samples
      ; frame = host.frame
      ; frame_usb = host.frame_usb
      ; frame_owner = host.frame_owner
      ; stamps = host.stamps
      }
  in
  Frame_rx.Status.Of_signal.assign frame cores.frame;
  Usb_frame_rx.Status.Of_signal.assign usb cores.usb;
  Edge_stamps.O.Of_signal.assign stamps cores.stamps;
  List.iter2_exn engine_outs cores.engines ~f:Engine.O.Of_signal.assign;
  Engines.Check.Of_signal.assign check cores.check;
  { O.uo_out = cores.pin_out.:[11, 5] @: host.miso
  ; uio_out = cores.pin_out.:[19, 12]
  ; uio_oe = cores.pin_dir.:[19, 12]
  }
;;

let hierarchical ?instance ~memory ~engines scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"top" (create ~memory ~engines) i
;;
