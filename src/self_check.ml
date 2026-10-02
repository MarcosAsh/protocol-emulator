open! Core

let exact (interval : Interval.t) =
  match interval.lo, interval.hi with
  | Some lo, Some hi when lo = hi -> Some lo
  | _ -> None
;;

(* Where a row's pin write shows, if it makes one. *)
let write_at (row : Analyser.Row.t) =
  match row.pin_event, row.side_event with
  | Some (Edge at), _ -> Some at
  | _, Some { at; changes = true } -> Some at
  | _ -> None
;;

(* The level a row's pin write leaves on the first pin it writes, where the instruction
   alone says. *)
let written_level (row : Analyser.Row.t) =
  match row.instruction, row.pin_event, row.side_event with
  | Op { op = Set { dest = Pins; value }; _ }, Some (Edge _), _ -> Some (value land 1)
  | Op { op = Mov { dest = Pins; op = Copy; source = Null }; _ }, Some (Edge _), _ ->
    Some 0
  | Op { op = Mov { dest = Pins; op = Invert; source = Null }; _ }, Some (Edge _), _ ->
    Some 1
  | Op { side_set; _ }, None, Some { changes = true; _ } -> Some (side_set land 1)
  | _ -> None
;;

(* Longer than any path without a loop, and than any frame worth checking. *)
let max_steps = 100_000

let edges ?period ~config (program : Asm.Program.t) ~first ~last =
  let open Or_error.Let_syntax in
  let config = Asm.Program.configure program config in
  let%bind () =
    if config.period_fraction <> 0 || config.manchester
    then Or_error.error_s [%message "edges not whole cycles apart"]
    else Ok ()
  in
  let%bind words = Asm.Program.words program in
  let analysed = Analyser.analyse ?period ~config program.instructions in
  let%bind () = Kernel.check ?period ~config ~words (Kernel.Table.of_analyser analysed) in
  let rows = Int.Map.of_alist_exn (List.map analysed ~f:(fun r -> r.pc, r)) in
  let instructions = Array.of_list program.instructions in
  let next pc = if pc = config.wrap_top then config.wrap_bottom else pc + 1 in
  let row pc =
    match Map.find rows pc with
    | Some row -> Ok row
    | None -> Or_error.error_s [%message "pc not reached" (pc : int)]
  in
  let exactly what pc interval =
    match exact interval with
    | Some n -> Ok n
    | None -> Or_error.error_s [%message "not exact" (what : string) (pc : int)]
  in
  let refuse what pc = Or_error.error_s [%message what (pc : int)] in
  let no_write what pc =
    let%bind r = row pc in
    if Option.is_some (write_at r) then refuse what pc else Ok ()
  in
  let%bind start = row first in
  let%bind start_at =
    match write_at start with
    | Some at -> exactly "edge" first at
    | None -> refuse "no pin write" first
  in
  let%bind () =
    match written_level start with
    | Some 0 -> Ok ()
    | Some _ -> refuse "frame starts with a rise" first
    | None -> refuse "first edge's level not known" first
  in
  let%bind p = exactly "period" first start.period in
  (* [dt] is how far [t] has moved since [first]; each row's phase is from [t]. *)
  let rec walk ~pc ~dt ~x ~y ~steps found =
    if steps > max_steps
    then refuse "frame does not end" last
    else (
      let%bind r = row pc in
      let%bind found =
        match write_at r with
        | Some at when steps > 0 ->
          let%map at = exactly "edge" pc at in
          (dt + at - start_at) :: found
        | Some _ | None -> Ok found
      in
      if pc = last && steps > 0
      then Ok (List.rev found)
      else (
        let continue ?(dt = dt) ?(x = x) ?(y = y) pc =
          walk ~pc ~dt ~x ~y ~steps:(steps + 1) found
        in
        let count name = function
          | Some v -> Ok (v <> 0, Some ((v - 1) land 0xffff))
          | None -> refuse [%string "%{name} not known"] pc
        in
        match instructions.(pc) with
        | Jmp { cond = Always; target } -> continue target
        | Jmp { cond = X_dec; target } ->
          let%bind taken, x = count "x" x in
          continue ~x (if taken then target else next pc)
        | Jmp { cond = Y_dec; target } ->
          let%bind taken, y = count "y" y in
          continue ~y (if taken then target else next pc)
        | Jmp _ -> refuse "jump on the world inside the frame" pc
        | Op { op; _ } ->
          (match op with
           | Wait (Deadline { advance }) ->
             continue ~dt:(if advance then dt + p else dt) (next pc)
           | Wait _ -> refuse "wait on the world inside the frame" pc
           | Alu { dest = T; op = Add; operand = Imm n } ->
             continue ~dt:(dt + n) (next pc)
           | Alu { dest = T; op = Sub; operand = Imm n } ->
             continue ~dt:(dt - n) (next pc)
           | Alu { dest = T; op = Add; operand = Reg P } ->
             continue ~dt:(dt + p) (next pc)
           | Alu { dest = T; op = Sub; operand = Reg P } ->
             continue ~dt:(dt - p) (next pc)
           | Alu { dest = T; _ } | Mov { dest = T; _ } | Out { dest = T; _ } ->
             refuse "t written inside the frame" pc
           | Alu { dest = P; _ }
           | Mov { dest = P; _ }
           | Out { dest = P; _ }
           | Set { dest = P; _ } -> refuse "p written inside the frame" pc
           | Set { dest = X; value } -> continue ~x:(Some value) (next pc)
           | Set { dest = Y; value } -> continue ~y:(Some value) (next pc)
           | Alu { dest = X; _ } | Mov { dest = X; _ } | Out { dest = X; _ } ->
             continue ~x:None (next pc)
           | Alu { dest = Y; _ } | Mov { dest = Y; _ } | Out { dest = Y; _ } ->
             continue ~y:None (next pc)
           | Sys Halt -> refuse "halt inside the frame" pc
           | _ -> continue (next pc))))
  in
  let%bind later =
    walk ~pc:first ~dt:0 ~x:(exact start.x) ~y:(exact start.y) ~steps:0 []
  in
  let%bind final =
    match List.last later with
    | Some d -> Ok d
    | None -> refuse "no edge after the first" first
  in
  (* From a wait on the world back to [first], each instruction at its least, the wait
     releasing at once. *)
  let rec back pc cycles steps =
    if steps > max_steps
    then refuse "no way back to the first edge" first
    else if pc = first
    then Ok (cycles + 1)
    else (
      let%bind () = no_write "edge before the first" pc in
      match instructions.(pc) with
      | Jmp { cond = Always; target } -> back target (cycles + Isa.jmp_cycles) (steps + 1)
      | Jmp _ -> refuse "branch on the way back" pc
      | Op { op = Wait (Deadline _); _ } -> refuse "deadline on the way back" pc
      | Op { delay; _ } -> back (next pc) (cycles + 1 + delay) (steps + 1))
  in
  (* After [last], the least cycles to the next first edge: the analyser's count since the
     last edge where the frame waits on the world, then [back]. *)
  let rec world pc ~previous steps =
    if steps > max_steps
    then refuse "no wait on the world after the frame" last
    else (
      let%bind () = no_write "edge after the frame" pc in
      match instructions.(pc) with
      | Op { op = Wait (Pin_level _ | Pin_edge _ | Fifo _); _ } ->
        let%bind r = row pc in
        (match List.Assoc.find r.since_edge previous ~equal:Int.equal with
         | Some { lo = Some since; _ } ->
           let%map rest = back pc 0 0 in
           since + rest
         | Some _ | None -> refuse "no count since the edge" pc)
      | Jmp { cond = Always; target } -> world target ~previous:pc (steps + 1)
      | Jmp _ -> refuse "branch after the frame" pc
      | Op _ -> world (next pc) ~previous:pc (steps + 1))
  in
  let%map gap = world (next last) ~previous:last 0 in
  later @ [ final + gap ]
;;

(* [checker]'s wait for a check ends [lead] cycles before the edge and its wait for the
   least [least_lead] cycles before it; each frame's [t] is anchored [anchor] cycles after
   its first edge. *)
let lead = 2
let least_lead = 5
let anchor = 10
let min_gap = 17
let capture_span = 1 lsl 14
let data_words = 1 lsl Isa.data_addr_bits

let rows ~base edges =
  let open Or_error.Let_syntax in
  let%bind first, rest =
    match edges with
    | first :: (_ :: _ as rest) -> Ok (first, rest)
    | [] | [ _ ] -> Or_error.error_s [%message "no least after the edges"]
  in
  let gaps = List.map2_exn (List.drop_last_exn edges) rest ~f:(fun a b -> b - a) in
  let loaded =
    ((first - anchor - lead) :: List.drop_last_exn gaps)
    @ [ List.last_exn gaps - (least_lead - lead) ]
  in
  let%bind () =
    List.map loaded ~f:(fun p ->
      if p < min_gap
      then Or_error.error_s [%message "gap out of range" (p : int)]
      else Ok ())
    |> Or_error.combine_errors_unit
  in
  let%bind () =
    let last = List.last_exn edges in
    if last >= capture_span
    then Or_error.error_s [%message "frame reaches 2^14 cycles" (last : int)]
    else Ok ()
  in
  let%map () =
    if base < 0 || base + List.length loaded + 1 > data_words
    then Or_error.error_s [%message "rows past the data memory" (base : int)]
    else Ok ()
  in
  (* the first row is the first check's [p]; the rest carry theirs above whether another
     edge follows; the word after them is the base, which [seek] wraps, above the data
     memory so no load of [p] is under [min_gap] *)
  let last = List.length loaded - 1 in
  List.mapi loaded ~f:(fun n p ->
    if n = 0 then p else (p lsl 1) lor Bool.to_int (n < last))
  @ [ base + data_words ]
;;

(* One loop per level after the last edge. High, x is the last fall's stamp, so a capture
   that differs means a fall, which must stamp the edge's own cycle. Low, the line cannot
   fall without rising, so it is read in the cycle before the edge and at the edge. The
   next frame's wait starts at the least, and its stamp must be the cycle it released on. *)
let checker ~pin ~base =
  if base < 0 || base >= data_words
  then raise_s [%message "base past the data memory" (base : int)];
  let high = base lsr 4 in
  let low = base land 0xf in
  [%string
    {|
    set x, %{high#Int}
    in x, 5
    set x, %{low#Int}
    in x, 4
    mov x, isr
    mov p, x                 ; the rows' base, where the least keeps it
    capture_arm
    wait 1 pin %{pin#Int}            ; the line idles high
    wait 0 pin %{pin#Int}            ; the first frame's first edge
    capture_arm
    mov isr, capture [5]     ; its stamp, or a fall's in the first cycle read
    jmp anchor
high:                        ; x is the last fall's stamp
    wait t [2]
    capture_arm              ; the cycle after the edge
    mov y, capture
    jmp x!=y, fell
    out y, 1
    out p, 15
    add t, p
    jmp y--, high
    jmp least
fell:
    mov x, now
    sub x, 5                 ; the edge's own cycle
    jmp x!=y, fault
    out y, 1
    out p, 15
    add t, p
    jmp y--, low
    jmp fault                ; the frame ends low
low:
    mov isr, null
    wait t
    in pins, 1               ; the cycle before the edge
    jmp pin, rose            ; the edge
    mov y, isr
    jmp y--, fault
    out y, 1
    out p, 15
    add t, p
    jmp y--, low
    jmp fault                ; the frame ends low
rose:
    mov y, isr
    jmp y--, fault
    out y, 1
    out p, 15
    add t, p
    jmp y--, high
least:
    out p, 16                ; the base, in the word after the rows
    wait t
    mov y, capture
    jmp x!=y, fault          ; nothing fell up to five cycles before the least
    mov y, capture           ; the cycle before it
    wait 0 pin %{pin#Int}            ; from the least on, the next frame's first edge
    capture_arm
    mov isr, capture
    jmp x!=y, fault          ; nor up to two cycles before
    mov x, isr
    mov y, now
    add x, 6
    jmp x!=y, fault          ; the capture is the fall the wait released on
anchor:
    mov t, now
    set x, 0
    add x, p
    seek [2]                 ; the rows from the top, four cycles to fetch
    mov x, isr
    out p, 16
    add t, p
    jmp low
fault:
    irq
    halt
|}]
;;

let checker_config ~pin =
  { Program_config.default with
    in_base = pin
  ; in_count = 1
  ; jmp_pin = pin
  ; capture_pin = pin
  ; capture_rising = false
  ; in_shift = Left
  ; autopull = true
  ; pull_threshold = 16
  ; autopull_data = true
  }
;;
