open! Core
open Pio

(* Every rule between two output edges, checked by [Timing] and then against emulated
   runs: no run may bring two edges closer than the bound, or make a pair the bound says
   never happens. *)
let compare_with_runs
  ?(setup = Emulator.Setup.default)
  ?(runs = 40)
  ~cycles
  name
  source
  (config : Timing.Config.t)
  =
  let program =
    match source with
    | `Text text -> Pioasm.parse text |> ok_exn |> List.hd_exn
    | `Program program -> program
  in
  let outputs =
    List.filter config.pins ~f:(fun pin ->
      List.exists pin.bindings ~f:(fun (_, drive) ->
        match drive with
        | Level | Dir | Dir_low -> true
        | Input -> false))
    |> List.map ~f:(fun pin -> pin.name)
  in
  let edges = List.concat_map outputs ~f:(fun pin -> [ pin, true; pin, false ]) in
  let pairs = List.cartesian_product edges edges in
  let rules =
    List.mapi pairs ~f:(fun i ((a, a_rising), (b, b_rising)) ->
      let sign rising = if rising then "+" else "-" in
      Timing.Rule.of_string
        [%string "r%{i#Int}: %{a}%{sign a_rising} -> %{b}%{sign b_rising} >= 0"]
      |> ok_exn)
  in
  let report = Timing.analyse { config with rules } program in
  let bounds = Timing.Report.rule_bounds report |> Array.of_list in
  let fewest = Array.create ~len:(List.length pairs) None in
  let violations = Queue.create () in
  let check_target ~seed ~before ~last (target : Emulator.Edge.t) =
    List.iteri pairs ~f:(fun i ((a, a_rising), (b, b_rising)) ->
      let sources = if String.equal a b then before else last in
      match Hashtbl.find sources (a, a_rising) with
      | Some source when String.equal b target.pin && Bool.equal b_rising target.rising ->
        let gap = target.time - source in
        fewest.(i) <- Some (Option.value_map fewest.(i) ~default:gap ~f:(Int.min gap));
        (match bounds.(i) with
         | Some bound when gap >= bound * setup.divider -> ()
         | bound ->
           Queue.enqueue
             violations
             [%message
               (seed : int)
                 ~rule:(List.nth_exn rules i : Timing.Rule.t)
                 (bound : int option)
                 (gap : int)
                 ~time:(target.time : int)])
      | Some _ | None -> ())
  in
  List.iter (List.init runs ~f:Fn.id) ~f:(fun seed ->
    let last = Hashtbl.Poly.create () in
    Emulator.run ~setup config program ~seed ~cycles
    |> List.group ~break:(fun (a : Emulator.Edge.t) b -> a.time <> b.time)
    |> List.iter ~f:(fun group ->
      let before = Hashtbl.copy last in
      List.iter group ~f:(fun (edge : Emulator.Edge.t) ->
        Hashtbl.set last ~key:(edge.pin, edge.rising) ~data:edge.time);
      List.iter group ~f:(fun (target : Emulator.Edge.t) ->
        if target.own then check_target ~seed ~before ~last target)));
  let seen = Array.count fewest ~f:Option.is_some in
  let tight =
    Array.counti fewest ~f:(fun i fewest ->
      Option.equal Int.equal fewest bounds.(i) && Option.is_some fewest)
  in
  printf
    "%s: %d rules, %d seen in runs, %d as close as the bound, %d violations\n"
    name
    (List.length rules)
    seen
    tight
    (Queue.length violations);
  List.iter (List.take (Queue.to_list violations) 3) ~f:print_s
;;

let pins specs = List.map specs ~f:(fun spec -> Timing.Pin.of_string spec |> ok_exn)

let initially high (pins : Timing.Pin.t list) =
  List.map pins ~f:(fun pin -> { pin with initial = Some high })
;;

let vendored file name =
  In_channel.read_all ("pico_examples/" ^ file)
  |> Pioasm.parse
  |> ok_exn
  |> List.find_exn ~f:(fun (program : Pioasm.Program.t) -> String.equal program.name name)
;;

let%expect_test "the verifier's counterexamples and the open-drain cases" =
  compare_with_runs
    ~cycles:2_000
    "ce1"
    (`Text
      {|
.program ce1
.side_set 1 opt
.wrap_target
    out pins, 1 side 1
    nop [7]
    nop side 0 [7]
.wrap
|})
    { Timing.Config.default with pins = pins [ "p=side0,out0" ]; autopull = true };
  compare_with_runs
    ~cycles:2_000
    "ce2"
    (`Text
      {|
.program ce2
.side_set 1 opt
.wrap_target
    nop side 1 [7]
    wait 1 pin 0 side 0 [7]
    nop side 1
    nop side 0 [7]
.wrap
|})
    { Timing.Config.default with pins = pins [ "scl=side0,in0" ] |> initially true };
  compare_with_runs
    ~cycles:2_000
    "stretched wait"
    (`Text
      {|
.program stretch
.side_set 1 opt pindirs
    nop side 1 [7]
    wait 1 pin 0 [3]
    nop side 0 [7]
|})
    { Timing.Config.default with pins = pins [ "scl=side0:dir,in0" ] |> initially true };
  compare_with_runs
    ~cycles:2_000
    "stretched stop"
    (`Text
      {|
.program stop
.side_set 1 opt pindirs
    set pindirs, 0 side 0 [7]
    set pindirs, 0 side 1 [7]
    set pindirs, 1 side 1 [7]
|})
    { Timing.Config.default with
      pins = pins [ "sda=set0:dir"; "scl=side0:dir" ] |> initially true
    };
  compare_with_runs
    ~cycles:2_000
    "a3"
    (`Text
      {|
.program a3
.side_set 1 opt pindirs
    nop side 0 [3]
    nop side 1
    wait 0 pin 0 [3]
    nop side 0 [7]
|})
    { Timing.Config.default with pins = pins [ "s=side0:dir,in0" ] };
  compare_with_runs
    ~cycles:2_000
    "b"
    (`Text {|
.program b
.wrap_target
    out pindirs, 1 [7]
.wrap
|})
    { Timing.Config.default with
      pins = pins [ "s=out0:dir" ]
    ; autopull = true
    ; fifo_ready = true
    };
  compare_with_runs
    ~setup:
      { Emulator.Setup.default with divider = 3; pull_threshold = 1; tx_chance = 0.01 }
    ~cycles:6_000
    "d3 at a divider of 3"
    (`Text
      {|
.program d3
.side_set 2 opt pindirs
    nop side 0 [3]
    out pindirs, 1 side 3
    wait 1 pin 0 [3]
|})
    { Timing.Config.default with
      pins = pins [ "s=side0:dir,in0"; "q=side1:dir,out0:dir" ]
    ; autopull = true
    ; clock = Some { sys_hz = 125e6; clkdiv = 3. }
    };
  [%expect
    {|
    ce1: 4 rules, 4 seen in runs, 3 as close as the bound, 0 violations
    ce2: 4 rules, 4 seen in runs, 4 as close as the bound, 0 violations
    stretched wait: 4 rules, 4 seen in runs, 2 as close as the bound, 0 violations
    stretched stop: 16 rules, 16 seen in runs, 9 as close as the bound, 0 violations
    a3: 4 rules, 4 seen in runs, 2 as close as the bound, 0 violations
    b: 4 rules, 4 seen in runs, 1 as close as the bound, 0 violations
    d3 at a divider of 3: 16 rules, 16 seen in runs, 5 as close as the bound, 0 violations
    |}]
;;

let%expect_test "pico-examples programs" =
  compare_with_runs
    ~cycles:3_000
    "uart_tx"
    (`Program (vendored "uart_tx.pio" "uart_tx"))
    { Timing.Config.default with
      pins = pins [ "tx=out0,side0" ] |> initially true
    ; fifo_ready = true
    };
  compare_with_runs
    ~cycles:3_000
    "ws2812"
    (`Program (vendored "ws2812.pio" "ws2812"))
    { Timing.Config.default with pins = pins [ "din=side0" ]; autopull = true };
  compare_with_runs
    ~cycles:6_000
    "onewire"
    (`Program (vendored "onewire_library.pio" "onewire"))
    { Timing.Config.default with
      pins = pins [ "dq=side0:!dir,in0" ] |> initially true
    ; no_stretch = [ "dq" ]
    ; fifo_ready = true
    };
  [%expect
    {|
    uart_tx: 4 rules, 4 seen in runs, 2 as close as the bound, 0 violations
    ws2812: 4 rules, 4 seen in runs, 4 as close as the bound, 0 violations
    onewire: 4 rules, 4 seen in runs, 2 as close as the bound, 0 violations
    |}]
;;

(* pio_i2c.c's words: an escape of its step count then one step a word, or a byte with the
   final bit set so a NAK never halts the machine. Halfword writes fill both halves. *)
let%expect_test "pico-examples i2c, with a slave that stretches scl" =
  let program = vendored "i2c.pio" "i2c" in
  let sc0_sd0 = "set pindirs, 0 side 0 [7]" in
  let sc0_sd1 = "set pindirs, 1 side 0 [7]" in
  let sc1_sd0 = "set pindirs, 0 side 1 [7]" in
  let sc1_sd1 = "set pindirs, 1 side 1 [7]" in
  let mov_isr = "mov isr, null" in
  let start = [ sc1_sd0; sc0_sd0; mov_isr ] in
  let stop = [ sc0_sd0; sc1_sd0; sc1_sd1 ] in
  let repeated = [ sc0_sd1; sc1_sd1; sc1_sd0; sc0_sd0; mov_isr ] in
  let steps = [ sc0_sd0; sc0_sd1; sc1_sd0; sc1_sd1; mov_isr ] in
  let code step =
    0xE000 + fst (List.findi_exn steps ~f:(fun _ text -> String.equal text step))
  in
  let halfword h = (h lsl 16) lor h in
  let escape sequence =
    halfword ((List.length sequence - 1) lsl 10)
    :: List.map sequence ~f:(fun step -> halfword (code step))
  in
  let words seed =
    let rng = Random.State.make [| seed |] in
    let byte () =
      halfword ((Random.State.int rng 256 lsl 1) lor (1 lsl 9) lor Random.State.int rng 2)
    in
    List.init 4 ~f:(fun _ ->
      escape start
      @ List.init (1 + Random.State.int rng 3) ~f:(fun _ -> byte ())
      @ (if Random.State.bool rng then escape repeated @ [ byte () ] else [])
      @ escape stop)
    |> List.concat
  in
  let sequence guard steps =
    Timing.Exec_sequence.of_string
      program
      [%string
        "x=%{List.length steps - 1#Int},%{guard}: %{String.concat ~sep:\" | \" steps}"]
    |> ok_exn
  in
  let config : Timing.Config.t =
    { Timing.Config.default with
      pins =
        pins [ "sda=set0:dir,out0:dir,in0,jmp"; "scl=side0:dir,in1" ] |> initially true
    ; autopull = true
    ; autopush = true
    ; irq_wait_halts = true
    ; entry = Some "entry_point"
    ; no_stretch = [ "sda" ]
    ; exec =
        [ sequence "scl=1,sda=1" start; sequence "scl=0" stop; sequence "scl=0" repeated ]
    }
  in
  let exec =
    List.map steps ~f:(fun step ->
      code step, Pioasm.parse_instruction program step |> ok_exn)
  in
  List.iter [ 1; 2 ] ~f:(fun seed ->
    compare_with_runs
      ~setup:
        { pull_threshold = 16
        ; push_threshold = 8
        ; shift_left = true
        ; exec
        ; tx = Some (Sequence.of_list (words seed))
        ; divider = 1
        ; tx_chance = 0.3
        }
      ~runs:20
      ~cycles:30_000
      [%string "i2c words %{seed#Int}"]
      (`Program program)
      config);
  [%expect
    {|
    i2c words 1: 16 rules, 16 seen in runs, 7 as close as the bound, 0 violations
    i2c words 2: 16 rules, 16 seen in runs, 7 as close as the bound, 0 violations
    |}]
;;
