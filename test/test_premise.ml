open! Core
open Protocol_emulator
open Firmware
open Protocol_models

(* A sender whose bit lasts [num / den] of the receiver's: four percent fast, exact, four
   percent slow. *)
let rates = [ "4% fast", 24, 25; "exact", 1, 1; "4% slow", 26, 25 ]

(* A level a cycle from a level a bit, each bit starting on the first cycle at or after
   the time it is due, so the edges of a sender that is off drift across the cycles. *)
let clocked bits ~period ~num ~den =
  let start k = ((k * period * num) + den - 1) / den in
  List.concat_mapi bits ~f:(fun k level ->
    List.init (start (k + 1) - start k) ~f:(fun _ -> level))
;;

module Run = struct
  type t =
    { count : Premise.Count.t
    ; words : int list
    ; irqs : int
    ; missed : bool
    }
end

(* The model a cycle at a time while [next] gives it levels, with the monitor beside it
   and a host that reads every word and clears every interrupt. [react] sees the model
   after every step. *)
let watch_while ?(preload = []) ?(react = ignore) (firmware : Certified.t) ~next =
  let premise = Premise.create () in
  let t =
    List.fold
      preload
      ~init:
        (Machine.create ~config:firmware.config ~program:(assemble firmware.source)
         |> ok_exn)
      ~f:(fun t word -> Machine.write_tx t word |> ok_exn)
  in
  let rec loop t ~words ~irqs =
    match next () with
    | None -> t, words, irqs
    | Some inputs ->
      let after = Machine.step t ~inputs in
      Premise.record premise ~before:t ~after;
      react after;
      let irqs = irqs + Bool.to_int after.irq in
      let after = Machine.clear_irq after in
      (match Machine.read_rx after with
       | Some (word, after) -> loop after ~words:(word :: words) ~irqs
       | None -> loop after ~words ~irqs)
  in
  let t, words, irqs = loop t ~words:[] ~irqs:0 in
  { Run.count = Premise.count premise
  ; words = List.rev words
  ; irqs
  ; missed = t.fault.missed_deadline
  }
;;

(* the same under [levels], a cycle each *)
let watch ?preload ?react firmware levels =
  let levels = ref levels in
  watch_while ?preload ?react firmware ~next:(fun () ->
    match !levels with
    | [] -> None
    | level :: rest ->
      levels := rest;
      Some level)
;;

let print_row name ~sender ({ count; missed; _ } : Run.t) ~received =
  printf
    "%-18s %-8s %5d  %8d  %10d  %s%s\n"
    name
    sender
    count.arms
    count.at_captured_level
    count.left_captured_level
    received
    (if missed then ", MISSED A DEADLINE" else "")
;;

let intact ~expected (run : Run.t) =
  if [%equal: int list] run.words expected
  then "all intact"
  else sprintf "%d words, not as sent" (List.length run.words)
;;

let every_byte = List.init 256 ~f:Fn.id

(* Every byte, frame after frame with no idle between them. [broken] frames lose their
   stop bit and a bit of idle follows, so the receiver takes the next start edge again. *)
let uart ?(broken = fun _ -> false) ~period ?(name = "uart_rx") firmware =
  let bits =
    List.concat_map every_byte ~f:(fun byte ->
      let frame = (0 :: List.init 8 ~f:(fun i -> (byte lsr i) land 1)) @ [ 1 ] in
      if broken byte then List.drop_last_exn frame @ [ 0; 1 ] else frame)
  in
  List.iter rates ~f:(fun (sender, num, den) ->
    let levels =
      List.init 20 ~f:(fun _ -> 1) @ clocked (bits @ [ 1; 1 ]) ~period ~num ~den
    in
    let run = watch firmware levels in
    let received = intact ~expected:every_byte run in
    print_row
      name
      ~sender
      run
      ~received:
        (if run.irqs = 0
         then received
         else sprintf "%s, %d framing errors" received run.irqs))
;;

let usb_level ~dp ~dm (line : Usb_ls.Line.t) =
  match line with
  | J -> 1 lsl dm
  | K -> 1 lsl dp
  | Se0 -> 0
;;

(* a data packet: PID, payload, CRC-16 low byte first *)
let data ~pid payload =
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes payload) in
  (pid :: payload) @ [ crc land 0xff; crc lsr 8 ]
;;

let token ~pid ~address =
  let bits = List.init 11 ~f:(fun i -> if i < 7 then (address lsr i) land 1 else 0) in
  [ pid; address; Usb_ls.crc5 bits lsl 3 ]
;;

let chunks = List.chunks_of every_byte ~length:8

(* DATA0 packets carrying every byte, each after the one before by the two bit times of
   idle a host has to leave. *)
let usb_rx_packets ~bit_period firmware =
  let packets = List.map chunks ~f:(data ~pid:0xc3) in
  let lines =
    List.init 8 ~f:(fun _ -> Usb_ls.Line.J)
    @ List.concat_map packets ~f:(fun packet -> Usb_ls.encode packet @ [ J ])
    @ List.init 8 ~f:(fun _ -> Usb_ls.Line.J)
  in
  let expected =
    List.concat_map packets ~f:(fun packet ->
      List.map (0x80 :: packet) ~f:(fun byte -> byte lsl 8) @ [ Usb_ls.residual packet ])
  in
  List.iter rates ~f:(fun (sender, num, den) ->
    let levels =
      clocked
        (List.map lines ~f:(usb_level ~dp:usb_rx_dp_pin ~dm:usb_rx_dm_pin))
        ~period:bit_period
        ~num
        ~den
    in
    let run = watch ~preload:[ bit_period ] firmware levels in
    print_row "usb_rx" ~sender run ~received:(intact ~expected run))
;;

(* For every eight bytes: a SETUP and its DATA0 for the device, which acknowledges; an IN
   for it, which it answers with NAK; an IN, an OUT and its data for another address; an
   ACK from the host. Two bit times of idle after each packet, and room for the answer
   after the two that get one. *)
let usb_device_transactions ~bit_period firmware =
  let dp = usb_device_dp_pin in
  let dm = usb_device_dm_pin in
  let packets =
    List.concat_map chunks ~f:(fun chunk ->
      [ token ~pid:0x2d ~address:0, 1
      ; data ~pid:0xc3 chunk, 30
      ; token ~pid:0x69 ~address:0, 30
      ; token ~pid:0x69 ~address:5, 1
      ; token ~pid:0xe1 ~address:5, 1
      ; data ~pid:0x4b chunk, 1
      ; [ 0xd2 ], 1
      ])
  in
  let lines =
    List.init 8 ~f:(fun _ -> Usb_ls.Line.J)
    @ List.concat_map packets ~f:(fun (packet, idle) ->
      Usb_ls.encode packet @ List.init idle ~f:(fun _ -> Usb_ls.Line.J))
    @ List.init 40 ~f:(fun _ -> Usb_ls.Line.J)
  in
  List.iter rates ~f:(fun (sender, num, den) ->
    let levels =
      clocked (List.map lines ~f:(usb_level ~dp ~dm)) ~period:bit_period ~num ~den
    in
    (* what the device sends, the bus idle where it does not drive *)
    let sniffer = ref (Usb_ls.Sniffer.create ~bit_period) in
    let react (m : Machine.t) =
      let pin n ~idle =
        if (m.pin_dir lsr n) land 1 = 1 then (m.pin_out lsr n) land 1 else idle
      in
      sniffer := Usb_ls.Sniffer.step !sniffer ~dp:(pin dp ~idle:0) ~dm:(pin dm ~idle:1)
    in
    let run = watch ~preload:[ bit_period ] ~react firmware levels in
    let answers pid =
      List.count (Usb_ls.Sniffer.packets !sniffer) ~f:([%equal: int list] [ pid ])
    in
    print_row
      "usb_device"
      ~sender
      run
      ~received:(sprintf "%d ACK and %d NAK of 32 each" (answers 0xd2) (answers 0x5a)))
;;

(* The tightest arm the device makes: after its own handshake, with the host's next packet
   at once, the two bit times after the device's EOP that a host has to leave at the
   least. For every eight bytes, a SETUP and its DATA0, which the device acknowledges; an
   IN at once, which it answers with NAK; at once the next SETUP. *)
let usb_device_at_once ~bit_period firmware =
  let dp = usb_device_dp_pin in
  let dm = usb_device_dm_pin in
  let j = usb_level ~dp ~dm J in
  let host lines =
    clocked (List.map lines ~f:(usb_level ~dp ~dm)) ~period:bit_period ~num:1 ~den:1
  in
  (* the lines of each packet and whether the device answers it, then the idle bus *)
  let packets =
    ref
      (List.concat_map chunks ~f:(fun chunk ->
         [ Usb_ls.encode (token ~pid:0x2d ~address:0) @ [ J ], false
         ; Usb_ls.encode (data ~pid:0xc3 chunk), true
         ; Usb_ls.encode (token ~pid:0x69 ~address:0), true
         ])
       @ [ List.init 40 ~f:(fun _ -> Usb_ls.Line.J), false ])
  in
  let pending = ref (host (List.init 8 ~f:(fun _ -> Usb_ls.Line.J))) in
  (* the cycles left for an answer to begin; a host gives up after eighteen bit times *)
  let awaiting = ref None in
  let rec next () =
    match !pending, !awaiting, !packets with
    | level :: rest, _, _ ->
      pending := rest;
      Some level
    | [], Some _, _ -> Some j
    | [], None, (lines, answers) :: rest ->
      packets := rest;
      pending := host lines;
      if answers then awaiting := Some (18 * bit_period);
      next ()
    | [], None, [] -> None
  in
  let sniffer = ref (Usb_ls.Sniffer.create ~bit_period) in
  let se0 = ref false in
  let react (m : Machine.t) =
    let driven n = (m.pin_dir lsr n) land 1 = 1 in
    let pin n ~idle = if driven n then (m.pin_out lsr n) land 1 else idle in
    let dp_level = pin dp ~idle:0 in
    let dm_level = pin dm ~idle:1 in
    sniffer := Usb_ls.Sniffer.step !sniffer ~dp:dp_level ~dm:dm_level;
    let ends = !se0 && not (dp_level = 0 && dm_level = 0) in
    se0 := dp_level = 0 && dm_level = 0;
    match !awaiting with
    | Some _ when ends ->
      (* the pins show what the device drives from the next cycle, its J with them *)
      awaiting := None;
      pending := List.init (2 * bit_period) ~f:(fun _ -> j)
    | Some _ when driven dp -> awaiting := Some (18 * bit_period)
    | Some left when List.is_empty !pending ->
      awaiting := Option.some_if (left > 0) (left - 1)
    | Some _ | None -> ()
  in
  let run = watch_while ~preload:[ bit_period ] ~react firmware ~next in
  let answers pid =
    List.count (Usb_ls.Sniffer.packets !sniffer) ~f:([%equal: int list] [ pid ])
  in
  print_row
    "usb_device at once"
    ~sender:"exact"
    run
    ~received:(sprintf "%d ACK and %d NAK of 32 each" (answers 0xd2) (answers 0x5a))
;;

(* Every receiver whose certificate assumes the single-edge premise, the program it is
   certified as, under a sender that keeps to its protocol but for its rate: at every
   [capture_arm], is the capture pin already at the captured level, and does it leave that
   level again before the wait for it releases? Either one is a frame the certificate does
   not cover.

   The UART runs again at the 25 cycles a bit the tolerance test uses, at 17, where the
   stop bit's check moves a cycle to keep to 4% either way, and with every eighth frame
   missing its stop bit, which takes the framing error's way to the arm. USB allows a
   sender 1.5% off, and these two take the timing of a whole packet from its first edge,
   so a sender 4% off garbles the packet; what the rows are for is the arms. *)
let%expect_test "the receivers keep the premise their certificates rest on" =
  printf
    "%-18s %-8s %5s  %8s  %10s  %s\n"
    "receiver"
    "sender"
    "arms"
    "at level"
    "left level"
    "received";
  List.iter Certified.all ~f:(fun firmware ->
    if firmware.single_capture_edge
    then (
      match firmware.name with
      | "uart_rx" ->
        uart ~period:16 firmware;
        uart ~period:25 ~name:"uart_rx 25" { firmware with source = uart_rx ~period:25 };
        uart ~period:17 ~name:"uart_rx 17" { firmware with source = uart_rx ~period:17 };
        uart ~broken:(fun byte -> byte % 8 = 7) ~period:16 ~name:"uart_rx stop" firmware
      | "usb_rx" -> usb_rx_packets ~bit_period:(Option.value_exn firmware.period) firmware
      | "usb_device" ->
        let bit_period = Option.value_exn firmware.period in
        usb_device_transactions ~bit_period firmware;
        usb_device_at_once ~bit_period firmware
      | name -> printf "%-18s no sender to drive it with\n" name));
  [%expect
    {|
    receiver           sender    arms  at level  left level  received
    uart_rx            4% fast    257         0           0  all intact
    uart_rx            exact      257         0           0  all intact
    uart_rx            4% slow    257         0           0  all intact
    uart_rx 25         4% fast    257         0           0  all intact
    uart_rx 25         exact      257         0           0  all intact
    uart_rx 25         4% slow    257         0           0  all intact
    uart_rx 17         4% fast    257         0           0  all intact
    uart_rx 17         exact      257         0           0  all intact
    uart_rx 17         4% slow    257         0           0  all intact
    uart_rx stop       4% fast    257         0           0  all intact, 32 framing errors
    uart_rx stop       exact      257         0           0  all intact, 32 framing errors
    uart_rx stop       4% slow    257         0           0  all intact, 32 framing errors
    usb_rx             4% fast     33         0           0  384 words, not as sent
    usb_rx             exact       33         0           0  all intact
    usb_rx             4% slow     33         0           0  416 words, not as sent
    usb_device         4% fast    225         0           0  0 ACK and 0 NAK of 32 each
    usb_device         exact      225         0           0  32 ACK and 32 NAK of 32 each
    usb_device         4% slow    225         0           0  0 ACK and 0 NAK of 32 each
    usb_device at once exact       97         0           0  32 ACK and 32 NAK of 32 each
    |}]
;;

(* A halt is not a release. The certified UART, armed and waiting for the start edge, is
   stopped by the host, and the line falls and rises again: a second edge before the wait
   has released. *)
let%expect_test "a halted wait for the edge has not released" =
  let firmware = Certified.find_exn "uart_rx" in
  let program = assemble firmware.source in
  let levels = List.init 20 ~f:(fun _ -> 1) @ [ 0; 0; 1; 1 ] in
  let run ?stop config =
    let premise = Premise.create () in
    let (_ : Machine.t) =
      List.foldi
        levels
        ~init:(Machine.create ~config ~program |> ok_exn)
        ~f:(fun n t inputs ->
          let after = Machine.step t ~inputs in
          let after =
            if [%equal: int option] (Some n) stop then Machine.stop after else after
          in
          Premise.record premise ~before:t ~after;
          after)
    in
    Premise.count premise
  in
  print_s [%message "" ~stopped:(run ~stop:10 firmware.config : Premise.Count.t)];
  [%expect
    {| (stopped ((arms 1) (at_captured_level 0) (left_captured_level 1))) |}]
;;
