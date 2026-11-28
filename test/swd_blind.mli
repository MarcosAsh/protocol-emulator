(** SWD host (ARM IHI 0031C, ADIv5.0 to ADIv5.2, chapter 4): SWCLK on OUT2 by side-set,
    SWDIO on IO5, the bench's pins to its RP2040. The host writes the half period, then a
    word per eight clocks, two bits per clock from bit 0: SWDIO's level, then 1 to drive
    or 0 to release. It reads a word per eight, SWDIO sampled at each fall into bits 8 to

    15. A drive lands two cycles after a release, so SWDIO is let go a period plus two. *)

open! Core
open Protocol_emulator

val swclk_pin : int
val swdio_pin : int

(** 24 cycles, 1 MHz at 48 MHz. *)
val standard_half : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

module Clock : sig
  type t =
    | Drive of bool
    | Release
  [@@deriving sexp_of]
end

(** 56 clocks high. *)
val line_reset : Clock.t list

val idle : int -> Clock.t list
val high : int -> Clock.t list

(** A request, then the 37 clocks the target answers in, the turnarounds included. *)
val read : ap:bool -> addr:int -> Clock.t list

(** A request, five clocks let go, then WDATA and its parity. *)
val write : ap:bool -> addr:int -> int -> Clock.t list

(** The clocks packed eight to a word, padded with idle clocks. *)
val words : Clock.t list -> int list

module Answer : sig
  type t =
    { ack : int
    ; data : Int.Hex.t
    ; parity_ok : bool
    }
  [@@deriving sexp_of]
end

(** The answer to a read from the words the core pushed, [first] its first clock. *)
val answer : pushed:int list -> first:int -> Answer.t

(** A SW-DP, protocol 1, turnaround 1 (DLCR's reset value). It samples SWDIO on each SWCLK
    rise, moves it just after. It expects a line reset (50 high, 2 idle), then headers: a
    valid one gets OK, a protocol error nothing until the next line reset. DPIDR is the
    RP2040's, AP reads posted (p.4-95). Flags double drive, short idle. *)
module Target : sig
  type t

  val dpidr : int
  val create : unit -> t

  (** SWDIO as the target makes it: its bit, else the host's, else the pull-up's. *)
  val line : t -> int

  val step : t -> swclk:int -> host_drive:bool -> host_level:int -> t
  val log : t -> string list
  val violations : t -> string list
end

(** The scenario's clocks: a line reset, 8 idle, a DPIDR read and an AP read of CSW. *)
val clocks : Clock.t list

val dpidr_first : int
val ap_first : int
val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
