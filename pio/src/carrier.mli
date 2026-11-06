(** pico-examples programs on the bench carrier's pins ([Bench_wiring]), each at the rate
    its own example uses. *)

open! Core

type t =
  { k : float
  ; why : string (** Where [k] comes from. *)
  ; place : Translate.Setup.t -> Translate.Setup.t
  }

(** ws2812 on OUT3, uart_tx on OUT0, spi_cpha0_cs with SCK and CSn on OUT5 and OUT6, MOSI
    on OUT4 and MISO on IN0. Any other program gives [None]. i2c needs SCL at SDA + 1 but
    the carrier has SCL on IO2 and SDA on IO3. *)
val find : Pioasm.Program.t -> t option
