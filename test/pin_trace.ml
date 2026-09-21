open! Core
open! Hardcaml
open Hardcaml_lws
open Protocol_emulator
module Harness = Hardcaml_test_harness.Lws_harness.Make (Top.I) (Top.O)
module Reg = Host_port.Reg

let ( <--. ) = Bits.( <--. )

module Line = struct
  type t =
    { ui_in : int
    ; uio_in : int
    ; uo_out : int
    ; uio_out : int
    ; uio_oe : int
    }
  [@@deriving sexp_of, equal]
end

module Peer = struct
  type t =
    { inputs : unit -> int
    ; step : pin_out:int -> pin_dir:int -> unit
    }

  let idle levels =
    { inputs = (fun () -> levels); step = (fun ~pin_out:_ ~pin_dir:_ -> ()) }
  ;;
end

module Step = struct
  type t =
    | Write of int * int list
    | Read of int * int
    | Run of int
    | Drive of
        { pin : int
        ; levels : int list
        }
end

module Scenario = struct
  type t =
    { name : string
    ; peer : unit -> Peer.t
    ; script : Step.t list
    }

  let load ~config ~program =
    let config = Engine.Config.of_program_config config in
    (Engine.Config.to_list (Engine.Config.map config ~f:Bits.to_unsigned_int)
     |> List.mapi ~f:(fun n v -> Step.Write (Reg.config + n, [ v ])))
    @ [ Write (Reg.program_addr, [ 0 ]); Write (Reg.program, program) ]
  ;;

  let start = Step.Write (Reg.control, [ 1 ])
end

let run (scenario : Scenario.t) =
  Harness.run
    ~create:(Top.hierarchical ~memory:Flops)
    (fun (h @ local) ~inputs ~outputs ->
       let o = Before_and_after_edge.after_edge outputs in
       let peer = scenario.peer () in
       let lines = ref [] in
       let driven = ref None in
       let sck = ref Bits.gnd
       and mosi = ref Bits.gnd
       and cs_n = ref Bits.vdd
       and miso = ref Bits.gnd in
       let cycle () =
         let levels =
           match !driven with
           | None -> peer.inputs ()
           | Some (pin, level) -> peer.inputs () land lnot (1 lsl pin) lor (level lsl pin)
         in
         let host = Bits.to_unsigned_int (Bits.concat_msb [ !cs_n; !mosi; !sck ]) in
         let ui_in = ((levels land 0x1f) lsl 3) lor host in
         let uio_in = (levels lsr Isa.first_bidir_pin) land 0xff in
         inputs.ui_in <--. ui_in;
         inputs.uio_in <--. uio_in;
         Lws.step h;
         let int r = Bits.to_unsigned_int !r in
         let line =
           { Line.ui_in
           ; uio_in
           ; uo_out = int o.uo_out
           ; uio_out = int o.uio_out
           ; uio_oe = int o.uio_oe
           }
         in
         lines := line :: !lines;
         peer.step
           ~pin_out:
             (((line.uo_out lsr 1) lsl Isa.first_output_pin)
              lor (line.uio_out lsl Isa.first_bidir_pin))
           ~pin_dir:(line.uio_oe lsl Isa.first_bidir_pin)
       in
       let watch n =
         for _ = 1 to n do
           cycle ()
         done;
         miso := Bits.lsb !(o.uo_out)
       in
       inputs.rst_n := Bits.vdd;
       inputs.ena := Bits.vdd;
       watch 4;
       let m = Spi_master.create ~sck ~mosi ~cs_n ~miso ~half:4 in
       let reads =
         List.filter_map scenario.script ~f:(function
           | Write (reg, words) ->
             Spi_master.write m ~watch reg words;
             None
           | Read (reg, count) -> Some (Spi_master.read m ~watch reg ~count)
           | Run n ->
             watch n;
             None
           | Drive { pin; levels } ->
             List.iter levels ~f:(fun level ->
               driven := Some (pin, level);
               watch 1);
             driven := None;
             None)
       in
       List.rev !lines, reads)
;;
