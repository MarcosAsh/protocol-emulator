open! Core
open Protocol_emulator
open Protocol_emulator_test

(* Every delay variant of the swept firmware as a JSON line, for demo/kernel_vs_board.py
   to run on the board: its words, the analyser's and the kernel's verdicts, whether the
   model ran it late, and the certificate a host makes for it from the analyser's rows,
   with what the model of the chip's walk says of it. *)

let json_string s =
  let escaped =
    String.concat_map s ~f:(function
      | '"' -> "\\\""
      | '\\' -> "\\\\"
      | '\n' -> "\\n"
      | c when Char.to_int c < 0x20 -> sprintf "\\u%04x" (Char.to_int c)
      | c -> String.of_char c)
  in
  "\"" ^ escaped ^ "\""
;;

let json_list f items = "[" ^ String.concat ~sep:", " (List.map items ~f) ^ "]"

let verdict = function
  | Ok () -> json_string "accepted"
  | Error e -> json_string ("refused: " ^ Error.to_string_hum e)
;;

let rejection { Kernel.Rejection.pc; fails } =
  let fails = String.concat ~sep:", " fails in
  json_string [%string "pc %{pc#Int}: %{fails}"]
;;

(* What the host writes to the data memory for the chip to check [v] against, and the
   walk's verdict as the chip would give it. *)
let chip (t : Delay_variants.t) (v : Delay_variants.Variant.t) =
  let single_capture_edge = t.certified.single_capture_edge in
  let instructions =
    List.map v.words ~f:(fun w ->
      Isa.of_word ~side_set_count:v.config.side_set_count w |> ok_exn)
  in
  let table =
    Analyser.analyse
      ?period:t.swept.period
      ~single_capture_edge
      ~config:v.config
      instructions
    |> Kernel.Table.of_analyser
  in
  match Load_check.of_table ~config:v.config ~words:v.words table with
  | Error e -> "null", json_string ("no certificate: " ^ Error.to_string_hum e)
  | Ok certificate ->
    let words = Array.of_list (Load_check.to_words certificate) in
    let memory at = if at < Array.length words then words.(at) else 0 in
    let walked =
      Load_check.walk
        ?loaded:t.swept.period
        ~single_capture_edge
        ~config:v.config
        ~words:v.words
        ~memory
        ~base:0
        ()
    in
    ( json_list Int.to_string (Array.to_list words)
    , (match walked with
       | Ok _ -> json_string "accepted"
       | Error { pc; reason } -> json_string [%string "refused: pc %{pc#Int}: %{reason}"])
    )
;;

let print_variant (t : Delay_variants.t) (v : Delay_variants.Variant.t) =
  let { Delay_variants.Model.fault; moved } = force v.model in
  let certificate, walked = chip t v in
  let fault =
    if Machine.Fault.equal fault Machine.Fault.none
    then "none"
    else Sexp.to_string [%sexp (fault : Machine.Fault.t)]
  in
  printf
    "{\"firmware\": %s, \"k\": %d, \"slack\": %d, \"wait_pc\": %d, \"words\": %s, \
     \"analyser\": %s, \"kernel\": %s, \"rejections\": %s, \"accepted\": %b, \
     \"model_fault\": %s, \"model_moved\": %b, \"model_late\": %b, \"certificate\": %s, \
     \"chip_model\": %s}\n"
    (json_string t.swept.name)
    v.k
    t.slack
    t.wait_pc
    (json_list Int.to_string v.words)
    (verdict v.analyser)
    (verdict v.kernel)
    (json_list rejection v.rejections)
    (Delay_variants.Variant.accepted v)
    (json_string fault)
    moved
    (Delay_variants.Variant.late v)
    certificate
    walked
;;

let () =
  List.iter Swept.all ~f:(fun swept ->
    let t = Delay_variants.of_swept swept in
    List.iter (Delay_variants.every t) ~f:(print_variant t))
;;
