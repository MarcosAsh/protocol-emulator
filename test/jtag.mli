(** JTAG master: TCK on IO5 by side-set, TDI on IO6 and TMS on IO7, TDO on input 0.

    JTAG is SPI mode 0 with a second output. TMS and TDI change as TCK falls and the TAP
    takes them as it rises, half a period later; TDO is taken on the same rising edge,
    half a period after the TAP moved it on the fall. The host writes a word per eight
    clocks, the pairs from bit 0 up, TDI in the even bit and TMS in the odd, and reads
    back a word per eight clocks with TDO in bits 8 to 15, the first clock in bit 8. TCK
    stays low between words, which JTAG allows, so the host can stop anywhere and walk the
    TAP wherever it likes; [reset], [scan_ir] and [scan_dr] are the usual walks.

    Every edge is the instruction after a deadline wait, so TCK is exact and TMS and TDI
    are set up and held for exactly half a period. The shortest half period the program
    keeps up with is [shortest_half] cycles. *)

open! Core
open Protocol_emulator

val tck_pin : int
val tdi_pin : int
val tms_pin : int
val tdo_pin : int
val cycle_ns : int
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

(** Five clocks with TMS high reach Test-Logic-Reset from anywhere, one low goes on to
    Run-Test/Idle. *)
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

(** The offset of the first shift clock inside [scan_ir] and [scan_dr]. *)
val ir_shift_offset : int

val dr_shift_offset : int

(** A TAP controller with a four bit instruction register: 0x1 IDCODE, which reset
    selects, 0x2 USER, an eight bit register that keeps what is shifted in, and 0xf
    BYPASS. It follows the sixteen states of IEEE 1149.1 on every rise of TCK and moves
    TDO on every fall. It times what it sees: TCK high and low, and TMS and TDI set up
    before and held after each rise, each at least [minimum_ns]. *)
module Tap : sig
  type t

  val idcode : int
  val minimum_ns : int
  val create : cycle_ns:int -> t
  val tdo : t -> int
  val step : t -> tck:int -> tms:int -> tdi:int -> t
  val user : t -> int
  val measured : t -> Measured.t
  val violations : t -> string list
end
