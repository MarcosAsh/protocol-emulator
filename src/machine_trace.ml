open! Core

let pin_name pin =
  if pin < Isa.first_output_pin
  then sprintf "IN%d" pin
  else if pin < Isa.first_bidir_pin
  then sprintf "OUT%d" (pin - Isa.first_output_pin)
  else if pin < Isa.num_pins
  then sprintf "IO%d" (pin - Isa.first_bidir_pin)
  else sprintf "W%d" (pin - Isa.num_pins)
;;

let all_pins = List.init Isa.pin_space ~f:Fn.id

let pin_of_string text =
  match
    List.find all_pins ~f:(fun pin -> String.equal (pin_name pin) (String.uppercase text))
  with
  | Some pin -> pin
  | None ->
    (match Int.of_string_opt text with
     | Some pin when pin >= 0 && pin < Isa.pin_space -> pin
     | _ -> raise_s [%message "no such pin" (text : string)])
;;

(* [TEXT] or [TEXT@CYCLE] *)
let at text =
  match String.lsplit2 text ~on:'@' with
  | None -> text, 0
  | Some (text, cycle) ->
    let cycle = Int.of_string cycle in
    if cycle < 0 then raise_s [%message "negative cycle" (cycle : int)];
    text, cycle
;;

module Input = struct
  type t =
    { pin : int
    ; level : bool
    ; cycle : int
    }
  [@@deriving sexp_of]

  let of_string text =
    let pin_level, cycle = at text in
    match String.lsplit2 pin_level ~on:'=' with
    | Some (pin, (("0" | "1") as level)) ->
      let pin = pin_of_string pin in
      if pin >= Isa.first_output_pin && pin < Isa.first_bidir_pin
      then raise_s [%message "only the core drives an output pin" (text : string)];
      { pin; level = String.equal level "1"; cycle }
    | _ -> raise_s [%message "expected PIN=LEVEL or PIN=LEVEL@CYCLE" (text : string)]
  ;;
end

module Tx = struct
  type t =
    { word : int
    ; cycle : int
    }
  [@@deriving sexp_of]

  let of_string text =
    let word, cycle = at text in
    let word = Int.of_string word in
    if word < 0 || word >= 1 lsl Isa.data_bits
    then raise_s [%message "not a 16-bit word" (text : string)];
    { word; cycle }
  ;;
end

module Fault_set = struct
  type t =
    { name : string
    ; cycle : int
    ; pc : int
    }
end

type t =
  { levels : int array
  ; shown : int list
  ; rx : (int * int) list (** Each word with the cycle it was pushed. *)
  ; queued : int
  ; faults : Fault_set.t list
  ; halted : (int * int) option (** The cycle and pc that halted the core. *)
  }

let level t ~pin ~cycle = (t.levels.(cycle) lsr pin) land 1 = 1

let fault_names { Machine.Fault.underflow; overflow; missed_deadline; decode } =
  List.filter_map
    [ "underflow", underflow
    ; "overflow", overflow
    ; "missed_deadline", missed_deadline
    ; "decode", decode
    ]
    ~f:(fun (name, set) -> Option.some_if set name)
;;

(* the host writes in order, stopping at the first word not yet due or with no room *)
let rec write_tx machine (tx : Tx.t list) ~cycle =
  match tx with
  | word :: rest when word.cycle <= cycle ->
    (match Machine.write_tx machine word.word with
     | Ok machine -> write_tx machine rest ~cycle
     | Error _ -> machine, tx)
  | _ -> machine, tx
;;

let rec read_rx machine ~cycle rx =
  match Machine.read_rx machine with
  | None -> machine, rx
  | Some (word, machine) -> read_rx machine ~cycle ((word, cycle) :: rx)
;;

let run machine ~cycles ~tx ~(inputs : Input.t list) =
  if cycles <= 0 then raise_s [%message "cycles must be positive" (cycles : int)];
  let levels = Array.create ~len:cycles 0 in
  let input_at cycle =
    List.filter inputs ~f:(fun input -> input.cycle <= cycle)
    |> List.stable_sort ~compare:(fun (a : Input.t) b -> Int.compare a.cycle b.cycle)
    |> List.fold ~init:0 ~f:(fun level (input : Input.t) ->
      if input.level
      then level lor (1 lsl input.pin)
      else level land lnot (1 lsl input.pin))
  in
  let machine, tx, rx, faults, halted =
    List.fold
      (List.range 0 cycles)
      ~init:(machine, tx, [], [], None)
      ~f:(fun (machine, tx, rx, faults, halted) cycle ->
        let machine, tx = write_tx machine tx ~cycle in
        let inputs = input_at cycle in
        let next = Machine.step machine ~inputs in
        levels.(cycle) <- Machine.pins next ~inputs;
        let faults =
          List.filter (fault_names next.fault) ~f:(fun name ->
            not (List.mem (fault_names machine.fault) name ~equal:String.equal))
          |> List.map ~f:(fun name -> { Fault_set.name; cycle; pc = machine.pc })
          |> List.append faults
        in
        let halted =
          match halted with
          | None when next.halted && not machine.halted -> Some (cycle, machine.pc)
          | halted -> halted
        in
        let next, rx = read_rx next ~cycle rx in
        next, tx, rx, faults, halted)
  in
  let driven = List.map inputs ~f:(fun input -> input.pin) in
  let shown =
    List.filter all_pins ~f:(fun pin ->
      List.mem driven pin ~equal:Int.equal
      || Array.exists levels ~f:(fun levels -> (levels lsr pin) land 1 = 1))
  in
  { levels
  ; shown
  ; rx = List.rev rx
  ; queued = List.length machine.tx_fifo + List.length tx
  ; faults
  ; halted
  }
;;

let faulted t = not (List.is_empty t.faults)
let columns = 64
let width = 88
let edges_shown = 32

let strip t ~pin ~scale =
  String.init
    ((Array.length t.levels + scale - 1) / scale)
    ~f:(fun column ->
      let cycles =
        List.range
          (column * scale)
          (Int.min (Array.length t.levels) ((column + 1) * scale))
      in
      match List.map cycles ~f:(fun cycle -> level t ~pin ~cycle) with
      | levels when List.for_all levels ~f:Fn.id -> '-'
      | levels when List.for_all levels ~f:not -> '_'
      | _ -> '|')
;;

(* "starts low, rise 1, fall 6 +5, ...", wrapped *)
let edges t ~pin =
  let edges =
    List.filter
      (List.range 1 (Array.length t.levels))
      ~f:(fun cycle ->
        Bool.( <> ) (level t ~pin ~cycle) (level t ~pin ~cycle:(cycle - 1)))
  in
  let words =
    ((if level t ~pin ~cycle:0 then "starts high" else "starts low")
     :: List.folding_map (List.take edges edges_shown) ~init:None ~f:(fun last cycle ->
       let edge = if level t ~pin ~cycle then "rise" else "fall" in
       ( Some cycle
       , match last with
         | None -> sprintf "%s %d" edge cycle
         | Some last -> sprintf "%s %d +%d" edge cycle (cycle - last) )))
    @
    if List.length edges > edges_shown
    then [ sprintf "and %d more" (List.length edges - edges_shown) ]
    else []
  in
  let indent = String.make 6 ' ' in
  List.fold words ~init:[] ~f:(fun lines word ->
    match lines with
    | line :: rest when String.length line + String.length word + 2 <= width ->
      (line ^ ", " ^ word) :: rest
    | [] -> [ sprintf "%-6s%s" (pin_name pin) word ]
    | line :: rest -> (indent ^ word) :: (line ^ ",") :: rest)
  |> List.rev
;;

let to_string t =
  let cycles = Array.length t.levels in
  let scale = (cycles + columns - 1) / columns in
  let header =
    sprintf
      "cycles 0 to %d, %s: _ low, - high, | both"
      (cycles - 1)
      (if scale = 1 then "one a column" else sprintf "%d a column" scale)
  in
  let strips =
    List.map t.shown ~f:(fun pin -> sprintf "%-6s%s" (pin_name pin) (strip t ~pin ~scale))
  in
  let rx =
    if List.is_empty t.rx
    then "rx: empty"
    else
      "rx: "
      ^ String.concat
          ~sep:", "
          (List.map t.rx ~f:(fun (word, cycle) -> sprintf "%04x at %d" word cycle))
  in
  let queued =
    if t.queued = 0 then [] else [ sprintf "tx: %d words never pulled" t.queued ]
  in
  let faults =
    match t.faults with
    | [] -> [ "faults: none" ]
    | faults ->
      List.map faults ~f:(fun { name; cycle; pc } ->
        sprintf "fault %s at cycle %d, pc %d" name cycle pc)
  in
  let halted =
    Option.value_map t.halted ~default:[] ~f:(fun (cycle, pc) ->
      [ sprintf "halted at cycle %d, pc %d" cycle pc ])
  in
  List.concat
    [ [ header ]
    ; strips
    ; [ "" ]
    ; List.concat_map t.shown ~f:(fun pin -> edges t ~pin)
    ; [ ""; rx ]
    ; queued
    ; faults
    ; halted
    ]
  |> String.concat_lines
;;

let ns_per_cycle = 20

let to_vcd t =
  let id i = Char.of_int_exn (Char.to_int '!' + i) |> String.of_char in
  let pins = List.mapi t.shown ~f:(fun i pin -> id i, pin) in
  let value ~cycle (id, pin) = sprintf "%d%s" (Bool.to_int (level t ~pin ~cycle)) id in
  let changes =
    List.concat_map
      (List.range 1 (Array.length t.levels))
      ~f:(fun cycle ->
        match
          List.filter pins ~f:(fun (_, pin) ->
            Bool.( <> ) (level t ~pin ~cycle) (level t ~pin ~cycle:(cycle - 1)))
        with
        | [] -> []
        | changed ->
          sprintf "#%d" (cycle * ns_per_cycle) :: List.map changed ~f:(value ~cycle))
  in
  List.concat
    [ [ "$timescale 1ns $end"; "$scope module core $end" ]
    ; List.map pins ~f:(fun (id, pin) ->
        sprintf "$var wire 1 %s %s $end" id (pin_name pin))
    ; [ "$upscope $end"; "$enddefinitions $end"; "#0" ]
    ; List.map pins ~f:(value ~cycle:0)
    ; changes
    ; [ sprintf "#%d" (Array.length t.levels * ns_per_cycle) ]
    ]
  |> String.concat_lines
;;
