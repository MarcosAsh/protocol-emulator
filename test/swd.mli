(** SWD host (ARM IHI 0031G, B4): SWCLK on OUT2 by side-set, SWDIO on IO5. SWDIO moves and
    is sampled as SWCLK falls, half a period from the target's rise; SWCLK idles high from
    the first command until [release]. Overrun detection is not supported, so a WAIT or
    FAULT has no data phase. *)

open! Core
open Protocol_emulator

val swclk_pin : int
val swdio_pin : int
val cycle_ns : int

(** Cycles in half of 1 us at 50 MHz, a 1 MHz SWCLK. *)
val standard_half : int

val shortest_half : int

(** Takes the half period, answering with SWDIO's level while let go, then [sequence],
    [Transfer.words] or [release]. Eight idle cycles end each transfer. *)
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

(** A read is answered with RDATA's two halves, zeros if refused, then the status; a write
    with the status. A refused write's data words are dropped. *)
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

  (** The request, bit 8 set to write whatever the ACK, then any data words. *)
  val words : t -> int list

  val replies : t -> int
end

(** The status holds the ACK in bits 2 to 0 and a RDATA parity error in bit 3. *)
module Reply : sig
  type t =
    { ack : Ack.t
    ; data : Int.Hex.t option
    ; parity_error : bool
    }
  [@@deriving sexp_of]

  val of_words : Transfer.t -> int list -> t
end

(** Driven bits, sixteen to a word LSB first, as many as 16384 words. *)
val sequence : int list -> int list

(** Leaves SWCLK low and SWDIO let go until the next command. *)
val release : int list

(** 64 cycles high, then 16 idle. *)
val line_reset : int list

(** Sixteen high, the selection alert, four low and the SW-DP activation code (B5.3.4). *)
val dormant_to_swd : int list

(** B5.3.4, LSB first, sixteen bits a word. *)
val selection_alert : int list

(** TARGETSEL values of the RP2040's DPs (RP2040 datasheet 2.3.4). *)
val rp2040_core0 : int

val rp2040_core1 : int

(** What OpenOCD reads from an RP2040: Arm's designer code and DPv2, MINDP. *)
val rp2040_dpidr : int

(** A SW-DP of SWD protocol version 2 (B4, B5.3) with one Arm MEM-AP, busy [ap_latency]
    clocks after each access. It times SWCLK and the host's setup and hold, each at least
    [minimum_ns]. The [corrupt_*] arguments garble its parity, or its first OK ACKs. *)
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
