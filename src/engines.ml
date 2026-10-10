open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val engines : int
end

module Make (Config : Config) = struct
  let engines = Config.engines

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
      }
    [@@deriving hardcaml]
  end

  module Check = struct
    type 'a t =
      { verdict : 'a Load_checker.Verdict.t
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
      }
    [@@deriving hardcaml]
  end

  module Data_memory = Data_memory.Make (Config)

  let any (outs : Signal.t Engine.O.t list) ~f = List.map outs ~f |> reduce ~f:( |: )

  (* The pads, except bidirectional pins another engine drives, and on wires what the
     others drive. An engine reads its own outputs back itself. Only a bidirectional pin
     has a direction bit. *)
  let seen ~pads ~(others : Signal.t Engine.O.t list) =
    let pads = uresize pads ~width:Isa.pin_space in
    match others with
    | [] -> pads
    | others ->
      let wires = concat_msb [ ones Isa.num_wires; zero Isa.num_pins ] in
      let driven = any others ~f:(fun e -> e.pin_dir) in
      let level = any others ~f:(fun e -> e.pin_out &: (e.pin_dir |: wires)) in
      pads &: ~:driven |: level
  ;;

  let create ~gated ~memory (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let outs = List.init engines ~f:(fun _ -> Engine.O.Of_signal.wires ()) in
    let select_bits = Int.max 1 (Int.ceil_log2 engines) in
    (* One checker serves every engine, a halted one at a time: it reads that engine's
       program memory and takes its turn at the data memory. *)
    let checker = Load_checker.O.Of_signal.wires () in
    let%hw checked = wire select_bits in
    let%hw checking = checker.busy in
    let mine n = checking &: (checked ==:. n) in
    let%hw_list asks =
      List.map2_exn i.hosts outs ~f:(fun (h : _ Engine.Host.t) e -> h.check &: e.halted)
    in
    let%hw go = ~:checking &: List.reduce_exn asks ~f:( |: ) in
    let%hw chosen =
      priority_select_with_default
        (List.mapi asks ~f:(fun n ask ->
           { With_valid.valid = ask; value = of_unsigned_int ~width:select_bits n }))
        ~default:(zero select_bits)
    in
    checked <-- reg spec ~enable:go chosen;
    let pick values = mux checked values in
    let%hw accepts = checker.finished &: checker.accepted in
    (* a start counts only for a program the checker accepted, under the configuration it
       was checked with *)
    let checks_begin n = go &: (chosen ==:. n) in
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
       each other: only with all halted, and on the gated chip all certified, or none. *)
    let%hw all_ready =
      List.map2_exn outs certified ~f:(fun e certified ->
        if gated then e.halted &: certified else e.halted)
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
    (* what the walk reads, written under it, or its engine leaving halted *)
    let%hw abort =
      checking
      &: (List.map i.hosts ~f:(fun h -> h.data_write.valid)
          |> List.reduce_exn ~f:( |: )
          |: pick
               (List.map i.hosts ~f:(fun h ->
                  h.program_write.valid |: h.config_written |: h.line_write.valid))
          |: pick (List.map lent ~f:( ~: )))
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
        }
    in
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
    List.iteri
      (List.zip_exn (List.zip_exn i.hosts outs) data.words)
      ~f:(fun n (((host : _ Engine.Host.t), out), data_word) ->
        let others = List.filteri outs ~f:(fun m _ -> m <> n) in
        let feeder_routes = (List.nth_exn i.hosts (feeder n)).config.route in
        Engine.hierarchical
          ~instance:[%string "engine_%{n#Int}"]
          ~memory
          scope
          { clocking = i.clocking
          ; config = host.config
          ; start = List.nth_exn starts n
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
          ; stop = host.stop
          ; flush = host.flush
          ; inputs = seen ~pads:i.pads ~others
          ; line_write = host.line_write
          ; premises = List.nth_exn premises n
          ; route_full = List.nth_exn route_full n
          }
        |> Engine.O.Of_signal.assign out);
    let pin_out =
      match outs with
      (* with one engine the pad's output enable does this, and the chip stays as it was *)
      | [ engine ] -> engine.pin_out
      | outs ->
        let output_only =
          concat_msb
            [ zero (Isa.pin_space - Isa.first_bidir_pin); ones Isa.first_bidir_pin ]
        in
        any outs ~f:(fun e -> e.pin_out &: (e.pin_dir |: output_only))
    in
    { O.engines = outs
    ; pin_out = sel_bottom pin_out ~width:Isa.num_pins
    ; pin_dir = sel_bottom (any outs ~f:(fun e -> e.pin_dir)) ~width:Isa.num_pins
    ; check =
        { verdict =
            { busy = checking
            ; accepted = checker.accepted
            ; reject_pc = checker.reject_pc
            ; reason = checker.reason
            }
        ; certified
        ; refused
        }
    }
  ;;

  let hierarchical ?instance ?(gated = true) ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"engines" (create ~gated ~memory) i
  ;;
end
