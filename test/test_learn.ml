open! Core
open Protocol_emulator

let recording name =
  In_channel.read_all [%string "learn/%{name}.edges"] |> Recording.of_string |> ok_exn
;;

let bits_string bits =
  Array.to_list bits
  |> List.map ~f:(fun b -> if b then '1' else '0')
  |> String.of_char_list
;;

(* What was learned, without the frames, then the new message and its firmware, run on the
   model and read back. *)
let show ?(speak = true) name =
  match Learn.learn (recording name) with
  | Error e -> print_s [%message (e : Error.t)]
  | Ok t ->
    String.split_lines (Learn.to_string t)
    |> List.filter ~f:(fun line -> not (String.is_substring line ~substring:" s  kind "))
    |> List.iter ~f:print_endline;
    if speak
    then (
      match Learn.new_message t with
      | Error e -> print_s [%message (e : Error.t)]
      | Ok (field, message) ->
        let firmware =
          Learn_firmware.generate ~clock_hz:48e6 ~pins:(Line 5) t |> ok_exn
        in
        let frames = [ message.kind, message.bits ] in
        let read =
          Learn_firmware.simulate ~clock_hz:48e6 ~pins:(Line 5) firmware t frames
          |> ok_exn
          |> Learn.decode t
          |> ok_exn
        in
        let sent = Learn.with_checks t ~kind:message.kind message.bits in
        print_s
          [%message
            "new message"
              ~field:(Learn.field_value t field message.bits : int)
              ~seen:(field.seen : int list)
              ~bits:(bits_string sent)
              ~firmware:
                (Analyser.Verdict.to_string (Timed_program.verdict firmware.timed))
              ~model_reads_it_back:
                ([%equal: (int * bool array) list]
                   [ message.kind, sent ]
                   (List.map read ~f:(fun f -> f.kind, f.bits))
                 : bool)])
;;

let%expect_test "NEC, an unmarked ceiling light's remote" =
  show "nec_ceiling_light";
  [%expect
    {|
    line D0, idle 1
    pulse, unit 560.4 us, 0 = mark 1 space 1, 1 = mark 1 space 3
    marks read -32.8 us long, as a receiver stretches them
    gap at least 74 units, 11 frames, 0 outliers
    kind 0: 4 frames, leader [], 0 bits, trailer [+16 -4 +1]
    kind 1: 7 frames, leader [+16 -8], 32 bits, trailer [+1]
    kind 1 check: byte 3 = ~byte 2 (40 bits against 2^4.0)
    kind 1 field: bits 16..17, 4 values seen
    kind 1 field: bits 19..20, 2 values seen
    kind 1 field: bits 22..22, 2 values seen
    ("new message" (field 0) (seen (0 1 2 3))
     (bits 10000010010101110001001011101101)
     (firmware "80 words, 24 deadline waits, worst slack 26891")
     (model_reads_it_back true))
    |}]
;;

let%expect_test "NEC, a Joy-IT remote, every key" =
  show "nec_joy_it";
  [%expect
    {|
    line D0, idle 1
    pulse, unit 565.1 us, 0 = mark 1 space 1, 1 = mark 1 space 3
    marks read 23.4 us long, as a receiver stretches them
    gap at least 69 units, 51 frames, 0 outliers
    kind 0: 30 frames, leader [], 0 bits, trailer [+16 -4 +1]
    kind 1: 21 frames, leader [+16 -8], 32 bits, trailer [+1]
    kind 1 check: byte 3 = ~byte 2 (168 bits against 2^4.0)
    kind 1 field: bits 16..20, 20 values seen
    kind 1 field: bits 22..22, 2 values seen
    ("new message" (field 1)
     (seen (0 2 3 4 5 6 7 8 9 10 12 13 18 21 22 24 25 26 28 30))
     (bits 00000000111111111000001001111101)
     (firmware "80 words, 24 deadline waits, worst slack 27112")
     (model_reads_it_back true))
    |}]
;;

let%expect_test "RC-5, a Philips VCR's button held" =
  show "rc5_philips_vcr";
  [%expect
    {|
    line D1, idle 1
    manchester, half bit 876.2 us, a one idle then active, the first half hidden in the idle
    marks read 23.5 us long, as a receiver stretches them
    gap at least 102 units, 17 frames, 0 outliers
    kind 0: 17 frames, leader [], 14 bits, trailer []
    (e "no field differs between frames")
    |}]
;;

let%expect_test "RC-6 mode 0, a Philips remote's numbers" =
  show "rc6_philips";
  [%expect
    {|
    line D0, idle 1
    manchester, half bit 446.2 us, a one active then idle, bit 4 twice as wide
    marks read -14.2 us long, as a receiver stretches them
    gap at least 185 units, 23 frames, 0 outliers
    kind 0: 23 frames, leader [+6 -2], 21 bits, trailer []
    kind 0 field: bits 4..4, 2 values seen
    kind 0 field: bits 17..20, 11 values seen
    ("new message" (field 10) (seen (0 1 2 3 4 5 6 7 8 9 12))
     (bits 100010000000000001010)
     (firmware "79 words, 23 deadline waits, worst slack 21406")
     (model_reads_it_back true))
    |}]
;;

let%expect_test "RC-6, a Kathrein receiver's remote" =
  show "rc6_kathrein";
  [%expect
    {|
    line D0, idle 1
    manchester, half bit 446.5 us, a one active then idle, bit 4 twice as wide
    marks read -12.7 us long, as a receiver stretches them
    gap at least 154 units, 24 frames, 0 outliers
    kind 0: 24 frames, leader [+6 -2], 37 bits, trailer []
    kind 0 field: bits 21..21, 2 values seen
    kind 0 field: bits 33..36, 11 values seen
    ("new message" (field 10) (seen (0 1 2 3 4 5 6 7 8 9 12))
     (bits 1110010000000010001101000000000001010)
     (firmware "79 words, 23 deadline waits, worst slack 21421")
     (model_reads_it_back true))
    |}]
;;

let%expect_test "SIRC, 20 bits" =
  show "sirc";
  [%expect
    {|
    line D0, idle 1
    pulse, unit 595.6 us, 0 = mark 1 space 1, 1 = mark 2 space 1, the last mark a bit
    marks read -15.2 us long, as a receiver stretches them
    gap at least 26 units, 4 frames, 0 outliers
    kind 0: 4 frames, leader [+4 -1], 20 bits, trailer []
    (e "no field differs between frames")
    |}]
;;

let%expect_test "PT2262 on 433 MHz, a Maplin socket remote's four buttons" =
  show "pt2262_maplin";
  [%expect
    {|
    line D0, idle 0
    pulse, unit 315.2 us, 0 = mark 1 space 3, 1 = mark 3 space 1
    marks read -23.4 us long, as a receiver stretches them
    gap at least 31 units, 25 frames, 7 outliers
    kind 0: 25 frames, leader [], 24 bits, trailer [+1]
    kind 0 field: bits 13..13, 2 values seen
    kind 0 field: bits 15..15, 2 values seen
    kind 0 field: bits 17..17, 2 values seen
    kind 0 field: bits 19..19, 2 values seen
    ("new message" (field 0) (seen (0 1)) (bits 000100010001000101000100)
     (firmware "36 words, 11 deadline waits, worst slack 15121")
     (model_reads_it_back true))
    |}]
;;

let%expect_test "Modbus RTU at 9600 baud, CRC-16/MODBUS found" =
  show "modbus_wizmodbus";
  [%expect
    {|
    line D0, idle 1
    uart, 9608.4 baud (bit 104.08 us), 8N1
    marks read 0.3 us long, as a receiver stretches them
    gap at least 135 units, 44 frames, 0 outliers
    kind 0: 44 frames, leader [], 64 bits, trailer []
    kind 0 check: crc-16 poly 0x8005 init 0xffff (with xorout, from frames of one length) xorout 0x0000 over bits 0.., check sent high bit first, which is CRC-16/MODBUS (144 bits against 2^17.6)
    kind 0 field: bits 8..8, 2 values seen
    kind 0 field: bits 10..10, 2 values seen
    kind 0 field: bits 16..18, 2 values seen
    kind 0 field: bits 24..31, 20 values seen
    kind 0 field: bits 40..41, 3 values seen
    ("new message" (field 1)
     (seen (0 2 3 4 5 6 7 8 232 234 236 238 240 242 244 246 248 250 252 254))
     (bits 1000000011000000110000001000000000000000010000001010100111110001)
     (firmware "32 words, 6 deadline waits, worst slack 4989")
     (model_reads_it_back true))
    |}]
;;

let%expect_test "Modbus RTU on an inverted RS-232 line, 8E1" =
  show "modbus_brainchild";
  [%expect
    {|
    line D1, idle 0
    uart, 19267.0 baud (bit 51.90 us), 8E1
    marks read -0.4 us long, as a receiver stretches them
    gap at least 1179 units, 2 frames, 0 outliers
    kind 0: 1 frames, leader [], 464 bits, trailer []
    kind 1: 1 frames, leader [], 552 bits, trailer []
    (e "no field differs between frames")
    |}]
;;

let%expect_test "SPI to a MAX7219: the clock, the edge it reads on and the select found" =
  show ~speak:false "spi_max7219";
  [%expect
    {|
    line D2, idle 0
    clocked, clock D3 at 29411.8 Hz idle 0, data D2 read on the rising edge, D1 selects
    marks read 0.0 us long, as a receiver stretches them
    gap at least 2 units, 27 frames, 2 outliers
    kind 0: 27 frames, leader [], 16 bits, trailer []
    kind 0 field: bits 4..7, 14 values seen
    kind 0 field: bits 8..15, 10 values seen
    |}]
;;

let%expect_test "a UART counting, one long frame" =
  show ~speak:false "uart_count";
  [%expect
    {|
    line D0, idle 1
    uart, 19507.9 baud (bit 51.26 us), 8N1
    marks read 1.3 us long, as a receiver stretches them
    gap at least 0 units, 1 frames, 0 outliers
    kind 0: 1 frames, leader [], 2920 bits, trailer []
    |}]
;;

let%expect_test "an IR carrier is no protocol" =
  show "carrier_rc5";
  [%expect
    {|
    (e
     ("unknown: no coding reads the frames" (line D0) (unit_us 9.12181264211005)
      (frames 34)))
    |}]
;;

(* Synthetic protocols with known answers. *)

let protocol ?(lsb_first = true) ?(rules = []) ~coding ~unit_s ~idle ~kinds ~gap () =
  { Learn.line = "D0"
  ; unit_s
  ; bias_s = 0.
  ; idle
  ; coding
  ; lsb_first
  ; kinds
  ; gap
  ; frames = []
  ; outliers = 0
  ; rules =
      List.mapi rules ~f:(fun kind rule ->
        kind, [ rule, { Learn_check.Evidence.bits = 0; hypotheses = 1. } ])
  ; fields = []
  }
;;

let run active units = { Learn.Run.active; units }

module Shape = struct
  type t =
    | Pulse_distance
    | Pulse_width
    | Pwm
    | Manchester
    | Uart
    | Clocked
  [@@deriving sexp_of, compare, enumerate]
end

let crc_rule random ~bits =
  let width = if Random.State.bool random then 8 else 16 in
  Learn_check.Rule.Crc
    { width
    ; poly = (2 * Random.State.int random (1 lsl (width - 1))) + 1
    ; init = Random.State.int random (1 lsl width)
    ; xorout = 0
    ; start = 0
    ; check_lsb_first = Random.State.bool random
    ; init_known = false
    }
  |> fun rule -> Option.some_if (bits >= 24) rule
;;

(* A protocol of [shape], eight frames of random bits under it, and its recording. *)
let synthetic random (shape : Shape.t) =
  let r lo hi = lo + Random.State.int random (hi - lo + 1) in
  let float lo hi = lo +. Random.State.float random (hi -. lo) in
  let idle = Random.State.bool random in
  let leader () = [ run true (r 8 16); run false (r 4 8) ] in
  let coding, unit_s, kinds, gap =
    match shape with
    | Pulse_distance ->
      ( Learn.Coding.Pulse { zero = 1, 1; one = 1, 3; last_is_bit = false }
      , float 300e-6 1e-3
      , [ { Learn.Kind.leader = leader (); bits = r 12 40; trailer = [ run true 1 ] } ]
      , r 30 80 )
    | Pulse_width ->
      ( Pulse { zero = 1, 1; one = 2, 1; last_is_bit = true }
      , float 300e-6 1e-3
      , [ { leader = leader (); bits = r 12 32; trailer = [] } ]
      , r 30 60 )
    | Pwm ->
      ( Pulse { zero = 1, 3; one = 3, 1; last_is_bit = false }
      , float 200e-6 600e-6
      , [ { leader = []; bits = r 12 32; trailer = [ run true 1 ] } ]
      , r 31 60 )
    | Manchester ->
      let hidden_half = Random.State.bool random in
      let bits = r 12 32 in
      ( Manchester
          { (* the first bit is a 1, and after a leader's space a 1 that started idle
               would read as a longer space and a hidden half, as RC-5's *)
            one_starts_active = not hidden_half
          ; wide = (if Random.State.bool random then Some (r 2 (bits - 2)) else None)
          ; hidden_half
          }
      , float 300e-6 1e-3
      , [ { leader = (if hidden_half then [] else leader ()); bits; trailer = [] } ]
      , r 40 120 )
    | Uart ->
      let data_bits = r 7 8 in
      ( Uart
          { data_bits
          ; parity =
              List.random_element_exn
                ~random_state:random
                [ None; Some Learn.Parity.Even; Some Odd ]
          ; stop_bits = 1
          }
      , 1. /. float 1200. 115200.
      , [ { leader = []; bits = data_bits * r 4 10; trailer = [] } ]
      , r 40 80 )
    | Clocked ->
      ( Clocked
          { clock = "CLK"
          ; select = None
          ; sample_rising = Random.State.bool random
          ; clock_idle = Random.State.bool random
          }
      , float 5e-6 100e-6
      , [ { leader = []; bits = 8 * r 2 6; trailer = [] } ]
      , r 20 60 )
  in
  let bits = (List.hd_exn kinds).bits in
  let rules =
    match shape with
    | Uart | Clocked | Pulse_distance -> Option.to_list (crc_rule random ~bits)
    | Pulse_width | Pwm | Manchester -> []
  in
  let t = protocol ~coding ~unit_s ~idle ~kinds ~gap ~rules () in
  let frames =
    List.init 8 ~f:(fun _ ->
      let b = Array.init bits ~f:(fun _ -> Random.State.bool random) in
      (* RC-5 and RC-6 start with a 1, which sets which way round a one is *)
      (match shape with
       | Manchester -> b.(0) <- true
       | _ -> ());
      0, Learn.with_checks t ~kind:0 b)
  in
  let jitter, skew =
    match shape with
    | Uart | Clocked -> 0.02, 0.
    | _ -> 0.1, float (-0.15) 0.15
  in
  let recording =
    Learn.synthesize ~jitter ~skew ~seed:(Random.State.bits random) ~rate_hz:48e6 t frames
  in
  t, frames, recording
;;

let same_coding (a : Learn.Coding.t) (b : Learn.Coding.t) =
  match a, b with
  | Clocked a, Clocked b ->
    Bool.equal a.sample_rising b.sample_rising && Bool.equal a.clock_idle b.clock_idle
  | a, b -> Learn.Coding.equal a b
;;

let crc_poly (t : Learn.t) =
  List.concat_map t.rules ~f:snd
  |> List.find_map ~f:(fun (rule, _) ->
    match rule with
    | Learn_check.Rule.Crc m -> Some (m.width, m.poly)
    | _ -> None)
;;

(* The learned protocol's firmware, which the kernel must accept at the chip's clock, and
   for a few, run on the model at 4 MHz to keep it short and read back. *)
let speaks ~simulate (learned : Learn.t) frames =
  let pins =
    match learned.coding with
    | Clocked _ -> Learn_firmware.Pins.Clocked { clock = 10; data = 9; deselect = true }
    | _ -> Line 5
  in
  match Learn_firmware.generate ~clock_hz:48e6 ~pins learned with
  | Error e -> Some (Error.to_string_hum e)
  | Ok _ when not simulate -> None
  | Ok _ ->
    let clock_hz = 4e6 in
    let read =
      let%bind.Or_error firmware = Learn_firmware.generate ~clock_hz ~pins learned in
      let%bind.Or_error recording =
        Learn_firmware.simulate ~clock_hz ~pins firmware learned (List.take frames 2)
      in
      Learn.decode learned recording
    in
    (match read with
     | Error e -> Some (Error.to_string_hum e)
     | Ok read ->
       Option.some_if
         (not
            ([%equal: (int * bool array) list]
               (List.take frames 2)
               (List.map read ~f:(fun f -> f.kind, f.bits))))
         "the model's frames read back otherwise")
;;

let%expect_test "random protocols of every shape, learned from their recordings" =
  let random = Random.State.make [| 2026; 10; 30 |] in
  let results =
    List.concat_map Shape.all ~f:(fun shape ->
      List.init 20 ~f:(fun trial ->
        let truth, frames, recording = synthetic random shape in
        let wrong =
          match Learn.learn recording with
          | Error e -> Some (Error.to_string_hum e)
          | Ok learned ->
            let expected_frames = List.map frames ~f:snd in
            let got_frames = List.map learned.frames ~f:(fun f -> f.bits) in
            if not (same_coding truth.coding learned.coding)
            then Some (Sexp.to_string [%sexp (learned.coding : Learn.Coding.t)])
            else if Float.( > ) (Float.abs ((learned.unit_s /. truth.unit_s) -. 1.)) 0.01
            then Some (sprintf "unit %g, not %g" learned.unit_s truth.unit_s)
            else if not ([%equal: Learn.Kind.t list] truth.kinds learned.kinds)
            then Some (Sexp.to_string [%sexp (learned.kinds : Learn.Kind.t list)])
            else if not ([%equal: bool array list] expected_frames got_frames)
            then Some "frames read otherwise"
            else if not ([%equal: (int * int) option] (crc_poly truth) (crc_poly learned))
            then Some "the CRC is not the one sent"
            else speaks ~simulate:(trial < 3) learned frames
        in
        shape, trial, wrong))
  in
  List.iter Shape.all ~f:(fun shape ->
    let mine = List.filter results ~f:(fun (s, _, _) -> Shape.compare s shape = 0) in
    printf
      !"%{Sexp} %d of %d learned exactly, and their firmware accepted\n"
      [%sexp (shape : Shape.t)]
      (List.count mine ~f:(fun (_, _, w) -> Option.is_none w))
      (List.length mine);
    List.iter mine ~f:(fun (_, trial, w) ->
      Option.iter w ~f:(fun w -> printf "  trial %d: %s\n" trial w)));
  [%expect
    {|
    Pulse_distance 20 of 20 learned exactly, and their firmware accepted
    Pulse_width 20 of 20 learned exactly, and their firmware accepted
    Pwm 20 of 20 learned exactly, and their firmware accepted
    Manchester 20 of 20 learned exactly, and their firmware accepted
    Uart 20 of 20 learned exactly, and their firmware accepted
    Clocked 20 of 20 learned exactly, and their firmware accepted
    |}]
;;

(* Recordings that hold no protocol, or too little to say, must be answered so. *)

let%expect_test "noise, a square wave and a clock alone are unknown" =
  let random = Random.State.make [| 7 |] in
  let line name first edges = { Recording.Line.name; first; edges } in
  let of_lengths lengths =
    List.folding_map lengths ~init:1000 ~f:(fun at d -> at + d, at + d) |> Array.of_list
  in
  let noise =
    of_lengths (List.init 400 ~f:(fun _ -> 2_000 + Random.State.int random 60_000))
  in
  let square = of_lengths (List.init 400 ~f:(fun _ -> 20_000)) in
  List.iter
    [ "noise", [ line "D0" true noise ]
    ; "square wave", [ line "D0" true square ]
    ; ( "a clock and a line that never moves"
      , [ line "CLK" false square; line "D" true [| 5 |] ] )
    ]
    ~f:(fun (name, lines) ->
      let recording =
        { Recording.rate_hz = 48e6; length = 50_000_000; lines; notes = [] }
      in
      match Learn.learn recording with
      | Ok t -> printf "%s: learned, wrongly\n%s" name (Learn.to_string t)
      | Error e -> printf "%s: %s\n" name (Error.to_string_hum e));
  [%expect
    {|
    noise: ("unknown: no unit puts the runs on a grid" (line D0))
    square wave: ("unknown: every bit reads the same, as a clock or carrier would" (line D0))
    a clock and a line that never moves: ("unknown: every bit reads the same, as a clock or carrier would" (line CLK))
    |}]
;;

let%expect_test "no check is claimed from too few frames, or from random ones" =
  let random = Random.State.make [| 11 |] in
  let frame () = Array.init 48 ~f:(fun _ -> Random.State.bool random) in
  let crc =
    Learn_check.Rule.Crc
      { width = 16
      ; poly = 0x8005
      ; init = 0xffff
      ; xorout = 0
      ; start = 0
      ; check_lsb_first = false
      ; init_known = false
      }
  in
  let with_crc () = Learn_check.apply [ crc ] (frame ()) in
  let found frames =
    Learn_check.find ~lsb_first:true frames
    |> List.map ~f:(fun (rule, _) -> Learn_check.Rule.to_string ~lsb_first:true rule)
  in
  print_s
    [%message
      ""
        ~two_frames_with_a_crc:(found [ with_crc (); with_crc () ] : string list)
        ~four_frames_with_a_crc:
          (found (List.init 4 ~f:(fun _ -> with_crc ())) : string list)
        ~twenty_random_frames:(found (List.init 20 ~f:(fun _ -> frame ())) : string list)];
  [%expect
    {|
    ((two_frames_with_a_crc ())
     (four_frames_with_a_crc
      ("crc-16 poly 0x8005 init 0xffff (with xorout, from frames of one length) xorout 0x0000 over bits 0.., check sent high bit first, which is CRC-16/MODBUS"))
     (twenty_random_frames ()))
    |}]
;;
