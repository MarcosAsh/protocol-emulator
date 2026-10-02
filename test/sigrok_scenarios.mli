(** Library firmware at the pins of the top, for sigrok's protocol decoders to judge
    ([demo/decode.py]): CAN, CEC, 1-Wire, PS/2, JTAG, USB and WS2812. Traces in
    test/traces/sigrok, which the cocotb replay leaves out. *)

open! Core

val all : Pin_trace.Scenario.t list
