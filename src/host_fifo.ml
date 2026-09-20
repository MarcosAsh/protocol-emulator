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

(* A showahead [Fifo] holds one word more than its capacity, so [full] comes from the
   [nearly_full] flag at [depth] and gates the push. A pop in the same cycle makes room,
   which is how the model sees a host pop: before the instruction. *)
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
      ~clear:i.clocking.clear
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
