(** The kernel's check of a row and the core's place inside one, which [Kernel] documents,
    with the step it builds on. *)

open! Core
open! Hardcaml
open Kernel_types

module Make_timer (Timer : Engine.Timer) : sig
  open Kernel_types.Make_timer(Timer)

  module Make (Comb : Comb.S) : sig
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

    val conjuncts
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t Loaded.t
      -> capture:Comb.t Capture.t
      -> spacing:Comb.t Spaced.t
      -> word:Comb.t
      -> row:Comb.t Row.t
      -> next:Comb.t Row.t
      -> target:Comb.t Row.t
      -> Comb.t Conjuncts.t

    val accepts
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t Loaded.t
      -> capture:Comb.t Capture.t
      -> spacing:Comb.t Spaced.t
      -> word:Comb.t
      -> row:Comb.t Row.t
      -> next:Comb.t Row.t
      -> target:Comb.t Row.t
      -> Comb.t

    (** The tightest row [conjuncts] lets the next pc's be on the way of falling through,
        with no spacing and the offset left full, and whether that way is asked: where it
        is not, any row holds. [test/test_kernel.ml] proves it field by field. *)
    val fall_through
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t Loaded.t
      -> capture:Comb.t Capture.t
      -> word:Comb.t
      -> row:Comb.t Row.t
      -> Comb.t Row.t * Comb.t

    (** [conjuncts] with no spacing on one way out against [s], the jump's where [taken]
        is high and falling through where it is low, the other way's holding; where
        [taken] is low, [fall_through] too. A way's image is then computed once, for the
        load checker, which checks one way at a time and registers the word's classes with
        [stage]. [test/test_kernel.ml] proves it theirs. *)
    val one_way
      :  ?stage:(Comb.t -> Comb.t)
      -> side_set_count:Comb.t
      -> fraction:Comb.t
      -> loaded:Comb.t Loaded.t
      -> capture:Comb.t Capture.t
      -> word:Comb.t
      -> row:Comb.t Row.t
      -> taken:Comb.t
      -> Comb.t Row.t
      -> Comb.t Conjuncts.t * Comb.t Row.t * Comb.t

    val no_spacing : Comb.t Spaced.t
    val starting : level:Comb.t -> Comb.t Edge.t
    val following : wrap_top:Comb.t -> wrap_bottom:Comb.t -> Comb.t -> Comb.t
    val is_full : Comb.t Row.t -> Comb.t
    val offset_is_full : Comb.t Row.t -> Comb.t
    val arm_is_full : Comb.t Row.t -> Comb.t

    val successors
      :  wrap_top:Comb.t
      -> wrap_bottom:Comb.t
      -> pc:Comb.t
      -> word:Comb.t
      -> Comb.t * Comb.t

    val within
      :  Comb.t Row.t
      -> spacing:Comb.t Spaced.t
      -> phase:Comb.t
      -> offset:Comb.t
      -> period:Comb.t
      -> x:Comb.t
      -> y:Comb.t
      -> arm:Comb.t
      -> arm_known:Comb.t
      -> captured:Comb.t
      -> awaiting:Comb.t
      -> a:Comb.t Edge.t
      -> b:Comb.t Edge.t
      -> Comb.t Holds.t

    val starts_open : Comb.t Row.t -> spacing:Comb.t Spaced.t -> Comb.t

    (** The row bounds no core, as at a pc never reached. *)
    val is_empty : Comb.t Row.t -> Comb.t

    val since_limit : Comb.t

    (** A mark that bounds nothing, and the most a mark can bound. *)
    val mark_none : Comb.t

    val mark_max : Comb.t

    (** The pair's bounds after the word, as [conjuncts] makes them, for
        [Kernel_table.with_edges]. *)
    val edge_images
      :  side_set_count:Comb.t
      -> fraction:Comb.t
      -> capture:Comb.t Capture.t
      -> spacing:Comb.t Spaced.t
      -> word:Comb.t
      -> row:Comb.t Row.t
      -> Comb.t Pin.t * Comb.t Pin.t
  end

  module Accepts : sig
    module I : sig
      type 'a t =
        { side_set_count : 'a
        ; fraction : 'a
        ; loaded : 'a Loaded.t
        ; capture : 'a Capture.t
        ; spacing : 'a Spaced.t
        ; wrap_top : 'a
        ; wrap_bottom : 'a
        ; pc : 'a
        ; word : 'a
        ; row : 'a
        ; next : 'a
        ; target : 'a
        ; phase : 'a
        ; offset : 'a
        ; period : 'a
        ; x : 'a
        ; y : 'a
        ; arm : 'a
        ; arm_known : 'a
        ; captured : 'a
        ; awaiting : 'a
        ; a : 'a Edge.t
        ; b : 'a Edge.t
        }
      [@@deriving hardcaml]
    end

    module O : sig
      type 'a t =
        { next_pc : 'a
        ; target_pc : 'a
        ; accepts : 'a
        ; within : 'a
        ; starts_open : 'a
        }
      [@@deriving hardcaml]
    end

    val hierarchical : ?instance:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
  end
end
