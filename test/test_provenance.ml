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
  [%expect {| ((bytes 387291) (untraced_identical true) (traced_identical true)) |}]
;;

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
            (List.count names ~f:(fun (_, source) -> Option.is_none source) : int)]);
  [%expect {|
    ((names 3728) (named_at 190) (made_at 3205) (unresolved 333)
     (distinct_lines 573))
    (data_memory (names 60) (unresolved 22))
    (engine (names 2001) (unresolved 63))
    (engines (names 414) (unresolved 87))
    (host_fifo (names 92) (unresolved 79))
    (host_port (names 882) (unresolved 36))
    (host_spi (names 71) (unresolved 15))
    (protocol_emulator (names 17) (unresolved 12))
    (sram_macro (names 21) (unresolved 12))
    (top (names 170) (unresolved 7))
    |}]
;;
