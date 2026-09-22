open! Core
open Protocol_emulator
module Reg = Host_port.Reg

module Event = struct
  type t =
    | Start
    | Clear_irq
    | Stop
    | Flush
    | Resume
    | Single_step
    | Program_write of
        { addr : int
        ; data : int
        }
    | Data_write of
        { addr : int
        ; data : int
        }
    | Tx of int
    | Rx_pop
  [@@deriving sexp_of, equal]
end

type t =
  { engines : int
  ; select : int
  ; program_addr : int
  ; data_addr : int
  ; configs : int list list
  }
[@@deriving sexp_of]

let config_widths = Engine.Config.to_list Engine.Config.port_widths

let create ?(engines = 1) () =
  { engines
  ; select = 0
  ; program_addr = 0
  ; data_addr = 0
  ; configs = List.init engines ~f:(fun _ -> List.map config_widths ~f:(fun _ -> 0))
  }
;;

let configs t = t.configs
let mask width = (1 lsl width) - 1

(* strobes and config writes reach the selected engine, or none past the last *)
let reached t events =
  if t.select < t.engines then List.map events ~f:(fun e -> t.select, e) else []
;;

let write t ~(statuses : int Host_port.Status.t list) ~reg value =
  let index = reg - Reg.config in
  if reg = Reg.control
  then
    ( t
    , List.filter_opt
        [ Option.some_if (value land 1 = 1) Event.Start
        ; Option.some_if (value land 2 = 2) Event.Clear_irq
        ; Option.some_if (value land 4 = 4) Event.Stop
        ; Option.some_if (value land 8 = 8) Event.Flush
        ; Option.some_if (value land 16 = 16) Event.Resume
        ; Option.some_if (value land 32 = 32) Event.Single_step
        ]
      |> reached t )
  else if reg = Reg.tx
  then t, reached t [ Event.Tx value ]
  else if reg = Reg.program_addr
  then { t with program_addr = value land mask Isa.pc_bits }, []
  else if reg = Reg.program
  then
    ( { t with program_addr = (t.program_addr + 1) land mask Isa.pc_bits }
    , reached t [ Event.Program_write { addr = t.program_addr; data = value } ] )
  else if reg = Reg.data_addr
  then { t with data_addr = value land mask Isa.data_addr_bits }, []
  else if reg = Reg.data
  then
    ( { t with data_addr = (t.data_addr + 1) land mask Isa.data_addr_bits }
    , reached t [ Event.Data_write { addr = t.data_addr; data = value } ] )
  else if reg = Reg.select && t.engines > 1
  then { t with select = value land mask (Int.ceil_log2 t.engines) }, []
  else if index >= 0 && index < List.length config_widths
  then (
    (* a running engine keeps its configuration *)
    let halted engine = (List.nth_exn statuses engine).halted = 1 in
    let configs =
      List.mapi t.configs ~f:(fun engine config ->
        List.mapi config ~f:(fun n old ->
          if engine = t.select && n = index && halted engine
          then value land mask (List.nth_exn config_widths n)
          else old))
    in
    { t with configs }, [])
  else t, []
;;

let status_word (s : int Host_port.Status.t) ~other_irq =
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
    ~init:(Bool.to_int other_irq lsl (Isa.data_bits - 1))
    ~f:(fun bit word flag -> word lor (flag lsl bit))
;;

let read t ~(statuses : int Host_port.Status.t list) ~reg =
  let index = reg - Reg.config in
  let low x = x land mask Isa.data_bits in
  let high x = x lsr Isa.data_bits in
  let engine = t.select in
  let status =
    List.nth statuses engine
    |> Option.value
         ~default:(Host_port.Status.map Host_port.Status.port_widths ~f:(Fn.const 0))
  in
  if reg = Reg.program_addr
  then t.program_addr, []
  else if reg = Reg.data_addr
  then t.data_addr, []
  else if reg = Reg.select && t.engines > 1
  then t.select, []
  else if engine >= t.engines
  then 0, []
  else if reg = Reg.status
  then (
    let other_irq =
      List.existsi statuses ~f:(fun n (s : _ Host_port.Status.t) ->
        n <> engine && s.irq = 1)
    in
    status_word status ~other_irq, [])
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
  then status.rx_head, reached t [ Event.Rx_pop ]
  else if reg = Reg.x
  then status.x, []
  else if reg = Reg.y
  then status.y, []
  else if reg = Reg.p
  then status.p, []
  else if reg = Reg.t_lo
  then low status.t, []
  else if reg = Reg.t_hi
  then high status.t, []
  else if reg = Reg.isr
  then status.isr, []
  else if reg = Reg.osr
  then status.osr, []
  else if reg = Reg.counts
  then (status.osr_count lsl 8) lor status.isr_count, []
  else if index >= 0 && index < List.length config_widths
  then List.nth_exn (List.nth_exn t.configs engine) index, []
  else 0, []
;;
