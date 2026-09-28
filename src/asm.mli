(** Assembler for the core, in the style of the RP2040 PIO assembler.

    {v
    .side_set 1                ; top bit of every delay field is a side-set pin
    idle:
        wait tx                ; block until the host has written a word
        pull
        set x, 7
        mov t, now
        set pins, 0 side 1 [3] ; modifiers: side N, [delay]
    bit:
        wait t+                ; wait for the deadline, then t <- t + p
        out pins, 1
        jmp x--, bit
        jmp idle
    v}

    [.wrap_target] and [.wrap] mark a zero-cycle loop; without [.wrap] it ends with the
    program. With side-set on, every non-[jmp] instruction must carry [side].

    Operands are the lower-case [Isa] constructor names. [mov] sources take [!] (invert)
    or [::] (reverse). Jump conditions: [x--], [y--], [x!=y], [pin], [!pin], [!osre],
    [stuff], [tx] (host wrote a word), [!tx], [rx] (room to push), [!rx]. Waits:
    [wait 0|1 pin N], [wait rise|fall pin N], [wait t], [wait t+], [wait tx], [wait rx].
    ALU: [add], [sub], [xor] with a register or immediate. [;] comments, [label:], numbers
    decimal, [0x] or [0b]. *)

open! Core

module Program : sig
  type t =
    { side_set_count : int
    ; wrap_bottom : int
    ; wrap_top : int
    ; instructions : Isa.t list
    }
  [@@deriving sexp_of, compare, equal]

  val words : t -> int list Or_error.t

  (** Fills in the side-set count and wrap addresses. *)
  val configure : t -> Program_config.t -> Program_config.t
end

(** Errors carry the line number and the offending line. *)
val assemble : string -> Program.t Or_error.t

(** Inverse of [assemble] for one instruction, with a numeric jump target. *)
val to_string : side_set_count:int -> Isa.t -> string
