open! Core
open! Hardcaml
open Protocol_emulator

let%expect_test "the hardware step matches the model step" =
  let module C = Crc.Make (Bits) in
  let bits ~width v = Bits.of_unsigned_int ~width v in
  Quickcheck.test
    ~trials:2000
    (let open Quickcheck.Generator.Let_syntax in
     let%bind width = Int.gen_incl 1 16 in
     let%bind poly = Int.gen_incl 0 0xffff in
     let%bind crc = Int.gen_incl 0 ((1 lsl width) - 1) in
     let%bind reflect = Bool.quickcheck_generator in
     let%map bit = Int.gen_incl 0 1 in
     width, poly, crc, reflect, bit)
    ~f:(fun (width, poly, crc, reflect, bit) ->
      let expect = Crc.step ~width ~poly ~reflect crc ~bit in
      let actual =
        C.step
          ~width:(bits ~width:5 width)
          ~poly:(bits ~width:16 poly)
          ~reflect:(Bits.of_bool reflect)
          (bits ~width:16 crc)
          ~bit:(bits ~width:1 bit)
        |> Bits.to_unsigned_int
      in
      [%test_result: int]
        ~message:[%string "width %{width#Int} poly %{poly#Int} reflect %{reflect#Bool}"]
        actual
        ~expect);
  [%expect {| |}]
;;
