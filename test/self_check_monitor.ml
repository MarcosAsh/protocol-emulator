open! Core
open Protocol_emulator

(* [Self_check.checker] against a reference monitor that is its contract, on waveforms
   made by moving, dropping, adding and pulsing the edges of certified frames. *)

let pin = 0
let config = Self_check.checker_config ~pin
let programs = Int.Table.create ()

let program base =
  Hashtbl.find_or_add programs base ~default:(fun () ->
    Asm.assemble (Self_check.checker ~pin ~base) |> ok_exn)
;;

(* The cycle the checker first looks for the line high in. *)
let watch_from = 7

module Wave = struct
  (* The level the checker samples in each cycle; past the end the line idles high. *)
  type t = Bytes.t

  let get (w : t) i =
    if i < 0 || i >= Bytes.length w then 1 else Char.to_int (Bytes.get w i)
  ;;

  let set (w : t) i v =
    if i >= 0 && i < Bytes.length w then Bytes.set w i (Char.of_int_exn v)
  ;;

  let moves w c = get w c <> get w (c - 1)

  let next_fall (w : t) ~from =
    let rec go c =
      if c >= Bytes.length w then None else if get w c = 0 then Some c else go (c + 1)
    in
    go from
  ;;
end

module Reference = struct
  module Kind = struct
    type t =
      | By of int (** the checker raises its irq by this cycle *)
      | Pending (** before a least with no frame after it, so never seen *)
      | Alias (** blind, as [Self_check.checker] states *)
    [@@deriving sexp_of, compare, equal]
  end

  type t =
    { at : int
    ; kind : Kind.t
    }
  [@@deriving sexp_of]

  (* A frame starts at the first low cycle from the least on, or for the first, after the
     line is first high from [watch_from]. Inside it the line moves only at an edge, and
     it is high by the next least. A move in the four cycles before the least is seen when
     the next frame starts; one before those, by the cycle before the least. After a fall
     at [watch_from], the first frame is blind from a fall [2^16 k] cycles after it. *)
  let violations ~edges (w : Wave.t) =
    let m = Array.length edges in
    let least = edges.(m - 1) in
    let last = edges.(m - 2) in
    let inner = Int.Set.of_array (Array.sub edges ~pos:0 ~len:(m - 1)) in
    let stale = Wave.get w (watch_from - 1) = 1 && Wave.get w watch_from = 0 in
    let rec from ~least_at ~first acc =
      match Wave.next_fall w ~from:least_at with
      | None -> List.rev acc
      | Some f ->
        let e = f + least in
        let next = Wave.next_fall w ~from:e in
        let blind_from =
          if first && stale
          then
            List.range (f + 1) e
            |> List.find ~f:(fun c ->
              (c - watch_from) % (1 lsl 16) = 0 && Wave.moves w c && Wave.get w c = 0)
          else None
        in
        let kind v =
          if Option.exists blind_from ~f:(fun b -> v >= b)
          then Kind.Alias
          else if v <= e - 5
          then Kind.By (e - 1)
          else (
            match next with
            | None -> Pending
            | Some r ->
              if v = e - 1 && Wave.get w e = 1 && (r - v) % (1 lsl 16) = 0
              then Alias
              else By (r + 10))
        in
        let moves =
          List.range (f + 1) e
          |> List.filter ~f:(fun c -> Wave.moves w c && not (Set.mem inner (c - f)))
        in
        let ends_low = if Wave.get w (f + last) = 0 then [ f + last ] else [] in
        let found =
          List.map (moves @ ends_low) ~f:(fun at -> { at; kind = kind at })
          |> List.sort ~compare:(Comparable.lift Int.compare ~f:(fun v -> v.at))
        in
        let acc = List.rev_append found acc in
        if List.for_all found ~f:(fun v -> Kind.equal v.kind Alias) && e < Bytes.length w
        then from ~least_at:e ~first:false acc
        else List.rev acc
    in
    let rec high c =
      if c >= Bytes.length w || Wave.get w c = 1 then c else high (c + 1)
    in
    from ~least_at:(high watch_from + 1) ~first:true []
  ;;
end

module Run = struct
  type t =
    { irq_at : int option
    ; missed_deadline : bool
    }
  [@@deriving sexp_of]
end

let data ~base ~edges =
  List.init base ~f:(fun _ -> 0) @ (Self_check.rows ~base (Array.to_list edges) |> ok_exn)
;;

let run_model ~base ~edges (w : Wave.t) : Run.t =
  let program = program base in
  let m =
    Machine.create
      ~config:(Asm.Program.configure program config)
      ~program:(Asm.Program.words program |> ok_exn)
    |> ok_exn
  in
  let m = Machine.load_data m (data ~base ~edges) |> ok_exn in
  let rec go (m : Machine.t) i =
    if m.irq || i >= Bytes.length w
    then (
      let irq_at = Option.some_if m.irq (i - 1) in
      { Run.irq_at; missed_deadline = m.fault.missed_deadline })
    else go (Machine.step m ~inputs:(Wave.get w i lsl pin)) (i + 1)
  in
  go m 0
;;

let run_rtl ~base ~edges (w : Wave.t) =
  let program = program base in
  let system, mismatch =
    System_lockstep.run
      ~cycles:(Bytes.length w)
      ~pads:(fun i -> Wave.get w i lsl pin)
      [ { config = Asm.Program.configure program config
        ; program = Asm.Program.words program |> ok_exn
        ; preload = []
        ; data = data ~base ~edges
        ; assumptions =
            { System_lockstep.Assumptions.none with
              period_floor = Some Self_check.min_gap
            }
        }
      ]
  in
  (List.hd_exn system.engines).irq, Option.is_none mismatch
;;

module Verdict = struct
  type t =
    | Quiet
    | Caught
    | Unseen of Reference.Kind.t
    | Missed of int (** a violation the contract says is seen, not seen in time *)
    | False_alarm of int
    | Missed_deadline
  [@@deriving sexp_of, compare]
end

let judge ~(reference : Reference.t list) (run : Run.t) : Verdict.t =
  let must =
    List.find_map reference ~f:(fun v ->
      match v.kind with
      | By by -> Some by
      | Pending | Alias -> None)
  in
  if run.missed_deadline
  then Missed_deadline
  else (
    match run.irq_at, reference with
    | Some at, [] -> False_alarm at
    | Some at, first :: _ ->
      if at < first.at
      then False_alarm at
      else (
        match must with
        | Some by when at > by -> Missed by
        | _ -> Caught)
    | None, [] -> Quiet
    | None, first :: _ ->
      (match must with
       | Some by -> Missed by
       | None -> Unseen first.kind))
;;

(* Frames on a waveform: each starts at [starts.(j)], and holds [levels.(j).(k)] from edge
   [k - 1], or its start, to edge [k]. *)
module Case = struct
  type mutation =
    | Pulse of
        { at : int
        ; width : int
        }
    | Shift of
        { at : int
        ; by : int
        }
    | Missing of { at : int }
  [@@deriving sexp_of]

  type t =
    { edges : int array
    ; base : int
    ; starts : int array
    ; levels : int array array
    ; mutations : mutation list
    ; cycles : int
    }
  [@@deriving sexp_of]

  let nominal c =
    let w = Bytes.make c.cycles '\001' in
    Array.iteri c.starts ~f:(fun j f ->
      Array.iteri c.edges ~f:(fun k hi ->
        let lo = if k = 0 then 0 else c.edges.(k - 1) in
        for i = f + lo to f + hi - 1 do
          Wave.set w i c.levels.(j).(k)
        done));
    w
  ;;

  let next_move w c =
    let rec go i = if i >= Bytes.length w || Wave.moves w i then i else go (i + 1) in
    go (c + 1)
  ;;

  let apply nominal w = function
    | Pulse { at; width } ->
      for i = at to at + width - 1 do
        Wave.set w i (1 - Wave.get w i)
      done
    | Shift { at; by } ->
      let before = Wave.get nominal (at - 1) in
      let after = Wave.get nominal at in
      if by > 0
      then
        for i = at to at + by - 1 do
          Wave.set w i before
        done
      else
        for i = at + by to at - 1 do
          Wave.set w i after
        done
    | Missing { at } ->
      let before = Wave.get nominal (at - 1) in
      for i = at to next_move nominal at - 1 do
        Wave.set w i before
      done
  ;;

  let wave c =
    let nominal = nominal c in
    let w = Bytes.copy nominal in
    List.iter c.mutations ~f:(apply nominal w);
    w
  ;;

  (* Back to back from [lead_in], each [idle] after the last's least. *)
  let frames ?(base = 0) ?(lead_in = 100) ?(idle = []) ?(mutations = []) edges levels =
    let least = edges.(Array.length edges - 1) in
    let starts =
      List.folding_map idle ~init:lead_in ~f:(fun at gap ->
        at + least + gap, at + least + gap)
      |> List.cons lead_in
      |> Array.of_list
    in
    let cycles = starts.(Array.length starts - 1) + (2 * least) + 300 in
    { edges
    ; base
    ; starts
    ; levels = Array.map starts ~f:(fun _ -> levels)
    ; mutations
    ; cycles
    }
  ;;
end

let check (c : Case.t) =
  let w = Case.wave c in
  let reference = Reference.violations ~edges:c.edges w in
  let run = run_model ~base:c.base ~edges:c.edges w in
  judge ~reference run, reference, run
;;

module Gen = struct
  let rand rs lo hi = lo + Random.State.int rs (hi - lo + 1)
  let span = 1 lsl 14

  (* Edges the rows take, some gaps at the least, the frame sometimes near [span]. *)
  let rec edges rs ~long =
    let n = rand rs 2 10 in
    let least_first = Self_check.min_gap + 12 in
    let first =
      if Random.State.bool rs
      then rand rs least_first (least_first + 8)
      else rand rs least_first 2000
    in
    let least_span = first + (Self_check.min_gap * (n - 1)) + 3 in
    let last =
      match Random.State.int rs (if long then 5 else 3) with
      | 0 -> least_span + rand rs 0 3000
      | 1 | 2 -> least_span + rand rs 0 200
      | 3 -> rand rs (span / 2) (span - 1)
      | _ -> rand rs (span - 40) (span - 1)
    in
    if last < least_span
    then edges rs ~long
    else (
      let slack = last - least_span in
      let cuts =
        List.init (n - 2) ~f:(fun _ ->
          if Random.State.int rs 3 = 0 then 0 else Random.State.int rs (slack + 1))
        |> List.sort ~compare
      in
      let bounds = (0 :: cuts) @ [ slack ] in
      let extra =
        List.map2_exn (List.drop_last_exn bounds) (List.tl_exn bounds) ~f:(fun a b ->
          b - a)
        |> List.permute ~random_state:rs
      in
      let later =
        List.folding_mapi extra ~init:first ~f:(fun k at x ->
          let at = at + Self_check.min_gap + x + if k = n - 2 then 3 else 0 in
          at, at)
      in
      let found = Array.of_list (first :: later) in
      let base = rand rs 0 ((1 lsl Isa.data_addr_bits) - n - 2) in
      match Self_check.rows ~base (Array.to_list found) with
      | Ok _ -> found, base
      | Error _ -> edges rs ~long)
  ;;

  let case rs ~long : Case.t =
    let edges, base = edges rs ~long in
    let n = Array.length edges in
    let frames = rand rs 1 3 in
    let idle =
      List.init (frames - 1) ~f:(fun _ ->
        match Random.State.int rs 8 with
        | 0 | 1 -> 0
        | 2 | 3 -> rand rs 1 20
        | 4 -> rand rs 21 3000
        | 5 when long ->
          (* the next frame's first edge 2^16 after the cycle before the least *)
          (1 lsl 16) - 1 + rand rs (-1) 1
        | _ -> rand rs 0 8)
    in
    let c =
      Case.frames ~base ~lead_in:(rand rs 40 300) ~idle edges (Array.create ~len:n 0)
    in
    let levels =
      Array.map c.starts ~f:(fun _ ->
        Array.init n ~f:(fun k ->
          if k = 0 then 0 else if k = n - 1 then 1 else Random.State.int rs 2))
    in
    { c with levels }
  ;;

  let mutation rs (c : Case.t) : string * Case.mutation =
    let w = Case.nominal c in
    let moves =
      List.range 1 (Bytes.length w) |> List.filter ~f:(Wave.moves w) |> Array.of_list
    in
    let frames = Array.length c.starts in
    let j = Random.State.int rs frames in
    let n = Array.length c.edges in
    let check () = c.starts.(j) + c.edges.(Random.State.int rs n) in
    let least () = c.starts.(j) + c.edges.(n - 1) in
    let width () = rand rs 1 3 in
    let horizon = c.starts.(frames - 1) + c.edges.(n - 1) + 10 in
    match Random.State.int rs 12 with
    | 0 -> "pulse at a check", Pulse { at = check () + rand rs (-3) 7; width = 1 }
    | 1 ->
      "pulse near a check", Pulse { at = check () + rand rs (-8) 14; width = width () }
    | 2 ->
      "pulse at the least", Pulse { at = least () + rand rs (-8) 3; width = width () }
    | 3 ->
      "pulse at a start", Pulse { at = c.starts.(j) + rand rs (-3) 14; width = width () }
    | 4 ->
      let falls =
        Array.to_list c.starts
        @ List.filter (Array.to_list moves) ~f:(fun at -> Wave.get w at = 0)
      in
      let at = List.random_element_exn ~random_state:rs falls in
      ( "pulse 2^14 on"
      , Pulse { at = at + (span * rand rs 1 3) + rand rs (-2) 2; width = width () } )
    | 5 | 6 -> "pulse", Pulse { at = rand rs 30 horizon; width = width () }
    | 7 | 8 ->
      let at = moves.(Random.State.int rs (Array.length moves)) in
      let by = rand rs 1 20 * if Random.State.bool rs then 1 else -1 in
      "shift", Shift { at; by }
    | 9 ->
      let at = moves.(Random.State.int rs (Array.length moves)) in
      "missing", Missing { at }
    | _ -> "long pulse", Pulse { at = rand rs 30 horizon; width = rand rs 4 300 }
  ;;

  (* A case with none, one or two mutations, never before cycle 30. *)
  let mutated rs ~long =
    let c = case rs ~long in
    let tags, mutations =
      match Random.State.int rs 10 with
      | 0 -> [], []
      | 1 | 2 ->
        let a, m = mutation rs c in
        let b, n = mutation rs c in
        [ a; b ], [ m; n ]
      | _ ->
        let a, m = mutation rs c in
        [ a ], [ m ]
    in
    let at = function
      | Case.Pulse { at; _ } | Missing { at } -> at
      | Shift { at; by } -> Int.min at (at + by)
    in
    if List.exists mutations ~f:(fun m -> at m < 30)
    then [ "clean" ], c
    else (
      let cycles =
        List.fold mutations ~init:c.cycles ~f:(fun acc m ->
          Int.max acc (at m + (2 * c.edges.(Array.length c.edges - 1)) + 400))
      in
      (if List.is_empty tags then [ "clean" ] else tags), { c with mutations; cycles })
  ;;
end
