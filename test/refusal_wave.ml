open! Core
open! Hardcaml
open! Signal
open Hardcaml_lws
open Hardcaml_waveterm
open Protocol_emulator

module O = struct
  type 'a t =
    { line : 'a
    ; pc : 'a [@bits Isa.pc_bits]
    ; now : 'a [@bits Isa.timer_bits]
    ; t : 'a [@bits Isa.timer_bits]
    ; phase : 'a [@bits Isa.timer_bits]
    ; entry : 'a
    ; late : 'a
    ; missed_deadline : 'a
    }
  [@@deriving hardcaml]
end

module Deadline = Deadline.Make (Signal)

let create ~pc ~pin scope (i : Signal.t Solo.I.t) =
  let core = Solo.hierarchical ~memory:Flops scope i in
  let spec = Clocking.to_spec i.clocking in
  let%hw at_pc =
    ~:(core.halted) &: (core.stall ==:. 0) &: (core.pc ==:. pc) &: ~:(i.start)
  in
  let%hw entry = at_pc &: ~:(reg spec at_pc) in
  { O.line = core.pin_out.:(pin)
  ; pc = core.pc
  ; now = core.now
  ; t = core.t
  ; phase = Deadline.phase ~now:core.now ~t:core.t
  ; entry
  ; late = entry &: Deadline.late ~now:core.now ~t:core.t
  ; missed_deadline = core.fault.missed_deadline
  }
;;

let hierarchical ?instance ~pc ~pin scope i =
  let module H = Hierarchy.In_scope (Solo.I) (O) in
  H.hierarchical ?instance ~scope ~name:"refusal" (create ~pc ~pin) i
;;

module Harness = Hardcaml_test_harness.Lws_harness.Make (Solo.I) (O)

let ( <--. ) = Bits.( <--. )

let assemble (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  Asm.Program.configure program c.config, Asm.Program.words program |> ok_exn, program
;;

let rejections (c : Certified.t) =
  let config, words, program = assemble c in
  Analyser.analyse
    ?period:c.period
    ~single_capture_edge:c.single_capture_edge
    ~config
    program.instructions
  |> Kernel.Table.of_analyser
  |> Kernel.rejections
       ?period:c.period
       ~single_capture_edge:c.single_capture_edge
       ~config
       ~words
;;

let late_wait c =
  List.find_map (rejections c) ~f:(fun (r : Kernel.Rejection.t) ->
    Option.some_if (List.mem r.fails "in time" ~equal:String.equal) r.pc)
;;

let display_rules =
  List.map
    [ "line", Wave_format.Bit
    ; "pc", Unsigned_int
    ; "now", Unsigned_int
    ; "t", Unsigned_int
    ; "phase", Int
    ; "entry", Bit
    ; "late", Bit
    ; "missed_deadline", Bit
    ]
    ~f:(fun (name, wave_format) -> Display_rule.port_name_is name ~wave_format)
;;

let print ?(cycles = 20) c ~pc ~pin ~tx =
  let config, words, _ = assemble c in
  let first_entry = ref 0 in
  Harness.run
    ~create:(hierarchical ~pc ~pin)
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:17
        ~display_width:(19 + (4 * cycles))
        ~wave_width:1
        ~start_cycle:(!first_entry - 4)
        waves)
    (fun (h @ local) ~inputs:i ~outputs ->
      let o = Before_and_after_edge.after_edge outputs in
      let elapsed = ref 0 in
      let cycle ?(n = 1) () =
        Lws.step ~n h;
        elapsed := !elapsed + n
      in
      i.clocking.clear := Bits.vdd;
      cycle ();
      i.clocking.clear := Bits.gnd;
      Engine.Config.iter2 i.config (Engine.Config.of_program_config config) ~f:( := );
      List.iteri words ~f:(fun addr word ->
        i.program_write.valid := Bits.vdd;
        i.program_write.addr <--. addr;
        i.program_write.data <--. word;
        cycle ());
      i.program_write.valid := Bits.gnd;
      i.start := Bits.vdd;
      cycle ();
      i.start := Bits.gnd;
      List.iter tx ~f:(fun word ->
        i.tx.valid := Bits.vdd;
        i.tx.value <--. word;
        cycle ());
      i.tx.valid := Bits.gnd;
      let limit = !elapsed + 1_000 in
      while (not (Bits.to_bool !(o.entry))) && !elapsed < limit do
        cycle ()
      done;
      first_entry := !elapsed;
      cycle ~n:cycles ();
      ())
;;
