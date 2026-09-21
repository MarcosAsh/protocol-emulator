open! Core
open! Hardcaml
open! Hardcaml_test_harness
open Protocol_emulator

let ( <--. ) = Bits.( <--. )

module Setup = struct
  type t =
    { config : Program_config.t
    ; program : int list
    ; preload : int list
    }
end

module Mismatch = struct
  type t =
    | Engine of
        { cycle : int
        ; engine : int
        ; expected : Lockstep.State.t
        ; actual : Lockstep.State.t
        }
    | Pins of
        { cycle : int
        ; expected : int * int
        ; actual : int * int
        }
  [@@deriving sexp_of]
end

let run
  ?(cycles = 400)
  ?host
  ?(react = fun (_ : System.t) -> ())
  ~pads
  (setups : Setup.t list)
  =
  let module Dut =
    Engines.Make (struct
      let engines = List.length setups
    end)
  in
  let module Harness = Lws_harness.Make (Dut.I) (Dut.O) in
  let host =
    Option.value host ~default:(fun _ -> List.map setups ~f:(fun _ -> Lockstep.Host.idle))
  in
  Harness.run
    ~random_initial_state:`All
    ~create:(Dut.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Hardcaml_lws.Lws.cycle h in
       let o = Before_and_after_edge.after_edge outputs in
       let int r = Bits.to_unsigned_int !r in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       let each f = List.iter2_exn i.hosts setups ~f in
       each (fun port setup ->
         Engine.Config.iter2
           port.config
           (Engine.Config.of_program_config setup.config)
           ~f:( := ));
       let feed ~words ~valid ~write =
         let longest =
           List.map setups ~f:(fun s -> List.length (words s))
           |> List.max_elt ~compare:Int.compare
           |> Option.value ~default:0
         in
         for n = 0 to longest - 1 do
           each (fun port setup ->
             match List.nth (words setup) n with
             | Some word ->
               valid port := Bits.vdd;
               write port n word
             | None -> valid port := Bits.gnd);
           cycle ()
         done;
         each (fun port _ -> valid port := Bits.gnd)
       in
       feed
         ~words:(fun s -> s.program)
         ~valid:(fun port -> port.program_write.valid)
         ~write:(fun port addr word ->
           port.program_write.addr <--. addr;
           port.program_write.data <--. word);
       feed
         ~words:(fun s -> s.preload)
         ~valid:(fun port -> port.tx.valid)
         ~write:(fun port _ word -> port.tx.value <--. word);
       let model =
         List.map setups ~f:(fun s ->
           let machine = Machine.create ~config:s.config ~program:s.program |> ok_exn in
           List.fold s.preload ~init:machine ~f:(fun m word ->
             Machine.write_tx m word |> ok_exn))
         |> System.create
         |> ref
       in
       each (fun port _ -> port.start := Bits.vdd);
       cycle ();
       each (fun port _ -> port.start := Bits.gnd);
       cycle ();
       let mismatch = ref None in
       let cycle_number = ref 0 in
       while !cycle_number < cycles && Option.is_none !mismatch do
         let n = !cycle_number in
         let engine_mismatch =
           List.zip_exn !model.engines o.engines
           |> List.find_mapi ~f:(fun engine (machine, outputs) ->
             let expected = Lockstep.State.of_machine machine in
             let actual = Lockstep.State.of_outputs outputs in
             if Lockstep.State.equal expected actual
             then None
             else Some (Mismatch.Engine { cycle = n; engine; expected; actual }))
         in
         let expected = System.pin_out !model, System.pin_dir !model in
         let actual = int o.pin_out, int o.pin_dir in
         match engine_mismatch with
         | Some _ -> mismatch := engine_mismatch
         | None when not ([%equal: int * int] expected actual) ->
           mismatch := Some (Pins { cycle = n; expected; actual })
         | None ->
           let levels = pads n in
           let actions = host n in
           i.pads <--. levels;
           let flushed =
             List.mapi (List.zip_exn i.hosts actions) ~f:(fun engine (port, action) ->
               (match action.tx with
                | Some word ->
                  port.tx.valid := Bits.vdd;
                  port.tx.value <--. word
                | None -> port.tx.valid := Bits.gnd);
               port.rx_pop := Bits.of_bool action.pop_rx;
               port.clear_irq := Bits.of_bool action.clear_irq;
               port.stop := Bits.of_bool action.stop;
               port.flush := Bits.of_bool action.flush;
               let flushed =
                 action.flush && (List.nth_exn !model.engines engine).halted
               in
               model
               := System.update !model engine ~f:(fun m ->
                    let m = if action.clear_irq then Machine.clear_irq m else m in
                    let m =
                      match Machine.read_rx m with
                      | Some (_, popped) when action.pop_rx -> popped
                      | Some _ | None -> m
                    in
                    if flushed then Machine.flush m else m);
               flushed)
           in
           cycle ();
           model := System.step !model ~pads:levels;
           List.iteri (List.zip_exn actions flushed) ~f:(fun engine (action, flushed) ->
             model
             := System.update !model engine ~f:(fun m ->
                  let m = if action.stop then Machine.stop m else m in
                  match action.tx with
                  | Some word when not flushed -> Machine.write_tx m word |> ok_exn
                  | Some _ | None -> m));
           react !model;
           Int.incr cycle_number
       done;
       !model, !mismatch)
;;

let lockstep ?(cycles = 400) ?host ?react ~pads setups =
  let model, mismatch = run ~cycles ?host ?react ~pads setups in
  (match mismatch with
   | None -> print_s [%message "lockstep held" (cycles : int)]
   | Some mismatch -> print_s [%message "MISMATCH" (mismatch : Mismatch.t)]);
  model
;;
