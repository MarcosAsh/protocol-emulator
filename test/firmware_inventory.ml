open! Core
open Protocol_emulator

(* Every firmware the repo runs: the library, each test/*.asm under test/firmware.mk's
   assumptions, and the outside chip acts' firmware. *)

type t =
  { name : string
  ; timed : Timed_program.t
  ; period : int option
  ; single_capture_edge : bool
  }

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

let all = library @ asm_cases @ bench_cases
