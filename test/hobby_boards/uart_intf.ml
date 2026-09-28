open! Base
open! Hardcaml
open Uart_types

module type Config = sig
  type 'a t =
    { data_bits : 'a Data_bits.Enum.t
    ; parity : 'a Parity.Enum.t
    ; stop_bits : 'a Stop_bits.Enum.t
    ; clocks_per_bit : 'a
    }
  [@@deriving hardcaml]
end

module type Uart = sig
  module Config : Config

  module Tx : sig
    module I : sig
      type 'a t =
        { clocking : 'a Clocking.t
        ; config : 'a Config.t
        ; data_in : 'a
        ; data_in_valid : 'a
        }
      [@@deriving hardcaml]
    end

    module O : sig
      type 'a t =
        { txd : 'a
        ; data_in_ready : 'a
        }
      [@@deriving hardcaml]
    end

    val create : Scope.t -> Interface.Create_fn(I)(O).t
    val hierarchical : ?instance:string -> Scope.t -> Interface.Create_fn(I)(O).t
  end

  module Rx : sig
    module I : sig
      type 'a t =
        { clocking : 'a Clocking.t
        ; enable : 'a
        ; config : 'a Config.t
        ; rxd : 'a
        }
      [@@deriving hardcaml]
    end

    module O : sig
      type 'a t =
        { data_out : 'a
        ; data_out_valid : 'a
        ; error : 'a
        }
      [@@deriving hardcaml]
    end

    val create_internal
      :  ?align_rxdata_to_lsb:bool
      -> Scope.t
      -> Interface.Create_fn(I)(O).t

    val create : ?align_rxdata_to_lsb:bool -> Scope.t -> Interface.Create_fn(I)(O).t

    val hierarchical
      :  ?instance:string
      -> ?align_rxdata_to_lsb:bool
      -> Scope.t
      -> Interface.Create_fn(I)(O).t
  end
end
