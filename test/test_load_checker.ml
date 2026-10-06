open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Load_checker.I) (Load_checker.O)

let ( <--. ) = Bits.( <--. )

(* [Load_check.walk]'s verdict as the checker reports it *)
let expected = function
  | Ok _ -> `Accepted
  | Error { Load_check.Rejection.pc; reason } ->
    let names =
      Kernel.Conjuncts.to_list
        { Kernel.Conjuncts.in_time = "in time"
        ; wide_a = "a spaced"
        ; wide_b = "b spaced"
        ; next = Kernel.Holds.map Kernel.Holds.port_names ~f:(fun f -> "next " ^ f)
        ; target = Kernel.Holds.map Kernel.Holds.port_names ~f:(fun f -> "target " ^ f)
        }
    in
    let code =
      match reason with
      | "a table entry out of order" -> Load_checker.out_of_order
      | "a table entry left over" -> Load_checker.left_over
      | reason -> fst (List.findi_exn names ~f:(fun _ name -> String.equal name reason))
    in
    `Rejected (pc, code)
;;

(* The checker over [words] and [certificate], the program memory answering a cycle after
   an address and the data memory two, the latest either engine's turn gives. With
   [rewrite_at], the host writes a different setup that many cycles into the walk. *)
let run
  ?random_initial_state
  ?rewrite_at
  ~config
  ?loaded
  ?(single_edge = false)
  ~words
  ~certificate
  ()
  =
  let program = Array.of_list words in
  let data = Array.of_list certificate in
  let word memory at = if at < Array.length memory then memory.(at) else 0 in
  Harness.run
    ?random_initial_state
    ~create:Load_checker.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Lws.step ?n h in
       let outputs = Before_and_after_edge.after_edge outputs in
       inputs.clocking.clear := Bits.vdd;
       cycle ();
       inputs.clocking.clear := Bits.gnd;
       Engine.Config.iter2
         inputs.config
         (Engine.Config.of_program_config config)
         ~f:( := );
       inputs.setup.loaded.valid := Bits.of_bool (Option.is_some loaded);
       inputs.setup.loaded.value <--. Option.value loaded ~default:0;
       inputs.setup.single_edge := Bits.of_bool single_edge;
       inputs.setup.base <--. 0;
       inputs.check := Bits.vdd;
       cycle ();
       inputs.check := Bits.gnd;
       let program_at = ref 0 in
       let data_at = ref (0, 0) in
       let cycles = ref 1 in
       while not (Bits.to_bool !(outputs.finished)) do
         inputs.program_word <--. word program !program_at;
         inputs.data_word <--. word data (fst !data_at);
         program_at := Bits.to_unsigned_int !(outputs.program_read.value);
         data_at := snd !data_at, Bits.to_unsigned_int !(outputs.data_read.value);
         if Option.equal Int.equal rewrite_at (Some !cycles)
         then (
           inputs.setup.base <--. 0x155;
           inputs.setup.loaded.valid := Bits.of_bool (Option.is_none loaded);
           inputs.setup.loaded.value <--. 0xbeef;
           inputs.setup.single_edge := Bits.of_bool (not single_edge));
         cycle ();
         incr cycles;
         if !cycles > 200_000 then raise_s [%message "the checker never finished"]
       done;
       let verdict =
         if Bits.to_bool !(outputs.accepted)
         then `Accepted
         else
           `Rejected
             ( Bits.to_unsigned_int !(outputs.reject_pc)
             , Bits.to_unsigned_int !(outputs.reason) )
       in
       verdict, !cycles)
;;

let certify (case : Firmware_inventory.t) =
  let config = Timed_program.config case.timed in
  let words = Timed_program.words case.timed in
  let certificate =
    Load_check.of_table
      ~config
      ~words
      (Kernel.Table.of_analyser (Timed_program.rows case.timed))
    |> ok_exn
    |> Load_check.to_words
  in
  config, words, certificate
;;

let model (case : Firmware_inventory.t) ~config ~words ~certificate =
  let memory at =
    if at < List.length certificate then List.nth_exn certificate at else 0
  in
  Load_check.walk
    ?loaded:case.period
    ~single_capture_edge:case.single_capture_edge
    ~config
    ~words
    ~memory
    ~base:0
    ()
  |> expected
;;

let show = function
  | `Accepted -> "accepted"
  | `Rejected (pc, code) -> sprintf "refused at %d, reason %d" pc code
;;

(* The hardware against [Load_check.walk] on every firmware: the same verdict, at the same
   pc, for the same conjunct. *)
let%expect_test "the checker agrees with the model on every firmware" =
  printf "%-26s %7s  %s\n" "firmware" "cycles" "verdict";
  List.iter Firmware_inventory.all ~f:(fun case ->
    let config, words, certificate = certify case in
    let verdict, cycles =
      run
        ~config
        ?loaded:case.period
        ~single_edge:case.single_capture_edge
        ~words
        ~certificate
        ()
    in
    let model = model case ~config ~words ~certificate in
    if not ([%equal: [ `Accepted | `Rejected of int * int ]] verdict model)
    then printf "MISMATCH, the model says %s: " (show model);
    printf "%-26s %7d  %s\n" case.name cycles (show verdict));
  [%expect
    {|
    firmware                    cycles  verdict
    uart_tx                       4222  accepted
    uart_tx16                     4222  accepted
    uart_tx_host_rate             4224  accepted
    uart_rx                       4297  accepted
    spi_master                    4223  accepted
    spi_slave                     4134  accepted
    i2c_master                    5134  accepted
    i2c_slave                     4729  accepted
    i2c_logger                    4571  accepted
    usb_tx                        5422  accepted
    usb_rx                        4495  accepted
    usb_device                   16899  accepted
    edge_meter                    4160  accepted
    ws2812                        4586  accepted
    ethernet                      4418  accepted
    one_wire                      4670  accepted
    ps2                           4709  accepted
    jtag                          4222  accepted
    can                           5304  accepted
    dshot600                      4335  accepted
    sent                          4792  accepted
    cec                           5421  accepted
    asm/data_stream               4138  accepted
    asm/edge_logger_echo          4221  accepted
    asm/edge_logger_wire          4175  accepted
    asm/ethernet                  4418  accepted
    asm/i2c_master_marked         4929  accepted
    asm/i2c_start_watch           4166  accepted
    asm/quiet_watch                212  refused at 8, reason 0
    asm/scl_rise                  4148  accepted
    asm/scrub                     4100  accepted
    asm/self_check_wire           4953  accepted
    asm/uart_rx_wire              4297  accepted
    asm/uart_tx                   4222  accepted
    asm/uart_tx_host_rate         4224  accepted
    asm/wrapped_loop              4164  accepted
    bench/i2c_master              5136  accepted
    bench/i2c_master_stretch      6451  accepted
    bench/can_sender              5312  accepted
    bench/can_receiver           10375  accepted
    bench/sk6812                  4586  accepted
    bench/start_hold              4098  accepted
    bench/swd                     7161  accepted
    bench/spi_cs_mode0            4354  accepted
    bench/spi_cs_mode1            4354  accepted
    bench/spi_cs_mode2            4354  accepted
    bench/spi_cs_mode3            4354  accepted
    |}]
;;

(* One word of the certificate or of the program changed at random, from a random initial
   state: whatever the model makes of it, accepting or refusing where and why, so does the
   checker. *)
let%expect_test "the checker agrees with the model on corrupted certificates" =
  let cases =
    List.filter Firmware_inventory.all ~f:(fun c ->
      List.mem
        [ "uart_tx"; "uart_rx"; "i2c_master"; "can"; "bench/swd" ]
        c.name
        ~equal:String.equal)
  in
  let refused = ref 0 in
  let trials = ref 0 in
  List.iter cases ~f:(fun case ->
    let config, words, certificate = certify case in
    Quickcheck.test
      ~seed:(`Deterministic case.name)
      ~trials:40
      (Quickcheck.Generator.tuple3
         Bool.quickcheck_generator
         (Int.gen_incl 0 511)
         (Int.gen_incl 0 0xffff))
      ~f:(fun (in_program, at, value) ->
        let replace list =
          List.mapi list ~f:(fun n w -> if n = at % List.length list then value else w)
        in
        let words, certificate =
          if in_program then replace words, certificate else words, replace certificate
        in
        let verdict, _ =
          run
            ~random_initial_state:`All
            ~config
            ?loaded:case.period
            ~single_edge:case.single_capture_edge
            ~words
            ~certificate
            ()
        in
        let model = model case ~config ~words ~certificate in
        incr trials;
        (match verdict with
         | `Rejected _ -> incr refused
         | `Accepted -> ());
        if not ([%equal: [ `Accepted | `Rejected of int * int ]] verdict model)
        then
          raise_s
            [%message
              "the checker and the model disagree"
                case.name
                (in_program : bool)
                (at : int)
                (value : int)
                ~checker:(show verdict)
                ~model:(show model)]));
  print_s [%message (!trials : int) (!refused : int)];
  [%expect {| ((!trials 200) (!refused 126)) |}]
;;

(* The setup is the one the host wrote before the check: writing another mid-walk, from
   the first cycle to the last, leaves every verdict as it was. *)
let%expect_test "a setup written during a walk does not reach it" =
  let cases =
    List.filter Firmware_inventory.all ~f:(fun c ->
      List.mem
        [ "uart_tx"; "i2c_master"; "usb_device"; "bench/swd" ]
        c.name
        ~equal:String.equal)
  in
  List.iter cases ~f:(fun case ->
    let config, words, certificate = certify case in
    let run ?rewrite_at () =
      run
        ?rewrite_at
        ~config
        ?loaded:case.period
        ~single_edge:case.single_capture_edge
        ~words
        ~certificate
        ()
    in
    let verdict, cycles = run () in
    List.iter
      [ 1; 2; 3; cycles / 2; cycles - 2 ]
      ~f:(fun rewrite_at ->
        let rewritten, _ = run ~rewrite_at () in
        if not ([%equal: [ `Accepted | `Rejected of int * int ]] verdict rewritten)
        then
          raise_s
            [%message
              "a setup written mid-walk changed the verdict"
                case.name
                (rewrite_at : int)
                ~before:(show verdict)
                ~after:(show rewritten)]);
    printf "%s: %s\n" case.name (show verdict));
  [%expect
    {|
    uart_tx: accepted
    i2c_master: accepted
    usb_device: accepted
    bench/swd: accepted
    |}]
;;
