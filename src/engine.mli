(** The core. Same semantics as [Machine]; the tests keep them in lockstep.

    Memory is read at the next issue address every cycle, so its registered output is the
    instruction register. [program_write] only while halted. [start] resets [pc] and the
    timer; the first instruction issues a cycle later at [now = 0]. *)

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
    ; config : 'a Config.t
    ; start : 'a
    ; program_write : 'a Program_write.t
    ; tx : 'a With_valid.t
    ; rx_pop : 'a
    ; clear_irq : 'a
    ; inputs : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { pin_out : 'a
    ; pin_dir : 'a
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
    ; stall : 'a
    ; halted : 'a
    ; irq : 'a
    ; fault : 'a Fault.t
    ; capture : 'a
    ; capture_armed : 'a
    ; tx_level : 'a
    ; rx_level : 'a
    ; rx_head : 'a
    ; instruction : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical
  :  ?instance:string
  -> memory:Memory.t
  -> Scope.t
  -> Signal.t I.t
  -> Signal.t O.t
