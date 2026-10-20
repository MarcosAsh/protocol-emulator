open! Core
open! Hardcaml

module Bit = struct
  type t =
    | Zero
    | One
    | Data of
        { index : int
        ; inverted : bool
        }
    | Unknown
  [@@deriving compare, equal, sexp_of]

  let to_string = function
    | Zero -> "0"
    | One -> "1"
    | Data { index; inverted = false } -> [%string "d%{index#Int}"]
    | Data { index; inverted = true } -> [%string "~d%{index#Int}"]
    | Unknown -> "x"
  ;;

  let of_bool b = if b then One else Zero

  let not_ = function
    | Zero -> One
    | One -> Zero
    | Data d -> Data { d with inverted = not d.inverted }
    | Unknown -> Unknown
  ;;

  let is_complement a b = equal a (not_ b) && not (equal a Unknown)

  let and_ a b =
    match a, b with
    | Zero, _ | _, Zero -> Zero
    | One, x | x, One -> x
    | a, b when equal a b -> a
    | a, b when is_complement a b -> Zero
    | _ -> Unknown
  ;;

  let or_ a b = not_ (and_ (not_ a) (not_ b))

  let xor a b =
    match a, b with
    | Zero, x | x, Zero -> x
    | One, x | x, One -> not_ x
    | a, b when equal a b -> Zero
    | a, b when is_complement a b -> One
    | _ -> Unknown
  ;;

  let merge a b = if equal a b then a else Unknown
  let within a b = equal b Unknown || equal a b
end

module Value = struct
  type t = Bit.t array [@@deriving compare, equal, sexp_of]

  let of_bits b =
    Array.of_list_rev_map (Bits.bits_msb b) ~f:(fun b -> Bit.of_bool (Bits.to_bool b))
  ;;

  let unknown ~width = Array.create ~len:width Bit.Unknown

  let data ~width =
    Array.init width ~f:(fun index -> Bit.Data { index; inverted = false })
  ;;

  let to_bits t =
    Array.fold_right t ~init:(Some []) ~f:(fun bit acc ->
      match bit, acc with
      | Bit.Zero, Some acc -> Some (Bits.gnd :: acc)
      | One, Some acc -> Some (Bits.vdd :: acc)
      | _ -> None)
    |> Option.map ~f:(fun lsb_first -> Bits.concat_lsb lsb_first)
  ;;

  let is_known t =
    Array.for_all t ~f:(function
      | Bit.Zero | One -> true
      | Data _ | Unknown -> false)
  ;;

  let within a b = Array.for_all2_exn a b ~f:Bit.within

  let to_string t =
    match to_bits t with
    | Some bits -> Int.to_string (Bits.to_unsigned_int bits)
    | None ->
      Array.to_list t
      |> List.rev_map ~f:Bit.to_string
      |> String.concat ~sep:" "
      |> sprintf "{%s}"
  ;;

  let map2 a b ~f = Array.map2_exn a b ~f
  let merge = map2 ~f:Bit.merge
end

module Uid = Signal.Type.Uid

type t =
  { circuit : Circuit.t
  ; registers : Signal.t list
  ; describe : Signal.t -> string
  ; start : Signal.t -> Bits.t option
  }

let circuit t = t.circuit
let describe t = t.describe
let registers t = t.registers
let uid = Signal.uid

let default_describe (s : Signal.t) =
  match Signal.names s with
  | name :: _ -> name
  | [] -> Signal.Type.to_string s
;;

let create ?(describe = default_describe) ?(initial = fun _ -> None) circuit =
  let graph = Circuit.signal_graph circuit in
  let refusals =
    Signal_graph.filter graph ~f:(fun (s : Signal.t) ->
      match s with
      | Multiport_mem _ | Mem_read_port _ | Inst _ | Empty -> true
      | Reg { register = { clock = { clock_edge = Falling; _ }; _ }; _ } -> true
      | _ -> false)
    |> List.map ~f:(fun (s : Signal.t) ->
      let what =
        match s with
        | Multiport_mem _ | Mem_read_port _ -> "a memory"
        | Inst { instantiation; _ } -> "an instance of " ^ instantiation.circuit_name
        | Reg _ -> "a register on the falling edge"
        | _ -> "an empty signal"
      in
      Error.of_string [%string "%{describe s}: %{what} is outside the subset"])
  in
  let registers =
    Signal_graph.filter graph ~f:Signal.Type.is_reg
    |> List.sort ~compare:(Comparable.lift Uid.compare ~f:uid)
  in
  let clocks =
    List.map registers ~f:(fun (s : Signal.t) ->
      match s with
      | Reg { register = { clock = { clock; _ }; _ }; _ } -> uid clock
      | _ -> assert false)
    |> List.dedup_and_sort ~compare:Uid.compare
  in
  let clocks =
    match clocks with
    | [] | [ _ ] -> []
    | _ -> [ Error.of_string "registers on more than one clock are outside the subset" ]
  in
  match refusals @ clocks with
  | [] -> Ok { circuit; registers; describe; start = initial }
  | errors -> Error (Error.of_list errors)
;;

module State = struct
  type t = Value.t Map.M(Uid).t [@@deriving equal, sexp_of]

  let find t s = Map.find_exn t (uid s)
  let set t s value = Map.set t ~key:(uid s) ~data:value
  let merge a b = Map.mapi a ~f:(fun ~key ~data -> Value.merge data (Map.find_exn b key))

  let within a b =
    Map.for_alli a ~f:(fun ~key ~data -> Value.within data (Map.find_exn b key))
  ;;
end

let initial t =
  List.map t.registers ~f:(fun (s : Signal.t) ->
    let value =
      match s with
      | Reg { register = { initialize_to = Some bits; _ }; _ } -> Value.of_bits bits
      | _ ->
        Option.value_map
          (t.start s)
          ~default:(Value.unknown ~width:(Signal.width s))
          ~f:Value.of_bits
    in
    uid s, value)
  |> Map.of_alist_exn (module Uid)
;;

let known_op (op : Signal.Type.Op.t) a b =
  match op with
  | Add -> Bits.(a +: b)
  | Sub -> Bits.(a -: b)
  | Mulu -> Bits.(a *: b)
  | Muls -> Bits.(a *+ b)
  | And -> Bits.(a &: b)
  | Or -> Bits.(a |: b)
  | Xor -> Bits.(a ^: b)
  | Eq -> Bits.(a ==: b)
  | Lt -> Bits.(a <: b)
;;

let op2 (op : Signal.Type.Op.t) ~width a b =
  match Value.to_bits a, Value.to_bits b, op with
  | Some a, Some b, _ -> Value.of_bits (known_op op a b)
  | _, _, And -> Value.map2 a b ~f:Bit.and_
  | _, _, Or -> Value.map2 a b ~f:Bit.or_
  | _, _, Xor -> Value.map2 a b ~f:Bit.xor
  | _, _, Eq ->
    let differ = Array.exists2_exn a b ~f:(fun x y -> Bit.is_complement x y) in
    let same =
      Array.for_all2_exn a b ~f:(fun x y -> Bit.equal x y && not (Bit.equal x Unknown))
    in
    if differ then [| Bit.Zero |] else if same then [| Bit.One |] else [| Bit.Unknown |]
  | _ -> Value.unknown ~width
;;

let merge_all = function
  | [] -> assert false
  | v :: vs -> List.fold vs ~init:v ~f:Value.merge
;;

(* The value read through a mux's select, clamped to the last case as Hardcaml's is. *)
let pick cases select =
  List.nth_exn cases (Int.min (Bits.to_unsigned_int select) (List.length cases - 1))
;;

let input_name (s : Signal.t) = List.hd_exn (Signal.names s)

let evaluate state ~inputs =
  let memo = Hashtbl.create (module Uid) in
  let rec go (s : Signal.t) =
    match Hashtbl.find memo (uid s) with
    | Some v -> v
    | None ->
      let v = compute s in
      Hashtbl.set memo ~key:(uid s) ~data:v;
      v
  and compute (s : Signal.t) : Value.t =
    match s with
    | Const { constant; _ } -> Value.of_bits constant
    | Wire _ ->
      (match Signal.Type.wire_driver s with
       | Some d -> go d
       | None ->
         Option.value
           (inputs (input_name s))
           ~default:(Value.unknown ~width:(Signal.width s)))
    | Reg _ -> State.find state s
    | Op2 { op; arg_a; arg_b; _ } -> op2 op ~width:(Signal.width s) (go arg_a) (go arg_b)
    | Not { arg; _ } -> Array.map (go arg) ~f:Bit.not_
    | Select { arg; high; low; _ } -> Array.sub (go arg) ~pos:low ~len:(high - low + 1)
    | Cat { args; _ } -> List.rev_map args ~f:go |> Array.concat
    | Mux { select; cases; _ } ->
      (match Value.to_bits (go select) with
       | Some select -> go (pick cases select)
       | None -> merge_all (List.map cases ~f:go))
    | Cases { select; cases; default; _ } ->
      (match Value.to_bits (go select) with
       | Some select ->
         (match
            List.find cases ~f:(fun (k, _) ->
              Option.exists (Value.to_bits (go k)) ~f:(Bits.equal select))
          with
          | Some (_, value) -> go value
          | None -> go default)
       | None -> merge_all (go default :: List.map cases ~f:(fun (_, v) -> go v)))
    | Empty | Multiport_mem _ | Mem_read_port _ | Inst _ ->
      (* refused by [create] *)
      assert false
  in
  go
;;

(* [active] picks [taken] over [otherwise] when known, else merges them *)
let choose active ~taken ~otherwise =
  match active with
  | Bit.One -> taken ()
  | Zero -> otherwise ()
  | Data _ | Unknown -> Value.merge (taken ()) (otherwise ())
;;

let next_value go (s : Signal.t) ~current =
  match s with
  | Reg { register = { reset; clear; enable; _ }; d; _ } ->
    let enabled () =
      match enable with
      | None -> go d
      | Some e -> choose (go e).(0) ~taken:(fun () -> go d) ~otherwise:(fun () -> current)
    in
    let cleared () =
      match clear with
      | None -> enabled ()
      | Some { clear; clear_to } ->
        choose (go clear).(0) ~taken:(fun () -> go clear_to) ~otherwise:enabled
    in
    (match reset with
     | None -> cleared ()
     | Some { reset; reset_level; reset_to } ->
       let level = (go reset).(0) in
       let active =
         match reset_level with
         | High -> level
         | Low -> Bit.not_ level
       in
       choose active ~taken:(fun () -> go reset_to) ~otherwise:cleared)
  | _ -> assert false
;;

let step t state ~inputs =
  let go = evaluate state ~inputs in
  let outputs = List.map (Circuit.outputs t.circuit) ~f:(fun o -> input_name o, go o) in
  let next =
    List.map t.registers ~f:(fun r ->
      uid r, next_value go r ~current:(State.find state r))
    |> Map.of_alist_exn (module Uid)
  in
  outputs, next
;;

let cone _ (s : Signal.t) =
  let seen = Hash_set.create (module Uid) in
  let found = ref [] in
  let rec go (s : Signal.t) =
    if not (Hash_set.mem seen (uid s))
    then (
      Hash_set.add seen (uid s);
      match s with
      | Reg _ -> found := s :: !found
      | Wire _ when Option.is_none (Signal.Type.wire_driver s) -> found := s :: !found
      | _ -> Signal.Type.Deps.iter s ~f:go)
  in
  (match s with
   | Reg { register = { reset; clear; enable; _ }; d; _ } ->
     go d;
     Option.iter enable ~f:go;
     Option.iter clear ~f:(fun { clear; clear_to } ->
       go clear;
       go clear_to);
     Option.iter reset ~f:(fun { reset; reset_to; _ } ->
       go reset;
       go reset_to)
   | _ -> go s);
  List.rev !found
;;
