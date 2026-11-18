(** A timing table in, firmware out. Rows are the intake's (parameter, min, max, unit),
    shape lines say which rows time which runs, and [Learn_firmware] writes the firmware:
    pulse codes, UART, Manchester or clocked serial. Every run is a whole number of units
    of whole cycles, each limit cleared by a cycle as the library's are. The unit leaving
    the most room is taken. A refusal names the row the nearest unit, or the kernel's
    least, misses. *)

open! Core
open Protocol_emulator

module Report : sig
  type t =
    { verdict : string (** ["certified"], or a refusal or ["not read"] with its reason. *)
    ; detail : string
    ; limits : string (** A line per row: its limits, the firmware's run, ok or not. *)
    ; source : string
    ; check : Checks.Report.t (** The firmware tab's own check of [source]. *)
    ; host : string (** The period the host loads, and a frame's words. *)
    ; firmware : (Program_config.t * int) option
    (** What [source] is checked under: its configuration and period. *)
    }
end

(** [model_cycles] caps the run on the engine's model, a million cycles by default. *)
val run : ?model_cycles:int -> clock_hz:int -> string -> Report.t

(** The report on one line a field, for comparing the page with a native build. *)
val to_string : Report.t -> string
