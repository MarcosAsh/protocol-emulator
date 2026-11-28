(** Assembler for the core, in the style of the RP2040 PIO assembler. Operands are the
    lower-case [Isa] constructor names, with [side N] and [delay] modifiers, [;] comments,
    labels ending in [:] and decimal, [0x] or [0b] numbers. [.wrap_target] and [.wrap]
    mark a zero-cycle loop. With side-set on, every non-[jmp] instruction must carry
    [side]. [mov] sources take [!] or [::]. *)

open! Core

module Program : sig
  type t =
    { side_set_count : int
    ; wrap_bottom : int
    ; wrap_top : int
    ; instructions : Isa.t list
    }
  [@@deriving sexp_of, compare, equal]

  val words : t -> int list Or_error.t

  (** Fills in the side-set count and wrap addresses. *)
  val configure : t -> Program_config.t -> Program_config.t
end

(** Errors carry the line number and the offending line. *)
val assemble : string -> Program.t Or_error.t

(** [assemble] plus the source line of each instruction by pc. On error, each fault's line
    comes beside its error: every bad label, directive or line past the memory, or if
    there are none, every instruction at fault. Lines count from 1. *)
val assemble_with_lines : string -> (Program.t * int list, (int * Error.t) list) Result.t

(** Inverse of [assemble] for one instruction, with a numeric jump target. *)
val to_string : side_set_count:int -> Isa.t -> string
