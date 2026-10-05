open! Core
open Hardcaml
open Protocol_emulator
module K = Kernel.Make (Bits)

(* Every firmware the repo runs, against the certificate the chip would check: no Spacing,
   no affine offset, and rows stored only at the wrap and jump targets, every other row
   the tightest the row before it maps into. A firmware refused here could not start on a
   chip that enforces the kernel. *)

type case =
  { name : string
  ; timed : Timed_program.t
  ; period : int option
  ; single_capture_edge : bool
  }

let half = 1 lsl (Isa.timer_bits - 1)
let data_max = (1 lsl Isa.data_bits) - 1
let signed n = Bits.of_signed_int ~width:Isa.timer_bits n
let timer n = Bits.of_unsigned_int ~width:Isa.timer_bits n
let data n = Bits.of_unsigned_int ~width:Isa.data_bits n

let reduce (r : Bits.t Kernel.Row.t) =
  if Bits.to_bool Bits.(r.phase_lo >+ r.phase_hi)
  then r
  else
    { r with slope = signed 0; offset_lo = signed (-half); offset_hi = signed (half - 1) }
;;

let full : Bits.t Kernel.Row.t =
  { ((Kernel.Table.of_analyser []).(0)) with
    phase_lo = signed (-half)
  ; phase_hi = signed (half - 1)
  ; period_lo = data 0
  ; period_hi = data data_max
  ; x_lo = data 0
  ; x_hi = data data_max
  ; y_lo = data 0
  ; y_hi = data data_max
  ; arm_lo = timer 0
  ; arm_hi = Bits.ones Isa.timer_bits
  }
;;

(* pc 0 of a table is always the full row *)
let unreached = (Kernel.Table.of_analyser []).(1)

(* the largest [v] in [lo, hi] with [f v], [f] true up to some point *)
let rec last_true ~lo ~hi f =
  if lo >= hi
  then lo
  else (
    let mid = lo + ((hi - lo + 1) / 2) in
    if f mid then last_true ~lo:mid ~hi f else last_true ~lo ~hi:(mid - 1) f)
;;

let first_true ~lo ~hi f = -last_true ~lo:(-hi) ~hi:(-lo) (fun v -> f (-v))

let derive case ~config ~word ~row ~target =
  let loaded =
    { With_valid.valid = Bits.of_bool (Option.is_some case.period)
    ; value = data (Option.value case.period ~default:0)
    }
  in
  let capture =
    { Kernel.Capture.pin =
        Bits.of_unsigned_int
          ~width:Isa.Field.wait_index.width
          config.Program_config.capture_pin
    ; rising = Bits.of_bool config.capture_rising
    ; single_edge = Bits.of_bool case.single_capture_edge
    }
  in
  let holds next =
    (K.conjuncts
       ~side_set_count:(Bits.of_unsigned_int ~width:2 config.side_set_count)
       ~fraction:(Bits.of_bool (config.period_fraction <> 0))
       ~loaded
       ~capture
       ~spacing:K.no_spacing
       ~word
       ~row
       ~next
       ~target)
      .next
  in
  let ok field next = Bits.to_bool (field (holds next)) in
  let phase = Kernel.Holds.(fun h -> h.phase) in
  let period = Kernel.Holds.(fun h -> h.period) in
  let y = Kernel.Holds.(fun h -> h.y) in
  let arm = Kernel.Holds.(fun h -> h.arm) in
  let flags =
    List.find
      [ true, true; true, false; false, true; false, false ]
      ~f:(fun (c, a) ->
        let next = { full with captured = Bits.of_bool c; awaiting = Bits.of_bool a } in
        ok (fun h -> Bits.(h.Kernel.Holds.captured &: h.awaiting)) next)
    |> Option.value ~default:(false, false)
  in
  let base =
    { full with captured = Bits.of_bool (fst flags); awaiting = Bits.of_bool (snd flags) }
  in
  let phase_lo =
    last_true ~lo:(-half) ~hi:(half - 1) (fun v ->
      ok phase { base with phase_lo = signed v })
  in
  let phase_hi =
    first_true ~lo:(-half) ~hi:(half - 1) (fun v ->
      ok phase { base with phase_hi = signed v })
  in
  let period_lo =
    last_true ~lo:0 ~hi:data_max (fun v -> ok period { base with period_lo = data v })
  in
  let period_hi =
    first_true ~lo:0 ~hi:data_max (fun v -> ok period { base with period_hi = data v })
  in
  let x = Kernel.Holds.(fun h -> h.x) in
  let x_lo = last_true ~lo:0 ~hi:data_max (fun v -> ok x { base with x_lo = data v }) in
  let x_hi = first_true ~lo:0 ~hi:data_max (fun v -> ok x { base with x_hi = data v }) in
  let y_lo = last_true ~lo:0 ~hi:data_max (fun v -> ok y { base with y_lo = data v }) in
  let y_hi = first_true ~lo:0 ~hi:data_max (fun v -> ok y { base with y_hi = data v }) in
  let arm_lo =
    last_true
      ~lo:0
      ~hi:((1 lsl Isa.timer_bits) - 1)
      (fun v -> ok arm { base with arm_lo = timer v })
  in
  let arm_hi =
    first_true
      ~lo:0
      ~hi:((1 lsl Isa.timer_bits) - 1)
      (fun v -> ok arm { base with arm_hi = timer v })
  in
  if phase_lo > phase_hi
     || period_lo > period_hi
     || x_lo > x_hi
     || y_lo > y_hi
     || arm_lo > arm_hi
  then unreached
  else
    { base with
      phase_lo = signed phase_lo
    ; phase_hi = signed phase_hi
    ; period_lo = data period_lo
    ; period_hi = data period_hi
    ; x_lo = data x_lo
    ; x_hi = data x_hi
    ; y_lo = data y_lo
    ; y_hi = data y_hi
    ; arm_lo = timer arm_lo
    ; arm_hi = timer arm_hi
    }
;;

let size = 1 lsl Isa.pc_bits

let stored ~config ~words =
  let targets =
    List.filter_mapi words ~f:(fun _ w ->
      match Isa.of_word ~side_set_count:config.Program_config.side_set_count w with
      | Ok (Jmp { target; _ }) -> Some target
      | _ -> None)
  in
  Int.Set.of_list (config.wrap_bottom :: targets) |> Fn.flip Set.remove 0
;;

let check case table =
  Kernel.check
    ?period:case.period
    ~single_capture_edge:case.single_capture_edge
    ~config:(Timed_program.config case.timed)
    ~words:(Timed_program.words case.timed)
    table
;;

let row_words = 3

let table_words ~stored_pcs (table : Bits.t Kernel.Row.t array) =
  let intervals =
    Set.to_list stored_pcs
    |> List.concat_map ~f:(fun pc ->
      let r = table.(pc) in
      List.map
        [ r.phase_lo, r.phase_hi
        ; r.period_lo, r.period_hi
        ; r.x_lo, r.x_hi
        ; r.y_lo, r.y_hi
        ; r.arm_lo, r.arm_hi
        ]
        ~f:(fun (lo, hi) -> Bits.to_unsigned_int lo, Bits.to_unsigned_int hi))
    |> List.dedup_and_sort ~compare:[%compare: int * int]
  in
  (row_words * Set.length stored_pcs) + (3 * List.length intervals)
;;

let report case =
  let config = Timed_program.config case.timed in
  let words = Timed_program.words case.timed in
  let full_table = Kernel.Table.of_analyser (Timed_program.rows case.timed) in
  let reduced = Array.map full_table ~f:reduce in
  let stored_pcs = stored ~config ~words in
  let word pc = data (List.nth words pc |> Option.value ~default:0) in
  let derived = Array.create ~len:size unreached in
  derived.(0) <- reduced.(0);
  for pc = 0 to size - 2 do
    let next, target =
      K.successors
        ~wrap_top:(Bits.of_unsigned_int ~width:Isa.pc_bits config.wrap_top)
        ~wrap_bottom:(Bits.of_unsigned_int ~width:Isa.pc_bits config.wrap_bottom)
        ~pc:(Bits.of_unsigned_int ~width:Isa.pc_bits pc)
        ~word:(word pc)
    in
    derived.(pc + 1)
    <- (if Set.mem stored_pcs (pc + 1)
        then reduced.(pc + 1)
        else if Bits.to_unsigned_int next = pc + 1 && pc < List.length words
        then
          derive
            case
            ~config
            ~word:(word pc)
            ~row:derived.(pc)
            ~target:reduced.(Bits.to_unsigned_int target)
        else unreached)
  done;
  let verdict table = if Result.is_ok (check case table) then "ok" else "REFUSED" in
  printf
    "%-22s %5d  %4s  %7s  %7s  %6d  %5d\n"
    case.name
    (List.length words)
    (verdict full_table)
    (verdict reduced)
    (verdict derived)
    (Set.length stored_pcs)
    (table_words ~stored_pcs derived)
;;

let library =
  List.map Certified.all ~f:(fun (t : Certified.t) ->
    (* the floor where there is one, as test_certified.ml checks the table at *)
    let period = Option.first_some t.period_floor t.period in
    { name = t.name
    ; timed =
        Timed_program.of_source_exn
          ?period:(if Option.is_some t.period_floor then None else t.period)
          ?period_floor:t.period_floor
          ~single_capture_edge:t.single_capture_edge
          ~config:t.config
          t.source
    ; period
    ; single_capture_edge = t.single_capture_edge
    })
;;

(* test/firmware.mk's assumptions, by file *)
let asm_cases =
  let assume =
    [ "uart_rx_wire", (None, true, Some 20, true, None)
    ; "uart_tx_host_rate", (Some 434, false, None, false, None)
    ; "ethernet", (Some 64000, false, None, false, Some 16)
    ; "data_stream", (None, false, None, false, Some 16)
    ; "self_check_wire", (Some 17, false, Some 20, true, Some 16)
    ]
  in
  Stdlib.Sys.readdir "."
  |> Array.to_list
  |> List.filter ~f:(String.is_suffix ~suffix:".asm")
  |> List.sort ~compare:String.compare
  |> List.filter_map ~f:(fun file ->
    let name = String.chop_suffix_exn file ~suffix:".asm" in
    let period, single_capture_edge, capture_pin, falling, autopull =
      List.Assoc.find assume name ~equal:String.equal
      |> Option.value ~default:(None, false, None, false, None)
    in
    let config =
      { Program_config.default with
        capture_pin = Option.value capture_pin ~default:Program_config.default.capture_pin
      ; capture_rising = not falling
      ; autopull = Option.is_some autopull
      ; autopull_data = Option.is_some autopull
      ; pull_threshold =
          Option.value autopull ~default:Program_config.default.pull_threshold
      }
    in
    let floor = String.equal name "self_check_wire" in
    match
      Timed_program.check
        ?period:(if floor then None else period)
        ?period_floor:(if floor then period else None)
        ~single_capture_edge
        ~config
        (In_channel.read_all file)
    with
    | Ok timed -> Some { name = "asm/" ^ name; timed; period; single_capture_edge }
    | Error _ -> None)
;;

(* the outside chip acts' firmware, as test/python/write_bench_firmware.ml checks it *)
let bench_cases =
  let sda = 14
  and scl = 15 in
  let case name ?period ?period_floor ?(single_capture_edge = false) ~config source =
    { name = "bench/" ^ name
    ; timed =
        Timed_program.of_source_exn
          ?period
          ?period_floor
          ~single_capture_edge
          ~config
          source
    ; period = Option.first_some period_floor period
    ; single_capture_edge
    }
  in
  [ case
      "i2c_master"
      ~period_floor:31
      ~config:Firmware.i2c_config
      Firmware.i2c_master_host_rate
  ; case
      "i2c_master_stretch"
      ~period_floor:31
      ~config:Firmware.i2c_stretch_config
      Firmware.i2c_master_stretch_host_rate
  ; case
      "can_sender"
      ~period_floor:Can_node.Sender.shortest_period
      ~config:Can_node.Sender.config
      (Timed_program.source Can_node.Sender.firmware)
  ; case
      "can_receiver"
      ~period:Can_node.Receiver.period
      ~single_capture_edge:true
      ~config:Can_node.Receiver.config
      (Timed_program.source Can_node.Receiver.firmware)
  ; case "sk6812" ~config:Ws2812.config (Ws2812.firmware ~third:16 ~tail:7)
  ; case
      "start_hold"
      ~config:(Firmware.start_hold_config ~scl)
      (Firmware.start_hold ~sda ~scl)
  ; case
      "swd"
      ~period_floor:Swd.shortest_half
      ~config:Swd.config
      (Timed_program.source Swd.firmware)
  ]
  @ List.map Spi_cs.Mode.all ~f:(fun mode ->
    case
      (sprintf "spi_cs_mode%d" (Spi_cs.Mode.to_int mode))
      ~config:Spi_cs.config
      (Spi_cs.master ~mode ~half_period:8 ~setup:4 ~hold:8))
;;

let%expect_test "every firmware against the on-chip certificate" =
  printf
    "%-22s %5s  %4s  %7s  %7s  %6s  %5s\n"
    "firmware"
    "words"
    "full"
    "reduced"
    "derived"
    "stored"
    "table";
  List.iter (library @ asm_cases @ bench_cases) ~f:report;
  [%expect
    {|
    firmware               words  full  reduced  derived  stored  table
    uart_tx                   15    ok       ok       ok       2     24
    uart_tx16                 15    ok       ok       ok       2     24
    uart_tx_host_rate         17    ok       ok       ok       2     24
    uart_rx                   19    ok       ok       ok       3     30
    spi_master                16    ok       ok       ok       2     24
    spi_slave                  6    ok       ok       ok       1     12
    i2c_master                99    ok       ok       ok      12     87
    i2c_slave                 72    ok       ok       ok      11     48
    i2c_logger                73    ok       ok       ok       6     48
    usb_tx                    65    ok       ok       ok      14     96
    usb_rx                    29    ok       ok       ok       5     39
    usb_device               470    ok       ok       ok     109    516
    edge_meter                12    ok       ok       ok       1     15
    ws2812                    32    ok       ok       ok       6     57
    ethernet                  24    ok       ok       ok       4     39
    one_wire                  48    ok       ok       ok       7     63
    ps2                       65    ok       ok       ok       7     51
    jtag                      15    ok       ok       ok       2     24
    can                       56    ok       ok       ok      12     81
    dshot600                  21    ok       ok       ok       3     36
    sent                      83    ok       ok       ok       7     69
    cec                       71    ok       ok       ok      16    108
    asm/data_stream            4    ok       ok       ok       1     12
    asm/edge_logger_echo      13    ok       ok       ok       3     18
    asm/edge_logger_wire       8    ok       ok       ok       2     15
    asm/ethernet              24    ok       ok       ok       4     39
    asm/i2c_master_marked     84    ok       ok       ok      10     75
    asm/i2c_start_watch       10    ok       ok       ok       1     15
    asm/quiet_watch           23    ok  REFUSED  REFUSED       4     27
    asm/scl_rise              12    ok       ok       ok       1     12
    asm/scrub                  4    ok       ok       ok       0      0
    asm/self_check_wire       69    ok       ok       ok       7     54
    asm/uart_rx_wire          19    ok       ok       ok       3     30
    asm/uart_tx               15    ok       ok       ok       2     24
    asm/uart_tx_host_rate     17    ok       ok       ok       2     24
    asm/wrapped_loop           5    ok       ok       ok       1     15
    bench/i2c_master         101    ok       ok       ok      12     87
    bench/i2c_master_stretch   163    ok       ok       ok      28    144
    bench/can_sender          64    ok       ok       ok      12     81
    bench/can_receiver       242    ok       ok       ok      44    288
    bench/sk6812              32    ok       ok       ok       6     57
    bench/start_hold           9    ok       ok       ok       0      0
    bench/swd                232    ok       ok       ok      34    195
    bench/spi_cs_mode0        33    ok       ok       ok       3     33
    bench/spi_cs_mode1        33    ok       ok       ok       3     33
    bench/spi_cs_mode2        33    ok       ok       ok       3     33
    bench/spi_cs_mode3        33    ok       ok       ok       3     33
    |}]
;;
