open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module K = Kernel.Make (G)
module Decoder = Decoder.Make (G)
module Opcode = Isa.Opcode.Make_comb (G)
module Wait_source = Isa.Wait_source.Make_comb (G)
module Jmp_cond = Isa.Jmp_cond.Make_comb (G)

let row_input name =
  Kernel.Row.map2 Kernel.Row.port_names Kernel.Row.port_widths ~f:(fun field width ->
    G.input (name ^ "_" ^ field) width)
;;

(* A row holds the core when every bound in it does; a full arm range says nothing. *)
let within (r : _ Kernel.Row.t) ~phase ~period ~x ~y ~arm ~arm_known ~captured ~awaiting =
  let inside lo hi v = G.(lo <=: v &: (v <=: hi)) in
  G.(
    r.phase_lo
    <=+ phase
    &: (phase <=+ r.phase_hi)
    &: inside r.period_lo r.period_hi period
    &: inside r.x_lo r.x_hi x
    &: inside r.y_lo r.y_hi y
    &: (K.arm_is_full r |: (arm_known &: inside r.arm_lo r.arm_hi arm))
    &: (~:(r.captured) |: captured)
    &: (~:(r.awaiting) |: awaiting))
;;

let prove name ~claim =
  match Solver.solve ~solver:(Solver.z3 ~parallel:false ()) (G.cnf G.(~:claim)) with
  | Ok Unsat -> print_s [%message "QED" name]
  | Ok (Sat model) ->
    let model =
      List.map model ~f:(fun (m : Cnf.Model_with_vectors.input) -> m.name, m.value)
    in
    print_s [%message "counterexample" name (model : (string * string) list)]
  | Error e -> print_s [%message "solver failed" name (e : Error.t)]
;;

let%expect_test "an accepted row maps into its successors and meets its deadline" =
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
      ~capture
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
  let within' r =
    within
      r
      ~phase:phase'
      ~period:(known s.period_known s.next_period "period")
      ~x:(known s.x_known s.next_x "x")
      ~y:(known s.y_known s.next_y "y")
      ~arm:s.next_arm
      ~arm_known:s.next_arm_known
      ~captured:s.next_captured
      ~awaiting:s.next_awaiting
  in
  let hypothesis =
    G.(
      K.accepts ~side_set_count ~fraction ~loaded ~capture ~word ~row ~next ~target
      &: within row ~phase ~period ~x ~y ~arm ~arm_known ~captured ~awaiting
      &: (side_set_count <=:. 2)
      &: ~:(s.halts)
      &: (~:(s.capture_bounded) |: in_capture_range))
  in
  let arrives =
    G.(
      mux2
        (is Jmp)
        (mux2
           s.taken_known
           (mux2 s.taken (within' target) (within' next))
           (within' target &: within' next))
        (within' next))
  in
  let claim = G.(~:deadline |: (phase <=+ zero Isa.timer_bits) &: arrives) in
  prove "accepts => step stays in the rows" ~claim:G.(~:hypothesis |: claim);
  [%expect {| (QED "accepts => step stays in the rows") |}]
;;

let assemble (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  program, Asm.Program.configure program c.config
;;

let check (c : Certified.t) =
  let program, config = assemble c in
  let single_capture_edge = c.single_capture_edge in
  let rows =
    Analyser.analyse ?period:c.period ~single_capture_edge ~config program.instructions
  in
  Kernel.check
    ?period:c.period
    ~single_capture_edge
    ~config
    ~words:(Asm.Program.words program |> ok_exn)
    (Kernel.Table.of_analyser rows)
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
    (ws2812
     (verdict
      (Error
       ("rows the kernel rejects"
        (rejected (((pc 11) (fails ("in time" "next phase")))))))))
    (ethernet (verdict (Ok ())))
    (one_wire (verdict (Ok ())))
    (ps2 (verdict (Ok ())))
    (jtag (verdict (Ok ())))
    |}]
;;

(* Whether some table of interval rows passes the kernel, with pc 0 held to the full range
   as [Kernel.check] holds it and every other row free. The analyser's rows play no part,
   so when no table passes, a rejection is a limit of the kernel's rows and not of the
   analyser's. Like [Kernel.check], it checks every pc, reading words past the program as
   zero. *)
let some_table_passes (c : Certified.t) =
  let program, config = assemble c in
  let words = Asm.Program.words program |> ok_exn |> Array.of_list in
  let constant b = G.of_constant (Bits.to_constant b) in
  let size = 1 lsl Isa.pc_bits in
  let table =
    Array.init size ~f:(fun pc ->
      if pc = 0
      then Kernel.Row.map (Kernel.Table.of_analyser []).(0) ~f:constant
      else row_input [%string "pc%{pc#Int}"])
  in
  let word pc =
    Bits.of_unsigned_int
      ~width:Isa.data_bits
      (if pc < Array.length words then words.(pc) else 0)
  in
  let following pc =
    if pc = config.wrap_top then config.wrap_bottom else (pc + 1) % size
  in
  let side_set_count = G.of_unsigned_int ~width:2 config.side_set_count in
  let fraction = G.of_bool (config.period_fraction <> 0) in
  let loaded =
    { With_valid.valid = G.of_bool (Option.is_some c.period)
    ; value = G.of_unsigned_int ~width:Isa.data_bits (Option.value c.period ~default:0)
    }
  in
  let capture =
    { Kernel.Capture.pin =
        G.of_unsigned_int ~width:Isa.Field.wait_index.width config.capture_pin
    ; rising = G.of_bool config.capture_rising
    ; single_edge = G.of_bool c.single_capture_edge
    }
  in
  let passes =
    List.init size ~f:(fun pc ->
      let target =
        Bits.to_unsigned_int
          (Isa.Field.select (module Bits) Isa.Field.jmp_target (word pc))
      in
      K.accepts
        ~side_set_count
        ~fraction
        ~loaded
        ~capture
        ~word:(constant (word pc))
        ~row:table.(pc)
        ~next:table.(following pc)
        ~target:table.(target))
  in
  match
    Solver.solve
      ~solver:(Solver.z3 ~parallel:false ())
      (G.cnf (G.reduce ~f:G.( &: ) passes))
    |> ok_exn
  with
  | Unsat -> false
  | Sat _ -> true
;;

let%expect_test "a rejection is the kernel's or the analyser's" =
  List.iter Certified.all ~f:(fun (c : Certified.t) ->
    match check c with
    | Ok () -> ()
    | Error _ ->
      if some_table_passes c
      then
        print_s [%message c.name "some table passes, so the analyser's rows are at fault"]
      else print_s [%message c.name "no table of intervals passes"]);
  [%expect {| (ws2812 "no table of intervals passes") |}]
;;

(* The analyser's rows are one table that passes, so the query must find some for the
   firmware the kernel accepts: a receiver and a loaded period among them. *)
let%expect_test "some table passes for firmware the kernel accepts" =
  List.iter [ "uart_tx"; "uart_rx"; "ethernet"; "jtag" ] ~f:(fun name ->
    let passes = some_table_passes (Certified.find_exn name) in
    print_s [%message name (passes : bool)]);
  [%expect
    {|
    (uart_tx (passes true))
    (uart_rx (passes true))
    (ethernet (passes true))
    (jtag (passes true))
    |}]
;;

(* Each pass of ws2812's gap loop moves [t] 23 cycles further ahead of [now], so the row
   at the head of the loop, which has to hold its own image one pass on, has no lower
   bound short of the full range, and the wait after the loop is not known to be in time.
   Moving that wait into the loop still holds the line low for 160 thirds, and a table
   passes. *)
let%expect_test "ws2812 passes once the wait after its gap loop moves into the loop" =
  let c = Certified.find_exn "ws2812" in
  let source =
    String.substr_replace_first
      c.source
      ~pattern:"jmp x--, gap\n    wait t"
      ~with_:"wait t\n    jmp x--, gap"
  in
  let passes = some_table_passes { c with source } in
  print_s [%message (passes : bool)];
  [%expect {| (passes true) |}]
;;
