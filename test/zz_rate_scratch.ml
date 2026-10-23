open! Core
open Protocol_emulator

(* Scratch: an asynchronous SPI controller in continuous time against one engine, the
   pads through [lag] synchroniser flops, MISO read [tco] ns after the chip edge. *)

let tc = 1000. /. 48.

type plan =
  { events : (float * int * int) array
  ; samples : float list
  ; sent : int list
  ; finish : float
  }

let plan ~(mode : Spi_cs.Mode.t) ~half ~setup ~hold ~deselect ~start ~(pins : Spi_target.Pins.t) frames =
  let ev = ref [] in
  let samples = ref [] in
  let add at pin level = ev := (at, pin, level) :: !ev in
  let cpol = Bool.to_int mode.cpol in
  let t = ref start in
  List.iter frames ~f:(fun bytes ->
    add !t pins.cs 0;
    let t0 = !t +. setup in
    let bits =
      List.concat_map bytes ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1))
    in
    List.iteri bits ~f:(fun k bit ->
      let lead = t0 +. (2. *. Float.of_int k *. half) in
      let trail = lead +. half in
      add lead pins.sck (1 - cpol);
      add trail pins.sck cpol;
      if mode.cpha
      then (
        add lead pins.mosi bit;
        samples := trail :: !samples)
      else (
        if k = 0 then add !t pins.mosi bit else add (lead -. half) pins.mosi bit;
        samples := lead :: !samples));
    let last_trail = t0 +. (((2. *. Float.of_int (List.length bits)) -. 1.) *. half) in
    add (last_trail +. hold) pins.cs 1;
    t := last_trail +. hold +. deselect);
  let events = List.rev !ev |> List.stable_sort ~compare:(fun (a, _, _) (b, _, _) -> Float.compare a b) in
  { events = Array.of_list events; samples = List.rev !samples; sent = List.concat frames; finish = !t }
;;

(* the level of every controller pin at time [at] *)
let inputs_at plan ~(pins : Spi_target.Pins.t) ~(mode : Spi_cs.Mode.t) =
  let cs = ref 1
  and sck = ref (Bool.to_int mode.cpol)
  and mosi = ref 0
  and next = ref 0 in
  fun at ->
    while !next < Array.length plan.events && Float.( <= ) (fst3 plan.events.(!next)) at do
      let _, pin, level = plan.events.(!next) in
      if pin = pins.cs then cs := level else if pin = pins.sck then sck := level else mosi := level;
      incr next
    done;
    (!cs lsl pins.cs) lor (!sck lsl pins.sck) lor (!mosi lsl pins.mosi)
;;

let frames =
  [ [ 0xa5; 0x3c; 0x5a; 0xc3 ]; [ 0x0f; 0xf0; 0x69; 0x96 ]; [ 0x81; 0x7e; 0x55; 0xaa ] ]
;;

let replies = [ 0x12; 0xed; 0x34; 0xcb; 0x80; 0x01; 0xfe; 0x7f; 0x99; 0x66; 0x3a; 0xc5 ]

let decode plan miso ~tco =
  let bits =
    List.map plan.samples ~f:(fun s ->
      let n = Float.iround_down_exn ((s -. tco) /. tc) in
      if n < 0 || n >= Array.length miso then 0 else miso.(n))
  in
  List.chunks_of bits ~length:8
  |> List.map ~f:(List.fold ~init:0 ~f:(fun acc b -> (acc lsl 1) lor b))
;;

let run ?(rtl = false) ~source ~config ~mode ~half_cycles ~phase ?(lag = 2) ?(tco = 15.) ?setup ?hold () =
  let pins = Spi_target.pads in
  let half = half_cycles *. tc in
  let setup = Option.value setup ~default:half in
  let hold = Option.value hold ~default:half in
  let plan =
    plan ~mode ~half ~setup ~hold ~deselect:(Float.max (2. *. half) (10. *. tc))
      ~start:((40. *. tc) +. (phase *. tc)) ~pins frames
  in
  let cycles = Float.iround_up_exn (plan.finish /. tc) + 40 in
  let timed = Timed_program.of_source_exn ~config source in
  let config = Timed_program.config timed in
  let program = Timed_program.words timed in
  let level = inputs_at plan ~pins ~mode in
  let sampled = Array.init cycles ~f:(fun n -> level (Float.of_int n *. tc)) in
  let idle = (1 lsl pins.cs) lor (Bool.to_int mode.cpol lsl pins.sck) in
  let inputs n = if n - lag < 0 then idle else sampled.(n - lag) in
  let miso = Array.create ~len:cycles 0 in
  let rx, mismatch =
    if rtl
    then (
      let step = ref 0 in
      let react (m : Machine.t) =
        if !step < cycles then miso.(!step) <- (m.pin_out lsr pins.miso) land 1;
        incr step
      in
      let m, mismatch =
        Lockstep.run ~cycles ~preload:(List.map replies ~f:(fun r -> r lsl 8)) ~react ~config ~program ~inputs ()
      in
      m.rx_fifo, Option.is_some mismatch)
    else (
      let m =
        List.fold replies ~init:(Machine.create ~config ~program |> ok_exn) ~f:(fun m r ->
          Machine.write_tx m (r lsl 8) |> ok_exn)
      in
      let m = ref m in
      for n = 0 to cycles - 1 do
        m := Machine.step !m ~inputs:(inputs n);
        miso.(n) <- (!m.pin_out lsr pins.miso) land 1
      done;
      !m.rx_fifo, false)
  in
  let got = decode plan miso ~tco in
  (not mismatch) && [%equal: int list] rx plan.sent && [%equal: int list] got replies
;;

let old_ mode = Spi_target.firmware ~mode Spi_target.pads, Spi_target.config Spi_target.pads
let fast_ mode = Spi_target.fast ~mode Spi_target.pads, Spi_target.fast_config Spi_target.pads
let phases = [ 0.; 0.13; 0.37; 0.5; 0.71; 0.93 ]

let grid = List.init 69 ~f:(fun i -> 3. +. (0.25 *. Float.of_int i))

(* the least half period from which every grid point up to 20 cycles passes *)
let least ?lag ?tco ?setup ?hold (source, config) mode =
  let passes h =
    List.for_all phases ~f:(fun phase -> run ~source ~config ~mode ~half_cycles:h ~phase ?lag ?tco ?setup ?hold ())
  in
  (* from the top down: stop at the first failure *)
  let rec down best = function
    | [] -> best
    | h :: rest -> if passes h then down (Some h) rest else best
  in
  down None (List.rev grid)
;;

let mhz h = 48. /. (2. *. h)

let%expect_test "scratch rates" =
  List.iter [ "old", old_; "fast", fast_ ] ~f:(fun (name, fw) ->
    List.iter Spi_cs.Mode.all ~f:(fun mode ->
      let wire = least ~lag:0 ~tco:0.1 (fw mode) mode in
      let pad = least (fw mode) mode in
      let show = Option.value_map ~default:"-" ~f:(fun h -> sprintf "%.2f (%.2f MHz)" h (mhz h)) in
      printf "%s mode %d: lag0 %s, pads %s\n" name (Spi_cs.Mode.to_int mode) (show wire) (show pad)));
  [%expect {| |}]
;;
