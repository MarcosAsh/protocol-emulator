open! Core
open Protocol_emulator
open Protocol_models

let unit = 1 lsl Isa.fraction_bits

module Receiver = struct
  type t =
    { firmware : Certified.t
    ; nominal : int
    ; preload : int list
    ; idle : int
    ; bits : int array
    ; expected : int list
    ; wired : sender:int -> pin_out:int -> int
    }

  let plain ~sender ~pin_out:_ = sender
  let every_byte = List.init 256 ~f:Fn.id

  let uart ?(bytes = every_byte) ~firmware ~nominal ~preload () =
    let frame byte = (0 :: List.init 8 ~f:(fun i -> (byte lsr i) land 1)) @ [ 1 ] in
    { firmware
    ; nominal
    ; preload
    ; idle = 1
    ; bits = Array.of_list (List.concat_map bytes ~f:frame)
    ; expected = bytes
    ; wired = plain
    }
  ;;

  let uart_rx ?bytes ?source ~period () =
    let source = Option.value source ~default:(Uart.rx ~period) in
    uart
      ?bytes
      ~firmware:(Certified.receiver "uart_rx" source Uart.rx_config)
      ~nominal:period
      ~preload:[]
      ()
  ;;

  let uart_rx_host_rate ?bytes ?(source = Uart.rx_host_rate) ~half () =
    uart
      ?bytes
      ~firmware:
        (Certified.receiver ~period:half "uart_rx_host_rate" source Uart.rx_config)
      ~nominal:(2 * half)
      ~preload:[ half ]
      ()
  ;;

  let usb_word (line : Usb_ls.Line.t) =
    match line with
    | J -> 1 lsl Usb.rx_dm_pin
    | K -> 1 lsl Usb.rx_dp_pin
    | Se0 -> 0
  ;;

  (* DATA0 packets of eight bytes, every byte once and then all ones, the longest a low
     speed packet stuffs to, a J apart *)
  let usb_rx () =
    let packets =
      List.chunks_of every_byte ~length:8 @ [ List.init 8 ~f:(fun _ -> 0xff) ]
      |> List.map ~f:(fun payload ->
        let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes payload) in
        (0xc3 :: payload) @ [ crc land 0xff; crc lsr 8 ])
    in
    { firmware = Library.find_certified_exn "usb_rx"
    ; nominal = 32
    ; preload = [ 32 ]
    ; idle = usb_word J
    ; bits =
        (* the first again, so the last one's end has a packet after it *)
        List.concat_map
          (packets @ [ List.hd_exn packets ])
          ~f:(fun packet -> Usb_ls.encode packet @ [ J ])
        |> List.map ~f:usb_word
        |> Array.of_list
    ; expected =
        List.concat_map
          (packets @ [ List.hd_exn packets ])
          ~f:(fun packet ->
            List.map (0x80 :: packet) ~f:(fun byte -> byte lsl 8)
            @ [ Usb_ls.residual packet ])
    ; wired = plain
    }
  ;;

  (* A frame on the bus from SOF to the ACK slot, which the sender leaves recessive, then
     the ACK delimiter, EOF and two bits of intermission: the next SOF is the third. *)
  let can_line frame =
    let line = Can.line frame in
    List.take line (List.length line - 12) @ List.init 11 ~f:(fun _ -> true)
  ;;

  (* the bits from each recessive-to-dominant edge to the next, SOF to SOF *)
  let can_segments frame =
    let falls =
      List.filter_mapi (can_line frame) ~f:(fun i level -> Option.some_if (not level) i)
      |> List.filter ~f:(fun i -> i = 0 || List.nth_exn (can_line frame) (i - 1))
    in
    let ends = List.tl_exn falls @ [ List.length (can_line frame) ] in
    List.map2_exn falls ends ~f:(fun a b -> b - a)
  ;;

  (* Seeded frames, kept where one has the longest segment inside a frame, five dominant
     bits and five recessive, or the longest from the CRC's last fall to the next SOF. *)
  let can_frames =
    let state = Random.State.make [| 2026 |] in
    let random () =
      let dlc = Random.State.int_incl state 0 8 in
      Can.Frame.data
        ~id:(Random.State.int state (1 lsl 11))
        (List.init dlc ~f:(fun _ -> Random.State.int state 256))
    in
    let candidates = List.init 4000 ~f:(fun _ -> random ()) in
    let longest ~f =
      List.max_elt candidates ~compare:(Comparable.lift Int.compare ~f)
      |> Option.value_exn
    in
    let inside frame =
      List.drop_last_exn (can_segments frame) |> List.fold ~init:0 ~f:Int.max
    in
    let tail frame = List.last_exn (can_segments frame) in
    Can.Frame.
      [ data ~id:0x123 [ 0xde; 0xad ]
      ; data ~id:0x555 [ 0x00; 0xff; 0x55; 0xaa; 0x01; 0x80; 0x7f; 0xfe ]
      ; data ~id:0x7ff (List.init 8 ~f:(fun _ -> 0xff))
      ; data ~id:0 (List.init 8 ~f:(fun _ -> 0))
      ; remote ~id:0xf0 ~dlc:4
      ; longest ~f:inside
      ; longest ~f:tail
      ]
  ;;

  let can_rx ~period ~sample () =
    let rx = 1 lsl Can_node.rx_pin in
    let source = Can_node.Receiver.source ~period ~sample in
    { firmware = Certified.receiver ~period "can_rx" source Can_node.Receiver.config
    ; nominal = period
    ; preload = []
    ; idle = rx
    ; bits =
        List.concat_map (can_frames @ [ List.hd_exn can_frames ]) ~f:can_line
        |> List.map ~f:(fun level -> if level then rx else 0)
        |> Array.of_list
    ; expected =
        List.concat_map
          (can_frames @ [ List.hd_exn can_frames ])
          ~f:Can_node.Receiver.words
    ; wired =
        (fun ~sender ~pin_out ->
          if (pin_out lsr Can.tx_pin) land 1 = 1 then sender else sender land lnot rx)
    }
  ;;
end

module Read = struct
  type t =
    { pc : int
    ; d : int * int
    ; since : int
    ; until : int option
    ; edge : int [@sexp_drop_if Fn.const true]
    }
  [@@deriving sexp_of]
end

module Bounds = struct
  type t =
    { least : int
    ; most : int
    ; fastest_read : Read.t
    ; slowest_read : Read.t
    ; fast_witness : int
    ; slow_witness : int
    }
  [@@deriving sexp_of]

  let ppm t ~nominal =
    let m = nominal * unit in
    (m - t.least) * 1_000_000 / m, (t.most - m) * 1_000_000 / m
  ;;
end

(* the bit the sender shows at [cycle], once it has begun *)
let bit_at ~start ~m ~phase cycle =
  if cycle < start
  then None
  else Some (((((cycle - start + 1) * unit) - phase + m - 1) / m) - 1)
;;

(* long enough for the CAN receiver's eleven idle bits *)
let lead (r : Receiver.t) = 16 * r.nominal

let signed x =
  let x = x land ((1 lsl Isa.timer_bits) - 1) in
  if x >= 1 lsl (Isa.timer_bits - 1) then x - (1 lsl Isa.timer_bits) else x
;;

let assemble (r : Receiver.t) =
  let program = Asm.assemble r.firmware.source |> ok_exn in
  let config = Asm.Program.configure program r.firmware.config in
  program, config
;;

module Run = struct
  type t =
    { words : int list
    ; irqs : int
    ; fault : Machine.Fault.t
    }
end

(* The receiver on the sender at [m] and [phase]; the host reads every word and clears
   every irq. [observe] sees the core before each cycle. *)
let run ?(observe = fun (_ : Machine.t) -> ()) (r : Receiver.t) ~m ~phase =
  let program, config = assemble r in
  let machine =
    List.fold
      r.preload
      ~init:
        (Machine.create ~config ~program:(Asm.Program.words program |> ok_exn) |> ok_exn)
      ~f:(fun t word -> Machine.write_tx t word |> ok_exn)
  in
  let start = lead r in
  let length = Array.length r.bits in
  let cycles = start + (length * m / unit) + (4 * r.nominal) in
  let rec drain (t : Machine.t) words =
    match Machine.read_rx t with
    | Some (word, t) -> drain t (word :: words)
    | None -> t, words
  in
  let t, words, irqs =
    List.fold
      (List.range 0 cycles)
      ~init:(machine, [], 0)
      ~f:(fun (t, words, irqs) cycle ->
        observe t;
        let sender =
          match bit_at ~start ~m ~phase cycle with
          | Some k when k < length -> r.bits.(k)
          | _ -> r.idle
        in
        let t = Machine.step t ~inputs:(r.wired ~sender ~pin_out:t.pin_out) in
        let t, words = drain t words in
        if t.irq then Machine.clear_irq t, words, irqs + 1 else t, words, irqs)
  in
  { Run.words = List.rev words; irqs; fault = t.fault }
;;

let receives r ~m ~phase =
  let run = run r ~m ~phase in
  [%equal: int list] run.words r.expected
  && run.irqs = 0
  && Machine.Fault.equal run.fault Machine.Fault.none
;;

let range ~base ~count = ((1 lsl count) - 1) lsl base

(* the pins an instruction reads, a capture's arm reading the capture pin *)
let read_mask (config : Program_config.t) (instruction : Isa.t) =
  match instruction with
  | Jmp { cond = Pin | Not_pin; _ } -> Some (1 lsl config.jmp_pin)
  | Op { op = In { source = Pins; count }; _ } -> Some (range ~base:config.in_base ~count)
  | Op { op = Mov { source = Pins; _ }; _ } ->
    Some (range ~base:config.in_base ~count:config.in_count)
  | Op { op = Sys Capture_arm; _ } -> Some (1 lsl config.capture_pin)
  | _ -> None
;;

module Issue = struct
  type t =
    { pc : int
    ; now : int
    ; deadline : int
    ; wait : bool
    }
end

module Seen = struct
  type t =
    { issue : Issue.t
    ; mask : int
    ; anchor : int
    ; before : Issue.t list (** What issued since the last wait, latest first. *)
    }
end

(* An arm with a jump on the capture pin right after it checks for an edge that came
   first, which the firmware then times another way: neither bounds the sender. *)
let recovers (config : Program_config.t) (instructions : Isa.t list) =
  List.concat_mapi
    (List.zip_exn (List.drop_last_exn instructions) (List.tl_exn instructions))
    ~f:(fun pc pair ->
      match pair with
      | Op { op = Sys Capture_arm; _ }, Jmp { cond = Pin | Not_pin; _ }
        when config.jmp_pin = config.capture_pin -> [ pc; pc + 1 ]
      | _ -> [])
;;

let reads (r : Receiver.t) =
  let program, config = assemble r in
  let recovers = recovers config program.instructions in
  let rows =
    Analyser.analyse
      ?period:r.firmware.period
      ~single_capture_edge:r.firmware.single_capture_edge
      ~config
      program.instructions
    |> Array.of_list
  in
  let anchor = ref None in
  let since_wait = ref [] in
  let seen = Queue.create () in
  let observe (t : Machine.t) =
    if t.stall = 0 && not t.halted
    then (
      let instruction =
        Isa.of_word ~side_set_count:config.side_set_count t.program.(t.pc) |> ok_exn
      in
      let issue =
        { Issue.pc = t.pc
        ; now = t.now
        ; deadline = t.t
        ; wait =
            (match instruction with
             | Op { op = Wait _; _ } -> true
             | _ -> false)
        }
      in
      (match read_mask config instruction, !anchor with
       | Some mask, Some anchor when not (List.mem recovers t.pc ~equal) ->
         Queue.enqueue seen { Seen.issue; mask; anchor; before = !since_wait }
       | _ -> ());
      since_wait := if issue.wait then [] else issue :: !since_wait;
      match instruction with
      | Op { op = Mov { dest = T; source = Capture; _ }; _ } -> anchor := Some t.capture
      | Op { op = Mov { dest = T; _ }; _ } -> anchor := None
      | _ -> ())
  in
  let m = r.nominal * unit in
  let run = run r ~m ~phase:0 ~observe in
  if not ([%equal: int list] run.words r.expected && run.irqs = 0)
  then raise_s [%message "BUG: the receiver fails at its own rate" r.firmware.name];
  let start = lead r in
  let length = Array.length r.bits in
  let bit cycle = bit_at ~start ~m ~phase:0 cycle |> Option.value_exn in
  Queue.to_list seen
  |> List.filter_map ~f:(fun (s : Seen.t) ->
    let k = bit s.issue.now in
    if k >= length
    then None
    else (
      let e = bit s.anchor in
      if start + (e * r.nominal) <> s.anchor
      then raise_s [%message "BUG: a capture off the sender's edges" (s.anchor : int)];
      (* each row from the last wait to the read bounds it, by its phase and the cycles
         since, which the instructions between fix; the read is in all of them *)
      let from (issue : Issue.t) ~gap =
        let phase = signed (issue.now - issue.deadline) in
        match rows.(issue.pc).phase with
        | { lo = Some lo; hi = Some hi } ->
          if phase < lo || phase > hi
          then
            raise_s
              [%message
                "BUG: a read outside its row"
                  (issue.pc : int)
                  (phase : int)
                  (rows.(issue.pc).phase : Interval.t)];
          Some
            ( signed (issue.deadline - s.anchor) + lo + gap
            , signed (issue.deadline - s.anchor) + hi + gap )
        | _ -> None
      in
      let d =
        List.filter_map (s.issue :: s.before) ~f:(fun before ->
          from before ~gap:(s.issue.now - before.now))
        |> List.reduce ~f:(fun (lo, hi) (lo', hi') -> Int.max lo lo', Int.min hi hi')
        |> Option.value_exn ~message:"BUG: a read with no row to time it"
      in
      let level j = r.bits.(j) land s.mask in
      let rec first j = if j > 0 && level (j - 1) = level k then first (j - 1) else j in
      let rec last j =
        if j + 1 < length && level (j + 1) = level k then last (j + 1) else j
      in
      let r1 = last k in
      let until =
        if r1 + 1 < length
        then Some (r1 + 1 - e)
        else if r.idle land s.mask = level k
        then None
        else Some (length - e)
      in
      Some { Read.pc = s.issue.pc; d; since = first k - e; until; edge = e }))
;;

(* An arm checked for an edge that came first, at more than one place, is a receiver that
   re-anchors on every edge and, when it sees one late, on [now]: the reads after that are
   timed from no captured edge, so no bound from the rows holds for it. One such arm, as
   the CAN receiver's at the SOF, starts a frame and leaves the rest timed. *)
let applies (r : Receiver.t) =
  let program, config = assemble r in
  let arms = List.length (recovers config program.instructions) / 2 in
  if arms > 1
  then
    Or_error.error_s
      [%message
        "formula does not apply: re-anchors on every edge, from [now] where it saw one \
         late"
          r.firmware.name
          (arms : int)]
  else Ok ()
;;

let bounds r =
  applies r |> ok_exn;
  let reads = reads r in
  let slowest =
    List.filter_map reads ~f:(fun read ->
      if read.since > 0 then Some (unit * fst read.d / read.since, read) else None)
  in
  let fastest =
    List.filter_map reads ~f:(fun read ->
      Option.map read.until ~f:(fun u -> ((unit * (snd read.d + 1)) + u - 1) / u, read))
  in
  let most, slowest_read =
    List.min_elt slowest ~compare:(Comparable.lift Int.compare ~f:fst) |> Option.value_exn
  in
  let least, fastest_read =
    List.max_elt fastest ~compare:(Comparable.lift Int.compare ~f:fst) |> Option.value_exn
  in
  (* the phases that put the binding read's edge last in its cycle, or first, one step
     past the bound *)
  let at_edge (read : Read.t) ~m ~phase = (phase - (read.edge * m)) % unit in
  { Bounds.least
  ; most
  ; fastest_read
  ; slowest_read
  ; fast_witness = at_edge fastest_read ~m:(least - 1) ~phase:0
  ; slow_witness = at_edge slowest_read ~m:(most + 1) ~phase:(unit - 1)
  }
;;

(* bit k of the stimulus starts floor(k * m / 2^16) cycles in, so the captured edge at bit
   e sits at phase e * m mod 2^16 *)
let predicts r =
  let reads = reads r in
  fun ~m ->
    List.for_all reads ~f:(fun (read : Read.t) ->
      let phase = read.edge * m % unit in
      let after bits = (phase + (bits * m)) / unit in
      (read.since <= 0 || after read.since <= fst read.d)
      && Option.for_all read.until ~f:(fun u -> after u >= snd read.d + 1))
;;

module Bench = struct
  let half = 2500
  let line = Isa.num_pins + 6
  let bytes = List.init 64 ~f:Fn.id
  let receiver = Receiver.uart_rx_host_rate ~bytes ~half ()

  let sender =
    {|
    wait tx
    pull
    mov p, osr               ; the bit period's whole cycles, the rest in the config
    set pins, 1              ; idle high
idle:
    wait tx                  ; a burst's first byte
    pull
    mov t, now               ; the burst's one anchor, its fraction cleared
    add t, p
frame:
    wait t+
    set pins, 0              ; start bit
    set x, 7
bit:
    wait t+
    out pins, 1
    jmp x--, bit
    wait t+
    set pins, 1              ; stop bit
    jmp !tx, idle            ; no byte ready: the burst is over
    pull
    jmp frame
|}
  ;;

  let sender_config = { Program_config.default with out_base = line; set_base = line }
  let receiver_source = Uart.rx_host_rate_on ~pin:line

  let receiver_config =
    { Uart.rx_config with in_base = line; jmp_pin = line; capture_pin = line }
  ;;

  let steps () =
    let b = bounds receiver in
    let predicts = predicts receiver in
    let nominal = 2 * half * unit in
    let near = [ 0; 1; 2; 3; 4; 6; 8; 12; 16; 24; 32; 48; 64; 128; 256; 512; 1024 ] in
    let percent =
      List.range (-14) 15 |> List.map ~f:(fun h -> nominal + (h * nominal / 200))
    in
    List.concat
      [ List.map near ~f:(fun d -> b.least - d)
      ; List.map near ~f:(fun d -> b.least + d)
      ; List.map near ~f:(fun d -> b.most - d)
      ; List.map near ~f:(fun d -> b.most + d)
      ; percent
      ]
    |> List.dedup_and_sort ~compare
    |> List.map ~f:(fun m -> m, predicts ~m)
  ;;
end
