open! Core

let waits_on_host (instruction : Isa.t) =
  match instruction with
  | Op { op = Wait (Fifo _); _ } -> true
  | Jmp { cond = Tx_not_empty | Tx_empty | Rx_not_full | Rx_full; _ } -> true
  | Jmp _ | Op _ -> false
;;

let time_triggered (program : Asm.Program.t) =
  match
    List.filter_mapi program.instructions ~f:(fun pc instruction ->
      Option.some_if (waits_on_host instruction) pc)
  with
  | [] -> Ok ()
  | pcs -> Or_error.error_s [%message "waits on the host" (pcs : int list)]
;;

let schedule ?(inputs = 0) ?(max_cycles = 1_000_000) ~config program ~words =
  let open Or_error.Let_syntax in
  let%bind () = time_triggered program in
  let%bind encoded = Asm.Program.words program in
  let%bind machine = Machine.create ~config ~program:encoded in
  (* after every cycle the host reads every reply and tops the tx fifo up, which is as
     early as it can do either *)
  let rec drain machine =
    match Machine.read_rx machine with
    | Some (_, machine) -> drain machine
    | None -> machine
  in
  let rec top_up (machine : Machine.t) ~sent =
    if sent < words && List.length machine.tx_fifo < Machine.fifo_depth
    then (
      let%bind machine = Machine.write_tx machine sent in
      top_up machine ~sent:(sent + 1))
    else Ok (machine, sent)
  in
  let rec run (machine : Machine.t) ~sent ~deadlines =
    if List.length deadlines = words
    then Ok (List.rev deadlines)
    else if machine.now >= max_cycles
    then
      Or_error.error_s
        [%message
          "words not taken" (max_cycles : int) ~taken:(List.length deadlines : int)]
    else (
      let cycle = machine.now in
      let before = List.length machine.tx_fifo in
      let machine = Machine.step machine ~inputs in
      if not (Machine.Fault.equal machine.fault Machine.Fault.none)
      then
        Or_error.error_s
          [%message "faults" (cycle : int) (machine.fault : Machine.Fault.t)]
      else (
        let deadlines =
          if List.length machine.tx_fifo < before
          then (cycle - 1) :: deadlines
          else deadlines
        in
        let%bind machine, sent = top_up (drain machine) ~sent in
        run machine ~sent ~deadlines))
  in
  let%bind machine, sent = top_up machine ~sent:0 in
  run machine ~sent ~deadlines:[]
;;
