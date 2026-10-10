open! Core
open Protocol_emulator

module Pin = struct
  type t =
    | A
    | B
  [@@deriving sexp_of, equal, enumerate]
end

module Kind = struct
  type t =
    | Plain
    | Shift
    | Pull
    | Push
    | Stamp
    | Burst
    | Await_host
    | Await of
        { pin : Pin.t
        ; level : bool
        }
  [@@deriving sexp_of, equal]

  (* in the order the interpreter tries them *)
  let all =
    [ Plain; Shift; Pull; Push; Stamp; Burst; Await_host ]
    @ List.concat_map Pin.all ~f:(fun pin ->
      [ Await { pin; level = true }; Await { pin; level = false } ])
  ;;

  let code t = List.findi_exn all ~f:(fun _ k -> equal k t) |> fst

  (* what a step adds to [t] beyond its hold: its path's cycles past the wait that
     releases it, for the deadline at the end to have no slack at hold 0 *)
  let added = function
    | Plain -> 19
    | Shift -> 26
    | Pull -> 28
    | Push | Stamp -> 31
    | Burst | Await_host -> 16
    | Await _ -> 17
  ;;

  let burst_bit = 6

  let least = function
    | Burst -> burst_bit
    | t -> added t
  ;;
end

module Wiring = struct
  type t =
    { inputs : int
    ; in_base : int
    ; out_base : int
    ; open_drain : bool
    ; await_a : int
    ; await_b : int
    }
  [@@deriving sexp_of]

  let default =
    { inputs = 1
    ; in_base = 0
    ; out_base = Isa.first_output_pin
    ; open_drain = false
    ; await_a = 0
    ; await_b = 1
    }
  ;;

  let states t = 1 lsl (7 - t.inputs)

  let validate t =
    let pin name p ~lo ~hi =
      if p < lo || p > hi
      then
        Or_error.error_s
          [%message "pin out of range" name (p : int) (lo : int) (hi : int)]
      else Ok ()
    in
    let first_wire = Isa.num_pins in
    Or_error.combine_errors_unit
      [ (if t.inputs < 1 || t.inputs > 6
         then Or_error.error_s [%message "1 to 6 inputs" (t.inputs : int)]
         else Ok ())
      ; pin "in_base" t.in_base ~lo:0 ~hi:(Isa.pin_space - t.inputs)
      ; (if t.open_drain
         then pin "out_base" t.out_base ~lo:Isa.first_bidir_pin ~hi:(first_wire - 6)
         else pin "out_base" t.out_base ~lo:Isa.first_output_pin ~hi:(Isa.pin_space - 6))
      ; pin "await_a" t.await_a ~lo:0 ~hi:(Isa.pin_space - 1)
      ; pin "await_b" t.await_b ~lo:0 ~hi:(Isa.pin_space - 1)
      ]
  ;;
end

let output_bits = 6
let entries = 256
let max_hold = (1 lsl Isa.data_bits) - 1
let burst_bits = 12

(* Two words an entry: its hold, then outputs (6 bits), kind (4) and next state (6), read
   low bits first. The entry at [d << 7 | state << k | inputs], d the host bit p[15],
   comes next. The kinds are tried in [Kind.all]'s order by counting x down, and every
   code from the last on runs the last. Each path adds its [Kind.added] to [t] before the
   paths join, as the analyser keeps one interval a pc. *)
let interpreter (w : Wiring.t) =
  Wiring.validate w |> ok_exn;
  let drive = if w.open_drain then "pindirs" else "pins" in
  let added kind = Int.to_string (Kind.added kind) in
  let after_await = added (Await { pin = A; level = true }) in
  let await pin level =
    [%string
      {|    wait %{level#Int} pin %{pin#Int}
    mov t, now
    add t, y                 ; the hold, from here
    set y, %{after_await}
    add t, y
    jmp join|}]
  in
  [%string
    {|
    set x, 0
    seek [1]                 ; data_settle
    out y, 16                ; entry 0's hold
    mov t, now
    add t, 7
.wrap_target
    wait t                   ; release
    out %{drive}, 6              ; the entry's outputs
    add t, y                 ; its hold
    out x, 4                 ; its kind
    jmp x--, shift
    set y, %{added Plain}
    add t, y
join:
    out x, 6                 ; the next state
joined:
    set y, 0
    add y, p
    mov isr, ::y             ; the host bit p[15], index bit 8 once shifted
    in x, %{7 - w.inputs#Int}
    in pins, %{w.inputs#Int}
    in null, 1               ; two words an entry
    mov x, isr
    seek [1]                 ; seek keeps the low 9 bits
    out y, 16                ; the next entry's hold
.wrap
shift:
    jmp x--, pull
    mov x, pins              ; in_base, as in_count is 1
    add p, p
    add p, x
    set y, %{added Shift}
    add t, y
    jmp join
pull:
    jmp x--, push
    out x, 6
    pull
    mov p, osr
    out null, 16             ; the table's word is spent
    set y, %{added Pull}
    add t, y
    jmp joined
push:
    jmp x--, stamp
    set y, 0
    add y, p
    mov isr, y
    push
    set y, %{added Push}
    add t, y
    jmp join
stamp:
    jmp x--, burst
    mov isr, now
    push
    set y, %{added Stamp}
    add t, y
    jmp join
burst:
    jmp x--, await_host
    out isr, 6               ; the next state, kept
    wait tx
    pull                     ; bits less one in the low 4, then the bits
    out x, 4
    mov t, now
    add t, 4
bit:
    wait t
    out %{drive}, 1
    add t, y
    add t, %{Kind.burst_bit#Int}
    jmp x--, bit
    mov x, isr
    out null, 16             ; the rest of the host word
    set y, %{added Burst}
    add t, y
    jmp joined
await_host:
    jmp x--, await_a_high
    out x, 6
    wait tx
    pull
    mov p, osr
    out null, 16
    mov t, now
    add t, y                 ; the hold, from here
    set y, %{added Await_host}
    add t, y
    jmp joined
await_a_high:
    jmp x--, await_a_low
%{await w.await_a 1}
await_a_low:
    jmp x--, await_b_high
%{await w.await_a 0}
await_b_high:
    jmp x--, await_b_low
%{await w.await_b 1}
await_b_low:
%{await w.await_b 0}
|}]
;;

let config (w : Wiring.t) =
  { Program_config.default with
    out_base = w.out_base
  ; out_count = output_bits
  ; in_base = w.in_base
  ; in_count = 1
  ; out_shift = Right
  ; in_shift = Left
  ; autopull = true
  ; pull_threshold = 16
  ; autopull_data = true
  }
;;

let check w = Timed_program.check ~config:(config w) (interpreter w)

module type State = sig
  type t [@@deriving equal, sexp_of]
end

module Step = struct
  type 'state t =
    { outputs : int
    ; kind : Kind.t
    ; cycles : int
    ; next : 'state
    }
  [@@deriving sexp_of]
end

type 'state t =
  { name : string
  ; wiring : Wiring.t
  ; state : (module State with type t = 'state)
  ; states : 'state list
  ; step : 'state -> host_bit:bool -> inputs:int -> 'state Step.t
  }

let words (type state) (t : state t) =
  let open Or_error.Let_syntax in
  let module State = (val t.state) in
  let w = t.wiring in
  let%bind () = Wiring.validate w in
  let count = List.length t.states in
  let%bind () =
    if count >= 1 && count <= Wiring.states w
    then return ()
    else
      Or_error.error_s
        [%message "1 to 2^(7 - inputs) states" (count : int) ~inputs:(w.inputs : int)]
  in
  let index state = List.findi t.states ~f:(fun _ s -> State.equal s state) in
  let entry ~d ~state ~inputs =
    if state >= count
    then return [ 0; 0 ]
    else
      (let state = List.nth_exn t.states state in
       let host_bit = d = 1 in
       let ({ outputs; kind; cycles; next } : State.t Step.t) =
         t.step state ~host_bit ~inputs
       in
       let hold = cycles - Kind.least kind in
       let%bind next =
         match index next with
         | Some (i, _) -> return i
         | None -> Or_error.error_s [%message "no such state" (next : State.t)]
       in
       let%bind () =
         if outputs >= 0 && outputs < 1 lsl output_bits
         then return ()
         else Or_error.error_s [%message "6 output bits" (outputs : int)]
       in
       let%bind () =
         if hold >= 0 && hold <= max_hold
         then return ()
         else
           Or_error.error_s
             [%message
               "cycles out of the kind's range"
                 (kind : Kind.t)
                 (cycles : int)
                 ~least:(Kind.least kind : int)
                 ~most:(Kind.least kind + max_hold : int)]
       in
       return [ hold; outputs lor (Kind.code kind lsl 6) lor (next lsl 10) ])
      |> Or_error.tag_s ~tag:[%message t.name (state : int) (d : int) (inputs : int)]
  in
  List.init entries ~f:(fun i ->
    entry
      ~d:(i lsr 7)
      ~state:((i lsr w.inputs) land (Wiring.states w - 1))
      ~inputs:(i land ((1 lsl w.inputs) - 1)))
  |> Result.all
  |> Or_error.map ~f:List.concat
;;

(* the host's words *)
let host_bits bits =
  if List.length bits > Isa.data_bits
  then raise_s [%message "BUG: 16 bits a word" (bits : bool list)];
  List.foldi bits ~init:0 ~f:(fun i word bit ->
    word lor (Bool.to_int bit lsl (Isa.data_bits - 1 - i)))
;;

let burst_word bits =
  let n = List.length bits in
  if n < 1 || n > burst_bits then raise_s [%message "BUG: 1 to 12 bits a burst" (n : int)];
  List.foldi bits ~init:(n - 1) ~f:(fun i word bit ->
    word lor (Bool.to_int bit lsl (4 + i)))
;;

let step outputs kind cycles next = { Step.outputs; kind; cycles; next }
let fastest kind next ~outputs = step outputs kind (Kind.least kind) next
let bit b = Bool.to_int b

module Uart_tx = struct
  type t =
    | Idle
    | Start
    | Data of int
    | Stop
  [@@deriving equal, sexp_of]
end

let uart_tx ~bit:cycles : Uart_tx.t t =
  { name = "uart_tx"
  ; wiring = Wiring.default
  ; state = (module Uart_tx)
  ; states =
      (Uart_tx.Idle :: Start :: List.init 8 ~f:(fun i -> Uart_tx.Data i)) @ [ Stop ]
  ; step =
      (fun state ~host_bit ~inputs:_ ->
        let open Uart_tx in
        match state with
        | Idle -> fastest Await_host Start ~outputs:1
        | Start -> step 0 Plain cycles (Data 0)
        | Data i ->
          step (bit host_bit) Shift cycles (if i = 7 then Stop else Data (i + 1))
        | Stop -> step 1 Plain cycles Idle)
  }
;;

let uart_word byte = host_bits (List.init 8 ~f:(fun i -> (byte lsr i) land 1 = 1))

module Uart_rx = struct
  type t =
    | Wait
    | Data of int
    | Done
  [@@deriving equal, sexp_of]
end

(* the start bit's edge opens the wait, which times the first Shift's read to the middle
   of bit 0 *)
let uart_rx ~bit:cycles : Uart_rx.t t =
  { name = "uart_rx"
  ; wiring = Wiring.default
  ; state = (module Uart_rx)
  ; states = (Uart_rx.Wait :: List.init 8 ~f:(fun i -> Uart_rx.Data i)) @ [ Done ]
  ; step =
      (fun state ~host_bit:_ ~inputs:_ ->
        let open Uart_rx in
        match state with
        | Wait ->
          step 0 (Await { pin = A; level = false }) ((3 * cycles / 2) - 9) (Data 0)
        | Data i -> step 0 Shift cycles (if i = 7 then Done else Data (i + 1))
        | Done -> fastest Push Wait ~outputs:0)
  }
;;

module Uart_burst = struct
  type t = Send [@@deriving equal, sexp_of]
end

let uart_tx_burst ~bit:cycles : Uart_burst.t t =
  { name = "uart_tx_burst"
  ; wiring = Wiring.default
  ; state = (module Uart_burst)
  ; states = [ Uart_burst.Send ]
  ; step = (fun Send ~host_bit:_ ~inputs:_ -> step 1 Burst cycles Uart_burst.Send)
  }
;;

let uart_frame byte =
  burst_word ((false :: List.init 8 ~f:(fun i -> (byte lsr i) land 1 = 1)) @ [ true ])
;;

module Spi_master = struct
  type t =
    | Idle
    | Low of int
    | High of int
    | Done
  [@@deriving equal, sexp_of]
end

(* MOSI on out_base, SCK beside it, MISO on in_base *)
let spi_master ~half : Spi_master.t t =
  { name = "spi_master"
  ; wiring = Wiring.default
  ; state = (module Spi_master)
  ; states =
      (Spi_master.Idle
       :: List.concat_map (List.range 0 8) ~f:(fun i -> [ Spi_master.Low i; High i ]))
      @ [ Done ]
  ; step =
      (fun state ~host_bit ~inputs:_ ->
        let open Spi_master in
        match state with
        | Idle -> fastest Await_host (Low 0) ~outputs:0
        | Low i -> step (bit host_bit) Plain half (High i)
        | High i ->
          step (bit host_bit lor 2) Shift half (if i = 7 then Done else Low (i + 1))
        | Done -> fastest Push Idle ~outputs:0)
  }
;;

module Dshot_bits = struct
  type t =
    | Idle
    | Rise of int
    | Bit of int
    | Fall of int
    | Gap
  [@@deriving equal, sexp_of]
end

(* each bit: high for [zero_high], the bit for [zero_high] more, low to [bit] *)
let dshot ~zero_high ~bit:cycles : Dshot_bits.t t =
  { name = "dshot"
  ; wiring = Wiring.default
  ; state = (module Dshot_bits)
  ; states =
      (Dshot_bits.Idle
       :: List.concat_map (List.range 0 16) ~f:(fun i ->
         [ Dshot_bits.Rise i; Bit i; Fall i ]))
      @ [ Gap ]
  ; step =
      (fun state ~host_bit ~inputs:_ ->
        let open Dshot_bits in
        match state with
        | Idle -> fastest Await_host (Rise 0) ~outputs:0
        | Rise i -> step 1 Plain zero_high (Bit i)
        | Bit i -> step (bit host_bit) Shift zero_high (Fall i)
        | Fall i ->
          step 0 Plain (cycles - (2 * zero_high)) (if i = 15 then Gap else Rise (i + 1))
        | Gap -> step 0 Plain (8 * zero_high) Idle)
  }
;;

module I2c_slave = struct
  type t =
    | Idle
    | Fall
    | Start
    | Address_high of int
    | Address_check of int
    | Ack
    | Ack_low
    | Release
    | First_high
    | First_shift
    | Watch of bool
    | Data_high
    | Data_shift
    | Data_low
    | Push_ack
  [@@deriving equal, sexp_of]
end

let marker = 0x0080

(* Takes writes to [address]: SDA on [sda], SCL beside it, both open drain. Each byte goes
   to the host as [0x8000 lor byte]; the host keeps a [marker] word queued for each, which
   reaches p[15] as the eighth bit comes in. START and STOP are watched for on the first
   bit of a byte, by polling while SCL is high, as [I2c.slave] does. *)
let i2c_slave ~address ~sda : I2c_slave.t t =
  let scl = sda + 1 in
  let wiring =
    { Wiring.inputs = 2
    ; in_base = sda
    ; out_base = sda
    ; open_drain = true
    ; await_a = scl
    ; await_b = sda
    }
  in
  let sda_high inputs = inputs land 1 = 1 in
  let scl_high inputs = inputs land 2 = 2 in
  let scl_low = Kind.Await { pin = A; level = false } in
  let scl_high_kind = Kind.Await { pin = A; level = true } in
  let wanted i = ((address lsl 1) lsr (7 - i)) land 1 = 1 in
  { name = "i2c_slave"
  ; wiring
  ; state = (module I2c_slave)
  ; states =
      [ I2c_slave.Idle; Fall; Start ]
      @ List.concat_map (List.range 0 8) ~f:(fun i ->
        [ I2c_slave.Address_high i; Address_check i ])
      @ [ Ack
        ; Ack_low
        ; Release
        ; First_high
        ; First_shift
        ; Watch false
        ; Watch true
        ; Data_high
        ; Data_shift
        ; Data_low
        ; Push_ack
        ]
  ; step =
      (fun state ~host_bit ~inputs ->
        let open I2c_slave in
        match state with
        | Idle -> fastest (Await { pin = B; level = true }) Fall ~outputs:0
        | Fall -> fastest (Await { pin = B; level = false }) Start ~outputs:0
        | Start ->
          if scl_high inputs
          then fastest scl_low (Address_high 0) ~outputs:0
          else fastest Plain Idle ~outputs:0
        | Address_high i -> fastest scl_high_kind (Address_check i) ~outputs:0
        | Address_check i ->
          if scl_high inputs && Bool.equal (sda_high inputs) (wanted i)
          then fastest scl_low (if i = 7 then Ack else Address_high (i + 1)) ~outputs:0
          else fastest Plain Idle ~outputs:0
        | Ack -> fastest scl_high_kind Ack_low ~outputs:1
        | Ack_low -> fastest scl_low Release ~outputs:1
        | Release -> fastest Pull First_high ~outputs:0
        | First_high -> fastest scl_high_kind First_shift ~outputs:0
        | First_shift -> fastest Shift (Watch (sda_high inputs)) ~outputs:0
        | Watch was ->
          if not (scl_high inputs)
          then fastest scl_high_kind Data_shift ~outputs:0
          else if Bool.equal (sda_high inputs) was
          then fastest Plain (Watch was) ~outputs:0
          else if was
          then fastest scl_low (Address_high 0) ~outputs:0 (* a repeated START *)
          else fastest Plain Idle ~outputs:0 (* a STOP *)
        | Data_high -> fastest scl_high_kind Data_shift ~outputs:0
        | Data_shift -> fastest Shift Data_low ~outputs:0
        | Data_low ->
          fastest scl_low (if host_bit then Push_ack else Data_high) ~outputs:0
        | Push_ack -> fastest Push Ack ~outputs:1)
  }
;;
