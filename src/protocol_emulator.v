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
    output [2:0] level;
    output empty;
    output full;

    wire signal_or;
    wire [15:0] signal_const;
    reg [15:0] data_before_collision;
    wire [15:0] signal_wire;
    (* RAM_STYLE="block" *)
    reg [15:0] signal_multiport_mem[0:3];
    wire [15:0] signal_mem_read_port;
    reg [15:0] ram_rbw_data;
    wire [1:0] signal_const_1;
    wire [1:0] signal_const_2;
    wire [1:0] READ_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [1:0] READ_ADDRESS;
    wire [1:0] signal_wire_1;
    wire signal_and;
    wire [1:0] RA;
    wire [1:0] WRITE_ADDRESS_NEXT;
    (* extract_reset="FALSE" *)
    reg [1:0] WRITE_ADDRESS;
    wire [1:0] signal_wire_2;
    wire signal_eq;
    wire signal_not;
    wire signal_and_1;
    wire signal_xor;
    wire signal_const_5;
    wire [2:0] signal_const_6;
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
    wire [2:0] signal_const_10;
    wire [2:0] signal_const_11;
    wire [2:0] signal_sub;
    reg [2:0] USED_MINUS_1 = 3'b111;
    wire [2:0] signal_wire_3;
    wire [2:0] signal_add;
    reg [2:0] USED_PLUS_1 = 3'b001;
    wire [2:0] signal_wire_4;
    wire [2:0] signal_mux;
    reg [2:0] USED;
    wire [2:0] signal_wire_5;
    wire [2:0] signal_const_17;
    wire signal_eq_2;
    reg full_0;
    wire signal_wire_6;
    wire signal_wire_7;
    wire signal_not_1;
    wire signal_not_2;
    wire signal_wire_8;
    wire signal_wire_9;
    wire [2:0] signal_const_19;
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
    wire [2:0] USED_NEXT;
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
    assign signal_const_1 = 2'b00;
    assign signal_const_2 = 2'b01;
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
    assign signal_const_6 = 3'b001;
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
    assign signal_const_10 = 3'b000;
    assign signal_const_11 = 3'b111;
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
    assign signal_const_17 = 3'b101;
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
    assign signal_const_19 = 3'b100;
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
    output [2:0] tx_level;
    output [2:0] rx_level;
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
    wire [2:0] signal_select_1;
    wire [2:0] signal_select_2;
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
    wire signal_select_4;
    wire signal_select_5;
    wire signal_select_6;
    wire signal_select_7;
    wire signal_select_8;
    wire signal_select_9;
    wire signal_select_10;
    wire signal_select_11;
    wire signal_select_12;
    wire signal_select_13;
    wire signal_select_14;
    wire signal_select_15;
    wire signal_select_16;
    wire signal_select_17;
    wire signal_select_18;
    wire signal_select_19;
    wire signal_select_20;
    wire signal_select_21;
    wire signal_select_22;
    wire signal_select_23;
    wire signal_select_24;
    wire [3:0] signal_select_25;
    reg signal_mux_2;
    wire signal_select_26;
    wire [5:0] signal_cat_1;
    wire [5:0] signal_cat_2;
    wire [5:0] signal_const_11;
    wire [5:0] signal_sub_2;
    wire [5:0] signal_cat_3;
    wire [5:0] signal_const_12;
    wire [5:0] signal_sub_3;
    wire [4:0] signal_const_13;
    wire signal_lt;
    wire [5:0] signal_mux_3;
    wire signal_lt_1;
    wire signal_mux_4;
    wire signal_select_27;
    wire signal_select_28;
    wire signal_select_29;
    wire signal_select_30;
    wire signal_select_31;
    wire signal_select_32;
    wire signal_select_33;
    wire signal_select_34;
    wire signal_select_35;
    wire signal_select_36;
    wire signal_select_37;
    wire signal_select_38;
    wire signal_select_39;
    wire signal_select_40;
    wire signal_select_41;
    wire signal_select_42;
    wire [3:0] signal_select_43;
    reg signal_mux_5;
    wire signal_select_44;
    wire [5:0] signal_cat_4;
    wire [5:0] signal_cat_5;
    wire [5:0] signal_const_14;
    wire [5:0] signal_sub_4;
    wire [5:0] signal_cat_6;
    wire [5:0] signal_const_15;
    wire [5:0] signal_sub_5;
    wire [4:0] signal_const_16;
    wire signal_lt_2;
    wire [5:0] signal_mux_6;
    wire signal_lt_3;
    wire signal_mux_7;
    wire signal_select_45;
    wire signal_select_46;
    wire signal_select_47;
    wire signal_select_48;
    wire signal_select_49;
    wire signal_select_50;
    wire signal_select_51;
    wire signal_select_52;
    wire signal_select_53;
    wire signal_select_54;
    wire signal_select_55;
    wire signal_select_56;
    wire signal_select_57;
    wire signal_select_58;
    wire signal_select_59;
    wire signal_select_60;
    wire [3:0] signal_select_61;
    reg signal_mux_8;
    wire signal_select_62;
    wire [5:0] signal_cat_7;
    wire [5:0] signal_cat_8;
    wire [5:0] signal_const_17;
    wire [5:0] signal_sub_6;
    wire [5:0] signal_cat_9;
    wire [5:0] signal_const_18;
    wire [5:0] signal_sub_7;
    wire [4:0] signal_const_19;
    wire signal_lt_4;
    wire [5:0] signal_mux_9;
    wire signal_lt_5;
    wire signal_mux_10;
    wire signal_select_63;
    wire signal_select_64;
    wire signal_select_65;
    wire signal_select_66;
    wire signal_select_67;
    wire signal_select_68;
    wire signal_select_69;
    wire signal_select_70;
    wire signal_select_71;
    wire signal_select_72;
    wire signal_select_73;
    wire signal_select_74;
    wire signal_select_75;
    wire signal_select_76;
    wire signal_select_77;
    wire signal_select_78;
    wire [3:0] signal_select_79;
    reg signal_mux_11;
    wire signal_select_80;
    wire [5:0] signal_cat_10;
    wire [5:0] signal_cat_11;
    wire [5:0] signal_const_20;
    wire [5:0] signal_sub_8;
    wire [5:0] signal_cat_12;
    wire [5:0] signal_const_21;
    wire [5:0] signal_sub_9;
    wire [4:0] signal_const_22;
    wire signal_lt_6;
    wire [5:0] signal_mux_12;
    wire signal_lt_7;
    wire signal_mux_13;
    wire signal_select_81;
    wire signal_select_82;
    wire signal_select_83;
    wire signal_select_84;
    wire signal_select_85;
    wire signal_select_86;
    wire signal_select_87;
    wire signal_select_88;
    wire signal_select_89;
    wire signal_select_90;
    wire signal_select_91;
    wire signal_select_92;
    wire signal_select_93;
    wire signal_select_94;
    wire signal_select_95;
    wire signal_select_96;
    wire [3:0] signal_select_97;
    reg signal_mux_14;
    wire signal_select_98;
    wire [5:0] signal_cat_13;
    wire [5:0] signal_cat_14;
    wire [5:0] signal_const_23;
    wire [5:0] signal_sub_10;
    wire [5:0] signal_cat_15;
    wire [5:0] signal_const_24;
    wire [5:0] signal_sub_11;
    wire [4:0] signal_const_25;
    wire signal_lt_8;
    wire [5:0] signal_mux_15;
    wire signal_lt_9;
    wire signal_mux_16;
    wire signal_select_99;
    wire signal_select_100;
    wire signal_select_101;
    wire signal_select_102;
    wire signal_select_103;
    wire signal_select_104;
    wire signal_select_105;
    wire signal_select_106;
    wire signal_select_107;
    wire signal_select_108;
    wire signal_select_109;
    wire signal_select_110;
    wire signal_select_111;
    wire signal_select_112;
    wire signal_select_113;
    wire signal_select_114;
    wire [3:0] signal_select_115;
    reg signal_mux_17;
    wire signal_select_116;
    wire [5:0] signal_cat_16;
    wire [5:0] signal_cat_17;
    wire [5:0] signal_const_26;
    wire [5:0] signal_sub_12;
    wire [5:0] signal_cat_18;
    wire [5:0] signal_const_27;
    wire [5:0] signal_sub_13;
    wire [4:0] signal_const_28;
    wire signal_lt_10;
    wire [5:0] signal_mux_18;
    wire signal_lt_11;
    wire signal_mux_19;
    wire signal_select_117;
    wire signal_select_118;
    wire signal_select_119;
    wire signal_select_120;
    wire signal_select_121;
    wire signal_select_122;
    wire signal_select_123;
    wire signal_select_124;
    wire signal_select_125;
    wire signal_select_126;
    wire signal_select_127;
    wire signal_select_128;
    wire signal_select_129;
    wire signal_select_130;
    wire signal_select_131;
    wire signal_select_132;
    wire [3:0] signal_select_133;
    reg signal_mux_20;
    wire signal_select_134;
    wire [5:0] signal_cat_19;
    wire [5:0] signal_cat_20;
    wire [5:0] signal_const_29;
    wire [5:0] signal_sub_14;
    wire [5:0] signal_cat_21;
    wire [5:0] signal_const_30;
    wire [5:0] signal_sub_15;
    wire [4:0] signal_const_31;
    wire signal_lt_12;
    wire [5:0] signal_mux_21;
    wire signal_lt_13;
    wire signal_mux_22;
    wire signal_select_135;
    wire signal_select_136;
    wire signal_select_137;
    wire signal_select_138;
    wire signal_select_139;
    wire signal_select_140;
    wire signal_select_141;
    wire signal_select_142;
    wire signal_select_143;
    wire signal_select_144;
    wire signal_select_145;
    wire signal_select_146;
    wire signal_select_147;
    wire signal_select_148;
    wire signal_select_149;
    wire signal_select_150;
    wire [3:0] signal_select_151;
    reg signal_mux_23;
    wire signal_select_152;
    wire [5:0] signal_cat_22;
    wire [5:0] signal_cat_23;
    wire [5:0] signal_const_32;
    wire [5:0] signal_sub_16;
    wire [5:0] signal_cat_24;
    wire [5:0] signal_const_33;
    wire [5:0] signal_sub_17;
    wire [4:0] signal_const_34;
    wire signal_lt_14;
    wire [5:0] signal_mux_24;
    wire signal_lt_15;
    wire signal_mux_25;
    wire signal_select_153;
    wire signal_select_154;
    wire signal_select_155;
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
    wire [3:0] signal_select_169;
    reg signal_mux_26;
    wire signal_select_170;
    wire [5:0] signal_cat_25;
    wire [5:0] signal_cat_26;
    wire [5:0] signal_const_35;
    wire [5:0] signal_sub_18;
    wire [5:0] signal_cat_27;
    wire [5:0] signal_const_36;
    wire [5:0] signal_sub_19;
    wire [4:0] signal_const_37;
    wire signal_lt_16;
    wire [5:0] signal_mux_27;
    wire signal_lt_17;
    wire signal_mux_28;
    wire signal_select_171;
    wire signal_select_172;
    wire signal_select_173;
    wire signal_select_174;
    wire signal_select_175;
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
    wire [3:0] signal_select_187;
    reg signal_mux_29;
    wire signal_select_188;
    wire [5:0] signal_cat_28;
    wire [5:0] signal_cat_29;
    wire [5:0] signal_const_38;
    wire [5:0] signal_sub_20;
    wire [5:0] signal_cat_30;
    wire [5:0] signal_const_39;
    wire [5:0] signal_sub_21;
    wire [4:0] signal_const_40;
    wire signal_lt_18;
    wire [5:0] signal_mux_30;
    wire signal_lt_19;
    wire signal_mux_31;
    wire signal_select_189;
    wire signal_select_190;
    wire signal_select_191;
    wire signal_select_192;
    wire signal_select_193;
    wire signal_select_194;
    wire signal_select_195;
    wire signal_select_196;
    wire signal_select_197;
    wire signal_select_198;
    wire signal_select_199;
    wire signal_select_200;
    wire signal_select_201;
    wire signal_select_202;
    wire signal_select_203;
    wire signal_select_204;
    wire [3:0] signal_select_205;
    reg signal_mux_32;
    wire signal_select_206;
    wire [5:0] signal_cat_31;
    wire [5:0] signal_cat_32;
    wire [5:0] signal_const_41;
    wire [5:0] signal_sub_22;
    wire [5:0] signal_cat_33;
    wire [5:0] signal_const_42;
    wire [5:0] signal_sub_23;
    wire [4:0] signal_const_43;
    wire signal_lt_20;
    wire [5:0] signal_mux_33;
    wire signal_lt_21;
    wire signal_mux_34;
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
    wire signal_select_221;
    wire signal_select_222;
    wire [3:0] signal_select_223;
    reg signal_mux_35;
    wire signal_select_224;
    wire [5:0] signal_cat_34;
    wire [5:0] signal_cat_35;
    wire [5:0] signal_const_44;
    wire [5:0] signal_sub_24;
    wire [5:0] signal_cat_36;
    wire [5:0] signal_const_45;
    wire [5:0] signal_sub_25;
    wire [4:0] signal_const_46;
    wire signal_lt_22;
    wire [5:0] signal_mux_36;
    wire signal_lt_23;
    wire signal_mux_37;
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
    wire [3:0] signal_select_241;
    reg signal_mux_38;
    wire signal_select_242;
    wire [5:0] signal_cat_37;
    wire [5:0] signal_cat_38;
    wire [5:0] signal_const_47;
    wire [5:0] signal_sub_26;
    wire [5:0] signal_cat_39;
    wire [5:0] signal_const_48;
    wire [5:0] signal_sub_27;
    wire [4:0] signal_const_49;
    wire signal_lt_24;
    wire [5:0] signal_mux_39;
    wire signal_lt_25;
    wire signal_mux_40;
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
    wire [3:0] signal_select_259;
    reg signal_mux_41;
    wire signal_select_260;
    wire [5:0] signal_cat_40;
    wire [5:0] signal_cat_41;
    wire [5:0] signal_const_50;
    wire [5:0] signal_sub_28;
    wire [5:0] signal_cat_42;
    wire [5:0] signal_const_51;
    wire [5:0] signal_sub_29;
    wire [4:0] signal_const_52;
    wire signal_lt_26;
    wire [5:0] signal_mux_42;
    wire signal_lt_27;
    wire signal_mux_43;
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
    wire [10:0] signal_const_53;
    wire [15:0] signal_cat_43;
    wire signal_select_276;
    wire [3:0] signal_select_277;
    reg signal_mux_44;
    wire signal_select_278;
    wire [5:0] signal_cat_44;
    wire [5:0] signal_cat_45;
    wire [5:0] signal_const_54;
    wire [5:0] signal_sub_30;
    wire [5:0] signal_cat_46;
    wire [5:0] signal_const_55;
    wire [5:0] signal_sub_31;
    wire [4:0] signal_const_56;
    wire signal_lt_28;
    wire [5:0] signal_mux_45;
    wire signal_lt_29;
    wire signal_mux_46;
    wire [19:0] signal_cat_47;
    wire [2:0] signal_const_57;
    wire signal_eq_5;
    wire [19:0] signal_mux_47;
    wire signal_select_279;
    wire signal_select_280;
    wire signal_select_281;
    wire signal_select_282;
    wire signal_select_283;
    wire signal_select_284;
    wire signal_select_285;
    wire signal_select_286;
    wire signal_select_287;
    wire signal_select_288;
    wire signal_select_289;
    wire signal_select_290;
    wire signal_select_291;
    wire signal_select_292;
    wire signal_select_293;
    wire signal_select_294;
    wire signal_select_295;
    wire signal_select_296;
    wire signal_select_297;
    wire signal_select_298;
    wire signal_select_299;
    wire [3:0] signal_select_300;
    reg signal_mux_48;
    wire signal_select_301;
    wire [5:0] signal_cat_48;
    wire [5:0] signal_cat_49;
    wire [5:0] signal_sub_32;
    wire [5:0] signal_cat_50;
    wire [5:0] signal_sub_33;
    wire signal_lt_30;
    wire [5:0] signal_mux_49;
    wire signal_lt_31;
    wire signal_mux_50;
    wire signal_select_302;
    wire signal_select_303;
    wire signal_select_304;
    wire signal_select_305;
    wire signal_select_306;
    wire signal_select_307;
    wire signal_select_308;
    wire signal_select_309;
    wire signal_select_310;
    wire signal_select_311;
    wire signal_select_312;
    wire signal_select_313;
    wire signal_select_314;
    wire signal_select_315;
    wire signal_select_316;
    wire signal_select_317;
    wire [3:0] signal_select_318;
    reg signal_mux_51;
    wire signal_select_319;
    wire [5:0] signal_cat_51;
    wire [5:0] signal_cat_52;
    wire [5:0] signal_sub_34;
    wire [5:0] signal_cat_53;
    wire [5:0] signal_sub_35;
    wire signal_lt_32;
    wire [5:0] signal_mux_52;
    wire signal_lt_33;
    wire signal_mux_53;
    wire signal_select_320;
    wire signal_select_321;
    wire signal_select_322;
    wire signal_select_323;
    wire signal_select_324;
    wire signal_select_325;
    wire signal_select_326;
    wire signal_select_327;
    wire signal_select_328;
    wire signal_select_329;
    wire signal_select_330;
    wire signal_select_331;
    wire signal_select_332;
    wire signal_select_333;
    wire signal_select_334;
    wire signal_select_335;
    wire [3:0] signal_select_336;
    reg signal_mux_54;
    wire signal_select_337;
    wire [5:0] signal_cat_54;
    wire [5:0] signal_cat_55;
    wire [5:0] signal_sub_36;
    wire [5:0] signal_cat_56;
    wire [5:0] signal_sub_37;
    wire signal_lt_34;
    wire [5:0] signal_mux_55;
    wire signal_lt_35;
    wire signal_mux_56;
    wire signal_select_338;
    wire signal_select_339;
    wire signal_select_340;
    wire signal_select_341;
    wire signal_select_342;
    wire signal_select_343;
    wire signal_select_344;
    wire signal_select_345;
    wire signal_select_346;
    wire signal_select_347;
    wire signal_select_348;
    wire signal_select_349;
    wire signal_select_350;
    wire signal_select_351;
    wire signal_select_352;
    wire signal_select_353;
    wire [3:0] signal_select_354;
    reg signal_mux_57;
    wire signal_select_355;
    wire [5:0] signal_cat_57;
    wire [5:0] signal_cat_58;
    wire [5:0] signal_sub_38;
    wire [5:0] signal_cat_59;
    wire [5:0] signal_sub_39;
    wire signal_lt_36;
    wire [5:0] signal_mux_58;
    wire signal_lt_37;
    wire signal_mux_59;
    wire signal_select_356;
    wire signal_select_357;
    wire signal_select_358;
    wire signal_select_359;
    wire signal_select_360;
    wire signal_select_361;
    wire signal_select_362;
    wire signal_select_363;
    wire signal_select_364;
    wire signal_select_365;
    wire signal_select_366;
    wire signal_select_367;
    wire signal_select_368;
    wire signal_select_369;
    wire signal_select_370;
    wire signal_select_371;
    wire [3:0] signal_select_372;
    reg signal_mux_60;
    wire signal_select_373;
    wire [5:0] signal_cat_60;
    wire [5:0] signal_cat_61;
    wire [5:0] signal_sub_40;
    wire [5:0] signal_cat_62;
    wire [5:0] signal_sub_41;
    wire signal_lt_38;
    wire [5:0] signal_mux_61;
    wire signal_lt_39;
    wire signal_mux_62;
    wire signal_select_374;
    wire signal_select_375;
    wire signal_select_376;
    wire signal_select_377;
    wire signal_select_378;
    wire signal_select_379;
    wire signal_select_380;
    wire signal_select_381;
    wire signal_select_382;
    wire signal_select_383;
    wire signal_select_384;
    wire signal_select_385;
    wire signal_select_386;
    wire signal_select_387;
    wire signal_select_388;
    wire signal_select_389;
    wire [3:0] signal_select_390;
    reg signal_mux_63;
    wire signal_select_391;
    wire [5:0] signal_cat_63;
    wire [5:0] signal_cat_64;
    wire [5:0] signal_sub_42;
    wire [5:0] signal_cat_65;
    wire [5:0] signal_sub_43;
    wire signal_lt_40;
    wire [5:0] signal_mux_64;
    wire signal_lt_41;
    wire signal_mux_65;
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
    wire signal_select_403;
    wire signal_select_404;
    wire signal_select_405;
    wire signal_select_406;
    wire signal_select_407;
    wire [3:0] signal_select_408;
    reg signal_mux_66;
    wire signal_select_409;
    wire [5:0] signal_cat_66;
    wire [5:0] signal_cat_67;
    wire [5:0] signal_sub_44;
    wire [5:0] signal_cat_68;
    wire [5:0] signal_sub_45;
    wire signal_lt_42;
    wire [5:0] signal_mux_67;
    wire signal_lt_43;
    wire signal_mux_68;
    wire signal_select_410;
    wire signal_select_411;
    wire signal_select_412;
    wire signal_select_413;
    wire signal_select_414;
    wire signal_select_415;
    wire signal_select_416;
    wire signal_select_417;
    wire signal_select_418;
    wire signal_select_419;
    wire signal_select_420;
    wire signal_select_421;
    wire signal_select_422;
    wire signal_select_423;
    wire signal_select_424;
    wire signal_select_425;
    wire [3:0] signal_select_426;
    reg signal_mux_69;
    wire signal_select_427;
    wire [5:0] signal_cat_69;
    wire [5:0] signal_cat_70;
    wire [5:0] signal_sub_46;
    wire [5:0] signal_cat_71;
    wire [5:0] signal_sub_47;
    wire signal_lt_44;
    wire [5:0] signal_mux_70;
    wire signal_lt_45;
    wire signal_mux_71;
    wire signal_select_428;
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
    wire [3:0] signal_select_444;
    reg signal_mux_72;
    wire signal_select_445;
    wire [5:0] signal_cat_72;
    wire [5:0] signal_cat_73;
    wire [5:0] signal_sub_48;
    wire [5:0] signal_cat_74;
    wire [5:0] signal_sub_49;
    wire signal_lt_46;
    wire [5:0] signal_mux_73;
    wire signal_lt_47;
    wire signal_mux_74;
    wire signal_select_446;
    wire signal_select_447;
    wire signal_select_448;
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
    wire [3:0] signal_select_462;
    reg signal_mux_75;
    wire signal_select_463;
    wire [5:0] signal_cat_75;
    wire [5:0] signal_cat_76;
    wire [5:0] signal_sub_50;
    wire [5:0] signal_cat_77;
    wire [5:0] signal_sub_51;
    wire signal_lt_48;
    wire [5:0] signal_mux_76;
    wire signal_lt_49;
    wire signal_mux_77;
    wire signal_select_464;
    wire signal_select_465;
    wire signal_select_466;
    wire signal_select_467;
    wire signal_select_468;
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
    wire [3:0] signal_select_480;
    reg signal_mux_78;
    wire signal_select_481;
    wire [5:0] signal_cat_78;
    wire [5:0] signal_cat_79;
    wire [5:0] signal_sub_52;
    wire [5:0] signal_cat_80;
    wire [5:0] signal_sub_53;
    wire signal_lt_50;
    wire [5:0] signal_mux_79;
    wire signal_lt_51;
    wire signal_mux_80;
    wire signal_select_482;
    wire signal_select_483;
    wire signal_select_484;
    wire signal_select_485;
    wire signal_select_486;
    wire signal_select_487;
    wire signal_select_488;
    wire signal_select_489;
    wire signal_select_490;
    wire signal_select_491;
    wire signal_select_492;
    wire signal_select_493;
    wire signal_select_494;
    wire signal_select_495;
    wire signal_select_496;
    wire signal_select_497;
    wire [3:0] signal_select_498;
    reg signal_mux_81;
    wire signal_select_499;
    wire [5:0] signal_cat_81;
    wire [5:0] signal_cat_82;
    wire [5:0] signal_sub_54;
    wire [5:0] signal_cat_83;
    wire [5:0] signal_sub_55;
    wire signal_lt_52;
    wire [5:0] signal_mux_82;
    wire signal_lt_53;
    wire signal_mux_83;
    wire signal_select_500;
    wire signal_select_501;
    wire signal_select_502;
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
    wire [3:0] signal_select_516;
    reg signal_mux_84;
    wire signal_select_517;
    wire [5:0] signal_cat_84;
    wire [5:0] signal_cat_85;
    wire [5:0] signal_sub_56;
    wire [5:0] signal_cat_86;
    wire [5:0] signal_sub_57;
    wire signal_lt_54;
    wire [5:0] signal_mux_85;
    wire signal_lt_55;
    wire signal_mux_86;
    wire signal_select_518;
    wire signal_select_519;
    wire signal_select_520;
    wire signal_select_521;
    wire signal_select_522;
    wire signal_select_523;
    wire signal_select_524;
    wire signal_select_525;
    wire signal_select_526;
    wire signal_select_527;
    wire signal_select_528;
    wire signal_select_529;
    wire signal_select_530;
    wire signal_select_531;
    wire signal_select_532;
    wire signal_select_533;
    wire [3:0] signal_select_534;
    reg signal_mux_87;
    wire signal_select_535;
    wire [5:0] signal_cat_87;
    wire [5:0] signal_cat_88;
    wire [5:0] signal_sub_58;
    wire [5:0] signal_cat_89;
    wire [5:0] signal_sub_59;
    wire signal_lt_56;
    wire [5:0] signal_mux_88;
    wire signal_lt_57;
    wire signal_mux_89;
    wire signal_select_536;
    wire signal_select_537;
    wire signal_select_538;
    wire signal_select_539;
    wire signal_select_540;
    wire signal_select_541;
    wire signal_select_542;
    wire signal_select_543;
    wire signal_select_544;
    wire signal_select_545;
    wire signal_select_546;
    wire signal_select_547;
    wire signal_select_548;
    wire signal_select_549;
    wire signal_select_550;
    wire signal_select_551;
    wire [3:0] signal_select_552;
    reg signal_mux_90;
    wire signal_select_553;
    wire [5:0] signal_cat_90;
    wire [5:0] signal_cat_91;
    wire [5:0] signal_sub_60;
    wire [5:0] signal_cat_92;
    wire [5:0] signal_sub_61;
    wire signal_lt_58;
    wire [5:0] signal_mux_91;
    wire signal_lt_59;
    wire signal_mux_92;
    wire [19:0] signal_cat_93;
    wire signal_eq_6;
    wire [19:0] signal_mux_93;
    wire signal_select_554;
    wire signal_select_555;
    wire signal_select_556;
    wire signal_select_557;
    wire signal_select_558;
    wire signal_select_559;
    wire signal_select_560;
    wire signal_select_561;
    wire signal_select_562;
    wire signal_select_563;
    wire signal_select_564;
    wire signal_select_565;
    wire signal_select_566;
    wire signal_select_567;
    wire signal_select_568;
    wire signal_select_569;
    wire signal_select_570;
    wire signal_select_571;
    wire signal_select_572;
    wire signal_select_573;
    wire signal_select_574;
    wire [3:0] signal_select_575;
    reg signal_mux_94;
    wire signal_select_576;
    wire [5:0] signal_cat_94;
    wire [5:0] signal_cat_95;
    wire [5:0] signal_sub_62;
    wire [5:0] signal_cat_96;
    wire [5:0] signal_sub_63;
    wire signal_lt_60;
    wire [5:0] signal_mux_95;
    wire signal_lt_61;
    wire signal_mux_96;
    wire signal_select_577;
    wire signal_select_578;
    wire signal_select_579;
    wire signal_select_580;
    wire signal_select_581;
    wire signal_select_582;
    wire signal_select_583;
    wire signal_select_584;
    wire signal_select_585;
    wire signal_select_586;
    wire signal_select_587;
    wire signal_select_588;
    wire signal_select_589;
    wire signal_select_590;
    wire signal_select_591;
    wire signal_select_592;
    wire [3:0] signal_select_593;
    reg signal_mux_97;
    wire signal_select_594;
    wire [5:0] signal_cat_97;
    wire [5:0] signal_cat_98;
    wire [5:0] signal_sub_64;
    wire [5:0] signal_cat_99;
    wire [5:0] signal_sub_65;
    wire signal_lt_62;
    wire [5:0] signal_mux_98;
    wire signal_lt_63;
    wire signal_mux_99;
    wire signal_select_595;
    wire signal_select_596;
    wire signal_select_597;
    wire signal_select_598;
    wire signal_select_599;
    wire signal_select_600;
    wire signal_select_601;
    wire signal_select_602;
    wire signal_select_603;
    wire signal_select_604;
    wire signal_select_605;
    wire signal_select_606;
    wire signal_select_607;
    wire signal_select_608;
    wire signal_select_609;
    wire signal_select_610;
    wire [3:0] signal_select_611;
    reg signal_mux_100;
    wire signal_select_612;
    wire [5:0] signal_cat_100;
    wire [5:0] signal_cat_101;
    wire [5:0] signal_sub_66;
    wire [5:0] signal_cat_102;
    wire [5:0] signal_sub_67;
    wire signal_lt_64;
    wire [5:0] signal_mux_101;
    wire signal_lt_65;
    wire signal_mux_102;
    wire signal_select_613;
    wire signal_select_614;
    wire signal_select_615;
    wire signal_select_616;
    wire signal_select_617;
    wire signal_select_618;
    wire signal_select_619;
    wire signal_select_620;
    wire signal_select_621;
    wire signal_select_622;
    wire signal_select_623;
    wire signal_select_624;
    wire signal_select_625;
    wire signal_select_626;
    wire signal_select_627;
    wire signal_select_628;
    wire [3:0] signal_select_629;
    reg signal_mux_103;
    wire signal_select_630;
    wire [5:0] signal_cat_103;
    wire [5:0] signal_cat_104;
    wire [5:0] signal_sub_68;
    wire [5:0] signal_cat_105;
    wire [5:0] signal_sub_69;
    wire signal_lt_66;
    wire [5:0] signal_mux_104;
    wire signal_lt_67;
    wire signal_mux_105;
    wire signal_select_631;
    wire signal_select_632;
    wire signal_select_633;
    wire signal_select_634;
    wire signal_select_635;
    wire signal_select_636;
    wire signal_select_637;
    wire signal_select_638;
    wire signal_select_639;
    wire signal_select_640;
    wire signal_select_641;
    wire signal_select_642;
    wire signal_select_643;
    wire signal_select_644;
    wire signal_select_645;
    wire signal_select_646;
    wire [3:0] signal_select_647;
    reg signal_mux_106;
    wire signal_select_648;
    wire [5:0] signal_cat_106;
    wire [5:0] signal_cat_107;
    wire [5:0] signal_sub_70;
    wire [5:0] signal_cat_108;
    wire [5:0] signal_sub_71;
    wire signal_lt_68;
    wire [5:0] signal_mux_107;
    wire signal_lt_69;
    wire signal_mux_108;
    wire signal_select_649;
    wire signal_select_650;
    wire signal_select_651;
    wire signal_select_652;
    wire signal_select_653;
    wire signal_select_654;
    wire signal_select_655;
    wire signal_select_656;
    wire signal_select_657;
    wire signal_select_658;
    wire signal_select_659;
    wire signal_select_660;
    wire signal_select_661;
    wire signal_select_662;
    wire signal_select_663;
    wire signal_select_664;
    wire [3:0] signal_select_665;
    reg signal_mux_109;
    wire signal_select_666;
    wire [5:0] signal_cat_109;
    wire [5:0] signal_cat_110;
    wire [5:0] signal_sub_72;
    wire [5:0] signal_cat_111;
    wire [5:0] signal_sub_73;
    wire signal_lt_70;
    wire [5:0] signal_mux_110;
    wire signal_lt_71;
    wire signal_mux_111;
    wire signal_select_667;
    wire signal_select_668;
    wire signal_select_669;
    wire signal_select_670;
    wire signal_select_671;
    wire signal_select_672;
    wire signal_select_673;
    wire signal_select_674;
    wire signal_select_675;
    wire signal_select_676;
    wire signal_select_677;
    wire signal_select_678;
    wire signal_select_679;
    wire signal_select_680;
    wire signal_select_681;
    wire signal_select_682;
    wire [3:0] signal_select_683;
    reg signal_mux_112;
    wire signal_select_684;
    wire [5:0] signal_cat_112;
    wire [5:0] signal_cat_113;
    wire [5:0] signal_sub_74;
    wire [5:0] signal_cat_114;
    wire [5:0] signal_sub_75;
    wire signal_lt_72;
    wire [5:0] signal_mux_113;
    wire signal_lt_73;
    wire signal_mux_114;
    wire signal_select_685;
    wire signal_select_686;
    wire signal_select_687;
    wire signal_select_688;
    wire signal_select_689;
    wire signal_select_690;
    wire signal_select_691;
    wire signal_select_692;
    wire signal_select_693;
    wire signal_select_694;
    wire signal_select_695;
    wire signal_select_696;
    wire signal_select_697;
    wire signal_select_698;
    wire signal_select_699;
    wire signal_select_700;
    wire [3:0] signal_select_701;
    reg signal_mux_115;
    wire signal_select_702;
    wire [5:0] signal_cat_115;
    wire [5:0] signal_cat_116;
    wire [5:0] signal_sub_76;
    wire [5:0] signal_cat_117;
    wire [5:0] signal_sub_77;
    wire signal_lt_74;
    wire [5:0] signal_mux_116;
    wire signal_lt_75;
    wire signal_mux_117;
    wire signal_select_703;
    wire signal_select_704;
    wire signal_select_705;
    wire signal_select_706;
    wire signal_select_707;
    wire signal_select_708;
    wire signal_select_709;
    wire signal_select_710;
    wire signal_select_711;
    wire signal_select_712;
    wire signal_select_713;
    wire signal_select_714;
    wire signal_select_715;
    wire signal_select_716;
    wire signal_select_717;
    wire signal_select_718;
    wire [3:0] signal_select_719;
    reg signal_mux_118;
    wire signal_select_720;
    wire [5:0] signal_cat_118;
    wire [5:0] signal_cat_119;
    wire [5:0] signal_sub_78;
    wire [5:0] signal_cat_120;
    wire [5:0] signal_sub_79;
    wire signal_lt_76;
    wire [5:0] signal_mux_119;
    wire signal_lt_77;
    wire signal_mux_120;
    wire signal_select_721;
    wire signal_select_722;
    wire signal_select_723;
    wire signal_select_724;
    wire signal_select_725;
    wire signal_select_726;
    wire signal_select_727;
    wire signal_select_728;
    wire signal_select_729;
    wire signal_select_730;
    wire signal_select_731;
    wire signal_select_732;
    wire signal_select_733;
    wire signal_select_734;
    wire signal_select_735;
    wire signal_select_736;
    wire [3:0] signal_select_737;
    reg signal_mux_121;
    wire signal_select_738;
    wire [5:0] signal_cat_121;
    wire [5:0] signal_cat_122;
    wire [5:0] signal_sub_80;
    wire [5:0] signal_cat_123;
    wire [5:0] signal_sub_81;
    wire signal_lt_78;
    wire [5:0] signal_mux_122;
    wire signal_lt_79;
    wire signal_mux_123;
    wire signal_select_739;
    wire signal_select_740;
    wire signal_select_741;
    wire signal_select_742;
    wire signal_select_743;
    wire signal_select_744;
    wire signal_select_745;
    wire signal_select_746;
    wire signal_select_747;
    wire signal_select_748;
    wire signal_select_749;
    wire signal_select_750;
    wire signal_select_751;
    wire signal_select_752;
    wire signal_select_753;
    wire signal_select_754;
    wire [3:0] signal_select_755;
    reg signal_mux_124;
    wire signal_select_756;
    wire [5:0] signal_cat_124;
    wire [5:0] signal_cat_125;
    wire [5:0] signal_sub_82;
    wire [5:0] signal_cat_126;
    wire [5:0] signal_sub_83;
    wire signal_lt_80;
    wire [5:0] signal_mux_125;
    wire signal_lt_81;
    wire signal_mux_126;
    wire signal_select_757;
    wire signal_select_758;
    wire signal_select_759;
    wire signal_select_760;
    wire signal_select_761;
    wire signal_select_762;
    wire signal_select_763;
    wire signal_select_764;
    wire signal_select_765;
    wire signal_select_766;
    wire signal_select_767;
    wire signal_select_768;
    wire signal_select_769;
    wire signal_select_770;
    wire signal_select_771;
    wire signal_select_772;
    wire [3:0] signal_select_773;
    reg signal_mux_127;
    wire signal_select_774;
    wire [5:0] signal_cat_127;
    wire [5:0] signal_cat_128;
    wire [5:0] signal_sub_84;
    wire [5:0] signal_cat_129;
    wire [5:0] signal_sub_85;
    wire signal_lt_82;
    wire [5:0] signal_mux_128;
    wire signal_lt_83;
    wire signal_mux_129;
    wire signal_select_775;
    wire signal_select_776;
    wire signal_select_777;
    wire signal_select_778;
    wire signal_select_779;
    wire signal_select_780;
    wire signal_select_781;
    wire signal_select_782;
    wire signal_select_783;
    wire signal_select_784;
    wire signal_select_785;
    wire signal_select_786;
    wire signal_select_787;
    wire signal_select_788;
    wire signal_select_789;
    wire signal_select_790;
    wire [3:0] signal_select_791;
    reg signal_mux_130;
    wire signal_select_792;
    wire [5:0] signal_cat_130;
    wire [5:0] signal_cat_131;
    wire [5:0] signal_sub_86;
    wire [5:0] signal_cat_132;
    wire [5:0] signal_sub_87;
    wire signal_lt_84;
    wire [5:0] signal_mux_131;
    wire signal_lt_85;
    wire signal_mux_132;
    wire signal_select_793;
    wire signal_select_794;
    wire signal_select_795;
    wire signal_select_796;
    wire signal_select_797;
    wire signal_select_798;
    wire signal_select_799;
    wire signal_select_800;
    wire signal_select_801;
    wire signal_select_802;
    wire signal_select_803;
    wire signal_select_804;
    wire signal_select_805;
    wire signal_select_806;
    wire signal_select_807;
    wire signal_select_808;
    wire [3:0] signal_select_809;
    reg signal_mux_133;
    wire signal_select_810;
    wire [5:0] signal_cat_133;
    wire [5:0] signal_cat_134;
    wire [5:0] signal_sub_88;
    wire [5:0] signal_cat_135;
    wire [5:0] signal_sub_89;
    wire signal_lt_86;
    wire [5:0] signal_mux_134;
    wire signal_lt_87;
    wire signal_mux_135;
    wire signal_select_811;
    wire signal_select_812;
    wire signal_select_813;
    wire signal_select_814;
    wire signal_select_815;
    wire signal_select_816;
    wire signal_select_817;
    wire signal_select_818;
    wire signal_select_819;
    wire signal_select_820;
    wire signal_select_821;
    wire signal_select_822;
    wire signal_select_823;
    wire signal_select_824;
    wire signal_select_825;
    wire signal_select_826;
    wire [3:0] signal_select_827;
    reg signal_mux_136;
    wire signal_select_828;
    wire [5:0] signal_cat_136;
    wire [5:0] signal_cat_137;
    wire [5:0] signal_sub_90;
    wire [5:0] signal_cat_138;
    wire [5:0] signal_sub_91;
    wire signal_lt_88;
    wire [5:0] signal_mux_137;
    wire signal_lt_89;
    wire signal_mux_138;
    wire [19:0] signal_cat_139;
    wire signal_eq_7;
    wire [19:0] signal_mux_139;
    wire signal_select_829;
    wire signal_select_830;
    wire signal_select_831;
    wire signal_select_832;
    wire signal_select_833;
    wire signal_select_834;
    wire signal_select_835;
    wire signal_select_836;
    wire signal_select_837;
    wire signal_select_838;
    wire signal_select_839;
    wire signal_select_840;
    wire signal_select_841;
    wire signal_select_842;
    wire signal_select_843;
    wire signal_select_844;
    wire signal_select_845;
    wire signal_select_846;
    wire signal_select_847;
    wire signal_select_848;
    wire signal_select_849;
    wire [3:0] signal_select_850;
    reg signal_mux_140;
    wire signal_select_851;
    wire [5:0] signal_cat_140;
    wire [5:0] signal_cat_141;
    wire [5:0] signal_sub_92;
    wire [5:0] signal_cat_142;
    wire [5:0] signal_sub_93;
    wire signal_lt_90;
    wire [5:0] signal_mux_141;
    wire signal_lt_91;
    wire signal_mux_142;
    wire signal_select_852;
    wire signal_select_853;
    wire signal_select_854;
    wire signal_select_855;
    wire signal_select_856;
    wire signal_select_857;
    wire signal_select_858;
    wire signal_select_859;
    wire signal_select_860;
    wire signal_select_861;
    wire signal_select_862;
    wire signal_select_863;
    wire signal_select_864;
    wire signal_select_865;
    wire signal_select_866;
    wire signal_select_867;
    wire [3:0] signal_select_868;
    reg signal_mux_143;
    wire signal_select_869;
    wire [5:0] signal_cat_143;
    wire [5:0] signal_cat_144;
    wire [5:0] signal_sub_94;
    wire [5:0] signal_cat_145;
    wire [5:0] signal_sub_95;
    wire signal_lt_92;
    wire [5:0] signal_mux_144;
    wire signal_lt_93;
    wire signal_mux_145;
    wire signal_select_870;
    wire signal_select_871;
    wire signal_select_872;
    wire signal_select_873;
    wire signal_select_874;
    wire signal_select_875;
    wire signal_select_876;
    wire signal_select_877;
    wire signal_select_878;
    wire signal_select_879;
    wire signal_select_880;
    wire signal_select_881;
    wire signal_select_882;
    wire signal_select_883;
    wire signal_select_884;
    wire signal_select_885;
    wire [3:0] signal_select_886;
    reg signal_mux_146;
    wire signal_select_887;
    wire [5:0] signal_cat_146;
    wire [5:0] signal_cat_147;
    wire [5:0] signal_sub_96;
    wire [5:0] signal_cat_148;
    wire [5:0] signal_sub_97;
    wire signal_lt_94;
    wire [5:0] signal_mux_147;
    wire signal_lt_95;
    wire signal_mux_148;
    wire signal_select_888;
    wire signal_select_889;
    wire signal_select_890;
    wire signal_select_891;
    wire signal_select_892;
    wire signal_select_893;
    wire signal_select_894;
    wire signal_select_895;
    wire signal_select_896;
    wire signal_select_897;
    wire signal_select_898;
    wire signal_select_899;
    wire signal_select_900;
    wire signal_select_901;
    wire signal_select_902;
    wire signal_select_903;
    wire [3:0] signal_select_904;
    reg signal_mux_149;
    wire signal_select_905;
    wire [5:0] signal_cat_149;
    wire [5:0] signal_cat_150;
    wire [5:0] signal_sub_98;
    wire [5:0] signal_cat_151;
    wire [5:0] signal_sub_99;
    wire signal_lt_96;
    wire [5:0] signal_mux_150;
    wire signal_lt_97;
    wire signal_mux_151;
    wire signal_select_906;
    wire signal_select_907;
    wire signal_select_908;
    wire signal_select_909;
    wire signal_select_910;
    wire signal_select_911;
    wire signal_select_912;
    wire signal_select_913;
    wire signal_select_914;
    wire signal_select_915;
    wire signal_select_916;
    wire signal_select_917;
    wire signal_select_918;
    wire signal_select_919;
    wire signal_select_920;
    wire signal_select_921;
    wire [3:0] signal_select_922;
    reg signal_mux_152;
    wire signal_select_923;
    wire [5:0] signal_cat_152;
    wire [5:0] signal_cat_153;
    wire [5:0] signal_sub_100;
    wire [5:0] signal_cat_154;
    wire [5:0] signal_sub_101;
    wire signal_lt_98;
    wire [5:0] signal_mux_153;
    wire signal_lt_99;
    wire signal_mux_154;
    wire signal_select_924;
    wire signal_select_925;
    wire signal_select_926;
    wire signal_select_927;
    wire signal_select_928;
    wire signal_select_929;
    wire signal_select_930;
    wire signal_select_931;
    wire signal_select_932;
    wire signal_select_933;
    wire signal_select_934;
    wire signal_select_935;
    wire signal_select_936;
    wire signal_select_937;
    wire signal_select_938;
    wire signal_select_939;
    wire [3:0] signal_select_940;
    reg signal_mux_155;
    wire signal_select_941;
    wire [5:0] signal_cat_155;
    wire [5:0] signal_cat_156;
    wire [5:0] signal_sub_102;
    wire [5:0] signal_cat_157;
    wire [5:0] signal_sub_103;
    wire signal_lt_100;
    wire [5:0] signal_mux_156;
    wire signal_lt_101;
    wire signal_mux_157;
    wire signal_select_942;
    wire signal_select_943;
    wire signal_select_944;
    wire signal_select_945;
    wire signal_select_946;
    wire signal_select_947;
    wire signal_select_948;
    wire signal_select_949;
    wire signal_select_950;
    wire signal_select_951;
    wire signal_select_952;
    wire signal_select_953;
    wire signal_select_954;
    wire signal_select_955;
    wire signal_select_956;
    wire signal_select_957;
    wire [3:0] signal_select_958;
    reg signal_mux_158;
    wire signal_select_959;
    wire [5:0] signal_cat_158;
    wire [5:0] signal_cat_159;
    wire [5:0] signal_sub_104;
    wire [5:0] signal_cat_160;
    wire [5:0] signal_sub_105;
    wire signal_lt_102;
    wire [5:0] signal_mux_159;
    wire signal_lt_103;
    wire signal_mux_160;
    wire signal_select_960;
    wire signal_select_961;
    wire signal_select_962;
    wire signal_select_963;
    wire signal_select_964;
    wire signal_select_965;
    wire signal_select_966;
    wire signal_select_967;
    wire signal_select_968;
    wire signal_select_969;
    wire signal_select_970;
    wire signal_select_971;
    wire signal_select_972;
    wire signal_select_973;
    wire signal_select_974;
    wire signal_select_975;
    wire [3:0] signal_select_976;
    reg signal_mux_161;
    wire signal_select_977;
    wire [5:0] signal_cat_161;
    wire [5:0] signal_cat_162;
    wire [5:0] signal_sub_106;
    wire [5:0] signal_cat_163;
    wire [5:0] signal_sub_107;
    wire signal_lt_104;
    wire [5:0] signal_mux_162;
    wire signal_lt_105;
    wire signal_mux_163;
    wire signal_select_978;
    wire signal_select_979;
    wire signal_select_980;
    wire signal_select_981;
    wire signal_select_982;
    wire signal_select_983;
    wire signal_select_984;
    wire signal_select_985;
    wire signal_select_986;
    wire signal_select_987;
    wire signal_select_988;
    wire signal_select_989;
    wire signal_select_990;
    wire signal_select_991;
    wire signal_select_992;
    wire signal_select_993;
    wire [3:0] signal_select_994;
    reg signal_mux_164;
    wire signal_select_995;
    wire [5:0] signal_cat_164;
    wire [5:0] signal_cat_165;
    wire [5:0] signal_sub_108;
    wire [5:0] signal_cat_166;
    wire [5:0] signal_sub_109;
    wire signal_lt_106;
    wire [5:0] signal_mux_165;
    wire signal_lt_107;
    wire signal_mux_166;
    wire signal_select_996;
    wire signal_select_997;
    wire signal_select_998;
    wire signal_select_999;
    wire signal_select_1000;
    wire signal_select_1001;
    wire signal_select_1002;
    wire signal_select_1003;
    wire signal_select_1004;
    wire signal_select_1005;
    wire signal_select_1006;
    wire signal_select_1007;
    wire signal_select_1008;
    wire signal_select_1009;
    wire signal_select_1010;
    wire signal_select_1011;
    wire [3:0] signal_select_1012;
    reg signal_mux_167;
    wire signal_select_1013;
    wire [5:0] signal_cat_167;
    wire [5:0] signal_cat_168;
    wire [5:0] signal_sub_110;
    wire [5:0] signal_cat_169;
    wire [5:0] signal_sub_111;
    wire signal_lt_108;
    wire [5:0] signal_mux_168;
    wire signal_lt_109;
    wire signal_mux_169;
    wire signal_select_1014;
    wire signal_select_1015;
    wire signal_select_1016;
    wire signal_select_1017;
    wire signal_select_1018;
    wire signal_select_1019;
    wire signal_select_1020;
    wire signal_select_1021;
    wire signal_select_1022;
    wire signal_select_1023;
    wire signal_select_1024;
    wire signal_select_1025;
    wire signal_select_1026;
    wire signal_select_1027;
    wire signal_select_1028;
    wire signal_select_1029;
    wire [3:0] signal_select_1030;
    reg signal_mux_170;
    wire signal_select_1031;
    wire [5:0] signal_cat_170;
    wire [5:0] signal_cat_171;
    wire [5:0] signal_sub_112;
    wire [5:0] signal_cat_172;
    wire [5:0] signal_sub_113;
    wire signal_lt_110;
    wire [5:0] signal_mux_171;
    wire signal_lt_111;
    wire signal_mux_172;
    wire signal_select_1032;
    wire signal_select_1033;
    wire signal_select_1034;
    wire signal_select_1035;
    wire signal_select_1036;
    wire signal_select_1037;
    wire signal_select_1038;
    wire signal_select_1039;
    wire signal_select_1040;
    wire signal_select_1041;
    wire signal_select_1042;
    wire signal_select_1043;
    wire signal_select_1044;
    wire signal_select_1045;
    wire signal_select_1046;
    wire signal_select_1047;
    wire [3:0] signal_select_1048;
    reg signal_mux_173;
    wire signal_select_1049;
    wire [5:0] signal_cat_173;
    wire [5:0] signal_cat_174;
    wire [5:0] signal_sub_114;
    wire [5:0] signal_cat_175;
    wire [5:0] signal_sub_115;
    wire signal_lt_112;
    wire [5:0] signal_mux_174;
    wire signal_lt_113;
    wire signal_mux_175;
    wire signal_select_1050;
    wire signal_select_1051;
    wire signal_select_1052;
    wire signal_select_1053;
    wire signal_select_1054;
    wire signal_select_1055;
    wire signal_select_1056;
    wire signal_select_1057;
    wire signal_select_1058;
    wire signal_select_1059;
    wire signal_select_1060;
    wire signal_select_1061;
    wire signal_select_1062;
    wire signal_select_1063;
    wire signal_select_1064;
    wire signal_select_1065;
    wire [3:0] signal_select_1066;
    reg signal_mux_176;
    wire signal_select_1067;
    wire [5:0] signal_cat_176;
    wire [5:0] signal_cat_177;
    wire [5:0] signal_sub_116;
    wire [5:0] signal_cat_178;
    wire [5:0] signal_sub_117;
    wire signal_lt_114;
    wire [5:0] signal_mux_177;
    wire signal_lt_115;
    wire signal_mux_178;
    wire signal_select_1068;
    wire signal_select_1069;
    wire signal_select_1070;
    wire signal_select_1071;
    wire signal_select_1072;
    wire signal_select_1073;
    wire signal_select_1074;
    wire signal_select_1075;
    wire signal_select_1076;
    wire signal_select_1077;
    wire signal_select_1078;
    wire signal_select_1079;
    wire signal_select_1080;
    wire signal_select_1081;
    wire signal_select_1082;
    wire signal_select_1083;
    wire [3:0] signal_select_1084;
    reg signal_mux_179;
    wire signal_select_1085;
    wire [5:0] signal_cat_179;
    wire [5:0] signal_cat_180;
    wire [5:0] signal_sub_118;
    wire [5:0] signal_cat_181;
    wire [5:0] signal_sub_119;
    wire signal_lt_116;
    wire [5:0] signal_mux_180;
    wire signal_lt_117;
    wire signal_mux_181;
    wire signal_select_1086;
    wire signal_select_1087;
    wire signal_select_1088;
    wire signal_select_1089;
    wire signal_select_1090;
    wire signal_select_1091;
    wire signal_select_1092;
    wire signal_select_1093;
    wire signal_select_1094;
    wire signal_select_1095;
    wire signal_select_1096;
    wire signal_select_1097;
    wire signal_select_1098;
    wire signal_select_1099;
    wire signal_select_1100;
    wire [13:0] signal_const_192;
    wire [15:0] signal_cat_182;
    wire signal_select_1101;
    wire [3:0] signal_select_1102;
    reg signal_mux_182;
    wire signal_select_1103;
    wire [5:0] signal_cat_183;
    wire [5:0] signal_cat_184;
    wire [5:0] signal_sub_120;
    wire [5:0] signal_cat_185;
    wire [5:0] signal_sub_121;
    wire signal_lt_118;
    wire [5:0] signal_mux_183;
    wire signal_lt_119;
    wire signal_mux_184;
    wire [19:0] pin_out_side;
    wire [19:0] pin_out_base;
    wire [15:0] signal_const_196;
    wire [15:0] signal_const_197;
    wire [15:0] signal_wire_2;
    wire [8:0] signal_wire_3;
    wire [8:0] signal_const_198;
    wire [8:0] signal_const_199;
    wire signal_eq_8;
    wire [8:0] signal_mux_185;
    wire [8:0] signal_add;
    wire signal_eq_9;
    wire [8:0] signal_mux_186;
    wire [8:0] signal_wire_4;
    wire [8:0] signal_add_1;
    wire [8:0] signal_wire_5;
    wire [8:0] d$jmp_target;
    wire [4:0] signal_const_205;
    wire [4:0] signal_const_208;
    wire [4:0] signal_add_2;
    wire [4:0] stuff_run_max;
    wire signal_eq_10;
    wire [4:0] signal_mux_187;
    wire signal_wire_6;
    wire signal_eq_11;
    wire [4:0] signal_mux_188;
    wire [4:0] signal_mux_189;
    wire signal_eq_12;
    wire signal_and_11;
    wire [4:0] stuff_run_next;
    wire [4:0] signal_mux_190;
    wire [4:0] signal_mux_191;
    reg [4:0] signal_reg_4;
    wire [4:0] stuff_run_0;
    wire signal_lt_120;
    wire signal_not_3;
    wire [4:0] signal_wire_7;
    wire signal_eq_13;
    wire signal_not_4;
    wire signal_and_12;
    wire signal_lt_121;
    wire signal_select_1104;
    wire signal_select_1105;
    wire signal_select_1106;
    wire signal_select_1107;
    wire signal_select_1108;
    wire signal_select_1109;
    wire signal_select_1110;
    wire signal_select_1111;
    wire signal_select_1112;
    wire signal_select_1113;
    wire signal_select_1114;
    wire signal_select_1115;
    wire signal_select_1116;
    wire signal_select_1117;
    wire signal_select_1118;
    wire signal_select_1119;
    wire signal_select_1120;
    wire signal_select_1121;
    wire signal_select_1122;
    wire signal_select_1123;
    reg signal_mux_192;
    wire signal_not_5;
    wire signal_select_1124;
    wire signal_select_1125;
    wire signal_select_1126;
    wire signal_select_1127;
    wire signal_select_1128;
    wire signal_select_1129;
    wire signal_select_1130;
    wire signal_select_1131;
    wire signal_select_1132;
    wire signal_select_1133;
    wire signal_select_1134;
    wire signal_select_1135;
    wire signal_select_1136;
    wire signal_select_1137;
    wire signal_select_1138;
    wire signal_select_1139;
    wire signal_select_1140;
    wire signal_select_1141;
    wire signal_select_1142;
    wire signal_select_1143;
    wire [4:0] signal_wire_8;
    reg signal_mux_193;
    wire signal_eq_14;
    wire signal_not_6;
    wire signal_eq_15;
    wire signal_not_7;
    wire signal_eq_16;
    wire signal_not_8;
    reg jmp_taken;
    wire [8:0] jmp_target_or_next;
    wire [8:0] signal_mux_194;
    wire [8:0] signal_mux_195;
    wire [8:0] pc_value_next;
    reg [8:0] signal_reg_5;
    wire [8:0] pc_0;
    wire signal_eq_17;
    wire [8:0] pc_next;
    wire [8:0] signal_mux_196;
    wire [8:0] pc_after_next;
    wire signal_not_9;
    wire [4:0] signal_and_13;
    wire [4:0] signal_and_14;
    wire [4:0] signal_and_15;
    reg [4:0] d$delay;
    wire [4:0] signal_sub_122;
    wire signal_eq_18;
    wire signal_not_10;
    wire [4:0] signal_mux_197;
    wire [4:0] signal_mux_198;
    wire [4:0] signal_mux_199;
    wire [4:0] stall_next;
    reg [4:0] signal_reg_6;
    wire [4:0] stall_0;
    wire signal_eq_19;
    wire [2:0] signal_const_223;
    wire signal_eq_20;
    wire signal_and_16;
    wire signal_and_17;
    wire signal_mux_200;
    wire signal_or_1;
    reg refill;
    wire signal_not_11;
    wire signal_wire_9;
    wire [15:0] signal_mux_201;
    wire [15:0] signal_wire_10;
    wire signal_not_12;
    wire [2:0] signal_const_225;
    wire signal_eq_21;
    wire signal_and_18;
    wire signal_and_19;
    wire pushes;
    wire signal_and_20;
    wire signal_and_21;
    wire signal_wire_11;
    wire [20:0] signal_inst;
    wire signal_select_1144;
    wire signal_not_13;
    wire signal_mux_202;
    wire [23:0] signal_xor;
    wire [23:0] signal_sub_123;
    wire [7:0] signal_const_227;
    wire [23:0] signal_cat_186;
    wire [23:0] signal_add_3;
    reg [23:0] signal_mux_203;
    wire [1:0] signal_const_228;
    wire signal_eq_22;
    wire [23:0] signal_mux_204;
    wire signal_select_1145;
    wire signal_select_1146;
    wire signal_select_1147;
    wire signal_select_1148;
    wire signal_select_1149;
    wire signal_select_1150;
    wire signal_select_1151;
    wire signal_select_1152;
    wire signal_select_1153;
    wire signal_select_1154;
    wire signal_select_1155;
    wire signal_select_1156;
    wire signal_select_1157;
    wire signal_select_1158;
    wire signal_select_1159;
    wire signal_select_1160;
    wire signal_select_1161;
    wire signal_select_1162;
    wire signal_select_1163;
    wire signal_select_1164;
    wire signal_select_1165;
    wire signal_select_1166;
    wire signal_select_1167;
    wire signal_select_1168;
    wire [23:0] signal_cat_187;
    wire [23:0] signal_not_14;
    reg [23:0] mov_value_t;
    wire [2:0] signal_const_229;
    wire signal_eq_23;
    wire [23:0] signal_mux_205;
    wire [23:0] signal_cat_188;
    wire signal_eq_24;
    wire [23:0] signal_mux_206;
    wire [23:0] signal_cat_189;
    wire [23:0] signal_add_4;
    wire [1:0] signal_const_233;
    wire signal_eq_25;
    wire signal_and_22;
    wire releases_deadline;
    wire signal_and_23;
    wire [23:0] signal_mux_207;
    reg [23:0] t_next;
    reg [23:0] signal_reg_7;
    wire [23:0] t_0;
    wire [23:0] signal_sub_124;
    wire signal_select_1169;
    wire deadline_ready;
    wire signal_eq_26;
    wire signal_select_1170;
    wire signal_select_1171;
    wire signal_select_1172;
    wire signal_select_1173;
    wire signal_select_1174;
    wire signal_select_1175;
    wire signal_select_1176;
    wire signal_select_1177;
    wire signal_select_1178;
    wire signal_select_1179;
    wire signal_select_1180;
    wire signal_select_1181;
    wire signal_select_1182;
    wire signal_select_1183;
    wire signal_select_1184;
    wire signal_select_1185;
    wire signal_select_1186;
    wire signal_select_1187;
    wire signal_select_1188;
    wire signal_select_1189;
    reg wait_pin_prev;
    wire signal_eq_27;
    wire signal_not_15;
    wire signal_and_24;
    wire d$wait_polarity;
    wire signal_select_1190;
    wire signal_select_1191;
    wire signal_select_1192;
    wire signal_select_1193;
    wire signal_select_1194;
    wire signal_select_1195;
    wire signal_select_1196;
    wire signal_select_1197;
    wire signal_select_1198;
    wire signal_select_1199;
    wire signal_select_1200;
    wire signal_select_1201;
    wire signal_select_1202;
    wire signal_select_1203;
    wire signal_select_1204;
    wire signal_select_1205;
    wire signal_select_1206;
    wire signal_select_1207;
    wire signal_select_1208;
    wire signal_select_1209;
    wire signal_select_1210;
    wire signal_select_1211;
    wire signal_select_1212;
    wire signal_select_1213;
    wire signal_select_1214;
    wire signal_select_1215;
    wire signal_select_1216;
    wire signal_select_1217;
    wire signal_select_1218;
    wire signal_select_1219;
    wire signal_select_1220;
    wire signal_select_1221;
    wire signal_select_1222;
    wire signal_select_1223;
    wire signal_mux_208;
    wire signal_select_1224;
    wire signal_select_1225;
    wire signal_select_1226;
    wire signal_mux_209;
    wire signal_select_1227;
    wire signal_select_1228;
    wire signal_select_1229;
    wire signal_mux_210;
    wire signal_select_1230;
    wire signal_select_1231;
    wire signal_select_1232;
    wire signal_mux_211;
    wire signal_select_1233;
    wire signal_select_1234;
    wire signal_select_1235;
    wire signal_mux_212;
    wire signal_select_1236;
    wire signal_select_1237;
    wire signal_select_1238;
    wire signal_mux_213;
    wire signal_select_1239;
    wire signal_select_1240;
    wire signal_select_1241;
    wire signal_mux_214;
    wire signal_select_1242;
    wire [19:0] signal_wire_12;
    wire signal_select_1243;
    wire signal_select_1244;
    wire signal_select_1245;
    wire signal_select_1246;
    wire signal_select_1247;
    wire signal_select_1248;
    wire signal_select_1249;
    wire signal_select_1250;
    wire signal_select_1251;
    wire signal_select_1252;
    wire signal_select_1253;
    wire signal_select_1254;
    wire signal_select_1255;
    wire signal_select_1256;
    wire signal_select_1257;
    wire signal_select_1258;
    wire signal_select_1259;
    wire signal_select_1260;
    wire signal_select_1261;
    wire signal_select_1262;
    wire signal_select_1263;
    wire signal_select_1264;
    wire signal_select_1265;
    wire signal_select_1266;
    wire signal_select_1267;
    wire signal_select_1268;
    wire signal_select_1269;
    wire signal_select_1270;
    wire signal_select_1271;
    wire [3:0] signal_select_1272;
    reg signal_mux_215;
    wire signal_select_1273;
    wire [5:0] signal_cat_190;
    wire [5:0] signal_cat_191;
    wire [5:0] signal_sub_125;
    wire [5:0] signal_cat_192;
    wire [5:0] signal_sub_126;
    wire signal_lt_122;
    wire [5:0] signal_mux_216;
    wire signal_lt_123;
    wire signal_mux_217;
    wire signal_select_1274;
    wire signal_select_1275;
    wire signal_select_1276;
    wire signal_select_1277;
    wire signal_select_1278;
    wire signal_select_1279;
    wire signal_select_1280;
    wire signal_select_1281;
    wire signal_select_1282;
    wire signal_select_1283;
    wire signal_select_1284;
    wire signal_select_1285;
    wire signal_select_1286;
    wire signal_select_1287;
    wire signal_select_1288;
    wire signal_select_1289;
    wire [3:0] signal_select_1290;
    reg signal_mux_218;
    wire signal_select_1291;
    wire [5:0] signal_cat_193;
    wire [5:0] signal_cat_194;
    wire [5:0] signal_sub_127;
    wire [5:0] signal_cat_195;
    wire [5:0] signal_sub_128;
    wire signal_lt_124;
    wire [5:0] signal_mux_219;
    wire signal_lt_125;
    wire signal_mux_220;
    wire signal_select_1292;
    wire signal_select_1293;
    wire signal_select_1294;
    wire signal_select_1295;
    wire signal_select_1296;
    wire signal_select_1297;
    wire signal_select_1298;
    wire signal_select_1299;
    wire signal_select_1300;
    wire signal_select_1301;
    wire signal_select_1302;
    wire signal_select_1303;
    wire signal_select_1304;
    wire signal_select_1305;
    wire signal_select_1306;
    wire signal_select_1307;
    wire [3:0] signal_select_1308;
    reg signal_mux_221;
    wire signal_select_1309;
    wire [5:0] signal_cat_196;
    wire [5:0] signal_cat_197;
    wire [5:0] signal_sub_129;
    wire [5:0] signal_cat_198;
    wire [5:0] signal_sub_130;
    wire signal_lt_126;
    wire [5:0] signal_mux_222;
    wire signal_lt_127;
    wire signal_mux_223;
    wire signal_select_1310;
    wire signal_select_1311;
    wire signal_select_1312;
    wire signal_select_1313;
    wire signal_select_1314;
    wire signal_select_1315;
    wire signal_select_1316;
    wire signal_select_1317;
    wire signal_select_1318;
    wire signal_select_1319;
    wire signal_select_1320;
    wire signal_select_1321;
    wire signal_select_1322;
    wire signal_select_1323;
    wire signal_select_1324;
    wire signal_select_1325;
    wire [3:0] signal_select_1326;
    reg signal_mux_224;
    wire signal_select_1327;
    wire [5:0] signal_cat_199;
    wire [5:0] signal_cat_200;
    wire [5:0] signal_sub_131;
    wire [5:0] signal_cat_201;
    wire [5:0] signal_sub_132;
    wire signal_lt_128;
    wire [5:0] signal_mux_225;
    wire signal_lt_129;
    wire signal_mux_226;
    wire signal_select_1328;
    wire signal_select_1329;
    wire signal_select_1330;
    wire signal_select_1331;
    wire signal_select_1332;
    wire signal_select_1333;
    wire signal_select_1334;
    wire signal_select_1335;
    wire signal_select_1336;
    wire signal_select_1337;
    wire signal_select_1338;
    wire signal_select_1339;
    wire signal_select_1340;
    wire signal_select_1341;
    wire signal_select_1342;
    wire signal_select_1343;
    wire [3:0] signal_select_1344;
    reg signal_mux_227;
    wire signal_select_1345;
    wire [5:0] signal_cat_202;
    wire [5:0] signal_cat_203;
    wire [5:0] signal_sub_133;
    wire [5:0] signal_cat_204;
    wire [5:0] signal_sub_134;
    wire signal_lt_130;
    wire [5:0] signal_mux_228;
    wire signal_lt_131;
    wire signal_mux_229;
    wire signal_select_1346;
    wire signal_select_1347;
    wire signal_select_1348;
    wire signal_select_1349;
    wire signal_select_1350;
    wire signal_select_1351;
    wire signal_select_1352;
    wire signal_select_1353;
    wire signal_select_1354;
    wire signal_select_1355;
    wire signal_select_1356;
    wire signal_select_1357;
    wire signal_select_1358;
    wire signal_select_1359;
    wire signal_select_1360;
    wire signal_select_1361;
    wire [3:0] signal_select_1362;
    reg signal_mux_230;
    wire signal_select_1363;
    wire [5:0] signal_cat_205;
    wire [5:0] signal_cat_206;
    wire [5:0] signal_sub_135;
    wire [5:0] signal_cat_207;
    wire [5:0] signal_sub_136;
    wire signal_lt_132;
    wire [5:0] signal_mux_231;
    wire signal_lt_133;
    wire signal_mux_232;
    wire signal_select_1364;
    wire signal_select_1365;
    wire signal_select_1366;
    wire signal_select_1367;
    wire signal_select_1368;
    wire signal_select_1369;
    wire signal_select_1370;
    wire signal_select_1371;
    wire signal_select_1372;
    wire signal_select_1373;
    wire signal_select_1374;
    wire signal_select_1375;
    wire signal_select_1376;
    wire signal_select_1377;
    wire signal_select_1378;
    wire signal_select_1379;
    wire [3:0] signal_select_1380;
    reg signal_mux_233;
    wire signal_select_1381;
    wire [5:0] signal_cat_208;
    wire [5:0] signal_cat_209;
    wire [5:0] signal_sub_137;
    wire [5:0] signal_cat_210;
    wire [5:0] signal_sub_138;
    wire signal_lt_134;
    wire [5:0] signal_mux_234;
    wire signal_lt_135;
    wire signal_mux_235;
    wire signal_select_1382;
    wire signal_select_1383;
    wire signal_select_1384;
    wire signal_select_1385;
    wire signal_select_1386;
    wire signal_select_1387;
    wire signal_select_1388;
    wire signal_select_1389;
    wire signal_select_1390;
    wire signal_select_1391;
    wire signal_select_1392;
    wire signal_select_1393;
    wire signal_select_1394;
    wire signal_select_1395;
    wire signal_select_1396;
    wire [15:0] signal_cat_211;
    wire signal_select_1397;
    wire [3:0] signal_select_1398;
    reg signal_mux_236;
    wire signal_select_1399;
    wire [2:0] signal_wire_13;
    wire [1:0] signal_const_257;
    wire [4:0] signal_cat_212;
    wire [5:0] signal_cat_213;
    wire [5:0] signal_cat_214;
    wire [5:0] signal_sub_139;
    wire [5:0] signal_cat_215;
    wire [5:0] signal_sub_140;
    wire [4:0] signal_wire_14;
    wire signal_lt_136;
    wire [5:0] signal_mux_237;
    wire signal_lt_137;
    wire signal_mux_238;
    wire [19:0] signal_cat_216;
    wire signal_eq_28;
    wire [19:0] signal_mux_239;
    wire signal_select_1400;
    wire signal_select_1401;
    wire signal_select_1402;
    wire signal_select_1403;
    wire signal_select_1404;
    wire signal_select_1405;
    wire signal_select_1406;
    wire signal_select_1407;
    wire signal_select_1408;
    wire signal_select_1409;
    wire signal_select_1410;
    wire signal_select_1411;
    wire signal_select_1412;
    wire signal_select_1413;
    wire signal_select_1414;
    wire signal_select_1415;
    wire signal_select_1416;
    wire signal_select_1417;
    wire signal_select_1418;
    wire signal_select_1419;
    wire signal_select_1420;
    wire signal_select_1421;
    wire signal_select_1422;
    wire signal_select_1423;
    wire signal_select_1424;
    wire signal_select_1425;
    wire signal_select_1426;
    wire signal_select_1427;
    wire [3:0] signal_select_1428;
    reg signal_mux_240;
    wire signal_select_1429;
    wire [5:0] signal_cat_217;
    wire [5:0] signal_cat_218;
    wire [5:0] signal_sub_141;
    wire [5:0] signal_cat_219;
    wire [5:0] signal_sub_142;
    wire signal_lt_138;
    wire [5:0] signal_mux_241;
    wire signal_lt_139;
    wire signal_mux_242;
    wire signal_select_1430;
    wire signal_select_1431;
    wire signal_select_1432;
    wire signal_select_1433;
    wire signal_select_1434;
    wire signal_select_1435;
    wire signal_select_1436;
    wire signal_select_1437;
    wire signal_select_1438;
    wire signal_select_1439;
    wire signal_select_1440;
    wire signal_select_1441;
    wire signal_select_1442;
    wire signal_select_1443;
    wire signal_select_1444;
    wire signal_select_1445;
    wire [3:0] signal_select_1446;
    reg signal_mux_243;
    wire signal_select_1447;
    wire [5:0] signal_cat_220;
    wire [5:0] signal_cat_221;
    wire [5:0] signal_sub_143;
    wire [5:0] signal_cat_222;
    wire [5:0] signal_sub_144;
    wire signal_lt_140;
    wire [5:0] signal_mux_244;
    wire signal_lt_141;
    wire signal_mux_245;
    wire signal_select_1448;
    wire signal_select_1449;
    wire signal_select_1450;
    wire signal_select_1451;
    wire signal_select_1452;
    wire signal_select_1453;
    wire signal_select_1454;
    wire signal_select_1455;
    wire signal_select_1456;
    wire signal_select_1457;
    wire signal_select_1458;
    wire signal_select_1459;
    wire signal_select_1460;
    wire signal_select_1461;
    wire signal_select_1462;
    wire signal_select_1463;
    wire [3:0] signal_select_1464;
    reg signal_mux_246;
    wire signal_select_1465;
    wire [5:0] signal_cat_223;
    wire [5:0] signal_cat_224;
    wire [5:0] signal_sub_145;
    wire [5:0] signal_cat_225;
    wire [5:0] signal_sub_146;
    wire signal_lt_142;
    wire [5:0] signal_mux_247;
    wire signal_lt_143;
    wire signal_mux_248;
    wire signal_select_1466;
    wire signal_select_1467;
    wire signal_select_1468;
    wire signal_select_1469;
    wire signal_select_1470;
    wire signal_select_1471;
    wire signal_select_1472;
    wire signal_select_1473;
    wire signal_select_1474;
    wire signal_select_1475;
    wire signal_select_1476;
    wire signal_select_1477;
    wire signal_select_1478;
    wire signal_select_1479;
    wire signal_select_1480;
    wire signal_select_1481;
    wire [3:0] signal_select_1482;
    reg signal_mux_249;
    wire signal_select_1483;
    wire [5:0] signal_cat_226;
    wire [5:0] signal_cat_227;
    wire [5:0] signal_sub_147;
    wire [5:0] signal_cat_228;
    wire [5:0] signal_sub_148;
    wire signal_lt_144;
    wire [5:0] signal_mux_250;
    wire signal_lt_145;
    wire signal_mux_251;
    wire signal_select_1484;
    wire signal_select_1485;
    wire signal_select_1486;
    wire signal_select_1487;
    wire signal_select_1488;
    wire signal_select_1489;
    wire signal_select_1490;
    wire signal_select_1491;
    wire signal_select_1492;
    wire signal_select_1493;
    wire signal_select_1494;
    wire signal_select_1495;
    wire signal_select_1496;
    wire signal_select_1497;
    wire signal_select_1498;
    wire signal_select_1499;
    wire [3:0] signal_select_1500;
    reg signal_mux_252;
    wire signal_select_1501;
    wire [5:0] signal_cat_229;
    wire [5:0] signal_cat_230;
    wire [5:0] signal_sub_149;
    wire [5:0] signal_cat_231;
    wire [5:0] signal_sub_150;
    wire signal_lt_146;
    wire [5:0] signal_mux_253;
    wire signal_lt_147;
    wire signal_mux_254;
    wire signal_select_1502;
    wire signal_select_1503;
    wire signal_select_1504;
    wire signal_select_1505;
    wire signal_select_1506;
    wire signal_select_1507;
    wire signal_select_1508;
    wire signal_select_1509;
    wire signal_select_1510;
    wire signal_select_1511;
    wire signal_select_1512;
    wire signal_select_1513;
    wire signal_select_1514;
    wire signal_select_1515;
    wire signal_select_1516;
    wire signal_select_1517;
    wire [3:0] signal_select_1518;
    reg signal_mux_255;
    wire signal_select_1519;
    wire [5:0] signal_cat_232;
    wire [5:0] signal_cat_233;
    wire [5:0] signal_sub_151;
    wire [5:0] signal_cat_234;
    wire [5:0] signal_sub_152;
    wire signal_lt_148;
    wire [5:0] signal_mux_256;
    wire signal_lt_149;
    wire signal_mux_257;
    wire signal_select_1520;
    wire signal_select_1521;
    wire signal_select_1522;
    wire signal_select_1523;
    wire signal_select_1524;
    wire signal_select_1525;
    wire signal_select_1526;
    wire signal_select_1527;
    wire signal_select_1528;
    wire signal_select_1529;
    wire signal_select_1530;
    wire signal_select_1531;
    wire signal_select_1532;
    wire signal_select_1533;
    wire signal_select_1534;
    wire signal_select_1535;
    wire [3:0] signal_select_1536;
    reg signal_mux_258;
    wire signal_select_1537;
    wire [5:0] signal_cat_235;
    wire [5:0] signal_cat_236;
    wire [5:0] signal_sub_153;
    wire [5:0] signal_cat_237;
    wire [5:0] signal_sub_154;
    wire signal_lt_150;
    wire [5:0] signal_mux_259;
    wire signal_lt_151;
    wire signal_mux_260;
    wire signal_select_1538;
    wire signal_select_1539;
    wire signal_select_1540;
    wire signal_select_1541;
    wire signal_select_1542;
    wire signal_select_1543;
    wire signal_select_1544;
    wire signal_select_1545;
    wire signal_select_1546;
    wire signal_select_1547;
    wire signal_select_1548;
    wire signal_select_1549;
    wire signal_select_1550;
    wire signal_select_1551;
    wire signal_select_1552;
    wire signal_select_1553;
    wire [3:0] signal_select_1554;
    reg signal_mux_261;
    wire signal_select_1555;
    wire [4:0] signal_wire_15;
    wire [5:0] signal_cat_238;
    wire [5:0] signal_cat_239;
    wire [5:0] signal_sub_155;
    wire [5:0] signal_cat_240;
    wire [5:0] signal_sub_156;
    wire signal_lt_152;
    wire [5:0] signal_mux_262;
    wire signal_lt_153;
    wire signal_mux_263;
    wire [19:0] signal_cat_241;
    wire signal_eq_29;
    wire [19:0] signal_mux_264;
    wire signal_select_1556;
    wire signal_select_1557;
    wire signal_select_1558;
    wire signal_select_1559;
    wire signal_select_1560;
    wire signal_select_1561;
    wire signal_select_1562;
    wire signal_select_1563;
    wire signal_select_1564;
    wire signal_select_1565;
    wire signal_select_1566;
    wire signal_select_1567;
    wire signal_select_1568;
    wire signal_select_1569;
    wire signal_select_1570;
    wire signal_select_1571;
    wire signal_select_1572;
    wire signal_select_1573;
    wire signal_select_1574;
    wire signal_select_1575;
    wire signal_select_1576;
    wire signal_select_1577;
    wire signal_select_1578;
    wire signal_select_1579;
    wire signal_select_1580;
    wire signal_select_1581;
    wire signal_select_1582;
    wire signal_select_1583;
    wire [3:0] signal_select_1584;
    reg signal_mux_265;
    wire signal_select_1585;
    wire [5:0] signal_cat_242;
    wire [5:0] signal_cat_243;
    wire [5:0] signal_sub_157;
    wire [5:0] signal_cat_244;
    wire [5:0] signal_sub_158;
    wire signal_lt_154;
    wire [5:0] signal_mux_266;
    wire signal_lt_155;
    wire signal_mux_267;
    wire signal_select_1586;
    wire signal_select_1587;
    wire signal_select_1588;
    wire signal_select_1589;
    wire signal_select_1590;
    wire signal_select_1591;
    wire signal_select_1592;
    wire signal_select_1593;
    wire signal_select_1594;
    wire signal_select_1595;
    wire signal_select_1596;
    wire signal_select_1597;
    wire signal_select_1598;
    wire signal_select_1599;
    wire signal_select_1600;
    wire signal_select_1601;
    wire [3:0] signal_select_1602;
    reg signal_mux_268;
    wire signal_select_1603;
    wire [5:0] signal_cat_245;
    wire [5:0] signal_cat_246;
    wire [5:0] signal_sub_159;
    wire [5:0] signal_cat_247;
    wire [5:0] signal_sub_160;
    wire signal_lt_156;
    wire [5:0] signal_mux_269;
    wire signal_lt_157;
    wire signal_mux_270;
    wire signal_select_1604;
    wire signal_select_1605;
    wire signal_select_1606;
    wire signal_select_1607;
    wire signal_select_1608;
    wire signal_select_1609;
    wire signal_select_1610;
    wire signal_select_1611;
    wire signal_select_1612;
    wire signal_select_1613;
    wire signal_select_1614;
    wire signal_select_1615;
    wire signal_select_1616;
    wire signal_select_1617;
    wire signal_select_1618;
    wire signal_select_1619;
    wire [3:0] signal_select_1620;
    reg signal_mux_271;
    wire signal_select_1621;
    wire [5:0] signal_cat_248;
    wire [5:0] signal_cat_249;
    wire [5:0] signal_sub_161;
    wire [5:0] signal_cat_250;
    wire [5:0] signal_sub_162;
    wire signal_lt_158;
    wire [5:0] signal_mux_272;
    wire signal_lt_159;
    wire signal_mux_273;
    wire signal_select_1622;
    wire signal_select_1623;
    wire signal_select_1624;
    wire signal_select_1625;
    wire signal_select_1626;
    wire signal_select_1627;
    wire signal_select_1628;
    wire signal_select_1629;
    wire signal_select_1630;
    wire signal_select_1631;
    wire signal_select_1632;
    wire signal_select_1633;
    wire signal_select_1634;
    wire signal_select_1635;
    wire signal_select_1636;
    wire signal_select_1637;
    wire [3:0] signal_select_1638;
    reg signal_mux_274;
    wire signal_select_1639;
    wire [5:0] signal_cat_251;
    wire [5:0] signal_cat_252;
    wire [5:0] signal_sub_163;
    wire [5:0] signal_cat_253;
    wire [5:0] signal_sub_164;
    wire signal_lt_160;
    wire [5:0] signal_mux_275;
    wire signal_lt_161;
    wire signal_mux_276;
    wire signal_select_1640;
    wire signal_select_1641;
    wire signal_select_1642;
    wire signal_select_1643;
    wire signal_select_1644;
    wire signal_select_1645;
    wire signal_select_1646;
    wire signal_select_1647;
    wire signal_select_1648;
    wire signal_select_1649;
    wire signal_select_1650;
    wire signal_select_1651;
    wire signal_select_1652;
    wire signal_select_1653;
    wire signal_select_1654;
    wire signal_select_1655;
    wire [3:0] signal_select_1656;
    reg signal_mux_277;
    wire signal_select_1657;
    wire [5:0] signal_cat_254;
    wire [5:0] signal_cat_255;
    wire [5:0] signal_sub_165;
    wire [5:0] signal_cat_256;
    wire [5:0] signal_sub_166;
    wire signal_lt_162;
    wire [5:0] signal_mux_278;
    wire signal_lt_163;
    wire signal_mux_279;
    wire signal_select_1658;
    wire signal_select_1659;
    wire signal_select_1660;
    wire signal_select_1661;
    wire signal_select_1662;
    wire signal_select_1663;
    wire signal_select_1664;
    wire signal_select_1665;
    wire signal_select_1666;
    wire signal_select_1667;
    wire signal_select_1668;
    wire signal_select_1669;
    wire signal_select_1670;
    wire signal_select_1671;
    wire signal_select_1672;
    wire signal_select_1673;
    wire [3:0] signal_select_1674;
    reg signal_mux_280;
    wire signal_select_1675;
    wire [5:0] signal_cat_257;
    wire [5:0] signal_cat_258;
    wire [5:0] signal_sub_167;
    wire [5:0] signal_cat_259;
    wire [5:0] signal_sub_168;
    wire signal_lt_164;
    wire [5:0] signal_mux_281;
    wire signal_lt_165;
    wire signal_mux_282;
    wire signal_select_1676;
    wire signal_select_1677;
    wire signal_select_1678;
    wire signal_select_1679;
    wire signal_select_1680;
    wire signal_select_1681;
    wire signal_select_1682;
    wire signal_select_1683;
    wire signal_select_1684;
    wire signal_select_1685;
    wire signal_select_1686;
    wire signal_select_1687;
    wire signal_select_1688;
    wire signal_select_1689;
    wire signal_select_1690;
    wire signal_select_1691;
    wire [3:0] signal_select_1692;
    reg signal_mux_283;
    wire signal_select_1693;
    wire [5:0] signal_cat_260;
    wire [5:0] signal_cat_261;
    wire [5:0] signal_sub_169;
    wire [5:0] signal_cat_262;
    wire [5:0] signal_sub_170;
    wire signal_lt_166;
    wire [5:0] signal_mux_284;
    wire signal_lt_167;
    wire signal_mux_285;
    wire signal_select_1694;
    wire signal_select_1695;
    wire signal_select_1696;
    wire signal_select_1697;
    wire signal_select_1698;
    wire signal_select_1699;
    wire signal_select_1700;
    wire signal_select_1701;
    wire signal_select_1702;
    wire signal_select_1703;
    wire signal_select_1704;
    wire signal_select_1705;
    wire signal_select_1706;
    wire signal_select_1707;
    wire signal_select_1708;
    wire [15:0] signal_and_25;
    wire [7:0] signal_select_1709;
    wire [15:0] signal_cat_263;
    wire [11:0] signal_select_1710;
    wire [3:0] signal_const_310;
    wire [15:0] signal_cat_264;
    wire [13:0] signal_select_1711;
    wire [15:0] signal_cat_265;
    wire [14:0] signal_select_1712;
    wire [15:0] signal_cat_266;
    wire [15:0] signal_select_1713;
    wire signal_not_16;
    wire signal_and_26;
    wire [15:0] signal_mux_286;
    wire signal_select_1714;
    wire signal_select_1715;
    wire signal_select_1716;
    wire signal_select_1717;
    wire signal_select_1718;
    wire signal_select_1719;
    wire signal_select_1720;
    wire signal_select_1721;
    wire signal_select_1722;
    wire signal_select_1723;
    wire signal_select_1724;
    wire signal_select_1725;
    wire signal_select_1726;
    wire signal_select_1727;
    wire signal_select_1728;
    wire signal_select_1729;
    wire [15:0] signal_cat_267;
    wire [15:0] signal_not_17;
    wire [23:0] signal_cat_268;
    wire [23:0] signal_cat_269;
    wire [23:0] signal_cat_270;
    wire [15:0] signal_xor_1;
    wire [15:0] signal_sub_171;
    wire signal_eq_30;
    wire signal_and_27;
    wire [15:0] signal_mux_287;
    wire signal_eq_31;
    wire [15:0] signal_mux_288;
    wire signal_eq_32;
    wire [15:0] signal_mux_289;
    wire [7:0] signal_select_1730;
    wire [15:0] signal_cat_271;
    wire [11:0] signal_select_1731;
    wire [15:0] signal_cat_272;
    wire [13:0] signal_select_1732;
    wire [15:0] signal_cat_273;
    wire [14:0] signal_select_1733;
    wire [15:0] signal_cat_274;
    wire signal_select_1734;
    wire [15:0] signal_mux_290;
    wire signal_select_1735;
    wire [15:0] signal_mux_291;
    wire signal_select_1736;
    wire [15:0] signal_mux_292;
    wire signal_select_1737;
    wire [15:0] signal_mux_293;
    wire signal_select_1738;
    wire [15:0] signal_mux_294;
    wire [7:0] signal_select_1739;
    wire [15:0] signal_cat_275;
    wire [11:0] signal_select_1740;
    wire [15:0] signal_cat_276;
    wire [13:0] signal_select_1741;
    wire [15:0] signal_cat_277;
    wire [14:0] signal_select_1742;
    wire [15:0] signal_cat_278;
    wire signal_select_1743;
    wire [15:0] signal_mux_295;
    wire signal_select_1744;
    wire [15:0] signal_mux_296;
    wire signal_select_1745;
    wire [15:0] signal_mux_297;
    wire signal_select_1746;
    wire [15:0] signal_mux_298;
    wire signal_select_1747;
    wire [15:0] signal_mux_299;
    wire [15:0] signal_or_2;
    wire [7:0] signal_select_1748;
    wire [15:0] signal_cat_279;
    wire [11:0] signal_select_1749;
    wire [15:0] signal_cat_280;
    wire [13:0] signal_select_1750;
    wire [15:0] signal_cat_281;
    wire [15:0] signal_const_339;
    wire signal_select_1751;
    wire [15:0] signal_mux_300;
    wire signal_select_1752;
    wire [15:0] signal_mux_301;
    wire signal_select_1753;
    wire [15:0] signal_mux_302;
    wire signal_select_1754;
    wire [15:0] signal_mux_303;
    wire signal_select_1755;
    wire [15:0] signal_mux_304;
    wire [15:0] mask;
    wire signal_wire_16;
    wire signal_select_1756;
    wire signal_select_1757;
    wire signal_select_1758;
    wire signal_select_1759;
    wire signal_select_1760;
    wire signal_select_1761;
    wire signal_select_1762;
    wire signal_select_1763;
    wire signal_select_1764;
    wire signal_select_1765;
    wire signal_select_1766;
    wire signal_select_1767;
    wire signal_select_1768;
    wire signal_select_1769;
    wire signal_select_1770;
    wire signal_select_1771;
    wire signal_select_1772;
    wire signal_select_1773;
    wire signal_select_1774;
    wire signal_select_1775;
    reg signal_mux_305;
    wire signal_eq_33;
    wire signal_select_1776;
    wire signal_select_1777;
    wire signal_select_1778;
    wire signal_select_1779;
    wire signal_select_1780;
    wire signal_select_1781;
    wire signal_select_1782;
    wire signal_select_1783;
    wire signal_select_1784;
    wire signal_select_1785;
    wire signal_select_1786;
    wire signal_select_1787;
    wire signal_select_1788;
    wire signal_select_1789;
    wire signal_select_1790;
    wire signal_select_1791;
    wire signal_select_1792;
    wire signal_select_1793;
    wire signal_select_1794;
    reg [19:0] signal_reg_8;
    wire [19:0] pins_sampled;
    wire signal_select_1795;
    reg signal_mux_306;
    wire signal_select_1796;
    wire signal_select_1797;
    wire signal_select_1798;
    wire signal_select_1799;
    wire signal_select_1800;
    wire signal_select_1801;
    wire signal_select_1802;
    wire signal_select_1803;
    wire signal_select_1804;
    wire signal_select_1805;
    wire signal_select_1806;
    wire signal_select_1807;
    wire signal_select_1808;
    wire signal_select_1809;
    wire signal_select_1810;
    wire signal_select_1811;
    wire signal_select_1812;
    wire signal_select_1813;
    wire signal_select_1814;
    wire signal_select_1815;
    wire [4:0] signal_wire_17;
    reg signal_mux_307;
    wire signal_eq_34;
    wire signal_not_18;
    wire signal_eq_35;
    wire signal_and_28;
    wire signal_and_29;
    wire signal_mux_308;
    wire signal_mux_309;
    reg signal_reg_9;
    wire capture_armed_0;
    wire signal_and_30;
    wire captured;
    wire [23:0] signal_const_347;
    wire [23:0] signal_add_5;
    wire [23:0] signal_mux_310;
    reg [23:0] signal_reg_10;
    wire [23:0] now_0;
    reg [23:0] signal_reg_11;
    wire [23:0] capture_0;
    wire [15:0] signal_select_1816;
    wire [15:0] signal_wire_18;
    wire [7:0] signal_select_1817;
    wire [15:0] signal_cat_282;
    wire [11:0] signal_select_1818;
    wire [15:0] signal_cat_283;
    wire [13:0] signal_select_1819;
    wire [15:0] signal_cat_284;
    wire signal_select_1820;
    wire [15:0] signal_mux_311;
    wire signal_select_1821;
    wire [15:0] signal_mux_312;
    wire signal_select_1822;
    wire [15:0] signal_mux_313;
    wire signal_select_1823;
    wire [15:0] signal_mux_314;
    wire signal_select_1824;
    wire [15:0] signal_mux_315;
    wire [15:0] signal_not_19;
    wire [15:0] signal_xor_2;
    wire [14:0] signal_select_1825;
    wire [15:0] signal_cat_285;
    wire signal_select_1826;
    wire signal_xor_3;
    wire [15:0] signal_mux_316;
    wire [15:0] signal_wire_19;
    wire [15:0] signal_xor_4;
    wire [14:0] signal_select_1827;
    wire [15:0] signal_cat_286;
    wire signal_select_1828;
    wire signal_select_1829;
    wire crossing_bit;
    wire signal_select_1830;
    wire signal_select_1831;
    wire signal_select_1832;
    wire signal_select_1833;
    wire signal_select_1834;
    wire signal_select_1835;
    wire signal_select_1836;
    wire signal_select_1837;
    wire signal_select_1838;
    wire signal_select_1839;
    wire signal_select_1840;
    wire signal_select_1841;
    wire signal_select_1842;
    wire signal_select_1843;
    wire signal_select_1844;
    wire signal_select_1845;
    wire [4:0] signal_wire_20;
    wire [4:0] signal_sub_172;
    reg signal_mux_317;
    wire signal_xor_5;
    wire [15:0] signal_mux_318;
    wire signal_wire_21;
    wire [15:0] signal_mux_319;
    wire [15:0] crc_stepped;
    wire signal_eq_36;
    reg is_opcode$2;
    wire signal_or_3;
    wire signal_eq_37;
    wire bit_crosses;
    wire [15:0] signal_mux_320;
    wire signal_eq_38;
    wire signal_and_31;
    wire [15:0] crc_next;
    wire [15:0] signal_mux_321;
    wire [15:0] signal_mux_322;
    reg [15:0] signal_reg_12;
    wire [15:0] crc_0;
    wire signal_select_1846;
    wire signal_select_1847;
    wire signal_select_1848;
    wire signal_select_1849;
    wire signal_select_1850;
    wire signal_select_1851;
    wire signal_select_1852;
    wire signal_select_1853;
    wire signal_select_1854;
    wire signal_select_1855;
    wire signal_select_1856;
    wire signal_select_1857;
    wire signal_select_1858;
    wire signal_select_1859;
    wire signal_select_1860;
    wire signal_select_1861;
    wire signal_select_1862;
    wire signal_select_1863;
    wire signal_select_1864;
    wire signal_select_1865;
    wire [5:0] signal_const_362;
    wire [5:0] signal_sub_173;
    wire [5:0] signal_cat_287;
    wire signal_lt_168;
    wire signal_not_20;
    wire [5:0] signal_mux_323;
    wire [4:0] signal_select_1866;
    reg signal_mux_324;
    wire signal_lt_169;
    wire signal_and_32;
    wire signal_select_1867;
    wire signal_select_1868;
    wire signal_select_1869;
    wire signal_select_1870;
    wire signal_select_1871;
    wire signal_select_1872;
    wire signal_select_1873;
    wire signal_select_1874;
    wire signal_select_1875;
    wire signal_select_1876;
    wire signal_select_1877;
    wire signal_select_1878;
    wire signal_select_1879;
    wire signal_select_1880;
    wire signal_select_1881;
    wire signal_select_1882;
    wire signal_select_1883;
    wire signal_select_1884;
    wire signal_select_1885;
    wire signal_select_1886;
    wire [5:0] signal_sub_174;
    wire [5:0] signal_const_367;
    wire [5:0] signal_cat_288;
    wire [5:0] signal_add_6;
    wire signal_lt_170;
    wire signal_not_21;
    wire [5:0] signal_mux_325;
    wire [4:0] signal_select_1887;
    reg signal_mux_326;
    wire signal_lt_171;
    wire signal_and_33;
    wire signal_select_1888;
    wire signal_select_1889;
    wire signal_select_1890;
    wire signal_select_1891;
    wire signal_select_1892;
    wire signal_select_1893;
    wire signal_select_1894;
    wire signal_select_1895;
    wire signal_select_1896;
    wire signal_select_1897;
    wire signal_select_1898;
    wire signal_select_1899;
    wire signal_select_1900;
    wire signal_select_1901;
    wire signal_select_1902;
    wire signal_select_1903;
    wire signal_select_1904;
    wire signal_select_1905;
    wire signal_select_1906;
    wire signal_select_1907;
    wire [5:0] signal_sub_175;
    wire [5:0] signal_const_371;
    wire [5:0] signal_cat_289;
    wire [5:0] signal_add_7;
    wire signal_lt_172;
    wire signal_not_22;
    wire [5:0] signal_mux_327;
    wire [4:0] signal_select_1908;
    reg signal_mux_328;
    wire [4:0] signal_const_372;
    wire signal_lt_173;
    wire signal_and_34;
    wire signal_select_1909;
    wire signal_select_1910;
    wire signal_select_1911;
    wire signal_select_1912;
    wire signal_select_1913;
    wire signal_select_1914;
    wire signal_select_1915;
    wire signal_select_1916;
    wire signal_select_1917;
    wire signal_select_1918;
    wire signal_select_1919;
    wire signal_select_1920;
    wire signal_select_1921;
    wire signal_select_1922;
    wire signal_select_1923;
    wire signal_select_1924;
    wire signal_select_1925;
    wire signal_select_1926;
    wire signal_select_1927;
    wire signal_select_1928;
    wire [5:0] signal_sub_176;
    wire [5:0] signal_const_375;
    wire [5:0] signal_cat_290;
    wire [5:0] signal_add_8;
    wire signal_lt_174;
    wire signal_not_23;
    wire [5:0] signal_mux_329;
    wire [4:0] signal_select_1929;
    reg signal_mux_330;
    wire [4:0] signal_const_376;
    wire signal_lt_175;
    wire signal_and_35;
    wire signal_select_1930;
    wire signal_select_1931;
    wire signal_select_1932;
    wire signal_select_1933;
    wire signal_select_1934;
    wire signal_select_1935;
    wire signal_select_1936;
    wire signal_select_1937;
    wire signal_select_1938;
    wire signal_select_1939;
    wire signal_select_1940;
    wire signal_select_1941;
    wire signal_select_1942;
    wire signal_select_1943;
    wire signal_select_1944;
    wire signal_select_1945;
    wire signal_select_1946;
    wire signal_select_1947;
    wire signal_select_1948;
    wire signal_select_1949;
    wire [5:0] signal_sub_177;
    wire [5:0] signal_const_379;
    wire [5:0] signal_cat_291;
    wire [5:0] signal_add_9;
    wire signal_lt_176;
    wire signal_not_24;
    wire [5:0] signal_mux_331;
    wire [4:0] signal_select_1950;
    reg signal_mux_332;
    wire [4:0] signal_const_380;
    wire signal_lt_177;
    wire signal_and_36;
    wire signal_select_1951;
    wire signal_select_1952;
    wire signal_select_1953;
    wire signal_select_1954;
    wire signal_select_1955;
    wire signal_select_1956;
    wire signal_select_1957;
    wire signal_select_1958;
    wire signal_select_1959;
    wire signal_select_1960;
    wire signal_select_1961;
    wire signal_select_1962;
    wire signal_select_1963;
    wire signal_select_1964;
    wire signal_select_1965;
    wire signal_select_1966;
    wire signal_select_1967;
    wire signal_select_1968;
    wire signal_select_1969;
    wire signal_select_1970;
    wire [5:0] signal_sub_178;
    wire [5:0] signal_cat_292;
    wire [5:0] signal_add_10;
    wire signal_lt_178;
    wire signal_not_25;
    wire [5:0] signal_mux_333;
    wire [4:0] signal_select_1971;
    reg signal_mux_334;
    wire signal_lt_179;
    wire signal_and_37;
    wire signal_select_1972;
    wire signal_select_1973;
    wire signal_select_1974;
    wire signal_select_1975;
    wire signal_select_1976;
    wire signal_select_1977;
    wire signal_select_1978;
    wire signal_select_1979;
    wire signal_select_1980;
    wire signal_select_1981;
    wire signal_select_1982;
    wire signal_select_1983;
    wire signal_select_1984;
    wire signal_select_1985;
    wire signal_select_1986;
    wire signal_select_1987;
    wire signal_select_1988;
    wire signal_select_1989;
    wire signal_select_1990;
    wire signal_select_1991;
    wire [5:0] signal_sub_179;
    wire [5:0] signal_cat_293;
    wire [5:0] signal_add_11;
    wire signal_lt_180;
    wire signal_not_26;
    wire [5:0] signal_mux_335;
    wire [4:0] signal_select_1992;
    reg signal_mux_336;
    wire signal_lt_181;
    wire signal_and_38;
    wire signal_select_1993;
    wire signal_select_1994;
    wire signal_select_1995;
    wire signal_select_1996;
    wire signal_select_1997;
    wire signal_select_1998;
    wire signal_select_1999;
    wire signal_select_2000;
    wire signal_select_2001;
    wire signal_select_2002;
    wire signal_select_2003;
    wire signal_select_2004;
    wire signal_select_2005;
    wire signal_select_2006;
    wire signal_select_2007;
    wire signal_select_2008;
    wire signal_select_2009;
    wire signal_select_2010;
    wire signal_select_2011;
    wire signal_select_2012;
    wire [5:0] signal_sub_180;
    wire [5:0] signal_cat_294;
    wire [5:0] signal_add_12;
    wire signal_lt_182;
    wire signal_not_27;
    wire [5:0] signal_mux_337;
    wire [4:0] signal_select_2013;
    reg signal_mux_338;
    wire signal_lt_183;
    wire signal_and_39;
    wire signal_select_2014;
    wire signal_select_2015;
    wire signal_select_2016;
    wire signal_select_2017;
    wire signal_select_2018;
    wire signal_select_2019;
    wire signal_select_2020;
    wire signal_select_2021;
    wire signal_select_2022;
    wire signal_select_2023;
    wire signal_select_2024;
    wire signal_select_2025;
    wire signal_select_2026;
    wire signal_select_2027;
    wire signal_select_2028;
    wire signal_select_2029;
    wire signal_select_2030;
    wire signal_select_2031;
    wire signal_select_2032;
    wire signal_select_2033;
    wire [5:0] signal_sub_181;
    wire [5:0] signal_cat_295;
    wire [5:0] signal_add_13;
    wire signal_lt_184;
    wire signal_not_28;
    wire [5:0] signal_mux_339;
    wire [4:0] signal_select_2034;
    reg signal_mux_340;
    wire signal_lt_185;
    wire signal_and_40;
    wire signal_select_2035;
    wire signal_select_2036;
    wire signal_select_2037;
    wire signal_select_2038;
    wire signal_select_2039;
    wire signal_select_2040;
    wire signal_select_2041;
    wire signal_select_2042;
    wire signal_select_2043;
    wire signal_select_2044;
    wire signal_select_2045;
    wire signal_select_2046;
    wire signal_select_2047;
    wire signal_select_2048;
    wire signal_select_2049;
    wire signal_select_2050;
    wire signal_select_2051;
    wire signal_select_2052;
    wire signal_select_2053;
    wire signal_select_2054;
    wire [5:0] signal_sub_182;
    wire [5:0] signal_cat_296;
    wire [5:0] signal_add_14;
    wire signal_lt_186;
    wire signal_not_29;
    wire [5:0] signal_mux_341;
    wire [4:0] signal_select_2055;
    reg signal_mux_342;
    wire signal_lt_187;
    wire signal_and_41;
    wire signal_select_2056;
    wire signal_select_2057;
    wire signal_select_2058;
    wire signal_select_2059;
    wire signal_select_2060;
    wire signal_select_2061;
    wire signal_select_2062;
    wire signal_select_2063;
    wire signal_select_2064;
    wire signal_select_2065;
    wire signal_select_2066;
    wire signal_select_2067;
    wire signal_select_2068;
    wire signal_select_2069;
    wire signal_select_2070;
    wire signal_select_2071;
    wire signal_select_2072;
    wire signal_select_2073;
    wire signal_select_2074;
    wire signal_select_2075;
    wire [5:0] signal_sub_183;
    wire [5:0] signal_cat_297;
    wire [5:0] signal_add_15;
    wire signal_lt_188;
    wire signal_not_30;
    wire [5:0] signal_mux_343;
    wire [4:0] signal_select_2076;
    reg signal_mux_344;
    wire signal_lt_189;
    wire signal_and_42;
    wire signal_select_2077;
    wire signal_select_2078;
    wire signal_select_2079;
    wire signal_select_2080;
    wire signal_select_2081;
    wire signal_select_2082;
    wire signal_select_2083;
    wire signal_select_2084;
    wire signal_select_2085;
    wire signal_select_2086;
    wire signal_select_2087;
    wire signal_select_2088;
    wire signal_select_2089;
    wire signal_select_2090;
    wire signal_select_2091;
    wire signal_select_2092;
    wire signal_select_2093;
    wire signal_select_2094;
    wire signal_select_2095;
    wire signal_select_2096;
    wire [5:0] signal_sub_184;
    wire [5:0] signal_cat_298;
    wire [5:0] signal_add_16;
    wire signal_lt_190;
    wire signal_not_31;
    wire [5:0] signal_mux_345;
    wire [4:0] signal_select_2097;
    reg signal_mux_346;
    wire signal_lt_191;
    wire signal_and_43;
    wire signal_select_2098;
    wire signal_select_2099;
    wire signal_select_2100;
    wire signal_select_2101;
    wire signal_select_2102;
    wire signal_select_2103;
    wire signal_select_2104;
    wire signal_select_2105;
    wire signal_select_2106;
    wire signal_select_2107;
    wire signal_select_2108;
    wire signal_select_2109;
    wire signal_select_2110;
    wire signal_select_2111;
    wire signal_select_2112;
    wire signal_select_2113;
    wire signal_select_2114;
    wire signal_select_2115;
    wire signal_select_2116;
    wire signal_select_2117;
    wire [5:0] signal_sub_185;
    wire [5:0] signal_cat_299;
    wire [5:0] signal_add_17;
    wire signal_lt_192;
    wire signal_not_32;
    wire [5:0] signal_mux_347;
    wire [4:0] signal_select_2118;
    reg signal_mux_348;
    wire signal_lt_193;
    wire signal_and_44;
    wire signal_select_2119;
    wire signal_select_2120;
    wire signal_select_2121;
    wire signal_select_2122;
    wire signal_select_2123;
    wire signal_select_2124;
    wire signal_select_2125;
    wire signal_select_2126;
    wire signal_select_2127;
    wire signal_select_2128;
    wire signal_select_2129;
    wire signal_select_2130;
    wire signal_select_2131;
    wire signal_select_2132;
    wire signal_select_2133;
    wire signal_select_2134;
    wire signal_select_2135;
    wire signal_select_2136;
    wire signal_select_2137;
    wire signal_select_2138;
    wire [5:0] signal_sub_186;
    wire [5:0] signal_cat_300;
    wire [5:0] signal_add_18;
    wire signal_lt_194;
    wire signal_not_33;
    wire [5:0] signal_mux_349;
    wire [4:0] signal_select_2139;
    reg signal_mux_350;
    wire signal_lt_195;
    wire signal_and_45;
    wire signal_select_2140;
    wire signal_select_2141;
    wire signal_select_2142;
    wire signal_select_2143;
    wire signal_select_2144;
    wire signal_select_2145;
    wire signal_select_2146;
    wire signal_select_2147;
    wire signal_select_2148;
    wire signal_select_2149;
    wire signal_select_2150;
    wire signal_select_2151;
    wire signal_select_2152;
    wire signal_select_2153;
    wire signal_select_2154;
    wire signal_select_2155;
    wire signal_select_2156;
    wire signal_select_2157;
    wire signal_select_2158;
    wire signal_select_2159;
    wire [5:0] signal_sub_187;
    wire [5:0] signal_cat_301;
    wire [5:0] signal_add_19;
    wire signal_lt_196;
    wire signal_not_34;
    wire [5:0] signal_mux_351;
    wire [4:0] signal_select_2160;
    reg signal_mux_352;
    wire signal_lt_197;
    wire signal_and_46;
    wire signal_select_2161;
    wire signal_select_2162;
    wire signal_select_2163;
    wire signal_select_2164;
    wire signal_select_2165;
    wire signal_select_2166;
    wire signal_select_2167;
    wire signal_select_2168;
    wire signal_select_2169;
    wire signal_select_2170;
    wire signal_select_2171;
    wire signal_select_2172;
    wire signal_select_2173;
    wire signal_select_2174;
    wire signal_select_2175;
    wire signal_select_2176;
    wire signal_select_2177;
    wire signal_select_2178;
    wire signal_select_2179;
    wire signal_select_2180;
    wire [5:0] signal_sub_188;
    wire [5:0] signal_cat_302;
    wire [5:0] signal_add_20;
    wire signal_lt_198;
    wire signal_not_35;
    wire [5:0] signal_mux_353;
    wire [4:0] signal_select_2181;
    reg signal_mux_354;
    wire signal_lt_199;
    wire signal_and_47;
    wire [15:0] signal_cat_303;
    reg [15:0] signal_mux_355;
    wire [15:0] in_value;
    wire [7:0] signal_select_2182;
    wire [15:0] signal_cat_304;
    wire [11:0] signal_select_2183;
    wire [15:0] signal_cat_305;
    wire [13:0] signal_select_2184;
    wire [15:0] signal_cat_306;
    wire [14:0] signal_select_2185;
    wire [15:0] signal_cat_307;
    wire signal_select_2186;
    wire [15:0] signal_mux_356;
    wire signal_select_2187;
    wire [15:0] signal_mux_357;
    wire signal_select_2188;
    wire [15:0] signal_mux_358;
    wire signal_select_2189;
    wire [15:0] signal_mux_359;
    wire signal_select_2190;
    wire [15:0] signal_mux_360;
    wire [15:0] signal_or_4;
    wire signal_wire_22;
    wire [15:0] isr_shifted;
    wire [4:0] signal_wire_23;
    wire [4:0] signal_select_2191;
    wire [5:0] signal_cat_308;
    wire signal_eq_39;
    wire signal_and_48;
    wire [4:0] signal_mux_361;
    wire signal_eq_40;
    wire [4:0] signal_mux_362;
    wire signal_eq_41;
    wire [4:0] signal_mux_363;
    wire [4:0] signal_mux_364;
    reg [4:0] isr_count_next_value;
    reg [4:0] signal_reg_13;
    wire [4:0] isr_count_0;
    wire [5:0] signal_cat_309;
    wire [5:0] signal_add_21;
    wire signal_lt_200;
    wire [4:0] isr_count_next;
    wire signal_lt_201;
    wire signal_not_36;
    wire signal_wire_24;
    wire autopush_now;
    wire [15:0] signal_mux_365;
    reg [15:0] isr_next;
    reg [15:0] signal_reg_14;
    wire [15:0] isr_0;
    wire [15:0] signal_xor_6;
    wire [15:0] signal_sub_189;
    wire [15:0] signal_add_22;
    reg [15:0] signal_mux_366;
    wire signal_eq_42;
    wire [15:0] signal_mux_367;
    wire [15:0] signal_cat_310;
    wire signal_eq_43;
    wire [15:0] signal_mux_368;
    wire signal_eq_44;
    wire [15:0] signal_mux_369;
    wire signal_eq_45;
    wire [15:0] signal_mux_370;
    reg [15:0] p_next;
    reg [15:0] signal_reg_15;
    wire [15:0] p_0;
    wire [15:0] signal_xor_7;
    wire [15:0] signal_sub_190;
    wire [15:0] signal_add_23;
    reg [15:0] signal_mux_371;
    wire [1:0] signal_const_443;
    wire signal_eq_46;
    wire [15:0] signal_mux_372;
    wire [15:0] signal_cat_311;
    wire signal_eq_47;
    wire [15:0] signal_mux_373;
    wire signal_eq_48;
    wire [15:0] signal_mux_374;
    wire signal_eq_49;
    wire [15:0] signal_mux_375;
    wire [15:0] signal_const_448;
    wire [15:0] signal_sub_191;
    wire signal_eq_50;
    wire [15:0] signal_mux_376;
    reg [15:0] y_next;
    reg [15:0] signal_reg_16;
    wire [15:0] y_0;
    reg [15:0] signal_mux_377;
    wire [2:0] d$alu_reg$binary_variant;
    wire [2:0] d$alu_imm;
    wire [12:0] signal_const_450;
    wire [15:0] signal_cat_312;
    wire d$alu_is_reg;
    wire [15:0] alu_operand;
    wire [15:0] signal_add_24;
    wire [1:0] d$alu_op$binary_variant;
    reg [15:0] signal_mux_378;
    wire [1:0] d$alu_dest$binary_variant;
    wire signal_eq_51;
    wire [15:0] signal_mux_379;
    wire [4:0] d$set_value;
    wire [15:0] signal_cat_313;
    wire [2:0] d$set_dest$binary_variant;
    wire signal_eq_52;
    wire [15:0] signal_mux_380;
    wire signal_eq_53;
    wire [15:0] signal_mux_381;
    wire signal_eq_54;
    wire [15:0] signal_mux_382;
    wire [15:0] signal_sub_192;
    wire [2:0] d$jmp_cond$binary_variant;
    wire signal_eq_55;
    wire [15:0] signal_mux_383;
    reg [15:0] x_next;
    reg [15:0] signal_reg_17;
    wire [15:0] x_0;
    wire [23:0] signal_cat_314;
    wire signal_select_2192;
    wire signal_select_2193;
    wire signal_select_2194;
    wire signal_select_2195;
    wire signal_select_2196;
    wire signal_select_2197;
    wire signal_select_2198;
    wire signal_select_2199;
    wire signal_select_2200;
    wire signal_select_2201;
    wire signal_select_2202;
    wire signal_select_2203;
    wire signal_select_2204;
    wire signal_select_2205;
    wire signal_select_2206;
    wire signal_select_2207;
    wire signal_select_2208;
    wire signal_select_2209;
    wire signal_select_2210;
    wire signal_select_2211;
    wire [5:0] signal_sub_193;
    wire [5:0] signal_cat_315;
    wire signal_lt_202;
    wire signal_not_37;
    wire [5:0] signal_mux_384;
    wire [4:0] signal_select_2212;
    reg signal_mux_385;
    wire signal_lt_203;
    wire signal_and_49;
    wire signal_select_2213;
    wire signal_select_2214;
    wire signal_select_2215;
    wire signal_select_2216;
    wire signal_select_2217;
    wire signal_select_2218;
    wire signal_select_2219;
    wire signal_select_2220;
    wire signal_select_2221;
    wire signal_select_2222;
    wire signal_select_2223;
    wire signal_select_2224;
    wire signal_select_2225;
    wire signal_select_2226;
    wire signal_select_2227;
    wire signal_select_2228;
    wire signal_select_2229;
    wire signal_select_2230;
    wire signal_select_2231;
    wire signal_select_2232;
    wire [5:0] signal_sub_194;
    wire [5:0] signal_cat_316;
    wire [5:0] signal_add_25;
    wire signal_lt_204;
    wire signal_not_38;
    wire [5:0] signal_mux_386;
    wire [4:0] signal_select_2233;
    reg signal_mux_387;
    wire signal_lt_205;
    wire signal_and_50;
    wire signal_select_2234;
    wire signal_select_2235;
    wire signal_select_2236;
    wire signal_select_2237;
    wire signal_select_2238;
    wire signal_select_2239;
    wire signal_select_2240;
    wire signal_select_2241;
    wire signal_select_2242;
    wire signal_select_2243;
    wire signal_select_2244;
    wire signal_select_2245;
    wire signal_select_2246;
    wire signal_select_2247;
    wire signal_select_2248;
    wire signal_select_2249;
    wire signal_select_2250;
    wire signal_select_2251;
    wire signal_select_2252;
    wire signal_select_2253;
    wire [5:0] signal_sub_195;
    wire [5:0] signal_cat_317;
    wire [5:0] signal_add_26;
    wire signal_lt_206;
    wire signal_not_39;
    wire [5:0] signal_mux_388;
    wire [4:0] signal_select_2254;
    reg signal_mux_389;
    wire signal_lt_207;
    wire signal_and_51;
    wire signal_select_2255;
    wire signal_select_2256;
    wire signal_select_2257;
    wire signal_select_2258;
    wire signal_select_2259;
    wire signal_select_2260;
    wire signal_select_2261;
    wire signal_select_2262;
    wire signal_select_2263;
    wire signal_select_2264;
    wire signal_select_2265;
    wire signal_select_2266;
    wire signal_select_2267;
    wire signal_select_2268;
    wire signal_select_2269;
    wire signal_select_2270;
    wire signal_select_2271;
    wire signal_select_2272;
    wire signal_select_2273;
    wire signal_select_2274;
    wire [5:0] signal_sub_196;
    wire [5:0] signal_cat_318;
    wire [5:0] signal_add_27;
    wire signal_lt_208;
    wire signal_not_40;
    wire [5:0] signal_mux_390;
    wire [4:0] signal_select_2275;
    reg signal_mux_391;
    wire signal_lt_209;
    wire signal_and_52;
    wire signal_select_2276;
    wire signal_select_2277;
    wire signal_select_2278;
    wire signal_select_2279;
    wire signal_select_2280;
    wire signal_select_2281;
    wire signal_select_2282;
    wire signal_select_2283;
    wire signal_select_2284;
    wire signal_select_2285;
    wire signal_select_2286;
    wire signal_select_2287;
    wire signal_select_2288;
    wire signal_select_2289;
    wire signal_select_2290;
    wire signal_select_2291;
    wire signal_select_2292;
    wire signal_select_2293;
    wire signal_select_2294;
    wire signal_select_2295;
    wire [5:0] signal_sub_197;
    wire [5:0] signal_cat_319;
    wire [5:0] signal_add_28;
    wire signal_lt_210;
    wire signal_not_41;
    wire [5:0] signal_mux_392;
    wire [4:0] signal_select_2296;
    reg signal_mux_393;
    wire signal_lt_211;
    wire signal_and_53;
    wire signal_select_2297;
    wire signal_select_2298;
    wire signal_select_2299;
    wire signal_select_2300;
    wire signal_select_2301;
    wire signal_select_2302;
    wire signal_select_2303;
    wire signal_select_2304;
    wire signal_select_2305;
    wire signal_select_2306;
    wire signal_select_2307;
    wire signal_select_2308;
    wire signal_select_2309;
    wire signal_select_2310;
    wire signal_select_2311;
    wire signal_select_2312;
    wire signal_select_2313;
    wire signal_select_2314;
    wire signal_select_2315;
    wire signal_select_2316;
    wire [5:0] signal_sub_198;
    wire [5:0] signal_cat_320;
    wire [5:0] signal_add_29;
    wire signal_lt_212;
    wire signal_not_42;
    wire [5:0] signal_mux_394;
    wire [4:0] signal_select_2317;
    reg signal_mux_395;
    wire signal_lt_213;
    wire signal_and_54;
    wire signal_select_2318;
    wire signal_select_2319;
    wire signal_select_2320;
    wire signal_select_2321;
    wire signal_select_2322;
    wire signal_select_2323;
    wire signal_select_2324;
    wire signal_select_2325;
    wire signal_select_2326;
    wire signal_select_2327;
    wire signal_select_2328;
    wire signal_select_2329;
    wire signal_select_2330;
    wire signal_select_2331;
    wire signal_select_2332;
    wire signal_select_2333;
    wire signal_select_2334;
    wire signal_select_2335;
    wire signal_select_2336;
    wire signal_select_2337;
    wire [5:0] signal_sub_199;
    wire [5:0] signal_cat_321;
    wire [5:0] signal_add_30;
    wire signal_lt_214;
    wire signal_not_43;
    wire [5:0] signal_mux_396;
    wire [4:0] signal_select_2338;
    reg signal_mux_397;
    wire signal_lt_215;
    wire signal_and_55;
    wire signal_select_2339;
    wire signal_select_2340;
    wire signal_select_2341;
    wire signal_select_2342;
    wire signal_select_2343;
    wire signal_select_2344;
    wire signal_select_2345;
    wire signal_select_2346;
    wire signal_select_2347;
    wire signal_select_2348;
    wire signal_select_2349;
    wire signal_select_2350;
    wire signal_select_2351;
    wire signal_select_2352;
    wire signal_select_2353;
    wire signal_select_2354;
    wire signal_select_2355;
    wire signal_select_2356;
    wire signal_select_2357;
    wire signal_select_2358;
    wire [5:0] signal_sub_200;
    wire [5:0] signal_cat_322;
    wire [5:0] signal_add_31;
    wire signal_lt_216;
    wire signal_not_44;
    wire [5:0] signal_mux_398;
    wire [4:0] signal_select_2359;
    reg signal_mux_399;
    wire signal_lt_217;
    wire signal_and_56;
    wire signal_select_2360;
    wire signal_select_2361;
    wire signal_select_2362;
    wire signal_select_2363;
    wire signal_select_2364;
    wire signal_select_2365;
    wire signal_select_2366;
    wire signal_select_2367;
    wire signal_select_2368;
    wire signal_select_2369;
    wire signal_select_2370;
    wire signal_select_2371;
    wire signal_select_2372;
    wire signal_select_2373;
    wire signal_select_2374;
    wire signal_select_2375;
    wire signal_select_2376;
    wire signal_select_2377;
    wire signal_select_2378;
    wire signal_select_2379;
    wire [5:0] signal_sub_201;
    wire [5:0] signal_cat_323;
    wire [5:0] signal_add_32;
    wire signal_lt_218;
    wire signal_not_45;
    wire [5:0] signal_mux_400;
    wire [4:0] signal_select_2380;
    reg signal_mux_401;
    wire signal_lt_219;
    wire signal_and_57;
    wire signal_select_2381;
    wire signal_select_2382;
    wire signal_select_2383;
    wire signal_select_2384;
    wire signal_select_2385;
    wire signal_select_2386;
    wire signal_select_2387;
    wire signal_select_2388;
    wire signal_select_2389;
    wire signal_select_2390;
    wire signal_select_2391;
    wire signal_select_2392;
    wire signal_select_2393;
    wire signal_select_2394;
    wire signal_select_2395;
    wire signal_select_2396;
    wire signal_select_2397;
    wire signal_select_2398;
    wire signal_select_2399;
    wire signal_select_2400;
    wire [5:0] signal_sub_202;
    wire [5:0] signal_cat_324;
    wire [5:0] signal_add_33;
    wire signal_lt_220;
    wire signal_not_46;
    wire [5:0] signal_mux_402;
    wire [4:0] signal_select_2401;
    reg signal_mux_403;
    wire signal_lt_221;
    wire signal_and_58;
    wire signal_select_2402;
    wire signal_select_2403;
    wire signal_select_2404;
    wire signal_select_2405;
    wire signal_select_2406;
    wire signal_select_2407;
    wire signal_select_2408;
    wire signal_select_2409;
    wire signal_select_2410;
    wire signal_select_2411;
    wire signal_select_2412;
    wire signal_select_2413;
    wire signal_select_2414;
    wire signal_select_2415;
    wire signal_select_2416;
    wire signal_select_2417;
    wire signal_select_2418;
    wire signal_select_2419;
    wire signal_select_2420;
    wire signal_select_2421;
    wire [5:0] signal_sub_203;
    wire [5:0] signal_cat_325;
    wire [5:0] signal_add_34;
    wire signal_lt_222;
    wire signal_not_47;
    wire [5:0] signal_mux_404;
    wire [4:0] signal_select_2422;
    reg signal_mux_405;
    wire signal_lt_223;
    wire signal_and_59;
    wire signal_select_2423;
    wire signal_select_2424;
    wire signal_select_2425;
    wire signal_select_2426;
    wire signal_select_2427;
    wire signal_select_2428;
    wire signal_select_2429;
    wire signal_select_2430;
    wire signal_select_2431;
    wire signal_select_2432;
    wire signal_select_2433;
    wire signal_select_2434;
    wire signal_select_2435;
    wire signal_select_2436;
    wire signal_select_2437;
    wire signal_select_2438;
    wire signal_select_2439;
    wire signal_select_2440;
    wire signal_select_2441;
    wire signal_select_2442;
    wire [5:0] signal_sub_204;
    wire [5:0] signal_cat_326;
    wire [5:0] signal_add_35;
    wire signal_lt_224;
    wire signal_not_48;
    wire [5:0] signal_mux_406;
    wire [4:0] signal_select_2443;
    reg signal_mux_407;
    wire signal_lt_225;
    wire signal_and_60;
    wire signal_select_2444;
    wire signal_select_2445;
    wire signal_select_2446;
    wire signal_select_2447;
    wire signal_select_2448;
    wire signal_select_2449;
    wire signal_select_2450;
    wire signal_select_2451;
    wire signal_select_2452;
    wire signal_select_2453;
    wire signal_select_2454;
    wire signal_select_2455;
    wire signal_select_2456;
    wire signal_select_2457;
    wire signal_select_2458;
    wire signal_select_2459;
    wire signal_select_2460;
    wire signal_select_2461;
    wire signal_select_2462;
    wire signal_select_2463;
    wire [5:0] signal_sub_205;
    wire [5:0] signal_cat_327;
    wire [5:0] signal_add_36;
    wire signal_lt_226;
    wire signal_not_49;
    wire [5:0] signal_mux_408;
    wire [4:0] signal_select_2464;
    reg signal_mux_409;
    wire signal_lt_227;
    wire signal_and_61;
    wire signal_select_2465;
    wire signal_select_2466;
    wire signal_select_2467;
    wire signal_select_2468;
    wire signal_select_2469;
    wire signal_select_2470;
    wire signal_select_2471;
    wire signal_select_2472;
    wire signal_select_2473;
    wire signal_select_2474;
    wire signal_select_2475;
    wire signal_select_2476;
    wire signal_select_2477;
    wire signal_select_2478;
    wire signal_select_2479;
    wire signal_select_2480;
    wire signal_select_2481;
    wire signal_select_2482;
    wire signal_select_2483;
    wire signal_select_2484;
    wire [5:0] signal_sub_206;
    wire [5:0] signal_cat_328;
    wire [5:0] signal_add_37;
    wire signal_lt_228;
    wire signal_not_50;
    wire [5:0] signal_mux_410;
    wire [4:0] signal_select_2485;
    reg signal_mux_411;
    wire signal_lt_229;
    wire signal_and_62;
    wire signal_select_2486;
    wire signal_select_2487;
    wire signal_select_2488;
    wire signal_select_2489;
    wire signal_select_2490;
    wire signal_select_2491;
    wire signal_select_2492;
    wire signal_select_2493;
    wire signal_select_2494;
    wire signal_select_2495;
    wire signal_select_2496;
    wire signal_select_2497;
    wire signal_select_2498;
    wire signal_select_2499;
    wire signal_select_2500;
    wire signal_select_2501;
    wire signal_select_2502;
    wire signal_select_2503;
    wire signal_select_2504;
    wire signal_select_2505;
    wire [5:0] signal_sub_207;
    wire [5:0] signal_cat_329;
    wire [5:0] signal_add_38;
    wire signal_lt_230;
    wire signal_not_51;
    wire [5:0] signal_mux_412;
    wire [4:0] signal_select_2506;
    reg signal_mux_413;
    wire signal_lt_231;
    wire signal_and_63;
    wire signal_select_2507;
    wire signal_select_2508;
    wire signal_select_2509;
    wire signal_select_2510;
    wire signal_select_2511;
    wire signal_select_2512;
    wire signal_select_2513;
    wire signal_select_2514;
    wire signal_select_2515;
    wire signal_select_2516;
    wire signal_select_2517;
    wire signal_select_2518;
    wire signal_select_2519;
    wire signal_select_2520;
    wire signal_select_2521;
    wire signal_select_2522;
    wire signal_select_2523;
    wire signal_select_2524;
    wire signal_select_2525;
    wire signal_select_2526;
    wire [5:0] signal_sub_208;
    wire [4:0] signal_wire_25;
    wire [5:0] signal_cat_330;
    wire [5:0] signal_add_39;
    wire signal_lt_232;
    wire signal_not_52;
    wire [5:0] signal_mux_414;
    wire [4:0] signal_select_2527;
    reg signal_mux_415;
    wire [4:0] signal_wire_26;
    wire signal_lt_233;
    wire signal_and_64;
    wire [15:0] signal_cat_331;
    wire [23:0] signal_cat_332;
    wire [2:0] d$mov_source$binary_variant;
    reg [23:0] mov_value24;
    wire [15:0] signal_select_2528;
    wire [1:0] d$mov_op$binary_variant;
    reg [15:0] mov_value;
    wire signal_eq_56;
    wire [15:0] signal_mux_416;
    wire [7:0] signal_select_2529;
    wire [15:0] signal_cat_333;
    wire [11:0] signal_select_2530;
    wire [15:0] signal_cat_334;
    wire [13:0] signal_select_2531;
    wire [15:0] signal_cat_335;
    wire [14:0] signal_select_2532;
    wire [15:0] signal_cat_336;
    wire signal_select_2533;
    wire [15:0] signal_mux_417;
    wire signal_select_2534;
    wire [15:0] signal_mux_418;
    wire signal_select_2535;
    wire [15:0] signal_mux_419;
    wire signal_select_2536;
    wire [15:0] signal_mux_420;
    wire signal_select_2537;
    wire [15:0] signal_mux_421;
    wire [7:0] signal_select_2538;
    wire [15:0] signal_cat_337;
    wire [11:0] signal_select_2539;
    wire [15:0] signal_cat_338;
    wire [13:0] signal_select_2540;
    wire [15:0] signal_cat_339;
    wire [14:0] signal_select_2541;
    wire [15:0] signal_cat_340;
    wire signal_select_2542;
    wire [15:0] signal_mux_422;
    wire signal_select_2543;
    wire [15:0] signal_mux_423;
    wire signal_select_2544;
    wire [15:0] signal_mux_424;
    wire signal_select_2545;
    wire [15:0] signal_mux_425;
    wire signal_select_2546;
    wire [15:0] signal_mux_426;
    wire [15:0] osr_shifted;
    reg [15:0] osr_next;
    reg [15:0] signal_reg_18;
    wire [15:0] osr_0;
    wire signal_not_53;
    wire signal_and_65;
    wire signal_eq_57;
    reg is_opcode$3;
    wire signal_and_66;
    wire signal_or_5;
    wire signal_and_67;
    wire tx_pop;
    wire [15:0] signal_wire_27;
    wire signal_wire_28;
    wire [20:0] signal_inst_1;
    wire signal_select_2547;
    wire signal_not_54;
    wire [4:0] signal_wire_29;
    wire [2:0] d$sys_op$binary_variant;
    wire signal_eq_58;
    wire signal_eq_59;
    reg is_opcode$7;
    wire pulls;
    wire [4:0] signal_mux_427;
    wire [4:0] osr_count_zero;
    wire [2:0] d$mov_dest$binary_variant;
    wire signal_eq_60;
    wire [4:0] signal_mux_428;
    wire [4:0] signal_select_2548;
    wire [5:0] signal_cat_341;
    wire [4:0] osr_count_before;
    wire [5:0] signal_cat_342;
    wire [5:0] signal_add_40;
    wire signal_lt_234;
    wire [4:0] osr_count_next;
    reg [4:0] osr_count_next_value;
    reg [4:0] signal_reg_19;
    wire [4:0] osr_count_0;
    wire signal_lt_235;
    wire signal_not_55;
    wire signal_wire_30;
    wire pull_now;
    wire pull_ok;
    wire [15:0] osr_before;
    wire signal_select_2549;
    wire [15:0] signal_mux_429;
    wire signal_select_2550;
    wire [15:0] signal_mux_430;
    wire signal_select_2551;
    wire [15:0] signal_mux_431;
    wire signal_select_2552;
    wire [15:0] signal_mux_432;
    wire [4:0] shift_back;
    wire signal_select_2553;
    wire [15:0] signal_mux_433;
    wire [15:0] signal_and_68;
    wire signal_wire_31;
    wire [15:0] out_value;
    wire signal_select_2554;
    wire [3:0] signal_select_2555;
    reg signal_mux_434;
    wire signal_select_2556;
    wire [4:0] d$shift_count;
    wire [5:0] signal_cat_343;
    wire [5:0] signal_cat_344;
    wire [5:0] signal_sub_209;
    wire [5:0] signal_cat_345;
    wire [5:0] signal_sub_210;
    wire [4:0] signal_wire_32;
    wire signal_lt_236;
    wire [5:0] signal_mux_435;
    wire signal_lt_237;
    wire signal_mux_436;
    wire [19:0] signal_cat_346;
    wire [2:0] d$out_dest$binary_variant;
    wire [2:0] d$in_source$binary_variant;
    wire signal_eq_61;
    wire [19:0] signal_mux_437;
    wire signal_select_2557;
    wire signal_select_2558;
    wire signal_select_2559;
    wire signal_select_2560;
    wire signal_select_2561;
    wire signal_select_2562;
    wire signal_select_2563;
    wire signal_select_2564;
    wire signal_select_2565;
    wire signal_select_2566;
    wire signal_select_2567;
    wire signal_select_2568;
    wire signal_select_2569;
    wire signal_select_2570;
    wire signal_select_2571;
    wire signal_select_2572;
    wire signal_select_2573;
    wire signal_select_2574;
    wire signal_select_2575;
    wire signal_select_2576;
    wire signal_select_2577;
    wire signal_select_2578;
    wire signal_select_2579;
    wire signal_select_2580;
    wire signal_select_2581;
    wire signal_select_2582;
    wire signal_select_2583;
    wire signal_select_2584;
    wire [3:0] signal_select_2585;
    reg signal_mux_438;
    wire signal_select_2586;
    wire [5:0] signal_cat_347;
    wire [5:0] signal_cat_348;
    wire [5:0] signal_sub_211;
    wire [5:0] signal_cat_349;
    wire [5:0] signal_sub_212;
    wire signal_lt_238;
    wire [5:0] signal_mux_439;
    wire signal_lt_239;
    wire signal_mux_440;
    wire signal_select_2587;
    wire signal_select_2588;
    wire signal_select_2589;
    wire signal_select_2590;
    wire signal_select_2591;
    wire signal_select_2592;
    wire signal_select_2593;
    wire signal_select_2594;
    wire signal_select_2595;
    wire signal_select_2596;
    wire signal_select_2597;
    wire signal_select_2598;
    wire signal_select_2599;
    wire signal_select_2600;
    wire signal_select_2601;
    wire signal_select_2602;
    wire [3:0] signal_select_2603;
    reg signal_mux_441;
    wire signal_select_2604;
    wire [5:0] signal_cat_350;
    wire [5:0] signal_cat_351;
    wire [5:0] signal_sub_213;
    wire [5:0] signal_cat_352;
    wire [5:0] signal_sub_214;
    wire signal_lt_240;
    wire [5:0] signal_mux_442;
    wire signal_lt_241;
    wire signal_mux_443;
    wire signal_select_2605;
    wire signal_select_2606;
    wire signal_select_2607;
    wire signal_select_2608;
    wire signal_select_2609;
    wire signal_select_2610;
    wire signal_select_2611;
    wire signal_select_2612;
    wire signal_select_2613;
    wire signal_select_2614;
    wire signal_select_2615;
    wire signal_select_2616;
    wire signal_select_2617;
    wire signal_select_2618;
    wire signal_select_2619;
    wire signal_select_2620;
    wire [3:0] signal_select_2621;
    reg signal_mux_444;
    wire signal_select_2622;
    wire [5:0] signal_cat_353;
    wire [5:0] signal_cat_354;
    wire [5:0] signal_sub_215;
    wire [5:0] signal_cat_355;
    wire [5:0] signal_sub_216;
    wire signal_lt_242;
    wire [5:0] signal_mux_445;
    wire signal_lt_243;
    wire signal_mux_446;
    wire signal_select_2623;
    wire signal_select_2624;
    wire signal_select_2625;
    wire signal_select_2626;
    wire signal_select_2627;
    wire signal_select_2628;
    wire signal_select_2629;
    wire signal_select_2630;
    wire signal_select_2631;
    wire signal_select_2632;
    wire signal_select_2633;
    wire signal_select_2634;
    wire signal_select_2635;
    wire signal_select_2636;
    wire signal_select_2637;
    wire signal_select_2638;
    wire [3:0] signal_select_2639;
    reg signal_mux_447;
    wire signal_select_2640;
    wire [5:0] signal_cat_356;
    wire [5:0] signal_cat_357;
    wire [5:0] signal_sub_217;
    wire [5:0] signal_cat_358;
    wire [5:0] signal_sub_218;
    wire signal_lt_244;
    wire [5:0] signal_mux_448;
    wire signal_lt_245;
    wire signal_mux_449;
    wire signal_select_2641;
    wire signal_select_2642;
    wire signal_select_2643;
    wire signal_select_2644;
    wire signal_select_2645;
    wire signal_select_2646;
    wire signal_select_2647;
    wire signal_select_2648;
    wire signal_select_2649;
    wire signal_select_2650;
    wire signal_select_2651;
    wire signal_select_2652;
    wire signal_select_2653;
    wire signal_select_2654;
    wire signal_select_2655;
    wire signal_select_2656;
    wire [3:0] signal_select_2657;
    reg signal_mux_450;
    wire signal_select_2658;
    wire [5:0] signal_cat_359;
    wire [5:0] signal_cat_360;
    wire [5:0] signal_sub_219;
    wire [5:0] signal_cat_361;
    wire [5:0] signal_sub_220;
    wire signal_lt_246;
    wire [5:0] signal_mux_451;
    wire signal_lt_247;
    wire signal_mux_452;
    wire signal_select_2659;
    wire signal_select_2660;
    wire signal_select_2661;
    wire signal_select_2662;
    wire signal_select_2663;
    wire signal_select_2664;
    wire signal_select_2665;
    wire signal_select_2666;
    wire signal_select_2667;
    wire signal_select_2668;
    wire signal_select_2669;
    wire signal_select_2670;
    wire signal_select_2671;
    wire signal_select_2672;
    wire signal_select_2673;
    wire signal_select_2674;
    wire [3:0] signal_select_2675;
    reg signal_mux_453;
    wire signal_select_2676;
    wire [5:0] signal_cat_362;
    wire [5:0] signal_cat_363;
    wire [5:0] signal_sub_221;
    wire [5:0] signal_cat_364;
    wire [5:0] signal_sub_222;
    wire signal_lt_248;
    wire [5:0] signal_mux_454;
    wire signal_lt_249;
    wire signal_mux_455;
    wire signal_select_2677;
    wire signal_select_2678;
    wire signal_select_2679;
    wire signal_select_2680;
    wire signal_select_2681;
    wire signal_select_2682;
    wire signal_select_2683;
    wire signal_select_2684;
    wire signal_select_2685;
    wire signal_select_2686;
    wire signal_select_2687;
    wire signal_select_2688;
    wire signal_select_2689;
    wire signal_select_2690;
    wire signal_select_2691;
    wire signal_select_2692;
    wire [3:0] signal_select_2693;
    reg signal_mux_456;
    wire signal_select_2694;
    wire [5:0] signal_cat_365;
    wire [5:0] signal_cat_366;
    wire [5:0] signal_sub_223;
    wire [5:0] signal_cat_367;
    wire [5:0] signal_sub_224;
    wire signal_lt_250;
    wire [5:0] signal_mux_457;
    wire signal_lt_251;
    wire signal_mux_458;
    wire signal_select_2695;
    wire signal_select_2696;
    wire signal_select_2697;
    wire signal_select_2698;
    wire signal_select_2699;
    wire signal_select_2700;
    wire signal_select_2701;
    wire signal_select_2702;
    wire signal_select_2703;
    wire signal_select_2704;
    wire signal_select_2705;
    wire signal_select_2706;
    wire signal_select_2707;
    wire signal_select_2708;
    wire signal_select_2709;
    wire [1:0] signal_select_2710;
    wire [1:0] signal_select_2711;
    wire [4:0] signal_select_2712;
    wire signal_select_2713;
    wire [1:0] signal_cat_368;
    reg [1:0] d$side_set;
    wire [15:0] signal_cat_369;
    wire signal_select_2714;
    wire [3:0] signal_select_2715;
    reg signal_mux_459;
    wire signal_select_2716;
    wire [1:0] signal_wire_33;
    wire [4:0] signal_cat_370;
    wire [5:0] signal_cat_371;
    wire [5:0] signal_cat_372;
    wire [5:0] signal_sub_225;
    wire [5:0] signal_cat_373;
    wire [5:0] signal_sub_226;
    wire [4:0] signal_wire_34;
    wire signal_lt_252;
    wire [5:0] signal_mux_460;
    wire signal_lt_253;
    wire signal_mux_461;
    wire [19:0] pin_dir_side;
    wire signal_wire_35;
    wire [19:0] pin_dir_base;
    reg [19:0] pin_dir_next;
    reg [19:0] signal_reg_20;
    wire [19:0] pin_dir_0;
    wire signal_select_2717;
    wire signal_mux_462;
    wire [19:0] sample;
    wire signal_select_2718;
    wire [4:0] d$wait_index;
    reg wait_pin_cur;
    wire signal_eq_62;
    wire [1:0] d$wait_source$binary_variant;
    reg wait_ready;
    wire signal_not_56;
    wire gnd;
    wire signal_eq_63;
    reg is_opcode$1;
    wire wait_holds;
    wire signal_not_57;
    wire signal_eq_64;
    reg is_opcode$0;
    wire signal_not_58;
    wire op_go;
    wire advance;
    wire signal_or_6;
    wire ir_load;
    wire [4:0] signal_select_2719;
    wire signal_eq_65;
    wire [2:0] signal_select_2720;
    wire signal_lt_254;
    wire signal_select_2721;
    wire signal_not_59;
    wire signal_or_7;
    wire [1:0] signal_select_2722;
    wire signal_lt_255;
    wire signal_and_69;
    wire [2:0] signal_select_2723;
    wire signal_lt_256;
    wire [1:0] signal_select_2724;
    wire signal_lt_257;
    wire signal_lt_258;
    wire signal_not_60;
    wire [4:0] signal_select_2725;
    wire signal_lt_259;
    wire signal_not_61;
    wire signal_and_70;
    wire signal_eq_66;
    wire signal_eq_67;
    wire [4:0] signal_const_585;
    wire signal_lt_260;
    wire [4:0] signal_select_2726;
    wire signal_lt_261;
    wire [1:0] signal_select_2727;
    reg signal_mux_463;
    wire signal_select_2728;
    wire signal_not_62;
    wire [2:0] signal_select_2729;
    reg signal_mux_464;
    reg decode_ok_0;
    wire signal_not_63;
    wire signal_and_71;
    wire signal_mux_465;
    wire signal_wire_36;
    reg start_0;
    wire halted_next;
    reg signal_reg_21;
    wire halted_0;
    wire signal_not_64;
    wire signal_and_72;
    wire issue;
    wire go;
    wire jmp_go;
    wire [8:0] signal_mux_466;
    wire signal_wire_37;
    wire [8:0] signal_mux_467;
    wire [8:0] fetch_addr;
    wire [8:0] signal_mux_468;
    wire signal_wire_38;
    wire vdd;
    wire signal_wire_39;
    wire [15:0] signal_inst_2;
    wire [15:0] signal_wire_40;
    reg [15:0] word;
    wire [2:0] d$opcode$binary_variant;
    reg [19:0] pin_out_next;
    reg [19:0] signal_reg_22;
    wire [19:0] pin_out_0;
    assign signal_const = 3'b100;
    assign signal_eq = signal_select_2729 == signal_const;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            is_opcode$4 <= gnd;
        else
            if (ir_load)
                is_opcode$4 <= signal_eq;
    end
    assign signal_const_1 = 3'b101;
    assign signal_eq_1 = signal_select_2729 == signal_const_1;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            is_opcode$5 <= gnd;
        else
            if (ir_load)
                is_opcode$5 <= signal_eq_1;
    end
    assign signal_const_2 = 3'b110;
    assign signal_eq_2 = signal_select_2729 == signal_const_2;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
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
    assign signal_select_1 = signal_inst[18:16];
    assign signal_select_2 = signal_inst_1[18:16];
    assign signal_not = ~ decode_ok_0;
    assign signal_and = issue & signal_not;
    assign signal_const_3 = 1'b0;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
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
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_1 <= signal_const_3;
        else
            if (signal_and_2)
                signal_reg_1 <= vdd;
    end
    assign signal_and_3 = op_go & pushes;
    assign signal_and_4 = signal_and_3 & signal_select_1144;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_2 <= signal_const_3;
        else
            if (signal_and_4)
                signal_reg_2 <= vdd;
    end
    assign signal_and_5 = pulls & signal_select_2547;
    assign signal_and_6 = is_opcode$3 & pull_now;
    assign signal_and_7 = signal_and_6 & signal_select_2547;
    assign signal_or = signal_and_7 | signal_and_5;
    assign signal_and_8 = op_go & signal_or;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
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
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            irq_0 <= signal_const_3;
        else
            irq_0 <= signal_wire_1;
    end
    assign signal_const_10 = 20'b00000000000000000000;
    assign signal_select_4 = pin_out_base[0:0];
    assign signal_select_5 = pin_out_base[1:1];
    assign signal_select_6 = pin_out_base[2:2];
    assign signal_select_7 = pin_out_base[3:3];
    assign signal_select_8 = pin_out_base[4:4];
    assign signal_select_9 = signal_cat_43[15:15];
    assign signal_select_10 = signal_cat_43[14:14];
    assign signal_select_11 = signal_cat_43[13:13];
    assign signal_select_12 = signal_cat_43[12:12];
    assign signal_select_13 = signal_cat_43[11:11];
    assign signal_select_14 = signal_cat_43[10:10];
    assign signal_select_15 = signal_cat_43[9:9];
    assign signal_select_16 = signal_cat_43[8:8];
    assign signal_select_17 = signal_cat_43[7:7];
    assign signal_select_18 = signal_cat_43[6:6];
    assign signal_select_19 = signal_cat_43[5:5];
    assign signal_select_20 = signal_cat_43[4:4];
    assign signal_select_21 = signal_cat_43[3:3];
    assign signal_select_22 = signal_cat_43[2:2];
    assign signal_select_23 = signal_cat_43[1:1];
    assign signal_select_24 = signal_cat_43[0:0];
    assign signal_select_25 = signal_mux_3[3:0];
    always @* begin
        case (signal_select_25)
        0:
            signal_mux_2 <= signal_select_24;
        1:
            signal_mux_2 <= signal_select_23;
        2:
            signal_mux_2 <= signal_select_22;
        3:
            signal_mux_2 <= signal_select_21;
        4:
            signal_mux_2 <= signal_select_20;
        5:
            signal_mux_2 <= signal_select_19;
        6:
            signal_mux_2 <= signal_select_18;
        7:
            signal_mux_2 <= signal_select_17;
        8:
            signal_mux_2 <= signal_select_16;
        9:
            signal_mux_2 <= signal_select_15;
        10:
            signal_mux_2 <= signal_select_14;
        11:
            signal_mux_2 <= signal_select_13;
        12:
            signal_mux_2 <= signal_select_12;
        13:
            signal_mux_2 <= signal_select_11;
        14:
            signal_mux_2 <= signal_select_10;
        default:
            signal_mux_2 <= signal_select_9;
        endcase
    end
    assign signal_select_26 = pin_out_base[5:5];
    assign signal_cat_1 = { gnd,
                            signal_cat_212 };
    assign signal_cat_2 = { gnd,
                            signal_wire_14 };
    assign signal_const_11 = 6'b011001;
    assign signal_sub_2 = signal_const_11 - signal_cat_2;
    assign signal_cat_3 = { gnd,
                            signal_wire_14 };
    assign signal_const_12 = 6'b000101;
    assign signal_sub_3 = signal_const_12 - signal_cat_3;
    assign signal_const_13 = 5'b00101;
    assign signal_lt = signal_const_13 < signal_wire_14;
    assign signal_mux_3 = signal_lt ? signal_sub_2 : signal_sub_3;
    assign signal_lt_1 = signal_mux_3 < signal_cat_1;
    assign signal_mux_4 = signal_lt_1 ? signal_mux_2 : signal_select_26;
    assign signal_select_27 = signal_cat_43[15:15];
    assign signal_select_28 = signal_cat_43[14:14];
    assign signal_select_29 = signal_cat_43[13:13];
    assign signal_select_30 = signal_cat_43[12:12];
    assign signal_select_31 = signal_cat_43[11:11];
    assign signal_select_32 = signal_cat_43[10:10];
    assign signal_select_33 = signal_cat_43[9:9];
    assign signal_select_34 = signal_cat_43[8:8];
    assign signal_select_35 = signal_cat_43[7:7];
    assign signal_select_36 = signal_cat_43[6:6];
    assign signal_select_37 = signal_cat_43[5:5];
    assign signal_select_38 = signal_cat_43[4:4];
    assign signal_select_39 = signal_cat_43[3:3];
    assign signal_select_40 = signal_cat_43[2:2];
    assign signal_select_41 = signal_cat_43[1:1];
    assign signal_select_42 = signal_cat_43[0:0];
    assign signal_select_43 = signal_mux_6[3:0];
    always @* begin
        case (signal_select_43)
        0:
            signal_mux_5 <= signal_select_42;
        1:
            signal_mux_5 <= signal_select_41;
        2:
            signal_mux_5 <= signal_select_40;
        3:
            signal_mux_5 <= signal_select_39;
        4:
            signal_mux_5 <= signal_select_38;
        5:
            signal_mux_5 <= signal_select_37;
        6:
            signal_mux_5 <= signal_select_36;
        7:
            signal_mux_5 <= signal_select_35;
        8:
            signal_mux_5 <= signal_select_34;
        9:
            signal_mux_5 <= signal_select_33;
        10:
            signal_mux_5 <= signal_select_32;
        11:
            signal_mux_5 <= signal_select_31;
        12:
            signal_mux_5 <= signal_select_30;
        13:
            signal_mux_5 <= signal_select_29;
        14:
            signal_mux_5 <= signal_select_28;
        default:
            signal_mux_5 <= signal_select_27;
        endcase
    end
    assign signal_select_44 = pin_out_base[6:6];
    assign signal_cat_4 = { gnd,
                            signal_cat_212 };
    assign signal_cat_5 = { gnd,
                            signal_wire_14 };
    assign signal_const_14 = 6'b011010;
    assign signal_sub_4 = signal_const_14 - signal_cat_5;
    assign signal_cat_6 = { gnd,
                            signal_wire_14 };
    assign signal_const_15 = 6'b000110;
    assign signal_sub_5 = signal_const_15 - signal_cat_6;
    assign signal_const_16 = 5'b00110;
    assign signal_lt_2 = signal_const_16 < signal_wire_14;
    assign signal_mux_6 = signal_lt_2 ? signal_sub_4 : signal_sub_5;
    assign signal_lt_3 = signal_mux_6 < signal_cat_4;
    assign signal_mux_7 = signal_lt_3 ? signal_mux_5 : signal_select_44;
    assign signal_select_45 = signal_cat_43[15:15];
    assign signal_select_46 = signal_cat_43[14:14];
    assign signal_select_47 = signal_cat_43[13:13];
    assign signal_select_48 = signal_cat_43[12:12];
    assign signal_select_49 = signal_cat_43[11:11];
    assign signal_select_50 = signal_cat_43[10:10];
    assign signal_select_51 = signal_cat_43[9:9];
    assign signal_select_52 = signal_cat_43[8:8];
    assign signal_select_53 = signal_cat_43[7:7];
    assign signal_select_54 = signal_cat_43[6:6];
    assign signal_select_55 = signal_cat_43[5:5];
    assign signal_select_56 = signal_cat_43[4:4];
    assign signal_select_57 = signal_cat_43[3:3];
    assign signal_select_58 = signal_cat_43[2:2];
    assign signal_select_59 = signal_cat_43[1:1];
    assign signal_select_60 = signal_cat_43[0:0];
    assign signal_select_61 = signal_mux_9[3:0];
    always @* begin
        case (signal_select_61)
        0:
            signal_mux_8 <= signal_select_60;
        1:
            signal_mux_8 <= signal_select_59;
        2:
            signal_mux_8 <= signal_select_58;
        3:
            signal_mux_8 <= signal_select_57;
        4:
            signal_mux_8 <= signal_select_56;
        5:
            signal_mux_8 <= signal_select_55;
        6:
            signal_mux_8 <= signal_select_54;
        7:
            signal_mux_8 <= signal_select_53;
        8:
            signal_mux_8 <= signal_select_52;
        9:
            signal_mux_8 <= signal_select_51;
        10:
            signal_mux_8 <= signal_select_50;
        11:
            signal_mux_8 <= signal_select_49;
        12:
            signal_mux_8 <= signal_select_48;
        13:
            signal_mux_8 <= signal_select_47;
        14:
            signal_mux_8 <= signal_select_46;
        default:
            signal_mux_8 <= signal_select_45;
        endcase
    end
    assign signal_select_62 = pin_out_base[7:7];
    assign signal_cat_7 = { gnd,
                            signal_cat_212 };
    assign signal_cat_8 = { gnd,
                            signal_wire_14 };
    assign signal_const_17 = 6'b011011;
    assign signal_sub_6 = signal_const_17 - signal_cat_8;
    assign signal_cat_9 = { gnd,
                            signal_wire_14 };
    assign signal_const_18 = 6'b000111;
    assign signal_sub_7 = signal_const_18 - signal_cat_9;
    assign signal_const_19 = 5'b00111;
    assign signal_lt_4 = signal_const_19 < signal_wire_14;
    assign signal_mux_9 = signal_lt_4 ? signal_sub_6 : signal_sub_7;
    assign signal_lt_5 = signal_mux_9 < signal_cat_7;
    assign signal_mux_10 = signal_lt_5 ? signal_mux_8 : signal_select_62;
    assign signal_select_63 = signal_cat_43[15:15];
    assign signal_select_64 = signal_cat_43[14:14];
    assign signal_select_65 = signal_cat_43[13:13];
    assign signal_select_66 = signal_cat_43[12:12];
    assign signal_select_67 = signal_cat_43[11:11];
    assign signal_select_68 = signal_cat_43[10:10];
    assign signal_select_69 = signal_cat_43[9:9];
    assign signal_select_70 = signal_cat_43[8:8];
    assign signal_select_71 = signal_cat_43[7:7];
    assign signal_select_72 = signal_cat_43[6:6];
    assign signal_select_73 = signal_cat_43[5:5];
    assign signal_select_74 = signal_cat_43[4:4];
    assign signal_select_75 = signal_cat_43[3:3];
    assign signal_select_76 = signal_cat_43[2:2];
    assign signal_select_77 = signal_cat_43[1:1];
    assign signal_select_78 = signal_cat_43[0:0];
    assign signal_select_79 = signal_mux_12[3:0];
    always @* begin
        case (signal_select_79)
        0:
            signal_mux_11 <= signal_select_78;
        1:
            signal_mux_11 <= signal_select_77;
        2:
            signal_mux_11 <= signal_select_76;
        3:
            signal_mux_11 <= signal_select_75;
        4:
            signal_mux_11 <= signal_select_74;
        5:
            signal_mux_11 <= signal_select_73;
        6:
            signal_mux_11 <= signal_select_72;
        7:
            signal_mux_11 <= signal_select_71;
        8:
            signal_mux_11 <= signal_select_70;
        9:
            signal_mux_11 <= signal_select_69;
        10:
            signal_mux_11 <= signal_select_68;
        11:
            signal_mux_11 <= signal_select_67;
        12:
            signal_mux_11 <= signal_select_66;
        13:
            signal_mux_11 <= signal_select_65;
        14:
            signal_mux_11 <= signal_select_64;
        default:
            signal_mux_11 <= signal_select_63;
        endcase
    end
    assign signal_select_80 = pin_out_base[8:8];
    assign signal_cat_10 = { gnd,
                             signal_cat_212 };
    assign signal_cat_11 = { gnd,
                             signal_wire_14 };
    assign signal_const_20 = 6'b011100;
    assign signal_sub_8 = signal_const_20 - signal_cat_11;
    assign signal_cat_12 = { gnd,
                             signal_wire_14 };
    assign signal_const_21 = 6'b001000;
    assign signal_sub_9 = signal_const_21 - signal_cat_12;
    assign signal_const_22 = 5'b01000;
    assign signal_lt_6 = signal_const_22 < signal_wire_14;
    assign signal_mux_12 = signal_lt_6 ? signal_sub_8 : signal_sub_9;
    assign signal_lt_7 = signal_mux_12 < signal_cat_10;
    assign signal_mux_13 = signal_lt_7 ? signal_mux_11 : signal_select_80;
    assign signal_select_81 = signal_cat_43[15:15];
    assign signal_select_82 = signal_cat_43[14:14];
    assign signal_select_83 = signal_cat_43[13:13];
    assign signal_select_84 = signal_cat_43[12:12];
    assign signal_select_85 = signal_cat_43[11:11];
    assign signal_select_86 = signal_cat_43[10:10];
    assign signal_select_87 = signal_cat_43[9:9];
    assign signal_select_88 = signal_cat_43[8:8];
    assign signal_select_89 = signal_cat_43[7:7];
    assign signal_select_90 = signal_cat_43[6:6];
    assign signal_select_91 = signal_cat_43[5:5];
    assign signal_select_92 = signal_cat_43[4:4];
    assign signal_select_93 = signal_cat_43[3:3];
    assign signal_select_94 = signal_cat_43[2:2];
    assign signal_select_95 = signal_cat_43[1:1];
    assign signal_select_96 = signal_cat_43[0:0];
    assign signal_select_97 = signal_mux_15[3:0];
    always @* begin
        case (signal_select_97)
        0:
            signal_mux_14 <= signal_select_96;
        1:
            signal_mux_14 <= signal_select_95;
        2:
            signal_mux_14 <= signal_select_94;
        3:
            signal_mux_14 <= signal_select_93;
        4:
            signal_mux_14 <= signal_select_92;
        5:
            signal_mux_14 <= signal_select_91;
        6:
            signal_mux_14 <= signal_select_90;
        7:
            signal_mux_14 <= signal_select_89;
        8:
            signal_mux_14 <= signal_select_88;
        9:
            signal_mux_14 <= signal_select_87;
        10:
            signal_mux_14 <= signal_select_86;
        11:
            signal_mux_14 <= signal_select_85;
        12:
            signal_mux_14 <= signal_select_84;
        13:
            signal_mux_14 <= signal_select_83;
        14:
            signal_mux_14 <= signal_select_82;
        default:
            signal_mux_14 <= signal_select_81;
        endcase
    end
    assign signal_select_98 = pin_out_base[9:9];
    assign signal_cat_13 = { gnd,
                             signal_cat_212 };
    assign signal_cat_14 = { gnd,
                             signal_wire_14 };
    assign signal_const_23 = 6'b011101;
    assign signal_sub_10 = signal_const_23 - signal_cat_14;
    assign signal_cat_15 = { gnd,
                             signal_wire_14 };
    assign signal_const_24 = 6'b001001;
    assign signal_sub_11 = signal_const_24 - signal_cat_15;
    assign signal_const_25 = 5'b01001;
    assign signal_lt_8 = signal_const_25 < signal_wire_14;
    assign signal_mux_15 = signal_lt_8 ? signal_sub_10 : signal_sub_11;
    assign signal_lt_9 = signal_mux_15 < signal_cat_13;
    assign signal_mux_16 = signal_lt_9 ? signal_mux_14 : signal_select_98;
    assign signal_select_99 = signal_cat_43[15:15];
    assign signal_select_100 = signal_cat_43[14:14];
    assign signal_select_101 = signal_cat_43[13:13];
    assign signal_select_102 = signal_cat_43[12:12];
    assign signal_select_103 = signal_cat_43[11:11];
    assign signal_select_104 = signal_cat_43[10:10];
    assign signal_select_105 = signal_cat_43[9:9];
    assign signal_select_106 = signal_cat_43[8:8];
    assign signal_select_107 = signal_cat_43[7:7];
    assign signal_select_108 = signal_cat_43[6:6];
    assign signal_select_109 = signal_cat_43[5:5];
    assign signal_select_110 = signal_cat_43[4:4];
    assign signal_select_111 = signal_cat_43[3:3];
    assign signal_select_112 = signal_cat_43[2:2];
    assign signal_select_113 = signal_cat_43[1:1];
    assign signal_select_114 = signal_cat_43[0:0];
    assign signal_select_115 = signal_mux_18[3:0];
    always @* begin
        case (signal_select_115)
        0:
            signal_mux_17 <= signal_select_114;
        1:
            signal_mux_17 <= signal_select_113;
        2:
            signal_mux_17 <= signal_select_112;
        3:
            signal_mux_17 <= signal_select_111;
        4:
            signal_mux_17 <= signal_select_110;
        5:
            signal_mux_17 <= signal_select_109;
        6:
            signal_mux_17 <= signal_select_108;
        7:
            signal_mux_17 <= signal_select_107;
        8:
            signal_mux_17 <= signal_select_106;
        9:
            signal_mux_17 <= signal_select_105;
        10:
            signal_mux_17 <= signal_select_104;
        11:
            signal_mux_17 <= signal_select_103;
        12:
            signal_mux_17 <= signal_select_102;
        13:
            signal_mux_17 <= signal_select_101;
        14:
            signal_mux_17 <= signal_select_100;
        default:
            signal_mux_17 <= signal_select_99;
        endcase
    end
    assign signal_select_116 = pin_out_base[10:10];
    assign signal_cat_16 = { gnd,
                             signal_cat_212 };
    assign signal_cat_17 = { gnd,
                             signal_wire_14 };
    assign signal_const_26 = 6'b011110;
    assign signal_sub_12 = signal_const_26 - signal_cat_17;
    assign signal_cat_18 = { gnd,
                             signal_wire_14 };
    assign signal_const_27 = 6'b001010;
    assign signal_sub_13 = signal_const_27 - signal_cat_18;
    assign signal_const_28 = 5'b01010;
    assign signal_lt_10 = signal_const_28 < signal_wire_14;
    assign signal_mux_18 = signal_lt_10 ? signal_sub_12 : signal_sub_13;
    assign signal_lt_11 = signal_mux_18 < signal_cat_16;
    assign signal_mux_19 = signal_lt_11 ? signal_mux_17 : signal_select_116;
    assign signal_select_117 = signal_cat_43[15:15];
    assign signal_select_118 = signal_cat_43[14:14];
    assign signal_select_119 = signal_cat_43[13:13];
    assign signal_select_120 = signal_cat_43[12:12];
    assign signal_select_121 = signal_cat_43[11:11];
    assign signal_select_122 = signal_cat_43[10:10];
    assign signal_select_123 = signal_cat_43[9:9];
    assign signal_select_124 = signal_cat_43[8:8];
    assign signal_select_125 = signal_cat_43[7:7];
    assign signal_select_126 = signal_cat_43[6:6];
    assign signal_select_127 = signal_cat_43[5:5];
    assign signal_select_128 = signal_cat_43[4:4];
    assign signal_select_129 = signal_cat_43[3:3];
    assign signal_select_130 = signal_cat_43[2:2];
    assign signal_select_131 = signal_cat_43[1:1];
    assign signal_select_132 = signal_cat_43[0:0];
    assign signal_select_133 = signal_mux_21[3:0];
    always @* begin
        case (signal_select_133)
        0:
            signal_mux_20 <= signal_select_132;
        1:
            signal_mux_20 <= signal_select_131;
        2:
            signal_mux_20 <= signal_select_130;
        3:
            signal_mux_20 <= signal_select_129;
        4:
            signal_mux_20 <= signal_select_128;
        5:
            signal_mux_20 <= signal_select_127;
        6:
            signal_mux_20 <= signal_select_126;
        7:
            signal_mux_20 <= signal_select_125;
        8:
            signal_mux_20 <= signal_select_124;
        9:
            signal_mux_20 <= signal_select_123;
        10:
            signal_mux_20 <= signal_select_122;
        11:
            signal_mux_20 <= signal_select_121;
        12:
            signal_mux_20 <= signal_select_120;
        13:
            signal_mux_20 <= signal_select_119;
        14:
            signal_mux_20 <= signal_select_118;
        default:
            signal_mux_20 <= signal_select_117;
        endcase
    end
    assign signal_select_134 = pin_out_base[11:11];
    assign signal_cat_19 = { gnd,
                             signal_cat_212 };
    assign signal_cat_20 = { gnd,
                             signal_wire_14 };
    assign signal_const_29 = 6'b011111;
    assign signal_sub_14 = signal_const_29 - signal_cat_20;
    assign signal_cat_21 = { gnd,
                             signal_wire_14 };
    assign signal_const_30 = 6'b001011;
    assign signal_sub_15 = signal_const_30 - signal_cat_21;
    assign signal_const_31 = 5'b01011;
    assign signal_lt_12 = signal_const_31 < signal_wire_14;
    assign signal_mux_21 = signal_lt_12 ? signal_sub_14 : signal_sub_15;
    assign signal_lt_13 = signal_mux_21 < signal_cat_19;
    assign signal_mux_22 = signal_lt_13 ? signal_mux_20 : signal_select_134;
    assign signal_select_135 = signal_cat_43[15:15];
    assign signal_select_136 = signal_cat_43[14:14];
    assign signal_select_137 = signal_cat_43[13:13];
    assign signal_select_138 = signal_cat_43[12:12];
    assign signal_select_139 = signal_cat_43[11:11];
    assign signal_select_140 = signal_cat_43[10:10];
    assign signal_select_141 = signal_cat_43[9:9];
    assign signal_select_142 = signal_cat_43[8:8];
    assign signal_select_143 = signal_cat_43[7:7];
    assign signal_select_144 = signal_cat_43[6:6];
    assign signal_select_145 = signal_cat_43[5:5];
    assign signal_select_146 = signal_cat_43[4:4];
    assign signal_select_147 = signal_cat_43[3:3];
    assign signal_select_148 = signal_cat_43[2:2];
    assign signal_select_149 = signal_cat_43[1:1];
    assign signal_select_150 = signal_cat_43[0:0];
    assign signal_select_151 = signal_mux_24[3:0];
    always @* begin
        case (signal_select_151)
        0:
            signal_mux_23 <= signal_select_150;
        1:
            signal_mux_23 <= signal_select_149;
        2:
            signal_mux_23 <= signal_select_148;
        3:
            signal_mux_23 <= signal_select_147;
        4:
            signal_mux_23 <= signal_select_146;
        5:
            signal_mux_23 <= signal_select_145;
        6:
            signal_mux_23 <= signal_select_144;
        7:
            signal_mux_23 <= signal_select_143;
        8:
            signal_mux_23 <= signal_select_142;
        9:
            signal_mux_23 <= signal_select_141;
        10:
            signal_mux_23 <= signal_select_140;
        11:
            signal_mux_23 <= signal_select_139;
        12:
            signal_mux_23 <= signal_select_138;
        13:
            signal_mux_23 <= signal_select_137;
        14:
            signal_mux_23 <= signal_select_136;
        default:
            signal_mux_23 <= signal_select_135;
        endcase
    end
    assign signal_select_152 = pin_out_base[12:12];
    assign signal_cat_22 = { gnd,
                             signal_cat_212 };
    assign signal_cat_23 = { gnd,
                             signal_wire_14 };
    assign signal_const_32 = 6'b100000;
    assign signal_sub_16 = signal_const_32 - signal_cat_23;
    assign signal_cat_24 = { gnd,
                             signal_wire_14 };
    assign signal_const_33 = 6'b001100;
    assign signal_sub_17 = signal_const_33 - signal_cat_24;
    assign signal_const_34 = 5'b01100;
    assign signal_lt_14 = signal_const_34 < signal_wire_14;
    assign signal_mux_24 = signal_lt_14 ? signal_sub_16 : signal_sub_17;
    assign signal_lt_15 = signal_mux_24 < signal_cat_22;
    assign signal_mux_25 = signal_lt_15 ? signal_mux_23 : signal_select_152;
    assign signal_select_153 = signal_cat_43[15:15];
    assign signal_select_154 = signal_cat_43[14:14];
    assign signal_select_155 = signal_cat_43[13:13];
    assign signal_select_156 = signal_cat_43[12:12];
    assign signal_select_157 = signal_cat_43[11:11];
    assign signal_select_158 = signal_cat_43[10:10];
    assign signal_select_159 = signal_cat_43[9:9];
    assign signal_select_160 = signal_cat_43[8:8];
    assign signal_select_161 = signal_cat_43[7:7];
    assign signal_select_162 = signal_cat_43[6:6];
    assign signal_select_163 = signal_cat_43[5:5];
    assign signal_select_164 = signal_cat_43[4:4];
    assign signal_select_165 = signal_cat_43[3:3];
    assign signal_select_166 = signal_cat_43[2:2];
    assign signal_select_167 = signal_cat_43[1:1];
    assign signal_select_168 = signal_cat_43[0:0];
    assign signal_select_169 = signal_mux_27[3:0];
    always @* begin
        case (signal_select_169)
        0:
            signal_mux_26 <= signal_select_168;
        1:
            signal_mux_26 <= signal_select_167;
        2:
            signal_mux_26 <= signal_select_166;
        3:
            signal_mux_26 <= signal_select_165;
        4:
            signal_mux_26 <= signal_select_164;
        5:
            signal_mux_26 <= signal_select_163;
        6:
            signal_mux_26 <= signal_select_162;
        7:
            signal_mux_26 <= signal_select_161;
        8:
            signal_mux_26 <= signal_select_160;
        9:
            signal_mux_26 <= signal_select_159;
        10:
            signal_mux_26 <= signal_select_158;
        11:
            signal_mux_26 <= signal_select_157;
        12:
            signal_mux_26 <= signal_select_156;
        13:
            signal_mux_26 <= signal_select_155;
        14:
            signal_mux_26 <= signal_select_154;
        default:
            signal_mux_26 <= signal_select_153;
        endcase
    end
    assign signal_select_170 = pin_out_base[13:13];
    assign signal_cat_25 = { gnd,
                             signal_cat_212 };
    assign signal_cat_26 = { gnd,
                             signal_wire_14 };
    assign signal_const_35 = 6'b100001;
    assign signal_sub_18 = signal_const_35 - signal_cat_26;
    assign signal_cat_27 = { gnd,
                             signal_wire_14 };
    assign signal_const_36 = 6'b001101;
    assign signal_sub_19 = signal_const_36 - signal_cat_27;
    assign signal_const_37 = 5'b01101;
    assign signal_lt_16 = signal_const_37 < signal_wire_14;
    assign signal_mux_27 = signal_lt_16 ? signal_sub_18 : signal_sub_19;
    assign signal_lt_17 = signal_mux_27 < signal_cat_25;
    assign signal_mux_28 = signal_lt_17 ? signal_mux_26 : signal_select_170;
    assign signal_select_171 = signal_cat_43[15:15];
    assign signal_select_172 = signal_cat_43[14:14];
    assign signal_select_173 = signal_cat_43[13:13];
    assign signal_select_174 = signal_cat_43[12:12];
    assign signal_select_175 = signal_cat_43[11:11];
    assign signal_select_176 = signal_cat_43[10:10];
    assign signal_select_177 = signal_cat_43[9:9];
    assign signal_select_178 = signal_cat_43[8:8];
    assign signal_select_179 = signal_cat_43[7:7];
    assign signal_select_180 = signal_cat_43[6:6];
    assign signal_select_181 = signal_cat_43[5:5];
    assign signal_select_182 = signal_cat_43[4:4];
    assign signal_select_183 = signal_cat_43[3:3];
    assign signal_select_184 = signal_cat_43[2:2];
    assign signal_select_185 = signal_cat_43[1:1];
    assign signal_select_186 = signal_cat_43[0:0];
    assign signal_select_187 = signal_mux_30[3:0];
    always @* begin
        case (signal_select_187)
        0:
            signal_mux_29 <= signal_select_186;
        1:
            signal_mux_29 <= signal_select_185;
        2:
            signal_mux_29 <= signal_select_184;
        3:
            signal_mux_29 <= signal_select_183;
        4:
            signal_mux_29 <= signal_select_182;
        5:
            signal_mux_29 <= signal_select_181;
        6:
            signal_mux_29 <= signal_select_180;
        7:
            signal_mux_29 <= signal_select_179;
        8:
            signal_mux_29 <= signal_select_178;
        9:
            signal_mux_29 <= signal_select_177;
        10:
            signal_mux_29 <= signal_select_176;
        11:
            signal_mux_29 <= signal_select_175;
        12:
            signal_mux_29 <= signal_select_174;
        13:
            signal_mux_29 <= signal_select_173;
        14:
            signal_mux_29 <= signal_select_172;
        default:
            signal_mux_29 <= signal_select_171;
        endcase
    end
    assign signal_select_188 = pin_out_base[14:14];
    assign signal_cat_28 = { gnd,
                             signal_cat_212 };
    assign signal_cat_29 = { gnd,
                             signal_wire_14 };
    assign signal_const_38 = 6'b100010;
    assign signal_sub_20 = signal_const_38 - signal_cat_29;
    assign signal_cat_30 = { gnd,
                             signal_wire_14 };
    assign signal_const_39 = 6'b001110;
    assign signal_sub_21 = signal_const_39 - signal_cat_30;
    assign signal_const_40 = 5'b01110;
    assign signal_lt_18 = signal_const_40 < signal_wire_14;
    assign signal_mux_30 = signal_lt_18 ? signal_sub_20 : signal_sub_21;
    assign signal_lt_19 = signal_mux_30 < signal_cat_28;
    assign signal_mux_31 = signal_lt_19 ? signal_mux_29 : signal_select_188;
    assign signal_select_189 = signal_cat_43[15:15];
    assign signal_select_190 = signal_cat_43[14:14];
    assign signal_select_191 = signal_cat_43[13:13];
    assign signal_select_192 = signal_cat_43[12:12];
    assign signal_select_193 = signal_cat_43[11:11];
    assign signal_select_194 = signal_cat_43[10:10];
    assign signal_select_195 = signal_cat_43[9:9];
    assign signal_select_196 = signal_cat_43[8:8];
    assign signal_select_197 = signal_cat_43[7:7];
    assign signal_select_198 = signal_cat_43[6:6];
    assign signal_select_199 = signal_cat_43[5:5];
    assign signal_select_200 = signal_cat_43[4:4];
    assign signal_select_201 = signal_cat_43[3:3];
    assign signal_select_202 = signal_cat_43[2:2];
    assign signal_select_203 = signal_cat_43[1:1];
    assign signal_select_204 = signal_cat_43[0:0];
    assign signal_select_205 = signal_mux_33[3:0];
    always @* begin
        case (signal_select_205)
        0:
            signal_mux_32 <= signal_select_204;
        1:
            signal_mux_32 <= signal_select_203;
        2:
            signal_mux_32 <= signal_select_202;
        3:
            signal_mux_32 <= signal_select_201;
        4:
            signal_mux_32 <= signal_select_200;
        5:
            signal_mux_32 <= signal_select_199;
        6:
            signal_mux_32 <= signal_select_198;
        7:
            signal_mux_32 <= signal_select_197;
        8:
            signal_mux_32 <= signal_select_196;
        9:
            signal_mux_32 <= signal_select_195;
        10:
            signal_mux_32 <= signal_select_194;
        11:
            signal_mux_32 <= signal_select_193;
        12:
            signal_mux_32 <= signal_select_192;
        13:
            signal_mux_32 <= signal_select_191;
        14:
            signal_mux_32 <= signal_select_190;
        default:
            signal_mux_32 <= signal_select_189;
        endcase
    end
    assign signal_select_206 = pin_out_base[15:15];
    assign signal_cat_31 = { gnd,
                             signal_cat_212 };
    assign signal_cat_32 = { gnd,
                             signal_wire_14 };
    assign signal_const_41 = 6'b100011;
    assign signal_sub_22 = signal_const_41 - signal_cat_32;
    assign signal_cat_33 = { gnd,
                             signal_wire_14 };
    assign signal_const_42 = 6'b001111;
    assign signal_sub_23 = signal_const_42 - signal_cat_33;
    assign signal_const_43 = 5'b01111;
    assign signal_lt_20 = signal_const_43 < signal_wire_14;
    assign signal_mux_33 = signal_lt_20 ? signal_sub_22 : signal_sub_23;
    assign signal_lt_21 = signal_mux_33 < signal_cat_31;
    assign signal_mux_34 = signal_lt_21 ? signal_mux_32 : signal_select_206;
    assign signal_select_207 = signal_cat_43[15:15];
    assign signal_select_208 = signal_cat_43[14:14];
    assign signal_select_209 = signal_cat_43[13:13];
    assign signal_select_210 = signal_cat_43[12:12];
    assign signal_select_211 = signal_cat_43[11:11];
    assign signal_select_212 = signal_cat_43[10:10];
    assign signal_select_213 = signal_cat_43[9:9];
    assign signal_select_214 = signal_cat_43[8:8];
    assign signal_select_215 = signal_cat_43[7:7];
    assign signal_select_216 = signal_cat_43[6:6];
    assign signal_select_217 = signal_cat_43[5:5];
    assign signal_select_218 = signal_cat_43[4:4];
    assign signal_select_219 = signal_cat_43[3:3];
    assign signal_select_220 = signal_cat_43[2:2];
    assign signal_select_221 = signal_cat_43[1:1];
    assign signal_select_222 = signal_cat_43[0:0];
    assign signal_select_223 = signal_mux_36[3:0];
    always @* begin
        case (signal_select_223)
        0:
            signal_mux_35 <= signal_select_222;
        1:
            signal_mux_35 <= signal_select_221;
        2:
            signal_mux_35 <= signal_select_220;
        3:
            signal_mux_35 <= signal_select_219;
        4:
            signal_mux_35 <= signal_select_218;
        5:
            signal_mux_35 <= signal_select_217;
        6:
            signal_mux_35 <= signal_select_216;
        7:
            signal_mux_35 <= signal_select_215;
        8:
            signal_mux_35 <= signal_select_214;
        9:
            signal_mux_35 <= signal_select_213;
        10:
            signal_mux_35 <= signal_select_212;
        11:
            signal_mux_35 <= signal_select_211;
        12:
            signal_mux_35 <= signal_select_210;
        13:
            signal_mux_35 <= signal_select_209;
        14:
            signal_mux_35 <= signal_select_208;
        default:
            signal_mux_35 <= signal_select_207;
        endcase
    end
    assign signal_select_224 = pin_out_base[16:16];
    assign signal_cat_34 = { gnd,
                             signal_cat_212 };
    assign signal_cat_35 = { gnd,
                             signal_wire_14 };
    assign signal_const_44 = 6'b100100;
    assign signal_sub_24 = signal_const_44 - signal_cat_35;
    assign signal_cat_36 = { gnd,
                             signal_wire_14 };
    assign signal_const_45 = 6'b010000;
    assign signal_sub_25 = signal_const_45 - signal_cat_36;
    assign signal_const_46 = 5'b10000;
    assign signal_lt_22 = signal_const_46 < signal_wire_14;
    assign signal_mux_36 = signal_lt_22 ? signal_sub_24 : signal_sub_25;
    assign signal_lt_23 = signal_mux_36 < signal_cat_34;
    assign signal_mux_37 = signal_lt_23 ? signal_mux_35 : signal_select_224;
    assign signal_select_225 = signal_cat_43[15:15];
    assign signal_select_226 = signal_cat_43[14:14];
    assign signal_select_227 = signal_cat_43[13:13];
    assign signal_select_228 = signal_cat_43[12:12];
    assign signal_select_229 = signal_cat_43[11:11];
    assign signal_select_230 = signal_cat_43[10:10];
    assign signal_select_231 = signal_cat_43[9:9];
    assign signal_select_232 = signal_cat_43[8:8];
    assign signal_select_233 = signal_cat_43[7:7];
    assign signal_select_234 = signal_cat_43[6:6];
    assign signal_select_235 = signal_cat_43[5:5];
    assign signal_select_236 = signal_cat_43[4:4];
    assign signal_select_237 = signal_cat_43[3:3];
    assign signal_select_238 = signal_cat_43[2:2];
    assign signal_select_239 = signal_cat_43[1:1];
    assign signal_select_240 = signal_cat_43[0:0];
    assign signal_select_241 = signal_mux_39[3:0];
    always @* begin
        case (signal_select_241)
        0:
            signal_mux_38 <= signal_select_240;
        1:
            signal_mux_38 <= signal_select_239;
        2:
            signal_mux_38 <= signal_select_238;
        3:
            signal_mux_38 <= signal_select_237;
        4:
            signal_mux_38 <= signal_select_236;
        5:
            signal_mux_38 <= signal_select_235;
        6:
            signal_mux_38 <= signal_select_234;
        7:
            signal_mux_38 <= signal_select_233;
        8:
            signal_mux_38 <= signal_select_232;
        9:
            signal_mux_38 <= signal_select_231;
        10:
            signal_mux_38 <= signal_select_230;
        11:
            signal_mux_38 <= signal_select_229;
        12:
            signal_mux_38 <= signal_select_228;
        13:
            signal_mux_38 <= signal_select_227;
        14:
            signal_mux_38 <= signal_select_226;
        default:
            signal_mux_38 <= signal_select_225;
        endcase
    end
    assign signal_select_242 = pin_out_base[17:17];
    assign signal_cat_37 = { gnd,
                             signal_cat_212 };
    assign signal_cat_38 = { gnd,
                             signal_wire_14 };
    assign signal_const_47 = 6'b100101;
    assign signal_sub_26 = signal_const_47 - signal_cat_38;
    assign signal_cat_39 = { gnd,
                             signal_wire_14 };
    assign signal_const_48 = 6'b010001;
    assign signal_sub_27 = signal_const_48 - signal_cat_39;
    assign signal_const_49 = 5'b10001;
    assign signal_lt_24 = signal_const_49 < signal_wire_14;
    assign signal_mux_39 = signal_lt_24 ? signal_sub_26 : signal_sub_27;
    assign signal_lt_25 = signal_mux_39 < signal_cat_37;
    assign signal_mux_40 = signal_lt_25 ? signal_mux_38 : signal_select_242;
    assign signal_select_243 = signal_cat_43[15:15];
    assign signal_select_244 = signal_cat_43[14:14];
    assign signal_select_245 = signal_cat_43[13:13];
    assign signal_select_246 = signal_cat_43[12:12];
    assign signal_select_247 = signal_cat_43[11:11];
    assign signal_select_248 = signal_cat_43[10:10];
    assign signal_select_249 = signal_cat_43[9:9];
    assign signal_select_250 = signal_cat_43[8:8];
    assign signal_select_251 = signal_cat_43[7:7];
    assign signal_select_252 = signal_cat_43[6:6];
    assign signal_select_253 = signal_cat_43[5:5];
    assign signal_select_254 = signal_cat_43[4:4];
    assign signal_select_255 = signal_cat_43[3:3];
    assign signal_select_256 = signal_cat_43[2:2];
    assign signal_select_257 = signal_cat_43[1:1];
    assign signal_select_258 = signal_cat_43[0:0];
    assign signal_select_259 = signal_mux_42[3:0];
    always @* begin
        case (signal_select_259)
        0:
            signal_mux_41 <= signal_select_258;
        1:
            signal_mux_41 <= signal_select_257;
        2:
            signal_mux_41 <= signal_select_256;
        3:
            signal_mux_41 <= signal_select_255;
        4:
            signal_mux_41 <= signal_select_254;
        5:
            signal_mux_41 <= signal_select_253;
        6:
            signal_mux_41 <= signal_select_252;
        7:
            signal_mux_41 <= signal_select_251;
        8:
            signal_mux_41 <= signal_select_250;
        9:
            signal_mux_41 <= signal_select_249;
        10:
            signal_mux_41 <= signal_select_248;
        11:
            signal_mux_41 <= signal_select_247;
        12:
            signal_mux_41 <= signal_select_246;
        13:
            signal_mux_41 <= signal_select_245;
        14:
            signal_mux_41 <= signal_select_244;
        default:
            signal_mux_41 <= signal_select_243;
        endcase
    end
    assign signal_select_260 = pin_out_base[18:18];
    assign signal_cat_40 = { gnd,
                             signal_cat_212 };
    assign signal_cat_41 = { gnd,
                             signal_wire_14 };
    assign signal_const_50 = 6'b100110;
    assign signal_sub_28 = signal_const_50 - signal_cat_41;
    assign signal_cat_42 = { gnd,
                             signal_wire_14 };
    assign signal_const_51 = 6'b010010;
    assign signal_sub_29 = signal_const_51 - signal_cat_42;
    assign signal_const_52 = 5'b10010;
    assign signal_lt_26 = signal_const_52 < signal_wire_14;
    assign signal_mux_42 = signal_lt_26 ? signal_sub_28 : signal_sub_29;
    assign signal_lt_27 = signal_mux_42 < signal_cat_40;
    assign signal_mux_43 = signal_lt_27 ? signal_mux_41 : signal_select_260;
    assign signal_select_261 = signal_cat_43[15:15];
    assign signal_select_262 = signal_cat_43[14:14];
    assign signal_select_263 = signal_cat_43[13:13];
    assign signal_select_264 = signal_cat_43[12:12];
    assign signal_select_265 = signal_cat_43[11:11];
    assign signal_select_266 = signal_cat_43[10:10];
    assign signal_select_267 = signal_cat_43[9:9];
    assign signal_select_268 = signal_cat_43[8:8];
    assign signal_select_269 = signal_cat_43[7:7];
    assign signal_select_270 = signal_cat_43[6:6];
    assign signal_select_271 = signal_cat_43[5:5];
    assign signal_select_272 = signal_cat_43[4:4];
    assign signal_select_273 = signal_cat_43[3:3];
    assign signal_select_274 = signal_cat_43[2:2];
    assign signal_select_275 = signal_cat_43[1:1];
    assign signal_const_53 = 11'b00000000000;
    assign signal_cat_43 = { signal_const_53,
                             d$set_value };
    assign signal_select_276 = signal_cat_43[0:0];
    assign signal_select_277 = signal_mux_45[3:0];
    always @* begin
        case (signal_select_277)
        0:
            signal_mux_44 <= signal_select_276;
        1:
            signal_mux_44 <= signal_select_275;
        2:
            signal_mux_44 <= signal_select_274;
        3:
            signal_mux_44 <= signal_select_273;
        4:
            signal_mux_44 <= signal_select_272;
        5:
            signal_mux_44 <= signal_select_271;
        6:
            signal_mux_44 <= signal_select_270;
        7:
            signal_mux_44 <= signal_select_269;
        8:
            signal_mux_44 <= signal_select_268;
        9:
            signal_mux_44 <= signal_select_267;
        10:
            signal_mux_44 <= signal_select_266;
        11:
            signal_mux_44 <= signal_select_265;
        12:
            signal_mux_44 <= signal_select_264;
        13:
            signal_mux_44 <= signal_select_263;
        14:
            signal_mux_44 <= signal_select_262;
        default:
            signal_mux_44 <= signal_select_261;
        endcase
    end
    assign signal_select_278 = pin_out_base[19:19];
    assign signal_cat_44 = { gnd,
                             signal_cat_212 };
    assign signal_cat_45 = { gnd,
                             signal_wire_14 };
    assign signal_const_54 = 6'b100111;
    assign signal_sub_30 = signal_const_54 - signal_cat_45;
    assign signal_cat_46 = { gnd,
                             signal_wire_14 };
    assign signal_const_55 = 6'b010011;
    assign signal_sub_31 = signal_const_55 - signal_cat_46;
    assign signal_const_56 = 5'b10011;
    assign signal_lt_28 = signal_const_56 < signal_wire_14;
    assign signal_mux_45 = signal_lt_28 ? signal_sub_30 : signal_sub_31;
    assign signal_lt_29 = signal_mux_45 < signal_cat_44;
    assign signal_mux_46 = signal_lt_29 ? signal_mux_44 : signal_select_278;
    assign signal_cat_47 = { signal_mux_46,
                             signal_mux_43,
                             signal_mux_40,
                             signal_mux_37,
                             signal_mux_34,
                             signal_mux_31,
                             signal_mux_28,
                             signal_mux_25,
                             signal_mux_22,
                             signal_mux_19,
                             signal_mux_16,
                             signal_mux_13,
                             signal_mux_10,
                             signal_mux_7,
                             signal_mux_4,
                             signal_select_8,
                             signal_select_7,
                             signal_select_6,
                             signal_select_5,
                             signal_select_4 };
    assign signal_const_57 = 3'b000;
    assign signal_eq_5 = d$set_dest$binary_variant == signal_const_57;
    assign signal_mux_47 = signal_eq_5 ? signal_cat_47 : pin_out_base;
    assign signal_select_279 = pin_out_base[0:0];
    assign signal_select_280 = pin_out_base[1:1];
    assign signal_select_281 = pin_out_base[2:2];
    assign signal_select_282 = pin_out_base[3:3];
    assign signal_select_283 = pin_out_base[4:4];
    assign signal_select_284 = mov_value[15:15];
    assign signal_select_285 = mov_value[14:14];
    assign signal_select_286 = mov_value[13:13];
    assign signal_select_287 = mov_value[12:12];
    assign signal_select_288 = mov_value[11:11];
    assign signal_select_289 = mov_value[10:10];
    assign signal_select_290 = mov_value[9:9];
    assign signal_select_291 = mov_value[8:8];
    assign signal_select_292 = mov_value[7:7];
    assign signal_select_293 = mov_value[6:6];
    assign signal_select_294 = mov_value[5:5];
    assign signal_select_295 = mov_value[4:4];
    assign signal_select_296 = mov_value[3:3];
    assign signal_select_297 = mov_value[2:2];
    assign signal_select_298 = mov_value[1:1];
    assign signal_select_299 = mov_value[0:0];
    assign signal_select_300 = signal_mux_49[3:0];
    always @* begin
        case (signal_select_300)
        0:
            signal_mux_48 <= signal_select_299;
        1:
            signal_mux_48 <= signal_select_298;
        2:
            signal_mux_48 <= signal_select_297;
        3:
            signal_mux_48 <= signal_select_296;
        4:
            signal_mux_48 <= signal_select_295;
        5:
            signal_mux_48 <= signal_select_294;
        6:
            signal_mux_48 <= signal_select_293;
        7:
            signal_mux_48 <= signal_select_292;
        8:
            signal_mux_48 <= signal_select_291;
        9:
            signal_mux_48 <= signal_select_290;
        10:
            signal_mux_48 <= signal_select_289;
        11:
            signal_mux_48 <= signal_select_288;
        12:
            signal_mux_48 <= signal_select_287;
        13:
            signal_mux_48 <= signal_select_286;
        14:
            signal_mux_48 <= signal_select_285;
        default:
            signal_mux_48 <= signal_select_284;
        endcase
    end
    assign signal_select_301 = pin_out_base[5:5];
    assign signal_cat_48 = { gnd,
                             signal_wire_15 };
    assign signal_cat_49 = { gnd,
                             signal_wire_32 };
    assign signal_sub_32 = signal_const_11 - signal_cat_49;
    assign signal_cat_50 = { gnd,
                             signal_wire_32 };
    assign signal_sub_33 = signal_const_12 - signal_cat_50;
    assign signal_lt_30 = signal_const_13 < signal_wire_32;
    assign signal_mux_49 = signal_lt_30 ? signal_sub_32 : signal_sub_33;
    assign signal_lt_31 = signal_mux_49 < signal_cat_48;
    assign signal_mux_50 = signal_lt_31 ? signal_mux_48 : signal_select_301;
    assign signal_select_302 = mov_value[15:15];
    assign signal_select_303 = mov_value[14:14];
    assign signal_select_304 = mov_value[13:13];
    assign signal_select_305 = mov_value[12:12];
    assign signal_select_306 = mov_value[11:11];
    assign signal_select_307 = mov_value[10:10];
    assign signal_select_308 = mov_value[9:9];
    assign signal_select_309 = mov_value[8:8];
    assign signal_select_310 = mov_value[7:7];
    assign signal_select_311 = mov_value[6:6];
    assign signal_select_312 = mov_value[5:5];
    assign signal_select_313 = mov_value[4:4];
    assign signal_select_314 = mov_value[3:3];
    assign signal_select_315 = mov_value[2:2];
    assign signal_select_316 = mov_value[1:1];
    assign signal_select_317 = mov_value[0:0];
    assign signal_select_318 = signal_mux_52[3:0];
    always @* begin
        case (signal_select_318)
        0:
            signal_mux_51 <= signal_select_317;
        1:
            signal_mux_51 <= signal_select_316;
        2:
            signal_mux_51 <= signal_select_315;
        3:
            signal_mux_51 <= signal_select_314;
        4:
            signal_mux_51 <= signal_select_313;
        5:
            signal_mux_51 <= signal_select_312;
        6:
            signal_mux_51 <= signal_select_311;
        7:
            signal_mux_51 <= signal_select_310;
        8:
            signal_mux_51 <= signal_select_309;
        9:
            signal_mux_51 <= signal_select_308;
        10:
            signal_mux_51 <= signal_select_307;
        11:
            signal_mux_51 <= signal_select_306;
        12:
            signal_mux_51 <= signal_select_305;
        13:
            signal_mux_51 <= signal_select_304;
        14:
            signal_mux_51 <= signal_select_303;
        default:
            signal_mux_51 <= signal_select_302;
        endcase
    end
    assign signal_select_319 = pin_out_base[6:6];
    assign signal_cat_51 = { gnd,
                             signal_wire_15 };
    assign signal_cat_52 = { gnd,
                             signal_wire_32 };
    assign signal_sub_34 = signal_const_14 - signal_cat_52;
    assign signal_cat_53 = { gnd,
                             signal_wire_32 };
    assign signal_sub_35 = signal_const_15 - signal_cat_53;
    assign signal_lt_32 = signal_const_16 < signal_wire_32;
    assign signal_mux_52 = signal_lt_32 ? signal_sub_34 : signal_sub_35;
    assign signal_lt_33 = signal_mux_52 < signal_cat_51;
    assign signal_mux_53 = signal_lt_33 ? signal_mux_51 : signal_select_319;
    assign signal_select_320 = mov_value[15:15];
    assign signal_select_321 = mov_value[14:14];
    assign signal_select_322 = mov_value[13:13];
    assign signal_select_323 = mov_value[12:12];
    assign signal_select_324 = mov_value[11:11];
    assign signal_select_325 = mov_value[10:10];
    assign signal_select_326 = mov_value[9:9];
    assign signal_select_327 = mov_value[8:8];
    assign signal_select_328 = mov_value[7:7];
    assign signal_select_329 = mov_value[6:6];
    assign signal_select_330 = mov_value[5:5];
    assign signal_select_331 = mov_value[4:4];
    assign signal_select_332 = mov_value[3:3];
    assign signal_select_333 = mov_value[2:2];
    assign signal_select_334 = mov_value[1:1];
    assign signal_select_335 = mov_value[0:0];
    assign signal_select_336 = signal_mux_55[3:0];
    always @* begin
        case (signal_select_336)
        0:
            signal_mux_54 <= signal_select_335;
        1:
            signal_mux_54 <= signal_select_334;
        2:
            signal_mux_54 <= signal_select_333;
        3:
            signal_mux_54 <= signal_select_332;
        4:
            signal_mux_54 <= signal_select_331;
        5:
            signal_mux_54 <= signal_select_330;
        6:
            signal_mux_54 <= signal_select_329;
        7:
            signal_mux_54 <= signal_select_328;
        8:
            signal_mux_54 <= signal_select_327;
        9:
            signal_mux_54 <= signal_select_326;
        10:
            signal_mux_54 <= signal_select_325;
        11:
            signal_mux_54 <= signal_select_324;
        12:
            signal_mux_54 <= signal_select_323;
        13:
            signal_mux_54 <= signal_select_322;
        14:
            signal_mux_54 <= signal_select_321;
        default:
            signal_mux_54 <= signal_select_320;
        endcase
    end
    assign signal_select_337 = pin_out_base[7:7];
    assign signal_cat_54 = { gnd,
                             signal_wire_15 };
    assign signal_cat_55 = { gnd,
                             signal_wire_32 };
    assign signal_sub_36 = signal_const_17 - signal_cat_55;
    assign signal_cat_56 = { gnd,
                             signal_wire_32 };
    assign signal_sub_37 = signal_const_18 - signal_cat_56;
    assign signal_lt_34 = signal_const_19 < signal_wire_32;
    assign signal_mux_55 = signal_lt_34 ? signal_sub_36 : signal_sub_37;
    assign signal_lt_35 = signal_mux_55 < signal_cat_54;
    assign signal_mux_56 = signal_lt_35 ? signal_mux_54 : signal_select_337;
    assign signal_select_338 = mov_value[15:15];
    assign signal_select_339 = mov_value[14:14];
    assign signal_select_340 = mov_value[13:13];
    assign signal_select_341 = mov_value[12:12];
    assign signal_select_342 = mov_value[11:11];
    assign signal_select_343 = mov_value[10:10];
    assign signal_select_344 = mov_value[9:9];
    assign signal_select_345 = mov_value[8:8];
    assign signal_select_346 = mov_value[7:7];
    assign signal_select_347 = mov_value[6:6];
    assign signal_select_348 = mov_value[5:5];
    assign signal_select_349 = mov_value[4:4];
    assign signal_select_350 = mov_value[3:3];
    assign signal_select_351 = mov_value[2:2];
    assign signal_select_352 = mov_value[1:1];
    assign signal_select_353 = mov_value[0:0];
    assign signal_select_354 = signal_mux_58[3:0];
    always @* begin
        case (signal_select_354)
        0:
            signal_mux_57 <= signal_select_353;
        1:
            signal_mux_57 <= signal_select_352;
        2:
            signal_mux_57 <= signal_select_351;
        3:
            signal_mux_57 <= signal_select_350;
        4:
            signal_mux_57 <= signal_select_349;
        5:
            signal_mux_57 <= signal_select_348;
        6:
            signal_mux_57 <= signal_select_347;
        7:
            signal_mux_57 <= signal_select_346;
        8:
            signal_mux_57 <= signal_select_345;
        9:
            signal_mux_57 <= signal_select_344;
        10:
            signal_mux_57 <= signal_select_343;
        11:
            signal_mux_57 <= signal_select_342;
        12:
            signal_mux_57 <= signal_select_341;
        13:
            signal_mux_57 <= signal_select_340;
        14:
            signal_mux_57 <= signal_select_339;
        default:
            signal_mux_57 <= signal_select_338;
        endcase
    end
    assign signal_select_355 = pin_out_base[8:8];
    assign signal_cat_57 = { gnd,
                             signal_wire_15 };
    assign signal_cat_58 = { gnd,
                             signal_wire_32 };
    assign signal_sub_38 = signal_const_20 - signal_cat_58;
    assign signal_cat_59 = { gnd,
                             signal_wire_32 };
    assign signal_sub_39 = signal_const_21 - signal_cat_59;
    assign signal_lt_36 = signal_const_22 < signal_wire_32;
    assign signal_mux_58 = signal_lt_36 ? signal_sub_38 : signal_sub_39;
    assign signal_lt_37 = signal_mux_58 < signal_cat_57;
    assign signal_mux_59 = signal_lt_37 ? signal_mux_57 : signal_select_355;
    assign signal_select_356 = mov_value[15:15];
    assign signal_select_357 = mov_value[14:14];
    assign signal_select_358 = mov_value[13:13];
    assign signal_select_359 = mov_value[12:12];
    assign signal_select_360 = mov_value[11:11];
    assign signal_select_361 = mov_value[10:10];
    assign signal_select_362 = mov_value[9:9];
    assign signal_select_363 = mov_value[8:8];
    assign signal_select_364 = mov_value[7:7];
    assign signal_select_365 = mov_value[6:6];
    assign signal_select_366 = mov_value[5:5];
    assign signal_select_367 = mov_value[4:4];
    assign signal_select_368 = mov_value[3:3];
    assign signal_select_369 = mov_value[2:2];
    assign signal_select_370 = mov_value[1:1];
    assign signal_select_371 = mov_value[0:0];
    assign signal_select_372 = signal_mux_61[3:0];
    always @* begin
        case (signal_select_372)
        0:
            signal_mux_60 <= signal_select_371;
        1:
            signal_mux_60 <= signal_select_370;
        2:
            signal_mux_60 <= signal_select_369;
        3:
            signal_mux_60 <= signal_select_368;
        4:
            signal_mux_60 <= signal_select_367;
        5:
            signal_mux_60 <= signal_select_366;
        6:
            signal_mux_60 <= signal_select_365;
        7:
            signal_mux_60 <= signal_select_364;
        8:
            signal_mux_60 <= signal_select_363;
        9:
            signal_mux_60 <= signal_select_362;
        10:
            signal_mux_60 <= signal_select_361;
        11:
            signal_mux_60 <= signal_select_360;
        12:
            signal_mux_60 <= signal_select_359;
        13:
            signal_mux_60 <= signal_select_358;
        14:
            signal_mux_60 <= signal_select_357;
        default:
            signal_mux_60 <= signal_select_356;
        endcase
    end
    assign signal_select_373 = pin_out_base[9:9];
    assign signal_cat_60 = { gnd,
                             signal_wire_15 };
    assign signal_cat_61 = { gnd,
                             signal_wire_32 };
    assign signal_sub_40 = signal_const_23 - signal_cat_61;
    assign signal_cat_62 = { gnd,
                             signal_wire_32 };
    assign signal_sub_41 = signal_const_24 - signal_cat_62;
    assign signal_lt_38 = signal_const_25 < signal_wire_32;
    assign signal_mux_61 = signal_lt_38 ? signal_sub_40 : signal_sub_41;
    assign signal_lt_39 = signal_mux_61 < signal_cat_60;
    assign signal_mux_62 = signal_lt_39 ? signal_mux_60 : signal_select_373;
    assign signal_select_374 = mov_value[15:15];
    assign signal_select_375 = mov_value[14:14];
    assign signal_select_376 = mov_value[13:13];
    assign signal_select_377 = mov_value[12:12];
    assign signal_select_378 = mov_value[11:11];
    assign signal_select_379 = mov_value[10:10];
    assign signal_select_380 = mov_value[9:9];
    assign signal_select_381 = mov_value[8:8];
    assign signal_select_382 = mov_value[7:7];
    assign signal_select_383 = mov_value[6:6];
    assign signal_select_384 = mov_value[5:5];
    assign signal_select_385 = mov_value[4:4];
    assign signal_select_386 = mov_value[3:3];
    assign signal_select_387 = mov_value[2:2];
    assign signal_select_388 = mov_value[1:1];
    assign signal_select_389 = mov_value[0:0];
    assign signal_select_390 = signal_mux_64[3:0];
    always @* begin
        case (signal_select_390)
        0:
            signal_mux_63 <= signal_select_389;
        1:
            signal_mux_63 <= signal_select_388;
        2:
            signal_mux_63 <= signal_select_387;
        3:
            signal_mux_63 <= signal_select_386;
        4:
            signal_mux_63 <= signal_select_385;
        5:
            signal_mux_63 <= signal_select_384;
        6:
            signal_mux_63 <= signal_select_383;
        7:
            signal_mux_63 <= signal_select_382;
        8:
            signal_mux_63 <= signal_select_381;
        9:
            signal_mux_63 <= signal_select_380;
        10:
            signal_mux_63 <= signal_select_379;
        11:
            signal_mux_63 <= signal_select_378;
        12:
            signal_mux_63 <= signal_select_377;
        13:
            signal_mux_63 <= signal_select_376;
        14:
            signal_mux_63 <= signal_select_375;
        default:
            signal_mux_63 <= signal_select_374;
        endcase
    end
    assign signal_select_391 = pin_out_base[10:10];
    assign signal_cat_63 = { gnd,
                             signal_wire_15 };
    assign signal_cat_64 = { gnd,
                             signal_wire_32 };
    assign signal_sub_42 = signal_const_26 - signal_cat_64;
    assign signal_cat_65 = { gnd,
                             signal_wire_32 };
    assign signal_sub_43 = signal_const_27 - signal_cat_65;
    assign signal_lt_40 = signal_const_28 < signal_wire_32;
    assign signal_mux_64 = signal_lt_40 ? signal_sub_42 : signal_sub_43;
    assign signal_lt_41 = signal_mux_64 < signal_cat_63;
    assign signal_mux_65 = signal_lt_41 ? signal_mux_63 : signal_select_391;
    assign signal_select_392 = mov_value[15:15];
    assign signal_select_393 = mov_value[14:14];
    assign signal_select_394 = mov_value[13:13];
    assign signal_select_395 = mov_value[12:12];
    assign signal_select_396 = mov_value[11:11];
    assign signal_select_397 = mov_value[10:10];
    assign signal_select_398 = mov_value[9:9];
    assign signal_select_399 = mov_value[8:8];
    assign signal_select_400 = mov_value[7:7];
    assign signal_select_401 = mov_value[6:6];
    assign signal_select_402 = mov_value[5:5];
    assign signal_select_403 = mov_value[4:4];
    assign signal_select_404 = mov_value[3:3];
    assign signal_select_405 = mov_value[2:2];
    assign signal_select_406 = mov_value[1:1];
    assign signal_select_407 = mov_value[0:0];
    assign signal_select_408 = signal_mux_67[3:0];
    always @* begin
        case (signal_select_408)
        0:
            signal_mux_66 <= signal_select_407;
        1:
            signal_mux_66 <= signal_select_406;
        2:
            signal_mux_66 <= signal_select_405;
        3:
            signal_mux_66 <= signal_select_404;
        4:
            signal_mux_66 <= signal_select_403;
        5:
            signal_mux_66 <= signal_select_402;
        6:
            signal_mux_66 <= signal_select_401;
        7:
            signal_mux_66 <= signal_select_400;
        8:
            signal_mux_66 <= signal_select_399;
        9:
            signal_mux_66 <= signal_select_398;
        10:
            signal_mux_66 <= signal_select_397;
        11:
            signal_mux_66 <= signal_select_396;
        12:
            signal_mux_66 <= signal_select_395;
        13:
            signal_mux_66 <= signal_select_394;
        14:
            signal_mux_66 <= signal_select_393;
        default:
            signal_mux_66 <= signal_select_392;
        endcase
    end
    assign signal_select_409 = pin_out_base[11:11];
    assign signal_cat_66 = { gnd,
                             signal_wire_15 };
    assign signal_cat_67 = { gnd,
                             signal_wire_32 };
    assign signal_sub_44 = signal_const_29 - signal_cat_67;
    assign signal_cat_68 = { gnd,
                             signal_wire_32 };
    assign signal_sub_45 = signal_const_30 - signal_cat_68;
    assign signal_lt_42 = signal_const_31 < signal_wire_32;
    assign signal_mux_67 = signal_lt_42 ? signal_sub_44 : signal_sub_45;
    assign signal_lt_43 = signal_mux_67 < signal_cat_66;
    assign signal_mux_68 = signal_lt_43 ? signal_mux_66 : signal_select_409;
    assign signal_select_410 = mov_value[15:15];
    assign signal_select_411 = mov_value[14:14];
    assign signal_select_412 = mov_value[13:13];
    assign signal_select_413 = mov_value[12:12];
    assign signal_select_414 = mov_value[11:11];
    assign signal_select_415 = mov_value[10:10];
    assign signal_select_416 = mov_value[9:9];
    assign signal_select_417 = mov_value[8:8];
    assign signal_select_418 = mov_value[7:7];
    assign signal_select_419 = mov_value[6:6];
    assign signal_select_420 = mov_value[5:5];
    assign signal_select_421 = mov_value[4:4];
    assign signal_select_422 = mov_value[3:3];
    assign signal_select_423 = mov_value[2:2];
    assign signal_select_424 = mov_value[1:1];
    assign signal_select_425 = mov_value[0:0];
    assign signal_select_426 = signal_mux_70[3:0];
    always @* begin
        case (signal_select_426)
        0:
            signal_mux_69 <= signal_select_425;
        1:
            signal_mux_69 <= signal_select_424;
        2:
            signal_mux_69 <= signal_select_423;
        3:
            signal_mux_69 <= signal_select_422;
        4:
            signal_mux_69 <= signal_select_421;
        5:
            signal_mux_69 <= signal_select_420;
        6:
            signal_mux_69 <= signal_select_419;
        7:
            signal_mux_69 <= signal_select_418;
        8:
            signal_mux_69 <= signal_select_417;
        9:
            signal_mux_69 <= signal_select_416;
        10:
            signal_mux_69 <= signal_select_415;
        11:
            signal_mux_69 <= signal_select_414;
        12:
            signal_mux_69 <= signal_select_413;
        13:
            signal_mux_69 <= signal_select_412;
        14:
            signal_mux_69 <= signal_select_411;
        default:
            signal_mux_69 <= signal_select_410;
        endcase
    end
    assign signal_select_427 = pin_out_base[12:12];
    assign signal_cat_69 = { gnd,
                             signal_wire_15 };
    assign signal_cat_70 = { gnd,
                             signal_wire_32 };
    assign signal_sub_46 = signal_const_32 - signal_cat_70;
    assign signal_cat_71 = { gnd,
                             signal_wire_32 };
    assign signal_sub_47 = signal_const_33 - signal_cat_71;
    assign signal_lt_44 = signal_const_34 < signal_wire_32;
    assign signal_mux_70 = signal_lt_44 ? signal_sub_46 : signal_sub_47;
    assign signal_lt_45 = signal_mux_70 < signal_cat_69;
    assign signal_mux_71 = signal_lt_45 ? signal_mux_69 : signal_select_427;
    assign signal_select_428 = mov_value[15:15];
    assign signal_select_429 = mov_value[14:14];
    assign signal_select_430 = mov_value[13:13];
    assign signal_select_431 = mov_value[12:12];
    assign signal_select_432 = mov_value[11:11];
    assign signal_select_433 = mov_value[10:10];
    assign signal_select_434 = mov_value[9:9];
    assign signal_select_435 = mov_value[8:8];
    assign signal_select_436 = mov_value[7:7];
    assign signal_select_437 = mov_value[6:6];
    assign signal_select_438 = mov_value[5:5];
    assign signal_select_439 = mov_value[4:4];
    assign signal_select_440 = mov_value[3:3];
    assign signal_select_441 = mov_value[2:2];
    assign signal_select_442 = mov_value[1:1];
    assign signal_select_443 = mov_value[0:0];
    assign signal_select_444 = signal_mux_73[3:0];
    always @* begin
        case (signal_select_444)
        0:
            signal_mux_72 <= signal_select_443;
        1:
            signal_mux_72 <= signal_select_442;
        2:
            signal_mux_72 <= signal_select_441;
        3:
            signal_mux_72 <= signal_select_440;
        4:
            signal_mux_72 <= signal_select_439;
        5:
            signal_mux_72 <= signal_select_438;
        6:
            signal_mux_72 <= signal_select_437;
        7:
            signal_mux_72 <= signal_select_436;
        8:
            signal_mux_72 <= signal_select_435;
        9:
            signal_mux_72 <= signal_select_434;
        10:
            signal_mux_72 <= signal_select_433;
        11:
            signal_mux_72 <= signal_select_432;
        12:
            signal_mux_72 <= signal_select_431;
        13:
            signal_mux_72 <= signal_select_430;
        14:
            signal_mux_72 <= signal_select_429;
        default:
            signal_mux_72 <= signal_select_428;
        endcase
    end
    assign signal_select_445 = pin_out_base[13:13];
    assign signal_cat_72 = { gnd,
                             signal_wire_15 };
    assign signal_cat_73 = { gnd,
                             signal_wire_32 };
    assign signal_sub_48 = signal_const_35 - signal_cat_73;
    assign signal_cat_74 = { gnd,
                             signal_wire_32 };
    assign signal_sub_49 = signal_const_36 - signal_cat_74;
    assign signal_lt_46 = signal_const_37 < signal_wire_32;
    assign signal_mux_73 = signal_lt_46 ? signal_sub_48 : signal_sub_49;
    assign signal_lt_47 = signal_mux_73 < signal_cat_72;
    assign signal_mux_74 = signal_lt_47 ? signal_mux_72 : signal_select_445;
    assign signal_select_446 = mov_value[15:15];
    assign signal_select_447 = mov_value[14:14];
    assign signal_select_448 = mov_value[13:13];
    assign signal_select_449 = mov_value[12:12];
    assign signal_select_450 = mov_value[11:11];
    assign signal_select_451 = mov_value[10:10];
    assign signal_select_452 = mov_value[9:9];
    assign signal_select_453 = mov_value[8:8];
    assign signal_select_454 = mov_value[7:7];
    assign signal_select_455 = mov_value[6:6];
    assign signal_select_456 = mov_value[5:5];
    assign signal_select_457 = mov_value[4:4];
    assign signal_select_458 = mov_value[3:3];
    assign signal_select_459 = mov_value[2:2];
    assign signal_select_460 = mov_value[1:1];
    assign signal_select_461 = mov_value[0:0];
    assign signal_select_462 = signal_mux_76[3:0];
    always @* begin
        case (signal_select_462)
        0:
            signal_mux_75 <= signal_select_461;
        1:
            signal_mux_75 <= signal_select_460;
        2:
            signal_mux_75 <= signal_select_459;
        3:
            signal_mux_75 <= signal_select_458;
        4:
            signal_mux_75 <= signal_select_457;
        5:
            signal_mux_75 <= signal_select_456;
        6:
            signal_mux_75 <= signal_select_455;
        7:
            signal_mux_75 <= signal_select_454;
        8:
            signal_mux_75 <= signal_select_453;
        9:
            signal_mux_75 <= signal_select_452;
        10:
            signal_mux_75 <= signal_select_451;
        11:
            signal_mux_75 <= signal_select_450;
        12:
            signal_mux_75 <= signal_select_449;
        13:
            signal_mux_75 <= signal_select_448;
        14:
            signal_mux_75 <= signal_select_447;
        default:
            signal_mux_75 <= signal_select_446;
        endcase
    end
    assign signal_select_463 = pin_out_base[14:14];
    assign signal_cat_75 = { gnd,
                             signal_wire_15 };
    assign signal_cat_76 = { gnd,
                             signal_wire_32 };
    assign signal_sub_50 = signal_const_38 - signal_cat_76;
    assign signal_cat_77 = { gnd,
                             signal_wire_32 };
    assign signal_sub_51 = signal_const_39 - signal_cat_77;
    assign signal_lt_48 = signal_const_40 < signal_wire_32;
    assign signal_mux_76 = signal_lt_48 ? signal_sub_50 : signal_sub_51;
    assign signal_lt_49 = signal_mux_76 < signal_cat_75;
    assign signal_mux_77 = signal_lt_49 ? signal_mux_75 : signal_select_463;
    assign signal_select_464 = mov_value[15:15];
    assign signal_select_465 = mov_value[14:14];
    assign signal_select_466 = mov_value[13:13];
    assign signal_select_467 = mov_value[12:12];
    assign signal_select_468 = mov_value[11:11];
    assign signal_select_469 = mov_value[10:10];
    assign signal_select_470 = mov_value[9:9];
    assign signal_select_471 = mov_value[8:8];
    assign signal_select_472 = mov_value[7:7];
    assign signal_select_473 = mov_value[6:6];
    assign signal_select_474 = mov_value[5:5];
    assign signal_select_475 = mov_value[4:4];
    assign signal_select_476 = mov_value[3:3];
    assign signal_select_477 = mov_value[2:2];
    assign signal_select_478 = mov_value[1:1];
    assign signal_select_479 = mov_value[0:0];
    assign signal_select_480 = signal_mux_79[3:0];
    always @* begin
        case (signal_select_480)
        0:
            signal_mux_78 <= signal_select_479;
        1:
            signal_mux_78 <= signal_select_478;
        2:
            signal_mux_78 <= signal_select_477;
        3:
            signal_mux_78 <= signal_select_476;
        4:
            signal_mux_78 <= signal_select_475;
        5:
            signal_mux_78 <= signal_select_474;
        6:
            signal_mux_78 <= signal_select_473;
        7:
            signal_mux_78 <= signal_select_472;
        8:
            signal_mux_78 <= signal_select_471;
        9:
            signal_mux_78 <= signal_select_470;
        10:
            signal_mux_78 <= signal_select_469;
        11:
            signal_mux_78 <= signal_select_468;
        12:
            signal_mux_78 <= signal_select_467;
        13:
            signal_mux_78 <= signal_select_466;
        14:
            signal_mux_78 <= signal_select_465;
        default:
            signal_mux_78 <= signal_select_464;
        endcase
    end
    assign signal_select_481 = pin_out_base[15:15];
    assign signal_cat_78 = { gnd,
                             signal_wire_15 };
    assign signal_cat_79 = { gnd,
                             signal_wire_32 };
    assign signal_sub_52 = signal_const_41 - signal_cat_79;
    assign signal_cat_80 = { gnd,
                             signal_wire_32 };
    assign signal_sub_53 = signal_const_42 - signal_cat_80;
    assign signal_lt_50 = signal_const_43 < signal_wire_32;
    assign signal_mux_79 = signal_lt_50 ? signal_sub_52 : signal_sub_53;
    assign signal_lt_51 = signal_mux_79 < signal_cat_78;
    assign signal_mux_80 = signal_lt_51 ? signal_mux_78 : signal_select_481;
    assign signal_select_482 = mov_value[15:15];
    assign signal_select_483 = mov_value[14:14];
    assign signal_select_484 = mov_value[13:13];
    assign signal_select_485 = mov_value[12:12];
    assign signal_select_486 = mov_value[11:11];
    assign signal_select_487 = mov_value[10:10];
    assign signal_select_488 = mov_value[9:9];
    assign signal_select_489 = mov_value[8:8];
    assign signal_select_490 = mov_value[7:7];
    assign signal_select_491 = mov_value[6:6];
    assign signal_select_492 = mov_value[5:5];
    assign signal_select_493 = mov_value[4:4];
    assign signal_select_494 = mov_value[3:3];
    assign signal_select_495 = mov_value[2:2];
    assign signal_select_496 = mov_value[1:1];
    assign signal_select_497 = mov_value[0:0];
    assign signal_select_498 = signal_mux_82[3:0];
    always @* begin
        case (signal_select_498)
        0:
            signal_mux_81 <= signal_select_497;
        1:
            signal_mux_81 <= signal_select_496;
        2:
            signal_mux_81 <= signal_select_495;
        3:
            signal_mux_81 <= signal_select_494;
        4:
            signal_mux_81 <= signal_select_493;
        5:
            signal_mux_81 <= signal_select_492;
        6:
            signal_mux_81 <= signal_select_491;
        7:
            signal_mux_81 <= signal_select_490;
        8:
            signal_mux_81 <= signal_select_489;
        9:
            signal_mux_81 <= signal_select_488;
        10:
            signal_mux_81 <= signal_select_487;
        11:
            signal_mux_81 <= signal_select_486;
        12:
            signal_mux_81 <= signal_select_485;
        13:
            signal_mux_81 <= signal_select_484;
        14:
            signal_mux_81 <= signal_select_483;
        default:
            signal_mux_81 <= signal_select_482;
        endcase
    end
    assign signal_select_499 = pin_out_base[16:16];
    assign signal_cat_81 = { gnd,
                             signal_wire_15 };
    assign signal_cat_82 = { gnd,
                             signal_wire_32 };
    assign signal_sub_54 = signal_const_44 - signal_cat_82;
    assign signal_cat_83 = { gnd,
                             signal_wire_32 };
    assign signal_sub_55 = signal_const_45 - signal_cat_83;
    assign signal_lt_52 = signal_const_46 < signal_wire_32;
    assign signal_mux_82 = signal_lt_52 ? signal_sub_54 : signal_sub_55;
    assign signal_lt_53 = signal_mux_82 < signal_cat_81;
    assign signal_mux_83 = signal_lt_53 ? signal_mux_81 : signal_select_499;
    assign signal_select_500 = mov_value[15:15];
    assign signal_select_501 = mov_value[14:14];
    assign signal_select_502 = mov_value[13:13];
    assign signal_select_503 = mov_value[12:12];
    assign signal_select_504 = mov_value[11:11];
    assign signal_select_505 = mov_value[10:10];
    assign signal_select_506 = mov_value[9:9];
    assign signal_select_507 = mov_value[8:8];
    assign signal_select_508 = mov_value[7:7];
    assign signal_select_509 = mov_value[6:6];
    assign signal_select_510 = mov_value[5:5];
    assign signal_select_511 = mov_value[4:4];
    assign signal_select_512 = mov_value[3:3];
    assign signal_select_513 = mov_value[2:2];
    assign signal_select_514 = mov_value[1:1];
    assign signal_select_515 = mov_value[0:0];
    assign signal_select_516 = signal_mux_85[3:0];
    always @* begin
        case (signal_select_516)
        0:
            signal_mux_84 <= signal_select_515;
        1:
            signal_mux_84 <= signal_select_514;
        2:
            signal_mux_84 <= signal_select_513;
        3:
            signal_mux_84 <= signal_select_512;
        4:
            signal_mux_84 <= signal_select_511;
        5:
            signal_mux_84 <= signal_select_510;
        6:
            signal_mux_84 <= signal_select_509;
        7:
            signal_mux_84 <= signal_select_508;
        8:
            signal_mux_84 <= signal_select_507;
        9:
            signal_mux_84 <= signal_select_506;
        10:
            signal_mux_84 <= signal_select_505;
        11:
            signal_mux_84 <= signal_select_504;
        12:
            signal_mux_84 <= signal_select_503;
        13:
            signal_mux_84 <= signal_select_502;
        14:
            signal_mux_84 <= signal_select_501;
        default:
            signal_mux_84 <= signal_select_500;
        endcase
    end
    assign signal_select_517 = pin_out_base[17:17];
    assign signal_cat_84 = { gnd,
                             signal_wire_15 };
    assign signal_cat_85 = { gnd,
                             signal_wire_32 };
    assign signal_sub_56 = signal_const_47 - signal_cat_85;
    assign signal_cat_86 = { gnd,
                             signal_wire_32 };
    assign signal_sub_57 = signal_const_48 - signal_cat_86;
    assign signal_lt_54 = signal_const_49 < signal_wire_32;
    assign signal_mux_85 = signal_lt_54 ? signal_sub_56 : signal_sub_57;
    assign signal_lt_55 = signal_mux_85 < signal_cat_84;
    assign signal_mux_86 = signal_lt_55 ? signal_mux_84 : signal_select_517;
    assign signal_select_518 = mov_value[15:15];
    assign signal_select_519 = mov_value[14:14];
    assign signal_select_520 = mov_value[13:13];
    assign signal_select_521 = mov_value[12:12];
    assign signal_select_522 = mov_value[11:11];
    assign signal_select_523 = mov_value[10:10];
    assign signal_select_524 = mov_value[9:9];
    assign signal_select_525 = mov_value[8:8];
    assign signal_select_526 = mov_value[7:7];
    assign signal_select_527 = mov_value[6:6];
    assign signal_select_528 = mov_value[5:5];
    assign signal_select_529 = mov_value[4:4];
    assign signal_select_530 = mov_value[3:3];
    assign signal_select_531 = mov_value[2:2];
    assign signal_select_532 = mov_value[1:1];
    assign signal_select_533 = mov_value[0:0];
    assign signal_select_534 = signal_mux_88[3:0];
    always @* begin
        case (signal_select_534)
        0:
            signal_mux_87 <= signal_select_533;
        1:
            signal_mux_87 <= signal_select_532;
        2:
            signal_mux_87 <= signal_select_531;
        3:
            signal_mux_87 <= signal_select_530;
        4:
            signal_mux_87 <= signal_select_529;
        5:
            signal_mux_87 <= signal_select_528;
        6:
            signal_mux_87 <= signal_select_527;
        7:
            signal_mux_87 <= signal_select_526;
        8:
            signal_mux_87 <= signal_select_525;
        9:
            signal_mux_87 <= signal_select_524;
        10:
            signal_mux_87 <= signal_select_523;
        11:
            signal_mux_87 <= signal_select_522;
        12:
            signal_mux_87 <= signal_select_521;
        13:
            signal_mux_87 <= signal_select_520;
        14:
            signal_mux_87 <= signal_select_519;
        default:
            signal_mux_87 <= signal_select_518;
        endcase
    end
    assign signal_select_535 = pin_out_base[18:18];
    assign signal_cat_87 = { gnd,
                             signal_wire_15 };
    assign signal_cat_88 = { gnd,
                             signal_wire_32 };
    assign signal_sub_58 = signal_const_50 - signal_cat_88;
    assign signal_cat_89 = { gnd,
                             signal_wire_32 };
    assign signal_sub_59 = signal_const_51 - signal_cat_89;
    assign signal_lt_56 = signal_const_52 < signal_wire_32;
    assign signal_mux_88 = signal_lt_56 ? signal_sub_58 : signal_sub_59;
    assign signal_lt_57 = signal_mux_88 < signal_cat_87;
    assign signal_mux_89 = signal_lt_57 ? signal_mux_87 : signal_select_535;
    assign signal_select_536 = mov_value[15:15];
    assign signal_select_537 = mov_value[14:14];
    assign signal_select_538 = mov_value[13:13];
    assign signal_select_539 = mov_value[12:12];
    assign signal_select_540 = mov_value[11:11];
    assign signal_select_541 = mov_value[10:10];
    assign signal_select_542 = mov_value[9:9];
    assign signal_select_543 = mov_value[8:8];
    assign signal_select_544 = mov_value[7:7];
    assign signal_select_545 = mov_value[6:6];
    assign signal_select_546 = mov_value[5:5];
    assign signal_select_547 = mov_value[4:4];
    assign signal_select_548 = mov_value[3:3];
    assign signal_select_549 = mov_value[2:2];
    assign signal_select_550 = mov_value[1:1];
    assign signal_select_551 = mov_value[0:0];
    assign signal_select_552 = signal_mux_91[3:0];
    always @* begin
        case (signal_select_552)
        0:
            signal_mux_90 <= signal_select_551;
        1:
            signal_mux_90 <= signal_select_550;
        2:
            signal_mux_90 <= signal_select_549;
        3:
            signal_mux_90 <= signal_select_548;
        4:
            signal_mux_90 <= signal_select_547;
        5:
            signal_mux_90 <= signal_select_546;
        6:
            signal_mux_90 <= signal_select_545;
        7:
            signal_mux_90 <= signal_select_544;
        8:
            signal_mux_90 <= signal_select_543;
        9:
            signal_mux_90 <= signal_select_542;
        10:
            signal_mux_90 <= signal_select_541;
        11:
            signal_mux_90 <= signal_select_540;
        12:
            signal_mux_90 <= signal_select_539;
        13:
            signal_mux_90 <= signal_select_538;
        14:
            signal_mux_90 <= signal_select_537;
        default:
            signal_mux_90 <= signal_select_536;
        endcase
    end
    assign signal_select_553 = pin_out_base[19:19];
    assign signal_cat_90 = { gnd,
                             signal_wire_15 };
    assign signal_cat_91 = { gnd,
                             signal_wire_32 };
    assign signal_sub_60 = signal_const_54 - signal_cat_91;
    assign signal_cat_92 = { gnd,
                             signal_wire_32 };
    assign signal_sub_61 = signal_const_55 - signal_cat_92;
    assign signal_lt_58 = signal_const_56 < signal_wire_32;
    assign signal_mux_91 = signal_lt_58 ? signal_sub_60 : signal_sub_61;
    assign signal_lt_59 = signal_mux_91 < signal_cat_90;
    assign signal_mux_92 = signal_lt_59 ? signal_mux_90 : signal_select_553;
    assign signal_cat_93 = { signal_mux_92,
                             signal_mux_89,
                             signal_mux_86,
                             signal_mux_83,
                             signal_mux_80,
                             signal_mux_77,
                             signal_mux_74,
                             signal_mux_71,
                             signal_mux_68,
                             signal_mux_65,
                             signal_mux_62,
                             signal_mux_59,
                             signal_mux_56,
                             signal_mux_53,
                             signal_mux_50,
                             signal_select_283,
                             signal_select_282,
                             signal_select_281,
                             signal_select_280,
                             signal_select_279 };
    assign signal_eq_6 = d$mov_dest$binary_variant == signal_const_57;
    assign signal_mux_93 = signal_eq_6 ? signal_cat_93 : pin_out_base;
    assign signal_select_554 = pin_out_base[0:0];
    assign signal_select_555 = pin_out_base[1:1];
    assign signal_select_556 = pin_out_base[2:2];
    assign signal_select_557 = pin_out_base[3:3];
    assign signal_select_558 = pin_out_base[4:4];
    assign signal_select_559 = out_value[15:15];
    assign signal_select_560 = out_value[14:14];
    assign signal_select_561 = out_value[13:13];
    assign signal_select_562 = out_value[12:12];
    assign signal_select_563 = out_value[11:11];
    assign signal_select_564 = out_value[10:10];
    assign signal_select_565 = out_value[9:9];
    assign signal_select_566 = out_value[8:8];
    assign signal_select_567 = out_value[7:7];
    assign signal_select_568 = out_value[6:6];
    assign signal_select_569 = out_value[5:5];
    assign signal_select_570 = out_value[4:4];
    assign signal_select_571 = out_value[3:3];
    assign signal_select_572 = out_value[2:2];
    assign signal_select_573 = out_value[1:1];
    assign signal_select_574 = out_value[0:0];
    assign signal_select_575 = signal_mux_95[3:0];
    always @* begin
        case (signal_select_575)
        0:
            signal_mux_94 <= signal_select_574;
        1:
            signal_mux_94 <= signal_select_573;
        2:
            signal_mux_94 <= signal_select_572;
        3:
            signal_mux_94 <= signal_select_571;
        4:
            signal_mux_94 <= signal_select_570;
        5:
            signal_mux_94 <= signal_select_569;
        6:
            signal_mux_94 <= signal_select_568;
        7:
            signal_mux_94 <= signal_select_567;
        8:
            signal_mux_94 <= signal_select_566;
        9:
            signal_mux_94 <= signal_select_565;
        10:
            signal_mux_94 <= signal_select_564;
        11:
            signal_mux_94 <= signal_select_563;
        12:
            signal_mux_94 <= signal_select_562;
        13:
            signal_mux_94 <= signal_select_561;
        14:
            signal_mux_94 <= signal_select_560;
        default:
            signal_mux_94 <= signal_select_559;
        endcase
    end
    assign signal_select_576 = pin_out_base[5:5];
    assign signal_cat_94 = { gnd,
                             d$shift_count };
    assign signal_cat_95 = { gnd,
                             signal_wire_32 };
    assign signal_sub_62 = signal_const_11 - signal_cat_95;
    assign signal_cat_96 = { gnd,
                             signal_wire_32 };
    assign signal_sub_63 = signal_const_12 - signal_cat_96;
    assign signal_lt_60 = signal_const_13 < signal_wire_32;
    assign signal_mux_95 = signal_lt_60 ? signal_sub_62 : signal_sub_63;
    assign signal_lt_61 = signal_mux_95 < signal_cat_94;
    assign signal_mux_96 = signal_lt_61 ? signal_mux_94 : signal_select_576;
    assign signal_select_577 = out_value[15:15];
    assign signal_select_578 = out_value[14:14];
    assign signal_select_579 = out_value[13:13];
    assign signal_select_580 = out_value[12:12];
    assign signal_select_581 = out_value[11:11];
    assign signal_select_582 = out_value[10:10];
    assign signal_select_583 = out_value[9:9];
    assign signal_select_584 = out_value[8:8];
    assign signal_select_585 = out_value[7:7];
    assign signal_select_586 = out_value[6:6];
    assign signal_select_587 = out_value[5:5];
    assign signal_select_588 = out_value[4:4];
    assign signal_select_589 = out_value[3:3];
    assign signal_select_590 = out_value[2:2];
    assign signal_select_591 = out_value[1:1];
    assign signal_select_592 = out_value[0:0];
    assign signal_select_593 = signal_mux_98[3:0];
    always @* begin
        case (signal_select_593)
        0:
            signal_mux_97 <= signal_select_592;
        1:
            signal_mux_97 <= signal_select_591;
        2:
            signal_mux_97 <= signal_select_590;
        3:
            signal_mux_97 <= signal_select_589;
        4:
            signal_mux_97 <= signal_select_588;
        5:
            signal_mux_97 <= signal_select_587;
        6:
            signal_mux_97 <= signal_select_586;
        7:
            signal_mux_97 <= signal_select_585;
        8:
            signal_mux_97 <= signal_select_584;
        9:
            signal_mux_97 <= signal_select_583;
        10:
            signal_mux_97 <= signal_select_582;
        11:
            signal_mux_97 <= signal_select_581;
        12:
            signal_mux_97 <= signal_select_580;
        13:
            signal_mux_97 <= signal_select_579;
        14:
            signal_mux_97 <= signal_select_578;
        default:
            signal_mux_97 <= signal_select_577;
        endcase
    end
    assign signal_select_594 = pin_out_base[6:6];
    assign signal_cat_97 = { gnd,
                             d$shift_count };
    assign signal_cat_98 = { gnd,
                             signal_wire_32 };
    assign signal_sub_64 = signal_const_14 - signal_cat_98;
    assign signal_cat_99 = { gnd,
                             signal_wire_32 };
    assign signal_sub_65 = signal_const_15 - signal_cat_99;
    assign signal_lt_62 = signal_const_16 < signal_wire_32;
    assign signal_mux_98 = signal_lt_62 ? signal_sub_64 : signal_sub_65;
    assign signal_lt_63 = signal_mux_98 < signal_cat_97;
    assign signal_mux_99 = signal_lt_63 ? signal_mux_97 : signal_select_594;
    assign signal_select_595 = out_value[15:15];
    assign signal_select_596 = out_value[14:14];
    assign signal_select_597 = out_value[13:13];
    assign signal_select_598 = out_value[12:12];
    assign signal_select_599 = out_value[11:11];
    assign signal_select_600 = out_value[10:10];
    assign signal_select_601 = out_value[9:9];
    assign signal_select_602 = out_value[8:8];
    assign signal_select_603 = out_value[7:7];
    assign signal_select_604 = out_value[6:6];
    assign signal_select_605 = out_value[5:5];
    assign signal_select_606 = out_value[4:4];
    assign signal_select_607 = out_value[3:3];
    assign signal_select_608 = out_value[2:2];
    assign signal_select_609 = out_value[1:1];
    assign signal_select_610 = out_value[0:0];
    assign signal_select_611 = signal_mux_101[3:0];
    always @* begin
        case (signal_select_611)
        0:
            signal_mux_100 <= signal_select_610;
        1:
            signal_mux_100 <= signal_select_609;
        2:
            signal_mux_100 <= signal_select_608;
        3:
            signal_mux_100 <= signal_select_607;
        4:
            signal_mux_100 <= signal_select_606;
        5:
            signal_mux_100 <= signal_select_605;
        6:
            signal_mux_100 <= signal_select_604;
        7:
            signal_mux_100 <= signal_select_603;
        8:
            signal_mux_100 <= signal_select_602;
        9:
            signal_mux_100 <= signal_select_601;
        10:
            signal_mux_100 <= signal_select_600;
        11:
            signal_mux_100 <= signal_select_599;
        12:
            signal_mux_100 <= signal_select_598;
        13:
            signal_mux_100 <= signal_select_597;
        14:
            signal_mux_100 <= signal_select_596;
        default:
            signal_mux_100 <= signal_select_595;
        endcase
    end
    assign signal_select_612 = pin_out_base[7:7];
    assign signal_cat_100 = { gnd,
                              d$shift_count };
    assign signal_cat_101 = { gnd,
                              signal_wire_32 };
    assign signal_sub_66 = signal_const_17 - signal_cat_101;
    assign signal_cat_102 = { gnd,
                              signal_wire_32 };
    assign signal_sub_67 = signal_const_18 - signal_cat_102;
    assign signal_lt_64 = signal_const_19 < signal_wire_32;
    assign signal_mux_101 = signal_lt_64 ? signal_sub_66 : signal_sub_67;
    assign signal_lt_65 = signal_mux_101 < signal_cat_100;
    assign signal_mux_102 = signal_lt_65 ? signal_mux_100 : signal_select_612;
    assign signal_select_613 = out_value[15:15];
    assign signal_select_614 = out_value[14:14];
    assign signal_select_615 = out_value[13:13];
    assign signal_select_616 = out_value[12:12];
    assign signal_select_617 = out_value[11:11];
    assign signal_select_618 = out_value[10:10];
    assign signal_select_619 = out_value[9:9];
    assign signal_select_620 = out_value[8:8];
    assign signal_select_621 = out_value[7:7];
    assign signal_select_622 = out_value[6:6];
    assign signal_select_623 = out_value[5:5];
    assign signal_select_624 = out_value[4:4];
    assign signal_select_625 = out_value[3:3];
    assign signal_select_626 = out_value[2:2];
    assign signal_select_627 = out_value[1:1];
    assign signal_select_628 = out_value[0:0];
    assign signal_select_629 = signal_mux_104[3:0];
    always @* begin
        case (signal_select_629)
        0:
            signal_mux_103 <= signal_select_628;
        1:
            signal_mux_103 <= signal_select_627;
        2:
            signal_mux_103 <= signal_select_626;
        3:
            signal_mux_103 <= signal_select_625;
        4:
            signal_mux_103 <= signal_select_624;
        5:
            signal_mux_103 <= signal_select_623;
        6:
            signal_mux_103 <= signal_select_622;
        7:
            signal_mux_103 <= signal_select_621;
        8:
            signal_mux_103 <= signal_select_620;
        9:
            signal_mux_103 <= signal_select_619;
        10:
            signal_mux_103 <= signal_select_618;
        11:
            signal_mux_103 <= signal_select_617;
        12:
            signal_mux_103 <= signal_select_616;
        13:
            signal_mux_103 <= signal_select_615;
        14:
            signal_mux_103 <= signal_select_614;
        default:
            signal_mux_103 <= signal_select_613;
        endcase
    end
    assign signal_select_630 = pin_out_base[8:8];
    assign signal_cat_103 = { gnd,
                              d$shift_count };
    assign signal_cat_104 = { gnd,
                              signal_wire_32 };
    assign signal_sub_68 = signal_const_20 - signal_cat_104;
    assign signal_cat_105 = { gnd,
                              signal_wire_32 };
    assign signal_sub_69 = signal_const_21 - signal_cat_105;
    assign signal_lt_66 = signal_const_22 < signal_wire_32;
    assign signal_mux_104 = signal_lt_66 ? signal_sub_68 : signal_sub_69;
    assign signal_lt_67 = signal_mux_104 < signal_cat_103;
    assign signal_mux_105 = signal_lt_67 ? signal_mux_103 : signal_select_630;
    assign signal_select_631 = out_value[15:15];
    assign signal_select_632 = out_value[14:14];
    assign signal_select_633 = out_value[13:13];
    assign signal_select_634 = out_value[12:12];
    assign signal_select_635 = out_value[11:11];
    assign signal_select_636 = out_value[10:10];
    assign signal_select_637 = out_value[9:9];
    assign signal_select_638 = out_value[8:8];
    assign signal_select_639 = out_value[7:7];
    assign signal_select_640 = out_value[6:6];
    assign signal_select_641 = out_value[5:5];
    assign signal_select_642 = out_value[4:4];
    assign signal_select_643 = out_value[3:3];
    assign signal_select_644 = out_value[2:2];
    assign signal_select_645 = out_value[1:1];
    assign signal_select_646 = out_value[0:0];
    assign signal_select_647 = signal_mux_107[3:0];
    always @* begin
        case (signal_select_647)
        0:
            signal_mux_106 <= signal_select_646;
        1:
            signal_mux_106 <= signal_select_645;
        2:
            signal_mux_106 <= signal_select_644;
        3:
            signal_mux_106 <= signal_select_643;
        4:
            signal_mux_106 <= signal_select_642;
        5:
            signal_mux_106 <= signal_select_641;
        6:
            signal_mux_106 <= signal_select_640;
        7:
            signal_mux_106 <= signal_select_639;
        8:
            signal_mux_106 <= signal_select_638;
        9:
            signal_mux_106 <= signal_select_637;
        10:
            signal_mux_106 <= signal_select_636;
        11:
            signal_mux_106 <= signal_select_635;
        12:
            signal_mux_106 <= signal_select_634;
        13:
            signal_mux_106 <= signal_select_633;
        14:
            signal_mux_106 <= signal_select_632;
        default:
            signal_mux_106 <= signal_select_631;
        endcase
    end
    assign signal_select_648 = pin_out_base[9:9];
    assign signal_cat_106 = { gnd,
                              d$shift_count };
    assign signal_cat_107 = { gnd,
                              signal_wire_32 };
    assign signal_sub_70 = signal_const_23 - signal_cat_107;
    assign signal_cat_108 = { gnd,
                              signal_wire_32 };
    assign signal_sub_71 = signal_const_24 - signal_cat_108;
    assign signal_lt_68 = signal_const_25 < signal_wire_32;
    assign signal_mux_107 = signal_lt_68 ? signal_sub_70 : signal_sub_71;
    assign signal_lt_69 = signal_mux_107 < signal_cat_106;
    assign signal_mux_108 = signal_lt_69 ? signal_mux_106 : signal_select_648;
    assign signal_select_649 = out_value[15:15];
    assign signal_select_650 = out_value[14:14];
    assign signal_select_651 = out_value[13:13];
    assign signal_select_652 = out_value[12:12];
    assign signal_select_653 = out_value[11:11];
    assign signal_select_654 = out_value[10:10];
    assign signal_select_655 = out_value[9:9];
    assign signal_select_656 = out_value[8:8];
    assign signal_select_657 = out_value[7:7];
    assign signal_select_658 = out_value[6:6];
    assign signal_select_659 = out_value[5:5];
    assign signal_select_660 = out_value[4:4];
    assign signal_select_661 = out_value[3:3];
    assign signal_select_662 = out_value[2:2];
    assign signal_select_663 = out_value[1:1];
    assign signal_select_664 = out_value[0:0];
    assign signal_select_665 = signal_mux_110[3:0];
    always @* begin
        case (signal_select_665)
        0:
            signal_mux_109 <= signal_select_664;
        1:
            signal_mux_109 <= signal_select_663;
        2:
            signal_mux_109 <= signal_select_662;
        3:
            signal_mux_109 <= signal_select_661;
        4:
            signal_mux_109 <= signal_select_660;
        5:
            signal_mux_109 <= signal_select_659;
        6:
            signal_mux_109 <= signal_select_658;
        7:
            signal_mux_109 <= signal_select_657;
        8:
            signal_mux_109 <= signal_select_656;
        9:
            signal_mux_109 <= signal_select_655;
        10:
            signal_mux_109 <= signal_select_654;
        11:
            signal_mux_109 <= signal_select_653;
        12:
            signal_mux_109 <= signal_select_652;
        13:
            signal_mux_109 <= signal_select_651;
        14:
            signal_mux_109 <= signal_select_650;
        default:
            signal_mux_109 <= signal_select_649;
        endcase
    end
    assign signal_select_666 = pin_out_base[10:10];
    assign signal_cat_109 = { gnd,
                              d$shift_count };
    assign signal_cat_110 = { gnd,
                              signal_wire_32 };
    assign signal_sub_72 = signal_const_26 - signal_cat_110;
    assign signal_cat_111 = { gnd,
                              signal_wire_32 };
    assign signal_sub_73 = signal_const_27 - signal_cat_111;
    assign signal_lt_70 = signal_const_28 < signal_wire_32;
    assign signal_mux_110 = signal_lt_70 ? signal_sub_72 : signal_sub_73;
    assign signal_lt_71 = signal_mux_110 < signal_cat_109;
    assign signal_mux_111 = signal_lt_71 ? signal_mux_109 : signal_select_666;
    assign signal_select_667 = out_value[15:15];
    assign signal_select_668 = out_value[14:14];
    assign signal_select_669 = out_value[13:13];
    assign signal_select_670 = out_value[12:12];
    assign signal_select_671 = out_value[11:11];
    assign signal_select_672 = out_value[10:10];
    assign signal_select_673 = out_value[9:9];
    assign signal_select_674 = out_value[8:8];
    assign signal_select_675 = out_value[7:7];
    assign signal_select_676 = out_value[6:6];
    assign signal_select_677 = out_value[5:5];
    assign signal_select_678 = out_value[4:4];
    assign signal_select_679 = out_value[3:3];
    assign signal_select_680 = out_value[2:2];
    assign signal_select_681 = out_value[1:1];
    assign signal_select_682 = out_value[0:0];
    assign signal_select_683 = signal_mux_113[3:0];
    always @* begin
        case (signal_select_683)
        0:
            signal_mux_112 <= signal_select_682;
        1:
            signal_mux_112 <= signal_select_681;
        2:
            signal_mux_112 <= signal_select_680;
        3:
            signal_mux_112 <= signal_select_679;
        4:
            signal_mux_112 <= signal_select_678;
        5:
            signal_mux_112 <= signal_select_677;
        6:
            signal_mux_112 <= signal_select_676;
        7:
            signal_mux_112 <= signal_select_675;
        8:
            signal_mux_112 <= signal_select_674;
        9:
            signal_mux_112 <= signal_select_673;
        10:
            signal_mux_112 <= signal_select_672;
        11:
            signal_mux_112 <= signal_select_671;
        12:
            signal_mux_112 <= signal_select_670;
        13:
            signal_mux_112 <= signal_select_669;
        14:
            signal_mux_112 <= signal_select_668;
        default:
            signal_mux_112 <= signal_select_667;
        endcase
    end
    assign signal_select_684 = pin_out_base[11:11];
    assign signal_cat_112 = { gnd,
                              d$shift_count };
    assign signal_cat_113 = { gnd,
                              signal_wire_32 };
    assign signal_sub_74 = signal_const_29 - signal_cat_113;
    assign signal_cat_114 = { gnd,
                              signal_wire_32 };
    assign signal_sub_75 = signal_const_30 - signal_cat_114;
    assign signal_lt_72 = signal_const_31 < signal_wire_32;
    assign signal_mux_113 = signal_lt_72 ? signal_sub_74 : signal_sub_75;
    assign signal_lt_73 = signal_mux_113 < signal_cat_112;
    assign signal_mux_114 = signal_lt_73 ? signal_mux_112 : signal_select_684;
    assign signal_select_685 = out_value[15:15];
    assign signal_select_686 = out_value[14:14];
    assign signal_select_687 = out_value[13:13];
    assign signal_select_688 = out_value[12:12];
    assign signal_select_689 = out_value[11:11];
    assign signal_select_690 = out_value[10:10];
    assign signal_select_691 = out_value[9:9];
    assign signal_select_692 = out_value[8:8];
    assign signal_select_693 = out_value[7:7];
    assign signal_select_694 = out_value[6:6];
    assign signal_select_695 = out_value[5:5];
    assign signal_select_696 = out_value[4:4];
    assign signal_select_697 = out_value[3:3];
    assign signal_select_698 = out_value[2:2];
    assign signal_select_699 = out_value[1:1];
    assign signal_select_700 = out_value[0:0];
    assign signal_select_701 = signal_mux_116[3:0];
    always @* begin
        case (signal_select_701)
        0:
            signal_mux_115 <= signal_select_700;
        1:
            signal_mux_115 <= signal_select_699;
        2:
            signal_mux_115 <= signal_select_698;
        3:
            signal_mux_115 <= signal_select_697;
        4:
            signal_mux_115 <= signal_select_696;
        5:
            signal_mux_115 <= signal_select_695;
        6:
            signal_mux_115 <= signal_select_694;
        7:
            signal_mux_115 <= signal_select_693;
        8:
            signal_mux_115 <= signal_select_692;
        9:
            signal_mux_115 <= signal_select_691;
        10:
            signal_mux_115 <= signal_select_690;
        11:
            signal_mux_115 <= signal_select_689;
        12:
            signal_mux_115 <= signal_select_688;
        13:
            signal_mux_115 <= signal_select_687;
        14:
            signal_mux_115 <= signal_select_686;
        default:
            signal_mux_115 <= signal_select_685;
        endcase
    end
    assign signal_select_702 = pin_out_base[12:12];
    assign signal_cat_115 = { gnd,
                              d$shift_count };
    assign signal_cat_116 = { gnd,
                              signal_wire_32 };
    assign signal_sub_76 = signal_const_32 - signal_cat_116;
    assign signal_cat_117 = { gnd,
                              signal_wire_32 };
    assign signal_sub_77 = signal_const_33 - signal_cat_117;
    assign signal_lt_74 = signal_const_34 < signal_wire_32;
    assign signal_mux_116 = signal_lt_74 ? signal_sub_76 : signal_sub_77;
    assign signal_lt_75 = signal_mux_116 < signal_cat_115;
    assign signal_mux_117 = signal_lt_75 ? signal_mux_115 : signal_select_702;
    assign signal_select_703 = out_value[15:15];
    assign signal_select_704 = out_value[14:14];
    assign signal_select_705 = out_value[13:13];
    assign signal_select_706 = out_value[12:12];
    assign signal_select_707 = out_value[11:11];
    assign signal_select_708 = out_value[10:10];
    assign signal_select_709 = out_value[9:9];
    assign signal_select_710 = out_value[8:8];
    assign signal_select_711 = out_value[7:7];
    assign signal_select_712 = out_value[6:6];
    assign signal_select_713 = out_value[5:5];
    assign signal_select_714 = out_value[4:4];
    assign signal_select_715 = out_value[3:3];
    assign signal_select_716 = out_value[2:2];
    assign signal_select_717 = out_value[1:1];
    assign signal_select_718 = out_value[0:0];
    assign signal_select_719 = signal_mux_119[3:0];
    always @* begin
        case (signal_select_719)
        0:
            signal_mux_118 <= signal_select_718;
        1:
            signal_mux_118 <= signal_select_717;
        2:
            signal_mux_118 <= signal_select_716;
        3:
            signal_mux_118 <= signal_select_715;
        4:
            signal_mux_118 <= signal_select_714;
        5:
            signal_mux_118 <= signal_select_713;
        6:
            signal_mux_118 <= signal_select_712;
        7:
            signal_mux_118 <= signal_select_711;
        8:
            signal_mux_118 <= signal_select_710;
        9:
            signal_mux_118 <= signal_select_709;
        10:
            signal_mux_118 <= signal_select_708;
        11:
            signal_mux_118 <= signal_select_707;
        12:
            signal_mux_118 <= signal_select_706;
        13:
            signal_mux_118 <= signal_select_705;
        14:
            signal_mux_118 <= signal_select_704;
        default:
            signal_mux_118 <= signal_select_703;
        endcase
    end
    assign signal_select_720 = pin_out_base[13:13];
    assign signal_cat_118 = { gnd,
                              d$shift_count };
    assign signal_cat_119 = { gnd,
                              signal_wire_32 };
    assign signal_sub_78 = signal_const_35 - signal_cat_119;
    assign signal_cat_120 = { gnd,
                              signal_wire_32 };
    assign signal_sub_79 = signal_const_36 - signal_cat_120;
    assign signal_lt_76 = signal_const_37 < signal_wire_32;
    assign signal_mux_119 = signal_lt_76 ? signal_sub_78 : signal_sub_79;
    assign signal_lt_77 = signal_mux_119 < signal_cat_118;
    assign signal_mux_120 = signal_lt_77 ? signal_mux_118 : signal_select_720;
    assign signal_select_721 = out_value[15:15];
    assign signal_select_722 = out_value[14:14];
    assign signal_select_723 = out_value[13:13];
    assign signal_select_724 = out_value[12:12];
    assign signal_select_725 = out_value[11:11];
    assign signal_select_726 = out_value[10:10];
    assign signal_select_727 = out_value[9:9];
    assign signal_select_728 = out_value[8:8];
    assign signal_select_729 = out_value[7:7];
    assign signal_select_730 = out_value[6:6];
    assign signal_select_731 = out_value[5:5];
    assign signal_select_732 = out_value[4:4];
    assign signal_select_733 = out_value[3:3];
    assign signal_select_734 = out_value[2:2];
    assign signal_select_735 = out_value[1:1];
    assign signal_select_736 = out_value[0:0];
    assign signal_select_737 = signal_mux_122[3:0];
    always @* begin
        case (signal_select_737)
        0:
            signal_mux_121 <= signal_select_736;
        1:
            signal_mux_121 <= signal_select_735;
        2:
            signal_mux_121 <= signal_select_734;
        3:
            signal_mux_121 <= signal_select_733;
        4:
            signal_mux_121 <= signal_select_732;
        5:
            signal_mux_121 <= signal_select_731;
        6:
            signal_mux_121 <= signal_select_730;
        7:
            signal_mux_121 <= signal_select_729;
        8:
            signal_mux_121 <= signal_select_728;
        9:
            signal_mux_121 <= signal_select_727;
        10:
            signal_mux_121 <= signal_select_726;
        11:
            signal_mux_121 <= signal_select_725;
        12:
            signal_mux_121 <= signal_select_724;
        13:
            signal_mux_121 <= signal_select_723;
        14:
            signal_mux_121 <= signal_select_722;
        default:
            signal_mux_121 <= signal_select_721;
        endcase
    end
    assign signal_select_738 = pin_out_base[14:14];
    assign signal_cat_121 = { gnd,
                              d$shift_count };
    assign signal_cat_122 = { gnd,
                              signal_wire_32 };
    assign signal_sub_80 = signal_const_38 - signal_cat_122;
    assign signal_cat_123 = { gnd,
                              signal_wire_32 };
    assign signal_sub_81 = signal_const_39 - signal_cat_123;
    assign signal_lt_78 = signal_const_40 < signal_wire_32;
    assign signal_mux_122 = signal_lt_78 ? signal_sub_80 : signal_sub_81;
    assign signal_lt_79 = signal_mux_122 < signal_cat_121;
    assign signal_mux_123 = signal_lt_79 ? signal_mux_121 : signal_select_738;
    assign signal_select_739 = out_value[15:15];
    assign signal_select_740 = out_value[14:14];
    assign signal_select_741 = out_value[13:13];
    assign signal_select_742 = out_value[12:12];
    assign signal_select_743 = out_value[11:11];
    assign signal_select_744 = out_value[10:10];
    assign signal_select_745 = out_value[9:9];
    assign signal_select_746 = out_value[8:8];
    assign signal_select_747 = out_value[7:7];
    assign signal_select_748 = out_value[6:6];
    assign signal_select_749 = out_value[5:5];
    assign signal_select_750 = out_value[4:4];
    assign signal_select_751 = out_value[3:3];
    assign signal_select_752 = out_value[2:2];
    assign signal_select_753 = out_value[1:1];
    assign signal_select_754 = out_value[0:0];
    assign signal_select_755 = signal_mux_125[3:0];
    always @* begin
        case (signal_select_755)
        0:
            signal_mux_124 <= signal_select_754;
        1:
            signal_mux_124 <= signal_select_753;
        2:
            signal_mux_124 <= signal_select_752;
        3:
            signal_mux_124 <= signal_select_751;
        4:
            signal_mux_124 <= signal_select_750;
        5:
            signal_mux_124 <= signal_select_749;
        6:
            signal_mux_124 <= signal_select_748;
        7:
            signal_mux_124 <= signal_select_747;
        8:
            signal_mux_124 <= signal_select_746;
        9:
            signal_mux_124 <= signal_select_745;
        10:
            signal_mux_124 <= signal_select_744;
        11:
            signal_mux_124 <= signal_select_743;
        12:
            signal_mux_124 <= signal_select_742;
        13:
            signal_mux_124 <= signal_select_741;
        14:
            signal_mux_124 <= signal_select_740;
        default:
            signal_mux_124 <= signal_select_739;
        endcase
    end
    assign signal_select_756 = pin_out_base[15:15];
    assign signal_cat_124 = { gnd,
                              d$shift_count };
    assign signal_cat_125 = { gnd,
                              signal_wire_32 };
    assign signal_sub_82 = signal_const_41 - signal_cat_125;
    assign signal_cat_126 = { gnd,
                              signal_wire_32 };
    assign signal_sub_83 = signal_const_42 - signal_cat_126;
    assign signal_lt_80 = signal_const_43 < signal_wire_32;
    assign signal_mux_125 = signal_lt_80 ? signal_sub_82 : signal_sub_83;
    assign signal_lt_81 = signal_mux_125 < signal_cat_124;
    assign signal_mux_126 = signal_lt_81 ? signal_mux_124 : signal_select_756;
    assign signal_select_757 = out_value[15:15];
    assign signal_select_758 = out_value[14:14];
    assign signal_select_759 = out_value[13:13];
    assign signal_select_760 = out_value[12:12];
    assign signal_select_761 = out_value[11:11];
    assign signal_select_762 = out_value[10:10];
    assign signal_select_763 = out_value[9:9];
    assign signal_select_764 = out_value[8:8];
    assign signal_select_765 = out_value[7:7];
    assign signal_select_766 = out_value[6:6];
    assign signal_select_767 = out_value[5:5];
    assign signal_select_768 = out_value[4:4];
    assign signal_select_769 = out_value[3:3];
    assign signal_select_770 = out_value[2:2];
    assign signal_select_771 = out_value[1:1];
    assign signal_select_772 = out_value[0:0];
    assign signal_select_773 = signal_mux_128[3:0];
    always @* begin
        case (signal_select_773)
        0:
            signal_mux_127 <= signal_select_772;
        1:
            signal_mux_127 <= signal_select_771;
        2:
            signal_mux_127 <= signal_select_770;
        3:
            signal_mux_127 <= signal_select_769;
        4:
            signal_mux_127 <= signal_select_768;
        5:
            signal_mux_127 <= signal_select_767;
        6:
            signal_mux_127 <= signal_select_766;
        7:
            signal_mux_127 <= signal_select_765;
        8:
            signal_mux_127 <= signal_select_764;
        9:
            signal_mux_127 <= signal_select_763;
        10:
            signal_mux_127 <= signal_select_762;
        11:
            signal_mux_127 <= signal_select_761;
        12:
            signal_mux_127 <= signal_select_760;
        13:
            signal_mux_127 <= signal_select_759;
        14:
            signal_mux_127 <= signal_select_758;
        default:
            signal_mux_127 <= signal_select_757;
        endcase
    end
    assign signal_select_774 = pin_out_base[16:16];
    assign signal_cat_127 = { gnd,
                              d$shift_count };
    assign signal_cat_128 = { gnd,
                              signal_wire_32 };
    assign signal_sub_84 = signal_const_44 - signal_cat_128;
    assign signal_cat_129 = { gnd,
                              signal_wire_32 };
    assign signal_sub_85 = signal_const_45 - signal_cat_129;
    assign signal_lt_82 = signal_const_46 < signal_wire_32;
    assign signal_mux_128 = signal_lt_82 ? signal_sub_84 : signal_sub_85;
    assign signal_lt_83 = signal_mux_128 < signal_cat_127;
    assign signal_mux_129 = signal_lt_83 ? signal_mux_127 : signal_select_774;
    assign signal_select_775 = out_value[15:15];
    assign signal_select_776 = out_value[14:14];
    assign signal_select_777 = out_value[13:13];
    assign signal_select_778 = out_value[12:12];
    assign signal_select_779 = out_value[11:11];
    assign signal_select_780 = out_value[10:10];
    assign signal_select_781 = out_value[9:9];
    assign signal_select_782 = out_value[8:8];
    assign signal_select_783 = out_value[7:7];
    assign signal_select_784 = out_value[6:6];
    assign signal_select_785 = out_value[5:5];
    assign signal_select_786 = out_value[4:4];
    assign signal_select_787 = out_value[3:3];
    assign signal_select_788 = out_value[2:2];
    assign signal_select_789 = out_value[1:1];
    assign signal_select_790 = out_value[0:0];
    assign signal_select_791 = signal_mux_131[3:0];
    always @* begin
        case (signal_select_791)
        0:
            signal_mux_130 <= signal_select_790;
        1:
            signal_mux_130 <= signal_select_789;
        2:
            signal_mux_130 <= signal_select_788;
        3:
            signal_mux_130 <= signal_select_787;
        4:
            signal_mux_130 <= signal_select_786;
        5:
            signal_mux_130 <= signal_select_785;
        6:
            signal_mux_130 <= signal_select_784;
        7:
            signal_mux_130 <= signal_select_783;
        8:
            signal_mux_130 <= signal_select_782;
        9:
            signal_mux_130 <= signal_select_781;
        10:
            signal_mux_130 <= signal_select_780;
        11:
            signal_mux_130 <= signal_select_779;
        12:
            signal_mux_130 <= signal_select_778;
        13:
            signal_mux_130 <= signal_select_777;
        14:
            signal_mux_130 <= signal_select_776;
        default:
            signal_mux_130 <= signal_select_775;
        endcase
    end
    assign signal_select_792 = pin_out_base[17:17];
    assign signal_cat_130 = { gnd,
                              d$shift_count };
    assign signal_cat_131 = { gnd,
                              signal_wire_32 };
    assign signal_sub_86 = signal_const_47 - signal_cat_131;
    assign signal_cat_132 = { gnd,
                              signal_wire_32 };
    assign signal_sub_87 = signal_const_48 - signal_cat_132;
    assign signal_lt_84 = signal_const_49 < signal_wire_32;
    assign signal_mux_131 = signal_lt_84 ? signal_sub_86 : signal_sub_87;
    assign signal_lt_85 = signal_mux_131 < signal_cat_130;
    assign signal_mux_132 = signal_lt_85 ? signal_mux_130 : signal_select_792;
    assign signal_select_793 = out_value[15:15];
    assign signal_select_794 = out_value[14:14];
    assign signal_select_795 = out_value[13:13];
    assign signal_select_796 = out_value[12:12];
    assign signal_select_797 = out_value[11:11];
    assign signal_select_798 = out_value[10:10];
    assign signal_select_799 = out_value[9:9];
    assign signal_select_800 = out_value[8:8];
    assign signal_select_801 = out_value[7:7];
    assign signal_select_802 = out_value[6:6];
    assign signal_select_803 = out_value[5:5];
    assign signal_select_804 = out_value[4:4];
    assign signal_select_805 = out_value[3:3];
    assign signal_select_806 = out_value[2:2];
    assign signal_select_807 = out_value[1:1];
    assign signal_select_808 = out_value[0:0];
    assign signal_select_809 = signal_mux_134[3:0];
    always @* begin
        case (signal_select_809)
        0:
            signal_mux_133 <= signal_select_808;
        1:
            signal_mux_133 <= signal_select_807;
        2:
            signal_mux_133 <= signal_select_806;
        3:
            signal_mux_133 <= signal_select_805;
        4:
            signal_mux_133 <= signal_select_804;
        5:
            signal_mux_133 <= signal_select_803;
        6:
            signal_mux_133 <= signal_select_802;
        7:
            signal_mux_133 <= signal_select_801;
        8:
            signal_mux_133 <= signal_select_800;
        9:
            signal_mux_133 <= signal_select_799;
        10:
            signal_mux_133 <= signal_select_798;
        11:
            signal_mux_133 <= signal_select_797;
        12:
            signal_mux_133 <= signal_select_796;
        13:
            signal_mux_133 <= signal_select_795;
        14:
            signal_mux_133 <= signal_select_794;
        default:
            signal_mux_133 <= signal_select_793;
        endcase
    end
    assign signal_select_810 = pin_out_base[18:18];
    assign signal_cat_133 = { gnd,
                              d$shift_count };
    assign signal_cat_134 = { gnd,
                              signal_wire_32 };
    assign signal_sub_88 = signal_const_50 - signal_cat_134;
    assign signal_cat_135 = { gnd,
                              signal_wire_32 };
    assign signal_sub_89 = signal_const_51 - signal_cat_135;
    assign signal_lt_86 = signal_const_52 < signal_wire_32;
    assign signal_mux_134 = signal_lt_86 ? signal_sub_88 : signal_sub_89;
    assign signal_lt_87 = signal_mux_134 < signal_cat_133;
    assign signal_mux_135 = signal_lt_87 ? signal_mux_133 : signal_select_810;
    assign signal_select_811 = out_value[15:15];
    assign signal_select_812 = out_value[14:14];
    assign signal_select_813 = out_value[13:13];
    assign signal_select_814 = out_value[12:12];
    assign signal_select_815 = out_value[11:11];
    assign signal_select_816 = out_value[10:10];
    assign signal_select_817 = out_value[9:9];
    assign signal_select_818 = out_value[8:8];
    assign signal_select_819 = out_value[7:7];
    assign signal_select_820 = out_value[6:6];
    assign signal_select_821 = out_value[5:5];
    assign signal_select_822 = out_value[4:4];
    assign signal_select_823 = out_value[3:3];
    assign signal_select_824 = out_value[2:2];
    assign signal_select_825 = out_value[1:1];
    assign signal_select_826 = out_value[0:0];
    assign signal_select_827 = signal_mux_137[3:0];
    always @* begin
        case (signal_select_827)
        0:
            signal_mux_136 <= signal_select_826;
        1:
            signal_mux_136 <= signal_select_825;
        2:
            signal_mux_136 <= signal_select_824;
        3:
            signal_mux_136 <= signal_select_823;
        4:
            signal_mux_136 <= signal_select_822;
        5:
            signal_mux_136 <= signal_select_821;
        6:
            signal_mux_136 <= signal_select_820;
        7:
            signal_mux_136 <= signal_select_819;
        8:
            signal_mux_136 <= signal_select_818;
        9:
            signal_mux_136 <= signal_select_817;
        10:
            signal_mux_136 <= signal_select_816;
        11:
            signal_mux_136 <= signal_select_815;
        12:
            signal_mux_136 <= signal_select_814;
        13:
            signal_mux_136 <= signal_select_813;
        14:
            signal_mux_136 <= signal_select_812;
        default:
            signal_mux_136 <= signal_select_811;
        endcase
    end
    assign signal_select_828 = pin_out_base[19:19];
    assign signal_cat_136 = { gnd,
                              d$shift_count };
    assign signal_cat_137 = { gnd,
                              signal_wire_32 };
    assign signal_sub_90 = signal_const_54 - signal_cat_137;
    assign signal_cat_138 = { gnd,
                              signal_wire_32 };
    assign signal_sub_91 = signal_const_55 - signal_cat_138;
    assign signal_lt_88 = signal_const_56 < signal_wire_32;
    assign signal_mux_137 = signal_lt_88 ? signal_sub_90 : signal_sub_91;
    assign signal_lt_89 = signal_mux_137 < signal_cat_136;
    assign signal_mux_138 = signal_lt_89 ? signal_mux_136 : signal_select_828;
    assign signal_cat_139 = { signal_mux_138,
                              signal_mux_135,
                              signal_mux_132,
                              signal_mux_129,
                              signal_mux_126,
                              signal_mux_123,
                              signal_mux_120,
                              signal_mux_117,
                              signal_mux_114,
                              signal_mux_111,
                              signal_mux_108,
                              signal_mux_105,
                              signal_mux_102,
                              signal_mux_99,
                              signal_mux_96,
                              signal_select_558,
                              signal_select_557,
                              signal_select_556,
                              signal_select_555,
                              signal_select_554 };
    assign signal_eq_7 = d$out_dest$binary_variant == signal_const_57;
    assign signal_mux_139 = signal_eq_7 ? signal_cat_139 : pin_out_base;
    assign signal_select_829 = pin_out_0[0:0];
    assign signal_select_830 = pin_out_0[1:1];
    assign signal_select_831 = pin_out_0[2:2];
    assign signal_select_832 = pin_out_0[3:3];
    assign signal_select_833 = pin_out_0[4:4];
    assign signal_select_834 = signal_cat_182[15:15];
    assign signal_select_835 = signal_cat_182[14:14];
    assign signal_select_836 = signal_cat_182[13:13];
    assign signal_select_837 = signal_cat_182[12:12];
    assign signal_select_838 = signal_cat_182[11:11];
    assign signal_select_839 = signal_cat_182[10:10];
    assign signal_select_840 = signal_cat_182[9:9];
    assign signal_select_841 = signal_cat_182[8:8];
    assign signal_select_842 = signal_cat_182[7:7];
    assign signal_select_843 = signal_cat_182[6:6];
    assign signal_select_844 = signal_cat_182[5:5];
    assign signal_select_845 = signal_cat_182[4:4];
    assign signal_select_846 = signal_cat_182[3:3];
    assign signal_select_847 = signal_cat_182[2:2];
    assign signal_select_848 = signal_cat_182[1:1];
    assign signal_select_849 = signal_cat_182[0:0];
    assign signal_select_850 = signal_mux_141[3:0];
    always @* begin
        case (signal_select_850)
        0:
            signal_mux_140 <= signal_select_849;
        1:
            signal_mux_140 <= signal_select_848;
        2:
            signal_mux_140 <= signal_select_847;
        3:
            signal_mux_140 <= signal_select_846;
        4:
            signal_mux_140 <= signal_select_845;
        5:
            signal_mux_140 <= signal_select_844;
        6:
            signal_mux_140 <= signal_select_843;
        7:
            signal_mux_140 <= signal_select_842;
        8:
            signal_mux_140 <= signal_select_841;
        9:
            signal_mux_140 <= signal_select_840;
        10:
            signal_mux_140 <= signal_select_839;
        11:
            signal_mux_140 <= signal_select_838;
        12:
            signal_mux_140 <= signal_select_837;
        13:
            signal_mux_140 <= signal_select_836;
        14:
            signal_mux_140 <= signal_select_835;
        default:
            signal_mux_140 <= signal_select_834;
        endcase
    end
    assign signal_select_851 = pin_out_0[5:5];
    assign signal_cat_140 = { gnd,
                              signal_cat_370 };
    assign signal_cat_141 = { gnd,
                              signal_wire_34 };
    assign signal_sub_92 = signal_const_11 - signal_cat_141;
    assign signal_cat_142 = { gnd,
                              signal_wire_34 };
    assign signal_sub_93 = signal_const_12 - signal_cat_142;
    assign signal_lt_90 = signal_const_13 < signal_wire_34;
    assign signal_mux_141 = signal_lt_90 ? signal_sub_92 : signal_sub_93;
    assign signal_lt_91 = signal_mux_141 < signal_cat_140;
    assign signal_mux_142 = signal_lt_91 ? signal_mux_140 : signal_select_851;
    assign signal_select_852 = signal_cat_182[15:15];
    assign signal_select_853 = signal_cat_182[14:14];
    assign signal_select_854 = signal_cat_182[13:13];
    assign signal_select_855 = signal_cat_182[12:12];
    assign signal_select_856 = signal_cat_182[11:11];
    assign signal_select_857 = signal_cat_182[10:10];
    assign signal_select_858 = signal_cat_182[9:9];
    assign signal_select_859 = signal_cat_182[8:8];
    assign signal_select_860 = signal_cat_182[7:7];
    assign signal_select_861 = signal_cat_182[6:6];
    assign signal_select_862 = signal_cat_182[5:5];
    assign signal_select_863 = signal_cat_182[4:4];
    assign signal_select_864 = signal_cat_182[3:3];
    assign signal_select_865 = signal_cat_182[2:2];
    assign signal_select_866 = signal_cat_182[1:1];
    assign signal_select_867 = signal_cat_182[0:0];
    assign signal_select_868 = signal_mux_144[3:0];
    always @* begin
        case (signal_select_868)
        0:
            signal_mux_143 <= signal_select_867;
        1:
            signal_mux_143 <= signal_select_866;
        2:
            signal_mux_143 <= signal_select_865;
        3:
            signal_mux_143 <= signal_select_864;
        4:
            signal_mux_143 <= signal_select_863;
        5:
            signal_mux_143 <= signal_select_862;
        6:
            signal_mux_143 <= signal_select_861;
        7:
            signal_mux_143 <= signal_select_860;
        8:
            signal_mux_143 <= signal_select_859;
        9:
            signal_mux_143 <= signal_select_858;
        10:
            signal_mux_143 <= signal_select_857;
        11:
            signal_mux_143 <= signal_select_856;
        12:
            signal_mux_143 <= signal_select_855;
        13:
            signal_mux_143 <= signal_select_854;
        14:
            signal_mux_143 <= signal_select_853;
        default:
            signal_mux_143 <= signal_select_852;
        endcase
    end
    assign signal_select_869 = pin_out_0[6:6];
    assign signal_cat_143 = { gnd,
                              signal_cat_370 };
    assign signal_cat_144 = { gnd,
                              signal_wire_34 };
    assign signal_sub_94 = signal_const_14 - signal_cat_144;
    assign signal_cat_145 = { gnd,
                              signal_wire_34 };
    assign signal_sub_95 = signal_const_15 - signal_cat_145;
    assign signal_lt_92 = signal_const_16 < signal_wire_34;
    assign signal_mux_144 = signal_lt_92 ? signal_sub_94 : signal_sub_95;
    assign signal_lt_93 = signal_mux_144 < signal_cat_143;
    assign signal_mux_145 = signal_lt_93 ? signal_mux_143 : signal_select_869;
    assign signal_select_870 = signal_cat_182[15:15];
    assign signal_select_871 = signal_cat_182[14:14];
    assign signal_select_872 = signal_cat_182[13:13];
    assign signal_select_873 = signal_cat_182[12:12];
    assign signal_select_874 = signal_cat_182[11:11];
    assign signal_select_875 = signal_cat_182[10:10];
    assign signal_select_876 = signal_cat_182[9:9];
    assign signal_select_877 = signal_cat_182[8:8];
    assign signal_select_878 = signal_cat_182[7:7];
    assign signal_select_879 = signal_cat_182[6:6];
    assign signal_select_880 = signal_cat_182[5:5];
    assign signal_select_881 = signal_cat_182[4:4];
    assign signal_select_882 = signal_cat_182[3:3];
    assign signal_select_883 = signal_cat_182[2:2];
    assign signal_select_884 = signal_cat_182[1:1];
    assign signal_select_885 = signal_cat_182[0:0];
    assign signal_select_886 = signal_mux_147[3:0];
    always @* begin
        case (signal_select_886)
        0:
            signal_mux_146 <= signal_select_885;
        1:
            signal_mux_146 <= signal_select_884;
        2:
            signal_mux_146 <= signal_select_883;
        3:
            signal_mux_146 <= signal_select_882;
        4:
            signal_mux_146 <= signal_select_881;
        5:
            signal_mux_146 <= signal_select_880;
        6:
            signal_mux_146 <= signal_select_879;
        7:
            signal_mux_146 <= signal_select_878;
        8:
            signal_mux_146 <= signal_select_877;
        9:
            signal_mux_146 <= signal_select_876;
        10:
            signal_mux_146 <= signal_select_875;
        11:
            signal_mux_146 <= signal_select_874;
        12:
            signal_mux_146 <= signal_select_873;
        13:
            signal_mux_146 <= signal_select_872;
        14:
            signal_mux_146 <= signal_select_871;
        default:
            signal_mux_146 <= signal_select_870;
        endcase
    end
    assign signal_select_887 = pin_out_0[7:7];
    assign signal_cat_146 = { gnd,
                              signal_cat_370 };
    assign signal_cat_147 = { gnd,
                              signal_wire_34 };
    assign signal_sub_96 = signal_const_17 - signal_cat_147;
    assign signal_cat_148 = { gnd,
                              signal_wire_34 };
    assign signal_sub_97 = signal_const_18 - signal_cat_148;
    assign signal_lt_94 = signal_const_19 < signal_wire_34;
    assign signal_mux_147 = signal_lt_94 ? signal_sub_96 : signal_sub_97;
    assign signal_lt_95 = signal_mux_147 < signal_cat_146;
    assign signal_mux_148 = signal_lt_95 ? signal_mux_146 : signal_select_887;
    assign signal_select_888 = signal_cat_182[15:15];
    assign signal_select_889 = signal_cat_182[14:14];
    assign signal_select_890 = signal_cat_182[13:13];
    assign signal_select_891 = signal_cat_182[12:12];
    assign signal_select_892 = signal_cat_182[11:11];
    assign signal_select_893 = signal_cat_182[10:10];
    assign signal_select_894 = signal_cat_182[9:9];
    assign signal_select_895 = signal_cat_182[8:8];
    assign signal_select_896 = signal_cat_182[7:7];
    assign signal_select_897 = signal_cat_182[6:6];
    assign signal_select_898 = signal_cat_182[5:5];
    assign signal_select_899 = signal_cat_182[4:4];
    assign signal_select_900 = signal_cat_182[3:3];
    assign signal_select_901 = signal_cat_182[2:2];
    assign signal_select_902 = signal_cat_182[1:1];
    assign signal_select_903 = signal_cat_182[0:0];
    assign signal_select_904 = signal_mux_150[3:0];
    always @* begin
        case (signal_select_904)
        0:
            signal_mux_149 <= signal_select_903;
        1:
            signal_mux_149 <= signal_select_902;
        2:
            signal_mux_149 <= signal_select_901;
        3:
            signal_mux_149 <= signal_select_900;
        4:
            signal_mux_149 <= signal_select_899;
        5:
            signal_mux_149 <= signal_select_898;
        6:
            signal_mux_149 <= signal_select_897;
        7:
            signal_mux_149 <= signal_select_896;
        8:
            signal_mux_149 <= signal_select_895;
        9:
            signal_mux_149 <= signal_select_894;
        10:
            signal_mux_149 <= signal_select_893;
        11:
            signal_mux_149 <= signal_select_892;
        12:
            signal_mux_149 <= signal_select_891;
        13:
            signal_mux_149 <= signal_select_890;
        14:
            signal_mux_149 <= signal_select_889;
        default:
            signal_mux_149 <= signal_select_888;
        endcase
    end
    assign signal_select_905 = pin_out_0[8:8];
    assign signal_cat_149 = { gnd,
                              signal_cat_370 };
    assign signal_cat_150 = { gnd,
                              signal_wire_34 };
    assign signal_sub_98 = signal_const_20 - signal_cat_150;
    assign signal_cat_151 = { gnd,
                              signal_wire_34 };
    assign signal_sub_99 = signal_const_21 - signal_cat_151;
    assign signal_lt_96 = signal_const_22 < signal_wire_34;
    assign signal_mux_150 = signal_lt_96 ? signal_sub_98 : signal_sub_99;
    assign signal_lt_97 = signal_mux_150 < signal_cat_149;
    assign signal_mux_151 = signal_lt_97 ? signal_mux_149 : signal_select_905;
    assign signal_select_906 = signal_cat_182[15:15];
    assign signal_select_907 = signal_cat_182[14:14];
    assign signal_select_908 = signal_cat_182[13:13];
    assign signal_select_909 = signal_cat_182[12:12];
    assign signal_select_910 = signal_cat_182[11:11];
    assign signal_select_911 = signal_cat_182[10:10];
    assign signal_select_912 = signal_cat_182[9:9];
    assign signal_select_913 = signal_cat_182[8:8];
    assign signal_select_914 = signal_cat_182[7:7];
    assign signal_select_915 = signal_cat_182[6:6];
    assign signal_select_916 = signal_cat_182[5:5];
    assign signal_select_917 = signal_cat_182[4:4];
    assign signal_select_918 = signal_cat_182[3:3];
    assign signal_select_919 = signal_cat_182[2:2];
    assign signal_select_920 = signal_cat_182[1:1];
    assign signal_select_921 = signal_cat_182[0:0];
    assign signal_select_922 = signal_mux_153[3:0];
    always @* begin
        case (signal_select_922)
        0:
            signal_mux_152 <= signal_select_921;
        1:
            signal_mux_152 <= signal_select_920;
        2:
            signal_mux_152 <= signal_select_919;
        3:
            signal_mux_152 <= signal_select_918;
        4:
            signal_mux_152 <= signal_select_917;
        5:
            signal_mux_152 <= signal_select_916;
        6:
            signal_mux_152 <= signal_select_915;
        7:
            signal_mux_152 <= signal_select_914;
        8:
            signal_mux_152 <= signal_select_913;
        9:
            signal_mux_152 <= signal_select_912;
        10:
            signal_mux_152 <= signal_select_911;
        11:
            signal_mux_152 <= signal_select_910;
        12:
            signal_mux_152 <= signal_select_909;
        13:
            signal_mux_152 <= signal_select_908;
        14:
            signal_mux_152 <= signal_select_907;
        default:
            signal_mux_152 <= signal_select_906;
        endcase
    end
    assign signal_select_923 = pin_out_0[9:9];
    assign signal_cat_152 = { gnd,
                              signal_cat_370 };
    assign signal_cat_153 = { gnd,
                              signal_wire_34 };
    assign signal_sub_100 = signal_const_23 - signal_cat_153;
    assign signal_cat_154 = { gnd,
                              signal_wire_34 };
    assign signal_sub_101 = signal_const_24 - signal_cat_154;
    assign signal_lt_98 = signal_const_25 < signal_wire_34;
    assign signal_mux_153 = signal_lt_98 ? signal_sub_100 : signal_sub_101;
    assign signal_lt_99 = signal_mux_153 < signal_cat_152;
    assign signal_mux_154 = signal_lt_99 ? signal_mux_152 : signal_select_923;
    assign signal_select_924 = signal_cat_182[15:15];
    assign signal_select_925 = signal_cat_182[14:14];
    assign signal_select_926 = signal_cat_182[13:13];
    assign signal_select_927 = signal_cat_182[12:12];
    assign signal_select_928 = signal_cat_182[11:11];
    assign signal_select_929 = signal_cat_182[10:10];
    assign signal_select_930 = signal_cat_182[9:9];
    assign signal_select_931 = signal_cat_182[8:8];
    assign signal_select_932 = signal_cat_182[7:7];
    assign signal_select_933 = signal_cat_182[6:6];
    assign signal_select_934 = signal_cat_182[5:5];
    assign signal_select_935 = signal_cat_182[4:4];
    assign signal_select_936 = signal_cat_182[3:3];
    assign signal_select_937 = signal_cat_182[2:2];
    assign signal_select_938 = signal_cat_182[1:1];
    assign signal_select_939 = signal_cat_182[0:0];
    assign signal_select_940 = signal_mux_156[3:0];
    always @* begin
        case (signal_select_940)
        0:
            signal_mux_155 <= signal_select_939;
        1:
            signal_mux_155 <= signal_select_938;
        2:
            signal_mux_155 <= signal_select_937;
        3:
            signal_mux_155 <= signal_select_936;
        4:
            signal_mux_155 <= signal_select_935;
        5:
            signal_mux_155 <= signal_select_934;
        6:
            signal_mux_155 <= signal_select_933;
        7:
            signal_mux_155 <= signal_select_932;
        8:
            signal_mux_155 <= signal_select_931;
        9:
            signal_mux_155 <= signal_select_930;
        10:
            signal_mux_155 <= signal_select_929;
        11:
            signal_mux_155 <= signal_select_928;
        12:
            signal_mux_155 <= signal_select_927;
        13:
            signal_mux_155 <= signal_select_926;
        14:
            signal_mux_155 <= signal_select_925;
        default:
            signal_mux_155 <= signal_select_924;
        endcase
    end
    assign signal_select_941 = pin_out_0[10:10];
    assign signal_cat_155 = { gnd,
                              signal_cat_370 };
    assign signal_cat_156 = { gnd,
                              signal_wire_34 };
    assign signal_sub_102 = signal_const_26 - signal_cat_156;
    assign signal_cat_157 = { gnd,
                              signal_wire_34 };
    assign signal_sub_103 = signal_const_27 - signal_cat_157;
    assign signal_lt_100 = signal_const_28 < signal_wire_34;
    assign signal_mux_156 = signal_lt_100 ? signal_sub_102 : signal_sub_103;
    assign signal_lt_101 = signal_mux_156 < signal_cat_155;
    assign signal_mux_157 = signal_lt_101 ? signal_mux_155 : signal_select_941;
    assign signal_select_942 = signal_cat_182[15:15];
    assign signal_select_943 = signal_cat_182[14:14];
    assign signal_select_944 = signal_cat_182[13:13];
    assign signal_select_945 = signal_cat_182[12:12];
    assign signal_select_946 = signal_cat_182[11:11];
    assign signal_select_947 = signal_cat_182[10:10];
    assign signal_select_948 = signal_cat_182[9:9];
    assign signal_select_949 = signal_cat_182[8:8];
    assign signal_select_950 = signal_cat_182[7:7];
    assign signal_select_951 = signal_cat_182[6:6];
    assign signal_select_952 = signal_cat_182[5:5];
    assign signal_select_953 = signal_cat_182[4:4];
    assign signal_select_954 = signal_cat_182[3:3];
    assign signal_select_955 = signal_cat_182[2:2];
    assign signal_select_956 = signal_cat_182[1:1];
    assign signal_select_957 = signal_cat_182[0:0];
    assign signal_select_958 = signal_mux_159[3:0];
    always @* begin
        case (signal_select_958)
        0:
            signal_mux_158 <= signal_select_957;
        1:
            signal_mux_158 <= signal_select_956;
        2:
            signal_mux_158 <= signal_select_955;
        3:
            signal_mux_158 <= signal_select_954;
        4:
            signal_mux_158 <= signal_select_953;
        5:
            signal_mux_158 <= signal_select_952;
        6:
            signal_mux_158 <= signal_select_951;
        7:
            signal_mux_158 <= signal_select_950;
        8:
            signal_mux_158 <= signal_select_949;
        9:
            signal_mux_158 <= signal_select_948;
        10:
            signal_mux_158 <= signal_select_947;
        11:
            signal_mux_158 <= signal_select_946;
        12:
            signal_mux_158 <= signal_select_945;
        13:
            signal_mux_158 <= signal_select_944;
        14:
            signal_mux_158 <= signal_select_943;
        default:
            signal_mux_158 <= signal_select_942;
        endcase
    end
    assign signal_select_959 = pin_out_0[11:11];
    assign signal_cat_158 = { gnd,
                              signal_cat_370 };
    assign signal_cat_159 = { gnd,
                              signal_wire_34 };
    assign signal_sub_104 = signal_const_29 - signal_cat_159;
    assign signal_cat_160 = { gnd,
                              signal_wire_34 };
    assign signal_sub_105 = signal_const_30 - signal_cat_160;
    assign signal_lt_102 = signal_const_31 < signal_wire_34;
    assign signal_mux_159 = signal_lt_102 ? signal_sub_104 : signal_sub_105;
    assign signal_lt_103 = signal_mux_159 < signal_cat_158;
    assign signal_mux_160 = signal_lt_103 ? signal_mux_158 : signal_select_959;
    assign signal_select_960 = signal_cat_182[15:15];
    assign signal_select_961 = signal_cat_182[14:14];
    assign signal_select_962 = signal_cat_182[13:13];
    assign signal_select_963 = signal_cat_182[12:12];
    assign signal_select_964 = signal_cat_182[11:11];
    assign signal_select_965 = signal_cat_182[10:10];
    assign signal_select_966 = signal_cat_182[9:9];
    assign signal_select_967 = signal_cat_182[8:8];
    assign signal_select_968 = signal_cat_182[7:7];
    assign signal_select_969 = signal_cat_182[6:6];
    assign signal_select_970 = signal_cat_182[5:5];
    assign signal_select_971 = signal_cat_182[4:4];
    assign signal_select_972 = signal_cat_182[3:3];
    assign signal_select_973 = signal_cat_182[2:2];
    assign signal_select_974 = signal_cat_182[1:1];
    assign signal_select_975 = signal_cat_182[0:0];
    assign signal_select_976 = signal_mux_162[3:0];
    always @* begin
        case (signal_select_976)
        0:
            signal_mux_161 <= signal_select_975;
        1:
            signal_mux_161 <= signal_select_974;
        2:
            signal_mux_161 <= signal_select_973;
        3:
            signal_mux_161 <= signal_select_972;
        4:
            signal_mux_161 <= signal_select_971;
        5:
            signal_mux_161 <= signal_select_970;
        6:
            signal_mux_161 <= signal_select_969;
        7:
            signal_mux_161 <= signal_select_968;
        8:
            signal_mux_161 <= signal_select_967;
        9:
            signal_mux_161 <= signal_select_966;
        10:
            signal_mux_161 <= signal_select_965;
        11:
            signal_mux_161 <= signal_select_964;
        12:
            signal_mux_161 <= signal_select_963;
        13:
            signal_mux_161 <= signal_select_962;
        14:
            signal_mux_161 <= signal_select_961;
        default:
            signal_mux_161 <= signal_select_960;
        endcase
    end
    assign signal_select_977 = pin_out_0[12:12];
    assign signal_cat_161 = { gnd,
                              signal_cat_370 };
    assign signal_cat_162 = { gnd,
                              signal_wire_34 };
    assign signal_sub_106 = signal_const_32 - signal_cat_162;
    assign signal_cat_163 = { gnd,
                              signal_wire_34 };
    assign signal_sub_107 = signal_const_33 - signal_cat_163;
    assign signal_lt_104 = signal_const_34 < signal_wire_34;
    assign signal_mux_162 = signal_lt_104 ? signal_sub_106 : signal_sub_107;
    assign signal_lt_105 = signal_mux_162 < signal_cat_161;
    assign signal_mux_163 = signal_lt_105 ? signal_mux_161 : signal_select_977;
    assign signal_select_978 = signal_cat_182[15:15];
    assign signal_select_979 = signal_cat_182[14:14];
    assign signal_select_980 = signal_cat_182[13:13];
    assign signal_select_981 = signal_cat_182[12:12];
    assign signal_select_982 = signal_cat_182[11:11];
    assign signal_select_983 = signal_cat_182[10:10];
    assign signal_select_984 = signal_cat_182[9:9];
    assign signal_select_985 = signal_cat_182[8:8];
    assign signal_select_986 = signal_cat_182[7:7];
    assign signal_select_987 = signal_cat_182[6:6];
    assign signal_select_988 = signal_cat_182[5:5];
    assign signal_select_989 = signal_cat_182[4:4];
    assign signal_select_990 = signal_cat_182[3:3];
    assign signal_select_991 = signal_cat_182[2:2];
    assign signal_select_992 = signal_cat_182[1:1];
    assign signal_select_993 = signal_cat_182[0:0];
    assign signal_select_994 = signal_mux_165[3:0];
    always @* begin
        case (signal_select_994)
        0:
            signal_mux_164 <= signal_select_993;
        1:
            signal_mux_164 <= signal_select_992;
        2:
            signal_mux_164 <= signal_select_991;
        3:
            signal_mux_164 <= signal_select_990;
        4:
            signal_mux_164 <= signal_select_989;
        5:
            signal_mux_164 <= signal_select_988;
        6:
            signal_mux_164 <= signal_select_987;
        7:
            signal_mux_164 <= signal_select_986;
        8:
            signal_mux_164 <= signal_select_985;
        9:
            signal_mux_164 <= signal_select_984;
        10:
            signal_mux_164 <= signal_select_983;
        11:
            signal_mux_164 <= signal_select_982;
        12:
            signal_mux_164 <= signal_select_981;
        13:
            signal_mux_164 <= signal_select_980;
        14:
            signal_mux_164 <= signal_select_979;
        default:
            signal_mux_164 <= signal_select_978;
        endcase
    end
    assign signal_select_995 = pin_out_0[13:13];
    assign signal_cat_164 = { gnd,
                              signal_cat_370 };
    assign signal_cat_165 = { gnd,
                              signal_wire_34 };
    assign signal_sub_108 = signal_const_35 - signal_cat_165;
    assign signal_cat_166 = { gnd,
                              signal_wire_34 };
    assign signal_sub_109 = signal_const_36 - signal_cat_166;
    assign signal_lt_106 = signal_const_37 < signal_wire_34;
    assign signal_mux_165 = signal_lt_106 ? signal_sub_108 : signal_sub_109;
    assign signal_lt_107 = signal_mux_165 < signal_cat_164;
    assign signal_mux_166 = signal_lt_107 ? signal_mux_164 : signal_select_995;
    assign signal_select_996 = signal_cat_182[15:15];
    assign signal_select_997 = signal_cat_182[14:14];
    assign signal_select_998 = signal_cat_182[13:13];
    assign signal_select_999 = signal_cat_182[12:12];
    assign signal_select_1000 = signal_cat_182[11:11];
    assign signal_select_1001 = signal_cat_182[10:10];
    assign signal_select_1002 = signal_cat_182[9:9];
    assign signal_select_1003 = signal_cat_182[8:8];
    assign signal_select_1004 = signal_cat_182[7:7];
    assign signal_select_1005 = signal_cat_182[6:6];
    assign signal_select_1006 = signal_cat_182[5:5];
    assign signal_select_1007 = signal_cat_182[4:4];
    assign signal_select_1008 = signal_cat_182[3:3];
    assign signal_select_1009 = signal_cat_182[2:2];
    assign signal_select_1010 = signal_cat_182[1:1];
    assign signal_select_1011 = signal_cat_182[0:0];
    assign signal_select_1012 = signal_mux_168[3:0];
    always @* begin
        case (signal_select_1012)
        0:
            signal_mux_167 <= signal_select_1011;
        1:
            signal_mux_167 <= signal_select_1010;
        2:
            signal_mux_167 <= signal_select_1009;
        3:
            signal_mux_167 <= signal_select_1008;
        4:
            signal_mux_167 <= signal_select_1007;
        5:
            signal_mux_167 <= signal_select_1006;
        6:
            signal_mux_167 <= signal_select_1005;
        7:
            signal_mux_167 <= signal_select_1004;
        8:
            signal_mux_167 <= signal_select_1003;
        9:
            signal_mux_167 <= signal_select_1002;
        10:
            signal_mux_167 <= signal_select_1001;
        11:
            signal_mux_167 <= signal_select_1000;
        12:
            signal_mux_167 <= signal_select_999;
        13:
            signal_mux_167 <= signal_select_998;
        14:
            signal_mux_167 <= signal_select_997;
        default:
            signal_mux_167 <= signal_select_996;
        endcase
    end
    assign signal_select_1013 = pin_out_0[14:14];
    assign signal_cat_167 = { gnd,
                              signal_cat_370 };
    assign signal_cat_168 = { gnd,
                              signal_wire_34 };
    assign signal_sub_110 = signal_const_38 - signal_cat_168;
    assign signal_cat_169 = { gnd,
                              signal_wire_34 };
    assign signal_sub_111 = signal_const_39 - signal_cat_169;
    assign signal_lt_108 = signal_const_40 < signal_wire_34;
    assign signal_mux_168 = signal_lt_108 ? signal_sub_110 : signal_sub_111;
    assign signal_lt_109 = signal_mux_168 < signal_cat_167;
    assign signal_mux_169 = signal_lt_109 ? signal_mux_167 : signal_select_1013;
    assign signal_select_1014 = signal_cat_182[15:15];
    assign signal_select_1015 = signal_cat_182[14:14];
    assign signal_select_1016 = signal_cat_182[13:13];
    assign signal_select_1017 = signal_cat_182[12:12];
    assign signal_select_1018 = signal_cat_182[11:11];
    assign signal_select_1019 = signal_cat_182[10:10];
    assign signal_select_1020 = signal_cat_182[9:9];
    assign signal_select_1021 = signal_cat_182[8:8];
    assign signal_select_1022 = signal_cat_182[7:7];
    assign signal_select_1023 = signal_cat_182[6:6];
    assign signal_select_1024 = signal_cat_182[5:5];
    assign signal_select_1025 = signal_cat_182[4:4];
    assign signal_select_1026 = signal_cat_182[3:3];
    assign signal_select_1027 = signal_cat_182[2:2];
    assign signal_select_1028 = signal_cat_182[1:1];
    assign signal_select_1029 = signal_cat_182[0:0];
    assign signal_select_1030 = signal_mux_171[3:0];
    always @* begin
        case (signal_select_1030)
        0:
            signal_mux_170 <= signal_select_1029;
        1:
            signal_mux_170 <= signal_select_1028;
        2:
            signal_mux_170 <= signal_select_1027;
        3:
            signal_mux_170 <= signal_select_1026;
        4:
            signal_mux_170 <= signal_select_1025;
        5:
            signal_mux_170 <= signal_select_1024;
        6:
            signal_mux_170 <= signal_select_1023;
        7:
            signal_mux_170 <= signal_select_1022;
        8:
            signal_mux_170 <= signal_select_1021;
        9:
            signal_mux_170 <= signal_select_1020;
        10:
            signal_mux_170 <= signal_select_1019;
        11:
            signal_mux_170 <= signal_select_1018;
        12:
            signal_mux_170 <= signal_select_1017;
        13:
            signal_mux_170 <= signal_select_1016;
        14:
            signal_mux_170 <= signal_select_1015;
        default:
            signal_mux_170 <= signal_select_1014;
        endcase
    end
    assign signal_select_1031 = pin_out_0[15:15];
    assign signal_cat_170 = { gnd,
                              signal_cat_370 };
    assign signal_cat_171 = { gnd,
                              signal_wire_34 };
    assign signal_sub_112 = signal_const_41 - signal_cat_171;
    assign signal_cat_172 = { gnd,
                              signal_wire_34 };
    assign signal_sub_113 = signal_const_42 - signal_cat_172;
    assign signal_lt_110 = signal_const_43 < signal_wire_34;
    assign signal_mux_171 = signal_lt_110 ? signal_sub_112 : signal_sub_113;
    assign signal_lt_111 = signal_mux_171 < signal_cat_170;
    assign signal_mux_172 = signal_lt_111 ? signal_mux_170 : signal_select_1031;
    assign signal_select_1032 = signal_cat_182[15:15];
    assign signal_select_1033 = signal_cat_182[14:14];
    assign signal_select_1034 = signal_cat_182[13:13];
    assign signal_select_1035 = signal_cat_182[12:12];
    assign signal_select_1036 = signal_cat_182[11:11];
    assign signal_select_1037 = signal_cat_182[10:10];
    assign signal_select_1038 = signal_cat_182[9:9];
    assign signal_select_1039 = signal_cat_182[8:8];
    assign signal_select_1040 = signal_cat_182[7:7];
    assign signal_select_1041 = signal_cat_182[6:6];
    assign signal_select_1042 = signal_cat_182[5:5];
    assign signal_select_1043 = signal_cat_182[4:4];
    assign signal_select_1044 = signal_cat_182[3:3];
    assign signal_select_1045 = signal_cat_182[2:2];
    assign signal_select_1046 = signal_cat_182[1:1];
    assign signal_select_1047 = signal_cat_182[0:0];
    assign signal_select_1048 = signal_mux_174[3:0];
    always @* begin
        case (signal_select_1048)
        0:
            signal_mux_173 <= signal_select_1047;
        1:
            signal_mux_173 <= signal_select_1046;
        2:
            signal_mux_173 <= signal_select_1045;
        3:
            signal_mux_173 <= signal_select_1044;
        4:
            signal_mux_173 <= signal_select_1043;
        5:
            signal_mux_173 <= signal_select_1042;
        6:
            signal_mux_173 <= signal_select_1041;
        7:
            signal_mux_173 <= signal_select_1040;
        8:
            signal_mux_173 <= signal_select_1039;
        9:
            signal_mux_173 <= signal_select_1038;
        10:
            signal_mux_173 <= signal_select_1037;
        11:
            signal_mux_173 <= signal_select_1036;
        12:
            signal_mux_173 <= signal_select_1035;
        13:
            signal_mux_173 <= signal_select_1034;
        14:
            signal_mux_173 <= signal_select_1033;
        default:
            signal_mux_173 <= signal_select_1032;
        endcase
    end
    assign signal_select_1049 = pin_out_0[16:16];
    assign signal_cat_173 = { gnd,
                              signal_cat_370 };
    assign signal_cat_174 = { gnd,
                              signal_wire_34 };
    assign signal_sub_114 = signal_const_44 - signal_cat_174;
    assign signal_cat_175 = { gnd,
                              signal_wire_34 };
    assign signal_sub_115 = signal_const_45 - signal_cat_175;
    assign signal_lt_112 = signal_const_46 < signal_wire_34;
    assign signal_mux_174 = signal_lt_112 ? signal_sub_114 : signal_sub_115;
    assign signal_lt_113 = signal_mux_174 < signal_cat_173;
    assign signal_mux_175 = signal_lt_113 ? signal_mux_173 : signal_select_1049;
    assign signal_select_1050 = signal_cat_182[15:15];
    assign signal_select_1051 = signal_cat_182[14:14];
    assign signal_select_1052 = signal_cat_182[13:13];
    assign signal_select_1053 = signal_cat_182[12:12];
    assign signal_select_1054 = signal_cat_182[11:11];
    assign signal_select_1055 = signal_cat_182[10:10];
    assign signal_select_1056 = signal_cat_182[9:9];
    assign signal_select_1057 = signal_cat_182[8:8];
    assign signal_select_1058 = signal_cat_182[7:7];
    assign signal_select_1059 = signal_cat_182[6:6];
    assign signal_select_1060 = signal_cat_182[5:5];
    assign signal_select_1061 = signal_cat_182[4:4];
    assign signal_select_1062 = signal_cat_182[3:3];
    assign signal_select_1063 = signal_cat_182[2:2];
    assign signal_select_1064 = signal_cat_182[1:1];
    assign signal_select_1065 = signal_cat_182[0:0];
    assign signal_select_1066 = signal_mux_177[3:0];
    always @* begin
        case (signal_select_1066)
        0:
            signal_mux_176 <= signal_select_1065;
        1:
            signal_mux_176 <= signal_select_1064;
        2:
            signal_mux_176 <= signal_select_1063;
        3:
            signal_mux_176 <= signal_select_1062;
        4:
            signal_mux_176 <= signal_select_1061;
        5:
            signal_mux_176 <= signal_select_1060;
        6:
            signal_mux_176 <= signal_select_1059;
        7:
            signal_mux_176 <= signal_select_1058;
        8:
            signal_mux_176 <= signal_select_1057;
        9:
            signal_mux_176 <= signal_select_1056;
        10:
            signal_mux_176 <= signal_select_1055;
        11:
            signal_mux_176 <= signal_select_1054;
        12:
            signal_mux_176 <= signal_select_1053;
        13:
            signal_mux_176 <= signal_select_1052;
        14:
            signal_mux_176 <= signal_select_1051;
        default:
            signal_mux_176 <= signal_select_1050;
        endcase
    end
    assign signal_select_1067 = pin_out_0[17:17];
    assign signal_cat_176 = { gnd,
                              signal_cat_370 };
    assign signal_cat_177 = { gnd,
                              signal_wire_34 };
    assign signal_sub_116 = signal_const_47 - signal_cat_177;
    assign signal_cat_178 = { gnd,
                              signal_wire_34 };
    assign signal_sub_117 = signal_const_48 - signal_cat_178;
    assign signal_lt_114 = signal_const_49 < signal_wire_34;
    assign signal_mux_177 = signal_lt_114 ? signal_sub_116 : signal_sub_117;
    assign signal_lt_115 = signal_mux_177 < signal_cat_176;
    assign signal_mux_178 = signal_lt_115 ? signal_mux_176 : signal_select_1067;
    assign signal_select_1068 = signal_cat_182[15:15];
    assign signal_select_1069 = signal_cat_182[14:14];
    assign signal_select_1070 = signal_cat_182[13:13];
    assign signal_select_1071 = signal_cat_182[12:12];
    assign signal_select_1072 = signal_cat_182[11:11];
    assign signal_select_1073 = signal_cat_182[10:10];
    assign signal_select_1074 = signal_cat_182[9:9];
    assign signal_select_1075 = signal_cat_182[8:8];
    assign signal_select_1076 = signal_cat_182[7:7];
    assign signal_select_1077 = signal_cat_182[6:6];
    assign signal_select_1078 = signal_cat_182[5:5];
    assign signal_select_1079 = signal_cat_182[4:4];
    assign signal_select_1080 = signal_cat_182[3:3];
    assign signal_select_1081 = signal_cat_182[2:2];
    assign signal_select_1082 = signal_cat_182[1:1];
    assign signal_select_1083 = signal_cat_182[0:0];
    assign signal_select_1084 = signal_mux_180[3:0];
    always @* begin
        case (signal_select_1084)
        0:
            signal_mux_179 <= signal_select_1083;
        1:
            signal_mux_179 <= signal_select_1082;
        2:
            signal_mux_179 <= signal_select_1081;
        3:
            signal_mux_179 <= signal_select_1080;
        4:
            signal_mux_179 <= signal_select_1079;
        5:
            signal_mux_179 <= signal_select_1078;
        6:
            signal_mux_179 <= signal_select_1077;
        7:
            signal_mux_179 <= signal_select_1076;
        8:
            signal_mux_179 <= signal_select_1075;
        9:
            signal_mux_179 <= signal_select_1074;
        10:
            signal_mux_179 <= signal_select_1073;
        11:
            signal_mux_179 <= signal_select_1072;
        12:
            signal_mux_179 <= signal_select_1071;
        13:
            signal_mux_179 <= signal_select_1070;
        14:
            signal_mux_179 <= signal_select_1069;
        default:
            signal_mux_179 <= signal_select_1068;
        endcase
    end
    assign signal_select_1085 = pin_out_0[18:18];
    assign signal_cat_179 = { gnd,
                              signal_cat_370 };
    assign signal_cat_180 = { gnd,
                              signal_wire_34 };
    assign signal_sub_118 = signal_const_50 - signal_cat_180;
    assign signal_cat_181 = { gnd,
                              signal_wire_34 };
    assign signal_sub_119 = signal_const_51 - signal_cat_181;
    assign signal_lt_116 = signal_const_52 < signal_wire_34;
    assign signal_mux_180 = signal_lt_116 ? signal_sub_118 : signal_sub_119;
    assign signal_lt_117 = signal_mux_180 < signal_cat_179;
    assign signal_mux_181 = signal_lt_117 ? signal_mux_179 : signal_select_1085;
    assign signal_select_1086 = signal_cat_182[15:15];
    assign signal_select_1087 = signal_cat_182[14:14];
    assign signal_select_1088 = signal_cat_182[13:13];
    assign signal_select_1089 = signal_cat_182[12:12];
    assign signal_select_1090 = signal_cat_182[11:11];
    assign signal_select_1091 = signal_cat_182[10:10];
    assign signal_select_1092 = signal_cat_182[9:9];
    assign signal_select_1093 = signal_cat_182[8:8];
    assign signal_select_1094 = signal_cat_182[7:7];
    assign signal_select_1095 = signal_cat_182[6:6];
    assign signal_select_1096 = signal_cat_182[5:5];
    assign signal_select_1097 = signal_cat_182[4:4];
    assign signal_select_1098 = signal_cat_182[3:3];
    assign signal_select_1099 = signal_cat_182[2:2];
    assign signal_select_1100 = signal_cat_182[1:1];
    assign signal_const_192 = 14'b00000000000000;
    assign signal_cat_182 = { signal_const_192,
                              d$side_set };
    assign signal_select_1101 = signal_cat_182[0:0];
    assign signal_select_1102 = signal_mux_183[3:0];
    always @* begin
        case (signal_select_1102)
        0:
            signal_mux_182 <= signal_select_1101;
        1:
            signal_mux_182 <= signal_select_1100;
        2:
            signal_mux_182 <= signal_select_1099;
        3:
            signal_mux_182 <= signal_select_1098;
        4:
            signal_mux_182 <= signal_select_1097;
        5:
            signal_mux_182 <= signal_select_1096;
        6:
            signal_mux_182 <= signal_select_1095;
        7:
            signal_mux_182 <= signal_select_1094;
        8:
            signal_mux_182 <= signal_select_1093;
        9:
            signal_mux_182 <= signal_select_1092;
        10:
            signal_mux_182 <= signal_select_1091;
        11:
            signal_mux_182 <= signal_select_1090;
        12:
            signal_mux_182 <= signal_select_1089;
        13:
            signal_mux_182 <= signal_select_1088;
        14:
            signal_mux_182 <= signal_select_1087;
        default:
            signal_mux_182 <= signal_select_1086;
        endcase
    end
    assign signal_select_1103 = pin_out_0[19:19];
    assign signal_cat_183 = { gnd,
                              signal_cat_370 };
    assign signal_cat_184 = { gnd,
                              signal_wire_34 };
    assign signal_sub_120 = signal_const_54 - signal_cat_184;
    assign signal_cat_185 = { gnd,
                              signal_wire_34 };
    assign signal_sub_121 = signal_const_55 - signal_cat_185;
    assign signal_lt_118 = signal_const_56 < signal_wire_34;
    assign signal_mux_183 = signal_lt_118 ? signal_sub_120 : signal_sub_121;
    assign signal_lt_119 = signal_mux_183 < signal_cat_183;
    assign signal_mux_184 = signal_lt_119 ? signal_mux_182 : signal_select_1103;
    assign pin_out_side = { signal_mux_184,
                            signal_mux_181,
                            signal_mux_178,
                            signal_mux_175,
                            signal_mux_172,
                            signal_mux_169,
                            signal_mux_166,
                            signal_mux_163,
                            signal_mux_160,
                            signal_mux_157,
                            signal_mux_154,
                            signal_mux_151,
                            signal_mux_148,
                            signal_mux_145,
                            signal_mux_142,
                            signal_select_833,
                            signal_select_832,
                            signal_select_831,
                            signal_select_830,
                            signal_select_829 };
    assign pin_out_base = signal_wire_35 ? pin_out_0 : pin_out_side;
    assign signal_const_196 = 16'b0000000000000000;
    assign signal_const_197 = 16'b1111111111111111;
    assign signal_wire_2 = program_write$data;
    assign signal_wire_3 = program_write$addr;
    assign signal_const_198 = 9'b000000000;
    assign signal_const_199 = 9'b000000001;
    assign signal_eq_8 = signal_const_198 == signal_wire_5;
    assign signal_mux_185 = signal_eq_8 ? signal_wire_4 : signal_const_199;
    assign signal_add = pc_next + signal_const_199;
    assign signal_eq_9 = pc_next == signal_wire_5;
    assign signal_mux_186 = signal_eq_9 ? signal_wire_4 : signal_add;
    assign signal_wire_4 = config$wrap_bottom;
    assign signal_add_1 = pc_0 + signal_const_199;
    assign signal_wire_5 = config$wrap_top;
    assign d$jmp_target = word[8:0];
    assign signal_const_205 = 5'b00000;
    assign signal_const_208 = 5'b00001;
    assign signal_add_2 = stuff_run_0 + signal_const_208;
    assign stuff_run_max = 5'b11111;
    assign signal_eq_10 = stuff_run_0 == stuff_run_max;
    assign signal_mux_187 = signal_eq_10 ? stuff_run_0 : signal_add_2;
    assign signal_wire_6 = config$stuff_level;
    assign signal_eq_11 = crossing_bit == signal_wire_6;
    assign signal_mux_188 = signal_eq_11 ? signal_mux_187 : signal_const_205;
    assign signal_mux_189 = bit_crosses ? signal_mux_188 : stuff_run_0;
    assign signal_eq_12 = d$sys_op$binary_variant == signal_const_2;
    assign signal_and_11 = is_opcode$7 & signal_eq_12;
    assign stuff_run_next = signal_and_11 ? signal_const_205 : signal_mux_189;
    assign signal_mux_190 = go ? stuff_run_next : stuff_run_0;
    assign signal_mux_191 = start_0 ? signal_const_205 : signal_mux_190;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_4 <= signal_const_205;
        else
            signal_reg_4 <= signal_mux_191;
    end
    assign stuff_run_0 = signal_reg_4;
    assign signal_lt_120 = stuff_run_0 < signal_wire_7;
    assign signal_not_3 = ~ signal_lt_120;
    assign signal_wire_7 = config$stuff_threshold;
    assign signal_eq_13 = signal_wire_7 == signal_const_205;
    assign signal_not_4 = ~ signal_eq_13;
    assign signal_and_12 = signal_not_4 & signal_not_3;
    assign signal_lt_121 = osr_count_0 < signal_wire_29;
    assign signal_select_1104 = sample[19:19];
    assign signal_select_1105 = sample[18:18];
    assign signal_select_1106 = sample[17:17];
    assign signal_select_1107 = sample[16:16];
    assign signal_select_1108 = sample[15:15];
    assign signal_select_1109 = sample[14:14];
    assign signal_select_1110 = sample[13:13];
    assign signal_select_1111 = sample[12:12];
    assign signal_select_1112 = sample[11:11];
    assign signal_select_1113 = sample[10:10];
    assign signal_select_1114 = sample[9:9];
    assign signal_select_1115 = sample[8:8];
    assign signal_select_1116 = sample[7:7];
    assign signal_select_1117 = sample[6:6];
    assign signal_select_1118 = sample[5:5];
    assign signal_select_1119 = sample[4:4];
    assign signal_select_1120 = sample[3:3];
    assign signal_select_1121 = sample[2:2];
    assign signal_select_1122 = sample[1:1];
    assign signal_select_1123 = sample[0:0];
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_192 <= signal_select_1123;
        1:
            signal_mux_192 <= signal_select_1122;
        2:
            signal_mux_192 <= signal_select_1121;
        3:
            signal_mux_192 <= signal_select_1120;
        4:
            signal_mux_192 <= signal_select_1119;
        5:
            signal_mux_192 <= signal_select_1118;
        6:
            signal_mux_192 <= signal_select_1117;
        7:
            signal_mux_192 <= signal_select_1116;
        8:
            signal_mux_192 <= signal_select_1115;
        9:
            signal_mux_192 <= signal_select_1114;
        10:
            signal_mux_192 <= signal_select_1113;
        11:
            signal_mux_192 <= signal_select_1112;
        12:
            signal_mux_192 <= signal_select_1111;
        13:
            signal_mux_192 <= signal_select_1110;
        14:
            signal_mux_192 <= signal_select_1109;
        15:
            signal_mux_192 <= signal_select_1108;
        16:
            signal_mux_192 <= signal_select_1107;
        17:
            signal_mux_192 <= signal_select_1106;
        18:
            signal_mux_192 <= signal_select_1105;
        default:
            signal_mux_192 <= signal_select_1104;
        endcase
    end
    assign signal_not_5 = ~ signal_mux_192;
    assign signal_select_1124 = sample[19:19];
    assign signal_select_1125 = sample[18:18];
    assign signal_select_1126 = sample[17:17];
    assign signal_select_1127 = sample[16:16];
    assign signal_select_1128 = sample[15:15];
    assign signal_select_1129 = sample[14:14];
    assign signal_select_1130 = sample[13:13];
    assign signal_select_1131 = sample[12:12];
    assign signal_select_1132 = sample[11:11];
    assign signal_select_1133 = sample[10:10];
    assign signal_select_1134 = sample[9:9];
    assign signal_select_1135 = sample[8:8];
    assign signal_select_1136 = sample[7:7];
    assign signal_select_1137 = sample[6:6];
    assign signal_select_1138 = sample[5:5];
    assign signal_select_1139 = sample[4:4];
    assign signal_select_1140 = sample[3:3];
    assign signal_select_1141 = sample[2:2];
    assign signal_select_1142 = sample[1:1];
    assign signal_select_1143 = sample[0:0];
    assign signal_wire_8 = config$jmp_pin;
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_193 <= signal_select_1143;
        1:
            signal_mux_193 <= signal_select_1142;
        2:
            signal_mux_193 <= signal_select_1141;
        3:
            signal_mux_193 <= signal_select_1140;
        4:
            signal_mux_193 <= signal_select_1139;
        5:
            signal_mux_193 <= signal_select_1138;
        6:
            signal_mux_193 <= signal_select_1137;
        7:
            signal_mux_193 <= signal_select_1136;
        8:
            signal_mux_193 <= signal_select_1135;
        9:
            signal_mux_193 <= signal_select_1134;
        10:
            signal_mux_193 <= signal_select_1133;
        11:
            signal_mux_193 <= signal_select_1132;
        12:
            signal_mux_193 <= signal_select_1131;
        13:
            signal_mux_193 <= signal_select_1130;
        14:
            signal_mux_193 <= signal_select_1129;
        15:
            signal_mux_193 <= signal_select_1128;
        16:
            signal_mux_193 <= signal_select_1127;
        17:
            signal_mux_193 <= signal_select_1126;
        18:
            signal_mux_193 <= signal_select_1125;
        default:
            signal_mux_193 <= signal_select_1124;
        endcase
    end
    assign signal_eq_14 = x_0 == y_0;
    assign signal_not_6 = ~ signal_eq_14;
    assign signal_eq_15 = y_0 == signal_const_196;
    assign signal_not_7 = ~ signal_eq_15;
    assign signal_eq_16 = x_0 == signal_const_196;
    assign signal_not_8 = ~ signal_eq_16;
    always @* begin
        case (d$jmp_cond$binary_variant)
        0:
            jmp_taken <= vdd;
        1:
            jmp_taken <= signal_not_8;
        2:
            jmp_taken <= signal_not_7;
        3:
            jmp_taken <= signal_not_6;
        4:
            jmp_taken <= signal_mux_193;
        5:
            jmp_taken <= signal_not_5;
        6:
            jmp_taken <= signal_lt_121;
        default:
            jmp_taken <= signal_and_12;
        endcase
    end
    assign jmp_target_or_next = jmp_taken ? d$jmp_target : pc_next;
    assign signal_mux_194 = advance ? pc_next : pc_0;
    assign signal_mux_195 = jmp_go ? jmp_target_or_next : signal_mux_194;
    assign pc_value_next = start_0 ? signal_const_198 : signal_mux_195;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_5 <= signal_const_198;
        else
            signal_reg_5 <= pc_value_next;
    end
    assign pc_0 = signal_reg_5;
    assign signal_eq_17 = pc_0 == signal_wire_5;
    assign pc_next = signal_eq_17 ? signal_wire_4 : signal_add_1;
    assign signal_mux_196 = advance ? signal_mux_186 : pc_next;
    assign pc_after_next = start_0 ? signal_mux_185 : signal_mux_196;
    assign signal_not_9 = ~ start_0;
    assign signal_and_13 = signal_select_2712 & signal_const_19;
    assign signal_and_14 = signal_select_2712 & signal_const_19;
    assign signal_and_15 = signal_select_2712 & signal_const_43;
    always @* begin
        case (signal_wire_33)
        0:
            d$delay <= signal_select_2712;
        1:
            d$delay <= signal_and_15;
        2:
            d$delay <= signal_and_14;
        default:
            d$delay <= signal_and_13;
        endcase
    end
    assign signal_sub_122 = stall_0 - signal_const_208;
    assign signal_eq_18 = stall_0 == signal_const_205;
    assign signal_not_10 = ~ signal_eq_18;
    assign signal_mux_197 = signal_not_10 ? signal_sub_122 : stall_0;
    assign signal_mux_198 = advance ? d$delay : signal_mux_197;
    assign signal_mux_199 = jmp_go ? signal_const_208 : signal_mux_198;
    assign stall_next = start_0 ? signal_const_205 : signal_mux_199;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_6 <= signal_const_205;
        else
            signal_reg_6 <= stall_next;
    end
    assign stall_0 = signal_reg_6;
    assign signal_eq_19 = stall_0 == signal_const_205;
    assign signal_const_223 = 3'b001;
    assign signal_eq_20 = d$sys_op$binary_variant == signal_const_223;
    assign signal_and_16 = is_opcode$7 & signal_eq_20;
    assign signal_and_17 = op_go & signal_and_16;
    assign signal_mux_200 = signal_and_17 ? vdd : halted_0;
    assign signal_or_1 = jmp_go | signal_wire_37;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            refill <= signal_const_3;
        else
            refill <= signal_or_1;
    end
    assign signal_not_11 = ~ signal_select_2547;
    assign signal_wire_9 = rx_pop;
    assign signal_mux_201 = is_opcode$2 ? isr_shifted : isr_0;
    assign signal_wire_10 = signal_mux_201;
    assign signal_not_12 = ~ signal_select_1144;
    assign signal_const_225 = 3'b011;
    assign signal_eq_21 = d$sys_op$binary_variant == signal_const_225;
    assign signal_and_18 = is_opcode$7 & signal_eq_21;
    assign signal_and_19 = is_opcode$2 & autopush_now;
    assign pushes = signal_and_19 | signal_and_18;
    assign signal_and_20 = op_go & pushes;
    assign signal_and_21 = signal_and_20 & signal_not_12;
    assign signal_wire_11 = signal_and_21;
    host_fifo
        rx
        ( .clock(signal_wire_39),
          .clear(signal_wire_36),
          .push$valid(signal_wire_11),
          .push$value(signal_wire_10),
          .pop(signal_wire_9),
          .head(signal_inst[15:0]),
          .level(signal_inst[18:16]),
          .empty(signal_inst[19:19]),
          .full(signal_inst[20:20]) );
    assign signal_select_1144 = signal_inst[20:20];
    assign signal_not_13 = ~ signal_select_1144;
    assign signal_mux_202 = d$wait_polarity ? signal_not_11 : signal_not_13;
    assign signal_xor = t_0 ^ signal_cat_186;
    assign signal_sub_123 = t_0 - signal_cat_186;
    assign signal_const_227 = 8'b00000000;
    assign signal_cat_186 = { signal_const_227,
                              alu_operand };
    assign signal_add_3 = t_0 + signal_cat_186;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_203 <= signal_add_3;
        1:
            signal_mux_203 <= signal_sub_123;
        default:
            signal_mux_203 <= signal_xor;
        endcase
    end
    assign signal_const_228 = 2'b11;
    assign signal_eq_22 = d$alu_dest$binary_variant == signal_const_228;
    assign signal_mux_204 = signal_eq_22 ? signal_mux_203 : t_0;
    assign signal_select_1145 = mov_value24[23:23];
    assign signal_select_1146 = mov_value24[22:22];
    assign signal_select_1147 = mov_value24[21:21];
    assign signal_select_1148 = mov_value24[20:20];
    assign signal_select_1149 = mov_value24[19:19];
    assign signal_select_1150 = mov_value24[18:18];
    assign signal_select_1151 = mov_value24[17:17];
    assign signal_select_1152 = mov_value24[16:16];
    assign signal_select_1153 = mov_value24[15:15];
    assign signal_select_1154 = mov_value24[14:14];
    assign signal_select_1155 = mov_value24[13:13];
    assign signal_select_1156 = mov_value24[12:12];
    assign signal_select_1157 = mov_value24[11:11];
    assign signal_select_1158 = mov_value24[10:10];
    assign signal_select_1159 = mov_value24[9:9];
    assign signal_select_1160 = mov_value24[8:8];
    assign signal_select_1161 = mov_value24[7:7];
    assign signal_select_1162 = mov_value24[6:6];
    assign signal_select_1163 = mov_value24[5:5];
    assign signal_select_1164 = mov_value24[4:4];
    assign signal_select_1165 = mov_value24[3:3];
    assign signal_select_1166 = mov_value24[2:2];
    assign signal_select_1167 = mov_value24[1:1];
    assign signal_select_1168 = mov_value24[0:0];
    assign signal_cat_187 = { signal_select_1168,
                              signal_select_1167,
                              signal_select_1166,
                              signal_select_1165,
                              signal_select_1164,
                              signal_select_1163,
                              signal_select_1162,
                              signal_select_1161,
                              signal_select_1160,
                              signal_select_1159,
                              signal_select_1158,
                              signal_select_1157,
                              signal_select_1156,
                              signal_select_1155,
                              signal_select_1154,
                              signal_select_1153,
                              signal_select_1152,
                              signal_select_1151,
                              signal_select_1150,
                              signal_select_1149,
                              signal_select_1148,
                              signal_select_1147,
                              signal_select_1146,
                              signal_select_1145 };
    assign signal_not_14 = ~ mov_value24;
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value_t <= mov_value24;
        1:
            mov_value_t <= signal_not_14;
        default:
            mov_value_t <= signal_cat_187;
        endcase
    end
    assign signal_const_229 = 3'b111;
    assign signal_eq_23 = d$mov_dest$binary_variant == signal_const_229;
    assign signal_mux_205 = signal_eq_23 ? mov_value_t : t_0;
    assign signal_cat_188 = { signal_const_227,
                              out_value };
    assign signal_eq_24 = d$out_dest$binary_variant == signal_const_229;
    assign signal_mux_206 = signal_eq_24 ? signal_cat_188 : t_0;
    assign signal_cat_189 = { signal_const_227,
                              p_0 };
    assign signal_add_4 = t_0 + signal_cat_189;
    assign signal_const_233 = 2'b10;
    assign signal_eq_25 = d$wait_source$binary_variant == signal_const_233;
    assign signal_and_22 = is_opcode$1 & signal_eq_25;
    assign releases_deadline = signal_and_22 & wait_ready;
    assign signal_and_23 = releases_deadline & d$wait_polarity;
    assign signal_mux_207 = signal_and_23 ? signal_add_4 : t_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_next <= t_0;
        1:
            t_next <= signal_mux_207;
        2:
            t_next <= t_0;
        3:
            t_next <= signal_mux_206;
        4:
            t_next <= signal_mux_205;
        5:
            t_next <= t_0;
        6:
            t_next <= signal_mux_204;
        default:
            t_next <= t_0;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_7 <= signal_const_4;
        else
            if (go)
                signal_reg_7 <= t_next;
    end
    assign t_0 = signal_reg_7;
    assign signal_sub_124 = now_0 - t_0;
    assign signal_select_1169 = signal_sub_124[23:23];
    assign deadline_ready = ~ signal_select_1169;
    assign signal_eq_26 = wait_pin_cur == d$wait_polarity;
    assign signal_select_1170 = pins_sampled[19:19];
    assign signal_select_1171 = pins_sampled[18:18];
    assign signal_select_1172 = pins_sampled[17:17];
    assign signal_select_1173 = pins_sampled[16:16];
    assign signal_select_1174 = pins_sampled[15:15];
    assign signal_select_1175 = pins_sampled[14:14];
    assign signal_select_1176 = pins_sampled[13:13];
    assign signal_select_1177 = pins_sampled[12:12];
    assign signal_select_1178 = pins_sampled[11:11];
    assign signal_select_1179 = pins_sampled[10:10];
    assign signal_select_1180 = pins_sampled[9:9];
    assign signal_select_1181 = pins_sampled[8:8];
    assign signal_select_1182 = pins_sampled[7:7];
    assign signal_select_1183 = pins_sampled[6:6];
    assign signal_select_1184 = pins_sampled[5:5];
    assign signal_select_1185 = pins_sampled[4:4];
    assign signal_select_1186 = pins_sampled[3:3];
    assign signal_select_1187 = pins_sampled[2:2];
    assign signal_select_1188 = pins_sampled[1:1];
    assign signal_select_1189 = pins_sampled[0:0];
    always @* begin
        case (d$wait_index)
        0:
            wait_pin_prev <= signal_select_1189;
        1:
            wait_pin_prev <= signal_select_1188;
        2:
            wait_pin_prev <= signal_select_1187;
        3:
            wait_pin_prev <= signal_select_1186;
        4:
            wait_pin_prev <= signal_select_1185;
        5:
            wait_pin_prev <= signal_select_1184;
        6:
            wait_pin_prev <= signal_select_1183;
        7:
            wait_pin_prev <= signal_select_1182;
        8:
            wait_pin_prev <= signal_select_1181;
        9:
            wait_pin_prev <= signal_select_1180;
        10:
            wait_pin_prev <= signal_select_1179;
        11:
            wait_pin_prev <= signal_select_1178;
        12:
            wait_pin_prev <= signal_select_1177;
        13:
            wait_pin_prev <= signal_select_1176;
        14:
            wait_pin_prev <= signal_select_1175;
        15:
            wait_pin_prev <= signal_select_1174;
        16:
            wait_pin_prev <= signal_select_1173;
        17:
            wait_pin_prev <= signal_select_1172;
        18:
            wait_pin_prev <= signal_select_1171;
        default:
            wait_pin_prev <= signal_select_1170;
        endcase
    end
    assign signal_eq_27 = wait_pin_cur == wait_pin_prev;
    assign signal_not_15 = ~ signal_eq_27;
    assign signal_and_24 = signal_not_15 & signal_eq_26;
    assign d$wait_polarity = word[7:7];
    assign signal_select_1190 = sample[19:19];
    assign signal_select_1191 = sample[18:18];
    assign signal_select_1192 = sample[17:17];
    assign signal_select_1193 = sample[16:16];
    assign signal_select_1194 = sample[15:15];
    assign signal_select_1195 = sample[14:14];
    assign signal_select_1196 = sample[13:13];
    assign signal_select_1197 = sample[12:12];
    assign signal_select_1198 = sample[11:11];
    assign signal_select_1199 = sample[10:10];
    assign signal_select_1200 = sample[9:9];
    assign signal_select_1201 = sample[8:8];
    assign signal_select_1202 = sample[7:7];
    assign signal_select_1203 = sample[6:6];
    assign signal_select_1204 = sample[5:5];
    assign signal_select_1205 = sample[4:4];
    assign signal_select_1206 = sample[3:3];
    assign signal_select_1207 = sample[2:2];
    assign signal_select_1208 = sample[1:1];
    assign signal_select_1209 = signal_wire_12[0:0];
    assign signal_select_1210 = signal_wire_12[1:1];
    assign signal_select_1211 = signal_wire_12[2:2];
    assign signal_select_1212 = signal_wire_12[3:3];
    assign signal_select_1213 = signal_wire_12[4:4];
    assign signal_select_1214 = pin_out_0[5:5];
    assign signal_select_1215 = pin_out_0[6:6];
    assign signal_select_1216 = pin_out_0[7:7];
    assign signal_select_1217 = pin_out_0[8:8];
    assign signal_select_1218 = pin_out_0[9:9];
    assign signal_select_1219 = pin_out_0[10:10];
    assign signal_select_1220 = pin_out_0[11:11];
    assign signal_select_1221 = pin_out_0[12:12];
    assign signal_select_1222 = signal_wire_12[12:12];
    assign signal_select_1223 = pin_dir_0[12:12];
    assign signal_mux_208 = signal_select_1223 ? signal_select_1221 : signal_select_1222;
    assign signal_select_1224 = pin_out_0[13:13];
    assign signal_select_1225 = signal_wire_12[13:13];
    assign signal_select_1226 = pin_dir_0[13:13];
    assign signal_mux_209 = signal_select_1226 ? signal_select_1224 : signal_select_1225;
    assign signal_select_1227 = pin_out_0[14:14];
    assign signal_select_1228 = signal_wire_12[14:14];
    assign signal_select_1229 = pin_dir_0[14:14];
    assign signal_mux_210 = signal_select_1229 ? signal_select_1227 : signal_select_1228;
    assign signal_select_1230 = pin_out_0[15:15];
    assign signal_select_1231 = signal_wire_12[15:15];
    assign signal_select_1232 = pin_dir_0[15:15];
    assign signal_mux_211 = signal_select_1232 ? signal_select_1230 : signal_select_1231;
    assign signal_select_1233 = pin_out_0[16:16];
    assign signal_select_1234 = signal_wire_12[16:16];
    assign signal_select_1235 = pin_dir_0[16:16];
    assign signal_mux_212 = signal_select_1235 ? signal_select_1233 : signal_select_1234;
    assign signal_select_1236 = pin_out_0[17:17];
    assign signal_select_1237 = signal_wire_12[17:17];
    assign signal_select_1238 = pin_dir_0[17:17];
    assign signal_mux_213 = signal_select_1238 ? signal_select_1236 : signal_select_1237;
    assign signal_select_1239 = pin_out_0[18:18];
    assign signal_select_1240 = signal_wire_12[18:18];
    assign signal_select_1241 = pin_dir_0[18:18];
    assign signal_mux_214 = signal_select_1241 ? signal_select_1239 : signal_select_1240;
    assign signal_select_1242 = pin_out_0[19:19];
    assign signal_wire_12 = inputs;
    assign signal_select_1243 = signal_wire_12[19:19];
    assign signal_select_1244 = pin_dir_base[0:0];
    assign signal_select_1245 = pin_dir_base[1:1];
    assign signal_select_1246 = pin_dir_base[2:2];
    assign signal_select_1247 = pin_dir_base[3:3];
    assign signal_select_1248 = pin_dir_base[4:4];
    assign signal_select_1249 = pin_dir_base[5:5];
    assign signal_select_1250 = pin_dir_base[6:6];
    assign signal_select_1251 = pin_dir_base[7:7];
    assign signal_select_1252 = pin_dir_base[8:8];
    assign signal_select_1253 = pin_dir_base[9:9];
    assign signal_select_1254 = pin_dir_base[10:10];
    assign signal_select_1255 = pin_dir_base[11:11];
    assign signal_select_1256 = signal_cat_211[15:15];
    assign signal_select_1257 = signal_cat_211[14:14];
    assign signal_select_1258 = signal_cat_211[13:13];
    assign signal_select_1259 = signal_cat_211[12:12];
    assign signal_select_1260 = signal_cat_211[11:11];
    assign signal_select_1261 = signal_cat_211[10:10];
    assign signal_select_1262 = signal_cat_211[9:9];
    assign signal_select_1263 = signal_cat_211[8:8];
    assign signal_select_1264 = signal_cat_211[7:7];
    assign signal_select_1265 = signal_cat_211[6:6];
    assign signal_select_1266 = signal_cat_211[5:5];
    assign signal_select_1267 = signal_cat_211[4:4];
    assign signal_select_1268 = signal_cat_211[3:3];
    assign signal_select_1269 = signal_cat_211[2:2];
    assign signal_select_1270 = signal_cat_211[1:1];
    assign signal_select_1271 = signal_cat_211[0:0];
    assign signal_select_1272 = signal_mux_216[3:0];
    always @* begin
        case (signal_select_1272)
        0:
            signal_mux_215 <= signal_select_1271;
        1:
            signal_mux_215 <= signal_select_1270;
        2:
            signal_mux_215 <= signal_select_1269;
        3:
            signal_mux_215 <= signal_select_1268;
        4:
            signal_mux_215 <= signal_select_1267;
        5:
            signal_mux_215 <= signal_select_1266;
        6:
            signal_mux_215 <= signal_select_1265;
        7:
            signal_mux_215 <= signal_select_1264;
        8:
            signal_mux_215 <= signal_select_1263;
        9:
            signal_mux_215 <= signal_select_1262;
        10:
            signal_mux_215 <= signal_select_1261;
        11:
            signal_mux_215 <= signal_select_1260;
        12:
            signal_mux_215 <= signal_select_1259;
        13:
            signal_mux_215 <= signal_select_1258;
        14:
            signal_mux_215 <= signal_select_1257;
        default:
            signal_mux_215 <= signal_select_1256;
        endcase
    end
    assign signal_select_1273 = pin_dir_base[12:12];
    assign signal_cat_190 = { gnd,
                              signal_cat_212 };
    assign signal_cat_191 = { gnd,
                              signal_wire_14 };
    assign signal_sub_125 = signal_const_32 - signal_cat_191;
    assign signal_cat_192 = { gnd,
                              signal_wire_14 };
    assign signal_sub_126 = signal_const_33 - signal_cat_192;
    assign signal_lt_122 = signal_const_34 < signal_wire_14;
    assign signal_mux_216 = signal_lt_122 ? signal_sub_125 : signal_sub_126;
    assign signal_lt_123 = signal_mux_216 < signal_cat_190;
    assign signal_mux_217 = signal_lt_123 ? signal_mux_215 : signal_select_1273;
    assign signal_select_1274 = signal_cat_211[15:15];
    assign signal_select_1275 = signal_cat_211[14:14];
    assign signal_select_1276 = signal_cat_211[13:13];
    assign signal_select_1277 = signal_cat_211[12:12];
    assign signal_select_1278 = signal_cat_211[11:11];
    assign signal_select_1279 = signal_cat_211[10:10];
    assign signal_select_1280 = signal_cat_211[9:9];
    assign signal_select_1281 = signal_cat_211[8:8];
    assign signal_select_1282 = signal_cat_211[7:7];
    assign signal_select_1283 = signal_cat_211[6:6];
    assign signal_select_1284 = signal_cat_211[5:5];
    assign signal_select_1285 = signal_cat_211[4:4];
    assign signal_select_1286 = signal_cat_211[3:3];
    assign signal_select_1287 = signal_cat_211[2:2];
    assign signal_select_1288 = signal_cat_211[1:1];
    assign signal_select_1289 = signal_cat_211[0:0];
    assign signal_select_1290 = signal_mux_219[3:0];
    always @* begin
        case (signal_select_1290)
        0:
            signal_mux_218 <= signal_select_1289;
        1:
            signal_mux_218 <= signal_select_1288;
        2:
            signal_mux_218 <= signal_select_1287;
        3:
            signal_mux_218 <= signal_select_1286;
        4:
            signal_mux_218 <= signal_select_1285;
        5:
            signal_mux_218 <= signal_select_1284;
        6:
            signal_mux_218 <= signal_select_1283;
        7:
            signal_mux_218 <= signal_select_1282;
        8:
            signal_mux_218 <= signal_select_1281;
        9:
            signal_mux_218 <= signal_select_1280;
        10:
            signal_mux_218 <= signal_select_1279;
        11:
            signal_mux_218 <= signal_select_1278;
        12:
            signal_mux_218 <= signal_select_1277;
        13:
            signal_mux_218 <= signal_select_1276;
        14:
            signal_mux_218 <= signal_select_1275;
        default:
            signal_mux_218 <= signal_select_1274;
        endcase
    end
    assign signal_select_1291 = pin_dir_base[13:13];
    assign signal_cat_193 = { gnd,
                              signal_cat_212 };
    assign signal_cat_194 = { gnd,
                              signal_wire_14 };
    assign signal_sub_127 = signal_const_35 - signal_cat_194;
    assign signal_cat_195 = { gnd,
                              signal_wire_14 };
    assign signal_sub_128 = signal_const_36 - signal_cat_195;
    assign signal_lt_124 = signal_const_37 < signal_wire_14;
    assign signal_mux_219 = signal_lt_124 ? signal_sub_127 : signal_sub_128;
    assign signal_lt_125 = signal_mux_219 < signal_cat_193;
    assign signal_mux_220 = signal_lt_125 ? signal_mux_218 : signal_select_1291;
    assign signal_select_1292 = signal_cat_211[15:15];
    assign signal_select_1293 = signal_cat_211[14:14];
    assign signal_select_1294 = signal_cat_211[13:13];
    assign signal_select_1295 = signal_cat_211[12:12];
    assign signal_select_1296 = signal_cat_211[11:11];
    assign signal_select_1297 = signal_cat_211[10:10];
    assign signal_select_1298 = signal_cat_211[9:9];
    assign signal_select_1299 = signal_cat_211[8:8];
    assign signal_select_1300 = signal_cat_211[7:7];
    assign signal_select_1301 = signal_cat_211[6:6];
    assign signal_select_1302 = signal_cat_211[5:5];
    assign signal_select_1303 = signal_cat_211[4:4];
    assign signal_select_1304 = signal_cat_211[3:3];
    assign signal_select_1305 = signal_cat_211[2:2];
    assign signal_select_1306 = signal_cat_211[1:1];
    assign signal_select_1307 = signal_cat_211[0:0];
    assign signal_select_1308 = signal_mux_222[3:0];
    always @* begin
        case (signal_select_1308)
        0:
            signal_mux_221 <= signal_select_1307;
        1:
            signal_mux_221 <= signal_select_1306;
        2:
            signal_mux_221 <= signal_select_1305;
        3:
            signal_mux_221 <= signal_select_1304;
        4:
            signal_mux_221 <= signal_select_1303;
        5:
            signal_mux_221 <= signal_select_1302;
        6:
            signal_mux_221 <= signal_select_1301;
        7:
            signal_mux_221 <= signal_select_1300;
        8:
            signal_mux_221 <= signal_select_1299;
        9:
            signal_mux_221 <= signal_select_1298;
        10:
            signal_mux_221 <= signal_select_1297;
        11:
            signal_mux_221 <= signal_select_1296;
        12:
            signal_mux_221 <= signal_select_1295;
        13:
            signal_mux_221 <= signal_select_1294;
        14:
            signal_mux_221 <= signal_select_1293;
        default:
            signal_mux_221 <= signal_select_1292;
        endcase
    end
    assign signal_select_1309 = pin_dir_base[14:14];
    assign signal_cat_196 = { gnd,
                              signal_cat_212 };
    assign signal_cat_197 = { gnd,
                              signal_wire_14 };
    assign signal_sub_129 = signal_const_38 - signal_cat_197;
    assign signal_cat_198 = { gnd,
                              signal_wire_14 };
    assign signal_sub_130 = signal_const_39 - signal_cat_198;
    assign signal_lt_126 = signal_const_40 < signal_wire_14;
    assign signal_mux_222 = signal_lt_126 ? signal_sub_129 : signal_sub_130;
    assign signal_lt_127 = signal_mux_222 < signal_cat_196;
    assign signal_mux_223 = signal_lt_127 ? signal_mux_221 : signal_select_1309;
    assign signal_select_1310 = signal_cat_211[15:15];
    assign signal_select_1311 = signal_cat_211[14:14];
    assign signal_select_1312 = signal_cat_211[13:13];
    assign signal_select_1313 = signal_cat_211[12:12];
    assign signal_select_1314 = signal_cat_211[11:11];
    assign signal_select_1315 = signal_cat_211[10:10];
    assign signal_select_1316 = signal_cat_211[9:9];
    assign signal_select_1317 = signal_cat_211[8:8];
    assign signal_select_1318 = signal_cat_211[7:7];
    assign signal_select_1319 = signal_cat_211[6:6];
    assign signal_select_1320 = signal_cat_211[5:5];
    assign signal_select_1321 = signal_cat_211[4:4];
    assign signal_select_1322 = signal_cat_211[3:3];
    assign signal_select_1323 = signal_cat_211[2:2];
    assign signal_select_1324 = signal_cat_211[1:1];
    assign signal_select_1325 = signal_cat_211[0:0];
    assign signal_select_1326 = signal_mux_225[3:0];
    always @* begin
        case (signal_select_1326)
        0:
            signal_mux_224 <= signal_select_1325;
        1:
            signal_mux_224 <= signal_select_1324;
        2:
            signal_mux_224 <= signal_select_1323;
        3:
            signal_mux_224 <= signal_select_1322;
        4:
            signal_mux_224 <= signal_select_1321;
        5:
            signal_mux_224 <= signal_select_1320;
        6:
            signal_mux_224 <= signal_select_1319;
        7:
            signal_mux_224 <= signal_select_1318;
        8:
            signal_mux_224 <= signal_select_1317;
        9:
            signal_mux_224 <= signal_select_1316;
        10:
            signal_mux_224 <= signal_select_1315;
        11:
            signal_mux_224 <= signal_select_1314;
        12:
            signal_mux_224 <= signal_select_1313;
        13:
            signal_mux_224 <= signal_select_1312;
        14:
            signal_mux_224 <= signal_select_1311;
        default:
            signal_mux_224 <= signal_select_1310;
        endcase
    end
    assign signal_select_1327 = pin_dir_base[15:15];
    assign signal_cat_199 = { gnd,
                              signal_cat_212 };
    assign signal_cat_200 = { gnd,
                              signal_wire_14 };
    assign signal_sub_131 = signal_const_41 - signal_cat_200;
    assign signal_cat_201 = { gnd,
                              signal_wire_14 };
    assign signal_sub_132 = signal_const_42 - signal_cat_201;
    assign signal_lt_128 = signal_const_43 < signal_wire_14;
    assign signal_mux_225 = signal_lt_128 ? signal_sub_131 : signal_sub_132;
    assign signal_lt_129 = signal_mux_225 < signal_cat_199;
    assign signal_mux_226 = signal_lt_129 ? signal_mux_224 : signal_select_1327;
    assign signal_select_1328 = signal_cat_211[15:15];
    assign signal_select_1329 = signal_cat_211[14:14];
    assign signal_select_1330 = signal_cat_211[13:13];
    assign signal_select_1331 = signal_cat_211[12:12];
    assign signal_select_1332 = signal_cat_211[11:11];
    assign signal_select_1333 = signal_cat_211[10:10];
    assign signal_select_1334 = signal_cat_211[9:9];
    assign signal_select_1335 = signal_cat_211[8:8];
    assign signal_select_1336 = signal_cat_211[7:7];
    assign signal_select_1337 = signal_cat_211[6:6];
    assign signal_select_1338 = signal_cat_211[5:5];
    assign signal_select_1339 = signal_cat_211[4:4];
    assign signal_select_1340 = signal_cat_211[3:3];
    assign signal_select_1341 = signal_cat_211[2:2];
    assign signal_select_1342 = signal_cat_211[1:1];
    assign signal_select_1343 = signal_cat_211[0:0];
    assign signal_select_1344 = signal_mux_228[3:0];
    always @* begin
        case (signal_select_1344)
        0:
            signal_mux_227 <= signal_select_1343;
        1:
            signal_mux_227 <= signal_select_1342;
        2:
            signal_mux_227 <= signal_select_1341;
        3:
            signal_mux_227 <= signal_select_1340;
        4:
            signal_mux_227 <= signal_select_1339;
        5:
            signal_mux_227 <= signal_select_1338;
        6:
            signal_mux_227 <= signal_select_1337;
        7:
            signal_mux_227 <= signal_select_1336;
        8:
            signal_mux_227 <= signal_select_1335;
        9:
            signal_mux_227 <= signal_select_1334;
        10:
            signal_mux_227 <= signal_select_1333;
        11:
            signal_mux_227 <= signal_select_1332;
        12:
            signal_mux_227 <= signal_select_1331;
        13:
            signal_mux_227 <= signal_select_1330;
        14:
            signal_mux_227 <= signal_select_1329;
        default:
            signal_mux_227 <= signal_select_1328;
        endcase
    end
    assign signal_select_1345 = pin_dir_base[16:16];
    assign signal_cat_202 = { gnd,
                              signal_cat_212 };
    assign signal_cat_203 = { gnd,
                              signal_wire_14 };
    assign signal_sub_133 = signal_const_44 - signal_cat_203;
    assign signal_cat_204 = { gnd,
                              signal_wire_14 };
    assign signal_sub_134 = signal_const_45 - signal_cat_204;
    assign signal_lt_130 = signal_const_46 < signal_wire_14;
    assign signal_mux_228 = signal_lt_130 ? signal_sub_133 : signal_sub_134;
    assign signal_lt_131 = signal_mux_228 < signal_cat_202;
    assign signal_mux_229 = signal_lt_131 ? signal_mux_227 : signal_select_1345;
    assign signal_select_1346 = signal_cat_211[15:15];
    assign signal_select_1347 = signal_cat_211[14:14];
    assign signal_select_1348 = signal_cat_211[13:13];
    assign signal_select_1349 = signal_cat_211[12:12];
    assign signal_select_1350 = signal_cat_211[11:11];
    assign signal_select_1351 = signal_cat_211[10:10];
    assign signal_select_1352 = signal_cat_211[9:9];
    assign signal_select_1353 = signal_cat_211[8:8];
    assign signal_select_1354 = signal_cat_211[7:7];
    assign signal_select_1355 = signal_cat_211[6:6];
    assign signal_select_1356 = signal_cat_211[5:5];
    assign signal_select_1357 = signal_cat_211[4:4];
    assign signal_select_1358 = signal_cat_211[3:3];
    assign signal_select_1359 = signal_cat_211[2:2];
    assign signal_select_1360 = signal_cat_211[1:1];
    assign signal_select_1361 = signal_cat_211[0:0];
    assign signal_select_1362 = signal_mux_231[3:0];
    always @* begin
        case (signal_select_1362)
        0:
            signal_mux_230 <= signal_select_1361;
        1:
            signal_mux_230 <= signal_select_1360;
        2:
            signal_mux_230 <= signal_select_1359;
        3:
            signal_mux_230 <= signal_select_1358;
        4:
            signal_mux_230 <= signal_select_1357;
        5:
            signal_mux_230 <= signal_select_1356;
        6:
            signal_mux_230 <= signal_select_1355;
        7:
            signal_mux_230 <= signal_select_1354;
        8:
            signal_mux_230 <= signal_select_1353;
        9:
            signal_mux_230 <= signal_select_1352;
        10:
            signal_mux_230 <= signal_select_1351;
        11:
            signal_mux_230 <= signal_select_1350;
        12:
            signal_mux_230 <= signal_select_1349;
        13:
            signal_mux_230 <= signal_select_1348;
        14:
            signal_mux_230 <= signal_select_1347;
        default:
            signal_mux_230 <= signal_select_1346;
        endcase
    end
    assign signal_select_1363 = pin_dir_base[17:17];
    assign signal_cat_205 = { gnd,
                              signal_cat_212 };
    assign signal_cat_206 = { gnd,
                              signal_wire_14 };
    assign signal_sub_135 = signal_const_47 - signal_cat_206;
    assign signal_cat_207 = { gnd,
                              signal_wire_14 };
    assign signal_sub_136 = signal_const_48 - signal_cat_207;
    assign signal_lt_132 = signal_const_49 < signal_wire_14;
    assign signal_mux_231 = signal_lt_132 ? signal_sub_135 : signal_sub_136;
    assign signal_lt_133 = signal_mux_231 < signal_cat_205;
    assign signal_mux_232 = signal_lt_133 ? signal_mux_230 : signal_select_1363;
    assign signal_select_1364 = signal_cat_211[15:15];
    assign signal_select_1365 = signal_cat_211[14:14];
    assign signal_select_1366 = signal_cat_211[13:13];
    assign signal_select_1367 = signal_cat_211[12:12];
    assign signal_select_1368 = signal_cat_211[11:11];
    assign signal_select_1369 = signal_cat_211[10:10];
    assign signal_select_1370 = signal_cat_211[9:9];
    assign signal_select_1371 = signal_cat_211[8:8];
    assign signal_select_1372 = signal_cat_211[7:7];
    assign signal_select_1373 = signal_cat_211[6:6];
    assign signal_select_1374 = signal_cat_211[5:5];
    assign signal_select_1375 = signal_cat_211[4:4];
    assign signal_select_1376 = signal_cat_211[3:3];
    assign signal_select_1377 = signal_cat_211[2:2];
    assign signal_select_1378 = signal_cat_211[1:1];
    assign signal_select_1379 = signal_cat_211[0:0];
    assign signal_select_1380 = signal_mux_234[3:0];
    always @* begin
        case (signal_select_1380)
        0:
            signal_mux_233 <= signal_select_1379;
        1:
            signal_mux_233 <= signal_select_1378;
        2:
            signal_mux_233 <= signal_select_1377;
        3:
            signal_mux_233 <= signal_select_1376;
        4:
            signal_mux_233 <= signal_select_1375;
        5:
            signal_mux_233 <= signal_select_1374;
        6:
            signal_mux_233 <= signal_select_1373;
        7:
            signal_mux_233 <= signal_select_1372;
        8:
            signal_mux_233 <= signal_select_1371;
        9:
            signal_mux_233 <= signal_select_1370;
        10:
            signal_mux_233 <= signal_select_1369;
        11:
            signal_mux_233 <= signal_select_1368;
        12:
            signal_mux_233 <= signal_select_1367;
        13:
            signal_mux_233 <= signal_select_1366;
        14:
            signal_mux_233 <= signal_select_1365;
        default:
            signal_mux_233 <= signal_select_1364;
        endcase
    end
    assign signal_select_1381 = pin_dir_base[18:18];
    assign signal_cat_208 = { gnd,
                              signal_cat_212 };
    assign signal_cat_209 = { gnd,
                              signal_wire_14 };
    assign signal_sub_137 = signal_const_50 - signal_cat_209;
    assign signal_cat_210 = { gnd,
                              signal_wire_14 };
    assign signal_sub_138 = signal_const_51 - signal_cat_210;
    assign signal_lt_134 = signal_const_52 < signal_wire_14;
    assign signal_mux_234 = signal_lt_134 ? signal_sub_137 : signal_sub_138;
    assign signal_lt_135 = signal_mux_234 < signal_cat_208;
    assign signal_mux_235 = signal_lt_135 ? signal_mux_233 : signal_select_1381;
    assign signal_select_1382 = signal_cat_211[15:15];
    assign signal_select_1383 = signal_cat_211[14:14];
    assign signal_select_1384 = signal_cat_211[13:13];
    assign signal_select_1385 = signal_cat_211[12:12];
    assign signal_select_1386 = signal_cat_211[11:11];
    assign signal_select_1387 = signal_cat_211[10:10];
    assign signal_select_1388 = signal_cat_211[9:9];
    assign signal_select_1389 = signal_cat_211[8:8];
    assign signal_select_1390 = signal_cat_211[7:7];
    assign signal_select_1391 = signal_cat_211[6:6];
    assign signal_select_1392 = signal_cat_211[5:5];
    assign signal_select_1393 = signal_cat_211[4:4];
    assign signal_select_1394 = signal_cat_211[3:3];
    assign signal_select_1395 = signal_cat_211[2:2];
    assign signal_select_1396 = signal_cat_211[1:1];
    assign signal_cat_211 = { signal_const_53,
                              d$set_value };
    assign signal_select_1397 = signal_cat_211[0:0];
    assign signal_select_1398 = signal_mux_237[3:0];
    always @* begin
        case (signal_select_1398)
        0:
            signal_mux_236 <= signal_select_1397;
        1:
            signal_mux_236 <= signal_select_1396;
        2:
            signal_mux_236 <= signal_select_1395;
        3:
            signal_mux_236 <= signal_select_1394;
        4:
            signal_mux_236 <= signal_select_1393;
        5:
            signal_mux_236 <= signal_select_1392;
        6:
            signal_mux_236 <= signal_select_1391;
        7:
            signal_mux_236 <= signal_select_1390;
        8:
            signal_mux_236 <= signal_select_1389;
        9:
            signal_mux_236 <= signal_select_1388;
        10:
            signal_mux_236 <= signal_select_1387;
        11:
            signal_mux_236 <= signal_select_1386;
        12:
            signal_mux_236 <= signal_select_1385;
        13:
            signal_mux_236 <= signal_select_1384;
        14:
            signal_mux_236 <= signal_select_1383;
        default:
            signal_mux_236 <= signal_select_1382;
        endcase
    end
    assign signal_select_1399 = pin_dir_base[19:19];
    assign signal_wire_13 = config$set_count;
    assign signal_const_257 = 2'b00;
    assign signal_cat_212 = { signal_const_257,
                              signal_wire_13 };
    assign signal_cat_213 = { gnd,
                              signal_cat_212 };
    assign signal_cat_214 = { gnd,
                              signal_wire_14 };
    assign signal_sub_139 = signal_const_54 - signal_cat_214;
    assign signal_cat_215 = { gnd,
                              signal_wire_14 };
    assign signal_sub_140 = signal_const_55 - signal_cat_215;
    assign signal_wire_14 = config$set_base;
    assign signal_lt_136 = signal_const_56 < signal_wire_14;
    assign signal_mux_237 = signal_lt_136 ? signal_sub_139 : signal_sub_140;
    assign signal_lt_137 = signal_mux_237 < signal_cat_213;
    assign signal_mux_238 = signal_lt_137 ? signal_mux_236 : signal_select_1399;
    assign signal_cat_216 = { signal_mux_238,
                              signal_mux_235,
                              signal_mux_232,
                              signal_mux_229,
                              signal_mux_226,
                              signal_mux_223,
                              signal_mux_220,
                              signal_mux_217,
                              signal_select_1255,
                              signal_select_1254,
                              signal_select_1253,
                              signal_select_1252,
                              signal_select_1251,
                              signal_select_1250,
                              signal_select_1249,
                              signal_select_1248,
                              signal_select_1247,
                              signal_select_1246,
                              signal_select_1245,
                              signal_select_1244 };
    assign signal_eq_28 = d$set_dest$binary_variant == signal_const_225;
    assign signal_mux_239 = signal_eq_28 ? signal_cat_216 : pin_dir_base;
    assign signal_select_1400 = pin_dir_base[0:0];
    assign signal_select_1401 = pin_dir_base[1:1];
    assign signal_select_1402 = pin_dir_base[2:2];
    assign signal_select_1403 = pin_dir_base[3:3];
    assign signal_select_1404 = pin_dir_base[4:4];
    assign signal_select_1405 = pin_dir_base[5:5];
    assign signal_select_1406 = pin_dir_base[6:6];
    assign signal_select_1407 = pin_dir_base[7:7];
    assign signal_select_1408 = pin_dir_base[8:8];
    assign signal_select_1409 = pin_dir_base[9:9];
    assign signal_select_1410 = pin_dir_base[10:10];
    assign signal_select_1411 = pin_dir_base[11:11];
    assign signal_select_1412 = mov_value[15:15];
    assign signal_select_1413 = mov_value[14:14];
    assign signal_select_1414 = mov_value[13:13];
    assign signal_select_1415 = mov_value[12:12];
    assign signal_select_1416 = mov_value[11:11];
    assign signal_select_1417 = mov_value[10:10];
    assign signal_select_1418 = mov_value[9:9];
    assign signal_select_1419 = mov_value[8:8];
    assign signal_select_1420 = mov_value[7:7];
    assign signal_select_1421 = mov_value[6:6];
    assign signal_select_1422 = mov_value[5:5];
    assign signal_select_1423 = mov_value[4:4];
    assign signal_select_1424 = mov_value[3:3];
    assign signal_select_1425 = mov_value[2:2];
    assign signal_select_1426 = mov_value[1:1];
    assign signal_select_1427 = mov_value[0:0];
    assign signal_select_1428 = signal_mux_241[3:0];
    always @* begin
        case (signal_select_1428)
        0:
            signal_mux_240 <= signal_select_1427;
        1:
            signal_mux_240 <= signal_select_1426;
        2:
            signal_mux_240 <= signal_select_1425;
        3:
            signal_mux_240 <= signal_select_1424;
        4:
            signal_mux_240 <= signal_select_1423;
        5:
            signal_mux_240 <= signal_select_1422;
        6:
            signal_mux_240 <= signal_select_1421;
        7:
            signal_mux_240 <= signal_select_1420;
        8:
            signal_mux_240 <= signal_select_1419;
        9:
            signal_mux_240 <= signal_select_1418;
        10:
            signal_mux_240 <= signal_select_1417;
        11:
            signal_mux_240 <= signal_select_1416;
        12:
            signal_mux_240 <= signal_select_1415;
        13:
            signal_mux_240 <= signal_select_1414;
        14:
            signal_mux_240 <= signal_select_1413;
        default:
            signal_mux_240 <= signal_select_1412;
        endcase
    end
    assign signal_select_1429 = pin_dir_base[12:12];
    assign signal_cat_217 = { gnd,
                              signal_wire_15 };
    assign signal_cat_218 = { gnd,
                              signal_wire_32 };
    assign signal_sub_141 = signal_const_32 - signal_cat_218;
    assign signal_cat_219 = { gnd,
                              signal_wire_32 };
    assign signal_sub_142 = signal_const_33 - signal_cat_219;
    assign signal_lt_138 = signal_const_34 < signal_wire_32;
    assign signal_mux_241 = signal_lt_138 ? signal_sub_141 : signal_sub_142;
    assign signal_lt_139 = signal_mux_241 < signal_cat_217;
    assign signal_mux_242 = signal_lt_139 ? signal_mux_240 : signal_select_1429;
    assign signal_select_1430 = mov_value[15:15];
    assign signal_select_1431 = mov_value[14:14];
    assign signal_select_1432 = mov_value[13:13];
    assign signal_select_1433 = mov_value[12:12];
    assign signal_select_1434 = mov_value[11:11];
    assign signal_select_1435 = mov_value[10:10];
    assign signal_select_1436 = mov_value[9:9];
    assign signal_select_1437 = mov_value[8:8];
    assign signal_select_1438 = mov_value[7:7];
    assign signal_select_1439 = mov_value[6:6];
    assign signal_select_1440 = mov_value[5:5];
    assign signal_select_1441 = mov_value[4:4];
    assign signal_select_1442 = mov_value[3:3];
    assign signal_select_1443 = mov_value[2:2];
    assign signal_select_1444 = mov_value[1:1];
    assign signal_select_1445 = mov_value[0:0];
    assign signal_select_1446 = signal_mux_244[3:0];
    always @* begin
        case (signal_select_1446)
        0:
            signal_mux_243 <= signal_select_1445;
        1:
            signal_mux_243 <= signal_select_1444;
        2:
            signal_mux_243 <= signal_select_1443;
        3:
            signal_mux_243 <= signal_select_1442;
        4:
            signal_mux_243 <= signal_select_1441;
        5:
            signal_mux_243 <= signal_select_1440;
        6:
            signal_mux_243 <= signal_select_1439;
        7:
            signal_mux_243 <= signal_select_1438;
        8:
            signal_mux_243 <= signal_select_1437;
        9:
            signal_mux_243 <= signal_select_1436;
        10:
            signal_mux_243 <= signal_select_1435;
        11:
            signal_mux_243 <= signal_select_1434;
        12:
            signal_mux_243 <= signal_select_1433;
        13:
            signal_mux_243 <= signal_select_1432;
        14:
            signal_mux_243 <= signal_select_1431;
        default:
            signal_mux_243 <= signal_select_1430;
        endcase
    end
    assign signal_select_1447 = pin_dir_base[13:13];
    assign signal_cat_220 = { gnd,
                              signal_wire_15 };
    assign signal_cat_221 = { gnd,
                              signal_wire_32 };
    assign signal_sub_143 = signal_const_35 - signal_cat_221;
    assign signal_cat_222 = { gnd,
                              signal_wire_32 };
    assign signal_sub_144 = signal_const_36 - signal_cat_222;
    assign signal_lt_140 = signal_const_37 < signal_wire_32;
    assign signal_mux_244 = signal_lt_140 ? signal_sub_143 : signal_sub_144;
    assign signal_lt_141 = signal_mux_244 < signal_cat_220;
    assign signal_mux_245 = signal_lt_141 ? signal_mux_243 : signal_select_1447;
    assign signal_select_1448 = mov_value[15:15];
    assign signal_select_1449 = mov_value[14:14];
    assign signal_select_1450 = mov_value[13:13];
    assign signal_select_1451 = mov_value[12:12];
    assign signal_select_1452 = mov_value[11:11];
    assign signal_select_1453 = mov_value[10:10];
    assign signal_select_1454 = mov_value[9:9];
    assign signal_select_1455 = mov_value[8:8];
    assign signal_select_1456 = mov_value[7:7];
    assign signal_select_1457 = mov_value[6:6];
    assign signal_select_1458 = mov_value[5:5];
    assign signal_select_1459 = mov_value[4:4];
    assign signal_select_1460 = mov_value[3:3];
    assign signal_select_1461 = mov_value[2:2];
    assign signal_select_1462 = mov_value[1:1];
    assign signal_select_1463 = mov_value[0:0];
    assign signal_select_1464 = signal_mux_247[3:0];
    always @* begin
        case (signal_select_1464)
        0:
            signal_mux_246 <= signal_select_1463;
        1:
            signal_mux_246 <= signal_select_1462;
        2:
            signal_mux_246 <= signal_select_1461;
        3:
            signal_mux_246 <= signal_select_1460;
        4:
            signal_mux_246 <= signal_select_1459;
        5:
            signal_mux_246 <= signal_select_1458;
        6:
            signal_mux_246 <= signal_select_1457;
        7:
            signal_mux_246 <= signal_select_1456;
        8:
            signal_mux_246 <= signal_select_1455;
        9:
            signal_mux_246 <= signal_select_1454;
        10:
            signal_mux_246 <= signal_select_1453;
        11:
            signal_mux_246 <= signal_select_1452;
        12:
            signal_mux_246 <= signal_select_1451;
        13:
            signal_mux_246 <= signal_select_1450;
        14:
            signal_mux_246 <= signal_select_1449;
        default:
            signal_mux_246 <= signal_select_1448;
        endcase
    end
    assign signal_select_1465 = pin_dir_base[14:14];
    assign signal_cat_223 = { gnd,
                              signal_wire_15 };
    assign signal_cat_224 = { gnd,
                              signal_wire_32 };
    assign signal_sub_145 = signal_const_38 - signal_cat_224;
    assign signal_cat_225 = { gnd,
                              signal_wire_32 };
    assign signal_sub_146 = signal_const_39 - signal_cat_225;
    assign signal_lt_142 = signal_const_40 < signal_wire_32;
    assign signal_mux_247 = signal_lt_142 ? signal_sub_145 : signal_sub_146;
    assign signal_lt_143 = signal_mux_247 < signal_cat_223;
    assign signal_mux_248 = signal_lt_143 ? signal_mux_246 : signal_select_1465;
    assign signal_select_1466 = mov_value[15:15];
    assign signal_select_1467 = mov_value[14:14];
    assign signal_select_1468 = mov_value[13:13];
    assign signal_select_1469 = mov_value[12:12];
    assign signal_select_1470 = mov_value[11:11];
    assign signal_select_1471 = mov_value[10:10];
    assign signal_select_1472 = mov_value[9:9];
    assign signal_select_1473 = mov_value[8:8];
    assign signal_select_1474 = mov_value[7:7];
    assign signal_select_1475 = mov_value[6:6];
    assign signal_select_1476 = mov_value[5:5];
    assign signal_select_1477 = mov_value[4:4];
    assign signal_select_1478 = mov_value[3:3];
    assign signal_select_1479 = mov_value[2:2];
    assign signal_select_1480 = mov_value[1:1];
    assign signal_select_1481 = mov_value[0:0];
    assign signal_select_1482 = signal_mux_250[3:0];
    always @* begin
        case (signal_select_1482)
        0:
            signal_mux_249 <= signal_select_1481;
        1:
            signal_mux_249 <= signal_select_1480;
        2:
            signal_mux_249 <= signal_select_1479;
        3:
            signal_mux_249 <= signal_select_1478;
        4:
            signal_mux_249 <= signal_select_1477;
        5:
            signal_mux_249 <= signal_select_1476;
        6:
            signal_mux_249 <= signal_select_1475;
        7:
            signal_mux_249 <= signal_select_1474;
        8:
            signal_mux_249 <= signal_select_1473;
        9:
            signal_mux_249 <= signal_select_1472;
        10:
            signal_mux_249 <= signal_select_1471;
        11:
            signal_mux_249 <= signal_select_1470;
        12:
            signal_mux_249 <= signal_select_1469;
        13:
            signal_mux_249 <= signal_select_1468;
        14:
            signal_mux_249 <= signal_select_1467;
        default:
            signal_mux_249 <= signal_select_1466;
        endcase
    end
    assign signal_select_1483 = pin_dir_base[15:15];
    assign signal_cat_226 = { gnd,
                              signal_wire_15 };
    assign signal_cat_227 = { gnd,
                              signal_wire_32 };
    assign signal_sub_147 = signal_const_41 - signal_cat_227;
    assign signal_cat_228 = { gnd,
                              signal_wire_32 };
    assign signal_sub_148 = signal_const_42 - signal_cat_228;
    assign signal_lt_144 = signal_const_43 < signal_wire_32;
    assign signal_mux_250 = signal_lt_144 ? signal_sub_147 : signal_sub_148;
    assign signal_lt_145 = signal_mux_250 < signal_cat_226;
    assign signal_mux_251 = signal_lt_145 ? signal_mux_249 : signal_select_1483;
    assign signal_select_1484 = mov_value[15:15];
    assign signal_select_1485 = mov_value[14:14];
    assign signal_select_1486 = mov_value[13:13];
    assign signal_select_1487 = mov_value[12:12];
    assign signal_select_1488 = mov_value[11:11];
    assign signal_select_1489 = mov_value[10:10];
    assign signal_select_1490 = mov_value[9:9];
    assign signal_select_1491 = mov_value[8:8];
    assign signal_select_1492 = mov_value[7:7];
    assign signal_select_1493 = mov_value[6:6];
    assign signal_select_1494 = mov_value[5:5];
    assign signal_select_1495 = mov_value[4:4];
    assign signal_select_1496 = mov_value[3:3];
    assign signal_select_1497 = mov_value[2:2];
    assign signal_select_1498 = mov_value[1:1];
    assign signal_select_1499 = mov_value[0:0];
    assign signal_select_1500 = signal_mux_253[3:0];
    always @* begin
        case (signal_select_1500)
        0:
            signal_mux_252 <= signal_select_1499;
        1:
            signal_mux_252 <= signal_select_1498;
        2:
            signal_mux_252 <= signal_select_1497;
        3:
            signal_mux_252 <= signal_select_1496;
        4:
            signal_mux_252 <= signal_select_1495;
        5:
            signal_mux_252 <= signal_select_1494;
        6:
            signal_mux_252 <= signal_select_1493;
        7:
            signal_mux_252 <= signal_select_1492;
        8:
            signal_mux_252 <= signal_select_1491;
        9:
            signal_mux_252 <= signal_select_1490;
        10:
            signal_mux_252 <= signal_select_1489;
        11:
            signal_mux_252 <= signal_select_1488;
        12:
            signal_mux_252 <= signal_select_1487;
        13:
            signal_mux_252 <= signal_select_1486;
        14:
            signal_mux_252 <= signal_select_1485;
        default:
            signal_mux_252 <= signal_select_1484;
        endcase
    end
    assign signal_select_1501 = pin_dir_base[16:16];
    assign signal_cat_229 = { gnd,
                              signal_wire_15 };
    assign signal_cat_230 = { gnd,
                              signal_wire_32 };
    assign signal_sub_149 = signal_const_44 - signal_cat_230;
    assign signal_cat_231 = { gnd,
                              signal_wire_32 };
    assign signal_sub_150 = signal_const_45 - signal_cat_231;
    assign signal_lt_146 = signal_const_46 < signal_wire_32;
    assign signal_mux_253 = signal_lt_146 ? signal_sub_149 : signal_sub_150;
    assign signal_lt_147 = signal_mux_253 < signal_cat_229;
    assign signal_mux_254 = signal_lt_147 ? signal_mux_252 : signal_select_1501;
    assign signal_select_1502 = mov_value[15:15];
    assign signal_select_1503 = mov_value[14:14];
    assign signal_select_1504 = mov_value[13:13];
    assign signal_select_1505 = mov_value[12:12];
    assign signal_select_1506 = mov_value[11:11];
    assign signal_select_1507 = mov_value[10:10];
    assign signal_select_1508 = mov_value[9:9];
    assign signal_select_1509 = mov_value[8:8];
    assign signal_select_1510 = mov_value[7:7];
    assign signal_select_1511 = mov_value[6:6];
    assign signal_select_1512 = mov_value[5:5];
    assign signal_select_1513 = mov_value[4:4];
    assign signal_select_1514 = mov_value[3:3];
    assign signal_select_1515 = mov_value[2:2];
    assign signal_select_1516 = mov_value[1:1];
    assign signal_select_1517 = mov_value[0:0];
    assign signal_select_1518 = signal_mux_256[3:0];
    always @* begin
        case (signal_select_1518)
        0:
            signal_mux_255 <= signal_select_1517;
        1:
            signal_mux_255 <= signal_select_1516;
        2:
            signal_mux_255 <= signal_select_1515;
        3:
            signal_mux_255 <= signal_select_1514;
        4:
            signal_mux_255 <= signal_select_1513;
        5:
            signal_mux_255 <= signal_select_1512;
        6:
            signal_mux_255 <= signal_select_1511;
        7:
            signal_mux_255 <= signal_select_1510;
        8:
            signal_mux_255 <= signal_select_1509;
        9:
            signal_mux_255 <= signal_select_1508;
        10:
            signal_mux_255 <= signal_select_1507;
        11:
            signal_mux_255 <= signal_select_1506;
        12:
            signal_mux_255 <= signal_select_1505;
        13:
            signal_mux_255 <= signal_select_1504;
        14:
            signal_mux_255 <= signal_select_1503;
        default:
            signal_mux_255 <= signal_select_1502;
        endcase
    end
    assign signal_select_1519 = pin_dir_base[17:17];
    assign signal_cat_232 = { gnd,
                              signal_wire_15 };
    assign signal_cat_233 = { gnd,
                              signal_wire_32 };
    assign signal_sub_151 = signal_const_47 - signal_cat_233;
    assign signal_cat_234 = { gnd,
                              signal_wire_32 };
    assign signal_sub_152 = signal_const_48 - signal_cat_234;
    assign signal_lt_148 = signal_const_49 < signal_wire_32;
    assign signal_mux_256 = signal_lt_148 ? signal_sub_151 : signal_sub_152;
    assign signal_lt_149 = signal_mux_256 < signal_cat_232;
    assign signal_mux_257 = signal_lt_149 ? signal_mux_255 : signal_select_1519;
    assign signal_select_1520 = mov_value[15:15];
    assign signal_select_1521 = mov_value[14:14];
    assign signal_select_1522 = mov_value[13:13];
    assign signal_select_1523 = mov_value[12:12];
    assign signal_select_1524 = mov_value[11:11];
    assign signal_select_1525 = mov_value[10:10];
    assign signal_select_1526 = mov_value[9:9];
    assign signal_select_1527 = mov_value[8:8];
    assign signal_select_1528 = mov_value[7:7];
    assign signal_select_1529 = mov_value[6:6];
    assign signal_select_1530 = mov_value[5:5];
    assign signal_select_1531 = mov_value[4:4];
    assign signal_select_1532 = mov_value[3:3];
    assign signal_select_1533 = mov_value[2:2];
    assign signal_select_1534 = mov_value[1:1];
    assign signal_select_1535 = mov_value[0:0];
    assign signal_select_1536 = signal_mux_259[3:0];
    always @* begin
        case (signal_select_1536)
        0:
            signal_mux_258 <= signal_select_1535;
        1:
            signal_mux_258 <= signal_select_1534;
        2:
            signal_mux_258 <= signal_select_1533;
        3:
            signal_mux_258 <= signal_select_1532;
        4:
            signal_mux_258 <= signal_select_1531;
        5:
            signal_mux_258 <= signal_select_1530;
        6:
            signal_mux_258 <= signal_select_1529;
        7:
            signal_mux_258 <= signal_select_1528;
        8:
            signal_mux_258 <= signal_select_1527;
        9:
            signal_mux_258 <= signal_select_1526;
        10:
            signal_mux_258 <= signal_select_1525;
        11:
            signal_mux_258 <= signal_select_1524;
        12:
            signal_mux_258 <= signal_select_1523;
        13:
            signal_mux_258 <= signal_select_1522;
        14:
            signal_mux_258 <= signal_select_1521;
        default:
            signal_mux_258 <= signal_select_1520;
        endcase
    end
    assign signal_select_1537 = pin_dir_base[18:18];
    assign signal_cat_235 = { gnd,
                              signal_wire_15 };
    assign signal_cat_236 = { gnd,
                              signal_wire_32 };
    assign signal_sub_153 = signal_const_50 - signal_cat_236;
    assign signal_cat_237 = { gnd,
                              signal_wire_32 };
    assign signal_sub_154 = signal_const_51 - signal_cat_237;
    assign signal_lt_150 = signal_const_52 < signal_wire_32;
    assign signal_mux_259 = signal_lt_150 ? signal_sub_153 : signal_sub_154;
    assign signal_lt_151 = signal_mux_259 < signal_cat_235;
    assign signal_mux_260 = signal_lt_151 ? signal_mux_258 : signal_select_1537;
    assign signal_select_1538 = mov_value[15:15];
    assign signal_select_1539 = mov_value[14:14];
    assign signal_select_1540 = mov_value[13:13];
    assign signal_select_1541 = mov_value[12:12];
    assign signal_select_1542 = mov_value[11:11];
    assign signal_select_1543 = mov_value[10:10];
    assign signal_select_1544 = mov_value[9:9];
    assign signal_select_1545 = mov_value[8:8];
    assign signal_select_1546 = mov_value[7:7];
    assign signal_select_1547 = mov_value[6:6];
    assign signal_select_1548 = mov_value[5:5];
    assign signal_select_1549 = mov_value[4:4];
    assign signal_select_1550 = mov_value[3:3];
    assign signal_select_1551 = mov_value[2:2];
    assign signal_select_1552 = mov_value[1:1];
    assign signal_select_1553 = mov_value[0:0];
    assign signal_select_1554 = signal_mux_262[3:0];
    always @* begin
        case (signal_select_1554)
        0:
            signal_mux_261 <= signal_select_1553;
        1:
            signal_mux_261 <= signal_select_1552;
        2:
            signal_mux_261 <= signal_select_1551;
        3:
            signal_mux_261 <= signal_select_1550;
        4:
            signal_mux_261 <= signal_select_1549;
        5:
            signal_mux_261 <= signal_select_1548;
        6:
            signal_mux_261 <= signal_select_1547;
        7:
            signal_mux_261 <= signal_select_1546;
        8:
            signal_mux_261 <= signal_select_1545;
        9:
            signal_mux_261 <= signal_select_1544;
        10:
            signal_mux_261 <= signal_select_1543;
        11:
            signal_mux_261 <= signal_select_1542;
        12:
            signal_mux_261 <= signal_select_1541;
        13:
            signal_mux_261 <= signal_select_1540;
        14:
            signal_mux_261 <= signal_select_1539;
        default:
            signal_mux_261 <= signal_select_1538;
        endcase
    end
    assign signal_select_1555 = pin_dir_base[19:19];
    assign signal_wire_15 = config$out_count;
    assign signal_cat_238 = { gnd,
                              signal_wire_15 };
    assign signal_cat_239 = { gnd,
                              signal_wire_32 };
    assign signal_sub_155 = signal_const_54 - signal_cat_239;
    assign signal_cat_240 = { gnd,
                              signal_wire_32 };
    assign signal_sub_156 = signal_const_55 - signal_cat_240;
    assign signal_lt_152 = signal_const_56 < signal_wire_32;
    assign signal_mux_262 = signal_lt_152 ? signal_sub_155 : signal_sub_156;
    assign signal_lt_153 = signal_mux_262 < signal_cat_238;
    assign signal_mux_263 = signal_lt_153 ? signal_mux_261 : signal_select_1555;
    assign signal_cat_241 = { signal_mux_263,
                              signal_mux_260,
                              signal_mux_257,
                              signal_mux_254,
                              signal_mux_251,
                              signal_mux_248,
                              signal_mux_245,
                              signal_mux_242,
                              signal_select_1411,
                              signal_select_1410,
                              signal_select_1409,
                              signal_select_1408,
                              signal_select_1407,
                              signal_select_1406,
                              signal_select_1405,
                              signal_select_1404,
                              signal_select_1403,
                              signal_select_1402,
                              signal_select_1401,
                              signal_select_1400 };
    assign signal_eq_29 = d$mov_dest$binary_variant == signal_const_225;
    assign signal_mux_264 = signal_eq_29 ? signal_cat_241 : pin_dir_base;
    assign signal_select_1556 = pin_dir_base[0:0];
    assign signal_select_1557 = pin_dir_base[1:1];
    assign signal_select_1558 = pin_dir_base[2:2];
    assign signal_select_1559 = pin_dir_base[3:3];
    assign signal_select_1560 = pin_dir_base[4:4];
    assign signal_select_1561 = pin_dir_base[5:5];
    assign signal_select_1562 = pin_dir_base[6:6];
    assign signal_select_1563 = pin_dir_base[7:7];
    assign signal_select_1564 = pin_dir_base[8:8];
    assign signal_select_1565 = pin_dir_base[9:9];
    assign signal_select_1566 = pin_dir_base[10:10];
    assign signal_select_1567 = pin_dir_base[11:11];
    assign signal_select_1568 = out_value[15:15];
    assign signal_select_1569 = out_value[14:14];
    assign signal_select_1570 = out_value[13:13];
    assign signal_select_1571 = out_value[12:12];
    assign signal_select_1572 = out_value[11:11];
    assign signal_select_1573 = out_value[10:10];
    assign signal_select_1574 = out_value[9:9];
    assign signal_select_1575 = out_value[8:8];
    assign signal_select_1576 = out_value[7:7];
    assign signal_select_1577 = out_value[6:6];
    assign signal_select_1578 = out_value[5:5];
    assign signal_select_1579 = out_value[4:4];
    assign signal_select_1580 = out_value[3:3];
    assign signal_select_1581 = out_value[2:2];
    assign signal_select_1582 = out_value[1:1];
    assign signal_select_1583 = out_value[0:0];
    assign signal_select_1584 = signal_mux_266[3:0];
    always @* begin
        case (signal_select_1584)
        0:
            signal_mux_265 <= signal_select_1583;
        1:
            signal_mux_265 <= signal_select_1582;
        2:
            signal_mux_265 <= signal_select_1581;
        3:
            signal_mux_265 <= signal_select_1580;
        4:
            signal_mux_265 <= signal_select_1579;
        5:
            signal_mux_265 <= signal_select_1578;
        6:
            signal_mux_265 <= signal_select_1577;
        7:
            signal_mux_265 <= signal_select_1576;
        8:
            signal_mux_265 <= signal_select_1575;
        9:
            signal_mux_265 <= signal_select_1574;
        10:
            signal_mux_265 <= signal_select_1573;
        11:
            signal_mux_265 <= signal_select_1572;
        12:
            signal_mux_265 <= signal_select_1571;
        13:
            signal_mux_265 <= signal_select_1570;
        14:
            signal_mux_265 <= signal_select_1569;
        default:
            signal_mux_265 <= signal_select_1568;
        endcase
    end
    assign signal_select_1585 = pin_dir_base[12:12];
    assign signal_cat_242 = { gnd,
                              d$shift_count };
    assign signal_cat_243 = { gnd,
                              signal_wire_32 };
    assign signal_sub_157 = signal_const_32 - signal_cat_243;
    assign signal_cat_244 = { gnd,
                              signal_wire_32 };
    assign signal_sub_158 = signal_const_33 - signal_cat_244;
    assign signal_lt_154 = signal_const_34 < signal_wire_32;
    assign signal_mux_266 = signal_lt_154 ? signal_sub_157 : signal_sub_158;
    assign signal_lt_155 = signal_mux_266 < signal_cat_242;
    assign signal_mux_267 = signal_lt_155 ? signal_mux_265 : signal_select_1585;
    assign signal_select_1586 = out_value[15:15];
    assign signal_select_1587 = out_value[14:14];
    assign signal_select_1588 = out_value[13:13];
    assign signal_select_1589 = out_value[12:12];
    assign signal_select_1590 = out_value[11:11];
    assign signal_select_1591 = out_value[10:10];
    assign signal_select_1592 = out_value[9:9];
    assign signal_select_1593 = out_value[8:8];
    assign signal_select_1594 = out_value[7:7];
    assign signal_select_1595 = out_value[6:6];
    assign signal_select_1596 = out_value[5:5];
    assign signal_select_1597 = out_value[4:4];
    assign signal_select_1598 = out_value[3:3];
    assign signal_select_1599 = out_value[2:2];
    assign signal_select_1600 = out_value[1:1];
    assign signal_select_1601 = out_value[0:0];
    assign signal_select_1602 = signal_mux_269[3:0];
    always @* begin
        case (signal_select_1602)
        0:
            signal_mux_268 <= signal_select_1601;
        1:
            signal_mux_268 <= signal_select_1600;
        2:
            signal_mux_268 <= signal_select_1599;
        3:
            signal_mux_268 <= signal_select_1598;
        4:
            signal_mux_268 <= signal_select_1597;
        5:
            signal_mux_268 <= signal_select_1596;
        6:
            signal_mux_268 <= signal_select_1595;
        7:
            signal_mux_268 <= signal_select_1594;
        8:
            signal_mux_268 <= signal_select_1593;
        9:
            signal_mux_268 <= signal_select_1592;
        10:
            signal_mux_268 <= signal_select_1591;
        11:
            signal_mux_268 <= signal_select_1590;
        12:
            signal_mux_268 <= signal_select_1589;
        13:
            signal_mux_268 <= signal_select_1588;
        14:
            signal_mux_268 <= signal_select_1587;
        default:
            signal_mux_268 <= signal_select_1586;
        endcase
    end
    assign signal_select_1603 = pin_dir_base[13:13];
    assign signal_cat_245 = { gnd,
                              d$shift_count };
    assign signal_cat_246 = { gnd,
                              signal_wire_32 };
    assign signal_sub_159 = signal_const_35 - signal_cat_246;
    assign signal_cat_247 = { gnd,
                              signal_wire_32 };
    assign signal_sub_160 = signal_const_36 - signal_cat_247;
    assign signal_lt_156 = signal_const_37 < signal_wire_32;
    assign signal_mux_269 = signal_lt_156 ? signal_sub_159 : signal_sub_160;
    assign signal_lt_157 = signal_mux_269 < signal_cat_245;
    assign signal_mux_270 = signal_lt_157 ? signal_mux_268 : signal_select_1603;
    assign signal_select_1604 = out_value[15:15];
    assign signal_select_1605 = out_value[14:14];
    assign signal_select_1606 = out_value[13:13];
    assign signal_select_1607 = out_value[12:12];
    assign signal_select_1608 = out_value[11:11];
    assign signal_select_1609 = out_value[10:10];
    assign signal_select_1610 = out_value[9:9];
    assign signal_select_1611 = out_value[8:8];
    assign signal_select_1612 = out_value[7:7];
    assign signal_select_1613 = out_value[6:6];
    assign signal_select_1614 = out_value[5:5];
    assign signal_select_1615 = out_value[4:4];
    assign signal_select_1616 = out_value[3:3];
    assign signal_select_1617 = out_value[2:2];
    assign signal_select_1618 = out_value[1:1];
    assign signal_select_1619 = out_value[0:0];
    assign signal_select_1620 = signal_mux_272[3:0];
    always @* begin
        case (signal_select_1620)
        0:
            signal_mux_271 <= signal_select_1619;
        1:
            signal_mux_271 <= signal_select_1618;
        2:
            signal_mux_271 <= signal_select_1617;
        3:
            signal_mux_271 <= signal_select_1616;
        4:
            signal_mux_271 <= signal_select_1615;
        5:
            signal_mux_271 <= signal_select_1614;
        6:
            signal_mux_271 <= signal_select_1613;
        7:
            signal_mux_271 <= signal_select_1612;
        8:
            signal_mux_271 <= signal_select_1611;
        9:
            signal_mux_271 <= signal_select_1610;
        10:
            signal_mux_271 <= signal_select_1609;
        11:
            signal_mux_271 <= signal_select_1608;
        12:
            signal_mux_271 <= signal_select_1607;
        13:
            signal_mux_271 <= signal_select_1606;
        14:
            signal_mux_271 <= signal_select_1605;
        default:
            signal_mux_271 <= signal_select_1604;
        endcase
    end
    assign signal_select_1621 = pin_dir_base[14:14];
    assign signal_cat_248 = { gnd,
                              d$shift_count };
    assign signal_cat_249 = { gnd,
                              signal_wire_32 };
    assign signal_sub_161 = signal_const_38 - signal_cat_249;
    assign signal_cat_250 = { gnd,
                              signal_wire_32 };
    assign signal_sub_162 = signal_const_39 - signal_cat_250;
    assign signal_lt_158 = signal_const_40 < signal_wire_32;
    assign signal_mux_272 = signal_lt_158 ? signal_sub_161 : signal_sub_162;
    assign signal_lt_159 = signal_mux_272 < signal_cat_248;
    assign signal_mux_273 = signal_lt_159 ? signal_mux_271 : signal_select_1621;
    assign signal_select_1622 = out_value[15:15];
    assign signal_select_1623 = out_value[14:14];
    assign signal_select_1624 = out_value[13:13];
    assign signal_select_1625 = out_value[12:12];
    assign signal_select_1626 = out_value[11:11];
    assign signal_select_1627 = out_value[10:10];
    assign signal_select_1628 = out_value[9:9];
    assign signal_select_1629 = out_value[8:8];
    assign signal_select_1630 = out_value[7:7];
    assign signal_select_1631 = out_value[6:6];
    assign signal_select_1632 = out_value[5:5];
    assign signal_select_1633 = out_value[4:4];
    assign signal_select_1634 = out_value[3:3];
    assign signal_select_1635 = out_value[2:2];
    assign signal_select_1636 = out_value[1:1];
    assign signal_select_1637 = out_value[0:0];
    assign signal_select_1638 = signal_mux_275[3:0];
    always @* begin
        case (signal_select_1638)
        0:
            signal_mux_274 <= signal_select_1637;
        1:
            signal_mux_274 <= signal_select_1636;
        2:
            signal_mux_274 <= signal_select_1635;
        3:
            signal_mux_274 <= signal_select_1634;
        4:
            signal_mux_274 <= signal_select_1633;
        5:
            signal_mux_274 <= signal_select_1632;
        6:
            signal_mux_274 <= signal_select_1631;
        7:
            signal_mux_274 <= signal_select_1630;
        8:
            signal_mux_274 <= signal_select_1629;
        9:
            signal_mux_274 <= signal_select_1628;
        10:
            signal_mux_274 <= signal_select_1627;
        11:
            signal_mux_274 <= signal_select_1626;
        12:
            signal_mux_274 <= signal_select_1625;
        13:
            signal_mux_274 <= signal_select_1624;
        14:
            signal_mux_274 <= signal_select_1623;
        default:
            signal_mux_274 <= signal_select_1622;
        endcase
    end
    assign signal_select_1639 = pin_dir_base[15:15];
    assign signal_cat_251 = { gnd,
                              d$shift_count };
    assign signal_cat_252 = { gnd,
                              signal_wire_32 };
    assign signal_sub_163 = signal_const_41 - signal_cat_252;
    assign signal_cat_253 = { gnd,
                              signal_wire_32 };
    assign signal_sub_164 = signal_const_42 - signal_cat_253;
    assign signal_lt_160 = signal_const_43 < signal_wire_32;
    assign signal_mux_275 = signal_lt_160 ? signal_sub_163 : signal_sub_164;
    assign signal_lt_161 = signal_mux_275 < signal_cat_251;
    assign signal_mux_276 = signal_lt_161 ? signal_mux_274 : signal_select_1639;
    assign signal_select_1640 = out_value[15:15];
    assign signal_select_1641 = out_value[14:14];
    assign signal_select_1642 = out_value[13:13];
    assign signal_select_1643 = out_value[12:12];
    assign signal_select_1644 = out_value[11:11];
    assign signal_select_1645 = out_value[10:10];
    assign signal_select_1646 = out_value[9:9];
    assign signal_select_1647 = out_value[8:8];
    assign signal_select_1648 = out_value[7:7];
    assign signal_select_1649 = out_value[6:6];
    assign signal_select_1650 = out_value[5:5];
    assign signal_select_1651 = out_value[4:4];
    assign signal_select_1652 = out_value[3:3];
    assign signal_select_1653 = out_value[2:2];
    assign signal_select_1654 = out_value[1:1];
    assign signal_select_1655 = out_value[0:0];
    assign signal_select_1656 = signal_mux_278[3:0];
    always @* begin
        case (signal_select_1656)
        0:
            signal_mux_277 <= signal_select_1655;
        1:
            signal_mux_277 <= signal_select_1654;
        2:
            signal_mux_277 <= signal_select_1653;
        3:
            signal_mux_277 <= signal_select_1652;
        4:
            signal_mux_277 <= signal_select_1651;
        5:
            signal_mux_277 <= signal_select_1650;
        6:
            signal_mux_277 <= signal_select_1649;
        7:
            signal_mux_277 <= signal_select_1648;
        8:
            signal_mux_277 <= signal_select_1647;
        9:
            signal_mux_277 <= signal_select_1646;
        10:
            signal_mux_277 <= signal_select_1645;
        11:
            signal_mux_277 <= signal_select_1644;
        12:
            signal_mux_277 <= signal_select_1643;
        13:
            signal_mux_277 <= signal_select_1642;
        14:
            signal_mux_277 <= signal_select_1641;
        default:
            signal_mux_277 <= signal_select_1640;
        endcase
    end
    assign signal_select_1657 = pin_dir_base[16:16];
    assign signal_cat_254 = { gnd,
                              d$shift_count };
    assign signal_cat_255 = { gnd,
                              signal_wire_32 };
    assign signal_sub_165 = signal_const_44 - signal_cat_255;
    assign signal_cat_256 = { gnd,
                              signal_wire_32 };
    assign signal_sub_166 = signal_const_45 - signal_cat_256;
    assign signal_lt_162 = signal_const_46 < signal_wire_32;
    assign signal_mux_278 = signal_lt_162 ? signal_sub_165 : signal_sub_166;
    assign signal_lt_163 = signal_mux_278 < signal_cat_254;
    assign signal_mux_279 = signal_lt_163 ? signal_mux_277 : signal_select_1657;
    assign signal_select_1658 = out_value[15:15];
    assign signal_select_1659 = out_value[14:14];
    assign signal_select_1660 = out_value[13:13];
    assign signal_select_1661 = out_value[12:12];
    assign signal_select_1662 = out_value[11:11];
    assign signal_select_1663 = out_value[10:10];
    assign signal_select_1664 = out_value[9:9];
    assign signal_select_1665 = out_value[8:8];
    assign signal_select_1666 = out_value[7:7];
    assign signal_select_1667 = out_value[6:6];
    assign signal_select_1668 = out_value[5:5];
    assign signal_select_1669 = out_value[4:4];
    assign signal_select_1670 = out_value[3:3];
    assign signal_select_1671 = out_value[2:2];
    assign signal_select_1672 = out_value[1:1];
    assign signal_select_1673 = out_value[0:0];
    assign signal_select_1674 = signal_mux_281[3:0];
    always @* begin
        case (signal_select_1674)
        0:
            signal_mux_280 <= signal_select_1673;
        1:
            signal_mux_280 <= signal_select_1672;
        2:
            signal_mux_280 <= signal_select_1671;
        3:
            signal_mux_280 <= signal_select_1670;
        4:
            signal_mux_280 <= signal_select_1669;
        5:
            signal_mux_280 <= signal_select_1668;
        6:
            signal_mux_280 <= signal_select_1667;
        7:
            signal_mux_280 <= signal_select_1666;
        8:
            signal_mux_280 <= signal_select_1665;
        9:
            signal_mux_280 <= signal_select_1664;
        10:
            signal_mux_280 <= signal_select_1663;
        11:
            signal_mux_280 <= signal_select_1662;
        12:
            signal_mux_280 <= signal_select_1661;
        13:
            signal_mux_280 <= signal_select_1660;
        14:
            signal_mux_280 <= signal_select_1659;
        default:
            signal_mux_280 <= signal_select_1658;
        endcase
    end
    assign signal_select_1675 = pin_dir_base[17:17];
    assign signal_cat_257 = { gnd,
                              d$shift_count };
    assign signal_cat_258 = { gnd,
                              signal_wire_32 };
    assign signal_sub_167 = signal_const_47 - signal_cat_258;
    assign signal_cat_259 = { gnd,
                              signal_wire_32 };
    assign signal_sub_168 = signal_const_48 - signal_cat_259;
    assign signal_lt_164 = signal_const_49 < signal_wire_32;
    assign signal_mux_281 = signal_lt_164 ? signal_sub_167 : signal_sub_168;
    assign signal_lt_165 = signal_mux_281 < signal_cat_257;
    assign signal_mux_282 = signal_lt_165 ? signal_mux_280 : signal_select_1675;
    assign signal_select_1676 = out_value[15:15];
    assign signal_select_1677 = out_value[14:14];
    assign signal_select_1678 = out_value[13:13];
    assign signal_select_1679 = out_value[12:12];
    assign signal_select_1680 = out_value[11:11];
    assign signal_select_1681 = out_value[10:10];
    assign signal_select_1682 = out_value[9:9];
    assign signal_select_1683 = out_value[8:8];
    assign signal_select_1684 = out_value[7:7];
    assign signal_select_1685 = out_value[6:6];
    assign signal_select_1686 = out_value[5:5];
    assign signal_select_1687 = out_value[4:4];
    assign signal_select_1688 = out_value[3:3];
    assign signal_select_1689 = out_value[2:2];
    assign signal_select_1690 = out_value[1:1];
    assign signal_select_1691 = out_value[0:0];
    assign signal_select_1692 = signal_mux_284[3:0];
    always @* begin
        case (signal_select_1692)
        0:
            signal_mux_283 <= signal_select_1691;
        1:
            signal_mux_283 <= signal_select_1690;
        2:
            signal_mux_283 <= signal_select_1689;
        3:
            signal_mux_283 <= signal_select_1688;
        4:
            signal_mux_283 <= signal_select_1687;
        5:
            signal_mux_283 <= signal_select_1686;
        6:
            signal_mux_283 <= signal_select_1685;
        7:
            signal_mux_283 <= signal_select_1684;
        8:
            signal_mux_283 <= signal_select_1683;
        9:
            signal_mux_283 <= signal_select_1682;
        10:
            signal_mux_283 <= signal_select_1681;
        11:
            signal_mux_283 <= signal_select_1680;
        12:
            signal_mux_283 <= signal_select_1679;
        13:
            signal_mux_283 <= signal_select_1678;
        14:
            signal_mux_283 <= signal_select_1677;
        default:
            signal_mux_283 <= signal_select_1676;
        endcase
    end
    assign signal_select_1693 = pin_dir_base[18:18];
    assign signal_cat_260 = { gnd,
                              d$shift_count };
    assign signal_cat_261 = { gnd,
                              signal_wire_32 };
    assign signal_sub_169 = signal_const_50 - signal_cat_261;
    assign signal_cat_262 = { gnd,
                              signal_wire_32 };
    assign signal_sub_170 = signal_const_51 - signal_cat_262;
    assign signal_lt_166 = signal_const_52 < signal_wire_32;
    assign signal_mux_284 = signal_lt_166 ? signal_sub_169 : signal_sub_170;
    assign signal_lt_167 = signal_mux_284 < signal_cat_260;
    assign signal_mux_285 = signal_lt_167 ? signal_mux_283 : signal_select_1693;
    assign signal_select_1694 = out_value[15:15];
    assign signal_select_1695 = out_value[14:14];
    assign signal_select_1696 = out_value[13:13];
    assign signal_select_1697 = out_value[12:12];
    assign signal_select_1698 = out_value[11:11];
    assign signal_select_1699 = out_value[10:10];
    assign signal_select_1700 = out_value[9:9];
    assign signal_select_1701 = out_value[8:8];
    assign signal_select_1702 = out_value[7:7];
    assign signal_select_1703 = out_value[6:6];
    assign signal_select_1704 = out_value[5:5];
    assign signal_select_1705 = out_value[4:4];
    assign signal_select_1706 = out_value[3:3];
    assign signal_select_1707 = out_value[2:2];
    assign signal_select_1708 = out_value[1:1];
    assign signal_and_25 = osr_before & mask;
    assign signal_select_1709 = signal_mux_431[15:8];
    assign signal_cat_263 = { signal_const_227,
                              signal_select_1709 };
    assign signal_select_1710 = signal_mux_430[15:4];
    assign signal_const_310 = 4'b0000;
    assign signal_cat_264 = { signal_const_310,
                              signal_select_1710 };
    assign signal_select_1711 = signal_mux_429[15:2];
    assign signal_cat_265 = { signal_const_257,
                              signal_select_1711 };
    assign signal_select_1712 = osr_before[15:1];
    assign signal_cat_266 = { signal_const_3,
                              signal_select_1712 };
    assign signal_select_1713 = signal_inst_1[15:0];
    assign signal_not_16 = ~ signal_select_2547;
    assign signal_and_26 = pulls & signal_not_16;
    assign signal_mux_286 = signal_and_26 ? signal_select_1713 : osr_0;
    assign signal_select_1714 = signal_select_2528[15:15];
    assign signal_select_1715 = signal_select_2528[14:14];
    assign signal_select_1716 = signal_select_2528[13:13];
    assign signal_select_1717 = signal_select_2528[12:12];
    assign signal_select_1718 = signal_select_2528[11:11];
    assign signal_select_1719 = signal_select_2528[10:10];
    assign signal_select_1720 = signal_select_2528[9:9];
    assign signal_select_1721 = signal_select_2528[8:8];
    assign signal_select_1722 = signal_select_2528[7:7];
    assign signal_select_1723 = signal_select_2528[6:6];
    assign signal_select_1724 = signal_select_2528[5:5];
    assign signal_select_1725 = signal_select_2528[4:4];
    assign signal_select_1726 = signal_select_2528[3:3];
    assign signal_select_1727 = signal_select_2528[2:2];
    assign signal_select_1728 = signal_select_2528[1:1];
    assign signal_select_1729 = signal_select_2528[0:0];
    assign signal_cat_267 = { signal_select_1729,
                              signal_select_1728,
                              signal_select_1727,
                              signal_select_1726,
                              signal_select_1725,
                              signal_select_1724,
                              signal_select_1723,
                              signal_select_1722,
                              signal_select_1721,
                              signal_select_1720,
                              signal_select_1719,
                              signal_select_1718,
                              signal_select_1717,
                              signal_select_1716,
                              signal_select_1715,
                              signal_select_1714 };
    assign signal_not_17 = ~ signal_select_2528;
    assign signal_cat_268 = { signal_const_227,
                              osr_0 };
    assign signal_cat_269 = { signal_const_227,
                              isr_0 };
    assign signal_cat_270 = { signal_const_227,
                              y_0 };
    assign signal_xor_1 = x_0 ^ alu_operand;
    assign signal_sub_171 = x_0 - alu_operand;
    assign signal_eq_30 = d$sys_op$binary_variant == signal_const_225;
    assign signal_and_27 = is_opcode$7 & signal_eq_30;
    assign signal_mux_287 = signal_and_27 ? signal_const_196 : isr_0;
    assign signal_eq_31 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_288 = signal_eq_31 ? mov_value : isr_0;
    assign signal_eq_32 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_289 = signal_eq_32 ? out_value : isr_0;
    assign signal_select_1730 = signal_mux_292[7:0];
    assign signal_cat_271 = { signal_select_1730,
                              signal_const_227 };
    assign signal_select_1731 = signal_mux_291[11:0];
    assign signal_cat_272 = { signal_select_1731,
                              signal_const_310 };
    assign signal_select_1732 = signal_mux_290[13:0];
    assign signal_cat_273 = { signal_select_1732,
                              signal_const_257 };
    assign signal_select_1733 = in_value[14:0];
    assign signal_cat_274 = { signal_select_1733,
                              signal_const_3 };
    assign signal_select_1734 = shift_back[0:0];
    assign signal_mux_290 = signal_select_1734 ? signal_cat_274 : in_value;
    assign signal_select_1735 = shift_back[1:1];
    assign signal_mux_291 = signal_select_1735 ? signal_cat_273 : signal_mux_290;
    assign signal_select_1736 = shift_back[2:2];
    assign signal_mux_292 = signal_select_1736 ? signal_cat_272 : signal_mux_291;
    assign signal_select_1737 = shift_back[3:3];
    assign signal_mux_293 = signal_select_1737 ? signal_cat_271 : signal_mux_292;
    assign signal_select_1738 = shift_back[4:4];
    assign signal_mux_294 = signal_select_1738 ? signal_const_196 : signal_mux_293;
    assign signal_select_1739 = signal_mux_297[15:8];
    assign signal_cat_275 = { signal_const_227,
                              signal_select_1739 };
    assign signal_select_1740 = signal_mux_296[15:4];
    assign signal_cat_276 = { signal_const_310,
                              signal_select_1740 };
    assign signal_select_1741 = signal_mux_295[15:2];
    assign signal_cat_277 = { signal_const_257,
                              signal_select_1741 };
    assign signal_select_1742 = isr_0[15:1];
    assign signal_cat_278 = { signal_const_3,
                              signal_select_1742 };
    assign signal_select_1743 = d$shift_count[0:0];
    assign signal_mux_295 = signal_select_1743 ? signal_cat_278 : isr_0;
    assign signal_select_1744 = d$shift_count[1:1];
    assign signal_mux_296 = signal_select_1744 ? signal_cat_277 : signal_mux_295;
    assign signal_select_1745 = d$shift_count[2:2];
    assign signal_mux_297 = signal_select_1745 ? signal_cat_276 : signal_mux_296;
    assign signal_select_1746 = d$shift_count[3:3];
    assign signal_mux_298 = signal_select_1746 ? signal_cat_275 : signal_mux_297;
    assign signal_select_1747 = d$shift_count[4:4];
    assign signal_mux_299 = signal_select_1747 ? signal_const_196 : signal_mux_298;
    assign signal_or_2 = signal_mux_299 | signal_mux_294;
    assign signal_select_1748 = signal_mux_302[7:0];
    assign signal_cat_279 = { signal_select_1748,
                              signal_const_227 };
    assign signal_select_1749 = signal_mux_301[11:0];
    assign signal_cat_280 = { signal_select_1749,
                              signal_const_310 };
    assign signal_select_1750 = signal_mux_300[13:0];
    assign signal_cat_281 = { signal_select_1750,
                              signal_const_257 };
    assign signal_const_339 = 16'b1111111111111110;
    assign signal_select_1751 = d$shift_count[0:0];
    assign signal_mux_300 = signal_select_1751 ? signal_const_339 : signal_const_197;
    assign signal_select_1752 = d$shift_count[1:1];
    assign signal_mux_301 = signal_select_1752 ? signal_cat_281 : signal_mux_300;
    assign signal_select_1753 = d$shift_count[2:2];
    assign signal_mux_302 = signal_select_1753 ? signal_cat_280 : signal_mux_301;
    assign signal_select_1754 = d$shift_count[3:3];
    assign signal_mux_303 = signal_select_1754 ? signal_cat_279 : signal_mux_302;
    assign signal_select_1755 = d$shift_count[4:4];
    assign signal_mux_304 = signal_select_1755 ? signal_const_196 : signal_mux_303;
    assign mask = ~ signal_mux_304;
    assign signal_wire_16 = config$capture_rising;
    assign signal_select_1756 = sample[19:19];
    assign signal_select_1757 = sample[18:18];
    assign signal_select_1758 = sample[17:17];
    assign signal_select_1759 = sample[16:16];
    assign signal_select_1760 = sample[15:15];
    assign signal_select_1761 = sample[14:14];
    assign signal_select_1762 = sample[13:13];
    assign signal_select_1763 = sample[12:12];
    assign signal_select_1764 = sample[11:11];
    assign signal_select_1765 = sample[10:10];
    assign signal_select_1766 = sample[9:9];
    assign signal_select_1767 = sample[8:8];
    assign signal_select_1768 = sample[7:7];
    assign signal_select_1769 = sample[6:6];
    assign signal_select_1770 = sample[5:5];
    assign signal_select_1771 = sample[4:4];
    assign signal_select_1772 = sample[3:3];
    assign signal_select_1773 = sample[2:2];
    assign signal_select_1774 = sample[1:1];
    assign signal_select_1775 = sample[0:0];
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_305 <= signal_select_1775;
        1:
            signal_mux_305 <= signal_select_1774;
        2:
            signal_mux_305 <= signal_select_1773;
        3:
            signal_mux_305 <= signal_select_1772;
        4:
            signal_mux_305 <= signal_select_1771;
        5:
            signal_mux_305 <= signal_select_1770;
        6:
            signal_mux_305 <= signal_select_1769;
        7:
            signal_mux_305 <= signal_select_1768;
        8:
            signal_mux_305 <= signal_select_1767;
        9:
            signal_mux_305 <= signal_select_1766;
        10:
            signal_mux_305 <= signal_select_1765;
        11:
            signal_mux_305 <= signal_select_1764;
        12:
            signal_mux_305 <= signal_select_1763;
        13:
            signal_mux_305 <= signal_select_1762;
        14:
            signal_mux_305 <= signal_select_1761;
        15:
            signal_mux_305 <= signal_select_1760;
        16:
            signal_mux_305 <= signal_select_1759;
        17:
            signal_mux_305 <= signal_select_1758;
        18:
            signal_mux_305 <= signal_select_1757;
        default:
            signal_mux_305 <= signal_select_1756;
        endcase
    end
    assign signal_eq_33 = signal_mux_305 == signal_wire_16;
    assign signal_select_1776 = pins_sampled[19:19];
    assign signal_select_1777 = pins_sampled[18:18];
    assign signal_select_1778 = pins_sampled[17:17];
    assign signal_select_1779 = pins_sampled[16:16];
    assign signal_select_1780 = pins_sampled[15:15];
    assign signal_select_1781 = pins_sampled[14:14];
    assign signal_select_1782 = pins_sampled[13:13];
    assign signal_select_1783 = pins_sampled[12:12];
    assign signal_select_1784 = pins_sampled[11:11];
    assign signal_select_1785 = pins_sampled[10:10];
    assign signal_select_1786 = pins_sampled[9:9];
    assign signal_select_1787 = pins_sampled[8:8];
    assign signal_select_1788 = pins_sampled[7:7];
    assign signal_select_1789 = pins_sampled[6:6];
    assign signal_select_1790 = pins_sampled[5:5];
    assign signal_select_1791 = pins_sampled[4:4];
    assign signal_select_1792 = pins_sampled[3:3];
    assign signal_select_1793 = pins_sampled[2:2];
    assign signal_select_1794 = pins_sampled[1:1];
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_8 <= signal_const_10;
        else
            signal_reg_8 <= sample;
    end
    assign pins_sampled = signal_reg_8;
    assign signal_select_1795 = pins_sampled[0:0];
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_306 <= signal_select_1795;
        1:
            signal_mux_306 <= signal_select_1794;
        2:
            signal_mux_306 <= signal_select_1793;
        3:
            signal_mux_306 <= signal_select_1792;
        4:
            signal_mux_306 <= signal_select_1791;
        5:
            signal_mux_306 <= signal_select_1790;
        6:
            signal_mux_306 <= signal_select_1789;
        7:
            signal_mux_306 <= signal_select_1788;
        8:
            signal_mux_306 <= signal_select_1787;
        9:
            signal_mux_306 <= signal_select_1786;
        10:
            signal_mux_306 <= signal_select_1785;
        11:
            signal_mux_306 <= signal_select_1784;
        12:
            signal_mux_306 <= signal_select_1783;
        13:
            signal_mux_306 <= signal_select_1782;
        14:
            signal_mux_306 <= signal_select_1781;
        15:
            signal_mux_306 <= signal_select_1780;
        16:
            signal_mux_306 <= signal_select_1779;
        17:
            signal_mux_306 <= signal_select_1778;
        18:
            signal_mux_306 <= signal_select_1777;
        default:
            signal_mux_306 <= signal_select_1776;
        endcase
    end
    assign signal_select_1796 = sample[19:19];
    assign signal_select_1797 = sample[18:18];
    assign signal_select_1798 = sample[17:17];
    assign signal_select_1799 = sample[16:16];
    assign signal_select_1800 = sample[15:15];
    assign signal_select_1801 = sample[14:14];
    assign signal_select_1802 = sample[13:13];
    assign signal_select_1803 = sample[12:12];
    assign signal_select_1804 = sample[11:11];
    assign signal_select_1805 = sample[10:10];
    assign signal_select_1806 = sample[9:9];
    assign signal_select_1807 = sample[8:8];
    assign signal_select_1808 = sample[7:7];
    assign signal_select_1809 = sample[6:6];
    assign signal_select_1810 = sample[5:5];
    assign signal_select_1811 = sample[4:4];
    assign signal_select_1812 = sample[3:3];
    assign signal_select_1813 = sample[2:2];
    assign signal_select_1814 = sample[1:1];
    assign signal_select_1815 = sample[0:0];
    assign signal_wire_17 = config$capture_pin;
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_307 <= signal_select_1815;
        1:
            signal_mux_307 <= signal_select_1814;
        2:
            signal_mux_307 <= signal_select_1813;
        3:
            signal_mux_307 <= signal_select_1812;
        4:
            signal_mux_307 <= signal_select_1811;
        5:
            signal_mux_307 <= signal_select_1810;
        6:
            signal_mux_307 <= signal_select_1809;
        7:
            signal_mux_307 <= signal_select_1808;
        8:
            signal_mux_307 <= signal_select_1807;
        9:
            signal_mux_307 <= signal_select_1806;
        10:
            signal_mux_307 <= signal_select_1805;
        11:
            signal_mux_307 <= signal_select_1804;
        12:
            signal_mux_307 <= signal_select_1803;
        13:
            signal_mux_307 <= signal_select_1802;
        14:
            signal_mux_307 <= signal_select_1801;
        15:
            signal_mux_307 <= signal_select_1800;
        16:
            signal_mux_307 <= signal_select_1799;
        17:
            signal_mux_307 <= signal_select_1798;
        18:
            signal_mux_307 <= signal_select_1797;
        default:
            signal_mux_307 <= signal_select_1796;
        endcase
    end
    assign signal_eq_34 = signal_mux_307 == signal_mux_306;
    assign signal_not_18 = ~ signal_eq_34;
    assign signal_eq_35 = d$sys_op$binary_variant == signal_const_229;
    assign signal_and_28 = is_opcode$7 & signal_eq_35;
    assign signal_and_29 = op_go & signal_and_28;
    assign signal_mux_308 = signal_and_29 ? vdd : capture_armed_0;
    assign signal_mux_309 = captured ? gnd : signal_mux_308;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_9 <= signal_const_3;
        else
            signal_reg_9 <= signal_mux_309;
    end
    assign capture_armed_0 = signal_reg_9;
    assign signal_and_30 = capture_armed_0 & signal_not_18;
    assign captured = signal_and_30 & signal_eq_33;
    assign signal_const_347 = 24'b000000000000000000000001;
    assign signal_add_5 = now_0 + signal_const_347;
    assign signal_mux_310 = start_0 ? signal_const_4 : signal_add_5;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_10 <= signal_const_4;
        else
            signal_reg_10 <= signal_mux_310;
    end
    assign now_0 = signal_reg_10;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_11 <= signal_const_4;
        else
            if (captured)
                signal_reg_11 <= now_0;
    end
    assign capture_0 = signal_reg_11;
    assign signal_select_1816 = capture_0[15:0];
    assign signal_wire_18 = config$crc_init;
    assign signal_select_1817 = signal_mux_313[7:0];
    assign signal_cat_282 = { signal_select_1817,
                              signal_const_227 };
    assign signal_select_1818 = signal_mux_312[11:0];
    assign signal_cat_283 = { signal_select_1818,
                              signal_const_310 };
    assign signal_select_1819 = signal_mux_311[13:0];
    assign signal_cat_284 = { signal_select_1819,
                              signal_const_257 };
    assign signal_select_1820 = signal_wire_20[0:0];
    assign signal_mux_311 = signal_select_1820 ? signal_const_339 : signal_const_197;
    assign signal_select_1821 = signal_wire_20[1:1];
    assign signal_mux_312 = signal_select_1821 ? signal_cat_284 : signal_mux_311;
    assign signal_select_1822 = signal_wire_20[2:2];
    assign signal_mux_313 = signal_select_1822 ? signal_cat_283 : signal_mux_312;
    assign signal_select_1823 = signal_wire_20[3:3];
    assign signal_mux_314 = signal_select_1823 ? signal_cat_282 : signal_mux_313;
    assign signal_select_1824 = signal_wire_20[4:4];
    assign signal_mux_315 = signal_select_1824 ? signal_const_196 : signal_mux_314;
    assign signal_not_19 = ~ signal_mux_315;
    assign signal_xor_2 = signal_cat_285 ^ signal_wire_19;
    assign signal_select_1825 = crc_0[15:1];
    assign signal_cat_285 = { signal_const_3,
                              signal_select_1825 };
    assign signal_select_1826 = crc_0[0:0];
    assign signal_xor_3 = signal_select_1826 ^ crossing_bit;
    assign signal_mux_316 = signal_xor_3 ? signal_xor_2 : signal_cat_285;
    assign signal_wire_19 = config$crc_poly;
    assign signal_xor_4 = signal_cat_286 ^ signal_wire_19;
    assign signal_select_1827 = crc_0[14:0];
    assign signal_cat_286 = { signal_select_1827,
                              signal_const_3 };
    assign signal_select_1828 = in_value[0:0];
    assign signal_select_1829 = out_value[0:0];
    assign crossing_bit = is_opcode$2 ? signal_select_1828 : signal_select_1829;
    assign signal_select_1830 = crc_0[15:15];
    assign signal_select_1831 = crc_0[14:14];
    assign signal_select_1832 = crc_0[13:13];
    assign signal_select_1833 = crc_0[12:12];
    assign signal_select_1834 = crc_0[11:11];
    assign signal_select_1835 = crc_0[10:10];
    assign signal_select_1836 = crc_0[9:9];
    assign signal_select_1837 = crc_0[8:8];
    assign signal_select_1838 = crc_0[7:7];
    assign signal_select_1839 = crc_0[6:6];
    assign signal_select_1840 = crc_0[5:5];
    assign signal_select_1841 = crc_0[4:4];
    assign signal_select_1842 = crc_0[3:3];
    assign signal_select_1843 = crc_0[2:2];
    assign signal_select_1844 = crc_0[1:1];
    assign signal_select_1845 = crc_0[0:0];
    assign signal_wire_20 = config$crc_width;
    assign signal_sub_172 = signal_wire_20 - signal_const_208;
    always @* begin
        case (signal_sub_172)
        0:
            signal_mux_317 <= signal_select_1845;
        1:
            signal_mux_317 <= signal_select_1844;
        2:
            signal_mux_317 <= signal_select_1843;
        3:
            signal_mux_317 <= signal_select_1842;
        4:
            signal_mux_317 <= signal_select_1841;
        5:
            signal_mux_317 <= signal_select_1840;
        6:
            signal_mux_317 <= signal_select_1839;
        7:
            signal_mux_317 <= signal_select_1838;
        8:
            signal_mux_317 <= signal_select_1837;
        9:
            signal_mux_317 <= signal_select_1836;
        10:
            signal_mux_317 <= signal_select_1835;
        11:
            signal_mux_317 <= signal_select_1834;
        12:
            signal_mux_317 <= signal_select_1833;
        13:
            signal_mux_317 <= signal_select_1832;
        14:
            signal_mux_317 <= signal_select_1831;
        default:
            signal_mux_317 <= signal_select_1830;
        endcase
    end
    assign signal_xor_5 = signal_mux_317 ^ crossing_bit;
    assign signal_mux_318 = signal_xor_5 ? signal_xor_4 : signal_cat_286;
    assign signal_wire_21 = config$crc_reflect;
    assign signal_mux_319 = signal_wire_21 ? signal_mux_316 : signal_mux_318;
    assign crc_stepped = signal_mux_319 & signal_not_19;
    assign signal_eq_36 = signal_select_2729 == signal_const_9;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            is_opcode$2 <= gnd;
        else
            if (ir_load)
                is_opcode$2 <= signal_eq_36;
    end
    assign signal_or_3 = is_opcode$2 | is_opcode$3;
    assign signal_eq_37 = d$shift_count == signal_const_208;
    assign bit_crosses = signal_eq_37 & signal_or_3;
    assign signal_mux_320 = bit_crosses ? crc_stepped : crc_0;
    assign signal_eq_38 = d$sys_op$binary_variant == signal_const_1;
    assign signal_and_31 = is_opcode$7 & signal_eq_38;
    assign crc_next = signal_and_31 ? signal_wire_18 : signal_mux_320;
    assign signal_mux_321 = go ? crc_next : crc_0;
    assign signal_mux_322 = start_0 ? signal_wire_18 : signal_mux_321;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_12 <= signal_const_196;
        else
            signal_reg_12 <= signal_mux_322;
    end
    assign crc_0 = signal_reg_12;
    assign signal_select_1846 = sample[19:19];
    assign signal_select_1847 = sample[18:18];
    assign signal_select_1848 = sample[17:17];
    assign signal_select_1849 = sample[16:16];
    assign signal_select_1850 = sample[15:15];
    assign signal_select_1851 = sample[14:14];
    assign signal_select_1852 = sample[13:13];
    assign signal_select_1853 = sample[12:12];
    assign signal_select_1854 = sample[11:11];
    assign signal_select_1855 = sample[10:10];
    assign signal_select_1856 = sample[9:9];
    assign signal_select_1857 = sample[8:8];
    assign signal_select_1858 = sample[7:7];
    assign signal_select_1859 = sample[6:6];
    assign signal_select_1860 = sample[5:5];
    assign signal_select_1861 = sample[4:4];
    assign signal_select_1862 = sample[3:3];
    assign signal_select_1863 = sample[2:2];
    assign signal_select_1864 = sample[1:1];
    assign signal_select_1865 = sample[0:0];
    assign signal_const_362 = 6'b010100;
    assign signal_sub_173 = signal_cat_287 - signal_const_362;
    assign signal_cat_287 = { gnd,
                              signal_wire_25 };
    assign signal_lt_168 = signal_cat_287 < signal_const_362;
    assign signal_not_20 = ~ signal_lt_168;
    assign signal_mux_323 = signal_not_20 ? signal_sub_173 : signal_cat_287;
    assign signal_select_1866 = signal_mux_323[4:0];
    always @* begin
        case (signal_select_1866)
        0:
            signal_mux_324 <= signal_select_1865;
        1:
            signal_mux_324 <= signal_select_1864;
        2:
            signal_mux_324 <= signal_select_1863;
        3:
            signal_mux_324 <= signal_select_1862;
        4:
            signal_mux_324 <= signal_select_1861;
        5:
            signal_mux_324 <= signal_select_1860;
        6:
            signal_mux_324 <= signal_select_1859;
        7:
            signal_mux_324 <= signal_select_1858;
        8:
            signal_mux_324 <= signal_select_1857;
        9:
            signal_mux_324 <= signal_select_1856;
        10:
            signal_mux_324 <= signal_select_1855;
        11:
            signal_mux_324 <= signal_select_1854;
        12:
            signal_mux_324 <= signal_select_1853;
        13:
            signal_mux_324 <= signal_select_1852;
        14:
            signal_mux_324 <= signal_select_1851;
        15:
            signal_mux_324 <= signal_select_1850;
        16:
            signal_mux_324 <= signal_select_1849;
        17:
            signal_mux_324 <= signal_select_1848;
        18:
            signal_mux_324 <= signal_select_1847;
        default:
            signal_mux_324 <= signal_select_1846;
        endcase
    end
    assign signal_lt_169 = signal_const_205 < d$shift_count;
    assign signal_and_32 = signal_lt_169 & signal_mux_324;
    assign signal_select_1867 = sample[19:19];
    assign signal_select_1868 = sample[18:18];
    assign signal_select_1869 = sample[17:17];
    assign signal_select_1870 = sample[16:16];
    assign signal_select_1871 = sample[15:15];
    assign signal_select_1872 = sample[14:14];
    assign signal_select_1873 = sample[13:13];
    assign signal_select_1874 = sample[12:12];
    assign signal_select_1875 = sample[11:11];
    assign signal_select_1876 = sample[10:10];
    assign signal_select_1877 = sample[9:9];
    assign signal_select_1878 = sample[8:8];
    assign signal_select_1879 = sample[7:7];
    assign signal_select_1880 = sample[6:6];
    assign signal_select_1881 = sample[5:5];
    assign signal_select_1882 = sample[4:4];
    assign signal_select_1883 = sample[3:3];
    assign signal_select_1884 = sample[2:2];
    assign signal_select_1885 = sample[1:1];
    assign signal_select_1886 = sample[0:0];
    assign signal_sub_174 = signal_add_6 - signal_const_362;
    assign signal_const_367 = 6'b000001;
    assign signal_cat_288 = { gnd,
                              signal_wire_25 };
    assign signal_add_6 = signal_cat_288 + signal_const_367;
    assign signal_lt_170 = signal_add_6 < signal_const_362;
    assign signal_not_21 = ~ signal_lt_170;
    assign signal_mux_325 = signal_not_21 ? signal_sub_174 : signal_add_6;
    assign signal_select_1887 = signal_mux_325[4:0];
    always @* begin
        case (signal_select_1887)
        0:
            signal_mux_326 <= signal_select_1886;
        1:
            signal_mux_326 <= signal_select_1885;
        2:
            signal_mux_326 <= signal_select_1884;
        3:
            signal_mux_326 <= signal_select_1883;
        4:
            signal_mux_326 <= signal_select_1882;
        5:
            signal_mux_326 <= signal_select_1881;
        6:
            signal_mux_326 <= signal_select_1880;
        7:
            signal_mux_326 <= signal_select_1879;
        8:
            signal_mux_326 <= signal_select_1878;
        9:
            signal_mux_326 <= signal_select_1877;
        10:
            signal_mux_326 <= signal_select_1876;
        11:
            signal_mux_326 <= signal_select_1875;
        12:
            signal_mux_326 <= signal_select_1874;
        13:
            signal_mux_326 <= signal_select_1873;
        14:
            signal_mux_326 <= signal_select_1872;
        15:
            signal_mux_326 <= signal_select_1871;
        16:
            signal_mux_326 <= signal_select_1870;
        17:
            signal_mux_326 <= signal_select_1869;
        18:
            signal_mux_326 <= signal_select_1868;
        default:
            signal_mux_326 <= signal_select_1867;
        endcase
    end
    assign signal_lt_171 = signal_const_208 < d$shift_count;
    assign signal_and_33 = signal_lt_171 & signal_mux_326;
    assign signal_select_1888 = sample[19:19];
    assign signal_select_1889 = sample[18:18];
    assign signal_select_1890 = sample[17:17];
    assign signal_select_1891 = sample[16:16];
    assign signal_select_1892 = sample[15:15];
    assign signal_select_1893 = sample[14:14];
    assign signal_select_1894 = sample[13:13];
    assign signal_select_1895 = sample[12:12];
    assign signal_select_1896 = sample[11:11];
    assign signal_select_1897 = sample[10:10];
    assign signal_select_1898 = sample[9:9];
    assign signal_select_1899 = sample[8:8];
    assign signal_select_1900 = sample[7:7];
    assign signal_select_1901 = sample[6:6];
    assign signal_select_1902 = sample[5:5];
    assign signal_select_1903 = sample[4:4];
    assign signal_select_1904 = sample[3:3];
    assign signal_select_1905 = sample[2:2];
    assign signal_select_1906 = sample[1:1];
    assign signal_select_1907 = sample[0:0];
    assign signal_sub_175 = signal_add_7 - signal_const_362;
    assign signal_const_371 = 6'b000010;
    assign signal_cat_289 = { gnd,
                              signal_wire_25 };
    assign signal_add_7 = signal_cat_289 + signal_const_371;
    assign signal_lt_172 = signal_add_7 < signal_const_362;
    assign signal_not_22 = ~ signal_lt_172;
    assign signal_mux_327 = signal_not_22 ? signal_sub_175 : signal_add_7;
    assign signal_select_1908 = signal_mux_327[4:0];
    always @* begin
        case (signal_select_1908)
        0:
            signal_mux_328 <= signal_select_1907;
        1:
            signal_mux_328 <= signal_select_1906;
        2:
            signal_mux_328 <= signal_select_1905;
        3:
            signal_mux_328 <= signal_select_1904;
        4:
            signal_mux_328 <= signal_select_1903;
        5:
            signal_mux_328 <= signal_select_1902;
        6:
            signal_mux_328 <= signal_select_1901;
        7:
            signal_mux_328 <= signal_select_1900;
        8:
            signal_mux_328 <= signal_select_1899;
        9:
            signal_mux_328 <= signal_select_1898;
        10:
            signal_mux_328 <= signal_select_1897;
        11:
            signal_mux_328 <= signal_select_1896;
        12:
            signal_mux_328 <= signal_select_1895;
        13:
            signal_mux_328 <= signal_select_1894;
        14:
            signal_mux_328 <= signal_select_1893;
        15:
            signal_mux_328 <= signal_select_1892;
        16:
            signal_mux_328 <= signal_select_1891;
        17:
            signal_mux_328 <= signal_select_1890;
        18:
            signal_mux_328 <= signal_select_1889;
        default:
            signal_mux_328 <= signal_select_1888;
        endcase
    end
    assign signal_const_372 = 5'b00010;
    assign signal_lt_173 = signal_const_372 < d$shift_count;
    assign signal_and_34 = signal_lt_173 & signal_mux_328;
    assign signal_select_1909 = sample[19:19];
    assign signal_select_1910 = sample[18:18];
    assign signal_select_1911 = sample[17:17];
    assign signal_select_1912 = sample[16:16];
    assign signal_select_1913 = sample[15:15];
    assign signal_select_1914 = sample[14:14];
    assign signal_select_1915 = sample[13:13];
    assign signal_select_1916 = sample[12:12];
    assign signal_select_1917 = sample[11:11];
    assign signal_select_1918 = sample[10:10];
    assign signal_select_1919 = sample[9:9];
    assign signal_select_1920 = sample[8:8];
    assign signal_select_1921 = sample[7:7];
    assign signal_select_1922 = sample[6:6];
    assign signal_select_1923 = sample[5:5];
    assign signal_select_1924 = sample[4:4];
    assign signal_select_1925 = sample[3:3];
    assign signal_select_1926 = sample[2:2];
    assign signal_select_1927 = sample[1:1];
    assign signal_select_1928 = sample[0:0];
    assign signal_sub_176 = signal_add_8 - signal_const_362;
    assign signal_const_375 = 6'b000011;
    assign signal_cat_290 = { gnd,
                              signal_wire_25 };
    assign signal_add_8 = signal_cat_290 + signal_const_375;
    assign signal_lt_174 = signal_add_8 < signal_const_362;
    assign signal_not_23 = ~ signal_lt_174;
    assign signal_mux_329 = signal_not_23 ? signal_sub_176 : signal_add_8;
    assign signal_select_1929 = signal_mux_329[4:0];
    always @* begin
        case (signal_select_1929)
        0:
            signal_mux_330 <= signal_select_1928;
        1:
            signal_mux_330 <= signal_select_1927;
        2:
            signal_mux_330 <= signal_select_1926;
        3:
            signal_mux_330 <= signal_select_1925;
        4:
            signal_mux_330 <= signal_select_1924;
        5:
            signal_mux_330 <= signal_select_1923;
        6:
            signal_mux_330 <= signal_select_1922;
        7:
            signal_mux_330 <= signal_select_1921;
        8:
            signal_mux_330 <= signal_select_1920;
        9:
            signal_mux_330 <= signal_select_1919;
        10:
            signal_mux_330 <= signal_select_1918;
        11:
            signal_mux_330 <= signal_select_1917;
        12:
            signal_mux_330 <= signal_select_1916;
        13:
            signal_mux_330 <= signal_select_1915;
        14:
            signal_mux_330 <= signal_select_1914;
        15:
            signal_mux_330 <= signal_select_1913;
        16:
            signal_mux_330 <= signal_select_1912;
        17:
            signal_mux_330 <= signal_select_1911;
        18:
            signal_mux_330 <= signal_select_1910;
        default:
            signal_mux_330 <= signal_select_1909;
        endcase
    end
    assign signal_const_376 = 5'b00011;
    assign signal_lt_175 = signal_const_376 < d$shift_count;
    assign signal_and_35 = signal_lt_175 & signal_mux_330;
    assign signal_select_1930 = sample[19:19];
    assign signal_select_1931 = sample[18:18];
    assign signal_select_1932 = sample[17:17];
    assign signal_select_1933 = sample[16:16];
    assign signal_select_1934 = sample[15:15];
    assign signal_select_1935 = sample[14:14];
    assign signal_select_1936 = sample[13:13];
    assign signal_select_1937 = sample[12:12];
    assign signal_select_1938 = sample[11:11];
    assign signal_select_1939 = sample[10:10];
    assign signal_select_1940 = sample[9:9];
    assign signal_select_1941 = sample[8:8];
    assign signal_select_1942 = sample[7:7];
    assign signal_select_1943 = sample[6:6];
    assign signal_select_1944 = sample[5:5];
    assign signal_select_1945 = sample[4:4];
    assign signal_select_1946 = sample[3:3];
    assign signal_select_1947 = sample[2:2];
    assign signal_select_1948 = sample[1:1];
    assign signal_select_1949 = sample[0:0];
    assign signal_sub_177 = signal_add_9 - signal_const_362;
    assign signal_const_379 = 6'b000100;
    assign signal_cat_291 = { gnd,
                              signal_wire_25 };
    assign signal_add_9 = signal_cat_291 + signal_const_379;
    assign signal_lt_176 = signal_add_9 < signal_const_362;
    assign signal_not_24 = ~ signal_lt_176;
    assign signal_mux_331 = signal_not_24 ? signal_sub_177 : signal_add_9;
    assign signal_select_1950 = signal_mux_331[4:0];
    always @* begin
        case (signal_select_1950)
        0:
            signal_mux_332 <= signal_select_1949;
        1:
            signal_mux_332 <= signal_select_1948;
        2:
            signal_mux_332 <= signal_select_1947;
        3:
            signal_mux_332 <= signal_select_1946;
        4:
            signal_mux_332 <= signal_select_1945;
        5:
            signal_mux_332 <= signal_select_1944;
        6:
            signal_mux_332 <= signal_select_1943;
        7:
            signal_mux_332 <= signal_select_1942;
        8:
            signal_mux_332 <= signal_select_1941;
        9:
            signal_mux_332 <= signal_select_1940;
        10:
            signal_mux_332 <= signal_select_1939;
        11:
            signal_mux_332 <= signal_select_1938;
        12:
            signal_mux_332 <= signal_select_1937;
        13:
            signal_mux_332 <= signal_select_1936;
        14:
            signal_mux_332 <= signal_select_1935;
        15:
            signal_mux_332 <= signal_select_1934;
        16:
            signal_mux_332 <= signal_select_1933;
        17:
            signal_mux_332 <= signal_select_1932;
        18:
            signal_mux_332 <= signal_select_1931;
        default:
            signal_mux_332 <= signal_select_1930;
        endcase
    end
    assign signal_const_380 = 5'b00100;
    assign signal_lt_177 = signal_const_380 < d$shift_count;
    assign signal_and_36 = signal_lt_177 & signal_mux_332;
    assign signal_select_1951 = sample[19:19];
    assign signal_select_1952 = sample[18:18];
    assign signal_select_1953 = sample[17:17];
    assign signal_select_1954 = sample[16:16];
    assign signal_select_1955 = sample[15:15];
    assign signal_select_1956 = sample[14:14];
    assign signal_select_1957 = sample[13:13];
    assign signal_select_1958 = sample[12:12];
    assign signal_select_1959 = sample[11:11];
    assign signal_select_1960 = sample[10:10];
    assign signal_select_1961 = sample[9:9];
    assign signal_select_1962 = sample[8:8];
    assign signal_select_1963 = sample[7:7];
    assign signal_select_1964 = sample[6:6];
    assign signal_select_1965 = sample[5:5];
    assign signal_select_1966 = sample[4:4];
    assign signal_select_1967 = sample[3:3];
    assign signal_select_1968 = sample[2:2];
    assign signal_select_1969 = sample[1:1];
    assign signal_select_1970 = sample[0:0];
    assign signal_sub_178 = signal_add_10 - signal_const_362;
    assign signal_cat_292 = { gnd,
                              signal_wire_25 };
    assign signal_add_10 = signal_cat_292 + signal_const_12;
    assign signal_lt_178 = signal_add_10 < signal_const_362;
    assign signal_not_25 = ~ signal_lt_178;
    assign signal_mux_333 = signal_not_25 ? signal_sub_178 : signal_add_10;
    assign signal_select_1971 = signal_mux_333[4:0];
    always @* begin
        case (signal_select_1971)
        0:
            signal_mux_334 <= signal_select_1970;
        1:
            signal_mux_334 <= signal_select_1969;
        2:
            signal_mux_334 <= signal_select_1968;
        3:
            signal_mux_334 <= signal_select_1967;
        4:
            signal_mux_334 <= signal_select_1966;
        5:
            signal_mux_334 <= signal_select_1965;
        6:
            signal_mux_334 <= signal_select_1964;
        7:
            signal_mux_334 <= signal_select_1963;
        8:
            signal_mux_334 <= signal_select_1962;
        9:
            signal_mux_334 <= signal_select_1961;
        10:
            signal_mux_334 <= signal_select_1960;
        11:
            signal_mux_334 <= signal_select_1959;
        12:
            signal_mux_334 <= signal_select_1958;
        13:
            signal_mux_334 <= signal_select_1957;
        14:
            signal_mux_334 <= signal_select_1956;
        15:
            signal_mux_334 <= signal_select_1955;
        16:
            signal_mux_334 <= signal_select_1954;
        17:
            signal_mux_334 <= signal_select_1953;
        18:
            signal_mux_334 <= signal_select_1952;
        default:
            signal_mux_334 <= signal_select_1951;
        endcase
    end
    assign signal_lt_179 = signal_const_13 < d$shift_count;
    assign signal_and_37 = signal_lt_179 & signal_mux_334;
    assign signal_select_1972 = sample[19:19];
    assign signal_select_1973 = sample[18:18];
    assign signal_select_1974 = sample[17:17];
    assign signal_select_1975 = sample[16:16];
    assign signal_select_1976 = sample[15:15];
    assign signal_select_1977 = sample[14:14];
    assign signal_select_1978 = sample[13:13];
    assign signal_select_1979 = sample[12:12];
    assign signal_select_1980 = sample[11:11];
    assign signal_select_1981 = sample[10:10];
    assign signal_select_1982 = sample[9:9];
    assign signal_select_1983 = sample[8:8];
    assign signal_select_1984 = sample[7:7];
    assign signal_select_1985 = sample[6:6];
    assign signal_select_1986 = sample[5:5];
    assign signal_select_1987 = sample[4:4];
    assign signal_select_1988 = sample[3:3];
    assign signal_select_1989 = sample[2:2];
    assign signal_select_1990 = sample[1:1];
    assign signal_select_1991 = sample[0:0];
    assign signal_sub_179 = signal_add_11 - signal_const_362;
    assign signal_cat_293 = { gnd,
                              signal_wire_25 };
    assign signal_add_11 = signal_cat_293 + signal_const_15;
    assign signal_lt_180 = signal_add_11 < signal_const_362;
    assign signal_not_26 = ~ signal_lt_180;
    assign signal_mux_335 = signal_not_26 ? signal_sub_179 : signal_add_11;
    assign signal_select_1992 = signal_mux_335[4:0];
    always @* begin
        case (signal_select_1992)
        0:
            signal_mux_336 <= signal_select_1991;
        1:
            signal_mux_336 <= signal_select_1990;
        2:
            signal_mux_336 <= signal_select_1989;
        3:
            signal_mux_336 <= signal_select_1988;
        4:
            signal_mux_336 <= signal_select_1987;
        5:
            signal_mux_336 <= signal_select_1986;
        6:
            signal_mux_336 <= signal_select_1985;
        7:
            signal_mux_336 <= signal_select_1984;
        8:
            signal_mux_336 <= signal_select_1983;
        9:
            signal_mux_336 <= signal_select_1982;
        10:
            signal_mux_336 <= signal_select_1981;
        11:
            signal_mux_336 <= signal_select_1980;
        12:
            signal_mux_336 <= signal_select_1979;
        13:
            signal_mux_336 <= signal_select_1978;
        14:
            signal_mux_336 <= signal_select_1977;
        15:
            signal_mux_336 <= signal_select_1976;
        16:
            signal_mux_336 <= signal_select_1975;
        17:
            signal_mux_336 <= signal_select_1974;
        18:
            signal_mux_336 <= signal_select_1973;
        default:
            signal_mux_336 <= signal_select_1972;
        endcase
    end
    assign signal_lt_181 = signal_const_16 < d$shift_count;
    assign signal_and_38 = signal_lt_181 & signal_mux_336;
    assign signal_select_1993 = sample[19:19];
    assign signal_select_1994 = sample[18:18];
    assign signal_select_1995 = sample[17:17];
    assign signal_select_1996 = sample[16:16];
    assign signal_select_1997 = sample[15:15];
    assign signal_select_1998 = sample[14:14];
    assign signal_select_1999 = sample[13:13];
    assign signal_select_2000 = sample[12:12];
    assign signal_select_2001 = sample[11:11];
    assign signal_select_2002 = sample[10:10];
    assign signal_select_2003 = sample[9:9];
    assign signal_select_2004 = sample[8:8];
    assign signal_select_2005 = sample[7:7];
    assign signal_select_2006 = sample[6:6];
    assign signal_select_2007 = sample[5:5];
    assign signal_select_2008 = sample[4:4];
    assign signal_select_2009 = sample[3:3];
    assign signal_select_2010 = sample[2:2];
    assign signal_select_2011 = sample[1:1];
    assign signal_select_2012 = sample[0:0];
    assign signal_sub_180 = signal_add_12 - signal_const_362;
    assign signal_cat_294 = { gnd,
                              signal_wire_25 };
    assign signal_add_12 = signal_cat_294 + signal_const_18;
    assign signal_lt_182 = signal_add_12 < signal_const_362;
    assign signal_not_27 = ~ signal_lt_182;
    assign signal_mux_337 = signal_not_27 ? signal_sub_180 : signal_add_12;
    assign signal_select_2013 = signal_mux_337[4:0];
    always @* begin
        case (signal_select_2013)
        0:
            signal_mux_338 <= signal_select_2012;
        1:
            signal_mux_338 <= signal_select_2011;
        2:
            signal_mux_338 <= signal_select_2010;
        3:
            signal_mux_338 <= signal_select_2009;
        4:
            signal_mux_338 <= signal_select_2008;
        5:
            signal_mux_338 <= signal_select_2007;
        6:
            signal_mux_338 <= signal_select_2006;
        7:
            signal_mux_338 <= signal_select_2005;
        8:
            signal_mux_338 <= signal_select_2004;
        9:
            signal_mux_338 <= signal_select_2003;
        10:
            signal_mux_338 <= signal_select_2002;
        11:
            signal_mux_338 <= signal_select_2001;
        12:
            signal_mux_338 <= signal_select_2000;
        13:
            signal_mux_338 <= signal_select_1999;
        14:
            signal_mux_338 <= signal_select_1998;
        15:
            signal_mux_338 <= signal_select_1997;
        16:
            signal_mux_338 <= signal_select_1996;
        17:
            signal_mux_338 <= signal_select_1995;
        18:
            signal_mux_338 <= signal_select_1994;
        default:
            signal_mux_338 <= signal_select_1993;
        endcase
    end
    assign signal_lt_183 = signal_const_19 < d$shift_count;
    assign signal_and_39 = signal_lt_183 & signal_mux_338;
    assign signal_select_2014 = sample[19:19];
    assign signal_select_2015 = sample[18:18];
    assign signal_select_2016 = sample[17:17];
    assign signal_select_2017 = sample[16:16];
    assign signal_select_2018 = sample[15:15];
    assign signal_select_2019 = sample[14:14];
    assign signal_select_2020 = sample[13:13];
    assign signal_select_2021 = sample[12:12];
    assign signal_select_2022 = sample[11:11];
    assign signal_select_2023 = sample[10:10];
    assign signal_select_2024 = sample[9:9];
    assign signal_select_2025 = sample[8:8];
    assign signal_select_2026 = sample[7:7];
    assign signal_select_2027 = sample[6:6];
    assign signal_select_2028 = sample[5:5];
    assign signal_select_2029 = sample[4:4];
    assign signal_select_2030 = sample[3:3];
    assign signal_select_2031 = sample[2:2];
    assign signal_select_2032 = sample[1:1];
    assign signal_select_2033 = sample[0:0];
    assign signal_sub_181 = signal_add_13 - signal_const_362;
    assign signal_cat_295 = { gnd,
                              signal_wire_25 };
    assign signal_add_13 = signal_cat_295 + signal_const_21;
    assign signal_lt_184 = signal_add_13 < signal_const_362;
    assign signal_not_28 = ~ signal_lt_184;
    assign signal_mux_339 = signal_not_28 ? signal_sub_181 : signal_add_13;
    assign signal_select_2034 = signal_mux_339[4:0];
    always @* begin
        case (signal_select_2034)
        0:
            signal_mux_340 <= signal_select_2033;
        1:
            signal_mux_340 <= signal_select_2032;
        2:
            signal_mux_340 <= signal_select_2031;
        3:
            signal_mux_340 <= signal_select_2030;
        4:
            signal_mux_340 <= signal_select_2029;
        5:
            signal_mux_340 <= signal_select_2028;
        6:
            signal_mux_340 <= signal_select_2027;
        7:
            signal_mux_340 <= signal_select_2026;
        8:
            signal_mux_340 <= signal_select_2025;
        9:
            signal_mux_340 <= signal_select_2024;
        10:
            signal_mux_340 <= signal_select_2023;
        11:
            signal_mux_340 <= signal_select_2022;
        12:
            signal_mux_340 <= signal_select_2021;
        13:
            signal_mux_340 <= signal_select_2020;
        14:
            signal_mux_340 <= signal_select_2019;
        15:
            signal_mux_340 <= signal_select_2018;
        16:
            signal_mux_340 <= signal_select_2017;
        17:
            signal_mux_340 <= signal_select_2016;
        18:
            signal_mux_340 <= signal_select_2015;
        default:
            signal_mux_340 <= signal_select_2014;
        endcase
    end
    assign signal_lt_185 = signal_const_22 < d$shift_count;
    assign signal_and_40 = signal_lt_185 & signal_mux_340;
    assign signal_select_2035 = sample[19:19];
    assign signal_select_2036 = sample[18:18];
    assign signal_select_2037 = sample[17:17];
    assign signal_select_2038 = sample[16:16];
    assign signal_select_2039 = sample[15:15];
    assign signal_select_2040 = sample[14:14];
    assign signal_select_2041 = sample[13:13];
    assign signal_select_2042 = sample[12:12];
    assign signal_select_2043 = sample[11:11];
    assign signal_select_2044 = sample[10:10];
    assign signal_select_2045 = sample[9:9];
    assign signal_select_2046 = sample[8:8];
    assign signal_select_2047 = sample[7:7];
    assign signal_select_2048 = sample[6:6];
    assign signal_select_2049 = sample[5:5];
    assign signal_select_2050 = sample[4:4];
    assign signal_select_2051 = sample[3:3];
    assign signal_select_2052 = sample[2:2];
    assign signal_select_2053 = sample[1:1];
    assign signal_select_2054 = sample[0:0];
    assign signal_sub_182 = signal_add_14 - signal_const_362;
    assign signal_cat_296 = { gnd,
                              signal_wire_25 };
    assign signal_add_14 = signal_cat_296 + signal_const_24;
    assign signal_lt_186 = signal_add_14 < signal_const_362;
    assign signal_not_29 = ~ signal_lt_186;
    assign signal_mux_341 = signal_not_29 ? signal_sub_182 : signal_add_14;
    assign signal_select_2055 = signal_mux_341[4:0];
    always @* begin
        case (signal_select_2055)
        0:
            signal_mux_342 <= signal_select_2054;
        1:
            signal_mux_342 <= signal_select_2053;
        2:
            signal_mux_342 <= signal_select_2052;
        3:
            signal_mux_342 <= signal_select_2051;
        4:
            signal_mux_342 <= signal_select_2050;
        5:
            signal_mux_342 <= signal_select_2049;
        6:
            signal_mux_342 <= signal_select_2048;
        7:
            signal_mux_342 <= signal_select_2047;
        8:
            signal_mux_342 <= signal_select_2046;
        9:
            signal_mux_342 <= signal_select_2045;
        10:
            signal_mux_342 <= signal_select_2044;
        11:
            signal_mux_342 <= signal_select_2043;
        12:
            signal_mux_342 <= signal_select_2042;
        13:
            signal_mux_342 <= signal_select_2041;
        14:
            signal_mux_342 <= signal_select_2040;
        15:
            signal_mux_342 <= signal_select_2039;
        16:
            signal_mux_342 <= signal_select_2038;
        17:
            signal_mux_342 <= signal_select_2037;
        18:
            signal_mux_342 <= signal_select_2036;
        default:
            signal_mux_342 <= signal_select_2035;
        endcase
    end
    assign signal_lt_187 = signal_const_25 < d$shift_count;
    assign signal_and_41 = signal_lt_187 & signal_mux_342;
    assign signal_select_2056 = sample[19:19];
    assign signal_select_2057 = sample[18:18];
    assign signal_select_2058 = sample[17:17];
    assign signal_select_2059 = sample[16:16];
    assign signal_select_2060 = sample[15:15];
    assign signal_select_2061 = sample[14:14];
    assign signal_select_2062 = sample[13:13];
    assign signal_select_2063 = sample[12:12];
    assign signal_select_2064 = sample[11:11];
    assign signal_select_2065 = sample[10:10];
    assign signal_select_2066 = sample[9:9];
    assign signal_select_2067 = sample[8:8];
    assign signal_select_2068 = sample[7:7];
    assign signal_select_2069 = sample[6:6];
    assign signal_select_2070 = sample[5:5];
    assign signal_select_2071 = sample[4:4];
    assign signal_select_2072 = sample[3:3];
    assign signal_select_2073 = sample[2:2];
    assign signal_select_2074 = sample[1:1];
    assign signal_select_2075 = sample[0:0];
    assign signal_sub_183 = signal_add_15 - signal_const_362;
    assign signal_cat_297 = { gnd,
                              signal_wire_25 };
    assign signal_add_15 = signal_cat_297 + signal_const_27;
    assign signal_lt_188 = signal_add_15 < signal_const_362;
    assign signal_not_30 = ~ signal_lt_188;
    assign signal_mux_343 = signal_not_30 ? signal_sub_183 : signal_add_15;
    assign signal_select_2076 = signal_mux_343[4:0];
    always @* begin
        case (signal_select_2076)
        0:
            signal_mux_344 <= signal_select_2075;
        1:
            signal_mux_344 <= signal_select_2074;
        2:
            signal_mux_344 <= signal_select_2073;
        3:
            signal_mux_344 <= signal_select_2072;
        4:
            signal_mux_344 <= signal_select_2071;
        5:
            signal_mux_344 <= signal_select_2070;
        6:
            signal_mux_344 <= signal_select_2069;
        7:
            signal_mux_344 <= signal_select_2068;
        8:
            signal_mux_344 <= signal_select_2067;
        9:
            signal_mux_344 <= signal_select_2066;
        10:
            signal_mux_344 <= signal_select_2065;
        11:
            signal_mux_344 <= signal_select_2064;
        12:
            signal_mux_344 <= signal_select_2063;
        13:
            signal_mux_344 <= signal_select_2062;
        14:
            signal_mux_344 <= signal_select_2061;
        15:
            signal_mux_344 <= signal_select_2060;
        16:
            signal_mux_344 <= signal_select_2059;
        17:
            signal_mux_344 <= signal_select_2058;
        18:
            signal_mux_344 <= signal_select_2057;
        default:
            signal_mux_344 <= signal_select_2056;
        endcase
    end
    assign signal_lt_189 = signal_const_28 < d$shift_count;
    assign signal_and_42 = signal_lt_189 & signal_mux_344;
    assign signal_select_2077 = sample[19:19];
    assign signal_select_2078 = sample[18:18];
    assign signal_select_2079 = sample[17:17];
    assign signal_select_2080 = sample[16:16];
    assign signal_select_2081 = sample[15:15];
    assign signal_select_2082 = sample[14:14];
    assign signal_select_2083 = sample[13:13];
    assign signal_select_2084 = sample[12:12];
    assign signal_select_2085 = sample[11:11];
    assign signal_select_2086 = sample[10:10];
    assign signal_select_2087 = sample[9:9];
    assign signal_select_2088 = sample[8:8];
    assign signal_select_2089 = sample[7:7];
    assign signal_select_2090 = sample[6:6];
    assign signal_select_2091 = sample[5:5];
    assign signal_select_2092 = sample[4:4];
    assign signal_select_2093 = sample[3:3];
    assign signal_select_2094 = sample[2:2];
    assign signal_select_2095 = sample[1:1];
    assign signal_select_2096 = sample[0:0];
    assign signal_sub_184 = signal_add_16 - signal_const_362;
    assign signal_cat_298 = { gnd,
                              signal_wire_25 };
    assign signal_add_16 = signal_cat_298 + signal_const_30;
    assign signal_lt_190 = signal_add_16 < signal_const_362;
    assign signal_not_31 = ~ signal_lt_190;
    assign signal_mux_345 = signal_not_31 ? signal_sub_184 : signal_add_16;
    assign signal_select_2097 = signal_mux_345[4:0];
    always @* begin
        case (signal_select_2097)
        0:
            signal_mux_346 <= signal_select_2096;
        1:
            signal_mux_346 <= signal_select_2095;
        2:
            signal_mux_346 <= signal_select_2094;
        3:
            signal_mux_346 <= signal_select_2093;
        4:
            signal_mux_346 <= signal_select_2092;
        5:
            signal_mux_346 <= signal_select_2091;
        6:
            signal_mux_346 <= signal_select_2090;
        7:
            signal_mux_346 <= signal_select_2089;
        8:
            signal_mux_346 <= signal_select_2088;
        9:
            signal_mux_346 <= signal_select_2087;
        10:
            signal_mux_346 <= signal_select_2086;
        11:
            signal_mux_346 <= signal_select_2085;
        12:
            signal_mux_346 <= signal_select_2084;
        13:
            signal_mux_346 <= signal_select_2083;
        14:
            signal_mux_346 <= signal_select_2082;
        15:
            signal_mux_346 <= signal_select_2081;
        16:
            signal_mux_346 <= signal_select_2080;
        17:
            signal_mux_346 <= signal_select_2079;
        18:
            signal_mux_346 <= signal_select_2078;
        default:
            signal_mux_346 <= signal_select_2077;
        endcase
    end
    assign signal_lt_191 = signal_const_31 < d$shift_count;
    assign signal_and_43 = signal_lt_191 & signal_mux_346;
    assign signal_select_2098 = sample[19:19];
    assign signal_select_2099 = sample[18:18];
    assign signal_select_2100 = sample[17:17];
    assign signal_select_2101 = sample[16:16];
    assign signal_select_2102 = sample[15:15];
    assign signal_select_2103 = sample[14:14];
    assign signal_select_2104 = sample[13:13];
    assign signal_select_2105 = sample[12:12];
    assign signal_select_2106 = sample[11:11];
    assign signal_select_2107 = sample[10:10];
    assign signal_select_2108 = sample[9:9];
    assign signal_select_2109 = sample[8:8];
    assign signal_select_2110 = sample[7:7];
    assign signal_select_2111 = sample[6:6];
    assign signal_select_2112 = sample[5:5];
    assign signal_select_2113 = sample[4:4];
    assign signal_select_2114 = sample[3:3];
    assign signal_select_2115 = sample[2:2];
    assign signal_select_2116 = sample[1:1];
    assign signal_select_2117 = sample[0:0];
    assign signal_sub_185 = signal_add_17 - signal_const_362;
    assign signal_cat_299 = { gnd,
                              signal_wire_25 };
    assign signal_add_17 = signal_cat_299 + signal_const_33;
    assign signal_lt_192 = signal_add_17 < signal_const_362;
    assign signal_not_32 = ~ signal_lt_192;
    assign signal_mux_347 = signal_not_32 ? signal_sub_185 : signal_add_17;
    assign signal_select_2118 = signal_mux_347[4:0];
    always @* begin
        case (signal_select_2118)
        0:
            signal_mux_348 <= signal_select_2117;
        1:
            signal_mux_348 <= signal_select_2116;
        2:
            signal_mux_348 <= signal_select_2115;
        3:
            signal_mux_348 <= signal_select_2114;
        4:
            signal_mux_348 <= signal_select_2113;
        5:
            signal_mux_348 <= signal_select_2112;
        6:
            signal_mux_348 <= signal_select_2111;
        7:
            signal_mux_348 <= signal_select_2110;
        8:
            signal_mux_348 <= signal_select_2109;
        9:
            signal_mux_348 <= signal_select_2108;
        10:
            signal_mux_348 <= signal_select_2107;
        11:
            signal_mux_348 <= signal_select_2106;
        12:
            signal_mux_348 <= signal_select_2105;
        13:
            signal_mux_348 <= signal_select_2104;
        14:
            signal_mux_348 <= signal_select_2103;
        15:
            signal_mux_348 <= signal_select_2102;
        16:
            signal_mux_348 <= signal_select_2101;
        17:
            signal_mux_348 <= signal_select_2100;
        18:
            signal_mux_348 <= signal_select_2099;
        default:
            signal_mux_348 <= signal_select_2098;
        endcase
    end
    assign signal_lt_193 = signal_const_34 < d$shift_count;
    assign signal_and_44 = signal_lt_193 & signal_mux_348;
    assign signal_select_2119 = sample[19:19];
    assign signal_select_2120 = sample[18:18];
    assign signal_select_2121 = sample[17:17];
    assign signal_select_2122 = sample[16:16];
    assign signal_select_2123 = sample[15:15];
    assign signal_select_2124 = sample[14:14];
    assign signal_select_2125 = sample[13:13];
    assign signal_select_2126 = sample[12:12];
    assign signal_select_2127 = sample[11:11];
    assign signal_select_2128 = sample[10:10];
    assign signal_select_2129 = sample[9:9];
    assign signal_select_2130 = sample[8:8];
    assign signal_select_2131 = sample[7:7];
    assign signal_select_2132 = sample[6:6];
    assign signal_select_2133 = sample[5:5];
    assign signal_select_2134 = sample[4:4];
    assign signal_select_2135 = sample[3:3];
    assign signal_select_2136 = sample[2:2];
    assign signal_select_2137 = sample[1:1];
    assign signal_select_2138 = sample[0:0];
    assign signal_sub_186 = signal_add_18 - signal_const_362;
    assign signal_cat_300 = { gnd,
                              signal_wire_25 };
    assign signal_add_18 = signal_cat_300 + signal_const_36;
    assign signal_lt_194 = signal_add_18 < signal_const_362;
    assign signal_not_33 = ~ signal_lt_194;
    assign signal_mux_349 = signal_not_33 ? signal_sub_186 : signal_add_18;
    assign signal_select_2139 = signal_mux_349[4:0];
    always @* begin
        case (signal_select_2139)
        0:
            signal_mux_350 <= signal_select_2138;
        1:
            signal_mux_350 <= signal_select_2137;
        2:
            signal_mux_350 <= signal_select_2136;
        3:
            signal_mux_350 <= signal_select_2135;
        4:
            signal_mux_350 <= signal_select_2134;
        5:
            signal_mux_350 <= signal_select_2133;
        6:
            signal_mux_350 <= signal_select_2132;
        7:
            signal_mux_350 <= signal_select_2131;
        8:
            signal_mux_350 <= signal_select_2130;
        9:
            signal_mux_350 <= signal_select_2129;
        10:
            signal_mux_350 <= signal_select_2128;
        11:
            signal_mux_350 <= signal_select_2127;
        12:
            signal_mux_350 <= signal_select_2126;
        13:
            signal_mux_350 <= signal_select_2125;
        14:
            signal_mux_350 <= signal_select_2124;
        15:
            signal_mux_350 <= signal_select_2123;
        16:
            signal_mux_350 <= signal_select_2122;
        17:
            signal_mux_350 <= signal_select_2121;
        18:
            signal_mux_350 <= signal_select_2120;
        default:
            signal_mux_350 <= signal_select_2119;
        endcase
    end
    assign signal_lt_195 = signal_const_37 < d$shift_count;
    assign signal_and_45 = signal_lt_195 & signal_mux_350;
    assign signal_select_2140 = sample[19:19];
    assign signal_select_2141 = sample[18:18];
    assign signal_select_2142 = sample[17:17];
    assign signal_select_2143 = sample[16:16];
    assign signal_select_2144 = sample[15:15];
    assign signal_select_2145 = sample[14:14];
    assign signal_select_2146 = sample[13:13];
    assign signal_select_2147 = sample[12:12];
    assign signal_select_2148 = sample[11:11];
    assign signal_select_2149 = sample[10:10];
    assign signal_select_2150 = sample[9:9];
    assign signal_select_2151 = sample[8:8];
    assign signal_select_2152 = sample[7:7];
    assign signal_select_2153 = sample[6:6];
    assign signal_select_2154 = sample[5:5];
    assign signal_select_2155 = sample[4:4];
    assign signal_select_2156 = sample[3:3];
    assign signal_select_2157 = sample[2:2];
    assign signal_select_2158 = sample[1:1];
    assign signal_select_2159 = sample[0:0];
    assign signal_sub_187 = signal_add_19 - signal_const_362;
    assign signal_cat_301 = { gnd,
                              signal_wire_25 };
    assign signal_add_19 = signal_cat_301 + signal_const_39;
    assign signal_lt_196 = signal_add_19 < signal_const_362;
    assign signal_not_34 = ~ signal_lt_196;
    assign signal_mux_351 = signal_not_34 ? signal_sub_187 : signal_add_19;
    assign signal_select_2160 = signal_mux_351[4:0];
    always @* begin
        case (signal_select_2160)
        0:
            signal_mux_352 <= signal_select_2159;
        1:
            signal_mux_352 <= signal_select_2158;
        2:
            signal_mux_352 <= signal_select_2157;
        3:
            signal_mux_352 <= signal_select_2156;
        4:
            signal_mux_352 <= signal_select_2155;
        5:
            signal_mux_352 <= signal_select_2154;
        6:
            signal_mux_352 <= signal_select_2153;
        7:
            signal_mux_352 <= signal_select_2152;
        8:
            signal_mux_352 <= signal_select_2151;
        9:
            signal_mux_352 <= signal_select_2150;
        10:
            signal_mux_352 <= signal_select_2149;
        11:
            signal_mux_352 <= signal_select_2148;
        12:
            signal_mux_352 <= signal_select_2147;
        13:
            signal_mux_352 <= signal_select_2146;
        14:
            signal_mux_352 <= signal_select_2145;
        15:
            signal_mux_352 <= signal_select_2144;
        16:
            signal_mux_352 <= signal_select_2143;
        17:
            signal_mux_352 <= signal_select_2142;
        18:
            signal_mux_352 <= signal_select_2141;
        default:
            signal_mux_352 <= signal_select_2140;
        endcase
    end
    assign signal_lt_197 = signal_const_40 < d$shift_count;
    assign signal_and_46 = signal_lt_197 & signal_mux_352;
    assign signal_select_2161 = sample[19:19];
    assign signal_select_2162 = sample[18:18];
    assign signal_select_2163 = sample[17:17];
    assign signal_select_2164 = sample[16:16];
    assign signal_select_2165 = sample[15:15];
    assign signal_select_2166 = sample[14:14];
    assign signal_select_2167 = sample[13:13];
    assign signal_select_2168 = sample[12:12];
    assign signal_select_2169 = sample[11:11];
    assign signal_select_2170 = sample[10:10];
    assign signal_select_2171 = sample[9:9];
    assign signal_select_2172 = sample[8:8];
    assign signal_select_2173 = sample[7:7];
    assign signal_select_2174 = sample[6:6];
    assign signal_select_2175 = sample[5:5];
    assign signal_select_2176 = sample[4:4];
    assign signal_select_2177 = sample[3:3];
    assign signal_select_2178 = sample[2:2];
    assign signal_select_2179 = sample[1:1];
    assign signal_select_2180 = sample[0:0];
    assign signal_sub_188 = signal_add_20 - signal_const_362;
    assign signal_cat_302 = { gnd,
                              signal_wire_25 };
    assign signal_add_20 = signal_cat_302 + signal_const_42;
    assign signal_lt_198 = signal_add_20 < signal_const_362;
    assign signal_not_35 = ~ signal_lt_198;
    assign signal_mux_353 = signal_not_35 ? signal_sub_188 : signal_add_20;
    assign signal_select_2181 = signal_mux_353[4:0];
    always @* begin
        case (signal_select_2181)
        0:
            signal_mux_354 <= signal_select_2180;
        1:
            signal_mux_354 <= signal_select_2179;
        2:
            signal_mux_354 <= signal_select_2178;
        3:
            signal_mux_354 <= signal_select_2177;
        4:
            signal_mux_354 <= signal_select_2176;
        5:
            signal_mux_354 <= signal_select_2175;
        6:
            signal_mux_354 <= signal_select_2174;
        7:
            signal_mux_354 <= signal_select_2173;
        8:
            signal_mux_354 <= signal_select_2172;
        9:
            signal_mux_354 <= signal_select_2171;
        10:
            signal_mux_354 <= signal_select_2170;
        11:
            signal_mux_354 <= signal_select_2169;
        12:
            signal_mux_354 <= signal_select_2168;
        13:
            signal_mux_354 <= signal_select_2167;
        14:
            signal_mux_354 <= signal_select_2166;
        15:
            signal_mux_354 <= signal_select_2165;
        16:
            signal_mux_354 <= signal_select_2164;
        17:
            signal_mux_354 <= signal_select_2163;
        18:
            signal_mux_354 <= signal_select_2162;
        default:
            signal_mux_354 <= signal_select_2161;
        endcase
    end
    assign signal_lt_199 = signal_const_43 < d$shift_count;
    assign signal_and_47 = signal_lt_199 & signal_mux_354;
    assign signal_cat_303 = { signal_and_47,
                              signal_and_46,
                              signal_and_45,
                              signal_and_44,
                              signal_and_43,
                              signal_and_42,
                              signal_and_41,
                              signal_and_40,
                              signal_and_39,
                              signal_and_38,
                              signal_and_37,
                              signal_and_36,
                              signal_and_35,
                              signal_and_34,
                              signal_and_33,
                              signal_and_32 };
    always @* begin
        case (d$out_dest$binary_variant)
        0:
            signal_mux_355 <= signal_cat_303;
        1:
            signal_mux_355 <= x_0;
        2:
            signal_mux_355 <= y_0;
        3:
            signal_mux_355 <= signal_const_196;
        4:
            signal_mux_355 <= isr_0;
        5:
            signal_mux_355 <= osr_0;
        6:
            signal_mux_355 <= crc_0;
        default:
            signal_mux_355 <= signal_select_1816;
        endcase
    end
    assign in_value = signal_mux_355 & mask;
    assign signal_select_2182 = signal_mux_358[7:0];
    assign signal_cat_304 = { signal_select_2182,
                              signal_const_227 };
    assign signal_select_2183 = signal_mux_357[11:0];
    assign signal_cat_305 = { signal_select_2183,
                              signal_const_310 };
    assign signal_select_2184 = signal_mux_356[13:0];
    assign signal_cat_306 = { signal_select_2184,
                              signal_const_257 };
    assign signal_select_2185 = isr_0[14:0];
    assign signal_cat_307 = { signal_select_2185,
                              signal_const_3 };
    assign signal_select_2186 = d$shift_count[0:0];
    assign signal_mux_356 = signal_select_2186 ? signal_cat_307 : isr_0;
    assign signal_select_2187 = d$shift_count[1:1];
    assign signal_mux_357 = signal_select_2187 ? signal_cat_306 : signal_mux_356;
    assign signal_select_2188 = d$shift_count[2:2];
    assign signal_mux_358 = signal_select_2188 ? signal_cat_305 : signal_mux_357;
    assign signal_select_2189 = d$shift_count[3:3];
    assign signal_mux_359 = signal_select_2189 ? signal_cat_304 : signal_mux_358;
    assign signal_select_2190 = d$shift_count[4:4];
    assign signal_mux_360 = signal_select_2190 ? signal_const_196 : signal_mux_359;
    assign signal_or_4 = signal_mux_360 | in_value;
    assign signal_wire_22 = config$in_shift_right;
    assign isr_shifted = signal_wire_22 ? signal_or_2 : signal_or_4;
    assign signal_wire_23 = config$push_threshold;
    assign signal_select_2191 = signal_add_21[4:0];
    assign signal_cat_308 = { gnd,
                              d$shift_count };
    assign signal_eq_39 = d$sys_op$binary_variant == signal_const_225;
    assign signal_and_48 = is_opcode$7 & signal_eq_39;
    assign signal_mux_361 = signal_and_48 ? osr_count_zero : isr_count_0;
    assign signal_eq_40 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_362 = signal_eq_40 ? osr_count_zero : isr_count_0;
    assign signal_eq_41 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_363 = signal_eq_41 ? d$shift_count : isr_count_0;
    assign signal_mux_364 = autopush_now ? osr_count_zero : isr_count_next;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_count_next_value <= isr_count_0;
        1:
            isr_count_next_value <= isr_count_0;
        2:
            isr_count_next_value <= signal_mux_364;
        3:
            isr_count_next_value <= signal_mux_363;
        4:
            isr_count_next_value <= signal_mux_362;
        5:
            isr_count_next_value <= isr_count_0;
        6:
            isr_count_next_value <= isr_count_0;
        default:
            isr_count_next_value <= signal_mux_361;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_13 <= signal_const_205;
        else
            if (go)
                signal_reg_13 <= isr_count_next_value;
    end
    assign isr_count_0 = signal_reg_13;
    assign signal_cat_309 = { gnd,
                              isr_count_0 };
    assign signal_add_21 = signal_cat_309 + signal_cat_308;
    assign signal_lt_200 = signal_const_45 < signal_add_21;
    assign isr_count_next = signal_lt_200 ? signal_const_46 : signal_select_2191;
    assign signal_lt_201 = isr_count_next < signal_wire_23;
    assign signal_not_36 = ~ signal_lt_201;
    assign signal_wire_24 = config$autopush;
    assign autopush_now = signal_wire_24 & signal_not_36;
    assign signal_mux_365 = autopush_now ? signal_const_196 : isr_shifted;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_next <= isr_0;
        1:
            isr_next <= isr_0;
        2:
            isr_next <= signal_mux_365;
        3:
            isr_next <= signal_mux_289;
        4:
            isr_next <= signal_mux_288;
        5:
            isr_next <= isr_0;
        6:
            isr_next <= isr_0;
        default:
            isr_next <= signal_mux_287;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_14 <= signal_const_196;
        else
            if (go)
                signal_reg_14 <= isr_next;
    end
    assign isr_0 = signal_reg_14;
    assign signal_xor_6 = p_0 ^ alu_operand;
    assign signal_sub_189 = p_0 - alu_operand;
    assign signal_add_22 = p_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_366 <= signal_add_22;
        1:
            signal_mux_366 <= signal_sub_189;
        default:
            signal_mux_366 <= signal_xor_6;
        endcase
    end
    assign signal_eq_42 = d$alu_dest$binary_variant == signal_const_233;
    assign signal_mux_367 = signal_eq_42 ? signal_mux_366 : p_0;
    assign signal_cat_310 = { signal_const_53,
                              d$set_value };
    assign signal_eq_43 = d$set_dest$binary_variant == signal_const;
    assign signal_mux_368 = signal_eq_43 ? signal_cat_310 : p_0;
    assign signal_eq_44 = d$mov_dest$binary_variant == signal_const_2;
    assign signal_mux_369 = signal_eq_44 ? mov_value : p_0;
    assign signal_eq_45 = d$out_dest$binary_variant == signal_const_2;
    assign signal_mux_370 = signal_eq_45 ? out_value : p_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            p_next <= p_0;
        1:
            p_next <= p_0;
        2:
            p_next <= p_0;
        3:
            p_next <= signal_mux_370;
        4:
            p_next <= signal_mux_369;
        5:
            p_next <= signal_mux_368;
        6:
            p_next <= signal_mux_367;
        default:
            p_next <= p_0;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_15 <= signal_const_196;
        else
            if (go)
                signal_reg_15 <= p_next;
    end
    assign p_0 = signal_reg_15;
    assign signal_xor_7 = y_0 ^ alu_operand;
    assign signal_sub_190 = y_0 - alu_operand;
    assign signal_add_23 = y_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_371 <= signal_add_23;
        1:
            signal_mux_371 <= signal_sub_190;
        default:
            signal_mux_371 <= signal_xor_7;
        endcase
    end
    assign signal_const_443 = 2'b01;
    assign signal_eq_46 = d$alu_dest$binary_variant == signal_const_443;
    assign signal_mux_372 = signal_eq_46 ? signal_mux_371 : y_0;
    assign signal_cat_311 = { signal_const_53,
                              d$set_value };
    assign signal_eq_47 = d$set_dest$binary_variant == signal_const_9;
    assign signal_mux_373 = signal_eq_47 ? signal_cat_311 : y_0;
    assign signal_eq_48 = d$mov_dest$binary_variant == signal_const_9;
    assign signal_mux_374 = signal_eq_48 ? mov_value : y_0;
    assign signal_eq_49 = d$out_dest$binary_variant == signal_const_9;
    assign signal_mux_375 = signal_eq_49 ? out_value : y_0;
    assign signal_const_448 = 16'b0000000000000001;
    assign signal_sub_191 = y_0 - signal_const_448;
    assign signal_eq_50 = d$jmp_cond$binary_variant == signal_const_9;
    assign signal_mux_376 = signal_eq_50 ? signal_sub_191 : y_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            y_next <= signal_mux_376;
        1:
            y_next <= y_0;
        2:
            y_next <= y_0;
        3:
            y_next <= signal_mux_375;
        4:
            y_next <= signal_mux_374;
        5:
            y_next <= signal_mux_373;
        6:
            y_next <= signal_mux_372;
        default:
            y_next <= y_0;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_16 <= signal_const_196;
        else
            if (go)
                signal_reg_16 <= y_next;
    end
    assign y_0 = signal_reg_16;
    always @* begin
        case (d$alu_reg$binary_variant)
        0:
            signal_mux_377 <= x_0;
        1:
            signal_mux_377 <= y_0;
        2:
            signal_mux_377 <= p_0;
        3:
            signal_mux_377 <= isr_0;
        default:
            signal_mux_377 <= osr_0;
        endcase
    end
    assign d$alu_reg$binary_variant = word[2:0];
    assign signal_const_450 = 13'b0000000000000;
    assign signal_cat_312 = { signal_const_450,
                              d$alu_reg$binary_variant };
    assign d$alu_is_reg = word[3:3];
    assign alu_operand = d$alu_is_reg ? signal_mux_377 : signal_cat_312;
    assign signal_add_24 = x_0 + alu_operand;
    assign d$alu_op$binary_variant = word[5:4];
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_378 <= signal_add_24;
        1:
            signal_mux_378 <= signal_sub_171;
        default:
            signal_mux_378 <= signal_xor_1;
        endcase
    end
    assign d$alu_dest$binary_variant = word[7:6];
    assign signal_eq_51 = d$alu_dest$binary_variant == signal_const_257;
    assign signal_mux_379 = signal_eq_51 ? signal_mux_378 : x_0;
    assign d$set_value = word[4:0];
    assign signal_cat_313 = { signal_const_53,
                              d$set_value };
    assign d$set_dest$binary_variant = word[7:5];
    assign signal_eq_52 = d$set_dest$binary_variant == signal_const_223;
    assign signal_mux_380 = signal_eq_52 ? signal_cat_313 : x_0;
    assign signal_eq_53 = d$mov_dest$binary_variant == signal_const_223;
    assign signal_mux_381 = signal_eq_53 ? mov_value : x_0;
    assign signal_eq_54 = d$out_dest$binary_variant == signal_const_223;
    assign signal_mux_382 = signal_eq_54 ? out_value : x_0;
    assign signal_sub_192 = x_0 - signal_const_448;
    assign d$jmp_cond$binary_variant = word[12:10];
    assign signal_eq_55 = d$jmp_cond$binary_variant == signal_const_223;
    assign signal_mux_383 = signal_eq_55 ? signal_sub_192 : x_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            x_next <= signal_mux_383;
        1:
            x_next <= x_0;
        2:
            x_next <= x_0;
        3:
            x_next <= signal_mux_382;
        4:
            x_next <= signal_mux_381;
        5:
            x_next <= signal_mux_380;
        6:
            x_next <= signal_mux_379;
        default:
            x_next <= x_0;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_17 <= signal_const_196;
        else
            if (go)
                signal_reg_17 <= x_next;
    end
    assign x_0 = signal_reg_17;
    assign signal_cat_314 = { signal_const_227,
                              x_0 };
    assign signal_select_2192 = sample[19:19];
    assign signal_select_2193 = sample[18:18];
    assign signal_select_2194 = sample[17:17];
    assign signal_select_2195 = sample[16:16];
    assign signal_select_2196 = sample[15:15];
    assign signal_select_2197 = sample[14:14];
    assign signal_select_2198 = sample[13:13];
    assign signal_select_2199 = sample[12:12];
    assign signal_select_2200 = sample[11:11];
    assign signal_select_2201 = sample[10:10];
    assign signal_select_2202 = sample[9:9];
    assign signal_select_2203 = sample[8:8];
    assign signal_select_2204 = sample[7:7];
    assign signal_select_2205 = sample[6:6];
    assign signal_select_2206 = sample[5:5];
    assign signal_select_2207 = sample[4:4];
    assign signal_select_2208 = sample[3:3];
    assign signal_select_2209 = sample[2:2];
    assign signal_select_2210 = sample[1:1];
    assign signal_select_2211 = sample[0:0];
    assign signal_sub_193 = signal_cat_315 - signal_const_362;
    assign signal_cat_315 = { gnd,
                              signal_wire_25 };
    assign signal_lt_202 = signal_cat_315 < signal_const_362;
    assign signal_not_37 = ~ signal_lt_202;
    assign signal_mux_384 = signal_not_37 ? signal_sub_193 : signal_cat_315;
    assign signal_select_2212 = signal_mux_384[4:0];
    always @* begin
        case (signal_select_2212)
        0:
            signal_mux_385 <= signal_select_2211;
        1:
            signal_mux_385 <= signal_select_2210;
        2:
            signal_mux_385 <= signal_select_2209;
        3:
            signal_mux_385 <= signal_select_2208;
        4:
            signal_mux_385 <= signal_select_2207;
        5:
            signal_mux_385 <= signal_select_2206;
        6:
            signal_mux_385 <= signal_select_2205;
        7:
            signal_mux_385 <= signal_select_2204;
        8:
            signal_mux_385 <= signal_select_2203;
        9:
            signal_mux_385 <= signal_select_2202;
        10:
            signal_mux_385 <= signal_select_2201;
        11:
            signal_mux_385 <= signal_select_2200;
        12:
            signal_mux_385 <= signal_select_2199;
        13:
            signal_mux_385 <= signal_select_2198;
        14:
            signal_mux_385 <= signal_select_2197;
        15:
            signal_mux_385 <= signal_select_2196;
        16:
            signal_mux_385 <= signal_select_2195;
        17:
            signal_mux_385 <= signal_select_2194;
        18:
            signal_mux_385 <= signal_select_2193;
        default:
            signal_mux_385 <= signal_select_2192;
        endcase
    end
    assign signal_lt_203 = signal_const_205 < signal_wire_26;
    assign signal_and_49 = signal_lt_203 & signal_mux_385;
    assign signal_select_2213 = sample[19:19];
    assign signal_select_2214 = sample[18:18];
    assign signal_select_2215 = sample[17:17];
    assign signal_select_2216 = sample[16:16];
    assign signal_select_2217 = sample[15:15];
    assign signal_select_2218 = sample[14:14];
    assign signal_select_2219 = sample[13:13];
    assign signal_select_2220 = sample[12:12];
    assign signal_select_2221 = sample[11:11];
    assign signal_select_2222 = sample[10:10];
    assign signal_select_2223 = sample[9:9];
    assign signal_select_2224 = sample[8:8];
    assign signal_select_2225 = sample[7:7];
    assign signal_select_2226 = sample[6:6];
    assign signal_select_2227 = sample[5:5];
    assign signal_select_2228 = sample[4:4];
    assign signal_select_2229 = sample[3:3];
    assign signal_select_2230 = sample[2:2];
    assign signal_select_2231 = sample[1:1];
    assign signal_select_2232 = sample[0:0];
    assign signal_sub_194 = signal_add_25 - signal_const_362;
    assign signal_cat_316 = { gnd,
                              signal_wire_25 };
    assign signal_add_25 = signal_cat_316 + signal_const_367;
    assign signal_lt_204 = signal_add_25 < signal_const_362;
    assign signal_not_38 = ~ signal_lt_204;
    assign signal_mux_386 = signal_not_38 ? signal_sub_194 : signal_add_25;
    assign signal_select_2233 = signal_mux_386[4:0];
    always @* begin
        case (signal_select_2233)
        0:
            signal_mux_387 <= signal_select_2232;
        1:
            signal_mux_387 <= signal_select_2231;
        2:
            signal_mux_387 <= signal_select_2230;
        3:
            signal_mux_387 <= signal_select_2229;
        4:
            signal_mux_387 <= signal_select_2228;
        5:
            signal_mux_387 <= signal_select_2227;
        6:
            signal_mux_387 <= signal_select_2226;
        7:
            signal_mux_387 <= signal_select_2225;
        8:
            signal_mux_387 <= signal_select_2224;
        9:
            signal_mux_387 <= signal_select_2223;
        10:
            signal_mux_387 <= signal_select_2222;
        11:
            signal_mux_387 <= signal_select_2221;
        12:
            signal_mux_387 <= signal_select_2220;
        13:
            signal_mux_387 <= signal_select_2219;
        14:
            signal_mux_387 <= signal_select_2218;
        15:
            signal_mux_387 <= signal_select_2217;
        16:
            signal_mux_387 <= signal_select_2216;
        17:
            signal_mux_387 <= signal_select_2215;
        18:
            signal_mux_387 <= signal_select_2214;
        default:
            signal_mux_387 <= signal_select_2213;
        endcase
    end
    assign signal_lt_205 = signal_const_208 < signal_wire_26;
    assign signal_and_50 = signal_lt_205 & signal_mux_387;
    assign signal_select_2234 = sample[19:19];
    assign signal_select_2235 = sample[18:18];
    assign signal_select_2236 = sample[17:17];
    assign signal_select_2237 = sample[16:16];
    assign signal_select_2238 = sample[15:15];
    assign signal_select_2239 = sample[14:14];
    assign signal_select_2240 = sample[13:13];
    assign signal_select_2241 = sample[12:12];
    assign signal_select_2242 = sample[11:11];
    assign signal_select_2243 = sample[10:10];
    assign signal_select_2244 = sample[9:9];
    assign signal_select_2245 = sample[8:8];
    assign signal_select_2246 = sample[7:7];
    assign signal_select_2247 = sample[6:6];
    assign signal_select_2248 = sample[5:5];
    assign signal_select_2249 = sample[4:4];
    assign signal_select_2250 = sample[3:3];
    assign signal_select_2251 = sample[2:2];
    assign signal_select_2252 = sample[1:1];
    assign signal_select_2253 = sample[0:0];
    assign signal_sub_195 = signal_add_26 - signal_const_362;
    assign signal_cat_317 = { gnd,
                              signal_wire_25 };
    assign signal_add_26 = signal_cat_317 + signal_const_371;
    assign signal_lt_206 = signal_add_26 < signal_const_362;
    assign signal_not_39 = ~ signal_lt_206;
    assign signal_mux_388 = signal_not_39 ? signal_sub_195 : signal_add_26;
    assign signal_select_2254 = signal_mux_388[4:0];
    always @* begin
        case (signal_select_2254)
        0:
            signal_mux_389 <= signal_select_2253;
        1:
            signal_mux_389 <= signal_select_2252;
        2:
            signal_mux_389 <= signal_select_2251;
        3:
            signal_mux_389 <= signal_select_2250;
        4:
            signal_mux_389 <= signal_select_2249;
        5:
            signal_mux_389 <= signal_select_2248;
        6:
            signal_mux_389 <= signal_select_2247;
        7:
            signal_mux_389 <= signal_select_2246;
        8:
            signal_mux_389 <= signal_select_2245;
        9:
            signal_mux_389 <= signal_select_2244;
        10:
            signal_mux_389 <= signal_select_2243;
        11:
            signal_mux_389 <= signal_select_2242;
        12:
            signal_mux_389 <= signal_select_2241;
        13:
            signal_mux_389 <= signal_select_2240;
        14:
            signal_mux_389 <= signal_select_2239;
        15:
            signal_mux_389 <= signal_select_2238;
        16:
            signal_mux_389 <= signal_select_2237;
        17:
            signal_mux_389 <= signal_select_2236;
        18:
            signal_mux_389 <= signal_select_2235;
        default:
            signal_mux_389 <= signal_select_2234;
        endcase
    end
    assign signal_lt_207 = signal_const_372 < signal_wire_26;
    assign signal_and_51 = signal_lt_207 & signal_mux_389;
    assign signal_select_2255 = sample[19:19];
    assign signal_select_2256 = sample[18:18];
    assign signal_select_2257 = sample[17:17];
    assign signal_select_2258 = sample[16:16];
    assign signal_select_2259 = sample[15:15];
    assign signal_select_2260 = sample[14:14];
    assign signal_select_2261 = sample[13:13];
    assign signal_select_2262 = sample[12:12];
    assign signal_select_2263 = sample[11:11];
    assign signal_select_2264 = sample[10:10];
    assign signal_select_2265 = sample[9:9];
    assign signal_select_2266 = sample[8:8];
    assign signal_select_2267 = sample[7:7];
    assign signal_select_2268 = sample[6:6];
    assign signal_select_2269 = sample[5:5];
    assign signal_select_2270 = sample[4:4];
    assign signal_select_2271 = sample[3:3];
    assign signal_select_2272 = sample[2:2];
    assign signal_select_2273 = sample[1:1];
    assign signal_select_2274 = sample[0:0];
    assign signal_sub_196 = signal_add_27 - signal_const_362;
    assign signal_cat_318 = { gnd,
                              signal_wire_25 };
    assign signal_add_27 = signal_cat_318 + signal_const_375;
    assign signal_lt_208 = signal_add_27 < signal_const_362;
    assign signal_not_40 = ~ signal_lt_208;
    assign signal_mux_390 = signal_not_40 ? signal_sub_196 : signal_add_27;
    assign signal_select_2275 = signal_mux_390[4:0];
    always @* begin
        case (signal_select_2275)
        0:
            signal_mux_391 <= signal_select_2274;
        1:
            signal_mux_391 <= signal_select_2273;
        2:
            signal_mux_391 <= signal_select_2272;
        3:
            signal_mux_391 <= signal_select_2271;
        4:
            signal_mux_391 <= signal_select_2270;
        5:
            signal_mux_391 <= signal_select_2269;
        6:
            signal_mux_391 <= signal_select_2268;
        7:
            signal_mux_391 <= signal_select_2267;
        8:
            signal_mux_391 <= signal_select_2266;
        9:
            signal_mux_391 <= signal_select_2265;
        10:
            signal_mux_391 <= signal_select_2264;
        11:
            signal_mux_391 <= signal_select_2263;
        12:
            signal_mux_391 <= signal_select_2262;
        13:
            signal_mux_391 <= signal_select_2261;
        14:
            signal_mux_391 <= signal_select_2260;
        15:
            signal_mux_391 <= signal_select_2259;
        16:
            signal_mux_391 <= signal_select_2258;
        17:
            signal_mux_391 <= signal_select_2257;
        18:
            signal_mux_391 <= signal_select_2256;
        default:
            signal_mux_391 <= signal_select_2255;
        endcase
    end
    assign signal_lt_209 = signal_const_376 < signal_wire_26;
    assign signal_and_52 = signal_lt_209 & signal_mux_391;
    assign signal_select_2276 = sample[19:19];
    assign signal_select_2277 = sample[18:18];
    assign signal_select_2278 = sample[17:17];
    assign signal_select_2279 = sample[16:16];
    assign signal_select_2280 = sample[15:15];
    assign signal_select_2281 = sample[14:14];
    assign signal_select_2282 = sample[13:13];
    assign signal_select_2283 = sample[12:12];
    assign signal_select_2284 = sample[11:11];
    assign signal_select_2285 = sample[10:10];
    assign signal_select_2286 = sample[9:9];
    assign signal_select_2287 = sample[8:8];
    assign signal_select_2288 = sample[7:7];
    assign signal_select_2289 = sample[6:6];
    assign signal_select_2290 = sample[5:5];
    assign signal_select_2291 = sample[4:4];
    assign signal_select_2292 = sample[3:3];
    assign signal_select_2293 = sample[2:2];
    assign signal_select_2294 = sample[1:1];
    assign signal_select_2295 = sample[0:0];
    assign signal_sub_197 = signal_add_28 - signal_const_362;
    assign signal_cat_319 = { gnd,
                              signal_wire_25 };
    assign signal_add_28 = signal_cat_319 + signal_const_379;
    assign signal_lt_210 = signal_add_28 < signal_const_362;
    assign signal_not_41 = ~ signal_lt_210;
    assign signal_mux_392 = signal_not_41 ? signal_sub_197 : signal_add_28;
    assign signal_select_2296 = signal_mux_392[4:0];
    always @* begin
        case (signal_select_2296)
        0:
            signal_mux_393 <= signal_select_2295;
        1:
            signal_mux_393 <= signal_select_2294;
        2:
            signal_mux_393 <= signal_select_2293;
        3:
            signal_mux_393 <= signal_select_2292;
        4:
            signal_mux_393 <= signal_select_2291;
        5:
            signal_mux_393 <= signal_select_2290;
        6:
            signal_mux_393 <= signal_select_2289;
        7:
            signal_mux_393 <= signal_select_2288;
        8:
            signal_mux_393 <= signal_select_2287;
        9:
            signal_mux_393 <= signal_select_2286;
        10:
            signal_mux_393 <= signal_select_2285;
        11:
            signal_mux_393 <= signal_select_2284;
        12:
            signal_mux_393 <= signal_select_2283;
        13:
            signal_mux_393 <= signal_select_2282;
        14:
            signal_mux_393 <= signal_select_2281;
        15:
            signal_mux_393 <= signal_select_2280;
        16:
            signal_mux_393 <= signal_select_2279;
        17:
            signal_mux_393 <= signal_select_2278;
        18:
            signal_mux_393 <= signal_select_2277;
        default:
            signal_mux_393 <= signal_select_2276;
        endcase
    end
    assign signal_lt_211 = signal_const_380 < signal_wire_26;
    assign signal_and_53 = signal_lt_211 & signal_mux_393;
    assign signal_select_2297 = sample[19:19];
    assign signal_select_2298 = sample[18:18];
    assign signal_select_2299 = sample[17:17];
    assign signal_select_2300 = sample[16:16];
    assign signal_select_2301 = sample[15:15];
    assign signal_select_2302 = sample[14:14];
    assign signal_select_2303 = sample[13:13];
    assign signal_select_2304 = sample[12:12];
    assign signal_select_2305 = sample[11:11];
    assign signal_select_2306 = sample[10:10];
    assign signal_select_2307 = sample[9:9];
    assign signal_select_2308 = sample[8:8];
    assign signal_select_2309 = sample[7:7];
    assign signal_select_2310 = sample[6:6];
    assign signal_select_2311 = sample[5:5];
    assign signal_select_2312 = sample[4:4];
    assign signal_select_2313 = sample[3:3];
    assign signal_select_2314 = sample[2:2];
    assign signal_select_2315 = sample[1:1];
    assign signal_select_2316 = sample[0:0];
    assign signal_sub_198 = signal_add_29 - signal_const_362;
    assign signal_cat_320 = { gnd,
                              signal_wire_25 };
    assign signal_add_29 = signal_cat_320 + signal_const_12;
    assign signal_lt_212 = signal_add_29 < signal_const_362;
    assign signal_not_42 = ~ signal_lt_212;
    assign signal_mux_394 = signal_not_42 ? signal_sub_198 : signal_add_29;
    assign signal_select_2317 = signal_mux_394[4:0];
    always @* begin
        case (signal_select_2317)
        0:
            signal_mux_395 <= signal_select_2316;
        1:
            signal_mux_395 <= signal_select_2315;
        2:
            signal_mux_395 <= signal_select_2314;
        3:
            signal_mux_395 <= signal_select_2313;
        4:
            signal_mux_395 <= signal_select_2312;
        5:
            signal_mux_395 <= signal_select_2311;
        6:
            signal_mux_395 <= signal_select_2310;
        7:
            signal_mux_395 <= signal_select_2309;
        8:
            signal_mux_395 <= signal_select_2308;
        9:
            signal_mux_395 <= signal_select_2307;
        10:
            signal_mux_395 <= signal_select_2306;
        11:
            signal_mux_395 <= signal_select_2305;
        12:
            signal_mux_395 <= signal_select_2304;
        13:
            signal_mux_395 <= signal_select_2303;
        14:
            signal_mux_395 <= signal_select_2302;
        15:
            signal_mux_395 <= signal_select_2301;
        16:
            signal_mux_395 <= signal_select_2300;
        17:
            signal_mux_395 <= signal_select_2299;
        18:
            signal_mux_395 <= signal_select_2298;
        default:
            signal_mux_395 <= signal_select_2297;
        endcase
    end
    assign signal_lt_213 = signal_const_13 < signal_wire_26;
    assign signal_and_54 = signal_lt_213 & signal_mux_395;
    assign signal_select_2318 = sample[19:19];
    assign signal_select_2319 = sample[18:18];
    assign signal_select_2320 = sample[17:17];
    assign signal_select_2321 = sample[16:16];
    assign signal_select_2322 = sample[15:15];
    assign signal_select_2323 = sample[14:14];
    assign signal_select_2324 = sample[13:13];
    assign signal_select_2325 = sample[12:12];
    assign signal_select_2326 = sample[11:11];
    assign signal_select_2327 = sample[10:10];
    assign signal_select_2328 = sample[9:9];
    assign signal_select_2329 = sample[8:8];
    assign signal_select_2330 = sample[7:7];
    assign signal_select_2331 = sample[6:6];
    assign signal_select_2332 = sample[5:5];
    assign signal_select_2333 = sample[4:4];
    assign signal_select_2334 = sample[3:3];
    assign signal_select_2335 = sample[2:2];
    assign signal_select_2336 = sample[1:1];
    assign signal_select_2337 = sample[0:0];
    assign signal_sub_199 = signal_add_30 - signal_const_362;
    assign signal_cat_321 = { gnd,
                              signal_wire_25 };
    assign signal_add_30 = signal_cat_321 + signal_const_15;
    assign signal_lt_214 = signal_add_30 < signal_const_362;
    assign signal_not_43 = ~ signal_lt_214;
    assign signal_mux_396 = signal_not_43 ? signal_sub_199 : signal_add_30;
    assign signal_select_2338 = signal_mux_396[4:0];
    always @* begin
        case (signal_select_2338)
        0:
            signal_mux_397 <= signal_select_2337;
        1:
            signal_mux_397 <= signal_select_2336;
        2:
            signal_mux_397 <= signal_select_2335;
        3:
            signal_mux_397 <= signal_select_2334;
        4:
            signal_mux_397 <= signal_select_2333;
        5:
            signal_mux_397 <= signal_select_2332;
        6:
            signal_mux_397 <= signal_select_2331;
        7:
            signal_mux_397 <= signal_select_2330;
        8:
            signal_mux_397 <= signal_select_2329;
        9:
            signal_mux_397 <= signal_select_2328;
        10:
            signal_mux_397 <= signal_select_2327;
        11:
            signal_mux_397 <= signal_select_2326;
        12:
            signal_mux_397 <= signal_select_2325;
        13:
            signal_mux_397 <= signal_select_2324;
        14:
            signal_mux_397 <= signal_select_2323;
        15:
            signal_mux_397 <= signal_select_2322;
        16:
            signal_mux_397 <= signal_select_2321;
        17:
            signal_mux_397 <= signal_select_2320;
        18:
            signal_mux_397 <= signal_select_2319;
        default:
            signal_mux_397 <= signal_select_2318;
        endcase
    end
    assign signal_lt_215 = signal_const_16 < signal_wire_26;
    assign signal_and_55 = signal_lt_215 & signal_mux_397;
    assign signal_select_2339 = sample[19:19];
    assign signal_select_2340 = sample[18:18];
    assign signal_select_2341 = sample[17:17];
    assign signal_select_2342 = sample[16:16];
    assign signal_select_2343 = sample[15:15];
    assign signal_select_2344 = sample[14:14];
    assign signal_select_2345 = sample[13:13];
    assign signal_select_2346 = sample[12:12];
    assign signal_select_2347 = sample[11:11];
    assign signal_select_2348 = sample[10:10];
    assign signal_select_2349 = sample[9:9];
    assign signal_select_2350 = sample[8:8];
    assign signal_select_2351 = sample[7:7];
    assign signal_select_2352 = sample[6:6];
    assign signal_select_2353 = sample[5:5];
    assign signal_select_2354 = sample[4:4];
    assign signal_select_2355 = sample[3:3];
    assign signal_select_2356 = sample[2:2];
    assign signal_select_2357 = sample[1:1];
    assign signal_select_2358 = sample[0:0];
    assign signal_sub_200 = signal_add_31 - signal_const_362;
    assign signal_cat_322 = { gnd,
                              signal_wire_25 };
    assign signal_add_31 = signal_cat_322 + signal_const_18;
    assign signal_lt_216 = signal_add_31 < signal_const_362;
    assign signal_not_44 = ~ signal_lt_216;
    assign signal_mux_398 = signal_not_44 ? signal_sub_200 : signal_add_31;
    assign signal_select_2359 = signal_mux_398[4:0];
    always @* begin
        case (signal_select_2359)
        0:
            signal_mux_399 <= signal_select_2358;
        1:
            signal_mux_399 <= signal_select_2357;
        2:
            signal_mux_399 <= signal_select_2356;
        3:
            signal_mux_399 <= signal_select_2355;
        4:
            signal_mux_399 <= signal_select_2354;
        5:
            signal_mux_399 <= signal_select_2353;
        6:
            signal_mux_399 <= signal_select_2352;
        7:
            signal_mux_399 <= signal_select_2351;
        8:
            signal_mux_399 <= signal_select_2350;
        9:
            signal_mux_399 <= signal_select_2349;
        10:
            signal_mux_399 <= signal_select_2348;
        11:
            signal_mux_399 <= signal_select_2347;
        12:
            signal_mux_399 <= signal_select_2346;
        13:
            signal_mux_399 <= signal_select_2345;
        14:
            signal_mux_399 <= signal_select_2344;
        15:
            signal_mux_399 <= signal_select_2343;
        16:
            signal_mux_399 <= signal_select_2342;
        17:
            signal_mux_399 <= signal_select_2341;
        18:
            signal_mux_399 <= signal_select_2340;
        default:
            signal_mux_399 <= signal_select_2339;
        endcase
    end
    assign signal_lt_217 = signal_const_19 < signal_wire_26;
    assign signal_and_56 = signal_lt_217 & signal_mux_399;
    assign signal_select_2360 = sample[19:19];
    assign signal_select_2361 = sample[18:18];
    assign signal_select_2362 = sample[17:17];
    assign signal_select_2363 = sample[16:16];
    assign signal_select_2364 = sample[15:15];
    assign signal_select_2365 = sample[14:14];
    assign signal_select_2366 = sample[13:13];
    assign signal_select_2367 = sample[12:12];
    assign signal_select_2368 = sample[11:11];
    assign signal_select_2369 = sample[10:10];
    assign signal_select_2370 = sample[9:9];
    assign signal_select_2371 = sample[8:8];
    assign signal_select_2372 = sample[7:7];
    assign signal_select_2373 = sample[6:6];
    assign signal_select_2374 = sample[5:5];
    assign signal_select_2375 = sample[4:4];
    assign signal_select_2376 = sample[3:3];
    assign signal_select_2377 = sample[2:2];
    assign signal_select_2378 = sample[1:1];
    assign signal_select_2379 = sample[0:0];
    assign signal_sub_201 = signal_add_32 - signal_const_362;
    assign signal_cat_323 = { gnd,
                              signal_wire_25 };
    assign signal_add_32 = signal_cat_323 + signal_const_21;
    assign signal_lt_218 = signal_add_32 < signal_const_362;
    assign signal_not_45 = ~ signal_lt_218;
    assign signal_mux_400 = signal_not_45 ? signal_sub_201 : signal_add_32;
    assign signal_select_2380 = signal_mux_400[4:0];
    always @* begin
        case (signal_select_2380)
        0:
            signal_mux_401 <= signal_select_2379;
        1:
            signal_mux_401 <= signal_select_2378;
        2:
            signal_mux_401 <= signal_select_2377;
        3:
            signal_mux_401 <= signal_select_2376;
        4:
            signal_mux_401 <= signal_select_2375;
        5:
            signal_mux_401 <= signal_select_2374;
        6:
            signal_mux_401 <= signal_select_2373;
        7:
            signal_mux_401 <= signal_select_2372;
        8:
            signal_mux_401 <= signal_select_2371;
        9:
            signal_mux_401 <= signal_select_2370;
        10:
            signal_mux_401 <= signal_select_2369;
        11:
            signal_mux_401 <= signal_select_2368;
        12:
            signal_mux_401 <= signal_select_2367;
        13:
            signal_mux_401 <= signal_select_2366;
        14:
            signal_mux_401 <= signal_select_2365;
        15:
            signal_mux_401 <= signal_select_2364;
        16:
            signal_mux_401 <= signal_select_2363;
        17:
            signal_mux_401 <= signal_select_2362;
        18:
            signal_mux_401 <= signal_select_2361;
        default:
            signal_mux_401 <= signal_select_2360;
        endcase
    end
    assign signal_lt_219 = signal_const_22 < signal_wire_26;
    assign signal_and_57 = signal_lt_219 & signal_mux_401;
    assign signal_select_2381 = sample[19:19];
    assign signal_select_2382 = sample[18:18];
    assign signal_select_2383 = sample[17:17];
    assign signal_select_2384 = sample[16:16];
    assign signal_select_2385 = sample[15:15];
    assign signal_select_2386 = sample[14:14];
    assign signal_select_2387 = sample[13:13];
    assign signal_select_2388 = sample[12:12];
    assign signal_select_2389 = sample[11:11];
    assign signal_select_2390 = sample[10:10];
    assign signal_select_2391 = sample[9:9];
    assign signal_select_2392 = sample[8:8];
    assign signal_select_2393 = sample[7:7];
    assign signal_select_2394 = sample[6:6];
    assign signal_select_2395 = sample[5:5];
    assign signal_select_2396 = sample[4:4];
    assign signal_select_2397 = sample[3:3];
    assign signal_select_2398 = sample[2:2];
    assign signal_select_2399 = sample[1:1];
    assign signal_select_2400 = sample[0:0];
    assign signal_sub_202 = signal_add_33 - signal_const_362;
    assign signal_cat_324 = { gnd,
                              signal_wire_25 };
    assign signal_add_33 = signal_cat_324 + signal_const_24;
    assign signal_lt_220 = signal_add_33 < signal_const_362;
    assign signal_not_46 = ~ signal_lt_220;
    assign signal_mux_402 = signal_not_46 ? signal_sub_202 : signal_add_33;
    assign signal_select_2401 = signal_mux_402[4:0];
    always @* begin
        case (signal_select_2401)
        0:
            signal_mux_403 <= signal_select_2400;
        1:
            signal_mux_403 <= signal_select_2399;
        2:
            signal_mux_403 <= signal_select_2398;
        3:
            signal_mux_403 <= signal_select_2397;
        4:
            signal_mux_403 <= signal_select_2396;
        5:
            signal_mux_403 <= signal_select_2395;
        6:
            signal_mux_403 <= signal_select_2394;
        7:
            signal_mux_403 <= signal_select_2393;
        8:
            signal_mux_403 <= signal_select_2392;
        9:
            signal_mux_403 <= signal_select_2391;
        10:
            signal_mux_403 <= signal_select_2390;
        11:
            signal_mux_403 <= signal_select_2389;
        12:
            signal_mux_403 <= signal_select_2388;
        13:
            signal_mux_403 <= signal_select_2387;
        14:
            signal_mux_403 <= signal_select_2386;
        15:
            signal_mux_403 <= signal_select_2385;
        16:
            signal_mux_403 <= signal_select_2384;
        17:
            signal_mux_403 <= signal_select_2383;
        18:
            signal_mux_403 <= signal_select_2382;
        default:
            signal_mux_403 <= signal_select_2381;
        endcase
    end
    assign signal_lt_221 = signal_const_25 < signal_wire_26;
    assign signal_and_58 = signal_lt_221 & signal_mux_403;
    assign signal_select_2402 = sample[19:19];
    assign signal_select_2403 = sample[18:18];
    assign signal_select_2404 = sample[17:17];
    assign signal_select_2405 = sample[16:16];
    assign signal_select_2406 = sample[15:15];
    assign signal_select_2407 = sample[14:14];
    assign signal_select_2408 = sample[13:13];
    assign signal_select_2409 = sample[12:12];
    assign signal_select_2410 = sample[11:11];
    assign signal_select_2411 = sample[10:10];
    assign signal_select_2412 = sample[9:9];
    assign signal_select_2413 = sample[8:8];
    assign signal_select_2414 = sample[7:7];
    assign signal_select_2415 = sample[6:6];
    assign signal_select_2416 = sample[5:5];
    assign signal_select_2417 = sample[4:4];
    assign signal_select_2418 = sample[3:3];
    assign signal_select_2419 = sample[2:2];
    assign signal_select_2420 = sample[1:1];
    assign signal_select_2421 = sample[0:0];
    assign signal_sub_203 = signal_add_34 - signal_const_362;
    assign signal_cat_325 = { gnd,
                              signal_wire_25 };
    assign signal_add_34 = signal_cat_325 + signal_const_27;
    assign signal_lt_222 = signal_add_34 < signal_const_362;
    assign signal_not_47 = ~ signal_lt_222;
    assign signal_mux_404 = signal_not_47 ? signal_sub_203 : signal_add_34;
    assign signal_select_2422 = signal_mux_404[4:0];
    always @* begin
        case (signal_select_2422)
        0:
            signal_mux_405 <= signal_select_2421;
        1:
            signal_mux_405 <= signal_select_2420;
        2:
            signal_mux_405 <= signal_select_2419;
        3:
            signal_mux_405 <= signal_select_2418;
        4:
            signal_mux_405 <= signal_select_2417;
        5:
            signal_mux_405 <= signal_select_2416;
        6:
            signal_mux_405 <= signal_select_2415;
        7:
            signal_mux_405 <= signal_select_2414;
        8:
            signal_mux_405 <= signal_select_2413;
        9:
            signal_mux_405 <= signal_select_2412;
        10:
            signal_mux_405 <= signal_select_2411;
        11:
            signal_mux_405 <= signal_select_2410;
        12:
            signal_mux_405 <= signal_select_2409;
        13:
            signal_mux_405 <= signal_select_2408;
        14:
            signal_mux_405 <= signal_select_2407;
        15:
            signal_mux_405 <= signal_select_2406;
        16:
            signal_mux_405 <= signal_select_2405;
        17:
            signal_mux_405 <= signal_select_2404;
        18:
            signal_mux_405 <= signal_select_2403;
        default:
            signal_mux_405 <= signal_select_2402;
        endcase
    end
    assign signal_lt_223 = signal_const_28 < signal_wire_26;
    assign signal_and_59 = signal_lt_223 & signal_mux_405;
    assign signal_select_2423 = sample[19:19];
    assign signal_select_2424 = sample[18:18];
    assign signal_select_2425 = sample[17:17];
    assign signal_select_2426 = sample[16:16];
    assign signal_select_2427 = sample[15:15];
    assign signal_select_2428 = sample[14:14];
    assign signal_select_2429 = sample[13:13];
    assign signal_select_2430 = sample[12:12];
    assign signal_select_2431 = sample[11:11];
    assign signal_select_2432 = sample[10:10];
    assign signal_select_2433 = sample[9:9];
    assign signal_select_2434 = sample[8:8];
    assign signal_select_2435 = sample[7:7];
    assign signal_select_2436 = sample[6:6];
    assign signal_select_2437 = sample[5:5];
    assign signal_select_2438 = sample[4:4];
    assign signal_select_2439 = sample[3:3];
    assign signal_select_2440 = sample[2:2];
    assign signal_select_2441 = sample[1:1];
    assign signal_select_2442 = sample[0:0];
    assign signal_sub_204 = signal_add_35 - signal_const_362;
    assign signal_cat_326 = { gnd,
                              signal_wire_25 };
    assign signal_add_35 = signal_cat_326 + signal_const_30;
    assign signal_lt_224 = signal_add_35 < signal_const_362;
    assign signal_not_48 = ~ signal_lt_224;
    assign signal_mux_406 = signal_not_48 ? signal_sub_204 : signal_add_35;
    assign signal_select_2443 = signal_mux_406[4:0];
    always @* begin
        case (signal_select_2443)
        0:
            signal_mux_407 <= signal_select_2442;
        1:
            signal_mux_407 <= signal_select_2441;
        2:
            signal_mux_407 <= signal_select_2440;
        3:
            signal_mux_407 <= signal_select_2439;
        4:
            signal_mux_407 <= signal_select_2438;
        5:
            signal_mux_407 <= signal_select_2437;
        6:
            signal_mux_407 <= signal_select_2436;
        7:
            signal_mux_407 <= signal_select_2435;
        8:
            signal_mux_407 <= signal_select_2434;
        9:
            signal_mux_407 <= signal_select_2433;
        10:
            signal_mux_407 <= signal_select_2432;
        11:
            signal_mux_407 <= signal_select_2431;
        12:
            signal_mux_407 <= signal_select_2430;
        13:
            signal_mux_407 <= signal_select_2429;
        14:
            signal_mux_407 <= signal_select_2428;
        15:
            signal_mux_407 <= signal_select_2427;
        16:
            signal_mux_407 <= signal_select_2426;
        17:
            signal_mux_407 <= signal_select_2425;
        18:
            signal_mux_407 <= signal_select_2424;
        default:
            signal_mux_407 <= signal_select_2423;
        endcase
    end
    assign signal_lt_225 = signal_const_31 < signal_wire_26;
    assign signal_and_60 = signal_lt_225 & signal_mux_407;
    assign signal_select_2444 = sample[19:19];
    assign signal_select_2445 = sample[18:18];
    assign signal_select_2446 = sample[17:17];
    assign signal_select_2447 = sample[16:16];
    assign signal_select_2448 = sample[15:15];
    assign signal_select_2449 = sample[14:14];
    assign signal_select_2450 = sample[13:13];
    assign signal_select_2451 = sample[12:12];
    assign signal_select_2452 = sample[11:11];
    assign signal_select_2453 = sample[10:10];
    assign signal_select_2454 = sample[9:9];
    assign signal_select_2455 = sample[8:8];
    assign signal_select_2456 = sample[7:7];
    assign signal_select_2457 = sample[6:6];
    assign signal_select_2458 = sample[5:5];
    assign signal_select_2459 = sample[4:4];
    assign signal_select_2460 = sample[3:3];
    assign signal_select_2461 = sample[2:2];
    assign signal_select_2462 = sample[1:1];
    assign signal_select_2463 = sample[0:0];
    assign signal_sub_205 = signal_add_36 - signal_const_362;
    assign signal_cat_327 = { gnd,
                              signal_wire_25 };
    assign signal_add_36 = signal_cat_327 + signal_const_33;
    assign signal_lt_226 = signal_add_36 < signal_const_362;
    assign signal_not_49 = ~ signal_lt_226;
    assign signal_mux_408 = signal_not_49 ? signal_sub_205 : signal_add_36;
    assign signal_select_2464 = signal_mux_408[4:0];
    always @* begin
        case (signal_select_2464)
        0:
            signal_mux_409 <= signal_select_2463;
        1:
            signal_mux_409 <= signal_select_2462;
        2:
            signal_mux_409 <= signal_select_2461;
        3:
            signal_mux_409 <= signal_select_2460;
        4:
            signal_mux_409 <= signal_select_2459;
        5:
            signal_mux_409 <= signal_select_2458;
        6:
            signal_mux_409 <= signal_select_2457;
        7:
            signal_mux_409 <= signal_select_2456;
        8:
            signal_mux_409 <= signal_select_2455;
        9:
            signal_mux_409 <= signal_select_2454;
        10:
            signal_mux_409 <= signal_select_2453;
        11:
            signal_mux_409 <= signal_select_2452;
        12:
            signal_mux_409 <= signal_select_2451;
        13:
            signal_mux_409 <= signal_select_2450;
        14:
            signal_mux_409 <= signal_select_2449;
        15:
            signal_mux_409 <= signal_select_2448;
        16:
            signal_mux_409 <= signal_select_2447;
        17:
            signal_mux_409 <= signal_select_2446;
        18:
            signal_mux_409 <= signal_select_2445;
        default:
            signal_mux_409 <= signal_select_2444;
        endcase
    end
    assign signal_lt_227 = signal_const_34 < signal_wire_26;
    assign signal_and_61 = signal_lt_227 & signal_mux_409;
    assign signal_select_2465 = sample[19:19];
    assign signal_select_2466 = sample[18:18];
    assign signal_select_2467 = sample[17:17];
    assign signal_select_2468 = sample[16:16];
    assign signal_select_2469 = sample[15:15];
    assign signal_select_2470 = sample[14:14];
    assign signal_select_2471 = sample[13:13];
    assign signal_select_2472 = sample[12:12];
    assign signal_select_2473 = sample[11:11];
    assign signal_select_2474 = sample[10:10];
    assign signal_select_2475 = sample[9:9];
    assign signal_select_2476 = sample[8:8];
    assign signal_select_2477 = sample[7:7];
    assign signal_select_2478 = sample[6:6];
    assign signal_select_2479 = sample[5:5];
    assign signal_select_2480 = sample[4:4];
    assign signal_select_2481 = sample[3:3];
    assign signal_select_2482 = sample[2:2];
    assign signal_select_2483 = sample[1:1];
    assign signal_select_2484 = sample[0:0];
    assign signal_sub_206 = signal_add_37 - signal_const_362;
    assign signal_cat_328 = { gnd,
                              signal_wire_25 };
    assign signal_add_37 = signal_cat_328 + signal_const_36;
    assign signal_lt_228 = signal_add_37 < signal_const_362;
    assign signal_not_50 = ~ signal_lt_228;
    assign signal_mux_410 = signal_not_50 ? signal_sub_206 : signal_add_37;
    assign signal_select_2485 = signal_mux_410[4:0];
    always @* begin
        case (signal_select_2485)
        0:
            signal_mux_411 <= signal_select_2484;
        1:
            signal_mux_411 <= signal_select_2483;
        2:
            signal_mux_411 <= signal_select_2482;
        3:
            signal_mux_411 <= signal_select_2481;
        4:
            signal_mux_411 <= signal_select_2480;
        5:
            signal_mux_411 <= signal_select_2479;
        6:
            signal_mux_411 <= signal_select_2478;
        7:
            signal_mux_411 <= signal_select_2477;
        8:
            signal_mux_411 <= signal_select_2476;
        9:
            signal_mux_411 <= signal_select_2475;
        10:
            signal_mux_411 <= signal_select_2474;
        11:
            signal_mux_411 <= signal_select_2473;
        12:
            signal_mux_411 <= signal_select_2472;
        13:
            signal_mux_411 <= signal_select_2471;
        14:
            signal_mux_411 <= signal_select_2470;
        15:
            signal_mux_411 <= signal_select_2469;
        16:
            signal_mux_411 <= signal_select_2468;
        17:
            signal_mux_411 <= signal_select_2467;
        18:
            signal_mux_411 <= signal_select_2466;
        default:
            signal_mux_411 <= signal_select_2465;
        endcase
    end
    assign signal_lt_229 = signal_const_37 < signal_wire_26;
    assign signal_and_62 = signal_lt_229 & signal_mux_411;
    assign signal_select_2486 = sample[19:19];
    assign signal_select_2487 = sample[18:18];
    assign signal_select_2488 = sample[17:17];
    assign signal_select_2489 = sample[16:16];
    assign signal_select_2490 = sample[15:15];
    assign signal_select_2491 = sample[14:14];
    assign signal_select_2492 = sample[13:13];
    assign signal_select_2493 = sample[12:12];
    assign signal_select_2494 = sample[11:11];
    assign signal_select_2495 = sample[10:10];
    assign signal_select_2496 = sample[9:9];
    assign signal_select_2497 = sample[8:8];
    assign signal_select_2498 = sample[7:7];
    assign signal_select_2499 = sample[6:6];
    assign signal_select_2500 = sample[5:5];
    assign signal_select_2501 = sample[4:4];
    assign signal_select_2502 = sample[3:3];
    assign signal_select_2503 = sample[2:2];
    assign signal_select_2504 = sample[1:1];
    assign signal_select_2505 = sample[0:0];
    assign signal_sub_207 = signal_add_38 - signal_const_362;
    assign signal_cat_329 = { gnd,
                              signal_wire_25 };
    assign signal_add_38 = signal_cat_329 + signal_const_39;
    assign signal_lt_230 = signal_add_38 < signal_const_362;
    assign signal_not_51 = ~ signal_lt_230;
    assign signal_mux_412 = signal_not_51 ? signal_sub_207 : signal_add_38;
    assign signal_select_2506 = signal_mux_412[4:0];
    always @* begin
        case (signal_select_2506)
        0:
            signal_mux_413 <= signal_select_2505;
        1:
            signal_mux_413 <= signal_select_2504;
        2:
            signal_mux_413 <= signal_select_2503;
        3:
            signal_mux_413 <= signal_select_2502;
        4:
            signal_mux_413 <= signal_select_2501;
        5:
            signal_mux_413 <= signal_select_2500;
        6:
            signal_mux_413 <= signal_select_2499;
        7:
            signal_mux_413 <= signal_select_2498;
        8:
            signal_mux_413 <= signal_select_2497;
        9:
            signal_mux_413 <= signal_select_2496;
        10:
            signal_mux_413 <= signal_select_2495;
        11:
            signal_mux_413 <= signal_select_2494;
        12:
            signal_mux_413 <= signal_select_2493;
        13:
            signal_mux_413 <= signal_select_2492;
        14:
            signal_mux_413 <= signal_select_2491;
        15:
            signal_mux_413 <= signal_select_2490;
        16:
            signal_mux_413 <= signal_select_2489;
        17:
            signal_mux_413 <= signal_select_2488;
        18:
            signal_mux_413 <= signal_select_2487;
        default:
            signal_mux_413 <= signal_select_2486;
        endcase
    end
    assign signal_lt_231 = signal_const_40 < signal_wire_26;
    assign signal_and_63 = signal_lt_231 & signal_mux_413;
    assign signal_select_2507 = sample[19:19];
    assign signal_select_2508 = sample[18:18];
    assign signal_select_2509 = sample[17:17];
    assign signal_select_2510 = sample[16:16];
    assign signal_select_2511 = sample[15:15];
    assign signal_select_2512 = sample[14:14];
    assign signal_select_2513 = sample[13:13];
    assign signal_select_2514 = sample[12:12];
    assign signal_select_2515 = sample[11:11];
    assign signal_select_2516 = sample[10:10];
    assign signal_select_2517 = sample[9:9];
    assign signal_select_2518 = sample[8:8];
    assign signal_select_2519 = sample[7:7];
    assign signal_select_2520 = sample[6:6];
    assign signal_select_2521 = sample[5:5];
    assign signal_select_2522 = sample[4:4];
    assign signal_select_2523 = sample[3:3];
    assign signal_select_2524 = sample[2:2];
    assign signal_select_2525 = sample[1:1];
    assign signal_select_2526 = sample[0:0];
    assign signal_sub_208 = signal_add_39 - signal_const_362;
    assign signal_wire_25 = config$in_base;
    assign signal_cat_330 = { gnd,
                              signal_wire_25 };
    assign signal_add_39 = signal_cat_330 + signal_const_42;
    assign signal_lt_232 = signal_add_39 < signal_const_362;
    assign signal_not_52 = ~ signal_lt_232;
    assign signal_mux_414 = signal_not_52 ? signal_sub_208 : signal_add_39;
    assign signal_select_2527 = signal_mux_414[4:0];
    always @* begin
        case (signal_select_2527)
        0:
            signal_mux_415 <= signal_select_2526;
        1:
            signal_mux_415 <= signal_select_2525;
        2:
            signal_mux_415 <= signal_select_2524;
        3:
            signal_mux_415 <= signal_select_2523;
        4:
            signal_mux_415 <= signal_select_2522;
        5:
            signal_mux_415 <= signal_select_2521;
        6:
            signal_mux_415 <= signal_select_2520;
        7:
            signal_mux_415 <= signal_select_2519;
        8:
            signal_mux_415 <= signal_select_2518;
        9:
            signal_mux_415 <= signal_select_2517;
        10:
            signal_mux_415 <= signal_select_2516;
        11:
            signal_mux_415 <= signal_select_2515;
        12:
            signal_mux_415 <= signal_select_2514;
        13:
            signal_mux_415 <= signal_select_2513;
        14:
            signal_mux_415 <= signal_select_2512;
        15:
            signal_mux_415 <= signal_select_2511;
        16:
            signal_mux_415 <= signal_select_2510;
        17:
            signal_mux_415 <= signal_select_2509;
        18:
            signal_mux_415 <= signal_select_2508;
        default:
            signal_mux_415 <= signal_select_2507;
        endcase
    end
    assign signal_wire_26 = config$in_count;
    assign signal_lt_233 = signal_const_43 < signal_wire_26;
    assign signal_and_64 = signal_lt_233 & signal_mux_415;
    assign signal_cat_331 = { signal_and_64,
                              signal_and_63,
                              signal_and_62,
                              signal_and_61,
                              signal_and_60,
                              signal_and_59,
                              signal_and_58,
                              signal_and_57,
                              signal_and_56,
                              signal_and_55,
                              signal_and_54,
                              signal_and_53,
                              signal_and_52,
                              signal_and_51,
                              signal_and_50,
                              signal_and_49 };
    assign signal_cat_332 = { signal_const_227,
                              signal_cat_331 };
    assign d$mov_source$binary_variant = word[2:0];
    always @* begin
        case (d$mov_source$binary_variant)
        0:
            mov_value24 <= signal_cat_332;
        1:
            mov_value24 <= signal_cat_314;
        2:
            mov_value24 <= signal_cat_270;
        3:
            mov_value24 <= signal_const_4;
        4:
            mov_value24 <= signal_cat_269;
        5:
            mov_value24 <= signal_cat_268;
        6:
            mov_value24 <= now_0;
        default:
            mov_value24 <= capture_0;
        endcase
    end
    assign signal_select_2528 = mov_value24[15:0];
    assign d$mov_op$binary_variant = word[4:3];
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value <= signal_select_2528;
        1:
            mov_value <= signal_not_17;
        default:
            mov_value <= signal_cat_267;
        endcase
    end
    assign signal_eq_56 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_416 = signal_eq_56 ? mov_value : osr_0;
    assign signal_select_2529 = signal_mux_419[15:8];
    assign signal_cat_333 = { signal_const_227,
                              signal_select_2529 };
    assign signal_select_2530 = signal_mux_418[15:4];
    assign signal_cat_334 = { signal_const_310,
                              signal_select_2530 };
    assign signal_select_2531 = signal_mux_417[15:2];
    assign signal_cat_335 = { signal_const_257,
                              signal_select_2531 };
    assign signal_select_2532 = osr_before[15:1];
    assign signal_cat_336 = { signal_const_3,
                              signal_select_2532 };
    assign signal_select_2533 = d$shift_count[0:0];
    assign signal_mux_417 = signal_select_2533 ? signal_cat_336 : osr_before;
    assign signal_select_2534 = d$shift_count[1:1];
    assign signal_mux_418 = signal_select_2534 ? signal_cat_335 : signal_mux_417;
    assign signal_select_2535 = d$shift_count[2:2];
    assign signal_mux_419 = signal_select_2535 ? signal_cat_334 : signal_mux_418;
    assign signal_select_2536 = d$shift_count[3:3];
    assign signal_mux_420 = signal_select_2536 ? signal_cat_333 : signal_mux_419;
    assign signal_select_2537 = d$shift_count[4:4];
    assign signal_mux_421 = signal_select_2537 ? signal_const_196 : signal_mux_420;
    assign signal_select_2538 = signal_mux_424[7:0];
    assign signal_cat_337 = { signal_select_2538,
                              signal_const_227 };
    assign signal_select_2539 = signal_mux_423[11:0];
    assign signal_cat_338 = { signal_select_2539,
                              signal_const_310 };
    assign signal_select_2540 = signal_mux_422[13:0];
    assign signal_cat_339 = { signal_select_2540,
                              signal_const_257 };
    assign signal_select_2541 = osr_before[14:0];
    assign signal_cat_340 = { signal_select_2541,
                              signal_const_3 };
    assign signal_select_2542 = d$shift_count[0:0];
    assign signal_mux_422 = signal_select_2542 ? signal_cat_340 : osr_before;
    assign signal_select_2543 = d$shift_count[1:1];
    assign signal_mux_423 = signal_select_2543 ? signal_cat_339 : signal_mux_422;
    assign signal_select_2544 = d$shift_count[2:2];
    assign signal_mux_424 = signal_select_2544 ? signal_cat_338 : signal_mux_423;
    assign signal_select_2545 = d$shift_count[3:3];
    assign signal_mux_425 = signal_select_2545 ? signal_cat_337 : signal_mux_424;
    assign signal_select_2546 = d$shift_count[4:4];
    assign signal_mux_426 = signal_select_2546 ? signal_const_196 : signal_mux_425;
    assign osr_shifted = signal_wire_31 ? signal_mux_421 : signal_mux_426;
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
            osr_next <= signal_mux_416;
        5:
            osr_next <= osr_0;
        6:
            osr_next <= osr_0;
        default:
            osr_next <= signal_mux_286;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_18 <= signal_const_196;
        else
            if (go)
                signal_reg_18 <= osr_next;
    end
    assign osr_0 = signal_reg_18;
    assign signal_not_53 = ~ signal_select_2547;
    assign signal_and_65 = pulls & signal_not_53;
    assign signal_eq_57 = signal_select_2729 == signal_const_225;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            is_opcode$3 <= gnd;
        else
            if (ir_load)
                is_opcode$3 <= signal_eq_57;
    end
    assign signal_and_66 = is_opcode$3 & pull_ok;
    assign signal_or_5 = signal_and_66 | signal_and_65;
    assign signal_and_67 = op_go & signal_or_5;
    assign tx_pop = signal_and_67;
    assign signal_wire_27 = tx$value;
    assign signal_wire_28 = tx$valid;
    host_fifo
        tx
        ( .clock(signal_wire_39),
          .clear(signal_wire_36),
          .push$valid(signal_wire_28),
          .push$value(signal_wire_27),
          .pop(tx_pop),
          .head(signal_inst_1[15:0]),
          .level(signal_inst_1[18:16]),
          .empty(signal_inst_1[19:19]),
          .full(signal_inst_1[20:20]) );
    assign signal_select_2547 = signal_inst_1[19:19];
    assign signal_not_54 = ~ signal_select_2547;
    assign signal_wire_29 = config$pull_threshold;
    assign d$sys_op$binary_variant = word[2:0];
    assign signal_eq_58 = d$sys_op$binary_variant == signal_const;
    assign signal_eq_59 = signal_select_2729 == signal_const_229;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            is_opcode$7 <= gnd;
        else
            if (ir_load)
                is_opcode$7 <= signal_eq_59;
    end
    assign pulls = is_opcode$7 & signal_eq_58;
    assign signal_mux_427 = pulls ? osr_count_zero : osr_count_0;
    assign osr_count_zero = 5'b00000;
    assign d$mov_dest$binary_variant = word[7:5];
    assign signal_eq_60 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_428 = signal_eq_60 ? osr_count_zero : osr_count_0;
    assign signal_select_2548 = signal_add_40[4:0];
    assign signal_cat_341 = { gnd,
                              d$shift_count };
    assign osr_count_before = pull_now ? signal_const_205 : osr_count_0;
    assign signal_cat_342 = { gnd,
                              osr_count_before };
    assign signal_add_40 = signal_cat_342 + signal_cat_341;
    assign signal_lt_234 = signal_const_45 < signal_add_40;
    assign osr_count_next = signal_lt_234 ? signal_const_46 : signal_select_2548;
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
            osr_count_next_value <= signal_mux_428;
        5:
            osr_count_next_value <= osr_count_0;
        6:
            osr_count_next_value <= osr_count_0;
        default:
            osr_count_next_value <= signal_mux_427;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_19 <= signal_const_46;
        else
            if (go)
                signal_reg_19 <= osr_count_next_value;
    end
    assign osr_count_0 = signal_reg_19;
    assign signal_lt_235 = osr_count_0 < signal_wire_29;
    assign signal_not_55 = ~ signal_lt_235;
    assign signal_wire_30 = config$autopull;
    assign pull_now = signal_wire_30 & signal_not_55;
    assign pull_ok = pull_now & signal_not_54;
    assign osr_before = pull_ok ? signal_select_1713 : osr_0;
    assign signal_select_2549 = shift_back[0:0];
    assign signal_mux_429 = signal_select_2549 ? signal_cat_266 : osr_before;
    assign signal_select_2550 = shift_back[1:1];
    assign signal_mux_430 = signal_select_2550 ? signal_cat_265 : signal_mux_429;
    assign signal_select_2551 = shift_back[2:2];
    assign signal_mux_431 = signal_select_2551 ? signal_cat_264 : signal_mux_430;
    assign signal_select_2552 = shift_back[3:3];
    assign signal_mux_432 = signal_select_2552 ? signal_cat_263 : signal_mux_431;
    assign shift_back = signal_const_46 - d$shift_count;
    assign signal_select_2553 = shift_back[4:4];
    assign signal_mux_433 = signal_select_2553 ? signal_const_196 : signal_mux_432;
    assign signal_and_68 = signal_mux_433 & mask;
    assign signal_wire_31 = config$out_shift_right;
    assign out_value = signal_wire_31 ? signal_and_25 : signal_and_68;
    assign signal_select_2554 = out_value[0:0];
    assign signal_select_2555 = signal_mux_435[3:0];
    always @* begin
        case (signal_select_2555)
        0:
            signal_mux_434 <= signal_select_2554;
        1:
            signal_mux_434 <= signal_select_1708;
        2:
            signal_mux_434 <= signal_select_1707;
        3:
            signal_mux_434 <= signal_select_1706;
        4:
            signal_mux_434 <= signal_select_1705;
        5:
            signal_mux_434 <= signal_select_1704;
        6:
            signal_mux_434 <= signal_select_1703;
        7:
            signal_mux_434 <= signal_select_1702;
        8:
            signal_mux_434 <= signal_select_1701;
        9:
            signal_mux_434 <= signal_select_1700;
        10:
            signal_mux_434 <= signal_select_1699;
        11:
            signal_mux_434 <= signal_select_1698;
        12:
            signal_mux_434 <= signal_select_1697;
        13:
            signal_mux_434 <= signal_select_1696;
        14:
            signal_mux_434 <= signal_select_1695;
        default:
            signal_mux_434 <= signal_select_1694;
        endcase
    end
    assign signal_select_2556 = pin_dir_base[19:19];
    assign d$shift_count = word[4:0];
    assign signal_cat_343 = { gnd,
                              d$shift_count };
    assign signal_cat_344 = { gnd,
                              signal_wire_32 };
    assign signal_sub_209 = signal_const_54 - signal_cat_344;
    assign signal_cat_345 = { gnd,
                              signal_wire_32 };
    assign signal_sub_210 = signal_const_55 - signal_cat_345;
    assign signal_wire_32 = config$out_base;
    assign signal_lt_236 = signal_const_56 < signal_wire_32;
    assign signal_mux_435 = signal_lt_236 ? signal_sub_209 : signal_sub_210;
    assign signal_lt_237 = signal_mux_435 < signal_cat_343;
    assign signal_mux_436 = signal_lt_237 ? signal_mux_434 : signal_select_2556;
    assign signal_cat_346 = { signal_mux_436,
                              signal_mux_285,
                              signal_mux_282,
                              signal_mux_279,
                              signal_mux_276,
                              signal_mux_273,
                              signal_mux_270,
                              signal_mux_267,
                              signal_select_1567,
                              signal_select_1566,
                              signal_select_1565,
                              signal_select_1564,
                              signal_select_1563,
                              signal_select_1562,
                              signal_select_1561,
                              signal_select_1560,
                              signal_select_1559,
                              signal_select_1558,
                              signal_select_1557,
                              signal_select_1556 };
    assign d$out_dest$binary_variant = word[7:5];
    assign signal_eq_61 = d$out_dest$binary_variant == signal_const;
    assign signal_mux_437 = signal_eq_61 ? signal_cat_346 : pin_dir_base;
    assign signal_select_2557 = pin_dir_0[0:0];
    assign signal_select_2558 = pin_dir_0[1:1];
    assign signal_select_2559 = pin_dir_0[2:2];
    assign signal_select_2560 = pin_dir_0[3:3];
    assign signal_select_2561 = pin_dir_0[4:4];
    assign signal_select_2562 = pin_dir_0[5:5];
    assign signal_select_2563 = pin_dir_0[6:6];
    assign signal_select_2564 = pin_dir_0[7:7];
    assign signal_select_2565 = pin_dir_0[8:8];
    assign signal_select_2566 = pin_dir_0[9:9];
    assign signal_select_2567 = pin_dir_0[10:10];
    assign signal_select_2568 = pin_dir_0[11:11];
    assign signal_select_2569 = signal_cat_369[15:15];
    assign signal_select_2570 = signal_cat_369[14:14];
    assign signal_select_2571 = signal_cat_369[13:13];
    assign signal_select_2572 = signal_cat_369[12:12];
    assign signal_select_2573 = signal_cat_369[11:11];
    assign signal_select_2574 = signal_cat_369[10:10];
    assign signal_select_2575 = signal_cat_369[9:9];
    assign signal_select_2576 = signal_cat_369[8:8];
    assign signal_select_2577 = signal_cat_369[7:7];
    assign signal_select_2578 = signal_cat_369[6:6];
    assign signal_select_2579 = signal_cat_369[5:5];
    assign signal_select_2580 = signal_cat_369[4:4];
    assign signal_select_2581 = signal_cat_369[3:3];
    assign signal_select_2582 = signal_cat_369[2:2];
    assign signal_select_2583 = signal_cat_369[1:1];
    assign signal_select_2584 = signal_cat_369[0:0];
    assign signal_select_2585 = signal_mux_439[3:0];
    always @* begin
        case (signal_select_2585)
        0:
            signal_mux_438 <= signal_select_2584;
        1:
            signal_mux_438 <= signal_select_2583;
        2:
            signal_mux_438 <= signal_select_2582;
        3:
            signal_mux_438 <= signal_select_2581;
        4:
            signal_mux_438 <= signal_select_2580;
        5:
            signal_mux_438 <= signal_select_2579;
        6:
            signal_mux_438 <= signal_select_2578;
        7:
            signal_mux_438 <= signal_select_2577;
        8:
            signal_mux_438 <= signal_select_2576;
        9:
            signal_mux_438 <= signal_select_2575;
        10:
            signal_mux_438 <= signal_select_2574;
        11:
            signal_mux_438 <= signal_select_2573;
        12:
            signal_mux_438 <= signal_select_2572;
        13:
            signal_mux_438 <= signal_select_2571;
        14:
            signal_mux_438 <= signal_select_2570;
        default:
            signal_mux_438 <= signal_select_2569;
        endcase
    end
    assign signal_select_2586 = pin_dir_0[12:12];
    assign signal_cat_347 = { gnd,
                              signal_cat_370 };
    assign signal_cat_348 = { gnd,
                              signal_wire_34 };
    assign signal_sub_211 = signal_const_32 - signal_cat_348;
    assign signal_cat_349 = { gnd,
                              signal_wire_34 };
    assign signal_sub_212 = signal_const_33 - signal_cat_349;
    assign signal_lt_238 = signal_const_34 < signal_wire_34;
    assign signal_mux_439 = signal_lt_238 ? signal_sub_211 : signal_sub_212;
    assign signal_lt_239 = signal_mux_439 < signal_cat_347;
    assign signal_mux_440 = signal_lt_239 ? signal_mux_438 : signal_select_2586;
    assign signal_select_2587 = signal_cat_369[15:15];
    assign signal_select_2588 = signal_cat_369[14:14];
    assign signal_select_2589 = signal_cat_369[13:13];
    assign signal_select_2590 = signal_cat_369[12:12];
    assign signal_select_2591 = signal_cat_369[11:11];
    assign signal_select_2592 = signal_cat_369[10:10];
    assign signal_select_2593 = signal_cat_369[9:9];
    assign signal_select_2594 = signal_cat_369[8:8];
    assign signal_select_2595 = signal_cat_369[7:7];
    assign signal_select_2596 = signal_cat_369[6:6];
    assign signal_select_2597 = signal_cat_369[5:5];
    assign signal_select_2598 = signal_cat_369[4:4];
    assign signal_select_2599 = signal_cat_369[3:3];
    assign signal_select_2600 = signal_cat_369[2:2];
    assign signal_select_2601 = signal_cat_369[1:1];
    assign signal_select_2602 = signal_cat_369[0:0];
    assign signal_select_2603 = signal_mux_442[3:0];
    always @* begin
        case (signal_select_2603)
        0:
            signal_mux_441 <= signal_select_2602;
        1:
            signal_mux_441 <= signal_select_2601;
        2:
            signal_mux_441 <= signal_select_2600;
        3:
            signal_mux_441 <= signal_select_2599;
        4:
            signal_mux_441 <= signal_select_2598;
        5:
            signal_mux_441 <= signal_select_2597;
        6:
            signal_mux_441 <= signal_select_2596;
        7:
            signal_mux_441 <= signal_select_2595;
        8:
            signal_mux_441 <= signal_select_2594;
        9:
            signal_mux_441 <= signal_select_2593;
        10:
            signal_mux_441 <= signal_select_2592;
        11:
            signal_mux_441 <= signal_select_2591;
        12:
            signal_mux_441 <= signal_select_2590;
        13:
            signal_mux_441 <= signal_select_2589;
        14:
            signal_mux_441 <= signal_select_2588;
        default:
            signal_mux_441 <= signal_select_2587;
        endcase
    end
    assign signal_select_2604 = pin_dir_0[13:13];
    assign signal_cat_350 = { gnd,
                              signal_cat_370 };
    assign signal_cat_351 = { gnd,
                              signal_wire_34 };
    assign signal_sub_213 = signal_const_35 - signal_cat_351;
    assign signal_cat_352 = { gnd,
                              signal_wire_34 };
    assign signal_sub_214 = signal_const_36 - signal_cat_352;
    assign signal_lt_240 = signal_const_37 < signal_wire_34;
    assign signal_mux_442 = signal_lt_240 ? signal_sub_213 : signal_sub_214;
    assign signal_lt_241 = signal_mux_442 < signal_cat_350;
    assign signal_mux_443 = signal_lt_241 ? signal_mux_441 : signal_select_2604;
    assign signal_select_2605 = signal_cat_369[15:15];
    assign signal_select_2606 = signal_cat_369[14:14];
    assign signal_select_2607 = signal_cat_369[13:13];
    assign signal_select_2608 = signal_cat_369[12:12];
    assign signal_select_2609 = signal_cat_369[11:11];
    assign signal_select_2610 = signal_cat_369[10:10];
    assign signal_select_2611 = signal_cat_369[9:9];
    assign signal_select_2612 = signal_cat_369[8:8];
    assign signal_select_2613 = signal_cat_369[7:7];
    assign signal_select_2614 = signal_cat_369[6:6];
    assign signal_select_2615 = signal_cat_369[5:5];
    assign signal_select_2616 = signal_cat_369[4:4];
    assign signal_select_2617 = signal_cat_369[3:3];
    assign signal_select_2618 = signal_cat_369[2:2];
    assign signal_select_2619 = signal_cat_369[1:1];
    assign signal_select_2620 = signal_cat_369[0:0];
    assign signal_select_2621 = signal_mux_445[3:0];
    always @* begin
        case (signal_select_2621)
        0:
            signal_mux_444 <= signal_select_2620;
        1:
            signal_mux_444 <= signal_select_2619;
        2:
            signal_mux_444 <= signal_select_2618;
        3:
            signal_mux_444 <= signal_select_2617;
        4:
            signal_mux_444 <= signal_select_2616;
        5:
            signal_mux_444 <= signal_select_2615;
        6:
            signal_mux_444 <= signal_select_2614;
        7:
            signal_mux_444 <= signal_select_2613;
        8:
            signal_mux_444 <= signal_select_2612;
        9:
            signal_mux_444 <= signal_select_2611;
        10:
            signal_mux_444 <= signal_select_2610;
        11:
            signal_mux_444 <= signal_select_2609;
        12:
            signal_mux_444 <= signal_select_2608;
        13:
            signal_mux_444 <= signal_select_2607;
        14:
            signal_mux_444 <= signal_select_2606;
        default:
            signal_mux_444 <= signal_select_2605;
        endcase
    end
    assign signal_select_2622 = pin_dir_0[14:14];
    assign signal_cat_353 = { gnd,
                              signal_cat_370 };
    assign signal_cat_354 = { gnd,
                              signal_wire_34 };
    assign signal_sub_215 = signal_const_38 - signal_cat_354;
    assign signal_cat_355 = { gnd,
                              signal_wire_34 };
    assign signal_sub_216 = signal_const_39 - signal_cat_355;
    assign signal_lt_242 = signal_const_40 < signal_wire_34;
    assign signal_mux_445 = signal_lt_242 ? signal_sub_215 : signal_sub_216;
    assign signal_lt_243 = signal_mux_445 < signal_cat_353;
    assign signal_mux_446 = signal_lt_243 ? signal_mux_444 : signal_select_2622;
    assign signal_select_2623 = signal_cat_369[15:15];
    assign signal_select_2624 = signal_cat_369[14:14];
    assign signal_select_2625 = signal_cat_369[13:13];
    assign signal_select_2626 = signal_cat_369[12:12];
    assign signal_select_2627 = signal_cat_369[11:11];
    assign signal_select_2628 = signal_cat_369[10:10];
    assign signal_select_2629 = signal_cat_369[9:9];
    assign signal_select_2630 = signal_cat_369[8:8];
    assign signal_select_2631 = signal_cat_369[7:7];
    assign signal_select_2632 = signal_cat_369[6:6];
    assign signal_select_2633 = signal_cat_369[5:5];
    assign signal_select_2634 = signal_cat_369[4:4];
    assign signal_select_2635 = signal_cat_369[3:3];
    assign signal_select_2636 = signal_cat_369[2:2];
    assign signal_select_2637 = signal_cat_369[1:1];
    assign signal_select_2638 = signal_cat_369[0:0];
    assign signal_select_2639 = signal_mux_448[3:0];
    always @* begin
        case (signal_select_2639)
        0:
            signal_mux_447 <= signal_select_2638;
        1:
            signal_mux_447 <= signal_select_2637;
        2:
            signal_mux_447 <= signal_select_2636;
        3:
            signal_mux_447 <= signal_select_2635;
        4:
            signal_mux_447 <= signal_select_2634;
        5:
            signal_mux_447 <= signal_select_2633;
        6:
            signal_mux_447 <= signal_select_2632;
        7:
            signal_mux_447 <= signal_select_2631;
        8:
            signal_mux_447 <= signal_select_2630;
        9:
            signal_mux_447 <= signal_select_2629;
        10:
            signal_mux_447 <= signal_select_2628;
        11:
            signal_mux_447 <= signal_select_2627;
        12:
            signal_mux_447 <= signal_select_2626;
        13:
            signal_mux_447 <= signal_select_2625;
        14:
            signal_mux_447 <= signal_select_2624;
        default:
            signal_mux_447 <= signal_select_2623;
        endcase
    end
    assign signal_select_2640 = pin_dir_0[15:15];
    assign signal_cat_356 = { gnd,
                              signal_cat_370 };
    assign signal_cat_357 = { gnd,
                              signal_wire_34 };
    assign signal_sub_217 = signal_const_41 - signal_cat_357;
    assign signal_cat_358 = { gnd,
                              signal_wire_34 };
    assign signal_sub_218 = signal_const_42 - signal_cat_358;
    assign signal_lt_244 = signal_const_43 < signal_wire_34;
    assign signal_mux_448 = signal_lt_244 ? signal_sub_217 : signal_sub_218;
    assign signal_lt_245 = signal_mux_448 < signal_cat_356;
    assign signal_mux_449 = signal_lt_245 ? signal_mux_447 : signal_select_2640;
    assign signal_select_2641 = signal_cat_369[15:15];
    assign signal_select_2642 = signal_cat_369[14:14];
    assign signal_select_2643 = signal_cat_369[13:13];
    assign signal_select_2644 = signal_cat_369[12:12];
    assign signal_select_2645 = signal_cat_369[11:11];
    assign signal_select_2646 = signal_cat_369[10:10];
    assign signal_select_2647 = signal_cat_369[9:9];
    assign signal_select_2648 = signal_cat_369[8:8];
    assign signal_select_2649 = signal_cat_369[7:7];
    assign signal_select_2650 = signal_cat_369[6:6];
    assign signal_select_2651 = signal_cat_369[5:5];
    assign signal_select_2652 = signal_cat_369[4:4];
    assign signal_select_2653 = signal_cat_369[3:3];
    assign signal_select_2654 = signal_cat_369[2:2];
    assign signal_select_2655 = signal_cat_369[1:1];
    assign signal_select_2656 = signal_cat_369[0:0];
    assign signal_select_2657 = signal_mux_451[3:0];
    always @* begin
        case (signal_select_2657)
        0:
            signal_mux_450 <= signal_select_2656;
        1:
            signal_mux_450 <= signal_select_2655;
        2:
            signal_mux_450 <= signal_select_2654;
        3:
            signal_mux_450 <= signal_select_2653;
        4:
            signal_mux_450 <= signal_select_2652;
        5:
            signal_mux_450 <= signal_select_2651;
        6:
            signal_mux_450 <= signal_select_2650;
        7:
            signal_mux_450 <= signal_select_2649;
        8:
            signal_mux_450 <= signal_select_2648;
        9:
            signal_mux_450 <= signal_select_2647;
        10:
            signal_mux_450 <= signal_select_2646;
        11:
            signal_mux_450 <= signal_select_2645;
        12:
            signal_mux_450 <= signal_select_2644;
        13:
            signal_mux_450 <= signal_select_2643;
        14:
            signal_mux_450 <= signal_select_2642;
        default:
            signal_mux_450 <= signal_select_2641;
        endcase
    end
    assign signal_select_2658 = pin_dir_0[16:16];
    assign signal_cat_359 = { gnd,
                              signal_cat_370 };
    assign signal_cat_360 = { gnd,
                              signal_wire_34 };
    assign signal_sub_219 = signal_const_44 - signal_cat_360;
    assign signal_cat_361 = { gnd,
                              signal_wire_34 };
    assign signal_sub_220 = signal_const_45 - signal_cat_361;
    assign signal_lt_246 = signal_const_46 < signal_wire_34;
    assign signal_mux_451 = signal_lt_246 ? signal_sub_219 : signal_sub_220;
    assign signal_lt_247 = signal_mux_451 < signal_cat_359;
    assign signal_mux_452 = signal_lt_247 ? signal_mux_450 : signal_select_2658;
    assign signal_select_2659 = signal_cat_369[15:15];
    assign signal_select_2660 = signal_cat_369[14:14];
    assign signal_select_2661 = signal_cat_369[13:13];
    assign signal_select_2662 = signal_cat_369[12:12];
    assign signal_select_2663 = signal_cat_369[11:11];
    assign signal_select_2664 = signal_cat_369[10:10];
    assign signal_select_2665 = signal_cat_369[9:9];
    assign signal_select_2666 = signal_cat_369[8:8];
    assign signal_select_2667 = signal_cat_369[7:7];
    assign signal_select_2668 = signal_cat_369[6:6];
    assign signal_select_2669 = signal_cat_369[5:5];
    assign signal_select_2670 = signal_cat_369[4:4];
    assign signal_select_2671 = signal_cat_369[3:3];
    assign signal_select_2672 = signal_cat_369[2:2];
    assign signal_select_2673 = signal_cat_369[1:1];
    assign signal_select_2674 = signal_cat_369[0:0];
    assign signal_select_2675 = signal_mux_454[3:0];
    always @* begin
        case (signal_select_2675)
        0:
            signal_mux_453 <= signal_select_2674;
        1:
            signal_mux_453 <= signal_select_2673;
        2:
            signal_mux_453 <= signal_select_2672;
        3:
            signal_mux_453 <= signal_select_2671;
        4:
            signal_mux_453 <= signal_select_2670;
        5:
            signal_mux_453 <= signal_select_2669;
        6:
            signal_mux_453 <= signal_select_2668;
        7:
            signal_mux_453 <= signal_select_2667;
        8:
            signal_mux_453 <= signal_select_2666;
        9:
            signal_mux_453 <= signal_select_2665;
        10:
            signal_mux_453 <= signal_select_2664;
        11:
            signal_mux_453 <= signal_select_2663;
        12:
            signal_mux_453 <= signal_select_2662;
        13:
            signal_mux_453 <= signal_select_2661;
        14:
            signal_mux_453 <= signal_select_2660;
        default:
            signal_mux_453 <= signal_select_2659;
        endcase
    end
    assign signal_select_2676 = pin_dir_0[17:17];
    assign signal_cat_362 = { gnd,
                              signal_cat_370 };
    assign signal_cat_363 = { gnd,
                              signal_wire_34 };
    assign signal_sub_221 = signal_const_47 - signal_cat_363;
    assign signal_cat_364 = { gnd,
                              signal_wire_34 };
    assign signal_sub_222 = signal_const_48 - signal_cat_364;
    assign signal_lt_248 = signal_const_49 < signal_wire_34;
    assign signal_mux_454 = signal_lt_248 ? signal_sub_221 : signal_sub_222;
    assign signal_lt_249 = signal_mux_454 < signal_cat_362;
    assign signal_mux_455 = signal_lt_249 ? signal_mux_453 : signal_select_2676;
    assign signal_select_2677 = signal_cat_369[15:15];
    assign signal_select_2678 = signal_cat_369[14:14];
    assign signal_select_2679 = signal_cat_369[13:13];
    assign signal_select_2680 = signal_cat_369[12:12];
    assign signal_select_2681 = signal_cat_369[11:11];
    assign signal_select_2682 = signal_cat_369[10:10];
    assign signal_select_2683 = signal_cat_369[9:9];
    assign signal_select_2684 = signal_cat_369[8:8];
    assign signal_select_2685 = signal_cat_369[7:7];
    assign signal_select_2686 = signal_cat_369[6:6];
    assign signal_select_2687 = signal_cat_369[5:5];
    assign signal_select_2688 = signal_cat_369[4:4];
    assign signal_select_2689 = signal_cat_369[3:3];
    assign signal_select_2690 = signal_cat_369[2:2];
    assign signal_select_2691 = signal_cat_369[1:1];
    assign signal_select_2692 = signal_cat_369[0:0];
    assign signal_select_2693 = signal_mux_457[3:0];
    always @* begin
        case (signal_select_2693)
        0:
            signal_mux_456 <= signal_select_2692;
        1:
            signal_mux_456 <= signal_select_2691;
        2:
            signal_mux_456 <= signal_select_2690;
        3:
            signal_mux_456 <= signal_select_2689;
        4:
            signal_mux_456 <= signal_select_2688;
        5:
            signal_mux_456 <= signal_select_2687;
        6:
            signal_mux_456 <= signal_select_2686;
        7:
            signal_mux_456 <= signal_select_2685;
        8:
            signal_mux_456 <= signal_select_2684;
        9:
            signal_mux_456 <= signal_select_2683;
        10:
            signal_mux_456 <= signal_select_2682;
        11:
            signal_mux_456 <= signal_select_2681;
        12:
            signal_mux_456 <= signal_select_2680;
        13:
            signal_mux_456 <= signal_select_2679;
        14:
            signal_mux_456 <= signal_select_2678;
        default:
            signal_mux_456 <= signal_select_2677;
        endcase
    end
    assign signal_select_2694 = pin_dir_0[18:18];
    assign signal_cat_365 = { gnd,
                              signal_cat_370 };
    assign signal_cat_366 = { gnd,
                              signal_wire_34 };
    assign signal_sub_223 = signal_const_50 - signal_cat_366;
    assign signal_cat_367 = { gnd,
                              signal_wire_34 };
    assign signal_sub_224 = signal_const_51 - signal_cat_367;
    assign signal_lt_250 = signal_const_52 < signal_wire_34;
    assign signal_mux_457 = signal_lt_250 ? signal_sub_223 : signal_sub_224;
    assign signal_lt_251 = signal_mux_457 < signal_cat_365;
    assign signal_mux_458 = signal_lt_251 ? signal_mux_456 : signal_select_2694;
    assign signal_select_2695 = signal_cat_369[15:15];
    assign signal_select_2696 = signal_cat_369[14:14];
    assign signal_select_2697 = signal_cat_369[13:13];
    assign signal_select_2698 = signal_cat_369[12:12];
    assign signal_select_2699 = signal_cat_369[11:11];
    assign signal_select_2700 = signal_cat_369[10:10];
    assign signal_select_2701 = signal_cat_369[9:9];
    assign signal_select_2702 = signal_cat_369[8:8];
    assign signal_select_2703 = signal_cat_369[7:7];
    assign signal_select_2704 = signal_cat_369[6:6];
    assign signal_select_2705 = signal_cat_369[5:5];
    assign signal_select_2706 = signal_cat_369[4:4];
    assign signal_select_2707 = signal_cat_369[3:3];
    assign signal_select_2708 = signal_cat_369[2:2];
    assign signal_select_2709 = signal_cat_369[1:1];
    assign signal_select_2710 = signal_select_2712[4:3];
    assign signal_select_2711 = signal_select_2712[4:3];
    assign signal_select_2712 = word[12:8];
    assign signal_select_2713 = signal_select_2712[4:4];
    assign signal_cat_368 = { gnd,
                              signal_select_2713 };
    always @* begin
        case (signal_wire_33)
        0:
            d$side_set <= signal_const_257;
        1:
            d$side_set <= signal_cat_368;
        2:
            d$side_set <= signal_select_2711;
        default:
            d$side_set <= signal_select_2710;
        endcase
    end
    assign signal_cat_369 = { signal_const_192,
                              d$side_set };
    assign signal_select_2714 = signal_cat_369[0:0];
    assign signal_select_2715 = signal_mux_460[3:0];
    always @* begin
        case (signal_select_2715)
        0:
            signal_mux_459 <= signal_select_2714;
        1:
            signal_mux_459 <= signal_select_2709;
        2:
            signal_mux_459 <= signal_select_2708;
        3:
            signal_mux_459 <= signal_select_2707;
        4:
            signal_mux_459 <= signal_select_2706;
        5:
            signal_mux_459 <= signal_select_2705;
        6:
            signal_mux_459 <= signal_select_2704;
        7:
            signal_mux_459 <= signal_select_2703;
        8:
            signal_mux_459 <= signal_select_2702;
        9:
            signal_mux_459 <= signal_select_2701;
        10:
            signal_mux_459 <= signal_select_2700;
        11:
            signal_mux_459 <= signal_select_2699;
        12:
            signal_mux_459 <= signal_select_2698;
        13:
            signal_mux_459 <= signal_select_2697;
        14:
            signal_mux_459 <= signal_select_2696;
        default:
            signal_mux_459 <= signal_select_2695;
        endcase
    end
    assign signal_select_2716 = pin_dir_0[19:19];
    assign signal_wire_33 = config$side_set_count;
    assign signal_cat_370 = { signal_const_57,
                              signal_wire_33 };
    assign signal_cat_371 = { gnd,
                              signal_cat_370 };
    assign signal_cat_372 = { gnd,
                              signal_wire_34 };
    assign signal_sub_225 = signal_const_54 - signal_cat_372;
    assign signal_cat_373 = { gnd,
                              signal_wire_34 };
    assign signal_sub_226 = signal_const_55 - signal_cat_373;
    assign signal_wire_34 = config$side_set_base;
    assign signal_lt_252 = signal_const_56 < signal_wire_34;
    assign signal_mux_460 = signal_lt_252 ? signal_sub_225 : signal_sub_226;
    assign signal_lt_253 = signal_mux_460 < signal_cat_371;
    assign signal_mux_461 = signal_lt_253 ? signal_mux_459 : signal_select_2716;
    assign pin_dir_side = { signal_mux_461,
                            signal_mux_458,
                            signal_mux_455,
                            signal_mux_452,
                            signal_mux_449,
                            signal_mux_446,
                            signal_mux_443,
                            signal_mux_440,
                            signal_select_2568,
                            signal_select_2567,
                            signal_select_2566,
                            signal_select_2565,
                            signal_select_2564,
                            signal_select_2563,
                            signal_select_2562,
                            signal_select_2561,
                            signal_select_2560,
                            signal_select_2559,
                            signal_select_2558,
                            signal_select_2557 };
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
            pin_dir_next <= signal_mux_437;
        4:
            pin_dir_next <= signal_mux_264;
        5:
            pin_dir_next <= signal_mux_239;
        6:
            pin_dir_next <= pin_dir_base;
        default:
            pin_dir_next <= pin_dir_base;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_20 <= signal_const_10;
        else
            if (op_go)
                signal_reg_20 <= pin_dir_next;
    end
    assign pin_dir_0 = signal_reg_20;
    assign signal_select_2717 = pin_dir_0[19:19];
    assign signal_mux_462 = signal_select_2717 ? signal_select_1242 : signal_select_1243;
    assign sample = { signal_mux_462,
                      signal_mux_214,
                      signal_mux_213,
                      signal_mux_212,
                      signal_mux_211,
                      signal_mux_210,
                      signal_mux_209,
                      signal_mux_208,
                      signal_select_1220,
                      signal_select_1219,
                      signal_select_1218,
                      signal_select_1217,
                      signal_select_1216,
                      signal_select_1215,
                      signal_select_1214,
                      signal_select_1213,
                      signal_select_1212,
                      signal_select_1211,
                      signal_select_1210,
                      signal_select_1209 };
    assign signal_select_2718 = sample[0:0];
    assign d$wait_index = word[4:0];
    always @* begin
        case (d$wait_index)
        0:
            wait_pin_cur <= signal_select_2718;
        1:
            wait_pin_cur <= signal_select_1208;
        2:
            wait_pin_cur <= signal_select_1207;
        3:
            wait_pin_cur <= signal_select_1206;
        4:
            wait_pin_cur <= signal_select_1205;
        5:
            wait_pin_cur <= signal_select_1204;
        6:
            wait_pin_cur <= signal_select_1203;
        7:
            wait_pin_cur <= signal_select_1202;
        8:
            wait_pin_cur <= signal_select_1201;
        9:
            wait_pin_cur <= signal_select_1200;
        10:
            wait_pin_cur <= signal_select_1199;
        11:
            wait_pin_cur <= signal_select_1198;
        12:
            wait_pin_cur <= signal_select_1197;
        13:
            wait_pin_cur <= signal_select_1196;
        14:
            wait_pin_cur <= signal_select_1195;
        15:
            wait_pin_cur <= signal_select_1194;
        16:
            wait_pin_cur <= signal_select_1193;
        17:
            wait_pin_cur <= signal_select_1192;
        18:
            wait_pin_cur <= signal_select_1191;
        default:
            wait_pin_cur <= signal_select_1190;
        endcase
    end
    assign signal_eq_62 = wait_pin_cur == d$wait_polarity;
    assign d$wait_source$binary_variant = word[6:5];
    always @* begin
        case (d$wait_source$binary_variant)
        0:
            wait_ready <= signal_eq_62;
        1:
            wait_ready <= signal_and_24;
        2:
            wait_ready <= deadline_ready;
        default:
            wait_ready <= signal_mux_202;
        endcase
    end
    assign signal_not_56 = ~ wait_ready;
    assign gnd = 1'b0;
    assign signal_eq_63 = signal_select_2729 == signal_const_223;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            is_opcode$1 <= gnd;
        else
            if (ir_load)
                is_opcode$1 <= signal_eq_63;
    end
    assign wait_holds = is_opcode$1 & signal_not_56;
    assign signal_not_57 = ~ wait_holds;
    assign signal_eq_64 = signal_select_2729 == signal_const_57;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            is_opcode$0 <= vdd;
        else
            if (ir_load)
                is_opcode$0 <= signal_eq_64;
    end
    assign signal_not_58 = ~ is_opcode$0;
    assign op_go = go & signal_not_58;
    assign advance = op_go & signal_not_57;
    assign signal_or_6 = advance | refill;
    assign ir_load = signal_or_6;
    assign signal_select_2719 = signal_wire_40[7:3];
    assign signal_eq_65 = signal_select_2719 == signal_const_205;
    assign signal_select_2720 = signal_wire_40[2:0];
    assign signal_lt_254 = signal_select_2720 < signal_const_1;
    assign signal_select_2721 = signal_wire_40[3:3];
    assign signal_not_59 = ~ signal_select_2721;
    assign signal_or_7 = signal_not_59 | signal_lt_254;
    assign signal_select_2722 = signal_wire_40[5:4];
    assign signal_lt_255 = signal_select_2722 < signal_const_228;
    assign signal_and_69 = signal_lt_255 & signal_or_7;
    assign signal_select_2723 = signal_wire_40[7:5];
    assign signal_lt_256 = signal_select_2723 < signal_const_1;
    assign signal_select_2724 = signal_wire_40[4:3];
    assign signal_lt_257 = signal_select_2724 < signal_const_228;
    assign signal_lt_258 = signal_const_46 < signal_select_2725;
    assign signal_not_60 = ~ signal_lt_258;
    assign signal_select_2725 = signal_wire_40[4:0];
    assign signal_lt_259 = signal_select_2725 < signal_const_208;
    assign signal_not_61 = ~ signal_lt_259;
    assign signal_and_70 = signal_not_61 & signal_not_60;
    assign signal_eq_66 = signal_select_2726 == signal_const_205;
    assign signal_eq_67 = signal_select_2726 == signal_const_205;
    assign signal_const_585 = 5'b10100;
    assign signal_lt_260 = signal_select_2726 < signal_const_585;
    assign signal_select_2726 = signal_wire_40[4:0];
    assign signal_lt_261 = signal_select_2726 < signal_const_585;
    assign signal_select_2727 = signal_wire_40[6:5];
    always @* begin
        case (signal_select_2727)
        0:
            signal_mux_463 <= signal_lt_261;
        1:
            signal_mux_463 <= signal_lt_260;
        2:
            signal_mux_463 <= signal_eq_67;
        default:
            signal_mux_463 <= signal_eq_66;
        endcase
    end
    assign signal_select_2728 = signal_wire_40[9:9];
    assign signal_not_62 = ~ signal_select_2728;
    assign signal_select_2729 = signal_wire_40[15:13];
    always @* begin
        case (signal_select_2729)
        0:
            signal_mux_464 <= signal_not_62;
        1:
            signal_mux_464 <= signal_mux_463;
        2:
            signal_mux_464 <= signal_and_70;
        3:
            signal_mux_464 <= signal_and_70;
        4:
            signal_mux_464 <= signal_lt_257;
        5:
            signal_mux_464 <= signal_lt_256;
        6:
            signal_mux_464 <= signal_and_69;
        default:
            signal_mux_464 <= signal_eq_65;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            decode_ok_0 <= vdd;
        else
            if (ir_load)
                decode_ok_0 <= signal_mux_464;
    end
    assign signal_not_63 = ~ decode_ok_0;
    assign signal_and_71 = issue & signal_not_63;
    assign signal_mux_465 = signal_and_71 ? vdd : signal_mux_200;
    assign signal_wire_36 = clear;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            start_0 <= signal_const_3;
        else
            start_0 <= signal_wire_37;
    end
    assign halted_next = start_0 ? gnd : signal_mux_465;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            signal_reg_21 <= vdd;
        else
            signal_reg_21 <= halted_next;
    end
    assign halted_0 = signal_reg_21;
    assign signal_not_64 = ~ halted_0;
    assign signal_and_72 = signal_not_64 & signal_eq_19;
    assign issue = signal_and_72 & signal_not_9;
    assign go = issue & decode_ok_0;
    assign jmp_go = go & is_opcode$0;
    assign signal_mux_466 = jmp_go ? jmp_target_or_next : pc_after_next;
    assign signal_wire_37 = start;
    assign signal_mux_467 = signal_wire_37 ? signal_const_198 : signal_mux_466;
    assign fetch_addr = signal_mux_467;
    assign signal_mux_468 = signal_wire_38 ? signal_wire_3 : fetch_addr;
    assign signal_wire_38 = program_write$valid;
    assign vdd = 1'b1;
    assign signal_wire_39 = clock;
    sram_macro
        sram_macro
        ( .clock(signal_wire_39),
          .men(vdd),
          .wen(signal_wire_38),
          .ren(vdd),
          .addr(signal_mux_468),
          .din(signal_wire_2),
          .bm(signal_const_197),
          .dout(signal_inst_2[15:0]) );
    assign signal_wire_40 = signal_inst_2;
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
            word <= signal_const_196;
        else
            if (ir_load)
                word <= signal_wire_40;
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
            pin_out_next <= signal_mux_139;
        4:
            pin_out_next <= signal_mux_93;
        5:
            pin_out_next <= signal_mux_47;
        6:
            pin_out_next <= pin_out_base;
        default:
            pin_out_next <= pin_out_base;
        endcase
    end
    always @(posedge signal_wire_39) begin
        if (signal_wire_36)
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
    input [2:0] status$tx_level;
    input [2:0] status$rx_level;
    input [15:0] status$rx_head;
    output miso;
    output start;
    output clear_irq;
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
    wire [7:0] signal_select_2;
    wire [15:0] signal_const_5;
    wire [15:0] signal_cat;
    wire [15:0] signal_cat_1;
    wire [14:0] signal_const_11;
    wire [15:0] signal_cat_2;
    wire [10:0] signal_const_13;
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
    wire [12:0] signal_const_39;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_cat_16;
    wire [15:0] signal_cat_17;
    wire [15:0] signal_cat_18;
    wire [15:0] signal_cat_19;
    wire [15:0] signal_cat_20;
    wire [15:0] signal_cat_21;
    wire [15:0] signal_cat_22;
    wire [13:0] signal_const_55;
    wire [15:0] signal_cat_23;
    wire [15:0] signal_cat_24;
    wire [7:0] signal_select_3;
    wire [7:0] signal_const_60;
    wire [15:0] signal_cat_25;
    wire [15:0] signal_select_4;
    wire [7:0] signal_select_5;
    wire [15:0] signal_cat_26;
    wire [15:0] signal_select_6;
    wire [15:0] signal_cat_27;
    reg [15:0] read_value;
    wire [8:0] signal_const_70;
    wire [8:0] signal_select_7;
    wire [6:0] signal_const_71;
    wire signal_eq_5;
    wire [8:0] signal_mux;
    wire [8:0] signal_mux_1;
    wire [8:0] signal_wire;
    reg [8:0] signal_reg;
    wire [15:0] signal_cat_28;
    wire [8:0] signal_select_8;
    wire [6:0] signal_const_75;
    wire signal_eq_6;
    wire [8:0] signal_mux_2;
    wire [8:0] signal_mux_3;
    wire [8:0] signal_wire_1;
    reg [8:0] signal_reg_1;
    wire [15:0] signal_cat_29;
    wire signal_const_78;
    wire signal_select_9;
    wire [6:0] signal_const_79;
    wire signal_eq_7;
    wire signal_mux_4;
    wire signal_mux_5;
    wire signal_wire_2;
    reg signal_reg_2;
    wire [15:0] signal_cat_30;
    wire [4:0] signal_const_82;
    wire [4:0] signal_select_10;
    wire [6:0] signal_const_83;
    wire signal_eq_8;
    wire [4:0] signal_mux_6;
    wire [4:0] signal_mux_7;
    wire [4:0] signal_wire_3;
    reg [4:0] signal_reg_3;
    wire [15:0] signal_cat_31;
    wire signal_select_11;
    wire [6:0] signal_const_87;
    wire signal_eq_9;
    wire signal_mux_8;
    wire signal_mux_9;
    wire signal_wire_4;
    reg signal_reg_4;
    wire [15:0] signal_cat_32;
    wire [6:0] signal_const_91;
    wire signal_eq_10;
    wire [15:0] signal_mux_10;
    wire [15:0] signal_mux_11;
    wire [15:0] signal_wire_5;
    reg [15:0] signal_reg_5;
    wire [6:0] signal_const_94;
    wire signal_eq_11;
    wire [15:0] signal_mux_12;
    wire [15:0] signal_mux_13;
    wire [15:0] signal_wire_6;
    reg [15:0] signal_reg_6;
    wire [4:0] signal_select_12;
    wire [6:0] signal_const_97;
    wire signal_eq_12;
    wire [4:0] signal_mux_14;
    wire [4:0] signal_mux_15;
    wire [4:0] signal_wire_7;
    reg [4:0] signal_reg_7;
    wire [15:0] signal_cat_33;
    wire [4:0] signal_select_13;
    wire [6:0] signal_const_101;
    wire signal_eq_13;
    wire [4:0] signal_mux_16;
    wire [4:0] signal_mux_17;
    wire [4:0] signal_wire_8;
    reg [4:0] signal_reg_8;
    wire [15:0] signal_cat_34;
    wire signal_select_14;
    wire [6:0] signal_const_105;
    wire signal_eq_14;
    wire signal_mux_18;
    wire signal_mux_19;
    wire signal_wire_9;
    reg signal_reg_9;
    wire [15:0] signal_cat_35;
    wire [4:0] signal_select_15;
    wire [6:0] signal_const_109;
    wire signal_eq_15;
    wire [4:0] signal_mux_20;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_wire_10;
    reg [4:0] signal_reg_10;
    wire [15:0] signal_cat_36;
    wire signal_select_16;
    wire [6:0] signal_const_113;
    wire signal_eq_16;
    wire signal_mux_22;
    wire signal_mux_23;
    wire signal_wire_11;
    reg signal_reg_11;
    wire [15:0] signal_cat_37;
    wire signal_select_17;
    wire [6:0] signal_const_117;
    wire signal_eq_17;
    wire signal_mux_24;
    wire signal_mux_25;
    wire signal_wire_12;
    reg signal_reg_12;
    wire [15:0] signal_cat_38;
    wire signal_select_18;
    wire [6:0] signal_const_121;
    wire signal_eq_18;
    wire signal_mux_26;
    wire signal_mux_27;
    wire signal_wire_13;
    reg signal_reg_13;
    wire [15:0] signal_cat_39;
    wire signal_select_19;
    wire [6:0] signal_const_125;
    wire signal_eq_19;
    wire signal_mux_28;
    wire signal_mux_29;
    wire signal_wire_14;
    reg signal_reg_14;
    wire [15:0] signal_cat_40;
    wire [4:0] signal_select_20;
    wire [6:0] signal_const_129;
    wire signal_eq_20;
    wire [4:0] signal_mux_30;
    wire [4:0] signal_mux_31;
    wire [4:0] signal_wire_15;
    reg [4:0] signal_reg_15;
    wire [15:0] signal_cat_41;
    wire [4:0] signal_select_21;
    wire [6:0] signal_const_133;
    wire signal_eq_21;
    wire [4:0] signal_mux_32;
    wire [4:0] signal_mux_33;
    wire [4:0] signal_wire_16;
    reg [4:0] signal_reg_16;
    wire [15:0] signal_cat_42;
    wire [2:0] signal_const_136;
    wire [2:0] signal_select_22;
    wire [6:0] signal_const_137;
    wire signal_eq_22;
    wire [2:0] signal_mux_34;
    wire [2:0] signal_mux_35;
    wire [2:0] signal_wire_17;
    reg [2:0] signal_reg_17;
    wire [15:0] signal_cat_43;
    wire [4:0] signal_select_23;
    wire [6:0] signal_const_141;
    wire signal_eq_23;
    wire [4:0] signal_mux_36;
    wire [4:0] signal_mux_37;
    wire [4:0] signal_wire_18;
    reg [4:0] signal_reg_18;
    wire [15:0] signal_cat_44;
    wire [4:0] signal_select_24;
    wire [6:0] signal_const_145;
    wire signal_eq_24;
    wire [4:0] signal_mux_38;
    wire [4:0] signal_mux_39;
    wire [4:0] signal_wire_19;
    reg [4:0] signal_reg_19;
    wire [15:0] signal_cat_45;
    wire [4:0] signal_select_25;
    wire [6:0] signal_const_149;
    wire signal_eq_25;
    wire [4:0] signal_mux_40;
    wire [4:0] signal_mux_41;
    wire [4:0] signal_wire_20;
    reg [4:0] signal_reg_20;
    wire [15:0] signal_cat_46;
    wire [4:0] signal_select_26;
    wire [6:0] signal_const_153;
    wire signal_eq_26;
    wire [4:0] signal_mux_42;
    wire [4:0] signal_mux_43;
    wire [4:0] signal_wire_21;
    reg [4:0] signal_reg_21;
    wire [15:0] signal_cat_47;
    wire [4:0] signal_select_27;
    wire [6:0] signal_const_157;
    wire signal_eq_27;
    wire [4:0] signal_mux_44;
    wire [4:0] signal_mux_45;
    wire [4:0] signal_wire_22;
    reg [4:0] signal_reg_22;
    wire [15:0] signal_cat_48;
    wire signal_select_28;
    wire [6:0] signal_const_161;
    wire signal_eq_28;
    wire signal_mux_46;
    wire signal_mux_47;
    wire signal_wire_23;
    reg signal_reg_23;
    wire [15:0] signal_cat_49;
    wire [4:0] signal_select_29;
    wire [6:0] signal_const_165;
    wire signal_eq_29;
    wire [4:0] signal_mux_48;
    wire [4:0] signal_mux_49;
    wire [4:0] signal_wire_24;
    reg [4:0] signal_reg_24;
    wire [15:0] signal_cat_50;
    wire [1:0] signal_const_168;
    wire [1:0] signal_select_30;
    wire [6:0] signal_const_169;
    wire signal_eq_30;
    wire [1:0] signal_mux_50;
    wire [1:0] signal_mux_51;
    wire [1:0] signal_wire_25;
    reg [1:0] signal_reg_25;
    wire [15:0] signal_cat_51;
    wire [8:0] signal_const_173;
    wire [8:0] signal_add;
    reg [7:0] signal_cases;
    wire [7:0] signal_mux_52;
    wire [7:0] signal_wire_26;
    reg [7:0] high;
    wire [15:0] value;
    wire [8:0] signal_select_31;
    wire [6:0] signal_const_175;
    wire signal_eq_31;
    wire [8:0] signal_mux_53;
    wire signal_eq_32;
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
    wire [7:0] signal_select_32;
    wire [15:0] signal_cat_53;
    wire [23:0] signal_wire_29;
    wire [15:0] signal_select_33;
    wire [7:0] signal_select_34;
    wire [15:0] signal_cat_54;
    wire [23:0] signal_wire_30;
    wire [15:0] signal_select_35;
    wire [8:0] signal_wire_31;
    wire [15:0] signal_cat_55;
    wire signal_wire_32;
    wire signal_wire_33;
    wire signal_wire_34;
    wire signal_wire_35;
    wire signal_wire_36;
    wire signal_wire_37;
    wire [2:0] signal_wire_38;
    wire [2:0] signal_wire_39;
    wire [3:0] signal_const_188;
    wire [15:0] signal_cat_56;
    wire [6:0] signal_select_36;
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
    wire [7:0] signal_select_37;
    reg [7:0] signal_cases_4;
    wire [7:0] signal_mux_62;
    wire [7:0] signal_wire_41;
    reg [7:0] cmd;
    wire [6:0] addr;
    wire signal_eq_33;
    wire [15:0] tx_word;
    wire [7:0] signal_select_38;
    wire [1:0] signal_const_193;
    reg [1:0] signal_cases_5;
    wire signal_select_39;
    wire [1:0] signal_mux_63;
    wire signal_select_40;
    wire [1:0] signal_mux_64;
    wire [1:0] signal_wire_42;
    (* fsm_encoding="one_hot" *)
    reg [1:0] sm;
    wire [1:0] signal_const_195;
    wire signal_eq_34;
    wire [7:0] signal_mux_65;
    wire signal_wire_43;
    wire signal_wire_44;
    wire signal_wire_45;
    wire signal_wire_46;
    wire signal_wire_47;
    wire [11:0] signal_inst;
    wire signal_select_41;
    assign signal_const = 7'b0001000;
    assign signal_eq = addr == signal_const;
    assign signal_and = read_done & signal_eq;
    assign signal_const_1 = 7'b0000111;
    assign signal_eq_1 = addr == signal_const_1;
    assign signal_and_1 = write & signal_eq_1;
    assign signal_const_2 = 7'b0001010;
    assign signal_eq_2 = addr == signal_const_2;
    assign signal_and_2 = write & signal_eq_2;
    assign signal_select = value[1:1];
    assign signal_const_3 = 7'b0000000;
    assign signal_eq_3 = addr == signal_const_3;
    assign signal_and_3 = write & signal_eq_3;
    assign signal_and_4 = signal_and_3 & signal_select;
    assign signal_select_1 = value[0:0];
    assign signal_eq_4 = addr == signal_const_3;
    assign signal_and_5 = write & signal_eq_4;
    assign signal_and_6 = signal_and_5 & signal_select_1;
    assign signal_select_2 = tx_word[7:0];
    assign signal_const_5 = 16'b0000000000000000;
    assign signal_cat = { signal_const_3,
                          signal_reg };
    assign signal_cat_1 = { signal_const_3,
                            signal_reg_1 };
    assign signal_const_11 = 15'b000000000000000;
    assign signal_cat_2 = { signal_const_11,
                            signal_reg_2 };
    assign signal_const_13 = 11'b00000000000;
    assign signal_cat_3 = { signal_const_13,
                            signal_reg_3 };
    assign signal_cat_4 = { signal_const_11,
                            signal_reg_4 };
    assign signal_cat_5 = { signal_const_13,
                            signal_reg_7 };
    assign signal_cat_6 = { signal_const_13,
                            signal_reg_8 };
    assign signal_cat_7 = { signal_const_11,
                            signal_reg_9 };
    assign signal_cat_8 = { signal_const_13,
                            signal_reg_10 };
    assign signal_cat_9 = { signal_const_11,
                            signal_reg_11 };
    assign signal_cat_10 = { signal_const_11,
                             signal_reg_12 };
    assign signal_cat_11 = { signal_const_11,
                             signal_reg_13 };
    assign signal_cat_12 = { signal_const_11,
                             signal_reg_14 };
    assign signal_cat_13 = { signal_const_13,
                             signal_reg_15 };
    assign signal_cat_14 = { signal_const_13,
                             signal_reg_16 };
    assign signal_const_39 = 13'b0000000000000;
    assign signal_cat_15 = { signal_const_39,
                             signal_reg_17 };
    assign signal_cat_16 = { signal_const_13,
                             signal_reg_18 };
    assign signal_cat_17 = { signal_const_13,
                             signal_reg_19 };
    assign signal_cat_18 = { signal_const_13,
                             signal_reg_20 };
    assign signal_cat_19 = { signal_const_13,
                             signal_reg_21 };
    assign signal_cat_20 = { signal_const_13,
                             signal_reg_22 };
    assign signal_cat_21 = { signal_const_11,
                             signal_reg_23 };
    assign signal_cat_22 = { signal_const_13,
                             signal_reg_24 };
    assign signal_const_55 = 14'b00000000000000;
    assign signal_cat_23 = { signal_const_55,
                             signal_reg_25 };
    assign signal_cat_24 = { signal_const_3,
                             program_addr };
    assign signal_select_3 = signal_wire_29[23:16];
    assign signal_const_60 = 8'b00000000;
    assign signal_cat_25 = { signal_const_60,
                             signal_select_3 };
    assign signal_select_4 = signal_wire_29[15:0];
    assign signal_select_5 = signal_wire_30[23:16];
    assign signal_cat_26 = { signal_const_60,
                             signal_select_5 };
    assign signal_select_6 = signal_wire_30[15:0];
    assign signal_cat_27 = { signal_const_3,
                             signal_wire_31 };
    always @* begin
        case (addr)
        7'b0000001:
            read_value <= signal_cat_56;
        7'b0000010:
            read_value <= signal_cat_27;
        7'b0000011:
            read_value <= signal_select_6;
        7'b0000100:
            read_value <= signal_cat_26;
        7'b0000101:
            read_value <= signal_select_4;
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
            read_value <= signal_const_5;
        endcase
    end
    assign signal_const_70 = 9'b000000000;
    assign signal_select_7 = value[8:0];
    assign signal_const_71 = 7'b0101001;
    assign signal_eq_5 = addr == signal_const_71;
    assign signal_mux = signal_eq_5 ? signal_select_7 : signal_reg;
    assign signal_mux_1 = write ? signal_mux : signal_reg;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg <= signal_const_70;
        else
            signal_reg <= signal_wire;
    end
    assign signal_cat_28 = { signal_const_3,
                             signal_reg };
    assign signal_select_8 = value[8:0];
    assign signal_const_75 = 7'b0101000;
    assign signal_eq_6 = addr == signal_const_75;
    assign signal_mux_2 = signal_eq_6 ? signal_select_8 : signal_reg_1;
    assign signal_mux_3 = write ? signal_mux_2 : signal_reg_1;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_1 <= signal_const_70;
        else
            signal_reg_1 <= signal_wire_1;
    end
    assign signal_cat_29 = { signal_const_3,
                             signal_reg_1 };
    assign signal_const_78 = 1'b0;
    assign signal_select_9 = value[0:0];
    assign signal_const_79 = 7'b0100111;
    assign signal_eq_7 = addr == signal_const_79;
    assign signal_mux_4 = signal_eq_7 ? signal_select_9 : signal_reg_2;
    assign signal_mux_5 = write ? signal_mux_4 : signal_reg_2;
    assign signal_wire_2 = signal_mux_5;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_2 <= signal_const_78;
        else
            signal_reg_2 <= signal_wire_2;
    end
    assign signal_cat_30 = { signal_const_11,
                             signal_reg_2 };
    assign signal_const_82 = 5'b00000;
    assign signal_select_10 = value[4:0];
    assign signal_const_83 = 7'b0100110;
    assign signal_eq_8 = addr == signal_const_83;
    assign signal_mux_6 = signal_eq_8 ? signal_select_10 : signal_reg_3;
    assign signal_mux_7 = write ? signal_mux_6 : signal_reg_3;
    assign signal_wire_3 = signal_mux_7;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_3 <= signal_const_82;
        else
            signal_reg_3 <= signal_wire_3;
    end
    assign signal_cat_31 = { signal_const_13,
                             signal_reg_3 };
    assign signal_select_11 = value[0:0];
    assign signal_const_87 = 7'b0100101;
    assign signal_eq_9 = addr == signal_const_87;
    assign signal_mux_8 = signal_eq_9 ? signal_select_11 : signal_reg_4;
    assign signal_mux_9 = write ? signal_mux_8 : signal_reg_4;
    assign signal_wire_4 = signal_mux_9;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_4 <= signal_const_78;
        else
            signal_reg_4 <= signal_wire_4;
    end
    assign signal_cat_32 = { signal_const_11,
                             signal_reg_4 };
    assign signal_const_91 = 7'b0100100;
    assign signal_eq_10 = addr == signal_const_91;
    assign signal_mux_10 = signal_eq_10 ? value : signal_reg_5;
    assign signal_mux_11 = write ? signal_mux_10 : signal_reg_5;
    assign signal_wire_5 = signal_mux_11;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_5 <= signal_const_5;
        else
            signal_reg_5 <= signal_wire_5;
    end
    assign signal_const_94 = 7'b0100011;
    assign signal_eq_11 = addr == signal_const_94;
    assign signal_mux_12 = signal_eq_11 ? value : signal_reg_6;
    assign signal_mux_13 = write ? signal_mux_12 : signal_reg_6;
    assign signal_wire_6 = signal_mux_13;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_6 <= signal_const_5;
        else
            signal_reg_6 <= signal_wire_6;
    end
    assign signal_select_12 = value[4:0];
    assign signal_const_97 = 7'b0100010;
    assign signal_eq_12 = addr == signal_const_97;
    assign signal_mux_14 = signal_eq_12 ? signal_select_12 : signal_reg_7;
    assign signal_mux_15 = write ? signal_mux_14 : signal_reg_7;
    assign signal_wire_7 = signal_mux_15;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_7 <= signal_const_82;
        else
            signal_reg_7 <= signal_wire_7;
    end
    assign signal_cat_33 = { signal_const_13,
                             signal_reg_7 };
    assign signal_select_13 = value[4:0];
    assign signal_const_101 = 7'b0100001;
    assign signal_eq_13 = addr == signal_const_101;
    assign signal_mux_16 = signal_eq_13 ? signal_select_13 : signal_reg_8;
    assign signal_mux_17 = write ? signal_mux_16 : signal_reg_8;
    assign signal_wire_8 = signal_mux_17;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_8 <= signal_const_82;
        else
            signal_reg_8 <= signal_wire_8;
    end
    assign signal_cat_34 = { signal_const_13,
                             signal_reg_8 };
    assign signal_select_14 = value[0:0];
    assign signal_const_105 = 7'b0100000;
    assign signal_eq_14 = addr == signal_const_105;
    assign signal_mux_18 = signal_eq_14 ? signal_select_14 : signal_reg_9;
    assign signal_mux_19 = write ? signal_mux_18 : signal_reg_9;
    assign signal_wire_9 = signal_mux_19;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_9 <= signal_const_78;
        else
            signal_reg_9 <= signal_wire_9;
    end
    assign signal_cat_35 = { signal_const_11,
                             signal_reg_9 };
    assign signal_select_15 = value[4:0];
    assign signal_const_109 = 7'b0011111;
    assign signal_eq_15 = addr == signal_const_109;
    assign signal_mux_20 = signal_eq_15 ? signal_select_15 : signal_reg_10;
    assign signal_mux_21 = write ? signal_mux_20 : signal_reg_10;
    assign signal_wire_10 = signal_mux_21;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_10 <= signal_const_82;
        else
            signal_reg_10 <= signal_wire_10;
    end
    assign signal_cat_36 = { signal_const_13,
                             signal_reg_10 };
    assign signal_select_16 = value[0:0];
    assign signal_const_113 = 7'b0011110;
    assign signal_eq_16 = addr == signal_const_113;
    assign signal_mux_22 = signal_eq_16 ? signal_select_16 : signal_reg_11;
    assign signal_mux_23 = write ? signal_mux_22 : signal_reg_11;
    assign signal_wire_11 = signal_mux_23;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_11 <= signal_const_78;
        else
            signal_reg_11 <= signal_wire_11;
    end
    assign signal_cat_37 = { signal_const_11,
                             signal_reg_11 };
    assign signal_select_17 = value[0:0];
    assign signal_const_117 = 7'b0011101;
    assign signal_eq_17 = addr == signal_const_117;
    assign signal_mux_24 = signal_eq_17 ? signal_select_17 : signal_reg_12;
    assign signal_mux_25 = write ? signal_mux_24 : signal_reg_12;
    assign signal_wire_12 = signal_mux_25;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_12 <= signal_const_78;
        else
            signal_reg_12 <= signal_wire_12;
    end
    assign signal_cat_38 = { signal_const_11,
                             signal_reg_12 };
    assign signal_select_18 = value[0:0];
    assign signal_const_121 = 7'b0011100;
    assign signal_eq_18 = addr == signal_const_121;
    assign signal_mux_26 = signal_eq_18 ? signal_select_18 : signal_reg_13;
    assign signal_mux_27 = write ? signal_mux_26 : signal_reg_13;
    assign signal_wire_13 = signal_mux_27;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_13 <= signal_const_78;
        else
            signal_reg_13 <= signal_wire_13;
    end
    assign signal_cat_39 = { signal_const_11,
                             signal_reg_13 };
    assign signal_select_19 = value[0:0];
    assign signal_const_125 = 7'b0011011;
    assign signal_eq_19 = addr == signal_const_125;
    assign signal_mux_28 = signal_eq_19 ? signal_select_19 : signal_reg_14;
    assign signal_mux_29 = write ? signal_mux_28 : signal_reg_14;
    assign signal_wire_14 = signal_mux_29;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_14 <= signal_const_78;
        else
            signal_reg_14 <= signal_wire_14;
    end
    assign signal_cat_40 = { signal_const_11,
                             signal_reg_14 };
    assign signal_select_20 = value[4:0];
    assign signal_const_129 = 7'b0011010;
    assign signal_eq_20 = addr == signal_const_129;
    assign signal_mux_30 = signal_eq_20 ? signal_select_20 : signal_reg_15;
    assign signal_mux_31 = write ? signal_mux_30 : signal_reg_15;
    assign signal_wire_15 = signal_mux_31;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_15 <= signal_const_82;
        else
            signal_reg_15 <= signal_wire_15;
    end
    assign signal_cat_41 = { signal_const_13,
                             signal_reg_15 };
    assign signal_select_21 = value[4:0];
    assign signal_const_133 = 7'b0011001;
    assign signal_eq_21 = addr == signal_const_133;
    assign signal_mux_32 = signal_eq_21 ? signal_select_21 : signal_reg_16;
    assign signal_mux_33 = write ? signal_mux_32 : signal_reg_16;
    assign signal_wire_16 = signal_mux_33;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_16 <= signal_const_82;
        else
            signal_reg_16 <= signal_wire_16;
    end
    assign signal_cat_42 = { signal_const_13,
                             signal_reg_16 };
    assign signal_const_136 = 3'b000;
    assign signal_select_22 = value[2:0];
    assign signal_const_137 = 7'b0011000;
    assign signal_eq_22 = addr == signal_const_137;
    assign signal_mux_34 = signal_eq_22 ? signal_select_22 : signal_reg_17;
    assign signal_mux_35 = write ? signal_mux_34 : signal_reg_17;
    assign signal_wire_17 = signal_mux_35;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_17 <= signal_const_136;
        else
            signal_reg_17 <= signal_wire_17;
    end
    assign signal_cat_43 = { signal_const_39,
                             signal_reg_17 };
    assign signal_select_23 = value[4:0];
    assign signal_const_141 = 7'b0010111;
    assign signal_eq_23 = addr == signal_const_141;
    assign signal_mux_36 = signal_eq_23 ? signal_select_23 : signal_reg_18;
    assign signal_mux_37 = write ? signal_mux_36 : signal_reg_18;
    assign signal_wire_18 = signal_mux_37;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_18 <= signal_const_82;
        else
            signal_reg_18 <= signal_wire_18;
    end
    assign signal_cat_44 = { signal_const_13,
                             signal_reg_18 };
    assign signal_select_24 = value[4:0];
    assign signal_const_145 = 7'b0010110;
    assign signal_eq_24 = addr == signal_const_145;
    assign signal_mux_38 = signal_eq_24 ? signal_select_24 : signal_reg_19;
    assign signal_mux_39 = write ? signal_mux_38 : signal_reg_19;
    assign signal_wire_19 = signal_mux_39;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_19 <= signal_const_82;
        else
            signal_reg_19 <= signal_wire_19;
    end
    assign signal_cat_45 = { signal_const_13,
                             signal_reg_19 };
    assign signal_select_25 = value[4:0];
    assign signal_const_149 = 7'b0010101;
    assign signal_eq_25 = addr == signal_const_149;
    assign signal_mux_40 = signal_eq_25 ? signal_select_25 : signal_reg_20;
    assign signal_mux_41 = write ? signal_mux_40 : signal_reg_20;
    assign signal_wire_20 = signal_mux_41;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_20 <= signal_const_82;
        else
            signal_reg_20 <= signal_wire_20;
    end
    assign signal_cat_46 = { signal_const_13,
                             signal_reg_20 };
    assign signal_select_26 = value[4:0];
    assign signal_const_153 = 7'b0010100;
    assign signal_eq_26 = addr == signal_const_153;
    assign signal_mux_42 = signal_eq_26 ? signal_select_26 : signal_reg_21;
    assign signal_mux_43 = write ? signal_mux_42 : signal_reg_21;
    assign signal_wire_21 = signal_mux_43;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_21 <= signal_const_82;
        else
            signal_reg_21 <= signal_wire_21;
    end
    assign signal_cat_47 = { signal_const_13,
                             signal_reg_21 };
    assign signal_select_27 = value[4:0];
    assign signal_const_157 = 7'b0010011;
    assign signal_eq_27 = addr == signal_const_157;
    assign signal_mux_44 = signal_eq_27 ? signal_select_27 : signal_reg_22;
    assign signal_mux_45 = write ? signal_mux_44 : signal_reg_22;
    assign signal_wire_22 = signal_mux_45;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_22 <= signal_const_82;
        else
            signal_reg_22 <= signal_wire_22;
    end
    assign signal_cat_48 = { signal_const_13,
                             signal_reg_22 };
    assign signal_select_28 = value[0:0];
    assign signal_const_161 = 7'b0010010;
    assign signal_eq_28 = addr == signal_const_161;
    assign signal_mux_46 = signal_eq_28 ? signal_select_28 : signal_reg_23;
    assign signal_mux_47 = write ? signal_mux_46 : signal_reg_23;
    assign signal_wire_23 = signal_mux_47;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_23 <= signal_const_78;
        else
            signal_reg_23 <= signal_wire_23;
    end
    assign signal_cat_49 = { signal_const_11,
                             signal_reg_23 };
    assign signal_select_29 = value[4:0];
    assign signal_const_165 = 7'b0010001;
    assign signal_eq_29 = addr == signal_const_165;
    assign signal_mux_48 = signal_eq_29 ? signal_select_29 : signal_reg_24;
    assign signal_mux_49 = write ? signal_mux_48 : signal_reg_24;
    assign signal_wire_24 = signal_mux_49;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_24 <= signal_const_82;
        else
            signal_reg_24 <= signal_wire_24;
    end
    assign signal_cat_50 = { signal_const_13,
                             signal_reg_24 };
    assign signal_const_168 = 2'b00;
    assign signal_select_30 = value[1:0];
    assign signal_const_169 = 7'b0010000;
    assign signal_eq_30 = addr == signal_const_169;
    assign signal_mux_50 = signal_eq_30 ? signal_select_30 : signal_reg_25;
    assign signal_mux_51 = write ? signal_mux_50 : signal_reg_25;
    assign signal_wire_25 = signal_mux_51;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_25 <= signal_const_168;
        else
            signal_reg_25 <= signal_wire_25;
    end
    assign signal_cat_51 = { signal_const_55,
                             signal_reg_25 };
    assign signal_const_173 = 9'b000000001;
    assign signal_add = program_addr + signal_const_173;
    always @* begin
        case (sm)
        2'b01:
            signal_cases <= signal_select_37;
        default:
            signal_cases <= high;
        endcase
    end
    assign signal_mux_52 = signal_select_40 ? signal_cases : high;
    assign signal_wire_26 = signal_mux_52;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            high <= signal_const_60;
        else
            high <= signal_wire_26;
    end
    assign value = { high,
                     signal_select_37 };
    assign signal_select_31 = value[8:0];
    assign signal_const_175 = 7'b0001001;
    assign signal_eq_31 = addr == signal_const_175;
    assign signal_mux_53 = signal_eq_31 ? signal_select_31 : program_addr;
    assign signal_eq_32 = addr == signal_const_2;
    assign signal_mux_54 = signal_eq_32 ? signal_add : signal_mux_53;
    assign signal_mux_55 = is_write ? vdd : gnd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_1 <= signal_mux_55;
        default:
            signal_cases_1 <= gnd;
        endcase
    end
    assign signal_mux_56 = signal_select_40 ? signal_cases_1 : gnd;
    assign write = signal_mux_56;
    assign signal_mux_57 = write ? signal_mux_54 : program_addr;
    assign signal_wire_27 = signal_mux_57;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            program_addr <= signal_const_70;
        else
            program_addr <= signal_wire_27;
    end
    assign signal_cat_52 = { signal_const_3,
                             program_addr };
    assign signal_wire_28 = status$rx_head;
    assign signal_select_32 = signal_wire_29[23:16];
    assign signal_cat_53 = { signal_const_60,
                             signal_select_32 };
    assign signal_wire_29 = status$capture;
    assign signal_select_33 = signal_wire_29[15:0];
    assign signal_select_34 = signal_wire_30[23:16];
    assign signal_cat_54 = { signal_const_60,
                             signal_select_34 };
    assign signal_wire_30 = status$now;
    assign signal_select_35 = signal_wire_30[15:0];
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
    assign signal_const_188 = 4'b0000;
    assign signal_cat_56 = { signal_const_188,
                             signal_wire_39,
                             signal_wire_38,
                             signal_wire_37,
                             signal_wire_36,
                             signal_wire_35,
                             signal_wire_34,
                             signal_wire_33,
                             signal_wire_32 };
    assign signal_select_36 = signal_select_37[6:0];
    always @* begin
        case (signal_select_36)
        7'b0000001:
            first_read <= signal_cat_56;
        7'b0000010:
            first_read <= signal_cat_55;
        7'b0000011:
            first_read <= signal_select_35;
        7'b0000100:
            first_read <= signal_cat_54;
        7'b0000101:
            first_read <= signal_select_33;
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
            first_read <= signal_const_5;
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
    assign signal_mux_58 = signal_select_40 ? signal_cases_2 : word;
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
    assign signal_mux_60 = signal_select_40 ? signal_cases_3 : gnd;
    assign read_done = signal_mux_60;
    assign signal_mux_61 = read_done ? read_value : signal_mux_58;
    assign signal_wire_40 = signal_mux_61;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            word <= signal_const_5;
        else
            word <= signal_wire_40;
    end
    assign signal_select_37 = signal_inst[8:1];
    always @* begin
        case (sm)
        2'b00:
            signal_cases_4 <= signal_select_37;
        default:
            signal_cases_4 <= cmd;
        endcase
    end
    assign signal_mux_62 = signal_select_40 ? signal_cases_4 : cmd;
    assign signal_wire_41 = signal_mux_62;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            cmd <= signal_const_60;
        else
            cmd <= signal_wire_41;
    end
    assign addr = cmd[6:0];
    assign signal_eq_33 = addr == signal_const;
    assign tx_word = signal_eq_33 ? signal_wire_28 : word;
    assign signal_select_38 = tx_word[15:8];
    assign signal_const_193 = 2'b01;
    always @* begin
        case (sm)
        2'b00:
            signal_cases_5 <= signal_const_193;
        2'b01:
            signal_cases_5 <= signal_const_195;
        2'b10:
            signal_cases_5 <= signal_const_193;
        default:
            signal_cases_5 <= signal_mux_63;
        endcase
    end
    assign signal_select_39 = signal_inst[10:10];
    assign signal_mux_63 = signal_select_39 ? signal_const_168 : sm;
    assign signal_select_40 = signal_inst[9:9];
    assign signal_mux_64 = signal_select_40 ? signal_cases_5 : signal_mux_63;
    assign signal_wire_42 = signal_mux_64;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            sm <= signal_const_168;
        else
            sm <= signal_wire_42;
    end
    assign signal_const_195 = 2'b10;
    assign signal_eq_34 = signal_const_195 == sm;
    assign signal_mux_65 = signal_eq_34 ? signal_select_2 : signal_select_38;
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
    assign signal_select_41 = signal_inst[0:0];
    assign miso = signal_select_41;
    assign start = signal_and_6;
    assign clear_irq = signal_and_4;
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
    wire [15:0] signal_select_7;
    wire signal_select_8;
    wire [15:0] signal_select_9;
    wire [8:0] signal_select_10;
    wire signal_select_11;
    wire signal_select_12;
    wire [8:0] signal_select_13;
    wire [8:0] signal_select_14;
    wire signal_select_15;
    wire [4:0] signal_select_16;
    wire signal_select_17;
    wire [15:0] signal_select_18;
    wire [15:0] signal_select_19;
    wire [4:0] signal_select_20;
    wire [4:0] signal_select_21;
    wire signal_select_22;
    wire [4:0] signal_select_23;
    wire signal_select_24;
    wire signal_select_25;
    wire signal_select_26;
    wire signal_select_27;
    wire [4:0] signal_select_28;
    wire [4:0] signal_select_29;
    wire [2:0] signal_select_30;
    wire [4:0] signal_select_31;
    wire [4:0] signal_select_32;
    wire [4:0] signal_select_33;
    wire [4:0] signal_select_34;
    wire [4:0] signal_select_35;
    wire signal_select_36;
    wire [4:0] signal_select_37;
    wire [15:0] signal_select_38;
    wire [15:0] signal_wire_1;
    wire [2:0] signal_select_39;
    wire [2:0] signal_wire_2;
    wire [2:0] signal_select_40;
    wire [2:0] signal_wire_3;
    wire signal_select_41;
    wire signal_wire_4;
    wire signal_select_42;
    wire signal_wire_5;
    wire signal_select_43;
    wire signal_wire_6;
    wire signal_select_44;
    wire signal_wire_7;
    wire signal_select_45;
    wire signal_wire_8;
    wire signal_select_46;
    wire signal_wire_9;
    wire [23:0] signal_select_47;
    wire [23:0] signal_wire_10;
    wire [23:0] signal_select_48;
    wire [23:0] signal_wire_11;
    wire [8:0] signal_select_49;
    wire [8:0] signal_wire_12;
    wire signal_select_50;
    wire signal_select_51;
    wire [7:0] signal_wire_13;
    wire signal_select_52;
    wire [169:0] signal_inst;
    wire [1:0] signal_select_53;
    wire signal_const_5;
    wire signal_wire_14;
    wire signal_not;
    wire vdd;
    reg signal_reg_4;
    reg reset_done;
    wire signal_not_1;
    wire signal_wire_15;
    wire [290:0] signal_inst_1;
    wire [19:0] signal_select_54;
    wire [6:0] signal_select_55;
    wire [7:0] signal_cat;
    assign signal_select = signal_inst_1[39:20];
    assign signal_select_1 = signal_select[19:12];
    assign signal_select_2 = signal_select_54[19:12];
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
    assign signal_select_5 = signal_inst[2:2];
    assign signal_select_6 = signal_inst[46:46];
    assign signal_select_7 = signal_inst[45:30];
    assign signal_select_8 = signal_inst[29:29];
    assign signal_select_9 = signal_inst[28:13];
    assign signal_select_10 = signal_inst[12:4];
    assign signal_select_11 = signal_inst[3:3];
    assign signal_select_12 = signal_inst[1:1];
    assign signal_select_13 = signal_inst[169:161];
    assign signal_select_14 = signal_inst[160:152];
    assign signal_select_15 = signal_inst[151:151];
    assign signal_select_16 = signal_inst[150:146];
    assign signal_select_17 = signal_inst[145:145];
    assign signal_select_18 = signal_inst[144:129];
    assign signal_select_19 = signal_inst[128:113];
    assign signal_select_20 = signal_inst[112:108];
    assign signal_select_21 = signal_inst[107:103];
    assign signal_select_22 = signal_inst[102:102];
    assign signal_select_23 = signal_inst[101:97];
    assign signal_select_24 = signal_inst[96:96];
    assign signal_select_25 = signal_inst[95:95];
    assign signal_select_26 = signal_inst[94:94];
    assign signal_select_27 = signal_inst[93:93];
    assign signal_select_28 = signal_inst[92:88];
    assign signal_select_29 = signal_inst[87:83];
    assign signal_select_30 = signal_inst[82:80];
    assign signal_select_31 = signal_inst[79:75];
    assign signal_select_32 = signal_inst[74:70];
    assign signal_select_33 = signal_inst[69:65];
    assign signal_select_34 = signal_inst[64:60];
    assign signal_select_35 = signal_inst[59:55];
    assign signal_select_36 = signal_inst[54:54];
    assign signal_select_37 = signal_inst[53:49];
    assign signal_select_38 = signal_inst_1[244:229];
    assign signal_wire_1 = signal_select_38;
    assign signal_select_39 = signal_inst_1[228:226];
    assign signal_wire_2 = signal_select_39;
    assign signal_select_40 = signal_inst_1[225:223];
    assign signal_wire_3 = signal_select_40;
    assign signal_select_41 = signal_inst_1[197:197];
    assign signal_wire_4 = signal_select_41;
    assign signal_select_42 = signal_inst_1[196:196];
    assign signal_wire_5 = signal_select_42;
    assign signal_select_43 = signal_inst_1[195:195];
    assign signal_wire_6 = signal_select_43;
    assign signal_select_44 = signal_inst_1[194:194];
    assign signal_wire_7 = signal_select_44;
    assign signal_select_45 = signal_inst_1[193:193];
    assign signal_wire_8 = signal_select_45;
    assign signal_select_46 = signal_inst_1[192:192];
    assign signal_wire_9 = signal_select_46;
    assign signal_select_47 = signal_inst_1[221:198];
    assign signal_wire_10 = signal_select_47;
    assign signal_select_48 = signal_inst_1[186:163];
    assign signal_wire_11 = signal_select_48;
    assign signal_select_49 = signal_inst_1[48:40];
    assign signal_wire_12 = signal_select_49;
    assign signal_select_50 = signal_wire_13[2:2];
    assign signal_select_51 = signal_wire_13[1:1];
    assign signal_wire_13 = ui_in;
    assign signal_select_52 = signal_wire_13[0:0];
    host_port
        host_port
        ( .clock(signal_wire_15),
          .clear(signal_not_1),
          .sck(signal_select_52),
          .mosi(signal_select_51),
          .cs_n(signal_select_50),
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
          .program_write$valid(signal_inst[3:3]),
          .program_write$addr(signal_inst[12:4]),
          .program_write$data(signal_inst[28:13]),
          .tx$valid(signal_inst[29:29]),
          .tx$value(signal_inst[45:30]),
          .rx_pop(signal_inst[46:46]),
          .config$side_set_count(signal_inst[48:47]),
          .config$side_set_base(signal_inst[53:49]),
          .config$side_set_pindirs(signal_inst[54:54]),
          .config$in_base(signal_inst[59:55]),
          .config$in_count(signal_inst[64:60]),
          .config$out_base(signal_inst[69:65]),
          .config$out_count(signal_inst[74:70]),
          .config$set_base(signal_inst[79:75]),
          .config$set_count(signal_inst[82:80]),
          .config$jmp_pin(signal_inst[87:83]),
          .config$capture_pin(signal_inst[92:88]),
          .config$capture_rising(signal_inst[93:93]),
          .config$in_shift_right(signal_inst[94:94]),
          .config$out_shift_right(signal_inst[95:95]),
          .config$autopush(signal_inst[96:96]),
          .config$push_threshold(signal_inst[101:97]),
          .config$autopull(signal_inst[102:102]),
          .config$pull_threshold(signal_inst[107:103]),
          .config$crc_width(signal_inst[112:108]),
          .config$crc_poly(signal_inst[128:113]),
          .config$crc_init(signal_inst[144:129]),
          .config$crc_reflect(signal_inst[145:145]),
          .config$stuff_threshold(signal_inst[150:146]),
          .config$stuff_level(signal_inst[151:151]),
          .config$wrap_bottom(signal_inst[160:152]),
          .config$wrap_top(signal_inst[169:161]) );
    assign signal_select_53 = signal_inst[48:47];
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
          .config$side_set_count(signal_select_53),
          .config$side_set_base(signal_select_37),
          .config$side_set_pindirs(signal_select_36),
          .config$in_base(signal_select_35),
          .config$in_count(signal_select_34),
          .config$out_base(signal_select_33),
          .config$out_count(signal_select_32),
          .config$set_base(signal_select_31),
          .config$set_count(signal_select_30),
          .config$jmp_pin(signal_select_29),
          .config$capture_pin(signal_select_28),
          .config$capture_rising(signal_select_27),
          .config$in_shift_right(signal_select_26),
          .config$out_shift_right(signal_select_25),
          .config$autopush(signal_select_24),
          .config$push_threshold(signal_select_23),
          .config$autopull(signal_select_22),
          .config$pull_threshold(signal_select_21),
          .config$crc_width(signal_select_20),
          .config$crc_poly(signal_select_19),
          .config$crc_init(signal_select_18),
          .config$crc_reflect(signal_select_17),
          .config$stuff_threshold(signal_select_16),
          .config$stuff_level(signal_select_15),
          .config$wrap_bottom(signal_select_14),
          .config$wrap_top(signal_select_13),
          .start(signal_select_12),
          .program_write$valid(signal_select_11),
          .program_write$addr(signal_select_10),
          .program_write$data(signal_select_9),
          .tx$valid(signal_select_8),
          .tx$value(signal_select_7),
          .rx_pop(signal_select_6),
          .clear_irq(signal_select_5),
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
          .tx_level(signal_inst_1[225:223]),
          .rx_level(signal_inst_1[228:226]),
          .rx_head(signal_inst_1[244:229]),
          .instruction(signal_inst_1[260:245]),
          .decode_ok(signal_inst_1[261:261]),
          .opcode_onehot(signal_inst_1[269:262]),
          .crc(signal_inst_1[285:270]),
          .stuff_run(signal_inst_1[290:286]) );
    assign signal_select_54 = signal_inst_1[19:0];
    assign signal_select_55 = signal_select_54[11:5];
    assign signal_cat = { signal_select_55,
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

