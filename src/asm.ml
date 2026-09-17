open! Core

module Program = struct
  type t =
    { side_set_count : int
    ; instructions : Isa.t list
    }
  [@@deriving sexp_of, compare, equal]

  let words t =
    List.map t.instructions ~f:(Isa.to_word ~side_set_count:t.side_set_count)
    |> Or_error.all
  ;;
end

let case_name (type a) (module Cases : Isa.Cases with type t = a) (case : a) =
  Sexp.to_string (Cases.sexp_of_t case) |> String.lowercase
;;

let find_case (type a) (module Cases : Isa.Cases with type t = a) name =
  match
    List.find Cases.all ~f:(fun case -> String.equal (case_name (module Cases) case) name)
  with
  | Some case -> Ok case
  | None ->
    let expected = List.map Cases.all ~f:(case_name (module Cases)) in
    Or_error.error_s [%message "unknown operand" name (expected : string list)]
;;

let jmp_conds : (string * Isa.Jmp_cond.Cases.t) list =
  [ "x--", X_dec
  ; "y--", Y_dec
  ; "x!=y", X_ne_y
  ; "pin", Pin
  ; "!pin", Not_pin
  ; "!osre", Osr_not_empty
  ; "stuff", Stuff_pending
  ]
;;

let sys_ops : (string * Isa.Sys_op.Cases.t) list =
  List.map Isa.Sys_op.Cases.all ~f:(fun op -> case_name (module Isa.Sys_op.Cases) op, op)
;;

let int_of_token token =
  match Int.of_string_opt token with
  | Some n -> Ok n
  | None -> Or_error.error_s [%message "not a number" token]
;;

let bool_of_token token =
  match token with
  | "0" -> Ok false
  | "1" -> Ok true
  | _ -> Or_error.error_s [%message "expected 0 or 1" token]
;;

let strip_comment line =
  match String.lsplit2 line ~on:';' with
  | Some (code, _) -> code
  | None -> line
;;

let tokenize line =
  String.tr line ~target:',' ~replacement:' '
  |> String.split ~on:' '
  |> List.filter ~f:(Fn.non String.is_empty)
;;

let rec split_modifiers tokens ~side_set ~delay =
  let open Or_error.Let_syntax in
  match tokens with
  | [] -> Ok ([], side_set, delay)
  | "side" :: value :: rest ->
    let%bind side_set = int_of_token value in
    split_modifiers rest ~side_set:(Some side_set) ~delay
  | [ "side" ] -> Or_error.error_s [%message "side needs a value"]
  | token :: rest
    when String.is_prefix token ~prefix:"[" && String.is_suffix token ~suffix:"]" ->
    let%bind delay =
      int_of_token (String.sub token ~pos:1 ~len:(String.length token - 2))
    in
    split_modifiers rest ~side_set ~delay
  | token :: rest ->
    let%map args, side_set, delay = split_modifiers rest ~side_set ~delay in
    token :: args, side_set, delay
;;

let parse_wait args : Isa.Wait.t Or_error.t =
  let open Or_error.Let_syntax in
  match args with
  | [ "rise"; "pin"; pin ] ->
    let%map pin = int_of_token pin in
    Isa.Wait.Pin_edge { pin; rising = true }
  | [ "fall"; "pin"; pin ] ->
    let%map pin = int_of_token pin in
    Isa.Wait.Pin_edge { pin; rising = false }
  | [ level; "pin"; pin ] ->
    let%bind level = bool_of_token level in
    let%map pin = int_of_token pin in
    Isa.Wait.Pin_level { pin; level }
  | [ "t" ] -> Ok (Deadline { advance = false })
  | [ "t+" ] -> Ok (Deadline { advance = true })
  | [ "tx" ] -> Ok (Fifo Tx_not_empty)
  | [ "rx" ] -> Ok (Fifo Rx_not_full)
  | _ ->
    Or_error.error_s
      [%message "expected: wait 0|1|rise|fall pin N, wait t, wait t+, wait tx, wait rx"]
;;

let parse_mov_source token =
  let open Or_error.Let_syntax in
  let op, name =
    if String.is_prefix token ~prefix:"::"
    then Isa.Mov_op.Cases.Reverse, String.drop_prefix token 2
    else if String.is_prefix token ~prefix:"!"
    then Invert, String.drop_prefix token 1
    else Copy, token
  in
  let%map source = find_case (module Isa.Mov_source.Cases) name in
  op, source
;;

let parse_alu_operand token =
  match Int.of_string_opt token with
  | Some imm -> Ok (Isa.Alu_operand.Imm imm)
  | None ->
    let%map.Or_error reg = find_case (module Isa.Alu_reg.Cases) token in
    Isa.Alu_operand.Reg reg
;;

let parse_op mnemonic args : Isa.Op.t Or_error.t =
  let open Or_error.Let_syntax in
  match mnemonic, args with
  | "wait", args ->
    let%map wait = parse_wait args in
    Isa.Op.Wait wait
  | "in", [ source; count ] ->
    let%bind source = find_case (module Isa.In_source.Cases) source in
    let%map count = int_of_token count in
    Isa.Op.In { source; count }
  | "out", [ dest; count ] ->
    let%bind dest = find_case (module Isa.Out_dest.Cases) dest in
    let%map count = int_of_token count in
    Isa.Op.Out { dest; count }
  | "mov", [ dest; source ] ->
    let%bind dest = find_case (module Isa.Mov_dest.Cases) dest in
    let%map op, source = parse_mov_source source in
    Isa.Op.Mov { dest; op; source }
  | "set", [ dest; value ] ->
    let%bind dest = find_case (module Isa.Set_dest.Cases) dest in
    let%map value = int_of_token value in
    Isa.Op.Set { dest; value }
  | ("add" | "sub" | "xor"), [ dest; operand ] ->
    let%bind op = find_case (module Isa.Alu_op.Cases) mnemonic in
    let%bind dest = find_case (module Isa.Alu_dest.Cases) dest in
    let%map operand = parse_alu_operand operand in
    Isa.Op.Alu { dest; op; operand }
  | mnemonic, [] when List.Assoc.mem sys_ops mnemonic ~equal:String.equal ->
    Ok (Isa.Op.Sys (List.Assoc.find_exn sys_ops mnemonic ~equal:String.equal))
  | mnemonic, args ->
    Or_error.error_s [%message "cannot parse" mnemonic (args : string list)]
;;

let parse_jmp args ~labels =
  let open Or_error.Let_syntax in
  let target token =
    match List.Assoc.find labels token ~equal:String.equal with
    | Some address -> Ok address
    | None ->
      (match Int.of_string_opt token with
       | Some address -> Ok address
       | None -> Or_error.error_s [%message "unknown label" token])
  in
  match args with
  | [ target_ ] ->
    let%map target = target target_ in
    Isa.Jmp { cond = Always; target }
  | [ cond; target_ ] ->
    (match List.Assoc.find jmp_conds cond ~equal:String.equal with
     | None -> Or_error.error_s [%message "unknown jump condition" cond]
     | Some cond ->
       let%map target = target target_ in
       Isa.Jmp { cond; target })
  | _ -> Or_error.error_s [%message "expected: jmp [cond,] target"]
;;

let parse_instruction tokens ~labels ~side_set_count =
  let open Or_error.Let_syntax in
  let%bind args, side_set, delay = split_modifiers tokens ~side_set:None ~delay:0 in
  match args with
  | [] -> Or_error.error_s [%message "modifiers without an instruction"]
  | "jmp" :: args ->
    if Option.is_some side_set || delay <> 0
    then Or_error.error_s [%message "jmp takes no side-set or delay"]
    else parse_jmp args ~labels
  | mnemonic :: args ->
    let%bind op = parse_op mnemonic args in
    let%bind side_set =
      match side_set with
      | Some side_set -> Ok side_set
      | None ->
        if side_set_count = 0
        then Ok 0
        else
          Or_error.error_s
            [%message "side-set is enabled, so every instruction needs a side"]
    in
    let t = Isa.Op { op; delay; side_set } in
    let%map (_ : int) = Isa.to_word ~side_set_count t in
    t
;;

module Line = struct
  type t =
    | Directive of string * string list
    | Label of string
    | Instruction of string list

  let parse line =
    match tokenize (strip_comment line) with
    | [] -> []
    | directive :: args when String.is_prefix directive ~prefix:"." ->
      [ Directive (String.drop_prefix directive 1, args) ]
    | label :: rest when String.is_suffix label ~suffix:":" ->
      let label = Label (String.drop_suffix label 1) in
      if List.is_empty rest then [ label ] else [ label; Instruction rest ]
    | tokens -> [ Instruction tokens ]
  ;;
end

let assemble source =
  let open Or_error.Let_syntax in
  let lines =
    String.split_lines source
    |> List.concat_mapi ~f:(fun i line ->
      List.map (Line.parse line) ~f:(fun parsed -> i + 1, line, parsed))
  in
  let tag number line = Or_error.tag_s ~tag:[%message "line" ~_:(number : int) line] in
  let%bind side_set_count, labels, _ =
    List.fold_result
      lines
      ~init:(0, [], 0)
      ~f:(fun (side_set_count, labels, address) (number, line, parsed) ->
        tag
          number
          line
          (match parsed with
           | Directive ("side_set", [ count ]) ->
             let%map count = int_of_token count in
             count, labels, address
           | Directive (name, args) ->
             Or_error.error_s [%message "unknown directive" name (args : string list)]
           | Label label ->
             if List.Assoc.mem labels label ~equal:String.equal
             then Or_error.error_s [%message "duplicate label" label]
             else Ok (side_set_count, (label, address) :: labels, address)
           | Instruction _ -> Ok (side_set_count, labels, address + 1)))
  in
  let%map instructions =
    List.filter_map lines ~f:(fun (number, line, parsed) ->
      match parsed with
      | Instruction tokens ->
        Some (tag number line (parse_instruction tokens ~labels ~side_set_count))
      | Directive _ | Label _ -> None)
    |> Or_error.all
  in
  { Program.side_set_count; instructions }
;;

let to_string ~side_set_count (t : Isa.t) =
  let name (type a) (module Cases : Isa.Cases with type t = a) case =
    case_name (module Cases) case
  in
  match t with
  | Jmp { cond; target } ->
    let cond =
      match cond with
      | Always -> ""
      | cond ->
        (List.find_exn jmp_conds ~f:(fun (_, c) -> Isa.Jmp_cond.Cases.equal c cond) |> fst)
        ^ ", "
    in
    [%string "jmp %{cond}%{target#Int}"]
  | Op { op; delay; side_set } ->
    let body =
      match op with
      | Wait (Pin_level { pin; level }) ->
        [%string "wait %{Bool.to_int level#Int} pin %{pin#Int}"]
      | Wait (Pin_edge { pin; rising }) ->
        [%string "wait %{if rising then \"rise\" else \"fall\"} pin %{pin#Int}"]
      | Wait (Deadline { advance }) -> if advance then "wait t+" else "wait t"
      | Wait (Fifo Tx_not_empty) -> "wait tx"
      | Wait (Fifo Rx_not_full) -> "wait rx"
      | In { source; count } ->
        [%string "in %{name (module Isa.In_source.Cases) source}, %{count#Int}"]
      | Out { dest; count } ->
        [%string "out %{name (module Isa.Out_dest.Cases) dest}, %{count#Int}"]
      | Mov { dest; op; source } ->
        let prefix =
          match op with
          | Copy -> ""
          | Invert -> "!"
          | Reverse -> "::"
        in
        [%string
          "mov %{name (module Isa.Mov_dest.Cases) dest}, %{prefix}%{name (module \
           Isa.Mov_source.Cases) source}"]
      | Set { dest; value } ->
        [%string "set %{name (module Isa.Set_dest.Cases) dest}, %{value#Int}"]
      | Alu { dest; op; operand } ->
        let operand =
          match operand with
          | Imm imm -> Int.to_string imm
          | Reg reg -> name (module Isa.Alu_reg.Cases) reg
        in
        [%string
          "%{name (module Isa.Alu_op.Cases) op} %{name (module Isa.Alu_dest.Cases) \
           dest}, %{operand}"]
      | Sys op -> name (module Isa.Sys_op.Cases) op
    in
    let side = if side_set_count = 0 then "" else [%string " side %{side_set#Int}"] in
    let delay = if delay = 0 then "" else [%string " [%{delay#Int}]"] in
    body ^ side ^ delay
;;
