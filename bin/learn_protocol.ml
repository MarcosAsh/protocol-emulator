open! Core
open Hardcaml
open Protocol_emulator

let bits_string bits =
  Array.to_list bits
  |> List.map ~f:(fun b -> if b then '1' else '0')
  |> String.of_char_list
;;

let config_json config =
  Engine.Config.map2
    Engine.Config.port_names
    (Engine.Config.of_program_config config)
    ~f:(fun name value -> sprintf "%S: %d" name (Bits.to_unsigned_int value))
  |> Engine.Config.to_list
  |> String.concat ~sep:", "
;;

let int_list l = "[" ^ String.concat ~sep:", " (List.map l ~f:Int.to_string) ^ "]"

let pins_of ~pin ~clocked =
  match clocked with
  | None -> Learn_firmware.Pins.Line pin
  | Some (clock, data) -> Clocked { clock; data; deselect = true }
;;

let pin_arg =
  Command.Arg_type.create (fun name ->
    match Int.of_string_opt name with
    | Some pin -> pin
    | None ->
      List.init 28 ~f:Fn.id
      |> List.find ~f:(fun pin -> String.equal (Machine_trace.pin_name pin) name)
      |> Option.value_exn ~message:"no such pin")
;;

let clocked_arg =
  Command.Arg_type.comma_separated pin_arg
  |> Command.Arg_type.map ~f:(function
    | [ clock; data ] -> clock, data
    | _ -> raise_s [%message "CLOCK,DATA"])
;;

(* The firmware, run on the model and read back, then the files the host takes. *)
let speak ~clock_hz ~pins ~value ~repeat ~out (learned : Learn.t) =
  let open Or_error.Let_syntax in
  let%bind field, message = Learn.new_message ?value learned in
  printf
    "new message: kind %d, field bits %d..%d = %d (seen %s), bits %s\n"
    message.kind
    field.first
    (field.first + field.width - 1)
    (Learn.field_value learned field message.bits)
    (String.concat ~sep:" " (List.map field.seen ~f:Int.to_string))
    (bits_string message.bits);
  let%bind firmware = Learn_firmware.generate ~clock_hz ~pins learned in
  let verdict = Timed_program.verdict firmware.timed in
  printf
    "firmware: %s, period %d cycles x %d a unit\n\
     kernel: accepted, so no deadline is missed by the step lemma\n"
    (Analyser.Verdict.to_string verdict)
    firmware.period
    firmware.ticks;
  let frames = List.init repeat ~f:(fun _ -> message.kind, message.bits) in
  let%bind simulated = Learn_firmware.simulate ~clock_hz ~pins firmware learned frames in
  Core_unix.mkdir_p out;
  Out_channel.write_all (out ^/ "learned.txt") ~data:(Learn.to_string learned);
  Out_channel.write_all (out ^/ "firmware.asm") ~data:firmware.source;
  Out_channel.write_all (out ^/ "model.edges") ~data:(Recording.to_string simulated);
  let%bind read = Learn.decode learned simulated in
  let sent =
    List.map frames ~f:(fun (kind, bits) -> kind, Learn.with_checks learned ~kind bits)
  in
  let got = List.map read ~f:(fun (f : Learn.Frame.t) -> f.kind, f.bits) in
  let show l = List.map l ~f:(fun (k, b) -> k, bits_string b) in
  let%map () =
    if [%equal: (int * bool array) list] sent got
    then (
      printf "model: sends the %d frames, read back with what was learned\n" repeat;
      return ())
    else
      Or_error.error_s
        [%message
          "the model's frames read back otherwise"
            ~sent:(show sent : (int * string) list)
            ~got:(show got : (int * string) list)]
  in
  let frame_json (kind, bits) =
    sprintf
      "{\"kind\": %d, \"bits\": %S, \"words\": %s}"
      kind
      (bits_string (Learn.with_checks learned ~kind bits))
      (int_list (Learn_firmware.words firmware learned ~kind bits))
  in
  Out_channel.write_all
    (out ^/ "send.json")
    ~data:
      (sprintf
         "{\"config\": {%s},\n\
         \ \"words\": %s,\n\
         \ \"period\": %d,\n\
         \ \"unit_us\": %.3f,\n\
         \ \"gap\": %d,\n\
         \ \"slack\": %s,\n\
         \ \"frames\": [%s]}\n"
         (config_json (Timed_program.config firmware.timed))
         (int_list (Timed_program.words firmware.timed))
         firmware.period
         (learned.unit_s *. 1e6)
         learned.gap
         (Option.value_map verdict.worst_slack ~default:"null" ~f:Int.to_string)
         (String.concat ~sep:",\n  " (List.map frames ~f:frame_json)))
;;

let command =
  Command.basic
    ~summary:"Learn the protocol of a recording, and write firmware that speaks it"
    ~readme:(fun () ->
      "Prints what was learned, or why it cannot say. With -out, also writes firmware \
       for one engine that sends a message the recording never held, checked by the \
       analyser and the kernel, run on the model and read back with what was learned, \
       and send.json for the host: config, words, period and the frames' words.")
    [%map_open.Command
      let file = anon ("RECORDING" %: string)
      and lines =
        flag "-line" (listed string) ~doc:"NAME a line to read, every one by default"
      and out =
        flag "-out" (optional string) ~doc:"DIR write the firmware and send.json there"
      and pin =
        flag
          "-pin"
          (optional_with_default 5 pin_arg)
          ~doc:"PIN the output, OUT0 by default"
      and clocked =
        flag
          "-clocked"
          (optional clocked_arg)
          ~doc:
            "CLOCK,DATA output pins for a clocked protocol; the pin after CLOCK held high"
      and value = flag "-value" (optional int) ~doc:"N the new message's field value"
      and repeat =
        flag "-repeat" (optional_with_default 2 int) ~doc:"N times the host sends it (2)"
      and clock_hz =
        flag "-clock-hz" (optional_with_default 48e6 float) ~doc:"HZ the chip's clock"
      in
      fun () ->
        let result =
          let%bind.Or_error recording = Recording.of_string (In_channel.read_all file) in
          let%bind.Or_error learned =
            Learn.learn
              ?lines:(Option.some_if (not (List.is_empty lines)) lines)
              recording
          in
          print_string (Learn.to_string learned);
          match out with
          | None -> Ok ()
          | Some out ->
            speak ~clock_hz ~pins:(pins_of ~pin ~clocked) ~value ~repeat ~out learned
        in
        match result with
        | Ok () -> ()
        | Error e ->
          printf "%s\n" (Error.to_string_hum e);
          exit 1]
;;
