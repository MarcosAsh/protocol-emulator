open! Core
open! Hardcaml
open Protocol_emulator

(* The circuit and every circuit under it, as [bin/generate.ml] writes them out. *)
let circuits create =
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let top = create scope in
  top :: Circuit_database.get_circuits (Scope.circuit_database scope)
;;

let engine ~memory scope =
  let module C = Circuit.With_interface (Solo.I) (Solo.O) in
  C.create_exn ~name:"engine_top" (Solo.hierarchical ~memory scope)
;;

let kernel scope =
  let module C = Circuit.With_interface (Kernel.I) (Kernel.O) in
  C.create_exn ~name:"kernel_step_top" (Kernel.hierarchical scope)
;;

let allow : Timer_lint.Allowance.t list =
  let arm_known =
    "mux2(_, uresize(mux2(_, 2, _ +: 1), 25), mux2(_, uresize(arm, 25) +: uresize(_ -: \
     phase, 25) +: uresize(mux2(_, 2, _ +: 1), 25), uresize(arm, 25) +: uresize(mux2(_, \
     2, _ +: 1), 25))) <: 0x800000"
  in
  [ { name = "phase_is_now_minus_t"
    ; circuit = "kernel_step"
    ; compare = "msb(phase)"
    ; fault = Not_a_difference "phase"
    ; reason = "the port is the core's now - t, so its sign is that difference's"
    }
  ; { name = "stall_is_minus_phase"
    ; circuit = "kernel_step"
    ; compare = arm_known
    ; fault = Unsigned_difference "mux2(msb(phase), 0, phase) -: phase"
    ; reason =
        "released is 0 where phase is negative and phase otherwise, so the stall is \
         -phase or 0, never negative"
    }
  ; { name = "stall_below_half"
    ; circuit = "kernel_step"
    ; compare = arm_known
    ; fault =
        May_wrap
          "uresize(arm, 25) +: uresize(mux2(msb(phase), 0, phase) -: phase, 25) +: \
           uresize(mux2(_, 2, _ +: 1), 25)"
    ; reason =
        "released - phase is 0 or -phase, at most 2^23, and cycles at most 32, so the \
         sum of the three stays below 2^25"
    }
  ]
;;

let%expect_test "every compare of timer values in the core and the kernel's step" =
  List.iter Engine.Memory.all ~f:(fun memory ->
    print_s [%message (memory : Engine.Memory.t)];
    Timer_lint.print ~allow (circuits (engine ~memory)));
  Timer_lint.print ~allow (circuits kernel);
  [%expect
    {|
    (memory Flops)
    (circuits (engine_top data_memory engine program_memory solo host_fifo))
    (engine
     (((at (deadline_late)) (compare "(now -: t) ==: 0")
       (verdict (Safe Difference_against_constant)))
      ((at (deadline_late)) (compare "msb(now -: t)")
       (verdict (Safe Difference_against_constant)))
      ((at (deadline_ready)) (compare "msb(now -: t)")
       (verdict (Safe Difference_against_constant)))))
    (memory Ihp_sram)
    (circuits (engine_top data_memory sram_macro engine solo host_fifo))
    (engine
     (((at (deadline_late)) (compare "(now -: t) ==: 0")
       (verdict (Safe Difference_against_constant)))
      ((at (deadline_late)) (compare "msb(now -: t)")
       (verdict (Safe Difference_against_constant)))
      ((at (deadline_ready)) (compare "msb(now -: t)")
       (verdict (Safe Difference_against_constant)))))
    (circuits (kernel_step_top kernel_step))
    (kernel_step
     (((at (next_arm next_arm_known next_phase)) (compare "msb(phase)")
       (verdict
        (Allowed
         ((phase_is_now_minus_t
           "the port is the core's now - t, so its sign is that difference's")))))
      ((at (next_arm_known))
       (compare
        "mux2(_, uresize(mux2(_, 2, _ +: 1), 25), mux2(_, uresize(arm, 25) +: uresize(_ -: phase, 25) +: uresize(mux2(_, 2, _ +: 1), 25), uresize(arm, 25) +: uresize(mux2(_, 2, _ +: 1), 25))) <: 0x800000")
       (verdict
        (Allowed
         ((stall_below_half
           "released - phase is 0 or -phase, at most 2^23, and cycles at most 32, so the sum of the three stays below 2^25")
          (stall_is_minus_phase
           "released is 0 where phase is negative and phase otherwise, so the stall is -phase or 0, never negative")))))))
    |}]
;;

(* The kernel's count of cycles since [capture_arm] as it was before 2026-09-26, summed in
   24 bits, next to the fix, the same count tested other ways, and the other shapes a
   compare of timer values takes. *)
module Shapes = struct
  module I = struct
    type 'a t =
      { now : 'a [@bits Isa.timer_bits]
      ; t : 'a [@bits Isa.timer_bits]
      ; arm : 'a [@bits Isa.timer_bits]
      ; cycles : 'a [@bits Isa.timer_bits]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { wrapped_known : 'a
      ; wide_known : 'a
      ; wrapped_threshold : 'a
      ; signed_known : 'a
      ; wider_signed_known : 'a
      ; stalled_known : 'a
      ; status : 'a [@bits 2]
      ; released : 'a
      ; before : 'a
      ; ahead : 'a
      ; due : 'a
      ; sign_extended : 'a [@bits Isa.timer_bits + 1]
      ; reversed : 'a [@bits Isa.timer_bits]
      }
    [@@deriving hardcaml]
  end

  let create (i : Signal.t I.t) =
    let open Signal in
    let limit = 1 lsl (Isa.timer_bits - 1) in
    let wide x = uresize x ~width:(Isa.timer_bits + 1) in
    let wider x = uresize x ~width:(Isa.timer_bits + 2) in
    { O.wrapped_known = i.arm +: i.cycles <:. limit
    ; wide_known = wide i.arm +: wide i.cycles <:. limit
    ; wrapped_threshold = msb (i.arm +: i.cycles -:. limit)
    ; signed_known = wide i.arm +: wide i.cycles <+. limit
    ; wider_signed_known = wider i.arm +: wider i.cycles <+. limit
    ; stalled_known = wide (i.now -: i.t) +: wide i.cycles <:. limit
    ; status = msb (i.arm +: i.cycles) @: msb (i.now -: i.t)
    ; released = i.now -: i.t >=+. 0
    ; before = i.now <: i.t
    ; ahead = i.now <+ i.t
    ; due = i.t +: i.cycles ==: i.now
    ; sign_extended = sresize (i.now -: i.t) ~width:(Isa.timer_bits + 1)
    ; reversed = reverse i.now
    }
  ;;
end

let%expect_test "the lint flags the wrapped count, however tested, and passes its fix" =
  let module C = Circuit.With_interface (Shapes.I) (Shapes.O) in
  Timer_lint.print [ C.create_exn ~name:"shapes" Shapes.create ];
  [%expect
    {|
    (circuits (shapes))
    (shapes
     (((at (ahead)) (compare "now <+ t")
       (verdict (Flagged ((Two_sided "now <+ t")))))
      ((at (before)) (compare "now <: t")
       (verdict (Flagged ((Unsigned_timer now) (Unsigned_timer t)))))
      ((at (due)) (compare "(t +: cycles) ==: now")
       (verdict
        (Flagged ((May_wrap "t +: cycles") (Two_sided "(t +: cycles) ==: now")))))
      ((at (released)) (compare "(now -: t) <+ 0")
       (verdict (Safe Difference_against_constant)))
      ((at (signed_known))
       (compare "(uresize(arm, 25) +: uresize(cycles, 25)) <+ 8388608")
       (verdict
        (Flagged ((Signed_overflow "uresize(arm, 25) +: uresize(cycles, 25)")))))
      ((at (stalled_known))
       (compare "(uresize(now -: t, 25) +: uresize(cycles, 25)) <: 0x800000")
       (verdict (Flagged ((Unsigned_difference "now -: t")))))
      ((at (status)) (compare "msb(arm +: cycles)")
       (verdict (Flagged ((May_wrap "arm +: cycles")))))
      ((at (status)) (compare "msb(now -: t)")
       (verdict (Safe Difference_against_constant)))
      ((at (wide_known))
       (compare "(uresize(arm, 25) +: uresize(cycles, 25)) <: 0x800000")
       (verdict (Safe Wide_sum)))
      ((at (wider_signed_known))
       (compare "(uresize(arm, 26) +: uresize(cycles, 26)) <+ 8388608")
       (verdict (Safe Wide_sum)))
      ((at (wrapped_known)) (compare "(arm +: cycles) <: 0x800000")
       (verdict (Flagged ((May_wrap "arm +: cycles")))))
      ((at (wrapped_threshold)) (compare "msb(arm +: cycles -: 0x800000)")
       (verdict (Flagged ((May_wrap "arm +: cycles")))))))
    |}]
;;
