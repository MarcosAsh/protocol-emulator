module sram_macro (
    clock,
    men,
    wen,
    ren,
    addr,
    din,
    bm,
    dout
);

    input clock;
    input men;
    input wen;
    input ren;
    input [8:0] addr;
    input [15:0] din;
    input [15:0] bm;
    output [15:0] dout;

    wire [15:0] signal_const;
    wire [8:0] signal_const_2;
    wire gnd;
    wire [15:0] signal_wire;
    wire vdd;
    wire [15:0] signal_wire_1;
    wire [8:0] signal_wire_2;
    wire signal_wire_3;
    wire signal_wire_4;
    wire signal_wire_5;
    wire signal_wire_6;
    wire [15:0] signal_inst;
    wire [15:0] signal_wire_7;
    assign signal_const = 16'b0000000000000000;
    assign signal_const_2 = 9'b000000000;
    assign gnd = 1'b0;
    assign signal_wire = bm;
    assign vdd = 1'b1;
    assign signal_wire_1 = din;
    assign signal_wire_2 = addr;
    assign signal_wire_3 = ren;
    assign signal_wire_4 = wen;
    assign signal_wire_5 = men;
    assign signal_wire_6 = clock;
    RM_IHPSG13_1P_512x16_c2_bm_bist
        sram
        ( .A_CLK(signal_wire_6),
          .A_MEN(signal_wire_5),
          .A_WEN(signal_wire_4),
          .A_REN(signal_wire_3),
          .A_ADDR(signal_wire_2),
          .A_DIN(signal_wire_1),
          .A_DLY(vdd),
          .A_BM(signal_wire),
          .A_BIST_CLK(gnd),
          .A_BIST_EN(gnd),
          .A_BIST_MEN(gnd),
          .A_BIST_WEN(gnd),
          .A_BIST_REN(gnd),
          .A_BIST_ADDR(signal_const_2),
          .A_BIST_DIN(signal_const),
          .A_BIST_BM(signal_const),
          .A_DOUT(signal_inst[15:0]) );
    assign signal_wire_7 = signal_inst;
    assign dout = signal_wire_7;

endmodule
module host_fifo (
    clock,
    clear,
    push$valid,
    push$value,
    pop,
    head,
    level,
    empty,
    full
);

    input clock;
    input clear;
    input push$valid;
    input [15:0] push$value;
    input pop;
    output [15:0] head;
    output [3:0] level;
    output empty;
    output full;

    wire signal_or;
    wire [15:0] signal_const;
    reg [15:0] data_before_collision;
    wire [15:0] signal_wire;
    (* RAM_STYLE="block" *)
    reg [15:0] signal_multiport_mem[0:7];
    wire [15:0] signal_mem_read_port;
    reg [15:0] ram_rbw_data;
    wire [2:0] signal_const_1;
    wire [2:0] signal_const_2;
    wire [2:0] READ_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [2:0] READ_ADDRESS;
    wire [2:0] signal_wire_1;
    wire signal_and;
    wire [2:0] RA;
    wire [2:0] WRITE_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [2:0] WRITE_ADDRESS;
    wire [2:0] signal_wire_2;
    wire signal_eq;
    wire signal_not;
    wire signal_and_1;
    wire signal_xor;
    wire signal_const_5;
    wire [3:0] signal_const_6;
    wire signal_lt;
    reg used_gt_one;
    wire signal_or_1;
    wire signal_and_2;
    wire signal_and_3;
    reg collision;
    wire [15:0] memory;
    wire signal_xor_1;
    wire signal_eq_1;
    reg used_is_one;
    wire signal_and_4;
    wire signal_and_5;
    wire [3:0] signal_const_10;
    wire [3:0] signal_const_11;
    wire [3:0] signal_sub;
    reg [3:0] USED_MINUS_1 = 4'b1111;
    wire [3:0] signal_wire_3;
    wire [3:0] signal_add;
    reg [3:0] USED_PLUS_1 = 4'b0001;
    wire [3:0] signal_wire_4;
    wire [3:0] signal_mux;
    reg [3:0] USED;
    wire [3:0] signal_wire_5;
    wire [3:0] signal_const_17;
    wire signal_eq_2;
    reg full_0;
    wire signal_wire_6;
    wire signal_wire_7;
    wire signal_not_1;
    wire signal_not_2;
    wire signal_wire_8;
    wire signal_wire_9;
    wire [3:0] signal_const_19;
    wire signal_lt_1;
    wire signal_not_3;
    reg nearly_full;
    wire signal_and_6;
    wire full_1;
    wire signal_not_4;
    wire signal_wire_10;
    wire signal_and_7;
    wire WR_INT;
    wire signal_wire_11;
    wire signal_not_5;
    wire signal_wire_12;
    wire RD_INT;
    wire signal_xor_2;
    wire [3:0] USED_NEXT;
    wire signal_eq_3;
    wire signal_not_6;
    reg not_empty;
    wire signal_wire_13;
    wire signal_not_7;
    wire signal_and_8;
    wire bypass_cond;
    wire [15:0] signal_mux_1;
    reg [15:0] signal_reg;
    assign signal_or = bypass_cond | RD_INT;
    assign signal_const = 16'b0000000000000000;
    always @(posedge signal_wire_9) begin
        data_before_collision <= signal_wire;
    end
    assign signal_wire = push$value;
    always @(posedge signal_wire_9) begin
        if (signal_and_2)
            signal_multiport_mem[signal_wire_2] <= signal_wire;
    end
    assign signal_mem_read_port = signal_multiport_mem[RA];
    always @(posedge signal_wire_9) begin
        ram_rbw_data <= signal_mem_read_port;
    end
    assign signal_const_1 = 3'b000;
    assign signal_const_2 = 3'b001;
    assign READ_ADDRESS_NEXT = signal_wire_1 + signal_const_2;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            READ_ADDRESS <= signal_const_1;
        else
            if (signal_and)
                READ_ADDRESS <= READ_ADDRESS_NEXT;
    end
    assign signal_wire_1 = READ_ADDRESS;
    assign signal_and = RD_INT & used_gt_one;
    assign RA = signal_and ? READ_ADDRESS_NEXT : signal_wire_1;
    assign WRITE_ADDRESS_NEXT = signal_wire_2 + signal_const_2;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            WRITE_ADDRESS <= signal_const_1;
        else
            if (signal_and_2)
                WRITE_ADDRESS <= WRITE_ADDRESS_NEXT;
    end
    assign signal_wire_2 = WRITE_ADDRESS;
    assign signal_eq = signal_wire_2 == RA;
    assign signal_not = ~ RD_INT;
    assign signal_and_1 = used_is_one & signal_not;
    assign signal_xor = RD_INT ^ WR_INT;
    assign signal_const_5 = 1'b0;
    assign signal_const_6 = 4'b0001;
    assign signal_lt = signal_const_6 < USED_NEXT;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            used_gt_one <= signal_const_5;
        else
            if (signal_xor)
                used_gt_one <= signal_lt;
    end
    assign signal_or_1 = used_gt_one | signal_and_1;
    assign signal_and_2 = WR_INT & signal_or_1;
    assign signal_and_3 = signal_and_2 & signal_eq;
    always @(posedge signal_wire_9) begin
        collision <= signal_and_3;
    end
    assign memory = collision ? data_before_collision : ram_rbw_data;
    assign signal_xor_1 = RD_INT ^ WR_INT;
    assign signal_eq_1 = USED_NEXT == signal_const_6;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            used_is_one <= signal_const_5;
        else
            if (signal_xor_1)
                used_is_one <= signal_eq_1;
    end
    assign signal_and_4 = used_is_one & WR_INT;
    assign signal_and_5 = signal_and_4 & RD_INT;
    assign signal_const_10 = 4'b0000;
    assign signal_const_11 = 4'b1111;
    assign signal_sub = USED_NEXT - signal_const_6;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            USED_MINUS_1 <= signal_const_11;
        else
            if (signal_xor_2)
                USED_MINUS_1 <= signal_sub;
    end
    assign signal_wire_3 = USED_MINUS_1;
    assign signal_add = USED_NEXT + signal_const_6;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            USED_PLUS_1 <= signal_const_6;
        else
            if (signal_xor_2)
                USED_PLUS_1 <= signal_add;
    end
    assign signal_wire_4 = USED_PLUS_1;
    assign signal_mux = RD_INT ? signal_wire_3 : signal_wire_4;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            USED <= signal_const_10;
        else
            if (signal_xor_2)
                USED <= USED_NEXT;
    end
    assign signal_wire_5 = USED;
    assign signal_const_17 = 4'b1001;
    assign signal_eq_2 = USED_NEXT == signal_const_17;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            full_0 <= signal_const_5;
        else
            if (signal_xor_2)
                full_0 <= signal_eq_2;
    end
    assign signal_wire_6 = full_0;
    assign signal_wire_7 = signal_wire_6;
    assign signal_not_1 = ~ signal_wire_7;
    assign signal_not_2 = ~ signal_wire_12;
    assign signal_wire_8 = clear;
    assign signal_wire_9 = clock;
    assign signal_const_19 = 4'b1000;
    assign signal_lt_1 = USED_NEXT < signal_const_19;
    assign signal_not_3 = ~ signal_lt_1;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            nearly_full <= signal_const_5;
        else
            if (signal_xor_2)
                nearly_full <= signal_not_3;
    end
    assign signal_and_6 = nearly_full & signal_not_2;
    assign full_1 = signal_and_6;
    assign signal_not_4 = ~ full_1;
    assign signal_wire_10 = push$valid;
    assign signal_and_7 = signal_wire_10 & signal_not_4;
    assign WR_INT = signal_and_7 & signal_not_1;
    assign signal_wire_11 = signal_not_7;
    assign signal_not_5 = ~ signal_wire_11;
    assign signal_wire_12 = pop;
    assign RD_INT = signal_wire_12 & signal_not_5;
    assign signal_xor_2 = RD_INT ^ WR_INT;
    assign USED_NEXT = signal_xor_2 ? signal_mux : signal_wire_5;
    assign signal_eq_3 = USED_NEXT == signal_const_10;
    assign signal_not_6 = ~ signal_eq_3;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            not_empty <= signal_const_5;
        else
            if (signal_xor_2)
                not_empty <= signal_not_6;
    end
    assign signal_wire_13 = not_empty;
    assign signal_not_7 = ~ signal_wire_13;
    assign signal_and_8 = signal_not_7 & WR_INT;
    assign bypass_cond = signal_and_8 | signal_and_5;
    assign signal_mux_1 = bypass_cond ? signal_wire : memory;
    always @(posedge signal_wire_9) begin
        if (signal_wire_8)
            signal_reg <= signal_const;
        else
            if (signal_or)
                signal_reg <= signal_mux_1;
    end
    assign head = signal_reg;
    assign level = signal_wire_5;
    assign empty = signal_not_7;
    assign full = full_1;

endmodule
module engine (
    clock,
    clear,
    config$side_set_count,
    config$side_set_base,
    config$side_set_pindirs,
    config$in_base,
    config$in_count,
    config$out_base,
    config$out_count,
    config$set_base,
    config$set_count,
    config$jmp_pin,
    config$capture_pin,
    config$capture_rising,
    config$in_shift_right,
    config$out_shift_right,
    config$autopush,
    config$push_threshold,
    config$autopull,
    config$pull_threshold,
    config$crc_width,
    config$crc_poly,
    config$crc_init,
    config$crc_reflect,
    config$stuff_threshold,
    config$stuff_level,
    config$wrap_bottom,
    config$wrap_top,
    start,
    program_write$valid,
    program_write$addr,
    program_write$data,
    tx$valid,
    tx$value,
    rx_pop,
    clear_irq,
    stop,
    inputs,
    pin_out,
    pin_dir,
    pc,
    x,
    y,
    p,
    t,
    osr,
    osr_count,
    isr,
    isr_count,
    now,
    stall,
    halted,
    irq,
    fault$underflow,
    fault$overflow,
    fault$missed_deadline,
    fault$decode,
    capture,
    capture_armed,
    tx_level,
    rx_level,
    rx_head,
    instruction,
    decode_ok,
    opcode_onehot,
    crc,
    stuff_run
);

    input clock;
    input clear;
    input [1:0] config$side_set_count;
    input [4:0] config$side_set_base;
    input config$side_set_pindirs;
    input [4:0] config$in_base;
    input [4:0] config$in_count;
    input [4:0] config$out_base;
    input [4:0] config$out_count;
    input [4:0] config$set_base;
    input [2:0] config$set_count;
    input [4:0] config$jmp_pin;
    input [4:0] config$capture_pin;
    input config$capture_rising;
    input config$in_shift_right;
    input config$out_shift_right;
    input config$autopush;
    input [4:0] config$push_threshold;
    input config$autopull;
    input [4:0] config$pull_threshold;
    input [4:0] config$crc_width;
    input [15:0] config$crc_poly;
    input [15:0] config$crc_init;
    input config$crc_reflect;
    input [4:0] config$stuff_threshold;
    input config$stuff_level;
    input [8:0] config$wrap_bottom;
    input [8:0] config$wrap_top;
    input start;
    input program_write$valid;
    input [8:0] program_write$addr;
    input [15:0] program_write$data;
    input tx$valid;
    input [15:0] tx$value;
    input rx_pop;
    input clear_irq;
    input stop;
    input [19:0] inputs;
    output [19:0] pin_out;
    output [19:0] pin_dir;
    output [8:0] pc;
    output [15:0] x;
    output [15:0] y;
    output [15:0] p;
    output [23:0] t;
    output [15:0] osr;
    output [4:0] osr_count;
    output [15:0] isr;
    output [4:0] isr_count;
    output [23:0] now;
    output [4:0] stall;
    output halted;
    output irq;
    output fault$underflow;
    output fault$overflow;
    output fault$missed_deadline;
    output fault$decode;
    output [23:0] capture;
    output capture_armed;
    output [3:0] tx_level;
    output [3:0] rx_level;
    output [15:0] rx_head;
    output [15:0] instruction;
    output decode_ok;
    output [7:0] opcode_onehot;
    output [15:0] crc;
    output [4:0] stuff_run;

    wire [2:0] signal_const;
    wire signal_eq;
    reg is_opcode$4;
    wire [2:0] signal_const_1;
    wire signal_eq_1;
    reg is_opcode$5;
    wire [2:0] signal_const_2;
    wire signal_eq_2;
    reg is_opcode$6;
    wire [7:0] signal_cat;
    wire [15:0] signal_select;
    wire [3:0] signal_select_1;
    wire [3:0] signal_select_2;
    wire signal_not;
    wire signal_and;
    wire signal_const_3;
    reg signal_reg;
    wire [23:0] signal_const_4;
    wire [23:0] signal_sub;
    wire signal_eq_3;
    wire signal_not_1;
    wire [23:0] signal_sub_1;
    wire signal_select_3;
    wire signal_not_2;
    wire deadline_late;
    wire signal_and_1;
    wire signal_and_2;
    reg signal_reg_1;
    wire signal_and_3;
    wire signal_and_4;
    reg signal_reg_2;
    wire signal_and_5;
    wire signal_and_6;
    wire signal_and_7;
    wire signal_or;
    wire signal_and_8;
    reg signal_reg_3;
    wire signal_wire;
    wire signal_mux;
    wire [2:0] signal_const_9;
    wire signal_eq_4;
    wire signal_and_9;
    wire signal_and_10;
    wire signal_mux_1;
    wire signal_wire_1;
    reg irq_0;
    wire [19:0] signal_const_10;
    wire [15:0] signal_select_4;
    wire [3:0] signal_select_5;
    wire [19:0] signal_cat_1;
    wire [7:0] signal_select_6;
    wire [11:0] signal_select_7;
    wire [19:0] signal_cat_2;
    wire [3:0] signal_select_8;
    wire [15:0] signal_select_9;
    wire [19:0] signal_cat_3;
    wire [1:0] signal_select_10;
    wire [17:0] signal_select_11;
    wire [19:0] signal_cat_4;
    wire signal_select_12;
    wire [18:0] signal_select_13;
    wire [19:0] signal_cat_5;
    wire [10:0] signal_const_11;
    wire [15:0] signal_cat_6;
    wire [3:0] signal_const_12;
    wire [19:0] signal_cat_7;
    wire signal_select_14;
    wire [19:0] signal_mux_2;
    wire signal_select_15;
    wire [19:0] signal_mux_3;
    wire signal_select_16;
    wire [19:0] signal_mux_4;
    wire signal_select_17;
    wire [19:0] signal_mux_5;
    wire signal_select_18;
    wire [19:0] signal_mux_6;
    wire [19:0] signal_and_11;
    wire [19:0] signal_const_13;
    wire [15:0] signal_select_19;
    wire [3:0] signal_select_20;
    wire [19:0] signal_cat_8;
    wire [7:0] signal_select_21;
    wire [11:0] signal_select_22;
    wire [19:0] signal_cat_9;
    wire [3:0] signal_select_23;
    wire [15:0] signal_select_24;
    wire [19:0] signal_cat_10;
    wire [1:0] signal_select_25;
    wire [17:0] signal_select_26;
    wire [19:0] signal_cat_11;
    wire signal_select_27;
    wire [18:0] signal_select_28;
    wire [19:0] signal_cat_12;
    wire [15:0] signal_const_14;
    wire [7:0] signal_const_15;
    wire [7:0] signal_select_29;
    wire [15:0] signal_cat_13;
    wire [11:0] signal_select_30;
    wire [15:0] signal_cat_14;
    wire [1:0] signal_const_17;
    wire [13:0] signal_select_31;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_const_18;
    wire [15:0] signal_const_19;
    wire signal_select_32;
    wire [15:0] signal_mux_7;
    wire signal_select_33;
    wire [15:0] signal_mux_8;
    wire signal_select_34;
    wire [15:0] signal_mux_9;
    wire signal_select_35;
    wire [15:0] signal_mux_10;
    wire signal_select_36;
    wire [15:0] signal_mux_11;
    wire [15:0] signal_not_3;
    wire [19:0] signal_cat_16;
    wire signal_select_37;
    wire [19:0] signal_mux_12;
    wire signal_select_38;
    wire [19:0] signal_mux_13;
    wire signal_select_39;
    wire [19:0] signal_mux_14;
    wire signal_select_40;
    wire [19:0] signal_mux_15;
    wire signal_select_41;
    wire [19:0] signal_mux_16;
    wire [19:0] signal_and_12;
    wire [19:0] signal_not_4;
    wire [19:0] signal_and_13;
    wire [19:0] signal_or_1;
    wire [2:0] signal_const_21;
    wire signal_eq_5;
    wire [19:0] signal_mux_17;
    wire [15:0] signal_select_42;
    wire [3:0] signal_select_43;
    wire [19:0] signal_cat_17;
    wire [7:0] signal_select_44;
    wire [11:0] signal_select_45;
    wire [19:0] signal_cat_18;
    wire [3:0] signal_select_46;
    wire [15:0] signal_select_47;
    wire [19:0] signal_cat_19;
    wire [1:0] signal_select_48;
    wire [17:0] signal_select_49;
    wire [19:0] signal_cat_20;
    wire signal_select_50;
    wire [18:0] signal_select_51;
    wire [19:0] signal_cat_21;
    wire [19:0] signal_cat_22;
    wire signal_select_52;
    wire [19:0] signal_mux_18;
    wire signal_select_53;
    wire [19:0] signal_mux_19;
    wire signal_select_54;
    wire [19:0] signal_mux_20;
    wire signal_select_55;
    wire [19:0] signal_mux_21;
    wire signal_select_56;
    wire [19:0] signal_mux_22;
    wire [19:0] signal_and_14;
    wire [15:0] signal_select_57;
    wire [3:0] signal_select_58;
    wire [19:0] signal_cat_23;
    wire [7:0] signal_select_59;
    wire [11:0] signal_select_60;
    wire [19:0] signal_cat_24;
    wire [3:0] signal_select_61;
    wire [15:0] signal_select_62;
    wire [19:0] signal_cat_25;
    wire [1:0] signal_select_63;
    wire [17:0] signal_select_64;
    wire [19:0] signal_cat_26;
    wire signal_select_65;
    wire [18:0] signal_select_66;
    wire [19:0] signal_cat_27;
    wire [7:0] signal_select_67;
    wire [15:0] signal_cat_28;
    wire [11:0] signal_select_68;
    wire [15:0] signal_cat_29;
    wire [13:0] signal_select_69;
    wire [15:0] signal_cat_30;
    wire signal_select_70;
    wire [15:0] signal_mux_23;
    wire signal_select_71;
    wire [15:0] signal_mux_24;
    wire signal_select_72;
    wire [15:0] signal_mux_25;
    wire signal_select_73;
    wire [15:0] signal_mux_26;
    wire signal_select_74;
    wire [15:0] signal_mux_27;
    wire [15:0] signal_not_5;
    wire [19:0] signal_cat_31;
    wire signal_select_75;
    wire [19:0] signal_mux_28;
    wire signal_select_76;
    wire [19:0] signal_mux_29;
    wire signal_select_77;
    wire [19:0] signal_mux_30;
    wire signal_select_78;
    wire [19:0] signal_mux_31;
    wire signal_select_79;
    wire [19:0] signal_mux_32;
    wire [19:0] signal_and_15;
    wire [19:0] signal_not_6;
    wire [19:0] signal_and_16;
    wire [19:0] signal_or_2;
    wire signal_eq_6;
    wire [19:0] signal_mux_33;
    wire [15:0] signal_select_80;
    wire [3:0] signal_select_81;
    wire [19:0] signal_cat_32;
    wire [7:0] signal_select_82;
    wire [11:0] signal_select_83;
    wire [19:0] signal_cat_33;
    wire [3:0] signal_select_84;
    wire [15:0] signal_select_85;
    wire [19:0] signal_cat_34;
    wire [1:0] signal_select_86;
    wire [17:0] signal_select_87;
    wire [19:0] signal_cat_35;
    wire signal_select_88;
    wire [18:0] signal_select_89;
    wire [19:0] signal_cat_36;
    wire [19:0] signal_cat_37;
    wire signal_select_90;
    wire [19:0] signal_mux_34;
    wire signal_select_91;
    wire [19:0] signal_mux_35;
    wire signal_select_92;
    wire [19:0] signal_mux_36;
    wire signal_select_93;
    wire [19:0] signal_mux_37;
    wire signal_select_94;
    wire [19:0] signal_mux_38;
    wire [19:0] signal_and_17;
    wire [15:0] signal_select_95;
    wire [3:0] signal_select_96;
    wire [19:0] signal_cat_38;
    wire [7:0] signal_select_97;
    wire [11:0] signal_select_98;
    wire [19:0] signal_cat_39;
    wire [3:0] signal_select_99;
    wire [15:0] signal_select_100;
    wire [19:0] signal_cat_40;
    wire [1:0] signal_select_101;
    wire [17:0] signal_select_102;
    wire [19:0] signal_cat_41;
    wire signal_select_103;
    wire [18:0] signal_select_104;
    wire [19:0] signal_cat_42;
    wire [7:0] signal_select_105;
    wire [15:0] signal_cat_43;
    wire [11:0] signal_select_106;
    wire [15:0] signal_cat_44;
    wire [13:0] signal_select_107;
    wire [15:0] signal_cat_45;
    wire signal_select_108;
    wire [15:0] signal_mux_39;
    wire signal_select_109;
    wire [15:0] signal_mux_40;
    wire signal_select_110;
    wire [15:0] signal_mux_41;
    wire signal_select_111;
    wire [15:0] signal_mux_42;
    wire signal_select_112;
    wire [15:0] signal_mux_43;
    wire [15:0] signal_not_7;
    wire [19:0] signal_cat_46;
    wire signal_select_113;
    wire [19:0] signal_mux_44;
    wire signal_select_114;
    wire [19:0] signal_mux_45;
    wire signal_select_115;
    wire [19:0] signal_mux_46;
    wire signal_select_116;
    wire [19:0] signal_mux_47;
    wire signal_select_117;
    wire [19:0] signal_mux_48;
    wire [19:0] signal_and_18;
    wire [19:0] signal_not_8;
    wire [19:0] signal_and_19;
    wire [19:0] signal_or_3;
    wire signal_eq_7;
    wire [19:0] signal_mux_49;
    wire [15:0] signal_select_118;
    wire [3:0] signal_select_119;
    wire [19:0] signal_cat_47;
    wire [7:0] signal_select_120;
    wire [11:0] signal_select_121;
    wire [19:0] signal_cat_48;
    wire [3:0] signal_select_122;
    wire [15:0] signal_select_123;
    wire [19:0] signal_cat_49;
    wire [1:0] signal_select_124;
    wire [17:0] signal_select_125;
    wire [19:0] signal_cat_50;
    wire signal_select_126;
    wire [18:0] signal_select_127;
    wire [19:0] signal_cat_51;
    wire [13:0] signal_const_42;
    wire [15:0] signal_cat_52;
    wire [19:0] signal_cat_53;
    wire signal_select_128;
    wire [19:0] signal_mux_50;
    wire signal_select_129;
    wire [19:0] signal_mux_51;
    wire signal_select_130;
    wire [19:0] signal_mux_52;
    wire signal_select_131;
    wire [19:0] signal_mux_53;
    wire signal_select_132;
    wire [19:0] signal_mux_54;
    wire [19:0] signal_and_20;
    wire [15:0] signal_select_133;
    wire [3:0] signal_select_134;
    wire [19:0] signal_cat_54;
    wire [7:0] signal_select_135;
    wire [11:0] signal_select_136;
    wire [19:0] signal_cat_55;
    wire [3:0] signal_select_137;
    wire [15:0] signal_select_138;
    wire [19:0] signal_cat_56;
    wire [1:0] signal_select_139;
    wire [17:0] signal_select_140;
    wire [19:0] signal_cat_57;
    wire signal_select_141;
    wire [18:0] signal_select_142;
    wire [19:0] signal_cat_58;
    wire [7:0] signal_select_143;
    wire [15:0] signal_cat_59;
    wire [11:0] signal_select_144;
    wire [15:0] signal_cat_60;
    wire [13:0] signal_select_145;
    wire [15:0] signal_cat_61;
    wire signal_select_146;
    wire [15:0] signal_mux_55;
    wire signal_select_147;
    wire [15:0] signal_mux_56;
    wire signal_select_148;
    wire [15:0] signal_mux_57;
    wire signal_select_149;
    wire [15:0] signal_mux_58;
    wire signal_select_150;
    wire [15:0] signal_mux_59;
    wire [15:0] signal_not_9;
    wire [19:0] signal_cat_62;
    wire signal_select_151;
    wire [19:0] signal_mux_60;
    wire signal_select_152;
    wire [19:0] signal_mux_61;
    wire signal_select_153;
    wire [19:0] signal_mux_62;
    wire signal_select_154;
    wire [19:0] signal_mux_63;
    wire signal_select_155;
    wire [19:0] signal_mux_64;
    wire [19:0] signal_and_21;
    wire [19:0] signal_not_10;
    wire [19:0] signal_and_22;
    wire [19:0] pin_out_side;
    wire [19:0] pin_out_base;
    wire [15:0] signal_wire_2;
    wire [8:0] signal_wire_3;
    wire [8:0] signal_const_54;
    wire [8:0] signal_const_55;
    wire signal_eq_8;
    wire [8:0] signal_mux_65;
    wire [8:0] signal_add;
    wire signal_eq_9;
    wire [8:0] signal_mux_66;
    wire [8:0] signal_wire_4;
    wire [8:0] signal_add_1;
    wire [8:0] signal_wire_5;
    wire [8:0] d$jmp_target;
    wire signal_not_11;
    wire signal_not_12;
    wire [4:0] signal_const_61;
    wire [4:0] signal_const_64;
    wire [4:0] signal_add_2;
    wire [4:0] stuff_run_max;
    wire signal_eq_10;
    wire [4:0] signal_mux_67;
    wire signal_wire_6;
    wire signal_eq_11;
    wire [4:0] signal_mux_68;
    wire [4:0] signal_mux_69;
    wire signal_eq_12;
    wire signal_and_23;
    wire [4:0] stuff_run_next;
    wire [4:0] signal_mux_70;
    wire [4:0] signal_mux_71;
    reg [4:0] signal_reg_4;
    wire [4:0] stuff_run_0;
    wire signal_lt;
    wire signal_not_13;
    wire [4:0] signal_wire_7;
    wire signal_eq_13;
    wire signal_not_14;
    wire signal_and_24;
    wire signal_lt_1;
    wire signal_select_156;
    wire signal_select_157;
    wire signal_select_158;
    wire signal_select_159;
    wire signal_select_160;
    wire signal_select_161;
    wire signal_select_162;
    wire signal_select_163;
    wire signal_select_164;
    wire signal_select_165;
    wire signal_select_166;
    wire signal_select_167;
    wire signal_select_168;
    wire signal_select_169;
    wire signal_select_170;
    wire signal_select_171;
    wire signal_select_172;
    wire signal_select_173;
    wire signal_select_174;
    wire signal_select_175;
    reg signal_mux_72;
    wire signal_not_15;
    wire signal_select_176;
    wire signal_select_177;
    wire signal_select_178;
    wire signal_select_179;
    wire signal_select_180;
    wire signal_select_181;
    wire signal_select_182;
    wire signal_select_183;
    wire signal_select_184;
    wire signal_select_185;
    wire signal_select_186;
    wire signal_select_187;
    wire signal_select_188;
    wire signal_select_189;
    wire signal_select_190;
    wire signal_select_191;
    wire signal_select_192;
    wire signal_select_193;
    wire signal_select_194;
    wire signal_select_195;
    wire [4:0] signal_wire_8;
    reg signal_mux_73;
    wire signal_eq_14;
    wire signal_not_16;
    wire signal_eq_15;
    wire signal_not_17;
    wire signal_eq_16;
    wire signal_not_18;
    reg jmp_taken;
    wire [8:0] jmp_target_or_next;
    wire [8:0] signal_mux_74;
    wire [8:0] signal_mux_75;
    wire [8:0] pc_value_next;
    reg [8:0] signal_reg_5;
    wire [8:0] pc_0;
    wire signal_eq_17;
    wire [8:0] pc_next;
    wire [8:0] signal_mux_76;
    wire [8:0] pc_after_next;
    wire [8:0] signal_mux_77;
    wire [8:0] signal_mux_78;
    wire [8:0] fetch_addr;
    wire [8:0] signal_mux_79;
    wire [2:0] signal_const_70;
    wire signal_eq_18;
    wire signal_and_25;
    wire signal_and_26;
    wire signal_mux_80;
    wire signal_not_19;
    wire signal_not_20;
    wire [4:0] signal_const_75;
    wire [4:0] signal_and_27;
    wire [4:0] signal_and_28;
    wire [4:0] signal_const_77;
    wire [4:0] signal_and_29;
    reg [4:0] d$delay;
    wire [4:0] signal_sub_2;
    wire signal_eq_19;
    wire signal_not_21;
    wire [4:0] signal_mux_81;
    wire [4:0] signal_mux_82;
    wire signal_or_4;
    reg refill;
    wire signal_not_22;
    wire signal_wire_9;
    wire [15:0] signal_mux_83;
    wire [15:0] signal_wire_10;
    wire signal_not_23;
    wire [2:0] signal_const_81;
    wire signal_eq_20;
    wire signal_and_30;
    wire signal_and_31;
    wire pushes;
    wire signal_and_32;
    wire signal_and_33;
    wire signal_wire_11;
    wire [21:0] signal_inst;
    wire signal_select_196;
    wire signal_not_24;
    wire signal_mux_84;
    wire [23:0] signal_xor;
    wire [23:0] signal_sub_3;
    wire [23:0] signal_cat_63;
    wire [23:0] signal_add_3;
    reg [23:0] signal_mux_85;
    wire [1:0] signal_const_84;
    wire signal_eq_21;
    wire [23:0] signal_mux_86;
    wire signal_select_197;
    wire signal_select_198;
    wire signal_select_199;
    wire signal_select_200;
    wire signal_select_201;
    wire signal_select_202;
    wire signal_select_203;
    wire signal_select_204;
    wire signal_select_205;
    wire signal_select_206;
    wire signal_select_207;
    wire signal_select_208;
    wire signal_select_209;
    wire signal_select_210;
    wire signal_select_211;
    wire signal_select_212;
    wire signal_select_213;
    wire signal_select_214;
    wire signal_select_215;
    wire signal_select_216;
    wire signal_select_217;
    wire signal_select_218;
    wire signal_select_219;
    wire signal_select_220;
    wire [23:0] signal_cat_64;
    wire [23:0] signal_not_25;
    reg [23:0] mov_value_t;
    wire [2:0] signal_const_85;
    wire signal_eq_22;
    wire [23:0] signal_mux_87;
    wire [23:0] signal_cat_65;
    wire signal_eq_23;
    wire [23:0] signal_mux_88;
    wire [23:0] signal_cat_66;
    wire [23:0] signal_add_4;
    wire [1:0] signal_const_89;
    wire signal_eq_24;
    wire signal_and_34;
    wire releases_deadline;
    wire signal_and_35;
    wire [23:0] signal_mux_89;
    reg [23:0] t_next;
    reg [23:0] signal_reg_6;
    wire [23:0] t_0;
    wire [23:0] signal_sub_4;
    wire signal_select_221;
    wire deadline_ready;
    wire signal_eq_25;
    wire signal_select_222;
    wire signal_select_223;
    wire signal_select_224;
    wire signal_select_225;
    wire signal_select_226;
    wire signal_select_227;
    wire signal_select_228;
    wire signal_select_229;
    wire signal_select_230;
    wire signal_select_231;
    wire signal_select_232;
    wire signal_select_233;
    wire signal_select_234;
    wire signal_select_235;
    wire signal_select_236;
    wire signal_select_237;
    wire signal_select_238;
    wire signal_select_239;
    wire signal_select_240;
    wire signal_select_241;
    reg wait_pin_prev;
    wire signal_eq_26;
    wire signal_not_26;
    wire signal_and_36;
    wire d$wait_polarity;
    wire signal_select_242;
    wire signal_select_243;
    wire signal_select_244;
    wire signal_select_245;
    wire signal_select_246;
    wire signal_select_247;
    wire signal_select_248;
    wire signal_select_249;
    wire signal_select_250;
    wire signal_select_251;
    wire signal_select_252;
    wire signal_select_253;
    wire signal_select_254;
    wire signal_select_255;
    wire signal_select_256;
    wire signal_select_257;
    wire signal_select_258;
    wire signal_select_259;
    wire signal_select_260;
    wire signal_select_261;
    wire signal_select_262;
    wire signal_select_263;
    wire signal_select_264;
    wire signal_select_265;
    wire signal_select_266;
    wire signal_select_267;
    wire signal_select_268;
    wire signal_select_269;
    wire signal_select_270;
    wire signal_select_271;
    wire signal_select_272;
    wire signal_select_273;
    wire signal_select_274;
    wire signal_select_275;
    wire signal_mux_90;
    wire signal_select_276;
    wire signal_select_277;
    wire signal_select_278;
    wire signal_mux_91;
    wire signal_select_279;
    wire signal_select_280;
    wire signal_select_281;
    wire signal_mux_92;
    wire signal_select_282;
    wire signal_select_283;
    wire signal_select_284;
    wire signal_mux_93;
    wire signal_select_285;
    wire signal_select_286;
    wire signal_select_287;
    wire signal_mux_94;
    wire signal_select_288;
    wire signal_select_289;
    wire signal_select_290;
    wire signal_mux_95;
    wire signal_select_291;
    wire signal_select_292;
    wire signal_select_293;
    wire signal_mux_96;
    wire signal_select_294;
    wire [19:0] signal_wire_12;
    wire signal_select_295;
    wire [15:0] signal_select_296;
    wire [3:0] signal_select_297;
    wire [19:0] signal_cat_67;
    wire [7:0] signal_select_298;
    wire [11:0] signal_select_299;
    wire [19:0] signal_cat_68;
    wire [3:0] signal_select_300;
    wire [15:0] signal_select_301;
    wire [19:0] signal_cat_69;
    wire [1:0] signal_select_302;
    wire [17:0] signal_select_303;
    wire [19:0] signal_cat_70;
    wire signal_select_304;
    wire [18:0] signal_select_305;
    wire [19:0] signal_cat_71;
    wire [15:0] signal_cat_72;
    wire [19:0] signal_cat_73;
    wire signal_select_306;
    wire [19:0] signal_mux_97;
    wire signal_select_307;
    wire [19:0] signal_mux_98;
    wire signal_select_308;
    wire [19:0] signal_mux_99;
    wire signal_select_309;
    wire [19:0] signal_mux_100;
    wire signal_select_310;
    wire [19:0] signal_mux_101;
    wire [19:0] signal_and_37;
    wire [19:0] signal_const_93;
    wire [15:0] signal_select_311;
    wire [3:0] signal_select_312;
    wire [19:0] signal_cat_74;
    wire [7:0] signal_select_313;
    wire [11:0] signal_select_314;
    wire [19:0] signal_cat_75;
    wire [3:0] signal_select_315;
    wire [15:0] signal_select_316;
    wire [19:0] signal_cat_76;
    wire [1:0] signal_select_317;
    wire [17:0] signal_select_318;
    wire [19:0] signal_cat_77;
    wire signal_select_319;
    wire [18:0] signal_select_320;
    wire [19:0] signal_cat_78;
    wire [7:0] signal_select_321;
    wire [15:0] signal_cat_79;
    wire [11:0] signal_select_322;
    wire [15:0] signal_cat_80;
    wire [13:0] signal_select_323;
    wire [15:0] signal_cat_81;
    wire signal_select_324;
    wire [15:0] signal_mux_102;
    wire signal_select_325;
    wire [15:0] signal_mux_103;
    wire signal_select_326;
    wire [15:0] signal_mux_104;
    wire signal_select_327;
    wire [15:0] signal_mux_105;
    wire [2:0] signal_wire_13;
    wire [4:0] signal_cat_82;
    wire signal_select_328;
    wire [15:0] signal_mux_106;
    wire [15:0] signal_not_27;
    wire [19:0] signal_cat_83;
    wire signal_select_329;
    wire [19:0] signal_mux_107;
    wire signal_select_330;
    wire [19:0] signal_mux_108;
    wire signal_select_331;
    wire [19:0] signal_mux_109;
    wire signal_select_332;
    wire [19:0] signal_mux_110;
    wire [4:0] signal_wire_14;
    wire signal_select_333;
    wire [19:0] signal_mux_111;
    wire [19:0] signal_and_38;
    wire [19:0] signal_not_28;
    wire [19:0] signal_and_39;
    wire [19:0] signal_or_5;
    wire signal_eq_27;
    wire [19:0] signal_mux_112;
    wire [15:0] signal_select_334;
    wire [3:0] signal_select_335;
    wire [19:0] signal_cat_84;
    wire [7:0] signal_select_336;
    wire [11:0] signal_select_337;
    wire [19:0] signal_cat_85;
    wire [3:0] signal_select_338;
    wire [15:0] signal_select_339;
    wire [19:0] signal_cat_86;
    wire [1:0] signal_select_340;
    wire [17:0] signal_select_341;
    wire [19:0] signal_cat_87;
    wire signal_select_342;
    wire [18:0] signal_select_343;
    wire [19:0] signal_cat_88;
    wire [19:0] signal_cat_89;
    wire signal_select_344;
    wire [19:0] signal_mux_113;
    wire signal_select_345;
    wire [19:0] signal_mux_114;
    wire signal_select_346;
    wire [19:0] signal_mux_115;
    wire signal_select_347;
    wire [19:0] signal_mux_116;
    wire signal_select_348;
    wire [19:0] signal_mux_117;
    wire [19:0] signal_and_40;
    wire [15:0] signal_select_349;
    wire [3:0] signal_select_350;
    wire [19:0] signal_cat_90;
    wire [7:0] signal_select_351;
    wire [11:0] signal_select_352;
    wire [19:0] signal_cat_91;
    wire [3:0] signal_select_353;
    wire [15:0] signal_select_354;
    wire [19:0] signal_cat_92;
    wire [1:0] signal_select_355;
    wire [17:0] signal_select_356;
    wire [19:0] signal_cat_93;
    wire signal_select_357;
    wire [18:0] signal_select_358;
    wire [19:0] signal_cat_94;
    wire [7:0] signal_select_359;
    wire [15:0] signal_cat_95;
    wire [11:0] signal_select_360;
    wire [15:0] signal_cat_96;
    wire [13:0] signal_select_361;
    wire [15:0] signal_cat_97;
    wire signal_select_362;
    wire [15:0] signal_mux_118;
    wire signal_select_363;
    wire [15:0] signal_mux_119;
    wire signal_select_364;
    wire [15:0] signal_mux_120;
    wire signal_select_365;
    wire [15:0] signal_mux_121;
    wire [4:0] signal_wire_15;
    wire signal_select_366;
    wire [15:0] signal_mux_122;
    wire [15:0] signal_not_29;
    wire [19:0] signal_cat_98;
    wire signal_select_367;
    wire [19:0] signal_mux_123;
    wire signal_select_368;
    wire [19:0] signal_mux_124;
    wire signal_select_369;
    wire [19:0] signal_mux_125;
    wire signal_select_370;
    wire [19:0] signal_mux_126;
    wire signal_select_371;
    wire [19:0] signal_mux_127;
    wire [19:0] signal_and_41;
    wire [19:0] signal_not_30;
    wire [19:0] signal_and_42;
    wire [19:0] signal_or_6;
    wire signal_eq_28;
    wire [19:0] signal_mux_128;
    wire [15:0] signal_select_372;
    wire [3:0] signal_select_373;
    wire [19:0] signal_cat_99;
    wire [7:0] signal_select_374;
    wire [11:0] signal_select_375;
    wire [19:0] signal_cat_100;
    wire [3:0] signal_select_376;
    wire [15:0] signal_select_377;
    wire [19:0] signal_cat_101;
    wire [1:0] signal_select_378;
    wire [17:0] signal_select_379;
    wire [19:0] signal_cat_102;
    wire signal_select_380;
    wire [18:0] signal_select_381;
    wire [19:0] signal_cat_103;
    wire [15:0] signal_and_43;
    wire [7:0] signal_select_382;
    wire [15:0] signal_cat_104;
    wire [11:0] signal_select_383;
    wire [15:0] signal_cat_105;
    wire [13:0] signal_select_384;
    wire [15:0] signal_cat_106;
    wire [14:0] signal_select_385;
    wire [15:0] signal_cat_107;
    wire [15:0] signal_select_386;
    wire signal_not_31;
    wire signal_and_44;
    wire [15:0] signal_mux_129;
    wire signal_select_387;
    wire signal_select_388;
    wire signal_select_389;
    wire signal_select_390;
    wire signal_select_391;
    wire signal_select_392;
    wire signal_select_393;
    wire signal_select_394;
    wire signal_select_395;
    wire signal_select_396;
    wire signal_select_397;
    wire signal_select_398;
    wire signal_select_399;
    wire signal_select_400;
    wire signal_select_401;
    wire signal_select_402;
    wire [15:0] signal_cat_108;
    wire [15:0] signal_not_32;
    wire [23:0] signal_cat_109;
    wire [23:0] signal_cat_110;
    wire [23:0] signal_cat_111;
    wire [15:0] signal_xor_1;
    wire [15:0] signal_sub_5;
    wire signal_eq_29;
    wire signal_and_45;
    wire [15:0] signal_mux_130;
    wire signal_eq_30;
    wire [15:0] signal_mux_131;
    wire signal_eq_31;
    wire [15:0] signal_mux_132;
    wire [7:0] signal_select_403;
    wire [15:0] signal_cat_112;
    wire [11:0] signal_select_404;
    wire [15:0] signal_cat_113;
    wire [13:0] signal_select_405;
    wire [15:0] signal_cat_114;
    wire [14:0] signal_select_406;
    wire [15:0] signal_cat_115;
    wire signal_select_407;
    wire [15:0] signal_mux_133;
    wire signal_select_408;
    wire [15:0] signal_mux_134;
    wire signal_select_409;
    wire [15:0] signal_mux_135;
    wire signal_select_410;
    wire [15:0] signal_mux_136;
    wire signal_select_411;
    wire [15:0] signal_mux_137;
    wire [7:0] signal_select_412;
    wire [15:0] signal_cat_116;
    wire [11:0] signal_select_413;
    wire [15:0] signal_cat_117;
    wire [13:0] signal_select_414;
    wire [15:0] signal_cat_118;
    wire [14:0] signal_select_415;
    wire [15:0] signal_cat_119;
    wire signal_select_416;
    wire [15:0] signal_mux_138;
    wire signal_select_417;
    wire [15:0] signal_mux_139;
    wire signal_select_418;
    wire [15:0] signal_mux_140;
    wire signal_select_419;
    wire [15:0] signal_mux_141;
    wire signal_select_420;
    wire [15:0] signal_mux_142;
    wire [15:0] signal_or_7;
    wire [7:0] signal_select_421;
    wire [15:0] signal_cat_120;
    wire [11:0] signal_select_422;
    wire [15:0] signal_cat_121;
    wire [13:0] signal_select_423;
    wire [15:0] signal_cat_122;
    wire signal_select_424;
    wire [15:0] signal_mux_143;
    wire signal_select_425;
    wire [15:0] signal_mux_144;
    wire signal_select_426;
    wire [15:0] signal_mux_145;
    wire signal_select_427;
    wire [15:0] signal_mux_146;
    wire signal_select_428;
    wire [15:0] signal_mux_147;
    wire [15:0] mask;
    wire signal_wire_16;
    wire signal_select_429;
    wire signal_select_430;
    wire signal_select_431;
    wire signal_select_432;
    wire signal_select_433;
    wire signal_select_434;
    wire signal_select_435;
    wire signal_select_436;
    wire signal_select_437;
    wire signal_select_438;
    wire signal_select_439;
    wire signal_select_440;
    wire signal_select_441;
    wire signal_select_442;
    wire signal_select_443;
    wire signal_select_444;
    wire signal_select_445;
    wire signal_select_446;
    wire signal_select_447;
    wire signal_select_448;
    reg signal_mux_148;
    wire signal_eq_32;
    wire signal_select_449;
    wire signal_select_450;
    wire signal_select_451;
    wire signal_select_452;
    wire signal_select_453;
    wire signal_select_454;
    wire signal_select_455;
    wire signal_select_456;
    wire signal_select_457;
    wire signal_select_458;
    wire signal_select_459;
    wire signal_select_460;
    wire signal_select_461;
    wire signal_select_462;
    wire signal_select_463;
    wire signal_select_464;
    wire signal_select_465;
    wire signal_select_466;
    wire signal_select_467;
    reg [19:0] signal_reg_7;
    wire [19:0] pins_sampled;
    wire signal_select_468;
    reg signal_mux_149;
    wire signal_select_469;
    wire signal_select_470;
    wire signal_select_471;
    wire signal_select_472;
    wire signal_select_473;
    wire signal_select_474;
    wire signal_select_475;
    wire signal_select_476;
    wire signal_select_477;
    wire signal_select_478;
    wire signal_select_479;
    wire signal_select_480;
    wire signal_select_481;
    wire signal_select_482;
    wire signal_select_483;
    wire signal_select_484;
    wire signal_select_485;
    wire signal_select_486;
    wire signal_select_487;
    wire signal_select_488;
    wire [4:0] signal_wire_17;
    reg signal_mux_150;
    wire signal_eq_33;
    wire signal_not_33;
    wire signal_eq_34;
    wire signal_and_46;
    wire signal_and_47;
    wire signal_mux_151;
    wire signal_mux_152;
    reg signal_reg_8;
    wire capture_armed_0;
    wire signal_and_48;
    wire captured;
    wire [23:0] signal_const_152;
    wire [23:0] signal_add_5;
    wire [23:0] signal_mux_153;
    reg [23:0] signal_reg_9;
    wire [23:0] now_0;
    reg [23:0] signal_reg_10;
    wire [23:0] capture_0;
    wire [15:0] signal_select_489;
    wire [15:0] signal_wire_18;
    wire [7:0] signal_select_490;
    wire [15:0] signal_cat_123;
    wire [11:0] signal_select_491;
    wire [15:0] signal_cat_124;
    wire [13:0] signal_select_492;
    wire [15:0] signal_cat_125;
    wire signal_select_493;
    wire [15:0] signal_mux_154;
    wire signal_select_494;
    wire [15:0] signal_mux_155;
    wire signal_select_495;
    wire [15:0] signal_mux_156;
    wire signal_select_496;
    wire [15:0] signal_mux_157;
    wire signal_select_497;
    wire [15:0] signal_mux_158;
    wire [15:0] signal_not_34;
    wire [15:0] signal_xor_2;
    wire [14:0] signal_select_498;
    wire [15:0] signal_cat_126;
    wire signal_select_499;
    wire signal_xor_3;
    wire [15:0] signal_mux_159;
    wire [15:0] signal_wire_19;
    wire [15:0] signal_xor_4;
    wire [14:0] signal_select_500;
    wire [15:0] signal_cat_127;
    wire signal_select_501;
    wire signal_select_502;
    wire crossing_bit;
    wire signal_select_503;
    wire signal_select_504;
    wire signal_select_505;
    wire signal_select_506;
    wire signal_select_507;
    wire signal_select_508;
    wire signal_select_509;
    wire signal_select_510;
    wire signal_select_511;
    wire signal_select_512;
    wire signal_select_513;
    wire signal_select_514;
    wire signal_select_515;
    wire signal_select_516;
    wire signal_select_517;
    wire signal_select_518;
    wire [4:0] signal_wire_20;
    wire [4:0] signal_sub_6;
    reg signal_mux_160;
    wire signal_xor_5;
    wire [15:0] signal_mux_161;
    wire signal_wire_21;
    wire [15:0] signal_mux_162;
    wire [15:0] crc_stepped;
    wire signal_eq_35;
    reg is_opcode$2;
    wire signal_or_8;
    wire signal_eq_36;
    wire bit_crosses;
    wire [15:0] signal_mux_163;
    wire signal_eq_37;
    wire signal_and_49;
    wire [15:0] crc_next;
    wire [15:0] signal_mux_164;
    wire [15:0] signal_mux_165;
    reg [15:0] signal_reg_11;
    wire [15:0] crc_0;
    wire [7:0] signal_select_519;
    wire [15:0] signal_cat_128;
    wire [11:0] signal_select_520;
    wire [15:0] signal_cat_129;
    wire [13:0] signal_select_521;
    wire [15:0] signal_cat_130;
    wire signal_select_522;
    wire [15:0] signal_mux_166;
    wire signal_select_523;
    wire [15:0] signal_mux_167;
    wire signal_select_524;
    wire [15:0] signal_mux_168;
    wire signal_select_525;
    wire [15:0] signal_mux_169;
    wire signal_select_526;
    wire [15:0] signal_mux_170;
    wire [15:0] signal_not_35;
    wire [3:0] signal_select_527;
    wire [15:0] signal_select_528;
    wire [19:0] signal_cat_131;
    wire [11:0] signal_select_529;
    wire [7:0] signal_select_530;
    wire [19:0] signal_cat_132;
    wire [15:0] signal_select_531;
    wire [3:0] signal_select_532;
    wire [19:0] signal_cat_133;
    wire [17:0] signal_select_533;
    wire [1:0] signal_select_534;
    wire [19:0] signal_cat_134;
    wire [18:0] signal_select_535;
    wire signal_select_536;
    wire [19:0] signal_cat_135;
    wire signal_select_537;
    wire [19:0] signal_mux_171;
    wire signal_select_538;
    wire [19:0] signal_mux_172;
    wire signal_select_539;
    wire [19:0] signal_mux_173;
    wire signal_select_540;
    wire [19:0] signal_mux_174;
    wire signal_select_541;
    wire [19:0] signal_mux_175;
    wire [15:0] signal_select_542;
    wire [15:0] signal_and_50;
    reg [15:0] signal_mux_176;
    wire [15:0] in_value;
    wire [7:0] signal_select_543;
    wire [15:0] signal_cat_136;
    wire [11:0] signal_select_544;
    wire [15:0] signal_cat_137;
    wire [13:0] signal_select_545;
    wire [15:0] signal_cat_138;
    wire [14:0] signal_select_546;
    wire [15:0] signal_cat_139;
    wire signal_select_547;
    wire [15:0] signal_mux_177;
    wire signal_select_548;
    wire [15:0] signal_mux_178;
    wire signal_select_549;
    wire [15:0] signal_mux_179;
    wire signal_select_550;
    wire [15:0] signal_mux_180;
    wire signal_select_551;
    wire [15:0] signal_mux_181;
    wire [15:0] signal_or_9;
    wire signal_wire_22;
    wire [15:0] isr_shifted;
    wire [4:0] signal_wire_23;
    wire [4:0] signal_const_178;
    wire [4:0] signal_select_552;
    wire [5:0] signal_cat_140;
    wire signal_eq_38;
    wire signal_and_51;
    wire [4:0] signal_mux_182;
    wire signal_eq_39;
    wire [4:0] signal_mux_183;
    wire signal_eq_40;
    wire [4:0] signal_mux_184;
    wire [4:0] signal_mux_185;
    reg [4:0] isr_count_next_value;
    reg [4:0] signal_reg_12;
    wire [4:0] isr_count_0;
    wire [5:0] signal_cat_141;
    wire [5:0] signal_add_6;
    wire [5:0] signal_const_183;
    wire signal_lt_2;
    wire [4:0] isr_count_next;
    wire signal_lt_3;
    wire signal_not_36;
    wire signal_wire_24;
    wire autopush_now;
    wire [15:0] signal_mux_186;
    reg [15:0] isr_next;
    reg [15:0] signal_reg_13;
    wire [15:0] isr_0;
    wire [15:0] signal_xor_6;
    wire [15:0] signal_sub_7;
    wire [15:0] signal_add_7;
    reg [15:0] signal_mux_187;
    wire signal_eq_41;
    wire [15:0] signal_mux_188;
    wire [15:0] signal_cat_142;
    wire signal_eq_42;
    wire [15:0] signal_mux_189;
    wire signal_eq_43;
    wire [15:0] signal_mux_190;
    wire signal_eq_44;
    wire [15:0] signal_mux_191;
    reg [15:0] p_next;
    reg [15:0] signal_reg_14;
    wire [15:0] p_0;
    wire [15:0] signal_xor_7;
    wire [15:0] signal_sub_8;
    wire [15:0] signal_add_8;
    reg [15:0] signal_mux_192;
    wire [1:0] signal_const_191;
    wire signal_eq_45;
    wire [15:0] signal_mux_193;
    wire [15:0] signal_cat_143;
    wire signal_eq_46;
    wire [15:0] signal_mux_194;
    wire signal_eq_47;
    wire [15:0] signal_mux_195;
    wire signal_eq_48;
    wire [15:0] signal_mux_196;
    wire [15:0] signal_const_196;
    wire [15:0] signal_sub_9;
    wire [3:0] signal_const_197;
    wire signal_eq_49;
    wire [15:0] signal_mux_197;
    reg [15:0] y_next;
    reg [15:0] signal_reg_15;
    wire [15:0] y_0;
    reg [15:0] signal_mux_198;
    wire [2:0] d$alu_reg$binary_variant;
    wire [2:0] d$alu_imm;
    wire [12:0] signal_const_198;
    wire [15:0] signal_cat_144;
    wire d$alu_is_reg;
    wire [15:0] alu_operand;
    wire [15:0] signal_add_9;
    wire [1:0] d$alu_op$binary_variant;
    reg [15:0] signal_mux_199;
    wire [1:0] d$alu_dest$binary_variant;
    wire signal_eq_50;
    wire [15:0] signal_mux_200;
    wire [4:0] d$set_value;
    wire [15:0] signal_cat_145;
    wire [2:0] d$set_dest$binary_variant;
    wire signal_eq_51;
    wire [15:0] signal_mux_201;
    wire signal_eq_52;
    wire [15:0] signal_mux_202;
    wire signal_eq_53;
    wire [15:0] signal_mux_203;
    wire [15:0] signal_sub_10;
    wire [3:0] signal_const_205;
    wire [3:0] d$jmp_cond$binary_variant;
    wire signal_eq_54;
    wire [15:0] signal_mux_204;
    reg [15:0] x_next;
    reg [15:0] signal_reg_16;
    wire [15:0] x_0;
    wire [23:0] signal_cat_146;
    wire [7:0] signal_select_553;
    wire [15:0] signal_cat_147;
    wire [11:0] signal_select_554;
    wire [15:0] signal_cat_148;
    wire [13:0] signal_select_555;
    wire [15:0] signal_cat_149;
    wire signal_select_556;
    wire [15:0] signal_mux_205;
    wire signal_select_557;
    wire [15:0] signal_mux_206;
    wire signal_select_558;
    wire [15:0] signal_mux_207;
    wire signal_select_559;
    wire [15:0] signal_mux_208;
    wire [4:0] signal_wire_25;
    wire signal_select_560;
    wire [15:0] signal_mux_209;
    wire [15:0] signal_not_37;
    wire [3:0] signal_select_561;
    wire [15:0] signal_select_562;
    wire [19:0] signal_cat_150;
    wire [11:0] signal_select_563;
    wire [7:0] signal_select_564;
    wire [19:0] signal_cat_151;
    wire [15:0] signal_select_565;
    wire [3:0] signal_select_566;
    wire [19:0] signal_cat_152;
    wire [17:0] signal_select_567;
    wire [1:0] signal_select_568;
    wire [19:0] signal_cat_153;
    wire [18:0] signal_select_569;
    wire signal_select_570;
    wire [19:0] signal_cat_154;
    wire signal_select_571;
    wire [19:0] signal_mux_210;
    wire signal_select_572;
    wire [19:0] signal_mux_211;
    wire signal_select_573;
    wire [19:0] signal_mux_212;
    wire signal_select_574;
    wire [19:0] signal_mux_213;
    wire [4:0] signal_wire_26;
    wire signal_select_575;
    wire [19:0] signal_mux_214;
    wire [15:0] signal_select_576;
    wire [15:0] signal_and_52;
    wire [23:0] signal_cat_155;
    wire [2:0] d$mov_source$binary_variant;
    reg [23:0] mov_value24;
    wire [15:0] signal_select_577;
    wire [1:0] d$mov_op$binary_variant;
    reg [15:0] mov_value;
    wire signal_eq_55;
    wire [15:0] signal_mux_215;
    wire [7:0] signal_select_578;
    wire [15:0] signal_cat_156;
    wire [11:0] signal_select_579;
    wire [15:0] signal_cat_157;
    wire [13:0] signal_select_580;
    wire [15:0] signal_cat_158;
    wire [14:0] signal_select_581;
    wire [15:0] signal_cat_159;
    wire signal_select_582;
    wire [15:0] signal_mux_216;
    wire signal_select_583;
    wire [15:0] signal_mux_217;
    wire signal_select_584;
    wire [15:0] signal_mux_218;
    wire signal_select_585;
    wire [15:0] signal_mux_219;
    wire signal_select_586;
    wire [15:0] signal_mux_220;
    wire [7:0] signal_select_587;
    wire [15:0] signal_cat_160;
    wire [11:0] signal_select_588;
    wire [15:0] signal_cat_161;
    wire [13:0] signal_select_589;
    wire [15:0] signal_cat_162;
    wire [14:0] signal_select_590;
    wire [15:0] signal_cat_163;
    wire signal_select_591;
    wire [15:0] signal_mux_221;
    wire signal_select_592;
    wire [15:0] signal_mux_222;
    wire signal_select_593;
    wire [15:0] signal_mux_223;
    wire signal_select_594;
    wire [15:0] signal_mux_224;
    wire signal_select_595;
    wire [15:0] signal_mux_225;
    wire [15:0] osr_shifted;
    reg [15:0] osr_next;
    reg [15:0] signal_reg_17;
    wire [15:0] osr_0;
    wire signal_not_38;
    wire signal_and_53;
    wire signal_eq_56;
    reg is_opcode$3;
    wire signal_and_54;
    wire signal_or_10;
    wire signal_and_55;
    wire tx_pop;
    wire [15:0] signal_wire_27;
    wire signal_wire_28;
    wire [21:0] signal_inst_1;
    wire signal_select_596;
    wire signal_not_39;
    wire [4:0] signal_wire_29;
    wire [2:0] d$sys_op$binary_variant;
    wire signal_eq_57;
    wire signal_eq_58;
    reg is_opcode$7;
    wire pulls;
    wire [4:0] signal_mux_226;
    wire [4:0] osr_count_zero;
    wire [2:0] d$mov_dest$binary_variant;
    wire signal_eq_59;
    wire [4:0] signal_mux_227;
    wire [4:0] signal_select_597;
    wire [5:0] signal_cat_164;
    wire [4:0] osr_count_before;
    wire [5:0] signal_cat_165;
    wire [5:0] signal_add_10;
    wire signal_lt_4;
    wire [4:0] osr_count_next;
    reg [4:0] osr_count_next_value;
    reg [4:0] signal_reg_18;
    wire [4:0] osr_count_0;
    wire signal_lt_5;
    wire signal_not_40;
    wire signal_wire_30;
    wire pull_now;
    wire pull_ok;
    wire [15:0] osr_before;
    wire signal_select_598;
    wire [15:0] signal_mux_228;
    wire signal_select_599;
    wire [15:0] signal_mux_229;
    wire signal_select_600;
    wire [15:0] signal_mux_230;
    wire signal_select_601;
    wire [15:0] signal_mux_231;
    wire [4:0] shift_back;
    wire signal_select_602;
    wire [15:0] signal_mux_232;
    wire [15:0] signal_and_56;
    wire signal_wire_31;
    wire [15:0] out_value;
    wire [19:0] signal_cat_166;
    wire signal_select_603;
    wire [19:0] signal_mux_233;
    wire signal_select_604;
    wire [19:0] signal_mux_234;
    wire signal_select_605;
    wire [19:0] signal_mux_235;
    wire signal_select_606;
    wire [19:0] signal_mux_236;
    wire signal_select_607;
    wire [19:0] signal_mux_237;
    wire [19:0] signal_and_57;
    wire [15:0] signal_select_608;
    wire [3:0] signal_select_609;
    wire [19:0] signal_cat_167;
    wire [7:0] signal_select_610;
    wire [11:0] signal_select_611;
    wire [19:0] signal_cat_168;
    wire [3:0] signal_select_612;
    wire [15:0] signal_select_613;
    wire [19:0] signal_cat_169;
    wire [1:0] signal_select_614;
    wire [17:0] signal_select_615;
    wire [19:0] signal_cat_170;
    wire signal_select_616;
    wire [18:0] signal_select_617;
    wire [19:0] signal_cat_171;
    wire [7:0] signal_select_618;
    wire [15:0] signal_cat_172;
    wire [11:0] signal_select_619;
    wire [15:0] signal_cat_173;
    wire [13:0] signal_select_620;
    wire [15:0] signal_cat_174;
    wire signal_select_621;
    wire [15:0] signal_mux_238;
    wire signal_select_622;
    wire [15:0] signal_mux_239;
    wire signal_select_623;
    wire [15:0] signal_mux_240;
    wire signal_select_624;
    wire [15:0] signal_mux_241;
    wire [4:0] d$shift_count;
    wire signal_select_625;
    wire [15:0] signal_mux_242;
    wire [15:0] signal_not_41;
    wire [19:0] signal_cat_175;
    wire signal_select_626;
    wire [19:0] signal_mux_243;
    wire signal_select_627;
    wire [19:0] signal_mux_244;
    wire signal_select_628;
    wire [19:0] signal_mux_245;
    wire signal_select_629;
    wire [19:0] signal_mux_246;
    wire [4:0] signal_wire_32;
    wire signal_select_630;
    wire [19:0] signal_mux_247;
    wire [19:0] signal_and_58;
    wire [19:0] signal_not_42;
    wire [19:0] signal_and_59;
    wire [19:0] signal_or_11;
    wire [2:0] d$out_dest$binary_variant;
    wire [2:0] d$in_source$binary_variant;
    wire signal_eq_60;
    wire [19:0] signal_mux_248;
    wire [15:0] signal_select_631;
    wire [3:0] signal_select_632;
    wire [19:0] signal_cat_176;
    wire [7:0] signal_select_633;
    wire [11:0] signal_select_634;
    wire [19:0] signal_cat_177;
    wire [3:0] signal_select_635;
    wire [15:0] signal_select_636;
    wire [19:0] signal_cat_178;
    wire [1:0] signal_select_637;
    wire [17:0] signal_select_638;
    wire [19:0] signal_cat_179;
    wire signal_select_639;
    wire [18:0] signal_select_640;
    wire [19:0] signal_cat_180;
    wire [1:0] signal_select_641;
    wire [1:0] signal_select_642;
    wire [4:0] signal_select_643;
    wire signal_select_644;
    wire [1:0] signal_cat_181;
    reg [1:0] d$side_set;
    wire [15:0] signal_cat_182;
    wire [19:0] signal_cat_183;
    wire signal_select_645;
    wire [19:0] signal_mux_249;
    wire signal_select_646;
    wire [19:0] signal_mux_250;
    wire signal_select_647;
    wire [19:0] signal_mux_251;
    wire signal_select_648;
    wire [19:0] signal_mux_252;
    wire signal_select_649;
    wire [19:0] signal_mux_253;
    wire [19:0] signal_and_60;
    wire [15:0] signal_select_650;
    wire [3:0] signal_select_651;
    wire [19:0] signal_cat_184;
    wire [7:0] signal_select_652;
    wire [11:0] signal_select_653;
    wire [19:0] signal_cat_185;
    wire [3:0] signal_select_654;
    wire [15:0] signal_select_655;
    wire [19:0] signal_cat_186;
    wire [1:0] signal_select_656;
    wire [17:0] signal_select_657;
    wire [19:0] signal_cat_187;
    wire signal_select_658;
    wire [18:0] signal_select_659;
    wire [19:0] signal_cat_188;
    wire [7:0] signal_select_660;
    wire [15:0] signal_cat_189;
    wire [11:0] signal_select_661;
    wire [15:0] signal_cat_190;
    wire [13:0] signal_select_662;
    wire [15:0] signal_cat_191;
    wire signal_select_663;
    wire [15:0] signal_mux_254;
    wire signal_select_664;
    wire [15:0] signal_mux_255;
    wire signal_select_665;
    wire [15:0] signal_mux_256;
    wire signal_select_666;
    wire [15:0] signal_mux_257;
    wire [1:0] signal_wire_33;
    wire [4:0] signal_cat_192;
    wire signal_select_667;
    wire [15:0] signal_mux_258;
    wire [15:0] signal_not_43;
    wire [19:0] signal_cat_193;
    wire signal_select_668;
    wire [19:0] signal_mux_259;
    wire signal_select_669;
    wire [19:0] signal_mux_260;
    wire signal_select_670;
    wire [19:0] signal_mux_261;
    wire signal_select_671;
    wire [19:0] signal_mux_262;
    wire [4:0] signal_wire_34;
    wire signal_select_672;
    wire [19:0] signal_mux_263;
    wire [19:0] signal_and_61;
    wire [19:0] signal_not_44;
    wire [19:0] signal_and_62;
    wire [19:0] pin_dir_side;
    wire signal_wire_35;
    wire [19:0] pin_dir_base;
    reg [19:0] pin_dir_next;
    reg [19:0] signal_reg_19;
    wire [19:0] pin_dir_0;
    wire signal_select_673;
    wire signal_mux_264;
    wire [19:0] sample;
    wire signal_select_674;
    wire [4:0] d$wait_index;
    reg wait_pin_cur;
    wire signal_eq_61;
    wire [1:0] d$wait_source$binary_variant;
    reg wait_ready;
    wire signal_not_45;
    wire gnd;
    wire signal_eq_62;
    reg is_opcode$1;
    wire wait_holds;
    wire signal_not_46;
    wire signal_eq_63;
    reg is_opcode$0;
    wire signal_not_47;
    wire op_go;
    wire advance;
    wire signal_or_12;
    wire ir_load;
    wire [4:0] signal_select_675;
    wire signal_eq_64;
    wire [2:0] signal_select_676;
    wire signal_lt_6;
    wire signal_select_677;
    wire signal_not_48;
    wire signal_or_13;
    wire [1:0] signal_select_678;
    wire signal_lt_7;
    wire signal_and_63;
    wire [2:0] signal_select_679;
    wire signal_lt_8;
    wire [1:0] signal_select_680;
    wire signal_lt_9;
    wire signal_lt_10;
    wire signal_not_49;
    wire [4:0] signal_select_681;
    wire signal_lt_11;
    wire signal_not_50;
    wire signal_and_64;
    wire signal_eq_65;
    wire signal_eq_66;
    wire [4:0] signal_const_267;
    wire signal_lt_12;
    wire [4:0] signal_select_682;
    wire signal_lt_13;
    wire [1:0] signal_select_683;
    reg signal_mux_265;
    wire [3:0] signal_const_269;
    wire [3:0] signal_select_684;
    wire signal_lt_14;
    wire [2:0] signal_select_685;
    reg signal_mux_266;
    reg decode_ok_0;
    wire go;
    wire jmp_go;
    wire [4:0] signal_mux_267;
    wire [4:0] stall_next;
    reg [4:0] signal_reg_20;
    wire [4:0] stall_0;
    wire signal_eq_67;
    wire signal_not_51;
    wire signal_and_65;
    wire issue;
    wire signal_and_66;
    wire signal_mux_268;
    wire signal_wire_36;
    wire signal_mux_269;
    wire signal_wire_37;
    wire signal_wire_38;
    reg start_0;
    wire halted_next;
    reg signal_reg_21;
    wire halted_0;
    wire signal_wire_39;
    wire program_write;
    wire vdd;
    wire signal_wire_40;
    wire [15:0] signal_inst_2;
    wire [15:0] signal_wire_41;
    reg [15:0] word;
    wire [2:0] d$opcode$binary_variant;
    reg [19:0] pin_out_next;
    reg [19:0] signal_reg_22;
    wire [19:0] pin_out_0;
    assign signal_const = 3'b100;
    assign signal_eq = signal_select_685 == signal_const;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$4 <= gnd;
        else
            if (ir_load)
                is_opcode$4 <= signal_eq;
    end
    assign signal_const_1 = 3'b101;
    assign signal_eq_1 = signal_select_685 == signal_const_1;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$5 <= gnd;
        else
            if (ir_load)
                is_opcode$5 <= signal_eq_1;
    end
    assign signal_const_2 = 3'b110;
    assign signal_eq_2 = signal_select_685 == signal_const_2;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$6 <= gnd;
        else
            if (ir_load)
                is_opcode$6 <= signal_eq_2;
    end
    assign signal_cat = { is_opcode$7,
                          is_opcode$6,
                          is_opcode$5,
                          is_opcode$4,
                          is_opcode$3,
                          is_opcode$2,
                          is_opcode$1,
                          is_opcode$0 };
    assign signal_select = signal_inst[15:0];
    assign signal_select_1 = signal_inst[19:16];
    assign signal_select_2 = signal_inst_1[19:16];
    assign signal_not = ~ decode_ok_0;
    assign signal_and = issue & signal_not;
    assign signal_const_3 = 1'b0;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg <= signal_const_3;
        else
            if (signal_and)
                signal_reg <= vdd;
    end
    assign signal_const_4 = 24'b000000000000000000000000;
    assign signal_sub = now_0 - t_0;
    assign signal_eq_3 = signal_sub == signal_const_4;
    assign signal_not_1 = ~ signal_eq_3;
    assign signal_sub_1 = now_0 - t_0;
    assign signal_select_3 = signal_sub_1[23:23];
    assign signal_not_2 = ~ signal_select_3;
    assign deadline_late = signal_not_2 & signal_not_1;
    assign signal_and_1 = op_go & releases_deadline;
    assign signal_and_2 = signal_and_1 & deadline_late;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_1 <= signal_const_3;
        else
            if (signal_and_2)
                signal_reg_1 <= vdd;
    end
    assign signal_and_3 = op_go & pushes;
    assign signal_and_4 = signal_and_3 & signal_select_196;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_2 <= signal_const_3;
        else
            if (signal_and_4)
                signal_reg_2 <= vdd;
    end
    assign signal_and_5 = pulls & signal_select_596;
    assign signal_and_6 = is_opcode$3 & pull_now;
    assign signal_and_7 = signal_and_6 & signal_select_596;
    assign signal_or = signal_and_7 | signal_and_5;
    assign signal_and_8 = op_go & signal_or;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_3 <= signal_const_3;
        else
            if (signal_and_8)
                signal_reg_3 <= vdd;
    end
    assign signal_wire = clear_irq;
    assign signal_mux = signal_wire ? gnd : irq_0;
    assign signal_const_9 = 3'b010;
    assign signal_eq_4 = d$sys_op$binary_variant == signal_const_9;
    assign signal_and_9 = is_opcode$7 & signal_eq_4;
    assign signal_and_10 = op_go & signal_and_9;
    assign signal_mux_1 = signal_and_10 ? vdd : signal_mux;
    assign signal_wire_1 = signal_mux_1;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            irq_0 <= signal_const_3;
        else
            irq_0 <= signal_wire_1;
    end
    assign signal_const_10 = 20'b00000000000000000000;
    assign signal_select_4 = signal_mux_5[19:4];
    assign signal_select_5 = signal_mux_5[3:0];
    assign signal_cat_1 = { signal_select_5,
                            signal_select_4 };
    assign signal_select_6 = signal_mux_4[19:12];
    assign signal_select_7 = signal_mux_4[11:0];
    assign signal_cat_2 = { signal_select_7,
                            signal_select_6 };
    assign signal_select_8 = signal_mux_3[19:16];
    assign signal_select_9 = signal_mux_3[15:0];
    assign signal_cat_3 = { signal_select_9,
                            signal_select_8 };
    assign signal_select_10 = signal_mux_2[19:18];
    assign signal_select_11 = signal_mux_2[17:0];
    assign signal_cat_4 = { signal_select_11,
                            signal_select_10 };
    assign signal_select_12 = signal_cat_7[19:19];
    assign signal_select_13 = signal_cat_7[18:0];
    assign signal_cat_5 = { signal_select_13,
                            signal_select_12 };
    assign signal_const_11 = 11'b00000000000;
    assign signal_cat_6 = { signal_const_11,
                            d$set_value };
    assign signal_const_12 = 4'b0000;
    assign signal_cat_7 = { signal_const_12,
                            signal_cat_6 };
    assign signal_select_14 = signal_wire_14[0:0];
    assign signal_mux_2 = signal_select_14 ? signal_cat_5 : signal_cat_7;
    assign signal_select_15 = signal_wire_14[1:1];
    assign signal_mux_3 = signal_select_15 ? signal_cat_4 : signal_mux_2;
    assign signal_select_16 = signal_wire_14[2:2];
    assign signal_mux_4 = signal_select_16 ? signal_cat_3 : signal_mux_3;
    assign signal_select_17 = signal_wire_14[3:3];
    assign signal_mux_5 = signal_select_17 ? signal_cat_2 : signal_mux_4;
    assign signal_select_18 = signal_wire_14[4:4];
    assign signal_mux_6 = signal_select_18 ? signal_cat_1 : signal_mux_5;
    assign signal_and_11 = signal_mux_6 & signal_and_12;
    assign signal_const_13 = 20'b11111111111111100000;
    assign signal_select_19 = signal_mux_15[19:4];
    assign signal_select_20 = signal_mux_15[3:0];
    assign signal_cat_8 = { signal_select_20,
                            signal_select_19 };
    assign signal_select_21 = signal_mux_14[19:12];
    assign signal_select_22 = signal_mux_14[11:0];
    assign signal_cat_9 = { signal_select_22,
                            signal_select_21 };
    assign signal_select_23 = signal_mux_13[19:16];
    assign signal_select_24 = signal_mux_13[15:0];
    assign signal_cat_10 = { signal_select_24,
                             signal_select_23 };
    assign signal_select_25 = signal_mux_12[19:18];
    assign signal_select_26 = signal_mux_12[17:0];
    assign signal_cat_11 = { signal_select_26,
                             signal_select_25 };
    assign signal_select_27 = signal_cat_16[19:19];
    assign signal_select_28 = signal_cat_16[18:0];
    assign signal_cat_12 = { signal_select_28,
                             signal_select_27 };
    assign signal_const_14 = 16'b0000000000000000;
    assign signal_const_15 = 8'b00000000;
    assign signal_select_29 = signal_mux_9[7:0];
    assign signal_cat_13 = { signal_select_29,
                             signal_const_15 };
    assign signal_select_30 = signal_mux_8[11:0];
    assign signal_cat_14 = { signal_select_30,
                             signal_const_12 };
    assign signal_const_17 = 2'b00;
    assign signal_select_31 = signal_mux_7[13:0];
    assign signal_cat_15 = { signal_select_31,
                             signal_const_17 };
    assign signal_const_18 = 16'b1111111111111110;
    assign signal_const_19 = 16'b1111111111111111;
    assign signal_select_32 = signal_cat_82[0:0];
    assign signal_mux_7 = signal_select_32 ? signal_const_18 : signal_const_19;
    assign signal_select_33 = signal_cat_82[1:1];
    assign signal_mux_8 = signal_select_33 ? signal_cat_15 : signal_mux_7;
    assign signal_select_34 = signal_cat_82[2:2];
    assign signal_mux_9 = signal_select_34 ? signal_cat_14 : signal_mux_8;
    assign signal_select_35 = signal_cat_82[3:3];
    assign signal_mux_10 = signal_select_35 ? signal_cat_13 : signal_mux_9;
    assign signal_select_36 = signal_cat_82[4:4];
    assign signal_mux_11 = signal_select_36 ? signal_const_14 : signal_mux_10;
    assign signal_not_3 = ~ signal_mux_11;
    assign signal_cat_16 = { signal_const_12,
                             signal_not_3 };
    assign signal_select_37 = signal_wire_14[0:0];
    assign signal_mux_12 = signal_select_37 ? signal_cat_12 : signal_cat_16;
    assign signal_select_38 = signal_wire_14[1:1];
    assign signal_mux_13 = signal_select_38 ? signal_cat_11 : signal_mux_12;
    assign signal_select_39 = signal_wire_14[2:2];
    assign signal_mux_14 = signal_select_39 ? signal_cat_10 : signal_mux_13;
    assign signal_select_40 = signal_wire_14[3:3];
    assign signal_mux_15 = signal_select_40 ? signal_cat_9 : signal_mux_14;
    assign signal_select_41 = signal_wire_14[4:4];
    assign signal_mux_16 = signal_select_41 ? signal_cat_8 : signal_mux_15;
    assign signal_and_12 = signal_mux_16 & signal_const_13;
    assign signal_not_4 = ~ signal_and_12;
    assign signal_and_13 = pin_out_base & signal_not_4;
    assign signal_or_1 = signal_and_13 | signal_and_11;
    assign signal_const_21 = 3'b000;
    assign signal_eq_5 = d$set_dest$binary_variant == signal_const_21;
    assign signal_mux_17 = signal_eq_5 ? signal_or_1 : pin_out_base;
    assign signal_select_42 = signal_mux_21[19:4];
    assign signal_select_43 = signal_mux_21[3:0];
    assign signal_cat_17 = { signal_select_43,
                             signal_select_42 };
    assign signal_select_44 = signal_mux_20[19:12];
    assign signal_select_45 = signal_mux_20[11:0];
    assign signal_cat_18 = { signal_select_45,
                             signal_select_44 };
    assign signal_select_46 = signal_mux_19[19:16];
    assign signal_select_47 = signal_mux_19[15:0];
    assign signal_cat_19 = { signal_select_47,
                             signal_select_46 };
    assign signal_select_48 = signal_mux_18[19:18];
    assign signal_select_49 = signal_mux_18[17:0];
    assign signal_cat_20 = { signal_select_49,
                             signal_select_48 };
    assign signal_select_50 = signal_cat_22[19:19];
    assign signal_select_51 = signal_cat_22[18:0];
    assign signal_cat_21 = { signal_select_51,
                             signal_select_50 };
    assign signal_cat_22 = { signal_const_12,
                             mov_value };
    assign signal_select_52 = signal_wire_32[0:0];
    assign signal_mux_18 = signal_select_52 ? signal_cat_21 : signal_cat_22;
    assign signal_select_53 = signal_wire_32[1:1];
    assign signal_mux_19 = signal_select_53 ? signal_cat_20 : signal_mux_18;
    assign signal_select_54 = signal_wire_32[2:2];
    assign signal_mux_20 = signal_select_54 ? signal_cat_19 : signal_mux_19;
    assign signal_select_55 = signal_wire_32[3:3];
    assign signal_mux_21 = signal_select_55 ? signal_cat_18 : signal_mux_20;
    assign signal_select_56 = signal_wire_32[4:4];
    assign signal_mux_22 = signal_select_56 ? signal_cat_17 : signal_mux_21;
    assign signal_and_14 = signal_mux_22 & signal_and_15;
    assign signal_select_57 = signal_mux_31[19:4];
    assign signal_select_58 = signal_mux_31[3:0];
    assign signal_cat_23 = { signal_select_58,
                             signal_select_57 };
    assign signal_select_59 = signal_mux_30[19:12];
    assign signal_select_60 = signal_mux_30[11:0];
    assign signal_cat_24 = { signal_select_60,
                             signal_select_59 };
    assign signal_select_61 = signal_mux_29[19:16];
    assign signal_select_62 = signal_mux_29[15:0];
    assign signal_cat_25 = { signal_select_62,
                             signal_select_61 };
    assign signal_select_63 = signal_mux_28[19:18];
    assign signal_select_64 = signal_mux_28[17:0];
    assign signal_cat_26 = { signal_select_64,
                             signal_select_63 };
    assign signal_select_65 = signal_cat_31[19:19];
    assign signal_select_66 = signal_cat_31[18:0];
    assign signal_cat_27 = { signal_select_66,
                             signal_select_65 };
    assign signal_select_67 = signal_mux_25[7:0];
    assign signal_cat_28 = { signal_select_67,
                             signal_const_15 };
    assign signal_select_68 = signal_mux_24[11:0];
    assign signal_cat_29 = { signal_select_68,
                             signal_const_12 };
    assign signal_select_69 = signal_mux_23[13:0];
    assign signal_cat_30 = { signal_select_69,
                             signal_const_17 };
    assign signal_select_70 = signal_wire_15[0:0];
    assign signal_mux_23 = signal_select_70 ? signal_const_18 : signal_const_19;
    assign signal_select_71 = signal_wire_15[1:1];
    assign signal_mux_24 = signal_select_71 ? signal_cat_30 : signal_mux_23;
    assign signal_select_72 = signal_wire_15[2:2];
    assign signal_mux_25 = signal_select_72 ? signal_cat_29 : signal_mux_24;
    assign signal_select_73 = signal_wire_15[3:3];
    assign signal_mux_26 = signal_select_73 ? signal_cat_28 : signal_mux_25;
    assign signal_select_74 = signal_wire_15[4:4];
    assign signal_mux_27 = signal_select_74 ? signal_const_14 : signal_mux_26;
    assign signal_not_5 = ~ signal_mux_27;
    assign signal_cat_31 = { signal_const_12,
                             signal_not_5 };
    assign signal_select_75 = signal_wire_32[0:0];
    assign signal_mux_28 = signal_select_75 ? signal_cat_27 : signal_cat_31;
    assign signal_select_76 = signal_wire_32[1:1];
    assign signal_mux_29 = signal_select_76 ? signal_cat_26 : signal_mux_28;
    assign signal_select_77 = signal_wire_32[2:2];
    assign signal_mux_30 = signal_select_77 ? signal_cat_25 : signal_mux_29;
    assign signal_select_78 = signal_wire_32[3:3];
    assign signal_mux_31 = signal_select_78 ? signal_cat_24 : signal_mux_30;
    assign signal_select_79 = signal_wire_32[4:4];
    assign signal_mux_32 = signal_select_79 ? signal_cat_23 : signal_mux_31;
    assign signal_and_15 = signal_mux_32 & signal_const_13;
    assign signal_not_6 = ~ signal_and_15;
    assign signal_and_16 = pin_out_base & signal_not_6;
    assign signal_or_2 = signal_and_16 | signal_and_14;
    assign signal_eq_6 = d$mov_dest$binary_variant == signal_const_21;
    assign signal_mux_33 = signal_eq_6 ? signal_or_2 : pin_out_base;
    assign signal_select_80 = signal_mux_37[19:4];
    assign signal_select_81 = signal_mux_37[3:0];
    assign signal_cat_32 = { signal_select_81,
                             signal_select_80 };
    assign signal_select_82 = signal_mux_36[19:12];
    assign signal_select_83 = signal_mux_36[11:0];
    assign signal_cat_33 = { signal_select_83,
                             signal_select_82 };
    assign signal_select_84 = signal_mux_35[19:16];
    assign signal_select_85 = signal_mux_35[15:0];
    assign signal_cat_34 = { signal_select_85,
                             signal_select_84 };
    assign signal_select_86 = signal_mux_34[19:18];
    assign signal_select_87 = signal_mux_34[17:0];
    assign signal_cat_35 = { signal_select_87,
                             signal_select_86 };
    assign signal_select_88 = signal_cat_37[19:19];
    assign signal_select_89 = signal_cat_37[18:0];
    assign signal_cat_36 = { signal_select_89,
                             signal_select_88 };
    assign signal_cat_37 = { signal_const_12,
                             out_value };
    assign signal_select_90 = signal_wire_32[0:0];
    assign signal_mux_34 = signal_select_90 ? signal_cat_36 : signal_cat_37;
    assign signal_select_91 = signal_wire_32[1:1];
    assign signal_mux_35 = signal_select_91 ? signal_cat_35 : signal_mux_34;
    assign signal_select_92 = signal_wire_32[2:2];
    assign signal_mux_36 = signal_select_92 ? signal_cat_34 : signal_mux_35;
    assign signal_select_93 = signal_wire_32[3:3];
    assign signal_mux_37 = signal_select_93 ? signal_cat_33 : signal_mux_36;
    assign signal_select_94 = signal_wire_32[4:4];
    assign signal_mux_38 = signal_select_94 ? signal_cat_32 : signal_mux_37;
    assign signal_and_17 = signal_mux_38 & signal_and_18;
    assign signal_select_95 = signal_mux_47[19:4];
    assign signal_select_96 = signal_mux_47[3:0];
    assign signal_cat_38 = { signal_select_96,
                             signal_select_95 };
    assign signal_select_97 = signal_mux_46[19:12];
    assign signal_select_98 = signal_mux_46[11:0];
    assign signal_cat_39 = { signal_select_98,
                             signal_select_97 };
    assign signal_select_99 = signal_mux_45[19:16];
    assign signal_select_100 = signal_mux_45[15:0];
    assign signal_cat_40 = { signal_select_100,
                             signal_select_99 };
    assign signal_select_101 = signal_mux_44[19:18];
    assign signal_select_102 = signal_mux_44[17:0];
    assign signal_cat_41 = { signal_select_102,
                             signal_select_101 };
    assign signal_select_103 = signal_cat_46[19:19];
    assign signal_select_104 = signal_cat_46[18:0];
    assign signal_cat_42 = { signal_select_104,
                             signal_select_103 };
    assign signal_select_105 = signal_mux_41[7:0];
    assign signal_cat_43 = { signal_select_105,
                             signal_const_15 };
    assign signal_select_106 = signal_mux_40[11:0];
    assign signal_cat_44 = { signal_select_106,
                             signal_const_12 };
    assign signal_select_107 = signal_mux_39[13:0];
    assign signal_cat_45 = { signal_select_107,
                             signal_const_17 };
    assign signal_select_108 = d$shift_count[0:0];
    assign signal_mux_39 = signal_select_108 ? signal_const_18 : signal_const_19;
    assign signal_select_109 = d$shift_count[1:1];
    assign signal_mux_40 = signal_select_109 ? signal_cat_45 : signal_mux_39;
    assign signal_select_110 = d$shift_count[2:2];
    assign signal_mux_41 = signal_select_110 ? signal_cat_44 : signal_mux_40;
    assign signal_select_111 = d$shift_count[3:3];
    assign signal_mux_42 = signal_select_111 ? signal_cat_43 : signal_mux_41;
    assign signal_select_112 = d$shift_count[4:4];
    assign signal_mux_43 = signal_select_112 ? signal_const_14 : signal_mux_42;
    assign signal_not_7 = ~ signal_mux_43;
    assign signal_cat_46 = { signal_const_12,
                             signal_not_7 };
    assign signal_select_113 = signal_wire_32[0:0];
    assign signal_mux_44 = signal_select_113 ? signal_cat_42 : signal_cat_46;
    assign signal_select_114 = signal_wire_32[1:1];
    assign signal_mux_45 = signal_select_114 ? signal_cat_41 : signal_mux_44;
    assign signal_select_115 = signal_wire_32[2:2];
    assign signal_mux_46 = signal_select_115 ? signal_cat_40 : signal_mux_45;
    assign signal_select_116 = signal_wire_32[3:3];
    assign signal_mux_47 = signal_select_116 ? signal_cat_39 : signal_mux_46;
    assign signal_select_117 = signal_wire_32[4:4];
    assign signal_mux_48 = signal_select_117 ? signal_cat_38 : signal_mux_47;
    assign signal_and_18 = signal_mux_48 & signal_const_13;
    assign signal_not_8 = ~ signal_and_18;
    assign signal_and_19 = pin_out_base & signal_not_8;
    assign signal_or_3 = signal_and_19 | signal_and_17;
    assign signal_eq_7 = d$out_dest$binary_variant == signal_const_21;
    assign signal_mux_49 = signal_eq_7 ? signal_or_3 : pin_out_base;
    assign signal_select_118 = signal_mux_53[19:4];
    assign signal_select_119 = signal_mux_53[3:0];
    assign signal_cat_47 = { signal_select_119,
                             signal_select_118 };
    assign signal_select_120 = signal_mux_52[19:12];
    assign signal_select_121 = signal_mux_52[11:0];
    assign signal_cat_48 = { signal_select_121,
                             signal_select_120 };
    assign signal_select_122 = signal_mux_51[19:16];
    assign signal_select_123 = signal_mux_51[15:0];
    assign signal_cat_49 = { signal_select_123,
                             signal_select_122 };
    assign signal_select_124 = signal_mux_50[19:18];
    assign signal_select_125 = signal_mux_50[17:0];
    assign signal_cat_50 = { signal_select_125,
                             signal_select_124 };
    assign signal_select_126 = signal_cat_53[19:19];
    assign signal_select_127 = signal_cat_53[18:0];
    assign signal_cat_51 = { signal_select_127,
                             signal_select_126 };
    assign signal_const_42 = 14'b00000000000000;
    assign signal_cat_52 = { signal_const_42,
                             d$side_set };
    assign signal_cat_53 = { signal_const_12,
                             signal_cat_52 };
    assign signal_select_128 = signal_wire_34[0:0];
    assign signal_mux_50 = signal_select_128 ? signal_cat_51 : signal_cat_53;
    assign signal_select_129 = signal_wire_34[1:1];
    assign signal_mux_51 = signal_select_129 ? signal_cat_50 : signal_mux_50;
    assign signal_select_130 = signal_wire_34[2:2];
    assign signal_mux_52 = signal_select_130 ? signal_cat_49 : signal_mux_51;
    assign signal_select_131 = signal_wire_34[3:3];
    assign signal_mux_53 = signal_select_131 ? signal_cat_48 : signal_mux_52;
    assign signal_select_132 = signal_wire_34[4:4];
    assign signal_mux_54 = signal_select_132 ? signal_cat_47 : signal_mux_53;
    assign signal_and_20 = signal_mux_54 & signal_and_21;
    assign signal_select_133 = signal_mux_63[19:4];
    assign signal_select_134 = signal_mux_63[3:0];
    assign signal_cat_54 = { signal_select_134,
                             signal_select_133 };
    assign signal_select_135 = signal_mux_62[19:12];
    assign signal_select_136 = signal_mux_62[11:0];
    assign signal_cat_55 = { signal_select_136,
                             signal_select_135 };
    assign signal_select_137 = signal_mux_61[19:16];
    assign signal_select_138 = signal_mux_61[15:0];
    assign signal_cat_56 = { signal_select_138,
                             signal_select_137 };
    assign signal_select_139 = signal_mux_60[19:18];
    assign signal_select_140 = signal_mux_60[17:0];
    assign signal_cat_57 = { signal_select_140,
                             signal_select_139 };
    assign signal_select_141 = signal_cat_62[19:19];
    assign signal_select_142 = signal_cat_62[18:0];
    assign signal_cat_58 = { signal_select_142,
                             signal_select_141 };
    assign signal_select_143 = signal_mux_57[7:0];
    assign signal_cat_59 = { signal_select_143,
                             signal_const_15 };
    assign signal_select_144 = signal_mux_56[11:0];
    assign signal_cat_60 = { signal_select_144,
                             signal_const_12 };
    assign signal_select_145 = signal_mux_55[13:0];
    assign signal_cat_61 = { signal_select_145,
                             signal_const_17 };
    assign signal_select_146 = signal_cat_192[0:0];
    assign signal_mux_55 = signal_select_146 ? signal_const_18 : signal_const_19;
    assign signal_select_147 = signal_cat_192[1:1];
    assign signal_mux_56 = signal_select_147 ? signal_cat_61 : signal_mux_55;
    assign signal_select_148 = signal_cat_192[2:2];
    assign signal_mux_57 = signal_select_148 ? signal_cat_60 : signal_mux_56;
    assign signal_select_149 = signal_cat_192[3:3];
    assign signal_mux_58 = signal_select_149 ? signal_cat_59 : signal_mux_57;
    assign signal_select_150 = signal_cat_192[4:4];
    assign signal_mux_59 = signal_select_150 ? signal_const_14 : signal_mux_58;
    assign signal_not_9 = ~ signal_mux_59;
    assign signal_cat_62 = { signal_const_12,
                             signal_not_9 };
    assign signal_select_151 = signal_wire_34[0:0];
    assign signal_mux_60 = signal_select_151 ? signal_cat_58 : signal_cat_62;
    assign signal_select_152 = signal_wire_34[1:1];
    assign signal_mux_61 = signal_select_152 ? signal_cat_57 : signal_mux_60;
    assign signal_select_153 = signal_wire_34[2:2];
    assign signal_mux_62 = signal_select_153 ? signal_cat_56 : signal_mux_61;
    assign signal_select_154 = signal_wire_34[3:3];
    assign signal_mux_63 = signal_select_154 ? signal_cat_55 : signal_mux_62;
    assign signal_select_155 = signal_wire_34[4:4];
    assign signal_mux_64 = signal_select_155 ? signal_cat_54 : signal_mux_63;
    assign signal_and_21 = signal_mux_64 & signal_const_13;
    assign signal_not_10 = ~ signal_and_21;
    assign signal_and_22 = pin_out_0 & signal_not_10;
    assign pin_out_side = signal_and_22 | signal_and_20;
    assign pin_out_base = signal_wire_35 ? pin_out_0 : pin_out_side;
    assign signal_wire_2 = program_write$data;
    assign signal_wire_3 = program_write$addr;
    assign signal_const_54 = 9'b000000000;
    assign signal_const_55 = 9'b000000001;
    assign signal_eq_8 = signal_const_54 == signal_wire_5;
    assign signal_mux_65 = signal_eq_8 ? signal_wire_4 : signal_const_55;
    assign signal_add = pc_next + signal_const_55;
    assign signal_eq_9 = pc_next == signal_wire_5;
    assign signal_mux_66 = signal_eq_9 ? signal_wire_4 : signal_add;
    assign signal_wire_4 = config$wrap_bottom;
    assign signal_add_1 = pc_0 + signal_const_55;
    assign signal_wire_5 = config$wrap_top;
    assign d$jmp_target = word[8:0];
    assign signal_not_11 = ~ signal_select_196;
    assign signal_not_12 = ~ signal_select_596;
    assign signal_const_61 = 5'b00000;
    assign signal_const_64 = 5'b00001;
    assign signal_add_2 = stuff_run_0 + signal_const_64;
    assign stuff_run_max = 5'b11111;
    assign signal_eq_10 = stuff_run_0 == stuff_run_max;
    assign signal_mux_67 = signal_eq_10 ? stuff_run_0 : signal_add_2;
    assign signal_wire_6 = config$stuff_level;
    assign signal_eq_11 = crossing_bit == signal_wire_6;
    assign signal_mux_68 = signal_eq_11 ? signal_mux_67 : signal_const_61;
    assign signal_mux_69 = bit_crosses ? signal_mux_68 : stuff_run_0;
    assign signal_eq_12 = d$sys_op$binary_variant == signal_const_2;
    assign signal_and_23 = is_opcode$7 & signal_eq_12;
    assign stuff_run_next = signal_and_23 ? signal_const_61 : signal_mux_69;
    assign signal_mux_70 = go ? stuff_run_next : stuff_run_0;
    assign signal_mux_71 = start_0 ? signal_const_61 : signal_mux_70;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_4 <= signal_const_61;
        else
            signal_reg_4 <= signal_mux_71;
    end
    assign stuff_run_0 = signal_reg_4;
    assign signal_lt = stuff_run_0 < signal_wire_7;
    assign signal_not_13 = ~ signal_lt;
    assign signal_wire_7 = config$stuff_threshold;
    assign signal_eq_13 = signal_wire_7 == signal_const_61;
    assign signal_not_14 = ~ signal_eq_13;
    assign signal_and_24 = signal_not_14 & signal_not_13;
    assign signal_lt_1 = osr_count_0 < signal_wire_29;
    assign signal_select_156 = sample[19:19];
    assign signal_select_157 = sample[18:18];
    assign signal_select_158 = sample[17:17];
    assign signal_select_159 = sample[16:16];
    assign signal_select_160 = sample[15:15];
    assign signal_select_161 = sample[14:14];
    assign signal_select_162 = sample[13:13];
    assign signal_select_163 = sample[12:12];
    assign signal_select_164 = sample[11:11];
    assign signal_select_165 = sample[10:10];
    assign signal_select_166 = sample[9:9];
    assign signal_select_167 = sample[8:8];
    assign signal_select_168 = sample[7:7];
    assign signal_select_169 = sample[6:6];
    assign signal_select_170 = sample[5:5];
    assign signal_select_171 = sample[4:4];
    assign signal_select_172 = sample[3:3];
    assign signal_select_173 = sample[2:2];
    assign signal_select_174 = sample[1:1];
    assign signal_select_175 = sample[0:0];
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_72 <= signal_select_175;
        1:
            signal_mux_72 <= signal_select_174;
        2:
            signal_mux_72 <= signal_select_173;
        3:
            signal_mux_72 <= signal_select_172;
        4:
            signal_mux_72 <= signal_select_171;
        5:
            signal_mux_72 <= signal_select_170;
        6:
            signal_mux_72 <= signal_select_169;
        7:
            signal_mux_72 <= signal_select_168;
        8:
            signal_mux_72 <= signal_select_167;
        9:
            signal_mux_72 <= signal_select_166;
        10:
            signal_mux_72 <= signal_select_165;
        11:
            signal_mux_72 <= signal_select_164;
        12:
            signal_mux_72 <= signal_select_163;
        13:
            signal_mux_72 <= signal_select_162;
        14:
            signal_mux_72 <= signal_select_161;
        15:
            signal_mux_72 <= signal_select_160;
        16:
            signal_mux_72 <= signal_select_159;
        17:
            signal_mux_72 <= signal_select_158;
        18:
            signal_mux_72 <= signal_select_157;
        default:
            signal_mux_72 <= signal_select_156;
        endcase
    end
    assign signal_not_15 = ~ signal_mux_72;
    assign signal_select_176 = sample[19:19];
    assign signal_select_177 = sample[18:18];
    assign signal_select_178 = sample[17:17];
    assign signal_select_179 = sample[16:16];
    assign signal_select_180 = sample[15:15];
    assign signal_select_181 = sample[14:14];
    assign signal_select_182 = sample[13:13];
    assign signal_select_183 = sample[12:12];
    assign signal_select_184 = sample[11:11];
    assign signal_select_185 = sample[10:10];
    assign signal_select_186 = sample[9:9];
    assign signal_select_187 = sample[8:8];
    assign signal_select_188 = sample[7:7];
    assign signal_select_189 = sample[6:6];
    assign signal_select_190 = sample[5:5];
    assign signal_select_191 = sample[4:4];
    assign signal_select_192 = sample[3:3];
    assign signal_select_193 = sample[2:2];
    assign signal_select_194 = sample[1:1];
    assign signal_select_195 = sample[0:0];
    assign signal_wire_8 = config$jmp_pin;
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_73 <= signal_select_195;
        1:
            signal_mux_73 <= signal_select_194;
        2:
            signal_mux_73 <= signal_select_193;
        3:
            signal_mux_73 <= signal_select_192;
        4:
            signal_mux_73 <= signal_select_191;
        5:
            signal_mux_73 <= signal_select_190;
        6:
            signal_mux_73 <= signal_select_189;
        7:
            signal_mux_73 <= signal_select_188;
        8:
            signal_mux_73 <= signal_select_187;
        9:
            signal_mux_73 <= signal_select_186;
        10:
            signal_mux_73 <= signal_select_185;
        11:
            signal_mux_73 <= signal_select_184;
        12:
            signal_mux_73 <= signal_select_183;
        13:
            signal_mux_73 <= signal_select_182;
        14:
            signal_mux_73 <= signal_select_181;
        15:
            signal_mux_73 <= signal_select_180;
        16:
            signal_mux_73 <= signal_select_179;
        17:
            signal_mux_73 <= signal_select_178;
        18:
            signal_mux_73 <= signal_select_177;
        default:
            signal_mux_73 <= signal_select_176;
        endcase
    end
    assign signal_eq_14 = x_0 == y_0;
    assign signal_not_16 = ~ signal_eq_14;
    assign signal_eq_15 = y_0 == signal_const_14;
    assign signal_not_17 = ~ signal_eq_15;
    assign signal_eq_16 = x_0 == signal_const_14;
    assign signal_not_18 = ~ signal_eq_16;
    always @* begin
        case (d$jmp_cond$binary_variant)
        0:
            jmp_taken <= vdd;
        1:
            jmp_taken <= signal_not_18;
        2:
            jmp_taken <= signal_not_17;
        3:
            jmp_taken <= signal_not_16;
        4:
            jmp_taken <= signal_mux_73;
        5:
            jmp_taken <= signal_not_15;
        6:
            jmp_taken <= signal_lt_1;
        7:
            jmp_taken <= signal_and_24;
        8:
            jmp_taken <= signal_not_12;
        9:
            jmp_taken <= signal_select_596;
        10:
            jmp_taken <= signal_not_11;
        default:
            jmp_taken <= signal_select_196;
        endcase
    end
    assign jmp_target_or_next = jmp_taken ? d$jmp_target : pc_next;
    assign signal_mux_74 = advance ? pc_next : pc_0;
    assign signal_mux_75 = jmp_go ? jmp_target_or_next : signal_mux_74;
    assign pc_value_next = start_0 ? signal_const_54 : signal_mux_75;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_5 <= signal_const_54;
        else
            signal_reg_5 <= pc_value_next;
    end
    assign pc_0 = signal_reg_5;
    assign signal_eq_17 = pc_0 == signal_wire_5;
    assign pc_next = signal_eq_17 ? signal_wire_4 : signal_add_1;
    assign signal_mux_76 = advance ? signal_mux_66 : pc_next;
    assign pc_after_next = start_0 ? signal_mux_65 : signal_mux_76;
    assign signal_mux_77 = jmp_go ? jmp_target_or_next : pc_after_next;
    assign signal_mux_78 = signal_wire_38 ? signal_const_54 : signal_mux_77;
    assign fetch_addr = signal_mux_78;
    assign signal_mux_79 = program_write ? signal_wire_3 : fetch_addr;
    assign signal_const_70 = 3'b001;
    assign signal_eq_18 = d$sys_op$binary_variant == signal_const_70;
    assign signal_and_25 = is_opcode$7 & signal_eq_18;
    assign signal_and_26 = op_go & signal_and_25;
    assign signal_mux_80 = signal_and_26 ? vdd : halted_0;
    assign signal_not_19 = ~ decode_ok_0;
    assign signal_not_20 = ~ start_0;
    assign signal_const_75 = 5'b00111;
    assign signal_and_27 = signal_select_643 & signal_const_75;
    assign signal_and_28 = signal_select_643 & signal_const_75;
    assign signal_const_77 = 5'b01111;
    assign signal_and_29 = signal_select_643 & signal_const_77;
    always @* begin
        case (signal_wire_33)
        0:
            d$delay <= signal_select_643;
        1:
            d$delay <= signal_and_29;
        2:
            d$delay <= signal_and_28;
        default:
            d$delay <= signal_and_27;
        endcase
    end
    assign signal_sub_2 = stall_0 - signal_const_64;
    assign signal_eq_19 = stall_0 == signal_const_61;
    assign signal_not_21 = ~ signal_eq_19;
    assign signal_mux_81 = signal_not_21 ? signal_sub_2 : stall_0;
    assign signal_mux_82 = advance ? d$delay : signal_mux_81;
    assign signal_or_4 = jmp_go | signal_wire_38;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            refill <= signal_const_3;
        else
            refill <= signal_or_4;
    end
    assign signal_not_22 = ~ signal_select_596;
    assign signal_wire_9 = rx_pop;
    assign signal_mux_83 = is_opcode$2 ? isr_shifted : isr_0;
    assign signal_wire_10 = signal_mux_83;
    assign signal_not_23 = ~ signal_select_196;
    assign signal_const_81 = 3'b011;
    assign signal_eq_20 = d$sys_op$binary_variant == signal_const_81;
    assign signal_and_30 = is_opcode$7 & signal_eq_20;
    assign signal_and_31 = is_opcode$2 & autopush_now;
    assign pushes = signal_and_31 | signal_and_30;
    assign signal_and_32 = op_go & pushes;
    assign signal_and_33 = signal_and_32 & signal_not_23;
    assign signal_wire_11 = signal_and_33;
    host_fifo
        rx
        ( .clock(signal_wire_40),
          .clear(signal_wire_37),
          .push$valid(signal_wire_11),
          .push$value(signal_wire_10),
          .pop(signal_wire_9),
          .head(signal_inst[15:0]),
          .level(signal_inst[19:16]),
          .empty(signal_inst[20:20]),
          .full(signal_inst[21:21]) );
    assign signal_select_196 = signal_inst[21:21];
    assign signal_not_24 = ~ signal_select_196;
    assign signal_mux_84 = d$wait_polarity ? signal_not_22 : signal_not_24;
    assign signal_xor = t_0 ^ signal_cat_63;
    assign signal_sub_3 = t_0 - signal_cat_63;
    assign signal_cat_63 = { signal_const_15,
                             alu_operand };
    assign signal_add_3 = t_0 + signal_cat_63;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_85 <= signal_add_3;
        1:
            signal_mux_85 <= signal_sub_3;
        default:
            signal_mux_85 <= signal_xor;
        endcase
    end
    assign signal_const_84 = 2'b11;
    assign signal_eq_21 = d$alu_dest$binary_variant == signal_const_84;
    assign signal_mux_86 = signal_eq_21 ? signal_mux_85 : t_0;
    assign signal_select_197 = mov_value24[23:23];
    assign signal_select_198 = mov_value24[22:22];
    assign signal_select_199 = mov_value24[21:21];
    assign signal_select_200 = mov_value24[20:20];
    assign signal_select_201 = mov_value24[19:19];
    assign signal_select_202 = mov_value24[18:18];
    assign signal_select_203 = mov_value24[17:17];
    assign signal_select_204 = mov_value24[16:16];
    assign signal_select_205 = mov_value24[15:15];
    assign signal_select_206 = mov_value24[14:14];
    assign signal_select_207 = mov_value24[13:13];
    assign signal_select_208 = mov_value24[12:12];
    assign signal_select_209 = mov_value24[11:11];
    assign signal_select_210 = mov_value24[10:10];
    assign signal_select_211 = mov_value24[9:9];
    assign signal_select_212 = mov_value24[8:8];
    assign signal_select_213 = mov_value24[7:7];
    assign signal_select_214 = mov_value24[6:6];
    assign signal_select_215 = mov_value24[5:5];
    assign signal_select_216 = mov_value24[4:4];
    assign signal_select_217 = mov_value24[3:3];
    assign signal_select_218 = mov_value24[2:2];
    assign signal_select_219 = mov_value24[1:1];
    assign signal_select_220 = mov_value24[0:0];
    assign signal_cat_64 = { signal_select_220,
                             signal_select_219,
                             signal_select_218,
                             signal_select_217,
                             signal_select_216,
                             signal_select_215,
                             signal_select_214,
                             signal_select_213,
                             signal_select_212,
                             signal_select_211,
                             signal_select_210,
                             signal_select_209,
                             signal_select_208,
                             signal_select_207,
                             signal_select_206,
                             signal_select_205,
                             signal_select_204,
                             signal_select_203,
                             signal_select_202,
                             signal_select_201,
                             signal_select_200,
                             signal_select_199,
                             signal_select_198,
                             signal_select_197 };
    assign signal_not_25 = ~ mov_value24;
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value_t <= mov_value24;
        1:
            mov_value_t <= signal_not_25;
        default:
            mov_value_t <= signal_cat_64;
        endcase
    end
    assign signal_const_85 = 3'b111;
    assign signal_eq_22 = d$mov_dest$binary_variant == signal_const_85;
    assign signal_mux_87 = signal_eq_22 ? mov_value_t : t_0;
    assign signal_cat_65 = { signal_const_15,
                             out_value };
    assign signal_eq_23 = d$out_dest$binary_variant == signal_const_85;
    assign signal_mux_88 = signal_eq_23 ? signal_cat_65 : t_0;
    assign signal_cat_66 = { signal_const_15,
                             p_0 };
    assign signal_add_4 = t_0 + signal_cat_66;
    assign signal_const_89 = 2'b10;
    assign signal_eq_24 = d$wait_source$binary_variant == signal_const_89;
    assign signal_and_34 = is_opcode$1 & signal_eq_24;
    assign releases_deadline = signal_and_34 & wait_ready;
    assign signal_and_35 = releases_deadline & d$wait_polarity;
    assign signal_mux_89 = signal_and_35 ? signal_add_4 : t_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_next <= t_0;
        1:
            t_next <= signal_mux_89;
        2:
            t_next <= t_0;
        3:
            t_next <= signal_mux_88;
        4:
            t_next <= signal_mux_87;
        5:
            t_next <= t_0;
        6:
            t_next <= signal_mux_86;
        default:
            t_next <= t_0;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_6 <= signal_const_4;
        else
            if (go)
                signal_reg_6 <= t_next;
    end
    assign t_0 = signal_reg_6;
    assign signal_sub_4 = now_0 - t_0;
    assign signal_select_221 = signal_sub_4[23:23];
    assign deadline_ready = ~ signal_select_221;
    assign signal_eq_25 = wait_pin_cur == d$wait_polarity;
    assign signal_select_222 = pins_sampled[19:19];
    assign signal_select_223 = pins_sampled[18:18];
    assign signal_select_224 = pins_sampled[17:17];
    assign signal_select_225 = pins_sampled[16:16];
    assign signal_select_226 = pins_sampled[15:15];
    assign signal_select_227 = pins_sampled[14:14];
    assign signal_select_228 = pins_sampled[13:13];
    assign signal_select_229 = pins_sampled[12:12];
    assign signal_select_230 = pins_sampled[11:11];
    assign signal_select_231 = pins_sampled[10:10];
    assign signal_select_232 = pins_sampled[9:9];
    assign signal_select_233 = pins_sampled[8:8];
    assign signal_select_234 = pins_sampled[7:7];
    assign signal_select_235 = pins_sampled[6:6];
    assign signal_select_236 = pins_sampled[5:5];
    assign signal_select_237 = pins_sampled[4:4];
    assign signal_select_238 = pins_sampled[3:3];
    assign signal_select_239 = pins_sampled[2:2];
    assign signal_select_240 = pins_sampled[1:1];
    assign signal_select_241 = pins_sampled[0:0];
    always @* begin
        case (d$wait_index)
        0:
            wait_pin_prev <= signal_select_241;
        1:
            wait_pin_prev <= signal_select_240;
        2:
            wait_pin_prev <= signal_select_239;
        3:
            wait_pin_prev <= signal_select_238;
        4:
            wait_pin_prev <= signal_select_237;
        5:
            wait_pin_prev <= signal_select_236;
        6:
            wait_pin_prev <= signal_select_235;
        7:
            wait_pin_prev <= signal_select_234;
        8:
            wait_pin_prev <= signal_select_233;
        9:
            wait_pin_prev <= signal_select_232;
        10:
            wait_pin_prev <= signal_select_231;
        11:
            wait_pin_prev <= signal_select_230;
        12:
            wait_pin_prev <= signal_select_229;
        13:
            wait_pin_prev <= signal_select_228;
        14:
            wait_pin_prev <= signal_select_227;
        15:
            wait_pin_prev <= signal_select_226;
        16:
            wait_pin_prev <= signal_select_225;
        17:
            wait_pin_prev <= signal_select_224;
        18:
            wait_pin_prev <= signal_select_223;
        default:
            wait_pin_prev <= signal_select_222;
        endcase
    end
    assign signal_eq_26 = wait_pin_cur == wait_pin_prev;
    assign signal_not_26 = ~ signal_eq_26;
    assign signal_and_36 = signal_not_26 & signal_eq_25;
    assign d$wait_polarity = word[7:7];
    assign signal_select_242 = sample[19:19];
    assign signal_select_243 = sample[18:18];
    assign signal_select_244 = sample[17:17];
    assign signal_select_245 = sample[16:16];
    assign signal_select_246 = sample[15:15];
    assign signal_select_247 = sample[14:14];
    assign signal_select_248 = sample[13:13];
    assign signal_select_249 = sample[12:12];
    assign signal_select_250 = sample[11:11];
    assign signal_select_251 = sample[10:10];
    assign signal_select_252 = sample[9:9];
    assign signal_select_253 = sample[8:8];
    assign signal_select_254 = sample[7:7];
    assign signal_select_255 = sample[6:6];
    assign signal_select_256 = sample[5:5];
    assign signal_select_257 = sample[4:4];
    assign signal_select_258 = sample[3:3];
    assign signal_select_259 = sample[2:2];
    assign signal_select_260 = sample[1:1];
    assign signal_select_261 = signal_wire_12[0:0];
    assign signal_select_262 = signal_wire_12[1:1];
    assign signal_select_263 = signal_wire_12[2:2];
    assign signal_select_264 = signal_wire_12[3:3];
    assign signal_select_265 = signal_wire_12[4:4];
    assign signal_select_266 = pin_out_0[5:5];
    assign signal_select_267 = pin_out_0[6:6];
    assign signal_select_268 = pin_out_0[7:7];
    assign signal_select_269 = pin_out_0[8:8];
    assign signal_select_270 = pin_out_0[9:9];
    assign signal_select_271 = pin_out_0[10:10];
    assign signal_select_272 = pin_out_0[11:11];
    assign signal_select_273 = pin_out_0[12:12];
    assign signal_select_274 = signal_wire_12[12:12];
    assign signal_select_275 = pin_dir_0[12:12];
    assign signal_mux_90 = signal_select_275 ? signal_select_273 : signal_select_274;
    assign signal_select_276 = pin_out_0[13:13];
    assign signal_select_277 = signal_wire_12[13:13];
    assign signal_select_278 = pin_dir_0[13:13];
    assign signal_mux_91 = signal_select_278 ? signal_select_276 : signal_select_277;
    assign signal_select_279 = pin_out_0[14:14];
    assign signal_select_280 = signal_wire_12[14:14];
    assign signal_select_281 = pin_dir_0[14:14];
    assign signal_mux_92 = signal_select_281 ? signal_select_279 : signal_select_280;
    assign signal_select_282 = pin_out_0[15:15];
    assign signal_select_283 = signal_wire_12[15:15];
    assign signal_select_284 = pin_dir_0[15:15];
    assign signal_mux_93 = signal_select_284 ? signal_select_282 : signal_select_283;
    assign signal_select_285 = pin_out_0[16:16];
    assign signal_select_286 = signal_wire_12[16:16];
    assign signal_select_287 = pin_dir_0[16:16];
    assign signal_mux_94 = signal_select_287 ? signal_select_285 : signal_select_286;
    assign signal_select_288 = pin_out_0[17:17];
    assign signal_select_289 = signal_wire_12[17:17];
    assign signal_select_290 = pin_dir_0[17:17];
    assign signal_mux_95 = signal_select_290 ? signal_select_288 : signal_select_289;
    assign signal_select_291 = pin_out_0[18:18];
    assign signal_select_292 = signal_wire_12[18:18];
    assign signal_select_293 = pin_dir_0[18:18];
    assign signal_mux_96 = signal_select_293 ? signal_select_291 : signal_select_292;
    assign signal_select_294 = pin_out_0[19:19];
    assign signal_wire_12 = inputs;
    assign signal_select_295 = signal_wire_12[19:19];
    assign signal_select_296 = signal_mux_100[19:4];
    assign signal_select_297 = signal_mux_100[3:0];
    assign signal_cat_67 = { signal_select_297,
                             signal_select_296 };
    assign signal_select_298 = signal_mux_99[19:12];
    assign signal_select_299 = signal_mux_99[11:0];
    assign signal_cat_68 = { signal_select_299,
                             signal_select_298 };
    assign signal_select_300 = signal_mux_98[19:16];
    assign signal_select_301 = signal_mux_98[15:0];
    assign signal_cat_69 = { signal_select_301,
                             signal_select_300 };
    assign signal_select_302 = signal_mux_97[19:18];
    assign signal_select_303 = signal_mux_97[17:0];
    assign signal_cat_70 = { signal_select_303,
                             signal_select_302 };
    assign signal_select_304 = signal_cat_73[19:19];
    assign signal_select_305 = signal_cat_73[18:0];
    assign signal_cat_71 = { signal_select_305,
                             signal_select_304 };
    assign signal_cat_72 = { signal_const_11,
                             d$set_value };
    assign signal_cat_73 = { signal_const_12,
                             signal_cat_72 };
    assign signal_select_306 = signal_wire_14[0:0];
    assign signal_mux_97 = signal_select_306 ? signal_cat_71 : signal_cat_73;
    assign signal_select_307 = signal_wire_14[1:1];
    assign signal_mux_98 = signal_select_307 ? signal_cat_70 : signal_mux_97;
    assign signal_select_308 = signal_wire_14[2:2];
    assign signal_mux_99 = signal_select_308 ? signal_cat_69 : signal_mux_98;
    assign signal_select_309 = signal_wire_14[3:3];
    assign signal_mux_100 = signal_select_309 ? signal_cat_68 : signal_mux_99;
    assign signal_select_310 = signal_wire_14[4:4];
    assign signal_mux_101 = signal_select_310 ? signal_cat_67 : signal_mux_100;
    assign signal_and_37 = signal_mux_101 & signal_and_38;
    assign signal_const_93 = 20'b11111111000000000000;
    assign signal_select_311 = signal_mux_110[19:4];
    assign signal_select_312 = signal_mux_110[3:0];
    assign signal_cat_74 = { signal_select_312,
                             signal_select_311 };
    assign signal_select_313 = signal_mux_109[19:12];
    assign signal_select_314 = signal_mux_109[11:0];
    assign signal_cat_75 = { signal_select_314,
                             signal_select_313 };
    assign signal_select_315 = signal_mux_108[19:16];
    assign signal_select_316 = signal_mux_108[15:0];
    assign signal_cat_76 = { signal_select_316,
                             signal_select_315 };
    assign signal_select_317 = signal_mux_107[19:18];
    assign signal_select_318 = signal_mux_107[17:0];
    assign signal_cat_77 = { signal_select_318,
                             signal_select_317 };
    assign signal_select_319 = signal_cat_83[19:19];
    assign signal_select_320 = signal_cat_83[18:0];
    assign signal_cat_78 = { signal_select_320,
                             signal_select_319 };
    assign signal_select_321 = signal_mux_104[7:0];
    assign signal_cat_79 = { signal_select_321,
                             signal_const_15 };
    assign signal_select_322 = signal_mux_103[11:0];
    assign signal_cat_80 = { signal_select_322,
                             signal_const_12 };
    assign signal_select_323 = signal_mux_102[13:0];
    assign signal_cat_81 = { signal_select_323,
                             signal_const_17 };
    assign signal_select_324 = signal_cat_82[0:0];
    assign signal_mux_102 = signal_select_324 ? signal_const_18 : signal_const_19;
    assign signal_select_325 = signal_cat_82[1:1];
    assign signal_mux_103 = signal_select_325 ? signal_cat_81 : signal_mux_102;
    assign signal_select_326 = signal_cat_82[2:2];
    assign signal_mux_104 = signal_select_326 ? signal_cat_80 : signal_mux_103;
    assign signal_select_327 = signal_cat_82[3:3];
    assign signal_mux_105 = signal_select_327 ? signal_cat_79 : signal_mux_104;
    assign signal_wire_13 = config$set_count;
    assign signal_cat_82 = { signal_const_17,
                             signal_wire_13 };
    assign signal_select_328 = signal_cat_82[4:4];
    assign signal_mux_106 = signal_select_328 ? signal_const_14 : signal_mux_105;
    assign signal_not_27 = ~ signal_mux_106;
    assign signal_cat_83 = { signal_const_12,
                             signal_not_27 };
    assign signal_select_329 = signal_wire_14[0:0];
    assign signal_mux_107 = signal_select_329 ? signal_cat_78 : signal_cat_83;
    assign signal_select_330 = signal_wire_14[1:1];
    assign signal_mux_108 = signal_select_330 ? signal_cat_77 : signal_mux_107;
    assign signal_select_331 = signal_wire_14[2:2];
    assign signal_mux_109 = signal_select_331 ? signal_cat_76 : signal_mux_108;
    assign signal_select_332 = signal_wire_14[3:3];
    assign signal_mux_110 = signal_select_332 ? signal_cat_75 : signal_mux_109;
    assign signal_wire_14 = config$set_base;
    assign signal_select_333 = signal_wire_14[4:4];
    assign signal_mux_111 = signal_select_333 ? signal_cat_74 : signal_mux_110;
    assign signal_and_38 = signal_mux_111 & signal_const_93;
    assign signal_not_28 = ~ signal_and_38;
    assign signal_and_39 = pin_dir_base & signal_not_28;
    assign signal_or_5 = signal_and_39 | signal_and_37;
    assign signal_eq_27 = d$set_dest$binary_variant == signal_const_81;
    assign signal_mux_112 = signal_eq_27 ? signal_or_5 : pin_dir_base;
    assign signal_select_334 = signal_mux_116[19:4];
    assign signal_select_335 = signal_mux_116[3:0];
    assign signal_cat_84 = { signal_select_335,
                             signal_select_334 };
    assign signal_select_336 = signal_mux_115[19:12];
    assign signal_select_337 = signal_mux_115[11:0];
    assign signal_cat_85 = { signal_select_337,
                             signal_select_336 };
    assign signal_select_338 = signal_mux_114[19:16];
    assign signal_select_339 = signal_mux_114[15:0];
    assign signal_cat_86 = { signal_select_339,
                             signal_select_338 };
    assign signal_select_340 = signal_mux_113[19:18];
    assign signal_select_341 = signal_mux_113[17:0];
    assign signal_cat_87 = { signal_select_341,
                             signal_select_340 };
    assign signal_select_342 = signal_cat_89[19:19];
    assign signal_select_343 = signal_cat_89[18:0];
    assign signal_cat_88 = { signal_select_343,
                             signal_select_342 };
    assign signal_cat_89 = { signal_const_12,
                             mov_value };
    assign signal_select_344 = signal_wire_32[0:0];
    assign signal_mux_113 = signal_select_344 ? signal_cat_88 : signal_cat_89;
    assign signal_select_345 = signal_wire_32[1:1];
    assign signal_mux_114 = signal_select_345 ? signal_cat_87 : signal_mux_113;
    assign signal_select_346 = signal_wire_32[2:2];
    assign signal_mux_115 = signal_select_346 ? signal_cat_86 : signal_mux_114;
    assign signal_select_347 = signal_wire_32[3:3];
    assign signal_mux_116 = signal_select_347 ? signal_cat_85 : signal_mux_115;
    assign signal_select_348 = signal_wire_32[4:4];
    assign signal_mux_117 = signal_select_348 ? signal_cat_84 : signal_mux_116;
    assign signal_and_40 = signal_mux_117 & signal_and_41;
    assign signal_select_349 = signal_mux_126[19:4];
    assign signal_select_350 = signal_mux_126[3:0];
    assign signal_cat_90 = { signal_select_350,
                             signal_select_349 };
    assign signal_select_351 = signal_mux_125[19:12];
    assign signal_select_352 = signal_mux_125[11:0];
    assign signal_cat_91 = { signal_select_352,
                             signal_select_351 };
    assign signal_select_353 = signal_mux_124[19:16];
    assign signal_select_354 = signal_mux_124[15:0];
    assign signal_cat_92 = { signal_select_354,
                             signal_select_353 };
    assign signal_select_355 = signal_mux_123[19:18];
    assign signal_select_356 = signal_mux_123[17:0];
    assign signal_cat_93 = { signal_select_356,
                             signal_select_355 };
    assign signal_select_357 = signal_cat_98[19:19];
    assign signal_select_358 = signal_cat_98[18:0];
    assign signal_cat_94 = { signal_select_358,
                             signal_select_357 };
    assign signal_select_359 = signal_mux_120[7:0];
    assign signal_cat_95 = { signal_select_359,
                             signal_const_15 };
    assign signal_select_360 = signal_mux_119[11:0];
    assign signal_cat_96 = { signal_select_360,
                             signal_const_12 };
    assign signal_select_361 = signal_mux_118[13:0];
    assign signal_cat_97 = { signal_select_361,
                             signal_const_17 };
    assign signal_select_362 = signal_wire_15[0:0];
    assign signal_mux_118 = signal_select_362 ? signal_const_18 : signal_const_19;
    assign signal_select_363 = signal_wire_15[1:1];
    assign signal_mux_119 = signal_select_363 ? signal_cat_97 : signal_mux_118;
    assign signal_select_364 = signal_wire_15[2:2];
    assign signal_mux_120 = signal_select_364 ? signal_cat_96 : signal_mux_119;
    assign signal_select_365 = signal_wire_15[3:3];
    assign signal_mux_121 = signal_select_365 ? signal_cat_95 : signal_mux_120;
    assign signal_wire_15 = config$out_count;
    assign signal_select_366 = signal_wire_15[4:4];
    assign signal_mux_122 = signal_select_366 ? signal_const_14 : signal_mux_121;
    assign signal_not_29 = ~ signal_mux_122;
    assign signal_cat_98 = { signal_const_12,
                             signal_not_29 };
    assign signal_select_367 = signal_wire_32[0:0];
    assign signal_mux_123 = signal_select_367 ? signal_cat_94 : signal_cat_98;
    assign signal_select_368 = signal_wire_32[1:1];
    assign signal_mux_124 = signal_select_368 ? signal_cat_93 : signal_mux_123;
    assign signal_select_369 = signal_wire_32[2:2];
    assign signal_mux_125 = signal_select_369 ? signal_cat_92 : signal_mux_124;
    assign signal_select_370 = signal_wire_32[3:3];
    assign signal_mux_126 = signal_select_370 ? signal_cat_91 : signal_mux_125;
    assign signal_select_371 = signal_wire_32[4:4];
    assign signal_mux_127 = signal_select_371 ? signal_cat_90 : signal_mux_126;
    assign signal_and_41 = signal_mux_127 & signal_const_93;
    assign signal_not_30 = ~ signal_and_41;
    assign signal_and_42 = pin_dir_base & signal_not_30;
    assign signal_or_6 = signal_and_42 | signal_and_40;
    assign signal_eq_28 = d$mov_dest$binary_variant == signal_const_81;
    assign signal_mux_128 = signal_eq_28 ? signal_or_6 : pin_dir_base;
    assign signal_select_372 = signal_mux_236[19:4];
    assign signal_select_373 = signal_mux_236[3:0];
    assign signal_cat_99 = { signal_select_373,
                             signal_select_372 };
    assign signal_select_374 = signal_mux_235[19:12];
    assign signal_select_375 = signal_mux_235[11:0];
    assign signal_cat_100 = { signal_select_375,
                              signal_select_374 };
    assign signal_select_376 = signal_mux_234[19:16];
    assign signal_select_377 = signal_mux_234[15:0];
    assign signal_cat_101 = { signal_select_377,
                              signal_select_376 };
    assign signal_select_378 = signal_mux_233[19:18];
    assign signal_select_379 = signal_mux_233[17:0];
    assign signal_cat_102 = { signal_select_379,
                              signal_select_378 };
    assign signal_select_380 = signal_cat_166[19:19];
    assign signal_select_381 = signal_cat_166[18:0];
    assign signal_cat_103 = { signal_select_381,
                              signal_select_380 };
    assign signal_and_43 = osr_before & mask;
    assign signal_select_382 = signal_mux_230[15:8];
    assign signal_cat_104 = { signal_const_15,
                              signal_select_382 };
    assign signal_select_383 = signal_mux_229[15:4];
    assign signal_cat_105 = { signal_const_12,
                              signal_select_383 };
    assign signal_select_384 = signal_mux_228[15:2];
    assign signal_cat_106 = { signal_const_17,
                              signal_select_384 };
    assign signal_select_385 = osr_before[15:1];
    assign signal_cat_107 = { signal_const_3,
                              signal_select_385 };
    assign signal_select_386 = signal_inst_1[15:0];
    assign signal_not_31 = ~ signal_select_596;
    assign signal_and_44 = pulls & signal_not_31;
    assign signal_mux_129 = signal_and_44 ? signal_select_386 : osr_0;
    assign signal_select_387 = signal_select_577[15:15];
    assign signal_select_388 = signal_select_577[14:14];
    assign signal_select_389 = signal_select_577[13:13];
    assign signal_select_390 = signal_select_577[12:12];
    assign signal_select_391 = signal_select_577[11:11];
    assign signal_select_392 = signal_select_577[10:10];
    assign signal_select_393 = signal_select_577[9:9];
    assign signal_select_394 = signal_select_577[8:8];
    assign signal_select_395 = signal_select_577[7:7];
    assign signal_select_396 = signal_select_577[6:6];
    assign signal_select_397 = signal_select_577[5:5];
    assign signal_select_398 = signal_select_577[4:4];
    assign signal_select_399 = signal_select_577[3:3];
    assign signal_select_400 = signal_select_577[2:2];
    assign signal_select_401 = signal_select_577[1:1];
    assign signal_select_402 = signal_select_577[0:0];
    assign signal_cat_108 = { signal_select_402,
                              signal_select_401,
                              signal_select_400,
                              signal_select_399,
                              signal_select_398,
                              signal_select_397,
                              signal_select_396,
                              signal_select_395,
                              signal_select_394,
                              signal_select_393,
                              signal_select_392,
                              signal_select_391,
                              signal_select_390,
                              signal_select_389,
                              signal_select_388,
                              signal_select_387 };
    assign signal_not_32 = ~ signal_select_577;
    assign signal_cat_109 = { signal_const_15,
                              osr_0 };
    assign signal_cat_110 = { signal_const_15,
                              isr_0 };
    assign signal_cat_111 = { signal_const_15,
                              y_0 };
    assign signal_xor_1 = x_0 ^ alu_operand;
    assign signal_sub_5 = x_0 - alu_operand;
    assign signal_eq_29 = d$sys_op$binary_variant == signal_const_81;
    assign signal_and_45 = is_opcode$7 & signal_eq_29;
    assign signal_mux_130 = signal_and_45 ? signal_const_14 : isr_0;
    assign signal_eq_30 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_131 = signal_eq_30 ? mov_value : isr_0;
    assign signal_eq_31 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_132 = signal_eq_31 ? out_value : isr_0;
    assign signal_select_403 = signal_mux_135[7:0];
    assign signal_cat_112 = { signal_select_403,
                              signal_const_15 };
    assign signal_select_404 = signal_mux_134[11:0];
    assign signal_cat_113 = { signal_select_404,
                              signal_const_12 };
    assign signal_select_405 = signal_mux_133[13:0];
    assign signal_cat_114 = { signal_select_405,
                              signal_const_17 };
    assign signal_select_406 = in_value[14:0];
    assign signal_cat_115 = { signal_select_406,
                              signal_const_3 };
    assign signal_select_407 = shift_back[0:0];
    assign signal_mux_133 = signal_select_407 ? signal_cat_115 : in_value;
    assign signal_select_408 = shift_back[1:1];
    assign signal_mux_134 = signal_select_408 ? signal_cat_114 : signal_mux_133;
    assign signal_select_409 = shift_back[2:2];
    assign signal_mux_135 = signal_select_409 ? signal_cat_113 : signal_mux_134;
    assign signal_select_410 = shift_back[3:3];
    assign signal_mux_136 = signal_select_410 ? signal_cat_112 : signal_mux_135;
    assign signal_select_411 = shift_back[4:4];
    assign signal_mux_137 = signal_select_411 ? signal_const_14 : signal_mux_136;
    assign signal_select_412 = signal_mux_140[15:8];
    assign signal_cat_116 = { signal_const_15,
                              signal_select_412 };
    assign signal_select_413 = signal_mux_139[15:4];
    assign signal_cat_117 = { signal_const_12,
                              signal_select_413 };
    assign signal_select_414 = signal_mux_138[15:2];
    assign signal_cat_118 = { signal_const_17,
                              signal_select_414 };
    assign signal_select_415 = isr_0[15:1];
    assign signal_cat_119 = { signal_const_3,
                              signal_select_415 };
    assign signal_select_416 = d$shift_count[0:0];
    assign signal_mux_138 = signal_select_416 ? signal_cat_119 : isr_0;
    assign signal_select_417 = d$shift_count[1:1];
    assign signal_mux_139 = signal_select_417 ? signal_cat_118 : signal_mux_138;
    assign signal_select_418 = d$shift_count[2:2];
    assign signal_mux_140 = signal_select_418 ? signal_cat_117 : signal_mux_139;
    assign signal_select_419 = d$shift_count[3:3];
    assign signal_mux_141 = signal_select_419 ? signal_cat_116 : signal_mux_140;
    assign signal_select_420 = d$shift_count[4:4];
    assign signal_mux_142 = signal_select_420 ? signal_const_14 : signal_mux_141;
    assign signal_or_7 = signal_mux_142 | signal_mux_137;
    assign signal_select_421 = signal_mux_145[7:0];
    assign signal_cat_120 = { signal_select_421,
                              signal_const_15 };
    assign signal_select_422 = signal_mux_144[11:0];
    assign signal_cat_121 = { signal_select_422,
                              signal_const_12 };
    assign signal_select_423 = signal_mux_143[13:0];
    assign signal_cat_122 = { signal_select_423,
                              signal_const_17 };
    assign signal_select_424 = d$shift_count[0:0];
    assign signal_mux_143 = signal_select_424 ? signal_const_18 : signal_const_19;
    assign signal_select_425 = d$shift_count[1:1];
    assign signal_mux_144 = signal_select_425 ? signal_cat_122 : signal_mux_143;
    assign signal_select_426 = d$shift_count[2:2];
    assign signal_mux_145 = signal_select_426 ? signal_cat_121 : signal_mux_144;
    assign signal_select_427 = d$shift_count[3:3];
    assign signal_mux_146 = signal_select_427 ? signal_cat_120 : signal_mux_145;
    assign signal_select_428 = d$shift_count[4:4];
    assign signal_mux_147 = signal_select_428 ? signal_const_14 : signal_mux_146;
    assign mask = ~ signal_mux_147;
    assign signal_wire_16 = config$capture_rising;
    assign signal_select_429 = sample[19:19];
    assign signal_select_430 = sample[18:18];
    assign signal_select_431 = sample[17:17];
    assign signal_select_432 = sample[16:16];
    assign signal_select_433 = sample[15:15];
    assign signal_select_434 = sample[14:14];
    assign signal_select_435 = sample[13:13];
    assign signal_select_436 = sample[12:12];
    assign signal_select_437 = sample[11:11];
    assign signal_select_438 = sample[10:10];
    assign signal_select_439 = sample[9:9];
    assign signal_select_440 = sample[8:8];
    assign signal_select_441 = sample[7:7];
    assign signal_select_442 = sample[6:6];
    assign signal_select_443 = sample[5:5];
    assign signal_select_444 = sample[4:4];
    assign signal_select_445 = sample[3:3];
    assign signal_select_446 = sample[2:2];
    assign signal_select_447 = sample[1:1];
    assign signal_select_448 = sample[0:0];
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_148 <= signal_select_448;
        1:
            signal_mux_148 <= signal_select_447;
        2:
            signal_mux_148 <= signal_select_446;
        3:
            signal_mux_148 <= signal_select_445;
        4:
            signal_mux_148 <= signal_select_444;
        5:
            signal_mux_148 <= signal_select_443;
        6:
            signal_mux_148 <= signal_select_442;
        7:
            signal_mux_148 <= signal_select_441;
        8:
            signal_mux_148 <= signal_select_440;
        9:
            signal_mux_148 <= signal_select_439;
        10:
            signal_mux_148 <= signal_select_438;
        11:
            signal_mux_148 <= signal_select_437;
        12:
            signal_mux_148 <= signal_select_436;
        13:
            signal_mux_148 <= signal_select_435;
        14:
            signal_mux_148 <= signal_select_434;
        15:
            signal_mux_148 <= signal_select_433;
        16:
            signal_mux_148 <= signal_select_432;
        17:
            signal_mux_148 <= signal_select_431;
        18:
            signal_mux_148 <= signal_select_430;
        default:
            signal_mux_148 <= signal_select_429;
        endcase
    end
    assign signal_eq_32 = signal_mux_148 == signal_wire_16;
    assign signal_select_449 = pins_sampled[19:19];
    assign signal_select_450 = pins_sampled[18:18];
    assign signal_select_451 = pins_sampled[17:17];
    assign signal_select_452 = pins_sampled[16:16];
    assign signal_select_453 = pins_sampled[15:15];
    assign signal_select_454 = pins_sampled[14:14];
    assign signal_select_455 = pins_sampled[13:13];
    assign signal_select_456 = pins_sampled[12:12];
    assign signal_select_457 = pins_sampled[11:11];
    assign signal_select_458 = pins_sampled[10:10];
    assign signal_select_459 = pins_sampled[9:9];
    assign signal_select_460 = pins_sampled[8:8];
    assign signal_select_461 = pins_sampled[7:7];
    assign signal_select_462 = pins_sampled[6:6];
    assign signal_select_463 = pins_sampled[5:5];
    assign signal_select_464 = pins_sampled[4:4];
    assign signal_select_465 = pins_sampled[3:3];
    assign signal_select_466 = pins_sampled[2:2];
    assign signal_select_467 = pins_sampled[1:1];
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_7 <= signal_const_10;
        else
            signal_reg_7 <= sample;
    end
    assign pins_sampled = signal_reg_7;
    assign signal_select_468 = pins_sampled[0:0];
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_149 <= signal_select_468;
        1:
            signal_mux_149 <= signal_select_467;
        2:
            signal_mux_149 <= signal_select_466;
        3:
            signal_mux_149 <= signal_select_465;
        4:
            signal_mux_149 <= signal_select_464;
        5:
            signal_mux_149 <= signal_select_463;
        6:
            signal_mux_149 <= signal_select_462;
        7:
            signal_mux_149 <= signal_select_461;
        8:
            signal_mux_149 <= signal_select_460;
        9:
            signal_mux_149 <= signal_select_459;
        10:
            signal_mux_149 <= signal_select_458;
        11:
            signal_mux_149 <= signal_select_457;
        12:
            signal_mux_149 <= signal_select_456;
        13:
            signal_mux_149 <= signal_select_455;
        14:
            signal_mux_149 <= signal_select_454;
        15:
            signal_mux_149 <= signal_select_453;
        16:
            signal_mux_149 <= signal_select_452;
        17:
            signal_mux_149 <= signal_select_451;
        18:
            signal_mux_149 <= signal_select_450;
        default:
            signal_mux_149 <= signal_select_449;
        endcase
    end
    assign signal_select_469 = sample[19:19];
    assign signal_select_470 = sample[18:18];
    assign signal_select_471 = sample[17:17];
    assign signal_select_472 = sample[16:16];
    assign signal_select_473 = sample[15:15];
    assign signal_select_474 = sample[14:14];
    assign signal_select_475 = sample[13:13];
    assign signal_select_476 = sample[12:12];
    assign signal_select_477 = sample[11:11];
    assign signal_select_478 = sample[10:10];
    assign signal_select_479 = sample[9:9];
    assign signal_select_480 = sample[8:8];
    assign signal_select_481 = sample[7:7];
    assign signal_select_482 = sample[6:6];
    assign signal_select_483 = sample[5:5];
    assign signal_select_484 = sample[4:4];
    assign signal_select_485 = sample[3:3];
    assign signal_select_486 = sample[2:2];
    assign signal_select_487 = sample[1:1];
    assign signal_select_488 = sample[0:0];
    assign signal_wire_17 = config$capture_pin;
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_150 <= signal_select_488;
        1:
            signal_mux_150 <= signal_select_487;
        2:
            signal_mux_150 <= signal_select_486;
        3:
            signal_mux_150 <= signal_select_485;
        4:
            signal_mux_150 <= signal_select_484;
        5:
            signal_mux_150 <= signal_select_483;
        6:
            signal_mux_150 <= signal_select_482;
        7:
            signal_mux_150 <= signal_select_481;
        8:
            signal_mux_150 <= signal_select_480;
        9:
            signal_mux_150 <= signal_select_479;
        10:
            signal_mux_150 <= signal_select_478;
        11:
            signal_mux_150 <= signal_select_477;
        12:
            signal_mux_150 <= signal_select_476;
        13:
            signal_mux_150 <= signal_select_475;
        14:
            signal_mux_150 <= signal_select_474;
        15:
            signal_mux_150 <= signal_select_473;
        16:
            signal_mux_150 <= signal_select_472;
        17:
            signal_mux_150 <= signal_select_471;
        18:
            signal_mux_150 <= signal_select_470;
        default:
            signal_mux_150 <= signal_select_469;
        endcase
    end
    assign signal_eq_33 = signal_mux_150 == signal_mux_149;
    assign signal_not_33 = ~ signal_eq_33;
    assign signal_eq_34 = d$sys_op$binary_variant == signal_const_85;
    assign signal_and_46 = is_opcode$7 & signal_eq_34;
    assign signal_and_47 = op_go & signal_and_46;
    assign signal_mux_151 = signal_and_47 ? vdd : capture_armed_0;
    assign signal_mux_152 = captured ? gnd : signal_mux_151;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_8 <= signal_const_3;
        else
            signal_reg_8 <= signal_mux_152;
    end
    assign capture_armed_0 = signal_reg_8;
    assign signal_and_48 = capture_armed_0 & signal_not_33;
    assign captured = signal_and_48 & signal_eq_32;
    assign signal_const_152 = 24'b000000000000000000000001;
    assign signal_add_5 = now_0 + signal_const_152;
    assign signal_mux_153 = start_0 ? signal_const_4 : signal_add_5;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_9 <= signal_const_4;
        else
            signal_reg_9 <= signal_mux_153;
    end
    assign now_0 = signal_reg_9;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_10 <= signal_const_4;
        else
            if (captured)
                signal_reg_10 <= now_0;
    end
    assign capture_0 = signal_reg_10;
    assign signal_select_489 = capture_0[15:0];
    assign signal_wire_18 = config$crc_init;
    assign signal_select_490 = signal_mux_156[7:0];
    assign signal_cat_123 = { signal_select_490,
                              signal_const_15 };
    assign signal_select_491 = signal_mux_155[11:0];
    assign signal_cat_124 = { signal_select_491,
                              signal_const_12 };
    assign signal_select_492 = signal_mux_154[13:0];
    assign signal_cat_125 = { signal_select_492,
                              signal_const_17 };
    assign signal_select_493 = signal_wire_20[0:0];
    assign signal_mux_154 = signal_select_493 ? signal_const_18 : signal_const_19;
    assign signal_select_494 = signal_wire_20[1:1];
    assign signal_mux_155 = signal_select_494 ? signal_cat_125 : signal_mux_154;
    assign signal_select_495 = signal_wire_20[2:2];
    assign signal_mux_156 = signal_select_495 ? signal_cat_124 : signal_mux_155;
    assign signal_select_496 = signal_wire_20[3:3];
    assign signal_mux_157 = signal_select_496 ? signal_cat_123 : signal_mux_156;
    assign signal_select_497 = signal_wire_20[4:4];
    assign signal_mux_158 = signal_select_497 ? signal_const_14 : signal_mux_157;
    assign signal_not_34 = ~ signal_mux_158;
    assign signal_xor_2 = signal_cat_126 ^ signal_wire_19;
    assign signal_select_498 = crc_0[15:1];
    assign signal_cat_126 = { signal_const_3,
                              signal_select_498 };
    assign signal_select_499 = crc_0[0:0];
    assign signal_xor_3 = signal_select_499 ^ crossing_bit;
    assign signal_mux_159 = signal_xor_3 ? signal_xor_2 : signal_cat_126;
    assign signal_wire_19 = config$crc_poly;
    assign signal_xor_4 = signal_cat_127 ^ signal_wire_19;
    assign signal_select_500 = crc_0[14:0];
    assign signal_cat_127 = { signal_select_500,
                              signal_const_3 };
    assign signal_select_501 = in_value[0:0];
    assign signal_select_502 = out_value[0:0];
    assign crossing_bit = is_opcode$2 ? signal_select_501 : signal_select_502;
    assign signal_select_503 = crc_0[15:15];
    assign signal_select_504 = crc_0[14:14];
    assign signal_select_505 = crc_0[13:13];
    assign signal_select_506 = crc_0[12:12];
    assign signal_select_507 = crc_0[11:11];
    assign signal_select_508 = crc_0[10:10];
    assign signal_select_509 = crc_0[9:9];
    assign signal_select_510 = crc_0[8:8];
    assign signal_select_511 = crc_0[7:7];
    assign signal_select_512 = crc_0[6:6];
    assign signal_select_513 = crc_0[5:5];
    assign signal_select_514 = crc_0[4:4];
    assign signal_select_515 = crc_0[3:3];
    assign signal_select_516 = crc_0[2:2];
    assign signal_select_517 = crc_0[1:1];
    assign signal_select_518 = crc_0[0:0];
    assign signal_wire_20 = config$crc_width;
    assign signal_sub_6 = signal_wire_20 - signal_const_64;
    always @* begin
        case (signal_sub_6)
        0:
            signal_mux_160 <= signal_select_518;
        1:
            signal_mux_160 <= signal_select_517;
        2:
            signal_mux_160 <= signal_select_516;
        3:
            signal_mux_160 <= signal_select_515;
        4:
            signal_mux_160 <= signal_select_514;
        5:
            signal_mux_160 <= signal_select_513;
        6:
            signal_mux_160 <= signal_select_512;
        7:
            signal_mux_160 <= signal_select_511;
        8:
            signal_mux_160 <= signal_select_510;
        9:
            signal_mux_160 <= signal_select_509;
        10:
            signal_mux_160 <= signal_select_508;
        11:
            signal_mux_160 <= signal_select_507;
        12:
            signal_mux_160 <= signal_select_506;
        13:
            signal_mux_160 <= signal_select_505;
        14:
            signal_mux_160 <= signal_select_504;
        default:
            signal_mux_160 <= signal_select_503;
        endcase
    end
    assign signal_xor_5 = signal_mux_160 ^ crossing_bit;
    assign signal_mux_161 = signal_xor_5 ? signal_xor_4 : signal_cat_127;
    assign signal_wire_21 = config$crc_reflect;
    assign signal_mux_162 = signal_wire_21 ? signal_mux_159 : signal_mux_161;
    assign crc_stepped = signal_mux_162 & signal_not_34;
    assign signal_eq_35 = signal_select_685 == signal_const_9;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$2 <= gnd;
        else
            if (ir_load)
                is_opcode$2 <= signal_eq_35;
    end
    assign signal_or_8 = is_opcode$2 | is_opcode$3;
    assign signal_eq_36 = d$shift_count == signal_const_64;
    assign bit_crosses = signal_eq_36 & signal_or_8;
    assign signal_mux_163 = bit_crosses ? crc_stepped : crc_0;
    assign signal_eq_37 = d$sys_op$binary_variant == signal_const_1;
    assign signal_and_49 = is_opcode$7 & signal_eq_37;
    assign crc_next = signal_and_49 ? signal_wire_18 : signal_mux_163;
    assign signal_mux_164 = go ? crc_next : crc_0;
    assign signal_mux_165 = start_0 ? signal_wire_18 : signal_mux_164;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_11 <= signal_const_14;
        else
            signal_reg_11 <= signal_mux_165;
    end
    assign crc_0 = signal_reg_11;
    assign signal_select_519 = signal_mux_168[7:0];
    assign signal_cat_128 = { signal_select_519,
                              signal_const_15 };
    assign signal_select_520 = signal_mux_167[11:0];
    assign signal_cat_129 = { signal_select_520,
                              signal_const_12 };
    assign signal_select_521 = signal_mux_166[13:0];
    assign signal_cat_130 = { signal_select_521,
                              signal_const_17 };
    assign signal_select_522 = d$shift_count[0:0];
    assign signal_mux_166 = signal_select_522 ? signal_const_18 : signal_const_19;
    assign signal_select_523 = d$shift_count[1:1];
    assign signal_mux_167 = signal_select_523 ? signal_cat_130 : signal_mux_166;
    assign signal_select_524 = d$shift_count[2:2];
    assign signal_mux_168 = signal_select_524 ? signal_cat_129 : signal_mux_167;
    assign signal_select_525 = d$shift_count[3:3];
    assign signal_mux_169 = signal_select_525 ? signal_cat_128 : signal_mux_168;
    assign signal_select_526 = d$shift_count[4:4];
    assign signal_mux_170 = signal_select_526 ? signal_const_14 : signal_mux_169;
    assign signal_not_35 = ~ signal_mux_170;
    assign signal_select_527 = signal_mux_174[19:16];
    assign signal_select_528 = signal_mux_174[15:0];
    assign signal_cat_131 = { signal_select_528,
                              signal_select_527 };
    assign signal_select_529 = signal_mux_173[19:8];
    assign signal_select_530 = signal_mux_173[7:0];
    assign signal_cat_132 = { signal_select_530,
                              signal_select_529 };
    assign signal_select_531 = signal_mux_172[19:4];
    assign signal_select_532 = signal_mux_172[3:0];
    assign signal_cat_133 = { signal_select_532,
                              signal_select_531 };
    assign signal_select_533 = signal_mux_171[19:2];
    assign signal_select_534 = signal_mux_171[1:0];
    assign signal_cat_134 = { signal_select_534,
                              signal_select_533 };
    assign signal_select_535 = sample[19:1];
    assign signal_select_536 = sample[0:0];
    assign signal_cat_135 = { signal_select_536,
                              signal_select_535 };
    assign signal_select_537 = signal_wire_26[0:0];
    assign signal_mux_171 = signal_select_537 ? signal_cat_135 : sample;
    assign signal_select_538 = signal_wire_26[1:1];
    assign signal_mux_172 = signal_select_538 ? signal_cat_134 : signal_mux_171;
    assign signal_select_539 = signal_wire_26[2:2];
    assign signal_mux_173 = signal_select_539 ? signal_cat_133 : signal_mux_172;
    assign signal_select_540 = signal_wire_26[3:3];
    assign signal_mux_174 = signal_select_540 ? signal_cat_132 : signal_mux_173;
    assign signal_select_541 = signal_wire_26[4:4];
    assign signal_mux_175 = signal_select_541 ? signal_cat_131 : signal_mux_174;
    assign signal_select_542 = signal_mux_175[15:0];
    assign signal_and_50 = signal_select_542 & signal_not_35;
    always @* begin
        case (d$out_dest$binary_variant)
        0:
            signal_mux_176 <= signal_and_50;
        1:
            signal_mux_176 <= x_0;
        2:
            signal_mux_176 <= y_0;
        3:
            signal_mux_176 <= signal_const_14;
        4:
            signal_mux_176 <= isr_0;
        5:
            signal_mux_176 <= osr_0;
        6:
            signal_mux_176 <= crc_0;
        default:
            signal_mux_176 <= signal_select_489;
        endcase
    end
    assign in_value = signal_mux_176 & mask;
    assign signal_select_543 = signal_mux_179[7:0];
    assign signal_cat_136 = { signal_select_543,
                              signal_const_15 };
    assign signal_select_544 = signal_mux_178[11:0];
    assign signal_cat_137 = { signal_select_544,
                              signal_const_12 };
    assign signal_select_545 = signal_mux_177[13:0];
    assign signal_cat_138 = { signal_select_545,
                              signal_const_17 };
    assign signal_select_546 = isr_0[14:0];
    assign signal_cat_139 = { signal_select_546,
                              signal_const_3 };
    assign signal_select_547 = d$shift_count[0:0];
    assign signal_mux_177 = signal_select_547 ? signal_cat_139 : isr_0;
    assign signal_select_548 = d$shift_count[1:1];
    assign signal_mux_178 = signal_select_548 ? signal_cat_138 : signal_mux_177;
    assign signal_select_549 = d$shift_count[2:2];
    assign signal_mux_179 = signal_select_549 ? signal_cat_137 : signal_mux_178;
    assign signal_select_550 = d$shift_count[3:3];
    assign signal_mux_180 = signal_select_550 ? signal_cat_136 : signal_mux_179;
    assign signal_select_551 = d$shift_count[4:4];
    assign signal_mux_181 = signal_select_551 ? signal_const_14 : signal_mux_180;
    assign signal_or_9 = signal_mux_181 | in_value;
    assign signal_wire_22 = config$in_shift_right;
    assign isr_shifted = signal_wire_22 ? signal_or_7 : signal_or_9;
    assign signal_wire_23 = config$push_threshold;
    assign signal_const_178 = 5'b10000;
    assign signal_select_552 = signal_add_6[4:0];
    assign signal_cat_140 = { gnd,
                              d$shift_count };
    assign signal_eq_38 = d$sys_op$binary_variant == signal_const_81;
    assign signal_and_51 = is_opcode$7 & signal_eq_38;
    assign signal_mux_182 = signal_and_51 ? osr_count_zero : isr_count_0;
    assign signal_eq_39 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_183 = signal_eq_39 ? osr_count_zero : isr_count_0;
    assign signal_eq_40 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_184 = signal_eq_40 ? d$shift_count : isr_count_0;
    assign signal_mux_185 = autopush_now ? osr_count_zero : isr_count_next;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_count_next_value <= isr_count_0;
        1:
            isr_count_next_value <= isr_count_0;
        2:
            isr_count_next_value <= signal_mux_185;
        3:
            isr_count_next_value <= signal_mux_184;
        4:
            isr_count_next_value <= signal_mux_183;
        5:
            isr_count_next_value <= isr_count_0;
        6:
            isr_count_next_value <= isr_count_0;
        default:
            isr_count_next_value <= signal_mux_182;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_12 <= signal_const_61;
        else
            if (go)
                signal_reg_12 <= isr_count_next_value;
    end
    assign isr_count_0 = signal_reg_12;
    assign signal_cat_141 = { gnd,
                              isr_count_0 };
    assign signal_add_6 = signal_cat_141 + signal_cat_140;
    assign signal_const_183 = 6'b010000;
    assign signal_lt_2 = signal_const_183 < signal_add_6;
    assign isr_count_next = signal_lt_2 ? signal_const_178 : signal_select_552;
    assign signal_lt_3 = isr_count_next < signal_wire_23;
    assign signal_not_36 = ~ signal_lt_3;
    assign signal_wire_24 = config$autopush;
    assign autopush_now = signal_wire_24 & signal_not_36;
    assign signal_mux_186 = autopush_now ? signal_const_14 : isr_shifted;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_next <= isr_0;
        1:
            isr_next <= isr_0;
        2:
            isr_next <= signal_mux_186;
        3:
            isr_next <= signal_mux_132;
        4:
            isr_next <= signal_mux_131;
        5:
            isr_next <= isr_0;
        6:
            isr_next <= isr_0;
        default:
            isr_next <= signal_mux_130;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_13 <= signal_const_14;
        else
            if (go)
                signal_reg_13 <= isr_next;
    end
    assign isr_0 = signal_reg_13;
    assign signal_xor_6 = p_0 ^ alu_operand;
    assign signal_sub_7 = p_0 - alu_operand;
    assign signal_add_7 = p_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_187 <= signal_add_7;
        1:
            signal_mux_187 <= signal_sub_7;
        default:
            signal_mux_187 <= signal_xor_6;
        endcase
    end
    assign signal_eq_41 = d$alu_dest$binary_variant == signal_const_89;
    assign signal_mux_188 = signal_eq_41 ? signal_mux_187 : p_0;
    assign signal_cat_142 = { signal_const_11,
                              d$set_value };
    assign signal_eq_42 = d$set_dest$binary_variant == signal_const;
    assign signal_mux_189 = signal_eq_42 ? signal_cat_142 : p_0;
    assign signal_eq_43 = d$mov_dest$binary_variant == signal_const_2;
    assign signal_mux_190 = signal_eq_43 ? mov_value : p_0;
    assign signal_eq_44 = d$out_dest$binary_variant == signal_const_2;
    assign signal_mux_191 = signal_eq_44 ? out_value : p_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            p_next <= p_0;
        1:
            p_next <= p_0;
        2:
            p_next <= p_0;
        3:
            p_next <= signal_mux_191;
        4:
            p_next <= signal_mux_190;
        5:
            p_next <= signal_mux_189;
        6:
            p_next <= signal_mux_188;
        default:
            p_next <= p_0;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_14 <= signal_const_14;
        else
            if (go)
                signal_reg_14 <= p_next;
    end
    assign p_0 = signal_reg_14;
    assign signal_xor_7 = y_0 ^ alu_operand;
    assign signal_sub_8 = y_0 - alu_operand;
    assign signal_add_8 = y_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_192 <= signal_add_8;
        1:
            signal_mux_192 <= signal_sub_8;
        default:
            signal_mux_192 <= signal_xor_7;
        endcase
    end
    assign signal_const_191 = 2'b01;
    assign signal_eq_45 = d$alu_dest$binary_variant == signal_const_191;
    assign signal_mux_193 = signal_eq_45 ? signal_mux_192 : y_0;
    assign signal_cat_143 = { signal_const_11,
                              d$set_value };
    assign signal_eq_46 = d$set_dest$binary_variant == signal_const_9;
    assign signal_mux_194 = signal_eq_46 ? signal_cat_143 : y_0;
    assign signal_eq_47 = d$mov_dest$binary_variant == signal_const_9;
    assign signal_mux_195 = signal_eq_47 ? mov_value : y_0;
    assign signal_eq_48 = d$out_dest$binary_variant == signal_const_9;
    assign signal_mux_196 = signal_eq_48 ? out_value : y_0;
    assign signal_const_196 = 16'b0000000000000001;
    assign signal_sub_9 = y_0 - signal_const_196;
    assign signal_const_197 = 4'b0010;
    assign signal_eq_49 = d$jmp_cond$binary_variant == signal_const_197;
    assign signal_mux_197 = signal_eq_49 ? signal_sub_9 : y_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            y_next <= signal_mux_197;
        1:
            y_next <= y_0;
        2:
            y_next <= y_0;
        3:
            y_next <= signal_mux_196;
        4:
            y_next <= signal_mux_195;
        5:
            y_next <= signal_mux_194;
        6:
            y_next <= signal_mux_193;
        default:
            y_next <= y_0;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_15 <= signal_const_14;
        else
            if (go)
                signal_reg_15 <= y_next;
    end
    assign y_0 = signal_reg_15;
    always @* begin
        case (d$alu_reg$binary_variant)
        0:
            signal_mux_198 <= x_0;
        1:
            signal_mux_198 <= y_0;
        2:
            signal_mux_198 <= p_0;
        3:
            signal_mux_198 <= isr_0;
        default:
            signal_mux_198 <= osr_0;
        endcase
    end
    assign d$alu_reg$binary_variant = word[2:0];
    assign signal_const_198 = 13'b0000000000000;
    assign signal_cat_144 = { signal_const_198,
                              d$alu_reg$binary_variant };
    assign d$alu_is_reg = word[3:3];
    assign alu_operand = d$alu_is_reg ? signal_mux_198 : signal_cat_144;
    assign signal_add_9 = x_0 + alu_operand;
    assign d$alu_op$binary_variant = word[5:4];
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_199 <= signal_add_9;
        1:
            signal_mux_199 <= signal_sub_5;
        default:
            signal_mux_199 <= signal_xor_1;
        endcase
    end
    assign d$alu_dest$binary_variant = word[7:6];
    assign signal_eq_50 = d$alu_dest$binary_variant == signal_const_17;
    assign signal_mux_200 = signal_eq_50 ? signal_mux_199 : x_0;
    assign d$set_value = word[4:0];
    assign signal_cat_145 = { signal_const_11,
                              d$set_value };
    assign d$set_dest$binary_variant = word[7:5];
    assign signal_eq_51 = d$set_dest$binary_variant == signal_const_70;
    assign signal_mux_201 = signal_eq_51 ? signal_cat_145 : x_0;
    assign signal_eq_52 = d$mov_dest$binary_variant == signal_const_70;
    assign signal_mux_202 = signal_eq_52 ? mov_value : x_0;
    assign signal_eq_53 = d$out_dest$binary_variant == signal_const_70;
    assign signal_mux_203 = signal_eq_53 ? out_value : x_0;
    assign signal_sub_10 = x_0 - signal_const_196;
    assign signal_const_205 = 4'b0001;
    assign d$jmp_cond$binary_variant = word[12:9];
    assign signal_eq_54 = d$jmp_cond$binary_variant == signal_const_205;
    assign signal_mux_204 = signal_eq_54 ? signal_sub_10 : x_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            x_next <= signal_mux_204;
        1:
            x_next <= x_0;
        2:
            x_next <= x_0;
        3:
            x_next <= signal_mux_203;
        4:
            x_next <= signal_mux_202;
        5:
            x_next <= signal_mux_201;
        6:
            x_next <= signal_mux_200;
        default:
            x_next <= x_0;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_16 <= signal_const_14;
        else
            if (go)
                signal_reg_16 <= x_next;
    end
    assign x_0 = signal_reg_16;
    assign signal_cat_146 = { signal_const_15,
                              x_0 };
    assign signal_select_553 = signal_mux_207[7:0];
    assign signal_cat_147 = { signal_select_553,
                              signal_const_15 };
    assign signal_select_554 = signal_mux_206[11:0];
    assign signal_cat_148 = { signal_select_554,
                              signal_const_12 };
    assign signal_select_555 = signal_mux_205[13:0];
    assign signal_cat_149 = { signal_select_555,
                              signal_const_17 };
    assign signal_select_556 = signal_wire_25[0:0];
    assign signal_mux_205 = signal_select_556 ? signal_const_18 : signal_const_19;
    assign signal_select_557 = signal_wire_25[1:1];
    assign signal_mux_206 = signal_select_557 ? signal_cat_149 : signal_mux_205;
    assign signal_select_558 = signal_wire_25[2:2];
    assign signal_mux_207 = signal_select_558 ? signal_cat_148 : signal_mux_206;
    assign signal_select_559 = signal_wire_25[3:3];
    assign signal_mux_208 = signal_select_559 ? signal_cat_147 : signal_mux_207;
    assign signal_wire_25 = config$in_count;
    assign signal_select_560 = signal_wire_25[4:4];
    assign signal_mux_209 = signal_select_560 ? signal_const_14 : signal_mux_208;
    assign signal_not_37 = ~ signal_mux_209;
    assign signal_select_561 = signal_mux_213[19:16];
    assign signal_select_562 = signal_mux_213[15:0];
    assign signal_cat_150 = { signal_select_562,
                              signal_select_561 };
    assign signal_select_563 = signal_mux_212[19:8];
    assign signal_select_564 = signal_mux_212[7:0];
    assign signal_cat_151 = { signal_select_564,
                              signal_select_563 };
    assign signal_select_565 = signal_mux_211[19:4];
    assign signal_select_566 = signal_mux_211[3:0];
    assign signal_cat_152 = { signal_select_566,
                              signal_select_565 };
    assign signal_select_567 = signal_mux_210[19:2];
    assign signal_select_568 = signal_mux_210[1:0];
    assign signal_cat_153 = { signal_select_568,
                              signal_select_567 };
    assign signal_select_569 = sample[19:1];
    assign signal_select_570 = sample[0:0];
    assign signal_cat_154 = { signal_select_570,
                              signal_select_569 };
    assign signal_select_571 = signal_wire_26[0:0];
    assign signal_mux_210 = signal_select_571 ? signal_cat_154 : sample;
    assign signal_select_572 = signal_wire_26[1:1];
    assign signal_mux_211 = signal_select_572 ? signal_cat_153 : signal_mux_210;
    assign signal_select_573 = signal_wire_26[2:2];
    assign signal_mux_212 = signal_select_573 ? signal_cat_152 : signal_mux_211;
    assign signal_select_574 = signal_wire_26[3:3];
    assign signal_mux_213 = signal_select_574 ? signal_cat_151 : signal_mux_212;
    assign signal_wire_26 = config$in_base;
    assign signal_select_575 = signal_wire_26[4:4];
    assign signal_mux_214 = signal_select_575 ? signal_cat_150 : signal_mux_213;
    assign signal_select_576 = signal_mux_214[15:0];
    assign signal_and_52 = signal_select_576 & signal_not_37;
    assign signal_cat_155 = { signal_const_15,
                              signal_and_52 };
    assign d$mov_source$binary_variant = word[2:0];
    always @* begin
        case (d$mov_source$binary_variant)
        0:
            mov_value24 <= signal_cat_155;
        1:
            mov_value24 <= signal_cat_146;
        2:
            mov_value24 <= signal_cat_111;
        3:
            mov_value24 <= signal_const_4;
        4:
            mov_value24 <= signal_cat_110;
        5:
            mov_value24 <= signal_cat_109;
        6:
            mov_value24 <= now_0;
        default:
            mov_value24 <= capture_0;
        endcase
    end
    assign signal_select_577 = mov_value24[15:0];
    assign d$mov_op$binary_variant = word[4:3];
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value <= signal_select_577;
        1:
            mov_value <= signal_not_32;
        default:
            mov_value <= signal_cat_108;
        endcase
    end
    assign signal_eq_55 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_215 = signal_eq_55 ? mov_value : osr_0;
    assign signal_select_578 = signal_mux_218[15:8];
    assign signal_cat_156 = { signal_const_15,
                              signal_select_578 };
    assign signal_select_579 = signal_mux_217[15:4];
    assign signal_cat_157 = { signal_const_12,
                              signal_select_579 };
    assign signal_select_580 = signal_mux_216[15:2];
    assign signal_cat_158 = { signal_const_17,
                              signal_select_580 };
    assign signal_select_581 = osr_before[15:1];
    assign signal_cat_159 = { signal_const_3,
                              signal_select_581 };
    assign signal_select_582 = d$shift_count[0:0];
    assign signal_mux_216 = signal_select_582 ? signal_cat_159 : osr_before;
    assign signal_select_583 = d$shift_count[1:1];
    assign signal_mux_217 = signal_select_583 ? signal_cat_158 : signal_mux_216;
    assign signal_select_584 = d$shift_count[2:2];
    assign signal_mux_218 = signal_select_584 ? signal_cat_157 : signal_mux_217;
    assign signal_select_585 = d$shift_count[3:3];
    assign signal_mux_219 = signal_select_585 ? signal_cat_156 : signal_mux_218;
    assign signal_select_586 = d$shift_count[4:4];
    assign signal_mux_220 = signal_select_586 ? signal_const_14 : signal_mux_219;
    assign signal_select_587 = signal_mux_223[7:0];
    assign signal_cat_160 = { signal_select_587,
                              signal_const_15 };
    assign signal_select_588 = signal_mux_222[11:0];
    assign signal_cat_161 = { signal_select_588,
                              signal_const_12 };
    assign signal_select_589 = signal_mux_221[13:0];
    assign signal_cat_162 = { signal_select_589,
                              signal_const_17 };
    assign signal_select_590 = osr_before[14:0];
    assign signal_cat_163 = { signal_select_590,
                              signal_const_3 };
    assign signal_select_591 = d$shift_count[0:0];
    assign signal_mux_221 = signal_select_591 ? signal_cat_163 : osr_before;
    assign signal_select_592 = d$shift_count[1:1];
    assign signal_mux_222 = signal_select_592 ? signal_cat_162 : signal_mux_221;
    assign signal_select_593 = d$shift_count[2:2];
    assign signal_mux_223 = signal_select_593 ? signal_cat_161 : signal_mux_222;
    assign signal_select_594 = d$shift_count[3:3];
    assign signal_mux_224 = signal_select_594 ? signal_cat_160 : signal_mux_223;
    assign signal_select_595 = d$shift_count[4:4];
    assign signal_mux_225 = signal_select_595 ? signal_const_14 : signal_mux_224;
    assign osr_shifted = signal_wire_31 ? signal_mux_220 : signal_mux_225;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            osr_next <= osr_0;
        1:
            osr_next <= osr_0;
        2:
            osr_next <= osr_0;
        3:
            osr_next <= osr_shifted;
        4:
            osr_next <= signal_mux_215;
        5:
            osr_next <= osr_0;
        6:
            osr_next <= osr_0;
        default:
            osr_next <= signal_mux_129;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_17 <= signal_const_14;
        else
            if (go)
                signal_reg_17 <= osr_next;
    end
    assign osr_0 = signal_reg_17;
    assign signal_not_38 = ~ signal_select_596;
    assign signal_and_53 = pulls & signal_not_38;
    assign signal_eq_56 = signal_select_685 == signal_const_81;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$3 <= gnd;
        else
            if (ir_load)
                is_opcode$3 <= signal_eq_56;
    end
    assign signal_and_54 = is_opcode$3 & pull_ok;
    assign signal_or_10 = signal_and_54 | signal_and_53;
    assign signal_and_55 = op_go & signal_or_10;
    assign tx_pop = signal_and_55;
    assign signal_wire_27 = tx$value;
    assign signal_wire_28 = tx$valid;
    host_fifo
        tx
        ( .clock(signal_wire_40),
          .clear(signal_wire_37),
          .push$valid(signal_wire_28),
          .push$value(signal_wire_27),
          .pop(tx_pop),
          .head(signal_inst_1[15:0]),
          .level(signal_inst_1[19:16]),
          .empty(signal_inst_1[20:20]),
          .full(signal_inst_1[21:21]) );
    assign signal_select_596 = signal_inst_1[20:20];
    assign signal_not_39 = ~ signal_select_596;
    assign signal_wire_29 = config$pull_threshold;
    assign d$sys_op$binary_variant = word[2:0];
    assign signal_eq_57 = d$sys_op$binary_variant == signal_const;
    assign signal_eq_58 = signal_select_685 == signal_const_85;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$7 <= gnd;
        else
            if (ir_load)
                is_opcode$7 <= signal_eq_58;
    end
    assign pulls = is_opcode$7 & signal_eq_57;
    assign signal_mux_226 = pulls ? osr_count_zero : osr_count_0;
    assign osr_count_zero = 5'b00000;
    assign d$mov_dest$binary_variant = word[7:5];
    assign signal_eq_59 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_227 = signal_eq_59 ? osr_count_zero : osr_count_0;
    assign signal_select_597 = signal_add_10[4:0];
    assign signal_cat_164 = { gnd,
                              d$shift_count };
    assign osr_count_before = pull_now ? signal_const_61 : osr_count_0;
    assign signal_cat_165 = { gnd,
                              osr_count_before };
    assign signal_add_10 = signal_cat_165 + signal_cat_164;
    assign signal_lt_4 = signal_const_183 < signal_add_10;
    assign osr_count_next = signal_lt_4 ? signal_const_178 : signal_select_597;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            osr_count_next_value <= osr_count_0;
        1:
            osr_count_next_value <= osr_count_0;
        2:
            osr_count_next_value <= osr_count_0;
        3:
            osr_count_next_value <= osr_count_next;
        4:
            osr_count_next_value <= signal_mux_227;
        5:
            osr_count_next_value <= osr_count_0;
        6:
            osr_count_next_value <= osr_count_0;
        default:
            osr_count_next_value <= signal_mux_226;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_18 <= signal_const_178;
        else
            if (go)
                signal_reg_18 <= osr_count_next_value;
    end
    assign osr_count_0 = signal_reg_18;
    assign signal_lt_5 = osr_count_0 < signal_wire_29;
    assign signal_not_40 = ~ signal_lt_5;
    assign signal_wire_30 = config$autopull;
    assign pull_now = signal_wire_30 & signal_not_40;
    assign pull_ok = pull_now & signal_not_39;
    assign osr_before = pull_ok ? signal_select_386 : osr_0;
    assign signal_select_598 = shift_back[0:0];
    assign signal_mux_228 = signal_select_598 ? signal_cat_107 : osr_before;
    assign signal_select_599 = shift_back[1:1];
    assign signal_mux_229 = signal_select_599 ? signal_cat_106 : signal_mux_228;
    assign signal_select_600 = shift_back[2:2];
    assign signal_mux_230 = signal_select_600 ? signal_cat_105 : signal_mux_229;
    assign signal_select_601 = shift_back[3:3];
    assign signal_mux_231 = signal_select_601 ? signal_cat_104 : signal_mux_230;
    assign shift_back = signal_const_178 - d$shift_count;
    assign signal_select_602 = shift_back[4:4];
    assign signal_mux_232 = signal_select_602 ? signal_const_14 : signal_mux_231;
    assign signal_and_56 = signal_mux_232 & mask;
    assign signal_wire_31 = config$out_shift_right;
    assign out_value = signal_wire_31 ? signal_and_43 : signal_and_56;
    assign signal_cat_166 = { signal_const_12,
                              out_value };
    assign signal_select_603 = signal_wire_32[0:0];
    assign signal_mux_233 = signal_select_603 ? signal_cat_103 : signal_cat_166;
    assign signal_select_604 = signal_wire_32[1:1];
    assign signal_mux_234 = signal_select_604 ? signal_cat_102 : signal_mux_233;
    assign signal_select_605 = signal_wire_32[2:2];
    assign signal_mux_235 = signal_select_605 ? signal_cat_101 : signal_mux_234;
    assign signal_select_606 = signal_wire_32[3:3];
    assign signal_mux_236 = signal_select_606 ? signal_cat_100 : signal_mux_235;
    assign signal_select_607 = signal_wire_32[4:4];
    assign signal_mux_237 = signal_select_607 ? signal_cat_99 : signal_mux_236;
    assign signal_and_57 = signal_mux_237 & signal_and_58;
    assign signal_select_608 = signal_mux_246[19:4];
    assign signal_select_609 = signal_mux_246[3:0];
    assign signal_cat_167 = { signal_select_609,
                              signal_select_608 };
    assign signal_select_610 = signal_mux_245[19:12];
    assign signal_select_611 = signal_mux_245[11:0];
    assign signal_cat_168 = { signal_select_611,
                              signal_select_610 };
    assign signal_select_612 = signal_mux_244[19:16];
    assign signal_select_613 = signal_mux_244[15:0];
    assign signal_cat_169 = { signal_select_613,
                              signal_select_612 };
    assign signal_select_614 = signal_mux_243[19:18];
    assign signal_select_615 = signal_mux_243[17:0];
    assign signal_cat_170 = { signal_select_615,
                              signal_select_614 };
    assign signal_select_616 = signal_cat_175[19:19];
    assign signal_select_617 = signal_cat_175[18:0];
    assign signal_cat_171 = { signal_select_617,
                              signal_select_616 };
    assign signal_select_618 = signal_mux_240[7:0];
    assign signal_cat_172 = { signal_select_618,
                              signal_const_15 };
    assign signal_select_619 = signal_mux_239[11:0];
    assign signal_cat_173 = { signal_select_619,
                              signal_const_12 };
    assign signal_select_620 = signal_mux_238[13:0];
    assign signal_cat_174 = { signal_select_620,
                              signal_const_17 };
    assign signal_select_621 = d$shift_count[0:0];
    assign signal_mux_238 = signal_select_621 ? signal_const_18 : signal_const_19;
    assign signal_select_622 = d$shift_count[1:1];
    assign signal_mux_239 = signal_select_622 ? signal_cat_174 : signal_mux_238;
    assign signal_select_623 = d$shift_count[2:2];
    assign signal_mux_240 = signal_select_623 ? signal_cat_173 : signal_mux_239;
    assign signal_select_624 = d$shift_count[3:3];
    assign signal_mux_241 = signal_select_624 ? signal_cat_172 : signal_mux_240;
    assign d$shift_count = word[4:0];
    assign signal_select_625 = d$shift_count[4:4];
    assign signal_mux_242 = signal_select_625 ? signal_const_14 : signal_mux_241;
    assign signal_not_41 = ~ signal_mux_242;
    assign signal_cat_175 = { signal_const_12,
                              signal_not_41 };
    assign signal_select_626 = signal_wire_32[0:0];
    assign signal_mux_243 = signal_select_626 ? signal_cat_171 : signal_cat_175;
    assign signal_select_627 = signal_wire_32[1:1];
    assign signal_mux_244 = signal_select_627 ? signal_cat_170 : signal_mux_243;
    assign signal_select_628 = signal_wire_32[2:2];
    assign signal_mux_245 = signal_select_628 ? signal_cat_169 : signal_mux_244;
    assign signal_select_629 = signal_wire_32[3:3];
    assign signal_mux_246 = signal_select_629 ? signal_cat_168 : signal_mux_245;
    assign signal_wire_32 = config$out_base;
    assign signal_select_630 = signal_wire_32[4:4];
    assign signal_mux_247 = signal_select_630 ? signal_cat_167 : signal_mux_246;
    assign signal_and_58 = signal_mux_247 & signal_const_93;
    assign signal_not_42 = ~ signal_and_58;
    assign signal_and_59 = pin_dir_base & signal_not_42;
    assign signal_or_11 = signal_and_59 | signal_and_57;
    assign d$out_dest$binary_variant = word[7:5];
    assign signal_eq_60 = d$out_dest$binary_variant == signal_const;
    assign signal_mux_248 = signal_eq_60 ? signal_or_11 : pin_dir_base;
    assign signal_select_631 = signal_mux_252[19:4];
    assign signal_select_632 = signal_mux_252[3:0];
    assign signal_cat_176 = { signal_select_632,
                              signal_select_631 };
    assign signal_select_633 = signal_mux_251[19:12];
    assign signal_select_634 = signal_mux_251[11:0];
    assign signal_cat_177 = { signal_select_634,
                              signal_select_633 };
    assign signal_select_635 = signal_mux_250[19:16];
    assign signal_select_636 = signal_mux_250[15:0];
    assign signal_cat_178 = { signal_select_636,
                              signal_select_635 };
    assign signal_select_637 = signal_mux_249[19:18];
    assign signal_select_638 = signal_mux_249[17:0];
    assign signal_cat_179 = { signal_select_638,
                              signal_select_637 };
    assign signal_select_639 = signal_cat_183[19:19];
    assign signal_select_640 = signal_cat_183[18:0];
    assign signal_cat_180 = { signal_select_640,
                              signal_select_639 };
    assign signal_select_641 = signal_select_643[4:3];
    assign signal_select_642 = signal_select_643[4:3];
    assign signal_select_643 = word[12:8];
    assign signal_select_644 = signal_select_643[4:4];
    assign signal_cat_181 = { gnd,
                              signal_select_644 };
    always @* begin
        case (signal_wire_33)
        0:
            d$side_set <= signal_const_17;
        1:
            d$side_set <= signal_cat_181;
        2:
            d$side_set <= signal_select_642;
        default:
            d$side_set <= signal_select_641;
        endcase
    end
    assign signal_cat_182 = { signal_const_42,
                              d$side_set };
    assign signal_cat_183 = { signal_const_12,
                              signal_cat_182 };
    assign signal_select_645 = signal_wire_34[0:0];
    assign signal_mux_249 = signal_select_645 ? signal_cat_180 : signal_cat_183;
    assign signal_select_646 = signal_wire_34[1:1];
    assign signal_mux_250 = signal_select_646 ? signal_cat_179 : signal_mux_249;
    assign signal_select_647 = signal_wire_34[2:2];
    assign signal_mux_251 = signal_select_647 ? signal_cat_178 : signal_mux_250;
    assign signal_select_648 = signal_wire_34[3:3];
    assign signal_mux_252 = signal_select_648 ? signal_cat_177 : signal_mux_251;
    assign signal_select_649 = signal_wire_34[4:4];
    assign signal_mux_253 = signal_select_649 ? signal_cat_176 : signal_mux_252;
    assign signal_and_60 = signal_mux_253 & signal_and_61;
    assign signal_select_650 = signal_mux_262[19:4];
    assign signal_select_651 = signal_mux_262[3:0];
    assign signal_cat_184 = { signal_select_651,
                              signal_select_650 };
    assign signal_select_652 = signal_mux_261[19:12];
    assign signal_select_653 = signal_mux_261[11:0];
    assign signal_cat_185 = { signal_select_653,
                              signal_select_652 };
    assign signal_select_654 = signal_mux_260[19:16];
    assign signal_select_655 = signal_mux_260[15:0];
    assign signal_cat_186 = { signal_select_655,
                              signal_select_654 };
    assign signal_select_656 = signal_mux_259[19:18];
    assign signal_select_657 = signal_mux_259[17:0];
    assign signal_cat_187 = { signal_select_657,
                              signal_select_656 };
    assign signal_select_658 = signal_cat_193[19:19];
    assign signal_select_659 = signal_cat_193[18:0];
    assign signal_cat_188 = { signal_select_659,
                              signal_select_658 };
    assign signal_select_660 = signal_mux_256[7:0];
    assign signal_cat_189 = { signal_select_660,
                              signal_const_15 };
    assign signal_select_661 = signal_mux_255[11:0];
    assign signal_cat_190 = { signal_select_661,
                              signal_const_12 };
    assign signal_select_662 = signal_mux_254[13:0];
    assign signal_cat_191 = { signal_select_662,
                              signal_const_17 };
    assign signal_select_663 = signal_cat_192[0:0];
    assign signal_mux_254 = signal_select_663 ? signal_const_18 : signal_const_19;
    assign signal_select_664 = signal_cat_192[1:1];
    assign signal_mux_255 = signal_select_664 ? signal_cat_191 : signal_mux_254;
    assign signal_select_665 = signal_cat_192[2:2];
    assign signal_mux_256 = signal_select_665 ? signal_cat_190 : signal_mux_255;
    assign signal_select_666 = signal_cat_192[3:3];
    assign signal_mux_257 = signal_select_666 ? signal_cat_189 : signal_mux_256;
    assign signal_wire_33 = config$side_set_count;
    assign signal_cat_192 = { signal_const_21,
                              signal_wire_33 };
    assign signal_select_667 = signal_cat_192[4:4];
    assign signal_mux_258 = signal_select_667 ? signal_const_14 : signal_mux_257;
    assign signal_not_43 = ~ signal_mux_258;
    assign signal_cat_193 = { signal_const_12,
                              signal_not_43 };
    assign signal_select_668 = signal_wire_34[0:0];
    assign signal_mux_259 = signal_select_668 ? signal_cat_188 : signal_cat_193;
    assign signal_select_669 = signal_wire_34[1:1];
    assign signal_mux_260 = signal_select_669 ? signal_cat_187 : signal_mux_259;
    assign signal_select_670 = signal_wire_34[2:2];
    assign signal_mux_261 = signal_select_670 ? signal_cat_186 : signal_mux_260;
    assign signal_select_671 = signal_wire_34[3:3];
    assign signal_mux_262 = signal_select_671 ? signal_cat_185 : signal_mux_261;
    assign signal_wire_34 = config$side_set_base;
    assign signal_select_672 = signal_wire_34[4:4];
    assign signal_mux_263 = signal_select_672 ? signal_cat_184 : signal_mux_262;
    assign signal_and_61 = signal_mux_263 & signal_const_93;
    assign signal_not_44 = ~ signal_and_61;
    assign signal_and_62 = pin_dir_0 & signal_not_44;
    assign pin_dir_side = signal_and_62 | signal_and_60;
    assign signal_wire_35 = config$side_set_pindirs;
    assign pin_dir_base = signal_wire_35 ? pin_dir_side : pin_dir_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            pin_dir_next <= pin_dir_base;
        1:
            pin_dir_next <= pin_dir_base;
        2:
            pin_dir_next <= pin_dir_base;
        3:
            pin_dir_next <= signal_mux_248;
        4:
            pin_dir_next <= signal_mux_128;
        5:
            pin_dir_next <= signal_mux_112;
        6:
            pin_dir_next <= pin_dir_base;
        default:
            pin_dir_next <= pin_dir_base;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_19 <= signal_const_10;
        else
            if (op_go)
                signal_reg_19 <= pin_dir_next;
    end
    assign pin_dir_0 = signal_reg_19;
    assign signal_select_673 = pin_dir_0[19:19];
    assign signal_mux_264 = signal_select_673 ? signal_select_294 : signal_select_295;
    assign sample = { signal_mux_264,
                      signal_mux_96,
                      signal_mux_95,
                      signal_mux_94,
                      signal_mux_93,
                      signal_mux_92,
                      signal_mux_91,
                      signal_mux_90,
                      signal_select_272,
                      signal_select_271,
                      signal_select_270,
                      signal_select_269,
                      signal_select_268,
                      signal_select_267,
                      signal_select_266,
                      signal_select_265,
                      signal_select_264,
                      signal_select_263,
                      signal_select_262,
                      signal_select_261 };
    assign signal_select_674 = sample[0:0];
    assign d$wait_index = word[4:0];
    always @* begin
        case (d$wait_index)
        0:
            wait_pin_cur <= signal_select_674;
        1:
            wait_pin_cur <= signal_select_260;
        2:
            wait_pin_cur <= signal_select_259;
        3:
            wait_pin_cur <= signal_select_258;
        4:
            wait_pin_cur <= signal_select_257;
        5:
            wait_pin_cur <= signal_select_256;
        6:
            wait_pin_cur <= signal_select_255;
        7:
            wait_pin_cur <= signal_select_254;
        8:
            wait_pin_cur <= signal_select_253;
        9:
            wait_pin_cur <= signal_select_252;
        10:
            wait_pin_cur <= signal_select_251;
        11:
            wait_pin_cur <= signal_select_250;
        12:
            wait_pin_cur <= signal_select_249;
        13:
            wait_pin_cur <= signal_select_248;
        14:
            wait_pin_cur <= signal_select_247;
        15:
            wait_pin_cur <= signal_select_246;
        16:
            wait_pin_cur <= signal_select_245;
        17:
            wait_pin_cur <= signal_select_244;
        18:
            wait_pin_cur <= signal_select_243;
        default:
            wait_pin_cur <= signal_select_242;
        endcase
    end
    assign signal_eq_61 = wait_pin_cur == d$wait_polarity;
    assign d$wait_source$binary_variant = word[6:5];
    always @* begin
        case (d$wait_source$binary_variant)
        0:
            wait_ready <= signal_eq_61;
        1:
            wait_ready <= signal_and_36;
        2:
            wait_ready <= deadline_ready;
        default:
            wait_ready <= signal_mux_84;
        endcase
    end
    assign signal_not_45 = ~ wait_ready;
    assign gnd = 1'b0;
    assign signal_eq_62 = signal_select_685 == signal_const_70;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$1 <= gnd;
        else
            if (ir_load)
                is_opcode$1 <= signal_eq_62;
    end
    assign wait_holds = is_opcode$1 & signal_not_45;
    assign signal_not_46 = ~ wait_holds;
    assign signal_eq_63 = signal_select_685 == signal_const_21;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            is_opcode$0 <= vdd;
        else
            if (ir_load)
                is_opcode$0 <= signal_eq_63;
    end
    assign signal_not_47 = ~ is_opcode$0;
    assign op_go = go & signal_not_47;
    assign advance = op_go & signal_not_46;
    assign signal_or_12 = advance | refill;
    assign ir_load = signal_or_12;
    assign signal_select_675 = signal_wire_41[7:3];
    assign signal_eq_64 = signal_select_675 == signal_const_61;
    assign signal_select_676 = signal_wire_41[2:0];
    assign signal_lt_6 = signal_select_676 < signal_const_1;
    assign signal_select_677 = signal_wire_41[3:3];
    assign signal_not_48 = ~ signal_select_677;
    assign signal_or_13 = signal_not_48 | signal_lt_6;
    assign signal_select_678 = signal_wire_41[5:4];
    assign signal_lt_7 = signal_select_678 < signal_const_84;
    assign signal_and_63 = signal_lt_7 & signal_or_13;
    assign signal_select_679 = signal_wire_41[7:5];
    assign signal_lt_8 = signal_select_679 < signal_const_1;
    assign signal_select_680 = signal_wire_41[4:3];
    assign signal_lt_9 = signal_select_680 < signal_const_84;
    assign signal_lt_10 = signal_const_178 < signal_select_681;
    assign signal_not_49 = ~ signal_lt_10;
    assign signal_select_681 = signal_wire_41[4:0];
    assign signal_lt_11 = signal_select_681 < signal_const_64;
    assign signal_not_50 = ~ signal_lt_11;
    assign signal_and_64 = signal_not_50 & signal_not_49;
    assign signal_eq_65 = signal_select_682 == signal_const_61;
    assign signal_eq_66 = signal_select_682 == signal_const_61;
    assign signal_const_267 = 5'b10100;
    assign signal_lt_12 = signal_select_682 < signal_const_267;
    assign signal_select_682 = signal_wire_41[4:0];
    assign signal_lt_13 = signal_select_682 < signal_const_267;
    assign signal_select_683 = signal_wire_41[6:5];
    always @* begin
        case (signal_select_683)
        0:
            signal_mux_265 <= signal_lt_13;
        1:
            signal_mux_265 <= signal_lt_12;
        2:
            signal_mux_265 <= signal_eq_66;
        default:
            signal_mux_265 <= signal_eq_65;
        endcase
    end
    assign signal_const_269 = 4'b1100;
    assign signal_select_684 = signal_wire_41[12:9];
    assign signal_lt_14 = signal_select_684 < signal_const_269;
    assign signal_select_685 = signal_wire_41[15:13];
    always @* begin
        case (signal_select_685)
        0:
            signal_mux_266 <= signal_lt_14;
        1:
            signal_mux_266 <= signal_mux_265;
        2:
            signal_mux_266 <= signal_and_64;
        3:
            signal_mux_266 <= signal_and_64;
        4:
            signal_mux_266 <= signal_lt_9;
        5:
            signal_mux_266 <= signal_lt_8;
        6:
            signal_mux_266 <= signal_and_63;
        default:
            signal_mux_266 <= signal_eq_64;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            decode_ok_0 <= vdd;
        else
            if (ir_load)
                decode_ok_0 <= signal_mux_266;
    end
    assign go = issue & decode_ok_0;
    assign jmp_go = go & is_opcode$0;
    assign signal_mux_267 = jmp_go ? signal_const_64 : signal_mux_82;
    assign stall_next = start_0 ? signal_const_61 : signal_mux_267;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_20 <= signal_const_61;
        else
            signal_reg_20 <= stall_next;
    end
    assign stall_0 = signal_reg_20;
    assign signal_eq_67 = stall_0 == signal_const_61;
    assign signal_not_51 = ~ halted_0;
    assign signal_and_65 = signal_not_51 & signal_eq_67;
    assign issue = signal_and_65 & signal_not_20;
    assign signal_and_66 = issue & signal_not_19;
    assign signal_mux_268 = signal_and_66 ? vdd : signal_mux_80;
    assign signal_wire_36 = stop;
    assign signal_mux_269 = signal_wire_36 ? vdd : signal_mux_268;
    assign signal_wire_37 = clear;
    assign signal_wire_38 = start;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            start_0 <= signal_const_3;
        else
            start_0 <= signal_wire_38;
    end
    assign halted_next = start_0 ? gnd : signal_mux_269;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_21 <= vdd;
        else
            signal_reg_21 <= halted_next;
    end
    assign halted_0 = signal_reg_21;
    assign signal_wire_39 = program_write$valid;
    assign program_write = signal_wire_39 & halted_0;
    assign vdd = 1'b1;
    assign signal_wire_40 = clock;
    sram_macro
        sram_macro
        ( .clock(signal_wire_40),
          .men(vdd),
          .wen(program_write),
          .ren(vdd),
          .addr(signal_mux_79),
          .din(signal_wire_2),
          .bm(signal_const_19),
          .dout(signal_inst_2[15:0]) );
    assign signal_wire_41 = signal_inst_2;
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            word <= signal_const_14;
        else
            if (ir_load)
                word <= signal_wire_41;
    end
    assign d$opcode$binary_variant = word[15:13];
    always @* begin
        case (d$opcode$binary_variant)
        0:
            pin_out_next <= pin_out_base;
        1:
            pin_out_next <= pin_out_base;
        2:
            pin_out_next <= pin_out_base;
        3:
            pin_out_next <= signal_mux_49;
        4:
            pin_out_next <= signal_mux_33;
        5:
            pin_out_next <= signal_mux_17;
        6:
            pin_out_next <= pin_out_base;
        default:
            pin_out_next <= pin_out_base;
        endcase
    end
    always @(posedge signal_wire_40) begin
        if (signal_wire_37)
            signal_reg_22 <= signal_const_10;
        else
            if (op_go)
                signal_reg_22 <= pin_out_next;
    end
    assign pin_out_0 = signal_reg_22;
    assign d$alu_imm = d$alu_reg$binary_variant;
    assign d$in_source$binary_variant = d$out_dest$binary_variant;
    assign pin_out = pin_out_0;
    assign pin_dir = pin_dir_0;
    assign pc = pc_0;
    assign x = x_0;
    assign y = y_0;
    assign p = p_0;
    assign t = t_0;
    assign osr = osr_0;
    assign osr_count = osr_count_0;
    assign isr = isr_0;
    assign isr_count = isr_count_0;
    assign now = now_0;
    assign stall = stall_0;
    assign halted = halted_0;
    assign irq = irq_0;
    assign fault$underflow = signal_reg_3;
    assign fault$overflow = signal_reg_2;
    assign fault$missed_deadline = signal_reg_1;
    assign fault$decode = signal_reg;
    assign capture = capture_0;
    assign capture_armed = capture_armed_0;
    assign tx_level = signal_select_2;
    assign rx_level = signal_select_1;
    assign rx_head = signal_select;
    assign instruction = word;
    assign decode_ok = decode_ok_0;
    assign opcode_onehot = signal_cat;
    assign crc = crc_0;
    assign stuff_run = stuff_run_0;

endmodule
module host_spi (
    clock,
    clear,
    sck,
    mosi,
    cs_n,
    tx_byte,
    miso,
    rx_byte,
    rx_valid,
    frame_start,
    frame_end
);

    input clock;
    input clear;
    input sck;
    input mosi;
    input cs_n;
    input [7:0] tx_byte;
    output miso;
    output [7:0] rx_byte;
    output rx_valid;
    output frame_start;
    output frame_end;

    wire signal_const;
    reg signal_reg;
    wire signal_not;
    wire frame_end_0;
    reg rx_valid_0;
    wire [2:0] signal_const_2;
    wire signal_eq;
    wire last_bit;
    wire [7:0] signal_const_3;
    wire signal_wire;
    reg signal_reg_1;
    reg mosi_0;
    wire [6:0] signal_select;
    wire [7:0] signal_cat;
    wire [7:0] signal_mux;
    wire [7:0] signal_wire_1;
    reg [7:0] shift_in;
    wire [6:0] signal_select_1;
    wire [7:0] signal_cat_1;
    reg [7:0] rx_byte_0;
    wire [7:0] signal_wire_2;
    wire gnd;
    wire [6:0] signal_select_2;
    wire [7:0] signal_cat_2;
    wire [7:0] signal_mux_1;
    wire [2:0] signal_const_8;
    wire [2:0] signal_const_11;
    wire [2:0] signal_add;
    reg signal_reg_2;
    wire signal_not_1;
    wire signal_and;
    wire sck_rise;
    wire [2:0] signal_mux_2;
    wire [2:0] signal_mux_3;
    wire [2:0] signal_wire_3;
    reg [2:0] count;
    wire signal_eq_1;
    reg signal_reg_3;
    wire signal_wire_4;
    reg signal_reg_4;
    reg sck_0;
    wire signal_not_2;
    wire signal_and_1;
    wire sck_fall;
    wire signal_and_2;
    reg signal_reg_5;
    wire signal_not_3;
    wire frame_start_0;
    wire signal_or;
    wire [7:0] signal_mux_4;
    wire [7:0] signal_wire_5;
    reg [7:0] shift_out;
    wire signal_select_3;
    wire signal_wire_6;
    wire signal_wire_7;
    wire signal_wire_8;
    reg signal_reg_6;
    reg signal_reg_7;
    wire selected;
    wire signal_and_3;
    assign signal_const = 1'b0;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg <= signal_const;
        else
            signal_reg <= selected;
    end
    assign signal_not = ~ selected;
    assign frame_end_0 = signal_not & signal_reg;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            rx_valid_0 <= signal_const;
        else
            rx_valid_0 <= last_bit;
    end
    assign signal_const_2 = 3'b111;
    assign signal_eq = count == signal_const_2;
    assign last_bit = sck_rise & signal_eq;
    assign signal_const_3 = 8'b00000000;
    assign signal_wire = mosi;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg_1 <= signal_const;
        else
            signal_reg_1 <= signal_wire;
    end
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            mosi_0 <= signal_const;
        else
            mosi_0 <= signal_reg_1;
    end
    assign signal_select = shift_in[6:0];
    assign signal_cat = { signal_select,
                          mosi_0 };
    assign signal_mux = sck_rise ? signal_cat : shift_in;
    assign signal_wire_1 = signal_mux;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            shift_in <= signal_const_3;
        else
            shift_in <= signal_wire_1;
    end
    assign signal_select_1 = shift_in[6:0];
    assign signal_cat_1 = { signal_select_1,
                            mosi_0 };
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            rx_byte_0 <= signal_const_3;
        else
            if (last_bit)
                rx_byte_0 <= signal_cat_1;
    end
    assign signal_wire_2 = tx_byte;
    assign gnd = 1'b0;
    assign signal_select_2 = shift_out[6:0];
    assign signal_cat_2 = { signal_select_2,
                            gnd };
    assign signal_mux_1 = sck_fall ? signal_cat_2 : shift_out;
    assign signal_const_8 = 3'b000;
    assign signal_const_11 = 3'b001;
    assign signal_add = count + signal_const_11;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg_2 <= signal_const;
        else
            signal_reg_2 <= sck_0;
    end
    assign signal_not_1 = ~ signal_reg_2;
    assign signal_and = selected & sck_0;
    assign sck_rise = signal_and & signal_not_1;
    assign signal_mux_2 = sck_rise ? signal_add : count;
    assign signal_mux_3 = frame_start_0 ? signal_const_8 : signal_mux_2;
    assign signal_wire_3 = signal_mux_3;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            count <= signal_const_8;
        else
            count <= signal_wire_3;
    end
    assign signal_eq_1 = count == signal_const_8;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg_3 <= signal_const;
        else
            signal_reg_3 <= sck_0;
    end
    assign signal_wire_4 = sck;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg_4 <= signal_const;
        else
            signal_reg_4 <= signal_wire_4;
    end
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            sck_0 <= signal_const;
        else
            sck_0 <= signal_reg_4;
    end
    assign signal_not_2 = ~ sck_0;
    assign signal_and_1 = selected & signal_not_2;
    assign sck_fall = signal_and_1 & signal_reg_3;
    assign signal_and_2 = sck_fall & signal_eq_1;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg_5 <= signal_const;
        else
            signal_reg_5 <= selected;
    end
    assign signal_not_3 = ~ signal_reg_5;
    assign frame_start_0 = selected & signal_not_3;
    assign signal_or = frame_start_0 | signal_and_2;
    assign signal_mux_4 = signal_or ? signal_wire_2 : signal_mux_1;
    assign signal_wire_5 = signal_mux_4;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            shift_out <= signal_const_3;
        else
            shift_out <= signal_wire_5;
    end
    assign signal_select_3 = shift_out[7:7];
    assign signal_wire_6 = clear;
    assign signal_wire_7 = clock;
    assign signal_wire_8 = cs_n;
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg_6 <= signal_const;
        else
            signal_reg_6 <= signal_wire_8;
    end
    always @(posedge signal_wire_7) begin
        if (signal_wire_6)
            signal_reg_7 <= signal_const;
        else
            signal_reg_7 <= signal_reg_6;
    end
    assign selected = ~ signal_reg_7;
    assign signal_and_3 = selected & signal_select_3;
    assign miso = signal_and_3;
    assign rx_byte = rx_byte_0;
    assign rx_valid = rx_valid_0;
    assign frame_start = frame_start_0;
    assign frame_end = frame_end_0;

endmodule
module host_port (
    clock,
    clear,
    sck,
    mosi,
    cs_n,
    status$pc,
    status$now,
    status$capture,
    status$halted,
    status$irq,
    status$fault$underflow,
    status$fault$overflow,
    status$fault$missed_deadline,
    status$fault$decode,
    status$tx_level,
    status$rx_level,
    status$rx_head,
    miso,
    start,
    clear_irq,
    stop,
    program_write$valid,
    program_write$addr,
    program_write$data,
    tx$valid,
    tx$value,
    rx_pop,
    config$side_set_count,
    config$side_set_base,
    config$side_set_pindirs,
    config$in_base,
    config$in_count,
    config$out_base,
    config$out_count,
    config$set_base,
    config$set_count,
    config$jmp_pin,
    config$capture_pin,
    config$capture_rising,
    config$in_shift_right,
    config$out_shift_right,
    config$autopush,
    config$push_threshold,
    config$autopull,
    config$pull_threshold,
    config$crc_width,
    config$crc_poly,
    config$crc_init,
    config$crc_reflect,
    config$stuff_threshold,
    config$stuff_level,
    config$wrap_bottom,
    config$wrap_top
);

    input clock;
    input clear;
    input sck;
    input mosi;
    input cs_n;
    input [8:0] status$pc;
    input [23:0] status$now;
    input [23:0] status$capture;
    input status$halted;
    input status$irq;
    input status$fault$underflow;
    input status$fault$overflow;
    input status$fault$missed_deadline;
    input status$fault$decode;
    input [3:0] status$tx_level;
    input [3:0] status$rx_level;
    input [15:0] status$rx_head;
    output miso;
    output start;
    output clear_irq;
    output stop;
    output program_write$valid;
    output [8:0] program_write$addr;
    output [15:0] program_write$data;
    output tx$valid;
    output [15:0] tx$value;
    output rx_pop;
    output [1:0] config$side_set_count;
    output [4:0] config$side_set_base;
    output config$side_set_pindirs;
    output [4:0] config$in_base;
    output [4:0] config$in_count;
    output [4:0] config$out_base;
    output [4:0] config$out_count;
    output [4:0] config$set_base;
    output [2:0] config$set_count;
    output [4:0] config$jmp_pin;
    output [4:0] config$capture_pin;
    output config$capture_rising;
    output config$in_shift_right;
    output config$out_shift_right;
    output config$autopush;
    output [4:0] config$push_threshold;
    output config$autopull;
    output [4:0] config$pull_threshold;
    output [4:0] config$crc_width;
    output [15:0] config$crc_poly;
    output [15:0] config$crc_init;
    output config$crc_reflect;
    output [4:0] config$stuff_threshold;
    output config$stuff_level;
    output [8:0] config$wrap_bottom;
    output [8:0] config$wrap_top;

    wire [6:0] signal_const;
    wire signal_eq;
    wire signal_and;
    wire [6:0] signal_const_1;
    wire signal_eq_1;
    wire signal_and_1;
    wire [6:0] signal_const_2;
    wire signal_eq_2;
    wire signal_and_2;
    wire signal_select;
    wire [6:0] signal_const_3;
    wire signal_eq_3;
    wire signal_and_3;
    wire signal_and_4;
    wire signal_select_1;
    wire signal_eq_4;
    wire signal_and_5;
    wire signal_and_6;
    wire signal_select_2;
    wire signal_eq_5;
    wire signal_and_7;
    wire signal_and_8;
    wire [7:0] signal_select_3;
    wire [15:0] signal_const_6;
    wire [15:0] signal_cat;
    wire [15:0] signal_cat_1;
    wire [14:0] signal_const_12;
    wire [15:0] signal_cat_2;
    wire [10:0] signal_const_14;
    wire [15:0] signal_cat_3;
    wire [15:0] signal_cat_4;
    wire [15:0] signal_cat_5;
    wire [15:0] signal_cat_6;
    wire [15:0] signal_cat_7;
    wire [15:0] signal_cat_8;
    wire [15:0] signal_cat_9;
    wire [15:0] signal_cat_10;
    wire [15:0] signal_cat_11;
    wire [15:0] signal_cat_12;
    wire [15:0] signal_cat_13;
    wire [15:0] signal_cat_14;
    wire [12:0] signal_const_40;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_cat_16;
    wire [15:0] signal_cat_17;
    wire [15:0] signal_cat_18;
    wire [15:0] signal_cat_19;
    wire [15:0] signal_cat_20;
    wire [15:0] signal_cat_21;
    wire [15:0] signal_cat_22;
    wire [13:0] signal_const_56;
    wire [15:0] signal_cat_23;
    wire [15:0] signal_cat_24;
    wire [7:0] signal_select_4;
    wire [7:0] signal_const_61;
    wire [15:0] signal_cat_25;
    wire [15:0] signal_select_5;
    wire [7:0] signal_select_6;
    wire [15:0] signal_cat_26;
    wire [15:0] signal_select_7;
    wire [15:0] signal_cat_27;
    reg [15:0] read_value;
    wire [8:0] signal_const_71;
    wire [8:0] signal_select_8;
    wire [6:0] signal_const_72;
    wire signal_eq_6;
    wire [8:0] signal_mux;
    wire [8:0] signal_mux_1;
    wire [8:0] signal_wire;
    reg [8:0] signal_reg;
    wire [15:0] signal_cat_28;
    wire [8:0] signal_select_9;
    wire [6:0] signal_const_76;
    wire signal_eq_7;
    wire [8:0] signal_mux_2;
    wire [8:0] signal_mux_3;
    wire [8:0] signal_wire_1;
    reg [8:0] signal_reg_1;
    wire [15:0] signal_cat_29;
    wire signal_const_79;
    wire signal_select_10;
    wire [6:0] signal_const_80;
    wire signal_eq_8;
    wire signal_mux_4;
    wire signal_mux_5;
    wire signal_wire_2;
    reg signal_reg_2;
    wire [15:0] signal_cat_30;
    wire [4:0] signal_const_83;
    wire [4:0] signal_select_11;
    wire [6:0] signal_const_84;
    wire signal_eq_9;
    wire [4:0] signal_mux_6;
    wire [4:0] signal_mux_7;
    wire [4:0] signal_wire_3;
    reg [4:0] signal_reg_3;
    wire [15:0] signal_cat_31;
    wire signal_select_12;
    wire [6:0] signal_const_88;
    wire signal_eq_10;
    wire signal_mux_8;
    wire signal_mux_9;
    wire signal_wire_4;
    reg signal_reg_4;
    wire [15:0] signal_cat_32;
    wire [6:0] signal_const_92;
    wire signal_eq_11;
    wire [15:0] signal_mux_10;
    wire [15:0] signal_mux_11;
    wire [15:0] signal_wire_5;
    reg [15:0] signal_reg_5;
    wire [6:0] signal_const_95;
    wire signal_eq_12;
    wire [15:0] signal_mux_12;
    wire [15:0] signal_mux_13;
    wire [15:0] signal_wire_6;
    reg [15:0] signal_reg_6;
    wire [4:0] signal_select_13;
    wire [6:0] signal_const_98;
    wire signal_eq_13;
    wire [4:0] signal_mux_14;
    wire [4:0] signal_mux_15;
    wire [4:0] signal_wire_7;
    reg [4:0] signal_reg_7;
    wire [15:0] signal_cat_33;
    wire [4:0] signal_select_14;
    wire [6:0] signal_const_102;
    wire signal_eq_14;
    wire [4:0] signal_mux_16;
    wire [4:0] signal_mux_17;
    wire [4:0] signal_wire_8;
    reg [4:0] signal_reg_8;
    wire [15:0] signal_cat_34;
    wire signal_select_15;
    wire [6:0] signal_const_106;
    wire signal_eq_15;
    wire signal_mux_18;
    wire signal_mux_19;
    wire signal_wire_9;
    reg signal_reg_9;
    wire [15:0] signal_cat_35;
    wire [4:0] signal_select_16;
    wire [6:0] signal_const_110;
    wire signal_eq_16;
    wire [4:0] signal_mux_20;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_wire_10;
    reg [4:0] signal_reg_10;
    wire [15:0] signal_cat_36;
    wire signal_select_17;
    wire [6:0] signal_const_114;
    wire signal_eq_17;
    wire signal_mux_22;
    wire signal_mux_23;
    wire signal_wire_11;
    reg signal_reg_11;
    wire [15:0] signal_cat_37;
    wire signal_select_18;
    wire [6:0] signal_const_118;
    wire signal_eq_18;
    wire signal_mux_24;
    wire signal_mux_25;
    wire signal_wire_12;
    reg signal_reg_12;
    wire [15:0] signal_cat_38;
    wire signal_select_19;
    wire [6:0] signal_const_122;
    wire signal_eq_19;
    wire signal_mux_26;
    wire signal_mux_27;
    wire signal_wire_13;
    reg signal_reg_13;
    wire [15:0] signal_cat_39;
    wire signal_select_20;
    wire [6:0] signal_const_126;
    wire signal_eq_20;
    wire signal_mux_28;
    wire signal_mux_29;
    wire signal_wire_14;
    reg signal_reg_14;
    wire [15:0] signal_cat_40;
    wire [4:0] signal_select_21;
    wire [6:0] signal_const_130;
    wire signal_eq_21;
    wire [4:0] signal_mux_30;
    wire [4:0] signal_mux_31;
    wire [4:0] signal_wire_15;
    reg [4:0] signal_reg_15;
    wire [15:0] signal_cat_41;
    wire [4:0] signal_select_22;
    wire [6:0] signal_const_134;
    wire signal_eq_22;
    wire [4:0] signal_mux_32;
    wire [4:0] signal_mux_33;
    wire [4:0] signal_wire_16;
    reg [4:0] signal_reg_16;
    wire [15:0] signal_cat_42;
    wire [2:0] signal_const_137;
    wire [2:0] signal_select_23;
    wire [6:0] signal_const_138;
    wire signal_eq_23;
    wire [2:0] signal_mux_34;
    wire [2:0] signal_mux_35;
    wire [2:0] signal_wire_17;
    reg [2:0] signal_reg_17;
    wire [15:0] signal_cat_43;
    wire [4:0] signal_select_24;
    wire [6:0] signal_const_142;
    wire signal_eq_24;
    wire [4:0] signal_mux_36;
    wire [4:0] signal_mux_37;
    wire [4:0] signal_wire_18;
    reg [4:0] signal_reg_18;
    wire [15:0] signal_cat_44;
    wire [4:0] signal_select_25;
    wire [6:0] signal_const_146;
    wire signal_eq_25;
    wire [4:0] signal_mux_38;
    wire [4:0] signal_mux_39;
    wire [4:0] signal_wire_19;
    reg [4:0] signal_reg_19;
    wire [15:0] signal_cat_45;
    wire [4:0] signal_select_26;
    wire [6:0] signal_const_150;
    wire signal_eq_26;
    wire [4:0] signal_mux_40;
    wire [4:0] signal_mux_41;
    wire [4:0] signal_wire_20;
    reg [4:0] signal_reg_20;
    wire [15:0] signal_cat_46;
    wire [4:0] signal_select_27;
    wire [6:0] signal_const_154;
    wire signal_eq_27;
    wire [4:0] signal_mux_42;
    wire [4:0] signal_mux_43;
    wire [4:0] signal_wire_21;
    reg [4:0] signal_reg_21;
    wire [15:0] signal_cat_47;
    wire [4:0] signal_select_28;
    wire [6:0] signal_const_158;
    wire signal_eq_28;
    wire [4:0] signal_mux_44;
    wire [4:0] signal_mux_45;
    wire [4:0] signal_wire_22;
    reg [4:0] signal_reg_22;
    wire [15:0] signal_cat_48;
    wire signal_select_29;
    wire [6:0] signal_const_162;
    wire signal_eq_29;
    wire signal_mux_46;
    wire signal_mux_47;
    wire signal_wire_23;
    reg signal_reg_23;
    wire [15:0] signal_cat_49;
    wire [4:0] signal_select_30;
    wire [6:0] signal_const_166;
    wire signal_eq_30;
    wire [4:0] signal_mux_48;
    wire [4:0] signal_mux_49;
    wire [4:0] signal_wire_24;
    reg [4:0] signal_reg_24;
    wire [15:0] signal_cat_50;
    wire [1:0] signal_const_169;
    wire [1:0] signal_select_31;
    wire [6:0] signal_const_170;
    wire signal_eq_31;
    wire [1:0] signal_mux_50;
    wire [1:0] signal_mux_51;
    wire [1:0] signal_wire_25;
    reg [1:0] signal_reg_25;
    wire [15:0] signal_cat_51;
    wire [8:0] signal_const_174;
    wire [8:0] signal_add;
    reg [7:0] signal_cases;
    wire [7:0] signal_mux_52;
    wire [7:0] signal_wire_26;
    reg [7:0] high;
    wire [15:0] value;
    wire [8:0] signal_select_32;
    wire [6:0] signal_const_176;
    wire signal_eq_32;
    wire [8:0] signal_mux_53;
    wire signal_eq_33;
    wire [8:0] signal_mux_54;
    wire signal_mux_55;
    reg signal_cases_1;
    wire signal_mux_56;
    wire write;
    wire [8:0] signal_mux_57;
    wire [8:0] signal_wire_27;
    reg [8:0] program_addr;
    wire [15:0] signal_cat_52;
    wire [15:0] signal_wire_28;
    wire [7:0] signal_select_33;
    wire [15:0] signal_cat_53;
    wire [23:0] signal_wire_29;
    wire [15:0] signal_select_34;
    wire [7:0] signal_select_35;
    wire [15:0] signal_cat_54;
    wire [23:0] signal_wire_30;
    wire [15:0] signal_select_36;
    wire [8:0] signal_wire_31;
    wire [15:0] signal_cat_55;
    wire signal_wire_32;
    wire signal_wire_33;
    wire signal_wire_34;
    wire signal_wire_35;
    wire signal_wire_36;
    wire signal_wire_37;
    wire [3:0] signal_wire_38;
    wire [3:0] signal_wire_39;
    wire [15:0] signal_cat_56;
    wire [6:0] signal_select_37;
    reg [15:0] first_read;
    reg [15:0] signal_cases_2;
    wire [15:0] signal_mux_58;
    wire vdd;
    wire is_write;
    wire signal_mux_59;
    reg signal_cases_3;
    wire gnd;
    wire signal_mux_60;
    wire read_done;
    wire [15:0] signal_mux_61;
    wire [15:0] signal_wire_40;
    reg [15:0] word;
    wire [7:0] signal_select_38;
    reg [7:0] signal_cases_4;
    wire [7:0] signal_mux_62;
    wire [7:0] signal_wire_41;
    reg [7:0] cmd;
    wire [6:0] addr;
    wire signal_eq_34;
    wire [15:0] tx_word;
    wire [7:0] signal_select_39;
    wire [1:0] signal_const_194;
    reg [1:0] signal_cases_5;
    wire signal_select_40;
    wire [1:0] signal_mux_63;
    wire signal_select_41;
    wire [1:0] signal_mux_64;
    wire [1:0] signal_wire_42;
    (* fsm_encoding="one_hot" *)
    reg [1:0] sm;
    wire [1:0] signal_const_196;
    wire signal_eq_35;
    wire [7:0] signal_mux_65;
    wire signal_wire_43;
    wire signal_wire_44;
    wire signal_wire_45;
    wire signal_wire_46;
    wire signal_wire_47;
    wire [11:0] signal_inst;
    wire signal_select_42;
    assign signal_const = 7'b0001000;
    assign signal_eq = addr == signal_const;
    assign signal_and = read_done & signal_eq;
    assign signal_const_1 = 7'b0000111;
    assign signal_eq_1 = addr == signal_const_1;
    assign signal_and_1 = write & signal_eq_1;
    assign signal_const_2 = 7'b0001010;
    assign signal_eq_2 = addr == signal_const_2;
    assign signal_and_2 = write & signal_eq_2;
    assign signal_select = value[2:2];
    assign signal_const_3 = 7'b0000000;
    assign signal_eq_3 = addr == signal_const_3;
    assign signal_and_3 = write & signal_eq_3;
    assign signal_and_4 = signal_and_3 & signal_select;
    assign signal_select_1 = value[1:1];
    assign signal_eq_4 = addr == signal_const_3;
    assign signal_and_5 = write & signal_eq_4;
    assign signal_and_6 = signal_and_5 & signal_select_1;
    assign signal_select_2 = value[0:0];
    assign signal_eq_5 = addr == signal_const_3;
    assign signal_and_7 = write & signal_eq_5;
    assign signal_and_8 = signal_and_7 & signal_select_2;
    assign signal_select_3 = tx_word[7:0];
    assign signal_const_6 = 16'b0000000000000000;
    assign signal_cat = { signal_const_3,
                          signal_reg };
    assign signal_cat_1 = { signal_const_3,
                            signal_reg_1 };
    assign signal_const_12 = 15'b000000000000000;
    assign signal_cat_2 = { signal_const_12,
                            signal_reg_2 };
    assign signal_const_14 = 11'b00000000000;
    assign signal_cat_3 = { signal_const_14,
                            signal_reg_3 };
    assign signal_cat_4 = { signal_const_12,
                            signal_reg_4 };
    assign signal_cat_5 = { signal_const_14,
                            signal_reg_7 };
    assign signal_cat_6 = { signal_const_14,
                            signal_reg_8 };
    assign signal_cat_7 = { signal_const_12,
                            signal_reg_9 };
    assign signal_cat_8 = { signal_const_14,
                            signal_reg_10 };
    assign signal_cat_9 = { signal_const_12,
                            signal_reg_11 };
    assign signal_cat_10 = { signal_const_12,
                             signal_reg_12 };
    assign signal_cat_11 = { signal_const_12,
                             signal_reg_13 };
    assign signal_cat_12 = { signal_const_12,
                             signal_reg_14 };
    assign signal_cat_13 = { signal_const_14,
                             signal_reg_15 };
    assign signal_cat_14 = { signal_const_14,
                             signal_reg_16 };
    assign signal_const_40 = 13'b0000000000000;
    assign signal_cat_15 = { signal_const_40,
                             signal_reg_17 };
    assign signal_cat_16 = { signal_const_14,
                             signal_reg_18 };
    assign signal_cat_17 = { signal_const_14,
                             signal_reg_19 };
    assign signal_cat_18 = { signal_const_14,
                             signal_reg_20 };
    assign signal_cat_19 = { signal_const_14,
                             signal_reg_21 };
    assign signal_cat_20 = { signal_const_14,
                             signal_reg_22 };
    assign signal_cat_21 = { signal_const_12,
                             signal_reg_23 };
    assign signal_cat_22 = { signal_const_14,
                             signal_reg_24 };
    assign signal_const_56 = 14'b00000000000000;
    assign signal_cat_23 = { signal_const_56,
                             signal_reg_25 };
    assign signal_cat_24 = { signal_const_3,
                             program_addr };
    assign signal_select_4 = signal_wire_29[23:16];
    assign signal_const_61 = 8'b00000000;
    assign signal_cat_25 = { signal_const_61,
                             signal_select_4 };
    assign signal_select_5 = signal_wire_29[15:0];
    assign signal_select_6 = signal_wire_30[23:16];
    assign signal_cat_26 = { signal_const_61,
                             signal_select_6 };
    assign signal_select_7 = signal_wire_30[15:0];
    assign signal_cat_27 = { signal_const_3,
                             signal_wire_31 };
    always @* begin
        case (addr)
        7'b0000001:
            read_value <= signal_cat_56;
        7'b0000010:
            read_value <= signal_cat_27;
        7'b0000011:
            read_value <= signal_select_7;
        7'b0000100:
            read_value <= signal_cat_26;
        7'b0000101:
            read_value <= signal_select_5;
        7'b0000110:
            read_value <= signal_cat_25;
        7'b0001000:
            read_value <= signal_wire_28;
        7'b0001001:
            read_value <= signal_cat_24;
        7'b0010000:
            read_value <= signal_cat_23;
        7'b0010001:
            read_value <= signal_cat_22;
        7'b0010010:
            read_value <= signal_cat_21;
        7'b0010011:
            read_value <= signal_cat_20;
        7'b0010100:
            read_value <= signal_cat_19;
        7'b0010101:
            read_value <= signal_cat_18;
        7'b0010110:
            read_value <= signal_cat_17;
        7'b0010111:
            read_value <= signal_cat_16;
        7'b0011000:
            read_value <= signal_cat_15;
        7'b0011001:
            read_value <= signal_cat_14;
        7'b0011010:
            read_value <= signal_cat_13;
        7'b0011011:
            read_value <= signal_cat_12;
        7'b0011100:
            read_value <= signal_cat_11;
        7'b0011101:
            read_value <= signal_cat_10;
        7'b0011110:
            read_value <= signal_cat_9;
        7'b0011111:
            read_value <= signal_cat_8;
        7'b0100000:
            read_value <= signal_cat_7;
        7'b0100001:
            read_value <= signal_cat_6;
        7'b0100010:
            read_value <= signal_cat_5;
        7'b0100011:
            read_value <= signal_reg_6;
        7'b0100100:
            read_value <= signal_reg_5;
        7'b0100101:
            read_value <= signal_cat_4;
        7'b0100110:
            read_value <= signal_cat_3;
        7'b0100111:
            read_value <= signal_cat_2;
        7'b0101000:
            read_value <= signal_cat_1;
        7'b0101001:
            read_value <= signal_cat;
        default:
            read_value <= signal_const_6;
        endcase
    end
    assign signal_const_71 = 9'b000000000;
    assign signal_select_8 = value[8:0];
    assign signal_const_72 = 7'b0101001;
    assign signal_eq_6 = addr == signal_const_72;
    assign signal_mux = signal_eq_6 ? signal_select_8 : signal_reg;
    assign signal_mux_1 = write ? signal_mux : signal_reg;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg <= signal_const_71;
        else
            signal_reg <= signal_wire;
    end
    assign signal_cat_28 = { signal_const_3,
                             signal_reg };
    assign signal_select_9 = value[8:0];
    assign signal_const_76 = 7'b0101000;
    assign signal_eq_7 = addr == signal_const_76;
    assign signal_mux_2 = signal_eq_7 ? signal_select_9 : signal_reg_1;
    assign signal_mux_3 = write ? signal_mux_2 : signal_reg_1;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_1 <= signal_const_71;
        else
            signal_reg_1 <= signal_wire_1;
    end
    assign signal_cat_29 = { signal_const_3,
                             signal_reg_1 };
    assign signal_const_79 = 1'b0;
    assign signal_select_10 = value[0:0];
    assign signal_const_80 = 7'b0100111;
    assign signal_eq_8 = addr == signal_const_80;
    assign signal_mux_4 = signal_eq_8 ? signal_select_10 : signal_reg_2;
    assign signal_mux_5 = write ? signal_mux_4 : signal_reg_2;
    assign signal_wire_2 = signal_mux_5;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_2 <= signal_const_79;
        else
            signal_reg_2 <= signal_wire_2;
    end
    assign signal_cat_30 = { signal_const_12,
                             signal_reg_2 };
    assign signal_const_83 = 5'b00000;
    assign signal_select_11 = value[4:0];
    assign signal_const_84 = 7'b0100110;
    assign signal_eq_9 = addr == signal_const_84;
    assign signal_mux_6 = signal_eq_9 ? signal_select_11 : signal_reg_3;
    assign signal_mux_7 = write ? signal_mux_6 : signal_reg_3;
    assign signal_wire_3 = signal_mux_7;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_3 <= signal_const_83;
        else
            signal_reg_3 <= signal_wire_3;
    end
    assign signal_cat_31 = { signal_const_14,
                             signal_reg_3 };
    assign signal_select_12 = value[0:0];
    assign signal_const_88 = 7'b0100101;
    assign signal_eq_10 = addr == signal_const_88;
    assign signal_mux_8 = signal_eq_10 ? signal_select_12 : signal_reg_4;
    assign signal_mux_9 = write ? signal_mux_8 : signal_reg_4;
    assign signal_wire_4 = signal_mux_9;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_4 <= signal_const_79;
        else
            signal_reg_4 <= signal_wire_4;
    end
    assign signal_cat_32 = { signal_const_12,
                             signal_reg_4 };
    assign signal_const_92 = 7'b0100100;
    assign signal_eq_11 = addr == signal_const_92;
    assign signal_mux_10 = signal_eq_11 ? value : signal_reg_5;
    assign signal_mux_11 = write ? signal_mux_10 : signal_reg_5;
    assign signal_wire_5 = signal_mux_11;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_5 <= signal_const_6;
        else
            signal_reg_5 <= signal_wire_5;
    end
    assign signal_const_95 = 7'b0100011;
    assign signal_eq_12 = addr == signal_const_95;
    assign signal_mux_12 = signal_eq_12 ? value : signal_reg_6;
    assign signal_mux_13 = write ? signal_mux_12 : signal_reg_6;
    assign signal_wire_6 = signal_mux_13;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_6 <= signal_const_6;
        else
            signal_reg_6 <= signal_wire_6;
    end
    assign signal_select_13 = value[4:0];
    assign signal_const_98 = 7'b0100010;
    assign signal_eq_13 = addr == signal_const_98;
    assign signal_mux_14 = signal_eq_13 ? signal_select_13 : signal_reg_7;
    assign signal_mux_15 = write ? signal_mux_14 : signal_reg_7;
    assign signal_wire_7 = signal_mux_15;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_7 <= signal_const_83;
        else
            signal_reg_7 <= signal_wire_7;
    end
    assign signal_cat_33 = { signal_const_14,
                             signal_reg_7 };
    assign signal_select_14 = value[4:0];
    assign signal_const_102 = 7'b0100001;
    assign signal_eq_14 = addr == signal_const_102;
    assign signal_mux_16 = signal_eq_14 ? signal_select_14 : signal_reg_8;
    assign signal_mux_17 = write ? signal_mux_16 : signal_reg_8;
    assign signal_wire_8 = signal_mux_17;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_8 <= signal_const_83;
        else
            signal_reg_8 <= signal_wire_8;
    end
    assign signal_cat_34 = { signal_const_14,
                             signal_reg_8 };
    assign signal_select_15 = value[0:0];
    assign signal_const_106 = 7'b0100000;
    assign signal_eq_15 = addr == signal_const_106;
    assign signal_mux_18 = signal_eq_15 ? signal_select_15 : signal_reg_9;
    assign signal_mux_19 = write ? signal_mux_18 : signal_reg_9;
    assign signal_wire_9 = signal_mux_19;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_9 <= signal_const_79;
        else
            signal_reg_9 <= signal_wire_9;
    end
    assign signal_cat_35 = { signal_const_12,
                             signal_reg_9 };
    assign signal_select_16 = value[4:0];
    assign signal_const_110 = 7'b0011111;
    assign signal_eq_16 = addr == signal_const_110;
    assign signal_mux_20 = signal_eq_16 ? signal_select_16 : signal_reg_10;
    assign signal_mux_21 = write ? signal_mux_20 : signal_reg_10;
    assign signal_wire_10 = signal_mux_21;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_10 <= signal_const_83;
        else
            signal_reg_10 <= signal_wire_10;
    end
    assign signal_cat_36 = { signal_const_14,
                             signal_reg_10 };
    assign signal_select_17 = value[0:0];
    assign signal_const_114 = 7'b0011110;
    assign signal_eq_17 = addr == signal_const_114;
    assign signal_mux_22 = signal_eq_17 ? signal_select_17 : signal_reg_11;
    assign signal_mux_23 = write ? signal_mux_22 : signal_reg_11;
    assign signal_wire_11 = signal_mux_23;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_11 <= signal_const_79;
        else
            signal_reg_11 <= signal_wire_11;
    end
    assign signal_cat_37 = { signal_const_12,
                             signal_reg_11 };
    assign signal_select_18 = value[0:0];
    assign signal_const_118 = 7'b0011101;
    assign signal_eq_18 = addr == signal_const_118;
    assign signal_mux_24 = signal_eq_18 ? signal_select_18 : signal_reg_12;
    assign signal_mux_25 = write ? signal_mux_24 : signal_reg_12;
    assign signal_wire_12 = signal_mux_25;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_12 <= signal_const_79;
        else
            signal_reg_12 <= signal_wire_12;
    end
    assign signal_cat_38 = { signal_const_12,
                             signal_reg_12 };
    assign signal_select_19 = value[0:0];
    assign signal_const_122 = 7'b0011100;
    assign signal_eq_19 = addr == signal_const_122;
    assign signal_mux_26 = signal_eq_19 ? signal_select_19 : signal_reg_13;
    assign signal_mux_27 = write ? signal_mux_26 : signal_reg_13;
    assign signal_wire_13 = signal_mux_27;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_13 <= signal_const_79;
        else
            signal_reg_13 <= signal_wire_13;
    end
    assign signal_cat_39 = { signal_const_12,
                             signal_reg_13 };
    assign signal_select_20 = value[0:0];
    assign signal_const_126 = 7'b0011011;
    assign signal_eq_20 = addr == signal_const_126;
    assign signal_mux_28 = signal_eq_20 ? signal_select_20 : signal_reg_14;
    assign signal_mux_29 = write ? signal_mux_28 : signal_reg_14;
    assign signal_wire_14 = signal_mux_29;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_14 <= signal_const_79;
        else
            signal_reg_14 <= signal_wire_14;
    end
    assign signal_cat_40 = { signal_const_12,
                             signal_reg_14 };
    assign signal_select_21 = value[4:0];
    assign signal_const_130 = 7'b0011010;
    assign signal_eq_21 = addr == signal_const_130;
    assign signal_mux_30 = signal_eq_21 ? signal_select_21 : signal_reg_15;
    assign signal_mux_31 = write ? signal_mux_30 : signal_reg_15;
    assign signal_wire_15 = signal_mux_31;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_15 <= signal_const_83;
        else
            signal_reg_15 <= signal_wire_15;
    end
    assign signal_cat_41 = { signal_const_14,
                             signal_reg_15 };
    assign signal_select_22 = value[4:0];
    assign signal_const_134 = 7'b0011001;
    assign signal_eq_22 = addr == signal_const_134;
    assign signal_mux_32 = signal_eq_22 ? signal_select_22 : signal_reg_16;
    assign signal_mux_33 = write ? signal_mux_32 : signal_reg_16;
    assign signal_wire_16 = signal_mux_33;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_16 <= signal_const_83;
        else
            signal_reg_16 <= signal_wire_16;
    end
    assign signal_cat_42 = { signal_const_14,
                             signal_reg_16 };
    assign signal_const_137 = 3'b000;
    assign signal_select_23 = value[2:0];
    assign signal_const_138 = 7'b0011000;
    assign signal_eq_23 = addr == signal_const_138;
    assign signal_mux_34 = signal_eq_23 ? signal_select_23 : signal_reg_17;
    assign signal_mux_35 = write ? signal_mux_34 : signal_reg_17;
    assign signal_wire_17 = signal_mux_35;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_17 <= signal_const_137;
        else
            signal_reg_17 <= signal_wire_17;
    end
    assign signal_cat_43 = { signal_const_40,
                             signal_reg_17 };
    assign signal_select_24 = value[4:0];
    assign signal_const_142 = 7'b0010111;
    assign signal_eq_24 = addr == signal_const_142;
    assign signal_mux_36 = signal_eq_24 ? signal_select_24 : signal_reg_18;
    assign signal_mux_37 = write ? signal_mux_36 : signal_reg_18;
    assign signal_wire_18 = signal_mux_37;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_18 <= signal_const_83;
        else
            signal_reg_18 <= signal_wire_18;
    end
    assign signal_cat_44 = { signal_const_14,
                             signal_reg_18 };
    assign signal_select_25 = value[4:0];
    assign signal_const_146 = 7'b0010110;
    assign signal_eq_25 = addr == signal_const_146;
    assign signal_mux_38 = signal_eq_25 ? signal_select_25 : signal_reg_19;
    assign signal_mux_39 = write ? signal_mux_38 : signal_reg_19;
    assign signal_wire_19 = signal_mux_39;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_19 <= signal_const_83;
        else
            signal_reg_19 <= signal_wire_19;
    end
    assign signal_cat_45 = { signal_const_14,
                             signal_reg_19 };
    assign signal_select_26 = value[4:0];
    assign signal_const_150 = 7'b0010101;
    assign signal_eq_26 = addr == signal_const_150;
    assign signal_mux_40 = signal_eq_26 ? signal_select_26 : signal_reg_20;
    assign signal_mux_41 = write ? signal_mux_40 : signal_reg_20;
    assign signal_wire_20 = signal_mux_41;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_20 <= signal_const_83;
        else
            signal_reg_20 <= signal_wire_20;
    end
    assign signal_cat_46 = { signal_const_14,
                             signal_reg_20 };
    assign signal_select_27 = value[4:0];
    assign signal_const_154 = 7'b0010100;
    assign signal_eq_27 = addr == signal_const_154;
    assign signal_mux_42 = signal_eq_27 ? signal_select_27 : signal_reg_21;
    assign signal_mux_43 = write ? signal_mux_42 : signal_reg_21;
    assign signal_wire_21 = signal_mux_43;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_21 <= signal_const_83;
        else
            signal_reg_21 <= signal_wire_21;
    end
    assign signal_cat_47 = { signal_const_14,
                             signal_reg_21 };
    assign signal_select_28 = value[4:0];
    assign signal_const_158 = 7'b0010011;
    assign signal_eq_28 = addr == signal_const_158;
    assign signal_mux_44 = signal_eq_28 ? signal_select_28 : signal_reg_22;
    assign signal_mux_45 = write ? signal_mux_44 : signal_reg_22;
    assign signal_wire_22 = signal_mux_45;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_22 <= signal_const_83;
        else
            signal_reg_22 <= signal_wire_22;
    end
    assign signal_cat_48 = { signal_const_14,
                             signal_reg_22 };
    assign signal_select_29 = value[0:0];
    assign signal_const_162 = 7'b0010010;
    assign signal_eq_29 = addr == signal_const_162;
    assign signal_mux_46 = signal_eq_29 ? signal_select_29 : signal_reg_23;
    assign signal_mux_47 = write ? signal_mux_46 : signal_reg_23;
    assign signal_wire_23 = signal_mux_47;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_23 <= signal_const_79;
        else
            signal_reg_23 <= signal_wire_23;
    end
    assign signal_cat_49 = { signal_const_12,
                             signal_reg_23 };
    assign signal_select_30 = value[4:0];
    assign signal_const_166 = 7'b0010001;
    assign signal_eq_30 = addr == signal_const_166;
    assign signal_mux_48 = signal_eq_30 ? signal_select_30 : signal_reg_24;
    assign signal_mux_49 = write ? signal_mux_48 : signal_reg_24;
    assign signal_wire_24 = signal_mux_49;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_24 <= signal_const_83;
        else
            signal_reg_24 <= signal_wire_24;
    end
    assign signal_cat_50 = { signal_const_14,
                             signal_reg_24 };
    assign signal_const_169 = 2'b00;
    assign signal_select_31 = value[1:0];
    assign signal_const_170 = 7'b0010000;
    assign signal_eq_31 = addr == signal_const_170;
    assign signal_mux_50 = signal_eq_31 ? signal_select_31 : signal_reg_25;
    assign signal_mux_51 = write ? signal_mux_50 : signal_reg_25;
    assign signal_wire_25 = signal_mux_51;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_25 <= signal_const_169;
        else
            signal_reg_25 <= signal_wire_25;
    end
    assign signal_cat_51 = { signal_const_56,
                             signal_reg_25 };
    assign signal_const_174 = 9'b000000001;
    assign signal_add = program_addr + signal_const_174;
    always @* begin
        case (sm)
        2'b01:
            signal_cases <= signal_select_38;
        default:
            signal_cases <= high;
        endcase
    end
    assign signal_mux_52 = signal_select_41 ? signal_cases : high;
    assign signal_wire_26 = signal_mux_52;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            high <= signal_const_61;
        else
            high <= signal_wire_26;
    end
    assign value = { high,
                     signal_select_38 };
    assign signal_select_32 = value[8:0];
    assign signal_const_176 = 7'b0001001;
    assign signal_eq_32 = addr == signal_const_176;
    assign signal_mux_53 = signal_eq_32 ? signal_select_32 : program_addr;
    assign signal_eq_33 = addr == signal_const_2;
    assign signal_mux_54 = signal_eq_33 ? signal_add : signal_mux_53;
    assign signal_mux_55 = is_write ? vdd : gnd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_1 <= signal_mux_55;
        default:
            signal_cases_1 <= gnd;
        endcase
    end
    assign signal_mux_56 = signal_select_41 ? signal_cases_1 : gnd;
    assign write = signal_mux_56;
    assign signal_mux_57 = write ? signal_mux_54 : program_addr;
    assign signal_wire_27 = signal_mux_57;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            program_addr <= signal_const_71;
        else
            program_addr <= signal_wire_27;
    end
    assign signal_cat_52 = { signal_const_3,
                             program_addr };
    assign signal_wire_28 = status$rx_head;
    assign signal_select_33 = signal_wire_29[23:16];
    assign signal_cat_53 = { signal_const_61,
                             signal_select_33 };
    assign signal_wire_29 = status$capture;
    assign signal_select_34 = signal_wire_29[15:0];
    assign signal_select_35 = signal_wire_30[23:16];
    assign signal_cat_54 = { signal_const_61,
                             signal_select_35 };
    assign signal_wire_30 = status$now;
    assign signal_select_36 = signal_wire_30[15:0];
    assign signal_wire_31 = status$pc;
    assign signal_cat_55 = { signal_const_3,
                             signal_wire_31 };
    assign signal_wire_32 = status$halted;
    assign signal_wire_33 = status$irq;
    assign signal_wire_34 = status$fault$underflow;
    assign signal_wire_35 = status$fault$overflow;
    assign signal_wire_36 = status$fault$missed_deadline;
    assign signal_wire_37 = status$fault$decode;
    assign signal_wire_38 = status$tx_level;
    assign signal_wire_39 = status$rx_level;
    assign signal_cat_56 = { signal_const_169,
                             signal_wire_39,
                             signal_wire_38,
                             signal_wire_37,
                             signal_wire_36,
                             signal_wire_35,
                             signal_wire_34,
                             signal_wire_33,
                             signal_wire_32 };
    assign signal_select_37 = signal_select_38[6:0];
    always @* begin
        case (signal_select_37)
        7'b0000001:
            first_read <= signal_cat_56;
        7'b0000010:
            first_read <= signal_cat_55;
        7'b0000011:
            first_read <= signal_select_36;
        7'b0000100:
            first_read <= signal_cat_54;
        7'b0000101:
            first_read <= signal_select_34;
        7'b0000110:
            first_read <= signal_cat_53;
        7'b0001000:
            first_read <= signal_wire_28;
        7'b0001001:
            first_read <= signal_cat_52;
        7'b0010000:
            first_read <= signal_cat_51;
        7'b0010001:
            first_read <= signal_cat_50;
        7'b0010010:
            first_read <= signal_cat_49;
        7'b0010011:
            first_read <= signal_cat_48;
        7'b0010100:
            first_read <= signal_cat_47;
        7'b0010101:
            first_read <= signal_cat_46;
        7'b0010110:
            first_read <= signal_cat_45;
        7'b0010111:
            first_read <= signal_cat_44;
        7'b0011000:
            first_read <= signal_cat_43;
        7'b0011001:
            first_read <= signal_cat_42;
        7'b0011010:
            first_read <= signal_cat_41;
        7'b0011011:
            first_read <= signal_cat_40;
        7'b0011100:
            first_read <= signal_cat_39;
        7'b0011101:
            first_read <= signal_cat_38;
        7'b0011110:
            first_read <= signal_cat_37;
        7'b0011111:
            first_read <= signal_cat_36;
        7'b0100000:
            first_read <= signal_cat_35;
        7'b0100001:
            first_read <= signal_cat_34;
        7'b0100010:
            first_read <= signal_cat_33;
        7'b0100011:
            first_read <= signal_reg_6;
        7'b0100100:
            first_read <= signal_reg_5;
        7'b0100101:
            first_read <= signal_cat_32;
        7'b0100110:
            first_read <= signal_cat_31;
        7'b0100111:
            first_read <= signal_cat_30;
        7'b0101000:
            first_read <= signal_cat_29;
        7'b0101001:
            first_read <= signal_cat_28;
        default:
            first_read <= signal_const_6;
        endcase
    end
    always @* begin
        case (sm)
        2'b00:
            signal_cases_2 <= first_read;
        default:
            signal_cases_2 <= word;
        endcase
    end
    assign signal_mux_58 = signal_select_41 ? signal_cases_2 : word;
    assign vdd = 1'b1;
    assign is_write = cmd[7:7];
    assign signal_mux_59 = is_write ? gnd : vdd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_3 <= signal_mux_59;
        default:
            signal_cases_3 <= gnd;
        endcase
    end
    assign gnd = 1'b0;
    assign signal_mux_60 = signal_select_41 ? signal_cases_3 : gnd;
    assign read_done = signal_mux_60;
    assign signal_mux_61 = read_done ? read_value : signal_mux_58;
    assign signal_wire_40 = signal_mux_61;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            word <= signal_const_6;
        else
            word <= signal_wire_40;
    end
    assign signal_select_38 = signal_inst[8:1];
    always @* begin
        case (sm)
        2'b00:
            signal_cases_4 <= signal_select_38;
        default:
            signal_cases_4 <= cmd;
        endcase
    end
    assign signal_mux_62 = signal_select_41 ? signal_cases_4 : cmd;
    assign signal_wire_41 = signal_mux_62;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            cmd <= signal_const_61;
        else
            cmd <= signal_wire_41;
    end
    assign addr = cmd[6:0];
    assign signal_eq_34 = addr == signal_const;
    assign tx_word = signal_eq_34 ? signal_wire_28 : word;
    assign signal_select_39 = tx_word[15:8];
    assign signal_const_194 = 2'b01;
    always @* begin
        case (sm)
        2'b00:
            signal_cases_5 <= signal_const_194;
        2'b01:
            signal_cases_5 <= signal_const_196;
        2'b10:
            signal_cases_5 <= signal_const_194;
        default:
            signal_cases_5 <= signal_mux_63;
        endcase
    end
    assign signal_select_40 = signal_inst[10:10];
    assign signal_mux_63 = signal_select_40 ? signal_const_169 : sm;
    assign signal_select_41 = signal_inst[9:9];
    assign signal_mux_64 = signal_select_41 ? signal_cases_5 : signal_mux_63;
    assign signal_wire_42 = signal_mux_64;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            sm <= signal_const_169;
        else
            sm <= signal_wire_42;
    end
    assign signal_const_196 = 2'b10;
    assign signal_eq_35 = signal_const_196 == sm;
    assign signal_mux_65 = signal_eq_35 ? signal_select_3 : signal_select_39;
    assign signal_wire_43 = cs_n;
    assign signal_wire_44 = mosi;
    assign signal_wire_45 = sck;
    assign signal_wire_46 = clear;
    assign signal_wire_47 = clock;
    host_spi
        host_spi
        ( .clock(signal_wire_47),
          .clear(signal_wire_46),
          .sck(signal_wire_45),
          .mosi(signal_wire_44),
          .cs_n(signal_wire_43),
          .tx_byte(signal_mux_65),
          .miso(signal_inst[0:0]),
          .rx_byte(signal_inst[8:1]),
          .rx_valid(signal_inst[9:9]),
          .frame_start(signal_inst[10:10]),
          .frame_end(signal_inst[11:11]) );
    assign signal_select_42 = signal_inst[0:0];
    assign miso = signal_select_42;
    assign start = signal_and_8;
    assign clear_irq = signal_and_6;
    assign stop = signal_and_4;
    assign program_write$valid = signal_and_2;
    assign program_write$addr = program_addr;
    assign program_write$data = value;
    assign tx$valid = signal_and_1;
    assign tx$value = value;
    assign rx_pop = signal_and;
    assign config$side_set_count = signal_reg_25;
    assign config$side_set_base = signal_reg_24;
    assign config$side_set_pindirs = signal_reg_23;
    assign config$in_base = signal_reg_22;
    assign config$in_count = signal_reg_21;
    assign config$out_base = signal_reg_20;
    assign config$out_count = signal_reg_19;
    assign config$set_base = signal_reg_18;
    assign config$set_count = signal_reg_17;
    assign config$jmp_pin = signal_reg_16;
    assign config$capture_pin = signal_reg_15;
    assign config$capture_rising = signal_reg_14;
    assign config$in_shift_right = signal_reg_13;
    assign config$out_shift_right = signal_reg_12;
    assign config$autopush = signal_reg_11;
    assign config$push_threshold = signal_reg_10;
    assign config$autopull = signal_reg_9;
    assign config$pull_threshold = signal_reg_8;
    assign config$crc_width = signal_reg_7;
    assign config$crc_poly = signal_reg_6;
    assign config$crc_init = signal_reg_5;
    assign config$crc_reflect = signal_reg_4;
    assign config$stuff_threshold = signal_reg_3;
    assign config$stuff_level = signal_reg_2;
    assign config$wrap_bottom = signal_reg_1;
    assign config$wrap_top = signal_reg;

endmodule
module top (
    clk,
    rst_n,
    ui_in,
    uio_in,
    ena,
    uo_out,
    uio_out,
    uio_oe
);

    input clk;
    input rst_n;
    input [7:0] ui_in;
    input [7:0] uio_in;
    input ena;
    output [7:0] uo_out;
    output [7:0] uio_out;
    output [7:0] uio_oe;

    wire [19:0] signal_select;
    wire [7:0] signal_select_1;
    wire [7:0] signal_select_2;
    wire signal_select_3;
    wire [4:0] signal_const;
    wire [4:0] signal_select_4;
    reg [4:0] signal_reg;
    reg [4:0] signal_reg_1;
    wire [6:0] signal_const_2;
    wire [7:0] signal_const_3;
    wire [7:0] signal_wire;
    reg [7:0] signal_reg_2;
    reg [7:0] signal_reg_3;
    wire [19:0] inputs;
    wire signal_select_5;
    wire signal_select_6;
    wire signal_select_7;
    wire [15:0] signal_select_8;
    wire signal_select_9;
    wire [15:0] signal_select_10;
    wire [8:0] signal_select_11;
    wire signal_select_12;
    wire signal_select_13;
    wire [8:0] signal_select_14;
    wire [8:0] signal_select_15;
    wire signal_select_16;
    wire [4:0] signal_select_17;
    wire signal_select_18;
    wire [15:0] signal_select_19;
    wire [15:0] signal_select_20;
    wire [4:0] signal_select_21;
    wire [4:0] signal_select_22;
    wire signal_select_23;
    wire [4:0] signal_select_24;
    wire signal_select_25;
    wire signal_select_26;
    wire signal_select_27;
    wire signal_select_28;
    wire [4:0] signal_select_29;
    wire [4:0] signal_select_30;
    wire [2:0] signal_select_31;
    wire [4:0] signal_select_32;
    wire [4:0] signal_select_33;
    wire [4:0] signal_select_34;
    wire [4:0] signal_select_35;
    wire [4:0] signal_select_36;
    wire signal_select_37;
    wire [4:0] signal_select_38;
    wire [15:0] signal_select_39;
    wire [15:0] signal_wire_1;
    wire [3:0] signal_select_40;
    wire [3:0] signal_wire_2;
    wire [3:0] signal_select_41;
    wire [3:0] signal_wire_3;
    wire signal_select_42;
    wire signal_wire_4;
    wire signal_select_43;
    wire signal_wire_5;
    wire signal_select_44;
    wire signal_wire_6;
    wire signal_select_45;
    wire signal_wire_7;
    wire signal_select_46;
    wire signal_wire_8;
    wire signal_select_47;
    wire signal_wire_9;
    wire [23:0] signal_select_48;
    wire [23:0] signal_wire_10;
    wire [23:0] signal_select_49;
    wire [23:0] signal_wire_11;
    wire [8:0] signal_select_50;
    wire [8:0] signal_wire_12;
    wire signal_select_51;
    wire signal_select_52;
    wire [7:0] signal_wire_13;
    wire signal_select_53;
    wire [170:0] signal_inst;
    wire [1:0] signal_select_54;
    wire signal_const_5;
    wire signal_wire_14;
    wire signal_not;
    wire vdd;
    reg signal_reg_4;
    reg reset_done;
    wire signal_not_1;
    wire signal_wire_15;
    wire [292:0] signal_inst_1;
    wire [19:0] signal_select_55;
    wire [6:0] signal_select_56;
    wire [7:0] signal_cat;
    assign signal_select = signal_inst_1[39:20];
    assign signal_select_1 = signal_select[19:12];
    assign signal_select_2 = signal_select_55[19:12];
    assign signal_select_3 = signal_inst[0:0];
    assign signal_const = 5'b00000;
    assign signal_select_4 = signal_wire_13[7:3];
    always @(posedge signal_wire_15) begin
        if (signal_not_1)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_select_4;
    end
    always @(posedge signal_wire_15) begin
        if (signal_not_1)
            signal_reg_1 <= signal_const;
        else
            signal_reg_1 <= signal_reg;
    end
    assign signal_const_2 = 7'b0000000;
    assign signal_const_3 = 8'b00000000;
    assign signal_wire = uio_in;
    always @(posedge signal_wire_15) begin
        if (signal_not_1)
            signal_reg_2 <= signal_const_3;
        else
            signal_reg_2 <= signal_wire;
    end
    always @(posedge signal_wire_15) begin
        if (signal_not_1)
            signal_reg_3 <= signal_const_3;
        else
            signal_reg_3 <= signal_reg_2;
    end
    assign inputs = { signal_reg_3,
                      signal_const_2,
                      signal_reg_1 };
    assign signal_select_5 = signal_inst[3:3];
    assign signal_select_6 = signal_inst[2:2];
    assign signal_select_7 = signal_inst[47:47];
    assign signal_select_8 = signal_inst[46:31];
    assign signal_select_9 = signal_inst[30:30];
    assign signal_select_10 = signal_inst[29:14];
    assign signal_select_11 = signal_inst[13:5];
    assign signal_select_12 = signal_inst[4:4];
    assign signal_select_13 = signal_inst[1:1];
    assign signal_select_14 = signal_inst[170:162];
    assign signal_select_15 = signal_inst[161:153];
    assign signal_select_16 = signal_inst[152:152];
    assign signal_select_17 = signal_inst[151:147];
    assign signal_select_18 = signal_inst[146:146];
    assign signal_select_19 = signal_inst[145:130];
    assign signal_select_20 = signal_inst[129:114];
    assign signal_select_21 = signal_inst[113:109];
    assign signal_select_22 = signal_inst[108:104];
    assign signal_select_23 = signal_inst[103:103];
    assign signal_select_24 = signal_inst[102:98];
    assign signal_select_25 = signal_inst[97:97];
    assign signal_select_26 = signal_inst[96:96];
    assign signal_select_27 = signal_inst[95:95];
    assign signal_select_28 = signal_inst[94:94];
    assign signal_select_29 = signal_inst[93:89];
    assign signal_select_30 = signal_inst[88:84];
    assign signal_select_31 = signal_inst[83:81];
    assign signal_select_32 = signal_inst[80:76];
    assign signal_select_33 = signal_inst[75:71];
    assign signal_select_34 = signal_inst[70:66];
    assign signal_select_35 = signal_inst[65:61];
    assign signal_select_36 = signal_inst[60:56];
    assign signal_select_37 = signal_inst[55:55];
    assign signal_select_38 = signal_inst[54:50];
    assign signal_select_39 = signal_inst_1[246:231];
    assign signal_wire_1 = signal_select_39;
    assign signal_select_40 = signal_inst_1[230:227];
    assign signal_wire_2 = signal_select_40;
    assign signal_select_41 = signal_inst_1[226:223];
    assign signal_wire_3 = signal_select_41;
    assign signal_select_42 = signal_inst_1[197:197];
    assign signal_wire_4 = signal_select_42;
    assign signal_select_43 = signal_inst_1[196:196];
    assign signal_wire_5 = signal_select_43;
    assign signal_select_44 = signal_inst_1[195:195];
    assign signal_wire_6 = signal_select_44;
    assign signal_select_45 = signal_inst_1[194:194];
    assign signal_wire_7 = signal_select_45;
    assign signal_select_46 = signal_inst_1[193:193];
    assign signal_wire_8 = signal_select_46;
    assign signal_select_47 = signal_inst_1[192:192];
    assign signal_wire_9 = signal_select_47;
    assign signal_select_48 = signal_inst_1[221:198];
    assign signal_wire_10 = signal_select_48;
    assign signal_select_49 = signal_inst_1[186:163];
    assign signal_wire_11 = signal_select_49;
    assign signal_select_50 = signal_inst_1[48:40];
    assign signal_wire_12 = signal_select_50;
    assign signal_select_51 = signal_wire_13[2:2];
    assign signal_select_52 = signal_wire_13[1:1];
    assign signal_wire_13 = ui_in;
    assign signal_select_53 = signal_wire_13[0:0];
    host_port
        host_port
        ( .clock(signal_wire_15),
          .clear(signal_not_1),
          .sck(signal_select_53),
          .mosi(signal_select_52),
          .cs_n(signal_select_51),
          .status$pc(signal_wire_12),
          .status$now(signal_wire_11),
          .status$capture(signal_wire_10),
          .status$halted(signal_wire_9),
          .status$irq(signal_wire_8),
          .status$fault$underflow(signal_wire_7),
          .status$fault$overflow(signal_wire_6),
          .status$fault$missed_deadline(signal_wire_5),
          .status$fault$decode(signal_wire_4),
          .status$tx_level(signal_wire_3),
          .status$rx_level(signal_wire_2),
          .status$rx_head(signal_wire_1),
          .miso(signal_inst[0:0]),
          .start(signal_inst[1:1]),
          .clear_irq(signal_inst[2:2]),
          .stop(signal_inst[3:3]),
          .program_write$valid(signal_inst[4:4]),
          .program_write$addr(signal_inst[13:5]),
          .program_write$data(signal_inst[29:14]),
          .tx$valid(signal_inst[30:30]),
          .tx$value(signal_inst[46:31]),
          .rx_pop(signal_inst[47:47]),
          .config$side_set_count(signal_inst[49:48]),
          .config$side_set_base(signal_inst[54:50]),
          .config$side_set_pindirs(signal_inst[55:55]),
          .config$in_base(signal_inst[60:56]),
          .config$in_count(signal_inst[65:61]),
          .config$out_base(signal_inst[70:66]),
          .config$out_count(signal_inst[75:71]),
          .config$set_base(signal_inst[80:76]),
          .config$set_count(signal_inst[83:81]),
          .config$jmp_pin(signal_inst[88:84]),
          .config$capture_pin(signal_inst[93:89]),
          .config$capture_rising(signal_inst[94:94]),
          .config$in_shift_right(signal_inst[95:95]),
          .config$out_shift_right(signal_inst[96:96]),
          .config$autopush(signal_inst[97:97]),
          .config$push_threshold(signal_inst[102:98]),
          .config$autopull(signal_inst[103:103]),
          .config$pull_threshold(signal_inst[108:104]),
          .config$crc_width(signal_inst[113:109]),
          .config$crc_poly(signal_inst[129:114]),
          .config$crc_init(signal_inst[145:130]),
          .config$crc_reflect(signal_inst[146:146]),
          .config$stuff_threshold(signal_inst[151:147]),
          .config$stuff_level(signal_inst[152:152]),
          .config$wrap_bottom(signal_inst[161:153]),
          .config$wrap_top(signal_inst[170:162]) );
    assign signal_select_54 = signal_inst[49:48];
    assign signal_const_5 = 1'b0;
    assign signal_wire_14 = rst_n;
    assign signal_not = ~ signal_wire_14;
    assign vdd = 1'b1;
    always @(posedge signal_wire_15 or posedge signal_not) begin
        if (signal_not)
            signal_reg_4 <= signal_const_5;
        else
            signal_reg_4 <= vdd;
    end
    always @(posedge signal_wire_15 or posedge signal_not) begin
        if (signal_not)
            reset_done <= signal_const_5;
        else
            reset_done <= signal_reg_4;
    end
    assign signal_not_1 = ~ reset_done;
    assign signal_wire_15 = clk;
    engine
        engine
        ( .clock(signal_wire_15),
          .clear(signal_not_1),
          .config$side_set_count(signal_select_54),
          .config$side_set_base(signal_select_38),
          .config$side_set_pindirs(signal_select_37),
          .config$in_base(signal_select_36),
          .config$in_count(signal_select_35),
          .config$out_base(signal_select_34),
          .config$out_count(signal_select_33),
          .config$set_base(signal_select_32),
          .config$set_count(signal_select_31),
          .config$jmp_pin(signal_select_30),
          .config$capture_pin(signal_select_29),
          .config$capture_rising(signal_select_28),
          .config$in_shift_right(signal_select_27),
          .config$out_shift_right(signal_select_26),
          .config$autopush(signal_select_25),
          .config$push_threshold(signal_select_24),
          .config$autopull(signal_select_23),
          .config$pull_threshold(signal_select_22),
          .config$crc_width(signal_select_21),
          .config$crc_poly(signal_select_20),
          .config$crc_init(signal_select_19),
          .config$crc_reflect(signal_select_18),
          .config$stuff_threshold(signal_select_17),
          .config$stuff_level(signal_select_16),
          .config$wrap_bottom(signal_select_15),
          .config$wrap_top(signal_select_14),
          .start(signal_select_13),
          .program_write$valid(signal_select_12),
          .program_write$addr(signal_select_11),
          .program_write$data(signal_select_10),
          .tx$valid(signal_select_9),
          .tx$value(signal_select_8),
          .rx_pop(signal_select_7),
          .clear_irq(signal_select_6),
          .stop(signal_select_5),
          .inputs(inputs),
          .pin_out(signal_inst_1[19:0]),
          .pin_dir(signal_inst_1[39:20]),
          .pc(signal_inst_1[48:40]),
          .x(signal_inst_1[64:49]),
          .y(signal_inst_1[80:65]),
          .p(signal_inst_1[96:81]),
          .t(signal_inst_1[120:97]),
          .osr(signal_inst_1[136:121]),
          .osr_count(signal_inst_1[141:137]),
          .isr(signal_inst_1[157:142]),
          .isr_count(signal_inst_1[162:158]),
          .now(signal_inst_1[186:163]),
          .stall(signal_inst_1[191:187]),
          .halted(signal_inst_1[192:192]),
          .irq(signal_inst_1[193:193]),
          .fault$underflow(signal_inst_1[194:194]),
          .fault$overflow(signal_inst_1[195:195]),
          .fault$missed_deadline(signal_inst_1[196:196]),
          .fault$decode(signal_inst_1[197:197]),
          .capture(signal_inst_1[221:198]),
          .capture_armed(signal_inst_1[222:222]),
          .tx_level(signal_inst_1[226:223]),
          .rx_level(signal_inst_1[230:227]),
          .rx_head(signal_inst_1[246:231]),
          .instruction(signal_inst_1[262:247]),
          .decode_ok(signal_inst_1[263:263]),
          .opcode_onehot(signal_inst_1[271:264]),
          .crc(signal_inst_1[287:272]),
          .stuff_run(signal_inst_1[292:288]) );
    assign signal_select_55 = signal_inst_1[19:0];
    assign signal_select_56 = signal_select_55[11:5];
    assign signal_cat = { signal_select_56,
                          signal_select_3 };
    assign uo_out = signal_cat;
    assign uio_out = signal_select_2;
    assign uio_oe = signal_select_1;

endmodule
module protocol_emulator (
    clk,
    rst_n,
    ena,
    ui_in,
    uio_in,
    uo_out,
    uio_out,
    uio_oe
);

    input clk;
    input rst_n;
    input ena;
    input [7:0] ui_in;
    input [7:0] uio_in;
    output [7:0] uo_out;
    output [7:0] uio_out;
    output [7:0] uio_oe;

    wire [7:0] signal_select;
    wire [7:0] signal_select_1;
    wire [7:0] signal_wire;
    wire [7:0] signal_wire_1;
    wire signal_wire_2;
    wire signal_wire_3;
    wire signal_wire_4;
    wire [23:0] signal_inst;
    wire [7:0] signal_select_2;
    assign signal_select = signal_inst[23:16];
    assign signal_select_1 = signal_inst[15:8];
    assign signal_wire = uio_in;
    assign signal_wire_1 = ui_in;
    assign signal_wire_2 = ena;
    assign signal_wire_3 = rst_n;
    assign signal_wire_4 = clk;
    top
        top
        ( .clk(signal_wire_4),
          .rst_n(signal_wire_3),
          .ena(signal_wire_2),
          .ui_in(signal_wire_1),
          .uio_in(signal_wire),
          .uo_out(signal_inst[7:0]),
          .uio_out(signal_inst[15:8]),
          .uio_oe(signal_inst[23:16]) );
    assign signal_select_2 = signal_inst[7:0];
    assign uo_out = signal_select_2;
    assign uio_out = signal_select_1;
    assign uio_oe = signal_select;

endmodule

