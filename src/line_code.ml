open! Core

let states = 8
let state_bits = 3
let address_bits = 4
let entry_bits = 5
let modes_word = states

module Entry = struct
  type t =
    { next : int
    ; out : int
    ; flag : bool
    }
  [@@deriving sexp_of, compare, equal]

  let to_int t = t.next lor (t.out lsl 3) lor (Bool.to_int t.flag lsl 4)
  let of_int v = { next = v land 7; out = (v lsr 3) land 1; flag = v land 0x10 <> 0 }
end

module Modes = struct
  type t =
    { tx_relative : bool
    ; rx_relative : bool
    ; tx_toggle : bool
    ; rx_toggle : bool
    }
  [@@deriving sexp_of, compare, equal]

  let none =
    { tx_relative = false; rx_relative = false; tx_toggle = false; rx_toggle = false }
  ;;

  let to_int t =
    List.foldi
      [ t.tx_relative; t.rx_relative; t.tx_toggle; t.rx_toggle ]
      ~init:0
      ~f:(fun n word b -> word lor (Bool.to_int b lsl n))
  ;;

  let of_int v =
    let bit n = (v lsr n) land 1 = 1 in
    { tx_relative = bit 0; rx_relative = bit 1; tx_toggle = bit 2; rx_toggle = bit 3 }
  ;;
end

type t =
  { words : int array
  ; modes : Modes.t
  }
[@@deriving sexp_of, compare, equal]

let off = { words = Array.create ~len:states 0; modes = Modes.none }

let of_states ?(modes = Modes.none) f =
  { words =
      Array.init states ~f:(fun s ->
        let zero, one = f s in
        Entry.to_int zero lor (Entry.to_int one lsl 8))
  ; modes
  }
;;

let words t = Array.to_list t.words @ [ Modes.to_int t.modes ]
let entry_mask = (1 lsl entry_bits) - 1

let of_words words =
  if List.length words <> states + 1
  then Or_error.error_s [%message "not eight states and the modes" (words : int list)]
  else (
    let #(states, modes) = List.split_n words states in
    let modes = List.hd_exn modes in
    let past_entries = lnot (entry_mask lor (entry_mask lsl 8)) in
    if List.exists states ~f:(fun w -> w land past_entries <> 0)
       || modes land lnot 0xf <> 0
    then
      Or_error.error_s [%message "bits past the entries or the modes" (words : int list)]
    else Ok { words = Array.of_list states; modes = Modes.of_int modes })
;;

let entry t ~state ~input = Entry.of_int ((t.words.(state) lsr (8 * input)) land 0xff)
let flips = { Modes.none with tx_toggle = true }

(* stateless: the line flips on a 0 *)
let nrzi =
  of_states ~modes:flips (fun _ ->
    { Entry.next = 0; out = 1; flag = false }, { Entry.next = 0; out = 0; flag = false })
;;

(* state the ones since a zero; the sixth raises [flag] and counts the stuffed zero *)
let usb_transmit =
  of_states ~modes:flips (fun ones ->
    ( { Entry.next = 0; out = 1; flag = false }
    , if ones >= 5
      then { Entry.next = 0; out = 0; flag = true }
      else { Entry.next = ones + 1; out = 0; flag = false } ))
;;

(* input whether D+ moved; state the ones since a zero *)
let usb_receive =
  of_states ~modes:{ Modes.none with rx_relative = true } (fun ones ->
    ( { Entry.next = Int.min 6 (ones + 1); out = 1; flag = false }
    , { Entry.next = 0; out = 0; flag = ones >= 6 } ))
;;

(* input whether the bit differs from the pin, which flips where it does; state the run so
   far, 0 before the first bit; the fifth raises [flag] and the stuffed bit starts the
   next run *)
let can_transmit =
  of_states ~modes:{ flips with tx_relative = true } (fun run ->
    let take ~differs =
      let run = if run > 0 && not differs then run + 1 else 1 in
      { Entry.next = (if run = 5 then 1 else run)
      ; out = Bool.to_int differs
      ; flag = run = 5
      }
    in
    take ~differs:false, take ~differs:true)
;;

(* input whether the line moved, which flipped where the line was high is the level *)
let can_receive =
  of_states ~modes:{ Modes.none with rx_relative = true; rx_toggle = true } (fun run ->
    let take ~moved =
      if run >= 5
      then { Entry.next = 1; out = 0; flag = true }
      else
        { Entry.next = (if run > 0 && not moved then run + 1 else 1)
        ; out = Bool.to_int moved
        ; flag = false
        }
    in
    take ~moved:false, take ~moved:true)
;;
