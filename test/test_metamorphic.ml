open! Core
open Protocol_emulator

(* Metamorphic tests of the analyser and the kernel (Chen, Cheung and Yiu 1998), with dead
   code changed as in EMI (Le, Afshari and Su, PLDI 2014): each changes a program in a way
   whose effect on every row and verdict is known in advance, on the library and on random
   programs. A violation prints the program, the change and the row. *)

let memory = 1 lsl Isa.pc_bits
let max_delay ~side_set_count = (1 lsl (Isa.delay_bits - side_set_count)) - 1
let max_period = (1 lsl Isa.data_bits) - 1

module Subject = struct
  type t =
    { name : string
    ; config : Program_config.t
    ; program : Asm.Program.t
    ; period : int option
    ; period_floor : int option
    ; single_capture_edge : bool
    }
end

(* a floor is checked alone, as [Timed_program.check] does *)
let library =
  List.map
    ((Library.certified @ Library.time_triggered) @ [ Library.stamped ])
    ~f:(fun (c : Certified.t) ->
      { Subject.name = c.name
      ; config = c.config
      ; program = Asm.assemble c.source |> ok_exn
      ; period = (if Option.is_some c.period_floor then None else c.period)
      ; period_floor = c.period_floor
      ; single_capture_edge = c.single_capture_edge
      })
;;

(* A loop after [set p] and a deadline a few cycles ahead, of straight runs, deadline
   waits, counted loops, jumps over one word and pin waits that take a new deadline, with
   mostly short delays, so that many meet their deadlines. *)
let random_subject seed =
  let random = Splittable_random.of_int seed in
  let int lo hi = Splittable_random.int random ~lo ~hi in
  let side_set_count = int 0 Isa.max_side_set in
  let op op =
    Isa.Op
      { op
      ; delay = (if int 0 7 = 0 then int 0 (max_delay ~side_set_count) else int 0 1)
      ; side_set = int 0 ((1 lsl side_set_count) - 1)
      }
  in
  let plain () : Isa.t =
    match int 0 4 with
    | 0 -> op (Set { dest = Pins; value = int 0 1 })
    | 1 -> op (Sys Nop)
    | 2 -> op (Set { dest = Y; value = int 0 31 })
    | 3 -> op (In { source = Pins; count = 1 })
    | _ -> op (Mov { dest = Pins; op = Copy; source = Y })
  in
  let anchor () : Isa.t list =
    [ Op { op = Mov { dest = T; op = Copy; source = Now }; delay = 0; side_set = 0 }
    ; Op { op = Alu { dest = T; op = Add; operand = Imm 7 }; delay = 0; side_set = 0 }
    ]
  in
  let piece pc : Isa.t list =
    match int 0 6 with
    | 0 | 1 -> List.init (int 1 3) ~f:(fun _ -> plain ())
    | 2 -> [ op (Wait (Deadline { advance = true })) ]
    | 3 ->
      [ op (Alu { dest = T; op = Add; operand = Imm (int 0 7) })
      ; op (Wait (Deadline { advance = false }))
      ]
    | 4 ->
      [ op (Set { dest = X; value = int 0 3 })
      ; plain ()
      ; Jmp { cond = X_dec; target = pc + 1 }
      ]
    | 5 -> [ Jmp { cond = Pin; target = pc + 2 }; plain () ]
    | _ ->
      op (Wait (Pin_level { pin = int 0 4; level = Splittable_random.bool random }))
      :: anchor ()
  in
  let start = op (Set { dest = P; value = int 16 31 }) :: anchor () in
  let loop = List.length start in
  let body =
    List.fold
      (List.init (int 2 8) ~f:Fn.id)
      ~init:[]
      ~f:(fun body _ -> body @ piece (loop + List.length body))
  in
  { Subject.name = [%string "random %{seed#Int}"]
  ; config = { Program_config.default with side_set_count }
  ; program =
      { side_set_count
      ; wrap_bottom = Program_config.default.wrap_bottom
      ; wrap_top = Program_config.default.wrap_top
      ; instructions =
          start
          @ body
          @ [ op (Wait (Deadline { advance = true }))
            ; Jmp { cond = Always; target = loop }
            ]
      }
  ; period = None
  ; period_floor = None
  ; single_capture_edge = false
  }
;;

let random_subjects = List.init 100 ~f:random_subject

(* The analyser's rows, the pcs it refuses and, if run, the pcs the kernel rejects on
   them, at each end of a floor, with pc 0 as ["open"] if that is what fails. *)
module Outcome = struct
  type t =
    { rows : Analyser.Row.t list
    ; refused : int list
    ; rejected : (int * string list) list option
    }

  (* by every check that ran *)
  let accepted t = List.is_empty t.refused && Option.for_all t.rejected ~f:List.is_empty
  let row t pc = List.find t.rows ~f:(fun (r : Analyser.Row.t) -> r.pc = pc)
end

module K = Kernel.Make (Hardcaml.Bits)

(* [Kernel.check] without spacing is [rejections] and an open row at pc 0. *)
let outcome ?(kernel = true) (s : Subject.t) =
  let { Subject.period; period_floor; single_capture_edge; _ } = s in
  let config = Asm.Program.configure s.program s.config in
  let rows =
    Analyser.analyse
      ?period
      ?period_floor
      ~single_capture_edge
      ~config
      s.program.instructions
  in
  let words = Asm.Program.words s.program |> ok_exn in
  let table = Kernel.Table.of_analyser rows in
  let check period =
    (if Hardcaml.Bits.to_bool (K.starts_open table.(0) ~spacing:K.no_spacing)
     then []
     else [ 0, [ "open" ] ])
    @ List.map
        (Kernel.rejections ?period ~single_capture_edge ~config ~words table)
        ~f:(fun { Kernel.Rejection.pc; fails } -> pc, fails)
  in
  let rejected =
    Option.some_if kernel ()
    |> Option.map ~f:(fun () ->
      (match period_floor with
       | None -> check period
       | Some floor -> check (Some floor) @ check (Some max_period))
      |> List.dedup_and_sort ~compare:[%compare: int * string list])
  in
  { Outcome.rows
  ; refused =
      List.filter_map rows ~f:(fun r ->
        Option.some_if (r.may_miss || r.may_underrun) r.pc)
  ; rejected
  }
;;

let retarget (t : Isa.t) ~f : Isa.t =
  match t with
  | Jmp { cond; target } -> Jmp { cond; target = f target }
  | Op _ -> t
;;

(* [inserted] put before pc [at], with the pcs the rest moves to. Jumps to [at] land on it
   if [entered]; a wrap after [at - 1] runs on into it if [continues]. None if it does not
   fit, past the program reading [jmp 0] as before. *)
let insert (p : Asm.Program.t) ~at ~entered ~continues inserted =
  let m = List.length inserted in
  let move pc = if pc < at then pc else pc + m in
  let into target = if target = at && entered then target else move target in
  let before = List.take p.instructions at in
  let after = List.drop p.instructions at in
  let program =
    { p with
      instructions =
        List.map before ~f:(retarget ~f:into)
        @ inserted
        @ List.map after ~f:(retarget ~f:into)
    ; wrap_bottom = into p.wrap_bottom
    ; wrap_top =
        (if p.wrap_top = memory - 1
         then p.wrap_top
         else if p.wrap_top = at - 1 && continues
         then p.wrap_top + m
         else move p.wrap_top)
    }
  in
  Option.some_if
    (List.length program.instructions < memory
     && Result.is_ok (Asm.Program.words program)
     && program.wrap_top < memory)
    (program, move)
;;

(* The whole memory turned round by [by], jumps and wrap with it: the core starts at the
   [jmp] the word past the program's end becomes. *)
let rotate (p : Asm.Program.t) ~by =
  let move pc = (pc + by) % memory in
  let image = Array.create ~len:memory (Isa.Jmp { cond = Always; target = 0 }) in
  List.iteri
    (p.instructions
     @ List.init
         (memory - List.length p.instructions)
         ~f:(fun _ -> Isa.Jmp { cond = Always; target = 0 }))
    ~f:(fun pc t -> image.(move pc) <- retarget t ~f:move);
  ( { p with
      instructions = Array.to_list image
    ; wrap_bottom = move p.wrap_bottom
    ; wrap_top = move p.wrap_top
    }
  , move )
;;

let with_delay (t : Isa.t) delay : Isa.t =
  match t with
  | Op o -> Op { o with delay }
  | Jmp _ -> t
;;

let side_set (t : Isa.t) =
  match t with
  | Op { side_set; _ } -> side_set
  | Jmp _ -> 0
;;

(* nops that take [n] cycles between them *)
let nops ~side_set_count ~side_set n =
  let most = max_delay ~side_set_count + 1 in
  (List.init (n / most) ~f:(fun _ -> most) @ if n % most = 0 then [] else [ n % most ])
  |> List.map ~f:(fun cycles -> Isa.Op { op = Sys Nop; delay = cycles - 1; side_set })
;;

let is_deadline (t : Isa.t) =
  match t with
  | Op { op = Wait (Deadline _); _ } -> true
  | Op _ | Jmp _ -> false
;;

(* what a row says of time and registers, its pins and side-set aside *)
let timing (r : Analyser.Row.t) =
  [%message
    ""
      ~phase:(r.phase : Interval.t)
      ~slack:(r.slack : Interval.t option)
      ~may_miss:(r.may_miss : bool)
      ~slope:(r.slope : int)
      ~offset:(r.offset : Interval.t)
      ~x:(r.x : Interval.t)
      ~y:(r.y : Interval.t)
      ~period:(r.period : Interval.t)
      ~since_arm:(r.since_arm : Interval.t option)
      ~captured:(r.captured : bool)
      ~awaiting:(r.awaiting : bool)
      ~may_underrun:(r.may_underrun : bool)]
;;

(* [r] at [move]d pcs, its ways in too *)
let moved ~move (r : Analyser.Row.t) =
  let from = List.map ~f:(fun (pc, i) -> move pc, i) in
  { r with pc = move r.pc; gaps = from r.gaps; since_edge = from r.since_edge }
;;

(* the whole row but its pc and word, leaving out ways in from [added] pcs *)
let whole ~added (r : Analyser.Row.t) =
  let from ways =
    List.filter ways ~f:(fun (pc, _) -> not (List.mem added pc ~equal:Int.equal))
    |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)
  in
  [%sexp_of: Analyser.Row.t]
    { r with
      pc = 0
    ; instruction = Jmp { cond = Always; target = 0 }
    ; gaps = from r.gaps
    ; since_edge = from r.since_edge
    }
;;

(* Every row of [before] reads [expect] of it at its moved pc in [after], and [after]
   reaches no other pc but [added]. *)
let rows_moved ~move ?(added = []) ~expect ~view (before : Outcome.t) (after : Outcome.t) =
  let reached = List.map before.rows ~f:(fun r -> move r.pc) @ added |> Int.Set.of_list in
  List.filter_map before.rows ~f:(fun r ->
    let pc = move r.pc in
    match Outcome.row after pc with
    | None -> Some [%message "row not reached" (r.pc : int)]
    | Some a ->
      let expected = view (expect r) in
      let got = view a in
      Option.some_if
        (not (Sexp.equal expected got))
        [%message "row" (r.pc : int) (pc : int) (expected : Sexp.t) (got : Sexp.t)])
  @ List.filter_map after.rows ~f:(fun a ->
    Option.some_if
      (not (Set.mem reached a.pc))
      [%message "row reached only after" (a.pc : int)])
;;

module Tally = struct
  type t =
    { relation : string
    ; programs : String.Hash_set.t
    ; mutable variants : int
    ; mutable kernel : int
    ; mutable turns : int
    ; mutable accepted : int
    ; mutable refused : int
    ; mutable violations : (bool * Sexp.t) list
    }

  let create relation =
    { relation
    ; programs = String.Hash_set.create ()
    ; variants = 0
    ; kernel = 0
    ; turns = 0
    ; accepted = 0
    ; refused = 0
    ; violations = []
    }
  ;;

  (* The kernel takes one variant in [kernel_every], the analyser every one. *)
  let kernel_every = 5

  let turn t =
    t.turns <- t.turns + 1;
    t.turns % kernel_every = 1
  ;;

  (* a variant's outcome, and what it breaks, if anything *)
  let add t (s : Subject.t) ~before ~change (after : Outcome.t) broken =
    Hash_set.add t.programs s.name;
    t.variants <- t.variants + 1;
    if Option.is_some after.rejected then t.kernel <- t.kernel + 1;
    if Outcome.accepted after
    then t.accepted <- t.accepted + 1
    else t.refused <- t.refused + 1;
    if not (List.is_empty broken)
    then (
      let broken = List.take broken 2 in
      t.violations
      <- ( Outcome.accepted before
         , [%message s.name (change : Sexp.t) (broken : Sexp.t list)] )
         :: t.violations)
  ;;

  (* the first violations on accepted programs and on refused ones *)
  let print t =
    let violations = List.rev t.violations in
    let on_accepted = List.filter_map violations ~f:(fun (a, v) -> Option.some_if a v) in
    let on_refused =
      List.filter_map violations ~f:(fun (a, v) -> Option.some_if (not a) v)
    in
    print_s
      [%message
        t.relation
          ~programs:(Hash_set.length t.programs : int)
          ~variants:(t.variants : int)
          ~kernel_checked:(t.kernel : int)
          ~accepted:(t.accepted : int)
          ~refused:(t.refused : int)
          ~violations_on_accepted:(List.length on_accepted : int)
          ~violations_on_refused:(List.length on_refused : int)];
    List.iter (List.take on_accepted 2 @ List.take on_refused 1) ~f:print_s
  ;;
end

let sample random l ~n =
  List.map l ~f:(fun x -> Splittable_random.int random ~lo:0 ~hi:(1 lsl 29), x)
  |> List.stable_sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)
  |> List.map ~f:snd
  |> Fn.flip List.take n
;;

let subjects = List.mapi (library @ random_subjects) ~f:(fun i s -> i, s, outcome s)
let library_names = List.map library ~f:(fun s -> s.name) |> String.Set.of_list

let tallies relation =
  ( Tally.create [%string "%{relation}, library"]
  , Tally.create [%string "%{relation}, random"] )
;;

let tally (library, random) (s : Subject.t) =
  if Set.mem library_names s.name then library else random
;;

let print_tallies (library, random) =
  Tally.print library;
  Tally.print random
;;

(* The reachable deadline waits a delay can go in front of, with their least slack. *)
let waits (before : Outcome.t) =
  List.filter_map before.rows ~f:(fun r ->
    match r.slack with
    | Some { lo = Some s; _ } when is_deadline r.instruction && r.pc > 0 -> Some (r, s)
    | _ -> None)
;;

let in_time (after : Outcome.t) pc =
  List.mem after.refused pc ~equal:Int.equal
  && Option.for_all after.rejected ~f:(fun rejected ->
    List.exists rejected ~f:(fun (p, fails) ->
      p = pc && List.mem fails "in time" ~equal:String.equal))
;;

(* [n] more cycles on every way into the wait at [w] with least slack [s]: accepted with
   its slack [n] less and every other row as it was while [n <= s], refused at the wait
   after. *)
let check_delay (before : Outcome.t) (after : Outcome.t) ~move ~added ~w ~s ~n =
  if n <= s
  then (
    let expect (r : Analyser.Row.t) =
      if r.pc <> w.Analyser.Row.pc
      then r
      else
        { r with
          phase = Interval.shift r.phase n
        ; slack = Option.map r.slack ~f:(fun s -> Interval.shift s (-n))
        ; since_arm = Option.map r.since_arm ~f:(fun a -> Interval.shift a n)
        }
    in
    (if Outcome.accepted after then [] else [ [%message "refused"] ])
    @ rows_moved ~move ~added ~expect ~view:timing before after)
  else if in_time after (move w.pc)
  then []
  else
    [ [%message
        "not refused in time at the wait"
          (after.refused : int list)
          (after.rejected : (int * string list) list option)]
    ]
;;

let delay_amounts random s =
  List.dedup_and_sort
    ~compare:Int.compare
    ([ 1; s; s + 1 ] @ if s > 1 then [ Splittable_random.int random ~lo:1 ~hi:s ] else [])
  |> List.filter ~f:(fun n -> n >= 1)
;;

let junk random ~side_set_count n =
  let rec word () =
    let t =
      Quickcheck.Generator.generate
        (Test_isa.Generator.instruction ~side_set_count)
        ~size:10
        ~random
    in
    if Result.is_ok (Isa.to_word ~side_set_count t) then t else word ()
  in
  List.init n ~f:(fun _ -> word ())
;;

let falls_through ~(config : Program_config.t) pc (t : Isa.t) =
  match t with
  | Jmp { cond = Always; _ } | Op { op = Sys Halt; _ } -> false
  | Jmp _ | Op _ -> pc <> config.wrap_top || config.wrap_top = memory - 1
;;

let%expect_test "a delay before a deadline wait takes exactly its slack" =
  let nops_tally = tallies "nops before a wait" in
  let field_tally = tallies "delay field before a wait" in
  let jump_tally = tallies "jump over dead code before a wait" in
  List.iter subjects ~f:(fun (seed, (s : Subject.t), before) ->
    if Outcome.accepted before && not (List.is_empty (waits before))
    then (
      let random = Splittable_random.of_int seed in
      let side_set_count = s.program.side_set_count in
      let configured = Asm.Program.configure s.program s.config in
      List.iter
        (sample random (waits before) ~n:3)
        ~f:(fun ((w : Analyser.Row.t), slack) ->
          List.iter (delay_amounts random slack) ~f:(fun n ->
            let inserted = nops ~side_set_count ~side_set:(side_set w.instruction) n in
            Option.iter
              (insert s.program ~at:w.pc ~entered:true ~continues:false inserted)
              ~f:(fun (program, move) ->
                let after =
                  outcome ~kernel:(Tally.turn (tally nops_tally s)) { s with program }
                in
                let added = List.init (List.length inserted) ~f:(fun i -> w.pc + i) in
                Tally.add
                  (tally nops_tally s)
                  s
                  ~before
                  ~change:[%message "nops" (w.pc : int) (n : int) (slack : int)]
                  after
                  (check_delay before after ~move ~added ~w ~s:slack ~n)));
          (* EMI: a jump over dead code is a delay of the jump's cycles *)
          let m = Splittable_random.int random ~lo:1 ~hi:8 in
          let inserted =
            Isa.Jmp { cond = Always; target = w.pc + 1 + m }
            :: junk random ~side_set_count m
          in
          Option.iter
            (insert s.program ~at:w.pc ~entered:true ~continues:false inserted)
            ~f:(fun (program, move) ->
              let after =
                outcome ~kernel:(Tally.turn (tally jump_tally s)) { s with program }
              in
              Tally.add
                (tally jump_tally s)
                s
                ~before
                ~change:[%message "jump" (w.pc : int) (m : int) (slack : int)]
                after
                (check_delay
                   before
                   after
                   ~move
                   ~added:(List.init (m + 1) ~f:(fun i -> w.pc + i))
                   ~w
                   ~s:slack
                   ~n:Isa.jmp_cycles));
          (* the word before is the only way in: put the cycles in its delay field *)
          let j = w.pc - 1 in
          let only_way_in =
            configured.wrap_bottom <> w.pc
            && configured.wrap_top <> j
            && List.for_all before.rows ~f:(fun r ->
              match r.instruction with
              | Jmp { target; _ } -> target <> w.pc
              | Op _ -> true)
          in
          match Outcome.row before j with
          | Some { instruction = Op { op; delay; _ } as instruction; _ }
            when only_way_in && not ([%equal: Isa.Op.t] op (Sys Halt)) ->
            List.iter (delay_amounts random slack) ~f:(fun n ->
              if delay + n <= max_delay ~side_set_count
              then (
                let program =
                  { s.program with
                    instructions =
                      List.mapi s.program.instructions ~f:(fun pc t ->
                        if pc = j then with_delay instruction (delay + n) else t)
                  }
                in
                let after =
                  outcome ~kernel:(Tally.turn (tally field_tally s)) { s with program }
                in
                Tally.add
                  (tally field_tally s)
                  s
                  ~before
                  ~change:[%message "delay field" (j : int) (n : int) (slack : int)]
                  after
                  (check_delay before after ~move:Fn.id ~added:[] ~w ~s:slack ~n)))
          | _ -> ())));
  print_tallies nops_tally;
  print_tallies jump_tally;
  print_tallies field_tally;
  [%expect
    {|
    ("nops before a wait, library" (programs 44) (variants 417)
     (kernel_checked 84) (accepted 294) (refused 123) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("nops before a wait, random" (programs 26) (variants 183)
     (kernel_checked 37) (accepted 128) (refused 55) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("jump over dead code before a wait, library" (programs 44) (variants 125)
     (kernel_checked 25) (accepted 106) (refused 19) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("jump over dead code before a wait, random" (programs 26) (variants 55)
     (kernel_checked 11) (accepted 45) (refused 10) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("delay field before a wait, library" (programs 37) (variants 229)
     (kernel_checked 46) (accepted 169) (refused 60) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("delay field before a wait, random" (programs 24) (variants 120)
     (kernel_checked 24) (accepted 86) (refused 34) (violations_on_accepted 0)
     (violations_on_refused 0))
    |}]
;;

(* The analyser's refusals of [before], at moved pcs. *)
let refusals_moved ~move (before : Outcome.t) (after : Outcome.t) =
  let refused = List.map before.refused ~f:move |> List.sort ~compare:Int.compare in
  let got_refused = List.sort after.refused ~compare:Int.compare in
  if [%equal: int list] refused got_refused
  then []
  else [ [%message "analyser" (refused : int list) (got_refused : int list)] ]
;;

(* The same, and the kernel's where it ran on both. *)
let verdicts_moved ~move (before : Outcome.t) (after : Outcome.t) =
  let sort = List.sort ~compare:[%compare: int * string list] in
  refusals_moved ~move before after
  @
  match before.rejected, after.rejected with
  | Some rejected, Some got_rejected ->
    let rejected = List.map rejected ~f:(fun (pc, fails) -> move pc, fails) |> sort in
    let got_rejected = sort got_rejected in
    if [%equal: (int * string list) list] rejected got_rejected
    then []
    else
      [ [%message
          "kernel"
            (rejected : (int * string list) list)
            (got_rejected : (int * string list) list)]
      ]
  | _ -> []
;;

let%expect_test "dead code changes nothing" =
  let padding = tallies "dead code after a word that never falls through" in
  List.iter subjects ~f:(fun (seed, (s : Subject.t), before) ->
    let random = Splittable_random.of_int seed in
    let side_set_count = s.program.side_set_count in
    let config = Asm.Program.configure s.program s.config in
    (* the [jmp 0] past the end, written out, is the same program *)
    let program =
      { s.program with
        instructions = s.program.instructions @ [ Jmp { cond = Always; target = 0 } ]
      }
    in
    let ends =
      List.filter_mapi program.instructions ~f:(fun pc t ->
        Option.some_if (not (falls_through ~config pc t)) (pc + 1))
    in
    List.iter (sample random ends ~n:2) ~f:(fun at ->
      let m = Splittable_random.int random ~lo:1 ~hi:8 in
      Option.iter
        (insert
           program
           ~at
           ~entered:false
           ~continues:false
           (junk random ~side_set_count m))
        ~f:(fun (program, move) ->
          let after = outcome ~kernel:(Tally.turn (tally padding s)) { s with program } in
          Tally.add
            (tally padding s)
            s
            ~before
            ~change:[%message "dead code" (at : int) (m : int)]
            after
            (verdicts_moved ~move before after
             @ rows_moved ~move ~expect:(moved ~move) ~view:(whole ~added:[]) before after
            ))));
  print_tallies padding;
  [%expect
    {|
    ("dead code after a word that never falls through, library" (programs 51)
     (variants 102) (kernel_checked 21) (accepted 102) (refused 0)
     (violations_on_accepted 0) (violations_on_refused 0))
    ("dead code after a word that never falls through, random" (programs 100)
     (variants 200) (kernel_checked 40) (accepted 52) (refused 148)
     (violations_on_accepted 0) (violations_on_refused 0))
    |}]
;;

let%expect_test "moving the program in memory changes nothing" =
  let relocation = tallies "program moved in memory" in
  List.iter subjects ~f:(fun (seed, (s : Subject.t), before) ->
    let random = Splittable_random.of_int seed in
    let length = List.length s.program.instructions in
    let room = memory - length - 1 in
    if room >= 1
    then
      List.iter
        (List.dedup_and_sort
           ~compare:Int.compare
           [ Splittable_random.int random ~lo:1 ~hi:room; room ])
        ~f:(fun by ->
          let program, move = rotate s.program ~by in
          let after =
            outcome ~kernel:(Tally.turn (tally relocation s)) { s with program }
          in
          Tally.add
            (tally relocation s)
            s
            ~before
            ~change:[%message "moved" (by : int)]
            after
            (verdicts_moved ~move before after
             @ rows_moved
                 ~move
                 ~added:[ 0 ]
                 ~expect:(moved ~move)
                 ~view:(whole ~added:[ 0 ])
                 before
                 after)));
  print_tallies relocation;
  [%expect
    {|
    ("program moved in memory, library" (programs 51) (variants 102)
     (kernel_checked 21) (accepted 102) (refused 0) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("program moved in memory, random" (programs 100) (variants 200)
     (kernel_checked 40) (accepted 52) (refused 148) (violations_on_accepted 0)
     (violations_on_refused 0))
    |}]
;;

let starts_flip ~(config : Program_config.t) (t : Isa.t) =
  config.manchester
  &&
  match t with
  | Op { op = Out { dest = Pins; count = 1 }; _ } -> true
  | Op _ | Jmp _ -> false
;;

let timing_and_pins (r : Analyser.Row.t) =
  [%message
    "" ~_:(timing r : Sexp.t) ~pin_event:(r.pin_event : Analyser.Pin_event.t option)]
;;

let%expect_test "a delay split into the word and a nop changes nothing" =
  let others = tallies "delay split into the word and a nop" in
  let set_x = tallies "delay of a set x split into it and a nop" in
  List.iter subjects ~f:(fun (seed, (s : Subject.t), before) ->
    let random = Splittable_random.of_int seed in
    let config = Asm.Program.configure s.program s.config in
    let delayed =
      List.filter before.rows ~f:(fun r ->
        r.pc < List.length s.program.instructions
        &&
        match r.instruction with
        | Op { op = Sys Halt; _ } -> false
        | Op { delay; _ } -> delay >= 1 && not (starts_flip ~config r.instruction)
        | Jmp _ -> false)
    in
    List.iter (sample random delayed ~n:4) ~f:(fun j ->
      match j.instruction with
      | Jmp _ -> ()
      | Op { op; delay; side_set } ->
        let split =
          match op with
          | Set { dest = X; _ } -> set_x
          | _ -> others
        in
        let first = Splittable_random.int random ~lo:0 ~hi:(delay - 1) in
        let nop = Isa.Op { op = Sys Nop; delay = delay - 1 - first; side_set } in
        let program =
          { s.program with
            instructions =
              List.mapi s.program.instructions ~f:(fun pc t ->
                if pc = j.pc then with_delay t first else t)
          }
        in
        Option.iter
          (insert program ~at:(j.pc + 1) ~entered:false ~continues:true [ nop ])
          ~f:(fun (program, move) ->
            let after = outcome ~kernel:(Tally.turn (tally split s)) { s with program } in
            let kernel_agrees =
              match before.rejected, after.rejected with
              | Some before, Some after ->
                Bool.equal (List.is_empty before) (List.is_empty after)
              | _ -> true
            in
            Tally.add
              (tally split s)
              s
              ~before
              ~change:[%message "split" (j.pc : int) (delay : int) (first : int)]
              after
              ((if kernel_agrees then [] else [ [%message "kernel verdict changed"] ])
               @ refusals_moved ~move before after
               @ rows_moved
                   ~move
                   ~added:[ j.pc + 1 ]
                   ~expect:Fn.id
                   ~view:timing_and_pins
                   before
                   after))));
  print_tallies others;
  print_tallies set_x;
  [%expect
    {|
    ("delay split into the word and a nop, library" (programs 7) (variants 19)
     (kernel_checked 4) (accepted 19) (refused 0) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("delay split into the word and a nop, random" (programs 100) (variants 337)
     (kernel_checked 68) (accepted 84) (refused 253) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("delay of a set x split into it and a nop, library" (programs 0)
     (variants 0) (kernel_checked 0) (accepted 0) (refused 0)
     (violations_on_accepted 0) (violations_on_refused 0))
    ("delay of a set x split into it and a nop, random" (programs 24)
     (variants 31) (kernel_checked 7) (accepted 0) (refused 31)
     (violations_on_accepted 0) (violations_on_refused 0))
    |}]
;;

(* What the split above found: a nop between [set x] and its counted loop lost the loop's
   exit phase, and a program accepted without it was refused. *)
let%expect_test "a nop between set x and its counted loop keeps the loop's exit phase" =
  let source ~between =
    String.concat
      ~sep:"\n"
      ([ "set p, 31"; "mov t, now"; "add t, 7"; "wait t+"; "loop:"; "set x, 3 [1]" ]
       @ between
       @ [ "count:"; "nop [1]"; "jmp x--, count"; "wait t+"; "jmp loop" ])
  in
  List.iter
    [ "set x, 3 [1]", source ~between:[]
    ; ( "set x, 3; nop"
      , source ~between:[ "nop" ]
        |> String.substr_replace_first ~pattern:"set x, 3 [1]" ~with_:"set x, 3" )
    ]
    ~f:(fun (name, source) ->
      match Timed_program.check ~config:Program_config.default source with
      | Ok t ->
        print_s [%message name ~accepted:(Timed_program.verdict t : Analyser.Verdict.t)]
      | Error { faults; _ } ->
        print_s [%message name ~refused:(faults : Timed_program.Fault.t list)]);
  [%expect
    {|
    ("set x, 3 [1]" (accepted ((words 9) (deadline_waits 2) (worst_slack (5)))))
    ("set x, 3; nop"
     (accepted ((words 10) (deadline_waits 2) (worst_slack (5)))))
    |}]
;;

(* [wait t] is [alu t, sub a; wait t; alu t, add a; wait t]: the first wait has [a + 1]
   less slack, the second [a - 2] exactly, and the rest is as it was, while [a] is below
   the slack; at the slack the first wait is refused. *)
let%expect_test "a deadline wait split at an earlier deadline changes nothing after it" =
  let split = tallies "deadline wait split in two" in
  List.iter subjects ~f:(fun (seed, (s : Subject.t), before) ->
    let random = Splittable_random.of_int seed in
    let config = Asm.Program.configure s.program s.config in
    let most = Isa.Field.mask Isa.Field.alu_operand in
    if Outcome.accepted before && config.period_fraction = 0
    then
      List.iter
        (sample random (List.filter (waits before) ~f:(fun (_, s) -> s >= 3)) ~n:2)
        ~f:(fun ((w : Analyser.Row.t), slack) ->
          let amounts =
            Splittable_random.int random ~lo:2 ~hi:(Int.min most (slack - 1))
            :: (if slack <= most then [ slack ] else [])
          in
          List.iter amounts ~f:(fun a ->
            let side_set = side_set w.instruction in
            let op op = Isa.Op { op; delay = 0; side_set } in
            let inserted =
              [ op (Alu { dest = T; op = Sub; operand = Imm a })
              ; op (Wait (Deadline { advance = false }))
              ; op (Alu { dest = T; op = Add; operand = Imm a })
              ]
            in
            Option.iter
              (insert s.program ~at:w.pc ~entered:true ~continues:false inserted)
              ~f:(fun (program, move) ->
                let after =
                  outcome ~kernel:(Tally.turn (tally split s)) { s with program }
                in
                let first = w.pc + 1 in
                let broken =
                  if a < slack
                  then (
                    let expect_first =
                      Option.map w.slack ~f:(fun s -> Interval.shift s (-(a + 1)))
                    in
                    let expect_second = Interval.exactly (a - 2) in
                    let got_first =
                      Option.bind (Outcome.row after first) ~f:(fun r -> r.slack)
                    in
                    let got_second =
                      Option.bind (Outcome.row after (move w.pc)) ~f:(fun r -> r.slack)
                    in
                    (if Outcome.accepted after then [] else [ [%message "refused"] ])
                    @ (if [%equal: Interval.t option] expect_first got_first
                       then []
                       else
                         [ [%message
                             "first wait"
                               (expect_first : Interval.t option)
                               (got_first : Interval.t option)]
                         ])
                    @ (if [%equal: Interval.t option] (Some expect_second) got_second
                       then []
                       else
                         [ [%message
                             "second wait"
                               (expect_second : Interval.t)
                               (got_second : Interval.t option)]
                         ])
                    @ rows_moved
                        ~move
                        ~added:[ w.pc; w.pc + 1; w.pc + 2; move w.pc ]
                        ~expect:Fn.id
                        ~view:timing
                        { before with
                          rows = List.filter before.rows ~f:(fun r -> r.pc <> w.pc)
                        }
                        after)
                  else if in_time after first
                  then []
                  else [ [%message "not refused in time at the first wait"] ]
                in
                Tally.add
                  (tally split s)
                  s
                  ~before
                  ~change:[%message "split" (w.pc : int) (a : int) (slack : int)]
                  after
                  broken))));
  print_tallies split;
  [%expect
    {|
    ("deadline wait split in two, library" (programs 40) (variants 121)
     (kernel_checked 25) (accepted 78) (refused 43) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("deadline wait split in two, random" (programs 24) (variants 61)
     (kernel_checked 13) (accepted 40) (refused 21) (violations_on_accepted 0)
     (violations_on_refused 0))
    |}]
;;

(* A later deadline on every pass: a longer period, or a larger [set p]. *)
let%expect_test "a longer period lowers no slack and refuses nothing more" =
  let longer = tallies "longer period" in
  List.iter subjects ~f:(fun (_, (s : Subject.t), before) ->
    let longer_by k =
      match s.period, s.period_floor with
      | Some p, _ -> Option.some_if (p + k <= max_period) { s with period = Some (p + k) }
      | None, Some f ->
        Option.some_if (f + k <= max_period) { s with period_floor = Some (f + k) }
      | None, None ->
        (* every [set p] raised alike *)
        let raised =
          List.map s.program.instructions ~f:(fun (t : Isa.t) ->
            match t with
            | Op ({ op = Set { dest = P; value }; _ } as o) ->
              Isa.Op { o with op = Set { dest = P; value = value + k } }
            | t -> t)
        in
        let program = { s.program with instructions = raised } in
        Option.some_if
          ((not ([%equal: Isa.t list] raised s.program.instructions))
           && Result.is_ok (Asm.Program.words program))
          { s with program }
    in
    List.iter [ 1; 4; 100 ] ~f:(fun k ->
      Option.iter (longer_by k) ~f:(fun longer_subject ->
        let after = outcome ~kernel:(Tally.turn (tally longer s)) longer_subject in
        let lowered =
          List.filter_map before.rows ~f:(fun r ->
            match r.slack, Outcome.row after r.pc with
            | Some { lo = Some lo; _ }, Some a ->
              let got = Option.bind a.slack ~f:(fun s -> s.lo) in
              if Option.value_map got ~default:false ~f:(fun got -> got >= lo)
              then None
              else
                Some [%message "slack lowered" (r.pc : int) (lo : int) (got : int option)]
            | _ -> None)
        in
        let refused_more =
          List.filter after.refused ~f:(fun pc ->
            not (List.mem before.refused pc ~equal:Int.equal))
        in
        let kernel =
          match after.rejected with
          | Some (_ :: _ as rejected) when Outcome.accepted before ->
            [ [%message "kernel refuses" (rejected : (int * string list) list)] ]
          | _ -> []
        in
        Tally.add
          (tally longer s)
          s
          ~before
          ~change:[%message "longer" (k : int)]
          after
          (lowered
           @ (if List.is_empty refused_more
              then []
              else [ [%message (refused_more : int list)] ])
           @ kernel))));
  print_tallies longer;
  [%expect
    {|
    ("longer period, library" (programs 40) (variants 98) (kernel_checked 20)
     (accepted 98) (refused 0) (violations_on_accepted 0)
     (violations_on_refused 0))
    ("longer period, random" (programs 93) (variants 172) (kernel_checked 35)
     (accepted 46) (refused 126) (violations_on_accepted 0)
     (violations_on_refused 0))
    |}]
;;
