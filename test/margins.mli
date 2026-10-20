(** Sweeps of a part's datasheet timings past the sheet's limits, a firmware a point, to
    find where the part stops answering. The library's limits are never loosened: a point
    is certified only against its own limit set, with each row it breaks set at its own
    value, and every point names the rows it breaks. *)

open! Core

(** A timing's least and most over a model run, in cycles, by parameter; the swept
    timing's values also as ["swept " ^ parameter]. *)
module Measured : sig
  type t

  val least : t -> string -> int option
  val most : t -> string -> int option

  (** Each parameter's least and most, by name. *)
  val to_alist : t -> (string * (int * int)) list
end

(** The core from reset, every line pulled up and nothing else driving, each word in as
    soon as the fifo has room. Raises if it faults. *)
module Run : sig
  type t =
    { pins : int array (** Every pin, a word a cycle. *)
    ; samples : int list (** The cycles of each [in pins, 1]. *)
    ; replies : int list
    }

  val create : Bench.t -> words:int list -> cycles:int -> t

  (** Each finished level of [pin]: level, first cycle, length. *)
  val runs : t -> pin:int -> (bool * int * int) list
end

module Verdict : sig
  type t =
    { row : Datasheet.t
    ; value : int option (** The least for an [At_least] row, the most for [At_most]. *)
    ; ok : bool (** [Datasheet.verdict], so with the row's own margin. *)
    }
end

module Point : sig
  type t =
    { cycles : int (** The swept timing, as designed. *)
    ; bench : Bench.t
    ; words : int list (** The run's host words, after the load. *)
    ; run_cycles : int
    ; verdicts : Verdict.t list
    ; in_spec : bool (** Every row of the part's table holds. *)
    ; sweep_limits : Datasheet.t list
    (** The rows, each broken one at the point's own value with no margin. *)
    ; designed : int option (** The swept timing's least in the run. *)
    ; sweep_ok : bool (** Every row of [sweep_limits] holds and [designed] is [cycles]. *)
    ; measured : Measured.t
    }

  val ns : t -> float
  val broken : t -> Verdict.t list

  (** ["in spec"], or ["OUT OF SPEC: "] and every row broken with its value. *)
  val label : t -> string
end

module Sweep : sig
  type t =
    { part : string
    ; parameter : string
    ; what : string
    ; rows : Datasheet.t list
    ; nominal : int (** Cycles, the library bench's value. *)
    ; observable : string (** What the bench decides a repeat on. *)
    ; points : (Point.t, string) Either.t list
    (** A point, or why the kernel refuses its firmware. *)
    }
end

(** A pixel a frame: three host words, green, red, blue, a byte each in the top bits. *)
module Sk6812 : sig
  val words : int * int * int -> int list
  val sweeps : unit -> Sweep.t list
end

(** Host words after the quarter as [I2c.word]: an address probe, then a random read of
    [read_count] bytes from [page]. *)
module Eeprom : sig
  val page : int
  val read_count : int
  val words : device:int -> int list
  val sweeps : unit -> Sweep.t list
end

(** Host words after the unit, 1 us: reset[0], swept[1], byte[9:2], each answered as
    [One_wire]'s are. [swept] picks the point's timing for that word, else the library
    bench's. *)
module Ds18b20 : sig
  val unit : int
  val reset : swept:bool -> int
  val byte : swept:bool -> int -> int
  val sweeps : unit -> Sweep.t list
end

(** Every sweep, each point's kernel check and model run done afresh. *)
val all : unit -> Sweep.t list
