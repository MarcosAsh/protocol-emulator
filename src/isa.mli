(** The instruction set of the protocol emulator core, as an executable specification.

    Instructions are 16-bit words fetched from program memory. The machine has two 16-bit
    scratch registers [x] and [y], a 16-bit period register [p], a 24-bit deadline
    register [t], and the output and input shift registers [osr] and [isr]. A free running
    24-bit counter [now] is the clock the deadline is compared against.

    Every instruction other than [jmp] occupies [1 + delay] cycles, plus however long a
    [wait] stalls. A [jmp] always occupies [jmp_cycles] cycles whether or not it is taken,
    so the time between instruction issues never depends on data. Timing is anchored to
    the deadline: firmware sets [t], waits on it, and advances it by [p], so pin edges
    land on cycles that are computable from the program alone.

    Pins are numbered in one flat space: inputs first, then outputs, then the
    bidirectional pins, then [num_wires] wires that never leave the chip. A wire is high
    while any engine drives it high and every engine reads it, so engines signal each
    other with the instructions they use on pins. Shift operations on pins start at a base
    pin held in the program configuration, as in the RP2040 PIO. *)

open! Core
open! Hardcaml

val word_bits : int
val data_bits : int
val timer_bits : int

(** The deadline [t] carries this many bits below the cycle, which a fractional period
    fills. *)
val fraction_bits : int

val pc_bits : int

(** The data memory is the same macro as the program memory, 512 words. *)
val data_addr_bits : int

val delay_bits : int
val max_side_set : int
val num_pins : int
val num_wires : int

(** Pins and wires together: what a pin index can name. *)
val pin_space : int

val first_output_pin : int
val first_bidir_pin : int
val max_shift_count : int
val count_bits : int
val jmp_cycles : int

(** Bit fields of an instruction word. The same constants drive the software encoder and
    the hardware decoder. *)
module Field : sig
  type t =
    { lsb : int
    ; width : int
    }
  [@@deriving sexp_of]

  val mask : t -> int
  val extract : t -> int -> int
  val insert : t -> int -> int -> int
  val select : (module Comb.S with type t = 'a) -> t -> 'a -> 'a
  val op : t

  (** Delay and side-set share five bits. The program configuration says how many of the
      top bits are side-set; the rest are delay. Not present on [jmp]. *)
  val delay_side : t

  val jmp_cond : t
  val jmp_target : t
  val wait_polarity : t
  val wait_source : t
  val wait_index : t
  val shift_target : t
  val shift_count : t
  val mov_dest : t
  val mov_op : t
  val mov_source : t
  val set_dest : t
  val set_value : t
  val alu_dest : t
  val alu_op : t
  val alu_is_reg : t
  val alu_operand : t
  val sys_op : t
end

module type Cases = sig
  type t [@@deriving sexp_of, compare ~localize, enumerate, equal]
end

(** An enumeration encoded as the binary rank of its constructor. The Hardcaml enum
    interface is included so the decoder can match on the same codes. *)
module type Enum = sig
  module Cases : Cases
  include Hardcaml.Enum.S_enum with module Cases := Cases

  val width : int
  val to_int : Cases.t -> int
  val of_int : int -> Cases.t Or_error.t
end

module Opcode : sig
  module Cases : sig
    type t =
      | Jmp
      | Wait
      | In
      | Out
      | Mov
      | Set
      | Alu
      | Sys
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

(** [X_dec] and [Y_dec] jump if the register was non-zero and decrement it either way, so
    a register loaded with [n] runs a loop body [n + 1] times and ends at all ones. [Pin]
    tests the jump pin from the program configuration. [Stuff_pending] is set by the bit
    stuffing counter. The four fifo tests look without touching the fifo or stalling,
    which is the one way besides [wait] on a fifo that when the host talks can change what
    the program does. *)
module Jmp_cond : sig
  module Cases : sig
    type t =
      | Always
      | X_dec
      | Y_dec
      | X_ne_y
      | Pin
      | Not_pin
      | Osr_not_empty
      | Stuff_pending
      | Tx_not_empty
      | Tx_empty
      | Rx_not_full
      | Rx_full
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Wait_source : sig
  module Cases : sig
    type t =
      | Pin_level
      | Pin_edge
      | Deadline
      | Fifo
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

(** [Crc] reads the running CRC of the bits shifted so far. [Capture] reads the low bits
    of the timestamp latched by the last armed input capture. *)
module In_source : sig
  module Cases : sig
    type t =
      | Pins
      | X
      | Y
      | Null
      | Isr
      | Osr
      | Crc
      | Capture
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Out_dest : sig
  module Cases : sig
    type t =
      | Pins
      | X
      | Y
      | Null
      | Pindirs
      | Isr
      | P
      | T
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Mov_dest : sig
  module Cases : sig
    type t =
      | Pins
      | X
      | Y
      | Pindirs
      | Isr
      | Osr
      | P
      | T
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Mov_op : sig
  module Cases : sig
    type t =
      | Copy
      | Invert
      | Reverse
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

(** Writes to [t] are absolute: [mov t, now] anchors the deadline to the current cycle and
    [mov t, capture] anchors it to an input edge. Arithmetic on [t] goes through [alu]. *)
module Mov_source : sig
  module Cases : sig
    type t =
      | Pins
      | X
      | Y
      | Null
      | Isr
      | Osr
      | Now
      | Capture
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Set_dest : sig
  module Cases : sig
    type t =
      | Pins
      | X
      | Y
      | Pindirs
      | P
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Alu_dest : sig
  module Cases : sig
    type t =
      | X
      | Y
      | P
      | T
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Alu_op : sig
  module Cases : sig
    type t =
      | Add
      | Sub
      | Xor
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Alu_reg : sig
  module Cases : sig
    type t =
      | X
      | Y
      | P
      | Isr
      | Osr
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

(** [Push] and [Pull] never stall. On a full or empty fifo they set a fault bit instead,
    so the host can never perturb pin timing. Firmware that needs to block does so with
    [wait fifo]. [Seek] points the data memory at [x], for the autopull that reads it. *)
module Sys_op : sig
  module Cases : sig
    type t =
      | Nop
      | Halt
      | Irq
      | Push
      | Pull
      | Crc_init
      | Stuff_reset
      | Capture_arm
      | Seek
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Enum with module Cases := Cases
end

module Fifo_wait : sig
  type t =
    | Tx_not_empty
    | Rx_not_full
  [@@deriving sexp_of, compare, equal]
end

(** [Deadline] releases when [now - t], taken as a signed 24-bit number, is zero or
    positive, so a deadline that has already passed releases immediately rather than
    waiting for the counter to wrap. With [advance] the release also does [t <- t + p]. *)
module Wait : sig
  type t =
    | Pin_level of
        { pin : int
        ; level : bool
        }
    | Pin_edge of
        { pin : int
        ; rising : bool
        }
    | Deadline of { advance : bool }
    | Fifo of Fifo_wait.t
  [@@deriving sexp_of, compare, equal]
end

module Alu_operand : sig
  type t =
    | Imm of int
    | Reg of Alu_reg.Cases.t
  [@@deriving sexp_of, compare, equal]
end

(** Shift counts are 1 to 16 and are encoded directly. [Mov] into [isr] or [osr] resets
    the corresponding shift counter. *)
module Op : sig
  type t =
    | Wait of Wait.t
    | In of
        { source : In_source.Cases.t
        ; count : int
        }
    | Out of
        { dest : Out_dest.Cases.t
        ; count : int
        }
    | Mov of
        { dest : Mov_dest.Cases.t
        ; op : Mov_op.Cases.t
        ; source : Mov_source.Cases.t
        }
    | Set of
        { dest : Set_dest.Cases.t
        ; value : int
        }
    | Alu of
        { dest : Alu_dest.Cases.t
        ; op : Alu_op.Cases.t
        ; operand : Alu_operand.t
        }
    | Sys of Sys_op.Cases.t
  [@@deriving sexp_of, compare, equal]
end

(** A [jmp] carries a nine bit target and no delay or side-set. Everything else carries a
    delay and a side-set value whose widths depend on [side_set_count]. *)
type t =
  | Jmp of
      { cond : Jmp_cond.Cases.t
      ; target : int
      }
  | Op of
      { op : Op.t
      ; delay : int
      ; side_set : int
      }
[@@deriving sexp_of, compare, equal]

(** [side_set_count] is the number of side-set pins in the program configuration, from 0
    to [max_side_set]. Both functions reject anything that would not survive a round trip:
    out of range fields, reserved codes and set reserved bits. *)
val in_range : string -> int -> lo:int -> hi:int -> unit Or_error.t

val to_word : side_set_count:int -> t -> int Or_error.t
val of_word : side_set_count:int -> int -> t Or_error.t
