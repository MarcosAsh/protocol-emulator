open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val engines : int
end

module Make (Config : Config) = struct
  let engines = Config.engines
  let owner_bits = Int.max 1 (Int.ceil_log2 engines)

  let () =
    if engines < 1
    then raise_s [%message "BUG: there has to be an engine" (engines : int)]
  ;;

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; hosts : 'a Engine.Host.t list [@length engines]
      ; pads : 'a [@bits Isa.num_pins]
      ; check_setup : 'a Load_checker.Setup.t
      ; start_all : 'a
      ; rd : 'a [@bits 2]
      ; dm : 'a [@bits 2]
      ; frame : 'a Frame_rx.Control.t
      ; frame_usb : 'a
      ; frame_owner : 'a [@bits owner_bits]
      ; stamps : 'a Edge_stamps.Control.t
      }
    [@@deriving hardcaml]
  end

  module Check = struct
    type 'a t =
      { verdicts : 'a Load_checker.Verdict.t list [@length engines]
      ; certified : 'a list [@length engines]
      ; refused : 'a list [@length engines]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { engines : 'a Engine.O.t list [@length engines]
      ; pin_out : 'a [@bits Isa.num_pins]
      ; pin_dir : 'a [@bits Isa.num_pins]
      ; check : 'a Check.t
      ; frame : 'a Frame_rx.Status.t
      ; usb : 'a Usb_frame_rx.Status.t
      ; stamps : 'a Edge_stamps.O.t
      }
    [@@deriving hardcaml]
  end

  module Data_memory = Data_memory.Make (Config)

  let turn_bits = 16
  let turn_cycles = 1 lsl turn_bits
  let any (outs : Signal.t Engine.O.t list) ~f = List.map outs ~f |> reduce ~f:( |: )

  (* what an engine drives: nothing once it has faulted, as at reset, until the clear *)
  let driving (e : Signal.t Engine.O.t) ~faulted =
    let keep s = mux2 faulted (zero (width s)) s in
    { e with pin_out = keep e.pin_out; pin_dir = keep e.pin_dir }
  ;;

  (* The pads, except bidirectional pins another engine drives, on wires what the others
     drive, and [status] on the status pins. An engine reads its own outputs back itself.
     Only a bidirectional pin has a direction bit. *)
  let seen ~pads ~status ~(others : Signal.t Engine.O.t list) =
    let pads = concat_msb [ status; zero Isa.num_wires; pads ] in
    match others with
    | [] -> pads
    | others ->
      let wires =
        concat_msb [ zero Isa.num_status_pins; ones Isa.num_wires; zero Isa.num_pins ]
      in
      let driven = any others ~f:(fun e -> e.pin_dir) in
      let level = any others ~f:(fun e -> e.pin_out &: (e.pin_dir |: wires)) in
      pads &: ~:driven |: level
  ;;

  let create ~gated ~memory (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let outs = List.init engines ~f:(fun _ -> Engine.O.Of_signal.wires ()) in
    let select_bits = Int.max 1 (Int.ceil_log2 engines) in
    (* One checker serves every engine, a halted one at a time: it reads that engine's
       program memory and takes its turn at the data memory. With more than one engine the
       checker goes to each in turn for [turn_cycles], whoever asks: a check waits for its
       engine's turn and a walk still going at the turn's end is aborted, so when an
       engine's check begins and ends never depends on another's. *)
    let checker = Load_checker.O.Of_signal.wires () in
    let%hw checked = wire select_bits in
    let%hw checking = checker.busy in
    let mine n = checking &: (checked ==:. n) in
    let%hw turn_cycle = reg_fb spec ~width:turn_bits ~f:(fun c -> c +:. 1) in
    let%hw turn_ends = if engines = 1 then gnd else turn_cycle ==: ones turn_bits in
    let%hw chosen =
      reg_fb spec ~enable:turn_ends ~width:select_bits ~f:(fun owner ->
        mux2 (owner ==:. engines - 1) (zero select_bits) (owner +:. 1))
    in
    let%hw turn_starts = if engines = 1 then ~:checking else turn_cycle ==:. 0 in
    (* a check asked between its engine's turns waits for the next, while it stays halted *)
    let%hw_list waiting = List.init engines ~f:(fun _ -> wire 1) in
    let%hw_list asks =
      List.map3_exn i.hosts outs waiting ~f:(fun (h : _ Engine.Host.t) e waiting ->
        h.check |: waiting &: e.halted)
    in
    let%hw go = turn_starts &: mux chosen asks in
    let checks_begin n = go &: (chosen ==:. n) in
    List.iteri (List.zip_exn waiting asks) ~f:(fun n (waiting, ask) ->
      waiting <-- reg spec (ask &: ~:(checks_begin n)));
    checked <-- reg spec ~enable:go chosen;
    let pick values = mux checked values in
    let%hw accepts = checker.finished &: checker.accepted in
    (* a start counts only for a program the checker accepted, under the configuration it
       was checked with *)
    let%hw_list certified =
      List.mapi i.hosts ~f:(fun n (h : _ Engine.Host.t) ->
        reg_fb spec ~width:1 ~f:(fun certified ->
          mux2
            (h.program_write.valid
             |: h.config_written
             |: h.line_write.valid
             |: checks_begin n)
            gnd
            (mux2 (accepts &: (checked ==:. n)) vdd certified)))
    in
    (* what the engine's certificate was checked under, which the core then watches *)
    let premises =
      List.init engines ~f:(fun n ->
        let s = i.check_setup in
        Engine.Premises.Of_signal.reg
          spec
          ~enable:(checks_begin n)
          { period = s.loaded; floor = s.floor; single_edge = s.single_edge })
    in
    (* A start of every engine on the same cycle, so their programs' phases are fixed to
       each other: only with all halted and none faulted, and on the gated chip all
       certified, or none. *)
    let%hw_list faulted = List.map outs ~f:(fun e -> e.faulted) in
    let%hw all_ready =
      List.map3_exn outs certified faulted ~f:(fun e certified faulted ->
        (if gated then e.halted &: certified else e.halted) &: ~:faulted)
      |> List.reduce_exn ~f:( &: )
    in
    let%hw starts_all = i.start_all &: all_ready in
    let%hw_list refused =
      List.mapi
        (List.zip_exn i.hosts certified)
        ~f:(fun n ((h : _ Engine.Host.t), certified) ->
          reg_fb spec ~width:1 ~f:(fun refused ->
            mux2
              (checks_begin n)
              gnd
              (mux2 (h.start |: i.start_all &: ~:certified) vdd refused)))
    in
    let starts =
      List.map2_exn i.hosts certified ~f:(fun (h : _ Engine.Host.t) certified ->
        (if gated then h.start &: certified else h.start) |: starts_all)
    in
    (* The checker borrows engine [n]'s program port and data turn only while [n] is free,
       so a running or starting core never sees it. *)
    let%hw_list lent = List.mapi outs ~f:(fun n e -> mine n &: e.free) in
    let%hw frame_writes = wire 1 in
    (* what the walk reads, written under it, or its engine leaving halted *)
    let%hw abort =
      checking
      &: (List.map i.hosts ~f:(fun h -> h.data_write.valid)
          |> List.reduce_exn ~f:( |: )
          |: frame_writes
          |: pick
               (List.map i.hosts ~f:(fun h ->
                  h.program_write.valid |: h.config_written |: h.line_write.valid))
          |: pick (List.map lent ~f:( ~: ))
          |: turn_ends)
    in
    (* A received frame takes the data memory's port only in its owner's turn, and only
       where no read the owner needs is lost: no host write, and the owner halted and not
       starting, not pulling from data, or keeping its word. A halted engine's word is
       refetched from its start on, and a walk the write lands under is aborted. So when
       words land, and so when the owner's status pins move, never depends on another
       engine. *)
    let%hw host_writes =
      List.map outs ~f:(fun e -> e.halted)
      @ [ List.map i.hosts ~f:(fun h -> h.data_write.valid) |> List.reduce_exn ~f:( |: ) ]
      |> List.reduce_exn ~f:( &: )
    in
    let data_turn = Data_memory.O.Of_signal.wires () in
    let%hw_list turn_spared =
      List.map3_exn outs i.hosts data_turn.keeps ~f:(fun e (h : _ Engine.Host.t) keeps ->
        e.free |: ~:(h.config.autopull_data) |: keeps)
    in
    let owns n = if engines = 1 then vdd else i.frame_owner ==:. n in
    let%hw owners_turn =
      if engines = 1 then vdd else data_turn.whose_turn ==: i.frame_owner
    in
    let%hw frame_may_write =
      ~:host_writes &: owners_turn &: mux i.frame_owner turn_spared
    in
    (* one receiver at a time, armed and on the data memory's port *)
    let frame =
      Frame_rx.hierarchical
        scope
        { clocking = i.clocking
        ; rd = i.rd
        ; control = { i.frame with arm = i.frame.arm &: ~:(i.frame_usb) }
        ; may_write = frame_may_write
        }
    in
    let usb =
      Usb_frame_rx.hierarchical
        scope
        { clocking = i.clocking
        ; dp = i.rd
        ; dm = i.dm
        ; control = { arm = i.frame.arm &: i.frame_usb; base = i.frame.base }
        ; may_write = frame_may_write
        }
    in
    let dma_write =
      Engine.Program_write.Of_signal.mux2 i.frame_usb usb.write frame.write
    in
    frame_writes <-- dma_write.valid;
    let dma_write = { dma_write with valid = frame_writes } in
    (* finished, good, receiving and error, for the owner alone *)
    let%hw frame_status =
      let f = frame.status in
      let u = usb.status in
      mux2
        i.frame_usb
        (concat_msb
           [ u.dropped |: u.stuff_error
           ; u.receiving
           ; u.crc5_ok |: u.crc16_ok
           ; u.finished
           ])
        (concat_msb [ f.dropped; f.receiving; f.fcs_ok; f.finished ])
    in
    let stamps =
      Edge_stamps.hierarchical
        scope
        { clocking = i.clocking
        ; pads = i.pads
        ; now =
            (match outs with
             | [ e ] -> e.now
             | outs -> mux i.stamps.engine (List.map outs ~f:(fun e -> e.now)))
        ; control = i.stamps
        }
    in
    let data =
      Data_memory.hierarchical
        ~memory
        scope
        { clocking = i.clocking
        ; halted = List.map outs ~f:(fun e -> e.halted)
        ; writes = List.map i.hosts ~f:(fun h -> h.data_write)
        ; reads =
            List.map2_exn outs lent ~f:(fun e lent ->
              mux2 (lent &: checker.data_read.valid) checker.data_read.value e.data_addr)
        ; dma = dma_write
        }
    in
    Data_memory.O.Of_signal.assign data_turn data;
    Load_checker.hierarchical
      scope
      { clocking = i.clocking
      ; check = go
      ; abort
      ; config =
          Engine.Config.Of_signal.mux checked (List.map i.hosts ~f:(fun h -> h.config))
      ; setup = i.check_setup
      ; program_word = pick (List.map outs ~f:(fun e -> e.program_word))
      ; data_word = pick data.words
      }
    |> Load_checker.O.Of_signal.assign checker;
    (* Engine n's pushes, routed, go to engine n + 1's tx fifo in place of its host's. The
       full flag is the registered level's, so it holds through a pop that cycle. *)
    let next n = (n + 1) % engines in
    let feeder n = (n + engines - 1) % engines in
    let%hw_list route_full =
      List.init engines ~f:(fun n ->
        (List.nth_exn outs (next n)).tx_level ==:. Machine.fifo_depth)
    in
    let drives = List.map2_exn outs faulted ~f:(fun e faulted -> driving e ~faulted) in
    List.iteri
      (List.zip_exn (List.zip_exn i.hosts outs) data.words)
      ~f:(fun n (((host : _ Engine.Host.t), out), data_word) ->
        let faulted = List.nth_exn faulted n in
        let others = List.filteri drives ~f:(fun m _ -> m <> n) in
        let feeder_routes = (List.nth_exn i.hosts (feeder n)).config.route in
        (* a faulted engine halts, and no start runs it again before the clear *)
        Engine.hierarchical
          ~instance:[%string "engine_%{n#Int}"]
          ~memory
          scope
          { clocking = i.clocking
          ; config = host.config
          ; start = List.nth_exn starts n &: ~:faulted
          ; program_write = host.program_write
          ; program_read =
              { valid = List.nth_exn lent n &: checker.program_read.valid
              ; value = checker.program_read.value
              }
          ; data_word
          ; tx =
              (let pushed = (List.nth_exn outs (feeder n)).push in
               { valid = mux2 feeder_routes pushed.valid host.tx.valid
               ; value = mux2 feeder_routes pushed.value host.tx.value
               })
          ; rx_pop = host.rx_pop
          ; clear_irq = host.clear_irq
          ; stop = host.stop |: faulted
          ; flush = host.flush
          ; inputs =
              seen
                ~pads:i.pads
                ~status:(mux2 (owns n) frame_status (zero Isa.num_status_pins))
                ~others
          ; line_write = host.line_write
          ; premises = List.nth_exn premises n
          ; route_full = List.nth_exn route_full n
          }
        |> Engine.O.Of_signal.assign out);
    let pin_out =
      match drives with
      | [ engine ] -> engine.pin_out
      | drives ->
        let output_only =
          concat_msb
            [ zero (Isa.pin_space - Isa.first_bidir_pin); ones Isa.first_bidir_pin ]
        in
        any drives ~f:(fun e -> e.pin_out &: (e.pin_dir |: output_only))
    in
    { O.engines = outs
    ; pin_out = sel_bottom pin_out ~width:Isa.num_pins
    ; pin_dir = sel_bottom (any drives ~f:(fun e -> e.pin_dir)) ~width:Isa.num_pins
    ; check =
        { verdicts =
            (* each engine's last, kept while the checker serves the others, and busy from
               its ask until it is kept *)
            List.mapi waiting ~f:(fun n waiting ->
              let ends = checker.finished &: (checked ==:. n) in
              let keep = reg spec ~enable:ends in
              { Load_checker.Verdict.busy = waiting |: mine n |: ends
              ; accepted = keep checker.accepted
              ; reject_pc = keep checker.reject_pc
              ; reason = keep checker.reason
              }
              |> Load_checker.Verdict.Of_signal.apply_names
                   ~prefix:[%string "verdict$%{n#Int}$"]
                   ~naming_op:(Scope.naming scope))
        ; certified
        ; refused
        }
    ; frame = frame.status
    ; usb = usb.status
    ; stamps
    }
  ;;

  let hierarchical ?instance ?(gated = true) ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"engines" (create ~gated ~memory) i
  ;;
end
