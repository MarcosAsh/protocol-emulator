open! Core
open Usb_host

(* A keyboard and a mouse behind one interrupt endpoint, told apart by the report ID. *)
let report_descriptor =
  [ 0x05
  ; 0x01
  ; 0x09
  ; 0x06
  ; 0xa1
  ; 0x01
  ; 0x85
  ; 0x01
  ; 0x05
  ; 0x07
  ; 0x19
  ; 0xe0
  ; 0x29
  ; 0xe7
  ; 0x15
  ; 0x00
  ; 0x25
  ; 0x01
  ; 0x75
  ; 0x01
  ; 0x95
  ; 0x08
  ; 0x81
  ; 0x02
  ; 0x95
  ; 0x06
  ; 0x75
  ; 0x08
  ; 0x15
  ; 0x00
  ; 0x25
  ; 0x65
  ; 0x05
  ; 0x07
  ; 0x19
  ; 0x00
  ; 0x29
  ; 0x65
  ; 0x81
  ; 0x00
  ; 0xc0
  ; 0x05
  ; 0x01
  ; 0x09
  ; 0x02
  ; 0xa1
  ; 0x01
  ; 0x85
  ; 0x02
  ; 0x09
  ; 0x01
  ; 0xa1
  ; 0x00
  ; 0x05
  ; 0x09
  ; 0x19
  ; 0x01
  ; 0x29
  ; 0x03
  ; 0x15
  ; 0x00
  ; 0x25
  ; 0x01
  ; 0x95
  ; 0x03
  ; 0x75
  ; 0x01
  ; 0x81
  ; 0x02
  ; 0x95
  ; 0x01
  ; 0x75
  ; 0x05
  ; 0x81
  ; 0x03
  ; 0x05
  ; 0x01
  ; 0x09
  ; 0x30
  ; 0x09
  ; 0x31
  ; 0x15
  ; 0x81
  ; 0x25
  ; 0x7f
  ; 0x75
  ; 0x08
  ; 0x95
  ; 0x02
  ; 0x81
  ; 0x06
  ; 0xc0
  ; 0xc0
  ]
;;

let device_descriptor =
  [ 18; 1; 0x10; 0x01; 0; 0; 0; 8; 0x09; 0x12; 0x01; 0x00; 0x00; 0x01; 0; 0; 0; 1 ]
;;

let configuration_descriptor =
  let report_length = List.length report_descriptor in
  [ 9; 2; 34; 0; 1; 1; 0; 0xa0; 50 ]
  @ [ 9; 4; 0; 0; 1; 3; 0; 0; 0 ]
  @ [ 9; 0x21; 0x11; 0x01; 0; 1; 0x22; report_length land 0xff; report_length lsr 8 ]
  @ [ 7; 5; 0x81; 3; 8; 0; 10 ]
;;

let descriptors =
  [ 1, device_descriptor; 2, configuration_descriptor; 0x22, report_descriptor ]
;;

let%expect_test "a host enumerates the keyboard and mouse and reads reports" =
  let t = create ~descriptors ~latency:6000 () in
  let read name request expected =
    let bytes = control_in t request in
    print_s
      [%message
        name
          ~bytes:(List.length bytes : int)
          ~correct:([%equal: int list] bytes expected : bool)
          ~naks_so_far:(naks t : int)]
  in
  reset t;
  read
    "first eight bytes of the device descriptor"
    (Request.get_descriptor ~kind:1 ~length:8 ())
    (List.take device_descriptor 8);
  reset t;
  control_out t (Request.set_address 7);
  print_s [%message "address set" ~naks_so_far:(naks t : int)];
  read
    "device descriptor"
    (Request.get_descriptor ~kind:1 ~length:18 ())
    device_descriptor;
  read
    "configuration header"
    (Request.get_descriptor ~kind:2 ~length:9 ())
    (List.take configuration_descriptor 9);
  read
    "configuration"
    (Request.get_descriptor ~kind:2 ~length:34 ())
    configuration_descriptor;
  control_out t (Request.set_configuration 1);
  read
    "report descriptor"
    (Request.get_descriptor
       ~interface:true
       ~kind:0x22
       ~length:(List.length report_descriptor)
       ())
    report_descriptor;
  let poll () = interrupt_in t ~endpoint:1 in
  print_s [%message "nothing to report" ~_:(poll () : int list option)];
  (* the letter h down, then up, then the mouse five right and three up *)
  List.iter
    [ [ 1; 0; 0x0b; 0; 0; 0; 0; 0 ]; [ 1; 0; 0; 0; 0; 0; 0; 0 ]; [ 2; 0; 5; 0xfd ] ]
    ~f:(fun payload ->
      report t payload;
      let rec until_data tries =
        match poll () with
        | Some bytes -> bytes
        | None when tries > 0 -> until_data (tries - 1)
        | None -> []
      in
      print_s [%message "report" ~_:(until_data 20 : int list)]);
  (* a report is waiting when the host starts a control transfer: the core takes it out of
     the way, the board hears of it and puts it back afterwards *)
  report t [ 2; 1; 0; 0 ];
  read
    "device descriptor with a report in the way"
    (Request.get_descriptor ~kind:1 ~length:18 ())
    device_descriptor;
  let rec until_data tries =
    match poll () with
    | Some bytes -> bytes
    | None when tries > 0 -> until_data (tries - 1)
    | None -> []
  in
  print_s [%message "the report afterwards" ~_:(until_data 20 : int list)];
  (* after a bus reset the device is back at address 0 *)
  reset t;
  read
    "device descriptor at address 0 after a reset"
    (Request.get_descriptor ~kind:1 ~length:8 ())
    (List.take device_descriptor 8);
  print_s [%message (faults t : Protocol_emulator.Machine.Fault.t)];
  [%expect
    {|
    ("first eight bytes of the device descriptor" (bytes 8) (correct true)
     (naks_so_far 1))
    ("address set" (naks_so_far 2))
    ("device descriptor" (bytes 18) (correct true) (naks_so_far 5))
    ("configuration header" (bytes 9) (correct true) (naks_so_far 7))
    (configuration (bytes 34) (correct true) (naks_so_far 12))
    ("report descriptor" (bytes 93) (correct true) (naks_so_far 25))
    ("nothing to report" ())
    (report (1 0 11 0 0 0 0 0))
    (report (1 0 0 0 0 0 0 0))
    (report (2 0 5 253))
    ("device descriptor with a report in the way" (bytes 18) (correct true)
     (naks_so_far 38))
    ("the report afterwards" (2 1 0 0))
    ("device descriptor at address 0 after a reset" (bytes 8) (correct true)
     (naks_so_far 39))
    ("faults t"
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;

(* The same conversation against the hardware: every load of the core is run again in the
   lockstep harness with the pins and the fifo writes the model saw, cycle for cycle, and
   the Hardcaml core has to agree with the model on all of its state after every edge. *)
let%expect_test "the enumeration in lockstep with the hardware" =
  let t = create ~reset_cycles:4000 ~descriptors ~latency:3000 () in
  reset t;
  let (_ : int list) = control_in t (Request.get_descriptor ~kind:1 ~length:8 ()) in
  reset t;
  control_out t (Request.set_address 7);
  let (_ : int list) = control_in t (Request.get_descriptor ~kind:1 ~length:18 ()) in
  let (_ : int list) = control_in t (Request.get_descriptor ~kind:2 ~length:34 ()) in
  control_out t (Request.set_configuration 1);
  report t [ 2; 1; 0; 0 ];
  let (_ : int list) = control_in t (Request.get_descriptor ~kind:1 ~length:8 ()) in
  let rec until_data tries =
    match interrupt_in t ~endpoint:1 with
    | Some bytes -> bytes
    | None when tries > 0 -> until_data (tries - 1)
    | None -> []
  in
  print_s [%message "report" ~_:(until_data 20 : int list)];
  List.iter (recording t) ~f:(fun (address, cycles) ->
    let cycles = Array.of_list cycles in
    let program =
      Firmware.assemble (Firmware.usb_device ~address ~half_period:(bit_period / 2))
    in
    let (_ : Protocol_emulator.Machine.t), mismatch =
      Lockstep.run
        ~cycles:(Array.length cycles)
        ~config:Firmware.usb_device_config
        ~program
        ~preload:[ bit_period ]
        ~inputs:(fun n -> fst cycles.(n))
        ~host:(fun n -> { Lockstep.Host.idle with tx = snd cycles.(n); pop_rx = true })
        ()
    in
    print_s
      [%message
        "load"
          (address : int)
          ~cycles:(Array.length cycles : int)
          ~held:(Option.is_none mismatch : bool)]);
  [%expect
    {|
    (report (2 1 0 0))
    (load (address 0) (cycles 5441) (held true))
    (load (address 0) (cycles 28000) (held true))
    (load (address 0) (cycles 21215) (held true))
    (load (address 7) (cycles 168032) (held true))
    |}]
;;
