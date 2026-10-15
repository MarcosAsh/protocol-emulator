(** [new-protocol NAME]: a protocol's file in test/, with placeholder firmware that the
    kernel accepts and TODOs where the spec goes, its test, a bench script in python/, the
    protocol in [Library.protocols], and a sigrok decoder picked by name from sigrok-cli's
    list. Prints the steps from there to a certificate and a bench run, each with its
    command. *)

open! Core

val command : Command.t
