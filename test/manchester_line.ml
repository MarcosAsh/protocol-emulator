open! Core
open Protocol_emulator

let bit_ns = 100.

(* The line as transitions: idle low, then per bit its complement and its value, then
   TP_IDL, high 300 ns, and idle again. Each transition moves by up to [jitter] ns either
   way, independently, and the sender's bit is [ppm] long or short. *)
let transitions ~random ~ppm ~jitter bits =
  let length = bit_ns *. (1. +. (ppm /. 1e6)) in
  let start = 1000. in
  let level = ref 0 in
  let edges = Queue.create () in
  let put at value =
    if value <> !level
    then (
      level := value;
      let moved =
        if Float.(jitter = 0.)
        then 0.
        else Random.State.float random (2. *. jitter) -. jitter
      in
      Queue.enqueue edges (at +. moved, value))
  in
  List.iteri bits ~f:(fun n bit ->
    let at = start +. (Float.of_int n *. length) in
    put at (1 - bit);
    put (at +. (length /. 2.)) bit);
  let finish = start +. (Float.of_int (List.length bits) *. length) in
  put finish 1;
  put (finish +. 300.) 0;
  Queue.to_list edges, finish +. 1000.
;;

(* The line sampled [per_bit] times a bit from a random phase, [per_cycle] to a cycle. *)
let sample ~random ~per_bit ~per_cycle (edges, stop) =
  let period = bit_ns /. Float.of_int per_bit in
  let first = Random.State.float random period in
  let count = Float.iround_down_exn ((stop -. first) /. period) / per_cycle in
  (* in order: the level is carried from one sample to the next *)
  let edges = ref edges in
  let level = ref 0 in
  let level_at at =
    let rec catch_up () =
      match !edges with
      | (time, value) :: rest when Float.(time <= at) ->
        level := value;
        edges := rest;
        catch_up ()
      | _ -> ()
    in
    catch_up ();
    !level
  in
  let cycles = Queue.create () in
  for cycle = 0 to count - 1 do
    let samples = Queue.create () in
    for k = 0 to per_cycle - 1 do
      Queue.enqueue
        samples
        (level_at (first +. (Float.of_int ((cycle * per_cycle) + k) *. period)))
    done;
    Queue.enqueue cycles (Queue.to_list samples)
  done;
  Queue.to_list cycles
;;

let bits_of_bytes bytes =
  List.concat_map bytes ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr i) land 1))
;;

let preamble = List.init 7 ~f:(Fn.const 0x55) @ [ 0xd5 ]

(* zlib's CRC-32, on [Crc]'s serial step *)
let crc32 bytes =
  List.fold (bits_of_bytes bytes) ~init:0xffffffff ~f:(fun crc bit ->
    Crc.step ~width:32 ~poly:Frame_rx.poly ~reflect:true crc ~bit)
  lxor 0xffffffff
;;

let with_fcs bytes =
  let fcs = crc32 bytes in
  bytes @ List.init 4 ~f:(fun n -> (fcs lsr (8 * n)) land 0xff)
;;

(* two bytes to a word, low first, a last odd byte alone *)
let words bytes =
  List.chunks_of bytes ~length:2
  |> List.map ~f:(function
    | [ low; high ] -> low lor (high lsl 8)
    | [ low ] -> low
    | _ -> assert false)
;;
