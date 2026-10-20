open! Core
open! Hardcaml
open Hardcaml_of_verilog
module Sec = Hardcaml_verify.Sec
module Uid = Signal.Type.Uid
module Yosys_netlist = Expert.Yosys_netlist

module Verilog = struct
  type t =
    { netlist : Netlist.t
    ; inits : (string * Jsonaf.t) list String.Map.t
    }

  (* each module but a black box, with the [init] attribute Yosys gives a reg declared
     with a value: a number, or bits when not 32 or fewer and all 0 or 1 *)
  let attributes json =
    let%map.Or_error json = Jsonaf.parse json in
    Jsonaf.member_exn "modules" json
    |> Jsonaf.assoc_list_exn
    |> List.filter ~f:(fun (_, module_) ->
      Jsonaf.member_exn "attributes" module_ |> Jsonaf.member "blackbox" |> Option.is_none)
    |> List.map ~f:(fun (module_name, module_) ->
      ( module_name
      , Jsonaf.member_exn "netnames" module_
        |> Jsonaf.assoc_list_exn
        |> List.filter_map ~f:(fun (name, net) ->
          Jsonaf.member_exn "attributes" net
          |> Jsonaf.member "init"
          |> Option.map ~f:(fun init -> name, init)) ))
    |> String.Map.of_alist_exn
  ;;

  let read ~files ~lib ~top =
    let json = Filename_unix.temp_file "translation" ".json" in
    let script =
      List.concat
        [ List.map lib ~f:(fun file -> "read_verilog -lib " ^ file)
        ; List.map files ~f:(fun file -> "read_verilog " ^ file)
        ; [ "hierarchy -check -top " ^ top
          ; "proc -norom"
          ; "memory_map"
          ; "write_json -compat-int " ^ json
          ]
        ]
      |> String.concat ~sep:"; "
    in
    Exn.protect
      ~finally:(fun () -> Core_unix.unlink json)
      ~f:(fun () ->
        let command = "yosys -q -p " ^ Filename.quote script in
        let%bind.Or_error () =
          match Stdlib.Sys.command command with
          | 0 -> Ok ()
          | exit_code -> error_s [%message "yosys failed" command (exit_code : int)]
        in
        let json = In_channel.read_all json in
        let%bind.Or_error yosys = Yosys_netlist.of_string json in
        let%bind.Or_error netlist = Netlist.of_yosys_netlist yosys in
        let%map.Or_error inits = attributes json in
        { netlist; inits })
  ;;

  let modules t = Map.keys t.inits
end

module Outcome = struct
  type t =
    { flops : int
    ; bits : int
    ; equal : Sec.Equivalence_result.t
    }
  [@@deriving sexp_of]
end

let op2 (op : Signal.Type.Op.t) a b =
  let open Signal.Unoptimized in
  match op with
  | Add -> a +: b
  | Sub -> a -: b
  | Mulu -> a *: b
  | Muls -> a *+ b
  | And -> a &: b
  | Or -> a |: b
  | Xor -> a ^: b
  | Eq -> a ==: b
  | Lt -> a <: b
;;

let named signal name =
  Signal.set_names signal [ { Name_and_loc.name; loc = [%here] } ];
  signal
;;

(* Yosys takes an asynchronous reset through inverters, as [x] low rather than [~x] high *)
let rec through_inverters (reset : Signal.t) (level : Level.t) =
  match reset with
  | Not { arg; _ } -> through_inverters arg (if Level.equal level High then Low else High)
  | Wire { driver = Some driver; _ } -> through_inverters driver level
  | _ -> reset, level
;;

(* [circuit] rebuilt in the form [Translation] describes; [name] is a flop's or memory's
   Verilog name *)
let flops circuit ~name =
  let built = Hashtbl.create (module Uid) in
  let memories = Hashtbl.create (module Uid) in
  let inputs =
    Circuit.inputs circuit |> List.map ~f:Signal.uid |> Set.of_list (module Uid)
  in
  let rec build (signal : Signal.t) =
    match Hashtbl.find built (Signal.uid signal) with
    | Some signal -> signal
    | None ->
      let rebuilt = rebuild signal in
      Hashtbl.set built ~key:(Signal.uid signal) ~data:rebuilt;
      rebuilt
  and rebuild (signal : Signal.t) =
    let open Signal.Unoptimized in
    match signal with
    | Empty -> Signal.empty
    | Const { constant; _ } -> Signal.of_bits constant
    | Op2 { op; arg_a; arg_b; _ } -> op2 op (build arg_a) (build arg_b)
    | Mux { select; cases; _ } -> mux (build select) (List.map cases ~f:build)
    | Cases { select; cases; default; _ } ->
      Signal.Unoptimized.cases
        ~default:(build default)
        (build select)
        (List.map cases ~f:(fun (match_with, value) -> build match_with, build value))
    | Cat { args; _ } -> concat_msb (List.map args ~f:build)
    | Not { arg; _ } -> ~:(build arg)
    | Select { arg; high; low; _ } -> select (build arg) ~high ~low
    | Wire { driver = Some driver; _ } -> build driver
    | Wire { driver = None; _ } ->
      if not (Set.mem inputs (Signal.uid signal))
      then raise_s [%message "undriven wire" (signal : Signal.t)];
      Signal.input (List.hd_exn (Signal.names signal)) (Signal.width signal)
    | Reg { register = { clock; reset; clear; enable; initialize_to }; d; _ } ->
      (* the flop's output first: [d] may read it *)
      let q = Signal.wire (Signal.width signal) in
      Hashtbl.set built ~key:(Signal.uid signal) ~data:q;
      let enabled =
        Option.value_map enable ~default:(build d) ~f:(fun enable ->
          mux2 (build enable) (build d) q)
      in
      let next =
        Option.value_map clear ~default:enabled ~f:(fun { clear; clear_to } ->
          mux2 (build clear) (build clear_to) enabled)
      in
      let reset =
        Option.map reset ~f:(fun { reset; reset_level; reset_to } ->
          let reset, reset_level = through_inverters reset reset_level in
          build reset, reset_level, Signal.to_bits reset_to)
      in
      let spec =
        Signal.Reg_spec.create
          ~clock_edge:clock.clock_edge
          ?reset:(Option.map reset ~f:fst3)
          ?reset_level:(Option.map reset ~f:snd3)
          ()
          ~clock:(build clock.clock)
      in
      let flop =
        Signal.reg spec ?initialize_to ?reset_to:(Option.map reset ~f:trd3) next
      in
      Signal.( <-- ) q (named flop (name signal));
      q
    | Mem_read_port { memory; read_address; _ } ->
      let words = memory_words memory in
      if Array.length words <> 1 lsl Signal.width read_address
      then raise_s [%message "memory not a power of two in size" (memory : Signal.t)];
      mux (build read_address) (Array.to_list words)
    | Multiport_mem _ -> raise_s [%message "memory read whole" (signal : Signal.t)]
    | Inst
        { instantiation = { circuit_name; instance_label; parameters; inputs; outputs; _ }
        ; _
        } ->
      (* the instance first: a path may leave it and come back *)
      let wires =
        List.map inputs ~f:(fun { name; input_signal } ->
          name, input_signal, Signal.wire (Signal.width input_signal))
      in
      let instance =
        Instantiation.create
          ()
          ~name:circuit_name
          ~instance:instance_label
          ~parameters
          ~inputs:(List.map wires ~f:(fun (name, _, wire) -> name, wire))
          ~outputs:
            (List.map outputs ~f:(fun { name; output_width; _ } -> name, output_width))
        |> Instantiation.instantiation_signal
      in
      Hashtbl.set built ~key:(Signal.uid signal) ~data:instance;
      List.iter wires ~f:(fun (_, input_signal, wire) ->
        Signal.( <-- ) wire (build input_signal));
      instance
  (* Cyclesim writes the ports in order, so the last one wins *)
  and memory_words (memory : Signal.t) =
    match Hashtbl.find memories (Signal.uid memory) with
    | Some words -> words
    | None ->
      (match memory with
       | Multiport_mem { size; write_ports; initialize_to = None; _ } ->
         let words = Array.init size ~f:(fun _ -> Signal.wire (Signal.width memory)) in
         Hashtbl.set memories ~key:(Signal.uid memory) ~data:words;
         let clock =
           match
             Array.to_list write_ports
             |> List.map ~f:(fun port -> port.write_clock)
             |> List.dedup_and_sort ~compare:(Comparable.lift Uid.compare ~f:Signal.uid)
           with
           | [ clock ] -> build clock
           | _ -> raise_s [%message "memory not on one clock" (memory : Signal.t)]
         in
         let spec = Signal.Reg_spec.create () ~clock in
         Array.iteri words ~f:(fun i q ->
           let next =
             Array.fold write_ports ~init:q ~f:(fun held port ->
               Signal.Unoptimized.(
                 mux2
                   (build port.write_enable &: (build port.write_address ==:. i))
                   (build port.write_data)
                   held))
           in
           let word = [%string "%{name memory}[%{i#Int}]"] in
           Signal.( <-- ) q (named (Signal.reg spec next) word));
         words
       | _ -> raise_s [%message "memory with an initial value" (memory : Signal.t)])
  in
  let outputs =
    List.map (Circuit.outputs circuit) ~f:(fun output ->
      let driver = Option.value_exn (Signal.Type.wire_driver output) in
      Signal.output (List.hd_exn (Signal.names output)) (build driver))
  in
  Circuit.create_exn ~name:(Circuit.name circuit) outputs
;;

let regs circuit =
  Circuit.signal_graph circuit
  |> Signal_graph.filter ~f:Signal.Type.is_reg
  |> List.sort ~compare:(Comparable.lift Uid.compare ~f:Signal.uid)
;;

(* a flop of Yosys's drives a wire with every name its net has; it takes the one the
   Hardcaml side gave a flop, which must be exactly one *)
let name_flops circuit ~flop_names =
  Circuit.signal_graph circuit
  |> Signal_graph.iter ~f:(fun (signal : Signal.t) ->
    match signal with
    | Wire { driver = Some (Reg _ as flop); _ } ->
      (match List.filter (Signal.names signal) ~f:(Set.mem flop_names) with
       | [ name ] -> ignore (named flop name : Signal.t)
       | names ->
         raise_s
           [%message "flop not named once" (names : string list) (signal : Signal.t)])
    | _ -> ())
;;

let check instance (verilog : Verilog.t) =
  Or_error.try_with_join (fun () ->
    let module_name = Rtl.Circuit_instance.module_name instance in
    let names = Rtl.Circuit_instance.name_map instance in
    let name signal =
      match Map.find names (Signal.uid signal, 0) with
      | Some name -> Rtl.Name.For_backend.to_string name
      | None -> raise_s [%message "no verilog name" (signal : Signal.t)]
    in
    let hardcaml = flops (Rtl.Circuit_instance.circuit instance) ~name in
    let flops = regs hardcaml in
    let flop_names = List.concat_map flops ~f:Signal.names |> String.Set.of_list in
    let%bind.Or_error yosys =
      let%bind.Or_error circuit =
        Verilog_circuit.create verilog.netlist ~top_name:module_name
      in
      Verilog_circuit.to_hardcaml_circuit circuit
    in
    name_flops yosys ~flop_names;
    let inits =
      List.filter_map flops ~f:(function
        | Reg { register = { initialize_to = Some init; _ }; _ } as flop ->
          Some (List.hd_exn (Signal.names flop), Bits.to_bstr init)
        | _ -> None)
    in
    let widths =
      List.map flops ~f:(fun flop -> List.hd_exn (Signal.names flop), Signal.width flop)
      |> String.Map.of_alist_exn
    in
    let verilog_inits =
      Map.find_multi verilog.inits module_name
      |> List.filter_map ~f:(fun (name, init) ->
        Map.find widths name
        |> Option.map ~f:(fun width ->
          ( name
          , match init with
            | `Number _ ->
              Bits.of_unsigned_int ~width (Jsonaf.int_exn init) |> Bits.to_bstr
            | _ -> Jsonaf.string_exn init )))
    in
    let sorted = List.sort ~compare:[%compare: string * string] in
    let%bind.Or_error () =
      if [%equal: (string * string) list] (sorted inits) (sorted verilog_inits)
      then Ok ()
      else
        error_s
          [%message
            "initial values differ"
              (inits : (string * string) list)
              (verilog_inits : (string * string) list)]
    in
    let%bind.Or_error sec = Sec.create hardcaml yosys in
    let%map.Or_error equal = Sec.circuits_equivalent sec in
    { Outcome.flops = List.length flops
    ; bits = List.sum (module Int) flops ~f:Signal.width
    ; equal
    })
;;
