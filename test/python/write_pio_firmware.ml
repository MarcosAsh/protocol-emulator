open! Core
open Hardcaml
open Protocol_emulator
open Pio

(* Each bench run: the upstream path, the program, and the PIO tx words of its data, as
   its example's C code writes them. *)
module Run = struct
  type t =
    { name : string
    ; upstream : string
    ; program : string
    ; data : string (** A Python literal, for the demo to show. *)
    ; pio_words : int list list
    }
end

let commit = "0d62f75bafc2c8120d3276c3343d1a9195e909e9"
let dir = "../../pio/test/pico_examples/"

(* demo_neopixel's pixels, low enough that USB powers the stick, then turned by one *)
let pixels =
  [ 0x20, 0x00, 0x00
  ; 0x00, 0x20, 0x00
  ; 0x00, 0x00, 0x20
  ; 0x20, 0x20, 0x00
  ; 0x00, 0x20, 0x20
  ; 0x20, 0x00, 0x20
  ; 0x12, 0x34, 0x56
  ; 0x01, 0x02, 0x04
  ]
;;

let frames = [ pixels; List.tl_exn pixels @ [ List.hd_exn pixels ] ]

(* ws2812.c's put_pixel (urgb_u32 (r, g, b)): green, red, blue from bit 31 *)
let grb (r, g, b) = ((g lsl 16) lor (r lsl 8) lor b) lsl 8

(* uart_tx.c's string; uart_tx_program_putc puts each character as a word *)
let hello = "Hello, world! (from PIO!)\r\n"

(* W25Q64JV's Release Power-down, ABh, which it needs 3 us after, then Read JEDEC ID, 9Fh,
   and three bytes for the reply *)
let commands = [ [ 0xab ]; [ 0x9f; 0; 0; 0 ] ]

let runs =
  [ { Run.name = "WS2812"
    ; upstream = "pio/ws2812/ws2812.pio"
    ; program = "ws2812"
    ; data =
        List.map frames ~f:(fun frame ->
          List.map frame ~f:(fun (r, g, b) -> sprintf "(0x%02x, 0x%02x, 0x%02x)" r g b)
          |> String.concat ~sep:", "
          |> sprintf "        [%s],\n")
        |> String.concat
        |> sprintf "[\n%s    ]"
    ; pio_words = List.map frames ~f:(List.map ~f:grb)
    }
  ; { name = "UART_TX"
    ; upstream = "pio/uart_tx/uart_tx.pio"
    ; program = "uart_tx"
    ; data = sprintf "%S" hello
    ; pio_words = [ String.to_list hello |> List.map ~f:Char.to_int ]
    }
  ; { name = "SPI"
    ; upstream = "pio/spi/spi.pio"
    ; program = "spi_cpha0_cs"
    ; data =
        List.map commands ~f:(fun command ->
          List.map command ~f:(sprintf "0x%02x")
          |> String.concat ~sep:", "
          |> sprintf "[%s]")
        |> String.concat ~sep:", "
        |> sprintf "[%s]"
        (* 8-bit frames shifted left: pio_spi_write8_blocking writes each byte to the
           fifo's top byte *)
    ; pio_words = List.map commands ~f:(List.map ~f:(fun b -> b lsl 24))
    }
  ]
;;

let sha256 =
  let sums =
    In_channel.read_lines (dir ^ "SHA256SUMS")
    |> List.map ~f:(fun line ->
      match String.split line ~on:' ' |> List.filter ~f:(Fn.non String.is_empty) with
      | [ hash; file ] -> file, hash
      | _ -> raise_s [%message "BUG: SHA256SUMS line" line])
  in
  fun file -> List.Assoc.find_exn sums file ~equal:String.equal
;;

let words_lines words =
  List.chunks_of words ~length:8
  |> List.iter ~f:(fun chunk ->
    printf
      "        %s,\n"
      (String.concat ~sep:", " (List.map chunk ~f:(sprintf "0x%04X"))))
;;

let () =
  printf
    "# Written by test/python/write_pio_firmware.ml; `dune promote` after a change.\n\
     # Raspberry Pi's pico-examples PIO programs at COMMIT, byte for byte (SHA256SUMS in\n\
     # pio/test/pico_examples), as `pio_import -carrier` translates and certifies them: \
     the\n\
     # words, the configuration they run under on the carrier's pins, the kernel's \
     verdict,\n\
     # and each demo's data as the host words the translation takes in place of the \
     PIO's.\n\n\
     COMMIT = %S\n"
    commit;
  List.iter runs ~f:(fun run ->
    let file = Filename.basename run.upstream in
    let program =
      In_channel.read_all (dir ^ file)
      |> Pioasm.parse
      |> ok_exn
      |> List.find_exn ~f:(fun (p : Pioasm.Program.t) -> String.equal p.name run.program)
    in
    let carrier = Option.value_exn (Carrier.find program) in
    let t, timed =
      match Census.certify ~place:carrier.place program ~k:carrier.k with
      | Ok certified -> certified
      | Error verdict -> raise_s [%sexp (verdict : Census.Verdict.t)]
    in
    if List.exists (Census.limits program timed) ~f:(Fn.non Census.Limit.ok)
    then raise_s [%message "BUG: a bench run fails a limit" run.program];
    let verdict = Timed_program.verdict timed in
    let setup = Census.setup program ~period:2 in
    let fields =
      Engine.Config.map2
        Engine.Config.port_names
        (Engine.Config.of_program_config (Timed_program.config timed))
        ~f:(fun name value -> name, Bits.to_unsigned_int value)
      |> Engine.Config.to_list
    in
    printf "\n# k for %s\n%s = {\n" carrier.why run.name;
    printf "    \"file\": %S,\n" run.upstream;
    printf "    \"sha256\": %S,\n" (sha256 file);
    printf "    \"program\": %S,\n" run.program;
    printf "    \"k\": %s,\n" (Float.to_string_hum ~decimals:4 ~strip_zero:true carrier.k);
    printf "    \"deadline_waits\": %d,\n" verdict.deadline_waits;
    printf
      "    \"worst_slack\": %s,\n"
      (Option.value_map verdict.worst_slack ~default:"None" ~f:Int.to_string);
    print_string "    \"contract\": [\n";
    List.iter t.contract ~f:(printf "        %S,\n");
    print_string "    ],\n    \"config\": {\n";
    List.iter fields ~f:(fun (field, value) -> printf "        \"%s\": %d,\n" field value);
    print_string "    },\n    \"words\": [\n";
    words_lines (Timed_program.words timed);
    printf "    ],\n    \"data\": %s,\n    \"tx\": [\n" run.data;
    List.iter run.pio_words ~f:(fun piece ->
      print_string "      [\n";
      words_lines (List.concat_map piece ~f:(Translate.tx_words setup t));
      print_string "      ],\n");
    print_string "    ],\n}\n")
;;
