(** The kernel as a chip runs it at load: the host writes a certificate to the data memory
    and the chip walks the program in its own memory against it, refusing to start one
    that fails. A certificate stores rows only at the wrap and jump targets; every other
    row is the kernel's [fall_through] image of the row before it. Rows carry no Spacing
    and no slope, so firmware that needs either is refused.

    Layout from [base]: the entry count and the wide count, each its low byte, then three
    words an entry, sorted by pc, then the wide dictionary, three words an interval, then
    the narrow one, two words an interval; addresses wrap at the memory's size. An entry
    is a pc, the captured and awaiting bits and seven bit indices into the dictionaries for
    the phase and arm (wide) and the period, x and y (narrow), index 0 being the field's
    whole range. *)

open! Core
open! Hardcaml

type t [@@deriving sexp_of]

(** The rows of [table] at the wrap and jump targets, the program being [words] under
    [config]. Fails if a dictionary outgrows its indices. *)
val of_table : config:Program_config.t -> words:int list -> Kernel.Table.t -> t Or_error.t

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
