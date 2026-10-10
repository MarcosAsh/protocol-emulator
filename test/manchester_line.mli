(** A 10BASE-T line for the receiver's tests, and the frames on it. *)

open! Core

(** Transitions in ns, idle low, then per bit its complement and its value, then TP_IDL
    (high 300 ns) and idle again; each edge moved independently by up to [jitter] ns, the
    bit [ppm] long or short. Returns them with a time past the end. *)
val transitions
  :  random:Random.State.t
  -> ppm:float
  -> jitter:float
  -> int list
  -> (float * int) list * float

(** The line sampled [per_bit] times a bit from a random phase, [per_cycle] to a cycle,
    earliest first. *)
val sample
  :  random:Random.State.t
  -> per_bit:int
  -> per_cycle:int
  -> (float * int) list * float
  -> int list list

(** First bit lowest. *)
val bits_of_bytes : int list -> int list

(** Seven 0x55 and the start of frame. *)
val preamble : int list

(** zlib's CRC-32. *)
val crc32 : int list -> int

(** The bytes and their FCS, as 802.3 sends it. *)
val with_fcs : int list -> int list

(** Two bytes to a word, low first, a last odd byte alone, as [Frame_rx] writes them. *)
val words : int list -> int list
