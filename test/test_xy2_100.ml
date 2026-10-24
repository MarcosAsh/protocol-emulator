open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Xy2_100.firmware));
  [%expect {| 35 words, 10 deadline waits, worst slack 2 |}]
;;

(* The line, level by level with the cycles each lasted, for one host word. *)
let%expect_test "SENDCK for one host word" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Xy2_100.firmware)
      ~program:(Timed_program.words Xy2_100.firmware)
    |> ok_exn
  in
  let machine = Machine.write_tx machine 0x8000 |> ok_exn in
  let levels =
    List.folding_map (List.range 0 400) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      machine, (machine.pin_out lsr Xy2_100.pin) land 1 = 1)
  in
  let runs =
    List.group levels ~break:Bool.( <> )
    |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  in
  print_s [%message (runs : (bool * int) list)];
  [%expect
    {|
    (runs
     ((false 16) (true 12) (false 12) (true 12) (false 12) (true 12) (false 12)
      (true 12) (false 12) (true 12) (false 12) (true 12) (false 12) (true 12)
      (false 12) (true 12) (false 12) (true 12) (false 12) (true 12) (false 12)
      (true 12) (false 12) (true 12) (false 12) (true 12) (false 12) (true 12)
      (false 12) (true 12) (false 12) (true 12) (false 12)))
    |}]
;;

(* The deflection system: SENDCK rises and the data bit changes, SENDCK falls and the bit
   is sampled, while SYNC is high and on the bit it falls with. It checks the parity, and
   measures how long DATA is steady either side of the sample. *)
module Deflection = struct
  type t =
    { cycle : int
    ; clk : int
    ; data : int
    ; data_edge : int
    ; fall : int option
    ; rise : int option
    ; bits : int list
    ; frames : int list
    ; measured : Measured.t
    ; violations : string list
    }

  let create =
    { cycle = 0
    ; clk = 0
    ; data = 0
    ; data_edge = 0
    ; fall = None
    ; rise = None
    ; bits = []
    ; frames = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let frames t = List.rev t.frames
  let measured t = t.measured
  let violations t = List.rev t.violations

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let measure t name cycles =
    { t with
      measured =
        Measured.add t.measured ~name ~ns:(Measured.ns ~clock_hz:Bench.clock_hz cycles)
    }
  ;;

  let word bits = List.fold (List.rev bits) ~init:0 ~f:(fun w b -> (w lsl 1) lor b)

  let sample t ~sync =
    let t = measure t "tDS" (t.cycle - t.data_edge) in
    let bits = t.data :: t.bits in
    if sync = 1
    then { t with bits }
    else if List.length bits = 20
    then (
      let t = { t with bits = [] } in
      if Int.popcount (word bits) land 1 = 0
      then { t with frames = word bits :: t.frames }
      else violate t "odd parity")
    else if List.is_empty t.bits
    then t
    else violate { t with bits = [] } "SYNC fell off the twentieth bit"
  ;;

  let step t ~clk ~sync ~data =
    let t = { t with cycle = t.cycle + 1 } in
    let t =
      if data = t.data
      then t
      else (
        let t =
          match t.fall with
          | Some fall -> measure { t with fall = None } "tDH" (t.cycle - fall)
          | None -> t
        in
        { t with data; data_edge = t.cycle })
    in
    if clk = t.clk
    then t
    else if clk = 1
    then (
      let t =
        match t.rise with
        | Some rise -> measure t "SENDCK" (t.cycle - rise)
        | None -> t
      in
      { t with clk; rise = Some t.cycle })
    else sample { t with clk; fall = Some t.cycle } ~sync
  ;;
end

let words = [ 0x8000; 0x0000; 0xffff; 0x1234 ]

(* The host writes every word as the fifo has room. *)
let run ~cycles =
  let config = Timed_program.config Xy2_100.firmware in
  let machine =
    Machine.create ~config ~program:(Timed_program.words Xy2_100.firmware) |> ok_exn
  in
  let rec loop (machine : Machine.t) words deflection n =
    if n = 0
    then machine, deflection
    else (
      let machine, words =
        match words with
        | word :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine word |> ok_exn, rest
        | words -> machine, words
      in
      let machine = Machine.step machine ~inputs:0 in
      let bit pin = (machine.pin_out lsr pin) land 1 in
      loop
        machine
        words
        (Deflection.step
           deflection
           ~clk:(bit Xy2_100.clk_pin)
           ~sync:(bit Xy2_100.sync_pin)
           ~data:(bit Xy2_100.data_pin))
        (n - 1))
  in
  loop machine words Deflection.create cycles
;;

let%expect_test "the deflection system reads every setpoint the host sent" =
  let machine, deflection = run ~cycles:2_800 in
  [%test_result: int list]
    ~message:"frames"
    (Deflection.frames deflection)
    ~expect:
      (List.map (words @ [ List.last_exn words ]) ~f:(fun data -> Xy2_100.on_wire ~data));
  print_s
    [%message
      ""
        ~frames:(Deflection.frames deflection : Int.Hex.t list)
        ~measured_ns:(Deflection.measured deflection : Measured.t)
        ~violations:(Deflection.violations deflection : string list)
        (machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((frames (0x30000 0x20001 0x3ffff 0x22468 0x22468))
     (measured_ns ((tDS (250 8750)) (SENDCK (500 500)) (tDH (250 250))))
     (violations ())
     (machine.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "the deflection system refuses a bit flipped on the line" =
  let frame = Xy2_100.on_wire ~data:0x8000 in
  let bit i = (frame lsr (19 - i)) land 1 in
  let deflection =
    List.fold (List.range 0 20) ~init:Deflection.create ~f:(fun t i ->
      let data = if i = 7 then 1 - bit i else bit i in
      let sync = Bool.to_int (i < 19) in
      let t = Deflection.step t ~clk:1 ~sync ~data in
      let t =
        List.fold (List.range 0 11) ~init:t ~f:(fun t _ ->
          Deflection.step t ~clk:1 ~sync ~data)
      in
      List.fold (List.range 0 12) ~init:t ~f:(fun t _ ->
        Deflection.step t ~clk:0 ~sync ~data))
  in
  print_s
    [%message
      ""
        ~frames:(Deflection.frames deflection : Int.Hex.t list)
        ~violations:(Deflection.violations deflection : string list)];
  [%expect {| ((frames ()) (violations ("odd parity at 469"))) |}]
;;
