open! Core
open Protocol_emulator_test

(* Every variant of the firmware named on the command line, or of the whole library. *)
let () =
  let names = List.tl_exn (Array.to_list (Sys.get_argv ())) in
  let firmware =
    match names with
    | [] -> Reject_split.firmware
    | names -> List.map names ~f:Library.find_certified_exn
  in
  Reject_split.print_split (List.concat_map firmware ~f:Reject_split.variants)
;;
