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
