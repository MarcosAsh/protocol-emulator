open! Core
open! Hardcaml
open! Signal

let position_bits = 14

(* the 16 bits a stamp keeps *)
let watch_from = Self_check_monitor.watch_from
let stamp_bits = 16

module type Config = sig
  val max_inner : int
end

module Make (Config : Config) = struct
  let count_bits = Int.ceil_log2 (Config.max_inner + 1)

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; line : 'a
      ; inner : 'a list [@length Config.max_inner] [@bits position_bits]
      ; count : 'a [@bits count_bits]
      ; least : 'a [@bits position_bits]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { violated : 'a
      ; overdue : 'a
      ; ended : 'a [@bits 2]
      ; late : 'a
      }
    [@@deriving hardcaml]
  end

  module State = struct
    type t =
      | Boot
      | Wait_high
      | Seek
      | Frame
      | Doomed
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  (* A frame starts at the first low from the last's least, the first once the line is
     high from [watch_from]. A move off its edges, or a low at its last, is a break, due
     by the cycle before the least if five or more before it, else ten after the next
     start. Blind where the reference is: from a fall [2^16 k] after a fall at
     [watch_from], and a lone break before a high least with the next start [2^16 k] on. *)
  let create (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let open Always in
    let%hw.Always.State_machine sm = State_machine.create (module State) spec in
    let%hw_var boot = Variable.reg spec ~width:(Int.ceil_log2 (watch_from + 1)) in
    let%hw_var stale = Variable.reg spec ~width:1 in
    let%hw_var ended = Variable.reg spec ~width:2 in
    let%hw_var blind = Variable.reg spec ~width:1 in
    let%hw_var early = Variable.reg spec ~width:1 in
    let%hw_var at_last = Variable.reg spec ~width:1 in
    let%hw_var fresh = Variable.reg spec ~width:1 in
    let%hw_var least_high = Variable.reg spec ~width:1 in
    let%hw_var position = Variable.reg spec ~width:position_bits in
    let%hw_var left = Variable.reg spec ~width:position_bits in
    let%hw_var watch = Variable.reg spec ~width:stamp_bits in
    let%hw_var idle = Variable.reg spec ~width:stamp_bits in
    let%hw_var violated = Variable.reg spec ~width:1 in
    let%hw_var late = Variable.reg spec ~width:1 in
    let%hw previous = reg spec i.line in
    let%hw moved = i.line ^: previous in
    let%hw fell = moved &: ~:(i.line) in
    let%hw hit =
      List.mapi i.inner ~f:(fun n edge -> (edge ==: position.value) &: (i.count >:. n))
      |> reduce ~f:( |: )
    in
    let%hw last = mux (i.count -:. 1) i.inner in
    let%hw off_edge = moved &: ~:hit in
    let%hw ends_low = (position.value ==: last) &: ~:(i.line) in
    let%hw broke = off_edge |: ends_low in
    let%hw blind_now =
      blind.value |: ((ended.value ==:. 0) &: stale.value &: (watch.value ==:. 0) &: fell)
    in
    let%hw final = position.value ==: (i.least -:. 1) in
    let%hw in_time = position.value <=: (i.least -:. 5) in
    let%hw aliased =
      at_last.value
      &: ~:(early.value)
      &: ~:(fresh.value)
      &: least_high.value
      &: (idle.value ==:. 0)
    in
    let%hw due_later = early.value |: (at_last.value &: ~:aliased) in
    compile
      [ watch <-- watch.value +:. 1
      ; idle <-- idle.value +:. 1
      ; sm.switch
          [ ( Boot
            , [ boot <-- boot.value +:. 1
              ; watch <--. 0
              ; when_
                  (boot.value ==:. watch_from)
                  [ stale <-- (previous &: ~:(i.line))
                  ; watch <--. 1
                  ; if_ i.line [ sm.set_next Seek ] [ sm.set_next Wait_high ]
                  ]
              ] )
          ; Wait_high, [ when_ i.line [ sm.set_next Seek ] ]
          ; ( Seek
            , [ fresh <--. 0
              ; when_ fresh.value [ least_high <-- i.line ]
              ; when_
                  ~:(i.line)
                  [ if_
                      due_later
                      [ left <--. 10; late <--. 1; sm.set_next Doomed ]
                      [ position <--. 1
                      ; blind <--. 0
                      ; early <--. 0
                      ; at_last <--. 0
                      ; sm.set_next Frame
                      ]
                  ]
              ] )
          ; ( Frame
            , [ position <-- position.value +:. 1
              ; blind <-- blind_now
              ; when_
                  final
                  [ ended <-- mux2 (ended.value ==:. 3) ended.value (ended.value +:. 1)
                  ; fresh <--. 1
                  ; idle <--. 1
                  ; sm.set_next Seek
                  ]
              ; when_
                  broke
                  [ violated <--. 1
                  ; unless
                      blind_now
                      [ if_
                          in_time
                          [ left <-- (i.least -: position.value) -:. 1; sm.set_next Doomed ]
                          [ if_ final [ at_last <--. 1 ] [ early <--. 1 ] ]
                      ]
                  ]
              ] )
          ; Doomed, [ when_ (left.value <>:. 0) [ left <-- left.value -:. 1 ] ]
          ]
      ];
    { O.violated = violated.value
    ; overdue = sm.is Doomed &: (left.value ==:. 0)
    ; ended = ended.value
    ; late = late.value
    }
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"self_check_contract" create i
  ;;
end
