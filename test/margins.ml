open! Core
open Protocol_emulator

let clock_hz = Bench.clock_hz
let ns cycles = Float.of_int cycles *. 1e9 /. Float.of_int clock_hz
let cycles_in ~ns = Float.iround_nearest_exn (ns *. Float.of_int clock_hz /. 1e9)
let us n = cycles_in ~ns:(n *. 1000.)

let time_ns ns =
  if Float.(ns < 1000.) then sprintf "%g ns" ns else sprintf "%g us" (ns /. 1000.)
;;

(* a fresh label each call, for the loops [advance] writes *)
let labels stem =
  let n = ref 0 in
  fun () ->
    incr n;
    [%string "%{stem}%{!n#Int}"]
;;

(* [cycles] onto [t] from the deadline last waited on, for the next [wait t]: the part
   below a [p] of [unit] cycles in adds of up to 7, then a [p] and the other whole [p]s by
   [wait t+], so the phase is bounded round every loop, in loops of [counter] where one is
   free. [side] goes on every instruction but [jmp]. *)
let advance ?(side = "") ?counter ~unit ~fresh cycles =
  if cycles < 0 then raise_s [%message "BUG: a deadline behind the last" (cycles : int)];
  let line text = [%string "    %{text}%{side}\n"] in
  let unrolled n = List.init n ~f:(fun _ -> line "wait t+") in
  let waits n =
    match counter with
    | Some counter when n > 2 ->
      let body = (n + 31) / 32 in
      let passes = n / body in
      let label = fresh () in
      [ line [%string "set %{counter}, %{passes - 1#Int}"]; [%string "%{label}:\n"] ]
      @ unrolled body
      @ [ [%string "    jmp %{counter}--, %{label}\n"] ]
      @ unrolled (n - (passes * body))
    | _ -> unrolled n
  in
  let rest = cycles % unit in
  let sevens =
    List.init (rest / 7) ~f:(fun _ -> line "add t, 7")
    @ if rest % 7 > 0 then [ line [%string "add t, %{rest % 7#Int}"] ] else []
  in
  let whole = cycles / unit in
  String.concat (sevens @ if whole = 0 then [] else line "add t, p" :: waits (whole - 1))
;;

module Run = struct
  type t =
    { pins : int array
    ; samples : int list
    ; replies : int list
    }

  (* the core from reset with every line pulled up and nothing else driving, each word in
     as soon as the fifo has room, for [cycles] *)
  let create (bench : Bench.t) ~words ~cycles =
    let timed = Bench.timed bench in
    let inputs = (1 lsl Isa.num_pins) - 1 in
    let pins = Array.create ~len:cycles 0 in
    let rec go machine ~cycle ~queued ~samples ~replies =
      if cycle = cycles
      then (
        if not (Machine.Fault.equal machine.Machine.fault Machine.Fault.none)
        then
          raise_s
            [%message
              "BUG: the run faulted" bench.what ~fault:(machine.fault : Machine.Fault.t)];
        { pins; samples = List.rev samples; replies = List.rev replies })
      else (
        let machine, queued =
          match queued with
          | word :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
            Machine.write_tx machine word |> ok_exn, rest
          | _ -> machine, queued
        in
        let before = machine.isr_count in
        let machine = Machine.step machine ~inputs in
        (* an [in pins, 1]; the [in null]s that fill a word move the count further *)
        let samples =
          if machine.isr_count = before + 1 then cycle :: samples else samples
        in
        let machine, replies =
          match Machine.read_rx machine with
          | Some (word, machine) -> machine, word :: replies
          | None -> machine, replies
        in
        pins.(cycle) <- Machine.pins machine ~inputs;
        go machine ~cycle:(cycle + 1) ~queued ~samples ~replies)
    in
    let machine =
      Machine.create
        ~config:(Timed_program.config timed)
        ~program:(Timed_program.words timed)
      |> ok_exn
    in
    go
      machine
      ~cycle:0
      ~queued:(Option.to_list bench.load @ words)
      ~samples:[]
      ~replies:[]
  ;;

  (* each level of [pin] and the cycle it began, the last, unfinished one dropped *)
  let levels t ~pin =
    Array.foldi t.pins ~init:[] ~f:(fun cycle acc word ->
      let level = (word lsr pin) land 1 = 1 in
      match acc with
      | (high, _) :: _ when Bool.equal high level -> acc
      | acc -> (level, cycle) :: acc)
    |> List.rev
  ;;

  (* [levels] as (level, start, length), the unfinished last one dropped *)
  let runs t ~pin =
    let levels = levels t ~pin in
    List.zip_exn (List.drop_last_exn levels) (List.tl_exn levels)
    |> List.map ~f:(fun ((level, start), (_, next)) -> level, start, next - start)
  ;;
end

(* each parameter's least and most over a run, in cycles *)
module Measured = struct
  type t = (string * int list) list

  let add (t : t) parameter value =
    match List.Assoc.find t parameter ~equal:String.equal with
    | Some values -> List.Assoc.add t parameter (value :: values) ~equal:String.equal
    | None -> (parameter, [ value ]) :: t
  ;;

  (* the swept timing's own values go under "swept" as well *)
  let record t ~swept parameter value =
    let t = add t parameter value in
    if swept then add t ("swept " ^ parameter) value else t
  ;;

  let least (t : t) parameter =
    Option.bind (List.Assoc.find t parameter ~equal:String.equal) ~f:(fun values ->
      List.min_elt values ~compare)
  ;;

  let most (t : t) parameter =
    Option.bind (List.Assoc.find t parameter ~equal:String.equal) ~f:(fun values ->
      List.max_elt values ~compare)
  ;;

  let to_alist (t : t) =
    List.map t ~f:(fun (parameter, values) ->
      ( parameter
      , ( List.min_elt values ~compare |> Option.value_exn
        , List.max_elt values ~compare |> Option.value_exn ) ))
    |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
  ;;
end

(* the rows of a part, read by parameter and side from its library table, so the numbers
   and citations are the library's *)
let library_row (protocol : Protocol.t) ~firmware ~parameter ~least =
  List.find_exn protocol.limits ~f:(fun (t : Datasheet.t) ->
    String.equal t.firmware firmware
    && String.equal t.parameter parameter
    &&
    match t.limit with
    | At_least _ -> least
    | At_most _ -> not least)
;;

let added_row ~firmware ~parameter ~limit ~sheet ~margin =
  { Datasheet.firmware
  ; parameter
  ; limit
  ; sheet
  ; margin
  ; bound = Datasheet.run ~pin:Datasheet.set_pin (fun ~clock_hz:_ _ -> [])
  }
;;

module Verdict = struct
  type t =
    { row : Datasheet.t
    ; value : int option
    ; ok : bool
    }
end

let value (row : Datasheet.t) measured =
  match row.limit with
  | At_least _ -> Measured.least measured row.parameter
  | At_most _ -> Measured.most measured row.parameter
;;

let check_rows rows measured =
  List.map rows ~f:(fun (row : Datasheet.t) ->
    let value = value row measured in
    let v = Datasheet.verdict row ~clock_hz ~bound:value in
    { Verdict.row; value; ok = v.ok })
;;

(* the row at the point's own value, half a cycle out: [Datasheet.needed] then asks for
   that many cycles exactly *)
let own (row : Datasheet.t) ~cycles =
  let half = ns 1 /. 2. in
  let limit : Datasheet.Limit.t =
    match row.limit with
    | At_least _ -> At_least (ns cycles -. half)
    | At_most _ -> At_most (ns cycles +. half)
  in
  { row with limit; margin = Ns { ns = 0.; why = "the point's own value" } }
;;

module Point = struct
  type t =
    { cycles : int
    ; bench : Bench.t
    ; words : int list
    ; run_cycles : int
    ; verdicts : Verdict.t list
    ; in_spec : bool
    ; sweep_limits : Datasheet.t list
    ; designed : int option
    ; sweep_ok : bool
    ; measured : Measured.t
    }

  let ns t = ns t.cycles
  let broken t = List.filter t.verdicts ~f:(fun v -> not v.ok)

  let label t =
    match broken t with
    | [] -> "in spec"
    | broken ->
      "OUT OF SPEC: "
      ^ String.concat
          ~sep:", "
          (List.map broken ~f:(fun { row; value; ok = _ } ->
             let side, limit =
               match row.limit with
               | At_least ns -> ">=", ns
               | At_most ns -> "<=", ns
             in
             let value =
               Option.value_map value ~default:"none" ~f:(fun c -> Bench.time c)
             in
             let margin =
               match row.margin with
               | Cycle -> " + a cycle"
               | Ns { ns; why } -> [%string " + %{time_ns ns} %{why}"]
             in
             [%string
               "%{row.parameter} %{value} (sheet %{side} %{time_ns limit}%{margin})"]))
  ;;
end

module Sweep = struct
  type t =
    { part : string
    ; parameter : string
    ; what : string
    ; rows : Datasheet.t list
    ; nominal : int
    ; observable : string
    ; points : (Point.t, string) Either.t list
    }
end

(* A point: the kernel accepts [bench] or says why not, and a model run gives every row's
   value. The sweep's limit set is the rows with each one the point breaks at the point's
   own value, and the swept parameter's least in the swept timing exactly the design. *)
let point ~rows ~parameter ~cycles ~measure ~words ~run_cycles (bench : Bench.t) =
  match
    Timed_program.check ?period:(Bench.period bench) ~config:bench.config bench.source
  with
  | Error refusal ->
    let why =
      match refusal.faults with
      | { reason; line; _ } :: _ -> [%string "line %{line#Int}: %{reason}"]
      | [] -> Error.to_string_hum refusal.error
    in
    Second [%string "%{Bench.time cycles}: the kernel refuses it, %{why}"]
  | Ok _ ->
    let measured = measure (Run.create bench ~words ~cycles:run_cycles) in
    let verdicts = check_rows rows measured in
    let sweep_limits =
      List.map verdicts ~f:(fun { row; value; ok } ->
        match ok, value with
        | false, Some cycles -> own row ~cycles
        | _ -> row)
    in
    let designed = Measured.least measured ("swept " ^ parameter) in
    First
      { Point.cycles
      ; bench
      ; words
      ; run_cycles
      ; verdicts
      ; in_spec = List.for_all verdicts ~f:(fun v -> v.ok)
      ; sweep_limits
      ; designed
      ; sweep_ok =
          List.for_all (check_rows sweep_limits measured) ~f:(fun v -> v.ok)
          && [%equal: int option] designed (Some cycles)
      ; measured
      }
;;

module Sk6812 = struct
  module Timing = struct
    type t =
      { h0 : int
      ; h1 : int
      ; l0 : int
      ; l1 : int
      ; gap : int
      }
  end

  (* the library bench's: Ws2812.latching ~gaps:4 ~third:17 ~tail:8 *)
  let nominal = { Timing.h0 = 17; h1 = 34; l0 = 42; l1 = 25; gap = 4 * 160 * 17 }

  (* from the frame's last fall to [gap:]'s wait, and on to the first rise *)
  let gap_overhead = 12

  (* [p], the longest [set] takes *)
  let unit = 31

  (* A frame is one pixel, 24 bits, three host words of a byte each, MSB first by
     autopull. The next bit is taken during the high and the low chosen by it, so every
     edge is the instruction after a deadline wait and [y] is free as a counter within
     each level. The line is low for [gap] between frames, exactly when the next frame's
     words are already in. *)
  let firmware (timing : Timing.t) =
    let fresh = labels "a" in
    let advance = advance ~fresh ~unit ~counter:"y" in
    let low ~cycles ~next =
      [%string
        {|    wait t
    set pins, 0              ; fall
%{advance cycles}    jmp %{next}
|}]
    in
    let path ~level ~high ~low:cycles =
      [%string
        {|%{level}:
    wait t
    set pins, 1              ; rise
%{advance high}    jmp x--, %{level}_more
    wait t
    set pins, 0              ; the frame's last fall
    jmp gap_from_last
%{level}_more:
    out y, 1                 ; the next bit
    jmp y--, %{level}_to_one
%{low ~cycles ~next:"zero"}%{level}_to_one:
%{low ~cycles ~next:"one"}|}]
    in
    [%string
      {|
    set pins, 0
    set p, %{unit#Int}
    mov t, now
    jmp gap_from_last
gap:
    wait t
    wait tx                  ; a frame's first word
    mov t, now
    add t, 7
    add t, 3
    set x, 23
    out y, 1
    jmp y--, one
    jmp zero
%{path ~level:"one" ~high:timing.h1 ~low:timing.l1}%{path ~level:"zero" ~high:timing.h0 ~low:timing.l0}gap_from_last:
%{advance (timing.gap - gap_overhead)}    jmp gap
|}]
  ;;

  let config =
    { Ws2812.config with
      out_base = Bench.neopixel
    ; set_base = Bench.neopixel
    ; out_shift = Left
    ; autopull = true
    ; pull_threshold = 8
    }
  ;;

  let words (red, green, blue) = List.map [ green; red; blue ] ~f:(fun b -> b lsl 8)
  let white = 0xff, 0xff, 0xff
  let black = 0, 0, 0

  let bits (red, green, blue) =
    List.concat_map [ green; red; blue ] ~f:(fun b ->
      List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1))
  ;;

  (* the frames each bench repeat sends, and the run's: both bit values and a gap *)
  let frames = [ white; black ]

  let measure frames (run : Run.t) =
    let runs = Run.runs run ~pin:Bench.neopixel in
    (* the line starts low *)
    let bits = List.concat_map frames ~f:bits in
    let rec go measured runs bits ~left =
      match runs, bits with
      | (true, _, high) :: (false, _, low) :: runs, bit :: bits ->
        let h, l = if bit = 1 then "T1H", "T1L" else "T0H", "T0L" in
        let measured = Measured.record ~swept:true measured h high in
        let last = left = 1 in
        let measured =
          if last
          then Measured.record ~swept:true measured "reset" low
          else
            Measured.record
              ~swept:true
              (Measured.record ~swept:true measured l low)
              "T"
              (high + low)
        in
        go measured runs bits ~left:(if last then 24 else left - 1)
      | [ (true, _, high) ], bit :: _ ->
        Measured.record ~swept:true measured (if bit = 1 then "T1H" else "T0H") high
      | _ -> measured
    in
    match runs with
    | (false, _, _) :: runs -> go [] runs bits ~left:24
    | _ -> raise_s [%message "BUG: the line starts high"]
  ;;

  (* the first gap, both frames and the gap after, with room *)
  let run_cycles (timing : Timing.t) =
    (3 * nominal.gap)
    + (2 * timing.gap)
    + (48 * Int.max (timing.h0 + timing.l0) (timing.h1 + timing.l1))
    + 20_000
  ;;

  let bench (timing : Timing.t) ~what =
    { Bench.name = "sk6812"
    ; what
    ; source = firmware timing
    ; config
    ; assumption = Nothing
    ; clock_hz
    ; load = None
    ; stimulus =
        Some
          { bursts = [ List.concat_map frames ~f:words ]
          ; quiet = 0
          ; cycles = run_cycles timing
          }
    }
  ;;

  let rows =
    let library = library_row Ws2812.protocol ~firmware:"sk6812" in
    let note3 parameter =
      let row = library ~parameter ~least:true in
      added_row
        ~firmware:"sk6812"
        ~parameter
        ~limit:(At_most 20_000.)
        ~sheet:{ row.sheet with page = "p.7, note 3" }
        ~margin:Cycle
    in
    [ library ~parameter:"T0H" ~least:true
    ; library ~parameter:"T0H" ~least:false
    ; library ~parameter:"T1H" ~least:true
    ; library ~parameter:"T1H" ~least:false
    ; library ~parameter:"T0L" ~least:true
    ; note3 "T0L"
    ; library ~parameter:"T1L" ~least:true
    ; note3 "T1L"
    ; library ~parameter:"T" ~least:true
    ; library ~parameter:"reset" ~least:true
    ]
  ;;

  (* a bit's period stays the nominal one where the swept high leaves room *)
  let period_0 = nominal.h0 + nominal.l0
  let period_1 = nominal.h1 + nominal.l1

  let sweep ~parameter ~nominal:nominal_cycles ~timing points =
    let observable =
      "Pico A's ADC channel 3, which falls about 1.6 mV with the first pixel white: each \
       repeat a white pixel, then a black one, or for the reset a white and a black back \
       to back, passing where the step between the two readings is within 30% of the \
       step the library's timing makes"
    in
    let points =
      List.map points ~f:(fun cycles ->
        let timing = timing cycles in
        point
          ~rows
          ~parameter
          ~cycles
          ~measure:(measure frames)
          ~words:(List.concat_map frames ~f:words)
          ~run_cycles:(run_cycles timing)
          (bench timing ~what:[%string "SK6812 %{parameter} at %{Bench.time cycles}"]))
    in
    { Sweep.part = "SK6812"
    ; parameter
    ; what =
        "Ws2812.latching's bench timing with one row moved, a pixel a frame, OUT3 \
         through the 74AHCT125 to the stick's first SK6812"
    ; rows
    ; nominal = nominal_cycles
    ; observable
    ; points
    }
  ;;

  let range lo hi = List.range lo hi ~stop:`inclusive

  (* past the sheet's 20 us, up to where the reset sweep finds a latch *)
  let long_lows =
    List.map
      [ 1.5
      ; 2.
      ; 3.
      ; 4.
      ; 5.
      ; 6.
      ; 7.
      ; 8.
      ; 10.
      ; 12.
      ; 15.
      ; 20.
      ; 25.
      ; 30.
      ; 40.
      ; 50.
      ; 60.
      ; 70.
      ; 80.
      ; 90.
      ; 100.
      ; 110.
      ; 120.
      ]
      ~f:us
  ;;

  let sweeps () =
    [ sweep
        ~parameter:"T0H"
        ~nominal:nominal.h0
        ~timing:(fun h0 -> { nominal with h0; l0 = Int.max nominal.l0 (period_0 - h0) })
        (range 2 40 @ [ 44; 48; 56 ])
    ; sweep
        ~parameter:"T1H"
        ~nominal:nominal.h1
        ~timing:(fun h1 -> { nominal with h1; l1 = Int.max nominal.l1 (period_1 - h1) })
        (range 2 40 @ [ 44; 48; 56; 64; 80; 96; 120; 160; 240; 480 ])
    ; sweep
        ~parameter:"T0L"
        ~nominal:nominal.l0
        ~timing:(fun l0 -> { nominal with l0 })
        (range 2 48 @ long_lows)
    ; sweep
        ~parameter:"T1L"
        ~nominal:nominal.l1
        ~timing:(fun l1 -> { nominal with l1 })
        (range 2 48 @ long_lows)
    ; sweep
        ~parameter:"reset"
        ~nominal:nominal.gap
        ~timing:(fun gap -> { nominal with gap })
        (List.map
           [ 1.
           ; 2.
           ; 3.
           ; 4.
           ; 5.
           ; 6.
           ; 7.
           ; 8.
           ; 9.
           ; 10.
           ; 12.
           ; 14.
           ; 16.
           ; 18.
           ; 20.
           ; 25.
           ; 30.
           ; 35.
           ; 40.
           ; 50.
           ; 60.
           ; 70.
           ; 80.
           ; 100.
           ; 102.
           ; 104.
           ; 106.
           ; 108.
           ; 110.
           ; 112.
           ; 114.
           ; 116.
           ; 118.
           ; 120.
           ; 150.
           ; 200.
           ; 250.
           ; 300.
           ]
           ~f:us)
    ]
  ;;
end

module Eeprom = struct
  module Timing = struct
    type t =
      { quarter : int
      ; hold : int option
      ; setup : int option
      ; free : int option
      }
  end

  (* the eeprom demo's quarter, 1 us: SCL at 250 kHz *)
  let nominal =
    { Timing.quarter = Bench.quarter ~hz:250_000; hold = None; setup = None; free = None }
  ;;

  (* cycles the patches spend around their own deadlines, so each timing is exact *)
  let setup_overhead = 1
  let free_overhead = 6

  (* [I2c.master_host_rate] without its bus clear, with each START's and repeated START's
     hold, the data's setup before SCL rises, and the bus free time from a STOP to the
     next START moved where [timing] says. *)
  let firmware (timing : Timing.t) =
    let fresh = labels "e" in
    let advance ~side =
      advance ~side:[%string " side %{side#Int}"] ~fresh ~unit:timing.quarter
    in
    let source = I2c.master_host_rate_without_bus_clear in
    let source =
      match timing.hold with
      | None -> source
      | Some hold ->
        let held ~after =
          let pattern rest =
            [%string
              "    wait t+ side 0\n\
              \    set pindirs, 1 side 0        ; SDA low while SCL high\n\
              \    wait t+ side 0\n\
              \    nop side 1\n\
               %{rest}"]
          in
          Bench.patch
            ~pattern:(pattern after)
            ~with_:
              (pattern after
               |> String.substr_replace_first
                    ~pattern:"wait t+ side 0\n"
                    ~with_:"wait t side 0\n"
               |> String.substr_replace_first
                    ~pattern:"SCL high\n"
                    ~with_:[%string "SCL high\n%{advance ~side:0 hold}"])
        in
        source
        |> held ~after:"    add t, p side 1              ; a quarter of slack"
        |> held ~after:"    add t, p side 1\nsend_or_read:"
    in
    let source =
      match timing.setup with
      | None -> source
      | Some setup ->
        Bench.patch
          source
          ~pattern:
            "send:\n\
            \    wait t+ side 1\n\
            \    out y, 1 side 1\n\
            \    mov pindirs, !y side 1       ; SDA follows the bit\n"
          ~with_:
            [%string
              "send:\n\
              \    wait t side 1\n\
              \    out y, 1 side 1\n\
              \    mov pindirs, !y side 1       ; SDA follows the bit\n\
               %{advance ~side:1 (setup + setup_overhead)}"]
    in
    match timing.free with
    | None -> source
    | Some free ->
      source
      |> Bench.patch
           ~pattern:"SDA released while SCL high\n    wait t+ side 0\n    jmp idle"
           ~with_:"SDA released while SCL high\n    jmp idle"
      |> Bench.patch
           ~pattern:
             "    mov t, now side 0\n\
             \    add t, p side 0\n\
             \    add t, p side 0              ; two quarters of slack for the dispatch\n"
           ~with_:
             [%string "    mov t, now side 0\n%{advance ~side:0 (free - free_overhead)}"]
  ;;

  let device = 0x50
  let page = 0x7fc0
  let read_count = 8

  (* an address probe, then a random read of the page's first bytes: a STOP and a START
     back to back, a repeated START, and the master's bits and acks *)
  let words ~device =
    let word = I2c.word in
    [ word ~start:true ~stop:true (device lsl 1)
    ; word ~start:true (device lsl 1)
    ; word (page lsr 8)
    ; word (page land 0xff)
    ; word ~start:true ((device lsl 1) lor 1)
    ]
    @ List.init (read_count - 1) ~f:(fun _ -> word ~read:true 0)
    @ [ word ~read:true ~stop:true 0 ]
  ;;

  let config = I2c.on_bench_pins ~jmp_pin:Bench.sda I2c.config

  let bench (timing : Timing.t) ~what =
    { Bench.name = "i2c_master"
    ; what
    ; source = firmware timing
    ; config
    ; assumption = Period timing.quarter
    ; clock_hz
    ; load = Some timing.quarter
    ; stimulus = Some { bursts = [ words ~device ]; quiet = 0; cycles = 0 }
    }
  ;;

  (* SCL and SDA as the master leaves them, every line pulled up *)
  let measure (run : Run.t) =
    let level pin cycle = (run.pins.(cycle) lsr pin) land 1 = 1 in
    let add = Measured.record ~swept:true in
    let rec go measured cycle ~scl ~sda ~scl_rose ~scl_fell ~sda_moved ~start ~stop =
      if cycle = Array.length run.pins
      then measured
      else (
        let scl' = level Bench.scl cycle
        and sda' = level Bench.sda cycle in
        let since at = Option.map at ~f:(fun at -> cycle - at) in
        let add_opt measured parameter = function
          | Some value -> add measured parameter value
          | None -> measured
        in
        let measured, start, stop =
          match Bool.equal scl scl', Bool.equal sda sda' with
          | false, _ when scl' ->
            let measured = add_opt measured "TLOW" (since scl_fell) in
            let measured = add_opt measured "TSU:DAT" (since sda_moved) in
            add_opt measured "1/fSCL" (since scl_rose), start, stop
          | false, _ ->
            let measured = add_opt measured "THIGH" (since scl_rose) in
            add_opt measured "THD:STA" (since start), None, stop
          | true, false when scl && not sda' ->
            let measured = add_opt measured "TSU:STA" (since scl_rose) in
            add_opt measured "TBUF" (since stop), Some cycle, None
          | true, false when scl ->
            add_opt measured "TSU:STO" (since scl_rose), start, Some cycle
          | true, _ -> measured, start, stop
        in
        go
          measured
          (cycle + 1)
          ~scl:scl'
          ~sda:sda'
          ~scl_rose:(if scl' && not scl then Some cycle else scl_rose)
          ~scl_fell:(if scl && not scl' then Some cycle else scl_fell)
          ~sda_moved:(if Bool.equal sda sda' then sda_moved else Some cycle)
          ~start
          ~stop)
    in
    go
      []
      0
      ~scl:true
      ~sda:true
      ~scl_rose:None
      ~scl_fell:None
      ~sda_moved:None
      ~start:None
      ~stop:None
  ;;

  let rows =
    let library = library_row I2c.protocol ~firmware:"i2c_master" in
    let thigh = library ~parameter:"THIGH" ~least:true in
    [ added_row
        ~firmware:"i2c_master"
        ~parameter:"1/fSCL"
        ~limit:(At_least 2_500.)
        ~sheet:{ thigh.sheet with page = "p.4, param 1, FCLK 400 kHz" }
        ~margin:Cycle
    ; thigh
    ; library ~parameter:"TLOW" ~least:true
    ; library ~parameter:"THD:STA" ~least:true
    ; library ~parameter:"TSU:STA" ~least:true
    ; library ~parameter:"TSU:DAT" ~least:true
    ; library ~parameter:"TSU:STO" ~least:true
    ; library ~parameter:"TBUF" ~least:true
    ]
  ;;

  let sweep ~parameter ~what ~nominal:nominal_cycles ~timing points =
    let points =
      List.map points ~f:(fun cycles ->
        let timing = timing cycles in
        point
          ~rows
          ~parameter
          ~cycles
          ~measure
          ~words:(words ~device)
          ~run_cycles:
            ((List.length (words ~device) + 2) * ((40 * timing.Timing.quarter) + 40))
          (bench timing ~what:[%string "24LC256 %{parameter} at %{Bench.time cycles}"]))
    in
    { Sweep.part = "24LC256"
    ; parameter
    ; what
    ; rows
    ; nominal = nominal_cycles
    ; observable =
        "the part's ACKs and the bytes it returns as the chip reads them, against a read \
         of the same bytes at the eeprom demo's timing; sigrok's i2c decode of analyser \
         B beside"
    ; points
    }
  ;;

  let sweeps () =
    let q = nominal.quarter in
    [ sweep
        ~parameter:"1/fSCL"
        ~what:"I2c.master_host_rate's quarter: every phase moves with it"
        ~nominal:(4 * q)
        ~timing:(fun period -> { nominal with quarter = period / 4 })
        (List.map
           [ 48; 40; 32; 28; 24; 20; 18; 16; 14; 12; 11; 10; 9; 8; 7; 6; 5; 4; 3 ]
           ~f:(fun quarter -> 4 * quarter))
    ; sweep
        ~parameter:"THD:STA"
        ~what:"each START's and repeated START's hold, at 250 kHz"
        ~nominal:q
        ~timing:(fun hold -> { nominal with hold = Some hold })
        (List.range 1 60 ~stride:2 ~stop:`inclusive)
    ; sweep
        ~parameter:"TSU:DAT"
        ~what:
          "the master's data setup before SCL rises, at 166.7 kHz so SCL's low stays in \
           spec"
        ~nominal:(72 - 1)
        ~timing:(fun setup -> { nominal with quarter = 72; setup = Some setup })
        (List.range 1 40 ~stop:`inclusive @ [ 44; 48; 56; 64; 70 ])
    ; sweep
        ~parameter:"TBUF"
        ~what:"the bus free time from the probe's STOP to the read's START, at 250 kHz"
        ~nominal:149
        ~timing:(fun free -> { nominal with free = Some free })
        (List.range 6 80 ~stride:2 ~stop:`inclusive @ [ 90; 100; 120; 149 ])
    ]
  ;;
end

module Ds18b20 = struct
  module Timing = struct
    type t =
      { low1 : int
      ; sample : int
      ; low0 : int
      ; slot : int
      ; reset_low : int
      ; presence : int
      ; reset_high : int
      }
  end

  let unit = Bench.cycles_in ~us:1

  (* the library bench's, at its 6 us unit *)
  let nominal =
    let u = Bench.cycles_in ~us:6 in
    { Timing.low1 = u
    ; sample = 2 * u
    ; low0 = 11 * u
    ; slot = 12 * u
    ; reset_low = 84 * u
    ; presence = 12 * u
    ; reset_high = 80 * u
    }
  ;;

  (* Events of a slot from its fall, in order, actions of one instant together and a
     sample after a release. The bits are in [osr] inverted, so [out pindirs, 1] lets a
     one go. *)
  let slot_events (t : Timing.t) =
    if t.low1 > t.low0
    then raise_s [%message "BUG: a one let go after a zero" (t.low1 : int) (t.low0 : int)];
    let events =
      [ t.low1, "    out pindirs, 1           ; a one lets go\n"
      ; t.low0, "    set pindirs, 0           ; a zero lets go\n"
      ; t.sample, "    in pins, 1               ; sample\n"
      ]
      |> List.stable_sort ~compare:(fun (a, _) (b, _) -> compare a b)
    in
    if List.exists events ~f:(fun (at, _) -> at <= 0 || at >= t.slot)
    then raise_s [%message "BUG: an event outside the slot" (t.slot : int)];
    List.group events ~break:(fun (a, _) (b, _) -> a <> b)
    |> List.map ~f:(fun group ->
      fst (List.hd_exn group), String.concat (List.map group ~f:snd))
  ;;

  let timing_code ~name ~fresh (t : Timing.t) =
    let advance = advance ~fresh ~unit ~counter:"y" in
    let at = ref 0 in
    let events =
      List.map (slot_events t) ~f:(fun (time, actions) ->
        let code = [%string "%{advance (time - !at)}    wait t\n%{actions}"] in
        at := time;
        code)
      |> String.concat
    in
    if t.presence >= t.reset_high
    then
      raise_s [%message "BUG: presence sampled after the reset's high" (t.presence : int)];
    [%string
      {|
slot_%{name}:
    wait t
    set pindirs, 1           ; the slot starts
%{events}%{advance (t.slot - !at)}    jmp x--, slot_%{name}
    wait t                   ; the last slot's end
    in null, 8
    push
    jmp idle
reset_%{name}:
    wait t
    set pindirs, 1
%{advance t.reset_low}    wait t
    set pindirs, 0           ; the reset lets go
%{advance t.presence}    wait t
    in pins, 1               ; presence
%{advance (t.reset_high - t.presence)}    wait t
    in null, 15
    push
    jmp idle
|}]
  ;;

  (* Host words after the unit: reset[0], swept[1], byte[9:2]. Each word is answered as
     the library's: the byte as sampled, or 0 for a presence. [swept] picks the second
     timing for that word. *)
  let firmware ~swept =
    let fresh = labels "w" in
    [%string
      {|
    wait tx
    pull
    mov p, osr               ; the unit
idle:
    wait tx
    pull
    out y, 1                 ; reset
    out x, 1                 ; swept
    mov osr, !osr            ; a released line is a one
    mov t, now
    add t, p
    jmp x--, swept
    jmp y--, reset_nominal
    set x, 7
    jmp slot_nominal
swept:
    jmp y--, reset_swept
    set x, 7
    jmp slot_swept
%{timing_code ~name:"nominal" ~fresh nominal}%{timing_code ~name:"swept" ~fresh swept}|}]
  ;;

  let reset ~swept = 1 lor (Bool.to_int swept lsl 1)
  let byte ~swept b = ((b land 0xff) lsl 2) lor (Bool.to_int swept lsl 1)

  (* both timings, both bit values *)
  let words =
    [ reset ~swept:false
    ; byte ~swept:false 0x0f
    ; reset ~swept:true
    ; byte ~swept:true 0x0f
    ; byte ~swept:false 0x0f
    ]
  ;;

  let config =
    { One_wire.config with
      in_base = Bench.one_wire
    ; out_base = Bench.one_wire
    ; set_base = Bench.one_wire
    }
  ;;

  let bench timing ~what =
    { Bench.name = "one_wire"
    ; what
    ; source = firmware ~swept:timing
    ; config
    ; assumption = Period unit
    ; clock_hz
    ; load = Some unit
    ; stimulus = Some { bursts = [ words ]; quiet = 0; cycles = 0 }
    }
  ;;

  (* Lows and the high after each, in the order the words make them, and the samples: each
     slot's against its fall, a presence's against the reset's release. *)
  let measure (run : Run.t) =
    let runs = Run.runs run ~pin:Bench.one_wire in
    let lows =
      List.filter_mapi runs ~f:(fun i (level, start, length) ->
        if level
        then None
        else (
          let high =
            match List.nth runs (i + 1) with
            | Some (_, _, high) -> Some high
            | None -> None
          in
          Some (start, length, high)))
    in
    let events =
      List.concat_map words ~f:(fun word ->
        let swept = word land 2 <> 0 in
        if word land 1 = 1
        then [ `Reset swept ]
        else List.init 8 ~f:(fun i -> `Bit (swept, (word lsr (2 + i)) land 1)))
    in
    let samples = ref run.samples in
    let next_sample () =
      match !samples with
      | s :: rest ->
        samples := rest;
        s
      | [] -> raise_s [%message "BUG: a sample missing"]
    in
    if List.length lows < List.length events
    then raise_s [%message "BUG: lows missing" (List.length lows : int)];
    List.fold
      (List.zip_exn (List.take lows (List.length events)) events)
      ~init:[]
      ~f:(fun measured ((start, low, high), event) ->
        let sample = next_sample () in
        let add =
          match event with
          | `Reset swept | `Bit (swept, _) -> Measured.record ~swept
        in
        let measured =
          match event with
          | `Reset _ ->
            let measured =
              add (add measured "tRSTL" low) "presence sample" (sample - (start + low))
            in
            Option.value_map high ~default:measured ~f:(add measured "tRSTH")
          | `Bit (_, bit) ->
            let measured = add measured (if bit = 1 then "tLOW1" else "tLOW0") low in
            let measured =
              Option.value_map high ~default:measured ~f:(fun h ->
                add (add measured "tREC" h) "tSLOT + tREC" (low + h))
            in
            (* in a zero's slot the master samples its own low; a read is a one *)
            if bit = 1 then add measured "read sample" (sample - start) else measured
        in
        measured)
  ;;

  let sheet =
    let row =
      library_row One_wire.protocol ~firmware:"one_wire" ~parameter:"tRSTL" ~least:true
    in
    row.sheet
  ;;

  let rows =
    let library = library_row One_wire.protocol ~firmware:"one_wire" in
    let added parameter limit page =
      added_row
        ~firmware:"one_wire"
        ~parameter
        ~limit
        ~sheet:{ sheet with page }
        ~margin:Cycle
    in
    [ library ~parameter:"tLOW1" ~least:true
    ; library ~parameter:"tLOW1" ~least:false
    ; library ~parameter:"tLOW0" ~least:true
    ; library ~parameter:"tLOW0" ~least:false
    ; library ~parameter:"tREC" ~least:true
    ; library ~parameter:"tSLOT + tREC" ~least:true
    ; library ~parameter:"tRSTL" ~least:true
    ; library ~parameter:"tRSTH" ~least:true
    ; added "read sample" (At_most 15_000.) "p.20, tRDV; p.16"
    ; added "presence sample" (At_least 60_000.) "p.20, tPDHIGH max; p.15"
    ; added "presence sample" (At_most 75_000.) "p.20, tPDHIGH max + tPDLOW min; p.15"
    ]
  ;;

  (* a reset and [slots] slots *)
  let length (t : Timing.t) ~slots = t.reset_low + t.reset_high + (slots * t.slot)

  let sweep ~parameter ~what ~nominal:nominal_cycles ~timing points =
    let points =
      List.map points ~f:(fun cycles ->
        let swept = timing cycles in
        point
          ~rows
          ~parameter
          ~cycles
          ~measure
          ~words
          ~run_cycles:(length nominal ~slots:16 + length swept ~slots:8 + us 200.)
          (bench swept ~what:[%string "DS18B20 %{parameter} at %{Bench.time cycles}"]))
    in
    { Sweep.part = "DS18B20"
    ; parameter
    ; what
    ; rows
    ; nominal = nominal_cycles
    ; observable =
        "the part's presence pulse and the bytes it returns as the chip samples them, \
         against a read at the library's timing; analyser B's capture beside, for the \
         part's own presence and read-zero times"
    ; points
    }
  ;;

  (* whole microseconds, and steps of [stride] *)
  let uss = List.map ~f:(fun n -> us (Float.of_int n))
  let range ?(stride = 1) lo hi = List.range lo hi ~stride ~stop:`inclusive

  let sweeps () =
    let n = nominal in
    [ sweep
        ~parameter:"tRSTL"
        ~what:"the reset's low, then READ ROM at the library's timing"
        ~nominal:n.reset_low
        ~timing:(fun reset_low -> { n with reset_low })
        (uss
           (range 5 30 ~stride:5
            @ range 40 100 ~stride:10
            @ [ 120; 140; 160 ]
            @ range 200 240 ~stride:5
            @ [ 300; 400; 480; 504 ]))
    ; sweep
        ~parameter:"presence sample"
        ~what:"the master's presence sample after the reset lets go, then READ ROM"
        ~nominal:n.presence
        ~timing:(fun presence -> { n with presence })
        (uss
           ([ 2; 5; 10; 15; 20; 25 ]
            @ range 30 35
            @ range 40 70 ~stride:5
            @ [ 72; 75; 80; 90; 100; 120 ]
            @ range 140 160 ~stride:5
            @ range 180 300 ~stride:20))
    ; sweep
        ~parameter:"tLOW0"
        ~what:"a zero's low in the scratchpad bytes written, read back at the library's"
        ~nominal:n.low0
        ~timing:(fun low0 ->
          { n with
            low0
          ; low1 = Int.min n.low1 (low0 / 2)
          ; slot = Int.max n.slot (low0 + us 6.)
          })
        (uss
           (range 2 28 ~stride:2
            @ [ 29; 30; 32; 35; 40; 45; 50; 55; 60; 66; 80; 100; 114 ]))
    ; sweep
        ~parameter:"tLOW1"
        ~what:"a one's low in the scratchpad bytes written, read back at the library's"
        ~nominal:n.low1
        ~timing:(fun low1 -> { n with low1 })
        (uss
           (range 1 6
            @ range 8 14 ~stride:2
            @ [ 15; 16; 18; 20; 22; 24; 26; 28; 29; 30; 32; 35; 40; 45; 50; 55 ]))
    ; sweep
        ~parameter:"read sample"
        ~what:"the master's sample in READ ROM's read slots, after a 6 us low"
        ~nominal:n.sample
        ~timing:(fun sample -> { n with sample })
        (uss
           (range 7 20
            @ range 22 28 ~stride:2
            @ [ 29 ]
            @ range 30 40 ~stride:2
            @ [ 45; 50; 55; 60 ]))
    ; sweep
        ~parameter:"tREC"
        ~what:"the high after a zero's 66 us in the scratchpad bytes written"
        ~nominal:(n.slot - n.low0)
        ~timing:(fun recovery -> { n with slot = n.low0 + recovery })
        ([ 1; 2; 4 ] @ range 8 12 @ [ 16; 24; 32; 40; 48; 56; 72; 96; 144; 288 ])
    ; sweep
        ~parameter:"tSLOT + tREC"
        ~what:"the whole slot, a zero's low 6 us short of it, in the bytes written"
        ~nominal:n.slot
        ~timing:(fun slot ->
          let low0 = slot - us 6. in
          { n with
            slot
          ; low0
          ; low1 = Int.min n.low1 (low0 / 2)
          ; sample = Int.min n.sample (slot - 1)
          })
        (uss
           (range 10 30 ~stride:5
            @ range 31 35
            @ range 40 60 ~stride:5
            @ [ 61; 62; 65; 72 ]))
    ]
  ;;
end

let all () = Sk6812.sweeps () @ Eeprom.sweeps () @ Ds18b20.sweeps ()
