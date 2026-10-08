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
  let faulted (e : Signal.t Engine.O.t) = Engine.Fault.to_list e.fault |> reduce ~f:( |: )

  (* what an engine drives: nothing once it has faulted, as at reset, until the clear *)
  let driving (e : Signal.t Engine.O.t) ~faulted =
    let keep s = mux2 faulted (zero (width s)) s in
    { e with pin_out = keep e.pin_out; pin_dir = keep e.pin_dir }
  ;;

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
            (h.program_write.valid |: h.config_written |: checks_begin n)
            gnd
            (mux2 (accepts &: (checked ==:. n)) vdd certified)))
    in
    let%hw_list refused =
      List.mapi
        (List.zip_exn i.hosts certified)
        ~f:(fun n ((h : _ Engine.Host.t), certified) ->
          reg_fb spec ~width:1 ~f:(fun refused ->
            mux2 (checks_begin n) gnd (mux2 (h.start &: ~:certified) vdd refused)))
    in
    let starts =
      List.map2_exn i.hosts certified ~f:(fun (h : _ Engine.Host.t) certified ->
        if gated then h.start &: certified else h.start)
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
               (List.map i.hosts ~f:(fun h -> h.program_write.valid |: h.config_written))
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
    let%hw_list faulted = List.map outs ~f:faulted in
    let drives = List.map2_exn outs faulted ~f:(fun e faulted -> driving e ~faulted) in
    List.iteri
      (List.zip_exn (List.zip_exn i.hosts outs) data.words)
      ~f:(fun n (((host : _ Engine.Host.t), out), data_word) ->
        let faulted = List.nth_exn faulted n in
        let others = List.filteri drives ~f:(fun m _ -> m <> n) in
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
          ; tx = host.tx
          ; rx_pop = host.rx_pop
          ; clear_irq = host.clear_irq
          ; stop = host.stop |: faulted
          ; flush = host.flush
          ; inputs = seen ~pads:i.pads ~others
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
