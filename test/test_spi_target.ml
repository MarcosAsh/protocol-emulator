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

(* CS rising inside a byte drops that byte: the bits it took and its reply. The frames
   after it line up again, in every mode. *)
let%expect_test "a frame cut short inside a byte loses that byte and no more" =
  let pins = Spi_target.pads in
  let run (mode : Spi_cs.Mode.t) frames =
    let timed =
      Timed_program.of_source_exn
        ~config:(Spi_target.config pins)
        (Spi_target.firmware ~mode pins)
    in
    let target =
      ref
        (Machine.create
           ~config:(Timed_program.config timed)
           ~program:(Timed_program.words timed)
         |> ok_exn)
    in
    List.iter [ 0x81; 0x7e; 0x42 ] ~f:(fun reply ->
      target := Machine.write_tx !target (reply lsl 8) |> ok_exn);
    let received = Queue.create () in
    let half = 20 in
    let idle = Bool.to_int mode.cpol in
    (* [n] cycles at these levels, then MISO as they left it *)
    let hold ?(cs = 0) ?(sck = idle) ?(mosi = 0) n =
      let inputs = (mosi lsl pins.mosi) lor (sck lsl pins.sck) lor (cs lsl pins.cs) in
      for _ = 1 to n do
        target := Machine.step !target ~inputs;
        Option.iter (Machine.read_rx !target) ~f:(fun (word, t) ->
          Queue.enqueue received word;
          target := t)
      done;
      (!target.pin_out lsr pins.miso) land 1
    in
    (* MOSI holds from the edge before the one the target samples on, and MISO is read at
       the end of the first half: the leading edge in CPHA 0, the trailing one in CPHA 1 *)
    let bit mosi =
      let first = hold ~sck:(if mode.cpha then 1 - idle else idle) ~mosi half in
      let (_ : int) = hold ~sck:(if mode.cpha then idle else 1 - idle) ~mosi half in
      first
    in
    let (_ : int) = hold ~cs:1 200 in
    let miso =
      List.map frames ~f:(fun bits ->
        let (_ : int) = hold half in
        let miso = List.fold bits ~init:0 ~f:(fun acc b -> (acc lsl 1) lor bit b) in
        let (_ : int) = hold half in
        let (_ : int) = hold ~cs:1 (5 * half) in
        List.length bits, miso)
    in
    Queue.to_list received, miso
  in
  let byte b = List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1) in
  List.iter Spi_cs.Mode.all ~f:(fun mode ->
    let received, miso = run mode [ [ 1; 1; 1; 1 ]; byte 0xa5; byte 0x3c ] in
    print_s
      [%message
        ""
          ~mode:(Spi_cs.Mode.to_int mode : int)
          (received : Int.Hex.t list)
          ~miso:(miso : (int * Int.Hex.t) list)]);
  [%expect {|
    ((mode 0) (received (0xa5 0x3c)) (miso ((4 0x8) (8 0x7e) (8 0x42))))
    ((mode 1) (received (0xa5 0x3c)) (miso ((4 0x8) (8 0x7e) (8 0x42))))
    ((mode 2) (received (0xa5 0x3c)) (miso ((4 0x8) (8 0x7e) (8 0x42))))
    ((mode 3) (received (0xa5 0x3c)) (miso ((4 0x8) (8 0x7e) (8 0x42))))
    |}]
;;
