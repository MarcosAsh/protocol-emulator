open! Core
open! Hardcaml
open! Signal

let input_pins = Isa.first_output_pin
let pad_bits = input_pins + (Isa.num_pins - Isa.first_bidir_pin)
let ring_bits = Isa.data_addr_bits - 1
let words = 1 lsl ring_bits
let base = words
let delta_bits = Isa.data_bits
let code_bits = Isa.data_bits - pad_bits

module Code = struct
  type t =
    | Pads
    | Control
    | Tx
    | Rx_pop
    | Arm
    | Disarm
    | Fault
    | Lost
  [@@deriving sexp_of, compare ~localize, equal, enumerate]

  let to_int t = Option.value_exn (List.findi all ~f:(fun _ c -> equal c t)) |> fst
  let of_int n = List.nth_exn all n

  let is_end = function
    | Disarm | Fault | Lost -> true
    | Pads | Control | Tx | Rx_pop | Arm -> false
  ;;
end

let () =
  if code_bits < Int.ceil_log2 (List.length Code.all)
  then raise_s [%message "BUG: the pads leave no room for the code" (pad_bits : int)]
;;

let pads_of_pins pins =
  pins
  land ((1 lsl input_pins) - 1)
  lor ((pins lsr Isa.first_bidir_pin) lsl input_pins)
  land ((1 lsl pad_bits) - 1)
;;

module Entry = struct
  type t =
    { code : Code.t
    ; pads : int
    ; delta : int
    }
  [@@deriving sexp_of, compare, equal]

  let of_words event delta =
    { code = Code.of_int (event land ((1 lsl code_bits) - 1))
    ; pads = event lsr code_bits
    ; delta
    }
  ;;
end

module Log = struct
  type t =
    { from_arm : bool
    ; entries : Entry.t list
    }
  [@@deriving sexp_of]
end

let decode ring =
  let open Or_error.Let_syntax in
  let%bind () =
    if List.length ring = words
    then Ok ()
    else Or_error.error_s [%message "a ring is its words" (words : int)]
  in
  let pairs =
    List.chunks_of ring ~length:2
    |> List.map ~f:(function
      | [ event; delta ] -> Entry.of_words event delta
      | _ -> assert false)
    |> Array.of_list
  in
  let n = Array.length pairs in
  let from_arm = [%equal: Code.t] pairs.(0).code Arm in
  (* unwrapped, stale entries of an earlier run may follow this run's end *)
  let%bind last =
    List.range 0 n
    |> List.find ~f:(fun k -> Code.is_end pairs.(k).code)
    |> Result.of_option ~error:(Error.of_string "the journal has not ended")
  in
  Ok
    (if from_arm
     then { Log.from_arm; entries = List.init (last + 1) ~f:(fun k -> pairs.(k)) }
     else { from_arm; entries = List.init n ~f:(fun k -> pairs.((last + 1 + k) % n)) })
;;

module Arm = struct
  type 'a t =
    { valid : 'a
    ; on : 'a
    }
  [@@deriving hardcaml]
end

module I = struct
  type 'a t =
    { clocking : 'a Clocking.t
    ; arm : 'a Arm.t
    ; pads : 'a [@bits pad_bits]
    ; command : 'a [@bits 2]
    ; fault : 'a
    ; slot : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { write : 'a Engine.Program_write.t } [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Clocking.to_spec i.clocking in
  let code c = of_unsigned_int ~width:code_bits (Code.to_int c) in
  let entry_bits = pad_bits + code_bits + delta_bits in
  let%hw arm = i.arm.valid &: i.arm.on in
  let%hw disarm = i.arm.valid &: ~:(i.arm.on) in
  let%hw last_pads = reg spec i.pads in
  let%hw fault_rose = i.fault &: ~:(reg spec i.fault) in
  let%hw recording = wire 1 in
  let%hw ending = wire 1 in
  let%hw end_code = wire code_bits in
  let%hw age = wire delta_bits in
  let%hw ptr = wire ring_bits in
  let%hw second = wire 1 in
  let%hw head = wire entry_bits in
  let%hw head_valid = wire 1 in
  let%hw tail = wire entry_bits in
  let%hw tail_valid = wire 1 in
  (* a two-entry queue: the head goes to the ring a word per slot, event word first *)
  let%hw wrote = head_valid &: i.slot in
  let%hw pop = wrote &: second in
  let%hw kept_valid = mux2 pop tail_valid head_valid in
  let%hw kept = mux2 pop tail head in
  let%hw full = tail_valid &: ~:pop in
  let%hw open_ = recording &: ~:ending in
  let%hw event =
    open_ &: ((i.pads <>: last_pads) |: (i.command <>:. 0) |: (age ==: ones delta_bits))
  in
  let%hw stops = open_ &: (disarm |: fault_rose |: (event &: full)) in
  let%hw stop_code =
    mux2 disarm (code Disarm) @@ mux2 fault_rose (code Fault) @@ code Lost
  in
  let%hw closing = stops |: ending in
  let%hw marks = closing &: ~:full in
  let%hw logs = event &: ~:full &: ~:stops in
  let%hw pushes = marks |: logs in
  let%hw entry_code =
    mux2 closing (mux2 ending end_code stop_code) (uresize i.command ~width:code_bits)
  in
  let%hw entry = concat_msb [ i.pads; entry_code; age ] in
  let%hw armed = concat_msb [ i.pads; code Arm; zero delta_bits ] in
  let on_arm ~armed x = mux2 arm armed x in
  recording <-- reg spec (on_arm ~armed:vdd (recording &: ~:marks));
  ending <-- reg spec (on_arm ~armed:gnd (closing &: ~:marks));
  end_code <-- reg spec ~enable:stops stop_code;
  age
  <-- reg
        spec
        (on_arm ~armed:(one delta_bits)
         @@ mux2 logs (one delta_bits)
         @@ mux2 closing age (age +:. 1));
  ptr
  <-- reg spec (on_arm ~armed:(zero ring_bits) (ptr +: uresize wrote ~width:ring_bits));
  second <-- reg spec (on_arm ~armed:gnd (mux2 pop gnd (second |: wrote)));
  head <-- reg spec (on_arm ~armed (mux2 kept_valid kept entry));
  head_valid <-- reg spec (on_arm ~armed:vdd (kept_valid |: pushes));
  tail <-- reg spec ~enable:(kept_valid &: pushes) entry;
  tail_valid
  <-- reg spec (on_arm ~armed:gnd ((tail_valid &: ~:pop) |: (kept_valid &: pushes)));
  { O.write =
      { valid = wrote
      ; addr = vdd @: ptr
      ; data =
          mux2
            second
            (sel_bottom head ~width:delta_bits)
            (sel_top head ~width:(pad_bits + code_bits))
      }
  }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"journal" create i
;;
