open! Core
open Protocol_emulator
open Protocol_emulator_test

(* A Mealy table in data memory, two words an entry at [2 * (state lsl k lor inputs)]: a
   time, then the outputs (low byte) and the next state (high byte). Entry 0 is the first.
   Two interpreters read it:
   - [Hold_p]: the entry's outputs show for [time] cycles, at least [floor Hold_p]. The
     time goes through [p], so the kernel checks it under the period-floor premise.
   - [Dwell_y]: the entry shows [floor Dwell_y + time] cycles after the one before, any
     time. The time goes through [y], with no premise. *)

module Route = struct
  type t =
    | Hold_p
    | Dwell_y
  [@@deriving sexp_of, equal, enumerate]
end

let floor : Route.t -> int = function
  | Hold_p -> 10
  | Dwell_y -> 11
;;

let loop ~k =
  [%string
    {|
    out pins, 8              ; the entry's outputs
    out x, 8                 ; its next state
    in x, %{(8 - k)#Int}
    in pins, %{k#Int}
    in null, 1               ; two words an entry
    mov x, isr               ; seek keeps the low 9 bits
    seek [1]|}]
;;

let interpreter ?floor:f ?(wait = "wait t+") (route : Route.t) ~k =
  let f = Option.value f ~default:(floor route) in
  match route with
  | Hold_p ->
    [%string
      {|
    set x, 0
    seek [1]                 ; data_settle
    out p, 16                ; entry 0's time
    mov t, now
    add t, p
.wrap_target
    wait t+                  ; release, then t <- t + time%{loop ~k}
    out p, 16                ; the next entry's time
.wrap
|}]
  | Dwell_y ->
    [%string
      {|
    set p, %{f#Int}
    set x, 0
    seek [1]                 ; data_settle
    out y, 16                ; entry 0's time
    mov t, now
    add t, p
    add t, y
.wrap_target
    %{wait}                  ; release, then t <- t + floor%{loop ~k}
    out y, 16                ; the next entry's time
    add t, y
.wrap
|}]
;;

let config =
  { Program_config.default with
    out_base = Isa.first_output_pin
  ; out_count = 8
  ; in_base = 0
  ; in_count = 3
  ; out_shift = Right
  ; in_shift = Left
  ; autopull = true
  ; pull_threshold = 16
  ; autopull_data = true
  }
;;

module Entry = struct
  type t =
    { outputs : int
    ; next : int
    ; time : int
    }
end

let words ~k (entry : state:int -> inputs:int -> Entry.t) =
  List.init 256 ~f:(fun i ->
    let (e : Entry.t) = entry ~state:(i lsr k) ~inputs:(i land ((1 lsl k) - 1)) in
    [ e.time; e.outputs lor (e.next lsl 8) ])
  |> List.concat
;;

(* Read off the model once, then checked on random tables: the first release is
   [first + time(entry 0)], outputs show [shows] cycles after a release, and inputs are
   read [samples] cycles after it. *)
let first : Route.t -> int = function
  | Hold_p -> 4
  | Dwell_y -> 16
;;

let shows = 1
let samples = 4

(* The specification: the output byte after every cycle. *)
let reference (route : Route.t) ~k ~entry ~inputs ~cycles =
  let out = Array.create ~len:cycles 0 in
  let rec go ~release (e : Entry.t) =
    if release + shows < cycles
    then (
      for c = release + shows to cycles - 1 do
        out.(c) <- e.outputs
      done;
      let read = inputs (release + samples) land ((1 lsl k) - 1) in
      let (e' : Entry.t) = entry ~state:e.next ~inputs:read in
      let gap =
        match route with
        | Hold_p -> e.time
        | Dwell_y -> floor route + e'.time
      in
      go ~release:(release + gap) e')
  in
  let (e0 : Entry.t) = entry ~state:0 ~inputs:0 in
  go ~release:(first route + e0.time) e0;
  out
;;

let timed ?floor:f ?wait ?period_floor (route : Route.t) ~k =
  let period_floor =
    match route with
    | Hold_p -> Some (Option.value period_floor ~default:(floor route))
    | Dwell_y -> None
  in
  Timed_program.check ?period_floor ~config (interpreter ?floor:f ?wait route ~k)
;;

(* the routes [timed] accepts, which the simulations run *)
let accepted () = List.filter Route.all ~f:(fun route -> Result.is_ok (timed route ~k:3))

let image route ~k =
  let t =
    match timed route ~k with
    | Ok t -> t
    | Error r -> raise_s [%message "refused" (r.error : Error.t)]
  in
  Timed_program.config t, Timed_program.words t
;;

(* Runs the RTL and the model in lockstep; the model's pins after every cycle. *)
let trace ?preload ?data ~cycles ~config ~program ~inputs () =
  let pins = Queue.create () in
  let model, mismatch =
    Lockstep.run
      ?preload
      ?data
      ~cycles
      ~config
      ~program
      ~inputs
      ~react:(fun m -> Queue.enqueue pins m.pin_out)
      ()
  in
  (match mismatch with
   | None -> ()
   | Some (cycle, _, _) -> raise_s [%message "RTL and model differ" (cycle : int)]);
  model, Queue.to_array pins
;;

let outputs pins = Array.map pins ~f:(fun p -> (p lsr Isa.first_output_pin) land 0xff)

(* every change of the watched pins: cycle, pin, level *)
let edges ~watch pins =
  List.concat_mapi (Array.to_list pins) ~f:(fun c p ->
    let before = if c = 0 then p else pins.(c - 1) in
    List.filter_map watch ~f:(fun pin ->
      let level = (p lsr pin) land 1 in
      if c > 0 && level <> (before lsr pin) land 1 then Some (c, pin, level) else None))
;;

let relative = function
  | [] -> []
  | (c0, _, _) :: _ as es -> List.map es ~f:(fun (c, pin, level) -> c - c0, pin, level)
;;

let%expect_test "the kernel on the interpreters, data memory unknown" =
  List.iter Route.all ~f:(fun route ->
    List.iter [ 1; 2; 3; 4 ] ~f:(fun k ->
      match timed route ~k with
      | Ok t ->
        print_s
          [%message
            "accepted"
              (route : Route.t)
              (k : int)
              ~verdict:(Timed_program.verdict t : Analyser.Verdict.t)]
      | Error r ->
        print_s
          [%message
            "refused" (route : Route.t) (k : int) (r.faults : Timed_program.Fault.t list)]));
  [%expect
    {|
    (accepted (route Hold_p) (k 1)
     (verdict ((words 14) (deadline_waits 1) (worst_slack (0)))))
    (accepted (route Hold_p) (k 2)
     (verdict ((words 14) (deadline_waits 1) (worst_slack (0)))))
    (accepted (route Hold_p) (k 3)
     (verdict ((words 14) (deadline_waits 1) (worst_slack (0)))))
    (accepted (route Hold_p) (k 4)
     (verdict ((words 14) (deadline_waits 1) (worst_slack (0)))))
    (accepted (route Dwell_y) (k 1)
     (verdict ((words 17) (deadline_waits 1) (worst_slack (0)))))
    (accepted (route Dwell_y) (k 2)
     (verdict ((words 17) (deadline_waits 1) (worst_slack (0)))))
    (accepted (route Dwell_y) (k 3)
     (verdict ((words 17) (deadline_waits 1) (worst_slack (0)))))
    (accepted (route Dwell_y) (k 4)
     (verdict ((words 17) (deadline_waits 1) (worst_slack (0)))))
    |}];
  List.iter Route.all ~f:(fun route ->
    match timed route ~k:3 with
    | Ok t ->
      print_s [%message (route : Route.t)];
      print_endline (Analyser.to_string ~side_set_count:0 (Timed_program.rows t))
    | Error _ -> ());
  [%expect
    {|
    (route Hold_p)
      0  set x, 0                     phase ?..?
      1  seek [1]                     phase ?..?
      2  out p, 16                    phase ?..?
      3  mov t, now                   phase ?..?
      4  add t, p                     phase 1
      5  wait t+                      phase -65533..0  slack 0..65533
      6  out pins, 8                  phase -65534..-9  edge -65533..-8  jitter 65525  gap ?..?
      7  out x, 8                     phase -65533..-8
      8  in x, 5                      phase -65532..-7
      9  in pins, 3                   phase -65531..-6  sample -65531..-6  jitter 65525
     10  in null, 1                   phase -65530..-5
     11  mov x, isr                   phase -65529..-4
     12  seek [1]                     phase -65528..-3
     13  out p, 16                    phase -65526..-1
    (route Dwell_y)
      0  set p, 11                    phase ?..?
      1  set x, 0                     phase ?..?
      2  seek [1]                     phase ?..?
      3  out y, 16                    phase ?..?
      4  mov t, now                   phase ?..?
      5  add t, p                     phase 1
      6  add t, y                     phase -9
      7  wait t+                      phase -65543..0  slack 0..65543
      8  out pins, 8                  phase -10  edge -9  gap ?..?
      9  out x, 8                     phase -9
     10  in x, 5                      phase -8
     11  in pins, 3                   phase -7  sample -7
     12  in null, 1                   phase -6
     13  mov x, isr                   phase -5
     14  seek [1]                     phase -4
     15  out y, 16                    phase -2
     16  add t, y                     phase -1
    |}]
;;

(* As test_self_check.ml does for the checker: the analyser's rows under the floor, and
   the kernel on them at every load from the floor, by SAT. Here z3 answers unchecked; the
   cake_lpr-checked run is [Checked_unsat.prove] on the same claim. *)
let%expect_test "the kernel accepts the hold interpreter at every load from the floor" =
  let module G = Hardcaml_verify.Comb_gates in
  let program = Asm.assemble (interpreter Hold_p ~k:3) |> ok_exn in
  let config = Asm.Program.configure program config in
  let words = Asm.Program.words program |> ok_exn in
  let table =
    Analyser.analyse ~period_floor:(floor Hold_p) ~config program.instructions
    |> Kernel.Table.of_analyser
  in
  let solver = Hardcaml_verify.Solver.z3 ~parallel:false () in
  List.iter
    [ floor Hold_p; floor Hold_p - 1 ]
    ~f:(fun least ->
      let claim =
        Table_query.every_load_from
          ~floor:least
          ~single_capture_edge:false
          ~config
          ~words
          table
      in
      match Hardcaml_verify.Solver.solve ~solver (G.cnf G.(~:claim)) with
      | Ok Unsat -> print_s [%message "every load accepted" (least : int)]
      | Ok (Sat _) -> print_s [%message "a load refused" (least : int)]
      | Error e -> print_s [%message "solver failed" (e : Error.t)]);
  [%expect
    {|
    ("every load accepted" (least 10))
    ("a load refused" (least 9))
    |}]
;;

let%expect_test "without the floor, or one cycle short of it, it is refused" =
  let show name r =
    match r with
    | Ok _ -> print_s [%message name "accepted"]
    | Error (r : Timed_program.Refusal.t) ->
      print_s [%message name (r.faults : Timed_program.Fault.t list)]
  in
  (* the verification lens's loop: the time straight into [t], no floor *)
  show "y, no floor" (timed ~floor:0 ~wait:"wait t" Dwell_y ~k:3);
  show "y, floor 10" (timed ~floor:10 Dwell_y ~k:3);
  show "p, premise 9" (timed ~period_floor:9 Hold_p ~k:3);
  [%expect
    {|
    ("y, no floor"
     (r.faults
      (((line 10) (pc (7))
        (reason
         "this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait")))))
    ("y, floor 10"
     (r.faults
      (((line 10) (pc (7))
        (reason
         "this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait")))))
    ("p, premise 9"
     (r.faults
      (((line 8) (pc (5))
        (reason
         "this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait")))))
    |}]
;;

let random_entry rand route ~k =
  let states = 1 lsl (8 - k) in
  let base = if [%equal: Route.t] route Hold_p then floor route else 0 in
  let table =
    Array.init 256 ~f:(fun _ ->
      { Entry.outputs = Random.State.int rand 256
      ; next = Random.State.int rand states
      ; time =
          (base
           +
           if Random.State.int rand 10 = 0
           then Random.State.int rand 200
           else Random.State.int rand 8)
      })
  in
  fun ~state ~inputs -> table.((state lsl k) lor inputs)
;;

let random_inputs rand ~cycles =
  let levels = Array.create ~len:(cycles + 64) 0 in
  let level = ref 0 in
  Array.iteri levels ~f:(fun c _ ->
    if Random.State.int rand 7 = 0 then level := Random.State.int rand 32;
    levels.(c) <- !level);
  fun c -> levels.(c)
;;

let%expect_test "random tables: RTL, model and the Mealy reference agree every cycle" =
  List.iter (accepted ()) ~f:(fun route ->
    let rand = Random.State.make [| 10 |] in
    let tables = 50 in
    let cycles = 1500 in
    let bad = ref 0 in
    for n = 1 to tables do
      let k = 1 + (n % 4) in
      let config, program = image route ~k in
      let entry = random_entry rand route ~k in
      let inputs = random_inputs rand ~cycles in
      let model, pins =
        trace ~data:(words ~k entry) ~cycles ~config ~program ~inputs ()
      in
      let expected = reference route ~k ~entry ~inputs ~cycles in
      let got = outputs pins in
      match Array.findi got ~f:(fun c o -> o <> expected.(c)) with
      | None when Machine.Fault.equal model.fault Machine.Fault.none -> ()
      | first ->
        incr bad;
        print_s
          [%message
            "differs"
              (route : Route.t)
              (n : int)
              (k : int)
              (first : (int * int) option)
              (model.fault : Machine.Fault.t)]
    done;
    print_s
      [%message
        "" (route : Route.t) (tables : int) (cycles : int) ~differing:(!bad : int)]);
  [%expect
    {|
    ((route Hold_p) (tables 50) (cycles 1500) (differing 0))
    ((route Dwell_y) (tables 50) (cycles 1500) (differing 0))
    |}]
;;

(* A table from output segments, [(outputs, cycles)], each held that long; state 0 holds
   the first until an input in [go] is high, the last holds for ever. *)
let of_segments (route : Route.t) ~go segments =
  let segments = Array.of_list segments in
  let n = Array.length segments in
  fun ~state ~inputs ->
    let state = Int.min state (n - 1) in
    let outputs, cycles = segments.(state) in
    let next =
      if state = 0
      then if inputs land go <> 0 then 1 else 0
      else Int.min (state + 1) (n - 1)
    in
    let time =
      match route with
      | Hold_p -> Int.max cycles (floor route)
      | Dwell_y -> if state = 0 then 0 else snd segments.(state - 1) - floor route
    in
    if time < 0 then raise_s [%message "segment below the floor" (state : int)];
    { Entry.outputs; next; time }
;;

(* from the first edge to [level], so the lead-in of each is left out *)
let compare_traces ~name ~route ~watch ~level ~native ~table =
  let from pins =
    edges ~watch pins |> List.drop_while ~f:(fun (_, _, l) -> l <> level) |> relative
  in
  let native = from native in
  let table = from table in
  let n = Int.min (List.length native) (List.length table) in
  let same =
    List.equal [%equal: int * int * int] (List.take native n) (List.take table n)
  in
  print_s
    [%message
      name
        (route : Route.t)
        ~native_edges:(List.length native : int)
        ~table_edges:(List.length table : int)
        ~identical_from_first_start:(same : bool)];
  if not same
  then
    print_s [%message (native : (int * int * int) list) (table : (int * int * int) list)]
;;

let go_pin = 0b100

let run_table route ~segments ~cycles =
  let k = 3 in
  let entry = of_segments route ~go:go_pin segments in
  let config, program = image route ~k in
  let model, pins =
    trace
      ~data:(words ~k entry)
      ~cycles
      ~config
      ~program
      ~inputs:(fun c -> if c >= 50 then go_pin else 0)
      ()
  in
  if not (Machine.Fault.equal model.fault Machine.Fault.none)
  then print_s [%message "fault" (model.fault : Machine.Fault.t)];
  pins
;;

let%expect_test "uart tx: the table and the native firmware make the same edges" =
  let period = 16 in
  let byte = 0xa3 in
  let cycles = 400 in
  let _, native =
    trace
      ~preload:[ byte ]
      ~cycles
      ~config:Program_config.default
      ~program:(Firmware.assemble (Firmware.uart_tx ~period))
      ~inputs:(Fn.const 0)
      ()
  in
  let bits = List.init 8 ~f:(fun i -> (byte lsr i) land 1, period) in
  let segments = ((1, period) :: (0, period) :: bits) @ [ 1, period ] in
  List.iter (accepted ()) ~f:(fun route ->
    compare_traces
      ~name:"uart tx"
      ~route
      ~level:0
      ~watch:[ Isa.first_output_pin ]
      ~native
      ~table:(run_table route ~segments ~cycles));
  [%expect
    {|
    ("uart tx" (route Hold_p) (native_edges 6) (table_edges 6)
     (identical_from_first_start true))
    ("uart tx" (route Dwell_y) (native_edges 6) (table_edges 6)
     (identical_from_first_start true))
    |}]
;;

let%expect_test "spi master: the table and the native firmware make the same edges" =
  let half_period = 16 in
  let byte = 0xa5 in
  let cycles = 700 in
  let _, native =
    trace
      ~preload:[ byte ]
      ~cycles
      ~config:Firmware.spi_config
      ~program:(Firmware.assemble (Firmware.spi_master ~half_period))
      ~inputs:(Fn.const 0)
      ()
  in
  (* bit 0 drives MOSI (pin 5), bit 1 SCK (pin 6) *)
  let bit i = (byte lsr (7 - i)) land 1 in
  let segments =
    ((0, half_period)
     :: List.concat_map (List.init 8 ~f:Fn.id) ~f:(fun i ->
       [ bit i, half_period; bit i lor 0b10, half_period ]))
    @ [ 0, half_period ]
  in
  List.iter (accepted ()) ~f:(fun route ->
    compare_traces
      ~name:"spi master"
      ~route
      ~level:1
      ~watch:[ Firmware.mosi_pin; Firmware.sck_pin ]
      ~native
      ~table:(run_table route ~segments ~cycles));
  [%expect
    {|
    ("spi master" (route Hold_p) (native_edges 24) (table_edges 24)
     (identical_from_first_start true))
    ("spi master" (route Dwell_y) (native_edges 24) (table_edges 24)
     (identical_from_first_start true))
    |}]
;;

let%expect_test "long times stay exact on the model" =
  let k = 3 in
  List.iter (accepted ()) ~f:(fun route ->
    let base = if [%equal: Route.t] route Hold_p then floor route else 0 in
    let times = [| 65535; base; 40000; base + 1; 65535 |] in
    let entry ~state ~inputs:_ =
      { Entry.outputs = state land 1; next = (state + 1) % 5; time = times.(state % 5) }
    in
    let config, program = image route ~k in
    let m =
      Machine.create ~config ~program
      |> Or_error.bind ~f:(fun m -> Machine.load_data m (words ~k entry))
      |> ok_exn
    in
    let cycles = 400_000 in
    let pins = Array.create ~len:cycles 0 in
    let m = ref m in
    for c = 0 to cycles - 1 do
      m := Machine.step !m ~inputs:0;
      pins.(c) <- !m.pin_out
    done;
    let expected = reference route ~k ~entry ~inputs:(Fn.const 0) ~cycles in
    let got = outputs pins in
    let gaps =
      edges ~watch:[ Isa.first_output_pin ] pins
      |> List.map ~f:(fun (c, _, _) -> c)
      |> List.fold ~init:(None, []) ~f:(fun (prev, acc) c ->
        Some c, Option.value_map prev ~default:acc ~f:(fun p -> (c - p) :: acc))
      |> snd
      |> List.rev
    in
    print_s
      [%message
        ""
          (route : Route.t)
          ~matches_reference:([%equal: int array] got expected : bool)
          (gaps : int list)
          (!m.fault : Machine.Fault.t)]);
  [%expect
    {|
    ((route Hold_p) (matches_reference true)
     (gaps (10 40000 11 131070 10 40000 11))
     ("(!m).fault"
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((route Dwell_y) (matches_reference true)
     (gaps (40011 12 65546 65557 40011 12 65546))
     ("(!m).fault"
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
