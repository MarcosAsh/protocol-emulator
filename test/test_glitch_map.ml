open! Core
open Protocol_emulator
open Glitch_map

let%expect_test "the kernel places the pulse at k" =
  let image = image 40 in
  print_endline (Timed_program.source image.timed);
  print_endline (Analyser.to_string ~side_set_count:0 (Timed_program.rows image.timed));
  print_s [%message (image.pulse : Interval.t)];
  [%expect
    {|
        set pins, 1              ; idle high
    idle:
        wait tx
        pull                     ; a frame for each word from the host
        mov t, now               ; the anchor the rows place each edge from
        set pins, 0              ; start bit
        nop [14]
        set pins, 1              ; the byte and the stop bit, all ones
        nop [22]
        set pins, 0              ; the pulse
        set pins, 1
        jmp idle
      0  set pins, 1                  phase ?..?  edge ?..?  jitter ?
      1  wait tx                      phase ?..?
      2  pull                         phase ?..?
      3  mov t, now                   phase ?..?
      4  set pins, 0                  phase 1  edge 2  gap 4..?
      5  nop [14]                     phase 2
      6  set pins, 1                  phase 17  edge 18  gap 16
      7  nop [22]                     phase 18
      8  set pins, 0                  phase 41  edge 42  gap 24
      9  set pins, 1                  phase 42  edge 43  gap 1
     10  jmp 1                        phase 43
    (image.pulse ((lo (40)) (hi (40))))
    |}]
;;

let at (i : Interval.t) =
  match i with
  | { lo = Some lo; hi = Some hi } when lo = hi -> Int.to_string lo
  | i -> Interval.to_string i
;;

let%expect_test "the receiver's samples, from the start bit" =
  List.iter2_exn (samples Rows) (samples Kernel) ~f:(fun rows kernel ->
    printf
      "pc %2d pass %d  rows %-4s kernel %s\n"
      rows.pc
      rows.pass
      (at rows.at)
      (at kernel.at));
  [%expect
    {|
    pc 10 pass 0  rows 24   kernel 24
    pc 10 pass 1  rows 40   kernel 40
    pc 10 pass 2  rows 56   kernel 56
    pc 10 pass 3  rows 72   kernel 72
    pc 10 pass 4  rows 88   kernel 88
    pc 10 pass 5  rows 104  kernel 104
    pc 10 pass 6  rows 120  kernel 120
    pc 10 pass 7  rows 136  kernel 136
    pc 16 pass 0  rows 150  kernel 150
    |}]
;;

let show (o : Outcome.t) =
  String.concat ~sep:" " (List.map o.words ~f:(sprintf "%02x"))
  ^ if o.framing_error then " framing error" else ""
;;

(* Every k on the model and on [Engines] beside it, runs of equal outcome on a line. *)
let%expect_test "the sweep" =
  let seen =
    List.map pulses ~f:(fun k ->
      let image = image k in
      if not (Interval.equal image.pulse (Interval.exactly k))
      then raise_s [%message "the rows place the pulse elsewhere" (k : int)];
      let model = model image in
      let rtl, mismatch = rtl image in
      Option.iter mismatch ~f:(fun mismatch ->
        print_s [%message "MISMATCH" (k : int) (mismatch : System_lockstep.Mismatch.t)]);
      k, predict k, model, rtl)
  in
  List.group seen ~break:(fun (_, p, m, r) (_, p', m', r') ->
    not ([%equal: Outcome.t * Outcome.t * Outcome.t] (p, m, r) (p', m', r')))
  |> List.iter ~f:(fun run ->
    let first, predicted, model, rtl = List.hd_exn run in
    let last, _, _, _ = List.last_exn run in
    let ks =
      if first = last then Int.to_string first else [%string "%{first#Int}-%{last#Int}"]
    in
    printf
      "k %-8s rows %-17s model %-17s rtl %s\n"
      ks
      (show predicted)
      (show model)
      (show rtl));
  let differ =
    List.count seen ~f:(fun (_, p, m, r) -> not (Outcome.equal p m && Outcome.equal p r))
  in
  print_s [%message (List.length seen : int) (differ : int)];
  (* where each data bit was seen against the kernel's window for it *)
  List.iteri
    (List.filter (samples Kernel) ~f:(fun s -> s.pc = 10))
    ~f:(fun bit kernel ->
      let cleared =
        List.filter_map seen ~f:(fun (k, _, _, (rtl : Outcome.t)) ->
          match rtl.words with
          | byte :: _ when byte land (1 lsl bit) = 0 -> Some k
          | _ -> None)
      in
      printf
        "bit %d  kernel %-8s seen at %s\n"
        bit
        (at kernel.at)
        (String.concat ~sep:" " (List.map cleared ~f:Int.to_string)));
  [%expect
    {|
    k 17-23    rows ff                model ff                rtl ff
    k 24       rows fe                model fe                rtl fe
    k 25-39    rows ff                model ff                rtl ff
    k 40       rows fd                model fd                rtl fd
    k 41-55    rows ff                model ff                rtl ff
    k 56       rows fb                model fb                rtl fb
    k 57-71    rows ff                model ff                rtl ff
    k 72       rows f7                model f7                rtl f7
    k 73-87    rows ff                model ff                rtl ff
    k 88       rows ef                model ef                rtl ef
    k 89-103   rows ff                model ff                rtl ff
    k 104      rows df                model df                rtl df
    k 105-119  rows ff                model ff                rtl ff
    k 120      rows bf                model bf                rtl bf
    k 121-135  rows ff                model ff                rtl ff
    k 136      rows 7f                model 7f                rtl 7f
    k 137-149  rows ff                model ff                rtl ff
    k 150      rows ff framing error  model ff framing error  rtl ff framing error
    k 151-152  rows ff                model ff                rtl ff
    k 153-191  rows ff ff             model ff ff             rtl ff ff
    (("List.length seen" 175) (differ 0))
    bit 0  kernel 24       seen at 24
    bit 1  kernel 40       seen at 40
    bit 2  kernel 56       seen at 56
    bit 3  kernel 72       seen at 72
    bit 4  kernel 88       seen at 88
    bit 5  kernel 104      seen at 104
    bit 6  kernel 120      seen at 120
    bit 7  kernel 136      seen at 136
    |}]
;;
