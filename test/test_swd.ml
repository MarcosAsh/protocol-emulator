open! Core
open Protocol_emulator
open Swd

let half_period = shortest_half

module Item = struct
  type t =
    | Bits of int list
    | Transfer of Transfer.t
end

let words items =
  half_period
  :: List.concat_map items ~f:(function
    | Item.Bits words -> words
    | Transfer transfer -> Transfer.words transfer)
;;

let replies items ~pushed =
  List.filter_map items ~f:(function
    | Item.Bits _ -> None
    | Transfer transfer -> Some transfer)
  |> List.fold_map ~init:pushed ~f:(fun pushed transfer ->
    let #(mine, rest) = List.split_n pushed (Transfer.replies transfer) in
    rest, (transfer, Reply.of_words transfer mine))
  |> snd
;;

let dp ?ap_latency ?memory ?corrupt_parity ?corrupt_acks targetid =
  Dp.create
    ?ap_latency
    ?memory
    ?corrupt_parity
    ?corrupt_acks
    ~cycle_ns
    ~dpidr:rp2040_dpidr
    ~targetid
    ()
;;

(* the core, fed and emptied each cycle as a host keeping up would, on [bus] *)
let run ~cycles ~bus items =
  let t =
    Machine.create
      ~config:(Timed_program.config firmware)
      ~program:(Timed_program.words firmware)
    |> ok_exn
  in
  let rec loop (t : Machine.t) bus schedule pushed n =
    if n = cycles
    then t, bus, List.rev pushed
    else (
      let t, schedule =
        match schedule with
        | word :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
          Machine.write_tx t word |> ok_exn, rest
        | schedule -> t, schedule
      in
      let t = Machine.step t ~inputs:(Bus.inputs bus) in
      let bus = Bus.step bus ~pin_out:t.pin_out ~pin_dir:t.pin_dir in
      let pushed, t =
        match Machine.read_rx t with
        | Some (word, t) -> word :: pushed, t
        | None -> pushed, t
      in
      loop t bus schedule pushed (n + 1))
  in
  loop t bus (words items) [] 0
;;

let print ~(machine : Machine.t) ~bus ~pushed items =
  List.iter (replies items ~pushed) ~f:(fun (transfer, reply) ->
    print_s [%message "" (transfer : Transfer.t) (reply : Reply.t)]);
  List.iteri (Bus.dps bus) ~f:(fun i dp ->
    print_s
      [%message
        ""
          ~dp:(i : int)
          ~log:(Dp.log dp : string list)
          ~measured_ns:(Dp.measured dp : Measured.t)
          ~violations:
            (Dp.violations dp |> List.dedup_and_sort ~compare:String.compare
             : string list)]);
  print_s
    [%message
      ""
        ~contention:(Bus.contention bus : int list)
        ~fault:(machine.fault : Machine.Fault.t)
        ~tx_left:(List.length machine.tx_fifo : int)]
;;

let read ?(ap = false) address = Item.Transfer (Read { ap; address })
let write ?(ap = false) address value = Item.Transfer (Write { ap; address; value })

(* The RP2040's bring-up, its debug domain powered and AP 0's IDR read, then each ACK:
   WAIT from an AP still busy, FAULT once a read outside memory has set STICKYERR, and
   none once TARGETSEL has let both DPs go. A refused write's data words are dropped. *)
let%expect_test "an RP2040's two DPs, woken from dormant and selected in turn" =
  let memory = [ 0x4000_0000, 0x2000_2927 ] in
  let bus =
    Bus.create
      [ dp ~ap_latency:20 ~memory rp2040_core0; dp ~ap_latency:20 ~memory rp2040_core1 ]
  in
  let select targetsel =
    [ Item.Bits line_reset; Transfer (Targetsel targetsel); read 0x0 ]
  in
  let items =
    (Item.Bits dormant_to_swd :: select rp2040_core0)
    @ [ write 0x0 0x1c
      ; write 0x4 0x5000_0000
      ; read 0x4
      ; write 0x8 0xf0
      ; read ~ap:true 0xc
      ; read 0xc
      ; write 0x8 0x0
      ; write ~ap:true 0x4 0x4000_0000
      ; read ~ap:true 0xc
      ; read ~ap:true 0xc
      ; read 0xc
      ; write ~ap:true 0x4 0x5000_0000
      ; read ~ap:true 0xc
      ; read ~ap:true 0xc
      ; read 0xc
      ; write ~ap:true 0x4 0x4000_0000
      ; read 0x4
      ; write 0x0 0x04
      ; read 0x4
      ]
    @ select rp2040_core1
    @ select 0x2100_2927
    @ select rp2040_core0
  in
  let machine, bus, pushed = run ~cycles:90_000 ~bus items in
  print ~machine ~bus ~pushed items;
  [%expect
    {|
    ((transfer (Targetsel 0x1002927))
     (reply ((ack (Invalid 7)) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack Ok) (data (0xbc12477)) (parity_error false))))
    ((transfer (Write (ap false) (address 0) (value 0x1c)))
     (reply ((ack Ok) (data ()) (parity_error false))))
    ((transfer (Write (ap false) (address 4) (value 0x50000000)))
     (reply ((ack Ok) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 4)))
     (reply ((ack Ok) (data (0xf0000000)) (parity_error false))))
    ((transfer (Write (ap false) (address 8) (value 0xf0)))
     (reply ((ack Ok) (data ()) (parity_error false))))
    ((transfer (Read (ap true) (address 12)))
     (reply ((ack Ok) (data (0x0)) (parity_error false))))
    ((transfer (Read (ap false) (address 12)))
     (reply ((ack Ok) (data (0x4770031)) (parity_error false))))
    ((transfer (Write (ap false) (address 8) (value 0x0)))
     (reply ((ack Ok) (data ()) (parity_error false))))
    ((transfer (Write (ap true) (address 4) (value 0x40000000)))
     (reply ((ack Ok) (data ()) (parity_error false))))
    ((transfer (Read (ap true) (address 12)))
     (reply ((ack Wait) (data ()) (parity_error false))))
    ((transfer (Read (ap true) (address 12)))
     (reply ((ack Ok) (data (0x4770031)) (parity_error false))))
    ((transfer (Read (ap false) (address 12)))
     (reply ((ack Ok) (data (0x20002927)) (parity_error false))))
    ((transfer (Write (ap true) (address 4) (value 0x50000000)))
     (reply ((ack Ok) (data ()) (parity_error false))))
    ((transfer (Read (ap true) (address 12)))
     (reply ((ack Wait) (data ()) (parity_error false))))
    ((transfer (Read (ap true) (address 12)))
     (reply ((ack Ok) (data (0x20002927)) (parity_error false))))
    ((transfer (Read (ap false) (address 12)))
     (reply ((ack Fault) (data ()) (parity_error false))))
    ((transfer (Write (ap true) (address 4) (value 0x40000000)))
     (reply ((ack Fault) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 4)))
     (reply ((ack Ok) (data (0xf0000020)) (parity_error false))))
    ((transfer (Write (ap false) (address 0) (value 0x4)))
     (reply ((ack Ok) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 4)))
     (reply ((ack Ok) (data (0xf0000000)) (parity_error false))))
    ((transfer (Targetsel 0x11002927))
     (reply ((ack (Invalid 7)) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack Ok) (data (0xbc12477)) (parity_error false))))
    ((transfer (Targetsel 0x21002927))
     (reply ((ack (Invalid 7)) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack (Invalid 7)) (data ()) (parity_error false))))
    ((transfer (Targetsel 0x1002927))
     (reply ((ack (Invalid 7)) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack Ok) (data (0xbc12477)) (parity_error false))))
    ((dp 0)
     (log
      ("dormant to SWD" "line reset" "TARGETSEL 0x01002927: selected"
       "R DP 0x0 OK 0x0bc12477" "W DP 0x0 OK 0x0000001c" "W DP 0x4 OK 0x50000000"
       "R DP 0x4 OK 0xf0000000" "W DP 0x8 OK 0x000000f0" "R AP 0xc OK 0x00000000"
       "R DP 0xc OK 0x04770031" "W DP 0x8 OK 0x00000000" "W AP 0x4 OK 0x40000000"
       "R AP 0xc WAIT" "R AP 0xc OK 0x04770031" "R DP 0xc OK 0x20002927"
       "W AP 0x4 OK 0x50000000" "R AP 0xc WAIT" "R AP 0xc OK 0x20002927"
       "R DP 0xc FAULT" "W AP 0x4 FAULT" "R DP 0x4 OK 0xf0000020"
       "W DP 0x0 OK 0x00000004" "R DP 0x4 OK 0xf0000000" "line reset"
       "TARGETSEL 0x11002927: deselected" "line reset"
       "TARGETSEL 0x21002927: deselected" "line reset"
       "TARGETSEL 0x01002927: selected" "R DP 0x0 OK 0x0bc12477"))
     (measured_ns
      (("SWCLK low" (200 200)) ("SWCLK high" (200 440)) (setup (180 13180))
       (hold (200 220))))
     (violations ()))
    ((dp 1)
     (log
      ("dormant to SWD" "line reset" "TARGETSEL 0x01002927: deselected"
       "line reset" "TARGETSEL 0x11002927: selected" "R DP 0x0 OK 0x0bc12477"
       "line reset" "TARGETSEL 0x21002927: deselected" "line reset"
       "TARGETSEL 0x01002927: deselected"))
     (measured_ns
      (("SWCLK low" (200 200)) ("SWCLK high" (200 440)) (setup (180 3800))
       (hold (200 220))))
     (violations ()))
    ((contention ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (tx_left 0))
    |}]
;;

let%expect_test "a read whose parity is wrong" =
  let bus = Bus.create [ dp ~corrupt_parity:true rp2040_core0 ] in
  let items = [ Item.Bits dormant_to_swd; Bits line_reset; read 0x0; read 0x0 ] in
  let machine, bus, pushed = run ~cycles:12_000 ~bus items in
  print ~machine ~bus ~pushed items;
  [%expect
    {|
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack Ok) (data (0xbc12477)) (parity_error true))))
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack Ok) (data (0xbc12477)) (parity_error true))))
    ((dp 0)
     (log
      ("dormant to SWD" "line reset" "R DP 0x0 OK 0x0bc12477"
       "R DP 0x0 OK 0x0bc12477"))
     (measured_ns
      (("SWCLK low" (200 200)) ("SWCLK high" (200 440)) (setup (180 600))
       (hold (200 220))))
     (violations ()))
    ((contention ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (tx_left 0))
    |}]
;;

(* A DP whose first two OK ACKs the wire garbles goes on with the data phase: RDATA for
   the read, which the core lets be, and WDATA for the write, which the core does not
   send. A line reset after, and the DP answers as it should. *)
let%expect_test "ACKs the wire garbled" =
  let bus = Bus.create [ dp ~corrupt_acks:2 rp2040_core0 ] in
  let items =
    [ Item.Bits dormant_to_swd
    ; Bits line_reset
    ; read 0x0
    ; write 0x0 0x04
    ; Bits line_reset
    ; read 0x0
    ]
  in
  let machine, bus, pushed = run ~cycles:20_000 ~bus items in
  print ~machine ~bus ~pushed items;
  [%expect
    {|
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack (Invalid 5)) (data ()) (parity_error false))))
    ((transfer (Write (ap false) (address 0) (value 0x4)))
     (reply ((ack (Invalid 5)) (data ()) (parity_error false))))
    ((transfer (Read (ap false) (address 0)))
     (reply ((ack Ok) (data (0xbc12477)) (parity_error false))))
    ((dp 0)
     (log
      ("dormant to SWD" "line reset" "R DP 0x0 OK 0x0bc12477, ACK garbled"
       "W DP 0x0 with no WDATA" "line reset" "R DP 0x0 OK 0x0bc12477"))
     (measured_ns
      (("SWCLK low" (200 200)) ("SWCLK high" (200 440)) (setup (180 3000))
       (hold (200 220))))
     (violations ()))
    ((contention ())
     (fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (tx_left 0))
    |}]
;;

(* The requests of Figures B4-8 and B4-9, as they go on the wire, and the selection alert
   from the LFSR of Figure B5-10, its taps numbered from the input end: a zero, then the
   register's bit 0 each cycle. *)
let%expect_test "the spec's requests and selection alert" =
  let wire byte =
    String.init 8 ~f:(fun i -> if (byte lsr i) land 1 = 1 then '1' else '0')
  in
  let alert =
    List.init 127 ~f:Fn.id
    |> List.fold_map ~init:0b1001001 ~f:(fun lfsr _ ->
      let feedback = lfsr lxor (lfsr lsr 1) lxor (lfsr lsr 3) lxor (lfsr lsr 6) land 1 in
      (lfsr lsr 1) lor (feedback lsl 6), lfsr land 1)
    |> snd
    |> List.cons 0
  in
  let sent =
    List.concat_map selection_alert ~f:(fun word ->
      List.init 16 ~f:(fun i -> (word lsr i) land 1))
  in
  print_s
    [%message
      ""
        ~dpidr_read:(wire (Transfer.request (Read { ap = false; address = 0 })) : string)
        ~targetsel:(wire (Transfer.request (Targetsel rp2040_core0)) : string)
        ~alert_is_the_lfsr:([%equal: int list] alert sent : bool)];
  [%expect {| ((dpidr_read 10100101) (targetsel 10011001) (alert_is_the_lfsr true)) |}]
;;

let%expect_test "every edge and every sample is placed by a deadline" =
  Timing_report.print ~config ~period:standard_half (Timed_program.source firmware);
  [%expect
    {|
      0  set pindirs, 1 side 1        phase ?..?  edge ?..?  jitter ?  side ?..?  jitter ?
     15  out pins, 1 side 0           phase -24  edge -23  side -23  gap 32..?
     17  nop side 1                   phase -24  side -23
     27  set pins, 1 side 0           phase -24  edge -23  side -23  gap 32..?
     29  nop side 1                   phase -24  side -23
     31  out pins, 1 side 0           phase -24  edge -23  side -23  gap 50
     33  nop side 1                   phase -24  side -23
     35  out y, 1 side 0              phase -24  side -23
     36  mov pins, y side 0           phase -23  edge -22  gap 51
     38  set x, 4 side 1              phase -24  side -23
     40  out pins, 1 side 0           phase -24  edge -23  side -23  gap 47..52
     42  nop side 1                   phase -24  side -23
     45  set pindirs, 0 side 0        phase -24  edge -23  side -23  gap 50
     46  set pins, 0 side 0           phase -23  edge -22  gap 1
     48  nop side 1                   phase -24  side -23
     50  in pins, 1 side 0            phase -24  sample -24  side -23
     52  nop side 1                   phase -24  side -23
     54  in pins, 1 side 0            phase -24  sample -24  side -23
     56  nop side 1                   phase -24  side -23
     58  in pins, 1 side 0            phase -24  sample -24  side -23
     62  nop side 1                   phase -24  side -23
     69  mov y, x side 0              phase -24  side -23
     72  nop side 1                   phase -24  side -23
     73  set pindirs, 1 side 1        phase -23  edge -22  gap 222..228
     78  out pins, 1 side 0           phase -24  edge -23  side -23  gap 24..?
     80  nop side 1                   phase -24  side -23
     86  out pins, 1 side 0           phase -24  edge -23  side -23  gap 46..?
     88  nop side 1                   phase -24  side -23
     93  mov pins, isr side 0         phase -24  edge -23  side -23  gap 50
     95  nop side 1                   phase -24  side -23
    108  mov y, x side 0              phase -24  side -23
    112  nop side 1                   phase -24  side -23
    113  set pindirs, 1 side 1        phase -23  edge -22  gap 220..230
    127  nop side 1                   phase -24  side -23
    129  nop side 0                   phase -24  side -23
    132  nop side 1                   phase -24  side -23
    134  nop side 0                   phase -24  side -23
    136  nop side 1                   phase -24  side -23
    137  set pindirs, 1 side 1        phase -23  edge -22  gap 325..?
    145  in pins, 1 side 0            phase -24  sample -24  side -23
    147  nop side 1                   phase -24  side -23
    152  in pins, 1 side 0            phase -24  sample -24  side -23
    154  nop side 1                   phase -24  side -23
    158  in pins, 1 side 0            phase -24  sample -24  side -23
    160  nop side 1                   phase -24  side -23
    162  nop side 0                   phase -24  side -23
    164  nop side 1                   phase -24  side -23
    165  set pindirs, 1 side 1        phase -23  edge -22  gap 375..?
    168  mov y, x side 0              phase -24  side -23
    172  nop side 1                   phase -24  side -23
    173  set pindirs, 1 side 1        phase -23  edge -22  gap 220..230
    184  nop side 1                   phase -24  side -23
    186  nop side 0                   phase -24  side -23
    189  nop side 1                   phase -24  side -23
    191  crc_init side 0              phase -24  side -23
    196  nop side 1                   phase -24  side -23
    197  set pindirs, 1 side 1        phase -23  edge -22  gap 325..?
    201  set pins, 0 side 0           phase -24  edge -23  side -23  gap 20..?
    203  nop side 1                   phase -24  side -23
    ((words 210) (edge_jitter unbounded) (sample_jitter 0)
     (side_jitter unbounded) (may_miss 0))
    |}]
;;

let%expect_test "the shortest half period" =
  let check period_floor =
    Timed_program.check ~config ~period_floor (Timed_program.source firmware)
    |> Result.is_ok
  in
  print_s [%message (check shortest_half : bool) (check (shortest_half - 1) : bool)];
  [%expect {| (("check shortest_half" true) ("check (shortest_half - 1)" false)) |}]
;;

(* swd joins [Certified.all] once its certificate is inductive: t is stale at a host
   wait. *)
let%expect_test "the kernel accepts swd at its half period" =
  let program = Asm.assemble (Timed_program.source firmware) |> ok_exn in
  let config = Asm.Program.configure program config in
  let words = Asm.Program.words program |> ok_exn in
  let rows = Analyser.analyse ~period:standard_half ~config program.instructions in
  print_s
    [%sexp
      (Kernel.check ~period:standard_half ~config ~words (Kernel.Table.of_analyser rows)
       : unit Or_error.t)];
  [%expect {| (Ok ()) |}]
;;

(* The core against its RTL, through a wake-up, TARGETSEL, and a read and a write whose
   ACKs the wire garbles. *)
let%expect_test "swd in lockstep" =
  let bus = ref (Bus.create [ dp ~corrupt_acks:2 rp2040_core0; dp rp2040_core1 ]) in
  let schedule =
    ref
      (words
         [ Item.Bits dormant_to_swd
         ; Bits line_reset
         ; Transfer (Targetsel rp2040_core0)
         ; read 0x0
         ; write 0x0 0x1c
         ])
  in
  let tx_level = ref 0 in
  let model =
    Lockstep.lockstep
      ~cycles:12_000
      ~config:(Timed_program.config firmware)
      ~program:(Timed_program.words firmware)
      ~inputs:(fun _ -> Bus.inputs !bus)
      ~host:(fun _ ->
        match !schedule with
        | word :: rest when !tx_level < Machine.fifo_depth ->
          schedule := rest;
          { Lockstep.Host.idle with tx = Some word; pop_rx = true }
        | _ -> { Lockstep.Host.idle with pop_rx = true })
      ~react:(fun m ->
        tx_level := List.length m.tx_fifo;
        bus := Bus.step !bus ~pin_out:m.pin_out ~pin_dir:m.pin_dir)
      ()
  in
  print_s
    [%message
      ""
        ~log:(List.concat_map (Bus.dps !bus) ~f:Dp.log : string list)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ("lockstep held" (cycles 12000))
    ((log
      ("dormant to SWD" "line reset" "TARGETSEL 0x01002927: selected"
       "R DP 0x0 OK 0x0bc12477, ACK garbled" "W DP 0x0 with no WDATA"
       "dormant to SWD" "line reset" "TARGETSEL 0x01002927: deselected"))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
