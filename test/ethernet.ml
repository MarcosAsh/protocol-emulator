open! Core
open Protocol_emulator

let td_plus = Isa.first_bidir_pin
let cycle_ns = 25
let link_tenth = 64000

let firmware =
  {|
    pull                     ; a tenth of the link pulse interval
    mov p, osr
    set pindirs, 3
    mov t, now
    add t, p
link:
    set x, 9
tenth:
    wait t+
    jmp tx, send             ; a frame is waiting
    jmp x--, tenth
    set pins, 1 [3]          ; the link pulse, 100 ns
    set pins, 0
    jmp link
send:
    pull                     ; its length in bits less one
    mov y, osr
    set x, 0
    seek
    out null, 16             ; so the next out pulls from the data memory
bit:
    out pins, 1 [1]          ; the first half of the bit, and with the jump the second
    jmp y--, bit
    set pins, 1 [10]         ; TP_IDL, high 275 ns
    set pins, 0
    mov t, now
    add t, p
    jmp link
|}
;;

let config =
  { Program_config.default with
    out_base = td_plus
  ; set_base = td_plus
  ; set_count = 2
  ; manchester = true
  ; autopull = true
  ; autopull_data = true
  }
;;

module Frame = struct
  let crc32 bytes =
    List.fold bytes ~init:0xffffffff ~f:(fun crc byte ->
      Fn.apply_n_times
        ~n:8
        (fun crc -> if crc land 1 = 1 then (crc lsr 1) lxor 0xedb88320 else crc lsr 1)
        (crc lxor byte))
    lxor 0xffffffff
  ;;

  let big16 n = [ n lsr 8; n land 0xff ]

  (* the ones' complement sum of the header's sixteen bit words, complemented *)
  let ip_checksum header =
    let rec sum = function
      | hi :: lo :: rest -> ((hi lsl 8) lor lo) + sum rest
      | [ hi ] -> hi lsl 8
      | [] -> 0
    in
    let rec fold s = if s > 0xffff then fold ((s land 0xffff) + (s lsr 16)) else s in
    lnot (fold (sum header)) land 0xffff
  ;;

  let udp ~payload =
    let payload = String.to_list payload |> List.map ~f:Char.to_int in
    let udp = big16 1234 @ big16 1234 @ big16 (8 + List.length payload) @ big16 0 in
    let ip ~checksum =
      [ 0x45; 0 ]
      @ big16 (20 + 8 + List.length payload)
      @ [ 0; 0; 0x40; 0; 64; 17 ]
      @ big16 checksum
      @ [ 10; 0; 0; 2; 255; 255; 255; 255 ]
    in
    let ip = ip ~checksum:(ip_checksum (ip ~checksum:0)) in
    let frame =
      List.init 6 ~f:(Fn.const 0xff)
      @ [ 0x02; 0; 0; 0; 0; 0x02 ]
      @ big16 0x0800
      @ ip
      @ udp
      @ payload
    in
    let length = Int.max 60 (List.length frame) in
    let length = length + (length land 1) in
    frame @ List.init (length - List.length frame) ~f:(Fn.const 0)
  ;;

  let wire frame =
    let fcs = crc32 frame in
    List.init 7 ~f:(Fn.const 0x55)
    @ [ 0xd5 ]
    @ frame
    @ List.init 4 ~f:(fun n -> (fcs lsr (8 * n)) land 0xff)
  ;;

  let rec words = function
    | lo :: hi :: rest -> (lo lor (hi lsl 8)) :: words rest
    | [ lo ] -> [ lo ]
    | [] -> []
  ;;
end

module Receiver = struct
  (* what the pair shows in a cycle: +1 is TD+ high, -1 TD- high, 0 idle *)
  type t =
    { cycle : int
    ; burst : int list (** The levels since the line left idle, last first. *)
    ; burst_start : int
    ; last_pulse : int option
    ; frames : int list list
    ; link_intervals : int list
    ; violations : string list
    }

  let create () =
    { cycle = 0
    ; burst = []
    ; burst_start = 0
    ; last_pulse = None
    ; frames = []
    ; link_intervals = []
    ; violations = []
    }
  ;;

  let violation t message = { t with violations = message :: t.violations }
  let ns cycles = cycles * cycle_ns

  let rec bits = function
    | a :: a' :: b :: b' :: rest when a = a' && b = b' && a = -b ->
      let decoded, tail = bits rest in
      Bool.to_int (b > 0) :: decoded, tail
    | tail -> [], tail
  ;;

  let rec bytes = function
    | [] -> []
    | bits ->
      let #(byte, rest) = List.split_n bits 8 in
      List.foldi byte ~init:0 ~f:(fun n acc bit -> acc lor (bit lsl n)) :: bytes rest
  ;;

  let link_pulse t levels =
    let t =
      if ns (List.length levels) >= 80 && ns (List.length levels) <= 200
      then t
      else violation t [%string "a link pulse of %{ns (List.length levels)#Int} ns"]
    in
    let t =
      match t.last_pulse with
      | None -> t
      | Some last ->
        let interval = t.burst_start - last in
        let t = { t with link_intervals = interval :: t.link_intervals } in
        if ns interval >= 8_000_000 && ns interval <= 24_000_000
        then t
        else violation t [%string "link pulses %{ns interval#Int} ns apart"]
    in
    { t with last_pulse = Some t.burst_start }
  ;;

  let frame t levels =
    let decoded, tail = bits levels in
    let t =
      if List.for_all tail ~f:(fun l -> l > 0)
         && ns (List.length tail) >= 250
         && ns (List.length tail) <= 350
      then t
      else
        violation
          t
          [%string "a frame ends with %{List.length tail#Int} cycles not TP_IDL"]
    in
    let t =
      if List.length decoded % 8 = 0
      then t
      else violation t [%string "%{List.length decoded#Int} bits are not whole bytes"]
    in
    match bytes decoded with
    | 0x55 :: 0x55 :: 0x55 :: 0x55 :: 0x55 :: 0x55 :: 0x55 :: 0xd5 :: frame ->
      { t with frames = frame :: t.frames; last_pulse = None }
    | _ -> { (violation t "no preamble and start of frame") with last_pulse = None }
  ;;

  let step t ~td_plus ~td_minus =
    let level =
      match td_plus, td_minus with
      | 1, 0 -> 1
      | 0, 1 -> -1
      | _ -> 0
    in
    let t =
      if td_plus = 1 && td_minus = 1 then violation t "TD+ and TD- both high" else t
    in
    let t =
      match t.burst, level with
      | [], 0 -> t
      | [], level -> { t with burst = [ level ]; burst_start = t.cycle }
      | burst, 0 ->
        let levels = List.rev burst in
        let t = { t with burst = [] } in
        if List.for_all levels ~f:(fun l -> l > 0) && List.length levels <= 8
        then link_pulse t levels
        else frame t levels
      | burst, level -> { t with burst = level :: burst }
    in
    { t with cycle = t.cycle + 1 }
  ;;

  let frames t = List.rev t.frames
  let link_intervals t = List.rev t.link_intervals
  let violations t = List.rev t.violations
end
