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
  List.map Library.certified ~f:(fun (t : Certified.t) ->
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
  List.map Library.bench ~f:(fun (bench : Bench.t) ->
    let period, single_capture_edge =
      match bench.assumption with
      | Nothing -> None, false
      | Floor period | Period period -> Some period, false
      | Receiver period -> Some period, true
    in
    { name = "bench/" ^ bench.name
    ; timed = Bench.timed bench
    ; period
    ; single_capture_edge
    })
;;

let all = library @ asm_cases @ bench_cases
