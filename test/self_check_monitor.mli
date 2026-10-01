(** [Self_check.checker] on pin 0 against a reference monitor that states its contract, on
    waveforms made by pulsing, moving and dropping the edges of frames. *)

open! Core

(** The cycle the checker first looks for the line high in; the first frame starts at the
    first fall after it sees it. *)
val watch_from : int

module Wave : sig
  (** The level the checker samples in each cycle. *)
  type t = Bytes.t
end

module Reference : sig
  module Kind : sig
    type t =
      | By of int (** The checker must raise its irq by this cycle. *)
      | Pending (** In the four cycles before a least no frame follows: never seen. *)
      | Alias (** Blind, as [Self_check.checker] states. *)
    [@@deriving sexp_of, compare, equal]
  end

  type t =
    { at : int
    ; kind : Kind.t
    }
  [@@deriving sexp_of]

  (** Every break of the contract for frames with [edges], as [Self_check.rows] takes
      them, in order, up to the first the checker must see. *)
  val violations : edges:int array -> Wave.t -> t list
end

module Run : sig
  type t =
    { irq_at : int option
    ; missed_deadline : bool
    }
  [@@deriving sexp_of]
end

val run_model : base:int -> edges:int array -> Wave.t -> Run.t

(** The rtl's irq at the end, and whether it held in lockstep with the model. *)
val run_rtl : base:int -> edges:int array -> Wave.t -> bool * bool

module Verdict : sig
  type t =
    | Quiet
    | Caught
    | Unseen of Reference.Kind.t (** a break the contract lets go *)
    | Missed of int (** a break the contract says is seen, not seen by this cycle *)
    | False_alarm of int
    | Missed_deadline
  [@@deriving sexp_of, compare]
end

val judge : reference:Reference.t list -> Run.t -> Verdict.t

module Case : sig
  type mutation =
    | Pulse of
        { at : int
        ; width : int
        }
    | Shift of
        { at : int
        ; by : int
        } (** the move at [at] comes [by] cycles later *)
    | Missing of { at : int } (** the move at [at] never comes *)
  [@@deriving sexp_of]

  (** Frame [j] starts at [starts.(j)] and holds [levels.(j).(k)] up to [edges.(k)]; the
      line is high otherwise. *)
  type t =
    { edges : int array
    ; base : int
    ; starts : int array
    ; levels : int array array
    ; mutations : mutation list
    ; cycles : int
    }
  [@@deriving sexp_of]

  val wave : t -> Wave.t

  (** Frames with the same levels from [lead_in], each after the last's least by the next
      of [idle]. *)
  val frames
    :  ?base:int
    -> ?lead_in:int
    -> ?idle:int list
    -> ?mutations:mutation list
    -> int array
    -> int array
    -> t
end

(** The model's verdict on a case, with the reference's breaks and the run. *)
val check : Case.t -> Verdict.t * Reference.t list * Run.t

module Gen : sig
  (** A random case and what was done to it; [long] allows frames near [2^14] and idle
      gaps near [2^16]. *)
  val mutated : Random.State.t -> long:bool -> string list * Case.t
end
