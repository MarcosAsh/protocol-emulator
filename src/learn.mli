(** Learns a protocol from a recording of a transmitter nobody described: timing table,
    line coding, frame shapes and checks, from edge times alone. It returns [Error] when
    the recording doesn't settle the question. Every run is a whole number of one unit,
    found by fitting runs inside frames, and frames split at idle runs far longer than any
    inside one. Codings tried in order: Manchester, pulse, UART, clocked. *)

open! Core

module Parity : sig
  type t =
    | Even
    | Odd
  [@@deriving sexp_of, equal]
end

module Coding : sig
  type t =
    | Manchester of
        { one_starts_active : bool (** A one's first half is the active level. *)
        ; wide : int option (** A bit twice as long, by its index in the frame. *)
        ; hidden_half : bool
        (** The first bit's first half is at the idle level, so the frame shows from its
            middle (RC-5 does this). *)
        }
    | Pulse of
        { zero : int * int (** Mark, then space, in units. *)
        ; one : int * int
        ; last_is_bit : bool
        (** The frame's last mark is a bit whose space is the gap (SIRC does this). *)
        }
    | Uart of
        { data_bits : int
        ; parity : Parity.t option
        ; stop_bits : int
        }
    | Clocked of
        { clock : string
        ; select : string option
        ; sample_rising : bool
        ; clock_idle : bool
        }
  [@@deriving sexp_of, equal]
end

module Run : sig
  type t =
    { active : bool
    ; units : int
    }
  [@@deriving sexp_of, compare, equal]
end

(** A frame shape: what comes before and after its bits, and how many bits there are. *)
module Kind : sig
  type t =
    { leader : Run.t list
    ; bits : int
    ; trailer : Run.t list
    }
  [@@deriving sexp_of, compare, equal]
end

module Frame : sig
  type t =
    { kind : int
    ; bits : bool array
    ; at : float (** Seconds from the recording's start. *)
    }
  [@@deriving sexp_of]
end

(** A run of bits that differs between frames of a kind and that no check writes. *)
module Field : sig
  type t =
    { kind : int
    ; first : int
    ; width : int
    ; seen : int list (** Values in the recording, read as [lsb_first] says. *)
    }
  [@@deriving sexp_of]
end

type t =
  { line : string
  ; unit_s : float (** Seconds: a bit, a half bit for Manchester, a half clock. *)
  ; bias_s : float
  (** Seconds an active run reads longer than whole units, and an idle one shorter,
      because a receiver module stretches or shrinks its marks. *)
  ; idle : bool (** The data line's level between frames. *)
  ; coding : Coding.t
  ; lsb_first : bool (** How bits are read as values; the line cannot say. *)
  ; kinds : Kind.t list
  ; gap : int (** The fewest units seen between two frames. *)
  ; frames : Frame.t list
  ; outliers : int (** Frames of a shape seen only once among many. *)
  ; rules : (int * (Learn_check.Rule.t * Learn_check.Evidence.t) list) list
  (** By kind. *)
  ; fields : Field.t list
  }
[@@deriving sexp_of]

(** From [lines], every line with edges by default. *)
val learn : ?lines:string list -> Recording.t -> t Or_error.t

(** The timing table, coding, kinds, checks and fields, then each frame's bits. *)
val to_string : t -> string

(** Bit values of a field, read as [lsb_first]. *)
val field_value : t -> Field.t -> bool array -> int

(** [bits] with every check of the kind filled in. *)
val with_checks : t -> kind:int -> bool array -> bool array

(** A frame never recorded: the field with the most values seen, set to the least value it
    never took, in the commonest kind that has one, with checks filled in. *)
val new_message : ?value:int -> t -> (Field.t * Frame.t) Or_error.t

(** A single-line frame as runs from its first edge to its last, with checks filled in and
    the UART's parity and stop bits. Not for clocked protocols. *)
val runs : t -> kind:int -> bool array -> Run.t list

(** The frames of a recording, read with what was learned: kind, bits and time. A
    recording of one line is read as the learned line, whatever its name. *)
val decode : t -> Recording.t -> Frame.t list Or_error.t

(** A recording of [frames] sent as [runs] says, each after [gap] idle units, sampled at
    [rate_hz]. Every run is randomly [jitter] of a unit too long or short (from [seed]),
    and active runs are [skew] of a unit longer and idle ones shorter. *)
val synthesize
  :  ?jitter:float
  -> ?skew:float
  -> ?seed:int
  -> rate_hz:float
  -> t
  -> (int * bool array) list
  -> Recording.t
