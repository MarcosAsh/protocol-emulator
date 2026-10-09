open! Core
open Pio

let command =
  Command.basic
    ~summary:"Static timing of the programs in a .pio file"
    ~readme:(fun () ->
      "Prints each instruction's phase, pin edges with the pulse they end, and samples, \
       then checks the rules. Exits 2 on any FAIL or ERROR, 1 on a usage error.")
    (let%map_open.Command file = anon ("FILE" %: Filename_unix.arg_type)
     and program = flag "program" (optional string) ~doc:"NAME analyse only this program"
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
     and entry = flag "entry" (optional string) ~doc:"LABEL start address"
     and no_stretch =
       flag
         "no-stretch"
         (listed string)
         ~doc:"NAME an open-drain output no other driver holds low"
     in
     fun () ->
       let ok_or_usage = function
         | Ok value -> value
         | Error error ->
           eprintf "%s\n" (Error.to_string_hum error);
           exit 1
       in
       let spec =
         { Spec.program
         ; pins
         ; initials
         ; rules
         ; autopull
         ; autopush
         ; fifo_ready
         ; irq_wait_halts
         ; set_count
         ; out_count
         ; exec
         ; sys_hz
         ; clkdiv
         ; cell
         ; entry
         ; no_stretch
         }
       in
       let programs =
         Or_error.try_with (fun () -> In_channel.read_all file)
         |> Or_error.bind ~f:Pioasm.parse
         |> Or_error.bind ~f:(Spec.select spec)
         |> ok_or_usage
       in
       let configure = Spec.configure spec |> ok_or_usage in
       let passed =
         List.map programs ~f:(fun program ->
           let report = Timing.analyse (configure program |> ok_or_usage) program in
           print_string (Timing.Report.to_string report);
           Timing.Report.passed report)
       in
       if not (List.for_all passed ~f:Fn.id) then exit 2)
;;

let () = Command_unix.run command
