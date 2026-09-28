open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module Pins = Pins.Make (G)

(* The run of pins, one pin at a time: what [Pins] has to agree with. *)
module Reference = struct
  open G

  let pin_bits = Int.ceil_log2 Isa.pin_space

  let pin_index base j =
    let s = uresize base ~width:(pin_bits + 1) +:. j in
    mux2 (s >=:. Isa.pin_space) (s -:. Isa.pin_space) s |> sel_bottom ~width:pin_bits
  ;;

  let read sample ~base ~count =
    List.init Isa.data_bits ~f:(fun j ->
      let hit = of_unsigned_int ~width:(width count) j <: count in
      hit &: mux (pin_index base j) (bits_lsb sample))
    |> concat_lsb
  ;;

  let write old ~base ~count ~value ~writable =
    List.init Isa.pin_space ~f:(fun i ->
      let hits =
        List.init Isa.data_bits ~f:(fun j ->
          let hit =
            pin_index base j
            ==:. i
            &: (of_unsigned_int ~width:(width count) j <: count)
            &: of_bool (writable i)
          in
          hit, value.:(j))
      in
      List.fold hits ~init:old.:(i) ~f:(fun pin (hit, bit) -> mux2 hit bit pin))
    |> concat_lsb
  ;;
end

let pins = G.input "pins" Isa.pin_space
let base = G.input "base" Reference.pin_bits
let count = G.input "count" Isa.count_bits
let value = G.input "value" Isa.data_bits
let in_range = G.(base <:. Isa.pin_space &: (count <=:. Isa.data_bits))

let prove ?(solver = Checked_unsat.solver) name ~claim =
  match Solver.solve ~solver (G.cnf G.(in_range &: ~:claim)) with
  | Ok Unsat -> print_s [%message "QED" name]
  | Ok (Sat _) -> print_s [%message "counterexample" name]
  | Error e -> print_s [%message "solver failed" name (e : Error.t)]
;;

let writes_like ~writable ~reference =
  G.(
    Pins.write pins ~base ~count ~value ~writable
    ==: Reference.write pins ~base ~count ~value ~writable:reference)
;;

let claims =
  ("read", G.(Pins.read pins ~base ~count ==: Reference.read pins ~base ~count))
  :: List.map
       [ "write any pin", Fn.const true
       ; ("write output pins", fun i -> i >= Isa.first_output_pin)
       ; ( "write bidirectional pins"
         , fun i -> i >= Isa.first_bidir_pin && i < Isa.num_pins )
       ]
       ~f:(fun (name, writable) -> name, writes_like ~writable ~reference:writable)
;;

let%expect_test "rotating the pins is the same as indexing each one" =
  List.iter claims ~f:(fun (name, claim) -> prove name ~claim);
  [%expect
    {|
    (QED read)
    (QED "write any pin")
    (QED "write output pins")
    (QED "write bidirectional pins")
    |}]
;;

let%expect_test "no QED once cake_lpr refuses the proof, or for a false claim" =
  List.iter claims ~f:(fun (name, claim) ->
    prove ~solver:Checked_unsat.solver_with_a_bad_proof name ~claim);
  prove
    "write output pins as any pin"
    ~claim:
      (writes_like
         ~writable:(fun i -> i >= Isa.first_output_pin)
         ~reference:(Fn.const true));
  [%expect
    {|
    ("solver failed" read
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 0. Reason: clause index has no reduction sequence: 9646\n")))
    ("solver failed" "write any pin"
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 0. Reason: clause index has no reduction sequence: 80921\n")))
    ("solver failed" "write output pins"
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 0. Reason: clause index has no reduction sequence: 66761\n")))
    ("solver failed" "write bidirectional pins"
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 0. Reason: clause index has no reduction sequence: 24849\n")))
    (counterexample "write output pins as any pin")
    |}]
;;
