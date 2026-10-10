open! Core
open Protocol_emulator
open Protocol_emulator_test
open Pio

(* A translated pico-examples program on the RTL, in lockstep with the [Machine] every
   cycle, and its pin edges against the PIO emulator's, each [k] cycles a PIO cycle plus
   one latency for the run. The host keeps both tx fifos fed until the words run out. *)

let program file name =
  In_channel.read_all ("pico_examples/" ^ file)
  |> Pioasm.parse
  |> ok_exn
  |> List.find_exn ~f:(fun (p : Pioasm.Program.t) -> String.equal p.name name)
;;

let debug = false

let pin text ~initial =
  { (Timing.Pin.of_string text |> ok_exn) with initial = Some initial }
;;

let lockstep
  ?(pull_threshold = 32)
  ?(shift_left = false)
  ?(autopull = false)
  ?(autopush = false)
  ?(push_threshold = 32)
  ~k
  ~file
  ~name
  ~pins
  ~words
  ~pio_cycles
  ()
  =
  let program = program file name in
  let setup = Census.setup program ~period:2 in
  let t, timed =
    match Census.certify program ~k with
    | Ok certified -> certified
    | Error verdict -> raise_s [%sexp (verdict : Census.Verdict.t)]
  in
  let pio =
    Emulator.run
      ~setup:
        { Emulator.Setup.default with
          pull_threshold
        ; push_threshold
        ; shift_left
        ; tx = Some (Sequence.of_list words)
        ; tx_chance = 1.
        }
      { Timing.Config.default with
        pins = List.map pins ~f:(fun (text, _, initial) -> pin text ~initial)
      ; autopull
      ; autopush
      ; fifo_ready = true
      ; entry = setup.entry
      }
      program
      ~seed:1
      ~cycles:pio_cycles
    |> List.map ~f:(fun (e : Emulator.Edge.t) ->
      let _, ours, _ =
        List.find_exn pins ~f:(fun (text, _, _) ->
          String.equal (String.lsplit2_exn text ~on:'=' |> fst) e.pin)
      in
      e.time, ours, e.rising)
  in
  let outputs = List.map pins ~f:(fun (_, ours, _) -> ours) in
  let tx = Queue.of_list (List.concat_map words ~f:(Translate.tx_words setup t)) in
  let markers =
    List.concat_map t.relation.steps ~f:(fun step -> step.markers) |> Int.Set.of_list
  in
  let latest = ref None in
  let started = ref false in
  let levels = ref [] in
  let edges = Queue.create () in
  let cycle = ref 0 in
  let level m pin = (Machine.pins m ~inputs:0 lsr pin) land 1 = 1 in
  let react (m : Machine.t) =
    incr cycle;
    latest := Some m;
    if !started
    then
      List.iter2_exn outputs !levels ~f:(fun pin before ->
        if Bool.( <> ) (level m pin) before
        then Queue.enqueue edges (!cycle, pin, level m pin))
    else if Set.mem markers m.pc
    then started := true;
    levels := List.map outputs ~f:(level m)
  in
  let host _ =
    match !latest with
    | Some m when List.length m.tx_fifo < Machine.fifo_depth && not (Queue.is_empty tx) ->
      { Lockstep.Host.idle with
        tx = Queue.dequeue tx
      ; pop_rx = not (List.is_empty m.rx_fifo)
      }
    | Some m -> { Lockstep.Host.idle with pop_rx = not (List.is_empty m.rx_fifo) }
    | None -> Lockstep.Host.idle
  in
  let machine, mismatch =
    Lockstep.run
      ~cycles:(Float.iround_up_exn (Float.of_int pio_cycles *. k) + 64)
      ~host
      ~react
      ~config:(Timed_program.config timed)
      ~program:(Timed_program.words timed)
      ~inputs:(fun _ -> 0)
      ()
  in
  let pio = List.filter pio ~f:(fun (time, _, _) -> time < pio_cycles - 1) in
  (* ours over the same window, from the first edge on both *)
  let ours =
    let ours = Queue.to_list edges in
    match ours, pio with
    | (c, _, _) :: _, (time, _, _) :: _ ->
      let start = Float.of_int c -. (k *. Float.of_int time) in
      List.filter ours ~f:(fun (c, _, _) ->
        Float.( < ) (Float.of_int c) (start +. (k *. Float.of_int (pio_cycles - 1))))
    | _ -> ours
  in
  let latency =
    match ours, pio with
    | (c, _, _) :: _, (time, _, _) :: _ ->
      Some (Float.of_int c -. (k *. Float.of_int time))
    | _ -> None
  in
  if debug
  then
    print_s
      [%message
        (List.take ours 30 : (int * int * bool) list)
          (List.take pio 30 : (int * int * bool) list)];
  let off =
    match latency with
    | None -> []
    | Some latency ->
      List.zip_exn (List.take ours (List.length pio)) (List.take pio (List.length ours))
      |> List.filter ~f:(fun ((c, p, r), (time, p', r')) ->
        Float.( > )
          (Float.abs (Float.of_int c -. ((k *. Float.of_int time) +. latency)))
          1.
        || p <> p'
        || Bool.( <> ) r r')
  in
  let exact =
    match latency with
    | None -> false
    | Some latency ->
      List.for_all2_exn
        (List.take ours (List.length pio))
        (List.take pio (List.length ours))
        ~f:(fun (c, _, _) (time, _, _) ->
          Float.equal (Float.of_int c) ((k *. Float.of_int time) +. latency))
  in
  print_s
    [%message
      name
        (k : float)
        ~words:(List.length t.words : int)
        ~rtl_lockstep:(Option.is_none mismatch : bool)
        ~fault:(machine.fault : Machine.Fault.t)
        ~pio_edges:(List.length pio : int)
        ~our_edges:(List.length ours : int)
        (latency : float option)
        ~more_than_a_cycle_off:(List.length off : int)
        (exact : bool)]
;;

let%expect_test "uart_tx sends bytes at k times its PIO edges" =
  lockstep
    ~k:8.
    ~file:"uart_tx.pio"
    ~name:"uart_tx"
    ~pins:[ "tx=side0,out0", 5, true ]
    ~words:[ 0x55; 0x00; 0xff; 0xa3 ]
    ~pio_cycles:400
    ();
  [%expect {|
    (uart_tx (k 8) (words 65) (rtl_lockstep true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (pio_edges 20) (our_edges 20) (latency (11)) (more_than_a_cycle_off 0)
     (exact true))
    |}]
;;

let%expect_test "ws2812 sends pixels at k times its PIO edges" =
  lockstep
    ~k:6.
    ~autopull:true
    ~pull_threshold:24
    ~shift_left:true
    ~file:"ws2812.pio"
    ~name:"ws2812"
    ~pins:[ "din=side0", 5, false ]
    ~words:[ 0xff0000 lsl 8; 0x00a5c3 lsl 8; 0x123456 lsl 8 ]
    ~pio_cycles:800
    ();
  [%expect {|
    (ws2812 (k 6) (words 73) (rtl_lockstep true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (pio_edges 144) (our_edges 144) (latency (4)) (more_than_a_cycle_off 0)
     (exact true))
    |}]
;;

let%expect_test "spi_cpha0 shifts bytes at k times its PIO edges" =
  lockstep
    ~k:8.
    ~autopull:true
    ~autopush:true
    ~pull_threshold:8
    ~push_threshold:8
    ~shift_left:true
    ~file:"spi.pio"
    ~name:"spi_cpha0"
    ~pins:[ "sck=side0", 5, false; "mosi=out0", 6, false; "miso=in0", 0, false ]
    ~words:(List.map [ 0x9f; 0x00; 0xa5; 0x3c ] ~f:(fun b -> b lsl 24))
    ~pio_cycles:200
    ();
  [%expect {|
    (spi_cpha0 (k 8) (words 41) (rtl_lockstep true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (pio_edges 78) (our_edges 78) (latency (2)) (more_than_a_cycle_off 0)
     (exact true))
    |}]
;;

(* at 50 MHz the example's 800 kHz takes k = 6.25: each edge within a cycle of 6.25 times
   its PIO cycle *)
let%expect_test "ws2812 at its own rate" =
  lockstep
    ~k:6.25
    ~autopull:true
    ~pull_threshold:24
    ~shift_left:true
    ~file:"ws2812.pio"
    ~name:"ws2812"
    ~pins:[ "din=side0", 5, false ]
    ~words:[ 0xff0000 lsl 8; 0x00a5c3 lsl 8; 0x123456 lsl 8 ]
    ~pio_cycles:800
    ();
  [%expect {|
    (ws2812 (k 6.25) (words 73) (rtl_lockstep true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (pio_edges 144) (our_edges 144) (latency (3.5)) (more_than_a_cycle_off 0)
     (exact false))
    |}]
;;

let%expect_test "manchester_tx at k times its PIO edges" =
  lockstep
    ~k:7.
    ~autopull:true
    ~file:"manchester_encoding.pio"
    ~name:"manchester_tx"
    ~pins:[ "tx=side0", 5, false ]
    ~words:[ 0x0000a5c3; 0x12345678 ]
    ~pio_cycles:700
    ();
  [%expect {|
    (manchester_tx (k 7) (words 86) (rtl_lockstep true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (pio_edges 93) (our_edges 93) (latency (3)) (more_than_a_cycle_off 0)
     (exact true))
    |}]
;;
