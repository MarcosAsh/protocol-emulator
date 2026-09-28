open! Core
open! Hardcaml
open! Signal
open Hardcaml_hobby_boards

module type Config = sig
  val clocks_per_bit : int
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; data_in : 'a [@bits 9]
    ; data_in_valid : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { txd : 'a
    ; data_in_ready : 'a
    }
  [@@deriving hardcaml]
end

module Pin = struct
  type 'a t = { txd : 'a } [@@deriving hardcaml]
end

module Make (Config : Config) = struct
  let create scope (i : _ I.t) =
    let config =
      { Uart.Config.data_bits = Uart_types.Data_bits.Enum.Of_signal.of_enum Eight
      ; parity = Uart_types.Parity.Enum.Of_signal.of_enum None
      ; stop_bits = Uart_types.Stop_bits.Enum.Of_signal.of_enum One
      ; clocks_per_bit =
          of_unsigned_int
            ~width:Uart.Config.port_widths.clocks_per_bit
            Config.clocks_per_bit
      }
    in
    let o =
      Uart.Tx.hierarchical
        scope
        { clocking = i.clocking
        ; config
        ; data_in = i.data_in
        ; data_in_valid = i.data_in_valid
        }
    in
    { O.txd = o.txd; data_in_ready = o.data_in_ready }
  ;;

  let hierarchical ?instance scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"hobby_uart_tx" create i
  ;;

  let pin ?instance scope i = { Pin.txd = (hierarchical ?instance scope i).txd }
end
