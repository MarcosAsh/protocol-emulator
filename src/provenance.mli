(** The [src/] line each Verilog name of a design came from. A named signal takes the line
    that named it, any other the innermost [src/] frame of the stack Hardcaml keeps for it
    inside its own module, past derived interface code, and a wire with neither its
    driver's. The stack is cut at 16 frames and loses inlined ones, so some get none. *)

open! Core
open! Hardcaml

module Source : sig
  type t =
    { file : string
    ; line : int
    ; named : bool (** The line named it, rather than made it. *)
    }
  [@@deriving compare, sexp_of]

  val to_string : t -> string
end

(** Runs [f] with Hardcaml keeping each new signal's call stack. *)
val traced : (unit -> 'a) -> 'a

(** Each module's Verilog names, sorted, with their lines. A constant shared by several
    signals takes the line of the first. *)
val of_rtl
  :  Rtl.Hierarchical_circuits.t list
  -> (string * (string * Source.t option) list) list

(** As JSON: modules to names to ["file:line"], or [null] when unresolved. *)
val to_json : (string * (string * Source.t option) list) list -> string
