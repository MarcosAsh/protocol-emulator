open! Core
open Hardcaml
open Hardcaml_lws
open! Hardcaml_waveterm
open Protocol_emulator
open Manchester_line

(* The decoder, a cycle at a time, as the RTL has it: what it shows after the edge. *)
module Model (Config : Manchester_rx.Config) = struct
  module Rx = Manchester_rx.Make (Config)

  type state =
    | Idle
    | Hunt
    | Frame
  [@@deriving equal]

  type t =
    { state : state
    ; count : int
    ; last : int
    ; shift : int
    ; word : int
    ; word_bits : int
    }

  module Shown = struct
    type t =
      { bit : int option
      ; frame_active : bool
      ; sfd_seen : bool
      ; frame_end : bool
      ; word : int option
      }
    [@@deriving sexp_of, equal]
  end

  let one = 1 lsl Rx.fraction_bits
  let length rate = List.nth_exn Config.samples_per_bit rate * one
  let initial = { state = Idle; count = 0; last = 0; shift = 0; word = 0; word_bits = 0 }

  let step ~rate t samples =
    let length = length rate in
    let m = Config.samples_per_cycle in
    let idle = equal_state t.state Idle in
    let centre =
      List.findi samples ~f:(fun k sample ->
        let before = if k = 0 then t.last else List.nth_exn samples (k - 1) in
        sample <> before && (idle || t.count + ((k + 1) * one) >= 3 * length / 4))
    in
    let drifted = t.count + (m * one) in
    let lost = (not idle) && Option.is_none centre && drifted > 3 * length / 2 in
    let count =
      match centre with
      | Some (k, _) ->
        let after = (m - 1 - k) * one in
        if idle
        then after
        else (
          let error = t.count + ((k + 1) * one) - length in
          error - (error asr Config.gain_shift) + after)
      | None -> if idle then t.count else drifted
    in
    let bit = Option.map centre ~f:snd in
    let shift =
      match bit with
      | Some bit -> (bit lsl 7) lor if idle then 0 else t.shift lsr 1
      | None -> t.shift
    in
    let found = equal_state t.state Hunt && Option.is_some bit && shift = 0xd5 in
    let in_frame = equal_state t.state Frame && Option.is_some bit in
    let word_next = (Option.value bit ~default:0 lsl 15) lor (t.word lsr 1) in
    let half_word = equal_state t.state Frame && lost && t.word_bits = 8 in
    let word =
      if half_word
      then Some (t.word lsr 8)
      else if in_frame && t.word_bits = 15
      then Some word_next
      else None
    in
    let state =
      match t.state with
      | Idle -> if Option.is_some bit then Hunt else Idle
      | Hunt -> if lost then Idle else if found then Frame else Hunt
      | Frame -> if lost then Idle else Frame
    in
    ( { state
      ; count
      ; last = List.last_exn samples
      ; shift
      ; word = (if in_frame then word_next else t.word)
      ; word_bits =
          (if found then 0 else if in_frame then (t.word_bits + 1) % 16 else t.word_bits)
      }
    , { Shown.bit
      ; frame_active = equal_state state Frame
      ; sfd_seen = found
      ; frame_end = equal_state t.state Frame && lost
      ; word
      } )
  ;;

  (* the bytes of each frame, two to a word, low half first *)
  let frames shown =
    let frames, _ =
      List.fold shown ~init:([], None) ~f:(fun (done_, current) (s : Shown.t) ->
        let current = if s.sfd_seen then Some [] else current in
        let current =
          match current, s.word with
          | Some words, Some w -> Some (w :: words)
          | current, _ -> current
        in
        if s.frame_end
        then (
          let bytes =
            List.rev (Option.value current ~default:[])
            |> List.concat_map ~f:(fun w -> [ w land 0xff; w lsr 8 ])
          in
          bytes :: done_, None)
        else done_, current)
    in
    List.rev frames
  ;;

  let run ?(rate = 0) cycles = List.folding_map cycles ~init:initial ~f:(step ~rate)
end

module type Setup = sig
  val name : string

  include Manchester_rx.Config
end

let setup name ~per_bit ~per_cycle ~gain : (module Setup) =
  (module struct
    let name = name
    let samples_per_bit = [ per_bit ]
    let samples_per_cycle = per_cycle
    let gain_shift = gain
  end)
;;

let setups =
  List.concat_map
    [ "40 MHz", 4, 1
    ; "50 MHz", 5, 1
    ; "40 MHz both edges", 8, 2
    ; "50 MHz both edges", 10, 2
    ]
    ~f:(fun (name, per_bit, per_cycle) ->
      List.map [ 0; 3 ] ~f:(fun gain -> setup name ~per_bit ~per_cycle ~gain))
;;

(* Frames of 64 random bytes through the model, at the jitter IEEE 802.3 asks a station to
   accept (13.5 ns) and around it, the sender 100 ppm fast and slow (the standard allows
   100). Each cell: intact frames of 40. Jitter is uniform and independent per edge, the
   worst case for a loop that follows edges. *)
let%expect_test "frames intact under jitter, by sample rate and loop gain" =
  let jitters = [ 0.; 5.; 10.; 13.5; 15. ] in
  printf "%-18s %4s %5s" "sampling" "gain" "ppm";
  List.iter jitters ~f:(fun j -> printf " %6s" (sprintf "%gns" j));
  printf "\n";
  List.iter setups ~f:(fun (module S : Setup) ->
    let module M = Model (S) in
    List.iter [ 100.; -100. ] ~f:(fun ppm ->
      printf "%-18s %4s %+5.0f" S.name (sprintf "1/%d" (1 lsl S.gain_shift)) ppm;
      List.iter jitters ~f:(fun jitter ->
        let random = Random.State.make [| 7 |] in
        let intact =
          List.count (List.range 0 40) ~f:(fun _ ->
            let payload = List.init 64 ~f:(fun _ -> Random.State.int random 256) in
            transitions ~random ~ppm ~jitter (bits_of_bytes (preamble @ payload))
            |> sample
                 ~random
                 ~per_bit:(List.hd_exn S.samples_per_bit)
                 ~per_cycle:S.samples_per_cycle
            |> M.run
            |> M.frames
            |> [%equal: int list list] [ payload ])
        in
        printf " %6s" (sprintf "%d/40" intact));
      printf "\n"));
  [%expect
    {|
    sampling           gain   ppm    0ns    5ns   10ns 13.5ns   15ns
    40 MHz              1/1  +100  38/40  19/40   1/40   0/40   0/40
    40 MHz              1/1  -100  40/40  17/40   1/40   0/40   0/40
    40 MHz              1/8  +100  38/40  29/40  23/40  22/40  17/40
    40 MHz              1/8  -100  40/40  27/40  24/40  22/40  19/40
    50 MHz              1/1  +100  40/40  40/40  17/40   1/40   0/40
    50 MHz              1/1  -100  40/40  40/40  13/40   0/40   0/40
    50 MHz              1/8  +100  40/40  40/40  37/40  15/40   9/40
    50 MHz              1/8  -100  40/40  40/40  34/40  21/40   9/40
    40 MHz both edges   1/1  +100  40/40  40/40   9/40   0/40   0/40
    40 MHz both edges   1/1  -100  40/40  40/40  13/40   0/40   0/40
    40 MHz both edges   1/8  +100  40/40  40/40  40/40  40/40  33/40
    40 MHz both edges   1/8  -100  40/40  40/40  40/40  39/40  35/40
    50 MHz both edges   1/1  +100  40/40  40/40  40/40   4/40   0/40
    50 MHz both edges   1/1  -100  40/40  40/40  40/40   5/40   0/40
    50 MHz both edges   1/8  +100  40/40  40/40  40/40  40/40  37/40
    50 MHz both edges   1/8  -100  40/40  40/40  40/40  40/40  40/40
    |}]
;;

(* The chip's: both edges, either clock, gain 1/8. *)
let either_clock : (module Setup) =
  (module struct
    let name = "40 or 50 MHz both edges"
    let samples_per_bit = [ 8; 10 ]
    let samples_per_cycle = 2
    let gain_shift = 3
  end)
;;

(* The RTL against the model, every output on every cycle, over random short frames at
   random jitter and rate. *)
let%expect_test "the RTL follows the model" =
  List.iter (setups @ [ either_clock ]) ~f:(fun (module S : Setup) ->
    let module M = Model (S) in
    let module Harness = Hardcaml_test_harness.Lws_harness.Make (M.Rx.I) (M.Rx.O) in
    List.iteri S.samples_per_bit ~f:(fun rate per_bit ->
      Quickcheck.test
        ~trials:8
        (let open Quickcheck.Generator.Let_syntax in
         let%bind payload = List.gen_with_length 6 (Int.gen_incl 0 255) in
         let%bind jitter = Float.gen_incl 0. 20. in
         let%bind ppm = Float.gen_incl (-5000.) 5000. in
         let%map seed = Int.gen_incl 0 1_000_000 in
         payload, jitter, ppm, seed)
        ~f:(fun (payload, jitter, ppm, seed) ->
          let random = Random.State.make [| seed |] in
          let cycles =
            transitions ~random ~ppm ~jitter (bits_of_bytes (preamble @ payload))
            |> sample ~random ~per_bit ~per_cycle:S.samples_per_cycle
          in
          let expected = M.run ~rate cycles in
          Harness.run
            ~random_initial_state:`All
            ~create:M.Rx.hierarchical
            (fun (h @ local) ~inputs ~outputs ->
               let cycle () = Lws.step h in
               let outputs = Before_and_after_edge.after_edge outputs in
               inputs.clocking.clear := Bits.vdd;
               cycle ();
               inputs.clocking.clear := Bits.gnd;
               inputs.rate := Bits.of_bool (rate = 1);
               let wanted = Array.of_list (List.zip_exn cycles expected) in
               for n = 0 to Array.length wanted - 1 do
                 let samples, (want : M.Shown.t) = wanted.(n) in
                 inputs.rd := Bits.of_bit_list (List.rev samples);
                 cycle ();
                 let flag x = Bits.to_bool !x in
                 let opt (v : _ With_valid.t) =
                   Option.some_if (flag v.valid) (Bits.to_unsigned_int !(v.value))
                 in
                 let got =
                   { M.Shown.bit = opt outputs.bit
                   ; frame_active = flag outputs.frame_active
                   ; sfd_seen = flag outputs.sfd_seen
                   ; frame_end = flag outputs.frame_end
                   ; word = opt outputs.word
                   }
                 in
                 if not (M.Shown.equal got want)
                 then
                   raise_s
                     [%message
                       "RTL and model differ"
                         S.name
                         (got : M.Shown.t)
                         (want : M.Shown.t)
                         (payload : int list)]
               done));
      printf "%s at %d a bit, gain 1/%d: agree\n" S.name per_bit (1 lsl S.gain_shift)));
  [%expect
    {|
    40 MHz at 4 a bit, gain 1/1: agree
    40 MHz at 4 a bit, gain 1/8: agree
    50 MHz at 5 a bit, gain 1/1: agree
    50 MHz at 5 a bit, gain 1/8: agree
    40 MHz both edges at 8 a bit, gain 1/1: agree
    40 MHz both edges at 8 a bit, gain 1/8: agree
    50 MHz both edges at 10 a bit, gain 1/1: agree
    50 MHz both edges at 10 a bit, gain 1/8: agree
    40 or 50 MHz both edges at 8 a bit, gain 1/8: agree
    40 or 50 MHz both edges at 10 a bit, gain 1/8: agree
    |}]
;;

(* At 40 MHz, the start of frame straight from idle (its first bit is a one, so its first
   edge is a centre) and an odd byte, which comes out alone in a low half when the carrier
   goes. The TP_IDL's fall after that is a first edge again, and times out. *)
let%expect_test "waveform of a short frame" =
  let module S = (val setup "40 MHz" ~per_bit:4 ~per_cycle:1 ~gain:0) in
  let module M = Model (S) in
  let module Harness = Hardcaml_test_harness.Lws_harness.Make (M.Rx.I) (M.Rx.O) in
  let random = Random.State.make [| 1 |] in
  let cycles =
    transitions ~random ~ppm:0. ~jitter:0. (bits_of_bytes [ 0xd5; 0xa7 ])
    |> sample ~random ~per_bit:4 ~per_cycle:1
    |> List.drop_while ~f:(List.for_all ~f:(( = ) 0))
    |> fun cycles -> [ 0 ] :: [ 0 ] :: List.take cycles 100
  in
  let display_rules =
    List.map
      [ "rd"
      ; "bit$valid"
      ; "bit$value"
      ; "sfd_seen"
      ; "frame_active"
      ; "frame_end"
      ; "word$valid"
      ]
      ~f:(fun name -> Display_rule.port_name_is name ~wave_format:Bit)
    @ [ Display_rule.port_name_is "word$value" ~wave_format:Hex
      ; Display_rule.port_name_is "manchester_rx$count" ~wave_format:Int
      ]
  in
  Harness.run
    ~create:M.Rx.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:20
        ~display_width:130
        ~wave_width:(-1)
        waves)
    (fun (h @ local) ~inputs ~outputs ->
      let cycle () = Lws.step h in
      let outputs = Before_and_after_edge.after_edge outputs in
      let words = ref [] in
      inputs.clocking.clear := Bits.vdd;
      cycle ();
      inputs.clocking.clear := Bits.gnd;
      let cycles = Array.of_list cycles in
      for n = 0 to Array.length cycles - 1 do
        inputs.rd := Bits.of_bit_list (List.rev cycles.(n));
        cycle ();
        if Bits.to_bool !(outputs.word.valid)
        then words := !(outputs.word.value) :: !words
      done;
      let words = List.rev !words in
      print_s [%message (words : Bits.Hex.t list)]);
  [%expect
    {|
    (words (16'h00a7))
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────────────────────────────────────────────────────┐
    │rd                ││   ┌───┐   ┌───┐   ┌───┐   ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌───┐ ┌─┐   ┌───┐   ┌─────────────┐                              │
    │                  ││───┘   └───┘   └───┘   └───┘ └─┘ └─┘ └─┘ └─┘   └─┘ └───┘   └───┘             └──────────────────────────    │
    │bit$valid         ││    ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐  ┌┐            ┌┐                            │
    │                  ││────┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└──┘└────────────┘└────────────────────────    │
    │bit$value         ││    ┌───┐   ┌───┐   ┌───┐   ┌───────────────────┐       ┌───┐   ┌─────────────┐                             │
    │                  ││────┘   └───┘   └───┘   └───┘                   └───────┘   └───┘             └─────────────────────────    │
    │sfd_seen          ││                                ┌┐                                                                          │
    │                  ││────────────────────────────────┘└──────────────────────────────────────────────────────────────────────    │
    │frame_active      ││                                ┌──────────────────────────────────────┐                                    │
    │                  ││────────────────────────────────┘                                      └────────────────────────────────    │
    │frame_end         ││                                                                       ┌┐                                   │
    │                  ││───────────────────────────────────────────────────────────────────────┘└───────────────────────────────    │
    │word$valid        ││                                                                       ┌┐                                   │
    │                  ││───────────────────────────────────────────────────────────────────────┘└───────────────────────────────    │
    │                  ││───────────────────────────────────────────────────────────────────────┬────────────────────────────────    │
    │word$value        ││ 0000                                                                  │00A7                                │
    │                  ││───────────────────────────────────────────────────────────────────────┴────────────────────────────────    │
    │                  ││─────┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬──────┬┬┬┬┬┬┬┬──────────────────    │
    │manchester_rx$coun││ 0   │││││││││││││││││││││││││││││││││││││││││││││││││││││││││││││││││││28    ││││││││28                    │
    │                  ││─────┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴──────┴┴┴┴┴┴┴┴──────────────────    │
    └──────────────────┘└────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
    |}]
;;
