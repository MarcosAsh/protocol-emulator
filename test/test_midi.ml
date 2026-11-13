open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Midi.firmware));
  [%expect {| 17 words, 3 deadline waits, worst slack 1532 |}]
;;

(* A receiver as CA-033 describes the line: a start bit, 8 data bits LSB first and a stop
   bit, each sampled in its middle. It keeps the bit it measures at the start edge and the
   byte after it, which is 320 us. *)
module Receiver = struct
  let bit = Midi.period

  type t =
    { cycle : int
    ; level : int
    ; started : int option
    ; bits : int list (* newest first *)
    ; bytes : int list (* newest first *)
    ; starts : int list (* the start edges, newest first *)
    ; violations : string list
    }

  let create =
    { cycle = 0
    ; level = 1
    ; started = None
    ; bits = []
    ; bytes = []
    ; starts = []
    ; violations = []
    }
  ;;

  let bytes t = List.rev t.bytes
  let starts t = List.rev t.starts

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let finish t =
    let bits = List.rev t.bits in
    let byte =
      List.foldi
        (List.take (List.tl_exn bits) 8)
        ~init:0
        ~f:(fun i byte b -> byte lor (b lsl i))
    in
    let t = if List.last_exn bits = 0 then violate t "a framing error" else t in
    { t with started = None; bytes = byte :: t.bytes }
  ;;

  let step t ~level =
    let t = { t with cycle = t.cycle + 1 } in
    let t =
      if t.level = 1 && level = 0 && Option.is_none t.started
      then { t with started = Some t.cycle; bits = []; starts = t.cycle :: t.starts }
      else t
    in
    let t = { t with level } in
    match t.started with
    | Some at when (t.cycle - at - (bit / 2)) % bit = 0 && t.cycle - at >= bit / 2 ->
      let t = { t with bits = level :: t.bits } in
      if List.length t.bits = 10 then finish t else t
    | _ -> t
  ;;
end

let run ~cycles =
  let config = Timed_program.config Midi.firmware in
  let machine =
    Machine.create ~config ~program:(Timed_program.words Midi.firmware) |> ok_exn
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
        (Receiver.step receiver ~level:((machine.pin_out lsr Midi.pin) land 1))
        (n - 1))
  in
  loop machine (Midi.period :: List.concat Midi.messages) Receiver.create cycles
;;

(* Channel messages, from the data bytes each takes by status: 8n 9n An Bn En take two, Cn
   Dn one. A data byte with no status before it belongs to the last one. *)
let messages bytes =
  let length status =
    match status land 0xf0 with
    | 0xc0 | 0xd0 -> 1
    | _ -> 2
  in
  let rec go status pending acc = function
    | [] -> List.rev acc
    | byte :: rest when byte land 0x80 <> 0 -> go byte [] acc rest
    | byte :: rest ->
      let pending = pending @ [ byte ] in
      if List.length pending = length status
      then go status [] ((status :: pending) :: acc) rest
      else go status pending acc rest
  in
  go 0 [] [] bytes
;;

let%expect_test "a receiver reads the messages, a byte every 320 us" =
  let machine, receiver = run ~cycles:(14 * 10 * Midi.period) in
  let bytes = Receiver.bytes receiver in
  [%test_result: int list] ~message:"bytes" bytes ~expect:(List.concat Midi.messages);
  let spans =
    List.map2_exn
      (List.drop_last_exn (Receiver.starts receiver))
      (List.tl_exn (Receiver.starts receiver))
      ~f:(fun a b -> Measured.ns ~clock_hz:Bench.clock_hz (b - a))
  in
  print_s
    [%message
      ""
        ~messages:
          (List.map (messages bytes) ~f:(List.map ~f:(sprintf "%02X")) : string list list)
        ~byte_ns:(List.dedup_and_sort spans ~compare:Int.compare : int list)
        ~violations:(Receiver.(receiver.violations) : string list)
        ~fault:(machine.fault : Machine.Fault.t)];
  [%expect {|
    ((messages ((90 3C 40) (90 3E 40) (80 3C 00) (C0 05) (B0 07 64)))
     (byte_ns (320125)) (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false))))
    |}]
;;
