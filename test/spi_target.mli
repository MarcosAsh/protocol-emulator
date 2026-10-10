(** SPI target in any of the four modes, MSB first, for a controller that frames whole
    bytes, as [Spi_cs.master] does. It shifts only while CS is low, starts each frame with
    nothing shifted in, lets MISO go to 0 while CS is high, and pushes each byte it takes.
    Replies are host words [byte lsl 8], taken a byte ahead: the reply for a byte is
    fetched as the byte before it ends, or at the start, and one the frame does not clock
    keeps for the next frame's first byte. With none queued the reply is 0xff. *)

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

(** SCK's least half period: between bytes the poll of SCK and CS takes up to this, less
    the cycle each way the pins are registered. *)
val shortest_half : int
