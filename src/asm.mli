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

    [.wrap_target] before an instruction and [.wrap] after one close a loop that costs no
    cycles: after the instruction above [.wrap] comes the one below [.wrap_target].
    Without [.wrap] the loop ends with the program. The addresses go to the program
    config.

    With side-set enabled every instruction except [jmp] drives the side-set pins, so the
    assembler insists on a [side] modifier on each of them.

    A [;] starts a comment. Labels end in [:]. Numbers are decimal, [0x] or [0b]. Register
    and pin operand names are the lower case constructor names from [Isa]: [pins],
    [pindirs], [x], [y], [p], [t], [isr], [osr], [null], [now], [capture], [crc]. [mov]
    sources take a [!] prefix to invert or [::] to reverse. Jump conditions are [x--],
    [y--], [x!=y], [pin], [!pin], [!osre], [stuff], and the fifo tests [tx] (the host has
    written a word), [!tx], [rx] (there is room for a push) and [!rx]. Waits are
    [wait 0 pin N], [wait 1 pin N], [wait rise pin N], [wait fall pin N], [wait t],
    [wait t+], [wait tx] and [wait rx]. The ALU is [add], [sub] and [xor] with a register
    or an immediate. *)

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

  (** The config with the program's side-set count and wrap addresses filled in. *)
  val configure : t -> Program_config.t -> Program_config.t
end

(** Errors carry the line number and the offending line. *)
val assemble : string -> Program.t Or_error.t

(** The inverse of [assemble] for one instruction, with a numeric jump target. *)
val to_string : side_set_count:int -> Isa.t -> string
