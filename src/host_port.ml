open! Core
open! Hardcaml
open! Signal

module Status = struct
  type 'a t =
    { pc : 'a [@bits Isa.pc_bits]
    ; now : 'a [@bits Isa.timer_bits]
    ; capture : 'a [@bits Isa.timer_bits]
    ; halted : 'a
    ; irq : 'a
    ; fault : 'a Engine.Fault.t
    ; tx_level : 'a [@bits Host_fifo.level_bits]
    ; rx_level : 'a [@bits Host_fifo.level_bits]
    ; rx_head : 'a [@bits Isa.data_bits]
    }
  [@@deriving hardcaml]
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; sck : 'a
    ; mosi : 'a
    ; cs_n : 'a
    ; status : 'a Status.t
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { miso : 'a
    ; start : 'a
    ; clear_irq : 'a
    ; program_write : 'a Engine.Program_write.t
    ; tx : 'a With_valid.t [@bits Isa.data_bits]
    ; rx_pop : 'a
    ; config : 'a Engine.Config.t
    }
  [@@deriving hardcaml]
end

module Reg = struct
  let control = 0x00
  let status = 0x01
  let pc = 0x02
  let now_lo = 0x03
  let now_hi = 0x04
  let capture_lo = 0x05
  let capture_hi = 0x06
  let tx = 0x07
  let rx = 0x08
  let program_addr = 0x09
  let program = 0x0a
  let config = 0x10
end

module State = struct
  type t =
    | Command
    | High
    | Low
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let s = i.status in
  let%hw.Always.State_machine sm = Always.State_machine.create (module State) spec in
  let%hw_var cmd = Always.Variable.reg spec ~width:8 in
  let%hw_var high = Always.Variable.reg spec ~width:8 in
  let%hw_var word = Always.Variable.reg spec ~width:Isa.data_bits in
  let%hw_var program_addr = Always.Variable.reg spec ~width:Isa.pc_bits in
  let%hw_var write = Always.Variable.wire ~default:gnd () in
  let%hw_var read_done = Always.Variable.wire ~default:gnd () in
  let config = Engine.Config.Of_always.reg spec in
  let config_value = Engine.Config.Of_always.value config in
  let%hw is_write = msb cmd.value in
  let%hw addr = cmd.value.:[6, 0] in
  let at n = addr ==:. n in
  let reg16 x = uresize x ~width:Isa.data_bits in
  let status_word =
    concat_msb
      [ zero 4
      ; s.rx_level
      ; s.tx_level
      ; s.fault.decode
      ; s.fault.missed_deadline
      ; s.fault.overflow
      ; s.fault.underflow
      ; s.irq
      ; s.halted
      ]
  in
  let config_words = Engine.Config.to_list config_value in
  let read_at addr =
    let key n = of_unsigned_int ~width:(width addr) n in
    List.map
      ~f:(fun (n, v) -> key n, v)
      ([ Reg.status, status_word
       ; Reg.pc, reg16 s.pc
       ; Reg.now_lo, sel_bottom s.now ~width:Isa.data_bits
       ; Reg.now_hi, reg16 (sel_top s.now ~width:(Isa.timer_bits - Isa.data_bits))
       ; Reg.capture_lo, sel_bottom s.capture ~width:Isa.data_bits
       ; Reg.capture_hi, reg16 (sel_top s.capture ~width:(Isa.timer_bits - Isa.data_bits))
       ; Reg.rx, s.rx_head
       ; Reg.program_addr, reg16 program_addr.value
       ]
       @ List.mapi config_words ~f:(fun n w -> Reg.config + n, reg16 w))
    |> cases ~default:(zero Isa.data_bits) addr
  in
  let%hw read_value = read_at addr in
  let%hw tx_word = mux2 (at Reg.rx) s.rx_head word.value in
  let spi =
    Host_spi.hierarchical
      scope
      { clocking = i.clocking
      ; sck = i.sck
      ; mosi = i.mosi
      ; cs_n = i.cs_n
      ; tx_byte = mux2 (sm.is Low) tx_word.:[7, 0] tx_word.:[15, 8]
      }
  in
  (* The register named by the command byte is read while that byte is still arriving. *)
  let%hw first_read = read_at spi.rx_byte.:[6, 0] in
  let%hw value = high.value @: spi.rx_byte in
  let config_writes =
    List.mapi
      (Engine.Config.to_list
         (Engine.Config.map2 Engine.Config.port_widths config ~f:(fun w v -> w, v)))
      ~f:(fun n (width, v) ->
        Always.(when_ (at (Reg.config + n)) [ v <-- sel_bottom value ~width ]))
  in
  Always.(
    compile
      [ when_ spi.frame_start [ sm.set_next Command ]
      ; when_
          spi.rx_valid
          [ sm.switch
              [ Command, [ cmd <-- spi.rx_byte; word <-- first_read; sm.set_next High ]
              ; High, [ high <-- spi.rx_byte; sm.set_next Low ]
              ; ( Low
                , [ if_ is_write [ write <-- vdd ] [ read_done <-- vdd ]
                  ; sm.set_next High
                  ] )
              ]
          ]
      ; when_ read_done.value [ word <-- read_value ]
      ; when_
          write.value
          ([ when_
               (at Reg.program_addr)
               [ program_addr <-- sel_bottom value ~width:Isa.pc_bits ]
           ; when_ (at Reg.program) [ program_addr <-- program_addr.value +:. 1 ]
           ]
           @ config_writes)
      ]);
  let strobe n = write.value &: at n in
  { O.miso = spi.miso
  ; start = strobe Reg.control &: value.:(0)
  ; clear_irq = strobe Reg.control &: value.:(1)
  ; program_write =
      { valid = strobe Reg.program; addr = program_addr.value; data = value }
  ; tx = { valid = strobe Reg.tx; value }
  ; rx_pop = read_done.value &: at Reg.rx
  ; config = config_value
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"host_port" create i
;;
