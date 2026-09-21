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
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { engines : 'a Engine.O.t list [@length engines]
      ; pin_out : 'a [@bits Isa.num_pins]
      ; pin_dir : 'a [@bits Isa.num_pins]
      }
    [@@deriving hardcaml]
  end

  let any (outs : Signal.t Engine.O.t list) ~f = List.map outs ~f |> reduce ~f:( |: )

  (* What an engine finds on the pins besides itself: the pads, except where another
     engine drives a bidirectional pin, and on the wires what the other engines drive. Its
     own outputs it reads back by itself. Only a bidirectional pin has a direction bit to
     set. *)
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
    List.iteri (List.zip_exn i.hosts outs) ~f:(fun n ((host : _ Engine.Host.t), out) ->
      let others = List.filteri outs ~f:(fun m _ -> m <> n) in
      Engine.hierarchical
        ~instance:[%string "engine_%{n#Int}"]
        ~memory
        scope
        { clocking = i.clocking
        ; config = host.config
        ; start = host.start
        ; program_write = host.program_write
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
    }
  ;;

  let hierarchical ?instance ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"engines" (create ~memory) i
  ;;
end
