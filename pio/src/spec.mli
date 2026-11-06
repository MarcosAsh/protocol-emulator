(** The flags [pio_check] takes besides the [.pio] file. They come from the command line,
    or from text with one flag per line, which is how the playground passes them. *)

open! Core

type t =
  { program : string option (** Check only this program, or every program when [None]. *)
  ; pins : string list (** In the format [Timing.Pin.of_string] reads. *)
  ; initials : string list (** ["name=0"] or ["name=1"], where name is one of [pins]. *)
  ; rules : string list (** In the format [Timing.Rule.of_string] reads. *)
  ; autopull : bool
  ; autopush : bool
  ; fifo_ready : bool
  ; irq_wait_halts : bool
  ; set_count : int
  ; out_count : int
  ; exec : string list (** In the format [Timing.Exec_sequence.of_string] reads. *)
  ; sys_hz : float option
  ; clkdiv : float option (** Uses the program's [.clock_div] when [None]. *)
  ; cell : int option
  ; entry : string option
  ; no_stretch : string list
  }
[@@deriving sexp_of]

(** No flags: one set pin and one out pin, nothing else. *)
val default : t

(** One flag per line, spelled as on the [pio_check] command line but without the dash,
    like [pin sda=set0:dir,in0] or [autopull]. [#] starts a comment. The flags are added
    to [base], which is [default] if not given. *)
val of_string : ?base:t -> string -> t Or_error.t

(** The programs that [program] names, in order. It is an error if none match. *)
val select : t -> Pioasm.Program.t list -> Pioasm.Program.t list Or_error.t

(** Checks every flag that needs no program, then returns a function giving each program's
    config. [exec] sequences use the program's labels, so they can only fail in that
    function. A rule in [ns] or [us] needs [sys_hz]. *)
val configure : t -> (Pioasm.Program.t -> Timing.Config.t Or_error.t) Or_error.t
