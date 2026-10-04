open! Core
open Protocol_emulator
open Firmware
open Protocol_models

(* A slave that holds SCL low from each fall for the next of [holds] cycles, round and
   round; a hold no longer than the master's own low phase stretches nothing. *)
module Stretcher = struct
  type t =
    { holds : int list
    ; next : int list
    ; left : int
    ; last_scl : int
    }

  let create holds = { holds; next = holds; left = 0; last_scl = 1 }
  let scl t ~master = if t.left > 0 then 0 else master

  let step t ~master =
    let bus = scl t ~master in
    let t =
      if t.last_scl = 1 && bus = 0
      then (
        match t.next, t.holds with
        | hold :: next, _ | [], hold :: next -> { t with left = hold; next }
        | [], [] -> t)
      else t
    in
    { t with left = Int.max 0 (t.left - 1); last_scl = bus }
  ;;
end

module Run = struct
  type t =
    { levels : (int * int) list (** SDA and SCL on the bus, a pair per cycle. *)
    ; replies : (int * int) list (** Each word the core pushed, and the cycle. *)
    ; log : string list
    ; machine : Machine.t
    }
end

(* [program] beside an [I2c_slave] at 0x50 and [stretcher], [words] queued, then [later]
   from its cycle on; SCL is held low over [stuck], from its first cycle up to its last. *)
let run
  ?(stretcher = Stretcher.create [])
  ?(stuck = 0, 0)
  ?(later = 0, [])
  ?(memory = Array.create ~len:16 0)
  ~config
  ~program
  ~words
  ~cycles
  ()
  =
  let t = Machine.create ~config ~program |> ok_exn in
  let t = List.fold words ~init:t ~f:(fun t w -> Machine.write_tx t w |> ok_exn) in
  let slave = I2c_slave.create ~address:0x50 ~memory in
  let rec loop cycle (t : Machine.t) slave stretcher levels replies =
    if cycle = cycles
    then
      { Run.levels = List.rev levels
      ; replies = List.rev replies
      ; log = I2c_slave.log slave
      ; machine = t
      }
    else (
      let t =
        if cycle = fst later
        then List.fold (snd later) ~init:t ~f:(fun t w -> Machine.write_tx t w |> ok_exn)
        else t
      in
      let master_sda = 1 - ((t.pin_dir lsr sda) land 1) in
      let master_scl = 1 - ((t.pin_dir lsr scl) land 1) in
      let bus_sda = if I2c_slave.drive_low slave then 0 else master_sda in
      let bus_scl =
        if cycle >= fst stuck && cycle < snd stuck
        then 0
        else Stretcher.scl stretcher ~master:master_scl
      in
      let t = Machine.step t ~inputs:((bus_sda lsl sda) lor (bus_scl lsl scl)) in
      let slave = I2c_slave.step slave ~sda:bus_sda ~scl:bus_scl in
      let stretcher = Stretcher.step stretcher ~master:master_scl in
      let replies, t =
        match Machine.read_rx t with
        | Some (r, t) -> (r, cycle) :: replies, t
        | None -> replies, t
      in
      loop (cycle + 1) t slave stretcher ((bus_sda, bus_scl) :: levels) replies)
  in
  loop 0 t slave stretcher [] []
;;

let plain ~quarter = i2c_config, assemble (i2c_master ~quarter)
let stretching ~quarter = i2c_stretch_config, assemble (i2c_master_stretch ~quarter)

let write_then_read =
  [ i2c_word ~start:true 0xa0
  ; i2c_word 3
  ; i2c_word ~stop:true 0xaa
  ; i2c_word ~start:true 0xa0
  ; i2c_word 3
  ; i2c_word ~start:true 0xa1
  ; i2c_word ~read:true 0
  ; i2c_word ~read:true ~stop:true 0
  ]
;;

(* SCL's runs at [level] between the first and the last, which are the idle bus *)
let scl_runs (run : Run.t) ~level =
  List.map run.levels ~f:snd
  |> runs
  |> Fn.flip List.drop 1
  |> List.drop_last_exn
  |> List.filter_map ~f:(fun (l, n) -> Option.some_if (l = level) n)
  |> List.dedup_and_sort ~compare
;;

(* Like the plain master, the quarter is the deadlines' and the sample's slack. *)
let%expect_test "the kernel accepts the stretching master from a quarter of 8" =
  List.iter [ 8; 7 ] ~f:(fun quarter ->
    match
      Timed_program.check ~config:i2c_stretch_config (i2c_master_stretch ~quarter)
    with
    | Ok timed ->
      print_s
        [%message
          "accepted" (quarter : int) (Timed_program.verdict timed : Analyser.Verdict.t)]
    | Error { faults; _ } ->
      print_s [%message "refused" (quarter : int) (faults : Timed_program.Fault.t list)]);
  let host_rate period_floor =
    Timed_program.check
      ~period_floor
      ~config:i2c_stretch_config
      i2c_master_stretch_host_rate
    |> Result.is_ok
  in
  print_s [%message (host_rate 8 : bool) (host_rate 7 : bool)];
  let program = Asm.assemble (i2c_master_stretch ~quarter:13) |> ok_exn in
  let config = Asm.Program.configure program i2c_stretch_config in
  let words = Asm.Program.words program |> ok_exn in
  let rows = Analyser.analyse ~config program.instructions in
  print_s
    [%sexp
      (Kernel.check ~config ~words (Kernel.Table.of_analyser rows) : unit Or_error.t)];
  [%expect
    {|
    (accepted (quarter 8)
     ("Timed_program.verdict timed"
      ((words 161) (deadline_waits 35) (worst_slack (0)))))
    (refused (quarter 7)
     (faults
      (((line 116) (pc (97))
        (reason "this deadline wait can be reached 1 cycle late (slack -1..6)"))
       ((line 155) (pc (130))
        (reason "this deadline wait can be reached 1 cycle late (slack -1..1)")))))
    (("host_rate 8" true) ("host_rate 7" false))
    (Ok ())
    |}]
;;

(* One data bit's SCL high. The phase is unknown while SCL is polled, as after any wait on
   a pin; [mov t, now] fixes it, so the deadlines after, and the edges and the sample on
   them, are certified from the poll that saw SCL high, wherever the slave let it go. *)
let%expect_test "the certificate starts again from the poll that sees SCL high" =
  let timed =
    Timed_program.of_source_exn
      ~config:i2c_stretch_config
      (i2c_master_stretch ~quarter:13)
  in
  let releases =
    List.filter (Timed_program.rows timed) ~f:(fun row ->
      match row.instruction with
      | Op { op = Mov { dest = Y; op = Invert; source = Null }; _ } -> true
      | _ -> false)
  in
  (* the second is a data bit's, after the repeated START's *)
  let release = (List.nth_exn releases 1).pc in
  let rows =
    List.filter (Timed_program.rows timed) ~f:(fun row ->
      row.pc >= release && row.pc <= release + 10)
  in
  print_string (Analyser.to_string ~side_set_count:1 rows);
  [%expect
    {|
    69  mov y, !null side 0          phase -12  side -11
    70  jmp pin, 73                  phase -11..?
    71  jmp y--, 70                  phase -9..?
    72  jmp 146                      phase -7..?
    73  mov t, now side 0            phase -9..?
    74  sub t, 4 side 0              phase 1
    75  add t, p side 0              phase 6
    76  wait t+ side 0               phase -6  slack 6
    77  wait t+ side 0               phase -12  slack 12
    78  nop side 1                   phase -12  side -11
    79  jmp x--, 65                  phase -11
    |}]
;;

(* In the model, whose inputs take no time; on the RTL every high is longer by the input
   path's delay. *)
let%expect_test "without a stretch the bus is the plain master's, cycle for cycle" =
  List.iter [ 8; 13 ] ~f:(fun quarter ->
    let bus (config, program) =
      run ~config ~program ~words:write_then_read ~cycles:(400 * quarter) ()
    in
    let plain = bus (plain ~quarter) in
    let stretching = bus (stretching ~quarter) in
    print_s
      [%message
        (quarter : int)
          ~same_bus:([%equal: (int * int) list] plain.levels stretching.levels : bool)
          ~same_replies:
            ([%equal: (int * int) list] plain.replies stretching.replies : bool)
          (stretching.log : string list)]);
  [%expect
    {|
    ((quarter 8) (same_bus true) (same_replies true)
     (stretching.log
      (start stop start "address 80 write" "pointer 3" "write 170" stop start
       "address 80 write" "pointer 3" start "address 80 read" nack stop)))
    ((quarter 13) (same_bus true) (same_replies true)
     (stretching.log
      (start stop start "address 80 write" "pointer 3" "write 170" stop start
       "address 80 write" "pointer 3" start "address 80 read" nack stop)))
    |}]
;;

(* Holds of 17 to 21 cycles end one to five past the master's 16 low, 40, 100 and 33 well
   past. The plain master's highs come short and the slave misreads the pointer; the
   stretching master's highs are two quarters and up to three cycles more, a poll's gap. *)
let%expect_test "a slave stretching by varying amounts" =
  let quarter = 8 in
  let holds = [ 0; 17; 18; 19; 20; 21; 40; 3; 100; 33 ] in
  List.iter
    [ plain ~quarter; stretching ~quarter ]
    ~f:(fun (config, program) ->
      let memory = Array.init 16 ~f:(fun i -> if i = 4 then 0x5c else 0) in
      let run =
        run
          ~stretcher:(Stretcher.create holds)
          ~memory
          ~config
          ~program
          ~words:write_then_read
          ~cycles:6000
          ()
      in
      print_s
        [%message
          ""
            ~log:(run.log : string list)
            ~replies:(List.map run.replies ~f:fst : int list)
            (memory : int array)
            ~scl_high:(scl_runs run ~level:1 : int list)
            ~scl_low:(scl_runs run ~level:0 : int list)
            ~fault:(run.machine.fault : Machine.Fault.t)]);
  [%expect
    {|
    ((log
      (start stop start "address 80 write" "pointer 62" stop start
       "address 80 read"))
     (replies (1 1 1 1 0 0 1 0)) (memory (0 0 0 0 92 0 0 0 0 0 0 0 0 0 0 0))
     (scl_high (11 12 13 14 15 16 45))
     (scl_low (16 17 18 19 20 21 24 28 34 36 48 68 100 112))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((log
      (start stop start "address 80 write" "pointer 3" "write 170" stop start
       "address 80 write" "pointer 3" start "address 80 read" nack stop))
     (replies (0 0 0 0 0 0 170 92)) (memory (0 0 0 170 92 0 0 0 0 0 0 0 0 0 0 0))
     (scl_high (16 17 18 19 45)) (scl_low (16 17 18 19 20 21 24 28 33 36 40 100))
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* Held from reset, every word is answered at once. Held mid-address, that word is
   answered after 65536 polls and the rest at once. Once SCL is back a write goes through;
   the model slave, cut off mid-address, first takes the next rises as the rest. *)
let%expect_test "SCL held low answers 0xffff" =
  let config, program = stretching ~quarter:8 in
  let held ?later ~stuck ~cycles () =
    let memory = Array.create ~len:16 0 in
    let run =
      run ?later ~stuck ~memory ~config ~program ~words:write_then_read ~cycles ()
    in
    print_s
      [%message
        ""
          ~log:(run.log : string list)
          ~replies:(run.replies : (int * int) list)
          (memory : int array)
          ~pc:(run.machine.pc : int)
          ~driven:(run.machine.pin_dir land ((1 lsl sda) lor (1 lsl scl)) : int)
          ~fault:(run.machine.fault : Machine.Fault.t)]
  in
  held ~stuck:(0, 1_000) ~cycles:1_000 ();
  held
    ~stuck:(300, 300_000)
    ~later:(300_000, [ i2c_word ~start:true 0xa0; i2c_word 5; i2c_word ~stop:true 0x77 ])
    ~cycles:301_500
    ();
  [%expect
    {|
    ((log ())
     (replies
      ((65535 62) (65535 69) (65535 78) (65535 93) (65535 100) (65535 115)
       (65535 122) (65535 131)))
     (memory (0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)) (pc 149) (driven 0)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((log
      (start stop start "address 80 read" start "address 80 write" "pointer 5"
       "write 119" stop))
     (replies
      ((65535 262477) (65535 262484) (65535 262493) (65535 262508) (65535 262515)
       (65535 262530) (65535 262537) (65535 262546) (0 300330) (0 300638)
       (0 300946)))
     (memory (0 0 0 0 0 119 0 0 0 0 0 0 0 0 0 0)) (pc 25) (driven 0)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* SCL comes back after the timeout but before the rest of the transfer: those words are
   answered 0xffff and kept off the bus, and the next START word goes through. *)
let%expect_test "after a timeout only a START goes back on the bus" =
  let config, program = stretching ~quarter:8 in
  let memory = Array.create ~len:16 0 in
  let run =
    run
      ~stuck:(300, 262_600)
      ~later:
        ( 263_000
        , [ i2c_word 3
          ; i2c_word ~stop:true 0xaa
          ; i2c_word ~start:true 0xa0
          ; i2c_word 5
          ; i2c_word ~stop:true 0x77
          ] )
      ~memory
      ~config
      ~program
      ~words:[ i2c_word ~start:true 0xa0 ]
      ~cycles:264_500
      ()
  in
  print_s
    [%message
      ""
        ~replies:(run.replies : (int * int) list)
        ~log:(run.log : string list)
        (memory : int array)
        ~pc:(run.machine.pc : int)
        ~fault:(run.machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((replies
      ((65535 262477) (65535 263006) (65535 263015) (0 263348) (0 263656)
       (0 263964)))
     (log
      (start stop start "address 80 read" start "address 80 write" "pointer 5"
       "write 119" stop))
     (memory (0 0 0 0 0 119 0 0 0 0 0 0 0 0 0 0)) (pc 25)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* Held at the STOP, after the stop word's reply: nothing more is pushed for it. No STOP
   reaches the bus, so the model slave takes the next START as a repeated one and writes
   on from 6. *)
let%expect_test "SCL held at the STOP adds no reply" =
  let config, program = stretching ~quarter:8 in
  let words = [ i2c_word ~start:true 0xa0; i2c_word 5; i2c_word ~stop:true 0x77 ] in
  let free = run ~config ~program ~words ~cycles:1_000 () in
  let last = snd (List.last_exn free.replies) in
  let memory = Array.create ~len:16 0 in
  let back = last + 300_000 in
  let run =
    run
      ~stuck:(last + 1, back)
      ~later:(back, [ i2c_word ~start:true 0xa0; i2c_word 6; i2c_word ~stop:true 0x55 ])
      ~memory
      ~config
      ~program
      ~words
      ~cycles:(back + 1_500)
      ()
  in
  print_s
    [%message
      ""
        ~replies:(List.map run.replies ~f:fst : int list)
        ~log:(run.log : string list)
        (memory : int array)
        ~pc:(run.machine.pc : int)
        ~driven:(run.machine.pin_dir land ((1 lsl sda) lor (1 lsl scl)) : int)
        ~fault:(run.machine.fault : Machine.Fault.t)];
  [%expect
    {|
    ((replies (0 0 0 0 0 0))
     (log
      (start stop start "address 80 write" "pointer 5" "write 119" start
       "address 80 write" "write 6" "write 85" stop))
     (memory (0 0 0 0 0 119 6 85 0 0 0 0 0 0 0 0)) (pc 25) (driven 0)
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* The core against its RTL beside the stretching slave. *)
let%expect_test "the stretching master in lockstep with a stretching slave" =
  let memory = Array.create ~len:16 0 in
  let slave = ref (I2c_slave.create ~address:0x50 ~memory) in
  let stretcher = ref (Stretcher.create [ 0; 17; 21; 40; 100; 33 ]) in
  let words = ref write_then_read in
  let bus (m : Machine.t) =
    let master_sda = 1 - ((m.pin_dir lsr sda) land 1) in
    let bus_sda = if I2c_slave.drive_low !slave then 0 else master_sda in
    let master_scl = 1 - ((m.pin_dir lsr scl) land 1) in
    bus_sda, master_scl, Stretcher.scl !stretcher ~master:master_scl
  in
  let model = ref None in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~cycles:5000
      ~config:i2c_stretch_config
      ~program:(assemble (i2c_master_stretch ~quarter:8))
      ~inputs:(fun _ ->
        match !model with
        | None -> (1 lsl sda) lor (1 lsl scl)
        | Some m ->
          let bus_sda, _, bus_scl = bus m in
          (bus_sda lsl sda) lor (bus_scl lsl scl))
      ~host:(fun _ ->
        match !words with
        | w :: rest ->
          words := rest;
          { Lockstep.Host.idle with tx = Some w; pop_rx = true }
        | [] -> { Lockstep.Host.idle with pop_rx = true })
      ~react:(fun m ->
        let bus_sda, master_scl, bus_scl = bus m in
        slave := I2c_slave.step !slave ~sda:bus_sda ~scl:bus_scl;
        stretcher := Stretcher.step !stretcher ~master:master_scl;
        model := Some m)
      ()
  in
  print_s [%message (I2c_slave.log !slave : string list) (memory : int array)];
  [%expect
    {|
    ("lockstep held" (cycles 5000))
    (("I2c_slave.log (!slave)"
      (start stop start "address 80 write" "pointer 3" "write 170" stop start
       "address 80 write" "pointer 3" start "address 80 read" nack stop))
     (memory (0 0 0 170 0 0 0 0 0 0 0 0 0 0 0 0)))
    |}]
;;
