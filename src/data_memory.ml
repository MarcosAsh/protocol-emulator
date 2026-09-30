open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val engines : int
  val journal : bool
end

module Make (Config : Config) = struct
  let engines = Config.engines
  let journals = Bool.to_int Config.journal

  let () =
    if engines < 1 || engines > 2
    then
      raise_s [%message "BUG: one data memory serves one or two engines" (engines : int)];
    if Config.journal && engines <> 2
    then raise_s [%message "BUG: the journal writes in engine 1's turn" (engines : int)]
  ;;

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; halted : 'a list [@length engines] [@bits 1]
      ; writes : 'a Engine.Program_write.t list [@length engines]
      ; reads : 'a list [@length engines] [@bits Isa.data_addr_bits]
      ; journal : 'a Engine.Program_write.t list [@length journals]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { words : 'a list [@length engines] [@bits Isa.data_bits]
      ; journal_slot : 'a list [@length journals]
      }
    [@@deriving hardcaml]
  end

  let create ~(memory : Engine.Memory.t) (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let%hw writes_open = List.reduce_exn i.halted ~f:( &: ) in
    let%hw write =
      writes_open &: List.reduce_exn (List.map i.writes ~f:(fun w -> w.valid)) ~f:( |: )
    in
    let written ~f =
      priority_select_with_default
        (List.map i.writes ~f:(fun (w : _ Engine.Program_write.t) ->
           { With_valid.valid = w.valid; value = f w }))
        ~default:(zero (width (f (List.hd_exn i.writes))))
    in
    (* whose turn it is to read, one cycle each *)
    let%hw turn = wire 1 in
    turn <-- if engines = 1 then gnd else reg spec ~:turn;
    let%hw read_addr = mux turn i.reads in
    let host_addr = written ~f:(fun w -> w.addr) in
    let host_data = written ~f:(fun w -> w.data) in
    (* the journal takes engine 1's turn, and only the top half *)
    let journal_slot = List.map i.journal ~f:(fun _ -> turn &: ~:write) in
    let wen, addr, din =
      match i.journal, journal_slot with
      | [], _ -> write, mux2 write host_addr read_addr, host_data
      | [ journal ], [ slot ] ->
        let%hw journal_write = journal.valid &: slot in
        let journal_addr = vdd @: drop_top journal.addr ~width:1 in
        ( write |: journal_write
        , mux2 write host_addr @@ mux2 journal_write journal_addr @@ read_addr
        , mux2 journal_write journal.data host_data )
      | _ -> raise_s [%message "BUG: one journal at most"]
    in
    let memory_in =
      { Program_memory.I.clock = i.clocking.clock
      ; men = vdd
      ; wen
      ; ren = vdd
      ; addr
      ; din
      ; bm = ones Isa.data_bits
      }
    in
    let dout =
      match memory with
      | Flops -> (Program_memory.hierarchical scope memory_in).dout
      | Ihp_sram -> (Sram_macro.hierarchical scope memory_in).dout
    in
    let words =
      List.mapi i.reads ~f:(fun n _ ->
        (* reads where the pointer will be, so next cycle's output is the word at it *)
        let%hw mine = reg spec (turn ==:. n &: ~:wen) in
        let%hw last = reg spec ~enable:mine dout in
        mux2 mine dout last)
    in
    { O.words; journal_slot }
  ;;

  let hierarchical ?instance ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"data_memory" (create ~memory) i
  ;;
end
