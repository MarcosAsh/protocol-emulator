open! Core
open Ppxlib
open Protocol_emulator

(* What a firmware's settings evaluate to at compile time. *)
module Value = struct
  type t =
    | Int of int
    | Bool of bool
    | Constructor of string
    | Record of (string * t) list

  let rec t_of_sexp : Sexp.t -> t = function
    | Atom (("true" | "false") as b) -> Bool (Bool.of_string b)
    | Atom a when Char.is_digit a.[0] || Char.equal a.[0] '-' -> Int (Int.of_string a)
    | Atom a -> Constructor a
    | List fields ->
      Record
        (List.map fields ~f:(function
          | List [ Atom name; value ] -> name, t_of_sexp value
          | sexp -> raise_s [%message "BUG: not a record field" (sexp : Sexp.t)]))
  ;;

  let rec sexp_of_t : t -> Sexp.t = function
    | Int i -> Atom (Int.to_string i)
    | Bool b -> Atom (Bool.to_string b)
    | Constructor c -> Atom c
    | Record fields ->
      List
        (List.map fields ~f:(fun (name, value) ->
           Sexp.List [ Atom name; sexp_of_t value ]))
  ;;
end

let fail ~loc message = Location.raise_errorf ~loc "[%%firmware] %s" message

(* What the top level binds above the firmware, the latest first. A name this pass cannot
   follow, and every name behind an [open] or [include], is refused rather than guessed,
   so the build checks what runs. *)
module Binding = struct
  type t =
    | Let of string * expression
    | Opaque of string
    | Open
    | Module of string
end

type env = Binding.t list

let rec lookup ~loc (env : env) name =
  match env with
  | [] -> None
  | Let (bound, expression) :: above when String.equal bound name ->
    Some (expression, above)
  | Opaque bound :: _ when String.equal bound name ->
    fail ~loc [%string "cannot follow %{name}, bound by more than a plain top-level let"]
  | Open :: _ ->
    fail ~loc [%string "cannot tell what %{name} is, past an open or include above"]
  | _ :: above -> lookup ~loc above name
;;

let is_default (ident : Longident.t) =
  match Longident.flatten_exn ident |> List.rev with
  | "default" :: "Program_config" :: _ -> true
  | _ -> false
;;

(* [Program_config] and [Isa] are the library's, unless a module above takes the name. *)
let library ~loc (env : env) name =
  if List.exists env ~f:(function
       | Module bound -> String.equal bound name
       | Let _ | Opaque _ | Open -> false)
  then
    fail ~loc [%string "cannot tell which %{name} this is, past a module %{name} above"]
;;

(* The library's constants a configuration may name, as this ppx links the same library. *)
let isa = [ "first_bidir_pin", Isa.first_bidir_pin ]

let int_op ~loc env op =
  if List.exists env ~f:(function
       | Binding.Let (name, _) | Opaque name -> String.equal name op
       | Open | Module _ -> false)
  then fail ~loc [%string "cannot follow ( %{op} ), bound at the top level"];
  match op with
  | "+" -> Some ( + )
  | "-" -> Some ( - )
  | "*" -> Some ( * )
  | "/" -> Some ( / )
  | "mod" -> Some ( mod )
  | "lsl" -> Some ( lsl )
  | "lsr" -> Some ( lsr )
  | "land" -> Some ( land )
  | "lor" -> Some ( lor )
  | "lxor" -> Some ( lxor )
  | _ -> None
;;

(* Literals, integer arithmetic, records and names bound above. The run-time check sees
   the same expressions, so a disagreement still refuses, at load rather than build. *)
let rec eval (env : env) (e : expression) : Value.t =
  let loc = e.pexp_loc in
  let int e =
    match eval env e with
    | Int i -> i
    | _ -> fail ~loc:e.pexp_loc "expected an integer here"
  in
  match e.pexp_desc with
  | Pexp_constant (Pconst_integer (digits, None)) -> Int (Int.of_string digits)
  | Pexp_construct ({ txt = Lident (("true" | "false") as b); loc = _ }, None) ->
    Bool (Bool.of_string b)
  | Pexp_construct ({ txt; loc = _ }, None) -> Constructor (Longident.last_exn txt)
  | Pexp_ident { txt; loc = _ } when is_default txt ->
    library ~loc env "Program_config";
    Value.t_of_sexp (Program_config.sexp_of_t Program_config.default)
  | Pexp_ident { txt = Ldot (Lident "Isa", name); loc = _ }
    when List.Assoc.mem isa ~equal:String.equal name ->
    library ~loc env "Isa";
    Int (List.Assoc.find_exn isa ~equal:String.equal name)
  | Pexp_ident { txt = Lident name; loc = _ } ->
    (match lookup ~loc env name with
     | Some (expression, above) -> eval above expression
     | None ->
       fail
         ~loc
         [%string "cannot see a top-level let of %{name} above, to check at compile time"])
  | Pexp_apply
      ( { pexp_desc = Pexp_ident { txt = Lident op; loc = _ }; _ }
      , [ (Nolabel, a); (Nolabel, b) ] )
    when Option.is_some (int_op ~loc env op) ->
    let f = Option.value_exn (int_op ~loc env op) in
    Int (f (int a) (int b))
  | Pexp_apply
      ({ pexp_desc = Pexp_ident { txt = Lident "~-"; loc = _ }; _ }, [ (Nolabel, a) ]) ->
    Int (-int a)
  | Pexp_constraint (e, _, _) -> eval env e
  | Pexp_record (fields, base) ->
    let base =
      match Option.map base ~f:(eval env) with
      | None -> []
      | Some (Record fields) -> fields
      | Some _ -> fail ~loc "expected a record to update"
    in
    Record
      (List.fold fields ~init:base ~f:(fun record ({ txt; loc }, value) ->
         let name = Longident.last_exn txt in
         if List.Assoc.mem record ~equal:String.equal name || List.is_empty base
         then List.Assoc.add record ~equal:String.equal name (eval env value)
         else fail ~loc [%string "no field %{name}"]))
  | _ ->
    fail
      ~loc
      "checks at compile time, so this has to be a literal, integer arithmetic, a record \
       or a name bound by a top-level let above"
;;

let config env (e : expression) =
  let value = eval env e in
  match Program_config.t_of_sexp (Value.sexp_of_t value) with
  | config -> config
  | exception exn ->
    fail ~loc:e.pexp_loc [%string "not a Program_config.t: %{Exn.to_string exn}"]
;;

(* Where line [n] of a quoted string is, given where its contents start and end, from its
   first non-blank to the end of its instruction, so the squiggle sits under the
   instruction and not its comment. The lexer keeps a CRLF in a quoted string as a bare
   \n, so the lines are measured in the file, while it still holds the string. *)
let line_location (loc : Location.t) source n =
  let contents = loc.loc_start.pos_cnum in
  let in_file =
    Option.try_with (fun () ->
      String.sub
        (In_channel.read_all loc.loc_start.pos_fname)
        ~pos:contents
        ~len:(loc.loc_end.pos_cnum - contents))
    |> Option.filter ~f:(fun raw ->
      String.equal (String.substr_replace_all raw ~pattern:"\r\n" ~with_:"\n") source)
  in
  let lines = String.split (Option.value in_file ~default:source) ~on:'\n' in
  let before = List.take lines (n - 1) in
  let line = List.nth lines (n - 1) |> Option.value ~default:"" in
  let bol =
    if n = 1
    then loc.loc_start.pos_bol
    else contents + List.sum (module Int) before ~f:(fun l -> String.length l + 1)
  in
  let start = if n = 1 then contents - bol else 0 in
  let code =
    String.prefix
      line
      (String.index line ';' |> Option.value ~default:(String.length line))
  in
  let first =
    String.lfindi code ~f:(fun _ c -> not (Char.is_whitespace c))
    |> Option.value ~default:0
  in
  let last = String.length (String.rstrip code) in
  let position column =
    { loc.loc_start with
      pos_lnum = loc.loc_start.pos_lnum + n - 1
    ; pos_bol = bol
    ; pos_cnum = bol + start + column
    }
  in
  { loc with loc_start = position first; loc_end = position (Int.max first last) }
;;

module Payload = struct
  type t =
    { source : string
    ; source_expression : expression
    ; delimiter : string option
    ; string_loc : Location.t
    ; arguments : (string * expression) list
    }

  let names = [ "config"; "period"; "period_floor"; "single_capture_edge" ]

  let parse ~loc (payload : Ppxlib.payload) =
    let source_of (e : expression) =
      match e.pexp_desc with
      | Pexp_constant (Pconst_string (source, string_loc, delimiter)) ->
        source, e, delimiter, string_loc
      | _ -> fail ~loc:e.pexp_loc "expects the firmware as a string literal"
    in
    let expression =
      match payload with
      | PStr [ { pstr_desc = Pstr_eval (e, []); _ } ] -> e
      | _ -> fail ~loc "expects {| firmware |} then ~config, ~period, ~period_floor"
    in
    let (source, source_expression, delimiter, string_loc), arguments =
      match expression.pexp_desc with
      | Pexp_apply (e, arguments) -> source_of e, arguments
      | _ -> source_of expression, []
    in
    let arguments =
      List.map arguments ~f:(fun (label, e) ->
        match label with
        | Labelled name when List.mem names name ~equal:String.equal -> name, e
        | _ ->
          fail ~loc:e.pexp_loc [%string "takes only ~%{String.concat ~sep:\", ~\" names}"])
    in
    { source; source_expression; delimiter; string_loc; arguments }
  ;;
end

let refusal ~name (payload : Payload.t) (refusal : Timed_program.Refusal.t) =
  let at (fault : Timed_program.Fault.t) =
    match payload.delimiter with
    | Some _ -> line_location payload.string_loc payload.source fault.line
    | None -> payload.source_expression.pexp_loc
  in
  let who =
    match refusal.verdict with
    | None -> "the analyser"
    | Some _ -> "the proved kernel"
  in
  match refusal.faults with
  | [] -> fail ~loc:payload.source_expression.pexp_loc (Error.to_string_hum refusal.error)
  | first :: rest ->
    Location.Error.make
      ~loc:(at first)
      (match first.pc with
       | None -> [%string "%{name} does not assemble: %{first.reason}"]
       | Some _ -> [%string "%{name} is refused by %{who}: %{first.reason}"])
      ~sub:
        (List.map rest ~f:(fun fault ->
           ( at fault
           , if String.equal fault.reason first.reason
             then "and here"
             else [%string "and here: %{fault.reason}"] )))
    |> Location.Error.raise
;;

let expand ~(env : env) ~name ~loc payload =
  let payload = Payload.parse ~loc payload in
  let argument name = List.Assoc.find payload.arguments ~equal:String.equal name in
  let int name =
    Option.map (argument name) ~f:(fun e ->
      match eval env e with
      | Int i -> i
      | _ -> fail ~loc:e.pexp_loc [%string "expected an integer for ~%{name}"])
  in
  let config =
    Option.value_map (argument "config") ~default:Program_config.default ~f:(config env)
  in
  let single_capture_edge =
    Option.map (argument "single_capture_edge") ~f:(fun e ->
      match eval env e with
      | Bool b -> b
      | _ -> fail ~loc:e.pexp_loc "expected a bool for ~single_capture_edge")
  in
  let period = int "period" in
  let period_floor = int "period_floor" in
  if Option.is_some period && Option.is_some period_floor
  then fail ~loc "takes ~period or ~period_floor, not both";
  (match
     Timed_program.check ?period ?period_floor ?single_capture_edge ~config payload.source
   with
   | Ok _ -> ()
   | Error error -> refusal ~name payload error);
  let open Ast_builder.Default in
  let loc = { loc with loc_ghost = true } in
  let config =
    Option.value
      (argument "config")
      ~default:(evar ~loc "Protocol_emulator.Program_config.default")
  in
  pexp_apply
    ~loc
    (evar ~loc "Protocol_emulator.Timed_program.of_source_exn")
    (((Labelled "config", config)
      :: List.filter_map Payload.names ~f:(fun name ->
        if String.equal name "config"
        then None
        else Option.map (argument name) ~f:(fun e -> Labelled name, e)))
     @ [ Nolabel, payload.source_expression ])
;;

let error_expression ~loc error =
  Ast_builder.Default.pexp_extension ~loc (Location.Error.to_extension error)
;;

let catching ~loc f =
  try f () with
  | exn ->
    (match Location.Error.of_exn exn with
     | Some error -> error_expression ~loc error
     | None ->
       error_expression
         ~loc
         (Location.Error.make ~loc [%string "[%firmware] %{Exn.to_string exn}"] ~sub:[]))
;;

(* A [%firmware] anywhere but the whole of a top-level let could see names shadowed that
   this pass cannot. *)
let misplaced =
  object
    inherit Ast_traverse.map as super

    method! expression e =
      match e.pexp_desc with
      | Pexp_extension ({ txt = "firmware"; loc }, _) ->
        error_expression
          ~loc
          (Location.Error.make
             ~loc
             "[%firmware] has to be the whole of a top-level [let name = ...]"
             ~sub:[])
      | _ -> super#expression e
  end
;;

let bound_name (pattern : pattern) =
  match pattern.ppat_desc with
  | Ppat_var { txt; loc = _ }
  | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _, _) -> Some txt
  | _ -> None
;;

let names_in pattern =
  (object
     inherit [string list] Ast_traverse.fold as super

     method! pattern p acc =
       match p.ppat_desc with
       | Ppat_var { txt; loc = _ } | Ppat_alias (_, { txt; loc = _ }) ->
         super#pattern p (txt :: acc)
       | _ -> super#pattern p acc
  end)
    #pattern
    pattern
    []
;;

let structure items =
  List.folding_map items ~init:[] ~f:(fun (env : env) item ->
    match item.pstr_desc with
    | Pstr_value (Nonrecursive, bindings) ->
      let bindings =
        List.map bindings ~f:(fun binding ->
          match binding.pvb_expr.pexp_desc, bound_name binding.pvb_pat with
          | Pexp_extension ({ txt = "firmware"; loc }, payload), Some name ->
            { binding with
              pvb_expr = catching ~loc (fun () -> expand ~env ~name ~loc payload)
            }
          | _ -> { binding with pvb_expr = misplaced#expression binding.pvb_expr })
      in
      (* a name in an [and] group would be looked up past its siblings, so only a lone
         binding is followed *)
      let env =
        let opaque () =
          List.concat_map bindings ~f:(fun binding ->
            List.map (names_in binding.pvb_pat) ~f:(fun name -> Binding.Opaque name))
          @ env
        in
        match bindings with
        | [ binding ] ->
          (match bound_name binding.pvb_pat with
           | Some name -> Binding.Let (name, binding.pvb_expr) :: env
           | None -> opaque ())
        | _ -> opaque ()
      in
      env, { item with pstr_desc = Pstr_value (Nonrecursive, bindings) }
    | Pstr_value (Recursive, bindings) ->
      ( List.concat_map bindings ~f:(fun binding ->
          List.map (names_in binding.pvb_pat) ~f:(fun name -> Binding.Opaque name))
        @ env
      , misplaced#structure_item item )
    | Pstr_primitive { pval_name = { txt; loc = _ }; _ } ->
      Opaque txt :: env, misplaced#structure_item item
    | Pstr_open _ | Pstr_include _ -> Open :: env, misplaced#structure_item item
    | Pstr_module { pmb_name = { txt = Some name; loc = _ }; _ } ->
      Module name :: env, misplaced#structure_item item
    | Pstr_recmodule bindings ->
      ( List.filter_map bindings ~f:(fun binding ->
          Option.map binding.pmb_name.txt ~f:(fun name -> Binding.Module name))
        @ env
      , misplaced#structure_item item )
    | _ -> env, misplaced#structure_item item)
;;

let () = Driver.register_transformation "firmware" ~impl:structure
