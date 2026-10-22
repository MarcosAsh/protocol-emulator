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

module Walk = struct
  type t =
    { config : Program_config.t
    ; loaded : int option
    ; floor : bool
    ; single_edge : bool
    ; words : int list
    ; certificate : int list
    ; base : int
    ; abort_at : int option
    }

  (* the data memory with the certificate from [base], wrapping at its size *)
  let memory t =
    let size = 1 lsl Isa.data_addr_bits in
    let memory = Array.create ~len:size 0 in
    List.iteri t.certificate ~f:(fun n word -> memory.((t.base + n) % size) <- word);
    memory
  ;;
end

(* The checker over each walk's [words] and [certificate] in turn, one simulation, the
   program memory answering a cycle after an address and the data memory two, the latest
   either engine's turn gives. With [rewrite_at], the host writes a different setup that
   many cycles into a walk; with a walk's [abort_at], it aborts it that many cycles in. *)
let run_walks ?random_initial_state ?rewrite_at (walks : Walk.t list) =
  Harness.run
    ?random_initial_state
    ~create:Load_checker.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let cycle ?n () = Lws.step ?n h in
       let outputs = Before_and_after_edge.after_edge outputs in
       inputs.clocking.clear := Bits.vdd;
       cycle ();
       inputs.clocking.clear := Bits.gnd;
       List.map
         walks
         ~f:
           (fun
             ({ config; loaded; floor; single_edge; words; base; abort_at; _ } as walk) ->
           let program = Array.of_list words in
           let data = Walk.memory walk in
           let word memory at = if at < Array.length memory then memory.(at) else 0 in
           Engine.Config.iter2
             inputs.config
             (Engine.Config.of_program_config config)
             ~f:( := );
           inputs.setup.loaded.valid := Bits.of_bool (Option.is_some loaded);
           inputs.setup.loaded.value <--. Option.value loaded ~default:0;
           inputs.setup.floor := Bits.of_bool floor;
           inputs.setup.single_edge := Bits.of_bool single_edge;
           inputs.setup.base <--. base;
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
               inputs.setup.floor := Bits.of_bool (not floor);
               inputs.setup.single_edge := Bits.of_bool (not single_edge));
             inputs.abort := Bits.of_bool (Option.equal Int.equal abort_at (Some !cycles));
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
       [@nontail])
;;

let run
  ?random_initial_state
  ?rewrite_at
  ~config
  ?loaded
  ?(floor = false)
  ?(single_edge = false)
  ~words
  ~certificate
  ()
  =
  run_walks
    ?random_initial_state
    ?rewrite_at
    [ { config
      ; loaded
      ; floor
      ; single_edge
      ; words
      ; certificate
      ; base = 0
      ; abort_at = None
      }
    ]
  |> List.hd_exn
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
    ~floor:case.floor
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

(* a firmware's walk, its table's rows changed by [edit] before the host certifies it *)
let walk_of ?(edit = Fn.id) name =
  let case =
    List.find_exn Firmware_inventory.all ~f:(fun c -> String.equal c.name name)
  in
  let config = Timed_program.config case.timed in
  let words = Timed_program.words case.timed in
  let table = edit (Kernel.Table.of_analyser (Timed_program.rows case.timed)) in
  { Walk.config
  ; loaded = case.period
  ; floor = case.floor
  ; single_edge = case.single_capture_edge
  ; words
  ; certificate =
      Load_check.of_table ~config ~words table |> ok_exn |> Load_check.to_words
  ; base = 0
  ; abort_at = None
  }
;;

let edit_row pc ~f (table : Kernel.Table.t) =
  table.(pc) <- f table.(pc);
  table
;;

(* the model's verdict on a walk; it has no abort *)
let walk_model (w : Walk.t) =
  let memory = Walk.memory w in
  Load_check.walk
    ?loaded:w.loaded
    ~floor:w.floor
    ~single_capture_edge:w.single_edge
    ~config:w.config
    ~words:w.words
    ~memory:(Array.get memory)
    ~base:w.base
    ()
  |> expected
;;

(* each walk's verdict, one simulation, after a MISMATCH where the model's differs *)
let print_walks ?random_initial_state walks =
  List.iter2_exn walks (run_walks ?random_initial_state walks) ~f:(fun w (verdict, _) ->
    let model = walk_model w in
    if not ([%equal: [ `Accepted | `Rejected of int * int ]] verdict model)
    then printf "MISMATCH, the model says %s: " (show model);
    print_endline (show verdict))
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
        ~floor:case.floor
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
    uart_tx                       8428  accepted
    uart_tx16                     8428  accepted
    uart_tx_host_rate             8434  accepted
    uart_rx                       8575  accepted
    uart_rx_host_rate             8521  accepted
    spi_master                    8431  accepted
    spi_slave                     8251  accepted
    i2c_master                   10172  accepted
    i2c_slave                     9284  accepted
    i2c_logger                    9154  accepted
    i2c_master_standard          10208  accepted
    i2c_master_fast              10193  accepted
    i2c_controller_wire           9781  accepted
    i2c_target_wire               9299  accepted
    usb_tx                       10631  accepted
    usb_rx                       11225  accepted
    usb_device                   30545  accepted
    edge_meter                    8314  accepted
    ws2812                        9121  accepted
    ws2812_standard               9121  accepted
    ethernet                      9162  accepted
    one_wire                      9361  accepted
    ps2                           9304  accepted
    jtag                          8428  accepted
    can                          10382  accepted
    dshot600                      8647  accepted
    sent                          9527  accepted
    cec                          10683  accepted
    spi_cs_mode0                  8698  accepted
    spi_cs_mode1                  8698  accepted
    spi_cs_mode2                  8698  accepted
    spi_cs_mode3                  8698  accepted
    spi_cs_mode0_default_pins     8698  accepted
    spi_cs_mode1_default_pins     8698  accepted
    spi_cs_mode2_default_pins     8698  accepted
    spi_cs_mode3_default_pins     8698  accepted
    spi_target_mode0              8987  accepted
    spi_target_mode1              8972  accepted
    spi_target_mode2              8987  accepted
    spi_target_mode3              8972  accepted
    swd                          13926  accepted
    table                        10310  accepted
    table_open_drain             10310  accepted
    asm/blink                     8251  accepted
    asm/crc_send                  8377  accepted
    asm/data_stream               8254  accepted
    asm/edge_logger_echo          8401  accepted
    asm/edge_logger_wire          8320  accepted
    asm/ethernet                  9162  accepted
    asm/fault_release             8192  accepted
    asm/i2c_master_marked         9793  accepted
    asm/i2c_start_watch           8308  accepted
    asm/quiet_watch                392  refused at 8, reason 0
    asm/scl_rise                  8278  accepted
    asm/scrub                     8192  accepted
    asm/self_check_wire           9695  accepted
    asm/uart_rx_wire              8575  accepted
    asm/uart_tx                   8428  accepted
    asm/uart_tx_host_rate         8434  accepted
    asm/wrapped_loop              8301  accepted
    bench/uart_tx_9600            8434  accepted
    bench/uart_tx_19200           8434  accepted
    bench/uart_tx_38400           8434  accepted
    bench/uart_tx_57600           8434  accepted
    bench/uart_tx_115200          8434  accepted
    bench/uart_tx_230400          8434  accepted
    bench/i2c_master             10178  accepted
    bench/i2c_master_stretch     12388  accepted
    bench/start_hold              8192  accepted
    bench/i2c_standard           10208  accepted
    bench/i2c_fast               10193  accepted
    bench/sk6812                  9311  accepted
    bench/ethernet                9162  accepted
    bench/one_wire                9361  accepted
    bench/ps2                     9304  accepted
    bench/can                    10540  accepted
    bench/can_sender             10564  accepted
    bench/can_receiver           18999  accepted
    bench/cec                    10683  accepted
    bench/spi_cs_mode0            8698  accepted
    bench/spi_cs_mode1            8698  accepted
    bench/spi_cs_mode2            8698  accepted
    bench/spi_cs_mode3            8698  accepted
    bench/swd                    13926  accepted
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
            ~floor:case.floor
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
  [%expect {| ((!trials 200) (!refused 124)) |}]
;;

(* A one-word corruption of a firmware for each reason a random search over six firmwares
   found the model refusing for, under the setup given, then for the reasons it did not, a
   row marked captured or awaiting where no way into it can be: all walked in one
   simulation, each verdict as the model's, and each refusal's flags cleared by the walk
   after it. *)
let%expect_test "a refusal for every reason found, one walk after another" =
  let corruptions =
    (* firmware, in the program (or the certificate), at, value, loaded, floor, single
       edge *)
    [ "uart_tx", false, 309, 0x1e62, None, false, false
    ; "uart_tx", false, 423, 0xa505, None, false, false
    ; "uart_tx", false, 1, 0x1dce, Some 255, false, false
    ; "uart_tx", true, 34, 0xe206, Some 42, false, true
    ; "uart_rx", true, 286, 0x9041, None, false, true
    ; "uart_rx", false, 506, 0x2880, None, false, true
    ; "uart_tx", false, 320, 0x5bba, None, false, false
    ; "uart_tx", true, 73, 0x88c7, None, false, false
    ; "i2c_master", false, 102, 0x83b0, None, false, false
    ; "uart_rx", true, 301, 0xc445, None, false, true
    ; "i2c_master", false, 433, 0x9980, Some 218, false, false
    ; "uart_tx", false, 482, 0x918e, None, false, false
    ]
  in
  let corrupted =
    List.map
      corruptions
      ~f:(fun (name, in_program, at, value, loaded, floor, single_edge) ->
        let w = walk_of name in
        let replace list =
          List.mapi list ~f:(fun n x -> if n = at % List.length list then value else x)
        in
        { w with
          loaded
        ; floor
        ; single_edge
        ; words = (if in_program then replace w.words else w.words)
        ; certificate = (if in_program then w.certificate else replace w.certificate)
        })
  in
  let marked =
    List.map
      [ "uart_tx", 2, `Awaiting
      ; "i2c_master", 12, `Captured
      ; "i2c_master", 12, `Awaiting
      ]
      ~f:(fun (name, pc, mark) ->
        walk_of
          name
          ~edit:
            (edit_row pc ~f:(fun r ->
               match mark with
               | `Captured -> { r with captured = Bits.vdd }
               | `Awaiting -> { r with awaiting = Bits.vdd })))
  in
  print_walks ~random_initial_state:`All (corrupted @ marked @ [ walk_of "uart_tx" ]);
  [%expect
    {|
    refused at 8, reason 0
    refused at 1, reason 3
    refused at 1, reason 5
    refused at 7, reason 6
    refused at 1, reason 7
    refused at 2, reason 8
    refused at 10, reason 13
    refused at 14, reason 15
    refused at 24, reason 16
    refused at 18, reason 17
    refused at 68, reason 18
    refused at 291, reason 30
    refused at 1, reason 10
    refused at 4, reason 19
    refused at 4, reason 20
    accepted
    |}]
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
        ~floor:case.floor
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

(* Walks at the edges of what a host sets up, one simulation: a certificate at the top of
   memory, wrapping to its bottom, then at 0; a side-set count of 3, which only the host
   can write; a loaded period of 0x5a5; a row with an arm no way into it reaches, which
   only a dictionary holds; 150 jumps, each to the next, so the search and the entry
   pointer pass 128; and, after a refusal at a stored row, a program wrapping at pc 0. *)
let%expect_test "walks at the edges of the setup" =
  let uart_tx = walk_of "uart_tx" in
  let host_rate = walk_of "uart_tx_host_rate" in
  let loaded = 0x5a5 in
  let program config words =
    { uart_tx with
      config
    ; loaded = None
    ; floor = false
    ; single_edge = false
    ; words
    ; certificate = Load_check.of_program ~config words |> ok_exn |> Load_check.to_words
    }
  in
  let jumps =
    List.init 150 ~f:(fun pc ->
      Isa.to_word ~side_set_count:0 (Jmp { cond = Always; target = pc + 1 }) |> ok_exn)
  in
  print_walks
    [ { uart_tx with base = 0x1ff }
    ; uart_tx
    ; { uart_tx with config = { uart_tx.config with side_set_count = 3 } }
    ; { host_rate with
        loaded = Some loaded
      ; certificate =
          Load_check.of_program
            ?period:(Option.some_if (not host_rate.floor) loaded)
            ?period_floor:(Option.some_if host_rate.floor loaded)
            ~single_capture_edge:host_rate.single_edge
            ~config:host_rate.config
            host_rate.words
          |> ok_exn
          |> Load_check.to_words
      }
    ; walk_of
        "bench/can_receiver"
        ~edit:
          (edit_row 29 ~f:(fun r ->
             let width = Bits.width r.arm_lo in
             { r with
               arm_lo = Bits.of_unsigned_int ~width 0xffff00
             ; arm_hi = Bits.ones width
             }))
    ; program Program_config.default jumps
    ; walk_of "uart_tx" ~edit:(edit_row 2 ~f:(fun r -> { r with awaiting = Bits.vdd }))
    ; program { Program_config.default with wrap_top = 0 } (Firmware.assemble "set x, 1")
    ];
  [%expect {|
    accepted
    accepted
    accepted
    accepted
    refused at 31, reason 8
    accepted
    refused at 1, reason 10
    accepted
    |}]
;;

(* An abort on each of a walk's first 200 cycles, so in every state it passes through,
   refuses it as aborted at the pc it reached; the walk after them is as the model's. *)
let%expect_test "an abort refuses a walk wherever it is" =
  let walk = walk_of "i2c_master" in
  let aborted = List.init 200 ~f:(fun n -> { walk with abort_at = Some (n + 1) }) in
  let verdicts = run_walks (aborted @ [ walk ]) |> List.map ~f:fst in
  let reached =
    List.take verdicts (List.length aborted)
    |> List.map ~f:(function
      | `Rejected (pc, reason) when reason = Load_checker.aborted -> pc
      | verdict -> raise_s [%message "not aborted" (show verdict)])
  in
  if not (List.is_sorted reached ~compare:Int.compare)
  then print_endline "a later abort reached an earlier pc";
  print_s
    [%message
      ""
        ~reached:(List.dedup_and_sort reached ~compare:Int.compare : int list)
        ~last:(show (List.last_exn verdicts))
        ~model:(show (walk_model walk))];
  [%expect {| ((reached (0 1 2 3 4)) (last accepted) (model accepted)) |}]
;;
