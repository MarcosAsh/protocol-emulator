open! Core
open Protocol_emulator

let feed (t : Machine.t) pending =
  match pending with
  | word :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
    Machine.write_tx t word |> ok_exn, rest
  | pending -> t, pending
;;

let feed_due (t : Machine.t) schedule ~now =
  match schedule with
  | (cycle, word) :: rest when cycle <= now && List.length t.tx_fifo < Machine.fifo_depth
    -> Machine.write_tx t word |> ok_exn, rest
  | schedule -> t, schedule
;;

let write_all t words =
  List.fold words ~init:t ~f:(fun t word -> Machine.write_tx t word |> ok_exn)
;;

let receive t received =
  match Machine.read_rx t with
  | Some (word, t) -> t, word :: received
  | None -> t, received
;;

let run ?(tx = []) ?(pin = Isa.first_output_pin) t ~cycles ~inputs =
  let rec loop t tx n levels =
    if n = 0
    then t, List.rev levels
    else (
      let t, tx = feed t tx in
      let t = Machine.step t ~inputs in
      loop t tx (n - 1) (((t.pin_out lsr pin) land 1) :: levels))
  in
  loop t tx cycles []
;;
