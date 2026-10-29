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
      ; walked : 'a list [@length engines] [@bits 1]
      ; writes : 'a Engine.Program_write.t list [@length engines]
      ; reads : 'a list [@length engines] [@bits Isa.data_addr_bits]
      ; dma : 'a Engine.Program_write.t
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { words : 'a list [@length engines] [@bits Isa.data_bits]
      ; whose_turn : 'a
      ; keeps : 'a list [@length engines] [@bits 1]
      ; host_write : 'a
      ; written : 'a With_valid.t [@bits Isa.data_addr_bits]
      }
    [@@deriving hardcaml]
  end

  let create ~(memory : Engine.Memory.t) (scope : Scope.t) (i : Signal.t I.t) =
    let spec = Clocking.to_spec i.clocking in
    let%hw writes_open = List.reduce_exn i.halted ~f:( &: ) in
    (* nor while the checker walks another engine, whose reads a write would take *)
    let%hw_list lands =
      List.mapi i.writes ~f:(fun n (w : _ Engine.Program_write.t) ->
        w.valid
        &: writes_open
        &: ~:(List.filteri i.walked ~f:(fun m _ -> m <> n)
              |> List.fold ~init:gnd ~f:( |: )))
    in
    let%hw host_write = List.reduce_exn lands ~f:( |: ) in
    (* the caller lets the other writer in only where no read it serves is lost *)
    let%hw write = host_write |: i.dma.valid in
    let written ~f =
      priority_select_with_default
        (List.map2_exn i.writes lands ~f:(fun (w : _ Engine.Program_write.t) lands ->
           { With_valid.valid = lands; value = f w }))
        ~default:(zero (width (f (List.hd_exn i.writes))))
    in
    let%hw write_addr = mux2 host_write (written ~f:(fun w -> w.addr)) i.dma.addr in
    (* whose turn it is to read, one cycle each *)
    let%hw turn = wire 1 in
    turn <-- if engines = 1 then gnd else reg spec ~:turn;
    let%hw read_addr = mux turn i.reads in
    let memory_in =
      { Program_memory.I.clock = i.clocking.clock
      ; men = vdd
      ; wen = write
      ; ren = vdd
      ; addr = mux2 write write_addr read_addr
      ; din = mux2 host_write (written ~f:(fun w -> w.data)) i.dma.data
      ; bm = ones Isa.data_bits
      }
    in
    let dout =
      match memory with
      | Flops -> (Program_memory.hierarchical scope memory_in).dout
      | Ihp_sram -> (Sram_macro.hierarchical scope memory_in).dout
    in
    (* A running engine keeps its word while its next address is the one it last read and
       nothing has written there since: its last word is the word the read would give, so
       it skips the read and a write may take its turn. *)
    let%hw_list held =
      List.mapi i.reads ~f:(fun n read -> reg spec ~enable:(turn ==:. n &: ~:write) read)
    in
    let%hw_list held_valid =
      List.mapi (List.zip_exn held i.halted) ~f:(fun n (held, halted) ->
        reg_fb spec ~width:1 ~f:(fun valid ->
          mux2
            (halted |: (write &: (write_addr ==: held)))
            gnd
            (valid |: (turn ==:. n &: ~:write))))
    in
    let%hw_list keeps =
      List.map3_exn
        i.reads
        (List.zip_exn held held_valid)
        i.halted
        ~f:(fun read (held, valid) halted -> valid &: ~:halted &: (read ==: held))
    in
    let words =
      List.mapi (List.zip_exn i.reads keeps) ~f:(fun n (_, keeps) ->
        (* reads where the pointer will be, so next cycle's output is the word at it *)
        let%hw mine = reg spec (turn ==:. n &: ~:write &: ~:keeps) in
        let%hw last = reg spec ~enable:mine dout in
        mux2 mine dout last)
    in
    { O.words
    ; whose_turn = turn
    ; keeps
    ; host_write
    ; written = { valid = write; value = write_addr }
    }
  ;;

  let hierarchical ?instance ~memory scope i =
    let module H = Hierarchy.In_scope (I) (O) in
    H.hierarchical ?instance ~scope ~name:"data_memory" (create ~memory) i
  ;;
end
