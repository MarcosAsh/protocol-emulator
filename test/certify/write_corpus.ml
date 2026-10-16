open! Core
open Protocol_emulator_test

(* The library as data for test/corpus.py, in [dir]: firmware.tsv with each protocol's
   firmware and its source in firmware/, and limits.tsv with each datasheet limit, the
   sheet it is read from and the bound at the clock the firmware ships at. *)

let write dir name rows =
  Out_channel.write_lines
    (dir ^/ name)
    (List.map rows ~f:(fun row -> String.concat ~sep:"\t" row))
;;

let clean s =
  String.tr s ~target:'\t' ~replacement:' ' |> String.tr ~target:'\n' ~replacement:' '
;;

let () =
  match Sys.get_argv () |> Array.to_list |> List.tl_exn with
  | [ dir ] ->
    Core_unix.mkdir_p (dir ^/ "firmware");
    let firmware = ref [] in
    let add (p : Protocol.t) kind name ~clock_hz source =
      let file = [%string "%{kind}-%{name}.asm"] in
      Out_channel.write_all (dir ^/ "firmware" ^/ file) ~data:source;
      firmware := [ p.name; kind; name; clock_hz; file ] :: !firmware
    in
    let limits =
      List.concat_map Library.protocols ~f:(fun p ->
        List.iter p.certified ~f:(fun (c : Certified.t) ->
          add p "certified" c.name ~clock_hz:"-" c.source);
        List.iter p.time_triggered ~f:(fun (c : Certified.t) ->
          add p "time_triggered" c.name ~clock_hz:"-" c.source);
        let bench kind (b : Bench.t) =
          add p kind b.name ~clock_hz:(Int.to_string b.clock_hz) b.source
        in
        List.iter p.bench ~f:(bench "bench");
        List.iter p.loaded_from_hex ~f:(bench "hex");
        List.concat_map (p.bench @ p.loaded_from_hex) ~f:(fun (b : Bench.t) ->
          Datasheet.check p.limits b
          |> List.map ~f:(fun ((t : Datasheet.t), (v : Datasheet.Verdict.t)) ->
            let side, limit =
              match v.limit with
              | At_least ns -> ">=", ns
              | At_most ns -> "<=", ns
            in
            let margin =
              match t.margin with
              | Cycle -> "a cycle"
              | Ns { ns; why } -> sprintf "%g ns, %s" ns why
            in
            let kind =
              match t.bound with
              | Kernel _ -> "kernel"
              | Run _ -> "run"
            in
            let bound, bound_ns =
              match v.bound with
              | None -> "-", "-"
              | Some c ->
                ( Int.to_string c
                , sprintf "%.1f" (Float.of_int c *. 1e9 /. Float.of_int b.clock_hz) )
            in
            List.map
              ~f:clean
              [ p.name
              ; b.name
              ; t.parameter
              ; side
              ; sprintf "%g" limit
              ; kind
              ; Int.to_string v.needed
              ; bound
              ; bound_ns
              ; (if v.ok then "ok" else "FAIL")
              ; margin
              ; t.sheet.part
              ; t.sheet.document
              ; t.sheet.page
              ])))
    in
    write
      dir
      "firmware.tsv"
      ([ "protocol"; "class"; "firmware"; "clock_hz"; "source" ] :: List.rev !firmware);
    write
      dir
      "limits.tsv"
      ([ "protocol"
       ; "firmware"
       ; "parameter"
       ; "side"
       ; "limit_ns"
       ; "bound_by"
       ; "needed_cycles"
       ; "bound_cycles"
       ; "bound_ns"
       ; "result"
       ; "margin"
       ; "part"
       ; "document"
       ; "page"
       ]
       :: limits)
  | _ -> eprintf "usage: write_corpus DIR\n"
;;
