(** PS/2 device (the keyboard side): open drain data on IO0, clock on IO1.

    The host's first word is a quarter of the clock period in cycles: 1000 cycles (20.8 us
    at 48 MHz) gives a 12 kHz clock, inside the bus's 10 to 16.7 kHz. Every later word is
    a byte to send, and the device adds the start bit, odd parity (the CRC unit set one
    bit wide) and the stop bit. Data moves mid clock high and the host samples a quarter
    later at the fall, so setup is a quarter less the two cycles of a jump and hold is a
    quarter plus two. The bus is idle for a whole period before a frame, and the device
    checks the clock before each bit: if the host holds it low, the device drops the
    frame, releases data and raises the interrupt so the host can write the byte again.

    If the host sends a request to send (clock held low, released with data low), the
    device clocks in eight data bits, parity and stop, pulls data low for one more clock
    as the acknowledge, and pushes [data lor (parity lsl 8) lor (stop lsl 9)]. The host
    checks the parity.

    Every edge is placed by a deadline wait, so the clock is exact to one cycle (20.8 ns).
    The shortest quarter it keeps up with is 8 cycles (1.5 MHz at 48 MHz), because of the
    data check between the host releasing the clock and the first clock of a byte it
    sends. *)

open! Core
open Protocol_emulator

val data_pin : int
val clock_pin : int

(** 20.8 us at 48 MHz. *)
val standard_quarter : int

val firmware : Timed_program.t
val config : Program_config.t

(** The host at the other end. It times the clock the device makes (30 to 50 us each for
    low and high) and checks that data moves only while the clock is high, at least 5 us
    after the rise and 5 to 25 us before the fall. It checks start, odd parity and stop of
    every frame. Its script holds the clock low for 100 us at the given cycles, either to
    inhibit the device or, with a byte, to send it one. *)
module Host : sig
  module Action : sig
    type t =
      | Inhibit
      | Send of int
    [@@deriving sexp_of]
  end

  type t

  val create : clock_hz:int -> (int * Action.t) list -> t
  val clock_low : t -> bool
  val data_low : t -> bool
  val step : t -> clock:int -> data:int -> t
  val log : t -> string list
  val measured : t -> Measured.t
  val violations : t -> string list
end

val protocol : Protocol.t
