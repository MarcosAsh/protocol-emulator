(** A remote lab job: a WaveDrom diagram and its frames, never firmware. The diagram is
    compiled at the rated clock to a table for the certified interpreter. The only program
    the chip runs is the one the kernel certified once, and a job brings data words and
    nothing else. A refusal names the limit before anything reaches the bench.

    The bench takes a certified job only when every pin it drives is one [Pads] lets a job
    drive, an analyser sees at least one of them, nothing is read, and everything the host
    sends fits the tx fifo before the start, so the host's own timing can't shape the
    waveform. Any other job runs on the model alone and is labelled simulated. *)

open! Core

(** [Wavedrom.rated_hz]: a job has no clock of its own. *)
val clock_hz : int

(** Which of sigrok's decoders to run on a capture, from a fixed list, with each option's
    value checked against what the decoder takes. Nothing from the job reaches sigrok-cli
    unless it is one of those names or values, or a channel the check names itself. *)
module Decode : sig
  module Value_rule : sig
    type t =
      | Range of int * int
      | One_of of string list
  end

  module Decoder : sig
    type t =
      { id : string
      ; channels : string list
      ; required : string list
      ; options : (string * Value_rule.t) list
      ; rows : string list -> string (** the [-A] rows, given the channels bound *)
      }
  end

  type t =
    | Off
    | On of
        { decoder : Decoder.t
        ; channels : (string * int) list (** each channel's pin *)
        ; options : (string * string) list
        }
  [@@deriving sexp_of]

  val max_length : int

  (** [none], or [DECODER:KEY=VALUE:...] where a key is a channel (its value a pin, as
      [OUT0]) or an option. A decoder of one line may leave its channel out. [ws281x] and
      [uart:BAUD] are short for [rgb_led_ws281x] and [uart:baudrate=BAUD]. *)
  val of_string : string -> t Or_error.t

  val to_string : t -> string

  (** The decoders a job may name. *)
  val ids : string list
end

module Job : sig
  type t =
    { diagram : string (** WaveJSON, as typed *)
    ; frames : string (** a line of 0s and 1s a frame, as the playground takes them *)
    ; decode : Decode.t
    }
  [@@deriving sexp_of]

  val max_bytes : int
  val max_frames : int

  (** A job file: [{lab: 1, diagram: ..., frames: ..., decode: ...}], where [decode] is
      optional and other keys are refused. Printable ASCII only, at most [max_bytes]. *)
  val of_string : string -> t Or_error.t

  (** The job file with its frames tidied, giving the same text for the same job. The
      worker names the job by the hash of that text. *)
  val to_string : t -> string
end

(** The bench's output and bidirectional pads, by what else the carrier wires to them. *)
module Pads : sig
  (** [Ok net] if a job may drive [pin]: nothing else on the net can drive it, or only
      through a series resistor, and nothing on it keeps state. [Error why] otherwise. *)
  val safety : int -> (string, string) Result.t

  val all : int list
  val drivable : int list
end

module Lane : sig
  type t =
    { name : string
    ; pin : int
    ; wiring : Bench_wiring.t option
    }
end

(** A lane an analyser sees. *)
module Probe : sig
  type t =
    { lane : string
    ; wiring : Bench_wiring.t
    }
end

module Bench : sig
  type t =
    | Takes of
        { probes : Probe.t list (** one pass a bench run for each analyser they use *)
        ; run_ms : int (** how long the host lets the engine run before it stops it *)
        ; decode : (Bench_wiring.Analyser.t * string list) option
        (** the analyser whose capture sigrok-cli reads, and its [-P] and [-A] *)
        }
    | Declines of string (** why, which the result page shows beside the model's trace *)
end

(** What the host loads: the program, the certificate the chip's load check accepted and
    the assumptions it was walked under, and the data memory. *)
module Image : sig
  type t =
    { config : Program_config.t
    ; words : int list
    ; certificate : int list
    ; loaded : int option
    ; floor : bool
    ; single_edge : bool
    ; data : int list
    }
end

type t =
  | Refused of
      { job : Job.t
      ; certificate : string (** the refusal at [clock_hz], naming the step or limit *)
      }
  | Certified of
      { job : Job.t
      ; certificate : string
      ; lanes : Lane.t list (** the output lanes, out_base first *)
      ; input : (string * int array) option (** a peer's line each cycle, by its lane *)
      ; host_words : int list
      ; cycles : int (** the model's run, as the playground's *)
      ; levels : int array (** the output lanes each cycle, the first lowest *)
      ; faults : Machine.Fault.t (** the model's at the end of its run *)
      ; image : Image.t option (** none if the chip's load check refuses *)
      ; bench : Bench.t
      }

(** An error means a malformed job (for example frames that don't fit the diagram, or a
    decode of a pin the bench doesn't capture), not a refusal. *)
val check : Job.t -> t Or_error.t

(** The result folder's files from the check, as name and contents: [job.json],
    [certificate.txt] and [check.json]. A certified job also gets [simulated.json] (each
    lane's edges, by cycle). If the bench takes it, there is also [firmware.json] (the
    config, the interpreter's words, the certificate the chip checks them against and its
    assumptions, the table, the tx words, [run_ms], the expected faults and the probes,
    for python/demo_lab.py and test/test_lab_rtl.py). *)
val files : t -> (string * string) list

(** [check.json] for a job that never reached [check], saying why. *)
val malformed : Error.t -> (string * string) list
