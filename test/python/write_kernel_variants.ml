open! Core
open Protocol_emulator
open Protocol_emulator_test

(* Every delay variant of the swept firmware as a JSON line, for demo/kernel_vs_board.py
   to run on the board: its words, the analyser's and the kernel's verdicts, and whether
   the model ran it late. *)

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

let print_variant (t : Delay_variants.t) (v : Delay_variants.Variant.t) =
  let { Delay_variants.Model.fault; moved } = force v.model in
  let fault =
    if Machine.Fault.equal fault Machine.Fault.none
    then "none"
    else Sexp.to_string [%sexp (fault : Machine.Fault.t)]
  in
  printf
    "{\"firmware\": %s, \"k\": %d, \"slack\": %d, \"wait_pc\": %d, \"words\": %s, \
     \"analyser\": %s, \"kernel\": %s, \"rejections\": %s, \"accepted\": %b, \
     \"model_fault\": %s, \"model_moved\": %b, \"model_late\": %b}\n"
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
;;

let () =
  List.iter Library.swept ~f:(fun swept ->
    let t = Delay_variants.of_swept swept in
    List.iter (Delay_variants.every t) ~f:(print_variant t))
;;
