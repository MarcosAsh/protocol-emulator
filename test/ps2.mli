(** PS/2 device, the keyboard's end of the wire: open drain data on IO0 and clock on IO1.

    The host's first word is a quarter of the clock period in cycles; 20 us, 1000 cycles
    at 50 MHz, makes a 12.5 kHz clock, in the middle of the 10 to 16.7 kHz the bus allows.
    After that every word is a byte to send. The start bit, the odd parity and the stop
    bit are added here, the parity by the core's CRC unit set one bit wide. Data moves in
    the middle of clock high and the host samples it a quarter later when the clock falls,
    so setup is a quarter less the two cycles a jump takes and hold a quarter and two
    cycles. Before a frame the bus has been left alone for a whole clock period, and
    before each bit the clock is looked at: if the host holds it low the frame is dropped,
    data is let go and the interrupt is raised, for the host of the core to write the byte
    again.

    When the host holds the clock low and lets it go with data low, that is its request to
    send: the device clocks in eight data bits, parity and stop, sampling in the middle of
    clock high, pulls data low for one more clock as the acknowledge and pushes
    [data lor (parity lsl 8) lor (stop lsl 9)]. The parity is for the host of the core to
    check, as a keyboard acknowledges a byte before it asks for it again.

    Every edge is placed by a deadline wait, so the resolution is one cycle, 20 ns, and
    the clock is exact. The shortest quarter the program keeps up with is 8 cycles, a
    clock of 1.56 MHz at 50 MHz, far beyond anything PS/2 asks for; what sets it is the
    look at data between the host letting the clock go and the first clock of a byte it
    sends. *)

open! Core
open Protocol_emulator

val data_pin : int
val clock_pin : int
val cycle_ns : int

(** Cycles in 20 us at 50 MHz. *)
val standard_quarter : int

val firmware : string
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

  val create : cycle_ns:int -> (int * Action.t) list -> t
  val clock_low : t -> bool
  val data_low : t -> bool
  val step : t -> clock:int -> data:int -> t
  val log : t -> string list
  val measured : t -> Measured.t
  val violations : t -> string list
end
