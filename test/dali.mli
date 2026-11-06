(** DALI frames at 1200 bit/s, Manchester coded, MSB first: forward frames of an address
    byte and an opcode as an application controller sends them, and backward frames of a
    byte as control gear answers. The line idles high. Follows Wikipedia's "Digital
    Addressable Lighting Interface", revision of 10 July 2026. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

module Frame : sig
  type t =
    | Forward of
        { address : int
        ; opcode : int
        }
    | Backward of int
  [@@deriving sexp_of, equal]
end

(** The host's words for a frame, after the half bit loaded once. *)
val words : Frame.t -> int list

module Read : sig
  type t =
    { frame : Frame.t
    ; start : int (** The cycle of the start bit's fall. *)
    ; idle : int option (** Cycles from the end of the last bit to the next fall. *)
    }
  [@@deriving sexp_of]
end

(** A model of the far end on the line's levels: each run within 5% of a whole number of
    half bits, frames of 8 or 16 data bits, and (unless [check_idle] is false) an idle of
    at least 2.45 ms after each frame but the last. *)
val read
  :  ?check_idle:bool
  -> clock_hz:int
  -> (bool * int) list
  -> (Read.t list * Measured.t) Or_error.t

val forward_starts : Read.t list -> int list

(** Each element's distance from the one before. *)
val gaps : int list -> int list

(** QUERY ACTUAL LEVEL to short address 1, and its answer, full brightness. *)
val query : Frame.t

val answer : Frame.t

(** The trace's clock and half bit: 1200 bit/s, as sigrok's dali assumes. *)
val trace_clock_hz : int

val trace_half_bit : int
val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
