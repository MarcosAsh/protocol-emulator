open! Core
open Protocol_emulator
open Firmware

(* USB low speed on D+ alone: a zero after six ones, then NRZI from J (D+ low) *)
let usb_reference bits =
  let rec stuff run = function
    | [] -> []
    | 1 :: rest when run = 5 -> 1 :: 0 :: stuff 0 rest
    | 1 :: rest -> 1 :: stuff (run + 1) rest
    | bit :: rest -> bit :: stuff 0 rest
  in
  List.folding_map (stuff 0 bits) ~init:0 ~f:(fun level bit ->
    let level = if bit = 0 then 1 - level else level in
    level, level)
;;

(* CAN: the complement after five of a level, the stuffed bit counting toward the next *)
let can_reference bits =
  let rec stuff ~last ~run = function
    | [] -> []
    | bit :: rest ->
      let run = if run > 0 && bit = last then run + 1 else 1 in
      if run = 5
      then bit :: (1 - bit) :: stuff ~last:(1 - bit) ~run:1 rest
      else bit :: stuff ~last:bit ~run rest
  in
  stuff ~last:0 ~run:0 bits
;;

(* The first pin a transmit table drives, with the firmware flipping it for the stuffed
   bit where [flag] asks, and what a receive table makes of a line: [Machine]'s rules
   written out for one pin. *)
let transmitted (table : Line_code.t) bits =
  let level = ref 0 in
  let state = ref 0 in
  List.concat_map bits ~f:(fun bit ->
    let input = if table.modes.tx_relative then bit lxor !level else bit in
    let e = Line_code.entry table ~state:!state ~input in
    state := e.next;
    level := if table.modes.tx_toggle then !level lxor e.out else e.out;
    let first = !level in
    if e.flag
    then (
      level := 1 - !level;
      [ first; !level ])
    else [ first ])
;;

let received (table : Line_code.t) levels =
  let last = ref 0 in
  let state = ref 0 in
  List.filter_map levels ~f:(fun pin ->
    let input = if table.modes.rx_relative then pin lxor !last else pin in
    let e = Line_code.entry table ~state:!state ~input in
    let bit = if table.modes.rx_toggle then e.out lxor !last else e.out in
    last := pin;
    state := e.next;
    Option.some_if (not e.flag) bit)
;;

let bits =
  Quickcheck.Generator.(
    list (weighted_union [ 1., return 0; 3., return 1 ])
    |> map ~f:(fun l -> List.take l 200))
;;

let%expect_test "the USB and CAN tables code as the standards do, and decode back" =
  let stuffed_usb = ref 0 in
  let stuffed_can = ref 0 in
  Quickcheck.test ~trials:500 ~sexp_of:[%sexp_of: int list] bits ~f:(fun bits ->
    let usb = transmitted Line_code.usb_transmit bits in
    let can = transmitted Line_code.can_transmit bits in
    [%test_result: int list] usb ~expect:(usb_reference bits);
    [%test_result: int list] can ~expect:(can_reference bits);
    [%test_result: int list] (received Line_code.usb_receive usb) ~expect:bits;
    [%test_result: int list] (received Line_code.can_receive can) ~expect:bits;
    stuffed_usb := !stuffed_usb + List.length usb - List.length bits;
    stuffed_can := !stuffed_can + List.length can - List.length bits);
  print_s [%message (!stuffed_usb : int) (!stuffed_can : int)];
  [%expect {| ((!stuffed_usb 59) (!stuffed_can 105)) |}]
;;

let%expect_test "a table is eight words, a state's two entries in each, and the modes" =
  let hex words = List.map words ~f:(sprintf "%04x") in
  print_s
    [%message
      ""
        ~nrzi:(hex (Line_code.words Line_code.nrzi) : string list)
        ~usb_receive:(hex (Line_code.words Line_code.usb_receive) : string list)
        ~usb_transmit_at_the_sixth_one:
          (Line_code.entry Line_code.usb_transmit ~state:5 ~input:1 : Line_code.Entry.t)
        ~round_trip:
          (List.for_all
             Line_code.[ nrzi; usb_transmit; usb_receive; can_transmit; can_receive ]
             ~f:(fun t ->
               [%equal: Line_code.t] (Line_code.of_words (Line_code.words t) |> ok_exn) t)
           : bool)
        ~too_many:(Line_code.of_words (List.init 10 ~f:Fn.id) |> Or_error.is_error : bool)
        ~bit_seven:
          (Line_code.of_words (0x80 :: List.init 8 ~f:(Fn.const 0)) |> Or_error.is_error
           : bool)];
  [%expect
    {|
    ((nrzi (0008 0008 0008 0008 0008 0008 0008 0008 0004))
     (usb_receive (0009 000a 000b 000c 000d 000e 100e 100e 0002))
     (usb_transmit_at_the_sixth_one ((next 0) (out 0) (flag true)))
     (round_trip true) (too_many true) (bit_seven true))
    |}]
;;

let dp = Isa.first_output_pin
let line_in = 4

(* D+ and D- from J, a bit every eight cycles; the stuffed zero flips the pair *)
let usb_transmitter =
  {|
    set pins, 2              ; J
bit:
    jmp stuff, stuffed
    out pins, 1 [5]
    jmp bit
stuffed:
    mov pins, !pins [3]
    stuff_reset
    jmp bit
|}
;;

let transmit_config =
  { Program_config.default with
    out_base = dp
  ; out_count = 2
  ; set_base = dp
  ; set_count = 2
  ; in_base = dp
  ; in_count = 2
  ; autopull = true
  ; line_code = true
  }
;;

let bytes = [ 0x80; 0xff; 0xff; 0x3c; 0x7e ]

let bits_of_bytes =
  List.concat_map ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr i) land 1))
;;

let%expect_test "the transmit table on the core puts USB's line on D+ and D-" =
  let program = assemble usb_transmitter in
  let words = [ 0xff80; 0x3cff; 0x007e ] in
  let out_pc = 2 in
  let mov_pc = 4 in
  let line = ref [] in
  let previous = ref None in
  let react (m : Machine.t) =
    (match !previous with
     | Some (before : Machine.t)
       when before.stall = 0
            && (not before.halted)
            && (before.pc = out_pc || before.pc = mov_pc) ->
       let pair = (m.pin_out lsr dp) land 3 in
       line := pair :: !line
     | Some _ | None -> ());
    previous := Some m
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:440
      ~preload:words
      ~line_table:Line_code.usb_transmit
      ~config:transmit_config
      ~program
      ~inputs:(fun _ -> 0)
      ~react
      ()
  in
  let line = List.rev !line in
  let dp_levels = List.map line ~f:(fun pair -> pair land 1) in
  let expected = usb_reference (bits_of_bytes bytes) in
  print_s
    [%message
      ""
        ~differential:(List.for_all line ~f:(fun pair -> pair = 1 || pair = 2) : bool)
        ~as_reference:
          ([%equal: int list] (List.take dp_levels (List.length expected)) expected
           : bool)
        ~line_bits:(List.length expected : int)
        ~recorded:(List.length dp_levels : int)];
  [%expect
    {|
    ("lockstep held" (cycles 440))
    ((differential true) (as_reference true) (line_bits 43) (recorded 44))
    |}]
;;

let%expect_test "the receive table on the core takes the stuffed zeros out" =
  let levels = usb_reference (bits_of_bytes bytes) |> Array.of_list in
  let inputs n =
    let bit = n / 8 in
    if bit < Array.length levels then levels.(bit) lsl line_in else 0
  in
  let config =
    { Program_config.default with
      in_base = line_in
    ; autopush = true
    ; push_threshold = 8
    ; wrap_bottom = 0
    ; wrap_top = 0
    ; line_code = true
    }
  in
  let m =
    Lockstep.lockstep
      ~cycles:(8 * Array.length levels)
      ~line_table:Line_code.usb_receive
      ~config
      ~program:(assemble "    in pins, 1 [7]")
      ~inputs
      ()
  in
  print_s
    [%message
      ""
        ~sent:(List.map bytes ~f:(sprintf "%02x") : string list)
        ~pushed:(List.map m.rx_fifo ~f:(fun w -> sprintf "%02x" (w lsr 8)) : string list)
        ~line_bits:(Array.length levels : int)];
  [%expect
    {|
    ("lockstep held" (cycles 344))
    ((sent (80 ff ff 3c 7e)) (pushed (80 ff ff 3c 7e)) (line_bits 43))
    |}]
;;

(* Random words, a third of them the ones the add-ons act on: single-bit [in pins] and
   [out pins], [jmp stuff], [stuff_reset], [capture_arm], waits on the capture pin, loads
   of [p] and its uses as a period. *)
let program random ~(config : Program_config.t) =
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let bool () = Splittable_random.bool random in
  let op (op : Isa.Op.t) = Isa.Op { op; delay = int 3; side_set = 0 } in
  let special () : Isa.t =
    match int 9 with
    | 0 -> op (In { source = Pins; count = 1 })
    | 1 -> op (Out { dest = Pins; count = 1 })
    | 2 -> Jmp { cond = Stuff_pending; target = int ((1 lsl Isa.pc_bits) - 1) }
    | 3 -> op (Sys Stuff_reset)
    | 4 -> op (Sys Capture_arm)
    | 5 ->
      op
        (Wait
           (if bool ()
            then Pin_edge { pin = config.capture_pin; rising = config.capture_rising }
            else Pin_level { pin = config.capture_pin; level = config.capture_rising }))
    | 6 -> op (Mov { dest = P; op = Copy; source = (if bool () then Osr else X) })
    | 7 -> op (Wait (Deadline { advance = true }))
    | _ -> op (Alu { dest = T; op = Add; operand = Reg P })
  in
  List.init (1 lsl Isa.pc_bits) ~f:(fun _ ->
    if int 2 = 0
    then Isa.to_word ~side_set_count:config.side_set_count (special ()) |> ok_exn
    else Random_program.word random ~side_set_count:config.side_set_count)
;;

(* Random programs under random configurations, with the table on and random words in it,
   and random premises: the core and the model stay together cycle by cycle. *)
let%expect_test "random programs through random tables" =
  let random = Splittable_random.of_int 11 in
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let bool () = Splittable_random.bool random in
  let programs = 64 in
  let stepped = ref 0 in
  let flagged = ref 0 in
  let assumed = ref 0 in
  let failed =
    List.init programs ~f:(fun seed ->
      let config =
        { (Random_program.config random) with line_code = true; manchester = int 3 = 0 }
      in
      let program = program random ~config in
      let line_table =
        Line_code.of_words
          (List.init Line_code.states ~f:(fun _ -> int 0xffff land 0x1f1f) @ [ int 15 ])
        |> ok_exn
      in
      let premises =
        { Machine.Premises.period = Option.some_if (bool ()) (int 3)
        ; floor = bool ()
        ; single_edge = bool ()
        }
      in
      let level = ref 0 in
      let host _ =
        { Lockstep.Host.idle with
          tx =
            (if !level < Machine.fifo_depth && int 3 = 0 then Some (int 0xffff) else None)
        ; pop_rx = int 3 = 0
        }
      in
      let saw_step = ref false in
      let saw_flag = ref false in
      let react (m : Machine.t) =
        level := List.length m.tx_fifo;
        if m.line_tx <> 0 || m.line_rx <> 0 then saw_step := true;
        if m.line_flag then saw_flag := true
      in
      (* the pins hold for a few cycles at a time, so edges and levels both last *)
      let pins = ref 0 in
      let inputs _ =
        if int 3 = 0 then pins := int ((1 lsl Isa.pin_space) - 1);
        !pins
      in
      match
        Lockstep.run
          ~cycles:600
          ~line_table
          ~premises
          ~config
          ~program
          ~inputs
          ~host
          ~react
          ()
      with
      | m, None ->
        if !saw_step then incr stepped;
        if !saw_flag then incr flagged;
        if m.fault.assumption then incr assumed;
        None
      | _, Some (cycle, expected, actual) ->
        print_s
          [%message
            "MISMATCH"
              (seed : int)
              (cycle : int)
              (expected : Lockstep.State.t)
              (actual : Lockstep.State.t)];
        Some seed)
    |> List.filter_opt
  in
  print_s
    [%message
      (programs : int)
        (failed : int list)
        (!stepped : int)
        (!flagged : int)
        (!assumed : int)];
  [%expect {| ((programs 64) (failed ()) (!stepped 41) (!flagged 32) (!assumed 24)) |}]
;;
