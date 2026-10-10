open! Core
open Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Edge_stamps.I) (Edge_stamps.O)

let ( <--. ) = Bits.( <--. )

(* The queue a cycle at a time, as the hardware has it after the edge. *)
module Model = struct
  type t =
    { last : int
    ; queue : (int * int) list
    ; lost : bool
    ; pushes : int
    }

  let initial = { last = 0; queue = []; lost = false; pushes = 0 }

  let step t ~pads ~now ~mask ~pop ~flush =
    let moved = pads lxor t.last land mask <> 0 in
    let full = List.length t.queue >= Edge_stamps.depth && not pop in
    if flush
    then { t with last = pads; queue = []; lost = false }
    else (
      let queue = if pop then List.tl t.queue |> Option.value ~default:[] else t.queue in
      let takes = moved && not full in
      { last = pads
      ; queue = (if takes then queue @ [ now, pads ] else queue)
      ; lost = t.lost || (moved && full)
      ; pushes = t.pushes + Bool.to_int takes
      })
  ;;

  let shown t =
    let time, pins = List.hd t.queue |> Option.value ~default:(0, 0) in
    time, pins, List.length t.queue, t.lost
  ;;
end

(* Pads that hold a few cycles at a time, a random mask, pops and the odd flush: the queue
   and the model agree every cycle. *)
let%expect_test "the queue follows the model" =
  let random = Random.State.make [| 5 |] in
  let int n = Random.State.int random n in
  let pushed = ref 0 in
  let lost = ref 0 in
  let full = ref 0 in
  for _ = 1 to 20 do
    let mask = int (1 lsl Isa.num_pins) in
    Harness.run
      ~random_initial_state:`All
      ~create:Edge_stamps.hierarchical
      (fun (h @ local) ~inputs ~outputs ->
         let cycle () = Lws.step h in
         let o = Before_and_after_edge.after_edge outputs in
         let int_of r = Bits.to_unsigned_int !r in
         inputs.clocking.clear := Bits.vdd;
         cycle ();
         inputs.clocking.clear := Bits.gnd;
         inputs.control.mask <--. mask;
         let model = ref Model.initial in
         let pads = ref 0 in
         for now = 0 to 499 do
           if int 4 = 0 then pads := int (1 lsl Isa.num_pins);
           let pop = int 5 = 0 in
           let flush = int 150 = 0 in
           inputs.pads <--. !pads;
           inputs.now <--. now;
           inputs.control.pop := Bits.of_bool pop;
           inputs.control.flush := Bits.of_bool flush;
           model := Model.step !model ~pads:!pads ~now ~mask ~pop ~flush;
           if List.length !model.queue = Edge_stamps.depth then Int.incr full;
           cycle ();
           let got =
             ( int_of o.head.time
             , int_of o.head.pins
             , int_of o.level
             , Bits.to_bool !(o.lost) )
           in
           let want = Model.shown !model in
           if not ([%equal: int * int * int * bool] got want)
           then
             raise_s
               [%message
                 "queue and model differ"
                   (now : int)
                   (got : int * int * int * bool)
                   (want : int * int * int * bool)]
         done;
         pushed := !pushed + !model.pushes;
         if !model.lost then Int.incr lost)
  done;
  print_s [%message "agree" (!pushed : int) (!full : int) (!lost : int)];
  [%expect {| (agree (!pushed 1901) (!full 2774) (!lost 13)) |}]
;;

module Two = Engines.Make (struct
    let engines = 2
  end)

module Chip = Hardcaml_test_harness.Lws_harness.Make (Two.I) (Two.O)

let catcher =
  {|
loop:
    capture_arm
    wait 1 pin 0
    mov x, capture
    wait 0 pin 0
    jmp loop
|}
;;

(* Pins 0, 1, 2, 4 and 16 watched, engine 0 catching pin 0's rises with its capture unit
   in lockstep with the model, the host popping each stamp as it shows: every stamp is the
   model's time and pads at a watched edge, and pin 0's rises carry engine 0's captures. *)
let%expect_test "stamps on the chip time edges as the engine's capture does" =
  let config = { Program_config.default with capture_pin = 0; capture_rising = true } in
  let program = Firmware.assemble catcher in
  let mask = 0b1_0000_0000_0001_0111 in
  let random = Random.State.make [| 9 |] in
  let inputs_only = 0b1111_1111_0000_0001_1111 in
  Chip.run
    ~random_initial_state:`All
    ~create:(Two.hierarchical ~gated:false ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let cycle () = Lws.cycle h in
       let o = Before_and_after_edge.after_edge outputs in
       let int r = Bits.to_unsigned_int !r in
       let port = List.hd_exn i.hosts in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       Engine.Config.iter2 port.config (Engine.Config.of_program_config config) ~f:( := );
       List.iteri program ~f:(fun addr word ->
         port.program_write.valid := Bits.vdd;
         port.program_write.addr <--. addr;
         port.program_write.data <--. word;
         cycle ());
       port.program_write.valid := Bits.gnd;
       i.stamps.mask <--. mask;
       i.stamps.flush := Bits.vdd;
       cycle ();
       i.stamps.flush := Bits.gnd;
       port.start := Bits.vdd;
       cycle ();
       port.start := Bits.gnd;
       cycle ();
       let machine = Machine.create ~config ~program |> ok_exn in
       let model = ref (System.create [ machine; Machine.stop machine ]) in
       let pads = ref 0 in
       let last = ref 0 in
       let expected = Queue.create () in
       let popped = Queue.create () in
       let captures = Queue.create () in
       let mismatch = ref None in
       let n = ref 0 in
       while !n < 1500 && Option.is_none !mismatch do
         let m = List.hd_exn !model.engines in
         let want = Lockstep.State.of_machine m in
         let got = Lockstep.State.of_outputs (List.hd_exn o.engines) in
         if not (Lockstep.State.equal want got) then mismatch := Some !n;
         if int o.stamps.level > 0
         then (
           Queue.enqueue popped (int o.stamps.head.time, int o.stamps.head.pins);
           i.stamps.pop := Bits.vdd)
         else i.stamps.pop := Bits.gnd;
         if Random.State.int random 6 = 0
         then pads := Random.State.int random (1 lsl Isa.num_pins) land inputs_only;
         if !pads lxor !last land mask <> 0 then Queue.enqueue expected (m.now, !pads);
         last := !pads;
         i.pads <--. !pads;
         cycle ();
         model := System.step !model ~pads:!pads;
         let after = List.hd_exn !model.engines in
         if after.capture <> m.capture then Queue.enqueue captures after.capture;
         Int.incr n
       done;
       let popped = Queue.to_list popped in
       let expected = List.take (Queue.to_list expected) (List.length popped) in
       let rises =
         List.filter_map popped ~f:(fun (time, pins) ->
           Option.some_if (pins land 1 = 1) time)
       in
       print_s
         [%message
           ""
             ~lockstep:(!mismatch : int option)
             ~stamps:(List.length popped : int)
             ~as_model:([%equal: (int * int) list] popped expected : bool)
             ~captures:(Queue.length captures : int)
             ~each_capture_a_stamp:
               (Queue.for_all captures ~f:(List.mem rises ~equal:Int.equal) : bool)
             ~lost:(Bits.to_bool !(o.stamps.lost) : bool)]);
  [%expect
    {|
    ((lockstep ()) (stamps 223) (as_model true) (captures 52)
     (each_capture_a_stamp true) (lost false))
    |}]
;;
