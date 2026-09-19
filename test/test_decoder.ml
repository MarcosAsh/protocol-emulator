open! Core
open! Hardcaml
open Protocol_emulator
module D = Decoder.Make (Bits)

let bits = Bits.of_unsigned_int

let expected (t : Isa.t) (d : Bits.t Decoder.Decoded.t) =
  match t with
  | Jmp { cond; target } ->
    [%test_result: Isa.Opcode.Cases.t Or_error.t]
      (Isa.Opcode.to_enum d.opcode)
      ~expect:(Ok Jmp);
    [%test_result: Isa.Jmp_cond.Cases.t Or_error.t]
      (Isa.Jmp_cond.to_enum d.jmp_cond)
      ~expect:(Ok cond);
    [%test_result: int] (Bits.to_unsigned_int d.jmp_target) ~expect:target
  | Op { op; delay; side_set } ->
    [%test_result: int] (Bits.to_unsigned_int d.delay) ~expect:delay;
    [%test_result: int] (Bits.to_unsigned_int d.side_set) ~expect:side_set;
    let opcode = Isa.Opcode.to_enum d.opcode |> ok_exn in
    (match op with
     | Wait wait ->
       [%test_result: Isa.Opcode.Cases.t] opcode ~expect:Wait;
       let source, polarity, index =
         match wait with
         | Pin_level { pin; level } -> Isa.Wait_source.Cases.Pin_level, level, pin
         | Pin_edge { pin; rising } -> Pin_edge, rising, pin
         | Deadline { advance } -> Deadline, advance, 0
         | Fifo Tx_not_empty -> Fifo, true, 0
         | Fifo Rx_not_full -> Fifo, false, 0
       in
       [%test_result: Isa.Wait_source.Cases.t Or_error.t]
         (Isa.Wait_source.to_enum d.wait_source)
         ~expect:(Ok source);
       [%test_result: bool] (Bits.to_bool d.wait_polarity) ~expect:polarity;
       [%test_result: int] (Bits.to_unsigned_int d.wait_index) ~expect:index
     | In { source; count } ->
       [%test_result: Isa.Opcode.Cases.t] opcode ~expect:In;
       [%test_result: Isa.In_source.Cases.t Or_error.t]
         (Isa.In_source.to_enum d.in_source)
         ~expect:(Ok source);
       [%test_result: int] (Bits.to_unsigned_int d.shift_count) ~expect:count
     | Out { dest; count } ->
       [%test_result: Isa.Opcode.Cases.t] opcode ~expect:Out;
       [%test_result: Isa.Out_dest.Cases.t Or_error.t]
         (Isa.Out_dest.to_enum d.out_dest)
         ~expect:(Ok dest);
       [%test_result: int] (Bits.to_unsigned_int d.shift_count) ~expect:count
     | Mov { dest; op; source } ->
       [%test_result: Isa.Opcode.Cases.t] opcode ~expect:Mov;
       [%test_result: Isa.Mov_dest.Cases.t Or_error.t]
         (Isa.Mov_dest.to_enum d.mov_dest)
         ~expect:(Ok dest);
       [%test_result: Isa.Mov_op.Cases.t Or_error.t]
         (Isa.Mov_op.to_enum d.mov_op)
         ~expect:(Ok op);
       [%test_result: Isa.Mov_source.Cases.t Or_error.t]
         (Isa.Mov_source.to_enum d.mov_source)
         ~expect:(Ok source)
     | Set { dest; value } ->
       [%test_result: Isa.Opcode.Cases.t] opcode ~expect:Set;
       [%test_result: Isa.Set_dest.Cases.t Or_error.t]
         (Isa.Set_dest.to_enum d.set_dest)
         ~expect:(Ok dest);
       [%test_result: int] (Bits.to_unsigned_int d.set_value) ~expect:value
     | Alu { dest; op; operand } ->
       [%test_result: Isa.Opcode.Cases.t] opcode ~expect:Alu;
       [%test_result: Isa.Alu_dest.Cases.t Or_error.t]
         (Isa.Alu_dest.to_enum d.alu_dest)
         ~expect:(Ok dest);
       [%test_result: Isa.Alu_op.Cases.t Or_error.t]
         (Isa.Alu_op.to_enum d.alu_op)
         ~expect:(Ok op);
       (match operand with
        | Imm imm ->
          [%test_result: bool] (Bits.to_bool d.alu_is_reg) ~expect:false;
          [%test_result: int] (Bits.to_unsigned_int d.alu_imm) ~expect:imm
        | Reg reg ->
          [%test_result: bool] (Bits.to_bool d.alu_is_reg) ~expect:true;
          [%test_result: Isa.Alu_reg.Cases.t Or_error.t]
            (Isa.Alu_reg.to_enum d.alu_reg)
            ~expect:(Ok reg))
     | Sys sys ->
       [%test_result: Isa.Opcode.Cases.t] opcode ~expect:Sys;
       [%test_result: Isa.Sys_op.Cases.t Or_error.t]
         (Isa.Sys_op.to_enum d.sys_op)
         ~expect:(Ok sys))
;;

let%expect_test "the decoder agrees with the spec on every word" =
  List.iter [ 0; 1; 2 ] ~f:(fun side_set_count ->
    let accepted = ref 0 in
    for word = 0 to (1 lsl Isa.word_bits) - 1 do
      let d =
        D.decode
          ~side_set_count:(bits ~width:2 side_set_count)
          (bits ~width:Isa.word_bits word)
      in
      match Isa.of_word ~side_set_count word with
      | Error _ ->
        if Bits.to_bool d.valid
        then raise_s [%message "hardware accepts a word the spec rejects" (word : int)]
      | Ok t ->
        if not (Bits.to_bool d.valid)
        then raise_s [%message "hardware rejects a word the spec accepts" (word : int)];
        Int.incr accepted;
        expected t d
    done;
    let accepted = !accepted in
    print_s [%message (side_set_count : int) (accepted : int)]);
  [%expect
    {|
    ((side_set_count 0) (accepted 31488))
    ((side_set_count 1) (accepted 31488))
    ((side_set_count 2) (accepted 31488))
    |}]
;;
