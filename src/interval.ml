open! Core

type t =
  { lo : int option
  ; hi : int option
  }
[@@deriving sexp_of, compare, equal]

let exactly n = { lo = Some n; hi = Some n }
let top = { lo = None; hi = None }
let at_least n = { lo = Some n; hi = None }
let shift t n = { lo = Option.map t.lo ~f:(( + ) n); hi = Option.map t.hi ~f:(( + ) n) }

let join a b =
  let min a b = Option.bind a ~f:(fun a -> Option.map b ~f:(Int.min a)) in
  let max a b = Option.bind a ~f:(fun a -> Option.map b ~f:(Int.max a)) in
  { lo = min a.lo b.lo; hi = max a.hi b.hi }
;;

let plus a b =
  { lo = Option.bind a.lo ~f:(fun a -> Option.map b.lo ~f:(( + ) a))
  ; hi = Option.bind a.hi ~f:(fun a -> Option.map b.hi ~f:(( + ) a))
  }
;;

let minus a b =
  { lo = Option.bind a.lo ~f:(fun a -> Option.map b.hi ~f:(fun b -> a - b))
  ; hi = Option.bind a.hi ~f:(fun a -> Option.map b.lo ~f:(fun b -> a - b))
  }
;;

let clamp_low t n =
  { lo = Some (Option.value_map t.lo ~default:n ~f:(Int.max n))
  ; hi = Option.map t.hi ~f:(Int.max n)
  }
;;

let widen ~old t =
  { lo = (if [%equal: int option] old.lo t.lo then t.lo else None)
  ; hi = (if [%equal: int option] old.hi t.hi then t.hi else None)
  }
;;

let to_string t =
  let b = function
    | None -> "?"
    | Some n -> Int.to_string n
  in
  match t.lo, t.hi with
  | Some a, Some b when a = b -> Int.to_string a
  | lo, hi -> [%string "%{b lo}..%{b hi}"]
;;

let disjoint a b =
  let below hi lo =
    match hi, lo with
    | Some hi, Some lo -> hi < lo
    | _ -> false
  in
  below a.hi b.lo || below b.hi a.lo
;;

let contains t n =
  Option.value_map t.lo ~default:true ~f:(fun lo -> n >= lo)
  && Option.value_map t.hi ~default:true ~f:(fun hi -> n <= hi)
;;
