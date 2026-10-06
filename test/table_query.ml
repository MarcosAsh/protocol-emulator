open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module K = Kernel.Make (G)

let full = (Kernel.Table.of_analyser []).(0)
let row_name pc field = [%string "pc%{pc#Int}_%{field}"]

(* The model spells a vector msb first, with a [-] for a bit the CNF does not use and
   nothing for the bits above the highest it does. *)
let of_model model ~pc =
  Kernel.Row.map2 Kernel.Row.port_names Kernel.Row.port_widths ~f:(fun field width ->
    match
      List.find model ~f:(fun (m : Cnf.Model_with_vectors.input) ->
        String.equal m.name (row_name pc field))
    with
    | None -> Bits.zero width
    | Some m ->
      String.fold m.value ~init:0 ~f:(fun value bit ->
        (2 * value) + Bool.to_int (Char.equal bit '1'))
      |> Bits.of_unsigned_int ~width)
;;

let constant b = G.of_constant (Bits.to_constant b)
let size = 1 lsl Isa.pc_bits

let accepts ~loaded ~single_capture_edge ~(config : Program_config.t) ~words table =
  let words = Array.of_list words in
  let word pc =
    Bits.of_unsigned_int
      ~width:Isa.data_bits
      (if pc < Array.length words then words.(pc) else 0)
  in
  let following pc =
    if pc = config.wrap_top then config.wrap_bottom else (pc + 1) % size
  in
  let side_set_count = G.of_unsigned_int ~width:2 config.side_set_count in
  let fraction = G.of_bool (config.period_fraction <> 0) in
  let capture =
    { Kernel.Capture.pin =
        G.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
    ; rising = G.of_bool config.capture_rising
    ; single_edge = G.of_bool single_capture_edge
    }
  in
  List.init size ~f:(fun pc ->
    let target =
      Bits.to_unsigned_int (Isa.Field.select (module Bits) Isa.Field.jmp_target (word pc))
    in
    K.accepts
      ~side_set_count
      ~fraction
      ~loaded
      ~capture
      ~spacing:K.no_spacing
      ~word:(constant (word pc))
      ~row:table.(pc)
      ~next:table.(following pc)
      ~target:table.(target))
  |> G.reduce ~f:G.( &: )
;;

let every_load_from ~floor ~single_capture_edge ~config ~words (table : Kernel.Table.t) =
  let loaded = { With_valid.valid = G.vdd; value = G.input "loaded" Isa.data_bits } in
  let accepts =
    Array.map table ~f:(Kernel.Row.map ~f:constant)
    |> accepts ~loaded ~single_capture_edge ~config ~words
  in
  let below = G.(loaded.value <:. floor) in
  G.(below |: accepts)
;;

let witness
  ?(solver = Checked_unsat.solver)
  ?(offsets = true)
  ?period
  ~single_capture_edge
  ~config
  ~words
  ()
  =
  let table =
    Array.init size ~f:(fun pc ->
      let row =
        Kernel.Row.map2
          Kernel.Row.port_names
          Kernel.Row.port_widths
          ~f:(fun field width -> G.input (row_name pc field) width)
      in
      let full = Kernel.Row.map full ~f:constant in
      if pc = 0
      then full
      else if offsets
      then row
      else
        { row with
          slope = full.slope
        ; offset_lo = full.offset_lo
        ; offset_hi = full.offset_hi
        })
  in
  let loaded =
    { With_valid.valid = G.of_bool (Option.is_some period)
    ; value = G.of_unsigned_int ~width:Isa.data_bits (Option.value period ~default:0)
    }
  in
  match
    Solver.solve
      ~solver
      (G.cnf (accepts ~loaded ~single_capture_edge ~config ~words table))
    |> ok_exn
  with
  | Unsat -> None
  | Sat model ->
    Some
      (Array.init size ~f:(fun pc ->
         if pc = 0
         then full
         else (
           let row = of_model model ~pc in
           if offsets
           then row
           else
             { row with
               slope = full.slope
             ; offset_lo = full.offset_lo
             ; offset_hi = full.offset_hi
             })))
;;

let some_table_passes ?offsets (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  let config = Asm.Program.configure program c.config in
  let words = Asm.Program.words program |> ok_exn in
  let single_capture_edge = c.single_capture_edge in
  match witness ?offsets ?period:c.period ~single_capture_edge ~config ~words () with
  | None -> false
  | Some table ->
    Kernel.check ?period:c.period ~single_capture_edge ~config ~words table |> ok_exn;
    true
;;
