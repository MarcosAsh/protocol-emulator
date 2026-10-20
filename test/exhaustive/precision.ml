open! Core
open Protocol_emulator_test

(* [Exhaustive.run] at the bound on the command line, the laptop's by default: jobs, then
   words, delays, alu steps and set values, each comma-separated. Each job forks and runs
   a shard. *)
let () =
  let ints s =
    String.split s ~on:','
    |> List.filter ~f:(Fn.non String.is_empty)
    |> List.map ~f:Int.of_string
  in
  let jobs, (bound : Exhaustive.Bound.t) =
    match Sys.get_argv () with
    | [| _ |] -> 1, Exhaustive.Bound.laptop
    | [| _; jobs |] -> Int.of_string jobs, Exhaustive.Bound.laptop
    | [| _; jobs; words; delays; imms; values |] ->
      ( Int.of_string jobs
      , { words = Int.of_string words
        ; delays = ints delays
        ; imms = ints imms
        ; values = ints values
        } )
    | _ ->
      eprintf "usage: precision.exe [JOBS [WORDS DELAYS IMMS VALUES]], as 8 5 0,1 3 4\n";
      exit 2
  in
  let start = Time_ns.now () in
  let shards =
    List.init jobs ~f:(fun shard ->
      let file = Filename_unix.temp_file "precision" ".shard" in
      match Core_unix.fork () with
      | `In_the_child ->
        let report = Exhaustive.run ~shard:(shard, jobs) bound in
        Out_channel.with_file file ~binary:true ~f:(fun out ->
          Marshal.to_channel out report []);
        Core_unix.exit_immediately 0
      | `In_the_parent pid -> pid, file)
  in
  let report =
    List.map shards ~f:(fun (pid, file) ->
      Core_unix.waitpid_exn pid;
      let report : Exhaustive.Report.t =
        In_channel.with_file file ~binary:true ~f:Marshal.from_channel
      in
      Core_unix.unlink file;
      report)
    |> List.reduce_exn ~f:Exhaustive.Report.merge
  in
  eprintf "%s\n" (Time_ns.Span.to_string_hum (Time_ns.diff (Time_ns.now ()) start));
  Exhaustive.print ~top:25 ~witness:true report
;;
