open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Tdm_audio.firmware));
  [%expect {| 117 words, 0 deadline waits |}]
;;

(* SCLK, level by level with the cycles each lasted, for one host word. *)
let%expect_test "SCLK for one host word" =
  let machine =
    Machine.create
      ~config:(Timed_program.config Tdm_audio.firmware)
      ~program:(Timed_program.words Tdm_audio.firmware)
    |> ok_exn
  in
  let machine = Machine.write_tx machine 0x55 |> ok_exn in
  let levels =
    List.folding_map (List.range 0 400) ~init:machine ~f:(fun machine _ ->
      let machine = Machine.step machine ~inputs:0 in
      machine, (machine.pin_out lsr Tdm_audio.pin) land 1 = 1)
  in
  let runs =
    List.group levels ~break:Bool.( <> )
    |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
  in
  print_s [%message (runs : (bool * int) list)];
  [%expect
    {|
    (runs
     ((false 5) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 3) (true 3) (false 3)
      (true 3) (false 3) (true 3) (false 3) (true 3) (false 2)))
    |}]
;;

(* A converter in the clock slave format (AN301 p.3, Figures 4 and 6). It reads SDATA and
   FSYNC as SCLK rises. FSYNC seen rising marks that bit the last of the frame, and the
   frame's bits are eight 32-bit blocks of which it keeps the top 24, ignoring the pad. *)
module Converter = struct
  type t =
    { cycle : int
    ; clk : int
    ; sync : int
    ; rise : int option
    ; frame_start : int option
    ; bits : int list
    ; frames : int list list
    ; measured : Measured.t
    ; violations : string list
    }

  let create =
    { cycle = 0
    ; clk = 0
    ; sync = 0
    ; rise = None
    ; frame_start = None
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

  let word bits = List.fold bits ~init:0 ~f:(fun w b -> (w lsl 1) lor b)
  let frame_bits = Tdm_audio.channels * Tdm_audio.block_bits

  let end_frame t =
    let bits = List.rev t.bits in
    if List.length bits <> frame_bits
    then violate t [%string "a frame of %{List.length bits#Int} bits"]
    else (
      let audio =
        List.chunks_of bits ~length:Tdm_audio.block_bits
        |> List.map ~f:(fun block -> word (List.take block 24))
      in
      { t with frames = audio :: t.frames })
  ;;

  let read t ~sync ~data =
    let t =
      match t.rise with
      | Some rise -> measure t "SCLK" (t.cycle - rise)
      | None -> t
    in
    let t = { t with rise = Some t.cycle; bits = data :: t.bits } in
    let rising = sync = 1 && t.sync = 0 in
    let t = { t with sync } in
    if not rising
    then t
    else (
      let t =
        match t.frame_start with
        | Some start -> measure (end_frame t) "frame" (t.cycle - start)
        | None -> t
      in
      { t with bits = []; frame_start = Some t.cycle })
  ;;

  let step t ~clk ~sync ~data =
    let t = { t with cycle = t.cycle + 1 } in
    if clk = t.clk
    then t
    else if clk = 1
    then read { t with clk } ~sync ~data
    else { t with clk }
  ;;
end

(* two frames of samples, then one of silence *)
let samples = Tdm_audio.samples @ List.map Tdm_audio.samples ~f:(fun s -> 0xffff - s)

(* The host writes every sample as the fifo has room. *)
let run ~cycles =
  let config = Timed_program.config Tdm_audio.firmware in
  let machine =
    Machine.create ~config ~program:(Timed_program.words Tdm_audio.firmware) |> ok_exn
  in
  let rec loop (machine : Machine.t) samples converter n =
    if n = 0
    then machine, converter
    else (
      let machine, samples =
        match samples with
        | sample :: rest when List.length machine.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx machine sample |> ok_exn, rest
        | samples -> machine, samples
      in
      let machine = Machine.step machine ~inputs:0 in
      let bit pin = (machine.pin_out lsr pin) land 1 in
      loop
        machine
        samples
        (Converter.step
           converter
           ~clk:(bit Tdm_audio.clk_pin)
           ~sync:(bit Tdm_audio.sync_pin)
           ~data:(bit Tdm_audio.data_pin))
        (n - 1))
  in
  loop machine samples Converter.create cycles
;;

let%expect_test "the converter reads every sample the host sent, then silence" =
  let machine, converter = run ~cycles:4_800 in
  let audio = List.map ~f:(fun sample -> Tdm_audio.audio_word ~sample) in
  [%test_result: int list list]
    ~message:"frames"
    (Converter.frames converter)
    ~expect:
      (List.chunks_of samples ~length:Tdm_audio.channels
       |> List.map ~f:audio
       |> Fn.flip List.append [ List.init Tdm_audio.channels ~f:(Fn.const 0) ]);
  print_s
    [%message
      ""
        ~frames:(Converter.frames converter : Int.Hex.t list list)
        ~measured_ns:(Converter.measured converter : Measured.t)
        ~violations:(Converter.violations converter : string list)
        (machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((frames
      ((0x800000 0x7fff00 0x123400 0xa5a500 0x100 0xffff00 0x555500 0xc3c300)
       (0x7fff00 0x800000 0xedcb00 0x5a5a00 0xfffe00 0x0 0xaaaa00 0x3c3c00)
       (0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x0)))
     (measured_ns ((SCLK (125 125)) (frame (32000 32000)))) (violations ())
     (machine.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* FSYNC a bit early: the frame is a bit short and the converter refuses it. *)
let%expect_test "the converter refuses a short frame" =
  let bit t ~sync ~data =
    let t = Converter.step t ~clk:0 ~sync ~data in
    Converter.step t ~clk:1 ~sync ~data
  in
  let frame length =
    List.init length ~f:(fun i -> if i = length - 1 then 1, 0 else 0, 1)
  in
  let converter =
    List.fold
      (frame 1 @ frame Converter.frame_bits @ frame (Converter.frame_bits - 1))
      ~init:Converter.create
      ~f:(fun t (sync, data) -> bit t ~sync ~data)
  in
  print_s
    [%message
      ""
        ~frames:(List.length (Converter.frames converter) : int)
        ~violations:(Converter.violations converter : string list)];
  [%expect {| ((frames 1) (violations ("a frame of 255 bits at 1024"))) |}]
;;
