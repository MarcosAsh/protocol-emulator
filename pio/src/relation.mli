(** A checker that a translated program keeps its PIO program's timing, trusting neither
    the translator nor its layout. Every path from a marker ([wait t+] released on a
    step's first PIO cycle) takes [per_cycle] [wait t+]s per PIO cycle, writes or samples
    pins one cycle after it (two for a [jmp pin] after a side-set nop), and reaches a next
    step's marker. A stall re-anchors [t]. *)

open! Core
open Protocol_emulator

module Site : sig
  type t =
    | Pc of int
    | Exec of
        { entry : int (** Index in the exec table. *)
        ; return : int (** Where the machine goes afterwards. *)
        }
  [@@deriving sexp_of, compare, equal, hash]
end

module Step : sig
  type t =
    { site : Site.t
    ; side : int (** The side-set pin value on entry, as PIO writes it. *)
    ; markers : int list
    }
  [@@deriving sexp_of]
end

type t =
  { period : int
  ; per_cycle : int (** [wait t+]s per PIO cycle. *)
  ; steps : Step.t list
  ; entry : Site.t
  ; side_init : int
  ; side_by_set : bool
  (** Side-set is done with [set] because it shares pins with [out], one write each. *)
  }
[@@deriving sexp_of]

(** The address after [pc], applying [.wrap] as PIO does. *)
val following : Pioasm.Program.t -> int -> int

val instruction
  :  Pioasm.Program.t
  -> exec:Pioasm.Instruction.t array
  -> Site.t
  -> Pioasm.Instruction.t

(** The PIO cycles a step takes when it doesn't stall. *)
val cycles : Pioasm.Instruction.t -> int

(** The sites a step can go to next. *)
val successors
  :  Pioasm.Program.t
  -> exec:Pioasm.Instruction.t array
  -> Site.t
  -> Site.t list

(** Checks every path from every marker, and that the prologue reaches the entry step.
    Direction bits are inverted when [dirs_inverted]. *)
val check
  :  Pioasm.Program.t
  -> exec:Pioasm.Instruction.t array
  -> dirs_inverted:bool
  -> config:Program_config.t
  -> Isa.t list
  -> t
  -> unit Or_error.t
