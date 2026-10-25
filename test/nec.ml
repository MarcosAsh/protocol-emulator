open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* NEC as SB-Projects' page on it gives the frames, in units of 562.5 us:
   {v
   frame   leader mark 16, space 8, 32 bits LSB first, final mark 1
   bit     mark 1, then space 1 for a zero, 3 for a one
   repeat  mark 16, space 4, final mark 1
   period  192, 108 ms, from one leader or repeat to the next
   v} *)

let pin = 5
let standard_unit = 27_000
let shortest_unit = 11
let standard_half = standard_unit / 2

let config =
  { Program_config.default with
    set_base = pin
  ; set_count = 1
  ; out_shift = Right
  ; pull_threshold = 16
  }
;;

(* The line is low for a mark, as a receiver module's output. [t] is the next unit
   throughout and every wait takes one, so the gap after the final mark makes up the 192
   from [y]: set for a frame of zeros, two less for each one. *)
let tx =
  [%firmware
    {|
    mov t, now
    set pins, 1
    wait tx
    pull
    mov p, osr               ; the unit
message:
    wait tx
    pull
    mov isr, osr             ; repeat codes after the frame
    mov t, now
    add t, p
    wait t+
    set pins, 0              ; leader, 9 ms
    set x, 14
l0:
    wait t+
    jmp x--, l0
    wait t+
    set pins, 1              ; 4.5 ms
    pull                     ; the address, then its inverse
    set y, 25
    add y, y
    add y, y
    add y, 1
    set x, 6
l1:
    wait t+
    jmp x--, l1
a_bit:
    wait t+
    set pins, 0
    out x, 1
    wait t+
    set pins, 1
    jmp x--, a_one
    jmp !osre, a_bit
command:
    pull                     ; the command, then its inverse
c_bit:
    wait t+
    set pins, 0
    out x, 1
    wait t+
    set pins, 1
    jmp x--, c_one
    jmp !osre, c_bit
final:
    wait t+
    set pins, 0
    wait t+
    set pins, 1
gap:
    wait t+
    jmp y--, gap             ; to 108 ms from the leader
more:
    mov x, isr
    jmp x--, repeat
    jmp message
repeat:
    mov isr, x
    wait t+
    set pins, 0              ; repeat code, 9 ms
    set x, 14
r0:
    wait t+
    jmp x--, r0
    wait t+
    set pins, 1              ; 2.25 ms
    set x, 2
r1:
    wait t+
    jmp x--, r1
    wait t+
    set pins, 0
    wait t+
    set pins, 1
    set y, 9
r2:
    set x, 16
r3:
    wait t+
    jmp x--, r3
    jmp y--, r2              ; 170 units to 108 ms
    jmp more
a_one:
    wait t+
    sub y, 2
    wait t+
    jmp !osre, a_bit
    jmp command
c_one:
    wait t+
    sub y, 2
    wait t+
    jmp !osre, c_bit
    jmp final
|}
      ~config
      ~period_floor:shortest_unit]
;;

let rx_config ~pin =
  { Program_config.default with
    in_base = pin
  ; jmp_pin = pin
  ; capture_pin = pin
  ; capture_rising = false
  ; in_shift = Right
  ; autopush = true
  ; push_threshold = 16
  }
;;

(* In halves of a unit, each sample in the middle of what it tells apart: 16 into a mark a
   leader's from a bit's, 9 past the leader's end a frame's space from a repeat code's
   final mark, and 5 into a bit the next mark of a zero from the space of a one. A bit is
   timed from the fall the capture holds, armed in the space before it. *)
let rx_on ~pin =
  [%string
    {|
    wait tx
    pull
    mov p, osr               ; half the unit
idle:
    wait 1 pin %{pin#Int}
    capture_arm
    wait 0 pin %{pin#Int}             ; a mark
    mov t, capture
    add t, p
    set x, 15
l0:
    wait t+
    jmp x--, l0
    jmp pin, idle            ; too short for a leader
    wait 1 pin %{pin#Int}             ; its end
    mov t, now
    add t, p
    set x, 8
l1:
    wait t+
    jmp x--, l1
    jmp pin, frame
    mov isr, !null           ; a repeat code
    push
    jmp idle
frame:
    set x, 31
    capture_arm
    wait 0 pin %{pin#Int}             ; the first bit's mark
bit:
    mov t, capture
    add t, p
    add t, p
    add t, p
    wait t+                  ; the space after the mark, a zero's or a one's
    capture_arm
    add t, p
    wait t
    in pins, 1
    wait 0 pin %{pin#Int}             ; the next mark, a zero's begun already
    jmp x--, bit
    jmp idle
|}]
;;

let rx_pin = 15

let receiver ~pin ~half =
  Timed_program.of_source_exn
    ~period:half
    ~single_capture_edge:true
    ~config:(rx_config ~pin)
    (rx_on ~pin)
;;

let rx = receiver ~pin:rx_pin ~half:standard_half

module Message = struct
  type t =
    | Frame of
        { address : int
        ; command : int
        }
    | Repeat
  [@@deriving sexp_of, equal]
end

let words ~address ~command ~repeats =
  let inverted byte = byte lor ((lnot byte land 0xff) lsl 8) in
  [ repeats; inverted address; inverted command ]
;;

let unit_ns = 562_500

let decode ~clock_hz levels =
  let open Or_error.Let_syntax in
  (* within 5%, exactly: cycles of 1e9 / clock_hz ns against ns *)
  let off cycles ~units =
    let nominal = units * unit_ns * clock_hz in
    (cycles * 1_000_000_000) - nominal, nominal
  in
  let near cycles ~units =
    let off, nominal = off cycles ~units in
    abs off * 20 <= nominal
  in
  let timed measured cycles ~units ~name =
    let ns = Measured.ns ~clock_hz cycles in
    if near cycles ~units
    then return (Measured.add measured ~name ~ns)
    else Or_error.error_s [%message "out of spec" name (ns : int)]
  in
  (* each mark with the cycle it began and the space after it, the idle line before the
     first left out *)
  let marks =
    List.group levels ~break:Bool.( <> )
    |> List.fold ~init:(0, []) ~f:(fun (at, marks) run ->
      let length = List.length run in
      let marks =
        match List.hd_exn run, marks with
        | false, _ -> (at, length, None) :: marks
        | true, (start, mark, None) :: rest -> (start, mark, Some length) :: rest
        | true, _ -> marks
      in
      at + length, marks)
    |> snd
    |> List.rev
  in
  let final measured = function
    | (_, mark, _) :: rest ->
      let%map measured = timed measured mark ~units:1 ~name:"final mark" in
      measured, rest
    | [] -> Or_error.error_s [%message "no final mark"]
  in
  let byte bits ~at =
    List.foldi (List.sub bits ~pos:at ~len:8) ~init:0 ~f:(fun i b bit ->
      b lor (Bool.to_int bit lsl i))
  in
  let rec messages measured ~last = function
    | [] -> return ([], measured)
    | (start, mark, space) :: rest ->
      let%bind measured = timed measured mark ~units:16 ~name:"leader mark" in
      let%bind measured =
        match last with
        | None -> return measured
        | Some last ->
          let off, nominal = off (start - last) ~units:192 in
          let ns = Measured.ns ~clock_hz (start - last) in
          if off * 20 >= -nominal
          then return (Measured.add measured ~name:"period" ~ns)
          else Or_error.error_s [%message "next message too soon" (ns : int)]
      in
      let%bind message, measured, rest =
        match space with
        | Some space when near space ~units:4 ->
          let%bind measured = timed measured space ~units:4 ~name:"repeat space" in
          let%map measured, rest = final measured rest in
          Message.Repeat, measured, rest
        | Some space ->
          let%bind measured = timed measured space ~units:8 ~name:"leader space" in
          let%bind () =
            if List.length rest > 32
            then return ()
            else Or_error.error_s [%message "a frame cut short"]
          in
          let bits = List.take rest 32
          and rest = List.drop rest 32 in
          let%bind bits, measured =
            List.fold_result
              bits
              ~init:([], measured)
              ~f:(fun (bits, measured) -> function
              | _, mark, Some space ->
                let%bind measured = timed measured mark ~units:1 ~name:"bit mark" in
                let one = not (near space ~units:1) in
                let%map measured =
                  if one
                  then timed measured space ~units:3 ~name:"one space"
                  else timed measured space ~units:1 ~name:"zero space"
                in
                one :: bits, measured
              | _, _, None -> Or_error.error_s [%message "a bit with no space"])
          in
          let bits = List.rev bits in
          let address = byte bits ~at:0
          and command = byte bits ~at:16 in
          let%bind () =
            if byte bits ~at:8 = lnot address land 0xff
               && byte bits ~at:24 = lnot command land 0xff
            then return ()
            else
              Or_error.error_s [%message "not followed by its inverse" (bits : bool list)]
          in
          let%map measured, rest = final measured rest in
          Message.Frame { address; command }, measured, rest
        | None -> Or_error.error_s [%message "a leader with no space"]
      in
      let%map messages, measured = messages measured ~last:(Some start) rest in
      message :: messages, measured
  in
  messages Measured.empty ~last:None marks
;;

(* A unit of 18 cycles, as a 32 kHz clock gives, keeps the simulation short: a frame and a
   repeat code, then a frame on its own, which the host sends 108 ms on. *)
let scenario =
  let clock_hz = 32_000 in
  let unit = 18 in
  let sent = [ 0x04, 0x08, 1; 0x00, 0x45, 0 ] in
  let send (address, command, repeats) =
    [ Step.Write (Reg.tx, words ~address ~command ~repeats)
    ; Run ((192 * (repeats + 1) * unit) + 20)
    ]
  in
  { Scenario.name = "nec"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:
          (Certified.assumptions
             (Certified.of_firmware ~period:standard_unit ~no_wrap:true "nec_tx" tx))
        ~config:(Timed_program.config tx)
        ~program:(Timed_program.words tx)
        ()
      @ [ Scenario.start; Write (Reg.tx, [ unit ]) ]
      @ List.concat_map sent ~f:send
  ; sigrok =
      Some
        { clock_hz
        ; decoders = [ Sigrok.decoder "ir_nec" ~pins:[ "ir", pin ] ]
        ; expect =
            [ ( "ir_nec=addr:addr-inv:cmd:cmd-inv"
              , List.concat_map sent ~f:(fun (address, command, _) ->
                  [ sprintf "Address: 0x%02X" address
                  ; sprintf "Address#: 0x%02X" (lnot address land 0xff)
                  ; sprintf "Command: 0x%02X" command
                  ; sprintf "Command#: 0x%02X" (lnot command land 0xff)
                  ])
                |> Sigrok.lines "ir_nec" )
            ; "ir_nec=repeat-code", Sigrok.lines "ir_nec" [ "Repeat code" ]
            ]
        ; joins_after = None
        ; rejected = None
        ; (* edge 9 is the fall of address bit 3's mark: two units early, bit 2 of 0x04
             reads a zero and bit 3 a one *)
          teeth = [ [ Shift { pin; edge = 9; cycles = -2 * unit } ] ]
        }
  }
;;

let tx_bench =
  { Bench.name = "nec_tx"
  ; what =
      [%string
        "Nec.tx: NEC frames and repeat codes, %{standard_unit#Int} cycles a 562.5 us \
         unit, the line low for a mark, on OUT0"]
  ; source = Timed_program.source tx
  ; config = Timed_program.config tx
  ; assumption = Floor shortest_unit
  ; clock_hz = Bench.clock_hz
  ; load = Some standard_unit
  ; stimulus = None
  }
;;

let rx_bench =
  { Bench.name = "nec_rx"
  ; what =
      [%string
        "Nec.rx: frames and repeat codes read at %{standard_half#Int} cycles a half \
         unit, on IO3, where Pico B's GP2 can send them"]
  ; source = Timed_program.source rx
  ; config = Timed_program.config rx
  ; assumption = Receiver standard_half
  ; clock_hz = Bench.clock_hz
  ; load = Some standard_half
  ; stimulus = None
  }
;;

let protocol =
  { Protocol.name = "nec"
  ; certified =
      [ Certified.of_firmware ~period:standard_unit ~no_wrap:true "nec_tx" tx
      ; Certified.of_firmware ~no_wrap:true "nec_rx" rx
      ]
  ; time_triggered = []
  ; bench = [ tx_bench; rx_bench ]
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited =
      [ "nec_tx", "no datasheet at hand; Nec.decode holds each mark and space to 5%"
      ; "nec_rx", "a receiver: it samples, and drives nothing"
      ]
  ; swept = []
  ; not_swept =
      [ "nec_tx", "a 9 ms mark is 432000 cycles, past the 65536 a stamp tells apart"
      ; "nec_rx", "a receiver: it drives no line to stamp"
      ]
  ; scenarios = []
  ; decoded = [ scenario ]
  }
;;
