open! Core
open Protocol_emulator

module Setup = struct
  module Exec = struct
    type t =
      { instruction : string
      ; from_sides : int list
      }
    [@@deriving sexp_of]
  end

  type t =
    { period : int
    ; fraction : int
    ; per_cycle : int
    ; side_set_base : int
    ; set_base : int
    ; set_count : int
    ; out_base : int
    ; out_count : int
    ; in_base : int
    ; in_count : int
    ; jmp_pin : int
    ; out_shift_right : bool
    ; in_shift_right : bool
    ; autopull : bool
    ; pull_threshold : int
    ; autopush : bool
    ; push_threshold : int
    ; side_init : int
    ; dirs_inverted : bool
    ; exec : Exec.t list
    ; init : string list
    ; entry : string option
    }
  [@@deriving sexp_of]

  let bits_for value = Int.max 1 (Int.ceil_log2 (value + 1))

  let default (program : Pioasm.Program.t) ~period =
    let ops =
      Array.to_list program.instructions |> List.map ~f:(fun i -> i.Pioasm.Instruction.op)
    in
    let max_of f = List.fold ops ~init:0 ~f:(fun acc op -> Int.max acc (f op)) in
    let any f = List.exists ops ~f in
    let set_count =
      max_of (function
        | Set { destination = Pins | Pindirs; value } -> bits_for value
        | _ -> 0)
      |> Int.clamp_exn ~min:1 ~max:5
    in
    let out_count =
      max_of (function
        | Out { destination = Pins | Pindirs; bits } -> bits
        | _ -> 0)
      |> Int.clamp_exn ~min:1 ~max:Isa.data_bits
    in
    let in_count =
      max_of (function
        | In { source = Pins; bits } -> bits
        | Wait { source = Pin n; _ } -> n + 1
        | _ -> 0)
      |> Int.clamp_exn ~min:1 ~max:Isa.data_bits
    in
    let set_dirs =
      any (function
        | Set { destination = Pindirs; _ } -> true
        | _ -> false)
    in
    let out_dirs =
      any (function
        | Out { destination = Pindirs; _ } | Mov { destination = Pindirs; _ } -> true
        | _ -> false)
    in
    (* written by direction on IO pins, by level on OUT pins, read on IN pins *)
    let next_out = ref Isa.first_output_pin
    and next_io = ref Isa.first_bidir_pin in
    let take ~dirs count =
      let next = if dirs then next_io else next_out in
      let base = !next in
      next := base + count;
      base
    in
    let side_set_base =
      take ~dirs:program.side_set.pindirs (Int.max 1 program.side_set.count)
    in
    let used f = if any f then Fn.id else fun _ -> 0 in
    let set_base =
      take
        ~dirs:set_dirs
        (used
           (function
             | Set { destination = Pins | Pindirs; _ } -> true
             | _ -> false)
           set_count)
    in
    let out_base =
      take
        ~dirs:out_dirs
        (used
           (function
             | Out { destination = Pins | Pindirs; _ }
             | Mov { destination = Pins | Pindirs; _ } -> true
             | _ -> false)
           out_count)
    in
    let in_base = 0 in
    { period
    ; fraction = 0
    ; per_cycle = 1
    ; side_set_base
    ; set_base
    ; set_count
    ; out_base
    ; out_count
    ; in_base
    ; in_count
    ; jmp_pin = in_base
    ; out_shift_right = true
    ; in_shift_right = true
    ; autopull = false
    ; pull_threshold = 32
    ; autopush = false
    ; push_threshold = 32
    ; side_init = 0
    ; dirs_inverted = false
    ; exec = []
    ; init = []
    ; entry = None
    }
  ;;
end

module Refusal = struct
  type t =
    { pc : int option
    ; feature : string
    }
  [@@deriving sexp_of, compare]
end

type t =
  { source : string
  ; words : Isa.t list
  ; config : Program_config.t
  ; relation : Relation.t
  ; exec : Pioasm.Instruction.t array
  ; contract : string list
  }

(* The features the core cannot keep, by instruction. *)
let refused ~(setup : Setup.t) ~in_exec (instruction : Pioasm.Instruction.t) =
  let width bits = sprintf "%d-bit shift" bits in
  match instruction.op with
  | Jmp _ | Set _ -> []
  | Wait { source = Irq _; _ } -> [ "wait irq" ]
  | Wait { source = Gpio _; _ } -> [ "wait gpio" ]
  | Wait _ -> []
  | In { source = Status; _ } -> [ "in status" ]
  | In { bits; _ } -> if bits > Isa.data_bits then [ width bits ] else []
  | Out { destination = Pc; _ } -> [ "out pc" ]
  | Out { destination = Exec; bits } ->
    if in_exec
    then [ "out exec from an exec'd instruction" ]
    else if List.is_empty setup.exec
    then [ "out exec without an exec table" ]
    else if bits <> 16
    then [ width bits ^ " out exec" ]
    else []
  | Out { destination = Null; bits = 32 } -> []
  | Out { bits; _ } -> if bits > Isa.data_bits then [ width bits ] else []
  | Push { if_full = true; _ } -> [ "push iffull" ]
  | Push _ -> []
  | Pull { if_empty = true; block = false } -> [ "pull ifempty noblock" ]
  | Pull { if_empty = false; _ } when setup.autopull -> [ "pull with autopull" ]
  | Pull _ -> []
  | Mov { destination; op; source } ->
    List.filter_opt
      [ (match destination with
         | Pc -> Some "mov pc"
         | Exec -> Some "mov exec"
         | Null -> Some "mov null"
         | _ -> None)
      ; (match source with
         | Status -> Some "mov status"
         | _ -> None)
      ; (match op, destination with
         | Reverse, _ -> Some "mov :: (32-bit reverse)"
         | Invert, (X | Y | Isr | Osr) -> Some "mov ~ into a register (32-bit invert)"
         | _ -> None)
      ]
  | Irq { mode = Raise_and_wait | Raise; _ } -> []
  | Irq { mode = Clear; _ } -> [ "irq clear" ]
;;

(* the largest divisor of [threshold] no more than 16 that [counts] all divide *)
let repack threshold ~counts =
  List.range ~stop:`inclusive 1 Isa.data_bits
  |> List.rev
  |> List.find ~f:(fun n ->
    threshold % n = 0 && List.for_all counts ~f:(fun count -> n % count = 0))
;;

(* Refusals of the program as a whole, the 16-bit thresholds, and the host contract. *)
let program_level ~(setup : Setup.t) (program : Pioasm.Program.t) ~exec =
  let ops =
    Array.to_list program.instructions @ Array.to_list exec
    |> List.map ~f:(fun (i : Pioasm.Instruction.t) -> i.op)
  in
  let any f = List.exists ops ~f in
  let shifts_in =
    any (function
      | In _ -> true
      | _ -> false)
  in
  let reads_isr =
    any (function
      | Mov { source = Isr; _ } | In { source = Isr; _ } -> true
      | _ -> false)
  in
  (* a whole value in isr is shifted unless a push takes it at once *)
  let loads_isr =
    Array.existsi program.instructions ~f:(fun pc (i : Pioasm.Instruction.t) ->
      let pushed () =
        match program.instructions.(Relation.following program pc).op with
        | Push { if_full = false; _ } -> true
        | _ -> false
      in
      match i.op with
      | Mov { destination = Isr; source = Null; _ } -> false
      | Mov { destination = Isr; _ } | Out { destination = Isr; _ } -> not (pushed ())
      | _ -> false)
    || Array.exists exec ~f:(fun (i : Pioasm.Instruction.t) ->
      match i.op with
      | Mov { destination = Isr; source = Null; _ } -> false
      | Mov { destination = Isr; _ } | Out { destination = Isr; _ } -> true
      | _ -> false)
  in
  let reads_osr =
    any (function
      | Mov { source = Osr; _ } | In { source = Osr; _ } -> true
      | _ -> false)
  in
  let pulls =
    any (function
      | Pull _ -> true
      | _ -> false)
  in
  let tests_osr =
    any (function
      | Jmp { condition = Osr_not_empty; _ } -> true
      | _ -> false)
  in
  let pushes =
    any (function
      | Push _ -> true
      | _ -> false)
  in
  let moves_isr =
    any (function
      | Mov { destination = Isr; _ } | Out { destination = Isr; _ } -> true
      | _ -> false)
  in
  let discards =
    any (function
      | Out { destination = Null; bits = 32 } -> true
      | _ -> false)
  in
  let outs =
    any (function
      | Out _ -> true
      | _ -> false)
  in
  let out_counts =
    List.filter_map ops ~f:(function
      | Out { bits; _ } when bits <= Isa.data_bits -> Some bits
      | _ -> None)
  in
  let in_counts =
    List.filter_map ops ~f:(function
      | In { bits; _ } when bits <= Isa.data_bits -> Some bits
      | _ -> None)
  in
  let refusals = ref [] in
  let refuse feature = refusals := feature :: !refusals in
  let contract = ref [] in
  let promise line = contract := line :: !contract in
  if program.side_set.count > Isa.max_side_set
  then refuse (sprintf "side-set of %d pins" program.side_set.count);
  if setup.in_shift_right && shifts_in && reads_isr
  then refuse "isr read whole under a right shift";
  if shifts_in && loads_isr then refuse "isr loaded whole, then shifted";
  if (not setup.out_shift_right) && reads_osr
  then refuse "osr read whole under a left shift";
  let pull_threshold =
    if setup.pull_threshold <= Isa.data_bits
    then Some setup.pull_threshold
    else if not (setup.autopull || tests_osr)
    then Some Isa.data_bits
    else if tests_osr || pulls || reads_osr || discards
    then None
    else repack setup.pull_threshold ~counts:out_counts
  in
  let pull_threshold =
    match pull_threshold with
    | Some n ->
      if setup.pull_threshold > Isa.data_bits && setup.autopull
      then
        promise
          (sprintf
             "each %d-bit tx word comes as %d words of %d bits, in the order they shift \
              out"
             setup.pull_threshold
             (setup.pull_threshold / n)
             n);
      n
    | None ->
      refuse (sprintf "pull threshold %d" setup.pull_threshold);
      Isa.data_bits
  in
  let push_threshold =
    if setup.push_threshold <= Isa.data_bits
    then Some setup.push_threshold
    else if not setup.autopush
    then Some Isa.data_bits
    else if pushes || moves_isr || reads_isr
    then None
    else repack setup.push_threshold ~counts:in_counts
  in
  let push_threshold =
    match push_threshold with
    | Some n ->
      if setup.push_threshold > Isa.data_bits && setup.autopush
      then
        promise
          (sprintf
             "each %d-bit rx word comes as %d words of %d bits, in the order they shift \
              in"
             setup.push_threshold
             (setup.push_threshold / n)
             n);
      n
    | None ->
      refuse (sprintf "push threshold %d" setup.push_threshold);
      Isa.data_bits
  in
  if outs || pulls
  then
    promise
      (if setup.out_shift_right
       then "tx words fit 16 bits"
       else "tx words carry their data in bits 31-16, sent as bits 15-0");
  if shifts_in || pushes
  then
    promise
      (if setup.in_shift_right
       then "rx words come back as bits 31-16, in bits 15-0"
       else "rx words fit 16 bits");
  if setup.autopush
  then
    promise "the host keeps the rx fifo from filling: autopush faults instead of stalling";
  if any (function
       | Mov { source = Pins; _ } -> true
       | _ -> false)
  then promise "mov from pins reads in_count pins, as on RP2350";
  if any (function
       | Irq { mode = Raise_and_wait; _ } -> true
       | _ -> false)
  then promise "irq wait raises the irq flag and halts; the host restarts the machine";
  if any (function
       | Irq { mode = Raise; _ } -> true
       | _ -> false)
  then promise "irq raises the host's one irq flag, whatever its number";
  if any (function
       | Out { destination = Exec; _ } -> true
       | _ -> false)
  then promise "out exec takes an exec table index, not an instruction";
  if List.exists setup.exec ~f:(fun e -> not (List.is_empty e.from_sides))
  then
    promise
      "an exec entry comes only from the side-set its guard names, else the machine halts";
  if setup.dirs_inverted
     && any (function
       | Out { destination = Pindirs; _ } | Mov { destination = Pindirs; _ } -> true
       | _ -> false)
  then promise "the bits out and mov write to pindirs come complemented";
  List.rev !refusals, List.rev !contract, pull_threshold, push_threshold
;;

module Key = struct
  type t =
    { site : Relation.Site.t
    ; side : int
    }
  [@@deriving sexp_of, compare, equal, hash]
end

module Item = struct
  type word =
    | Jmp of Isa.Jmp_cond.Cases.t * string
    | Op of Isa.Op.t * int

  type t =
    | Label of string
    | Word of word * string option
end

let cond_text (cond : Isa.Jmp_cond.Cases.t) =
  match cond with
  | Always -> ""
  | X_dec -> "x--, "
  | Y_dec -> "y--, "
  | X_ne_y -> "x!=y, "
  | Pin -> "pin, "
  | Not_pin -> "!pin, "
  | Osr_not_empty -> "!osre, "
  | Stuff_pending -> "stuff, "
  | Tx_not_empty -> "tx, "
  | Tx_empty -> "!tx, "
  | Rx_not_full -> "rx, "
  | Rx_full -> "!rx, "
;;

let isa_mov_dest (d : Pioasm.Destination.t) : Isa.Mov_dest.Cases.t =
  match d with
  | Pins -> Pins
  | X -> X
  | Y -> Y
  | Pindirs -> Pindirs
  | Isr -> Isr
  | Osr -> Osr
  | Null | Pc | Exec -> raise_s [%message "BUG: refused mov destination"]
;;

let isa_mov_source (s : Pioasm.Source.t) : Isa.Mov_source.Cases.t =
  match s with
  | Pins -> Pins
  | X -> X
  | Y -> Y
  | Null -> Null
  | Isr -> Isr
  | Osr -> Osr
  | Status -> raise_s [%message "BUG: refused mov source"]
;;

let isa_in_source (s : Pioasm.Source.t) : Isa.In_source.Cases.t =
  match s with
  | Pins -> Pins
  | X -> X
  | Y -> Y
  | Null -> Null
  | Isr -> Isr
  | Osr -> Osr
  | Status -> raise_s [%message "BUG: refused in source"]
;;

let isa_out_dest (d : Pioasm.Destination.t) : Isa.Out_dest.Cases.t =
  match d with
  | Pins -> Pins
  | X -> X
  | Y -> Y
  | Null -> Null
  | Pindirs -> Pindirs
  | Isr -> Isr
  | Osr | Pc | Exec -> raise_s [%message "BUG: refused out destination"]
;;

let isa_mov_op (op : Pioasm.Mov_op.t) : Isa.Mov_op.Cases.t =
  match op with
  | Copy -> Copy
  | Invert -> Invert
  | Reverse -> Reverse
;;

(* The data part of an instruction run before the start, as pio_sm_exec does. *)
let init_op ~(setup : Setup.t) (instruction : Pioasm.Instruction.t) : Isa.Op.t option =
  let mask = (1 lsl setup.set_count) - 1 in
  match instruction.op with
  | Set { destination = (Pins | Pindirs | X | Y) as destination; value } ->
    Some
      (Set
         { dest =
             (match destination with
              | Pins -> Pins
              | Pindirs -> Pindirs
              | X -> X
              | _ -> Y)
         ; value =
             (match destination with
              | Pindirs when setup.dirs_inverted -> lnot value land mask
              | _ -> value)
         })
  | Mov { destination; op = Copy; source } ->
    Some
      (Mov { dest = isa_mov_dest destination; op = Copy; source = isa_mov_source source })
  | Out { destination; bits } when bits <= Isa.data_bits ->
    Some (Out { dest = isa_out_dest destination; count = bits })
  | Pull _ -> Some (Sys Pull)
  | _ -> None
;;

let side_by_set ~(setup : Setup.t) (program : Pioasm.Program.t) ~exec =
  let ops = Array.to_list program.instructions @ Array.to_list exec in
  let any f = List.exists ops ~f:(fun (i : Pioasm.Instruction.t) -> f i.op) in
  let overlaps ~base ~count =
    let side = program.side_set.count in
    side > 0 && setup.side_set_base < base + count && base < setup.side_set_base + side
  in
  let writes_out =
    any (function
      | Out { destination = Pins | Pindirs; _ } | Mov { destination = Pins | Pindirs; _ }
        -> true
      | _ -> false)
  in
  let writes_set =
    any (function
      | Set { destination = Pins | Pindirs; _ } -> true
      | _ -> false)
  in
  let shared =
    (writes_out && overlaps ~base:setup.out_base ~count:setup.out_count)
    || (writes_set && overlaps ~base:setup.set_base ~count:setup.set_count)
  in
  let touches_pins (i : Pioasm.Instruction.t) =
    match i.op with
    | Set { destination = Pins | Pindirs; _ }
    | Out { destination = Pins | Pindirs; _ }
    | Mov { destination = Pins | Pindirs; _ }
    | Mov { source = Pins; _ }
    | In { source = Pins; _ }
    | Jmp { condition = Pin; _ }
    | Wait _ -> true
    | _ -> false
  in
  if not shared
  then Ok false
  else if (not program.side_set.optional) || writes_set
  then Error "side-set on pins out or set writes"
  else if List.exists ops ~f:(fun i -> Option.is_some i.side && touches_pins i)
  then Error "side-set beside a pin write or sample, on pins out writes"
  else Ok true
;;

let translate (setup : Setup.t) (program : Pioasm.Program.t) =
  let open Result.Let_syntax in
  let parse_all what lines program =
    List.map lines ~f:(fun line ->
      Pioasm.parse_instruction program line
      |> Result.map_error ~f:(fun error ->
        [ { Refusal.pc = None
          ; feature = sprintf "%s %S: %s" what line (Error.to_string_hum error)
          }
        ]))
    |> Result.all
  in
  let%bind exec =
    parse_all "exec" (List.map setup.exec ~f:(fun e -> e.Setup.Exec.instruction)) program
  in
  (* pio_sm_exec runs an instruction with no side-set bits, which we leave out *)
  let%bind init =
    parse_all
      "init"
      setup.init
      { program with side_set = { program.side_set with optional = true } }
  in
  let exec = Array.of_list exec in
  let by_instruction =
    List.concat
      [ Array.to_list program.instructions
        |> List.concat_mapi ~f:(fun pc i ->
          List.map (refused ~setup ~in_exec:false i) ~f:(fun feature ->
            { Refusal.pc = Some pc; feature }))
      ; Array.to_list exec
        |> List.concat_map ~f:(fun i ->
          List.map (refused ~setup ~in_exec:true i) ~f:(fun feature ->
            { Refusal.pc = None; feature = "exec table: " ^ feature }))
      ; List.filter_map init ~f:(fun i ->
          match init_op ~setup i with
          | Some _ -> None
          | None -> Some { Refusal.pc = None; feature = "init: " ^ i.text })
      ]
  in
  let whole, contract, pull_threshold, push_threshold =
    program_level ~setup program ~exec
  in
  let entry_pc =
    match setup.entry with
    | None -> Ok 0
    | Some label ->
      (match List.Assoc.find program.labels label ~equal:String.equal with
       | Some pc -> Ok pc
       | None -> Error [ { Refusal.pc = None; feature = "no label " ^ label } ])
  in
  let%bind entry_pc in
  let%bind () =
    if setup.period < 2 || setup.period > 31 || setup.per_cycle < 1
    then
      Error
        [ { Refusal.pc = None
          ; feature = sprintf "p %d, %d a cycle" setup.period setup.per_cycle
          }
        ]
    else Ok ()
  in
  let%bind () =
    match
      by_instruction @ List.map whole ~f:(fun feature -> { Refusal.pc = None; feature })
    with
    | [] -> Ok ()
    | refusals -> Error (List.dedup_and_sort refusals ~compare:Refusal.compare)
  in
  (* Side-set on pins out or set also writes is written by [set] instead, as our side-set
     comes on every word and would undo the data in between. *)
  let side_by_set = side_by_set ~setup program ~exec in
  let%bind () =
    match side_by_set with
    | Error feature -> Error [ { Refusal.pc = None; feature } ]
    | Ok _ -> Ok ()
  in
  let side_by_set = Result.ok side_by_set |> Option.value ~default:false in
  let sided = program.side_set.count > 0 && not side_by_set in
  let side_mask = (1 lsl program.side_set.count) - 1 in
  let ours_side side =
    if setup.dirs_inverted && program.side_set.pindirs
    then lnot side land side_mask
    else side
  in
  let set_mask = (1 lsl setup.set_count) - 1 in
  let ids = Hashtbl.create (module Key) in
  let keys = Hashtbl.create (module String) in
  let pending = Stack.create () in
  let label_of (key : Key.t) =
    let id =
      Hashtbl.find_or_add ids key ~default:(fun () ->
        Stack.push pending key;
        Hashtbl.set keys ~key:(sprintf "n%d" (Hashtbl.length ids)) ~data:key;
        Hashtbl.length ids)
    in
    sprintf "n%d" id
  in
  let markers = Hashtbl.create (module Key) in
  let fresh =
    let n = ref 0 in
    fun () ->
      incr n;
      sprintf "l%d" !n
  in
  (* A step's parts. A blocking one has [ready] jumps to its normal markers and a [stall]
     copy, inlined at each normal way in so its marker is reached as soon as a normal one;
     a stall copy's own way out is a plain jump, so the inlining stops there. *)
  let rec parts (key : Key.t) =
    let instruction = Relation.instruction program ~exec key.site in
    let id = Hashtbl.find_exn ids key in
    let side' = if sided then Option.value instruction.side ~default:key.side else 0 in
    let s = ours_side key.side
    and s' = ours_side side' in
    let op ?(side = s') o = Item.Word (Op (o, side), None) in
    let jmp cond label = Item.Word (Jmp (cond, label), None) in
    let goto ?(inline = true) site =
      let next = { Key.site; side = side' } in
      let label = label_of next in
      let ready, stall = ready_and_stall next in
      match ready, stall with
      | _ :: _, Some stall when inline ->
        List.map ready ~f:(fun (cond, label) -> jmp cond label) @ stall (fresh ())
      | _ -> [ jmp Always label ]
    in
    let marker suffix =
      let label = sprintf "m%d%s" id suffix in
      Hashtbl.add_multi markers ~key ~data:label;
      [ Item.Label label
      ; Word (Op (Wait (Deadline { advance = true }), s), Some instruction.text)
      ]
    in
    (* the rest of the step's waits: the first cycle's after its marker, then the delay *)
    let delays =
      List.init
        ((Relation.cycles instruction * setup.per_cycle) - 1)
        ~f:(fun _ -> op (Wait (Deadline { advance = true })))
    in
    let after_pc =
      match key.site with
      | Pc pc -> Relation.following program pc
      | Exec { return; _ } -> return
    in
    let after : Relation.Site.t = Pc after_pc in
    let read_now = op (Mov { dest = T; op = Copy; source = Now }) in
    let add_period = op (Alu { dest = T; op = Add; operand = Reg P }) in
    (* t from the cycle a wait released: that cycle less one, plus p *)
    let reanchor =
      [ read_now; add_period; op (Alu { dest = T; op = Sub; operand = Imm 2 }) ]
    in
    (* the side-set alone, the cycle after the marker *)
    let side_nop =
      match instruction.side with
      | Some v when side_by_set ->
        [ op
            (Set
               { dest = (if program.side_set.pindirs then Pindirs else Pins)
               ; value = ours_side v
               })
        ]
      | _ -> if sided && s <> s' then [ op (Sys Nop) ] else []
    in
    let side_first = if side_by_set then side_nop else [] in
    let normal = sprintf "m%d" id in
    (* a blocking op: [ready] jumps past the stall; the stall waits, reads now and then
       does the op, so the op's own cycle less one is the anchor *)
    let blocking ~(ready : Isa.Jmp_cond.Cases.t list) ~(wait : Isa.Fifo_wait.t) ~word =
      let stall suffix =
        marker ("s" ^ suffix)
        @ side_first
        @ [ op (Wait (Fifo wait)); read_now; op word; add_period ]
        @ delays
        @ goto ~inline:false after
      in
      let normal () = marker "" @ side_first @ [ op word ] @ delays @ goto after in
      List.map ready ~f:(fun cond -> cond, sprintf "m%d" id), Some stall, normal
    in
    let simple words =
      [], None, fun () -> marker "" @ side_first @ words () @ delays @ goto after
    in
    match instruction.op with
    | Set { destination; value } ->
      let dest : Isa.Set_dest.Cases.t =
        match destination with
        | Pins -> Pins
        | Pindirs -> Pindirs
        | X -> X
        | Y -> Y
        | _ -> raise_s [%message "BUG: bad set"]
      in
      let value =
        match destination with
        | Pindirs when setup.dirs_inverted -> lnot value land set_mask
        | _ -> value
      in
      simple (fun () -> [ op (Set { dest; value }) ])
    | Mov { destination = Y; op = Copy; source = Y } ->
      simple (fun () -> if side_by_set then [] else side_nop)
    | Mov { destination; op = mov_op; source } ->
      simple (fun () ->
        [ op
            (Mov
               { dest = isa_mov_dest destination
               ; op = isa_mov_op mov_op
               ; source = isa_mov_source source
               })
        ])
    | In { source; bits } ->
      simple (fun () -> [ op (In { source = isa_in_source source; count = bits }) ])
    | Out { destination = Exec; _ } ->
      (* the stall copies jump into the one dispatch *)
      let dispatch = sprintf "d%d" id in
      let rec chain i =
        let allowed =
          match (List.nth_exn setup.exec i).from_sides with
          | [] -> true
          | sides -> List.mem sides key.side ~equal:Int.equal
        in
        let leaf =
          if not allowed
          then [ op (Sys Halt) ]
          else
            [ op (Set { dest = X; value = 0 })
            ; op (Alu { dest = X; op = Add; operand = Reg P })
            ; op (Set { dest = P; value = setup.period })
            ]
            @ delays
            @ goto (Exec { entry = i; return = after_pc })
        in
        if i = Array.length exec - 1
        then leaf
        else (
          let next = fresh () in
          (jmp X_dec next :: leaf) @ (Item.Label next :: chain (i + 1)))
      in
      let save_and_read =
        [ op (Mov { dest = P; op = Copy; source = X })
        ; op (Out { dest = X; count = Isa.data_bits })
        ]
      in
      let body () = save_and_read @ (Item.Label dispatch :: chain 0) in
      if setup.autopull
      then
        ( [ Isa.Jmp_cond.Cases.Osr_not_empty, normal; Tx_not_empty, normal ]
        , Some
            (fun suffix ->
              (* the anchor is the out, and p must be read before x goes into it *)
              marker ("s" ^ suffix)
              @ side_first
              @ [ op (Wait (Fifo Tx_not_empty))
                ; read_now
                ; add_period
                ; op (Alu { dest = T; op = Add; operand = Imm 3 })
                ]
              @ save_and_read
              @ [ jmp Always dispatch ])
        , fun () -> marker "" @ side_nop @ body () )
      else [], None, fun () -> marker "" @ side_nop @ body ()
    | Out { destination; bits } ->
      let word : Isa.Op.t =
        Out
          { dest = isa_out_dest destination
          ; count = (if bits > Isa.data_bits then Isa.data_bits else bits)
          }
      in
      if setup.autopull
      then blocking ~ready:[ Osr_not_empty; Tx_not_empty ] ~wait:Tx_not_empty ~word
      else simple (fun () -> [ op word ])
    | Jmp { condition; target } ->
      let target : Relation.Site.t = Pc target in
      let label_target = label_of { site = target; side = side' } in
      let control () =
        match condition with
        | Always -> delays @ goto target
        | X_post_decrement -> delays @ [ jmp X_dec label_target ] @ goto after
        | Y_post_decrement -> delays @ [ jmp Y_dec label_target ] @ goto after
        | X_not_y -> delays @ [ jmp X_ne_y label_target ] @ goto after
        | X_zero | Y_zero ->
          let dest : Isa.Alu_dest.Cases.t =
            match condition with
            | X_zero -> X
            | _ -> Y
          in
          let nonzero = fresh () in
          let restore = op (Alu { dest; op = Add; operand = Imm 1 }) in
          delays
          @ [ jmp
                (match dest with
                 | X -> X_dec
                 | _ -> Y_dec)
                nonzero
            ; restore
            ]
          @ goto target
          @ [ Item.Label nonzero; restore ]
          @ goto after
        | Osr_not_empty ->
          delays
          @ [ jmp Osr_not_empty label_target ]
          @ (if setup.autopull then [ jmp Tx_not_empty label_target ] else [])
          @ goto after
        | Pin ->
          let taken = fresh () in
          [ jmp Pin taken ]
          @ delays
          @ goto after
          @ [ Item.Label taken ]
          @ delays
          @ goto target
      in
      [], None, fun () -> marker "" @ side_nop @ control ()
    | Wait { polarity; source } ->
      let pin =
        match source with
        | Pin n -> (setup.in_base + n) % Isa.pin_space
        | Jmp_pin -> setup.jmp_pin
        | Gpio _ | Irq _ -> raise_s [%message "BUG: refused wait"]
      in
      simple (fun () -> op (Wait (Pin_level { pin; level = polarity })) :: reanchor)
    | Pull { if_empty = false; block = true } ->
      blocking ~ready:[ Tx_not_empty ] ~wait:Tx_not_empty ~word:(Sys Pull)
    | Pull { if_empty = true; block = _ } ->
      let ready, stall, normal =
        blocking ~ready:[ Tx_not_empty ] ~wait:Tx_not_empty ~word:(Sys Pull)
      in
      ( (Isa.Jmp_cond.Cases.Osr_not_empty, sprintf "m%dk" id) :: ready
      , stall
      , fun () -> normal () @ marker "k" @ side_nop @ delays @ goto after )
    | Pull { if_empty = false; block = false } ->
      let empty = fresh () in
      ( []
      , None
      , fun () ->
          marker ""
          @ side_nop
          @ [ jmp Tx_empty empty; op (Sys Pull) ]
          @ delays
          @ goto after
          @ [ Item.Label empty; op (Mov { dest = Osr; op = Copy; source = X }) ]
          @ delays
          @ goto after )
    | Push { block = true; _ } ->
      blocking ~ready:[ Rx_not_full ] ~wait:Rx_not_full ~word:(Sys Push)
    | Push { block = false; _ } ->
      let full = fresh () in
      ( []
      , None
      , fun () ->
          marker ""
          @ side_nop
          @ [ jmp Rx_full full; op (Sys Push) ]
          @ delays
          @ goto after
          @ [ Item.Label full; op (Mov { dest = Isr; op = Copy; source = Null }) ]
          @ delays
          @ goto after )
    | Irq { mode = Raise_and_wait; _ } ->
      [], None, fun () -> marker "" @ side_first @ [ op (Sys Irq); op (Sys Halt) ]
    | Irq { mode = Raise; _ } -> simple (fun () -> [ op (Sys Irq) ])
    | Irq { mode = Clear; _ } -> raise_s [%message "BUG: refused irq clear"]
  and ready_and_stall key =
    let ready, stall, _ = parts key in
    ready, stall
  in
  let block (key : Key.t) =
    let id = Hashtbl.find_exn ids key in
    let ready, stall, normal = parts key in
    (Item.Label (sprintf "n%d" id)
     :: List.map ready ~f:(fun (cond, label) -> Item.Word (Jmp (cond, label), None)))
    @ (match stall with
       | Some stall -> stall ""
       | None -> [])
    @ normal ()
  in
  let s_init = if sided then ours_side setup.side_init else 0 in
  let prologue =
    let op o = Item.Word (Op (o, s_init), None) in
    (op (Set { dest = P; value = setup.period })
     ::
     (if side_by_set
      then
        [ op
            (Set
               { dest = (if program.side_set.pindirs then Pindirs else Pins)
               ; value = ours_side setup.side_init
               })
        ]
      else []))
    @ List.filter_map init ~f:(fun i -> Option.map (init_op ~setup i) ~f:op)
    @ [ op (Mov { dest = T; op = Copy; source = Now })
      ; op (Alu { dest = T; op = Add; operand = Reg P })
      ; op (Alu { dest = T; op = Add; operand = Imm 7 })
      ; Word
          ( Jmp
              ( Always
              , label_of
                  { site = Pc entry_pc; side = (if sided then setup.side_init else 0) } )
          , None )
      ]
  in
  (* Trace layout: a block goes where the first plain jump to it is, so that jump falls
     through; the rest follow in the order they were first named. *)
  let placed = Hash_set.create (module Key) in
  let order = ref [] in
  let rec place key =
    Hash_set.add placed key;
    order := key :: !order;
    List.concat_map (block key) ~f:splice
  and splice (item : Item.t) =
    match item with
    | Word (Jmp (Always, label), _) ->
      (match Hashtbl.find keys label with
       | Some next when not (Hash_set.mem placed next) -> place next
       | _ -> [ item ])
    | item -> [ item ]
  in
  let prologue = List.concat_map prologue ~f:splice in
  let rec rest () =
    match Stack.pop pending with
    | None -> []
    | Some key when Hash_set.mem placed key -> rest ()
    | Some key ->
      let items = place key in
      items @ rest ()
  in
  let blocks = rest () in
  let items = prologue @ blocks in
  (* a jump to the next word falls through *)
  let rec fall = function
    | (Item.Word (Jmp (Always, label), _) as jump) :: rest ->
      let rec labels = function
        | Item.Label l :: rest -> String.equal l label || labels rest
        | _ -> false
      in
      if labels rest then fall rest else jump :: fall rest
    | item :: rest -> item :: fall rest
    | [] -> []
  in
  let items = fall items in
  let address = Hashtbl.create (module String) in
  let size =
    List.fold items ~init:0 ~f:(fun at item ->
      match item with
      | Label l ->
        Hashtbl.set address ~key:l ~data:at;
        at
      | Word _ -> at + 1)
  in
  let%bind () =
    if size > 1 lsl Isa.pc_bits
    then
      Error
        [ { Refusal.pc = None
          ; feature = sprintf "%d words, more than program memory holds" size
          }
        ]
    else Ok ()
  in
  let resolve label = Hashtbl.find_exn address label in
  let words =
    List.filter_map items ~f:(function
      | Label _ -> None
      | Word (Jmp (cond, label), _) -> Some (Isa.Jmp { cond; target = resolve label })
      | Word (Op (op, side_set), _) -> Some (Isa.Op { op; delay = 0; side_set }))
  in
  let side_set_count = if sided then program.side_set.count else 0 in
  let source =
    let header = if sided then [ sprintf ".side_set %d" side_set_count ] else [] in
    header
    @ List.map items ~f:(function
      | Label l -> l ^ ":"
      | Word (Jmp (cond, label), _) -> sprintf "    jmp %s%s" (cond_text cond) label
      | Word (Op (op, side_set), comment) ->
        let text = Asm.to_string ~side_set_count (Op { op; delay = 0; side_set }) in
        (match comment with
         | Some c -> sprintf "    %-24s ; %s" text c
         | None -> "    " ^ text))
    |> String.concat_lines
  in
  let config =
    { Program_config.default with
      side_set_count
    ; side_set_base = setup.side_set_base
    ; side_set_pindirs = program.side_set.pindirs
    ; in_base = setup.in_base
    ; in_count = setup.in_count
    ; out_base = setup.out_base
    ; out_count = setup.out_count
    ; set_base = (if side_by_set then setup.side_set_base else setup.set_base)
    ; set_count = (if side_by_set then program.side_set.count else setup.set_count)
    ; jmp_pin = setup.jmp_pin
    ; in_shift = (if setup.in_shift_right then Right else Left)
    ; out_shift = (if setup.out_shift_right then Right else Left)
    ; autopush = setup.autopush
    ; push_threshold
    ; autopull = setup.autopull
    ; pull_threshold
    ; period_fraction = setup.fraction
    }
  in
  let%map () =
    Program_config.validate config
    |> Result.map_error ~f:(fun error ->
      [ { Refusal.pc = None; feature = "config: " ^ Error.to_string_hum error } ])
  in
  let steps =
    List.rev !order
    |> List.map ~f:(fun (key : Key.t) ->
      { Relation.Step.site = key.site
      ; side = key.side
      ; markers =
          Hashtbl.find_multi markers key |> List.map ~f:resolve |> List.sort ~compare
      })
  in
  { source
  ; words
  ; config
  ; relation =
      { period = setup.period
      ; per_cycle = setup.per_cycle
      ; steps
      ; entry = Pc entry_pc
      ; side_init = (if sided then setup.side_init else 0)
      ; side_by_set
      }
  ; exec
  ; contract
  }
;;

let check_relation (setup : Setup.t) program t =
  Relation.check
    program
    ~exec:t.exec
    ~dirs_inverted:setup.dirs_inverted
    ~config:t.config
    t.words
    t.relation
;;

let tx_words (setup : Setup.t) t word =
  let mask n = (1 lsl n) - 1 in
  let threshold = setup.pull_threshold in
  if setup.autopull && threshold > Isa.data_bits
  then (
    let chunk = t.config.pull_threshold in
    List.init (threshold / chunk) ~f:(fun j ->
      if setup.out_shift_right
      then (word lsr (chunk * j)) land mask chunk
      else
        ((word lsr (32 - (chunk * (j + 1)))) land mask chunk) lsl (Isa.data_bits - chunk)))
  else if setup.out_shift_right
  then [ word land mask Isa.data_bits ]
  else [ (word lsr 16) land mask Isa.data_bits ]
;;
