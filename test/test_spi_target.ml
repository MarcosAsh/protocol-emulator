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

let spi_ok ~mode ~half_period ~hold ~deselect =
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
              ~config:Wire_spi.target_config
              (Wire_spi.target mode)
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
  let passes half_period =
    List.for_all Spi_cs.Mode.all ~f:(fun mode ->
      List.for_all
        [ Spi_cs.shortest_hold, 9; Spi_cs.longest_hold, 40 ]
        ~f:(fun (hold, deselect) -> spi_ok ~mode ~half_period ~hold ~deselect))
  in
  let shortest = Spi_target.shortest_half in
  print_s
    [%message
      ""
        ~from_shortest:(List.for_all (List.range shortest 32) ~f:passes : bool)
        ~one_less:(passes (shortest - 1) : bool)];
  [%expect {| ((from_shortest true) (one_less false)) |}]
;;
