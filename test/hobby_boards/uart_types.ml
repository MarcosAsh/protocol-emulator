open Base
open Hardcaml

module Data_bits = struct
  module Cases = struct
    type t =
      | Five
      | Six
      | Seven
      | Eight
      | Nine
    [@@deriving enumerate, sexp_of, compare ~localize]
  end

  module Enum = Enum.Make_binary (Cases)
end

module Parity = struct
  module Cases = struct
    type t =
      | None
      | Even
      | Odd
    [@@deriving enumerate, sexp_of, compare ~localize]
  end

  module Enum = Enum.Make_binary (Cases)
end

module Stop_bits = struct
  module Cases = struct
    type t =
      | One
      | Two
    [@@deriving enumerate, sexp_of, compare ~localize]
  end

  module Enum = Enum.Make_binary (Cases)
end
