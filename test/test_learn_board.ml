open! Core
open Protocol_emulator

(* The OCaml half of each learn demo's witness in test/board/learn_*/,
   demo/learn_witness.py the sigrok half: what the chip recorded is learned again here and
   must give the firmware the board ran, and the analyser's and Pico B's edges of the
   chip's speech must read back as the message sent. Each has teeth: the speech with one
   edge moved a unit, and the recording with one edge of the field dropped, must be
   refused. *)

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

(* The line with the field's middle edge moved a unit later. *)
let moved (t : Learn.t) (r : Recording.t) =
  let unit = Float.iround_nearest_exn (t.unit_s *. r.rate_hz) in
  { r with
    lines =
      List.map r.lines ~f:(fun line ->
        if String.equal line.name t.line
        then (
          let edges = Array.copy line.edges in
          let i = Array.length edges / 4 in
          edges.(i) <- edges.(i) + unit;
          { line with edges })
        else line)
  }
;;

let dropped (t : Learn.t) (r : Recording.t) =
  { r with
    lines =
      List.map r.lines ~f:(fun line ->
        if String.equal line.name t.line
        then (
          let n = Array.length line.edges in
          { line with
            edges =
              Array.filteri line.edges ~f:(fun i _ -> i <> n / 2 && i <> (n / 2) + 1)
          })
        else line)
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
  let toothed_speech = read_back t (moved t spoken) in
  let toothed_learning =
    match Learn.learn (dropped t chip) with
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
        ~speech_with_an_edge_moved:
          (if [%equal: string list] toothed_speech wanted
           then "MISSED: read as sent"
           else "refused: read otherwise"
           : string)
        ~recording_with_an_edge_dropped:(toothed_learning : string)]
;;

let%expect_test "every learn demo the board ran" =
  Stdlib.Sys.readdir "board"
  |> Array.to_list
  |> List.filter ~f:(String.is_prefix ~prefix:"learn_")
  |> List.sort ~compare:String.compare
  |> List.iter ~f:check;
  [%expect {| |}]
;;
