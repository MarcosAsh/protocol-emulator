open! Core
open Protocol_emulator

let config random =
  let int hi = Splittable_random.int random ~lo:0 ~hi in
  let bool () = Splittable_random.bool random in
  let pin () = int (Isa.num_pins - 1) in
  let shift () : Program_config.Shift_direction.t = if bool () then Left else Right in
  { Program_config.side_set_count = int Isa.max_side_set
  ; side_set_base = pin ()
  ; side_set_pindirs = bool ()
  ; in_base = pin ()
  ; out_base = pin ()
  ; out_count = 1 + int 15
  ; set_base = pin ()
  ; set_count = 1 + int 4
  ; jmp_pin = pin ()
  ; capture_pin = pin ()
  ; capture_rising = bool ()
  ; in_shift = shift ()
  ; out_shift = shift ()
  ; autopush = bool ()
  ; push_threshold = 1 + int 15
  ; autopull = bool ()
  ; pull_threshold = 1 + int 15
  }
;;

let rec word ?(fifo_waits = true) random ~side_set_count =
  let w = Splittable_random.int random ~lo:0 ~hi:0xffff in
  match Isa.of_word ~side_set_count w with
  | Ok (Op { op = Sys Halt; _ }) | Error _ -> word ~fifo_waits random ~side_set_count
  | Ok (Op { op = Wait (Fifo _); _ }) when not fifo_waits ->
    word ~fifo_waits random ~side_set_count
  | Ok _ -> w
;;

let program ?fifo_waits random ~(config : Program_config.t) =
  List.init (1 lsl Isa.pc_bits) ~f:(fun _ ->
    word ?fifo_waits random ~side_set_count:config.side_set_count)
;;
