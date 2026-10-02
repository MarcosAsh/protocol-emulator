(** The core's instruction set: 16-bit words; registers [x], [y], [p] (16 bits), deadline
    [t] and free-running [now] (24 bits), shift registers [osr] and [isr]. An instruction
    takes [1 + delay] cycles plus any [wait] stall; a [jmp] always takes [jmp_cycles],
    taken or not, so issue timing never depends on data. Firmware sets [t], waits on it
    and advances it by [p], so pin edges are computable from the program alone. Pins are
    one flat space: inputs, outputs, bidirectional, then [num_wires] wires ORed across
    engines. Pin shifts start at a configured base pin, as in the RP2040 PIO. *)

open! Core
open! Hardcaml

val word_bits : int
val data_bits : int
val timer_bits : int

(** Bits of [t] below the cycle, filled by a fractional period. *)
val fraction_bits : int

val pc_bits : int

(** Same 512-word macro as program memory. *)
val data_addr_bits : int

(** Up to four engines time-share data memory: after a data autopull, [Seek] or the start
    pulse (two cycles before the first issue), a data autopull sooner than this many
    cycles is refused and sets [underflow]. *)
val data_settle : int

val delay_bits : int
val max_side_set : int
val num_pins : int
val num_wires : int

(** Pins plus wires. *)
val pin_space : int

val first_output_pin : int
val first_bidir_pin : int
val max_shift_count : int
val count_bits : int
val jmp_cycles : int

(** Instruction word fields, shared by the encoder and the hardware decoder. *)
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

  (** Five bits: the configured number of top bits are side-set, the rest delay. Absent on
      [jmp]. *)
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

(** Encoded as the constructor's rank. *)
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

(** [X_dec]/[Y_dec] jump if non-zero and decrement either way: [n] runs a loop [n + 1]
    times and ends at all ones. [Pin] tests the configured jump pin. The fifo tests
    neither stall nor touch the fifo; with [wait fifo] they are the only way host timing
    can change what a program does. *)
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

(** [Capture] reads the low bits of the timestamp latched by the last armed capture. *)
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

(** Writes to [t] are absolute ([mov t, now], [mov t, capture]); arithmetic on [t] goes
    through [alu]. *)
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

(** [Push] and [Pull] never stall, so the host cannot perturb pin timing; on a full or
    empty fifo they set a fault bit. [Seek] points data autopull at [x]. *)
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

(** [Deadline] releases when [now - t], as a signed 24-bit number, is >= 0, so a passed
    deadline releases at once instead of after wrap-around. [advance] also does
    [t <- t + p]. *)
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

(** Shift counts are 1 to 16. [Mov] into [isr] or [osr] resets its shift counter. *)
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

(** A [jmp] has no delay or side-set; elsewhere their widths follow [side_set_count]. *)
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

(** [side_set_count] is 0 to [max_side_set]. The codecs reject whatever would not
    round-trip: out-of-range fields, reserved codes, set reserved bits. *)
val in_range : string -> int -> lo:int -> hi:int -> unit Or_error.t

val to_word : side_set_count:int -> t -> int Or_error.t
val of_word : side_set_count:int -> int -> t Or_error.t
