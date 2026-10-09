open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module K = Kernel.Make (G)
module O = Osr_kernel.Make (G)
module Decoder = Decoder.Make (G)
module Opcode = Isa.Opcode.Make_comb (G)

let row_input name =
  Osr_kernel.Row.map2
    Osr_kernel.Row.port_names
    Osr_kernel.Row.port_widths
    ~f:(fun field width -> G.input (name ^ "_" ^ field) width)
;;

let within (lo, hi) v = G.(lo <=: v &: (v <=: hi))

(* Whether the core lies inside a row, bound by bound. *)
let lies_in (r : _ Osr_kernel.Row.t) ~shifted ~x ~pulled =
  let wide v = G.uresize v ~width:(G.width r.sum_lo) in
  { Osr_kernel.Holds.shifted = within (r.shifted_lo, r.shifted_hi) shifted
  ; sum = within (r.sum_lo, r.sum_hi) G.(wide shifted +: wide x)
  ; pulled = G.(~:(r.pulled) |: pulled)
  }
;;

let all (h : _ Osr_kernel.Holds.t) = Osr_kernel.Holds.to_list h |> G.reduce ~f:G.( &: )

(* An accepted row maps into the row the core steps to. x and the way out are the kernel's
   step (phase_step.sv), and x on the way in lies in the kernel's row, which the kernel's
   proof gives for a program it accepts. [with_kernel] false drops that. A write to x the
   kernel does not follow asks for a full sum, so the x the core arrives with is free. *)
let accepted_rows_hold ~with_kernel =
  let side_set_count = G.input "side_set_count" 2 in
  let autopull = G.input "autopull" 1 in
  let pull_threshold = G.input "pull_threshold" Isa.count_bits in
  let word = G.input "word" Isa.data_bits in
  let shifted = G.input "shifted" (G.width (row_input "row").shifted_lo) in
  let pulled = G.input "pulled" 1 in
  let x = G.input "x" Isa.data_bits in
  let s =
    K.step
      ~side_set_count
      ~fraction:(G.input "fraction" 1)
      ~loaded:
        { With_valid.valid = G.input "loads_period" 1
        ; value = G.input "loaded_period" Isa.data_bits
        }
      ~capture:
        { Kernel.Capture.pin = G.input "capture_pin" Isa.Field.wait_index.width
        ; rising = G.input "capture_rising" 1
        ; single_edge = G.input "single_edge" 1
        }
      ~spacing:K.no_spacing
      ~word
      ~phase:(G.input "phase" Isa.timer_bits)
      ~period:(G.input "period" Isa.data_bits)
      ~x
      ~y:(G.input "y" Isa.data_bits)
      ~arm:(G.input "arm" Isa.timer_bits)
      ~arm_known:(G.input "arm_known" 1)
      ~captured:(G.input "captured" 1)
      ~awaiting:(G.input "awaiting" 1)
      ~a:(K.starting ~level:G.gnd)
      ~b:(K.starting ~level:G.gnd)
      ~data_a:G.gnd
      ~data_b:G.gnd
  in
  let o = O.step ~side_set_count ~autopull ~pull_threshold ~word ~shifted ~pulled in
  let x' = G.mux2 s.x_known s.next_x (G.input "any_x" Isa.data_bits) in
  let d = Decoder.decode ~side_set_count word in
  let is op = Opcode.is d.opcode op in
  let lands ~target ~next =
    G.(
      mux2 (is Jmp) (mux2 s.taken_known (mux2 s.taken target next) (target &: next)) next)
  in
  let row = row_input "row" in
  let next = row_input "next" in
  let target = row_input "target" in
  (* the x bounds of the kernel's row at the same pc *)
  let x_lo = G.input "row_x_lo" Isa.data_bits in
  let x_hi = G.input "row_x_hi" Isa.data_bits in
  let conjuncts =
    O.conjuncts
      ~side_set_count
      ~autopull
      ~pull_threshold
      ~word
      ~x_lo
      ~x_hi
      ~row
      ~next
      ~target
  in
  let premise =
    G.(
      all (lies_in row ~shifted ~x ~pulled)
      &: (if with_kernel then within (x_lo, x_hi) x else x_lo <=: x_hi)
      &: (shifted <=:. Osr_kernel.shift_limit)
      &: (side_set_count <=:. 2)
      &: ~:(s.halts))
  in
  let arrives =
    Osr_kernel.Holds.map2
      (lies_in target ~shifted:o.next_shifted ~x:x' ~pulled:o.next_pulled)
      (lies_in next ~shifted:o.next_shifted ~x:x' ~pulled:o.next_pulled)
      ~f:(fun target next -> lands ~target ~next)
  in
  (* each bound on its own, from the conjuncts that ask for it, which SAT finds far easier
     than all at once; [accepts] is every conjunct, so it implies each *)
  let claims =
    Osr_kernel.Holds.map3
      conjuncts.next
      conjuncts.target
      arrives
      ~f:(fun next target arrives -> G.(~:(premise &: next &: target) |: arrives))
  in
  let cases =
    List.concat_map Isa.Opcode.Cases.all ~f:(fun op ->
      match op with
      | Jmp ->
        List.init (1 lsl Isa.Field.jmp_cond.width) ~f:(fun v ->
          G.(is Jmp &: (Isa.Field.select (module G) Isa.Field.jmp_cond word ==:. v)))
      | Wait | In | Out | Mov | Set | Alu | Sys -> [ is op ])
  in
  cases, claims
;;

let%expect_test "an accepted osr row maps into the row the core steps to" =
  let cases, claims = accepted_rows_hold ~with_kernel:true in
  Osr_kernel.Holds.iter2 Osr_kernel.Holds.port_names claims ~f:(fun bound claim ->
    Checked_unsat.prove
      ~show:[]
      [%string "accepts => %{bound} stays in the rows"]
      ~cases
      ~claim);
  [%expect {|
    (QED "accepts => shifted stays in the rows")
    (QED "accepts => sum stays in the rows")
    (QED "accepts => pulled stays in the rows")
    |}]
;;

(* Teeth: the kernel's x is what bounds the count in a loop. *)
let%expect_test "the rows hold only with the kernel's x" =
  let cases, claims = accepted_rows_hold ~with_kernel:false in
  Checked_unsat.prove
    ~show:[]
    "accepts => shifted stays in the rows, x anything"
    ~cases
    ~claim:claims.shifted;
  [%expect {|
    (counterexample "accepts => shifted stays in the rows, x anything"
     (model ()))
    |}]
;;

(* The kernel's rows from the analyser, and the osr rows proposed on their x. *)
let rows (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  let config = Asm.Program.configure program c.config in
  let words = Asm.Program.words program |> ok_exn in
  let kernel =
    Analyser.analyse
      ?period:c.period
      ~single_capture_edge:c.single_capture_edge
      ~config
      program.instructions
    |> Kernel.Table.of_analyser
  in
  program, config, words, kernel, Osr_kernel.Table.propose ~config ~words kernel
;;

(* What each out to the pins sends, by its row: bit [sum - x] and the n - 1 after it, from
   the end the osr shifts from, where the sum is one value; else the first bit's range. An
   osr that may hold something other than a pulled word sends nothing named. *)
let sends (c : Certified.t) =
  let program, _, _, _, table = rows c in
  List.filter_mapi program.instructions ~f:(fun pc instruction ->
    match instruction with
    | Op { op = Out { dest = Pins; count }; _ } ->
      let r = Osr_kernel.Row.map table.(pc) ~f:Bits.to_unsigned_int in
      let bits first =
        if count = 1 then [%string "bit %{first}"] else [%string "bits %{first} on"]
      in
      let what =
        if r.shifted_lo > r.shifted_hi
        then "never reached"
        else if r.pulled = 0
        then "not a pulled word"
        else if r.sum_lo = r.sum_hi
        then bits [%string "%{r.sum_lo#Int} - x"]
        else if r.shifted_lo = r.shifted_hi
        then bits (Int.to_string r.shifted_lo)
        else bits [%string "%{r.shifted_lo#Int} to %{r.shifted_hi#Int}"]
      in
      Some (pc, what)
    | _ -> None)
;;

let%expect_test "what each out sends, in the firmware library" =
  List.iter
    ((Library.stamped :: Library.certified) @ Library.time_triggered)
    ~f:(fun (c : Certified.t) ->
      let _, config, words, kernel, table = rows c in
      let verdict = Osr_kernel.check ~config ~words ~kernel table in
      let sends = sends c in
      print_s [%message c.name (verdict : unit Or_error.t) (sends : (int * string) list)]);
  [%expect {|
    (uart_tx_stamped (verdict (Ok ()))
     (sends ((11 "bit 7 - x") (16 "not a pulled word"))))
    (uart_tx (verdict (Ok ())) (sends ((9 "bit 7 - x"))))
    (uart_tx16 (verdict (Ok ())) (sends ((9 "bit 7 - x"))))
    (uart_tx_host_rate (verdict (Ok ())) (sends ((11 "bit 7 - x"))))
    (uart_rx (verdict (Ok ())) (sends ()))
    (spi_master (verdict (Ok ())) (sends ((8 "bit 15 - x") (12 "bit 16 - x"))))
    (spi_slave (verdict (Ok ()))
     (sends ((0 "not a pulled word") (4 "not a pulled word"))))
    (i2c_master (verdict (Ok ())) (sends ()))
    (i2c_slave (verdict (Ok ())) (sends ()))
    (i2c_logger (verdict (Ok ())) (sends ((67 "not a pulled word"))))
    (usb_tx (verdict (Ok ()))
     (sends ((11 "bit 7 - x") (23 "bit 7 - x") (33 "not a pulled word"))))
    (usb_rx (verdict (Ok ())) (sends ()))
    (usb_device (verdict (Ok ())) (sends ()))
    (edge_meter (verdict (Ok ())) (sends ()))
    (ws2812 (verdict (Ok ())) (sends ((21 "bit 0 to 32"))))
    (ethernet (verdict (Ok ())) (sends ((17 "bit 1 to 32"))))
    (one_wire (verdict (Ok ())) (sends ()))
    (ps2 (verdict (Ok ())) (sends ()))
    (jtag (verdict (Ok ())) (sends ((7 "bits 7 - x on") (11 "bits 2 to 32 on"))))
    (can (verdict (Ok ()))
     (sends
      ((19 "bit 1 to 32") (23 "bit 1 to 32") (37 "not a pulled word")
       (41 "not a pulled word"))))
    (dshot600 (verdict (Ok ())) (sends ((11 "bit 15 - x"))))
    (sent (verdict (Ok ())) (sends ()))
    (cec (verdict (Ok ())) (sends ()))
    (uart_tx_stream (verdict (Ok ())) (sends ((8 "not a pulled word"))))
    (spi_master_stream (verdict (Ok ()))
     (sends ((4 "not a pulled word") (8 "not a pulled word"))))
    |}]
;;

(* A row that leaves out the last count the loop reaches is refused: uart_tx's, with the
   count at its out one short of 7, which the wait before it steps past. *)
let%expect_test "the check refuses a row one short" =
  let c = Library.find_certified_exn "uart_tx" in
  let _, config, words, kernel, table = rows c in
  let out = 9 in
  table.(out) <- { (table.(out)) with shifted_hi = Bits.(table.(out).shifted_hi -:. 1) };
  print_s [%message (Osr_kernel.check ~config ~words ~kernel table : unit Or_error.t)];
  [%expect {|
    ("Osr_kernel.check ~config ~words ~kernel table"
     (Error
      ("rows the check rejects" (rejected (((pc 8) (fails ("next shifted"))))))))
    |}]
;;
