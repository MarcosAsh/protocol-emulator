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
    (uart_rx_host_rate (verdict (Ok ())) (sends ()))
    (spi_master (verdict (Ok ())) (sends ((8 "bit 15 - x") (12 "bit 16 - x"))))
    (spi_slave (verdict (Ok ()))
     (sends ((0 "not a pulled word") (4 "not a pulled word"))))
    (i2c_master (verdict (Ok ())) (sends ()))
    (i2c_slave (verdict (Ok ())) (sends ()))
    (i2c_logger (verdict (Ok ())) (sends ((67 "not a pulled word"))))
    (i2c_master_standard (verdict (Ok ())) (sends ()))
    (i2c_master_fast (verdict (Ok ())) (sends ()))
    (i2c_controller_wire (verdict (Ok ())) (sends ()))
    (i2c_target_wire (verdict (Ok ())) (sends ()))
    (usb_tx (verdict (Ok ()))
     (sends ((11 "bit 7 - x") (23 "bit 7 - x") (33 "not a pulled word"))))
    (usb_rx (verdict (Ok ())) (sends ()))
    (usb_device (verdict (Ok ())) (sends ()))
    (edge_meter (verdict (Ok ())) (sends ()))
    (ws2812 (verdict (Ok ())) (sends ((21 "bit 0 to 32"))))
    (ws2812_standard (verdict (Ok ())) (sends ((21 "bit 0 to 32"))))
    (ethernet (verdict (Ok ())) (sends ((25 "bit 1 to 32"))))
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
    (spi_cs_mode0 (verdict (Ok ()))
     (sends ((8 "bit 13 - x") (13 "bit 15 - x") (24 "bit 11 - x"))))
    (spi_cs_mode1 (verdict (Ok ()))
     (sends ((11 "bit 14 - x") (16 "bit 65550 - x"))))
    (spi_cs_mode2 (verdict (Ok ()))
     (sends ((8 "bit 13 - x") (13 "bit 15 - x") (24 "bit 11 - x"))))
    (spi_cs_mode3 (verdict (Ok ()))
     (sends ((11 "bit 14 - x") (16 "bit 65550 - x"))))
    (spi_cs_mode0_default_pins (verdict (Ok ()))
     (sends ((8 "bit 13 - x") (13 "bit 15 - x") (24 "bit 11 - x"))))
    (spi_cs_mode1_default_pins (verdict (Ok ()))
     (sends ((11 "bit 14 - x") (16 "bit 65550 - x"))))
    (spi_cs_mode2_default_pins (verdict (Ok ()))
     (sends ((8 "bit 13 - x") (13 "bit 15 - x") (24 "bit 11 - x"))))
    (spi_cs_mode3_default_pins (verdict (Ok ()))
     (sends ((11 "bit 14 - x") (16 "bit 65550 - x"))))
    (spi_target_mode0 (verdict (Ok ()))
     (sends
      ((10 "not a pulled word") (15 "not a pulled word") (26 "not a pulled word")
       (36 "not a pulled word"))))
    (spi_target_mode1 (verdict (Ok ()))
     (sends ((12 "not a pulled word") (28 "not a pulled word"))))
    (spi_target_mode2 (verdict (Ok ()))
     (sends
      ((10 "not a pulled word") (15 "not a pulled word") (26 "not a pulled word")
       (36 "not a pulled word"))))
    (spi_target_mode3 (verdict (Ok ()))
     (sends ((12 "not a pulled word") (28 "not a pulled word"))))
    (swd (verdict (Ok ()))
     (sends
      ((33 "bit 15 - x") (53 "bit 1") (62 "bit 7 - x") (100 "bit 15 - x")
       (108 "bit 15 - x"))))
    (table (verdict (Ok ()))
     (sends ((6 "not a pulled word") (60 "bit 1 to 32"))))
    (table_open_drain (verdict (Ok ())) (sends ()))
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

(* [accepts] is every conjunct: on uart_tx's rows, with each reached row whose count may
   vary one short at the top in turn, it fails at exactly the pcs where a conjunct does. *)
let%expect_test "accepts is every conjunct" =
  let module O = Osr_kernel.Make (Bits) in
  let module K = Kernel.Make (Bits) in
  let c = Library.find_certified_exn "uart_tx" in
  let _, config, words, kernel, table = rows c in
  let words = Array.of_list words in
  let pc_bits n = Bits.of_unsigned_int ~width:Isa.pc_bits n in
  let side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count in
  let autopull = Bits.of_bool config.autopull in
  let pull_threshold = Bits.of_unsigned_int ~width:Isa.count_bits config.pull_threshold in
  (* the pcs a table is refused at, by [accepts] and by its conjuncts *)
  let refused table =
    List.filter_map
      (List.range 0 (Array.length table))
      ~f:(fun pc ->
        let word =
          Bits.of_unsigned_int
            ~width:Isa.data_bits
            (if pc < Array.length words then words.(pc) else 0)
        in
        let next, target =
          K.successors
            ~wrap_top:(pc_bits config.wrap_top)
            ~wrap_bottom:(pc_bits config.wrap_bottom)
            ~pc:(pc_bits pc)
            ~word
        in
        let x_lo = kernel.(pc).x_lo in
        let x_hi = kernel.(pc).x_hi in
        let row = table.(pc) in
        let next = table.(Bits.to_unsigned_int next) in
        let target = table.(Bits.to_unsigned_int target) in
        let accepts =
          O.accepts
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
        let every =
          List.for_all (Osr_kernel.Conjuncts.to_list conjuncts) ~f:Bits.to_bool
        in
        Option.some_if
          (not (Bits.to_bool accepts && every))
          (pc, Bits.to_bool accepts, every))
  in
  let tampered =
    List.filter_mapi (Array.to_list table) ~f:(fun pc (row : Bits.t Osr_kernel.Row.t) ->
      Option.some_if
        Bits.(to_bool (row.shifted_lo <: row.shifted_hi))
        (let table = Array.copy table in
         table.(pc) <- { row with shifted_hi = Bits.(row.shifted_hi -:. 1) };
         table))
  in
  let verdicts = List.concat_map (table :: tampered) ~f:refused in
  print_s
    [%message
      ""
        ~tampered:(List.length tampered : int)
        ~refused:(List.length verdicts : int)
        ~disagree:
          (List.filter verdicts ~f:(fun (_, accepts, every) -> Bool.( <> ) accepts every)
           : (int * bool * bool) list)];
  [%expect {| ((tampered 7) (refused 6) (disagree ())) |}]
;;

(* bounds in order, as a row that is not empty has them *)
let range top =
  Quickcheck.Generator.map
    (Quickcheck.Generator.both (Int.gen_incl 0 top) (Int.gen_incl 0 top))
    ~f:(fun (a, b) -> Int.min a b, Int.max a b)
;;

let hull = function
  | [] -> None
  | v :: rest ->
    Some (List.fold rest ~init:(v, v) ~f:(fun (lo, hi) n -> Int.min lo n, Int.max hi n))
;;

let assembled source =
  Asm.assemble source
  |> ok_exn
  |> Asm.Program.words
  |> ok_exn
  |> List.hd_exn
  |> Bits.of_unsigned_int ~width:Isa.data_bits
;;

(* Brute force: for a word that leaves x alone or counts it down, on each way out, the
   image's shifted bounds are exactly the least and greatest counts the core steps to from
   a state the row and x's bounds allow there: the sum less x narrows the row's own, a
   [jmp x--] is taken only from x at 1 or more and falls through only from 0. Its sum
   bounds are exact too where every sum in the row's is reached. *)
let%expect_test "an image's bounds are the hull of the states the core reaches" =
  let module O = Osr_kernel.Make (Bits) in
  let side_set_count = Bits.zero 2 in
  let autopull = Bits.gnd in
  let pull_threshold = Bits.zero Isa.count_bits in
  let width = Osr_kernel.Row.port_widths in
  let of_int n ~width = Bits.of_unsigned_int ~width n in
  List.iter
    [ "set y, 0", false, Fn.const true, Fn.id
    ; "out pins, 3", false, Fn.const true, Fn.id
    ; "jmp x--, 0", true, (fun x -> x > 0), (fun x -> x - 1)
    ; "jmp x--, 0", false, (fun x -> x = 0), Fn.const 0xffff
    ; "jmp 0", true, Fn.const true, Fn.id
    ]
    ~f:(fun (source, taken, goes, next_x) ->
      let word = assembled source in
      Quickcheck.test
        ~trials:2000
        (Quickcheck.Generator.tuple3 (range 12) (range 24) (range 12))
        ~f:(fun ((shifted_lo, shifted_hi), (sum_lo, sum_hi), (x_lo, x_hi)) ->
          (* each state the row allows that leaves this way: its sum, and the count and
             sum after *)
          let reached =
            List.concat_map
              (List.range shifted_lo (shifted_hi + 1))
              ~f:(fun shifted ->
                List.filter_map
                  (List.range x_lo (x_hi + 1))
                  ~f:(fun x ->
                    let sum = shifted + x in
                    if sum < sum_lo || sum > sum_hi || not (goes x)
                    then None
                    else (
                      let s =
                        O.step
                          ~side_set_count
                          ~autopull
                          ~pull_threshold
                          ~word
                          ~shifted:(of_int shifted ~width:width.shifted_lo)
                          ~pulled:Bits.gnd
                      in
                      let next = Bits.to_unsigned_int s.next_shifted in
                      Some (sum, next, next + next_x x))))
          in
          let image =
            O.image
              ~side_set_count
              ~autopull
              ~pull_threshold
              ~word
              ~x_lo:(of_int x_lo ~width:Isa.data_bits)
              ~x_hi:(of_int x_hi ~width:Isa.data_bits)
              ~row:
                { shifted_lo = of_int shifted_lo ~width:width.shifted_lo
                ; shifted_hi = of_int shifted_hi ~width:width.shifted_hi
                ; sum_lo = of_int sum_lo ~width:width.sum_lo
                ; sum_hi = of_int sum_hi ~width:width.sum_hi
                ; pulled = Bits.gnd
                }
              ~taken
          in
          let bounds lo hi = Bits.to_unsigned_int lo, Bits.to_unsigned_int hi in
          let message =
            [%string
              "%{source}, taken %{taken#Bool}: shifted %{shifted_lo#Int}..%{shifted_hi#Int}, \
               sum %{sum_lo#Int}..%{sum_hi#Int}, x %{x_lo#Int}..%{x_hi#Int}"]
          in
          Option.iter
            (hull (List.map reached ~f:(fun (_, next, _) -> next)))
            ~f:(fun expect ->
              [%test_result: int * int]
                (bounds image.shifted_lo image.shifted_hi)
                ~expect
                ~message:("shifted, " ^ message));
          let sums = List.map reached ~f:(fun (sum, _, _) -> sum) in
          if List.for_all (List.range sum_lo (sum_hi + 1)) ~f:(List.mem sums ~equal:( = ))
          then
            Option.iter
              (hull (List.map reached ~f:(fun (_, _, next_sum) -> next_sum)))
              ~f:(fun expect ->
                [%test_result: int * int]
                  (bounds image.sum_lo image.sum_hi)
                  ~expect
                  ~message:("sum, " ^ message)));
      printf "%s%s: exact\n" source (if taken then " taken" else ""));
  [%expect {|
    set y, 0: exact
    out pins, 3: exact
    jmp x--, 0 taken: exact
    jmp x--, 0: exact
    jmp 0 taken: exact
    |}]
;;

(* With autopull, an out's image holds every count the core steps to from a state the row
   allows, and is exact where every such state pulls or none does. *)
let%expect_test "an autopulling out's image holds the counts the core reaches" =
  let module O = Osr_kernel.Make (Bits) in
  let side_set_count = Bits.zero 2 in
  let width = Osr_kernel.Row.port_widths in
  let of_int n ~width = Bits.of_unsigned_int ~width n in
  let word = assembled "out pins, 3" in
  let exact = ref 0 in
  let sound = ref 0 in
  Quickcheck.test
    ~trials:2000
    (Quickcheck.Generator.tuple4
       (range 20)
       (range 32)
       (range 12)
       (Int.gen_incl 0 Isa.data_bits))
    ~f:(fun ((shifted_lo, shifted_hi), (sum_lo, sum_hi), (x_lo, x_hi), threshold) ->
      let pull_threshold = of_int threshold ~width:Isa.count_bits in
      let reached =
        List.cartesian_product
          (List.range shifted_lo (shifted_hi + 1))
          (List.range x_lo (x_hi + 1))
        |> List.filter ~f:(fun (shifted, x) ->
          sum_lo <= shifted + x && shifted + x <= sum_hi)
        |> List.map ~f:(fun (shifted, _) ->
          let s =
            O.step
              ~side_set_count
              ~autopull:Bits.vdd
              ~pull_threshold
              ~word
              ~shifted:(of_int shifted ~width:width.shifted_lo)
              ~pulled:Bits.gnd
          in
          Bits.to_bool s.takes, Bits.to_unsigned_int s.next_shifted)
      in
      let image =
        O.image
          ~side_set_count
          ~autopull:Bits.vdd
          ~pull_threshold
          ~word
          ~x_lo:(of_int x_lo ~width:Isa.data_bits)
          ~x_hi:(of_int x_hi ~width:Isa.data_bits)
          ~row:
            { shifted_lo = of_int shifted_lo ~width:width.shifted_lo
            ; shifted_hi = of_int shifted_hi ~width:width.shifted_hi
            ; sum_lo = of_int sum_lo ~width:width.sum_lo
            ; sum_hi = of_int sum_hi ~width:width.sum_hi
            ; pulled = Bits.gnd
            }
          ~taken:false
      in
      let image =
        Bits.to_unsigned_int image.shifted_lo, Bits.to_unsigned_int image.shifted_hi
      in
      let message =
        Sexp.to_string_hum
          [%message
            (shifted_lo : int)
              (shifted_hi : int)
              (sum_lo : int)
              (sum_hi : int)
              (x_lo : int)
              (x_hi : int)
              (threshold : int)]
      in
      Option.iter
        (hull (List.map reached ~f:snd))
        ~f:(fun (lo, hi) ->
          let pulls = List.map reached ~f:fst in
          if List.for_all pulls ~f:Fn.id || not (List.exists pulls ~f:Fn.id)
          then (
            [%test_result: int * int] image ~expect:(lo, hi) ~message;
            incr exact)
          else (
            [%test_result: bool]
              (fst image <= lo && hi <= snd image)
              ~expect:true
              ~message;
            incr sound)));
  print_s [%message "" ~exact:(!exact : int) ~sound:(!sound : int)];
  [%expect {| ((exact 1013) (sound 414)) |}]
;;

(* [ways] against the ISA, for x anywhere in the kernel's bounds: a word leaves by the
   next pc unless it is no instruction, halts or always jumps, and by its target if it
   jumps, [jmp x--] only from x at 1 or more and falling through only from 0. A row empty
   in either bound is never reached and leaves by neither. *)
let%expect_test "a row asks of the ways out the core may take" =
  let module O = Osr_kernel.Make (Bits) in
  let width = Osr_kernel.Row.port_widths in
  let of_int n ~width = Bits.of_unsigned_int ~width n in
  let row (shifted_lo, shifted_hi) (sum_lo, sum_hi) =
    { Osr_kernel.Row.shifted_lo = of_int shifted_lo ~width:width.shifted_lo
    ; shifted_hi = of_int shifted_hi ~width:width.shifted_hi
    ; sum_lo = of_int sum_lo ~width:width.sum_lo
    ; sum_hi = of_int sum_hi ~width:width.sum_hi
    ; pulled = Bits.gnd
    }
  in
  let rows =
    [ true, row (0, Osr_kernel.shift_limit) (0, 3)
    ; false, row (1, 0) (0, 3)
    ; false, row (0, Osr_kernel.shift_limit) (1, 0)
    ]
  in
  (* every word, and the ones that leave unusually more often than a random word does *)
  let words =
    Quickcheck.Generator.union
      [ Int.gen_incl 0 0xffff
      ; Quickcheck.Generator.of_list
          (List.map
             [ "halt"; "jmp 0"; "jmp x--, 0"; "jmp y--, 0"; "jmp x!=y, 0"; "nop"; "pull" ]
             ~f:(fun source -> Bits.to_unsigned_int (assembled source)))
      ]
  in
  Quickcheck.test
    ~trials:5000
    (Quickcheck.Generator.tuple3 words (range 2) (Quickcheck.Generator.of_list rows))
    ~f:(fun (word, (x_lo, x_hi), (reached, row)) ->
      let leaves x =
        match Isa.of_word ~side_set_count:0 word with
        | Error _ | Ok (Op { op = Sys Halt; _ }) -> false, false
        | Ok (Jmp { cond = Always; _ }) -> false, true
        | Ok (Jmp { cond = X_dec; _ }) -> x = 0, x <> 0
        | Ok (Jmp _) -> true, true
        | Ok (Op _) -> true, false
      in
      let leaves = List.map (List.range x_lo (x_hi + 1)) ~f:leaves in
      let ways =
        O.ways
          ~side_set_count:(Bits.zero 2)
          ~word:(of_int word ~width:Isa.data_bits)
          ~x_lo:(of_int x_lo ~width:Isa.data_bits)
          ~x_hi:(of_int x_hi ~width:Isa.data_bits)
          ~row
      in
      [%test_result: bool * bool]
        (Bits.to_bool ways.next, Bits.to_bool ways.target)
        ~expect:
          (reached && List.exists leaves ~f:fst, reached && List.exists leaves ~f:snd)
        ~message:
          (Sexp.to_string_hum
             [%message (word : int) (x_lo : int) (x_hi : int) (reached : bool)]));
  print_endline "agrees";
  [%expect {| agrees |}]
;;

(* The core starts at pc 0 with the osr anything, so the check asks pc 0's row to bound
   nothing; narrowing it at any one bound is refused. *)
let%expect_test "the check refuses a row at pc 0 narrower than the full range" =
  let c = Library.find_certified_exn "uart_tx" in
  let _, config, words, kernel, table = rows c in
  let full = table.(0) in
  List.iter
    [ "shifted from 1", { full with shifted_lo = Bits.(full.shifted_lo +:. 1) }
    ; "shifted to 31", { full with shifted_hi = Bits.(full.shifted_hi -:. 1) }
    ; "sum from 1", { full with sum_lo = Bits.(full.sum_lo +:. 1) }
    ; "sum one short", { full with sum_hi = Bits.(full.sum_hi -:. 1) }
    ; "pulled", { full with pulled = Bits.vdd }
    ]
    ~f:(fun (name, row) ->
      let table = Array.copy table in
      table.(0) <- row;
      print_s
        [%message name (Osr_kernel.check ~config ~words ~kernel table : unit Or_error.t)]);
  [%expect {|
    ("shifted from 1"
     ("Osr_kernel.check ~config ~words ~kernel table"
      (Error "the row at pc 0 must be the full range")))
    ("shifted to 31"
     ("Osr_kernel.check ~config ~words ~kernel table"
      (Error "the row at pc 0 must be the full range")))
    ("sum from 1"
     ("Osr_kernel.check ~config ~words ~kernel table"
      (Error "the row at pc 0 must be the full range")))
    ("sum one short"
     ("Osr_kernel.check ~config ~words ~kernel table"
      (Error "the row at pc 0 must be the full range")))
    (pulled
     ("Osr_kernel.check ~config ~words ~kernel table"
      (Error "the row at pc 0 must be the full range")))
    |}]
;;

(* [step]'s pulled against the ISA: a pull, or an out that autopulls at the threshold,
   takes a word; a mov to the osr replaces it with one not pulled; anything else keeps
   what it was. *)
let%expect_test "a step's pulled follows the instruction" =
  let module O = Osr_kernel.Make (Bits) in
  Quickcheck.test
    ~trials:5000
    (Quickcheck.Generator.tuple4
       (Int.gen_incl 0 0xffff)
       (Int.gen_incl 0 Osr_kernel.shift_limit)
       (Int.gen_incl 0 Isa.data_bits)
       (Quickcheck.Generator.both Bool.quickcheck_generator Bool.quickcheck_generator))
    ~f:(fun (word, shifted, threshold, (autopull, pulled)) ->
      match Isa.of_word ~side_set_count:0 word with
      | Error _ -> ()
      | Ok instruction ->
        let s =
          O.step
            ~side_set_count:(Bits.zero 2)
            ~autopull:(Bits.of_bool autopull)
            ~pull_threshold:(Bits.of_unsigned_int ~width:Isa.count_bits threshold)
            ~word:(Bits.of_unsigned_int ~width:Isa.data_bits word)
            ~shifted:
              (Bits.of_unsigned_int ~width:Osr_kernel.Row.port_widths.shifted_lo shifted)
            ~pulled:(Bits.of_bool pulled)
        in
        let takes, keeps =
          match instruction with
          | Op { op = Sys Pull; _ } -> true, false
          | Op { op = Out _; _ } ->
            autopull && Int.min shifted Isa.data_bits >= threshold, pulled
          | Op { op = Mov { dest = Osr; _ }; _ } -> false, false
          | Jmp _ | Op _ -> false, pulled
        in
        [%test_result: bool * bool]
          (Bits.to_bool s.takes, Bits.to_bool s.next_pulled)
          ~expect:(takes, takes || keeps)
          ~message:
            (Sexp.to_string_hum
               [%message
                 (instruction : Isa.t)
                   (shifted : int)
                   (threshold : int)
                   (autopull : bool)
                   (pulled : bool)]));
  print_endline "agrees";
  [%expect {| agrees |}]
;;
