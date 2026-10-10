open! Core
open! Hardcaml
open! Signal

module Rx_config = struct
  let samples_per_bit = [ 8; 10 ]
  let samples_per_cycle = 2
  let gain_shift = 3
end

module Rx = Manchester_rx.Make (Rx_config)

let word_count_bits = 10
let pin_bits = Int.ceil_log2 Isa.num_pins

(* CRC-32 as 802.3 sends it, first bit lowest: a good frame leaves this in the register
   once its FCS has gone through *)
let poly = 0xedb88320
let residue = 0xdebb20e3

module Control = struct
  type 'a t =
    { arm : 'a
    ; base : 'a [@bits Isa.data_addr_bits]
    ; fifty : 'a
    }
  [@@deriving hardcaml]
end

module Status = struct
  type 'a t =
    { words : 'a [@bits word_count_bits]
    ; finished : 'a
    ; fcs_ok : 'a
    ; half : 'a
    ; dropped : 'a
    ; receiving : 'a
    ; armed : 'a
    }
  [@@deriving hardcaml]
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; rd : 'a [@bits 2]
    ; control : 'a Control.t
    ; may_write : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { write : 'a Engine.Program_write.t
    ; status : 'a Status.t
    }
  [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let rx =
    Rx.hierarchical scope { clocking = i.clocking; rd = i.rd; rate = i.control.fifty }
  in
  let%hw armed = wire 1 in
  let%hw receiving = wire 1 in
  let%hw starts = armed &: rx.sfd_seen in
  let%hw ends = receiving &: rx.frame_end in
  armed <-- reg spec (mux2 i.control.arm vdd @@ mux2 ends gnd armed);
  receiving
  <-- reg spec (mux2 i.control.arm gnd @@ mux2 starts vdd @@ mux2 ends gnd receiving);
  let%hw words = wire word_count_bits in
  let%hw takes = receiving &: rx.word.valid in
  let%hw addr =
    uresize i.control.base ~width:(word_count_bits + 1)
    +: uresize words ~width:(word_count_bits + 1)
  in
  (* the data memory's end is the frame's, with no wrap *)
  let%hw fits = addr <:. 1 lsl Isa.data_addr_bits in
  let%hw writes = takes &: fits &: i.may_write in
  let%hw full = words ==:. (1 lsl word_count_bits) - 1 in
  words
  <-- reg
        spec
        (mux2 (i.control.arm |: starts) (zero word_count_bits)
         @@ mux2 (takes &: ~:full) (words +:. 1) words);
  let restart = i.control.arm |: starts in
  let%hw dropped =
    reg_fb spec ~width:1 ~f:(fun d -> mux2 restart gnd @@ mux2 (takes &: ~:writes) vdd d)
  in
  (* the FCS over every bit after the start of frame, judged at each byte's end *)
  let module Crc_step = Crc.Make (Signal) in
  let%hw crc = wire 32 in
  let%hw frame_bit = receiving &: rx.bit.valid in
  let%hw crc_next =
    Crc_step.step
      ~width:(of_unsigned_int ~width:6 32)
      ~poly:(of_unsigned_int ~width:32 poly)
      ~reflect:vdd
      crc
      ~bit:rx.bit.value
  in
  crc <-- reg spec (mux2 starts (ones 32) @@ mux2 frame_bit crc_next crc);
  let%hw byte_bit = wire 3 in
  byte_bit <-- reg spec (mux2 starts (zero 3) @@ mux2 frame_bit (byte_bit +:. 1) byte_bit);
  let%hw good_so_far =
    reg_fb spec ~width:1 ~f:(fun d ->
      mux2 starts gnd @@ mux2 (frame_bit &: (byte_bit ==:. 7)) (crc_next ==:. residue) d)
  in
  let latch v = reg_fb spec ~width:1 ~f:(fun d -> mux2 restart gnd @@ mux2 ends v d) in
  let%hw finished = latch vdd in
  let%hw fcs_ok = latch good_so_far in
  (* the last word holds one byte where the carrier went on a half word *)
  let%hw half = latch rx.word.valid in
  { O.write =
      { valid = writes
      ; addr = sel_bottom addr ~width:Isa.data_addr_bits
      ; data = rx.word.value
      }
  ; status = { words; finished; fcs_ok; half; dropped; receiving; armed }
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"frame_rx" create i
;;
