open! Core
open! Hardcaml
open Hardcaml_of_verilog
open Protocol_emulator

module Names = struct
  type t =
    { pin : string option
    ; valid : string option
    ; data : string option
    ; reset : string option
    ; active_low : bool option
    ; tied : (string * int) list
    }

  let none =
    { pin = None; valid = None; data = None; reset = None; active_low = None; tied = [] }
  ;;
end

type t =
  { files : string list
  ; top : string
  ; parameters : (string * string) list
  ; sim : Bit_sim.t
  ; ports : Frame_compiler.Ports.t
  ; clock : string
  ; others : string list
  ; register_name : Signal.t -> string option
  }

let refuse fmt = Printf.ksprintf (fun s -> Or_error.error_string s) fmt

(* the cells hardcaml_of_verilog models, less memories and latches *)
let supported =
  String.Set.of_list
    [ "$not"
    ; "$pos"
    ; "$neg"
    ; "$reduce_and"
    ; "$reduce_or"
    ; "$reduce_xor"
    ; "$reduce_xnor"
    ; "$reduce_bool"
    ; "$logic_not"
    ; "$and"
    ; "$or"
    ; "$xor"
    ; "$xnor"
    ; "$add"
    ; "$sub"
    ; "$mul"
    ; "$shl"
    ; "$shr"
    ; "$sshl"
    ; "$sshr"
    ; "$shift"
    ; "$shiftx"
    ; "$logic_and"
    ; "$logic_or"
    ; "$lt"
    ; "$le"
    ; "$gt"
    ; "$ge"
    ; "$eq"
    ; "$ne"
    ; "$eqx"
    ; "$nex"
    ; "$mux"
    ; "$pmux"
    ; "$dff"
    ; "$dffe"
    ; "$adff"
    ; "$concat"
    ; "$slice"
    ]
;;

let kinds =
  [ "$mem", "a memory"
  ; "$mem_v2", "a memory"
  ; "$memrd", "a memory"
  ; "$memwr", "a memory"
  ; "$dlatch", "a latch"
  ; "$dffsr", "a flop with set and reset"
  ; "$div", "a division"
  ; "$mod", "a remainder"
  ; "$pow", "a power"
  ]
;;

(* "file.v:30.13-30.22" as "file.v:30" *)
let line_of src =
  let src = List.hd_exn (String.split src ~on:'|') in
  match String.rsplit2 src ~on:':' with
  | Some (file, position) ->
    Filename.basename file ^ ":" ^ List.hd_exn (String.split position ~on:'.')
  | None -> src
;;

let src json =
  Jsonaf.member "attributes" json
  |> Option.bind ~f:(Jsonaf.member "src")
  |> Option.bind ~f:Jsonaf.string
  |> Option.map ~f:line_of
;;

let yosys_json ~files ~top ~parameters =
  let json = Filename_unix.temp_file "verilog_in" ".json" in
  let script =
    List.concat
      [ List.map files ~f:(fun file -> "read_verilog " ^ file)
      ; List.map parameters ~f:(fun (name, value) ->
          [%string "chparam -set %{name} %{value} %{top}"])
      ; [ "hierarchy -check -top " ^ top
        ; "proc"
        ; "flatten -noscopeinfo"
        ; "write_json -compat-int " ^ json
        ]
      ]
    |> String.concat ~sep:"; "
  in
  Exn.protect
    ~finally:(fun () -> Core_unix.unlink json)
    ~f:(fun () ->
      let log = Filename_unix.temp_file "verilog_in" ".log" in
      let command =
        "yosys -q -l " ^ log ^ " -p " ^ Filename.quote script ^ " > /dev/null 2>&1"
      in
      match Stdlib.Sys.command command with
      | 0 ->
        Core_unix.unlink log;
        Ok (In_channel.read_all json)
      | _ ->
        let errors =
          In_channel.read_lines log
          |> List.filter ~f:(String.is_substring ~substring:"ERROR")
          |> String.concat ~sep:" "
        in
        Core_unix.unlink log;
        refuse "yosys cannot read it: %s" errors)
;;

let module_json json ~top =
  let%bind.Or_error json = Jsonaf.parse json in
  Jsonaf.member_exn "modules" json
  |> Jsonaf.member top
  |> Or_error.of_option ~error:(Error.of_string ("no module " ^ top))
;;

let check_cells module_ =
  Jsonaf.member_exn "cells" module_
  |> Jsonaf.assoc_list_exn
  |> List.filter_map ~f:(fun (_, cell) ->
    let kind = Jsonaf.member_exn "type" cell |> Jsonaf.string_exn in
    let unknown_reset =
      String.equal kind "$adff"
      && Jsonaf.member "parameters" cell
         |> Option.bind ~f:(Jsonaf.member "ARST_VALUE")
         |> Option.bind ~f:Jsonaf.string
         |> Option.exists ~f:(fun value -> String.mem value 'x')
    in
    if unknown_reset
    then
      Some
        (Error.of_string
           [%string
             "%{Option.value (src cell) ~default:\"?\"}: a register the asynchronous \
              reset leaves as it was, which hardcaml_of_verilog cannot convert"])
    else if Set.mem supported kind
    then None
    else (
      let what =
        List.Assoc.find kinds kind ~equal:String.equal
        |> Option.value ~default:("a " ^ kind ^ " cell")
      in
      Some
        (Error.of_string
           [%string
             "%{Option.value (src cell) ~default:\"?\"}: %{what} is outside the subset"])))
  |> List.dedup_and_sort ~compare:(Comparable.lift String.compare ~f:Error.to_string_hum)
  |> function
  | [] -> Ok ()
  | errors -> Error (Error.of_list errors)
;;

(* netname to its declaration's line, and to its init value *)
let netnames module_ =
  Jsonaf.member_exn "netnames" module_
  |> Jsonaf.assoc_list_exn
  |> List.map ~f:(fun (name, net) -> name, net)
;;

let is_user_name name = not (String.is_prefix name ~prefix:"$")

let looks_like_reset name =
  let lower = String.lowercase name in
  List.exists [ "rst"; "reset" ] ~f:(fun word ->
    String.is_substring lower ~substring:word)
  || List.mem [ "clear"; "clr" ] lower ~equal:String.equal
;;

let active_low name =
  let lower = String.lowercase name in
  List.exists [ "n"; "_l"; "_b" ] ~f:(fun suffix -> String.is_suffix lower ~suffix)
;;

let read ~files ~top ~parameters (names : Names.t) =
  let open Or_error.Let_syntax in
  Or_error.try_with_join (fun () ->
    let%bind json = yosys_json ~files ~top ~parameters in
    let%bind module_ = module_json json ~top in
    let%bind () = check_cells module_ in
    let%bind circuit =
      (let%bind yosys = Expert.Yosys_netlist.of_string json in
       let%bind netlist = Netlist.of_yosys_netlist yosys in
       let%bind verilog_circuit = Verilog_circuit.create netlist ~top_name:top in
       Verilog_circuit.to_hardcaml_circuit verilog_circuit)
      |> Or_error.tag ~tag:"hardcaml_of_verilog cannot convert it"
    in
    let nets = netnames module_ in
    let line name = List.Assoc.find nets name ~equal:String.equal |> Option.bind ~f:src in
    let init name =
      List.Assoc.find nets name ~equal:String.equal
      |> Option.bind ~f:(Jsonaf.member "attributes")
      |> Option.bind ~f:(Jsonaf.member "init")
    in
    (* a register drives a wire with every name its net has *)
    let reg_names = Hashtbl.create (module Signal.Type.Uid) in
    Signal_graph.iter (Circuit.signal_graph circuit) ~f:(fun (s : Signal.t) ->
      match s with
      | Wire { driver = Some (Reg _ as r); _ } ->
        (match List.filter (Signal.names s) ~f:is_user_name with
         | name :: _ -> Hashtbl.set reg_names ~key:(Signal.uid r) ~data:name
         | [] -> ())
      | _ -> ());
    let register_name s = Hashtbl.find reg_names (Signal.uid s) in
    let describe s =
      match register_name s with
      | Some name ->
        (match line name with
         | Some line -> [%string "%{name} (%{line})"]
         | None -> name)
      | None ->
        (match Signal.names s with
         | name :: _ ->
           (match line name with
            | Some line -> [%string "%{name} (%{line})"]
            | None -> name)
         | [] -> Signal.Type.to_string s)
    in
    let initial s =
      let%bind.Option name = register_name s in
      let%bind.Option init = init name in
      let width = Signal.width s in
      match Jsonaf.int init, Jsonaf.string init with
      | Some n, _ -> Some (Bits.of_unsigned_int ~width n)
      | None, Some bits when String.for_all bits ~f:(fun c -> Char.(c = '0' || c = '1'))
        -> Some (Bits.of_string bits)
      | _ -> None
    in
    let%bind sim = Bit_sim.create ~describe ~initial circuit in
    let clocks =
      List.filter_map (Bit_sim.registers sim) ~f:(fun (s : Signal.t) ->
        match s with
        | Reg { register = { clock = { clock; _ }; _ }; _ } ->
          List.hd (Signal.names clock)
        | _ -> None)
      |> List.dedup_and_sort ~compare:String.compare
    in
    let%bind clock =
      match clocks with
      | [ clock ] -> Ok clock
      | [] -> refuse "no registers"
      | _ -> refuse "more than one clock"
    in
    let inputs =
      List.map (Circuit.inputs circuit) ~f:(fun s ->
        List.hd_exn (Signal.names s), Signal.width s)
      |> List.filter ~f:(fun (name, _) -> not (String.equal name clock))
    in
    let outputs =
      List.map (Circuit.outputs circuit) ~f:(fun s ->
        List.hd_exn (Signal.names s), Signal.width s)
    in
    let one ~what ~given candidates =
      match given with
      | Some name -> Ok name
      | None ->
        (match candidates with
         | [ name ] -> Ok name
         | [] -> refuse "no %s" what
         | names ->
           refuse "%s could be any of %s: name one" what (String.concat ~sep:", " names))
    in
    let reset =
      match names.reset with
      | Some name -> Some name
      | None ->
        List.find_map inputs ~f:(fun (name, width) ->
          Option.some_if (width = 1 && looks_like_reset name) name)
    in
    let is_reset name = Option.exists reset ~f:(String.equal name) in
    let is_tied name = List.Assoc.mem names.tied name ~equal:String.equal in
    let inputs = List.filter inputs ~f:(fun (name, _) -> not (is_tied name)) in
    let%bind tied =
      List.map names.tied ~f:(fun (name, value) ->
        match
          List.find_map (Circuit.inputs circuit) ~f:(fun s ->
            Option.some_if
              (List.mem (Signal.names s) name ~equal:String.equal)
              (Signal.width s))
        with
        | Some width when value >= 0 && value < 1 lsl width ->
          Ok (name, Bits.of_unsigned_int ~width value)
        | Some width -> refuse "%d does not fit %s's %d bits" value name width
        | None -> refuse "no input %s to tie" name)
      |> Or_error.all
    in
    let%bind pin =
      one
        ~what:"pin (a 1-bit output)"
        ~given:names.pin
        (List.filter_map outputs ~f:(fun (name, width) -> Option.some_if (width = 1) name))
    in
    let%bind valid =
      one
        ~what:"valid (a 1-bit input)"
        ~given:names.valid
        (List.filter_map inputs ~f:(fun (name, width) ->
           Option.some_if (width = 1 && not (is_reset name)) name))
    in
    let%map data =
      one
        ~what:"data (an input wider than a bit)"
        ~given:names.data
        (List.filter_map inputs ~f:(fun (name, width) -> Option.some_if (width > 1) name))
    in
    let reset =
      Option.map reset ~f:(fun name ->
        let low = Option.value names.active_low ~default:(active_low name) in
        name, if low then Level.Low else High)
    in
    let others =
      List.filter_map inputs ~f:(fun (name, _) ->
        Option.some_if
          (not (is_reset name || String.equal name valid || String.equal name data))
          ("input " ^ name))
      @ List.filter_map outputs ~f:(fun (name, _) ->
        Option.some_if (not (String.equal name pin)) ("output " ^ name))
    in
    { files
    ; top
    ; parameters
    ; sim
    ; ports = { reset; valid; data; pin; tied }
    ; clock
    ; others
    ; register_name
    })
;;
