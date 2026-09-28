open! Base
open Hardcaml

module Data_bits : sig
  module Cases : sig
    type t =
      | Five
      | Six
      | Seven
      | Eight
      | Nine
    [@@deriving enumerate, sexp_of, compare ~localize]
  end

  module Enum : Enum.S_enum with module Cases := Cases
end

module Parity : sig
  module Cases : sig
    type t =
      | None
      | Even
      | Odd
    [@@deriving enumerate, sexp_of, compare ~localize]
  end

  module Enum : Enum.S_enum with module Cases := Cases
end

module Stop_bits : sig
  module Cases : sig
    type t =
      | One
      | Two
    [@@deriving enumerate, sexp_of, compare ~localize]
  end

  module Enum : Enum.S_enum with module Cases := Cases
end
