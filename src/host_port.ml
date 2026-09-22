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
    ; x : 'a [@bits Isa.data_bits]
    ; y : 'a [@bits Isa.data_bits]
    ; p : 'a [@bits Isa.data_bits]
    ; t : 'a [@bits Isa.timer_bits]
    ; isr : 'a [@bits Isa.data_bits]
    ; osr : 'a [@bits Isa.data_bits]
    ; isr_count : 'a [@bits Isa.count_bits]
    ; osr_count : 'a [@bits Isa.count_bits]
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
  let select = 0x0b
  let data_addr = 0x0c
  let data = 0x0d
  let config = 0x10
  let x = 0x40
  let y = 0x41
  let p = 0x42
  let t_lo = 0x43
  let t_hi = 0x44
  let isr = 0x45
  let osr = 0x46
  let counts = 0x47
end

module State = struct
  type t =
    | Command
    | High
    | Low
  [@@deriving sexp_of, compare ~localize, enumerate]

  let names =
    List.map all ~f:(function
      | Command -> "C"
      | High -> "H"
      | Low -> "L")
  ;;
end

module type Config = sig
  val engines : int
end

module Make (Config : Config) = struct
  let engines = Config.engines
  let select_bits = Int.ceil_log2 engines

  let () =
    if engines < 1
    then raise_s [%message "BUG: there has to be an engine" (engines : int)]
  ;;

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; sck : 'a
      ; mosi : 'a
      ; cs_n : 'a
      ; status : 'a Status.t list [@length engines]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { miso : 'a
      ; engines : 'a Engine.Host.t list [@length engines]
      }
    [@@deriving hardcaml]
  end

  let create (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    (* one engine needs no select, and the chip with one stays as it was *)
    let select =
      Option.some_if
        (engines > 1)
        (Always.Variable.reg spec ~width:(Int.max 1 select_bits))
    in
    let select_value =
      Option.map select ~f:(fun select ->
        let%hw select = select.value in
        select)
    in
    let mine n x =
      match select_value with
      | None -> x
      | Some select -> x &: (select ==:. n)
    in
    let configs = List.init engines ~f:(fun _ -> Engine.Config.Of_always.reg spec) in
    let config_values = List.map configs ~f:Engine.Config.Of_always.value in
    let other_irqs =
      List.mapi i.status ~f:(fun n _ ->
        List.filteri i.status ~f:(fun m _ -> m <> n)
        |> List.fold ~init:gnd ~f:(fun irq (s : _ Status.t) -> irq |: s.irq))
    in
    let s, config_value, other_irq =
      match select_value with
      | None -> List.hd_exn i.status, List.hd_exn config_values, List.hd_exn other_irqs
      | Some select ->
        (* a select past the last engine reads zeros rather than the last engine again *)
        let spare = (1 lsl select_bits) - engines in
        let pad values ~zero = values @ List.init spare ~f:(fun _ -> zero) in
        ( Status.Of_signal.mux
            select
            (pad i.status ~zero:(Status.map Status.port_widths ~f:zero))
        , Engine.Config.Of_signal.mux
            select
            (pad
               config_values
               ~zero:(Engine.Config.map Engine.Config.port_widths ~f:zero))
        , mux select (pad other_irqs ~zero:gnd) )
    in
    let%hw.Always.State_machine sm = Always.State_machine.create (module State) spec in
    let%hw_var cmd = Always.Variable.reg spec ~width:8 in
    let%hw_var high = Always.Variable.reg spec ~width:8 in
    let%hw_var word = Always.Variable.reg spec ~width:Isa.data_bits in
    let%hw_var program_addr = Always.Variable.reg spec ~width:Isa.pc_bits in
    let%hw_var data_addr = Always.Variable.reg spec ~width:Isa.data_addr_bits in
    let%hw_var write = Always.Variable.wire ~default:gnd () in
    let%hw_var read_done = Always.Variable.wire ~default:gnd () in
    let%hw is_write = msb cmd.value in
    let%hw addr = cmd.value.:[6, 0] in
    let at n = addr ==:. n in
    let reg16 x = uresize x ~width:Isa.data_bits in
    let status_word =
      concat_msb
        [ other_irq
        ; zero (Isa.data_bits - 7 - (2 * Host_fifo.level_bits))
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
         ; ( Reg.capture_hi
           , reg16 (sel_top s.capture ~width:(Isa.timer_bits - Isa.data_bits)) )
         ; Reg.rx, s.rx_head
         ; Reg.program_addr, reg16 program_addr.value
         ; Reg.data_addr, reg16 data_addr.value
         ; Reg.x, s.x
         ; Reg.y, s.y
         ; Reg.p, s.p
         ; Reg.t_lo, sel_bottom s.t ~width:Isa.data_bits
         ; Reg.t_hi, reg16 (sel_top s.t ~width:(Isa.timer_bits - Isa.data_bits))
         ; Reg.isr, s.isr
         ; Reg.osr, s.osr
         ; Reg.counts, reg16 (s.osr_count @: zero 3 @: s.isr_count)
         ]
         @ (Option.map select_value ~f:(fun select -> Reg.select, reg16 select)
            |> Option.to_list)
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
    (* a running engine keeps the configuration its program was loaded and checked with *)
    let config_writes =
      List.concat_mapi
        (List.zip_exn configs i.status)
        ~f:(fun engine (config, (status : _ Status.t)) ->
          List.mapi
            (Engine.Config.to_list
               (Engine.Config.map2 Engine.Config.port_widths config ~f:(fun w v -> w, v)))
            ~f:(fun n (width, v) ->
              Always.(
                when_
                  (mine engine (at (Reg.config + n)) &: status.halted)
                  [ v <-- sel_bottom value ~width ])))
    in
    let select_write =
      Option.map select ~f:(fun select ->
        Always.(when_ (at Reg.select) [ select <-- sel_bottom value ~width:select_bits ]))
      |> Option.to_list
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
             ; when_
                 (at Reg.data_addr)
                 [ data_addr <-- sel_bottom value ~width:Isa.data_addr_bits ]
             ; when_ (at Reg.data) [ data_addr <-- data_addr.value +:. 1 ]
             ]
             @ select_write
             @ config_writes)
        ]);
    let strobe n = write.value &: at n in
    { O.miso = spi.miso
    ; engines =
        List.mapi config_values ~f:(fun n config ->
          let mine = mine n in
          { Engine.Host.config
          ; start = mine (strobe Reg.control &: value.:(0))
          ; clear_irq = mine (strobe Reg.control &: value.:(1))
          ; stop = mine (strobe Reg.control &: value.:(2))
          ; flush = mine (strobe Reg.control &: value.:(3))
          ; resume = mine (strobe Reg.control &: value.:(4))
          ; single_step = mine (strobe Reg.control &: value.:(5))
          ; data_write =
              { valid = mine (strobe Reg.data); addr = data_addr.value; data = value }
          ; program_write =
              { valid = mine (strobe Reg.program)
              ; addr = program_addr.value
              ; data = value
              }
          ; tx = { valid = mine (strobe Reg.tx); value }
          ; rx_pop = mine (read_done.value &: at Reg.rx)
          })
    }
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"host_port" create i
  ;;
end
