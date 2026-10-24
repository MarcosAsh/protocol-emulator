(** The core's step through one instruction, which [Kernel] documents, and what it reads
    of a word, which [Kernel_accepts] reads too. *)

open! Core
open! Hardcaml
open Kernel_types

module Make_timer (Timer : Engine.Timer) : sig
  open Kernel_types.Make_timer(Timer)

  module Make (Comb : Comb.S) : sig
    (** The classes of word the analyser's transfer function tells apart. *)
    module Class : sig
      type t =
        { cycles : Comb.t
        ; deadline : Comb.t
        ; advance : Comb.t
        ; anchor : Comb.t
        ; add_imm : Comb.t
        ; add_p : Comb.t
        ; add_x : Comb.t
        ; add_y : Comb.t
        ; sub_imm : Comb.t
        ; imm : Comb.t
        ; bounded : Comb.t
        ; jump : Comb.t
        ; always : Comb.t
        ; x_dec : Comb.t
        ; y_dec : Comb.t
        ; x_ne_y : Comb.t
        ; halts : Comb.t
        ; set_value : Comb.t
        ; set_p : Comb.t
        ; writes_p : Comb.t
        ; set_x : Comb.t
        ; writes_x : Comb.t
        ; set_y : Comb.t
        ; writes_y : Comb.t
        ; arm : Comb.t
        ; capturing : Comb.t
        ; pin_or_fifo_wait : Comb.t
        ; from_capture : Comb.t
        ; decoded : Comb.t Decoder.Decoded.t
        }

      val of_word : side_set_count:Comb.t -> capture:Comb.t Capture.t -> Comb.t -> t
      val map : t -> f:(Comb.t -> Comb.t) -> t
    end

    (** What the word does to the watched bit of [pin]. *)
    module Watched : sig
      type t =
        { written : Comb.t
        ; bit : Comb.t
        ; data : Comb.t
        }

      val of_word
        :  side_set_count:Comb.t
        -> spacing:Comb.t Spacing.t
        -> Comb.t Decoder.Decoded.t
        -> pin:Comb.t
        -> t
    end

    (** A count of cycles that has saturated, all ones. *)
    val since_limit : Comb.t

    (** A count of cycles, [Isa.data_bits] wide, at most [since_limit]. *)
    val saturate : Comb.t -> Comb.t

    (** Past this, a count of cycles since the arm is taken as lost, so it never wraps. *)
    val arm_limit : int

    val step
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t Loaded.t
      -> capture:Comb.t Capture.t
      -> spacing:Comb.t Spaced.t
      -> word:Comb.t
      -> phase:Comb.t
      -> period:Comb.t
      -> x:Comb.t
      -> y:Comb.t
      -> arm:Comb.t
      -> arm_known:Comb.t
      -> captured:Comb.t
      -> awaiting:Comb.t
      -> a:Comb.t Edge.t
      -> b:Comb.t Edge.t
      -> data_a:Comb.t
      -> data_b:Comb.t
      -> Comb.t Step.t
  end

  module I : sig
    type 'a t =
      { side_set_count : 'a
      ; fraction : 'a
      ; loaded : 'a Loaded.t
      ; capture : 'a Capture.t
      ; spacing : 'a Spaced.t
      ; word : 'a
      ; phase : 'a
      ; period : 'a
      ; x : 'a
      ; y : 'a
      ; arm : 'a
      ; arm_known : 'a
      ; captured : 'a
      ; awaiting : 'a
      ; a : 'a Edge.t
      ; b : 'a Edge.t
      ; data_a : 'a
      ; data_b : 'a
      }
    [@@deriving hardcaml]
  end

  val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t Step.t
end
