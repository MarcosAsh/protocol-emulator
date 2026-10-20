open! Core
open Protocol_emulator

module Bound = struct
  type t =
    { words : int
    ; delays : int list
    ; imms : int list
    ; values : int list
    }
  [@@deriving sexp_of]

  let tiny = { words = 4; delays = [ 0 ]; imms = [ 7 ]; values = [] }
  let laptop = { words = 5; delays = [ 0; 1 ]; imms = [ 3 ]; values = [ 4 ] }
end

module Class = struct
  type t =
    | Wait
    | Wait_advance
    | Anchor
    | Step
    | Set_p
    | Set_x
    | Count
    | Jump
    | Nop
    | Halt
  [@@deriving sexp_of, compare, enumerate, equal]

  let of_instruction : Isa.t -> t = function
    | Jmp { cond = X_dec; _ } -> Count
    | Jmp _ -> Jump
    | Op { op; _ } ->
      (match op with
       | Wait (Deadline { advance = false }) -> Wait
       | Wait (Deadline { advance = true }) -> Wait_advance
       | Mov { dest = T; _ } -> Anchor
       | Alu { dest = T; _ } -> Step
       | Set { dest = P; _ } -> Set_p
       | Set { dest = X; _ } -> Set_x
       | Sys Halt -> Halt
       | _ -> Nop)
  ;;
end

let config = Program_config.default
let past_end = Isa.of_word ~side_set_count:0 0 |> ok_exn
let at program pc = if pc < Array.length program then program.(pc) else past_end

let alphabet (bound : Bound.t) =
  let ops : Isa.Op.t list =
    List.concat
      [ [ Isa.Op.Sys Nop
        ; Wait (Deadline { advance = false })
        ; Wait (Deadline { advance = true })
        ; Mov { dest = T; op = Copy; source = Now }
        ]
      ; List.concat_map bound.imms ~f:(fun imm ->
          List.map [ Isa.Alu_op.Cases.Add; Sub ] ~f:(fun op ->
            Isa.Op.Alu { dest = T; op; operand = Imm imm }))
      ; List.concat_map bound.values ~f:(fun value ->
          [ Isa.Op.Set { dest = P; value }; Set { dest = X; value } ])
      ]
  in
  let jumps =
    List.concat_map [ Isa.Jmp_cond.Cases.Always; X_dec ] ~f:(fun cond ->
      List.init bound.words ~f:(fun target -> Isa.Jmp { cond; target }))
  in
  List.concat_map ops ~f:(fun op ->
    List.map bound.delays ~f:(fun delay -> Isa.Op { op; delay; side_set = 0 }))
  @ (Isa.Op { op = Sys Halt; delay = 0; side_set = 0 } :: jumps)
;;

(* pc [Array.length program] is the [jmp 0] past the end, and leads back to 0 *)
let successors program pc =
  let n = Array.length program in
  if pc = n
  then [ 0 ]
  else (
    match program.(pc) with
    | Isa.Jmp { cond = Always; target } -> [ target ]
    | Jmp { target; _ } -> [ target; pc + 1 ]
    | Op { op = Sys Halt; _ } -> []
    | Op _ -> [ pc + 1 ])
;;

let reachable_from program pc =
  let seen = Array.create ~len:(Array.length program + 1) false in
  let rec visit pc =
    if not seen.(pc)
    then (
      seen.(pc) <- true;
      List.iter (successors program pc) ~f:visit)
  in
  visit pc;
  seen
;;

let reachable program = reachable_from program 0

let sets_x_first program =
  let n = Array.length program in
  let reached = reachable program in
  (* [set.(pc)]: x is set on every way into pc, a greatest fixed point *)
  let set = Array.init (n + 1) ~f:(fun pc -> pc <> 0) in
  let leaves pc =
    set.(pc)
    ||
    match at program pc with
    | Op { op = Set { dest = X; _ }; _ } -> true
    | Jmp _ | Op _ -> false
  in
  let changed = ref true in
  while !changed do
    changed := false;
    for pc = 0 to n do
      if reached.(pc)
      then
        List.iter (successors program pc) ~f:(fun next ->
          if set.(next) && not (leaves pc)
          then (
            set.(next) <- false;
            changed := true))
    done
  done;
  Array.for_alli program ~f:(fun pc instruction ->
    match instruction with
    | Jmp { cond = X_dec; _ } -> (not reached.(pc)) || set.(pc)
    | Jmp _ | Op _ -> true)
;;

let programs (bound : Bound.t) =
  let alphabet = Array.of_list (alphabet bound) in
  let size = Array.length alphabet in
  Sequence.range 0 (Int.pow size bound.words)
  |> Sequence.filter_map ~f:(fun index ->
    let program =
      Array.init bound.words ~f:(fun pc -> alphabet.(index / Int.pow size pc % size))
    in
    let reached = reachable program in
    Option.some_if
      (Array.for_alli program ~f:(fun pc instruction ->
         reached.(pc) || Isa.equal instruction alphabet.(0)))
      (index, program))
;;

module Truth = struct
  type t =
    | Safe of { waited : bool }
    | Late of { pc : int }
    | Unanchored of { pc : int }
    | Undecided
  [@@deriving sexp_of, compare, equal]

  let is_safe = function
    | Safe _ -> true
    | Late _ | Unanchored _ | Undecided -> false
  ;;

  let name = function
    | Safe { waited = true } -> "safe, waits"
    | Safe { waited = false } -> "safe, never waits"
    | Late _ -> "late"
    | Unanchored _ -> "unanchored"
    | Undecided -> "undecided"
  ;;
end

module Key = struct
  type t =
    { pc : int
    ; x : int
    ; p : int
    ; phase : int option
    }
  [@@deriving compare, hash, sexp_of]
end

let words program =
  Array.to_list program
  |> List.map ~f:(fun instruction -> Isa.to_word ~side_set_count:0 instruction |> ok_exn)
;;

let to_string program =
  Array.to_list program
  |> List.map ~f:(Asm.to_string ~side_set_count:0)
  |> String.concat ~sep:"; "
;;

let phase (m : Machine.t) =
  let d = (m.now - m.t) land ((1 lsl Isa.timer_bits) - 1) in
  if d >= 1 lsl (Isa.timer_bits - 1) then d - (1 lsl Isa.timer_bits) else d
;;

(* Two repeats end a run: of the state, or of the state less the phase with no deadline
   wait in between, as only a wait reads the phase; so does a pc no wait lies ahead of. *)
let truth ?(horizon = 4_000_000) program =
  if not (sets_x_first program)
  then raise_s [%message "counts x down before setting it" (to_string program : string)];
  let waits_ahead =
    Array.init
      (Array.length program + 1)
      ~f:(fun pc ->
        Array.existsi (reachable_from program pc) ~f:(fun pc reached ->
          reached
          &&
          match Class.of_instruction (at program pc) with
          | Wait | Wait_advance -> true
          | Anchor | Step | Set_p | Set_x | Count | Jump | Nop | Halt -> false))
  in
  let seen = Hash_set.create (module Key) in
  let since_wait = Hash_set.create (module Key) in
  let rec run (m : Machine.t) ~cycle ~anchored ~waited : Truth.t =
    if m.halted
    then Safe { waited }
    else if cycle >= horizon
    then Undecided
    else if m.stall > 0
    then run (Machine.step m ~inputs:0) ~cycle:(cycle + 1) ~anchored ~waited
    else (
      let instruction = at program m.pc in
      let class_ = Class.of_instruction instruction in
      let waits =
        match class_ with
        | Wait | Wait_advance -> true
        | Anchor | Step | Set_p | Set_x | Count | Jump | Nop | Halt -> false
      in
      let bare = { Key.pc = m.pc; x = m.x; p = m.p; phase = None } in
      let key = { bare with phase = Option.some_if anchored (phase m) } in
      if waits && not anchored
      then Unanchored { pc = m.pc }
      else if (not waits_ahead.(m.pc))
              || ((not waits) && Hash_set.mem since_wait bare)
              || Hash_set.mem seen key
      then Safe { waited }
      else (
        if waits then Hash_set.clear since_wait else Hash_set.add since_wait bare;
        Hash_set.add seen key;
        let after = Machine.step m ~inputs:0 in
        if after.fault.missed_deadline
        then Late { pc = m.pc }
        else
          run
            after
            ~cycle:(cycle + 1)
            ~anchored:(anchored || Class.equal class_ Anchor)
            ~waited:(waited || (waits && after.pc <> m.pc))))
  in
  run
    (Machine.create ~config ~program:(words program) |> ok_exn)
    ~cycle:0
    ~anchored:false
    ~waited:false
;;

let analyse program = Analyser.analyse ~config (Array.to_list program)

let analyser_late program rows =
  List.filter_map rows ~f:(fun (row : Analyser.Row.t) ->
    Option.some_if
      (row.may_miss || row.may_underrun)
      ( Class.of_instruction (at program row.pc)
      , match row.phase.hi with
        | None -> "analyser: phase unbounded"
        | Some _ -> "analyser: phase above zero" ))
;;

module K = Kernel.Make (Hardcaml.Bits)

let empty = (Kernel.Table.of_analyser []).(1)

(* [Kernel.check] with no premises, at the pcs [of_analyser] did not leave empty: the
   conjuncts of an empty row hold, as [Kernel.conjuncts] gates each on [is_empty]. *)
(* [accepts] by its inputs, which repeat across programs *)
let accepted = Hashtbl.create (module String)

let kernel_accepts ~words (table : Kernel.Table.t) =
  let open Hardcaml in
  let words = Array.of_list words in
  let word pc =
    Bits.of_unsigned_int
      ~width:Isa.data_bits
      (if pc < Array.length words then words.(pc) else 0)
  in
  let pc_bits n = Bits.of_unsigned_int ~width:Isa.pc_bits n in
  let capture =
    { Kernel.Capture.pin =
        Bits.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
    ; rising = Bits.of_bool config.capture_rising
    ; single_edge = Bits.gnd
    }
  in
  let loaded =
    { Kernel.Loaded.valid = Bits.gnd; value = Bits.zero Isa.data_bits; floor = Bits.gnd }
  in
  Bits.to_bool (K.starts_open table.(0) ~spacing:K.no_spacing)
  && Array.for_alli table ~f:(fun pc row ->
    Kernel.Row.equal Bits.equal row empty
    ||
    let next, target =
      K.successors
        ~wrap_top:(pc_bits config.wrap_top)
        ~wrap_bottom:(pc_bits config.wrap_bottom)
        ~pc:(pc_bits pc)
        ~word:(word pc)
    in
    let next = table.(Bits.to_unsigned_int next) in
    let target = table.(Bits.to_unsigned_int target) in
    let key =
      List.concat_map [ row; next; target ] ~f:Kernel.Row.to_list
      |> List.cons (word pc)
      |> Bits.concat_msb
      |> Bits.to_constant
      |> Constant.Raw.to_string
    in
    match Hashtbl.find accepted key with
    | Some accepts -> accepts
    | None ->
      let accepts =
        K.accepts
          ~side_set_count:(Bits.of_unsigned_int ~width:2 config.side_set_count)
          ~fraction:(Bits.of_bool (config.period_fraction <> 0))
          ~loaded
          ~capture
          ~spacing:K.no_spacing
          ~word:(word pc)
          ~row
          ~next
          ~target
        |> Bits.to_bool
      in
      if Hashtbl.length accepted >= 1_000_000 then Hashtbl.clear accepted;
      Hashtbl.set accepted ~key ~data:accepts;
      accepts)
;;

let admits program =
  let rows = analyse program in
  List.is_empty (analyser_late program rows)
  && kernel_accepts ~words:(words program) (Kernel.Table.of_analyser rows)
;;

let refusal program =
  let rows = analyse program in
  let words = words program in
  let table = Kernel.Table.of_analyser rows in
  (match analyser_late program rows with
   | _ :: _ as late -> late
   | [] ->
     (match Kernel.check ~config ~words table with
      | Ok () -> []
      | Error error ->
        (match Kernel.rejections ~config ~words table with
         | [] -> [ Class.Jump, Error.to_string_hum error ]
         | rejections ->
           List.concat_map rejections ~f:(fun { pc; fails } ->
             List.map fails ~f:(fun fail ->
               Class.of_instruction (at program pc), "kernel: " ^ fail)))))
  |> List.dedup_and_sort ~compare:[%compare: Class.t * string]
;;

let table_exists program =
  let words = words program in
  match Table_query.witness ~single_capture_edge:false ~config ~words () with
  | None -> false
  | Some table ->
    Kernel.check ~config ~words table |> ok_exn;
    true
;;

module Report = struct
  type t =
    { bound : Bound.t
    ; programs : int
    ; out_of_scope : int
    ; checked : int
    ; truths : (string * int) list
    ; safe : int * int
    ; waiting : int * int
    ; unsound : string list
    ; by_class : (Class.t * (int * int)) list
    ; refused :
        ((bool * Class.t list * (Class.t * string) list) * (int * int * Isa.t array)) list
    }
  [@@deriving sexp_of]

  let add (a, b) (c, d) = a + c, b + d

  let merge_alist ~compare ~f xs ys =
    List.Assoc.sort_and_group (xs @ ys) ~compare
    |> List.map ~f:(fun (key, values) -> key, List.reduce_exn values ~f)
  ;;

  let merge t u =
    { bound = t.bound
    ; programs = t.programs + u.programs
    ; out_of_scope = t.out_of_scope + u.out_of_scope
    ; checked = t.checked + u.checked
    ; truths = merge_alist t.truths u.truths ~compare:String.compare ~f:( + )
    ; safe = add t.safe u.safe
    ; waiting = add t.waiting u.waiting
    ; unsound = t.unsound @ u.unsound
    ; by_class = merge_alist t.by_class u.by_class ~compare:Class.compare ~f:add
    ; refused =
        merge_alist
          t.refused
          u.refused
          ~compare:[%compare: bool * Class.t list * (Class.t * string) list]
          ~f:(fun (count, first, example) (count', first', example') ->
            let first, example =
              if first <= first' then first, example else first', example'
            in
            count + count', first, example)
    }
  ;;
end

let run ?horizon ?(check_every = 1000) ?(shard = 0, 1) bound =
  let shard, shards = shard in
  let count = ref 0 in
  let checked = ref 0 in
  let out_of_scope = ref 0 in
  let truths = Hashtbl.create (module String) in
  let safe = ref (0, 0) in
  let waiting = ref (0, 0) in
  let unsound = ref [] in
  let by_class = ref [] in
  let refused = ref [] in
  let tally accepted = 1, Bool.to_int accepted in
  programs bound
  |> Sequence.filter ~f:(fun (index, _) -> index % shards = shard)
  |> Sequence.iter ~f:(fun (index, program) ->
    incr count;
    if not (sets_x_first program)
    then incr out_of_scope
    else (
      let truth = truth ?horizon program in
      Hashtbl.incr truths (Truth.name truth);
      let accepted = admits program in
      let unsafe =
        match truth with
        | Late _ | Unanchored _ -> true
        | Safe _ | Undecided -> false
      in
      (* [Kernel.check] itself on every program a figure names and on a sample *)
      let refusal =
        if not
             ((accepted && unsafe)
              || ((not accepted) && Truth.is_safe truth)
              || index % check_every = 0)
        then []
        else (
          let refusal = refusal program in
          incr checked;
          if Bool.equal accepted (not (List.is_empty refusal))
          then
            raise_s [%message "fast path disagrees" (to_string program) (accepted : bool)];
          refusal)
      in
      if accepted && unsafe
      then
        unsound
        := Sexp.to_string [%message (to_string program) (truth : Truth.t)] :: !unsound;
      match truth with
      | Late _ | Unanchored _ | Undecided -> ()
      | Safe { waited } ->
        safe := Report.add !safe (tally accepted);
        if waited then waiting := Report.add !waiting (tally accepted);
        let reached = reachable program in
        let shape =
          Array.filteri program ~f:(fun pc _ -> reached.(pc))
          |> Array.map ~f:Class.of_instruction
          |> Array.to_list
        in
        let classes = List.dedup_and_sort shape ~compare:Class.compare in
        by_class
        := Report.merge_alist
             !by_class
             (List.map classes ~f:(fun class_ -> class_, tally accepted))
             ~compare:Class.compare
             ~f:Report.add;
        if not accepted
        then
          refused
          := Report.merge_alist
               !refused
               [ (waited, shape, refusal), (1, index, program) ]
               ~compare:[%compare: bool * Class.t list * (Class.t * string) list]
               ~f:(fun (count, first, example) (count', _, _) ->
                 count + count', first, example)));
  { Report.bound
  ; programs = !count
  ; out_of_scope = !out_of_scope
  ; checked = !checked
  ; truths = Hashtbl.to_alist truths |> List.sort ~compare:[%compare: string * int]
  ; safe = !safe
  ; waiting = !waiting
  ; unsound = List.rev !unsound
  ; by_class = !by_class
  ; refused = !refused
  }
;;

let precision (safe, admitted) =
  if safe = 0
  then "-"
  else sprintf "%.2f%%" (100. *. Float.of_int admitted /. Float.of_int safe)
;;

let print ?(top = 10) ?(witness = false) (r : Report.t) =
  print_s
    [%message
      ""
        ~bound:(r.bound : Bound.t)
        ~programs:(r.programs : int)
        ~out_of_scope:(r.out_of_scope : int)
        ~checked:(r.checked : int)
        ~truths:(r.truths : (string * int) list)
        ~safe_admitted:(r.safe : int * int)
        ~precision:(precision r.safe : string)
        ~waiting_admitted:(r.waiting : int * int)
        ~precision_waiting:(precision r.waiting : string)
        ~unsound:(r.unsound : string list)];
  List.iter r.by_class ~f:(fun (class_, (safe, admitted)) ->
    print_s
      [%message
        ""
          (class_ : Class.t)
          (safe : int)
          (admitted : int)
          ~precision:(precision (safe, admitted) : string)]);
  List.sort
    r.refused
    ~compare:
      (fun
        ((waits, _, _), (count, first, _)) ((waits', _, _), (count', first', _)) ->
      [%compare: bool * int * int] (waits', count', first) (waits, count, first'))
  |> Fn.flip List.take top
  |> List.iter ~f:(fun ((waits, shape, refusal), (count, _, example)) ->
    let table = if witness then Some (table_exists example) else None in
    print_s
      [%message
        ""
          (count : int)
          (waits : bool)
          (shape : Class.t list)
          (refusal : (Class.t * string) list)
          ~example:(to_string example)
          (table : (bool option[@sexp.option]))])
;;
