(** Cycle-accurate model of the core: the specification the simulator, the timing analyser
    and the hardware tests compare against.

    An instruction issues when not halted or stalled, then stalls for its delay (or
    [Isa.jmp_cycles - 1] after a [jmp]). A false [wait] reissues next cycle, re-applying
    its side-set. The wrap from [wrap_top] to [wrap_bottom], unless a jump is taken, takes
    no cycles. [now] counts every cycle, halted or not, and a begun delay runs out even if
    halted. State written in a cycle is visible from the next, so a read of capture misses
    a same-cycle edge. Autopull precedes an [out] at threshold, never follows it, so a
    cycle touches each fifo once.

    Pins 0-4 are inputs, 5-11 outputs, 12-19 bidirectional (reading the driven value when
    the direction bit is set), 20-27 wires (read ORed with what [inputs] says others
    drive). Writes to inputs are dropped.

    Nothing touching a fifo stalls: a push into a full fifo drops and sets [overflow], a
    pull from an empty one leaves [osr] and sets [underflow]. A late deadline release sets
    [missed_deadline]; an undecodable word halts and sets [decode]. CRC and stuff counter
    see only single-bit [in]/[out]; [jmp stuff_pending] compares the run with the
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
  ; data : int array (** Loaded by the host while the core is halted. *)
  ; data_ptr : int (** The word the next data autopull takes. *)
  ; data_age : int
  (** Cycles since [data_ptr] moved, saturating at [Isa.data_settle]; a data pull sooner
      is refused like an empty-fifo pull. *)
  ; pc : int
  ; x : int
  ; y : int
  ; p : int
  ; t : int
  ; t_fraction : int (** What a fractional period has built up below [t]. *)
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
  ; flip : int option
  (** Manchester [out] bit whose second half starts at the next issue. *)
  }
[@@deriving sexp_of, compare, equal]

(** [program] is encoded words from address 0; the rest reads zero, [jmp always 0]. Data
    memory starts at zero here but is undefined in silicon until the host writes it. *)
val create : config:Program_config.t -> program:int list -> t Or_error.t

(** Fills data memory from address 0, before a run or while halted; the rest is zero. *)
val load_data : t -> int list -> t Or_error.t

(** [inputs]: external pin levels, and for wires what other cores drive. Bits of pins the
    core drives are ignored. *)
val step : t -> inputs:int -> t

(** Host side of the fifos and the interrupt flag. *)
val write_tx : t -> int -> t Or_error.t

val read_rx : t -> (int * t) option
val clear_irq : t -> t

(** Halts the core; this cycle's issue still takes effect and pins hold. *)
val stop : t -> t

(** Empties both fifos; ignored unless halted. *)
val flush : t -> t
