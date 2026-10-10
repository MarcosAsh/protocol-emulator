(** The sweep: every library firmware engine 1 can stamp, its watched output moved to wire
    20 and its other outputs beside it, with the words the host pushes. *)

open! Core
open Protocol_emulator

(** The wire engine 1 stamps. *)
val wire : int

type t =
  { name : string (** As in [Certified]. *)
  ; watch : string (** The output on the wire. *)
  ; on_wire : Program_config.t -> Program_config.t
  ; period : int option (** The host's first word, for firmware that takes it. *)
  ; bursts : int list list (** Each pushed once the one before is quiet. *)
  }

(** The firmware's line on the wire. *)
val line : Program_config.t -> Program_config.t

(** A burst a character. *)
val bytes : string -> int list list
