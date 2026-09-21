(** The firmwares the replay runs at the pins: UART both ways, the SPI master against a
    slave model, the I2C logger against a memory, the wrapped loop, and a program that
    polls both fifos while the host keeps the SPI port busy. *)

open! Core

val all : Pin_trace.Scenario.t list
