open! Core
open Protocol_emulator

let jitter (i : Interval.t) = Option.map2 i.lo i.hi ~f:(fun lo hi -> hi - lo)

let worst_jitter rows ~f =
  List.filter_map rows ~f:(fun (r : Analyser.Row.t) -> Option.bind r.pin_event ~f)
  |> List.map ~f:jitter
  |> List.fold ~init:(Some 0) ~f:(Option.map2 ~f:Int.max)
  |> Option.value_map ~default:"unbounded" ~f:Int.to_string
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
  let judged = List.filter rows ~f:(fun r -> r.may_miss || Option.is_some r.pin_event) in
  print_endline (Analyser.to_string ~side_set_count:program.side_set_count judged);
  let edge_jitter =
    worst_jitter rows ~f:(function
      | Edge i -> Some i
      | Sample _ -> None)
  in
  let sample_jitter =
    worst_jitter rows ~f:(function
      | Sample i -> Some i
      | Edge _ -> None)
  in
  print_s
    [%message
      ""
        ~words:(List.length program.instructions : int)
        (edge_jitter : string)
        (sample_jitter : string)
        ~may_miss:(List.count rows ~f:(fun r -> r.may_miss) : int)]
;;
