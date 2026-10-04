(** SWD host (debugger): SWCLK on OUT2 by side-set, SWDIO on IO5 (ARM IHI 0031G, B4).

    The host's first word is the half period in cycles, which the core answers with
    SWDIO's level before it drives either line. Then a word with bit 0 clear sends the [n]
    words after it as driven bits, LSB first, for line resets and the dormant wake-up,
    [n - 1] in bits 14 to 1, or with bit 15 set lets go of the lines. A word with bit 0
    set is a request byte, which the core sends and then reads the ACK; bit 8 writes
    regardless of the ACK, as TARGETSEL takes none. A write's two data words follow it and
    the CRC unit adds the parity.

    SWCLK idles high and SWDIO is driven but where the target answers, once the first
    command comes and until the lines are let go, which leaves SWCLK low. The core changes
    SWDIO as SWCLK falls and samples the target there too, half a period after the target
    moved it on the rise. A read pushes RDATA as two words, zeros if the ACK refused it,
    then the status; a write pushes the status: ACK in bits 2 to 0, OK being 1, and a
    RDATA parity error in bit 3. A write refused by its ACK drops its data words. Eight
    idle cycles end every transfer. Overrun detection is not supported, so a WAIT or FAULT
    has no data phase. *)

open! Core
open Protocol_emulator

val swclk_pin : int
val swdio_pin : int
val cycle_ns : int

(** Cycles in half of 1 us at 50 MHz, a 1 MHz SWCLK. *)
val standard_half : int

val shortest_half : int
val firmware : Timed_program.t
val config : Program_config.t

(** As the core pushes it, OK being 1. After none of OK, WAIT or FAULT the core lets the
    line be for a data phase and turnaround too, as CMSIS-DAP does. *)
module Ack : sig
  type t =
    | Ok
    | Wait
    | Fault
    | Invalid of int
  [@@deriving sexp_of, equal]

  val of_bits : int -> t
  val to_bits : t -> int
end

module Transfer : sig
  type t =
    | Read of
        { ap : bool
        ; address : int
        }
    | Write of
        { ap : bool
        ; address : int
        ; value : Int.Hex.t
        }
    | Targetsel of Int.Hex.t
  [@@deriving sexp_of]

  (** Start, APnDP, RnW, A[2:3], even parity, stop, park, from bit 0. *)
  val request : t -> int

  val words : t -> int list
  val replies : t -> int
end

(** What the core pushed for a transfer: [data] for a read the target accepted. *)
module Reply : sig
  type t =
    { ack : Ack.t
    ; data : Int.Hex.t option
    ; parity_error : bool
    }
  [@@deriving sexp_of]

  val of_words : Transfer.t -> int list -> t
end

(** Driven bits, sixteen to a word. *)
val sequence : int list -> int list

(** Leaves SWCLK low and SWDIO let go until the next command. *)
val release : int list

(** 64 cycles high, then 16 idle. *)
val line_reset : int list

(** Eight high, the selection alert, four low and the SW-DP activation code, which leave a
    dormant SW-DP in the protocol error state, for a line reset to take out (B5.3.4). *)
val dormant_to_swd : int list

(** B5.3.4, LSB first, sixteen bits a word. *)
val selection_alert : int list

(** TARGETSEL values of the RP2040's DPs (RP2040 datasheet 2.3.4). *)
val rp2040_core0 : int

val rp2040_core1 : int

(** What OpenOCD reads from an RP2040: Arm's designer code and DPv2, MINDP. *)
val rp2040_dpidr : int

(** A SW-DP of SWD protocol version 2, from ADIv5.2 (IHI 0031G): dormant from power-on,
    selected by a line reset and kept or let go by the TARGETSEL write after it, ACK OK,
    WAIT or FAULT, even parity, one cycle of turnaround. It samples on the rise of SWCLK
    and moves SWDIO there too. Behind it is one Arm MEM-AP whose accesses keep it busy for
    [ap_latency] clocks, a WAIT to anything that needs it meanwhile, over [memory]; a word
    outside it sets STICKYERR, and a sticky flag FAULTs what B4.2.4 lets it. It times
    SWCLK high and low, and SWDIO's setup and hold around each rise where the host drives,
    each at least [minimum_ns], and refuses STKCMPCLR as a MINDP DP must. [corrupt_parity]
    sends every RDATA with the wrong parity, and [corrupt_acks] garbles its first OK ACKs. *)
module Dp : sig
  type t

  val minimum_ns : int

  val create
    :  ?ap_latency:int
    -> ?memory:(int * int) list
    -> ?corrupt_parity:bool
    -> ?corrupt_acks:int
    -> cycle_ns:int
    -> dpidr:int
    -> targetid:int
    -> unit
    -> t

  (** The level it drives, if it drives. *)
  val drive : t -> int option

  (** [host] is the level the host drives, if it does, and [line] what everyone sees. *)
  val step : t -> swclk:int -> host:int option -> line:int -> t

  val log : t -> string list
  val measured : t -> Measured.t
  val violations : t -> string list
end

(** The host's pins and a multi-drop bus of DPs, at [undriven] when nobody drives it: 1, a
    pull-up, unless said. *)
module Bus : sig
  type t

  val create : ?undriven:int -> Dp.t list -> t
  val rp2040 : ?undriven:int -> cycle_ns:int -> unit -> t
  val dps : t -> Dp.t list

  (** The line, at [swdio_pin], as the core's input. *)
  val inputs : t -> int

  val step : t -> pin_out:int -> pin_dir:int -> t

  (** Two DPs driving at once, by cycle. *)
  val contention : t -> int list
end
