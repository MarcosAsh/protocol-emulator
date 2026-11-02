(** PS/2 device, the keyboard's end of the wire: open drain data on IO0 and clock on IO1.

    The host's first word is a quarter of the clock period in cycles: 1000 cycles, 20.8 us
    at 48 MHz, makes a 12 kHz clock, inside the bus's 10 to 16.7 kHz. After that every
    word is a byte to send, with start bit, odd parity (the CRC unit set one bit wide) and
    stop bit added here. Data moves mid clock high and the host samples a quarter later at
    the fall, so setup is a quarter less the two cycles of a jump and hold a quarter and
    two. Before a frame the bus has been idle a whole period, and before each bit the
    clock is looked at: if the host holds it low the frame is dropped, data is let go and
    the interrupt is raised, for the host to write the byte again.

    A host request to send (clock held low, released with data low) makes the device clock
    in eight data bits, parity and stop, pull data low one more clock as the acknowledge
    and push [data lor (parity lsl 8) lor (stop lsl 9)]. The host checks the parity.

    Every edge is placed by a deadline wait, so the clock is exact to one cycle (20.8 ns).
    The shortest quarter kept up with is 8 cycles (1.5 MHz at 48 MHz), set by the look at
    data between the host letting the clock go and the first clock of a byte it sends. *)

open! Core
open Protocol_emulator

val data_pin : int
val clock_pin : int

(** 20.8 us at 48 MHz. *)
val standard_quarter : int

val firmware : Timed_program.t
val config : Program_config.t

(** The host at the other end. It times the clock the device makes: low and high of 30 to
    50 us each, data moving only while the clock is high, at least 5 us after it rose and
    5 to 25 us before it falls. It checks start, odd parity and stop of every frame. Its
    script holds the clock low for 100 us at the given cycles, to inhibit the device or,
    with a byte, to send it one. *)
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
