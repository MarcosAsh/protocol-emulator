open! Core

module Condition = struct
  type t =
    | Always
    | X_zero
    | X_post_decrement
    | Y_zero
    | Y_post_decrement
    | X_not_y
    | Pin
    | Osr_not_empty
  [@@deriving sexp_of, equal]
end

module Source = struct
  type t =
    | Pins
    | X
    | Y
    | Null
    | Status
    | Isr
    | Osr
  [@@deriving sexp_of, equal]
end

module Destination = struct
  type t =
    | Pins
    | X
    | Y
    | Null
    | Pindirs
    | Pc
    | Isr
    | Osr
    | Exec
  [@@deriving sexp_of, equal]
end

module Wait_source = struct
  type t =
    | Gpio of int
    | Pin of int
    | Irq of int
    | Jmp_pin
  [@@deriving sexp_of, equal]
end

module Mov_op = struct
  type t =
    | Copy
    | Invert
    | Reverse
  [@@deriving sexp_of, equal]
end

module Irq_mode = struct
  type t =
    | Raise
    | Raise_and_wait
    | Clear
  [@@deriving sexp_of, equal]
end

module Op = struct
  type t =
    | Jmp of
        { condition : Condition.t
        ; target : int
        }
    | Wait of
        { polarity : bool
        ; source : Wait_source.t
        }
    | In of
        { source : Source.t
        ; bits : int
        }
    | Out of
        { destination : Destination.t
        ; bits : int
        }
    | Push of
        { if_full : bool
        ; block : bool
        }
    | Pull of
        { if_empty : bool
        ; block : bool
        }
    | Mov of
        { destination : Destination.t
        ; op : Mov_op.t
        ; source : Source.t
        }
    | Irq of
        { mode : Irq_mode.t
        ; index : int
        }
    | Set of
        { destination : Destination.t
        ; value : int
        }
  [@@deriving sexp_of, equal]
end

module Instruction = struct
  type t =
    { op : Op.t
    ; delay : int
    ; side : int option
    ; text : string
    }
  [@@deriving sexp_of]
end

module Side_set = struct
  type t =
    { count : int
    ; optional : bool
    ; pindirs : bool
    }
  [@@deriving sexp_of]

  let none = { count = 0; optional = false; pindirs = false }
  let delay_bits t = 5 - t.count - Bool.to_int t.optional
end

module Program = struct
  type t =
    { name : string
    ; side_set : Side_set.t
    ; instructions : Instruction.t array
    ; wrap_target : int
    ; wrap : int
    ; clock_div : float option
    ; labels : (string * int) list
    }
  [@@deriving sexp_of]
end

let tokenize line =
  let n = String.length line in
  let is_word c = Char.is_alphanum c || Char.equal c '_' || Char.equal c '.' in
  let rec go i acc =
    if i >= n
    then List.rev acc
    else (
      let c = line.[i] in
      let two = if i + 1 < n then String.sub line ~pos:i ~len:2 else "" in
      if Char.is_whitespace c
      then go (i + 1) acc
      else if List.mem [ "::"; "--"; "!=" ] two ~equal:String.equal
      then go (i + 2) (two :: acc)
      else if is_word c
      then (
        let j = ref i in
        while !j < n && is_word line.[!j] do
          incr j
        done;
        go !j (String.sub line ~pos:i ~len:(!j - i) :: acc))
      else go (i + 1) (String.of_char c :: acc))
  in
  go 0 []
;;

let strip_comment line =
  let cut line sep =
    match String.substr_index line ~pattern:sep with
    | Some i -> String.prefix line i
    | None -> line
  in
  cut (cut line ";") "//" |> String.strip
;;

let keyword token = String.lowercase token

(* Recursive descent over [+ - * /], parentheses and names. *)
let eval ~lookup tokens =
  let rec expr tokens =
    let%bind.Or_error value, rest = term tokens in
    sum value rest
  and sum value = function
    | "+" :: rest ->
      let%bind.Or_error b, rest = term rest in
      sum (value + b) rest
    | "-" :: rest ->
      let%bind.Or_error b, rest = term rest in
      sum (value - b) rest
    | rest -> Ok (value, rest)
  and term tokens =
    let%bind.Or_error value, rest = unary tokens in
    product value rest
  and product value = function
    | "*" :: rest ->
      let%bind.Or_error b, rest = unary rest in
      product (value * b) rest
    | "/" :: rest ->
      let%bind.Or_error b, rest = unary rest in
      if b = 0 then Or_error.error_string "division by zero" else product (value / b) rest
    | rest -> Ok (value, rest)
  and unary = function
    | "-" :: rest ->
      let%map.Or_error value, rest = unary rest in
      -value, rest
    | "(" :: rest ->
      let%bind.Or_error value, rest = expr rest in
      (match rest with
       | ")" :: rest -> Ok (value, rest)
       | _ -> Or_error.error_string "missing )")
    | token :: rest ->
      (match Int.of_string_opt token with
       | Some value -> Ok (value, rest)
       | None ->
         (match lookup token with
          | Some value -> Ok (value, rest)
          | None -> Or_error.error_s [%message "unknown name" (token : string)]))
    | [] -> Or_error.error_string "missing value"
  in
  match%bind.Or_error expr tokens with
  | value, [] -> Ok value
  | _, rest -> Or_error.error_s [%message "trailing tokens" (rest : string list)]
;;

let source token : Source.t Or_error.t =
  match keyword token with
  | "pins" -> Ok Pins
  | "x" -> Ok X
  | "y" -> Ok Y
  | "null" -> Ok Null
  | "status" -> Ok Status
  | "isr" -> Ok Isr
  | "osr" -> Ok Osr
  | _ -> Or_error.error_s [%message "bad source" (token : string)]
;;

let destination token : Destination.t Or_error.t =
  match keyword token with
  | "pins" -> Ok Pins
  | "x" -> Ok X
  | "y" -> Ok Y
  | "null" -> Ok Null
  | "pindirs" -> Ok Pindirs
  | "pc" -> Ok Pc
  | "isr" -> Ok Isr
  | "osr" -> Ok Osr
  | "exec" -> Ok Exec
  | _ -> Or_error.error_s [%message "bad destination" (token : string)]
;;

let split_modifiers tokens =
  List.split_while tokens ~f:(fun token ->
    not
      (List.mem
         [ "side"; "sideset"; "side_set"; "[" ]
         (keyword token)
         ~equal:String.equal))
;;

(* [side e] and [[e]] in either order. *)
let rec modifiers ~eval ~side ~delay = function
  | [] -> Ok (side, delay)
  | "[" :: rest ->
    (match List.split_while rest ~f:(fun token -> not (String.equal token "]")) with
     | inside, "]" :: rest ->
       let%bind.Or_error value = eval inside in
       modifiers ~eval ~side ~delay:value rest
     | _ -> Or_error.error_string "missing ]")
  | token :: rest
    when List.mem [ "side"; "sideset"; "side_set" ] (keyword token) ~equal:String.equal ->
    let value, rest =
      List.split_while rest ~f:(fun token -> not (String.equal token "["))
    in
    let%bind.Or_error value = eval value in
    modifiers ~eval ~side:(Some value) ~delay rest
  | tokens -> Or_error.error_s [%message "unexpected" (tokens : string list)]
;;

let parse_op ~eval ~label operands : Op.t Or_error.t =
  let operands = List.filter operands ~f:(fun token -> not (String.equal token ",")) in
  match operands with
  | [] -> Or_error.error_string "empty instruction"
  | mnemonic :: args ->
    (match keyword mnemonic, List.map args ~f:keyword with
     | "nop", [] -> Ok (Mov { destination = Y; op = Copy; source = Y })
     | "jmp", keywords ->
       let (condition : Condition.t), rest =
         match keywords with
         | "!" :: "x" :: _ -> X_zero, List.drop args 2
         | "x" :: "--" :: _ -> X_post_decrement, List.drop args 2
         | "!" :: "y" :: _ -> Y_zero, List.drop args 2
         | "y" :: "--" :: _ -> Y_post_decrement, List.drop args 2
         | "x" :: "!=" :: "y" :: _ -> X_not_y, List.drop args 3
         | "pin" :: _ -> Pin, List.drop args 1
         | "!" :: "osre" :: _ -> Osr_not_empty, List.drop args 2
         | _ -> Always, args
       in
       let%map.Or_error target =
         match rest with
         | [ name ] when Option.is_some (label name) -> Ok (Option.value_exn (label name))
         | tokens -> eval tokens
       in
       Op.Jmp { condition; target }
     | "wait", keywords ->
       let polarity, rest, keywords =
         match keywords with
         | ("gpio" | "pin" | "irq" | "jmppin") :: _ -> Ok 1, args, keywords
         | _ -> eval (List.take args 1), List.drop args 1, List.drop keywords 1
       in
       let%bind.Or_error polarity in
       let without_rel tokens =
         List.filter tokens ~f:(fun token -> not (String.equal (keyword token) "rel"))
       in
       let%map.Or_error source =
         match keywords, rest with
         | "gpio" :: _, _ :: index ->
           let%map.Or_error index = eval index in
           Wait_source.Gpio index
         | "pin" :: _, _ :: index ->
           let%map.Or_error index = eval index in
           Wait_source.Pin index
         | "irq" :: _, _ :: index ->
           let%map.Or_error index = eval (without_rel index) in
           Wait_source.Irq index
         | "jmppin" :: _, _ -> Ok Wait_source.Jmp_pin
         | _ -> Or_error.error_s [%message "bad wait" (args : string list)]
       in
       Op.Wait { polarity = polarity <> 0; source }
     | "in", _ ->
       (match args with
        | first :: bits ->
          let%bind.Or_error source = source first in
          let%map.Or_error bits = eval bits in
          Op.In { source; bits }
        | [] -> Or_error.error_string "in needs a source")
     | "out", _ ->
       (match args with
        | first :: bits ->
          let%bind.Or_error destination = destination first in
          let%map.Or_error bits = eval bits in
          Op.Out { destination; bits }
        | [] -> Or_error.error_string "out needs a destination")
     | "push", keywords ->
       Ok
         (Op.Push
            { if_full = List.mem keywords "iffull" ~equal:String.equal
            ; block = not (List.mem keywords "noblock" ~equal:String.equal)
            })
     | "pull", keywords ->
       Ok
         (Op.Pull
            { if_empty = List.mem keywords "ifempty" ~equal:String.equal
            ; block = not (List.mem keywords "noblock" ~equal:String.equal)
            })
     | "mov", _ ->
       (match args with
        | first :: rest ->
          let%bind.Or_error destination = destination first in
          let (op : Mov_op.t), rest =
            match rest with
            | ("!" | "~") :: rest -> Invert, rest
            | "::" :: rest -> Reverse, rest
            | rest -> Copy, rest
          in
          (match rest with
           | [ token ] ->
             let%map.Or_error source = source token in
             Op.Mov { destination; op; source }
           | _ -> Or_error.error_s [%message "bad mov" (args : string list)])
        | [] -> Or_error.error_string "mov needs operands")
     | "irq", keywords ->
       let (mode : Irq_mode.t), rest =
         match keywords with
         | ("set" | "nowait") :: _ -> Raise, List.drop args 1
         | "wait" :: _ -> Raise_and_wait, List.drop args 1
         | "clear" :: _ -> Clear, List.drop args 1
         | _ -> Raise, args
       in
       let rest =
         List.filter rest ~f:(fun token -> not (String.equal (keyword token) "rel"))
       in
       let%map.Or_error index = eval rest in
       Op.Irq { mode; index }
     | "set", _ ->
       (match args with
        | first :: value ->
          let%bind.Or_error destination = destination first in
          let%map.Or_error value = eval value in
          Op.Set { destination; value }
        | [] -> Or_error.error_string "set needs a destination")
     | _ -> Or_error.error_s [%message "unknown instruction" (mnemonic : string)])
;;

let check_fields (side_set : Side_set.t) ({ op; delay; side; text } : Instruction.t) =
  let max_delay = (1 lsl Side_set.delay_bits side_set) - 1 in
  let%bind.Or_error () =
    if delay < 0 || delay > max_delay
    then Or_error.error_s [%message "delay out of range" (delay : int) (max_delay : int)]
    else Ok ()
  in
  let%bind.Or_error () =
    match side with
    | None when side_set.count > 0 && not side_set.optional ->
      Or_error.error_s [%message "side-set is not optional" (text : string)]
    | Some _ when side_set.count = 0 -> Or_error.error_string "no .side_set declared"
    | Some value when value < 0 || value >= 1 lsl side_set.count ->
      Or_error.error_s [%message "side-set value out of range" (value : int)]
    | None | Some _ -> Ok ()
  in
  match op with
  | Set { value; _ } when value < 0 || value > 31 ->
    Or_error.error_s [%message "set value out of range" (value : int)]
  | (In { bits; _ } | Out { bits; _ }) when bits < 1 || bits > 32 ->
    Or_error.error_s [%message "bit count out of range" (bits : int)]
  | _ -> Ok ()
;;

let join_tokens tokens =
  let glued_before = [ ","; "]"; ")"; "--"; "!=" ] in
  let glued_after = [ "["; "("; "!"; "~"; "::"; "!=" ] in
  List.fold tokens ~init:(None, "") ~f:(fun (previous, text) token ->
    let space =
      match previous with
      | None -> ""
      | Some previous
        when List.mem glued_before token ~equal:String.equal
             || List.mem glued_after previous ~equal:String.equal -> ""
      | Some _ -> " "
    in
    Some token, text ^ space ^ token)
  |> snd
;;

let instruction_of_tokens ~side_set ~eval ~label tokens =
  let operands, rest = split_modifiers tokens in
  let%bind.Or_error side, delay = modifiers ~eval ~side:None ~delay:0 rest in
  let%bind.Or_error op = parse_op ~eval ~label operands in
  let instruction = { Instruction.op; delay; side; text = join_tokens tokens } in
  let%map.Or_error () = check_fields side_set instruction in
  instruction
;;

(* A line after comments are stripped, with any leading label split off. *)
module Line = struct
  type t =
    { number : int
    ; label : string option
    ; body : string list
    }
end

let split_label tokens =
  match tokens with
  | public :: name :: ":" :: rest when String.equal (keyword public) "public" ->
    Some name, rest
  | name :: ":" :: rest -> Some name, rest
  | tokens -> None, tokens
;;

type draft =
  { name : string
  ; mutable side_set : Side_set.t
  ; mutable lines : Line.t list
  ; mutable wrap_target : int option
  ; mutable wrap : int option
  ; mutable clock_div : float option
  ; defines : (string, int) Hashtbl.t
  ; mutable count : int
  }

let error_at number error = Or_error.tag error ~tag:[%string "line %{number#Int}"]

let parse text =
  let globals = Hashtbl.create (module String) in
  let drafts = ref [] in
  let in_c_block = ref false in
  let current () =
    match !drafts with
    | draft :: _ -> Ok draft
    | [] -> Or_error.error_string "instruction before .program"
  in
  let lookup draft token =
    match Hashtbl.find draft.defines token with
    | Some _ as value -> value
    | None -> Hashtbl.find globals token
  in
  let directive ~number tokens =
    let defines () =
      match !drafts with
      | draft :: _ -> draft.defines
      | [] -> globals
    in
    let define name value =
      let%map.Or_error value =
        match !drafts with
        | draft :: _ -> eval ~lookup:(lookup draft) value
        | [] -> eval ~lookup:(Hashtbl.find globals) value
      in
      Hashtbl.set (defines ()) ~key:name ~data:value
    in
    match tokens with
    | [] -> Ok ()
    | first :: rest ->
      error_at
        number
        (match keyword first, rest with
         | ".program", [ name ] ->
           drafts
           := { name
              ; side_set = Side_set.none
              ; lines = []
              ; wrap_target = None
              ; wrap = None
              ; clock_div = None
              ; defines = Hashtbl.create (module String)
              ; count = 0
              }
              :: !drafts;
           Ok ()
         | ".define", public :: name :: value when String.equal (keyword public) "public"
           -> define name value
         | ".define", name :: value -> define name value
         | ".side_set", count :: flags ->
           let%bind.Or_error draft = current () in
           let%map.Or_error count = eval ~lookup:(lookup draft) [ count ] in
           let flags = List.map flags ~f:keyword in
           draft.side_set
           <- { count
              ; optional = List.mem flags "opt" ~equal:String.equal
              ; pindirs = List.mem flags "pindirs" ~equal:String.equal
              }
         | ".wrap_target", [] ->
           let%map.Or_error draft = current () in
           draft.wrap_target <- Some draft.count
         | ".wrap", [] ->
           let%map.Or_error draft = current () in
           draft.wrap <- Some (draft.count - 1)
         | ".clock_div", value ->
           let%bind.Or_error draft = current () in
           (match Float.of_string_opt (String.concat value) with
            | Some value ->
              draft.clock_div <- Some value;
              Ok ()
            | None -> Or_error.error_string "bad .clock_div")
         | ( ( ".pio_version"
             | ".lang_opt"
             | ".origin"
             | ".in"
             | ".out"
             | ".set"
             | ".fifo"
             | ".mov_status" )
           , _ ) -> Ok ()
         | _ -> Or_error.error_s [%message "unsupported directive" (first : string)])
  in
  let%bind.Or_error () =
    String.split_lines text
    |> List.mapi ~f:(fun i line -> i + 1, line)
    |> List.map ~f:(fun (number, line) ->
      if !in_c_block
      then (
        if String.is_prefix (String.strip line) ~prefix:"%}" then in_c_block := false;
        Ok ())
      else if String.is_prefix (String.lstrip line) ~prefix:"%"
      then (
        in_c_block := true;
        Ok ())
      else (
        match tokenize (strip_comment line) with
        | [] -> Ok ()
        | first :: _ as tokens when String.is_prefix first ~prefix:"." ->
          directive ~number tokens
        | tokens ->
          let label, body = split_label tokens in
          let%map.Or_error draft = current () |> error_at number in
          draft.lines <- { Line.number; label; body } :: draft.lines;
          if not (List.is_empty body) then draft.count <- draft.count + 1))
    |> Or_error.all_unit
  in
  List.rev !drafts
  |> List.map ~f:(fun draft ->
    let lines = List.rev draft.lines in
    let labels =
      List.fold lines ~init:(0, []) ~f:(fun (address, labels) line ->
        let labels =
          match line.label with
          | Some name -> (name, address) :: labels
          | None -> labels
        in
        (if List.is_empty line.body then address else address + 1), labels)
      |> snd
      |> List.rev
    in
    let label name = List.Assoc.find labels name ~equal:String.equal in
    let%bind.Or_error instructions =
      List.filter lines ~f:(fun line -> not (List.is_empty line.body))
      |> List.map ~f:(fun line ->
        instruction_of_tokens
          ~side_set:draft.side_set
          ~eval:
            (eval ~lookup:(fun token ->
               match lookup draft token with
               | Some _ as value -> value
               | None -> label token))
          ~label
          line.body
        |> error_at line.number)
      |> Or_error.all
    in
    let instructions = Array.of_list instructions in
    let count = Array.length instructions in
    let%bind.Or_error () =
      if count = 0 || count > 32
      then Or_error.error_s [%message "program length" draft.name (count : int)]
      else Ok ()
    in
    let%map.Or_error () =
      Array.to_list instructions
      |> List.map ~f:(fun (instruction : Instruction.t) ->
        match instruction.op with
        | Jmp { target; _ } when target < 0 || target >= count ->
          Or_error.error_s [%message "jmp target out of range" instruction.text]
        | _ -> Ok ())
      |> Or_error.all_unit
    in
    { Program.name = draft.name
    ; side_set = draft.side_set
    ; instructions
    ; wrap_target = Option.value draft.wrap_target ~default:0
    ; wrap = Option.value draft.wrap ~default:(count - 1)
    ; clock_div = draft.clock_div
    ; labels
    })
  |> Or_error.all
;;

let parse_instruction (program : Program.t) line =
  let label name = List.Assoc.find program.labels name ~equal:String.equal in
  instruction_of_tokens
    ~side_set:program.side_set
    ~eval:(eval ~lookup:label)
    ~label
    (tokenize (strip_comment line))
;;
