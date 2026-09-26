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

let within (r : _ Kernel.Row.t) ~phase ~period =
  G.(
    r.phase_lo
    <=+ phase
    &: (phase <=+ r.phase_hi)
    &: (r.period_lo <=: period)
    &: (period <=: r.period_hi))
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
  let word = G.input "word" Isa.data_bits in
  let phase = G.input "phase" Isa.timer_bits in
  let period = G.input "period" Isa.data_bits in
  let carry = G.input "carry" 1 in
  let any_phase = G.input "any_phase" Isa.timer_bits in
  let any_period = G.input "any_period" Isa.data_bits in
  let row = row_input "row" in
  let next = row_input "next" in
  let target = row_input "target" in
  let s = K.step ~side_set_count ~fraction ~loaded ~word ~phase ~period in
  let d = Decoder.decode ~side_set_count word in
  let is op = Opcode.is d.opcode op in
  let deadline = G.(is Wait &: Wait_source.is d.wait_source Deadline) in
  let phase' =
    G.(
      mux2
        s.bounded
        (s.next_phase -: uresize (carry &: s.may_carry) ~width:Isa.timer_bits)
        any_phase)
  in
  let period' = G.mux2 s.period_known s.next_period any_period in
  let hypothesis =
    G.(
      K.accepts ~side_set_count ~fraction ~loaded ~word ~row ~next ~target
      &: within row ~phase ~period
      &: (side_set_count <=:. 2)
      &: ~:(s.halts))
  in
  let claim =
    G.(
      ~:deadline
      |: (phase <=+ zero Isa.timer_bits)
      &: (is Jmp
          &: Jmp_cond.is d.jmp_cond Always
          |: within next ~phase:phase' ~period:period')
      &: (~:(is Jmp) |: within target ~phase:phase' ~period:period'))
  in
  prove "accepts => step stays in the rows" ~claim:G.(~:hypothesis |: claim);
  [%expect {| (QED "accepts => step stays in the rows") |}]
;;

let%expect_test "the kernel on the firmware library, from the analyser's rows" =
  List.iter Certified.all ~f:(fun (c : Certified.t) ->
    let program = Asm.assemble c.source |> ok_exn in
    let config = Asm.Program.configure program c.config in
    let words = Asm.Program.words program |> ok_exn in
    let rows = Analyser.analyse ?period:c.period ~config program.instructions in
    let verdict =
      Kernel.check ?period:c.period ~config ~words (Kernel.Table.of_analyser rows)
    in
    print_s [%message c.name (verdict : unit Or_error.t)]);
  [%expect
    {|
    (uart_tx (verdict (Ok ())))
    (uart_tx16 (verdict (Ok ())))
    (uart_tx_host_rate (verdict (Ok ())))
    (uart_rx (verdict (Error ("rows the kernel rejects" (pcs (9 15))))))
    (spi_master (verdict (Ok ())))
    (spi_slave (verdict (Ok ())))
    (i2c_master (verdict (Ok ())))
    (i2c_slave (verdict (Ok ())))
    (i2c_logger (verdict (Ok ())))
    (usb_tx (verdict (Ok ())))
    (usb_rx (verdict (Error ("rows the kernel rejects" (pcs (12 24))))))
    (usb_device
     (verdict
      (Error
       ("rows the kernel rejects"
        (pcs
         (24 32 39 44 49 54 59 64 69 74 79 84 89 94 99 104 119 131 136 148 157
          169 174 186 193 215 244 256 261 273 280 295 302 317 323 336 368 372 377
          378 382 386 409 410 414 420 423 424 427 436 442 448 454 466))))))
    (edge_meter (verdict (Ok ())))
    (ws2812 (verdict (Error ("rows the kernel rejects" (pcs (11))))))
    (ethernet (verdict (Ok ())))
    (one_wire (verdict (Ok ())))
    (ps2 (verdict (Ok ())))
    (jtag (verdict (Ok ())))
    |}]
;;
