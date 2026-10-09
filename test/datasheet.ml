open! Core
open Protocol_emulator

module Sheet = struct
  type t =
    { part : string
    ; document : string
    ; page : string
    }
end

module Margin = struct
  type t =
    | Cycle
    | Ns of
        { ns : float
        ; why : string
        }
end

module Levels = struct
  type t = (bool * int) list
end

module Bound = struct
  type t =
    | Kernel of (Program_config.t -> int -> Kernel.Spacing.Spec.t)
    | Run of
        { pin : Program_config.t -> int
        ; widths : clock_hz:int -> Levels.t -> int list
        }
end

module Limit = struct
  type t =
    | At_least of float
    | At_most of float
end

type t =
  { firmware : string
  ; parameter : string
  ; limit : Limit.t
  ; sheet : Sheet.t
  ; margin : Margin.t
  ; bound : Bound.t
  }

let none ~own:_ ~other:_ = 0
let never ~own:_ ~other:_ = false

(* [n] cycles at least before an edge of [a] where [hold] holds of the two bits before it,
   and since [b]'s last edge where [apart] does *)
let spacing ?(dirs = false) ?(hold = never) ?(apart = never) ~a ~b () n =
  let at f ~own ~other = if f ~own ~other then n else 0 in
  let hold = at hold
  and apart = at apart in
  { Kernel.Spacing.Spec.a
  ; b
  ; dirs
  ; hold_a = hold
  ; apart_a = apart
  ; hold_b = none
  ; apart_b = none
  }
;;

let swap (spec : Kernel.Spacing.Spec.t) =
  { spec with
    a = spec.b
  ; b = spec.a
  ; hold_a = spec.hold_b
  ; apart_a = spec.apart_b
  ; hold_b = spec.hold_a
  ; apart_b = spec.apart_a
  }
;;

(* one pin at one level: high, or for [dirs] held low *)
let level ?dirs ~pin ~high () =
  Bound.Kernel
    (fun config ->
      let a = pin config in
      spacing ?dirs ~a ~b:(a + 1) ~hold:(fun ~own ~other:_ -> Bool.equal own high) ())
;;

let set_pin (config : Program_config.t) = config.set_base
let side_pin (config : Program_config.t) = config.side_set_base
let cycles ~clock_hz ns = Float.iround_down_exn (ns *. Float.of_int clock_hz /. 1e9)

(* each level after the one before it *)
let pairs (levels : Levels.t) =
  List.zip_exn (List.drop_last_exn levels) (List.tl_exn levels)
;;

let run ~pin widths = Bound.Run { pin; widths }
let lows levels = List.filter_map levels ~f:(fun (high, n) -> Option.some_if (not high) n)

(* SK6812: the low of a bit is under 20 us (012 B/0, note 3), so a longer one latches, and
   a high under 500 ns is a zero, between the B/0 sheet's T0H and T1H. A cycle of margin
   covers the 74AHCT125's skew between rise and fall, 5.5 ns at most. *)
let sk6812 =
  let rev01 =
    { Sheet.part = "SK6812"
    ; document = "SPC/SK6812 Rev. 01"
    ; page = "p.5, 0.3/0.6/0.9/0.6 us +-0.15"
    }
  and b0 =
    { Sheet.part = "SK6812"; document = "OSK-SPC-SK6812-012 Rev. B/0"; page = "p.7" }
  in
  let bits ~clock_hz levels =
    List.filter_map (pairs levels) ~f:(fun ((high, h), (_, l)) ->
      Option.some_if (high && l < cycles ~clock_hz 20_000.) (h, l))
  in
  let zero ~clock_hz (h, _) = h < cycles ~clock_hz 500. in
  let code ~one f =
    run ~pin:set_pin (fun ~clock_hz levels ->
      List.filter_map (bits ~clock_hz levels) ~f:(fun bit ->
        Option.some_if (Bool.equal one (not (zero ~clock_hz bit))) (f bit)))
  in
  let limit parameter limit sheet bound =
    { firmware = "sk6812"; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit "T0H" (At_least 200.) b0 (level ~pin:set_pin ~high:true ())
  ; limit "T0H" (At_most 400.) b0 (code ~one:false fst)
  ; limit "T1H" (At_least 600.) b0 (code ~one:true fst)
  ; limit "T1H" (At_most 750.) rev01 (code ~one:true fst)
  ; limit "T0L" (At_least 800.) b0 (code ~one:false snd)
  ; limit "T0L" (At_most 1050.) rev01 (code ~one:false snd)
  ; limit "T1L" (At_least 450.) rev01 (level ~pin:set_pin ~high:false ())
  ; limit "T1L" (At_most 750.) rev01 (code ~one:true snd)
  ; limit
      "T"
      (At_least 1200.)
      { b0 with page = "p.7, note 2" }
      (run ~pin:set_pin (fun ~clock_hz levels ->
         List.map (bits ~clock_hz levels) ~f:(fun (h, l) -> h + l)))
  ; limit
      "reset"
      (At_least 200_000.)
      b0
      (run ~pin:set_pin (fun ~clock_hz levels ->
         List.filter (lows levels) ~f:(fun l -> l >= cycles ~clock_hz 20_000.)))
  ]
;;

(* DS18B20: a low under tLOW0's 60 us is a write 1 or a read, one from there to tRSTL's
   480 a write 0, and longer a reset *)
let ds18b20 =
  let sheet = { Sheet.part = "DS18B20"; document = "Maxim REV 042208"; page = "p.20" } in
  let reset ~clock_hz l = l >= cycles ~clock_hz 480_000. in
  let lows_from least ?(below = Float.infinity) () =
    run ~pin:set_pin (fun ~clock_hz levels ->
      List.filter (lows levels) ~f:(fun l ->
        l >= cycles ~clock_hz least && Float.(of_int l < below *. of_int clock_hz /. 1e9)))
  in
  (* each low with the high after it *)
  let slots f =
    run ~pin:set_pin (fun ~clock_hz levels ->
      List.filter_map (pairs levels) ~f:(fun ((high, l), (_, h)) ->
        if high then None else f ~clock_hz l h))
  in
  let limit parameter limit bound =
    { firmware = "one_wire"; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit "tLOW1" (At_least 1_000.) (level ~dirs:true ~pin:set_pin ~high:true ())
  ; limit "tLOW1" (At_most 15_000.) (lows_from 0. ~below:60_000. ())
  ; limit "tLOW0" (At_least 60_000.) (lows_from 60_000. ~below:480_000. ())
  ; limit "tLOW0" (At_most 120_000.) (lows_from 60_000. ~below:480_000. ())
  ; limit "tREC" (At_least 1_000.) (level ~dirs:true ~pin:set_pin ~high:false ())
  ; limit
      "tSLOT + tREC"
      (At_least 61_000.)
      (slots (fun ~clock_hz l h -> Option.some_if (not (reset ~clock_hz l)) (l + h)))
  ; limit "tRSTL" (At_least 480_000.) (lows_from 480_000. ())
  ; limit
      "tRSTH"
      (At_least 480_000.)
      (slots (fun ~clock_hz l h -> Option.some_if (reset ~clock_hz l) h))
  ]
;;

(* Bosch: a node joins the bus after eleven recessive bits; the transceiver's rate *)
let can firmware =
  let bosch =
    { Sheet.part = "CAN 2.0A"
    ; document = "Bosch CAN 2.0, BCANPSV2.0 Rev. 3"
    ; page = "s.2.15 p.2-6, eleven recessive bits"
    }
  and transceiver =
    { Sheet.part = "SN65HVD230"; document = "TI SLOS346O"; page = "p.1, up to 1 Mbps" }
  in
  let limit parameter limit sheet bound =
    { firmware; parameter; limit; sheet; margin = Cycle; bound }
  in
  [ limit "recessive" (At_least 1_000.) transceiver (level ~pin:set_pin ~high:true ())
  ; limit "dominant" (At_least 1_000.) transceiver (level ~pin:set_pin ~high:false ())
  ; limit
      "idle to SOF"
      (At_least 22_000.)
      bosch
      (run ~pin:set_pin (fun ~clock_hz:_ levels ->
         List.drop_while levels ~f:(fun (high, _) -> not high)
         |> List.hd
         |> Option.to_list
         |> List.map ~f:snd))
  ]
;;

let can_receiver =
  [ { firmware = "can_receiver"
    ; parameter = "ACK"
    ; limit = At_least 1_000.
    ; sheet =
        { part = "SN65HVD230"; document = "TI SLOS346O"; page = "p.1, up to 1 Mbps" }
    ; margin = Cycle
    ; bound = level ~pin:set_pin ~high:false ()
    }
  ]
;;

(* 24LC256 at 3.3 V, the 2.5 to 5.5 V rows. The kernel times the master's pins, so a width
   from a release to the next edge loses the line's rise, TR of 300 ns at most. *)
let i2c firmware =
  let sheet page =
    { Sheet.part = "24LC256"; document = "Microchip DS20001203W, Table 1-2"; page }
  in
  let rise = Margin.Ns { ns = 300.; why = "TR, param 4" } in
  let scl = side_pin
  and sda = set_pin in
  (* the bits before an edge are true while the master holds the line low *)
  let pair ?hold ?apart () =
    Bound.Kernel
      (fun config -> spacing ~dirs:true ?hold ?apart ~a:(scl config) ~b:(sda config) ())
  in
  let sda_pair ?hold ?apart () =
    Bound.Kernel
      (fun config n ->
        swap (spacing ~dirs:true ?hold ?apart ~a:(sda config) ~b:(scl config) () n))
  in
  let limit parameter ns page margin bound =
    { firmware; parameter; limit = At_least ns; sheet = sheet page; margin; bound }
  in
  [ limit "THIGH" 600. "p.3, param 2" rise (pair ~hold:(fun ~own ~other:_ -> not own) ())
  ; limit "TLOW" 1300. "p.3, param 3" Cycle (pair ~hold:(fun ~own ~other:_ -> own) ())
  ; limit
      "THD:STA"
      600.
      "p.3, param 6"
      Cycle
      (pair ~apart:(fun ~own ~other -> (not own) && other) ())
  ; limit
      "TSU:STA"
      600.
      "p.3, param 7"
      rise
      (sda_pair ~apart:(fun ~own ~other -> (not own) && not other) ())
  ; limit "TSU:DAT" 100. "p.3, param 9" rise (pair ~apart:(fun ~own ~other:_ -> own) ())
  ; limit
      "TSU:STO"
      600.
      "p.3, param 10"
      rise
      (sda_pair ~apart:(fun ~own ~other -> own && not other) ())
  ; limit
      "TBUF"
      1300.
      "p.4, param 14"
      rise
      (sda_pair ~hold:(fun ~own ~other -> (not own) && not other) ())
  ]
;;

(* W25Q64JV: CLK high and low are 45% of the 20 ns of 03h's 50 MHz, the strictest reading;
   CS high is tRES1's 3 us, which a read after ABh needs and every frame keeps *)
let w25q64 firmware =
  let sheet page = { Sheet.part = "W25Q64JV"; document = "Winbond Rev. M"; page } in
  let sck = side_pin
  and cs config = side_pin config + 1 in
  let pair ?hold ?apart () =
    Bound.Kernel (fun config -> spacing ?hold ?apart ~a:(sck config) ~b:(cs config) ())
  in
  let cs_pair ?hold ?apart () =
    Bound.Kernel
      (fun config n -> swap (spacing ?hold ?apart ~a:(cs config) ~b:(sck config) () n))
  in
  let limit parameter ns page bound =
    { firmware
    ; parameter
    ; limit = At_least ns
    ; sheet = sheet page
    ; margin = Cycle
    ; bound
    }
  in
  [ limit "tCLH" 9. "p.64" (pair ~hold:(fun ~own ~other -> own && not other) ())
  ; limit "tCLL" 9. "p.64" (pair ~hold:(fun ~own ~other -> (not own) && not other) ())
  ; limit "tSLCH" 3. "p.64" (pair ~apart:(fun ~own:_ ~other -> not other) ())
  ; limit "tCHSH" 3. "p.64" (cs_pair ~apart:(fun ~own ~other:_ -> not own) ())
  ; limit "tSHSL2" 50. "p.64" (cs_pair ~hold:(fun ~own ~other:_ -> own) ())
  ; limit "tRES1" 3_000. "p.65" (cs_pair ~hold:(fun ~own ~other:_ -> own) ())
  ]
;;

(* RP2040 recommends 24 MHz at most; each half at least half of its period keeps it *)
let swd =
  let sheet =
    { Sheet.part = "RP2040"
    ; document = "RP2040 datasheet, 2025-02-20"
    ; page = "s.2.3.4 p.61"
    }
  in
  List.map
    [ "SWCLK high", true; "SWCLK low", false ]
    ~f:(fun (parameter, high) ->
      { firmware = "swd"
      ; parameter
      ; limit = At_least (1e9 /. 24e6 /. 2.)
      ; sheet
      ; margin = Cycle
      ; bound = level ~pin:side_pin ~high ()
      })
;;

let all =
  sk6812
  @ ds18b20
  @ can "can"
  @ can "can_sender"
  @ can_receiver
  @ i2c "i2c_master"
  @ i2c "i2c_master_stretch"
  @ swd
  @ List.concat_map Spi_cs.Mode.all ~f:(fun mode ->
    w25q64 [%string "spi_cs_mode%{Spi_cs.Mode.to_int mode#Int}"])
;;

let exempt =
  [ "spi_master", "no demo loads it"
  ; "start_hold", "it drives no pin: it listens to Pico B's I2C"
  ; "ethernet", "no demo on the bench: it needs the Icepi's 40 MHz build"
  ]
;;

module Stimulus = struct
  type t =
    { bursts : int list list
    ; quiet : int
    ; cycles : int
    }
end

let stimulus (bench : Bench.t) =
  let load = Option.to_list bench.load in
  match bench.name with
  | "sk6812" ->
    let pixels =
      List.concat_map
        [ { Ws2812.Pixel.red = 0x0f; green = 0xf0; blue = 0x55 }
        ; { red = 0xaa; green = 0x33; blue = 0xcc }
        ]
        ~f:Ws2812.Pixel.words
    in
    Some { Stimulus.bursts = [ pixels; pixels; pixels ]; quiet = 200; cycles = 60_000 }
  | "one_wire" ->
    Some
      { bursts = [ (load @ One_wire.[ reset; byte 0x00; byte 0xa5; byte 0xff ]) ]
      ; quiet = 0
      ; cycles = 200_000
      }
  | "can" | "can_sender" ->
    Some
      { bursts = [ load @ Can.words (Can.Frame.data ~id:0x4a [ 0x61 ]) ]
      ; quiet = 0
      ; cycles = 20_000
      }
  | _ -> None
;;

(* every line pulled up, nothing else driving, and the host on time *)
let levels (bench : Bench.t) ~pin (stimulus : Stimulus.t) =
  let timed = Bench.timed bench in
  let inputs = (1 lsl Isa.num_pins) - 1 in
  let level machine = (Machine.pins machine ~inputs lsr pin) land 1 = 1 in
  let rec go machine ~cycle ~queued ~bursts ~quiet acc =
    if cycle = stimulus.cycles
    then (
      if not (Machine.Fault.equal machine.Machine.fault Machine.Fault.none)
      then
        raise_s
          [%message
            "BUG: the run faulted" bench.name ~fault:(machine.fault : Machine.Fault.t)];
      (* the last level has not ended *)
      List.tl_exn acc |> List.rev)
    else (
      let queued, bursts =
        match queued, bursts with
        | [], next :: bursts when List.is_empty machine.tx_fifo && quiet >= stimulus.quiet
          -> next, bursts
        | _ -> queued, bursts
      in
      let machine, queued =
        match queued with
        | word :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine word |> ok_exn, rest
        | _ -> machine, queued
      in
      let before = level machine in
      let machine = Machine.step machine ~inputs in
      let machine = Option.value_map (Machine.read_rx machine) ~default:machine ~f:snd in
      let now = level machine in
      let acc =
        match acc with
        | (high, n) :: rest when Bool.equal high now -> (high, n + 1) :: rest
        | acc -> (now, 1) :: acc
      in
      go
        machine
        ~cycle:(cycle + 1)
        ~queued
        ~bursts
        ~quiet:(if Bool.equal before now then quiet + 1 else 0)
        acc)
  in
  let machine =
    Machine.create
      ~config:(Timed_program.config timed)
      ~program:(Timed_program.words timed)
    |> ok_exn
  in
  go machine ~cycle:0 ~queued:[] ~bursts:stimulus.bursts ~quiet:0 []
;;

module Verdict = struct
  type t =
    { limit : Limit.t
    ; needed : int
    ; bound : int option
    ; ok : bool
    }
end

let picoseconds ns = Float.iround_nearest_exn (ns *. 1000.)

(* the least or most cycles that clear the limit by the margin *)
let needed ~clock_hz (limit : Limit.t) (margin : Margin.t) =
  let per_ps = 1_000_000_000_000 in
  let cycle, margin_ps =
    match margin with
    | Cycle -> 1, 0
    | Ns { ns; why = _ } -> 0, picoseconds ns
  in
  match limit with
  | At_least ns ->
    ((((picoseconds ns + margin_ps) * clock_hz) + per_ps - 1) / per_ps) + cycle
  | At_most ns -> ((picoseconds ns - margin_ps) * clock_hz / per_ps) - cycle
;;

let kernel_accepts (bench : Bench.t) spec =
  let program = Asm.assemble bench.source |> ok_exn in
  let config = Asm.Program.configure program bench.config in
  let words = Asm.Program.words program |> ok_exn in
  let single_capture_edge =
    match bench.assumption with
    | Receiver _ -> true
    | Nothing | Floor _ | Period _ -> false
  in
  let period = Bench.period bench in
  let table =
    Analyser.analyse ?period ~single_capture_edge ~config program.instructions
    |> Kernel.Table.of_analyser
    |> Kernel.Table.with_edges
         ~single_capture_edge
         ~config
         ~spacing:(Kernel.Spacing.of_spec config spec)
         ~words
  in
  Kernel.check ?period ~single_capture_edge ~spacing:spec ~config ~words table
  |> Result.is_ok
;;

(* the most cycles the kernel accepts, by bisection: [ok] holds at [lo] and not at [hi] *)
let rec most ~ok ~lo ~hi =
  if hi - lo <= 1
  then lo
  else (
    let mid = (lo + hi) / 2 in
    if ok mid then most ~ok ~lo:mid ~hi else most ~ok ~lo ~hi:mid)
;;

let check ?limits (bench : Bench.t) =
  let limits =
    Option.value_or_thunk limits ~default:(fun () ->
      List.filter all ~f:(fun t -> String.equal t.firmware bench.name))
  in
  List.map limits ~f:(fun t ->
    let needed = needed ~clock_hz:bench.clock_hz t.limit t.margin in
    let bound =
      match t.bound, t.limit with
      | Kernel spec, At_least _ ->
        let ok n = kernel_accepts bench (spec bench.config n) in
        if not (ok 0) then None else Some (most ~ok ~lo:0 ~hi:(1 lsl 16))
      | Kernel _, At_most _ -> raise_s [%message "BUG: the kernel bounds least widths"]
      | Run { pin; widths }, limit ->
        let stimulus =
          match stimulus bench with
          | Some stimulus -> stimulus
          | None -> raise_s [%message "BUG: no stimulus to run" bench.name]
        in
        let widths =
          widths ~clock_hz:bench.clock_hz (levels bench ~pin:(pin bench.config) stimulus)
        in
        (match limit with
         | At_least _ -> List.min_elt widths ~compare
         | At_most _ -> List.max_elt widths ~compare)
    in
    let ok =
      match t.limit, bound with
      | _, None -> false
      | At_least _, Some bound -> bound >= needed
      | At_most _, Some bound -> bound <= needed
    in
    t, { Verdict.limit = t.limit; needed; bound; ok })
;;

let ns ~clock_hz cycles = Float.of_int cycles *. 1e9 /. Float.of_int clock_hz

let to_string (bench : Bench.t) verdicts =
  List.map verdicts ~f:(fun (t, (v : Verdict.t)) ->
    let side, limit =
      match v.limit with
      | At_least ns -> ">=", ns
      | At_most ns -> "<=", ns
    in
    let margin =
      match t.margin with
      | Cycle -> "a cycle"
      | Ns { ns; why } -> sprintf "%g ns, %s" ns why
    in
    let kind =
      match t.bound with
      | Kernel _ -> "kernel"
      | Run _ -> "run"
    in
    let bound =
      Option.value_map v.bound ~default:"none" ~f:(fun cycles ->
        sprintf "%d (%.1f ns)" cycles (ns ~clock_hz:bench.clock_hz cycles))
    in
    sprintf
      "%-18s %-14s %s %8g ns  %-6s %-17s needs %4d%-5s  %s, %s %s; margin %s"
      bench.name
      t.parameter
      side
      limit
      kind
      bound
      v.needed
      (if v.ok then "" else " FAIL")
      t.sheet.part
      t.sheet.document
      t.sheet.page
      margin)
  |> String.concat ~sep:"\n"
;;

let check_exn (bench : Bench.t) =
  match check bench with
  | [] when not (List.Assoc.mem exempt bench.name ~equal:String.equal) ->
    raise_s [%message "no datasheet limits, and no reason why" bench.name]
  | verdicts ->
    if not (List.for_all verdicts ~f:(fun (_, v) -> v.ok))
    then
      raise_s
        [%message
          "a datasheet limit is not cleared" ~_:(to_string bench verdicts : string)]
;;
