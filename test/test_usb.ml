open! Core
open Protocol_emulator
open Firmware
open Protocol_models

let%expect_test "usb low speed packets survive the wire" =
  (* the SETUP token to address 0, endpoint 0, and a DATA0 packet with its crc *)
  let setup = [ 0x2d; 0x00; 0x10 ] in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes data) in
  let data0 = (0xc3 :: data) @ [ crc land 0xff; crc lsr 8 ] in
  let token_crc = Usb_ls.crc5 (List.take (Usb_ls.bits_of_bytes [ 0x00; 0x10 ]) 11) in
  let bit_period = 32 in
  let sniffer =
    List.fold
      [ setup; data0 ]
      ~init:(Usb_ls.Sniffer.create ~bit_period)
      ~f:(fun sniffer packet ->
        let idle = List.init 3 ~f:(fun _ -> Usb_ls.Line.J) in
        List.fold
          (Usb_ls.encode packet @ idle)
          ~init:sniffer
          ~f:(fun sniffer line ->
            let dp, dm =
              match line with
              | J -> 0, 1
              | K -> 1, 0
              | Se0 -> 0, 0
            in
            Fn.apply_n_times
              ~n:bit_period
              (fun s -> Usb_ls.Sniffer.step s ~dp ~dm)
              sniffer))
  in
  print_s
    [%message
      (token_crc : Int.Hex.t)
        (crc : Int.Hex.t)
        (Usb_ls.Sniffer.packets sniffer : int list list)];
  [%expect
    {|
    ((token_crc 0x2) (crc 0x94dd)
     ("Usb_ls.Sniffer.packets sniffer"
      ((45 0 16) (195 128 6 0 1 0 0 64 0 221 148))))
    |}]
;;

let%expect_test "usb tx builds the crc and stuffs the get descriptor packet" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let words =
    (bit_period :: 0x80 :: 0xc3 :: (List.length data - 1) :: data)
    @ [ 0x80; 0xc3; 0; 0xff ]
  in
  let t = Machine.create ~config:usb_config ~program:(assemble usb_tx) |> ok_exn in
  let feed (t : Machine.t) words =
    match words with
    | w :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
      Machine.write_tx t w |> ok_exn, rest
    | words -> t, words
  in
  let rec loop (t : Machine.t) words sniffer n =
    if n = 0
    then t, sniffer
    else (
      let t, words = feed t words in
      let t = Machine.step t ~inputs:0 in
      let pin p = (t.pin_out lsr p) land 1 in
      let sniffer =
        Usb_ls.Sniffer.step sniffer ~dp:(pin usb_dp_pin) ~dm:(pin usb_dm_pin)
      in
      loop t words sniffer (n - 1))
  in
  let t, sniffer = loop t words (Usb_ls.Sniffer.create ~bit_period) (bit_period * 200) in
  print_s
    [%message
      (Usb_ls.Sniffer.packets sniffer : int list list) (t.fault : Machine.Fault.t)];
  [%expect
    {|
    (("Usb_ls.Sniffer.packets sniffer"
      ((195 128 6 0 1 0 0 64 0 221 148) (195 255 0 255)))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "usb rx decodes, unstuffs and checks two packets" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes data) in
  let data0 = (0xc3 :: data) @ [ crc land 0xff; crc lsr 8 ] in
  let ones = [ 0xc3; 0xff; 0x00; 0xff ] in
  let line_levels packet =
    List.concat_map
      (Usb_ls.encode packet @ List.init 4 ~f:(fun _ -> Usb_ls.Line.J))
      ~f:(fun line ->
        let dp, dm =
          match line with
          | J -> 0, 1
          | K -> 1, 0
          | Se0 -> 0, 0
        in
        List.init bit_period ~f:(fun _ ->
          (dp lsl usb_rx_dp_pin) lor (dm lsl usb_rx_dm_pin)))
  in
  let levels =
    List.init 40 ~f:(fun _ -> 1 lsl usb_rx_dm_pin) @ line_levels data0 @ line_levels ones
  in
  let t =
    Machine.create
      ~config:usb_rx_config
      ~program:(assemble (usb_rx ~half_period:(bit_period / 2)))
    |> ok_exn
  in
  let t = Machine.write_tx t bit_period |> ok_exn in
  let t, words =
    List.fold levels ~init:(t, []) ~f:(fun (t, words) inputs ->
      let t = Machine.step t ~inputs in
      match Machine.read_rx t with
      | Some (w, t) -> t, w :: words
      | None -> t, words)
  in
  let words = List.rev words in
  let bytes = List.map words ~f:(fun w -> w lsr 8) in
  let residuals =
    List.filteri words ~f:(fun i _ ->
      i = List.length data0 + 1 || i = List.length words - 1)
  in
  let expected = List.map [ data0; ones ] ~f:Usb_ls.residual in
  print_s
    [%message
      (bytes : int list)
        (residuals : Int.Hex.t list)
        (expected : Int.Hex.t list)
        (t.fault : Machine.Fault.t)];
  [%expect
    {|
    ((bytes (128 195 128 6 0 1 0 0 64 0 221 148 140 128 195 255 0 255 234))
     (residuals (0x8ce4 0xea69)) (expected (0x8ce4 0xea69))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "usb tx in lockstep" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let sniffer = ref (Usb_ls.Sniffer.create ~bit_period) in
  let pending =
    ref ((0x80 :: 0xc3 :: (List.length data - 1) :: data) @ [ 0x80; 0xc3; 0; 0xff ])
  in
  let level = ref 0 in
  let host _ =
    match !pending with
    | w :: rest when !level < Machine.fifo_depth ->
      pending := rest;
      { Lockstep.Host.idle with tx = Some w; pop_rx = false }
    | _ -> Lockstep.Host.idle
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(bit_period * 200)
      ~config:usb_config
      ~program:(assemble usb_tx)
      ~preload:[ bit_period ]
      ~inputs:(fun _ -> 0)
      ~host
      ~react:(fun m ->
        level := List.length m.tx_fifo;
        let pin p = (m.pin_out lsr p) land 1 in
        sniffer := Usb_ls.Sniffer.step !sniffer ~dp:(pin usb_dp_pin) ~dm:(pin usb_dm_pin))
      ()
  in
  print_s [%message (Usb_ls.Sniffer.packets !sniffer : int list list)];
  [%expect
    {|
    ("lockstep held" (cycles 6400))
    ("Usb_ls.Sniffer.packets (!sniffer)"
     ((195 128 6 0 1 0 0 64 0 221 148) (195 255 0 255)))
    |}]
;;

let%expect_test "usb rx in lockstep" =
  let bit_period = 32 in
  let data = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ] in
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes data) in
  let packet = (0xc3 :: data) @ [ crc land 0xff; crc lsr 8 ] in
  let levels =
    List.init 40 ~f:(fun _ -> 1 lsl usb_rx_dm_pin)
    @ List.concat_map
        (Usb_ls.encode packet @ List.init 4 ~f:(fun _ -> Usb_ls.Line.J))
        ~f:(fun line ->
          let dp, dm =
            match line with
            | J -> 0, 1
            | K -> 1, 0
            | Se0 -> 0, 0
          in
          List.init bit_period ~f:(fun _ ->
            (dp lsl usb_rx_dp_pin) lor (dm lsl usb_rx_dm_pin)))
    |> Array.of_list
  in
  let words = ref [] in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(Array.length levels)
      ~config:usb_rx_config
      ~program:(assemble (usb_rx ~half_period:(bit_period / 2)))
      ~preload:[ bit_period ]
      ~inputs:(fun n -> levels.(n))
      ~host:(fun _ -> { Lockstep.Host.idle with tx = None; pop_rx = true })
      ~react:(fun m ->
        match m.rx_fifo with
        | w :: _ -> words := w :: !words
        | [] -> ())
      ()
  in
  let bytes = List.rev_map !words ~f:(fun w -> w lsr 8) in
  print_s [%message (bytes : int list)];
  [%expect
    {|
    ("lockstep held" (cycles 3336))
    (bytes (128 195 128 6 0 1 0 0 64 0 221 148 140))
    |}]
;;

(* D+ and D- as a wire: the device wins where it drives, the host's level otherwise *)
let usb_bus (t : Machine.t) ~host =
  let pin n = if (t.pin_dir lsr n) land 1 = 1 then (t.pin_out lsr n) land 1 else host n in
  pin usb_device_dp_pin, pin usb_device_dm_pin
;;

let run_usb_device ?(queue = []) ~address packets ~idle =
  let bit_period = 32 in
  let t =
    Machine.create
      ~config:usb_device_config
      ~program:(assemble (usb_device ~address ~half_period:(bit_period / 2)))
    |> ok_exn
  in
  let t =
    List.fold (bit_period :: queue) ~init:t ~f:(fun t word ->
      Machine.write_tx t word |> ok_exn)
  in
  let words = ref [] in
  let lines =
    List.concat_map packets ~f:(fun packet ->
      List.init 8 ~f:(fun _ -> Usb_ls.Line.J)
      @ Usb_ls.encode packet
      @ List.init idle ~f:(fun _ -> Usb_ls.Line.J))
  in
  let levels =
    List.concat_map lines ~f:(fun line ->
      let level =
        match line with
        | J -> 0, 1
        | K -> 1, 0
        | Se0 -> 0, 0
      in
      List.init bit_period ~f:(fun _ -> level))
  in
  (* the reply delay the specification bounds: from the end of the host's SE0 to the first
     K the device drives, two to six and a half bit times *)
  let host_se0_ends = ref 0 in
  let replied = ref true in
  let reply_delays = ref [] in
  let cycle = ref 0 in
  let t, sniffer =
    List.fold
      levels
      ~init:(t, Usb_ls.Sniffer.create ~bit_period)
      ~f:(fun (t, sniffer) (dp, dm) ->
        Int.incr cycle;
        if dp = 0 && dm = 0
        then (
          host_se0_ends := !cycle + 1;
          replied := false);
        let host n = if n = usb_device_dp_pin then dp else dm in
        let inputs = (dp lsl usb_device_dp_pin) lor (dm lsl usb_device_dm_pin) in
        let t = Machine.step t ~inputs in
        let t =
          match Machine.read_rx t with
          | Some (word, t) ->
            words := word :: !words;
            t
          | None -> t
        in
        let dp, dm = usb_bus t ~host in
        let drives = (t.pin_dir lsr usb_device_dp_pin) land 1 = 1 in
        if drives && dp = 1 && not !replied
        then (
          replied := true;
          reply_delays := (!cycle - !host_se0_ends) :: !reply_delays);
        t, Usb_ls.Sniffer.step sniffer ~dp ~dm)
  in
  let reply_after_bit_times =
    List.rev_map !reply_delays ~f:(fun cycles ->
      Float.of_int cycles /. Float.of_int bit_period)
  in
  (* the first bit received is the top bit of a word *)
  let reverse byte =
    List.init 8 ~f:(fun i -> ((byte lsr i) land 1) lsl (7 - i))
    |> List.sum (module Int) ~f:Fn.id
  in
  let tag, bytes =
    match List.rev !words with
    | [] -> None, []
    | tag :: words ->
      ( Some tag
      , List.concat_map words ~f:(fun w -> [ reverse (w lsr 8); reverse (w land 0xff) ]) )
  in
  print_s
    [%message
      (Usb_ls.Sniffer.packets sniffer : int list list)
        (reply_after_bit_times : float list)
        (tag : int option)
        (bytes : int list)
        (t.irq : bool)
        (t.fault : Machine.Fault.t)]
;;

let%expect_test "usb device answers an IN for its address with NAK" =
  run_usb_device ~address:0 [ [ 0x69; 0x00; 0x10 ] ] ~idle:40;
  [%expect
    {|
    (("Usb_ls.Sniffer.packets sniffer" ((105 0 16) (90)))
     (reply_after_bit_times (2.625)) (tag ()) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let usb_token ~pid ~address =
  let bits = List.init 11 ~f:(fun i -> if i < 7 then (address lsr i) land 1 else 0) in
  [ pid; address; Usb_ls.crc5 bits lsl 3 ]
;;

let%expect_test "usb device ignores other addresses, bad token crcs and SETUP tokens" =
  let in_pid = 0x69 in
  run_usb_device ~address:0 [ usb_token ~pid:in_pid ~address:5 ] ~idle:40;
  run_usb_device ~address:5 [ usb_token ~pid:in_pid ~address:5 ] ~idle:40;
  run_usb_device ~address:0 [ [ in_pid; 0x00; 0x18 ] ] ~idle:40;
  run_usb_device ~address:0 [ usb_token ~pid:0x2d ~address:0 ] ~idle:40;
  run_usb_device
    ~address:0
    [ usb_token ~pid:in_pid ~address:0; usb_token ~pid:in_pid ~address:0 ]
    ~idle:40;
  [%expect
    {|
    (("Usb_ls.Sniffer.packets sniffer" ((105 5 208))) (reply_after_bit_times ())
     (tag ()) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (("Usb_ls.Sniffer.packets sniffer" ((105 5 208) (90)))
     (reply_after_bit_times (2.625)) (tag ()) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (("Usb_ls.Sniffer.packets sniffer" ((105 0 24))) (reply_after_bit_times ())
     (tag ()) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (("Usb_ls.Sniffer.packets sniffer" ((45 0 16))) (reply_after_bit_times ())
     (tag ()) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (("Usb_ls.Sniffer.packets sniffer" ((105 0 16) (90) (105 0 16) (90)))
     (reply_after_bit_times (2.625 2.625)) (tag ()) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "usb device in lockstep" =
  let bit_period = 32 in
  let levels =
    List.concat_map
      [ usb_token ~pid:0x69 ~address:3; usb_token ~pid:0x69 ~address:0 ]
      ~f:(fun packet ->
        List.init 8 ~f:(fun _ -> Usb_ls.Line.J)
        @ Usb_ls.encode packet
        @ List.init 40 ~f:(fun _ -> Usb_ls.Line.J))
    |> List.concat_map ~f:(fun line ->
      let dp, dm =
        match (line : Usb_ls.Line.t) with
        | J -> 0, 1
        | K -> 1, 0
        | Se0 -> 0, 0
      in
      List.init bit_period ~f:(fun _ ->
        (dp lsl usb_device_dp_pin) lor (dm lsl usb_device_dm_pin)))
    |> Array.of_list
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(Array.length levels)
      ~config:usb_device_config
      ~program:(assemble (usb_device ~address:3 ~half_period:(bit_period / 2)))
      ~preload:[ bit_period ]
      ~inputs:(fun n -> levels.(n))
      ()
  in
  [%expect {| ("lockstep held" (cycles 5312)) |}]
;;

(* a data packet: PID, payload, CRC-16 low byte first *)
let usb_data ~pid payload =
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes payload) in
  (pid :: payload) @ [ crc land 0xff; crc lsr 8 ]
;;

let get_descriptor = [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ]

let%expect_test "usb device takes a SETUP and its data and acknowledges" =
  run_usb_device
    ~address:0
    [ usb_token ~pid:0x2d ~address:0; usb_data ~pid:0xc3 get_descriptor ]
    ~idle:40;
  [%expect
    {|
    (("Usb_ls.Sniffer.packets sniffer"
      ((45 0 16) (195 128 6 0 1 0 0 64 0 221 148) (210)))
     (reply_after_bit_times (3.625)) (tag (1))
     (bytes (128 6 0 1 0 0 64 0 221 148 0 0)) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "usb device stays silent on a bad data crc, a status packet is fine" =
  let corrupt =
    List.mapi (usb_data ~pid:0xc3 get_descriptor) ~f:(fun i b ->
      if i = 3 then b lxor 0x10 else b)
  in
  run_usb_device ~address:0 [ usb_token ~pid:0x2d ~address:0; corrupt ] ~idle:40;
  run_usb_device
    ~address:0
    [ usb_token ~pid:0xe1 ~address:0; usb_data ~pid:0x4b [] ]
    ~idle:40;
  run_usb_device
    ~address:0
    [ usb_token ~pid:0x2d ~address:9
    ; usb_data ~pid:0xc3 get_descriptor
    ; usb_token ~pid:0x69 ~address:0
    ]
    ~idle:40;
  [%expect
    {|
    (("Usb_ls.Sniffer.packets sniffer"
      ((45 0 16) (195 128 6 16 1 0 0 64 0 221 148)))
     (reply_after_bit_times ()) (tag (1))
     (bytes (128 6 16 1 0 0 64 0 221 148 0 0)) (t.irq true)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (("Usb_ls.Sniffer.packets sniffer" ((225 0 16) (75 0 0) (210)))
     (reply_after_bit_times (3.625)) (tag (2)) (bytes (0 0 0 0)) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (("Usb_ls.Sniffer.packets sniffer"
      ((45 9 152) (195 128 6 0 1 0 0 64 0 221 148) (105 0 16) (90)))
     (reply_after_bit_times (2.625)) (tag ()) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "usb device takes a SETUP in lockstep" =
  let bit_period = 32 in
  let levels =
    List.concat_map
      [ usb_token ~pid:0x2d ~address:0
      ; usb_data ~pid:0xc3 get_descriptor
      ; usb_token ~pid:0x69 ~address:0
      ]
      ~f:(fun packet ->
        List.init 8 ~f:(fun _ -> Usb_ls.Line.J)
        @ Usb_ls.encode packet
        @ List.init 40 ~f:(fun _ -> Usb_ls.Line.J))
    |> List.concat_map ~f:(fun line ->
      let dp, dm =
        match (line : Usb_ls.Line.t) with
        | J -> 0, 1
        | K -> 1, 0
        | Se0 -> 0, 0
      in
      List.init bit_period ~f:(fun _ ->
        (dp lsl usb_device_dp_pin) lor (dm lsl usb_device_dm_pin)))
    |> Array.of_list
  in
  let program = assemble (usb_device ~address:0 ~half_period:(bit_period / 2)) in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:(Array.length levels)
      ~config:usb_device_config
      ~program
      ~preload:[ bit_period ]
      ~inputs:(fun n -> levels.(n))
      ~host:(fun _ -> { Lockstep.Host.idle with pop_rx = true })
      ()
  in
  print_s [%message "program" ~words:(List.length program : int)];
  [%expect {|
    ("lockstep held" (cycles 10016))
    (program (words 467))
    |}]
;;

(* what the host queues for an IN: SYNC and PID, the number of data bits, then the data
   two bytes a word, the first byte low *)
let usb_reply ~pid payload =
  let rec words = function
    | [] -> []
    | [ a ] -> [ a ]
    | a :: b :: rest -> (a lor (b lsl 8)) :: words rest
  in
  (0x80 lor (pid lsl 8)) :: (8 * List.length payload) :: words payload
;;

let%expect_test "usb device answers an IN with the data the host queued" =
  let in_token = usb_token ~pid:0x69 ~address:0 in
  let descriptor = [ 18; 1; 0x10; 1; 0; 0; 0; 8 ] in
  List.iter
    [ descriptor; [ 0xff; 0xff; 0xff; 0x7f ]; [ 0x2a ]; [] ]
    ~f:(fun payload ->
      run_usb_device
        ~queue:(usb_reply ~pid:0x4b payload)
        ~address:0
        [ in_token; [ 0xd2 ] ]
        ~idle:140;
      let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes payload) in
      print_s [%message "expected" ~crc:([ crc land 0xff; crc lsr 8 ] : int list)]);
  [%expect
    {|
    (("Usb_ls.Sniffer.packets sniffer"
      ((105 0 16) (75 18 1 16 1 0 0 0 8 17 119) (210)))
     (reply_after_bit_times (2.625)) (tag (3)) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (expected (crc (17 119)))
    (("Usb_ls.Sniffer.packets sniffer"
      ((105 0 16) (75 255 255 255 127 255 239) (210)))
     (reply_after_bit_times (2.625)) (tag (3)) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (expected (crc (255 239)))
    (("Usb_ls.Sniffer.packets sniffer" ((105 0 16) (75 42 193 96) (210)))
     (reply_after_bit_times (2.625)) (tag (3)) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (expected (crc (193 96)))
    (("Usb_ls.Sniffer.packets sniffer" ((105 0 16) (75 0 0) (210)))
     (reply_after_bit_times (2.625)) (tag (3)) (bytes ()) (t.irq false)
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (expected (crc (0 0)))
    |}]
;;
