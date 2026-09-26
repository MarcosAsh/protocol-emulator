(** A uart transmitter written the way [Uart.Tx] in janestreet/hardcaml_hobby_boards is,
    with eight data bits, no parity and one stop bit: a state machine that runs its
    [Start] state every cycle and the others once a bit period, on a tick from a counter
    it restarts when a byte arrives. It knows nothing of the engine; [Fsm_compiler] turns
    it into firmware. *)

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
  type 'a t = { txd : 'a } [@@deriving hardcaml]
end

module State : sig
  type t =
    | Start
    | Data
    | Stop
    | Complete
  [@@deriving sexp_of, compare ~localize, enumerate]
end

module Make (_ : Config) : sig
  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
end
