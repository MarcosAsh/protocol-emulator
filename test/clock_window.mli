(** The clocks each bench firmware stays certified at, with its image and load unchanged.
    The certificate is in cycles and holds at any clock the chip meets timing at; only a
    limit's ns move with it. So each datasheet limit holds up to a highest clock (a least
    width) or from a lowest (a most). A receiver whose sender keeps its own rate holds
    where the sender's bit, counted in the receiver's cycles, is inside its tolerance. *)

open! Core

module End : sig
  type t =
    { hz : int (** The last clock that holds; a hertz past it [limit] fails. *)
    ; limit : string
    }
  [@@deriving sexp_of]
end

type t =
  { firmware : string
  ; shipped_hz : int
  ; lowest : End.t option (** [None] where no limit fails at a slower clock. *)
  ; highest : End.t option
  }
[@@deriving sexp_of]

(** A limit as the window names it, as ["bit <= 8854.17 ns"]. *)
val limit_name : Datasheet.t -> string

(** [Up_to] and [From] of each limit on [bench], the tightest of each kind. *)
val of_bench : Bench.t -> t

(** The clocks at which [Tolerance.bounds] admits a sender at [rate] bits a second: the
    sender's bit is [m] = 2^16 [hz] / [rate] of the receiver's cycles. Whole hertz inside,
    so short of the exact edge by under 2^-16 cycles a bit. *)
val of_tolerance : Tolerance.Bounds.t -> rate:int -> End.t * End.t

(** The CAN receiver's bench copy, listening to a node on the bus at 500 kbit/s: its ACK
    limit, and its tolerance with the ACK back on CRX at once (as on the bench) and at
    [Can_node.Receiver.longest_loop]. *)
val can_receiver : unit -> t

(** Each diagram in [dir], test/diagrams, with a limit, as ["diagram ws2812"]. *)
val diagrams : dir:string -> t list

(** Every bench firmware with limits, then [Uart.log], with [can_receiver] in its place. *)
val all : unit -> t list

(** One line per firmware: the lowest clock and the limit that fails below it, the shipped
    clock, the highest and the limit that fails above it, in MHz. *)
val to_string : t list -> string
