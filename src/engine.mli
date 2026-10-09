(** The core, with [Machine]'s semantics; the tests keep them in lockstep. Memory reads
    one address ahead of [pc], so a jump spends its second cycle refilling.
    [program_write] counts only while halted and never with [start]. [start] fetches
    address 0 for a cycle, so the first instruction issues two cycles later at [now = 0];
    a second [start] restarts. *)

open! Core
open! Hardcaml

module Memory : sig
  type t =
    | Flops
    | Ihp_sram
  [@@deriving sexp_of, enumerate]
end

module Config : sig
  type 'a t =
    { side_set_count : 'a
    ; side_set_base : 'a
    ; side_set_pindirs : 'a
    ; in_base : 'a
    ; in_count : 'a
    ; out_base : 'a
    ; out_count : 'a
    ; set_base : 'a
    ; set_count : 'a
    ; jmp_pin : 'a
    ; capture_pin : 'a
    ; capture_rising : 'a
    ; in_shift_right : 'a
    ; out_shift_right : 'a
    ; autopush : 'a
    ; push_threshold : 'a
    ; autopull : 'a
    ; pull_threshold : 'a
    ; crc_width : 'a
    ; crc_poly : 'a
    ; crc_init : 'a
    ; crc_reflect : 'a
    ; stuff_threshold : 'a
    ; stuff_level : 'a
    ; wrap_bottom : 'a
    ; wrap_top : 'a
    ; period_fraction : 'a
    ; autopull_data : 'a
    ; manchester : 'a
    }
  [@@deriving hardcaml]

  val of_program_config : Program_config.t -> Bits.t t
end

module Fault : sig
  type 'a t =
    { underflow : 'a
    ; overflow : 'a
    ; missed_deadline : 'a
    ; decode : 'a
    }
  [@@deriving hardcaml]
end

module Program_write : sig
  type 'a t =
    { valid : 'a
    ; addr : 'a
    ; data : 'a
    }
  [@@deriving hardcaml]
end

(** The host port's fields of [I], by the same names. *)
module Host : sig
  type 'a t =
    { config : 'a Config.t
    ; start : 'a
    ; program_write : 'a Program_write.t
    ; data_write : 'a Program_write.t
    ; tx : 'a With_valid.t
    ; rx_pop : 'a
    ; clear_irq : 'a
    ; stop : 'a
    ; flush : 'a
    ; check : 'a (** Walk the halted engine's program against its certificate. *)
    ; config_written : 'a (** A field of [config] was written. *)
    }
  [@@deriving hardcaml]
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; config : 'a Config.t (** Held constant while running. *)
    ; start : 'a (** Pulse while halted. *)
    ; program_write : 'a Program_write.t (** Only while halted. *)
    ; program_read : 'a With_valid.t
    (** Only while [free] and not writing: the word is [program_word] a cycle later. *)
    ; data_word : 'a (** The word at [data_ptr], from [Data_memory]. *)
    ; tx : 'a With_valid.t
    ; rx_pop : 'a (** [rx_head] is the word popped. *)
    ; clear_irq : 'a
    ; stop : 'a (** Pins hold. [start] wins. *)
    ; flush : 'a
    (** Empties both fifos. Ignored unless already halted, so not in the [stop] cycle. *)
    ; inputs : 'a (** External pin levels, and for wires what other engines drive. *)
    }
  [@@deriving hardcaml]
end

(** The timer's width, [Isa.timer_bits] on the chip. A narrower one wraps within reach of
    a bounded proof; [t], [now] and [capture] narrow with it, and a mov or an in of one
    reads it zero-extended. *)
module type Timer = sig
  val timer_bits : int
end

module Make (_ : Timer) : sig
  (** Exposes architectural state for lockstep tests and formal proofs. *)
  module O : sig
    type 'a t =
      { pin_out : 'a
      ; pin_dir : 'a (** Set for a bidirectional pin the core drives. *)
      ; pc : 'a
      ; data_ptr : 'a
      ; data_addr : 'a (** Where [data_ptr] will be next cycle. *)
      ; x : 'a
      ; y : 'a
      ; p : 'a
      ; t : 'a
      ; t_fraction : 'a
      ; osr : 'a
      ; osr_count : 'a
      ; isr : 'a
      ; isr_count : 'a
      ; now : 'a
      ; stall : 'a (** Cycles until the next issue. *)
      ; halted : 'a
      ; free : 'a
      (** Halted, and not starting now or a cycle ago: the program port and data turn
          serve no fetch. *)
      ; irq : 'a
      ; fault : 'a Fault.t
      ; faulted : 'a (** Any of [fault], as one flop. *)
      ; capture : 'a
      ; capture_armed : 'a
      ; tx_level : 'a
      ; rx_level : 'a
      ; rx_head : 'a (** 0 while [rx_level] is. *)
      ; instruction : 'a (** The word at [pc]. *)
      ; program_word : 'a (** The program memory's output. *)
      ; decode_ok : 'a (** Registered with [instruction], as are the next two. *)
      ; opcode_onehot : 'a
      ; wait_select : 'a (** Bit [n] for the pin the wait field names. *)
      ; crc : 'a
      ; stuff_run : 'a
      ; flip_pending : 'a
      ; flip_bit : 'a
      }
    [@@deriving hardcaml]
  end

  val hierarchical
    :  ?instance:string
    -> memory:Memory.t
    -> Scope.t
    -> Signal.t I.t
    -> Signal.t O.t
end

(** The chip's core. *)
include module type of Make (Isa)
