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

let%expect_test "the kernel on the firmware library, from the analyser's rows" =
  List.iter Certified.all ~f:(fun (c : Certified.t) ->
    let program = Asm.assemble c.source |> ok_exn in
    let config = Asm.Program.configure program c.config in
    let words = Asm.Program.words program |> ok_exn in
    let single_capture_edge = c.single_capture_edge in
    let rows =
      Analyser.analyse ?period:c.period ~single_capture_edge ~config program.instructions
    in
    let verdict =
      Kernel.check
        ?period:c.period
        ~single_capture_edge
        ~config
        ~words
        (Kernel.Table.of_analyser rows)
    in
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
    (ws2812 (verdict (Error ("rows the kernel rejects" (pcs (11))))))
    (ethernet (verdict (Ok ())))
    (one_wire (verdict (Ok ())))
    (ps2 (verdict (Ok ())))
    (jtag (verdict (Ok ())))
    |}]
;;
