open! Core
open Protocol_emulator

let pin_of (bench : Bench.t) (limit : Datasheet.t) =
  match limit.bound with
  | Run { pin; widths = _ } -> pin bench.config
  | Kernel spec -> (spec bench.config 1).a
;;

module Capture = struct
  type t =
    { rate_hz : int
    ; samples : int array
    ; from_reset : bool
    }

  let of_run ?rate_hz (bench : Bench.t) (limit : Datasheet.t) =
    let stimulus =
      Option.value_exn bench.stimulus ~message:[%string "%{bench.name} has no run"]
    in
    let cycles = Datasheet.run_pins bench ~quiet_pin:(pin_of bench limit) stimulus in
    let rate_hz = Option.value rate_hz ~default:bench.clock_hz in
    let count = Array.length cycles * rate_hz / bench.clock_hz in
    { rate_hz
    ; samples = Array.init count ~f:(fun k -> cycles.(k * bench.clock_hz / rate_hz))
    ; from_reset = true
    }
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

let level (capture : Capture.t) pin i = (capture.samples.(i) lsr pin) land 1 = 1

(* The least spacing the capture shows where [spec] asks one: at each edge of a pin, the
   samples since its own edge before, where its hold applies to the two pins' bits before
   the edge, and since the other pin's last edge, where its apart does. *)
let spacing (capture : Capture.t) (spec : Kernel.Spacing.Spec.t) =
  let bit pin i = Bool.( <> ) spec.dirs (level capture pin i) in
  let apply ~own_pin ~other_pin ~hold ~apart ~own_last ~other_last ~at least =
    let own = bit own_pin (at - 1)
    and other = bit other_pin (at - 1) in
    List.filter_opt
      [ Option.bind own_last ~f:(fun last ->
          Option.some_if (hold ~own ~other > 0) (at - last))
      ; Option.bind other_last ~f:(fun last ->
          Option.some_if (apart ~own ~other > 0) (at - last))
      ]
    |> List.fold ~init:least ~f:(fun least since ->
      Some (Option.value_map least ~default:since ~f:(Int.min since)))
  in
  let _, _, least =
    List.fold
      (List.range 1 (Array.length capture.samples))
      ~init:(None, None, None)
      ~f:(fun (last_a, last_b, least) at ->
        let moved pin = Bool.( <> ) (bit pin at) (bit pin (at - 1)) in
        let a = moved spec.a
        and b = moved spec.b in
        let least =
          if a
          then
            apply
              ~own_pin:spec.a
              ~other_pin:spec.b
              ~hold:spec.hold_a
              ~apart:spec.apart_a
              ~own_last:last_a
              ~other_last:last_b
              ~at
              least
          else least
        in
        let least =
          if b
          then
            apply
              ~own_pin:spec.b
              ~other_pin:spec.a
              ~hold:spec.hold_b
              ~apart:spec.apart_b
              ~own_last:last_b
              ~other_last:last_a
              ~at
              least
          else least
        in
        (if a then Some at else last_a), (if b then Some at else last_b), least)
  in
  least
;;

(* a [Run] bound's widths, from the capture's levels on its pin: the first level only when
   it began at the capture's start, and never the last, which has not ended *)
let widths (capture : Capture.t) ~pin widths =
  let levels =
    Datasheet.runs (Array.init (Array.length capture.samples) ~f:(level capture pin))
    |> List.drop_last
    |> Option.value ~default:[]
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
      "%-18s %-14s %s %8g ns  measured %-20s %s"
      t.limit.firmware
      t.limit.parameter
      side
      ns
      measured
      (Sexp.to_string (Verdict.sexp_of_t t.verdict)))
  |> String.concat ~sep:"\n"
;;
