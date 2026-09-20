open! Core
open Protocol_emulator

let runs levels =
  List.group levels ~break:(fun a b -> a <> b)
  |> List.map ~f:(fun g -> List.hd_exn g, List.length g)
;;

let decode_uart levels ~period =
  let levels = Array.of_list levels in
  let rec frames i acc =
    if i + (10 * period) > Array.length levels
    then List.rev acc
    else if levels.(i) = 0 && (i = 0 || levels.(i - 1) = 1)
    then (
      let byte =
        List.init 8 ~f:(fun b -> levels.(i + ((b + 1) * period) + (period / 2)) lsl b)
        |> List.fold ~init:0 ~f:( lor )
      in
      frames (i + (10 * period)) (byte :: acc))
    else frames (i + 1) acc
  in
  frames 0 []
;;

let serial_levels bytes ~period ~stop =
  let bit b = List.init period ~f:(fun _ -> b) in
  List.init 20 ~f:(fun _ -> 1)
  @ List.concat_map bytes ~f:(fun byte ->
    List.concat_map
      ((0 :: List.init 8 ~f:(fun i -> (byte lsr i) land 1)) @ [ stop ])
      ~f:bit)
  @ List.init (4 * period) ~f:(fun _ -> 1)
;;

module Spi_slave = struct
  type t =
    { sck : int
    ; shift_in : int
    ; bits : int
    ; shift_out : int
    ; replies : int list
    ; received : int list
    }

  let create replies =
    let shift_out, replies =
      match replies with
      | [] -> 0, []
      | r :: rest -> r, rest
    in
    { sck = 0; shift_in = 0; bits = 0; shift_out; replies; received = [] }
  ;;

  let miso t = (t.shift_out lsr 7) land 1
  let received t = List.rev t.received

  let step t ~sck ~mosi =
    let t' = { t with sck } in
    if sck = 1 && t.sck = 0
    then (
      let shift_in = (t.shift_in lsl 1) lor mosi land 0xff in
      if t.bits = 7
      then { t' with shift_in = 0; bits = 8; received = shift_in :: t.received }
      else { t' with shift_in; bits = t.bits + 1 })
    else if sck = 0 && t.sck = 1
    then
      if t.bits = 8
      then (
        match t.replies with
        | [] -> { t' with bits = 0; shift_out = 0 }
        | r :: replies -> { t' with bits = 0; shift_out = r; replies })
      else { t' with shift_out = (t.shift_out lsl 1) land 0xff }
    else t'
  ;;
end

(* Mode 0: sck idles low, mosi changes on the falling edge, both sides sample on the
   rising edge. Bytes go out back to back, or [gap] cycles apart. *)
module Spi_peer = struct
  type t =
    { half_period : int
    ; gap : int
    ; countdown : int
    ; edges : int
    ; sck : int
    ; mosi : int
    ; shift_out : int
    ; shift_in : int
    ; queue : int list
    ; received : int list
    }

  let begin_byte t =
    match t.queue with
    | [] -> t
    | byte :: queue ->
      { t with
        edges = 0
      ; countdown = t.half_period
      ; mosi = (byte lsr 7) land 1
      ; shift_out = (byte lsl 1) land 0xff
      ; queue
      }
  ;;

  let create ?(gap = 0) ~half_period bytes =
    begin_byte
      { half_period
      ; gap
      ; countdown = 0
      ; edges = 16
      ; sck = 0
      ; mosi = 0
      ; shift_out = 0
      ; shift_in = 0
      ; queue = bytes
      ; received = []
      }
  ;;

  let sck t = t.sck
  let mosi t = t.mosi
  let received t = List.rev t.received
  let idle t = t.edges = 16 && List.is_empty t.queue

  let step t ~miso =
    if idle t
    then t
    else if t.countdown > 1
    then { t with countdown = t.countdown - 1 }
    else if t.edges = 16
    then begin_byte t
    else if t.sck = 0
    then
      { t with
        sck = 1
      ; countdown = t.half_period
      ; edges = t.edges + 1
      ; shift_in = (t.shift_in lsl 1) lor miso land 0xff
      }
    else (
      let edges = t.edges + 1 in
      let t =
        { t with
          sck = 0
        ; countdown = t.half_period
        ; edges
        ; mosi = (t.shift_out lsr 7) land 1
        ; shift_out = (t.shift_out lsl 1) land 0xff
        }
      in
      if edges < 16
      then t
      else (
        let t = { t with received = t.shift_in :: t.received; shift_in = 0 } in
        if t.gap = 0 then begin_byte t else { t with mosi = 0; countdown = t.gap }))
  ;;
end

module I2c_slave = struct
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
  let drive_low t = t.drive_low
  let log t = List.rev t.log
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

(* Each quarter of a bit period is a frame; the master samples the bus a quarter into the
   high half of SCL. *)
module I2c_peer = struct
  module Op = struct
    type t =
      | Start
      | Write of int
      | Read of { ack : bool }
      | Stop
    [@@deriving sexp_of]
  end

  module Frame = struct
    type t =
      { sda : int
      ; scl : int
      ; sample : [ `No | `Bit | `Ack ]
      }

    let quiet sda scl = { sda; scl; sample = `No }

    let bit ~sda ~sample =
      [ quiet sda 0; quiet sda 1; { sda; scl = 1; sample }; quiet sda 0 ]
    ;;

    let of_op ~first (op : Op.t) =
      match op with
      | Start ->
        (if first then [ quiet 1 1 ] else [ quiet 1 0; quiet 1 1 ])
        @ [ quiet 0 1; quiet 0 0 ]
      | Write byte ->
        List.concat_map
          (List.init 8 ~f:(fun i -> (byte lsr (7 - i)) land 1))
          ~f:(fun b -> bit ~sda:b ~sample:`No)
        @ bit ~sda:1 ~sample:`Ack
      | Read { ack } ->
        List.concat (List.init 8 ~f:(fun _ -> bit ~sda:1 ~sample:`Bit))
        @ bit ~sda:(if ack then 0 else 1) ~sample:`No
      | Stop -> [ quiet 0 0; quiet 0 1; quiet 1 1 ]
    ;;
  end

  type t =
    { quarter : int
    ; frames : Frame.t list
    ; countdown : int
    ; shift : int
    ; bits : int
    ; log : string list
    }

  let create ~quarter ops =
    let frames = List.concat_mapi ops ~f:(fun i op -> Frame.of_op ~first:(i = 0) op) in
    { quarter; frames; countdown = quarter; shift = 0; bits = 0; log = [] }
  ;;

  let current t =
    match t.frames with
    | [] -> Frame.quiet 1 1
    | frame :: _ -> frame
  ;;

  let sda t = (current t).sda
  let scl t = (current t).scl
  let log t = List.rev t.log
  let idle t = List.is_empty t.frames

  let step t ~sda =
    if idle t
    then t
    else if t.countdown > 1
    then { t with countdown = t.countdown - 1 }
    else (
      let frames = List.tl_exn t.frames in
      let t = { t with frames; countdown = t.quarter } in
      match frames with
      | { sample = `Bit; _ } :: _ ->
        let shift = (t.shift lsl 1) lor sda land 0xff in
        if t.bits = 7
        then { t with shift = 0; bits = 0; log = [%string "read %{shift#Int}"] :: t.log }
        else { t with shift; bits = t.bits + 1 }
      | { sample = `Ack; _ } :: _ ->
        { t with log = (if sda = 0 then "ack" else "nack") :: t.log }
      | { sample = `No; _ } :: _ | [] -> t)
  ;;
end

(* USB low speed on the wire: J is D- high, K is D+ high, SE0 both low. NRZI with a
   transition for every zero, a zero stuffed after six ones, SYNC then bytes LSB first,
   EOP is two bits of SE0 and one of J. *)
module Usb_ls = struct
  let crc5 bits =
    List.fold bits ~init:0x1f ~f:(fun crc bit ->
      Crc.step ~width:5 ~poly:0x14 ~reflect:true crc ~bit)
    lxor 0x1f
  ;;

  let crc16 bits =
    List.fold bits ~init:0xffff ~f:(fun crc bit ->
      Crc.step ~width:16 ~poly:0xa001 ~reflect:true crc ~bit)
    lxor 0xffff
  ;;

  let bits_of_bytes bytes =
    List.concat_map bytes ~f:(fun byte -> List.init 8 ~f:(fun i -> (byte lsr i) land 1))
  ;;

  (* the CRC register after every bit of a packet, SYNC and PID included, which is what
     the receiver hands the host to check *)
  let residual bytes =
    List.fold
      (bits_of_bytes (0x80 :: bytes))
      ~init:0xffff
      ~f:(fun crc bit -> Crc.step ~width:16 ~poly:0xa001 ~reflect:true crc ~bit)
  ;;

  let bytes_of_bits bits =
    List.chunks_of bits ~length:8
    |> List.filter ~f:(fun chunk -> List.length chunk = 8)
    |> List.map ~f:(fun chunk ->
      List.foldi chunk ~init:0 ~f:(fun i acc b -> acc lor (b lsl i)))
  ;;

  let stuff bits =
    let rec go bits ones acc =
      match bits with
      | [] -> List.rev acc
      | 1 :: rest when ones = 5 -> go rest 0 (0 :: 1 :: acc)
      | 1 :: rest -> go rest (ones + 1) (1 :: acc)
      | _ :: rest -> go rest 0 (0 :: acc)
    in
    go bits 0 []
  ;;

  let unstuff bits =
    let rec go bits ones acc =
      match bits with
      | [] -> List.rev acc
      | 0 :: rest when ones = 6 -> go rest 0 acc
      | 1 :: rest -> go rest (ones + 1) (1 :: acc)
      | _ :: rest -> go rest 0 (0 :: acc)
    in
    go bits 0 []
  ;;

  module Line = struct
    type t =
      | J
      | K
      | Se0
    [@@deriving sexp_of, equal]

    let of_pins ~dp ~dm =
      match dp, dm with
      | 0, 1 -> Some J
      | 1, 0 -> Some K
      | 0, 0 -> Some Se0
      | _ -> None
    ;;
  end

  (* The line states of a whole packet, one per bit time, from the bus idle. *)
  let encode bytes =
    let bits = stuff (bits_of_bytes (0x80 :: bytes)) in
    let _, states =
      List.fold_map bits ~init:Line.J ~f:(fun line bit ->
        let line : Line.t =
          match bit, line with
          | 1, l -> l
          | _, J -> K
          | _, (K | Se0) -> J
        in
        line, line)
    in
    states @ [ Se0; Se0; J ]
  ;;

  module Sniffer = struct
    type t =
      { bit_period : int
      ; line : Line.t
      ; since_change : int
      ; symbols : Line.t list
      ; packets : int list list
      }

    let create ~bit_period =
      { bit_period; line = J; since_change = 0; symbols = []; packets = [] }
    ;;

    let packets t = List.rev t.packets

    let decode symbols =
      let symbols = List.drop_while (List.rev symbols) ~f:(Line.equal J) in
      let _, bits =
        List.fold_map symbols ~init:Line.J ~f:(fun prev s ->
          s, if Line.equal prev s then 1 else 0)
      in
      match bytes_of_bits (unstuff bits) with
      | 0x80 :: bytes -> Some bytes
      | _ -> None
    ;;

    (* Each line state lasts a whole number of bit times; a run of [n] periods is [n]
       symbols. SE0 ends the packet. *)
    let step t ~dp ~dm =
      match Line.of_pins ~dp ~dm with
      | None -> t
      | Some line when Line.equal line t.line ->
        { t with since_change = t.since_change + 1 }
      | Some line ->
        let n = (t.since_change + (t.bit_period / 2)) / t.bit_period in
        let symbols = List.init n ~f:(fun _ -> t.line) @ t.symbols in
        (match line with
         | Se0 ->
           let packets =
             match decode symbols with
             | Some bytes -> bytes :: t.packets
             | None -> t.packets
           in
           { t with line; since_change = 1; symbols = []; packets }
         | J | K ->
           let symbols =
             match t.line with
             | Se0 -> []
             | J | K -> symbols
           in
           { t with line; since_change = 1; symbols })
    ;;
  end
end
