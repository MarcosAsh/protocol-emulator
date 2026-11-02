open! Core
open Hardcaml
open Hardcaml_lws
open Protocol_emulator
open Protocol_models

let ( <--. ) = Bits.( <--. )

module Two = Engines.Make (struct
    let engines = 2
  end)

module Chip = Hardcaml_test_harness.Lws_harness.Make (Two.I) (Two.O)

(* the analyser's verdict, the kernel's on its rows, and the certificate's length in data
   memory words, which shares the data memory with the packets *)
let%expect_test "the firmware's verdict and certificate" =
  let program = Asm.assemble Usb_fs.device |> ok_exn in
  let config = Asm.Program.configure program Usb_fs.config in
  let words = Asm.Program.words program |> ok_exn in
  let rows = Analyser.analyse ~config program.instructions in
  let kernel = Kernel.check ~config ~words (Kernel.Table.of_analyser rows) in
  let certificate =
    Load_check.of_program ~config words |> ok_exn |> Load_check.to_words
  in
  print_s
    [%message
      ""
        ~analyser:(Analyser.check ~config program : Analyser.Verdict.t Or_error.t)
        (kernel : unit Or_error.t)
        ~certificate_words:(List.length certificate : int)];
  [%expect
    {|
    ((analyser (Ok ((words 251) (deadline_waits 5) (worst_slack (0)))))
     (kernel (Ok ())) (certificate_words 132))
    |}]
;;

(* One data packet sent from its record, with the model and the RTL in lockstep: what the
   pins carry is [Usb.data] of the payload, the reference's CRC-16 and stuffing, for any
   PID and up to eight bytes, mostly of 0xff to stuff the most, and a STALL as it is.
   Prints the most bits owed. *)
let%expect_test "every data packet the chip sends is the reference encoding" =
  let program =
    [ "    set pins, 1"; "    set pindirs, 0"; "    set x, 0"; "    mov t, now" ]
    @ Usb_fs.send_data ~name:"reply" ~then_:"done"
    @ [ "done:"; "    halt" ]
    |> String.concat ~sep:"\n"
    |> Asm.assemble
    |> ok_exn
  in
  let config = Asm.Program.configure program Usb_fs.config in
  let words = Asm.Program.words program |> ok_exn in
  let most_owed = ref 0 in
  let byte =
    Quickcheck.Generator.weighted_union
      [ 4., Quickcheck.Generator.return 0xff
      ; 1., Quickcheck.Generator.of_list [ 0x00; 0x7f; 0xfe; 0x3f; 0xfc ]
      ; 2., Int.gen_incl 0 255
      ]
  in
  let packet =
    Quickcheck.Generator.both
      (Quickcheck.Generator.of_list [ 0xc3; 0x4b ])
      (Quickcheck.Generator.bind (Int.gen_incl 0 8) ~f:(fun n ->
         List.gen_with_length n byte))
  in
  Quickcheck.test
    ~trials:300
    ~examples:[ 0x4b, List.init 8 ~f:(Fn.const 0xff); 0xc3, []; 0x1e, [] ]
    packet
    ~sexp_of:[%sexp_of: int * int list]
    ~f:(fun (pid, payload) ->
      let sniffer = ref (Usb_ls.Sniffer.create ~bit_period:4) in
      let react (m : Machine.t) =
        let pin n = (m.pin_out lsr n) land 1 in
        most_owed := Int.max !most_owed m.line_count;
        sniffer
        := Usb_ls.Sniffer.step !sniffer ~dp:(pin Usb_fs.dm_pin) ~dm:(pin Usb_fs.dp_pin)
      in
      let model, mismatch =
        Lockstep.run
          ~cycles:600
          ~data:(Usb_fs.data_record (pid :: payload))
          ~line_table:Usb_fs.line_table
          ~react
          ~config
          ~program:words
          ~inputs:(Fn.const 0)
          ()
      in
      Expect_test_helpers_core.require_equal
        ~message:"lockstep"
        (module struct
          type t = int option [@@deriving equal, sexp_of]
        end)
        (Option.map mismatch ~f:Tuple3.get1)
        None;
      Expect_test_helpers_core.require_equal
        ~message:"packet"
        (module struct
          type t = int list list [@@deriving equal, sexp_of]
        end)
        (Usb_ls.Sniffer.packets !sniffer)
        [ (if pid land 3 = 2 then [ pid ] else Usb.data ~pid payload) ];
      Expect_test_helpers_core.require_equal
        ~message:"halted, nothing owed"
        (module struct
          type t = bool * int [@@deriving equal, sexp_of]
        end)
        (model.halted, model.line_count)
        (true, 0));
  print_s [%message (!most_owed : int)];
  [%expect {| (!most_owed 11) |}]
;;

let device_descriptor =
  [ 18; 1; 0x10; 0x01; 0; 0; 0; 8; 0x09; 0x12; 0x02; 0x00; 0x00; 0x01; 0; 0; 0; 1 ]
;;

let data0 = 0xc3
let data1 = 0x4b
let ack = 0xd2
let nak = 0x5a

(* a control read's data stage, DATA1 first, each packet its PID and data: the chip adds
   the CRC-16 *)
let chunks payload =
  List.chunks_of payload ~length:8
  |> List.mapi ~f:(fun n chunk -> (if n % 2 = 0 then data1 else data0) :: chunk)
;;

let zero_length = [ data1 ]

module Line = Usb_ls.Line

type bus =
  { mutable cycle : int
  ; mutable eop_j : int
  ; mutable host : Line.t option
  ; mutable sniffer : Usb_ls.Sniffer.t
  ; mutable device_driving : bool
  ; mutable device_line : Line.t
  }

let line_of ~dp ~dm : Line.t =
  match dp, dm with
  | 1, 0 -> J
  | 0, 1 -> K
  | _ -> Se0
;;

let pins_of : Line.t -> int * int = function
  | J -> 1, 0
  | K -> 0, 1
  | Se0 -> 0, 0
;;

(* Engine 0 as the device, the receiver re-armed on its pins, a host that makes each
   control read of [requests], and a board that queues each reply chunk as the last is
   acknowledged. Engine 0 runs beside [System] every cycle, given the status pins the chip
   shows it and each packet's words as the receiver ends it. Prints each transaction, the
   device's turnarounds in bit times from the EOP's J to its SOP, and the first cycle the
   model and the RTL part, if any. *)
let control_reads ?(board_latency = 100) ?(rearm = true) requests =
  let replies = List.concat_map requests ~f:(fun (_, payload) -> chunks payload) in
  let layout = Usb_fs.Layout.create (zero_length :: replies) in
  let program = Asm.assemble Usb_fs.device |> ok_exn in
  let program_words = Asm.Program.words program |> ok_exn in
  let config = Asm.Program.configure program Usb_fs.config in
  Chip.run
    ~random_initial_state:`All
    ~create:(Two.hierarchical ~gated:false ~memory:Flops)
    (fun (h @ local) ~inputs:i ~outputs ->
       let o = Before_and_after_edge.after_edge outputs in
       let int r = Bits.to_unsigned_int !r in
       let p = List.nth_exn i.hosts 0 in
       let e = List.nth_exn o.engines 0 in
       let bus =
         { cycle = 0
         ; eop_j = 0
         ; host = None
         ; sniffer = Usb_ls.Sniffer.create ~bit_period:4
         ; device_driving = false
         ; device_line = J
         }
       in
       let model = ref None in
       let mismatch = ref None in
       let receiving = ref false in
       let level () : Line.t =
         if bus.device_driving then bus.device_line else Option.value bus.host ~default:J
       in
       (* finished, good, receiving and error, as engine 0 reads them this cycle *)
       let status () =
         let u = Usb_frame_rx.Status.map o.usb ~f:int in
         u.finished
         lor (u.good lsl 1)
         lor (u.receiving lsl 2)
         lor ((u.dropped lor u.stuff_error) lsl 3)
       in
       let cycle ?tx ?(pop = false) () =
         let dp, dm = pins_of (level ()) in
         i.rd <--. dp * 3;
         i.dm <--. dm * 3;
         i.pads <--. (dp lsl Usb_fs.dp_pin) lor (dm lsl Usb_fs.dm_pin);
         p.tx.valid := Bits.of_bool (Option.is_some tx);
         p.tx.value <--. Option.value tx ~default:0;
         p.rx_pop := Bits.of_bool pop;
         let status = status () in
         Option.iter !model ~f:(fun m ->
           let m =
             Option.fold tx ~init:m ~f:(fun m word ->
               System.update m 0 ~f:(fun m -> Machine.write_tx m word |> ok_exn))
           in
           let m =
             if pop
             then
               System.update m 0 ~f:(fun m ->
                 Machine.read_rx m |> Option.value_exn |> snd)
             else m
           in
           model := Some m);
         Lws.cycle h;
         bus.cycle <- bus.cycle + 1;
         Option.iter !model ~f:(fun m ->
           let m = System.step m ~owner:0 ~status ~pads:0 in
           model := Some m;
           if Option.is_none !mismatch
              && not
                   (Lockstep.State.equal
                      (Lockstep.State.of_machine (List.hd_exn m.engines))
                      (Lockstep.State.of_outputs e))
           then (
             mismatch := Some bus.cycle;
             print_s
               [%message
                 (Lockstep.State.of_machine (List.hd_exn m.engines) : Lockstep.State.t)
                   (Lockstep.State.of_outputs e : Lockstep.State.t)]));
         let dir = int o.pin_dir in
         let out = int o.pin_out in
         bus.device_driving <- (dir lsr Usb_fs.dp_pin) land 3 = 3;
         bus.device_line
         <- line_of
              ~dp:((out lsr Usb_fs.dp_pin) land 1)
              ~dm:((out lsr Usb_fs.dm_pin) land 1);
         let dp, dm = pins_of (level ()) in
         (* the sniffer reads low speed's pins, J on D- *)
         bus.sniffer <- Usb_ls.Sniffer.step bus.sniffer ~dp:dm ~dm:dp;
         (* the packet the receiver just ended lands in the model's data memory too *)
         let now = int o.usb.receiving = 1 in
         if !receiving && not now
         then
           Option.iter !model ~f:(fun m ->
             let packet = List.last_exn (Usb_ls.Sniffer.packets bus.sniffer) in
             List.iteri (Manchester_line.words packet) ~f:(fun n word ->
               (List.hd_exn m.engines).data.(Usb_fs.rx_base + n) <- word));
         receiving := now
       in
       let cycles n =
         for _ = 1 to n do
           cycle ()
         done
       in
       let pulse (s : Bits.t ref) =
         s := Bits.vdd;
         cycle ();
         s := Bits.gnd
       in
       i.clocking.clear := Bits.vdd;
       cycle ();
       i.clocking.clear := Bits.gnd;
       Engine.Config.iter2 p.config (Engine.Config.of_program_config config) ~f:( := );
       List.iteri program_words ~f:(fun addr word ->
         p.program_write.valid := Bits.vdd;
         p.program_write.addr <--. addr;
         p.program_write.data <--. word;
         cycle ());
       p.program_write.valid := Bits.gnd;
       Array.iteri layout.words ~f:(fun addr word ->
         p.data_write.valid := Bits.vdd;
         p.data_write.addr <--. addr;
         p.data_write.data <--. word;
         cycle ());
       p.data_write.valid := Bits.gnd;
       List.iteri (Line_code.words Usb_fs.line_table) ~f:(fun addr word ->
         p.line_write.valid := Bits.vdd;
         p.line_write.addr <--. addr;
         p.line_write.data <--. word;
         cycle ());
       p.line_write.valid := Bits.gnd;
       let push words = List.iter words ~f:(fun word -> cycle ~tx:word ()) [@nontail] in
       let pop () =
         let words = Queue.create () in
         while int e.rx_level > 0 do
           Queue.enqueue words (int e.rx_head);
           cycle ~pop:true ()
         done;
         Queue.to_list words
       in
       let address = 0 in
       let first = Usb_fs.in_token ~address ~endpoint:0 in
       push [ first ];
       i.frame_usb := Bits.vdd;
       i.frame_owner := Bits.gnd;
       i.frame.base <--. Usb_fs.rx_base;
       i.frame.fifty := Bits.of_bool rearm;
       pulse i.frame.arm;
       (* a start pulse, a cycle for the fetch, then the cores as [Machine.create] has
          them, the device with its first word in the tx fifo *)
       pulse p.start;
       cycle ();
       let machine ~program ~config =
         Machine.create ~config ~program
         |> ok_exn
         |> Fn.flip Machine.load_data (Array.to_list layout.words)
         |> ok_exn
         |> Fn.flip Machine.load_line_table Usb_fs.line_table
       in
       let device =
         Machine.write_tx (machine ~program:program_words ~config) first |> ok_exn
       in
       let idle = machine ~program:[] ~config:Program_config.default |> Machine.stop in
       model := Some (System.create [ device; idle ]);
       cycles 40;
       let send packet =
         List.iter (Usb_ls.encode packet) ~f:(fun line ->
           (match bus.host, line with
            | Some Se0, J -> bus.eop_j <- bus.cycle
            | _ -> ());
           bus.host <- Some line;
           cycles 4);
         bus.host <- None
       in
       (* the device's packet if it starts within 16 bit times of the host's EOP, and the
          cycles from the EOP's J to its SOP *)
       let listen () =
         let seen = List.length (Usb_ls.Sniffer.packets bus.sniffer) in
         let sop = ref None in
         let waited = ref 0 in
         while
           (Option.is_none !sop && !waited < 64)
           || (Option.is_some !sop && bus.device_driving)
         do
           if Option.is_none !sop && bus.device_driving && Line.equal bus.device_line K
           then sop := Some (bus.cycle - bus.eop_j);
           incr waited;
           cycle ()
         done;
         cycles 8;
         Option.map !sop ~f:(fun at ->
           List.nth (Usb_ls.Sniffer.packets bus.sniffer) seen, at)
       in
       let turnarounds = ref [] in
       let transaction ?(gap = 3) packets =
         List.iteri packets ~f:(fun n packet ->
           if n > 0 then cycles (4 * gap);
           send packet);
         Option.bind (listen ()) ~f:(fun (reply, at) ->
           turnarounds := at :: !turnarounds;
           reply)
       in
       let pending = Queue.create () in
       let board () =
         cycles board_latency;
         let words = pop () in
         List.iter words ~f:(fun word ->
           if word = 3 then Queue.dequeue pending |> Option.iter ~f:push);
         words
       in
       let log = Queue.create () in
       List.iter requests ~f:(fun (setup, payload) ->
         let reply =
           transaction
             [ Usb.token ~address ~pid:0x2d ~endpoint:0; Usb.data ~pid:data0 setup ]
         in
         let words = board () in
         Queue.enqueue
           log
           [%message "SETUP" (reply : Int.Hex.t list option) (words : Int.Hex.t list)];
         List.iter (chunks payload) ~f:(fun chunk ->
           Queue.enqueue
             pending
             [ Usb_fs.in_token ~address ~endpoint:0; Usb_fs.Layout.address layout chunk ]);
         Queue.dequeue pending |> Option.iter ~f:push;
         let rec ins naks =
           if naks < 2
           then (
             match transaction [ Usb.token ~address ~pid:0x69 ~endpoint:0 ] with
             | Some (pid :: _ as data) when pid = data0 || pid = data1 ->
               cycles 12;
               send [ ack ];
               cycles 40;
               let words = board () in
               Queue.enqueue
                 log
                 [%message "IN" (data : Int.Hex.t list) (words : Int.Hex.t list)];
               ins 0
             | Some [ pid ] when pid = nak ->
               let words = board () in
               Queue.enqueue log [%message "IN" "NAK" (words : Int.Hex.t list)];
               ins (naks + 1)
             | other -> Queue.enqueue log [%message "IN" (other : int list option)])
         in
         ins 0;
         (* an IN on endpoint 1, for which nothing is queued *)
         let reply = transaction [ Usb.token ~address ~pid:0x69 ~endpoint:1 ] in
         Queue.enqueue log [%message "IN 1" (reply : Int.Hex.t list option)];
         let reply =
           transaction
             [ Usb.token ~address ~pid:0xe1 ~endpoint:0; Usb.data ~pid:data1 [] ]
         in
         let words = board () in
         Queue.enqueue
           log
           [%message "OUT" (reply : Int.Hex.t list option) (words : Int.Hex.t list)]);
       Queue.iter log ~f:print_s;
       print_s
         [%message
           ""
             ~turnaround_bits:
               (List.dedup_and_sort !turnarounds ~compare
                |> List.map ~f:(fun c -> Float.of_int c /. 4.)
                : float list)
             ~lockstep_parts_at:(!mismatch : int option)
             ~faulted:(int e.faulted : int)
             ~halted:(int e.halted : int)])
  [@nontail]
;;

(* The device descriptor in three packets, then a string of 0xff bytes, whose packets the
   record stuffs most, each IN NAKed until the board has queued its packet, and an IN on
   endpoint 1 with nothing queued for it NAKed too. *)
let%expect_test "control reads on the chip, in lockstep with the model" =
  control_reads
    [ [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ], device_descriptor
    ; ( [ 0x80; 0x06; 0x02; 0x03; 0x09; 0x04; 0x0c; 0x00 ]
      , [ 12; 3; 0xff; 0xff; 0xff; 0xff; 0x7f; 0xfe; 0xff; 0xff; 0xff; 0x01 ] )
    ];
  [%expect
    {|
    (SETUP (reply ((0xd2))) (words (0x80c3 0x6 0x1 0x4000 0xdd00)))
    (IN NAK (words ()))
    (IN (data (0x4b 0x12 0x1 0x10 0x1 0x0 0x0 0x0 0x8 0x11 0x77)) (words (0x3)))
    (IN NAK (words ()))
    (IN (data (0xc3 0x9 0x12 0x2 0x0 0x0 0x1 0x0 0x0 0x1d 0xbd)) (words (0x3)))
    (IN NAK (words ()))
    (IN (data (0x4b 0x0 0x1 0x3f 0x8f)) (words (0x3)))
    (IN NAK (words ()))
    (IN NAK (words ()))
    ("IN 1" (reply ((0x5a))))
    (OUT (reply ((0xd2))) (words (0x2)))
    (SETUP (reply ((0xd2))) (words (0x80c3 0x206 0x903 0xc04 0xd300)))
    (IN NAK (words ()))
    (IN (data (0x4b 0xc 0x3 0xff 0xff 0xff 0xff 0x7f 0xfe 0x2d 0x2e))
     (words (0x3)))
    (IN NAK (words ()))
    (IN (data (0xc3 0xff 0xff 0xff 0x1 0x7f 0xcf)) (words (0x3)))
    (IN NAK (words ()))
    (IN NAK (words ()))
    ("IN 1" (reply ((0x5a))))
    (OUT (reply ((0xd2))) (words (0x2)))
    ((turnaround_bits (4)) (lockstep_parts_at ()) (faulted 0) (halted 0))
    |}]
;;

(* Without the re-arm the receiver takes the SETUP token and nothing after: the DATA0 is
   never ACKed, so a host gets no further. *)
let%expect_test "without the re-arm, the device answers nothing" =
  control_reads
    ~rearm:false
    [ [ 0x80; 0x06; 0x00; 0x01; 0x00; 0x00; 0x40; 0x00 ], List.take device_descriptor 8 ];
  [%expect
    {|
    (SETUP (reply ()) (words ()))
    (IN (other ()))
    ("IN 1" (reply ()))
    (OUT (reply ()) (words ()))
    ((turnaround_bits ()) (lockstep_parts_at ()) (faulted 0) (halted 0))
    |}]
;;
