open! Core
open! Hardcaml
open! Hardcaml_verify
open Protocol_emulator
module G = Comb_gates
module Footprint_gates = Footprint.Make (G)

(* formal/frame_step.sv's footprint over gates: the window of [n] pins from [base] is the
   top half of the doubled word, shifted up by [base] mod 28. *)
module Frame_step = struct
  open G

  let outputs = of_unsigned_int ~width:Isa.pin_space 0xfffffe0
  let bidirs = of_unsigned_int ~width:Isa.pin_space 0x00ff000
  let five v = uresize v ~width:5

  let place v ~base =
    let base = mux2 (base >=:. 28) (base -:. 28) base in
    log_shift ~f:sll (concat_msb [ zero 12; v; zero 12; v ]) ~by:base
    |> select ~high:55 ~low:28
  ;;

  let mask n = mux2 (n >=:. 16) (ones 16) (log_shift ~f:sll (one 16) ~by:n -:. 1)
  let window ~base ~n ~takes = place (mask (five n)) ~base &: takes
  let only_if used pins = mux2 used pins (zero Isa.pin_space)
  let side_reach n = mux2 (n ==:. 3) (of_unsigned_int ~width:2 2) n

  let pin_out (c : G.t Engine.Config.t) (w : G.t Footprint.Writes.t) =
    let pair_width =
      mux2
        (c.manchester &: (w.out_pins_width ==:. 1))
        (of_unsigned_int ~width:5 2)
        w.out_pins_width
    in
    reduce
      ~f:( |: )
      [ only_if
          (~:(c.side_set_pindirs) &: (c.side_set_count <>:. 0))
          (window ~base:c.side_set_base ~n:(side_reach c.side_set_count) ~takes:outputs)
      ; only_if w.sets_pins (window ~base:c.set_base ~n:c.set_count ~takes:outputs)
      ; window ~base:c.out_base ~n:pair_width ~takes:outputs
      ; only_if w.movs_pins (window ~base:c.out_base ~n:c.out_count ~takes:outputs)
      ]
  ;;

  let pin_dir (c : G.t Engine.Config.t) (w : G.t Footprint.Writes.t) =
    reduce
      ~f:( |: )
      [ only_if
          (c.side_set_pindirs &: (c.side_set_count <>:. 0))
          (window ~base:c.side_set_base ~n:(side_reach c.side_set_count) ~takes:bidirs)
      ; only_if w.sets_dirs (window ~base:c.set_base ~n:c.set_count ~takes:bidirs)
      ; window ~base:c.out_base ~n:w.out_dirs_width ~takes:bidirs
      ; only_if w.movs_dirs (window ~base:c.out_base ~n:c.out_count ~takes:bidirs)
      ]
  ;;
end

let prove ?(solver = Checked_unsat.solver) name ~claim =
  match Solver.solve ~solver (G.cnf G.(~:claim)) with
  | Ok Unsat -> print_s [%message "QED" name]
  | Ok (Sat _) -> print_s [%message "counterexample" name]
  | Error e -> print_s [%message "solver failed" name (e : Error.t)]
;;

let config =
  Engine.Config.map Engine.Config.port_names_and_widths ~f:(fun (name, width) ->
    G.input name width)
;;

let writes =
  Footprint.Writes.map Footprint.Writes.port_names_and_widths ~f:(fun (name, width) ->
    G.input name width)
;;

let claims =
  [ ( "pin_out"
    , G.(Footprint_gates.pin_out config writes ==: Frame_step.pin_out config writes) )
  ; ( "pin_dir"
    , G.(Footprint_gates.pin_dir config writes ==: Frame_step.pin_dir config writes) )
  ]
;;

let%expect_test "the footprint is the one the frame lemma proves, for every config" =
  List.iter claims ~f:(fun (name, claim) -> prove name ~claim);
  [%expect {|
    (QED pin_out)
    (QED pin_dir)
    |}]
;;

let%expect_test "no QED once cake_lpr refuses the proof, or for a false claim" =
  List.iter claims ~f:(fun (name, claim) ->
    prove ~solver:Checked_unsat.solver_with_a_bad_proof name ~claim);
  prove
    "pin_out without Manchester's second pin"
    ~claim:
      G.(
        Footprint_gates.pin_out config writes
        ==: Frame_step.pin_out { config with manchester = gnd } writes);
  [%expect
    {|
    ("solver failed" pin_out
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 1. Reason: clause index has no reduction sequence: 5\n")))
    ("solver failed" pin_dir
     (e
      ("cake_lpr rejects the proof"
       "c Checking failed at line: 1. Reason: clause index has no reduction sequence: 5\n")))
    (counterexample "pin_out without Manchester's second pin")
    |}]
;;

(* runs of pins, as 5-7 12 *)
let pins_to_string = function
  | [] -> "-"
  | pins ->
    List.group pins ~break:(fun a b -> b <> a + 1)
    |> List.map ~f:(fun run ->
      match run with
      | [ pin ] -> Int.to_string pin
      | run -> sprintf "%d-%d" (List.hd_exn run) (List.last_exn run))
    |> String.concat ~sep:" "
;;

let firmware (t : Certified.t) =
  let program = Asm.assemble t.source |> ok_exn in
  Asm.Program.configure program t.config, program
;;

let footprint (t : Certified.t) =
  let config, program = firmware t in
  Footprint.of_program config program.instructions
;;

(* The writes formal/frame_step.sv holds a word to, decoded as it decodes them: out, mov,
   set are opcodes 3, 4, 5; pins is destination 0, pindirs 4 for out and 3 otherwise. An
   out's width is its count, capped at what a data word covers. *)
let frame_step_writes word =
  let opcode = (word lsr 13) land 0x7 in
  let dest = (word lsr 5) land 0x7 in
  let count = word land 0x1f in
  let writes ~opcode:o ~dest:d = opcode = o && dest = d in
  let out ~dest = if writes ~opcode:3 ~dest then Int.min count 16 else 0 in
  { Footprint.Writes.out_pins_width = out ~dest:0
  ; out_dirs_width = out ~dest:4
  ; sets_pins = Bool.to_int (writes ~opcode:5 ~dest:0)
  ; sets_dirs = Bool.to_int (writes ~opcode:5 ~dest:3)
  ; movs_pins = Bool.to_int (writes ~opcode:4 ~dest:0)
  ; movs_dirs = Bool.to_int (writes ~opcode:4 ~dest:3)
  }
;;

(* The lemma assumes each word keeps to [Writes.of_program]. A word that writes more would
   make the assumption rule out the firmware's own runs, and the lemma vacuous. *)
let%expect_test "the frame lemma counts each word as the writer Writes counts it" =
  let fields writes =
    Footprint.Writes.(to_list (map2 port_names writes ~f:(fun name n -> name, n)))
  in
  let of_program program =
    Footprint.Writes.map (Footprint.Writes.of_program program) ~f:Bits.to_unsigned_int
  in
  let decoded =
    List.concat_map
      (List.range 0 (Isa.max_side_set + 1))
      ~f:(fun side_set_count ->
        List.filter_map
          (List.range 0 (1 lsl Isa.word_bits))
          ~f:(fun word ->
            Isa.of_word ~side_set_count word
            |> Result.ok
            |> Option.map ~f:(fun instruction -> word, instruction)))
  in
  List.iter decoded ~f:(fun (word, instruction) ->
    [%test_result: (string * int) list]
      ~message:(sprintf "word 0x%04x" word)
      ~expect:(fields (of_program [ instruction ]))
      (fields (frame_step_writes word)));
  List.iter Certified.all ~f:(fun t ->
    let _, program = firmware t in
    let writes = of_program program.instructions in
    List.iter
      (Asm.Program.words program |> ok_exn)
      ~f:(fun word ->
        [%test_result: (string * int) list]
          ~message:(sprintf "%s word 0x%04x" t.name word)
          ~expect:(fields writes)
          (fields (Footprint.Writes.map2 (frame_step_writes word) writes ~f:Int.max))));
  printf
    "%d of the %d words decode under some side-set count\n"
    (List.map decoded ~f:fst |> Int.Set.of_list |> Set.length)
    (1 lsl Isa.word_bits);
  [%expect {| 34592 of the 65536 words decode under some side-set count |}]
;;

let%expect_test "the footprint of each firmware, and of its config under any program" =
  printf
    "%-18s %-12s %-10s %-14s %s\n"
    "firmware"
    "pin_out"
    "pin_dir"
    "any: pin_out"
    "pin_dir";
  List.iter Certified.all ~f:(fun t ->
    let config, _ = firmware t in
    let mine = footprint t in
    let any = Footprint.of_config config in
    printf
      "%-18s %-12s %-10s %-14s %s\n"
      t.name
      (pins_to_string mine.pin_out)
      (pins_to_string mine.pin_dir)
      (pins_to_string any.pin_out)
      (pins_to_string any.pin_dir));
  [%expect
    {|
    firmware           pin_out      pin_dir    any: pin_out   pin_dir
    uart_tx            5            -          5-20           12-19
    uart_tx16          5            -          5-20           12-19
    uart_tx_host_rate  5            -          5-20           12-19
    uart_rx            -            -          5-20           12-19
    spi_master         5-6          -          5-20           12-19
    spi_slave          5            -          5-20           12-19
    i2c_master         -            12-13      12-27          12-19
    i2c_slave          -            12         12-27          12-19
    i2c_logger         5            12-13      5-20           12-19
    usb_tx             5-7          -          5-20           12-19
    usb_rx             -            -          5-20           12-19
    usb_device         12-14        12-14      12-27          12-19
    edge_meter         5            -          5-20           12-19
    ws2812             5            -          5-20           12-19
    ethernet           12-13        12-13      12-27          12-19
    one_wire           -            12         12-27          12-19
    ps2                -            12-13      12-27          12-19
    jtag               5-7          -          5-21           12-19
    can                6            -          6-21           12-19
    dshot600           5            -          5-20           12-19
    sent               5            -          5-20           12-19
    cec                12           12         12-27          12-19
    uart_rx_host_rate  -            -          5-20           12-19
    i2c_master_standard -            12-13      12-27          12-19
    i2c_master_fast    -            12-13      12-27          12-19
    i2c_controller_wire 20-21        -          5-7 20-27      -
    i2c_target_wire    20           -          5-7 20-27      -
    spi_cs_mode0       5-7          -          5-20           12-19
    spi_target_mode0   5            -          5-20           12-19
    spi_cs_mode1       5-7          -          5-20           12-19
    spi_target_mode1   5            -          5-20           12-19
    spi_cs_mode2       5-7          -          5-20           12-19
    spi_target_mode2   5            -          5-20           12-19
    spi_cs_mode3       5-7          -          5-20           12-19
    spi_target_mode3   5            -          5-20           12-19
    |}]
;;

(* Under random pins and host words, no firmware moves a pin outside its footprint. *)
let%expect_test "each firmware stays inside its footprint" =
  let random = Random.State.make [| 7 |] in
  let cycles = 4000 in
  printf "%-18s %-12s %s\n" "firmware" "moved out" "moved dir";
  List.iter Certified.all ~f:(fun t ->
    let config, program = firmware t in
    let footprint = footprint t in
    let mask pins = List.fold pins ~init:0 ~f:(fun mask pin -> mask lor (1 lsl pin)) in
    let words = Asm.Program.words program |> ok_exn in
    let machine = Machine.create ~config ~program:words |> ok_exn in
    let feed machine =
      match Machine.write_tx machine (Random.State.int random 0x10000) with
      | Ok machine -> machine
      | Error _ -> machine
    in
    let moved_out, moved_dir, _ =
      Fn.apply_n_times
        ~n:cycles
        (fun (moved_out, moved_dir, machine) ->
          let machine =
            Machine.step
              (feed machine)
              ~inputs:(Random.State.int random (1 lsl Isa.pin_space))
          in
          let machine =
            match Machine.read_rx machine with
            | Some (_, machine) -> machine
            | None -> machine
          in
          moved_out lor machine.pin_out, moved_dir lor machine.pin_dir, machine)
        (0, 0, machine)
    in
    let pins mask =
      List.filter (List.range 0 Isa.pin_space) ~f:(fun pin -> mask land (1 lsl pin) <> 0)
    in
    [%test_result: int list]
      ~message:[%string "%{t.name} moved pins outside its footprint"]
      ~expect:[]
      (pins
         (moved_out
          land lnot (mask footprint.pin_out)
          lor (moved_dir land lnot (mask footprint.pin_dir))));
    printf
      "%-18s %-12s %s\n"
      t.name
      (pins_to_string (pins moved_out))
      (pins_to_string (pins moved_dir)));
  [%expect
    {|
    firmware           moved out    moved dir
    uart_tx            5            -
    uart_tx16          5            -
    uart_tx_host_rate  5            -
    uart_rx            -            -
    spi_master         5-6          -
    spi_slave          5            -
    i2c_master         -            12-13
    i2c_slave          -            -
    i2c_logger         5            12-13
    usb_tx             7            -
    usb_rx             -            -
    usb_device         13           14
    edge_meter         5            -
    ws2812             5            -
    ethernet           -            12-13
    one_wire           -            -
    ps2                -            -
    jtag               5-7          -
    can                -            -
    dshot600           5            -
    sent               5            -
    cec                -            -
    uart_rx_host_rate  -            -
    i2c_master_standard -            -
    i2c_master_fast    -            12-13
    i2c_controller_wire 21           -
    i2c_target_wire    -            -
    spi_cs_mode0       5-7          -
    spi_target_mode0   5            -
    spi_cs_mode1       5-7          -
    spi_target_mode1   5            -
    spi_cs_mode2       5-7          -
    spi_target_mode2   5            -
    spi_cs_mode3       5-7          -
    spi_target_mode3   5            -
    |}]
;;

(* Pins both engines of a pair can move; must be none for the chip to show each one's
   edges. *)
let%expect_test "which pairs of firmware write disjoint pins" =
  List.iter
    [ "uart_tx", "uart_rx"
    ; "spi_master", "i2c_master"
    ; "uart_tx", "spi_master"
    ; "uart_rx", "spi_master"
    ; "uart_rx", "i2c_master"
    ; "ws2812", "uart_rx"
    ; "usb_device", "uart_tx"
    ; "jtag", "uart_rx"
    ; "one_wire", "ps2"
    ]
    ~f:(fun (a, b) ->
      let shared =
        Footprint.shared
          (footprint (Certified.find_exn a))
          (footprint (Certified.find_exn b))
      in
      printf
        "%-24s %s\n"
        [%string "%{a} + %{b}"]
        (match shared with
         | [] -> "disjoint"
         | pins -> "share " ^ pins_to_string pins));
  [%expect
    {|
    uart_tx + uart_rx        disjoint
    spi_master + i2c_master  disjoint
    uart_tx + spi_master     share 5
    uart_rx + spi_master     disjoint
    uart_rx + i2c_master     disjoint
    ws2812 + uart_rx         disjoint
    usb_device + uart_tx     disjoint
    jtag + uart_rx           disjoint
    one_wire + ps2           share 12
    |}]
;;
