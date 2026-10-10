(** Each receiver's allowed sender clock error, from its certificate.

    The sender is free-running at [m] 2^-16 cycles a bit, bit [k] starting at cycle
    [start + (phase + k * m) / 2^16] for any [phase] below 2^16: engine 1's fractional
    period exactly. Each read the receiver makes after [mov t, capture] lands [d] cycles
    after the captured edge, [d] being the sum of the program's adds to [t] plus the
    read's phase row. With the captured edge at bit [e] and the read in the run of equal
    bits [r0, r1], it is right for every phase iff

    {v
      (r0 - e) * m <= 2^16 * d_lo   and   (r1 + 1 - e) * m >= 2^16 * (d_hi + 1)
    v}

    as bit [k]'s edge lies [floor] or [ceil] of [(k - e) * m / 2^16] cycles after bit
    [e]'s, and some phase gives each. A [capture_arm] is a read of the capture pin. The
    bounds are the tightest of these over the reads of a stimulus that holds every run the
    protocol allows. *)

open! Core
open Protocol_emulator

(** 2^16, a cycle in the units of [m]. *)
val unit : int

module Receiver : sig
  type t =
    { firmware : Certified.t
    ; nominal : int (** Cycles a bit, the rate the error is counted from. *)
    ; preload : int list (** Host words before the start. *)
    ; idle : int (** The inputs between frames. *)
    ; bits : int array (** The inputs, a word a bit: frames back to back. *)
    ; expected : int list (** What the host reads off the fifo. *)
    ; wired : sender:int -> pin_out:int -> int
    (** The inputs from the sender's word and what the receiver drives. *)
    }

  (** [Uart.rx], [Uart.rx_host_rate] at half period [half], [Usb.rx] and the CAN node's
      receiver at [period], fed every byte, all-bytes DATA0 packets, or a set of frames
      with each SOF in the third bit of the intermission. *)
  val uart_rx : ?bytes:int list -> ?source:string -> period:int -> unit -> t

  val uart_rx_host_rate : ?bytes:int list -> ?source:string -> half:int -> unit -> t
  val usb_rx : unit -> t
  val can_rx : period:int -> sample:int -> unit -> t

  (** The CAN receiver's frames: a few by hand, and of 4000 seeded ones the frame with the
      longest run of bits between falling edges and the one with the longest from its
      CRC's last fall to the next SOF. *)
  val can_frames : Can.Frame.t list

  (** The bits from each falling edge of a frame on the bus to the next, SOF to SOF. *)
  val can_segments : Can.Frame.t -> int list
end

module Read : sig
  type t =
    { pc : int
    ; d : int * int (** Cycles after the captured edge, least and most. *)
    ; since : int (** Bits from the captured edge to the run's first. *)
    ; until : int option (** Bits from the captured edge to the run's end. *)
    ; edge : int (** The captured edge's bit in the stimulus. *)
    }
  [@@deriving sexp_of]
end

module Bounds : sig
  type t =
    { least : int (** The fastest sender, in [m]. *)
    ; most : int (** The slowest. *)
    ; fastest_read : Read.t (** The read that sets [least]. *)
    ; slowest_read : Read.t
    ; fast_witness : int (** A phase that fails at [least - 1]. *)
    ; slow_witness : int (** A phase that fails at [most + 1]. *)
    }
  [@@deriving sexp_of]

  (** As parts per million of [nominal], fast and slow. *)
  val ppm : t -> nominal:int -> int * int
end

(** The reads of a run at [nominal], each checked against its row of the certificate. *)
val reads : Receiver.t -> Read.t list

(** An error for a receiver that re-anchors on every edge and from [now] where it saw one
    late, as [Usb.rx] does: an arm checked for an edge that came first at more than one
    place. Reads timed from [now] follow no captured edge, so no bound from the rows
    holds. *)
val applies : Receiver.t -> unit Or_error.t

(** Raises where [applies] refuses. *)
val bounds : Receiver.t -> Bounds.t

(** The words the host reads with the sender at [m] and [phase], and whether the run
    stayed clean: every word as [expected], no irq, no fault. *)
val receives : Receiver.t -> m:int -> phase:int -> bool

(** Whether a sender at [m] from phase 0, as engine 1 sends from an anchor, gets every
    frame through: each read against the bounds above at its own edge's phase. Exact where
    every read sees the bit it sees at the nominal rate, and every wrong read shows in
    what the host reads. [predicts r] runs the model once. *)
val predicts : Receiver.t -> m:int -> bool

(** The bench: engine 1 sends [bytes] back to back from one anchor at m 2^-16 cycles a
    bit, the whole cycles from the host and the rest as its period fraction, to engine 0
    running [Uart.rx_host_rate] on a wire, at 9600 baud from 48 MHz. *)
module Bench : sig
  val half : int
  val bytes : int list

  (** The same receiver on pin 0, for [bounds] and [predicts]. *)
  val receiver : Receiver.t

  val sender : string
  val sender_config : Program_config.t
  val receiver_source : string
  val receiver_config : Program_config.t

  (** Each m the bench tries, fine steps either side of each bound and every half percent
      from -7% to 7%, and whether [predicts] passes it. *)
  val steps : unit -> (int * bool) list
end
