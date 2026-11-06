(** A kernel refusal as a waveform: runs the firmware on the core in Cyclesim and trims to
    the wait the kernel refuses. *)

open! Core
open! Hardcaml
open Protocol_emulator

(** The core with the pin and the wait at [pc] brought out. [phase] is [now - t], [entry]
    is the first issue of each visit to [pc], and [late] is an entry above phase zero,
    which is the deadline the kernel's [in time] conjunct checks. *)
module O : sig
  type 'a t =
    { line : 'a
    ; pc : 'a
    ; now : 'a
    ; t : 'a
    ; phase : 'a
    ; entry : 'a
    ; late : 'a
    ; missed_deadline : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical
  :  ?instance:string
  -> pc:int
  -> pin:int
  -> Scope.t
  -> Signal.t Solo.I.t
  -> Signal.t O.t

(** The kernel's rejections of [c], on the analyser's rows. *)
val rejections : Certified.t -> Kernel.Rejection.t list

(** The first pc where the kernel, on the analyser's rows, refuses [in time]: a deadline
    wait it may enter late. *)
val late_wait : Certified.t -> int option

(** Runs [c] with the host sending [tx] and prints [cycles] cycles starting four before
    the first entry to [pc], showing [pin]. *)
val print : ?cycles:int -> Certified.t -> pc:int -> pin:int -> tx:int list -> unit
