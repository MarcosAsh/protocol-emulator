open! Core
open Protocol_emulator_test

(* Each datasheet limit the named bench firmware breaks, one line and one picture in
   [dir]; the library's benches pass, so [i2c_short_start] and [ws2812_short_bit] show it. *)
let names =
  [ Bench.scl, "SCL"; Bench.sda, "SDA"; Bench.neopixel, "DIN"; Bench.one_wire, "DQ" ]
;;

let () =
  match Sys.get_argv () |> Array.to_list |> List.tl_exn with
  | [ name; dir ] ->
    let bench =
      match name with
      | "i2c_short_start" -> Refusal_mutants.i2c_short_start
      | "ws2812_short_bit" -> Refusal_mutants.ws2812_short_bit
      | name -> Library.find_bench_exn name
    in
    let refusals = Named_refusal.refusals Library.limits bench in
    if List.is_empty refusals then print_endline [%string "%{name}: no limit refused"];
    List.iteri refusals ~f:(fun i t ->
      print_endline (Named_refusal.to_line t);
      let parameter =
        String.map t.entry.parameter ~f:(fun c -> if Char.is_alphanum c then c else '_')
      in
      let path = [%string "%{dir}/%{name}-%{parameter}-%{i#Int}.svg"] in
      Out_channel.write_all path ~data:(Named_refusal.to_svg ~names t);
      print_endline [%string "  picture %{path}"])
  | _ ->
    eprintf "usage: write_refusal BENCH DIR\n";
    exit 2
;;
