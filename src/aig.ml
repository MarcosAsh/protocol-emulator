open! Core
open! Hardcaml

module Make () = struct
  (* A literal is twice its node, plus one when inverted; node 0 is false. Only the
     constant folding [Basic_gates] does is done here, so the graph keeps its shape. *)
  module Literal = struct
    type t = int [@@deriving equal ~localize, sexp]

    let constant_only = false
    let optimise_muxs = false
    let gnd = 0
    let vdd = 1
    let nodes = ref 0
    let inputs = Queue.create ()
    let ands = Queue.create ()

    let node () =
      incr nodes;
      2 * !nodes
    ;;

    let input name =
      let literal = node () in
      Queue.enqueue inputs (literal, name);
      literal
    ;;

    let ( ~: ) a = a lxor 1

    let ( &: ) a b =
      if a = gnd || b = gnd
      then gnd
      else if a = vdd
      then b
      else if b = vdd
      then a
      else (
        let literal = node () in
        Queue.enqueue ands (literal, Int.max a b, Int.min a b);
        literal)
    ;;

    let ( |: ) a b = ~:(~:a &: ~:b)
    let ( ^: ) a b = a &: ~:b |: (~:a &: b)

    let to_char = function
      | 0 -> '0'
      | 1 -> '1'
      | literal -> raise_s [%message "not a constant" (literal : int)]
    ;;

    let of_char = function
      | '0' -> gnd
      | '1' -> vdd
      | c -> raise_s [%message "not a constant" (c : char)]
    ;;
  end

  include Bits_list.Make (Literal)

  (* as yosys's write_aiger names them, msb first *)
  let bit_names name width =
    if width = 1
    then [ name ]
    else List.init width ~f:(fun i -> [%string "%{name}[%{width - 1 - i#Int}]"])
  ;;

  let input name width = bit_names name width |> List.map ~f:Literal.input

  let to_aiger outputs =
    let outputs =
      List.concat_map outputs ~f:(fun (name, bits) ->
        List.zip_exn (bit_names name (List.length bits)) bits)
    in
    let inputs = Queue.to_list Literal.inputs in
    let buffer = Buffer.create 65536 in
    let line fmt = ksprintf (fun s -> Buffer.add_string buffer (s ^ "\n")) fmt in
    line
      "aag %d %d 0 %d %d"
      !Literal.nodes
      (List.length inputs)
      (List.length outputs)
      (Queue.length Literal.ands);
    List.iter inputs ~f:(fun (literal, _) -> line "%d" literal);
    List.iter outputs ~f:(fun (_, literal) -> line "%d" literal);
    Queue.iter Literal.ands ~f:(fun (literal, a, b) -> line "%d %d %d" literal a b);
    List.iteri inputs ~f:(fun i (_, name) -> line "i%d %s" i name);
    List.iteri outputs ~f:(fun i (name, _) -> line "o%d %s" i name);
    Buffer.contents buffer
  ;;
end
