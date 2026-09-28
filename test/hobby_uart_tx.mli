(** [Uart.Tx] from janestreet/hardcaml_hobby_boards, unmodified, with its config tied to
    eight data bits, no parity, one stop bit and a constant [clocks_per_bit]. *)

open! Core
open! Hardcaml

module type Config = sig
  val clocks_per_bit : int
end

module I : sig
  type 'a t =
    { clocking : 'a Clocking.t
    ; data_in : 'a
    ; data_in_valid : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { txd : 'a
    ; data_in_ready : 'a
    }
  [@@deriving hardcaml]
end

(** The line alone, for [Fsm_compiler], which takes one output. *)
module Pin : sig
  type 'a t = { txd : 'a } [@@deriving hardcaml]
end

module Make (_ : Config) : sig
  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
  val pin : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t Pin.t
end
