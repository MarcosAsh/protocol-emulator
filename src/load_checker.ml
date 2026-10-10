open! Core
open! Hardcaml
open! Signal
module K = Kernel.Make (Signal)
module Decoder = Decoder.Make (Signal)
module Opcode = Isa.Opcode.Make_comb (Signal)

let data_wait = 4
let aborted = 29
let out_of_order = 30
let left_over = 31
let reason_bits = 5
let count_bits = 8

module Setup = struct
  type 'a t =
    { base : 'a [@bits Isa.data_addr_bits]
    ; loaded : 'a With_valid.t [@bits Isa.data_bits]
    ; floor : 'a
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
    | Check
    | Following
    | Check_next
    | Finish
  [@@deriving sexp_of, compare ~localize, enumerate]
end

(* why a row is being read, which says where the walk goes once it has it *)
module Purpose = struct
  type t =
    | Target
    | Following
    | Stored
    | Fallen
    | Reload
  [@@deriving sexp_of, compare ~localize, enumerate]
end

(* where a checked row's fields come from: the dictionaries, the empty row, or the fall
   through image *)
module Source = struct
  type t =
    | Dictionary
    | Empty
    | Fallen
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let constant_row bits = Kernel.Row.map bits ~f:of_bits

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  (* the rows and words a walk writes before it reads them need no clear *)
  let datapath = Reg_spec.create ~clock:i.clocking.clock () in
  let full = constant_row (Kernel.Table.of_analyser []).(0) in
  let empty = constant_row (Kernel.Table.of_analyser []).(1) in
  let%hw.Always.State_machine sm = Always.State_machine.create (module State) spec in
  let%hw.Always.State_machine purpose =
    Always.State_machine.create (module Purpose) spec
  in
  let%hw.Always.State_machine source = Always.State_machine.create (module Source) spec in
  (* taken as the check begins, so a host writing it mid-walk cannot mix two *)
  let%hw.Setup.Of_signal setup =
    Setup.Of_signal.reg spec ~enable:(sm.is Idle &: i.check) i.setup
  in
  let%hw_var pc = Always.Variable.reg spec ~width:Isa.pc_bits in
  let%hw_var ptr = Always.Variable.reg spec ~width:count_bits in
  let%hw_var count = Always.Variable.reg spec ~width:count_bits in
  let%hw_var wide_count = Always.Variable.reg spec ~width:count_bits in
  let%hw_var word = Always.Variable.reg datapath ~width:Isa.word_bits in
  let%hw_var stored = Always.Variable.reg spec ~width:1 in
  let%hw_var key = Always.Variable.reg spec ~width:Isa.pc_bits in
  let%hw_var lo = Always.Variable.reg spec ~width:count_bits in
  let%hw_var hi = Always.Variable.reg spec ~width:count_bits in
  let%hw_var sel = Always.Variable.reg spec ~width:count_bits in
  let%hw_var entry = Always.Variable.reg datapath ~width:(3 * Isa.data_bits) in
  let%hw_var acc = Always.Variable.reg datapath ~width:48 in
  let%hw_var k = Always.Variable.reg spec ~width:2 in
  let%hw_var field = Always.Variable.reg spec ~width:3 in
  let%hw_var wait = Always.Variable.reg spec ~width:2 in
  let%hw_var finished = Always.Variable.reg spec ~width:1 in
  let%hw_var accepted = Always.Variable.reg spec ~width:1 in
  let%hw_var reject_pc = Always.Variable.reg spec ~width:(Isa.pc_bits + 1) in
  let%hw_var reason = Always.Variable.reg spec ~width:reason_bits in
  let%hw_var data_addr = Always.Variable.wire ~default:(zero Isa.data_addr_bits) () in
  let%hw_var reading = Always.Variable.wire ~default:gnd () in
  (* the row at [pc]; a successor's or a target's is checked a field at a time as it is
     read, and the conjuncts each way fails kept *)
  let row = Kernel.Row.Of_always.reg datapath in
  Kernel.Row.Of_always.apply_names ~prefix:"row$" ~naming_op:(Scope.naming scope) row;
  let failed_next = Kernel.Holds.Of_always.reg datapath in
  let failed_target = Kernel.Holds.Of_always.reg datapath in
  Kernel.Holds.Of_always.apply_names
    ~prefix:"failed_next$"
    ~naming_op:(Scope.naming scope)
    failed_next;
  Kernel.Holds.Of_always.apply_names
    ~prefix:"failed_target$"
    ~naming_op:(Scope.naming scope)
    failed_target;
  let row_value = Kernel.Row.Of_always.value row in
  let config = i.config in
  let side_set_count = config.side_set_count in
  let fraction = config.period_fraction <>:. 0 in
  let capture =
    { Kernel.Capture.pin = uresize config.capture_pin ~width:Isa.Field.wait_index.width
    ; rising = config.capture_rising
    ; single_edge = setup.single_edge
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
  let%hw is_jump = Opcode.is (Decoder.decode ~side_set_count word.value).opcode Jmp in
  (* the field being read: phase and arm are wide, the period, x and y narrow *)
  let unpack_entry bits =
    Load_check.Entry.Of_signal.unpack
      ~rev:true
      (drop_bottom bits ~width:Load_check.unused_bits)
  in
  let%hw.Load_check.Entry.Of_signal held = unpack_entry entry.value in
  (* a row's field as the dictionaries hold it, the low bound above the high *)
  let field_bits (r : _ Kernel.Row.t) =
    mux
      field.value
      [ r.phase_lo @: r.phase_hi
      ; r.arm_lo @: r.arm_hi
      ; uresize (r.period_lo @: r.period_hi) ~width:48
      ; uresize (r.x_lo @: r.x_hi) ~width:48
      ; uresize (r.y_lo @: r.y_hi) ~width:48
      ]
  in
  (* the next row's marks where it falls through, set below from [one_way] *)
  let fell_captured = wire 1 in
  let fell_awaiting = wire 1 in
  (* the field checked, [acc], in every field of a row: a conjunct reads its own fields
     alone, and the offset and slope are the full row's, as in every row the walk holds *)
  let checked =
    let wide_lo = acc.value.:[47, 24] in
    let wide_hi = acc.value.:[23, 0] in
    let narrow_lo = acc.value.:[31, 16] in
    let narrow_hi = acc.value.:[15, 0] in
    let by_source ~dictionary ~fallen =
      mux2 (source.is Dictionary) dictionary (source.is Fallen &: fallen)
    in
    let%hw checked_captured = by_source ~dictionary:held.captured ~fallen:fell_captured in
    let%hw checked_awaiting = by_source ~dictionary:held.awaiting ~fallen:fell_awaiting in
    { full with
      phase_lo = wide_lo
    ; phase_hi = wide_hi
    ; arm_lo = wide_lo
    ; arm_hi = wide_hi
    ; period_lo = narrow_lo
    ; period_hi = narrow_hi
    ; x_lo = narrow_lo
    ; x_hi = narrow_hi
    ; y_lo = narrow_lo
    ; y_hi = narrow_hi
    ; captured = checked_captured
    ; awaiting = checked_awaiting
    }
  in
  let conjuncts, fallen, falls =
    K.one_way
      ~side_set_count
      ~fraction
      ~loaded:setup.loaded
      ~capture
      ~word:word.value
      ~row:row_value
      ~taken:(purpose.is Target)
      checked
  in
  (* the row the next pc's is where it falls through with none stored *)
  let%hw.Kernel.Row.Of_signal fell = Kernel.Row.map2 fallen empty ~f:(mux2 falls) in
  fell_captured <-- fell.captured;
  fell_awaiting <-- fell.awaiting;
  (* the way being checked; the other way holds *)
  let%hw.Kernel.Holds.Of_signal way =
    Kernel.Holds.map2 conjuncts.next conjuncts.target ~f:( &: )
  in
  (* the first conjunct that fails, by its index in [Conjuncts.to_list] *)
  let first_failing holds =
    priority_select_with_default
      (List.map holds ~f:(fun (index, h) ->
         { With_valid.valid = ~:h; value = of_unsigned_int ~width:reason_bits index }))
      ~default:(zero reason_bits)
  in
  (* the conjuncts as checked, split into those on the next row and those on the target,
     each kept at its place in the list so the indices stay [Conjuncts.to_list]'s *)
  let indexed (c : Signal.t Kernel.Conjuncts.t) =
    List.mapi (Kernel.Conjuncts.to_list c) ~f:(fun n h -> n, h)
  in
  let holding = Kernel.Holds.map ~f:(fun _ -> vdd) in
  let passed failed = Kernel.Holds.map failed ~f:( ~: ) in
  let in_time_and_next =
    indexed
      { conjuncts with
        next = passed (Kernel.Holds.Of_always.value failed_next)
      ; target = holding conjuncts.target
      }
  in
  let target_holds =
    indexed
      { in_time = vdd
      ; wide_a = vdd
      ; wide_b = vdd
      ; next = holding conjuncts.next
      ; target = passed (Kernel.Holds.Of_always.value failed_target)
      }
  in
  let%hw next_fails = ~:(List.map in_time_and_next ~f:snd |> List.reduce_exn ~f:( &: )) in
  let%hw next_reason = first_failing in_time_and_next in
  let%hw target_fails = ~:(List.map target_holds ~f:snd |> List.reduce_exn ~f:( &: )) in
  let%hw target_reason = first_failing target_holds in
  (* the field's value from a source other than the dictionaries, or the whole range for
     an index of 0 *)
  let%hw stand_in =
    mux2 (source.is Dictionary) (field_bits full)
    @@ mux2 (source.is Fallen) (field_bits fell) (field_bits empty)
  in
  (* the certificate's layout from [base]: two header words, the entries, the dictionaries *)
  let address offset = uresize offset ~width:Isa.data_addr_bits in
  let times3 x =
    let x = address x in
    x +: sll x ~by:1
  in
  let%hw entries_at = setup.base +:. 2 in
  let%hw wide_at = entries_at +: times3 count.value in
  let%hw narrow_at = wide_at +: times3 wide_count.value in
  let entry_at n = entries_at +: times3 n +: uresize k.value ~width:Isa.data_addr_bits in
  (* an entry's pc, the top of its first word *)
  let%hw entry_tag = sel_top i.data_word ~width:Isa.pc_bits in
  let%hw mid =
    srl
      (uresize lo.value ~width:(count_bits + 1) +: uresize hi.value ~width:(count_bits + 1)
      )
      ~by:1
    |> sel_bottom ~width:count_bits
  in
  let%hw read_done = wait.value ==:. data_wait - 1 in
  let%hw index = mux field.value [ held.phase; held.arm; held.period; held.x; held.y ] in
  let%hw wide = field.value <:. 2 in
  let%hw last_word = mux2 wide (k.value ==:. 2) (k.value ==:. 1) in
  let%hw from_dictionary = source.is Dictionary &: (index <>:. 0) in
  let%hw interval_at =
    mux2
      wide
      (wide_at +: times3 (index -:. 1))
      (narrow_at +: address (sll (uresize (index -:. 1) ~width:Isa.data_addr_bits) ~by:1))
    +: uresize k.value ~width:Isa.data_addr_bits
  in
  let%hw shifted = sel_bottom acc.value ~width:32 @: i.data_word in
  let%hw entry_shifted = sel_bottom entry.value ~width:32 @: i.data_word in
  let%hw.Load_check.Entry.Of_signal arriving = unpack_entry entry_shifted in
  (* a reloaded row's field, from the dictionary word just read *)
  let set_field =
    let narrow_lo = shifted.:[31, 16] in
    let narrow_hi = shifted.:[15, 0] in
    let wide_lo = shifted.:[47, 24] in
    let wide_hi = shifted.:[23, 0] in
    Always.(
      switch
        field.value
        [ ( of_unsigned_int ~width:3 0
          , [ row.phase_lo <-- wide_lo; row.phase_hi <-- wide_hi ] )
        ; of_unsigned_int ~width:3 1, [ row.arm_lo <-- wide_lo; row.arm_hi <-- wide_hi ]
        ; ( of_unsigned_int ~width:3 2
          , [ row.period_lo <-- narrow_lo; row.period_hi <-- narrow_hi ] )
        ; of_unsigned_int ~width:3 3, [ row.x_lo <-- narrow_lo; row.x_hi <-- narrow_hi ]
        ; of_unsigned_int ~width:3 4, [ row.y_lo <-- narrow_lo; row.y_hi <-- narrow_hi ]
        ])
  in
  (* the field just checked, and with the last field the conjuncts on no interval *)
  let record (failed : Always.Variable.t Kernel.Holds.t) =
    let fails = Kernel.Holds.map2 failed way ~f:(fun f h -> Always.(f <-- ~:h)) in
    Always.(
      switch
        field.value
        [ of_unsigned_int ~width:3 0, [ fails.phase ]
        ; of_unsigned_int ~width:3 1, [ fails.arm ]
        ; of_unsigned_int ~width:3 2, [ fails.period ]
        ; of_unsigned_int ~width:3 3, [ fails.x ]
        ; ( of_unsigned_int ~width:3 4
          , [ fails.y
            ; fails.offset
            ; fails.captured
            ; fails.awaiting
            ; fails.edge_a
            ; fails.edge_b
            ] )
        ])
  in
  let check_fields ~from =
    Always.[ source.set_next from; field <-- zero 3; k <-- zero 2; sm.set_next Field ]
  in
  (* every conjunct holds into the full row at pc 0, so it goes straight on to [then_]:
     [purpose] is set in the same cycle *)
  let start_lookup target ~then_ =
    Always.
      [ key <-- target
      ; if_
          (target ==:. 0)
          [ sm.set_next then_ ]
          [ lo <-- zero count_bits; hi <-- count.value; sm.set_next Search ]
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
      ; if_
          (pc.value ==:. (1 lsl Isa.pc_bits) - 1)
          [ sm.set_next Finish ]
          [ pc <-- sel_bottom next_pc ~width:Isa.pc_bits; k <-- zero 2; sm.set_next Word ]
      ]
  in
  (* where a walk goes once it has a row for [purpose] *)
  let after_row =
    purpose.switch
      [ Target, [ sm.set_next Following ]
      ; Following, [ sm.set_next Check_next ]
      ; Stored, [ sm.set_next Check_next ]
      ; Fallen, [ sm.set_next Check_next ]
      ; Reload, next_pc_or_finish
      ]
  in
  let read addr = Always.[ reading <-- vdd; data_addr <-- addr ] in
  let read_entry n = Always.[ sel <-- n; k <-- zero 2; sm.set_next Entry ] in
  let pass (failed : Always.Variable.t Kernel.Holds.t) =
    Kernel.Holds.to_list failed |> List.map ~f:(fun f -> Always.(f <-- gnd))
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
                  ; Kernel.Row.Of_always.assign row full
                  ; sm.set_next Header
                  ]
              ] )
          ; ( Header
            , read (setup.base +: uresize k.value ~width:Isa.data_addr_bits)
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
                  ([ word <-- i.program_word; k <-- zero 2; sm.set_next Head ]
                   @ pass failed_next
                   @ pass failed_target)
              ] )
          ; ( Head
            , [ if_
                  (ptr.value <: count.value)
                  (read (entry_at ptr.value)
                   @ [ when_
                         read_done
                         [ stored
                           <-- (uresize entry_tag ~width:(Isa.pc_bits + 1) ==: next_pc)
                         ; if_
                             (entry_tag <=: pc.value)
                             (reject
                                ~at:(uresize pc.value ~width:(Isa.pc_bits + 1))
                                (of_unsigned_int ~width:reason_bits out_of_order))
                             [ sm.set_next Target ]
                         ]
                     ])
                  [ stored <-- gnd; sm.set_next Target ]
              ] )
          ; ( Target
            , [ if_
                  is_jump
                  (purpose.set_next Target :: start_lookup jump_target ~then_:Following)
                  [ sm.set_next Following ]
              ] )
          ; ( Search
            , [ if_
                  (lo.value >=: hi.value)
                  (check_fields ~from:Empty)
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
                        (when_
                           (purpose.is Reload)
                           [ Kernel.Row.Of_always.assign
                               row
                               { full with
                                 captured = arriving.captured
                               ; awaiting = arriving.awaiting
                               }
                           ]
                         :: check_fields ~from:Dictionary)
                    ]
                ] )
          ; ( Field
            , [ if_
                  (field.value ==:. 5)
                  [ after_row ]
                  [ if_
                      from_dictionary
                      (read interval_at
                       @ [ when_
                             read_done
                             [ acc <-- shifted
                             ; k <-- k.value +:. 1
                             ; when_
                                 last_word
                                 [ k <-- zero 2
                                 ; if_
                                     (purpose.is Reload)
                                     [ set_field; field <-- field.value +:. 1 ]
                                     [ sm.set_next Check ]
                                 ]
                             ]
                         ])
                      [ if_
                          (purpose.is Reload)
                          [ field <-- field.value +:. 1 ]
                          [ acc <-- stand_in; sm.set_next Check ]
                      ]
                  ]
              ] )
          ; ( Check
            , [ if_ (purpose.is Target) [ record failed_target ] [ record failed_next ]
              ; field <-- field.value +:. 1
              ; if_ (field.value ==:. 4) [ after_row ] [ sm.set_next Field ]
              ] )
          ; ( Following
            , [ if_
                  falls_to_next
                  [ if_
                      stored.value
                      (purpose.set_next Stored :: read_entry ptr.value)
                      (purpose.set_next Fallen :: check_fields ~from:Fallen)
                  ]
                  (purpose.set_next Following :: start_lookup following ~then_:Check_next)
              ] )
          ; ( Check_next
            , [ if_
                  next_fails
                  (reject ~at:(uresize pc.value ~width:(Isa.pc_bits + 1)) next_reason)
                  [ if_
                      target_fails
                      (reject
                         ~at:(uresize pc.value ~width:(Isa.pc_bits + 1))
                         target_reason)
                      [ if_
                          stored.value
                          (purpose.set_next Reload :: read_entry ptr.value)
                          (Kernel.Row.Of_always.assign
                             row
                             (Kernel.Row.map2 fell empty ~f:(mux2 falls_to_next))
                           :: next_pc_or_finish)
                      ]
                  ]
              ] )
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
  (* registered, so the walk's address arithmetic ends at a flop and not at the memory *)
  let%hw read_valid = reg spec reading.value in
  let%hw read_at = reg spec data_addr.value in
  { O.program_read = { valid = sm.is Word; value = pc.value }
  ; data_read = { valid = read_valid; value = read_at }
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
