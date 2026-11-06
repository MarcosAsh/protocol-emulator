(** SPI target in any of the four modes, MSB first. It shifts only while CS is low, drives
    MISO to 0 while CS is high, and pushes each byte it takes. CS rising inside a byte
    drops that byte's bits and its reply. Replies are host words [byte lsl 8], fetched a
    byte ahead: the reply for a byte is fetched as the previous byte ends (or at the
    start). A reply the frame never clocks is kept for the next frame's first byte. With
    none queued the reply is 0xff. *)

open! Core
open Protocol_emulator

(** [sck] has to be [mosi + 1]: between bytes one read of the two tells the next byte's
    leading edge from MOSI. *)
module Pins : sig
  type t =
    { mosi : int
    ; sck : int
    ; cs : int
    ; miso : int
    }
end

(** IN1 to IN3, MISO on OUT0. *)
val pads : Pins.t

val config : Pins.t -> Program_config.t
val firmware : mode:Spi_cs.Mode.t -> Pins.t -> string

(** Smallest SCK half period. The poll of SCK and CS before each bit takes up to this many
    cycles, less one cycle each way for the pin registers. *)
val shortest_half : int

(** A faster [firmware]: each MISO bit goes out as soon as the controller has sampled the
    one before, and between bytes a three-cycle poll of MOSI, SCK and CS replaces
    [firmware]'s poll. Same bytes, replies and frames. CS has to be [mosi + 2]. *)
val fast : mode:Spi_cs.Mode.t -> Pins.t -> string

val fast_config : Pins.t -> Program_config.t

(** As [shortest_half], for [fast]. *)
val fast_shortest_half : int

(** A target in each mode on [pads], certified: none waits on a deadline. Its runs against
    [Spi_cs.master] are in [Both_roles]. *)
val protocol : Protocol.t
