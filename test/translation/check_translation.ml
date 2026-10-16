open! Core
open! Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* Sec runs the solver it calls z3, from the path, with the DIMACS file last *)
let z3_command =
  Command.basic
    ~summary:"Answer as z3 -dimacs, from cadical, UNSAT only once cake_lpr checks it"
    [%map_open.Command
      let (_ : bool) = flag "-dimacs" no_arg ~doc:" read DIMACS"
      and args = anon (non_empty_sequence_as_list ("ARG" %: string)) in
      fun () ->
        let result_out = Filename_unix.temp_file "translation" "result" in
        let answer =
          Exn.protect
            ~finally:(fun () -> Core_unix.unlink result_out)
            ~f:(fun () ->
              let dimacs_in = List.last_exn args in
              let%map.Or_error () = Checked_unsat.solver ~dimacs_in ~result_out () in
              In_channel.read_all result_out)
        in
        match answer with
        | Ok answer -> print_string answer
        | Error error ->
          eprint_s [%message "unchecked" (error : Error.t)];
          exit 1]
;;

let checked_z3_on_path () =
  let dir = Filename_unix.temp_dir "translation" "bin" in
  let z3 = dir ^/ "z3" in
  Out_channel.write_all
    z3
    ~data:
      [%string "#!/bin/sh\nexec %{Filename.quote Stdlib.Sys.executable_name} z3 \"$@\"\n"];
  Core_unix.chmod z3 ~perm:0o755;
  at_exit (fun () ->
    Core_unix.unlink z3;
    Core_unix.rmdir dir);
  (* one domain, before anything reads the environment *)
  (Core_unix.putenv [@alert "-unsafe_multidomain"])
    ~key:"PATH"
    ~data:(dir ^ ":" ^ Sys.getenv_exn "PATH")
;;

let check_command =
  Command.basic
    ~summary:"Check each module of the chip the tests simulate equals its Verilog"
    ~readme:(fun () ->
      "As bin/generate.exe top -sram -engines 2 builds it, against VERILOG as Yosys \
       reads it. Exits 1 unless every module is equal.")
    [%map_open.Command
      let files = anon (non_empty_sequence_as_list ("VERILOG" %: string))
      and lib = flag "-lib" (listed string) ~doc:"FILE a black box's Verilog" in
      fun () ->
        checked_z3_on_path ();
        let module C = Circuit.With_interface (Top.I) (Top.O) in
        let scope = Scope.create ~auto_label_hierarchical_ports:true () in
        let circuit =
          C.create_exn
            ~name:"protocol_emulator"
            (Top.hierarchical ~memory:Ihp_sram ~engines:2 scope)
        in
        let rtl =
          Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
        in
        let verilog =
          Translation.Verilog.read ~files ~lib ~top:"protocol_emulator" |> Or_error.ok_exn
        in
        let instances = Rtl.Hierarchical_circuits.(top rtl @ subcircuits rtl) in
        let modules = List.map instances ~f:Rtl.Circuit_instance.module_name in
        let unchecked =
          List.filter (Translation.Verilog.modules verilog) ~f:(fun name ->
            not (List.mem modules name ~equal:String.equal))
        in
        let equal =
          List.map instances ~f:(fun instance ->
            let module_name = Rtl.Circuit_instance.module_name instance in
            match Translation.check instance verilog with
            | Ok { flops; bits; equal = Unsat } ->
              print_s [%message "QED" module_name (flops : int) (bits : int)];
              true
            | Ok { equal = Sat _; _ } ->
              print_s [%message "counterexample" module_name];
              false
            | Error error ->
              print_s [%message "failed" module_name (error : Error.t)];
              false)
        in
        if not (List.is_empty unchecked)
        then print_s [%message "modules not checked" (unchecked : string list)];
        if List.is_empty unchecked && List.for_all equal ~f:Fn.id then () else exit 1]
;;

let () =
  Command.group
    ~summary:"Translation validation of the chip's Verilog"
    [ "check", check_command; "z3", z3_command ]
  |> Command_unix.run
;;
