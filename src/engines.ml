open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val engines : int
  val journal : bool
end

module Make (Config : Config) = struct
  let engines = Config.engines
  let journals = Bool.to_int Config.journal

  let () =
    if engines < 1
    then raise_s [%message "BUG: there has to be an engine" (engines : int)]
  ;;

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; hosts : 'a Engine.Host.t list [@length engines]
      ; pads : 'a [@bits Isa.num_pins]
      ; journal : 'a Journal.Arm.t list [@length journals]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { engines : 'a Engine.O.t list [@length engines]
      ; pin_out : 'a [@bits Isa.num_pins]
      ; pin_dir : 'a [@bits Isa.num_pins]
      ; journal_write : 'a Engine.Program_write.t list [@length journals]
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

  let create ~memory (scope : Scope.t) (i : Signal.t I.t) =
    let outs = List.init engines ~f:(fun _ -> Engine.O.Of_signal.wires ()) in
    let journal_writes =
      List.map i.journal ~f:(fun _ -> Engine.Program_write.Of_signal.wires ())
    in
    let data =
      Data_memory.hierarchical
        ~memory
        scope
        { clocking = i.clocking
        ; halted = List.map outs ~f:(fun e -> e.halted)
        ; writes = List.map i.hosts ~f:(fun h -> h.data_write)
        ; reads = List.map outs ~f:(fun e -> e.data_addr)
        ; journal = journal_writes
        }
    in
    List.iter2_exn
      (List.zip_exn i.journal data.journal_slot)
      journal_writes
      ~f:(fun (arm, slot) write ->
        let host ~f = List.map i.hosts ~f |> reduce ~f:( |: ) in
        let%hw journal_command =
          mux2
            (host ~f:(fun h -> h.start |: h.stop |: h.flush |: h.clear_irq))
            (of_unsigned_int ~width:2 (Journal.Code.to_int Control))
          @@ mux2
               (host ~f:(fun h -> h.tx.valid))
               (of_unsigned_int ~width:2 (Journal.Code.to_int Tx))
          @@ mux2
               (host ~f:(fun h -> h.rx_pop))
               (of_unsigned_int ~width:2 (Journal.Code.to_int Rx_pop))
          @@ zero 2
        in
        (* a data autopull on engine 1 keeps its turns, and the journal waits *)
        let pulls_data = (List.nth_exn i.hosts 1).config.autopull_data in
        let journal =
          Journal.hierarchical
            scope
            { clocking = i.clocking
            ; arm
            ; pads =
                concat_msb
                  [ drop_bottom i.pads ~width:Isa.first_bidir_pin
                  ; sel_bottom i.pads ~width:Isa.first_output_pin
                  ]
            ; command = journal_command
            ; fault =
                any outs ~f:(fun e -> Engine.Fault.to_list e.fault |> reduce ~f:( |: ))
            ; slot = slot &: ~:pulls_data
            }
        in
        Engine.Program_write.Of_signal.assign write journal.write);
    List.iteri
      (List.zip_exn (List.zip_exn i.hosts outs) data.words)
      ~f:(fun n (((host : _ Engine.Host.t), out), data_word) ->
        let others = List.filteri outs ~f:(fun m _ -> m <> n) in
        Engine.hierarchical
          ~instance:[%string "engine_%{n#Int}"]
          ~memory
          scope
          { clocking = i.clocking
          ; config = host.config
          ; start = host.start
          ; program_write = host.program_write
          ; data_word
          ; tx = host.tx
          ; rx_pop = host.rx_pop
          ; clear_irq = host.clear_irq
          ; stop = host.stop
          ; flush = host.flush
          ; inputs = seen ~pads:i.pads ~others
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
    ; journal_write = journal_writes
    }
  ;;

  let hierarchical ?instance ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"engines" (create ~memory) i
  ;;
end
