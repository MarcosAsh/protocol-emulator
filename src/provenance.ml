open! Core
open! Hardcaml

module Source = struct
  type t =
    { file : string
    ; line : int
    ; named : bool
    }
  [@@deriving compare, sexp_of]

  let to_string { file; line; named = _ } = [%string "%{file}:%{line#Int}"]
end

let traced f =
  Caller_id.set_mode Full_trace;
  Exn.protect ~f ~finally:(fun () -> Caller_id.set_mode Disabled)
;;

(* [@@deriving hardcaml] code sits at the record field it maps, so a signal an interface's
   [Of_always.reg] or [wires] made would claim a type's field. OxCaml names its frames
   after any of the derived functions. *)
let derived =
  String.Set.of_list
    [ "ast"
    ; "iter"
    ; "iter2"
    ; "map"
    ; "map2"
    ; "port_names_and_widths"
    ; "sexp_of_t"
    ; "to_list"
    ; "wave_formats"
    ]
;;

let is_derived defname =
  String.chop_suffix_if_exists defname ~suffix:".(fun)"
  |> String.rsplit2 ~on:'.'
  |> Option.exists ~f:(fun (_, name) -> Set.mem derived name)
;;

(* Core and Hardcaml keep their sources in a src/ too, so a frame is told ours by the
   module dune wraps it in. Frames past Hardcaml's hierarchy are the parent's, where the
   module was instantiated, so a signal whose own frames were inlined or cut has none. *)
let made signal =
  Signal.Type.caller_id signal
  |> Caller_id.call_stack_opt
  |> List.filter_opt
  |> List.take_while ~f:(fun (slot : Call_stack.Slot.t') ->
    not (String.is_prefix slot.defname ~prefix:"Hardcaml__Hierarchy."))
  |> List.find_map ~f:(fun { filename; line_number; defname; _ } ->
    Option.some_if
      (String.is_prefix defname ~prefix:"Protocol_emulator__" && not (is_derived defname))
      { Source.file = filename; line = line_number; named = false })
;;

let named signal ~index ~ours =
  match List.nth (Signal.Type.names_and_locs signal) index with
  | Some { loc; _ } when Set.mem ours loc.pos_fname ->
    Some { Source.file = loc.pos_fname; line = loc.pos_lnum; named = true }
  | _ -> None
;;

(* a wire with no line of its own, an output port say, has its driver's *)
let rec source signal ~index ~ours =
  match Option.first_some (named signal ~index ~ours) (made signal) with
  | Some _ as found -> found
  | None -> Option.bind (Signal.Type.wire_driver signal) ~f:(source ~index:0 ~ours)
;;

let names instance =
  let signals =
    Rtl.Circuit_instance.circuit instance
    |> Circuit.signal_graph
    |> Signal_graph.fold ~init:Signal.Type.Uid.Map.empty ~f:(fun map signal ->
      Map.set map ~key:(Signal.uid signal) ~data:signal)
  in
  Rtl.Circuit_instance.name_map instance
  |> Map.to_alist
  |> List.map ~f:(fun ((uid, index), name) ->
    Rtl.Name.For_backend.to_string name, index, Map.find signals uid)
;;

let of_rtl rtl =
  let modules =
    Rtl.Hierarchical_circuits.(top rtl @ subcircuits rtl)
    |> List.map ~f:(fun instance -> Rtl.Circuit_instance.module_name instance, instance)
    |> List.dedup_and_sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
    |> List.map ~f:(fun (name, instance) -> name, names instance)
  in
  (* a name's location counts only in a file some frame of ours is in. Constants share a
     name, which takes the first one's line. *)
  let ours =
    List.concat_map modules ~f:(fun (_, names) ->
      List.filter_map names ~f:(fun (_, _, signal) ->
        Option.bind signal ~f:made |> Option.map ~f:(fun source -> source.file)))
    |> String.Set.of_list
  in
  List.map modules ~f:(fun (module_name, names) ->
    ( module_name
    , List.map names ~f:(fun (name, index, signal) ->
        name, Option.bind signal ~f:(source ~index ~ours))
      |> List.sort ~compare:[%compare: string * _]
      |> List.remove_consecutive_duplicates
           ~which_to_keep:`First
           ~equal:(fun (a, _) (b, _) -> String.equal a b) ))
;;

let to_json modules =
  let quote s = "\"" ^ String.escaped s ^ "\"" in
  let source = Option.value_map ~default:"null" ~f:(Fn.compose quote Source.to_string) in
  List.map modules ~f:(fun (module_name, names) ->
    List.map names ~f:(fun (name, found) ->
      [%string "    %{quote name}: %{source found}"])
    |> String.concat ~sep:",\n"
    |> fun names -> [%string "  %{quote module_name}: {\n%{names}\n  }"])
  |> String.concat ~sep:",\n"
  |> fun modules -> [%string "{\n%{modules}\n}\n"]
;;
