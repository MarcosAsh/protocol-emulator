(** The check a recorded protocol puts in its frames, found from the frames alone: a byte
    sent again inverted, an XOR or sum of the bytes, or a CRC, whose width, polynomial,
    init and final XOR are searched the way CRC RevEng does. A rule is taken only when the
    frames hold more evidence than the search could match by chance, so a few frames, or
    frames that differ in too few places, give no rule rather than a guess.

    Bits are in the order they were sent. A CRC runs over them in that order with the
    register shifting left, which is how a receiver checks any CRC bit by bit; a reflected
    CRC over LSB-first bytes is the same thing with its constants reversed. *)

open! Core

module Crc_model : sig
  type t =
    { width : int
    ; poly : int (** Normal form, the top bit implicit. *)
    ; init : int
    ; xorout : int
    ; start : int
    (** The first bit covered; the check is the frame's last [width] bits. *)
    ; check_lsb_first : bool (** The check sent from its low bit. *)
    ; init_known : bool
    (** Frames of more than one length tell [init] from [xorout]; frames of one length
        only fix the pair, and [init] is then the one that goes with [xorout] = 0 or a
        catalogue pair. *)
    }
  [@@deriving sexp_of, equal]
end

module Rule : sig
  type t =
    | Inverse of
        { source : int
        ; target : int
        } (** Byte [target] is byte [source] inverted. *)
    | Xor of
        { first : int
        ; target : int
        } (** The last byte is the XOR of bytes [first] up to it. *)
    | Sum of
        { first : int
        ; target : int
        ; lsb_first : bool
        ; negate : bool (** Two's complement, so the bytes sum to zero. *)
        } (** The last byte is the sum of bytes [first] up to it, modulo 256. *)
    | Crc of Crc_model.t
  [@@deriving sexp_of, equal]

  (** As a person would write it, with byte values read [lsb_first], and for a CRC the
      catalogue name if one matches. *)
  val to_string : lsb_first:bool -> t -> string

  (** The bits it writes. *)
  val targets : t -> frame_bits:int -> int list
end

(** Bits the search weighed against how many ways it could have matched by chance, both as
    powers of two. *)
module Evidence : sig
  type t =
    { bits : int
    ; hypotheses : float
    }
  [@@deriving sexp_of]
end

(** Every rule the frames, all [frame_bits] long, support, and for each its evidence.
    [lsb_first] is how bytes are read, for sums and catalogue names only. *)
val find : lsb_first:bool -> bool array list -> (Rule.t * Evidence.t) list

(** The frame with each rule's target bits filled in, in order. *)
val apply : Rule.t list -> bool array -> bool array

(** Whether the frame already holds every rule. *)
val holds : Rule.t list -> bool array -> bool

(** The serial CRC of [bits] from [init], shifting left. *)
val crc : width:int -> poly:int -> init:int -> bool array -> int

(** Bytes of the frame, 8 bits each from bit 0, read LSB or MSB first; a short tail is
    dropped. *)
val bytes : lsb_first:bool -> bool array -> int array
