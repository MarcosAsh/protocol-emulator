open! Core
open! Hardcaml
open! Signal

module type Config = sig
  val engines : int
end

module Make (Config : Config) = struct
  let engines = Config.engines

  let () =
    if engines < 1 || engines > 2
    then
      raise_s [%message "BUG: one data memory serves one or two engines" (engines : int)]
  ;;

  module I = struct
    type 'a t =
      { clocking : 'a Clocking.t
      ; halted : 'a list [@length engines] [@bits 1]
      ; writes : 'a Engine.Program_write.t list [@length engines]
      ; reads : 'a list [@length engines] [@bits Isa.data_addr_bits]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { words : 'a list [@length engines] [@bits Isa.data_bits] }
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
    let memory_in =
      { Program_memory.I.clock = i.clocking.clock
      ; men = vdd
      ; wen = write
      ; ren = vdd
      ; addr = mux2 write (written ~f:(fun w -> w.addr)) read_addr
      ; din = written ~f:(fun w -> w.data)
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
        (* on this engine's turn the memory reads where its pointer will be, so the next
           cycle's output is the word at the pointer *)
        let%hw mine = reg spec (turn ==:. n &: ~:write) in
        let%hw last = reg spec ~enable:mine dout in
        mux2 mine dout last)
    in
    { O.words }
  ;;

  let hierarchical ?instance ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"data_memory" (create ~memory) i
  ;;
end
