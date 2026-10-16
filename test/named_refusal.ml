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

(* The cycles at which [pin] changes. *)
let changes trace pin =
  List.filter
    (List.range 1 (Array.length trace))
    ~f:(fun cycle ->
      not (Bool.equal (level trace pin (cycle - 1)) (level trace pin cycle)))
;;

(* The first edge of the spacing's pins, counted over both, that comes sooner than [spec]
   asks: its number, its cycle, and the cycles it came after the nearer edge it is spaced
   from. A pin whose direction is the bit shows low when the bit is 1. *)
let spaced_edge (spec : Kernel.Spacing.Spec.t) trace =
  let bit pin cycle = Bool.equal (level trace pin cycle) spec.dirs |> not in
  let edges_a = changes trace spec.a
  and edges_b = changes trace spec.b in
  let all =
    List.map edges_a ~f:(fun cycle -> cycle, true)
    @ List.map edges_b ~f:(fun cycle -> cycle, false)
    |> List.sort ~compare:(fun (x, _) (y, _) -> Int.compare x y)
  in
  let since edges cycle =
    List.filter edges ~f:(fun c -> c < cycle)
    |> List.last
    |> Option.map ~f:(fun last -> cycle - last)
  in
  let short ~least ~edges cycle =
    Option.filter (since edges cycle) ~f:(fun since -> since < least)
  in
  List.find_mapi all ~f:(fun i (cycle, is_a) ->
    let own_pin, other_pin = if is_a then spec.a, spec.b else spec.b, spec.a in
    let own_edges, other_edges = if is_a then edges_a, edges_b else edges_b, edges_a in
    let own = bit own_pin (cycle - 1)
    and other = bit other_pin (cycle - 1) in
    let hold, apart =
      if is_a
      then spec.hold_a ~own ~other, spec.apart_a ~own ~other
      else spec.hold_b ~own ~other, spec.apart_b ~own ~other
    in
    List.filter_opt
      [ short ~least:hold ~edges:own_edges cycle
      ; short ~least:apart ~edges:other_edges cycle
      ]
    |> List.min_elt ~compare
    |> Option.map ~f:(fun measured -> i + 1, cycle, measured))
;;

(* The first of the pin's completed level runs after which [widths] holds a width that
   breaks the limit, by bisection as a width once broken stays so. *)
let run_edge (limit : Datasheet.Limit.t) ~needed ~widths trace pin =
  let runs =
    Datasheet.runs (Array.map trace ~f:(fun word -> (word lsr pin) land 1 = 1))
  in
  let broken k =
    let levels = List.take runs (k + 1) |> List.drop_last_exn in
    let widths = widths levels in
    match limit with
    | At_least _ -> List.exists widths ~f:(fun w -> w < needed)
    | At_most _ -> List.exists widths ~f:(fun w -> w > needed)
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
    let levels = List.take runs (k + 1) |> List.drop_last_exn in
    let width =
      let widths = widths levels in
      match limit with
      | At_least _ -> List.min_elt widths ~compare
      | At_most _ -> List.max_elt widths ~compare
    in
    let cycle = List.sum (module Int) (List.take runs k) ~f:snd in
    Option.map width ~f:(fun width -> k, cycle, width))
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
    (match spaced_edge spec trace with
     | Some (edge, cycle, measured) ->
       { (none ~pins ~trace) with edge = Some edge; cycle; measured = Some measured }
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

let time_ns ns =
  if Float.(abs ns < 1000.) then sprintf "%.4g ns" ns else sprintf "%.2f us" (ns /. 1000.)
;;

let ns_of t cycles = Float.of_int cycles *. 1e9 /. Float.of_int t.bench.clock_hz

let to_line t =
  let side, limit =
    match t.entry.limit with
    | At_least ns -> "min", ns
    | At_most ns -> "max", ns
  in
  let against =
    match t.measured with
    | None ->
      sprintf
        "kernel bound %s"
        (Option.value_map t.verdict.bound ~default:"none" ~f:(fun n ->
           time_ns (ns_of t n)))
    | Some cycles ->
      let ns = ns_of t cycles in
      let breaks =
        match t.entry.limit with
        | At_least least -> Float.(ns < least)
        | At_most most -> Float.(ns > most)
      in
      if breaks
      then
        sprintf
          "%s %s %s %s"
          (time_ns ns)
          (match t.entry.limit with
           | At_least _ -> "<"
           | At_most _ -> ">")
          (time_ns limit)
          side
      else
        sprintf
          "%s, inside the %s %s but not its margin"
          (time_ns ns)
          (time_ns limit)
          side
  in
  let where = Option.value_map t.edge ~default:"" ~f:(sprintf "edge %d, ") in
  sprintf
    "%s: %s%s %s (%s, %s %s; %d cycles at %g MHz, %d needed)"
    t.bench.name
    where
    t.entry.parameter
    against
    t.entry.sheet.part
    t.entry.sheet.document
    t.entry.sheet.page
    (Option.value t.measured ~default:0)
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
      (sprintf
         "%s, limit %s %s"
         (time_ns (ns_of t measured))
         (match t.entry.limit with
          | At_least _ -> "&gt;="
          | At_most _ -> "&lt;=")
         (match t.entry.limit with
          | At_least ns | At_most ns -> time_ns ns)));
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
