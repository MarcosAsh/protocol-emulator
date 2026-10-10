(** The kernel as a chip runs it at load: the host writes a certificate to the data memory
    and the chip walks the program in its own memory against it, refusing to start one
    that fails. A certificate stores rows only at the wrap and jump targets; every other
    row is the kernel's [fall_through] image of the row before it. Rows carry no Spacing
    and no slope, so firmware that needs either is refused.

    Layout from [base]: the entry count and the wide count, each its low byte, then three
    words an entry, sorted by pc, then the wide dictionary, three words an interval, then
    the narrow one, two words an interval; addresses wrap at the memory's size. *)

open! Core
open! Hardcaml

(** An entry, packed from the top of its three words with [pc] highest: the captured and
    awaiting bits and indices into the dictionaries for the phase and arm (wide) and the
    period, x and y (narrow), index 0 being the field's whole range. *)
module Entry : sig
  type 'a t =
    { pc : 'a
    ; captured : 'a
    ; awaiting : 'a
    ; phase : 'a
    ; arm : 'a
    ; period : 'a
    ; x : 'a
    ; y : 'a
    }
  [@@deriving hardcaml]
end

(** The bits below an entry's fields, unused. *)
val unused_bits : int

type t [@@deriving sexp_of]

(** The rows of [table] at the wrap and jump targets, the program being [words] under
    [config]. [registers_whole] stores x and y as their whole ranges, so one certificate
    serves programs that differ only in what they set them to. Fails if a dictionary
    outgrows its indices. *)
val of_table
  :  ?registers_whole:bool
  -> config:Program_config.t
  -> words:int list
  -> Kernel.Table.t
  -> t Or_error.t

(** [of_table] on the analyser's rows for [words] under the assumptions, as a host makes
    the certificate for a program it holds only as words. *)
val of_program
  :  ?registers_whole:bool
  -> ?period:int
  -> ?period_floor:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> int list
  -> t Or_error.t

(** The data memory's words, from [base]. *)
val to_words : t -> int list

(** A pc [walk] refuses and why: a conjunct, as [Kernel.check] names them, or the table. *)
module Rejection : sig
  type t =
    { pc : int
    ; reason : string
    }
  [@@deriving sexp_of]
end

(** [walk]'s step at a pc, over [Kernel.Make]: the row it holds next, which is the stored
    entry's, [stored_row], where [stored], and whether a conjunct fails, [reason] the
    first in [Kernel.Conjuncts.to_list] order, and each. [next] and [target] are the rows
    looked up at the successors; [next] is unread where the pc falls through.
    [formal/complete.sv] takes the circuit for the walk the load checker is proved to
    keep. *)
module Step : sig
  module I : sig
    type 'a t =
      { side_set_count : 'a
      ; fraction : 'a
      ; loaded : 'a With_valid.t
      ; capture : 'a Kernel.Capture.t
      ; wrap_top : 'a
      ; wrap_bottom : 'a
      ; pc : 'a
      ; word : 'a
      ; row : 'a
      ; stored : 'a
      ; stored_row : 'a
      ; next : 'a
      ; target : 'a
      }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t =
      { next_pc : 'a
      ; target_pc : 'a
      ; after : 'a
      ; fails : 'a
      ; reason : 'a
      ; conjuncts : 'a Kernel.Conjuncts.t
      }
    [@@deriving hardcaml]
  end

  module Make (Comb : Comb.S) : sig
    val step
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t With_valid.t
      -> capture:Comb.t Kernel.Capture.t
      -> pc:Comb.t
      -> word:Comb.t
      -> row:Comb.t Kernel.Row.t
      -> stored:Comb.t
      -> stored_row:Comb.t Kernel.Row.t
      -> next_pc:Comb.t
      -> next:Comb.t Kernel.Row.t
      -> target:Comb.t Kernel.Row.t
      -> Comb.t Kernel.Row.t * Comb.t * Comb.t * Comb.t Kernel.Conjuncts.t
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end

(** The chip's walk over [words], reading the certificate from [memory] at [base], under
    [loaded] and [single_capture_edge] as the host sets them. [Ok rows] gives the row it
    held at each pc, which [Kernel.check] accepts. *)
val walk
  :  ?loaded:int
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> words:int list
  -> memory:(int -> int)
  -> base:int
  -> unit
  -> (Kernel.Table.t, Rejection.t) Result.t
