open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Host_port.I) (Host_port.O)
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

let events (o : Bits.t ref Host_port.O.t) =
  let int r = Bits.to_unsigned_int !r in
  let on r (event : Model.Event.t) = Option.some_if (Bits.to_bool !r) event in
  List.filter_opt
    [ on o.start Start
    ; on o.clear_irq Clear_irq
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
    ; expected_events : Model.Event.t list
    ; events : Model.Event.t list
    ; expected_replies : int list
    ; replies : int list
    ; expected_config : int list
    ; config : int list
    }
  [@@deriving sexp_of]
end

(* Runs random frames until the port and the model disagree. A frame is judged just before
   the first clock edge of the next, when its last strobe is long out: that keeps the gap
   between frames as short as the frame asks for. *)
let fuzz ?(halves = [ 4; 4; 5; 7; 12 ]) ?(edge = 1) ~seed ~frames () =
  let random = Splittable_random.of_int seed in
  Harness.run
    ~random_initial_state:`All
    ~create:Host_port.hierarchical
    (fun (h @ local) ~inputs ~outputs ->
       let o = Before_and_after_edge.after_edge outputs in
       let seen = ref [] in
       let rx = ref (List.init 200 ~f:(fun n -> 0x4000 + n)) in
       let popped = ref false in
       let idle = ref 0 in
       let miso_high_when_idle = ref false in
       let cycle () =
         if !popped then rx := List.drop !rx 1;
         inputs.status.rx_head <--. Option.value (List.hd !rx) ~default:empty_rx;
         Lws.step h;
         let now = events o in
         popped := List.mem now Rx_pop ~equal:Model.Event.equal;
         seen := List.rev_append now !seen;
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
       let model = ref (Model.create ()) in
       let failure = ref None in
       let strobes = ref 0 in
       let words_read = ref 0 in
       let judge = ref (fun () -> ()) in
       let run frame_number (frame : Frame.t) =
         let status = random_status random in
         Status.iter2 inputs.status status ~f:(fun port value -> port <--. value);
         let words = List.take frame.words (Frame.complete_words frame) in
         let expected_events, expected_replies =
           if frame.write
           then
             ( List.concat_map words ~f:(fun word ->
                 let next, events = Model.write !model ~reg:frame.reg word in
                 model := next;
                 events)
             , [] )
           else (
             let replies, events =
               List.mapi words ~f:(fun n (_ : int) ->
                 let rx_head = Option.value (List.nth !rx n) ~default:empty_rx in
                 Model.read !model ~status:{ status with rx_head } ~reg:frame.reg)
               |> List.unzip
             in
             List.concat events, replies)
         in
         let expected_config = Model.config !model in
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
           if not (frame.release_high && bit = frame.bits - 1) then inputs.sck := Bits.gnd;
           if bit >= 8 && bit % 16 = 7 then replies := (!shifted land 0xffff) :: !replies
         done;
         wait frame.trail;
         inputs.cs_n := Bits.vdd;
         (* a clock left high comes down before the next frame, as mode 0 wants, and a pop
            from the last edge lands before the next frame is planned *)
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
              let config =
                Engine.Config.to_list
                  (Engine.Config.map o.config ~f:(fun r -> Bits.to_unsigned_int !r))
              in
              if Option.is_none !failure
                 && not
                      ([%equal: Model.Event.t list] events expected_events
                       && [%equal: int list] replies expected_replies
                       && [%equal: int list] config expected_config)
              then
                failure
                := Some
                     { Failure.frame_number
                     ; frame
                     ; expected_events
                     ; events
                     ; expected_replies
                     ; replies
                     ; expected_config
                     ; config
                     }
       in
       let generated = List.init frames ~f:(fun _ -> Frame.random ~halves ~edge random) in
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

let%expect_test "random frames, whole and cut short, against the register map" =
  List.iter [ 1; 2; 3 ] ~f:(fun seed -> fuzz ~seed ~frames:300 ());
  [%expect
    {|
    ((seed 1) (frames 300) (cut 122) (!strobes 78) (!words_read 203)
     (!miso_high_when_idle false) (!failure ()))
    ((seed 2) (frames 300) (cut 110) (!strobes 111) (!words_read 204)
     (!miso_high_when_idle false) (!failure ()))
    ((seed 3) (frames 300) (cut 124) (!strobes 79) (!words_read 183)
     (!miso_high_when_idle false) (!failure ()))
    |}]
;;
