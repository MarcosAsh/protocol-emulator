open! Core

module Line = struct
  type t =
    { name : string
    ; first : bool
    ; edges : int array
    }
  [@@deriving sexp_of]

  let runs t =
    Array.to_list t.edges
    |> List.foldi ~init:[] ~f:(fun i acc at ->
      if i = 0
      then acc
      else (
        let level = Bool.( <> ) t.first (i % 2 = 1) in
        (level, at - t.edges.(i - 1)) :: acc))
    |> List.rev
  ;;

  let level_at t at =
    let changes = Array.count t.edges ~f:(fun edge -> edge < at) in
    Bool.( <> ) t.first (changes % 2 = 1)
  ;;
end

type t =
  { rate_hz : float
  ; length : int
  ; lines : Line.t list
  ; notes : string list
  }
[@@deriving sexp_of]

let of_string text =
  let lines = String.split_lines text |> List.map ~f:String.strip in
  let notes, lines = List.partition_tf lines ~f:(String.is_prefix ~prefix:"#") in
  let words =
    List.filter_map lines ~f:(fun line ->
      match String.split line ~on:' ' |> List.filter ~f:(Fn.non String.is_empty) with
      | [] -> None
      | words -> Some words)
  in
  Or_error.try_with (fun () ->
    let field name =
      match List.find words ~f:(fun w -> String.equal (List.hd_exn w) name) with
      | Some [ _; value ] -> value
      | _ -> raise_s [%message "no single value for" name]
    in
    let lines =
      List.filter_map words ~f:(function
        | "pin" :: name :: first :: edges ->
          let edges = Array.of_list_map edges ~f:Int.of_string in
          if not (Array.is_sorted_strictly edges ~compare)
          then raise_s [%message "edges out of order" name];
          Some { Line.name; first = String.equal first "1"; edges }
        | ("rate" | "length") :: _ -> None
        | line -> raise_s [%message "not a recording line" (line : string list)])
    in
    { rate_hz = Float.of_string (field "rate")
    ; length = Int.of_string (field "length")
    ; lines
    ; notes
    })
;;

let to_string t =
  let pins =
    List.map t.lines ~f:(fun line ->
      String.concat
        ~sep:" "
        ([ "pin"; line.name; (if line.first then "1" else "0") ]
         @ List.map (Array.to_list line.edges) ~f:Int.to_string))
  in
  String.concat_lines
    (t.notes @ [ sprintf "rate %.0f" t.rate_hz; sprintf "length %d" t.length ] @ pins)
;;

let find t name = List.find t.lines ~f:(fun line -> String.equal line.name name)
