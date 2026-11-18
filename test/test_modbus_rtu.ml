open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Modbus_rtu.firmware));
  [%expect {| 28 words, 6 deadline waits, worst slack 2496 |}]
;;

(* CRC-16/MODBUS of two frames whose CRCs are widely published *)
let%expect_test "the CRC of known frames" =
  let show bytes =
    let crc = Modbus_rtu.crc bytes in
    printf "%02X %02X\n" (crc land 0xff) (crc lsr 8)
  in
  show [ 0x01; 0x03; 0x00; 0x00; 0x00; 0x0a ];
  show [ 0x11; 0x06; 0x00; 0x01; 0x00; 0x03 ];
  [%expect {|
    C5 CD
    9A 9B
    |}]
;;

(* A receiver as section 2.5.1 and 2.5.1.1 describe it. A character is a start bit, 8 data
   bits LSB first, an even parity bit and a stop bit, each sampled in its middle. A
   silence over 3.5 characters ends a frame and one over 1.5 inside a frame would make it
   incomplete, so a silence between the two is refused. *)
module Receiver = struct
  let bit = Modbus_rtu.period
  let t15 = 15 * 11 * bit / 10
  let t35 = 35 * 11 * bit / 10

  type t =
    { cycle : int
    ; level : int
    ; started : int option (* the cycle of a character's start edge *)
    ; ends : int (* the last character's end *)
    ; bits : int list (* newest first *)
    ; frame : int list (* newest first *)
    ; frames : int list list
    ; gaps : int list
    ; violations : string list
    }

  let create =
    { cycle = 0
    ; level = 1
    ; started = None
    ; ends = 0
    ; bits = []
    ; frame = []
    ; frames = []
    ; gaps = []
    ; violations = []
    }
  ;;

  let frames t =
    List.rev (if List.is_empty t.frame then t.frames else List.rev t.frame :: t.frames)
  ;;

  let gaps t = List.rev t.gaps
  let violations t = List.rev t.violations

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let start t =
    let gap = t.cycle - t.ends in
    let t = { t with gaps = gap :: t.gaps; started = Some t.cycle; bits = [] } in
    if gap > t35
    then
      { t with
        frames =
          (if List.is_empty t.frame then t.frames else List.rev t.frame :: t.frames)
      ; frame = []
      }
    else if gap > t15
    then violate t "a silence between 1.5 and 3.5 characters"
    else t
  ;;

  (* the 11 bits of a character, once the stop bit is in *)
  let finish t =
    let bits = List.rev t.bits in
    let data = List.take (List.tl_exn bits) 8 in
    let byte = List.foldi data ~init:0 ~f:(fun i byte b -> byte lor (b lsl i)) in
    let parity = List.nth_exn bits 9 in
    let t =
      if parity <> Int.popcount byte land 1 then violate t "a parity error" else t
    in
    let t = if List.last_exn bits = 0 then violate t "a framing error" else t in
    { t with started = None; ends = t.cycle + (bit / 2); frame = byte :: t.frame }
  ;;

  let step t ~level =
    let t = { t with cycle = t.cycle + 1 } in
    let t = if t.level = 1 && level = 0 && Option.is_none t.started then start t else t in
    let t = { t with level } in
    match t.started with
    | Some at when (t.cycle - at - (bit / 2)) % bit = 0 && t.cycle - at >= bit / 2 ->
      let t = { t with bits = level :: t.bits } in
      if List.length t.bits = 11 then finish t else t
    | _ -> t
  ;;
end

let run ~cycles =
  let config = Timed_program.config Modbus_rtu.firmware in
  let machine =
    Machine.create ~config ~program:(Timed_program.words Modbus_rtu.firmware) |> ok_exn
  in
  let words =
    Modbus_rtu.period :: List.concat_map Modbus_rtu.requests ~f:Modbus_rtu.frame
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
        (Receiver.step receiver ~level:((machine.pin_out lsr Modbus_rtu.pin) land 1))
        (n - 1))
  in
  loop machine words Receiver.create cycles
;;

let%expect_test "a receiver reads both frames, each after 3.5 characters of silence" =
  let machine, receiver = run ~cycles:700_000 in
  let frames = Receiver.frames receiver in
  [%test_result: int list list]
    ~message:"frames"
    frames
    ~expect:
      (List.map Modbus_rtu.requests ~f:(fun bytes ->
         let crc = Modbus_rtu.crc bytes in
         bytes @ [ crc land 0xff; crc lsr 8 ]));
  print_s
    [%message
      ""
        ~frames:(List.map frames ~f:(List.map ~f:(sprintf "%02X")) : string list list)
        ~residual:(List.map frames ~f:Modbus_rtu.crc : int list)
        ~gaps_in_bits_x10:
          (List.map (Receiver.gaps receiver) ~f:(fun gap -> gap * 10 / Receiver.bit)
           : int list)
        ~violations:(Receiver.violations receiver : string list)
        ~fault:(machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((frames ((01 03 00 00 00 0A C5 CD) (11 06 00 01 00 03 9A 9B)))
     (residual (0 0)) (gaps_in_bits_x10 (390 0 0 0 0 0 0 0 390 0 0 0 0 0 0 0))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false))))
    |}]
;;

(* a line of levels and the cycles each lasts, from idle *)
let receive runs =
  List.fold runs ~init:Receiver.create ~f:(fun receiver (level, cycles) ->
    Fn.apply_n_times ~n:cycles (fun r -> Receiver.step r ~level) receiver)
;;

(* a character of [byte] with its even parity bit, the stop bit running on as the mark *)
let character byte =
  let bit = Receiver.bit in
  let parity = Int.popcount byte land 1 in
  ((0, bit) :: List.init 8 ~f:(fun n -> (byte lsr n) land 1, bit))
  @ [ parity, bit; 1, bit ]
;;

let%expect_test "the receiver refuses a silence between 1.5 and 3.5 characters" =
  let chars n = Receiver.bit * 11 * n / 10 in
  let show gap =
    let receiver =
      receive
        (((1, chars 40) :: character 0x01) @ [ 1, gap ] @ character 0x02 @ [ 1, 100 ])
    in
    print_s
      [%message
        ""
          ~frames:(Receiver.frames receiver : int list list)
          ~violations:(Receiver.violations receiver : string list)]
  in
  show (chars 14);
  show (chars 20);
  show (chars 36);
  [%expect
    {|
    ((frames ((1 2))) (violations ()))
    ((frames ((1 2)))
     (violations ("a silence between 1.5 and 3.5 characters at 192501")))
    ((frames ((1) (2))) (violations ()))
    |}]
;;
