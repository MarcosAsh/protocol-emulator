open! Core

module Value = struct
  type t =
    | Null
    | Bool of bool
    | Number of float
    | String of string
    | List of t list
    | Object of (string * t) list
  [@@deriving sexp_of, equal]

  exception Syntax of string * int

  (* recursive descent over [s], [pos] the next character *)
  let parse s =
    let pos = ref 0 in
    let fail what = raise (Syntax (what, !pos)) in
    let peek () = if !pos < String.length s then Some s.[!pos] else None in
    let advance () = incr pos in
    let rec blank () =
      match peek () with
      | Some (' ' | '\t' | '\n' | '\r') ->
        advance ();
        blank ()
      | Some '/' when !pos + 1 < String.length s && Char.equal s.[!pos + 1] '/' ->
        while Option.exists (peek ()) ~f:(fun c -> not (Char.equal c '\n')) do
          advance ()
        done;
        blank ()
      | Some '/' when !pos + 1 < String.length s && Char.equal s.[!pos + 1] '*' ->
        (match String.substr_index s ~pos:(!pos + 2) ~pattern:"*/" with
         | None -> fail "unclosed comment"
         | Some i -> pos := i + 2);
        blank ()
      | _ -> ()
    in
    let expect c =
      blank ();
      match peek () with
      | Some c' when Char.equal c c' -> advance ()
      | _ -> fail (sprintf "expected %c" c)
    in
    let string quote =
      advance ();
      let buffer = Buffer.create 16 in
      let rec go () =
        match peek () with
        | None -> fail "unclosed string"
        | Some c when Char.equal c quote -> advance ()
        | Some '\\' ->
          advance ();
          (match peek () with
           | Some 'n' -> Buffer.add_char buffer '\n'
           | Some 't' -> Buffer.add_char buffer '\t'
           | Some 'u' when !pos + 4 < String.length s ->
             (match Int.of_string_opt ("0x" ^ String.sub s ~pos:(!pos + 1) ~len:4) with
              | Some code when code < 128 -> Buffer.add_char buffer (Char.of_int_exn code)
              | _ -> fail "only ASCII \\u escapes");
             pos := !pos + 4
           | Some c -> Buffer.add_char buffer c
           | None -> fail "unclosed string");
          advance ();
          go ()
        | Some c ->
          Buffer.add_char buffer c;
          advance ();
          go ()
      in
      go ();
      Buffer.contents buffer
    in
    let word () =
      let start = !pos in
      while
        Option.exists (peek ()) ~f:(fun c -> Char.is_alphanum c || String.mem "_$+-." c)
      do
        advance ()
      done;
      String.sub s ~pos:start ~len:(!pos - start)
    in
    let rec value () =
      blank ();
      match peek () with
      | None -> fail "expected a value"
      | Some '{' ->
        advance ();
        Object (members [])
      | Some '[' ->
        advance ();
        List (elements [])
      | Some (('"' | '\'') as quote) -> String (string quote)
      | Some _ ->
        (match word () with
         | "" -> fail "expected a value"
         | "true" -> Bool true
         | "false" -> Bool false
         | "null" -> Null
         | w ->
           (match Float.of_string_opt w with
            | Some f when Float.is_finite f -> Number f
            | _ -> fail (sprintf "not a value: %s" w)))
    and members acc =
      blank ();
      match peek () with
      | Some '}' ->
        advance ();
        List.rev acc
      | Some (('"' | '\'') as quote) -> member acc (string quote)
      | _ ->
        (match word () with
         | "" -> fail "expected a key"
         | key -> member acc key)
    and member acc key =
      expect ':';
      let v = value () in
      blank ();
      (match peek () with
       | Some ',' -> advance ()
       | Some '}' -> ()
       | _ -> fail "expected , or }");
      members ((key, v) :: acc)
    and elements acc =
      blank ();
      match peek () with
      | Some ']' ->
        advance ();
        List.rev acc
      | _ ->
        let v = value () in
        blank ();
        (match peek () with
         | Some ',' -> advance ()
         | Some ']' -> ()
         | _ -> fail "expected , or ]");
        elements (v :: acc)
    in
    match value () with
    | exception Syntax (what, at) ->
      Or_error.error_s [%message "not WaveJSON" what (at : int)]
    | v ->
      blank ();
      if !pos = String.length s
      then Ok v
      else
        Or_error.error_s
          [%message "not WaveJSON" "text after the diagram" ~at:(!pos : int)]
  ;;
end

module Lane = struct
  type t =
    { name : string
    ; wave : string
    ; data : string list
    ; node : string
    ; input : bool
    ; phase : float
    ; period : float
    }
  [@@deriving sexp_of]
end

module Cycles = struct
  type t =
    | Every of int
    | Each of int list
  [@@deriving sexp_of]
end

module Repeat = struct
  type t =
    { first : int
    ; last : int
    ; times : int
    ; while_host : bool
    }
  [@@deriving sexp_of]
end

type t =
  { lanes : Lane.t list
  ; cycles : Cycles.t
  ; repeat : Repeat.t option
  ; words : int list option
  ; edges : string list
  }
[@@deriving sexp_of]

let field fields key = List.Assoc.find fields key ~equal:String.equal

let int what (v : Value.t) =
  match v with
  | Number f when Float.is_integer f && Float.(abs f < 1e9) -> Ok (Float.to_int f)
  | _ -> Or_error.error_s [%message "not a whole number" what (v : Value.t)]
;;

let ints what (v : Value.t) =
  match v with
  | List vs -> List.map vs ~f:(int what) |> Or_error.all
  | _ -> Or_error.error_s [%message "not a list of whole numbers" what (v : Value.t)]
;;

let lane fields =
  let open Or_error.Let_syntax in
  let string key ~default =
    match field fields key with
    | None -> Ok default
    | Some (Value.String s) -> Ok s
    | Some v -> Or_error.error_s [%message "not a string" key (v : Value.t)]
  in
  let number key ~default =
    match field fields key with
    | None -> Ok default
    | Some (Value.Number f) -> Ok f
    | Some v -> Or_error.error_s [%message "not a number" key (v : Value.t)]
  in
  let%bind name = string "name" ~default:"" in
  let%bind wave = string "wave" ~default:"" in
  let%bind node = string "node" ~default:"" in
  let%bind data =
    match field fields "data" with
    | None -> Ok []
    | Some (String s) ->
      Ok (String.split s ~on:' ' |> List.filter ~f:(Fn.non String.is_empty))
    | Some (List vs) ->
      List.map vs ~f:(function
        | Value.String s -> Ok s
        | Number f -> Ok (Float.to_string_hum ~strip_zero:true f)
        | v -> Or_error.error_s [%message "a data label is not text" (v : Value.t)])
      |> Or_error.all
    | Some v -> Or_error.error_s [%message "data is not a list" (v : Value.t)]
  in
  let%bind input =
    match field fields "input" with
    | None -> Ok false
    | Some (Bool b) -> Ok b
    | Some v -> Or_error.error_s [%message "input is not true or false" (v : Value.t)]
  in
  let%bind phase = number "phase" ~default:0. in
  let%map period = number "period" ~default:1. in
  { Lane.name; wave; data; node; input; phase; period }
;;

(* lanes in order, groups flattened, spacers and lanes with no wave dropped *)
let rec lanes (v : Value.t) =
  match v with
  | Object fields ->
    (match field fields "wave" with
     | None -> Ok []
     | Some _ -> lane fields |> Or_error.map ~f:List.return)
  | List (String _ :: rest) | List rest ->
    List.map rest ~f:lanes |> Or_error.all |> Or_error.map ~f:List.concat
  | v -> Or_error.error_s [%message "not a lane or a group" (v : Value.t)]
;;

let of_value (v : Value.t) =
  let open Or_error.Let_syntax in
  match v with
  | Object top ->
    let%bind lanes =
      match field top "signal" with
      | Some (List _ as signal) -> lanes signal
      | _ -> Or_error.error_s [%message "no signal list"]
    in
    let settings =
      match field top "table" with
      | Some (Object fields) -> fields
      | _ -> []
    in
    let%bind cycles =
      match field settings "cycles" with
      | None -> Or_error.error_s [%message "no table.cycles: how many cycles a period is"]
      | Some (Number _ as n) -> int "table.cycles" n >>| fun n -> Cycles.Every n
      | Some v -> ints "table.cycles" v >>| fun ns -> Cycles.Each ns
    in
    let%bind repeat =
      match field settings "repeat" with
      | None -> Ok None
      | Some (List [ first; last; times ]) ->
        let%bind first = int "table.repeat" first in
        let%bind last = int "table.repeat" last in
        let%map times = int "table.repeat" times in
        Some { Repeat.first; last; times; while_host = false }
      | Some (List [ first; last; times; String "host" ]) ->
        let%bind first = int "table.repeat" first in
        let%bind last = int "table.repeat" last in
        let%map times = int "table.repeat" times in
        Some { Repeat.first; last; times; while_host = true }
      | Some v ->
        Or_error.error_s
          [%message
            "table.repeat is [first, last, times] or [first, last, times, \"host\"]"
              (v : Value.t)]
    in
    let%bind words =
      match field settings "words" with
      | None -> Ok None
      | Some v -> ints "table.words" v >>| Option.some
    in
    let%map edges =
      match field top "edge" with
      | None -> Ok []
      | Some (List vs) ->
        List.map vs ~f:(function
          | Value.String s -> Ok s
          | v -> Or_error.error_s [%message "an edge is not text" (v : Value.t)])
        |> Or_error.all
      | Some v -> Or_error.error_s [%message "edge is not a list" (v : Value.t)]
    in
    { lanes; cycles; repeat; words; edges }
  | _ -> Or_error.error_s [%message "not an object"]
;;

let parse s = Or_error.bind (Value.parse s) ~f:of_value
