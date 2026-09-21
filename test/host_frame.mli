(** One chip select low period. [bits] is how many clock edges the host gets through
    before it lets go: all of them in a well formed frame, fewer when it gives up part way
    through a byte or a word, with the clock left high if [release_high]. [stray] clock
    pulses come first, with chip select still high. [half] is the clock's half period, 4
    being the clk/8 that host_spi.mli allows; [lead], [trail] and [gap] are the cycles
    around the chip select edges. *)

open! Core

type t =
  { write : bool
  ; reg : int
  ; words : int list
  ; bits : int
  ; release_high : bool
  ; stray : int
  ; half : int
  ; lead : int
  ; trail : int
  ; gap : int
  }
[@@deriving sexp_of]

(** Words whose last bit was clocked, which are the ones that count. *)
val complete_words : t -> int

(** Four frames in ten are cut short. [halves] are the half periods to pick from and
    [edge] the fewest cycles between a chip select edge and a clock edge. *)
val random : halves:int list -> edge:int -> Splittable_random.t -> t
