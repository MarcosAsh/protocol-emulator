open! Core
open! Hardcaml

type t =
  { sck : Bits.t ref
  ; mosi : Bits.t ref
  ; cs_n : Bits.t ref
  ; miso : Bits.t ref
  ; half : int
  }

let create ~sck ~mosi ~cs_n ~miso ~half =
  cs_n := Bits.vdd;
  { sck; mosi; cs_n; miso; half }
;;

let byte t ~(watch @ local) out =
  let acc = ref 0 in
  for b = 7 downto 0 do
    t.mosi := Bits.of_bool ((out lsr b) land 1 = 1);
    watch t.half;
    let bit = Bits.to_unsigned_int !(t.miso) in
    t.sck := Bits.vdd;
    watch t.half;
    t.sck := Bits.gnd;
    acc := (!acc lsl 1) lor bit
  done;
  !acc
;;

let frame t ~(watch @ local) bytes =
  t.cs_n := Bits.gnd;
  watch t.half;
  let replies = List.map bytes ~f:(fun b -> byte t ~watch b) in
  watch t.half;
  t.cs_n := Bits.vdd;
  watch 3;
  replies
;;

let write t ~(watch @ local) reg words =
  let bytes =
    (0x80 lor reg) :: List.concat_map words ~f:(fun w -> [ w lsr 8; w land 0xff ])
  in
  ignore (frame t ~watch bytes : int list)
;;

let read t ~(watch @ local) reg ~count =
  frame t ~watch (reg :: List.init (2 * count) ~f:(fun _ -> 0))
  |> List.tl_exn
  |> List.chunks_of ~length:2
  |> List.map ~f:(fun bytes -> (List.nth_exn bytes 0 lsl 8) lor List.nth_exn bytes 1)
;;
