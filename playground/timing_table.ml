open! Core
open Protocol_emulator

module Report = struct
  type t =
    { verdict : string
    ; detail : string
    ; limits : string
    ; source : string
    ; check : Checks.Report.t
    ; host : string
    ; firmware : (Program_config.t * int) option
    }
end

module Row = struct
  type t =
    { name : string
    ; min_ns : float option
    ; max_ns : float option
    }
end

module Scale = struct
  type t =
    | Time of float (* to ns *)
    | Rate of float (* to Hz *)
end

let scales =
  [ "s", Scale.Time 1e9
  ; "ms", Time 1e6
  ; "us", Time 1e3
  ; "µs", Time 1e3
  ; "ns", Time 1.
  ; "hz", Rate 1.
  ; "khz", Rate 1e3
  ; "mhz", Rate 1e6
  ; "baud", Rate 1.
  ; "bd", Rate 1.
  ; "kbaud", Rate 1e3
  ; "kbd", Rate 1e3
  ; "mbaud", Rate 1e6
  ; "bit/s", Rate 1.
  ; "bps", Rate 1.
  ; "kbit/s", Rate 1e3
  ; "kbps", Rate 1e3
  ; "mbit/s", Rate 1e6
  ; "mbps", Rate 1e6
  ]
;;

(* a blank or a 0 bounds nothing *)
let value = function
  | "-" -> Some None
  | s ->
    (match Float.of_string_opt s with
     | Some v when Float.( > ) v 0. -> Some (Some v)
     | Some v when Float.( = ) v 0. -> Some None
     | Some _ | None -> None)
;;

(* NAME MIN MAX UNIT, where a rate's least is the longest period *)
let row = function
  | [ name; low; high; unit ] ->
    (match
       ( value low
       , value high
       , List.Assoc.find scales (String.lowercase unit) ~equal:String.equal )
     with
     | Some low, Some high, Some (Time s) ->
       Some
         { Row.name
         ; min_ns = Option.map low ~f:(fun v -> v *. s)
         ; max_ns = Option.map high ~f:(fun v -> v *. s)
         }
     | Some low, Some high, Some (Rate s) ->
       let period v = 1e9 /. (v *. s) in
       Some
         { Row.name
         ; min_ns = Option.map high ~f:period
         ; max_ns = Option.map low ~f:period
         }
     | _ -> None)
  | _ -> None
;;

module Coding = struct
  type t =
    | Pulse of
        { zero : string * string
        ; one : string * string
        }
    | Uart of
        { bit : string
        ; data_bits : int
        ; parity : Learn.Parity.t option
        ; stop_bits : int
        }
    | Manchester of
        { half : string
        ; halves : int
        ; one_starts_high : bool
        }
    | Clocked of
        { phases : (string * int) list
        ; sample_rising : bool
        ; clock_idle : bool
        }
end

module Shape = struct
  type t =
    { coding : Coding.t
    ; bits : int
    ; idle : bool
    ; leader : string list
    ; trailer : string list
    ; gap : string option
    }
end

module Role = struct
  type t =
    | Leader of int
    | Zero_mark
    | Zero_space
    | One_mark
    | One_space
    | Trailer of int
    | Bit
    | Half
    | Phase of int
    | Gap
  [@@deriving equal]
end

module Span = struct
  type t =
    { role : Role.t
    ; row : Row.t
    ; fixed : int option (* units, or the search picks them *)
    ; inside : bool (* in a frame's bits, where a run is at most 33 periods *)
    }
end

let level = function
  | "high" -> Ok true
  | "low" -> Ok false
  | s -> Or_error.error_s [%message "a level is high or low" s]
;;

(* the lines each shape takes, besides its rows *)
let lines_of shape =
  let common = [ "shape"; "bits"; "idle"; "gap" ] in
  match shape with
  | "pulse" -> Ok (common @ [ "zero"; "one"; "leader"; "trailer" ])
  | "uart" -> Ok [ "shape"; "idle"; "gap"; "bit"; "data"; "parity"; "stop"; "chars" ]
  | "manchester" -> Ok (common @ [ "half"; "bit"; "one-starts" ])
  | "clocked" -> Ok (common @ [ "high"; "low"; "clock"; "sample"; "clock-idle" ])
  | shape ->
    Or_error.error_s
      [%message "a shape is pulse, uart, manchester or clocked" (shape : string)]
;;

let parse text =
  let open Or_error.Let_syntax in
  let rows, settings =
    String.split_lines text
    |> List.map ~f:(fun line ->
      String.lsplit2 line ~on:'#' |> Option.value_map ~default:line ~f:fst)
    |> List.map ~f:(fun line ->
      String.split_on_chars line ~on:[ ' '; '\t' ]
      |> List.filter ~f:(Fn.non String.is_empty))
    |> List.filter ~f:(Fn.non List.is_empty)
    |> List.partition_map ~f:(fun tokens ->
      match row tokens with
      | Some row -> First row
      | None -> Second (String.lowercase (List.hd_exn tokens), List.tl_exn tokens))
  in
  let%bind () =
    match
      List.find_a_dup rows ~compare:(fun (a : Row.t) b -> String.compare a.name b.name)
    with
    | Some row -> Or_error.error_s [%message "two rows named" row.name]
    | None -> Ok ()
  in
  let%bind () =
    match List.find_a_dup (List.map settings ~f:fst) ~compare:String.compare with
    | Some key -> Or_error.error_s [%message "two lines start" key]
    | None -> Ok ()
  in
  let find key = List.Assoc.find settings key ~equal:String.equal in
  let one key =
    match find key with
    | None -> Ok None
    | Some [ word ] -> Ok (Some word)
    | Some _ -> Or_error.error_s [%message "takes one word" key]
  in
  let%bind shape =
    match%bind one "shape" with
    | Some shape -> Ok (String.lowercase shape)
    | None -> Or_error.error_s [%message "no shape line"]
  in
  let%bind allowed = lines_of shape in
  let%bind () =
    match
      List.find settings ~f:(fun (key, _) ->
        not (List.mem allowed key ~equal:String.equal))
    with
    | Some (key, args) ->
      Or_error.error_s
        [%message
          "neither a row of four nor a line this shape takes"
            ~line:(String.concat ~sep:" " (key :: args))
            shape]
    | None -> Ok ()
  in
  let count key ~default =
    match%bind one key with
    | None ->
      (match default with
       | Some n -> Ok n
       | None -> Or_error.error_s [%message "needs a line" key])
    | Some n ->
      (match Int.of_string_opt n with
       | Some n when n > 0 && n <= 4096 -> Ok n
       | Some _ | None -> Or_error.error_s [%message "a count from 1 to 4096" key n])
  in
  let level_of key ~default =
    match%bind one key with
    | None -> Ok default
    | Some s -> level s
  in
  let name key =
    match%bind one key with
    | Some name -> Ok name
    | None -> Or_error.error_s [%message "needs a row" key]
  in
  let pair key =
    match find key with
    | Some [ mark; space ] -> Ok (mark, space)
    | _ -> Or_error.error_s [%message "names two rows, the mark then the space" key]
  in
  let rows_of key = Option.value (find key) ~default:[] in
  let%bind idle = level_of "idle" ~default:(String.equal shape "uart") in
  let%bind gap = one "gap" in
  let%map coding, bits =
    match shape with
    | "pulse" ->
      let%bind zero = pair "zero" in
      let%bind one = pair "one" in
      let%map bits = count "bits" ~default:None in
      Coding.Pulse { zero; one }, bits
    | "uart" ->
      let%bind bit = name "bit" in
      let%bind data_bits = count "data" ~default:(Some 8) in
      let%bind stop_bits = count "stop" ~default:(Some 1) in
      let%bind chars = count "chars" ~default:(Some 1) in
      let%map parity =
        match%bind one "parity" with
        | None | Some "none" -> Ok None
        | Some "even" -> Ok (Some Learn.Parity.Even)
        | Some "odd" -> Ok (Some Learn.Parity.Odd)
        | Some p -> Or_error.error_s [%message "parity is none, even or odd" p]
      in
      Coding.Uart { bit; data_bits; parity; stop_bits }, chars * data_bits
    | "manchester" ->
      let%bind half, halves =
        match%bind Or_error.both (one "half") (one "bit") with
        | Some half, None -> Ok (half, 1)
        | None, Some bit -> Ok (bit, 2)
        | _ -> Or_error.error_s [%message "a half line or a bit line, one of them"]
      in
      let%bind one_starts_high = level_of "one-starts" ~default:false in
      let%map bits = count "bits" ~default:None in
      Coding.Manchester { half; halves; one_starts_high }, bits
    | _ ->
      let%bind phases =
        List.filter_map
          [ "high", 1; "low", 1; "clock", 2 ]
          ~f:(fun (key, units) ->
            Option.map (find key) ~f:(fun _ ->
              Or_error.map (name key) ~f:(fun n -> n, units)))
        |> Or_error.all
      in
      let%bind () =
        if List.is_empty phases
        then Or_error.error_s [%message "a high, low or clock line"]
        else Ok ()
      in
      let%bind sample_rising =
        match%bind one "sample" with
        | None | Some "rising" -> Ok true
        | Some "falling" -> Ok false
        | Some s -> Or_error.error_s [%message "sample is rising or falling" s]
      in
      let%bind clock_idle = level_of "clock-idle" ~default:false in
      let%map bits = count "bits" ~default:None in
      Coding.Clocked { phases; sample_rising; clock_idle }, bits
  in
  ( { Shape.coding
    ; bits
    ; idle
    ; leader = rows_of "leader"
    ; trailer = rows_of "trailer"
    ; gap
    }
  , rows )
;;

let spans (shape : Shape.t) rows =
  let span ?fixed ~inside role name =
    match List.find rows ~f:(fun (r : Row.t) -> String.equal r.name name) with
    | Some row -> Ok { Span.role; row; fixed; inside }
    | None -> Or_error.error_s [%message "no row named" name]
  in
  let coding =
    match shape.coding with
    | Pulse { zero = zero_mark, zero_space; one = one_mark, one_space } ->
      [ span ~inside:true Zero_mark zero_mark
      ; span ~inside:true Zero_space zero_space
      ; span ~inside:true One_mark one_mark
      ; span ~inside:true One_space one_space
      ]
    | Uart { bit; _ } -> [ span ~fixed:1 ~inside:true Bit bit ]
    | Manchester { half; halves; _ } -> [ span ~fixed:halves ~inside:true Half half ]
    | Clocked { phases; _ } ->
      List.mapi phases ~f:(fun i (name, units) ->
        span ~fixed:units ~inside:true (Phase i) name)
  in
  List.mapi shape.leader ~f:(fun i name -> span ~inside:false (Leader i) name)
  @ coding
  @ List.mapi shape.trailer ~f:(fun i name -> span ~inside:false (Trailer i) name)
  @ Option.value_map shape.gap ~default:[] ~f:(fun name ->
    [ span ~inside:false Gap name ])
  |> Or_error.all
;;

(* in cycles, clearing each limit by one *)
let window ~clock_hz (row : Row.t) =
  let cycles ns = Float.min (ns *. Float.of_int clock_hz /. 1e9) 1e9 in
  ( Option.value_map row.min_ns ~default:1 ~f:(fun ns ->
      Float.iround_up_exn (cycles ns) + 1)
  , Option.map row.max_ns ~f:(fun ns -> Float.iround_down_exn (cycles ns) - 1) )
;;

let ticks u = (u + 65534) / 65535

(* the firmware idles at least four units between frames *)
let units (span : Span.t) k = if Role.equal span.role Gap then Int.max k 4 else k
let most (span : Span.t) ~u = (if span.inside then 33 else 1025) / ticks u

(* the units nearest the middle of the window, or the fewest for a least alone *)
let pick ~u (span : Span.t) (lo, hi) =
  match span.fixed with
  | Some k -> k
  | None ->
    let least = Int.max 1 ((lo + u - 1) / u) in
    (match hi with
     | Some hi when hi / u > least ->
       Int.clamp_exn
         (Float.iround_nearest_exn (Float.of_int (lo + hi) /. 2. /. Float.of_int u))
         ~min:least
         ~max:(hi / u)
     | Some _ | None -> least)
;;

module Miss = struct
  type t =
    | Under of int
    | Over of int
    | Too_long
end

let miss ~u (span : Span.t) (lo, hi) k : Miss.t option =
  let value = units span k * u in
  if k > most span ~u
  then Some Too_long
  else if value < lo
  then Some (Under (lo - value))
  else (
    match hi with
    | Some hi when value > hi -> Some (Over (value - hi))
    | Some _ | None -> None)
;;

let k_of spans ks role =
  List.find_map_exn (List.zip_exn spans ks) ~f:(fun ((s : Span.t), k) ->
    Option.some_if (Role.equal s.role role) k)
;;

(* a pulse code's zero and one must differ *)
let distinct (shape : Shape.t) spans ks =
  match shape.coding with
  | Pulse _ ->
    let k = k_of spans ks in
    not ([%equal: int * int] (k Zero_mark, k Zero_space) (k One_mark, k One_space))
  | Uart _ | Manchester _ | Clocked _ -> true
;;

let with_windows spans windows ks = List.zip_exn (List.zip_exn spans windows) ks

(* the least room any two-sided limit has, in cycles *)
let room ~u spans windows ks =
  List.filter_map
    (with_windows spans windows ks)
    ~f:(fun (((span : Span.t), (lo, hi)), k) ->
      match span.row.min_ns, hi with
      | Some _, Some hi ->
        let value = units span k * u in
        Some (Int.min (value - lo) (hi - value))
      | _ -> None)
  |> List.min_elt ~compare
;;

(* past it a max is missed, or with no max, past every least and what the kernel needs *)
let largest_unit spans windows =
  let per_unit f =
    List.filter_map (List.zip_exn spans windows) ~f:(fun ((span : Span.t), window) ->
      Option.map (f window) ~f:(fun cycles -> cycles / Option.value span.fixed ~default:1))
  in
  let top =
    match List.min_elt (per_unit snd) ~compare with
    | Some u -> u
    | None ->
      (List.max_elt (per_unit (fun (lo, _) -> Some lo)) ~compare
       |> Option.value ~default:1)
      + 64
  in
  Int.min top (1 lsl 20)
;;

let learned (shape : Shape.t) spans ks ~u ~clock_hz =
  let k = k_of spans ks in
  let alternate rows ~role =
    List.mapi rows ~f:(fun i _ -> { Learn.Run.active = i % 2 = 0; units = k (role i) })
  in
  let coding : Learn.Coding.t =
    match shape.coding with
    | Pulse _ ->
      Pulse
        { zero = k Zero_mark, k Zero_space
        ; one = k One_mark, k One_space
        ; last_is_bit = List.is_empty shape.trailer
        }
    | Uart { data_bits; parity; stop_bits; _ } -> Uart { data_bits; parity; stop_bits }
    | Manchester { one_starts_high; _ } ->
      Manchester
        { one_starts_active = Bool.equal one_starts_high (not shape.idle)
        ; wide = None
        ; hidden_half = false
        }
    | Clocked { sample_rising; clock_idle; _ } ->
      Clocked { clock = "clock"; select = None; sample_rising; clock_idle }
  in
  { Learn.line = "data"
  ; unit_s = Float.of_int u /. Float.of_int clock_hz
  ; bias_s = 0.
  ; idle = shape.idle
  ; coding
  ; lsb_first = true
  ; kinds =
      [ { leader = alternate shape.leader ~role:(fun i -> Leader i)
        ; bits = shape.bits
        ; trailer = alternate shape.trailer ~role:(fun i -> Trailer i)
        }
      ]
  ; gap = Option.value_map shape.gap ~default:0 ~f:(fun _ -> k Gap)
  ; frames = []
  ; outliers = 0
  ; rules = []
  ; fields = []
  }
;;

let pins (shape : Shape.t) : Learn_firmware.Pins.t =
  match shape.coding with
  | Clocked _ ->
    Clocked
      { clock = Isa.first_output_pin; data = Isa.first_output_pin + 1; deselect = false }
  | Pulse _ | Uart _ | Manchester _ -> Line Isa.first_output_pin
;;

let generate (shape : Shape.t) spans ks ~u ~clock_hz =
  let open Or_error.Let_syntax in
  let learned = learned shape spans ks ~u ~clock_hz in
  let%bind firmware =
    Learn_firmware.generate ~clock_hz:(Float.of_int clock_hz) ~pins:(pins shape) learned
  in
  if firmware.period * firmware.ticks = u
  then Ok (learned, firmware)
  else Or_error.error_s [%message "no period makes the unit" (u : int)]
;;

let time ns =
  if Float.( >= ) ns 1e6
  then sprintf "%.3f ms" (ns /. 1e6)
  else if Float.( >= ) ns 1e4
  then sprintf "%.3f us" (ns /. 1e3)
  else sprintf "%.1f ns" ns
;;

let limits_text (row : Row.t) =
  match row.min_ns, row.max_ns with
  | Some low, Some high -> time low ^ " to " ^ time high
  | Some low, None -> "at least " ^ time low
  | None, Some high -> "at most " ^ time high
  | None, None -> "no limit"
;;

let cycles_text = function
  | 1 -> "1 cycle"
  | n -> sprintf "%d cycles" n
;;

let ns ~clock_hz cycles = Float.of_int cycles *. 1e9 /. Float.of_int clock_hz

let miss_text ~clock_hz ~u (span : Span.t) hi k (miss : Miss.t) =
  let value = units span k * u in
  let is =
    sprintf "%s is %d cycles, %s" span.row.name value (time (ns ~clock_hz value))
  in
  match miss with
  | Under by ->
    sprintf
      "%s; its min of %s needs %d, %s short"
      is
      (time (Option.value_exn span.row.min_ns))
      (value + by)
      (time (ns ~clock_hz by))
  | Over by ->
    sprintf
      "%s; its max of %s allows %d, %s over"
      is
      (time (Option.value_exn span.row.max_ns))
      (Option.value_exn hi)
      (time (ns ~clock_hz by))
  | Too_long -> sprintf "%s, %d units: longer than one run of the firmware can be" is k
;;

(* a row two runs share, as a pulse code's marks can, is said once *)
let once lines =
  List.fold lines ~init:[] ~f:(fun seen line ->
    if List.mem seen line ~equal:String.equal then seen else line :: seen)
  |> List.rev
;;

let misses ~clock_hz ~u spans windows ks =
  List.filter_map (with_windows spans windows ks) ~f:(fun ((span, window), k) ->
    Option.map (miss ~u span window k) ~f:(miss_text ~clock_hz ~u span (snd window) k))
  |> once
;;

let no_check = { Checks.Report.verdict = ""; detail = ""; listing = ""; rows = "" }

let refused ?(detail = "") reason =
  { Report.verdict = "refused: " ^ reason
  ; detail
  ; limits = ""
  ; source = ""
  ; check = no_check
  ; host = ""
  ; firmware = None
  }
;;

(* the model's two frames *)
let frame_bits bits i = Array.init bits ~f:(fun j -> j % (i + 2) = 0)

let bits_text bits =
  Array.to_list bits |> List.map ~f:(fun b -> if b then '1' else '0') |> String.of_list
;;

(* the cycles from each edge of [line] to the next *)
let widths (recording : Recording.t) ~line =
  match Recording.find recording line with
  | None -> []
  | Some line ->
    List.init
      (Int.max 0 (Array.length line.edges - 1))
      ~f:(fun i -> line.edges.(i + 1) - line.edges.(i))
;;

(* Two frames on the engine's model, read back and timed run by run. One run a frame, as
   frames a short gap apart read as one. *)
let model ~clock_hz ~model_cycles (shape : Shape.t) learned (firmware : Learn_firmware.t) =
  let u = firmware.period * firmware.ticks in
  let cycles bits =
    let units =
      match shape.coding with
      | Clocked _ -> (2 * Array.length bits) + 8
      | Pulse _ | Uart _ | Manchester _ ->
        List.sum (module Int) (Learn.runs learned ~kind:0 bits) ~f:(fun r -> r.units)
    in
    (units + Int.max learned.gap 4 + 4) * u
  in
  let read_back bits =
    let%bind.Or_error recording =
      Learn_firmware.simulate
        ~clock_hz:(Float.of_int clock_hz)
        ~pins:(pins shape)
        firmware
        learned
        [ 0, bits ]
    in
    let seen, want =
      match shape.coding with
      | Clocked _ ->
        let seen = widths recording ~line:"clock" in
        seen, List.map seen ~f:(fun _ -> u)
      | Pulse _ | Uart _ | Manchester _ ->
        ( widths recording ~line:"data"
        , List.map (Learn.runs learned ~kind:0 bits) ~f:(fun r -> r.units * u) )
    in
    let show l = List.map l ~f:Int.to_string |> String.concat ~sep:" " in
    match%map.Or_error Learn.decode learned recording with
    | [ frame ] when [%equal: bool array] frame.bits bits ->
      if [%equal: int list] seen want
      then None
      else Some (sprintf "model: runs of %s cycles, not %s" (show seen) (show want))
    | frames ->
      Some
        (sprintf
           "model: sent %s, read back %s"
           (bits_text bits)
           (List.map frames ~f:(fun f -> bits_text f.bits) |> String.concat ~sep:" "))
  in
  (* a Manchester frame read from idle has to start with its first half active *)
  let first =
    match learned.Learn.coding with
    | Manchester { one_starts_active; _ } -> one_starts_active
    | Pulse _ | Uart _ | Clocked _ -> true
  in
  let frames =
    List.init 2 ~f:(fun i -> Array.map (frame_bits shape.bits i) ~f:(Bool.equal first))
  in
  match List.sum (module Int) frames ~f:cycles with
  | total when total > model_cycles ->
    Ok
      (sprintf "model: not run, two frames take %d cycles, more than the page runs" total)
  | _ ->
    (match List.map frames ~f:read_back |> Or_error.all with
     | Error e -> Error ("model: " ^ Error.to_string_hum e)
     | Ok wrong ->
       (match List.filter_opt wrong with
        | [] ->
          Ok
            "model: two frames run on the engine's model, read back as sent, each run as \
             the limits say"
        | wrong -> Error (String.concat ~sep:"\n" wrong)))
;;

let certify
  ~clock_hz
  ~model_cycles
  (shape : Shape.t)
  spans
  rows
  ~u
  ks
  (learned, (firmware : Learn_firmware.t))
  =
  let used = List.map spans ~f:(fun (s : Span.t) -> s.row.name) in
  let limits =
    (* the search only takes units every row fits *)
    (List.map (List.zip_exn spans ks) ~f:(fun ((span : Span.t), k) ->
       let n = units span k in
       sprintf
         "%-10s %-24s %s%d x %d cycles = %s  ok"
         span.row.name
         (limits_text span.row)
         (if Role.equal span.role Gap then "at least " else "")
         n
         u
         (time (ns ~clock_hz (n * u))))
     |> once)
    @ List.filter_map rows ~f:(fun (row : Row.t) ->
      Option.some_if
        (not (List.mem used row.name ~equal:String.equal))
        (sprintf
           "%-10s %-24s not checked: no run of the shape"
           row.name
           (limits_text row)))
  in
  (* the generator's first line says it learned from a recording *)
  let source =
    match String.lsplit2 firmware.source ~on:'\n' with
    | Some (first, rest) when String.is_prefix first ~prefix:";" ->
      sprintf "; from a timing table, a unit of %d cycles\n%s" u rest
    | Some _ | None -> firmware.source
  in
  (* the kernel checked these words when the firmware was written *)
  let chip = Chip_verdict.of_timed firmware.timed in
  let check = Checks.accepted firmware.timed chip in
  let certificate =
    match chip with
    | Accepted { certificate } | Refused { certificate; _ } ->
      [ sprintf
          "certificate, %d words: %s"
          (List.length certificate)
          (List.map certificate ~f:(sprintf "%04x") |> String.concat ~sep:" ")
      ]
    | No_certificate _ -> []
  in
  let words = Learn_firmware.words firmware learned ~kind:0 (frame_bits shape.bits 0) in
  let model = model ~clock_hz ~model_cycles shape learned firmware in
  { Report.verdict =
      (match chip, model with
       | Accepted _, Ok _ -> "certified"
       | Accepted _, Error _ -> "accepted, but the model reads it back otherwise"
       | (Refused _ | No_certificate _), _ -> "refused by the chip")
  ; detail =
      String.concat
        ~sep:"\n"
        ([ sprintf
             "unit: %d cycles, %s at %s, the period %d times %d"
             u
             (time (ns ~clock_hz u))
             (Wavedrom.clock_name clock_hz)
             firmware.period
             firmware.ticks
         ; check.detail
         ; (match model with
            | Ok text | Error text -> text)
         ]
         @ certificate)
  ; limits = String.concat ~sep:"\n" limits
  ; source
  ; check
  ; host =
      sprintf
        "%d, the period, first\n%s, a frame of %d bits"
        firmware.period
        (List.map words ~f:(sprintf "0x%04x") |> String.concat ~sep:" ")
        shape.bits
  ; firmware = Some (Timed_program.config firmware.timed, firmware.period)
  }
;;

(* the unit that misses the fewest rows, by the fewest cycles *)
let nearest spans windows ~top =
  List.range 1 (Int.max 1 top + 1)
  |> List.map ~f:(fun u ->
    let ks = List.map2_exn spans windows ~f:(pick ~u) in
    let missed =
      List.filter_map (with_windows spans windows ks) ~f:(fun ((s, w), k) ->
        miss ~u s w k)
    in
    let cycles =
      List.sum (module Int) missed ~f:(function
        | Under n | Over n -> n
        | Too_long -> 1 lsl 20)
    in
    (List.length missed, cycles, u), ks)
  |> List.min_elt ~compare:(fun (a, _) (b, _) -> [%compare: int * int * int] a b)
  |> Option.value_exn
;;

(* the generator's refusal carries its source, which the page shows apart *)
let kernel_text e =
  match Error.sexp_of_t e with
  | List [ Atom _; Atom refusal; Atom _ ] -> refusal
  | List [ Atom _; refusal; Atom _ ] -> Sexp.to_string_hum refusal
  | sexp -> Sexp.to_string_hum sexp
;;

(* the least unit the kernel takes for these runs *)
let kernel_least (shape : Shape.t) spans ks ~from ~clock_hz =
  List.range from (Int.min (1 lsl 20) ((from * 8) + 64))
  |> List.find ~f:(fun v ->
    v % ticks v = 0 && Result.is_ok (generate shape spans ks ~u:v ~clock_hz))
;;

let missed spans windows ks ~u =
  List.filter_map (with_windows spans windows ks) ~f:(fun (((s : Span.t), w), k) ->
    Option.map (miss ~u s w k) ~f:(fun _ -> s.row.name))
  |> once
;;

let missed_rows spans windows ks ~u =
  match missed spans windows ks ~u with
  | [] -> "every row"
  | names -> String.concat ~sep:" and " names
;;

let search ~clock_hz ~model_cycles (shape : Shape.t) spans windows rows =
  let at = Wavedrom.clock_name clock_hz in
  let top = largest_unit spans windows in
  let fits u =
    let ks = List.map2_exn spans windows ~f:(pick ~u) in
    Option.some_if
      (u % ticks u = 0
       && distinct shape spans ks
       && List.for_all (with_windows spans windows ks) ~f:(fun ((s, w), k) ->
         Option.is_none (miss ~u s w k)))
      ks
  in
  let candidates =
    List.filter_map
      (List.range 1 (top + 1))
      ~f:(fun u -> Option.map (fits u) ~f:(fun ks -> room ~u spans windows ks, u, ks))
    (* most room first, then the longest unit, or the shortest if no row has two sides *)
    |> List.stable_sort ~compare:(fun (r1, u1, _) (r2, u2, _) ->
      match r1, r2 with
      | None, None -> Int.compare u1 u2
      | _ -> [%compare: int option * int] (r2, u2) (r1, u1))
  in
  let tried =
    List.fold_until
      (List.take candidates 64)
      ~init:None
      ~f:(fun first (_, u, ks) ->
        match generate shape spans ks ~u ~clock_hz with
        | Ok made -> Stop (Ok (u, ks, made))
        (* the kernel's refusal at the longest unit tried says the most *)
        | Error e ->
          Continue
            (match first with
             | Some (longest, _, _) when longest > u -> first
             | Some _ | None -> Some (u, ks, e)))
      ~finish:(fun first -> Error first)
  in
  let needs v =
    sprintf
      "the kernel takes this firmware at %d cycles a unit, %s, or more"
      v
      (time (ns ~clock_hz v))
  in
  match tried with
  | Ok (u, ks, made) -> certify ~clock_hz ~model_cycles shape spans rows ~u ks made
  | Error None ->
    let (_, _, u), ks = nearest spans windows ~top in
    let cycles ns = ns *. Float.of_int clock_hz /. 1e9 in
    let narrow =
      List.filter_map (List.zip_exn spans windows) ~f:(fun ((span : Span.t), (lo, hi)) ->
        match span.row.min_ns, span.row.max_ns, hi with
        | Some low, Some high, Some hi when hi < lo ->
          Some
            (sprintf
               "%s, %s, is %.2f to %.2f cycles at %s: no whole number clears both ends \
                by a cycle"
               span.row.name
               (limits_text span.row)
               (cycles low)
               (cycles high)
               at)
        | _ -> None)
    in
    let kernel =
      match kernel_least shape spans ks ~from:1 ~clock_hz with
      | None -> []
      | Some v ->
        (* a longer unit mends a min, so only a max missed there is the kernel's doing *)
        let over =
          List.filter (with_windows spans windows ks) ~f:(fun ((span, window), k) ->
            match miss ~u:v span window k with
            | Some (Over _) -> true
            | Some (Under _ | Too_long) | None -> false)
          |> List.map ~f:fst
        in
        if List.is_empty over
        then []
        else
          needs v
          :: misses
               ~clock_hz
               ~u:v
               (List.map over ~f:fst)
               (List.map over ~f:snd)
               (List.map over ~f:(fun ((span : Span.t), _) -> k_of spans ks span.role))
    in
    refused
      (sprintf "no unit at %s fits %s" at (missed_rows spans windows ks ~u))
      ~detail:
        (String.concat
           ~sep:"\n"
           ((if List.is_empty narrow
             then
               sprintf "nearest: a unit of %s" (cycles_text u)
               :: misses ~clock_hz ~u spans windows ks
             else narrow)
            @ kernel))
  | Error (Some (u, ks, e)) ->
    let kernel =
      sprintf "the kernel, at %s a unit:\n%s" (cycles_text u) (kernel_text e)
    in
    (match kernel_least shape spans ks ~from:(u + 1) ~clock_hz with
     | None ->
       refused (sprintf "the kernel refuses every unit that fits at %s" at) ~detail:kernel
     | Some v ->
       (* the runs at the kernel's least unit, as near the limits as they go *)
       let ks =
         let repicked = List.map2_exn spans windows ~f:(pick ~u:v) in
         if List.is_empty (missed spans windows repicked ~u:v) then ks else repicked
       in
       refused
         (sprintf
            "%s, as the kernel needs a unit of %d cycles at %s"
            (missed_rows spans windows ks ~u:v)
            v
            at)
         ~detail:
           (String.concat
              ~sep:"\n"
              ((needs v :: misses ~clock_hz ~u:v spans windows ks) @ [ kernel ])))
;;

(* the page steps the model about 300,000 cycles a second *)
let run ?(model_cycles = 1_000_000) ~clock_hz text =
  match
    let open Or_error.Let_syntax in
    let%bind shape, rows = parse text in
    let%map spans = spans shape rows in
    shape, rows, spans
  with
  | Error e ->
    { Report.verdict = "not read"
    ; detail = Error.to_string_hum e
    ; limits = ""
    ; source = ""
    ; check = no_check
    ; host = ""
    ; firmware = None
    }
  | Ok (shape, rows, spans) ->
    let windows = List.map spans ~f:(fun (s : Span.t) -> window ~clock_hz s.row) in
    (match
       List.find spans ~f:(fun s -> Role.equal s.role Gap && Option.is_some s.row.max_ns)
     with
     | Some span ->
       refused
         (sprintf
            "%s, as the host paces frames, so a gap has no max the firmware can hold"
            span.row.name)
     | None -> search ~clock_hz ~model_cycles shape spans windows rows)
;;

let to_string (r : Report.t) =
  String.concat
    [ "verdict: " ^ r.verdict ^ "\n"
    ; "detail:\n" ^ r.detail ^ "\n"
    ; "limits:\n" ^ r.limits ^ "\n"
    ; "source:\n" ^ r.source ^ "\n"
    ; "listing:\n" ^ r.check.listing ^ "\n"
    ; "rows:\n" ^ r.check.rows ^ "\n"
    ; "host:\n" ^ r.host ^ "\n"
    ]
;;
