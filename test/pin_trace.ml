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

  let to_string t =
    sprintf "%02x %02x %02x %02x %02x" t.ui_in t.uio_in t.uo_out t.uio_out t.uio_oe
  ;;
end

module Peer = struct
  type t =
    { inputs : unit -> int
    ; step : pin_out:int -> pin_dir:int -> unit
    }

  let idle levels =
    { inputs = (fun () -> levels); step = (fun ~pin_out:_ ~pin_dir:_ -> ()) }
  ;;

  let bit levels pin = (levels lsr pin) land 1
end

module Step = struct
  type t =
    | Write of int * int list
    | Read of int * int
    | Run of int
    | Until of int
    | Drive of
        { pin : int
        ; levels : int list
        }
    | Certify of
        { assumptions : System_lockstep.Assumptions.t
        ; config : Program_config.t
        ; program : int list
        }
end

module Sigrok = struct
  module Corruption = struct
    type t =
      | Shift of
          { pin : int
          ; edge : int
          ; cycles : int
          }
      | Flip of
          { pin : int
          ; edge : int
          ; after : int
          ; cycles : int
          }
  end

  module Refusal = struct
    type t =
      { why : string
      ; first_difference : int
      ; reads : string
      }

    let header name t =
      [ sprintf "%s why %s" name t.why
      ; sprintf "%s at %d" name t.first_difference
      ; sprintf "%s reads %s" name t.reads
      ]
    ;;
  end

  type t =
    { clock_hz : int
    ; decoders : string list
    ; expect : (string * string list) list
    ; joins_after : (int * Refusal.t) option
    ; rejected : Refusal.t option
    ; teeth : Corruption.t list list
    }

  let pin_name pin =
    if pin < Isa.first_output_pin
    then sprintf "IN%d" pin
    else if pin < Isa.first_bidir_pin
    then sprintf "OUT%d" (pin - Isa.first_output_pin)
    else sprintf "IO%d" (pin - Isa.first_bidir_pin)
  ;;

  let decoder ?(pins = []) ?(options = []) name =
    String.concat
      ~sep:":"
      ((name :: List.map pins ~f:(fun (channel, pin) -> channel ^ "=" ^ pin_name pin))
       @ List.map options ~f:(fun (option, value) -> option ^ "=" ^ value))
  ;;

  let header t =
    [ [ sprintf "clock %d" t.clock_hz ]
    ; List.map t.decoders ~f:(sprintf "decoder %s")
    ; List.concat_map t.expect ~f:(fun (annotations, lines) ->
        sprintf "annotations %s" annotations :: List.map lines ~f:(sprintf "expect %s"))
    ; Option.value_map t.joins_after ~default:[] ~f:(fun (cycles, misread) ->
        sprintf "joins_after %d" cycles :: Refusal.header "misread" misread)
    ; Option.value_map t.rejected ~default:[] ~f:(Refusal.header "rejected")
    ; List.map t.teeth ~f:(fun tooth ->
        List.map tooth ~f:(function
          | Corruption.Shift { pin; edge; cycles } ->
            sprintf "shift:%s:%d:%d" (pin_name pin) edge cycles
          | Flip { pin; edge; after; cycles } ->
            sprintf "flip:%s:%d:%d:%d" (pin_name pin) edge after cycles)
        |> String.concat ~sep:" "
        |> sprintf "tooth %s")
    ]
    |> List.concat
    |> List.map ~f:(sprintf "# sigrok %s\n")
  ;;
end

module Scenario = struct
  type t =
    { name : string
    ; peer : unit -> Peer.t
    ; script : Step.t list
    ; sigrok : Sigrok.t option
    }

  let load ?(assumptions = System_lockstep.Assumptions.none) ~config ~program () =
    let fields = Engine.Config.of_program_config config in
    List.map2_exn
      Reg.configs
      (Engine.Config.to_list (Engine.Config.map fields ~f:Bits.to_unsigned_int))
      ~f:(fun reg v -> Step.Write (reg, [ v ]))
    @ [ Write (Reg.program_addr, [ 0 ])
        (* zeros past the program, as the host protocol loads them: the checker walks
           every word, and the SRAM powers up with anything in it *)
      ; Write
          ( Reg.program
          , program
            @ List.init ((1 lsl Isa.pc_bits) - List.length program) ~f:(fun _ -> 0) )
      ; Certify { assumptions; config; program }
      ]
  ;;

  let start = Step.Write (Reg.control, [ 1 ])
end

let run (scenario : Scenario.t) =
  Harness.run
    ~create:(Top.hierarchical ~memory:Flops ~engines:2)
    (fun (h @ local) ~inputs ~outputs ->
       let o = Before_and_after_edge.after_edge outputs in
       let peer = scenario.peer () in
       let lines = ref [] in
       let count = ref 0 in
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
         incr count;
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
           | Until n ->
             if n < !count
             then
               raise_s
                 [%message "the script is already past" (n : int) ~cycle:(!count : int)];
             watch (n - !count);
             None
           | Drive { pin; levels } ->
             List.iter levels ~f:(fun level ->
               driven := Some (pin, level);
               watch 1);
             driven := None;
             None
           | Certify { assumptions; config; program } ->
             (try Spi_certify.certify m ~watch ~assumptions ~config program with
              | exn -> raise_s [%message "certifying" scenario.name (exn : exn)]);
             None)
       in
       List.rev !lines, reads)
;;

let to_string (scenario : Scenario.t) lines =
  let runs =
    List.group lines ~break:(fun a b -> not (Line.equal a b))
    |> List.map ~f:(fun run ->
      sprintf "%d %s\n" (List.length run) (Line.to_string (List.hd_exn run)))
  in
  String.concat
    ([ sprintf "# %s, from test/pin_trace.ml: do not edit\n" scenario.name
     ; "# cycles ui_in uio_in uo_out uio_out uio_oe; cycle 0 is the first rising edge\n"
     ; "# after rst_n rises, outputs are the values after the edge\n"
     ]
     @ Option.value_map scenario.sigrok ~default:[] ~f:Sigrok.header
     @ runs)
;;
