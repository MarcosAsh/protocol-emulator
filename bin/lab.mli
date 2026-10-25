(** [lab JOB -out DIR]: a remote lab job file checked as the worker checks it, its result
    folder's first files written to DIR (see [Remote_lab.files]). Exits 0 when certified,
    1 when refused, 2 when the job is malformed, with [check.json] saying why.
    [-print FILE] prints one of the files instead, for the committed examples in test/lab. *)

open! Core

val command : Command.t
