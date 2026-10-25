open! Core
open Protocol_emulator

let command =
  Command.basic
    ~summary:"Check a remote lab job and write its result folder's first files"
    [%map_open.Command
      let job = anon ("JOB" %: string)
      and out = flag "-out" (optional string) ~doc:"DIR where the files go"
      and print =
        flag
          "-print"
          (optional string)
          ~doc:"FILE print one of them instead, as check.json"
      in
      fun () ->
        let checked =
          Or_error.try_with_join (fun () ->
            In_channel.read_all job |> Remote_lab.Job.of_string)
          |> Or_error.bind ~f:Remote_lab.check
        in
        let files =
          match checked with
          | Error e -> Remote_lab.malformed e
          | Ok t -> Remote_lab.files t
        in
        match print, out with
        | Some name, None ->
          (match List.Assoc.find files name ~equal:String.equal with
           | Some data -> print_string data
           | None -> raise_s [%message "the check wrote no such file" name])
        | None, Some out ->
          Core_unix.mkdir_p out;
          List.iter files ~f:(fun (name, data) ->
            Out_channel.write_all (out ^/ name) ~data);
          (match checked with
           | Error e ->
             eprintf "malformed: %s\n" (Error.to_string_hum e);
             exit 2
           | Ok (Refused _) ->
             print_endline "refused";
             exit 1
           | Ok (Certified { bench = Takes _; _ }) ->
             print_endline "certified, the bench takes it"
           | Ok (Certified { bench = Declines why; _ }) ->
             printf "certified, the bench declines it: %s\n" why)
        | _ -> raise_s [%message "one of -out DIR and -print FILE"]]
;;
