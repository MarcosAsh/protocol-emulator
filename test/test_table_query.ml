open! Core

(* The one variant of the reject split's sample no table passes. *)
let no_table =
  List.find_exn
    (Reject_split.variants (Library.find_certified_exn "uart_tx_host_rate"))
    ~f:(fun (v : Reject_split.Variant.t) ->
      String.equal v.name "uart_tx_host_rate pc 12 jmp 11")
;;

let%expect_test "no table passes only once cake_lpr accepts the proof" =
  let { Reject_split.Variant.firmware; config; words; _ } = no_table in
  let passes solver =
    Or_error.try_with (fun () ->
      Table_query.witness
        ~solver
        ?period:firmware.period
        ~single_capture_edge:firmware.single_capture_edge
        ~config
        ~words
        ()
      |> Option.is_some)
  in
  let checked = passes Checked_unsat.solver in
  let bad_proof = passes Checked_unsat.solver_with_a_bad_proof in
  print_s [%message (checked : bool Or_error.t) (bad_proof : bool Or_error.t)];
  [%expect
    {|
    ((checked (Ok false))
     (bad_proof
      (Error
       ("cake_lpr rejects the proof"
        "c Checking failed at line: 0. Reason: clause index has no reduction sequence: 8332\n"))))
    |}]
;;
