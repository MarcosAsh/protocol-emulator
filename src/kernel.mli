(** Checks a timing certificate one instruction at a time. A certificate is a row per pc:
    the phase [now - t] on entry as a signed interval, [p], [x] and [y] as unsigned ones,
    and the phase less a multiple of [x] as another signed interval. The analyser proposes
    it and is not trusted.

    [formal/phase_step.sv] proves the core moves from one entry to the next as [step]
    says, for any program; [test/test_kernel.ml] proves by SAT that [accepts] keeps [step]
    inside the rows and a deadline wait at or below zero. SAT cannot follow a
    multiplication, so that proof takes the offsets as free inputs under axioms of modular
    arithmetic, which it states and rests on. So a program whose rows all pass, with the
    full range at pc 0, never misses a deadline. An empty row is a pc never reached; the
    full range is an unknown phase. Rows also bound a pair of pins' edges, so that with a
    [Spacing] no edge comes too soon: [formal/phase_spacing.sby] proves that on the RTL
    for tables of intervals, taking the one-run theorem, the step lemmas and
    [pair_step.sby]'s as their own runs prove them.

    The parts: [Kernel_spacing] (the watched pair), [Kernel_rows] (the records),
    [Kernel_comb] (the step and its conjuncts over any gates), [Kernel_table] (the rows
    software builds) and this module (the check and its circuits). The signature and the
    records' docs are in [Kernel_intf]: [Rows], then [M(...).S]. *)

open! Core

include module type of struct
  include Kernel_spacing
end

(** The kernel for a timer of any width; the chip's, [Isa.timer_bits] wide, is below. *)
module Make_timer (Timer : Engine.Timer) : Kernel_intf.M(Kernel_rows.Make(Timer)).S

include Kernel_intf.M(Kernel_rows.Make(Isa)).S
