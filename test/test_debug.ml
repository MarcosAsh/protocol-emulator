open! Core
open Protocol_emulator
open Firmware

(* Runs [source] in lockstep with the hardware under a debugger: [act] sees the model
   after every cycle and says what the host does in the next, and every halt is printed
   with the cycle it came in, the pc and x. *)
let debug ?(cycles = 200) ?(config = Program_config.default) ~act source =
  let last = ref None in
  let cycle = ref 0 in
  let halts = ref [] in
  let react (m : Machine.t) =
    let was_halted =
      Option.value_map !last ~default:false ~f:(fun b -> b.Machine.halted)
    in
    if m.halted && not was_halted then halts := (!cycle, m.pc, m.x) :: !halts;
    Int.incr cycle;
    last := Some m
  in
  let host n =
    match !last with
    | None -> act n (Machine.create ~config ~program:[] |> ok_exn)
    | Some m -> act n m
  in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles
      ~config
      ~program:(assemble source)
      ~inputs:(fun _ -> 0)
      ~host
      ~react
      ()
  in
  print_s [%message "" ~halts:(List.rev !halts : (int * int * int) list)]
;;

let%expect_test "a breakpoint stops the core each time it comes round" =
  debug
    ~config:{ Program_config.default with break_enable = true; break_pc = 2 }
    ~act:(fun _ m -> { Lockstep.Host.idle with resume = m.halted && m.pc = 2 })
    {|
    set x, 3
loop:
    set pins, 1
    set pins, 0
    jmp x--, loop
    halt
|};
  [%expect
    {|
    ("lockstep held" (cycles 200))
    (halts ((2 2 3) (9 2 2) (16 2 1) (23 2 0) (29 5 65535)))
    |}]
;;

(* The host stops the core at once and steps it from there. A step spends a cycle fetching
   again before the instruction issues; the wait for the host's word does not complete,
   and so does not end the step, until the word comes at cycle 60. *)
let%expect_test "single steps go one instruction at a time" =
  debug
    ~act:(fun n m ->
      { Lockstep.Host.idle with
        stop = n = 0
      ; single_step = n > 0 && m.halted && m.pc < 6
      ; tx = Option.some_if (n = 60) 0x1234
      })
    {|
    set x, 1 [2]
loop:
    nop
    jmp x--, loop
    wait tx
    pull
    halt
|};
  [%expect
    {|
    ("lockstep held" (cycles 200))
    (halts
     ((0 1 1) (3 2 1) (6 1 0) (9 2 0) (12 3 65535) (61 4 65535) (64 5 65535)
      (67 6 65535)))
    |}]
;;

(* The wait at the breakpoint stalls for its deadline after the resume and is not stopped
   again for it: the breakpoint lets go of the instruction it resumed at until that
   instruction completes. *)
let%expect_test "a resume leaves a breakpoint on a wait that stalls" =
  debug
    ~cycles:120
    ~config:{ Program_config.default with break_enable = true; break_pc = 3 }
    ~act:(fun _ m -> { Lockstep.Host.idle with resume = m.halted })
    {|
    set p, 20
    mov t, now
    add t, p
loop:
    wait t+
    mov pins, !pins
    jmp loop
|};
  [%expect
    {|
    ("lockstep held" (cycles 120))
    (halts ((3 3 0) (25 3 0) (45 3 0) (65 3 0) (85 3 0) (105 3 0)))
    |}]
;;
