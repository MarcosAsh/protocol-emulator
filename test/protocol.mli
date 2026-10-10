(** A protocol written once, in a file of its own: its firmware, each with what its
    certificate rests on, the copies the bench demos load with the datasheet limits they
    are held to, and runs at the pins that sigrok's decoders judge and the engine and its
    model run in lockstep. [Library.protocols] lists every one, and the certificates CI
    proves, the bench's firmware, the limits and the pin traces all come from there. *)

open! Core

type t =
  { name : string
  ; certified : Certified.t list
  (** Each proved by induction in CI ([make -C formal inductive_certificate]). *)
  ; time_triggered : Certified.t list
  (** Certified as well, and never waiting on the host ([Certified]'s note). *)
  ; bench : Bench.t list (** Written to python/bench_firmware.py for the demos. *)
  ; loaded_from_hex : Bench.t list
  (** Bench firmware a demo loads from a committed .hex instead, held to its limits all
      the same. *)
  ; limits : Datasheet.t list (** Each names one of [bench] or [loaded_from_hex]. *)
  ; unlimited : (string * string) list (** Bench firmware with no limits, and why. *)
  ; swept : Swept.t list (** Firmware engine 1 stamps in the sweep demo. *)
  ; not_swept : (string * string) list
  (** The protocol's other firmware, each with what keeps it out of the sweep. *)
  ; scenarios : Pin_trace.Scenario.t list
  (** Runs at the pins, written to test/traces, replayed on the netlists and, with a
      [sigrok] field, judged by sigrok's decoders ([demo/decode.py]). *)
  ; decoded : Pin_trace.Scenario.t list
  (** Runs at the pins that sigrok's decoders judge, in test/traces/sigrok, which the RTL
      replay leaves out. *)
  }

(** The firmware of [certified] or [time_triggered] that [scenario] loads, at the
    configuration it is certified under, if it is one. *)
val firmware : t -> Pin_trace.Scenario.t -> Certified.t option

(** [scenario] at a lone engine, the program and configuration it loads, the RTL and
    [Machine] compared after every edge as [Lockstep.lockstep] does and printing the same.
    The host's tx words go in as the fifo has room and every rx word is taken as it comes,
    with no host port in between, so the cycles are not the trace's. Returns the rx words. *)
val lockstep : Pin_trace.Scenario.t -> int list
