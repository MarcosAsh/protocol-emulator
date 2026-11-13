open! Core
open! Hardcaml

let clock_hz = Wavedrom.rated_hz

(* the playground's cap on the model's run: 8.3 ms at 48 MHz *)
let max_cycles = 400_000

module Value = Wavejson.Value

let quote s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter s ~f:(fun c ->
    match c with
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\t' -> Buffer.add_string b "\\t"
    | c when Char.to_int c < 0x20 || Char.to_int c = 0x7f ->
      Buffer.add_string b (sprintf "\\u%04x" (Char.to_int c))
    | c -> Buffer.add_char b c);
  Buffer.add_char b '"';
  Buffer.contents b
;;

(* compact; Wavejson.Value.parse and every browser read it back *)
let rec json (v : Value.t) =
  match v with
  | Null -> "null"
  | Bool b -> Bool.to_string b
  | Number f when Float.is_integer f -> Int.to_string (Float.to_int f)
  | Number f -> Float.to_string f
  | String s -> quote s
  | List l -> "[" ^ String.concat ~sep:"," (List.map l ~f:json) ^ "]"
  | Object kv ->
    "{"
    ^ String.concat ~sep:"," (List.map kv ~f:(fun (k, v) -> quote k ^ ":" ^ json v))
    ^ "}"
;;

let int i = Value.Number (Float.of_int i)
let ints l = Value.List (List.map l ~f:int)

module Decode = struct
  type t =
    | Off
    | Uart of int
    | Ws281x
  [@@deriving sexp_of, equal]

  let of_string s =
    match String.lsplit2 s ~on:':' with
    | None when String.equal s "none" -> Ok Off
    | None when String.equal s "ws281x" -> Ok Ws281x
    | Some ("uart", baud) ->
      (match Int.of_string_opt baud with
       | Some b when b >= 300 && b <= 4_000_000 && String.for_all baud ~f:Char.is_digit ->
         Ok (Uart b)
       | _ -> Or_error.error_s [%message "uart's baud is 300 to 4000000" baud])
    | _ ->
      Or_error.error_s
        [%message "decode is none, ws281x or uart:BAUD" ~decode:(s : string)]
  ;;

  let to_string = function
    | Off -> "none"
    | Ws281x -> "ws281x"
    | Uart b -> sprintf "uart:%d" b
  ;;

  let sigrok_args t ~channel =
    match t with
    | Off -> []
    | Uart b -> [ "-P"; sprintf "uart:rx=%s:baudrate=%d" channel b; "-A"; "uart=rx-data" ]
    | Ws281x ->
      [ "-P"; "rgb_led_ws281x:din=" ^ channel; "-A"; "rgb_led_ws281x=rgb:reset" ]
  ;;
end

module Job = struct
  type t =
    { diagram : string
    ; frames : string
    ; decode : Decode.t
    }
  [@@deriving sexp_of]

  let max_bytes = 16_384
  let max_diagram = 8_192
  let max_frames = 16
  let max_frame_bits = 256

  (* one line per frame, blanks removed *)
  let tidy frames =
    String.split_lines frames
    |> List.map ~f:(String.filter ~f:(Fn.non Char.is_whitespace))
    |> List.filter ~f:(Fn.non String.is_empty)
  ;;

  let printable s =
    String.for_all s ~f:(fun c ->
      Char.equal c '\n'
      || Char.equal c '\t'
      || Char.equal c '\r'
      || (Char.to_int c >= 0x20 && Char.to_int c < 0x7f))
  ;;

  let of_string s =
    let open Or_error.Let_syntax in
    let%bind () =
      if String.length s > max_bytes
      then Or_error.error_s [%message "a job is at most" (max_bytes : int) "bytes"]
      else if not (printable s)
      then Or_error.error_s [%message "a job is printable ASCII"]
      else Ok ()
    in
    let%bind fields =
      match%bind Value.parse s with
      | Object fields -> Ok fields
      | _ -> Or_error.error_s [%message "a job is an object"]
    in
    let%bind () =
      match
        List.find fields ~f:(fun (k, _) ->
          not (List.mem [ "lab"; "diagram"; "frames"; "decode" ] k ~equal:String.equal))
      with
      | Some (key, _) -> Or_error.error_s [%message "a job has no such key" key]
      | None -> Ok ()
    in
    let field k = List.Assoc.find fields k ~equal:String.equal in
    let string k =
      match field k with
      | Some (String s) -> Ok s
      | _ -> Or_error.error_s [%message "a job's key is a string" k]
    in
    let%bind () =
      match field "lab" with
      | Some (Number 1.) -> Ok ()
      | _ -> Or_error.error_s [%message "a job says \"lab\": 1"]
    in
    let%bind diagram = string "diagram" in
    let%bind frames = string "frames" in
    let%bind decode =
      match field "decode" with
      | None -> Ok Decode.Off
      | Some _ -> string "decode" >>= Decode.of_string
    in
    let frames = tidy frames in
    let%bind () =
      if String.length diagram > max_diagram
      then Or_error.error_s [%message "a diagram is at most" (max_diagram : int) "bytes"]
      else if List.length frames > max_frames
      then Or_error.error_s [%message "a job has at most" (max_frames : int) "frames"]
      else if List.exists frames ~f:(fun f -> String.length f > max_frame_bits)
      then Or_error.error_s [%message "a frame is at most" (max_frame_bits : int) "bits"]
      else if List.exists frames ~f:(String.exists ~f:(fun c -> not (String.mem "01" c)))
      then Or_error.error_s [%message "a frame is 0s and 1s"]
      else Ok ()
    in
    Ok
      { diagram = String.rstrip diagram; frames = String.concat ~sep:"\n" frames; decode }
  ;;

  let to_string t =
    json
      (Object
         [ "lab", int 1
         ; "diagram", String t.diagram
         ; "frames", String t.frames
         ; "decode", String (Decode.to_string t.decode)
         ])
    ^ "\n"
  ;;

  let bits t =
    tidy t.frames
    |> List.map ~f:(fun f -> String.to_list f |> List.map ~f:(Char.equal '1'))
  ;;
end

module Pads = struct
  (* From demo/carrier_netlist.csv, which test/test_lab_pins.py checks. SWCLK is safe only
     because no job drives SWDIO: R13 holds it high, so no SWD request can end in its 0
     stop bit. *)
  let safety pin =
    match pin - Isa.first_output_pin with
    | 0 -> Ok "UART_B, Pico B GP1 through R8 (1k)"
    | 1 -> Ok "CAN_TX, CAN board A's CTX input through R9"
    | 2 -> Ok "SWCLK, Pico B's SWCLK input through R11 (220R)"
    | 3 -> Ok "NEO_3V3, the 74AHCT125's input, R3 (10k) to GND"
    | 4 -> Error "FLASH_DI, which the flash drives in dual and quad reads"
    | 5 -> Error "FLASH_CLK, which clocks commands into the flash, and it keeps them"
    | 6 -> Error "FLASH_CS_N, which selects the flash"
    | 7 -> Error "USB_MIR0, Pico A GP6 with no series resistor"
    | 8 -> Error "USB_MIR1, Pico A GP7 with no series resistor"
    | 9 -> Error "I2C_SCL, Pico B GP3 and the EEPROM with no series resistor"
    | 10 -> Error "I2C_SDA, Pico B GP2 and the EEPROM with no series resistor"
    | 11 -> Error "DQ, which the DS18B20 pulls low with no series resistor"
    | 12 -> Error "SWDIO, which with SWCLK reaches Pico B's debug port"
    | 13 -> Error "ETH_TXP, the Ethernet jack"
    | 14 -> Error "ETH_TXN, the Ethernet jack"
    | _ -> Error "not a pad"
  ;;

  let all = List.range Isa.first_output_pin Isa.num_pins
  let drivable = List.filter all ~f:(fun pin -> Result.is_ok (safety pin))
end

module Lane = struct
  type t =
    { name : string
    ; pin : int
    ; wiring : Bench_wiring.t option
    }
end

module Probe = struct
  type t =
    { lane : string
    ; wiring : Bench_wiring.t
    }
end

module Bench = struct
  type t =
    | Takes of
        { probes : Probe.t list
        ; run_ms : int
        }
    | Declines of string
end

module Image = struct
  type t =
    { config : Program_config.t
    ; words : int list
    ; certificate : int list
    ; loaded : int option
    ; floor : bool
    ; single_edge : bool
    ; data : int list
    }
end

type t =
  | Refused of
      { job : Job.t
      ; certificate : string
      }
  | Certified of
      { job : Job.t
      ; certificate : string
      ; lanes : Lane.t list
      ; input : (string * int array) option
      ; host_words : int list
      ; cycles : int
      ; levels : int array
      ; faults : Machine.Fault.t
      ; image : Image.t option
      ; bench : Bench.t
      }

let pin_name pin =
  if pin < Isa.first_output_pin
  then sprintf "IN%d" pin
  else if pin < Isa.first_bidir_pin
  then sprintf "OUT%d" (pin - Isa.first_output_pin)
  else sprintf "IO%d" (pin - Isa.first_bidir_pin)
;;

let channel (w : Bench_wiring.t) =
  sprintf
    "analyser %s D%d"
    (Sexp.to_string (Bench_wiring.Analyser.sexp_of_t w.analyser))
    w.channel
;;

(* STATUS's fault bits, as python/bench.py reads them *)
let fault_bits (f : Machine.Fault.t) =
  List.sum
    (module Int)
    [ f.underflow, 0x4; f.overflow, 0x8; f.missed_deadline, 0x10; f.decode, 0x20 ]
    ~f:(fun (set, bit) -> if set then bit else 0)
;;

let analyser_name (a : Bench_wiring.Analyser.t) =
  Sexp.to_string (Bench_wiring.Analyser.sexp_of_t a)
;;

let lane_safety (l : Lane.t) =
  match Pads.safety l.pin with
  | Ok _ -> None
  | Error why -> Some [%string "lane %{l.name} lands on %{pin_name l.pin}, %{why}"]
;;

(* whole milliseconds, plus one for the start *)
let run_ms cycles = (((cycles * 1000) + clock_hz - 1) / clock_hz) + 1

let bench_for (lanes : Lane.t list) ~host_words ~wanted =
  let declines why = Bench.Declines why in
  match lanes, List.find_map lanes ~f:lane_safety with
  | [], _ -> declines "it drives no pin"
  | _, Some why -> declines why
  | lanes, None ->
    let probes =
      List.filter_map lanes ~f:(fun l ->
        Option.map l.wiring ~f:(fun wiring -> { Probe.lane = l.name; wiring }))
    in
    if List.is_empty probes
    then declines "no analyser sees any pin it drives"
    else if List.length host_words > Machine.fifo_depth
    then
      declines
        [%string
          "%{List.length host_words#Int} host words, past the %{Machine.fifo_depth#Int} \
           the tx fifo holds before the start"]
    else if wanted > max_cycles
    then declines [%string "it runs past %{max_cycles#Int} cycles"]
    else Takes { probes; run_ms = run_ms wanted }
;;

let bench_line = function
  | Bench.Takes { probes; run_ms } ->
    let seen =
      List.map probes ~f:(fun p -> channel p.wiring) |> String.concat ~sep:" and "
    in
    [%string "bench: takes it, %{seen}, the engine stopped after %{run_ms#Int} ms"]
  | Declines why -> [%string "bench: declines it, %{why}, the trace is the model's"]
;;

let lane_line (l : Lane.t) =
  let wiring =
    match l.wiring with
    | None -> ""
    | Some w -> ", " ^ w.net ^ ", " ^ channel w
  in
  [%string "lane %{l.name}: %{pin_name l.pin}%{wiring}"]
;;

let image_of_timed timed ~(chip : Chip_verdict.t) ~data =
  match chip with
  | Refused _ | No_certificate _ -> None
  | Accepted { certificate } ->
    Some
      { Image.config = Timed_program.config timed
      ; words = Timed_program.words timed
      ; certificate
      ; loaded =
          Option.first_some
            (Timed_program.period_floor timed)
            (Timed_program.period timed)
      ; floor = Option.is_some (Timed_program.period_floor timed)
      ; single_edge = Timed_program.single_capture_edge timed
      ; data
      }
;;

let check (job : Job.t) =
  let open Or_error.Let_syntax in
  let%bind parsed = Wavejson.parse job.diagram in
  match Wavedrom.compile ~clock_hz parsed with
  | Error e ->
    let certificate =
      Diagram_mutation.Verdict.to_string
        (Refused (Error.tag e ~tag:("at " ^ Wavedrom.clock_name clock_hz)))
    in
    Ok (Refused { job; certificate })
  | Ok t ->
    let frames = Job.bits job in
    let%bind host_words =
      if t.starts_on_edge
      then Ok []
      else List.map frames ~f:(Wavedrom.host_words t) |> Or_error.all >>| List.concat
    in
    let%bind line = if t.starts_on_edge then Wavedrom.line t frames else Ok [||] in
    let%bind interpreter =
      Tables.check t.table.wiring
      |> Result.map_error ~f:(fun (r : Timed_program.Refusal.t) -> r.error)
    in
    let longest =
      List.sum (module Int) t.steps ~f:(fun s -> s.cycles + Tables.Kind.added s.kind)
    in
    let wanted = Array.length line + (longest * (List.length host_words + 2)) in
    let cycles = Int.min max_cycles wanted in
    let inputs c =
      if Array.is_empty line
      then 0
      else Bool.to_int line.(Int.min c (Array.length line - 1))
    in
    let%bind levels, _, faults = Wavedrom.simulate t ~host_words ~inputs ~cycles in
    let%map data = Tables.words t.table in
    let lanes =
      List.mapi t.outputs ~f:(fun i name ->
        let pin = t.table.wiring.out_base + i in
        { Lane.name; pin; wiring = Bench_wiring.find ~pin })
    in
    let chip = Chip_verdict.of_timed interpreter in
    let image = image_of_timed interpreter ~chip ~data in
    let bench =
      match t.input, image with
      | _, None -> Bench.Declines "the chip's load check refuses the interpreter"
      | Some _, _ ->
        Declines
          [%string
            "it reads %{pin_name t.table.wiring.in_base}, which no peer drives on the \
             bench"]
      | None, Some _ -> bench_for lanes ~host_words ~wanted
    in
    let input =
      match t.input with
      | Some name when t.starts_on_edge -> Some (name, Array.map line ~f:Bool.to_int)
      | _ -> None
    in
    let last = t.table.wiring.out_base + Tables.output_bits - 1 in
    let first_free = t.table.wiring.out_base + List.length lanes in
    let lines =
      [ "certified at " ^ Wavedrom.clock_name clock_hz
      ; Diagram_mutation.Verdict.to_string (Accepted t)
      ; "interpreter: "
        ^ Analyser.Verdict.to_string (Timed_program.verdict interpreter)
        ^ ", certified once with the data memory free"
      ; Chip_verdict.to_string chip
      ; "host words: "
        ^ (List.map host_words ~f:(sprintf "0x%04x") |> String.concat ~sep:" ")
      ; [%string
          "model: %{cycles#Int} cycles at %{Wavedrom.clock_name clock_hz}, faults \
           %{Sexp.to_string (Machine.Fault.sexp_of_t faults)}"]
      ]
      @ List.map lanes ~f:lane_line
      @ (if first_free <= last
         then
           [ [%string "the table holds %{pin_name first_free} to %{pin_name last} low"] ]
         else [])
      @ [ bench_line bench ]
    in
    Certified
      { job
      ; certificate = String.concat ~sep:"\n" lines ^ "\n"
      ; lanes
      ; input
      ; host_words
      ; cycles
      ; levels
      ; faults
      ; image
      ; bench
      }
;;

(* each change of [bit] of [levels], starting from cycle 0's level *)
let edges levels ~bit =
  let level c = (levels.(c) lsr bit) land 1 in
  if Array.is_empty levels
  then []
  else
    [ 0, level 0 ]
    @ List.filter_map
        (List.range 1 (Array.length levels))
        ~f:(fun c -> Option.some_if (level c <> level (c - 1)) (c, level c))
;;

(* the whole data memory, so the walk reads zeros past the certificate on the chip too *)
let padded certificate =
  certificate
  @ List.init ((1 lsl Isa.data_addr_bits) - List.length certificate) ~f:(Fn.const 0)
;;

let edge_list l = Value.List (List.map l ~f:(fun (c, v) -> ints [ c; v ]))

let lane_json (l : Lane.t) =
  Value.Object
    ([ "name", Value.String l.name; "pin", String (pin_name l.pin) ]
     @
     match l.wiring with
     | None -> [ "net", Null; "channel", Null ]
     | Some w -> [ "net", String w.net; "channel", String (channel w) ])
;;

let probe_json (p : Probe.t) =
  Value.Object
    [ "lane", String p.lane
    ; "pin", String p.wiring.name
    ; "analyser", String (analyser_name p.wiring.analyser)
    ; "channel", String (sprintf "D%d" p.wiring.channel)
    ]
;;

let analysers probes =
  List.map probes ~f:(fun (p : Probe.t) -> p.wiring.analyser)
  |> List.dedup_and_sort ~compare:Bench_wiring.Analyser.compare
;;

let firmware_json (image : Image.t) ~probes ~host_words ~run_ms ~faults =
  let fields =
    Engine.Config.map2
      Engine.Config.port_names
      (Engine.Config.of_program_config image.config)
      ~f:(fun name value -> name, int (Bits.to_unsigned_int value))
    |> Engine.Config.to_list
  in
  Value.Object
    [ "config", Object fields
    ; "words", ints image.words
    ; "certificate", ints (padded image.certificate)
    ; "loaded", Option.value_map image.loaded ~default:Value.Null ~f:int
    ; "floor", int (Bool.to_int image.floor)
    ; "single_edge", int (Bool.to_int image.single_edge)
    ; "data", ints image.data
    ; "tx", ints host_words
    ; "run_ms", int run_ms
    ; "faults", int (fault_bits faults)
    ; ( "probes"
      , List
          (List.map probes ~f:(fun (p : Probe.t) ->
             Value.Object
               [ "pin", int p.wiring.pin
               ; "analyser", String (analyser_name p.wiring.analyser)
               ; "channel", int p.wiring.channel
               ])) )
    ]
;;

let files t =
  let file name v = name, json v ^ "\n" in
  match t with
  | Refused { job; certificate } ->
    [ "job.json", Job.to_string job
    ; "certificate.txt", certificate ^ "\n"
    ; file
        "check.json"
        (Object
           [ "verdict", String "refused"
           ; "clock_hz", int clock_hz
           ; "certificate", String certificate
           ])
    ]
  | Certified
      { job; certificate; lanes; input; host_words; cycles; levels; faults; image; bench }
    ->
    let bench_json =
      match bench with
      | Takes { probes; run_ms } ->
        let decode =
          match probes with
          | [] -> Value.Null
          | first :: _ ->
            (match
               Decode.sigrok_args job.decode ~channel:(sprintf "D%d" first.wiring.channel)
             with
             | [] -> Null
             | args ->
               Object
                 [ "analyser", String (analyser_name first.wiring.analyser)
                 ; "args", List (List.map args ~f:(fun a -> Value.String a))
                 ])
        in
        Value.Object
          [ "takes", Bool true
          ; "probes", List (List.map probes ~f:probe_json)
          ; ( "analysers"
            , List
                (List.map (analysers probes) ~f:(fun a -> Value.String (analyser_name a)))
            )
          ; "run_ms", int run_ms
          ; "decode", decode
          ]
      | Declines why -> Object [ "takes", Bool false; "why", String why ]
    in
    let input =
      match input with
      | None -> Value.Null
      | Some (name, line) ->
        Object [ "name", String name; "edges", edge_list (edges line ~bit:0) ]
    in
    [ "job.json", Job.to_string job
    ; "certificate.txt", certificate
    ; file
        "check.json"
        (Object
           [ "verdict", String "certified"
           ; "clock_hz", int clock_hz
           ; "certificate", String certificate
           ; "lanes", List (List.map lanes ~f:lane_json)
           ; "host_words", ints host_words
           ; "cycles", int cycles
           ; "faults", int (fault_bits faults)
           ; "bench", bench_json
           ])
    ; file
        "simulated.json"
        (Object
           [ "clock_hz", int clock_hz
           ; "cycles", int cycles
           ; ( "lanes"
             , List
                 (List.mapi lanes ~f:(fun i l ->
                    Value.Object
                      [ "name", String l.name
                      ; "pin", String (pin_name l.pin)
                      ; "edges", edge_list (edges levels ~bit:i)
                      ])) )
           ; "input", input
           ; "faults", int (fault_bits faults)
           ])
    ]
    @
      (match bench, image with
      | Declines _, _ | _, None -> []
      | Takes { probes; run_ms }, Some image ->
        [ file "firmware.json" (firmware_json image ~probes ~host_words ~run_ms ~faults) ])
;;

let malformed e =
  [ ( "check.json"
    , json
        (Object [ "verdict", String "malformed"; "why", String (Error.to_string_hum e) ])
      ^ "\n" )
  ]
;;
