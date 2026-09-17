open! Core
open! Hardcaml

let word_bits = 16
let data_bits = 16
let timer_bits = 24
let pc_bits = 9
let delay_bits = 5
let max_side_set = 2
let num_pins = 20
let max_shift_count = 16
let jmp_cycles = 2

module Field = struct
  type t =
    { lsb : int
    ; width : int
    }
  [@@deriving sexp_of]

  let mask t = (1 lsl t.width) - 1
  let extract t word = (word lsr t.lsb) land mask t

  let insert t value word =
    if value < 0 || value > mask t
    then raise_s [%message "BUG: value does not fit in field" (t : t) (value : int)];
    word lor (value lsl t.lsb)
  ;;

  let select (type a) (module Comb : Comb.S with type t = a) t (word : a) =
    Comb.select word ~high:(t.lsb + t.width - 1) ~low:t.lsb
  ;;

  let op = { lsb = 13; width = 3 }
  let delay_side = { lsb = 8; width = 5 }
  let jmp_cond = { lsb = 10; width = 3 }
  let jmp_target = { lsb = 0; width = 9 }
  let wait_polarity = { lsb = 7; width = 1 }
  let wait_source = { lsb = 5; width = 2 }
  let wait_index = { lsb = 0; width = 5 }
  let shift_target = { lsb = 5; width = 3 }
  let shift_count = { lsb = 0; width = 5 }
  let mov_dest = { lsb = 5; width = 3 }
  let mov_op = { lsb = 3; width = 2 }
  let mov_source = { lsb = 0; width = 3 }
  let set_dest = { lsb = 5; width = 3 }
  let set_value = { lsb = 0; width = 5 }
  let alu_dest = { lsb = 6; width = 2 }
  let alu_op = { lsb = 4; width = 2 }
  let alu_is_reg = { lsb = 3; width = 1 }
  let alu_operand = { lsb = 0; width = 3 }
  let sys_op = { lsb = 0; width = 3 }
end

module type Cases = sig
  type t [@@deriving sexp_of, compare ~localize, enumerate, equal]
end

module type Enum = sig
  module Cases : Cases
  include Hardcaml.Enum.S_enum with module Cases := Cases

  val width : int
  val to_int : Cases.t -> int
  val of_int : int -> Cases.t Or_error.t
end

module Make_enum (Cases : Cases) = struct
  include Hardcaml.Enum.Make_binary (Cases)

  let width = to_raw port_widths
  let to_int t = to_raw (Of_bits.of_enum t) |> Bits.to_unsigned_int

  let of_int i =
    match List.nth Cases.all i with
    | Some t -> Ok t
    | None -> Or_error.error_s [%message "no such enum code" (i : int)]
  ;;
end

module Opcode = struct
  module Cases = struct
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

  include Make_enum (Cases)
end

module Jmp_cond = struct
  module Cases = struct
    type t =
      | Always
      | X_dec
      | Y_dec
      | X_ne_y
      | Pin
      | Not_pin
      | Osr_not_empty
      | Stuff_pending
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Wait_source = struct
  module Cases = struct
    type t =
      | Pin_level
      | Pin_edge
      | Deadline
      | Fifo
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module In_source = struct
  module Cases = struct
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

  include Make_enum (Cases)
end

module Out_dest = struct
  module Cases = struct
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

  include Make_enum (Cases)
end

module Mov_dest = struct
  module Cases = struct
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

  include Make_enum (Cases)
end

module Mov_op = struct
  module Cases = struct
    type t =
      | Copy
      | Invert
      | Reverse
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Mov_source = struct
  module Cases = struct
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

  include Make_enum (Cases)
end

module Set_dest = struct
  module Cases = struct
    type t =
      | Pins
      | X
      | Y
      | Pindirs
      | P
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Alu_dest = struct
  module Cases = struct
    type t =
      | X
      | Y
      | P
      | T
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Alu_op = struct
  module Cases = struct
    type t =
      | Add
      | Sub
      | Xor
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Alu_reg = struct
  module Cases = struct
    type t =
      | X
      | Y
      | P
      | Isr
      | Osr
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Sys_op = struct
  module Cases = struct
    type t =
      | Nop
      | Halt
      | Irq
      | Push
      | Pull
      | Crc_init
      | Stuff_reset
      | Capture_arm
    [@@deriving sexp_of, compare ~localize, enumerate, equal]
  end

  include Make_enum (Cases)
end

module Fifo_wait = struct
  type t =
    | Tx_not_empty
    | Rx_not_full
  [@@deriving sexp_of, compare, equal]
end

module Wait = struct
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

module Alu_operand = struct
  type t =
    | Imm of int
    | Reg of Alu_reg.Cases.t
  [@@deriving sexp_of, compare, equal]
end

module Op = struct
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

let in_range name value ~lo ~hi =
  if lo <= value && value <= hi
  then Ok ()
  else Or_error.error_s [%message name "out of range" (value : int) (lo : int) (hi : int)]
;;

let reserved_bits_clear word ~mask =
  if word land mask = 0
  then Ok ()
  else Or_error.error_s [%message "reserved bits set" (word : int) (mask : int)]
;;

let delay_width ~side_set_count = delay_bits - side_set_count

let encode_delay_side ~side_set_count ~delay ~side_set =
  let open Or_error.Let_syntax in
  let%bind () = in_range "side_set_count" side_set_count ~lo:0 ~hi:max_side_set in
  let delay_width = delay_width ~side_set_count in
  let%bind () = in_range "delay" delay ~lo:0 ~hi:((1 lsl delay_width) - 1) in
  let%map () = in_range "side_set" side_set ~lo:0 ~hi:((1 lsl side_set_count) - 1) in
  (side_set lsl delay_width) lor delay
;;

let decode_delay_side ~side_set_count ds =
  let open Or_error.Let_syntax in
  let%map () = in_range "side_set_count" side_set_count ~lo:0 ~hi:max_side_set in
  let delay_width = delay_width ~side_set_count in
  ds land ((1 lsl delay_width) - 1), ds lsr delay_width
;;

let pin_index pin = in_range "pin" pin ~lo:0 ~hi:(num_pins - 1)
let shift_count count = in_range "count" count ~lo:1 ~hi:max_shift_count

let encode_wait (wait : Wait.t) =
  let open Or_error.Let_syntax in
  let%map polarity, source, index =
    match wait with
    | Pin_level { pin; level } ->
      let%map () = pin_index pin in
      level, Wait_source.Cases.Pin_level, pin
    | Pin_edge { pin; rising } ->
      let%map () = pin_index pin in
      rising, Wait_source.Cases.Pin_edge, pin
    | Deadline { advance } -> return (advance, Wait_source.Cases.Deadline, 0)
    | Fifo Tx_not_empty -> return (true, Wait_source.Cases.Fifo, 0)
    | Fifo Rx_not_full -> return (false, Wait_source.Cases.Fifo, 0)
  in
  0
  |> Field.insert Field.wait_polarity (Bool.to_int polarity)
  |> Field.insert Field.wait_source (Wait_source.to_int source)
  |> Field.insert Field.wait_index index
;;

let decode_wait body =
  let open Or_error.Let_syntax in
  let polarity = Field.extract Field.wait_polarity body = 1 in
  let index = Field.extract Field.wait_index body in
  let%bind source = Wait_source.of_int (Field.extract Field.wait_source body) in
  match (source : Wait_source.Cases.t) with
  | Pin_level ->
    let%map () = pin_index index in
    Wait.Pin_level { pin = index; level = polarity }
  | Pin_edge ->
    let%map () = pin_index index in
    Wait.Pin_edge { pin = index; rising = polarity }
  | Deadline ->
    let%map () = in_range "index" index ~lo:0 ~hi:0 in
    Wait.Deadline { advance = polarity }
  | Fifo ->
    let%map () = in_range "index" index ~lo:0 ~hi:0 in
    Wait.Fifo (if polarity then Tx_not_empty else Rx_not_full)
;;

let encode_body (op : Op.t) =
  let open Or_error.Let_syntax in
  match op with
  | Wait wait ->
    let%map body = encode_wait wait in
    Opcode.Cases.Wait, body
  | In { source; count } ->
    let%map () = shift_count count in
    ( Opcode.Cases.In
    , 0
      |> Field.insert Field.shift_target (In_source.to_int source)
      |> Field.insert Field.shift_count count )
  | Out { dest; count } ->
    let%map () = shift_count count in
    ( Opcode.Cases.Out
    , 0
      |> Field.insert Field.shift_target (Out_dest.to_int dest)
      |> Field.insert Field.shift_count count )
  | Mov { dest; op; source } ->
    return
      ( Opcode.Cases.Mov
      , 0
        |> Field.insert Field.mov_dest (Mov_dest.to_int dest)
        |> Field.insert Field.mov_op (Mov_op.to_int op)
        |> Field.insert Field.mov_source (Mov_source.to_int source) )
  | Set { dest; value } ->
    let%map () = in_range "value" value ~lo:0 ~hi:(Field.mask Field.set_value) in
    ( Opcode.Cases.Set
    , 0
      |> Field.insert Field.set_dest (Set_dest.to_int dest)
      |> Field.insert Field.set_value value )
  | Alu { dest; op; operand } ->
    let%map is_reg, operand =
      match operand with
      | Imm imm ->
        let%map () = in_range "imm" imm ~lo:0 ~hi:(Field.mask Field.alu_operand) in
        0, imm
      | Reg reg -> return (1, Alu_reg.to_int reg)
    in
    ( Opcode.Cases.Alu
    , 0
      |> Field.insert Field.alu_dest (Alu_dest.to_int dest)
      |> Field.insert Field.alu_op (Alu_op.to_int op)
      |> Field.insert Field.alu_is_reg is_reg
      |> Field.insert Field.alu_operand operand )
  | Sys sys -> return (Opcode.Cases.Sys, Field.insert Field.sys_op (Sys_op.to_int sys) 0)
;;

let decode_body (opcode : Opcode.Cases.t) body =
  let open Or_error.Let_syntax in
  let get = Field.extract in
  match opcode with
  | Jmp -> raise_s [%message "BUG: jmp has no body"]
  | Wait ->
    let%map wait = decode_wait body in
    Op.Wait wait
  | In ->
    let count = get Field.shift_count body in
    let%bind () = shift_count count in
    let%map source = In_source.of_int (get Field.shift_target body) in
    Op.In { source; count }
  | Out ->
    let count = get Field.shift_count body in
    let%bind () = shift_count count in
    let%map dest = Out_dest.of_int (get Field.shift_target body) in
    Op.Out { dest; count }
  | Mov ->
    let%bind dest = Mov_dest.of_int (get Field.mov_dest body) in
    let%bind op = Mov_op.of_int (get Field.mov_op body) in
    let%map source = Mov_source.of_int (get Field.mov_source body) in
    Op.Mov { dest; op; source }
  | Set ->
    let%map dest = Set_dest.of_int (get Field.set_dest body) in
    Op.Set { dest; value = get Field.set_value body }
  | Alu ->
    let%bind dest = Alu_dest.of_int (get Field.alu_dest body) in
    let%bind op = Alu_op.of_int (get Field.alu_op body) in
    let operand = get Field.alu_operand body in
    let%map operand =
      if get Field.alu_is_reg body = 1
      then (
        let%map reg = Alu_reg.of_int operand in
        Alu_operand.Reg reg)
      else return (Alu_operand.Imm operand)
    in
    Op.Alu { dest; op; operand }
  | Sys ->
    let%bind () = reserved_bits_clear body ~mask:(lnot (Field.mask Field.sys_op)) in
    let%map sys = Sys_op.of_int (get Field.sys_op body) in
    Op.Sys sys
;;

let jmp_reserved_mask =
  Field.mask { lsb = 0; width = word_bits }
  land lnot (Field.mask Field.op lsl Field.op.lsb)
  land lnot (Field.mask Field.jmp_cond lsl Field.jmp_cond.lsb)
  land lnot (Field.mask Field.jmp_target lsl Field.jmp_target.lsb)
;;

let to_word ~side_set_count t =
  let open Or_error.Let_syntax in
  match t with
  | Jmp { cond; target } ->
    let%map () = in_range "target" target ~lo:0 ~hi:(Field.mask Field.jmp_target) in
    0
    |> Field.insert Field.op (Opcode.to_int Jmp)
    |> Field.insert Field.jmp_cond (Jmp_cond.to_int cond)
    |> Field.insert Field.jmp_target target
  | Op { op; delay; side_set } ->
    let%bind opcode, body = encode_body op in
    let%map delay_side = encode_delay_side ~side_set_count ~delay ~side_set in
    Field.insert Field.op (Opcode.to_int opcode) 0
    |> Field.insert Field.delay_side delay_side
    |> ( lor ) body
;;

let of_word ~side_set_count word =
  let open Or_error.Let_syntax in
  let%bind () = in_range "word" word ~lo:0 ~hi:((1 lsl word_bits) - 1) in
  let%bind opcode = Opcode.of_int (Field.extract Field.op word) in
  match (opcode : Opcode.Cases.t) with
  | Jmp ->
    let%bind () = reserved_bits_clear word ~mask:jmp_reserved_mask in
    let%map cond = Jmp_cond.of_int (Field.extract Field.jmp_cond word) in
    Jmp { cond; target = Field.extract Field.jmp_target word }
  | opcode ->
    let%bind op = decode_body opcode (word land 0xff) in
    let%map delay, side_set =
      decode_delay_side ~side_set_count (Field.extract Field.delay_side word)
    in
    Op { op; delay; side_set }
;;
