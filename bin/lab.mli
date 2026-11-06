(** [lab JOB -out DIR] checks a remote lab job the way the worker does and writes the
    first files of its result folder to DIR (see [Remote_lab.files]). Exits 0 when
    certified, 1 when refused and 2 when the job is malformed; [check.json] says why.
    [-print FILE] prints one of the files instead, for the examples in test/lab. *)

open! Core

val command : Command.t
