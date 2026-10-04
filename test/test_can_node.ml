open! Core
open Protocol_emulator
open Can_node

let bit v i = (v lsr i) land 1 = 1
let bits_of_string s = String.to_list s |> List.map ~f:(Char.equal '1')

let string_of_bits bits =
  String.of_list (List.map bits ~f:(fun b -> if b then '1' else '0'))
;;

(* can2040's own lines from SOF to the CRC delimiter, printed by demo/can_node/golden.c
   from can2040_transmit at the commit demo/can_node pins, and the CRC it computed *)
let can2040 =
  [ ( Can.Frame.data ~id:0x123 [ 0xde; 0xad ]
    , 0x0b6e
    , "0001001000110000011011011110101011010001011011011101" )
  ; ( Can.Frame.data ~id:0x555 [ 0x00; 0xff; 0x55; 0xaa; 0x01; 0x80; 0x7f; 0xfe ]
    , 0x7480
    , "01010101010100010000010000010111110111010101011010101000001000110000010001111101111101111011101001000001001"
    )
  ; Can.Frame.data ~id:0x7ef [], 0x5ed0, "0111110101111000001001011110110100001"
  ; ( Can.Frame.data ~id:0x000 [ 0x01 ]
    , 0x01bf
    , "0000010000010000010001000001001000001011011111011" )
  ; ( Can.Frame.data ~id:0x000 [ 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00 ]
    , 0x145b
    , "0000010000010000011000001000001000001000001000001000001000001000001000001000001000001000001000001000010100010110111"
    )
  ; ( Can.Frame.data ~id:0x7ff [ 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff ]
    , 0x4c89
    , "011111011111010001000111110111110111110111110111110111110111110111110111110111110111110111110111110001100100010011"
    )
  ; Can.Frame.remote ~id:0x0f0 ~dlc:4, 0x1459, "00001111000010001000010100010110011"
  ; ( Can.Frame.data ~id:0x2a5 [ 0x12; 0x34; 0x56 ]
    , 0x5b64
    , "001010100101000001110001001000110100010101101011011011001001" )
  ; ( { (Can.Frame.data ~id:0x6b1 [ 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff ]) with
        dlc = 12
      }
    , 0x3d8f
    , "011010110001000110011111011111011111011111011111011111011111011111011111011111011111011111011110111101100011111"
    )
    (* demo/can_node.c's replies *)
  ; ( Can.Frame.data ~id:0x0a1 [ 0x01; 0x02; 0x03 ]
    , 0x73cc
    , "0000101000010000011100000100100000101000001001111100011110011001" )
  ; Can.Frame.remote ~id:0x0a2 ~dlc:2, 0x532a, "00001010001010000101010011001010101"
  ; ( Can.Frame.data ~id:0x6b1 [ 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0xff ]
    , 0x556e
    , "0110101100010001000111110111110111110111110111110111110111110111110111110111110111110111110111110010101011011101"
    )
  ; ( Can.Frame.data ~id:0x000 [ 0x00; 0x00 ]
    , 0x25b1
    , "000001000001000001001000001000001000001000100101101100011" )
  ]
;;

(* SOF to the CRC delimiter, as our transmitter's builder makes it *)
let to_delimiter frame =
  let line = Can.line frame in
  List.take line (List.length line - 12)
;;

let%expect_test "can2040 builds every line as Can.line does" =
  List.iter can2040 ~f:(fun (frame, crc, line) ->
    [%test_result: int] ~message:"CRC" (Can.crc frame) ~expect:crc;
    [%test_result: string]
      ~message:"line"
      (string_of_bits (to_delimiter frame))
      ~expect:line);
  print_s [%message "" ~lines:(List.length can2040 : int)];
  [%expect {| (lines 13) |}]
;;

let frame_generator =
  let open Quickcheck.Generator.Let_syntax in
  let%bind id = Int.gen_incl 0 0x7ff in
  match%bind Int.gen_incl 0 3 with
  | 0 ->
    let%map dlc = Int.gen_incl 0 15 in
    Can.Frame.remote ~id ~dlc
  | _ ->
    let%bind length = Int.gen_incl 0 8 in
    let%bind data = List.gen_with_length length (Int.gen_incl 0 0xff) in
    let%map dlc = if length = 8 then Int.gen_incl 8 15 else return length in
    { (Can.Frame.data ~id data) with dlc }
;;

let%expect_test "the host's words for a frame, and the error codes" =
  Quickcheck.test
    ~trials:1000
    ~sexp_of:[%sexp_of: Can.Frame.t]
    frame_generator
    ~f:(fun frame ->
      [%test_result: Receiver.Event.t list Or_error.t]
        (Receiver.read (Receiver.words frame))
        ~expect:(Ok [ Frame frame ]));
  print_s
    [%message
      ""
        ~words:
          (Receiver.words (Can.Frame.data ~id:0x2a5 [ 0x12; 0x34; 0x56 ])
           : Int.Hex.t list)
        ~codes:
          (List.map Receiver.Error_code.all ~f:(fun code ->
             code, Receiver.Error_code.to_word code)
           : (Receiver.Error_code.t * int) list)];
  [%expect
    {|
    ((words (0x2a5 0x3 0x12 0x3456 0x0))
     (codes ((Stuffing 1) (Refused 2) (Form 3) (Crc 4))))
    |}]
;;

(* A node that sends lines from SOF to the CRC delimiter, a bit every [period_milli]
   thousandths of a cycle, the first SOF at [start] and each next [gap] bits after the ACK
   slot, 11 by default, and lets go for every ACK slot, which it reads three quarters in. *)
module Node = struct
  type t =
    { bits : bool array
    ; acks : int list
    ; start : int
    ; period_milli : int
    }

  let create ?(gap = 11) ?(start = 2_000) ?(period_milli = 96_000) lines =
    let bits, acks =
      List.fold lines ~init:([], []) ~f:(fun (bits, acks) line ->
        let ack = List.length bits + List.length line in
        bits @ line @ List.init (1 + gap) ~f:(fun _ -> true), ack :: acks)
    in
    { bits = Array.of_list bits; acks = List.rev acks; start; period_milli }
  ;;

  let index t ~cycle = (cycle - t.start) * 1000 / t.period_milli

  let drive t ~cycle =
    let i = index t ~cycle in
    cycle < t.start || i >= Array.length t.bits || t.bits.(i)
  ;;

  let ack_cycles t =
    List.map t.acks ~f:(fun ack -> t.start + (((4 * ack) + 3) * t.period_milli / 4000))
  ;;

  let cycles t = t.start + ((Array.length t.bits + 20) * t.period_milli / 1000)
end

module Run = struct
  type t =
    { events : Receiver.Event.t list Or_error.t
    ; acked : bool list
    ; fault : Machine.Fault.t
    ; ack_low_cycles : int
    }
  [@@deriving sexp_of]
end

(* The receiver on a bus with [node], CRX [delay] cycles behind the bus for the
   transceiver and the synchroniser. The host drains the rx fifo every cycle, and after
   each irq clears it and writes a word, as the receiver asks. *)
let receive ?(delay = 3) ?(firmware = Receiver.firmware) node =
  let ack_cycles = Node.ack_cycles node in
  let rec loop (t : Machine.t) ~cycle ~line ~words ~segments ~acked ~low =
    if cycle = Node.cycles node
    then t, List.rev (List.rev words :: segments), List.rev acked, low
    else (
      let bus = Node.drive node ~cycle && bit t.pin_out Can.tx_pin in
      let acked = if List.mem ack_cycles cycle ~equal then not bus :: acked else acked in
      let low = if bit t.pin_out Can.tx_pin then low else low + 1 in
      let line = line @ [ bus ] in
      let seen, line = List.hd_exn line, List.tl_exn line in
      let t = Machine.step t ~inputs:(if seen then 1 lsl rx_pin else 0) in
      let rec drain (t : Machine.t) words =
        match Machine.read_rx t with
        | Some (word, t) -> drain t (word :: words)
        | None -> t, words
      in
      let t, words = drain t words in
      let t, words, segments =
        if t.irq
        then (
          let t = Machine.write_tx (Machine.clear_irq t) 0 |> ok_exn in
          t, [], List.rev words :: segments)
        else t, words, segments
      in
      loop t ~cycle:(cycle + 1) ~line ~words ~segments ~acked ~low)
  in
  let t =
    Machine.create
      ~config:(Timed_program.config firmware)
      ~program:(Timed_program.words firmware)
    |> ok_exn
  in
  let t, segments, acked, low =
    loop
      t
      ~cycle:0
      ~line:(List.init delay ~f:(fun _ -> true))
      ~words:[]
      ~segments:[]
      ~acked:[]
      ~low:0
  in
  { Run.events =
      Or_error.all (List.map segments ~f:Receiver.read) |> Or_error.map ~f:List.concat
  ; acked
  ; fault = t.fault
  ; ack_low_cycles = low
  }
;;

let print_run (run : Run.t) =
  print_s
    [%message
      ""
        ~events:(run.events : Receiver.Event.t list Or_error.t)
        ~acked:(run.acked : bool list)
        ~fault:(run.fault : Machine.Fault.t)]
;;

let%expect_test "the receiver takes can2040's lines and ACKs each" =
  let run =
    receive (Node.create (List.map can2040 ~f:(fun (_, _, line) -> bits_of_string line)))
  in
  [%test_result: Receiver.Event.t list Or_error.t]
    run.events
    ~expect:(Ok (List.map can2040 ~f:(fun (frame, _, _) -> Receiver.Event.Frame frame)));
  print_run run;
  (* the CTX pin low for the ACK slots only *)
  print_s [%message "" ~ack_bits:(run.ack_low_cycles / Receiver.period : int)];
  [%expect
    {|
    ((events
      (Ok
       ((Frame ((id 291) (rtr false) (dlc 2) (data (222 173))))
        (Frame
         ((id 1365) (rtr false) (dlc 8) (data (0 255 85 170 1 128 127 254))))
        (Frame ((id 2031) (rtr false) (dlc 0) (data ())))
        (Frame ((id 0) (rtr false) (dlc 1) (data (1))))
        (Frame ((id 0) (rtr false) (dlc 8) (data (0 0 0 0 0 0 0 0))))
        (Frame
         ((id 2047) (rtr false) (dlc 8) (data (255 255 255 255 255 255 255 255))))
        (Frame ((id 240) (rtr true) (dlc 4) (data ())))
        (Frame ((id 677) (rtr false) (dlc 3) (data (18 52 86))))
        (Frame
         ((id 1713) (rtr false) (dlc 12)
          (data (255 255 255 255 255 255 255 255))))
        (Frame ((id 161) (rtr false) (dlc 3) (data (1 2 3))))
        (Frame ((id 162) (rtr true) (dlc 2) (data ())))
        (Frame
         ((id 1713) (rtr false) (dlc 8) (data (255 255 255 255 255 255 255 255))))
        (Frame ((id 0) (rtr false) (dlc 2) (data (0 0)))))))
     (acked (true true true true true true true true true true true true true))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (ack_bits 13)
    |}]
;;

(* Back to back, each SOF in the third bit of the intermission, from a sender whose clock
   is off by up to 1%: from the CRC's last falling edge to the next SOF is up to 23 bits
   with none to resynchronise on, and the quarter bit after the sample has to cover it.
   Alone, with idle between, 1.5% either way. *)
let%expect_test "frames from a node whose clock is off" =
  let trial ~off frames =
    let open Quickcheck.Generator.Let_syntax in
    let%bind frames = List.gen_with_length frames frame_generator in
    let%bind period_milli = Int.gen_incl (96_000 - (off * 96)) (96_000 + (off * 96)) in
    let%bind start = Int.gen_incl 1_500 3_000 in
    let%map delay = Int.gen_incl 2 6 in
    frames, period_milli, start, delay
  in
  List.iter
    [ 10, 10, 4; 30, 15, 1 ]
    ~f:(fun (gap, off, frames) ->
      Quickcheck.test
        ~trials:100
        ~sexp_of:[%sexp_of: Can.Frame.t list * int * int * int]
        (trial ~off frames)
        ~f:(fun (frames, period_milli, start, delay) ->
          let run =
            receive
              ~delay
              (Node.create ~gap ~start ~period_milli (List.map frames ~f:to_delimiter))
          in
          [%test_result: Receiver.Event.t list Or_error.t]
            run.events
            ~expect:(Ok (List.map frames ~f:(fun frame -> Receiver.Event.Frame frame)));
          [%test_result: bool list]
            ~message:"acked"
            run.acked
            ~expect:(List.map frames ~f:(fun _ -> true));
          [%test_result: Machine.Fault.t] run.fault ~expect:Machine.Fault.none);
      print_s [%message "" (gap : int) ~off_tenths_of_a_percent:(off : int) "held"]);
  [%expect
    {|
    ((gap 10) (off_tenths_of_a_percent 10) held)
    ((gap 30) (off_tenths_of_a_percent 15) held)
    |}]
;;

(* the bits of a frame's own making, stuffed, with the CRC over them, to the delimiter *)
let stuff bits =
  List.fold bits ~init:([], None, 0) ~f:(fun (sent, last, run) bit ->
    let run = if Option.equal Bool.equal last (Some bit) then run + 1 else 1 in
    if run = 5
    then not bit :: bit :: sent, Some (not bit), 1
    else bit :: sent, Some bit, run)
  |> fun (sent, _, _) -> List.rev sent
;;

let msb_first value ~width =
  List.init width ~f:(fun i -> (value lsr (width - 1 - i)) land 1 = 1)
;;

let line_of fields =
  let unstuffed = false :: fields in
  stuff (unstuffed @ msb_first (Can.crc15 unstuffed) ~width:15) @ [ true ]
;;

let flip line n = List.mapi line ~f:(fun i b -> if i = n then not b else b)

(* After each, the host's word lets it listen again, and the frame after is taken. *)
let%expect_test "frames it refuses, and the one after" =
  let good = Can.Frame.data ~id:0x123 [ 0xde; 0xad ] in
  let line = to_delimiter good in
  let extended =
    (* ID 0x123, SRR and IDE recessive, then an 18-bit extension, RTR, r1, r0, DLC 1 *)
    line_of
      (msb_first 0x123 ~width:11
       @ [ true; true ]
       @ msb_first 0x2aaaa ~width:18
       @ [ false; false; false ]
       @ msb_first 1 ~width:4
       @ msb_first 0x5a ~width:8)
  in
  let fd =
    line_of (msb_first 0x123 ~width:11 @ [ false; false; true ] @ msb_first 0 ~width:4)
  in
  List.iter
    [ "a data bit flipped", flip line 30
    ; "six equal bits", flip (to_delimiter (Can.Frame.data ~id:0 [ 0 ])) 5
    ; "an extended frame", extended
    ; "r0 recessive", fd
    ; "the CRC delimiter dominant", flip line (List.length line - 1)
    ]
    ~f:(fun (what, bad) ->
      let run = receive (Node.create ~gap:20 [ bad; line ]) in
      print_s
        [%message
          what
            ~events:(run.events : Receiver.Event.t list Or_error.t)
            ~acked:(run.acked : bool list)]);
  [%expect
    {|
    ("a data bit flipped"
     (events
      (Ok ((Error Crc) (Frame ((id 291) (rtr false) (dlc 2) (data (222 173)))))))
     (acked (false true)))
    ("six equal bits"
     (events
      (Ok
       ((Error Stuffing) (Frame ((id 291) (rtr false) (dlc 2) (data (222 173)))))))
     (acked (false true)))
    ("an extended frame"
     (events
      (Ok
       ((Error Refused) (Frame ((id 291) (rtr false) (dlc 2) (data (222 173)))))))
     (acked (false true)))
    ("r0 recessive"
     (events
      (Ok
       ((Error Refused) (Frame ((id 291) (rtr false) (dlc 2) (data (222 173)))))))
     (acked (false true)))
    ("the CRC delimiter dominant"
     (events
      (Ok ((Error Form) (Frame ((id 291) (rtr false) (dlc 2) (data (222 173)))))))
     (acked (false true)))
    |}]
;;

let%expect_test "every sample and the ACK's edges are placed by a deadline" =
  Timing_report.print
    ~period:Receiver.period
    ~single_capture_edge:true
    ~config:Receiver.config
    (Timed_program.source Receiver.firmware);
  [%expect
    {|
      3  set pins, 1                  phase ?..?  edge ?..?  jitter ?  gap ?..?
     27  in pins, 1                   phase -95  sample -95
     48  in pins, 1                   phase -95  sample -95
    137  in pins, 1                   phase -95  sample -95
    158  in pins, 1                   phase -95  sample -95
    175  in pins, 1                   phase -95  sample -95
    196  in pins, 1                   phase -95  sample -95
    216  set pins, 0                  phase -72  edge -71  gap 323..?
    219  set pins, 1                  phase -72  edge -71  gap 96
    ((words 239) (edge_jitter unbounded) (sample_jitter 0) (side_jitter 0)
     (may_miss 0))
    |}]
;;

module G = Hardcaml_verify.Comb_gates

(* The firmware is made for its period, with the sample three quarters in. The phase a
   resynchronisation leaves is as wide as a bit, the capture could be anywhere since the
   arm, so the quarter after the sample has to hold the longest way to the next sample. *)
let%expect_test "the kernel accepts the receiver from its shortest period up" =
  let check period =
    match Receiver.check ~period ~sample:(3 * period / 4) with
    | Ok timed -> Ok (Timed_program.verdict timed)
    | Error refusal ->
      Error (List.map refusal.faults ~f:(fun fault -> fault.pc, fault.reason))
  in
  let shortest = Receiver.shortest_period in
  print_s
    [%message
      ""
        ~bench:
          (check Receiver.period
           : (Analyser.Verdict.t, (int option * string) list) Result.t)
        (shortest : int)
        ~accepted:
          (check shortest : (Analyser.Verdict.t, (int option * string) list) Result.t)
        ~one_less:
          (check (shortest - 1)
           : (Analyser.Verdict.t, (int option * string) list) Result.t)
        ~every_period_to_250_kbits:
          (List.for_all (List.range shortest 193) ~f:(fun period ->
             Result.is_ok (check period))
           : bool)];
  [%expect
    {|
    ((bench (Ok ((words 239) (deadline_waits 16) (worst_slack (24)))))
     (shortest 63)
     (accepted (Ok ((words 231) (deadline_waits 16) (worst_slack (1)))))
     (one_less
      (Error
       (((206) "this deadline wait can be reached 1 cycle late (slack -1..92)"))))
     (every_period_to_250_kbits true))
    |}]
;;

(* What a core pushes, drained every cycle. *)
let drain (t : Machine.t) words =
  let rec go (t : Machine.t) words =
    match Machine.read_rx t with
    | Some (word, t) -> go t (word :: words)
    | None -> t, words
  in
  go t words
;;

(* The sender and, if [receiver], the receiver with its ACK on OUT2, on one bus through
   two transceivers, as engine 0 and engine 1 in test/test_outside.py. The bus is the AND
   of both CTX pins, and both read it on IN1 [delay] cycles late. The sender's host feeds
   it the period and every frame's words as the fifo has room. *)
let ack_pin = 7

let on_one_bus ?(delay = 3) ?(receiver = true) ~period frames =
  let sender =
    Machine.create
      ~config:(Timed_program.config Sender.firmware)
      ~program:(Timed_program.words Sender.firmware)
    |> ok_exn
  in
  let firmware =
    Receiver.check ~period ~sample:(3 * period / 4) |> Result.ok |> Option.value_exn
  in
  let receiver_config =
    { (Timed_program.config firmware) with set_base = ack_pin; out_base = ack_pin }
  in
  let listener =
    Machine.create ~config:receiver_config ~program:(Timed_program.words firmware)
    |> ok_exn
  in
  let cycles =
    (List.sum (module Int) frames ~f:(fun frame -> List.length (Can.line frame) + 4) + 20)
    * period
  in
  let rec loop
    (sender : Machine.t)
    (listener : Machine.t)
    ~schedule
    ~line
    ~acks
    ~heard
    ~levels
    n
    =
    if n = cycles
    then sender, listener, List.rev acks, List.rev heard, List.rev levels
    else (
      let bus =
        bit sender.pin_out Can.tx_pin && ((not receiver) || bit listener.pin_out ack_pin)
      in
      let line = line @ [ bus ] in
      let inputs = if List.hd_exn line then 1 lsl rx_pin else 0 in
      let line = List.tl_exn line in
      let sender, schedule =
        match schedule with
        | word :: rest
          when n >= 13 * period && List.length sender.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx sender word |> ok_exn, rest
        | schedule -> sender, schedule
      in
      let sender, acks = drain (Machine.step sender ~inputs) acks in
      let listener, heard = drain (Machine.step listener ~inputs) heard in
      loop sender listener ~schedule ~line ~acks ~heard ~levels:(bus :: levels) (n + 1))
  in
  (* the sender's pin is dominant until it has the period, and the receiver waits for
     eleven idle bits, so the frames come 13 bits after the period *)
  let schedule = List.concat_map frames ~f:Can.words in
  let sender, listener, acks, heard, levels =
    loop
      (Machine.write_tx sender period |> ok_exn)
      listener
      ~schedule
      ~line:(List.init delay ~f:(fun _ -> true))
      ~acks:[]
      ~heard:[]
      ~levels:[]
      0
  in
  ( acks
  , (if receiver then Receiver.read heard else Ok [])
  , sender.fault
  , listener.fault
  , levels )
;;

let frames =
  [ Can.Frame.data ~id:0x123 [ 0xde; 0xad ]
  ; Can.Frame.data ~id:0x555 [ 0x00; 0xff; 0x55; 0xaa; 0x01; 0x80; 0x7f; 0xfe ]
  ; Can.Frame.data ~id:0x7ef []
  ; Can.Frame.remote ~id:0x0f0 ~dlc:4
  ; Can.Frame.data ~id:0x000 [ 0x01 ]
  ]
;;

let%expect_test "the sender reads the receiver's ACK, and none when it is gone" =
  List.iter [ true; false ] ~f:(fun receiver ->
    let acks, heard, sender_fault, receiver_fault, _ =
      on_one_bus ~receiver ~period:Receiver.period frames
    in
    print_s
      [%message
        ""
          (receiver : bool)
          (acks : int list)
          (heard : Receiver.Event.t list Or_error.t)
          (sender_fault : Machine.Fault.t)
          (receiver_fault : Machine.Fault.t)]);
  [%expect
    {|
    ((receiver true) (acks (0 0 0 0 0))
     (heard
      (Ok
       ((Frame ((id 291) (rtr false) (dlc 2) (data (222 173))))
        (Frame
         ((id 1365) (rtr false) (dlc 8) (data (0 255 85 170 1 128 127 254))))
        (Frame ((id 2031) (rtr false) (dlc 0) (data ())))
        (Frame ((id 240) (rtr true) (dlc 4) (data ())))
        (Frame ((id 0) (rtr false) (dlc 1) (data (1)))))))
     (sender_fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (receiver_fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((receiver false) (acks (1 1 1 1 1)) (heard (Ok ()))
     (sender_fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (receiver_fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "every edge, the ACK's sample among them, is placed by a deadline" =
  Timing_report.print
    ~period:Receiver.period
    ~config:Sender.config
    (Timed_program.source Sender.firmware);
  [%expect
    {|
      6  set pins, 1                  phase -95  edge -94  gap ?..?
     15  set pins, 0                  phase -95  edge -94  gap 103..?
     19  out pins, 1                  phase -95  edge -94  gap 89..103
     23  out pins, 1                  phase -95  edge -94  gap 89..103
     29  mov pins, !pins              phase -95  edge -94  gap 94..98
     37  out pins, 1                  phase -95  edge -94  gap 88..104
     41  out pins, 1                  phase -95  edge -94  gap 88..104
     47  mov pins, !pins              phase -95  edge -94  gap 94..98
     51  set pins, 1                  phase -95  edge -94  gap 91..101
     56  mov isr, pins                phase 1  sample 1
    ((words 64) (edge_jitter 0) (sample_jitter 0) (side_jitter 0) (may_miss 0))
    |}]
;;

(* As Can.firmware's: the host picks the rate, so the kernel accepts the analyser's rows
   at every load of the floor or more, by checked SAT, and refuses them at one less. *)
let%expect_test "the kernel accepts the sender at every period from the shortest up" =
  let program = Timed_program.program Sender.firmware in
  let config = Asm.Program.configure program Sender.config in
  let words = Asm.Program.words program |> ok_exn in
  let table ~floor =
    Analyser.analyse ~period_floor:floor ~config program.instructions
    |> Kernel.Table.of_analyser
  in
  let check ~floor =
    Kernel.check ~period:floor ~single_capture_edge:false ~config ~words (table ~floor)
  in
  let shortest = Sender.shortest_period in
  print_s
    [%message
      ""
        ~kernel:(check ~floor:shortest : unit Or_error.t)
        ~one_less:(check ~floor:(shortest - 1) : unit Or_error.t)];
  let loads_from floor =
    Table_query.every_load_from
      ~floor
      ~single_capture_edge:false
      ~config
      ~words
      (table ~floor:shortest)
  in
  Checked_unsat.prove
    [%string "can sender: every load of %{shortest#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from shortest);
  Checked_unsat.prove
    ~show:[ "loaded" ]
    [%string "can sender: every load of %{shortest - 1#Int} or more"]
    ~cases:[ G.vdd ]
    ~claim:(loads_from (shortest - 1));
  [%expect
    {|
    ((kernel (Ok ()))
     (one_less
      (Error
       ("rows the kernel rejects"
        (rejected
         (((pc 36) (fails ("in time"))) ((pc 40) (fails ("in time")))
          ((pc 55) (fails ("in time")))))))))
    (QED "can sender: every load of 15 or more")
    (counterexample "can sender: every load of 14 or more"
     (model ((loaded 0000000000001110))))
    |}]
;;

(* A node that ACKs the frames it expects: from each SOF, a fall while no frame is going,
   it counts to the ACK slot at the sender's own period. *)
let%expect_test "the sender's ACK read, against a node that ACKs only the second frame" =
  let period = Sender.shortest_period + 1 in
  let lengths = List.map frames ~f:(fun frame -> List.length (Can.line frame)) in
  let t =
    Machine.create
      ~config:(Timed_program.config Sender.firmware)
      ~program:(Timed_program.words Sender.firmware)
    |> ok_exn
  in
  let rec loop (t : Machine.t) ~schedule ~last ~sof ~frame ~acks n =
    if n = 20_000
    then t, List.rev acks
    else (
      let line = bit t.pin_out Can.tx_pin in
      let acking =
        match sof with
        | Some at ->
          let ack = at + ((List.nth_exn lengths frame - 12) * period) in
          frame = 1 && n >= ack && n < ack + period
        | None -> false
      in
      let bus = line && not acking in
      let sof, frame =
        match sof with
        | None when last && not bus -> Some n, frame
        | Some at when n >= at + ((List.nth_exn lengths frame - 1) * period) ->
          None, frame + 1
        | sof -> sof, frame
      in
      let t, schedule =
        match schedule with
        | word :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx t word |> ok_exn, rest
        | schedule -> t, schedule
      in
      let t, acks =
        drain (Machine.step t ~inputs:(if bus then 1 lsl rx_pin else 0)) acks
      in
      loop t ~schedule ~last:bus ~sof ~frame ~acks (n + 1))
  in
  let t, acks =
    loop
      t
      ~schedule:(period :: List.concat_map frames ~f:Can.words)
      ~last:false
      ~sof:None
      ~frame:0
      ~acks:[]
      0
  in
  print_s [%message (acks : int list) (t.fault : Machine.Fault.t)];
  [%expect
    {|
    ((acks (1 0 1 1 1))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* At the shortest period, so the runs are short: the receiver taking three of can2040's
   lines, and the sender sending two frames with CTX looped back to CRX, so no ACK. *)
let%expect_test "the receiver and the sender in lockstep" =
  let period = Receiver.shortest_period in
  let firmware =
    Receiver.check ~period ~sample:(3 * period / 4) |> Result.ok |> Option.value_exn
  in
  let node =
    Node.create
      ~period_milli:(period * 1000)
      (List.take can2040 3 |> List.map ~f:(fun (_, _, line) -> bits_of_string line))
  in
  let ctx = ref true
  and line = ref [ true; true; true ]
  and words = ref [] in
  let model =
    Lockstep.lockstep
      ~cycles:(Node.cycles node)
      ~config:(Timed_program.config firmware)
      ~program:(Timed_program.words firmware)
      ~inputs:(fun cycle ->
        line := !line @ [ Node.drive node ~cycle && !ctx ];
        let seen = List.hd_exn !line in
        line := List.tl_exn !line;
        if seen then 1 lsl rx_pin else 0)
      ~host:(fun _ -> { Lockstep.Host.idle with pop_rx = true })
      ~react:(fun m ->
        ctx := bit m.pin_out Can.tx_pin;
        Option.iter (List.hd m.rx_fifo) ~f:(fun word -> words := word :: !words))
      ()
  in
  print_s
    [%message
      ""
        ~heard:(Receiver.read (List.rev !words) : Receiver.Event.t list Or_error.t)
        (model.fault : Machine.Fault.t)];
  let schedule = ref (period :: List.concat_map (List.take frames 2) ~f:Can.words)
  and tx_level = ref 0
  and acks = ref [] in
  let model =
    Lockstep.lockstep
      ~cycles:
        (List.sum (module Int) (List.take frames 2) ~f:(fun frame ->
           List.length (Can.line frame) + 3)
         * period)
      ~config:(Timed_program.config Sender.firmware)
      ~program:(Timed_program.words Sender.firmware)
      ~inputs:(fun _ -> if !ctx then 1 lsl rx_pin else 0)
      ~host:(fun _ ->
        match !schedule with
        | word :: rest when !tx_level < Machine.fifo_depth ->
          schedule := rest;
          { Lockstep.Host.idle with tx = Some word; pop_rx = true }
        | _ -> { Lockstep.Host.idle with pop_rx = true })
      ~react:(fun m ->
        tx_level := List.length m.tx_fifo;
        ctx := bit m.pin_out Can.tx_pin;
        Option.iter (List.hd m.rx_fifo) ~f:(fun word -> acks := word :: !acks))
      ()
  in
  print_s [%message "" ~acks:(List.rev !acks : int list) (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 17876))
    ((heard
      (Ok
       ((Frame ((id 291) (rtr false) (dlc 2) (data (222 173))))
        (Frame
         ((id 1365) (rtr false) (dlc 8) (data (0 255 85 170 1 128 127 254))))
        (Frame ((id 2031) (rtr false) (dlc 0) (data ()))))))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ("lockstep held" (cycles 11907))
    ((acks (1 1))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
