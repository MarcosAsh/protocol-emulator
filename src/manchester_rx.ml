open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val samples_per_bit : int list
  val samples_per_cycle : int
  val gain_shift : int
end

(* A first-order digital PLL on the transitions themselves:
   {v
   A Manchester bit always has a transition at its centre. Measure each transition from
   where the last centre was expected; one past 3/4 of a bit is the next centre, and
   moves the expectation by error * 2^-gain_shift.
   IEEE 802.3-2008 14.3.1.3.1: a station accepts 13.5 ns of jitter on its edges.
   v} *)
module Make (Config : Config) = struct
  open Config

  let () =
    if samples_per_cycle < 1 || samples_per_cycle > 2
    then raise_s [%message "BUG: one or two samples a cycle" (samples_per_cycle : int)];
    if List.is_empty samples_per_bit || List.length samples_per_bit > 2
    then raise_s [%message "BUG: one or two rates" (samples_per_bit : int list)];
    if List.exists samples_per_bit ~f:(fun n -> n < 4)
    then
      raise_s [%message "BUG: four samples a bit at least" (samples_per_bit : int list)];
    if gain_shift < 0
    then raise_s [%message "BUG: negative gain shift" (gain_shift : int)]
  ;;

  let fraction_bits = gain_shift + 2
  let one = 1 lsl fraction_bits
  let bit_length n = n * one
  let blank n = 3 * bit_length n / 4
  let timeout n = 3 * bit_length n / 2
  let slowest = List.reduce_exn samples_per_bit ~f:Int.max
  let count_bits = Int.ceil_log2 (timeout slowest + (2 * samples_per_cycle * one) + 1) + 1

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; rd : 'a [@bits samples_per_cycle]
      ; rate : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { bit : 'a With_valid.t [@bits 1]
      ; frame_active : 'a
      ; sfd_seen : 'a
      ; frame_end : 'a
      ; word : 'a With_valid.t [@bits 16]
      }
    [@@deriving hardcaml]
  end

  module State = struct
    type t =
      | Idle
      | Hunt
      | Frame
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let%hw.Always.State_machine sm = Always.State_machine.create (module State) spec in
    let constant n = of_signed_int ~width:count_bits n in
    (* the rate's lengths; with one rate [rate] is ignored *)
    let by_rate f =
      match samples_per_bit with
      | [ n ] -> constant (f n)
      | first :: second :: _ -> mux2 i.rate (constant (f second)) (constant (f first))
      | [] -> assert false
    in
    let%hw bit_length = by_rate bit_length in
    let%hw blank = by_rate blank in
    let%hw timeout = by_rate timeout in
    let%hw count = wire count_bits in
    let%hw last_sample = reg spec (msb i.rd) in
    let samples = bits_lsb i.rd in
    let%hw_list edges =
      List.mapi samples ~f:(fun k sample ->
        sample ^: if k = 0 then last_sample else List.nth_exn samples (k - 1))
    in
    (* the phase at each sample, and where it goes if that sample takes a centre *)
    let at k = count +: constant ((k + 1) * one) in
    let after k = constant ((samples_per_cycle - 1 - k) * one) in
    let%hw_list centres =
      List.mapi edges ~f:(fun k edge -> mux2 (sm.is Idle) edge (edge &: (at k >=+ blank)))
    in
    (* a cycle has room for one centre: two would need a half bit under a sample *)
    let%hw_list taken =
      List.mapi centres ~f:(fun k centre ->
        List.fold (List.take centres k) ~init:centre ~f:(fun acc earlier ->
          acc &: ~:earlier))
    in
    let%hw any = reduce ~f:( |: ) taken in
    let%hw centre_level =
      onehot_select
        (List.map2_exn taken samples ~f:(fun valid value -> { With_valid.valid; value }))
    in
    let residual k =
      let error = at k -: bit_length in
      error -: sra error ~by:gain_shift
    in
    let%hw centred =
      onehot_select
        (List.mapi taken ~f:(fun k taken ->
           { With_valid.valid = taken
           ; value = mux2 (sm.is Idle) (after k) (residual k +: after k)
           }))
    in
    let%hw drifted = count +: constant (samples_per_cycle * one) in
    let%hw lost = ~:(sm.is Idle) &: ~:any &: (drifted >+ timeout) in
    count <-- reg spec (mux2 any centred @@ mux2 (sm.is Idle) count drifted);
    let%hw shift = wire 8 in
    let%hw shifted = centre_level @: mux2 (sm.is Idle) (zero 7) shift.:[7, 1] in
    shift <-- reg spec ~enable:any shifted;
    let%hw found = sm.is Hunt &: any &: (shifted ==:. 0xd5) in
    let%hw in_frame = sm.is Frame &: any in
    let%hw word = wire 16 in
    let%hw word_bits = wire 4 in
    let%hw word_next = centre_level @: word.:[15, 1] in
    word <-- reg spec ~enable:in_frame word_next;
    word_bits
    <-- reg spec (mux2 found (zero 4) @@ mux2 in_frame (word_bits +:. 1) word_bits);
    let%hw half_word = sm.is Frame &: lost &: (word_bits ==:. 8) in
    Always.(
      compile
        [ sm.switch
            [ Idle, [ when_ any [ sm.set_next Hunt ] ]
            ; ( Hunt
              , [ if_ lost [ sm.set_next Idle ] @@ elif found [ sm.set_next Frame ] [] ] )
            ; Frame, [ when_ lost [ sm.set_next Idle ] ]
            ]
        ]);
    let%hw word_valid = in_frame &: (word_bits ==:. 15) |: half_word in
    (* values hold between strobes, so a waveform shows them *)
    { O.bit = { valid = reg spec any; value = reg spec ~enable:any centre_level }
    ; frame_active = sm.is Frame
    ; sfd_seen = reg spec found
    ; frame_end = reg spec (sm.is Frame &: lost)
    ; word =
        { valid = reg spec word_valid
        ; value =
            reg
              spec
              ~enable:word_valid
              (mux2 half_word (uresize word.:[15, 8] ~width:16) word_next)
        }
    }
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"manchester_rx" create i
  ;;
end
