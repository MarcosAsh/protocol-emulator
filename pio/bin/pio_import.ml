open! Core
open Pio

let command =
  Command.basic
    ~summary:
      "Translate .pio programs to the core's ISA, certified at k cycles a PIO cycle"
    ~readme:(fun () ->
      "Prints each program's translation, the host contract it rests on and the kernel's \
       verdict, at -k or else the least k that certifies; a pico-examples program gets \
       its C code's configuration. With -census, a table of them all. Exits 2 when any \
       is refused or not certified, 1 on a usage error.")
    (let%map_open.Command files = anon (non_empty_sequence_as_list ("FILE" %: string))
     and only = flag "program" (optional string) ~doc:"NAME translate only this program"
     and k = flag "k" (optional float) ~doc:"K cycles here a PIO cycle (default: least)"
     and census = flag "census" no_arg ~doc:" a table of every program instead" in
     fun () ->
       let usage_error error =
         eprintf "%s\n" (Error.to_string_hum error);
         exit 1
       in
       let programs =
         List.concat_map files ~f:(fun file ->
           match
             Or_error.try_with (fun () -> In_channel.read_all file)
             |> Or_error.bind ~f:Pioasm.parse
           with
           | Error error -> usage_error error
           | Ok programs ->
             List.filter_map programs ~f:(fun (program : Pioasm.Program.t) ->
               Option.some_if
                 (Option.value_map only ~default:true ~f:(String.equal program.name))
                 (Filename.basename file, program)))
       in
       if List.is_empty programs then usage_error (Error.of_string "no program");
       if Option.exists k ~f:(fun k -> Float.( < ) k 2.)
       then usage_error (Error.of_string "-k must be at least 2");
       if census
       then (
         let rows =
           List.map programs ~f:(fun (file, program) -> Census.row ~file program)
         in
         print_string (Census.to_string rows);
         if List.exists rows ~f:(fun row ->
              match row.verdict with
              | Certified _ -> false
              | Not_certified _ | Refused _ -> true)
         then exit 2)
       else (
         let passed =
           List.map programs ~f:(fun (_, program) ->
             let k =
               match k, Census.least program with
               | Some k, _ -> Ok k
               | None, Certified { k; _ } -> Ok (Float.of_int k)
               | None, verdict -> Error verdict
             in
             match
               Result.bind k ~f:(fun k ->
                 Census.certify program ~k |> Result.map ~f:(fun c -> k, c))
             with
             | Ok (k, (t, timed)) ->
               printf "; %s at k = %g, certified\n" program.name k;
               List.iter t.contract ~f:(printf "; host: %s\n");
               print_string t.source;
               print_s
                 [%sexp
                   (Protocol_emulator.Timed_program.verdict timed
                    : Protocol_emulator.Analyser.Verdict.t)];
               true
             | Error verdict ->
               printf "; %s\n" program.name;
               print_s [%sexp (verdict : Census.Verdict.t)];
               false)
         in
         if not (List.for_all passed ~f:Fn.id) then exit 2))
;;

let () = Command_unix.run command
