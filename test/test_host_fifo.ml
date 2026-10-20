open! Core
open! Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Expect_test_helpers_core
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Host_fifo.I) (Host_fifo.O)
module L = Lws_cyclesim.With_interface (Host_fifo.I) (Host_fifo.O)

let ( <--. ) = Bits.( <--. )
let depth = Host_fifo.depth

(* What formal/fifo_order.sv proves, as simulation assertions beside the fifo rather than
   in it, so the chip's Verilog does not change. Like the proof, not in a clear cycle. *)
let with_assertions ~tamper scope (i : Signal.t Host_fifo.I.t) =
  let open Signal in
  let o : Signal.t Host_fifo.O.t = tamper i (Host_fifo.hierarchical scope i) in
  let flushed = reg (Clocking.to_spec i.clocking) i.flush in
  let holds name condition = Assertions.add scope name (i.clocking.clear |: condition) in
  holds "level_within_depth" (o.level <=:. depth);
  holds "empty_iff_level_zero" (o.empty ==: (o.level ==:. 0));
  holds "empty_after_flush" (~:flushed |: o.empty);
  o
;;

module Op = struct
  type t =
    { push : int option
    ; pop : bool
    ; flush : bool
    }
  [@@deriving sexp_of]

  let quickcheck_generator =
    let open Quickcheck.Generator.Let_syntax in
    let%bind push = Option.quickcheck_generator (Int.gen_incl 0 0xffff) in
    (* push-heavy, so the fifo reaches full and the corners around it *)
    let%bind pop = Int.gen_incl 0 2 >>| ( = ) 0 in
    let%map flush = Int.gen_incl 0 15 >>| ( = ) 0 in
    { push; pop; flush }
  ;;
end

(* The cycle's pop comes first, so a full fifo that pops takes the push; a flush loses the
   push with the rest. *)
let model_step queue { Op.push; pop; flush } =
  if flush
  then Queue.clear queue
  else (
    if pop then ignore (Queue.dequeue queue : int option);
    Option.iter push ~f:(fun word ->
      if Queue.length queue < depth then Queue.enqueue queue word))
;;

let drive (inputs : _ Host_fifo.I.t) { Op.push; pop; flush } =
  inputs.push.valid := Bits.of_bool (Option.is_some push);
  inputs.push.value <--. Option.value push ~default:0;
  inputs.pop := Bits.of_bool pop;
  inputs.flush := Bits.of_bool flush
;;

let clear (h @ local) (inputs : _ Host_fifo.I.t) =
  drive inputs { push = None; pop = false; flush = false };
  inputs.clocking.clear := Bits.vdd;
  Lws.step h;
  inputs.clocking.clear := Bits.gnd
;;

let simulate ?(waves = false) tamper =
  let cyclesim_config =
    Cyclesim.Config.add_random_initialization
      Cyclesim.Config.default
      (Cyclesim.Config.Random_initializer.create
         Cyclesim.Config.Random_initializer.randomize_all)
  in
  L.create
    ~config:{ Lws.Config.default with assertions = true }
    ~backend_specific_config:
      { Lws_cyclesim.Backend_specific_config.default with cyclesim_config; waves }
    (with_assertions ~tamper)
;;

let print_assertions sim = print_s [%sexp (Lws_cyclesim.assertions sim : Assertions.t)]

let%expect_test "the fifo matches a queue" =
  let sim = simulate (fun _ o -> o) in
  Lws_cyclesim.run sim (fun (h @ local) { inputs; outputs; _ } ->
    let o = Before_and_after_edge.before_edge outputs in
    let check queue (op : Op.t) =
      let level = Bits.to_unsigned_int !(o.level) in
      require_equal ~message:"level" (module Int) level (Queue.length queue);
      require_equal
        ~message:"empty"
        (module Bool)
        (Bits.to_bool !(o.empty))
        (Queue.is_empty queue);
      (* [full] is low in a cycle that pops *)
      require_equal
        ~message:"full"
        (module Bool)
        (Bits.to_bool !(o.full))
        (Queue.length queue = depth && not op.pop);
      Option.iter (Queue.peek queue) ~f:(fun head ->
        require_equal ~message:"head" (module Int) (Bits.to_unsigned_int !(o.head)) head)
    in
    (* [h] is local, so the trials are drawn first rather than run by [Quickcheck.test] *)
    let trials =
      Quickcheck.random_sequence
        ~seed:(`Deterministic "host_fifo")
        (List.quickcheck_generator Op.quickcheck_generator)
      |> Fn.flip Sequence.take 200
      |> Sequence.to_array
      |> Array.map ~f:Array.of_list
    in
    for trial = 0 to Array.length trials - 1 do
      clear h inputs;
      let queue = Queue.create () in
      for n = 0 to Array.length trials.(trial) - 1 do
        let op = trials.(trial).(n) in
        drive inputs op;
        Lws.step h;
        (* the outputs are those before the edge, so the state this op found *)
        check queue op;
        model_step queue op
      done
    done);
  print_assertions sim;
  [%expect
    {|
    ((
      (empty_after_flush    Not_violated)
      (empty_iff_level_zero Not_violated)
      (level_within_depth   Not_violated)))
    |}]
;;

(* Fill it, pop and push together when full, push when full, then flush with a push. *)
let%expect_test "waveform of the corners at full and flush" =
  let display_rules =
    [ "push$valid"; "push$value"; "pop"; "flush"; "head"; "level"; "empty"; "full" ]
    |> List.map ~f:(fun name ->
      Display_rule.port_name_is name ~wave_format:(Bit_or Unsigned_int))
  in
  let idle = { Op.push = None; pop = false; flush = false } in
  let ops =
    List.init depth ~f:(fun n -> { idle with push = Some (n + 1) })
    @ [ idle
      ; { idle with pop = true; push = Some (depth + 1) }
      ; { idle with push = Some (depth + 2) }
      ; { idle with flush = true; push = Some (depth + 3) }
      ; idle
      ]
  in
  Harness.run
    ~create:Host_fifo.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:12
        ~display_width:92
        ~wave_width:1
        waves)
    (fun (h @ local) ~inputs ~outputs:_ ->
      clear h inputs;
      List.iter ops ~f:(fun op ->
        drive inputs op;
        Lws.step h);
      drive inputs idle;
      Lws.step ~n:2 h);
  [%expect
    {|
    ┌Signals───┐┌Waves─────────────────────────────────────────────────────────────────────────┐
    │push$valid││    ┌───────────────────────────────────────────────────────────┐   ┌─────────│
    │          ││────┘                                                           └───┘         │
    │          ││────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬─│
    │push$value││ 0  │1  │2  │3  │4  │5  │6  │7  │8  │9  │10 │11 │12 │13 │14 │15 │0  │16 │17 │1│
    │          ││────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴─│
    │pop       ││                                                                    ┌───┐     │
    │          ││────────────────────────────────────────────────────────────────────┘   └─────│
    │flush     ││                                                                            ┌─│
    │          ││────────────────────────────────────────────────────────────────────────────┘ │
    │          ││────────┬───────────────────────────────────────────────────────────────┬─────│
    │head      ││ 0      │1                                                              │2    │
    │          ││────────┴───────────────────────────────────────────────────────────────┴─────│
    │          ││────────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬─────────────│
    │level     ││ 0      │1  │2  │3  │4  │5  │6  │7  │8  │9  │10 │11 │12 │13 │14 │15           │
    │          ││────────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴─────────────│
    │empty     ││────────┐                                                                     │
    │          ││        └─────────────────────────────────────────────────────────────────────│
    │full      ││                                                                ┌───┐   ┌─────│
    │          ││────────────────────────────────────────────────────────────────┘   └───┘     │
    └──────────┘└──────────────────────────────────────────────────────────────────────────────┘
    |}]
;;

(* Reports empty low in a cycle that pushes to an empty fifo, which breaks
   [empty_iff_level_zero] in each such cycle. *)
let%expect_test "an assertion shows the cycles a broken fifo violates it" =
  let sim =
    simulate ~waves:true (fun i (o : _ Host_fifo.O.t) ->
      { o with empty = Signal.(o.empty &: ~:(i.push.valid)) })
  in
  Lws_cyclesim.run sim (fun (h @ local) { inputs; _ } ->
    clear h inputs;
    List.iter
      [ Some 1, false; None, true; None, false; Some 2, false; None, true; None, false ]
      ~f:(fun (push, pop) ->
        drive inputs { push; pop; flush = false };
        Lws.step h);
    ());
  print_assertions sim;
  Lws_context.waveform (Lws_cyclesim.context sim)
  |> Option.iter ~f:(fun waves ->
    Waveform.print
      ~display_rules:
        (List.map
           [ "push$valid"; "pop"; "level"; "empty"; "empty_iff_level_zero" ]
           ~f:(fun name ->
             Display_rule.port_name_is name ~wave_format:(Bit_or Unsigned_int)))
      ~signals_width:12
      ~display_width:50
      ~wave_width:2
      waves);
  [%expect
    {|
    ((
      (empty_after_flush Not_violated)
      (empty_iff_level_zero (Violated (1 4)))
      (level_within_depth Not_violated)))
    ┌Signals───┐┌Waves───────────────────────────────┐
    │push$valid││      ┌─────┐           ┌─────┐     │
    │          ││──────┘     └───────────┘     └─────│
    │pop       ││            ┌─────┐           ┌─────│
    │          ││────────────┘     └───────────┘     │
    │          ││──────┬─────┬─────┬───────────┬─────│
    │level     ││ 7    │0    │1    │0          │1    │
    │          ││──────┴─────┴─────┴───────────┴─────│
    │empty     ││                  ┌─────┐           │
    │          ││──────────────────┘     └───────────│
    │empty_iff_││──────┐     ┌───────────┐     ┌─────│
    │          ││      └─────┘           └─────┘     │
    └──────────┘└────────────────────────────────────┘
    |}]
;;
