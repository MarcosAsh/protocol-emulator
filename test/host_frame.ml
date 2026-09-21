open! Core
open Protocol_emulator
module Model = Host_port_model
module Reg = Host_port.Reg

type t =
  { write : bool
  ; reg : int
  ; words : int list
  ; bits : int
  ; release_high : bool
  ; stray : int
  ; half : int
  ; lead : int
  ; trail : int
  ; gap : int
  }
[@@deriving sexp_of]

let complete_words t = if t.bits < 8 then 0 else (t.bits - 8) / 16

let mapped =
  List.init (Reg.select + 1) ~f:Fn.id
  @ List.init
      (List.length (List.hd_exn (Model.configs (Model.create ()))))
      ~f:(fun n -> Reg.config + n)
;;

(* the registers that strobe the core come up more often than their share of the map *)
let strobing = [ Reg.control; Reg.tx; Reg.rx; Reg.program_addr; Reg.program ]

let random ~halves ~edge random =
  let int lo hi = Splittable_random.int random ~lo ~hi in
  let pick list = List.nth_exn list (int 0 (List.length list - 1)) in
  let words = List.init (int 1 3) ~f:(fun _ -> int 0 0xffff) in
  let total = 8 + (16 * List.length words) in
  let half = pick halves in
  let cut = int 0 9 < 4 in
  { write = Splittable_random.bool random
  ; reg = pick [ pick strobing; pick strobing; pick mapped; int 0 127 ]
  ; words
  ; bits = (if cut then int 0 (total - 1) else total)
  ; release_high = cut && Splittable_random.bool random
  ; stray = (if int 0 9 < 3 then int 1 3 else 0)
  ; half
  ; lead = int edge half
  ; trail = int edge half
  ; gap = int 1 6
  }
;;
