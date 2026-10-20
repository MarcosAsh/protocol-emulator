open! Core
open Pio

let command =
  Command.basic
    ~summary:
      "Translate .pio programs to the core's ISA, certified at k cycles a PIO cycle"
    ~readme:(fun () ->
      "Prints each program's translation, the host contract it rests on and the kernel's \
       verdict, at -k, -own-rate or else the least k that certifies; a pico-examples \
       program gets its C code's configuration and is held to its datasheet limits. With \
       -census, a table of them all. Exits 2 when any is refused or not certified, 1 on \
       a usage error.")
    (let%map_open.Command files = anon (non_empty_sequence_as_list ("FILE" %: string))
     and only = flag "program" (optional string) ~doc:"NAME translate only this program"
     and k = flag "k" (optional float) ~doc:"K cycles here a PIO cycle (default: least)"
     and own_rate =
       flag "own-rate" no_arg ~doc:" k for the example's own rate at the core's clock"
     and carrier =
       flag "carrier" no_arg ~doc:" on the bench carrier's pins, at its example's rate"
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
       if List.count [ Option.is_some k; own_rate; carrier ] ~f:Fn.id > 1
       then usage_error (Error.of_string "one of -k, -own-rate and -carrier");
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
             let on_carrier =
               if not carrier
               then None
               else (
                 match Carrier.find program with
                 | Some on_carrier -> Some on_carrier
                 | None ->
                   usage_error
                     (Error.of_string (program.name ^ ": no place on the carrier")))
             in
             let k =
               match k, own_rate, on_carrier with
               | Some k, _, _ -> Ok k
               | None, _, Some on_carrier -> Ok on_carrier.k
               | None, true, None ->
                 (match Census.real_time program with
                  | Some k -> Ok k
                  | None ->
                    usage_error
                      (Error.of_string (program.name ^ ": no rate of its own to run at")))
               | None, false, None ->
                 (match Census.least program with
                  | Certified { k; _ } -> Ok (Float.of_int k)
                  | verdict -> Error verdict)
             in
             match
               Result.bind k ~f:(fun k ->
                 Census.certify
                   ?place:(Option.map on_carrier ~f:(fun c -> c.place))
                   program
                   ~k
                 |> Result.map ~f:(fun c -> k, c))
             with
             | Ok (k, (t, timed)) ->
               let limits = Census.limits program timed in
               let refused =
                 List.filter_map limits ~f:(fun limit ->
                   Option.some_if (not (Census.Limit.ok limit)) limit.parameter)
               in
               printf
                 "; %s at k = %g, %s\n"
                 program.name
                 k
                 (if List.is_empty refused
                  then "certified"
                  else "refused: " ^ String.concat ~sep:", " refused);
               Option.iter on_carrier ~f:(fun c -> printf "; carrier: k for %s\n" c.why);
               List.iter limits ~f:(fun limit ->
                 printf "; limit: %s\n" (Census.Limit.to_string limit));
               List.iter t.contract ~f:(printf "; host: %s\n");
               print_string t.source;
               print_s
                 [%sexp
                   (Protocol_emulator.Timed_program.verdict timed
                    : Protocol_emulator.Analyser.Verdict.t)];
               let words = Protocol_emulator.Timed_program.words timed in
               printf "; %d words\n" (List.length words);
               List.chunks_of words ~length:8
               |> List.iter ~f:(fun chunk ->
                 printf
                   "; %s\n"
                   (String.concat ~sep:" " (List.map chunk ~f:(sprintf "0x%04X"))));
               List.is_empty refused
             | Error verdict ->
               printf "; %s\n" program.name;
               print_s [%sexp (verdict : Census.Verdict.t)];
               false)
         in
         if not (List.for_all passed ~f:Fn.id) then exit 2))
;;

let () = Command_unix.run command
