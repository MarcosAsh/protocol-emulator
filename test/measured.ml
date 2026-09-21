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
