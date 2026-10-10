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

module Entry = struct
  type 'a t =
    { pc : 'a [@bits Isa.pc_bits]
    ; captured : 'a
    ; awaiting : 'a
    ; phase : 'a [@bits index_bits]
    ; arm : 'a [@bits index_bits]
    ; period : 'a [@bits index_bits]
    ; x : 'a [@bits index_bits]
    ; y : 'a [@bits index_bits]
    }
  [@@deriving hardcaml]
end

let unused_bits = (3 * Isa.data_bits) - Entry.sum_of_port_widths

type t =
  { entries : int Entry.t list
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

let of_table ?(registers_whole = false) ~config ~words (table : Kernel.Table.t) =
  let wide = ref [] in
  let narrow = ref [] in
  let bounds lo hi = Bits.to_unsigned_int lo, Bits.to_unsigned_int hi in
  let entries =
    List.map (stored_pcs ~config ~words) ~f:(fun pc ->
      let r = table.(pc) in
      { Entry.pc
      ; captured = Bits.to_unsigned_int r.captured
      ; awaiting = Bits.to_unsigned_int r.awaiting
      ; phase = intern wide ~whole:phase_whole (bounds r.phase_lo r.phase_hi)
      ; arm = intern wide ~whole:arm_whole (bounds r.arm_lo r.arm_hi)
      ; period = intern narrow ~whole:narrow_whole (bounds r.period_lo r.period_hi)
      ; x =
          (if registers_whole
           then 0
           else intern narrow ~whole:narrow_whole (bounds r.x_lo r.x_hi))
      ; y =
          (if registers_whole
           then 0
           else intern narrow ~whole:narrow_whole (bounds r.y_lo r.y_hi))
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

let of_program
  ?registers_whole
  ?period
  ?period_floor
  ?single_capture_edge
  ~(config : Program_config.t)
  words
  =
  let%bind.Or_error instructions =
    List.map words ~f:(Isa.of_word ~side_set_count:config.side_set_count) |> Or_error.all
  in
  Analyser.analyse ?period ?period_floor ?single_capture_edge ~config instructions
  |> Kernel.Table.of_analyser
  |> of_table ?registers_whole ~config ~words
;;

(* 48 bits as three words, the top first *)
let split3 bits =
  [ (bits lsr 32) land 0xffff; (bits lsr 16) land 0xffff; bits land 0xffff ]
;;

let join3 memory at = (memory at lsl 32) lor (memory (at + 1) lsl 16) lor memory (at + 2)

(* an entry from the top of its three words, the first field highest *)
let pack (e : int Entry.t) =
  let bits =
    Entry.map2 Entry.port_widths e ~f:(fun width v -> Bits.of_unsigned_int ~width v)
    |> Entry.Of_bits.pack ~rev:true
  in
  Bits.to_unsigned_int bits lsl unused_bits
;;

let unpack bits =
  Bits.of_unsigned_int ~width:(3 * Isa.data_bits) bits
  |> Bits.drop_bottom ~width:unused_bits
  |> Entry.Of_bits.unpack ~rev:true
  |> Entry.map ~f:Bits.to_unsigned_int
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

let reason_bits = Int.ceil_log2 (List.length (Kernel.Conjuncts.to_list names))

module Step = struct
  let row_bits = Kernel.Row.sum_of_port_widths

  module I = struct
    type 'a t =
      { side_set_count : 'a [@bits 2]
      ; fraction : 'a
      ; loaded : 'a With_valid.t [@bits Isa.data_bits]
      ; capture : 'a Kernel.Capture.t
      ; wrap_top : 'a [@bits Isa.pc_bits]
      ; wrap_bottom : 'a [@bits Isa.pc_bits]
      ; pc : 'a [@bits Isa.pc_bits]
      ; word : 'a [@bits Isa.data_bits]
      ; row : 'a [@bits row_bits]
      ; stored : 'a
      ; stored_row : 'a [@bits row_bits]
      ; next : 'a [@bits row_bits]
      ; target : 'a [@bits row_bits]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { next_pc : 'a [@bits Isa.pc_bits]
      ; target_pc : 'a [@bits Isa.pc_bits]
      ; after : 'a [@bits row_bits]
      ; fails : 'a
      ; reason : 'a [@bits reason_bits]
      ; conjuncts : 'a Kernel.Conjuncts.t
      }
    [@@deriving hardcaml]
  end

  module Make (Comb : Comb.S) = struct
    module K = Kernel.Make (Comb)

    let step
      ~side_set_count
      ~fraction
      ~loaded
      ~capture
      ~pc
      ~word
      ~row
      ~stored
      ~stored_row
      ~next_pc
      ~next
      ~target
      =
      let empty_row =
        Kernel.Row.map empty ~f:(fun bits -> Comb.of_constant (Bits.to_constant bits))
      in
      let open Comb in
      (* one bit wider, so pc 511's way out never reads as falling through *)
      let falls_to_next =
        uresize next_pc ~width:(Isa.pc_bits + 1)
        ==: uresize pc ~width:(Isa.pc_bits + 1) +:. 1
      in
      let fallen, falls =
        K.fall_through ~side_set_count ~fraction ~loaded ~capture ~word ~row
      in
      let after =
        Kernel.Row.map2
          stored_row
          (Kernel.Row.map2 fallen empty_row ~f:(mux2 (falls_to_next &: falls)))
          ~f:(mux2 stored)
      in
      let conjuncts =
        K.conjuncts
          ~side_set_count
          ~fraction
          ~loaded
          ~capture
          ~spacing:K.no_spacing
          ~word
          ~row
          ~next:(Kernel.Row.map2 after next ~f:(mux2 falls_to_next))
          ~target
      in
      let holds = Kernel.Conjuncts.to_list conjuncts in
      let reason =
        priority_select_with_default
          (List.mapi holds ~f:(fun n holds ->
             { With_valid.valid = ~:holds; value = of_unsigned_int ~width:reason_bits n }))
          ~default:(zero reason_bits)
      in
      after, ~:(reduce holds ~f:( &: )), reason, conjuncts
    ;;
  end

  module Of_bits = Make (Bits)

  let create (_scope : Scope.t) (i : Signal.t I.t) =
    let module S = Make (Signal) in
    let row = Kernel.Row.Of_signal.unpack ~rev:true in
    let next_pc, target_pc =
      S.K.successors ~wrap_top:i.wrap_top ~wrap_bottom:i.wrap_bottom ~pc:i.pc ~word:i.word
    in
    let after, fails, reason, conjuncts =
      S.step
        ~side_set_count:i.side_set_count
        ~fraction:i.fraction
        ~loaded:i.loaded
        ~capture:i.capture
        ~pc:i.pc
        ~word:i.word
        ~row:(row i.row)
        ~stored:i.stored
        ~stored_row:(row i.stored_row)
        ~next_pc
        ~next:(row i.next)
        ~target:(row i.target)
    in
    { O.next_pc
    ; target_pc
    ; after = Kernel.Row.Of_signal.pack ~rev:true after
    ; fails
    ; reason
    ; conjuncts
    }
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"load_check_step" create i
  ;;
end

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
    Bits.of_unsigned_int
      ~width:Isa.data_bits
      (if pc < Array.length words then words.(pc) else 0)
  in
  (* as the chip reads them: addresses wrap at the memory's size, counts are a byte *)
  let memory at = memory (at land ((1 lsl Isa.data_addr_bits) - 1)) in
  let count = memory base land 0xff in
  let wide_count = memory (base + 1) land 0xff in
  let entry i = unpack (join3 memory (base + 2 + (3 * i))) in
  let wide_at = base + 2 + (3 * count) in
  let narrow_at = wide_at + (3 * wide_count) in
  let decode (e : int Entry.t) =
    let wide ~whole i =
      if i = 0
      then whole
      else (
        let bits = join3 memory (wide_at + (3 * (i - 1))) in
        bits lsr timer_bits, bits land timer_ones)
    in
    let narrow i =
      if i = 0
      then narrow_whole
      else memory (narrow_at + (2 * (i - 1))), memory (narrow_at + (2 * (i - 1)) + 1)
    in
    let timer (lo, hi) =
      Bits.of_unsigned_int ~width:timer_bits lo, Bits.of_unsigned_int ~width:timer_bits hi
    in
    let data (lo, hi) =
      ( Bits.of_unsigned_int ~width:Isa.data_bits lo
      , Bits.of_unsigned_int ~width:Isa.data_bits hi )
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
    ; captured = Bits.of_unsigned_int ~width:1 e.captured
    ; awaiting = Bits.of_unsigned_int ~width:1 e.awaiting
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
          if e.pc = pc
          then decode e
          else if e.pc < pc
          then search (mid + 1) hi
          else search lo mid)
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
      let stored = ptr < count && (entry ptr).pc = pc + 1 in
      let after, fails, reason, _ =
        Step.Of_bits.step
          ~side_set_count
          ~fraction
          ~loaded
          ~capture
          ~pc:(pc_bits pc)
          ~word:w
          ~row
          ~stored:(Bits.of_bool stored)
          ~stored_row:(if stored then decode (entry ptr) else empty)
          ~next_pc
          ~next:(lookup (Bits.to_unsigned_int next_pc))
          ~target:(lookup (Bits.to_unsigned_int target_pc))
      in
      if Bits.to_bool fails
      then
        reject
          (List.nth_exn (Kernel.Conjuncts.to_list names) (Bits.to_unsigned_int reason))
      else if pc + 1 = size
      then
        if ptr + Bool.to_int stored = count
        then Ok (Array.copy rows)
        else Error { Rejection.pc = size; reason = "a table entry left over" }
      else step (pc + 1) after (ptr + Bool.to_int stored))
  in
  step 0 full 0
;;
