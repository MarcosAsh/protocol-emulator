open! Core
open! Hardcaml
open! Signal

let depth = 4
let level_bits = Int.ceil_log2 (depth + 1)

module Entry = struct
  type 'a t =
    { time : 'a [@bits Isa.timer_bits]
    ; pins : 'a [@bits Isa.num_pins]
    }
  [@@deriving hardcaml]
end

module Control = struct
  type 'a t =
    { mask : 'a [@bits Isa.num_pins]
    ; engine : 'a
    ; flush : 'a
    ; pop : 'a
    }
  [@@deriving hardcaml]
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; pads : 'a [@bits Isa.num_pins]
    ; now : 'a [@bits Isa.timer_bits]
    ; control : 'a Control.t
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { head : 'a Entry.t
    ; level : 'a [@bits level_bits]
    ; lost : 'a
    }
  [@@deriving hardcaml]
end

(* As [Host_fifo]: the showahead [Fifo] holds one more than its capacity, so a push beside
   a pop when full lands. *)
let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let%hw last = reg spec i.pads in
  let%hw moved = i.pads ^: last &: i.control.mask <>:. 0 in
  let%hw full = wire 1 in
  let fifo =
    Fifo.create
      ~scope
      ~showahead:true
      ~nearly_full:depth
      ()
      ~capacity:depth
      ~clock:i.clocking.clock
      ~clear:(i.clocking.clear |: i.control.flush)
      ~wr:(moved &: ~:full)
      ~d:(Entry.Of_signal.pack { time = i.now; pins = i.pads })
      ~rd:i.control.pop
  in
  full <-- (fifo.nearly_full &: ~:(i.control.pop));
  let%hw lost =
    reg_fb spec ~width:1 ~f:(fun lost ->
      mux2 i.control.flush gnd @@ mux2 (moved &: full) vdd lost)
  in
  { O.head = Entry.Of_signal.unpack (mux2 fifo.empty (zero (width fifo.q)) fifo.q)
  ; level = sel_bottom fifo.used ~width:level_bits
  ; lost
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"edge_stamps" create i
;;
