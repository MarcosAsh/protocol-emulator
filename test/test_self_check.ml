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

let%expect_test "the checker keeps its own deadlines when every gap is at least min_gap" =
  let checker = checker ~pin:wire () in
  let config = Asm.Program.configure checker (Self_check.checker_config ~pin:wire) in
  List.iter
    [ Self_check.min_gap - 1; Self_check.min_gap ]
    ~f:(fun floor ->
      let late =
        Analyser.analyse
          ~period_floor:floor
          ~single_capture_edge:true
          ~config
          checker.instructions
        |> List.filter ~f:(fun r -> r.may_miss || r.may_underrun)
        |> List.map ~f:(fun r -> r.pc)
      in
      print_s [%message (floor : int) (late : int list)]);
  [%expect {|
    ((floor 28) (late (16)))
    ((floor 29) (late ()))
    |}]
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
     (rows (431 869 869 869 869 869 869 869 869 881 512)))
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
  rows ~base:0 [ 32; 61 ];
  rows ~base:0 [ 31; 59 ];
  (* three words, the last at 511 *)
  rows ~base:509 [ 32; 61 ];
  rows ~base:510 [ 32; 61 ];
  [%expect
    {|
    (Error ("not exact" (what edge) (pc 3)))
    (Error ("branch after the frame" (pc 12)))
    (Ok (29 59 0))
    (Error (("gap out of range" (p 28)) ("gap out of range" (p 28))))
    (Ok (29 59 1018))
    (Error ("rows past the data memory" (base 510)))
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
  [%expect
    {|
    ("on time" (caught false))
    ((shifted ())
     (unseen
      (97 98 101 102 103 104 105 106 107 198 201 202 203 204 205 206 297 298)))
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
          }
        ; { config = Asm.Program.configure checker (Self_check.checker_config ~pin:wire)
          ; program = Asm.Program.words checker |> ok_exn
          ; preload = []
          ; data = under ~base @ rows ~base
          }
        ]
    in
    let checker = List.nth_exn system.engines 1 in
    print_s [%message (host_period : int) (checker.irq : bool) (checker.halted : bool)]
  in
  run ~host_period:period;
  run ~host_period:(period + 1);
  [%expect {|
    ("lockstep held" (cycles 14322))
    ((host_period 434) (checker.irq false) (checker.halted false))
    ("lockstep held" (cycles 14322))
    ((host_period 435) (checker.irq true) (checker.halted true))
    |}]
;;
