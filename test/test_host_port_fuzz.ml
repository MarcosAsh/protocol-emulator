open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Model = Host_port_model
module Reg = Host_port.Reg
module Status = Host_port.Status
module Frame = Host_frame

let ( <--. ) = Bits.( <--. )
let empty_rx = 0xdead

let random_status random =
  Status.map Status.port_widths ~f:(fun width ->
    Splittable_random.int random ~lo:0 ~hi:((1 lsl width) - 1))
;;

let events (o : Bits.t ref Engine.Host.t) =
  let int r = Bits.to_unsigned_int !r in
  let on r (event : Model.Event.t) = Option.some_if (Bits.to_bool !r) event in
  List.filter_opt
    [ on o.start Start
    ; on o.clear_irq Clear_irq
    ; on o.stop Stop
    ; on o.flush Flush
    ; on
        o.program_write.valid
        (Program_write
           { addr = int o.program_write.addr; data = int o.program_write.data })
    ; on o.tx.valid (Tx (int o.tx.value))
    ; on o.rx_pop Rx_pop
    ]
;;

module Failure = struct
  type t =
    { frame_number : int
    ; frame : Frame.t
    ; expected_events : (int * Model.Event.t) list
    ; events : (int * Model.Event.t) list
    ; expected_replies : int list
    ; replies : int list
    ; expected_configs : int list list
    ; configs : int list list
    }
  [@@deriving sexp_of]
end

module Fuzz (Config : Host_port.Config) = struct
  let engines = Config.engines

  module Dut = Host_port.Make (Config)
  module Harness = Hardcaml_test_harness.Lws_harness.Make (Dut.I) (Dut.O)

  (* Runs random frames until the port and the model disagree. A frame is judged just
     before the first clock edge of the next, when its last strobe is long out: that keeps
     the gap between frames as short as the frame asks for. *)
  let fuzz ?(halves = [ 4; 4; 5; 7; 12 ]) ?(edge = 1) ~seed ~frames () =
    let random = Splittable_random.of_int seed in
    Harness.run
      ~random_initial_state:`All
      ~create:Dut.hierarchical
      (fun (h @ local) ~inputs ~outputs ->
         let o = Before_and_after_edge.after_edge outputs in
         let seen = ref [] in
         let rx =
           Array.init engines ~f:(fun engine ->
             List.init 200 ~f:(fun n -> 0x4000 + (0x1000 * engine) + n))
         in
         let popped = Array.create ~len:engines false in
         let idle = ref 0 in
         let miso_high_when_idle = ref false in
         let cycle () =
           List.iteri inputs.status ~f:(fun engine status ->
             if popped.(engine) then rx.(engine) <- List.drop rx.(engine) 1;
             status.rx_head <--. Option.value (List.hd rx.(engine)) ~default:empty_rx);
           Lws.step h;
           List.iteri o.engines ~f:(fun engine port ->
             let now = events port in
             popped.(engine) <- List.mem now Rx_pop ~equal:Model.Event.equal;
             seen := List.rev_append (List.map now ~f:(fun e -> engine, e)) !seen);
           idle := if Bits.to_bool !(inputs.cs_n) then !idle + 1 else 0;
           if !idle > 3 && Bits.to_bool !(o.miso) then miso_high_when_idle := true
         in
         let wait n =
           for _ = 1 to n do
             cycle ()
           done
         in
         inputs.clocking.clear := Bits.vdd;
         inputs.cs_n := Bits.vdd;
         cycle ();
         inputs.clocking.clear := Bits.gnd;
         wait 3;
         let model = ref (Model.create ~engines ()) in
         let failure = ref None in
         let strobes = ref 0 in
         let words_read = ref 0 in
         let judge = ref (fun () -> ()) in
         let run frame_number (frame : Frame.t) =
           let statuses = List.map inputs.status ~f:(fun _ -> random_status random) in
           List.iter2_exn inputs.status statuses ~f:(fun ports status ->
             Status.iter2 ports status ~f:(fun port value -> port <--. value));
           let words = List.take frame.words (Frame.complete_words frame) in
           let expected_events, expected_replies =
             if frame.write
             then
               ( List.concat_map words ~f:(fun word ->
                   let next, events = Model.write !model ~statuses ~reg:frame.reg word in
                   model := next;
                   events)
               , [] )
             else (
               let replies, events =
                 List.mapi words ~f:(fun n (_ : int) ->
                   let statuses =
                     List.mapi statuses ~f:(fun engine status ->
                       let rx_head =
                         Option.value (List.nth rx.(engine) n) ~default:empty_rx
                       in
                       { status with rx_head })
                   in
                   Model.read !model ~statuses ~reg:frame.reg)
                 |> List.unzip
               in
               List.concat events, replies)
           in
           let expected_configs = Model.configs !model in
           for _ = 1 to frame.stray do
             inputs.sck := Bits.vdd;
             wait frame.half;
             inputs.sck := Bits.gnd;
             wait frame.half
           done;
           let bytes =
             ((if frame.write then 0x80 else 0) lor frame.reg)
             :: List.concat_map frame.words ~f:(fun w -> [ w lsr 8; w land 0xff ])
           in
           let shifted = ref 0 in
           let replies = ref [] in
           inputs.cs_n := Bits.gnd;
           wait frame.lead;
           if frame.bits = 0 then !judge ();
           for bit = 0 to frame.bits - 1 do
             let byte = List.nth_exn bytes (bit / 8) in
             inputs.mosi := Bits.of_bool ((byte lsr (7 - (bit % 8))) land 1 = 1);
             wait frame.half;
             if bit = 0 then !judge ();
             shifted := (!shifted lsl 1) lor Bits.to_unsigned_int !(o.miso);
             inputs.sck := Bits.vdd;
             wait frame.half;
             if not (frame.release_high && bit = frame.bits - 1)
             then inputs.sck := Bits.gnd;
             if bit >= 8 && bit % 16 = 7
             then replies := (!shifted land 0xffff) :: !replies
           done;
           wait frame.trail;
           inputs.cs_n := Bits.vdd;
           (* a clock left high comes down before the next frame, as mode 0 wants, and a
              pop from the last edge lands before the next frame is planned *)
           if frame.release_high
           then (
             wait 1;
             inputs.sck := Bits.gnd;
             wait 3);
           wait frame.gap;
           judge
           := fun () ->
                let events = List.rev !seen in
                seen := [];
                let replies = if frame.write then [] else List.rev !replies in
                strobes := !strobes + List.length events;
                words_read := !words_read + List.length replies;
                let configs =
                  List.map o.engines ~f:(fun port ->
                    Engine.Config.to_list
                      (Engine.Config.map port.config ~f:(fun r -> Bits.to_unsigned_int !r)))
                in
                if Option.is_none !failure
                   && not
                        ([%equal: (int * Model.Event.t) list] events expected_events
                         && [%equal: int list] replies expected_replies
                         && [%equal: int list list] configs expected_configs)
                then
                  failure
                  := Some
                       { Failure.frame_number
                       ; frame
                       ; expected_events
                       ; events
                       ; expected_replies
                       ; replies
                       ; expected_configs
                       ; configs
                       }
         in
         let generated =
           List.init frames ~f:(fun _ -> Frame.random ~halves ~edge random)
         in
         List.iteri generated ~f:(fun n frame ->
           if Option.is_none !failure then run n frame);
         wait 8;
         !judge ();
         let cut =
           List.count generated ~f:(fun f -> f.bits < 8 + (16 * List.length f.words))
         in
         print_s
           [%message
             (seed : int)
               (frames : int)
               (cut : int)
               (!strobes : int)
               (!words_read : int)
               (!miso_high_when_idle : bool)
               (!failure : Failure.t option)])
  ;;
end

module One = Fuzz (struct
    let engines = 1
  end)

module Two = Fuzz (struct
    let engines = 2
  end)

module Three = Fuzz (struct
    let engines = 3
  end)

let fuzz = One.fuzz

let%expect_test "random frames, whole and cut short, against the register map" =
  List.iter [ 1; 2; 3 ] ~f:(fun seed -> fuzz ~seed ~frames:300 ());
  [%expect
    {|
    ((seed 1) (frames 300) (cut 122) (!strobes 85) (!words_read 203)
     (!miso_high_when_idle false) (!failure ()))
    ((seed 2) (frames 300) (cut 110) (!strobes 139) (!words_read 204)
     (!miso_high_when_idle false) (!failure ()))
    ((seed 3) (frames 300) (cut 124) (!strobes 96) (!words_read 183)
     (!miso_high_when_idle false) (!failure ()))
    |}]
;;

let%expect_test "random frames with a select register in the map" =
  Two.fuzz ~seed:5 ~frames:400 ();
  Three.fuzz ~seed:6 ~frames:400 ();
  [%expect
    {|
    ((seed 5) (frames 400) (cut 163) (!strobes 155) (!words_read 270)
     (!miso_high_when_idle false) (!failure ()))
    ((seed 6) (frames 400) (cut 157) (!strobes 8) (!words_read 260)
     (!miso_high_when_idle false) (!failure ()))
    |}]
;;

let%expect_test "outside what the interface allows" =
  fuzz ~halves:[ 3 ] ~seed:4 ~frames:300 ();
  fuzz ~halves:[ 2 ] ~seed:4 ~frames:300 ();
  fuzz ~edge:0 ~seed:4 ~frames:300 ();
  [%expect
    {|
    ((seed 4) (frames 300) (cut 148) (!strobes 87) (!words_read 170)
     (!miso_high_when_idle false) (!failure ()))
    ((seed 4) (frames 300) (cut 148) (!strobes 6) (!words_read 5)
     (!miso_high_when_idle false)
     (!failure
      (((frame_number 7)
        (frame
         ((write false) (reg 9) (words (63371 60329)) (bits 40)
          (release_high false) (stray 1) (half 2) (lead 2) (trail 2) (gap 3)))
        (expected_events ()) (events ()) (expected_replies (2 2)) (replies (1 1))
        (expected_configs
         ((0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)))
        (configs ((0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)))))))
    ((seed 4) (frames 300) (cut 148) (!strobes 87) (!words_read 170)
     (!miso_high_when_idle false) (!failure ()))
    |}]
;;
