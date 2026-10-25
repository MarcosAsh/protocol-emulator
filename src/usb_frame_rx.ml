open! Core
open! Hardcaml
open! Signal

module Rx_config = struct
  let samples_per_bit = 8
  let samples_per_cycle = 2
end

module Rx = Usb_rx.Make (Rx_config)

let word_count_bits = 10

(* USB 2.0 8.3.5: 01100 and 1000000000001101 sent MSB first, so reflected here *)
let crc5_residue = 0x06
let crc16_residue = 0xb001

module Control = struct
  type 'a t =
    { arm : 'a
    ; base : 'a [@bits Isa.data_addr_bits]
    }
  [@@deriving hardcaml]
end

module Status = struct
  type 'a t =
    { words : 'a [@bits word_count_bits]
    ; finished : 'a
    ; crc5_ok : 'a
    ; crc16_ok : 'a
    ; half : 'a
    ; aligned : 'a
    ; stuff_error : 'a
    ; dropped : 'a
    ; receiving : 'a
    ; armed : 'a
    }
  [@@deriving hardcaml]
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; dp : 'a [@bits 2]
    ; dm : 'a [@bits 2]
    ; control : 'a Control.t
    ; may_write : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { write : 'a Engine.Program_write.t
    ; ready : 'a
    ; status : 'a Status.t
    }
  [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let rx = Rx.hierarchical scope { clocking = i.clocking; dp = i.dp; dm = i.dm } in
  let%hw armed = wire 1 in
  let%hw receiving = wire 1 in
  let%hw starts = armed &: rx.sync_seen in
  let%hw ends = receiving &: rx.packet_end in
  armed <-- reg spec (mux2 i.control.arm vdd @@ mux2 ends gnd armed);
  receiving
  <-- reg spec (mux2 i.control.arm gnd @@ mux2 starts vdd @@ mux2 ends gnd receiving);
  let%hw words = wire word_count_bits in
  let%hw takes = receiving &: rx.word.valid in
  let%hw full = words ==:. (1 lsl word_count_bits) - 1 in
  words
  <-- reg
        spec
        (mux2 (i.control.arm |: starts) (zero word_count_bits)
         @@ mux2 (takes &: ~:full) (words +:. 1) words);
  let restart = i.control.arm |: starts in
  (* A word waits here for a cycle [may_write] lets through, until the next comes. Its
     address is taken from the base as it lands, as [Frame_rx]'s is. *)
  let%hw pending = wire 1 in
  let held = reg spec ~enable:takes in
  let%hw index = held words in
  let%hw addr =
    uresize i.control.base ~width:(word_count_bits + 1)
    +: uresize index ~width:(word_count_bits + 1)
  in
  let%hw fits = addr <:. 1 lsl Isa.data_addr_bits in
  let%hw leaves = pending &: i.may_write in
  let%hw ready = pending &: fits in
  let%hw writes = ready &: i.may_write in
  pending <-- reg spec (mux2 restart gnd @@ mux2 takes vdd @@ mux2 leaves gnd pending);
  let%hw dropped =
    reg_fb spec ~width:1 ~f:(fun d ->
      mux2 restart gnd @@ mux2 (leaves &: ~:fits |: (takes &: pending &: ~:leaves)) vdd d)
  in
  (* both CRCs over every bit after the PID *)
  let module Crc_step = Crc.Make (Signal) in
  let%hw packet_bit = receiving &: rx.bit.valid in
  let%hw past_pid = wire 1 in
  let%hw pid_bits = wire 3 in
  pid_bits <-- reg spec (mux2 starts (zero 3) @@ mux2 packet_bit (pid_bits +:. 1) pid_bits);
  past_pid
  <-- reg spec (mux2 starts gnd @@ mux2 (packet_bit &: (pid_bits ==:. 7)) vdd past_pid);
  let crc ~width ~poly =
    let crc = wire width in
    let next =
      Crc_step.step
        ~width:(of_unsigned_int ~width:Crc.width_bits width)
        ~poly:(of_unsigned_int ~width poly)
        ~reflect:vdd
        crc
        ~bit:rx.bit.value
    in
    crc <-- reg spec (mux2 starts (ones width) @@ mux2 (packet_bit &: past_pid) next crc);
    crc
  in
  let%hw crc5 = crc ~width:5 ~poly:0x14 in
  let%hw crc16 = crc ~width:16 ~poly:0xa001 in
  let latch v = reg_fb spec ~width:1 ~f:(fun d -> mux2 restart gnd @@ mux2 ends v d) in
  let%hw ended = latch vdd in
  let%hw finished = ended &: ~:pending in
  let%hw crc5_ok = latch (crc5 ==:. crc5_residue) in
  let%hw crc16_ok = latch (crc16 ==:. crc16_residue) in
  let%hw half = latch rx.word.valid in
  let%hw aligned = latch rx.aligned in
  let%hw stuff_error = latch rx.stuff_error in
  { O.write =
      { valid = writes
      ; addr = sel_bottom addr ~width:Isa.data_addr_bits
      ; data = held rx.word.value
      }
  ; ready
  ; status =
      { words
      ; finished
      ; crc5_ok
      ; crc16_ok
      ; half
      ; aligned
      ; stuff_error
      ; dropped
      ; receiving
      ; armed
      }
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"usb_frame_rx" create i
;;
