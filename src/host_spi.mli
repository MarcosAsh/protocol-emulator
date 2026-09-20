(** SPI slave byte layer, mode 0, MSB first, oversampled in the core clock. [sck] must be
    at most an eighth of it for the register layer to answer in time. [tx_byte] is latched
    when [cs_n] falls and at the first falling [sck] edge of every byte after. *)

open! Core
open! Hardcaml

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a (** Active low; one frame per low period. *)
    ; tx_byte : 'a
    (** The next byte to send, latched at the frame start and then at every byte boundary. *)
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { miso : 'a (** Low while [cs_n] is high. *)
    ; rx_byte : 'a
    ; rx_valid : 'a (** One cycle per byte received, with [rx_byte]. *)
    ; frame_start : 'a (** One cycle when [cs_n] falls, after synchronisation. *)
    ; frame_end : 'a (** One cycle when [cs_n] rises. *)
    }
  [@@deriving hardcaml]
end

val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
