(** The miter for a Verilog circuit that [Frame_compiler] compiles: the file as Yosys
    reads it, not as the front end does, beside the engine running the firmware. The host
    writes each word the circuit takes, and the engine's pin is the circuit's [lag] cycles
    later, provided there is no valid in the first cycles after reset and takes are at
    least [gap] apart.

    The coupling invariants are mined from many runs of [Bit_sim] and [Machine], keeping
    whatever every run agrees on at each cycle since the take. A wrong invariant fails the
    proof. *)

open! Core
open Protocol_emulator

type t =
  { host : string
  ; ports : string
  ; extra : config:Program_config.t -> Analyser.Row.t list -> string * string
  ; mutant : string (** The firmware with one bit or one cycle short. *)
  ; sby : string
  ; summary : string list
  }

(** [name] names the files: [name.sv], [name_mutant.sv], [name.sby]. *)
val create : name:string -> Verilog_in.t -> Frame_compiler.t -> t Or_error.t

(** [-verilog FILE -top MODULE], as [usage] says: prints the firmware, the certificate and
    what the miter assumes, and writes the miter beside, or prints why it is refused. *)
val main
  :  string array
  -> inductive:
       (host:string
        -> ports:string
        -> extra:(config:Program_config.t -> Analyser.Row.t list -> string * string)
        -> config:Program_config.t
        -> string
        -> string)
  -> unit

(** [-verilog-corpus [-out DIR]]: the transmitters in test/certify/third_party, run from
    the repository's root, a line each: accepted, with its miter written, or refused. *)
val main_corpus
  :  string array
  -> inductive:
       (host:string
        -> ports:string
        -> extra:(config:Program_config.t -> Analyser.Row.t list -> string * string)
        -> config:Program_config.t
        -> string
        -> string)
  -> unit
