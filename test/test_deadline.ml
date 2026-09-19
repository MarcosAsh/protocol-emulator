open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module Deadline = Deadline.Make (G)

let now = G.input "now" Isa.timer_bits
let t = G.input "t" Isa.timer_bits

let prove name ~claim =
  match Solver.solve ~solver:(Solver.z3 ~parallel:false ()) (G.cnf G.(~:claim)) with
  | Ok Unsat -> print_s [%message "QED" name]
  | Ok (Sat model) ->
    let value name =
      let m =
        List.find_exn model ~f:(fun (m : Cnf.Model_with_vectors.input) ->
          String.equal m.name name)
      in
      Int.of_string ("0b" ^ m.value)
    in
    let phase = (value "now" - value "t") land ((1 lsl Isa.timer_bits) - 1) in
    print_s [%message "counterexample" name (phase : int)]
  | Error e -> print_s [%message "solver failed" name (e : Error.t)]
;;

let%expect_test "the release compare is the signed test the model uses" =
  prove
    "release = now - t >= 0 signed"
    ~claim:G.(Deadline.release ~now ~t ==: (now -: t >=+ zero Isa.timer_bits));
  prove
    "late = release and now <> t"
    ~claim:G.(Deadline.late ~now ~t ==: (Deadline.release ~now ~t &: (now <>: t)));
  [%expect
    {|
    (QED "release = now - t >= 0 signed")
    (QED "late = release and now <> t")
    |}]
;;

let%expect_test "t - now <= 0 is not the same test" =
  prove
    "release = t - now <= 0 signed"
    ~claim:G.(Deadline.release ~now ~t ==: (t -: now <=+ zero Isa.timer_bits));
  [%expect {| (counterexample "release = t - now <= 0 signed" (phase 8388608)) |}]
;;
