(** pico-examples programs on the bench carrier's wiring ([Bench_wiring]), each at the
    rate its own example runs it. *)

open! Core

type t =
  { k : float
  ; why : string (** Whose rate [k] is. *)
  ; place : Translate.Setup.t -> Translate.Setup.t
  }

(** ws2812 on OUT3; uart_tx on OUT0; spi_cpha0_cs with SCK and CSn on OUT5 and OUT6, MOSI
    on OUT4 and MISO on IN0. [None] for any other: i2c wants SCL at SDA + 1, and the
    carrier has SCL on IO2 and SDA on IO3. *)
val find : Pioasm.Program.t -> t option
