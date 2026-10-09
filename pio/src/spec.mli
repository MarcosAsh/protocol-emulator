(** What [pio_check] is told besides the [.pio] file: its flags, from the command line or
    from text with one flag a line, as the playground takes them. *)

open! Core

type t =
  { program : string option (** Check only this program; every one when [None]. *)
  ; pins : string list (** As [Timing.Pin.of_string] reads them. *)
  ; initials : string list (** ["name=0"] or ["name=1"], each naming one of [pins]. *)
  ; rules : string list (** As [Timing.Rule.of_string] reads them. *)
  ; autopull : bool
  ; autopush : bool
  ; fifo_ready : bool
  ; irq_wait_halts : bool
  ; set_count : int
  ; out_count : int
  ; exec : string list (** As [Timing.Exec_sequence.of_string] reads them. *)
  ; sys_hz : float option
  ; clkdiv : float option (** The program's [.clock_div] when [None], else 1. *)
  ; cell : int option
  ; entry : string option
  ; no_stretch : string list
  }
[@@deriving sexp_of]

(** No flags: one set and one out pin, nothing else assumed. *)
val default : t

(** One flag a line, named as [pio_check] names it but without the dash:
    [pin sda=set0:dir,in0] or [autopull]. [#] starts a comment. *)
val of_string : string -> t Or_error.t

(** The programs [program] names, in order; an error when that leaves none. *)
val select : t -> Pioasm.Program.t list -> Pioasm.Program.t list Or_error.t

(** Checks every flag that needs no program, then gives each program's config. A program's
    [exec] sequences are read against its labels, so they fail there. A rule in [ns] or
    [us] needs [sys_hz]. *)
val configure : t -> (Pioasm.Program.t -> Timing.Config.t Or_error.t) Or_error.t
