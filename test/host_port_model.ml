open! Core
open Protocol_emulator
module Reg = Host_port.Reg

module Event = struct
  type t =
    | Start
    | Clear_irq
    | Stop
    | Flush
    | Program_write of
        { addr : int
        ; data : int
        }
    | Tx of int
    | Rx_pop
  [@@deriving sexp_of, equal]
end

type t =
  { program_addr : int
  ; config : int list
  }
[@@deriving sexp_of]

let config_widths = Engine.Config.to_list Engine.Config.port_widths
let create () = { program_addr = 0; config = List.map config_widths ~f:(fun _ -> 0) }
let config t = t.config
let mask width = (1 lsl width) - 1

let write t ~reg value =
  let index = reg - Reg.config in
  if reg = Reg.control
  then
    ( t
    , List.filter_opt
        [ Option.some_if (value land 1 = 1) Event.Start
        ; Option.some_if (value land 2 = 2) Event.Clear_irq
        ; Option.some_if (value land 4 = 4) Event.Stop
        ; Option.some_if (value land 8 = 8) Event.Flush
        ] )
  else if reg = Reg.tx
  then t, [ Tx value ]
  else if reg = Reg.program_addr
  then { t with program_addr = value land mask Isa.pc_bits }, []
  else if reg = Reg.program
  then
    ( { t with program_addr = (t.program_addr + 1) land mask Isa.pc_bits }
    , [ Program_write { addr = t.program_addr; data = value } ] )
  else if index >= 0 && index < List.length config_widths
  then (
    let config =
      List.mapi t.config ~f:(fun n old ->
        if n = index then value land mask (List.nth_exn config_widths n) else old)
    in
    { t with config }, [])
  else t, []
;;

let status_word (s : int Host_port.Status.t) =
  let levels = (s.rx_level lsl Host_fifo.level_bits) lor s.tx_level in
  List.foldi
    [ s.halted
    ; s.irq
    ; s.fault.underflow
    ; s.fault.overflow
    ; s.fault.missed_deadline
    ; s.fault.decode
    ; levels
    ]
    ~init:0
    ~f:(fun bit word flag -> word lor (flag lsl bit))
;;

let read t ~(status : int Host_port.Status.t) ~reg =
  let index = reg - Reg.config in
  let low x = x land mask Isa.data_bits in
  let high x = x lsr Isa.data_bits in
  if reg = Reg.status
  then status_word status, []
  else if reg = Reg.pc
  then status.pc, []
  else if reg = Reg.now_lo
  then low status.now, []
  else if reg = Reg.now_hi
  then high status.now, []
  else if reg = Reg.capture_lo
  then low status.capture, []
  else if reg = Reg.capture_hi
  then high status.capture, []
  else if reg = Reg.rx
  then status.rx_head, [ Event.Rx_pop ]
  else if reg = Reg.program_addr
  then t.program_addr, []
  else if index >= 0 && index < List.length config_widths
  then List.nth_exn t.config index, []
  else 0, []
;;
