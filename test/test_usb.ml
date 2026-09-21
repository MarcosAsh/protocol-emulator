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
