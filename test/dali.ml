open! Core
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

(* Wikipedia, "Digital Addressable Lighting Interface", revision of 10 July 2026 (oldid
   1363488623), one page, cited by line
   {v
   rate      1200 bit/s, fixed                                      lines 157, 172
   bit       Manchester, a one low then high, a zero the reverse    line 178
   frame     a start bit 1, 8 to 32 data bits msb first             line 178
   idle      high, at least 2.45 ms after each frame                line 178
   forward   16 bits, the address byte then the opcode              line 206
   backward  8 bits                                                 line 156
   commands  40 a second at most                                    line 188
   v} *)

let pin = 5
let half_bit = Bench.half ~hz:1200
let shortest_half_bit = 8

let config =
  { Program_config.default with
    set_base = pin
  ; set_count = 1
  ; out_shift = Left
  ; pull_threshold = 16
  }
;;

(* The host loads the half bit in cycles, then per frame its data bits minus one and the
   data, msb first from bit 15. Every edge follows a [wait t+]. Each frame is followed by
   27 half bits of idle, so forward frames start 61 half bits (25.4 ms) apart. *)
let firmware =
  [%firmware
    {|
    set pins, 1              ; idle high
    wait tx
    pull
    mov p, osr               ; the half bit
frame:
    wait tx
    pull
    mov y, osr               ; data bits less one
    wait tx
    pull                     ; the data
    mov t, now
    add t, p
    wait t+
    set pins, 0              ; the start bit, a one
    wait t+
    set pins, 1
bit:
    out x, 1
    jmp x--, one
    wait t+
    set pins, 1              ; a zero: high, then low
    wait t+
    set pins, 0
    jmp y--, bit
    jmp stop
one:
    wait t+
    set pins, 0              ; a one: low, then high
    wait t+
    set pins, 1
    jmp y--, bit
stop:
    wait t+
    set pins, 1              ; idle from the end of the last bit
    set x, 25
idle:
    wait t+
    jmp x--, idle
    jmp frame
|}
      ~config
      ~period_floor:shortest_half_bit]
;;

let certified = [ Certified.of_firmware ~period:half_bit ~no_wrap:true "dali" firmware ]

module Frame = struct
  type t =
    | Forward of
        { address : int
        ; opcode : int
        }
    | Backward of int
  [@@deriving sexp_of, equal]
end

let words : Frame.t -> int list = function
  | Forward { address; opcode } -> [ 15; (address lsl 8) lor opcode ]
  | Backward answer -> [ 7; answer lsl 8 ]
;;

module Read = struct
  type t =
    { frame : Frame.t
    ; start : int
    ; idle : int option
    }
  [@@deriving sexp_of]
end

let idle_ns = 2_450_000

(* The far end: each run of the line within 5% of a whole number of half bits of 1/2400 s,
   with a high of more than two ending the frame. The last bit ends a start bit's low
   after its middle edge; the idle runs from there to the next fall. If the levels end
   first, the last frame's high is taken as whole and its idle as cut short. *)
let read ?(check_idle = true) ~clock_hz levels =
  let open Or_error.Let_syntax in
  let halves cycles = ((cycles * 4800) + clock_hz) / (2 * clock_hz) in
  let timed measured cycles =
    let k = halves cycles in
    let ns = Measured.ns ~clock_hz cycles in
    let name = if k = 1 then "half bit" else sprintf "%d half bits" k in
    if k >= 1 && abs ((cycles * 2400) - (k * clock_hz)) * 20 <= k * clock_hz
    then return (Measured.add measured ~name ~ns)
    else Or_error.error_s [%message "out of spec" name (ns : int)]
  in
  let frame slots =
    let slots = Array.of_list (List.rev slots) in
    let bit i =
      match slots.(2 * i), slots.((2 * i) + 1) with
      | false, true -> return true
      | true, false -> return false
      | _ -> Or_error.error_s [%message "not a Manchester bit" (i : int)]
    in
    let n = (Array.length slots / 2) - 1 in
    let%bind start = bit 0 in
    let%bind data = List.init n ~f:(fun i -> bit (i + 1)) |> Or_error.all in
    let value = List.fold data ~init:0 ~f:(fun acc b -> (acc lsl 1) lor Bool.to_int b) in
    match start, n with
    | false, _ -> Or_error.error_s [%message "a start bit of 0"]
    | true, 16 ->
      return (Frame.Forward { address = value lsr 8; opcode = value land 0xff })
    | true, 8 -> return (Frame.Backward value)
    | true, n -> Or_error.error_s [%message "a frame of neither 8 nor 16 bits" (n : int)]
  in
  (* the half bits so far, newest first, up to the high that ends the frame *)
  let rec cells measured ~at slots = function
    | (level, cycles) :: rest
      when (not level) || (halves cycles <= 2 && not (List.is_empty rest)) ->
      let%bind measured = timed measured cycles in
      cells
        measured
        ~at:(at + cycles)
        (List.init (halves cycles) ~f:(fun _ -> level) @ slots)
        rest
    | runs -> return (slots, measured, at, runs)
  in
  let rec frames measured ~at reads = function
    | [] -> return (List.rev reads, measured)
    | runs ->
      let start_low = snd (List.hd_exn runs) in
      let%bind slots, measured, high_at, runs = cells measured ~at [] runs in
      let last = List.length slots % 2 = 1 in
      let%bind frame = frame (if last then true :: slots else slots) in
      let read idle = { Read.frame; start = at; idle } in
      (match runs with
       | [] -> return (List.rev (read None :: reads), measured)
       | (_, cycles) :: rest ->
         let idle = cycles - if last then start_low else 0 in
         if List.is_empty rest
         then return (List.rev (read None :: reads), measured)
         else if check_idle && not (Measured.at_least ~clock_hz idle ~ns:idle_ns)
         then
           Or_error.error_s
             [%message "idle too short" ~ns:(Measured.ns ~clock_hz idle : int)]
         else
           frames
             (Measured.add measured ~name:"idle" ~ns:(Measured.ns ~clock_hz idle))
             ~at:(high_at + cycles)
             (read (Some idle) :: reads)
             rest)
  in
  let before, runs = List.split_while levels ~f:(fun (high, _) -> not high) in
  let at = List.sum (module Int) before ~f:snd in
  match runs with
  | [] -> return ([], Measured.empty)
  | (_, idle) :: runs -> frames Measured.empty ~at:(at + idle) [] runs
;;

let forward_starts reads =
  List.filter_map reads ~f:(fun { Read.frame; start; _ } ->
    match frame with
    | Forward _ -> Some start
    | Backward _ -> None)
;;

let rec gaps = function
  | a :: (b :: _ as rest) -> (b - a) :: gaps rest
  | [] | [ _ ] -> []
;;

(* QUERY ACTUAL LEVEL (line 247) to short address 1, with its S bit set for a command (line
   207), and the answer, full brightness (line 202) *)
let query = Frame.Forward { address = (1 lsl 1) lor 1; opcode = 0xa0 }
let answer = Frame.Backward 254

let bench =
  { Bench.name = "dali"
  ; what =
      [%string
        "Dali.firmware: forward and backward frames at 1200 bit/s, %{half_bit#Int} \
         cycles a half bit, the line high when idle, on OUT0"]
  ; source = Timed_program.source firmware
  ; config = Timed_program.config firmware
  ; assumption = Floor shortest_half_bit
  ; clock_hz = Bench.clock_hz
  ; load = Some half_bit
  ; stimulus =
      Some
        { bursts = [ words query; words query; words answer ]
        ; quiet = 0
        ; cycles = 170 * half_bit
        }
  }
;;

(* Only rows with a least or a most are bounded. The rate (1200 bit/s, line 157), a
   packet's 25 ms (line 170), 1.5 s for 64 addresses (line 170) and UP and DOWN's 200 ms
   fades (lines 221-222) are typical values, so no row. Both bounds are the run's, as the
   idle is a loop of waits. *)
let limits =
  let sheet line =
    { Datasheet.Sheet.part = "DALI"
    ; document = "Wikipedia, Digital Addressable Lighting Interface, oldid 1363488623"
    ; page = [%string "p.1, line %{line#Int}"]
    }
  in
  let reads ~clock_hz levels = read ~check_idle:false ~clock_hz levels |> ok_exn |> fst in
  let limit parameter limit sheet bound =
    { Datasheet.firmware = "dali"; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit
      "idle after a frame"
      (At_least 2.45e6)
      (sheet 178)
      (Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
         List.filter_map (reads ~clock_hz levels) ~f:(fun r -> r.idle)))
  ; limit
      "40 commands a second, forward frames 25 ms apart"
      (At_least 25e6)
      (sheet 188)
      (Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz levels ->
         gaps (forward_starts (reads ~clock_hz levels))))
  ]
;;

(* 100 cycles a half bit, as a 240 kHz clock gives: sigrok's dali assumes 1200 bit/s *)
let trace_clock_hz = 240_000
let trace_half_bit = 100

(* What sigrok's dali prints for a frame, once the line has stayed high a bit past it:
   each bit with the start bit first, the start bit twice, then the raw bytes and the
   fields, here those of [query] alone *)
let reading frame =
  let bits value n =
    "1" :: List.init n ~f:(fun i -> Int.to_string ((value lsr (n - 1 - i)) land 1))
  in
  let start = [ "Startbit: 1"; "Startbit: 1" ] in
  match (frame : Frame.t) with
  | Forward { address; opcode } ->
    bits ((address lsl 8) lor opcode) 16
    @ start
    @ [ sprintf "Raw data: %02X" address; sprintf "Raw data: %02X" opcode ]
    @ [ "Command"; "YBit: 0"; "Short address: 1"; "Command: 160 (Query Level)" ]
  | Backward answer ->
    bits answer 8 @ start @ [ sprintf "Reply: %02X" answer; sprintf "Reply: %d" answer ]
;;

let sigrok =
  { Sigrok.clock_hz = trace_clock_hz
  ; decoders = [ Sigrok.decoder "dali" ~pins:[ "dali", pin ] ]
  ; expect =
      [ ( "dali=bit:startbit:ybit:address:command:reply:raw"
        , List.concat_map [ query; answer ] ~f:reading |> Sigrok.lines "dali" )
      ]
  ; joins_after = None
  ; rejected = None
  ; (* edge 0 is the line's rise to idle and edge 3 starts the low half of the first data bit,
       a zero. Held high instead, three half bits high read as the stop *)
    teeth = [ [ Flip { pin; edge = 3; after = 0; cycles = trace_half_bit } ] ]
  }
;;

let scenario =
  let send frame = [ Step.Write (Reg.tx, words frame); Run (61 * trace_half_bit) ] in
  { Scenario.name = "dali"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~assumptions:(Certified.assumptions (List.hd_exn certified))
        ~config:(Timed_program.config firmware)
        ~program:(Timed_program.words firmware)
        ()
      @ [ Scenario.start; Write (Reg.tx, [ trace_half_bit ]) ]
      @ send query
      @ send answer
  ; sigrok = Some sigrok
  }
;;

let protocol =
  { Protocol.name = "dali"
  ; certified
  ; time_triggered = []
  ; bench = [ bench ]
  ; loaded_from_hex = []
  ; limits
  ; unlimited = []
  ; swept = []
  ; not_swept =
      [ ( "dali"
        , "a half bit is 20000 cycles and the idle 540000, past the 65536 a stamp tells \
           apart" )
      ]
  ; scenarios = [ scenario ]
  ; decoded = []
  }
;;
