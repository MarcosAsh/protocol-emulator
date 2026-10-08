open! Core
open! Hardcaml
open Kernel_spacing

module Make (Timer : Engine.Timer) = struct
  let timer_bits = Timer.timer_bits

  (* an instruction's cycles, [1 lsl Isa.delay_bits] at most, stay below [arm_limit] *)
  let () =
    if timer_bits < Isa.delay_bits + 2
    then
      raise_s [%message "BUG: the timer is too narrow for the kernel" (timer_bits : int)]
  ;;

  (* wide enough for a count of cycles, 16 bits, less a phase *)
  let mark_bits = Int.max timer_bits (Isa.data_bits + 1) + 2

  module Held = struct
    type 'a t =
      { may : 'a
      ; since : 'a [@bits Isa.data_bits]
      ; mark : 'a [@bits mark_bits]
      }
    [@@deriving hardcaml]
  end

  module Pin = struct
    type 'a t =
      { at0 : 'a Held.t
      ; at1 : 'a Held.t
      ; fresh : 'a
      }
    [@@deriving hardcaml]
  end

  module Row = struct
    type 'a t =
      { phase_lo : 'a [@bits timer_bits]
      ; phase_hi : 'a [@bits timer_bits]
      ; slope : 'a [@bits timer_bits]
      ; offset_lo : 'a [@bits timer_bits]
      ; offset_hi : 'a [@bits timer_bits]
      ; period_lo : 'a [@bits Isa.data_bits]
      ; period_hi : 'a [@bits Isa.data_bits]
      ; x_lo : 'a [@bits Isa.data_bits]
      ; x_hi : 'a [@bits Isa.data_bits]
      ; y_lo : 'a [@bits Isa.data_bits]
      ; y_hi : 'a [@bits Isa.data_bits]
      ; arm_lo : 'a [@bits timer_bits]
      ; arm_hi : 'a [@bits timer_bits]
      ; captured : 'a
      ; awaiting : 'a
      ; a : 'a Pin.t
      ; b : 'a Pin.t
      }
    [@@deriving hardcaml]
  end

  module Capture = struct
    type 'a t =
      { pin : 'a [@bits Isa.Field.wait_index.width]
      ; rising : 'a
      ; single_edge : 'a
      }
    [@@deriving hardcaml]
  end

  module Holds = struct
    type 'a t =
      { phase : 'a
      ; offset : 'a
      ; period : 'a
      ; x : 'a
      ; y : 'a
      ; arm : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; edge_a : 'a
      ; edge_b : 'a
      }
    [@@deriving hardcaml]
  end

  module Conjuncts = struct
    type 'a t =
      { in_time : 'a
      ; wide_a : 'a
      ; wide_b : 'a
      ; next : 'a Holds.t
      ; target : 'a Holds.t
      }
    [@@deriving hardcaml]
  end

  module Step = struct
    type 'a t =
      { next_phase : 'a [@bits timer_bits]
      ; bounded : 'a
      ; may_carry : 'a
      ; next_period : 'a [@bits Isa.data_bits]
      ; period_known : 'a
      ; next_x : 'a [@bits Isa.data_bits]
      ; x_known : 'a
      ; next_y : 'a [@bits Isa.data_bits]
      ; y_known : 'a
      ; taken : 'a
      ; taken_known : 'a
      ; next_arm : 'a [@bits timer_bits]
      ; next_arm_known : 'a
      ; next_captured : 'a
      ; next_awaiting : 'a
      ; capture_bounded : 'a
      ; next_a : 'a Edge.t
      ; next_b : 'a Edge.t
      ; wide_a : 'a
      ; wide_b : 'a
      ; halts : 'a
      }
    [@@deriving hardcaml]
  end
end
