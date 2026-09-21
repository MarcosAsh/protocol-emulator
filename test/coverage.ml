open! Core
open Protocol_emulator

type t = String.Hash_set.t

let create () = String.Hash_set.create ()
let name sexp_of_a a = Sexp.to_string (sexp_of_a a) |> String.lowercase

let names (type a) (module E : Isa.Cases with type t = a) =
  List.map E.all ~f:(name E.sexp_of_t)
;;

let product lists =
  List.fold lists ~init:[ "" ] ~f:(fun acc names ->
    List.concat_map acc ~f:(fun prefix ->
      List.map names ~f:(fun n -> String.strip (prefix ^ " " ^ n))))
;;

let wait_name : Isa.Wait.t -> string = function
  | Pin_level { level; _ } -> if level then "pin_level high" else "pin_level low"
  | Pin_edge { rising; _ } -> if rising then "pin_edge rising" else "pin_edge falling"
  | Deadline { advance } -> if advance then "deadline advance" else "deadline"
  | Fifo Tx_not_empty -> "fifo tx"
  | Fifo Rx_not_full -> "fifo rx"
;;

let waits =
  [ "pin_level low"
  ; "pin_level high"
  ; "pin_edge falling"
  ; "pin_edge rising"
  ; "deadline"
  ; "deadline advance"
  ; "fifo tx"
  ; "fifo rx"
  ]
;;

let opcodes = [ "wait"; "in"; "out"; "mov"; "set"; "alu"; "sys" ]

let groups =
  [ "jmp", product [ names (module Isa.Jmp_cond.Cases); [ "taken"; "untaken" ] ]
  ; "wait", product [ waits; [ "held"; "released" ] ]
  ; "in", names (module Isa.In_source.Cases)
  ; "out", names (module Isa.Out_dest.Cases)
  ; ( "mov"
    , product
        [ names (module Isa.Mov_dest.Cases)
        ; names (module Isa.Mov_op.Cases)
        ; names (module Isa.Mov_source.Cases)
        ] )
  ; "set", names (module Isa.Set_dest.Cases)
  ; ( "alu"
    , product
        [ names (module Isa.Alu_dest.Cases)
        ; names (module Isa.Alu_op.Cases)
        ; "imm" :: names (module Isa.Alu_reg.Cases)
        ] )
  ; "sys", names (module Isa.Sys_op.Cases)
  ; "delay", opcodes
  ; "side-set", opcodes
  ]
;;

let unreachable = [ "jmp", "always untaken" ]

let op_point (op : Isa.Op.t) ~held =
  let words = String.concat ~sep:" " in
  match op with
  | Wait wait -> "wait", words [ wait_name wait; (if held then "held" else "released") ]
  | In { source; _ } -> "in", name Isa.In_source.Cases.sexp_of_t source
  | Out { dest; _ } -> "out", name Isa.Out_dest.Cases.sexp_of_t dest
  | Mov { dest; op; source } ->
    ( "mov"
    , words
        [ name Isa.Mov_dest.Cases.sexp_of_t dest
        ; name Isa.Mov_op.Cases.sexp_of_t op
        ; name Isa.Mov_source.Cases.sexp_of_t source
        ] )
  | Set { dest; _ } -> "set", name Isa.Set_dest.Cases.sexp_of_t dest
  | Alu { dest; op; operand } ->
    let operand =
      match operand with
      | Imm _ -> "imm"
      | Reg reg -> name Isa.Alu_reg.Cases.sexp_of_t reg
    in
    ( "alu"
    , words
        [ name Isa.Alu_dest.Cases.sexp_of_t dest
        ; name Isa.Alu_op.Cases.sexp_of_t op
        ; operand
        ] )
  | Sys op -> "sys", name Isa.Sys_op.Cases.sexp_of_t op
;;

let record t ~(before : Machine.t) ~(after : Machine.t) =
  let hit (group, point) = Hash_set.add t (group ^ " " ^ point) in
  let c = before.config in
  if (not before.halted) && before.stall = 0
  then (
    match Isa.of_word ~side_set_count:c.side_set_count before.program.(before.pc) with
    | Error _ -> ()
    | Ok (Jmp { cond; target }) ->
      let falls_to =
        if before.pc = c.wrap_top
        then c.wrap_bottom
        else (before.pc + 1) land ((1 lsl Isa.pc_bits) - 1)
      in
      if target <> falls_to
      then (
        let way = if after.pc = target then " taken" else " untaken" in
        hit ("jmp", name Isa.Jmp_cond.Cases.sexp_of_t cond ^ way))
    | Ok (Op { op; delay; side_set = _ }) ->
      let held = after.pc = before.pc && after.stall = 0 && not after.halted in
      let group, point = op_point op ~held in
      hit (group, point);
      if delay > 0 && not held then hit ("delay", group);
      if c.side_set_count > 0 then hit ("side-set", group))
;;

let split point =
  match String.rsplit2 point ~on:' ' with
  | Some (prefix, last) -> prefix, last
  | None -> "", point
;;

let print_holes t =
  List.iter groups ~f:(fun (group, points) ->
    let reachable =
      List.filter points ~f:(fun point ->
        not (List.mem unreachable (group, point) ~equal:[%equal: string * string]))
    in
    let holes =
      List.filter reachable ~f:(fun point -> not (Hash_set.mem t (group ^ " " ^ point)))
    in
    let hit = List.length reachable - List.length holes in
    printf "%-8s %3d of %3d\n" group hit (List.length reachable);
    List.map holes ~f:split
    |> List.group ~break:(fun (a, _) (b, _) -> String.( <> ) a b)
    |> List.iter ~f:(fun row ->
      let prefix = fst (List.hd_exn row) in
      let width =
        List.count reachable ~f:(fun p -> String.equal (fst (split p)) prefix)
      in
      let missing =
        if List.length row = width && width > 2
        then "all"
        else String.concat ~sep:" " (List.map row ~f:snd)
      in
      printf
        "    %s\n"
        (String.strip (prefix ^ ": " ^ missing)
         |> String.chop_prefix_if_exists ~prefix:": ")));
  print_endline "never, by construction:";
  List.iter unreachable ~f:(fun (group, point) -> printf "    %s %s\n" group point)
;;
