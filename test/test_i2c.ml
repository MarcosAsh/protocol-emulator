open! Core
open Protocol_emulator

let assemble source = Asm.assemble source |> ok_exn |> Asm.Program.words |> ok_exn
let sda = 12
let scl = 13

(* Open drain: a direction bit of 1 drives the line low, 0 releases it to the pull up. SDA
   is IO0 and SCL is IO1. Side-set targets pin directions, so [side 1] is SCL low and
   [side 0] is SCL high. Each word from the host is one bus byte with flags in the top
   bits: 15 start, 14 read, 13..6 data, 5 stop. After every byte the core pushes the ack
   bit, or the received byte for a read, to the host. [p] is a quarter of the SCL period. *)
let i2c_master ~quarter =
  [%string
    {|
    .side_set 1
    set p, %{quarter#Int} side 0
idle:
    wait tx side 0
    pull side 0
    mov t, now side 0
    add t, p side 0
    add t, p side 0              ; two quarters of slack for the dispatch
    out x, 1 side 0
    jmp x--, start
    jmp send_or_read
byte:
    wait tx side 1
    pull side 1
    mov t, now side 1
    add t, p side 1
    add t, p side 1
    out x, 1 side 1
    jmp x--, restart
    jmp send_or_read
start:                           ; bus idle, both lines high
    wait t+ side 0
    set pindirs, 1 side 0        ; SDA low while SCL high
    wait t+ side 0
    nop side 1
    jmp send_or_read
restart:                         ; SCL low after a byte
    set pindirs, 0 side 1        ; release SDA
    wait t+ side 1
    nop side 0
    wait t+ side 0
    set pindirs, 1 side 0        ; SDA low while SCL high
    wait t+ side 0
    nop side 1
send_or_read:
    out y, 1 side 1
    set x, 7 side 1
    jmp y--, read
send:
    wait t+ side 1
    out y, 1 side 1
    mov pindirs, !y side 1       ; SDA follows the bit
    wait t+ side 1
    nop side 0                   ; SCL high
    wait t+ side 0
    wait t+ side 0
    nop side 1                   ; SCL low
    jmp x--, send
    wait t+ side 1
    set pindirs, 0 side 1        ; release SDA for the ack
    wait t+ side 1
    nop side 0
    wait t+ side 0
    in pins, 1 side 0            ; ack bit, 0 means acked
    wait t+ side 0
    nop side 1
    out x, 1 side 1              ; stop flag
    jmp finish
read:
    set pindirs, 0 side 1        ; release SDA
rbit:
    wait t+ side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    in pins, 1 side 0
    wait t+ side 0
    nop side 1
    jmp x--, rbit
    out null, 8 side 1           ; the unused data bits
    out x, 1 side 1              ; stop flag, and nack on the last byte
    wait t+ side 1
    mov pindirs, !x side 1
    wait t+ side 1
    nop side 0
    wait t+ side 0
    wait t+ side 0
    nop side 1
    set pindirs, 0 side 1
finish:
    push side 1
    jmp x--, stop
    jmp byte
stop:
    wait t+ side 1
    set pindirs, 1 side 1        ; SDA low
    wait t+ side 1
    nop side 0                   ; SCL high
    wait t+ side 0
    set pindirs, 0 side 0        ; SDA released while SCL high
    wait t+ side 0
    jmp idle
|}]
;;

let config =
  { Program_config.default with
    side_set_count = 1
  ; side_set_base = scl
  ; side_set_pindirs = true
  ; out_base = sda
  ; out_count = 1
  ; set_base = sda
  ; set_count = 1
  ; in_base = sda
  ; out_shift = Left
  ; in_shift = Left
  }
;;

let word ?(start = false) ?(read = false) ?(stop = false) data =
  (Bool.to_int start lsl 15)
  lor (Bool.to_int read lsl 14)
  lor (data lsl 6)
  lor (Bool.to_int stop lsl 5)
;;

(* A slave at [address] with a register pointer: the first byte of a write sets the
   pointer, later bytes are stored from there, and a read returns bytes from there.
   Everything the slave sees goes into [log]. *)
module Slave = struct
  module Phase = struct
    type t =
      | Idle
      | Address
      | Ack of [ `Write | `Read ]
      | Write
      | Read
      | Master_ack
    [@@deriving sexp_of]
  end

  type t =
    { address : int
    ; memory : int array
    ; pointer : int
    ; pointer_set : bool
    ; phase : Phase.t
    ; shift : int
    ; bits : int
    ; drive_low : bool
    ; sda : int
    ; scl : int
    ; log : string list
    }

  let create ~address ~memory =
    { address
    ; memory
    ; pointer = 0
    ; pointer_set = false
    ; phase = Idle
    ; shift = 0
    ; bits = 0
    ; drive_low = false
    ; sda = 1
    ; scl = 1
    ; log = []
    }
  ;;

  let note t message = { t with log = message :: t.log }
  let slot t = t.pointer land (Array.length t.memory - 1)

  let load_next t =
    let byte = t.memory.(slot t) in
    { t with
      phase = Read
    ; shift = byte
    ; bits = 0
    ; drive_low = byte lsr 7 = 0
    ; pointer = t.pointer + 1
    }
  ;;

  let on_rising t ~sda =
    match t.phase with
    | Address ->
      let shift = (t.shift lsl 1) lor sda land 0xff in
      if t.bits < 7
      then { t with shift; bits = t.bits + 1 }
      else (
        let mine = shift lsr 1 = t.address in
        let next = if shift land 1 = 1 then `Read else `Write in
        let t =
          note
            t
            [%string
              "address %{shift lsr 1#Int} %{match next with `Read -> \"read\" | `Write \
               -> \"write\"}%{if mine then \"\" else \" ignored\"}"]
        in
        if mine then { t with phase = Ack next; bits = 0 } else { t with phase = Idle })
    | Write ->
      let shift = (t.shift lsl 1) lor sda land 0xff in
      if t.bits < 7
      then { t with shift; bits = t.bits + 1 }
      else if t.pointer_set
      then (
        t.memory.(slot t) <- shift;
        note
          { t with phase = Ack `Write; bits = 0; pointer = t.pointer + 1 }
          [%string "write %{shift#Int}"])
      else
        note
          { t with phase = Ack `Write; bits = 0; pointer = shift; pointer_set = true }
          [%string "pointer %{shift#Int}"]
    | Master_ack ->
      if sda = 0
      then { t with phase = Ack `Read; bits = 1 }
      else note { t with phase = Idle } "nack"
    | Ack _ | Read | Idle -> t
  ;;

  let on_falling t =
    match t.phase with
    | Ack next ->
      if t.bits = 0
      then { t with drive_low = true; bits = 1 }
      else (
        match next with
        | `Write -> { t with phase = Write; drive_low = false; bits = 0 }
        | `Read -> load_next t)
    | Read ->
      if t.bits < 7
      then (
        let shift = (t.shift lsl 1) land 0xff in
        { t with shift; bits = t.bits + 1; drive_low = shift lsr 7 = 0 })
      else { t with phase = Master_ack; drive_low = false }
    | Address | Write | Master_ack | Idle -> t
  ;;

  (* [sda] and [scl] are the bus levels this cycle. *)
  let step t ~sda ~scl =
    let t' = { t with sda; scl } in
    if scl = 1 && t.scl = 1 && sda = 0 && t.sda = 1
    then note { t' with phase = Address; shift = 0; bits = 0; drive_low = false } "start"
    else if scl = 1 && t.scl = 1 && sda = 1 && t.sda = 0
    then note { t' with phase = Idle; drive_low = false; pointer_set = false } "stop"
    else if scl = 1 && t.scl = 0
    then on_rising t' ~sda
    else if scl = 0 && t.scl = 1
    then on_falling t'
    else t'
  ;;
end

let run_transaction words ~memory ~cycles =
  let quarter = 8 in
  let t = Machine.create ~config ~program:(assemble (i2c_master ~quarter)) |> ok_exn in
  let slave = Slave.create ~address:0x50 ~memory in
  (* The host tops up the tx fifo whenever there is room. *)
  let feed (t : Machine.t) pending =
    match pending with
    | w :: rest when List.length t.tx_fifo < Machine.fifo_depth ->
      Machine.write_tx t w |> ok_exn, rest
    | pending -> t, pending
  in
  let rec loop (t : Machine.t) slave pending n replies =
    if n = 0
    then t, slave, List.rev replies
    else (
      let t, pending = feed t pending in
      let master_sda = 1 - ((t.pin_dir lsr sda) land 1) in
      let bus_sda = if slave.Slave.drive_low then 0 else master_sda in
      let bus_scl = 1 - ((t.pin_dir lsr scl) land 1) in
      let t = Machine.step t ~inputs:((bus_sda lsl sda) lor (bus_scl lsl scl)) in
      let slave = Slave.step slave ~sda:bus_sda ~scl:bus_scl in
      let replies, t =
        match Machine.read_rx t with
        | Some (r, t) -> r :: replies, t
        | None -> replies, t
      in
      loop t slave pending (n - 1) replies)
  in
  let t, slave, replies = loop t slave words cycles [] in
  print_s
    [%message
      (replies : int list)
        (List.rev slave.log : string list)
        (t.fault : Machine.Fault.t)
        (t.pc : int)]
;;

let%expect_test "write a register then read it back" =
  let memory = Array.create ~len:16 0 in
  run_transaction
    [ word ~start:true 0xa0; word 3; word ~stop:true 0xaa ]
    ~memory
    ~cycles:1500;
  [%expect
    {|
    ((replies (0 0 0))
     ("List.rev slave.log"
      (start "address 80 write" "pointer 3" "write 170" stop))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 1))
    |}];
  print_s [%message (memory : int array)];
  [%expect {| (memory (0 0 0 170 0 0 0 0 0 0 0 0 0 0 0 0)) |}];
  run_transaction
    [ word ~start:true 0xa0
    ; word 3
    ; word ~start:true 0xa1
    ; word ~read:true 0
    ; word ~read:true ~stop:true 0
    ]
    ~memory:(Array.mapi memory ~f:(fun i v -> if i = 4 then 0x5c else v))
    ~cycles:2500;
  [%expect
    {|
    ((replies (0 0 0 170 92))
     ("List.rev slave.log"
      (start "address 80 write" "pointer 3" start "address 80 read" nack stop))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 1))
    |}]
;;

let%expect_test "a slave at another address does not answer" =
  run_transaction
    [ word ~start:true ~stop:true 0xa2 ]
    ~memory:(Array.create ~len:16 0)
    ~cycles:800;
  [%expect
    {|
    ((replies (1)) ("List.rev slave.log" (start "address 81 write ignored" stop))
     (t.fault
      ((underflow false) (overflow false) (missed_deadline false) (decode false)))
     (t.pc 1))
    |}]
;;
