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
  let spec = Clocking.to_spec i.clocking in
  let%hw_var level = Always.Variable.reg spec ~width:level_bits in
  let%hw_var rd = Always.Variable.reg spec ~width:(Int.ceil_log2 depth) in
  let%hw_var wr = Always.Variable.reg spec ~width:(Int.ceil_log2 depth) in
  let%hw empty = level.value ==:. 0 in
  let%hw full = level.value ==:. depth in
  let%hw push = i.push.valid &: ~:full in
  let%hw pop = i.pop &: ~:empty in
  let slots =
    List.init depth ~f:(fun slot ->
      reg spec ~enable:(push &: (wr.value ==:. slot)) i.push.value)
  in
  let%hw head = mux rd.value slots in
  Always.(
    compile
      [ when_ push [ wr <-- wr.value +:. 1 ]
      ; when_ pop [ rd <-- rd.value +:. 1 ]
      ; when_ (push &: ~:pop) [ level <-- level.value +:. 1 ]
      ; when_ (pop &: ~:push) [ level <-- level.value -:. 1 ]
      ]);
  { O.head; level = level.value; empty; full }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"host_fifo" create i
;;
