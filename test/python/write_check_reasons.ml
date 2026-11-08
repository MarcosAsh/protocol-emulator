open! Core
open Protocol_emulator

(* The load checker's reject_reason codes with the names [Load_check.walk] gives them, one
   [code name] a line, for test_host.py to hold python/protocol_emulator.py's REASONS to. *)
let () =
  let way name = Kernel.Holds.map Kernel.Holds.port_names ~f:(fun f -> name ^ " " ^ f) in
  let conjuncts =
    Kernel.Conjuncts.to_list
      { Kernel.Conjuncts.in_time = "in time"
      ; wide_a = "a spaced"
      ; wide_b = "b spaced"
      ; next = way "next"
      ; target = way "target"
      }
  in
  List.mapi conjuncts ~f:(fun code name -> code, name)
  @ [ Load_checker.aborted, "aborted"
    ; Load_checker.out_of_order, "a table entry out of order"
    ; Load_checker.left_over, "a table entry left over"
    ]
  |> List.iter ~f:(fun (code, name) -> printf "%d %s\n" code name)
;;
