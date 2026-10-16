open! Core

module Verdict = struct
  type t =
    | Accepted of Wavedrom.t
    | Refused of Error.t

  let to_string = function
    | Accepted (t : Wavedrom.t) ->
      List.map t.limits ~f:(fun l -> sprintf "edge %s: %d ns, holds" l.edge l.ns)
      |> List.cons (sprintf "taken, %d steps" (List.length t.steps))
      |> String.concat ~sep:"\n"
    | Refused e -> "refused: " ^ Error.to_string_hum e
  ;;
end

type t =
  { original : Verdict.t
  ; mutant : Verdict.t
  ; cycles : int list
  }

let cycles_a_period (diagram : Wavejson.t) =
  let drawn =
    List.map diagram.lanes ~f:(fun l -> String.length l.wave)
    |> List.max_elt ~compare
    |> Option.value ~default:0
  in
  match diagram.cycles with
  | Every c -> List.init drawn ~f:(Fn.const c)
  | Each cs -> cs
;;

(* The refusal names the period it was drawn at: the edge is the level changes of the
   first lane up to it, the cycle the periods before it, in the first pass of a repeat. *)
let edge_at (diagram : Wavejson.t) e =
  let open Option.Let_syntax in
  let text = Sexp.to_string (Error.sexp_of_t e) in
  let%bind at = String.substr_index text ~pattern:"period " in
  let digits = String.drop_prefix text (at + 7) |> String.take_while ~f:Char.is_digit in
  let%bind period = Int.of_string_opt digits in
  let%map lane = List.hd diagram.lanes in
  let changes =
    String.to_list (String.prefix lane.wave (period + 1))
    |> List.filter ~f:(fun c -> not (Char.equal c '.' || Char.equal c '|'))
    |> List.length
  in
  let cycle =
    List.sum (module Int) (List.take (cycles_a_period diagram) period) ~f:Fn.id
  in
  [%string "edge %{Int.max 0 (changes - 1)#Int} at cycle %{cycle#Int}"]
;;

let verdict diagram : Verdict.t =
  match Wavedrom.compile diagram with
  | Ok t -> Accepted t
  | Error e ->
    Refused
      (match edge_at diagram e with
       | Some at -> Error.tag e ~tag:[%string "the mutant's %{at}"]
       | None -> e)
;;

let clocked (diagram : Wavejson.t) =
  List.exists diagram.lanes ~f:(fun l ->
    String.exists l.wave ~f:(fun c -> String.mem "pPnN" c))
;;

let faster (diagram : Wavejson.t) ~percent =
  let tenths = Float.iround_nearest_exn (percent *. 10.) in
  if tenths <= 0 || tenths >= 1000
  then
    Or_error.error_s [%message "a mutation is a percentage in (0, 100)" (percent : float)]
  else (
    (* a clock's period splits into two whole halves; a period never reaches 0, which the
       format reads as special *)
    let step = if clocked diagram then 2 else 1 in
    let cut c =
      if c <= 0 then c else Int.max step (c * (1000 - tenths) / 1000 / step * step)
    in
    let cycles : Wavejson.Cycles.t =
      match diagram.cycles with
      | Every c -> Every (cut c)
      | Each cs -> Each (List.map cs ~f:cut)
    in
    Ok { diagram with cycles })
;;

let run (diagram : Wavejson.t) ~percent =
  let open Or_error.Let_syntax in
  let%map mutant = faster diagram ~percent in
  { original = verdict diagram; mutant = verdict mutant; cycles = cycles_a_period mutant }
;;
