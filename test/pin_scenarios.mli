(** The firmwares the replay runs at the pins: every protocol's in [Library], then the
    wrapped loop and a program that polls both fifos while the host keeps the SPI port
    busy. *)

open! Core

val all : Pin_trace.Scenario.t list
