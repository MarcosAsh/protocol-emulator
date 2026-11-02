open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Dmx512.firmware));
  [%expect {| 52 words, 14 deadline waits, worst slack 182 |}]
;;

(* The line, level by level with the cycles each lasted, for a start code's word: the
   break, the mark after break and the start code 0x00, then the mark while the firmware
   waits for the first channels. *)
let%expect_test "the line for a start code" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Dmx512.firmware)
      ~program:(Timed_program.words Dmx512.firmware)
    |> ok_exn
  in
  let machine = Machine.write_tx machine 0x0000 |> ok_exn in
  let levels =
    List.folding_map (List.range 0 8_000) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      machine, (machine.pin_out lsr Dmx512.pin) land 1 = 1)
  in
  let runs =
    List.group levels ~break:Bool.( <> )
    |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  in
  print_s [%message (runs : (bool * int) list)];
  [%expect
    {| (runs ((false 4) (true 4) (false 4800) (true 768) (false 1728) (true 696))) |}]
;;

(* A receiver as the spec describes it (lines 291-297, 303-310): a low of at least 88 us
   is a break, the mark after it at least 8 us, then slots of a start bit, 8 bits LSB
   first and two stop bits, each bit sampled in its middle. A slot whose stop bits read
   low is a framing error, unless that low goes on to be a break. *)
module Receiver = struct
  let bit = Bench.clock_hz / 250_000
  let break_least = Measured.cycles ~clock_hz:Bench.clock_hz ~ns:88_000
  let mab_least = Measured.cycles ~clock_hz:Bench.clock_hz ~ns:8_000

  module State = struct
    type t =
      | Hunting
      | Mark_after_break of int
      | Slot of
          { start : int
          ; n : int
          ; byte : int
          }
      | Between
      | Framing
  end

  type t =
    { cycle : int
    ; level : int
    ; low_since : int
    ; last_break : int option
    ; state : State.t
    ; slots : int list
    ; packets : int list list
    ; measured : Measured.t
    ; violations : string list
    }

  let create =
    { cycle = 0
    ; level = 1
    ; low_since = 0
    ; last_break = None
    ; state = Hunting
    ; slots = []
    ; packets = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let packets t =
    List.rev (if List.is_empty t.slots then t.packets else List.rev t.slots :: t.packets)
  ;;

  let measured t = t.measured
  let violations t = List.rev t.violations

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let measure t name cycles =
    { t with
      measured =
        Measured.add t.measured ~name ~ns:(Measured.ns ~clock_hz:Bench.clock_hz cycles)
    }
  ;;

  (* a rising edge after a low of [low] cycles *)
  let rise t ~low =
    if low < break_least
    then t
    else (
      let t = measure t "break" low in
      let t =
        match t.last_break with
        | Some last -> measure t "break to break" (t.low_since - last)
        | None -> t
      in
      let packets =
        if List.is_empty t.slots then t.packets else List.rev t.slots :: t.packets
      in
      { t with
        state = Mark_after_break t.cycle
      ; last_break = Some t.low_since
      ; slots = []
      ; packets
      })
  ;;

  let fall t =
    match t.state with
    | Mark_after_break since ->
      let t = measure t "mark after break" (t.cycle - since) in
      let t =
        if t.cycle - since < mab_least then violate t "mark after break too short" else t
      in
      { t with state = Slot { start = t.cycle; n = 0; byte = 0 } }
    | Between -> { t with state = Slot { start = t.cycle; n = 0; byte = 0 } }
    | Hunting | Slot _ | Framing -> t
  ;;

  (* bit [n] of a slot, in its middle: 0 the start bit, 9 and 10 the stop bits *)
  let sample t ~start ~n ~byte =
    if t.cycle <> start + (bit / 2) + (n * bit)
    then t
    else if n = 0 && t.level = 1
    then violate { t with state = Between } "a start bit too short"
    else if n >= 9 && t.level = 0
    then { t with state = Framing }
    else if n = 10
    then { t with state = Between; slots = byte :: t.slots }
    else (
      let byte = if n >= 1 && n <= 8 then byte lor (t.level lsl (n - 1)) else byte in
      { t with state = Slot { start; n = n + 1; byte } })
  ;;

  let step t ~level =
    let t = { t with cycle = t.cycle + 1 } in
    let t =
      if level = t.level
      then t
      else if level = 1
      then (
        let low = t.cycle - t.low_since in
        match rise { t with level } ~low with
        | { state = Framing; _ } as t ->
          violate { t with state = Hunting } "a framing error"
        | t -> t)
      else fall { t with level; low_since = t.cycle }
    in
    match t.state with
    | Slot { start; n; byte } -> sample t ~start ~n ~byte
    | Hunting | Mark_after_break _ | Between | Framing -> t
  ;;
end

let start_code = 0x00
let channels = Dmx512.channels
let words = Dmx512.packet ~start_code channels

(* The host writes every word as the fifo has room. *)
let run ~cycles words =
  let config = Timed_program.config Dmx512.firmware in
  let machine =
    Machine.create ~config ~program:(Timed_program.words Dmx512.firmware) |> ok_exn
  in
  let rec loop (machine : Machine.t) words receiver n =
    if n = 0
    then machine, receiver
    else (
      let machine, words =
        match words with
        | word :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine word |> ok_exn, rest
        | words -> machine, words
      in
      let machine = Machine.step machine ~inputs:0 in
      loop
        machine
        words
        (Receiver.step receiver ~level:((machine.pin_out lsr Dmx512.pin) land 1))
        (n - 1))
  in
  loop machine words Receiver.create cycles
;;

let%expect_test "a receiver reads a full packet, and the next packet's break" =
  let machine, receiver = run ~cycles:1_105_000 (words @ [ start_code ]) in
  [%test_result: int list list]
    ~message:"packets"
    (Receiver.packets receiver)
    ~expect:[ start_code :: channels; [ start_code ] ];
  print_s
    [%message
      ""
        ~slots:(List.map (Receiver.packets receiver) ~f:List.length : int list)
        ~measured_ns:(Receiver.measured receiver : Measured.t)
        ~violations:(Receiver.violations receiver : string list)
        (machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((slots (513 1))
     (measured_ns
      ((break (100000 100000)) ("mark after break" (16000 16000))
       ("break to break" (22752104 22752104))))
     (violations ())
     (machine.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* a line of levels and the cycles each lasts, from idle *)
let receive runs =
  List.fold runs ~init:Receiver.create ~f:(fun receiver (level, cycles) ->
    Fn.apply_n_times ~n:cycles (fun r -> Receiver.step r ~level) receiver)
;;

(* a slot of [byte], its stop bits running on as the mark after it *)
let slot byte =
  let bit = Receiver.bit in
  ((0, bit) :: List.init 8 ~f:(fun n -> (byte lsr n) land 1, bit)) @ [ 1, 2 * bit ]
;;

let%expect_test "the receiver refuses a short break and a short mark after break" =
  let us n = n * Bench.clock_hz / 1_000_000 in
  let show runs =
    let receiver = receive runs in
    print_s
      [%message
        ""
          ~packets:(Receiver.packets receiver : int list list)
          ~violations:(Receiver.violations receiver : string list)]
  in
  show (((1, us 20) :: (0, us 87) :: (1, us 12) :: slot 0x00) @ slot 0x42);
  show (((1, us 20) :: (0, us 92) :: (1, us 7) :: slot 0x00) @ slot 0x42);
  show (((1, us 20) :: (0, us 92) :: (1, us 12) :: slot 0x00) @ slot 0x42);
  [%expect
    {|
    ((packets ()) (violations ()))
    ((packets ((0 66))) (violations ("mark after break too short at 5713")))
    ((packets ((0 66))) (violations ()))
    |}]
;;
