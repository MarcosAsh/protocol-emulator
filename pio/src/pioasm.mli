(** RP2040 PIO programs as pioasm reads them from a [.pio] file: the nine instructions,
    delay and side-set, [.wrap], [.define] and [.clock_div]. Addresses are relative to the
    program. C blocks, [.lang_opt] and [.pio_version] are skipped. *)

open! Core

module Condition : sig
  type t =
    | Always
    | X_zero
    | X_post_decrement
    | Y_zero
    | Y_post_decrement
    | X_not_y
    | Pin
    | Osr_not_empty
  [@@deriving sexp_of, equal]
end

module Source : sig
  type t =
    | Pins
    | X
    | Y
    | Null
    | Status
    | Isr
    | Osr
  [@@deriving sexp_of, equal]
end

module Destination : sig
  type t =
    | Pins
    | X
    | Y
    | Null
    | Pindirs
    | Pc
    | Isr
    | Osr
    | Exec
  [@@deriving sexp_of, equal]
end

module Wait_source : sig
  type t =
    | Gpio of int
    | Pin of int
    | Irq of int
    | Jmp_pin
  [@@deriving sexp_of, equal]
end

module Mov_op : sig
  type t =
    | Copy
    | Invert
    | Reverse
  [@@deriving sexp_of, equal]
end

module Irq_mode : sig
  type t =
    | Raise
    | Raise_and_wait
    | Clear
  [@@deriving sexp_of, equal]
end

module Op : sig
  type t =
    | Jmp of
        { condition : Condition.t
        ; target : int
        }
    | Wait of
        { polarity : bool
        ; source : Wait_source.t
        }
    | In of
        { source : Source.t
        ; bits : int
        }
    | Out of
        { destination : Destination.t
        ; bits : int
        }
    | Push of
        { if_full : bool
        ; block : bool
        }
    | Pull of
        { if_empty : bool
        ; block : bool
        }
    | Mov of
        { destination : Destination.t
        ; op : Mov_op.t
        ; source : Source.t
        }
    | Irq of
        { mode : Irq_mode.t
        ; index : int
        }
    | Set of
        { destination : Destination.t
        ; value : int
        }
  [@@deriving sexp_of, equal]
end

module Instruction : sig
  type t =
    { op : Op.t
    ; delay : int
    ; side : int option
    ; text : string (** The source text, comments and labels stripped. *)
    }
  [@@deriving sexp_of]
end

module Side_set : sig
  type t =
    { count : int (** Pins, not counting the [opt] enable bit. *)
    ; optional : bool
    ; pindirs : bool
    }
  [@@deriving sexp_of]
end

module Program : sig
  type t =
    { name : string
    ; side_set : Side_set.t
    ; instructions : Instruction.t array
    ; wrap_target : int
    ; wrap : int
    ; clock_div : float option
    ; labels : (string * int) list
    }
  [@@deriving sexp_of]
end

(** Every program in the file, in order. Errors name the line. Delays and side-set values
    are checked against the five delay/side-set bits, as pioasm does. *)
val parse : string -> Program.t list Or_error.t

(** One instruction line, labels resolved in [program] (for [out exec] tables). *)
val parse_instruction : Program.t -> string -> Instruction.t Or_error.t
