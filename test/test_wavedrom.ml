open! Core
open Protocol_emulator

let diagram name =
  In_channel.read_all [%string "diagrams/%{name}.json"] |> Wavedrom.of_string |> ok_exn
;;

(* The RTL and the model in lockstep, the host keeping the tx fifo topped up and taking
   every word pushed: the pins each cycle and the words taken. *)
let run ?(react = ignore) ~cycles ~inputs (config, program, data) host_words =
  let rest = ref (List.drop host_words Machine.fifo_depth) in
  let last = ref None in
  let pins = Queue.create () in
  let taken = Queue.create () in
  let host _ =
    let tx_level, rx_head =
      match !last with
      | None -> Machine.fifo_depth, None
      | Some (m : Machine.t) -> List.length m.tx_fifo, List.hd m.rx_fifo
    in
    let tx =
      match !rest with
      | w :: ws when tx_level < Machine.fifo_depth ->
        rest := ws;
        Some w
      | _ -> None
    in
    Option.iter rx_head ~f:(Queue.enqueue taken);
    { Lockstep.Host.idle with tx; pop_rx = Option.is_some rx_head }
  in
  let model, mismatch =
    Lockstep.run
      ~preload:(List.take host_words Machine.fifo_depth)
      ~data
      ~host
      ~cycles
      ~config
      ~program
      ~inputs
      ~react:(fun m ->
        react m;
        last := Some m;
        Queue.enqueue pins (m.pin_out lor m.pin_dir))
      ()
  in
  (match mismatch with
   | None -> ()
   | Some (cycle, _, _) -> raise_s [%message "RTL and model differ" (cycle : int)]);
  model.fault, Queue.to_array pins, Queue.to_list taken @ model.rx_fifo
;;

let hand_image table =
  let config, program, _ = Wavedrom.image (diagram "uart_tx") |> ok_exn in
  config, program, Tables.words table |> ok_exn
;;

let edges pins =
  Array.foldi pins ~init:0 ~f:(fun c n p ->
    if c > 0 && p <> pins.(c - 1) then n + 1 else n)
;;

(* the diagram's table and the hand-written one, run on the same host words *)
let against ?(peer = fun () -> Fn.const 0, ignore) ~cycles name hand ~host_words =
  let t = diagram name in
  let from_diagram = Wavedrom.image t |> ok_exn in
  let words_identical =
    [%equal: int list] (Tables.words t.table |> ok_exn) (Tables.words hand |> ok_exn)
  in
  let on image =
    let inputs, react = peer () in
    run ~react ~cycles ~inputs image host_words
  in
  let fault, pins, taken = on from_diagram in
  let _, hand_pins, hand_taken = on (hand_image hand) in
  print_s
    [%message
      name
        ~steps:(List.length t.steps : int)
        (words_identical : bool)
        ~edges:(edges pins : int)
        ~edges_identical:([%equal: int array] pins hand_pins : bool)
        ~taken_identical:([%equal: int list] taken hand_taken : bool)
        (fault : Machine.Fault.t)];
  t, pins, taken
;;

let%expect_test "uart tx, dshot and spi master from diagrams, against the hand tables" =
  let bytes = [ 0xa3; 0x00; 0xff; 0x5c ] in
  let uart = diagram "uart_tx" in
  let bits byte = List.init 8 ~f:(fun i -> (byte lsr i) land 1 = 1) in
  let words t bits = Wavedrom.host_words t bits |> ok_exn in
  let (_ : Wavedrom.t), _, _ =
    against
      "uart_tx"
      (Tables.uart_tx ~bit:26)
      ~cycles:2000
      ~host_words:(List.concat_map bytes ~f:(fun b -> words uart (bits b)))
  in
  let frames =
    [ Dshot.frame ~throttle:1046 ~telemetry:false
    ; Dshot.frame ~throttle:2047 ~telemetry:true
    ; Dshot.frame ~throttle:48 ~telemetry:false
    ]
  in
  let dshot = diagram "dshot" in
  let msb_first word = List.init 16 ~f:(fun i -> (word lsr (15 - i)) land 1 = 1) in
  let (_ : Wavedrom.t), pins, _ =
    against
      "dshot"
      (Tables.dshot ~zero_high:31 ~bit:83)
      ~cycles:6000
      ~host_words:(List.concat_map frames ~f:(fun f -> words dshot (msb_first f)))
  in
  let levels =
    Array.to_list pins |> List.map ~f:(fun p -> (p lsr Dshot.pin) land 1 = 1)
  in
  print_s
    [%message
      ""
        ~dshot_decoded:
          (Dshot.decode Dshot.Rate.dshot600 ~cycle_ns:Dshot.cycle_ns levels
           |> Or_error.map ~f:fst
           : (int * bool) list Or_error.t)];
  (* a mode 0 slave: MISO shows the next bit after each falling SCK *)
  let slave = [ 0x96; 0xf0; 0x80 ] in
  let peer () =
    let bits =
      List.concat_map slave ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1))
      |> Array.of_list
    in
    let index = ref 0 in
    let sck = ref 0 in
    let inputs _ =
      if !index < Array.length bits then bits.(!index) lsl Spi.miso_pin else 0
    in
    let react (m : Machine.t) =
      let level = (m.pin_out lsr Spi.sck_pin) land 1 in
      if !sck = 1 && level = 0 then incr index;
      sck := level
    in
    inputs, react
  in
  let spi = diagram "spi_master" in
  let sent = [ 0xa5; 0x3c; 0x01 ] in
  let t, _, taken =
    against
      "spi_master"
      (Tables.spi_master ~half:26)
      ~peer
      ~cycles:2500
      ~host_words:
        (List.concat_map sent ~f:(fun b ->
           words spi (List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1 = 1))))
  in
  let byte bits = List.fold bits ~init:0 ~f:(fun acc b -> (2 * acc) + Bool.to_int b) in
  print_s
    [%message
      "" ~spi_read:(List.map taken ~f:(fun w -> byte (Wavedrom.read_bits t w)) : int list)];
  [%expect
    {|
    (uart_tx (steps 11) (words_identical true) (edges 17) (edges_identical true)
     (taken_identical true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (dshot (steps 50) (words_identical true) (edges 96) (edges_identical true)
     (taken_identical true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (dshot_decoded (Ok ((1046 false) (2047 true) (48 false))))
    (spi_master (steps 18) (words_identical true) (edges 49)
     (edges_identical true) (taken_identical true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (spi_read (150 240 128))
    |}]
;;

let%expect_test "ws2812 from a diagram: passes of 12 bits while the host's flag is 1" =
  let t = diagram "ws2812" in
  let frames : Ws2812.Pixel.t list list =
    [ [ { red = 0xff; green = 0x10; blue = 0x00 }
      ; { red = 0x01; green = 0x80; blue = 0xaa }
      ]
    ; [ { red = 0x5a; green = 0xa5; blue = 0x3c }; { red = 0; green = 0; blue = 0xff } ]
    ]
  in
  let bits (p : Ws2812.Pixel.t) =
    List.concat_map [ p.green; p.red; p.blue ] ~f:(fun b ->
      List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1 = 1))
  in
  let host_words =
    List.concat_map frames ~f:(fun pixels ->
      Wavedrom.host_words t (List.concat_map pixels ~f:bits) |> ok_exn)
  in
  let fault, pins, _ =
    run ~cycles:14_000 ~inputs:(Fn.const 0) (Wavedrom.image t |> ok_exn) host_words
  in
  let strip =
    Array.fold pins ~init:(Ws2812.Strip.create ~cycle_ns:Ws2812.cycle_ns) ~f:(fun s p ->
      Ws2812.Strip.step s ~level:((p lsr Ws2812.pin) land 1))
  in
  print_s
    [%message
      ""
        ~steps:(List.length t.steps : int)
        ~limits:(t.limits : Wavedrom.Limit.t list)
        ~words_a_frame:(List.length host_words / List.length frames : int)
        ~frames_identical:
          ([%equal: Ws2812.Pixel.t list list] (Ws2812.Strip.frames strip) frames : bool)
        ~violations:(Ws2812.Strip.violations strip : string list)
        (fault : Machine.Fault.t)];
  print_s [%message "" ~measured:(Ws2812.Strip.measured strip : Measured.t)];
  [%expect
    {|
    ((steps 38)
     (limits
      (((edge "a<->b T0H 250ns..550ns") (cycles 26) (ns 520) (least_ns (250))
        (most_ns (550)))
       ((edge "a<->c T1H 650ns..950ns") (cycles 47) (ns 940) (least_ns (650))
        (most_ns (950)))
       ((edge "b<->d T0L 700ns..1000ns") (cycles 49) (ns 980) (least_ns (700))
        (most_ns (1000)))
       ((edge "c<->d T1L 300ns..600ns") (cycles 28) (ns 560) (least_ns (300))
        (most_ns (600)))))
     (words_a_frame 5) (frames_identical true) (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (measured ((T0H (520 520)) (T0L (980 980)) (T1H (940 940)) (T1L (560 560))))
    |}]
;;

let%expect_test "uart rx from a diagram: the start bit's edge, against the hand table" =
  let bit = 31 in
  let bytes = [ 0xa3; 0x00; 0xff; 0x5c; 0x81 ] in
  (* each frame after two bits of idle *)
  let line =
    List.concat_map bytes ~f:(fun b ->
      [ 1; 1; 0 ] @ List.init 8 ~f:(fun i -> (b lsr i) land 1) @ [ 1 ])
    |> Array.of_list
  in
  let lead = 100 in
  let inputs c =
    if c < lead || (c - lead) / bit >= Array.length line
    then 1
    else line.((c - lead) / bit)
  in
  let t, _, taken =
    against
      "uart_rx"
      (Tables.uart_rx ~bit)
      ~peer:(fun () -> inputs, ignore)
      ~cycles:(lead + (bit * Array.length line) + 200)
      ~host_words:[]
  in
  let byte bits =
    List.foldi bits ~init:0 ~f:(fun i acc b -> acc lor (Bool.to_int b lsl i))
  in
  (* the same bytes on the line the diagram draws, a frame after each idle bit *)
  let drawn =
    Wavedrom.line
      t
      (List.map bytes ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr i) land 1 = 1)))
    |> ok_exn
  in
  let _, line_taken, line_fault =
    Wavedrom.simulate
      t
      ~host_words:[]
      ~inputs:(fun c -> Bool.to_int drawn.(Int.min c (Array.length drawn - 1)))
      ~cycles:(Array.length drawn)
    |> ok_exn
  in
  let read words = List.map words ~f:(fun w -> byte (Wavedrom.read_bits t w)) in
  print_s
    [%message
      ""
        ~uart_read:(read taken : int list)
        ~line_read:(read line_taken : int list)
        (line_fault : Machine.Fault.t)];
  [%expect
    {|
    (uart_rx (steps 10) (words_identical true) (edges 0) (edges_identical true)
     (taken_identical true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((uart_read (163 0 255 92 129)) (line_read (163 0 255 92 129))
     (line_fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "diagrams outside the class are refused, with the reason" =
  List.iter
    [ "not WaveJSON", "{ signal: [ { wave: '01' } "
    ; "no cycles", "{ signal: [ { wave: '01' } ] }"
    ; "x on an output", "{ signal: [ { wave: '1x0' } ], table: { cycles: 20 } }"
    ; "a phase", "{ signal: [ { wave: '10', phase: 0.5 } ], table: { cycles: 20 } }"
    ; ( "seven outputs"
      , "{ signal: [ {wave:'0'}, {wave:'0'}, {wave:'0'}, {wave:'0'}, {wave:'0'}, \
         {wave:'0'}, {wave:'0'} ], table: { cycles: 20 } }" )
    ; ( "two inputs"
      , "{ signal: [ {wave:'0'}, {wave:'x=', input:true}, {wave:'x=', input:true} ], \
         table: { cycles: 40 } }" )
    ; "a step too short", "{ signal: [ { wave: '0101' } ], table: { cycles: 18 } }"
    ; ( "a bit too short to shift"
      , "{ signal: [ { wave: '10========1' } ], table: { cycles: 20 } }" )
    ; ( "a clock's odd half"
      , "{ signal: [ { wave: '0==' }, { wave: '0nn' } ], table: { cycles: 61 } }" )
    ; ( "two data lanes"
      , "{ signal: [ { wave: '0==' }, { wave: '0==' } ], table: { cycles: 30 } }" )
    ; ( "reads two, sends three"
      , "{ signal: [ { wave: '0===' }, { wave: 'x==x', input: true } ], table: { cycles: \
         40 } }" )
    ; "data in the idle", "{ signal: [ { wave: '=.0' } ], table: { cycles: 40 } }"
    ; ( "a pixel unrolled"
      , "{ signal: [ { wave: '01=00' } ], table: { cycles: [0, 20, 20, 28, 2600], \
         repeat: [1, 3, 24] } }" )
    ; ( "a limit the steps break"
      , "{ signal: [ { wave: '01=0', node: '.ab' } ], edge: ['a->b T0H <= 400ns'], \
         table: { cycles: [0, 26, 26, 26] } }" )
    ; ( "a limit from the idle"
      , "{ signal: [ { wave: '01=0', node: 'ab' } ], edge: ['a->b >= 1us'], table: { \
         cycles: [0, 26, 26, 26] } }" )
    ; ( "an input's edge, and an output"
      , "{ signal: [ { wave: '0' }, { wave: '10==', input: true } ], table: { cycles: 40 \
         } }" )
    ; ( "an input's edge, repeated"
      , "{ signal: [ { wave: '10===', input: true } ], table: { cycles: 40, repeat: [2, \
         3, 2] } }" )
    ; ( "an edge too close to its first read"
      , "{ signal: [ { wave: '10=', input: true } ], table: { cycles: 16 } }" )
    ; ( "ws2812 as the firmware times it, while the host says"
      , "{ signal: [ { wave: '01=00' } ], table: { cycles: [0, 20, 20, 28, 2600], \
         repeat: [1, 3, 12, 'host'] } }" )
    ]
    ~f:(fun (name, text) ->
      match Wavedrom.of_string text with
      | Ok t -> print_s [%message name "taken" ~steps:(List.length t.steps : int)]
      | Error e -> print_s [%message name (e : Error.t)]);
  [%expect
    {|
    ("not WaveJSON" (e ("not WaveJSON" "expected , or ]" (at 27))))
    ("no cycles" (e "no table.cycles: how many cycles a period is"))
    ("x on an output"
     (e
      ("outside the table class"
       ("an output needs a level, and x has none" (lane "lane 0") (at "period 1")
        (wave x)))))
    ("a phase"
     (e
      ("outside the table class"
       ("a phase moves a lane off the period grid, where no step can follow it"
        (lane "lane 0") (phase 0.5)))))
    ("seven outputs"
     (e ("outside the table class" ("a table drives 6 outputs" (lanes 7)))))
    ("two inputs"
     (e
      ("outside the table class"
       ("a Shift reads one input pin" (lanes ("lane 1" "lane 2"))))))
    ("a step too short"
     (e
      ("outside the table class"
       ("a Plain step lasts at least 19 cycles" (at "period 0") (cycles 18)))))
    ("a bit too short to shift"
     (e
      ("outside the table class"
       ("bit 0 has no step to move the host bit on: a Shift needs 26 cycles"
        (steps "period 2")))))
    ("a clock's odd half"
     (e
      ("outside the table class"
       ("a clock's period splits into two halves of whole cycles" (at "period 1")
        (cycles 61)))))
    ("two data lanes"
     (e
      ("outside the table class"
       ("a table shows one host bit at a time, on one lane"
        (lanes ("lane 0" "lane 1"))))))
    ("reads two, sends three"
     (e
      ("outside the table class"
       ("a table reads a bit with each bit it sends" (sent 3) (read 2)))))
    ("data in the idle"
     (e
      ("outside the table class"
       "the first period is the idle shown while the host's word is awaited: levels only")))
    ("a pixel unrolled"
     (e
      ("outside the table class"
       ("a table holds 64 steps, a repeat with the host's flag fewer" (steps 74)))))
    ("a limit the steps break"
     (e
      ("outside the table class"
       ("the diagram's own limit does not hold" (edge "a->b T0H <= 400ns")
        (cycles 26) (ns 520) (least_ns ()) (most_ns (400))))))
    ("a limit from the idle"
     (e
      ("outside the table class"
       ("an edge from the idle, whose length is the host's" (edge "a->b >= 1us")))))
    ("an input's edge, and an output"
     (e
      ("outside the table class"
       ("a frame an input's edge starts only reads, so outputs need a frame the host starts"
        (outputs ("lane 0"))))))
    ("an input's edge, repeated"
     (e
      ("outside the table class" "a frame an input's edge starts has no repeat")))
    ("an edge too close to its first read"
     (e
      ("outside the table class"
       ("a (Await(pin A)(level false)) step lasts at least 17 cycles"
        (at "the edge, period 1") (cycles 15)))))
    ("ws2812 as the firmware times it, while the host says"
     (e
      ("outside the table class"
       ("the host's flag before a pass has no step to move the host bit on: a Shift needs 26 cycles"
        (steps "period 1 (copy 1)")))))
    |}]
;;

let%expect_test "a frame of two host words pulls the second; one with no data loops" =
  let bits = List.init 20 ~f:(fun i -> i % 3 = 0 || i = 19) in
  let t =
    Wavedrom.of_string
      {|{ signal: [ { name: 'tx', wave: '10====================1' } ],
          table: { cycles: 28 } }|}
    |> ok_exn
  in
  let levels, _, fault =
    Wavedrom.simulate
      t
      ~host_words:(Wavedrom.host_words t bits |> ok_exn)
      ~inputs:(Fn.const 0)
      ~cycles:800
    |> ok_exn
  in
  let start =
    Array.findi_exn levels ~f:(fun c l -> c > 0 && l = 0 && levels.(c - 1) = 1) |> fst
  in
  let sent = List.init 20 ~f:(fun i -> levels.(start + (28 * (i + 1)) + 14) = 1) in
  let clock =
    Wavedrom.of_string
      {|{ signal: [ { wave: 'p' }, { wave: '01' } ], table: { cycles: 40 } }|}
    |> ok_exn
  in
  let ticks, _, _ =
    Wavedrom.simulate clock ~host_words:[] ~inputs:(Fn.const 0) ~cycles:200 |> ok_exn
  in
  print_s
    [%message
      ""
        ~words:(t.words : int list)
        ~kinds:
          (List.filter_map t.steps ~f:(fun s ->
             match s.kind with
             | Plain -> None
             | kind -> Some kind)
           : Tables.Kind.t list)
        ~sent_identical:([%equal: bool list] sent bits : bool)
        (fault : Machine.Fault.t)
        ~clock:
          (List.filter_mapi (Array.to_list ticks) ~f:(fun c l ->
             Option.some_if (c > 0 && l <> ticks.(c - 1)) l)
           : int list)];
  [%expect
    {|
    ((words (16 4))
     (kinds
      (Await_host Shift Shift Shift Shift Shift Shift Shift Shift Shift Shift
       Shift Shift Shift Shift Shift Pull Shift Shift Shift Shift))
     (sent_identical true)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (clock (1 0 3 2 1 0 3 2 1 0)))
    |}]
;;

let%expect_test "an edge's label sets a limit in ns, us or cycles, or none" =
  let t =
    Wavedrom.of_string
      {|{ signal: [ { wave: '01=0', node: '.abc' } ],
          edge: [ 'a->b >= 26 cycles', 'a->c <= 1.2us', 'b->c = 520ns', 'a-c 0.4us..1.1us',
                  'a~>b just a label' ],
          table: { cycles: 26 } }|}
    |> ok_exn
  in
  List.iter t.limits ~f:(fun l -> print_s [%sexp (l : Wavedrom.Limit.t)]);
  [%expect
    {|
    ((edge "a->b >= 26 cycles") (cycles 26) (ns 520) (least_ns (520))
     (most_ns ()))
    ((edge "a->c <= 1.2us") (cycles 52) (ns 1040) (least_ns ()) (most_ns (1200)))
    ((edge "b->c = 520ns") (cycles 26) (ns 520) (least_ns (520)) (most_ns (520)))
    ((edge "a-c 0.4us..1.1us") (cycles 52) (ns 1040) (least_ns (400))
     (most_ns (1100)))
    |}]
;;
