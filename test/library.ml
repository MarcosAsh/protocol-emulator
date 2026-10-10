open! Core

(* in the order of the certificates, then the ones with none *)
let protocols =
  [ Uart.protocol
  ; Spi.protocol
  ; I2c.protocol
  ; Usb.protocol
  ; Edge_meter.protocol
  ; Ws2812.protocol
  ; Ethernet.protocol
  ; One_wire.protocol
  ; Ps2.protocol
  ; Jtag.protocol
  ; Can_node.protocol
  ; Dshot.protocol
  ; Sent.protocol
  ; Cec.protocol
  ; Swd.protocol
  ; Spi_cs.protocol
  ]
;;

let each f = List.concat_map protocols ~f
let certified = each (fun p -> p.certified)
let time_triggered = each (fun p -> p.time_triggered)
let stamped = Uart.stamped

let find_certified_exn name =
  match
    List.find
      ((stamped :: certified) @ time_triggered)
      ~f:(fun t -> String.equal t.name name)
  with
  | Some t -> t
  | None -> raise_s [%message "no such firmware" (name : string)]
;;

let bench = each (fun p -> p.bench)

let find_bench_exn name =
  match
    List.find
      (each (fun p -> p.loaded_from_hex) @ bench)
      ~f:(fun t -> String.equal t.name name)
  with
  | Some t -> t
  | None -> raise_s [%message "no such bench firmware" (name : string)]
;;

let limits = each (fun p -> p.limits)
let exempt = each (fun p -> p.unlimited)
let scenarios = each (fun p -> p.scenarios)
let decoded = each (fun p -> p.decoded)

(* in the order of the firmware, whichever protocol has it *)
let in_firmware_order all ~name =
  List.filter_map
    ((certified @ time_triggered) @ [ stamped ])
    ~f:(fun c -> List.find all ~f:(fun x -> String.equal (name x) c.name))
;;

let swept = in_firmware_order (each (fun p -> p.swept)) ~name:(fun s -> s.Swept.name)
let not_swept = in_firmware_order (each (fun p -> p.not_swept)) ~name:fst
