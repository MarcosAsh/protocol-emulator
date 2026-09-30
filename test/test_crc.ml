open! Core
open! Hardcaml
open Protocol_emulator

let gen_case =
  let open Quickcheck.Generator.Let_syntax in
  let%bind width = Int.gen_incl 1 Crc.max_width in
  let%bind poly = Int.gen_incl 0 0xffff_ffff in
  let%bind crc = Int.gen_incl 0 ((1 lsl width) - 1) in
  let%bind reflect = Bool.quickcheck_generator in
  let%map bit = Int.gen_incl 0 1 in
  width, poly, crc, reflect, bit
;;

let%expect_test "the hardware step and out bit match the model's" =
  let module C = Crc.Make (Bits) in
  let bits ~width v = Bits.of_unsigned_int ~width v in
  Quickcheck.test ~trials:4000 gen_case ~f:(fun (width, poly, crc, reflect, bit) ->
    let message =
      [%string "width %{width#Int} poly %{poly#Int} reflect %{reflect#Bool}"]
    in
    let width_bits = bits ~width:Crc.width_bits width in
    let reflect_bits = Bits.of_bool reflect in
    let crc_bits = bits ~width:Crc.max_width crc in
    [%test_result: int]
      ~message
      (C.step
         ~width:width_bits
         ~poly:(bits ~width:Crc.max_width poly)
         ~reflect:reflect_bits
         crc_bits
         ~bit:(bits ~width:1 bit)
       |> Bits.to_unsigned_int)
      ~expect:(Crc.step ~width ~poly ~reflect crc ~bit);
    [%test_result: int]
      ~message
      (C.out_bit ~width:width_bits ~reflect:reflect_bits crc_bits |> Bits.to_unsigned_int)
      ~expect:(Crc.out_bit ~width ~reflect crc));
  [%expect {| |}]
;;

let%expect_test "stepping with the out bit shifts the register out" =
  Quickcheck.test ~trials:2000 gen_case ~f:(fun (width, poly, crc, reflect, _) ->
    let sent, _ =
      Fn.apply_n_times
        ~n:width
        (fun (sent, crc) ->
          let bit = Crc.out_bit ~width ~reflect crc in
          (sent lsl 1) lor bit, Crc.step ~width ~poly ~reflect crc ~bit)
        (0, crc)
    in
    let reversed =
      List.init width ~f:(fun n -> ((crc lsr n) land 1) lsl (width - 1 - n))
      |> List.fold ~init:0 ~f:( lor )
    in
    [%test_result: int]
      ~message:[%string "width %{width#Int} reflect %{reflect#Bool}"]
      sent
      ~expect:(if reflect then reversed else crc));
  [%expect {| |}]
;;
