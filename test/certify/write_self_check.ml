open! Core
open! Hardcaml
open Protocol_emulator
open Protocol_emulator_test

(* [Self_check.checker] on the core beside its contract, [Self_check_contract]: for any
   line, the irq rises only after a break of the contract, is up by the cycle the contract
   says, and no deadline of the checker's is missed. For one set of edges, and as far from
   the clear as formal/self_check.sby looks. With -invariants, for all time but only up to
   a break: no irq, no halt, none of the checker's deadlines missed. *)

let max_inner = 9

module Contract = Self_check_contract.Make (struct
    let max_inner = max_inner
  end)

let pin = 0

let contract_verilog () =
  let scope = Scope.create ~flatten_design:true () in
  let module C = Circuit.With_interface (Contract.I) (Contract.O) in
  [ C.create_exn ~name:"self_check_contract" (Contract.hierarchical scope) ]
  |> Rtl.create Verilog
  |> Rtl.full_hierarchy
  |> Rope.to_string
;;

let rom name words =
  List.mapi words ~f:(fun a w -> sprintf "      %d: %s = 16'h%04x;" a name w)
  |> String.concat ~sep:"\n"
;;

(* teeth: a checker that takes a fall's stamp a cycle off, one that takes the next frame's
   first edge a cycle off, one that halts without its irq, and one that raises it a cycle
   late *)
let mutate source = function
  | None -> source
  | Some (pattern, with_) ->
    let mutated = String.substr_replace_first source ~pattern ~with_ in
    if String.equal mutated source then raise_s [%message "BUG: no" pattern];
    mutated
;;

(* Invariants proposed for the induction: what each register holds, keyed by the
   contract's phase, the pc and the row pointer, in every cycle before a break of
   simulated runs of the model beside the contract. Claimed under INVARIANTS. *)
module Sim = Cyclesim.With_interface (Contract.I) (Contract.O)

module Feature = struct
  type t =
    { verilog : string
    ; width : int
    ; in_frame : bool
    ; read : Machine.t -> int Contract.O.t -> int
    }

  let all =
    let plain verilog width read =
      { verilog; width; in_frame = false; read = (fun m _ -> read m) }
    in
    let contract verilog width read =
      { verilog; width; in_frame = false; read = (fun _ o -> read o) }
    in
    (* a time as cycles from the frame's start, as the core's own arithmetic wraps it *)
    let from_start verilog width read =
      { verilog
      ; width
      ; in_frame = true
      ; read =
          (fun (m : Machine.t) (o : _ Contract.O.t) ->
            (read m - m.now + o.position) land ((1 lsl width) - 1))
      }
    in
    [ plain "stall" 5 (fun (m : Machine.t) -> m.stall)
    ; plain "osr_count" 5 (fun (m : Machine.t) -> m.osr_count)
    ; plain "osr" 16 (fun (m : Machine.t) -> m.osr)
    ; plain "isr_count" 5 (fun (m : Machine.t) -> m.isr_count)
    ; plain "isr" 16 (fun (m : Machine.t) -> m.isr)
    ; plain "p" 16 (fun (m : Machine.t) -> m.p)
    ; plain "y" 16 (fun (m : Machine.t) -> m.y)
    ; plain "capture_armed" 1 (fun (m : Machine.t) -> Bool.to_int m.capture_armed)
    ; from_start "t_age" Isa.timer_bits (fun (m : Machine.t) -> m.t)
    ; from_start "capture_age" Isa.timer_bits (fun (m : Machine.t) -> m.capture)
    ; from_start "x_age" 16 (fun (m : Machine.t) -> m.x)
    ; from_start "y_age" 16 (fun (m : Machine.t) -> m.y)
    ; from_start "isr_age" 16 (fun (m : Machine.t) -> m.isr)
    ; { verilog = "position"
      ; width = Self_check_contract.position_bits
      ; in_frame = true
      ; read = (fun _ o -> o.position)
      }
    ; { verilog = "position + stall"
      ; width = Self_check_contract.position_bits
      ; in_frame = true
      ; read = (fun m o -> o.position + m.stall)
      }
    ; contract "contract_boot" Contract.O.port_widths.boot (fun o -> o.boot)
    ; contract "previous" 1 (fun o -> o.previous)
    ]
    (* early and at last, set only by a break; the others carry state in clean runs *)
    @ List.map [ 2; 3 ] ~f:(fun bit ->
      contract [%string "flags[%{bit#Int}]"] 1 (fun o -> (o.flags lsr bit) land 1))
    @ [ contract "ended" Contract.O.port_widths.ended (fun o -> o.ended) ]
    @
    (* the stamps against each other, as 16 bits *)
    let stamps : (string * (Machine.t -> int)) list =
      [ ("x", fun m -> m.x)
      ; ("y", fun m -> m.y)
      ; ("isr", fun m -> m.isr)
      ; ("capture[15:0]", fun m -> m.capture)
      ; ("t[15:0]", fun m -> m.t)
      ]
    in
    List.concat_mapi stamps ~f:(fun n (a, read_a) ->
      List.drop stamps (n + 1)
      |> List.map ~f:(fun (b, read_b) ->
        plain [%string "%{a} - %{b}"] 16 (fun m -> (read_a m - read_b m) land 0xffff)))
  ;;
end

(* [Frame] in the contract's phase, as its mli numbers them *)
let frame = 3

let samples ~edges ~base ~program ~config =
  let open Self_check_monitor in
  let rs = Random.State.make [| 1 |] in
  let m = List.length edges in
  let edges = Array.of_list edges in
  let data =
    List.init base ~f:(fun _ -> 0)
    @ (Self_check.rows ~base (Array.to_list edges) |> ok_exn)
  in
  let sim = Sim.create (Contract.hierarchical (Scope.create ~flatten_design:true ())) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let found = Hashtbl.Poly.create () in
  let rand lo hi = lo + Random.State.int rs (hi - lo + 1) in
  let set r v = r := Bits.of_unsigned_int ~width:(Bits.width !r) v in
  for _ = 1 to 2000 do
    let idle =
      List.init 3 ~f:(fun _ -> if Random.State.bool rs then rand 0 3 else rand 0 40)
    in
    let lead_in = rand 9 40 in
    let c = Case.frames ~lead_in ~idle edges (Array.create ~len:m 0) in
    let levels =
      Array.map c.starts ~f:(fun _ ->
        Array.init m ~f:(fun k ->
          if k = 0 then 0 else if k = m - 1 then 1 else Random.State.int rs 2))
    in
    (* the line low from the clear for a while, so the checker waits for it high, and
       glitches before the first frame *)
    let mutations =
      (if Random.State.bool rs then [ Case.Pulse { at = 0; width = rand 1 20 } ] else [])
      @ List.init (rand 0 3) ~f:(fun _ ->
        Case.Pulse { at = rand 0 (lead_in - 1); width = rand 1 5 })
    in
    let w = Case.wave { c with levels; mutations } in
    i.clocking.clear := Bits.vdd;
    Cyclesim.cycle sim;
    i.clocking.clear := Bits.gnd;
    List.iteri i.inner ~f:(fun n edge -> set edge (if n < m - 1 then edges.(n) else 0));
    set i.count (m - 1);
    set i.least edges.(m - 1);
    let machine =
      ref (Machine.load_data (Machine.create ~config ~program |> ok_exn) data |> ok_exn)
    in
    for n = 0 to Bytes.length w - 1 do
      let int r = Bits.to_unsigned_int !r in
      let s = !machine in
      if int o.violated = 0
      then (
        let o = Contract.O.map o ~f:int in
        let phase = o.phase in
        let key = phase, s.pc, s.data_ptr in
        List.iter Feature.all ~f:(fun (f : Feature.t) ->
          if phase = frame || not f.in_frame
          then
            Hashtbl.update found (key, f.verilog) ~f:(fun v ->
              Set.add (Option.value v ~default:Int.Set.empty) (f.read s o))));
      let line = Char.to_int (Bytes.get w n) in
      set i.line line;
      Cyclesim.cycle sim;
      machine := Machine.step s ~inputs:(line lsl pin)
    done
  done;
  found
;;

(* mined claims the induction could not keep, by key and feature: the line high a cycle
   before, in the high branch, true in every simulated run but not inductive *)
let refuted =
  List.map
    [ 16, 2; 17, 3; 18, 3; 19, 3; 12, 3; 13, 3 ]
    ~f:(fun (pc, data_ptr) -> (3, pc, data_ptr), "previous")
;;

let mined ~edges ~base ~program ~config =
  let found = samples ~edges ~base ~program ~config in
  let keys =
    Hashtbl.keys found
    |> List.map ~f:fst
    |> List.dedup_and_sort ~compare:[%compare: int * int * int]
  in
  let at (phase, pc, ptr) =
    sprintf "phase == %d && pc == %d && data_ptr == %d" phase pc ptr
  in
  let reachable =
    List.map keys ~f:(fun key -> "(" ^ at key ^ ")") |> String.concat ~sep:"\n        || "
  in
  let claim (f : Feature.t) values =
    if List.length values <= 4
    then
      Some
        ("("
         ^ (List.map values ~f:(fun v -> sprintf "%s == %d'd%d" f.verilog f.width v)
            |> String.concat ~sep:" || ")
         ^ ")")
    else if String.equal f.verilog "stall" || String.equal f.verilog "position"
    then
      Some
        (sprintf
           "%s >= %d && %s <= %d"
           f.verilog
           (List.hd_exn values)
           f.verilog
           (List.last_exn values))
    else None
  in
  (* one claim a line, so a failing one is named by its line *)
  let claims =
    List.concat_map keys ~f:(fun key ->
      List.filter_map Feature.all ~f:(fun (f : Feature.t) ->
        if List.mem refuted (key, f.verilog) ~equal:[%equal: (int * int * int) * string]
        then None
        else
          Option.bind
            (Hashtbl.find found (key, f.verilog))
            ~f:(fun values ->
              claim f (Set.to_list values)
              |> Option.map ~f:(sprintf "      if (%s) assert (%s);" (at key)))))
    |> String.concat ~sep:"\n"
  in
  [%string
    {|  // what each register holds by the contract's phase, the pc and the row pointer, in
  // every cycle before a break of the simulated runs
  wire [23:0] t_age = t - now + position;
  wire [23:0] capture_age = capture - now + position;
  wire [15:0] x_age = x - now[15:0] + position;
  wire [15:0] y_age = y - now[15:0] + position;
  wire [15:0] isr_age = isr - now[15:0] + position;
  always @(*)
    if (running && !violated) begin
      assert (!halted && !irq && !missed);
`ifdef TEETH
      // a tooth: a frame is reached, so the lemma speaks of one
      assert (phase != 3);
`endif
      // a tooth leaves the mined claims out, so what fails is the alarm itself
`ifndef SHIFTED
      assert (%{reachable});
%{claims}
`endif
    end
|}]
;;

(* the theorem, with covers that each deadline is met to the cycle *)
let contract_checks =
  {|  always @(*)
    if (running) begin
      assert (!irq || violated);
      assert (!overdue || irq);
      assert (!missed);
    end

  // the irq rising in the very cycle it falls due, for a break five or more before the
  // least and for one later: neither deadline is loose
  reg was_irq = 0;
  always @(posedge clk) was_irq <= irq;
  wire due_now = overdue && irq && !was_irq;
  always @(posedge clk) begin
    cover (running && irq);
    cover (running && due_now && !late);
    cover (running && due_now && late);
    // two clean frames, the second anchored where the first left off
    cover (running && ended == 2 && !violated);
  end
|}
;;

(* the core's own, as write_certificate's inductive certificates have them, and the data
   memory's read a cycle on *)
let core_invariants ~after =
  [%string
    {|  wire [27:0] wait_pin = 28'd1 << instruction[4:0];
  function [8:0] after(input [8:0] a);
    after = %{after};
  endfunction
  reg started = 0;
  always @(posedge clk) started <= start;
  wire issue = running && eng_issue && !started;
  reg jumped = 0;
  always @(posedge clk) jumped <= start || eng_jmp_go;
  reg last_issue = 0;
  reg [8:0] last_pc = 0, last_data_addr = 0;
  always @(posedge clk) begin
    last_issue <= issue;
    last_pc <= pc;
    last_data_addr <= data_sram_addr;
  end
  wire stalled = issue && last_issue && last_pc == pc;
  always @(*)
    if (running) begin
      assert (!started);
      assert (decode_ok && opcode_onehot == (8'd1 << instruction[15:13]));
      assert (wait_select == wait_pin);
      if (!jumped) assert (instruction == rom(pc) && fetched == rom(after(pc)));
      if (jumped) assert (stall == 1 && fetched == rom(pc));
      if (stalled) assert (instruction[15:13] == 1);
      assert (data_word == rows(last_data_addr));
    end
|}]
;;

let harness ?(invariants = false) ~edges ~base ~mutant () =
  let source = mutate (Self_check.checker ~pin ~base) mutant in
  let program = Asm.assemble source |> ok_exn in
  let config = Asm.Program.configure program (Self_check.checker_config ~pin) in
  let words = Asm.Program.words program |> ok_exn in
  let rows = Self_check.rows ~base edges |> ok_exn in
  let inner = List.drop_last_exn edges in
  let least = List.last_exn edges in
  if List.length inner > max_inner
  then raise_s [%message "more edges than the contract keeps"];
  let widths = Contract.I.port_widths in
  let outs = Contract.O.port_widths in
  let config_ports =
    Engine.Config.(
      to_list
        (map2 port_names (of_program_config config) ~f:(fun name bits ->
           [%string
             ".config$%{name}(%{Bits.width bits#Int}'d%{Bits.to_unsigned_int bits#Int})"])))
    |> String.concat ~sep:",\n    "
  in
  let after =
    [%string "a == %{config.wrap_top#Int} ? 9'd%{config.wrap_bottom#Int} : a + 9'd1"]
  in
  let core_wires, core_ports, checks =
    if invariants
    then
      ( {|  wire [15:0] instruction;
  wire decode_ok, eng_issue, eng_jmp_go;
  wire [7:0] opcode_onehot;
  wire [27:0] wait_select;
|}
      , {|, .instruction(instruction),
    .decode_ok(decode_ok), .opcode_onehot(opcode_onehot), .wait_select(wait_select),
    .eng_issue(eng_issue), .eng_jmp_go(eng_jmp_go)|}
      , core_invariants ~after ^ mined ~edges ~base ~program:words ~config )
    else "", "", contract_checks
  in
  let inner_ports =
    List.mapi widths.inner ~f:(fun n width ->
      let edge = List.nth inner n |> Option.value ~default:0 in
      (* a tooth: the contract's first edge a cycle late, so a checker true to its rows
         raises a false alarm *)
      let shifted = if invariants && n = 0 then " `ifdef SHIFTED + 1 `endif" else "" in
      [%string ".inner_%{n#Int}(%{width#Int}'d%{edge#Int}%{shifted})"])
    |> String.concat ~sep:", "
  in
  [%string
    {|// Generated by test/certify/write_self_check.exe: Self_check.checker on pin %{pin#Int}
// with rows at %{base#Int} for edges %{String.concat ~sep:" " (List.map edges ~f:Int.to_string)}, beside its contract. The line is free.
module self_check (input clk);
  (* anyseq *) wire [27:0] inputs;

  function [15:0] rom(input [8:0] a);
    case (a)
%{rom "rom" words}
      default: rom = 0;
    endcase
  endfunction
  function [15:0] rows(input [8:0] a);
    case (a)
%{rom "rows" (List.init base ~f:(fun _ -> 0) @ rows)}
      default: rows = 0;
    endcase
  endfunction

  reg [1:0] boot = 0;
  always @(posedge clk) if (boot != 3) boot <= boot + 1;
  wire clear = boot == 0;
  wire start = boot == 1;
  // the checker's cycle 0, as the model counts, is the first running
  wire running = boot == 3;

  wire [8:0] sram_addr, data_sram_addr;
  reg [15:0] fetched, data_word;
  always @(posedge clk) begin
    fetched <= rom(sram_addr);
    data_word <= rows(data_sram_addr);
  end
  wire irq, missed, halted, capture_armed;
  wire [8:0] pc, data_ptr;
  wire [15:0] x, y, p, osr, isr;
  wire [23:0] t, now, capture;
  wire [4:0] osr_count, isr_count, stall;
%{core_wires}  engine_top dut (
    .clock(clk), .clear(clear),
    %{config_ports},
    .start(start), .program_write$valid(1'b0), .program_write$addr(9'b0),
    .program_write$data(16'b0), .data_write$valid(1'b0), .data_write$addr(9'b0),
    .data_write$data(16'b0), .tx$valid(1'b0), .tx$value(16'b0), .rx_pop(1'b0),
    .clear_irq(1'b0), .stop(1'b0), .flush(1'b0),
    .inputs(inputs), .sram_addr(sram_addr), .sram_dout(fetched),
    .data_sram_addr(data_sram_addr), .data_sram_dout(data_word),
    .irq(irq), .fault$missed_deadline(missed), .halted(halted), .pc(pc),
    .data_ptr(data_ptr), .x(x), .y(y), .p(p), .t(t), .now(now), .osr(osr),
    .osr_count(osr_count), .isr(isr), .isr_count(isr_count), .stall(stall),
    .capture(capture), .capture_armed(capture_armed)%{core_ports});

  wire violated, overdue, late;
  wire [%{outs.ended - 1#Int}:0] ended;
  wire [%{outs.phase - 1#Int}:0] phase;
  wire [%{outs.boot - 1#Int}:0] contract_boot;
  wire [%{outs.position - 1#Int}:0] position;
  wire previous;
  wire [%{outs.flags - 1#Int}:0] flags;
  self_check_contract contract (
    .clock(clk), .clear(!running), .line(inputs[%{pin#Int}]),
    %{inner_ports},
    .count(%{widths.count#Int}'d%{List.length inner#Int}), .least(%{widths.least#Int}'d%{least#Int}),
    .violated(violated), .overdue(overdue), .ended(ended),
    .late(late), .phase(phase), .position(position), .boot(contract_boot),
    .previous(previous), .flags(flags));

%{checks}endmodule

%{contract_verilog ()}|}]
;;

let () =
  let args = Sys.get_argv () in
  let value name =
    Array.findi args ~f:(fun _ a -> String.equal a name)
    |> Option.map ~f:(fun (i, _) -> args.(i + 1))
  in
  let mutant =
    match value "-mutant" with
    | None -> None
    | Some "stamp" -> Some ("sub x, 5", "sub x, 4")
    | Some "least" -> Some ("add x, 6", "add x, 7")
    | Some "silent" -> Some ("    irq\n", "    mov x, x\n")
    | Some "slow" -> Some ("fault:\n", "fault:\n    mov x, x\n")
    | Some other -> raise_s [%message "unknown mutant" other]
  in
  let edges =
    value "-edges"
    |> Option.value_map ~default:[ 29; 46; 63; 83 ] ~f:(fun s ->
      String.split s ~on:',' |> List.map ~f:Int.of_string)
  in
  let base = value "-base" |> Option.value_map ~default:0 ~f:Int.of_string in
  print_string
    (harness
       ~invariants:(Array.mem args "-invariants" ~equal:String.equal)
       ~edges
       ~base
       ~mutant
       ())
;;
