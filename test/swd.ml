open! Core
open Protocol_emulator

let swclk_pin = 7
let swdio_pin = 17
let cycle_ns = 20
let standard_half = 500 / cycle_ns
let shortest_half = 10

let config =
  { Program_config.default with
    side_set_count = 1
  ; side_set_base = swclk_pin
  ; in_base = swdio_pin
  ; in_count = 1
  ; out_base = swdio_pin
  ; set_base = swdio_pin
  ; crc_width = 1
  ; crc_poly = 1
  ; crc_init = 0
  }
;;

(* Each edge is the instruction after a wait, which carries the level SWCLK already has,
   and SWDIO is never taken back on the cycle SWCLK rises. y keeps RnW, then the ACK; the
   CRC unit, one bit wide, is the parity of every bit shifted since crc_init. *)
let firmware =
  [%firmware
    {|
    .side_set 1
    set pindirs, 0 side 0      ; every start: SWCLK low and SWDIO let go, wherever it was
    set pins, 0 side 0
    wait tx side 0
    pull side 0
    mov p, osr side 0          ; the half period
    mov t, now side 0
    add t, p side 0
    set x, 31 side 0
settle:
    wait t+ side 0             ; 32 half periods, 6 us or more: many RCs of either pull
    jmp x--, settle
    in pins, 1 side 0          ; SWDIO let go: high if the target's pull-up is powered
    in null, 15 side 0
    push side 0
released:
    wait tx side 0             ; SWCLK low and SWDIO let go until a command
    pull side 0
    set pindirs, 1 side 0      ; then SWDIO low, half a period before SWCLK rises to idle
    mov t, now side 0
    add t, p side 0
    wait t side 0
    jmp command
idle:
    wait tx side 1
    pull side 1
command:
    out y, 1 side 1            ; 1: a request, and this is its start bit
    jmp y--, request
    out y, 14 side 1           ; driven bits, this many words less one
    out x, 1 side 1            ; or bit 15: let go of the lines
    jmp x--, release
    mov t, now side 1
    add t, p side 1
word:
    jmp !tx, word_late
    pull side 1
word_ready:
    set x, 15 side 1
bit:
    wait t+ side 1
    out pins, 1 side 0         ; SWCLK falls with the next bit
    wait t+ side 0
    nop side 1                 ; and rises, when the target takes it
    jmp x--, bit
    jmp y--, word
    jmp idle
word_late:
    wait tx side 1             ; SWCLK waits high for the host
    pull side 1
    mov t, now side 1
    add t, p side 1
    jmp word_ready
release:
    set pindirs, 0 side 0
    jmp released
request:
    mov t, now side 1
    add t, p side 1
    wait t+ side 1
    set pins, 1 side 0         ; start
    wait t+ side 0
    nop side 1
    wait t+ side 1
    out pins, 1 side 0         ; APnDP
    wait t+ side 0
    nop side 1
    wait t+ side 1
    out y, 1 side 0            ; RnW
    mov pins, y side 0
    wait t+ side 0
    set x, 4 side 1
request_bit:
    wait t+ side 1
    out pins, 1 side 0         ; A[2:3], parity, stop, park
    wait t+ side 0
    nop side 1
    jmp x--, request_bit
    wait t+ side 1
    set pindirs, 0 side 0      ; turnaround
    set pins, 0 side 0         ; idle low when the host takes the line back
    wait t+ side 0
    nop side 1                 ; the target drives ACK[0]
    wait t+ side 1
    in pins, 1 side 0
    wait t+ side 0
    nop side 1
    wait t+ side 1
    in pins, 1 side 0
    wait t+ side 0
    nop side 1
    wait t+ side 1
    in pins, 1 side 0
    in null, 13 side 0
    mov x, isr side 0          ; ACK, OK being 1
    wait t+ side 0
    nop side 1
    jmp y--, read
    out y, 1 side 1            ; bit 8: write whatever the ACK
    jmp y--, write
    set y, 1 side 1
    jmp x!=y, no_write
write:
    wait t+ side 1
    mov y, x side 0            ; turnaround
    crc_init side 0
    wait t+ side 0
    nop side 1
    set pindirs, 1 side 1
    jmp !tx, low_late
    pull side 1
low_ready:
    set x, 15 side 1
write_low:
    wait t+ side 1
    out pins, 1 side 0         ; WDATA[0:15]
    wait t+ side 0
    nop side 1
    jmp x--, write_low
    jmp !tx, high_late
    pull side 1
high_ready:
    set x, 15 side 1
write_high:
    wait t+ side 1
    out pins, 1 side 0         ; WDATA[16:31]
    wait t+ side 0
    nop side 1
    jmp x--, write_high
    in crc, 1 side 1
    in null, 15 side 1
    wait t+ side 1
    mov pins, isr side 0       ; parity
    wait t+ side 0
    nop side 1
    jmp done
low_late:
    wait tx side 1
    pull side 1
    mov t, now side 1
    add t, p side 1
    jmp low_ready
high_late:
    wait tx side 1
    pull side 1
    mov t, now side 1
    add t, p side 1
    jmp high_ready
no_write:
    wait t+ side 1
    mov y, x side 0            ; turnaround, and no data phase
    set x, 2 side 0
    jmp x!=y, write_not_wait
write_refused:
    wait t+ side 0
    nop side 1
    set pindirs, 1 side 1
    crc_init side 1
drop:
    wait tx side 1             ; the WDATA words, dropped
    pull side 1
    wait tx side 1
    pull side 1
    mov t, now side 1
    add t, p side 1
    jmp done
write_not_wait:
    set x, 4 side 0
    jmp x!=y, write_invalid
    jmp write_refused
write_invalid:
    set x, 31 side 0           ; no valid ACK: let the line be for a data phase too
write_backoff:
    wait t+ side 0
    nop side 1
    wait t+ side 1
    nop side 0
    jmp x--, write_backoff
    wait t+ side 0
    nop side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    nop side 1                 ; the rise a read's turnaround would end on
    set pindirs, 1 side 1
    crc_init side 1
    jmp drop
read:
    set y, 1 side 1
    jmp x!=y, no_read
    crc_init side 1
    set x, 15 side 1
read_low:
    wait t+ side 1
    in pins, 1 side 0          ; RDATA[0:15]
    wait t+ side 0
    nop side 1
    jmp x--, read_low
    push side 1
    set x, 15 side 1
read_high:
    wait t+ side 1
    in pins, 1 side 0          ; RDATA[16:31]
    wait t+ side 0
    nop side 1
    jmp x--, read_high
    push side 1
    wait t+ side 1
    in pins, 1 side 0          ; parity: the CRC is 0 if it agrees
    wait t+ side 0
    nop side 1                 ; the target lets go
    wait t+ side 1
    nop side 0                 ; turnaround
    wait t+ side 0
    nop side 1
    set pindirs, 1 side 1
    jmp done
no_read:
    wait t+ side 1
    mov y, x side 0            ; turnaround, and no data phase
    set x, 2 side 0
    jmp x!=y, read_not_wait
read_refused:
    wait t+ side 0
    nop side 1
    set pindirs, 1 side 1
    crc_init side 1
    mov isr, null side 1       ; RDATA as zeros, so every read pushes three words
    push side 1
    push side 1
    jmp done
read_not_wait:
    set x, 4 side 0
    jmp x!=y, read_invalid
    jmp read_refused
read_invalid:
    set x, 31 side 0           ; no valid ACK: let the line be for a data phase too
read_backoff:
    wait t+ side 0
    nop side 1
    wait t+ side 1
    nop side 0
    jmp x--, read_backoff
    wait t+ side 0
    nop side 1
    wait t+ side 1
    crc_init side 0
    mov isr, null side 0
    push side 0
    push side 0
    wait t+ side 0
    nop side 1                 ; the end of a read's turnaround
    set pindirs, 1 side 1
    jmp done
done:
    set x, 7 side 1
idle_cycle:
    wait t+ side 1
    set pins, 0 side 0         ; eight idle cycles, so the DP clocks the transfer through
    wait t+ side 0
    nop side 1
    jmp x--, idle_cycle
    in y, 3 side 1             ; then the status, which shifts out all isr held
    in crc, 1 side 1
    in null, 12 side 1
    push side 1
    jmp idle
|}
      ~config
      ~period_floor:10]
;;

module Ack = struct
  type t =
    | Ok
    | Wait
    | Fault
    | Invalid of int
  [@@deriving sexp_of, equal]

  let of_bits = function
    | 0b001 -> Ok
    | 0b010 -> Wait
    | 0b100 -> Fault
    | bits -> Invalid bits
  ;;

  let to_bits = function
    | Ok -> 0b001
    | Wait -> 0b010
    | Fault -> 0b100
    | Invalid bits -> bits
  ;;
end

let bit v i = (v lsr i) land 1
let parity v = Int.popcount v land 1

module Transfer = struct
  type t =
    | Read of
        { ap : bool
        ; address : int
        }
    | Write of
        { ap : bool
        ; address : int
        ; value : Int.Hex.t
        }
    | Targetsel of Int.Hex.t
  [@@deriving sexp_of]

  let request t =
    let ap, read, address =
      match t with
      | Read { ap; address } -> ap, true, address
      | Write { ap; address; value = _ } -> ap, false, address
      | Targetsel _ -> false, false, 0xc
    in
    let fields = Bool.to_int ap lor (Bool.to_int read lsl 1) lor (address land 0xc) in
    1 lor (fields lsl 1) lor (parity fields lsl 5) lor (1 lsl 7)
  ;;

  let words t =
    match t with
    | Read _ -> [ request t ]
    | Write { value; _ } -> [ request t; value land 0xffff; value lsr 16 ]
    | Targetsel value -> [ request t lor 0x100; value land 0xffff; value lsr 16 ]
  ;;

  let replies = function
    | Read _ -> 3
    | Write _ | Targetsel _ -> 1
  ;;
end

module Reply = struct
  type t =
    { ack : Ack.t
    ; data : Int.Hex.t option
    ; parity_error : bool
    }
  [@@deriving sexp_of]

  let of_words (transfer : Transfer.t) words =
    let status = Option.value (List.last words) ~default:0 in
    let ack = Ack.of_bits (status land 0b111) in
    let data =
      match transfer, words with
      | Read _, [ low; high; _ ] when Ack.equal ack Ok -> Some (low lor (high lsl 16))
      | _ -> None
    in
    { ack; data; parity_error = bit status 3 = 1 }
  ;;
end

let sequence words = ((List.length words - 1) lsl 1) :: words
let line_reset = sequence [ 0xffff; 0xffff; 0xffff; 0xffff; 0x0000 ]
let release = [ 0x8000 ]

(* 0x19BC0EA2 E3DDAFE9 86852D95 6209F392, sent LSB first *)
let selection_alert = [ 0xf392; 0x6209; 0x2d95; 0x8685; 0xafe9; 0xe3dd; 0x0ea2; 0x19bc ]

(* four low, the activation code 0b0101_1000 sent MSB first, then high into the reset *)
let activation = 0b1111_0001_1010_0000
let dormant_to_swd = sequence ((0xffff :: selection_alert) @ [ activation ])
let rp2040_core0 = 0x01002927
let rp2040_core1 = 0x11002927
let rp2040_dpidr = 0x0bc12477

module Dp = struct
  let minimum_ns = 21

  (* what the target does at each rise of SWCLK once a request is in *)
  module Action = struct
    type t =
      | Drive of int
      | Release
      | Skip
      | Sample
  end

  module Mode = struct
    type t =
      | Dormant of bool list (* the latest first *)
      | Alerted of bool list (* what came after the alert *)
      | Swd
  end

  module Phase = struct
    type t =
      | Idle
      | Request of int list (* the latest first *)
      | Respond of
          { actions : Action.t list
          ; sampled : (int * bool) list (* each bit, and whether the host drove it *)
          ; request : int
          }
  end

  type t =
    { cycle_ns : int
    ; dpidr : int
    ; targetid : int
    ; ap_latency : int
    ; memory : (int * int) list
    ; corrupt_parity : bool
    ; corrupt_acks : int
    ; now : int
    ; mode : Mode.t
    ; phase : Phase.t
    ; selected : bool
    ; in_reset : bool
    ; may_select : bool
    ; high : int
    ; idle_after_high : int
    ; drive : int option
    ; ctrl_stat : int
    ; select : int
    ; sticky_err : bool
    ; wdata_err : bool
    ; csw : int
    ; tar : int
    ; rdbuff : int
    ; busy : int
    ; swclk : int
    ; line : int
    ; rose : int option
    ; fell : int option
    ; moved : int option
    ; held : bool
    ; took : bool
    ; log : string list
    ; measured : Measured.t
    ; violations : string list
    }

  let create
    ?(ap_latency = 0)
    ?(memory = [])
    ?(corrupt_parity = false)
    ?(corrupt_acks = 0)
    ~cycle_ns
    ~dpidr
    ~targetid
    ()
    =
    { cycle_ns
    ; dpidr
    ; targetid
    ; ap_latency
    ; memory
    ; corrupt_parity
    ; corrupt_acks
    ; now = 0
    ; mode = Dormant []
    ; phase = Idle
    ; selected = false
    ; in_reset = false
    ; may_select = false
    ; high = 0
    ; idle_after_high = 0
    ; drive = None
    ; ctrl_stat = 0
    ; select = 0
    ; sticky_err = false
    ; wdata_err = false
    ; csw = 0
    ; tar = 0
    ; rdbuff = 0
    ; busy = 0
    ; swclk = 1
    ; line = 1
    ; rose = None
    ; fell = None
    ; moved = None
    ; held = true
    ; took = false
    ; log = []
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let drive t = t.drive
  let log t = List.rev t.log
  let measured t = t.measured
  let violations t = List.rev t.violations
  let note t message = { t with log = message :: t.log }
  let violation t message = { t with violations = message :: t.violations }

  let timed t ~name ~since =
    match since with
    | None -> t
    | Some since ->
      let ns = (t.now - since) * t.cycle_ns in
      let t = { t with measured = Measured.add t.measured ~name ~ns } in
      if ns >= minimum_ns then t else violation t [%string "%{name} of %{ns#Int} ns"]
  ;;

  let alert_bits =
    List.concat_map selection_alert ~f:(fun word ->
      List.init 16 ~f:(fun i -> bit word i = 1))
  ;;

  (* B5.3.4, Table B5-2: SW-DP, MSB first *)
  let swd_activation = List.map [ 0; 1; 0; 1; 1; 0; 0; 0 ] ~f:(fun b -> b = 1)

  let dormant t ~sampled =
    match t.mode with
    | Swd -> t
    | Dormant seen ->
      let seen = List.take (sampled :: seen) (List.length alert_bits) in
      if List.equal Bool.equal (List.rev seen) alert_bits
      then { t with mode = Alerted [] }
      else { t with mode = Dormant seen }
    | Alerted after ->
      let after = sampled :: after in
      (* four cycles the target ignores, then the code *)
      if List.length after < 12
      then { t with mode = Alerted after }
      else if List.equal
                Bool.equal
                (List.take (List.rev after) 12 |> Fn.flip List.drop 4)
                swd_activation
      then note { t with mode = Swd; selected = false } "dormant to SWD"
      else { t with mode = Dormant [] }
  ;;

  (* 50 cycles high, then two idle (B4.3.3), seen while the target is not driving *)
  let line_reset t ~sampled =
    match t.mode, t.drive with
    | (Dormant _ | Alerted _), _ | Swd, Some _ -> t
    | Swd, None ->
      if sampled
      then
        { t with
          high = (if t.idle_after_high > 0 then 1 else t.high + 1)
        ; idle_after_high = 0
        }
      else if t.high < 50
      then { t with high = 0; idle_after_high = 0 }
      else if t.idle_after_high = 0
      then { t with idle_after_high = 1 }
      else
        note
          { t with
            high = 0
          ; idle_after_high = 0
          ; phase = Idle
          ; selected = true
          ; in_reset = true
          ; may_select = true
          }
          "line reset"
  ;;

  let sticky t = t.sticky_err || t.wdata_err

  (* APnDP, RnW and A[3:2] of a request, whose bit 0 is the start bit *)
  let fields request =
    bit request 1 = 1, bit request 2 = 1, ((request lsr 3) land 3) lsl 2
  ;;

  let describe request =
    let ap, read, address = fields request in
    sprintf "%s %s 0x%x" (if read then "R" else "W") (if ap then "AP" else "DP") address
  ;;

  (* an Arm AHB MEM-AP's IDR: designer 0x23b, class 8, type 1 (C1.3.2) *)
  let ap_idr = 0x0477_0031

  let mem_ap_read t address =
    match (t.select lsr 4) land 0xf, address with
    | 0xf, 0xc -> t, ap_idr
    | 0, 0x0 -> t, t.csw
    | 0, 0x4 -> t, t.tar
    | 0, 0xc ->
      (match List.Assoc.find t.memory t.tar ~equal:Int.equal with
       | Some value -> t, value
       | None -> { t with sticky_err = true }, 0)
    | _ -> t, 0
  ;;

  let dp_read t address =
    match address with
    | 0x0 -> t.dpidr
    | 0x4 ->
      (match t.select land 0xf with
       | 0 ->
         let req = t.ctrl_stat land 0x5000_0000 in
         req
         lor (req lsl 1)
         lor (Bool.to_int t.wdata_err lsl 7)
         lor (Bool.to_int t.sticky_err lsl 5)
       | 2 -> t.targetid land 0x0fff_ffff
       | 3 -> t.targetid land 0xf000_0000 lor 1
       | _ -> 0)
    | 0xc -> t.rdbuff
    | _ -> 0
  ;;

  let write_register t request value =
    let ap, _, address = fields request in
    if ap
    then (
      let t = { t with busy = t.ap_latency } in
      match (t.select lsr 4) land 0xf, address with
      | 0, 0x0 -> { t with csw = value }
      | 0, 0x4 -> { t with tar = value }
      | 0, 0xc ->
        if List.Assoc.mem t.memory t.tar ~equal:Int.equal
        then { t with memory = List.Assoc.add t.memory t.tar value ~equal:Int.equal }
        else { t with sticky_err = true }
      | _ -> t)
    else (
      match address with
      | 0x0 ->
        (* a MINDP DP takes STKCMPCLR as SBZ (B1.2) *)
        let t =
          if bit value 1 = 1 && bit t.dpidr 16 = 1
          then violation t "STKCMPCLR written to a MINDP DP"
          else t
        in
        { t with
          sticky_err = t.sticky_err && bit value 2 = 0
        ; wdata_err = t.wdata_err && bit value 3 = 0
        }
      | 0x4 when t.select land 0xf = 0 ->
        let t = { t with ctrl_stat = value } in
        if bit value 0 = 1
        then violation t "overrun detection, which the host cannot do"
        else t
      | 0x8 -> { t with select = value }
      | _ -> t)
  ;;

  let drive_bits value count = List.init count ~f:(fun i -> Action.Drive (bit value i))
  let ack_actions ack = drive_bits (Ack.to_bits ack) 3

  (* B4.2: ACK on the three rises after the turnaround; RDATA and its parity straight
     after a read's, then the target lets go and a turnaround follows; a write's WDATA
     after a turnaround. A corrupt ACK goes on as OK, as a target whose ACK the wire
     garbled would. *)
  let respond t request =
    let ap, read, address = fields request in
    let name = describe request in
    (* B4.2.3, B4.2.4: neither to a DPIDR or CTRL/STAT read, nor to an ABORT write *)
    let may_refuse = ap || (read && address > 0x4) || ((not read) && address <> 0) in
    let busy = t.busy > 0 && (ap || (read && address = 0xc)) in
    let ack : Ack.t =
      if may_refuse && sticky t then Fault else if may_refuse && busy then Wait else Ok
    in
    let t = { t with in_reset = t.in_reset && not (read && address = 0 && not ap) } in
    let sent, t =
      match ack with
      | Ok when t.corrupt_acks > 0 ->
        Ack.Invalid 0b101, { t with corrupt_acks = t.corrupt_acks - 1 }
      | ack -> ack, t
    in
    match ack with
    | Wait | Fault | Invalid _ ->
      ( note t (sprintf "%s %s" name (if Ack.equal ack Wait then "WAIT" else "FAULT"))
      , ack_actions ack @ [ Action.Release; Skip ] )
    | Ok when read ->
      let t, value =
        if ap
        then (
          let t, value = mem_ap_read t address in
          (* posted: the result of the read before (B4.2.2) *)
          { t with busy = t.ap_latency; rdbuff = value }, t.rdbuff)
        else t, dp_read t address
      in
      let parity = parity value lxor Bool.to_int t.corrupt_parity in
      ( note
          t
          (sprintf
             "%s OK 0x%08x%s"
             name
             value
             (if Ack.equal sent Ok then "" else ", ACK garbled"))
      , ack_actions sent @ drive_bits value 32 @ [ Drive parity; Release; Skip ] )
    | Ok ->
      ( t
      , ack_actions sent
        @ [ Action.Release; Skip ]
        @ List.init 33 ~f:(fun _ -> Action.Sample) )
  ;;

  let decode_request t bits =
    let request =
      List.foldi (List.rev bits) ~init:0 ~f:(fun i acc b -> acc lor (b lsl i))
    in
    let ap, read, address = fields request in
    let fine =
      parity ((request lsr 1) land 0xf) = bit request 5
      && bit request 6 = 0
      && bit request 7 = 1
    in
    let targetsel = (not ap) && (not read) && address = 0xc in
    let may_select = t.may_select in
    let t = { t with may_select = false } in
    if not fine
    then (
      (* a line reset's ones look like a request too *)
      let t = if request = 0xff then t else note t "protocol error" in
      { t with phase = Idle; selected = false })
    else if targetsel
    then (
      let t =
        if may_select then t else violation t "TARGETSEL not straight after a line reset"
      in
      (* five cycles not driven (B4.3.4), then WDATA and parity *)
      { t with
        phase =
          Respond
            { actions =
                List.init 5 ~f:(fun _ -> Action.Skip)
                @ List.init 33 ~f:(fun _ -> Action.Sample)
            ; sampled = []
            ; request
            }
      })
    else if t.in_reset && not ((not ap) && read && address = 0)
    then (
      let t = violation t (describe request ^ " in the reset state") in
      { t with phase = Idle; selected = false })
    else (
      let t, actions = respond t request in
      { t with phase = Respond { actions; sampled = []; request } })
  ;;

  (* WDATA the host drove every bit of, or none of, which is a host backing off *)
  let complete t ~request ~sampled =
    let driven = List.count sampled ~f:snd in
    let sampled = List.rev_map sampled ~f:fst in
    let value =
      List.foldi (List.take sampled 32) ~init:0 ~f:(fun i acc b -> acc lor (b lsl i))
    in
    let good = parity value = List.nth_exn sampled 32 in
    let ap, read, address = fields request in
    if driven = 0
    then note { t with phase = Idle } (describe request ^ " with no WDATA")
    else if driven < List.length sampled
    then violation { t with phase = Idle } (describe request ^ ", WDATA part undriven")
    else if (not ap) && (not read) && address = 0xc
    then (
      let selected = good && value = t.targetid in
      note
        { t with selected; phase = Idle }
        (sprintf
           "TARGETSEL 0x%08x: %s"
           value
           (if selected then "selected" else "deselected")))
    else (
      let t = note t (sprintf "%s OK 0x%08x" (describe request) value) in
      let t = { t with phase = Idle } in
      if good then write_register t request value else { t with wdata_err = true })
  ;;

  let rise t ~host =
    let t = timed t ~name:"SWCLK low" ~since:t.fell in
    let sampled = t.line = 1 in
    let t = dormant t ~sampled in
    let t = line_reset t ~sampled in
    let t = { t with busy = Int.max 0 (t.busy - 1) } in
    let t = { t with took = false } in
    (* a bit the target takes from the host *)
    let host_bit t =
      if Option.is_none host
      then violation t "a bit taken from the host while it does not drive"
      else { (timed t ~name:"setup" ~since:t.moved) with took = true }
    in
    match t.mode, t.selected, t.phase with
    | (Dormant _ | Alerted _), _, _ | Swd, false, _ -> t
    | Swd, true, Idle ->
      if sampled then { (host_bit t) with phase = Request [ 1 ] } else t
    | Swd, true, Request bits ->
      let t = host_bit t in
      let bits = Bool.to_int sampled :: bits in
      if List.length bits < 8
      then { t with phase = Request bits }
      else decode_request t bits
    | Swd, true, Respond { actions; sampled = so_far; request } ->
      (match actions with
       | [] -> { t with phase = Idle }
       | action :: actions ->
         let t, so_far =
           match action with
           | Drive level -> { t with drive = Some level }, so_far
           | Release -> { t with drive = None }, so_far
           | Skip -> t, so_far
           | Sample ->
             ( (if Option.is_some host
                then { (timed t ~name:"setup" ~since:t.moved) with took = true }
                else t)
             , (Bool.to_int sampled, Option.is_some host) :: so_far )
         in
         if List.is_empty actions
         then (
           match action with
           | Sample -> complete t ~request ~sampled:so_far
           | Drive _ | Release | Skip -> { t with phase = Idle })
         else { t with phase = Respond { actions; sampled = so_far; request } })
  ;;

  let step t ~swclk ~host ~line =
    let t =
      match host, t.drive with
      | Some _, Some _ -> violation t "contention: host and target both drive"
      | _ -> t
    in
    let t =
      if line <> t.line && Option.is_some host
      then (
        let t =
          if t.held then t else timed { t with held = true } ~name:"hold" ~since:t.rose
        in
        { t with moved = Some t.now })
      else t
    in
    let t = { t with line } in
    let t =
      if swclk = t.swclk
      then t
      else if swclk = 1
      then (
        (* hold counts only after a rise that took a bit from the host *)
        let t = rise t ~host in
        { t with swclk; rose = Some t.now; held = not t.took })
      else { (timed t ~name:"SWCLK high" ~since:t.rose) with swclk; fell = Some t.now }
    in
    { t with now = t.now + 1 }
  ;;
end

module Bus = struct
  type t =
    { dps : Dp.t list
    ; host : int option
    ; now : int
    ; contention : int list
    ; undriven : int
    }

  let create ?(undriven = 1) dps =
    { dps; host = None; now = 0; contention = []; undriven }
  ;;

  let rp2040 ?undriven ~cycle_ns () =
    create
      ?undriven
      (List.map [ rp2040_core0; rp2040_core1 ] ~f:(fun targetid ->
         Dp.create ~cycle_ns ~dpidr:rp2040_dpidr ~targetid ()))
  ;;

  let dps t = t.dps
  let contention t = List.rev t.contention

  let line t =
    match t.host, List.filter_map t.dps ~f:Dp.drive with
    | Some level, _ -> level
    | None, level :: _ -> level
    | None, [] -> t.undriven
  ;;

  let inputs t = line t lsl swdio_pin

  let step t ~pin_out ~pin_dir =
    let host = Option.some_if (bit pin_dir swdio_pin = 1) (bit pin_out swdio_pin) in
    let t = { t with host } in
    let swclk = bit pin_out swclk_pin in
    let line = line t in
    let dps = List.map t.dps ~f:(Dp.step ~swclk ~host ~line) in
    let contention =
      if List.count dps ~f:(fun dp -> Option.is_some (Dp.drive dp)) > 1
      then t.now :: t.contention
      else t.contention
    in
    { t with dps; now = t.now + 1; contention }
  ;;
end
