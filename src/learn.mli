(** A protocol learned from a recording of a transmitter nobody described: its timing
    table, line coding, frame shapes and checks, from edge times alone. It answers [Error]
    where the recording does not settle the question rather than guess.

    Every run on the line is taken as a whole number of one unit, found by fitting the
    runs inside frames; frames are split at idle runs far longer than any inside one. The
    codings tried, in order:

    - Manchester: runs of one or two half-bit units after a leader, a bit's first half the
      complement of its second; one bit may be twice as wide, as RC-6's trailer. A one is
      whichever way round makes the first bit 1, as RC-5 and RC-6 both start.
    - Pulse: each bit a mark and a space, two kinds of pair, the shorter a 0 (NEC and
      Samsung by the space, SIRC by the mark, PT2262 by both).
    - UART: a start bit, data LSB first, maybe parity, a stop bit at idle, read at the
      middle of each bit from the start edge, so idle between characters can be any
      length.
    - Clocked, from two or three lines: the line whose runs are all one unit is the clock,
      data is read at the clock edge it never changes near, and a line that only moves
      between bursts frames them as a chip select. *)

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
            middle, as RC-5's. *)
        }
    | Pulse of
        { zero : int * int (** Mark, then space, in units. *)
        ; one : int * int
        ; last_is_bit : bool
        (** The frame's last mark is a bit whose space is the gap, as SIRC's. *)
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

(** A shape of frame: what comes before and after its bits, and how many there are. *)
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

(** A run of bits that differs between frames of a kind and no check writes. *)
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
  { line : string (** The data line. *)
  ; unit_s : float (** Seconds: a bit, a half bit for Manchester, a half clock. *)
  ; bias_s : float
  (** Seconds an active run reads longer than whole units, and an idle one shorter, as a
      receiver module stretches or shrinks its marks. *)
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

(** [bits] with the field set to [value] and every check of its kind filled in. *)
val with_field : t -> Field.t -> bool array -> int -> bool array

(** A frame never recorded: the field with the most values seen set to the least value it
    never took, in the commonest kind that has one, checks filled in. *)
val new_message : ?value:int -> t -> (Field.t * Frame.t) Or_error.t

(** A single-line frame as runs from its first edge to its last, its checks filled in,
    with the UART's parity and stop bits. Not for clocked protocols. *)
val runs : t -> kind:int -> bool array -> Run.t list

(** Frames of a recording read with what was learned: kind, bits and when. A recording of
    one line is read as the learned line, whatever its name. *)
val decode : t -> Recording.t -> Frame.t list Or_error.t

(** A recording of [frames] sent as [runs] says, each after [gap] idle units, sampled at
    [rate_hz] with every run [jitter] of a unit long or short at random, from [seed], and
    active runs [skew] of a unit longer and idle ones shorter. *)
val synthesize
  :  ?jitter:float
  -> ?skew:float
  -> ?seed:int
  -> rate_hz:float
  -> t
  -> (int * bool array) list
  -> Recording.t
