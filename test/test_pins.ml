open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module Pins = Pins.Make (G)

(* The run of pins, one pin at a time: what [Pins] has to agree with. *)
module Reference = struct
  open G

  let pin_bits = Int.ceil_log2 Isa.num_pins

  let pin_index base j =
    let s = uresize base ~width:(pin_bits + 1) +:. j in
    mux2 (s >=:. Isa.num_pins) (s -:. Isa.num_pins) s |> sel_bottom ~width:pin_bits
  ;;

  let read sample ~base ~count =
    List.init Isa.data_bits ~f:(fun j ->
      let hit = of_unsigned_int ~width:(width count) j <: count in
      hit &: mux (pin_index base j) (bits_lsb sample))
    |> concat_lsb
  ;;

  let write old ~base ~count ~value ~writable =
    List.init Isa.num_pins ~f:(fun i ->
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

let pins = G.input "pins" Isa.num_pins
let base = G.input "base" Reference.pin_bits
let count = G.input "count" Isa.count_bits
let value = G.input "value" Isa.data_bits
let in_range = G.(base <:. Isa.num_pins &: (count <=:. Isa.data_bits))

let prove name ~claim =
  match
    Solver.solve ~solver:(Solver.z3 ~parallel:false ()) (G.cnf G.(in_range &: ~:claim))
  with
  | Ok Unsat -> print_s [%message "QED" name]
  | Ok (Sat _) -> print_s [%message "counterexample" name]
  | Error e -> print_s [%message "solver failed" name (e : Error.t)]
;;

let%expect_test "rotating the pins is the same as indexing each one" =
  prove "read" ~claim:G.(Pins.read pins ~base ~count ==: Reference.read pins ~base ~count);
  List.iter
    [ "write any pin", Fn.const true
    ; ("write output pins", fun i -> i >= Isa.first_output_pin)
    ; ("write bidirectional pins", fun i -> i >= Isa.first_bidir_pin)
    ]
    ~f:(fun (name, writable) ->
      prove
        name
        ~claim:
          G.(
            Pins.write pins ~base ~count ~value ~writable
            ==: Reference.write pins ~base ~count ~value ~writable));
  [%expect
    {|
    (QED read)
    (QED "write any pin")
    (QED "write output pins")
    (QED "write bidirectional pins")
    |}]
;;
