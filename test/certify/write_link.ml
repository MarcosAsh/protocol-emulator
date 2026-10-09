open! Core
open! Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* A UART from engine 0 to engine 1 over a wire, proved by induction on the two-engine
   chip for all time: each word engine 1 pushes is the low byte of the word engine 0
   pulled for that frame, once a frame, with every sample half a bit from the wire's
   edges. The invariant is a table of both engines' state by steps since the start, the
   pull and the start bit; a simulation proposes it, the proof checks it for any words at
   any times. *)

let wire = 20

(* the shortest period the analyser certifies the receiver at *)
let period = 10

module Chip = Engines.Make (struct
    let engines = 2
  end)

module Sim = Cyclesim.With_interface (Chip.I) (Chip.O)

let transmitter =
  Uart.tx ~period, { Program_config.default with set_base = wire; out_base = wire }
;;

let receiver ~period =
  ( Uart.rx_on ~pin:wire ~period
  , { Program_config.default with
      in_base = wire
    ; jmp_pin = wire
    ; capture_pin = wire
    ; capture_rising = false
    } )
;;

(* Neither firmware goes into a proof the analyser refuses: the receiver's certificate
   rests on its start edge being the one edge the line makes before it is captured. *)
let assemble ?single_capture_edge (source, config) =
  let program = Asm.assemble source |> ok_exn in
  let config = Asm.Program.configure program config in
  let (_ : Analyser.Verdict.t) =
    Analyser.check ?single_capture_edge ~config program |> ok_exn
  in
  program, config
;;

let pc_of (program : Asm.Program.t) ~f =
  List.findi_exn program.instructions ~f:(fun _ t -> f t) |> fst
;;

module Key = struct
  (* Steps count from the start pulse, step 0; the tables claim from step 2, once the
     start has reset the clock. Engine 0's key is the steps since its pc reached the pull,
     for [tx_frame] steps; engine 1's the steps since the wire fell outside a frame of its
     own, for [rx_frame]; outside a frame either is the step, held at [settled]. *)
  type t =
    { settled : int
    ; tx_frame : int
    ; rx_frame : int
    }

  let encode t ~since_start ~since ~frame =
    if since < frame then t.settled + 1 + since else since_start
  ;;

  let limit t = t.settled + 1 + Int.max t.tx_frame t.rx_frame
end

(* One step of a run: the chip's outputs in port order, the level the receiver sampled the
   step before, the ghost state link.sv keeps, and the keys. *)
module Step = struct
  type t =
    { values : int array
    ; sampled : int
    ; word : int
    ; since_start : int
    ; since_edge : int
    ; since_sample : int
    ; since_fall : int
    ; pushes : int
    ; pushed : int option (** what engine 1 pushes this step *)
    ; tx_key : int
    ; rx_key : int
    }
end

let saturate n = Int.min 255 n

let run ~(key : Key.t) ~programs ~configs ~pull_pc ~sample_pc ~push_pc ~sends ~steps =
  let scope = Scope.create ~flatten_design:true () in
  let sim = Sim.create (Chip.hierarchical ~memory:Flops scope) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let hosts = List.zip_exn i.hosts (List.zip_exn programs configs) in
  i.clocking.clear := Bits.vdd;
  Cyclesim.cycle sim;
  i.clocking.clear := Bits.gnd;
  List.iter hosts ~f:(fun (host, (_, config)) ->
    Engine.Config.iter2 host.config (Engine.Config.of_program_config config) ~f:( := ));
  List.iter hosts ~f:(fun (host, (words, _)) ->
    List.iteri words ~f:(fun a w ->
      host.program_write.valid := Bits.vdd;
      host.program_write.addr := Bits.of_unsigned_int ~width:Isa.pc_bits a;
      host.program_write.data := Bits.of_unsigned_int ~width:Isa.word_bits w;
      Cyclesim.cycle sim;
      host.program_write.valid := Bits.gnd));
  let tx, _ = List.hd_exn hosts in
  let rx, _ = List.nth_exn hosts 1 in
  let int s = Bits.to_unsigned_int s in
  let pc_of_step (s : Bits.t Chip.O.t) n = int (List.nth_exn s.engines n).pc in
  let level (s : Bits.t Chip.O.t) =
    List.fold s.engines ~init:0 ~f:(fun l e -> l lor ((int e.pin_out lsr wire) land 1))
  in
  let words = Queue.create () in
  let previous = ref (Chip.O.map o ~f:( ! )) in
  let since_pull = ref key.tx_frame in
  let since_fall = ref key.rx_frame in
  let word = ref 0 in
  let since_edge = ref 255 in
  let since_sample = ref 255 in
  let pushes = ref 0 in
  let trace = Queue.create () in
  for step = 0 to steps - 1 do
    tx.start := Bits.of_bool (step = 0);
    rx.start := Bits.of_bool (step = 0);
    let sent = List.Assoc.find sends ~equal:Int.equal step in
    tx.tx.valid := Bits.of_bool (Option.is_some sent);
    Option.iter sent ~f:(fun w ->
      tx.tx.value := Bits.of_unsigned_int ~width:Isa.data_bits w;
      Queue.enqueue words w);
    let now = Chip.O.map o ~f:( ! ) in
    let since_start = Int.min step key.settled in
    let entered pc n = pc_of_step now n = pc && pc_of_step !previous n <> pc in
    let pull = step > 0 && entered pull_pc 0 in
    if pull
    then (
      since_pull := 0;
      word := Queue.dequeue_exn words;
      pushes := 0);
    let moved = step > 0 && level now <> level !previous in
    if moved && level now = 0 && !since_fall = key.rx_frame then since_fall := 0;
    let sample = step > 0 && entered sample_pc 1 in
    let push = step > 0 && entered push_pc 1 in
    let result =
      { Step.values = Chip.O.to_list now |> List.map ~f:int |> Array.of_list
      ; sampled = level !previous
      ; word = !word
      ; since_start
      ; since_edge = !since_edge
      ; since_sample = !since_sample
      ; since_fall = !since_fall
      ; pushes = !pushes
      ; pushed = Option.some_if push (int (List.nth_exn now.engines 1).isr)
      ; tx_key = Key.encode key ~since_start ~since:!since_pull ~frame:key.tx_frame
      ; rx_key = Key.encode key ~since_start ~since:!since_fall ~frame:key.rx_frame
      }
    in
    if push then incr pushes;
    since_edge := if moved then 1 else saturate (!since_edge + 1);
    since_sample := if sample then 1 else saturate (!since_sample + 1);
    since_pull := Int.min key.tx_frame (!since_pull + 1);
    since_fall := Int.min key.rx_frame (!since_fall + 1);
    previous := now;
    Cyclesim.cycle sim;
    Queue.enqueue trace result
  done;
  Queue.to_list trace
;;

(* What the tables say of: each engine's outputs, but the host's fifos and the two timers,
   which they give as distances back from [now]; the level the receiver sampled; and the
   ghosts. Each is keyed by the engine it belongs to. A data field is claimed bit by bit
   as a constant or a bit of the word, a count the ghosts saturate as the range it keeps,
   anything else as one value. *)
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
    ; rx : bool
    ; read : Step.t -> int
    }

  let verilog_name = String.map ~f:(fun c -> if Char.equal c '$' then '_' else c)
  let ports = Chip.O.to_list Chip.O.port_names_and_widths
  let index name = List.findi_exn ports ~f:(fun _ (n, _) -> String.equal n name) |> fst
  let skip = [ "tx_level"; "rx_level"; "rx_head"; "data_addr"; "t"; "capture" ]

  let outputs =
    List.filter_mapi ports ~f:(fun index (name, width) ->
      let%bind.Option field = String.chop_prefix name ~prefix:"engines$" in
      let base, engine = String.rsplit2_exn field ~on:'_' in
      let rx = String.equal engine "1" in
      (* the receiver's host may let its fifo fill *)
      let host_decides = String.equal base "fault$overflow" && rx in
      Option.some_if
        (not (List.mem skip base ~equal:String.equal || host_decides))
        { verilog = verilog_name name
        ; width
        ; kind =
            (if List.mem [ "pin_out"; "osr"; "isr" ] base ~equal:String.equal
             then Data
             else Value)
        ; rx
        ; read = (fun step -> step.values.(index))
        })
  ;;

  let back_from_now n timer =
    let now = index [%string "engines$now_%{n#Int}"] in
    let at = index [%string "engines$%{timer}_%{n#Int}"] in
    { verilog = [%string "(engines_now_%{n#Int} - engines_%{timer}_%{n#Int})"]
    ; width = Isa.timer_bits
    ; kind = Value
    ; rx = n = 1
    ; read =
        (fun step ->
          (step.values.(now) - step.values.(at)) land ((1 lsl Isa.timer_bits) - 1))
    }
  ;;

  let ghost ?(rx = false) verilog width kind read = { verilog; width; kind; rx; read }

  let all =
    outputs
    @ List.concat_map [ 0; 1 ] ~f:(fun n ->
      [ back_from_now n "t"; back_from_now n "capture" ])
    @ [ ghost ~rx:true "pins_sampled_1[20]" 1 Data (fun s -> s.sampled)
      ; ghost ~rx:true "since_sample" 8 Range (fun s -> s.since_sample)
        (* and by engine 0's key, which knows how long the line has been idle *)
      ; ghost "since_sample" 8 Range (fun s -> s.since_sample)
      ; ghost "since_start" 8 Range (fun s -> s.since_start)
      ; ghost "since_edge" 8 Range (fun s -> s.since_edge)
      ; ghost "since_fall" 8 Value (fun s -> s.since_fall)
      ; ghost "pushes" 2 Value (fun s -> s.pushes)
      ; ghost "word" Isa.data_bits Data (fun s -> s.word)
      ]
  ;;
end

(* A bit of a data field at one key: the same in every run, or one bit of the word or its
   complement in every run, or not claimed. *)
let bit_formula samples ~bit =
  let value (v, _) = (v lsr bit) land 1 in
  let word_bit j (_, w) = (w lsr j) land 1 in
  let all f = List.for_all samples ~f in
  match samples with
  | [] -> None
  | first :: _ ->
    if all (fun s -> value s = value first)
    then Some (if value first = 1 then "1'b1" else "1'b0")
    else
      List.find_map (List.range 0 Isa.data_bits) ~f:(fun j ->
        if all (fun s -> value s = word_bit j s)
        then Some [%string "word[%{j#Int}]"]
        else if all (fun s -> value s <> word_bit j s)
        then Some [%string "~word[%{j#Int}]"]
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
    let bits = List.init w ~f:(fun bit -> bit_formula samples ~bit) |> List.rev in
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
  let key (step : Step.t) = if field.rx then step.rx_key else step.tx_key in
  let samples = Int.Table.create () in
  List.iter runs ~f:(fun run ->
    List.iter run ~f:(fun (step : Step.t) ->
      if step.since_start >= 2
      then Hashtbl.add_multi samples ~key:(key step) ~data:(field.read step, step.word)));
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
  let key = if field.rx then "rx_key" else "tx_key" in
  (* a data field's claim is the expected bits and the mask of those claimed, any other's
     the least and the most *)
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
    case (%{key})
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

(* engines_top's inputs: the configs, the start, engine 0's tx fifo and both rx pops from
   the host, the pads; nothing else *)
let input_ports ~configs =
  let configs =
    List.concat_mapi configs ~f:(fun n config ->
      Engine.Config.(
        to_list
          (map2 port_names (of_program_config config) ~f:(fun name bits ->
             ( [%string "hosts$config$%{name}_%{n#Int}"]
             , [%string "%{Bits.width bits#Int}'d%{Bits.to_unsigned_int bits#Int}"] )))))
  in
  let driven =
    configs
    @ [ "clock", "clk"
      ; "clear", "clear"
      ; "hosts$start_0", "start"
      ; "hosts$start_1", "start"
      ; "hosts$tx$valid_0", "tx_valid"
      ; "hosts$tx$value_0", "tx_value"
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

let link ~rx_period =
  let tx_program, tx_config = assemble transmitter in
  let rx_program, rx_config =
    assemble ~single_capture_edge:true (receiver ~period:rx_period)
  in
  let pc_of program op =
    pc_of program ~f:(function
      | Isa.Op { op = o; _ } -> Isa.Op.equal o op
      | Jmp _ -> false)
  in
  let pull_pc = pc_of tx_program (Sys Pull) in
  let sample_pc = pc_of rx_program (In { source = Pins; count = 1 }) in
  let push_pc = pc_of rx_program (Sys Push) in
  let programs =
    List.map [ tx_program; rx_program ] ~f:(fun p -> Asm.Program.words p |> ok_exn)
  in
  let configs = [ tx_config; rx_config ] in
  let key = { Key.settled = 16; tx_frame = (11 * period) + 16; rx_frame = 10 * period } in
  let run sends ~steps =
    run ~key ~programs ~configs ~pull_pc ~sample_pc ~push_pc ~sends ~steps
  in
  let words =
    [ 0; 0xffff; 0x5a3c; 0xa5c3; 0x1234 ] @ List.init Isa.data_bits ~f:(fun j -> 1 lsl j)
  in
  let word n = List.nth_exn words (n % List.length words) in
  let runs =
    (* one frame, sent from before the receiver is up to after *)
    List.concat_map
      (List.range 0 (key.settled + 3))
      ~f:(fun at ->
        List.map words ~f:(fun w -> run [ at, w ] ~steps:(at + key.tx_frame + 40)))
    (* two, the second sent at each step of the first *)
    @ List.map
        (List.range 1 (key.tx_frame + 8))
        ~f:(fun gap ->
          let at = key.settled + 4 in
          run
            [ at, word gap; at + gap, word ((7 * gap) + 3) ]
            ~steps:(at + gap + (2 * key.tx_frame) + 40))
    (* three at once, and none *)
    @ List.map words ~f:(fun w ->
      run [ 3, w; 4, w lxor 0xa5a5; 5, lnot w land 0xffff ] ~steps:(4 * key.tx_frame))
    @ [ run [] ~steps:(key.settled + 60) ]
  in
  (* the simulation already says whether the words arrive, which with a receiver at
     another period they need not *)
  let frames, wrong =
    List.concat runs
    |> List.filter_map ~f:(fun (step : Step.t) ->
      Option.map step.pushed ~f:(fun p -> p <> step.word land 0xff))
    |> List.partition_tf ~f:not
  in
  if rx_period = period && not (List.is_empty wrong)
  then raise_s [%message "BUG: the simulated link loses words" (List.length wrong : int)];
  eprint_s
    [%message
      "simulated"
        ~frames:(List.length frames + List.length wrong : int)
        ~wrong:(List.length wrong : int)];
  let margin = period / 2 in
  let top = Key.limit key in
  let key_bits = Int.ceil_log2 (top + 1) in
  let declare =
    List.map Field.ports ~f:(fun (name, width) ->
      [%string "  wire [%{width - 1#Int}:0] %{Field.verilog_name name};"])
    |> String.concat ~sep:"\n"
  in
  let connect =
    input_ports ~configs
    @ List.map Field.ports ~f:(fun (name, _) ->
      [%string ".%{name}(%{Field.verilog_name name})"])
    |> String.concat ~sep:",\n    "
  in
  let table =
    List.mapi Field.all ~f:(fun n field -> table_claim n field runs) |> String.concat
  in
  let tx_words, rx_words = List.hd_exn programs, List.nth_exn programs 1 in
  [%string
    {|// Generated by test/certify/write_link.exe: a UART from engine 0 to engine 1 over wire
// %{wire#Int} at %{period#Int} cycles a bit (the receiver at %{rx_period#Int}), proved by induction on the
// two-engine chip. The host sends any words whenever it likes and pops engine 1's fifo
// whenever it likes; the pads are free. The tables pin each engine to the steps since the
// start and since its own frame began; a simulation proposed them, the proof checks them.
module link (input clk);
  (* anyseq *) wire tx_valid;
  (* anyseq *) wire [15:0] tx_value;
  (* anyseq *) wire [1:0] rx_pop;
  (* anyseq *) wire [19:0] pads;

  reg [1:0] boot = 0;
  always @(posedge clk) if (boot != 2) boot <= boot + 1;
  wire clear = boot == 0;
  wire start = boot == 1;

  // each program memory as a ROM behind the macro's port, read as the macro is
  function [15:0] rom_0(input [8:0] a);
    case (a)
%{rom "rom_0" tx_words}
      default: rom_0 = 0;
    endcase
  endfunction
  function [15:0] rom_1(input [8:0] a);
    case (a)
%{rom "rom_1" rx_words}
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

  wire [15:0] tx_head;
  wire tx_empty;
  wire [3:0] fifo_used, fifo_used_minus_1, fifo_used_plus_1;
  wire fifo_used_is_one, fifo_used_gt_one, fifo_full_0, fifo_nearly_full;
  wire [27:0] pins_sampled_1;
%{declare}
  engines_top dut (
    %{connect},
    .sram_addr_0(sram_addr_0), .sram_men_0(sram_men_0), .sram_ren_0(sram_ren_0),
    .sram_dout_0(sram_dout_0),
    .sram_addr_1(sram_addr_1), .sram_men_1(sram_men_1), .sram_ren_1(sram_ren_1),
    .sram_dout_1(sram_dout_1),
    .data_sram_dout(16'b0), .tx_head(tx_head), .tx_empty(tx_empty),
    .fifo_used(fifo_used), .fifo_used_minus_1(fifo_used_minus_1),
    .fifo_used_plus_1(fifo_used_plus_1), .fifo_used_is_one(fifo_used_is_one),
    .fifo_used_gt_one(fifo_used_gt_one), .fifo_full_0(fifo_full_0),
    .fifo_nearly_full(fifo_nearly_full),
    .pins_sampled_1(pins_sampled_1));

  // steps since the start, held at %{key.settled#Int}; 0 before it and at it
  reg [7:0] since_start = 0;
  always @(posedge clk)
    since_start <= clear ? 8'd0 : start ? 8'd1
      : since_start != 0 && since_start < %{key.settled#Int} ? since_start + 8'd1 : since_start;

  reg [8:0] last_pc_0 = 0, last_pc_1 = 0;
  always @(posedge clk) begin
    last_pc_0 <= engines_pc_0;
    last_pc_1 <= engines_pc_1;
  end
  wire pull = since_start != 0 && engines_pc_0 == %{pull_pc#Int} && last_pc_0 != %{pull_pc#Int};
  wire sample = since_start != 0 && engines_pc_1 == %{sample_pc#Int} && last_pc_1 != %{sample_pc#Int};
  wire push = since_start != 0 && engines_pc_1 == %{push_pc#Int} && last_pc_1 != %{push_pc#Int};

  // engine 0's frame: steps since the last pull, held at %{key.tx_frame#Int} outside one; the
  // word it took; how many words engine 1 has pushed since
  reg [7:0] since_pull_held = %{key.tx_frame#Int};
  reg [15:0] word_held = 0;
  reg [1:0] pushes_held = 0;
  wire [7:0] since_pull = pull ? 8'd0 : since_pull_held;
  wire [15:0] word = pull ? tx_head : word_held;
  wire [1:0] pushes = pull ? 2'd0 : pushes_held;
  always @(posedge clk)
    if (since_start == 0) begin
      since_pull_held <= %{key.tx_frame#Int};
      word_held <= 0;
      pushes_held <= 0;
    end else begin
      since_pull_held <= since_pull < %{key.tx_frame#Int} ? since_pull + 8'd1 : since_pull;
      word_held <= word;
      pushes_held <= pushes == 3 ? pushes : pushes + push;
    end

  // steps since the wire last moved and since engine 1 last sampled it, held at 255
  wire level = engines_pin_out_0[%{wire#Int}] | engines_pin_out_1[%{wire#Int}];
  reg last_level = 0;
  always @(posedge clk) last_level <= level;
  wire moved = since_start != 0 && level != last_level;
  reg [7:0] since_edge = 255, since_sample = 255;
  always @(posedge clk)
    if (since_start == 0) begin
      since_edge <= 255;
      since_sample <= 255;
    end else begin
      since_edge <= moved ? 8'd1 : since_edge == 255 ? since_edge : since_edge + 8'd1;
      since_sample <= sample ? 8'd1 : since_sample == 255 ? since_sample : since_sample + 8'd1;
    end

  // engine 1's frame: steps since the wire fell outside one, held at %{key.rx_frame#Int}
  reg [7:0] since_fall_held = %{key.rx_frame#Int};
  wire [7:0] since_fall =
    moved && !level && since_fall_held == %{key.rx_frame#Int} ? 8'd0 : since_fall_held;
  always @(posedge clk)
    since_fall_held <= since_start == 0 ? %{key.rx_frame#Int}
      : since_fall < %{key.rx_frame#Int} ? since_fall + 8'd1 : since_fall;

  wire [%{key_bits - 1#Int}:0] tx_key =
    since_pull < %{key.tx_frame#Int} ? %{key.settled + 1#Int} + since_pull : since_start;
  wire [%{key_bits - 1#Int}:0] rx_key =
    since_fall < %{key.rx_frame#Int} ? %{key.settled + 1#Int} + since_fall : since_start;

`ifdef WIDER
  localparam margin = %{margin + 1#Int};
`else
  localparam margin = %{margin#Int};
`endif

  // engine 0's tx fifo: Hardcaml's Fifo keeps its count several ways over, which agree
  always @(*)
    if (since_start != 0) begin
      assert (fifo_used <= 8 && tx_empty == (fifo_used == 0));
      assert (fifo_used_minus_1 == fifo_used - 4'd1 && fifo_used_plus_1 == fifo_used + 4'd1);
      assert (fifo_used_is_one == (fifo_used == 1) && fifo_used_gt_one == (fifo_used > 1));
      assert (!fifo_full_0 && fifo_nearly_full == (fifo_used == 8));
    end

  always @(*) begin
    assert (boot == 2 ? since_start != 0 : since_start == 0);
    // the ghosts count no further than they are held at
    assert (since_start <= %{key.settled#Int} && since_pull_held <= %{key.tx_frame#Int});
    assert (since_fall_held <= %{key.rx_frame#Int});
    if (since_start != 0) begin
      // neither engine faults, but for engine 1's fifo filling, which is the host's doing
      assert (!engines_fault_underflow_0 && !engines_fault_overflow_0);
      assert (!engines_fault_missed_deadline_0 && !engines_fault_decode_0);
      assert (!engines_fault_underflow_1 && !engines_fault_missed_deadline_1);
      assert (!engines_fault_decode_1 && !engines_irq_0 && !engines_irq_1);
      // each word engine 1 pushes is the byte engine 0 sent in that frame, one a frame
`ifdef NEXT_BIT
      if (push) assert (engines_isr_1 == {8'b0, word[8:1]});
`else
      if (push) assert (engines_isr_1 == {8'b0, word[7:0]});
`endif
      if (push) assert (since_pull < %{key.tx_frame#Int} && pushes == 0);
      if (pull && since_pull_held < %{key.tx_frame#Int}) assert (pushes_held == 1);
      if (since_pull == %{key.tx_frame - 1#Int}) assert (pushes == 1);
      // every sample lies %{margin#Int} steps or more from an edge of the wire on either side
      if (sample) assert (!moved && since_edge >= margin);
      if (moved) assert (since_sample >= margin);
`ifdef NEVER_PUSHES
      assert (!push);
`endif
    end
  end

%{table}
  always @(posedge clk) begin
    cover (push);
    cover (pull && since_pull_held < %{key.tx_frame#Int});
  end
endmodule
|}]
;;

let () =
  let args = Sys.get_argv () in
  let rx_period =
    Array.findi args ~f:(fun _ a -> String.equal a "-rx-period")
    |> Option.value_map ~default:period ~f:(fun (i, _) -> Int.of_string args.(i + 1))
  in
  print_string (link ~rx_period)
;;
