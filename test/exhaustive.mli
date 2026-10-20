(** Kernel precision by bounded-exhaustive enumeration: every program of [words] words
    over a small timing alphabet, each run on [Machine] for its ground truth and checked
    by the kernel, as [Timed_program.check] does after assembly.

    The truth is exact for the alphabet. Nothing in it reads [now], [t] or the pins, so a
    run's path depends on [x] and [p] alone, and waits only stall. At start [now] is zero
    and [x], [p] and [t] are anything, as [Kernel.check] takes them:
    - a deadline wait reached before any [mov t, now] is late for some start [t], as its
      phase is the start's plus a constant;
    - [p] only moves [t] on, so a smaller [p] makes every later entry no earlier, and the
      model's start, zero, is the worst;
    - [x] is the one start value left, so a program that may count it down before setting
      it is out of scope. A run is safe once its state at an issue repeats: pc, [x], [p]
      and, after the first [mov t, now], the phase. *)

open! Core
open Protocol_emulator

module Bound : sig
  type t =
    { words : int
    ; delays : int list
    ; imms : int list (** [alu t] steps. *)
    ; values : int list (** [set p] and [set x] values. *)
    }
  [@@deriving sexp_of]

  (** Seconds, for an expect test. *)
  val tiny : t

  (** Minutes on a laptop. *)
  val laptop : t
end

module Class : sig
  type t =
    | Wait (** [wait t] *)
    | Wait_advance (** [wait t+] *)
    | Anchor (** [mov t, now] *)
    | Step (** [alu t] *)
    | Set_p
    | Set_x
    | Count (** [jmp x--] *)
    | Jump
    | Nop
    | Halt
  [@@deriving sexp_of, compare, enumerate, equal]

  val of_instruction : Isa.t -> t
end

(** The instructions a program of the bound is made of. *)
val alphabet : Bound.t -> Isa.t list

(** Pcs a run can reach from 0, by the words alone; past the program is [jmp 0]. *)
val reachable : Isa.t array -> bool array

(** Every reachable [jmp x--] is reached only after a [set x] on every way in. *)
val sets_x_first : Isa.t array -> bool

(** Every program of the bound once, by index: words no run reaches are [alphabet]'s
    first. *)
val programs : Bound.t -> (int * Isa.t array) Sequence.t

module Truth : sig
  type t =
    | Safe of { waited : bool } (** [waited]: the run released a deadline wait. *)
    | Late of { pc : int } (** A run released a deadline wait late. *)
    | Unanchored of { pc : int }
    (** A deadline wait reached before any [mov t, now]: late for some start [t]. *)
    | Undecided (** No state repeated within the horizon. *)
  [@@deriving sexp_of, compare, equal]

  val is_safe : t -> bool
end

(** [horizon] in cycles, 4M by default. Raises unless [sets_x_first]. *)
val truth : ?horizon:int -> Isa.t array -> Truth.t

(** What [Timed_program.check] decides after assembly: the analyser finds no late row and
    [Kernel.check] passes its table. Fast, as it checks only the rows the analyser fills. *)
val admits : Isa.t array -> bool

(** Why the kernel refuses, from [Kernel.check] itself: the analyser's late rows, else the
    kernel's rejections, each as the instruction's class and what fails. Empty when
    admitted. *)
val refusal : Isa.t array -> (Class.t * string) list

(** The words in assembly, separated by [;]. *)
val to_string : Isa.t array -> string

module Report : sig
  type t =
    { bound : Bound.t
    ; programs : int
    ; out_of_scope : int (** May count [x] down before setting it. *)
    ; checked : int
    (** Verdicts [Kernel.check] itself confirmed: every one a figure below names and a
        sample. *)
    ; truths : (string * int) list
    ; safe : int * int (** Safe programs, and how many of them are admitted. *)
    ; waiting : int * int (** The same, of those whose run releases a deadline wait. *)
    ; unsound : string list (** Admitted and not safe. Never. *)
    ; by_class : (Class.t * (int * int)) list
    (** The same, of those that reach the class. *)
    ; refused :
        ((bool * Class.t list * (Class.t * string) list) * (int * int * Isa.t array)) list
    (** Safe and refused, grouped by whether the run waits, the shape (the classes of the
        words a run can reach) and [refusal]: the count, and the first by index. *)
    }
  [@@deriving sexp_of]

  (** Of two shards. *)
  val merge : t -> t -> t
end

(** [admits] of every program in scope, and [refusal] of every one a figure names and
    every [check_every]th by index, 1000 by default; raises if they disagree. [shard]
    [(k, n)] takes the indices [k] modulo [n]. *)
val run : ?horizon:int -> ?check_every:int -> ?shard:int * int -> Bound.t -> Report.t

(** A table [Kernel.check] passes exists, by [Table_query.witness]: if so the refusal is
    the analyser's, else the kernel's rows cannot say it. Raises if the check refuses the
    witness. *)
val table_exists : Isa.t array -> bool

(** Counts, precision, the classes and the [top] refusal groups, 10 by default, those
    whose run waits first, each with [table_exists] of its example if [witness]. *)
val print : ?top:int -> ?witness:bool -> Report.t -> unit
