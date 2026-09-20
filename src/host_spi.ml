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
  let%hw sck_rise = selected &: sck &: ~:(reg spec sck) in
  let%hw sck_fall = selected &: ~:sck &: reg spec sck in
  let%hw frame_start = selected &: ~:(reg spec selected) in
  let%hw frame_end = ~:selected &: reg spec selected in
  (* Mode 0: the master changes mosi on the falling edge and samples miso on the rising
     one, so we take bits on [sck_rise] and shift out on [sck_fall], reloading [tx_byte]
     when the count wraps at a byte boundary. *)
  let%hw count =
    reg_fb spec ~width:3 ~f:(fun d ->
      mux2 frame_start (zero 3) @@ mux2 sck_rise (d +:. 1) d)
  in
  let%hw shift_in =
    reg_fb spec ~width:8 ~f:(fun d -> mux2 sck_rise (d.:[6, 0] @: mosi) d)
  in
  let%hw last_bit = sck_rise &: (count ==:. 7) in
  let%hw rx_byte = reg spec ~enable:last_bit (shift_in.:[6, 0] @: mosi) in
  let%hw rx_valid = reg spec last_bit in
  let%hw shift_out =
    reg_fb spec ~width:8 ~f:(fun d ->
      mux2 (frame_start |: (sck_fall &: (count ==:. 0))) i.tx_byte
      @@ mux2 sck_fall (d.:[6, 0] @: gnd) d)
  in
  { O.miso = selected &: msb shift_out; rx_byte; rx_valid; frame_start; frame_end }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"host_spi" create i
;;
