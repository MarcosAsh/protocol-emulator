(** Checks a timing certificate one instruction at a time. A certificate is a row per pc:
    the phase [now - t] on entry as a signed interval, [p], [x] and [y] as unsigned ones,
    and the phase less a multiple of [x] as another signed interval. The analyser proposes
    it and is not trusted.

    [formal/phase_step.sv] proves the core moves from one entry to the next as [step]
    says, for any program; [test/test_kernel.ml] proves by SAT that [accepts] keeps [step]
    inside the rows and a deadline wait at or below zero. SAT cannot follow a
    multiplication, so that proof takes the offsets as free inputs under axioms of modular
    arithmetic, which it states and rests on. So a program whose rows all pass, with the
    full range at pc 0, never misses a deadline. An empty row is a pc never reached; the
    full range is an unknown phase. *)

open! Core
open! Hardcaml

(** [slope] is signed. [offset_lo] and [offset_hi] bound [phase - slope * x], taken modulo
    the timer and read as signed, and their full range bounds nothing. A counted loop that
    moves [t] by the same amount on every pass keeps it: its phase has no bound short of
    the full range, but where [jmp x--] falls through, x is zero and the phase lies inside
    the offset. The kernel follows it across [set x] and across a step that adds to the
    phase and leaves x alone or counts it down, with the slope the same on both rows; on
    any other step the next row's offset has to be full. *)
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
    }
  [@@deriving hardcaml]
end

(** The capture pin and edge, and whether the single-edge assumption is taken: the pin is
    at the other level when [capture_arm] issues and, once at the captured level, stays
    there until the wait for it releases. *)
module Capture : sig
  type 'a t =
    { pin : 'a
    ; rising : 'a
    ; single_edge : 'a
    }
  [@@deriving hardcaml]
end

(** What a row asks of the row it steps to: its phase, offset, registers and capture state
    each land inside that row's. *)
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
    }
  [@@deriving hardcaml]
end

(** [accepts] one conjunct at a time, so a rejection says which fails. [in_time]: a
    deadline wait is entered at phase zero or below. [next] and [target]: the row maps
    into the next pc's, and into the jump target's, on each way out the instruction may
    take. A conjunct that does not apply, as for an empty row or a halt, holds. *)
module Conjuncts : sig
  type 'a t =
    { in_time : 'a
    ; next : 'a Holds.t
    ; target : 'a Holds.t
    }
  [@@deriving hardcaml]
end

(** The next entry's phase: anything unless [bounded], one less too if [may_carry].
    [next_period] holds when [period_known]. [loaded], when valid, is the assumption that
    every run-time write to [p] carries its value. The same for [x] and [y]. A jump goes
    to its target when [taken], if [taken_known]. [next_arm] counts the cycles since
    [capture_arm], leaving out a capturing wait's own wait, when [next_arm_known]; once
    [next_captured], the capture is at most that old. Only the first wait for the edge
    after the arm, while [awaiting], captures. [capture_bounded]: this is [mov t,
    capture] with a captured edge, so the next phase lies in [cycles + 1, next_phase].
    [halts]: no next entry. *)
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
    ; halts : 'a
    }
  [@@deriving hardcaml]
end

module Make (Comb : Comb.S) : sig
  val step
    :  side_set_count:Comb.t
    -> fraction:Comb.t
    -> loaded:Comb.t With_valid.t
    -> capture:Comb.t Capture.t
    -> word:Comb.t
    -> phase:Comb.t
    -> period:Comb.t
    -> x:Comb.t
    -> y:Comb.t
    -> arm:Comb.t
    -> arm_known:Comb.t
    -> captured:Comb.t
    -> awaiting:Comb.t
    -> Comb.t Step.t

  (** [next] is the row after this one, [target] the jump's. *)
  val conjuncts
    :  side_set_count:Comb.t
    -> fraction:Comb.t
    -> loaded:Comb.t With_valid.t
    -> capture:Comb.t Capture.t
    -> word:Comb.t
    -> row:Comb.t Row.t
    -> next:Comb.t Row.t
    -> target:Comb.t Row.t
    -> Comb.t Conjuncts.t

  (** Every one of [conjuncts]. *)
  val accepts
    :  side_set_count:Comb.t
    -> fraction:Comb.t
    -> loaded:Comb.t With_valid.t
    -> capture:Comb.t Capture.t
    -> word:Comb.t
    -> row:Comb.t Row.t
    -> next:Comb.t Row.t
    -> target:Comb.t Row.t
    -> Comb.t

  val following : wrap_top:Comb.t -> wrap_bottom:Comb.t -> Comb.t -> Comb.t
  val is_full : Comb.t Row.t -> Comb.t
  val offset_is_full : Comb.t Row.t -> Comb.t
  val arm_is_full : Comb.t Row.t -> Comb.t

  (** The pcs of the rows [accepts] reads as [next] and [target] for the word at [pc]. *)
  val successors
    :  wrap_top:Comb.t
    -> wrap_bottom:Comb.t
    -> pc:Comb.t
    -> word:Comb.t
    -> Comb.t * Comb.t

  (** Whether the core lies inside a row, bound by bound. [offset] is the core's
      [phase - row.slope * x] modulo the timer; a full arm range says nothing of [arm],
      and [captured] and [awaiting] bound only when the row sets them. *)
  val within
    :  Comb.t Row.t
    -> phase:Comb.t
    -> offset:Comb.t
    -> period:Comb.t
    -> x:Comb.t
    -> y:Comb.t
    -> arm:Comb.t
    -> arm_known:Comb.t
    -> captured:Comb.t
    -> awaiting:Comb.t
    -> Comb.t Holds.t

  (** The row bounds nothing, which [check] asks of the row at pc 0: the core starts there
      with every register and the capture state anything. *)
  val starts_open : Comb.t Row.t -> Comb.t
end

module Table : sig
  type t = Bits.t Row.t array

  (** The analyser's rows; pcs it does not reach are empty. *)
  val of_analyser : Analyser.Row.t list -> t

  (** The slope and the ends of the offset that [of_analyser] keeps of an analyser row's,
      if any: it keeps them when the slope is not zero and it and both ends are values of
      the timer read as signed, and otherwise makes the offset full. *)
  val offset_bounds : slope:int -> Interval.t -> (int * int * int) option
end

(** Checks every pc; words past the program read zero. [period] is [loaded]. A rejection
    names each pc and the conjuncts that fail there. *)
val check
  :  ?period:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> words:int list
  -> Table.t
  -> unit Or_error.t

(** [step] as a circuit, for the RTL proof to use the same definition. *)
module I : sig
  type 'a t =
    { side_set_count : 'a
    ; fraction : 'a
    ; loaded : 'a With_valid.t
    ; capture : 'a Capture.t
    ; word : 'a
    ; phase : 'a
    ; period : 'a
    ; x : 'a
    ; y : 'a
    ; arm : 'a
    ; arm_known : 'a
    ; captured : 'a
    ; awaiting : 'a
    }
  [@@deriving hardcaml]
end

module O = Step

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t

(** [accepts], [within] and [starts_open] of [row] and the pcs of [next] and [target], as
    a circuit for [formal/phase_table.sby]. Each row is packed, its first field at the
    top. *)
module Accepts : sig
  module I : sig
    type 'a t =
      { side_set_count : 'a
      ; fraction : 'a
      ; loaded : 'a With_valid.t
      ; capture : 'a Capture.t
      ; wrap_top : 'a
      ; wrap_bottom : 'a
      ; pc : 'a
      ; word : 'a
      ; row : 'a
      ; next : 'a
      ; target : 'a
      ; phase : 'a
      ; offset : 'a
      ; period : 'a
      ; x : 'a
      ; y : 'a
      ; arm : 'a
      ; arm_known : 'a
      ; captured : 'a
      ; awaiting : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { next_pc : 'a
      ; target_pc : 'a
      ; accepts : 'a
      ; within : 'a
      ; starts_open : 'a
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
