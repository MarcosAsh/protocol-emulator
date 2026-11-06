(** Compiles a WaveDrom diagram to a [Tables] table, so it runs under the interpreter's
    certificate as it stands. Each period (or half period of a clock) is a step of
    [table.cycles] cycles. With data, the first period is the idle shown while we wait for
    the host's word. Without data, the diagram loops. Lanes: 0 1 h l are levels, p n are
    clocks, [=] is a host bit, [.] and [|] continue. An [input: true] lane's [=] cells are
    bits read by Shift. A frame starts on an edge when an input lane leaves its first
    level before its first cell and there are no output lanes. That compiles to an Await,
    a read at each cell's middle, and a Push. *)

open! Core

module Level : sig
  type t =
    | Low
    | High
    | Bit (** the host bit *)
  [@@deriving sexp_of, equal]
end

module Step : sig
  type t =
    { name : string (** where it was drawn *)
    ; outputs : Level.t list (** one an output lane *)
    ; kind : Tables.Kind.t
    ; cycles : int
    }
  [@@deriving sexp_of]
end

(** An [edge] whose label has a limit, such as [>= 250ns], [<= 1.2us], [= 26 cycles] or
    [250ns..550ns]. The limit is checked on the steps' [cycles], exactly, at any clock;
    [ns] means the clock compiled for. *)
module Limit : sig
  type t =
    { edge : string
    ; cycles : int
    ; ns : float
    ; least_ns : float option
    ; most_ns : float option
    }
  [@@deriving sexp_of]
end

module State : Tables.State with type t = int

(** The chip's rated clock, info.yaml's, 48 MHz. *)
val rated_hz : int

(** As ["48 MHz"]. *)
val clock_name : int -> string

type t =
  { outputs : string list (** lane names, out_base first *)
  ; input : string option
  ; steps : Step.t list (** one a state, the first first *)
  ; table : State.t Tables.t
  ; bits : int (** host bits a frame, or a pass with [while_host] *)
  ; words : int list (** bits in each host word of a frame *)
  ; while_host : bool
  ; starts_on_edge : bool (** each frame starts on the input's edge, with no host word *)
  ; read : int (** bits read a frame *)
  ; limits : Limit.t list
  ; clock_hz : int (** The limits' clock. *)
  ; diagram : Wavejson.t (** as compiled *)
  }

(** The table, or why the diagram is outside the class. Limits are checked at [clock_hz]
    (default [rated_hz]). The steps are in cycles and don't depend on the clock. *)
val compile : ?clock_hz:int -> Wavejson.t -> t Or_error.t

val of_string : ?clock_hz:int -> string -> t Or_error.t

(** One frame's host words: [bits] bits, first sent first. With [while_host] it is any
    number of passes of [bits]; each pass is a word whose first bit says another pass
    follows, then a word of 0. *)
val host_words : t -> bool list -> int list Or_error.t

(** The bits a pushed word holds, first read first. *)
val read_bits : t -> int -> bool list

(** The input lane's level each cycle as a peer sends [frames] of [read] bits, each drawn
    as the diagram draws its frame after the idle period, then one more idle at the end.
    Only for a frame that an input's edge starts. *)
val line : t -> bool list list -> bool array Or_error.t

(** The certified interpreter's config and program, and the table's data words. *)
val image : t -> (Program_config.t * int list * int list) Or_error.t

(** Runs the model of the core for [cycles] cycles from [image], with the host writing
    [host_words] as the fifo has room and taking every pushed word. Returns the output
    lanes' levels each cycle (out_base lowest), the words taken, and the faults. *)
val simulate
  :  t
  -> host_words:int list
  -> inputs:(int -> int)
  -> cycles:int
  -> (int array * int list * Machine.Fault.t) Or_error.t
