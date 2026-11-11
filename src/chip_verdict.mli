(** What the chip's own load check makes of a program: the certificate the host writes for
    it, walked by [Load_check.walk] under the assumptions the host sets. A certificate
    carries no affine rows and no slope, so the chip can refuse a program the host kernel
    accepts. *)

open! Core

type t =
  | Accepted of { certificate : int list }
  | Refused of
      { certificate : int list
      ; rejection : Load_check.Rejection.t
      }
  | No_certificate of Error.t

(** The certificate of the analyser's [rows] for [words], walked under the analyser's
    assumptions as the host sets them. [config] has the program's side-set and wrap. *)
val check
  :  ?period:int
  -> ?period_floor:int
  -> single_capture_edge:bool
  -> config:Program_config.t
  -> words:int list
  -> Analyser.Row.t list
  -> t

(** [check] on the rows and assumptions the host kernel accepted. *)
val of_timed : Timed_program.t -> t

(** One line for a reader, starting ["chip: "]. *)
val to_string : t -> string
