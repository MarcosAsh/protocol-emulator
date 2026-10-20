open! Core
open Timing

type t =
  { program : string option
  ; pins : string list
  ; initials : string list
  ; rules : string list
  ; autopull : bool
  ; autopush : bool
  ; fifo_ready : bool
  ; irq_wait_halts : bool
  ; set_count : int
  ; out_count : int
  ; exec : string list
  ; sys_hz : float option
  ; clkdiv : float option
  ; cell : int option
  ; entry : string option
  ; no_stretch : string list
  }
[@@deriving sexp_of]

let default =
  { program = None
  ; pins = []
  ; initials = []
  ; rules = []
  ; autopull = false
  ; autopush = false
  ; fifo_ready = false
  ; irq_wait_halts = false
  ; set_count = 1
  ; out_count = 1
  ; exec = []
  ; sys_hz = None
  ; clkdiv = None
  ; cell = None
  ; entry = None
  ; no_stretch = []
  }
;;

let add t line =
  let open Or_error.Let_syntax in
  let flag, value =
    match String.lfindi line ~f:(fun _ char -> Char.is_whitespace char) with
    | None -> line, None
    | Some i -> String.prefix line i, Some (String.strip (String.drop_prefix line i))
  in
  let error reason = Or_error.error_s [%message reason (line : string)] in
  let text () =
    match value with
    | Some value -> Ok value
    | None -> error "needs a value"
  in
  let number of_string =
    let%bind value = text () in
    match Option.try_with (fun () -> of_string value) with
    | Some number -> Ok number
    | None -> error "not a number"
  in
  let switch () =
    match value with
    | None -> Ok true
    | Some _ -> error "takes no value"
  in
  match flag with
  | "program" -> text () >>| fun program -> { t with program = Some program }
  | "pin" -> text () >>| fun pin -> { t with pins = t.pins @ [ pin ] }
  | "init" -> text () >>| fun init -> { t with initials = t.initials @ [ init ] }
  | "rule" -> text () >>| fun rule -> { t with rules = t.rules @ [ rule ] }
  | "exec" -> text () >>| fun exec -> { t with exec = t.exec @ [ exec ] }
  | "no-stretch" -> text () >>| fun pin -> { t with no_stretch = t.no_stretch @ [ pin ] }
  | "entry" -> text () >>| fun entry -> { t with entry = Some entry }
  | "autopull" -> switch () >>| fun autopull -> { t with autopull }
  | "autopush" -> switch () >>| fun autopush -> { t with autopush }
  | "fifo-ready" -> switch () >>| fun fifo_ready -> { t with fifo_ready }
  | "irq-wait-halts" -> switch () >>| fun irq_wait_halts -> { t with irq_wait_halts }
  | "set-count" -> number Int.of_string >>| fun set_count -> { t with set_count }
  | "out-count" -> number Int.of_string >>| fun out_count -> { t with out_count }
  | "cell" -> number Int.of_string >>| fun cell -> { t with cell = Some cell }
  | "sys-hz" -> number Float.of_string >>| fun hz -> { t with sys_hz = Some hz }
  | "clkdiv" -> number Float.of_string >>| fun div -> { t with clkdiv = Some div }
  | _ -> error "unknown flag"
;;

let of_string ?(base = default) text =
  String.split_lines text
  |> List.filter_map ~f:(fun line ->
    let line =
      String.lsplit2 line ~on:'#' |> Option.value_map ~default:line ~f:fst |> String.strip
    in
    Option.some_if (not (String.is_empty line)) line)
  |> List.fold_result ~init:base ~f:add
;;

let select t programs =
  match
    List.filter programs ~f:(fun (program : Pioasm.Program.t) ->
      Option.value_map t.program ~default:true ~f:(String.equal program.name))
  with
  | [] -> Or_error.error_string "no program to check"
  | programs -> Ok programs
;;

let initial text =
  match String.lsplit2 text ~on:'=' with
  | Some (name, "0") -> Ok (name, false)
  | Some (name, "1") -> Ok (name, true)
  | _ -> Or_error.error_s [%message "expected name=0 or name=1" (text : string)]
;;

let configure t =
  let open Or_error.Let_syntax in
  let%bind pins = List.map t.pins ~f:Pin.of_string |> Or_error.all in
  let%bind initials = List.map t.initials ~f:initial |> Or_error.all in
  let%bind () =
    match
      List.find initials ~f:(fun (name, _) ->
        not (List.exists pins ~f:(fun (pin : Pin.t) -> String.equal pin.name name)))
    with
    | Some (name, _) -> Or_error.error_s [%message "init of no pin" (name : string)]
    | None -> Ok ()
  in
  let pins =
    List.map pins ~f:(fun pin ->
      { pin with initial = List.Assoc.find initials pin.name ~equal:String.equal })
  in
  let%bind rules = List.map t.rules ~f:Rule.of_string |> Or_error.all in
  let check ok message = if ok then Ok () else Or_error.error_string message in
  let%bind () =
    Or_error.all_unit
      [ check
          (Option.for_all t.sys_hz ~f:(fun hz -> Float.( > ) hz 0.))
          "sys-hz must be > 0"
      ; check
          (Option.for_all t.clkdiv ~f:(fun div ->
             Float.( >= ) div 1. && Float.( <= ) div 65536.))
          "clkdiv must be in 1..65536"
      ; check (Option.for_all t.cell ~f:(fun cell -> cell > 0)) "cell must be > 0"
      ; check (0 <= t.set_count && t.set_count <= 5) "set-count must be in 0..5"
      ; check (0 <= t.out_count && t.out_count <= 32) "out-count must be in 0..32"
      ; check
          (Option.is_some t.sys_hz
           || List.for_all rules ~f:(fun (rule : Rule.t) ->
             match rule.at_least with
             | Cycles _ -> true
             | Ns _ -> false))
          "a rule in ns or us needs sys-hz"
      ]
  in
  return (fun (program : Pioasm.Program.t) ->
    let%map exec = List.map t.exec ~f:(Exec_sequence.of_string program) |> Or_error.all in
    { Config.pins
    ; autopull = t.autopull
    ; autopush = t.autopush
    ; fifo_ready = t.fifo_ready
    ; irq_wait_halts = t.irq_wait_halts
    ; set_count = t.set_count
    ; out_count = t.out_count
    ; exec
    ; clock =
        Option.map t.sys_hz ~f:(fun sys_hz ->
          { Clock.sys_hz
          ; clkdiv =
              Option.first_some t.clkdiv program.clock_div |> Option.value ~default:1.
          })
    ; rules
    ; cell = t.cell
    ; entry = t.entry
    ; no_stretch = t.no_stretch
    })
;;
