open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Caliper.firmware));
  [%expect {| 57 words, 11 deadline waits, worst slack 9 |}]
;;

(* The far end: a receiver that samples the data on every fall of the clock, as the spec
   advises, and checks it is also what the data holds at the next rise, which is where
   sigrok's decoder reads it. It keeps the cycles of each run of the clock. *)
module Receiver = struct
  type t =
    { clock : bool
    ; data : bool
    ; run : int
    ; sampled : bool
    ; armed : bool (* the clock has been high once: before that the pins are in reset *)
    ; bits : bool list (* of the word so far, newest first *)
    ; words : int list
    ; highs : int list
    ; lows : int list
    ; moved : int (* cycles since the data last changed *)
    ; unstable : int
    ; short_hold : int
    }

  let create =
    { clock = false
    ; data = false
    ; run = 0
    ; sampled = false
    ; armed = false
    ; bits = []
    ; words = []
    ; highs = []
    ; lows = []
    ; moved = 0
    ; unstable = 0
    ; short_hold = 0
    }
  ;;

  let word bits =
    List.foldi (List.rev bits) ~init:0 ~f:(fun i acc bit ->
      acc lor (Bool.to_int bit lsl i))
  ;;

  let step t ~clock ~data =
    let moved = if Bool.equal data t.data then t.moved + 1 else 0 in
    let t = { t with moved; data } in
    if Bool.equal clock t.clock
    then { t with run = t.run + 1 }
    else if not clock
    then
      (* falls: the high that ended is a pause or a half period *)
      { t with
        clock
      ; run = 1
      ; highs = t.run :: t.highs
      ; sampled = data
      ; short_hold = (if moved < 2 then t.short_hold + 1 else t.short_hold)
      }
    else if not t.armed
    then { t with clock; run = 1; armed = true }
    else (
      let t =
        { t with
          clock
        ; run = 1
        ; lows = t.run :: t.lows
        ; unstable = (if Bool.equal data t.sampled then t.unstable else t.unstable + 1)
        }
      in
      let bits = t.sampled :: t.bits in
      if List.length bits = 24
      then { t with bits = []; words = word bits :: t.words }
      else { t with bits })
  ;;
end

let half_period = Caliper.half_period

let frame words =
  let machine =
    Machine.create
      ~config:(Timed_program.config Caliper.firmware)
      ~program:(Timed_program.words Caliper.firmware)
    |> ok_exn
  in
  let machine =
    List.fold (half_period :: words) ~init:machine ~f:(fun machine word ->
      Machine.write_tx machine word |> ok_exn)
  in
  let receiver = ref Receiver.create in
  let machine = ref machine in
  for _ = 1 to 45_000 do
    machine := Machine.step !machine ~inputs:0;
    let pin n = (!machine.pin_out lsr n) land 1 = 1 in
    receiver
    := Receiver.step !receiver ~clock:(pin Caliper.pin) ~data:(pin (Caliper.pin + 1))
  done;
  !receiver
;;

(* The pauses are the highs longer than a half period: the first is measured from the
   start, so it is only a floor; the last runs to the end of the run. *)
let%expect_test "a frame as the scale sends it" =
  let words = [ 0x1234; 0x56; 0x9abc; 0xde ] in
  let receiver = frame words in
  let pauses =
    List.filter (List.rev receiver.highs) ~f:(fun high -> high > half_period + 20)
  in
  let pause_us =
    List.map pauses ~f:(fun cycles -> Measured.ns ~clock_hz:Bench.clock_hz cycles / 1000)
  in
  print_s
    [%message
      (List.rev receiver.words : Int.Hex.t list)
        (pauses : int list)
        (pause_us : int list)
        ~lows:(List.dedup_and_sort receiver.lows ~compare:Int.compare : int list)
        ~unstable:(receiver.unstable : int)
        ~short_hold:(receiver.short_hold : int)];
  [%expect
    {|
    (("List.rev receiver.words" (0x561234 0xde9abc)) (pauses (2705 5400))
     (pause_us (56 112)) (lows (270)) (unstable 0) (short_hold 0))
    |}]
;;
