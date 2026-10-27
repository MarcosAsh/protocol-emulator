open! Core

(* runs of consecutive ints, as "a-b" *)
let ranges ks =
  List.group ks ~break:(fun a b -> b <> a + 1)
  |> List.map ~f:(fun run ->
    match run, List.last_exn run with
    | [ k ], _ -> Int.to_string k
    | k :: _, last -> [%string "%{k#Int}-%{last#Int}"]
    | [], _ -> assert false)
;;

(* Around both ends of the slack, the first four and the last seven: the kernel accepts a
   variant exactly when its nops fit in the slack, and the model, under the sweep's
   stimulus, runs late none it accepts. It runs late every one it refuses but CAN's, whose
   tightest way into the wait the stimulus never takes. demo/kernel_vs_board.py runs every
   [k] in between on the board. *)
let%expect_test "the kernel's verdict on delay variants" =
  List.iter Library.swept ~f:(fun swept ->
    let t = Delay_variants.of_swept swept in
    let { Delay_variants.wait_pc; slack; _ } = t in
    let variants =
      List.init 4 ~f:Fn.id @ List.init 7 ~f:(fun k -> slack - 3 + k)
      |> List.filter ~f:(fun k -> k >= 0)
      |> List.dedup_and_sort ~compare:Int.compare
      |> List.map ~f:(Delay_variants.variant t)
    in
    let ks f =
      List.filter_map variants ~f:(fun (v : Delay_variants.Variant.t) ->
        Option.some_if (f v) v.k)
      |> ranges
    in
    let name = swept.name in
    let accepted = ks Delay_variants.Variant.accepted in
    let late = ks Delay_variants.Variant.late in
    print_s
      [%message
        name (wait_pc : int) (slack : int) (accepted : string list) (late : string list)]);
  [%expect
    {|
    (uart_tx (wait_pc 8) (slack 4) (accepted (0-4)) (late (5-7)))
    (uart_tx16 (wait_pc 8) (slack 12) (accepted (0-3 9-12)) (late (13-15)))
    (uart_tx_host_rate (wait_pc 10) (slack 430) (accepted (0-3 427-430))
     (late (431-433)))
    (spi_master (wait_pc 9) (slack 4) (accepted (0-4)) (late (5-7)))
    (jtag (wait_pc 8) (slack 0) (accepted (0)) (late (1-3)))
    (can (wait_pc 36) (slack 1785) (accepted (0-3 1782-1785)) (late ()))
    (sent (wait_pc 26) (slack 279) (accepted (0-3 276-279)) (late (280-282)))
    |}]
;;

(* Planted timing bugs: at every deadline wait of the swept firmware, one to three cycles
   of nops, half the slack, and every count from one short of it to three past, each run
   on the model under the sweep's stimulus. Whatever the kernel certifies must never run
   late; what it refuses either runs late or is late only on a way into the wait the
   stimulus does not take. *)
let%expect_test "planted delays: none the kernel certifies runs late" =
  let totals = Array.create ~len:5 0 in
  List.iter Library.swept ~f:(fun swept ->
    let row = Array.create ~len:5 0 in
    List.iter (Delay_variants.every_wait swept) ~f:(fun t ->
      [ 1; 2; 3; t.slack / 2 ] @ List.init 5 ~f:(fun i -> t.slack - 1 + i)
      |> List.filter ~f:(fun k -> k >= 1)
      |> List.dedup_and_sort ~compare:Int.compare
      |> List.iter ~f:(fun k ->
        let v = Delay_variants.variant t k in
        let certified = Delay_variants.Variant.accepted v in
        let late = Delay_variants.Variant.late v in
        let bump i =
          row.(i) <- row.(i) + 1;
          totals.(i) <- totals.(i) + 1
        in
        bump 0;
        bump (if certified then 1 else 2);
        if certified && late then bump 3;
        if (not certified) && late then bump 4));
    printf
      "%-18s %4d planted: %4d certified, %d ran late; %3d refused, %3d ran late\n"
      swept.name
      row.(0)
      row.(1)
      row.(3)
      row.(2)
      row.(4));
  printf
    "%-18s %4d planted: %4d certified, %d ran late; %3d refused, %3d ran late\n"
    "total"
    totals.(0)
    totals.(1)
    totals.(3)
    totals.(2)
    totals.(4);
  [%expect
    {|
    uart_tx              22 planted:   13 certified, 0 ran late;   9 refused,   9 ran late
    uart_tx16            27 planted:   18 certified, 0 ran late;   9 refused,   9 ran late
    uart_tx_host_rate    27 planted:   18 certified, 0 ran late;   9 refused,   9 ran late
    spi_master           23 planted:   14 certified, 0 ran late;   9 refused,   9 ran late
    jtag                 13 planted:    4 certified, 0 ran late;   9 refused,   9 ran late
    can                  90 planted:   60 certified, 0 ran late;  30 refused,  22 ran late
    sent                 81 planted:   54 certified, 0 ran late;  27 refused,  25 ran late
    total               283 planted:  181 certified, 0 ran late; 102 refused,  92 ran late
    |}]
;;

let%expect_test "nops fill the delay field before adding another" =
  List.iter
    [ 0, 0, 0; 0, 0, 1; 0, 0, 33; 1, 1, 17; 2, 0, 8 ]
    ~f:(fun (side_set_count, side, k) ->
      print_s
        [%message
          (side_set_count : int)
            (k : int)
            ~nops:(Delay_variants.nops ~side_set_count ~side k : string list)]);
  [%expect
    {|
    ((side_set_count 0) (k 0) (nops ()))
    ((side_set_count 0) (k 1) (nops ("    nop")))
    ((side_set_count 0) (k 33) (nops ("    nop [31]" "    nop")))
    ((side_set_count 1) (k 17) (nops ("    nop side 1 [15]" "    nop side 1")))
    ((side_set_count 2) (k 8) (nops ("    nop side 0 [7]")))
    |}]
;;
