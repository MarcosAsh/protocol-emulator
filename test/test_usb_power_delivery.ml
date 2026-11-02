open! Core
open Protocol_emulator
module Message = Usb_power_delivery.Message

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline
    (Analyser.Verdict.to_string (Timed_program.verdict Usb_power_delivery.firmware));
  [%expect {| 113 words, 74 deadline waits, worst slack 13 |}]
;;

(* The pin's levels and the cycles each lasted, [words] fed as the fifo has room. *)
let run words ~cycles =
  let machine =
    Machine.create
      ~config:(Timed_program.config Usb_power_delivery.firmware)
      ~program:(Timed_program.words Usb_power_delivery.firmware)
    |> ok_exn
  in
  let machine, _, levels =
    List.fold
      (List.range 0 cycles)
      ~init:(machine, words, [])
      ~f:(fun (machine, queued, levels) _ ->
        let machine, queued =
          match queued with
          | word :: rest when List.length machine.Machine.tx_fifo < Machine.fifo_depth ->
            Machine.write_tx machine word |> ok_exn, rest
          | _ -> machine, queued
        in
        let machine = Machine.step machine ~inputs:0 in
        ( machine
        , queued
        , ((machine.pin_out lsr Usb_power_delivery.pin) land 1 = 1) :: levels ))
  in
  [%test_result: Machine.Fault.t] machine.fault ~expect:Machine.Fault.none;
  List.rev levels
  |> List.group ~break:Bool.( <> )
  |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
;;

(* The far end: a BMC receiver after 5.3.2 and 5.3.3, p.91-95, with its own copy of Table
   5.2 p.89-90 and the CRC residual of 5.3.1.1.4 p.90. A half UI is 80 cycles; a low of 3
   UI or more is idle. *)
module Receiver = struct
  let half = Usb_power_delivery.bit_cycles / 2

  let nibbles =
    [ 0b11110, 0x0
    ; 0b01001, 0x1
    ; 0b10100, 0x2
    ; 0b10101, 0x3
    ; 0b01010, 0x4
    ; 0b01011, 0x5
    ; 0b01110, 0x6
    ; 0b01111, 0x7
    ; 0b10010, 0x8
    ; 0b10011, 0x9
    ; 0b10110, 0xa
    ; 0b10111, 0xb
    ; 0b11010, 0xc
    ; 0b11011, 0xd
    ; 0b11100, 0xe
    ; 0b11101, 0xf
    ]
  ;;

  let sync_1 = 0b11000
  let sync_2 = 0b10001
  let eop = 0b01101

  (* the runs of each packet, between idle lows *)
  let packets levels =
    let idle (high, n) = (not high) && n >= 6 * half in
    let _, packets =
      List.fold levels ~init:([], []) ~f:(fun (packet, packets) run ->
        if idle run
        then [], if List.is_empty packet then packets else List.rev packet :: packets
        else run :: packet, packets)
    in
    List.rev packets
  ;;

  (* a whole UI is a 0, two halves a 1 *)
  let bits runs =
    let rec go bits = function
      | [] -> Ok (List.rev bits)
      | (_, n) :: rest when n = 2 * half -> go (0 :: bits) rest
      | (_, a) :: (_, b) :: rest when a = half && b = half -> go (1 :: bits) rest
      | (high, n) :: _ -> Or_error.error_s [%message "not BMC" (high : bool) (n : int)]
    in
    go [] runs
  ;;

  let crc_residual bytes =
    let reflected =
      List.fold bytes ~init:0xffffffff ~f:(fun crc byte ->
        Fn.apply_n_times
          ~n:8
          (fun crc -> if crc land 1 = 1 then (crc lsr 1) lxor 0xedb88320 else crc lsr 1)
          (crc lxor byte))
    in
    List.fold (List.range 0 32) ~init:0 ~f:(fun acc i ->
      acc lor (((reflected lsr i) land 1) lsl (31 - i)))
  ;;

  let message runs =
    let open Or_error.Let_syntax in
    let%bind bits = bits runs in
    let #(preamble, rest) = List.split_n bits 64 in
    let%bind () =
      if [%equal: int list] preamble (List.init 64 ~f:(fun i -> i land 1))
      then return ()
      else Or_error.error_s [%message "not a preamble" (preamble : int list)]
    in
    let rec symbols acc = function
      | b0 :: b1 :: b2 :: b3 :: b4 :: rest ->
        let symbol = b0 lor (b1 lsl 1) lor (b2 lsl 2) lor (b3 lsl 3) lor (b4 lsl 4) in
        if symbol = eop then return (List.rev acc, rest) else symbols (symbol :: acc) rest
      | _ -> Or_error.error_s [%message "no EOP"]
    in
    let%bind symbols, after = symbols [] rest in
    let%bind () =
      (* the trailing UI high after a low half, 5.3.4 rule 6, reads as a 0 *)
      match after with
      | [] | [ 0 ] -> return ()
      | _ -> Or_error.error_s [%message "after the EOP" (after : int list)]
    in
    let #(sop, data) = List.split_n symbols 4 in
    let%bind () =
      if [%equal: int list] sop [ sync_1; sync_1; sync_1; sync_2 ]
      then return ()
      else Or_error.error_s [%message "not SOP" (sop : int list)]
    in
    let%bind nibbles =
      List.map data ~f:(fun symbol ->
        List.Assoc.find nibbles symbol ~equal
        |> Result.of_option ~error:(Error.create_s [%message "not data" (symbol : int)]))
      |> Or_error.all
    in
    let bytes =
      List.chunks_of nibbles ~length:2
      |> List.map ~f:(function
        | [ lo; hi ] -> lo lor (hi lsl 4)
        | _ -> -1)
    in
    let%bind () =
      if crc_residual bytes = 0xc704dd7b
      then return ()
      else Or_error.error_s [%message "bad CRC"]
    in
    let word bytes = List.foldi bytes ~init:0 ~f:(fun i w b -> w lor (b lsl (8 * i))) in
    let header = word (List.take bytes 2) in
    let count = (header lsr 12) land 7 in
    let%map () =
      if List.length bytes = 2 + (4 * count) + 4
      then return ()
      else Or_error.error_s [%message "a length not the header's" (header : Int.Hex.t)]
    in
    { Message.header
    ; data_objects =
        List.init count ~f:(fun i -> word (List.sub bytes ~pos:(2 + (4 * i)) ~len:4))
    }
  ;;
end

(* The two Source_Capabilities of the bench's run, read back by the far end. Every level
   in a packet is a half or a whole UI: 80 or 160 cycles, 300 kbps. *)
let%expect_test "the far end reads back what the host sent" =
  let sent = Usb_power_delivery.sent in
  let levels =
    run
      (List.concat_map sent ~f:Message.words)
      ~cycles:(List.sum (module Int) sent ~f:Message.cycles + 2_000)
  in
  let widths =
    List.map levels ~f:snd
    |> List.sort_and_group ~compare
    |> List.map ~f:(fun group -> List.hd_exn group, List.length group)
  in
  print_s [%message (widths : (int * int) list)];
  let received =
    List.map (Receiver.packets levels) ~f:Receiver.message |> Or_error.all |> ok_exn
  in
  List.iter received ~f:(fun { Message.header; data_objects } ->
    print_s [%message "" (header : Int.Hex.t) (data_objects : Int.Hex.t list)]);
  [%test_result: Message.t list] received ~expect:sent;
  [%expect
    {|
    (widths ((80 404) (160 176) (1367 1) (1368 1) (2665 1)))
    ((header 0x11a1) (data_objects (0x1912c)))
    ((header 0x13a1) (data_objects (0x1912c)))
    |}]
;;

(* What the host writes for the first, as python/demo_usb_power_delivery.py does *)
let%expect_test "the host's words" =
  let words = Message.words (List.hd_exn Usb_power_delivery.sent) in
  print_s [%message (words : Int.Hex.t list)];
  [%expect {| (words (0x7c 0xe318 0x6c98 0x9a4a 0x99a6 0xf7bc 0x7376 0x69aa 0xdaa)) |}]
;;

(* The packet's first edge, a rise 26.7 us in, and its end: the trailing edge, here from
   the EOP's low last half up to a UI high, then low. *)
let%expect_test "the packet's start and end" =
  let message = List.hd_exn Usb_power_delivery.sent in
  let levels = run (Message.words message) ~cycles:(Message.cycles message + 400) in
  let first = List.take levels 4
  and last = List.drop levels (List.length levels - 4) in
  print_s [%message (first : (bool * int) list) (last : (bool * int) list)];
  [%expect
    {|
    ((first ((false 1367) (true 160) (false 80) (true 80)))
     (last ((true 80) (false 80) (true 160) (false 733))))
    |}]
;;
