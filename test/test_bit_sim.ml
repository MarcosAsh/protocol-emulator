open! Core
open! Hardcaml
open Protocol_emulator

(* one output of a combinational circuit, on these inputs *)
let evaluate ~inputs f =
  let open Signal in
  let a = input "a" 4 in
  let b = input "b" 4 in
  let s = input "s" 1 in
  let circuit = Circuit.create_exn ~name:"comb" [ output "o" (f ~a ~b ~s) ] in
  let sim = Bit_sim.create circuit |> ok_exn in
  let outputs, _ =
    Bit_sim.step sim (Bit_sim.initial sim) ~inputs:(fun name ->
      List.Assoc.find inputs name ~equal:String.equal)
  in
  print_endline
    (Bit_sim.Value.to_string (List.Assoc.find_exn outputs "o" ~equal:String.equal))
;;

let%expect_test "logic keeps data bits, arithmetic needs known operands" =
  let open Signal in
  let data = Bit_sim.Value.data ~width:4 in
  let known n = Bit_sim.Value.of_bits (Bits.of_unsigned_int ~width:4 n) in
  let unknown = Bit_sim.Value.unknown ~width:1 in
  evaluate ~inputs:[ "a", data; "b", known 0b0110 ] (fun ~a ~b ~s:_ -> a &: b);
  evaluate ~inputs:[ "a", data; "b", known 0b0110 ] (fun ~a ~b ~s:_ -> a ^: b);
  evaluate ~inputs:[ "a", data; "b", known 1 ] (fun ~a ~b ~s:_ -> a +: b);
  evaluate ~inputs:[ "a", known 3; "b", known 4 ] (fun ~a ~b ~s:_ -> a +: b);
  (* a mux on an unknown select keeps the bits its cases agree on *)
  evaluate
    ~inputs:[ "a", known 0b1100; "b", known 0b1010; "s", unknown ]
    (fun ~a ~b ~s -> mux2 s a b);
  (* an equality some known bit already decides *)
  evaluate
    ~inputs:[ "a", [| One; Unknown; Unknown; Unknown |] ]
    (fun ~a ~b:_ ~s:_ -> a ==:. 2);
  [%expect
    {|
    {0 d2 d1 0}
    {d3 ~d2 ~d1 d0}
    {x x x x}
    7
    {1 x x 0}
    0
    |}]
;;

let%expect_test "a register takes reset, then enable, and starts unknown" =
  let open Signal in
  let clock = input "clock" 1 in
  let reset = input "reset" 1 in
  let enable = input "enable" 1 in
  let d = input "d" 4 in
  let r = reg (Reg_spec.create ~clock ~reset ()) ~enable d in
  let circuit = Circuit.create_exn ~name:"r" [ output "q" r ] in
  let sim = Bit_sim.create circuit |> ok_exn in
  let bit b = Bit_sim.Value.of_bits (Bits.of_bool b) in
  let cycle state inputs =
    let _, next =
      Bit_sim.step sim state ~inputs:(fun name ->
        List.Assoc.find inputs name ~equal:String.equal)
    in
    print_endline (Bit_sim.Value.to_string (Bit_sim.State.find next r));
    next
  in
  let state = Bit_sim.initial sim in
  print_endline (Bit_sim.Value.to_string (Bit_sim.State.find state r));
  let state = cycle state [ "reset", bit false; "enable", bit false ] in
  let state = cycle state [ "reset", bit true ] in
  let state =
    cycle
      state
      [ "reset", bit false; "enable", bit true; "d", Bit_sim.Value.data ~width:4 ]
  in
  let (_ : Bit_sim.State.t) =
    cycle
      state
      [ "reset", bit false
      ; "enable", Bit_sim.Value.unknown ~width:1
      ; "d", Bit_sim.Value.of_bits (Bits.of_unsigned_int ~width:4 0)
      ]
  in
  [%expect {|
    {x x x x}
    {x x x x}
    0
    {d3 d2 d1 d0}
    {x x x x}
    |}]
;;
