(** The instruction set as the page lays it out, read from [Isa] and nowhere else: the
    field positions and the names of each field's values. *)

open! Core

module Slot : sig
  type t =
    { name : string
    ; lsb : int
    ; width : int
    ; cases : (int * string) list (** Empty for a plain number. *)
    }
end

(** Each opcode's number, name and fields, the opcode field first. [side_set_count] splits
    the delay field into [side] and [delay]. *)
val opcodes : side_set_count:int -> (int * string * Slot.t list) list

type decoded =
  { text : string (** The assembler's text for the word, empty if [error]. *)
  ; error : string
  ; slots : (Slot.t * int) list (** The word's fields and their values. *)
  }

val decode : side_set_count:int -> int -> decoded

(** One instruction line through the assembler, to its word. *)
val assemble : side_set_count:int -> string -> (int, string) Result.t
