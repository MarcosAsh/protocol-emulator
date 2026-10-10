open! Core
open! Hardcaml
open Protocol_emulator
open Protocol_emulator_test

let writes_pins (t : Isa.t) =
  match t with
  | Op
      { op =
          ( Set { dest = Pins | Pindirs; _ }
          | Out { dest = Pins | Pindirs; _ }
          | Mov { dest = Pins | Pindirs; _ } )
      ; _
      } -> true
  | _ -> false
;;

(* The departure time in a stamped frame, for a transmitter shaped like [Uart.tx_stamped]:
   [mov y, now] starts the stamp, a [set pins, 0] sends the start bit, [mov osr, y] loads
   the stamp and [wait t+; out pins, 1; jmp x--] sends it LSB first. The claims:

   - in the first cycle the start bit shows, the line was high the cycle before and [y]
     holds the low 16 bits of [now];
   - [y] keeps that stamp until [mov osr, y], and the bits of [osr] still to go are the
     stamp's, from the next one to send;
   - from each [out] to the next, the pin shows the stamp bit it sent.

   What makes the first inductive is the line's level where the program knows it, since
   every instruction after a [set pins] finds the level it set up to the next pin write,
   and the delay left at each pc, which is no more than its ways in leave.

   It assumes no more than the certificate: inputs and the host's fifo traffic are free,
   and the host never halts the core. No bound on the clock is needed, since the stamp is
   [now] modulo 2^16 and so wraps with it; a receiver that wants the whole cycle unwraps
   it, which takes frames less than 65536 cycles apart or a count of its own. The pin is
   the engine's [pin_out] register, and each flop between it and the pad adds one cycle.

   Two claims made wrong on purpose have to fail: OFF_BY_ONE puts the stamp a cycle after
   the edge, which a run from reset contradicts, and NEXT_BIT says the pin shows the bit
   after the one sent, which the invariant must not imply. *)
let stamp_claims ~(config : Program_config.t) (rows : Analyser.Row.t list) =
  if config.side_set_count <> 0
     || config.manchester
     || config.set_base <> config.out_base
     || not (Program_config.Shift_direction.equal config.out_shift Right)
  then raise_s [%message "BUG: a stamped frame goes out on one plain pin, LSB first"];
  let find ?(after = -1) what ~f =
    match List.find rows ~f:(fun row -> row.pc > after && f row.instruction) with
    | Some row -> row.pc
    | None -> raise_s [%message "BUG: not a stamped transmitter" (what : string)]
  in
  let read_now =
    find "mov y, now" ~f:(function
      | Op { op = Mov { dest = Y; op = Copy; source = Now }; _ } -> true
      | _ -> false)
  in
  let start =
    find "start bit" ~after:read_now ~f:(function
      | Op { op = Set { dest = Pins; value = 0 }; _ } -> true
      | _ -> false)
  in
  let load =
    find "mov osr, y" ~after:start ~f:(function
      | Op { op = Mov { dest = Osr; op = Copy; source = Y }; _ } -> true
      | _ -> false)
  in
  let shift =
    find "out pins, 1" ~after:load ~f:(function
      | Op { op = Out { dest = Pins; count = 1 }; _ } -> true
      | _ -> false)
  in
  let wait = shift - 1 in
  let jmp = shift + 1 in
  let instruction pc = (List.nth_exn rows pc).instruction in
  (match instruction (load + 1), instruction wait, instruction jmp with
   | ( Op { op = Set { dest = X; value = 15 }; _ }
     , Op { op = Wait (Deadline { advance = true }); _ }
     , Jmp { cond = X_dec; target } )
     when wait = load + 2 && target = wait -> ()
   | _ -> raise_s [%message "BUG: the stamp is not sent as sixteen bits"]);
  (* the level each pc finds the line at, where every way in agrees; [None] is unknown *)
  let level_after (row : Analyser.Row.t) level_in =
    match row.instruction with
    | Op { op = Set { dest = Pins; value }; _ } -> Some (value land 1)
    | i when writes_pins i -> None
    | _ -> level_in
  in
  let rec settle levels =
    let next =
      List.fold rows ~init:levels ~f:(fun levels (row : Analyser.Row.t) ->
        (* the start is a way in to pc 0 at a level nothing set *)
        let start = if row.pc = 0 then [ None ] else [] in
        let ways_in =
          start
          @ List.filter_map row.since_edge ~f:(fun (from, _) ->
            Map.find levels from |> Option.map ~f:(level_after (List.nth_exn rows from)))
        in
        match ways_in with
        | [] -> levels
        | first :: rest ->
          let data =
            if List.for_all rest ~f:([%equal: int option] first) then first else None
          in
          Map.set levels ~key:row.pc ~data)
    in
    if Map.equal [%equal: int option] next levels then levels else settle next
  in
  let levels =
    settle Int.Map.empty
    |> Map.to_alist
    |> List.filter_map ~f:(fun (pc, level) ->
      Option.map level ~f:(fun level ->
        sprintf
          "      if (pc == %d%s) assert (tx == %d);"
          pc
          (if writes_pins (instruction pc) then " && entry" else "")
          level))
    |> String.concat ~sep:"\n"
  in
  (* without this induction holds the start bit back with a delay nothing left it *)
  let delays =
    List.map rows ~f:(fun (row : Analyser.Row.t) ->
      let left (from : int) =
        match instruction from with
        | Jmp _ -> Isa.jmp_cycles - 1
        | Op { delay; _ } -> delay
      in
      List.map row.since_edge ~f:(fun (from, _) -> left from)
      |> List.max_elt ~compare
      |> Option.value ~default:0
      |> sprintf "      if (pc == %d && !jumped) assert (stall <= %d);" row.pc)
    |> String.concat ~sep:"\n"
  in
  let tx_pin = config.out_base in
  let monitor =
    [%string
      {|  // the stamp: the low 16 bits of the cycle the start bit first shows
  wire tx = pin_out[%{tx_pin#Int}];
  reg last_tx = 0;
  reg shown = 0;
  reg [15:0] stamp = 0;
  always @(posedge clk) begin
    last_tx <= tx;
    shown <= entry && pc == %{start#Int};
    if (shown) stamp <= now[15:0];
  end
  // the stamp bits sent at the out and at the jump after it
  wire [4:0] sent_at_out = 5'd15 - x[4:0];
  wire [4:0] sent_at_jmp = 5'd16 - x[4:0];

|}]
  in
  let claims =
    [%string
      {|      // the delay left where the program can leave one
%{delays}
      // the line where the program knows it
%{levels}
      // the stamp is the cycle the start bit shows, and the line fell there
`ifdef OFF_BY_ONE
      if (shown) assert (y == now[15:0] + 16'd1);
`else
      if (shown) assert (!tx && last_tx && y == now[15:0]);
`endif
      if (!shown && pc > %{start#Int} && pc <= %{load#Int}) assert (y == stamp);
      if (pc == %{load + 1#Int}) assert (osr == stamp);
      if (pc == %{wait#Int} || pc == %{shift#Int})
        assert (x <= 15 && ((osr ^ (stamp >> sent_at_out)) & (16'hffff >> sent_at_out)) == 0);
      if (pc == %{jmp#Int})
        assert (x <= 15 && ((osr ^ (stamp >> sent_at_jmp)) & (16'hffff >> sent_at_jmp)) == 0);
      // and the pin shows each bit from its out to the next
      if (pc == %{jmp#Int}) assert (tx == stamp[4'd15 - x[3:0]]);
      if ((pc == %{wait#Int} || pc == %{shift#Int}) && x != 15) assert (tx == stamp[4'd14 - x[3:0]]);
      if (pc == %{jmp + 1#Int}) assert (tx == stamp[15]);
`ifdef NEXT_BIT
      if (pc == %{jmp#Int} && x != 0) assert (tx == stamp[4'd16 - x[3:0]]);
`endif
|}]
  in
  monitor, claims
;;

(* Which bits of the host word the pins carry, for firmware that pulls by hand and outs
   to the pins, n bits at a time. From the osr kernel's rows: osr_count and the osr follow
   the count since the pull; a pulled row holds a word or has set underflow; while an out
   to the pins was the last write to them or the osr, the pins show its bits [c - n, c),
   and where a row's sum S is one value, bits [S - n - x, S - x). Bits count from the end
   the osr shifts from; the word is the tx fifo's head at the pull (fifo_order.sv). *)
let data_claims ~(config : Program_config.t) ~words (rows : Analyser.Row.t list) =
  if config.autopull || config.manchester
  then raise_s [%message "BUG: data claims are for firmware that pulls by hand"];
  let kernel = Kernel.Table.of_analyser rows in
  let osr = Osr_kernel.Table.propose ~config ~words kernel in
  Osr_kernel.check ~config ~words ~kernel osr |> ok_exn;
  let n =
    List.filter_map rows ~f:(fun row ->
      match row.instruction with
      | Op { op = Out { dest = Pins; count }; _ } -> Some count
      | _ -> None)
    |> List.dedup_and_sort ~compare
    |> function
    | [ n ] -> n
    | counts -> raise_s [%message "BUG: one count of out to the pins" (counts : int list)]
  in
  let overlaps base count =
    count > 0 && base < config.out_base + n && config.out_base < base + count
  in
  if overlaps config.side_set_base config.side_set_count
  then raise_s [%message "BUG: side-set drives the pins the outs send on"];
  (* at each issue, what the count, the word and the last write to the out pins do *)
  let count_on = sprintf "shifted <= shifted + 6'd%d > 32 ? 6'd32 : shifted + 6'd%d;" in
  let actions =
    List.filter_map rows ~f:(fun row ->
      let action =
        match row.instruction with
        | Op { op = Out { dest = Pins; count }; _ } ->
          Some (count_on count count ^ " sent <= 1;")
        | Op { op = Out { count; _ }; _ } -> Some (count_on count count ^ " sent <= 0;")
        | Op { op = Sys Pull; _ } ->
          Some
            "shifted <= 0; holds_word <= !tx_empty; sent <= 0;\n\
            \          if (!tx_empty) word <= tx_head;"
        | Op { op = Mov { dest = Osr; _ }; _ } ->
          Some "shifted <= 0; holds_word <= 0; sent <= 0;"
        | i when writes_pins i -> Some "sent <= 0;"
        | _ -> None
      in
      Option.map action ~f:(fun action ->
        sprintf "        %d: begin\n          %s\n        end" row.pc action))
    |> String.concat ~sep:"\n"
  in
  (* whether every way in, and whether some way in, had an out to the pins last *)
  let sent_after (row : Analyser.Row.t) sent_in =
    match row.instruction with
    | Op { op = Out { dest = Pins; _ }; _ } -> true
    | Op { op = Out _ | Sys Pull | Mov { dest = Osr; _ }; _ } -> false
    | i when writes_pins i -> false
    | _ -> sent_in
  in
  let settle ~combine =
    let rec go sent =
      let next =
        List.fold rows ~init:sent ~f:(fun sent (row : Analyser.Row.t) ->
          let start = if row.pc = 0 then [ false ] else [] in
          let ways_in =
            start
            @ List.filter_map row.since_edge ~f:(fun (from, _) ->
              Map.find sent from |> Option.map ~f:(sent_after (List.nth_exn rows from)))
          in
          match ways_in with
          | [] -> sent
          | first :: rest ->
            Map.set sent ~key:row.pc ~data:(List.fold rest ~init:first ~f:combine))
      in
      if Map.equal Bool.equal next sent then sent else go next
    in
    go Int.Map.empty
  in
  let must_send = settle ~combine:( && ) in
  let may_send = settle ~combine:( || ) in
  let pins = sprintf "pin_out[%d +: %d]" config.out_base n in
  let row_claims =
    List.concat_map rows ~f:(fun (row : Analyser.Row.t) ->
      let r = Osr_kernel.Row.map osr.(row.pc) ~f:Bits.to_unsigned_int in
      if r.shifted_lo > r.shifted_hi
      then []
      else (
        (* a bound at either end of what the ghost can hold says nothing *)
        let bound value lo hi ~max =
          List.filter_opt
            [ Option.some_if (lo > 0) (sprintf "%s >= %d" value lo)
            ; Option.some_if (hi < max) (sprintf "%s <= %d" value hi)
            ]
        in
        let count =
          match
            bound "shifted" r.shifted_lo r.shifted_hi ~max:Osr_kernel.shift_limit
            @ bound "sum" r.sum_lo r.sum_hi ~max:((1 lsl (Isa.data_bits + 1)) - 1)
          with
          | [] -> []
          | c ->
            [ sprintf
                "      if (pc == %d) assert (%s);"
                row.pc
                (String.concat ~sep:" && " c)
            ]
        in
        let holds =
          if r.pulled = 0
          then []
          else [ sprintf "      if (pc == %d) assert (holds_word || underflow);" row.pc ]
        in
        let sent =
          if Map.find must_send row.pc |> Option.value ~default:false
          then [ sprintf "      if (pc == %d) assert (sent);" row.pc ]
          else []
        in
        (* which bits, by x, where the sum is one value and the count is not *)
        let which =
          if r.sum_lo <> r.sum_hi
             || r.shifted_lo = r.shifted_hi
             || r.pulled = 0
             || not (Map.find may_send row.pc |> Option.value ~default:false)
          then []
          else (
            let first = r.sum_lo - n in
            [ sprintf
                "      if (pc == %d && sent && holds_word)\n\
                \        assert (x <= %d && %s == bits(word, 17'd%d - {1'b0, x}, %d));"
                row.pc
                first
                pins
                first
                n
            ])
        in
        count @ holds @ sent @ which))
    |> String.concat ~sep:"\n"
  in
  let right = Program_config.Shift_direction.equal config.out_shift Right in
  let shift = if right then "w >> c" else "w << c" in
  (* the first n bits the osr shifts out, from c on *)
  let from c =
    if right
    then sprintf "shifted_by(w, %s)" c
    else sprintf "(shifted_by(w, %s) >> (5'd16 - n))" c
  in
  let monitor =
    [%string
      {|  // the word the osr last took from the host, and how many bits of it have gone out
  // since, on past 16; and whether the last write to the out pins or to the osr was an
  // out to the pins
  reg [5:0] shifted = 16;
  reg holds_word = 0;
  reg [15:0] word = 0;
  reg sent = 0;
  wire [16:0] sum = shifted + x;
  always @(posedge clk)
    if (clear) begin
      shifted <= 16;
      holds_word <= 0;
      sent <= 0;
    end else if (issue)
      case (pc)
%{actions}
      endcase
  function [15:0] shifted_by(input [15:0] w, input [5:0] c);
    shifted_by = %{shift};
  endfunction
  // the n bits of w from c on, counted from the end the osr shifts from, low bit first
  function [15:0] bits(input [15:0] w, input [5:0] c, input [4:0] n);
`ifdef NEXT_BIT
    bits = %{from "c + n"} & ((16'd1 << n) - 16'd1);
`else
    bits = %{from "c"} & ((16'd1 << n) - 16'd1);
`endif
  endfunction

|}]
  in
  let claims =
    [%string
      {|      // the count is the core's, stopped at 16, and the osr holds the word it last took
      assert (shifted <= 32 && osr_count == (shifted > 16 ? 5'd16 : shifted[4:0]));
      if (holds_word) assert (osr == shifted_by(word, shifted));
      // the pins show the bits the last out sent
      if (sent && holds_word) assert (%{pins} == bits(word, shifted - 6'd%{n#Int}, %{n#Int}));
      // the count, and which bits, at each pc
%{row_claims}
|}]
  in
  monitor, claims
;;

let anyseq_host =
  "  (* anyseq *) wire tx_valid, rx_pop;\n  (* anyseq *) wire [15:0] tx_value;\n"
;;

(* The same certificate as an invariant for induction, which holds for all time rather
   than to a depth. The program is a ROM behind the macro's port, read a cycle late as the
   macro is, so nothing about it can be wrong in the state induction starts from. At every
   cycle the core runs:

   - the instruction register holds the word at the pc and the memory's output the word
     after it, but in the second cycle of a jump, when the output is the word at the new
     pc and the register still the jump;
   - the opcode, the decode flag and the wait pin, which the core registers beside the
     word, say what the word says: they are state of their own, and induction would start
     them disagreeing with it and let a wait retire before its deadline;
   - what is left of a delay brings the next issue to the phase its row allows;
   - in a counted loop, the phase less the loop's slope times x lies in the row's offset,
     which is what carries the phase to where the loop falls through;
   - a wait that stalls has reached its row and, on a deadline, not yet the deadline;
   - x, y and p hold what the analyser says they hold on the way into the pc;
   - the pc is one the analyser reaches, and the instruction that issued last is one it
     says the pc can follow;
   - a Manchester bit's second half is pending only where the analyser says it can be;
   - where the program moves the capture, the captured edge is a cycle that has passed,
     which is what the analyser takes [mov t, capture] to load; the clock and the capture
     start together at zero and the clock has moved on by the first issue;
   - the cycles since the last pin edge are what the analyser says for the way in from
     that instruction, on the way in and while a delay or a wait holds the core, which is
     what makes the gaps between edges hold in a loop that anchors no deadline;
   - under the single-edge assumption, the capture is armed until the edge, which comes
     after the arm, and after the wait for it is as old as the analyser says. *)
let inductive
  ?period
  ?(single_capture_edge = false)
  ?(no_wrap = false)
  ?(any_data = false)
  ?(stamped = false)
  ?(data = false)
  ?(host = anyseq_host)
  ?(ports = "")
  ?extra
  ~config
  source
  =
  let program = Asm.assemble source |> ok_exn in
  let config = Asm.Program.configure program config in
  let words = Asm.Program.words program |> ok_exn in
  let rows = Analyser.analyse ?period ~single_capture_edge ~config program.instructions in
  (* each deadline wait's entry bound is the claim that it is on time *)
  (match List.filter rows ~f:(fun row -> row.may_miss) with
   | [] -> ()
   | late ->
     raise_s
       [%message
         "BUG: deadline waits the certificate cannot show on time"
           ~pcs:(List.map late ~f:(fun row -> row.pc) : int list)]);
  let config_ports =
    Engine.Config.(
      to_list
        (map2 port_names (of_program_config config) ~f:(fun name bits ->
           [%string
             ".config$%{name}(%{Bits.width bits#Int}'d%{Bits.to_unsigned_int bits#Int})"])))
    |> String.concat ~sep:",\n    "
  in
  let rom =
    List.mapi words ~f:(fun a w -> sprintf "      %d: rom = 16'h%04x;" a w)
    |> String.concat ~sep:"\n"
  in
  let within value (i : Interval.t) =
    List.filter_opt
      [ Option.map i.lo ~f:(fun lo -> sprintf "%s >= %d" value lo)
      ; Option.map i.hi ~f:(fun hi -> sprintf "%s <= %d" value hi)
      ]
  in
  let is_deadline_wait (t : Isa.t) =
    match t with
    | Op { op = Wait (Deadline _); _ } -> true
    | _ -> false
  in
  let is_wait (t : Isa.t) =
    match t with
    | Op { op = Wait _; _ } -> true
    | _ -> false
  in
  let any = function
    | [] -> "0"
    | cases -> String.concat ~sep:" || " cases
  in
  (* only a move can anchor a deadline on the capture: [in capture] passes the stamp to
     the host and the analyser takes nothing from it, and on a line that stays idle the
     stamp grows older than 24 bits can tell, so nothing is claimed of it there *)
  let moves_capture (t : Isa.t) =
    match t with
    | Op { op = Mov { source = Capture; _ }; _ } -> true
    | _ -> false
  in
  let anchors_on_capture =
    List.exists rows ~f:(fun row -> moves_capture row.instruction)
  in
  let captured_has_passed =
    if not anchors_on_capture
    then ""
    else "      assert ($signed(now - capture) >= (came_valid ? 24'sd1 : 24'sd0));\n"
  in
  let pin_writers =
    List.filter_map rows ~f:(fun row ->
      Option.some_if (writes_pins row.instruction) (sprintf "a == %d" row.pc))
    |> any
  in
  (* a count is unsigned, so a floor at or below zero says nothing and is left out *)
  let count (i : Interval.t) = { i with lo = Option.filter i.lo ~f:(fun lo -> lo > 0) } in
  let reachable = List.map rows ~f:(fun row -> sprintf "pc == %d" row.pc) |> any in
  let assert_when cond = function
    | [] -> []
    | c -> [ sprintf "      if (%s) assert (%s);" cond (String.concat ~sep:" && " c) ]
  in
  (* An age on the way into a row, at the entry and while a delay holds the core, where
     [_ahead] is the age it issues at *)
  let entering name ~way (since : Interval.t) =
    assert_when ("entry && " ^ way) (within name (count since))
    @ assert_when ("stall != 0 && " ^ way) (within (name ^ "_ahead") (count since))
  in
  (* The same age while a wait stalls, where a deadline wait keeps [_behind], the age less
     the phase, still *)
  let stalling name (row : Analyser.Row.t) (since : Interval.t) =
    if not (is_wait row.instruction)
    then []
    else (
      let at = sprintf "stalled && pc == %d" row.pc in
      let floor =
        Option.filter since.lo ~f:(fun lo -> lo + 1 > 0)
        |> Option.map ~f:(fun lo -> sprintf "%s >= %d" name (lo + 1))
        |> Option.to_list
      in
      let behind =
        if not (is_deadline_wait row.instruction)
        then []
        else (
          let bound lo hi =
            Option.bind lo ~f:(fun a -> Option.map hi ~f:(fun b -> a - b))
          in
          within
            (name ^ "_behind")
            { lo = bound since.lo row.phase.hi; hi = bound since.hi row.phase.lo })
      in
      assert_when at floor @ assert_when at behind)
  in
  let edges =
    List.concat_map rows ~f:(fun (row : Analyser.Row.t) ->
      let came_from =
        List.map row.since_edge ~f:(fun (from, _) -> sprintf "came == %d" from)
      in
      let ways_in =
        [ sprintf
            "      if (came_valid && !stalled && pc == %d) assert (%s);"
            row.pc
            (any came_from)
        ]
      in
      let way from = sprintf "came_valid && pc == %d && came == %d" row.pc from in
      let per_way =
        List.concat_map row.since_edge ~f:(fun (from, since) ->
          entering "since" ~way:(way from) since)
      in
      let gaps =
        List.concat_map row.gaps ~f:(fun (from, gap) ->
          assert_when ("entry && " ^ way from) (within "since + 1" (count gap)))
      in
      (* while a wait stalls the count runs on from its entry, which a Manchester flip the
         wait brings starts again *)
      let stalled =
        let since =
          List.map row.since_edge ~f:snd
          |> List.reduce ~f:Interval.join
          |> Option.value ~default:Interval.top
        in
        stalling
          "since"
          row
          (if Option.is_some row.flip
           then Interval.join since (Interval.exactly (-1))
           else since)
      in
      (* only the instruction after a Manchester out finds its second half pending *)
      let flip =
        if Option.is_some row.flip
        then []
        else [ sprintf "      if (pc == %d) assert (!flip_pending);" row.pc ]
      in
      ways_in @ flip @ per_way @ gaps @ stalled)
    |> String.concat ~sep:"\n"
  in
  let ages name (row : Analyser.Row.t) since =
    entering name ~way:(sprintf "pc == %d" row.pc) since @ stalling name row since
  in
  (* Under the single-edge assumption: from the arm to the wait for the edge the core
     holds the capture armed until the edge and after it an edge younger than the arm;
     from that wait on, the capture is the edge, younger than the row's arm. *)
  let edge_claims (row : Analyser.Row.t) =
    let awaiting =
      if not row.awaiting
      then []
      else (
        let waits_for_level =
          match row.instruction with
          | Op { op = Wait (Pin_level _ as wait); _ } -> Analyser.captures config wait
          | _ -> false
        in
        let bounded =
          match row.since_arm with
          | Some { hi = Some _; _ } ->
            (not (is_wait row.instruction))
            || waits_for_level
            || is_deadline_wait row.instruction
          | _ -> false
        in
        [ sprintf "      if (pc == %d) assert (holding);" row.pc ]
        @ (if waits_for_level
           then [ sprintf "      if (pc == %d && stalled) assert (!seen);" row.pc ]
           else [])
        @ Option.value_map row.since_arm ~default:[] ~f:(ages "arm_age" row)
        @
        if bounded
        then
          [ sprintf "      if (pc == %d && seen) assert (capture_age < arm_age);" row.pc ]
        else [])
    in
    (* the capture's age wraps with the clock unless [no_wrap] keeps it close *)
    let captured =
      if not row.captured
      then []
      else
        sprintf "      if (pc == %d) assert (!capture_armed);" row.pc
        ::
        (if no_wrap && anchors_on_capture
         then
           Option.value_map row.since_arm ~default:[] ~f:(fun since ->
             ages
               "capture_age"
               row
               { since with hi = Option.map since.hi ~f:(fun hi -> hi - 1) })
         else [])
    in
    awaiting @ captured
  in
  let claims =
    List.concat_map rows ~f:(fun (row : Analyser.Row.t) ->
      let conj = String.concat ~sep:" && " in
      let registers =
        within "x" row.x @ within "y" row.y @ within "p" row.period
        |> List.map ~f:(sprintf "      if (pc == %d) assert (%s);" row.pc)
      in
      let pending =
        match within "ahead" row.phase with
        | [] -> []
        | c ->
          [ sprintf "      if (pc == %d && stall != 0) assert (%s);" row.pc (conj c) ]
      in
      let entry =
        match within "phase" row.phase with
        | [] -> []
        | c -> [ sprintf "      if (pc == %d && entry) assert (%s);" row.pc (conj c) ]
      in
      let stalled =
        match row.phase.lo with
        | None -> []
        | Some lo ->
          [ sprintf
              "      if (pc == %d && stalled) assert (phase >= %d%s);"
              row.pc
              (lo + 1)
              (if is_deadline_wait row.instruction then " && phase <= 0" else "")
          ]
      in
      (* the offsets the kernel's table keeps, taken modulo the timer, as the core's own
         arithmetic is *)
      let offset =
        match Kernel.Table.offset_bounds ~slope:row.slope row.offset with
        | None -> []
        | Some (slope, lo, hi) ->
          let offset_of value =
            let offset =
              sprintf
                "$signed(%s - 24'd%d * x)"
                value
                (slope land ((1 lsl Isa.timer_bits) - 1))
            in
            sprintf "%s >= %d && %s <= %d" offset lo offset hi
          in
          [ sprintf
              "      if (pc == %d && stall != 0) assert (%s);"
              row.pc
              (offset_of "ahead")
          ; sprintf "      if (pc == %d && entry) assert (%s);" row.pc (offset_of "phase")
          ]
      in
      let edge = if single_capture_edge then edge_claims row else [] in
      registers @ pending @ entry @ offset @ stalled @ edge)
    |> String.concat ~sep:"\n"
  in
  (* induction proves anything from an invariant no state satisfies, so the teeth task
     adds a claim that is false in any run and has to fail. It names the last row, which
     no run reaches inside the base case's depth, so what fails is the induction step and
     the failure says the invariant is one some state satisfies. *)
  let teeth_pc = (List.last_exn rows).pc in
  (* Teeth bmc runs from reset: the bounded row fewest instructions from pc 0 moved a
     cycle, and a receiver's capture a cycle older or younger. *)
  let anchors_on_edge = single_capture_edge && no_wrap && anchors_on_capture in
  let moved =
    let steps = Hashtbl.create (module Int) in
    let rec walk depth = function
      | [] -> ()
      | pcs ->
        List.iter pcs ~f:(fun pc -> Hashtbl.set steps ~key:pc ~data:depth);
        List.filter_map rows ~f:(fun (row : Analyser.Row.t) ->
          Option.some_if
            ((not (Hashtbl.mem steps row.pc))
             && List.exists row.since_edge ~f:(fun (from, _) ->
               List.mem pcs from ~equal:Int.equal))
            row.pc)
        |> walk (depth + 1)
    in
    walk 0 [ 0 ];
    let tooth name claim = sprintf "`ifdef %s\n      %s\n`endif\n" name claim in
    let phase =
      List.filter_map rows ~f:(fun (row : Analyser.Row.t) ->
        match row.phase, Hashtbl.find steps row.pc with
        | { lo = Some lo; hi = Some hi }, Some depth when row.pc > 0 ->
          Some ((depth, hi - lo, row.pc), (lo, hi))
        | _ -> None)
      |> List.min_elt ~compare:(Comparable.lift [%compare: int * int * int] ~f:fst)
      |> Option.value_map ~default:"" ~f:(fun ((_, _, pc), (lo, hi)) ->
        let at by =
          sprintf
            "if (pc == %d && entry) assert (phase >= %d && phase <= %d);"
            pc
            (lo + by)
            (hi + by)
        in
        tooth "ROW_EARLY" (at (-1)) ^ tooth "ROW_LATE" (at 1))
    in
    let capture =
      if not anchors_on_edge
      then ""
      else
        List.find_map rows ~f:(fun (row : Analyser.Row.t) ->
          match row.since_arm with
          | Some { lo = Some lo; hi = Some hi }
            when row.captured && moves_capture row.instruction ->
            let claim = sprintf "if (pc == %d && entry) assert (capture_age %s %d);" in
            Some
              (tooth "CAPTURE_OLDER" (claim row.pc ">=" (lo + 1))
               ^ tooth "CAPTURE_YOUNGER" (claim row.pc "<=" (hi - 2)))
          | _ -> None)
        |> Option.value ~default:""
    in
    phase ^ capture
  in
  (* The one thing a certificate assumes of time, [no_wrap]. A wait for the host or for a
     pin can stall for as long as the world likes, so the rows after it have a floor under
     their phase and no ceiling: the core can fall arbitrarily far behind its deadline and
     24 bits of the difference wrap. A loop that anchors no deadline does the same from
     the other side, since intervals cannot say that its counter runs out, and the
     captured edge a receiver anchors on can lie as far back on a line that stays idle.
     The core's own release compares the same 24 bits, so this is a bound the hardware
     keeps as well: a deadline more than about 168 ms away at 50 MHz is one it reads the
     wrong way round. Keeping the core within 84 ms of its deadline, and of that edge,
     covers all three. *)
  let no_wrap =
    if not no_wrap
    then ""
    else
      "  // a wait for the host or a pin, or a loop that anchors no deadline, leaves\n\
      \  // rows with one side of the phase unbounded; the certificate holds while the\n\
      \  // core is within 84 ms of its deadline, half of what its 24 bits tell apart\n\
      \  always @(*) assume (phase >= -24'sd4194304 && phase <= 24'sd4194304);\n"
      ^ (if not anchors_on_capture
         then ""
         else
           "  // and as far from the edge it last captured\n\
           \  always @(*) assume ($signed(now - capture) <= 24'sd4194304);\n")
      ^ "\n"
  in
  (* What the firmware's entry in [Certified] assumes, as phase_step.sv takes it *)
  let loads_period =
    match period with
    | None -> ""
    | Some period ->
      let writers =
        List.filter_map rows ~f:(fun row ->
          match row.instruction with
          | Op { op = Mov { dest = P; _ } | Out { dest = P; _ } | Alu { dest = P; _ }; _ }
            -> Some (sprintf "pc == %d" row.pc)
          | _ -> None)
        |> any
      in
      [%string
        {|  // the period the host loads: every run-time write to p carries it
  reg wrote_p = 0;
  always @(posedge clk) wrote_p <= issue && (%{writers});
`ifndef NO_PERIOD
  always @(*) if (wrote_p) assume (p == 16'd%{period#Int});
`endif

|}]
  in
  let single_edge =
    if not single_capture_edge
    then ""
    else (
      let at ~f =
        List.filter_map rows ~f:(fun row ->
          Option.some_if (f row.instruction) (sprintf "pc == %d" row.pc))
        |> any
      in
      let arms =
        at ~f:(function
          | Op { op = Sys Capture_arm; _ } -> true
          | _ -> false)
      in
      let waits_for_edge =
        at ~f:(function
          | Op { op = Wait wait; _ } -> Analyser.captures config wait
          | _ -> false)
      in
      [%string
        {|  // the single-edge assumption, on the level the core sees: the capture pin is at the
  // other level when capture_arm issues, and once at the captured level it stays there
  // until a wait for it releases
  wire level = eng_sample[%{config.capture_pin#Int}] == %{Bool.to_int config.capture_rising#Int};
  wire arms = issue && (%{arms});
  reg holding = 0, seen = 0;
  always @(posedge clk)
    if (start) begin
      holding <= 0;
      seen <= 0;
    end else if (arms) begin
      holding <= 1;
      seen <= 0;
    end else if (issue && eng_advance && (%{waits_for_edge})) holding <= 0;
    else if (holding && level) seen <= 1;
  always @(*) begin
`ifndef LEVEL_AT_ARM
    if (arms) assume (!level);
`endif
    if (holding && seen) assume (level);
  end
  // cycles since the arm, and since the edge the core last captured
  reg [23:0] arm_age = 0;
  always @(posedge clk)
    arm_age <= arms ? 24'd1 : arm_age == 24'hffffff ? arm_age : arm_age + 24'd1;
  wire [24:0] arm_age_ahead = arm_age + stall;
  wire signed [25:0] arm_age_behind = $signed({2'b0, arm_age}) - phase;
  wire [23:0] capture_age = now - capture;
  wire [24:0] capture_age_ahead = capture_age + stall;
  wire signed [25:0] capture_age_behind = $signed({2'b0, capture_age}) - phase;

|}])
  in
  let edge_wires, edge_ports, holds_capture =
    if not single_capture_edge
    then "", "", ""
    else
      ( "  wire eng_advance, capture_armed;\n  wire [27:0] eng_sample;\n"
      , ".eng_advance(eng_advance), .eng_sample(eng_sample), \
         .capture_armed(capture_armed),\n\
        \    "
      , "      if (holding) assert (seen ? !capture_armed : capture_armed);\n" )
  in
  let stamp_monitor, stamp_claims =
    if stamped then stamp_claims ~config rows else "", ""
  in
  let data_monitor, data_claims =
    if data then data_claims ~config ~words rows else "", ""
  in
  let extra_monitor, extra_claims =
    match extra with
    | Some extra -> extra ~config rows
    | None -> "", ""
  in
  let wrap_top = config.wrap_top in
  let wrap_bottom = config.wrap_bottom in
  (* a table interpreter's data memory, free in every cycle, as I1 has it *)
  let data_wire, data_dout =
    if any_data
    then "  (* anyseq *) wire [15:0] data_dout;\n", "data_dout"
    else "", "16'b0"
  in
  [%string
    {|// Generated by test/certify/write_certificate.exe -inductive: the analyser's certificate
// as an invariant of the RTL, for every input and every host, proved by induction.
module certificate (input clk);
%{host}  (* anyseq *) wire [27:0] inputs;
%{data_wire}
  function [15:0] rom(input [8:0] a);
    case (a)
%{rom}
      default: rom = 0;
    endcase
  endfunction
  function [8:0] after(input [8:0] a);
    after = a == %{wrap_top#Int} ? %{wrap_bottom#Int} : a + 9'd1;
  endfunction

  reg [1:0] boot = 0;
  always @(posedge clk) if (boot != 3) boot <= boot + 1;
  wire clear = boot == 0;
  wire start = boot == 1;
  wire running = boot == 3;

  function writes_pins(input [8:0] a);
    writes_pins = %{pin_writers};
  endfunction

  wire [8:0] sram_addr, pc;
  reg [15:0] fetched;
  always @(posedge clk) fetched <= rom(sram_addr);
  wire [23:0] t, now, capture;
  wire [15:0] x, y, p, osr, instruction, tx_head;
  wire [4:0] osr_count;
  wire underflow, tx_empty;
  wire [27:0] pin_out;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
  wire [27:0] wait_pin = 28'd1 << instruction[4:0];
  wire [4:0] stall;
  wire halted, decode_ok, eng_issue, eng_jmp_go, flip_pending;
%{edge_wires}  engine_top dut (
    .clock(clk), .clear(clear),
    %{config_ports},
    .start(start), .program_write$valid(1'b0), .program_write$addr(9'b0),
    .program_write$data(16'b0), .data_write$valid(1'b0), .data_write$addr(9'b0),
    .data_write$data(16'b0), .tx$valid(tx_valid), .tx$value(tx_value), .rx_pop(rx_pop),
    .clear_irq(1'b0), .stop(1'b0), .flush(1'b0),
    .inputs(inputs), .sram_addr(sram_addr), .sram_dout(fetched), .data_sram_dout(%{data_dout}),
    .pin_out(pin_out), .pc(pc), .t(t), .now(now), .capture(capture), .x(x), .y(y), .p(p),
    .osr(osr), .osr_count(osr_count), .stall(stall),
    .fault$underflow(underflow), .halted(halted), .instruction(instruction), .decode_ok(decode_ok),
    .opcode_onehot(opcode_onehot), .wait_select(wait_select), .flip_pending(flip_pending),
    %{ports}%{edge_ports}.eng_issue(eng_issue),
    .eng_jmp_go(eng_jmp_go), .eng_tx_head(tx_head),
    .eng_tx_empty(tx_empty));

  // the engine's own signals, not a shadow of them worked out from the delay left: in the
  // state induction starts from the two come apart
  reg started = 0;
  always @(posedge clk) started <= start;
  wire issue = running && eng_issue && !started;
  // the second cycle of a jump: the core took one and is fetching at the target
  reg jumped = 0;
  always @(posedge clk) jumped <= start || eng_jmp_go;
  reg last_issue = 0;
  reg [8:0] last_pc = 0;
  always @(posedge clk) begin
    last_issue <= issue;
    last_pc <= pc;
  end
  wire entry = issue && !(last_issue && last_pc == pc);
  wire stalled = issue && last_issue && last_pc == pc;
  wire signed [23:0] phase = now - t;
  // the phase the pending instruction issues at, once the delay runs out
  wire signed [23:0] ahead = now - t + {19'b0, stall};

  // cycles since the last pin edge showed, which is the cycle after a pin write issues
  // or the instruction after a Manchester out, whose second half comes with it
  wire edge_now = issue && (writes_pins(pc) || flip_pending);
  reg [23:0] since = 0;
  always @(posedge clk) since <= edge_now ? 24'd0 : since == 24'hffffff ? since : since + 1;
  wire [24:0] since_ahead = since + stall;
  wire signed [25:0] since_behind = $signed({2'b0, since}) - phase;
  // the instruction that issued last, the one the analyser calls the way in
  reg came_valid = 0;
  reg [8:0] came = 0;
  always @(posedge clk)
    if (start) came_valid <= 0;
    else if (entry) begin
      came_valid <= 1;
      came <= pc;
    end

%{loads_period}%{single_edge}%{stamp_monitor}%{data_monitor}%{extra_monitor}%{no_wrap}  always @(*)
    if (running) begin
      assert (!halted && !started);
%{captured_has_passed}%{holds_capture}      assert (decode_ok && opcode_onehot == (8'd1 << instruction[15:13]));
      assert (wait_select == wait_pin);
      if (!jumped) assert (instruction == rom(pc) && fetched == rom(after(pc)));
      if (jumped) assert (stall == 1 && fetched == rom(pc));
      if (stalled) assert (instruction[15:13] == 1);
      assert (%{reachable});
      // until the first issue after the start, nothing has issued to come from
      if (!came_valid) assert (pc == 0 && stall == 0);
      // and a wait that stalls came last itself
      if (stalled) assert (came_valid && came == pc);
%{claims}
%{edges}
%{stamp_claims}%{data_claims}%{extra_claims}%{moved}`ifdef TEETH
      assert (pc != %{teeth_pc#Int});
`endif
    end
endmodule
|}]
;;

(* The miter for [Fsm_compiler]: [Uart.Tx] of hardcaml_hobby_boards, unmodified, beside
   the engine running what the compiler makes of it at 4 clocks per bit. The host writes
   each byte the circuit takes, and the engine's pin is the circuit's line 4 cycles later,
   given a byte comes at least 4 cycles after the circuit is ready. The coupling
   invariants are written by hand for this machine. *)
let lag = 4
let gap = 4
let clocks_per_bit = 4

let fsm_miter ~mutant =
  let module Uart =
    Hobby_uart_tx.Make (struct
      let clocks_per_bit = clocks_per_bit
    end)
  in
  let compiled =
    let scope = Scope.create ~flatten_design:true () in
    let module C = Circuit.With_interface (Hobby_uart_tx.I) (Hobby_uart_tx.Pin) in
    Fsm_compiler.compile (C.create_exn ~name:"hobby_uart_tx" (Uart.pin scope)) |> ok_exn
  in
  (* flat, with the registers the invariants name brought out as ports *)
  let circuit_verilog =
    let scope = Scope.create ~flatten_design:true () in
    let module C = Circuit.With_interface (Hobby_uart_tx.I) (Hobby_uart_tx.O) in
    let circuit = C.create_exn ~name:"source" (Uart.hierarchical scope) in
    let probe name ~f =
      match
        Signal_graph.filter (Circuit.signal_graph circuit) ~f:(fun s ->
          Signal.Type.is_reg s && f s)
      with
      | [ s ] -> Signal.output name s
      | _ -> raise_s [%message "BUG: no one register" (name : string)]
    in
    let named name s =
      List.exists (Signal.names s) ~f:(String.is_suffix ~suffix:("$" ^ name))
    in
    let probes =
      List.map [ "enable_rate"; "data_count"; "sm_tx" ] ~f:(fun name ->
        probe name ~f:(named name))
      (* the shift register is the one nine bits wide, and has no name *)
      @ [ probe "txdata" ~f:(fun s -> Signal.width s = 9) ]
    in
    [ Circuit.create_exn ~name:"source" (Circuit.outputs circuit @ probes) ]
    |> Rtl.create Verilog
    |> Rtl.full_hierarchy
    |> Rope.to_string
  in
  (* the teeth: a compiler one short in its bit count *)
  let source =
    if not mutant
    then compiled.source
    else (
      let source =
        String.substr_replace_first compiled.source ~pattern:"set x, 7" ~with_:"set x, 6"
      in
      if String.equal source compiled.source then raise_s [%message "BUG: no set x, 7"];
      source)
  in
  let label name =
    String.split_lines source
    |> List.map ~f:String.strip
    |> List.filter ~f:(fun line ->
      (not (String.is_empty line)) && not (String.is_prefix line ~prefix:";"))
    |> List.fold_until
         ~init:0
         ~f:(fun pc line ->
           if String.equal line (name ^ ":")
           then Stop pc
           else Continue (if String.is_suffix line ~suffix:":" then pc else pc + 1))
         ~finish:(fun _ -> raise_s [%message "BUG: no label" (name : string)])
  in
  let start = label "start" in
  let data = label "data" in
  let stop = label "stop" in
  let complete = label "complete" in
  let host =
    "  (* anyseq *) wire rx_pop, data_in_valid;\n\
    \  (* anyseq *) wire [8:0] data_in;\n\
    \  wire txd, data_in_ready;\n\
    \  wire tx_valid = data_in_valid && data_in_ready;\n\
    \  wire [15:0] tx_value = {7'b0, data_in};\n\
    \  wire [3:0] tx_level, fifo_used, fifo_used_minus_1, fifo_used_plus_1;\n\
    \  wire fifo_used_is_one, fifo_used_gt_one, fifo_not_empty, fifo_full, \
     fifo_nearly_full;\n"
  in
  let ports =
    ".tx_level(tx_level), .fifo_used(fifo_used),\n\
    \    .fifo_used_minus_1(fifo_used_minus_1), .fifo_used_plus_1(fifo_used_plus_1),\n\
    \    .fifo_used_is_one(fifo_used_is_one), .fifo_used_gt_one(fifo_used_gt_one),\n\
    \    .fifo_not_empty(fifo_not_empty), .fifo_full(fifo_full),\n\
    \    .fifo_nearly_full(fifo_nearly_full),\n\
    \    "
  in
  let extra ~(config : Program_config.t) (_ : Analyser.Row.t list) =
    let monitor =
      [%string
        {|  wire [15:0] enable_rate;
  wire [3:0] data_count;
  wire [2:0] sm_tx;
  wire [8:0] txdata;
  source circuit (
    .clock(clk), .clear(clear), .data_in(data_in), .data_in_valid(data_in_valid),
    .txd(txd), .data_in_ready(data_in_ready), .enable_rate(enable_rate),
    .data_count(data_count), .sm_tx(sm_tx), .txdata(txdata));
  localparam START = 0, DATA = 1, PARITY = 2, STOP = 3, COMPLETE = 4;
  wire [15:0] e = enable_rate;
  // the circuit's line, %{lag#Int} cycles back
  reg [%{lag - 1#Int}:0] line = 0;
  always @(posedge clk) line <= {line[%{lag - 2#Int}:0], txd};
  // cycles since the clear, and since the circuit last became ready
  reg [4:0] age = 0, ready_for = 0;
  always @(posedge clk) begin
    age <= clear ? 5'd0 : age == 5'd31 ? age : age + 5'd1;
    ready_for <= clear || !data_in_ready ? 5'd0 : ready_for == 5'd31 ? ready_for : ready_for + 5'd1;
  end
`ifdef SHORT_GAP
  always @(*) assume (!tx_valid || ready_for >= %{gap - 1#Int});
`else
  always @(*) assume (!tx_valid || ready_for >= %{gap#Int});
`endif
  wire pin = pin_out[%{config.out_base#Int}];
  // the engine's place in the loop that sends a bit, by the circuit's tick
  wire in_loop = e == 0 ? pc == %{data + 2#Int} : e == 3 ? pc == %{data + 1#Int}
    : pc == %{data#Int} && stall == (e == 1);

|}]
    in
    let claims =
      [%string
        {|`ifndef CLAIM_ONLY
      // the tx fifo's counters agree with its level
      assert (fifo_used == tx_level && fifo_used_minus_1 == tx_level - 4'd1
        && fifo_used_plus_1 == tx_level + 4'd1 && fifo_used_is_one == (tx_level == 1)
        && fifo_used_gt_one == (tx_level > 1) && fifo_not_empty == (tx_level != 0)
        && !fifo_full && !fifo_nearly_full);
      // the circuit: in range, and ready only in Start
      assert (sm_tx != PARITY && sm_tx <= COMPLETE && e < %{clocks_per_bit#Int} && data_count <= 8);
      assert (data_in_ready == (sm_tx == START) && age >= 2 && ready_for <= age);
      if (sm_tx == START) assert (e == 0);
      // a byte taken waits in the fifo for two cycles, and is then osr, less the bits sent
      if (sm_tx == DATA && data_count == 0 && e <= 1)
        assert (tx_level == 1 && tx_head == {7'b0, txdata});
      else assert (tx_level == 0);
      if (sm_tx == DATA && data_count == 0 && e >= 2) assert (osr == {7'b0, txdata});
      if ((sm_tx == DATA && data_count != 0) || sm_tx == STOP)
        assert (osr == {6'b0, txdata, txd});
      // the engine's pc, x and delay by the circuit's state and tick
      if (sm_tx == START)
        assert (ready_for >= %{gap#Int} ? pc == %{start#Int}
          : age == ready_for ? pc == (age <= 2 ? 0 : 1)
          : ready_for <= 2 ? pc == %{complete#Int} : pc == %{complete + 1#Int});
      if (sm_tx == DATA && data_count == 0) assert (pc == %{start#Int} + e);
      if (sm_tx == DATA && data_count == 1) assert (pc == %{start + 4#Int} + e);
      if (sm_tx == DATA && data_count >= 2)
        assert (in_loop && x == (e == 0 ? 9 : 8) - data_count);
      if (sm_tx == STOP) assert (data_count == 8 && in_loop && x == (e == 0));
      if (sm_tx == COMPLETE)
        assert (data_count == 8 && (e == 0 ? pc == %{data + 2#Int} && x == 0
          : e == 3 ? pc == %{stop + 1#Int} : pc == %{stop#Int} && stall == (e == 1)));
`endif
      // the pin is the circuit's line %{lag#Int} cycles back, once both have left the clear
`ifdef EARLY
      if (age >= %{2 * lag#Int}) assert (pin == line[%{lag - 2#Int}]);
`else
      if (age >= %{2 * lag#Int}) assert (pin == line[%{lag - 1#Int}]);
`endif
|}]
    in
    monitor, claims
  in
  "// write_certificate.exe -fsm: the certificate below carries the engine through the\n\
   // induction; the host is the circuit's handshake, not any host.\n"
  ^ inductive ~host ~ports ~extra ~config:compiled.config source
  ^ "\n"
  ^ circuit_verilog
;;

(* pico-examples programs as pio_import translates them, at the k their lockstep runs at *)
let translated =
  [ "pio_uart_tx", ("uart_tx.pio", "uart_tx", 8.)
  ; "pio_ws2812", ("ws2812.pio", "ws2812", 6.25)
  ; "pio_spi_cpha0", ("spi.pio", "spi_cpha0", 8.)
  ; "pio_manchester_tx", ("manchester_encoding.pio", "manchester_tx", 7.)
  ]
;;

let translated_exn name =
  let file, wanted, k = List.Assoc.find_exn translated name ~equal:String.equal in
  let program =
    In_channel.read_all ("pio/test/pico_examples/" ^ file)
    |> Pio.Pioasm.parse
    |> ok_exn
    |> List.find_exn ~f:(fun (p : Pio.Pioasm.Program.t) -> String.equal p.name wanted)
  in
  match Pio.Census.certify program ~k with
  | Ok (t, _) -> Certified.plain ~no_wrap:true name t.source t.config
  | Error verdict -> raise_s [%sexp (verdict : Pio.Census.Verdict.t)]
;;

let () =
  let args = Sys.get_argv () in
  let flag name = Array.exists args ~f:(String.equal name) in
  if flag "-fsm"
  then print_string (fsm_miter ~mutant:(flag "-mutant"))
  else if flag "-names"
  then
    (* every certificate formal/Makefile proves by induction, for CI's jobs *)
    List.map (Library.certified @ Library.time_triggered) ~f:(fun t -> t.name)
    @ List.map translated ~f:fst
    |> String.concat ~sep:" "
    |> print_endline
  else (
    if not (flag "-inductive")
    then raise_s [%message "write_certificate.exe: pass -inductive, -names or -fsm"];
    let name = Array.last_exn args in
    let { Certified.source; config; period; single_capture_edge; no_wrap; any_data; _ } =
      if List.Assoc.mem translated name ~equal:String.equal
      then translated_exn name
      else Library.find_certified_exn name
    in
    print_string
      (inductive
         ?period
         ~single_capture_edge
         ~no_wrap
         ~any_data
         ~stamped:(flag "-stamped")
         ~data:(flag "-data")
         ~config
         source))
;;
