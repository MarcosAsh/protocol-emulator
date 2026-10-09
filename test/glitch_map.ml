open! Core
open Protocol_emulator

let period = 16
let pulses = List.range (period + 1) (12 * period)
let wire = Swept.wire
let generator_config = { Program_config.default with set_base = wire }

let receiver_config =
  { Uart.rx_config with in_base = wire; jmp_pin = wire; capture_pin = wire }
;;

let nops n = Delay_variants.nops ~side_set_count:0 ~side:0 n

(* The start bit, then all ones, but for the pulse: a [set] a cycle, [nop]s between. *)
let generator ~k =
  [ [ "    set pins, 1              ; idle high"
    ; "idle:"
    ; "    wait tx"
    ; "    pull                     ; a frame for each word from the host"
    ; "    mov t, now               ; the anchor the rows place each edge from"
    ; "    set pins, 0              ; start bit"
    ]
  ; nops (period - 1)
  ; [ "    set pins, 1              ; the byte and the stop bit, all ones" ]
  ; nops (k - period - 1)
  ; [ "    set pins, 0              ; the pulse"; "    set pins, 1"; "    jmp idle" ]
  ]
  |> List.concat
  |> String.concat ~sep:"\n"
;;

module Image = struct
  type t =
    { k : int
    ; timed : Timed_program.t
    ; pulse : Interval.t
    }
end

let falls timed =
  List.filter_map (Timed_program.rows timed) ~f:(fun (r : Analyser.Row.t) ->
    match r.instruction, r.pin_event with
    | Op { op = Set { dest = Pins; value = 0 }; _ }, Some (Edge at) -> Some at
    | _ -> None)
;;

let image k =
  if k <= period then raise_s [%message "a pulse in the start bit" (k : int)];
  let timed = Timed_program.of_source_exn ~config:generator_config (generator ~k) in
  match falls timed with
  | [ start; pulse ] -> { Image.k; timed; pulse = Interval.minus pulse start }
  | falls -> raise_s [%message "BUG: not two falling edges" (falls : Interval.t list)]
;;

let receiver =
  Timed_program.of_source_exn
    ~single_capture_edge:true
    ~config:receiver_config
    (Uart.rx_on ~pin:wire ~period)
;;

module Sample = struct
  type t =
    { pc : int
    ; pass : int
    ; at : Interval.t
    }
  [@@deriving sexp_of]
end

module Capture_age = struct
  type t =
    | Rows
    | Kernel
  [@@deriving sexp_of]
end

let rows = Array.of_list (Timed_program.rows receiver)

(* The capture against the edge the capturing wait releases on, which [mov t, capture]
   reads the cycle after. The row after it holds [now - capture]: the analyser's bound is
   the arm's age less one, the kernel's step (formal/phase_step.sv) the arm's age. *)
let capture_offset (age : Capture_age.t) ~mov_pc =
  let after = rows.(mov_pc + 1).phase in
  let after =
    match age with
    | Rows -> after
    | Kernel ->
      let arm = Option.value_exn rows.(mov_pc).since_arm in
      { after with hi = Option.map arm.hi ~f:(fun hi -> hi + 1) }
  in
  Interval.minus (Interval.exactly 2) after
;;

(* Follows a frame from the capturing wait, the line high at the check, with [t] counted
   from the capture: each pin read samples in the cycle it issues, at its phase past [t]. *)
let samples age =
  let config = Timed_program.config receiver in
  let start =
    Array.find_exn rows ~f:(fun r ->
      match r.instruction with
      | Op { op = Wait wait; _ } -> Analyser.captures config wait
      | _ -> false)
  in
  let passes = Hashtbl.create (module Int) in
  let rec walk pc ~t ~x ~capture ~found =
    let r = rows.(pc) in
    let pass = Option.value (Hashtbl.find passes pc) ~default:0 in
    Hashtbl.set passes ~key:pc ~data:(pass + 1);
    let sample () =
      let at = Interval.plus (Interval.plus t r.phase) capture in
      { Sample.pc; pass; at } :: found
    in
    let next = walk (pc + 1) ~x ~capture in
    match r.instruction with
    | Op { op = Mov { dest = T; op = Copy; source = Capture }; _ } ->
      walk
        (pc + 1)
        ~t:(Interval.exactly 0)
        ~x
        ~capture:(capture_offset age ~mov_pc:pc)
        ~found
    | Op { op = Alu { dest = T; op; operand }; _ } ->
      let amount =
        match operand with
        | Imm n -> Interval.exactly n
        | Reg Y -> r.y
        | Reg P -> r.period
        | Reg _ -> raise_s [%message "BUG: t moved by" (operand : Isa.Alu_operand.t)]
      in
      (match op with
       | Add -> next ~t:(Interval.plus t amount) ~found
       | Sub -> next ~t:(Interval.minus t amount) ~found
       | Xor -> raise_s [%message "BUG: xor on t"])
    | Op { op = Set { dest = X; value }; _ } -> walk (pc + 1) ~t ~x:value ~capture ~found
    | Op { op = Wait (Deadline { advance = true }); _ } ->
      next ~t:(Interval.plus t r.period) ~found
    | Op { op = In { source = Pins; _ }; _ } -> next ~t ~found:(sample ())
    | Jmp { cond = X_dec; target } when x <> 0 ->
      walk target ~t ~x:(x - 1) ~capture ~found
    | Jmp { cond = Pin | Not_pin; _ } -> List.rev (sample ())
    | _ -> next ~t ~found
  in
  walk (start.pc + 1) ~t:Interval.top ~x:0 ~capture:Interval.top ~found:[]
;;

module Outcome = struct
  type t =
    { words : int list
    ; framing_error : bool
    }
  [@@deriving sexp_of, equal]
end

let exactly (i : Interval.t) =
  match i with
  | { lo = Some lo; hi = Some hi } when lo = hi -> lo
  | _ -> raise_s [%message "BUG: the rows leave a sample open" (i : Interval.t)]
;;

let predict k =
  let data, check =
    match List.rev (samples Rows) with
    | check :: data -> List.rev data, check
    | [] -> raise_s [%message "BUG: no samples"]
  in
  let check_at = exactly check.at in
  let byte =
    List.foldi data ~init:0xff ~f:(fun bit byte (s : Sample.t) ->
      if exactly s.at = k then byte land lnot (1 lsl bit) else byte)
  in
  let rearmed = k > check_at + Isa.jmp_cycles in
  { Outcome.words = (if rearmed then [ byte; 0xff ] else [ byte ])
  ; framing_error = k = check_at
  }
;;

let setups (image : Image.t) =
  [ { System_lockstep.Setup.config = Timed_program.config image.timed
    ; program = Timed_program.words image.timed
    ; preload = []
    ; data = []
    }
  ; { config = Timed_program.config receiver
    ; program = Timed_program.words receiver
    ; preload = []
    ; data = []
    }
  ]
;;

(* the frame and any frame a late pulse starts *)
let cycles = 10 + (25 * period)

let host n =
  [ { Lockstep.Host.idle with tx = Option.some_if (n = 10) 0 }; Lockstep.Host.idle ]
;;

let outcome (system : System.t) =
  let receiver = List.nth_exn system.engines 1 in
  { Outcome.words = receiver.rx_fifo; framing_error = receiver.irq }
;;

let model image =
  let system =
    List.map (setups image) ~f:(fun s ->
      Machine.create ~config:s.config ~program:s.program |> ok_exn)
    |> System.create
  in
  let system =
    Fn.apply_n_times
      ~n:cycles
      (fun (n, system) ->
        (* as [System_lockstep] does: the host's word lands after the step *)
        ( n + 1
        , List.foldi
            (host n)
            ~init:(System.step system ~pads:0)
            ~f:(fun engine system (action : Lockstep.Host.t) ->
              match action.tx with
              | Some word ->
                System.update system engine ~f:(fun m ->
                  Machine.write_tx m word |> ok_exn)
              | None -> system) ))
      (0, system)
    |> snd
  in
  outcome system
;;

let rtl image =
  let system, mismatch =
    System_lockstep.run ~cycles ~host ~pads:(fun _ -> 0) (setups image)
  in
  outcome system, mismatch
;;
