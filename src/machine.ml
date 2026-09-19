open! Core

let fifo_depth = 4
let data_mask = (1 lsl Isa.data_bits) - 1
let timer_mask = (1 lsl Isa.timer_bits) - 1
let pc_mask = (1 lsl Isa.pc_bits) - 1
let program_size = 1 lsl Isa.pc_bits
let first_output_pin = 5
let first_bidir_pin = 12
let writable_pins = ((1 lsl Isa.num_pins) - 1) land lnot ((1 lsl first_output_pin) - 1)
let bidir_pins = ((1 lsl Isa.num_pins) - 1) land lnot ((1 lsl first_bidir_pin) - 1)

module Fault = struct
  type t =
    { underflow : bool
    ; overflow : bool
    ; missed_deadline : bool
    ; decode : bool
    }
  [@@deriving sexp_of, compare, equal]

  let none =
    { underflow = false; overflow = false; missed_deadline = false; decode = false }
  ;;
end

type t =
  { config : Program_config.t
  ; program : int array
  ; pc : int
  ; x : int
  ; y : int
  ; p : int
  ; t : int
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
  }
[@@deriving sexp_of, compare, equal]

let create ~config ~program =
  let open Or_error.Let_syntax in
  let%bind () = Program_config.validate config in
  let%map () =
    if List.length program > program_size
    then Or_error.error_s [%message "program too long" (List.length program : int)]
    else Ok ()
  in
  let program =
    Array.of_list
      (program @ List.init (program_size - List.length program) ~f:(fun _ -> 0))
  in
  { config
  ; program
  ; pc = 0
  ; x = 0
  ; y = 0
  ; p = 0
  ; t = 0
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
  }
;;

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
let bit v i = (v lsr i) land 1
let set_bit v i b = if b then v lor (1 lsl i) else v land lnot (1 lsl i)
let pin i = i % Isa.num_pins

let get_pins v ~base ~count =
  List.init count ~f:(fun j -> bit v (pin (base + j)) lsl j)
  |> List.fold ~init:0 ~f:( lor )
;;

let set_pins v ~base ~count ~value =
  List.init count ~f:Fn.id
  |> List.fold ~init:v ~f:(fun v j -> set_bit v (pin (base + j)) (bit value j = 1))
;;

let sample_pins t ~inputs =
  List.init Isa.num_pins ~f:Fn.id
  |> List.fold ~init:0 ~f:(fun v i ->
    let driven = i >= first_output_pin && (i < first_bidir_pin || bit t.pin_dir i = 1) in
    set_bit v i (bit (if driven then t.pin_out else inputs) i = 1))
;;

let reverse_bits v ~width =
  List.init width ~f:(fun i -> bit v i lsl (width - 1 - i))
  |> List.fold ~init:0 ~f:( lor )
;;

let signed_diff a b =
  let d = (a - b) land timer_mask in
  if d >= 1 lsl (Isa.timer_bits - 1) then d - (1 lsl Isa.timer_bits) else d
;;

let fault t f = { t with fault = f t.fault }

let push t =
  let t =
    if List.length t.rx_fifo >= fifo_depth
    then fault t (fun f -> { f with overflow = true })
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
  if c.autopull && t.osr_count >= c.pull_threshold then pull t else t
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

let jmp_taken t (cond : Isa.Jmp_cond.Cases.t) ~sample =
  match cond with
  | Always -> true, t
  | X_dec -> t.x <> 0, { t with x = (t.x - 1) land data_mask }
  | Y_dec -> t.y <> 0, { t with y = (t.y - 1) land data_mask }
  | X_ne_y -> t.x <> t.y, t
  | Pin -> bit sample t.config.jmp_pin = 1, t
  | Not_pin -> bit sample t.config.jmp_pin = 0, t
  | Osr_not_empty -> t.osr_count < t.config.pull_threshold, t
  | Stuff_pending -> false, t
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
      Some (if advance then { t with t = (t.t + t.p) land timer_mask } else t))
  | Fifo Tx_not_empty -> if List.is_empty t.tx_fifo then None else Some t
  | Fifo Rx_not_full -> if List.length t.rx_fifo < fifo_depth then Some t else None
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
  | Crc -> 0
  | Capture -> t.capture land data_mask
;;

let out_dest t (dest : Isa.Out_dest.Cases.t) ~count ~value =
  match dest with
  | Pins -> write_pins t ~base:t.config.out_base ~count ~value
  | X -> { t with x = value }
  | Y -> { t with y = value }
  | Null -> t
  | Pindirs -> write_pindirs t ~base:t.config.out_base ~count ~value
  | Isr -> { t with isr = value; isr_count = count }
  | P -> { t with p = value }
  | T -> { t with t = value }
;;

let mov_source t (source : Isa.Mov_source.Cases.t) ~sample =
  match source with
  | Pins -> get_pins sample ~base:t.config.in_base ~count:Isa.data_bits
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
  | T -> { t with t = value }
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
  | T -> { t with t = apply t.t ~mask:timer_mask }
;;

let sys t (op : Isa.Sys_op.Cases.t) =
  match op with
  | Nop -> t
  | Halt -> { t with halted = true }
  | Irq -> { t with irq = true }
  | Push -> push t
  | Pull -> pull t
  | Crc_init -> t
  | Stuff_reset -> t
  | Capture_arm -> { t with capture_armed = true }
;;

let execute t (op : Isa.Op.t) ~sample =
  match op with
  | Wait _ -> raise_s [%message "BUG: wait is handled by the issue logic"]
  | In { source; count } ->
    let value = in_source t source ~count ~sample in
    shift_in t ~value ~count |> autopush_after_in
  | Out { dest; count } ->
    let t = autopull_before_out t in
    let value, t = shift_out t ~count in
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

let next t ~stall = { t with pc = (t.pc + 1) land pc_mask; stall }

let issue t ~sample =
  let c = t.config in
  match Isa.of_word ~side_set_count:c.side_set_count t.program.(t.pc) with
  | Error _ -> fault { t with halted = true } (fun f -> { f with decode = true })
  | Ok (Jmp { cond; target }) ->
    let taken, t = jmp_taken t cond ~sample in
    { t with
      pc = (if taken then target else (t.pc + 1) land pc_mask)
    ; stall = Isa.jmp_cycles - 1
    }
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
        | None -> t
        | Some t -> next t ~stall:delay)
     | op -> next (execute t op ~sample) ~stall:delay)
;;

let step t ~inputs =
  let sample = sample_pins t ~inputs in
  let captured = capture_edge t ~sample in
  let now = t.now in
  let t =
    if t.halted
    then t
    else if t.stall > 0
    then { t with stall = t.stall - 1 }
    else issue t ~sample
  in
  let t = if captured then { t with capture = now; capture_armed = false } else t in
  { t with now = (now + 1) land timer_mask; pins_sampled = sample }
;;
