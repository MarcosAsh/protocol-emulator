open Base
open! Hardcaml
open Signal
open Uart_types

let log_clocks_per_bit = 16

module Config = struct
  type 'a t =
    { data_bits : 'a Data_bits.Enum.t
    ; parity : 'a Parity.Enum.t
    ; stop_bits : 'a Stop_bits.Enum.t
    ; clocks_per_bit : 'a [@bits log_clocks_per_bit]
    }
  [@@deriving hardcaml ~rtlmangle:"$"]

  let data_count_max config =
    Data_bits.Enum.Of_signal.match_
      ~default:(of_int_trunc ~width:4 5)
      config.data_bits
      (Data_bits.Cases.all
       |> List.mapi ~f:(fun i v -> v, of_int_trunc ~width:4 (i + 5 - 1)))
  ;;
end

module Tx = struct
  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; config : 'a Config.t
      ; data_in : 'a [@bits 9]
      ; data_in_valid : 'a
      }
    [@@deriving hardcaml ~rtlmangle:false]
  end

  module O = struct
    type 'a t =
      { txd : 'a
      ; data_in_ready : 'a
      }
    [@@deriving hardcaml]
  end

  module State = struct
    type t =
      | Start
      | Data
      | Parity
      | Stop
      | Complete
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  open Signal

  let create scope (i : _ I.t) =
    let spec = Clocking.to_spec i.clocking in
    let%hw.Always.State_machine sm_tx = Always.State_machine.create (module State) spec in
    let txd = Always.Variable.reg spec ~width:1 ~clear_to:vdd in
    let data_in_ready = Always.Variable.reg spec ~clear_to:vdd ~width:1 in
    let%hw_var data_count = Always.Variable.reg spec ~width:4 in
    let data_count_max = Config.data_count_max i.config in
    let txdata = Always.Variable.reg spec ~width:9 in
    let stop_count = Always.Variable.reg spec ~width:1 in
    let parity = Always.Variable.reg spec ~width:1 in
    let%hw_var enable_rate = Always.Variable.reg spec ~width:log_clocks_per_bit in
    let enable_rate_next = enable_rate.value +:. 1 in
    let%hw_var enable = Always.Variable.wire ~default:gnd () in
    let enabled l = Always.[ when_ enable.value l ] in
    Always.(
      compile
        [ enable_rate <-- enable_rate_next
        ; when_
            (enable_rate_next ==: i.config.clocks_per_bit)
            [ enable_rate <--. 0; enable <-- vdd ]
        ; sm_tx.switch
            [ ( Start
              , [ data_count <--. 0
                ; txdata <-- i.data_in
                ; enable_rate <--. 0
                ; stop_count <-- gnd
                ; parity <-- gnd
                ; when_
                    i.data_in_valid
                    [ txd <-- gnd; data_in_ready <-- gnd; sm_tx.set_next Data ]
                ] )
            ; ( Data
              , enabled
                  [ data_count <-- data_count.value +:. 1
                  ; txdata <-- srl txdata.value ~by:1
                  ; txd <-- txdata.value.:(0)
                  ; parity <-- parity.value ^: txdata.value.:(0)
                  ; when_
                      (data_count.value ==: data_count_max)
                      [ if_
                          Parity.Enum.Of_signal.(i.config.parity ==: of_enum None)
                          [ sm_tx.set_next Stop ]
                          [ sm_tx.set_next Parity ]
                      ]
                  ] )
            ; ( Parity
              , enabled
                  [ Parity.Enum.Of_always.match_
                      i.config.parity
                      ~default:[]
                      [ Even, [ txd <-- parity.value ]
                      ; Odd, [ txd <-- ~:(parity.value) ]
                      ]
                  ; sm_tx.set_next Stop
                  ] )
            ; ( Stop
              , enabled
                  [ stop_count <-- ~:(stop_count.value)
                  ; txd <-- vdd
                  ; Stop_bits.Enum.Of_always.match_
                      i.config.stop_bits
                      [ One, [ sm_tx.set_next Complete ]
                      ; Two, [ when_ stop_count.value [ sm_tx.set_next Complete ] ]
                      ]
                  ] )
            ; Complete, enabled [ data_in_ready <-- vdd; sm_tx.set_next Start ]
            ]
        ]);
    { O.txd = txd.value; data_in_ready = data_in_ready.value }
  ;;

  let hierarchical ?instance scope inputs =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ~scope ~name:"uart_tx" ?instance create inputs
  ;;
end

module Rx = struct
  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; enable : 'a
      ; config : 'a Config.t
      ; rxd : 'a
      }
    [@@deriving hardcaml ~rtlmangle:false]
  end

  module O = struct
    type 'a t =
      { data_out : 'a [@bits 9]
      ; data_out_valid : 'a
      ; error : 'a
      }
    [@@deriving hardcaml]
  end

  module State = struct
    type t =
      | Start
      | Data
      | Parity
      | Stop
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create_internal
    ?(align_rxdata_to_lsb = false)
    scope
    ({ clocking; enable; config; rxd } : _ I.t)
    =
    let spec = Clocking.to_spec clocking in
    let%hw.Always.State_machine sm_rx = Always.State_machine.create (module State) spec in
    let%hw_var data_count = Always.Variable.reg spec ~width:4 in
    let data_count_max = Config.data_count_max config in
    let rxdata = Always.Variable.reg spec ~width:9 in
    let stop_count = Always.Variable.reg spec ~width:1 in
    let%hw_var parity = Always.Variable.reg spec ~width:1 in
    let error = Always.Variable.reg spec ~width:1 in
    let data_out_valid = Always.Variable.reg spec ~width:1 in
    Always.(
      compile
        [ data_out_valid <-- gnd
        ; error <-- gnd
        ; when_
            enable
            [ sm_rx.switch
                [ ( Start
                  , [ stop_count <--. 0
                    ; data_count <--. 0
                    ; error <-- gnd
                    ; parity <-- gnd
                    ; when_ ~:rxd [ sm_rx.set_next Data ]
                    ] )
                ; ( Data
                  , [ data_count <-- data_count.value +:. 1
                    ; rxdata <-- lsbs rxdata.value @: rxd
                    ; (rxdata
                       <--
                       if align_rxdata_to_lsb
                       then
                         Data_bits.Enum.Of_signal.match_
                           config.data_bits
                           [ Five, zero 4 @: rxd @: rxdata.value.:[4, 1]
                           ; Six, zero 3 @: rxd @: rxdata.value.:[5, 1]
                           ; Seven, zero 2 @: rxd @: rxdata.value.:[6, 1]
                           ; Eight, zero 1 @: rxd @: rxdata.value.:[7, 1]
                           ; Nine, rxd @: rxdata.value.:[8, 1]
                           ]
                       else rxd @: rxdata.value.:[8, 1])
                    ; parity <-- parity.value ^: rxd
                    ; when_
                        (data_count.value ==: data_count_max)
                        [ if_
                            Parity.Enum.Of_signal.(config.parity ==: of_enum None)
                            [ sm_rx.set_next Stop ]
                            [ sm_rx.set_next Parity ]
                        ]
                    ] )
                ; ( Parity
                  , [ Parity.Enum.Of_always.match_
                        config.parity
                        ~default:[]
                        [ ( Even
                          , [ if_
                                (rxd ==: parity.value)
                                [ sm_rx.set_next Stop ]
                                [ error <-- vdd; sm_rx.set_next Start ]
                            ] )
                        ; ( Odd
                          , [ if_
                                (rxd ==: parity.value)
                                [ error <-- vdd; sm_rx.set_next Start ]
                                [ sm_rx.set_next Stop ]
                            ] )
                        ]
                    ; sm_rx.set_next Stop
                    ] )
                ; ( Stop
                  , [ stop_count <-- ~:(stop_count.value)
                    ; if_
                        (rxd <>: vdd)
                        [ error <-- vdd; sm_rx.set_next Start ]
                        [ Stop_bits.Enum.Of_always.match_
                            config.stop_bits
                            [ One, [ data_out_valid <-- vdd; sm_rx.set_next Start ]
                            ; ( Two
                              , [ when_
                                    stop_count.value
                                    [ data_out_valid <-- vdd; sm_rx.set_next Start ]
                                ] )
                            ]
                        ]
                    ] )
                ]
            ]
        ]);
    { O.data_out = rxdata.value
    ; data_out_valid = data_out_valid.value
    ; error = error.value
    }
  ;;

  module State_top = struct
    type t =
      | Start
      | Run
    [@@deriving sexp_of, compare ~localize, enumerate]
  end

  let create
    ?align_rxdata_to_lsb
    scope
    ({ clocking; enable = enable_top; config; rxd } : _ I.t)
    =
    let spec = Clocking.to_spec clocking in
    (* Register a few times to clean up any possible metastability. *)
    (* let%hw rxd = reg spec (reg spec (reg spec rxd)) in *)
    let%hw.Always.State_machine sm_top =
      Always.State_machine.create (module State_top) spec
    in
    let%hw_var enable = Always.Variable.wire ~default:gnd () in
    let rx =
      create_internal
        ?align_rxdata_to_lsb
        scope
        { I.clocking; enable = enable.value; config; rxd }
    in
    let%hw_var enable_count = Always.Variable.reg spec ~width:log_clocks_per_bit in
    let enable_count_next = enable_count.value +:. 1 in
    Always.(
      compile
        [ when_
            enable_top
            [ sm_top.switch
                [ ( Start
                  , [ if_
                        ~:rxd
                        [ enable_count <-- enable_count_next
                        ; when_
                            (enable_count_next ==: srl config.clocks_per_bit ~by:1)
                            [ enable_count <--. 0; enable <-- vdd; sm_top.set_next Run ]
                        ]
                        [ enable_count <--. 0 ]
                    ] )
                ; ( Run
                  , [ enable_count <-- enable_count_next
                    ; when_
                        (enable_count_next ==: config.clocks_per_bit)
                        [ enable_count <--. 0; enable <-- vdd ]
                    ; when_
                        (rx.error |: rx.data_out_valid)
                        [ enable_count <--. 0; sm_top.set_next Start ]
                    ] )
                ]
            ]
        ]);
    rx
  ;;

  let hierarchical ?instance ?align_rxdata_to_lsb scope inputs =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ~scope ~name:"uart_rx" ?instance (create ?align_rxdata_to_lsb) inputs
  ;;
end
