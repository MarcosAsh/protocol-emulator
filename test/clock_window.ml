open! Core

module End = struct
  type t =
    { hz : int
    ; limit : string
    }
  [@@deriving sexp_of]
end

type t =
  { firmware : string
  ; shipped_hz : int
  ; lowest : End.t option
  ; highest : End.t option
  }
[@@deriving sexp_of]

let limit_name (t : Datasheet.t) =
  let side, ns =
    match t.limit with
    | At_least ns -> ">=", ns
    | At_most ns -> "<=", ns
  in
  sprintf "%s %s %g ns" t.parameter side ns
;;

let tighter ~f a b =
  match a, b with
  | None, x | x, None -> x
  | Some (a : End.t), Some (b : End.t) -> if f a.hz b.hz then Some a else Some b
;;

let lowest = tighter ~f:( >= )
let highest = tighter ~f:( <= )

let of_bench (bench : Bench.t) =
  List.fold
    (Datasheet.cliffs Library.limits bench)
    ~init:
      { firmware = bench.name
      ; shipped_hz = bench.clock_hz
      ; lowest = None
      ; highest = None
      }
    ~f:(fun t (limit, _, cliff) ->
      let at hz = Some { End.hz; limit = limit_name limit } in
      match cliff with
      | Never ->
        raise_s
          [%message "BUG: a limit that holds at no clock" bench.name limit.parameter]
      | Up_to hz -> { t with highest = highest t.highest (at hz) }
      | From hz -> { t with lowest = lowest t.lowest (at hz) })
;;

(* least <= 2^16 hz / rate <= most *)
let of_tolerance (b : Tolerance.Bounds.t) ~rate =
  let unit = Tolerance.unit in
  let named (read : Tolerance.Read.t) ~faster =
    sprintf "sender %s, read at pc %d" (if faster then "faster" else "slower") read.pc
  in
  ( { End.hz = ((b.least * rate) + unit - 1) / unit
    ; limit = named b.fastest_read ~faster:true
    }
  , { End.hz = b.most * rate / unit; limit = named b.slowest_read ~faster:false } )
;;

let can_receiver () =
  let bench = Library.find_bench_exn "can_receiver" in
  let period = Can_node.Receiver.period in
  let receiver = Tolerance.Receiver.can_rx ~period ~sample:Can_node.Receiver.sample () in
  if not (String.equal receiver.firmware.source bench.source)
  then raise_s [%message "BUG: the tolerance is of other firmware than the bench's"];
  let low, high =
    of_tolerance (Tolerance.bounds receiver) ~rate:(bench.clock_hz / period)
  in
  let t = of_bench bench in
  { t with lowest = lowest t.lowest (Some low); highest = highest t.highest (Some high) }
;;

let all () =
  List.filter_map (Library.bench @ [ Uart.log ]) ~f:(fun (bench : Bench.t) ->
    if String.equal bench.name "can_receiver"
    then Some (can_receiver ())
    else if List.exists Library.limits ~f:(fun l -> String.equal l.firmware bench.name)
    then Some (of_bench bench)
    else None)
;;

let mhz hz = sprintf "%.3f" (Float.of_int hz /. 1e6)

let to_string ts =
  List.map ts ~f:(fun t ->
    let side (e : End.t option) =
      Option.value_map e ~default:("-", "") ~f:(fun e -> mhz e.hz, e.limit)
    in
    let low, low_limit = side t.lowest
    and high, high_limit = side t.highest in
    sprintf
      "%-18s %7s %-28s %6s %7s %s"
      t.firmware
      low
      low_limit
      (mhz t.shipped_hz)
      high
      high_limit
    |> String.rstrip)
  |> String.concat ~sep:"\n"
;;
