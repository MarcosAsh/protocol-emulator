(** A TDM audio transmitter as Cirrus Logic's AN301 REV1 gives it: SCLK, FSYNC and SDATA,
    eight 32-bit channel blocks a frame, FSYNC one SCLK before channel 1. The host writes
    a 16-bit sample a channel, the top of the 24-bit audio word; with none the block is 0.
    SCLK starts with the first sample and runs on without a break. *)

open! Core
open Protocol_emulator

(** The lines the firmware drives: SCLK, then FSYNC and SDATA on the pins after it. *)
val pin : int

val clk_pin : int
val sync_pin : int
val data_pin : int
val channels : int
val block_bits : int

(** The 24-bit audio word for a 16-bit sample. *)
val audio_word : sample:int -> int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

(** The bench's frame of samples, channel 1 first. *)
val samples : int list

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
