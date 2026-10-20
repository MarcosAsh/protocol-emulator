open! Core
open Protocol_emulator

type t =
  { bench : Bench.t
  ; entry : Datasheet.t
  ; verdict : Datasheet.Verdict.t
  ; edge : int option
  ; cycle : int
  ; measured : int option
  ; pins : int list
  ; trace : int array
  }

let stimulus (bench : Bench.t) =
  match bench.stimulus with
  | Some stimulus -> stimulus
  | None -> raise_s [%message "BUG: no stimulus to run" bench.name]
;;

let level trace pin cycle = (trace.(cycle) lsr pin) land 1 = 1

(* The first edge that comes sooner than [needed] cycles after the edge it is spaced from,
   as the capture of the trace shows it. *)
let spaced_edge
  (bench : Bench.t)
  (entry : Datasheet.t)
  (spec : Kernel.Spacing.Spec.t)
  ~needed
  =
  let capture = Measured_limits.Capture.of_run bench entry in
  Measured_limits.applications capture spec
  |> List.filter ~f:(fun (_, _, since) -> since < needed)
  |> List.min_elt ~compare:(fun (a, _, _) (b, _, _) -> Int.compare a b)
;;

(* The edge that ends the first width to break the limit, found by bisection over the
   pin's completed level runs as a width once broken stays so. A width appears when its
   last level has ended, which for the first of a pair is the one after it: so the width
   ends at the last run if widening the last run changes it, and the run before if not. *)
let run_edge (limit : Datasheet.Limit.t) ~needed ~widths trace pin =
  let runs =
    Datasheet.runs (Array.map trace ~f:(fun word -> (word lsr pin) land 1 = 1))
  in
  let completed k = List.take runs (k + 1) |> List.drop_last_exn in
  let worst levels =
    match limit with
    | At_least _ -> List.min_elt (widths levels) ~compare
    | At_most _ -> List.max_elt (widths levels) ~compare
  in
  let broken k =
    match limit with
    | At_least _ -> List.exists (widths (completed k)) ~f:(fun w -> w < needed)
    | At_most _ -> List.exists (widths (completed k)) ~f:(fun w -> w > needed)
  in
  let last = List.length runs - 1 in
  if last < 1 || not (broken last)
  then None
  else (
    let rec go lo hi =
      if hi - lo <= 1
      then hi
      else (
        let mid = (lo + hi) / 2 in
        if broken mid then go lo mid else go mid hi)
    in
    let k = go 0 last in
    let levels = completed k in
    let widened =
      List.mapi levels ~f:(fun i (high, n) -> if i = k - 1 then high, n + 1 else high, n)
    in
    let edge = if [%equal: int option] (worst levels) (worst widened) then k - 1 else k in
    let cycle = List.sum (module Int) (List.take runs edge) ~f:snd in
    Option.map (worst levels) ~f:(fun width -> edge, cycle, width))
;;

let locate (bench : Bench.t) ((entry : Datasheet.t), (verdict : Datasheet.Verdict.t)) =
  let stimulus = stimulus bench in
  let none ~pins ~trace =
    { bench; entry; verdict; edge = None; cycle = 0; measured = None; pins; trace }
  in
  match entry.bound with
  | Kernel spec ->
    let spec = spec bench.config verdict.needed in
    let pins = [ spec.a; spec.b ] in
    let trace = Datasheet.run_pins bench ~quiet_pin:spec.a stimulus in
    (match spaced_edge bench entry spec ~needed:verdict.needed with
     | Some (edge, cycle, since) ->
       { (none ~pins ~trace) with edge = Some edge; cycle; measured = Some since }
     | None -> none ~pins ~trace)
  | Run { pin; widths } ->
    let pin = pin bench.config in
    let trace = Datasheet.run_pins bench ~quiet_pin:pin stimulus in
    (match
       run_edge
         entry.limit
         ~needed:verdict.needed
         ~widths:(widths ~clock_hz:bench.clock_hz)
         trace
         pin
     with
     | Some (edge, cycle, measured) ->
       { (none ~pins:[ pin ] ~trace) with
         edge = Some edge
       ; cycle
       ; measured = Some measured
       }
     | None -> none ~pins:[ pin ] ~trace)
;;

let refusals limits (bench : Bench.t) =
  Datasheet.check limits bench
  |> List.filter ~f:(fun (_, (v : Datasheet.Verdict.t)) -> not v.ok)
  |> List.map ~f:(locate bench)
;;

let time t cycles = Bench.time ~clock_hz:t.bench.clock_hz cycles

(* the limit's ns to the nearest, in [Bench.time]'s units *)
let limit_time ns = Bench.time ~clock_hz:1_000_000_000 (Float.iround_nearest_exn ns)

(* the limit's word, the sign of a width that breaks it, and the limit in ns *)
let side (limit : Datasheet.Limit.t) =
  match limit with
  | At_least ns -> "min", "<", ns
  | At_most ns -> "max", ">", ns
;;

let to_line t =
  let word, sign, limit_ns = side t.entry.limit in
  let cycles = Option.first_some t.measured t.verdict.bound in
  let against =
    match t.measured with
    | None ->
      sprintf
        "%s bound %s"
        (match t.entry.bound with
         | Kernel _ -> "kernel"
         | Run _ -> "run")
        (Option.value_map t.verdict.bound ~default:"none" ~f:(time t))
    | Some cycles ->
      let ns = Float.of_int cycles *. 1e9 /. Float.of_int t.bench.clock_hz in
      let breaks =
        match t.entry.limit with
        | At_least least -> Float.(ns < least)
        | At_most most -> Float.(ns > most)
      in
      if breaks
      then sprintf "%s %s %s %s" (time t cycles) sign (limit_time limit_ns) word
      else
        sprintf
          "%s, inside the %s %s but not its margin"
          (time t cycles)
          (limit_time limit_ns)
          word
  in
  sprintf
    "%s: %s%s %s (%s, %s %s; %s at %g MHz, %d needed)"
    t.bench.name
    (Option.value_map t.edge ~default:"" ~f:(sprintf "edge %d, "))
    t.entry.parameter
    against
    t.entry.sheet.part
    t.entry.sheet.document
    t.entry.sheet.page
    (Option.value_map cycles ~default:"no cycles" ~f:(sprintf "%d cycles"))
    (Float.of_int t.bench.clock_hz /. 1e6)
    t.verdict.needed
;;

let ink = "#1a1a1a"
let red = "#c0392b"
let grey = "#8a8f98"

let to_svg ?(names = []) t =
  let width = 780
  and left = 90
  and lane = 56 in
  let plot = width - left - 20 in
  let measured = Option.value t.measured ~default:t.verdict.needed in
  let pad = Int.max 4 (measured / 2) in
  let lo = Int.max 0 (t.cycle - measured - pad) in
  let hi = Int.min (Array.length t.trace - 1) (t.cycle + pad) in
  let hi = Int.max hi (lo + 1) in
  let x cycle = left + ((cycle - lo) * plot / (hi - lo)) in
  let height = 60 + (lane * List.length t.pins) + 50 in
  let b = Buffer.create 2048 in
  let add fmt = ksprintf (Buffer.add_string b) fmt in
  add
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 \
     %d %d\" font-family=\"monospace\" font-size=\"12\">\n"
    width
    height
    width
    height;
  add "<rect width=\"%d\" height=\"%d\" fill=\"#ffffff\"/>\n" width height;
  add
    "<text x=\"%d\" y=\"22\" fill=\"%s\">%s</text>\n"
    left
    ink
    (String.substr_replace_all (to_line t) ~pattern:"&" ~with_:"&amp;"
     |> String.substr_replace_all ~pattern:"<" ~with_:"&lt;"
     |> String.substr_replace_all ~pattern:">" ~with_:"&gt;");
  List.iteri t.pins ~f:(fun i pin ->
    let top = 50 + (i * lane) in
    let y high = if high then top + 8 else top + lane - 14 in
    let name =
      List.Assoc.find names pin ~equal:Int.equal
      |> Option.value ~default:(sprintf "pin %d" pin)
    in
    add "<text x=\"8\" y=\"%d\" fill=\"%s\">%s</text>\n" (top + (lane / 2)) ink name;
    let points =
      (lo, level t.trace pin lo)
      :: List.filter_map
           (List.range (lo + 1) (hi + 1))
           ~f:(fun c ->
             Option.some_if
               (not (Bool.equal (level t.trace pin (c - 1)) (level t.trace pin c)))
               (c, level t.trace pin c))
    in
    let path =
      List.foldi points ~init:[] ~f:(fun j acc (c, high) ->
        if j = 0
        then [ sprintf "M%d,%d" (x c) (y high) ]
        else
          sprintf "L%d,%d" (x c) (y high) :: sprintf "L%d,%d" (x c) (y (not high)) :: acc)
      |> List.rev
    in
    add
      "<path d=\"%s L%d,%d\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\"/>\n"
      (String.concat ~sep:" " path)
      (x hi)
      (y (snd (List.last_exn points)))
      ink);
  let bottom = 50 + (lane * List.length t.pins) in
  let from_ = t.cycle - measured in
  if Option.is_some t.edge
  then (
    List.iter [ from_; t.cycle ] ~f:(fun c ->
      add
        "<line x1=\"%d\" y1=\"40\" x2=\"%d\" y2=\"%d\" stroke=\"%s\" \
         stroke-dasharray=\"4 3\"/>\n"
        (x c)
        (x c)
        (bottom + 6)
        red);
    add
      "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"%s\" stroke-width=\"2\"/>\n"
      (x from_)
      (bottom + 18)
      (x t.cycle)
      (bottom + 18)
      red;
    add
      "<text x=\"%d\" y=\"%d\" fill=\"%s\">%s</text>\n"
      (x from_)
      (bottom + 36)
      red
      (let word, _, limit_ns = side t.entry.limit in
       sprintf "%s, %s %s" (time t measured) word (limit_time limit_ns)));
  add
    "<text x=\"%d\" y=\"%d\" fill=\"%s\">cycles %d to %d at %g MHz</text>\n"
    left
    (height - 6)
    grey
    lo
    hi
    (Float.of_int t.bench.clock_hz /. 1e6);
  add "</svg>\n";
  Buffer.contents b
;;
