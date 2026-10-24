open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* SB-Projects, "Philips RC-6 Protocol", last updated 17 July 2025, page 1: the symbols of
   mode 0, in units of 1t, 16 carrier periods or 444 us
   {v
   leader   mark 6, space 2
   cell     a one is a mark then a space, a zero the reverse, 1 each
   trailer  a cell of 2 and 2
   frame    leader, start bit 1, mode bits 000, trailer, 8 address bits, 8 command bits
   free     6 after the last cell
   v}
   The line is the demodulated one: high for a mark, with no carrier on it. *)

let pin = 5
let standard_unit = 21_333
let shortest_unit = 14

let config =
  { Program_config.default with
    set_base = pin
  ; set_count = 1
  ; out_shift = Left
  ; pull_threshold = 16
  }
;;

(* The host loads the unit in cycles, then for each frame the trailer bit as 0 or 1, then
   the address and command as one word, msb first. [t] is the next unit throughout and
   every wait takes one. *)
let firmware =
  [%firmware
    {|
    mov t, now
    set pins, 0
    wait tx
    pull
    mov p, osr               ; the unit
message:
    wait tx
    pull
    mov y, osr               ; the trailer bit
    wait tx
    pull                     ; address, then command
    mov t, now
    add t, p
    wait t+
    set pins, 1              ; leader mark, 6 units
    set x, 4
l0:
    wait t+
    jmp x--, l0
    wait t+
    set pins, 0              ; leader space, 2
    wait t+
    wait t+
    set pins, 1              ; start bit, a one
    wait t+
    set pins, 0
    wait t+
    set x, 2
mode:
    set pins, 0              ; three mode bits, zeros
    wait t+
    set pins, 1
    wait t+
    jmp x--, mode
    jmp y--, trailer_one
    set pins, 0              ; the trailer, 2 and 2
    wait t+
    wait t+
    set pins, 1
    wait t+
    wait t+
    jmp data
trailer_one:
    set pins, 1
    wait t+
    wait t+
    set pins, 0
    wait t+
    wait t+
data:
    set y, 15
bit:
    out x, 1
    jmp x--, one
    set pins, 0
    wait t+
    set pins, 1
    wait t+
    jmp y--, bit
    jmp free
one:
    set pins, 1
    wait t+
    set pins, 0
    wait t+
    jmp y--, bit
free:
    set pins, 0
    set x, 5
f0:
    wait t+
    jmp x--, f0              ; the signal free time, 6 units
    jmp message
|}
      ~config
      ~period_floor:shortest_unit]
;;

(* The certificate holds at the unit the bench loads, and the firmware at any from
   [shortest_unit]. *)
let certified =
  [ Certified.of_firmware ~period:standard_unit ~no_wrap:true "ir_rc6" firmware ]
;;

module Message = struct
  type t =
    { toggle : bool
    ; address : int
    ; command : int
    }
  [@@deriving sexp_of, equal]
end

let words ~toggle ~address ~command = [ Bool.to_int toggle; (address lsl 8) lor command ]

(* 16 periods of 36 kHz, in ns *)
let unit_ns = 444_444

(* the half cells from the start bit to the last data bit *)
let slots_in_frame = 44

let decode ~clock_hz levels =
  let open Or_error.Let_syntax in
  (* within 5%, exactly: cycles of 1e9 / clock_hz ns against ns *)
  let nominal ~units = units * unit_ns * clock_hz in
  let units cycles =
    ((cycles * 2_000_000_000) + nominal ~units:1) / (2 * nominal ~units:1)
  in
  let near cycles ~units =
    abs ((cycles * 1_000_000_000) - nominal ~units) * 20 <= nominal ~units
  in
  let timed measured cycles ~units ~name =
    let ns = Measured.ns ~clock_hz cycles in
    if near cycles ~units
    then return (Measured.add measured ~name ~ns)
    else Or_error.error_s [%message "out of spec" name (ns : int)]
  in
  (* a run of low whose first [part] units end the last cell and the rest is signal free *)
  let free measured cycles ~part =
    let rest = (cycles * 1_000_000_000) - nominal ~units:part in
    let ns = rest / clock_hz in
    if rest * 20 >= 19 * nominal ~units:6
    then return (Measured.add measured ~name:"signal free" ~ns)
    else Or_error.error_s [%message "signal free time too short" (ns : int)]
  in
  let rec cells measured slots = function
    | [] -> Or_error.error_s [%message "a frame cut short"]
    | (level, cycles) :: rest ->
      let have = List.length slots
      and k = units cycles in
      if have + k <= slots_in_frame && have < slots_in_frame
      then (
        let name = sprintf "%s %dt" (if level then "mark" else "space") k in
        let%bind measured = timed measured cycles ~units:k ~name in
        cells measured (List.init k ~f:(fun _ -> level) @ slots) rest)
      else if level
      then Or_error.error_s [%message "a mark in the signal free time"]
      else (
        let part = slots_in_frame - have in
        let%map measured = free measured cycles ~part in
        List.rev (List.init part ~f:(fun _ -> false) @ slots), measured, rest)
  in
  let message slots =
    let slots = Array.of_list slots in
    let bit i =
      match slots.(2 * i), slots.((2 * i) + 1) with
      | true, false -> return true
      | false, true -> return false
      | _ -> Or_error.error_s [%message "not a bi-phase cell" (i : int)]
    in
    let%bind start = bit 0 in
    let%bind mode = List.init 3 ~f:(fun i -> bit (i + 1)) |> Or_error.all in
    let%bind data = List.init 16 ~f:(fun i -> bit (6 + i)) |> Or_error.all in
    let%bind () =
      if start && not (List.exists mode ~f:Fn.id)
      then return ()
      else Or_error.error_s [%message "not mode 0" (start : bool) (mode : bool list)]
    in
    let%map toggle =
      match slots.(8), slots.(9), slots.(10), slots.(11) with
      | a, b, c, d when Bool.equal a b && Bool.equal c d && not (Bool.equal a c) ->
        return a
      | _ -> Or_error.error_s [%message "a trailer not of two and two"]
    in
    let value = List.fold data ~init:0 ~f:(fun acc b -> (acc lsl 1) lor Bool.to_int b) in
    { Message.toggle; address = value lsr 8; command = value land 0xff }
  in
  let rec messages measured = function
    | [] -> return ([], measured)
    | (true, mark) :: (false, space) :: rest ->
      let%bind measured = timed measured mark ~units:6 ~name:"leader mark" in
      let%bind measured = timed measured space ~units:2 ~name:"leader space" in
      let%bind slots, measured, rest = cells measured [] rest in
      let%bind message = message slots in
      let%map messages, measured = messages measured rest in
      message :: messages, measured
    | _ -> Or_error.error_s [%message "not a leader"]
  in
  List.group levels ~break:Bool.( <> )
  |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  |> List.drop_while ~f:(fun (high, _) -> not high)
  |> messages Measured.empty
;;

(* TODO bench *)
let bench =
  { Bench.name = "ir_rc6"
  ; what =
      [%string
        "Ir_rc6.firmware: RC-6 mode 0 frames, %{standard_unit#Int} cycles a 444 us unit, \
         the line high for a mark, on OUT0"]
  ; source = Timed_program.source firmware
  ; config = Timed_program.config firmware
  ; assumption = Floor shortest_unit
  ; clock_hz = Bench.clock_hz
  ; load = Some standard_unit
  ; stimulus = None
  }
;;

let limits : Datasheet.t list = []

(* A unit of 200 cycles, as a 450 kHz clock gives, keeps the simulation short: a frame
   with the trailer bit low and one with it high. *)
let sent =
  [ { Message.toggle = false; address = 0x1a; command = 0x35 }
  ; { toggle = true; address = 0x00; command = 0xff }
  ]
;;

let clock_hz = 450_000
let unit = 200

(* a frame is 58 units with the signal free time, and the next is a little after *)
let frame_cycles = 60 * unit

let sigrok =
  { Sigrok.clock_hz
  ; decoders = [ Sigrok.decoder "ir_rc6" ~pins:[ "ir", pin ] ]
  ; expect = []
  ; joins_after = None
  ; rejected = None
  ; teeth = []
  }
;;

let scenario =
  let send { Message.toggle; address; command } =
    [ Step.Write (Reg.tx, words ~toggle ~address ~command); Run frame_cycles ]
  in
  { Scenario.name = "ir_rc6"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
      @ [ Scenario.start; Write (Reg.tx, [ unit ]) ]
      @ List.concat_map sent ~f:send
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "ir_rc6"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited =
      [ ( "ir_rc6"
        , "the spec gives typical times and no minimum or maximum; Ir_rc6.decode holds \
           each mark and space to 5%" )
      ]
  ; swept = []
  ; not_swept =
      [ "ir_rc6", "a 6 unit mark is 128000 cycles, past the 65536 a stamp tells apart" ]
  ; scenarios = []
  ; decoded = [ scenario ]
  }
;;
