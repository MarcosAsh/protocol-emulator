open! Core
open Protocol_emulator
open Protocol_models

let bit_period = 32
let ack = 0xd2
let nak = 0x5a
let data0 = 0xc3
let data1 = 0x4b
let max_packet = 8

module Request = struct
  type t =
    { request_type : int
    ; request : int
    ; value : int
    ; index : int
    ; length : int
    }

  let bytes t =
    [ t.request_type
    ; t.request
    ; t.value land 0xff
    ; t.value lsr 8
    ; t.index land 0xff
    ; t.index lsr 8
    ; t.length land 0xff
    ; t.length lsr 8
    ]
  ;;

  let of_bytes = function
    | [ request_type; request; v0; v1; i0; i1; l0; l1 ] ->
      { request_type
      ; request
      ; value = v0 lor (v1 lsl 8)
      ; index = i0 lor (i1 lsl 8)
      ; length = l0 lor (l1 lsl 8)
      }
    | bytes -> raise_s [%message "a SETUP carries eight bytes" (bytes : int list)]
  ;;

  let get_descriptor ?(interface = false) ~kind ~length () =
    { request_type = (if interface then 0x81 else 0x80)
    ; request = 6
    ; value = kind lsl 8
    ; index = 0
    ; length
    }
  ;;

  let set_address address =
    { request_type = 0; request = 5; value = address; index = 0; length = 0 }
  ;;

  let set_configuration value =
    { request_type = 0; request = 9; value; index = 0; length = 0 }
  ;;
end

(* The demo board's side: what the RP2040 does with the words the core hands it. It is
   slow, which the latency stands for; the core covers for it with NAKs. *)
module Board = struct
  type parse =
    | Tag
    | Words of
        { tag : int
        ; left : int
        ; words : int list
        }

  type t =
    { descriptors : (int * int list) list
    ; latency : int
    ; mutable parse : parse
    ; mutable chunks : int list list
    ; mutable toggle : int
    ; mutable report_toggle : int
    ; mutable due : (int * int list) list
    ; mutable new_address : int option
    ; mutable reload : int option
    ; mutable report : int list option
    ; mutable dropped : bool
    }

  let create ~descriptors ~latency =
    { descriptors
    ; latency
    ; parse = Tag
    ; chunks = []
    ; toggle = data1
    ; report_toggle = data0
    ; due = []
    ; new_address = None
    ; reload = None
    ; report = None
    ; dropped = false
    }
  ;;

  let reply ~endpoint ~pid payload =
    let rec words = function
      | [] -> []
      | [ a ] -> [ a ]
      | a :: b :: rest -> (a lor (b lsl 8)) :: words rest
    in
    let data = words payload in
    (endpoint lor (pid lsl 8))
    :: (8 * List.length payload lor (List.length data lsl 8))
    :: data
  ;;

  let queue t ~endpoint ~pid payload =
    t.due <- t.due @ [ t.latency, reply ~endpoint ~pid payload ]
  ;;

  let next_chunk t =
    match t.chunks with
    | [] -> ()
    | chunk :: rest ->
      t.chunks <- rest;
      queue t ~endpoint:0 ~pid:t.toggle chunk;
      t.toggle <- (if t.toggle = data1 then data0 else data1)
  ;;

  let setup t (r : Request.t) =
    t.toggle <- data1;
    match r.request with
    | 6 ->
      let descriptor =
        List.Assoc.find t.descriptors (r.value lsr 8) ~equal:Int.equal
        |> Option.value ~default:[]
      in
      let data = List.take descriptor r.length in
      let chunks = List.chunks_of data ~length:max_packet in
      (* a transfer that stops short of what was asked on a full packet ends with an empty
         one *)
      let short = List.length data < r.length && List.length data % max_packet = 0 in
      t.chunks <- (if short then chunks @ [ [] ] else chunks);
      next_chunk t
    | 5 ->
      t.new_address <- Some r.value;
      t.chunks <- [ [] ];
      next_chunk t
    | _ ->
      t.chunks <- [ [] ];
      next_chunk t
  ;;

  (* the first bit received is the top bit of a word *)
  let bytes_of_word w =
    let reverse byte =
      List.init 8 ~f:(fun i -> ((byte lsr i) land 1) lsl (7 - i))
      |> List.sum (module Int) ~f:Fn.id
    in
    [ reverse (w lsr 8); reverse (w land 0xff) ]
  ;;

  let word t w =
    match t.parse with
    | Tag ->
      (match w with
       | 1 -> t.parse <- Words { tag = 1; left = 6; words = [] }
       | 2 -> t.parse <- Words { tag = 2; left = 2; words = [] }
       | 3 ->
         if not (List.is_empty t.chunks)
         then next_chunk t
         else if Option.is_some t.report
                 && (not t.dropped)
                 && Option.is_none t.new_address
         then (
           (* the report went out *)
           t.report <- None;
           t.report_toggle <- (if t.report_toggle = data0 then data1 else data0))
         else (
           t.reload <- t.new_address;
           t.new_address <- None)
       | 4 -> t.dropped <- true
       | tag -> raise_s [%message "unknown tag" (tag : int)])
    | Words { tag; left; words } ->
      let words = w :: words in
      if left > 1
      then t.parse <- Words { tag; left = left - 1; words }
      else (
        t.parse <- Tag;
        if tag = 1
        then (
          let bytes = List.concat_map (List.rev words) ~f:bytes_of_word in
          setup t (Request.of_bytes (List.take bytes 8))))
  ;;

  let reset t =
    t.parse <- Tag;
    t.chunks <- [];
    t.toggle <- data1;
    t.report_toggle <- data0;
    t.due <- [];
    t.new_address <- None;
    t.reload <- None;
    t.report <- None;
    t.dropped <- false
  ;;

  let send_report t payload = queue t ~endpoint:1 ~pid:t.report_toggle payload

  let report t payload =
    t.report <- Some payload;
    send_report t payload
  ;;

  (* a report the core had to drop goes back in once the control transfer is through *)
  let requeue t =
    match t.report with
    | Some payload when t.dropped && List.is_empty t.chunks && List.is_empty t.due ->
      t.dropped <- false;
      send_report t payload
    | _ -> ()
  ;;
end

type t =
  { mutable machine : Machine.t
  ; mutable sniffer : Usb_ls.Sniffer.t
  ; mutable ends : int
  ; mutable se0 : bool
  ; mutable se0_cycles : int
  ; mutable address : int
  ; mutable naks : int
  ; board : Board.t
  }

let load ~address =
  let machine =
    Machine.create
      ~config:Firmware.usb_device_config
      ~program:
        (Firmware.assemble (Firmware.usb_device ~address ~half_period:(bit_period / 2)))
    |> ok_exn
  in
  Machine.write_tx machine bit_period |> ok_exn
;;

(* two and a half milliseconds at 48 MHz *)
let reset_cycles = 120_000
let faults t = t.machine.fault
let naks t = t.naks

(* one clock: the host's level where the device does not drive, the board's turn, and the
   sniffer's *)
let cycle t (line : Usb_ls.Line.t) =
  let dp, dm =
    match line with
    | J -> 0, 1
    | K -> 1, 0
    | Se0 -> 0, 0
  in
  let inputs =
    (dp lsl Firmware.usb_device_dp_pin) lor (dm lsl Firmware.usb_device_dm_pin)
  in
  let before = t.machine in
  t.machine <- Machine.step t.machine ~inputs;
  if not ([%equal: Machine.Fault.t] t.machine.fault Machine.Fault.none)
  then
    raise_s
      [%message
        "the core faulted"
          (t.machine.fault : Machine.Fault.t)
          ~pc:(before.pc : int)
          ~phase:(before.now - before.t : int)
          (before.x : int)
          (before.y : int)];
  (match Machine.read_rx t.machine with
   | Some (word, machine) ->
     t.machine <- machine;
     Board.word t.board word
   | None -> ());
  (match t.board.due with
   | (0, words) :: rest ->
     if List.length t.machine.tx_fifo + List.length words <= Machine.fifo_depth
     then (
       t.machine
       <- List.fold words ~init:t.machine ~f:(fun m w -> Machine.write_tx m w |> ok_exn);
       t.board.due <- rest)
   | (n, words) :: rest -> t.board.due <- (n - 1, words) :: rest
   | [] -> Board.requeue t.board);
  let pin n level =
    if (t.machine.pin_dir lsr n) land 1 = 1
    then (t.machine.pin_out lsr n) land 1
    else level
  in
  let dp = pin Firmware.usb_device_dp_pin dp in
  let dm = pin Firmware.usb_device_dm_pin dm in
  (* a packet is over when the line comes back from SE0 *)
  let se0 = dp = 0 && dm = 0 in
  if t.se0 && not se0
  then (
    t.ends <- t.ends + 1;
    (* the board sits on the same two pins: an SE0 of two and a half milliseconds is a bus
       reset, and the device answers to address 0 again with nothing pending *)
    if t.se0_cycles >= reset_cycles
    then (
      t.machine <- load ~address:0;
      Board.reset t.board));
  t.se0_cycles <- (if se0 then t.se0_cycles + 1 else 0);
  t.se0 <- se0;
  t.sniffer <- Usb_ls.Sniffer.step t.sniffer ~dp ~dm
;;

let bits t line ~count =
  Fn.apply_n_times ~n:(count * bit_period) (fun () -> cycle t line) ()
;;

let create ~descriptors ~latency =
  let t =
    { machine = load ~address:0
    ; sniffer = Usb_ls.Sniffer.create ~bit_period
    ; ends = 0
    ; se0 = false
    ; se0_cycles = 0
    ; address = 0
    ; naks = 0
    ; board = Board.create ~descriptors ~latency
    }
  in
  (* a host leaves a new device alone for a while; the core needs a few cycles of it *)
  bits t J ~count:20;
  t
;;

let send t packet = List.iter (Usb_ls.encode packet) ~f:(fun line -> bits t line ~count:1)

(* the bus released until the device has ended a packet; a real host gives up after
   eighteen bit times of silence, this one after the longest packet there can be *)
let listen t =
  let ends = t.ends in
  let rec wait left =
    if t.ends > ends
    then (
      bits t J ~count:3;
      List.last (Usb_ls.Sniffer.packets t.sniffer))
    else if left = 0
    then None
    else (
      bits t J ~count:1;
      wait (left - 1))
  in
  wait 160
;;

let token t ~pid ~endpoint =
  let bits_ =
    List.init 11 ~f:(fun i ->
      if i < 7 then (t.address lsr i) land 1 else (endpoint lsr (i - 7)) land 1)
  in
  [ pid
  ; t.address lor ((endpoint land 1) lsl 7)
  ; (endpoint lsr 1) lor (Usb_ls.crc5 bits_ lsl 3)
  ]
;;

let data ~pid payload =
  let crc = Usb_ls.crc16 (Usb_ls.bits_of_bytes payload) in
  (pid :: payload) @ [ crc land 0xff; crc lsr 8 ]
;;

let expect_ack t what =
  match listen t with
  | Some [ pid ] when pid = ack -> ()
  | other -> raise_s [%message "no ACK" what (other : int list option)]
;;

(* an IN, again after every NAK; the payload once the CRC has been checked *)
let rec in_ t ~endpoint ~tries =
  send t (token t ~pid:0x69 ~endpoint);
  match listen t with
  | Some [ pid ] when pid = nak ->
    t.naks <- t.naks + 1;
    if tries = 0
    then None
    else (
      bits t J ~count:200;
      in_ t ~endpoint ~tries:(tries - 1))
  | Some (pid :: rest) when pid = data0 || pid = data1 ->
    let payload = List.take rest (List.length rest - 2) in
    if not ([%equal: int list] (data ~pid payload) (pid :: rest))
    then raise_s [%message "bad CRC from the device" (rest : int list)];
    send t [ ack ];
    bits t J ~count:4;
    Some payload
  | other -> raise_s [%message "no answer to IN" (other : int list option)]
;;

let setup t (request : Request.t) =
  send t (token t ~pid:0x2d ~endpoint:0);
  bits t J ~count:3;
  send t (data ~pid:data0 (Request.bytes request));
  expect_ack t "SETUP";
  bits t J ~count:4
;;

let control_in t request =
  setup t request;
  let rec stage acc =
    match in_ t ~endpoint:0 ~tries:50 with
    | None -> raise_s [%message "the device never answered"]
    | Some payload ->
      let acc = acc @ payload in
      if List.length payload < max_packet || List.length acc >= request.length
      then acc
      else stage acc
  in
  let bytes = stage [] in
  send t (token t ~pid:0xe1 ~endpoint:0);
  bits t J ~count:3;
  send t (data ~pid:data1 []);
  expect_ack t "status";
  bits t J ~count:4;
  bytes
;;

let control_out t request =
  setup t request;
  (match in_ t ~endpoint:0 ~tries:50 with
   | Some [] -> ()
   | other -> raise_s [%message "no status packet" (other : int list option)]);
  (* the board reloads the core with its new address once the status is acknowledged *)
  bits t J ~count:((t.board.latency / bit_period) + 10);
  match t.board.reload with
  | Some address ->
    t.board.reload <- None;
    t.machine <- load ~address;
    t.address <- address;
    bits t J ~count:20
  | None -> ()
;;

(* a host resets the bus for ten milliseconds or more; three are enough here *)
let reset t =
  Fn.apply_n_times ~n:(reset_cycles + (reset_cycles / 5)) (fun () -> cycle t Se0) ();
  t.address <- 0;
  bits t J ~count:40
;;

let report t payload = Board.report t.board payload
let interrupt_in t ~endpoint = in_ t ~endpoint ~tries:0
