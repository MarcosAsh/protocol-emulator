open! Core
open Protocol_emulator

(* The OCaml half of each learn demo's witness in test/board/learn_*/,
   demo/learn_witness.py the sigrok half: what the chip recorded is learned again here and
   must give the firmware the board ran, and the analyser's and Pico B's edges of the
   chip's speech must read back as the message sent. Each has teeth: the speech with two
   edges taken out must read otherwise, and the recording a tenth slower must give other
   firmware. *)

let read dir name = In_channel.read_all (dir ^/ name)
let recording dir name = Recording.of_string (read dir name) |> ok_exn

let bits_string bits =
  Array.to_list bits
  |> List.map ~f:(fun b -> if b then '1' else '0')
  |> String.of_char_list
;;

let pins (t : Learn.t) =
  match t.coding with
  | Clocked _ -> Learn_firmware.Pins.Clocked { clock = 10; data = 9; deselect = true }
  | _ -> Line 5
;;

(* The frames send.json asked for, in order. *)
let sent dir =
  Re.all (Re.compile (Re.Perl.re {|"bits": "([01]*)"|})) (read dir "send.json")
  |> List.map ~f:(fun g -> Re.Group.get g 1)
;;

let read_back t edges =
  match Learn.decode t edges with
  | Error e -> Error.to_string_hum e |> List.return
  | Ok frames -> List.map frames ~f:(fun f -> bits_string f.bits)
;;

(* Each chip edge less the analyser's same edge, after the offset and the two crystals'
   ratio are fitted, in microseconds. *)
let referee (chip : Recording.t) (analyser : Recording.t) =
  List.map chip.lines ~f:(fun (line : Recording.Line.t) ->
    match Recording.find analyser line.name with
    | None -> sprintf "%s: the analyser has no such line" line.name
    | Some seen when Array.length seen.edges <> Array.length line.edges ->
      sprintf
        "%s: the chip stamped %d edges, the analyser saw %d"
        line.name
        (Array.length line.edges)
        (Array.length seen.edges)
    | Some seen ->
      let c = Array.map line.edges ~f:(fun e -> Float.of_int e /. chip.rate_hz) in
      let a = Array.map seen.edges ~f:(fun e -> Float.of_int e /. analyser.rate_hz) in
      let n = Float.of_int (Array.length c) in
      let mean x = Array.sum (module Float) x ~f:Fn.id /. n in
      let mc = mean c
      and ma = mean a in
      let sxy =
        Array.sum
          (module Float)
          (Array.map2_exn c a ~f:(fun x y -> (x -. mc) *. (y -. ma)))
          ~f:Fn.id
      in
      let sxx = Array.sum (module Float) c ~f:(fun x -> (x -. mc) *. (x -. mc)) in
      let ratio = sxy /. sxx in
      let worst =
        Array.map2_exn c a ~f:(fun x y -> Float.abs (ma +. (ratio *. (x -. mc)) -. y))
        |> Array.fold ~init:0. ~f:Float.max
      in
      sprintf
        "%s: %d edges, each where the analyser saw it within %.2f us, crystals %+.0f ppm \
         apart"
        line.name
        (Array.length c)
        (worst *. 1e6)
        ((ratio -. 1.) *. 1e6))
;;

(* The learned line with the two edges from the i-th taken out, at i of n: a mark or space
   gone, two bits run into one. *)
let without_two (t : Learn.t) (r : Recording.t) ~at =
  { r with
    lines =
      List.map r.lines ~f:(fun line ->
        if String.equal line.name t.line || List.length r.lines = 1
        then (
          let i = at (Array.length line.edges) in
          { line with
            edges = Array.filteri line.edges ~f:(fun j _ -> j <> i && j <> i + 1)
          })
        else line)
  }
;;

(* The recording a tenth slower: every time learned from it, so the firmware too, must
   change. *)
let slowed (r : Recording.t) =
  let later e = e + (e / 10) in
  { r with
    length = later r.length
  ; lines =
      List.map r.lines ~f:(fun line ->
        { line with edges = Array.map line.edges ~f:later })
  }
;;

let check name =
  let dir = "board" ^/ name in
  let chip = recording dir "chip.edges" in
  let t = Learn.learn chip |> ok_exn in
  let firmware = Learn_firmware.generate ~clock_hz:48e6 ~pins:(pins t) t |> ok_exn in
  let wanted = sent dir in
  let spoken = recording dir "spoken.edges" in
  let listened =
    if Stdlib.Sys.file_exists (dir ^/ "listen.edges")
    then Some (read_back t (recording dir "listen.edges"))
    else None
  in
  let toothed_speech = read_back t (without_two t spoken ~at:(fun n -> n / 4)) in
  let toothed_learning =
    match Learn.learn (slowed chip) with
    | Error e -> "refused: " ^ Error.to_string_hum e
    | Ok t' ->
      (match Learn_firmware.generate ~clock_hz:48e6 ~pins:(pins t') t' with
       | Ok f when String.equal f.source firmware.source -> "MISSED: the same firmware"
       | Ok _ -> "refused: other firmware"
       | Error e -> "refused: " ^ Error.to_string_hum e)
  in
  print_s
    [%message
      name
        ~learned:
          (List.hd_exn (List.drop (String.split_lines (Learn.to_string t)) 1) : string)
        ~firmware_is_the_one_the_board_ran:
          (String.equal firmware.source (read dir "firmware.asm") : bool)
        ~verdict:(Analyser.Verdict.to_string (Timed_program.verdict firmware.timed))
        ~sent:(wanted : string list)
        ~analyser_reads:(read_back t spoken : string list)
        ~pico_b_reads:(listened : string list option)
        ~referee:(referee chip (recording dir "analyser_recorded.edges") : string list)
        ~speech_with_two_edges_taken_out:
          (if [%equal: string list] toothed_speech wanted
           then "MISSED: read as sent"
           else "refused: read otherwise"
           : string)
        ~recording_a_tenth_slower:(toothed_learning : string)]
;;

let%expect_test "every learn demo the board ran" =
  Stdlib.Sys.readdir "board"
  |> Array.to_list
  |> List.filter ~f:(String.is_prefix ~prefix:"learn_")
  |> List.sort ~compare:String.compare
  |> List.iter ~f:check;
  [%expect
    {|
    (learn_clocked
     (learned
      "clocked, clock IO2 at 4990.5 Hz idle 1, data IO3 read on the rising edge")
     (firmware_is_the_one_the_board_ran true)
     (verdict "31 words, 6 deadline waits, worst slack 4802")
     (sent (10100101000000010000000001101011 10100101000000010000000001101011))
     (analyser_reads
      (10100101000000010000000001101011 10100101000000010000000001101011))
     (pico_b_reads ())
     (referee
      ("IO2: 640 edges, each where the analyser saw it within 0.14 us, crystals +47 ppm apart"
       "IO3: 168 edges, each where the analyser saw it within 0.13 us, crystals +48 ppm apart"))
     (speech_with_two_edges_taken_out "refused: read otherwise")
     (recording_a_tenth_slower "refused: other firmware"))
    (learn_modbus (learned "uart, 7390.5 baud (bit 135.31 us), 8N1")
     (firmware_is_the_one_the_board_ran true)
     (verdict "32 words, 6 deadline waits, worst slack 6488")
     (sent
      (1000000011000000110000001000000000000000010000001010100111110001
       1000000011000000110000001000000000000000010000001010100111110001))
     (analyser_reads
      (1000000011000000110000001000000000000000010000001010100111110001
       1000000011000000110000001000000000000000010000001010100111110001))
     (pico_b_reads
      ((1000000011000000110000001000000000000000010000001010100111110001)))
     (referee
      ("IO3: 714 edges, each where the analyser saw it within 0.14 us, crystals +47 ppm apart"))
     (speech_with_two_edges_taken_out "refused: read otherwise")
     (recording_a_tenth_slower "refused: other firmware"))
    (learn_nec
     (learned "pulse, unit 557.0 us, 0 = mark 1 space 1, 1 = mark 1 space 3")
     (firmware_is_the_one_the_board_ran true)
     (verdict "71 words, 24 deadline waits, worst slack 26726")
     (sent (00000000111111111000001001111101 00000000111111111000001001111101))
     (analyser_reads
      (00000000111111111000001001111101 00000000111111111000001001111101))
     (pico_b_reads
      ((00000000111111111000001001111101 00000000111111111000001001111101)))
     (referee
      ("IO3: 724 edges, each where the analyser saw it within 0.14 us, crystals +47 ppm apart"))
     (speech_with_two_edges_taken_out "refused: read otherwise")
     (recording_a_tenth_slower "refused: other firmware"))
    (learn_pt2262
     (learned "pulse, unit 315.2 us, 0 = mark 1 space 3, 1 = mark 3 space 1")
     (firmware_is_the_one_the_board_ran true)
     (verdict "36 words, 11 deadline waits, worst slack 15121")
     (sent (000100010001000101000100 000100010001000101000100))
     (analyser_reads (000100010001000101000100 000100010001000101000100))
     (pico_b_reads ((000100010001000101000100 000100010001000101000100)))
     (referee
      ("IO3: 1601 edges, each where the analyser saw it within 0.14 us, crystals +47 ppm apart"))
     (speech_with_two_edges_taken_out "refused: read otherwise")
     (recording_a_tenth_slower "refused: other firmware"))
    (learn_rc5
     (learned
      "manchester, half bit 876.6 us, a one idle then active, the first half hidden in the idle")
     (firmware_is_the_one_the_board_ran true)
     (verdict "30 words, 6 deadline waits, worst slack 42064")
     (sent (11100101000000 11100101000000))
     (analyser_reads (11100101000000 11100101000000))
     (pico_b_reads ((11100101000000 11100101000000)))
     (referee
      ("IO3: 497 edges, each where the analyser saw it within 0.14 us, crystals +47 ppm apart"))
     (speech_with_two_edges_taken_out "refused: read otherwise")
     (recording_a_tenth_slower "refused: other firmware"))
    (learn_rc6
     (learned
      "manchester, half bit 446.2 us, a one active then idle, bit 4 twice as wide")
     (firmware_is_the_one_the_board_ran true)
     (verdict "79 words, 23 deadline waits, worst slack 21406")
     (sent (100010000000000001010 100010000000000001010))
     (analyser_reads (100010000000000001010 100010000000000001010))
     (pico_b_reads ((100010000000000001010 100010000000000001010)))
     (referee
      ("IO3: 936 edges, each where the analyser saw it within 0.14 us, crystals +47 ppm apart"))
     (speech_with_two_edges_taken_out "refused: read otherwise")
     (recording_a_tenth_slower "refused: other firmware"))
    |}]
;;
