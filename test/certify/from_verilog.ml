open! Core
open! Hardcaml
open Protocol_emulator
module Bit = Bit_sim.Bit

type t =
  { host : string
  ; ports : string
  ; extra : config:Program_config.t -> Analyser.Row.t list -> string * string
  ; mutant : string
  ; sby : string
  ; summary : string list
  }

let refuse fmt = Printf.ksprintf (fun s -> Or_error.error_string s) fmt

(* [name == value] on the bits [value] knows, runs of constants or of data bits together *)
let equals name (value : Bit.t array) =
  let width = Array.length value in
  let rec runs b =
    if b >= width
    then []
    else (
      match value.(b) with
      | Unknown -> runs (b + 1)
      | Zero | One ->
        let stop = ref b in
        while
          !stop + 1 < width
          &&
          match value.(!stop + 1) with
          | Zero | One -> true
          | _ -> false
        do
          incr stop
        done;
        let bits =
          List.range b (!stop + 1) ~stride:1
          |> List.rev_map ~f:(fun i -> Bit.to_string value.(i))
          |> String.concat
        in
        `Const (b, !stop, bits) :: runs (!stop + 1)
      | Data { index; inverted } ->
        let stop = ref b in
        while
          !stop + 1 < width
          &&
          match value.(!stop + 1) with
          | Data d -> d.index = index + (!stop + 1 - b) && Bool.equal d.inverted inverted
          | _ -> false
        do
          incr stop
        done;
        `Data (b, !stop, index, inverted) :: runs (!stop + 1))
  in
  let slice hi lo = if width = 1 then name else sprintf "%s[%d:%d]" name hi lo in
  List.map (runs 0) ~f:(function
    | `Const (lo, hi, bits) -> sprintf "%s == %d'b%s" (slice hi lo) (hi - lo + 1) bits
    | `Data (lo, hi, index, inverted) ->
      sprintf
        "%s == %sd[%d:%d]"
        (slice hi lo)
        (if inverted then "~" else "")
        (index + hi - lo)
        index)
;;

module Index = struct
  type t =
    | Warm of int
    | Frame of int
    | Settled
  [@@deriving compare, sexp_of]
end

(* each bit known when every run agrees on it, as a constant or as a bit of the word *)
let mine ~width ~data_width (observations : (int option * int option) list) =
  Array.init width ~f:(fun b ->
    let seen =
      List.filter_map observations ~f:(fun (v, d) ->
        Option.map v ~f:(fun v -> (v lsr b) land 1, d))
    in
    match seen with
    | [] -> Bit.Unknown
    | (first, _) :: _ ->
      if List.for_all seen ~f:(fun (v, _) -> v = first)
      then if first = 1 then One else Zero
      else (
        let data inverted =
          List.find (List.range 0 data_width) ~f:(fun j ->
            List.for_all seen ~f:(fun (v, d) ->
              match d with
              | Some d -> v = (d lsr j) land 1 lxor Bool.to_int inverted
              | None -> false))
        in
        match data false, data true with
        | Some index, _ -> Data { index; inverted = false }
        | None, Some index -> Data { index; inverted = true }
        | None, None -> Unknown))
;;

let fields ~out_base : (string * int * (Machine.t -> int option)) list =
  [ ("pc", Isa.pc_bits, fun m -> Some m.pc)
  ; ("pin", 1, fun m -> Some ((m.pin_out lsr out_base) land 1))
  ; ("stall", 5, fun m -> Some m.stall)
  ; ("x", Isa.data_bits, fun m -> Some m.x)
  ; ("p", Isa.data_bits, fun m -> Some m.p)
  ; ("osr", Isa.data_bits, fun m -> Some m.osr)
  ; ("osr_count", 5, fun m -> Some m.osr_count)
  ; ("tx_level", 4, fun m -> Some (List.length m.tx_fifo))
  ; ("tx_head", Isa.data_bits, fun m -> List.hd m.tx_fifo)
  ; ( "phase"
    , Isa.timer_bits
    , fun m -> Some ((m.now - m.t) land ((1 lsl Isa.timer_bits) - 1)) )
  ]
;;

let engine_lines =
  {|read_verilog -lib RM_IHPSG13_1P_512x16_c2_bm_bist.v
read_verilog engine_sram.v
hierarchy -top engine_top
proc
flatten
expose -evert -sep __ engine_top/t:RM_IHPSG13_1P_512x16_c2_bm_bist
cd engine_top
expose w:solo.engine.issue w:solo.engine.jmp_go w:solo.engine.tx.head w:solo.engine.tx.empty
rename solo.engine.issue eng_issue
rename solo.engine.jmp_go eng_jmp_go
rename solo.engine.tx.head eng_tx_head
rename solo.engine.tx.empty eng_tx_empty
rename solo.engine.sram_macro.sram__A_ADDR sram_addr
rename solo.engine.sram_macro.sram__A_DOUT sram_dout
rename solo.data_memory.sram_macro.sram__A_DOUT data_sram_dout
expose w:solo.engine.tx.USED w:solo.engine.tx.USED_MINUS_1
expose w:solo.engine.tx.USED_PLUS_1 w:solo.engine.tx.used_is_one w:solo.engine.tx.used_gt_one
expose w:solo.engine.tx.not_empty w:solo.engine.tx.full_0 w:solo.engine.tx.nearly_full
rename solo.engine.tx.USED fifo_used
rename solo.engine.tx.USED_MINUS_1 fifo_used_minus_1
rename solo.engine.tx.USED_PLUS_1 fifo_used_plus_1
rename solo.engine.tx.used_is_one fifo_used_is_one
rename solo.engine.tx.used_gt_one fifo_used_gt_one
rename solo.engine.tx.not_empty fifo_not_empty
rename solo.engine.tx.full_0 fifo_full
rename solo.engine.tx.nearly_full fifo_nearly_full
cd ..|}
;;

let fifo_ports =
  ".tx_level(tx_level), .fifo_used(fifo_used),\n\
  \    .fifo_used_minus_1(fifo_used_minus_1), .fifo_used_plus_1(fifo_used_plus_1),\n\
  \    .fifo_used_is_one(fifo_used_is_one), .fifo_used_gt_one(fifo_used_gt_one),\n\
  \    .fifo_not_empty(fifo_not_empty), .fifo_full(fifo_full),\n\
  \    .fifo_nearly_full(fifo_nearly_full),\n\
  \    "
;;

(* one bit or one cycle short: the loop's count, else the first deadline *)
let mutate source =
  let lines = String.split_lines source in
  let shorter =
    List.find_map lines ~f:(fun line ->
      let%bind.Option rest = String.chop_prefix (String.lstrip line) ~prefix:"set x, " in
      let count =
        Int.of_string (String.strip (List.hd_exn (String.split rest ~on:';')))
      in
      Option.some_if (count > 0) (line, [%string "    set x, %{count - 1#Int}"]))
  in
  match shorter with
  | Some (line, mutant) -> String.substr_replace_first source ~pattern:line ~with_:mutant
  | None ->
    String.substr_replace_first
      source
      ~pattern:"    mov t, now\n"
      ~with_:"    mov t, now\n    add t, 1\n"
;;

let create ~name (verilog : Verilog_in.t) (compiled : Frame_compiler.t) =
  let open Or_error.Let_syntax in
  let { Frame_compiler.frame; firmware; timing } = compiled in
  let%bind () =
    if firmware.period_from_host
    then refuse "BUG: a period from the host has no miter"
    else Ok ()
  in
  let%bind () =
    if timing.lag < 2 then refuse "BUG: a lag under 2 leaves no early tooth" else Ok ()
  in
  let sim = verilog.sim in
  let circuit = Bit_sim.circuit sim in
  let ports_of dir =
    List.map dir ~f:(fun s -> List.hd_exn (Signal.names s), Signal.width s)
  in
  let inputs = ports_of (Circuit.inputs circuit) in
  let outputs = ports_of (Circuit.outputs circuit) in
  let is_output name = List.Assoc.mem outputs name ~equal:String.equal in
  (* the registers with a name, each a wire c_k of the miter *)
  let named =
    List.filter_map (Bit_sim.registers sim) ~f:(fun r ->
      Option.map (verilog.register_name r) ~f:(fun name -> r, name))
    |> List.mapi ~f:(fun k (r, name) ->
      ( r
      , name
      , if String.equal name verilog.ports.pin then "c_pin" else [%string "c_%{k#Int}"] ))
  in
  let is_pin name = String.equal name verilog.ports.pin in
  let unnamed = List.length (Bit_sim.registers sim) - List.length named in
  let data_width = frame.data_width in
  let gap = timing.gap in
  let first_take =
    Int.max timing.first_take (Array.length frame.warm_up - 1 + timing.lag)
  in
  let lag = timing.lag in
  (* the circuit's registers by index *)
  let circuit_state (index : Index.t) =
    match index with
    | Warm a when a < Array.length frame.warm_up -> frame.warm_up.(a)
    | Frame k when k <= frame.length -> frame.states.(k)
    | Warm _ | Frame _ | Settled -> frame.idle
  in
  (* the engine over runs: single takes at a few times, and pairs a gap or more apart *)
  let words =
    let mask = (1 lsl data_width) - 1 in
    List.map
      [ 0x5555; 0xaaaa; 0x0f0f; 0xf0f0; 0x3c3c; 0x0000; 0xffff; 0x1234; 0xedcb ]
      ~f:(fun w -> w land mask)
  in
  let scenarios =
    List.concat_map words ~f:(fun w ->
      let other = w lxor ((1 lsl data_width) - 1) in
      [ [ first_take, w ]
      ; [ first_take + 7, w ]
      ; [ first_take + 1, w; first_take + 1 + gap, other ]
      ; [ first_take + 3, other; first_take + 3 + gap + 5, w ]
      ])
  in
  let observations =
    Hashtbl.create
      (module struct
        include Index

        let hash = Hashtbl.hash
      end)
  in
  List.iter scenarios ~f:(fun takes ->
    let cycles = (List.last_exn takes |> fst) + gap + 8 in
    let states = Frame_compiler.engine_states firmware ~takes ~cycles in
    for cycle = 3 to cycles - 1 do
      let last =
        List.filter takes ~f:(fun (at, _) -> at < cycle)
        |> List.max_elt ~compare:(Comparable.lift Int.compare ~f:fst)
      in
      let index, word =
        match last with
        | None -> if cycle < first_take then Index.Warm cycle, None else Settled, None
        | Some (at, w) ->
          let k = cycle - at in
          (if k < gap then Index.Frame k else Settled), Some w
      in
      Hashtbl.add_multi observations ~key:index ~data:(states.(cycle), word)
    done);
  let indices = Hashtbl.keys observations |> List.sort ~compare:Index.compare in
  let condition (index : Index.t) =
    match index with
    | Warm a -> [%string "age == %{a#Int}"]
    | Frame k -> [%string "fc == %{k#Int}"]
    | Settled -> [%string "fc == %{gap#Int} && age == %{first_take#Int}"]
  in
  let assertion cond terms =
    match terms with
    | [] -> []
    | terms ->
      [ sprintf
          "      if (%s)\n        assert (%s);"
          cond
          (String.concat ~sep:"\n          && " terms)
      ]
  in
  let engine_claims =
    List.concat_map indices ~f:(fun index ->
      let seen = Hashtbl.find_multi observations index in
      let terms =
        List.concat_map
          (fields ~out_base:firmware.config.out_base)
          ~f:(fun (field, width, get) ->
            (* the phase grows while the engine waits, so only one every run agrees on
               whole holds *)
            let value =
              mine ~width ~data_width (List.map seen ~f:(fun (m, w) -> get m, w))
            in
            if String.equal field "phase" && not (Bit_sim.Value.is_known value)
            then []
            else equals field value)
      in
      assertion (condition index) terms)
  in
  (* the circuit's pin [back] cycles before an index, where it is known *)
  let warm = Array.length frame.warm_up - 1 in
  let last_run = List.last_exn (Frame_compiler.Frame.runs frame) |> fst in
  let idle_bit = if frame.pin_idle then Bit.One else Zero in
  let pin_before (index : Index.t) ~back : Bit.t =
    match index with
    | Warm a -> if a - back >= warm then idle_bit else Unknown
    | Settled -> idle_bit
    | Frame k when k - back >= 0 ->
      (match frame.pins.(Int.min (k - back) frame.length) with
       | Level b -> if b then One else Zero
       | Data index -> Data { index; inverted = false })
    | Frame k -> if gap + k - back >= last_run then idle_bit else Unknown
  in
  let line_claims index =
    equals "line" (Array.init lag ~f:(fun i -> pin_before index ~back:(i + 1)))
  in
  let circuit_indices =
    List.map (List.range 1 first_take) ~f:(fun a -> Index.Warm a)
    @ List.map (List.range 1 gap) ~f:(fun k -> Index.Frame k)
    @ [ Index.Settled ]
  in
  let circuit_claims =
    List.concat_map circuit_indices ~f:(fun index ->
      let state = circuit_state index in
      let terms =
        List.concat_map named ~f:(fun (r, _, wire) ->
          equals wire (Bit_sim.State.find state r))
        @ line_claims index
      in
      assertion (condition index) terms)
  in
  let idle =
    List.concat_map named ~f:(fun (r, _, wire) ->
      equals wire (Bit_sim.State.find frame.idle r))
    |> function
    | [] -> "1"
    | terms -> String.concat ~sep:"\n    && " terms
  in
  let reset_connection =
    Option.map verilog.ports.reset ~f:(fun (name, level) ->
      match level with
      | High -> [%string ".%{name}(clear)"]
      | Low -> [%string ".%{name}(!clear)"])
  in
  let others =
    List.filter inputs ~f:(fun (name, _) ->
      not
        (String.equal name verilog.clock
         || String.equal name verilog.ports.valid
         || String.equal name verilog.ports.data
         || List.Assoc.mem verilog.ports.tied name ~equal:String.equal
         || Option.exists verilog.ports.reset ~f:(fun (r, _) -> String.equal r name)))
  in
  let connections =
    List.concat
      [ [ [%string ".%{verilog.clock}(clk)"] ]
      ; Option.to_list reset_connection
      ; [ [%string ".%{verilog.ports.valid}(valid_in)"]
        ; [%string ".%{verilog.ports.data}(data_in)"]
        ; [%string ".%{verilog.ports.pin}(c_pin)"]
        ]
      ; List.map verilog.ports.tied ~f:(fun (n, v) ->
          [%string ".%{n}(%{Bits.width v#Int}'d%{Bits.to_unsigned_int v#Int})"])
      ; List.map others ~f:(fun (n, _) -> [%string ".%{n}(other_%{n})"])
      ; List.filter_map named ~f:(fun (_, name, wire) ->
          if is_pin name
          then None
          else if is_output name
          then Some [%string ".%{name}(%{wire})"]
          else Some [%string ".%{wire}(%{wire})"])
      ]
    |> String.concat ~sep:", "
  in
  let wires =
    List.filter_map named ~f:(fun (r, name, wire) ->
      Option.some_if
        (not (is_pin name))
        [%string "  wire [%{Signal.width r - 1#Int}:0] %{wire};"])
    @ List.map others ~f:(fun (n, w) ->
      [%string "  (* anyseq *) wire [%{w - 1#Int}:0] other_%{n};"])
    |> String.concat_lines
  in
  let module_name = "user_" ^ verilog.top in
  let host =
    [%string
      {|  (* anyseq *) wire rx_pop, valid_in;
  (* anyseq *) wire [%{data_width - 1#Int}:0] data_in;
  wire c_pin;
%{wires}  // the circuit's idle state: the registers it knows there
  wire idle = %{idle};
  wire takes = valid_in && idle;
  wire tx_valid = takes;
  wire [15:0] tx_value = data_in;
  wire [%{Host_fifo.level_bits - 1#Int}:0] tx_level;
  wire [%{Int.ceil_log2 Host_fifo.depth#Int}:0] fifo_used, fifo_used_minus_1, fifo_used_plus_1;
  wire fifo_used_is_one, fifo_used_gt_one, fifo_not_empty, fifo_full, fifo_nearly_full;
|}]
  in
  let extra ~(config : Program_config.t) (_ : Analyser.Row.t list) =
    let monitor =
      [%string
        {|  // %{String.concat ~sep:", " (List.map verilog.files ~f:Filename.basename)} as yosys reads it, its registers brought out
  %{module_name} circuit (%{connections});
  // cycles since reset and since the last take, saturating, and the word taken
  reg [15:0] age = 0, fc = %{gap#Int};
  reg [%{data_width - 1#Int}:0] d = 0;
  always @(posedge clk) begin
    age <= clear ? 16'd1 : age == %{first_take#Int} ? age : age + 16'd1;
    fc <= clear ? 16'd%{gap#Int} : takes ? 16'd1 : fc == %{gap#Int} ? fc : fc + 16'd1;
    if (takes) d <= data_in;
  end
  // the circuit's pin, %{lag#Int} cycles back
  reg [%{lag - 1#Int}:0] line = 0;
  always @(posedge clk) line <= {line[%{lag - 2#Int}:0], c_pin};
  // the host: no valid in the first %{first_take#Int} cycles, takes %{gap#Int} or more apart
  always @(*) begin
    assume ((!clear && age >= %{first_take#Int}) || !valid_in);
`ifdef SHORT_GAP
    assume (!takes || fc >= %{timing.shortest - 1#Int});
`else
    assume (!takes || fc >= %{gap#Int});
`endif
  end
  wire pin = pin_out[%{config.out_base#Int}];
`ifndef CLAIM_ONLY
  // the circuit and the counters from the clear on, the engine running or not
  always @(*)
    if (!clear) begin
      assert (age >= 1 && age <= %{first_take#Int} && fc >= 1 && fc <= %{gap#Int});
      if (!running) assert (age == boot && fc == %{gap#Int});
      if (age < %{first_take#Int}) assert (fc == %{gap#Int});
      if (fc < %{gap#Int}) assert (age == %{first_take#Int});
%{String.concat_lines circuit_claims}    end
`endif

|}]
    in
    let claims =
      [%string
        {|`ifndef CLAIM_ONLY
      assert (fifo_used == tx_level && fifo_used_minus_1 == tx_level - 4'd1
        && fifo_used_plus_1 == tx_level + 4'd1 && fifo_used_is_one == (tx_level == 1)
        && fifo_used_gt_one == (tx_level > 1) && fifo_not_empty == (tx_level != 0)
        && !fifo_full && !fifo_nearly_full);
      // the engine, as Machine has it in every run
%{String.concat_lines engine_claims}`endif
      // the pin is the circuit's %{lag#Int} cycles back
`ifdef EARLY
      if (age >= %{first_take#Int}) assert (pin == line[%{lag - 2#Int}]);
`else
      if (age >= %{first_take#Int}) assert (pin == line[%{lag - 1#Int}]);
`endif
|}]
    in
    monitor, claims
  in
  let exposes =
    List.filter_map named ~f:(fun (_, name, wire) ->
      Option.some_if
        (not (is_output name))
        [%string "expose w:%{name}\nrename %{name} %{wire}"])
    |> String.concat_lines
  in
  let parameters =
    List.map verilog.parameters ~f:(fun (p, v) ->
      [%string "chparam -set %{p} %{v} %{verilog.top}"])
    |> String.concat_lines
  in
  let files = List.map verilog.files ~f:Filename.basename in
  let depth_teeth = first_take + (2 * gap) + lag + 8 in
  (* below the shortest the engine follows at, unless the circuit cannot take then *)
  let short_gap = timing.shortest > frame.length in
  let tasks =
    [ "prove"; "early"; "mutant" ] @ if short_gap then [ "short_gap" ] else []
  in
  let short_gap_script =
    if short_gap
    then
      [%string
        "short_gap: read_verilog -formal -sv -DCLAIM_ONLY -DSHORT_GAP %{name}.sv\n"]
    else ""
  in
  let teeth_options =
    List.concat_map (List.tl_exn tasks) ~f:(fun task ->
      [ [%string "%{task}: mode bmc"]
      ; [%string "%{task}: depth %{depth_teeth#Int}"]
      ; [%string "%{task}: expect fail"]
      ])
    |> String.concat_lines
  in
  let sby =
    [%string
      {|# write_certificate.exe -verilog: %{String.concat ~sep:", " files}, top %{verilog.top}, beside the engine
[tasks]
%{String.concat_lines tasks}
[options]
prove: mode prove
prove: depth 3
%{teeth_options}
[engines]
smtbmc boolector

[script]
%{List.map files ~f:(fun f -> "read_verilog " ^ f) |> String.concat_lines}%{parameters}hierarchy -check -top %{verilog.top}
proc
flatten
cd %{verilog.top}
%{exposes}cd ..
rename %{verilog.top} %{module_name}
design -stash circuit
%{engine_lines}
design -copy-from circuit -as %{module_name} %{module_name}
prove: read_verilog -formal -sv %{name}.sv
early: read_verilog -formal -sv -DCLAIM_ONLY -DEARLY %{name}.sv
mutant: read_verilog -formal -sv -DCLAIM_ONLY %{name}_mutant.sv
%{short_gap_script}prep -top certificate
memory_map

[files]
engine_sram.v
%{name}.sv
%{name}_mutant.sv
../src/RM_IHPSG13_1P_512x16_c2_bm_bist.v
%{String.concat_lines (List.map verilog.files ~f:Filename_unix.realpath)}|}]
  in
  let summary =
    [ [%string "lag: the engine's pin is the circuit's %{lag#Int} cycles later"]
    ; [%string
        "assumes: valid low for the first %{first_take#Int} cycles after reset, takes \
         %{gap#Int} or more cycles apart (the circuit's own frame is \
         %{frame.length#Int}, the engine follows it from %{timing.shortest#Int} in \
         simulation)"]
    ]
    @ List.map verilog.ports.tied ~f:(fun (n, v) ->
      [%string "assumes: %{n} tied to %{Bits.to_unsigned_int v#Int}"])
    @ (if List.is_empty verilog.others
       then []
       else [ "not modelled: " ^ String.concat ~sep:", " verilog.others ])
    @
    if unnamed = 0
    then []
    else [ [%string "%{unnamed#Int} registers without a Verilog name have no invariant"] ]
  in
  return
    { host; ports = fifo_ports; extra; mutant = mutate firmware.source; sby; summary }
;;

let usage =
  "write_certificate.exe -verilog FILE... -top MODULE [-pin P] [-valid V] [-data D] \
   [-reset R] [-active-low | -active-high] [-set PARAM=VALUE]... [-tie INPUT=VALUE]... \
   [-name NAME] [-out DIR]"
;;

let run args ~inductive ~print =
  let value name =
    List.find_mapi args ~f:(fun i a ->
      if String.equal a name then List.nth args (i + 1) else None)
  in
  let values name =
    List.filter_mapi args ~f:(fun i a ->
      if String.equal a name then List.nth args (i + 1) else None)
  in
  let flag name = List.mem args name ~equal:String.equal in
  let required name =
    match value name with
    | Some v -> v
    | None -> raise_s [%message usage]
  in
  let files =
    match values "-verilog" with
    | [] -> raise_s [%message usage]
    | files -> files
  in
  let top = required "-top" in
  let parameters =
    List.map (values "-set") ~f:(fun set ->
      match String.lsplit2 set ~on:'=' with
      | Some (p, v) -> p, v
      | None -> raise_s [%message usage])
  in
  let names =
    { Verilog_in.Names.pin = value "-pin"
    ; valid = value "-valid"
    ; data = value "-data"
    ; reset = value "-reset"
    ; active_low =
        (if flag "-active-low"
         then Some true
         else if flag "-active-high"
         then Some false
         else None)
    ; tied =
        List.map (values "-tie") ~f:(fun tie ->
          match String.lsplit2 tie ~on:'=' with
          | Some (input, v) -> input, Int.of_string v
          | None -> raise_s [%message usage])
    }
  in
  let out = Option.value (value "-out") ~default:"." in
  let name = Option.value (value "-name") ~default:("verilog_" ^ String.lowercase top) in
  let result =
    let open Or_error.Let_syntax in
    let%bind verilog = Verilog_in.read ~files ~top ~parameters names in
    let { Frame_compiler.Ports.reset; valid; data; pin; tied = _ } = verilog.ports in
    print
      (sprintf
         "ports: pin %s, valid %s, data %s, reset %s\n"
         pin
         valid
         data
         (match reset with
          | None -> "none"
          | Some (r, High) -> r
          | Some (r, Low) -> r ^ " (active low)"));
    let%bind compiled = Frame_compiler.compile verilog.sim ~ports:verilog.ports in
    let firmware = compiled.firmware in
    print (sprintf "firmware, %s:\n%s\n" top firmware.source);
    let period = Option.some_if firmware.period_from_host firmware.period in
    let rows =
      Analyser.analyse ?period ~config:firmware.config firmware.program.instructions
    in
    let%bind verdict = Analyser.check ?period ~config:firmware.config firmware.program in
    let%bind words = Asm.Program.words firmware.program in
    let%bind () =
      Kernel.check ?period ~config:firmware.config ~words (Kernel.Table.of_analyser rows)
      |> Or_error.tag ~tag:"the kernel refuses it"
    in
    print
      (sprintf
         "certificate (the analyser's rows, which the kernel checks and accepts):\n\
          %s\n\
          %s\n\n"
         (Analyser.to_string ~side_set_count:firmware.config.side_set_count rows)
         (Analyser.Verdict.to_string verdict));
    let words_line = Analyser.Verdict.to_string verdict in
    if firmware.period_from_host
    then
      return
        [ words_line
        ; sprintf
            "no miter: the period, %d, comes from the host, which the miter does not \
             model; prove it at a period under %d"
            firmware.period
            (1 lsl Isa.Field.set_value.width)
        ]
    else (
      let%map miter = create ~name verilog compiled in
      let write path text = Out_channel.write_all (out ^/ path) ~data:text in
      let miter_of source =
        inductive
          ~host:miter.host
          ~ports:miter.ports
          ~extra:miter.extra
          ~config:firmware.config
          source
      in
      write (name ^ ".sv") (miter_of firmware.source);
      write (name ^ "_mutant.sv") (miter_of miter.mutant);
      write (name ^ ".sby") miter.sby;
      (words_line :: miter.summary) @ [ "miter: " ^ out ^/ name ^ ".sby" ])
  in
  result
;;

let main args ~inductive =
  let args = Array.to_list args in
  match run args ~inductive ~print:print_string with
  | Ok summary -> List.iter (List.tl_exn summary) ~f:print_endline
  | Error e ->
    printf "refused: %s\n" (Error.to_string_hum e);
    exit 1
;;

(* test/certify/third_party, each with the names and settings it needs *)
let corpus =
  let dir = "test/certify/third_party/" in
  [ ( "nandland_uart"
    , [ dir ^ "nandland_uart/UART_TX.v"; "-top"; "UART_TX"; "-pin"; "o_TX_Serial" ]
      @ [ "-set"; "CLKS_PER_BIT=4" ] )
  ; ( "alexforencich_uart"
    , [ dir ^ "alexforencich_uart/uart_tx.v"; "-top"; "uart_tx"; "-pin"; "txd" ]
      @ [ "-valid"; "s_axis_tvalid"; "-data"; "s_axis_tdata" ] )
  ; ( "alexforencich_uart_tied"
    , [ dir ^ "alexforencich_uart/uart_tx.v"; "-top"; "uart_tx"; "-pin"; "txd" ]
      @ [ "-valid"; "s_axis_tvalid"; "-data"; "s_axis_tdata"; "-tie"; "prescale=1" ] )
  ; ( "ben_marshall_uart"
    , [ dir ^ "ben_marshall_uart/uart_tx.v"; "-top"; "uart_tx"; "-pin"; "uart_txd" ]
      @ [ "-set"; "CLK_HZ=40"; "-set"; "BIT_RATE=10" ] )
  ; ( "cyrozap_osdvu"
    , [ dir ^ "cyrozap_osdvu/uart.v"; "-top"; "uart"; "-pin"; "tx"; "-valid"; "transmit" ]
      @ [ "-data"; "tx_byte" ] )
  ; ( "nandland_spi"
    , [ dir ^ "nandland_spi/SPI_Master.v"; "-top"; "SPI_Master"; "-pin"; "o_SPI_MOSI" ]
      @ [ "-valid"; "i_TX_DV"; "-data"; "i_TX_Byte" ] )
  ]
;;

let main_corpus args ~inductive =
  let args = Array.to_list args in
  let out =
    List.find_mapi args ~f:(fun i a ->
      if String.equal a "-out" then List.nth args (i + 1) else None)
    |> Option.value ~default:"."
  in
  List.iter corpus ~f:(fun (name, args) ->
    let args = ("-verilog" :: args) @ [ "-name"; "verilog_" ^ name; "-out"; out ] in
    match run args ~inductive ~print:ignore with
    | Ok summary -> printf "%s: accepted, %s\n" name (String.concat ~sep:"; " summary)
    | Error e ->
      Error.to_string_hum e
      |> String.split_lines
      |> List.map ~f:String.strip
      |> String.concat ~sep:" "
      |> printf "%s: refused, %s\n" name)
;;
