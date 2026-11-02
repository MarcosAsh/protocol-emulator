open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Wiegand.firmware));
  [%expect {| 32 words, 4 deadline waits, worst slack 5 |}]
;;

(* The far end: a panel that takes a bit at each fall of either line, a 0 on DATA0 and a 1
   on DATA1, and keeps the cycles each pulse lasted and those between pulse starts. Both
   lines low at once is a fault. It joins once both lines have been high. *)
module Panel = struct
  type t =
    { d0 : bool
    ; d1 : bool
    ; joined : bool
    ; since_start : int
    ; low : int
    ; bits : bool list (* newest first *)
    ; lows : int list
    ; intervals : int list
    ; both_low : int
    }

  let create =
    { d0 = false
    ; d1 = false
    ; joined = false
    ; since_start = 0
    ; low = 0
    ; bits = []
    ; lows = []
    ; intervals = []
    ; both_low = 0
    }
  ;;

  let step t ~d0 ~d1 =
    if not t.joined
    then { t with d0; d1; joined = d0 && d1 }
    else (
      let fell now before = before && not now in
      let rose now before = now && not before in
      let t =
        { t with
          since_start = t.since_start + 1
        ; low = (if d0 && d1 then t.low else t.low + 1)
        ; both_low = (if d0 || d1 then t.both_low else t.both_low + 1)
        }
      in
      let t =
        if fell d0 t.d0 || fell d1 t.d1
        then
          { t with
            bits = fell d1 t.d1 :: t.bits
          ; intervals =
              (if List.is_empty t.bits then t.intervals else t.since_start :: t.intervals)
          ; since_start = 0
          ; low = 1
          }
        else t
      in
      let t =
        if (rose d0 t.d0 || rose d1 t.d1) && d0 && d1
        then { t with lows = t.low :: t.lows }
        else t
      in
      { t with d0; d1 })
  ;;

  let word bits =
    List.fold bits ~init:0 ~f:(fun acc bit -> (acc lsl 1) lor Bool.to_int bit)
  ;;
end

let read words ~cycles =
  let machine =
    Machine.create
      ~config:(Timed_program.config Wiegand.firmware)
      ~program:(Timed_program.words Wiegand.firmware)
    |> ok_exn
  in
  let machine =
    List.fold words ~init:machine ~f:(fun machine word ->
      Machine.write_tx machine word |> ok_exn)
  in
  let panel = ref Panel.create in
  let machine = ref machine in
  for _ = 1 to cycles do
    machine := Machine.step !machine ~inputs:0;
    let pin n = (!machine.pin_out lsr n) land 1 = 1 in
    panel := Panel.step !panel ~d0:(pin Wiegand.pin) ~d1:(pin (Wiegand.pin + 1))
  done;
  !panel
;;

(* A 26-bit card read: facility 42, ID 4660, its parity bits checked as the format says *)
let%expect_test "a 26-bit card read on two wires" =
  let pulse = Wiegand.pulse
  and interval = Wiegand.interval in
  let panel =
    read
      ([ pulse; interval ] @ Wiegand.card ~facility:0x2a ~id:0x1234)
      ~cycles:(28 * interval * pulse)
  in
  let bits = List.rev panel.bits in
  let count = List.length bits in
  let data = Panel.word (List.sub bits ~pos:1 ~len:24) in
  let ones bits = List.count bits ~f:Fn.id in
  let even_parity = ones (List.sub bits ~pos:0 ~len:13) % 2 = 0 in
  let odd_parity = ones (List.sub bits ~pos:13 ~len:13) % 2 = 1 in
  let dedup = List.dedup_and_sort ~compare:Int.compare in
  print_s
    [%message
      (count : int)
        ~facility:(data lsr 16 : int)
        ~id:(data land 0xffff : int)
        (even_parity : bool)
        (odd_parity : bool)
        ~lows:(dedup panel.lows : int list)
        ~intervals:(dedup panel.intervals : int list)
        ~both_low:(panel.both_low : int)];
  [%expect {|
    ((count 26) (facility 42) (id 4660) (even_parity true) (odd_parity true)
     (lows (2400)) (intervals (24000)) (both_low 0))
    |}]
;;

(* the host picks the timing: here the floor's 16-cycle pulses, 3 apart, and a 34-bit read *)
let%expect_test "the shortest pulses, back to back" =
  let bits = 0x2_dead_beef in
  let words = [ 33; bits lsr 18; (bits lsr 2) land 0xffff; (bits land 3) lsl 14 ] in
  let panel = read ([ 16; 3 ] @ words) ~cycles:(40 * 3 * 16) in
  let read = Panel.word (List.rev panel.bits) in
  let dedup = List.dedup_and_sort ~compare:Int.compare in
  print_s
    [%message
      (List.length panel.bits : int)
        (read = bits : bool)
        ~lows:(dedup panel.lows : int list)
        ~intervals:(dedup panel.intervals : int list)
        ~both_low:(panel.both_low : int)];
  [%expect {|
    (("List.length panel.bits" 34) ("read = bits" true) (lows (16))
     (intervals (48)) (both_low 0))
    |}]
;;
