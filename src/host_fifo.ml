open! Core
open! Hardcaml
open! Signal

let depth = Isa.fifo_depth
let level_bits = Int.ceil_log2 (depth + 1)

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; push : 'a With_valid.t [@bits Isa.data_bits]
    ; pop : 'a
    ; flush : 'a
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

(* A showahead [Fifo] holds one more than its capacity, so [full] is [nearly_full] at
   [depth]. A same-cycle pop makes room, as the model pops before the instruction. *)
let create (scope : Scope.t) (i : Signal.t I.t) =
  let%hw full = wire 1 in
  let fifo =
    Fifo.create
      ~scope
      ~showahead:true
      ~nearly_full:depth
      ()
      ~capacity:depth
      ~clock:i.clocking.clock
      ~clear:(i.clocking.clear |: i.flush)
      ~wr:(i.push.valid &: ~:full)
      ~d:i.push.value
      ~rd:i.pop
  in
  full <-- (fifo.nearly_full &: ~:(i.pop));
  { O.head = fifo.q; level = fifo.used; empty = fifo.empty; full }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"host_fifo" create i
;;
