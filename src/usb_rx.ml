open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val samples_per_bit : int
  val samples_per_cycle : int
end

(* Edge-aligned sampling with a full resync on every edge:
   {v
   NRZI with a 0 stuffed after six 1s has a D+ edge at least every seven bits. Count
   samples from the last one; the bit is the sample half a bit on, then one each bit.
   USB 2.0 table 7-10: a full speed receiver takes 18.5 ns of jitter to the next edge.
   v} *)
module Make (Config : Config) = struct
  open Config

  let () =
    if samples_per_cycle < 1 || samples_per_cycle > 2
    then raise_s [%message "BUG: one or two samples a cycle" (samples_per_cycle : int)];
    if samples_per_bit < 4 || not (Int.is_pow2 samples_per_bit)
    then
      raise_s
        [%message
          "BUG: a power of two samples a bit, four at least" (samples_per_bit : int)]
  ;;

  let phase_bits = Int.ceil_log2 samples_per_bit
  let centre = samples_per_bit / 2

  (* a SYNC has seven; three are enough to tell one from noise *)
  let sync_zeros = 3

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; dp : 'a [@bits samples_per_cycle]
      ; dm : 'a [@bits samples_per_cycle]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { bit : 'a With_valid.t [@bits 1]
      ; packet_active : 'a
      ; sync_seen : 'a
      ; packet_end : 'a
      ; stuff_error : 'a
      ; aligned : 'a
      ; word : 'a With_valid.t [@bits 16]
      }
    [@@deriving hardcaml]
  end

  module State = struct
    type t =
      | Idle
      | Hunt
      | Packet
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let%hw.Always.State_machine sm = Always.State_machine.create (module State) spec in
    let%hw phase = wire phase_bits in
    let%hw last_dp = reg spec (msb i.dp) in
    let dps = bits_lsb i.dp in
    let dms = bits_lsb i.dm in
    let%hw_list edges =
      List.mapi dps ~f:(fun k sample ->
        sample ^: if k = 0 then last_dp else List.nth_exn dps (k - 1))
    in
    (* samples since the last edge, wrapping a bit at a time *)
    let%hw_list positions =
      List.folding_map edges ~init:phase ~f:(fun before edge ->
        let at = mux2 edge (zero phase_bits) (before +:. 1) in
        at, at)
    in
    phase <-- reg spec (List.last_exn positions);
    (* a bit is longer than a cycle, so a cycle has one centre at most *)
    let%hw_list centres = List.map positions ~f:(fun at -> at ==:. centre) in
    let%hw any = reduce ~f:( |: ) centres in
    let pick samples =
      onehot_select
        (List.map2_exn centres samples ~f:(fun valid value -> { With_valid.valid; value }))
    in
    let%hw plus = pick dps in
    let%hw minus = pick dms in
    (* D+ at the last centre, inverted so that a clear leaves J *)
    let%hw was_low = reg spec ~enable:any ~:plus in
    let%hw se0 = ~:plus &: ~:minus in
    let%hw decoded = plus ^: was_low in
    let%hw zeros = wire 2 in
    let%hw ones = wire 3 in
    let%hw start = sm.is Idle &: any &: ~:plus &: minus &: ~:was_low in
    let%hw hunting = sm.is Hunt &: any in
    let%hw synced = zeros ==:. sync_zeros in
    let%hw found = hunting &: ~:se0 &: decoded &: synced in
    let%hw missed = hunting &: (se0 |: (decoded &: ~:synced)) in
    zeros
    <-- reg
          spec
          (mux2 start (of_unsigned_int ~width:2 1)
           @@ mux2 (hunting &: ~:decoded &: ~:synced) (zeros +:. 1) zeros);
    let%hw receiving = sm.is Packet &: any in
    let%hw ends = receiving &: se0 in
    let%hw full_run = ones ==:. 6 in
    let%hw stuff_error = receiving &: ~:se0 &: full_run &: decoded in
    let%hw taken = receiving &: ~:se0 &: ~:full_run in
    (* SYNC's last 1 is the first of a run *)
    ones
    <-- reg
          spec
          (mux2 found (of_unsigned_int ~width:3 1)
           @@ mux2 receiving (mux2 (decoded &: ~:full_run) (ones +:. 1) (zero 3)) ones);
    let%hw word = wire 16 in
    let%hw word_bits = wire 4 in
    let%hw word_next = decoded @: word.:[15, 1] in
    word <-- reg spec ~enable:taken word_next;
    word_bits <-- reg spec (mux2 found (zero 4) @@ mux2 taken (word_bits +:. 1) word_bits);
    let%hw finishes = ends |: stuff_error in
    let%hw half_word = ends &: (word_bits ==:. 8) in
    let%hw word_valid = taken &: (word_bits ==:. 15) |: half_word in
    Always.(
      compile
        [ sm.switch
            [ Idle, [ when_ start [ sm.set_next Hunt ] ]
            ; ( Hunt
              , [ if_ missed [ sm.set_next Idle ] @@ elif found [ sm.set_next Packet ] []
                ] )
            ; Packet, [ when_ finishes [ sm.set_next Idle ] ]
            ]
        ]);
    { O.bit = { valid = reg spec taken; value = reg spec ~enable:taken decoded }
    ; packet_active = sm.is Packet
    ; sync_seen = reg spec found
    ; packet_end = reg spec finishes
    ; stuff_error = reg spec stuff_error
    ; aligned = reg spec ~enable:finishes (word_bits.:[2, 0] ==:. 0)
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
    H.hierarchical ?instance ~scope ~name:"usb_rx" create i
  ;;
end
