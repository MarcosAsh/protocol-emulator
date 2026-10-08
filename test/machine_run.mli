open! Core
open Protocol_emulator

(** Writes the first of [pending] to the TX fifo if it has room, and returns what is left
    to write. *)
val feed : Machine.t -> int list -> Machine.t * int list

(** [feed] over [(cycle, word)] pairs: the first word waits until [now] reaches its cycle. *)
val feed_due : Machine.t -> (int * int) list -> now:int -> Machine.t * (int * int) list

(** Writes all of [words] to the TX fifo; they must fit. *)
val write_all : Machine.t -> int list -> Machine.t

(** Takes one word from the RX fifo, if there is one, onto the front of [received]. *)
val receive : Machine.t -> int list -> Machine.t * int list

(** Steps the model [cycles] times with constant [inputs], feeding [tx] as the fifo has
    room, and returns the level of [pin] (default OUT0) after each step. *)
val run
  :  ?tx:int list
  -> ?pin:int
  -> Machine.t
  -> cycles:int
  -> inputs:int
  -> Machine.t * int list
