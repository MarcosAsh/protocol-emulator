open! Core
open! Hardcaml
open! Signal
module K = Kernel.Make (Signal)
module Decoder = Decoder.Make (Signal)
module Opcode = Isa.Opcode.Make_comb (Signal)

let data_wait = 3
let aborted = 29
let out_of_order = 30
let left_over = 31
let reason_bits = 5
let count_bits = 8

module Setup = struct
  type 'a t =
    { base : 'a [@bits Isa.data_addr_bits]
    ; loaded : 'a With_valid.t [@bits Isa.data_bits]
    ; single_edge : 'a
    }
  [@@deriving hardcaml]
end

module Verdict = struct
  type 'a t =
    { busy : 'a
    ; accepted : 'a
    ; reject_pc : 'a [@bits Isa.pc_bits + 1]
    ; reason : 'a [@bits reason_bits]
    }
  [@@deriving hardcaml]
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; check : 'a
    ; abort : 'a
    ; config : 'a Engine.Config.t
    ; setup : 'a Setup.t
    ; program_word : 'a [@bits Isa.word_bits]
    ; data_word : 'a [@bits Isa.data_bits]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { program_read : 'a With_valid.t [@bits Isa.pc_bits]
    ; data_read : 'a With_valid.t [@bits Isa.data_addr_bits]
    ; busy : 'a
    ; finished : 'a
    ; accepted : 'a
    ; reject_pc : 'a [@bits Isa.pc_bits + 1]
    ; reason : 'a [@bits reason_bits]
    }
  [@@deriving hardcaml]
end

module State = struct
  type t =
    | Idle
    | Header
    | Word
    | Head
    | Target
    | Search
    | Entry
    | Field
    | Check_target
    | Following
    | Check_next
    | Advance
    | Reload
    | Finish
  [@@deriving sexp_of, compare ~localize, enumerate]
end

(* why a row is being read, which says where the walk goes once it has it *)
module Purpose = struct
  type t =
    | Target
    | Following
    | Stored
    | Reload
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let constant_row bits = Kernel.Row.map bits ~f:of_bits

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let full = constant_row (Kernel.Table.of_analyser []).(0) in
  let empty = constant_row (Kernel.Table.of_analyser []).(1) in
  let%hw.Always.State_machine sm = Always.State_machine.create (module State) spec in
  let%hw.Always.State_machine purpose =
    Always.State_machine.create (module Purpose) spec
  in
  let%hw_var pc = Always.Variable.reg spec ~width:Isa.pc_bits in
  let%hw_var ptr = Always.Variable.reg spec ~width:count_bits in
  let%hw_var count = Always.Variable.reg spec ~width:count_bits in
  let%hw_var wide_count = Always.Variable.reg spec ~width:count_bits in
  let%hw_var word = Always.Variable.reg spec ~width:Isa.word_bits in
  let%hw_var stored = Always.Variable.reg spec ~width:1 in
  let%hw_var key = Always.Variable.reg spec ~width:Isa.pc_bits in
  let%hw_var lo = Always.Variable.reg spec ~width:count_bits in
  let%hw_var hi = Always.Variable.reg spec ~width:count_bits in
  let%hw_var sel = Always.Variable.reg spec ~width:count_bits in
  let%hw_var entry = Always.Variable.reg spec ~width:48 in
  let%hw_var acc = Always.Variable.reg spec ~width:48 in
  let%hw_var k = Always.Variable.reg spec ~width:2 in
  let%hw_var field = Always.Variable.reg spec ~width:3 in
  let%hw_var wait = Always.Variable.reg spec ~width:2 in
  let%hw_var target_fails = Always.Variable.reg spec ~width:1 in
  let%hw_var target_reason = Always.Variable.reg spec ~width:reason_bits in
  let%hw_var finished = Always.Variable.reg spec ~width:1 in
  let%hw_var accepted = Always.Variable.reg spec ~width:1 in
  let%hw_var reject_pc = Always.Variable.reg spec ~width:(Isa.pc_bits + 1) in
  let%hw_var reason = Always.Variable.reg spec ~width:reason_bits in
  let%hw_var data_addr = Always.Variable.wire ~default:(zero Isa.data_addr_bits) () in
  let%hw_var reading = Always.Variable.wire ~default:gnd () in
  let row = Kernel.Row.Of_always.reg spec in
  let other = Kernel.Row.Of_always.reg spec in
  let row_value = Kernel.Row.Of_always.value row in
  let other_value = Kernel.Row.Of_always.value other in
  let config = i.config in
  let side_set_count = config.side_set_count in
  let fraction = config.period_fraction <>:. 0 in
  let capture =
    { Kernel.Capture.pin = uresize config.capture_pin ~width:Isa.Field.wait_index.width
    ; rising = config.capture_rising
    ; single_edge = i.setup.single_edge
    }
  in
  let%hw following, jump_target =
    K.successors
      ~wrap_top:config.wrap_top
      ~wrap_bottom:config.wrap_bottom
      ~pc:pc.value
      ~word:word.value
  in
  (* one bit wider, so pc 511's way out never reads as falling through *)
  let%hw next_pc = uresize pc.value ~width:(Isa.pc_bits + 1) +:. 1 in
  let%hw falls_to_next = uresize following ~width:(Isa.pc_bits + 1) ==: next_pc in
  let%hw is_jump =
    Opcode.is (Decoder.decode ~side_set_count word.value).opcode Jmp
  in
  let conjuncts =
    K.conjuncts
      ~side_set_count
      ~fraction
      ~loaded:i.setup.loaded
      ~capture
      ~spacing:K.no_spacing
      ~word:word.value
      ~row:row_value
      ~next:other_value
      ~target:other_value
  in
  let fallen, falls =
    K.fall_through
      ~side_set_count
      ~fraction
      ~loaded:i.setup.loaded
      ~capture
      ~word:word.value
      ~row:row_value
  in
  (* the first conjunct that fails, by its index in [Conjuncts.to_list] *)
  let first_failing holds =
    priority_select_with_default
      (List.map holds ~f:(fun (index, h) ->
         { With_valid.valid = ~:h; value = of_unsigned_int ~width:reason_bits index }))
      ~default:(zero reason_bits)
  in
  let indexed = List.mapi (Kernel.Conjuncts.to_list conjuncts) ~f:(fun n h -> n, h) in
  let in_time_and_next, target_holds =
    List.partition_tf indexed ~f:(fun (n, _) -> n < 3 + 10)
  in
  let%hw next_fails =
    ~:(List.map in_time_and_next ~f:snd |> List.reduce_exn ~f:( &: ))
  in
  let%hw next_reason = first_failing in_time_and_next in
  let%hw target_fails_now = ~:(List.map target_holds ~f:snd |> List.reduce_exn ~f:( &: )) in
  let%hw target_reason_now = first_failing target_holds in
  (* the certificate's layout from [base]: two header words, the entries, the dictionaries *)
  let address offset = uresize offset ~width:Isa.data_addr_bits in
  let times3 x = uresize x ~width:Isa.data_addr_bits *: of_unsigned_int ~width:2 3 |> address in
  let%hw entries_at = i.setup.base +:. 2 in
  let%hw wide_at = entries_at +: times3 count.value in
  let%hw narrow_at = wide_at +: times3 wide_count.value in
  let entry_at n = entries_at +: times3 n +: uresize k.value ~width:Isa.data_addr_bits in
  let%hw entry_tag = i.data_word.:[15, 7] in
  let%hw mid = srl (uresize lo.value ~width:(count_bits + 1) +: uresize hi.value ~width:(count_bits + 1)) ~by:1 |> sel_bottom ~width:count_bits in
  let%hw read_done = wait.value ==:. data_wait - 1 in
  (* the field being read: phase and arm are wide, the period, x and y narrow *)
  let%hw index =
    mux
      field.value
      [ entry.value.:[36, 30]
      ; entry.value.:[29, 23]
      ; entry.value.:[22, 16]
      ; entry.value.:[15, 9]
      ; entry.value.:[8, 2]
      ]
  in
  let%hw wide = field.value <:. 2 in
  let%hw last_word = mux2 wide (k.value ==:. 2) (k.value ==:. 1) in
  let%hw interval_at =
    mux2
      wide
      (wide_at +: times3 (index -:. 1))
      (narrow_at +: address (sll (uresize (index -:. 1) ~width:Isa.data_addr_bits) ~by:1))
    +: uresize k.value ~width:Isa.data_addr_bits
  in
  let%hw shifted = sel_bottom acc.value ~width:32 @: i.data_word in
  let%hw entry_shifted = sel_bottom entry.value ~width:32 @: i.data_word in
  let set_field =
    let narrow_lo = shifted.:[31, 16] in
    let narrow_hi = shifted.:[15, 0] in
    let wide_lo = shifted.:[47, 24] in
    let wide_hi = shifted.:[23, 0] in
    Always.(
      switch
        field.value
        [ ( of_unsigned_int ~width:3 0
          , [ other.phase_lo <-- wide_lo; other.phase_hi <-- wide_hi ] )
        ; of_unsigned_int ~width:3 1, [ other.arm_lo <-- wide_lo; other.arm_hi <-- wide_hi ]
        ; ( of_unsigned_int ~width:3 2
          , [ other.period_lo <-- narrow_lo; other.period_hi <-- narrow_hi ] )
        ; of_unsigned_int ~width:3 3, [ other.x_lo <-- narrow_lo; other.x_hi <-- narrow_hi ]
        ; of_unsigned_int ~width:3 4, [ other.y_lo <-- narrow_lo; other.y_hi <-- narrow_hi ]
        ])
  in
  (* [purpose] is set in the same cycle, so the full row at pc 0 goes on to [then_] *)
  let start_lookup target ~then_ =
    Always.
      [ key <-- target
      ; if_
          (target ==:. 0)
          [ Kernel.Row.Of_always.assign other full; sm.set_next then_ ]
          [ lo <-- zero count_bits; hi <-- count.value; sm.set_next Search ]
      ]
  in
  (* where a row read for [purpose] goes *)
  let after_row =
    purpose.switch
      [ Target, [ sm.set_next Check_target ]
      ; Following, [ sm.set_next Check_next ]
      ; Stored, [ sm.set_next Check_next ]
      ; Reload, [ sm.set_next Reload ]
      ]
  in
  let reject ~at why =
    Always.
      [ finished <-- vdd
      ; accepted <-- gnd
      ; reject_pc <-- at
      ; reason <-- why
      ; sm.set_next Idle
      ]
  in
  let next_pc_or_finish =
    Always.
      [ ptr <-- ptr.value +: uresize stored.value ~width:count_bits
      ; target_fails <-- gnd
      ; if_
          (pc.value ==:. (1 lsl Isa.pc_bits) - 1)
          [ sm.set_next Finish ]
          [ pc <-- sel_bottom next_pc ~width:Isa.pc_bits; k <-- zero 2; sm.set_next Word ]
      ]
  in
  let read addr = Always.[ reading <-- vdd; data_addr <-- addr ] in
  let read_entry n =
    Always.[ sel <-- n; k <-- zero 2; sm.set_next Entry ]
  in
  Always.(
    compile
      [ wait <-- mux2 (reading.value &: ~:read_done) (wait.value +:. 1) (zero 2)
      ; finished <-- gnd
      ; sm.switch
          [ ( Idle
            , [ when_
                  i.check
                  [ pc <-- zero Isa.pc_bits
                  ; ptr <-- zero count_bits
                  ; k <-- zero 2
                  ; target_fails <-- gnd
                  ; Kernel.Row.Of_always.assign row full
                  ; sm.set_next Header
                  ]
              ] )
          ; ( Header
            , read (i.setup.base +: uresize k.value ~width:Isa.data_addr_bits)
              @ [ when_
                    read_done
                    [ if_
                        (k.value ==:. 0)
                        [ count <-- sel_bottom i.data_word ~width:count_bits ]
                        [ wide_count <-- sel_bottom i.data_word ~width:count_bits ]
                    ; k <-- k.value +:. 1
                    ; when_ (k.value ==:. 1) [ k <-- zero 2; sm.set_next Word ]
                    ]
                ] )
          ; ( Word
            , [ k <-- k.value +:. 1
              ; when_
                  (k.value ==:. 1)
                  [ word <-- i.program_word; k <-- zero 2; sm.set_next Head ]
              ] )
          ; ( Head
            , [ if_
                  (ptr.value <: count.value)
                  (read (entry_at ptr.value)
                   @ [ when_
                         read_done
                         [ stored <-- (uresize entry_tag ~width:(Isa.pc_bits + 1) ==: next_pc)
                         ; if_
                             (entry_tag <=: pc.value)
                             (reject ~at:(uresize pc.value ~width:(Isa.pc_bits + 1)) (of_unsigned_int ~width:reason_bits out_of_order))
                             [ sm.set_next Target ]
                         ]
                     ])
                  [ stored <-- gnd; sm.set_next Target ]
              ] )
          ; ( Target
            , [ if_
                  is_jump
                  (purpose.set_next Target :: start_lookup jump_target ~then_:Check_target)
                  [ sm.set_next Following ]
              ] )
          ; ( Search
            , [ if_
                  (lo.value >=: hi.value)
                  [ Kernel.Row.Of_always.assign other empty; after_row ]
                  (read (entries_at +: times3 mid)
                   @ [ when_
                         read_done
                         [ if_
                             (entry_tag ==: key.value)
                             (read_entry mid)
                             [ if_
                                 (entry_tag <: key.value)
                                 [ lo <-- mid +:. 1 ]
                                 [ hi <-- mid ]
                             ]
                         ]
                     ])
              ] )
          ; ( Entry
            , read (entry_at sel.value)
              @ [ when_
                    read_done
                    [ entry <-- entry_shifted
                    ; k <-- k.value +:. 1
                    ; when_
                        (k.value ==:. 2)
                        [ Kernel.Row.Of_always.assign
                            other
                            { full with
                              captured = entry_shifted.:(38)
                            ; awaiting = entry_shifted.:(37)
                            }
                        ; k <-- zero 2
                        ; field <-- zero 3
                        ; sm.set_next Field
                        ]
                    ]
                ] )
          ; ( Field
            , [ if_
                  (field.value ==:. 5)
                  [ after_row ]
                  [ if_
                      (index ==:. 0)
                      [ field <-- field.value +:. 1 ]
                      (read interval_at
                       @ [ when_
                             read_done
                             [ acc <-- shifted
                             ; k <-- k.value +:. 1
                             ; when_
                                 last_word
                                 [ set_field
                                 ; k <-- zero 2
                                 ; field <-- field.value +:. 1
                                 ]
                             ]
                         ])
                  ]
              ] )
          ; ( Check_target
            , [ target_fails <-- target_fails_now
              ; target_reason <-- target_reason_now
              ; sm.set_next Following
              ] )
          ; ( Following
            , [ if_
                  falls_to_next
                  [ if_
                      stored.value
                      (purpose.set_next Stored :: read_entry ptr.value)
                      [ Kernel.Row.Of_always.assign other (Kernel.Row.map2 fallen empty ~f:(mux2 falls))
                      ; sm.set_next Check_next
                      ]
                  ]
                  (purpose.set_next Following :: start_lookup following ~then_:Check_next)
              ] )
          ; ( Check_next
            , [ if_
                  next_fails
                  (reject ~at:(uresize pc.value ~width:(Isa.pc_bits + 1)) next_reason)
                  [ if_
                      target_fails.value
                      (reject ~at:(uresize pc.value ~width:(Isa.pc_bits + 1)) target_reason.value)
                      [ sm.set_next Advance ]
                  ]
              ] )
          ; ( Advance
            , [ if_
                  falls_to_next
                  (Kernel.Row.Of_always.assign row other_value :: next_pc_or_finish)
                  [ if_
                      stored.value
                      (purpose.set_next Reload :: read_entry ptr.value)
                      (Kernel.Row.Of_always.assign row empty :: next_pc_or_finish)
                  ]
              ] )
          ; Reload, Kernel.Row.Of_always.assign row other_value :: next_pc_or_finish
          ; ( Finish
            , [ if_
                  (ptr.value ==: count.value)
                  [ finished <-- vdd; accepted <-- vdd; sm.set_next Idle ]
                  (reject
                     ~at:(of_unsigned_int ~width:(Isa.pc_bits + 1) (1 lsl Isa.pc_bits))
                     (of_unsigned_int ~width:reason_bits left_over))
              ] )
          ]
        (* last, so it wins over the state's own assignments *)
      ; when_
          (i.abort &: ~:(sm.is Idle))
          (reject
             ~at:(uresize pc.value ~width:(Isa.pc_bits + 1))
             (of_unsigned_int ~width:reason_bits aborted))
      ]);
  { O.program_read = { valid = sm.is Word; value = pc.value }
  ; data_read = { valid = reading.value; value = data_addr.value }
  ; busy = ~:(sm.is Idle)
  ; finished = finished.value
  ; accepted = accepted.value
  ; reject_pc = reject_pc.value
  ; reason = reason.value
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"load_checker" create i
;;
