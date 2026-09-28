(** SPI slave byte layer, mode 0, MSB first, oversampled by the core clock. [sck] must be
    at most an eighth of it for the register layer to answer in time. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a (** One frame per low period. *)
    ; tx_byte : 'a
    (** Latched when [cs_n] falls and at the first falling [sck] of each later byte. *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { miso : 'a (** Low while [cs_n] is high. *)
    ; rx_byte : 'a
    ; rx_valid : 'a
    ; frame_start : 'a (** One cycle when [cs_n] falls, after synchronisation. *)
    ; frame_end : 'a (** One cycle when [cs_n] rises. *)
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
