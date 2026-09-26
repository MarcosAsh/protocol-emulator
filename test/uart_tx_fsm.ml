open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val clocks_per_bit : int
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; data_in : 'a [@bits 8]
    ; data_in_valid : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { txd : 'a } [@@deriving hardcaml]
end

module State = struct
  type t =
    | Start
    | Data
    | Stop
    | Complete
  [@@deriving sexp_of, compare ~localize, enumerate]
end

module Make (Config : Config) = struct
  let log_clocks_per_bit = Int.ceil_log2 (Config.clocks_per_bit + 1)

  let create scope (i : _ I.t) =
    let spec = Clocking.to_spec i.clocking in
    let%hw.Always.State_machine sm_tx = Always.State_machine.create (module State) spec in
    let%hw_var txd = Always.Variable.reg spec ~width:1 ~clear_to:vdd in
    let%hw_var data_count = Always.Variable.reg spec ~width:3 in
    let%hw_var txdata = Always.Variable.reg spec ~width:8 in
    let%hw_var enable_rate = Always.Variable.reg spec ~width:log_clocks_per_bit in
    let%hw enable_rate_next = enable_rate.value +:. 1 in
    let%hw_var enable = Always.Variable.wire ~default:gnd () in
    let enabled l = Always.[ when_ enable.value l ] in
    Always.(
      compile
        [ enable_rate <-- enable_rate_next
        ; when_
            (enable_rate_next ==:. Config.clocks_per_bit)
            [ enable_rate <--. 0; enable <-- vdd ]
        ; sm_tx.switch
            [ ( Start
              , [ data_count <--. 0
                ; txdata <-- i.data_in
                ; enable_rate <--. 0
                ; when_ i.data_in_valid [ txd <-- gnd; sm_tx.set_next Data ]
                ] )
            ; ( Data
              , enabled
                  [ data_count <-- data_count.value +:. 1
                  ; txdata <-- srl txdata.value ~by:1
                  ; txd <-- txdata.value.:(0)
                  ; when_ (data_count.value ==:. 7) [ sm_tx.set_next Stop ]
                  ] )
            ; Stop, enabled [ txd <-- vdd; sm_tx.set_next Complete ]
            ; Complete, enabled [ sm_tx.set_next Start ]
            ]
        ]);
    { O.txd = txd.value }
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"uart_tx_fsm" create i
  ;;
end
