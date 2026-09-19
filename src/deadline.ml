open! Core
open! Hardcaml

module Make (Comb : Comb.S) = struct
  open Comb

  let phase ~now ~t = now -: t
  let release ~now ~t = ~:(msb (phase ~now ~t))
  let late ~now ~t = release ~now ~t &: (phase ~now ~t <>:. 0)
end
