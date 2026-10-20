(** The interfaces of the kernel's step and rows, which [Kernel] documents field by field.
    [Make_timer] sizes the ones whose widths follow the timer. *)

open! Core
open! Hardcaml

module Edge : sig
  type 'a t =
    { since : 'a
    ; level : 'a
    ; fresh : 'a
    }
  [@@deriving hardcaml]
end

module Spacing : sig
  type 'a t =
    { a : 'a
    ; b : 'a
    ; dirs : 'a
    ; side_set_base : 'a
    ; side_set_pindirs : 'a
    ; set_base : 'a
    ; set_count : 'a
    ; out_base : 'a
    ; out_count : 'a
    ; hold_a : 'a list
    ; apart_a : 'a list
    ; hold_b : 'a list
    ; apart_b : 'a list
    }
  [@@deriving hardcaml]

  module Spec : sig
    type t =
      { a : int
      ; b : int
      ; dirs : bool
      ; hold_a : own:bool -> other:bool -> int
      ; apart_a : own:bool -> other:bool -> int
      ; hold_b : own:bool -> other:bool -> int
      ; apart_b : own:bool -> other:bool -> int
      }
  end

  val of_spec : Program_config.t -> Spec.t -> Bits.t t
end

module Spaced : With_valid.Wrap.S with type 'a value = 'a Spacing.t

(** The period the host loads, when [valid]: what a run-time write to [p] leaves there, or
    with [floor] the least it leaves. *)
module Loaded : sig
  type 'a t =
    { valid : 'a
    ; value : 'a
    ; floor : 'a
    }
  [@@deriving hardcaml]
end

module Make_timer (_ : Engine.Timer) : sig
  val timer_bits : int
  val mark_bits : int

  module Held : sig
    type 'a t =
      { may : 'a
      ; since : 'a
      ; mark : 'a
      }
    [@@deriving hardcaml]
  end

  module Pin : sig
    type 'a t =
      { at0 : 'a Held.t
      ; at1 : 'a Held.t
      ; fresh : 'a
      }
    [@@deriving hardcaml]
  end

  module Row : sig
    type 'a t =
      { phase_lo : 'a
      ; phase_hi : 'a
      ; slope : 'a
      ; offset_lo : 'a
      ; offset_hi : 'a
      ; period_lo : 'a
      ; period_hi : 'a
      ; x_lo : 'a
      ; x_hi : 'a
      ; y_lo : 'a
      ; y_hi : 'a
      ; arm_lo : 'a
      ; arm_hi : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; a : 'a Pin.t
      ; b : 'a Pin.t
      }
    [@@deriving hardcaml]
  end

  module Capture : sig
    type 'a t =
      { pin : 'a
      ; rising : 'a
      ; single_edge : 'a
      }
    [@@deriving hardcaml]
  end

  module Holds : sig
    type 'a t =
      { phase : 'a
      ; offset : 'a
      ; period : 'a
      ; x : 'a
      ; y : 'a
      ; arm : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; edge_a : 'a
      ; edge_b : 'a
      }
    [@@deriving hardcaml]
  end

  module Conjuncts : sig
    type 'a t =
      { in_time : 'a
      ; wide_a : 'a
      ; wide_b : 'a
      ; next : 'a Holds.t
      ; target : 'a Holds.t
      }
    [@@deriving hardcaml]
  end

  module Step : sig
    type 'a t =
      { next_phase : 'a
      ; bounded : 'a
      ; may_carry : 'a
      ; next_period : 'a
      ; period_known : 'a
      ; next_x : 'a
      ; x_known : 'a
      ; next_y : 'a
      ; y_known : 'a
      ; taken : 'a
      ; taken_known : 'a
      ; next_arm : 'a
      ; next_arm_known : 'a
      ; next_captured : 'a
      ; next_awaiting : 'a
      ; capture_bounded : 'a
      ; next_a : 'a Edge.t
      ; next_b : 'a Edge.t
      ; wide_a : 'a
      ; wide_b : 'a
      ; halts : 'a
      }
    [@@deriving hardcaml]
  end
end
