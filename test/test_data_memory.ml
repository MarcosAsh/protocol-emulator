open! Core
open Protocol_emulator

let data = List.init 12 ~f:(fun n -> 0x1000 * (n + 1) lor n)

(* Sixteen pins from IO0, so a whole word shows at once. *)
let config =
  { Program_config.default with
    out_base = Isa.first_bidir_pin
  ; out_count = Isa.data_bits
  ; autopull = true
  ; autopull_data = true
  }
;;

(* Runs [source] with [data] in the data memory, in lockstep with the hardware, and prints
   every word that shows on the sixteen pins. *)
let stream ?(preload = []) ~cycles source =
  let shown = ref [] in
  let react (m : Machine.t) =
    let word = (m.pin_out lsr Isa.first_bidir_pin) land 0xffff in
    match !shown with
    | last :: _ when last = word -> ()
    | _ -> shown := word :: !shown
  in
  let program = Asm.assemble source |> ok_exn in
  let m =
    Lockstep.lockstep
      ~cycles
      ~preload
      ~data
      ~config:(Asm.Program.configure program config)
      ~program:(Asm.Program.words program |> ok_exn)
      ~inputs:(fun _ -> 0)
      ~react
      ()
  in
  print_s
    [%message
      "" ~shown:(List.rev !shown : Int.Hex.t list) ~underflow:(m.fault.underflow : bool)];
  (match Analyser.check ~config program with
   | Ok verdict -> print_endline (Analyser.Verdict.to_string verdict)
   | Error error -> print_endline (Error.to_string_hum error));
  (* and every pull the model refuses is one the analyser warned of *)
  let { Soundness.issues; violations; _ } =
    Soundness.check
      ~preload
      ~config:(Asm.Program.configure program config)
      (List.init 4 ~f:(fun n -> Soundness.Stimulus.random ~seed:(n + 1) ~cycles))
      (Asm.Program.words program |> ok_exn)
  in
  print_s [%message (issues : int) (violations : (int * int * int * int) list)]
;;

(* An autopull every other cycle, the fastest the shared memory is ever read. *)
let%expect_test "every other cycle takes the next word from where seek pointed" =
  stream
    ~cycles:22
    {|
    set x, 3
    seek [1]
.wrap_target
    out pins, 16 [1]
.wrap
|};
  [%expect
    {|
    ("lockstep held" (cycles 22))
    ((shown
      (0x0 0x4003 0x5004 0x6005 0x7006 0x8007 0x9008 0xa009 0xb00a 0xc00b 0x0))
     (underflow false))
    3 words, 0 deadline waits
    ((issues 48) (violations ()))
    |}]
;;

(* A word asked for the cycle after the pointer moved may not have arrived, so the pull is
   refused, the pointer stays and the next one takes the word. *)
let%expect_test "a data pull the cycle after a seek or a pull is refused" =
  stream ~cycles:12 {|
    set x, 3
    seek
.wrap_target
    out pins, 16
.wrap
|};
  [%expect
    {|
    ("lockstep held" (cycles 12))
    ((shown (0x0 0x4003 0x0 0x5004 0x0 0x6005 0x0 0x7006 0x0 0x8007))
     (underflow true))
    1 data pull may come within 1 cycle of the pointer moving
      2  out pins, 16                 phase ?..?  edge ?..?  jitter ?  gap 1 from 2, ?..? from 1  MAY UNDERRUN
    ((issues 12) (violations ()))
    |}]
;;

(* The host's word comes through the fifo, with [pull], and says how many data words to
   send; the data comes through autopull. *)
let%expect_test "a pull reads the host while autopull reads the data" =
  stream
    ~preload:[ 3 ]
    ~cycles:40
    {|
    wait tx
    pull
    mov y, osr
    out null, 16
loop:
    out pins, 16
    jmp y--, loop
    halt
|};
  [%expect
    {|
    ("lockstep held" (cycles 40))
    ((shown (0x0 0x1000 0x2001 0x3002 0x4003)) (underflow false))
    7 words, 0 deadline waits
    ((issues 52) (violations ()))
    |}]
;;
