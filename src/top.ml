open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

(* What an engine finds on the pins besides itself: the pads, except where another engine
   drives a bidirectional pin. Its own outputs it reads back by itself. *)
let seen ~pads ~(others : Signal.t Engine.O.t list) =
  match others with
  | [] -> pads
  | others ->
    let any f = List.map others ~f |> reduce ~f:( |: ) in
    let bidir =
      concat_msb [ ones (Isa.num_pins - Isa.first_bidir_pin); zero Isa.first_bidir_pin ]
    in
    let driven = any (fun e -> e.pin_dir) &: bidir in
    let level = any (fun e -> e.pin_out &: e.pin_dir) in
    pads &: ~:driven |: (level &: driven)
;;

let create ~memory ~engines (scope : Scope.t) (i : Signal.t I.t) =
  if engines < 1 then raise_s [%message "BUG: the top needs an engine" (engines : int)];
  let async = Reg_spec.create ~clock:i.clk ~reset:~:(i.rst_n) () in
  let%hw reset_done = pipeline async ~n:2 vdd in
  let clocking = { Clocking.clock = i.clk; clear = ~:reset_done } in
  let sync x = Clocking.pipeline clocking ~n:2 x in
  let%hw inputs = concat_msb [ sync i.uio_in; zero 7; sync i.ui_in.:[7, 3] ] in
  let engine_outs = List.init engines ~f:(fun _ -> Engine.O.Of_signal.wires ()) in
  (* the host talks to the first engine *)
  let engine_out = List.hd_exn engine_outs in
  let host =
    Host_port.hierarchical
      scope
      { clocking
      ; sck = i.ui_in.:(0)
      ; mosi = i.ui_in.:(1)
      ; cs_n = i.ui_in.:(2)
      ; status =
          { pc = engine_out.pc
          ; now = engine_out.now
          ; capture = engine_out.capture
          ; halted = engine_out.halted
          ; irq = engine_out.irq
          ; fault = engine_out.fault
          ; tx_level = engine_out.tx_level
          ; rx_level = engine_out.rx_level
          ; rx_head = engine_out.rx_head
          }
      }
  in
  List.iteri engine_outs ~f:(fun n out ->
    let mine x = if n = 0 then x else zero (width x) in
    let others = List.filteri engine_outs ~f:(fun m _ -> m <> n) in
    Engine.hierarchical
      ~instance:[%string "engine_%{n#Int}"]
      ~memory
      scope
      { clocking
      ; config = host.config
      ; start = mine host.start
      ; program_write = Engine.Program_write.map host.program_write ~f:mine
      ; tx = With_valid.map host.tx ~f:mine
      ; rx_pop = mine host.rx_pop
      ; clear_irq = mine host.clear_irq
      ; stop = mine host.stop
      ; flush = mine host.flush
      ; inputs = seen ~pads:inputs ~others
      }
    |> Engine.O.Of_signal.assign out);
  let any f = List.map engine_outs ~f |> reduce ~f:( |: ) in
  let uio_out =
    match engine_outs with
    (* with one engine the pad's output enable does this, and the chip stays as it was *)
    | [ engine ] -> engine.pin_out
    | _ -> any (fun e -> e.pin_out &: e.pin_dir)
  in
  { O.uo_out = (any (fun e -> e.pin_out)).:[11, 5] @: host.miso
  ; uio_out = uio_out.:[19, 12]
  ; uio_oe = (any (fun e -> e.pin_dir)).:[19, 12]
  }
;;

let hierarchical ?instance ~memory ~engines scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"top" (create ~memory ~engines) i
;;
