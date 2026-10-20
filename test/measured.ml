open! Core

type t = (string * (int * int)) list [@@deriving sexp_of]

let empty = []

let add t ~name ~ns =
  if List.Assoc.mem t name ~equal:String.equal
  then
    List.map t ~f:(fun (n, (shortest, longest)) ->
      if String.equal n name
      then n, (Int.min shortest ns, Int.max longest ns)
      else n, (shortest, longest))
  else t @ [ name, (ns, ns) ]
;;

let ns ~clock_hz cycles = ((2 * cycles * 1_000_000_000) + clock_hz) / (2 * clock_hz)
let at_least ~clock_hz cycles ~ns = cycles * 1_000_000_000 >= ns * clock_hz
let at_most ~clock_hz cycles ~ns = cycles * 1_000_000_000 <= ns * clock_hz
let cycles ~clock_hz ~ns = ns * clock_hz / 1_000_000_000
