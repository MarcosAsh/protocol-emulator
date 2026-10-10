open! Core
open Pio

let read file = Or_error.try_with (fun () -> In_channel.read_all file)

let describe (hole : Holes.Hole.t) =
  let kind =
    match hole.kind with
    | Delay -> "delay"
    | Side -> "side"
  in
  let reference =
    Option.value_map hole.reference ~default:"" ~f:(fun value ->
      [%string ", reference %{value#Int}"])
  in
  let domain =
    match hole.domain with
    | [] -> "none"
    | first :: _ -> [%string "%{first#Int}..%{List.last_exn hole.domain#Int}"]
  in
  [%string "line %{hole.line#Int}: %{kind} in %{domain}%{reference}"]
;;

let command =
  Command.basic
    ~summary:"Fill the [?] delays and side ? values of a .pio file to meet its specs"
    ~readme:(fun () ->
      "Tries every assignment in order of its distance from the reference (or of total \
       delay, with none) and stops at the first distance where one meets every spec, as \
       pio_check would check it. Every cheaper assignment is reported as tried and \
       failed, which is the proof of minimality. Exits 2 when none meets the specs, 1 on \
       a usage error.")
    (let%map_open.Command file = anon ("FILE" %: Filename_unix.arg_type)
     and specs =
       flag
         "spec"
         (one_or_more_as_list Filename_unix.arg_type)
         ~doc:"FILE pio_check flags, one a line; a fix must pass every one"
     and reference =
       flag
         "reference"
         (optional Filename_unix.arg_type)
         ~doc:"FILE the program the fix should change least"
     and output =
       flag "o" (optional Filename_unix.arg_type) ~doc:"FILE write the first minimal fix"
     and max_checks =
       flag
         "max-checks"
         (optional_with_default 100_000 int)
         ~doc:"N give up past N assignments"
     in
     fun () ->
       let ok_or_usage = function
         | Ok value -> value
         | Error error ->
           eprintf "%s\n" (Error.to_string_hum error);
           exit 1
       in
       let holes =
         (let open Or_error.Let_syntax in
          let%bind text = read file in
          let%bind reference =
            match reference with
            | None -> Ok None
            | Some reference -> read reference >>| Option.some
          in
          Holes.parse ?reference text)
         |> ok_or_usage
       in
       let specs =
         List.map specs ~f:(fun spec -> read spec |> Or_error.bind ~f:Spec.of_string)
         |> Or_error.all
         |> ok_or_usage
       in
       List.iter (Holes.holes holes) ~f:(fun hole -> print_endline (describe hole));
       let search =
         Holes.solve ~max_checks holes ~passes:(Holes.meets specs) |> ok_or_usage
       in
       List.iter search.checked ~f:(fun (cost, size) ->
         let passed =
           match search.minimal with
           | Some (minimal, passing) when minimal = cost -> List.length passing
           | _ -> 0
         in
         printf "cost %d: %d tried, %d pass\n" cost size passed);
       match search.minimal with
       | None ->
         print_endline "no assignment meets the specs";
         exit 2
       | Some (cost, passing) ->
         List.iter passing ~f:(fun values ->
           let changes =
             List.zip_exn (Holes.holes holes) values
             |> List.filter_map ~f:(fun ((hole : Holes.Hole.t), value) ->
               if [%equal: int option] hole.reference (Some value)
               then None
               else (
                 let kind =
                   match hole.kind with
                   | Delay -> "delay"
                   | Side -> "side"
                 in
                 let from =
                   Option.value_map hole.reference ~default:"" ~f:(fun reference ->
                     [%string "%{reference#Int} -> "])
                 in
                 Some [%string "line %{hole.line#Int} %{kind} %{from}%{value#Int}"]))
           in
           printf "minimal, cost %d: %s\n" cost (String.concat ~sep:", " changes));
         Option.iter output ~f:(fun output ->
           Out_channel.write_all
             output
             ~data:(Holes.fill holes (List.hd_exn passing) ^ "\n")))
;;

let () = Command_unix.run command
