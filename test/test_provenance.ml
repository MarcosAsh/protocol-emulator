open! Core
open! Hardcaml
open Protocol_emulator

(* the design and flags src/protocol_emulator.v is generated from *)
let rtl () =
  let module C = Circuit.With_interface (Top.I) (Top.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit =
    C.create_exn
      ~name:"protocol_emulator"
      (Top.hierarchical ~memory:Ihp_sram ~engines:2 scope)
  in
  Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
;;

(* with the newline bin/generate.exe prints after it *)
let verilog rtl = (Rtl.full_hierarchy rtl |> Rope.to_string) ^ "\n"

let%expect_test "tracing leaves the committed verilog byte for byte" =
  let committed = In_channel.read_all "../src/protocol_emulator.v" in
  let plain = verilog (rtl ()) in
  let traced = Provenance.traced (fun () -> verilog (rtl ())) in
  print_s
    [%message
      ""
        ~bytes:(String.length committed : int)
        ~untraced_identical:(String.equal plain committed : bool)
        ~traced_identical:(String.equal traced committed : bool)];
  [%expect {| ((bytes 698806) (untraced_identical true) (traced_identical true)) |}]
;;

(* no module's lines are an interface's fields, where its derived code sits *)
let%expect_test "the share of verilog names that resolve to a src line" =
  let modules = Provenance.traced rtl |> Provenance.of_rtl in
  let names = List.concat_map modules ~f:snd in
  let count f = List.count names ~f:(fun (_, source) -> f source) in
  let lines =
    List.filter_map names ~f:snd
    |> List.map ~f:Provenance.Source.to_string
    |> List.dedup_and_sort ~compare:String.compare
  in
  print_s
    [%message
      ""
        ~names:(List.length names : int)
        ~named_at:
          (count (function
             | Some { named; _ } -> named
             | None -> false)
           : int)
        ~made_at:
          (count (function
             | Some { named; _ } -> not named
             | None -> false)
           : int)
        ~unresolved:(count Option.is_none : int)
        ~distinct_lines:(List.length lines : int)];
  List.iter modules ~f:(fun (module_name, names) ->
    print_s
      [%message
        module_name
          ~names:(List.length names : int)
          ~unresolved:
            (List.count names ~f:(fun (_, source) -> Option.is_none source) : int)
          ~files:
            (List.filter_map names ~f:(fun (_, source) ->
               Option.map source ~f:(fun source -> source.file))
             |> List.dedup_and_sort ~compare:String.compare
             : string list)]);
  [%expect
    {|
    ((names 6735) (named_at 365) (made_at 5391) (unresolved 979)
     (distinct_lines 1004))
    (both_edges (names 14) (unresolved 10) (files (src/both_edges.ml)))
    (data_memory (names 69) (unresolved 36) (files (src/data_memory.ml)))
    (engine (names 2396) (unresolved 131)
     (files
      (src/crc.ml src/deadline.ml src/decoder.ml src/engine.ml src/pins.ml)))
    (engines (names 713) (unresolved 259) (files (src/engines.ml)))
    (frame_rx (names 116) (unresolved 20) (files (src/crc.ml src/frame_rx.ml)))
    (host_fifo (names 93) (unresolved 86) (files (src/host_fifo.ml)))
    (host_port (names 1146) (unresolved 258) (files (src/host_port.ml)))
    (host_spi (names 71) (unresolved 21) (files (src/host_spi.ml)))
    (load_checker (names 1644) (unresolved 99)
     (files (src/decoder.ml src/kernel.ml src/load_checker.ml)))
    (manchester_rx (names 181) (unresolved 12) (files (src/manchester_rx.ml)))
    (protocol_emulator (names 17) (unresolved 17) (files ()))
    (sram_macro (names 21) (unresolved 19) (files (src/sram_macro.ml)))
    (top (names 254) (unresolved 11) (files (src/top.ml)))
    |}]
;;
