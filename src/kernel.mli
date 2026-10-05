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
    full range is an unknown phase. Rows also bound a pair of pins' edges, so that with a
    [Spacing] no edge comes too soon: [formal/phase_spacing.sby] proves that on the RTL
    for tables of intervals, taking the one-run theorem, the step lemmas and
    [pair_step.sby]'s as their own runs prove them. *)

open! Core
open! Hardcaml

(** One pin of a watched pair at an entry: the cycles since its last edge in this run,
    saturating, all ones before the first; its bit; and [fresh] until the run first writes
    it, which sets it and is not counted as an edge. *)
module Edge : sig
  type 'a t =
    { since : 'a
    ; level : 'a
    ; fresh : 'a
    }
  [@@deriving hardcaml]
end

(** A pair of pins whose edges must be spaced, each its [pindirs] bit if [dirs] else its
    [pins] bit; the config that writes them; and the least cycles, indexed
    [2 * own + other] by the two bits before an edge, from [a]'s last edge ([hold_a]) and
    [b]'s ([apart_a]), and the same for [b]. Moving at once is 0 apart. An edge is a move
    after the pin's first write in the run. Out and mov data is not followed, so a pin
    they write may move. *)
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

  (** The same, the config apart, keyed by the bits before the edge. *)
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

(** No spacing asks nothing. *)
module Spaced : With_valid.Wrap.S with type 'a value = 'a Spacing.t

(** The parts the timer's width sizes; the chip's, [Isa.timer_bits] wide, is below. The
    width leaves an instruction's cycles below half the timer's range, so 7 bits or more. *)
module Make_timer (_ : Engine.Timer) : sig
  (** A row's bound on a pin at one bit: whether it [may] hold it, and then the least
      [since], and the least [since] less the phase, [mark], which is [t] less the edge's
      entry and so keeps through jitter. A saturated [since] keeps any mark. *)
  module Held : sig
    type 'a t =
      { may : 'a
      ; since : 'a
      ; mark : 'a
      }
    [@@deriving hardcaml]
  end

  (** A row's bounds on a pin, at each bit, and [fresh] where it is not yet written. *)
  module Pin : sig
    type 'a t =
      { at0 : 'a Held.t
      ; at1 : 'a Held.t
      ; fresh : 'a
      }
    [@@deriving hardcaml]
  end

  (** [slope] is signed. [offset_lo] and [offset_hi] bound [phase - slope * x], taken
      modulo the timer and read as signed, and their full range bounds nothing. A counted
      loop that moves [t] by the same amount on every pass keeps it: its phase has no
      bound short of the full range, but where [jmp x--] falls through, x is zero and the
      phase lies inside the offset. The kernel follows it across [set x] and across a step
      that adds to the phase and leaves x alone or counts it down, with the slope the same
      on both rows; on any other step the next row's offset has to be full. *)
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

  (** The capture pin and edge, and whether the single-edge assumption is taken: the pin
      is at the other level when [capture_arm] issues and, once at the captured level,
      stays there until the wait for it releases. *)
  module Capture : sig
    type 'a t =
      { pin : 'a
      ; rising : 'a
      ; single_edge : 'a
      }
    [@@deriving hardcaml]
  end

  (** What a row asks of the row it steps to: its phase, offset, registers and capture
      state each land inside that row's. *)
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

  (** [accepts] one conjunct at a time, so a rejection says which fails. [in_time]: a
      deadline wait is entered at phase zero or below. [wide_a] and [wide_b]: an edge the
      word may make keeps the pin's spacing. [next] and [target]: the row maps into the
      next pc's, and into the jump target's, on each way out the instruction may take. A
      conjunct that does not apply, as for an empty row or a halt, holds. *)
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

  (** The next entry's phase: anything unless [bounded], one less too if [may_carry].
      [next_period] holds when [period_known]. [loaded], when valid, is the assumption
      that every run-time write to [p] carries its value. The same for [x] and [y]. A jump
      goes to its target when [taken], if [taken_known]. [next_arm] counts the cycles
      since [capture_arm], leaving out a capturing wait's own wait, when [next_arm_known];
      once [next_captured], the capture is younger than that, as the arm takes effect a
      cycle late. Only the first wait for the edge after the arm, while [awaiting],
      captures. [capture_bounded]: this is [mov t, capture] with a captured edge, so the
      next phase lies in [cycles + 1, next_phase]. [next_a] and [next_b]: the pair's edge
      states, an edge showing the cycle after the entry, where out or mov data puts
      [data_a] and [data_b] on them; [wide_a] and [wide_b]: each keeps its spacing.
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
      ; next_a : 'a Edge.t
      ; next_b : 'a Edge.t
      ; wide_a : 'a
      ; wide_b : 'a
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
      -> spacing:Comb.t Spaced.t
      -> word:Comb.t
      -> phase:Comb.t
      -> period:Comb.t
      -> x:Comb.t
      -> y:Comb.t
      -> arm:Comb.t
      -> arm_known:Comb.t
      -> captured:Comb.t
      -> awaiting:Comb.t
      -> a:Comb.t Edge.t
      -> b:Comb.t Edge.t
      -> data_a:Comb.t
      -> data_b:Comb.t
      -> Comb.t Step.t

    (** [next] is the row after this one, [target] the jump's. *)
    val conjuncts
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t With_valid.t
      -> capture:Comb.t Capture.t
      -> spacing:Comb.t Spaced.t
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
      -> spacing:Comb.t Spaced.t
      -> word:Comb.t
      -> row:Comb.t Row.t
      -> next:Comb.t Row.t
      -> target:Comb.t Row.t
      -> Comb.t

    (** The tightest row [conjuncts] lets the next pc's be on the way of falling through,
        with no spacing and the offset left full, and whether that way is asked: where it
        is not, any row holds. [test/test_kernel.ml] proves it field by field. *)
    val fall_through
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t With_valid.t
      -> capture:Comb.t Capture.t
      -> word:Comb.t
      -> row:Comb.t Row.t
      -> Comb.t Row.t * Comb.t

    val no_spacing : Comb.t Spaced.t

    (** An edge state at the start of a run, not yet written. *)
    val starting : level:Comb.t -> Comb.t Edge.t

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
        [captured] and [awaiting] bound only when the row sets them, and the pins only
        with a [spacing]. *)
    val within
      :  Comb.t Row.t
      -> spacing:Comb.t Spaced.t
      -> phase:Comb.t
      -> offset:Comb.t
      -> period:Comb.t
      -> x:Comb.t
      -> y:Comb.t
      -> arm:Comb.t
      -> arm_known:Comb.t
      -> captured:Comb.t
      -> awaiting:Comb.t
      -> a:Comb.t Edge.t
      -> b:Comb.t Edge.t
      -> Comb.t Holds.t

    (** The row bounds nothing, which [check] asks of the row at pc 0: the core starts
        there with every register and the capture state anything, and no edge yet. *)
    val starts_open : Comb.t Row.t -> spacing:Comb.t Spaced.t -> Comb.t
  end

  module Table : sig
    type t = Bits.t Row.t array

    (** The analyser's rows; pcs it does not reach are empty. *)
    val of_analyser : Analyser.Row.t list -> t

    (** The slope and the ends of the offset that [of_analyser] keeps of an analyser
        row's, if any: it keeps them when the slope is not zero and it and both ends are
        values of the timer read as signed, and otherwise makes the offset full. *)
    val offset_bounds : slope:int -> Interval.t -> (int * int * int) option

    (** The edge states of the pair, from pc 0 on over every way the table reaches; not
        trusted. *)
    val with_edges
      :  ?single_capture_edge:bool
      -> t
      -> config:Program_config.t
      -> spacing:Bits.t Spacing.t
      -> words:int list
      -> t
  end

  (** A pc [check] rejects and the conjuncts that fail there: ["in time"], ["a spaced"],
      ["b spaced"], or ["next"] or ["target"] and a [Holds] field, as ["next phase"]. *)
  module Rejection : sig
    type t =
      { pc : int
      ; fails : string list
      }
    [@@deriving sexp_of]
  end

  (** [check]'s rejections, empty when every row passes; the row at pc 0 and the spacing's
      scope aside. *)
  val rejections
    :  ?period:int
    -> ?single_capture_edge:bool
    -> ?spacing:Spacing.Spec.t
    -> config:Program_config.t
    -> words:int list
    -> Table.t
    -> Rejection.t list

  (** Checks every pc; words past the program read zero. [period] is [loaded]. [spacing]
      is refused unless its pins differ and lie in the pin space, Manchester is off and
      every row has no slope and the full offset, as [formal/phase_spacing.sby] proves it.
      A rejection names each pc and the conjuncts that fail there. *)
  val check
    :  ?period:int
    -> ?single_capture_edge:bool
    -> ?spacing:Spacing.Spec.t
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
      ; spacing : 'a Spaced.t
      ; word : 'a
      ; phase : 'a
      ; period : 'a
      ; x : 'a
      ; y : 'a
      ; arm : 'a
      ; arm_known : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; a : 'a Edge.t
      ; b : 'a Edge.t
      ; data_a : 'a
      ; data_b : 'a
      }
    [@@deriving hardcaml]
  end

  module O = Step

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t

  (** [accepts], [within] and [starts_open] of [row] and the pcs of [next] and [target],
      as a circuit for [formal/phase_table.sby] and [formal/phase_spacing.sby]. Each row
      is packed, its first field at the top. *)
  module Accepts : sig
    module I : sig
      type 'a t =
        { side_set_count : 'a
        ; fraction : 'a
        ; loaded : 'a With_valid.t
        ; capture : 'a Capture.t
        ; spacing : 'a Spaced.t
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
        ; a : 'a Edge.t
        ; b : 'a Edge.t
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
end

include module type of Make_timer (Isa)
