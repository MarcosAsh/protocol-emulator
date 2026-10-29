(** A remote lab job: a WaveDrom diagram and its frames, never firmware. The diagram is
    compiled at the rated clock to a table for the certified interpreter, so the only
    program the chip runs is the one the kernel certified once; a job brings data words
    and nothing else. A refusal names the limit before anything reaches the bench.

    The bench takes a certified job only when every output lane lands on a pin in
    [bench_pins] and nothing is read, and everything the host sends fits the tx fifo
    before the start, so the host's own timing cannot shape the waveform. Anything else is
    run on the model alone and labelled simulated. *)

open! Core

(** [Wavedrom.rated_hz]: a job has no clock of its own. *)
val clock_hz : int

(** OUT0, analyser A's D4. The interpreter drives OUT0 to OUT5 and holds the lanes it is
    not given low, but only OUT0 is captured and wired to nothing that minds a toggle. *)
val bench_pins : int list

(** Which of sigrok's decoders to run on the capture, from a fixed list. *)
module Decode : sig
  type t =
    | Off
    | Uart of int (** baud, 300 to 4 000 000 *)
    | Ws281x
  [@@deriving sexp_of, equal]

  (** [none], [ws281x] or [uart:BAUD]. *)
  val of_string : string -> t Or_error.t

  val to_string : t -> string

  (** [-P ... -A ...] for the capture's [channel], as [D4]; empty for [Off]. *)
  val sigrok_args : t -> channel:string -> string list
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

  (** A job file: [{"lab": 1, "diagram": ..., "frames": ..., "decode": ...}], [decode]
      optional, other keys refused. Printable ASCII only, at most [max_bytes]. *)
  val of_string : string -> t Or_error.t

  (** The job file with its frames tidied, the same text for the same job, which the
      worker names the job by the hash of. *)
  val to_string : t -> string
end

module Lane : sig
  type t =
    { name : string
    ; pin : int
    ; wiring : Bench_wiring.t option
    }
end

module Bench : sig
  type t =
    | Takes of
        { probe : Bench_wiring.t
        ; run_ms : int (** how long the host lets the engine run before it stops it *)
        }
    | Declines of string (** why, which the result page shows beside the model's trace *)
end

type t =
  | Refused of
      { job : Job.t
      ; certificate : string (** the refusal at [clock_hz], naming the step or limit *)
      }
  | Certified of
      { job : Job.t
      ; diagram : Wavedrom.t
      ; certificate : string
      ; lanes : Lane.t list (** the output lanes, out_base first *)
      ; host_words : int list
      ; cycles : int (** the model's run, as the playground's *)
      ; levels : int array (** the output lanes each cycle, the first lowest *)
      ; faults : Machine.Fault.t (** the model's at the end of its run *)
      ; bench : Bench.t
      }

(** An error is a malformed job, as frames that do not fit the diagram, not a refusal. *)
val check : Job.t -> t Or_error.t

(** STATUS's fault bits, as python/bench.py reads them. *)
val fault_bits : Machine.Fault.t -> int

(** The result folder's files from the check, name and contents: [job.json],
    [certificate.txt] and [check.json], when certified [simulated.json] (each lane's
    edges, by cycle), and when the bench takes it [firmware.json] (the config, the
    interpreter's words, the table, the tx words, [run_ms] and the faults expected, for
    python/demo_lab.py). *)
val files : t -> (string * string) list

(** [check.json] for a job that never reached [check], saying why. *)
val malformed : Error.t -> (string * string) list
