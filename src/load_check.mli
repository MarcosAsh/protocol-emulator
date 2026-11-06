(** The kernel as a chip runs it at load. The host writes a certificate to the data
    memory, and the chip walks the program in its own memory against it, refusing to start
    one that fails. A certificate stores rows only at the wrap and jump targets; every
    other row is the kernel's [fall_through] image of the row before it. Rows carry no
    Spacing and no slope, so firmware that needs either is refused.

    Layout from [base]: the entry count and the wide count (each its low byte), then three
    words per entry sorted by pc, then the wide dictionary (three words per interval),
    then the narrow one (two words per interval). Addresses wrap at the memory's size. *)

open! Core
open! Hardcaml

(** An entry, packed from the top of its three words with [pc] highest. It holds the
    captured and awaiting bits, plus indices into the dictionaries for the phase and arm
    (wide) and the period, x and y (narrow). Index 0 is the field's whole range. *)
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

(** The rows of [table] at the wrap and jump targets, where the program is [words] under
    [config]. [registers_whole] stores x and y as their whole ranges, so one certificate
    serves programs that differ only in what they set them to. Fails if a dictionary
    outgrows its indices, or the certificate outgrows the data memory. *)
val of_table
  :  ?registers_whole:bool
  -> config:Program_config.t
  -> words:int list
  -> Kernel.Table.t
  -> t Or_error.t

(** [of_table] on the analyser's rows for [words] under the assumptions, as a host makes
    the certificate for a program it only has as words. *)
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

(** A pc that [walk] refuses, and why: a conjunct (named as [Kernel.check] names them) or
    the table. *)
module Rejection : sig
  type t =
    { pc : int
    ; reason : string
    }
  [@@deriving sexp_of]
end

(** [walk]'s step at a pc, over [Kernel.Make]. Gives the row held next (the stored
    entry's, [stored_row], where [stored]), whether a conjunct fails, [reason] (the first
    in [Kernel.Conjuncts.to_list] order), and each conjunct. [next] and [target] are the
    rows looked up at the successors; [next] is unread where the pc falls through.
    [formal/complete.sv] takes the circuit for the walk that the load checker is proved to
    keep. *)
module Step : sig
  module I : sig
    type 'a t =
      { side_set_count : 'a
      ; fraction : 'a
      ; loaded : 'a Kernel.Loaded.t
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
      -> loaded:Comb.t Kernel.Loaded.t
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
    [loaded], [floor] and [single_capture_edge] as the host sets them. [Ok rows] gives the
    row it held at each pc, which [Kernel.check] accepts. *)
val walk
  :  ?loaded:int
  -> ?floor:bool
  -> ?single_capture_edge:bool
  -> config:Program_config.t
  -> words:int list
  -> memory:(int -> int)
  -> base:int
  -> unit
  -> (Kernel.Table.t, Rejection.t) Result.t
