(** The core. Same semantics as [Machine]; the tests keep them in lockstep.

    The word at [pc] sits in an instruction register and the memory reads one address
    ahead of it, so a jump spends its second cycle refilling. [program_write] only while
    halted, and never in the same cycle as [start]. [start] spends one cycle fetching
    address 0, then resets [pc] and the timer; the first instruction issues two cycles
    after [start] at [now = 0]. A [start] while one is in flight starts over. *)

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

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; config : 'a Config.t (** Held constant while running. *)
    ; start : 'a (** Pulse while halted. *)
    ; program_write : 'a Program_write.t (** Only while halted. *)
    ; tx : 'a With_valid.t (** A word for the core's tx fifo. *)
    ; rx_pop : 'a (** Pops the rx fifo; [rx_head] is the word popped. *)
    ; clear_irq : 'a
    ; inputs : 'a (** The external level of every pin in the flat pin space. *)
    }
  [@@deriving hardcaml]
end

(** Besides the pins and the host's view, the architectural state comes out so the tests
    can hold it against the model every cycle and the formal proof can read it. *)
module O : sig
  type 'a t =
    { pin_out : 'a
    ; pin_dir : 'a (** Set for a bidirectional pin the core drives. *)
    ; pc : 'a
    ; x : 'a
    ; y : 'a
    ; p : 'a
    ; t : 'a
    ; osr : 'a
    ; osr_count : 'a
    ; isr : 'a
    ; isr_count : 'a
    ; now : 'a
    ; stall : 'a (** Cycles until the next issue. *)
    ; halted : 'a
    ; irq : 'a
    ; fault : 'a Fault.t
    ; capture : 'a
    ; capture_armed : 'a
    ; tx_level : 'a
    ; rx_level : 'a
    ; rx_head : 'a
    ; instruction : 'a (** The word at [pc]. *)
    ; crc : 'a
    ; stuff_run : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical
  :  ?instance:string
  -> memory:Memory.t
  -> Scope.t
  -> Signal.t I.t
  -> Signal.t O.t
