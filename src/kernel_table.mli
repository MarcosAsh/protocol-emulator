(** The kernel's rows as the software builds them, which [Kernel.check] does not trust. *)

open! Core
open! Hardcaml
module Make (Rows : Kernel_intf.Rows) : Kernel_intf.M(Rows).Table
