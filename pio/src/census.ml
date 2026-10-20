open! Core
open Protocol_emulator

let clock_hz = 48_000_000

(* the core's pins: IN0 0, IO0 12 *)
let in0 = 0
let io0 = Isa.first_bidir_pin

(* What each example's C code sets, from the % c-sdk block of its .pio file. *)
let configure (program : Pioasm.Program.t) (s : Translate.Setup.t) : Translate.Setup.t =
  let autopull ?(right = true) n =
    { s with autopull = true; pull_threshold = n; out_shift_right = right }
  in
  let spi s : Translate.Setup.t =
    { s with
      out_shift_right = false
    ; autopull = true
    ; pull_threshold = 8
    ; in_shift_right = false
    ; autopush = true
    ; push_threshold = 8
    ; in_base = in0
    }
  in
  let spi_cs s : Translate.Setup.t =
    { (spi s) with
      entry = Some "entry_point"
    ; init = [ "set x, 6"; "set y, 6" ]
    ; side_init = 2
    }
  in
  let i2c s : Translate.Setup.t =
    { s with
      side_set_base = io0 + 1
    ; set_base = io0
    ; set_count = 1
    ; out_base = io0
    ; out_count = 1
    ; in_base = io0
    ; in_count = 2
    ; jmp_pin = io0
    ; side_init = 1
    ; dirs_inverted = true
    }
  in
  match program.name with
  | "resistor_dac_5bit" -> autopull 5
  | "pio_serialiser" | "hub75_row" -> autopull 32
  | "apa102_mini" -> autopull ~right:false 32
  | "hub75_data_rgb888" ->
    { (autopull 24) with in_shift_right = false; entry = Some "entry_point" }
  | "clocked_input" ->
    { s with in_shift_right = false; autopush = true; push_threshold = 8 }
  | "differential_manchester_tx" | "manchester_tx" ->
    { (autopull 32) with entry = Some "start" }
  | "differential_manchester_rx" | "manchester_rx" ->
    { s with
      autopush = true
    ; push_threshold = 32
    ; jmp_pin = s.in_base
    ; init = [ "set x, 1"; "set y, 0" ]
    }
  | "nec_receive" -> { s with autopush = true; push_threshold = 32; jmp_pin = s.in_base }
  | "onewire" ->
    { s with
      in_base = s.side_set_base
    ; jmp_pin = s.side_set_base
    ; autopush = true
    ; push_threshold = 8
    ; autopull = true
    ; pull_threshold = 8
    ; entry = Some "fetch_bit"
    }
  | "spi_cpha0" | "spi_cpha1" -> spi s
  | "spi_cpha0_cs" | "spi_cpha1_cs" -> spi_cs s
  | "st7789_lcd" -> autopull ~right:false 8
  | "uart_rx_mini" -> { s with autopush = true; push_threshold = 8 }
  | "uart_rx" -> { s with jmp_pin = s.in_base }
  | "uart_tx" -> { s with out_base = s.side_set_base; side_init = 1 }
  | "ws2812" -> autopull ~right:false 24
  | "ws2812_parallel" -> autopull 32
  | "i2c" ->
    { (i2c s) with
      out_shift_right = false
    ; autopull = true
    ; pull_threshold = 16
    ; in_shift_right = false
    ; autopush = true
    ; push_threshold = 8
    ; entry =
        Some "entry_point"
        (* pio_i2c.c's START, RSTART and STOP: set_scl_sda's four and a clear of isr *)
    ; exec =
        (* SCL low, SDA high comes only with SCL low already, as RSTART starts *)
        List.map
          ~f:(fun (instruction, from_sides) ->
            { Translate.Setup.Exec.instruction; from_sides })
          [ "set pindirs, 0 side 0 [7]", []
          ; "set pindirs, 1 side 0 [7]", [ 0 ]
          ; "set pindirs, 0 side 1 [7]", []
          ; "set pindirs, 1 side 1 [7]", []
          ; "mov isr, null", []
          ]
    }
  | "set_scl_sda" -> i2c s
  | _ -> s
;;

let setup program ~period = configure program (Translate.Setup.default program ~period)

(* the state machine clock the example runs at, where it fixes one *)
let sm_hz (program : Pioasm.Program.t) =
  match program.name with
  | "uart_tx" | "uart_rx" | "uart_rx_mini" -> Some (8. *. 115_200.)
  | "ws2812" -> Some (10. *. 800_000.)
  | "i2c" | "set_scl_sda" -> Some (32. *. 100_000.)
  | "onewire" -> Some 1e6
  | _ -> None
;;

module Verdict = struct
  type t =
    | Certified of
        { k : int
        ; words : int
        }
    | Not_certified of { reason : string }
    | Refused of Translate.Refusal.t list
  [@@deriving sexp_of]
end

(* [k] as [per_cycle] waits of [p], [p] at most 31, in 65536ths *)
let scale k =
  let rec go per_cycle =
    if Float.( <= ) (k /. Float.of_int per_cycle) 31.
    then per_cycle
    else go (2 * per_cycle)
  in
  let per_cycle = go 1 in
  let p = k /. Float.of_int per_cycle in
  let period = Float.iround_down_exn p in
  let fraction = Float.iround_nearest_exn ((p -. Float.of_int period) *. 65536.) in
  if fraction = 65536 then per_cycle, period + 1, 0 else per_cycle, period, fraction
;;

let certify ?(place = Fn.id) program ~k =
  let per_cycle, period, fraction = scale k in
  let setup = place { (setup program ~period) with fraction; per_cycle } in
  match Translate.translate setup program with
  | Error refusals -> Error (Verdict.Refused refusals)
  | Ok t ->
    (match Translate.check_relation setup program t with
     | Error error ->
       Error (Not_certified { reason = "relation: " ^ Error.to_string_hum error })
     | Ok () ->
       (match Timed_program.check ~config:t.config t.source with
        | Ok timed -> Ok (t, timed)
        | Error { faults; _ } ->
          Error
            (Not_certified
               { reason =
                   List.hd faults
                   |> Option.value_map ~default:"refused" ~f:(fun f ->
                     f.Timed_program.Fault.reason)
               })))
;;

let least ?(upto = 64) program =
  let rec go k =
    match certify program ~k:(Float.of_int k) with
    | Ok (t, _) -> Verdict.Certified { k; words = List.length t.words }
    | Error (Refused _ as refused) -> refused
    | Error (Not_certified { reason }) ->
      if String.is_prefix reason ~prefix:"relation"
      then Not_certified { reason }
      else if k >= upto
      then Not_certified { reason = sprintf "up to k = %d: %s" upto reason }
      else go (k + 1)
    | Error (Certified _) -> assert false
  in
  go 2
;;

let real_time program =
  Option.map (sm_hz program) ~f:(fun hz -> Float.of_int clock_hz /. hz)
;;

let least_apart timed ~dirs ~a ~b ~apart =
  let config = Timed_program.config timed
  and words = Timed_program.words timed in
  let none ~own:_ ~other:_ = 0 in
  let accepts n =
    let spec =
      { Kernel.Spacing.Spec.a
      ; b
      ; dirs
      ; hold_a = none
      ; apart_a = (fun ~own ~other -> if apart ~own ~other then n else 0)
      ; hold_b = none
      ; apart_b = none
      }
    in
    let table =
      Kernel.Table.of_analyser (Timed_program.rows timed)
      |> Kernel.Table.with_edges
           ~config
           ~spacing:(Kernel.Spacing.of_spec config spec)
           ~words
    in
    Kernel.check ~spacing:spec ~config ~words table |> Result.is_ok
  in
  (* [accepts] holds at [lo] and not at [hi] *)
  let rec most ~lo ~hi =
    if hi - lo <= 1
    then lo
    else (
      let mid = (lo + hi) / 2 in
      if accepts mid then most ~lo:mid ~hi else most ~lo ~hi:mid)
  in
  if not (accepts 0) then None else Some (most ~lo:0 ~hi:(1 lsl 16))
;;

module Limit = struct
  type t =
    { parameter : string
    ; at_least_ns : int
    ; sheet : string
    ; edge : string
    ; bound : int option
    }

  let ok t =
    Option.exists t.bound ~f:(fun n -> n * 1_000_000_000 >= t.at_least_ns * clock_hz)
  ;;

  let to_string t =
    let proved =
      match t.bound with
      | None -> "the kernel proves no bound"
      | Some n ->
        sprintf
          "the kernel proves %d cycles, %.3f us at %d MHz"
          n
          (Float.of_int n *. 1e6 /. Float.of_int clock_hz)
          (clock_hz / 1_000_000)
    in
    sprintf
      "%s, %s: %s, %s %.1f us (%s)"
      t.parameter
      t.edge
      proved
      (if ok t then "clearing" else "under")
      (Float.of_int t.at_least_ns /. 1000.)
      t.sheet
  ;;
end

let limits (program : Pioasm.Program.t) timed =
  let config = Timed_program.config timed in
  match program.name with
  | "i2c" ->
    (* pindirs, which pio_i2c.c inverts: SCL falling while SDA is held low, since SDA's
       last edge *)
    [ { Limit.parameter = "tHD;STA"
      ; at_least_ns = 4_000
      ; sheet = "UM10204 Rev. 7.0, table 11, p.44, Standard-mode"
      ; edge = "SDA low to SCL low"
      ; bound =
          least_apart
            timed
            ~dirs:true
            ~a:config.side_set_base
            ~b:config.set_base
            ~apart:(fun ~own ~other -> (not own) && other)
      }
    ]
  | _ -> []
;;

module Row = struct
  type t =
    { file : string
    ; program : string
    ; verdict : Verdict.t
    ; real_time : (float * bool) option
    ; refused_limits : string list
    ; contract : string list
    }
end

let row ~file (program : Pioasm.Program.t) =
  let verdict = least program in
  let at_real_time =
    Option.map (real_time program) ~f:(fun k ->
      match certify program ~k with
      | Error _ -> k, false, []
      | Ok (_, timed) ->
        let refused =
          List.filter_map (limits program timed) ~f:(fun limit ->
            Option.some_if (not (Limit.ok limit)) limit.parameter)
        in
        k, List.is_empty refused, refused)
  in
  let contract =
    match Translate.translate (setup program ~period:8) program with
    | Ok t -> t.contract
    | Error _ -> []
  in
  { Row.file
  ; program = program.name
  ; verdict
  ; real_time = Option.map at_real_time ~f:(fun (k, ok, _) -> k, ok)
  ; refused_limits = Option.value_map at_real_time ~default:[] ~f:(fun (_, _, r) -> r)
  ; contract
  }
;;

let to_string rows =
  let line (row : Row.t) =
    let verdict, k, words =
      match row.verdict with
      | Certified { k; words } -> "certified", Int.to_string k, Int.to_string words
      | Not_certified { reason } -> "not certified: " ^ reason, "", ""
      | Refused refusals ->
        ( "refused: "
          ^ (List.map refusals ~f:(fun r -> r.feature)
             |> List.dedup_and_sort ~compare:String.compare
             |> String.concat ~sep:", ")
        , ""
        , "" )
    in
    let real =
      match row.real_time with
      | None -> ""
      | Some (k, true) -> sprintf "%.3f yes" k
      | Some (k, false) ->
        sprintf
          "%.3f no%s"
          k
          (List.map row.refused_limits ~f:(fun p -> ", " ^ p) |> String.concat)
    in
    sprintf "| %s | %s | %s | %s | %s | %s |" row.file row.program verdict k words real
  in
  let count f = List.count rows ~f:(fun (row : Row.t) -> f row.verdict) in
  let certified =
    count (function
      | Verdict.Certified _ -> true
      | _ -> false)
  and refused =
    count (function
      | Verdict.Refused _ -> true
      | _ -> false)
  in
  String.concat_lines
    ([ "| file | program | verdict | least k | words | k at 48 MHz, certified |"
     ; "|---|---|---|---|---|---|"
     ]
     @ List.map rows ~f:line
     @ [ ""
       ; sprintf
           "%d programs: %d certified, %d refused, %d not certified"
           (List.length rows)
           certified
           refused
           (List.length rows - certified - refused)
       ])
;;
