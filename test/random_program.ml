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
  ; in_count = 1 + int 15
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
  ; crc_width = 1 + int 15
  ; crc_poly = int 0xffff
  ; crc_init = int 0xffff
  ; crc_reflect = bool ()
  ; stuff_threshold = int 31
  ; stuff_level = bool ()
  ; wrap_bottom = Program_config.default.wrap_bottom
  ; wrap_top = Program_config.default.wrap_top
  }
;;

let rec word ?(waits = `Any) random ~side_set_count =
  let w = Splittable_random.int random ~lo:0 ~hi:0xffff in
  let input_pin pin = pin < Isa.first_output_pin in
  match Isa.of_word ~side_set_count w, waits with
  | (Ok (Op { op = Sys Halt; _ }) | Error _), _ -> word ~waits random ~side_set_count
  | Ok (Op { op = Wait wait; _ }), `Input_pins ->
    (match wait with
     | (Pin_level { pin; _ } | Pin_edge { pin; _ }) when input_pin pin -> w
     | Pin_level _ | Pin_edge _ | Deadline _ | Fifo _ ->
       word ~waits random ~side_set_count)
  | Ok _, _ -> w
;;

let program ?waits random ~(config : Program_config.t) =
  List.init (1 lsl Isa.pc_bits) ~f:(fun _ ->
    word ?waits random ~side_set_count:config.side_set_count)
;;
