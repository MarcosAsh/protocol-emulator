(** The [src/] line each Verilog name of a design came from: the line that named it, else
    the innermost [src/] frame of its own module past derived interface code, else its
    driver's. Hardcaml's stack is cut at 16 frames and loses inlined ones. *)

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
