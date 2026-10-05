open! Core
open Protocol_emulator

let wire = Isa.num_pins
let period = 434
let sender = Asm.assemble Firmware.uart_tx_host_rate |> ok_exn
let sender_config = { Program_config.default with set_base = wire; out_base = wire }
let checker ?(base = 0) ~pin () = Asm.assemble (Self_check.checker ~pin ~base) |> ok_exn

(* the start bit's write and the stop bit's *)
let frame = Self_check.edges ~period ~config:sender_config sender ~first:8 ~last:14
let rows ~base = Or_error.bind frame ~f:(Self_check.rows ~base) |> ok_exn

(* what engine 0 might keep under rows at [base]: read as rows, the sender's first data
   edge falls between two checks *)
let under ~base = List.init base ~f:(fun _ -> 0x0101)

let machine ~config program ~data =
  let config = Asm.Program.configure program config in
  let m =
    Machine.create ~config ~program:(Asm.Program.words program |> ok_exn) |> ok_exn
  in
  Machine.load_data m data |> ok_exn
;;

(* Engine 0 sends [bytes] at the bit period the host gives it, engine 1 checks it against
   [rows] read from [base], with [under] below them; the checker's irq, which it raises
   only with a halt. *)
let caught ?(sender = sender) ?(host_period = period) ?(base = 0) ~rows bytes =
  let system =
    System.create
      [ machine ~config:sender_config sender ~data:[]
      ; machine
          ~config:(Self_check.checker_config ~pin:wire)
          (checker ~pin:wire ~base ())
          ~data:(under ~base @ rows)
      ]
  in
  let system =
    List.fold (host_period :: bytes) ~init:system ~f:(fun s w ->
      System.update s 0 ~f:(fun m -> Machine.write_tx m w |> ok_exn))
  in
  let cycles = (List.length bytes + 1) * 11 * host_period in
  let system = Fn.apply_n_times ~n:cycles (fun s -> System.step s ~pads:0) system in
  let checker = List.nth_exn system.engines 1 in
  [%test_result: bool] checker.halted ~expect:checker.irq;
  checker.irq
;;

let bytes = [ 0x55; 0xa3; 0x00; 0xff ]

module G = Hardcaml_verify.Comb_gates

(* Each edge loads p from its row, so the analyser's table is for every load of min_gap or
   more, and the kernel accepts it at each, by checked SAT; phase_step.sv's load is free
   at each entry, so no deadline is missed however the rows' loads vary. Every frame is
   anchored on [now] after a wait on the pin, so this holds whatever the line does, with
   nothing assumed of the capture. At one less the kernel refuses. *)
let%expect_test "the kernel accepts the checker at every load from min_gap" =
  let checker = checker ~pin:wire () in
  let checker_config = Self_check.checker_config ~pin:wire in
  let config = Asm.Program.configure checker checker_config in
  let words = Asm.Program.words checker |> ok_exn in
  let table ~floor =
    Analyser.analyse ~period_floor:floor ~config checker.instructions
    |> Kernel.Table.of_analyser
  in
  let check ~floor = Kernel.check ~period:floor ~config ~words (table ~floor) in
  let floor = Self_check.min_gap in
  print_s
    [%message
      ""
        ~analyser:
          (Analyser.check ~period_floor:floor ~config:checker_config checker
           : Analyser.Verdict.t Or_error.t)
        ~kernel:(check ~floor : unit Or_error.t)
        ~one_less:(check ~floor:(floor - 1) : unit Or_error.t)];
  let loads_from least =
    Table_query.every_load_from
      ~floor:least
      ~single_capture_edge:false
      ~config
      ~words
      (table ~floor)
  in
  Checked_unsat.prove
    [%string "checker: every load of %{floor#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from floor);
  (* the tooth: one less than the table allows *)
  Checked_unsat.prove
    ~show:[ "loaded" ]
    [%string "checker: every load of %{floor - 1#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from (floor - 1));
  [%expect
    {|
    ((analyser (Ok ((words 69) (deadline_waits 3) (worst_slack (0)))))
     (kernel (Ok ()))
     (one_less
      (Error
       ("rows the kernel rejects" (rejected (((pc 30) (fails ("in time")))))))))
    (QED "checker: every load of 17 or more")
    (counterexample "checker: every load of 16 or more"
     (model ((loaded 0000000000010000))))
    |}]
;;

(* the word after the rows loads its base above the data memory, which seek wraps *)
let%expect_test "every p the rows load is at least min_gap" =
  let loads rows =
    let last = List.length rows - 1 in
    List.mapi rows ~f:(fun n word -> if n = 0 || n = last then word else word lsr 1)
  in
  let edges_and_base =
    let open Quickcheck.Generator.Let_syntax in
    let%bind first = Int.gen_incl 0 (1 lsl 12) in
    let%bind gaps = List.gen_non_empty (Int.gen_incl Self_check.min_gap (1 lsl 10)) in
    let%map base = Int.gen_incl 0 511 in
    first :: List.folding_map gaps ~init:first ~f:(fun at gap -> at + gap, at + gap), base
  in
  let accepted = ref 0 in
  Quickcheck.test
    ~trials:1000
    ~sexp_of:[%sexp_of: int list * int]
    edges_and_base
    ~f:(fun (edges, base) ->
      Or_error.iter (Self_check.rows ~base edges) ~f:(fun rows ->
        incr accepted;
        List.iter (loads rows) ~f:(fun p ->
          if p < Self_check.min_gap
          then raise_s [%message "a row loads p under min_gap" (p : int)])));
  print_s [%message (!accepted : int)];
  [%expect {| (!accepted 824) |}]
;;

let%expect_test "a uart frame's edges and rows" =
  let rows = rows ~base:256 in
  print_s [%message (frame : int list Or_error.t) (rows : int list)];
  [%test_result: int list]
    ~message:"the rows committed for the cocotb test"
    (In_channel.read_lines "uart_tx_host_rate_rows.hex"
     |> List.map ~f:(fun w -> Int.of_string ("0x" ^ w)))
    ~expect:rows;
  [%expect
    {|
    ((frame (Ok (434 868 1302 1736 2170 2604 3038 3472 3906 4346)))
     (rows (422 869 869 869 869 869 869 869 869 874 768)))
    |}]
;;

let%expect_test "frames the checker cannot take are refused" =
  let edges ~first ~last =
    print_s
      [%sexp
        (Self_check.edges ~period ~config:sender_config sender ~first ~last
         : int list Or_error.t)]
  in
  (* the idle line's write, before a wait on the host *)
  edges ~first:3 ~last:14;
  (* a frame cut inside its bit loop *)
  edges ~first:8 ~last:11;
  let rows ~base edges =
    print_s [%sexp (Self_check.rows ~base edges : int list Or_error.t)]
  in
  (* the least first edge, gap and gap to the least, then each a cycle short *)
  rows ~base:0 [ 29; 46; 66 ];
  rows ~base:0 [ 28; 45; 64 ];
  (* four words, the last at 511 *)
  rows ~base:508 [ 29; 46; 66 ];
  rows ~base:509 [ 29; 46; 66 ];
  [%expect
    {|
    (Error ("not exact" (what edge) (pc 3)))
    (Error ("branch after the frame" (pc 12)))
    (Ok (17 35 34 512))
    (Error (("gap out of range" (p 16)) ("gap out of range" (p 16))))
    (Ok (17 35 34 1020))
    (Error ("rows past the data memory" (base 509)))
    |}]
;;

(* The checker takes a frame's first edge for a fall, so one that starts with a rise is
   refused. *)
let%expect_test "a frame that starts with a rise is refused" =
  let edges source =
    let program = Asm.assemble source |> ok_exn in
    print_s
      [%sexp
        (Self_check.edges ~config:Program_config.default program ~first:4 ~last:6
         : int list Or_error.t)]
  in
  let frame ~first ~last =
    [%string
      {|
    set p, 20
top:
    wait tx
    pull
    mov t, now
    set pins, %{first#Int}
    nop [31]
    set pins, %{last#Int}
    jmp top
|}]
  in
  edges (frame ~first:0 ~last:1);
  edges (frame ~first:1 ~last:0);
  [%expect {|
    (Ok (33 39))
    (Error ("frame starts with a rise" (pc 4)))
    |}]
;;

let%expect_test "an edge a cycle early or late is caught" =
  let rows = rows ~base:0 in
  print_s [%message "on time" ~caught:(caught ~rows bytes : bool)];
  (* a row's gap one cycle out moves the check by a cycle; the last row is the least to
     the next frame, so later is allowed there *)
  let moved =
    List.init
      (List.length rows - 1)
      ~f:(fun n ->
        let by d =
          caught
            ~rows:
              (List.mapi rows ~f:(fun m r ->
                 if m <> n then r else if n = 0 then r + d else r + (2 * d)))
            bytes
        in
        n, by (-1), by 1)
  in
  print_s [%message (moved : (int * bool * bool) list)];
  [%expect
    {|
    ("on time" (caught false))
    (moved
     ((0 true true) (1 true true) (2 true true) (3 true true) (4 true true)
      (5 true true) (6 true true) (7 true true) (8 true true) (9 false true)))
    |}]
;;

let%expect_test "a firmware or bit period other than the certificate's is caught" =
  let rows = rows ~base:0 in
  let slower = caught ~rows ~host_period:(period + 1) bytes in
  let delayed =
    let source =
      String.substr_replace_first
        Firmware.uart_tx_host_rate
        ~pattern:"mov t, now"
        ~with_:"mov t, now [1]"
    in
    caught ~sender:(Asm.assemble source |> ok_exn) ~rows bytes
  in
  print_s [%message (slower : bool) (delayed : bool)];
  [%expect {| ((slower true) (delayed true)) |}]
;;

let%expect_test "rows above what engine 0 keeps in the data memory" =
  let rows = rows ~base:256 in
  let from_256 = caught ~base:256 ~rows bytes in
  let late_from_256 = caught ~base:256 ~host_period:(period + 1) ~rows bytes in
  (* the same memory, read from 0 *)
  let from_0 = caught ~rows:(under ~base:256 @ rows) bytes in
  print_s [%message (from_256 : bool) (late_from_256 : bool) (from_0 : bool)];
  [%expect {| ((from_256 false) (late_from_256 true) (from_0 true)) |}]
;;

(* A frame on an input pad: low from 0, high from 100, low from 200, high from 300, and
   the next no sooner than 400. One cycle of the other level at [glitch] from a frame's
   start, or the edge at 200 moved by [shift]. *)
let pad ?glitch ?(shift = 0) () =
  let pin = 0 in
  let start = 50 in
  let edges = [ 100; 200 + shift; 300 ] in
  let checker =
    machine
      ~config:(Self_check.checker_config ~pin)
      (checker ~pin ())
      ~data:(Self_check.rows ~base:0 [ 100; 200; 300; 400 ] |> ok_exn)
  in
  let level cycle =
    if cycle < start
    then 1
    else (
      let at = (cycle - start) % 400 in
      let level = List.count edges ~f:(fun e -> at >= e) % 2 in
      if Option.equal Int.equal glitch (Some at) then 1 - level else level)
  in
  let checker =
    List.fold
      (List.init (start + 1200) ~f:Fn.id)
      ~init:checker
      ~f:(fun m cycle -> Machine.step m ~inputs:(level cycle lsl pin))
  in
  checker.irq
;;

let%expect_test "what the checker sees on a pad" =
  print_s [%message "on time" ~caught:(pad () : bool)];
  let shifted = List.filter [ -2; -1; 1; 2 ] ~f:(fun shift -> not (pad ~shift ())) in
  let unseen =
    List.filter (List.init 400 ~f:Fn.id) ~f:(fun glitch ->
      glitch <> 0 && not (pad ~glitch ()))
  in
  print_s [%message (shifted : int list) (unseen : int list)];
  [%expect {|
    ("on time" (caught false))
    ((shifted ()) (unseen ()))
    |}]
;;

let%expect_test "the rtl checks as the model does, rows above other data" =
  let base = 256 in
  let checker = checker ~pin:wire ~base () in
  let run ~host_period =
    let system =
      System_lockstep.lockstep
        ~cycles:(3 * 11 * period)
        ~pads:(fun _ -> 0)
        [ { config = sender_config
          ; program = Asm.Program.words sender |> ok_exn
          ; preload = [ host_period; 0x55; 0xa3 ]
          ; data = []
          ; assumptions =
              { System_lockstep.Assumptions.none with period = Some host_period }
          }
        ; { config = Asm.Program.configure checker (Self_check.checker_config ~pin:wire)
          ; program = Asm.Program.words checker |> ok_exn
          ; preload = []
          ; data = under ~base @ rows ~base
          ; assumptions =
              { System_lockstep.Assumptions.none with period_floor = Some Self_check.min_gap }
          }
        ]
    in
    let checker = List.nth_exn system.engines 1 in
    print_s [%message (host_period : int) (checker.irq : bool) (checker.halted : bool)]
  in
  run ~host_period:period;
  run ~host_period:(period + 1);
  [%expect
    {|
    ("lockstep held" (cycles 14322))
    ((host_period 434) (checker.irq false) (checker.halted false))
    ("lockstep held" (cycles 14322))
    ((host_period 435) (checker.irq true) (checker.halted true))
    |}]
;;

(* The words [Self_check.rows] makes, with none of its refusals. *)
let unchecked_rows edges =
  let gaps =
    List.map2_exn (List.drop_last_exn edges) (List.tl_exn edges) ~f:(fun a b -> b - a)
  in
  let least = List.length gaps - 1 in
  ((List.hd_exn edges - 12)
   :: List.mapi gaps ~f:(fun n gap ->
     if n = least then (gap - 3) lsl 1 else (gap lsl 1) lor 1))
  @ [ 1 lsl Isa.data_addr_bits ]
;;

(* Low for the first 100 cycles of each frame, then high, with checks at [edges]; the last
   is the next frame. One cycle of the other level at [glitch]. *)
let long_frame ?glitch ?every ~rtl edges =
  let pin = 0 in
  let start = 50 in
  let span = Option.value every ~default:(List.last_exn edges) in
  let level cycle =
    let at = cycle - start in
    if at < 0
    then 1
    else (
      let level = if at % span < 100 then 0 else 1 in
      if Option.equal Int.equal glitch (Some at) then 1 - level else level)
  in
  let cycles = start + (2 * span) + 200 in
  let data = unchecked_rows edges in
  let checker = checker ~pin () in
  let config = Self_check.checker_config ~pin in
  if rtl
  then (
    let system =
      System_lockstep.lockstep
        ~cycles
        ~pads:(fun cycle -> level cycle lsl pin)
        [ { config = Asm.Program.configure checker config
          ; program = Asm.Program.words checker |> ok_exn
          ; preload = []
          ; data
          ; assumptions =
              { System_lockstep.Assumptions.none with period_floor = Some Self_check.min_gap }
          }
        ]
    in
    (List.hd_exn system.engines).irq)
  else (
    let m =
      List.fold
        (List.init cycles ~f:Fn.id)
        ~init:(machine ~config checker ~data)
        ~f:(fun m cycle -> Machine.step m ~inputs:(level cycle lsl pin))
    in
    m.irq)
;;

(* The checker once compared 14 bits of the capture, and before [rows] refused frames this
   long a glitch 2^14 cycles after the first edge stamped as that edge had and went
   unseen. It compares 16 now and catches that glitch and one a cycle either side, on the
   model and the rtl, with the frame quiet without them; [rows] still refuses the frame.
   The next frame comes late, as an idle line's would. *)
let%expect_test "a frame spanning the capture's 14 bits is refused" =
  let edges = [ 100; 8000; 16000; 16500; 16600 ] in
  let quiet = not (long_frame ~every:17000 ~rtl:false edges) in
  let unseen =
    List.filter [ 16383; 16384; 16385 ] ~f:(fun glitch ->
      not (long_frame ~glitch ~every:17000 ~rtl:false edges))
  in
  let rtl_caught = long_frame ~glitch:16384 ~every:17000 ~rtl:true edges in
  print_s [%message (quiet : bool) (unseen : int list) (rtl_caught : bool)];
  let rows edges =
    print_s [%sexp (Self_check.rows ~base:0 edges : int list Or_error.t)]
  in
  rows edges;
  rows [ 100; 16383 ];
  rows [ 100; 16384 ];
  (* uart_tx_host_rate at 9600 baud *)
  Or_error.bind
    (Self_check.edges ~period:5208 ~config:sender_config sender ~first:8 ~last:14)
    ~f:(Self_check.rows ~base:0)
  |> [%sexp_of: int list Or_error.t]
  |> print_s;
  [%expect
    {|
    ("lockstep held" (cycles 34250))
    ((quiet true) (unseen ()) (rtl_caught true))
    (Error ("frame reaches 2^14 cycles" (last 16600)))
    (Ok (88 32560 512))
    (Error ("frame reaches 2^14 cycles" (last 16384)))
    (Error ("frame reaches 2^14 cycles" (last 52086)))
    |}]
;;
