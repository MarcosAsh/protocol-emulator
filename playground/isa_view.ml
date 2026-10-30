open! Core
open Protocol_emulator

module Slot = struct
  type t =
    { name : string
    ; lsb : int
    ; width : int
    ; cases : (int * string) list
    }
end

type decoded =
  { text : string
  ; error : string
  ; slots : (Slot.t * int) list
  }

let cases all ~to_int ~sexp_of =
  List.map all ~f:(fun case -> to_int case, Sexp.to_string (sexp_of case))
;;

let slot ?(cases = []) name (field : Isa.Field.t) =
  { Slot.name; lsb = field.lsb; width = field.width; cases }
;;

let opcode_cases =
  cases Isa.Opcode.Cases.all ~to_int:Isa.Opcode.to_int ~sexp_of:Isa.Opcode.Cases.sexp_of_t
;;

(* the side-set bits are the top of the delay field, the delay the rest *)
let delay_slots ~side_set_count =
  let field = Isa.Field.delay_side in
  let delay_width = field.width - side_set_count in
  List.filter_opt
    [ Option.some_if
        (side_set_count > 0)
        (slot "side" { Isa.Field.lsb = field.lsb + delay_width; width = side_set_count })
    ; Option.some_if
        (delay_width > 0)
        (slot "delay" { Isa.Field.lsb = field.lsb; width = delay_width })
    ]
;;

let layout ~side_set_count (opcode : Isa.Opcode.Cases.t) =
  let delay = delay_slots ~side_set_count in
  slot ~cases:opcode_cases "op" Isa.Field.op
  ::
  (match opcode with
   | Jmp ->
     [ slot
         ~cases:
           (cases
              Isa.Jmp_cond.Cases.all
              ~to_int:Isa.Jmp_cond.to_int
              ~sexp_of:Isa.Jmp_cond.Cases.sexp_of_t)
         "cond"
         Isa.Field.jmp_cond
     ; slot "target" Isa.Field.jmp_target
     ]
   | Wait ->
     delay
     @ [ slot "polarity" Isa.Field.wait_polarity
       ; slot
           ~cases:
             (cases
                Isa.Wait_source.Cases.all
                ~to_int:Isa.Wait_source.to_int
                ~sexp_of:Isa.Wait_source.Cases.sexp_of_t)
           "source"
           Isa.Field.wait_source
       ; slot "index" Isa.Field.wait_index
       ]
   | In ->
     delay
     @ [ slot
           ~cases:
             (cases
                Isa.In_source.Cases.all
                ~to_int:Isa.In_source.to_int
                ~sexp_of:Isa.In_source.Cases.sexp_of_t)
           "source"
           Isa.Field.shift_target
       ; slot "count" Isa.Field.shift_count
       ]
   | Out ->
     delay
     @ [ slot
           ~cases:
             (cases
                Isa.Out_dest.Cases.all
                ~to_int:Isa.Out_dest.to_int
                ~sexp_of:Isa.Out_dest.Cases.sexp_of_t)
           "dest"
           Isa.Field.shift_target
       ; slot "count" Isa.Field.shift_count
       ]
   | Mov ->
     delay
     @ [ slot
           ~cases:
             (cases
                Isa.Mov_dest.Cases.all
                ~to_int:Isa.Mov_dest.to_int
                ~sexp_of:Isa.Mov_dest.Cases.sexp_of_t)
           "dest"
           Isa.Field.mov_dest
       ; slot
           ~cases:
             (cases
                Isa.Mov_op.Cases.all
                ~to_int:Isa.Mov_op.to_int
                ~sexp_of:Isa.Mov_op.Cases.sexp_of_t)
           "op"
           Isa.Field.mov_op
       ; slot
           ~cases:
             (cases
                Isa.Mov_source.Cases.all
                ~to_int:Isa.Mov_source.to_int
                ~sexp_of:Isa.Mov_source.Cases.sexp_of_t)
           "source"
           Isa.Field.mov_source
       ]
   | Set ->
     delay
     @ [ slot
           ~cases:
             (cases
                Isa.Set_dest.Cases.all
                ~to_int:Isa.Set_dest.to_int
                ~sexp_of:Isa.Set_dest.Cases.sexp_of_t)
           "dest"
           Isa.Field.set_dest
       ; slot "value" Isa.Field.set_value
       ]
   | Alu ->
     delay
     @ [ slot
           ~cases:
             (cases
                Isa.Alu_dest.Cases.all
                ~to_int:Isa.Alu_dest.to_int
                ~sexp_of:Isa.Alu_dest.Cases.sexp_of_t)
           "dest"
           Isa.Field.alu_dest
       ; slot
           ~cases:
             (cases
                Isa.Alu_op.Cases.all
                ~to_int:Isa.Alu_op.to_int
                ~sexp_of:Isa.Alu_op.Cases.sexp_of_t)
           "op"
           Isa.Field.alu_op
       ; slot "is_reg" Isa.Field.alu_is_reg
       ; slot "operand" Isa.Field.alu_operand
       ]
   | Sys ->
     delay
     @ [ slot
           ~cases:
             (cases
                Isa.Sys_op.Cases.all
                ~to_int:Isa.Sys_op.to_int
                ~sexp_of:Isa.Sys_op.Cases.sexp_of_t)
           "sys_op"
           Isa.Field.sys_op
       ])
;;

let opcodes ~side_set_count =
  List.map Isa.Opcode.Cases.all ~f:(fun opcode ->
    ( Isa.Opcode.to_int opcode
    , Sexp.to_string (Isa.Opcode.Cases.sexp_of_t opcode)
    , layout ~side_set_count opcode ))
;;

let decode ~side_set_count word =
  let slots =
    match Isa.Opcode.of_int (Isa.Field.extract Isa.Field.op word) with
    | Error _ -> []
    | Ok opcode ->
      List.map (layout ~side_set_count opcode) ~f:(fun slot ->
        slot, Isa.Field.extract { lsb = slot.lsb; width = slot.width } word)
  in
  match Isa.of_word ~side_set_count word with
  | Ok instruction ->
    { text = Asm.to_string ~side_set_count instruction; error = ""; slots }
  | Error e -> { text = ""; error = Error.to_string_hum e; slots }
;;

let assemble ~side_set_count line =
  let source =
    if side_set_count > 0 then sprintf ".side_set %d\n%s\n" side_set_count line else line
  in
  match
    let open Or_error.Let_syntax in
    let%bind program = Asm.assemble source in
    let%bind words = Asm.Program.words program in
    match words with
    | [ word ] -> Ok word
    | words ->
      Or_error.error_s
        [%message "expected one instruction" ~got:(List.length words : int)]
  with
  | Ok word -> Ok word
  | Error e -> Error (Error.to_string_hum e)
;;
