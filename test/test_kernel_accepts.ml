open! Core
open! Hardcaml
open Protocol_emulator
module K = Kernel.Make (Bits)

module Harness =
  Hardcaml_test_harness.Lws_harness.Make (Kernel.Accepts.I) (Kernel.Accepts.O)

(* uart_tx's pin held a bit, 8 cycles, at each level; the next pin is left alone *)
let uart_bits =
  { Kernel.Spacing.Spec.a = Program_config.default.set_base
  ; b = Program_config.default.set_base + 1
  ; dirs = false
  ; hold_a = (fun ~own:_ ~other:_ -> 8)
  ; apart_a = (fun ~own:_ ~other:_ -> 0)
  ; hold_b = (fun ~own:_ ~other:_ -> 0)
  ; apart_b = (fun ~own:_ ~other:_ -> 0)
  }
;;

(* The analyser's table for [c], with the pair's edge bounds under [spacing]. *)
let table ?spacing (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  let config = Asm.Program.configure program c.config in
  let words = Asm.Program.words program |> ok_exn in
  let table =
    Analyser.analyse
      ?period:c.period
      ~single_capture_edge:c.single_capture_edge
      ~config
      program.instructions
    |> Kernel.Table.of_analyser
  in
  let table =
    Option.value_map spacing ~default:table ~f:(fun spec ->
      Kernel.Table.with_edges
        ~single_capture_edge:c.single_capture_edge
        table
        ~config
        ~spacing:(Kernel.Spacing.of_spec config spec)
        ~words)
  in
  config, words, table
;;

(* formal/phase_table.sby and phase_spacing.sby read the kernel's check of a row off the
   Accepts circuit, its rows packed: on every reached row of the library it agrees with
   [K], at the row's lower bounds and with the phase one past its upper. *)
let%expect_test "the accepts circuit agrees with the kernel on the library's tables" =
  Harness.run ~create:Kernel.Accepts.hierarchical (fun (h @ local) ~inputs:i ~outputs ->
    let o = Before_and_after_edge.before_edge outputs in
    let pc_bits n = Bits.of_unsigned_int ~width:Isa.pc_bits n in
    let rows = ref 0 in
    let accepted = ref 0 in
    let within = ref 0 in
    let disagree = ref [] in
    List.iter
      (List.map Certified.all ~f:(fun c -> c, None)
       @ [ Certified.find_exn "uart_tx", Some uart_bits ])
      ~f:(fun ((c : Certified.t), spec) ->
        let config, words, table = table ?spacing:spec c in
        let words = Array.of_list words in
        let side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count in
        let fraction = Bits.of_bool (config.period_fraction <> 0) in
        let loaded =
          { With_valid.valid = Bits.of_bool (Option.is_some c.period)
          ; value =
              Bits.of_unsigned_int ~width:Isa.data_bits (Option.value c.period ~default:0)
          }
        in
        let capture =
          { Kernel.Capture.pin =
              Bits.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
          ; rising = Bits.of_bool config.capture_rising
          ; single_edge = Bits.of_bool c.single_capture_edge
          }
        in
        let spacing =
          Option.value_map spec ~default:K.no_spacing ~f:(fun spec ->
            { With_valid.valid = Bits.vdd; value = Kernel.Spacing.of_spec config spec })
        in
        let wrap_top = pc_bits config.wrap_top in
        let wrap_bottom = pc_bits config.wrap_bottom in
        i.side_set_count := side_set_count;
        i.fraction := fraction;
        i.loaded.valid := loaded.valid;
        i.loaded.value := loaded.value;
        Kernel.Capture.iter2 i.capture capture ~f:( := );
        Kernel.Spaced.iter2 i.spacing spacing ~f:( := );
        i.wrap_top := wrap_top;
        i.wrap_bottom := wrap_bottom;
        let edge = K.starting ~level:Bits.gnd in
        Kernel.Edge.iter2 i.a edge ~f:( := );
        Kernel.Edge.iter2 i.b edge ~f:( := );
        Array.iteri table ~f:(fun pc (row : Bits.t Kernel.Row.t) ->
          if Bits.(to_bool (row.phase_lo <=+ row.phase_hi))
          then (
            let word =
              Bits.of_unsigned_int
                ~width:Isa.data_bits
                (if pc < Array.length words then words.(pc) else 0)
            in
            let next_pc, target_pc =
              K.successors ~wrap_top ~wrap_bottom ~pc:(pc_bits pc) ~word
            in
            let next = table.(Bits.to_unsigned_int next_pc) in
            let target = table.(Bits.to_unsigned_int target_pc) in
            let pack = Kernel.Row.Of_bits.pack ~rev:true in
            i.pc := pc_bits pc;
            i.word := word;
            i.row := pack row;
            i.next := pack next;
            i.target := pack target;
            let expected_accepts =
              K.accepts
                ~side_set_count
                ~fraction
                ~loaded
                ~capture
                ~spacing
                ~word
                ~row
                ~next
                ~target
            in
            List.iter
              [ row.phase_lo; Bits.(row.phase_hi +:. 1) ]
              ~f:(fun phase ->
                i.phase := phase;
                i.offset := row.offset_lo;
                i.period := row.period_lo;
                i.x := row.x_lo;
                i.y := row.y_lo;
                i.arm := row.arm_lo;
                i.arm_known := Bits.vdd;
                i.captured := row.captured;
                i.awaiting := row.awaiting;
                Hardcaml_lws.Lws.cycle h;
                let expected_within =
                  K.within
                    row
                    ~spacing
                    ~phase
                    ~offset:row.offset_lo
                    ~period:row.period_lo
                    ~x:row.x_lo
                    ~y:row.y_lo
                    ~arm:row.arm_lo
                    ~arm_known:Bits.vdd
                    ~captured:row.captured
                    ~awaiting:row.awaiting
                    ~a:edge
                    ~b:edge
                  |> Kernel.Holds.to_list
                  |> Bits.reduce ~f:Bits.( &: )
                in
                let agrees =
                  List.for_all2_exn
                    [ !(o.accepts)
                    ; !(o.within)
                    ; !(o.starts_open)
                    ; !(o.next_pc)
                    ; !(o.target_pc)
                    ]
                    [ expected_accepts
                    ; expected_within
                    ; K.starts_open row ~spacing
                    ; next_pc
                    ; target_pc
                    ]
                    ~f:Bits.equal
                in
                if not agrees then disagree := (c.name, pc) :: !disagree;
                Int.incr rows;
                if Bits.to_bool !(o.accepts) then Int.incr accepted;
                if Bits.to_bool !(o.within) then Int.incr within);
            ()));
        ());
    print_s
      [%message
        ""
          ~rows:(!rows : int)
          ~accepted:(!accepted : int)
          ~within:(!within : int)
          ~disagree:(List.rev !disagree : (string * int) list)]);
  [%expect {| ((rows 2668) (accepted 2668) (within 1557) (disagree ())) |}]
;;

(* What [formal/pair_step.sby] proves on the RTL, that a row's edge bounds carry to the
   rows after it, the kernel checks of each row; so a bound made one step tighter than
   every way in brings is refused at a row before it. Each tamper is one bit's bound of
   one pin at one row of uart_tx's table. *)
let%expect_test "an edge bound tighter than the rows before it is refused" =
  let config, words, table = table ~spacing:uart_bits (Certified.find_exn "uart_tx") in
  let refused table =
    Kernel.rejections ~config ~words ~spacing:uart_bits table
    |> List.exists ~f:(fun (r : Kernel.Rejection.t) ->
      List.exists r.fails ~f:(String.is_substring ~substring:"edge"))
  in
  (* the highest mark a row may hold, which saturates *)
  let mark_max =
    Bits.of_signed_int
      ~width:Kernel.Held.port_widths.mark
      ((1 lsl (Isa.timer_bits - 1)) + 0xffff)
  in
  let tampers =
    [ ( "may"
      , fun (h : Bits.t Kernel.Held.t) ->
          Option.some_if (Bits.to_bool h.may) { h with may = Bits.gnd } )
    ; ( "since"
      , fun h ->
          Option.some_if
            (Bits.to_bool h.may && not (Bits.equal h.since (Bits.ones Isa.data_bits)))
            { h with since = Bits.(h.since +:. 1) } )
    ; ( "mark"
      , fun h ->
          Option.some_if
            (Bits.to_bool h.may && not (Bits.equal h.mark mark_max))
            { h with mark = Bits.(h.mark +:. 1) } )
    ]
  in
  let pins =
    [ ( (fun (r : Bits.t Kernel.Row.t) -> r.a)
      , fun (r : Bits.t Kernel.Row.t) a -> { r with a } )
    ; ((fun r -> r.b), fun r b -> { r with b })
    ]
  in
  let tampered_rows ~f =
    List.concat_mapi (Array.to_list table) ~f:(fun pc row ->
      if Bits.(to_bool (row.phase_lo <=+ row.phase_hi))
      then
        List.concat_map pins ~f:(fun (get, set) ->
          List.map
            (f (get row))
            ~f:(fun pin ->
              let table = Array.copy table in
              table.(pc) <- set row pin;
              table))
      else [])
  in
  let report name tables =
    print_s
      [%message
        name
          ~tampered:(List.length tables : int)
          ~refused:(List.count tables ~f:refused : int)]
  in
  print_s [%message "" ~untampered_refused:(refused table : bool)];
  List.iter tampers ~f:(fun (name, tamper) ->
    report
      name
      (tampered_rows ~f:(fun (p : Bits.t Kernel.Pin.t) ->
         [ Option.map (tamper p.at0) ~f:(fun at0 -> { p with at0 })
         ; Option.map (tamper p.at1) ~f:(fun at1 -> { p with at1 })
         ]
         |> List.filter_opt)));
  report
    "fresh"
    (tampered_rows ~f:(fun (p : Bits.t Kernel.Pin.t) ->
       if Bits.to_bool p.fresh then [] else [ { p with fresh = Bits.vdd } ]));
  [%expect
    {|
    (untampered_refused false)
    (may (tampered 52) (refused 48))
    (since (tampered 18) (refused 18))
    (mark (tampered 48) (refused 48))
    (fresh (tampered 13) (refused 13))
    |}]
;;

(* the timer's signed values are [-half, half - 1] *)
let half = 1 lsl (Isa.timer_bits - 1)

let%expect_test "an offset or a slope the timer cannot hold is dropped" =
  List.iter
    [ 1, -half, half - 1; 1, -half - 1, 0; 1, 0, half; 0, 0, 0; half, 0, 0; -half, 0, 0 ]
    ~f:(fun (slope, lo, hi) ->
      print_s
        [%message
          (slope : int)
            (lo : int)
            (hi : int)
            ~kept:
              (Kernel.Table.offset_bounds ~slope { lo = Some lo; hi = Some hi }
               : (int * int * int) option)]);
  [%expect
    {|
    ((slope 1) (lo -8388608) (hi 8388607) (kept ((1 -8388608 8388607))))
    ((slope 1) (lo -8388609) (hi 0) (kept ()))
    ((slope 1) (lo 0) (hi 8388608) (kept ()))
    ((slope 0) (lo 0) (hi 0) (kept ()))
    ((slope 8388608) (lo 0) (hi 0) (kept ()))
    ((slope -8388608) (lo 0) (hi 0) (kept ((-8388608 0 0))))
    |}]
;;
