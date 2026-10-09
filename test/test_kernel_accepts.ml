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
      (List.map Library.certified ~f:(fun c -> c, None)
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
   one pin at one reached row of [c]'s table. *)
let tamper_edges ?(spacing = uart_bits) (c : Certified.t) =
  let config, words, table = table ~spacing c in
  let refused table =
    Kernel.rejections ~config ~words ~spacing table
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
  print_s [%message c.name ~untampered_refused:(refused table : bool)];
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
       if Bits.to_bool p.fresh then [] else [ { p with fresh = Bits.vdd } ]))
;;

let%expect_test "an edge bound tighter than the rows before it is refused" =
  tamper_edges (Certified.find_exn "uart_tx");
  [%expect
    {|
    (uart_tx (untampered_refused false))
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

(* An end the timer cannot hold makes the whole range, as the timer wraps; pc 0's row is
   always the whole range, so these are pc 1's. *)
let%expect_test "a phase or an arm count at the timer's ends" =
  let program = Asm.assemble "    halt\n" |> ok_exn in
  let base =
    List.hd_exn (Analyser.analyse ~config:Program_config.default program.instructions)
  in
  List.iter
    [ -half, 0; -half - 1, 0; 0, half - 1; 0, half ]
    ~f:(fun (lo, hi) ->
      let row =
        (Kernel.Table.of_analyser
           [ { base with pc = 1; phase = { lo = Some lo; hi = Some hi } } ]).(1)
      in
      print_s
        [%message
          ""
            ~phase:((lo, hi) : int * int)
            ~row:
              ((Bits.to_signed_int row.phase_lo, Bits.to_signed_int row.phase_hi)
               : int * int)]);
  List.iter
    [ 0, 5; 5, half - 1; 5, half ]
    ~f:(fun (lo, hi) ->
      let row =
        (Kernel.Table.of_analyser
           [ { base with pc = 1; since_arm = Some { lo = Some lo; hi = Some hi } } ]).(1)
      in
      print_s
        [%message
          ""
            ~arm:((lo, hi) : int * int)
            ~row:
              ((Bits.to_unsigned_int row.arm_lo, Bits.to_unsigned_int row.arm_hi)
               : int * int)]);
  [%expect
    {|
    ((phase (-8388608 0)) (row (-8388608 0)))
    ((phase (-8388609 0)) (row (-8388608 8388607)))
    ((phase (0 8388607)) (row (0 8388607)))
    ((phase (0 8388608)) (row (-8388608 8388607)))
    ((arm (0 5)) (row (0 5)))
    ((arm (5 8388607)) (row (5 8388607)))
    ((arm (5 8388608)) (row (0 16777215)))
    |}]
;;

(* The analyser's rows bound no pin, so only [Kernel.Table.with_edges]'s keep a spacing. *)
let%expect_test "a table with no edge bounds keeps no spacing" =
  let config, words, table = table (Certified.find_exn "uart_tx") in
  print_s
    [%message
      "" ~_:(Kernel.check ~spacing:uart_bits ~config ~words table : unit Or_error.t)];
  [%expect
    {|
    (Error
     ("rows the kernel rejects"
      (rejected
       (((pc 1) (fails ("a spaced"))) ((pc 6) (fails ("a spaced")))
        ((pc 9) (fails ("a spaced"))) ((pc 12) (fails ("a spaced")))))))
    |}]
;;

(* beside test_kernel's: a pin past the pin space, and a slope with no offset *)
let%expect_test "a spacing is checked only for pins and tables it is proved for" =
  let c = Certified.find_exn "uart_tx" in
  let config, words, table = table ~spacing:uart_bits c in
  let check ?(table = table) spacing =
    print_s
      [%message "" ~_:(Kernel.check ~spacing ~config ~words table : unit Or_error.t)]
  in
  check { uart_bits with a = Isa.pin_space };
  check { uart_bits with b = Isa.pin_space };
  let sloped = Array.copy table in
  sloped.(5) <- { (sloped.(5)) with slope = Bits.one Isa.timer_bits };
  check ~table:sloped uart_bits;
  [%expect
    {|
    (Error
     "edges are spaced only for two pins, Manchester off and a table of intervals")
    (Error
     "edges are spaced only for two pins, Manchester off and a table of intervals")
    (Error
     "edges are spaced only for two pins, Manchester off and a table of intervals")
    |}]
;;

(* An unreached row holds nothing, so a step into one fails on every bound it can. *)
let%expect_test "a row that steps into an unreached row is refused" =
  let config, words, table = table (Certified.find_exn "uart_tx") in
  let table = Array.copy table in
  table.(3) <- table.(Array.length table - 1);
  print_s
    [%message "" ~_:(Kernel.rejections ~config ~words table : Kernel.Rejection.t list)];
  [%expect
    {| (((pc 2) (fails ("next phase" "next period" "next x" "next y" "next arm")))) |}]
;;

(* Whether the word at an entry writes [pin], side-set first, as [Pins.write] wraps runs;
   followed apart from the kernel's [Watched]. *)
let writes (c : Program_config.t) (spec : Kernel.Spacing.Spec.t) ~pin (i : Isa.t) =
  let in_run ~base ~count =
    List.exists (List.range 0 count) ~f:(fun k -> (base + k) % Isa.pin_space = pin)
  in
  let takes =
    if spec.dirs
    then pin >= Isa.first_bidir_pin && pin < Isa.num_pins
    else pin >= Isa.first_output_pin && pin < Isa.pin_space
  in
  let to_pins (dest : [ `Pins | `Pindirs ]) =
    Bool.equal
      spec.dirs
      (match dest with
       | `Pins -> false
       | `Pindirs -> true)
  in
  takes
  &&
  match i with
  | Jmp _ -> false
  | Op { op; _ } ->
    (Bool.equal c.side_set_pindirs spec.dirs
     && in_run ~base:c.side_set_base ~count:c.side_set_count)
    ||
      (match op with
      | Set { dest = Pins; _ } ->
        to_pins `Pins && in_run ~base:c.set_base ~count:c.set_count
      | Set { dest = Pindirs; _ } ->
        to_pins `Pindirs && in_run ~base:c.set_base ~count:c.set_count
      | Out { dest = Pins; count } -> to_pins `Pins && in_run ~base:c.out_base ~count
      | Out { dest = Pindirs; count } ->
        to_pins `Pindirs && in_run ~base:c.out_base ~count
      | Mov { dest = Pins; _ } ->
        to_pins `Pins && in_run ~base:c.out_base ~count:c.out_count
      | Mov { dest = Pindirs; _ } ->
        to_pins `Pindirs && in_run ~base:c.out_base ~count:c.out_count
      | _ -> false)
;;

(* [now - t], signed, as the core reads it *)
let phase (m : Machine.t) =
  let d = (m.now - m.t) land ((1 lsl Isa.timer_bits) - 1) in
  if d >= half then d - (2 * half) else d
;;

(* What formal/pair_step.sby proves, run on the model: at every entry the core's edge
   state of each pin of the pair lies inside the row [Kernel.Table.with_edges] gives its
   pc, under random pins and host. *)
let%expect_test "the core's edges stay inside the rows the table carries them to" =
  List.iter
    [ Certified.find_exn "uart_tx", uart_bits
    ; ( Certified.find_exn "i2c_master"
      , { Kernel.Spacing.Spec.a = Firmware.scl
        ; b = Firmware.sda
        ; dirs = true
        ; hold_a = (fun ~own:_ ~other:_ -> 10)
        ; apart_a = (fun ~own:_ ~other:_ -> 3)
        ; hold_b = (fun ~own:_ ~other:_ -> 0)
        ; apart_b = (fun ~own:_ ~other:_ -> 3)
        } )
    ]
    ~f:(fun ((c : Certified.t), spec) ->
      let config, words, table = table ~spacing:spec c in
      let spacing =
        { With_valid.valid = Bits.vdd; value = Kernel.Spacing.of_spec config spec }
      in
      let instructions =
        Array.init (1 lsl Isa.pc_bits) ~f:(fun pc ->
          Isa.of_word
            ~side_set_count:config.side_set_count
            (if pc < List.length words then List.nth_exn words pc else 0)
          |> ok_exn)
      in
      let level (m : Machine.t) pin =
        ((if spec.dirs then m.pin_dir else m.pin_out) lsr pin) land 1 = 1
      in
      let entries = ref 0 in
      let outside = ref [] in
      List.iter (List.range 1 5) ~f:(fun seed ->
        let stimulus = Soundness.Stimulus.random ~seed ~cycles:3000 in
        let m = ref (Machine.create ~config ~program:words |> ok_exn) in
        (* per pin: the entry of the last counted edge, and whether it is unwritten *)
        let last_edge = Array.create ~len:2 None in
        let fresh = Array.create ~len:2 true in
        let last = ref None in
        List.iter (List.range 0 stimulus.cycles) ~f:(fun cycle ->
          let t = !m in
          let entry =
            (not t.halted)
            && t.stall = 0
            && not (Option.equal [%equal: int * int] !last (Some (cycle - 1, t.pc)))
          in
          if (not t.halted) && t.stall = 0 then last := Some (cycle, t.pc);
          let pins = [ spec.a; spec.b ] in
          if entry
          then (
            Int.incr entries;
            let edge n pin =
              { Kernel.Edge.since =
                  Bits.of_unsigned_int
                    ~width:Isa.data_bits
                    (Option.value_map last_edge.(n) ~default:0xffff ~f:(fun at ->
                       Int.min 0xffff (cycle - at)))
              ; level = Bits.of_bool (level t pin)
              ; fresh = Bits.of_bool fresh.(n)
              }
            in
            let row = table.(t.pc) in
            let holds =
              K.within
                row
                ~spacing
                ~phase:(Bits.of_signed_int ~width:Isa.timer_bits (phase t))
                ~offset:row.offset_lo
                ~period:row.period_lo
                ~x:row.x_lo
                ~y:row.y_lo
                ~arm:row.arm_lo
                ~arm_known:Bits.gnd
                ~captured:row.captured
                ~awaiting:row.awaiting
                ~a:(edge 0 spec.a)
                ~b:(edge 1 spec.b)
            in
            if not (Bits.to_bool Bits.(holds.edge_a &: holds.edge_b))
            then outside := (seed, cycle, t.pc) :: !outside);
          let next =
            Machine.step (stimulus.host cycle t) ~inputs:(stimulus.inputs cycle)
          in
          if entry
          then
            List.iteri pins ~f:(fun n pin ->
              if writes config spec ~pin instructions.(t.pc)
              then (
                if (not fresh.(n)) && Bool.( <> ) (level t pin) (level next pin)
                then last_edge.(n) <- Some cycle;
                fresh.(n) <- false));
          m := next));
      print_s
        [%message
          c.name
            ~entries:(!entries : int)
            ~outside:(List.take (List.rev !outside) 5 : (int * int * int) list)]);
  [%expect
    {|
    (uart_tx (entries 4755) (outside ()))
    (i2c_master (entries 2257) (outside ()))
    |}]
;;
