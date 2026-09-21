open! Core
open Protocol_emulator

let movs =
  let open List.Let_syntax in
  let%bind dest = Isa.Mov_dest.Cases.all in
  let%bind op = Isa.Mov_op.Cases.all in
  let%map source = Isa.Mov_source.Cases.all in
  Isa.Op.Mov { dest; op; source }
;;

let alus =
  let open List.Let_syntax in
  let%bind dest = Isa.Alu_dest.Cases.all in
  let%bind op = Isa.Alu_op.Cases.all in
  let%map operand =
    Isa.Alu_operand.Imm 5
    :: List.map Isa.Alu_reg.Cases.all ~f:(fun reg -> Isa.Alu_operand.Reg reg)
  in
  Isa.Op.Alu { dest; op; operand }
;;

(* interleaved, so that the moves carry values the arithmetic has stirred *)
let rec interleave a b =
  match a, b with
  | [], rest | rest, [] -> rest
  | x :: a, y :: b -> x :: y :: interleave a b
;;

(* The lockstep harness randomises the hardware's memory, so the rest of it is filled with
   [jmp 0] rather than left alone. *)
let words =
  let jmp = Isa.to_word ~side_set_count:0 (Jmp { cond = Always; target = 0 }) |> ok_exn in
  let body =
    List.map (interleave movs alus) ~f:(fun op ->
      Isa.to_word ~side_set_count:0 (Op { op; delay = 0; side_set = 0 }) |> ok_exn)
  in
  body @ List.init ((1 lsl Isa.pc_bits) - List.length body) ~f:(fun _ -> jmp)
;;
