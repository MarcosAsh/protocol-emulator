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

  let of_run ?rate_hz (bench : Bench.t) (limit : Datasheet.t) =
    let stimulus =
      Option.value_exn bench.stimulus ~message:[%string "%{bench.name} has no run"]
    in
    let pins = pins_of bench limit in
    let cycles = Datasheet.run_pins bench ~quiet_pin:(List.hd_exn pins) stimulus in
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

(* Every spacing the capture shows where [spec] asks one, as the edge's number over both
   pins' edges from 1, its sample, and the samples since: at each edge of a pin, since its
   own edge before, where its hold applies to the two pins' bits before the edge, and
   since the other pin's last edge, where its apart does. The other pin moving at the same
   sample is 0 since. *)
let applications (capture : Capture.t) (spec : Kernel.Spacing.Spec.t) =
  let bit level = Bool.( <> ) spec.dirs level in
  let apply ~hold ~apart ~own ~other ~own_last ~other_last ~at ~number =
    List.filter_map
      [ own_last, hold ~own ~other; other_last, apart ~own ~other ]
      ~f:(fun (last, asked) ->
        match last with
        | Some last when asked > 0 -> Some (number, at, at - last)
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
      let seen_a = if b then Some at else last_b
      and seen_b = if a then Some at else last_a in
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
               ~at
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
               ~at
               ~number:(number + 1))
            found
        else found
      in
      let number = if b then number + 1 else number in
      let after moved edges = if moved then List.tl_exn edges else edges in
      go
        ~level_a:(Bool.( <> ) level_a a)
        ~level_b:(Bool.( <> ) level_b b)
        ~last_a:(if a then Some at else last_a)
        ~last_b:(if b then Some at else last_b)
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
