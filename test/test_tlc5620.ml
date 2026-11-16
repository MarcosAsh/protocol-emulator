open! Core
open Protocol_emulator

(* The analyser and kernel verdicts on the firmware (it already compiles). *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Tlc5620.firmware));
  [%expect {| 27 words, 7 deadline waits, worst slack 16 |}]
;;

(* The bench's run against the DAC model, fed the pins every cycle: four words, then an
   LDAC pulse that moves all four outputs at once. *)
let%expect_test "the DAC model takes the host's words" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Tlc5620.firmware)
      ~program:(Timed_program.words Tlc5620.firmware)
    |> ok_exn
  in
  let machine =
    List.fold Tlc5620.words ~init:machine ~f:(fun machine word ->
      Machine.write_tx machine word |> ok_exn)
  in
  let level (machine : Machine.t) pin = (machine.pin_out lsr pin) land 1 = 1 in
  let machine, dac, at_ldac =
    List.fold
      (List.range 0 4_000)
      ~init:(machine, Tlc5620.Dac.create (), None)
      ~f:(fun (machine, prev, at_ldac) _ ->
        let machine = Machine.step machine ~inputs:0 in
        let dac =
          Tlc5620.Dac.step
            prev
            ~clk:(level machine Tlc5620.clk)
            ~data:(level machine Tlc5620.data)
            ~load:(level machine Tlc5620.load)
            ~ldac:(level machine Tlc5620.ldac)
        in
        let at_ldac =
          match at_ldac with
          | None when not (level machine Tlc5620.ldac) -> Some (Tlc5620.Dac.outputs prev)
          | at_ldac -> at_ldac
        in
        machine, dac, at_ldac)
  in
  print_s
    [%message
      ""
        ~just_before_ldac_falls:(at_ldac : int list option)
        ~outputs:(Tlc5620.Dac.outputs dac : int list)
        ~violations:(Tlc5620.Dac.violations dac : string list)
        ~fault:(machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((just_before_ldac_falls ((0 0 0 0))) (outputs (128 128 255 1))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)
       (assumption false))))
    |}]
;;

(* a word cut to 10 clocks, and a LOAD that rises after 11 cycles *)
let%expect_test "the DAC model refuses a short word and a short LOAD" =
  let hold dac ~clk ~load ~cycles =
    Fn.apply_n_times
      ~n:cycles
      (fun dac -> Tlc5620.Dac.step dac ~clk ~data:true ~load ~ldac:true)
      dac
  in
  let clocks dac n =
    List.fold (List.range 0 n) ~init:dac ~f:(fun dac _ ->
      let dac = hold dac ~clk:false ~load:true ~cycles:20 in
      let dac = hold dac ~clk:true ~load:true ~cycles:20 in
      hold dac ~clk:false ~load:true ~cycles:20)
  in
  let start = hold (Tlc5620.Dac.create ()) ~clk:false ~load:true ~cycles:100 in
  let show dac =
    print_s [%message "" ~violations:(Tlc5620.Dac.violations dac : string list)]
  in
  show (hold (clocks start 10) ~clk:false ~load:false ~cycles:20);
  show
    (hold
       (hold (clocks start 11) ~clk:false ~load:false ~cycles:11)
       ~clk:false
       ~load:true
       ~cycles:1);
  [%expect
    {|
    (violations ("LOAD with fewer than 11 clocks at 701"))
    (violations ("LOAD low under 250 ns at 772"))
    |}]
;;
