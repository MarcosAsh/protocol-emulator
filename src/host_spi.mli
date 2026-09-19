(** SPI slave byte layer, mode 0, MSB first, oversampled in the core clock so [sck] must
    be at most a quarter of it. [tx_byte] is latched when [cs_n] falls and at the first
    falling [sck] edge of every byte after that. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a
    ; tx_byte : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { miso : 'a
    ; rx_byte : 'a
    ; rx_valid : 'a
    ; frame_start : 'a
    ; frame_end : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
