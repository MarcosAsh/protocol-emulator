(** A cycle accurate model of the core, used as the executable specification that the
    simulator, the static timing analyser and the hardware tests all compare against.

    [step] advances one clock cycle. An instruction issues when the core is not halted and
    not stalled; it then stalls for its delay, or for [Isa.jmp_cycles - 1] cycles after a
    [jmp]. A [wait] whose condition is false issues again on the next cycle, so a stalled
    [wait] re-applies its side-set every cycle. [now] counts every cycle, including while
    halted. State written in a cycle is visible from the next cycle, so an instruction
    reads the capture register as it was before any edge in the same cycle. Autopull
    happens before an [out] whose shift count has reached the threshold and never after
    it, so a cycle touches each fifo at most once.

    Pins 0 to 4 are input only, 5 to 11 are output only and 12 to 19 are bidirectional. A
    read of an output pin returns the driven value; a read of a bidirectional pin returns
    the driven value when its direction bit is set and the external input otherwise.
    Writes to input-only pins are dropped.

    The fifos are [fifo_depth] deep. Nothing that touches a fifo ever stalls: a push into
    a full fifo drops the data and sets [overflow], a pull from an empty fifo leaves [osr]
    alone and sets [underflow]. A deadline wait that releases late sets [missed_deadline].
    A word that does not decode halts the core and sets [decode].

    The CRC and the stuff counter see the bit of every single-bit [in] or [out], whatever
    it moves between; wider shifts leave them alone. [in crc] reads the CRC, [crc_init]
    reloads it, [stuff_reset] clears the run and [jmp stuff_pending] tests it against the
    threshold. *)

open! Core

val fifo_depth : int

module Fault : sig
  type t =
    { underflow : bool
    ; overflow : bool
    ; missed_deadline : bool
    ; decode : bool
    }
  [@@deriving sexp_of, compare, equal]

  val none : t
end

type t = private
  { config : Program_config.t
  ; program : int array
  ; pc : int
  ; x : int
  ; y : int
  ; p : int
  ; t : int
  ; osr : int
  ; osr_count : int
  ; isr : int
  ; isr_count : int
  ; now : int
  ; pin_out : int
  ; pin_dir : int
  ; pins_sampled : int
  ; tx_fifo : int list
  ; rx_fifo : int list
  ; stall : int
  ; halted : bool
  ; irq : bool
  ; fault : Fault.t
  ; capture : int
  ; capture_armed : bool
  ; crc : int
  ; stuff_run : int
  }
[@@deriving sexp_of, compare, equal]

(** [program] is a list of encoded words starting at address 0. The rest of program memory
    reads as zero, which decodes as [jmp always 0]. *)
val create : config:Program_config.t -> program:int list -> t Or_error.t

(** [inputs] carries the external level of every pin in the flat pin space. Bits for
    output-only pins and for bidirectional pins driven by the core are ignored. *)
val step : t -> inputs:int -> t

(** Host side of the fifos and the interrupt flag. *)
val write_tx : t -> int -> t Or_error.t

val read_rx : t -> (int * t) option
val clear_irq : t -> t
