open! Core
open Protocol_emulator
open Firmware
open Pin_trace
module Reg = Host_port.Reg

let wrapped_loop =
  let program =
    assemble
      {|
    set p, 2
    mov t, now
    add t, p
.wrap_target
    wait t+
    mov pins, !pins
.wrap
|}
  in
  { Scenario.name = "wrapped_loop"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load
        ~config:{ Program_config.default with in_base = 5; wrap_bottom = 3; wrap_top = 4 }
        ~program
      @ [ Scenario.start; Run 60; Read (Reg.status, 1) ]
  ; sigrok = None
  }
;;

let fifo_poll =
  let program = assemble (List.hd_exn Fifo_poll.programs) in
  let traffic words =
    List.concat_map words ~f:(fun word ->
      [ Step.Write (Reg.tx, [ word ]); Run (word land 7); Read (Reg.status, 1) ])
  in
  { Scenario.name = "fifo_poll"
  ; peer = (fun () -> Peer.idle 0)
  ; script =
      Scenario.load ~config:{ Program_config.default with in_base = 5 } ~program
      @ [ Scenario.start ]
      @ traffic [ 0x1234; 0xbeef; 0x0001 ]
      @ [ Step.Read (Reg.rx, 2) ]
      @ traffic [ 0xffff; 0x8000; 0x7a5c; 0x0ff0 ]
      @ [ Read (Reg.rx, 3); Write (Reg.tx, [ 1; 2 ]); Read (Reg.rx, 2); Read (Reg.pc, 1) ]
  ; sigrok = None
  }
;;

let all = Library.scenarios @ [ wrapped_loop; fifo_poll ]
