(** Cycle-accurate model of the core. The simulator, the timing analyser and the hardware
    tests all compare against it.

    An instruction issues when the core is neither halted nor stalled, then stalls for its
    delay ([Isa.jmp_cycles - 1] after a [jmp]). A false [wait] reissues next cycle and
    re-applies its side-set. The wrap from [wrap_top] to [wrap_bottom] takes no cycles
    unless a jump is taken. [now] counts every cycle, halted or not, and a delay that has
    begun runs out even if the core halts. State written in a cycle is visible from the
    next, so a read of capture misses an edge in the same cycle. Autopull comes before an
    [out] at threshold and never after it, so a cycle touches each fifo once.

    Pins 0-4 are inputs, 5-11 outputs, 12-19 bidirectional (they read the driven value
    when the direction bit is set), and 20-27 wires (read ORed with whatever [inputs] says
    other cores drive). Writes to inputs are dropped.

    Nothing that touches a fifo stalls. A push into a full fifo drops and sets [overflow];
    a pull from an empty one leaves [osr] alone and sets [underflow]. A late deadline
    release sets [missed_deadline], and an undecodable word halts and sets [decode]. The
    CRC and stuff counter only see single-bit [in]/[out]; [jmp stuff_pending] compares the
    run with the threshold. After [crc_send], such a bit shifts the CRC out instead, and
    an [out] sends the CRC's bit (complemented if configured) in place of the osr's. *)

open! Core

val fifo_depth : int

module Fault : sig
  type t =
    { underflow : bool
    ; overflow : bool
    ; missed_deadline : bool
    ; decode : bool
    ; assumption : bool (** A premise of [Premises] failed. *)
    }
  [@@deriving sexp_of, compare, equal]

  val none : t
end

(** What the chip's check assumed about a certificate, as in [Load_checker.Setup]: the
    period that every write to [p] other than a set carries (or with [floor] the least),
    and the single-edge assumption. The period is checked where the kernel uses it, at
    [wait t+] and [add t, p]. *)
module Premises : sig
  type t =
    { period : int option
    ; floor : bool
    ; single_edge : bool
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
  ; crc_sending : bool (** From [crc_send] to [crc_init]. *)
  ; stuff_run : int
  ; flip : int option
  (** Manchester [out] bit whose second half starts at the next issue. *)
  ; line_table : Line_code.t
  ; line_tx : int
  ; line_rx : int
  ; line_flag : bool
  ; line_last : int (** The pin the last line-coded [in] read. *)
  ; line_held : int (** [Line_stuff]'s bits taken, latest lowest. *)
  ; line_count : int (** How many of them are owed. *)
  ; line_draining : bool
  ; premises : Premises.t
  ; p_loaded : bool (** [p] was last written other than by a set. *)
  ; holding : bool (** From [capture_arm] until a wait for the captured edge releases. *)
  ; seen : bool (** The capture pin has been at the captured level since the arm. *)
  ; route_full : bool (** The next engine's tx fifo was full, as this step saw it. *)
  ; routed : int option (** What this step pushed to the next engine. *)
  }
[@@deriving sexp_of, compare, equal]

(** [program] is encoded words from address 0; the rest reads zero ([jmp always 0]). Data
    memory starts at zero here but is undefined in silicon until the host writes it. *)
val create : config:Program_config.t -> program:int list -> t Or_error.t

(** Fills data memory from address 0, before a run or while halted. The rest is zero. *)
val load_data : t -> int list -> t Or_error.t

(** Loads the [Line_code] table while halted. The receive side starts at its [rx_start]. *)
val load_line_table : t -> Line_code.t -> t

(** Watches the premises from the next step on; [Fault.assumption] fires on the step one
    fails. *)
val assume : t -> Premises.t -> t

(** [inputs] are the external pin levels (for wires, what other cores drive). Bits of pins
    the core drives are ignored. [route_full], with [route], says the next engine's tx
    fifo is full. *)
val step : ?route_full:bool -> t -> inputs:int -> t

(** The level on every pin: what the core drives, else [inputs]; wires are ORed. *)
val pins : t -> inputs:int -> int

(** The pins at [inputs] one cycle earlier, which the chip samples while halted too, so an
    edge wait at the first issue compares against them. [create] starts them low. *)
val pins_before : t -> inputs:int -> t

(** Host side of the fifos and the interrupt flag. *)
val write_tx : t -> int -> t Or_error.t

val read_rx : t -> (int * t) option
val clear_irq : t -> t

(** Halts the core. This cycle's issue still takes effect and the pins hold. *)
val stop : t -> t

(** A halted core as the chip leaves it a cycle after a start pulse: at address 0 with
    [now] at 0. Registers, fifos, pins, capture and faults carry over. Ignored unless
    halted. *)
val start : t -> t

(** Empties both fifos; ignored unless halted. *)
val flush : t -> t
