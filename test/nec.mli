(** NEC infrared remote control on one line, OUT0, as a receiver module's output gives it:
    low for a mark, where the light is on, high between. Every time is a whole number of
    units of 562.5 us, which the host loads. A frame is a leader of 16 units marked and 8
    not, 32 bits LSB first, the address, its inverse, the command and its inverse, each a
    unit's mark and a space of 1 unit for a zero or 3 for a one, and a final mark. A
    repeat code, sent while a key is held, is 16 units marked, 4 not and a final mark. One
    begins every 192 units, 108 ms.

    The host sends the unit once, then per key the three words of [words]. The address
    word is taken after the leader's mark and the command word after the address, and a
    word late is an underflow fault. *)

open! Core
open Protocol_emulator

val pin : int

(** 27000 and 13500 cycles at 48 MHz. *)
val standard_unit : int

val standard_half : int

(** The least unit [tx] takes: the kernel accepts the analyser's rows at every load of it
    or more. *)
val shortest_unit : int

val config : Program_config.t

(** The transmitter: a key's frame and repeat codes each 192 units from the last, and the
    next key's leader no sooner. *)
val tx : Timed_program.t

(** A receiver on [pin], at the half unit the host loads, for a line low in a mark, as
    from a receiver module. It pushes a frame's 32 bits as two words, the address with its
    inverse in the high byte, then the command's, and 0xffff for a repeat code. A mark too
    short for a leader is ignored, but nothing checks a frame's bits, so one cut short
    leaves the receiver waiting for the rest. *)
val rx_on : pin:int -> string

val rx_config : pin:int -> Program_config.t

(** [rx_on] checked by the kernel at the one load [half]: a bit's capture is armed a
    deadline wait before its fall, which a range of loads leaves unbounded. *)
val receiver : pin:int -> half:int -> Timed_program.t

(** IO3, the bench's SDA, which Pico B's GP2 can drive and analyser B sees. *)
val rx_pin : int

val rx : Timed_program.t

module Message : sig
  type t =
    | Frame of
        { address : int
        ; command : int
        }
    | Repeat
  [@@deriving sexp_of, equal]
end

(** A key's frame with [repeats] repeat codes after it. *)
val words : address:int -> command:int -> repeats:int -> int list

(** Decodes one level per cycle, low a mark: every mark and space must be within 5% of its
    nominal, and each frame's inverses must hold; from one leader or repeat to the next at
    least 95% of 108 ms. *)
val decode : clock_hz:int -> bool list -> (Message.t list * Measured.t) Or_error.t

val protocol : Protocol.t
