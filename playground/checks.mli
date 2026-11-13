(** What the page shows for a paste, kept apart from js_of_ocaml so a native build can be
    compared with the page. *)

open! Core
open Protocol_emulator

module Report : sig
  type t =
    { verdict : string
    ; detail : string
    ; listing : string
    ; rows : string
    }
end

(** Same as [generate.exe assemble -listing] and [-rows] with [config] and the assumption
    flags. A refusal names whichever of the assembler, analyser or kernel refused. What
    the kernel accepts still goes through the chip's load check, whose refusal the verdict
    names too. *)
val check
  :  ?period:int
  -> ?period_floor:int
  -> single_capture_edge:bool
  -> config:Program_config.t
  -> string
  -> Report.t

(** [check]'s report on what the kernel accepted, with the chip's verdict on it. *)
val accepted : Timed_program.t -> Chip_verdict.t -> Report.t

module Pio_report : sig
  type t =
    { verdict : string
    ; report : string
    }
end

(** Runs [pio_check] on [source] with [spec]'s flags, one per line. The verdict is
    "passed" if it exits 0, "failed" on any FAIL or ERROR, and refused on a usage error. *)
val check_pio : source:string -> spec:string -> Pio_report.t

module Diagram_report : sig
  type t =
    { verdict : string
    ; detail : string
    ; steps : string
    ; words : string
    ; lanes : string list
    ; levels : int array
    }
end

val cycle_ns : clock_hz:int -> float

(** Compiles the diagram at [clock_hz], then runs it on the core model with [frames]. Each
    line of [frames] is one frame of 0s and 1s. *)
val run_diagram : source:string -> frames:string -> clock_hz:int -> Diagram_report.t

module Sim_report : sig
  type t =
    { error : string
    ; lanes : string list (** Pin names; bit [i] of a level is lane [i]. *)
    ; levels : int array (** Per cycle, the lanes' levels after that cycle's step. *)
    ; edges : int array
    (** Five per pin edge: its cycle, the pc, the window's first and last cycle (-1 if
        unbounded), and 1 if the edge lies in it. *)
    ; releases : int array (** Two per release of a deadline wait: its cycle and pc. *)
    ; waits : (int * string * string) list (** Each deadline wait's pc, text and slack. *)
    ; summary : string
    }
end

(** Runs the core model for [cycles] (at most 20000). The host writes [tx], a
    comma-separated list of [WORD[@CYCLE]], and holds [inputs], a list of
    [PIN=LEVEL[@CYCLE]]. Each pin edge the program makes is checked against the analyser's
    window for it. *)
val simulate
  :  ?period:int
  -> ?period_floor:int
  -> single_capture_edge:bool
  -> config:Program_config.t
  -> tx:string
  -> inputs:string
  -> cycles:int
  -> string
  -> Sim_report.t
