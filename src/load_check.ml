open! Core
open! Hardcaml
module K = Kernel.Make (Bits)

let index_bits = 7
let timer_bits = Isa.timer_bits
let half = 1 lsl (timer_bits - 1)
let timer_ones = (1 lsl timer_bits) - 1
let data_ones = (1 lsl Isa.data_bits) - 1

(* bounds as the bits the row holds them in, read unsigned *)
let phase_whole = half, half - 1
let arm_whole = 0, timer_ones
let narrow_whole = 0, data_ones

type entry =
  { pc : int
  ; captured : bool
  ; awaiting : bool
  ; phase : int
  ; arm : int
  ; period : int
  ; x : int
  ; y : int
  }
[@@deriving sexp_of]

type t =
  { entries : entry list
  ; wide : (int * int) list
  ; narrow : (int * int) list
  }
[@@deriving sexp_of]

let stored_pcs ~(config : Program_config.t) ~words =
  List.filter_map words ~f:(fun w ->
    match Isa.of_word ~side_set_count:config.side_set_count w with
    | Ok (Jmp { target; _ }) -> Some target
    | _ -> None)
  |> List.cons config.wrap_bottom
  |> List.filter ~f:(fun pc -> pc <> 0)
  |> List.dedup_and_sort ~compare:Int.compare
;;

(* an interval's index in a dictionary built as it goes, 0 for the whole range *)
let intern dictionary ~whole interval =
  if [%equal: int * int] interval whole
  then 0
  else (
    match
      List.findi !dictionary ~f:(fun _ known -> [%equal: int * int] known interval)
    with
    | Some (i, _) -> i + 1
    | None ->
      dictionary := !dictionary @ [ interval ];
      List.length !dictionary)
;;

let of_table ~config ~words (table : Kernel.Table.t) =
  let wide = ref [] in
  let narrow = ref [] in
  let bounds lo hi = Bits.to_unsigned_int lo, Bits.to_unsigned_int hi in
  let entries =
    List.map (stored_pcs ~config ~words) ~f:(fun pc ->
      let r = table.(pc) in
      { pc
      ; captured = Bits.to_bool r.captured
      ; awaiting = Bits.to_bool r.awaiting
      ; phase = intern wide ~whole:phase_whole (bounds r.phase_lo r.phase_hi)
      ; arm = intern wide ~whole:arm_whole (bounds r.arm_lo r.arm_hi)
      ; period = intern narrow ~whole:narrow_whole (bounds r.period_lo r.period_hi)
      ; x = intern narrow ~whole:narrow_whole (bounds r.x_lo r.x_hi)
      ; y = intern narrow ~whole:narrow_whole (bounds r.y_lo r.y_hi)
      })
  in
  let fits dictionary = List.length !dictionary < 1 lsl index_bits in
  if fits wide && fits narrow
  then Ok { entries; wide = !wide; narrow = !narrow }
  else
    Or_error.error_s
      [%message
        "a dictionary outgrows its indices"
          ~wide:(List.length !wide : int)
          ~narrow:(List.length !narrow : int)]
;;

(* 48 bits as three words, the top first *)
let split3 bits = [ (bits lsr 32) land 0xffff; (bits lsr 16) land 0xffff; bits land 0xffff ]
let join3 memory at = (memory at lsl 32) lor (memory (at + 1) lsl 16) lor memory (at + 2)

(* pc 9, captured, awaiting, then the phase, arm, period, x and y indices, 7 bits each *)
let pack e =
  (e.pc lsl 39)
  lor (Bool.to_int e.captured lsl 38)
  lor (Bool.to_int e.awaiting lsl 37)
  lor (e.phase lsl 30)
  lor (e.arm lsl 23)
  lor (e.period lsl 16)
  lor (e.x lsl 9)
  lor (e.y lsl 2)
;;

let unpack bits =
  let index at = (bits lsr at) land ((1 lsl index_bits) - 1) in
  { pc = (bits lsr 39) land ((1 lsl Isa.pc_bits) - 1)
  ; captured = (bits lsr 38) land 1 = 1
  ; awaiting = (bits lsr 37) land 1 = 1
  ; phase = index 30
  ; arm = index 23
  ; period = index 16
  ; x = index 9
  ; y = index 2
  }
;;

let to_words t =
  [ List.length t.entries; List.length t.wide ]
  @ List.concat_map t.entries ~f:(fun e -> split3 (pack e))
  @ List.concat_map t.wide ~f:(fun (lo, hi) -> split3 ((lo lsl timer_bits) lor hi))
  @ List.concat_map t.narrow ~f:(fun (lo, hi) -> [ lo; hi ])
;;

module Rejection = struct
  type t =
    { pc : int
    ; reason : string
    }
  [@@deriving sexp_of]
end

let full = (Kernel.Table.of_analyser []).(0)
let empty = (Kernel.Table.of_analyser []).(1)

let names =
  let way name = Kernel.Holds.map Kernel.Holds.port_names ~f:(fun f -> name ^ " " ^ f) in
  { Kernel.Conjuncts.in_time = "in time"
  ; wide_a = "a spaced"
  ; wide_b = "b spaced"
  ; next = way "next"
  ; target = way "target"
  }
;;

let walk
  ?loaded
  ?(single_capture_edge = false)
  ~(config : Program_config.t)
  ~words
  ~memory
  ~base
  ()
  =
  let size = 1 lsl Isa.pc_bits in
  let words = Array.of_list words in
  let word pc =
    Bits.of_unsigned_int ~width:Isa.data_bits (if pc < Array.length words then words.(pc) else 0)
  in
  let count = memory base in
  let wide_count = memory (base + 1) in
  let entry i = unpack (join3 memory (base + 2 + (3 * i))) in
  let wide_at = base + 2 + (3 * count) in
  let narrow_at = wide_at + (3 * wide_count) in
  let decode e =
    let wide ~whole i =
      if i = 0
      then whole
      else (
        let bits = join3 memory (wide_at + (3 * (i - 1))) in
        bits lsr timer_bits, bits land timer_ones)
    in
    let narrow i =
      if i = 0 then narrow_whole else memory (narrow_at + (2 * (i - 1))), memory (narrow_at + (2 * (i - 1)) + 1)
    in
    let timer (lo, hi) = Bits.of_unsigned_int ~width:timer_bits lo, Bits.of_unsigned_int ~width:timer_bits hi in
    let data (lo, hi) =
      Bits.of_unsigned_int ~width:Isa.data_bits lo, Bits.of_unsigned_int ~width:Isa.data_bits hi
    in
    let phase_lo, phase_hi = timer (wide ~whole:phase_whole e.phase) in
    let arm_lo, arm_hi = timer (wide ~whole:arm_whole e.arm) in
    let period_lo, period_hi = data (narrow e.period) in
    let x_lo, x_hi = data (narrow e.x) in
    let y_lo, y_hi = data (narrow e.y) in
    { full with
      phase_lo
    ; phase_hi
    ; arm_lo
    ; arm_hi
    ; period_lo
    ; period_hi
    ; x_lo
    ; x_hi
    ; y_lo
    ; y_hi
    ; captured = Bits.of_bool e.captured
    ; awaiting = Bits.of_bool e.awaiting
    }
  in
  (* a target's row by binary search, empty where there is none *)
  let lookup pc =
    if pc = 0
    then full
    else (
      let rec search lo hi =
        if lo >= hi
        then empty
        else (
          let mid = (lo + hi) / 2 in
          let e = entry mid in
          if e.pc = pc then decode e else if e.pc < pc then search (mid + 1) hi else search lo mid)
      in
      search 0 count)
  in
  let side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count in
  let fraction = Bits.of_bool (config.period_fraction <> 0) in
  let loaded =
    { With_valid.valid = Bits.of_bool (Option.is_some loaded)
    ; value = Bits.of_unsigned_int ~width:Isa.data_bits (Option.value loaded ~default:0)
    }
  in
  let capture =
    { Kernel.Capture.pin =
        Bits.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
    ; rising = Bits.of_bool config.capture_rising
    ; single_edge = Bits.of_bool single_capture_edge
    }
  in
  let pc_bits n = Bits.of_unsigned_int ~width:Isa.pc_bits n in
  let rows = Array.create ~len:size empty in
  let rec step pc row ptr =
    rows.(pc) <- row;
    let reject reason = Error { Rejection.pc; reason } in
    if ptr < count && (entry ptr).pc <= pc
    then reject "a table entry out of order"
    else (
      let w = word pc in
      let next_pc, target_pc =
        K.successors
          ~wrap_top:(pc_bits config.wrap_top)
          ~wrap_bottom:(pc_bits config.wrap_bottom)
          ~pc:(pc_bits pc)
          ~word:w
      in
      let next_pc = Bits.to_unsigned_int next_pc in
      let stored = ptr < count && (entry ptr).pc = pc + 1 in
      let after =
        if stored
        then decode (entry ptr)
        else if next_pc = pc + 1
        then (
          let fallen, falls =
            K.fall_through ~side_set_count ~fraction ~loaded ~capture ~word:w ~row
          in
          if Bits.to_bool falls then fallen else empty)
        else empty
      in
      let conjuncts =
        K.conjuncts
          ~side_set_count
          ~fraction
          ~loaded
          ~capture
          ~spacing:K.no_spacing
          ~word:w
          ~row
          ~next:(if next_pc = pc + 1 then after else lookup next_pc)
          ~target:(lookup (Bits.to_unsigned_int target_pc))
      in
      let fails =
        List.filter_map
          (Kernel.Conjuncts.to_list (Kernel.Conjuncts.zip names conjuncts))
          ~f:(fun (name, holds) -> Option.some_if (not (Bits.to_bool holds)) name)
      in
      match fails with
      | reason :: _ -> reject reason
      | [] when pc + 1 = size ->
        if ptr + Bool.to_int stored = count
        then Ok (Array.copy rows)
        else Error { Rejection.pc = size; reason = "a table entry left over" }
      | [] -> step (pc + 1) after (ptr + Bool.to_int stored))
  in
  step 0 full 0
;;
