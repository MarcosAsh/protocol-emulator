open! Core

module Hole = struct
  type kind =
    | Delay
    | Side
  [@@deriving sexp_of]

  type t =
    { line : int
    ; kind : kind
    ; reference : int option
    ; domain : int list
    }
  [@@deriving sexp_of]
end

(* A hole is the [?] at [column] of [line] (from 0 here). Its value is written in binary
   with [binary] digits when the reference writes it so. *)
type spot =
  { line : int
  ; column : int
  ; kind : Hole.kind
  ; binary : int option
  }

type t =
  { lines : string array
  ; spots : spot list
  ; holes : Hole.t list
  ; reference : string array option
  }

let holes t = t.holes

(* The part of a line pioasm reads, as [Pioasm.strip_comment] cuts it. *)
let code line =
  let cut line sep =
    match String.substr_index line ~pattern:sep with
    | Some i -> String.prefix line i
    | None -> line
  in
  cut (cut line ";") "//"
;;

let is_side_keyword word =
  List.mem [ "side"; "sideset"; "side_set" ] (String.lowercase word) ~equal:String.equal
;;

let word_before text i =
  String.split_on_chars (String.prefix text i) ~on:[ ' '; '\t' ]
  |> List.filter ~f:(Fn.non String.is_empty)
  |> List.last
  |> Option.value ~default:""
;;

let spots_of_line ~line text =
  let code = code text in
  String.to_list code
  |> List.filter_mapi ~f:(fun column char -> Option.some_if (Char.equal char '?') column)
  |> List.map ~f:(fun column ->
    let before = String.rstrip (String.prefix code column) in
    let after = String.lstrip (String.drop_prefix code (column + 1)) in
    if String.is_suffix before ~suffix:"[" && String.is_prefix after ~prefix:"]"
    then Ok { line; column; kind = Delay; binary = None }
    else if is_side_keyword (word_before code column)
    then Ok { line; column; kind = Side; binary = None }
    else
      Or_error.error_s
        [%message "a ? that is neither [?] nor side ?" ~line:(line + 1 : int)])
  |> Or_error.all
;;

let fill_spots lines spots values =
  let lines = Array.copy lines in
  List.zip_exn spots values
  |> List.sort ~compare:(fun ((a : spot), _) (b, _) ->
    Comparable.lift [%compare: int * int] ~f:(fun (s : spot) -> s.line, -s.column) a b)
  |> List.iter ~f:(fun ({ line; column; kind = _; binary }, value) ->
    let value =
      match binary with
      | None -> Int.to_string value
      | Some digits ->
        let digits = Int.max digits (Int.ceil_log2 (value + 1)) in
        "0b"
        ^ String.init digits ~f:(fun i ->
          if value land (1 lsl (digits - 1 - i)) <> 0 then '1' else '0')
    in
    let text = lines.(line) in
    lines.(line)
    <- String.prefix text column ^ value ^ String.drop_prefix text (column + 1));
  String.concat_array ~sep:"\n" lines
;;

(* A line whose holes all take the reference's values is the reference's line, as it was. *)
let fill t values =
  match t.reference with
  | None -> fill_spots t.lines t.spots values
  | Some reference ->
    let changed =
      List.zip_exn (List.zip_exn t.spots t.holes) values
      |> List.filter_map ~f:(fun ((spot, hole), value) ->
        Option.some_if (not ([%equal: int option] hole.reference (Some value))) spot.line)
    in
    let is_changed line = List.mem changed line ~equal:Int.equal in
    let lines =
      Array.mapi t.lines ~f:(fun line text ->
        if is_changed line then text else reference.(line))
    in
    let spots, values =
      List.zip_exn t.spots values
      |> List.filter ~f:(fun ((spot : spot), _) -> is_changed spot.line)
      |> List.unzip
    in
    fill_spots lines spots values
;;

(* The value a reference line gives the hole, a number between [[ ]] or after a side
   keyword, and the binary digits it is written with. *)
let reference_value (kind : Hole.kind) ~line text =
  let code = code text in
  let number text =
    match Int.of_string_opt (String.strip text) with
    | Some value -> Ok (Some value)
    | None ->
      Or_error.error_s
        [%message "reference value is not a number" ~line:(line + 1 : int) text]
  in
  match kind with
  | Delay ->
    (match String.lsplit2 code ~on:'[' with
     | None -> Ok (Some 0, None)
     | Some (_, rest) ->
       let inside =
         String.lsplit2 rest ~on:']' |> Option.value_map ~default:rest ~f:fst
       in
       number inside |> Or_error.map ~f:(fun value -> value, None))
  | Side ->
    let words =
      String.split_on_chars code ~on:[ ' '; '\t'; '[' ]
      |> List.filter ~f:(Fn.non String.is_empty)
    in
    let rec find = function
      | keyword :: value :: _ when is_side_keyword keyword ->
        let binary =
          Option.map (String.chop_prefix value ~prefix:"0b") ~f:String.length
        in
        number value |> Or_error.map ~f:(fun value -> value, binary)
      | _ :: rest -> find rest
      | [] -> Ok (None, None)
    in
    find words
;;

let parse ?reference text =
  let open Or_error.Let_syntax in
  let lines = String.split_lines text |> Array.of_list in
  let%bind spots =
    Array.to_list lines
    |> List.mapi ~f:(fun line text -> spots_of_line ~line text)
    |> Or_error.all
    |> Or_error.map ~f:List.concat
  in
  let%bind () = if List.is_empty spots then Or_error.error_string "no holes" else Ok () in
  let reference =
    Option.map reference ~f:(fun text -> String.split_lines text |> Array.of_list)
  in
  let%bind references =
    match reference with
    | None -> Ok (List.map spots ~f:(fun _ -> None, None))
    | Some reference ->
      let%bind () =
        if Array.length reference = Array.length lines
        then Ok ()
        else Or_error.error_string "the reference has a different number of lines"
      in
      let%bind () =
        Array.to_list lines
        |> List.mapi ~f:(fun line text ->
          if List.exists spots ~f:(fun spot -> spot.line = line)
             || String.equal text reference.(line)
          then Ok ()
          else
            Or_error.error_s
              [%message
                "differs from the reference outside a hole" ~line:(line + 1 : int)])
        |> Or_error.all_unit
      in
      List.map spots ~f:(fun spot ->
        reference_value spot.kind ~line:spot.line reference.(spot.line))
      |> Or_error.all
  in
  (* Every hole 0 must assemble; a value is in a hole's domain when pioasm takes it there
     with every other hole 0. *)
  let reference_values = List.map references ~f:fst in
  let spots =
    List.map2_exn spots references ~f:(fun spot (_, binary) -> { spot with binary })
  in
  let zeros = List.map spots ~f:(fun _ -> 0) in
  let%bind _ = fill_spots lines spots zeros |> Pioasm.parse in
  let%bind holes =
    List.mapi (List.zip_exn spots reference_values) ~f:(fun i (spot, reference) ->
      let domain =
        List.filter (List.range 0 32) ~f:(fun value ->
          List.mapi zeros ~f:(fun j zero -> if i = j then value else zero)
          |> fill_spots lines spots
          |> Pioasm.parse
          |> Result.is_ok)
      in
      match reference with
      | Some value when not (List.mem domain value ~equal:Int.equal) ->
        Or_error.error_s
          [%message
            "reference value out of the hole's range"
              ~line:(spot.line + 1 : int)
              (value : int)]
      | _ -> Ok { Hole.line = spot.line + 1; kind = spot.kind; reference; domain })
    |> Or_error.all
  in
  return { lines; spots; holes; reference }
;;

let hole_cost ~has_reference (hole : Hole.t) value =
  match has_reference, hole.kind, hole.reference with
  | false, Delay, _ -> value
  | false, Side, _ -> 0
  | true, Delay, reference -> abs (value - Option.value reference ~default:0)
  | true, Side, Some reference -> Int.popcount (value lxor reference)
  | true, Side, None -> 1
;;

let cost t values =
  List.zip_exn t.holes values
  |> List.sum (module Int) ~f:(fun (hole, value) ->
    hole_cost ~has_reference:(Option.is_some t.reference) hole value)
;;

let meets specs text =
  let open Or_error.Let_syntax in
  let%bind programs = Pioasm.parse text in
  List.map specs ~f:(fun spec ->
    let%bind programs = Spec.select spec programs in
    let%bind configure = Spec.configure spec in
    List.map programs ~f:(fun program ->
      let%map config = configure program in
      Timing.Report.passed (Timing.analyse config program))
    |> Or_error.all)
  |> Or_error.all
  >>| List.for_all ~f:(List.for_all ~f:Fn.id)
;;

module Search = struct
  type t =
    { checked : (int * int) list
    ; minimal : (int * int list list) option
    }
  [@@deriving sexp_of]
end

let solve ?(max_checks = 100_000) t ~passes =
  let open Or_error.Let_syntax in
  let choices =
    List.map t.holes ~f:(fun hole ->
      List.map hole.domain ~f:(fun value ->
        value, hole_cost ~has_reference:(Option.is_some t.reference) hole value))
  in
  let most =
    List.sum (module Int) choices ~f:(fun choices ->
      List.fold choices ~init:0 ~f:(fun most (_, cost) -> Int.max most cost))
  in
  (* Every assignment of the remaining holes costing exactly [budget], made as needed. *)
  let rec assignments choices ~budget =
    match choices with
    | [] -> if budget = 0 then Sequence.singleton [] else Sequence.empty
    | first :: rest ->
      Sequence.of_list first
      |> Sequence.concat_map ~f:(fun (value, cost) ->
        if cost > budget
        then Sequence.empty
        else
          assignments rest ~budget:(budget - cost)
          |> Sequence.map ~f:(fun tail -> value :: tail))
  in
  let rec count choices ~budget =
    match choices with
    | [] -> if budget = 0 then 1 else 0
    | first :: rest ->
      List.sum (module Int) first ~f:(fun (_, cost) ->
        if cost > budget then 0 else count rest ~budget:(budget - cost))
  in
  let rec search ~budget ~checked ~tried =
    if budget > most
    then return { Search.checked = List.rev checked; minimal = None }
    else (
      let size = count choices ~budget in
      let%bind () =
        if tried + size > max_checks
        then
          Or_error.error_s
            [%message
              "more assignments than max_checks" (budget : int) (max_checks : int)]
        else Ok ()
      in
      let%bind passing =
        assignments choices ~budget
        |> Sequence.fold_result ~init:[] ~f:(fun passing values ->
          let%map passed = passes (fill t values) in
          if passed then values :: passing else passing)
        >>| List.rev
      in
      let checked = (budget, size) :: checked in
      match passing with
      | [] -> search ~budget:(budget + 1) ~checked ~tried:(tried + size)
      | _ :: _ ->
        return { Search.checked = List.rev checked; minimal = Some (budget, passing) })
  in
  search ~budget:0 ~checked:[] ~tried:0
;;
