open! Core
open! Hardcaml
open Protocol_emulator
module K = Kernel.Make (Bits)

let word source =
  let program = Asm.assemble source |> ok_exn in
  Bits.of_unsigned_int
    ~width:Isa.data_bits
    (List.hd_exn (Asm.Program.words program |> ok_exn))
;;

(* pin a is the set pin, held 10 cycles and 5 apart from b's last edge *)
let spacing =
  { With_valid.valid = Bits.vdd
  ; value =
      Kernel.Spacing.of_spec
        Program_config.default
        { a = Program_config.default.set_base
        ; b = Program_config.default.set_base + 1
        ; dirs = false
        ; hold_a = (fun ~own:_ ~other:_ -> 10)
        ; apart_a = (fun ~own:_ ~other:_ -> 5)
        ; hold_b = (fun ~own:_ ~other:_ -> 0)
        ; apart_b = (fun ~own:_ ~other:_ -> 0)
        }
  }
;;

let edge ~since ~fresh =
  { Kernel.Edge.since = Bits.of_unsigned_int ~width:Isa.data_bits since
  ; level = Bits.gnd
  ; fresh = Bits.of_bool fresh
  }
;;

(* The step's capture state and the pair's edges from one word, at a phase of -100 and an
   arm count of 10; what formal/edge_step.sv and phase_step.sv prove of the RTL. *)
let%expect_test "the step's capture and edge state" =
  let step ~source ~arm_known ~captured ~awaiting ~a ~b =
    let s =
      K.step
        ~side_set_count:(Bits.zero 2)
        ~fraction:Bits.gnd
        ~loaded:{ valid = Bits.gnd; value = Bits.zero Isa.data_bits }
        ~capture:
          { pin = Bits.zero Isa.Field.wait_index.width
          ; rising = Bits.gnd
          ; single_edge = Bits.vdd
          }
        ~spacing
        ~word:(word source)
        ~phase:(Bits.of_signed_int ~width:Isa.timer_bits (-100))
        ~period:(Bits.zero Isa.data_bits)
        ~x:(Bits.zero Isa.data_bits)
        ~y:(Bits.zero Isa.data_bits)
        ~arm:(Bits.of_unsigned_int ~width:Isa.timer_bits 10)
        ~arm_known:(Bits.of_bool arm_known)
        ~captured:(Bits.of_bool captured)
        ~awaiting:(Bits.of_bool awaiting)
        ~a
        ~b
        ~data_a:Bits.gnd
        ~data_b:Bits.gnd
    in
    let bool = Bits.to_bool in
    print_s
      [%message
        source
          (arm_known : bool)
          (captured : bool)
          (awaiting : bool)
          ~capture_bounded:(bool s.capture_bounded : bool)
          ~next_arm_known:(bool s.next_arm_known : bool)
          ~next_captured:(bool s.next_captured : bool)
          ~next_awaiting:(bool s.next_awaiting : bool)
          ~a_fresh:(bool s.next_a.fresh : bool)
          ~b_fresh:(bool s.next_b.fresh : bool)
          ~a_spaced:(bool s.wide_a : bool)]
  in
  let settled = edge ~since:100 ~fresh:false in
  let fresh = edge ~since:0xffff ~fresh:true in
  step ~source:"nop" ~arm_known:true ~captured:false ~awaiting:false ~a:settled ~b:fresh;
  step ~source:"nop" ~arm_known:true ~captured:true ~awaiting:false ~a:settled ~b:fresh;
  step ~source:"nop" ~arm_known:false ~captured:false ~awaiting:true ~a:settled ~b:fresh;
  step
    ~source:"capture_arm"
    ~arm_known:true
    ~captured:true
    ~awaiting:false
    ~a:settled
    ~b:fresh;
  step
    ~source:"mov t, capture"
    ~arm_known:true
    ~captured:true
    ~awaiting:false
    ~a:settled
    ~b:fresh;
  step
    ~source:"set pins, 0"
    ~arm_known:true
    ~captured:false
    ~awaiting:false
    ~a:fresh
    ~b:fresh;
  (* an edge of a 2 cycles after b's *)
  step
    ~source:"set pins, 1"
    ~arm_known:true
    ~captured:false
    ~awaiting:false
    ~a:settled
    ~b:(edge ~since:2 ~fresh:false);
  [%expect
    {|
    (nop (arm_known true) (captured false) (awaiting false)
     (capture_bounded false) (next_arm_known true) (next_captured false)
     (next_awaiting false) (a_fresh false) (b_fresh true) (a_spaced true))
    (nop (arm_known true) (captured true) (awaiting false)
     (capture_bounded false) (next_arm_known true) (next_captured true)
     (next_awaiting false) (a_fresh false) (b_fresh true) (a_spaced true))
    (nop (arm_known false) (captured false) (awaiting true)
     (capture_bounded false) (next_arm_known false) (next_captured false)
     (next_awaiting true) (a_fresh false) (b_fresh true) (a_spaced true))
    (capture_arm (arm_known true) (captured true) (awaiting false)
     (capture_bounded false) (next_arm_known true) (next_captured false)
     (next_awaiting true) (a_fresh false) (b_fresh true) (a_spaced true))
    ("mov t, capture" (arm_known true) (captured true) (awaiting false)
     (capture_bounded true) (next_arm_known true) (next_captured true)
     (next_awaiting false) (a_fresh false) (b_fresh true) (a_spaced true))
    ("set pins, 0" (arm_known true) (captured false) (awaiting false)
     (capture_bounded false) (next_arm_known true) (next_captured false)
     (next_awaiting false) (a_fresh false) (b_fresh true) (a_spaced true))
    ("set pins, 1" (arm_known true) (captured false) (awaiting false)
     (capture_bounded false) (next_arm_known true) (next_captured false)
     (next_awaiting false) (a_fresh false) (b_fresh false) (a_spaced false))
    |}]
;;
