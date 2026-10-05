(** Every firmware the repo runs, checked by the kernel, with the assumptions it was
    checked under: the library, each test/*.asm as test/firmware.mk assembles it, and the
    outside chip acts' firmware as test/python/write_bench_firmware.ml checks it. [period]
    is the load the kernel takes, the floor where there is one. *)

open! Core
open Protocol_emulator

type t =
  { name : string
  ; timed : Timed_program.t
  ; period : int option
  ; single_capture_edge : bool
  }

val all : t list
