open! Core
open Protocol_emulator

module Generator : sig
  val instruction : side_set_count:int -> Isa.t Quickcheck.Generator.t
end
