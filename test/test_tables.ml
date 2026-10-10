open! Core
open Protocol_emulator
open Tables

(* A host that keeps the tx fifo from running dry and takes every rx word as it comes: the
   RTL and the model in lockstep, the model's pins after every cycle and every word it
   pushed. *)
let run ?(data = []) ?(react = ignore) ~cycles ~config ~program ~inputs ~host_words () =
  let preload = List.take host_words 8 in
  let rest = ref (List.drop host_words 8) in
  let last = ref None in
  let popped = Queue.create () in
  let pins = Queue.create () in
  let host _ =
    let tx_level, rx_head =
      match !last with
      | None -> 8, None
      | Some (m : Machine.t) -> List.length m.tx_fifo, List.hd m.rx_fifo
    in
    let tx =
      match !rest with
      | w :: ws when tx_level < 8 ->
        rest := ws;
        Some w
      | _ -> None
    in
    Option.iter rx_head ~f:(Queue.enqueue popped);
    { Lockstep.Host.idle with tx; pop_rx = Option.is_some rx_head }
  in
  let model, mismatch =
    Lockstep.run
      ~preload
      ~data
      ~host
      ~cycles
      ~config
      ~program
      ~inputs
      ~react:(fun m ->
        react m;
        last := Some m;
        Queue.enqueue pins (m.pin_out lor m.pin_dir))
      ()
  in
  (match mismatch with
   | None -> ()
   | Some (cycle, _, _) -> raise_s [%message "RTL and model differ" (cycle : int)]);
  model, Queue.to_array pins, Queue.to_list popped @ model.rx_fifo
;;

let image wiring =
  match check wiring with
  | Ok t -> Timed_program.config t, Timed_program.words t
  | Error r -> raise_s [%message "refused" (r.error : Error.t)]
;;

(* One raw entry a table index, outside [Tables.words]: the reference reads these. *)
module Entry = struct
  type t =
    { outputs : int
    ; kind : Kind.t
    ; next : int
    ; hold : int
    }

  let to_words t = [ t.hold; t.outputs lor (Kind.code t.kind lsl 6) lor (t.next lsl 10) ]
end

(* The class's timing, read off the interpreter's listing and written out here on its own:
   R is a step's release, A the cycle the step re-anchors at. Outputs show at R + 2;
   inputs are sampled once a step, at [sample]; the next release comes [hold + added]
   after R, or after A for a re-anchoring kind. *)
let reference
  ~first_release
  ~(wiring : Wiring.t)
  ~(table : int -> Entry.t)
  ~inputs
  ~host_words
  ~cycles
  =
  let out = Array.create ~len:cycles 0 in
  let pushed = Queue.create () in
  let pin p c = (inputs c lsr p) land 1 in
  let show ~from ~bits ~count =
    for c = from to cycles - 1 do
      let mask = ((1 lsl count) - 1) lsl wiring.out_base in
      out.(c) <- out.(c) land lnot mask lor ((bits lsl wiring.out_base) land mask)
    done
  in
  let rec await ~pin:p ~level c =
    if c >= cycles
    then None
    else if pin p c = level
    then Some c
    else await ~pin:p ~level (c + 1)
  in
  let rec go ~release ~p ~host (e : Entry.t) =
    if release + 2 < cycles
    then (
      show ~from:(release + 2) ~bits:e.outputs ~count:output_bits;
      let after ~sample ~next_release ~p ~host = Some (sample, next_release, p, host) in
      let step =
        match e.kind with
        | Plain ->
          after ~sample:(release + 14) ~next_release:(release + e.hold + 19) ~p ~host
        | Shift ->
          let p = ((2 * p) + pin wiring.in_base (release + 9)) land 0xffff in
          after ~sample:(release + 21) ~next_release:(release + e.hold + 26) ~p ~host
        | Pull ->
          after
            ~sample:(release + 23)
            ~next_release:(release + e.hold + 28)
            ~p:(List.hd_exn host)
            ~host:(List.tl_exn host)
        | Push ->
          if release + 15 < cycles then Queue.enqueue pushed p;
          after ~sample:(release + 26) ~next_release:(release + e.hold + 31) ~p ~host
        | Stamp ->
          if release + 15 < cycles then Queue.enqueue pushed ((release + 15) land 0xffff);
          after ~sample:(release + 26) ~next_release:(release + e.hold + 31) ~p ~host
        | Burst ->
          let word = List.hd_exn host in
          let anchor = release + 20 in
          let bit_cycles = e.hold + 6 in
          let n = (word land 0xf) + 1 in
          List.init n ~f:Fn.id
          |> List.iter ~f:(fun i ->
            let at = anchor + 4 + (i * bit_cycles) in
            if at + 2 < cycles
            then show ~from:(at + 2) ~bits:((word lsr (4 + i)) land 1) ~count:1);
          let last = anchor + 4 + ((n - 1) * bit_cycles) in
          after
            ~sample:(last + 17)
            ~next_release:(last + bit_cycles + 16)
            ~p
            ~host:(List.tl_exn host)
        | Await_host ->
          let anchor = release + 23 in
          after
            ~sample:(anchor + 11)
            ~next_release:(anchor + e.hold + 16)
            ~p:(List.hd_exn host)
            ~host:(List.tl_exn host)
        | Await { pin = which; level } ->
          let opens =
            match which, level with
            | A, true -> 21
            | A, false -> 23
            | B, _ -> 25
          in
          let watched =
            match which with
            | A -> wiring.await_a
            | B -> wiring.await_b
          in
          Option.bind
            (await ~pin:watched ~level:(Bool.to_int level) (release + opens))
            ~f:(fun w ->
              let anchor = w in
              after ~sample:(anchor + 12) ~next_release:(anchor + e.hold + 17) ~p ~host)
      in
      match step with
      | None -> ()
      | Some (sample, _, _, _) when sample >= cycles -> ()
      | Some (sample, next_release, p, host) ->
        let state = e.next land (Wiring.states wiring - 1) in
        let ins = (inputs sample lsr wiring.in_base) land ((1 lsl wiring.inputs) - 1) in
        let index = ((p lsr 15) lsl 7) lor (state lsl wiring.inputs) lor ins in
        go ~release:next_release ~p ~host (table index))
  in
  go ~release:first_release ~p:0 ~host:host_words (table 0);
  out, Queue.to_list pushed
;;

let random_entry rand ~(wiring : Wiring.t) =
  let kinds = Array.of_list Kind.all in
  let entry =
    Array.init entries ~f:(fun _ ->
      let kind =
        if Random.State.int rand 3 = 0
        then Kind.Plain
        else kinds.(Random.State.int rand (Array.length kinds))
      in
      { Entry.outputs = Random.State.int rand 64
      ; kind
      ; next = Random.State.int rand (Wiring.states wiring)
      ; hold =
          (if Random.State.int rand 10 = 0
           then Random.State.int rand 200
           else Random.State.int rand 8)
      })
  in
  fun index -> entry.(index)
;;

let random_inputs rand ~cycles =
  let levels = Array.create ~len:cycles 0 in
  let level = ref 0 in
  Array.iteri levels ~f:(fun c _ ->
    if Random.State.int rand 9 = 0
    then level := Random.State.int rand (1 lsl Isa.pin_space);
    levels.(c) <- !level);
  fun c -> levels.(c)
;;

(* host words whose low four bits ask at most 12 bits of a burst *)
let random_host_words rand ~n =
  List.init n ~f:(fun _ ->
    (Random.State.int rand 0x1000 lsl 4) lor Random.State.int rand burst_bits)
;;

(* the pins read are never ones the core drives, which would read back what it drives *)
let wirings =
  List.concat_map (List.range 1 7) ~f:(fun inputs ->
    [ { Wiring.default with
        inputs
      ; in_base = (if inputs <= 5 then 0 else Isa.first_bidir_pin)
      }
    ; { Wiring.inputs
      ; in_base = (if inputs <= 5 then 0 else Isa.num_pins)
      ; out_base = Isa.first_bidir_pin + 2
      ; open_drain = true
      ; await_a = Isa.first_bidir_pin
      ; await_b = Isa.first_bidir_pin + 1
      }
    ])
;;

let%expect_test "random tables of every kind: RTL, model and reference agree" =
  let tables = 64 in
  let cycles = 3000 in
  let differing = ref 0 in
  let pushed_words = ref 0 in
  let used = Hashtbl.create (module Int) in
  List.iter (List.range 0 tables) ~f:(fun seed ->
    let rand = Random.State.make [| seed |] in
    let wiring = List.nth_exn wirings (seed % List.length wirings) in
    let config, program = image wiring in
    let table = random_entry rand ~wiring in
    let inputs = random_inputs rand ~cycles in
    let host_words = random_host_words rand ~n:(cycles / 10) in
    let model, pins, pushed =
      run
        ~react:(fun m -> Hashtbl.incr used m.pc)
        ~data:(List.init entries ~f:table |> List.concat_map ~f:Entry.to_words)
        ~cycles
        ~config
        ~program
        ~inputs
        ~host_words
        ()
    in
    let expected, expected_pushed =
      reference ~first_release:10 ~wiring ~table ~inputs ~host_words ~cycles
    in
    let mask = ((1 lsl output_bits) - 1) lsl wiring.out_base in
    let differs =
      Array.findi pins ~f:(fun c v -> v land mask <> expected.(c) land mask)
    in
    pushed_words := !pushed_words + List.length pushed;
    if Option.is_some differs
       || (not ([%equal: int list] pushed expected_pushed))
       || not (Machine.Fault.equal model.fault Machine.Fault.none)
    then (
      incr differing;
      print_s
        [%message
          "differs"
            (seed : int)
            (wiring : Wiring.t)
            ~cycle:(Option.map differs ~f:fst : int option)
            (model.fault : Machine.Fault.t)]));
  let program = Asm.assemble (interpreter Wiring.default) |> ok_exn in
  let unreached =
    List.range 0 (List.length program.instructions)
    |> List.filter ~f:(fun pc -> not (Hashtbl.mem used pc))
  in
  print_s
    [%message
      (tables : int)
        (cycles : int)
        ~differing:(!differing : int)
        ~words_pushed:(!pushed_words : int)
        (unreached : int list)];
  [%expect
    {| ((tables 64) (cycles 3000) (differing 0) (words_pushed 494) (unreached (0))) |}]
;;

let%expect_test "the kernel accepts the interpreter at every wiring, with data memory \
                 unknown"
  =
  List.iter wirings ~f:(fun wiring ->
    match check wiring with
    | Ok t ->
      print_s
        [%message
          ""
            ~inputs:(wiring.inputs : int)
            ~open_drain:(wiring.open_drain : bool)
            ~verdict:(Timed_program.verdict t : Analyser.Verdict.t)]
    | Error r -> print_s [%message "refused" (wiring : Wiring.t) (r.error : Error.t)]);
  (* teeth: any one path's [add t] a cycle short is refused *)
  let source = interpreter Wiring.default in
  List.iter
    (List.dedup_and_sort ~compare (List.map Kind.all ~f:Kind.added))
    ~f:(fun added ->
      let short =
        String.substr_replace_all
          source
          ~pattern:[%string "set y, %{added#Int}\n"]
          ~with_:[%string "set y, %{added - 1#Int}\n"]
      in
      match Timed_program.check ~config:(config Wiring.default) short with
      | Ok _ -> print_s [%message "accepted a cycle short" (added : int)]
      | Error r ->
        print_s
          [%message
            "a cycle short, refused"
              (added : int)
              ~at:(List.map r.faults ~f:(fun f -> f.pc) : int option list)]);
  (match
     Timed_program.check
       ~config:(config Wiring.default)
       (String.substr_replace_first source ~pattern:"add t, 6" ~with_:"add t, 5")
   with
   | Ok _ -> print_s [%message "accepted a burst bit a cycle short"]
   | Error r ->
     print_s
       [%message
         "a burst bit a cycle short, refused"
           ~at:(List.map r.faults ~f:(fun f -> f.pc) : int option list)]);
  [%expect
    {|
    ((inputs 1) (open_drain false)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 1) (open_drain true)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 2) (open_drain false)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 2) (open_drain true)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 3) (open_drain false)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 3) (open_drain true)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 4) (open_drain false)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 4) (open_drain true)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 5) (open_drain false)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 5) (open_drain true)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 6) (open_drain false)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ((inputs 6) (open_drain true)
     (verdict ((words 106) (deadline_waits 2) (worst_slack (0)))))
    ("a cycle short, refused" (added 16) (at ((5))))
    ("a cycle short, refused" (added 17) (at ((5))))
    ("a cycle short, refused" (added 19) (at ((5))))
    ("a cycle short, refused" (added 26) (at ((5))))
    ("a cycle short, refused" (added 28) (at ((5))))
    ("a cycle short, refused" (added 31) (at ((5))))
    ("a burst bit a cycle short, refused" (at ((5) (58))))
    |}]
;;

let%expect_test "every row of the interpreter, k = 1" =
  (match check Wiring.default with
   | Ok t -> print_endline (Analyser.to_string ~side_set_count:0 (Timed_program.rows t))
   | Error _ -> ());
  [%expect
    {|
      0  set x, 0                     phase ?..?
      1  seek [1]                     phase ?..?
      2  out y, 16                    phase ?..?
      3  mov t, now                   phase ?..?
      4  add t, 7                     phase 1
      5  wait t                       phase -65535..0  slack 0..65535
      6  out pins, 6                  phase 1  edge 2  gap ?..?
      7  add t, y                     phase 2
      8  out x, 4                     phase -65532..3
      9  jmp x--, 22                  phase -65531..4
     10  set y, 19                    phase -65529..6
     11  add t, y                     phase -65528..7
     12  out x, 6                     phase -65546..-11
     13  set y, 0                     phase -65545..-10
     14  add y, p                     phase -65544..-9
     15  mov isr, ::y                 phase -65543..-8
     16  in x, 6                      phase -65542..-7
     17  in pins, 1                   phase -65541..-6  sample -65541..-6  jitter 65535
     18  in null, 1                   phase -65540..-5
     19  mov x, isr                   phase -65539..-4
     20  seek [1]                     phase -65538..-3
     21  out y, 16                    phase -65536..-1
     22  jmp x--, 29                  phase -65529..6
     23  mov x, pins                  phase -65527..8  sample -65527..8  jitter 65535
     24  add p, p                     phase -65526..9
     25  add p, x                     phase -65525..10
     26  set y, 26                    phase -65524..11
     27  add t, y                     phase -65523..12
     28  jmp 12                       phase -65548..-13
     29  jmp x--, 37                  phase -65527..8
     30  out x, 6                     phase -65525..10
     31  pull                         phase -65524..11
     32  mov p, osr                   phase -65523..12
     33  out null, 16                 phase -65522..13
     34  set y, 28                    phase -65521..14
     35  add t, y                     phase -65520..15
     36  jmp 13                       phase -65547..-12
     37  jmp x--, 45                  phase -65525..10
     38  set y, 0                     phase -65523..12
     39  add y, p                     phase -65522..13
     40  mov isr, y                   phase -65521..14
     41  push                         phase -65520..15
     42  set y, 31                    phase -65519..16
     43  add t, y                     phase -65518..17
     44  jmp 12                       phase -65548..-13
     45  jmp x--, 51                  phase -65523..12
     46  mov isr, now                 phase -65521..14
     47  push                         phase -65520..15
     48  set y, 31                    phase -65519..16
     49  add t, y                     phase -65518..17
     50  jmp 12                       phase -65548..-13
     51  jmp x--, 68                  phase -65521..14
     52  out isr, 6                   phase -65519..16
     53  wait tx                      phase -65518..17
     54  pull                         phase -65517..?
     55  out x, 4                     phase -65516..?
     56  mov t, now                   phase -65515..?
     57  add t, 4                     phase 1
     58  wait t                       phase -65535..0  slack 0..65535
     59  out pins, 1                  phase 1  edge 2  gap 6..?
     60  add t, y                     phase 2
     61  add t, 6                     phase -65532..3
     62  jmp x--, 58                  phase -65537..-2
     63  mov x, isr                   phase -65535..0
     64  out null, 16                 phase -65534..1
     65  set y, 16                    phase -65533..2
     66  add t, y                     phase -65532..3
     67  jmp 13                       phase -65547..-12
     68  jmp x--, 79                  phase -65519..16
     69  out x, 6                     phase -65517..18
     70  wait tx                      phase -65516..19
     71  pull                         phase -65515..?
     72  mov p, osr                   phase -65514..?
     73  out null, 16                 phase -65513..?
     74  mov t, now                   phase -65512..?
     75  add t, y                     phase 1
     76  set y, 16                    phase -65533..2
     77  add t, y                     phase -65532..3
     78  jmp 13                       phase -65547..-12
     79  jmp x--, 86                  phase -65517..18
     80  wait 1 pin 0                 phase -65515..20
     81  mov t, now                   phase -65514..?
     82  add t, y                     phase 1
     83  set y, 17                    phase -65533..2
     84  add t, y                     phase -65532..3
     85  jmp 12                       phase -65548..-13
     86  jmp x--, 93                  phase -65515..20
     87  wait 0 pin 0                 phase -65513..22
     88  mov t, now                   phase -65512..?
     89  add t, y                     phase 1
     90  set y, 17                    phase -65533..2
     91  add t, y                     phase -65532..3
     92  jmp 12                       phase -65548..-13
     93  jmp x--, 100                 phase -65513..22
     94  wait 1 pin 1                 phase -65511..24
     95  mov t, now                   phase -65510..?
     96  add t, y                     phase 1
     97  set y, 17                    phase -65533..2
     98  add t, y                     phase -65532..3
     99  jmp 12                       phase -65548..-13
    100  wait 0 pin 1                 phase -65511..24
    101  mov t, now                   phase -65510..?
    102  add t, y                     phase 1
    103  set y, 17                    phase -65533..2
    104  add t, y                     phase -65532..3
    105  jmp 12                       phase -65548..-13
    |}]
;;

(* every change of the watched pins: cycle, pin, level *)
let edges ~watch pins =
  List.concat_mapi (Array.to_list pins) ~f:(fun c p ->
    List.filter_map watch ~f:(fun pin ->
      let level = (p lsr pin) land 1 in
      if c > 0 && level <> (pins.(c - 1) lsr pin) land 1
      then Some (c, pin, level)
      else None))
;;

let table_image t =
  let config, program = image t.wiring in
  config, program, words t |> ok_exn
;;

(* each frame from its start edge after an idle high: the edges inside 10 bits, and the
   byte read mid bit *)
let uart_frames ~pin ~bit pins =
  let rec frames acc = function
    | [] -> List.rev acc
    | (c, _, 0) :: _ as rest ->
      let inside, after =
        List.split_while rest ~f:(fun (c', _, _) -> c' < c + (10 * bit))
      in
      let byte =
        List.init 8 ~f:(fun i ->
          ((pins.(c + (bit * (i + 1)) + (bit / 2)) lsr pin) land 1) lsl i)
        |> List.reduce_exn ~f:( lor )
      in
      frames ((byte, List.map inside ~f:(fun (c', _, l) -> c' - c, l)) :: acc) after
    | _ :: rest -> frames acc rest
  in
  frames [] (edges ~watch:[ pin ] pins)
;;

let%expect_test "uart tx, a bit at a time and by burst, against the library's" =
  let bytes = [ 0xa3; 0x00; 0xff; 0x5c ] in
  let pin = Isa.first_output_pin in
  List.iter
    [ "shift", (fun ~bit -> table_image (uart_tx ~bit)), uart_word, 26
    ; "burst", (fun ~bit -> table_image (uart_tx_burst ~bit)), uart_frame, 16
    ; "burst", (fun ~bit -> table_image (uart_tx_burst ~bit)), uart_frame, 8
    ]
    ~f:(fun (name, image, word, bit) ->
      let cycles = (4 * 14 * bit) + 400 in
      let _, native, _ =
        run
          ~cycles
          ~config:Program_config.default
          ~program:(Firmware.assemble (Uart.tx ~period:bit))
          ~inputs:(Fn.const 0)
          ~host_words:bytes
          ()
      in
      let config, program, data = image ~bit in
      let model, pins, _ =
        run
          ~data
          ~cycles
          ~config
          ~program
          ~inputs:(Fn.const 0)
          ~host_words:(List.map bytes ~f:word)
          ()
      in
      let native = uart_frames ~pin ~bit native in
      let table = uart_frames ~pin ~bit pins in
      print_s
        [%message
          name
            (bit : int)
            ~bytes:(List.map table ~f:fst : int list)
            ~edges_identical:([%equal: (int * (int * int) list) list] native table : bool)
            (model.fault : Machine.Fault.t)]);
  [%expect
    {|
    (shift (bit 26) (bytes (163 0 255 92)) (edges_identical true)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (burst (bit 16) (bytes (163 0 255 92)) (edges_identical true)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    (burst (bit 8) (bytes (163 0 255 92)) (edges_identical true)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let rev8 b =
  List.init 8 ~f:(fun i -> ((b lsr i) land 1) lsl (7 - i))
  |> List.sum (module Int) ~f:Fn.id
;;

let%expect_test "uart rx by awaiting the start edge, against the library's" =
  let bit = 31 in
  let rand = Random.State.make [| 3 |] in
  let bytes = List.init 12 ~f:(fun _ -> Random.State.int rand 256) in
  (* each frame after two bits of idle *)
  let line =
    List.concat_map bytes ~f:(fun b ->
      [ 1; 1; 0 ] @ List.init 8 ~f:(fun i -> (b lsr i) land 1) @ [ 1 ])
    |> Array.of_list
  in
  let lead = 100 in
  let inputs c =
    if c < lead || (c - lead) / bit >= Array.length line
    then 1
    else line.((c - lead) / bit)
  in
  let cycles = lead + (bit * Array.length line) + 200 in
  let _, _, native =
    run
      ~cycles
      ~config:Uart.rx_config
      ~program:(Firmware.assemble (Uart.rx ~period:bit))
      ~inputs
      ~host_words:[]
      ()
  in
  let config, program, data = table_image (uart_rx ~bit) in
  let model, _, table = run ~data ~cycles ~config ~program ~inputs ~host_words:[] () in
  print_s
    [%message
      ""
        (bit : int)
        (bytes : int list)
        ~native:(List.map native ~f:(fun w -> w land 0xff) : int list)
        ~table:(List.map table ~f:(fun w -> rev8 (w land 0xff)) : int list)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ((bit 31) (bytes (51 48 221 112 94 153 208 75 50 135 133 127))
     (native (51 48 221 112 94 153 208 75 50 135 133 127))
     (table (51 48 221 112 94 153 208 75 50 135 133 127))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "spi master, full duplex, against the library's" =
  let half = 26 in
  let sent = [ 0xa5; 0x3c; 0x01 ] in
  let slave = [ 0x96; 0xf0; 0x80 ] in
  let cycles = 2500 in
  (* a mode 0 slave: MISO shows the next bit after each falling SCK *)
  let peer () =
    let bits =
      List.concat_map slave ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1))
      |> Array.of_list
    in
    let index = ref 0 in
    let sck = ref 0 in
    let inputs _ =
      if !index < Array.length bits then bits.(!index) lsl Spi.miso_pin else 0
    in
    let react (m : Machine.t) =
      let level = (m.pin_out lsr Spi.sck_pin) land 1 in
      if !sck = 1 && level = 0 then incr index;
      sck := level
    in
    inputs, react
  in
  (* SCK's rises from the first of each byte, and MOSI at each *)
  let observe pins =
    let rises =
      edges ~watch:[ Spi.sck_pin ] pins |> List.filter ~f:(fun (_, _, l) -> l = 1)
    in
    ( List.map rises ~f:(fun (c, _, _) -> (pins.(c) lsr Spi.mosi_pin) land 1)
    , List.chunks_of rises ~length:8
      |> List.map ~f:(fun byte ->
        let first = Tuple3.get1 (List.hd_exn byte) in
        List.map byte ~f:(fun (c, _, _) -> c - first)) )
  in
  let with_peer ~config ~program ~data ~host_words =
    let inputs, react = peer () in
    run ~react ~data ~cycles ~config ~program ~inputs ~host_words ()
  in
  let _, native, native_rx =
    with_peer
      ~config:Spi.config
      ~program:(Firmware.assemble (Spi.master ~half_period:half))
      ~data:[]
      ~host_words:sent
  in
  let config, program, data = table_image (spi_master ~half) in
  let model, pins, table_rx =
    with_peer ~config ~program ~data ~host_words:(List.map sent ~f:(fun b -> b lsl 8))
  in
  let native_mosi, native_spacing = observe native in
  let table_mosi, table_spacing = observe pins in
  print_s
    [%message
      ""
        (half : int)
        ~mosi_at_rises_identical:([%equal: int list] native_mosi table_mosi : bool)
        ~sck_rises_identical:([%equal: int list list] native_spacing table_spacing : bool)
        ~native_read:(List.map native_rx ~f:(fun w -> w land 0xff) : int list)
        ~table_read:(List.map table_rx ~f:(fun w -> w land 0xff) : int list)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ((half 26) (mosi_at_rises_identical true) (sck_rises_identical true)
     (native_read (150 240 128)) (table_read (150 240 128))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "dshot600 from host frames, against the library's" =
  let frames =
    [ Dshot.frame ~throttle:1046 ~telemetry:false
    ; Dshot.frame ~throttle:2047 ~telemetry:true
    ; Dshot.frame ~throttle:48 ~telemetry:false
    ]
  in
  let cycles = 6000 in
  let _, native, _ =
    run
      ~cycles
      ~config:Dshot.config
      ~program:(Firmware.assemble Dshot.dshot600)
      ~inputs:(Fn.const 0)
      ~host_words:frames
      ()
  in
  let config, program, data = table_image (dshot ~zero_high:31 ~bit:83) in
  let model, pins, _ =
    run ~data ~cycles ~config ~program ~inputs:(Fn.const 0) ~host_words:frames ()
  in
  (* each frame's edges from its first rise *)
  let per_frame pins =
    edges ~watch:[ Dshot.pin ] pins
    |> List.group ~break:(fun (a, _, _) (b, _, _) -> b - a > 200)
    |> List.map ~f:(fun es ->
      let first = Tuple3.get1 (List.hd_exn es) in
      List.map es ~f:(fun (c, _, l) -> c - first, l))
  in
  let levels pins =
    Array.to_list pins |> List.map ~f:(fun p -> (p lsr Dshot.pin) land 1 = 1)
  in
  let decoded pins =
    Dshot.decode Dshot.Rate.dshot600 ~cycle_ns:Dshot.cycle_ns (levels pins)
    |> Or_error.map ~f:fst
  in
  print_s
    [%message
      ""
        ~edges_a_frame:(List.map (per_frame pins) ~f:List.length : int list)
        ~identical:
          ([%equal: (int * int) list list] (per_frame native) (per_frame pins) : bool)
        ~decoded:(decoded pins : (int * bool) list Or_error.t)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ((edges_a_frame (32 32 32)) (identical true)
     (decoded (Ok ((1046 false) (2047 true) (48 false))))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "i2c slave by the second await pin, against the library's" =
  let module Peer = Protocol_models.I2c_peer in
  let ops : Peer.Op.t list =
    [ Start
    ; Write 0xa0
    ; Write 3
    ; Write 0xaa
    ; Stop
    ; Start
    ; Write 0xa2
    ; Write 1
    ; Stop
    ; Start
    ; Write 0xa0
    ; Write 0x55
    ; Start
    ; Write 0xa0
    ; Write 0x80
    ; Stop
    ]
  in
  let on_bus ~quarter ~config ~program ~data ~host_words =
    let master = ref (Peer.create ~quarter ops) in
    let dir = ref 0 in
    let bus_sda = ref 1 in
    (* the bus idles while both cores start *)
    let lead = 100 in
    let inputs c =
      let sda, scl = if c < lead then 1, 1 else Peer.sda !master, Peer.scl !master in
      bus_sda := sda land (1 - ((!dir lsr I2c.sda) land 1));
      (!bus_sda lsl I2c.sda) lor (scl lsl I2c.scl)
    in
    let cycle = ref 0 in
    let react (m : Machine.t) =
      if !cycle >= lead then master := Peer.step !master ~sda:!bus_sda;
      incr cycle;
      dir := m.pin_dir
    in
    let cycles = quarter * 4 * 9 * 12 in
    let model, _, received =
      run ~react ~data ~cycles ~config ~program ~inputs ~host_words ()
    in
    model, received, Peer.log !master, Peer.idle !master
  in
  List.iter [ 125; 32 ] ~f:(fun quarter ->
    let _, native, native_log, _ =
      on_bus
        ~quarter
        ~config:I2c.slave_config
        ~program:(Timed_program.words I2c.slave)
        ~data:[]
        ~host_words:[ 0x50 lsl 1 ]
    in
    let config, program, data = table_image (i2c_slave ~address:0x50 ~sda:I2c.sda) in
    let model, table, table_log, idle =
      on_bus
        ~quarter
        ~config
        ~program
        ~data
        ~host_words:(List.init 16 ~f:(fun _ -> marker))
    in
    print_s
      [%message
        ""
          ~kHz:(50_000 / (4 * quarter) : int)
          ~native:(List.filter native ~f:(fun w -> w <> 0xa0) : int list)
          ~table:(List.map table ~f:(fun w -> w lxor 0x8000) : int list)
          ~logs_identical:([%equal: string list] native_log table_log : bool)
          (table_log : string list)
          (idle : bool)
          (model.fault : Machine.Fault.t)]);
  [%expect
    {|
    ((kHz 100) (native (3 170 85 128)) (table (3 170 85 128))
     (logs_identical true) (table_log (ack ack ack nack nack ack ack ack ack))
     (idle true)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((kHz 390) (native (3 170 85 128)) (table (3 170 85 128))
     (logs_identical true) (table_log (ack ack ack nack nack ack ack ack ack))
     (idle true)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

module Counter = struct
  type t = int [@@deriving equal, sexp_of]
end

(* a ring of [states] plain steps, with one entry changed by [edit] *)
let ring ?(wiring = Wiring.default) ?(edit = Fn.id) states =
  { name = "ring"
  ; wiring
  ; state = (module Counter)
  ; states = List.range 0 states
  ; step =
      (fun state ~host_bit:_ ~inputs:_ ->
        let step =
          { Step.outputs = state land 0x3f
          ; kind = Plain
          ; cycles = Kind.least Plain
          ; next = (state + 1) % states
          }
        in
        if state = 0 then edit step else step)
  }
;;

let%expect_test "the compiler takes a table inside the class and refuses one outside" =
  let show table =
    match words table with
    | Ok words -> print_s [%message "fits" ~words:(List.length words : int)]
    | Error e -> print_s [%message "outside the class" (e : Error.t)]
  in
  let cycles ?(kind = Kind.Plain) cycles =
    ring ~edit:(fun s -> { s with kind; cycles }) 4
  in
  show (ring 64);
  show (ring 65);
  show (ring ~wiring:{ Wiring.default with inputs = 3 } 16);
  show (ring ~wiring:{ Wiring.default with inputs = 3 } 17);
  show (cycles (Kind.least Plain + max_hold));
  show (cycles (Kind.least Plain + max_hold + 1));
  show (cycles (Kind.least Plain - 1));
  show (cycles ~kind:Push (Kind.least Push - 1));
  show (cycles ~kind:Burst Kind.burst_bit);
  show (cycles ~kind:Burst (Kind.burst_bit - 1));
  show (ring ~edit:(fun s -> { s with outputs = 64 }) 4);
  show (ring ~edit:(fun s -> { s with next = 9 }) 4);
  show (ring ~wiring:{ Wiring.default with inputs = 7 } 1);
  show (ring ~wiring:{ Wiring.default with open_drain = true } 1);
  [%expect
    {|
    (fits (words 512))
    ("outside the class"
     (e ("1 to 2^(7 - inputs) states" (count 65) (inputs 1))))
    (fits (words 512))
    ("outside the class"
     (e ("1 to 2^(7 - inputs) states" (count 17) (inputs 3))))
    (fits (words 512))
    ("outside the class"
     (e
      ((ring (state 0) (d 0) (inputs 0))
       ("cycles out of the kind's range" (kind Plain) (cycles 65555) (least 19)
        (most 65554)))))
    ("outside the class"
     (e
      ((ring (state 0) (d 0) (inputs 0))
       ("cycles out of the kind's range" (kind Plain) (cycles 18) (least 19)
        (most 65554)))))
    ("outside the class"
     (e
      ((ring (state 0) (d 0) (inputs 0))
       ("cycles out of the kind's range" (kind Push) (cycles 30) (least 31)
        (most 65566)))))
    (fits (words 512))
    ("outside the class"
     (e
      ((ring (state 0) (d 0) (inputs 0))
       ("cycles out of the kind's range" (kind Burst) (cycles 5) (least 6)
        (most 65541)))))
    ("outside the class"
     (e ((ring (state 0) (d 0) (inputs 0)) ("6 output bits" (outputs 64)))))
    ("outside the class"
     (e ((ring (state 0) (d 0) (inputs 0)) ("no such state" (next 9)))))
    ("outside the class" (e ("1 to 6 inputs" (t.inputs 7))))
    ("outside the class" (e ("pin out of range" out_base (p 5) (lo 12) (hi 14))))
    |}]
;;
