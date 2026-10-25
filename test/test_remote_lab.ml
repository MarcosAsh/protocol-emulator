open! Core
open Protocol_emulator

let diagram name = In_channel.read_all [%string "diagrams/%{name}.json"]

(* each diagram with the playground's first frame *)
let corpus =
  [ "uart_tx", "11000101\n00111010"
  ; "dshot", "1000001011000110"
  ; "spi_master", "10100101"
  ; "ws2812", "000100001111111100000000"
  ; "uart_rx", "11000101\n00111010"
  ]
;;

(* through the job file's text, as the worker reads it *)
let check ?(decode = Remote_lab.Decode.Off) ~frames diagram =
  Remote_lab.Job.to_string { diagram; frames; decode }
  |> Remote_lab.Job.of_string
  |> Or_error.bind ~f:Remote_lab.check
;;

let bench (b : Remote_lab.Bench.t) =
  match b with
  | Takes { probe; run_ms } -> [%string "takes it on %{probe.name}, %{run_ms#Int} ms"]
  | Declines why -> "declines it: " ^ why
;;

let summary = function
  | Error e -> [%message "malformed" ~_:(e : Error.t)]
  | Ok (Remote_lab.Refused { certificate; _ }) ->
    [%message "refused" ~_:(String.split_lines certificate : string list)]
  | Ok (Certified { host_words; cycles; faults; bench = b; _ }) ->
    [%message
      "certified"
        ~host_words:(List.length host_words : int)
        (cycles : int)
        (faults : Machine.Fault.t)
        ~bench:(bench b : string)]
;;

let%expect_test "the corpus: what the bench takes, and what gets the model alone" =
  List.iter corpus ~f:(fun (name, frames) ->
    print_s [%message name ~_:(summary (check ~frames (diagram name)) : Sexp.t)]);
  [%expect
    {|
    (uart_tx
     (certified (host_words 2) (cycles 2152)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0, 2 ms")))
    (dshot
     (certified (host_words 1) (cycles 7953)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0, 2 ms")))
    (spi_master
     (certified (host_words 1) (cycles 2610)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "declines it: it reads IN0, which no peer drives on the bench")))
    (ws2812
     (certified (host_words 3) (cycles 21000)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0, 2 ms")))
    (uart_rx
     (certified (host_words 0) (cycles 1857)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "declines it: it reads IN0, which no peer drives on the bench")))
    |}]
;;

let files = function
  | Ok t -> Remote_lab.files t
  | Error _ -> []
;;

let%expect_test "every job loads the one certified interpreter, so a job brings data \
                 alone"
  =
  let interpreter =
    let timed =
      Tables.check Tables.Wiring.default
      |> Result.map_error ~f:(fun r -> r.Timed_program.Refusal.error)
      |> ok_exn
    in
    Timed_program.words timed
  in
  let loaded =
    List.filter_map corpus ~f:(fun (name, frames) ->
      let%map.Option firmware =
        List.Assoc.find
          (files (check ~frames (diagram name)))
          "firmware.json"
          ~equal:String.equal
      in
      let field key =
        match Wavejson.Value.parse firmware |> ok_exn with
        | Object fields -> List.Assoc.find_exn fields key ~equal:String.equal
        | _ -> assert false
      in
      let words =
        match field "words" with
        | List l ->
          List.map l ~f:(function
            | Number f -> Float.to_int f
            | _ -> assert false)
        | _ -> assert false
      in
      name, words, field "config")
  in
  let names = List.map loaded ~f:(fun (name, _, _) -> name) in
  let same_words =
    List.for_all loaded ~f:(fun (_, w, _) -> [%equal: int list] w interpreter)
  in
  let same_config =
    match loaded with
    | [] -> false
    | (_, _, first) :: rest ->
      List.for_all rest ~f:(fun (_, _, c) -> Wavejson.Value.equal c first)
  in
  print_s [%message (names : string list) (same_words : bool) (same_config : bool)];
  [%expect {| ((names (uart_tx dshot ws2812)) (same_words true) (same_config true)) |}]
;;

let%expect_test "a refusal names the limit, and nothing goes to the bench" =
  let slow =
    String.substr_replace_first
      (diagram "ws2812")
      ~pattern:"[0, 26, 19, 28, 2496]"
      ~with_:"[0, 26, 21, 28, 2496]"
  in
  let checked = check ~frames:"000100001111111100000000" slow in
  print_s (summary checked);
  print_s [%message (List.map (files checked) ~f:fst : string list)];
  [%expect
    {|
    (refused
     ("refused: (\"at 48 MHz\"" " (\"outside the table class\""
      "  (\"the diagram's own limit does not hold\" (edge \"a<->c T1H 650ns..950ns\")"
      "   (cycles 47) (ns 979.16666666666663) (least_ns (650)) (most_ns (950)))))"))
    ("List.map (files checked) ~f:fst" (job.json certificate.txt check.json))
    |}]
;;

(* as JSON quotes it, bytes past ASCII left as they are *)
let json_string s =
  "\""
  ^ String.concat_map s ~f:(function
    | '"' -> "\\\""
    | '\\' -> "\\\\"
    | '\n' -> "\\n"
    | c -> String.of_char c)
  ^ "\""
;;

let%expect_test "malformed jobs" =
  let uart = diagram "uart_tx" in
  let job ?(lab = "1") ?(extra = "") ?(frames = "11000101") diagram =
    [%string
      {|{"lab": %{lab}, "diagram": %{json_string diagram}, "frames": "%{frames}"%{extra}}|}]
  in
  List.iter
    [ "not an object", "[1, 2]"
    ; "another version", job ~lab:"2" uart
    ; "firmware", job ~extra:{|, "firmware": [1, 2, 3]|} uart
    ; "no such decoder", job ~extra:{|, "decode": "spi"|} uart
    ; "a baud out of range", job ~extra:{|, "decode": "uart:12"|} uart
    ; "not ASCII", job "{signal: [{name: '\xc3\xa9', wave: '01'}]}"
    ; "too big", job (String.make 20_000 ' ')
    ; ( "too many frames"
      , job ~frames:(String.concat ~sep:"\\n" (List.init 17 ~f:(Fn.const "1"))) uart )
    ; "not bits", job ~frames:"0120" uart
    ; "a short frame", job ~frames:"1100" uart
    ; "not a diagram", job "{signal: "
    ]
    ~f:(fun (what, text) ->
      print_s
        [%message
          what
            ~_:
              (summary (Remote_lab.Job.of_string text |> Or_error.bind ~f:Remote_lab.check)
               : Sexp.t)]);
  [%expect
    {|
    ("not an object" (malformed "a job is an object"))
    ("another version" (malformed "a job says \"lab\": 1"))
    (firmware (malformed ("a job has no such key" firmware)))
    ("no such decoder"
     (malformed ("decode is none, ws281x or uart:BAUD" (decode spi))))
    ("a baud out of range" (malformed ("uart's baud is 300 to 4000000" 12)))
    ("not ASCII" (malformed "a job is printable ASCII"))
    ("too big" (malformed ("a job is at most" (max_bytes 16384) bytes)))
    ("too many frames" (malformed ("a job has at most" (max_frames 16) frames)))
    ("not bits" (malformed "a frame is 0s and 1s"))
    ("a short frame" (malformed ("a frame's bits" (bits 4) (a_frame 8))))
    ("not a diagram" (malformed ("not WaveJSON" "expected a value" (at 8))))
    |}]
;;

let%expect_test "the bench takes only what the tx fifo holds before the start" =
  let uart n =
    check
      ~frames:(String.concat ~sep:"\n" (List.init n ~f:(Fn.const "10100101")))
      (diagram "uart_tx")
  in
  let pixels n =
    check
      ~frames:(String.concat (List.init n ~f:(Fn.const "000100001111111100000000")))
      (diagram "ws2812")
  in
  (* a frame a word, and a pixel two after the first *)
  let frames = Machine.fifo_depth in
  let pixels_fit = (Machine.fifo_depth - 1) / 2 in
  List.iter
    [ [%string "uart_tx, %{frames#Int} frames"], uart frames
    ; [%string "uart_tx, %{frames + 1#Int} frames"], uart (frames + 1)
    ; [%string "ws2812, %{pixels_fit#Int} pixels"], pixels pixels_fit
    ; [%string "ws2812, %{pixels_fit + 1#Int} pixels"], pixels (pixels_fit + 1)
    ]
    ~f:(fun (what, checked) -> print_s [%message what ~_:(summary checked : Sexp.t)]);
  [%expect
    {|
    ("uart_tx, 15 frames"
     (certified (host_words 15) (cycles 9146)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0, 2 ms")))
    ("uart_tx, 16 frames"
     (certified (host_words 16) (cycles 9684)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench
       "declines it: 16 host words, past the 15 the tx fifo holds before the start")))
    ("ws2812, 7 pixels"
     (certified (host_words 15) (cycles 71400)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0, 3 ms")))
    ("ws2812, 8 pixels"
     (certified (host_words 17) (cycles 79800)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench
       "declines it: 17 host words, past the 15 the tx fifo holds before the start")))
    |}]
;;

(* 8N1 from the model's levels, 26 cycles a bit, each bit read at its middle *)
let uart_bytes (levels : int array) =
  let bit = 26 in
  let level c = if c < Array.length levels then levels.(c) land 1 else 1 in
  let rec go c acc =
    if c >= Array.length levels
    then List.rev acc
    else if level (c - 1) = 1 && level c = 0
    then (
      let byte =
        List.sum (module Int) (List.range 0 8) ~f:(fun i ->
          level (c + (bit * (i + 1)) + (bit / 2)) lsl i)
      in
      go (c + (bit * 10)) (byte :: acc))
    else go (c + 1) acc
  in
  go 1 []
;;

let%test_unit "the model's trace of any uart_tx job decodes to its bytes" =
  Quickcheck.test
    ~trials:50
    (let open Quickcheck.Generator.Let_syntax in
     let%bind n = Int.gen_incl 1 8 in
     List.gen_with_length n (Int.gen_incl 0 255))
    ~sexp_of:[%sexp_of: int list]
    ~f:(fun bytes ->
      let frames =
        List.map bytes ~f:(fun b ->
          String.init 8 ~f:(fun i -> if (b lsr i) land 1 = 1 then '1' else '0'))
        |> String.concat ~sep:"\n"
      in
      match check ~frames (diagram "uart_tx") with
      | Ok (Certified { levels; bench = Takes _; _ }) ->
        [%test_result: int list] (uart_bytes levels) ~expect:bytes
      | checked -> raise_s (summary checked))
;;

let%expect_test "decoders" =
  List.iter
    [ "none"; "ws281x"; "uart:115200"; "uart:5000000"; "uart:12a"; "i2c" ]
    ~f:(fun s ->
      print_s
        [%message
          s
            ~_:
              (Remote_lab.Decode.of_string s
               |> Or_error.map ~f:(Remote_lab.Decode.sigrok_args ~channel:"D4")
               : string list Or_error.t)]);
  [%expect
    {|
    (none (Ok ()))
    (ws281x (Ok (-P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset)))
    (uart:115200 (Ok (-P uart:rx=D4:baudrate=115200 -A uart=rx-data)))
    (uart:5000000 (Error ("uart's baud is 300 to 4000000" 5000000)))
    (uart:12a (Error ("uart's baud is 300 to 4000000" 12a)))
    (i2c (Error ("decode is none, ws281x or uart:BAUD" (decode i2c))))
    |}]
;;
