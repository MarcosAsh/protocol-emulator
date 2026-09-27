open! Core
open! Hardcaml
open Protocol_emulator

let timer_bits = Isa.timer_bits

module Fault = struct
  type t =
    | May_wrap of string
    | Signed_overflow of string
    | Unsigned_difference of string
    | Unsigned_timer of string
    | Not_a_difference of string
    | Two_sided of string
  [@@deriving compare, equal, sexp_of]
end

module Allowance = struct
  type t =
    { name : string
    ; circuit : string
    ; compare : string
    ; fault : Fault.t
    ; reason : string
    }
end

module Safe = struct
  type t =
    | Difference_against_constant
    | Wide_sum
  [@@deriving equal, sexp_of]
end

module Verdict = struct
  type t =
    | Safe of Safe.t
    | Allowed of (string * string) list
    | Flagged of Fault.t list
  [@@deriving sexp_of]
end

module Finding = struct
  type t =
    { at : string list
    ; compare : string
    ; verdict : Verdict.t
    }
  [@@deriving sexp_of]
end

let uid (s : Signal.t) = Signal.Type.Uid.to_int (Signal.uid s)

let rec behind_wires (s : Signal.t) =
  match Signal.Type.wire_driver s with
  | Some d -> behind_wires d
  | None -> s
;;

(* Hierarchy puts the instance path in front, after a [$]. *)
let short_name name =
  match String.rsplit2 name ~on:'$' with
  | Some (_, name) -> name
  | None -> name
;;

let name (s : Signal.t) =
  match s with
  | Const _ -> None
  | _ -> List.hd (Signal.names s) |> Option.map ~f:short_name
;;

let msb_of (s : Signal.t) =
  match s with
  | Select { arg; high; low; _ } when high = low && high = Signal.width arg - 1 ->
    Some arg
  | _ -> None
;;

let is_zero (s : Signal.t) =
  match behind_wires s with
  | Const { constant; _ } -> Bits.equal constant (Bits.zero (Bits.width constant))
  | _ -> false
;;

(* [t] is copies of [msb x], the way [repeat] builds them. *)
let rec copies_of_msb x (t : Signal.t) =
  match t with
  | Cat { args; _ } -> List.for_all args ~f:(copies_of_msb x)
  | t -> Option.exists (msb_of t) ~f:(fun a -> uid a = uid x)
;;

(* [uresize x] and [sresize x] put a constant zero, or copies of [msb x], above [x]. *)
let extended (s : Signal.t) =
  match s with
  | Cat { args = [ top; x ]; _ } -> Option.some_if (is_zero top || copies_of_msb x top) x
  | _ -> None
;;

(* [a <+ b] is [f a <: f b] with [f a = ~:(msb a) @: lsbs a], folded when [b] is a
   constant. *)
let unflipped (s : Signal.t) =
  match s with
  | Cat { args = [ Not { arg = top; _ }; Select { arg; high; low = 0; _ } ]; _ }
    when high = Signal.width arg - 2
         && Option.exists (msb_of top) ~f:(fun a -> uid a = uid arg) -> Some arg
  | _ -> None
;;

let unflip_constant (s : Signal.t) =
  match s with
  | Const { constant; _ } ->
    let sign = Bits.(vdd @: zero (width constant - 1)) in
    Some (Signal.of_bits Bits.(constant ^: sign))
  | _ -> None
;;

(* The largest unsigned value [s] can take, from its structure alone. *)
let full width = (1 lsl width) - 1

let bound =
  let memo = Hashtbl.create (module Int) in
  let rec bound (s : Signal.t) =
    let w = Signal.width s in
    if w >= Int.num_bits - 2
    then Int.max_value
    else (
      match Hashtbl.find memo (uid s) with
      | Some b -> b
      | None ->
        let b =
          match s with
          | Const { constant; _ } -> Bits.to_unsigned_int constant
          | Wire _ ->
            Option.value_map (Signal.Type.wire_driver s) ~default:(full w) ~f:bound
          | Cat { args; _ } ->
            List.fold args ~init:0 ~f:(fun acc a -> (acc lsl Signal.width a) + bound a)
          | Select { arg; low; _ } -> Int.min (bound arg lsr low) (full w)
          | Mux { cases; _ } ->
            List.map cases ~f:bound |> List.max_elt ~compare |> Option.value ~default:0
          | Op2 { op = Add; arg_a; arg_b; _ } ->
            Int.min (bound arg_a + bound arg_b) (full w)
          | Op2 { op = And; arg_a; arg_b; _ } -> Int.min (bound arg_a) (bound arg_b)
          | _ -> full w
        in
        Hashtbl.set memo ~key:(uid s) ~data:b;
        b)
  in
  bound
;;

let may_carry (s : Signal.t) =
  match s with
  | Op2 { op = Add; arg_a; arg_b; _ } ->
    let w = Signal.width s in
    w < Int.num_bits - 2 && bound arg_a + bound arg_b > full w
  | _ -> false
;;

(* The outermost sum in [s] that may carry out of its width, through the muxes and resizes
   between them. A difference is modular on purpose, so it is not looked into. *)
let rec wrapping_sum (s : Signal.t) =
  let d = behind_wires s in
  match d with
  | Op2 { op = Add; arg_a; arg_b; _ } ->
    if may_carry d
    then Some d
    else (
      match wrapping_sum arg_a with
      | Some sum -> Some sum
      | None -> wrapping_sum arg_b)
  | Mux { cases; _ } -> List.find_map cases ~f:wrapping_sum
  | _ -> Option.bind (extended d) ~f:wrapping_sum
;;

let rec touches_timer (s : Signal.t) =
  let d = behind_wires s in
  Signal.width d = timer_bits
  ||
  match d with
  | Mux { cases; _ } -> List.exists cases ~f:touches_timer
  | Op2 { op = Add | Sub; arg_a; arg_b; _ } -> touches_timer arg_a || touches_timer arg_b
  | _ -> Option.exists (extended d) ~f:touches_timer
;;

(* What an operand can be, through wires, muxes and resizes. *)
let rec sources (s : Signal.t) =
  let d = behind_wires s in
  match d with
  | Mux { cases; _ } -> List.concat_map cases ~f:sources
  | Const _ | Op2 { op = Add | Sub; _ } -> [ d ]
  | _ ->
    (match extended d with
     | Some x -> sources x
     | None -> [ s ])
;;

module Text = struct
  type t =
    | Atom of string
    | Infix of string * string (** the operator, and the whole *)

  let hole = Atom "_"

  let is_hole t =
    match t with
    | Atom "_" -> true
    | _ -> false
  ;;

  let to_string t =
    match t with
    | Atom s | Infix (_, s) -> s
  ;;

  let operand t =
    match t with
    | Atom s -> s
    | Infix (_, s) -> "(" ^ s ^ ")"
  ;;

  (* Hardcaml's infix operators associate to the left, so a chain of sums needs no
     parentheses on its left. *)
  let left_operand ~op t =
    let additive op = List.mem [ "+:"; "-:" ] op ~equal:String.equal in
    match t with
    | Infix (inner, s) when String.equal inner op || (additive inner && additive op) -> s
    | t -> operand t
  ;;
end

let operator (op : Signal.Type.Op.t) =
  match op with
  | Add -> "+:"
  | Sub -> "-:"
  | Mulu -> "*:"
  | Muls -> "*+"
  | And -> "&:"
  | Or -> "|:"
  | Xor -> "^:"
  | Eq -> "==:"
  | Lt -> "<:"
;;

(* Names, constants and arithmetic to [depth] operators down; a mux shows its cases, not
   the control that picks one, and anything with nothing to show is [_]. *)
let rec text ~depth (s : Signal.t) : Text.t =
  let under ~f args =
    let args = List.map args ~f:(text ~depth:(depth - 1)) in
    if List.for_all args ~f:Text.is_hole then Text.hole else f args
  in
  let call fn args = Text.Atom (fn ^ "(" ^ String.concat ~sep:", " args ^ ")") in
  match s, name s, extended s with
  | Const { constant; _ }, _, _ ->
    if Bits.width constant >= Int.num_bits - 2
    then Text.hole
    else (
      let v = Bits.to_unsigned_int constant in
      Atom (if v < 1024 then Int.to_string v else sprintf "0x%x" v))
  | _, Some name, _ -> Atom name
  | Wire _, None, _ ->
    Option.value_map (Signal.Type.wire_driver s) ~default:Text.hole ~f:(text ~depth)
  | Cat { args = top :: _; _ }, None, Some x ->
    (* A resize costs no depth, since it only says the width, and a narrower value shows
       only by name. *)
    let resize = if is_zero top then "uresize" else "sresize" in
    let depth = if Signal.width x < timer_bits then 0 else depth in
    (match text ~depth x with
     | Atom "_" -> Text.hole
     | x -> call resize [ Text.to_string x; Int.to_string (Signal.width s) ])
  | _ when depth = 0 -> Text.hole
  | _ ->
    (match msb_of s, s with
     | Some x, _ ->
       under [ x ] ~f:(fun args -> call "msb" [ Text.to_string (List.hd_exn args) ])
     | None, Op2 { op; arg_a; arg_b; _ } ->
       let op = operator op in
       under [ arg_a; arg_b ] ~f:(fun args ->
         match args with
         | [ a; b ] ->
           Infix (op, sprintf "%s %s %s" (Text.left_operand ~op a) op (Text.operand b))
         | _ -> assert false)
     | None, Not { arg; _ } ->
       under [ arg ] ~f:(fun args -> Atom ("~:" ^ Text.operand (List.hd_exn args)))
     | None, Select { arg; high; low; _ } ->
       under [ arg ] ~f:(fun args ->
         Atom (sprintf "%s[%d:%d]" (Text.operand (List.hd_exn args)) high low))
     | None, Mux { select; cases; _ } ->
       let select =
         match text ~depth:1 select with
         | Atom _ as select -> select
         | Infix _ -> Text.hole
       in
       let cases =
         match cases with
         | [ f; t ] -> [ t; f ]
         | cases -> cases
       in
       under cases ~f:(fun cases ->
         call
           (if List.length cases = 2 then "mux2" else "mux")
           (List.map (select :: cases) ~f:Text.to_string))
     | None, Cat { args; _ } ->
       under args ~f:(fun args ->
         Infix ("@:", String.concat ~sep:" @: " (List.map args ~f:Text.operand)))
     | None, _ -> Text.hole)
;;

let render s = Text.to_string (text ~depth:6 s)

module Compare = struct
  type t =
    | Unsigned of Signal.t * Signal.t
    | Signed of Signal.t * Signal.t
    | Equal of Signal.t * Signal.t
    | Sign of Signal.t

  (* shallower than a fault, which shows what is wrong in full *)
  let to_string t =
    let operand s = Text.operand (text ~depth:5 s) in
    match t with
    | Unsigned (a, b) -> operand a ^ " <: " ^ operand b
    | Equal (a, b) -> operand a ^ " ==: " ^ operand b
    | Sign x -> "msb(" ^ Text.to_string (text ~depth:5 x) ^ ")"
    | Signed (a, b) ->
      let signed (s : Signal.t) =
        match s with
        | Const { constant; _ } -> Int.to_string (Bits.to_signed_int constant)
        | s -> operand s
      in
      signed a ^ " <+ " ^ signed b
  ;;

  let operands t =
    match t with
    | Unsigned (a, b) | Signed (a, b) | Equal (a, b) -> [ a; b ]
    | Sign x -> [ x ]
  ;;
end

let all_constant s =
  List.for_all (sources s) ~f:(fun (s : Signal.t) ->
    match s with
    | Const _ -> true
    | _ -> false)
;;

let half width = 1 lsl (width - 1)

(* The differences a sum adds up, through the muxes, resizes and sums under it. *)
let rec differences_in (sum : Signal.t) =
  match sum with
  | Op2 { op = Add; arg_a; arg_b; _ } ->
    List.concat_map
      (sources arg_a @ sources arg_b)
      ~f:(fun (s : Signal.t) ->
        match s with
        | Op2 { op = Sub; _ } -> [ s ]
        | Op2 { op = Add; _ } -> differences_in s
        | _ -> [])
  | _ -> []
;;

(* A sum is a count: it must not wrap, nor add up a difference, which may be negative, and
   where it is [signed] it must stay below its sign bit. *)
let count_faults ~signed (sum : Signal.t) : Fault.t list =
  List.concat
    [ Option.value_map (wrapping_sum sum) ~default:[] ~f:(fun wraps ->
        [ Fault.May_wrap (render wraps) ])
    ; List.map (differences_in sum) ~f:(fun d -> Fault.Unsigned_difference (render d))
    ; (if signed && (not (may_carry sum)) && bound sum >= half (Signal.width sum)
       then [ Signed_overflow (render sum) ]
       else [])
    ]
;;

(* An operand compared as unsigned, or either side of an equality of two values, is a
   count, and anything in it but a sum or a constant is [raw]. *)
let as_count ~raw s =
  List.concat_map (sources s) ~f:(fun (source : Signal.t) ->
    match source with
    | Const _ -> []
    | Op2 { op = Sub; _ } -> [ Fault.Unsigned_difference (render source) ]
    | Op2 { op = Add; _ } -> count_faults ~signed:false source
    | _ -> [ raw (render source) ])
;;

(* A value compared against a constant, or tested by its sign. A difference of two timer
   values wraps on purpose, so it needs nothing more; a difference with a constant is a
   threshold on its other side, which is judged as the value would be; a sum is a count. *)
let rec against_constant ~signed s : Safe.t list * Fault.t list =
  let judged =
    List.map (sources s) ~f:(fun (source : Signal.t) ->
      match source with
      | Const _ -> [], []
      | Op2 { op = Sub; arg_a; arg_b; _ } ->
        (match all_constant arg_a, all_constant arg_b with
         | true, true -> [], []
         | false, false -> [ Safe.Difference_against_constant ], []
         | true, false -> against_constant ~signed arg_b
         | false, true -> against_constant ~signed arg_a)
      | Op2 { op = Add; _ } -> [ Wide_sum ], count_faults ~signed source
      | _ -> [], [ Not_a_difference (render source) ])
  in
  List.concat_map judged ~f:fst, List.concat_map judged ~f:snd
;;

(* The faults of a compare, none when it is safe for the reason given. *)
let judge (compare : Compare.t) =
  let against_constant ~signed x : Safe.t * Fault.t list =
    let safe, faults = against_constant ~signed x in
    ( (if List.mem safe Wide_sum ~equal:Safe.equal
       then Wide_sum
       else Difference_against_constant)
    , faults )
  in
  let other_than_constant a b =
    if all_constant a then Some b else if all_constant b then Some a else None
  in
  let two_sided = Fault.Two_sided (Compare.to_string compare) in
  let safe, faults =
    match compare with
    | Unsigned (a, b) ->
      ( Safe.Wide_sum
      , List.concat_map [ a; b ] ~f:(as_count ~raw:(fun s -> Unsigned_timer s)) )
    | Sign x -> against_constant ~signed:true x
    | Signed (a, b) ->
      (match other_than_constant a b with
       | Some x -> against_constant ~signed:true x
       | None -> Wide_sum, [ two_sided ])
    | Equal (a, b) ->
      (match other_than_constant a b with
       | Some x -> against_constant ~signed:false x
       | None ->
         Wide_sum, List.concat_map [ a; b ] ~f:(as_count ~raw:(fun _ -> two_sided)))
  in
  safe, List.dedup_and_sort faults ~compare:Fault.compare
;;

let compares circuit =
  let fan_out = Signal_graph.fan_out_map (Circuit.signal_graph circuit) in
  let signals = Circuit.signal_map circuit in
  let consumers (s : Signal.t) =
    Map.find fan_out (Signal.uid s)
    |> Option.value_map ~default:[] ~f:Set.to_list
    |> List.filter_map ~f:(Map.find signals)
  in
  (* The sign bit [s] of [x] is not a test where it only goes into a sign extension of
     [x], into the flip that [<+] makes of [x] for [<:], or into a reordering of all the
     bits of [x]. *)
  let untested (s : Signal.t) x =
    let is_x (a : Signal.t) = uid a = uid x in
    let rec into_extension (c : Signal.t) =
      Option.exists (extended c) ~f:is_x
      || (copies_of_msb x c && List.for_all (consumers c) ~f:into_extension)
    in
    let is_lt (c : Signal.t) =
      match c with
      | Op2 { op = Lt; _ } -> true
      | _ -> false
    in
    let into_flip (c : Signal.t) =
      match c with
      | Not _ ->
        List.for_all (consumers c) ~f:(fun flipped ->
          Option.exists (unflipped flipped) ~f:is_x
          && List.for_all (consumers flipped) ~f:is_lt)
      | _ -> false
    in
    let reorders (c : Signal.t) =
      match c with
      | Cat { args; _ } ->
        let bits (a : Signal.t) =
          match a with
          | Select { arg; high; low; _ } when is_x arg -> Some (List.range low (high + 1))
          | _ -> None
        in
        (match Option.all (List.map args ~f:bits) with
         | Some bits ->
           [%equal: int list]
             (List.sort (List.concat bits) ~compare)
             (List.range 0 (Signal.width x))
         | None -> false)
      | _ -> false
    in
    List.for_all (consumers s) ~f:(fun c -> into_extension c || into_flip c || reorders c)
  in
  let found =
    Map.data signals
    |> List.filter_map ~f:(fun (s : Signal.t) ->
      let compare : Compare.t option =
        match s with
        | Op2 { op = Lt; arg_a; arg_b; _ } ->
          (match unflipped arg_a, unflipped arg_b with
           | Some a, Some b -> Some (Signed (a, b))
           | Some a, None ->
             Some
               (Option.value_map
                  (unflip_constant arg_b)
                  ~default:(Compare.Unsigned (arg_a, arg_b))
                  ~f:(fun b -> Signed (a, b)))
           | None, Some b ->
             Some
               (Option.value_map
                  (unflip_constant arg_a)
                  ~default:(Compare.Unsigned (arg_a, arg_b))
                  ~f:(fun a -> Signed (a, b)))
           | None, None -> Some (Unsigned (arg_a, arg_b)))
        | Op2 { op = Eq; arg_a; arg_b; _ } ->
          let arithmetic x =
            List.exists (sources x) ~f:(fun (s : Signal.t) ->
              match s with
              | Op2 { op = Add | Sub; _ } -> true
              | _ -> false)
          in
          Option.some_if
            (arithmetic arg_a || arithmetic arg_b)
            (Compare.Equal (arg_a, arg_b))
        | Select _ ->
          Option.bind (msb_of s) ~f:(fun x ->
            Option.some_if (not (untested s x)) (Compare.Sign x))
        | _ -> None
      in
      Option.bind compare ~f:(fun compare ->
        Option.some_if
          (List.exists (Compare.operands compare) ~f:touches_timer)
          (s, compare)))
  in
  (* the named signals a compare first reaches *)
  let at (s : Signal.t) =
    let seen = Hash_set.create (module Int) in
    let rec go (s : Signal.t) =
      if Hash_set.mem seen (uid s)
      then []
      else (
        Hash_set.add seen (uid s);
        match name s with
        | Some name -> [ name ]
        | None -> List.concat_map (consumers s) ~f:go)
    in
    let reached =
      match name s with
      | Some name -> [ name ]
      | None -> List.concat_map (consumers s) ~f:go
    in
    List.dedup_and_sort reached ~compare:String.compare
  in
  List.map found ~f:(fun (s, compare) -> at s, compare)
;;

let print ?(allow = []) circuits =
  let used = Hash_set.create (module String) in
  let audit =
    List.filter_map circuits ~f:(fun circuit ->
      let circuit_name = Circuit.name circuit in
      let findings =
        compares circuit
        |> List.map ~f:(fun (at, compare) ->
          let shown = Compare.to_string compare in
          let verdict : Verdict.t =
            match judge compare with
            | safe, [] -> Safe safe
            | _, faults ->
              let allowance (fault : Fault.t) =
                List.find allow ~f:(fun (a : Allowance.t) ->
                  String.equal a.circuit circuit_name
                  && String.equal a.compare shown
                  && Fault.equal a.fault fault)
              in
              (match List.filter faults ~f:(fun f -> Option.is_none (allowance f)) with
               | [] ->
                 let allowances = List.filter_map faults ~f:allowance in
                 List.iter allowances ~f:(fun a -> Hash_set.add used a.name);
                 Allowed (List.map allowances ~f:(fun a -> a.name, a.reason))
               | flagged -> Flagged flagged)
          in
          { Finding.at; compare = shown; verdict })
        |> List.sort ~compare:(fun (a : Finding.t) b ->
          [%compare: string list * string] (a.at, a.compare) (b.at, b.compare))
      in
      Option.some_if (not (List.is_empty findings)) (circuit_name, findings))
  in
  let circuits = List.map circuits ~f:Circuit.name in
  print_s [%message (circuits : string list)];
  List.iter audit ~f:(fun (circuit, findings) ->
    print_s [%message circuit ~_:(findings : Finding.t list)]);
  let unused =
    List.filter_map allow ~f:(fun a ->
      Option.some_if
        (List.mem circuits a.circuit ~equal:String.equal && not (Hash_set.mem used a.name))
        a.name)
  in
  if not (List.is_empty unused)
  then print_s [%message "allowances that cover nothing" (unused : string list)]
;;
