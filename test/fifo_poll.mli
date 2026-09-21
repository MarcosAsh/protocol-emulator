(** Programs that poll the host fifos with the four fifo jumps instead of waiting on them:
    the first with [jmp tx] and [jmp !rx], the second with [jmp !tx] and [jmp rx]. Both
    copy host words from tx to rx and drop them when rx is full. *)

open! Core

val programs : string list
