open! Core
open Protocol_emulator

let rx_pin = 1

(* Can.tx_pin, written out for [%firmware] to read *)
let tx_pin = 6

let () =
  if tx_pin <> Can.tx_pin
  then raise_s [%message "BUG: CTX is not Can.tx_pin" (tx_pin : int)]
;;

module Receiver = struct
  let period = 96
  let sample = 72
  let shortest_period = 63

  let config =
    { Program_config.default with
      in_base = rx_pin
    ; in_count = 1
    ; out_base = tx_pin
    ; set_base = tx_pin
    ; jmp_pin = rx_pin
    ; capture_pin = rx_pin
    ; capture_rising = false
    ; in_shift = Left
    ; out_shift = Right
    ; autopush = true
    ; push_threshold = 16
    ; crc_width = 15
    ; crc_poly = 0x4599
    ; crc_init = 0
    ; crc_reflect = false
    }
  ;;

  let lines = String.concat ~sep:"\n"

  (* the top five bits by [set], then a doubling per bit left *)
  let load_period period =
    let width = Int.ceil_log2 (period + 1) in
    let top = period lsr Int.max 0 (width - 5) in
    [%string "    set p, %{top#Int}"]
    :: List.concat_map
         (List.range ~stride:(-1) (width - 6) (-1))
         ~f:(fun bit ->
           "    add p, p"
           :: (if (period lsr bit) land 1 = 1 then [ "    add p, 1" ] else []))
  ;;

  (* n added to t through y, which the caller sets again after: k equal parts of at most
     31, the rest in immediates of at most 7 *)
  let add_to_t n =
    let parts = (n + 30) / 31 in
    let part = n / Int.max parts 1 in
    let rec rest n = if n = 0 then [] else Int.min n 7 :: rest (n - Int.min n 7) in
    (if parts = 0 then [] else [ [%string "    set y, %{part#Int}"] ])
    @ List.init parts ~f:(fun _ -> "    add t, y")
    @ List.map (rest (n - (parts * part))) ~f:(fun r -> [%string "    add t, %{r#Int}"])
  ;;

  (* exactly n cycles of nops *)
  let delay n =
    List.init (n / 32) ~f:(fun _ -> "    nop [31]")
    @ if n % 32 = 0 then [] else [ [%string "    nop [%{n % 32 - 1#Int}]"] ]
  ;;

  (* One field's bits: x counts them down, y the run to a stuff bit, and the loop half is
     the last level. A recessive bit arms the capture, so the next fall retimes the bits,
     as can2040 does. Leaves at [high_end] or [low_end] by the last level. *)
  let field name ~sample ~high_end ~low_end =
    lines
      ([ [%string "%{name}_high:"]
       ; "    wait t+"
       ; "    in pins, 1"
       ; [%string "    jmp pin, %{name}_held_high"]
       ; [%string "%{name}_fell:"]
       ; [%string "    wait 0 pin %{rx_pin#Int}"]
       ; "    mov t, capture"
       ; "    add t, p"
       ]
       @ add_to_t (sample - 1)
       @ [ "    set y, 3"
         ; [%string "    jmp x--, %{name}_low"]
         ; [%string "    jmp %{low_end}"]
         ; [%string "%{name}_held_high:"]
         ; "    capture_arm"
         ; [%string "    jmp y--, %{name}_next_high"]
         ; "    wait t+                  ; a stuff bit, dominant"
         ; "    jmp pin, stuffing"
         ; [%string "    jmp %{name}_fell"]
         ; [%string "%{name}_next_high:"]
         ; [%string "    jmp x--, %{name}_high"]
         ; [%string "    jmp %{high_end}"]
         ; [%string "%{name}_low:"]
         ; "    wait t+"
         ; "    in pins, 1"
         ; [%string "    jmp pin, %{name}_rose"]
         ; [%string "    jmp y--, %{name}_next_low"]
         ; "    wait t+                  ; a stuff bit, recessive"
         ; [%string "    jmp pin, %{name}_rose"]
         ; "    jmp stuffing"
         ; [%string "%{name}_rose:"]
         ; "    capture_arm"
         ; "    set y, 3"
         ; [%string "    jmp x--, %{name}_high"]
         ; [%string "    jmp %{high_end}"]
         ; [%string "%{name}_next_low:"]
         ; [%string "    jmp x--, %{name}_low"]
         ; [%string "    jmp %{low_end}"]
         ])
  ;;

  (* isr holds RTR, IDE, r0 and the DLC, the ID gone in the first word. A frame with IDE
     or r0 recessive is refused; otherwise they go to the host and x is the data bits less
     one. An odd number of bytes starts with a zero byte, so they fill whole words. *)
  let header_end level =
    lines
      [ [%string "header_%{level}_end:"]
      ; "    mov osr, isr"
      ; "    out null, 4"
      ; "    out x, 2                 ; r0 and IDE"
      ; "    jmp x--, refused"
      ; "    mov x, osr               ; RTR"
      ; [%string "    jmp x--, remote_%{level}"]
      ; "    mov osr, isr"
      ; "    out null, 3"
      ; "    mov x, osr               ; the DLC's top bit"
      ; [%string "    jmp x--, eight_%{level}"]
      ; "    mov osr, ::isr"
      ; "    out null, 15"
      ; "    mov x, osr               ; the DLC's low bit"
      ; [%string "    jmp x--, odd_%{level}"]
      ; "    mov x, isr"
      ; "    push"
      ; "    add x, x"
      ; "    add x, x"
      ; "    add x, x"
      ; [%string "    jmp x--, data_%{level}"]
      ; "    set x, 14                ; no data: the CRC"
      ; [%string "    jmp crc_%{level}"]
      ; [%string "odd_%{level}:"]
      ; "    mov x, isr"
      ; "    push"
      ; "    in null, 8"
      ; "    add x, x"
      ; "    add x, x"
      ; "    add x, x"
      ; "    sub x, 1"
      ; [%string "    jmp data_%{level}"]
      ; [%string "eight_%{level}:"]
      ; "    push"
      ; "    set x, 31"
      ; "    add x, x"
      ; "    add x, 1                 ; eight bytes"
      ; [%string "    jmp data_%{level}"]
      ; [%string "remote_%{level}:"]
      ; "    push"
      ; "    set x, 14"
      ; [%string "    jmp crc_%{level}"]
      ]
  ;;

  let data_end level =
    lines
      [ [%string "data_%{level}_end:"]
      ; "    set x, 14"
      ; [%string "    jmp crc_%{level}"]
      ]
  ;;

  let source ~period ~sample =
    if sample < 1 || sample > period - 5
    then raise_s [%message "BUG: no room for the ACK" (period : int) (sample : int)];
    lines
      (load_period period
       @ [ "    set pins, 1              ; recessive"
         ; "    mov t, now"
         ; "    add t, p"
         ; "idle:"
         ; "    set x, 10"
         ; "quiet:"
         ; "    wait t+"
         ; "    jmp pin, recessive"
         ; "    jmp idle"
         ; "recessive:"
         ; "    jmp x--, quiet           ; eleven recessive bits: the bus is idle"
         ; "sof:"
         ; "    capture_arm"
         ; "    jmp pin, armed"
         ; "    mov t, now               ; a SOF edge came a few cycles before the arm"
         ; "    jmp sofed"
         ; "armed:"
         ; [%string "    wait 0 pin %{rx_pin#Int}             ; SOF, its edge in capture"]
         ; "    mov t, capture"
         ; "sofed:"
         ]
       @ add_to_t (sample - 1)
       @ [ "    wait t+"
         ; "    jmp pin, sof             ; recessive again: no SOF"
         ; "    crc_init"
         ; "    in null, 5               ; so the ID fills the first word"
         ; "    set y, 3"
         ; "    set x, 17                ; ID, RTR, IDE, r0 and the DLC"
         ; "    jmp header_low"
         ; field "header" ~sample ~high_end:"header_high_end" ~low_end:"header_low_end"
         ; header_end "high"
         ; header_end "low"
         ; field "data" ~sample ~high_end:"data_high_end" ~low_end:"data_low_end"
         ; data_end "high"
         ; data_end "low"
         ; field "crc" ~sample ~high_end:"crc_end" ~low_end:"crc_end"
         ; "crc_end:"
         ; "    mov isr, null"
         ; "    in crc, 15"
         ; "    mov x, isr               ; zero when the CRC holds"
         ; "    wait t+                  ; the CRC delimiter"
         ; "    jmp pin, delimited"
         ; "    jmp form"
         ; "delimited:"
         ; "    jmp x--, crc_error"
         ]
       @ delay (period - sample - 5)
       @ [ "    set pins, 0              ; ACK, from the slot's start"; "    wait t+" ]
       @ delay (period - sample - 1)
       @ [ "    set pins, 1              ; to its end"
         ; "    mov isr, null"
         ; "    push"
         ; "    set x, 9                 ; ACK delimiter, EOF, two of the intermission"
         ; "    jmp quiet"
         ; "stuffing:"
         ; "    set x, 1"
         ; "    jmp error"
         ; "refused:"
         ; "    set x, 2"
         ; "    jmp error"
         ; "form:"
         ; "    set x, 3"
         ; "    jmp error"
         ; "crc_error:"
         ; "    set x, 4"
         ; "error:"
         ; "    mov isr, x"
         ; "    push"
         ; "    irq"
         ; "    wait tx                  ; the host has read the words and cleared irq"
         ; "    pull"
         ; "    mov t, now"
         ; "    add t, p"
         ; "    jmp idle"
         ])
  ;;

  let check ~period ~sample =
    Timed_program.check ~period ~single_capture_edge:true ~config (source ~period ~sample)
  ;;

  let firmware =
    Timed_program.of_source_exn
      ~period
      ~single_capture_edge:true
      ~config
      (source ~period ~sample)
  ;;

  module Error_code = struct
    type t =
      | Stuffing
      | Refused
      | Form
      | Crc
    [@@deriving sexp_of, compare, equal, enumerate]

    let to_word t =
      1 + List.find_mapi_exn all ~f:(fun i c -> Option.some_if (equal t c) i)
    ;;

    let of_word word = List.nth all (word - 1)
  end

  let words (frame : Can.Frame.t) =
    let bytes = if frame.rtr then [] else List.take frame.data (Int.min frame.dlc 8) in
    let bytes = if List.length bytes % 2 = 1 then 0 :: bytes else bytes in
    (frame.id
     :: ((Bool.to_int frame.rtr lsl 6) lor frame.dlc)
     :: List.map (List.chunks_of bytes ~length:2) ~f:(function
       | [ high; low ] -> (high lsl 8) lor low
       | _ -> raise_s [%message "BUG: bytes in pairs"]))
    @ [ 0 ]
  ;;

  module Event = struct
    type t =
      | Frame of Can.Frame.t
      | Error of Error_code.t
    [@@deriving sexp_of, compare, equal]
  end

  let frame words =
    match words with
    | id :: control :: rest when control < 0x80 ->
      let rtr = control land 0x40 <> 0
      and dlc = control land 0xf in
      let bytes = if rtr then 0 else Int.min dlc 8 in
      let #(data, rest) = List.split_n rest ((bytes + 1) / 2) in
      let data =
        List.concat_map data ~f:(fun word -> [ word lsr 8; word land 0xff ])
        |> fun all -> List.drop all (List.length all - bytes)
      in
      (match rest with
       | 0 :: rest when List.length data = bytes ->
         Some ({ Can.Frame.id; rtr; dlc; data }, rest)
       | _ -> None)
    | _ -> None
  ;;

  (* Whole frames, then what an error left: the words of the frame it ended and its code,
     the last word the core pushed before it raised [irq]. *)
  let rec read words =
    match frame words with
    | Some (frame, rest) ->
      Or_error.map (read rest) ~f:(fun events -> Event.Frame frame :: events)
    | None ->
      (match List.last words with
       | None -> Ok []
       | Some code ->
         (match Error_code.of_word code with
          | Some code -> Ok [ Event.Error code ]
          | None ->
            Or_error.error_s [%message "neither a frame nor an error" (words : int list)]))
  ;;
end

let sender_shortest_period = 15

let sender_config =
  { Program_config.default with
    in_base = rx_pin
  ; in_count = 1
  ; out_base = tx_pin
  ; set_base = tx_pin
  ; jmp_pin = tx_pin
  ; out_shift = Left
  ; autopull = true
  ; crc_width = 15
  ; crc_poly = 0x4599
  ; crc_init = 0
  ; crc_reflect = false
  }
;;

(* [Can.firmware] to the CRC delimiter, then the bus 11 cycles before the ACK slot ends,
   after which the deadlines go back to the bit's edges. *)
let sender =
  [%firmware
    {|
    wait tx
    pull
    mov p, osr               ; the bit period
    mov t, now
    add t, p
    wait t+
    set pins, 1              ; recessive
frame:
    wait tx
    pull
    mov x, osr               ; bits after SOF, less one
    out null, 16             ; the next out autopulls the first word of them
    crc_init
    mov t, now
    add t, p
    wait t+
    set pins, 0              ; SOF
    set y, 3
dbit:
    jmp pin, dhigh
    wait t+
    out pins, 1
    jmp pin, dchanged
    jmp dsame
dhigh:
    wait t+
    out pins, 1
    jmp pin, dsame
dchanged:
    set y, 3
    jmp dnext
dsame:
    jmp y--, dnext
    wait t+
    mov pins, !pins          ; stuff
    set y, 3
dnext:
    jmp x--, dbit
    in crc, 15
    mov osr, isr
    set x, 14
cbit:
    jmp pin, chigh
    wait t+
    out pins, 1
    jmp pin, cchanged
    jmp csame
chigh:
    wait t+
    out pins, 1
    jmp pin, csame
cchanged:
    set y, 3
    jmp cnext
csame:
    jmp y--, cnext
    wait t+
    mov pins, !pins          ; stuff
    set y, 3
cnext:
    jmp x--, cbit
    wait t+
    set pins, 1              ; CRC delimiter
    wait t+                  ; the ACK slot
    sub t, 7
    sub t, 5
    wait t
    mov isr, pins            ; the bus: 0 is an ACK
    push
    add t, 7
    add t, 5
    set x, 10                ; ACK delimiter, EOF, intermission
tail:
    wait t+
    jmp x--, tail
    jmp frame
|}
      ~config:sender_config
      ~period_floor:sender_shortest_period]
;;

module Sender = struct
  let config = sender_config
  let firmware = sender
  let shortest_period = sender_shortest_period
end

let bench_bit = Bench.bit ~hz:500_000

(* The library's line is dominant from reset until a bit after the period, and a frame can
   follow a bit later. On a bus it goes recessive at once and stays so eleven bits after
   the period, which a node needs to join the bus. *)
let bench_firmware firmware =
  Bench.patch
    (Timed_program.source firmware)
    ~pattern:
      "    wait tx\n\
      \    pull\n\
      \    mov p, osr               ; the bit period\n\
      \    mov t, now\n\
      \    add t, p\n\
      \    wait t+\n\
      \    set pins, 1              ; recessive\n"
    ~with_:
      "    set pins, 1              ; recessive\n\
      \    wait tx\n\
      \    pull\n\
      \    mov p, osr               ; the bit period\n\
      \    mov t, now\n\
      \    add t, p\n\
      \    set x, 10\n\
       bus_idle:\n\
      \    wait t+\n\
      \    jmp x--, bus_idle\n"
;;

let bench_stimulus =
  { Bench.Stimulus.bursts = [ Can.words (Can.Frame.data ~id:0x4a [ 0x61 ]) ]
  ; quiet = 0
  ; cycles = 20_000
  }
;;

let bench =
  [ { Bench.name = "can"
    ; what =
        [%string
          "Can.firmware, recessive from the start and for eleven bits after the period: \
           the host sends the bit period, %{bench_bit#Int} cycles for %{Bench.rate \
           ~unit:\"bit/s\" bench_bit}"]
    ; source = bench_firmware Can.firmware
    ; config = Can.config
    ; assumption = Floor Can.shortest_period
    ; clock_hz = Bench.clock_hz
    ; load = Some bench_bit
    ; stimulus = Some bench_stimulus
    }
  ; { name = "can_sender"
    ; what =
        [%string
          "Can_node.Sender.firmware, recessive from the start and for eleven bits after \
           the period: Can.firmware reading its ACK slot on IN1, the host sends the bit \
           period, %{bench_bit#Int} cycles for %{Bench.rate ~unit:\"bit/s\" bench_bit}"]
    ; source = bench_firmware Sender.firmware
    ; config = Sender.config
    ; assumption = Floor Sender.shortest_period
    ; clock_hz = Bench.clock_hz
    ; load = Some bench_bit
    ; stimulus = Some bench_stimulus
    }
  ; { name = "can_receiver"
    ; what =
        [%string
          "Can_node.Receiver.firmware: %{Bench.rate ~unit:\"bit/s\" Receiver.period} \
           sampled %{Receiver.sample#Int} cycles in, CRX on IN1, the ACK on OUT1"]
    ; source = Timed_program.source Receiver.firmware
    ; config = Receiver.config
    ; assumption = Receiver Receiver.period
    ; clock_hz = Bench.clock_hz
    ; load = Some Receiver.period
    ; stimulus = None
    }
  ]
;;

(* Bosch: a node joins the bus after eleven recessive bits; the transceiver's rate *)
let limits firmware =
  let bosch =
    { Datasheet.Sheet.part = "CAN 2.0A"
    ; document = "Bosch CAN 2.0, BCANPSV2.0 Rev. 3"
    ; page = "s.2.15 p.2-6, eleven recessive bits"
    }
  and transceiver =
    { Datasheet.Sheet.part = "SN65HVD230"
    ; document = "TI SLOS346O"
    ; page = "p.1, up to 1 Mbps"
    }
  in
  let limit parameter limit sheet bound =
    { Datasheet.firmware; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit
      "recessive"
      (At_least 1_000.)
      transceiver
      (Datasheet.level ~pin:Datasheet.set_pin ~high:true ())
  ; limit
      "dominant"
      (At_least 1_000.)
      transceiver
      (Datasheet.level ~pin:Datasheet.set_pin ~high:false ())
  ; limit
      "idle to SOF"
      (At_least 22_000.)
      bosch
      (Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz:_ levels ->
         List.drop_while levels ~f:(fun (high, _) -> not high)
         |> List.hd
         |> Option.to_list
         |> List.map ~f:snd))
  ]
;;

let receiver_limits =
  [ { Datasheet.firmware = "can_receiver"
    ; parameter = "ACK"
    ; limit = At_least 1_000.
    ; sheet =
        { part = "SN65HVD230"; document = "TI SLOS346O"; page = "p.1, up to 1 Mbps" }
    ; margin = Cycle
    ; bound = Datasheet.level ~pin:Datasheet.set_pin ~high:false ()
    }
  ]
;;

open Pin_trace
module Reg = Host_port.Reg

(* The host waits eleven bits after the period before the first frame, as a node joining
   the bus has to: the firmware sends whenever it has words. *)
let can_trace ?(teeth = []) ~name ~frames ~rejected () =
  let clock_hz = 48_000_000 in
  let send frame =
    [ Step.Write (Reg.tx, Can.words frame)
    ; Run (List.length (Can.line frame) * Can.period)
    ]
  in
  { Scenario.name
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load ~config:Can.config ~program:(Timed_program.words Can.firmware)
      @ [ Scenario.start; Write (Reg.tx, [ Can.period ]); Run (12 * Can.period) ]
      @ List.concat_map frames ~f:send
  ; sigrok =
      Some
        { clock_hz
        ; decoders =
            [ Sigrok.decoder
                "can"
                ~pins:[ "can_rx", Can.tx_pin ]
                ~options:[ "nominal_bitrate", Int.to_string (clock_hz / Can.period) ]
            ]
        ; expect =
            [ ( "can=sof:id:ide:rtr:dlc:data:crc-sequence:ack-slot:eof"
              , List.concat_map frames ~f:(fun (frame : Can.Frame.t) ->
                  [ "Start of frame"
                  ; sprintf "Identifier: %d (0x%x)" frame.id frame.id
                  ; "Identifier extension bit: standard frame"
                  ; sprintf
                      "Remote transmission request: %s frame"
                      (if frame.rtr then "remote" else "data")
                  ; sprintf "Data length code: %d" frame.dlc
                  ]
                  @ List.mapi frame.data ~f:(sprintf "Data byte %d: 0x%02x")
                  @ [ sprintf "CRC-15 sequence: 0x%04x" (Can.crc frame)
                    ; "ACK slot: NACK"
                    ; "End of frame"
                    ])
                |> Sigrok.lines "can" )
            ]
        ; joins_after =
            Some
              ( 11 * Can.period
              , { why =
                    "the pin is dominant from reset until a bit after the period \
                     arrives, which sigrok reads as frames of zeros"
                ; first_difference = 1
                ; reads = "can-1: Identifier: 0 (0x0)"
                } )
        ; rejected
        ; teeth
        }
  }
;;

let scenario =
  (* edge 1 is the first SOF: a data bit inverted and the CRC left as it was *)
  let tooth =
    [ Sigrok.Corruption.Flip
        { pin = Can.tx_pin; edge = 1; after = 25 * Can.period; cycles = Can.period }
    ]
  in
  can_trace
    ~name:"can"
    ~frames:
      [ Can.Frame.data ~id:0x123 [ 0xde; 0xad ]
      ; Can.Frame.data ~id:0x555 [ 0x00; 0xff; 0x55; 0xaa; 0x01; 0x80; 0x7f; 0xfe ]
      ; Can.Frame.data ~id:0x000 []
      ]
    ~rejected:None
    ~teeth:[ tooth ]
    ()
;;

let remote_scenario =
  can_trace
    ~name:"can_remote"
    ~frames:[ Can.Frame.remote ~id:0x0f0 ~dlc:4; Can.Frame.data ~id:0x123 [ 0xde; 0xad ] ]
    ~rejected:
      (Some
         { why =
             "sigrok 0.5.3 reads a remote frame's DLC of data bytes, though a remote \
              frame carries none"
         ; first_difference = 5 (* the line after the remote frame's DLC *)
         ; reads = "can-1: Data byte 0:"
         })
    ()
;;

let protocol =
  { Protocol.name = "can"
  ; certified =
      [ Certified.plain
          ~period:Can.period
          ~period_floor:Can.shortest_period
          ~no_wrap:true
          "can"
          (Timed_program.source Can.firmware)
          Can.config
      ]
  ; time_triggered = []
  ; bench
  ; loaded_from_hex = []
  ; limits = limits "can" @ limits "can_sender" @ receiver_limits
  ; unlimited = []
  ; swept =
      [ (* 26.7 kbit/s at 48 MHz, where nine edges take twice a poll *)
        { Swept.name = "can"
        ; watch = "tx"
        ; on_wire =
            (fun c ->
              { c with
                in_base = Swept.wire
              ; out_base = Swept.wire
              ; set_base = Swept.wire
              ; jmp_pin = Swept.wire
              })
        ; period = Some 1800
        ; bursts = [ Can.words (Can.Frame.data ~id:0x4a [ 0x61 ]) ]
        }
      ]
  ; not_swept = []
  ; scenarios = []
  ; decoded = [ scenario; remote_scenario ]
  }
;;
