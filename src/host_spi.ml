open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a
    ; tx_byte : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { miso : 'a
    ; rx_byte : 'a [@bits 8]
    ; rx_valid : 'a
    ; frame_start : 'a
    ; frame_end : 'a
    }
  [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let sync x = Clocking.pipeline i.clocking ~n:2 x in
  let%hw sck = sync i.sck in
  let%hw mosi = sync i.mosi in
  let%hw selected = ~:(sync i.cs_n) in
  let%hw sck_rise = sck &: ~:(reg spec sck) in
  let%hw sck_fall = ~:sck &: reg spec sck in
  let%hw frame_start = selected &: ~:(reg spec selected) in
  let%hw frame_end = ~:selected &: reg spec selected in
  let%hw_var bit = Always.Variable.reg spec ~width:3 in
  let%hw_var shift_in = Always.Variable.reg spec ~width:8 in
  let%hw_var shift_out = Always.Variable.reg spec ~width:8 in
  let%hw_var rx_byte = Always.Variable.reg spec ~width:8 in
  let%hw_var rx_valid = Always.Variable.reg spec ~width:1 in
  Always.(
    compile
      [ rx_valid <-- gnd
      ; when_ frame_start [ bit <-- zero 3; shift_out <-- i.tx_byte ]
      ; when_
          (selected &: sck_rise)
          [ shift_in <-- shift_in.value.:[6, 0] @: mosi
          ; bit <-- bit.value +:. 1
          ; when_
              (bit.value ==:. 7)
              [ rx_byte <-- shift_in.value.:[6, 0] @: mosi; rx_valid <-- vdd ]
          ]
      ; when_
          (selected &: sck_fall)
          [ if_
              (bit.value ==:. 0)
              [ shift_out <-- i.tx_byte ]
              [ shift_out <-- shift_out.value.:[6, 0] @: gnd ]
          ]
      ]);
  { O.miso = selected &: msb shift_out.value
  ; rx_byte = rx_byte.value
  ; rx_valid = rx_valid.value
  ; frame_start
  ; frame_end
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"host_spi" create i
;;
