open! Core
open! Hardcaml
open! Signal

let depth = 4
let level_bits = Int.ceil_log2 (depth + 1)

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; push : 'a With_valid.t [@bits Isa.data_bits]
    ; pop : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { head : 'a [@bits Isa.data_bits]
    ; level : 'a [@bits level_bits]
    ; empty : 'a
    ; full : 'a
    }
  [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : Signal.t I.t) =
  let fifo =
    Fifo.create
      ~scope
      ~showahead:true
      ()
      ~capacity:depth
      ~clock:i.clocking.clock
      ~clear:i.clocking.clear
      ~wr:i.push.valid
      ~d:i.push.value
      ~rd:i.pop
  in
  { O.head = fifo.q; level = fifo.used; empty = fifo.empty; full = fifo.full }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"host_fifo" create i
;;
