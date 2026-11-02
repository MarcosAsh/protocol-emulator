open! Core
open! Hardcaml
open! Signal

let held_bits = Line_code.owed_max
let count_bits = Int.ceil_log2 (Line_code.owed_max + 1)

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; start : 'a
    ; enable : 'a
    ; step : 'a
    ; stuffing : 'a
    ; data : 'a
    ; finish : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { sent : 'a
    ; owed : 'a
    ; held : 'a [@bits held_bits]
    ; count : 'a [@bits count_bits]
    ; draining : 'a
    }
  [@@deriving hardcaml]
end

(* The owed bits are the latest [count] taken, so a shift register of the bits taken and a
   count serve as the queue: the oldest owed bit is [held] at [count - 1]. *)
let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let%hw held = wire held_bits in
  let%hw count = wire count_bits in
  let%hw draining = wire 1 in
  let%hw empty = count ==:. 0 in
  let%hw full = count ==:. Line_code.owed_max in
  let%hw taking = ~:draining |: (empty &: ~:(i.stuffing)) in
  let%hw oldest = mux (count -:. 1) (bits_lsb held) in
  let%hw sent = mux2 i.enable (~:(i.stuffing) &: mux2 empty i.data oldest) i.data in
  let%hw stepping = i.enable &: i.step in
  let%hw count_next =
    mux2
      i.stuffing
      (mux2 (taking &: ~:full) (count +:. 1) count)
      (mux2 (taking |: empty) count (count -:. 1))
  in
  let%hw held_reg =
    reg
      spec
      (mux2 i.start (zero held_bits)
       @@ mux2 (stepping &: taking) (sel_bottom (held @: i.data) ~width:held_bits) held)
  in
  held <-- held_reg;
  let%hw count_reg =
    reg spec (mux2 i.start (zero count_bits) @@ mux2 stepping count_next count)
  in
  count <-- count_reg;
  let%hw draining_reg =
    reg
      spec
      (mux2 i.start gnd
       @@ mux2 (i.enable &: i.finish) vdd
       @@ mux2 (stepping &: draining &: taking) gnd draining)
  in
  draining <-- draining_reg;
  { O.sent; owed = ~:empty; held; count; draining }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"line_stuff" create i
;;
