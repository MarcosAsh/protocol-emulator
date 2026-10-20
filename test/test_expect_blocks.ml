open! Core

(* A failure the tests print and do not raise, a lockstep's mismatch or a non-empty
   [failed] list, can be promoted into an expect block and then passes. No block in test/
   may hold one. *)

let expect = "[%" ^ "expect"

(* The text of each expect block in [source], quoted [{|...|}] or [{id|...|id}]. *)
let blocks source =
  let rec from pos found =
    match String.substr_index source ~pos ~pattern:expect with
    | None -> List.rev found
    | Some start ->
      let opening = String.index_from_exn source start '{' in
      let bar = String.index_from_exn source opening '|' in
      let id = String.sub source ~pos:(opening + 1) ~len:(bar - opening - 1) in
      let closing = String.substr_index_exn source ~pos:bar ~pattern:("|" ^ id ^ "}") in
      from closing (String.sub source ~pos:(bar + 1) ~len:(closing - bar - 1) :: found)
  in
  from 0 []
;;

let failed = "(failed ("

let offending block =
  String.is_substring block ~substring:("MIS" ^ "MATCH")
  || List.exists
       (String.substr_index_all block ~may_overlap:false ~pattern:failed)
       ~f:(fun pos ->
         let next = pos + String.length failed in
         next < String.length block && Char.( <> ) block.[next] ')')
;;

let%expect_test "no expect block holds a failure" =
  let files =
    Stdlib.Sys.readdir "."
    |> Array.to_list
    |> List.filter ~f:(String.is_suffix ~suffix:".ml")
    |> List.sort ~compare:String.compare
  in
  let offenders =
    List.filter files ~f:(fun file ->
      List.exists (blocks (In_channel.read_all file)) ~f:offending)
  in
  (* every test file is there, and not some other directory *)
  [%test_result: bool]
    (List.mem files "test_expect_blocks.ml" ~equal:String.equal)
    ~expect:true;
  [%test_result: bool] (List.length files > 100) ~expect:true;
  print_s [%message (offenders : string list)];
  [%test_result: string list] offenders ~expect:[];
  [%expect {| (offenders ()) |}]
;;

(* the check's teeth: each of these blocks has to be caught *)
let%expect_test "a promoted failure is caught" =
  let block text = expect ^ " {|\n" ^ text ^ "\n|}]" in
  List.iter
    [ block ("(MIS" ^ "MATCH (cycle 12))")
    ; block (failed ^ "3 5))")
    ; expect ^ " {xx|\n" ^ failed ^ "7))\n|xx}]"
    ; block (failed ^ "))")
    ; block "lockstep held"
    ]
    ~f:(fun source ->
      print_s [%message "" ~caught:(List.exists (blocks source) ~f:offending : bool)]);
  [%expect
    {|
    (caught true)
    (caught true)
    (caught true)
    (caught false)
    (caught false)
    |}]
;;
