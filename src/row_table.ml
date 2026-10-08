open! Core
open! Hardcaml

let word words pc =
  Bits.of_unsigned_int
    ~width:Isa.data_bits
    (if pc < Array.length words then words.(pc) else 0)
;;

module Rejection = struct
  type t =
    { pc : int
    ; fails : string list
    }
  [@@deriving sexp_of]

  let of_conjuncts ~pc conjuncts =
    let fails =
      List.filter_map conjuncts ~f:(fun (name, holds) ->
        Option.some_if (not (Bits.to_bool holds)) name)
    in
    Option.some_if (not (List.is_empty fails)) { pc; fails }
  ;;
end

let widen_after = 64

let fixpoint init ~visit ~join ~widen ~equal =
  let state = Array.copy init in
  let changes = Array.create ~len:(Array.length state) 0 in
  let queue = Queue.of_list [ 0 ] in
  while not (Queue.is_empty queue) do
    let pc = Queue.dequeue_exn queue in
    List.iter
      (visit pc state.(pc))
      ~f:(fun (next, image) ->
        let joined = join state.(next) image in
        let joined = if changes.(next) < widen_after then joined else widen joined in
        if not (equal joined state.(next))
        then (
          changes.(next) <- changes.(next) + 1;
          state.(next) <- joined;
          Queue.enqueue queue next))
  done;
  state
;;
