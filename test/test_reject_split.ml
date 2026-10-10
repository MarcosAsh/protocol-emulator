open! Core
open Protocol_emulator

let variant name =
  let firmware = Certified.find_exn (List.hd_exn (String.split name ~on:' ')) in
  List.find_exn (Reject_split.variants firmware) ~f:(fun (v : Reject_split.Variant.t) ->
    String.equal v.name name)
;;

(* Every 250th variant, with the full run's runs, and the one uart_tx_host_rate variant
   the full run finds no table for. *)
let%expect_test "the reject split, on a sample" =
  let every = List.concat_map Reject_split.firmware ~f:Reject_split.variants in
  let sample = List.filteri every ~f:(fun i _ -> i % 250 = 0) in
  print_s [%message (List.length every : int) (List.length sample : int)];
  Reject_split.print_split (sample @ [ variant "uart_tx_host_rate pc 12 jmp 11" ]);
  [%expect
    {|
    (("List.length every" 28340) ("List.length sample" 114))
    ((verdict Accepted) (count 109))
    ((verdict Missed) (count 5))
    ((verdict Analyser_limit) (count 0))
    ((verdict No_table) (count 1))
    ((verdict Accepted_but_missed) (count 0))
    ((verdict Witness_refused) (count 0))
    ("uart_tx_host_rate pc 12 jmp 11" (verdict No_table) (cycles 80000))
    |}]
;;

(* Teeth for [Accepted_but_missed]: a host writing random words from the start breaks the
   period premise, and accepted firmware misses. *)
let%expect_test "a run that breaks the period premise misses deadlines the kernel says \
                 it meets"
  =
  List.iter [ "ethernet pc 1 delay 1"; "usb_tx pc 1 delay 1" ] ~f:(fun name ->
    let v = variant name in
    let kept, _ = Reject_split.classify ~runs:2 ~cycles:5_000 v in
    let broken, _ = Reject_split.classify ~random_host:true ~runs:2 ~cycles:5_000 v in
    print_s
      [%message name (kept : Reject_split.Verdict.t) (broken : Reject_split.Verdict.t)]);
  [%expect
    {|
    ("ethernet pc 1 delay 1" (kept Accepted) (broken Accepted_but_missed))
    ("usb_tx pc 1 delay 1" (kept Accepted) (broken Accepted_but_missed))
    |}]
;;

(* Teeth for [Witness_refused], which the full split did not reach: on accepted variants
   SAT finds a table, and it passes [Kernel.check] unless every row past pc 0 is emptied. *)
let%expect_test "a table SAT finds passes Kernel.check" =
  List.iter
    [ "uart_tx pc 8 delay 3"; "spi_slave pc 0 delay 4"; "ethernet pc 0 delay 11" ]
    ~f:(fun name ->
      let v = variant name in
      let { Certified.period; single_capture_edge; _ } = v.firmware in
      let check table =
        Kernel.check ?period ~single_capture_edge ~config:v.config ~words:v.words table
        |> Result.is_ok
      in
      let table =
        Table_query.witness
          ?period
          ~single_capture_edge
          ~config:v.config
          ~words:v.words
          ()
        |> Option.value_exn
      in
      let empty = (Kernel.Table.of_analyser []).(1) in
      let witness = check table in
      let emptied =
        check (Array.mapi table ~f:(fun pc row -> if pc = 0 then row else empty))
      in
      print_s [%message name (witness : bool) (emptied : bool)]);
  [%expect
    {|
    ("uart_tx pc 8 delay 3" (witness true) (emptied false))
    ("spi_slave pc 0 delay 4" (witness true) (emptied false))
    ("ethernet pc 0 delay 11" (witness true) (emptied false))
    |}]
;;
