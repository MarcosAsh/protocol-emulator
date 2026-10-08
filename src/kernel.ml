open! Core
open! Hardcaml
include Kernel_spacing

module Make_timer (Timer : Engine.Timer) = struct
  module Rows = Kernel_rows.Make (Timer)
  include Rows
  module Make = Kernel_comb.Make (Rows)
  module K = Make (Bits)
  module Table = Kernel_table.Make (Rows)

  module Rejection = struct
    type t =
      { pc : int
      ; fails : string list
      }
    [@@deriving sexp_of]
  end

  (* Whether the row at pc 0 starts open, and the pcs whose conjuncts fail. *)
  let verdicts
    ?period
    ?(single_capture_edge = false)
    ?spacing:spec
    ~(config : Program_config.t)
    ~words
    (table : Table.t)
    =
    let size = 1 lsl Isa.pc_bits in
    let words = Array.of_list words in
    let word pc =
      Bits.of_unsigned_int
        ~width:Isa.data_bits
        (if pc < Array.length words then words.(pc) else 0)
    in
    let side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count in
    let fraction = Bits.of_bool (config.period_fraction <> 0) in
    let loaded =
      { With_valid.valid = Bits.of_bool (Option.is_some period)
      ; value = Bits.of_unsigned_int ~width:Isa.data_bits (Option.value period ~default:0)
      }
    in
    let capture =
      { Capture.pin =
          Bits.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
      ; rising = Bits.of_bool config.capture_rising
      ; single_edge = Bits.of_bool single_capture_edge
      }
    in
    let spacing =
      Option.value_map spec ~default:K.no_spacing ~f:(fun spec ->
        { With_valid.valid = Bits.vdd; value = Spacing.of_spec config spec })
    in
    let starts_open = Bits.to_bool (K.starts_open table.(0) ~spacing) in
    let pc_bits n = Bits.of_unsigned_int ~width:Isa.pc_bits n in
    let wrap_top = pc_bits config.wrap_top in
    let wrap_bottom = pc_bits config.wrap_bottom in
    let names =
      let way name = Holds.map Holds.port_names ~f:(fun field -> name ^ " " ^ field) in
      { Conjuncts.in_time = "in time"
      ; wide_a = "a spaced"
      ; wide_b = "b spaced"
      ; next = way "next"
      ; target = way "target"
      }
    in
    let rejected =
      List.filter_map (List.range 0 size) ~f:(fun pc ->
        let w = word pc in
        let next, target = K.successors ~wrap_top ~wrap_bottom ~pc:(pc_bits pc) ~word:w in
        let row pc = table.(Bits.to_unsigned_int pc) in
        let conjuncts =
          K.conjuncts
            ~side_set_count
            ~fraction
            ~loaded
            ~capture
            ~spacing
            ~word:w
            ~row:table.(pc)
            ~next:(row next)
            ~target:(row target)
        in
        let fails =
          List.filter_map
            (Conjuncts.to_list (Conjuncts.zip names conjuncts))
            ~f:(fun (name, holds) -> Option.some_if (not (Bits.to_bool holds)) name)
        in
        Option.some_if (not (List.is_empty fails)) { Rejection.pc; fails })
    in
    starts_open, rejected
  ;;

  let rejections ?period ?single_capture_edge ?spacing ~config ~words table =
    snd (verdicts ?period ?single_capture_edge ?spacing ~config ~words table)
  ;;

  let check
    ?period
    ?single_capture_edge
    ?spacing:spec
    ~(config : Program_config.t)
    ~words
    (table : Table.t)
    =
    let starts_open, rejected =
      verdicts ?period ?single_capture_edge ?spacing:spec ~config ~words table
    in
    (* what formal/phase_spacing.sby proves the spacing for *)
    let proved_spacing =
      Option.for_all spec ~f:(fun { a; b; _ } ->
        a <> b
        && a < Isa.pin_space
        && b < Isa.pin_space
        && (not config.manchester)
        && Array.for_all table ~f:(fun r ->
          Bits.to_bool Bits.(K.offset_is_full r &: (r.slope ==:. 0))))
    in
    match starts_open, rejected with
    | _ when not proved_spacing ->
      Or_error.error_s
        [%message
          "edges are spaced only for two pins, Manchester off and a table of intervals"]
    | true, [] -> Ok ()
    | false, _ -> Or_error.error_s [%message "the row at pc 0 must be the full range"]
    | true, rejected ->
      Or_error.error_s [%message "rows the kernel rejects" (rejected : Rejection.t list)]
  ;;

  module I = struct
    type 'a t =
      { side_set_count : 'a [@bits 2]
      ; fraction : 'a
      ; loaded : 'a With_valid.t [@bits Isa.data_bits]
      ; capture : 'a Capture.t
      ; spacing : 'a Spaced.t
      ; word : 'a [@bits Isa.data_bits]
      ; phase : 'a [@bits timer_bits]
      ; period : 'a [@bits Isa.data_bits]
      ; x : 'a [@bits Isa.data_bits]
      ; y : 'a [@bits Isa.data_bits]
      ; arm : 'a [@bits timer_bits]
      ; arm_known : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; a : 'a Edge.t
      ; b : 'a Edge.t
      ; data_a : 'a
      ; data_b : 'a
      }
    [@@deriving hardcaml]
  end

  module O = Step

  let create (_scope : Scope.t) (i : Signal.t I.t) =
    let module K = Make (Signal) in
    K.step
      ~side_set_count:i.side_set_count
      ~fraction:i.fraction
      ~loaded:i.loaded
      ~capture:i.capture
      ~spacing:i.spacing
      ~word:i.word
      ~phase:i.phase
      ~period:i.period
      ~x:i.x
      ~y:i.y
      ~arm:i.arm
      ~arm_known:i.arm_known
      ~captured:i.captured
      ~awaiting:i.awaiting
      ~a:i.a
      ~b:i.b
      ~data_a:i.data_a
      ~data_b:i.data_b
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"kernel_step" create i
  ;;

  module Accepts = struct
    module I = struct
      type 'a t =
        { side_set_count : 'a [@bits 2]
        ; fraction : 'a
        ; loaded : 'a With_valid.t [@bits Isa.data_bits]
        ; capture : 'a Capture.t
        ; spacing : 'a Spaced.t
        ; wrap_top : 'a [@bits Isa.pc_bits]
        ; wrap_bottom : 'a [@bits Isa.pc_bits]
        ; pc : 'a [@bits Isa.pc_bits]
        ; word : 'a [@bits Isa.data_bits]
        ; row : 'a [@bits Row.sum_of_port_widths]
        ; next : 'a [@bits Row.sum_of_port_widths]
        ; target : 'a [@bits Row.sum_of_port_widths]
        ; phase : 'a [@bits timer_bits]
        ; offset : 'a [@bits timer_bits]
        ; period : 'a [@bits Isa.data_bits]
        ; x : 'a [@bits Isa.data_bits]
        ; y : 'a [@bits Isa.data_bits]
        ; arm : 'a [@bits timer_bits]
        ; arm_known : 'a
        ; captured : 'a
        ; awaiting : 'a
        ; a : 'a Edge.t
        ; b : 'a Edge.t
        }
      [@@deriving hardcaml]
    end

    module O = struct
      type 'a t =
        { next_pc : 'a [@bits Isa.pc_bits]
        ; target_pc : 'a [@bits Isa.pc_bits]
        ; accepts : 'a
        ; within : 'a
        ; starts_open : 'a
        }
      [@@deriving hardcaml]
    end

    let create (_scope : Scope.t) (i : Signal.t I.t) =
      let module K = Make (Signal) in
      let row = Row.Of_signal.unpack ~rev:true i.row in
      let next_pc, target_pc =
        K.successors ~wrap_top:i.wrap_top ~wrap_bottom:i.wrap_bottom ~pc:i.pc ~word:i.word
      in
      { O.next_pc
      ; target_pc
      ; accepts =
          K.accepts
            ~side_set_count:i.side_set_count
            ~fraction:i.fraction
            ~loaded:i.loaded
            ~capture:i.capture
            ~spacing:i.spacing
            ~word:i.word
            ~row
            ~next:(Row.Of_signal.unpack ~rev:true i.next)
            ~target:(Row.Of_signal.unpack ~rev:true i.target)
      ; within =
          K.within
            row
            ~spacing:i.spacing
            ~phase:i.phase
            ~offset:i.offset
            ~period:i.period
            ~x:i.x
            ~y:i.y
            ~arm:i.arm
            ~arm_known:i.arm_known
            ~captured:i.captured
            ~awaiting:i.awaiting
            ~a:i.a
            ~b:i.b
          |> Holds.to_list
          |> Signal.reduce ~f:Signal.( &: )
      ; starts_open = K.starts_open row ~spacing:i.spacing
      }
    ;;

    let hierarchical ?instance scope i =
      let module H = Hierarchy.In_scope (I) (O) in
      H.hierarchical ?instance ~scope ~name:"kernel_accepts" create i
    ;;
  end
end

include Make_timer (Isa)
