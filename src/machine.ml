open! Core

let fifo_depth = Host_fifo.depth
let data_mask = (1 lsl Isa.data_bits) - 1
let timer_mask = (1 lsl Isa.timer_bits) - 1
let fraction_mask = (1 lsl Isa.fraction_bits) - 1
let pc_mask = (1 lsl Isa.pc_bits) - 1
let program_size = 1 lsl Isa.pc_bits
let data_size = 1 lsl Isa.data_addr_bits
let first_output_pin = Isa.first_output_pin
let first_bidir_pin = Isa.first_bidir_pin
let writable_pins = ((1 lsl Isa.pin_space) - 1) land lnot ((1 lsl first_output_pin) - 1)
let bidir_pins = ((1 lsl Isa.num_pins) - 1) land lnot ((1 lsl first_bidir_pin) - 1)

module Fault = struct
  type t =
    { underflow : bool
    ; overflow : bool
    ; missed_deadline : bool
    ; decode : bool
    ; assumption : bool
    }
  [@@deriving sexp_of, compare, equal]

  let none =
    { underflow = false
    ; overflow = false
    ; missed_deadline = false
    ; decode = false
    ; assumption = false
    }
  ;;
end

module Premises = struct
  type t =
    { period : int option
    ; floor : bool
    ; single_edge : bool
    }
  [@@deriving sexp_of, compare, equal]

  let none = { period = None; floor = false; single_edge = false }
end

type t =
  { config : Program_config.t
  ; program : int array
  ; data : int array
  ; data_ptr : int
  ; data_age : int
  ; pc : int
  ; x : int
  ; y : int
  ; p : int
  ; t : int
  ; t_fraction : int
  ; osr : int
  ; osr_count : int
  ; isr : int
  ; isr_count : int
  ; now : int
  ; pin_out : int
  ; pin_dir : int
  ; pins_sampled : int
  ; tx_fifo : int list
  ; rx_fifo : int list
  ; stall : int
  ; halted : bool
  ; irq : bool
  ; fault : Fault.t
  ; capture : int
  ; capture_armed : bool
  ; crc : int
  ; stuff_run : int
  ; flip : int option
  ; line_table : Line_code.t
  ; line_tx : int
  ; line_rx : int
  ; line_flag : bool
  ; line_last : int
  ; premises : Premises.t
  ; p_loaded : bool
  ; holding : bool
  ; seen : bool
  ; route_full : bool
  ; routed : int option
  }
[@@deriving sexp_of, compare, equal]

let fill name words ~size =
  if List.length words > size
  then Or_error.error_s [%message "too long" name (List.length words : int)]
  else Ok (Array.of_list (words @ List.init (size - List.length words) ~f:(fun _ -> 0)))
;;

let create ~config ~program =
  let open Or_error.Let_syntax in
  let%bind () = Program_config.validate config in
  let%map program = fill "program" program ~size:program_size in
  { config
  ; program
  ; data = Array.create ~len:data_size 0
  ; data_ptr = 0
  ; data_age = Isa.data_settle
  ; pc = 0
  ; x = 0
  ; y = 0
  ; p = 0
  ; t = 0
  ; t_fraction = 0
  ; osr = 0
  ; osr_count = Isa.data_bits
  ; isr = 0
  ; isr_count = 0
  ; now = 0
  ; pin_out = 0
  ; pin_dir = 0
  ; pins_sampled = 0
  ; tx_fifo = []
  ; rx_fifo = []
  ; stall = 0
  ; halted = false
  ; irq = false
  ; fault = Fault.none
  ; capture = 0
  ; capture_armed = false
  ; crc = config.crc_init
  ; stuff_run = 0
  ; flip = None
  ; line_table = Line_code.off
  ; line_tx = 0
  ; line_rx = 0
  ; line_flag = false
  ; line_last = 0
  ; premises = Premises.none
  ; p_loaded = false
  ; holding = false
  ; seen = false
  ; route_full = false
  ; routed = None
  }
;;

let load_data t words =
  Or_error.map (fill "data" words ~size:data_size) ~f:(fun data -> { t with data })
;;

(* the receive side starts where the table says, as from a start *)
let load_line_table t line_table =
  { t with line_table; line_rx = line_table.modes.rx_start }
;;

let assume t premises = { t with premises }

let write_tx t value =
  if List.length t.tx_fifo >= fifo_depth
  then Or_error.error_s [%message "tx fifo full"]
  else Ok { t with tx_fifo = t.tx_fifo @ [ value land data_mask ] }
;;

let read_rx t =
  match t.rx_fifo with
  | [] -> None
  | value :: rx_fifo -> Some (value, { t with rx_fifo })
;;

let clear_irq t = { t with irq = false }
let stop t = { t with halted = true }
let flush t = if t.halted then { t with tx_fifo = []; rx_fifo = [] } else t
let bit v i = (v lsr i) land 1
let set_bit v i b = if b then v lor (1 lsl i) else v land lnot (1 lsl i)
let pin i = i % Isa.pin_space

let get_pins v ~base ~count =
  List.init count ~f:(fun j -> bit v (pin (base + j)) lsl j)
  |> List.fold ~init:0 ~f:( lor )
;;

let set_pins v ~base ~count ~value =
  List.init count ~f:Fn.id
  |> List.fold ~init:v ~f:(fun v j -> set_bit v (pin (base + j)) (bit value j = 1))
;;

let sample_pins t ~inputs =
  List.init Isa.pin_space ~f:Fn.id
  |> List.fold ~init:0 ~f:(fun v i ->
    let driven = i >= first_output_pin && (i < first_bidir_pin || bit t.pin_dir i = 1) in
    let level =
      if i >= Isa.num_pins
      then bit t.pin_out i lor bit inputs i
      else bit (if driven then t.pin_out else inputs) i
    in
    set_bit v i (level = 1))
;;

let pins = sample_pins

let reverse_bits v ~width =
  List.init width ~f:(fun i -> bit v i lsl (width - 1 - i))
  |> List.fold ~init:0 ~f:( lor )
;;

let signed_diff a b =
  let d = (a - b) land timer_mask in
  if d >= 1 lsl (Isa.timer_bits - 1) then d - (1 lsl Isa.timer_bits) else d
;;

let fault t f = { t with fault = f t.fault }

(* a routed engine's rx fifo is the next engine's tx fifo *)
let rx_full t =
  if t.config.route then t.route_full else List.length t.rx_fifo >= fifo_depth
;;

let push t =
  let t =
    if rx_full t
    then fault t (fun f -> { f with overflow = true })
    else if t.config.route
    then { t with routed = Some t.isr }
    else { t with rx_fifo = t.rx_fifo @ [ t.isr ] }
  in
  { t with isr = 0; isr_count = 0 }
;;

let pull t =
  match t.tx_fifo with
  | [] -> fault { t with osr_count = 0 } (fun f -> { f with underflow = true })
  | osr :: tx_fifo -> { t with osr; osr_count = 0; tx_fifo }
;;

let autopull_before_out t =
  let c = t.config in
  if not (c.autopull && t.osr_count >= c.pull_threshold)
  then t
  else if c.autopull_data
  then
    if t.data_age < Isa.data_settle
    then fault { t with osr_count = 0 } (fun f -> { f with underflow = true })
    else
      { t with
        osr = t.data.(t.data_ptr)
      ; osr_count = 0
      ; data_ptr = (t.data_ptr + 1) % data_size
      ; data_age = 0
      }
  else pull t
;;

let autopush_after_in t =
  let c = t.config in
  if c.autopush && t.isr_count >= c.push_threshold then push t else t
;;

let write_pins t ~base ~count ~value =
  { t with pin_out = set_pins t.pin_out ~base ~count ~value land writable_pins }
;;

let write_pindirs t ~base ~count ~value =
  { t with pin_dir = set_pins t.pin_dir ~base ~count ~value land bidir_pins }
;;

let capture_edge t ~sample =
  let c = t.config in
  let prev = bit t.pins_sampled c.capture_pin = 1 in
  let cur = bit sample c.capture_pin = 1 in
  t.capture_armed && Bool.( <> ) prev cur && Bool.equal cur c.capture_rising
;;

let stuff_run_max = 31

(* The assist units see every bit that crosses a pin one at a time. *)
let bit_crosses t bit =
  let c = t.config in
  let crc =
    Crc.step ~width:c.crc_width ~poly:c.crc_poly ~reflect:c.crc_reflect t.crc ~bit
  in
  let stuff_run =
    if Bool.equal (bit = 1) c.stuff_level
    then Int.min stuff_run_max (t.stuff_run + 1)
    else 0
  in
  { t with crc; stuff_run }
;;

let stuff_pending t =
  if t.config.line_code
  then t.line_flag
  else t.config.stuff_threshold > 0 && t.stuff_run >= t.config.stuff_threshold
;;

let jmp_taken t (cond : Isa.Jmp_cond.Cases.t) ~sample =
  match cond with
  | Always -> true, t
  | X_dec -> t.x <> 0, { t with x = (t.x - 1) land data_mask }
  | Y_dec -> t.y <> 0, { t with y = (t.y - 1) land data_mask }
  | X_ne_y -> t.x <> t.y, t
  | Pin -> bit sample t.config.jmp_pin = 1, t
  | Not_pin -> bit sample t.config.jmp_pin = 0, t
  | Osr_not_empty -> t.osr_count < t.config.pull_threshold, t
  | Stuff_pending -> stuff_pending t, t
  | Tx_not_empty -> not (List.is_empty t.tx_fifo), t
  | Tx_empty -> List.is_empty t.tx_fifo, t
  | Rx_not_full -> not (rx_full t), t
  | Rx_full -> rx_full t, t
;;

(* the part of the period below the cycle builds up under [t] and carries into it *)
let advance_deadline t =
  let fraction = t.t_fraction + t.config.period_fraction in
  { t with
    t = (t.t + t.p + (fraction lsr Isa.fraction_bits)) land timer_mask
  ; t_fraction = fraction land fraction_mask
  }
;;

let wait_ready t (wait : Isa.Wait.t) ~sample =
  match wait with
  | Pin_level { pin; level } ->
    if Bool.equal (bit sample pin = 1) level then Some t else None
  | Pin_edge { pin; rising } ->
    let prev = bit t.pins_sampled pin = 1 in
    let cur = bit sample pin = 1 in
    if Bool.( <> ) prev cur && Bool.equal cur rising then Some t else None
  | Deadline { advance } ->
    let phase = signed_diff t.now t.t in
    if phase < 0
    then None
    else (
      let t =
        if phase > 0 then fault t (fun f -> { f with missed_deadline = true }) else t
      in
      Some (if advance then advance_deadline t else t))
  | Fifo Tx_not_empty -> if List.is_empty t.tx_fifo then None else Some t
  | Fifo Rx_not_full -> if rx_full t then None else Some t
;;

let shift_in t ~value ~count =
  let mask = (1 lsl count) - 1 in
  let value = value land mask in
  let isr =
    match t.config.in_shift with
    | Right -> (t.isr lsr count) lor (value lsl (Isa.data_bits - count)) land data_mask
    | Left -> (t.isr lsl count) lor value land data_mask
  in
  { t with isr; isr_count = Int.min Isa.data_bits (t.isr_count + count) }
;;

let shift_out t ~count =
  let mask = (1 lsl count) - 1 in
  let value, osr =
    match t.config.out_shift with
    | Right -> t.osr land mask, t.osr lsr count
    | Left ->
      (t.osr lsr (Isa.data_bits - count)) land mask, (t.osr lsl count) land data_mask
  in
  value, { t with osr; osr_count = Int.min Isa.data_bits (t.osr_count + count) }
;;

let in_source t (source : Isa.In_source.Cases.t) ~count ~sample =
  match source with
  | Pins -> get_pins sample ~base:t.config.in_base ~count
  | X -> t.x
  | Y -> t.y
  | Null -> 0
  | Isr -> t.isr
  | Osr -> t.osr
  | Crc -> t.crc
  | Capture -> t.capture land data_mask
;;

(* the two pins of a Manchester bit: the complement on [out_base], the bit beside it *)
let manchester_pair bit = bit lxor 1 lor (bit lsl 1)

let out_dest t (dest : Isa.Out_dest.Cases.t) ~count ~value =
  match dest with
  | Pins when t.config.manchester && count = 1 ->
    { (write_pins t ~base:t.config.out_base ~count:2 ~value:(manchester_pair value)) with
      flip = Some value
    }
  | Pins when t.config.line_code && count = 1 ->
    let c = t.config in
    let modes = t.line_table.modes in
    let pin = get_pins t.pin_out ~base:c.out_base ~count:1 in
    let input = if modes.tx_relative then value lxor pin else value in
    let e = Line_code.entry t.line_table ~state:t.line_tx ~input in
    let level = if modes.tx_toggle then pin lxor e.out else e.out in
    (* the next pin the complement *)
    let value = level lor ((1 - level) lsl 1) in
    { (write_pins t ~base:c.out_base ~count:(Int.min 2 c.out_count) ~value) with
      line_tx = e.next
    ; line_flag = e.flag
    }
  | Pins -> write_pins t ~base:t.config.out_base ~count ~value
  | X -> { t with x = value }
  | Y -> { t with y = value }
  | Null -> t
  | Pindirs -> write_pindirs t ~base:t.config.out_base ~count ~value
  | Isr -> { t with isr = value; isr_count = count }
  | P -> { t with p = value }
  | T -> { t with t = value; t_fraction = 0 }
;;

let mov_source t (source : Isa.Mov_source.Cases.t) ~sample =
  match source with
  | Pins -> get_pins sample ~base:t.config.in_base ~count:t.config.in_count
  | X -> t.x
  | Y -> t.y
  | Null -> 0
  | Isr -> t.isr
  | Osr -> t.osr
  | Now -> t.now
  | Capture -> t.capture
;;

let mov_dest t (dest : Isa.Mov_dest.Cases.t) ~value =
  match dest with
  | Pins -> write_pins t ~base:t.config.out_base ~count:t.config.out_count ~value
  | X -> { t with x = value }
  | Y -> { t with y = value }
  | Pindirs -> write_pindirs t ~base:t.config.out_base ~count:t.config.out_count ~value
  | Isr -> { t with isr = value; isr_count = 0 }
  | Osr -> { t with osr = value; osr_count = 0 }
  | P -> { t with p = value }
  | T -> { t with t = value; t_fraction = 0 }
;;

let mov_op (op : Isa.Mov_op.Cases.t) ~value ~width =
  let mask = (1 lsl width) - 1 in
  match op with
  | Copy -> value land mask
  | Invert -> lnot value land mask
  | Reverse -> reverse_bits (value land mask) ~width
;;

let set_dest t (dest : Isa.Set_dest.Cases.t) ~value =
  match dest with
  | Pins -> write_pins t ~base:t.config.set_base ~count:t.config.set_count ~value
  | X -> { t with x = value }
  | Y -> { t with y = value }
  | Pindirs -> write_pindirs t ~base:t.config.set_base ~count:t.config.set_count ~value
  | P -> { t with p = value }
;;

let alu
  t
  (dest : Isa.Alu_dest.Cases.t)
  (op : Isa.Alu_op.Cases.t)
  (operand : Isa.Alu_operand.t)
  =
  let operand =
    match operand with
    | Imm imm -> imm
    | Reg X -> t.x
    | Reg Y -> t.y
    | Reg P -> t.p
    | Reg Isr -> t.isr
    | Reg Osr -> t.osr
  in
  let apply value ~mask =
    (match op with
     | Add -> value + operand
     | Sub -> value - operand
     | Xor -> value lxor operand)
    land mask
  in
  match dest with
  | X -> { t with x = apply t.x ~mask:data_mask }
  | Y -> { t with y = apply t.y ~mask:data_mask }
  | P -> { t with p = apply t.p ~mask:data_mask }
  | T -> { t with t = apply t.t ~mask:timer_mask; t_fraction = 0 }
;;

let sys t (op : Isa.Sys_op.Cases.t) =
  match op with
  | Nop -> t
  | Halt -> { t with halted = true }
  | Irq -> { t with irq = true }
  | Push -> push t
  | Pull -> pull t
  | Crc_init -> { t with crc = t.config.crc_init }
  | Stuff_reset -> { t with stuff_run = 0; line_flag = false }
  | Capture_arm -> { t with capture_armed = true }
  | Seek -> { t with data_ptr = t.x % data_size; data_age = 0 }
;;

let execute t (op : Isa.Op.t) ~sample =
  match op with
  | Wait _ -> raise_s [%message "BUG: wait is handled by the issue logic"]
  | In { source = Pins; count = 1 } when t.config.line_code ->
    let modes = t.line_table.modes in
    let pin = get_pins sample ~base:t.config.in_base ~count:1 in
    let input = if modes.rx_relative then pin lxor t.line_last else pin in
    let e = Line_code.entry t.line_table ~state:t.line_rx ~input in
    let value = if modes.rx_toggle then e.out lxor t.line_last else e.out in
    let t = { t with line_rx = e.next; line_flag = e.flag; line_last = pin } in
    (* a dropped bit reaches nothing but the state *)
    if e.flag
    then t
    else bit_crosses t value |> shift_in ~value ~count:1 |> autopush_after_in
  | In { source; count } ->
    let value = in_source t source ~count ~sample in
    let t = if count = 1 then bit_crosses t (value land 1) else t in
    shift_in t ~value ~count |> autopush_after_in
  | Out { dest; count } ->
    let t = autopull_before_out t in
    let value, t = shift_out t ~count in
    let t = if count = 1 then bit_crosses t value else t in
    out_dest t dest ~count ~value
  | Mov { dest; op; source } ->
    let width =
      match dest with
      | T -> Isa.timer_bits
      | _ -> Isa.data_bits
    in
    mov_dest t dest ~value:(mov_op op ~value:(mov_source t source ~sample) ~width)
  | Set { dest; value } -> set_dest t dest ~value
  | Alu { dest; op; operand } -> alu t dest op operand
  | Sys op -> sys t op
;;

let pc_after t =
  if t.pc = t.config.wrap_top then t.config.wrap_bottom else (t.pc + 1) land pc_mask
;;

(* the issue and, for an instruction that took effect rather than waited, its op *)
let issue t ~sample =
  let c = t.config in
  (* the second half of a Manchester bit starts with the next instruction *)
  let t =
    match t.flip with
    | None -> t
    | Some bit ->
      { (write_pins t ~base:c.out_base ~count:2 ~value:(manchester_pair (bit lxor 1))) with
        flip = None
      }
  in
  match Isa.of_word ~side_set_count:c.side_set_count t.program.(t.pc) with
  | Error _ -> fault { t with halted = true } (fun f -> { f with decode = true }), None
  | Ok (Jmp { cond; target }) ->
    let taken, t = jmp_taken t cond ~sample in
    ( { t with pc = (if taken then target else pc_after t); stall = Isa.jmp_cycles - 1 }
    , None )
  | Ok (Op { op; delay; side_set }) ->
    let t =
      (if c.side_set_pindirs then write_pindirs else write_pins)
        t
        ~base:c.side_set_base
        ~count:c.side_set_count
        ~value:side_set
    in
    (match op with
     | Wait wait ->
       (match wait_ready t wait ~sample with
        | None -> t, None
        | Some t -> { t with pc = pc_after t; stall = delay }, Some op)
     | op -> { (execute t op ~sample) with pc = pc_after t; stall = delay }, Some op)
;;

(* The premises a certificate may rest on. The period: where the kernel takes [p] as a
   period, at [wait t+] and [add t, p], a [p] last written other than by a set carries the
   loaded period, or at least it with [floor]. Checked at the use rather than the write,
   so firmware may keep other values in [p] between. The single edge, as
   [formal/phase_step.sv] assumes it: the capture pin is at the other level when
   [capture_arm] takes effect and, once at the captured level, stays there until a wait
   for it releases ([holding] from the arm to that release, [seen] once at the level). The
   fault rises the cycle a premise fails. *)
let watch_premises t ~(before : t) ~(op : Isa.Op.t option) ~sample =
  let c = t.config in
  let level = Bool.equal (bit sample c.capture_pin = 1) c.capture_rising in
  let arms =
    match op with
    | Some (Sys Capture_arm) -> true
    | _ -> false
  in
  let capture_pin pin = pin = c.capture_pin && pin < Isa.pin_space in
  let releases =
    before.premises.single_edge
    &&
    match op with
    | Some (Wait (Pin_level { pin; level })) ->
      capture_pin pin && Bool.equal level c.capture_rising
    | Some (Wait (Pin_edge { pin; rising })) ->
      capture_pin pin && Bool.equal rising c.capture_rising
    | _ -> false
  in
  let p_loaded =
    match op with
    | Some (Set { dest = P; _ }) -> false
    | Some (Mov { dest = P; _ } | Out { dest = P; _ } | Alu { dest = P; _ }) -> true
    | _ -> before.p_loaded
  in
  let uses_p =
    match op with
    | Some (Wait (Deadline { advance = true }))
    | Some (Alu { dest = T; op = Add; operand = Reg P }) -> true
    | _ -> false
  in
  let period_off =
    uses_p
    && before.p_loaded
    &&
    match before.premises.period with
    | Some period ->
      if before.premises.floor then before.p < period else before.p <> period
    | None -> false
  in
  let edge_off =
    before.premises.single_edge
    && ((arms && level) || (before.holding && before.seen && not level))
  in
  let holding, seen =
    if arms
    then true, false
    else if releases
    then false, before.seen
    else before.holding, before.seen || (before.holding && level)
  in
  let t = { t with p_loaded; holding; seen } in
  if period_off || edge_off then fault t (fun f -> { f with assumption = true }) else t
;;

let step ?(route_full = false) t ~inputs =
  let sample = sample_pins t ~inputs in
  let captured = capture_edge t ~sample in
  let now = t.now in
  let before = t in
  let t =
    { t with
      data_age = Int.min Isa.data_settle (t.data_age + 1)
    ; route_full
    ; routed = None
    }
  in
  let t, op =
    (* a delay runs out whether or not the core has been halted in the meantime *)
    if t.stall > 0
    then { t with stall = t.stall - 1 }, None
    else if t.halted
    then t, None
    else issue t ~sample
  in
  let t = watch_premises t ~before ~op ~sample in
  let t = if captured then { t with capture = now; capture_armed = false } else t in
  { t with now = (now + 1) land timer_mask; pins_sampled = sample }
;;
