open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; config : 'a Engine.Config.t
    ; start : 'a
    ; program_write : 'a Engine.Program_write.t
    ; data_write : 'a Engine.Program_write.t
    ; tx : 'a With_valid.t [@bits Isa.data_bits]
    ; rx_pop : 'a
    ; clear_irq : 'a
    ; stop : 'a
    ; flush : 'a
    ; resume : 'a
    ; single_step : 'a
    ; inputs : 'a [@bits Isa.pin_space]
    }
  [@@deriving hardcaml]
end

module O = Engine.O

module Data_memory = Data_memory.Make (struct
    let engines = 1
  end)

let create ~memory (scope : Scope.t) (i : Signal.t I.t) =
  let out = Engine.O.Of_signal.wires () in
  let data =
    Data_memory.hierarchical
      ~memory
      scope
      { clocking = i.clocking
      ; halted = [ out.halted ]
      ; writes = [ i.data_write ]
      ; reads = [ out.data_addr ]
      }
  in
  Engine.hierarchical
    ~memory
    scope
    { clocking = i.clocking
    ; config = i.config
    ; start = i.start
    ; program_write = i.program_write
    ; data_word = List.hd_exn data.words
    ; tx = i.tx
    ; rx_pop = i.rx_pop
    ; clear_irq = i.clear_irq
    ; stop = i.stop
    ; flush = i.flush
    ; resume = i.resume
    ; single_step = i.single_step
    ; inputs = i.inputs
    }
  |> Engine.O.Of_signal.assign out;
  out
;;

let hierarchical ?instance ~memory scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"solo" (create ~memory) i
;;
