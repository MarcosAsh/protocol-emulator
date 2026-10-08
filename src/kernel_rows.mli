(** The kernel's records, sized by the timer's width. *)

open! Core
module Make (_ : Engine.Timer) : Kernel_intf.Rows
