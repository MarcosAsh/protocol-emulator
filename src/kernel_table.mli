(** The table the kernel checks, built from the analyser's rows, and the check of every
    row, which [Kernel] documents. *)

open! Core
open! Hardcaml
open Kernel_types

module Make_timer (Timer : Engine.Timer) : sig
  open Kernel_types.Make_timer(Timer)

  module Table : sig
    type t = Bits.t Row.t array

    val of_analyser : Analyser.Row.t list -> t
    val offset_bounds : slope:int -> Interval.t -> (int * int * int) option

    val with_edges
      :  ?single_capture_edge:bool
      -> ?widen_after:int
      -> t
      -> config:Program_config.t
      -> spacing:Bits.t Spacing.t
      -> words:int list
      -> t
  end

  module Rejection : sig
    type t =
      { pc : int
      ; fails : string list
      }
    [@@deriving sexp_of]
  end

  val rejections
    :  ?period:int
    -> ?period_floor:int
    -> ?single_capture_edge:bool
    -> ?spacing:Spacing.Spec.t
    -> config:Program_config.t
    -> words:int list
    -> Table.t
    -> Rejection.t list

  val check
    :  ?period:int
    -> ?period_floor:int
    -> ?single_capture_edge:bool
    -> ?spacing:Spacing.Spec.t
    -> config:Program_config.t
    -> words:int list
    -> Table.t
    -> unit Or_error.t
end
