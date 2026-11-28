(** JTAG master: TCK on IO5 by side-set, TDI on IO6 and TMS on IO7, TDO on input 0. TMS
    and TDI change as TCK falls and the TAP takes them on the rise. The host writes a word
    per eight clocks, TDI in the even bits and TMS in the odd from bit 0 up, and reads one
    with TDO in bits 8 to 15, first clock in bit 8. TCK stays low between words, every
    edge follows a deadline wait. Shortest half period kept up with: [shortest_half]. *)

open! Core
open Protocol_emulator

val tck_pin : int
val tdi_pin : int
val tms_pin : int
val tdo_pin : int
val shortest_half : int
val firmware : half_period:int -> string
val config : Program_config.t

(** One TCK: the TMS and TDI the TAP takes on its rise. *)
module Clock : sig
  type t =
    { tms : bool
    ; tdi : bool
    }
  [@@deriving sexp_of]
end

(** Five clocks with TMS high reach Test-Logic-Reset from anywhere; one low then goes on
    to Run-Test/Idle. *)
val reset : Clock.t list

(** From Run-Test/Idle, shift [bits] of [value] into the instruction or data register, the
    least significant first, and come back to Run-Test/Idle. *)
val scan_ir : bits:int -> int -> Clock.t list

val scan_dr : bits:int -> int -> Clock.t list

(** The clocks packed eight to a word, padded with clocks that hold Run-Test/Idle. *)
val words : Clock.t list -> int list

(** What the TAP shifted out during the shift clocks of a scan, read back from the words
    the core pushed: [first] is the index of the scan's first clock in the whole sequence. *)
val shifted_out : pushed:int list -> first:int -> bits:int -> int

(** The offset of the first shift clock inside [scan_dr]. *)
val dr_shift_offset : int

(** A TAP controller with a four bit instruction register: 0x1 IDCODE (reset selects it),
    0x2 USER, an eight bit register keeping what is shifted in, and 0xf BYPASS. It follows
    IEEE 1149.1's sixteen states on each TCK rise and moves TDO on each fall. It times TCK
    high and low, and TMS and TDI set up and hold, each at least [minimum_ns]. *)
module Tap : sig
  type t

  val idcode : int
  val minimum_ns : int
  val create : clock_hz:int -> t
  val tdo : t -> int
  val step : t -> tck:int -> tms:int -> tdi:int -> t
  val user : t -> int
  val measured : t -> Measured.t
  val violations : t -> string list
end

val protocol : Protocol.t
