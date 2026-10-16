open! Core

module Level = struct
  type t =
    | Low
    | High
    | Bit
  [@@deriving sexp_of, equal]
end

module Step = struct
  type t =
    { name : string
    ; outputs : Level.t list
    ; kind : Tables.Kind.t
    ; cycles : int
    }
  [@@deriving sexp_of]
end

module Limit = struct
  type t =
    { edge : string
    ; cycles : int
    ; ns : float
    ; least_ns : float option
    ; most_ns : float option
    }
  [@@deriving sexp_of]
end

module State = struct
  type t = int [@@deriving equal, sexp_of]
end

(* info.yaml's clock *)
let rated_hz = 50_000_000
let ns ~clock_hz cycles = cycles *. 1e9 /. Float.of_int clock_hz

type t =
  { outputs : string list
  ; input : string option
  ; steps : Step.t list
  ; table : State.t Tables.t
  ; bits : int
  ; words : int list
  ; while_host : bool
  ; starts_on_edge : bool
  ; read : int
  ; limits : Limit.t list
  ; clock_hz : int
  ; diagram : Wavejson.t
  }

let outside detail =
  Error (Error.tag (Error.create_s detail) ~tag:"outside the table class")
;;

module Segment = struct
  type t =
    | Before
    | Body
    | After
  [@@deriving equal]
end

(* a period as sent: where it was drawn, and which copy of a repeat *)
module Period = struct
  type t =
    { drawn : int
    ; copy : int option
    ; segment : Segment.t
    }

  let name ?half t =
    sprintf
      "period %d%s%s"
      t.drawn
      (Option.value_map t.copy ~default:"" ~f:(fun c -> sprintf " (copy %d)" (c + 1)))
      (match half with
       | None -> ""
       | Some 0 -> ", first half"
       | Some _ -> ", second half")
  ;;
end

module Value = struct
  type t =
    | Level of bool
    | Clock of bool (** the first half's level *)
    | Data of int
end

(* one step of the diagram before it has a kind *)
module Draft = struct
  type t =
    { name : string
    ; levels : Level.t list
    ; shown : int option
    ; cycles : int
    ; time : int (** from the first step after the idle *)
    ; segment : Segment.t
    }
end

let periods ~drawn (repeat : Wavejson.Repeat.t option) =
  match repeat with
  | None ->
    Ok (List.init drawn ~f:(fun d -> { Period.drawn = d; copy = None; segment = Before }))
  | Some { first; last; times; while_host = _ } ->
    if first < 1 || last < first || last >= drawn || times < 1
    then
      outside
        [%message
          "a repeat is of drawn periods after the first, at least once"
            (first : int)
            (last : int)
            (times : int)
            ~periods:(drawn : int)]
    else (
      let range lo hi ~copy ~segment =
        List.range lo (hi + 1)
        |> List.map ~f:(fun d -> { Period.drawn = d; copy; segment })
      in
      Ok
        (range 0 (first - 1) ~copy:None ~segment:Before
         @ List.concat_map (List.range 0 times) ~f:(fun c ->
           range first last ~copy:(Some c) ~segment:Body)
         @ range (last + 1) (drawn - 1) ~copy:None ~segment:After))
;;

let lane_shape (lane : Wavejson.Lane.t) =
  if Float.(lane.phase <> 0.)
  then
    outside
      [%message
        "a phase moves a lane off the period grid, where no step can follow it"
          ~lane:lane.name
          ~phase:(lane.phase : float)]
  else if Float.(lane.period <> 1.)
  then
    outside
      [%message
        "a lane's own period is not supported; draw it in the diagram's periods"
          ~lane:lane.name
          ~period:(lane.period : float)]
  else Ok ()
;;

let char (lane : Wavejson.Lane.t) (p : Period.t) =
  if p.drawn < String.length lane.wave then lane.wave.[p.drawn] else '.'
;;

(* each period's value on an output lane, and whether a new cell starts there *)
let output_lane (lane : Wavejson.Lane.t) periods =
  let open Or_error.Let_syntax in
  let%bind () = lane_shape lane in
  let rec go acc ~previous ~bits = function
    | [] -> Ok (Array.of_list (List.rev acc))
    | p :: rest ->
      let start (v : Value.t) ~bits =
        go ((v, true) :: acc) ~previous:(Some v) ~bits rest
      in
      let refuse why =
        outside
          [%message
            why ~lane:lane.name ~at:(Period.name p : string) ~wave:(char lane p : char)]
      in
      (match char lane p with
       | '0' | 'l' | 'L' -> start (Level false) ~bits
       | '1' | 'h' | 'H' -> start (Level true) ~bits
       | 'p' | 'P' -> start (Clock true) ~bits
       | 'n' | 'N' -> start (Clock false) ~bits
       | '=' | '2' .. '9' -> start (Data bits) ~bits:(bits + 1)
       | '.' | '|' ->
         (match previous with
          | None -> refuse "a lane starts with nothing to go on from"
          | Some v -> go ((v, false) :: acc) ~previous ~bits rest)
       | 'x' -> refuse "an output needs a level, and x has none"
       | 'z' -> refuse "an output the table drives cannot float"
       | 'u' | 'd' -> refuse "an output the table drives is not pulled, it is driven"
       | _ -> refuse "not a wave character")
  in
  go [] ~previous:None ~bits:0 periods
;;

(* each period's cell of an input lane, if it is one the table reads *)
let input_lane (lane : Wavejson.Lane.t) periods =
  let open Or_error.Let_syntax in
  let%map () = lane_shape lane in
  List.folding_map periods ~init:(None, 0) ~f:(fun (previous, cells) p ->
    match char lane p with
    | '=' | '2' .. '9' -> (Some cells, cells + 1), Some cells
    | '.' | '|' -> (previous, cells), previous
    | _ -> (None, cells), None)
  |> Array.of_list
;;

module Slice = struct
  type t =
    { period : Period.t
    ; half : int option
    ; cycles : int
    ; levels : Level.t list
    ; starts : bool
    ; shown : int option
    ; cell : int option
    }
end

let slices ~periods ~cycles_of ~outputs ~input =
  List.mapi periods ~f:(fun i (p : Period.t) ->
    let here = List.map outputs ~f:(fun lane -> lane.(i)) in
    let clocked =
      List.exists here ~f:(fun ((v : Value.t), _) ->
        match v with
        | Clock _ -> true
        | Level _ | Data _ -> false)
    in
    let cycles = cycles_of p.drawn in
    if clocked && cycles % 2 = 1
    then
      outside
        [%message
          "a clock's period splits into two halves of whole cycles"
            ~at:(Period.name p : string)
            (cycles : int)]
    else (
      let halves =
        if clocked then [ Some 0, cycles / 2; Some 1, cycles / 2 ] else [ None, cycles ]
      in
      Ok
        (List.map halves ~f:(fun (half, cycles) ->
           let first = Option.value half ~default:0 = 0 in
           { Slice.period = p
           ; half
           ; cycles
           ; levels =
               List.map here ~f:(fun ((v : Value.t), _) : Level.t ->
                 match v with
                 | Level b -> if b then High else Low
                 | Clock b -> if Bool.equal b first then High else Low
                 | Data _ -> Bit)
           ; starts =
               List.exists here ~f:(fun ((v : Value.t), starts) ->
                 match v with
                 | Clock _ -> true
                 | Level _ | Data _ -> first && starts)
           ; shown =
               List.find_map here ~f:(fun ((v : Value.t), _) ->
                 match v with
                 | Data k -> Some k
                 | Level _ | Clock _ -> None)
           ; cell = Option.bind input ~f:(fun cells -> cells.(i))
           }))))
  |> Result.all
  |> Or_error.map ~f:List.concat
;;

(* consecutive slices with no new cell are one step; a loop's body starts and ends one *)
let drafts slices ~while_host =
  let finish (first : Slice.t) rest ~time =
    let cycles = List.sum (module Int) (first :: rest) ~f:(fun s -> s.cycles) in
    ( { Draft.name = Period.name ?half:first.half first.period
      ; levels = first.levels
      ; shown = first.shown
      ; cycles
      ; time
      ; segment = first.period.segment
      }
    , time + cycles )
  in
  let rec go acc ~time = function
    | [] -> List.rev acc
    | (first : Slice.t) :: rest ->
      let same, rest =
        List.split_while rest ~f:(fun (s : Slice.t) ->
          (not s.starts)
          && ((not while_host) || Segment.equal s.period.segment first.period.segment))
      in
      let draft, time = finish first same ~time in
      go (draft :: acc) ~time rest
  in
  go [] ~time:0 slices
;;

(* the input cells' spans in cycles *)
let cells (slices : Slice.t list) =
  List.folding_map slices ~init:0 ~f:(fun time s ->
    time + s.cycles, Option.map s.cell ~f:(fun c -> c, (time, time + s.cycles)))
  |> List.filter_opt
  |> Int.Map.of_alist_fold ~init:(Int.max_value, 0) ~f:(fun (lo, hi) (a, b) ->
    Int.min lo a, Int.max hi b)
;;

(* when a Shift reads in_base: 7 cycles after its outputs show *)
let sample_after = 7
let least = Tables.Kind.least
let kind_name (kind : Tables.Kind.t) = Sexp.to_string (Tables.Kind.sexp_of_t kind)

(* For each bit, the first step that may move the host bit on and is long enough: from the
   last showing the bit to before the first showing the next, reading inside the bit's
   input cell. The last bit of a word but the frame's last pulls the next word. *)
let place_shifts
  (drafts : Draft.t array)
  ~bits
  ~read
  ~(cells : (int * int) Int.Map.t)
  ~word_ends
  ~while_host
  =
  let open Or_error.Let_syntax in
  let count = Array.length drafts in
  let kinds = Array.create ~len:count Tables.Kind.Plain in
  let shows k =
    Array.filter_mapi drafts ~f:(fun i d ->
      Option.bind d.shown ~f:(fun b -> Option.some_if (b = k) i))
  in
  let body =
    Array.filter_mapi drafts ~f:(fun i d ->
      Option.some_if (Segment.equal d.segment Body) i)
  in
  let pick ~what ~lo ~hi ~(kind : Tables.Kind.t) ~cell ~optional =
    let fits i =
      drafts.(i).cycles >= least kind
      && Option.value_map cell ~default:true ~f:(fun (a, b) ->
        let at = drafts.(i).time + sample_after in
        a <= at && at < b)
    in
    match List.find (List.range lo (hi + 1)) ~f:fits with
    | Some i ->
      kinds.(i) <- kind;
      Ok (Some i)
    | None when optional -> Ok None
    | None ->
      let steps =
        if lo > hi || lo >= count
        then "none"
        else if lo = hi
        then drafts.(lo).name
        else [%string "%{drafts.(lo).name} to %{drafts.(hi).name}"]
      in
      let reading =
        if Option.is_some cell then ", reading inside its input cell" else ""
      in
      outside
        [%message
          [%string
            "%{what} has no step to move the host bit on: a %{kind_name kind} needs \
             %{least kind#Int} cycles%{reading}"]
            (steps : string)]
  in
  let%bind after_flag =
    if not while_host
    then Ok (-1)
    else (
      let head = body.(0) in
      let first_shown = (shows 0).(0) in
      let%map at =
        pick
          ~what:"the host's flag before a pass"
          ~lo:head
          ~hi:(first_shown - 1)
          ~kind:Shift
          ~cell:None
          ~optional:false
      in
      Option.value_exn at)
  in
  let n = Int.max bits read in
  let%map (_ : int) =
    List.fold_result (List.range 0 n) ~init:after_flag ~f:(fun previous k ->
      let shown = if k < bits then shows k else [||] in
      let lo =
        Int.max (previous + 1) (if Array.is_empty shown then 0 else Array.last_exn shown)
      in
      let hi =
        if k + 1 < bits
        then (shows (k + 1)).(0) - 1
        else if while_host
        then Array.last_exn body
        else count - 1
      in
      let last = k = n - 1 in
      let kind : Tables.Kind.t =
        if (while_host && last) || ((not last) && List.mem word_ends k ~equal:Int.equal)
        then Pull
        else Shift
      in
      let%map at =
        pick
          ~what:[%string "bit %{k#Int}"]
          ~lo
          ~hi
          ~kind
          ~cell:(Map.find cells k)
          ~optional:(last && read = 0 && not while_host)
      in
      Option.value at ~default:previous)
  in
  kinds
;;

let check_cycles (steps : Step.t list) =
  List.map steps ~f:(fun { name; kind; cycles; outputs = _ } ->
    if cycles < least kind
    then
      outside
        [%message
          [%string "a %{kind_name kind} step lasts at least %{least kind#Int} cycles"]
            ~at:(name : string)
            (cycles : int)]
    else if cycles > least kind + Tables.max_hold
    then
      outside
        [%message
          [%string
            "a %{kind_name kind} step lasts at most %{least kind + Tables.max_hold#Int} \
             cycles"]
            ~at:(name : string)
            (cycles : int)]
    else Ok ())
  |> Result.all_unit
;;

let split_unit token =
  let number =
    String.take_while token ~f:(fun c -> Char.is_digit c || Char.equal c '.')
  in
  number, String.drop_prefix token (String.length number)
;;

(* "400ns", "0.4us" or "20cycles", in ns; [unit] where the token has none *)
let quantity ?(unit = "") ~clock_hz token =
  let number, given = split_unit token in
  let%bind.Option n = Float.of_string_opt number in
  match if String.is_empty given then unit else given with
  | "ns" -> Some n
  | "us" -> Some (n *. 1000.)
  | "cycle" | "cycles" -> Some (ns ~clock_hz n)
  | _ -> None
;;

(* the bounds a label sets, if any: a number and its unit may stand apart *)
let bounds ~clock_hz label =
  let rec join = function
    | n :: unit :: rest
      when Option.is_some (Float.of_string_opt n)
           && List.mem [ "ns"; "us"; "cycle"; "cycles" ] unit ~equal:String.equal ->
      (n ^ unit) :: join rest
    | t :: rest -> t :: join rest
    | [] -> []
  in
  let rec go = function
    | [] -> None
    | ((">=" | "<=" | "=") as op) :: q :: _ ->
      Option.map (quantity ~clock_hz q) ~f:(fun q ->
        match op with
        | ">=" -> Some q, None
        | "<=" -> None, Some q
        | _ -> Some q, Some q)
    | t :: rest ->
      (match String.substr_index t ~pattern:".." with
       | Some i ->
         let hi = String.drop_prefix t (i + 2) in
         (match
            ( quantity ~unit:(snd (split_unit hi)) ~clock_hz (String.prefix t i)
            , quantity ~clock_hz hi )
          with
          | Some lo, Some hi -> Some (Some lo, Some hi)
          | _ -> go rest)
       | None ->
         (match quantity ~clock_hz t with
          | Some q -> Some (Some q, Some q)
          | None -> go rest))
  in
  String.split label ~on:' ' |> List.filter ~f:(Fn.non String.is_empty) |> join |> go
;;

(* The time between two nodes is the drawn periods' cycles between them, as every step is
   exact; one at the idle, or a pair across a whole repeat, has no such time. *)
let limits
  ~clock_hz
  (lanes : Wavejson.Lane.t list)
  edges
  ~cycles_of
  ~idle
  ~(repeat : Wavejson.Repeat.t option)
  =
  let node c = List.find_map lanes ~f:(fun l -> String.index l.node c) in
  List.filter_map edges ~f:(fun edge ->
    let arrow =
      String.drop_prefix edge 1 |> String.take_while ~f:(fun c -> String.mem "-~<>|+" c)
    in
    let rest = String.drop_prefix edge (1 + String.length arrow) in
    if String.length edge < 2 || String.is_empty rest
    then None
    else (
      let label = String.drop_prefix rest 1 |> String.strip in
      Option.map (bounds ~clock_hz label) ~f:(fun (least_ns, most_ns) ->
        match node edge.[0], node rest.[0] with
        | None, _ | _, None ->
          outside [%message "an edge names a node no lane has" (edge : string)]
        | Some a, Some b ->
          let a, b = Int.min a b, Int.max a b in
          if idle && a = 0
          then
            outside
              [%message
                "an edge from the idle, whose length is the host's" (edge : string)]
          else if Option.exists repeat ~f:(fun r -> a < r.first && b > r.last)
          then outside [%message "an edge across a whole repeat" (edge : string)]
          else (
            let cycles = List.sum (module Int) (List.range a b) ~f:cycles_of in
            let ns = ns ~clock_hz (Float.of_int cycles) in
            let holds =
              Option.for_all least_ns ~f:(fun l -> Float.(ns >= l))
              && Option.for_all most_ns ~f:(fun m -> Float.(ns <= m))
            in
            if holds
            then Ok { Limit.edge; cycles; ns; least_ns; most_ns }
            else
              outside
                [%message
                  "the diagram's own limit does not hold"
                    (edge : string)
                    (cycles : int)
                    (ns : float)
                    (least_ns : float option)
                    (most_ns : float option)]))))
  |> Result.all
;;

let drawn (diagram : Wavejson.t) =
  List.map diagram.lanes ~f:(fun (l : Wavejson.Lane.t) -> String.length l.wave)
  |> List.max_elt ~compare
  |> Option.value ~default:0
;;

let cycles_of (diagram : Wavejson.t) ~drawn =
  match diagram.cycles with
  | Every c -> Ok (Fn.const c)
  | Each cs when List.length cs = drawn -> Ok (List.nth_exn cs)
  | Each cs ->
    outside
      [%message
        "table.cycles has one number a drawn period"
          ~numbers:(List.length cs : int)
          ~periods:(drawn : int)]
;;

let step name outputs kind cycles = { Step.name; outputs; kind; cycles }

let check_steps steps =
  let states = Tables.Wiring.states Tables.Wiring.default in
  if List.length steps > states
  then
    outside
      [%message
        [%string "a table holds %{states#Int} steps, a repeat with the host's flag fewer"]
          ~steps:(List.length steps : int)]
  else check_cycles steps
;;

(* A pass's last step goes back to its head, which on the host's flag of 0 is the step
   after the pass; -1 for neither. *)
let table_of (steps : Step.t array) ~head ~tail =
  let count = Array.length steps in
  let entry state ~host_bit =
    let state = if state = head && not host_bit then (tail + 1) % count else state in
    let ({ outputs; kind; cycles; name = _ } : Step.t) = steps.(state) in
    { Tables.Step.outputs =
        List.foldi outputs ~init:0 ~f:(fun i acc (level : Level.t) ->
          let on =
            match level with
            | High -> true
            | Low -> false
            | Bit -> host_bit
          in
          acc lor (Bool.to_int on lsl i))
    ; kind
    ; cycles
    ; next = (if state = tail then head else (state + 1) % count)
    }
  in
  let table =
    { Tables.name = "wavedrom"
    ; wiring = Tables.Wiring.default
    ; state = (module State)
    ; states = List.range 0 count
    ; step = (fun state ~host_bit ~inputs:_ -> entry state ~host_bit)
    }
  in
  let%map.Or_error (_ : int list) = Tables.words table in
  table
;;

let compile_on_host
  ~clock_hz
  (diagram : Wavejson.t)
  ~(lanes : Wavejson.Lane.t list)
  ~(outputs : Wavejson.Lane.t list)
  ~(input : Wavejson.Lane.t option)
  ~drawn
  ~cycles_of
  =
  let open Or_error.Let_syntax in
  let%bind () =
    if List.is_empty outputs then outside [%message "no output lane"] else Ok ()
  in
  let%bind periods = periods ~drawn diagram.repeat in
  let while_host =
    Option.value_map diagram.repeat ~default:false ~f:(fun r -> r.while_host)
  in
  let%bind values = List.map outputs ~f:(fun l -> output_lane l periods) |> Result.all in
  let%bind cells_read =
    match input with
    | None -> Ok None
    | Some lane -> input_lane lane periods >>| Option.some
  in
  let%bind () =
    match
      List.filter_map
        (List.zip_exn outputs values)
        ~f:(fun ((l : Wavejson.Lane.t), cells) ->
          Option.some_if
            (Array.exists cells ~f:(fun ((v : Value.t), _) ->
               match v with
               | Data _ -> true
               | Level _ | Clock _ -> false))
            l.name)
    with
    | [] | [ _ ] -> Ok ()
    | lanes ->
      outside
        [%message
          "a table shows one host bit at a time, on one lane" (lanes : string list)]
  in
  let%bind slices = slices ~periods ~cycles_of ~outputs:values ~input:cells_read in
  let bits =
    List.filter_map slices ~f:(fun (s : Slice.t) -> s.shown)
    |> List.max_elt ~compare
    |> Option.value_map ~default:0 ~f:succ
  in
  let read =
    List.filter_map slices ~f:(fun (s : Slice.t) -> s.cell)
    |> List.max_elt ~compare
    |> Option.value_map ~default:0 ~f:succ
  in
  (* with data, the first period is the idle shown while the host's word is awaited *)
  let%bind idle, slices =
    if bits = 0 && read = 0
    then Ok (None, slices)
    else (
      match slices with
      | ({ period = { drawn = 0; _ }; half = None; shown = None; cell = None; _ } as s)
        :: rest -> Ok (Some s.levels, rest)
      | _ ->
        outside
          [%message
            "the first period is the idle shown while the host's word is awaited: levels \
             only"])
  in
  let%bind () =
    if read > 0 && bits > 0 && read <> bits
    then
      outside
        [%message
          "a table reads a bit with each bit it sends" ~sent:(bits : int) (read : int)]
    else if read > Isa.data_bits
    then outside [%message "a Push takes 16 bits read" (read : int)]
    else if while_host && read > 0
    then outside [%message "a frame the host repeats reads nothing"]
    else if while_host && bits = 0
    then outside [%message "a pass the host repeats sends a host bit"]
    else if while_host && bits >= Isa.data_bits
    then
      outside
        [%message
          "a pass is one host word: its flag and at most 15 bits"
            ~bits_a_pass:(bits : int)]
    else if while_host
            && List.exists slices ~f:(fun (s : Slice.t) ->
              Option.is_some s.shown && not (Segment.equal s.period.segment Body))
    then outside [%message "a frame the host repeats sends bits only in its pass"]
    else Ok ()
  in
  let%bind words =
    if while_host
    then Ok [ bits + 1 ]
    else (
      match diagram.words with
      | None ->
        Ok (List.init ((bits + 15) / 16) ~f:(fun i -> Int.min 16 (bits - (16 * i))))
      | Some words ->
        if List.sum (module Int) words ~f:Fn.id <> bits
           || List.exists words ~f:(fun w -> w < 1 || w > 16)
        then
          outside
            [%message
              "table.words are 1 to 16 bits each, the frame's bits in all"
                (words : int list)
                (bits : int)]
        else Ok words)
  in
  let%bind () =
    if read > 0 && List.length words > 1
    then
      outside [%message "a Pull of the next word drops the bits read" (words : int list)]
    else Ok ()
  in
  let word_ends = List.folding_map words ~init:0 ~f:(fun at w -> at + w, at + w - 1) in
  let drafts = Array.of_list (drafts slices ~while_host) in
  let%bind kinds =
    place_shifts drafts ~bits ~read ~cells:(cells slices) ~word_ends ~while_host
  in
  let steps =
    Option.value_map idle ~default:[] ~f:(fun levels ->
      [ step "idle" levels Await_host (least Await_host) ])
    @ Array.to_list
        (Array.mapi drafts ~f:(fun i d -> step d.name d.levels kinds.(i) d.cycles))
    @
    match idle with
    | Some levels when read > 0 -> [ step "push" levels Push (least Push) ]
    | _ -> []
  in
  let%bind () = check_steps steps in
  let%bind limits =
    limits
      ~clock_hz
      lanes
      diagram.edges
      ~cycles_of
      ~idle:(Option.is_some idle)
      ~repeat:diagram.repeat
  in
  let offset = if Option.is_some idle then 1 else 0 in
  let head, tail =
    if not while_host
    then -1, -1
    else (
      let body =
        Array.filter_mapi drafts ~f:(fun i d ->
          Option.some_if (Segment.equal d.segment Body) (i + offset))
      in
      body.(0), Array.last_exn body)
  in
  let%map table = table_of (Array.of_list steps) ~head ~tail in
  { outputs = List.map outputs ~f:(fun (l : Wavejson.Lane.t) -> l.name)
  ; input = Option.map input ~f:(fun (l : Wavejson.Lane.t) -> l.name)
  ; steps
  ; table
  ; bits
  ; words
  ; while_host
  ; starts_on_edge = false
  ; read
  ; limits
  ; clock_hz
  ; diagram
  }
;;

let level_char = function
  | '0' | 'l' | 'L' -> Some false
  | '1' | 'h' | 'H' -> Some true
  | _ -> None
;;

(* An input lane that starts at a level and leaves it before its first cell starts each
   frame on that edge: the period of the change, and the level after it. *)
let input_edge (lane : Wavejson.Lane.t) =
  let%bind.Option first_cell =
    String.lfindi lane.wave ~f:(fun _ c ->
      match c with
      | '=' | '2' .. '9' -> true
      | _ -> false)
  in
  let%bind.Option idle = level_char lane.wave.[0] in
  List.find_map (List.range 1 first_cell) ~f:(fun p ->
    Option.bind
      (level_char lane.wave.[p])
      ~f:(fun level -> Option.some_if (not (Bool.equal level idle)) (p, level)))
;;

(* An Await's cycles count from 2 after the pin's edge: Tables.uart_rx's [3 * bit / 2 - 9]
   puts its first read at the middle of bit 0 so. *)
let edge_seen = 2

(* A frame an input's edge starts: an Await for the edge, a Shift at the middle of each
   cell, the last held a cell's length, then a Push and back to the Await. *)
let compile_on_edge
  ~clock_hz
  (diagram : Wavejson.t)
  ~lanes
  ~(outputs : Wavejson.Lane.t list)
  ~(input : Wavejson.Lane.t)
  ~drawn
  ~cycles_of
  ~edge:(at, level)
  =
  let open Or_error.Let_syntax in
  let%bind () =
    if not (List.is_empty outputs)
    then
      outside
        [%message
          "a frame an input's edge starts only reads, so outputs need a frame the host \
           starts"
            ~outputs:
              (List.map outputs ~f:(fun (l : Wavejson.Lane.t) -> l.name) : string list)]
    else if Option.is_some diagram.repeat
    then outside [%message "a frame an input's edge starts has no repeat"]
    else Ok ()
  in
  let%bind periods = periods ~drawn None in
  let%bind cells = input_lane input periods in
  let from_edge p = List.sum (module Int) (List.range at p) ~f:cycles_of in
  let spans =
    Array.to_list cells
    |> List.filter_mapi ~f:(fun p cell ->
      Option.map cell ~f:(fun c -> c, (from_edge p, from_edge (p + 1))))
    |> Int.Map.of_alist_fold ~init:(Int.max_value, 0) ~f:(fun (lo, hi) (a, b) ->
      Int.min lo a, Int.max hi b)
    |> Map.data
  in
  let read = List.length spans in
  let%bind () =
    if read > Isa.data_bits
    then outside [%message "a Push takes 16 bits read" (read : int)]
    else Ok ()
  in
  let middle (lo, hi) = (lo + hi) / 2 in
  let first = List.hd_exn spans in
  let reads =
    List.mapi spans ~f:(fun k span ->
      let next =
        match List.nth spans (k + 1) with
        | Some next -> middle next
        | None -> middle span + snd span - fst span
      in
      step [%string "bit %{k#Int} read"] [] Shift (next - middle span))
  in
  let steps =
    (step
       [%string "the edge, period %{at#Int}"]
       []
       (Await { pin = A; level })
       (middle first - sample_after - edge_seen)
     :: reads)
    @ [ step "push" [] Push (least Push) ]
  in
  let%bind () = check_steps steps in
  let%bind limits =
    limits ~clock_hz lanes diagram.edges ~cycles_of ~idle:true ~repeat:None
  in
  let%map table = table_of (Array.of_list steps) ~head:(-1) ~tail:(-1) in
  { outputs = []
  ; input = Some input.name
  ; steps
  ; table
  ; bits = 0
  ; words = []
  ; while_host = false
  ; starts_on_edge = true
  ; read
  ; limits
  ; clock_hz
  ; diagram
  }
;;

let compile ?(clock_hz = rated_hz) (diagram : Wavejson.t) =
  let open Or_error.Let_syntax in
  let lanes =
    List.mapi diagram.lanes ~f:(fun i (l : Wavejson.Lane.t) ->
      if String.is_empty l.name then { l with name = sprintf "lane %d" i } else l)
  in
  let outputs, inputs =
    List.partition_tf lanes ~f:(fun (l : Wavejson.Lane.t) -> not l.input)
  in
  let%bind () =
    if List.length outputs > Tables.output_bits
    then
      outside
        [%message
          [%string "a table drives %{Tables.output_bits#Int} outputs"]
            ~lanes:(List.length outputs : int)]
    else if List.length inputs > 1
    then
      outside
        [%message
          "a Shift reads one input pin"
            ~lanes:
              (List.map inputs ~f:(fun (l : Wavejson.Lane.t) -> l.name) : string list)]
    else Ok ()
  in
  let drawn = drawn diagram in
  let%bind cycles_of = cycles_of diagram ~drawn in
  match inputs with
  | [ input ] when Option.is_some (input_edge input) ->
    compile_on_edge
      ~clock_hz
      diagram
      ~lanes
      ~outputs
      ~input
      ~drawn
      ~cycles_of
      ~edge:(Option.value_exn (input_edge input))
  | _ ->
    compile_on_host
      ~clock_hz
      diagram
      ~lanes
      ~outputs
      ~input:(List.hd inputs)
      ~drawn
      ~cycles_of
;;

let of_string ?clock_hz s = Or_error.bind (Wavejson.parse s) ~f:(compile ?clock_hz)

let host_words t bits =
  let n = List.length bits in
  if t.while_host
  then
    if n % t.bits <> 0
    then Or_error.error_s [%message "whole passes" ~bits:(n : int) ~a_pass:(t.bits : int)]
    else
      Ok
        (List.map (List.chunks_of bits ~length:t.bits) ~f:(fun pass ->
           Tables.host_bits (true :: pass))
         @ [ 0 ])
  else if n <> t.bits
  then
    Or_error.error_s [%message "a frame's bits" ~bits:(n : int) ~a_frame:(t.bits : int)]
  else if t.bits = 0
  then Ok (if t.read > 0 && not t.starts_on_edge then [ 0 ] else [])
  else
    Ok
      (List.folding_map t.words ~init:bits ~f:(fun rest w ->
         List.drop rest w, Tables.host_bits (List.take rest w)))
;;

let read_bits t word =
  List.init t.read ~f:(fun i -> (word lsr (t.read - 1 - i)) land 1 = 1)
;;

let line t frames =
  let open Or_error.Let_syntax in
  let%bind lane =
    match List.find t.diagram.lanes ~f:(fun (l : Wavejson.Lane.t) -> l.input) with
    | Some lane when t.starts_on_edge -> Ok lane
    | _ ->
      Or_error.error_s [%message "only a frame an input's edge starts has a line to draw"]
  in
  let drawn = drawn t.diagram in
  let%bind cycles_of = cycles_of t.diagram ~drawn in
  let%bind periods = periods ~drawn None in
  let%bind cells = input_lane lane periods in
  let idle = level_char lane.wave.[0] |> Option.value_exn in
  let hold level p = List.init (cycles_of p) ~f:(Fn.const level) in
  let%map frames =
    List.map frames ~f:(fun bits ->
      if List.length bits <> t.read
      then
        Or_error.error_s
          [%message
            "a frame's bits" ~bits:(List.length bits : int) ~a_frame:(t.read : int)]
      else
        Ok
          (hold idle 0
           :: List.folding_map (List.range 1 drawn) ~init:idle ~f:(fun previous p ->
             let level =
               match cells.(p) with
               | Some k -> List.nth_exn bits k
               | None ->
                 let c = if p < String.length lane.wave then lane.wave.[p] else '.' in
                 Option.value (level_char c) ~default:previous
             in
             level, hold level p)
           |> List.concat))
    |> Or_error.all
  in
  List.concat frames @ hold idle 0 |> Array.of_list
;;

let image t =
  let open Or_error.Let_syntax in
  let%bind timed =
    Tables.check t.table.wiring
    |> Result.map_error ~f:(fun r -> r.Timed_program.Refusal.error)
  in
  let%map data = Tables.words t.table in
  Timed_program.config timed, Timed_program.words timed, data
;;

let simulate t ~host_words ~inputs ~cycles =
  let open Or_error.Let_syntax in
  let%bind config, program, data = image t in
  let%bind machine = Machine.create ~config ~program in
  let%map machine = Machine.load_data machine data in
  let mask = (1 lsl List.length t.outputs) - 1 in
  let levels = Array.create ~len:cycles 0 in
  let read = Queue.create () in
  let rec go (m : Machine.t) pending c =
    if c = cycles
    then m
    else (
      let m, pending =
        match pending with
        | w :: rest when List.length m.tx_fifo < Machine.fifo_depth ->
          (match Machine.write_tx m w with
           | Ok m -> m, rest
           | Error _ -> m, pending)
        | _ -> m, pending
      in
      let m = Machine.step m ~inputs:(inputs c) in
      let m =
        match Machine.read_rx m with
        | Some (w, m) ->
          Queue.enqueue read w;
          m
        | None -> m
      in
      levels.(c) <- (m.pin_out lsr t.table.wiring.out_base) land mask;
      go m pending (c + 1))
  in
  let m = go machine host_words 0 in
  levels, Queue.to_list read, m.fault
;;
