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
  let%hw reset_done = pipeline async ~n:2 vdd in
  let clocking = { Clocking.clock = i.clk; clear = ~:reset_done } in
  let sync x = Clocking.pipeline clocking ~n:2 x in
  let%hw inputs = concat_msb [ sync i.uio_in; zero 7; sync i.ui_in.:[7, 3] ] in
  let engine_outs = List.init engines ~f:(fun _ -> Engine.O.Of_signal.wires ()) in
  let host =
    Host.hierarchical
      scope
      { clocking
      ; sck = i.ui_in.:(0)
      ; mosi = i.ui_in.:(1)
      ; cs_n = i.ui_in.:(2)
      ; status =
          List.map engine_outs ~f:(fun (engine : _ Engine.O.t) ->
            { Host_port.Status.pc = engine.pc
            ; now = engine.now
            ; capture = engine.capture
            ; halted = engine.halted
            ; irq = engine.irq
            ; fault = engine.fault
            ; tx_level = engine.tx_level
            ; rx_level = engine.rx_level
            ; rx_head = engine.rx_head
            ; x = engine.x
            ; y = engine.y
            ; p = engine.p
            ; t = engine.t
            ; isr = engine.isr
            ; osr = engine.osr
            ; isr_count = engine.isr_count
            ; osr_count = engine.osr_count
            })
      }
  in
  let cores =
    Engines.hierarchical ~memory scope { clocking; hosts = host.engines; pads = inputs }
  in
  List.iter2_exn engine_outs cores.engines ~f:Engine.O.Of_signal.assign;
  { O.uo_out = cores.pin_out.:[11, 5] @: host.miso
  ; uio_out = cores.pin_out.:[19, 12]
  ; uio_oe = cores.pin_dir.:[19, 12]
  }
;;

let hierarchical ?instance ~memory ~engines scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"top" (create ~memory ~engines) i
;;
