open! Core
open Protocol_emulator
open Protocol_emulator_test

(* The hold interpreter (route P) with a kind per entry. Seven kinds run a fixed step on
   the host word in [y] or re-anchor on an event; the host bit [y[15]] is the index's top
   bit, so the table reads host data as it reads an input. A kind that adds cycles adds
   them to [t] as well, so a step lasts [hold + extra kind] and the kernel checks every
   path under the one floor. Two words an entry: the hold, then outputs (6 bits), kind

   (3) and next state (7). *)

module Kind = struct
  type t =
    | Plain
    | Shift (** y <- 2y + the in_base pin, read 7 cycles after the release *)
    | Pull (** y <- the next host word, never stalls *)
    | Push (** host <- y *)
    | Stamp (** host <- now *)
    | Await_host (** wait for a host word, pull it, re-anchor *)
    | Await_high (** wait for the in_base pin high, re-anchor *)
    | Await_low
  [@@deriving sexp_of, equal, enumerate]

  let to_int t = List.findi_exn all ~f:(fun _ k -> equal k t) |> fst

  (* cycles the kind adds to its step; the waits re-anchor instead *)
  let extra = function
    | Plain | Await_host | Await_high | Await_low -> 0
    | Shift -> 9
    | Pull -> 11
    | Push -> 12
    | Stamp -> 14
  ;;
end

let floor = 14
let output_bits = 6

(* [drive] pindirs makes the outputs open drain: a 1 pulls the pin low. *)
let interpreter ?(drive = "pins") ?(edge_pin = 0) ~k () =
  [%string
    {|
    set x, 0
    seek [1]                 ; data_settle
    out p, 16                ; entry 0's hold
    mov t, now
    add t, p
.wrap_target
    wait t+                  ; release, then t <- t + hold
    out %{drive}, 6              ; the entry's outputs
    out x, 3                 ; its kind
    jmp x--, k_shift
join:
    out x, 7                 ; next state
join2:
    mov isr, ::y             ; the host bit y[15] goes to index bit 8
    in x, %{(7 - k)#Int}
    in pins, %{k#Int}
    in null, 1               ; two words an entry
    mov x, isr
    seek [1]
    out p, 16                ; the next entry's hold
.wrap
k_shift:
    jmp x--, k_pull
    mov x, pins              ; in_count 1
    add y, y
    add y, x
    add t, 7
    add t, 2
    jmp join
k_pull:
    jmp x--, k_push
    out x, 7
    pull
    mov y, osr
    out null, 16             ; the table's word is spent
    add t, 7
    add t, 4
    jmp join2
k_push:
    jmp x--, k_stamp
    mov isr, y
    push
    add t, 7
    add t, 5
    jmp join
k_stamp:
    jmp x--, k_await_host
    mov isr, now
    push
    add t, 7
    add t, 7
    jmp join
k_await_host:
    jmp x--, k_await_high
    out x, 7
    wait tx
    pull
    mov y, osr
    out null, 16
    mov t, now
    add t, p
    jmp join2
k_await_high:
    jmp x--, k_await_low
    wait 1 pin %{edge_pin#Int}
    mov t, now
    add t, p
    jmp join
k_await_low:
    wait 0 pin %{edge_pin#Int}
    mov t, now
    add t, p
    jmp join
|}]
;;

let config =
  { Program_config.default with
    out_base = Isa.first_output_pin
  ; out_count = output_bits
  ; in_base = 0
  ; in_count = 1
  ; out_shift = Right
  ; in_shift = Left
  ; autopull = true
  ; pull_threshold = 16
  ; autopull_data = true
  }
;;

let timed ?(period_floor = floor) ?drive ?edge_pin ?(config = config) ~k () =
  Timed_program.check ~period_floor ~config (interpreter ?drive ?edge_pin ~k ())
;;

let image ~k =
  match timed ~k () with
  | Ok t -> Timed_program.config t, Timed_program.words t
  | Error r -> raise_s [%message "refused" (r.error : Error.t)]
;;

module Entry = struct
  type t =
    { outputs : int
    ; kind : Kind.t
    ; next : int
    ; hold : int
    }
end

let states ~k = 1 lsl (7 - k)

(* entry i at words 2i, 2i+1, i = d << 7 | state << k | inputs *)
let words ~k (entry : d:int -> state:int -> inputs:int -> Entry.t) =
  List.init 256 ~f:(fun i ->
    let (e : Entry.t) =
      entry
        ~d:(i lsr 7)
        ~state:((i lsr k) land (states ~k - 1))
        ~inputs:(i land ((1 lsl k) - 1))
    in
    [ e.hold; e.outputs lor (Kind.to_int e.kind lsl 6) lor (e.next lsl 9) ])
  |> List.concat
;;

(* The specification, with the cycles read off the instruction listing: after a release at
   [r] the outputs show from [r + 1]; each kind's step reads, writes and samples at fixed
   offsets from [r], or from the anchor [a] a cycle after its wait releases. The host fifo
   is never empty here, so a pull takes the next word at once. *)
let reference ~k ~entry ~inputs ~host_words ~cycles =
  let out = Array.create ~len:cycles 0 in
  let pushed = Queue.create () in
  let pin c = inputs c land 1 in
  let rec await ~level c =
    if c >= cycles then None else if pin c = level then Some c else await ~level (c + 1)
  in
  let rec go ~release ~y ~host (e : Entry.t) =
    if release + 1 < cycles
    then (
      for c = release + 1 to cycles - 1 do
        out.(c) <- e.outputs
      done;
      let after_wait w ~sample ~y ~host =
        Some (w + 1 + sample, w + 1 + e.hold, y, host)
      in
      let step =
        match e.kind with
        | Plain -> Some (release + 8, release + e.hold, y, host)
        | Shift ->
          Some
            ( release + 17
            , release + e.hold + 9
            , ((2 * y) + pin (release + 7)) land 0xffff
            , host )
        | Pull ->
          Some (release + 19, release + e.hold + 11, List.hd_exn host, List.tl_exn host)
        | Push ->
          if release + 12 < cycles then Queue.enqueue pushed y;
          Some (release + 20, release + e.hold + 12, y, host)
        | Stamp ->
          if release + 14 < cycles then Queue.enqueue pushed ((release + 13) land 0xffff);
          Some (release + 22, release + e.hold + 14, y, host)
        | Await_host ->
          (* the wait is at r + 16 and the anchor four after it *)
          Some
            ( release + 16 + 4 + 6
            , release + 16 + 4 + e.hold
            , List.hd_exn host
            , List.tl_exn host )
        | Await_high ->
          Option.bind
            (await ~level:1 (release + 17))
            ~f:(fun w -> after_wait w ~sample:7 ~y ~host)
        | Await_low ->
          Option.bind
            (await ~level:0 (release + 17))
            ~f:(fun w -> after_wait w ~sample:7 ~y ~host)
      in
      match step with
      | None -> ()
      | Some (sample, next_release, y, host) ->
        let (e' : Entry.t) =
          entry ~d:(y lsr 15) ~state:e.next ~inputs:(inputs sample land ((1 lsl k) - 1))
        in
        go ~release:next_release ~y ~host e')
  in
  go
    ~release:(4 + (entry ~d:0 ~state:0 ~inputs:0).hold)
    ~y:0
    ~host:host_words
    (entry ~d:0 ~state:0 ~inputs:0);
  out, Queue.to_list pushed
;;

(* A host that keeps the tx fifo full and empties the rx fifo every cycle: the RTL and the
   model in lockstep, the model's pins after every cycle and every word it pushed. *)
let run ?(data = []) ~cycles ~config ~program ~inputs ~host_words () =
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
        last := Some m;
        Queue.enqueue pins m.pin_out)
      ()
  in
  (match mismatch with
   | None -> ()
   | Some (cycle, _, _) -> raise_s [%message "RTL and model differ" (cycle : int)]);
  model, Queue.to_array pins, Queue.to_list popped @ model.rx_fifo
;;

let outputs pins =
  Array.map pins ~f:(fun p -> (p lsr Isa.first_output_pin) land ((1 lsl output_bits) - 1))
;;

let%expect_test "the kernel on the interpreter, every kind, data memory unknown" =
  List.iter [ 1; 2; 3; 4 ] ~f:(fun k ->
    match timed ~k () with
    | Ok t ->
      print_s
        [%message
          "accepted" (k : int) ~verdict:(Timed_program.verdict t : Analyser.Verdict.t)]
    | Error r ->
      print_s [%message "refused" (k : int) (r.faults : Timed_program.Fault.t list)]);
  (match timed ~period_floor:(floor - 1) ~k:3 () with
   | Ok _ -> print_s [%message "accepted one short of the floor"]
   | Error r -> print_s [%message "one short" (r.faults : Timed_program.Fault.t list)]);
  (* open drain on the bidirectional pins, waiting on one of them *)
  (match
     timed
       ~drive:"pindirs"
       ~edge_pin:Isa.first_bidir_pin
       ~config:
         { config with out_base = Isa.first_bidir_pin; in_base = Isa.first_bidir_pin }
       ~k:2
       ()
   with
   | Ok t ->
     print_s
       [%message
         "open drain accepted" ~verdict:(Timed_program.verdict t : Analyser.Verdict.t)]
   | Error r ->
     print_s [%message "open drain refused" (r.faults : Timed_program.Fault.t list)]);
  (match timed ~k:3 () with
   | Ok t -> print_endline (Analyser.to_string ~side_set_count:0 (Timed_program.rows t))
   | Error _ -> ());
  [%expect
    {|
    (accepted (k 1) (verdict ((words 62) (deadline_waits 1) (worst_slack (0)))))
    (accepted (k 2) (verdict ((words 62) (deadline_waits 1) (worst_slack (0)))))
    (accepted (k 3) (verdict ((words 62) (deadline_waits 1) (worst_slack (0)))))
    (accepted (k 4) (verdict ((words 62) (deadline_waits 1) (worst_slack (0)))))
    ("one short"
     (r.faults
      (((line 8) (pc (5))
        (reason
         "this deadline wait can be reached late, by more on each pass of a loop or after an untimed wait")))))
    ("open drain accepted"
     (verdict ((words 62) (deadline_waits 1) (worst_slack (0)))))
      0  set x, 0                     phase ?..?
      1  seek [1]                     phase ?..?
      2  out p, 16                    phase ?..?
      3  mov t, now                   phase ?..?
      4  add t, p                     phase 1
      5  wait t+                      phase -65533..0  slack 0..65533
      6  out pins, 6                  phase -65534..-13  edge -65533..-12  jitter 65521  gap ?..?
      7  out x, 3                     phase -65533..-12
      8  jmp x--, 17                  phase -65532..-11
      9  out x, 7                     phase -65531..-9
     10  mov isr, ::y                 phase -65531..-8
     11  in x, 4                      phase -65530..-7
     12  in pins, 3                   phase -65529..-6  sample -65529..-6  jitter 65523
     13  in null, 1                   phase -65528..-5
     14  mov x, isr                   phase -65527..-4
     15  seek [1]                     phase -65526..-3
     16  out p, 16                    phase -65524..-1
     17  jmp x--, 24                  phase -65530..-9
     18  mov x, pins                  phase -65528..-7  sample -65528..-7  jitter 65521
     19  add y, y                     phase -65527..-6
     20  add y, x                     phase -65526..-5
     21  add t, 7                     phase -65525..-4
     22  add t, 2                     phase -65531..-10
     23  jmp 9                        phase -65532..-11
     24  jmp x--, 32                  phase -65528..-7
     25  out x, 7                     phase -65526..-5
     26  pull                         phase -65525..-4
     27  mov y, osr                   phase -65524..-3
     28  out null, 16                 phase -65523..-2
     29  add t, 7                     phase -65522..-1
     30  add t, 4                     phase -65528..-7
     31  jmp 10                       phase -65531..-10
     32  jmp x--, 38                  phase -65526..-5
     33  mov isr, y                   phase -65524..-3
     34  push                         phase -65523..-2
     35  add t, 7                     phase -65522..-1
     36  add t, 5                     phase -65528..-7
     37  jmp 9                        phase -65532..-11
     38  jmp x--, 44                  phase -65524..-3
     39  mov isr, now                 phase -65522..-1
     40  push                         phase -65521..0
     41  add t, 7                     phase -65520..1
     42  add t, 7                     phase -65526..-5
     43  jmp 9                        phase -65532..-11
     44  jmp x--, 53                  phase -65522..-1
     45  out x, 7                     phase -65520..1
     46  wait tx                      phase -65519..2
     47  pull                         phase -65518..?
     48  mov y, osr                   phase -65517..?
     49  out null, 16                 phase -65516..?
     50  mov t, now                   phase -65515..?
     51  add t, p                     phase 1
     52  jmp 10                       phase -65533..-12
     53  jmp x--, 58                  phase -65520..1
     54  wait 1 pin 0                 phase -65518..3
     55  mov t, now                   phase -65517..?
     56  add t, p                     phase 1
     57  jmp 9                        phase -65533..-12
     58  wait 0 pin 0                 phase -65518..3
     59  mov t, now                   phase -65517..?
     60  add t, p                     phase 1
     61  jmp 9                        phase -65533..-12
    |}]
;;

let%expect_test "the kernel accepts it at every load from the floor, by SAT" =
  let module G = Hardcaml_verify.Comb_gates in
  let program = Asm.assemble (interpreter ~k:3 ()) |> ok_exn in
  let config = Asm.Program.configure program config in
  let words = Asm.Program.words program |> ok_exn in
  let table =
    Analyser.analyse ~period_floor:floor ~config program.instructions
    |> Kernel.Table.of_analyser
  in
  let solver = Hardcaml_verify.Solver.z3 ~parallel:false () in
  List.iter
    [ floor; floor - 1 ]
    ~f:(fun least ->
      let claim =
        Table_query.every_load_from
          ~floor:least
          ~single_capture_edge:false
          ~config
          ~words
          table
      in
      match Hardcaml_verify.Solver.solve ~solver (G.cnf G.(~:claim)) with
      | Ok Unsat -> print_s [%message "every load accepted" (least : int)]
      | Ok (Sat _) -> print_s [%message "a load refused" (least : int)]
      | Error e -> print_s [%message "solver failed" (e : Error.t)]);
  [%expect
    {|
    ("every load accepted" (least 14))
    ("a load refused" (least 13))
    |}]
;;

let host_words ~n seed =
  let rand = Random.State.make [| seed |] in
  List.init n ~f:(fun _ -> Random.State.int rand 0x10000)
;;

let random_entry rand ~k =
  let kinds = Array.of_list Kind.all in
  let table =
    Array.init 256 ~f:(fun _ ->
      let kind =
        if Random.State.int rand 3 = 0
        then Kind.Plain
        else kinds.(Random.State.int rand (Array.length kinds))
      in
      { Entry.outputs = Random.State.int rand 64
      ; kind
      ; next = Random.State.int rand (states ~k)
      ; hold =
          (floor
           +
           if Random.State.int rand 10 = 0
           then Random.State.int rand 200
           else Random.State.int rand 8)
      })
  in
  fun ~d ~state ~inputs -> table.((d lsl 7) lor (state lsl k) lor inputs)
;;

let random_inputs rand ~cycles =
  let levels = Array.create ~len:(cycles + 64) 0 in
  let level = ref 0 in
  Array.iteri levels ~f:(fun c _ ->
    if Random.State.int rand 7 = 0 then level := Random.State.int rand 32;
    levels.(c) <- !level);
  fun c -> levels.(c)
;;

let%expect_test "random tables of every kind: RTL, model and reference agree" =
  let rand = Random.State.make [| 11 |] in
  let tables = 60 in
  let cycles = 2000 in
  let bad = ref 0 in
  let words_moved = ref 0 in
  for n = 1 to tables do
    let k = 1 + (n % 3) in
    let config, program = image ~k in
    let entry = random_entry rand ~k in
    let inputs = random_inputs rand ~cycles in
    let host_words = host_words ~n:400 n in
    let model, pins, pushed =
      run ~data:(words ~k entry) ~cycles ~config ~program ~inputs ~host_words ()
    in
    let expected, expected_pushed = reference ~k ~entry ~inputs ~host_words ~cycles in
    let got = outputs pins in
    words_moved := !words_moved + List.length pushed;
    let differs = Array.findi got ~f:(fun c o -> o <> expected.(c)) in
    let pushed_ok = [%equal: int list] pushed expected_pushed in
    if Option.is_some differs
       || (not pushed_ok)
       || not (Machine.Fault.equal model.fault Machine.Fault.none)
    then (
      incr bad;
      print_s
        [%message
          "differs"
            (n : int)
            (k : int)
            (differs : (int * int) option)
            (pushed : int list)
            (expected_pushed : int list)
            (model.fault : Machine.Fault.t)])
  done;
  print_s
    [%message
      ""
        (tables : int)
        (cycles : int)
        ~differing:(!bad : int)
        ~words_pushed:(!words_moved : int)];
  [%expect {| ((tables 60) (cycles 2000) (differing 0) (words_pushed 545)) |}]
;;

(* every change of the watched pins: cycle, pin, level *)
let edges ~watch pins =
  List.concat_mapi (Array.to_list pins) ~f:(fun c p ->
    let before = if c = 0 then p else pins.(c - 1) in
    List.filter_map watch ~f:(fun pin ->
      let level = (p lsr pin) land 1 in
      if c > 0 && level <> (before lsr pin) land 1 then Some (c, pin, level) else None))
;;

let rev8 b =
  List.init 8 ~f:(fun i -> ((b lsr i) land 1) lsl (7 - i)) |> List.reduce_exn ~f:( lor )
;;

(* a table from states, each a function of the host bit and the inputs *)
let table (states : (d:int -> inputs:int -> Entry.t) list) =
  let states = Array.of_list states in
  fun ~d ~state ~inputs ->
    if state < Array.length states
    then states.(state) ~d ~inputs
    else { Entry.outputs = 0; kind = Plain; next = state; hold = floor }
;;

let const e ~d:_ ~inputs:_ = e

(* the line's frames: from each start edge after an idle high, the edges inside 10 bits *)
let uart_frames ~pin ~period pins =
  let es = edges ~watch:[ pin ] pins in
  let rec frames acc = function
    | [] -> List.rev acc
    | (c, _, 0) :: _ as rest ->
      let inside, after =
        List.split_while rest ~f:(fun (c', _, _) -> c' < c + (10 * period))
      in
      let frame = List.map inside ~f:(fun (c', _, l) -> c' - c, l) in
      let byte =
        List.init 8 ~f:(fun i ->
          let at = c + (period * (i + 1)) + (period / 2) in
          ((pins.(at) lsr pin) land 1) lsl i)
        |> List.reduce_exn ~f:( lor )
      in
      frames ((byte, frame) :: acc) after
    | _ :: rest -> frames acc rest
  in
  frames [] es
;;

let%expect_test "uart tx from host bytes: the table and the native firmware" =
  let period = 32 in
  let bytes = [ 0xa3; 0x00; 0xff; 0x5c ] in
  let cycles = 2000 in
  let k = 1 in
  let _, native, _ =
    run
      ~cycles
      ~config:Program_config.default
      ~program:(Firmware.assemble Firmware.uart_tx_host_rate)
      ~inputs:(Fn.const 0)
      ~host_words:(period :: bytes)
      ()
  in
  let entry =
    table
      ([ const { Entry.outputs = 1; kind = Await_host; next = 1; hold = floor }
       ; const { Entry.outputs = 0; kind = Plain; next = 2; hold = period }
       ]
       @ List.init 8 ~f:(fun i ~d ~inputs:_ ->
         { Entry.outputs = d
         ; kind = Shift
         ; next = 3 + i
         ; hold = period - Kind.extra Shift
         })
       @ [ const { Entry.outputs = 1; kind = Plain; next = 0; hold = period } ])
  in
  let config, program = image ~k in
  let model, pins, _ =
    run
      ~data:(words ~k entry)
      ~cycles
      ~config
      ~program
      ~inputs:(Fn.const 0)
      ~host_words:(List.map bytes ~f:(fun b -> rev8 b lsl 8))
      ()
  in
  let pin = Isa.first_output_pin in
  let native = uart_frames ~pin ~period native in
  let table = uart_frames ~pin ~period pins in
  print_s
    [%message
      ""
        ~native_bytes:(List.map native ~f:fst : int list)
        ~table_bytes:(List.map table ~f:fst : int list)
        ~frames_identical:([%equal: (int * (int * int) list) list] native table : bool)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ((native_bytes (163 0 255 92)) (table_bytes (163 0 255 92))
     (frames_identical true)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "spi master from host bytes, with MISO: the table and the native firmware"
  =
  let half_period = 24 in
  let sent = [ 0xa5; 0x3c; 0x01 ] in
  let slave = [ 0x96; 0xf0; 0x80 ] in
  let cycles = 2500 in
  let k = 1 in
  (* a mode 0 slave: MISO shows the next bit after each falling SCK *)
  let peer () =
    let bits =
      List.concat_map slave ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr (7 - i)) land 1))
      |> Array.of_list
    in
    let index = ref 0 in
    let sck = ref 0 in
    let inputs _ = if !index < Array.length bits then bits.(!index) else 0 in
    let react (m : Machine.t) =
      let s = (m.pin_out lsr Firmware.sck_pin) land 1 in
      if !sck = 1 && s = 0 then incr index;
      sck := s
    in
    inputs, react
  in
  let observe pins =
    (* SCK edges from the first rise of each byte, and MOSI at each rise *)
    let es = edges ~watch:[ Firmware.sck_pin ] pins in
    let rises = List.filter es ~f:(fun (_, _, l) -> l = 1) in
    let mosi =
      List.map rises ~f:(fun (c, _, _) -> (pins.(c) lsr Firmware.mosi_pin) land 1)
    in
    let groups = List.chunks_of rises ~length:8 in
    let spacing =
      List.map groups ~f:(fun g ->
        let c0 = Tuple3.get1 (List.hd_exn g) in
        List.map g ~f:(fun (c, _, _) -> c - c0))
    in
    mosi, spacing
  in
  let with_peer ~config ~program ~data ~host_words =
    let inputs, react = peer () in
    let last = ref None in
    let rest = ref (List.drop host_words 8) in
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
        ~preload:(List.take host_words 8)
        ~data
        ~host
        ~cycles
        ~config
        ~program
        ~inputs
        ~react:(fun m ->
          react m;
          last := Some m;
          Queue.enqueue pins m.pin_out)
        ()
    in
    (match mismatch with
     | None -> ()
     | Some (cycle, _, _) -> raise_s [%message "RTL and model differ" (cycle : int)]);
    model, Queue.to_array pins, Queue.to_list popped @ model.rx_fifo
  in
  let _, native, native_rx =
    with_peer
      ~config:Firmware.spi_config
      ~program:(Firmware.assemble (Firmware.spi_master ~half_period))
      ~data:[]
      ~host_words:sent
  in
  let entry =
    table
      ([ const { Entry.outputs = 0; kind = Await_host; next = 1; hold = floor } ]
       @ List.concat
           (List.init 8 ~f:(fun i ->
              [ (fun ~d ~inputs:_ ->
                  { Entry.outputs = d
                  ; kind = Plain
                  ; next = 2 + (2 * i)
                  ; hold = half_period
                  })
              ; (fun ~d ~inputs:_ ->
                  { Entry.outputs = d lor 0b10
                  ; kind = Shift
                  ; next = (if i = 7 then 17 else 3 + (2 * i))
                  ; hold = half_period - Kind.extra Shift
                  })
              ]))
       @ [ const { Entry.outputs = 0; kind = Push; next = 0; hold = floor } ])
  in
  let config, program = image ~k in
  let model, pins, table_rx =
    with_peer
      ~config
      ~program
      ~data:(words ~k entry)
      ~host_words:(List.map sent ~f:(fun b -> b lsl 8))
  in
  let native_mosi, native_spacing = observe native in
  let table_mosi, table_spacing = observe pins in
  print_s
    [%message
      ""
        ~mosi_at_rises_identical:([%equal: int list] native_mosi table_mosi : bool)
        ~sck_spacing_identical:
          ([%equal: int list list] native_spacing table_spacing : bool)
        (table_spacing : int list list)
        ~native_rx:(List.map native_rx ~f:(fun w -> w land 0xff) : int list)
        ~table_rx:(List.map table_rx ~f:(fun w -> w land 0xff) : int list)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ((mosi_at_rises_identical true) (sck_spacing_identical true)
     (table_spacing
      ((0 48 96 144 192 240 288 336) (0 48 96 144 192 240 288 336)
       (0 48 96 144 192 240 288 336)))
     (native_rx (150 240 128)) (table_rx (150 240 128))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

(* A line of frames, each after a random idle of [min_gap] to 2 bits. *)
let uart_line ?(min_gap = 0) ~period ~bytes rand =
  let bits =
    List.concat_map bytes ~f:(fun b ->
      List.init (min_gap + Random.State.int rand (3 - min_gap)) ~f:(fun _ -> 1)
      @ [ 0 ]
      @ List.init 8 ~f:(fun i -> (b lsr i) land 1)
      @ [ 1 ])
  in
  let lead = 200 in
  let line = Array.of_list bits in
  fun c ->
    if c < lead
    then 1
    else (
      let i = (c - lead) / period in
      if i < Array.length line then line.(i) else 1)
;;

let%expect_test "uart rx by re-anchoring on the start edge: the table and the native" =
  let period = 80 in
  List.iter
    [ 80, 0; 77, 0; 83, 0; 77, 1 ]
    ~f:(fun (sender, min_gap) ->
      let rand = Random.State.make [| 3 |] in
      let bytes = List.init 12 ~f:(fun _ -> Random.State.int rand 256) in
      let inputs = uart_line ~min_gap ~period:sender ~bytes rand in
      let cycles = 200 + (12 * 12 * period) + 400 in
      let k = 1 in
      (* the library's receiver with its two constants from the host, as [set] stops at 31 *)
      let native_source =
        String.substr_replace_first
          (Firmware.uart_rx ~period)
          ~pattern:[%string "set p, %{period#Int}\n    set y, %{(period / 2) - 1#Int}"]
          ~with_:
            "wait tx\n    pull\n    mov p, osr\n    wait tx\n    pull\n    mov y, osr"
      in
      let _, _, native_rx =
        run
          ~cycles
          ~config:Firmware.rx_config
          ~program:(Firmware.assemble native_source)
          ~inputs
          ~host_words:[ period; (period / 2) - 1 ]
          ()
      in
      let entry =
        table
          ([ const
               { Entry.outputs = 0
               ; kind = Await_low
               ; next = 1
               ; hold = (3 * period / 2) - 8
               }
           ]
           @ List.init 8 ~f:(fun i ->
             const
               { Entry.outputs = 0
               ; kind = Shift
               ; next = 2 + i
               ; hold = period - Kind.extra Shift
               })
           @ [ const { Entry.outputs = 0; kind = Push; next = 0; hold = floor } ])
      in
      let config, program = image ~k in
      let model, _, table_rx =
        run ~data:(words ~k entry) ~cycles ~config ~program ~inputs ~host_words:[] ()
      in
      print_s
        [%message
          ""
            (sender : int)
            (min_gap : int)
            (bytes : int list)
            ~native:(List.map native_rx ~f:(fun w -> w land 0xff) : int list)
            ~table:(List.map table_rx ~f:(fun w -> rev8 (w land 0xff)) : int list)
            (model.fault : Machine.Fault.t)]);
  [%expect
    {|
    ((sender 80) (min_gap 0) (bytes (51 48 221 112 94 153 208 75 50 135 133 127))
     (native (51 48 221 112 94 153 208 75 50 135 133 127))
     (table (51 48 221 112 94 153 208 75 50 135 133 127))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((sender 77) (min_gap 0) (bytes (51 48 221 112 94 153 208 75 50 135 133 127))
     (native (51 48 221 112 94 153 208 75 50 135 133 127))
     (table (51 48 221 184 175 153 208 163 50 135 133 191))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((sender 83) (min_gap 0) (bytes (51 48 221 112 94 153 208 75 50 135 133 127))
     (native (51 48 221 112 94 153 208 75 50 135 133 127))
     (table (51 48 221 112 94 153 208 75 50 135 133 127))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    ((sender 77) (min_gap 1) (bytes (51 48 221 112 94 153 208 75 50 135 133 127))
     (native (51 48 221 112 94 153 208 75 50 135 133 127))
     (table (51 48 221 112 94 153 208 75 50 135 133 127))
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "dshot600 from host frames: the table and the library firmware" =
  let frames = [ Dshot.frame ~throttle:1046 ~telemetry:false; 0xffff; 0x0001 ] in
  let cycles = 6000 in
  let k = 1 in
  let _, native, _ =
    run
      ~cycles
      ~config:Dshot.config
      ~program:(Firmware.assemble Dshot.dshot600)
      ~inputs:(Fn.const 0)
      ~host_words:frames
      ()
  in
  (* a bit is three states: rise, the bit, fall; the bit's state consumes it *)
  let rise i = 1 + (3 * i) in
  let entry =
    table
      ([ const { Entry.outputs = 0; kind = Await_host; next = rise 0; hold = floor } ]
       @ List.concat
           (List.init 16 ~f:(fun i ->
              [ const { Entry.outputs = 1; kind = Plain; next = rise i + 1; hold = 31 }
              ; (fun ~d ~inputs:_ ->
                  { Entry.outputs = d
                  ; kind = Shift
                  ; next = rise i + 2
                  ; hold = 31 - Kind.extra Shift
                  })
              ; const
                  { Entry.outputs = 0
                  ; kind = Plain
                  ; next = (if i = 15 then 49 else rise (i + 1))
                  ; hold = 83 - 62
                  }
              ]))
       @ [ const { Entry.outputs = 0; kind = Plain; next = 0; hold = 8 * 31 } ])
  in
  let config, program = image ~k in
  let model, pins, _ =
    run
      ~data:(words ~k entry)
      ~cycles
      ~config
      ~program
      ~inputs:(Fn.const 0)
      ~host_words:frames
      ()
  in
  (* each frame's edges from its first rise *)
  let per_frame pins =
    edges ~watch:[ Dshot.pin ] pins
    |> List.group ~break:(fun (a, _, _) (b, _, _) -> b - a > 200)
    |> List.map ~f:(fun es ->
      let c0 = Tuple3.get1 (List.hd_exn es) in
      List.map es ~f:(fun (c, _, l) -> c - c0, l))
  in
  let native = per_frame native in
  let table = per_frame pins in
  print_s
    [%message
      ""
        ~frames:(List.length table : int)
        ~edges_a_frame:(List.map table ~f:List.length : int list)
        ~identical:([%equal: (int * int) list list] native table : bool)
        (model.fault : Machine.Fault.t)];
  [%expect
    {|
    ((frames 3) (edges_a_frame (32 32 32)) (identical true)
     (model.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;
