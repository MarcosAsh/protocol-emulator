open! Core
open Protocol_emulator

(* the pins a limit reads *)
let pins_of (bench : Bench.t) (limit : Datasheet.t) =
  match limit.bound with
  | Run { pin; widths = _ } -> [ pin bench.config ]
  | Kernel spec ->
    let spec = spec bench.config 1 in
    [ spec.a; spec.b ]
;;

module Capture = struct
  module Line = struct
    type t =
      { first : bool
      ; edges : int list
      }

    let at_rest = { first = false; edges = [] }
  end

  type t =
    { rate_hz : int
    ; length : int
    ; lines : (int * Line.t) list
    ; from_reset : bool
    }

  let line t pin =
    List.Assoc.find t.lines pin ~equal:Int.equal |> Option.value ~default:Line.at_rest
  ;;

  let of_pins ?rate_hz (bench : Bench.t) ~quiet_pin pins =
    let stimulus =
      Option.value_exn bench.stimulus ~message:[%string "%{bench.name} has no run"]
    in
    let cycles = Datasheet.run_pins bench ~quiet_pin stimulus in
    let rate_hz = Option.value rate_hz ~default:bench.clock_hz in
    let length = Array.length cycles * rate_hz / bench.clock_hz in
    let line pin =
      let level k = (cycles.(k * bench.clock_hz / rate_hz) lsr pin) land 1 = 1 in
      let edges = Queue.create () in
      for k = 1 to length - 1 do
        if Bool.( <> ) (level k) (level (k - 1)) then Queue.enqueue edges k
      done;
      pin, { Line.first = length > 0 && level 0; edges = Queue.to_list edges }
    in
    { rate_hz
    ; length
    ; lines = List.map (List.dedup_and_sort pins ~compare) ~f:line
    ; from_reset = true
    }
  ;;

  let of_run ?rate_hz bench limit =
    let pins = pins_of bench limit in
    of_pins ?rate_hz bench ~quiet_pin:(List.hd_exn pins) pins
  ;;

  let to_string t =
    [ [%string "rate %{t.rate_hz#Int}"]; [%string "length %{t.length#Int}"] ]
    @ List.map t.lines ~f:(fun (pin, { Line.first; edges }) ->
      String.concat
        ~sep:" "
        ("pin"
         :: Int.to_string pin
         :: Int.to_string (Bool.to_int first)
         :: List.map edges ~f:Int.to_string))
    |> String.concat ~sep:"\n"
  ;;

  let of_string text =
    let int s = Int.of_string (String.strip s) in
    List.fold
      (String.split_lines text)
      ~init:{ rate_hz = 0; length = 0; lines = []; from_reset = false }
      ~f:(fun t line ->
        match
          String.split (String.strip line) ~on:' '
          |> List.filter ~f:(Fn.non String.is_empty)
        with
        | [ "rate"; hz ] -> { t with rate_hz = int hz }
        | [ "length"; n ] -> { t with length = int n }
        | "pin" :: pin :: first :: edges ->
          { t with
            lines =
              t.lines
              @ [ int pin, { Line.first = int first <> 0; edges = List.map edges ~f:int }
                ]
          }
        | [] -> t
        | _ -> raise_s [%message "not an edges line" line])
  ;;
end

module Verdict = struct
  type t =
    | Pass
    | Within_a_sample
    | Fail
    | Unmeasured
  [@@deriving sexp_of, equal]
end

type t =
  { limit : Datasheet.t
  ; samples : int option
  ; verdict : Verdict.t
  }

module Edge = struct
  type t =
    { pin : int
    ; sample : int
    }
end

(* Every spacing the capture shows where [spec] asks one, as the edge's number over both
   pins' edges from 1, the edge, and the edge it is spaced from: its own edge before, for
   a hold, or the other pin's last edge, for an apart. The other pin moving at the same
   sample is 0 since. *)
let spaced (capture : Capture.t) (spec : Kernel.Spacing.Spec.t) =
  let bit level = Bool.( <> ) spec.dirs level in
  let apply ~hold ~apart ~own ~other ~own_last ~other_last ~edge ~number =
    List.filter_map
      [ own_last, hold ~own ~other; other_last, apart ~own ~other ]
      ~f:(fun (last, asked) ->
        match last with
        | Some last when asked > 0 -> Some (number, edge, last)
        | _ -> None)
  in
  let rec go ~level_a ~level_b ~last_a ~last_b ~number found edges_a edges_b =
    let next =
      List.min_elt (List.filter_opt [ List.hd edges_a; List.hd edges_b ]) ~compare
    in
    match next with
    | None -> List.rev found
    | Some at ->
      let moves edges = Option.equal Int.equal (List.hd edges) (Some at) in
      let a = moves edges_a
      and b = moves edges_b in
      let own_a = bit level_a
      and own_b = bit level_b in
      let edge_a = { Edge.pin = spec.a; sample = at }
      and edge_b = { Edge.pin = spec.b; sample = at } in
      let seen_a = if b then Some edge_b else last_b
      and seen_b = if a then Some edge_a else last_a in
      let found =
        if a
        then
          List.rev_append
            (apply
               ~hold:spec.hold_a
               ~apart:spec.apart_a
               ~own:own_a
               ~other:own_b
               ~own_last:last_a
               ~other_last:seen_a
               ~edge:edge_a
               ~number:(number + 1))
            found
        else found
      in
      let number = if a then number + 1 else number in
      let found =
        if b
        then
          List.rev_append
            (apply
               ~hold:spec.hold_b
               ~apart:spec.apart_b
               ~own:own_b
               ~other:own_a
               ~own_last:last_b
               ~other_last:seen_b
               ~edge:edge_b
               ~number:(number + 1))
            found
        else found
      in
      let number = if b then number + 1 else number in
      let after moved edges = if moved then List.tl_exn edges else edges in
      go
        ~level_a:(Bool.( <> ) level_a a)
        ~level_b:(Bool.( <> ) level_b b)
        ~last_a:(if a then Some edge_a else last_a)
        ~last_b:(if b then Some edge_b else last_b)
        ~number
        found
        (after a edges_a)
        (after b edges_b)
  in
  let a = Capture.line capture spec.a
  and b = Capture.line capture spec.b in
  go
    ~level_a:a.first
    ~level_b:b.first
    ~last_a:None
    ~last_b:None
    ~number:0
    []
    a.edges
    b.edges
;;

let applications capture spec =
  List.map (spaced capture spec) ~f:(fun (number, (edge : Edge.t), (from : Edge.t)) ->
    number, edge.sample, edge.sample - from.sample)
;;

let spacing capture spec =
  List.map (applications capture spec) ~f:(fun (_, _, since) -> since)
  |> List.min_elt ~compare
;;

(* a [Run] bound's widths, from the levels on its pin: the first only when it began at the
   capture's start, and never the last, which has not ended *)
let widths (capture : Capture.t) ~pin widths =
  let { Capture.Line.first; edges } = Capture.line capture pin in
  let bounds = 0 :: edges in
  let levels =
    List.zip_exn (List.drop_last_exn bounds) (List.tl_exn bounds)
    |> List.mapi ~f:(fun i (from, until) -> Bool.( <> ) first (i % 2 = 1), until - from)
  in
  let levels = if capture.from_reset then levels else List.drop levels 1 in
  widths ~clock_hz:capture.rate_hz levels
;;

let verdict (capture : Capture.t) (limit : Datasheet.Limit.t) samples =
  let ns n = Float.of_int n *. 1e9 /. Float.of_int capture.rate_hz in
  match samples with
  | None -> Verdict.Unmeasured
  | Some n ->
    let clears n =
      match limit with
      | At_least least -> Float.( >= ) (ns n) least
      | At_most most -> Float.( <= ) (ns n) most
    in
    if clears (n - 1) && clears (n + 1)
    then Pass
    else if clears (n - 1) || clears (n + 1)
    then Within_a_sample
    else Fail
;;

let measure limits (bench : Bench.t) capture =
  List.filter limits ~f:(fun (l : Datasheet.t) -> String.equal l.firmware bench.name)
  |> List.map ~f:(fun (limit : Datasheet.t) ->
    let samples =
      match limit.bound, limit.limit with
      | Kernel spec, _ -> spacing capture (spec bench.config 1)
      | Run { pin; widths = f }, At_least _ ->
        List.min_elt (widths capture ~pin:(pin bench.config) f) ~compare
      | Run { pin; widths = f }, At_most _ ->
        List.max_elt (widths capture ~pin:(pin bench.config) f) ~compare
    in
    { limit; samples; verdict = verdict capture limit.limit samples })
;;

let to_string (capture : Capture.t) ts =
  List.map ts ~f:(fun t ->
    let side, ns =
      match t.limit.limit with
      | At_least ns -> ">=", ns
      | At_most ns -> "<=", ns
    in
    let measured =
      Option.value_map t.samples ~default:"none" ~f:(fun n ->
        sprintf "%d (%.1f ns)" n (Float.of_int n *. 1e9 /. Float.of_int capture.rate_hz))
    in
    sprintf
      "%-18s %-16s %s %8g ns  measured %-20s %-15s %s, %s"
      t.limit.firmware
      t.limit.parameter
      side
      ns
      measured
      (Sexp.to_string (Verdict.sexp_of_t t.verdict))
      t.limit.sheet.document
      t.limit.sheet.page)
  |> String.concat ~sep:"\n"
;;

(* Where each of a run bound's widths lies on its pin: the levels one more cycle of which
   changes it. A width is placed only on whole levels after the first that sum to it, so
   it is never placed wrong, though one may go unplaced. *)
let placed (capture : Capture.t) ~pin widths =
  let { Capture.Line.first; edges } = Capture.line capture pin in
  let edges = Array.of_list edges in
  let levels =
    Array.mapi edges ~f:(fun i until ->
      let from = if i = 0 then 0 else edges.(i - 1) in
      Bool.( <> ) first (i % 2 = 1), until - from)
  in
  let widths_of levels =
    Array.of_list (widths ~clock_hz:capture.rate_hz (Array.to_list levels))
  in
  let base = widths_of levels in
  let touched = Array.map base ~f:(fun _ -> Queue.create ()) in
  Array.iteri levels ~f:(fun i (high, n) ->
    let wider = Array.copy levels in
    wider.(i) <- high, n + 1;
    let moved = widths_of wider in
    if Array.length moved = Array.length base
    then
      Array.iteri base ~f:(fun w width ->
        if moved.(w) <> width then Queue.enqueue touched.(w) i));
  Array.to_list base
  |> List.filter_mapi ~f:(fun w width ->
    match Queue.to_list touched.(w) with
    | [] -> None
    | from :: _ as span ->
      let until = List.last_exn span in
      let whole = [%equal: int list] span (List.range from (until + 1)) in
      let cycles = List.sum (module Int) span ~f:(fun i -> snd levels.(i)) in
      if whole && from >= 1 && cycles = width
      then
        Some
          ({ Edge.pin; sample = edges.(until) }, { Edge.pin; sample = edges.(from - 1) })
      else None)
;;

module Prediction = struct
  type t =
    { firmware : string
    ; load : int option
    ; bursts : int list list
    ; capture : Capture.t
    ; limits : (Datasheet.t * (Edge.t * Edge.t) list) list
    }

  let of_bench limits (bench : Bench.t) =
    match
      List.filter limits ~f:(fun (l : Datasheet.t) -> String.equal l.firmware bench.name)
    with
    | [] -> raise_s [%message "no datasheet limits name" bench.name]
    | first :: _ as mine ->
      let capture =
        Capture.of_pins
          bench
          ~quiet_pin:(List.hd_exn (pins_of bench first))
          (List.concat_map mine ~f:(pins_of bench))
      in
      let pairs (limit : Datasheet.t) =
        match limit.bound with
        | Kernel spec ->
          List.map
            (spaced capture (spec bench.config 1))
            ~f:(fun (_, edge, from) -> edge, from)
        | Run { pin; widths } -> placed capture ~pin:(pin bench.config) widths
      in
      let limits = List.map mine ~f:(fun limit -> limit, pairs limit) in
      let used (pin, _) =
        List.exists limits ~f:(fun (_, pairs) ->
          List.exists pairs ~f:(fun ((edge : Edge.t), (from : Edge.t)) ->
            edge.pin = pin || from.pin = pin))
      in
      { firmware = bench.name
      ; load = bench.load
      ; bursts = Option.value_map bench.stimulus ~default:[] ~f:(fun s -> s.bursts)
      ; capture = { capture with lines = List.filter capture.lines ~f:used }
      ; limits
      }
  ;;

  let to_string t =
    let limit i ((limit : Datasheet.t), pairs) =
      let side, ns =
        match limit.limit with
        | At_least ns -> ">=", ns
        | At_most ns -> "<=", ns
      in
      sprintf "limit %d %s %.3f %s" i side ns limit.parameter
      :: List.map pairs ~f:(fun ((edge : Edge.t), (from : Edge.t)) ->
        sprintf "apply %d %d %d %d %d" i edge.pin edge.sample from.pin from.sample)
    in
    let words = List.map ~f:Int.to_string in
    (([%string "firmware %{t.firmware}"]
      :: List.map (Option.to_list t.load) ~f:(sprintf "load %d"))
     @ List.map t.bursts ~f:(fun burst -> String.concat ~sep:" " ("burst" :: words burst))
     @ [ Capture.to_string t.capture ])
    @ List.concat_mapi t.limits ~f:limit
    |> String.concat ~sep:"\n"
  ;;
end
