open! Core
open! Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* Bridge's UART to SPI bridge by induction on the two-engine chip, for all time: each
   frame on IN0 reaches the wire, then SCK and MOSI, every edge a fixed number of steps
   after its stop bit begins, MOSI showing its byte at SCK's rises. Assumes any UART at
   Bridge.period on IN0, frames Bridge.spacing or more apart; hosts' fifo traffic free.
   The invariant is write_link.ml's kind: mined tables of both engines' state. *)

let period = Bridge.period
let wire = Bridge.wire
let spacing = Bridge.spacing
let firmware = [ Bridge.relay; Bridge.controller ]

module Chip = Engines.Make (struct
    let engines = 2
  end)

module Sim = Cyclesim.With_interface (Chip.I) (Chip.O)

(* Steps count from the start pulse, step 0; the tables claim from step 2. Engine 0's key
   is the steps since IN0's start bit, engine 1's since the wire's, each for [spacing]
   steps; outside a frame either is the step, held at [settled]. *)
let settled = 16

let encode ~since_start ~since =
  if since < spacing then settled + 1 + since else since_start
;;

let key_bits = Int.ceil_log2 (settled + 2 + spacing)

(* One step of a run: the chip's outputs in port order, the ghosts bridge.sv keeps, each
   engine's key, and the events the theorem speaks of. *)
module Step = struct
  type t =
    { values : int array
    ; ghosts : int String.Map.t
    ; pad_word : int
    ; wire_word : int
    ; since_start : int
    ; since_pad : int
    ; since_fall : int
    ; keys : int array
    ; sampled : bool array (** Each engine enters its [in pins, 1]. *)
    ; sent : bool array (** Each engine enters its [mov osr, isr]. *)
    ; moved : bool array (** IN0, and the wire. *)
    ; wire_fall : bool
    ; rise : bool
    ; sck_fall : bool
    ; rises : int
    }
end

let pc_of timed ~f =
  List.findi_exn (Timed_program.program timed).instructions ~f:(fun _ t -> f t) |> fst
;;

let sample_pc timed =
  pc_of timed ~f:(function
    | Isa.Op { op = In { source = Pins; count = 1 }; _ } -> true
    | _ -> false)
;;

(* the [mov osr, isr] a good stop bit jumps to *)
let send_pc timed =
  pc_of timed ~f:(function
    | Isa.Op { op = Mov { dest = Osr; op = Copy; source = Isr }; _ } -> true
    | _ -> false)
;;

let sample_pcs = List.map firmware ~f:sample_pc |> Array.of_list
let send_pcs = List.map firmware ~f:send_pc |> Array.of_list
let saturate n = Int.min 255 n
let bit v n = (v lsr n) land 1

let run ~sends ~steps =
  let scope = Scope.create ~flatten_design:true () in
  let sim = Sim.create (Chip.hierarchical ~memory:Flops scope) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let hosts = List.zip_exn i.hosts firmware in
  i.clocking.clear := Bits.vdd;
  Cyclesim.cycle sim;
  i.clocking.clear := Bits.gnd;
  List.iter hosts ~f:(fun (host, timed) ->
    Engine.Config.iter2
      host.config
      (Engine.Config.of_program_config (Timed_program.config timed))
      ~f:( := ));
  List.iter hosts ~f:(fun (host, timed) ->
    List.iteri (Timed_program.words timed) ~f:(fun a w ->
      host.program_write.valid := Bits.vdd;
      host.program_write.addr := Bits.of_unsigned_int ~width:Isa.pc_bits a;
      host.program_write.data := Bits.of_unsigned_int ~width:Isa.word_bits w;
      Cyclesim.cycle sim;
      host.program_write.valid := Bits.gnd));
  let int s = Bits.to_unsigned_int s in
  let pc (s : Bits.t Chip.O.t) n = int (List.nth_exn s.engines n).pc in
  let wire_of (s : Bits.t Chip.O.t) = bit (int (List.hd_exn s.engines).pin_out) wire in
  let pin (s : Bits.t Chip.O.t) n = bit (int s.pin_out) n in
  let previous = ref (Chip.O.map o ~f:( ! )) in
  let last_pad = ref 1 in
  let since_pad = ref spacing in
  let pad_word = ref 0 in
  let since_fall = ref spacing in
  let wire_word = ref 0 in
  let rises = ref 0 in
  let since_edge = [| 255; 255 |] in
  let since_sample = [| 255; 255 |] in
  let trace = Queue.create () in
  for step = 0 to steps - 1 do
    List.iter i.hosts ~f:(fun h -> h.start := Bits.of_bool (step = 0));
    let since_start = Int.min step settled in
    Option.iter (List.Assoc.find sends ~equal:Int.equal step) ~f:(fun byte ->
      if since_start <> settled || !since_pad <> spacing
      then raise_s [%message "BUG: a frame the sender may not start" (step : int)];
      since_pad := 0;
      pad_word := byte);
    let pad = Bridge.line [ step - !since_pad, !pad_word ] step in
    i.pads := Bits.of_unsigned_int ~width:Isa.num_pins pad;
    let now = Chip.O.map o ~f:( ! ) in
    let entered n =
      step > 0 && pc now n = sample_pcs.(n) && pc !previous n <> sample_pcs.(n)
    in
    let sending n =
      step > 0 && pc now n = send_pcs.(n) && pc !previous n <> send_pcs.(n)
    in
    let wire_level = wire_of now in
    let last_wire = wire_of !previous in
    let moved = [| step > 0 && pad <> !last_pad; step > 0 && wire_level <> last_wire |] in
    let wire_fall = moved.(1) && wire_level = 0 && !since_fall = spacing in
    if wire_fall
    then (
      since_fall := 0;
      wire_word := !pad_word;
      rises := 0);
    let sck = pin now Bridge.sck_pin in
    let last_sck = pin !previous Bridge.sck_pin in
    let rise = step > 0 && sck = 1 && last_sck = 0 in
    let sck_fall = step > 0 && sck = 0 && last_sck = 1 in
    let sampled = [| entered 0; entered 1 |] in
    let result =
      { Step.values = Chip.O.to_list now |> List.map ~f:int |> Array.of_list
      ; ghosts =
          String.Map.of_alist_exn
            [ "last_pad", !last_pad
            ; "last_wire", last_wire
            ; "last_sck", last_sck
            ; "last_pc_0", pc !previous 0
            ; "last_pc_1", pc !previous 1
            ; "since_edge_0", since_edge.(0)
            ; "since_sample_0", since_sample.(0)
            ; "since_edge_1", since_edge.(1)
            ; "since_sample_1", since_sample.(1)
            ; "since_fall", !since_fall
            ; "wire_word", !wire_word
            ; "rises", !rises
            ]
      ; pad_word = !pad_word
      ; wire_word = !wire_word
      ; since_start
      ; since_pad = !since_pad
      ; since_fall = !since_fall
      ; keys =
          [| encode ~since_start ~since:!since_pad
           ; encode ~since_start ~since:!since_fall
          |]
      ; sampled
      ; sent = [| sending 0; sending 1 |]
      ; moved
      ; wire_fall
      ; rise
      ; sck_fall
      ; rises = !rises
      }
    in
    if rise then rises := Int.min 15 (!rises + 1);
    for n = 0 to 1 do
      since_edge.(n) <- (if moved.(n) then 1 else saturate (since_edge.(n) + 1));
      since_sample.(n) <- (if sampled.(n) then 1 else saturate (since_sample.(n) + 1))
    done;
    since_pad := Int.min spacing (!since_pad + 1);
    since_fall := Int.min spacing (!since_fall + 1);
    previous := now;
    last_pad := pad;
    Cyclesim.cycle sim;
    Queue.enqueue trace result
  done;
  Queue.to_list trace
;;

(* What the tables say of: each engine's outputs, but the host's fifos and the two timers,
   which they give as distances back from [now]; and the ghosts. Each is keyed by one
   engine, whose frame's byte its data bits follow. A count the ghosts saturate is claimed
   as the range it keeps, any other non-data field as one value. *)
module Field = struct
  module Kind = struct
    type t =
      | Data
      | Range
      | Value
  end

  type t =
    { verilog : string
    ; width : int
    ; kind : Kind.t
    ; engine : int
    ; read : Step.t -> int
    }

  let word_name = function
    | 0 -> "pad_word"
    | _ -> "wire_word"
  ;;

  let word (step : Step.t) = function
    | 0 -> step.pad_word
    | _ -> step.wire_word
  ;;

  let verilog_name = String.map ~f:(fun c -> if Char.equal c '$' then '_' else c)
  let ports = Chip.O.to_list Chip.O.port_names_and_widths
  let index name = List.findi_exn ports ~f:(fun _ (n, _) -> String.equal n name) |> fst
  let skip = [ "tx_level"; "rx_level"; "rx_head"; "data_addr"; "t"; "capture" ]

  let outputs =
    List.filter_mapi ports ~f:(fun index (name, width) ->
      let%bind.Option field = String.chop_prefix name ~prefix:"engines$" in
      let base, engine = String.rsplit2_exn field ~on:'_' in
      Option.some_if
        (not (List.mem skip base ~equal:String.equal))
        { verilog = verilog_name name
        ; width
        ; kind =
            (if List.mem [ "pin_out"; "osr"; "isr" ] base ~equal:String.equal
             then Data
             else Value)
        ; engine = Int.of_string engine
        ; read = (fun step -> step.values.(index))
        })
  ;;

  let back_from_now n timer =
    let now = index [%string "engines$now_%{n#Int}"] in
    let at = index [%string "engines$%{timer}_%{n#Int}"] in
    { verilog = [%string "(engines_now_%{n#Int} - engines_%{timer}_%{n#Int})"]
    ; width = Isa.timer_bits
    ; kind = Value
    ; engine = n
    ; read =
        (fun step ->
          (step.values.(now) - step.values.(at)) land ((1 lsl Isa.timer_bits) - 1))
    }
  ;;

  let ghost ~engine ?verilog name width kind =
    { verilog = Option.value verilog ~default:name
    ; width
    ; kind
    ; engine
    ; read = (fun step -> Map.find_exn step.ghosts name)
    }
  ;;

  (* a shift count runs from 0 in the first frame and from full after: a floor where it
     differs *)
  let counts =
    List.filter_map outputs ~f:(fun field ->
      Option.some_if
        (List.exists [ "isr_count"; "osr_count" ] ~f:(fun substring ->
           String.is_substring field.verilog ~substring))
        { field with kind = Range })
  ;;

  let all =
    outputs
    @ counts
    @ List.concat_map [ 0; 1 ] ~f:(fun n ->
      [ back_from_now n "t"; back_from_now n "capture" ])
    @ [ (* what each receiver's pin sampled the step before *)
        ghost ~engine:0 ~verilog:"pins_sampled_0[0]" "last_pad" 1 Data
      ; ghost ~engine:1 ~verilog:"pins_sampled_1[20]" "last_wire" 1 Data
      ; ghost ~engine:0 "last_pad" 1 Data
      ; ghost ~engine:0 "since_edge_0" 8 Range
      ; ghost ~engine:0 "since_sample_0" 8 Range
      ; ghost ~engine:0 "last_pc_0" Isa.pc_bits Value
        (* engine 0's key knows where engine 1's frame is, and what it carries *)
      ; ghost ~engine:0 "since_fall" 9 Value
        (* and before the wire falls, how long engine 1 has had since its last frame *)
      ; ghost ~engine:0 "since_fall" 9 Range
      ; ghost ~engine:0 "wire_word" 8 Data
      ; ghost ~engine:0 "last_wire" 1 Data
      ; ghost ~engine:0 "since_edge_1" 8 Range
      ; ghost ~engine:0 "since_sample_1" 8 Range
      ; ghost ~engine:1 "last_wire" 1 Data
      ; ghost ~engine:1 "since_edge_1" 8 Range
      ; ghost ~engine:1 "since_sample_1" 8 Range
      ; ghost ~engine:1 "last_sck" 1 Data
      ; ghost ~engine:1 "rises" 4 Value
      ; ghost ~engine:1 "last_pc_1" Isa.pc_bits Value
      ]
  ;;
end

(* A bit of a data field at one key: the same in every run, or one bit of the word or its
   complement in every run, or not claimed. *)
let bit_formula samples ~bit ~word_name =
  let value (v, _) = (v lsr bit) land 1 in
  let word_bit j (_, w) = (w lsr j) land 1 in
  let all f = List.for_all samples ~f in
  match samples with
  | [] -> None
  | first :: _ ->
    if all (fun s -> value s = value first)
    then Some (if value first = 1 then "1'b1" else "1'b0")
    else
      List.find_map (List.range 0 8) ~f:(fun j ->
        if all (fun s -> value s = word_bit j s)
        then Some [%string "%{word_name}[%{j#Int}]"]
        else if all (fun s -> value s <> word_bit j s)
        then Some [%string "~%{word_name}[%{j#Int}]"]
        else None)
;;

(* The claim on one field at one key, as the least and the most it may be, or for data the
   bits expected and the mask of those claimed. A count only has a floor: a run can idle
   longer than any simulated. *)
let claim (field : Field.t) samples =
  let w = field.width in
  let values = List.map samples ~f:fst in
  let lo = List.reduce_exn values ~f:Int.min in
  let hi = List.reduce_exn values ~f:Int.max in
  match field.kind with
  | Range -> Some [%string "%{w#Int}'d%{lo#Int}, ~%{w#Int}'d0"]
  | Value -> Option.some_if (lo = hi) [%string "%{w#Int}'d%{lo#Int}, %{w#Int}'d%{lo#Int}"]
  | Data ->
    let word_name = Field.word_name field.engine in
    let bits =
      List.init w ~f:(fun bit -> bit_formula samples ~bit ~word_name) |> List.rev
    in
    if List.for_all bits ~f:Option.is_none
    then None
    else (
      let expected =
        List.map bits ~f:(Option.value ~default:"1'b0") |> String.concat ~sep:", "
      in
      let mask =
        List.map bits ~f:(fun b -> if Option.is_some b then "1" else "0") |> String.concat
      in
      Some [%string "{%{expected}}, %{w#Int}'b%{mask}"])
;;

let table_claim n (field : Field.t) (runs : Step.t list list) =
  let samples = Int.Table.create () in
  List.iter runs ~f:(fun run ->
    List.iter run ~f:(fun (step : Step.t) ->
      if step.since_start >= 2
      then
        Hashtbl.add_multi
          samples
          ~key:step.keys.(field.engine)
          ~data:(field.read step, Field.word step field.engine)));
  let arms =
    Hashtbl.to_alist samples
    |> List.filter_map ~f:(fun (key, samples) ->
      Option.map (claim field samples) ~f:(fun c -> c, key))
    |> List.Assoc.sort_and_group ~compare:String.compare
    |> List.map ~f:(fun (claim, keys) -> claim, List.sort keys ~compare)
    |> List.sort ~compare:(fun (_, a) (_, b) -> [%compare: int list] a b)
    |> List.map ~f:(fun (claim, keys) ->
      let keys = List.map keys ~f:Int.to_string |> String.concat ~sep:", " in
      [%string "      %{keys}: {a_%{n#Int}, b_%{n#Int}} = {%{claim}};"])
    |> String.concat ~sep:"\n"
  in
  let top = field.width - 1 in
  let check =
    match field.kind with
    | Data -> [%string "((%{field.verilog} ^ a_%{n#Int}) & b_%{n#Int}) == 0"]
    | Range | Value ->
      [%string "%{field.verilog} >= a_%{n#Int} && %{field.verilog} <= b_%{n#Int}"]
  in
  let default =
    match field.kind with
    | Data -> "0"
    | Range | Value -> [%string "~%{field.width#Int}'d0"]
  in
  [%string
    {|  // %{field.verilog}
  reg [%{top#Int}:0] a_%{n#Int}, b_%{n#Int};
  always @(*) begin
    a_%{n#Int} = 0;
    b_%{n#Int} = %{default};
    case (key_%{field.engine#Int})
%{arms}
    endcase
    if (since_start >= 2) assert (%{check});
  end
|}]
;;

let rom name words =
  List.mapi words ~f:(fun a w -> sprintf "      %d: %s = 16'h%04x;" a name w)
  |> String.concat ~sep:"\n"
;;

(* engines_top's inputs: the configs, the start, both hosts' fifo traffic, the pads *)
let input_ports () =
  let configs =
    List.concat_mapi firmware ~f:(fun n timed ->
      Engine.Config.(
        to_list
          (map2
             port_names
             (of_program_config (Timed_program.config timed))
             ~f:(fun name bits ->
               ( [%string "hosts$config$%{name}_%{n#Int}"]
               , [%string "%{Bits.width bits#Int}'d%{Bits.to_unsigned_int bits#Int}"] )))))
  in
  let driven =
    configs
    @ [ "clock", "clk"
      ; "clear", "clear"
      ; "hosts$start_0", "start"
      ; "hosts$start_1", "start"
      ; "hosts$tx$valid_0", "tx_valid[0]"
      ; "hosts$tx$valid_1", "tx_valid[1]"
      ; "hosts$tx$value_0", "tx_value_0"
      ; "hosts$tx$value_1", "tx_value_1"
      ; "hosts$rx_pop_0", "rx_pop[0]"
      ; "hosts$rx_pop_1", "rx_pop[1]"
      ; "pads", "pads"
      ]
  in
  Chip.I.to_list Chip.I.port_names_and_widths
  |> List.map ~f:(fun (name, width) ->
    let value =
      List.Assoc.find driven name ~equal:String.equal
      |> Option.value ~default:[%string "%{width#Int}'d0"]
    in
    [%string ".%{name}(%{value})"])
;;

(* The one value [f] gives at every step [at] picks, or raise *)
let constant runs what ~at ~f =
  match
    List.concat runs
    |> List.filter ~f:at
    |> List.map ~f
    |> List.dedup_and_sort ~compare:Int.compare
  with
  | [ d ] -> d
  | ds -> raise_s [%message "BUG: not one value" (what : string) (ds : int list)]
;;

let least runs ~at ~f =
  List.concat runs
  |> List.filter ~f:at
  |> List.map ~f
  |> List.min_elt ~compare:Int.compare
  |> Option.value_exn
;;

let bridge () =
  let words = [ 0; 0xff; 0x5a; 0xa5; 0x3c ] @ List.init 8 ~f:(fun j -> 1 lsl j) in
  let word n = List.nth_exn words (n % List.length words) in
  let runs =
    (* one frame, at each of the first steps it may *)
    List.concat_map
      (List.range settled (settled + 3))
      ~f:(fun at ->
        List.map words ~f:(fun w -> run ~sends:[ at, w ] ~steps:(at + spacing + 40)))
    (* two, the second at each of a few gaps from the closest on *)
    @ List.map (List.range 0 24) ~f:(fun extra ->
      let at = settled + 1 in
      let gap = spacing + extra in
      run
        ~sends:[ at, word extra; at + gap, word ((7 * extra) + 3) ]
        ~steps:(at + gap + spacing + 40))
    (* three as close as may be, and none *)
    @ List.map words ~f:(fun w ->
      run
        ~sends:
          [ settled, w
          ; settled + spacing, w lxor 0xa5
          ; settled + (2 * spacing), lnot w land 0xff
          ]
        ~steps:(settled + (4 * spacing)))
    @ [ run ~sends:[] ~steps:(settled + 60) ]
  in
  let sending n (s : Step.t) = s.sent.(n) in
  let send_0 =
    constant runs "engine 0's send" ~at:(sending 0) ~f:(fun s -> s.since_pad)
  in
  let send_1 =
    constant runs "engine 1's send" ~at:(sending 1) ~f:(fun s -> s.since_fall)
  in
  let wire_fall =
    constant runs "the wire's fall" ~at:(fun s -> s.wire_fall) ~f:(fun s -> s.since_pad)
  in
  let first =
    constant
      runs
      "the first rise"
      ~at:(fun s -> s.rise && s.rises = 0)
      ~f:(fun s -> s.since_fall)
  in
  let last =
    constant
      runs
      "the last fall"
      ~at:(fun s -> s.sck_fall && s.rises = 8)
      ~f:(fun s -> s.since_fall)
  in
  let margin n =
    Int.min
      (least
         runs
         ~at:(fun s -> s.sampled.(n))
         ~f:(fun s -> Map.find_exn s.ghosts [%string "since_edge_%{n#Int}"]))
      (least
         runs
         ~at:(fun s -> s.moved.(n))
         ~f:(fun s -> Map.find_exn s.ghosts [%string "since_sample_%{n#Int}"]))
  in
  let margin_0 = margin 0 in
  let margin_1 = margin 1 in
  let stop = 9 * period in
  eprint_s
    [%message
      "simulated"
        ~frames:(List.count (List.concat runs) ~f:(fun s -> s.wire_fall) : int)
        ~cycles_from_the_stop_bit:
          ([ "wire", wire_fall - stop
           ; "first rise", wire_fall + first - stop
           ; "last fall", wire_fall + last - stop
           ]
           : (string * int) list)
        (margin_0 : int)
        (margin_1 : int)];
  let declare =
    List.map Field.ports ~f:(fun (name, width) ->
      [%string "  wire [%{width - 1#Int}:0] %{Field.verilog_name name};"])
    |> String.concat ~sep:"\n"
  in
  let connect =
    input_ports ()
    @ List.map Field.ports ~f:(fun (name, _) ->
      [%string ".%{name}(%{Field.verilog_name name})"])
    |> String.concat ~sep:",\n    "
  in
  let table =
    List.mapi Field.all ~f:(fun n field -> table_claim n field runs) |> String.concat
  in
  let roms = List.map firmware ~f:Timed_program.words in
  let sample_0 = sample_pcs.(0)
  and sample_1 = sample_pcs.(1)
  and send_pc_0 = send_pcs.(0)
  and send_pc_1 = send_pcs.(1) in
  [%string
    {|// Generated by test/certify/write_bridge.exe: Bridge's UART to SPI bridge on the
// two-engine chip, proved by induction. IN0 is any UART at %{period#Int} cycles a bit whose frames
// start %{spacing#Int} or more steps apart, the first once the engines are up; the other pads and
// both hosts' fifo traffic are free. Each frame goes out on wire %{wire#Int}, its stop bit
// beginning %{wire_fall - stop#Int} steps after IN0's does, and then on SCK, first rising %{wire_fall + first - stop#Int} and
// last falling %{wire_fall + last - stop#Int} steps after, MOSI showing its byte MSB first at each rise.
module bridge (input clk);
  (* anyseq *) wire go;
  (* anyseq *) wire [7:0] next_byte;
  (* anyseq *) wire [1:0] tx_valid, rx_pop;
  (* anyseq *) wire [15:0] tx_value_0, tx_value_1;
  (* anyseq *) wire [19:1] other_pads;

  reg [1:0] boot = 0;
  always @(posedge clk) if (boot != 2) boot <= boot + 1;
  wire clear = boot == 0;
  wire start = boot == 1;

  // each program memory as a ROM behind the macro's port, read as the macro is
  function [15:0] rom_0(input [8:0] a);
    case (a)
%{rom "rom_0" (List.hd_exn roms)}
      default: rom_0 = 0;
    endcase
  endfunction
  function [15:0] rom_1(input [8:0] a);
    case (a)
%{rom "rom_1" (List.nth_exn roms 1)}
      default: rom_1 = 0;
    endcase
  endfunction
  wire [8:0] sram_addr_0, sram_addr_1;
  wire sram_men_0, sram_ren_0, sram_men_1, sram_ren_1;
  reg [15:0] sram_dout_0, sram_dout_1;
  always @(posedge clk) begin
    if (sram_men_0 && sram_ren_0) sram_dout_0 <= rom_0(sram_addr_0);
    if (sram_men_1 && sram_ren_1) sram_dout_1 <= rom_1(sram_addr_1);
  end

  // steps since the start, held at %{settled#Int}; 0 before it and at it
  reg [7:0] since_start = 0;
  always @(posedge clk)
    since_start <= clear ? 8'd0 : start ? 8'd1
      : since_start != 0 && since_start < %{settled#Int} ? since_start + 8'd1 : since_start;

  // The sender on IN0: a frame starts when it likes once %{spacing#Int} steps have passed since the
  // last, with the byte it likes: a start bit, the byte LSB first, a stop bit, %{period#Int} steps each.
  reg [8:0] since_pad_held = %{spacing#Int};
  reg [7:0] pad_word_held = 0;
  wire sending = go && since_start == %{settled#Int} && since_pad_held == %{spacing#Int};
  wire [8:0] since_pad = sending ? 9'd0 : since_pad_held;
  wire [7:0] pad_word = sending ? next_byte : pad_word_held;
  wire [8:0] pad_bit = since_pad / %{period#Int};
  wire pad = pad_bit == 0 ? 1'b0 : pad_bit < 9 ? pad_word[pad_bit - 1] : 1'b1;
  wire [19:0] pads = {other_pads, pad};
  always @(posedge clk) begin
    since_pad_held <= since_start == 0 ? %{spacing#Int}
      : since_pad < %{spacing#Int} ? since_pad + 9'd1 : since_pad;
    pad_word_held <= pad_word;
  end

  wire [27:0] pins_sampled_0, pins_sampled_1;
%{declare}
  engines_top dut (
    %{connect},
    .sram_addr_0(sram_addr_0), .sram_men_0(sram_men_0), .sram_ren_0(sram_ren_0),
    .sram_dout_0(sram_dout_0),
    .sram_addr_1(sram_addr_1), .sram_men_1(sram_men_1), .sram_ren_1(sram_ren_1),
    .sram_dout_1(sram_dout_1),
    .data_sram_dout(16'b0),
    .pins_sampled_0(pins_sampled_0), .pins_sampled_1(pins_sampled_1));

  reg [8:0] last_pc_0 = 0, last_pc_1 = 0;
  reg last_pad = 1, last_wire = 0, last_sck = 0;
  wire faulted_0 = engines_fault_underflow_0 | engines_fault_overflow_0
    | engines_fault_missed_deadline_0 | engines_fault_decode_0;
  wire faulted_1 = engines_fault_underflow_1 | engines_fault_overflow_1
    | engines_fault_missed_deadline_1 | engines_fault_decode_1;
  // the wire as engine 1 reads it, and the pins
  wire wire_level = (!faulted_0 && engines_pin_out_0[%{wire#Int}]) | (!faulted_1 && engines_pin_out_1[%{wire#Int}]);
  wire sck = pin_out[%{Bridge.sck_pin#Int}];
  wire mosi = pin_out[%{Bridge.mosi_pin#Int}];
  always @(posedge clk) begin
    last_pc_0 <= engines_pc_0;
    last_pc_1 <= engines_pc_1;
    last_pad <= pad;
    last_wire <= wire_level;
    last_sck <= sck;
  end
  wire up = since_start != 0;
  wire sample_0 = up && engines_pc_0 == %{sample_0#Int} && last_pc_0 != %{sample_0#Int};
  wire sample_1 = up && engines_pc_1 == %{sample_1#Int} && last_pc_1 != %{sample_1#Int};
  wire send_0 = up && engines_pc_0 == %{send_pc_0#Int} && last_pc_0 != %{send_pc_0#Int};
  wire send_1 = up && engines_pc_1 == %{send_pc_1#Int} && last_pc_1 != %{send_pc_1#Int};
  wire pad_moved = up && pad != last_pad;
  wire wire_moved = up && wire_level != last_wire;
  wire rise = up && sck && !last_sck;
  wire sck_fall = up && !sck && last_sck;

  // engine 1's frame: steps since the wire fell outside one, held at %{spacing#Int}; the byte
  // IN0's frame carried then; SCK's rises since
  reg [8:0] since_fall_held = %{spacing#Int};
  reg [7:0] wire_word_held = 0;
  reg [3:0] rises_held = 0;
  wire wire_fall = wire_moved && !wire_level && since_fall_held == %{spacing#Int};
  wire [8:0] since_fall = wire_fall ? 9'd0 : since_fall_held;
  wire [7:0] wire_word = wire_fall ? pad_word : wire_word_held;
  wire [3:0] rises = wire_fall ? 4'd0 : rises_held;
  always @(posedge clk)
    if (since_start == 0) begin
      since_fall_held <= %{spacing#Int};
      wire_word_held <= 0;
      rises_held <= 0;
    end else begin
      since_fall_held <= since_fall < %{spacing#Int} ? since_fall + 9'd1 : since_fall;
      wire_word_held <= wire_word;
      rises_held <= rises == 15 ? rises : rises + rise;
    end

  // steps since each line last moved and since its receiver last sampled it, held at 255
  reg [7:0] since_edge_0 = 255, since_sample_0 = 255, since_edge_1 = 255, since_sample_1 = 255;
  always @(posedge clk)
    if (since_start == 0) begin
      since_edge_0 <= 255;
      since_sample_0 <= 255;
      since_edge_1 <= 255;
      since_sample_1 <= 255;
    end else begin
      since_edge_0 <= pad_moved ? 8'd1 : since_edge_0 == 255 ? since_edge_0 : since_edge_0 + 8'd1;
      since_sample_0 <= sample_0 ? 8'd1 : since_sample_0 == 255 ? since_sample_0 : since_sample_0 + 8'd1;
      since_edge_1 <= wire_moved ? 8'd1 : since_edge_1 == 255 ? since_edge_1 : since_edge_1 + 8'd1;
      since_sample_1 <= sample_1 ? 8'd1 : since_sample_1 == 255 ? since_sample_1 : since_sample_1 + 8'd1;
    end

  wire [%{key_bits - 1#Int}:0] key_0 =
    since_pad < %{spacing#Int} ? %{settled + 1#Int} + since_pad : since_start;
  wire [%{key_bits - 1#Int}:0] key_1 =
    since_fall < %{spacing#Int} ? %{settled + 1#Int} + since_fall : since_start;

`ifdef WIDER
  localparam margin_0 = %{margin_0 + 1#Int};
`else
  localparam margin_0 = %{margin_0#Int};
`endif
  localparam margin_1 = %{margin_1#Int};
`ifdef EARLY
  localparam wire_at = %{wire_fall - 1#Int};
`else
  localparam wire_at = %{wire_fall#Int};
`endif
`ifdef LATE
  localparam first_at = %{first + 1#Int};
`else
  localparam first_at = %{first#Int};
`endif

  always @(*) begin
    assert (boot == 2 ? since_start != 0 : since_start == 0);
    // the ghosts count no further than they are held at
    assert (since_start <= %{settled#Int} && since_pad_held <= %{spacing#Int} && since_fall_held <= %{spacing#Int});
    // and no frame begins before the engines are up
    if (since_pad_held < %{spacing#Int} || since_fall_held < %{spacing#Int}) assert (since_start == %{settled#Int});
    if (since_start < %{settled#Int}) assert (pad_word_held == 0 && wire_word_held == 0);
    if (since_start != 0) begin
      assert (engines_isr_count_0 <= 16 && engines_isr_count_1 <= 16);
      assert (engines_osr_count_0 <= 16 && engines_osr_count_1 <= 16);
    end
    if (since_start != 0) begin
      // neither engine faults or raises its irq
      assert (!faulted_0 && !faulted_1 && !engines_irq_0 && !engines_irq_1);
      // engine 0 takes each frame's byte from IN0 and sends it, the wire's start bit falling
      // %{wire_fall#Int} steps after IN0's and at no other time
`ifdef NEXT_BIT
      if (send_0) assert (engines_isr_0[7:0] == {1'b0, pad_word[7:1]});
`else
      if (send_0) assert (engines_isr_0[7:0] == pad_word);
`endif
      if (send_0) assert (since_pad == %{send_0#Int});
      assert (wire_fall == (since_pad == wire_at));
      // engine 1 takes it from the wire and clocks it out, SCK first rising %{first#Int} steps
      // after the wire's fall and last falling %{last#Int} after, eight rises in all
      if (send_1) assert (engines_isr_1[7:0] == wire_word && since_fall == %{send_1#Int});
      if (rise) assert (since_fall < %{spacing#Int} && rises < 8 && mosi == wire_word[7 - rises]);
      assert ((rise && rises == 0) == (since_fall == first_at));
      assert ((sck_fall && rises == 8) == (since_fall == %{last#Int}));
      // every sample lies a margin from an edge of its line on either side
      if (sample_0) assert (!pad_moved && since_edge_0 >= margin_0);
      if (pad_moved) assert (since_sample_0 >= margin_0);
      if (sample_1) assert (!wire_moved && since_edge_1 >= margin_1);
      if (wire_moved) assert (since_sample_1 >= margin_1);
    end
  end

%{table}
  always @(posedge clk) begin
    cover (send_0);
    cover (rise && rises == 7);
  end
endmodule
|}]
;;

let () = print_string (bridge ())
