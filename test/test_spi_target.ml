open! Core
open Protocol_emulator
open Both_roles

let spi_case = List.find_exn Case.all ~f:(fun c -> String.is_prefix c.name ~prefix:"SPI")

(* what every mode pushes at the cases' half period *)
let spi_expected =
  model
    ~cycles:spi_case.cycles
    ~controller:{ timed = spi_case.controller; words = spi_case.controller_words }
    ~target:{ timed = spi_case.target; words = spi_case.target_words }
    ()
;;

(* each target, its source and config on any pins, and the least half period it claims *)
let targets =
  [ "firmware", Spi_target.firmware, Spi_target.config, Spi_target.shortest_half
  ; "fast", Spi_target.fast, Spi_target.fast_config, Spi_target.fast_shortest_half
  ]
;;

let spi_ok ~source ~config ~mode ~half_period ~hold ~deselect =
  let expected = spi_expected in
  let outcome =
    model
      ~cycles:(1000 + (150 * half_period))
      ~controller:
        { timed =
            Timed_program.of_source_exn
              ~config:Wire_spi.controller_config
              (Spi_cs.master
                 ~mode
                 ~half_period
                 ~setup:Spi_cs.shortest_setup
                 ~hold
                 ~deselect)
        ; words = spi_case.controller_words
        }
      ~target:
        { timed =
            Timed_program.of_source_exn
              ~config:(config Wire_spi.pins)
              (source ~mode Wire_spi.pins)
        ; words = spi_case.target_words
        }
      ()
  in
  [%equal: int list] outcome.controller expected.controller
  && [%equal: int list] outcome.target expected.target
;;

(* Every half period up to the master's 31, with CS held and kept high as briefly and as
   long as the master allows. *)
let%expect_test "the target keeps up from its shortest half period" =
  List.iter targets ~f:(fun (name, source, config, shortest) ->
    let passes half_period =
      List.for_all Spi_cs.Mode.all ~f:(fun mode ->
        List.for_all
          [ Spi_cs.shortest_hold, 9; Spi_cs.longest_hold, 40 ]
          ~f:(fun (hold, deselect) ->
            spi_ok ~source ~config ~mode ~half_period ~hold ~deselect))
    in
    print_s
      [%message
        name
          ~from_shortest:(List.for_all (List.range shortest 32) ~f:passes : bool)
          ~one_less:(passes (shortest - 1) : bool)]);
  [%expect
    {|
    (firmware (from_shortest true) (one_less false))
    (fast (from_shortest true) (one_less false))
    |}]
;;

let%expect_test "the kernel accepts the fast target in every mode" =
  List.iter Spi_cs.Mode.all ~f:(fun mode ->
    let timed =
      Timed_program.of_source_exn
        ~config:(Spi_target.fast_config Spi_target.pads)
        (Spi_target.fast ~mode Spi_target.pads)
    in
    let config = Timed_program.config timed in
    let words = Timed_program.words timed in
    let table = Kernel.Table.of_analyser (Timed_program.rows timed) in
    print_s
      [%message
        ""
          ~mode:(Spi_cs.Mode.to_int mode : int)
          ~words:(List.length words : int)
          ~kernel:(Kernel.check ~config ~words table : unit Or_error.t)]);
  [%expect
    {|
    ((mode 0) (words 36) (kernel (Ok ())))
    ((mode 1) (words 36) (kernel (Ok ())))
    ((mode 2) (words 37) (kernel (Ok ())))
    ((mode 3) (words 37) (kernel (Ok ())))
    |}]
;;

(* A controller on a clock of its own, across the pads, in ns: each pin reaches the core
   through the top's two flops, and MISO is read [delay] after the chip's edge that drives
   it, the pad, the board and the controller's setup together. CS falls and rises a half
   period from SCK and stays high two half periods, and 10 cycles at least. *)
module Over_pads = struct
  let cycle = 1000. /. 48.
  let flops = 2
  let delay = 15.
  let pins = Spi_target.pads

  let frames =
    [ [ 0xa5; 0x3c; 0x5a; 0xc3 ]; [ 0x0f; 0xf0; 0x69; 0x96 ]; [ 0x81; 0x7e; 0x55; 0xaa ] ]
  ;;

  let sent = List.concat frames
  let replies = [ 0x12; 0xed; 0x34; 0xcb; 0x80; 0x01; 0xfe; 0x7f; 0x99; 0x66; 0x3a; 0xc5 ]

  (* where the controller's first edge falls against the chip's clock, in cycles *)
  let phases = [ 0.; 0.13; 0.37; 0.5; 0.71; 0.93 ]

  (* each move as time, pin and level, in time order, and where MISO is read *)
  type plan =
    { moves : (float * int * int) list
    ; samples : float list
    ; finish : float
    }

  let plan ~(mode : Spi_cs.Mode.t) ~half ~phase =
    let idle = Bool.to_int mode.cpol in
    let deselect = Float.max (2. *. half) (10. *. cycle) in
    let start = (40. +. phase) *. cycle in
    let frame (moves, samples, select) bytes =
      let bits =
        List.concat_map bytes ~f:(fun byte ->
          List.init 8 ~f:(fun i -> (byte lsr (7 - i)) land 1))
      in
      let first = select +. half in
      let edges =
        List.concat_mapi bits ~f:(fun k bit ->
          let leading = first +. (2. *. Float.of_int k *. half) in
          let trailing = leading +. half in
          (* CPHA 0 shows the bit before its leading edge, the first as CS falls *)
          let shown =
            if mode.cpha then leading else if k = 0 then select else leading -. half
          in
          [ leading, pins.sck, 1 - idle; trailing, pins.sck, idle; shown, pins.mosi, bit ])
      in
      let sampled =
        List.mapi bits ~f:(fun k _ ->
          first +. (2. *. Float.of_int k *. half) +. if mode.cpha then half else 0.)
      in
      let rise =
        first +. (((2. *. Float.of_int (List.length bits)) -. 1.) *. half) +. half
      in
      ( moves @ [ select, pins.cs, 0 ] @ edges @ [ rise, pins.cs, 1 ]
      , samples @ sampled
      , rise +. deselect )
    in
    let moves, samples, finish = List.fold frames ~init:([], [], start) ~f:frame in
    { moves =
        List.stable_sort moves ~compare:(fun (a, _, _) (b, _, _) -> Float.compare a b)
    ; samples
    ; finish
    }
  ;;

  (* the pins as the core reads them each cycle, [flops] cycles late *)
  let inputs plan ~(mode : Spi_cs.Mode.t) ~cycles =
    let idle = (1 lsl pins.cs) lor (Bool.to_int mode.cpol lsl pins.sck) in
    let levels = Array.create ~len:cycles idle in
    let level = ref idle
    and moves = ref plan.moves in
    for n = 0 to cycles - 1 do
      let rec apply () =
        match !moves with
        | (at, pin, bit) :: rest when Float.( <= ) at (Float.of_int n *. cycle) ->
          level := !level land lnot (1 lsl pin) lor (bit lsl pin);
          moves := rest;
          apply ()
        | _ -> ()
      in
      apply ();
      levels.(n) <- !level
    done;
    fun n -> if n < flops then idle else levels.(n - flops)
  ;;

  (* The bytes the target pushed and the replies the controller read, run on the model, or
     on the RTL beside it when [rtl]: [None] if the two part. *)
  let run ?(rtl = false) ~(timed : Timed_program.t) ~mode ~half ~phase () =
    let plan = plan ~mode ~half:(half *. cycle) ~phase in
    let cycles = Float.iround_up_exn (plan.finish /. cycle) + 40 in
    let config = Timed_program.config timed in
    let program = Timed_program.words timed in
    let inputs = inputs plan ~mode ~cycles in
    let miso = Array.create ~len:(cycles + 1) 0 in
    let step = ref 0 in
    let react (m : Machine.t) =
      miso.(!step) <- (m.pin_out lsr pins.miso) land 1;
      incr step
    in
    let preload = List.map replies ~f:(fun byte -> byte lsl 8) in
    let pushed =
      if rtl
      then (
        let m, mismatch =
          Lockstep.run ~cycles ~preload ~react ~config ~program ~inputs ()
        in
        Option.some_if (Option.is_none mismatch) m.rx_fifo)
      else (
        let m =
          List.fold
            preload
            ~init:(Machine.create ~config ~program |> ok_exn)
            ~f:(fun m w -> Machine.write_tx m w |> ok_exn)
        in
        let m =
          List.fold (List.range 0 cycles) ~init:m ~f:(fun m n ->
            let m = Machine.step m ~inputs:(inputs n) in
            react m;
            m)
        in
        Some m.rx_fifo)
    in
    let read =
      List.map plan.samples ~f:(fun at ->
        miso.(Int.max 0 (Float.iround_down_exn ((at -. delay) /. cycle))))
      |> List.chunks_of ~length:8
      |> List.map ~f:(List.fold ~init:0 ~f:(fun byte bit -> (byte lsl 1) lor bit))
    in
    Option.map pushed ~f:(fun pushed -> pushed, read)
  ;;

  let passes ?rtl ~timed ~mode half =
    List.for_all phases ~f:(fun phase ->
      match run ?rtl ~timed ~mode ~half ~phase () with
      | Some (pushed, read) ->
        [%equal: int list] pushed sent && [%equal: int list] read replies
      | None -> false)
  ;;

  (* down from [most] a quarter cycle at a time, to the last before a failure *)
  let most = 16.

  let least ~timed ~mode =
    let rec down half =
      let lower = half -. 0.25 in
      if Float.( > ) lower 0. && passes ~timed ~mode lower then down lower else half
    in
    if passes ~timed ~mode most then Some (down most) else None
  ;;
end

(* The least half period, in quarter cycles, from which every one up to 16 passes in every
   phase on the model, and on the RTL at that least; SCK in MHz at 48 MHz. *)
let%expect_test "the least half period over the pads" =
  List.iter targets ~f:(fun (name, source, config, _) ->
    List.iter Spi_cs.Mode.all ~f:(fun mode ->
      let timed =
        Timed_program.of_source_exn
          ~config:(config Over_pads.pins)
          (source ~mode Over_pads.pins)
      in
      let least = Over_pads.least ~timed ~mode in
      let rtl =
        Option.map least ~f:(fun half -> Over_pads.passes ~rtl:true ~timed ~mode half)
      in
      let mhz = Option.map least ~f:(fun half -> sprintf "%.2f" (48. /. (2. *. half))) in
      print_s
        [%message
          name
            ~mode:(Spi_cs.Mode.to_int mode : int)
            (least : float option)
            (mhz : string option)
            (rtl : bool option)]));
  [%expect
    {|
    (firmware (mode 0) (least (10)) (mhz (2.40)) (rtl (true)))
    (firmware (mode 1) (least (15.5)) (mhz (1.55)) (rtl (true)))
    (firmware (mode 2) (least (13.5)) (mhz (1.78)) (rtl (true)))
    (firmware (mode 3) (least (15.5)) (mhz (1.55)) (rtl (true)))
    (fast (mode 0) (least (8)) (mhz (3.00)) (rtl (true)))
    (fast (mode 1) (least (5.5)) (mhz (4.36)) (rtl (true)))
    (fast (mode 2) (least (8)) (mhz (3.00)) (rtl (true)))
    (fast (mode 3) (least (5.75)) (mhz (4.17)) (rtl (true)))
    |}]
;;
