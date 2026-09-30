open! Core
open Pio
open Timing

let initial text =
  match String.lsplit2 text ~on:'=' with
  | Some (name, "0") -> Ok (name, false)
  | Some (name, "1") -> Ok (name, true)
  | _ -> Or_error.error_s [%message "expected name=0 or name=1" (text : string)]
;;

let command =
  Command.basic
    ~summary:"Static timing of the programs in a .pio file"
    ~readme:(fun () ->
      "Prints each instruction's phase, pin edges with the pulse they end, and samples, \
       then checks the rules. Exits 2 on any FAIL or ERROR, 1 on a usage error.")
    (let%map_open.Command file = anon ("FILE" %: Filename_unix.arg_type)
     and only = flag "program" (optional string) ~doc:"NAME analyse only this program"
     and pins = flag "pin" (listed string) ~doc:"NAME=BINDINGS e.g. sda=set0:dir,in0,jmp"
     and initials = flag "init" (listed string) ~doc:"NAME=0|1 output level on entry"
     and rules =
       flag "rule" (listed string) ~doc:"RULE e.g. 't_low: scl- -> scl+ >= 4.7us'"
     and autopull = flag "autopull" no_arg ~doc:" out may stall on an empty TX FIFO"
     and autopush = flag "autopush" no_arg ~doc:" in may stall on a full RX FIFO"
     and fifo_ready = flag "fifo-ready" no_arg ~doc:" FIFO accesses never stall"
     and irq_wait_halts =
       flag "irq-wait-halts" no_arg ~doc:" the CPU restarts a machine held by irq wait"
     and set_count = flag "set-count" (optional_with_default 1 int) ~doc:"N set pins"
     and out_count = flag "out-count" (optional_with_default 1 int) ~doc:"N out pins"
     and exec =
       flag
         "exec"
         (listed string)
         ~doc:"SEQ e.g. 'x=1,scl=0: i1 | i2', instructions out exec runs in order"
     and sys_hz = flag "sys-hz" (optional float) ~doc:"HZ system clock"
     and clkdiv =
       flag
         "clkdiv"
         (optional float)
         ~doc:"DIV clock divider (default .clock_div, else 1)"
     and cell = flag "cell" (optional int) ~doc:"N cycles per bit of a locked input"
     and entry = flag "entry" (optional string) ~doc:"LABEL start address" in
     fun () ->
       let usage_error error =
         eprintf "%s\n" (Error.to_string_hum error);
         exit 1
       in
       let ok_or_usage = function
         | Ok value -> value
         | Error error -> usage_error error
       in
       let programs =
         Or_error.try_with (fun () -> In_channel.read_all file)
         |> Or_error.bind ~f:Pioasm.parse
         |> ok_or_usage
         |> List.filter ~f:(fun (program : Pioasm.Program.t) ->
           Option.value_map only ~default:true ~f:(String.equal program.name))
       in
       if List.is_empty programs then usage_error (Error.of_string "no program to check");
       let pins = List.map pins ~f:Pin.of_string |> Or_error.all |> ok_or_usage in
       let initials = List.map initials ~f:initial |> Or_error.all |> ok_or_usage in
       List.iter initials ~f:(fun (name, _) ->
         if not (List.exists pins ~f:(fun (pin : Pin.t) -> String.equal pin.name name))
         then usage_error (Error.create_s [%message "-init of no -pin" (name : string)]));
       let pins =
         List.map pins ~f:(fun pin ->
           { pin with initial = List.Assoc.find initials pin.name ~equal:String.equal })
       in
       let rules = List.map rules ~f:Rule.of_string |> Or_error.all |> ok_or_usage in
       let passed =
         List.map programs ~f:(fun program ->
           let exec =
             List.map exec ~f:(Exec_sequence.of_string program)
             |> Or_error.all
             |> ok_or_usage
           in
           let config =
             { Config.pins
             ; autopull
             ; autopush
             ; fifo_ready
             ; irq_wait_halts
             ; set_count
             ; out_count
             ; exec
             ; clock =
                 Option.map sys_hz ~f:(fun sys_hz ->
                   { Clock.sys_hz
                   ; clkdiv =
                       Option.first_some clkdiv program.clock_div
                       |> Option.value ~default:1.
                   })
             ; rules
             ; cell
             ; entry
             }
           in
           let report = analyse config program in
           print_string (Report.to_string report);
           Report.passed report)
       in
       if not (List.for_all passed ~f:Fn.id) then exit 2)
;;

let () = Command_unix.run command
