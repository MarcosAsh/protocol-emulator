open! Core
open Protocol_emulator

(* what the analyser and the kernel make of the firmware, which compiling it checked *)
let%expect_test "the firmware's verdict" =
  print_endline (Analyser.Verdict.to_string (Timed_program.verdict Spdif.firmware));
  [%expect {| 108 words, 40 deadline waits, worst slack 2 |}]
;;

(* The far end, fed the line every cycle. Each pulse is the whole half slots nearest its
   length, at 128 a frame of 44.1 kHz; a preamble is the only pulse of three, and sigrok's
   B, M and W are 3113, 3311 and 3212. A subframe's 28 bits after it have even parity, the
   16-bit sample in bits 8 to 23, LSB first, and the rest 0. *)
module Receiver = struct
  module Preamble = struct
    type t =
      | B
      | M
      | W
    [@@deriving sexp_of, equal]

    let of_halves = function
      | [ 3; 1; 1; 3 ] -> Some B
      | [ 3; 3; 1; 1 ] -> Some M
      | [ 3; 2; 1; 2 ] -> Some W
      | _ -> None
    ;;
  end

  module Mode = struct
    type t =
      | Hunting
      | Preamble of
          { halves : int list
          ; start : int
          }
      | Data of
          { preamble : Preamble.t
          ; bits : int list
          ; half_one : bool
          }
  end

  type t =
    { clock_hz : int
    ; now : int
    ; level : bool option
    ; run : int
    ; mode : Mode.t
    ; left : (Preamble.t * int) option
    ; last_start : int option
    ; since_b : int option
    ; frames : string list
    ; blocks : int list
    ; measured : Measured.t
    ; errors : string list
    }

  let half_ns = 1e9 /. (44_100. *. 128.)

  let create ~clock_hz =
    { clock_hz
    ; now = 0
    ; level = None
    ; run = 0
    ; mode = Hunting
    ; left = None
    ; last_start = None
    ; since_b = None
    ; frames = []
    ; blocks = []
    ; measured = Measured.empty
    ; errors = []
    }
  ;;

  let error t line = { t with errors = line :: t.errors; mode = Hunting; left = None }

  let subframe t preamble bits =
    let word lo hi =
      List.sub bits ~pos:lo ~len:(hi - lo + 1)
      |> List.foldi ~init:0 ~f:(fun i acc b -> acc lor (b lsl i))
    in
    let sample = word 8 23 in
    if List.sum (module Int) bits ~f:Fn.id % 2 <> 0
    then error t "parity"
    else if word 0 7 <> 0 || word 24 26 <> 0
    then error t (sprintf "aux, V, U or C set: 0x%x 0x%x" (word 0 7) (word 24 26))
    else (
      match (preamble : Preamble.t), t.left with
      | (B | M), None -> { t with left = Some (preamble, sample) }
      | W, Some (first, left) ->
        let line = sprintf !"%{sexp:Preamble.t} 0x%04x 0x%04x" first left sample in
        { t with frames = line :: t.frames; left = None }
      | _ -> error t (sprintf !"%{sexp:Preamble.t} out of turn" preamble))
  ;;

  (* a frame starts at its B or M: the time since the last one, and the frames since B *)
  let frame_start t (preamble : Preamble.t) ~start =
    let t =
      match t.last_start with
      | Some last ->
        { t with
          measured =
            Measured.add
              t.measured
              ~name:"frame"
              ~ns:(Measured.ns ~clock_hz:t.clock_hz (start - last))
        }
      | None -> t
    in
    let t = { t with last_start = Some start } in
    match preamble, t.since_b with
    | B, Some n -> { t with blocks = (n + 1) :: t.blocks; since_b = Some 0 }
    | B, None -> { t with since_b = Some 0 }
    | M, Some n -> { t with since_b = Some (n + 1) }
    | M, None | W, _ -> t
  ;;

  let pulse t ~cycles =
    let ns = Float.of_int cycles *. 1e9 /. Float.of_int t.clock_hz in
    let halves = Float.iround_nearest_exn (ns /. half_ns) in
    let t =
      if halves >= 1 && halves <= 3
      then
        { t with
          measured =
            Measured.add
              t.measured
              ~name:(sprintf "%d half" halves)
              ~ns:(Measured.ns ~clock_hz:t.clock_hz cycles)
        }
      else t
    in
    let start = t.now - cycles in
    match t.mode, halves with
    | Hunting, 3 -> { t with mode = Preamble { halves = [ 3 ]; start } }
    | Hunting, _ -> t
    | Preamble { halves = h; start }, _ ->
      let h = halves :: h in
      if List.length h < 4
      then { t with mode = Preamble { halves = h; start } }
      else (
        match Preamble.of_halves (List.rev h) with
        | None -> error t (sprintf !"preamble %{sexp:int list}" (List.rev h))
        | Some preamble ->
          let t =
            if Preamble.equal preamble W then t else frame_start t preamble ~start
          in
          { t with mode = Data { preamble; bits = []; half_one = false } })
    | Data { preamble; bits; half_one }, _ ->
      let next bits half_one =
        if List.length bits = 28
        then { (subframe t preamble (List.rev bits)) with mode = Hunting }
        else { t with mode = Data { preamble; bits; half_one } }
      in
      (match halves, half_one with
       | 2, false -> next (0 :: bits) false
       | 1, false -> next bits true
       | 1, true -> next (1 :: bits) false
       | 3, false when List.is_empty bits -> error t "preamble with no data"
       | _ -> error t (sprintf "pulse of %d halves in a bit" halves))
  ;;

  (* the run before the first edge is idle, not a pulse *)
  let step t ~level =
    let t =
      match t.level with
      | Some was when Bool.equal was level -> { t with run = t.run + 1 }
      | Some _ when t.run = t.now -> { t with run = 1; level = Some level }
      | Some _ -> { (pulse t ~cycles:t.run) with run = 1; level = Some level }
      | None -> { t with run = 1; level = Some level }
    in
    { t with now = t.now + 1 }
  ;;

  let print ?(frames = Fn.id) t =
    print_s
      [%message
        ""
          ~frames:(frames (List.rev t.frames) : string list)
          ~blocks:(List.rev t.blocks : int list)
          ~measured_ns:(t.measured : Measured.t)
          ~errors:(List.rev t.errors : string list)]
  ;;
end

let run ?frames ~words ~cycles () =
  let machine =
    Machine.create
      ~config:(Timed_program.config Spdif.firmware)
      ~program:(Timed_program.words Spdif.firmware)
    |> ok_exn
  in
  let machine =
    List.fold words ~init:machine ~f:(fun m w -> Machine.write_tx m w |> ok_exn)
  in
  let machine, receiver =
    Fn.apply_n_times
      ~n:cycles
      (fun ((machine : Machine.t), receiver) ->
        let machine = Machine.step machine ~inputs:0 in
        machine, Receiver.step receiver ~level:((machine.pin_out lsr Spdif.pin) land 1 = 1))
      (machine, Receiver.create ~clock_hz:Bench.clock_hz)
  in
  Receiver.print ?frames receiver;
  print_s [%message "" ~fault:(machine.fault : Machine.Fault.t)]
;;

(* Three stereo frames, then silence as the fifo runs dry *)
let%expect_test "stereo 16-bit samples at 44.1 kHz" =
  run ~words:[ 0x1234; 0xfedc; 0x8001; 0x7ffe; 0x00ff; 0xa5a5 ] ~cycles:(6 * 1089) ();
  [%expect
    {|
    ((frames
      ("B 0x1234 0xfedc" "M 0x8001 0x7ffe" "M 0x00ff 0xa5a5" "M 0x0000 0x0000"
       "M 0x0000 0x0000"))
     (blocks ())
     (measured_ns
      (("3 half" (521 542)) ("1 half" (167 188)) ("2 half" (354 375))
       (frame (22667 22688))))
     (errors ()))
    (fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;

(* B every 192 frames, M between: a block, and the frame periods in it *)
let%expect_test "a block of 192 frames" =
  run
    ~frames:(fun frames -> List.take frames 2)
    ~words:[ 0x0001; 0x8000 ]
    ~cycles:(194 * 1089)
    ();
  [%expect
    {|
    ((frames ("B 0x0001 0x8000" "M 0x0000 0x0000")) (blocks (192))
     (measured_ns
      (("3 half" (521 542)) ("1 half" (167 188)) ("2 half" (354 375))
       (frame (22667 22688))))
     (errors ()))
    (fault
     ((underflow false) (overflow false) (missed_deadline false) (decode false)))
    |}]
;;
