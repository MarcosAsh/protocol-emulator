(** What the page shows for a paste, apart from js_of_ocaml, so a native build can be
    compared with the page's. *)

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

(** [generate.exe assemble -listing] and [-rows], under [config] and its assumption flags,
    naming whichever of the assembler, analyser and kernel refuses. *)
val check
  :  ?period:int
  -> ?period_floor:int
  -> single_capture_edge:bool
  -> config:Program_config.t
  -> string
  -> Report.t

module Pio_report : sig
  type t =
    { verdict : string
    ; report : string
    }
end

(** [pio_check] on [source] with [spec]'s flags, one a line: "passed" where it exits 0,
    "failed" on any FAIL or ERROR, refused where it gives a usage error. *)
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

(** The diagram compiled at [clock_hz], then the model of the core running it on [frames],
    a line a frame of 0s and 1s. *)
val run_diagram : source:string -> frames:string -> clock_hz:int -> Diagram_report.t

module Sim_report : sig
  type t =
    { error : string
    ; lanes : string list (** Pin names; bit [i] of a level is lane [i]. *)
    ; levels : int array (** Per cycle, the lanes' levels after that cycle's step. *)
    ; edges : int array
    (** Five a pin edge: its cycle, the pc, the window's first and last cycle (-1 if
        unbounded), and 1 if the edge lies in it. *)
    ; releases : int array (** Two a release of a deadline wait: its cycle and pc. *)
    ; waits : (int * string * string) list (** Each deadline wait's pc, text and slack. *)
    ; summary : string
    }
end

(** The model of the core run for [cycles] (at most 20000), the host writing [tx], a
    comma-separated list of [WORD[@CYCLE]], and holding [inputs], of [PIN=LEVEL[@CYCLE]];
    each pin edge the program makes is checked against the analyser's window for it. *)
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
