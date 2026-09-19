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

let create ~memory (scope : Scope.t) (i : Signal.t I.t) =
  let async = Reg_spec.create ~clock:i.clk ~reset:~:(i.rst_n) () in
  let%hw reset_done = pipeline async ~n:2 vdd in
  let clocking = { Clocking.clock = i.clk; clear = ~:reset_done } in
  let sync x = Clocking.pipeline clocking ~n:2 x in
  let%hw inputs = concat_msb [ sync i.uio_in; zero 7; sync i.ui_in.:[7, 3] ] in
  let engine_out = Engine.O.Of_signal.wires () in
  let host =
    Host_port.hierarchical
      scope
      { clocking
      ; sck = i.ui_in.:(0)
      ; mosi = i.ui_in.:(1)
      ; cs_n = i.ui_in.:(2)
      ; status =
          { pc = engine_out.pc
          ; now = engine_out.now
          ; capture = engine_out.capture
          ; halted = engine_out.halted
          ; irq = engine_out.irq
          ; fault = engine_out.fault
          ; tx_level = engine_out.tx_level
          ; rx_level = engine_out.rx_level
          ; rx_head = engine_out.rx_head
          }
      }
  in
  let engine =
    Engine.hierarchical
      ~memory
      scope
      { clocking
      ; config = host.config
      ; start = host.start
      ; program_write = host.program_write
      ; tx = host.tx
      ; rx_pop = host.rx_pop
      ; clear_irq = host.clear_irq
      ; inputs
      }
  in
  Engine.O.Of_signal.assign engine_out engine;
  { O.uo_out = engine.pin_out.:[11, 5] @: host.miso
  ; uio_out = engine.pin_out.:[19, 12]
  ; uio_oe = engine.pin_dir.:[19, 12]
  }
;;

let hierarchical ?instance ~memory scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"top" (create ~memory) i
;;
