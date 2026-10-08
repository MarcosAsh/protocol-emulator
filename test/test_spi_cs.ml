open! Core
open Protocol_emulator
open Spi_cs

let bit v i = (v lsr i) land 1

(* the core, its host keeping up but for the [late] word's index held back to a cycle,
   against a [Device] *)
let run ?(cycles = 2000) ?late ~mode ~half_period ~setup ~hold frames =
  let program =
    Timed_program.of_source_exn ~config (master ~mode ~half_period ~setup ~hold)
  in
  let t =
    Machine.create
      ~config:(Timed_program.config program)
      ~program:(Timed_program.words program)
    |> ok_exn
  in
  (* every word is due at once but the late one *)
  let schedule =
    List.concat_map frames ~f:words
    |> List.mapi ~f:(fun i word ->
      match late with
      | Some (late, cycle) when i = late -> cycle, word
      | Some _ | None -> 0, word)
  in
  let rec loop (t : Machine.t) device schedule received trace n =
    if n = cycles
    then t, device, List.rev received, List.rev trace
    else (
      let t, schedule = Machine_run.feed_due t schedule ~now:n in
      let miso = Device.miso device in
      let t = Machine.step t ~inputs:(miso lsl miso_pin) in
      let device =
        Device.step
          device
          ~cs:(bit t.pin_out cs_pin)
          ~sck:(bit t.pin_out sck_pin)
          ~mosi:(bit t.pin_out mosi_pin)
      in
      let t, received = Machine_run.receive t received in
      loop t device schedule received ((t.pin_out, miso) :: trace) (n + 1))
  in
  loop t (Device.create ~mode ~first:0x5a) schedule [] [] 0
;;

let frames = [ [ 0x9f; 0x00; 0x00; 0x00 ]; [ 0xa5 ]; [ 0x3c; 0xc3 ] ]

(* the flash act's: 3 MHz at the bench's 48 *)
let half_period = 8
let setup = 4
let hold = 8

let%expect_test "each mode against a slave of that mode" =
  List.iter Mode.all ~f:(fun mode ->
    let machine, device, received, _ = run ~mode ~half_period ~setup ~hold frames in
    print_s
      [%message
        ""
          ~mode:(Mode.to_int mode : int)
          ~frames:(Device.frames device : int list list)
          (received : int list)
          ~measured_cycles:(Device.measured device : Measured.t)
          ~violations:(Device.violations device : string list)
          ~fault:(machine.fault : Machine.Fault.t)]);
  [%expect
    {|
    ((mode 0) (frames ((159 0 0 0) (165) (60 195)))
     (received (90 96 255 255 90 90 195))
     (measured_cycles
      ((setup (4 4)) ("SCK high" (8 8)) ("SCK low" (8 18)) (hold (8 8))
       ("CS low" (132 546)) ("CS high" (9 9))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((mode 1) (frames ((159 0 0 0) (165) (60 195)))
     (received (90 96 255 255 90 90 195))
     (measured_cycles
      ((setup (4 4)) ("SCK high" (8 8)) ("SCK low" (8 18)) (hold (8 8))
       ("CS low" (132 546)) ("CS high" (9 9))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((mode 2) (frames ((159 0 0 0) (165) (60 195)))
     (received (90 96 255 255 90 90 195))
     (measured_cycles
      ((setup (4 4)) ("SCK low" (8 8)) ("SCK high" (8 18)) (hold (8 8))
       ("CS low" (132 546)) ("CS high" (9 9))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((mode 3) (frames ((159 0 0 0) (165) (60 195)))
     (received (90 96 255 255 90 90 195))
     (measured_cycles
      ((setup (4 4)) ("SCK low" (8 8)) ("SCK high" (8 18)) (hold (8 8))
       ("CS low" (132 546)) ("CS high" (9 9))))
     (violations ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* 0xa5 with 0x5a back, as each pin's runs of a level from the start, MISO as the core
   sees it *)
let%expect_test "the four modes' waveforms" =
  List.iter Mode.all ~f:(fun mode ->
    let _, _, _, trace = run ~cycles:170 ~mode ~half_period ~setup ~hold [ [ 0xa5 ] ] in
    let runs f = Protocol_models.runs (List.map trace ~f) in
    print_s
      [%message
        ""
          ~mode:(Mode.to_int mode : int)
          ~cs:(runs (fun (o, _) -> bit o cs_pin) : (int * int) list)
          ~sck:(runs (fun (o, _) -> bit o sck_pin) : (int * int) list)
          ~mosi:(runs (fun (o, _) -> bit o mosi_pin) : (int * int) list)
          ~miso:(runs snd : (int * int) list)]);
  [%expect
    {|
    ((mode 0) (cs ((1 7) (0 132) (1 31)))
     (sck
      ((0 11) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8)
       (1 8) (0 8) (1 8) (0 8) (1 8) (0 39)))
     (mosi ((0 7) (1 12) (0 16) (1 16) (0 32) (1 16) (0 16) (1 55)))
     (miso ((1 8) (0 12) (1 16) (0 16) (1 32) (0 16) (1 16) (0 24) (1 30))))
    ((mode 1) (cs ((1 7) (0 132) (1 31)))
     (sck
      ((0 11) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8)
       (1 8) (0 8) (1 8) (0 8) (1 8) (0 39)))
     (mosi ((0 11) (1 16) (0 16) (1 16) (0 32) (1 16) (0 16) (1 47)))
     (miso ((1 12) (0 16) (1 16) (0 16) (1 32) (0 16) (1 16) (0 16) (1 30))))
    ((mode 2) (cs ((1 7) (0 132) (1 31)))
     (sck
      ((1 11) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8)
       (0 8) (1 8) (0 8) (1 8) (0 8) (1 39)))
     (mosi ((0 7) (1 12) (0 16) (1 16) (0 32) (1 16) (0 16) (1 55)))
     (miso ((1 8) (0 12) (1 16) (0 16) (1 32) (0 16) (1 16) (0 24) (1 30))))
    ((mode 3) (cs ((1 7) (0 132) (1 31)))
     (sck
      ((1 11) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8) (0 8) (1 8)
       (0 8) (1 8) (0 8) (1 8) (0 8) (1 39)))
     (mosi ((0 11) (1 16) (0 16) (1 16) (0 32) (1 16) (0 16) (1 47)))
     (miso ((1 12) (0 16) (1 16) (0 16) (1 32) (0 16) (1 16) (0 16) (1 30))))
    |}]
;;

(* The host's second byte comes 300 cycles late: CS stays low and SCK idle meanwhile. *)
let%expect_test "a slow host holds the frame open" =
  let mode = Mode.of_int 0 in
  let _, device, received, _ =
    run ~late:(1, 300) ~mode ~half_period ~setup ~hold [ [ 0x9f; 0x12 ] ]
  in
  print_s
    [%message
      ""
        ~frames:(Device.frames device : int list list)
        (received : int list)
        ~measured_cycles:(Device.measured device : Measured.t)
        ~violations:(Device.violations device : string list)];
  [%expect
    {|
    ((frames ((159 18))) (received (90 96))
     (measured_cycles
      ((setup (4 4)) ("SCK high" (8 8)) ("SCK low" (8 183)) (hold (8 8))
       ("CS low" (435 435))))
     (violations ()))
    |}]
;;

let check ~mode ~half_period ~setup ~hold =
  Timed_program.check ~config (master ~mode ~half_period ~setup ~hold) |> Result.is_ok
;;

let%expect_test "the shortest half period" =
  List.iter Mode.all ~f:(fun mode ->
    let check half_period =
      check ~mode ~half_period ~setup:shortest_setup ~hold:shortest_hold
    in
    print_s
      [%message
        ""
          ~mode:(Mode.to_int mode : int)
          (check shortest_half : bool)
          (check (shortest_half - 1) : bool)]);
  [%expect
    {|
    ((mode 0) ("check shortest_half" true) ("check (shortest_half - 1)" false))
    ((mode 1) ("check shortest_half" true) ("check (shortest_half - 1)" false))
    ((mode 2) ("check shortest_half" true) ("check (shortest_half - 1)" false))
    ((mode 3) ("check shortest_half" true) ("check (shortest_half - 1)" false))
    |}]
;;

let%expect_test "the kernel accepts each mode at the flash act's parameters" =
  List.iter Mode.all ~f:(fun mode ->
    let program = Asm.assemble (master ~mode ~half_period ~setup ~hold) |> ok_exn in
    let config = Asm.Program.configure program config in
    let words = Asm.Program.words program |> ok_exn in
    let rows = Analyser.analyse ~config program.instructions in
    print_s
      [%message
        ""
          ~mode:(Mode.to_int mode : int)
          ~kernel:
            (Kernel.check ~config ~words (Kernel.Table.of_analyser rows)
             : unit Or_error.t)]);
  [%expect
    {|
    ((mode 0) (kernel (Ok ())))
    ((mode 1) (kernel (Ok ())))
    ((mode 2) (kernel (Ok ())))
    ((mode 3) (kernel (Ok ())))
    |}]
;;

(* SCK is pin a and CS pin b: SCK holds each level [half_period], its edges come [setup]
   after CS falls, CS rises [hold] after SCK's last edge and stays high [deselect]. *)
let spacing ~half_period ~setup ~hold ~deselect =
  { Kernel.Spacing.Spec.a = sck_pin
  ; b = cs_pin
  ; dirs = false
  ; hold_a = (fun ~own:_ ~other -> if other then 0 else half_period)
  ; apart_a = (fun ~own:_ ~other -> if other then 0 else setup)
  ; hold_b = (fun ~own ~other:_ -> if own then deselect else 0)
  ; apart_b = (fun ~own ~other:_ -> if own then 0 else hold)
  }
;;

let spaced ~mode spec =
  let program = Asm.assemble (master ~mode ~half_period ~setup ~hold) |> ok_exn in
  let config = Asm.Program.configure program config in
  let words = Asm.Program.words program |> ok_exn in
  let rows = Analyser.analyse ~config program.instructions in
  let table =
    Kernel.Table.with_edges
      (Kernel.Table.of_analyser rows)
      ~config
      ~spacing:(Kernel.Spacing.of_spec config spec)
      ~words
  in
  Kernel.check ~spacing:spec ~config ~words table
;;

(* What the kernel proves of every run, whatever the host does, and each bound one cycle
   more refused. *)
let%expect_test "the kernel proves the chip select's setup, hold and deselect" =
  let deselect = 9 in
  List.iter Mode.all ~f:(fun mode ->
    let spaced = spaced ~mode in
    print_s
      [%message
        ""
          ~mode:(Mode.to_int mode : int)
          ~proved:(spaced (spacing ~half_period ~setup ~hold ~deselect) : unit Or_error.t)
          ~half_period_more:
            (Or_error.is_ok
               (spaced (spacing ~half_period:(half_period + 1) ~setup ~hold ~deselect))
             : bool)
          ~setup_more:
            (Or_error.is_ok
               (spaced (spacing ~half_period ~setup:(setup + 1) ~hold ~deselect))
             : bool)
          ~hold_more:
            (Or_error.is_ok
               (spaced (spacing ~half_period ~setup ~hold:(hold + 1) ~deselect))
             : bool)
          ~deselect_more:
            (Or_error.is_ok
               (spaced (spacing ~half_period ~setup ~hold ~deselect:(deselect + 1)))
             : bool)]);
  [%expect
    {|
    ((mode 0) (proved (Ok ())) (half_period_more false) (setup_more false)
     (hold_more false) (deselect_more false))
    ((mode 1) (proved (Ok ())) (half_period_more false) (setup_more false)
     (hold_more false) (deselect_more false))
    ((mode 2) (proved (Ok ())) (half_period_more false) (setup_more false)
     (hold_more false) (deselect_more false))
    ((mode 3) (proved (Ok ())) (half_period_more false) (setup_more false)
     (hold_more false) (deselect_more false))
    |}]
;;

let%expect_test "each mode in lockstep" =
  List.iter Mode.all ~f:(fun mode ->
    let device = ref (Device.create ~mode ~first:0x5a) in
    let (_ : Machine.t) =
      Lockstep.lockstep
        ~cycles:1500
        ~config
        ~program:
          (Timed_program.words
             (Timed_program.of_source_exn
                ~config
                (master ~mode ~half_period ~setup ~hold)))
        ~preload:(List.concat_map [ [ 0x9f; 0x00 ]; [ 0xa5 ] ] ~f:words)
        ~inputs:(fun _ -> Device.miso !device lsl miso_pin)
        ~react:(fun m ->
          device
          := Device.step
               !device
               ~cs:(bit m.pin_out cs_pin)
               ~sck:(bit m.pin_out sck_pin)
               ~mosi:(bit m.pin_out mosi_pin))
        ()
    in
    print_s
      [%message
        "" ~mode:(Mode.to_int mode : int) ~frames:(Device.frames !device : int list list)]);
  [%expect
    {|
    ("lockstep held" (cycles 1500))
    ((mode 0) (frames ((159 0) (165))))
    ("lockstep held" (cycles 1500))
    ((mode 1) (frames ((159 0) (165))))
    ("lockstep held" (cycles 1500))
    ((mode 2) (frames ((159 0) (165))))
    ("lockstep held" (cycles 1500))
    ((mode 3) (frames ((159 0) (165))))
    |}]
;;
