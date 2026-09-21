open! Core
open Protocol_emulator
open Firmware

(* the loopback: IN0 follows OUT0 *)
let loopback (t : Machine.t) = (t.pin_out lsr 5) land 1

let%expect_test "the core measures its own edges" =
  let period = 16 in
  let t =
    Machine.create ~config:edge_meter_config ~program:(assemble (edge_meter ~period))
    |> ok_exn
  in
  let rec loop t n stamps =
    if n = 0
    then t, List.rev stamps
    else (
      let t = Machine.step t ~inputs:(loopback t) in
      match Machine.read_rx t with
      | Some (stamp, t) -> loop t (n - 1) (stamp :: stamps)
      | None -> loop t (n - 1) stamps)
  in
  let t, stamps = loop t 400 [] in
  let intervals =
    List.zip_exn (List.drop stamps 1) (List.drop_last_exn stamps)
    |> List.map ~f:(fun (a, b) -> a - b)
  in
  print_s
    [%message
      (List.hd_exn stamps : int) (intervals : int list) (t.fault : Machine.Fault.t)];
  [%expect
    {|
    (("List.hd_exn stamps" 20) (intervals (32 32 32 32 32 32 32 32 32 32 32))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false))))
    |}]
;;

let%expect_test "edge meter in lockstep" =
  let last = ref 0 in
  let stamps = ref [] in
  let (_ : Machine.t) =
    Lockstep.lockstep
      ~config:edge_meter_config
      ~program:(assemble (edge_meter ~period:16))
      ~inputs:(fun _ -> !last)
      ~host:(fun _ -> { Lockstep.Host.idle with tx = None; pop_rx = true })
      ~react:(fun m ->
        last := (m.pin_out lsr 5) land 1;
        match m.rx_fifo with
        | s :: _ -> stamps := s :: !stamps
        | [] -> ())
      ()
  in
  let stamps = List.rev !stamps in
  let intervals =
    List.zip_exn (List.drop stamps 1) (List.drop_last_exn stamps)
    |> List.map ~f:(fun (a, b) -> a - b)
  in
  print_s [%message (intervals : int list)];
  [%expect
    {|
    ("lockstep held" (cycles 400))
    (intervals (32 32 32 32 32 32 32 32 32 32 32))
    |}]
;;
