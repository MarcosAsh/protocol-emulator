open! Core
open Protocol_emulator

(* What sigrok-cli prints, or nothing when it is missing or fails. *)
let sigrok_cli args =
  let command =
    String.concat ~sep:" " ("sigrok-cli" :: List.map args ~f:Filename.quote)
    ^ " 2>/dev/null"
  in
  match Core_unix.open_process_in command with
  | exception _ -> None
  | channel ->
    let output = In_channel.input_all channel in
    (match Core_unix.close_process_in channel with
     | Ok () -> Some output
     | Error _ -> None)
;;

(* The lines under a heading of sigrok-cli's, up to the next line without an indent. *)
let section output ~heading =
  String.split_lines output
  |> List.drop_while ~f:(fun line -> not (String.equal line heading))
  |> (fun lines -> List.drop lines 1)
  |> List.take_while ~f:(fun line ->
    String.is_prefix line ~prefix:" " || String.is_prefix line ~prefix:"-")
;;

let alphanumeric s = String.filter (String.lowercase s) ~f:Char.is_alphanum

(* sigrok's decoders whose id or name holds a word of the protocol's name, or the other
   way round, those that match more of it first *)
let candidates name =
  let words =
    String.split name ~on:'_'
    |> List.map ~f:alphanumeric
    |> List.filter ~f:(fun word -> String.length word >= 2)
  in
  let matches id long_name word =
    let id = alphanumeric id in
    String.is_substring id ~substring:word
    || String.is_substring (alphanumeric long_name) ~substring:word
    || (String.length id >= 2 && String.is_substring word ~substring:id)
  in
  Option.value_map
    (sigrok_cli [ "-L" ])
    ~default:[]
    ~f:(section ~heading:"Supported protocol decoders:")
  |> List.filter_map ~f:(fun line ->
    let%bind.Option id, long_name = String.lsplit2 (String.strip line) ~on:' ' in
    let long_name = String.strip long_name in
    let score =
      List.count words ~f:(matches id long_name)
      + if String.equal id name then List.length words + 1 else 0
    in
    Option.some_if (score > 0) (score, (id, long_name)))
  |> List.stable_sort ~compare:(fun (a, _) (b, _) -> Int.compare b a)
  |> List.map ~f:snd
;;

module Decoder = struct
  type t =
    { id : string
    ; channels : string list
    ; optional_channels : string list
    ; options : string list
    ; classes : string list
    }

  (* the id before the first space or colon of each "- id ..." line *)
  let ids lines =
    List.filter_map lines ~f:(fun line ->
      String.chop_prefix line ~prefix:"- "
      |> Option.map ~f:(fun rest ->
        String.take_while rest ~f:(fun c -> not (Char.equal c ' ' || Char.equal c ':'))))
  ;;

  let show id =
    Option.map
      (sigrok_cli [ "-P"; id; "--show" ])
      ~f:(fun output ->
        let ids heading = ids (section output ~heading) in
        { id
        ; channels = ids "Required channels:"
        ; optional_channels = ids "Optional channels:"
        ; options = ids "Options:"
        ; classes = ids "Annotation classes:"
        })
  ;;

  let unknown =
    { id = "TODO"
    ; channels = [ "TODO" ]
    ; optional_channels = []
    ; options = []
    ; classes = []
    }
  ;;
end

(* [protocol_ml]'s [pin], OUT0, and the pins its decoder's channels take, one on from it *)
let default_pin = 5

let channels_of (decoder : Decoder.t) =
  match decoder.channels, decoder.optional_channels with
  | [], first :: _ -> [ first ]
  | channels, _ -> channels
;;

let pin_name pin =
  match Bench_wiring.find ~pin with
  | Some { name; _ } -> name
  | None when pin < Isa.first_output_pin -> [%string "IN%{pin#Int}"]
  | None when pin < Isa.first_bidir_pin ->
    [%string "OUT%{pin - Isa.first_output_pin#Int}"]
  | None -> [%string "IO%{pin - Isa.first_bidir_pin#Int}"]
;;

(* The analyser and each channel's Dn from Bench_wiring, "TODO" where there is none or the
   pins reach both analysers, and why for the line under the outside: one. *)
let wiring channels =
  let found =
    List.mapi channels ~f:(fun i _ -> Bench_wiring.find ~pin:(default_pin + i))
  in
  let analysers =
    List.filter_map found ~f:(Option.map ~f:(fun (w : Bench_wiring.t) -> w.analyser))
    |> List.dedup_and_sort ~compare:Bench_wiring.Analyser.compare
  in
  let analyser, usable =
    match analysers with
    | [ a ] ->
      Some a, fun (w : Bench_wiring.t) -> Bench_wiring.Analyser.compare w.analyser a = 0
    | _ -> None, fun _ -> false
  in
  let channel i =
    match List.nth_exn found i with
    | Some w when usable w -> [%string "D%{w.channel#Int}"]
    | Some _ | None -> "TODO"
  in
  let why =
    List.filter_mapi found ~f:(fun i w ->
      let pin = pin_name (default_pin + i) in
      match w with
      | None -> Some [%string "%{pin} has no analyser channel"]
      | Some w when not (usable w) -> Some [%string "%{pin} is on the other analyser"]
      | Some _ -> None)
  in
  let analyser =
    match analyser with
    | Some Bench_wiring.Analyser.A -> "A"
    | Some Bench_wiring.Analyser.B -> "B"
    | None -> "TODO"
  in
  analyser, List.mapi channels ~f:(fun i _ -> channel i), why
;;

let substitute template ~name ~(decoder : Decoder.t) =
  (* a decoder whose channels are all optional, as uart's, gets its first *)
  let channels = channels_of decoder in
  let analyser, wired, why = wiring channels in
  let outside =
    List.map2_exn channels wired ~f:(fun channel d -> [%string "%{channel}=%{d}"])
    |> String.concat ~sep:":"
  in
  let outside_note =
    if List.is_empty why
    then ""
    else [%string "# TODO outside: %{String.concat ~sep:\"; \" why}, see Bench_wiring\n"]
  in
  let pins =
    List.mapi channels ~f:(fun i channel ->
      if i = 0
      then [%string {|"%{channel}", pin|}]
      else [%string {|"%{channel}", pin + %{i#Int} (* TODO *)|}])
    |> String.concat ~sep:"; "
  in
  let list = function
    | [] -> "none"
    | l -> String.concat ~sep:", " l
  in
  List.fold
    [ "__MODULE__", String.capitalize name
    ; "__UPPER__", String.uppercase name
    ; "__NAME__", name
    ; "__DECODER__", decoder.id
    ; "__ANALYSER__", analyser
    ; "__OUTSIDE__", outside
    ; "__OUTSIDE_NOTE__", outside_note
    ; "__PINS__", pins
    ; "__CHANNELS__", list decoder.channels
    ; "__OPTIONAL__", list decoder.optional_channels
    ; "__OPTIONS__", list decoder.options
    ; "__CLASSES__", list decoder.classes
    ]
    ~init:template
    ~f:(fun text (pattern, with_) -> String.substr_replace_all text ~pattern ~with_)
;;

let protocol_mli =
  {|(** __NAME__, TODO: what it is and the spec this file follows, with its revision. *)

open! Core
open Protocol_emulator

(** The line the firmware drives. *)
val pin : int

val config : Program_config.t

(** Checked by the kernel when this file compiles. *)
val firmware : Timed_program.t

val scenario : Pin_trace.Scenario.t
val protocol : Protocol.t
|}
;;

let protocol_ml =
  {ocaml|open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* TODO the spec: the document with its revision, and the table the timing comes from *)

(* TODO the pins: OUT0 is 5, IO0 is 12 (Isa.first_bidir_pin), Bench names the bench's *)
let pin = 5

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  }
;;

(* TODO the firmware. This placeholder idles the line high and sends the low byte of each
   host word LSB first, 16 cycles a bit. [%firmware] runs the analyser and the kernel when
   this file compiles, so a deadline it can miss fails the build at its line. *)
let firmware =
  [%firmware
    {|
    set p, 16
    set pins, 1              ; idle high
idle:
    wait tx
    pull
    set x, 7
    mov t, now               ; anchor: the first bit a period from here
    add t, p
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; idle again a period after the last bit
    jmp idle
|}
      ~config]
;;

(* TODO the certificates, under the assumptions [%firmware] checked: give ~period, the
   period the host loads, to firmware checked at a ~period_floor, and ~no_wrap:true where
   a wait can fall far behind, as a receiver's can *)
let certified = [ Certified.of_firmware "__NAME__" firmware ]

(* TODO the copy python/bench_firmware.py holds for the bench, at its clock, with a run
   long enough to bound [limits]; for a period the host loads, [Floor] the least and
   [load] the one the bench loads *)
let bench =
  { Bench.name = "__NAME__"
  ; what = "__MODULE__.firmware: TODO what the bench sees, on OUT0"
  ; source = Timed_program.source firmware
  ; config
  ; assumption = Nothing
  ; clock_hz = Bench.clock_hz
  ; load = None
  ; stimulus = Some { bursts = [ [ 0x55 ] ]; quiet = 0; cycles = 400 }
  }
;;

(* TODO a row for each parameter of the spec's timing table, then [unlimited] empty. Each
   is bounded by the kernel over every path, [Datasheet.level] or [Datasheet.spacing], or
   by [bench]'s run, [Datasheet.run], which a loop of waits needs as the kernel counts one
   pass of it. For example
   { Datasheet.firmware = bench.name
   ; parameter = "tLOW"
   ; limit = At_least 4700.
   ; sheet = { part = "I2C"; document = "NXP UM10204 Rev. 7.0"; page = "Table 10" }
   ; margin = Cycle
   ; bound = Datasheet.level ~pin:Datasheet.set_pin ~high:false ()
   } *)
let limits : Datasheet.t list = []

(* TODO what sigrok's __DECODER__ decoder reads. demo/decode.py --show
   test/traces/__NAME__.trace prints every line it reads, by class, to fill [expect]
   with. Its channels: __CHANNELS__; optional: __OPTIONAL__; options: __OPTIONS__;
   classes: __CLASSES__. Each of [teeth] changes the waveform so the decoders have to
   misread it. *)
let sigrok =
  { Sigrok.clock_hz = 48_000_000
  ; decoders = [ Sigrok.decoder "__DECODER__" ~pins:[ __PINS__ ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

(* TODO a run at the pins: the host's words, and in [peer] a model of the far end if it
   answers *)
let scenario =
  { Scenario.name = "__NAME__"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Write (Reg.tx, [ 0x55; 0xa3 ]); Scenario.start; Run 600 ]
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "__NAME__"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = [ "__NAME__", "TODO the rows of the spec's timing table" ]
  ; swept = []
  ; not_swept = [ "__NAME__", "TODO why the sweep does not stamp it, or a Swept.t" ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
|ocaml}
;;

let test_ml =
  {ocaml|open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict __MODULE__.firmware));
  [%expect {| |}]
;;

(* The line, level by level with the cycles each lasted, for one host word: what to hold
   against the spec's timing diagram. TODO a model of the far end, fed the pins every
   cycle, that reads back what the host sent. *)
let%expect_test "the line for one host word" =
  let machine =
    Machine.create
      ~config:(Timed_program.config __MODULE__.firmware)
      ~program:(Timed_program.words __MODULE__.firmware)
    |> ok_exn
  in
  let machine = Machine.write_tx machine 0x55 |> ok_exn in
  let levels =
    List.folding_map (List.range 0 400) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      machine, (machine.pin_out lsr __MODULE__.pin) land 1 = 1)
  in
  let runs =
    List.group levels ~break:Bool.( <> )
    |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  in
  print_s [%message (runs : (bool * int) list)];
  [%expect {| |}]
;;
|ocaml}
;;

let empty_mli = "(*_ This signature is deliberately empty. *)\n"

let demo_py =
  {|# SPDX-License-Identifier: Apache-2.0
# TODO what this shows on the bench, and what is wired to which pin (MicroPython, Pico A).
# demo/outside.sh __NAME__ runs it, reading the analyser, the capture's length and
# sigrok's decoders from the next line.
# outside: analyser=__ANALYSER__ ms=2000 decode=-P __DECODER__:__OUTSIDE__
__OUTSIDE_NOTE__
import bench
import bench_firmware
import protocol_emulator as pe

# TODO the words the firmware takes
WORDS = [0x55, 0xA3]


def run(transfer, log=print):
    host = pe.Host(transfer)
    bench.load(host, bench_firmware.__UPPER__)
    host.start()
    host.push(WORDS)
    # TODO read back what the far end answered, and judge it
    found = bench.faults(host)
    log("faults 0x%x" % found)
    return not found


if __name__ == "__main__":
    import time

    import pico_board

    log = bench.Log()
    spi = pico_board.PicoSpi()
    time.sleep_ms(bench.START_MS)
    bench.report(lambda: run(spi.transfer, log), log)
|}
;;

(* [name] at the end of [Library.protocols], before the bracket that closes it *)
let add_to_library ~root name =
  let path = root ^/ "test/library.ml" in
  let text = In_channel.read_all path in
  let entry = String.capitalize name ^ ".protocol" in
  let from =
    match String.substr_index text ~pattern:"let protocols" with
    | Some at -> at
    | None -> raise_s [%message "no [let protocols] in" path]
  in
  match String.substr_index text ~pos:from ~pattern:"\n  ]" with
  | None -> raise_s [%message "no end to the list of protocols in" path]
  | Some at ->
    if String.is_substring (String.sub text ~pos:from ~len:(at - from)) ~substring:entry
    then raise_s [%message "already in the library" entry];
    Out_channel.write_all
      path
      ~data:
        (String.prefix text at ^ [%string "\n  ; %{entry}"] ^ String.drop_prefix text at)
;;

(* a row for [name] in test_tables.ml's table of which protocols the table interpreter
   runs, which has to name every protocol; false if the table is not where it was *)
let add_to_tables ~root name =
  let path = root ^/ "test/test_tables.ml" in
  let text = In_channel.read_all path in
  match
    String.substr_index text ~pattern:"\n    ]\n  in\n  let named = List.map rows"
  with
  | None -> false
  | Some at ->
    Out_channel.write_all
      path
      ~data:
        (String.prefix text at
         ^ [%string
             {|
    ; "%{name}", "TODO", "-", "-", "TODO whether the table interpreter runs it"|}]
         ^ String.drop_prefix text at);
    true
;;

(* the files written, formatted as the repository's .ocamlformat asks, if ocamlformat is
   on the PATH *)
let format ~root files =
  let files =
    List.filter files ~f:(fun file ->
      String.is_suffix file ~suffix:".ml" || String.is_suffix file ~suffix:".mli")
    |> List.map ~f:(fun file -> Filename.quote (root ^/ file))
  in
  match
    Core_unix.system
      [%string "ocamlformat -i %{String.concat ~sep:\" \" files} 2>/dev/null"]
  with
  | Ok () | Error _ -> ()
;;

(* modules a test file opens or names, which a protocol of that name would shadow *)
let taken =
  [ "array"
  ; "bench"
  ; "bits"
  ; "bool"
  ; "bytes"
  ; "char"
  ; "command"
  ; "datasheet"
  ; "float"
  ; "int"
  ; "library"
  ; "list"
  ; "map"
  ; "option"
  ; "protocol"
  ; "result"
  ; "scope"
  ; "set"
  ; "signal"
  ; "string"
  ; "sys"
  ; "time"
  ]
;;

let check_name ~root name =
  if not
       (String.length name > 0
        && Char.is_lowercase name.[0]
        && String.for_all name ~f:(fun c ->
          Char.is_lowercase c || Char.is_digit c || Char.equal c '_'))
  then raise_s [%message "a protocol's name is lowercase letters, digits and _" name];
  if List.mem taken name ~equal:String.equal
  then raise_s [%message "a module the tests use already has that name" name];
  List.iter
    [ "test" ^/ name ^ ".ml"
    ; "test" ^/ "test_" ^ name ^ ".ml"
    ; "src" ^/ name ^ ".ml"
    ; "python" ^/ "demo_" ^ name ^ ".py"
    ]
    ~f:(fun file ->
      if Sys_unix.file_exists_exn (root ^/ file)
      then raise_s [%message "already there" file])
;;

(* each pin the scaffold's firmware and decoder use, with its analyser channel and the
   rest of its net, for step 10 *)
let nets ~channels =
  List.mapi channels ~f:(fun i channel ->
    let pin = default_pin + i in
    match Bench_wiring.find ~pin with
    | Some w ->
      let analyser = Sexp.to_string (Bench_wiring.Analyser.sexp_of_t w.analyser) in
      [%string
        "              %{w.name} (%{channel}): analyser %{analyser} D%{w.channel#Int}, \
         %{w.net}\n"]
    | None ->
      [%string
        "              %{pin_name pin} (%{channel}): no analyser channel, no free one\n"])
  |> String.concat
;;

let checklist ~name ~channels =
  let nets = nets ~channels in
  [%string
    {|Next, from the repository's root, with the OxCaml switch and oss-cad-suite on PATH:

 1. spec      open the spec at its timing table; note its title, revision and table
 2. firmware  replace the placeholder in test/%{name}.ml: a build runs the kernel on it and
              fails at the line it refuses; the first test prints the verdict
                dune build --root . 2>&1 | grep -A12 %{name}
                test/only.sh test_%{name}.ml
 3. model     a model of the far end in test/test_%{name}.ml, then its output and the
              library's, which lists the certificate, limits, lockstep and decode
                test/only.sh test_%{name}.ml test_protocol.ml
                test/only.sh -promote test_%{name}.ml test_protocol.ml
 4. limits    a row a parameter of the spec's table in [limits], [unlimited] emptied,
              then step 3 again
 5. trace     the run at the pins: twice, as the first adds the trace's rule
                dune build --root . @test/traces/runtest; dune promote --root .
                dune build --root . @test/traces/runtest; dune promote --root .
 6. sigrok    what the decoders read, into [expect], then the check
                python3 demo/decode.py --show test/traces/%{name}.trace
                python3 demo/decode.py test/traces/%{name}.trace
 7. certify   the inductive certificate, its teeth failing as they must (minutes)
                make -C formal inductive_certificate NAME=%{name}
 8. the rest  the row in test/test_tables.ml, then every test and output the library
              feeds, a fix rerun before it is promoted; CI runs the whole of runtest
                test/only.sh -library test_%{name}.ml
                test/only.sh -promote -library test_%{name}.ml
                dune build --root . @test/python/runtest; dune promote --root .
 9. todo      grep -n TODO test/%{name}.ml test/test_%{name}.ml python/demo_%{name}.py
                grep -n '"%{name}"' test/test_tables.ml
10. bench     the outside: line is filled from Bench_wiring for the pins above; check it
              against the pins you moved to, then
                PICO=id:<serial of Pico A> demo/outside.sh %{name}
              the pins now, with the rest of each net:
%{nets}|}]
;;

let command =
  Command.basic
    ~summary:"Start a protocol's file from a template, with its test and bench script"
    ~readme:(fun () ->
      "Writes test/NAME.ml and .mli, test/test_NAME.ml and .mli and python/demo_NAME.py, \
       and adds NAME to Library.protocols. The firmware is a placeholder the kernel \
       accepts, so the library builds and its tests run from the start. Without \
       -decoder, sigrok-cli's decoders are searched for NAME.")
    [%map_open.Command
      let name = anon ("NAME" %: string)
      and decoder =
        flag
          "-decoder"
          (optional string)
          ~doc:"ID sigrok's decoder for the line, as sigrok-cli -L lists it"
      and root =
        flag
          "-root"
          (optional_with_default "." string)
          ~doc:"DIR the repository (default: .)"
      in
      fun () ->
        check_name ~root name;
        let found = candidates name in
        let id =
          match decoder, found with
          | Some id, _ -> Some id
          | None, (id, _) :: _ -> Some id
          | None, [] -> None
        in
        let decoder =
          Option.bind id ~f:Decoder.show |> Option.value ~default:Decoder.unknown
        in
        if Option.is_some id && String.equal decoder.id "TODO"
        then raise_s [%message "sigrok-cli has no such decoder" (id : string option)];
        let write path template =
          Out_channel.write_all (root ^/ path) ~data:(substitute template ~name ~decoder);
          path
        in
        let written =
          [ write ("test" ^/ name ^ ".mli") protocol_mli
          ; write ("test" ^/ name ^ ".ml") protocol_ml
          ; write ("test" ^/ "test_" ^ name ^ ".mli") empty_mli
          ; write ("test" ^/ "test_" ^ name ^ ".ml") test_ml
          ; write ("python" ^/ "demo_" ^ name ^ ".py") demo_py
          ]
        in
        format ~root written;
        add_to_library ~root name;
        printf
          "wrote %s, and added %s.protocol to test/library.ml\n"
          (String.concat ~sep:", " written)
          (String.capitalize name);
        if add_to_tables ~root name
        then printf "added a TODO row for %s to test/test_tables.ml\n" name
        else printf "test/test_tables.ml needs a row for %s by hand\n" name;
        (match found with
         | [] ->
           printf "sigrok: no decoder's name holds %s, so -decoder ID picks one\n" name
         | found ->
           printf
             "sigrok decoders by name: %s\n"
             (String.concat
                ~sep:", "
                (List.map found ~f:(fun (id, long_name) ->
                   [%string "%{id} (%{long_name})"]))));
        printf
          "sigrok: %s, channels %s, classes %s\n\n%s"
          decoder.id
          (String.concat ~sep:" " decoder.channels)
          (String.concat ~sep:" " decoder.classes)
          (checklist ~name ~channels:(channels_of decoder))]
;;
