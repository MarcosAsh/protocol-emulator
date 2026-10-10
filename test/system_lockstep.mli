(** Runs [Engines] and the [System] model side by side and compares every engine's
    architectural state and the chip's pins after every clock edge. *)

open! Core
open Protocol_emulator

(** What the kernel assumes of the world, under which a certificate is made and checked:
    the period every run-time load of [p] carries, or the least it may be, and the
    single-edge assumption. *)
module Assumptions : sig
  type t =
    { period : int option
    ; period_floor : int option
    ; single_capture_edge : bool
    }

  val none : t

  (** The certificate for [program], as the host writes it to the data memory. *)
  val certificate : t -> config:Program_config.t -> int list -> int list

  (** The period the chip's check takes as loaded: the floor where there is one. *)
  val loaded : t -> int option

  (** What the engine then watches. *)
  val premises : t -> Machine.Premises.t
end

module Setup : sig
  type t =
    { config : Program_config.t
    ; program : int list
    ; preload : int list (** Pushed into the tx fifo before the start. *)
    ; data : int list
    (** Written into the data memory from address 0 before the start, zeros after, when
        the program autopulls from it. *)
    ; assumptions : Assumptions.t
    (** Under which the engine's certificate is made and checked before the start. *)
    }
end

module Mismatch : sig
  type t =
    | Engine of
        { cycle : int
        ; engine : int
        ; expected : Lockstep.State.t
        ; actual : Lockstep.State.t
        }
    | Pins of
        { cycle : int
        ; expected : int * int
        ; actual : int * int
        } (** [pin_out] and [pin_dir] of the chip. *)
  [@@deriving sexp_of]
end

(** Every engine starts in the same cycle, by one start each or with [start_all] by the
    chip's start of every engine. [line_tables], one per engine, are written before the
    checks. [pads] and [host], one action per engine, are asked once per cycle; [react]
    sees the model after each step. Stops at the first mismatch. *)
val run
  :  ?cycles:int
  -> ?host:(int -> Lockstep.Host.t list)
  -> ?react:(System.t -> unit)
  -> ?line_tables:Line_code.t list
  -> ?start_all:bool
  -> pads:(int -> int)
  -> Setup.t list
  -> System.t * Mismatch.t option

(** [run], printing whether the two held together. *)
val lockstep
  :  ?cycles:int
  -> ?host:(int -> Lockstep.Host.t list)
  -> ?react:(System.t -> unit)
  -> ?line_tables:Line_code.t list
  -> ?start_all:bool
  -> pads:(int -> int)
  -> Setup.t list
  -> System.t
