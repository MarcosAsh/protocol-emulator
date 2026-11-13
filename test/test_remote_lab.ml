open! Core
open Protocol_emulator

let diagram name = In_channel.read_all [%string "diagrams/%{name}.json"]

(* Each diagram, with the playground's first frame. *)
let corpus =
  [ "uart_tx", "11000101\n00111010"
  ; "dshot", "1000001011000110"
  ; "spi_master", "10100101"
  ; "ws2812", "000100001111111100000000"
  ; "uart_rx", "11000101\n00111010"
  ]
;;

(* Goes through the job file's text, as the worker reads it. *)
let check ?(decode = Remote_lab.Decode.Off) ~frames diagram =
  Remote_lab.Job.to_string { program = Diagram { diagram; frames }; decode }
  |> Remote_lab.Job.of_string
  |> Or_error.bind ~f:Remote_lab.check
;;

let bench (b : Remote_lab.Bench.t) =
  match b with
  | Takes { probes; run_ms; decode = _ } ->
    let seen =
      List.map probes ~f:(fun p -> p.wiring.name) |> String.concat ~sep:" and "
    in
    [%string "takes it on %{seen}, %{run_ms#Int} ms"]
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

(* As JSON quotes it: bytes past ASCII are left as they are. *)
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
    ; "no such decoder", job ~extra:{|, "decode": "jtag"|} uart
    ; "a decoder without its pins", job ~extra:{|, "decode": "spi"|} uart
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
    (firmware (malformed ("a job has no such key" diagram)))
    ("no such decoder"
     (malformed
      ("no such decoder" (decode jtag)
       (decoders
        (uart spi i2c rgb_led_ws281x ir_nec ir_rc5 onewire_link can pwm dcf77 ps2
         dali caliper lfast snorble plinkoo i2c_timing)))))
    ("a decoder without its pins"
     (malformed ("the decoder needs a pin, as CHANNEL=OUT0" (decoder spi) clk)))
    ("a baud out of range"
     (malformed ("a decoder option is out of range" baudrate 12)))
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
  (* One word per frame, and a pixel two after the first. *)
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

(* 8N1 from the model's levels: 26 cycles per bit, each bit read in the middle. *)
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

let%expect_test "the pads a job may drive, and why the rest are refused" =
  List.iter Remote_lab.Pads.all ~f:(fun pin ->
    print_s
      [%message
        ""
          ~_:(Machine_trace.pin_name pin : string)
          ~_:(Remote_lab.Pads.safety pin : (string, string) Result.t)]);
  [%expect
    {|
    (OUT0 (Ok "UART_B, Pico B GP1 through R8 (1k)"))
    (OUT1 (Ok "CAN_TX, CAN board A's CTX input through R9"))
    (OUT2 (Ok "SWCLK, Pico B's SWCLK input through R11 (220R)"))
    (OUT3 (Ok "NEO_3V3, the 74AHCT125's input, R3 (10k) to GND"))
    (OUT4 (Error "FLASH_DI, which the flash drives in dual and quad reads"))
    (OUT5
     (Error "FLASH_CLK, which clocks commands into the flash, and it keeps them"))
    (OUT6 (Error "FLASH_CS_N, which selects the flash"))
    (IO0 (Error "USB_MIR0, Pico A GP6 with no series resistor"))
    (IO1 (Error "USB_MIR1, Pico A GP7 with no series resistor"))
    (IO2 (Error "I2C_SCL, Pico B GP3 and the EEPROM with no series resistor"))
    (IO3 (Error "I2C_SDA, Pico B GP2 and the EEPROM with no series resistor"))
    (IO4 (Error "DQ, which the DS18B20 pulls low with no series resistor"))
    (IO5 (Error "SWDIO, which with SWCLK reaches Pico B's debug port"))
    (IO6 (Error "ETH_TXP, the Ethernet jack"))
    (IO7 (Error "ETH_TXN, the Ethernet jack"))
    |}]
;;

(* [lanes] are (name, wave) pairs from OUT0 up, the first carrying the host's bits. *)
let lanes_diagram lanes =
  let lane (name, wave) =
    if String.mem wave '='
    then
      [%string
        {|{ "name": "%{name}", "wave": "%{wave}", "data": ["b0", "b1", "b2", "b3", "b4", "b5", "b6", "b7"] }|}]
    else [%string {|{ "name": "%{name}", "wave": "%{wave}" }|}]
  in
  [%string
    {|{ "signal": [ %{String.concat ~sep:", " (List.map lanes ~f:lane)} ], "table": { "cycles": 52 } }|}]
;;

let%expect_test "the bench takes lanes on OUT0 to OUT3 and captures them on either \
                 analyser"
  =
  let data = "0========" in
  let low = "0........" in
  let clock = "0nnnnnnnn" in
  List.iter
    [ "OUT0 and OUT2", [ "tx", data; "hold", low; "sck", clock ]
    ; "OUT3 alone on B", [ "a", low; "b", low; "c", low; "pixel", data ]
    ; "A and B", [ "tx", data; "hold", low; "sck", clock; "strobe", clock ]
    ; "OUT1, which no analyser sees, beside OUT0", [ "a", low; "can", data ]
    ; "a lane on OUT4", [ "tx", data; "b", low; "c", low; "d", low; "flash", clock ]
    ]
    ~f:(fun (what, lanes) ->
      print_s
        [%message
          what ~_:(summary (check ~frames:"11000101" (lanes_diagram lanes)) : Sexp.t)]);
  [%expect
    {|
    ("OUT0 and OUT2"
     (certified (host_words 1) (cycles 2424)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0 and OUT2, 2 ms")))
    ("OUT3 alone on B"
     (certified (host_words 1) (cycles 1968)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0 and OUT2 and OUT3, 2 ms")))
    ("A and B"
     (certified (host_words 1) (cycles 2424)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0 and OUT2 and OUT3, 2 ms")))
    ("OUT1, which no analyser sees, beside OUT0"
     (certified (host_words 1) (cycles 1968)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench "takes it on OUT0, 2 ms")))
    ("a lane on OUT4"
     (certified (host_words 1) (cycles 2424)
      (faults
       ((underflow false) (overflow false) (missed_deadline false) (decode false)
        (assumption false)))
      (bench
       "declines it: lane flash lands on OUT4, FLASH_DI, which the flash drives in dual and quad reads")))
    |}]
;;

let decode_of_check = function
  | Ok (Remote_lab.Certified { bench = Takes { decode = Some (analyser, args); _ }; _ })
    -> Ok (Sexp.to_string (Bench_wiring.Analyser.sexp_of_t analyser) :: args)
  | Ok (Certified { bench = Takes { decode = None; _ }; _ }) -> Ok []
  | Ok _ -> Or_error.error_s [%message "the bench does not take it"]
  | Error e -> Error e
;;

let%expect_test "decoders: the allowlist, each option's values, and the pins they read" =
  let four =
    lanes_diagram
      [ "tx", "0========"
      ; "hold", "0........"
      ; "sck", "0nnnnnnnn"
      ; "strobe", "0nnnnnnnn"
      ]
  in
  List.iter
    [ "none"
    ; "ws281x"
    ; "uart:115200"
    ; "uart:5000000"
    ; "uart:12a"
    ; "uart:tx=OUT3:invert_tx=yes:format=ascii"
    ; "spi:clk=OUT2:mosi=OUT0:cpol=1:wordsize=8"
    ; "spi:clk=OUT2:mosi=OUT3"
    ; "spi:mosi=OUT0"
    ; "i2c:scl=OUT2:sda=OUT0"
    ; "caliper:clk=OUT2:data=OUT0:unit=mm"
    ; "uart:rx=OUT1"
    ; "uart:rx=OUT4"
    ; "uart:rx=D4"
    ; "uart:format=hex:format=ascii"
    ; "uart:baudrate=9600;rm -rf ~"
    ; "uart:baudrate=$(id)"
    ; "uart:file=/etc/passwd"
    ; "../../tmp/evil:rx=OUT0"
    ; "uart:parity=none:baudrate"
    ; String.make 300 'a'
    ]
    ~f:(fun decode ->
      let checked =
        Or_error.bind (Remote_lab.Decode.of_string decode) ~f:(fun decode ->
          Remote_lab.Job.to_string
            { program = Diagram { diagram = four; frames = "11000101" }; decode }
          |> Remote_lab.Job.of_string
          |> Or_error.bind ~f:Remote_lab.check)
      in
      print_s
        [%message
          (String.prefix decode 48) ~_:(decode_of_check checked : string list Or_error.t)]);
  [%expect
    {|
    (none (Ok ()))
    (ws281x (Ok (A -P rgb_led_ws281x:din=D4 -A rgb_led_ws281x=rgb:reset)))
    (uart:115200 (Ok (A -P uart:rx=D4:baudrate=115200 -A uart=rx-data)))
    (uart:5000000 (Error ("a decoder option is out of range" baudrate 5000000)))
    (uart:12a (Error ("a decoder option is KEY=VALUE" 12a)))
    (uart:tx=OUT3:invert_tx=yes:format=ascii
     (Ok (B -P uart:tx=D4:invert_tx=yes:format=ascii -A uart=tx-data)))
    (spi:clk=OUT2:mosi=OUT0:cpol=1:wordsize=8
     (Ok (A -P spi:clk=D6:mosi=D4:cpol=1:wordsize=8 -A spi=mosi-data)))
    (spi:clk=OUT2:mosi=OUT3 (Error "the decoder's pins are on both analysers"))
    (spi:mosi=OUT0
     (Error ("the decoder needs a pin, as CHANNEL=OUT0" (decoder spi) clk)))
    (i2c:scl=OUT2:sda=OUT0 (Ok (A -P i2c:scl=D6:sda=D4 -A i2c=addr-data)))
    (caliper:clk=OUT2:data=OUT0:unit=mm
     (Ok (A -P caliper:clk=D6:data=D4:unit=mm -A caliper=measurements)))
    (uart:rx=OUT1
     (Error
      ("the decoder reads a pin no analyser captures in this job" rx (pin OUT1))))
    (uart:rx=OUT4
     (Error
      ("the decoder reads a pin no analyser captures in this job" rx (pin OUT4))))
    (uart:rx=D4 (Error ("a decoder channel is a pin, as OUT0" rx D4)))
    (uart:format=hex:format=ascii (Error "a decoder option is given twice"))
    ("uart:baudrate=9600;rm -rf ~"
     (Error ("a decoder option is out of range" baudrate "9600;rm -rf ~")))
    ("uart:baudrate=$(id)"
     (Error ("a decoder option is out of range" baudrate "$(id)")))
    (uart:file=/etc/passwd
     (Error
      ("the decoder has no such option" (decoder uart) file
       (options
        (baudrate data_bits parity stop_bits bit_order format invert_rx invert_tx
         rx tx)))))
    (../../tmp/evil:rx=OUT0
     (Error
      ("no such decoder" (decode ../../tmp/evil:rx=OUT0)
       (decoders
        (uart spi i2c rgb_led_ws281x ir_nec ir_rc5 onewire_link can pwm dcf77 ps2
         dali caliper lfast snorble plinkoo i2c_timing)))))
    (uart:parity=none:baudrate
     (Error ("a decoder option is KEY=VALUE" baudrate)))
    (aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
     (Error ("a decode is at most" (max_length 256) bytes)))
    |}]
;;

let blink = In_channel.read_all "blink.asm"

(* the certificate the chip's load check accepts for [source] under [config] *)
let certificate_for ?period ?(config = []) source =
  let config =
    List.fold config ~init:Program_config.default ~f:(fun c (key, v) ->
      (List.Assoc.find_exn Remote_lab.Firmware.config_fields key ~equal:String.equal) c v)
  in
  match Timed_program.check ?period ~config source with
  | Error _ -> []
  | Ok timed ->
    (match Chip_verdict.of_timed timed with
     | Accepted { certificate } -> certificate
     | Refused _ | No_certificate _ -> [])
;;

let firmware
  ?(config = [])
  ?certificate
  ?(tx = [])
  ?(cycles = 2000)
  ?period
  ?(decode = Remote_lab.Decode.Off)
  source
  =
  let certificate =
    Option.value_or_thunk certificate ~default:(fun () ->
      certificate_for ?period ~config source)
  in
  Remote_lab.Job.to_string
    { program =
        Firmware
          { source
          ; config
          ; certificate
          ; tx
          ; cycles
          ; period
          ; period_floor = None
          ; single_capture_edge = false
          }
    ; decode
    }
;;

let firmware_summary text =
  match Remote_lab.Job.of_string text |> Or_error.bind ~f:Remote_lab.check with
  | Ok (Certified { certificate; bench = b; _ }) ->
    let drives =
      List.find (String.split_lines certificate) ~f:(String.is_prefix ~prefix:"pins it")
    in
    [%message "certified" (drives : string option) ~bench:(bench b : string)]
  | checked -> summary checked
;;

let%expect_test "firmware jobs: the pins each can drive, and what the bench makes of them"
  =
  let uart =
    {|
    wait tx
    pull
    mov p, osr
    set pins, 1
idle:
    wait tx
    pull
    set x, 7
    mov t, now
    set pins, 0
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1
    wait t
    jmp idle
|}
  in
  List.iter
    [ "blink on OUT0", firmware blink
    ; "blink on OUT3", firmware ~config:[ "set_base", 8 ] blink
    ; ( "uart on OUT0 with a decode"
      , firmware
          ~period:417
          ~tx:[ 417; 0xc5; 0x3a ]
          ~cycles:20_000
          ~decode:(Remote_lab.Decode.of_string "uart:115200" |> ok_exn)
          uart )
    ; "blink on OUT4, the flash's DI", firmware ~config:[ "set_base", 9 ] blink
    ; "set pindirs on IO0", firmware ~config:[ "set_base", 12 ] blink
    ; ( "side-set turning IO5 out"
      , firmware
          ~config:[ "side_set_base", 17; "side_set_pindirs", 1 ]
          ".side_set 1\nloop:\n    nop side 1\n    jmp loop" )
    ; ( "out pins, 16 from OUT0"
      , firmware ~config:[ "out_base", 5 ] "loop:\n    out pins, 16\n    jmp loop" )
    ; "reads a pin", firmware "loop:\n    wait 1 pin 0\n    jmp loop"
    ; ( "Manchester from OUT3, whose pair is OUT4"
      , firmware
          ~config:[ "out_base", 8; "manchester", 1 ]
          "loop:\n    out pins, 1\n    jmp loop" )
    ; ( "OUT6, and a level on IO0 it never turns out"
      , firmware
          ~config:[ "set_count", 2; "set_base", 11 ]
          "loop:\n    set pins, 3\n    jmp loop" )
    ]
    ~f:(fun (what, text) -> print_s [%message what ~_:(firmware_summary text : Sexp.t)]);
  [%expect
    {|
    ("blink on OUT0"
     (certified (drives ("pins it can drive: OUT0"))
      (bench "takes it on OUT0, 2 ms")))
    ("blink on OUT3"
     (certified (drives ("pins it can drive: OUT3"))
      (bench "takes it on OUT3, 2 ms")))
    ("uart on OUT0 with a decode"
     (certified (drives ("pins it can drive: OUT0"))
      (bench "takes it on OUT0, 2 ms")))
    ("blink on OUT4, the flash's DI"
     (certified (drives ("pins it can drive: OUT4"))
      (bench
       "declines it: lane OUT4 lands on OUT4, FLASH_DI, which the flash drives in dual and quad reads")))
    ("set pindirs on IO0"
     (certified (drives ("pins it can drive: IO0"))
      (bench
       "declines it: it can drive IO0, USB_MIR0, Pico A GP6 with no series resistor")))
    ("side-set turning IO5 out"
     (certified (drives ("pins it can drive: IO5"))
      (bench
       "declines it: it can drive IO5, SWDIO, which with SWCLK reaches Pico B's debug port")))
    ("out pins, 16 from OUT0"
     (certified
      (drives ("pins it can drive: OUT0 OUT1 OUT2 OUT3 OUT4 OUT5 OUT6"))
      (bench
       "declines it: lane OUT4 lands on OUT4, FLASH_DI, which the flash drives in dual and quad reads")))
    ("reads a pin"
     (certified (drives ("pins it can drive: none"))
      (bench "declines it: it reads pins, which no peer drives on the bench")))
    ("Manchester from OUT3, whose pair is OUT4"
     (certified (drives ("pins it can drive: OUT3 OUT4"))
      (bench
       "declines it: lane OUT4 lands on OUT4, FLASH_DI, which the flash drives in dual and quad reads")))
    ("OUT6, and a level on IO0 it never turns out"
     (certified (drives ("pins it can drive: OUT6"))
      (bench
       "declines it: lane OUT6 lands on OUT6, FLASH_CS_N, which selects the flash")))
    |}]
;;

let%expect_test "hostile firmware jobs" =
  let ours = certificate_for blink in
  let tampered = List.mapi ours ~f:(fun i w -> if i = 2 then w lxor 1 else w) in
  let raw extra = [%string {|{"lab": 1, "firmware": %{json_string blink}%{extra}}|}] in
  List.iter
    [ "a certificate that does not match", firmware ~certificate:tampered blink
    ; "no certificate", raw ""
    ; "an empty certificate", firmware ~certificate:[] blink
    ; ( "a certificate past the data memory"
      , firmware ~certificate:(List.init 513 ~f:(Fn.const 0)) blink )
    ; "a word past 16 bits", raw {|, "certificate": [65536]|}
    ; "a negative word", raw {|, "certificate": [-1]|}
    ; "a fraction", raw {|, "certificate": [1.5]|}
    ; "a firmware past its limit", firmware (blink ^ String.make 8_200 ';')
    ; "a job past its limit", raw (String.make 17_000 ' ')
    ; ( "route, which needs the other engine"
      , raw {|, "certificate": [], "config": {"route": 1}|} )
    ; ( "line_code, which needs a table"
      , raw {|, "certificate": [], "config": {"line_code": 1}|} )
    ; ( "a config key twice"
      , raw {|, "certificate": [], "config": {"set_base": 5, "set_base": 9}|} )
    ; "a key twice", raw {|, "certificate": [], "certificate": [1]|}
    ; "a diagram too", raw {|, "certificate": [], "diagram": "x"|}
    ; "too many tx words", firmware ~tx:(List.init 65 ~f:Fn.id) blink
    ; "a run past the cap", firmware ~cycles:400_001 blink
    ; "shell in the source", firmware "$(reboot)\n`id`; rm -rf ~"
    ; ( "a deadline it can miss"
      , firmware "    mov t, now\nloop:\n    wait t+\n    jmp loop" )
    ; ( "a path for a decode"
      , raw {|, "certificate": [], "decode": "../../../../etc/passwd"|} )
    ]
    ~f:(fun (what, text) -> print_s [%message what ~_:(firmware_summary text : Sexp.t)]);
  [%expect
    {|
    ("a certificate that does not match"
     (refused
      ("kernel: accepted"
       "chip: its load check refuses the job's certificate at pc 0 (next phase), so the chip won't start it"
       "a certificate the chip accepts: 1,0,128,0,0")))
    ("no certificate" (malformed "a firmware job carries its certificate"))
    ("an empty certificate"
     (refused
      ("kernel: accepted"
       "chip: its load check refuses the job's certificate at pc 3 (target phase), so the chip won't start it"
       "a certificate the chip accepts: 1,0,128,0,0")))
    ("a certificate past the data memory"
     (malformed ("a job's list is at most" certificate (longest 512) long)))
    ("a word past 16 bits"
     (malformed
      ("a job's number is a whole number in range" certificate (most 65535))))
    ("a negative word"
     (malformed
      ("a job's number is a whole number in range" certificate (most 65535))))
    ("a fraction"
     (malformed
      ("a job's number is a whole number in range" certificate (most 65535))))
    ("a firmware past its limit"
     (malformed ("a firmware is at most" (Firmware.max_source 8192) bytes)))
    ("a job past its limit"
     (malformed ("a job is at most" (max_bytes 16384) bytes)))
    ("route, which needs the other engine"
     (malformed
      ("a firmware's config has no such key" route
       (keys
        (side_set_base side_set_pindirs in_base in_count out_base out_count
         set_base set_count jmp_pin capture_pin capture_rising in_shift_right
         out_shift_right autopush push_threshold autopull pull_threshold
         crc_width crc_poly crc_init crc_reflect crc_complement stuff_threshold
         stuff_level period_fraction autopull_data manchester)))))
    ("line_code, which needs a table"
     (malformed
      ("a firmware's config has no such key" line_code
       (keys
        (side_set_base side_set_pindirs in_base in_count out_base out_count
         set_base set_count jmp_pin capture_pin capture_rising in_shift_right
         out_shift_right autopush push_threshold autopull pull_threshold
         crc_width crc_poly crc_init crc_reflect crc_complement stuff_threshold
         stuff_level period_fraction autopull_data manchester)))))
    ("a config key twice" (malformed "a firmware's config gives a key twice"))
    ("a key twice" (malformed "a job gives a key twice"))
    ("a diagram too" (malformed ("a job has no such key" diagram)))
    ("too many tx words"
     (malformed ("a job's list is at most" tx (longest 64) long)))
    ("a run past the cap"
     (malformed
      ("a job's number is a whole number in range" cycles (most 400000))))
    ("shell in the source"
     (refused
      ("refused by the analyser"
       "(((line 1 \"$(reboot)\") (\"cannot parse\" \"$(reboot)\" (args ())))"
       " ((line 2 \"`id`; rm -rf ~\") (\"cannot parse\" `id` (args ()))))"
       "line 1: cannot parse \"$(reboot)\" (args ())"
       "line 2: cannot parse `id` (args ())")))
    ("a deadline it can miss"
     (refused
      ("refused by the analyser" "1 of 1 deadline waits may be missed"
       "  1  wait t+                      phase -65532..?  slack ?..65532  MAY MISS"
       "a bound of ? means none: the way here has a wait for a pin or a fifo, a capture nothing is assumed about, a period the host loads, or a loop that falls further behind on every pass"
       "line 3: this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait")))
    ("a path for a decode"
     (malformed
      ("no such decoder" (decode ../../../../etc/passwd)
       (decoders
        (uart spi i2c rgb_led_ws281x ir_nec ir_rc5 onewire_link can pwm dcf77 ps2
         dali caliper lfast snorble plinkoo i2c_timing)))))
    |}]
;;
