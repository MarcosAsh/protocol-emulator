open! Core

module Parity = struct
  type t =
    | Even
    | Odd
  [@@deriving sexp_of, equal]
end

module Coding = struct
  type t =
    | Manchester of
        { one_starts_active : bool
        ; wide : int option
        ; hidden_half : bool
        }
    | Pulse of
        { zero : int * int
        ; one : int * int
        ; last_is_bit : bool
        }
    | Uart of
        { data_bits : int
        ; parity : Parity.t option
        ; stop_bits : int
        }
    | Clocked of
        { clock : string
        ; select : string option
        ; sample_rising : bool
        ; clock_idle : bool
        }
  [@@deriving sexp_of, equal]
end

module Run = struct
  type t =
    { active : bool
    ; units : int
    }
  [@@deriving sexp_of, compare, equal]
end

module Kind = struct
  type t =
    { leader : Run.t list
    ; bits : int
    ; trailer : Run.t list
    }
  [@@deriving sexp_of, compare, equal]
end

module Frame = struct
  type t =
    { kind : int
    ; bits : bool array
    ; at : float
    }
  [@@deriving sexp_of]
end

module Field = struct
  type t =
    { kind : int
    ; first : int
    ; width : int
    ; seen : int list
    }
  [@@deriving sexp_of]
end

type t =
  { line : string
  ; unit_s : float
  ; bias_s : float
  ; idle : bool
  ; coding : Coding.t
  ; lsb_first : bool
  ; kinds : Kind.t list
  ; gap : int
  ; frames : Frame.t list
  ; outliers : int
  ; rules : (int * (Learn_check.Rule.t * Learn_check.Evidence.t) list) list
  ; fields : Field.t list
  }
[@@deriving sexp_of]

(* A frame on one line: the sample of each edge, the first to the active level. *)
module Edges = struct
  type t = int array

  let runs (t : t) =
    List.init (Array.length t - 1) ~f:(fun j -> j % 2 = 0, t.(j + 1) - t.(j))
  ;;
end

let level_after (line : Recording.Line.t) j = Bool.( <> ) line.first (j % 2 = 0)

let idle_level (line : Recording.Line.t) =
  let n = Array.length line.edges in
  let last = Bool.( <> ) line.first (n % 2 = 1) in
  if Bool.equal line.first last
  then line.first
  else
    Recording.Line.runs line
    |> List.max_elt ~compare:(Comparable.lift Int.compare ~f:snd)
    |> Option.value_map ~default:line.first ~f:fst
;;

(* Where frames might end: past each jump of four times or more between idle runs in order
   of length, ignoring the shortest quarter, where glitches are. None when no idle run
   stands out, as in one long frame. *)
let gap_thresholds ~idle runs =
  let idles =
    List.filter_map runs ~f:(fun (level, n) -> Option.some_if (Bool.equal level idle) n)
    |> List.sort ~compare:Int.compare
    |> Array.of_list
  in
  let count = Array.length idles in
  match
    List.range (count / 4) (count - 1)
    |> List.filter ~f:(fun i -> 2 * idles.(i + 1) >= 7 * idles.(i))
    |> List.map ~f:(fun i ->
      Float.to_int (Float.sqrt (Float.of_int idles.(i) *. Float.of_int idles.(i + 1))) + 1)
  with
  | [] -> [ None ]
  | thresholds -> List.map thresholds ~f:Option.some
;;

let split_frames (line : Recording.Line.t) ~idle ~threshold =
  let edges = line.edges in
  let n = Array.length edges in
  let frames = ref [] in
  let current = ref [] in
  let flush () =
    (match List.rev !current with
     | [] | [ _ ] -> ()
     | frame -> frames := Array.of_list frame :: !frames);
    current := []
  in
  for j = 0 to n - 1 do
    let to_active = Bool.( <> ) (level_after line j) idle in
    (match !current with
     | [] -> if to_active then current := [ edges.(j) ]
     | last :: _ ->
       let gap = edges.(j) - last in
       if to_active && Option.value_map threshold ~default:false ~f:(fun t -> gap > t)
       then (
         flush ();
         current := [ edges.(j) ])
       else current := edges.(j) :: !current);
    ()
  done;
  flush ();
  (* a frame ends on its last edge back to idle *)
  List.rev !frames
  |> List.map ~f:(fun frame ->
    if Array.length frame % 2 = 1
    then Array.sub frame ~pos:0 ~len:(Array.length frame - 1)
    else frame)
  |> List.filter ~f:(fun frame -> Array.length frame >= 2)
;;

(* Clusters of lengths in order, a new one wherever a length is 30% past the last. *)
let clusters lengths =
  List.sort lengths ~compare:Float.compare
  |> List.fold ~init:[] ~f:(fun acc d ->
    match acc with
    | (last :: _ as c) :: rest when Float.( <= ) d (last *. 1.3) -> (d :: c) :: rest
    | _ -> [ d ] :: acc)
  |> List.rev_map ~f:List.rev
;;

let median l =
  let a = Array.of_list l in
  Array.sort a ~compare:Float.compare;
  a.(Array.length a / 2)
;;

let tolerance ~unit d = Float.max (0.3 *. unit) (0.08 *. d)

(* A unit, and how much longer than whole units an active run reads, and an idle one
   shorter, as a receiver module stretches its marks. Both in samples. *)
module Grid = struct
  type t =
    { unit : float
    ; bias : float
    }

  let corrected t ~active d = if active then d -. t.bias else d +. t.bias

  let units t ~active d =
    let c = corrected t ~active d in
    let k = Float.iround_nearest_exn (c /. t.unit) in
    if k >= 1
       && Float.( <= )
            (Float.abs (c -. (Float.of_int k *. t.unit)))
            (tolerance ~unit:t.unit c)
    then Some k
    else None
  ;;

  (* Least squares of each length as [k * unit + bias] or [k * unit - bias], rounding
     again each time; the bias is kept under half a unit. *)
  let refine t runs =
    Fn.apply_n_times
      ~n:6
      (fun t ->
        let sums =
          List.fold
            runs
            ~init:(0., 0., 0., 0., 0.)
            ~f:(fun (kk, ks, ss, kd, sd) (active, d) ->
              match units t ~active d with
              | Some k ->
                let k = Float.of_int k
                and s = if active then 1. else -1. in
                kk +. (k *. k), ks +. (k *. s), ss +. 1., kd +. (k *. d), sd +. (s *. d)
              | None -> kk, ks, ss, kd, sd)
        in
        let kk, ks, ss, kd, sd = sums in
        let det = (kk *. ss) -. (ks *. ks) in
        if Float.( <= ) kk 0.
        then t
        else if Float.( <= ) (Float.abs det) (1e-6 *. kk *. ss)
        then { unit = kd /. kk; bias = 0. }
        else (
          let unit = ((kd *. ss) -. (ks *. sd)) /. det in
          let bias = ((kk *. sd) -. (ks *. kd)) /. det in
          if Float.( > ) (Float.abs bias) (0.4 *. unit)
          then { unit = kd /. kk; bias = 0. }
          else { unit; bias }))
      t
  ;;
end

let fraction l ~f =
  if List.is_empty l
  then 1.
  else Float.of_int (List.count l ~f) /. Float.of_int (List.length l)
;;

(* The grid: the longest unit, from the shortest common run over 1 to 3, that puts every
   active run of three frames in four, and most idle runs, on whole units. A UART's idle
   runs between characters can be any length, and a receiver's glitches spoil a few
   frames, so neither has to fit. *)
let fit frames =
  let frames =
    List.map frames ~f:(List.map ~f:(fun (active, n) -> active, Float.of_int n))
  in
  let runs = List.concat frames in
  let lengths = List.map runs ~f:snd in
  let total = List.length lengths in
  let common =
    clusters lengths |> List.filter ~f:(fun c -> List.length c >= Int.max 2 (total / 100))
  in
  match common with
  | [] -> None
  | shortest :: _ ->
    let idle = List.filter runs ~f:(Fn.non fst) in
    (* from a few starts each, as rounding a long leader at a unit a few percent out holds
       the fit there; the least squared error in units wins *)
    let cost (grid : Grid.t) =
      List.sum (module Float) runs ~f:(fun (active, d) ->
        match Grid.units grid ~active d with
        | Some k ->
          let r =
            (Grid.corrected grid ~active d -. (Float.of_int k *. grid.unit)) /. grid.unit
          in
          r *. r
        | None -> 1.)
    in
    List.find_map [ 1.; 2.; 3. ] ~f:(fun n ->
      List.filter_map [ 0.88; 0.94; 1.; 1.06; 1.12 ] ~f:(fun f ->
        let grid = Grid.refine { unit = f *. median shortest /. n; bias = 0. } runs in
        let on_grid (active, d) = Option.is_some (Grid.units grid ~active d) in
        let clean frame =
          List.for_all frame ~f:(fun (active, d) -> (not active) || on_grid (active, d))
        in
        Option.some_if
          (Float.( >= ) (fraction frames ~f:clean) 0.75
           && Float.( >= ) (fraction idle ~f:on_grid) 0.6)
          (Grid.refine grid (List.concat (List.filter frames ~f:clean))))
      |> List.min_elt ~compare:(Comparable.lift Float.compare ~f:cost))
;;

let quantize grid runs =
  List.map runs ~f:(fun (active, d) ->
    Option.map
      (Grid.units grid ~active (Float.of_int d))
      ~f:(fun units -> { Run.active; units }))
  |> Option.all
;;

(* Manchester *)

module Manchester_shape = struct
  type t =
    { leader : int
    ; hidden_half : bool
    ; wide : int option
    }
end

let halves runs =
  List.concat_map runs ~f:(fun (r : Run.t) -> List.init r.units ~f:(fun _ -> r.active))
;;

(* The bits as first-half-active, or None; the last bit's trailing idle halves may be
   missing, as they run into the gap. *)
let manchester_bits (shape : Manchester_shape.t) (runs : Run.t list) =
  if List.length runs <= shape.leader
  then None
  else (
    let #(leader, data) = List.split_n runs shape.leader in
    let halves = (if shape.hidden_half then [ false ] else []) @ halves data in
    let rec go halves i acc =
      if List.is_empty halves
      then Some (List.rev acc)
      else (
        let w = if Option.equal Int.equal shape.wide (Some i) then 2 else 1 in
        let #(taken, rest) = List.split_n halves (2 * w) in
        let taken = taken @ List.init ((2 * w) - List.length taken) ~f:(fun _ -> false) in
        let #(first, second) = List.split_n taken w in
        let all_equal l v = List.for_all l ~f:(Bool.equal v) in
        let a = List.hd_exn first in
        let b = List.hd_exn second in
        if all_equal first a && all_equal second b && Bool.( <> ) a b
        then go rest (i + 1) (a :: acc)
        else None)
    in
    Option.map (go halves 0 []) ~f:(fun bits -> leader, bits))
;;

let manchester frames =
  let max_bits =
    List.fold frames ~init:0 ~f:(fun m runs -> Int.max m (List.length (halves runs)))
  in
  let shapes =
    List.concat_map [ 0; 1; 2; 3 ] ~f:(fun leader ->
      List.concat_map [ false; true ] ~f:(fun hidden_half ->
        List.map
          (None :: List.init (Int.min 64 (max_bits / 2)) ~f:Option.some)
          ~f:(fun wide -> { Manchester_shape.leader; hidden_half; wide })))
  in
  (* frames weighed by their runs, so short frames cannot carry a reading of long ones *)
  let scored =
    List.map shapes ~f:(fun shape ->
      ( shape
      , List.sum (module Int) frames ~f:(fun runs ->
          if Option.is_some (manchester_bits shape runs) then List.length runs else 0) ))
  in
  let total = List.sum (module Int) frames ~f:List.length in
  let best = List.fold scored ~init:0 ~f:(fun m (_, n) -> Int.max m n) in
  if best = 0 || Float.( < ) (Float.of_int best) (0.8 *. Float.of_int total)
  then None
  else List.find scored ~f:(fun (_, n) -> n = best) |> Option.map ~f:fst
;;

(* Pulse *)

let pairs (runs : Run.t list) =
  let rec go acc = function
    | (m : Run.t) :: (s : Run.t) :: rest -> go ((m.units, s.units) :: acc) rest
    | [ (m : Run.t) ] -> List.rev acc, Some m.units
    | [] -> List.rev acc, None
  in
  go [] runs
;;

let pulse_alphabet frames =
  let all = List.concat_map frames ~f:(fun runs -> fst (pairs runs)) in
  let counted =
    List.sort_and_group all ~compare:[%compare: int * int]
    |> List.map ~f:(fun g -> List.hd_exn g, List.length g)
    |> List.sort ~compare:(fun (_, a) (_, b) -> Int.compare b a)
  in
  match counted with
  | (a, na) :: (b, nb) :: _ ->
    let total = Float.of_int (List.length all) in
    if Float.( >= ) (Float.of_int (na + nb)) (0.5 *. total)
       && Float.( >= ) (Float.of_int nb) (0.05 *. total)
    then (
      let total (m, s) = m + s in
      let zero, one =
        if [%compare: int * int] (total a, fst a) (total b, fst b) <= 0
        then a, b
        else b, a
      in
      Some (zero, one))
    else None
  | _ -> None
;;

(* The longest stretch of data pairs, with what is before and after it. *)
let pulse_frame ~zero ~one (runs : Run.t list) =
  let ps, last = pairs runs in
  let is_bit p = [%equal: int * int] p zero || [%equal: int * int] p one in
  let arr = Array.of_list ps in
  let n = Array.length arr in
  let best = ref (0, 0) in
  let i = ref 0 in
  while !i < n do
    if is_bit arr.(!i)
    then (
      let j = ref !i in
      while !j < n && is_bit arr.(!j) do
        incr j
      done;
      if !j - !i > snd !best - fst !best then best := !i, !j;
      i := !j)
    else incr i
  done;
  let from, until = !best in
  let run active units = { Run.active; units } in
  let to_runs ps = List.concat_map ps ~f:(fun (m, s) -> [ run true m; run false s ]) in
  let leader = to_runs (Array.to_list (Array.sub arr ~pos:0 ~len:from)) in
  let bits =
    Array.sub arr ~pos:from ~len:(until - from)
    |> Array.map ~f:(fun p -> [%equal: int * int] p one)
  in
  let after = to_runs (Array.to_list (Array.sub arr ~pos:until ~len:(n - until))) in
  leader, bits, after, last
;;

(* UART: chars read from each start edge. [level_at] gives the line at a sample. *)

let uart_chars ~unit ~idle ~bits ~level_at (frame : Edges.t) =
  let last = frame.(Array.length frame - 1) in
  let sample t i =
    level_at
      (Float.iround_nearest_exn (Float.of_int t +. ((Float.of_int i +. 0.5) *. unit)))
  in
  let rec go j acc =
    if j >= Array.length frame
    then Some (List.rev acc)
    else (
      let start = frame.(j) in
      let read = List.init (bits + 2) ~f:(fun i -> Bool.( <> ) (sample start i) idle) in
      let start_bit = List.hd_exn read in
      let stop = List.last_exn read in
      if (not start_bit) || stop
      then None
      else (
        let char = List.sub read ~pos:1 ~len:bits in
        let stop_at = Float.of_int start +. ((Float.of_int bits +. 1.5) *. unit) in
        match
          Array.findi frame ~f:(fun k e -> k > j && Float.( > ) (Float.of_int e) stop_at)
        with
        | None ->
          if Float.( >= ) stop_at (Float.of_int last)
          then go (Array.length frame) (char :: acc)
          else None
        | Some (k, _) ->
          (* the next edge after the stop must start a char *)
          if (k - j) % 2 = 0 then go k (char :: acc) else None))
  in
  go 0 []
;;

let parity_of bits = List.count bits ~f:Fn.id % 2 = 1

(* Clocked *)

let near sorted e =
  match Array.binary_search sorted ~compare `Last_less_than_or_equal_to e with
  | None -> Array.get sorted 0 - e |> Int.abs
  | Some i ->
    let before = e - sorted.(i) in
    if i + 1 < Array.length sorted then Int.min before (sorted.(i + 1) - e) else before
;;

(* Reports *)

let rule_targets t ~kind =
  let bits = (List.nth_exn t.kinds kind).bits in
  List.Assoc.find t.rules kind ~equal:Int.equal
  |> Option.value ~default:[]
  |> List.concat_map ~f:(fun (rule, _) -> Learn_check.Rule.targets rule ~frame_bits:bits)
;;

let field_value t (field : Field.t) bits =
  List.init field.width ~f:Fn.id
  |> List.fold ~init:0 ~f:(fun acc i ->
    let bit = Bool.to_int bits.(field.first + i) in
    if t.lsb_first then acc lor (bit lsl i) else (acc lsl 1) lor bit)
;;

let rules_of t ~kind =
  List.Assoc.find t.rules kind ~equal:Int.equal
  |> Option.value ~default:[]
  |> List.map ~f:fst
;;

let with_checks t ~kind bits = Learn_check.apply (rules_of t ~kind) bits

let with_field t (field : Field.t) bits value =
  let bits = Array.copy bits in
  for i = 0 to field.width - 1 do
    let shift = if t.lsb_first then i else field.width - 1 - i in
    bits.(field.first + i) <- (value lsr shift) land 1 = 1
  done;
  Learn_check.apply (rules_of t ~kind:field.kind) bits
;;

let fields_of t =
  List.concat_mapi t.kinds ~f:(fun kind (k : Kind.t) ->
    let frames = List.filter t.frames ~f:(fun f -> f.kind = kind) in
    match frames with
    | [] -> []
    | first :: _ ->
      let targets = rule_targets t ~kind in
      let varying i =
        (not (List.mem targets i ~equal))
        && List.exists frames ~f:(fun f -> Bool.( <> ) f.bits.(i) first.bits.(i))
      in
      let rec runs i acc =
        if i >= k.bits
        then List.rev acc
        else if varying i
        then (
          let j = ref i in
          (* fields of whole bytes do not run across a byte's end *)
          let bytes = k.bits % 8 = 0 in
          while !j < k.bits && varying !j && not (bytes && !j > i && !j % 8 = 0) do
            incr j
          done;
          runs !j ((i, !j - i) :: acc))
        else runs (i + 1) acc
      in
      List.map (runs 0 []) ~f:(fun (first, width) ->
        let field = { Field.kind; first; width; seen = [] } in
        { field with
          seen =
            List.map frames ~f:(fun f -> field_value t field f.bits)
            |> List.dedup_and_sort ~compare
        }))
;;

(* Kinds seen once among four or more frames, where another is seen again, are outliers. *)
let assign_kinds (decoded : (Kind.t * bool array * float) list) =
  let counts =
    List.sort_and_group decoded ~compare:(fun (a, _, _) (b, _, _) -> Kind.compare a b)
    |> List.map ~f:(fun g ->
      let k, _, _ = List.hd_exn g in
      k, List.length g)
  in
  let repeated = List.exists counts ~f:(fun (_, n) -> n >= 2) in
  let keep (_, n) = n >= 2 || (not repeated) || List.length decoded < 4 in
  let kinds = List.filter counts ~f:keep |> List.map ~f:fst in
  let frames =
    List.filter_map decoded ~f:(fun (k, bits, at) ->
      List.findi kinds ~f:(fun _ x -> Kind.equal x k)
      |> Option.map ~f:(fun (kind, _) -> { Frame.kind; bits; at }))
  in
  kinds, frames, List.length decoded - List.length frames
;;

(* [seen] counts the frames before any failed to read, so those count as outliers too. *)
let finish ~line ~unit_s ?(bias_s = 0.) ~idle ~coding ~lsb_first ~gap ~seen decoded =
  let kinds, frames, outliers = assign_kinds decoded in
  let outliers = outliers + seen - List.length decoded in
  let all_bits = List.concat_map frames ~f:(fun f -> Array.to_list f.bits) in
  if List.length all_bits >= 16
     && (List.for_all all_bits ~f:Fn.id || List.for_all all_bits ~f:not)
  then
    Or_error.error_s
      [%message "unknown: every bit reads the same, as a clock or carrier would" ~line]
  else if outliers * 3 > seen
  then
    Or_error.error_s
      [%message
        "unknown: over a third of the frames read no way seen twice"
          (outliers : int)
          (seen : int)]
  else (
    let rules =
      List.filter_mapi kinds ~f:(fun kind (k : Kind.t) ->
        let bits =
          List.filter_map frames ~f:(fun f -> Option.some_if (f.kind = kind) f.bits)
        in
        if k.bits = 0
        then None
        else (
          match Learn_check.find ~lsb_first bits with
          | [] -> None
          | found -> Some (kind, found)))
    in
    let t =
      { line
      ; unit_s
      ; bias_s
      ; idle
      ; coding
      ; lsb_first
      ; kinds
      ; gap
      ; frames
      ; outliers
      ; rules
      ; fields = []
      }
    in
    Ok { t with fields = fields_of t })
;;

let least_gap ~unit frames =
  List.zip_exn (List.drop frames 1) (List.take frames (List.length frames - 1))
  |> List.map ~f:(fun (b, a) -> a, b)
  |> List.map ~f:(fun ((a : Edges.t), (b : Edges.t)) ->
    Float.of_int (b.(0) - a.(Array.length a - 1)) /. unit)
  |> List.min_elt ~compare:Float.compare
  |> Option.value_map ~default:0 ~f:Float.iround_down_exn
;;

let learn_split ~rate ~idle ~threshold (line : Recording.Line.t) =
  let frames = split_frames line ~idle ~threshold in
  let at (frame : Edges.t) = Float.of_int frame.(0) /. rate in
  match frames, fit (List.map frames ~f:Edges.runs) with
  | [], _ -> Or_error.error_s [%message "unknown: no frames" ~line:line.name]
  | _, None ->
    Or_error.error_s [%message "unknown: no unit puts the runs on a grid" ~line:line.name]
  | _, Some grid ->
    let unit = grid.unit in
    let unit_s = unit /. rate in
    let bias_s = grid.bias /. rate in
    let gap = least_gap ~unit frames in
    let quantized = List.map frames ~f:(fun f -> f, quantize grid (Edges.runs f)) in
    let whole =
      List.filter_map quantized ~f:(fun (f, q) -> Option.map q ~f:(fun q -> f, q))
    in
    let line_name = line.name in
    let try_manchester () =
      if List.length whole * 3 < List.length frames * 2
      then None
      else
        Option.bind
          (manchester (List.map whole ~f:snd))
          ~f:(fun shape ->
            let decoded =
              List.filter_map whole ~f:(fun (f, runs) ->
                Option.map (manchester_bits shape runs) ~f:(fun (leader, bits) ->
                  f, leader, bits))
            in
            let firsts = List.map decoded ~f:(fun (_, _, bits) -> List.hd_exn bits) in
            (* one is whichever way round makes most frames start with 1 *)
            let one_starts_active =
              List.count firsts ~f:Fn.id * 2 >= List.length firsts
            in
            let decoded =
              List.map decoded ~f:(fun (f, leader, bits) ->
                ( { Kind.leader; bits = List.length bits; trailer = [] }
                , Array.of_list_map bits ~f:(Bool.equal one_starts_active)
                , at f ))
            in
            Some
              (finish
                 ~line:line_name
                 ~unit_s
                 ~bias_s
                 ~idle
                 ~coding:
                   (Manchester
                      { one_starts_active
                      ; wide = shape.wide
                      ; hidden_half = shape.hidden_half
                      })
                 ~lsb_first:false
                 ~gap
                 ~seen:(List.length frames)
                 decoded))
    in
    let try_pulse () =
      if List.length whole * 3 < List.length frames * 2
      then None
      else
        Option.bind
          (pulse_alphabet (List.map whole ~f:snd))
          ~f:(fun (zero, one) ->
            let width_coded = fst zero <> fst one && snd zero = snd one in
            let parsed =
              List.map whole ~f:(fun (f, runs) ->
                let leader, bits, after, last = pulse_frame ~zero ~one runs in
                let last_is_bit =
                  width_coded
                  && List.is_empty after
                  && Array.length bits > 0
                  && Option.exists last ~f:(fun m -> m = fst zero || m = fst one)
                in
                let bits, trailer =
                  if last_is_bit
                  then Array.append bits [| Option.value_exn last = fst one |], []
                  else
                    ( bits
                    , after
                      @ Option.value_map last ~default:[] ~f:(fun units ->
                        [ { Run.active = true; units } ]) )
                in
                f, leader, bits, trailer, last_is_bit)
            in
            let covered =
              List.sum (module Int) parsed ~f:(fun (_, _, bits, _, _) ->
                Array.length bits)
            in
            let pairs =
              List.sum (module Int) whole ~f:(fun (_, runs) -> List.length runs / 2)
            in
            let last_is_bit = List.exists parsed ~f:(fun (_, _, _, _, last) -> last) in
            if covered * 10 < pairs * 6
            then None
            else
              Some
                (finish
                   ~line:line_name
                   ~unit_s
                   ~bias_s
                   ~idle
                   ~coding:(Pulse { zero; one; last_is_bit })
                   ~lsb_first:true
                   ~gap
                   ~seen:(List.length frames)
                   (List.map parsed ~f:(fun (f, leader, bits, trailer, _) ->
                      { Kind.leader; bits = Array.length bits; trailer }, bits, at f))))
    in
    let try_uart () =
      let level_at at = Recording.Line.level_at line (at + 1) in
      List.find_map (List.range 6 12) ~f:(fun length ->
        let bits = length - 1 in
        let read =
          List.map frames ~f:(fun f -> f, uart_chars ~unit ~idle ~bits ~level_at f)
        in
        if List.exists read ~f:(fun (_, r) -> Option.is_none r)
        then None
        else (
          let chars = List.concat_map read ~f:(fun (_, r) -> Option.value_exn r) in
          (* a carrier or a clock reads as one character over and over *)
          let commonest =
            List.sort_and_group chars ~compare:[%compare: bool list]
            |> List.fold ~init:0 ~f:(fun m g -> Int.max m (List.length g))
          in
          if commonest * 5 > List.length chars * 3
          then None
          else (
            let parity =
              if List.length chars < 8 || bits - 1 < 5
              then None
              else
                List.find [ Parity.Even; Odd ] ~f:(fun p ->
                  List.for_all chars ~f:(fun c ->
                    Bool.equal (parity_of (List.map c ~f:not)) (Parity.equal p Odd)))
            in
            let data_bits = if Option.is_some parity then bits - 1 else bits in
            Some
              (finish
                 ~line:line_name
                 ~unit_s
                 ~bias_s
                 ~idle
                 ~coding:(Uart { data_bits; parity; stop_bits = 1 })
                 ~lsb_first:true
                 ~gap
                 ~seen:(List.length frames)
                 (List.map read ~f:(fun (f, r) ->
                    let chars = Option.value_exn r in
                    let payload =
                      List.concat_map chars ~f:(fun c ->
                        List.map (List.take c data_bits) ~f:not)
                    in
                    ( { Kind.leader = []; bits = List.length payload; trailer = [] }
                    , Array.of_list payload
                    , at f )))))))
    in
    let tried =
      List.filter_map [ try_manchester; try_pulse; try_uart ] ~f:(fun f -> f ())
    in
    (match List.find tried ~f:Result.is_ok, tried with
     | Some result, _ | None, result :: _ -> result
     | None, [] ->
       Or_error.error_s
         [%message
           "unknown: no coding reads the frames"
             ~line:line.name
             ~unit_us:(unit_s *. 1e6 : float)
             ~frames:(List.length frames : int)])
;;

(* Frames split at each place they might end, the reading with the fewest shapes, then the
   fewest frames dropped, then the shortest gap. A long leader space looks like a gap
   until the frames it would cut read as two shapes that always come together. *)
let learn_line ~rate (line : Recording.Line.t) =
  let idle = idle_level line in
  let tried =
    List.map
      (gap_thresholds ~idle (Recording.Line.runs line))
      ~f:(fun threshold -> learn_split ~rate ~idle ~threshold line)
  in
  match List.filter_map tried ~f:Result.ok with
  | [] -> List.hd_exn tried
  | learned ->
    Ok
      (List.min_elt learned ~compare:(fun a b ->
         [%compare: int * int]
           (List.length a.kinds, a.outliers)
           (List.length b.kinds, b.outliers))
       |> Option.value_exn)
;;

(* Bursts of the clock: edge spans with no run past four half periods. *)
let bursts ~half (clock : Recording.Line.t) =
  let threshold = Float.to_int (4. *. half) in
  Array.to_list clock.edges
  |> List.fold ~init:[] ~f:(fun acc e ->
    match acc with
    | (last :: _ as b) :: rest when e - last <= threshold -> (e :: b) :: rest
    | _ -> [ e ] :: acc)
  |> List.rev_map ~f:(fun b -> Array.of_list (List.rev b))
;;

(* A chip select: every clock edge comes while it is at one level, the active one. *)
let selects ~(clock : Recording.Line.t) (line : Recording.Line.t) =
  Array.length line.edges >= 2
  && Array.length clock.edges > 0
  &&
  let levels = Array.map clock.edges ~f:(Recording.Line.level_at line) in
  Array.for_all levels ~f:(Bool.equal levels.(0))
;;

(* The clock's edges in each span the select is active, as bursts. *)
let selected ~(clock : Recording.Line.t) (select : Recording.Line.t) =
  let active = Recording.Line.level_at select clock.edges.(0) in
  let starts =
    Array.filteri select.edges ~f:(fun j _ -> Bool.equal (level_after select j) active)
  in
  Array.to_list starts
  |> List.filter_map ~f:(fun start ->
    let until =
      Array.find select.edges ~f:(fun e -> e > start)
      |> Option.value ~default:Int.max_value
    in
    let inside = Array.filter clock.edges ~f:(fun e -> e > start && e < until) in
    Option.some_if (not (Array.is_empty inside)) inside)
;;

let clock_edges (clock : Recording.Line.t) ~rising =
  Array.filteri clock.edges ~f:(fun j _ -> Bool.equal (level_after clock j) rising)
;;

let clocked_frames ~rate ~clock ~(data : Recording.Line.t) ~sample_rising bursts =
  let samples = clock_edges clock ~rising:sample_rising in
  List.filter_map bursts ~f:(fun b ->
    let first = b.(0)
    and last = b.(Array.length b - 1) in
    let taken = Array.filter samples ~f:(fun s -> s >= first && s <= last) in
    if Array.is_empty taken
    then None
    else
      Some
        ( { Kind.leader = []; bits = Array.length taken; trailer = [] }
        , Array.map taken ~f:(fun s -> Recording.Line.level_at data s)
        , Float.of_int first /. rate ))
;;

let learn_clocked ~rate (lines : Recording.Line.t list) =
  let score (line : Recording.Line.t) =
    let runs = Recording.Line.runs line in
    match fit [ runs ] with
    | None -> None
    | Some (grid : Grid.t) ->
      let ones =
        List.count runs ~f:(fun (active, d) ->
          Option.equal Int.equal (Grid.units grid ~active (Float.of_int d)) (Some 1))
      in
      Some (line, grid.unit, Float.of_int ones /. Float.of_int (List.length runs))
  in
  let scored = List.filter_map lines ~f:score in
  match
    List.max_elt scored ~compare:(fun (a, _, x) (b, _, y) ->
      [%compare: float * int]
        (x, Array.length a.Recording.Line.edges)
        (y, Array.length b.edges))
  with
  | None -> Or_error.error_s [%message "unknown: no line has a clock's runs"]
  | Some (clock, half, ones) ->
    if Float.( < ) ones 0.6
    then Or_error.error_s [%message "unknown: no line runs at one rate, as a clock does"]
    else (
      let clock_idle = idle_level clock in
      let others = List.filter lines ~f:(fun l -> not (String.equal l.name clock.name)) in
      let select = List.find others ~f:(fun l -> selects ~clock l) in
      let bursts =
        match select with
        | Some select -> selected ~clock select
        | None -> bursts ~half clock
      in
      let within margin e =
        List.exists bursts ~f:(fun b ->
          e >= b.(0) - margin && e <= b.(Array.length b - 1) + margin)
      in
      let in_burst = within (Float.to_int half) in
      let quiet (l : Recording.Line.t) = Array.for_all l.edges ~f:(Fn.non (within 0)) in
      let data =
        List.filter others ~f:(fun l ->
          (not (quiet l))
          && not (Option.exists select ~f:(fun s -> String.equal s.name l.name)))
        |> List.max_elt ~compare:(fun (a : Recording.Line.t) b ->
          Int.compare (Array.length a.edges) (Array.length b.edges))
      in
      match data with
      | None ->
        Or_error.error_s [%message "unknown: a clock but no data line moves with it"]
      | Some data ->
        let rises = clock_edges clock ~rising:true in
        let falls = clock_edges clock ~rising:false in
        let inside = Array.filter data.edges ~f:in_burst in
        let distance sorted =
          if Array.is_empty inside || Array.is_empty sorted
          then 0
          else
            Array.fold inside ~init:Int.max_value ~f:(fun m e ->
              Int.min m (near sorted e))
        in
        let rise_clear = distance rises in
        let fall_clear = distance falls in
        let sample_rising = rise_clear >= fall_clear in
        if Float.( < ) (Float.of_int (Int.max rise_clear fall_clear)) (0.3 *. half)
        then Or_error.error_s [%message "unknown: data moves near both clock edges"]
        else (
          let data_idle = idle_level data in
          let frames = clocked_frames ~rate ~clock ~data ~sample_rising bursts in
          let gap =
            List.zip_exn (List.drop_last_exn bursts) (List.tl_exn bursts)
            |> List.map ~f:(fun (a, b) ->
              Float.of_int (b.(0) - a.(Array.length a - 1)) /. half)
            |> List.min_elt ~compare:Float.compare
            |> Option.value_map ~default:0 ~f:Float.iround_down_exn
          in
          finish
            ~line:data.name
            ~unit_s:(half /. rate)
            ~idle:data_idle
            ~coding:
              (Clocked
                 { clock = clock.name
                 ; select = Option.map select ~f:(fun (l : Recording.Line.t) -> l.name)
                 ; sample_rising
                 ; clock_idle
                 })
            ~lsb_first:false
            ~gap
            ~seen:(List.length frames)
            frames))
;;

let learn ?lines (recording : Recording.t) =
  let lines =
    match lines with
    | None -> List.filter recording.lines ~f:(fun l -> Array.length l.edges >= 4)
    | Some names -> List.filter_map names ~f:(Recording.find recording)
  in
  match lines with
  | [] -> Or_error.error_s [%message "unknown: no line moves"]
  | [ line ] -> learn_line ~rate:recording.rate_hz line
  | lines -> learn_clocked ~rate:recording.rate_hz lines
;;

let new_message ?value t =
  match
    List.max_elt t.fields ~compare:(fun (a : Field.t) b ->
      [%compare: int * int] (List.length a.seen, a.first) (List.length b.seen, b.first))
  with
  | None -> Or_error.error_s [%message "no field differs between frames"]
  | Some field ->
    let value =
      match value with
      | Some v -> v
      | None ->
        List.init (1 lsl Int.min field.width 16) ~f:Fn.id
        |> List.find ~f:(fun v -> not (List.mem field.seen v ~equal))
        |> Option.value ~default:0
    in
    let base = List.find_exn t.frames ~f:(fun f -> f.kind = field.kind) in
    Ok (field, { base with bits = with_field t field base.bits value; at = 0. })
;;

let runs t ~kind bits =
  let k = List.nth_exn t.kinds kind in
  let bits = Learn_check.apply (rules_of t ~kind) bits in
  let run active units = { Run.active; units } in
  let body =
    match t.coding with
    | Pulse { zero; one; last_is_bit } ->
      let n = Array.length bits in
      List.concat
        (List.init n ~f:(fun i ->
           let m, s = if bits.(i) then one else zero in
           if last_is_bit && i = n - 1
           then [ run true m ]
           else [ run true m; run false s ]))
    | Manchester { one_starts_active; wide; hidden_half } ->
      let halves =
        List.concat
          (List.init (Array.length bits) ~f:(fun i ->
             let first = Bool.equal bits.(i) one_starts_active in
             let w = if Option.equal Int.equal wide (Some i) then 2 else 1 in
             [ run first w; run (not first) w ]))
      in
      let halves = if hidden_half then List.tl_exn halves else halves in
      halves
    | Uart { data_bits; parity; stop_bits } ->
      let chars = Array.length bits / data_bits in
      List.concat
        (List.init chars ~f:(fun c ->
           let data =
             Array.to_list (Array.sub bits ~pos:(c * data_bits) ~len:data_bits)
           in
           let parity =
             match parity with
             | None -> []
             | Some Parity.Even -> [ parity_of data ]
             | Some Odd -> [ not (parity_of data) ]
           in
           (run true 1 :: List.map (data @ parity) ~f:(fun b -> run (not b) 1))
           @ [ run false stop_bits ]))
    | Clocked _ -> raise_s [%message "a clocked protocol has no single line of runs"]
  in
  (* merge equal neighbours, drop the idle ends *)
  let merged =
    List.fold
      (k.leader @ body @ k.trailer)
      ~init:[]
      ~f:(fun acc (r : Run.t) ->
        match acc with
        | (p : Run.t) :: rest when Bool.equal p.active r.active ->
          { p with units = p.units + r.units } :: rest
        | _ -> r :: acc)
    |> List.rev
  in
  let rec drop_idle = function
    | (r : Run.t) :: rest when not r.active -> drop_idle rest
    | l -> l
  in
  drop_idle merged |> List.rev |> drop_idle |> List.rev
;;

let synthesize ?(jitter = 0.) ?(skew = 0.) ?(seed = 0) ~rate_hz t frames =
  let random = Random.State.make [| seed |] in
  let unit = t.unit_s *. rate_hz in
  let length ?(active = false) units =
    let j =
      if Float.( > ) jitter 0.
      then Random.State.float random (2. *. jitter) -. jitter
      else 0.
    in
    let s = if active then skew else -.skew in
    Float.iround_nearest_exn ((Float.of_int units +. j +. s) *. unit)
  in
  match t.coding with
  | Clocked { clock; select; sample_rising; clock_idle } ->
    let half = Float.iround_nearest_exn unit in
    let time = ref (4 * half) in
    let clock_edges = Queue.create () in
    let data_edges = Queue.create () in
    let select_edges = Queue.create () in
    let data_level = ref t.idle in
    let clock_level = ref clock_idle in
    let change level edges b =
      if Bool.( <> ) b !level
      then (
        Queue.enqueue edges !time;
        level := b)
    in
    List.iter frames ~f:(fun (kind, bits) ->
      let bits = Learn_check.apply (rules_of t ~kind) bits in
      if Option.is_some select then Queue.enqueue select_edges !time;
      time := !time + (2 * half);
      (* the launch edge and the data, then the sampling edge half a period on *)
      Array.iter bits ~f:(fun b ->
        change clock_level clock_edges (not sample_rising);
        change data_level data_edges b;
        time := !time + half;
        change clock_level clock_edges sample_rising;
        time := !time + half);
      change clock_level clock_edges clock_idle;
      time := !time + half;
      change data_level data_edges t.idle;
      time := !time + (2 * half);
      if Option.is_some select then Queue.enqueue select_edges !time;
      time := !time + (Int.max t.gap 8 * half));
    let line name first edges =
      { Recording.Line.name; first; edges = Queue.to_array edges }
    in
    { Recording.rate_hz
    ; length = !time + (4 * half)
    ; lines =
        [ line clock clock_idle clock_edges; line t.line t.idle data_edges ]
        @ Option.value_map select ~default:[] ~f:(fun s -> [ line s true select_edges ])
    ; notes = []
    }
  | Pulse _ | Manchester _ | Uart _ ->
    let time = ref (Float.iround_nearest_exn (4. *. unit)) in
    let edges = Queue.create () in
    List.iter frames ~f:(fun (kind, bits) ->
      List.iter (runs t ~kind bits) ~f:(fun (r : Run.t) ->
        Queue.enqueue edges !time;
        time := !time + length ~active:r.active r.units);
      Queue.enqueue edges !time;
      time := !time + length (Int.max t.gap 4));
    { Recording.rate_hz
    ; length = !time
    ; lines =
        [ { Recording.Line.name = t.line; first = t.idle; edges = Queue.to_array edges } ]
    ; notes = []
    }
;;

let kind_index t kind =
  List.findi t.kinds ~f:(fun _ k -> Kind.equal k kind) |> Option.map ~f:fst
;;

let decode t (recording : Recording.t) =
  let rate = recording.rate_hz in
  let unit = t.unit_s *. rate in
  let frame (kind, bits, at) =
    Option.map (kind_index t kind) ~f:(fun kind -> { Frame.kind; bits; at })
  in
  let line name =
    match Recording.find recording name with
    | Some line -> Ok line
    | None -> Or_error.error_s [%message "the recording has no line" name]
  in
  match t.coding with
  | Clocked { clock; sample_rising; select; _ } ->
    let%bind.Or_error clock = line clock in
    let%bind.Or_error data = line t.line in
    let%map.Or_error bursts =
      match select with
      | Some name ->
        let%map.Or_error select = line name in
        selected ~clock select
      | None -> Ok (bursts ~half:unit clock)
    in
    clocked_frames ~rate ~clock ~data ~sample_rising bursts |> List.filter_map ~f:frame
  | Pulse _ | Manchester _ | Uart _ ->
    (* a recording of one line is the line, whatever pin it was taken from *)
    let%map.Or_error line =
      match recording.lines with
      | [ only ] -> Ok only
      | _ -> line t.line
    in
    let threshold =
      Some (Float.iround_nearest_exn (Float.of_int (Int.max 8 (t.gap / 2)) *. unit))
    in
    let frames = split_frames line ~idle:t.idle ~threshold in
    let at (f : Edges.t) = Float.of_int f.(0) /. rate in
    List.filter_map frames ~f:(fun f ->
      let runs = quantize { Grid.unit; bias = t.bias_s *. rate } (Edges.runs f) in
      match t.coding, runs with
      | Pulse { zero; one; last_is_bit }, Some runs ->
        let leader, bits, after, last = pulse_frame ~zero ~one runs in
        let bits, trailer =
          if last_is_bit && List.is_empty after
          then
            ( Array.append
                bits
                [| Option.value_map last ~default:false ~f:(fun m -> m = fst one) |]
            , [] )
          else
            ( bits
            , after
              @ Option.value_map last ~default:[] ~f:(fun units ->
                [ { Run.active = true; units } ]) )
        in
        frame ({ Kind.leader; bits = Array.length bits; trailer }, bits, at f)
      | Manchester { one_starts_active; wide; hidden_half }, Some runs ->
        List.find_map t.kinds ~f:(fun k ->
          let shape =
            { Manchester_shape.leader = List.length k.leader; hidden_half; wide }
          in
          Option.bind (manchester_bits shape runs) ~f:(fun (leader, bits) ->
            frame
              ( { Kind.leader; bits = List.length bits; trailer = [] }
              , Array.of_list_map bits ~f:(Bool.equal one_starts_active)
              , at f )))
      | Uart { data_bits; parity; _ }, _ ->
        let bits = data_bits + Bool.to_int (Option.is_some parity) in
        let level_at at = Recording.Line.level_at line (at + 1) in
        Option.bind (uart_chars ~unit ~idle:t.idle ~bits ~level_at f) ~f:(fun chars ->
          let payload =
            List.concat_map chars ~f:(fun c -> List.map (List.take c data_bits) ~f:not)
          in
          frame
            ( { Kind.leader = []; bits = List.length payload; trailer = [] }
            , Array.of_list payload
            , at f ))
      | _, _ -> None)
;;

let show_runs runs =
  List.map runs ~f:(fun (r : Run.t) ->
    sprintf "%s%d" (if r.active then "+" else "-") r.units)
  |> String.concat ~sep:" "
;;

let bits_string bits =
  Array.to_list bits
  |> List.map ~f:(fun b -> if b then '1' else '0')
  |> String.of_char_list
;;

let to_string t =
  let us = t.unit_s *. 1e6 in
  let coding =
    match t.coding with
    | Manchester { one_starts_active; wide; hidden_half } ->
      sprintf
        "manchester, half bit %.1f us, a one %s%s%s"
        us
        (if one_starts_active then "active then idle" else "idle then active")
        (Option.value_map wide ~default:"" ~f:(sprintf ", bit %d twice as wide"))
        (if hidden_half then ", the first half hidden in the idle" else "")
    | Pulse { zero = m0, s0; one = m1, s1; last_is_bit } ->
      sprintf
        "pulse, unit %.1f us, 0 = mark %d space %d, 1 = mark %d space %d%s"
        us
        m0
        s0
        m1
        s1
        (if last_is_bit then ", the last mark a bit" else "")
    | Uart { data_bits; parity; stop_bits } ->
      sprintf
        "uart, %.1f baud (bit %.2f us), %d%s%d"
        (1. /. t.unit_s)
        us
        data_bits
        (match parity with
         | None -> "N"
         | Some Even -> "E"
         | Some Odd -> "O")
        stop_bits
    | Clocked { clock; select; sample_rising; clock_idle } ->
      sprintf
        "clocked, clock %s at %.1f Hz idle %d, data %s read on the %s edge%s"
        clock
        (1. /. (2. *. t.unit_s))
        (Bool.to_int clock_idle)
        t.line
        (if sample_rising then "rising" else "falling")
        (Option.value_map select ~default:"" ~f:(sprintf ", %s selects"))
  in
  let kinds =
    List.mapi t.kinds ~f:(fun i k ->
      let count = List.count t.frames ~f:(fun f -> f.kind = i) in
      sprintf
        "kind %d: %d frames, leader [%s], %d bits, trailer [%s]"
        i
        count
        (show_runs k.leader)
        k.bits
        (show_runs k.trailer))
  in
  let rules =
    List.concat_map t.rules ~f:(fun (kind, found) ->
      List.map found ~f:(fun (rule, (e : Learn_check.Evidence.t)) ->
        sprintf
          "kind %d check: %s (%d bits against 2^%.1f)"
          kind
          (Learn_check.Rule.to_string ~lsb_first:t.lsb_first rule)
          e.bits
          (Float.log e.hypotheses /. Float.log 2.)))
  in
  let fields =
    List.map t.fields ~f:(fun f ->
      sprintf
        "kind %d field: bits %d..%d, %d values seen"
        f.kind
        f.first
        (f.first + f.width - 1)
        (List.length f.seen))
  in
  let frames =
    List.map t.frames ~f:(fun f ->
      sprintf "%10.6f s  kind %d  %s" f.at f.kind (bits_string f.bits))
  in
  String.concat_lines
    ([ sprintf "line %s, idle %d" t.line (Bool.to_int t.idle)
     ; coding
     ; sprintf "marks read %.1f us long, as a receiver stretches them" (t.bias_s *. 1e6)
     ; sprintf
         "gap at least %d units, %d frames, %d outliers"
         t.gap
         (List.length t.frames)
         t.outliers
     ]
     @ kinds
     @ rules
     @ fields
     @ frames)
;;
