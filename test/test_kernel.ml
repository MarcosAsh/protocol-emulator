open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator

(* [Comb_gates], with each product built once: the kernel's product of a slope and the
   value [set x] loads and the proof's product of the same two vectors are then the same
   gates. They are the same function either way, but SAT cannot see that two multipliers
   agree. *)
module G = struct
  include Comb_gates

  let products = Hashtbl.create (module String)

  let ( *+ ) a b =
    let key =
      List.map [ a; b ] ~f:(fun bits ->
        List.map bits ~f:(fun bit -> Basic_gates.Uid.to_string (Basic_gates.uid bit))
        |> String.concat ~sep:" ")
      |> String.concat ~sep:" * "
    in
    Hashtbl.find_or_add products key ~default:(fun () -> Comb_gates.( *+ ) a b)
  ;;
end

module K = Kernel.Make (G)
module Decoder = Decoder.Make (G)
module Opcode = Isa.Opcode.Make_comb (G)
module Wait_source = Isa.Wait_source.Make_comb (G)
module Jmp_cond = Isa.Jmp_cond.Make_comb (G)
module Set_dest = Isa.Set_dest.Make_comb (G)

let row_input name =
  Kernel.Row.map2 Kernel.Row.port_names Kernel.Row.port_widths ~f:(fun field width ->
    G.input (name ^ "_" ^ field) width)
;;

let all (h : _ Kernel.Holds.t) = Kernel.Holds.to_list h |> G.reduce ~f:G.( &: )
let all_but_offset (h : _ Kernel.Holds.t) = all { h with offset = G.vdd }

(* That an accepted row maps into its successors and meets its deadline, as two claims,
   which SAT finds far easier than one: [bounds], that the conjuncts other than the offset
   keep the core inside every other bound of the row it steps to and a deadline wait in
   time, and [offset], that the offset conjuncts keep its offset inside that row's.
   [accepts] is every conjunct, so it implies both. Each is proved one of [cases] at a
   time. *)
type claims =
  { cases : G.t list
  ; bounds : G.t
  ; offset : G.t
  }

(* The kernel accepts under the single-edge assumption as the input [single_edge] sets it,
   and the step takes [step_edge] of that. *)
let accepted_rows_hold ~step_edge =
  let side_set_count = G.input "side_set_count" 2 in
  let fraction = G.input "fraction" 1 in
  let loaded =
    { With_valid.valid = G.input "loads_period" 1
    ; value = G.input "loaded_period" Isa.data_bits
    }
  in
  let capture =
    { Kernel.Capture.pin = G.input "capture_pin" Isa.Field.wait_index.width
    ; rising = G.input "capture_rising" 1
    ; single_edge = G.input "single_edge" 1
    }
  in
  let word = G.input "word" Isa.data_bits in
  let phase = G.input "phase" Isa.timer_bits in
  let period = G.input "period" Isa.data_bits in
  let x = G.input "x" Isa.data_bits in
  let y = G.input "y" Isa.data_bits in
  let arm = G.input "arm" Isa.timer_bits in
  let arm_known = G.input "arm_known" 1 in
  let captured = G.input "captured" 1 in
  let awaiting = G.input "awaiting" 1 in
  let carry = G.input "carry" 1 in
  let any name width = G.input ("any_" ^ name) width in
  let row = row_input "row" in
  let next = row_input "next" in
  let target = row_input "target" in
  let s =
    K.step
      ~side_set_count
      ~fraction
      ~loaded
      ~capture:{ capture with single_edge = step_edge capture.single_edge }
      ~word
      ~phase
      ~period
      ~x
      ~y
      ~arm
      ~arm_known
      ~captured
      ~awaiting
  in
  let d = Decoder.decode ~side_set_count word in
  let is op = Opcode.is d.opcode op in
  let deadline = G.(is Wait &: Wait_source.is d.wait_source Deadline) in
  (* what the core holds at the next entry, by the step lemma; after [mov t, capture]
     that is only a range, from a cycle past the instruction up to the step *)
  let free_phase = any "phase" Isa.timer_bits in
  let cycles = G.(uresize d.delay ~width:Isa.timer_bits +:. 1) in
  let in_capture_range = G.(cycles +:. 1 <=: free_phase &: (free_phase <=: s.next_phase)) in
  let phase' =
    G.(
      mux2
        s.bounded
        (s.next_phase -: uresize (carry &: s.may_carry) ~width:Isa.timer_bits)
        free_phase)
  in
  let known k v name = G.mux2 k v (any name Isa.data_bits) in
  let x' = known s.x_known s.next_x "x" in
  (* SAT cannot follow a multiplication, so [offset], the core's [phase - row.slope * x]
     modulo the timer, and [next_offset] and [target_offset], [phase' - slope * x'] under
     each successor's slope, are free inputs, under axioms that hold of the true offsets
     in that arithmetic: after [set x, v] the offset is [phase' - slope * v]; where x is
     zero it is the phase; and with the slope the same, the offset moves as the phase does
     where x stays, and a slope further where x is one less. The proof is sound only
     because they hold. Each is stated only where the kernel needs it, which leaves it
     true and SAT finds far easier. *)
  let offset = G.input "offset" Isa.timer_bits in
  let next_offset = G.input "next_offset" Isa.timer_bits in
  let target_offset = G.input "target_offset" Isa.timer_bits in
  let set_x = G.(is Set &: Set_dest.is d.set_dest X) in
  let x_dec = G.(is Jmp &: Jmp_cond.is d.jmp_cond X_dec) in
  let steady = G.(s.bounded &: ~:deadline) in
  let moved = G.(offset +: (phase' -: phase)) in
  let axioms (r : _ Kernel.Row.t) r_offset =
    let same_slope = G.(r.slope ==: row.slope) in
    let set_value = G.uresize d.set_value ~width:(Isa.Field.set_value.width + 1) in
    G.(
      ~:set_x
      |: (r_offset ==: phase' -: sel_bottom (r.slope *+ set_value) ~width:Isa.timer_bits)
      &: (~:(steady &: s.x_known &: (x' ==: x) &: same_slope) |: (r_offset ==: moved))
      &: (~:(x_dec &: (x <>:. 0) &: (x' ==: x -:. 1) &: same_slope)
          |: (r_offset ==: moved +: row.slope)))
  in
  let lies_in' r ~offset =
    K.within
      r
      ~phase:phase'
      ~offset
      ~period:(known s.period_known s.next_period "period")
      ~x:x'
      ~y:(known s.y_known s.next_y "y")
      ~arm:s.next_arm
      ~arm_known:s.next_arm_known
      ~captured:s.next_captured
      ~awaiting:s.next_awaiting
  in
  let arrives =
    Kernel.Holds.map2
      (lies_in' target ~offset:target_offset)
      (lies_in' next ~offset:next_offset)
      ~f:(fun target next ->
        G.(
          mux2
            (is Jmp)
            (mux2 s.taken_known (mux2 s.taken target next) (target &: next))
            next))
  in
  let conjuncts =
    K.conjuncts ~side_set_count ~fraction ~loaded ~capture ~word ~row ~next ~target
  in
  let hypothesis =
    G.(
      all (K.within row ~phase ~offset ~period ~x ~y ~arm ~arm_known ~captured ~awaiting)
      &: (~:x_dec |: (x <>:. 0) |: (offset ==: phase))
      &: (side_set_count <=:. 2)
      &: ~:(s.halts)
      &: (~:(s.capture_bounded) |: in_capture_range))
  in
  (* a jump one condition at a time and an ALU instruction one destination and operation
     at a time *)
  let cases =
    let values (field : Isa.Field.t) =
      List.init (1 lsl field.width) ~f:(fun v ->
        G.(Isa.Field.select (module G) field word ==:. v))
    in
    List.concat_map Isa.Opcode.Cases.all ~f:(fun op ->
      let parts =
        match op with
        | Jmp -> values Isa.Field.jmp_cond
        | Alu ->
          List.cartesian_product (values Isa.Field.alu_dest) (values Isa.Field.alu_op)
          |> List.map ~f:(fun (dest, op) -> G.(dest &: op))
        | Wait | In | Out | Mov | Set | Sys -> [ G.vdd ]
      in
      List.map parts ~f:(fun part -> G.(is op &: part)))
  in
  { cases
  ; bounds =
      G.(
        ~:(hypothesis
           &: conjuncts.in_time
           &: all_but_offset conjuncts.next
           &: all_but_offset conjuncts.target)
        |: (~:deadline |: (phase <=+ zero Isa.timer_bits) &: all_but_offset arrives))
  ; offset =
      G.(
        ~:(hypothesis
           &: axioms next next_offset
           &: axioms target target_offset
           &: conjuncts.next.offset
           &: conjuncts.target.offset)
        |: arrives.offset)
  }
;;

let%expect_test "an accepted row maps into its successors and meets its deadline" =
  let { cases; bounds; offset } = accepted_rows_hold ~step_edge:Fn.id in
  Checked_unsat.prove "accepts => step stays in the rows" ~cases ~claim:bounds;
  Checked_unsat.prove "accepts => offset stays in the rows" ~cases ~claim:offset;
  [%expect
    {|
    (QED "accepts => step stays in the rows")
    (QED "accepts => offset stays in the rows")
    |}]
;;

(* Teeth for the single-edge assumption: a row the kernel accepts under it need not hold a
   core whose capture pin may make a second edge, which is the step without it. Any
   counterexample has the kernel assuming one edge while the core awaits it. *)
let%expect_test "the rows hold only under the single-edge assumption" =
  let { cases; bounds; _ } = accepted_rows_hold ~step_edge:(Fn.const G.gnd) in
  Checked_unsat.prove
    "accepts => step stays in the rows, with a second edge"
    ~show:[ "single_edge"; "awaiting" ]
    ~cases
    ~claim:bounds;
  [%expect
    {|
    (counterexample "accepts => step stays in the rows, with a second edge"
     (model ((awaiting 1) (single_edge 1))))
    |}]
;;

let assemble (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  program, Asm.Program.configure program c.config
;;

(* The kernel on the analyser's rows, with [at_pc_0] of the row it puts at pc 0. *)
let check ?(at_pc_0 = Fn.id) (c : Certified.t) =
  let program, config = assemble c in
  let single_capture_edge = c.single_capture_edge in
  let rows =
    Analyser.analyse ?period:c.period ~single_capture_edge ~config program.instructions
  in
  let table = Kernel.Table.of_analyser rows in
  table.(0) <- at_pc_0 table.(0);
  Kernel.check
    ?period:c.period
    ~single_capture_edge
    ~config
    ~words:(Asm.Program.words program |> ok_exn)
    table
;;

let%expect_test "the kernel on the firmware library, from the analyser's rows" =
  List.iter Certified.all ~f:(fun (c : Certified.t) ->
    let verdict = check c in
    print_s [%message c.name (verdict : unit Or_error.t)]);
  [%expect
    {|
    (uart_tx (verdict (Ok ())))
    (uart_tx16 (verdict (Ok ())))
    (uart_tx_host_rate (verdict (Ok ())))
    (uart_rx (verdict (Ok ())))
    (spi_master (verdict (Ok ())))
    (spi_slave (verdict (Ok ())))
    (i2c_master (verdict (Ok ())))
    (i2c_slave (verdict (Ok ())))
    (i2c_logger (verdict (Ok ())))
    (usb_tx (verdict (Ok ())))
    (usb_rx (verdict (Ok ())))
    (usb_device (verdict (Ok ())))
    (edge_meter (verdict (Ok ())))
    (ws2812 (verdict (Ok ())))
    (ethernet (verdict (Ok ())))
    (one_wire (verdict (Ok ())))
    (ps2 (verdict (Ok ())))
    (jtag (verdict (Ok ())))
    |}]
;;

(* At reset the phase, the offset, every register and the capture state are anything, and
   the proof of [accepts] takes the row at pc 0 to hold of them, so [Kernel.check] refuses
   a table whose row there bounds any of them: here uart_tx's, which it accepts, with one
   bound added at pc 0. *)
let%expect_test "the row at pc 0 bounds nothing" =
  let c = Certified.find_exn "uart_tx" in
  let signed n = Bits.of_signed_int ~width:Isa.timer_bits n in
  let data n = Bits.of_unsigned_int ~width:Isa.data_bits n in
  List.iter
    [ "nothing", Fn.id
    ; ("phase", fun (r : _ Kernel.Row.t) -> { r with phase_hi = signed 0 })
    ; ( "offset"
      , fun r -> { r with slope = signed 1; offset_lo = signed 0; offset_hi = signed 0 }
      )
    ; ("period", fun r -> { r with period_hi = data 0 })
    ; ("x", fun r -> { r with x_hi = data 0 })
    ; ("y", fun r -> { r with y_hi = data 0 })
    ; ("arm", fun r -> { r with arm_hi = Bits.zero Isa.timer_bits })
    ; ("captured", fun r -> { r with captured = Bits.vdd })
    ; ("awaiting", fun r -> { r with awaiting = Bits.vdd })
    ]
    ~f:(fun (bound, at_pc_0) ->
      let verdict = check c ~at_pc_0 in
      print_s [%message bound (verdict : unit Or_error.t)]);
  [%expect
    {|
    (nothing (verdict (Ok ())))
    (phase (verdict (Error "the row at pc 0 must be the full range")))
    (offset (verdict (Error "the row at pc 0 must be the full range")))
    (period (verdict (Error "the row at pc 0 must be the full range")))
    (x (verdict (Error "the row at pc 0 must be the full range")))
    (y (verdict (Error "the row at pc 0 must be the full range")))
    (arm (verdict (Error "the row at pc 0 must be the full range")))
    (captured (verdict (Error "the row at pc 0 must be the full range")))
    (awaiting (verdict (Error "the row at pc 0 must be the full range")))
    |}]
;;

(* ws2812 as it was first written, with the wait of its reset gap after the loop rather
   than in it. The line stays low as long, but each pass moves [t] 23 cycles further ahead
   of [now], so the row at the head of the loop, which has to hold its own image one pass
   on, has no bound on the phase short of the full range. Rows of intervals alone do not
   know the wait after the loop to be in time; the offset does, since the phase less 23
   times x holds still round the loop and x is zero where it falls through. *)
let ws2812_waiting_after_gap =
  let c = Certified.find_exn "ws2812" in
  { c with
    name = "ws2812_waiting_after_gap"
  ; source =
      String.substr_replace_first
        c.source
        ~pattern:"wait t\n    jmp x--, gap"
        ~with_:"jmp x--, gap\n    wait t"
  }
;;

(* [ws2812_waiting_after_gap] with the last [add t, p] of its gap loop made [add t, x]:
   each pass moves [t] ahead by an amount that changes from pass to pass, so neither the
   phase nor the phase less any multiple of x holds still round the loop. *)
let gap_adding_x =
  { ws2812_waiting_after_gap with
    name = "gap_adding_x"
  ; source =
      String.substr_replace_first
        ws2812_waiting_after_gap.source
        ~pattern:"add t, p\n    jmp x--, gap"
        ~with_:"add t, x\n    jmp x--, gap"
  }
;;

let print_rejection (c : Certified.t) =
  match check c with
  | Ok () -> ()
  | Error _ ->
    if Table_query.some_table_passes c
    then
      print_s [%message c.name "some table passes, so the analyser's rows are at fault"]
    else print_s [%message c.name "no table passes"]
;;

let%expect_test "a rejection is the kernel's or the analyser's" =
  List.iter Certified.all ~f:print_rejection;
  [%expect {| |}];
  List.iter [ ws2812_waiting_after_gap; gap_adding_x ] ~f:print_rejection;
  [%expect {| (gap_adding_x "no table passes") |}]
;;

(* The analyser's rows are one table that passes, so the query must find some for the
   firmware the kernel accepts: a receiver and a loaded period among them. *)
let%expect_test "some table passes for firmware the kernel accepts" =
  List.iter [ "uart_tx"; "uart_rx"; "ethernet"; "jtag" ] ~f:(fun name ->
    let passes = Table_query.some_table_passes (Certified.find_exn name) in
    print_s [%message name (passes : bool)]);
  [%expect
    {|
    (uart_tx (passes true))
    (uart_rx (passes true))
    (ethernet (passes true))
    (jtag (passes true))
    |}]
;;

(* Falling through [jmp x!=y] leaves x = y, so the wait timed by x after it is in time
   although x comes from the isr. *)
let%expect_test "the way through jmp x!=y knows x is y" =
  let c =
    { Certified.name = "x_is_y"
    ; source =
        {|
    start:
        mov t, now
        mov x, isr
        set y, 12
        jmp x!=y, start
        add t, x
        wait t
        jmp start
    |}
    ; config = Program_config.default
    ; period = None
    ; single_capture_edge = false
    ; no_wrap = false
    }
  in
  let verdict = check c in
  let passes = Table_query.some_table_passes c in
  print_s [%message (verdict : unit Or_error.t) (passes : bool)];
  [%expect {| ((verdict (Ok ())) (passes true)) |}]
;;

(* The library's ws2812 waits inside its gap loop instead, which holds the line low for
   the same 160 thirds and needs no offset. [accepted] is the kernel's verdict on the
   analyser's rows. *)
let%expect_test "ws2812's gap loop needs an offset, or its wait moved into the loop" =
  List.iter
    [ ws2812_waiting_after_gap; Certified.find_exn "ws2812" ]
    ~f:(fun c ->
      let intervals = Table_query.some_table_passes ~offsets:false c in
      let offsets = Table_query.some_table_passes c in
      let accepted = Result.is_ok (check c) in
      print_s [%message c.name (intervals : bool) (offsets : bool) (accepted : bool)]);
  [%expect
    {|
    (ws2812_waiting_after_gap (intervals false) (offsets true) (accepted true))
    (ws2812 (intervals true) (offsets true) (accepted true))
    |}]
;;

(* spi_slave arming the capture once sck is high, so the falling edge it answers is the
   captured one. The single-edge assumption asks that sck is still high when the arm
   issues, two cycles after the wait for it to rise releases. *)
let spi_slave_captured =
  let c = Certified.find_exn "spi_slave" in
  { c with
    name = "spi_slave_captured"
  ; source =
      String.substr_replace_first
        c.source
        ~pattern:"in pins, 1\n"
        ~with_:"in pins, 1\n    capture_arm\n"
  ; config =
      { c.config with capture_pin = Firmware.slave_sck_pin; capture_rising = false }
  ; single_capture_edge = true
  }
;;

(* the rows that write pins, as the jitter bound below counts them *)
let writes_pins (r : Analyser.Row.t) =
  Option.is_some r.flip
  || Option.is_some r.side_event
  ||
  match r.pin_event with
  | Some (Edge _) -> true
  | Some (Sample _) | None -> false
;;

module Reaction = struct
  type t =
    { pc : int
    ; at_most : int
    }
  [@@deriving sexp_of]

  (* the widest of [rows], as [table] holds them, that writes pins, has seen the captured
     edge and bounds the arm *)
  let of_rows rows ~(table : Kernel.Table.t) =
    let module Kernel_bits = Kernel.Make (Bits) in
    let arm_hi pc = Bits.to_unsigned_int table.(pc).arm_hi in
    List.filter_map rows ~f:(fun (r : Analyser.Row.t) ->
      let row = table.(r.pc) in
      Option.some_if
        (writes_pins r
         && Bits.to_bool Bits.(row.captured &: ~:(Kernel_bits.arm_is_full row)))
        r.pc)
    |> List.max_elt ~compare:(Comparable.lift Int.compare ~f:arm_hi)
    |> Option.map ~f:(fun pc -> { pc; at_most = arm_hi pc + 1 })
  ;;
end

let reaction (c : Certified.t) =
  let program, config = assemble c in
  let rows =
    Analyser.analyse
      ?period:c.period
      ~single_capture_edge:c.single_capture_edge
      ~config
      program.instructions
  in
  Reaction.of_rows rows ~table:(Kernel.Table.of_analyser rows) |> Option.value_exn
;;

(* Every row the analyser gives the library has no slope and the full offset, so each
   table is one of the tables of intervals that formal/phase_table.sby covers. The old
   ws2812's gap loop is the one that is not. *)
let%expect_test "the library's tables are rows of intervals" =
  let module Kernel_bits = Kernel.Make (Bits) in
  List.iter (Certified.all @ [ ws2812_waiting_after_gap ]) ~f:(fun (c : Certified.t) ->
    let program, config = assemble c in
    let rows =
      Analyser.analyse
        ?period:c.period
        ~single_capture_edge:c.single_capture_edge
        ~config
        program.instructions
    in
    Array.iteri (Kernel.Table.of_analyser rows) ~f:(fun pc row ->
      if Bits.to_bool Bits.(row.slope <>:. 0 |: ~:(Kernel_bits.offset_is_full row))
      then print_s [%message c.name (pc : int)]));
  [%expect
    {|
    (ws2812_waiting_after_gap (pc 5))
    (ws2812_waiting_after_gap (pc 6))
    (ws2812_waiting_after_gap (pc 7))
    (ws2812_waiting_after_gap (pc 8))
    (ws2812_waiting_after_gap (pc 9))
    (ws2812_waiting_after_gap (pc 10))
    |}]
;;

(* The kernel's row is the phase [now - t] an instruction enters at
   ([formal/phase_step.sv]), and a pin edge shows the cycle after the entry of an
   instruction that writes pins ([formal/edge_step.sv]): a set, out or mov to pins or
   pindirs, any instruction that carries side-set, and the one that lands the second half
   of a Manchester bit, all as the analyser's rows mark them. So the widest of those rows,
   in cycles, bounds the jitter of every edge against its deadline; the first pc with it
   is named. It is a bound and not the jitter of any one edge: side-set counts even where
   it drives the level the pins already hold, which neither lemma knows. A row the kernel
   leaves unbounded, before the first [mov t, now], after a wait on a pin or the host, or
   in a loop as long as its data, has no deadline, and its pc is listed as untimed.

   Reaction: a row that writes pins, has seen the captured edge and bounds the arm enters
   within [arm_hi] cycles of the core sampling the edge ([formal/phase_step.sv]); its edge
   shows within [arm_hi + 1]. Single-edge assumption; [Top]'s synchroniser adds two. *)
let%expect_test "a bound on the jitter of every pin edge, in firmware the kernel accepts" =
  let module Kernel_bits = Kernel.Make (Bits) in
  List.iter (Certified.all @ [ spi_slave_captured ]) ~f:(fun (c : Certified.t) ->
    if Result.is_ok (check c)
    then (
      let program, config = assemble c in
      let rows =
        Analyser.analyse
          ?period:c.period
          ~single_capture_edge:c.single_capture_edge
          ~config
          program.instructions
      in
      let table = Kernel.Table.of_analyser rows in
      let width_at pc =
        let row = table.(pc) in
        Bits.to_signed_int row.phase_hi - Bits.to_signed_int row.phase_lo
      in
      let untimed, timed =
        List.filter_map rows ~f:(fun r -> Option.some_if (writes_pins r) r.pc)
        |> List.partition_tf ~f:(fun pc -> Bits.to_bool (Kernel_bits.is_full table.(pc)))
      in
      let widest =
        List.max_elt timed ~compare:(Comparable.lift Int.compare ~f:width_at)
      in
      let reaction = Reaction.of_rows rows ~table in
      match widest, untimed with
      | Some pc, _ ->
        print_s
          [%message
            c.name
              (pc : int)
              ~jitter_bound:(width_at pc : int)
              (untimed : int list)
              (reaction : (Reaction.t option[@sexp.option]))]
      | None, [] -> print_s [%message c.name "writes no pins"]
      | None, _ ->
        print_s
          [%message
            c.name
              "no edge has a deadline"
              (untimed : int list)
              (reaction : (Reaction.t option[@sexp.option]))]));
  [%expect
    {|
    (uart_tx (pc 6) (jitter_bound 0) (untimed (1)))
    (uart_tx16 (pc 6) (jitter_bound 0) (untimed (1)))
    (uart_tx_host_rate (pc 8) (jitter_bound 0) (untimed (3)))
    (uart_rx "writes no pins")
    (spi_master (pc 9) (jitter_bound 2) (untimed (0 1 2 3 4 5)))
    (spi_slave "no edge has a deadline" (untimed (0 4)))
    (i2c_master (pc 34) (jitter_bound 10) (untimed (0 1 2 3 10 11)))
    (i2c_slave "no edge has a deadline" (untimed (2 19 22 40 43 53 60 64)))
    (i2c_logger (pc 24) (jitter_bound 2) (untimed (0 1 2 3)))
    (usb_tx (pc 11) (jitter_bound 0) (untimed (2)))
    (usb_rx "writes no pins")
    (usb_device (pc 109) (jitter_bound 0) (untimed (2 3)))
    (edge_meter (pc 6) (jitter_bound 0) (untimed (1)))
    (ws2812 (pc 1) (jitter_bound 0) (untimed ()))
    (ethernet (pc 9) (jitter_bound 0) (untimed (2 17 18 19 20)))
    (one_wire (pc 11) (jitter_bound 0) (untimed ()))
    (ps2 (pc 15) (jitter_bound 0) (untimed ()))
    (jtag (pc 8) (jitter_bound 2) (untimed (0 1 2 3 4)))
    (spi_slave_captured "no edge has a deadline" (untimed (0 5))
     (reaction ((pc 5) (at_most 3))))
    |}]
;;

(* Watches miso answer the falling edges of sck, every reply bit the other level to the
   one before so that each answer moves miso: [worst] is the most cycles from the core
   first sampling sck low to miso changing. *)
module Answers = struct
  type t =
    { mutable sck : int
    ; mutable fall : int option
    ; mutable miso : int option
    ; mutable worst : int
    ; mutable count : int
    }

  let create () = { sck = 0; fall = None; miso = None; worst = 0; count = 0 }

  let record t (m : Machine.t) ~sck =
    if t.sck = 1 && sck = 0 then t.fall <- Some (m.now - 1);
    t.sck <- sck;
    let miso = (m.pin_out lsr Firmware.slave_miso_pin) land 1 in
    (match t.miso, t.fall with
     | Some before, Some fall when before <> miso ->
       t.worst <- Int.max t.worst (m.now - fall);
       t.count <- t.count + 1
     | _ -> ());
    t.miso <- Some miso
  ;;

  (* [c] in lockstep with the RTL, the master's pins as [sck] and [mosi] give them each
     cycle and [step] told miso after it *)
  let run t (c : Certified.t) ~premise ~cycles ~sck ~mosi ~step =
    let program, config = assemble c in
    let sampled = ref 0 in
    Lockstep.run
      ~cycles
      ~preload:(List.init Machine.fifo_depth ~f:(fun _ -> 0x55 lsl 8))
      ~premise
      ~config
      ~program:(Asm.Program.words program |> ok_exn)
      ~inputs:(fun n ->
        sampled := sck n;
        (!sampled lsl Firmware.slave_sck_pin) lor (mosi n lsl Firmware.slave_mosi_pin))
      ~react:(fun m ->
        record t m ~sck:!sampled;
        step ((m.pin_out lsr Firmware.slave_miso_pin) land 1))
      ()
  ;;
end

(* [spi_slave_captured] answering [cycles] later, after a nop. *)
let answering_later cycles =
  { spi_slave_captured with
    name = [%string "answering_%{cycles#Int}_later"]
  ; source =
      String.substr_replace_first
        spi_slave_captured.source
        ~pattern:"    out pins, 1\n    jmp bit"
        ~with_:[%string "    nop [%{cycles - 1#Int}]\n    out pins, 1\n    jmp bit"]
  }
;;

(* Each firmware against a mode 0 master over half periods and byte gaps, in lockstep with
   the RTL. [worst] comes one under the bound, which counts the arm's own cycle, where the
   capture cannot fall. *)
let%expect_test "every answer to a captured edge comes within the reaction bound" =
  let module Spi_peer = Protocol_models.Spi_peer in
  List.iter
    [ spi_slave_captured, [ 4; 5; 6; 8 ]
    ; answering_later 1, [ 6; 8 ]
    ; answering_later 4, [ 8; 10 ]
    ]
    ~f:(fun ((c : Certified.t), half_periods) ->
      let answers = Answers.create () in
      let premise = Premise.create () in
      let bytes = [ 0xa5; 0x3c; 0xf0 ] in
      let exchanged =
        List.for_all half_periods ~f:(fun half_period ->
          List.for_all [ 0; 1; 3 ] ~f:(fun gap ->
            let master = ref (Spi_peer.create ~gap ~half_period bytes) in
            let m, mismatch =
              Answers.run
                answers
                c
                ~premise
                ~cycles:((64 * half_period) + 32)
                ~sck:(fun _ -> Spi_peer.sck !master)
                ~mosi:(fun _ -> Spi_peer.mosi !master)
                ~step:(fun miso -> master := Spi_peer.step !master ~miso)
            in
            Option.is_none mismatch
            && [%equal: int list] m.rx_fifo bytes
            && [%equal: int list]
                 (Spi_peer.received !master)
                 (List.map bytes ~f:(fun _ -> 0x55))))
      in
      print_s
        [%message
          c.name
            ~reaction:(reaction c : Reaction.t)
            ~worst:(answers.worst : int)
            ~answers:(answers.count : int)
            (exchanged : bool)
            ~premise:(Premise.count premise : Premise.Count.t)]);
  [%expect
    {|
    (spi_slave_captured (reaction ((pc 5) (at_most 3))) (worst 2) (answers 288)
     (exchanged true)
     (premise ((arms 288) (at_captured_level 0) (left_captured_level 0))))
    (answering_1_later (reaction ((pc 6) (at_most 4))) (worst 3) (answers 144)
     (exchanged true)
     (premise ((arms 144) (at_captured_level 0) (left_captured_level 0))))
    (answering_4_later (reaction ((pc 6) (at_most 7))) (worst 6) (answers 144)
     (exchanged true)
     (premise ((arms 144) (at_captured_level 0) (left_captured_level 0))))
    |}]
;;

(* Teeth: sck high for one cycle only, so the arm finds it low already and the capture
   misses the edge. The answer then comes later after the edge than the bound. *)
let%expect_test "the reaction bound rests on the single-edge assumption" =
  let answers = Answers.create () in
  let premise = Premise.create () in
  let _, mismatch =
    Answers.run
      answers
      spi_slave_captured
      ~premise
      ~cycles:240
      ~sck:(fun n -> Bool.to_int (n % 12 = 0))
      ~mosi:(Fn.const 0)
      ~step:ignore
  in
  print_s
    [%message
      spi_slave_captured.name
        ~reaction:(reaction spi_slave_captured : Reaction.t)
        ~worst:(answers.worst : int)
        (mismatch : (int * Lockstep.State.t * Lockstep.State.t) option)
        ~premise:(Premise.count premise : Premise.Count.t)];
  [%expect
    {|
    (spi_slave_captured (reaction ((pc 5) (at_most 3))) (worst 4) (mismatch ())
     (premise ((arms 19) (at_captured_level 19) (left_captured_level 0))))
    |}]
;;
