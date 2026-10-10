open! Core

(* a line of code as tokens, its comment kept apart *)
let split line =
  let code, comment =
    match String.lsplit2 line ~on:';' with
    | Some (code, comment) -> code, Some comment
    | None -> line, None
  in
  String.split code ~on:' ' |> List.filter ~f:(Fn.non String.is_empty), comment
;;

(* the comment kept at its column *)
let join ?(column = 0) ?comment tokens =
  let code = "    " ^ String.concat ~sep:" " tokens in
  match comment with
  | None -> code
  | Some comment ->
    let code = String.pad_right code ~len:(Int.max column (String.length code + 1)) in
    [%string "%{code};%{comment}"]
;;

let renumber ~pins token =
  match List.Assoc.find pins ~equal:Int.equal (Int.of_string token) with
  | Some moved -> Int.to_string moved
  | None -> raise_s [%message "BUG: a pin with nowhere to go" token]
;;

let move_pins ~pins source =
  String.split_lines source
  |> List.map ~f:(fun line ->
    let column = String.index line ';' |> Option.value ~default:0 in
    match split line with
    | "wait" :: level :: "pin" :: n :: rest, comment ->
      join ~column ?comment ("wait" :: level :: "pin" :: renumber ~pins n :: rest)
    | _ -> line)
  |> String.concat_lines
;;

let open_drain_on_wire ~pins source =
  let pin = renumber ~pins in
  let flip = function
    | "0" -> "1"
    | "1" -> "0"
    | "rise" -> "fall"
    | "fall" -> "rise"
    | level -> raise_s [%message "BUG: not a level" level]
  in
  String.split_lines source
  |> List.concat_map ~f:(fun line ->
    let column = String.index line ';' |> Option.value ~default:0 in
    let join = join ~column in
    match split line with
    | (("set" | "mov") as op) :: "pindirs," :: rest, comment ->
      [ join ?comment (op :: "pins," :: rest) ]
    | "in" :: "pins," :: count :: rest, comment ->
      [ join ?comment ("mov" :: "y," :: "!pins" :: rest)
      ; join ("in" :: "y," :: count :: rest)
      ]
    | "wait" :: level :: "pin" :: n :: rest, comment ->
      [ join ?comment ("wait" :: flip level :: "pin" :: pin n :: rest) ]
    | "jmp" :: "pin," :: rest, comment -> [ join ?comment ("jmp" :: "!pin," :: rest) ]
    | "jmp" :: "!pin," :: rest, comment -> [ join ?comment ("jmp" :: "pin," :: rest) ]
    | tokens, _ ->
      if List.exists tokens ~f:(String.is_substring ~substring:"pin")
      then raise_s [%message "BUG: a pin use with no rewrite" line];
      [ line ])
  |> String.concat_lines
;;
