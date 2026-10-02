open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module Deadline = Deadline.Make (G)

let now = G.input "now" Isa.timer_bits
let t = G.input "t" Isa.timer_bits

let prove ?(solver = Checked_unsat.solver) name ~claim =
  match Solver.solve ~solver (G.cnf G.(~:claim)) with
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

let claims =
  [ ( "release = now - t >= 0 signed"
    , G.(Deadline.release ~now ~t ==: (now -: t >=+ zero Isa.timer_bits)) )
  ; ( "late = release and now <> t"
    , G.(Deadline.late ~now ~t ==: (Deadline.release ~now ~t &: (now <>: t))) )
  ]
;;

let%expect_test "the release compare is the signed test the model uses" =
  List.iter claims ~f:(fun (name, claim) -> prove name ~claim);
  [%expect
    {|
    (QED "release = now - t >= 0 signed")
    (QED "late = release and now <> t")
    |}]
;;

let%expect_test "no QED once cake_lpr refuses the proof" =
  List.iter claims ~f:(fun (name, claim) ->
    prove ~solver:Checked_unsat.solver_with_a_bad_proof name ~claim);
  [%expect
    {|
    ("solver failed" "release = now - t >= 0 signed"
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 1. Reason: clause index has no reduction sequence: 5\n")))
    ("solver failed" "late = release and now <> t"
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 1. Reason: clause index has no reduction sequence: 5\n")))
    |}]
;;

(* and no counterexample once [check_model] refuses the model *)
let%expect_test "t - now <= 0 is not the same test" =
  let claim = G.(Deadline.release ~now ~t ==: (t -: now <=+ zero Isa.timer_bits)) in
  prove "release = t - now <= 0 signed" ~claim;
  prove
    ~solver:Checked_unsat.solver_with_a_bad_model
    "release = t - now <= 0 signed"
    ~claim;
  [%expect
    {|
    (counterexample "release = t - now <= 0 signed" (phase 8388608))
    ("solver failed" "release = t - now <= 0 signed"
     (e ("the model falsifies a clause" (clause (-1 -235)))))
    |}]
;;
