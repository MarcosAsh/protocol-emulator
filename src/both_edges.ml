open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; pad : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { samples : 'a [@bits 2] } [@@deriving hardcaml]
end

(* Two flops on each edge, then the falling side onto the rising: after a rising edge, the
   pad half a cycle before the rising chain's sample, then that sample. *)
let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let falling = Reg_spec.override spec ~clock_edge:Edge.Falling in
  let%hw rising = pipeline spec ~n:2 i.pad in
  let%hw fell = reg spec (pipeline falling ~n:2 i.pad) in
  { O.samples = rising @: fell }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"both_edges" create i
;;
