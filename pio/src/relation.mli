(** How a translated program keeps a PIO program's time, and a checker of it that trusts
    neither the translator nor its layout. Each PIO step has markers, [wait t+] words
    whose release is the step's first PIO cycle. From every marker, every path must take
    [per_cycle] [wait t+]s for each of the step's PIO cycles, make the step's pin write or
    sample the cycle after the marker (a [jmp pin] after a side-set nop, the cycle after
    that), and reach a marker of a step the PIO can go to next. A stall re-anchors [t] at
    its release. So once the kernel certifies that every [wait t+] releases on time, a PIO
    cycle takes [per_cycle] times [p] cycles here. *)

open! Core
open Protocol_emulator

module Site : sig
  type t =
    | Pc of int
    | Exec of
        { entry : int (** In the exec table. *)
        ; return : int (** Where the machine goes on after it. *)
        }
  [@@deriving sexp_of, compare, equal, hash]
end

module Step : sig
  type t =
    { site : Site.t
    ; side : int (** The side-set pins' value on the way in, as PIO writes it. *)
    ; markers : int list
    }
  [@@deriving sexp_of]
end

type t =
  { period : int
  ; per_cycle : int (** [wait t+]s a PIO cycle. *)
  ; steps : Step.t list
  ; entry : Site.t
  ; side_init : int
  ; side_by_set : bool
  (** Side-set comes by [set], as it shares pins with [out]; each a write of its own. *)
  }
[@@deriving sexp_of]

(** The address after [pc], with [.wrap] taken as PIO takes it. *)
val following : Pioasm.Program.t -> int -> int

val instruction
  :  Pioasm.Program.t
  -> exec:Pioasm.Instruction.t array
  -> Site.t
  -> Pioasm.Instruction.t

(** The PIO cycles a step takes when it does not stall. *)
val cycles : Pioasm.Instruction.t -> int

(** The sites a step can go to. *)
val successors
  :  Pioasm.Program.t
  -> exec:Pioasm.Instruction.t array
  -> Site.t
  -> Site.t list

(** Checks every path from every marker, and that the prologue reaches the entry step. A
    direction bit is complemented when [dirs_inverted]. *)
val check
  :  Pioasm.Program.t
  -> exec:Pioasm.Instruction.t array
  -> dirs_inverted:bool
  -> config:Program_config.t
  -> Isa.t list
  -> t
  -> unit Or_error.t
