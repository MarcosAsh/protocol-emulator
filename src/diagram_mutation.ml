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

let verdict diagram : Verdict.t =
  match Wavedrom.compile diagram with
  | Ok t -> Accepted t
  | Error e -> Refused e
;;

let faster (diagram : Wavejson.t) ~percent =
  if not Float.(percent > 0. && percent < 100.)
  then
    Or_error.error_s [%message "a mutation is a percentage in (0, 100)" (percent : float)]
  else (
    let cut c = Float.(round_down (of_int c * (100. - percent) / 100.) |> to_int) in
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
  { original = verdict diagram
  ; mutant = verdict mutant
  ; cycles =
      (match mutant.cycles with
       | Every c -> [ c ]
       | Each cs -> cs)
  }
;;
