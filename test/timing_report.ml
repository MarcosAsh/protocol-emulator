open! Core
open Protocol_emulator

let jitter (i : Interval.t) = Option.map2 i.lo i.hi ~f:(fun lo hi -> hi - lo)

let worst_jitter intervals =
  List.map intervals ~f:jitter
  |> List.fold ~init:(Some 0) ~f:(Option.map2 ~f:Int.max)
  |> Option.value_map ~default:"unbounded" ~f:Int.to_string
;;

let side_edge (r : Analyser.Row.t) =
  Option.bind r.side_event ~f:(fun side -> Option.some_if side.changes side.at)
;;

let print ?period ?single_capture_edge ~config source =
  let program = Asm.assemble source |> ok_exn in
  let rows =
    Analyser.analyse
      ?period
      ?single_capture_edge
      ~config:(Asm.Program.configure program config)
      program.instructions
  in
  let judged =
    List.filter rows ~f:(fun r ->
      r.may_miss
      || Option.is_some r.pin_event
      || Option.is_some (side_edge r)
      || Option.is_some r.flip)
  in
  print_endline (Analyser.to_string ~side_set_count:program.side_set_count judged);
  let pin_events ~f =
    List.filter_map rows ~f:(fun (r : Analyser.Row.t) -> Option.bind r.pin_event ~f)
  in
  (* the second half of a Manchester bit is an edge like any other *)
  let edge_jitter =
    worst_jitter
      (pin_events ~f:(function
         | Edge i -> Some i
         | Sample _ -> None)
       @ List.filter_map rows ~f:(fun r -> r.flip))
  in
  let sample_jitter =
    worst_jitter
      (pin_events ~f:(function
        | Sample i -> Some i
        | Edge _ -> None))
  in
  let side_jitter = worst_jitter (List.filter_map rows ~f:side_edge) in
  print_s
    [%message
      ""
        ~words:(List.length program.instructions : int)
        (edge_jitter : string)
        (sample_jitter : string)
        (side_jitter : string)
        ~may_miss:(List.count rows ~f:(fun r -> r.may_miss) : int)]
;;
