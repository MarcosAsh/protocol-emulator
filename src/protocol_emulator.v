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
    flush,
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
    input flush;
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
    wire signal_or_2;
    wire signal_wire_10;
    wire [3:0] signal_const_19;
    wire signal_lt_1;
    wire signal_not_3;
    reg nearly_full;
    wire signal_and_6;
    wire full_1;
    wire signal_not_4;
    wire signal_wire_11;
    wire signal_and_7;
    wire WR_INT;
    wire signal_wire_12;
    wire signal_not_5;
    wire signal_wire_13;
    wire RD_INT;
    wire signal_xor_2;
    wire [3:0] USED_NEXT;
    wire signal_eq_3;
    wire signal_not_6;
    reg not_empty;
    wire signal_wire_14;
    wire signal_not_7;
    wire signal_and_8;
    wire bypass_cond;
    wire [15:0] signal_mux_1;
    reg [15:0] signal_reg;
    assign signal_or = bypass_cond | RD_INT;
    assign signal_const = 16'b0000000000000000;
    always @(posedge signal_wire_10) begin
        data_before_collision <= signal_wire;
    end
    assign signal_wire = push$value;
    always @(posedge signal_wire_10) begin
        if (signal_and_2)
            signal_multiport_mem[signal_wire_2] <= signal_wire;
    end
    assign signal_mem_read_port = signal_multiport_mem[RA];
    always @(posedge signal_wire_10) begin
        ram_rbw_data <= signal_mem_read_port;
    end
    assign signal_const_1 = 3'b000;
    assign signal_const_2 = 3'b001;
    assign READ_ADDRESS_NEXT = signal_wire_1 + signal_const_2;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            READ_ADDRESS <= signal_const_1;
        else
            if (signal_and)
                READ_ADDRESS <= READ_ADDRESS_NEXT;
    end
    assign signal_wire_1 = READ_ADDRESS;
    assign signal_and = RD_INT & used_gt_one;
    assign RA = signal_and ? READ_ADDRESS_NEXT : signal_wire_1;
    assign WRITE_ADDRESS_NEXT = signal_wire_2 + signal_const_2;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
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
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            used_gt_one <= signal_const_5;
        else
            if (signal_xor)
                used_gt_one <= signal_lt;
    end
    assign signal_or_1 = used_gt_one | signal_and_1;
    assign signal_and_2 = WR_INT & signal_or_1;
    assign signal_and_3 = signal_and_2 & signal_eq;
    always @(posedge signal_wire_10) begin
        collision <= signal_and_3;
    end
    assign memory = collision ? data_before_collision : ram_rbw_data;
    assign signal_xor_1 = RD_INT ^ WR_INT;
    assign signal_eq_1 = USED_NEXT == signal_const_6;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
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
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            USED_MINUS_1 <= signal_const_11;
        else
            if (signal_xor_2)
                USED_MINUS_1 <= signal_sub;
    end
    assign signal_wire_3 = USED_MINUS_1;
    assign signal_add = USED_NEXT + signal_const_6;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            USED_PLUS_1 <= signal_const_6;
        else
            if (signal_xor_2)
                USED_PLUS_1 <= signal_add;
    end
    assign signal_wire_4 = USED_PLUS_1;
    assign signal_mux = RD_INT ? signal_wire_3 : signal_wire_4;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            USED <= signal_const_10;
        else
            if (signal_xor_2)
                USED <= USED_NEXT;
    end
    assign signal_wire_5 = USED;
    assign signal_const_17 = 4'b1001;
    assign signal_eq_2 = USED_NEXT == signal_const_17;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            full_0 <= signal_const_5;
        else
            if (signal_xor_2)
                full_0 <= signal_eq_2;
    end
    assign signal_wire_6 = full_0;
    assign signal_wire_7 = signal_wire_6;
    assign signal_not_1 = ~ signal_wire_7;
    assign signal_not_2 = ~ signal_wire_13;
    assign signal_wire_8 = flush;
    assign signal_wire_9 = clear;
    assign signal_or_2 = signal_wire_9 | signal_wire_8;
    assign signal_wire_10 = clock;
    assign signal_const_19 = 4'b1000;
    assign signal_lt_1 = USED_NEXT < signal_const_19;
    assign signal_not_3 = ~ signal_lt_1;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            nearly_full <= signal_const_5;
        else
            if (signal_xor_2)
                nearly_full <= signal_not_3;
    end
    assign signal_and_6 = nearly_full & signal_not_2;
    assign full_1 = signal_and_6;
    assign signal_not_4 = ~ full_1;
    assign signal_wire_11 = push$valid;
    assign signal_and_7 = signal_wire_11 & signal_not_4;
    assign WR_INT = signal_and_7 & signal_not_1;
    assign signal_wire_12 = signal_not_7;
    assign signal_not_5 = ~ signal_wire_12;
    assign signal_wire_13 = pop;
    assign RD_INT = signal_wire_13 & signal_not_5;
    assign signal_xor_2 = RD_INT ^ WR_INT;
    assign USED_NEXT = signal_xor_2 ? signal_mux : signal_wire_5;
    assign signal_eq_3 = USED_NEXT == signal_const_10;
    assign signal_not_6 = ~ signal_eq_3;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
            not_empty <= signal_const_5;
        else
            if (signal_xor_2)
                not_empty <= signal_not_6;
    end
    assign signal_wire_14 = not_empty;
    assign signal_not_7 = ~ signal_wire_14;
    assign signal_and_8 = signal_not_7 & WR_INT;
    assign bypass_cond = signal_and_8 | signal_and_5;
    assign signal_mux_1 = bypass_cond ? signal_wire : memory;
    always @(posedge signal_wire_10) begin
        if (signal_or_2)
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
    config$period_fraction,
    start,
    program_write$valid,
    program_write$addr,
    program_write$data,
    tx$valid,
    tx$value,
    rx_pop,
    clear_irq,
    stop,
    flush,
    inputs,
    pin_out,
    pin_dir,
    pc,
    x,
    y,
    p,
    t,
    t_fraction,
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
    input [15:0] config$period_fraction;
    input start;
    input program_write$valid;
    input [8:0] program_write$addr;
    input [15:0] program_write$data;
    input tx$valid;
    input [15:0] tx$value;
    input rx_pop;
    input clear_irq;
    input stop;
    input flush;
    input [27:0] inputs;
    output [27:0] pin_out;
    output [27:0] pin_dir;
    output [8:0] pc;
    output [15:0] x;
    output [15:0] y;
    output [15:0] p;
    output [23:0] t;
    output [15:0] t_fraction;
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
    wire [27:0] signal_const_10;
    wire [15:0] signal_select_4;
    wire [11:0] signal_select_5;
    wire [27:0] signal_cat_1;
    wire [7:0] signal_select_6;
    wire [19:0] signal_select_7;
    wire [27:0] signal_cat_2;
    wire [3:0] signal_select_8;
    wire [23:0] signal_select_9;
    wire [27:0] signal_cat_3;
    wire [1:0] signal_select_10;
    wire [25:0] signal_select_11;
    wire [27:0] signal_cat_4;
    wire signal_select_12;
    wire [26:0] signal_select_13;
    wire [27:0] signal_cat_5;
    wire [10:0] signal_const_11;
    wire [15:0] signal_cat_6;
    wire [11:0] signal_const_12;
    wire [27:0] signal_cat_7;
    wire signal_select_14;
    wire [27:0] signal_mux_2;
    wire signal_select_15;
    wire [27:0] signal_mux_3;
    wire signal_select_16;
    wire [27:0] signal_mux_4;
    wire signal_select_17;
    wire [27:0] signal_mux_5;
    wire signal_select_18;
    wire [27:0] signal_mux_6;
    wire [27:0] signal_and_11;
    wire [27:0] signal_const_13;
    wire [15:0] signal_select_19;
    wire [11:0] signal_select_20;
    wire [27:0] signal_cat_8;
    wire [7:0] signal_select_21;
    wire [19:0] signal_select_22;
    wire [27:0] signal_cat_9;
    wire [3:0] signal_select_23;
    wire [23:0] signal_select_24;
    wire [27:0] signal_cat_10;
    wire [1:0] signal_select_25;
    wire [25:0] signal_select_26;
    wire [27:0] signal_cat_11;
    wire signal_select_27;
    wire [26:0] signal_select_28;
    wire [27:0] signal_cat_12;
    wire [15:0] signal_const_14;
    wire [7:0] signal_const_15;
    wire [7:0] signal_select_29;
    wire [15:0] signal_cat_13;
    wire [3:0] signal_const_16;
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
    wire [27:0] signal_cat_16;
    wire signal_select_37;
    wire [27:0] signal_mux_12;
    wire signal_select_38;
    wire [27:0] signal_mux_13;
    wire signal_select_39;
    wire [27:0] signal_mux_14;
    wire signal_select_40;
    wire [27:0] signal_mux_15;
    wire signal_select_41;
    wire [27:0] signal_mux_16;
    wire [27:0] signal_and_12;
    wire [27:0] signal_not_4;
    wire [27:0] signal_and_13;
    wire [27:0] signal_or_1;
    wire [2:0] signal_const_21;
    wire signal_eq_5;
    wire [27:0] signal_mux_17;
    wire [15:0] signal_select_42;
    wire [11:0] signal_select_43;
    wire [27:0] signal_cat_17;
    wire [7:0] signal_select_44;
    wire [19:0] signal_select_45;
    wire [27:0] signal_cat_18;
    wire [3:0] signal_select_46;
    wire [23:0] signal_select_47;
    wire [27:0] signal_cat_19;
    wire [1:0] signal_select_48;
    wire [25:0] signal_select_49;
    wire [27:0] signal_cat_20;
    wire signal_select_50;
    wire [26:0] signal_select_51;
    wire [27:0] signal_cat_21;
    wire [27:0] signal_cat_22;
    wire signal_select_52;
    wire [27:0] signal_mux_18;
    wire signal_select_53;
    wire [27:0] signal_mux_19;
    wire signal_select_54;
    wire [27:0] signal_mux_20;
    wire signal_select_55;
    wire [27:0] signal_mux_21;
    wire signal_select_56;
    wire [27:0] signal_mux_22;
    wire [27:0] signal_and_14;
    wire [15:0] signal_select_57;
    wire [11:0] signal_select_58;
    wire [27:0] signal_cat_23;
    wire [7:0] signal_select_59;
    wire [19:0] signal_select_60;
    wire [27:0] signal_cat_24;
    wire [3:0] signal_select_61;
    wire [23:0] signal_select_62;
    wire [27:0] signal_cat_25;
    wire [1:0] signal_select_63;
    wire [25:0] signal_select_64;
    wire [27:0] signal_cat_26;
    wire signal_select_65;
    wire [26:0] signal_select_66;
    wire [27:0] signal_cat_27;
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
    wire [27:0] signal_cat_31;
    wire signal_select_75;
    wire [27:0] signal_mux_28;
    wire signal_select_76;
    wire [27:0] signal_mux_29;
    wire signal_select_77;
    wire [27:0] signal_mux_30;
    wire signal_select_78;
    wire [27:0] signal_mux_31;
    wire signal_select_79;
    wire [27:0] signal_mux_32;
    wire [27:0] signal_and_15;
    wire [27:0] signal_not_6;
    wire [27:0] signal_and_16;
    wire [27:0] signal_or_2;
    wire signal_eq_6;
    wire [27:0] signal_mux_33;
    wire [15:0] signal_select_80;
    wire [11:0] signal_select_81;
    wire [27:0] signal_cat_32;
    wire [7:0] signal_select_82;
    wire [19:0] signal_select_83;
    wire [27:0] signal_cat_33;
    wire [3:0] signal_select_84;
    wire [23:0] signal_select_85;
    wire [27:0] signal_cat_34;
    wire [1:0] signal_select_86;
    wire [25:0] signal_select_87;
    wire [27:0] signal_cat_35;
    wire signal_select_88;
    wire [26:0] signal_select_89;
    wire [27:0] signal_cat_36;
    wire [27:0] signal_cat_37;
    wire signal_select_90;
    wire [27:0] signal_mux_34;
    wire signal_select_91;
    wire [27:0] signal_mux_35;
    wire signal_select_92;
    wire [27:0] signal_mux_36;
    wire signal_select_93;
    wire [27:0] signal_mux_37;
    wire signal_select_94;
    wire [27:0] signal_mux_38;
    wire [27:0] signal_and_17;
    wire [15:0] signal_select_95;
    wire [11:0] signal_select_96;
    wire [27:0] signal_cat_38;
    wire [7:0] signal_select_97;
    wire [19:0] signal_select_98;
    wire [27:0] signal_cat_39;
    wire [3:0] signal_select_99;
    wire [23:0] signal_select_100;
    wire [27:0] signal_cat_40;
    wire [1:0] signal_select_101;
    wire [25:0] signal_select_102;
    wire [27:0] signal_cat_41;
    wire signal_select_103;
    wire [26:0] signal_select_104;
    wire [27:0] signal_cat_42;
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
    wire [27:0] signal_cat_46;
    wire signal_select_113;
    wire [27:0] signal_mux_44;
    wire signal_select_114;
    wire [27:0] signal_mux_45;
    wire signal_select_115;
    wire [27:0] signal_mux_46;
    wire signal_select_116;
    wire [27:0] signal_mux_47;
    wire signal_select_117;
    wire [27:0] signal_mux_48;
    wire [27:0] signal_and_18;
    wire [27:0] signal_not_8;
    wire [27:0] signal_and_19;
    wire [27:0] signal_or_3;
    wire signal_eq_7;
    wire [27:0] signal_mux_49;
    wire [15:0] signal_select_118;
    wire [11:0] signal_select_119;
    wire [27:0] signal_cat_47;
    wire [7:0] signal_select_120;
    wire [19:0] signal_select_121;
    wire [27:0] signal_cat_48;
    wire [3:0] signal_select_122;
    wire [23:0] signal_select_123;
    wire [27:0] signal_cat_49;
    wire [1:0] signal_select_124;
    wire [25:0] signal_select_125;
    wire [27:0] signal_cat_50;
    wire signal_select_126;
    wire [26:0] signal_select_127;
    wire [27:0] signal_cat_51;
    wire [13:0] signal_const_42;
    wire [15:0] signal_cat_52;
    wire [27:0] signal_cat_53;
    wire signal_select_128;
    wire [27:0] signal_mux_50;
    wire signal_select_129;
    wire [27:0] signal_mux_51;
    wire signal_select_130;
    wire [27:0] signal_mux_52;
    wire signal_select_131;
    wire [27:0] signal_mux_53;
    wire signal_select_132;
    wire [27:0] signal_mux_54;
    wire [27:0] signal_and_20;
    wire [15:0] signal_select_133;
    wire [11:0] signal_select_134;
    wire [27:0] signal_cat_54;
    wire [7:0] signal_select_135;
    wire [19:0] signal_select_136;
    wire [27:0] signal_cat_55;
    wire [3:0] signal_select_137;
    wire [23:0] signal_select_138;
    wire [27:0] signal_cat_56;
    wire [1:0] signal_select_139;
    wire [25:0] signal_select_140;
    wire [27:0] signal_cat_57;
    wire signal_select_141;
    wire [26:0] signal_select_142;
    wire [27:0] signal_cat_58;
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
    wire [27:0] signal_cat_62;
    wire signal_select_151;
    wire [27:0] signal_mux_60;
    wire signal_select_152;
    wire [27:0] signal_mux_61;
    wire signal_select_153;
    wire [27:0] signal_mux_62;
    wire signal_select_154;
    wire [27:0] signal_mux_63;
    wire signal_select_155;
    wire [27:0] signal_mux_64;
    wire [27:0] signal_and_21;
    wire [27:0] signal_not_10;
    wire [27:0] signal_and_22;
    wire [27:0] pin_out_side;
    wire [27:0] pin_out_base;
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
    wire signal_select_176;
    wire signal_select_177;
    wire signal_select_178;
    wire signal_select_179;
    wire signal_select_180;
    wire signal_select_181;
    wire signal_select_182;
    wire signal_select_183;
    reg signal_mux_72;
    wire signal_not_15;
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
    wire signal_select_196;
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
    wire signal_select_212;
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
    wire [23:0] signal_cat_64;
    wire [23:0] signal_not_25;
    reg [23:0] mov_value_t;
    wire [2:0] signal_const_85;
    wire signal_eq_22;
    wire [23:0] signal_mux_87;
    wire [23:0] signal_cat_65;
    wire signal_eq_23;
    wire [23:0] signal_mux_88;
    wire [15:0] signal_wire_12;
    wire [16:0] signal_cat_66;
    wire signal_eq_24;
    wire [15:0] signal_mux_89;
    wire signal_eq_25;
    wire [15:0] signal_mux_90;
    wire signal_eq_26;
    wire [15:0] signal_mux_91;
    wire [15:0] signal_select_237;
    wire [15:0] signal_mux_92;
    reg [15:0] t_fraction_next;
    reg [15:0] signal_reg_6;
    wire [15:0] t_fraction_0;
    wire [16:0] signal_cat_67;
    wire [16:0] fraction_sum;
    wire signal_select_238;
    wire [22:0] signal_const_95;
    wire [23:0] signal_cat_68;
    wire [23:0] signal_cat_69;
    wire [23:0] signal_add_4;
    wire [23:0] t_advanced;
    wire [1:0] signal_const_97;
    wire signal_eq_27;
    wire signal_and_34;
    wire releases_deadline;
    wire advances_deadline;
    wire [23:0] signal_mux_93;
    reg [23:0] t_next;
    reg [23:0] signal_reg_7;
    wire [23:0] t_0;
    wire [23:0] signal_sub_4;
    wire signal_select_239;
    wire deadline_ready;
    wire signal_eq_28;
    wire signal_select_240;
    wire signal_select_241;
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
    reg wait_pin_prev;
    wire signal_eq_29;
    wire signal_not_26;
    wire signal_and_35;
    wire d$wait_polarity;
    wire signal_select_268;
    wire signal_select_269;
    wire signal_select_270;
    wire signal_select_271;
    wire signal_select_272;
    wire signal_select_273;
    wire signal_select_274;
    wire signal_select_275;
    wire signal_select_276;
    wire signal_select_277;
    wire signal_select_278;
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
    wire signal_select_300;
    wire signal_select_301;
    wire signal_select_302;
    wire signal_select_303;
    wire signal_select_304;
    wire signal_select_305;
    wire signal_select_306;
    wire signal_select_307;
    wire signal_select_308;
    wire signal_select_309;
    wire signal_mux_94;
    wire signal_select_310;
    wire signal_select_311;
    wire signal_select_312;
    wire signal_mux_95;
    wire signal_select_313;
    wire signal_select_314;
    wire signal_select_315;
    wire signal_mux_96;
    wire signal_select_316;
    wire signal_select_317;
    wire signal_select_318;
    wire signal_mux_97;
    wire signal_select_319;
    wire signal_select_320;
    wire signal_select_321;
    wire signal_mux_98;
    wire signal_select_322;
    wire signal_select_323;
    wire signal_select_324;
    wire signal_mux_99;
    wire signal_select_325;
    wire signal_select_326;
    wire signal_select_327;
    wire signal_mux_100;
    wire signal_select_328;
    wire signal_select_329;
    wire [15:0] signal_select_330;
    wire [11:0] signal_select_331;
    wire [27:0] signal_cat_70;
    wire [7:0] signal_select_332;
    wire [19:0] signal_select_333;
    wire [27:0] signal_cat_71;
    wire [3:0] signal_select_334;
    wire [23:0] signal_select_335;
    wire [27:0] signal_cat_72;
    wire [1:0] signal_select_336;
    wire [25:0] signal_select_337;
    wire [27:0] signal_cat_73;
    wire signal_select_338;
    wire [26:0] signal_select_339;
    wire [27:0] signal_cat_74;
    wire [15:0] signal_cat_75;
    wire [27:0] signal_cat_76;
    wire signal_select_340;
    wire [27:0] signal_mux_101;
    wire signal_select_341;
    wire [27:0] signal_mux_102;
    wire signal_select_342;
    wire [27:0] signal_mux_103;
    wire signal_select_343;
    wire [27:0] signal_mux_104;
    wire signal_select_344;
    wire [27:0] signal_mux_105;
    wire [27:0] signal_and_36;
    wire [27:0] signal_const_101;
    wire [15:0] signal_select_345;
    wire [11:0] signal_select_346;
    wire [27:0] signal_cat_77;
    wire [7:0] signal_select_347;
    wire [19:0] signal_select_348;
    wire [27:0] signal_cat_78;
    wire [3:0] signal_select_349;
    wire [23:0] signal_select_350;
    wire [27:0] signal_cat_79;
    wire [1:0] signal_select_351;
    wire [25:0] signal_select_352;
    wire [27:0] signal_cat_80;
    wire signal_select_353;
    wire [26:0] signal_select_354;
    wire [27:0] signal_cat_81;
    wire [7:0] signal_select_355;
    wire [15:0] signal_cat_82;
    wire [11:0] signal_select_356;
    wire [15:0] signal_cat_83;
    wire [13:0] signal_select_357;
    wire [15:0] signal_cat_84;
    wire signal_select_358;
    wire [15:0] signal_mux_106;
    wire signal_select_359;
    wire [15:0] signal_mux_107;
    wire signal_select_360;
    wire [15:0] signal_mux_108;
    wire signal_select_361;
    wire [15:0] signal_mux_109;
    wire [2:0] signal_wire_13;
    wire [4:0] signal_cat_85;
    wire signal_select_362;
    wire [15:0] signal_mux_110;
    wire [15:0] signal_not_27;
    wire [27:0] signal_cat_86;
    wire signal_select_363;
    wire [27:0] signal_mux_111;
    wire signal_select_364;
    wire [27:0] signal_mux_112;
    wire signal_select_365;
    wire [27:0] signal_mux_113;
    wire signal_select_366;
    wire [27:0] signal_mux_114;
    wire [4:0] signal_wire_14;
    wire signal_select_367;
    wire [27:0] signal_mux_115;
    wire [27:0] signal_and_37;
    wire [27:0] signal_not_28;
    wire [27:0] signal_and_38;
    wire [27:0] signal_or_5;
    wire signal_eq_30;
    wire [27:0] signal_mux_116;
    wire [15:0] signal_select_368;
    wire [11:0] signal_select_369;
    wire [27:0] signal_cat_87;
    wire [7:0] signal_select_370;
    wire [19:0] signal_select_371;
    wire [27:0] signal_cat_88;
    wire [3:0] signal_select_372;
    wire [23:0] signal_select_373;
    wire [27:0] signal_cat_89;
    wire [1:0] signal_select_374;
    wire [25:0] signal_select_375;
    wire [27:0] signal_cat_90;
    wire signal_select_376;
    wire [26:0] signal_select_377;
    wire [27:0] signal_cat_91;
    wire [27:0] signal_cat_92;
    wire signal_select_378;
    wire [27:0] signal_mux_117;
    wire signal_select_379;
    wire [27:0] signal_mux_118;
    wire signal_select_380;
    wire [27:0] signal_mux_119;
    wire signal_select_381;
    wire [27:0] signal_mux_120;
    wire signal_select_382;
    wire [27:0] signal_mux_121;
    wire [27:0] signal_and_39;
    wire [15:0] signal_select_383;
    wire [11:0] signal_select_384;
    wire [27:0] signal_cat_93;
    wire [7:0] signal_select_385;
    wire [19:0] signal_select_386;
    wire [27:0] signal_cat_94;
    wire [3:0] signal_select_387;
    wire [23:0] signal_select_388;
    wire [27:0] signal_cat_95;
    wire [1:0] signal_select_389;
    wire [25:0] signal_select_390;
    wire [27:0] signal_cat_96;
    wire signal_select_391;
    wire [26:0] signal_select_392;
    wire [27:0] signal_cat_97;
    wire [7:0] signal_select_393;
    wire [15:0] signal_cat_98;
    wire [11:0] signal_select_394;
    wire [15:0] signal_cat_99;
    wire [13:0] signal_select_395;
    wire [15:0] signal_cat_100;
    wire signal_select_396;
    wire [15:0] signal_mux_122;
    wire signal_select_397;
    wire [15:0] signal_mux_123;
    wire signal_select_398;
    wire [15:0] signal_mux_124;
    wire signal_select_399;
    wire [15:0] signal_mux_125;
    wire [4:0] signal_wire_15;
    wire signal_select_400;
    wire [15:0] signal_mux_126;
    wire [15:0] signal_not_29;
    wire [27:0] signal_cat_101;
    wire signal_select_401;
    wire [27:0] signal_mux_127;
    wire signal_select_402;
    wire [27:0] signal_mux_128;
    wire signal_select_403;
    wire [27:0] signal_mux_129;
    wire signal_select_404;
    wire [27:0] signal_mux_130;
    wire signal_select_405;
    wire [27:0] signal_mux_131;
    wire [27:0] signal_and_40;
    wire [27:0] signal_not_30;
    wire [27:0] signal_and_41;
    wire [27:0] signal_or_6;
    wire signal_eq_31;
    wire [27:0] signal_mux_132;
    wire [15:0] signal_select_406;
    wire [11:0] signal_select_407;
    wire [27:0] signal_cat_102;
    wire [7:0] signal_select_408;
    wire [19:0] signal_select_409;
    wire [27:0] signal_cat_103;
    wire [3:0] signal_select_410;
    wire [23:0] signal_select_411;
    wire [27:0] signal_cat_104;
    wire [1:0] signal_select_412;
    wire [25:0] signal_select_413;
    wire [27:0] signal_cat_105;
    wire signal_select_414;
    wire [26:0] signal_select_415;
    wire [27:0] signal_cat_106;
    wire [15:0] signal_and_42;
    wire [7:0] signal_select_416;
    wire [15:0] signal_cat_107;
    wire [11:0] signal_select_417;
    wire [15:0] signal_cat_108;
    wire [13:0] signal_select_418;
    wire [15:0] signal_cat_109;
    wire [14:0] signal_select_419;
    wire [15:0] signal_cat_110;
    wire [15:0] signal_select_420;
    wire signal_not_31;
    wire signal_and_43;
    wire [15:0] signal_mux_133;
    wire signal_select_421;
    wire signal_select_422;
    wire signal_select_423;
    wire signal_select_424;
    wire signal_select_425;
    wire signal_select_426;
    wire signal_select_427;
    wire signal_select_428;
    wire signal_select_429;
    wire signal_select_430;
    wire signal_select_431;
    wire signal_select_432;
    wire signal_select_433;
    wire signal_select_434;
    wire signal_select_435;
    wire signal_select_436;
    wire [15:0] signal_cat_111;
    wire [15:0] signal_not_32;
    wire [23:0] signal_cat_112;
    wire [23:0] signal_cat_113;
    wire [23:0] signal_cat_114;
    wire [15:0] signal_xor_1;
    wire [15:0] signal_sub_5;
    wire signal_eq_32;
    wire signal_and_44;
    wire [15:0] signal_mux_134;
    wire signal_eq_33;
    wire [15:0] signal_mux_135;
    wire signal_eq_34;
    wire [15:0] signal_mux_136;
    wire [7:0] signal_select_437;
    wire [15:0] signal_cat_115;
    wire [11:0] signal_select_438;
    wire [15:0] signal_cat_116;
    wire [13:0] signal_select_439;
    wire [15:0] signal_cat_117;
    wire [14:0] signal_select_440;
    wire [15:0] signal_cat_118;
    wire signal_select_441;
    wire [15:0] signal_mux_137;
    wire signal_select_442;
    wire [15:0] signal_mux_138;
    wire signal_select_443;
    wire [15:0] signal_mux_139;
    wire signal_select_444;
    wire [15:0] signal_mux_140;
    wire signal_select_445;
    wire [15:0] signal_mux_141;
    wire [7:0] signal_select_446;
    wire [15:0] signal_cat_119;
    wire [11:0] signal_select_447;
    wire [15:0] signal_cat_120;
    wire [13:0] signal_select_448;
    wire [15:0] signal_cat_121;
    wire [14:0] signal_select_449;
    wire [15:0] signal_cat_122;
    wire signal_select_450;
    wire [15:0] signal_mux_142;
    wire signal_select_451;
    wire [15:0] signal_mux_143;
    wire signal_select_452;
    wire [15:0] signal_mux_144;
    wire signal_select_453;
    wire [15:0] signal_mux_145;
    wire signal_select_454;
    wire [15:0] signal_mux_146;
    wire [15:0] signal_or_7;
    wire [7:0] signal_select_455;
    wire [15:0] signal_cat_123;
    wire [11:0] signal_select_456;
    wire [15:0] signal_cat_124;
    wire [13:0] signal_select_457;
    wire [15:0] signal_cat_125;
    wire signal_select_458;
    wire [15:0] signal_mux_147;
    wire signal_select_459;
    wire [15:0] signal_mux_148;
    wire signal_select_460;
    wire [15:0] signal_mux_149;
    wire signal_select_461;
    wire [15:0] signal_mux_150;
    wire signal_select_462;
    wire [15:0] signal_mux_151;
    wire [15:0] mask;
    wire signal_wire_16;
    wire signal_select_463;
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
    wire signal_select_480;
    wire signal_select_481;
    wire signal_select_482;
    wire signal_select_483;
    wire signal_select_484;
    wire signal_select_485;
    wire signal_select_486;
    wire signal_select_487;
    wire signal_select_488;
    wire signal_select_489;
    wire signal_select_490;
    reg signal_mux_152;
    wire signal_eq_35;
    wire signal_select_491;
    wire signal_select_492;
    wire signal_select_493;
    wire signal_select_494;
    wire signal_select_495;
    wire signal_select_496;
    wire signal_select_497;
    wire signal_select_498;
    wire signal_select_499;
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
    wire signal_select_516;
    wire signal_select_517;
    reg [27:0] signal_reg_8;
    wire [27:0] pins_sampled;
    wire signal_select_518;
    reg signal_mux_153;
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
    wire signal_select_534;
    wire signal_select_535;
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
    wire [4:0] signal_wire_17;
    reg signal_mux_154;
    wire signal_eq_36;
    wire signal_not_33;
    wire signal_eq_37;
    wire signal_and_45;
    wire signal_and_46;
    wire signal_mux_155;
    wire signal_mux_156;
    reg signal_reg_9;
    wire capture_armed_0;
    wire signal_and_47;
    wire captured;
    wire [23:0] signal_const_160;
    wire [23:0] signal_add_5;
    wire [23:0] signal_mux_157;
    reg [23:0] signal_reg_10;
    wire [23:0] now_0;
    reg [23:0] signal_reg_11;
    wire [23:0] capture_0;
    wire [15:0] signal_select_547;
    wire [15:0] signal_wire_18;
    wire [7:0] signal_select_548;
    wire [15:0] signal_cat_126;
    wire [11:0] signal_select_549;
    wire [15:0] signal_cat_127;
    wire [13:0] signal_select_550;
    wire [15:0] signal_cat_128;
    wire signal_select_551;
    wire [15:0] signal_mux_158;
    wire signal_select_552;
    wire [15:0] signal_mux_159;
    wire signal_select_553;
    wire [15:0] signal_mux_160;
    wire signal_select_554;
    wire [15:0] signal_mux_161;
    wire signal_select_555;
    wire [15:0] signal_mux_162;
    wire [15:0] signal_not_34;
    wire [15:0] signal_xor_2;
    wire [14:0] signal_select_556;
    wire [15:0] signal_cat_129;
    wire signal_select_557;
    wire signal_xor_3;
    wire [15:0] signal_mux_163;
    wire [15:0] signal_wire_19;
    wire [15:0] signal_xor_4;
    wire [14:0] signal_select_558;
    wire [15:0] signal_cat_130;
    wire signal_select_559;
    wire signal_select_560;
    wire crossing_bit;
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
    wire signal_select_575;
    wire signal_select_576;
    wire [4:0] signal_wire_20;
    wire [4:0] signal_sub_6;
    reg signal_mux_164;
    wire signal_xor_5;
    wire [15:0] signal_mux_165;
    wire signal_wire_21;
    wire [15:0] signal_mux_166;
    wire [15:0] crc_stepped;
    wire signal_eq_38;
    reg is_opcode$2;
    wire signal_or_8;
    wire signal_eq_39;
    wire bit_crosses;
    wire [15:0] signal_mux_167;
    wire signal_eq_40;
    wire signal_and_48;
    wire [15:0] crc_next;
    wire [15:0] signal_mux_168;
    wire [15:0] signal_mux_169;
    reg [15:0] signal_reg_12;
    wire [15:0] crc_0;
    wire [7:0] signal_select_577;
    wire [15:0] signal_cat_131;
    wire [11:0] signal_select_578;
    wire [15:0] signal_cat_132;
    wire [13:0] signal_select_579;
    wire [15:0] signal_cat_133;
    wire signal_select_580;
    wire [15:0] signal_mux_170;
    wire signal_select_581;
    wire [15:0] signal_mux_171;
    wire signal_select_582;
    wire [15:0] signal_mux_172;
    wire signal_select_583;
    wire [15:0] signal_mux_173;
    wire signal_select_584;
    wire [15:0] signal_mux_174;
    wire [15:0] signal_not_35;
    wire [11:0] signal_select_585;
    wire [15:0] signal_select_586;
    wire [27:0] signal_cat_134;
    wire [19:0] signal_select_587;
    wire [7:0] signal_select_588;
    wire [27:0] signal_cat_135;
    wire [23:0] signal_select_589;
    wire [3:0] signal_select_590;
    wire [27:0] signal_cat_136;
    wire [25:0] signal_select_591;
    wire [1:0] signal_select_592;
    wire [27:0] signal_cat_137;
    wire [26:0] signal_select_593;
    wire signal_select_594;
    wire [27:0] signal_cat_138;
    wire signal_select_595;
    wire [27:0] signal_mux_175;
    wire signal_select_596;
    wire [27:0] signal_mux_176;
    wire signal_select_597;
    wire [27:0] signal_mux_177;
    wire signal_select_598;
    wire [27:0] signal_mux_178;
    wire signal_select_599;
    wire [27:0] signal_mux_179;
    wire [15:0] signal_select_600;
    wire [15:0] signal_and_49;
    reg [15:0] signal_mux_180;
    wire [15:0] in_value;
    wire [7:0] signal_select_601;
    wire [15:0] signal_cat_139;
    wire [11:0] signal_select_602;
    wire [15:0] signal_cat_140;
    wire [13:0] signal_select_603;
    wire [15:0] signal_cat_141;
    wire [14:0] signal_select_604;
    wire [15:0] signal_cat_142;
    wire signal_select_605;
    wire [15:0] signal_mux_181;
    wire signal_select_606;
    wire [15:0] signal_mux_182;
    wire signal_select_607;
    wire [15:0] signal_mux_183;
    wire signal_select_608;
    wire [15:0] signal_mux_184;
    wire signal_select_609;
    wire [15:0] signal_mux_185;
    wire [15:0] signal_or_9;
    wire signal_wire_22;
    wire [15:0] isr_shifted;
    wire [4:0] signal_wire_23;
    wire [4:0] signal_const_186;
    wire [4:0] signal_select_610;
    wire [5:0] signal_cat_143;
    wire signal_eq_41;
    wire signal_and_50;
    wire [4:0] signal_mux_186;
    wire signal_eq_42;
    wire [4:0] signal_mux_187;
    wire signal_eq_43;
    wire [4:0] signal_mux_188;
    wire [4:0] signal_mux_189;
    reg [4:0] isr_count_next_value;
    reg [4:0] signal_reg_13;
    wire [4:0] isr_count_0;
    wire [5:0] signal_cat_144;
    wire [5:0] signal_add_6;
    wire [5:0] signal_const_191;
    wire signal_lt_2;
    wire [4:0] isr_count_next;
    wire signal_lt_3;
    wire signal_not_36;
    wire signal_wire_24;
    wire autopush_now;
    wire [15:0] signal_mux_190;
    reg [15:0] isr_next;
    reg [15:0] signal_reg_14;
    wire [15:0] isr_0;
    wire [15:0] signal_xor_6;
    wire [15:0] signal_sub_7;
    wire [15:0] signal_add_7;
    reg [15:0] signal_mux_191;
    wire signal_eq_44;
    wire [15:0] signal_mux_192;
    wire [15:0] signal_cat_145;
    wire signal_eq_45;
    wire [15:0] signal_mux_193;
    wire signal_eq_46;
    wire [15:0] signal_mux_194;
    wire signal_eq_47;
    wire [15:0] signal_mux_195;
    reg [15:0] p_next;
    reg [15:0] signal_reg_15;
    wire [15:0] p_0;
    wire [15:0] signal_xor_7;
    wire [15:0] signal_sub_8;
    wire [15:0] signal_add_8;
    reg [15:0] signal_mux_196;
    wire [1:0] signal_const_199;
    wire signal_eq_48;
    wire [15:0] signal_mux_197;
    wire [15:0] signal_cat_146;
    wire signal_eq_49;
    wire [15:0] signal_mux_198;
    wire signal_eq_50;
    wire [15:0] signal_mux_199;
    wire signal_eq_51;
    wire [15:0] signal_mux_200;
    wire [15:0] signal_const_204;
    wire [15:0] signal_sub_9;
    wire [3:0] signal_const_205;
    wire signal_eq_52;
    wire [15:0] signal_mux_201;
    reg [15:0] y_next;
    reg [15:0] signal_reg_16;
    wire [15:0] y_0;
    reg [15:0] signal_mux_202;
    wire [2:0] d$alu_reg$binary_variant;
    wire [2:0] d$alu_imm;
    wire [12:0] signal_const_206;
    wire [15:0] signal_cat_147;
    wire d$alu_is_reg;
    wire [15:0] alu_operand;
    wire [15:0] signal_add_9;
    wire [1:0] d$alu_op$binary_variant;
    reg [15:0] signal_mux_203;
    wire [1:0] d$alu_dest$binary_variant;
    wire signal_eq_53;
    wire [15:0] signal_mux_204;
    wire [4:0] d$set_value;
    wire [15:0] signal_cat_148;
    wire [2:0] d$set_dest$binary_variant;
    wire signal_eq_54;
    wire [15:0] signal_mux_205;
    wire signal_eq_55;
    wire [15:0] signal_mux_206;
    wire signal_eq_56;
    wire [15:0] signal_mux_207;
    wire [15:0] signal_sub_10;
    wire [3:0] signal_const_213;
    wire [3:0] d$jmp_cond$binary_variant;
    wire signal_eq_57;
    wire [15:0] signal_mux_208;
    reg [15:0] x_next;
    reg [15:0] signal_reg_17;
    wire [15:0] x_0;
    wire [23:0] signal_cat_149;
    wire [7:0] signal_select_611;
    wire [15:0] signal_cat_150;
    wire [11:0] signal_select_612;
    wire [15:0] signal_cat_151;
    wire [13:0] signal_select_613;
    wire [15:0] signal_cat_152;
    wire signal_select_614;
    wire [15:0] signal_mux_209;
    wire signal_select_615;
    wire [15:0] signal_mux_210;
    wire signal_select_616;
    wire [15:0] signal_mux_211;
    wire signal_select_617;
    wire [15:0] signal_mux_212;
    wire [4:0] signal_wire_25;
    wire signal_select_618;
    wire [15:0] signal_mux_213;
    wire [15:0] signal_not_37;
    wire [11:0] signal_select_619;
    wire [15:0] signal_select_620;
    wire [27:0] signal_cat_153;
    wire [19:0] signal_select_621;
    wire [7:0] signal_select_622;
    wire [27:0] signal_cat_154;
    wire [23:0] signal_select_623;
    wire [3:0] signal_select_624;
    wire [27:0] signal_cat_155;
    wire [25:0] signal_select_625;
    wire [1:0] signal_select_626;
    wire [27:0] signal_cat_156;
    wire [26:0] signal_select_627;
    wire signal_select_628;
    wire [27:0] signal_cat_157;
    wire signal_select_629;
    wire [27:0] signal_mux_214;
    wire signal_select_630;
    wire [27:0] signal_mux_215;
    wire signal_select_631;
    wire [27:0] signal_mux_216;
    wire signal_select_632;
    wire [27:0] signal_mux_217;
    wire [4:0] signal_wire_26;
    wire signal_select_633;
    wire [27:0] signal_mux_218;
    wire [15:0] signal_select_634;
    wire [15:0] signal_and_51;
    wire [23:0] signal_cat_158;
    wire [2:0] d$mov_source$binary_variant;
    reg [23:0] mov_value24;
    wire [15:0] signal_select_635;
    wire [1:0] d$mov_op$binary_variant;
    reg [15:0] mov_value;
    wire signal_eq_58;
    wire [15:0] signal_mux_219;
    wire [7:0] signal_select_636;
    wire [15:0] signal_cat_159;
    wire [11:0] signal_select_637;
    wire [15:0] signal_cat_160;
    wire [13:0] signal_select_638;
    wire [15:0] signal_cat_161;
    wire [14:0] signal_select_639;
    wire [15:0] signal_cat_162;
    wire signal_select_640;
    wire [15:0] signal_mux_220;
    wire signal_select_641;
    wire [15:0] signal_mux_221;
    wire signal_select_642;
    wire [15:0] signal_mux_222;
    wire signal_select_643;
    wire [15:0] signal_mux_223;
    wire signal_select_644;
    wire [15:0] signal_mux_224;
    wire [7:0] signal_select_645;
    wire [15:0] signal_cat_163;
    wire [11:0] signal_select_646;
    wire [15:0] signal_cat_164;
    wire [13:0] signal_select_647;
    wire [15:0] signal_cat_165;
    wire [14:0] signal_select_648;
    wire [15:0] signal_cat_166;
    wire signal_select_649;
    wire [15:0] signal_mux_225;
    wire signal_select_650;
    wire [15:0] signal_mux_226;
    wire signal_select_651;
    wire [15:0] signal_mux_227;
    wire signal_select_652;
    wire [15:0] signal_mux_228;
    wire signal_select_653;
    wire [15:0] signal_mux_229;
    wire [15:0] osr_shifted;
    reg [15:0] osr_next;
    reg [15:0] signal_reg_18;
    wire [15:0] osr_0;
    wire signal_wire_27;
    wire flush_0;
    wire signal_not_38;
    wire signal_and_52;
    wire signal_eq_59;
    reg is_opcode$3;
    wire signal_and_53;
    wire signal_or_10;
    wire signal_and_54;
    wire tx_pop;
    wire [15:0] signal_wire_28;
    wire signal_wire_29;
    wire [21:0] signal_inst_1;
    wire signal_select_654;
    wire signal_not_39;
    wire [4:0] signal_wire_30;
    wire [2:0] d$sys_op$binary_variant;
    wire signal_eq_60;
    wire signal_eq_61;
    reg is_opcode$7;
    wire pulls;
    wire [4:0] signal_mux_230;
    wire [4:0] osr_count_zero;
    wire [2:0] d$mov_dest$binary_variant;
    wire signal_eq_62;
    wire [4:0] signal_mux_231;
    wire [4:0] signal_select_655;
    wire [5:0] signal_cat_167;
    wire [4:0] osr_count_before;
    wire [5:0] signal_cat_168;
    wire [5:0] signal_add_10;
    wire signal_lt_4;
    wire [4:0] osr_count_next;
    reg [4:0] osr_count_next_value;
    reg [4:0] signal_reg_19;
    wire [4:0] osr_count_0;
    wire signal_lt_5;
    wire signal_not_40;
    wire signal_wire_31;
    wire pull_now;
    wire pull_ok;
    wire [15:0] osr_before;
    wire signal_select_656;
    wire [15:0] signal_mux_232;
    wire signal_select_657;
    wire [15:0] signal_mux_233;
    wire signal_select_658;
    wire [15:0] signal_mux_234;
    wire signal_select_659;
    wire [15:0] signal_mux_235;
    wire [4:0] shift_back;
    wire signal_select_660;
    wire [15:0] signal_mux_236;
    wire [15:0] signal_and_55;
    wire signal_wire_32;
    wire [15:0] out_value;
    wire [27:0] signal_cat_169;
    wire signal_select_661;
    wire [27:0] signal_mux_237;
    wire signal_select_662;
    wire [27:0] signal_mux_238;
    wire signal_select_663;
    wire [27:0] signal_mux_239;
    wire signal_select_664;
    wire [27:0] signal_mux_240;
    wire signal_select_665;
    wire [27:0] signal_mux_241;
    wire [27:0] signal_and_56;
    wire [15:0] signal_select_666;
    wire [11:0] signal_select_667;
    wire [27:0] signal_cat_170;
    wire [7:0] signal_select_668;
    wire [19:0] signal_select_669;
    wire [27:0] signal_cat_171;
    wire [3:0] signal_select_670;
    wire [23:0] signal_select_671;
    wire [27:0] signal_cat_172;
    wire [1:0] signal_select_672;
    wire [25:0] signal_select_673;
    wire [27:0] signal_cat_173;
    wire signal_select_674;
    wire [26:0] signal_select_675;
    wire [27:0] signal_cat_174;
    wire [7:0] signal_select_676;
    wire [15:0] signal_cat_175;
    wire [11:0] signal_select_677;
    wire [15:0] signal_cat_176;
    wire [13:0] signal_select_678;
    wire [15:0] signal_cat_177;
    wire signal_select_679;
    wire [15:0] signal_mux_242;
    wire signal_select_680;
    wire [15:0] signal_mux_243;
    wire signal_select_681;
    wire [15:0] signal_mux_244;
    wire signal_select_682;
    wire [15:0] signal_mux_245;
    wire [4:0] d$shift_count;
    wire signal_select_683;
    wire [15:0] signal_mux_246;
    wire [15:0] signal_not_41;
    wire [27:0] signal_cat_178;
    wire signal_select_684;
    wire [27:0] signal_mux_247;
    wire signal_select_685;
    wire [27:0] signal_mux_248;
    wire signal_select_686;
    wire [27:0] signal_mux_249;
    wire signal_select_687;
    wire [27:0] signal_mux_250;
    wire [4:0] signal_wire_33;
    wire signal_select_688;
    wire [27:0] signal_mux_251;
    wire [27:0] signal_and_57;
    wire [27:0] signal_not_42;
    wire [27:0] signal_and_58;
    wire [27:0] signal_or_11;
    wire [2:0] d$out_dest$binary_variant;
    wire [2:0] d$in_source$binary_variant;
    wire signal_eq_63;
    wire [27:0] signal_mux_252;
    wire [15:0] signal_select_689;
    wire [11:0] signal_select_690;
    wire [27:0] signal_cat_179;
    wire [7:0] signal_select_691;
    wire [19:0] signal_select_692;
    wire [27:0] signal_cat_180;
    wire [3:0] signal_select_693;
    wire [23:0] signal_select_694;
    wire [27:0] signal_cat_181;
    wire [1:0] signal_select_695;
    wire [25:0] signal_select_696;
    wire [27:0] signal_cat_182;
    wire signal_select_697;
    wire [26:0] signal_select_698;
    wire [27:0] signal_cat_183;
    wire [1:0] signal_select_699;
    wire [1:0] signal_select_700;
    wire [4:0] signal_select_701;
    wire signal_select_702;
    wire [1:0] signal_cat_184;
    reg [1:0] d$side_set;
    wire [15:0] signal_cat_185;
    wire [27:0] signal_cat_186;
    wire signal_select_703;
    wire [27:0] signal_mux_253;
    wire signal_select_704;
    wire [27:0] signal_mux_254;
    wire signal_select_705;
    wire [27:0] signal_mux_255;
    wire signal_select_706;
    wire [27:0] signal_mux_256;
    wire signal_select_707;
    wire [27:0] signal_mux_257;
    wire [27:0] signal_and_59;
    wire [15:0] signal_select_708;
    wire [11:0] signal_select_709;
    wire [27:0] signal_cat_187;
    wire [7:0] signal_select_710;
    wire [19:0] signal_select_711;
    wire [27:0] signal_cat_188;
    wire [3:0] signal_select_712;
    wire [23:0] signal_select_713;
    wire [27:0] signal_cat_189;
    wire [1:0] signal_select_714;
    wire [25:0] signal_select_715;
    wire [27:0] signal_cat_190;
    wire signal_select_716;
    wire [26:0] signal_select_717;
    wire [27:0] signal_cat_191;
    wire [7:0] signal_select_718;
    wire [15:0] signal_cat_192;
    wire [11:0] signal_select_719;
    wire [15:0] signal_cat_193;
    wire [13:0] signal_select_720;
    wire [15:0] signal_cat_194;
    wire signal_select_721;
    wire [15:0] signal_mux_258;
    wire signal_select_722;
    wire [15:0] signal_mux_259;
    wire signal_select_723;
    wire [15:0] signal_mux_260;
    wire signal_select_724;
    wire [15:0] signal_mux_261;
    wire [1:0] signal_wire_34;
    wire [4:0] signal_cat_195;
    wire signal_select_725;
    wire [15:0] signal_mux_262;
    wire [15:0] signal_not_43;
    wire [27:0] signal_cat_196;
    wire signal_select_726;
    wire [27:0] signal_mux_263;
    wire signal_select_727;
    wire [27:0] signal_mux_264;
    wire signal_select_728;
    wire [27:0] signal_mux_265;
    wire signal_select_729;
    wire [27:0] signal_mux_266;
    wire [4:0] signal_wire_35;
    wire signal_select_730;
    wire [27:0] signal_mux_267;
    wire [27:0] signal_and_60;
    wire [27:0] signal_not_44;
    wire [27:0] signal_and_61;
    wire [27:0] pin_dir_side;
    wire signal_wire_36;
    wire [27:0] pin_dir_base;
    reg [27:0] pin_dir_next;
    reg [27:0] signal_reg_20;
    wire [27:0] pin_dir_0;
    wire signal_select_731;
    wire signal_mux_268;
    wire signal_select_732;
    wire signal_select_733;
    wire signal_or_12;
    wire signal_select_734;
    wire signal_select_735;
    wire signal_or_13;
    wire signal_select_736;
    wire signal_select_737;
    wire signal_or_14;
    wire signal_select_738;
    wire signal_select_739;
    wire signal_or_15;
    wire signal_select_740;
    wire signal_select_741;
    wire signal_or_16;
    wire signal_select_742;
    wire signal_select_743;
    wire signal_or_17;
    wire signal_select_744;
    wire signal_select_745;
    wire signal_or_18;
    wire [27:0] signal_wire_37;
    wire signal_select_746;
    wire signal_select_747;
    wire signal_or_19;
    wire [27:0] sample;
    wire signal_select_748;
    wire [4:0] d$wait_index;
    reg wait_pin_cur;
    wire signal_eq_64;
    wire [1:0] d$wait_source$binary_variant;
    reg wait_ready;
    wire signal_not_45;
    wire gnd;
    wire signal_eq_65;
    reg is_opcode$1;
    wire wait_holds;
    wire signal_not_46;
    wire signal_eq_66;
    reg is_opcode$0;
    wire signal_not_47;
    wire op_go;
    wire advance;
    wire signal_or_20;
    wire ir_load;
    wire [4:0] signal_select_749;
    wire signal_eq_67;
    wire [2:0] signal_select_750;
    wire signal_lt_6;
    wire signal_select_751;
    wire signal_not_48;
    wire signal_or_21;
    wire [1:0] signal_select_752;
    wire signal_lt_7;
    wire signal_and_62;
    wire [2:0] signal_select_753;
    wire signal_lt_8;
    wire [1:0] signal_select_754;
    wire signal_lt_9;
    wire signal_lt_10;
    wire signal_not_49;
    wire [4:0] signal_select_755;
    wire signal_lt_11;
    wire signal_not_50;
    wire signal_and_63;
    wire signal_eq_68;
    wire signal_eq_69;
    wire [4:0] signal_const_275;
    wire signal_lt_12;
    wire [4:0] signal_select_756;
    wire signal_lt_13;
    wire [1:0] signal_select_757;
    reg signal_mux_269;
    wire [3:0] signal_const_277;
    wire [3:0] signal_select_758;
    wire signal_lt_14;
    wire [2:0] signal_select_759;
    reg signal_mux_270;
    reg decode_ok_0;
    wire go;
    wire jmp_go;
    wire [4:0] signal_mux_271;
    wire [4:0] stall_next;
    reg [4:0] signal_reg_21;
    wire [4:0] stall_0;
    wire signal_eq_70;
    wire signal_not_51;
    wire signal_and_64;
    wire issue;
    wire signal_and_65;
    wire signal_mux_272;
    wire signal_wire_38;
    wire signal_mux_273;
    wire signal_wire_39;
    wire signal_wire_40;
    reg start_0;
    wire halted_next;
    reg signal_reg_22;
    wire halted_0;
    wire signal_wire_41;
    wire program_write;
    wire vdd;
    wire signal_wire_42;
    wire [15:0] signal_inst_2;
    wire [15:0] signal_wire_43;
    reg [15:0] word;
    wire [2:0] d$opcode$binary_variant;
    reg [27:0] pin_out_next;
    reg [27:0] signal_reg_23;
    wire [27:0] pin_out_0;
    assign signal_const = 3'b100;
    assign signal_eq = signal_select_759 == signal_const;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            is_opcode$4 <= gnd;
        else
            if (ir_load)
                is_opcode$4 <= signal_eq;
    end
    assign signal_const_1 = 3'b101;
    assign signal_eq_1 = signal_select_759 == signal_const_1;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            is_opcode$5 <= gnd;
        else
            if (ir_load)
                is_opcode$5 <= signal_eq_1;
    end
    assign signal_const_2 = 3'b110;
    assign signal_eq_2 = signal_select_759 == signal_const_2;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
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
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
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
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_1 <= signal_const_3;
        else
            if (signal_and_2)
                signal_reg_1 <= vdd;
    end
    assign signal_and_3 = op_go & pushes;
    assign signal_and_4 = signal_and_3 & signal_select_212;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_2 <= signal_const_3;
        else
            if (signal_and_4)
                signal_reg_2 <= vdd;
    end
    assign signal_and_5 = pulls & signal_select_654;
    assign signal_and_6 = is_opcode$3 & pull_now;
    assign signal_and_7 = signal_and_6 & signal_select_654;
    assign signal_or = signal_and_7 | signal_and_5;
    assign signal_and_8 = op_go & signal_or;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
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
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            irq_0 <= signal_const_3;
        else
            irq_0 <= signal_wire_1;
    end
    assign signal_const_10 = 28'b0000000000000000000000000000;
    assign signal_select_4 = signal_mux_5[27:12];
    assign signal_select_5 = signal_mux_5[11:0];
    assign signal_cat_1 = { signal_select_5,
                            signal_select_4 };
    assign signal_select_6 = signal_mux_4[27:20];
    assign signal_select_7 = signal_mux_4[19:0];
    assign signal_cat_2 = { signal_select_7,
                            signal_select_6 };
    assign signal_select_8 = signal_mux_3[27:24];
    assign signal_select_9 = signal_mux_3[23:0];
    assign signal_cat_3 = { signal_select_9,
                            signal_select_8 };
    assign signal_select_10 = signal_mux_2[27:26];
    assign signal_select_11 = signal_mux_2[25:0];
    assign signal_cat_4 = { signal_select_11,
                            signal_select_10 };
    assign signal_select_12 = signal_cat_7[27:27];
    assign signal_select_13 = signal_cat_7[26:0];
    assign signal_cat_5 = { signal_select_13,
                            signal_select_12 };
    assign signal_const_11 = 11'b00000000000;
    assign signal_cat_6 = { signal_const_11,
                            d$set_value };
    assign signal_const_12 = 12'b000000000000;
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
    assign signal_const_13 = 28'b1111111111111111111111100000;
    assign signal_select_19 = signal_mux_15[27:12];
    assign signal_select_20 = signal_mux_15[11:0];
    assign signal_cat_8 = { signal_select_20,
                            signal_select_19 };
    assign signal_select_21 = signal_mux_14[27:20];
    assign signal_select_22 = signal_mux_14[19:0];
    assign signal_cat_9 = { signal_select_22,
                            signal_select_21 };
    assign signal_select_23 = signal_mux_13[27:24];
    assign signal_select_24 = signal_mux_13[23:0];
    assign signal_cat_10 = { signal_select_24,
                             signal_select_23 };
    assign signal_select_25 = signal_mux_12[27:26];
    assign signal_select_26 = signal_mux_12[25:0];
    assign signal_cat_11 = { signal_select_26,
                             signal_select_25 };
    assign signal_select_27 = signal_cat_16[27:27];
    assign signal_select_28 = signal_cat_16[26:0];
    assign signal_cat_12 = { signal_select_28,
                             signal_select_27 };
    assign signal_const_14 = 16'b0000000000000000;
    assign signal_const_15 = 8'b00000000;
    assign signal_select_29 = signal_mux_9[7:0];
    assign signal_cat_13 = { signal_select_29,
                             signal_const_15 };
    assign signal_const_16 = 4'b0000;
    assign signal_select_30 = signal_mux_8[11:0];
    assign signal_cat_14 = { signal_select_30,
                             signal_const_16 };
    assign signal_const_17 = 2'b00;
    assign signal_select_31 = signal_mux_7[13:0];
    assign signal_cat_15 = { signal_select_31,
                             signal_const_17 };
    assign signal_const_18 = 16'b1111111111111110;
    assign signal_const_19 = 16'b1111111111111111;
    assign signal_select_32 = signal_cat_85[0:0];
    assign signal_mux_7 = signal_select_32 ? signal_const_18 : signal_const_19;
    assign signal_select_33 = signal_cat_85[1:1];
    assign signal_mux_8 = signal_select_33 ? signal_cat_15 : signal_mux_7;
    assign signal_select_34 = signal_cat_85[2:2];
    assign signal_mux_9 = signal_select_34 ? signal_cat_14 : signal_mux_8;
    assign signal_select_35 = signal_cat_85[3:3];
    assign signal_mux_10 = signal_select_35 ? signal_cat_13 : signal_mux_9;
    assign signal_select_36 = signal_cat_85[4:4];
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
    assign signal_select_42 = signal_mux_21[27:12];
    assign signal_select_43 = signal_mux_21[11:0];
    assign signal_cat_17 = { signal_select_43,
                             signal_select_42 };
    assign signal_select_44 = signal_mux_20[27:20];
    assign signal_select_45 = signal_mux_20[19:0];
    assign signal_cat_18 = { signal_select_45,
                             signal_select_44 };
    assign signal_select_46 = signal_mux_19[27:24];
    assign signal_select_47 = signal_mux_19[23:0];
    assign signal_cat_19 = { signal_select_47,
                             signal_select_46 };
    assign signal_select_48 = signal_mux_18[27:26];
    assign signal_select_49 = signal_mux_18[25:0];
    assign signal_cat_20 = { signal_select_49,
                             signal_select_48 };
    assign signal_select_50 = signal_cat_22[27:27];
    assign signal_select_51 = signal_cat_22[26:0];
    assign signal_cat_21 = { signal_select_51,
                             signal_select_50 };
    assign signal_cat_22 = { signal_const_12,
                             mov_value };
    assign signal_select_52 = signal_wire_33[0:0];
    assign signal_mux_18 = signal_select_52 ? signal_cat_21 : signal_cat_22;
    assign signal_select_53 = signal_wire_33[1:1];
    assign signal_mux_19 = signal_select_53 ? signal_cat_20 : signal_mux_18;
    assign signal_select_54 = signal_wire_33[2:2];
    assign signal_mux_20 = signal_select_54 ? signal_cat_19 : signal_mux_19;
    assign signal_select_55 = signal_wire_33[3:3];
    assign signal_mux_21 = signal_select_55 ? signal_cat_18 : signal_mux_20;
    assign signal_select_56 = signal_wire_33[4:4];
    assign signal_mux_22 = signal_select_56 ? signal_cat_17 : signal_mux_21;
    assign signal_and_14 = signal_mux_22 & signal_and_15;
    assign signal_select_57 = signal_mux_31[27:12];
    assign signal_select_58 = signal_mux_31[11:0];
    assign signal_cat_23 = { signal_select_58,
                             signal_select_57 };
    assign signal_select_59 = signal_mux_30[27:20];
    assign signal_select_60 = signal_mux_30[19:0];
    assign signal_cat_24 = { signal_select_60,
                             signal_select_59 };
    assign signal_select_61 = signal_mux_29[27:24];
    assign signal_select_62 = signal_mux_29[23:0];
    assign signal_cat_25 = { signal_select_62,
                             signal_select_61 };
    assign signal_select_63 = signal_mux_28[27:26];
    assign signal_select_64 = signal_mux_28[25:0];
    assign signal_cat_26 = { signal_select_64,
                             signal_select_63 };
    assign signal_select_65 = signal_cat_31[27:27];
    assign signal_select_66 = signal_cat_31[26:0];
    assign signal_cat_27 = { signal_select_66,
                             signal_select_65 };
    assign signal_select_67 = signal_mux_25[7:0];
    assign signal_cat_28 = { signal_select_67,
                             signal_const_15 };
    assign signal_select_68 = signal_mux_24[11:0];
    assign signal_cat_29 = { signal_select_68,
                             signal_const_16 };
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
    assign signal_select_75 = signal_wire_33[0:0];
    assign signal_mux_28 = signal_select_75 ? signal_cat_27 : signal_cat_31;
    assign signal_select_76 = signal_wire_33[1:1];
    assign signal_mux_29 = signal_select_76 ? signal_cat_26 : signal_mux_28;
    assign signal_select_77 = signal_wire_33[2:2];
    assign signal_mux_30 = signal_select_77 ? signal_cat_25 : signal_mux_29;
    assign signal_select_78 = signal_wire_33[3:3];
    assign signal_mux_31 = signal_select_78 ? signal_cat_24 : signal_mux_30;
    assign signal_select_79 = signal_wire_33[4:4];
    assign signal_mux_32 = signal_select_79 ? signal_cat_23 : signal_mux_31;
    assign signal_and_15 = signal_mux_32 & signal_const_13;
    assign signal_not_6 = ~ signal_and_15;
    assign signal_and_16 = pin_out_base & signal_not_6;
    assign signal_or_2 = signal_and_16 | signal_and_14;
    assign signal_eq_6 = d$mov_dest$binary_variant == signal_const_21;
    assign signal_mux_33 = signal_eq_6 ? signal_or_2 : pin_out_base;
    assign signal_select_80 = signal_mux_37[27:12];
    assign signal_select_81 = signal_mux_37[11:0];
    assign signal_cat_32 = { signal_select_81,
                             signal_select_80 };
    assign signal_select_82 = signal_mux_36[27:20];
    assign signal_select_83 = signal_mux_36[19:0];
    assign signal_cat_33 = { signal_select_83,
                             signal_select_82 };
    assign signal_select_84 = signal_mux_35[27:24];
    assign signal_select_85 = signal_mux_35[23:0];
    assign signal_cat_34 = { signal_select_85,
                             signal_select_84 };
    assign signal_select_86 = signal_mux_34[27:26];
    assign signal_select_87 = signal_mux_34[25:0];
    assign signal_cat_35 = { signal_select_87,
                             signal_select_86 };
    assign signal_select_88 = signal_cat_37[27:27];
    assign signal_select_89 = signal_cat_37[26:0];
    assign signal_cat_36 = { signal_select_89,
                             signal_select_88 };
    assign signal_cat_37 = { signal_const_12,
                             out_value };
    assign signal_select_90 = signal_wire_33[0:0];
    assign signal_mux_34 = signal_select_90 ? signal_cat_36 : signal_cat_37;
    assign signal_select_91 = signal_wire_33[1:1];
    assign signal_mux_35 = signal_select_91 ? signal_cat_35 : signal_mux_34;
    assign signal_select_92 = signal_wire_33[2:2];
    assign signal_mux_36 = signal_select_92 ? signal_cat_34 : signal_mux_35;
    assign signal_select_93 = signal_wire_33[3:3];
    assign signal_mux_37 = signal_select_93 ? signal_cat_33 : signal_mux_36;
    assign signal_select_94 = signal_wire_33[4:4];
    assign signal_mux_38 = signal_select_94 ? signal_cat_32 : signal_mux_37;
    assign signal_and_17 = signal_mux_38 & signal_and_18;
    assign signal_select_95 = signal_mux_47[27:12];
    assign signal_select_96 = signal_mux_47[11:0];
    assign signal_cat_38 = { signal_select_96,
                             signal_select_95 };
    assign signal_select_97 = signal_mux_46[27:20];
    assign signal_select_98 = signal_mux_46[19:0];
    assign signal_cat_39 = { signal_select_98,
                             signal_select_97 };
    assign signal_select_99 = signal_mux_45[27:24];
    assign signal_select_100 = signal_mux_45[23:0];
    assign signal_cat_40 = { signal_select_100,
                             signal_select_99 };
    assign signal_select_101 = signal_mux_44[27:26];
    assign signal_select_102 = signal_mux_44[25:0];
    assign signal_cat_41 = { signal_select_102,
                             signal_select_101 };
    assign signal_select_103 = signal_cat_46[27:27];
    assign signal_select_104 = signal_cat_46[26:0];
    assign signal_cat_42 = { signal_select_104,
                             signal_select_103 };
    assign signal_select_105 = signal_mux_41[7:0];
    assign signal_cat_43 = { signal_select_105,
                             signal_const_15 };
    assign signal_select_106 = signal_mux_40[11:0];
    assign signal_cat_44 = { signal_select_106,
                             signal_const_16 };
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
    assign signal_select_113 = signal_wire_33[0:0];
    assign signal_mux_44 = signal_select_113 ? signal_cat_42 : signal_cat_46;
    assign signal_select_114 = signal_wire_33[1:1];
    assign signal_mux_45 = signal_select_114 ? signal_cat_41 : signal_mux_44;
    assign signal_select_115 = signal_wire_33[2:2];
    assign signal_mux_46 = signal_select_115 ? signal_cat_40 : signal_mux_45;
    assign signal_select_116 = signal_wire_33[3:3];
    assign signal_mux_47 = signal_select_116 ? signal_cat_39 : signal_mux_46;
    assign signal_select_117 = signal_wire_33[4:4];
    assign signal_mux_48 = signal_select_117 ? signal_cat_38 : signal_mux_47;
    assign signal_and_18 = signal_mux_48 & signal_const_13;
    assign signal_not_8 = ~ signal_and_18;
    assign signal_and_19 = pin_out_base & signal_not_8;
    assign signal_or_3 = signal_and_19 | signal_and_17;
    assign signal_eq_7 = d$out_dest$binary_variant == signal_const_21;
    assign signal_mux_49 = signal_eq_7 ? signal_or_3 : pin_out_base;
    assign signal_select_118 = signal_mux_53[27:12];
    assign signal_select_119 = signal_mux_53[11:0];
    assign signal_cat_47 = { signal_select_119,
                             signal_select_118 };
    assign signal_select_120 = signal_mux_52[27:20];
    assign signal_select_121 = signal_mux_52[19:0];
    assign signal_cat_48 = { signal_select_121,
                             signal_select_120 };
    assign signal_select_122 = signal_mux_51[27:24];
    assign signal_select_123 = signal_mux_51[23:0];
    assign signal_cat_49 = { signal_select_123,
                             signal_select_122 };
    assign signal_select_124 = signal_mux_50[27:26];
    assign signal_select_125 = signal_mux_50[25:0];
    assign signal_cat_50 = { signal_select_125,
                             signal_select_124 };
    assign signal_select_126 = signal_cat_53[27:27];
    assign signal_select_127 = signal_cat_53[26:0];
    assign signal_cat_51 = { signal_select_127,
                             signal_select_126 };
    assign signal_const_42 = 14'b00000000000000;
    assign signal_cat_52 = { signal_const_42,
                             d$side_set };
    assign signal_cat_53 = { signal_const_12,
                             signal_cat_52 };
    assign signal_select_128 = signal_wire_35[0:0];
    assign signal_mux_50 = signal_select_128 ? signal_cat_51 : signal_cat_53;
    assign signal_select_129 = signal_wire_35[1:1];
    assign signal_mux_51 = signal_select_129 ? signal_cat_50 : signal_mux_50;
    assign signal_select_130 = signal_wire_35[2:2];
    assign signal_mux_52 = signal_select_130 ? signal_cat_49 : signal_mux_51;
    assign signal_select_131 = signal_wire_35[3:3];
    assign signal_mux_53 = signal_select_131 ? signal_cat_48 : signal_mux_52;
    assign signal_select_132 = signal_wire_35[4:4];
    assign signal_mux_54 = signal_select_132 ? signal_cat_47 : signal_mux_53;
    assign signal_and_20 = signal_mux_54 & signal_and_21;
    assign signal_select_133 = signal_mux_63[27:12];
    assign signal_select_134 = signal_mux_63[11:0];
    assign signal_cat_54 = { signal_select_134,
                             signal_select_133 };
    assign signal_select_135 = signal_mux_62[27:20];
    assign signal_select_136 = signal_mux_62[19:0];
    assign signal_cat_55 = { signal_select_136,
                             signal_select_135 };
    assign signal_select_137 = signal_mux_61[27:24];
    assign signal_select_138 = signal_mux_61[23:0];
    assign signal_cat_56 = { signal_select_138,
                             signal_select_137 };
    assign signal_select_139 = signal_mux_60[27:26];
    assign signal_select_140 = signal_mux_60[25:0];
    assign signal_cat_57 = { signal_select_140,
                             signal_select_139 };
    assign signal_select_141 = signal_cat_62[27:27];
    assign signal_select_142 = signal_cat_62[26:0];
    assign signal_cat_58 = { signal_select_142,
                             signal_select_141 };
    assign signal_select_143 = signal_mux_57[7:0];
    assign signal_cat_59 = { signal_select_143,
                             signal_const_15 };
    assign signal_select_144 = signal_mux_56[11:0];
    assign signal_cat_60 = { signal_select_144,
                             signal_const_16 };
    assign signal_select_145 = signal_mux_55[13:0];
    assign signal_cat_61 = { signal_select_145,
                             signal_const_17 };
    assign signal_select_146 = signal_cat_195[0:0];
    assign signal_mux_55 = signal_select_146 ? signal_const_18 : signal_const_19;
    assign signal_select_147 = signal_cat_195[1:1];
    assign signal_mux_56 = signal_select_147 ? signal_cat_61 : signal_mux_55;
    assign signal_select_148 = signal_cat_195[2:2];
    assign signal_mux_57 = signal_select_148 ? signal_cat_60 : signal_mux_56;
    assign signal_select_149 = signal_cat_195[3:3];
    assign signal_mux_58 = signal_select_149 ? signal_cat_59 : signal_mux_57;
    assign signal_select_150 = signal_cat_195[4:4];
    assign signal_mux_59 = signal_select_150 ? signal_const_14 : signal_mux_58;
    assign signal_not_9 = ~ signal_mux_59;
    assign signal_cat_62 = { signal_const_12,
                             signal_not_9 };
    assign signal_select_151 = signal_wire_35[0:0];
    assign signal_mux_60 = signal_select_151 ? signal_cat_58 : signal_cat_62;
    assign signal_select_152 = signal_wire_35[1:1];
    assign signal_mux_61 = signal_select_152 ? signal_cat_57 : signal_mux_60;
    assign signal_select_153 = signal_wire_35[2:2];
    assign signal_mux_62 = signal_select_153 ? signal_cat_56 : signal_mux_61;
    assign signal_select_154 = signal_wire_35[3:3];
    assign signal_mux_63 = signal_select_154 ? signal_cat_55 : signal_mux_62;
    assign signal_select_155 = signal_wire_35[4:4];
    assign signal_mux_64 = signal_select_155 ? signal_cat_54 : signal_mux_63;
    assign signal_and_21 = signal_mux_64 & signal_const_13;
    assign signal_not_10 = ~ signal_and_21;
    assign signal_and_22 = pin_out_0 & signal_not_10;
    assign pin_out_side = signal_and_22 | signal_and_20;
    assign pin_out_base = signal_wire_36 ? pin_out_0 : pin_out_side;
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
    assign signal_not_11 = ~ signal_select_212;
    assign signal_not_12 = ~ signal_select_654;
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
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
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
    assign signal_lt_1 = osr_count_0 < signal_wire_30;
    assign signal_select_156 = sample[27:27];
    assign signal_select_157 = sample[26:26];
    assign signal_select_158 = sample[25:25];
    assign signal_select_159 = sample[24:24];
    assign signal_select_160 = sample[23:23];
    assign signal_select_161 = sample[22:22];
    assign signal_select_162 = sample[21:21];
    assign signal_select_163 = sample[20:20];
    assign signal_select_164 = sample[19:19];
    assign signal_select_165 = sample[18:18];
    assign signal_select_166 = sample[17:17];
    assign signal_select_167 = sample[16:16];
    assign signal_select_168 = sample[15:15];
    assign signal_select_169 = sample[14:14];
    assign signal_select_170 = sample[13:13];
    assign signal_select_171 = sample[12:12];
    assign signal_select_172 = sample[11:11];
    assign signal_select_173 = sample[10:10];
    assign signal_select_174 = sample[9:9];
    assign signal_select_175 = sample[8:8];
    assign signal_select_176 = sample[7:7];
    assign signal_select_177 = sample[6:6];
    assign signal_select_178 = sample[5:5];
    assign signal_select_179 = sample[4:4];
    assign signal_select_180 = sample[3:3];
    assign signal_select_181 = sample[2:2];
    assign signal_select_182 = sample[1:1];
    assign signal_select_183 = sample[0:0];
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_72 <= signal_select_183;
        1:
            signal_mux_72 <= signal_select_182;
        2:
            signal_mux_72 <= signal_select_181;
        3:
            signal_mux_72 <= signal_select_180;
        4:
            signal_mux_72 <= signal_select_179;
        5:
            signal_mux_72 <= signal_select_178;
        6:
            signal_mux_72 <= signal_select_177;
        7:
            signal_mux_72 <= signal_select_176;
        8:
            signal_mux_72 <= signal_select_175;
        9:
            signal_mux_72 <= signal_select_174;
        10:
            signal_mux_72 <= signal_select_173;
        11:
            signal_mux_72 <= signal_select_172;
        12:
            signal_mux_72 <= signal_select_171;
        13:
            signal_mux_72 <= signal_select_170;
        14:
            signal_mux_72 <= signal_select_169;
        15:
            signal_mux_72 <= signal_select_168;
        16:
            signal_mux_72 <= signal_select_167;
        17:
            signal_mux_72 <= signal_select_166;
        18:
            signal_mux_72 <= signal_select_165;
        19:
            signal_mux_72 <= signal_select_164;
        20:
            signal_mux_72 <= signal_select_163;
        21:
            signal_mux_72 <= signal_select_162;
        22:
            signal_mux_72 <= signal_select_161;
        23:
            signal_mux_72 <= signal_select_160;
        24:
            signal_mux_72 <= signal_select_159;
        25:
            signal_mux_72 <= signal_select_158;
        26:
            signal_mux_72 <= signal_select_157;
        default:
            signal_mux_72 <= signal_select_156;
        endcase
    end
    assign signal_not_15 = ~ signal_mux_72;
    assign signal_select_184 = sample[27:27];
    assign signal_select_185 = sample[26:26];
    assign signal_select_186 = sample[25:25];
    assign signal_select_187 = sample[24:24];
    assign signal_select_188 = sample[23:23];
    assign signal_select_189 = sample[22:22];
    assign signal_select_190 = sample[21:21];
    assign signal_select_191 = sample[20:20];
    assign signal_select_192 = sample[19:19];
    assign signal_select_193 = sample[18:18];
    assign signal_select_194 = sample[17:17];
    assign signal_select_195 = sample[16:16];
    assign signal_select_196 = sample[15:15];
    assign signal_select_197 = sample[14:14];
    assign signal_select_198 = sample[13:13];
    assign signal_select_199 = sample[12:12];
    assign signal_select_200 = sample[11:11];
    assign signal_select_201 = sample[10:10];
    assign signal_select_202 = sample[9:9];
    assign signal_select_203 = sample[8:8];
    assign signal_select_204 = sample[7:7];
    assign signal_select_205 = sample[6:6];
    assign signal_select_206 = sample[5:5];
    assign signal_select_207 = sample[4:4];
    assign signal_select_208 = sample[3:3];
    assign signal_select_209 = sample[2:2];
    assign signal_select_210 = sample[1:1];
    assign signal_select_211 = sample[0:0];
    assign signal_wire_8 = config$jmp_pin;
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_73 <= signal_select_211;
        1:
            signal_mux_73 <= signal_select_210;
        2:
            signal_mux_73 <= signal_select_209;
        3:
            signal_mux_73 <= signal_select_208;
        4:
            signal_mux_73 <= signal_select_207;
        5:
            signal_mux_73 <= signal_select_206;
        6:
            signal_mux_73 <= signal_select_205;
        7:
            signal_mux_73 <= signal_select_204;
        8:
            signal_mux_73 <= signal_select_203;
        9:
            signal_mux_73 <= signal_select_202;
        10:
            signal_mux_73 <= signal_select_201;
        11:
            signal_mux_73 <= signal_select_200;
        12:
            signal_mux_73 <= signal_select_199;
        13:
            signal_mux_73 <= signal_select_198;
        14:
            signal_mux_73 <= signal_select_197;
        15:
            signal_mux_73 <= signal_select_196;
        16:
            signal_mux_73 <= signal_select_195;
        17:
            signal_mux_73 <= signal_select_194;
        18:
            signal_mux_73 <= signal_select_193;
        19:
            signal_mux_73 <= signal_select_192;
        20:
            signal_mux_73 <= signal_select_191;
        21:
            signal_mux_73 <= signal_select_190;
        22:
            signal_mux_73 <= signal_select_189;
        23:
            signal_mux_73 <= signal_select_188;
        24:
            signal_mux_73 <= signal_select_187;
        25:
            signal_mux_73 <= signal_select_186;
        26:
            signal_mux_73 <= signal_select_185;
        default:
            signal_mux_73 <= signal_select_184;
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
            jmp_taken <= signal_select_654;
        10:
            jmp_taken <= signal_not_11;
        default:
            jmp_taken <= signal_select_212;
        endcase
    end
    assign jmp_target_or_next = jmp_taken ? d$jmp_target : pc_next;
    assign signal_mux_74 = advance ? pc_next : pc_0;
    assign signal_mux_75 = jmp_go ? jmp_target_or_next : signal_mux_74;
    assign pc_value_next = start_0 ? signal_const_54 : signal_mux_75;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
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
    assign signal_mux_78 = signal_wire_40 ? signal_const_54 : signal_mux_77;
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
    assign signal_and_27 = signal_select_701 & signal_const_75;
    assign signal_and_28 = signal_select_701 & signal_const_75;
    assign signal_const_77 = 5'b01111;
    assign signal_and_29 = signal_select_701 & signal_const_77;
    always @* begin
        case (signal_wire_34)
        0:
            d$delay <= signal_select_701;
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
    assign signal_or_4 = jmp_go | signal_wire_40;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            refill <= signal_const_3;
        else
            refill <= signal_or_4;
    end
    assign signal_not_22 = ~ signal_select_654;
    assign signal_wire_9 = rx_pop;
    assign signal_mux_83 = is_opcode$2 ? isr_shifted : isr_0;
    assign signal_wire_10 = signal_mux_83;
    assign signal_not_23 = ~ signal_select_212;
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
        ( .clock(signal_wire_42),
          .clear(signal_wire_39),
          .push$valid(signal_wire_11),
          .push$value(signal_wire_10),
          .pop(signal_wire_9),
          .flush(flush_0),
          .head(signal_inst[15:0]),
          .level(signal_inst[19:16]),
          .empty(signal_inst[20:20]),
          .full(signal_inst[21:21]) );
    assign signal_select_212 = signal_inst[21:21];
    assign signal_not_24 = ~ signal_select_212;
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
    assign signal_select_213 = mov_value24[23:23];
    assign signal_select_214 = mov_value24[22:22];
    assign signal_select_215 = mov_value24[21:21];
    assign signal_select_216 = mov_value24[20:20];
    assign signal_select_217 = mov_value24[19:19];
    assign signal_select_218 = mov_value24[18:18];
    assign signal_select_219 = mov_value24[17:17];
    assign signal_select_220 = mov_value24[16:16];
    assign signal_select_221 = mov_value24[15:15];
    assign signal_select_222 = mov_value24[14:14];
    assign signal_select_223 = mov_value24[13:13];
    assign signal_select_224 = mov_value24[12:12];
    assign signal_select_225 = mov_value24[11:11];
    assign signal_select_226 = mov_value24[10:10];
    assign signal_select_227 = mov_value24[9:9];
    assign signal_select_228 = mov_value24[8:8];
    assign signal_select_229 = mov_value24[7:7];
    assign signal_select_230 = mov_value24[6:6];
    assign signal_select_231 = mov_value24[5:5];
    assign signal_select_232 = mov_value24[4:4];
    assign signal_select_233 = mov_value24[3:3];
    assign signal_select_234 = mov_value24[2:2];
    assign signal_select_235 = mov_value24[1:1];
    assign signal_select_236 = mov_value24[0:0];
    assign signal_cat_64 = { signal_select_236,
                             signal_select_235,
                             signal_select_234,
                             signal_select_233,
                             signal_select_232,
                             signal_select_231,
                             signal_select_230,
                             signal_select_229,
                             signal_select_228,
                             signal_select_227,
                             signal_select_226,
                             signal_select_225,
                             signal_select_224,
                             signal_select_223,
                             signal_select_222,
                             signal_select_221,
                             signal_select_220,
                             signal_select_219,
                             signal_select_218,
                             signal_select_217,
                             signal_select_216,
                             signal_select_215,
                             signal_select_214,
                             signal_select_213 };
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
    assign signal_wire_12 = config$period_fraction;
    assign signal_cat_66 = { gnd,
                             signal_wire_12 };
    assign signal_eq_24 = d$alu_dest$binary_variant == signal_const_84;
    assign signal_mux_89 = signal_eq_24 ? signal_const_14 : t_fraction_0;
    assign signal_eq_25 = d$mov_dest$binary_variant == signal_const_85;
    assign signal_mux_90 = signal_eq_25 ? signal_const_14 : t_fraction_0;
    assign signal_eq_26 = d$out_dest$binary_variant == signal_const_85;
    assign signal_mux_91 = signal_eq_26 ? signal_const_14 : t_fraction_0;
    assign signal_select_237 = fraction_sum[15:0];
    assign signal_mux_92 = advances_deadline ? signal_select_237 : t_fraction_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_fraction_next <= t_fraction_0;
        1:
            t_fraction_next <= signal_mux_92;
        2:
            t_fraction_next <= t_fraction_0;
        3:
            t_fraction_next <= signal_mux_91;
        4:
            t_fraction_next <= signal_mux_90;
        5:
            t_fraction_next <= t_fraction_0;
        6:
            t_fraction_next <= signal_mux_89;
        default:
            t_fraction_next <= t_fraction_0;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_6 <= signal_const_14;
        else
            if (go)
                signal_reg_6 <= t_fraction_next;
    end
    assign t_fraction_0 = signal_reg_6;
    assign signal_cat_67 = { gnd,
                             t_fraction_0 };
    assign fraction_sum = signal_cat_67 + signal_cat_66;
    assign signal_select_238 = fraction_sum[16:16];
    assign signal_const_95 = 23'b00000000000000000000000;
    assign signal_cat_68 = { signal_const_95,
                             signal_select_238 };
    assign signal_cat_69 = { signal_const_15,
                             p_0 };
    assign signal_add_4 = t_0 + signal_cat_69;
    assign t_advanced = signal_add_4 + signal_cat_68;
    assign signal_const_97 = 2'b10;
    assign signal_eq_27 = d$wait_source$binary_variant == signal_const_97;
    assign signal_and_34 = is_opcode$1 & signal_eq_27;
    assign releases_deadline = signal_and_34 & wait_ready;
    assign advances_deadline = releases_deadline & d$wait_polarity;
    assign signal_mux_93 = advances_deadline ? t_advanced : t_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_next <= t_0;
        1:
            t_next <= signal_mux_93;
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
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_7 <= signal_const_4;
        else
            if (go)
                signal_reg_7 <= t_next;
    end
    assign t_0 = signal_reg_7;
    assign signal_sub_4 = now_0 - t_0;
    assign signal_select_239 = signal_sub_4[23:23];
    assign deadline_ready = ~ signal_select_239;
    assign signal_eq_28 = wait_pin_cur == d$wait_polarity;
    assign signal_select_240 = pins_sampled[27:27];
    assign signal_select_241 = pins_sampled[26:26];
    assign signal_select_242 = pins_sampled[25:25];
    assign signal_select_243 = pins_sampled[24:24];
    assign signal_select_244 = pins_sampled[23:23];
    assign signal_select_245 = pins_sampled[22:22];
    assign signal_select_246 = pins_sampled[21:21];
    assign signal_select_247 = pins_sampled[20:20];
    assign signal_select_248 = pins_sampled[19:19];
    assign signal_select_249 = pins_sampled[18:18];
    assign signal_select_250 = pins_sampled[17:17];
    assign signal_select_251 = pins_sampled[16:16];
    assign signal_select_252 = pins_sampled[15:15];
    assign signal_select_253 = pins_sampled[14:14];
    assign signal_select_254 = pins_sampled[13:13];
    assign signal_select_255 = pins_sampled[12:12];
    assign signal_select_256 = pins_sampled[11:11];
    assign signal_select_257 = pins_sampled[10:10];
    assign signal_select_258 = pins_sampled[9:9];
    assign signal_select_259 = pins_sampled[8:8];
    assign signal_select_260 = pins_sampled[7:7];
    assign signal_select_261 = pins_sampled[6:6];
    assign signal_select_262 = pins_sampled[5:5];
    assign signal_select_263 = pins_sampled[4:4];
    assign signal_select_264 = pins_sampled[3:3];
    assign signal_select_265 = pins_sampled[2:2];
    assign signal_select_266 = pins_sampled[1:1];
    assign signal_select_267 = pins_sampled[0:0];
    always @* begin
        case (d$wait_index)
        0:
            wait_pin_prev <= signal_select_267;
        1:
            wait_pin_prev <= signal_select_266;
        2:
            wait_pin_prev <= signal_select_265;
        3:
            wait_pin_prev <= signal_select_264;
        4:
            wait_pin_prev <= signal_select_263;
        5:
            wait_pin_prev <= signal_select_262;
        6:
            wait_pin_prev <= signal_select_261;
        7:
            wait_pin_prev <= signal_select_260;
        8:
            wait_pin_prev <= signal_select_259;
        9:
            wait_pin_prev <= signal_select_258;
        10:
            wait_pin_prev <= signal_select_257;
        11:
            wait_pin_prev <= signal_select_256;
        12:
            wait_pin_prev <= signal_select_255;
        13:
            wait_pin_prev <= signal_select_254;
        14:
            wait_pin_prev <= signal_select_253;
        15:
            wait_pin_prev <= signal_select_252;
        16:
            wait_pin_prev <= signal_select_251;
        17:
            wait_pin_prev <= signal_select_250;
        18:
            wait_pin_prev <= signal_select_249;
        19:
            wait_pin_prev <= signal_select_248;
        20:
            wait_pin_prev <= signal_select_247;
        21:
            wait_pin_prev <= signal_select_246;
        22:
            wait_pin_prev <= signal_select_245;
        23:
            wait_pin_prev <= signal_select_244;
        24:
            wait_pin_prev <= signal_select_243;
        25:
            wait_pin_prev <= signal_select_242;
        26:
            wait_pin_prev <= signal_select_241;
        default:
            wait_pin_prev <= signal_select_240;
        endcase
    end
    assign signal_eq_29 = wait_pin_cur == wait_pin_prev;
    assign signal_not_26 = ~ signal_eq_29;
    assign signal_and_35 = signal_not_26 & signal_eq_28;
    assign d$wait_polarity = word[7:7];
    assign signal_select_268 = sample[27:27];
    assign signal_select_269 = sample[26:26];
    assign signal_select_270 = sample[25:25];
    assign signal_select_271 = sample[24:24];
    assign signal_select_272 = sample[23:23];
    assign signal_select_273 = sample[22:22];
    assign signal_select_274 = sample[21:21];
    assign signal_select_275 = sample[20:20];
    assign signal_select_276 = sample[19:19];
    assign signal_select_277 = sample[18:18];
    assign signal_select_278 = sample[17:17];
    assign signal_select_279 = sample[16:16];
    assign signal_select_280 = sample[15:15];
    assign signal_select_281 = sample[14:14];
    assign signal_select_282 = sample[13:13];
    assign signal_select_283 = sample[12:12];
    assign signal_select_284 = sample[11:11];
    assign signal_select_285 = sample[10:10];
    assign signal_select_286 = sample[9:9];
    assign signal_select_287 = sample[8:8];
    assign signal_select_288 = sample[7:7];
    assign signal_select_289 = sample[6:6];
    assign signal_select_290 = sample[5:5];
    assign signal_select_291 = sample[4:4];
    assign signal_select_292 = sample[3:3];
    assign signal_select_293 = sample[2:2];
    assign signal_select_294 = sample[1:1];
    assign signal_select_295 = signal_wire_37[0:0];
    assign signal_select_296 = signal_wire_37[1:1];
    assign signal_select_297 = signal_wire_37[2:2];
    assign signal_select_298 = signal_wire_37[3:3];
    assign signal_select_299 = signal_wire_37[4:4];
    assign signal_select_300 = pin_out_0[5:5];
    assign signal_select_301 = pin_out_0[6:6];
    assign signal_select_302 = pin_out_0[7:7];
    assign signal_select_303 = pin_out_0[8:8];
    assign signal_select_304 = pin_out_0[9:9];
    assign signal_select_305 = pin_out_0[10:10];
    assign signal_select_306 = pin_out_0[11:11];
    assign signal_select_307 = pin_out_0[12:12];
    assign signal_select_308 = signal_wire_37[12:12];
    assign signal_select_309 = pin_dir_0[12:12];
    assign signal_mux_94 = signal_select_309 ? signal_select_307 : signal_select_308;
    assign signal_select_310 = pin_out_0[13:13];
    assign signal_select_311 = signal_wire_37[13:13];
    assign signal_select_312 = pin_dir_0[13:13];
    assign signal_mux_95 = signal_select_312 ? signal_select_310 : signal_select_311;
    assign signal_select_313 = pin_out_0[14:14];
    assign signal_select_314 = signal_wire_37[14:14];
    assign signal_select_315 = pin_dir_0[14:14];
    assign signal_mux_96 = signal_select_315 ? signal_select_313 : signal_select_314;
    assign signal_select_316 = pin_out_0[15:15];
    assign signal_select_317 = signal_wire_37[15:15];
    assign signal_select_318 = pin_dir_0[15:15];
    assign signal_mux_97 = signal_select_318 ? signal_select_316 : signal_select_317;
    assign signal_select_319 = pin_out_0[16:16];
    assign signal_select_320 = signal_wire_37[16:16];
    assign signal_select_321 = pin_dir_0[16:16];
    assign signal_mux_98 = signal_select_321 ? signal_select_319 : signal_select_320;
    assign signal_select_322 = pin_out_0[17:17];
    assign signal_select_323 = signal_wire_37[17:17];
    assign signal_select_324 = pin_dir_0[17:17];
    assign signal_mux_99 = signal_select_324 ? signal_select_322 : signal_select_323;
    assign signal_select_325 = pin_out_0[18:18];
    assign signal_select_326 = signal_wire_37[18:18];
    assign signal_select_327 = pin_dir_0[18:18];
    assign signal_mux_100 = signal_select_327 ? signal_select_325 : signal_select_326;
    assign signal_select_328 = pin_out_0[19:19];
    assign signal_select_329 = signal_wire_37[19:19];
    assign signal_select_330 = signal_mux_104[27:12];
    assign signal_select_331 = signal_mux_104[11:0];
    assign signal_cat_70 = { signal_select_331,
                             signal_select_330 };
    assign signal_select_332 = signal_mux_103[27:20];
    assign signal_select_333 = signal_mux_103[19:0];
    assign signal_cat_71 = { signal_select_333,
                             signal_select_332 };
    assign signal_select_334 = signal_mux_102[27:24];
    assign signal_select_335 = signal_mux_102[23:0];
    assign signal_cat_72 = { signal_select_335,
                             signal_select_334 };
    assign signal_select_336 = signal_mux_101[27:26];
    assign signal_select_337 = signal_mux_101[25:0];
    assign signal_cat_73 = { signal_select_337,
                             signal_select_336 };
    assign signal_select_338 = signal_cat_76[27:27];
    assign signal_select_339 = signal_cat_76[26:0];
    assign signal_cat_74 = { signal_select_339,
                             signal_select_338 };
    assign signal_cat_75 = { signal_const_11,
                             d$set_value };
    assign signal_cat_76 = { signal_const_12,
                             signal_cat_75 };
    assign signal_select_340 = signal_wire_14[0:0];
    assign signal_mux_101 = signal_select_340 ? signal_cat_74 : signal_cat_76;
    assign signal_select_341 = signal_wire_14[1:1];
    assign signal_mux_102 = signal_select_341 ? signal_cat_73 : signal_mux_101;
    assign signal_select_342 = signal_wire_14[2:2];
    assign signal_mux_103 = signal_select_342 ? signal_cat_72 : signal_mux_102;
    assign signal_select_343 = signal_wire_14[3:3];
    assign signal_mux_104 = signal_select_343 ? signal_cat_71 : signal_mux_103;
    assign signal_select_344 = signal_wire_14[4:4];
    assign signal_mux_105 = signal_select_344 ? signal_cat_70 : signal_mux_104;
    assign signal_and_36 = signal_mux_105 & signal_and_37;
    assign signal_const_101 = 28'b0000000011111111000000000000;
    assign signal_select_345 = signal_mux_114[27:12];
    assign signal_select_346 = signal_mux_114[11:0];
    assign signal_cat_77 = { signal_select_346,
                             signal_select_345 };
    assign signal_select_347 = signal_mux_113[27:20];
    assign signal_select_348 = signal_mux_113[19:0];
    assign signal_cat_78 = { signal_select_348,
                             signal_select_347 };
    assign signal_select_349 = signal_mux_112[27:24];
    assign signal_select_350 = signal_mux_112[23:0];
    assign signal_cat_79 = { signal_select_350,
                             signal_select_349 };
    assign signal_select_351 = signal_mux_111[27:26];
    assign signal_select_352 = signal_mux_111[25:0];
    assign signal_cat_80 = { signal_select_352,
                             signal_select_351 };
    assign signal_select_353 = signal_cat_86[27:27];
    assign signal_select_354 = signal_cat_86[26:0];
    assign signal_cat_81 = { signal_select_354,
                             signal_select_353 };
    assign signal_select_355 = signal_mux_108[7:0];
    assign signal_cat_82 = { signal_select_355,
                             signal_const_15 };
    assign signal_select_356 = signal_mux_107[11:0];
    assign signal_cat_83 = { signal_select_356,
                             signal_const_16 };
    assign signal_select_357 = signal_mux_106[13:0];
    assign signal_cat_84 = { signal_select_357,
                             signal_const_17 };
    assign signal_select_358 = signal_cat_85[0:0];
    assign signal_mux_106 = signal_select_358 ? signal_const_18 : signal_const_19;
    assign signal_select_359 = signal_cat_85[1:1];
    assign signal_mux_107 = signal_select_359 ? signal_cat_84 : signal_mux_106;
    assign signal_select_360 = signal_cat_85[2:2];
    assign signal_mux_108 = signal_select_360 ? signal_cat_83 : signal_mux_107;
    assign signal_select_361 = signal_cat_85[3:3];
    assign signal_mux_109 = signal_select_361 ? signal_cat_82 : signal_mux_108;
    assign signal_wire_13 = config$set_count;
    assign signal_cat_85 = { signal_const_17,
                             signal_wire_13 };
    assign signal_select_362 = signal_cat_85[4:4];
    assign signal_mux_110 = signal_select_362 ? signal_const_14 : signal_mux_109;
    assign signal_not_27 = ~ signal_mux_110;
    assign signal_cat_86 = { signal_const_12,
                             signal_not_27 };
    assign signal_select_363 = signal_wire_14[0:0];
    assign signal_mux_111 = signal_select_363 ? signal_cat_81 : signal_cat_86;
    assign signal_select_364 = signal_wire_14[1:1];
    assign signal_mux_112 = signal_select_364 ? signal_cat_80 : signal_mux_111;
    assign signal_select_365 = signal_wire_14[2:2];
    assign signal_mux_113 = signal_select_365 ? signal_cat_79 : signal_mux_112;
    assign signal_select_366 = signal_wire_14[3:3];
    assign signal_mux_114 = signal_select_366 ? signal_cat_78 : signal_mux_113;
    assign signal_wire_14 = config$set_base;
    assign signal_select_367 = signal_wire_14[4:4];
    assign signal_mux_115 = signal_select_367 ? signal_cat_77 : signal_mux_114;
    assign signal_and_37 = signal_mux_115 & signal_const_101;
    assign signal_not_28 = ~ signal_and_37;
    assign signal_and_38 = pin_dir_base & signal_not_28;
    assign signal_or_5 = signal_and_38 | signal_and_36;
    assign signal_eq_30 = d$set_dest$binary_variant == signal_const_81;
    assign signal_mux_116 = signal_eq_30 ? signal_or_5 : pin_dir_base;
    assign signal_select_368 = signal_mux_120[27:12];
    assign signal_select_369 = signal_mux_120[11:0];
    assign signal_cat_87 = { signal_select_369,
                             signal_select_368 };
    assign signal_select_370 = signal_mux_119[27:20];
    assign signal_select_371 = signal_mux_119[19:0];
    assign signal_cat_88 = { signal_select_371,
                             signal_select_370 };
    assign signal_select_372 = signal_mux_118[27:24];
    assign signal_select_373 = signal_mux_118[23:0];
    assign signal_cat_89 = { signal_select_373,
                             signal_select_372 };
    assign signal_select_374 = signal_mux_117[27:26];
    assign signal_select_375 = signal_mux_117[25:0];
    assign signal_cat_90 = { signal_select_375,
                             signal_select_374 };
    assign signal_select_376 = signal_cat_92[27:27];
    assign signal_select_377 = signal_cat_92[26:0];
    assign signal_cat_91 = { signal_select_377,
                             signal_select_376 };
    assign signal_cat_92 = { signal_const_12,
                             mov_value };
    assign signal_select_378 = signal_wire_33[0:0];
    assign signal_mux_117 = signal_select_378 ? signal_cat_91 : signal_cat_92;
    assign signal_select_379 = signal_wire_33[1:1];
    assign signal_mux_118 = signal_select_379 ? signal_cat_90 : signal_mux_117;
    assign signal_select_380 = signal_wire_33[2:2];
    assign signal_mux_119 = signal_select_380 ? signal_cat_89 : signal_mux_118;
    assign signal_select_381 = signal_wire_33[3:3];
    assign signal_mux_120 = signal_select_381 ? signal_cat_88 : signal_mux_119;
    assign signal_select_382 = signal_wire_33[4:4];
    assign signal_mux_121 = signal_select_382 ? signal_cat_87 : signal_mux_120;
    assign signal_and_39 = signal_mux_121 & signal_and_40;
    assign signal_select_383 = signal_mux_130[27:12];
    assign signal_select_384 = signal_mux_130[11:0];
    assign signal_cat_93 = { signal_select_384,
                             signal_select_383 };
    assign signal_select_385 = signal_mux_129[27:20];
    assign signal_select_386 = signal_mux_129[19:0];
    assign signal_cat_94 = { signal_select_386,
                             signal_select_385 };
    assign signal_select_387 = signal_mux_128[27:24];
    assign signal_select_388 = signal_mux_128[23:0];
    assign signal_cat_95 = { signal_select_388,
                             signal_select_387 };
    assign signal_select_389 = signal_mux_127[27:26];
    assign signal_select_390 = signal_mux_127[25:0];
    assign signal_cat_96 = { signal_select_390,
                             signal_select_389 };
    assign signal_select_391 = signal_cat_101[27:27];
    assign signal_select_392 = signal_cat_101[26:0];
    assign signal_cat_97 = { signal_select_392,
                             signal_select_391 };
    assign signal_select_393 = signal_mux_124[7:0];
    assign signal_cat_98 = { signal_select_393,
                             signal_const_15 };
    assign signal_select_394 = signal_mux_123[11:0];
    assign signal_cat_99 = { signal_select_394,
                             signal_const_16 };
    assign signal_select_395 = signal_mux_122[13:0];
    assign signal_cat_100 = { signal_select_395,
                              signal_const_17 };
    assign signal_select_396 = signal_wire_15[0:0];
    assign signal_mux_122 = signal_select_396 ? signal_const_18 : signal_const_19;
    assign signal_select_397 = signal_wire_15[1:1];
    assign signal_mux_123 = signal_select_397 ? signal_cat_100 : signal_mux_122;
    assign signal_select_398 = signal_wire_15[2:2];
    assign signal_mux_124 = signal_select_398 ? signal_cat_99 : signal_mux_123;
    assign signal_select_399 = signal_wire_15[3:3];
    assign signal_mux_125 = signal_select_399 ? signal_cat_98 : signal_mux_124;
    assign signal_wire_15 = config$out_count;
    assign signal_select_400 = signal_wire_15[4:4];
    assign signal_mux_126 = signal_select_400 ? signal_const_14 : signal_mux_125;
    assign signal_not_29 = ~ signal_mux_126;
    assign signal_cat_101 = { signal_const_12,
                              signal_not_29 };
    assign signal_select_401 = signal_wire_33[0:0];
    assign signal_mux_127 = signal_select_401 ? signal_cat_97 : signal_cat_101;
    assign signal_select_402 = signal_wire_33[1:1];
    assign signal_mux_128 = signal_select_402 ? signal_cat_96 : signal_mux_127;
    assign signal_select_403 = signal_wire_33[2:2];
    assign signal_mux_129 = signal_select_403 ? signal_cat_95 : signal_mux_128;
    assign signal_select_404 = signal_wire_33[3:3];
    assign signal_mux_130 = signal_select_404 ? signal_cat_94 : signal_mux_129;
    assign signal_select_405 = signal_wire_33[4:4];
    assign signal_mux_131 = signal_select_405 ? signal_cat_93 : signal_mux_130;
    assign signal_and_40 = signal_mux_131 & signal_const_101;
    assign signal_not_30 = ~ signal_and_40;
    assign signal_and_41 = pin_dir_base & signal_not_30;
    assign signal_or_6 = signal_and_41 | signal_and_39;
    assign signal_eq_31 = d$mov_dest$binary_variant == signal_const_81;
    assign signal_mux_132 = signal_eq_31 ? signal_or_6 : pin_dir_base;
    assign signal_select_406 = signal_mux_240[27:12];
    assign signal_select_407 = signal_mux_240[11:0];
    assign signal_cat_102 = { signal_select_407,
                              signal_select_406 };
    assign signal_select_408 = signal_mux_239[27:20];
    assign signal_select_409 = signal_mux_239[19:0];
    assign signal_cat_103 = { signal_select_409,
                              signal_select_408 };
    assign signal_select_410 = signal_mux_238[27:24];
    assign signal_select_411 = signal_mux_238[23:0];
    assign signal_cat_104 = { signal_select_411,
                              signal_select_410 };
    assign signal_select_412 = signal_mux_237[27:26];
    assign signal_select_413 = signal_mux_237[25:0];
    assign signal_cat_105 = { signal_select_413,
                              signal_select_412 };
    assign signal_select_414 = signal_cat_169[27:27];
    assign signal_select_415 = signal_cat_169[26:0];
    assign signal_cat_106 = { signal_select_415,
                              signal_select_414 };
    assign signal_and_42 = osr_before & mask;
    assign signal_select_416 = signal_mux_234[15:8];
    assign signal_cat_107 = { signal_const_15,
                              signal_select_416 };
    assign signal_select_417 = signal_mux_233[15:4];
    assign signal_cat_108 = { signal_const_16,
                              signal_select_417 };
    assign signal_select_418 = signal_mux_232[15:2];
    assign signal_cat_109 = { signal_const_17,
                              signal_select_418 };
    assign signal_select_419 = osr_before[15:1];
    assign signal_cat_110 = { signal_const_3,
                              signal_select_419 };
    assign signal_select_420 = signal_inst_1[15:0];
    assign signal_not_31 = ~ signal_select_654;
    assign signal_and_43 = pulls & signal_not_31;
    assign signal_mux_133 = signal_and_43 ? signal_select_420 : osr_0;
    assign signal_select_421 = signal_select_635[15:15];
    assign signal_select_422 = signal_select_635[14:14];
    assign signal_select_423 = signal_select_635[13:13];
    assign signal_select_424 = signal_select_635[12:12];
    assign signal_select_425 = signal_select_635[11:11];
    assign signal_select_426 = signal_select_635[10:10];
    assign signal_select_427 = signal_select_635[9:9];
    assign signal_select_428 = signal_select_635[8:8];
    assign signal_select_429 = signal_select_635[7:7];
    assign signal_select_430 = signal_select_635[6:6];
    assign signal_select_431 = signal_select_635[5:5];
    assign signal_select_432 = signal_select_635[4:4];
    assign signal_select_433 = signal_select_635[3:3];
    assign signal_select_434 = signal_select_635[2:2];
    assign signal_select_435 = signal_select_635[1:1];
    assign signal_select_436 = signal_select_635[0:0];
    assign signal_cat_111 = { signal_select_436,
                              signal_select_435,
                              signal_select_434,
                              signal_select_433,
                              signal_select_432,
                              signal_select_431,
                              signal_select_430,
                              signal_select_429,
                              signal_select_428,
                              signal_select_427,
                              signal_select_426,
                              signal_select_425,
                              signal_select_424,
                              signal_select_423,
                              signal_select_422,
                              signal_select_421 };
    assign signal_not_32 = ~ signal_select_635;
    assign signal_cat_112 = { signal_const_15,
                              osr_0 };
    assign signal_cat_113 = { signal_const_15,
                              isr_0 };
    assign signal_cat_114 = { signal_const_15,
                              y_0 };
    assign signal_xor_1 = x_0 ^ alu_operand;
    assign signal_sub_5 = x_0 - alu_operand;
    assign signal_eq_32 = d$sys_op$binary_variant == signal_const_81;
    assign signal_and_44 = is_opcode$7 & signal_eq_32;
    assign signal_mux_134 = signal_and_44 ? signal_const_14 : isr_0;
    assign signal_eq_33 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_135 = signal_eq_33 ? mov_value : isr_0;
    assign signal_eq_34 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_136 = signal_eq_34 ? out_value : isr_0;
    assign signal_select_437 = signal_mux_139[7:0];
    assign signal_cat_115 = { signal_select_437,
                              signal_const_15 };
    assign signal_select_438 = signal_mux_138[11:0];
    assign signal_cat_116 = { signal_select_438,
                              signal_const_16 };
    assign signal_select_439 = signal_mux_137[13:0];
    assign signal_cat_117 = { signal_select_439,
                              signal_const_17 };
    assign signal_select_440 = in_value[14:0];
    assign signal_cat_118 = { signal_select_440,
                              signal_const_3 };
    assign signal_select_441 = shift_back[0:0];
    assign signal_mux_137 = signal_select_441 ? signal_cat_118 : in_value;
    assign signal_select_442 = shift_back[1:1];
    assign signal_mux_138 = signal_select_442 ? signal_cat_117 : signal_mux_137;
    assign signal_select_443 = shift_back[2:2];
    assign signal_mux_139 = signal_select_443 ? signal_cat_116 : signal_mux_138;
    assign signal_select_444 = shift_back[3:3];
    assign signal_mux_140 = signal_select_444 ? signal_cat_115 : signal_mux_139;
    assign signal_select_445 = shift_back[4:4];
    assign signal_mux_141 = signal_select_445 ? signal_const_14 : signal_mux_140;
    assign signal_select_446 = signal_mux_144[15:8];
    assign signal_cat_119 = { signal_const_15,
                              signal_select_446 };
    assign signal_select_447 = signal_mux_143[15:4];
    assign signal_cat_120 = { signal_const_16,
                              signal_select_447 };
    assign signal_select_448 = signal_mux_142[15:2];
    assign signal_cat_121 = { signal_const_17,
                              signal_select_448 };
    assign signal_select_449 = isr_0[15:1];
    assign signal_cat_122 = { signal_const_3,
                              signal_select_449 };
    assign signal_select_450 = d$shift_count[0:0];
    assign signal_mux_142 = signal_select_450 ? signal_cat_122 : isr_0;
    assign signal_select_451 = d$shift_count[1:1];
    assign signal_mux_143 = signal_select_451 ? signal_cat_121 : signal_mux_142;
    assign signal_select_452 = d$shift_count[2:2];
    assign signal_mux_144 = signal_select_452 ? signal_cat_120 : signal_mux_143;
    assign signal_select_453 = d$shift_count[3:3];
    assign signal_mux_145 = signal_select_453 ? signal_cat_119 : signal_mux_144;
    assign signal_select_454 = d$shift_count[4:4];
    assign signal_mux_146 = signal_select_454 ? signal_const_14 : signal_mux_145;
    assign signal_or_7 = signal_mux_146 | signal_mux_141;
    assign signal_select_455 = signal_mux_149[7:0];
    assign signal_cat_123 = { signal_select_455,
                              signal_const_15 };
    assign signal_select_456 = signal_mux_148[11:0];
    assign signal_cat_124 = { signal_select_456,
                              signal_const_16 };
    assign signal_select_457 = signal_mux_147[13:0];
    assign signal_cat_125 = { signal_select_457,
                              signal_const_17 };
    assign signal_select_458 = d$shift_count[0:0];
    assign signal_mux_147 = signal_select_458 ? signal_const_18 : signal_const_19;
    assign signal_select_459 = d$shift_count[1:1];
    assign signal_mux_148 = signal_select_459 ? signal_cat_125 : signal_mux_147;
    assign signal_select_460 = d$shift_count[2:2];
    assign signal_mux_149 = signal_select_460 ? signal_cat_124 : signal_mux_148;
    assign signal_select_461 = d$shift_count[3:3];
    assign signal_mux_150 = signal_select_461 ? signal_cat_123 : signal_mux_149;
    assign signal_select_462 = d$shift_count[4:4];
    assign signal_mux_151 = signal_select_462 ? signal_const_14 : signal_mux_150;
    assign mask = ~ signal_mux_151;
    assign signal_wire_16 = config$capture_rising;
    assign signal_select_463 = sample[27:27];
    assign signal_select_464 = sample[26:26];
    assign signal_select_465 = sample[25:25];
    assign signal_select_466 = sample[24:24];
    assign signal_select_467 = sample[23:23];
    assign signal_select_468 = sample[22:22];
    assign signal_select_469 = sample[21:21];
    assign signal_select_470 = sample[20:20];
    assign signal_select_471 = sample[19:19];
    assign signal_select_472 = sample[18:18];
    assign signal_select_473 = sample[17:17];
    assign signal_select_474 = sample[16:16];
    assign signal_select_475 = sample[15:15];
    assign signal_select_476 = sample[14:14];
    assign signal_select_477 = sample[13:13];
    assign signal_select_478 = sample[12:12];
    assign signal_select_479 = sample[11:11];
    assign signal_select_480 = sample[10:10];
    assign signal_select_481 = sample[9:9];
    assign signal_select_482 = sample[8:8];
    assign signal_select_483 = sample[7:7];
    assign signal_select_484 = sample[6:6];
    assign signal_select_485 = sample[5:5];
    assign signal_select_486 = sample[4:4];
    assign signal_select_487 = sample[3:3];
    assign signal_select_488 = sample[2:2];
    assign signal_select_489 = sample[1:1];
    assign signal_select_490 = sample[0:0];
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_152 <= signal_select_490;
        1:
            signal_mux_152 <= signal_select_489;
        2:
            signal_mux_152 <= signal_select_488;
        3:
            signal_mux_152 <= signal_select_487;
        4:
            signal_mux_152 <= signal_select_486;
        5:
            signal_mux_152 <= signal_select_485;
        6:
            signal_mux_152 <= signal_select_484;
        7:
            signal_mux_152 <= signal_select_483;
        8:
            signal_mux_152 <= signal_select_482;
        9:
            signal_mux_152 <= signal_select_481;
        10:
            signal_mux_152 <= signal_select_480;
        11:
            signal_mux_152 <= signal_select_479;
        12:
            signal_mux_152 <= signal_select_478;
        13:
            signal_mux_152 <= signal_select_477;
        14:
            signal_mux_152 <= signal_select_476;
        15:
            signal_mux_152 <= signal_select_475;
        16:
            signal_mux_152 <= signal_select_474;
        17:
            signal_mux_152 <= signal_select_473;
        18:
            signal_mux_152 <= signal_select_472;
        19:
            signal_mux_152 <= signal_select_471;
        20:
            signal_mux_152 <= signal_select_470;
        21:
            signal_mux_152 <= signal_select_469;
        22:
            signal_mux_152 <= signal_select_468;
        23:
            signal_mux_152 <= signal_select_467;
        24:
            signal_mux_152 <= signal_select_466;
        25:
            signal_mux_152 <= signal_select_465;
        26:
            signal_mux_152 <= signal_select_464;
        default:
            signal_mux_152 <= signal_select_463;
        endcase
    end
    assign signal_eq_35 = signal_mux_152 == signal_wire_16;
    assign signal_select_491 = pins_sampled[27:27];
    assign signal_select_492 = pins_sampled[26:26];
    assign signal_select_493 = pins_sampled[25:25];
    assign signal_select_494 = pins_sampled[24:24];
    assign signal_select_495 = pins_sampled[23:23];
    assign signal_select_496 = pins_sampled[22:22];
    assign signal_select_497 = pins_sampled[21:21];
    assign signal_select_498 = pins_sampled[20:20];
    assign signal_select_499 = pins_sampled[19:19];
    assign signal_select_500 = pins_sampled[18:18];
    assign signal_select_501 = pins_sampled[17:17];
    assign signal_select_502 = pins_sampled[16:16];
    assign signal_select_503 = pins_sampled[15:15];
    assign signal_select_504 = pins_sampled[14:14];
    assign signal_select_505 = pins_sampled[13:13];
    assign signal_select_506 = pins_sampled[12:12];
    assign signal_select_507 = pins_sampled[11:11];
    assign signal_select_508 = pins_sampled[10:10];
    assign signal_select_509 = pins_sampled[9:9];
    assign signal_select_510 = pins_sampled[8:8];
    assign signal_select_511 = pins_sampled[7:7];
    assign signal_select_512 = pins_sampled[6:6];
    assign signal_select_513 = pins_sampled[5:5];
    assign signal_select_514 = pins_sampled[4:4];
    assign signal_select_515 = pins_sampled[3:3];
    assign signal_select_516 = pins_sampled[2:2];
    assign signal_select_517 = pins_sampled[1:1];
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_8 <= signal_const_10;
        else
            signal_reg_8 <= sample;
    end
    assign pins_sampled = signal_reg_8;
    assign signal_select_518 = pins_sampled[0:0];
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_153 <= signal_select_518;
        1:
            signal_mux_153 <= signal_select_517;
        2:
            signal_mux_153 <= signal_select_516;
        3:
            signal_mux_153 <= signal_select_515;
        4:
            signal_mux_153 <= signal_select_514;
        5:
            signal_mux_153 <= signal_select_513;
        6:
            signal_mux_153 <= signal_select_512;
        7:
            signal_mux_153 <= signal_select_511;
        8:
            signal_mux_153 <= signal_select_510;
        9:
            signal_mux_153 <= signal_select_509;
        10:
            signal_mux_153 <= signal_select_508;
        11:
            signal_mux_153 <= signal_select_507;
        12:
            signal_mux_153 <= signal_select_506;
        13:
            signal_mux_153 <= signal_select_505;
        14:
            signal_mux_153 <= signal_select_504;
        15:
            signal_mux_153 <= signal_select_503;
        16:
            signal_mux_153 <= signal_select_502;
        17:
            signal_mux_153 <= signal_select_501;
        18:
            signal_mux_153 <= signal_select_500;
        19:
            signal_mux_153 <= signal_select_499;
        20:
            signal_mux_153 <= signal_select_498;
        21:
            signal_mux_153 <= signal_select_497;
        22:
            signal_mux_153 <= signal_select_496;
        23:
            signal_mux_153 <= signal_select_495;
        24:
            signal_mux_153 <= signal_select_494;
        25:
            signal_mux_153 <= signal_select_493;
        26:
            signal_mux_153 <= signal_select_492;
        default:
            signal_mux_153 <= signal_select_491;
        endcase
    end
    assign signal_select_519 = sample[27:27];
    assign signal_select_520 = sample[26:26];
    assign signal_select_521 = sample[25:25];
    assign signal_select_522 = sample[24:24];
    assign signal_select_523 = sample[23:23];
    assign signal_select_524 = sample[22:22];
    assign signal_select_525 = sample[21:21];
    assign signal_select_526 = sample[20:20];
    assign signal_select_527 = sample[19:19];
    assign signal_select_528 = sample[18:18];
    assign signal_select_529 = sample[17:17];
    assign signal_select_530 = sample[16:16];
    assign signal_select_531 = sample[15:15];
    assign signal_select_532 = sample[14:14];
    assign signal_select_533 = sample[13:13];
    assign signal_select_534 = sample[12:12];
    assign signal_select_535 = sample[11:11];
    assign signal_select_536 = sample[10:10];
    assign signal_select_537 = sample[9:9];
    assign signal_select_538 = sample[8:8];
    assign signal_select_539 = sample[7:7];
    assign signal_select_540 = sample[6:6];
    assign signal_select_541 = sample[5:5];
    assign signal_select_542 = sample[4:4];
    assign signal_select_543 = sample[3:3];
    assign signal_select_544 = sample[2:2];
    assign signal_select_545 = sample[1:1];
    assign signal_select_546 = sample[0:0];
    assign signal_wire_17 = config$capture_pin;
    always @* begin
        case (signal_wire_17)
        0:
            signal_mux_154 <= signal_select_546;
        1:
            signal_mux_154 <= signal_select_545;
        2:
            signal_mux_154 <= signal_select_544;
        3:
            signal_mux_154 <= signal_select_543;
        4:
            signal_mux_154 <= signal_select_542;
        5:
            signal_mux_154 <= signal_select_541;
        6:
            signal_mux_154 <= signal_select_540;
        7:
            signal_mux_154 <= signal_select_539;
        8:
            signal_mux_154 <= signal_select_538;
        9:
            signal_mux_154 <= signal_select_537;
        10:
            signal_mux_154 <= signal_select_536;
        11:
            signal_mux_154 <= signal_select_535;
        12:
            signal_mux_154 <= signal_select_534;
        13:
            signal_mux_154 <= signal_select_533;
        14:
            signal_mux_154 <= signal_select_532;
        15:
            signal_mux_154 <= signal_select_531;
        16:
            signal_mux_154 <= signal_select_530;
        17:
            signal_mux_154 <= signal_select_529;
        18:
            signal_mux_154 <= signal_select_528;
        19:
            signal_mux_154 <= signal_select_527;
        20:
            signal_mux_154 <= signal_select_526;
        21:
            signal_mux_154 <= signal_select_525;
        22:
            signal_mux_154 <= signal_select_524;
        23:
            signal_mux_154 <= signal_select_523;
        24:
            signal_mux_154 <= signal_select_522;
        25:
            signal_mux_154 <= signal_select_521;
        26:
            signal_mux_154 <= signal_select_520;
        default:
            signal_mux_154 <= signal_select_519;
        endcase
    end
    assign signal_eq_36 = signal_mux_154 == signal_mux_153;
    assign signal_not_33 = ~ signal_eq_36;
    assign signal_eq_37 = d$sys_op$binary_variant == signal_const_85;
    assign signal_and_45 = is_opcode$7 & signal_eq_37;
    assign signal_and_46 = op_go & signal_and_45;
    assign signal_mux_155 = signal_and_46 ? vdd : capture_armed_0;
    assign signal_mux_156 = captured ? gnd : signal_mux_155;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_9 <= signal_const_3;
        else
            signal_reg_9 <= signal_mux_156;
    end
    assign capture_armed_0 = signal_reg_9;
    assign signal_and_47 = capture_armed_0 & signal_not_33;
    assign captured = signal_and_47 & signal_eq_35;
    assign signal_const_160 = 24'b000000000000000000000001;
    assign signal_add_5 = now_0 + signal_const_160;
    assign signal_mux_157 = start_0 ? signal_const_4 : signal_add_5;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_10 <= signal_const_4;
        else
            signal_reg_10 <= signal_mux_157;
    end
    assign now_0 = signal_reg_10;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_11 <= signal_const_4;
        else
            if (captured)
                signal_reg_11 <= now_0;
    end
    assign capture_0 = signal_reg_11;
    assign signal_select_547 = capture_0[15:0];
    assign signal_wire_18 = config$crc_init;
    assign signal_select_548 = signal_mux_160[7:0];
    assign signal_cat_126 = { signal_select_548,
                              signal_const_15 };
    assign signal_select_549 = signal_mux_159[11:0];
    assign signal_cat_127 = { signal_select_549,
                              signal_const_16 };
    assign signal_select_550 = signal_mux_158[13:0];
    assign signal_cat_128 = { signal_select_550,
                              signal_const_17 };
    assign signal_select_551 = signal_wire_20[0:0];
    assign signal_mux_158 = signal_select_551 ? signal_const_18 : signal_const_19;
    assign signal_select_552 = signal_wire_20[1:1];
    assign signal_mux_159 = signal_select_552 ? signal_cat_128 : signal_mux_158;
    assign signal_select_553 = signal_wire_20[2:2];
    assign signal_mux_160 = signal_select_553 ? signal_cat_127 : signal_mux_159;
    assign signal_select_554 = signal_wire_20[3:3];
    assign signal_mux_161 = signal_select_554 ? signal_cat_126 : signal_mux_160;
    assign signal_select_555 = signal_wire_20[4:4];
    assign signal_mux_162 = signal_select_555 ? signal_const_14 : signal_mux_161;
    assign signal_not_34 = ~ signal_mux_162;
    assign signal_xor_2 = signal_cat_129 ^ signal_wire_19;
    assign signal_select_556 = crc_0[15:1];
    assign signal_cat_129 = { signal_const_3,
                              signal_select_556 };
    assign signal_select_557 = crc_0[0:0];
    assign signal_xor_3 = signal_select_557 ^ crossing_bit;
    assign signal_mux_163 = signal_xor_3 ? signal_xor_2 : signal_cat_129;
    assign signal_wire_19 = config$crc_poly;
    assign signal_xor_4 = signal_cat_130 ^ signal_wire_19;
    assign signal_select_558 = crc_0[14:0];
    assign signal_cat_130 = { signal_select_558,
                              signal_const_3 };
    assign signal_select_559 = in_value[0:0];
    assign signal_select_560 = out_value[0:0];
    assign crossing_bit = is_opcode$2 ? signal_select_559 : signal_select_560;
    assign signal_select_561 = crc_0[15:15];
    assign signal_select_562 = crc_0[14:14];
    assign signal_select_563 = crc_0[13:13];
    assign signal_select_564 = crc_0[12:12];
    assign signal_select_565 = crc_0[11:11];
    assign signal_select_566 = crc_0[10:10];
    assign signal_select_567 = crc_0[9:9];
    assign signal_select_568 = crc_0[8:8];
    assign signal_select_569 = crc_0[7:7];
    assign signal_select_570 = crc_0[6:6];
    assign signal_select_571 = crc_0[5:5];
    assign signal_select_572 = crc_0[4:4];
    assign signal_select_573 = crc_0[3:3];
    assign signal_select_574 = crc_0[2:2];
    assign signal_select_575 = crc_0[1:1];
    assign signal_select_576 = crc_0[0:0];
    assign signal_wire_20 = config$crc_width;
    assign signal_sub_6 = signal_wire_20 - signal_const_64;
    always @* begin
        case (signal_sub_6)
        0:
            signal_mux_164 <= signal_select_576;
        1:
            signal_mux_164 <= signal_select_575;
        2:
            signal_mux_164 <= signal_select_574;
        3:
            signal_mux_164 <= signal_select_573;
        4:
            signal_mux_164 <= signal_select_572;
        5:
            signal_mux_164 <= signal_select_571;
        6:
            signal_mux_164 <= signal_select_570;
        7:
            signal_mux_164 <= signal_select_569;
        8:
            signal_mux_164 <= signal_select_568;
        9:
            signal_mux_164 <= signal_select_567;
        10:
            signal_mux_164 <= signal_select_566;
        11:
            signal_mux_164 <= signal_select_565;
        12:
            signal_mux_164 <= signal_select_564;
        13:
            signal_mux_164 <= signal_select_563;
        14:
            signal_mux_164 <= signal_select_562;
        default:
            signal_mux_164 <= signal_select_561;
        endcase
    end
    assign signal_xor_5 = signal_mux_164 ^ crossing_bit;
    assign signal_mux_165 = signal_xor_5 ? signal_xor_4 : signal_cat_130;
    assign signal_wire_21 = config$crc_reflect;
    assign signal_mux_166 = signal_wire_21 ? signal_mux_163 : signal_mux_165;
    assign crc_stepped = signal_mux_166 & signal_not_34;
    assign signal_eq_38 = signal_select_759 == signal_const_9;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            is_opcode$2 <= gnd;
        else
            if (ir_load)
                is_opcode$2 <= signal_eq_38;
    end
    assign signal_or_8 = is_opcode$2 | is_opcode$3;
    assign signal_eq_39 = d$shift_count == signal_const_64;
    assign bit_crosses = signal_eq_39 & signal_or_8;
    assign signal_mux_167 = bit_crosses ? crc_stepped : crc_0;
    assign signal_eq_40 = d$sys_op$binary_variant == signal_const_1;
    assign signal_and_48 = is_opcode$7 & signal_eq_40;
    assign crc_next = signal_and_48 ? signal_wire_18 : signal_mux_167;
    assign signal_mux_168 = go ? crc_next : crc_0;
    assign signal_mux_169 = start_0 ? signal_wire_18 : signal_mux_168;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_12 <= signal_const_14;
        else
            signal_reg_12 <= signal_mux_169;
    end
    assign crc_0 = signal_reg_12;
    assign signal_select_577 = signal_mux_172[7:0];
    assign signal_cat_131 = { signal_select_577,
                              signal_const_15 };
    assign signal_select_578 = signal_mux_171[11:0];
    assign signal_cat_132 = { signal_select_578,
                              signal_const_16 };
    assign signal_select_579 = signal_mux_170[13:0];
    assign signal_cat_133 = { signal_select_579,
                              signal_const_17 };
    assign signal_select_580 = d$shift_count[0:0];
    assign signal_mux_170 = signal_select_580 ? signal_const_18 : signal_const_19;
    assign signal_select_581 = d$shift_count[1:1];
    assign signal_mux_171 = signal_select_581 ? signal_cat_133 : signal_mux_170;
    assign signal_select_582 = d$shift_count[2:2];
    assign signal_mux_172 = signal_select_582 ? signal_cat_132 : signal_mux_171;
    assign signal_select_583 = d$shift_count[3:3];
    assign signal_mux_173 = signal_select_583 ? signal_cat_131 : signal_mux_172;
    assign signal_select_584 = d$shift_count[4:4];
    assign signal_mux_174 = signal_select_584 ? signal_const_14 : signal_mux_173;
    assign signal_not_35 = ~ signal_mux_174;
    assign signal_select_585 = signal_mux_178[27:16];
    assign signal_select_586 = signal_mux_178[15:0];
    assign signal_cat_134 = { signal_select_586,
                              signal_select_585 };
    assign signal_select_587 = signal_mux_177[27:8];
    assign signal_select_588 = signal_mux_177[7:0];
    assign signal_cat_135 = { signal_select_588,
                              signal_select_587 };
    assign signal_select_589 = signal_mux_176[27:4];
    assign signal_select_590 = signal_mux_176[3:0];
    assign signal_cat_136 = { signal_select_590,
                              signal_select_589 };
    assign signal_select_591 = signal_mux_175[27:2];
    assign signal_select_592 = signal_mux_175[1:0];
    assign signal_cat_137 = { signal_select_592,
                              signal_select_591 };
    assign signal_select_593 = sample[27:1];
    assign signal_select_594 = sample[0:0];
    assign signal_cat_138 = { signal_select_594,
                              signal_select_593 };
    assign signal_select_595 = signal_wire_26[0:0];
    assign signal_mux_175 = signal_select_595 ? signal_cat_138 : sample;
    assign signal_select_596 = signal_wire_26[1:1];
    assign signal_mux_176 = signal_select_596 ? signal_cat_137 : signal_mux_175;
    assign signal_select_597 = signal_wire_26[2:2];
    assign signal_mux_177 = signal_select_597 ? signal_cat_136 : signal_mux_176;
    assign signal_select_598 = signal_wire_26[3:3];
    assign signal_mux_178 = signal_select_598 ? signal_cat_135 : signal_mux_177;
    assign signal_select_599 = signal_wire_26[4:4];
    assign signal_mux_179 = signal_select_599 ? signal_cat_134 : signal_mux_178;
    assign signal_select_600 = signal_mux_179[15:0];
    assign signal_and_49 = signal_select_600 & signal_not_35;
    always @* begin
        case (d$out_dest$binary_variant)
        0:
            signal_mux_180 <= signal_and_49;
        1:
            signal_mux_180 <= x_0;
        2:
            signal_mux_180 <= y_0;
        3:
            signal_mux_180 <= signal_const_14;
        4:
            signal_mux_180 <= isr_0;
        5:
            signal_mux_180 <= osr_0;
        6:
            signal_mux_180 <= crc_0;
        default:
            signal_mux_180 <= signal_select_547;
        endcase
    end
    assign in_value = signal_mux_180 & mask;
    assign signal_select_601 = signal_mux_183[7:0];
    assign signal_cat_139 = { signal_select_601,
                              signal_const_15 };
    assign signal_select_602 = signal_mux_182[11:0];
    assign signal_cat_140 = { signal_select_602,
                              signal_const_16 };
    assign signal_select_603 = signal_mux_181[13:0];
    assign signal_cat_141 = { signal_select_603,
                              signal_const_17 };
    assign signal_select_604 = isr_0[14:0];
    assign signal_cat_142 = { signal_select_604,
                              signal_const_3 };
    assign signal_select_605 = d$shift_count[0:0];
    assign signal_mux_181 = signal_select_605 ? signal_cat_142 : isr_0;
    assign signal_select_606 = d$shift_count[1:1];
    assign signal_mux_182 = signal_select_606 ? signal_cat_141 : signal_mux_181;
    assign signal_select_607 = d$shift_count[2:2];
    assign signal_mux_183 = signal_select_607 ? signal_cat_140 : signal_mux_182;
    assign signal_select_608 = d$shift_count[3:3];
    assign signal_mux_184 = signal_select_608 ? signal_cat_139 : signal_mux_183;
    assign signal_select_609 = d$shift_count[4:4];
    assign signal_mux_185 = signal_select_609 ? signal_const_14 : signal_mux_184;
    assign signal_or_9 = signal_mux_185 | in_value;
    assign signal_wire_22 = config$in_shift_right;
    assign isr_shifted = signal_wire_22 ? signal_or_7 : signal_or_9;
    assign signal_wire_23 = config$push_threshold;
    assign signal_const_186 = 5'b10000;
    assign signal_select_610 = signal_add_6[4:0];
    assign signal_cat_143 = { gnd,
                              d$shift_count };
    assign signal_eq_41 = d$sys_op$binary_variant == signal_const_81;
    assign signal_and_50 = is_opcode$7 & signal_eq_41;
    assign signal_mux_186 = signal_and_50 ? osr_count_zero : isr_count_0;
    assign signal_eq_42 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_187 = signal_eq_42 ? osr_count_zero : isr_count_0;
    assign signal_eq_43 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_188 = signal_eq_43 ? d$shift_count : isr_count_0;
    assign signal_mux_189 = autopush_now ? osr_count_zero : isr_count_next;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_count_next_value <= isr_count_0;
        1:
            isr_count_next_value <= isr_count_0;
        2:
            isr_count_next_value <= signal_mux_189;
        3:
            isr_count_next_value <= signal_mux_188;
        4:
            isr_count_next_value <= signal_mux_187;
        5:
            isr_count_next_value <= isr_count_0;
        6:
            isr_count_next_value <= isr_count_0;
        default:
            isr_count_next_value <= signal_mux_186;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_13 <= signal_const_61;
        else
            if (go)
                signal_reg_13 <= isr_count_next_value;
    end
    assign isr_count_0 = signal_reg_13;
    assign signal_cat_144 = { gnd,
                              isr_count_0 };
    assign signal_add_6 = signal_cat_144 + signal_cat_143;
    assign signal_const_191 = 6'b010000;
    assign signal_lt_2 = signal_const_191 < signal_add_6;
    assign isr_count_next = signal_lt_2 ? signal_const_186 : signal_select_610;
    assign signal_lt_3 = isr_count_next < signal_wire_23;
    assign signal_not_36 = ~ signal_lt_3;
    assign signal_wire_24 = config$autopush;
    assign autopush_now = signal_wire_24 & signal_not_36;
    assign signal_mux_190 = autopush_now ? signal_const_14 : isr_shifted;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_next <= isr_0;
        1:
            isr_next <= isr_0;
        2:
            isr_next <= signal_mux_190;
        3:
            isr_next <= signal_mux_136;
        4:
            isr_next <= signal_mux_135;
        5:
            isr_next <= isr_0;
        6:
            isr_next <= isr_0;
        default:
            isr_next <= signal_mux_134;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_14 <= signal_const_14;
        else
            if (go)
                signal_reg_14 <= isr_next;
    end
    assign isr_0 = signal_reg_14;
    assign signal_xor_6 = p_0 ^ alu_operand;
    assign signal_sub_7 = p_0 - alu_operand;
    assign signal_add_7 = p_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_191 <= signal_add_7;
        1:
            signal_mux_191 <= signal_sub_7;
        default:
            signal_mux_191 <= signal_xor_6;
        endcase
    end
    assign signal_eq_44 = d$alu_dest$binary_variant == signal_const_97;
    assign signal_mux_192 = signal_eq_44 ? signal_mux_191 : p_0;
    assign signal_cat_145 = { signal_const_11,
                              d$set_value };
    assign signal_eq_45 = d$set_dest$binary_variant == signal_const;
    assign signal_mux_193 = signal_eq_45 ? signal_cat_145 : p_0;
    assign signal_eq_46 = d$mov_dest$binary_variant == signal_const_2;
    assign signal_mux_194 = signal_eq_46 ? mov_value : p_0;
    assign signal_eq_47 = d$out_dest$binary_variant == signal_const_2;
    assign signal_mux_195 = signal_eq_47 ? out_value : p_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            p_next <= p_0;
        1:
            p_next <= p_0;
        2:
            p_next <= p_0;
        3:
            p_next <= signal_mux_195;
        4:
            p_next <= signal_mux_194;
        5:
            p_next <= signal_mux_193;
        6:
            p_next <= signal_mux_192;
        default:
            p_next <= p_0;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_15 <= signal_const_14;
        else
            if (go)
                signal_reg_15 <= p_next;
    end
    assign p_0 = signal_reg_15;
    assign signal_xor_7 = y_0 ^ alu_operand;
    assign signal_sub_8 = y_0 - alu_operand;
    assign signal_add_8 = y_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_196 <= signal_add_8;
        1:
            signal_mux_196 <= signal_sub_8;
        default:
            signal_mux_196 <= signal_xor_7;
        endcase
    end
    assign signal_const_199 = 2'b01;
    assign signal_eq_48 = d$alu_dest$binary_variant == signal_const_199;
    assign signal_mux_197 = signal_eq_48 ? signal_mux_196 : y_0;
    assign signal_cat_146 = { signal_const_11,
                              d$set_value };
    assign signal_eq_49 = d$set_dest$binary_variant == signal_const_9;
    assign signal_mux_198 = signal_eq_49 ? signal_cat_146 : y_0;
    assign signal_eq_50 = d$mov_dest$binary_variant == signal_const_9;
    assign signal_mux_199 = signal_eq_50 ? mov_value : y_0;
    assign signal_eq_51 = d$out_dest$binary_variant == signal_const_9;
    assign signal_mux_200 = signal_eq_51 ? out_value : y_0;
    assign signal_const_204 = 16'b0000000000000001;
    assign signal_sub_9 = y_0 - signal_const_204;
    assign signal_const_205 = 4'b0010;
    assign signal_eq_52 = d$jmp_cond$binary_variant == signal_const_205;
    assign signal_mux_201 = signal_eq_52 ? signal_sub_9 : y_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            y_next <= signal_mux_201;
        1:
            y_next <= y_0;
        2:
            y_next <= y_0;
        3:
            y_next <= signal_mux_200;
        4:
            y_next <= signal_mux_199;
        5:
            y_next <= signal_mux_198;
        6:
            y_next <= signal_mux_197;
        default:
            y_next <= y_0;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_16 <= signal_const_14;
        else
            if (go)
                signal_reg_16 <= y_next;
    end
    assign y_0 = signal_reg_16;
    always @* begin
        case (d$alu_reg$binary_variant)
        0:
            signal_mux_202 <= x_0;
        1:
            signal_mux_202 <= y_0;
        2:
            signal_mux_202 <= p_0;
        3:
            signal_mux_202 <= isr_0;
        default:
            signal_mux_202 <= osr_0;
        endcase
    end
    assign d$alu_reg$binary_variant = word[2:0];
    assign signal_const_206 = 13'b0000000000000;
    assign signal_cat_147 = { signal_const_206,
                              d$alu_reg$binary_variant };
    assign d$alu_is_reg = word[3:3];
    assign alu_operand = d$alu_is_reg ? signal_mux_202 : signal_cat_147;
    assign signal_add_9 = x_0 + alu_operand;
    assign d$alu_op$binary_variant = word[5:4];
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_203 <= signal_add_9;
        1:
            signal_mux_203 <= signal_sub_5;
        default:
            signal_mux_203 <= signal_xor_1;
        endcase
    end
    assign d$alu_dest$binary_variant = word[7:6];
    assign signal_eq_53 = d$alu_dest$binary_variant == signal_const_17;
    assign signal_mux_204 = signal_eq_53 ? signal_mux_203 : x_0;
    assign d$set_value = word[4:0];
    assign signal_cat_148 = { signal_const_11,
                              d$set_value };
    assign d$set_dest$binary_variant = word[7:5];
    assign signal_eq_54 = d$set_dest$binary_variant == signal_const_70;
    assign signal_mux_205 = signal_eq_54 ? signal_cat_148 : x_0;
    assign signal_eq_55 = d$mov_dest$binary_variant == signal_const_70;
    assign signal_mux_206 = signal_eq_55 ? mov_value : x_0;
    assign signal_eq_56 = d$out_dest$binary_variant == signal_const_70;
    assign signal_mux_207 = signal_eq_56 ? out_value : x_0;
    assign signal_sub_10 = x_0 - signal_const_204;
    assign signal_const_213 = 4'b0001;
    assign d$jmp_cond$binary_variant = word[12:9];
    assign signal_eq_57 = d$jmp_cond$binary_variant == signal_const_213;
    assign signal_mux_208 = signal_eq_57 ? signal_sub_10 : x_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            x_next <= signal_mux_208;
        1:
            x_next <= x_0;
        2:
            x_next <= x_0;
        3:
            x_next <= signal_mux_207;
        4:
            x_next <= signal_mux_206;
        5:
            x_next <= signal_mux_205;
        6:
            x_next <= signal_mux_204;
        default:
            x_next <= x_0;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_17 <= signal_const_14;
        else
            if (go)
                signal_reg_17 <= x_next;
    end
    assign x_0 = signal_reg_17;
    assign signal_cat_149 = { signal_const_15,
                              x_0 };
    assign signal_select_611 = signal_mux_211[7:0];
    assign signal_cat_150 = { signal_select_611,
                              signal_const_15 };
    assign signal_select_612 = signal_mux_210[11:0];
    assign signal_cat_151 = { signal_select_612,
                              signal_const_16 };
    assign signal_select_613 = signal_mux_209[13:0];
    assign signal_cat_152 = { signal_select_613,
                              signal_const_17 };
    assign signal_select_614 = signal_wire_25[0:0];
    assign signal_mux_209 = signal_select_614 ? signal_const_18 : signal_const_19;
    assign signal_select_615 = signal_wire_25[1:1];
    assign signal_mux_210 = signal_select_615 ? signal_cat_152 : signal_mux_209;
    assign signal_select_616 = signal_wire_25[2:2];
    assign signal_mux_211 = signal_select_616 ? signal_cat_151 : signal_mux_210;
    assign signal_select_617 = signal_wire_25[3:3];
    assign signal_mux_212 = signal_select_617 ? signal_cat_150 : signal_mux_211;
    assign signal_wire_25 = config$in_count;
    assign signal_select_618 = signal_wire_25[4:4];
    assign signal_mux_213 = signal_select_618 ? signal_const_14 : signal_mux_212;
    assign signal_not_37 = ~ signal_mux_213;
    assign signal_select_619 = signal_mux_217[27:16];
    assign signal_select_620 = signal_mux_217[15:0];
    assign signal_cat_153 = { signal_select_620,
                              signal_select_619 };
    assign signal_select_621 = signal_mux_216[27:8];
    assign signal_select_622 = signal_mux_216[7:0];
    assign signal_cat_154 = { signal_select_622,
                              signal_select_621 };
    assign signal_select_623 = signal_mux_215[27:4];
    assign signal_select_624 = signal_mux_215[3:0];
    assign signal_cat_155 = { signal_select_624,
                              signal_select_623 };
    assign signal_select_625 = signal_mux_214[27:2];
    assign signal_select_626 = signal_mux_214[1:0];
    assign signal_cat_156 = { signal_select_626,
                              signal_select_625 };
    assign signal_select_627 = sample[27:1];
    assign signal_select_628 = sample[0:0];
    assign signal_cat_157 = { signal_select_628,
                              signal_select_627 };
    assign signal_select_629 = signal_wire_26[0:0];
    assign signal_mux_214 = signal_select_629 ? signal_cat_157 : sample;
    assign signal_select_630 = signal_wire_26[1:1];
    assign signal_mux_215 = signal_select_630 ? signal_cat_156 : signal_mux_214;
    assign signal_select_631 = signal_wire_26[2:2];
    assign signal_mux_216 = signal_select_631 ? signal_cat_155 : signal_mux_215;
    assign signal_select_632 = signal_wire_26[3:3];
    assign signal_mux_217 = signal_select_632 ? signal_cat_154 : signal_mux_216;
    assign signal_wire_26 = config$in_base;
    assign signal_select_633 = signal_wire_26[4:4];
    assign signal_mux_218 = signal_select_633 ? signal_cat_153 : signal_mux_217;
    assign signal_select_634 = signal_mux_218[15:0];
    assign signal_and_51 = signal_select_634 & signal_not_37;
    assign signal_cat_158 = { signal_const_15,
                              signal_and_51 };
    assign d$mov_source$binary_variant = word[2:0];
    always @* begin
        case (d$mov_source$binary_variant)
        0:
            mov_value24 <= signal_cat_158;
        1:
            mov_value24 <= signal_cat_149;
        2:
            mov_value24 <= signal_cat_114;
        3:
            mov_value24 <= signal_const_4;
        4:
            mov_value24 <= signal_cat_113;
        5:
            mov_value24 <= signal_cat_112;
        6:
            mov_value24 <= now_0;
        default:
            mov_value24 <= capture_0;
        endcase
    end
    assign signal_select_635 = mov_value24[15:0];
    assign d$mov_op$binary_variant = word[4:3];
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value <= signal_select_635;
        1:
            mov_value <= signal_not_32;
        default:
            mov_value <= signal_cat_111;
        endcase
    end
    assign signal_eq_58 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_219 = signal_eq_58 ? mov_value : osr_0;
    assign signal_select_636 = signal_mux_222[15:8];
    assign signal_cat_159 = { signal_const_15,
                              signal_select_636 };
    assign signal_select_637 = signal_mux_221[15:4];
    assign signal_cat_160 = { signal_const_16,
                              signal_select_637 };
    assign signal_select_638 = signal_mux_220[15:2];
    assign signal_cat_161 = { signal_const_17,
                              signal_select_638 };
    assign signal_select_639 = osr_before[15:1];
    assign signal_cat_162 = { signal_const_3,
                              signal_select_639 };
    assign signal_select_640 = d$shift_count[0:0];
    assign signal_mux_220 = signal_select_640 ? signal_cat_162 : osr_before;
    assign signal_select_641 = d$shift_count[1:1];
    assign signal_mux_221 = signal_select_641 ? signal_cat_161 : signal_mux_220;
    assign signal_select_642 = d$shift_count[2:2];
    assign signal_mux_222 = signal_select_642 ? signal_cat_160 : signal_mux_221;
    assign signal_select_643 = d$shift_count[3:3];
    assign signal_mux_223 = signal_select_643 ? signal_cat_159 : signal_mux_222;
    assign signal_select_644 = d$shift_count[4:4];
    assign signal_mux_224 = signal_select_644 ? signal_const_14 : signal_mux_223;
    assign signal_select_645 = signal_mux_227[7:0];
    assign signal_cat_163 = { signal_select_645,
                              signal_const_15 };
    assign signal_select_646 = signal_mux_226[11:0];
    assign signal_cat_164 = { signal_select_646,
                              signal_const_16 };
    assign signal_select_647 = signal_mux_225[13:0];
    assign signal_cat_165 = { signal_select_647,
                              signal_const_17 };
    assign signal_select_648 = osr_before[14:0];
    assign signal_cat_166 = { signal_select_648,
                              signal_const_3 };
    assign signal_select_649 = d$shift_count[0:0];
    assign signal_mux_225 = signal_select_649 ? signal_cat_166 : osr_before;
    assign signal_select_650 = d$shift_count[1:1];
    assign signal_mux_226 = signal_select_650 ? signal_cat_165 : signal_mux_225;
    assign signal_select_651 = d$shift_count[2:2];
    assign signal_mux_227 = signal_select_651 ? signal_cat_164 : signal_mux_226;
    assign signal_select_652 = d$shift_count[3:3];
    assign signal_mux_228 = signal_select_652 ? signal_cat_163 : signal_mux_227;
    assign signal_select_653 = d$shift_count[4:4];
    assign signal_mux_229 = signal_select_653 ? signal_const_14 : signal_mux_228;
    assign osr_shifted = signal_wire_32 ? signal_mux_224 : signal_mux_229;
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
            osr_next <= signal_mux_219;
        5:
            osr_next <= osr_0;
        6:
            osr_next <= osr_0;
        default:
            osr_next <= signal_mux_133;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_18 <= signal_const_14;
        else
            if (go)
                signal_reg_18 <= osr_next;
    end
    assign osr_0 = signal_reg_18;
    assign signal_wire_27 = flush;
    assign flush_0 = signal_wire_27 & halted_0;
    assign signal_not_38 = ~ signal_select_654;
    assign signal_and_52 = pulls & signal_not_38;
    assign signal_eq_59 = signal_select_759 == signal_const_81;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            is_opcode$3 <= gnd;
        else
            if (ir_load)
                is_opcode$3 <= signal_eq_59;
    end
    assign signal_and_53 = is_opcode$3 & pull_ok;
    assign signal_or_10 = signal_and_53 | signal_and_52;
    assign signal_and_54 = op_go & signal_or_10;
    assign tx_pop = signal_and_54;
    assign signal_wire_28 = tx$value;
    assign signal_wire_29 = tx$valid;
    host_fifo
        tx
        ( .clock(signal_wire_42),
          .clear(signal_wire_39),
          .push$valid(signal_wire_29),
          .push$value(signal_wire_28),
          .pop(tx_pop),
          .flush(flush_0),
          .head(signal_inst_1[15:0]),
          .level(signal_inst_1[19:16]),
          .empty(signal_inst_1[20:20]),
          .full(signal_inst_1[21:21]) );
    assign signal_select_654 = signal_inst_1[20:20];
    assign signal_not_39 = ~ signal_select_654;
    assign signal_wire_30 = config$pull_threshold;
    assign d$sys_op$binary_variant = word[2:0];
    assign signal_eq_60 = d$sys_op$binary_variant == signal_const;
    assign signal_eq_61 = signal_select_759 == signal_const_85;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            is_opcode$7 <= gnd;
        else
            if (ir_load)
                is_opcode$7 <= signal_eq_61;
    end
    assign pulls = is_opcode$7 & signal_eq_60;
    assign signal_mux_230 = pulls ? osr_count_zero : osr_count_0;
    assign osr_count_zero = 5'b00000;
    assign d$mov_dest$binary_variant = word[7:5];
    assign signal_eq_62 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_231 = signal_eq_62 ? osr_count_zero : osr_count_0;
    assign signal_select_655 = signal_add_10[4:0];
    assign signal_cat_167 = { gnd,
                              d$shift_count };
    assign osr_count_before = pull_now ? signal_const_61 : osr_count_0;
    assign signal_cat_168 = { gnd,
                              osr_count_before };
    assign signal_add_10 = signal_cat_168 + signal_cat_167;
    assign signal_lt_4 = signal_const_191 < signal_add_10;
    assign osr_count_next = signal_lt_4 ? signal_const_186 : signal_select_655;
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
            osr_count_next_value <= signal_mux_231;
        5:
            osr_count_next_value <= osr_count_0;
        6:
            osr_count_next_value <= osr_count_0;
        default:
            osr_count_next_value <= signal_mux_230;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_19 <= signal_const_186;
        else
            if (go)
                signal_reg_19 <= osr_count_next_value;
    end
    assign osr_count_0 = signal_reg_19;
    assign signal_lt_5 = osr_count_0 < signal_wire_30;
    assign signal_not_40 = ~ signal_lt_5;
    assign signal_wire_31 = config$autopull;
    assign pull_now = signal_wire_31 & signal_not_40;
    assign pull_ok = pull_now & signal_not_39;
    assign osr_before = pull_ok ? signal_select_420 : osr_0;
    assign signal_select_656 = shift_back[0:0];
    assign signal_mux_232 = signal_select_656 ? signal_cat_110 : osr_before;
    assign signal_select_657 = shift_back[1:1];
    assign signal_mux_233 = signal_select_657 ? signal_cat_109 : signal_mux_232;
    assign signal_select_658 = shift_back[2:2];
    assign signal_mux_234 = signal_select_658 ? signal_cat_108 : signal_mux_233;
    assign signal_select_659 = shift_back[3:3];
    assign signal_mux_235 = signal_select_659 ? signal_cat_107 : signal_mux_234;
    assign shift_back = signal_const_186 - d$shift_count;
    assign signal_select_660 = shift_back[4:4];
    assign signal_mux_236 = signal_select_660 ? signal_const_14 : signal_mux_235;
    assign signal_and_55 = signal_mux_236 & mask;
    assign signal_wire_32 = config$out_shift_right;
    assign out_value = signal_wire_32 ? signal_and_42 : signal_and_55;
    assign signal_cat_169 = { signal_const_12,
                              out_value };
    assign signal_select_661 = signal_wire_33[0:0];
    assign signal_mux_237 = signal_select_661 ? signal_cat_106 : signal_cat_169;
    assign signal_select_662 = signal_wire_33[1:1];
    assign signal_mux_238 = signal_select_662 ? signal_cat_105 : signal_mux_237;
    assign signal_select_663 = signal_wire_33[2:2];
    assign signal_mux_239 = signal_select_663 ? signal_cat_104 : signal_mux_238;
    assign signal_select_664 = signal_wire_33[3:3];
    assign signal_mux_240 = signal_select_664 ? signal_cat_103 : signal_mux_239;
    assign signal_select_665 = signal_wire_33[4:4];
    assign signal_mux_241 = signal_select_665 ? signal_cat_102 : signal_mux_240;
    assign signal_and_56 = signal_mux_241 & signal_and_57;
    assign signal_select_666 = signal_mux_250[27:12];
    assign signal_select_667 = signal_mux_250[11:0];
    assign signal_cat_170 = { signal_select_667,
                              signal_select_666 };
    assign signal_select_668 = signal_mux_249[27:20];
    assign signal_select_669 = signal_mux_249[19:0];
    assign signal_cat_171 = { signal_select_669,
                              signal_select_668 };
    assign signal_select_670 = signal_mux_248[27:24];
    assign signal_select_671 = signal_mux_248[23:0];
    assign signal_cat_172 = { signal_select_671,
                              signal_select_670 };
    assign signal_select_672 = signal_mux_247[27:26];
    assign signal_select_673 = signal_mux_247[25:0];
    assign signal_cat_173 = { signal_select_673,
                              signal_select_672 };
    assign signal_select_674 = signal_cat_178[27:27];
    assign signal_select_675 = signal_cat_178[26:0];
    assign signal_cat_174 = { signal_select_675,
                              signal_select_674 };
    assign signal_select_676 = signal_mux_244[7:0];
    assign signal_cat_175 = { signal_select_676,
                              signal_const_15 };
    assign signal_select_677 = signal_mux_243[11:0];
    assign signal_cat_176 = { signal_select_677,
                              signal_const_16 };
    assign signal_select_678 = signal_mux_242[13:0];
    assign signal_cat_177 = { signal_select_678,
                              signal_const_17 };
    assign signal_select_679 = d$shift_count[0:0];
    assign signal_mux_242 = signal_select_679 ? signal_const_18 : signal_const_19;
    assign signal_select_680 = d$shift_count[1:1];
    assign signal_mux_243 = signal_select_680 ? signal_cat_177 : signal_mux_242;
    assign signal_select_681 = d$shift_count[2:2];
    assign signal_mux_244 = signal_select_681 ? signal_cat_176 : signal_mux_243;
    assign signal_select_682 = d$shift_count[3:3];
    assign signal_mux_245 = signal_select_682 ? signal_cat_175 : signal_mux_244;
    assign d$shift_count = word[4:0];
    assign signal_select_683 = d$shift_count[4:4];
    assign signal_mux_246 = signal_select_683 ? signal_const_14 : signal_mux_245;
    assign signal_not_41 = ~ signal_mux_246;
    assign signal_cat_178 = { signal_const_12,
                              signal_not_41 };
    assign signal_select_684 = signal_wire_33[0:0];
    assign signal_mux_247 = signal_select_684 ? signal_cat_174 : signal_cat_178;
    assign signal_select_685 = signal_wire_33[1:1];
    assign signal_mux_248 = signal_select_685 ? signal_cat_173 : signal_mux_247;
    assign signal_select_686 = signal_wire_33[2:2];
    assign signal_mux_249 = signal_select_686 ? signal_cat_172 : signal_mux_248;
    assign signal_select_687 = signal_wire_33[3:3];
    assign signal_mux_250 = signal_select_687 ? signal_cat_171 : signal_mux_249;
    assign signal_wire_33 = config$out_base;
    assign signal_select_688 = signal_wire_33[4:4];
    assign signal_mux_251 = signal_select_688 ? signal_cat_170 : signal_mux_250;
    assign signal_and_57 = signal_mux_251 & signal_const_101;
    assign signal_not_42 = ~ signal_and_57;
    assign signal_and_58 = pin_dir_base & signal_not_42;
    assign signal_or_11 = signal_and_58 | signal_and_56;
    assign d$out_dest$binary_variant = word[7:5];
    assign signal_eq_63 = d$out_dest$binary_variant == signal_const;
    assign signal_mux_252 = signal_eq_63 ? signal_or_11 : pin_dir_base;
    assign signal_select_689 = signal_mux_256[27:12];
    assign signal_select_690 = signal_mux_256[11:0];
    assign signal_cat_179 = { signal_select_690,
                              signal_select_689 };
    assign signal_select_691 = signal_mux_255[27:20];
    assign signal_select_692 = signal_mux_255[19:0];
    assign signal_cat_180 = { signal_select_692,
                              signal_select_691 };
    assign signal_select_693 = signal_mux_254[27:24];
    assign signal_select_694 = signal_mux_254[23:0];
    assign signal_cat_181 = { signal_select_694,
                              signal_select_693 };
    assign signal_select_695 = signal_mux_253[27:26];
    assign signal_select_696 = signal_mux_253[25:0];
    assign signal_cat_182 = { signal_select_696,
                              signal_select_695 };
    assign signal_select_697 = signal_cat_186[27:27];
    assign signal_select_698 = signal_cat_186[26:0];
    assign signal_cat_183 = { signal_select_698,
                              signal_select_697 };
    assign signal_select_699 = signal_select_701[4:3];
    assign signal_select_700 = signal_select_701[4:3];
    assign signal_select_701 = word[12:8];
    assign signal_select_702 = signal_select_701[4:4];
    assign signal_cat_184 = { gnd,
                              signal_select_702 };
    always @* begin
        case (signal_wire_34)
        0:
            d$side_set <= signal_const_17;
        1:
            d$side_set <= signal_cat_184;
        2:
            d$side_set <= signal_select_700;
        default:
            d$side_set <= signal_select_699;
        endcase
    end
    assign signal_cat_185 = { signal_const_42,
                              d$side_set };
    assign signal_cat_186 = { signal_const_12,
                              signal_cat_185 };
    assign signal_select_703 = signal_wire_35[0:0];
    assign signal_mux_253 = signal_select_703 ? signal_cat_183 : signal_cat_186;
    assign signal_select_704 = signal_wire_35[1:1];
    assign signal_mux_254 = signal_select_704 ? signal_cat_182 : signal_mux_253;
    assign signal_select_705 = signal_wire_35[2:2];
    assign signal_mux_255 = signal_select_705 ? signal_cat_181 : signal_mux_254;
    assign signal_select_706 = signal_wire_35[3:3];
    assign signal_mux_256 = signal_select_706 ? signal_cat_180 : signal_mux_255;
    assign signal_select_707 = signal_wire_35[4:4];
    assign signal_mux_257 = signal_select_707 ? signal_cat_179 : signal_mux_256;
    assign signal_and_59 = signal_mux_257 & signal_and_60;
    assign signal_select_708 = signal_mux_266[27:12];
    assign signal_select_709 = signal_mux_266[11:0];
    assign signal_cat_187 = { signal_select_709,
                              signal_select_708 };
    assign signal_select_710 = signal_mux_265[27:20];
    assign signal_select_711 = signal_mux_265[19:0];
    assign signal_cat_188 = { signal_select_711,
                              signal_select_710 };
    assign signal_select_712 = signal_mux_264[27:24];
    assign signal_select_713 = signal_mux_264[23:0];
    assign signal_cat_189 = { signal_select_713,
                              signal_select_712 };
    assign signal_select_714 = signal_mux_263[27:26];
    assign signal_select_715 = signal_mux_263[25:0];
    assign signal_cat_190 = { signal_select_715,
                              signal_select_714 };
    assign signal_select_716 = signal_cat_196[27:27];
    assign signal_select_717 = signal_cat_196[26:0];
    assign signal_cat_191 = { signal_select_717,
                              signal_select_716 };
    assign signal_select_718 = signal_mux_260[7:0];
    assign signal_cat_192 = { signal_select_718,
                              signal_const_15 };
    assign signal_select_719 = signal_mux_259[11:0];
    assign signal_cat_193 = { signal_select_719,
                              signal_const_16 };
    assign signal_select_720 = signal_mux_258[13:0];
    assign signal_cat_194 = { signal_select_720,
                              signal_const_17 };
    assign signal_select_721 = signal_cat_195[0:0];
    assign signal_mux_258 = signal_select_721 ? signal_const_18 : signal_const_19;
    assign signal_select_722 = signal_cat_195[1:1];
    assign signal_mux_259 = signal_select_722 ? signal_cat_194 : signal_mux_258;
    assign signal_select_723 = signal_cat_195[2:2];
    assign signal_mux_260 = signal_select_723 ? signal_cat_193 : signal_mux_259;
    assign signal_select_724 = signal_cat_195[3:3];
    assign signal_mux_261 = signal_select_724 ? signal_cat_192 : signal_mux_260;
    assign signal_wire_34 = config$side_set_count;
    assign signal_cat_195 = { signal_const_21,
                              signal_wire_34 };
    assign signal_select_725 = signal_cat_195[4:4];
    assign signal_mux_262 = signal_select_725 ? signal_const_14 : signal_mux_261;
    assign signal_not_43 = ~ signal_mux_262;
    assign signal_cat_196 = { signal_const_12,
                              signal_not_43 };
    assign signal_select_726 = signal_wire_35[0:0];
    assign signal_mux_263 = signal_select_726 ? signal_cat_191 : signal_cat_196;
    assign signal_select_727 = signal_wire_35[1:1];
    assign signal_mux_264 = signal_select_727 ? signal_cat_190 : signal_mux_263;
    assign signal_select_728 = signal_wire_35[2:2];
    assign signal_mux_265 = signal_select_728 ? signal_cat_189 : signal_mux_264;
    assign signal_select_729 = signal_wire_35[3:3];
    assign signal_mux_266 = signal_select_729 ? signal_cat_188 : signal_mux_265;
    assign signal_wire_35 = config$side_set_base;
    assign signal_select_730 = signal_wire_35[4:4];
    assign signal_mux_267 = signal_select_730 ? signal_cat_187 : signal_mux_266;
    assign signal_and_60 = signal_mux_267 & signal_const_101;
    assign signal_not_44 = ~ signal_and_60;
    assign signal_and_61 = pin_dir_0 & signal_not_44;
    assign pin_dir_side = signal_and_61 | signal_and_59;
    assign signal_wire_36 = config$side_set_pindirs;
    assign pin_dir_base = signal_wire_36 ? pin_dir_side : pin_dir_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            pin_dir_next <= pin_dir_base;
        1:
            pin_dir_next <= pin_dir_base;
        2:
            pin_dir_next <= pin_dir_base;
        3:
            pin_dir_next <= signal_mux_252;
        4:
            pin_dir_next <= signal_mux_132;
        5:
            pin_dir_next <= signal_mux_116;
        6:
            pin_dir_next <= pin_dir_base;
        default:
            pin_dir_next <= pin_dir_base;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_20 <= signal_const_10;
        else
            if (op_go)
                signal_reg_20 <= pin_dir_next;
    end
    assign pin_dir_0 = signal_reg_20;
    assign signal_select_731 = pin_dir_0[19:19];
    assign signal_mux_268 = signal_select_731 ? signal_select_328 : signal_select_329;
    assign signal_select_732 = signal_wire_37[20:20];
    assign signal_select_733 = pin_out_0[20:20];
    assign signal_or_12 = signal_select_733 | signal_select_732;
    assign signal_select_734 = signal_wire_37[21:21];
    assign signal_select_735 = pin_out_0[21:21];
    assign signal_or_13 = signal_select_735 | signal_select_734;
    assign signal_select_736 = signal_wire_37[22:22];
    assign signal_select_737 = pin_out_0[22:22];
    assign signal_or_14 = signal_select_737 | signal_select_736;
    assign signal_select_738 = signal_wire_37[23:23];
    assign signal_select_739 = pin_out_0[23:23];
    assign signal_or_15 = signal_select_739 | signal_select_738;
    assign signal_select_740 = signal_wire_37[24:24];
    assign signal_select_741 = pin_out_0[24:24];
    assign signal_or_16 = signal_select_741 | signal_select_740;
    assign signal_select_742 = signal_wire_37[25:25];
    assign signal_select_743 = pin_out_0[25:25];
    assign signal_or_17 = signal_select_743 | signal_select_742;
    assign signal_select_744 = signal_wire_37[26:26];
    assign signal_select_745 = pin_out_0[26:26];
    assign signal_or_18 = signal_select_745 | signal_select_744;
    assign signal_wire_37 = inputs;
    assign signal_select_746 = signal_wire_37[27:27];
    assign signal_select_747 = pin_out_0[27:27];
    assign signal_or_19 = signal_select_747 | signal_select_746;
    assign sample = { signal_or_19,
                      signal_or_18,
                      signal_or_17,
                      signal_or_16,
                      signal_or_15,
                      signal_or_14,
                      signal_or_13,
                      signal_or_12,
                      signal_mux_268,
                      signal_mux_100,
                      signal_mux_99,
                      signal_mux_98,
                      signal_mux_97,
                      signal_mux_96,
                      signal_mux_95,
                      signal_mux_94,
                      signal_select_306,
                      signal_select_305,
                      signal_select_304,
                      signal_select_303,
                      signal_select_302,
                      signal_select_301,
                      signal_select_300,
                      signal_select_299,
                      signal_select_298,
                      signal_select_297,
                      signal_select_296,
                      signal_select_295 };
    assign signal_select_748 = sample[0:0];
    assign d$wait_index = word[4:0];
    always @* begin
        case (d$wait_index)
        0:
            wait_pin_cur <= signal_select_748;
        1:
            wait_pin_cur <= signal_select_294;
        2:
            wait_pin_cur <= signal_select_293;
        3:
            wait_pin_cur <= signal_select_292;
        4:
            wait_pin_cur <= signal_select_291;
        5:
            wait_pin_cur <= signal_select_290;
        6:
            wait_pin_cur <= signal_select_289;
        7:
            wait_pin_cur <= signal_select_288;
        8:
            wait_pin_cur <= signal_select_287;
        9:
            wait_pin_cur <= signal_select_286;
        10:
            wait_pin_cur <= signal_select_285;
        11:
            wait_pin_cur <= signal_select_284;
        12:
            wait_pin_cur <= signal_select_283;
        13:
            wait_pin_cur <= signal_select_282;
        14:
            wait_pin_cur <= signal_select_281;
        15:
            wait_pin_cur <= signal_select_280;
        16:
            wait_pin_cur <= signal_select_279;
        17:
            wait_pin_cur <= signal_select_278;
        18:
            wait_pin_cur <= signal_select_277;
        19:
            wait_pin_cur <= signal_select_276;
        20:
            wait_pin_cur <= signal_select_275;
        21:
            wait_pin_cur <= signal_select_274;
        22:
            wait_pin_cur <= signal_select_273;
        23:
            wait_pin_cur <= signal_select_272;
        24:
            wait_pin_cur <= signal_select_271;
        25:
            wait_pin_cur <= signal_select_270;
        26:
            wait_pin_cur <= signal_select_269;
        default:
            wait_pin_cur <= signal_select_268;
        endcase
    end
    assign signal_eq_64 = wait_pin_cur == d$wait_polarity;
    assign d$wait_source$binary_variant = word[6:5];
    always @* begin
        case (d$wait_source$binary_variant)
        0:
            wait_ready <= signal_eq_64;
        1:
            wait_ready <= signal_and_35;
        2:
            wait_ready <= deadline_ready;
        default:
            wait_ready <= signal_mux_84;
        endcase
    end
    assign signal_not_45 = ~ wait_ready;
    assign gnd = 1'b0;
    assign signal_eq_65 = signal_select_759 == signal_const_70;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            is_opcode$1 <= gnd;
        else
            if (ir_load)
                is_opcode$1 <= signal_eq_65;
    end
    assign wait_holds = is_opcode$1 & signal_not_45;
    assign signal_not_46 = ~ wait_holds;
    assign signal_eq_66 = signal_select_759 == signal_const_21;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            is_opcode$0 <= vdd;
        else
            if (ir_load)
                is_opcode$0 <= signal_eq_66;
    end
    assign signal_not_47 = ~ is_opcode$0;
    assign op_go = go & signal_not_47;
    assign advance = op_go & signal_not_46;
    assign signal_or_20 = advance | refill;
    assign ir_load = signal_or_20;
    assign signal_select_749 = signal_wire_43[7:3];
    assign signal_eq_67 = signal_select_749 == signal_const_61;
    assign signal_select_750 = signal_wire_43[2:0];
    assign signal_lt_6 = signal_select_750 < signal_const_1;
    assign signal_select_751 = signal_wire_43[3:3];
    assign signal_not_48 = ~ signal_select_751;
    assign signal_or_21 = signal_not_48 | signal_lt_6;
    assign signal_select_752 = signal_wire_43[5:4];
    assign signal_lt_7 = signal_select_752 < signal_const_84;
    assign signal_and_62 = signal_lt_7 & signal_or_21;
    assign signal_select_753 = signal_wire_43[7:5];
    assign signal_lt_8 = signal_select_753 < signal_const_1;
    assign signal_select_754 = signal_wire_43[4:3];
    assign signal_lt_9 = signal_select_754 < signal_const_84;
    assign signal_lt_10 = signal_const_186 < signal_select_755;
    assign signal_not_49 = ~ signal_lt_10;
    assign signal_select_755 = signal_wire_43[4:0];
    assign signal_lt_11 = signal_select_755 < signal_const_64;
    assign signal_not_50 = ~ signal_lt_11;
    assign signal_and_63 = signal_not_50 & signal_not_49;
    assign signal_eq_68 = signal_select_756 == signal_const_61;
    assign signal_eq_69 = signal_select_756 == signal_const_61;
    assign signal_const_275 = 5'b11100;
    assign signal_lt_12 = signal_select_756 < signal_const_275;
    assign signal_select_756 = signal_wire_43[4:0];
    assign signal_lt_13 = signal_select_756 < signal_const_275;
    assign signal_select_757 = signal_wire_43[6:5];
    always @* begin
        case (signal_select_757)
        0:
            signal_mux_269 <= signal_lt_13;
        1:
            signal_mux_269 <= signal_lt_12;
        2:
            signal_mux_269 <= signal_eq_69;
        default:
            signal_mux_269 <= signal_eq_68;
        endcase
    end
    assign signal_const_277 = 4'b1100;
    assign signal_select_758 = signal_wire_43[12:9];
    assign signal_lt_14 = signal_select_758 < signal_const_277;
    assign signal_select_759 = signal_wire_43[15:13];
    always @* begin
        case (signal_select_759)
        0:
            signal_mux_270 <= signal_lt_14;
        1:
            signal_mux_270 <= signal_mux_269;
        2:
            signal_mux_270 <= signal_and_63;
        3:
            signal_mux_270 <= signal_and_63;
        4:
            signal_mux_270 <= signal_lt_9;
        5:
            signal_mux_270 <= signal_lt_8;
        6:
            signal_mux_270 <= signal_and_62;
        default:
            signal_mux_270 <= signal_eq_67;
        endcase
    end
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            decode_ok_0 <= vdd;
        else
            if (ir_load)
                decode_ok_0 <= signal_mux_270;
    end
    assign go = issue & decode_ok_0;
    assign jmp_go = go & is_opcode$0;
    assign signal_mux_271 = jmp_go ? signal_const_64 : signal_mux_82;
    assign stall_next = start_0 ? signal_const_61 : signal_mux_271;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_21 <= signal_const_61;
        else
            signal_reg_21 <= stall_next;
    end
    assign stall_0 = signal_reg_21;
    assign signal_eq_70 = stall_0 == signal_const_61;
    assign signal_not_51 = ~ halted_0;
    assign signal_and_64 = signal_not_51 & signal_eq_70;
    assign issue = signal_and_64 & signal_not_20;
    assign signal_and_65 = issue & signal_not_19;
    assign signal_mux_272 = signal_and_65 ? vdd : signal_mux_80;
    assign signal_wire_38 = stop;
    assign signal_mux_273 = signal_wire_38 ? vdd : signal_mux_272;
    assign signal_wire_39 = clear;
    assign signal_wire_40 = start;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            start_0 <= signal_const_3;
        else
            start_0 <= signal_wire_40;
    end
    assign halted_next = start_0 ? gnd : signal_mux_273;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_22 <= vdd;
        else
            signal_reg_22 <= halted_next;
    end
    assign halted_0 = signal_reg_22;
    assign signal_wire_41 = program_write$valid;
    assign program_write = signal_wire_41 & halted_0;
    assign vdd = 1'b1;
    assign signal_wire_42 = clock;
    sram_macro
        sram_macro
        ( .clock(signal_wire_42),
          .men(vdd),
          .wen(program_write),
          .ren(vdd),
          .addr(signal_mux_79),
          .din(signal_wire_2),
          .bm(signal_const_19),
          .dout(signal_inst_2[15:0]) );
    assign signal_wire_43 = signal_inst_2;
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            word <= signal_const_14;
        else
            if (ir_load)
                word <= signal_wire_43;
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
    always @(posedge signal_wire_42) begin
        if (signal_wire_39)
            signal_reg_23 <= signal_const_10;
        else
            if (op_go)
                signal_reg_23 <= pin_out_next;
    end
    assign pin_out_0 = signal_reg_23;
    assign d$alu_imm = d$alu_reg$binary_variant;
    assign d$in_source$binary_variant = d$out_dest$binary_variant;
    assign pin_out = pin_out_0;
    assign pin_dir = pin_dir_0;
    assign pc = pc_0;
    assign x = x_0;
    assign y = y_0;
    assign p = p_0;
    assign t = t_0;
    assign t_fraction = t_fraction_0;
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
module engines (
    clock,
    clear,
    hosts$config$side_set_count_0,
    hosts$config$side_set_base_0,
    hosts$config$side_set_pindirs_0,
    hosts$config$in_base_0,
    hosts$config$in_count_0,
    hosts$config$out_base_0,
    hosts$config$out_count_0,
    hosts$config$set_base_0,
    hosts$config$set_count_0,
    hosts$config$jmp_pin_0,
    hosts$config$capture_pin_0,
    hosts$config$capture_rising_0,
    hosts$config$in_shift_right_0,
    hosts$config$out_shift_right_0,
    hosts$config$autopush_0,
    hosts$config$push_threshold_0,
    hosts$config$autopull_0,
    hosts$config$pull_threshold_0,
    hosts$config$crc_width_0,
    hosts$config$crc_poly_0,
    hosts$config$crc_init_0,
    hosts$config$crc_reflect_0,
    hosts$config$stuff_threshold_0,
    hosts$config$stuff_level_0,
    hosts$config$wrap_bottom_0,
    hosts$config$wrap_top_0,
    hosts$config$period_fraction_0,
    hosts$start_0,
    hosts$program_write$valid_0,
    hosts$program_write$addr_0,
    hosts$program_write$data_0,
    hosts$tx$valid_0,
    hosts$tx$value_0,
    hosts$rx_pop_0,
    hosts$clear_irq_0,
    hosts$stop_0,
    hosts$flush_0,
    hosts$config$side_set_count_1,
    hosts$config$side_set_base_1,
    hosts$config$side_set_pindirs_1,
    hosts$config$in_base_1,
    hosts$config$in_count_1,
    hosts$config$out_base_1,
    hosts$config$out_count_1,
    hosts$config$set_base_1,
    hosts$config$set_count_1,
    hosts$config$jmp_pin_1,
    hosts$config$capture_pin_1,
    hosts$config$capture_rising_1,
    hosts$config$in_shift_right_1,
    hosts$config$out_shift_right_1,
    hosts$config$autopush_1,
    hosts$config$push_threshold_1,
    hosts$config$autopull_1,
    hosts$config$pull_threshold_1,
    hosts$config$crc_width_1,
    hosts$config$crc_poly_1,
    hosts$config$crc_init_1,
    hosts$config$crc_reflect_1,
    hosts$config$stuff_threshold_1,
    hosts$config$stuff_level_1,
    hosts$config$wrap_bottom_1,
    hosts$config$wrap_top_1,
    hosts$config$period_fraction_1,
    hosts$start_1,
    hosts$program_write$valid_1,
    hosts$program_write$addr_1,
    hosts$program_write$data_1,
    hosts$tx$valid_1,
    hosts$tx$value_1,
    hosts$rx_pop_1,
    hosts$clear_irq_1,
    hosts$stop_1,
    hosts$flush_1,
    pads,
    engines$pin_out_0,
    engines$pin_dir_0,
    engines$pc_0,
    engines$x_0,
    engines$y_0,
    engines$p_0,
    engines$t_0,
    engines$t_fraction_0,
    engines$osr_0,
    engines$osr_count_0,
    engines$isr_0,
    engines$isr_count_0,
    engines$now_0,
    engines$stall_0,
    engines$halted_0,
    engines$irq_0,
    engines$fault$underflow_0,
    engines$fault$overflow_0,
    engines$fault$missed_deadline_0,
    engines$fault$decode_0,
    engines$capture_0,
    engines$capture_armed_0,
    engines$tx_level_0,
    engines$rx_level_0,
    engines$rx_head_0,
    engines$instruction_0,
    engines$decode_ok_0,
    engines$opcode_onehot_0,
    engines$crc_0,
    engines$stuff_run_0,
    engines$pin_out_1,
    engines$pin_dir_1,
    engines$pc_1,
    engines$x_1,
    engines$y_1,
    engines$p_1,
    engines$t_1,
    engines$t_fraction_1,
    engines$osr_1,
    engines$osr_count_1,
    engines$isr_1,
    engines$isr_count_1,
    engines$now_1,
    engines$stall_1,
    engines$halted_1,
    engines$irq_1,
    engines$fault$underflow_1,
    engines$fault$overflow_1,
    engines$fault$missed_deadline_1,
    engines$fault$decode_1,
    engines$capture_1,
    engines$capture_armed_1,
    engines$tx_level_1,
    engines$rx_level_1,
    engines$rx_head_1,
    engines$instruction_1,
    engines$decode_ok_1,
    engines$opcode_onehot_1,
    engines$crc_1,
    engines$stuff_run_1,
    pin_out,
    pin_dir
);

    input clock;
    input clear;
    input [1:0] hosts$config$side_set_count_0;
    input [4:0] hosts$config$side_set_base_0;
    input hosts$config$side_set_pindirs_0;
    input [4:0] hosts$config$in_base_0;
    input [4:0] hosts$config$in_count_0;
    input [4:0] hosts$config$out_base_0;
    input [4:0] hosts$config$out_count_0;
    input [4:0] hosts$config$set_base_0;
    input [2:0] hosts$config$set_count_0;
    input [4:0] hosts$config$jmp_pin_0;
    input [4:0] hosts$config$capture_pin_0;
    input hosts$config$capture_rising_0;
    input hosts$config$in_shift_right_0;
    input hosts$config$out_shift_right_0;
    input hosts$config$autopush_0;
    input [4:0] hosts$config$push_threshold_0;
    input hosts$config$autopull_0;
    input [4:0] hosts$config$pull_threshold_0;
    input [4:0] hosts$config$crc_width_0;
    input [15:0] hosts$config$crc_poly_0;
    input [15:0] hosts$config$crc_init_0;
    input hosts$config$crc_reflect_0;
    input [4:0] hosts$config$stuff_threshold_0;
    input hosts$config$stuff_level_0;
    input [8:0] hosts$config$wrap_bottom_0;
    input [8:0] hosts$config$wrap_top_0;
    input [15:0] hosts$config$period_fraction_0;
    input hosts$start_0;
    input hosts$program_write$valid_0;
    input [8:0] hosts$program_write$addr_0;
    input [15:0] hosts$program_write$data_0;
    input hosts$tx$valid_0;
    input [15:0] hosts$tx$value_0;
    input hosts$rx_pop_0;
    input hosts$clear_irq_0;
    input hosts$stop_0;
    input hosts$flush_0;
    input [1:0] hosts$config$side_set_count_1;
    input [4:0] hosts$config$side_set_base_1;
    input hosts$config$side_set_pindirs_1;
    input [4:0] hosts$config$in_base_1;
    input [4:0] hosts$config$in_count_1;
    input [4:0] hosts$config$out_base_1;
    input [4:0] hosts$config$out_count_1;
    input [4:0] hosts$config$set_base_1;
    input [2:0] hosts$config$set_count_1;
    input [4:0] hosts$config$jmp_pin_1;
    input [4:0] hosts$config$capture_pin_1;
    input hosts$config$capture_rising_1;
    input hosts$config$in_shift_right_1;
    input hosts$config$out_shift_right_1;
    input hosts$config$autopush_1;
    input [4:0] hosts$config$push_threshold_1;
    input hosts$config$autopull_1;
    input [4:0] hosts$config$pull_threshold_1;
    input [4:0] hosts$config$crc_width_1;
    input [15:0] hosts$config$crc_poly_1;
    input [15:0] hosts$config$crc_init_1;
    input hosts$config$crc_reflect_1;
    input [4:0] hosts$config$stuff_threshold_1;
    input hosts$config$stuff_level_1;
    input [8:0] hosts$config$wrap_bottom_1;
    input [8:0] hosts$config$wrap_top_1;
    input [15:0] hosts$config$period_fraction_1;
    input hosts$start_1;
    input hosts$program_write$valid_1;
    input [8:0] hosts$program_write$addr_1;
    input [15:0] hosts$program_write$data_1;
    input hosts$tx$valid_1;
    input [15:0] hosts$tx$value_1;
    input hosts$rx_pop_1;
    input hosts$clear_irq_1;
    input hosts$stop_1;
    input hosts$flush_1;
    input [19:0] pads;
    output [27:0] engines$pin_out_0;
    output [27:0] engines$pin_dir_0;
    output [8:0] engines$pc_0;
    output [15:0] engines$x_0;
    output [15:0] engines$y_0;
    output [15:0] engines$p_0;
    output [23:0] engines$t_0;
    output [15:0] engines$t_fraction_0;
    output [15:0] engines$osr_0;
    output [4:0] engines$osr_count_0;
    output [15:0] engines$isr_0;
    output [4:0] engines$isr_count_0;
    output [23:0] engines$now_0;
    output [4:0] engines$stall_0;
    output engines$halted_0;
    output engines$irq_0;
    output engines$fault$underflow_0;
    output engines$fault$overflow_0;
    output engines$fault$missed_deadline_0;
    output engines$fault$decode_0;
    output [23:0] engines$capture_0;
    output engines$capture_armed_0;
    output [3:0] engines$tx_level_0;
    output [3:0] engines$rx_level_0;
    output [15:0] engines$rx_head_0;
    output [15:0] engines$instruction_0;
    output engines$decode_ok_0;
    output [7:0] engines$opcode_onehot_0;
    output [15:0] engines$crc_0;
    output [4:0] engines$stuff_run_0;
    output [27:0] engines$pin_out_1;
    output [27:0] engines$pin_dir_1;
    output [8:0] engines$pc_1;
    output [15:0] engines$x_1;
    output [15:0] engines$y_1;
    output [15:0] engines$p_1;
    output [23:0] engines$t_1;
    output [15:0] engines$t_fraction_1;
    output [15:0] engines$osr_1;
    output [4:0] engines$osr_count_1;
    output [15:0] engines$isr_1;
    output [4:0] engines$isr_count_1;
    output [23:0] engines$now_1;
    output [4:0] engines$stall_1;
    output engines$halted_1;
    output engines$irq_1;
    output engines$fault$underflow_1;
    output engines$fault$overflow_1;
    output engines$fault$missed_deadline_1;
    output engines$fault$decode_1;
    output [23:0] engines$capture_1;
    output engines$capture_armed_1;
    output [3:0] engines$tx_level_1;
    output [3:0] engines$rx_level_1;
    output [15:0] engines$rx_head_1;
    output [15:0] engines$instruction_1;
    output engines$decode_ok_1;
    output [7:0] engines$opcode_onehot_1;
    output [15:0] engines$crc_1;
    output [4:0] engines$stuff_run_1;
    output [19:0] pin_out;
    output [19:0] pin_dir;

    wire [27:0] signal_or;
    wire [19:0] signal_select;
    wire [27:0] signal_or_1;
    wire [27:0] signal_and;
    wire [27:0] signal_const;
    wire [27:0] signal_or_2;
    wire [27:0] signal_and_1;
    wire [27:0] signal_or_3;
    wire [19:0] signal_select_1;
    wire [4:0] signal_select_2;
    wire [4:0] signal_wire;
    wire [15:0] signal_select_3;
    wire [15:0] signal_wire_1;
    wire [7:0] signal_select_4;
    wire [7:0] signal_wire_2;
    wire signal_select_5;
    wire signal_wire_3;
    wire [15:0] signal_select_6;
    wire [15:0] signal_wire_4;
    wire [15:0] signal_select_7;
    wire [15:0] signal_wire_5;
    wire [3:0] signal_select_8;
    wire [3:0] signal_wire_6;
    wire [3:0] signal_select_9;
    wire [3:0] signal_wire_7;
    wire signal_select_10;
    wire signal_wire_8;
    wire [23:0] signal_select_11;
    wire [23:0] signal_wire_9;
    wire signal_select_12;
    wire signal_wire_10;
    wire signal_select_13;
    wire signal_wire_11;
    wire signal_select_14;
    wire signal_wire_12;
    wire signal_select_15;
    wire signal_wire_13;
    wire signal_select_16;
    wire signal_wire_14;
    wire signal_select_17;
    wire signal_wire_15;
    wire [4:0] signal_select_18;
    wire [4:0] signal_wire_16;
    wire [23:0] signal_select_19;
    wire [23:0] signal_wire_17;
    wire [4:0] signal_select_20;
    wire [4:0] signal_wire_18;
    wire [15:0] signal_select_21;
    wire [15:0] signal_wire_19;
    wire [4:0] signal_select_22;
    wire [4:0] signal_wire_20;
    wire [15:0] signal_select_23;
    wire [15:0] signal_wire_21;
    wire [15:0] signal_select_24;
    wire [15:0] signal_wire_22;
    wire [23:0] signal_select_25;
    wire [23:0] signal_wire_23;
    wire [15:0] signal_select_26;
    wire [15:0] signal_wire_24;
    wire [15:0] signal_select_27;
    wire [15:0] signal_wire_25;
    wire [15:0] signal_select_28;
    wire [15:0] signal_wire_26;
    wire [8:0] signal_select_29;
    wire [8:0] signal_wire_27;
    wire [4:0] signal_select_30;
    wire [4:0] signal_wire_28;
    wire [15:0] signal_select_31;
    wire [15:0] signal_wire_29;
    wire [7:0] signal_select_32;
    wire [7:0] signal_wire_30;
    wire signal_select_33;
    wire signal_wire_31;
    wire [15:0] signal_select_34;
    wire [15:0] signal_wire_32;
    wire [15:0] signal_select_35;
    wire [15:0] signal_wire_33;
    wire [3:0] signal_select_36;
    wire [3:0] signal_wire_34;
    wire [3:0] signal_select_37;
    wire [3:0] signal_wire_35;
    wire signal_select_38;
    wire signal_wire_36;
    wire [23:0] signal_select_39;
    wire [23:0] signal_wire_37;
    wire signal_select_40;
    wire signal_wire_38;
    wire signal_select_41;
    wire signal_wire_39;
    wire signal_select_42;
    wire signal_wire_40;
    wire signal_select_43;
    wire signal_wire_41;
    wire signal_select_44;
    wire signal_wire_42;
    wire signal_select_45;
    wire signal_wire_43;
    wire [4:0] signal_select_46;
    wire [4:0] signal_wire_44;
    wire [23:0] signal_select_47;
    wire [23:0] signal_wire_45;
    wire [4:0] signal_select_48;
    wire [4:0] signal_wire_46;
    wire [15:0] signal_select_49;
    wire [15:0] signal_wire_47;
    wire [4:0] signal_select_50;
    wire [4:0] signal_wire_48;
    wire [15:0] signal_select_51;
    wire [15:0] signal_wire_49;
    wire [15:0] signal_select_52;
    wire [15:0] signal_wire_50;
    wire [23:0] signal_select_53;
    wire [23:0] signal_wire_51;
    wire [15:0] signal_select_54;
    wire [15:0] signal_wire_52;
    wire [15:0] signal_select_55;
    wire [15:0] signal_wire_53;
    wire [15:0] signal_select_56;
    wire [15:0] signal_wire_54;
    wire [8:0] signal_select_57;
    wire [8:0] signal_wire_55;
    wire [27:0] signal_const_1;
    wire [27:0] signal_or_4;
    wire [27:0] signal_select_58;
    wire [27:0] signal_wire_56;
    wire [27:0] signal_and_2;
    wire [27:0] signal_or_5;
    wire [27:0] signal_and_3;
    wire [27:0] signal_select_59;
    wire [27:0] signal_wire_57;
    wire [27:0] signal_not;
    wire [7:0] signal_const_3;
    wire [27:0] signal_cat;
    wire [27:0] signal_and_4;
    wire [27:0] signal_or_6;
    wire signal_wire_58;
    wire signal_wire_59;
    wire signal_wire_60;
    wire signal_wire_61;
    wire [15:0] signal_wire_62;
    wire signal_wire_63;
    wire [15:0] signal_wire_64;
    wire [8:0] signal_wire_65;
    wire signal_wire_66;
    wire signal_wire_67;
    wire [15:0] signal_wire_68;
    wire [8:0] signal_wire_69;
    wire [8:0] signal_wire_70;
    wire signal_wire_71;
    wire [4:0] signal_wire_72;
    wire signal_wire_73;
    wire [15:0] signal_wire_74;
    wire [15:0] signal_wire_75;
    wire [4:0] signal_wire_76;
    wire [4:0] signal_wire_77;
    wire signal_wire_78;
    wire [4:0] signal_wire_79;
    wire signal_wire_80;
    wire signal_wire_81;
    wire signal_wire_82;
    wire signal_wire_83;
    wire [4:0] signal_wire_84;
    wire [4:0] signal_wire_85;
    wire [2:0] signal_wire_86;
    wire [4:0] signal_wire_87;
    wire [4:0] signal_wire_88;
    wire [4:0] signal_wire_89;
    wire [4:0] signal_wire_90;
    wire [4:0] signal_wire_91;
    wire signal_wire_92;
    wire [4:0] signal_wire_93;
    wire [1:0] signal_wire_94;
    wire [324:0] signal_inst;
    wire [27:0] signal_select_60;
    wire [27:0] signal_wire_95;
    wire [27:0] signal_not_1;
    wire [19:0] signal_wire_96;
    wire [27:0] signal_cat_1;
    wire [27:0] signal_and_5;
    wire [27:0] signal_or_7;
    wire signal_wire_97;
    wire signal_wire_98;
    wire signal_wire_99;
    wire signal_wire_100;
    wire [15:0] signal_wire_101;
    wire signal_wire_102;
    wire [15:0] signal_wire_103;
    wire [8:0] signal_wire_104;
    wire signal_wire_105;
    wire signal_wire_106;
    wire [15:0] signal_wire_107;
    wire [8:0] signal_wire_108;
    wire [8:0] signal_wire_109;
    wire signal_wire_110;
    wire [4:0] signal_wire_111;
    wire signal_wire_112;
    wire [15:0] signal_wire_113;
    wire [15:0] signal_wire_114;
    wire [4:0] signal_wire_115;
    wire [4:0] signal_wire_116;
    wire signal_wire_117;
    wire [4:0] signal_wire_118;
    wire signal_wire_119;
    wire signal_wire_120;
    wire signal_wire_121;
    wire signal_wire_122;
    wire [4:0] signal_wire_123;
    wire [4:0] signal_wire_124;
    wire [2:0] signal_wire_125;
    wire [4:0] signal_wire_126;
    wire [4:0] signal_wire_127;
    wire [4:0] signal_wire_128;
    wire [4:0] signal_wire_129;
    wire [4:0] signal_wire_130;
    wire signal_wire_131;
    wire [4:0] signal_wire_132;
    wire [1:0] signal_wire_133;
    wire signal_wire_134;
    wire signal_wire_135;
    wire [324:0] signal_inst_1;
    wire [27:0] signal_select_61;
    wire [27:0] signal_wire_136;
    assign signal_or = signal_wire_57 | signal_wire_95;
    assign signal_select = signal_or[19:0];
    assign signal_or_1 = signal_wire_95 | signal_const;
    assign signal_and = signal_wire_56 & signal_or_1;
    assign signal_const = 28'b0000000000000000111111111111;
    assign signal_or_2 = signal_wire_57 | signal_const;
    assign signal_and_1 = signal_wire_136 & signal_or_2;
    assign signal_or_3 = signal_and_1 | signal_and;
    assign signal_select_1 = signal_or_3[19:0];
    assign signal_select_2 = signal_inst[324:320];
    assign signal_wire = signal_select_2;
    assign signal_select_3 = signal_inst[319:304];
    assign signal_wire_1 = signal_select_3;
    assign signal_select_4 = signal_inst[303:296];
    assign signal_wire_2 = signal_select_4;
    assign signal_select_5 = signal_inst[295:295];
    assign signal_wire_3 = signal_select_5;
    assign signal_select_6 = signal_inst[294:279];
    assign signal_wire_4 = signal_select_6;
    assign signal_select_7 = signal_inst[278:263];
    assign signal_wire_5 = signal_select_7;
    assign signal_select_8 = signal_inst[262:259];
    assign signal_wire_6 = signal_select_8;
    assign signal_select_9 = signal_inst[258:255];
    assign signal_wire_7 = signal_select_9;
    assign signal_select_10 = signal_inst[254:254];
    assign signal_wire_8 = signal_select_10;
    assign signal_select_11 = signal_inst[253:230];
    assign signal_wire_9 = signal_select_11;
    assign signal_select_12 = signal_inst[229:229];
    assign signal_wire_10 = signal_select_12;
    assign signal_select_13 = signal_inst[228:228];
    assign signal_wire_11 = signal_select_13;
    assign signal_select_14 = signal_inst[227:227];
    assign signal_wire_12 = signal_select_14;
    assign signal_select_15 = signal_inst[226:226];
    assign signal_wire_13 = signal_select_15;
    assign signal_select_16 = signal_inst[225:225];
    assign signal_wire_14 = signal_select_16;
    assign signal_select_17 = signal_inst[224:224];
    assign signal_wire_15 = signal_select_17;
    assign signal_select_18 = signal_inst[223:219];
    assign signal_wire_16 = signal_select_18;
    assign signal_select_19 = signal_inst[218:195];
    assign signal_wire_17 = signal_select_19;
    assign signal_select_20 = signal_inst[194:190];
    assign signal_wire_18 = signal_select_20;
    assign signal_select_21 = signal_inst[189:174];
    assign signal_wire_19 = signal_select_21;
    assign signal_select_22 = signal_inst[173:169];
    assign signal_wire_20 = signal_select_22;
    assign signal_select_23 = signal_inst[168:153];
    assign signal_wire_21 = signal_select_23;
    assign signal_select_24 = signal_inst[152:137];
    assign signal_wire_22 = signal_select_24;
    assign signal_select_25 = signal_inst[136:113];
    assign signal_wire_23 = signal_select_25;
    assign signal_select_26 = signal_inst[112:97];
    assign signal_wire_24 = signal_select_26;
    assign signal_select_27 = signal_inst[96:81];
    assign signal_wire_25 = signal_select_27;
    assign signal_select_28 = signal_inst[80:65];
    assign signal_wire_26 = signal_select_28;
    assign signal_select_29 = signal_inst[64:56];
    assign signal_wire_27 = signal_select_29;
    assign signal_select_30 = signal_inst_1[324:320];
    assign signal_wire_28 = signal_select_30;
    assign signal_select_31 = signal_inst_1[319:304];
    assign signal_wire_29 = signal_select_31;
    assign signal_select_32 = signal_inst_1[303:296];
    assign signal_wire_30 = signal_select_32;
    assign signal_select_33 = signal_inst_1[295:295];
    assign signal_wire_31 = signal_select_33;
    assign signal_select_34 = signal_inst_1[294:279];
    assign signal_wire_32 = signal_select_34;
    assign signal_select_35 = signal_inst_1[278:263];
    assign signal_wire_33 = signal_select_35;
    assign signal_select_36 = signal_inst_1[262:259];
    assign signal_wire_34 = signal_select_36;
    assign signal_select_37 = signal_inst_1[258:255];
    assign signal_wire_35 = signal_select_37;
    assign signal_select_38 = signal_inst_1[254:254];
    assign signal_wire_36 = signal_select_38;
    assign signal_select_39 = signal_inst_1[253:230];
    assign signal_wire_37 = signal_select_39;
    assign signal_select_40 = signal_inst_1[229:229];
    assign signal_wire_38 = signal_select_40;
    assign signal_select_41 = signal_inst_1[228:228];
    assign signal_wire_39 = signal_select_41;
    assign signal_select_42 = signal_inst_1[227:227];
    assign signal_wire_40 = signal_select_42;
    assign signal_select_43 = signal_inst_1[226:226];
    assign signal_wire_41 = signal_select_43;
    assign signal_select_44 = signal_inst_1[225:225];
    assign signal_wire_42 = signal_select_44;
    assign signal_select_45 = signal_inst_1[224:224];
    assign signal_wire_43 = signal_select_45;
    assign signal_select_46 = signal_inst_1[223:219];
    assign signal_wire_44 = signal_select_46;
    assign signal_select_47 = signal_inst_1[218:195];
    assign signal_wire_45 = signal_select_47;
    assign signal_select_48 = signal_inst_1[194:190];
    assign signal_wire_46 = signal_select_48;
    assign signal_select_49 = signal_inst_1[189:174];
    assign signal_wire_47 = signal_select_49;
    assign signal_select_50 = signal_inst_1[173:169];
    assign signal_wire_48 = signal_select_50;
    assign signal_select_51 = signal_inst_1[168:153];
    assign signal_wire_49 = signal_select_51;
    assign signal_select_52 = signal_inst_1[152:137];
    assign signal_wire_50 = signal_select_52;
    assign signal_select_53 = signal_inst_1[136:113];
    assign signal_wire_51 = signal_select_53;
    assign signal_select_54 = signal_inst_1[112:97];
    assign signal_wire_52 = signal_select_54;
    assign signal_select_55 = signal_inst_1[96:81];
    assign signal_wire_53 = signal_select_55;
    assign signal_select_56 = signal_inst_1[80:65];
    assign signal_wire_54 = signal_select_56;
    assign signal_select_57 = signal_inst_1[64:56];
    assign signal_wire_55 = signal_select_57;
    assign signal_const_1 = 28'b1111111100000000000000000000;
    assign signal_or_4 = signal_wire_95 | signal_const_1;
    assign signal_select_58 = signal_inst[27:0];
    assign signal_wire_56 = signal_select_58;
    assign signal_and_2 = signal_wire_56 & signal_or_4;
    assign signal_or_5 = signal_wire_57 | signal_const_1;
    assign signal_and_3 = signal_wire_136 & signal_or_5;
    assign signal_select_59 = signal_inst_1[55:28];
    assign signal_wire_57 = signal_select_59;
    assign signal_not = ~ signal_wire_57;
    assign signal_const_3 = 8'b00000000;
    assign signal_cat = { signal_const_3,
                          signal_wire_96 };
    assign signal_and_4 = signal_cat & signal_not;
    assign signal_or_6 = signal_and_4 | signal_and_3;
    assign signal_wire_58 = hosts$flush_1;
    assign signal_wire_59 = hosts$stop_1;
    assign signal_wire_60 = hosts$clear_irq_1;
    assign signal_wire_61 = hosts$rx_pop_1;
    assign signal_wire_62 = hosts$tx$value_1;
    assign signal_wire_63 = hosts$tx$valid_1;
    assign signal_wire_64 = hosts$program_write$data_1;
    assign signal_wire_65 = hosts$program_write$addr_1;
    assign signal_wire_66 = hosts$program_write$valid_1;
    assign signal_wire_67 = hosts$start_1;
    assign signal_wire_68 = hosts$config$period_fraction_1;
    assign signal_wire_69 = hosts$config$wrap_top_1;
    assign signal_wire_70 = hosts$config$wrap_bottom_1;
    assign signal_wire_71 = hosts$config$stuff_level_1;
    assign signal_wire_72 = hosts$config$stuff_threshold_1;
    assign signal_wire_73 = hosts$config$crc_reflect_1;
    assign signal_wire_74 = hosts$config$crc_init_1;
    assign signal_wire_75 = hosts$config$crc_poly_1;
    assign signal_wire_76 = hosts$config$crc_width_1;
    assign signal_wire_77 = hosts$config$pull_threshold_1;
    assign signal_wire_78 = hosts$config$autopull_1;
    assign signal_wire_79 = hosts$config$push_threshold_1;
    assign signal_wire_80 = hosts$config$autopush_1;
    assign signal_wire_81 = hosts$config$out_shift_right_1;
    assign signal_wire_82 = hosts$config$in_shift_right_1;
    assign signal_wire_83 = hosts$config$capture_rising_1;
    assign signal_wire_84 = hosts$config$capture_pin_1;
    assign signal_wire_85 = hosts$config$jmp_pin_1;
    assign signal_wire_86 = hosts$config$set_count_1;
    assign signal_wire_87 = hosts$config$set_base_1;
    assign signal_wire_88 = hosts$config$out_count_1;
    assign signal_wire_89 = hosts$config$out_base_1;
    assign signal_wire_90 = hosts$config$in_count_1;
    assign signal_wire_91 = hosts$config$in_base_1;
    assign signal_wire_92 = hosts$config$side_set_pindirs_1;
    assign signal_wire_93 = hosts$config$side_set_base_1;
    assign signal_wire_94 = hosts$config$side_set_count_1;
    engine
        engine_1
        ( .clock(signal_wire_135),
          .clear(signal_wire_134),
          .config$side_set_count(signal_wire_94),
          .config$side_set_base(signal_wire_93),
          .config$side_set_pindirs(signal_wire_92),
          .config$in_base(signal_wire_91),
          .config$in_count(signal_wire_90),
          .config$out_base(signal_wire_89),
          .config$out_count(signal_wire_88),
          .config$set_base(signal_wire_87),
          .config$set_count(signal_wire_86),
          .config$jmp_pin(signal_wire_85),
          .config$capture_pin(signal_wire_84),
          .config$capture_rising(signal_wire_83),
          .config$in_shift_right(signal_wire_82),
          .config$out_shift_right(signal_wire_81),
          .config$autopush(signal_wire_80),
          .config$push_threshold(signal_wire_79),
          .config$autopull(signal_wire_78),
          .config$pull_threshold(signal_wire_77),
          .config$crc_width(signal_wire_76),
          .config$crc_poly(signal_wire_75),
          .config$crc_init(signal_wire_74),
          .config$crc_reflect(signal_wire_73),
          .config$stuff_threshold(signal_wire_72),
          .config$stuff_level(signal_wire_71),
          .config$wrap_bottom(signal_wire_70),
          .config$wrap_top(signal_wire_69),
          .config$period_fraction(signal_wire_68),
          .start(signal_wire_67),
          .program_write$valid(signal_wire_66),
          .program_write$addr(signal_wire_65),
          .program_write$data(signal_wire_64),
          .tx$valid(signal_wire_63),
          .tx$value(signal_wire_62),
          .rx_pop(signal_wire_61),
          .clear_irq(signal_wire_60),
          .stop(signal_wire_59),
          .flush(signal_wire_58),
          .inputs(signal_or_6),
          .pin_out(signal_inst[27:0]),
          .pin_dir(signal_inst[55:28]),
          .pc(signal_inst[64:56]),
          .x(signal_inst[80:65]),
          .y(signal_inst[96:81]),
          .p(signal_inst[112:97]),
          .t(signal_inst[136:113]),
          .t_fraction(signal_inst[152:137]),
          .osr(signal_inst[168:153]),
          .osr_count(signal_inst[173:169]),
          .isr(signal_inst[189:174]),
          .isr_count(signal_inst[194:190]),
          .now(signal_inst[218:195]),
          .stall(signal_inst[223:219]),
          .halted(signal_inst[224:224]),
          .irq(signal_inst[225:225]),
          .fault$underflow(signal_inst[226:226]),
          .fault$overflow(signal_inst[227:227]),
          .fault$missed_deadline(signal_inst[228:228]),
          .fault$decode(signal_inst[229:229]),
          .capture(signal_inst[253:230]),
          .capture_armed(signal_inst[254:254]),
          .tx_level(signal_inst[258:255]),
          .rx_level(signal_inst[262:259]),
          .rx_head(signal_inst[278:263]),
          .instruction(signal_inst[294:279]),
          .decode_ok(signal_inst[295:295]),
          .opcode_onehot(signal_inst[303:296]),
          .crc(signal_inst[319:304]),
          .stuff_run(signal_inst[324:320]) );
    assign signal_select_60 = signal_inst[55:28];
    assign signal_wire_95 = signal_select_60;
    assign signal_not_1 = ~ signal_wire_95;
    assign signal_wire_96 = pads;
    assign signal_cat_1 = { signal_const_3,
                            signal_wire_96 };
    assign signal_and_5 = signal_cat_1 & signal_not_1;
    assign signal_or_7 = signal_and_5 | signal_and_2;
    assign signal_wire_97 = hosts$flush_0;
    assign signal_wire_98 = hosts$stop_0;
    assign signal_wire_99 = hosts$clear_irq_0;
    assign signal_wire_100 = hosts$rx_pop_0;
    assign signal_wire_101 = hosts$tx$value_0;
    assign signal_wire_102 = hosts$tx$valid_0;
    assign signal_wire_103 = hosts$program_write$data_0;
    assign signal_wire_104 = hosts$program_write$addr_0;
    assign signal_wire_105 = hosts$program_write$valid_0;
    assign signal_wire_106 = hosts$start_0;
    assign signal_wire_107 = hosts$config$period_fraction_0;
    assign signal_wire_108 = hosts$config$wrap_top_0;
    assign signal_wire_109 = hosts$config$wrap_bottom_0;
    assign signal_wire_110 = hosts$config$stuff_level_0;
    assign signal_wire_111 = hosts$config$stuff_threshold_0;
    assign signal_wire_112 = hosts$config$crc_reflect_0;
    assign signal_wire_113 = hosts$config$crc_init_0;
    assign signal_wire_114 = hosts$config$crc_poly_0;
    assign signal_wire_115 = hosts$config$crc_width_0;
    assign signal_wire_116 = hosts$config$pull_threshold_0;
    assign signal_wire_117 = hosts$config$autopull_0;
    assign signal_wire_118 = hosts$config$push_threshold_0;
    assign signal_wire_119 = hosts$config$autopush_0;
    assign signal_wire_120 = hosts$config$out_shift_right_0;
    assign signal_wire_121 = hosts$config$in_shift_right_0;
    assign signal_wire_122 = hosts$config$capture_rising_0;
    assign signal_wire_123 = hosts$config$capture_pin_0;
    assign signal_wire_124 = hosts$config$jmp_pin_0;
    assign signal_wire_125 = hosts$config$set_count_0;
    assign signal_wire_126 = hosts$config$set_base_0;
    assign signal_wire_127 = hosts$config$out_count_0;
    assign signal_wire_128 = hosts$config$out_base_0;
    assign signal_wire_129 = hosts$config$in_count_0;
    assign signal_wire_130 = hosts$config$in_base_0;
    assign signal_wire_131 = hosts$config$side_set_pindirs_0;
    assign signal_wire_132 = hosts$config$side_set_base_0;
    assign signal_wire_133 = hosts$config$side_set_count_0;
    assign signal_wire_134 = clear;
    assign signal_wire_135 = clock;
    engine
        engine_0
        ( .clock(signal_wire_135),
          .clear(signal_wire_134),
          .config$side_set_count(signal_wire_133),
          .config$side_set_base(signal_wire_132),
          .config$side_set_pindirs(signal_wire_131),
          .config$in_base(signal_wire_130),
          .config$in_count(signal_wire_129),
          .config$out_base(signal_wire_128),
          .config$out_count(signal_wire_127),
          .config$set_base(signal_wire_126),
          .config$set_count(signal_wire_125),
          .config$jmp_pin(signal_wire_124),
          .config$capture_pin(signal_wire_123),
          .config$capture_rising(signal_wire_122),
          .config$in_shift_right(signal_wire_121),
          .config$out_shift_right(signal_wire_120),
          .config$autopush(signal_wire_119),
          .config$push_threshold(signal_wire_118),
          .config$autopull(signal_wire_117),
          .config$pull_threshold(signal_wire_116),
          .config$crc_width(signal_wire_115),
          .config$crc_poly(signal_wire_114),
          .config$crc_init(signal_wire_113),
          .config$crc_reflect(signal_wire_112),
          .config$stuff_threshold(signal_wire_111),
          .config$stuff_level(signal_wire_110),
          .config$wrap_bottom(signal_wire_109),
          .config$wrap_top(signal_wire_108),
          .config$period_fraction(signal_wire_107),
          .start(signal_wire_106),
          .program_write$valid(signal_wire_105),
          .program_write$addr(signal_wire_104),
          .program_write$data(signal_wire_103),
          .tx$valid(signal_wire_102),
          .tx$value(signal_wire_101),
          .rx_pop(signal_wire_100),
          .clear_irq(signal_wire_99),
          .stop(signal_wire_98),
          .flush(signal_wire_97),
          .inputs(signal_or_7),
          .pin_out(signal_inst_1[27:0]),
          .pin_dir(signal_inst_1[55:28]),
          .pc(signal_inst_1[64:56]),
          .x(signal_inst_1[80:65]),
          .y(signal_inst_1[96:81]),
          .p(signal_inst_1[112:97]),
          .t(signal_inst_1[136:113]),
          .t_fraction(signal_inst_1[152:137]),
          .osr(signal_inst_1[168:153]),
          .osr_count(signal_inst_1[173:169]),
          .isr(signal_inst_1[189:174]),
          .isr_count(signal_inst_1[194:190]),
          .now(signal_inst_1[218:195]),
          .stall(signal_inst_1[223:219]),
          .halted(signal_inst_1[224:224]),
          .irq(signal_inst_1[225:225]),
          .fault$underflow(signal_inst_1[226:226]),
          .fault$overflow(signal_inst_1[227:227]),
          .fault$missed_deadline(signal_inst_1[228:228]),
          .fault$decode(signal_inst_1[229:229]),
          .capture(signal_inst_1[253:230]),
          .capture_armed(signal_inst_1[254:254]),
          .tx_level(signal_inst_1[258:255]),
          .rx_level(signal_inst_1[262:259]),
          .rx_head(signal_inst_1[278:263]),
          .instruction(signal_inst_1[294:279]),
          .decode_ok(signal_inst_1[295:295]),
          .opcode_onehot(signal_inst_1[303:296]),
          .crc(signal_inst_1[319:304]),
          .stuff_run(signal_inst_1[324:320]) );
    assign signal_select_61 = signal_inst_1[27:0];
    assign signal_wire_136 = signal_select_61;
    assign engines$pin_out_0 = signal_wire_136;
    assign engines$pin_dir_0 = signal_wire_57;
    assign engines$pc_0 = signal_wire_55;
    assign engines$x_0 = signal_wire_54;
    assign engines$y_0 = signal_wire_53;
    assign engines$p_0 = signal_wire_52;
    assign engines$t_0 = signal_wire_51;
    assign engines$t_fraction_0 = signal_wire_50;
    assign engines$osr_0 = signal_wire_49;
    assign engines$osr_count_0 = signal_wire_48;
    assign engines$isr_0 = signal_wire_47;
    assign engines$isr_count_0 = signal_wire_46;
    assign engines$now_0 = signal_wire_45;
    assign engines$stall_0 = signal_wire_44;
    assign engines$halted_0 = signal_wire_43;
    assign engines$irq_0 = signal_wire_42;
    assign engines$fault$underflow_0 = signal_wire_41;
    assign engines$fault$overflow_0 = signal_wire_40;
    assign engines$fault$missed_deadline_0 = signal_wire_39;
    assign engines$fault$decode_0 = signal_wire_38;
    assign engines$capture_0 = signal_wire_37;
    assign engines$capture_armed_0 = signal_wire_36;
    assign engines$tx_level_0 = signal_wire_35;
    assign engines$rx_level_0 = signal_wire_34;
    assign engines$rx_head_0 = signal_wire_33;
    assign engines$instruction_0 = signal_wire_32;
    assign engines$decode_ok_0 = signal_wire_31;
    assign engines$opcode_onehot_0 = signal_wire_30;
    assign engines$crc_0 = signal_wire_29;
    assign engines$stuff_run_0 = signal_wire_28;
    assign engines$pin_out_1 = signal_wire_56;
    assign engines$pin_dir_1 = signal_wire_95;
    assign engines$pc_1 = signal_wire_27;
    assign engines$x_1 = signal_wire_26;
    assign engines$y_1 = signal_wire_25;
    assign engines$p_1 = signal_wire_24;
    assign engines$t_1 = signal_wire_23;
    assign engines$t_fraction_1 = signal_wire_22;
    assign engines$osr_1 = signal_wire_21;
    assign engines$osr_count_1 = signal_wire_20;
    assign engines$isr_1 = signal_wire_19;
    assign engines$isr_count_1 = signal_wire_18;
    assign engines$now_1 = signal_wire_17;
    assign engines$stall_1 = signal_wire_16;
    assign engines$halted_1 = signal_wire_15;
    assign engines$irq_1 = signal_wire_14;
    assign engines$fault$underflow_1 = signal_wire_13;
    assign engines$fault$overflow_1 = signal_wire_12;
    assign engines$fault$missed_deadline_1 = signal_wire_11;
    assign engines$fault$decode_1 = signal_wire_10;
    assign engines$capture_1 = signal_wire_9;
    assign engines$capture_armed_1 = signal_wire_8;
    assign engines$tx_level_1 = signal_wire_7;
    assign engines$rx_level_1 = signal_wire_6;
    assign engines$rx_head_1 = signal_wire_5;
    assign engines$instruction_1 = signal_wire_4;
    assign engines$decode_ok_1 = signal_wire_3;
    assign engines$opcode_onehot_1 = signal_wire_2;
    assign engines$crc_1 = signal_wire_1;
    assign engines$stuff_run_1 = signal_wire;
    assign pin_out = signal_select_1;
    assign pin_dir = signal_select;

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
    status$pc_0,
    status$now_0,
    status$capture_0,
    status$halted_0,
    status$irq_0,
    status$fault$underflow_0,
    status$fault$overflow_0,
    status$fault$missed_deadline_0,
    status$fault$decode_0,
    status$tx_level_0,
    status$rx_level_0,
    status$rx_head_0,
    status$pc_1,
    status$now_1,
    status$capture_1,
    status$halted_1,
    status$irq_1,
    status$fault$underflow_1,
    status$fault$overflow_1,
    status$fault$missed_deadline_1,
    status$fault$decode_1,
    status$tx_level_1,
    status$rx_level_1,
    status$rx_head_1,
    miso,
    engines$config$side_set_count_0,
    engines$config$side_set_base_0,
    engines$config$side_set_pindirs_0,
    engines$config$in_base_0,
    engines$config$in_count_0,
    engines$config$out_base_0,
    engines$config$out_count_0,
    engines$config$set_base_0,
    engines$config$set_count_0,
    engines$config$jmp_pin_0,
    engines$config$capture_pin_0,
    engines$config$capture_rising_0,
    engines$config$in_shift_right_0,
    engines$config$out_shift_right_0,
    engines$config$autopush_0,
    engines$config$push_threshold_0,
    engines$config$autopull_0,
    engines$config$pull_threshold_0,
    engines$config$crc_width_0,
    engines$config$crc_poly_0,
    engines$config$crc_init_0,
    engines$config$crc_reflect_0,
    engines$config$stuff_threshold_0,
    engines$config$stuff_level_0,
    engines$config$wrap_bottom_0,
    engines$config$wrap_top_0,
    engines$config$period_fraction_0,
    engines$start_0,
    engines$program_write$valid_0,
    engines$program_write$addr_0,
    engines$program_write$data_0,
    engines$tx$valid_0,
    engines$tx$value_0,
    engines$rx_pop_0,
    engines$clear_irq_0,
    engines$stop_0,
    engines$flush_0,
    engines$config$side_set_count_1,
    engines$config$side_set_base_1,
    engines$config$side_set_pindirs_1,
    engines$config$in_base_1,
    engines$config$in_count_1,
    engines$config$out_base_1,
    engines$config$out_count_1,
    engines$config$set_base_1,
    engines$config$set_count_1,
    engines$config$jmp_pin_1,
    engines$config$capture_pin_1,
    engines$config$capture_rising_1,
    engines$config$in_shift_right_1,
    engines$config$out_shift_right_1,
    engines$config$autopush_1,
    engines$config$push_threshold_1,
    engines$config$autopull_1,
    engines$config$pull_threshold_1,
    engines$config$crc_width_1,
    engines$config$crc_poly_1,
    engines$config$crc_init_1,
    engines$config$crc_reflect_1,
    engines$config$stuff_threshold_1,
    engines$config$stuff_level_1,
    engines$config$wrap_bottom_1,
    engines$config$wrap_top_1,
    engines$config$period_fraction_1,
    engines$start_1,
    engines$program_write$valid_1,
    engines$program_write$addr_1,
    engines$program_write$data_1,
    engines$tx$valid_1,
    engines$tx$value_1,
    engines$rx_pop_1,
    engines$clear_irq_1,
    engines$stop_1,
    engines$flush_1
);

    input clock;
    input clear;
    input sck;
    input mosi;
    input cs_n;
    input [8:0] status$pc_0;
    input [23:0] status$now_0;
    input [23:0] status$capture_0;
    input status$halted_0;
    input status$irq_0;
    input status$fault$underflow_0;
    input status$fault$overflow_0;
    input status$fault$missed_deadline_0;
    input status$fault$decode_0;
    input [3:0] status$tx_level_0;
    input [3:0] status$rx_level_0;
    input [15:0] status$rx_head_0;
    input [8:0] status$pc_1;
    input [23:0] status$now_1;
    input [23:0] status$capture_1;
    input status$halted_1;
    input status$irq_1;
    input status$fault$underflow_1;
    input status$fault$overflow_1;
    input status$fault$missed_deadline_1;
    input status$fault$decode_1;
    input [3:0] status$tx_level_1;
    input [3:0] status$rx_level_1;
    input [15:0] status$rx_head_1;
    output miso;
    output [1:0] engines$config$side_set_count_0;
    output [4:0] engines$config$side_set_base_0;
    output engines$config$side_set_pindirs_0;
    output [4:0] engines$config$in_base_0;
    output [4:0] engines$config$in_count_0;
    output [4:0] engines$config$out_base_0;
    output [4:0] engines$config$out_count_0;
    output [4:0] engines$config$set_base_0;
    output [2:0] engines$config$set_count_0;
    output [4:0] engines$config$jmp_pin_0;
    output [4:0] engines$config$capture_pin_0;
    output engines$config$capture_rising_0;
    output engines$config$in_shift_right_0;
    output engines$config$out_shift_right_0;
    output engines$config$autopush_0;
    output [4:0] engines$config$push_threshold_0;
    output engines$config$autopull_0;
    output [4:0] engines$config$pull_threshold_0;
    output [4:0] engines$config$crc_width_0;
    output [15:0] engines$config$crc_poly_0;
    output [15:0] engines$config$crc_init_0;
    output engines$config$crc_reflect_0;
    output [4:0] engines$config$stuff_threshold_0;
    output engines$config$stuff_level_0;
    output [8:0] engines$config$wrap_bottom_0;
    output [8:0] engines$config$wrap_top_0;
    output [15:0] engines$config$period_fraction_0;
    output engines$start_0;
    output engines$program_write$valid_0;
    output [8:0] engines$program_write$addr_0;
    output [15:0] engines$program_write$data_0;
    output engines$tx$valid_0;
    output [15:0] engines$tx$value_0;
    output engines$rx_pop_0;
    output engines$clear_irq_0;
    output engines$stop_0;
    output engines$flush_0;
    output [1:0] engines$config$side_set_count_1;
    output [4:0] engines$config$side_set_base_1;
    output engines$config$side_set_pindirs_1;
    output [4:0] engines$config$in_base_1;
    output [4:0] engines$config$in_count_1;
    output [4:0] engines$config$out_base_1;
    output [4:0] engines$config$out_count_1;
    output [4:0] engines$config$set_base_1;
    output [2:0] engines$config$set_count_1;
    output [4:0] engines$config$jmp_pin_1;
    output [4:0] engines$config$capture_pin_1;
    output engines$config$capture_rising_1;
    output engines$config$in_shift_right_1;
    output engines$config$out_shift_right_1;
    output engines$config$autopush_1;
    output [4:0] engines$config$push_threshold_1;
    output engines$config$autopull_1;
    output [4:0] engines$config$pull_threshold_1;
    output [4:0] engines$config$crc_width_1;
    output [15:0] engines$config$crc_poly_1;
    output [15:0] engines$config$crc_init_1;
    output engines$config$crc_reflect_1;
    output [4:0] engines$config$stuff_threshold_1;
    output engines$config$stuff_level_1;
    output [8:0] engines$config$wrap_bottom_1;
    output [8:0] engines$config$wrap_top_1;
    output [15:0] engines$config$period_fraction_1;
    output engines$start_1;
    output engines$program_write$valid_1;
    output [8:0] engines$program_write$addr_1;
    output [15:0] engines$program_write$data_1;
    output engines$tx$valid_1;
    output [15:0] engines$tx$value_1;
    output engines$rx_pop_1;
    output engines$clear_irq_1;
    output engines$stop_1;
    output engines$flush_1;

    wire signal_const;
    wire signal_eq;
    wire signal_select;
    wire [6:0] signal_const_1;
    wire signal_eq_1;
    wire signal_and;
    wire signal_and_1;
    wire signal_and_2;
    wire signal_eq_2;
    wire signal_select_1;
    wire signal_eq_3;
    wire signal_and_3;
    wire signal_and_4;
    wire signal_and_5;
    wire signal_eq_4;
    wire signal_select_2;
    wire signal_eq_5;
    wire signal_and_6;
    wire signal_and_7;
    wire signal_and_8;
    wire signal_eq_6;
    wire [6:0] signal_const_7;
    wire signal_eq_7;
    wire signal_and_9;
    wire signal_and_10;
    wire signal_eq_8;
    wire [6:0] signal_const_9;
    wire signal_eq_9;
    wire signal_and_11;
    wire signal_and_12;
    wire signal_eq_10;
    wire [6:0] signal_const_11;
    wire signal_eq_11;
    wire signal_and_13;
    wire signal_and_14;
    wire signal_eq_12;
    wire signal_select_3;
    wire signal_eq_13;
    wire signal_and_15;
    wire signal_and_16;
    wire signal_and_17;
    wire signal_const_14;
    wire signal_eq_14;
    wire signal_select_4;
    wire signal_eq_15;
    wire signal_and_18;
    wire signal_and_19;
    wire signal_and_20;
    wire signal_eq_16;
    wire signal_select_5;
    wire signal_eq_17;
    wire signal_and_21;
    wire signal_and_22;
    wire signal_and_23;
    wire signal_eq_18;
    wire signal_select_6;
    wire signal_eq_19;
    wire signal_and_24;
    wire signal_and_25;
    wire signal_and_26;
    wire signal_eq_20;
    wire signal_eq_21;
    wire signal_and_27;
    wire signal_and_28;
    wire signal_eq_22;
    wire signal_eq_23;
    wire signal_and_29;
    wire signal_and_30;
    wire signal_eq_24;
    wire signal_eq_25;
    wire signal_and_31;
    wire signal_and_32;
    wire signal_eq_26;
    wire signal_select_7;
    wire signal_eq_27;
    wire signal_and_33;
    wire signal_and_34;
    wire signal_and_35;
    wire [7:0] signal_select_8;
    wire [15:0] signal_const_28;
    wire [15:0] signal_cat;
    wire [15:0] signal_cat_1;
    wire [14:0] signal_const_35;
    wire [15:0] signal_cat_2;
    wire [10:0] signal_const_37;
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
    wire [12:0] signal_const_63;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_cat_16;
    wire [15:0] signal_cat_17;
    wire [15:0] signal_cat_18;
    wire [15:0] signal_cat_19;
    wire [15:0] signal_cat_20;
    wire [15:0] signal_cat_21;
    wire [15:0] signal_cat_22;
    wire [13:0] signal_const_79;
    wire [15:0] signal_cat_23;
    wire [15:0] signal_cat_24;
    wire [15:0] signal_cat_25;
    wire [7:0] signal_select_9;
    wire [7:0] signal_const_86;
    wire [15:0] signal_cat_26;
    wire [15:0] signal_select_10;
    wire [7:0] signal_select_11;
    wire [15:0] signal_cat_27;
    wire [15:0] signal_select_12;
    wire [15:0] signal_cat_28;
    reg [15:0] read_value;
    wire signal_eq_28;
    wire [6:0] signal_const_98;
    wire signal_eq_29;
    wire signal_and_36;
    wire signal_and_37;
    wire [15:0] signal_mux;
    wire [15:0] signal_mux_1;
    wire [15:0] signal_wire;
    reg [15:0] signal_reg;
    wire signal_eq_30;
    wire signal_eq_31;
    wire signal_and_38;
    wire signal_and_39;
    wire [15:0] signal_mux_2;
    wire [15:0] signal_mux_3;
    wire [15:0] signal_wire_1;
    reg [15:0] signal_reg_1;
    wire [15:0] signal_mux_4;
    wire [8:0] signal_const_103;
    wire [8:0] signal_select_13;
    wire signal_eq_32;
    wire [6:0] signal_const_105;
    wire signal_eq_33;
    wire signal_and_40;
    wire signal_and_41;
    wire [8:0] signal_mux_5;
    wire [8:0] signal_mux_6;
    wire [8:0] signal_wire_2;
    reg [8:0] signal_reg_2;
    wire [8:0] signal_select_14;
    wire signal_eq_34;
    wire signal_eq_35;
    wire signal_and_42;
    wire signal_and_43;
    wire [8:0] signal_mux_7;
    wire [8:0] signal_mux_8;
    wire [8:0] signal_wire_3;
    reg [8:0] signal_reg_3;
    wire [8:0] signal_mux_9;
    wire [15:0] signal_cat_29;
    wire [8:0] signal_select_15;
    wire signal_eq_36;
    wire [6:0] signal_const_113;
    wire signal_eq_37;
    wire signal_and_44;
    wire signal_and_45;
    wire [8:0] signal_mux_10;
    wire [8:0] signal_mux_11;
    wire [8:0] signal_wire_4;
    reg [8:0] signal_reg_4;
    wire [8:0] signal_select_16;
    wire signal_eq_38;
    wire signal_eq_39;
    wire signal_and_46;
    wire signal_and_47;
    wire [8:0] signal_mux_12;
    wire [8:0] signal_mux_13;
    wire [8:0] signal_wire_5;
    reg [8:0] signal_reg_5;
    wire [8:0] signal_mux_14;
    wire [15:0] signal_cat_30;
    wire signal_select_17;
    wire signal_eq_40;
    wire [6:0] signal_const_121;
    wire signal_eq_41;
    wire signal_and_48;
    wire signal_and_49;
    wire signal_mux_15;
    wire signal_mux_16;
    wire signal_wire_6;
    reg signal_reg_6;
    wire signal_select_18;
    wire signal_eq_42;
    wire signal_eq_43;
    wire signal_and_50;
    wire signal_and_51;
    wire signal_mux_17;
    wire signal_mux_18;
    wire signal_wire_7;
    reg signal_reg_7;
    wire signal_mux_19;
    wire [15:0] signal_cat_31;
    wire [4:0] signal_const_127;
    wire [4:0] signal_select_19;
    wire signal_eq_44;
    wire [6:0] signal_const_129;
    wire signal_eq_45;
    wire signal_and_52;
    wire signal_and_53;
    wire [4:0] signal_mux_20;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_wire_8;
    reg [4:0] signal_reg_8;
    wire [4:0] signal_select_20;
    wire signal_eq_46;
    wire signal_eq_47;
    wire signal_and_54;
    wire signal_and_55;
    wire [4:0] signal_mux_22;
    wire [4:0] signal_mux_23;
    wire [4:0] signal_wire_9;
    reg [4:0] signal_reg_9;
    wire [4:0] signal_mux_24;
    wire [15:0] signal_cat_32;
    wire signal_select_21;
    wire signal_eq_48;
    wire [6:0] signal_const_137;
    wire signal_eq_49;
    wire signal_and_56;
    wire signal_and_57;
    wire signal_mux_25;
    wire signal_mux_26;
    wire signal_wire_10;
    reg signal_reg_10;
    wire signal_select_22;
    wire signal_eq_50;
    wire signal_eq_51;
    wire signal_and_58;
    wire signal_and_59;
    wire signal_mux_27;
    wire signal_mux_28;
    wire signal_wire_11;
    reg signal_reg_11;
    wire signal_mux_29;
    wire [15:0] signal_cat_33;
    wire signal_eq_52;
    wire [6:0] signal_const_145;
    wire signal_eq_53;
    wire signal_and_60;
    wire signal_and_61;
    wire [15:0] signal_mux_30;
    wire [15:0] signal_mux_31;
    wire [15:0] signal_wire_12;
    reg [15:0] signal_reg_12;
    wire signal_eq_54;
    wire signal_eq_55;
    wire signal_and_62;
    wire signal_and_63;
    wire [15:0] signal_mux_32;
    wire [15:0] signal_mux_33;
    wire [15:0] signal_wire_13;
    reg [15:0] signal_reg_13;
    wire [15:0] signal_mux_34;
    wire signal_eq_56;
    wire [6:0] signal_const_152;
    wire signal_eq_57;
    wire signal_and_64;
    wire signal_and_65;
    wire [15:0] signal_mux_35;
    wire [15:0] signal_mux_36;
    wire [15:0] signal_wire_14;
    reg [15:0] signal_reg_14;
    wire signal_eq_58;
    wire signal_eq_59;
    wire signal_and_66;
    wire signal_and_67;
    wire [15:0] signal_mux_37;
    wire [15:0] signal_mux_38;
    wire [15:0] signal_wire_15;
    reg [15:0] signal_reg_15;
    wire [15:0] signal_mux_39;
    wire [4:0] signal_select_23;
    wire signal_eq_60;
    wire [6:0] signal_const_159;
    wire signal_eq_61;
    wire signal_and_68;
    wire signal_and_69;
    wire [4:0] signal_mux_40;
    wire [4:0] signal_mux_41;
    wire [4:0] signal_wire_16;
    reg [4:0] signal_reg_16;
    wire [4:0] signal_select_24;
    wire signal_eq_62;
    wire signal_eq_63;
    wire signal_and_70;
    wire signal_and_71;
    wire [4:0] signal_mux_42;
    wire [4:0] signal_mux_43;
    wire [4:0] signal_wire_17;
    reg [4:0] signal_reg_17;
    wire [4:0] signal_mux_44;
    wire [15:0] signal_cat_34;
    wire [4:0] signal_select_25;
    wire signal_eq_64;
    wire [6:0] signal_const_167;
    wire signal_eq_65;
    wire signal_and_72;
    wire signal_and_73;
    wire [4:0] signal_mux_45;
    wire [4:0] signal_mux_46;
    wire [4:0] signal_wire_18;
    reg [4:0] signal_reg_18;
    wire [4:0] signal_select_26;
    wire signal_eq_66;
    wire signal_eq_67;
    wire signal_and_74;
    wire signal_and_75;
    wire [4:0] signal_mux_47;
    wire [4:0] signal_mux_48;
    wire [4:0] signal_wire_19;
    reg [4:0] signal_reg_19;
    wire [4:0] signal_mux_49;
    wire [15:0] signal_cat_35;
    wire signal_select_27;
    wire signal_eq_68;
    wire [6:0] signal_const_175;
    wire signal_eq_69;
    wire signal_and_76;
    wire signal_and_77;
    wire signal_mux_50;
    wire signal_mux_51;
    wire signal_wire_20;
    reg signal_reg_20;
    wire signal_select_28;
    wire signal_eq_70;
    wire signal_eq_71;
    wire signal_and_78;
    wire signal_and_79;
    wire signal_mux_52;
    wire signal_mux_53;
    wire signal_wire_21;
    reg signal_reg_21;
    wire signal_mux_54;
    wire [15:0] signal_cat_36;
    wire [4:0] signal_select_29;
    wire signal_eq_72;
    wire [6:0] signal_const_183;
    wire signal_eq_73;
    wire signal_and_80;
    wire signal_and_81;
    wire [4:0] signal_mux_55;
    wire [4:0] signal_mux_56;
    wire [4:0] signal_wire_22;
    reg [4:0] signal_reg_22;
    wire [4:0] signal_select_30;
    wire signal_eq_74;
    wire signal_eq_75;
    wire signal_and_82;
    wire signal_and_83;
    wire [4:0] signal_mux_57;
    wire [4:0] signal_mux_58;
    wire [4:0] signal_wire_23;
    reg [4:0] signal_reg_23;
    wire [4:0] signal_mux_59;
    wire [15:0] signal_cat_37;
    wire signal_select_31;
    wire signal_eq_76;
    wire [6:0] signal_const_191;
    wire signal_eq_77;
    wire signal_and_84;
    wire signal_and_85;
    wire signal_mux_60;
    wire signal_mux_61;
    wire signal_wire_24;
    reg signal_reg_24;
    wire signal_select_32;
    wire signal_eq_78;
    wire signal_eq_79;
    wire signal_and_86;
    wire signal_and_87;
    wire signal_mux_62;
    wire signal_mux_63;
    wire signal_wire_25;
    reg signal_reg_25;
    wire signal_mux_64;
    wire [15:0] signal_cat_38;
    wire signal_select_33;
    wire signal_eq_80;
    wire [6:0] signal_const_199;
    wire signal_eq_81;
    wire signal_and_88;
    wire signal_and_89;
    wire signal_mux_65;
    wire signal_mux_66;
    wire signal_wire_26;
    reg signal_reg_26;
    wire signal_select_34;
    wire signal_eq_82;
    wire signal_eq_83;
    wire signal_and_90;
    wire signal_and_91;
    wire signal_mux_67;
    wire signal_mux_68;
    wire signal_wire_27;
    reg signal_reg_27;
    wire signal_mux_69;
    wire [15:0] signal_cat_39;
    wire signal_select_35;
    wire signal_eq_84;
    wire [6:0] signal_const_207;
    wire signal_eq_85;
    wire signal_and_92;
    wire signal_and_93;
    wire signal_mux_70;
    wire signal_mux_71;
    wire signal_wire_28;
    reg signal_reg_28;
    wire signal_select_36;
    wire signal_eq_86;
    wire signal_eq_87;
    wire signal_and_94;
    wire signal_and_95;
    wire signal_mux_72;
    wire signal_mux_73;
    wire signal_wire_29;
    reg signal_reg_29;
    wire signal_mux_74;
    wire [15:0] signal_cat_40;
    wire signal_select_37;
    wire signal_eq_88;
    wire [6:0] signal_const_215;
    wire signal_eq_89;
    wire signal_and_96;
    wire signal_and_97;
    wire signal_mux_75;
    wire signal_mux_76;
    wire signal_wire_30;
    reg signal_reg_30;
    wire signal_select_38;
    wire signal_eq_90;
    wire signal_eq_91;
    wire signal_and_98;
    wire signal_and_99;
    wire signal_mux_77;
    wire signal_mux_78;
    wire signal_wire_31;
    reg signal_reg_31;
    wire signal_mux_79;
    wire [15:0] signal_cat_41;
    wire [4:0] signal_select_39;
    wire signal_eq_92;
    wire [6:0] signal_const_223;
    wire signal_eq_93;
    wire signal_and_100;
    wire signal_and_101;
    wire [4:0] signal_mux_80;
    wire [4:0] signal_mux_81;
    wire [4:0] signal_wire_32;
    reg [4:0] signal_reg_32;
    wire [4:0] signal_select_40;
    wire signal_eq_94;
    wire signal_eq_95;
    wire signal_and_102;
    wire signal_and_103;
    wire [4:0] signal_mux_82;
    wire [4:0] signal_mux_83;
    wire [4:0] signal_wire_33;
    reg [4:0] signal_reg_33;
    wire [4:0] signal_mux_84;
    wire [15:0] signal_cat_42;
    wire [4:0] signal_select_41;
    wire signal_eq_96;
    wire [6:0] signal_const_231;
    wire signal_eq_97;
    wire signal_and_104;
    wire signal_and_105;
    wire [4:0] signal_mux_85;
    wire [4:0] signal_mux_86;
    wire [4:0] signal_wire_34;
    reg [4:0] signal_reg_34;
    wire [4:0] signal_select_42;
    wire signal_eq_98;
    wire signal_eq_99;
    wire signal_and_106;
    wire signal_and_107;
    wire [4:0] signal_mux_87;
    wire [4:0] signal_mux_88;
    wire [4:0] signal_wire_35;
    reg [4:0] signal_reg_35;
    wire [4:0] signal_mux_89;
    wire [15:0] signal_cat_43;
    wire [2:0] signal_const_237;
    wire [2:0] signal_select_43;
    wire signal_eq_100;
    wire [6:0] signal_const_239;
    wire signal_eq_101;
    wire signal_and_108;
    wire signal_and_109;
    wire [2:0] signal_mux_90;
    wire [2:0] signal_mux_91;
    wire [2:0] signal_wire_36;
    reg [2:0] signal_reg_36;
    wire [2:0] signal_select_44;
    wire signal_eq_102;
    wire signal_eq_103;
    wire signal_and_110;
    wire signal_and_111;
    wire [2:0] signal_mux_92;
    wire [2:0] signal_mux_93;
    wire [2:0] signal_wire_37;
    reg [2:0] signal_reg_37;
    wire [2:0] signal_mux_94;
    wire [15:0] signal_cat_44;
    wire [4:0] signal_select_45;
    wire signal_eq_104;
    wire [6:0] signal_const_247;
    wire signal_eq_105;
    wire signal_and_112;
    wire signal_and_113;
    wire [4:0] signal_mux_95;
    wire [4:0] signal_mux_96;
    wire [4:0] signal_wire_38;
    reg [4:0] signal_reg_38;
    wire [4:0] signal_select_46;
    wire signal_eq_106;
    wire signal_eq_107;
    wire signal_and_114;
    wire signal_and_115;
    wire [4:0] signal_mux_97;
    wire [4:0] signal_mux_98;
    wire [4:0] signal_wire_39;
    reg [4:0] signal_reg_39;
    wire [4:0] signal_mux_99;
    wire [15:0] signal_cat_45;
    wire [4:0] signal_select_47;
    wire signal_eq_108;
    wire [6:0] signal_const_255;
    wire signal_eq_109;
    wire signal_and_116;
    wire signal_and_117;
    wire [4:0] signal_mux_100;
    wire [4:0] signal_mux_101;
    wire [4:0] signal_wire_40;
    reg [4:0] signal_reg_40;
    wire [4:0] signal_select_48;
    wire signal_eq_110;
    wire signal_eq_111;
    wire signal_and_118;
    wire signal_and_119;
    wire [4:0] signal_mux_102;
    wire [4:0] signal_mux_103;
    wire [4:0] signal_wire_41;
    reg [4:0] signal_reg_41;
    wire [4:0] signal_mux_104;
    wire [15:0] signal_cat_46;
    wire [4:0] signal_select_49;
    wire signal_eq_112;
    wire [6:0] signal_const_263;
    wire signal_eq_113;
    wire signal_and_120;
    wire signal_and_121;
    wire [4:0] signal_mux_105;
    wire [4:0] signal_mux_106;
    wire [4:0] signal_wire_42;
    reg [4:0] signal_reg_42;
    wire [4:0] signal_select_50;
    wire signal_eq_114;
    wire signal_eq_115;
    wire signal_and_122;
    wire signal_and_123;
    wire [4:0] signal_mux_107;
    wire [4:0] signal_mux_108;
    wire [4:0] signal_wire_43;
    reg [4:0] signal_reg_43;
    wire [4:0] signal_mux_109;
    wire [15:0] signal_cat_47;
    wire [4:0] signal_select_51;
    wire signal_eq_116;
    wire [6:0] signal_const_271;
    wire signal_eq_117;
    wire signal_and_124;
    wire signal_and_125;
    wire [4:0] signal_mux_110;
    wire [4:0] signal_mux_111;
    wire [4:0] signal_wire_44;
    reg [4:0] signal_reg_44;
    wire [4:0] signal_select_52;
    wire signal_eq_118;
    wire signal_eq_119;
    wire signal_and_126;
    wire signal_and_127;
    wire [4:0] signal_mux_112;
    wire [4:0] signal_mux_113;
    wire [4:0] signal_wire_45;
    reg [4:0] signal_reg_45;
    wire [4:0] signal_mux_114;
    wire [15:0] signal_cat_48;
    wire [4:0] signal_select_53;
    wire signal_eq_120;
    wire [6:0] signal_const_279;
    wire signal_eq_121;
    wire signal_and_128;
    wire signal_and_129;
    wire [4:0] signal_mux_115;
    wire [4:0] signal_mux_116;
    wire [4:0] signal_wire_46;
    reg [4:0] signal_reg_46;
    wire [4:0] signal_select_54;
    wire signal_eq_122;
    wire signal_eq_123;
    wire signal_and_130;
    wire signal_and_131;
    wire [4:0] signal_mux_117;
    wire [4:0] signal_mux_118;
    wire [4:0] signal_wire_47;
    reg [4:0] signal_reg_47;
    wire [4:0] signal_mux_119;
    wire [15:0] signal_cat_49;
    wire signal_select_55;
    wire signal_eq_124;
    wire [6:0] signal_const_287;
    wire signal_eq_125;
    wire signal_and_132;
    wire signal_and_133;
    wire signal_mux_120;
    wire signal_mux_121;
    wire signal_wire_48;
    reg signal_reg_48;
    wire signal_select_56;
    wire signal_eq_126;
    wire signal_eq_127;
    wire signal_and_134;
    wire signal_and_135;
    wire signal_mux_122;
    wire signal_mux_123;
    wire signal_wire_49;
    reg signal_reg_49;
    wire signal_mux_124;
    wire [15:0] signal_cat_50;
    wire [4:0] signal_select_57;
    wire signal_eq_128;
    wire [6:0] signal_const_295;
    wire signal_eq_129;
    wire signal_and_136;
    wire signal_and_137;
    wire [4:0] signal_mux_125;
    wire [4:0] signal_mux_126;
    wire [4:0] signal_wire_50;
    reg [4:0] signal_reg_50;
    wire [4:0] signal_select_58;
    wire signal_eq_130;
    wire signal_eq_131;
    wire signal_and_138;
    wire signal_and_139;
    wire [4:0] signal_mux_127;
    wire [4:0] signal_mux_128;
    wire [4:0] signal_wire_51;
    reg [4:0] signal_reg_51;
    wire [4:0] signal_mux_129;
    wire [15:0] signal_cat_51;
    wire [1:0] signal_const_301;
    wire [1:0] signal_select_59;
    wire signal_eq_132;
    wire [6:0] signal_const_303;
    wire signal_eq_133;
    wire signal_and_140;
    wire signal_and_141;
    wire [1:0] signal_mux_130;
    wire [1:0] signal_mux_131;
    wire [1:0] signal_wire_52;
    reg [1:0] signal_reg_52;
    wire [1:0] signal_select_60;
    wire signal_eq_134;
    wire signal_eq_135;
    wire signal_and_142;
    wire signal_and_143;
    wire [1:0] signal_mux_132;
    wire [1:0] signal_mux_133;
    wire [1:0] signal_wire_53;
    reg [1:0] signal_reg_53;
    wire [1:0] signal_mux_134;
    wire [15:0] signal_cat_52;
    wire [15:0] signal_cat_53;
    wire [8:0] signal_const_312;
    wire [8:0] signal_add;
    wire [8:0] signal_select_61;
    wire [6:0] signal_const_313;
    wire signal_eq_136;
    wire [8:0] signal_mux_135;
    wire signal_eq_137;
    wire [8:0] signal_mux_136;
    wire [8:0] signal_mux_137;
    wire [8:0] signal_wire_54;
    reg [8:0] program_addr;
    wire [15:0] signal_cat_54;
    wire [15:0] signal_wire_55;
    wire [15:0] signal_wire_56;
    wire [15:0] signal_mux_138;
    wire [7:0] signal_select_62;
    wire [15:0] signal_cat_55;
    wire [23:0] signal_wire_57;
    wire [23:0] signal_wire_58;
    wire [23:0] signal_mux_139;
    wire [15:0] signal_select_63;
    wire [7:0] signal_select_64;
    wire [15:0] signal_cat_56;
    wire [23:0] signal_wire_59;
    wire [23:0] signal_wire_60;
    wire [23:0] signal_mux_140;
    wire [15:0] signal_select_65;
    wire [8:0] signal_wire_61;
    wire [8:0] signal_wire_62;
    wire [8:0] signal_mux_141;
    wire [15:0] signal_cat_57;
    wire signal_wire_63;
    wire signal_wire_64;
    wire signal_mux_142;
    wire signal_mux_143;
    wire signal_wire_65;
    wire signal_wire_66;
    wire signal_mux_144;
    wire signal_wire_67;
    wire signal_wire_68;
    wire signal_mux_145;
    wire signal_wire_69;
    wire signal_wire_70;
    wire signal_mux_146;
    wire signal_wire_71;
    wire signal_wire_72;
    wire signal_mux_147;
    wire [3:0] signal_wire_73;
    wire [3:0] signal_wire_74;
    wire [3:0] signal_mux_148;
    wire [3:0] signal_wire_75;
    wire [3:0] signal_wire_76;
    wire [3:0] signal_mux_149;
    wire signal_wire_77;
    wire signal_wire_78;
    reg [7:0] signal_cases;
    wire [7:0] signal_mux_150;
    wire [7:0] signal_wire_79;
    reg [7:0] high;
    wire [15:0] value;
    wire signal_select_66;
    wire [6:0] signal_const_329;
    wire signal_eq_138;
    wire signal_mux_151;
    wire signal_mux_152;
    reg signal_cases_1;
    wire signal_mux_153;
    wire write;
    wire signal_mux_154;
    wire signal_wire_80;
    reg select;
    wire signal_mux_155;
    wire [15:0] signal_cat_58;
    wire [6:0] signal_select_67;
    reg [15:0] first_read;
    reg [15:0] signal_cases_2;
    wire [15:0] signal_mux_156;
    wire vdd;
    wire is_write;
    wire signal_mux_157;
    reg signal_cases_3;
    wire gnd;
    wire signal_mux_158;
    wire read_done;
    wire [15:0] signal_mux_159;
    wire [15:0] signal_wire_81;
    reg [15:0] word;
    wire [7:0] signal_select_68;
    reg [7:0] signal_cases_4;
    wire [7:0] signal_mux_160;
    wire [7:0] signal_wire_82;
    reg [7:0] cmd;
    wire [6:0] addr;
    wire signal_eq_139;
    wire [15:0] tx_word;
    wire [7:0] signal_select_69;
    wire [1:0] signal_const_334;
    reg [1:0] signal_cases_5;
    wire signal_select_70;
    wire [1:0] signal_mux_161;
    wire signal_select_71;
    wire [1:0] signal_mux_162;
    wire [1:0] signal_wire_83;
    (* fsm_encoding="one_hot" *)
    reg [1:0] sm;
    wire [1:0] signal_const_336;
    wire signal_eq_140;
    wire [7:0] signal_mux_163;
    wire signal_wire_84;
    wire signal_wire_85;
    wire signal_wire_86;
    wire signal_wire_87;
    wire signal_wire_88;
    wire [11:0] signal_inst;
    wire signal_select_72;
    assign signal_const = 1'b1;
    assign signal_eq = select == signal_const;
    assign signal_select = value[3:3];
    assign signal_const_1 = 7'b0000000;
    assign signal_eq_1 = addr == signal_const_1;
    assign signal_and = write & signal_eq_1;
    assign signal_and_1 = signal_and & signal_select;
    assign signal_and_2 = signal_and_1 & signal_eq;
    assign signal_eq_2 = select == signal_const;
    assign signal_select_1 = value[2:2];
    assign signal_eq_3 = addr == signal_const_1;
    assign signal_and_3 = write & signal_eq_3;
    assign signal_and_4 = signal_and_3 & signal_select_1;
    assign signal_and_5 = signal_and_4 & signal_eq_2;
    assign signal_eq_4 = select == signal_const;
    assign signal_select_2 = value[1:1];
    assign signal_eq_5 = addr == signal_const_1;
    assign signal_and_6 = write & signal_eq_5;
    assign signal_and_7 = signal_and_6 & signal_select_2;
    assign signal_and_8 = signal_and_7 & signal_eq_4;
    assign signal_eq_6 = select == signal_const;
    assign signal_const_7 = 7'b0001000;
    assign signal_eq_7 = addr == signal_const_7;
    assign signal_and_9 = read_done & signal_eq_7;
    assign signal_and_10 = signal_and_9 & signal_eq_6;
    assign signal_eq_8 = select == signal_const;
    assign signal_const_9 = 7'b0000111;
    assign signal_eq_9 = addr == signal_const_9;
    assign signal_and_11 = write & signal_eq_9;
    assign signal_and_12 = signal_and_11 & signal_eq_8;
    assign signal_eq_10 = select == signal_const;
    assign signal_const_11 = 7'b0001010;
    assign signal_eq_11 = addr == signal_const_11;
    assign signal_and_13 = write & signal_eq_11;
    assign signal_and_14 = signal_and_13 & signal_eq_10;
    assign signal_eq_12 = select == signal_const;
    assign signal_select_3 = value[0:0];
    assign signal_eq_13 = addr == signal_const_1;
    assign signal_and_15 = write & signal_eq_13;
    assign signal_and_16 = signal_and_15 & signal_select_3;
    assign signal_and_17 = signal_and_16 & signal_eq_12;
    assign signal_const_14 = 1'b0;
    assign signal_eq_14 = select == signal_const_14;
    assign signal_select_4 = value[3:3];
    assign signal_eq_15 = addr == signal_const_1;
    assign signal_and_18 = write & signal_eq_15;
    assign signal_and_19 = signal_and_18 & signal_select_4;
    assign signal_and_20 = signal_and_19 & signal_eq_14;
    assign signal_eq_16 = select == signal_const_14;
    assign signal_select_5 = value[2:2];
    assign signal_eq_17 = addr == signal_const_1;
    assign signal_and_21 = write & signal_eq_17;
    assign signal_and_22 = signal_and_21 & signal_select_5;
    assign signal_and_23 = signal_and_22 & signal_eq_16;
    assign signal_eq_18 = select == signal_const_14;
    assign signal_select_6 = value[1:1];
    assign signal_eq_19 = addr == signal_const_1;
    assign signal_and_24 = write & signal_eq_19;
    assign signal_and_25 = signal_and_24 & signal_select_6;
    assign signal_and_26 = signal_and_25 & signal_eq_18;
    assign signal_eq_20 = select == signal_const_14;
    assign signal_eq_21 = addr == signal_const_7;
    assign signal_and_27 = read_done & signal_eq_21;
    assign signal_and_28 = signal_and_27 & signal_eq_20;
    assign signal_eq_22 = select == signal_const_14;
    assign signal_eq_23 = addr == signal_const_9;
    assign signal_and_29 = write & signal_eq_23;
    assign signal_and_30 = signal_and_29 & signal_eq_22;
    assign signal_eq_24 = select == signal_const_14;
    assign signal_eq_25 = addr == signal_const_11;
    assign signal_and_31 = write & signal_eq_25;
    assign signal_and_32 = signal_and_31 & signal_eq_24;
    assign signal_eq_26 = select == signal_const_14;
    assign signal_select_7 = value[0:0];
    assign signal_eq_27 = addr == signal_const_1;
    assign signal_and_33 = write & signal_eq_27;
    assign signal_and_34 = signal_and_33 & signal_select_7;
    assign signal_and_35 = signal_and_34 & signal_eq_26;
    assign signal_select_8 = tx_word[7:0];
    assign signal_const_28 = 16'b0000000000000000;
    assign signal_cat = { signal_const_1,
                          signal_mux_9 };
    assign signal_cat_1 = { signal_const_1,
                            signal_mux_14 };
    assign signal_const_35 = 15'b000000000000000;
    assign signal_cat_2 = { signal_const_35,
                            signal_mux_19 };
    assign signal_const_37 = 11'b00000000000;
    assign signal_cat_3 = { signal_const_37,
                            signal_mux_24 };
    assign signal_cat_4 = { signal_const_35,
                            signal_mux_29 };
    assign signal_cat_5 = { signal_const_37,
                            signal_mux_44 };
    assign signal_cat_6 = { signal_const_37,
                            signal_mux_49 };
    assign signal_cat_7 = { signal_const_35,
                            signal_mux_54 };
    assign signal_cat_8 = { signal_const_37,
                            signal_mux_59 };
    assign signal_cat_9 = { signal_const_35,
                            signal_mux_64 };
    assign signal_cat_10 = { signal_const_35,
                             signal_mux_69 };
    assign signal_cat_11 = { signal_const_35,
                             signal_mux_74 };
    assign signal_cat_12 = { signal_const_35,
                             signal_mux_79 };
    assign signal_cat_13 = { signal_const_37,
                             signal_mux_84 };
    assign signal_cat_14 = { signal_const_37,
                             signal_mux_89 };
    assign signal_const_63 = 13'b0000000000000;
    assign signal_cat_15 = { signal_const_63,
                             signal_mux_94 };
    assign signal_cat_16 = { signal_const_37,
                             signal_mux_99 };
    assign signal_cat_17 = { signal_const_37,
                             signal_mux_104 };
    assign signal_cat_18 = { signal_const_37,
                             signal_mux_109 };
    assign signal_cat_19 = { signal_const_37,
                             signal_mux_114 };
    assign signal_cat_20 = { signal_const_37,
                             signal_mux_119 };
    assign signal_cat_21 = { signal_const_35,
                             signal_mux_124 };
    assign signal_cat_22 = { signal_const_37,
                             signal_mux_129 };
    assign signal_const_79 = 14'b00000000000000;
    assign signal_cat_23 = { signal_const_79,
                             signal_mux_134 };
    assign signal_cat_24 = { signal_const_35,
                             select };
    assign signal_cat_25 = { signal_const_1,
                             program_addr };
    assign signal_select_9 = signal_mux_139[23:16];
    assign signal_const_86 = 8'b00000000;
    assign signal_cat_26 = { signal_const_86,
                             signal_select_9 };
    assign signal_select_10 = signal_mux_139[15:0];
    assign signal_select_11 = signal_mux_140[23:16];
    assign signal_cat_27 = { signal_const_86,
                             signal_select_11 };
    assign signal_select_12 = signal_mux_140[15:0];
    assign signal_cat_28 = { signal_const_1,
                             signal_mux_141 };
    always @* begin
        case (addr)
        7'b0000001:
            read_value <= signal_cat_58;
        7'b0000010:
            read_value <= signal_cat_28;
        7'b0000011:
            read_value <= signal_select_12;
        7'b0000100:
            read_value <= signal_cat_27;
        7'b0000101:
            read_value <= signal_select_10;
        7'b0000110:
            read_value <= signal_cat_26;
        7'b0001000:
            read_value <= signal_mux_138;
        7'b0001001:
            read_value <= signal_cat_25;
        7'b0001011:
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
            read_value <= signal_mux_39;
        7'b0100100:
            read_value <= signal_mux_34;
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
        7'b0101010:
            read_value <= signal_mux_4;
        default:
            read_value <= signal_const_28;
        endcase
    end
    assign signal_eq_28 = select == signal_const;
    assign signal_const_98 = 7'b0101010;
    assign signal_eq_29 = addr == signal_const_98;
    assign signal_and_36 = signal_eq_29 & signal_eq_28;
    assign signal_and_37 = signal_and_36 & signal_wire_63;
    assign signal_mux = signal_and_37 ? value : signal_reg;
    assign signal_mux_1 = write ? signal_mux : signal_reg;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg <= signal_const_28;
        else
            signal_reg <= signal_wire;
    end
    assign signal_eq_30 = select == signal_const_14;
    assign signal_eq_31 = addr == signal_const_98;
    assign signal_and_38 = signal_eq_31 & signal_eq_30;
    assign signal_and_39 = signal_and_38 & signal_wire_64;
    assign signal_mux_2 = signal_and_39 ? value : signal_reg_1;
    assign signal_mux_3 = write ? signal_mux_2 : signal_reg_1;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_1 <= signal_const_28;
        else
            signal_reg_1 <= signal_wire_1;
    end
    assign signal_mux_4 = select ? signal_reg : signal_reg_1;
    assign signal_const_103 = 9'b000000000;
    assign signal_select_13 = value[8:0];
    assign signal_eq_32 = select == signal_const;
    assign signal_const_105 = 7'b0101001;
    assign signal_eq_33 = addr == signal_const_105;
    assign signal_and_40 = signal_eq_33 & signal_eq_32;
    assign signal_and_41 = signal_and_40 & signal_wire_63;
    assign signal_mux_5 = signal_and_41 ? signal_select_13 : signal_reg_2;
    assign signal_mux_6 = write ? signal_mux_5 : signal_reg_2;
    assign signal_wire_2 = signal_mux_6;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_2 <= signal_const_103;
        else
            signal_reg_2 <= signal_wire_2;
    end
    assign signal_select_14 = value[8:0];
    assign signal_eq_34 = select == signal_const_14;
    assign signal_eq_35 = addr == signal_const_105;
    assign signal_and_42 = signal_eq_35 & signal_eq_34;
    assign signal_and_43 = signal_and_42 & signal_wire_64;
    assign signal_mux_7 = signal_and_43 ? signal_select_14 : signal_reg_3;
    assign signal_mux_8 = write ? signal_mux_7 : signal_reg_3;
    assign signal_wire_3 = signal_mux_8;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_3 <= signal_const_103;
        else
            signal_reg_3 <= signal_wire_3;
    end
    assign signal_mux_9 = select ? signal_reg_2 : signal_reg_3;
    assign signal_cat_29 = { signal_const_1,
                             signal_mux_9 };
    assign signal_select_15 = value[8:0];
    assign signal_eq_36 = select == signal_const;
    assign signal_const_113 = 7'b0101000;
    assign signal_eq_37 = addr == signal_const_113;
    assign signal_and_44 = signal_eq_37 & signal_eq_36;
    assign signal_and_45 = signal_and_44 & signal_wire_63;
    assign signal_mux_10 = signal_and_45 ? signal_select_15 : signal_reg_4;
    assign signal_mux_11 = write ? signal_mux_10 : signal_reg_4;
    assign signal_wire_4 = signal_mux_11;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_4 <= signal_const_103;
        else
            signal_reg_4 <= signal_wire_4;
    end
    assign signal_select_16 = value[8:0];
    assign signal_eq_38 = select == signal_const_14;
    assign signal_eq_39 = addr == signal_const_113;
    assign signal_and_46 = signal_eq_39 & signal_eq_38;
    assign signal_and_47 = signal_and_46 & signal_wire_64;
    assign signal_mux_12 = signal_and_47 ? signal_select_16 : signal_reg_5;
    assign signal_mux_13 = write ? signal_mux_12 : signal_reg_5;
    assign signal_wire_5 = signal_mux_13;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_5 <= signal_const_103;
        else
            signal_reg_5 <= signal_wire_5;
    end
    assign signal_mux_14 = select ? signal_reg_4 : signal_reg_5;
    assign signal_cat_30 = { signal_const_1,
                             signal_mux_14 };
    assign signal_select_17 = value[0:0];
    assign signal_eq_40 = select == signal_const;
    assign signal_const_121 = 7'b0100111;
    assign signal_eq_41 = addr == signal_const_121;
    assign signal_and_48 = signal_eq_41 & signal_eq_40;
    assign signal_and_49 = signal_and_48 & signal_wire_63;
    assign signal_mux_15 = signal_and_49 ? signal_select_17 : signal_reg_6;
    assign signal_mux_16 = write ? signal_mux_15 : signal_reg_6;
    assign signal_wire_6 = signal_mux_16;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_6 <= signal_const_14;
        else
            signal_reg_6 <= signal_wire_6;
    end
    assign signal_select_18 = value[0:0];
    assign signal_eq_42 = select == signal_const_14;
    assign signal_eq_43 = addr == signal_const_121;
    assign signal_and_50 = signal_eq_43 & signal_eq_42;
    assign signal_and_51 = signal_and_50 & signal_wire_64;
    assign signal_mux_17 = signal_and_51 ? signal_select_18 : signal_reg_7;
    assign signal_mux_18 = write ? signal_mux_17 : signal_reg_7;
    assign signal_wire_7 = signal_mux_18;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_7 <= signal_const_14;
        else
            signal_reg_7 <= signal_wire_7;
    end
    assign signal_mux_19 = select ? signal_reg_6 : signal_reg_7;
    assign signal_cat_31 = { signal_const_35,
                             signal_mux_19 };
    assign signal_const_127 = 5'b00000;
    assign signal_select_19 = value[4:0];
    assign signal_eq_44 = select == signal_const;
    assign signal_const_129 = 7'b0100110;
    assign signal_eq_45 = addr == signal_const_129;
    assign signal_and_52 = signal_eq_45 & signal_eq_44;
    assign signal_and_53 = signal_and_52 & signal_wire_63;
    assign signal_mux_20 = signal_and_53 ? signal_select_19 : signal_reg_8;
    assign signal_mux_21 = write ? signal_mux_20 : signal_reg_8;
    assign signal_wire_8 = signal_mux_21;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_8 <= signal_const_127;
        else
            signal_reg_8 <= signal_wire_8;
    end
    assign signal_select_20 = value[4:0];
    assign signal_eq_46 = select == signal_const_14;
    assign signal_eq_47 = addr == signal_const_129;
    assign signal_and_54 = signal_eq_47 & signal_eq_46;
    assign signal_and_55 = signal_and_54 & signal_wire_64;
    assign signal_mux_22 = signal_and_55 ? signal_select_20 : signal_reg_9;
    assign signal_mux_23 = write ? signal_mux_22 : signal_reg_9;
    assign signal_wire_9 = signal_mux_23;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_9 <= signal_const_127;
        else
            signal_reg_9 <= signal_wire_9;
    end
    assign signal_mux_24 = select ? signal_reg_8 : signal_reg_9;
    assign signal_cat_32 = { signal_const_37,
                             signal_mux_24 };
    assign signal_select_21 = value[0:0];
    assign signal_eq_48 = select == signal_const;
    assign signal_const_137 = 7'b0100101;
    assign signal_eq_49 = addr == signal_const_137;
    assign signal_and_56 = signal_eq_49 & signal_eq_48;
    assign signal_and_57 = signal_and_56 & signal_wire_63;
    assign signal_mux_25 = signal_and_57 ? signal_select_21 : signal_reg_10;
    assign signal_mux_26 = write ? signal_mux_25 : signal_reg_10;
    assign signal_wire_10 = signal_mux_26;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_10 <= signal_const_14;
        else
            signal_reg_10 <= signal_wire_10;
    end
    assign signal_select_22 = value[0:0];
    assign signal_eq_50 = select == signal_const_14;
    assign signal_eq_51 = addr == signal_const_137;
    assign signal_and_58 = signal_eq_51 & signal_eq_50;
    assign signal_and_59 = signal_and_58 & signal_wire_64;
    assign signal_mux_27 = signal_and_59 ? signal_select_22 : signal_reg_11;
    assign signal_mux_28 = write ? signal_mux_27 : signal_reg_11;
    assign signal_wire_11 = signal_mux_28;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_11 <= signal_const_14;
        else
            signal_reg_11 <= signal_wire_11;
    end
    assign signal_mux_29 = select ? signal_reg_10 : signal_reg_11;
    assign signal_cat_33 = { signal_const_35,
                             signal_mux_29 };
    assign signal_eq_52 = select == signal_const;
    assign signal_const_145 = 7'b0100100;
    assign signal_eq_53 = addr == signal_const_145;
    assign signal_and_60 = signal_eq_53 & signal_eq_52;
    assign signal_and_61 = signal_and_60 & signal_wire_63;
    assign signal_mux_30 = signal_and_61 ? value : signal_reg_12;
    assign signal_mux_31 = write ? signal_mux_30 : signal_reg_12;
    assign signal_wire_12 = signal_mux_31;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_12 <= signal_const_28;
        else
            signal_reg_12 <= signal_wire_12;
    end
    assign signal_eq_54 = select == signal_const_14;
    assign signal_eq_55 = addr == signal_const_145;
    assign signal_and_62 = signal_eq_55 & signal_eq_54;
    assign signal_and_63 = signal_and_62 & signal_wire_64;
    assign signal_mux_32 = signal_and_63 ? value : signal_reg_13;
    assign signal_mux_33 = write ? signal_mux_32 : signal_reg_13;
    assign signal_wire_13 = signal_mux_33;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_13 <= signal_const_28;
        else
            signal_reg_13 <= signal_wire_13;
    end
    assign signal_mux_34 = select ? signal_reg_12 : signal_reg_13;
    assign signal_eq_56 = select == signal_const;
    assign signal_const_152 = 7'b0100011;
    assign signal_eq_57 = addr == signal_const_152;
    assign signal_and_64 = signal_eq_57 & signal_eq_56;
    assign signal_and_65 = signal_and_64 & signal_wire_63;
    assign signal_mux_35 = signal_and_65 ? value : signal_reg_14;
    assign signal_mux_36 = write ? signal_mux_35 : signal_reg_14;
    assign signal_wire_14 = signal_mux_36;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_14 <= signal_const_28;
        else
            signal_reg_14 <= signal_wire_14;
    end
    assign signal_eq_58 = select == signal_const_14;
    assign signal_eq_59 = addr == signal_const_152;
    assign signal_and_66 = signal_eq_59 & signal_eq_58;
    assign signal_and_67 = signal_and_66 & signal_wire_64;
    assign signal_mux_37 = signal_and_67 ? value : signal_reg_15;
    assign signal_mux_38 = write ? signal_mux_37 : signal_reg_15;
    assign signal_wire_15 = signal_mux_38;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_15 <= signal_const_28;
        else
            signal_reg_15 <= signal_wire_15;
    end
    assign signal_mux_39 = select ? signal_reg_14 : signal_reg_15;
    assign signal_select_23 = value[4:0];
    assign signal_eq_60 = select == signal_const;
    assign signal_const_159 = 7'b0100010;
    assign signal_eq_61 = addr == signal_const_159;
    assign signal_and_68 = signal_eq_61 & signal_eq_60;
    assign signal_and_69 = signal_and_68 & signal_wire_63;
    assign signal_mux_40 = signal_and_69 ? signal_select_23 : signal_reg_16;
    assign signal_mux_41 = write ? signal_mux_40 : signal_reg_16;
    assign signal_wire_16 = signal_mux_41;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_16 <= signal_const_127;
        else
            signal_reg_16 <= signal_wire_16;
    end
    assign signal_select_24 = value[4:0];
    assign signal_eq_62 = select == signal_const_14;
    assign signal_eq_63 = addr == signal_const_159;
    assign signal_and_70 = signal_eq_63 & signal_eq_62;
    assign signal_and_71 = signal_and_70 & signal_wire_64;
    assign signal_mux_42 = signal_and_71 ? signal_select_24 : signal_reg_17;
    assign signal_mux_43 = write ? signal_mux_42 : signal_reg_17;
    assign signal_wire_17 = signal_mux_43;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_17 <= signal_const_127;
        else
            signal_reg_17 <= signal_wire_17;
    end
    assign signal_mux_44 = select ? signal_reg_16 : signal_reg_17;
    assign signal_cat_34 = { signal_const_37,
                             signal_mux_44 };
    assign signal_select_25 = value[4:0];
    assign signal_eq_64 = select == signal_const;
    assign signal_const_167 = 7'b0100001;
    assign signal_eq_65 = addr == signal_const_167;
    assign signal_and_72 = signal_eq_65 & signal_eq_64;
    assign signal_and_73 = signal_and_72 & signal_wire_63;
    assign signal_mux_45 = signal_and_73 ? signal_select_25 : signal_reg_18;
    assign signal_mux_46 = write ? signal_mux_45 : signal_reg_18;
    assign signal_wire_18 = signal_mux_46;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_18 <= signal_const_127;
        else
            signal_reg_18 <= signal_wire_18;
    end
    assign signal_select_26 = value[4:0];
    assign signal_eq_66 = select == signal_const_14;
    assign signal_eq_67 = addr == signal_const_167;
    assign signal_and_74 = signal_eq_67 & signal_eq_66;
    assign signal_and_75 = signal_and_74 & signal_wire_64;
    assign signal_mux_47 = signal_and_75 ? signal_select_26 : signal_reg_19;
    assign signal_mux_48 = write ? signal_mux_47 : signal_reg_19;
    assign signal_wire_19 = signal_mux_48;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_19 <= signal_const_127;
        else
            signal_reg_19 <= signal_wire_19;
    end
    assign signal_mux_49 = select ? signal_reg_18 : signal_reg_19;
    assign signal_cat_35 = { signal_const_37,
                             signal_mux_49 };
    assign signal_select_27 = value[0:0];
    assign signal_eq_68 = select == signal_const;
    assign signal_const_175 = 7'b0100000;
    assign signal_eq_69 = addr == signal_const_175;
    assign signal_and_76 = signal_eq_69 & signal_eq_68;
    assign signal_and_77 = signal_and_76 & signal_wire_63;
    assign signal_mux_50 = signal_and_77 ? signal_select_27 : signal_reg_20;
    assign signal_mux_51 = write ? signal_mux_50 : signal_reg_20;
    assign signal_wire_20 = signal_mux_51;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_20 <= signal_const_14;
        else
            signal_reg_20 <= signal_wire_20;
    end
    assign signal_select_28 = value[0:0];
    assign signal_eq_70 = select == signal_const_14;
    assign signal_eq_71 = addr == signal_const_175;
    assign signal_and_78 = signal_eq_71 & signal_eq_70;
    assign signal_and_79 = signal_and_78 & signal_wire_64;
    assign signal_mux_52 = signal_and_79 ? signal_select_28 : signal_reg_21;
    assign signal_mux_53 = write ? signal_mux_52 : signal_reg_21;
    assign signal_wire_21 = signal_mux_53;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_21 <= signal_const_14;
        else
            signal_reg_21 <= signal_wire_21;
    end
    assign signal_mux_54 = select ? signal_reg_20 : signal_reg_21;
    assign signal_cat_36 = { signal_const_35,
                             signal_mux_54 };
    assign signal_select_29 = value[4:0];
    assign signal_eq_72 = select == signal_const;
    assign signal_const_183 = 7'b0011111;
    assign signal_eq_73 = addr == signal_const_183;
    assign signal_and_80 = signal_eq_73 & signal_eq_72;
    assign signal_and_81 = signal_and_80 & signal_wire_63;
    assign signal_mux_55 = signal_and_81 ? signal_select_29 : signal_reg_22;
    assign signal_mux_56 = write ? signal_mux_55 : signal_reg_22;
    assign signal_wire_22 = signal_mux_56;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_22 <= signal_const_127;
        else
            signal_reg_22 <= signal_wire_22;
    end
    assign signal_select_30 = value[4:0];
    assign signal_eq_74 = select == signal_const_14;
    assign signal_eq_75 = addr == signal_const_183;
    assign signal_and_82 = signal_eq_75 & signal_eq_74;
    assign signal_and_83 = signal_and_82 & signal_wire_64;
    assign signal_mux_57 = signal_and_83 ? signal_select_30 : signal_reg_23;
    assign signal_mux_58 = write ? signal_mux_57 : signal_reg_23;
    assign signal_wire_23 = signal_mux_58;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_23 <= signal_const_127;
        else
            signal_reg_23 <= signal_wire_23;
    end
    assign signal_mux_59 = select ? signal_reg_22 : signal_reg_23;
    assign signal_cat_37 = { signal_const_37,
                             signal_mux_59 };
    assign signal_select_31 = value[0:0];
    assign signal_eq_76 = select == signal_const;
    assign signal_const_191 = 7'b0011110;
    assign signal_eq_77 = addr == signal_const_191;
    assign signal_and_84 = signal_eq_77 & signal_eq_76;
    assign signal_and_85 = signal_and_84 & signal_wire_63;
    assign signal_mux_60 = signal_and_85 ? signal_select_31 : signal_reg_24;
    assign signal_mux_61 = write ? signal_mux_60 : signal_reg_24;
    assign signal_wire_24 = signal_mux_61;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_24 <= signal_const_14;
        else
            signal_reg_24 <= signal_wire_24;
    end
    assign signal_select_32 = value[0:0];
    assign signal_eq_78 = select == signal_const_14;
    assign signal_eq_79 = addr == signal_const_191;
    assign signal_and_86 = signal_eq_79 & signal_eq_78;
    assign signal_and_87 = signal_and_86 & signal_wire_64;
    assign signal_mux_62 = signal_and_87 ? signal_select_32 : signal_reg_25;
    assign signal_mux_63 = write ? signal_mux_62 : signal_reg_25;
    assign signal_wire_25 = signal_mux_63;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_25 <= signal_const_14;
        else
            signal_reg_25 <= signal_wire_25;
    end
    assign signal_mux_64 = select ? signal_reg_24 : signal_reg_25;
    assign signal_cat_38 = { signal_const_35,
                             signal_mux_64 };
    assign signal_select_33 = value[0:0];
    assign signal_eq_80 = select == signal_const;
    assign signal_const_199 = 7'b0011101;
    assign signal_eq_81 = addr == signal_const_199;
    assign signal_and_88 = signal_eq_81 & signal_eq_80;
    assign signal_and_89 = signal_and_88 & signal_wire_63;
    assign signal_mux_65 = signal_and_89 ? signal_select_33 : signal_reg_26;
    assign signal_mux_66 = write ? signal_mux_65 : signal_reg_26;
    assign signal_wire_26 = signal_mux_66;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_26 <= signal_const_14;
        else
            signal_reg_26 <= signal_wire_26;
    end
    assign signal_select_34 = value[0:0];
    assign signal_eq_82 = select == signal_const_14;
    assign signal_eq_83 = addr == signal_const_199;
    assign signal_and_90 = signal_eq_83 & signal_eq_82;
    assign signal_and_91 = signal_and_90 & signal_wire_64;
    assign signal_mux_67 = signal_and_91 ? signal_select_34 : signal_reg_27;
    assign signal_mux_68 = write ? signal_mux_67 : signal_reg_27;
    assign signal_wire_27 = signal_mux_68;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_27 <= signal_const_14;
        else
            signal_reg_27 <= signal_wire_27;
    end
    assign signal_mux_69 = select ? signal_reg_26 : signal_reg_27;
    assign signal_cat_39 = { signal_const_35,
                             signal_mux_69 };
    assign signal_select_35 = value[0:0];
    assign signal_eq_84 = select == signal_const;
    assign signal_const_207 = 7'b0011100;
    assign signal_eq_85 = addr == signal_const_207;
    assign signal_and_92 = signal_eq_85 & signal_eq_84;
    assign signal_and_93 = signal_and_92 & signal_wire_63;
    assign signal_mux_70 = signal_and_93 ? signal_select_35 : signal_reg_28;
    assign signal_mux_71 = write ? signal_mux_70 : signal_reg_28;
    assign signal_wire_28 = signal_mux_71;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_28 <= signal_const_14;
        else
            signal_reg_28 <= signal_wire_28;
    end
    assign signal_select_36 = value[0:0];
    assign signal_eq_86 = select == signal_const_14;
    assign signal_eq_87 = addr == signal_const_207;
    assign signal_and_94 = signal_eq_87 & signal_eq_86;
    assign signal_and_95 = signal_and_94 & signal_wire_64;
    assign signal_mux_72 = signal_and_95 ? signal_select_36 : signal_reg_29;
    assign signal_mux_73 = write ? signal_mux_72 : signal_reg_29;
    assign signal_wire_29 = signal_mux_73;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_29 <= signal_const_14;
        else
            signal_reg_29 <= signal_wire_29;
    end
    assign signal_mux_74 = select ? signal_reg_28 : signal_reg_29;
    assign signal_cat_40 = { signal_const_35,
                             signal_mux_74 };
    assign signal_select_37 = value[0:0];
    assign signal_eq_88 = select == signal_const;
    assign signal_const_215 = 7'b0011011;
    assign signal_eq_89 = addr == signal_const_215;
    assign signal_and_96 = signal_eq_89 & signal_eq_88;
    assign signal_and_97 = signal_and_96 & signal_wire_63;
    assign signal_mux_75 = signal_and_97 ? signal_select_37 : signal_reg_30;
    assign signal_mux_76 = write ? signal_mux_75 : signal_reg_30;
    assign signal_wire_30 = signal_mux_76;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_30 <= signal_const_14;
        else
            signal_reg_30 <= signal_wire_30;
    end
    assign signal_select_38 = value[0:0];
    assign signal_eq_90 = select == signal_const_14;
    assign signal_eq_91 = addr == signal_const_215;
    assign signal_and_98 = signal_eq_91 & signal_eq_90;
    assign signal_and_99 = signal_and_98 & signal_wire_64;
    assign signal_mux_77 = signal_and_99 ? signal_select_38 : signal_reg_31;
    assign signal_mux_78 = write ? signal_mux_77 : signal_reg_31;
    assign signal_wire_31 = signal_mux_78;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_31 <= signal_const_14;
        else
            signal_reg_31 <= signal_wire_31;
    end
    assign signal_mux_79 = select ? signal_reg_30 : signal_reg_31;
    assign signal_cat_41 = { signal_const_35,
                             signal_mux_79 };
    assign signal_select_39 = value[4:0];
    assign signal_eq_92 = select == signal_const;
    assign signal_const_223 = 7'b0011010;
    assign signal_eq_93 = addr == signal_const_223;
    assign signal_and_100 = signal_eq_93 & signal_eq_92;
    assign signal_and_101 = signal_and_100 & signal_wire_63;
    assign signal_mux_80 = signal_and_101 ? signal_select_39 : signal_reg_32;
    assign signal_mux_81 = write ? signal_mux_80 : signal_reg_32;
    assign signal_wire_32 = signal_mux_81;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_32 <= signal_const_127;
        else
            signal_reg_32 <= signal_wire_32;
    end
    assign signal_select_40 = value[4:0];
    assign signal_eq_94 = select == signal_const_14;
    assign signal_eq_95 = addr == signal_const_223;
    assign signal_and_102 = signal_eq_95 & signal_eq_94;
    assign signal_and_103 = signal_and_102 & signal_wire_64;
    assign signal_mux_82 = signal_and_103 ? signal_select_40 : signal_reg_33;
    assign signal_mux_83 = write ? signal_mux_82 : signal_reg_33;
    assign signal_wire_33 = signal_mux_83;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_33 <= signal_const_127;
        else
            signal_reg_33 <= signal_wire_33;
    end
    assign signal_mux_84 = select ? signal_reg_32 : signal_reg_33;
    assign signal_cat_42 = { signal_const_37,
                             signal_mux_84 };
    assign signal_select_41 = value[4:0];
    assign signal_eq_96 = select == signal_const;
    assign signal_const_231 = 7'b0011001;
    assign signal_eq_97 = addr == signal_const_231;
    assign signal_and_104 = signal_eq_97 & signal_eq_96;
    assign signal_and_105 = signal_and_104 & signal_wire_63;
    assign signal_mux_85 = signal_and_105 ? signal_select_41 : signal_reg_34;
    assign signal_mux_86 = write ? signal_mux_85 : signal_reg_34;
    assign signal_wire_34 = signal_mux_86;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_34 <= signal_const_127;
        else
            signal_reg_34 <= signal_wire_34;
    end
    assign signal_select_42 = value[4:0];
    assign signal_eq_98 = select == signal_const_14;
    assign signal_eq_99 = addr == signal_const_231;
    assign signal_and_106 = signal_eq_99 & signal_eq_98;
    assign signal_and_107 = signal_and_106 & signal_wire_64;
    assign signal_mux_87 = signal_and_107 ? signal_select_42 : signal_reg_35;
    assign signal_mux_88 = write ? signal_mux_87 : signal_reg_35;
    assign signal_wire_35 = signal_mux_88;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_35 <= signal_const_127;
        else
            signal_reg_35 <= signal_wire_35;
    end
    assign signal_mux_89 = select ? signal_reg_34 : signal_reg_35;
    assign signal_cat_43 = { signal_const_37,
                             signal_mux_89 };
    assign signal_const_237 = 3'b000;
    assign signal_select_43 = value[2:0];
    assign signal_eq_100 = select == signal_const;
    assign signal_const_239 = 7'b0011000;
    assign signal_eq_101 = addr == signal_const_239;
    assign signal_and_108 = signal_eq_101 & signal_eq_100;
    assign signal_and_109 = signal_and_108 & signal_wire_63;
    assign signal_mux_90 = signal_and_109 ? signal_select_43 : signal_reg_36;
    assign signal_mux_91 = write ? signal_mux_90 : signal_reg_36;
    assign signal_wire_36 = signal_mux_91;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_36 <= signal_const_237;
        else
            signal_reg_36 <= signal_wire_36;
    end
    assign signal_select_44 = value[2:0];
    assign signal_eq_102 = select == signal_const_14;
    assign signal_eq_103 = addr == signal_const_239;
    assign signal_and_110 = signal_eq_103 & signal_eq_102;
    assign signal_and_111 = signal_and_110 & signal_wire_64;
    assign signal_mux_92 = signal_and_111 ? signal_select_44 : signal_reg_37;
    assign signal_mux_93 = write ? signal_mux_92 : signal_reg_37;
    assign signal_wire_37 = signal_mux_93;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_37 <= signal_const_237;
        else
            signal_reg_37 <= signal_wire_37;
    end
    assign signal_mux_94 = select ? signal_reg_36 : signal_reg_37;
    assign signal_cat_44 = { signal_const_63,
                             signal_mux_94 };
    assign signal_select_45 = value[4:0];
    assign signal_eq_104 = select == signal_const;
    assign signal_const_247 = 7'b0010111;
    assign signal_eq_105 = addr == signal_const_247;
    assign signal_and_112 = signal_eq_105 & signal_eq_104;
    assign signal_and_113 = signal_and_112 & signal_wire_63;
    assign signal_mux_95 = signal_and_113 ? signal_select_45 : signal_reg_38;
    assign signal_mux_96 = write ? signal_mux_95 : signal_reg_38;
    assign signal_wire_38 = signal_mux_96;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_38 <= signal_const_127;
        else
            signal_reg_38 <= signal_wire_38;
    end
    assign signal_select_46 = value[4:0];
    assign signal_eq_106 = select == signal_const_14;
    assign signal_eq_107 = addr == signal_const_247;
    assign signal_and_114 = signal_eq_107 & signal_eq_106;
    assign signal_and_115 = signal_and_114 & signal_wire_64;
    assign signal_mux_97 = signal_and_115 ? signal_select_46 : signal_reg_39;
    assign signal_mux_98 = write ? signal_mux_97 : signal_reg_39;
    assign signal_wire_39 = signal_mux_98;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_39 <= signal_const_127;
        else
            signal_reg_39 <= signal_wire_39;
    end
    assign signal_mux_99 = select ? signal_reg_38 : signal_reg_39;
    assign signal_cat_45 = { signal_const_37,
                             signal_mux_99 };
    assign signal_select_47 = value[4:0];
    assign signal_eq_108 = select == signal_const;
    assign signal_const_255 = 7'b0010110;
    assign signal_eq_109 = addr == signal_const_255;
    assign signal_and_116 = signal_eq_109 & signal_eq_108;
    assign signal_and_117 = signal_and_116 & signal_wire_63;
    assign signal_mux_100 = signal_and_117 ? signal_select_47 : signal_reg_40;
    assign signal_mux_101 = write ? signal_mux_100 : signal_reg_40;
    assign signal_wire_40 = signal_mux_101;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_40 <= signal_const_127;
        else
            signal_reg_40 <= signal_wire_40;
    end
    assign signal_select_48 = value[4:0];
    assign signal_eq_110 = select == signal_const_14;
    assign signal_eq_111 = addr == signal_const_255;
    assign signal_and_118 = signal_eq_111 & signal_eq_110;
    assign signal_and_119 = signal_and_118 & signal_wire_64;
    assign signal_mux_102 = signal_and_119 ? signal_select_48 : signal_reg_41;
    assign signal_mux_103 = write ? signal_mux_102 : signal_reg_41;
    assign signal_wire_41 = signal_mux_103;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_41 <= signal_const_127;
        else
            signal_reg_41 <= signal_wire_41;
    end
    assign signal_mux_104 = select ? signal_reg_40 : signal_reg_41;
    assign signal_cat_46 = { signal_const_37,
                             signal_mux_104 };
    assign signal_select_49 = value[4:0];
    assign signal_eq_112 = select == signal_const;
    assign signal_const_263 = 7'b0010101;
    assign signal_eq_113 = addr == signal_const_263;
    assign signal_and_120 = signal_eq_113 & signal_eq_112;
    assign signal_and_121 = signal_and_120 & signal_wire_63;
    assign signal_mux_105 = signal_and_121 ? signal_select_49 : signal_reg_42;
    assign signal_mux_106 = write ? signal_mux_105 : signal_reg_42;
    assign signal_wire_42 = signal_mux_106;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_42 <= signal_const_127;
        else
            signal_reg_42 <= signal_wire_42;
    end
    assign signal_select_50 = value[4:0];
    assign signal_eq_114 = select == signal_const_14;
    assign signal_eq_115 = addr == signal_const_263;
    assign signal_and_122 = signal_eq_115 & signal_eq_114;
    assign signal_and_123 = signal_and_122 & signal_wire_64;
    assign signal_mux_107 = signal_and_123 ? signal_select_50 : signal_reg_43;
    assign signal_mux_108 = write ? signal_mux_107 : signal_reg_43;
    assign signal_wire_43 = signal_mux_108;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_43 <= signal_const_127;
        else
            signal_reg_43 <= signal_wire_43;
    end
    assign signal_mux_109 = select ? signal_reg_42 : signal_reg_43;
    assign signal_cat_47 = { signal_const_37,
                             signal_mux_109 };
    assign signal_select_51 = value[4:0];
    assign signal_eq_116 = select == signal_const;
    assign signal_const_271 = 7'b0010100;
    assign signal_eq_117 = addr == signal_const_271;
    assign signal_and_124 = signal_eq_117 & signal_eq_116;
    assign signal_and_125 = signal_and_124 & signal_wire_63;
    assign signal_mux_110 = signal_and_125 ? signal_select_51 : signal_reg_44;
    assign signal_mux_111 = write ? signal_mux_110 : signal_reg_44;
    assign signal_wire_44 = signal_mux_111;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_44 <= signal_const_127;
        else
            signal_reg_44 <= signal_wire_44;
    end
    assign signal_select_52 = value[4:0];
    assign signal_eq_118 = select == signal_const_14;
    assign signal_eq_119 = addr == signal_const_271;
    assign signal_and_126 = signal_eq_119 & signal_eq_118;
    assign signal_and_127 = signal_and_126 & signal_wire_64;
    assign signal_mux_112 = signal_and_127 ? signal_select_52 : signal_reg_45;
    assign signal_mux_113 = write ? signal_mux_112 : signal_reg_45;
    assign signal_wire_45 = signal_mux_113;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_45 <= signal_const_127;
        else
            signal_reg_45 <= signal_wire_45;
    end
    assign signal_mux_114 = select ? signal_reg_44 : signal_reg_45;
    assign signal_cat_48 = { signal_const_37,
                             signal_mux_114 };
    assign signal_select_53 = value[4:0];
    assign signal_eq_120 = select == signal_const;
    assign signal_const_279 = 7'b0010011;
    assign signal_eq_121 = addr == signal_const_279;
    assign signal_and_128 = signal_eq_121 & signal_eq_120;
    assign signal_and_129 = signal_and_128 & signal_wire_63;
    assign signal_mux_115 = signal_and_129 ? signal_select_53 : signal_reg_46;
    assign signal_mux_116 = write ? signal_mux_115 : signal_reg_46;
    assign signal_wire_46 = signal_mux_116;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_46 <= signal_const_127;
        else
            signal_reg_46 <= signal_wire_46;
    end
    assign signal_select_54 = value[4:0];
    assign signal_eq_122 = select == signal_const_14;
    assign signal_eq_123 = addr == signal_const_279;
    assign signal_and_130 = signal_eq_123 & signal_eq_122;
    assign signal_and_131 = signal_and_130 & signal_wire_64;
    assign signal_mux_117 = signal_and_131 ? signal_select_54 : signal_reg_47;
    assign signal_mux_118 = write ? signal_mux_117 : signal_reg_47;
    assign signal_wire_47 = signal_mux_118;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_47 <= signal_const_127;
        else
            signal_reg_47 <= signal_wire_47;
    end
    assign signal_mux_119 = select ? signal_reg_46 : signal_reg_47;
    assign signal_cat_49 = { signal_const_37,
                             signal_mux_119 };
    assign signal_select_55 = value[0:0];
    assign signal_eq_124 = select == signal_const;
    assign signal_const_287 = 7'b0010010;
    assign signal_eq_125 = addr == signal_const_287;
    assign signal_and_132 = signal_eq_125 & signal_eq_124;
    assign signal_and_133 = signal_and_132 & signal_wire_63;
    assign signal_mux_120 = signal_and_133 ? signal_select_55 : signal_reg_48;
    assign signal_mux_121 = write ? signal_mux_120 : signal_reg_48;
    assign signal_wire_48 = signal_mux_121;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_48 <= signal_const_14;
        else
            signal_reg_48 <= signal_wire_48;
    end
    assign signal_select_56 = value[0:0];
    assign signal_eq_126 = select == signal_const_14;
    assign signal_eq_127 = addr == signal_const_287;
    assign signal_and_134 = signal_eq_127 & signal_eq_126;
    assign signal_and_135 = signal_and_134 & signal_wire_64;
    assign signal_mux_122 = signal_and_135 ? signal_select_56 : signal_reg_49;
    assign signal_mux_123 = write ? signal_mux_122 : signal_reg_49;
    assign signal_wire_49 = signal_mux_123;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_49 <= signal_const_14;
        else
            signal_reg_49 <= signal_wire_49;
    end
    assign signal_mux_124 = select ? signal_reg_48 : signal_reg_49;
    assign signal_cat_50 = { signal_const_35,
                             signal_mux_124 };
    assign signal_select_57 = value[4:0];
    assign signal_eq_128 = select == signal_const;
    assign signal_const_295 = 7'b0010001;
    assign signal_eq_129 = addr == signal_const_295;
    assign signal_and_136 = signal_eq_129 & signal_eq_128;
    assign signal_and_137 = signal_and_136 & signal_wire_63;
    assign signal_mux_125 = signal_and_137 ? signal_select_57 : signal_reg_50;
    assign signal_mux_126 = write ? signal_mux_125 : signal_reg_50;
    assign signal_wire_50 = signal_mux_126;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_50 <= signal_const_127;
        else
            signal_reg_50 <= signal_wire_50;
    end
    assign signal_select_58 = value[4:0];
    assign signal_eq_130 = select == signal_const_14;
    assign signal_eq_131 = addr == signal_const_295;
    assign signal_and_138 = signal_eq_131 & signal_eq_130;
    assign signal_and_139 = signal_and_138 & signal_wire_64;
    assign signal_mux_127 = signal_and_139 ? signal_select_58 : signal_reg_51;
    assign signal_mux_128 = write ? signal_mux_127 : signal_reg_51;
    assign signal_wire_51 = signal_mux_128;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_51 <= signal_const_127;
        else
            signal_reg_51 <= signal_wire_51;
    end
    assign signal_mux_129 = select ? signal_reg_50 : signal_reg_51;
    assign signal_cat_51 = { signal_const_37,
                             signal_mux_129 };
    assign signal_const_301 = 2'b00;
    assign signal_select_59 = value[1:0];
    assign signal_eq_132 = select == signal_const;
    assign signal_const_303 = 7'b0010000;
    assign signal_eq_133 = addr == signal_const_303;
    assign signal_and_140 = signal_eq_133 & signal_eq_132;
    assign signal_and_141 = signal_and_140 & signal_wire_63;
    assign signal_mux_130 = signal_and_141 ? signal_select_59 : signal_reg_52;
    assign signal_mux_131 = write ? signal_mux_130 : signal_reg_52;
    assign signal_wire_52 = signal_mux_131;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_52 <= signal_const_301;
        else
            signal_reg_52 <= signal_wire_52;
    end
    assign signal_select_60 = value[1:0];
    assign signal_eq_134 = select == signal_const_14;
    assign signal_eq_135 = addr == signal_const_303;
    assign signal_and_142 = signal_eq_135 & signal_eq_134;
    assign signal_and_143 = signal_and_142 & signal_wire_64;
    assign signal_mux_132 = signal_and_143 ? signal_select_60 : signal_reg_53;
    assign signal_mux_133 = write ? signal_mux_132 : signal_reg_53;
    assign signal_wire_53 = signal_mux_133;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            signal_reg_53 <= signal_const_301;
        else
            signal_reg_53 <= signal_wire_53;
    end
    assign signal_mux_134 = select ? signal_reg_52 : signal_reg_53;
    assign signal_cat_52 = { signal_const_79,
                             signal_mux_134 };
    assign signal_cat_53 = { signal_const_35,
                             select };
    assign signal_const_312 = 9'b000000001;
    assign signal_add = program_addr + signal_const_312;
    assign signal_select_61 = value[8:0];
    assign signal_const_313 = 7'b0001001;
    assign signal_eq_136 = addr == signal_const_313;
    assign signal_mux_135 = signal_eq_136 ? signal_select_61 : program_addr;
    assign signal_eq_137 = addr == signal_const_11;
    assign signal_mux_136 = signal_eq_137 ? signal_add : signal_mux_135;
    assign signal_mux_137 = write ? signal_mux_136 : program_addr;
    assign signal_wire_54 = signal_mux_137;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            program_addr <= signal_const_103;
        else
            program_addr <= signal_wire_54;
    end
    assign signal_cat_54 = { signal_const_1,
                             program_addr };
    assign signal_wire_55 = status$rx_head_1;
    assign signal_wire_56 = status$rx_head_0;
    assign signal_mux_138 = select ? signal_wire_55 : signal_wire_56;
    assign signal_select_62 = signal_mux_139[23:16];
    assign signal_cat_55 = { signal_const_86,
                             signal_select_62 };
    assign signal_wire_57 = status$capture_1;
    assign signal_wire_58 = status$capture_0;
    assign signal_mux_139 = select ? signal_wire_57 : signal_wire_58;
    assign signal_select_63 = signal_mux_139[15:0];
    assign signal_select_64 = signal_mux_140[23:16];
    assign signal_cat_56 = { signal_const_86,
                             signal_select_64 };
    assign signal_wire_59 = status$now_1;
    assign signal_wire_60 = status$now_0;
    assign signal_mux_140 = select ? signal_wire_59 : signal_wire_60;
    assign signal_select_65 = signal_mux_140[15:0];
    assign signal_wire_61 = status$pc_1;
    assign signal_wire_62 = status$pc_0;
    assign signal_mux_141 = select ? signal_wire_61 : signal_wire_62;
    assign signal_cat_57 = { signal_const_1,
                             signal_mux_141 };
    assign signal_wire_63 = status$halted_1;
    assign signal_wire_64 = status$halted_0;
    assign signal_mux_142 = select ? signal_wire_63 : signal_wire_64;
    assign signal_mux_143 = select ? signal_wire_78 : signal_wire_77;
    assign signal_wire_65 = status$fault$underflow_1;
    assign signal_wire_66 = status$fault$underflow_0;
    assign signal_mux_144 = select ? signal_wire_65 : signal_wire_66;
    assign signal_wire_67 = status$fault$overflow_1;
    assign signal_wire_68 = status$fault$overflow_0;
    assign signal_mux_145 = select ? signal_wire_67 : signal_wire_68;
    assign signal_wire_69 = status$fault$missed_deadline_1;
    assign signal_wire_70 = status$fault$missed_deadline_0;
    assign signal_mux_146 = select ? signal_wire_69 : signal_wire_70;
    assign signal_wire_71 = status$fault$decode_1;
    assign signal_wire_72 = status$fault$decode_0;
    assign signal_mux_147 = select ? signal_wire_71 : signal_wire_72;
    assign signal_wire_73 = status$tx_level_1;
    assign signal_wire_74 = status$tx_level_0;
    assign signal_mux_148 = select ? signal_wire_73 : signal_wire_74;
    assign signal_wire_75 = status$rx_level_1;
    assign signal_wire_76 = status$rx_level_0;
    assign signal_mux_149 = select ? signal_wire_75 : signal_wire_76;
    assign signal_wire_77 = status$irq_0;
    assign signal_wire_78 = status$irq_1;
    always @* begin
        case (sm)
        2'b01:
            signal_cases <= signal_select_68;
        default:
            signal_cases <= high;
        endcase
    end
    assign signal_mux_150 = signal_select_71 ? signal_cases : high;
    assign signal_wire_79 = signal_mux_150;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            high <= signal_const_86;
        else
            high <= signal_wire_79;
    end
    assign value = { high,
                     signal_select_68 };
    assign signal_select_66 = value[0:0];
    assign signal_const_329 = 7'b0001011;
    assign signal_eq_138 = addr == signal_const_329;
    assign signal_mux_151 = signal_eq_138 ? signal_select_66 : select;
    assign signal_mux_152 = is_write ? vdd : gnd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_1 <= signal_mux_152;
        default:
            signal_cases_1 <= gnd;
        endcase
    end
    assign signal_mux_153 = signal_select_71 ? signal_cases_1 : gnd;
    assign write = signal_mux_153;
    assign signal_mux_154 = write ? signal_mux_151 : select;
    assign signal_wire_80 = signal_mux_154;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            select <= signal_const_14;
        else
            select <= signal_wire_80;
    end
    assign signal_mux_155 = select ? signal_wire_77 : signal_wire_78;
    assign signal_cat_58 = { signal_mux_155,
                             signal_const_14,
                             signal_mux_149,
                             signal_mux_148,
                             signal_mux_147,
                             signal_mux_146,
                             signal_mux_145,
                             signal_mux_144,
                             signal_mux_143,
                             signal_mux_142 };
    assign signal_select_67 = signal_select_68[6:0];
    always @* begin
        case (signal_select_67)
        7'b0000001:
            first_read <= signal_cat_58;
        7'b0000010:
            first_read <= signal_cat_57;
        7'b0000011:
            first_read <= signal_select_65;
        7'b0000100:
            first_read <= signal_cat_56;
        7'b0000101:
            first_read <= signal_select_63;
        7'b0000110:
            first_read <= signal_cat_55;
        7'b0001000:
            first_read <= signal_mux_138;
        7'b0001001:
            first_read <= signal_cat_54;
        7'b0001011:
            first_read <= signal_cat_53;
        7'b0010000:
            first_read <= signal_cat_52;
        7'b0010001:
            first_read <= signal_cat_51;
        7'b0010010:
            first_read <= signal_cat_50;
        7'b0010011:
            first_read <= signal_cat_49;
        7'b0010100:
            first_read <= signal_cat_48;
        7'b0010101:
            first_read <= signal_cat_47;
        7'b0010110:
            first_read <= signal_cat_46;
        7'b0010111:
            first_read <= signal_cat_45;
        7'b0011000:
            first_read <= signal_cat_44;
        7'b0011001:
            first_read <= signal_cat_43;
        7'b0011010:
            first_read <= signal_cat_42;
        7'b0011011:
            first_read <= signal_cat_41;
        7'b0011100:
            first_read <= signal_cat_40;
        7'b0011101:
            first_read <= signal_cat_39;
        7'b0011110:
            first_read <= signal_cat_38;
        7'b0011111:
            first_read <= signal_cat_37;
        7'b0100000:
            first_read <= signal_cat_36;
        7'b0100001:
            first_read <= signal_cat_35;
        7'b0100010:
            first_read <= signal_cat_34;
        7'b0100011:
            first_read <= signal_mux_39;
        7'b0100100:
            first_read <= signal_mux_34;
        7'b0100101:
            first_read <= signal_cat_33;
        7'b0100110:
            first_read <= signal_cat_32;
        7'b0100111:
            first_read <= signal_cat_31;
        7'b0101000:
            first_read <= signal_cat_30;
        7'b0101001:
            first_read <= signal_cat_29;
        7'b0101010:
            first_read <= signal_mux_4;
        default:
            first_read <= signal_const_28;
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
    assign signal_mux_156 = signal_select_71 ? signal_cases_2 : word;
    assign vdd = 1'b1;
    assign is_write = cmd[7:7];
    assign signal_mux_157 = is_write ? gnd : vdd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_3 <= signal_mux_157;
        default:
            signal_cases_3 <= gnd;
        endcase
    end
    assign gnd = 1'b0;
    assign signal_mux_158 = signal_select_71 ? signal_cases_3 : gnd;
    assign read_done = signal_mux_158;
    assign signal_mux_159 = read_done ? read_value : signal_mux_156;
    assign signal_wire_81 = signal_mux_159;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            word <= signal_const_28;
        else
            word <= signal_wire_81;
    end
    assign signal_select_68 = signal_inst[8:1];
    always @* begin
        case (sm)
        2'b00:
            signal_cases_4 <= signal_select_68;
        default:
            signal_cases_4 <= cmd;
        endcase
    end
    assign signal_mux_160 = signal_select_71 ? signal_cases_4 : cmd;
    assign signal_wire_82 = signal_mux_160;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            cmd <= signal_const_86;
        else
            cmd <= signal_wire_82;
    end
    assign addr = cmd[6:0];
    assign signal_eq_139 = addr == signal_const_7;
    assign tx_word = signal_eq_139 ? signal_mux_138 : word;
    assign signal_select_69 = tx_word[15:8];
    assign signal_const_334 = 2'b01;
    always @* begin
        case (sm)
        2'b00:
            signal_cases_5 <= signal_const_334;
        2'b01:
            signal_cases_5 <= signal_const_336;
        2'b10:
            signal_cases_5 <= signal_const_334;
        default:
            signal_cases_5 <= signal_mux_161;
        endcase
    end
    assign signal_select_70 = signal_inst[10:10];
    assign signal_mux_161 = signal_select_70 ? signal_const_301 : sm;
    assign signal_select_71 = signal_inst[9:9];
    assign signal_mux_162 = signal_select_71 ? signal_cases_5 : signal_mux_161;
    assign signal_wire_83 = signal_mux_162;
    always @(posedge signal_wire_88) begin
        if (signal_wire_87)
            sm <= signal_const_301;
        else
            sm <= signal_wire_83;
    end
    assign signal_const_336 = 2'b10;
    assign signal_eq_140 = signal_const_336 == sm;
    assign signal_mux_163 = signal_eq_140 ? signal_select_8 : signal_select_69;
    assign signal_wire_84 = cs_n;
    assign signal_wire_85 = mosi;
    assign signal_wire_86 = sck;
    assign signal_wire_87 = clear;
    assign signal_wire_88 = clock;
    host_spi
        host_spi
        ( .clock(signal_wire_88),
          .clear(signal_wire_87),
          .sck(signal_wire_86),
          .mosi(signal_wire_85),
          .cs_n(signal_wire_84),
          .tx_byte(signal_mux_163),
          .miso(signal_inst[0:0]),
          .rx_byte(signal_inst[8:1]),
          .rx_valid(signal_inst[9:9]),
          .frame_start(signal_inst[10:10]),
          .frame_end(signal_inst[11:11]) );
    assign signal_select_72 = signal_inst[0:0];
    assign miso = signal_select_72;
    assign engines$config$side_set_count_0 = signal_reg_53;
    assign engines$config$side_set_base_0 = signal_reg_51;
    assign engines$config$side_set_pindirs_0 = signal_reg_49;
    assign engines$config$in_base_0 = signal_reg_47;
    assign engines$config$in_count_0 = signal_reg_45;
    assign engines$config$out_base_0 = signal_reg_43;
    assign engines$config$out_count_0 = signal_reg_41;
    assign engines$config$set_base_0 = signal_reg_39;
    assign engines$config$set_count_0 = signal_reg_37;
    assign engines$config$jmp_pin_0 = signal_reg_35;
    assign engines$config$capture_pin_0 = signal_reg_33;
    assign engines$config$capture_rising_0 = signal_reg_31;
    assign engines$config$in_shift_right_0 = signal_reg_29;
    assign engines$config$out_shift_right_0 = signal_reg_27;
    assign engines$config$autopush_0 = signal_reg_25;
    assign engines$config$push_threshold_0 = signal_reg_23;
    assign engines$config$autopull_0 = signal_reg_21;
    assign engines$config$pull_threshold_0 = signal_reg_19;
    assign engines$config$crc_width_0 = signal_reg_17;
    assign engines$config$crc_poly_0 = signal_reg_15;
    assign engines$config$crc_init_0 = signal_reg_13;
    assign engines$config$crc_reflect_0 = signal_reg_11;
    assign engines$config$stuff_threshold_0 = signal_reg_9;
    assign engines$config$stuff_level_0 = signal_reg_7;
    assign engines$config$wrap_bottom_0 = signal_reg_5;
    assign engines$config$wrap_top_0 = signal_reg_3;
    assign engines$config$period_fraction_0 = signal_reg_1;
    assign engines$start_0 = signal_and_35;
    assign engines$program_write$valid_0 = signal_and_32;
    assign engines$program_write$addr_0 = program_addr;
    assign engines$program_write$data_0 = value;
    assign engines$tx$valid_0 = signal_and_30;
    assign engines$tx$value_0 = value;
    assign engines$rx_pop_0 = signal_and_28;
    assign engines$clear_irq_0 = signal_and_26;
    assign engines$stop_0 = signal_and_23;
    assign engines$flush_0 = signal_and_20;
    assign engines$config$side_set_count_1 = signal_reg_52;
    assign engines$config$side_set_base_1 = signal_reg_50;
    assign engines$config$side_set_pindirs_1 = signal_reg_48;
    assign engines$config$in_base_1 = signal_reg_46;
    assign engines$config$in_count_1 = signal_reg_44;
    assign engines$config$out_base_1 = signal_reg_42;
    assign engines$config$out_count_1 = signal_reg_40;
    assign engines$config$set_base_1 = signal_reg_38;
    assign engines$config$set_count_1 = signal_reg_36;
    assign engines$config$jmp_pin_1 = signal_reg_34;
    assign engines$config$capture_pin_1 = signal_reg_32;
    assign engines$config$capture_rising_1 = signal_reg_30;
    assign engines$config$in_shift_right_1 = signal_reg_28;
    assign engines$config$out_shift_right_1 = signal_reg_26;
    assign engines$config$autopush_1 = signal_reg_24;
    assign engines$config$push_threshold_1 = signal_reg_22;
    assign engines$config$autopull_1 = signal_reg_20;
    assign engines$config$pull_threshold_1 = signal_reg_18;
    assign engines$config$crc_width_1 = signal_reg_16;
    assign engines$config$crc_poly_1 = signal_reg_14;
    assign engines$config$crc_init_1 = signal_reg_12;
    assign engines$config$crc_reflect_1 = signal_reg_10;
    assign engines$config$stuff_threshold_1 = signal_reg_8;
    assign engines$config$stuff_level_1 = signal_reg_6;
    assign engines$config$wrap_bottom_1 = signal_reg_4;
    assign engines$config$wrap_top_1 = signal_reg_2;
    assign engines$config$period_fraction_1 = signal_reg;
    assign engines$start_1 = signal_and_17;
    assign engines$program_write$valid_1 = signal_and_14;
    assign engines$program_write$addr_1 = program_addr;
    assign engines$program_write$data_1 = value;
    assign engines$tx$valid_1 = signal_and_12;
    assign engines$tx$value_1 = value;
    assign engines$rx_pop_1 = signal_and_10;
    assign engines$clear_irq_1 = signal_and_8;
    assign engines$stop_1 = signal_and_5;
    assign engines$flush_1 = signal_and_2;

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
    wire signal_select_8;
    wire [15:0] signal_select_9;
    wire signal_select_10;
    wire [15:0] signal_select_11;
    wire [8:0] signal_select_12;
    wire signal_select_13;
    wire signal_select_14;
    wire [15:0] signal_select_15;
    wire [8:0] signal_select_16;
    wire [8:0] signal_select_17;
    wire signal_select_18;
    wire [4:0] signal_select_19;
    wire signal_select_20;
    wire [15:0] signal_select_21;
    wire [15:0] signal_select_22;
    wire [4:0] signal_select_23;
    wire [4:0] signal_select_24;
    wire signal_select_25;
    wire [4:0] signal_select_26;
    wire signal_select_27;
    wire signal_select_28;
    wire signal_select_29;
    wire signal_select_30;
    wire [4:0] signal_select_31;
    wire [4:0] signal_select_32;
    wire [2:0] signal_select_33;
    wire [4:0] signal_select_34;
    wire [4:0] signal_select_35;
    wire [4:0] signal_select_36;
    wire [4:0] signal_select_37;
    wire [4:0] signal_select_38;
    wire signal_select_39;
    wire [4:0] signal_select_40;
    wire [1:0] signal_select_41;
    wire signal_select_42;
    wire signal_select_43;
    wire signal_select_44;
    wire signal_select_45;
    wire [15:0] signal_select_46;
    wire signal_select_47;
    wire [15:0] signal_select_48;
    wire [8:0] signal_select_49;
    wire signal_select_50;
    wire signal_select_51;
    wire [15:0] signal_select_52;
    wire [8:0] signal_select_53;
    wire [8:0] signal_select_54;
    wire signal_select_55;
    wire [4:0] signal_select_56;
    wire signal_select_57;
    wire [15:0] signal_select_58;
    wire [15:0] signal_select_59;
    wire [4:0] signal_select_60;
    wire [4:0] signal_select_61;
    wire signal_select_62;
    wire [4:0] signal_select_63;
    wire signal_select_64;
    wire signal_select_65;
    wire signal_select_66;
    wire signal_select_67;
    wire [4:0] signal_select_68;
    wire [4:0] signal_select_69;
    wire [2:0] signal_select_70;
    wire [4:0] signal_select_71;
    wire [4:0] signal_select_72;
    wire [4:0] signal_select_73;
    wire [4:0] signal_select_74;
    wire [4:0] signal_select_75;
    wire signal_select_76;
    wire [4:0] signal_select_77;
    wire [15:0] signal_select_78;
    wire [15:0] signal_wire_1;
    wire [3:0] signal_select_79;
    wire [3:0] signal_wire_2;
    wire [3:0] signal_select_80;
    wire [3:0] signal_wire_3;
    wire signal_select_81;
    wire signal_wire_4;
    wire signal_select_82;
    wire signal_wire_5;
    wire signal_select_83;
    wire signal_wire_6;
    wire signal_select_84;
    wire signal_wire_7;
    wire signal_select_85;
    wire signal_wire_8;
    wire signal_select_86;
    wire signal_wire_9;
    wire [23:0] signal_select_87;
    wire [23:0] signal_wire_10;
    wire [23:0] signal_select_88;
    wire [23:0] signal_wire_11;
    wire [8:0] signal_select_89;
    wire [8:0] signal_wire_12;
    wire [15:0] signal_select_90;
    wire [15:0] signal_wire_13;
    wire [3:0] signal_select_91;
    wire [3:0] signal_wire_14;
    wire [3:0] signal_select_92;
    wire [3:0] signal_wire_15;
    wire signal_select_93;
    wire signal_wire_16;
    wire signal_select_94;
    wire signal_wire_17;
    wire signal_select_95;
    wire signal_wire_18;
    wire signal_select_96;
    wire signal_wire_19;
    wire signal_select_97;
    wire signal_wire_20;
    wire signal_select_98;
    wire signal_wire_21;
    wire [23:0] signal_select_99;
    wire [23:0] signal_wire_22;
    wire [23:0] signal_select_100;
    wire [23:0] signal_wire_23;
    wire [8:0] signal_select_101;
    wire [8:0] signal_wire_24;
    wire signal_select_102;
    wire signal_select_103;
    wire [7:0] signal_wire_25;
    wire signal_select_104;
    wire [374:0] signal_inst;
    wire [1:0] signal_select_105;
    wire signal_const_5;
    wire signal_wire_26;
    wire signal_not;
    wire vdd;
    reg signal_reg_4;
    reg reset_done;
    wire signal_not_1;
    wire signal_wire_27;
    wire [689:0] signal_inst_1;
    wire [19:0] signal_select_106;
    wire [6:0] signal_select_107;
    wire [7:0] signal_cat;
    assign signal_select = signal_inst_1[689:670];
    assign signal_select_1 = signal_select[19:12];
    assign signal_select_2 = signal_select_106[19:12];
    assign signal_select_3 = signal_inst[0:0];
    assign signal_const = 5'b00000;
    assign signal_select_4 = signal_wire_25[7:3];
    always @(posedge signal_wire_27) begin
        if (signal_not_1)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_select_4;
    end
    always @(posedge signal_wire_27) begin
        if (signal_not_1)
            signal_reg_1 <= signal_const;
        else
            signal_reg_1 <= signal_reg;
    end
    assign signal_const_2 = 7'b0000000;
    assign signal_const_3 = 8'b00000000;
    assign signal_wire = uio_in;
    always @(posedge signal_wire_27) begin
        if (signal_not_1)
            signal_reg_2 <= signal_const_3;
        else
            signal_reg_2 <= signal_wire;
    end
    always @(posedge signal_wire_27) begin
        if (signal_not_1)
            signal_reg_3 <= signal_const_3;
        else
            signal_reg_3 <= signal_reg_2;
    end
    assign inputs = { signal_reg_3,
                      signal_const_2,
                      signal_reg_1 };
    assign signal_select_5 = signal_inst[374:374];
    assign signal_select_6 = signal_inst[373:373];
    assign signal_select_7 = signal_inst[372:372];
    assign signal_select_8 = signal_inst[371:371];
    assign signal_select_9 = signal_inst[370:355];
    assign signal_select_10 = signal_inst[354:354];
    assign signal_select_11 = signal_inst[353:338];
    assign signal_select_12 = signal_inst[337:329];
    assign signal_select_13 = signal_inst[328:328];
    assign signal_select_14 = signal_inst[327:327];
    assign signal_select_15 = signal_inst[326:311];
    assign signal_select_16 = signal_inst[310:302];
    assign signal_select_17 = signal_inst[301:293];
    assign signal_select_18 = signal_inst[292:292];
    assign signal_select_19 = signal_inst[291:287];
    assign signal_select_20 = signal_inst[286:286];
    assign signal_select_21 = signal_inst[285:270];
    assign signal_select_22 = signal_inst[269:254];
    assign signal_select_23 = signal_inst[253:249];
    assign signal_select_24 = signal_inst[248:244];
    assign signal_select_25 = signal_inst[243:243];
    assign signal_select_26 = signal_inst[242:238];
    assign signal_select_27 = signal_inst[237:237];
    assign signal_select_28 = signal_inst[236:236];
    assign signal_select_29 = signal_inst[235:235];
    assign signal_select_30 = signal_inst[234:234];
    assign signal_select_31 = signal_inst[233:229];
    assign signal_select_32 = signal_inst[228:224];
    assign signal_select_33 = signal_inst[223:221];
    assign signal_select_34 = signal_inst[220:216];
    assign signal_select_35 = signal_inst[215:211];
    assign signal_select_36 = signal_inst[210:206];
    assign signal_select_37 = signal_inst[205:201];
    assign signal_select_38 = signal_inst[200:196];
    assign signal_select_39 = signal_inst[195:195];
    assign signal_select_40 = signal_inst[194:190];
    assign signal_select_41 = signal_inst[189:188];
    assign signal_select_42 = signal_inst[187:187];
    assign signal_select_43 = signal_inst[186:186];
    assign signal_select_44 = signal_inst[185:185];
    assign signal_select_45 = signal_inst[184:184];
    assign signal_select_46 = signal_inst[183:168];
    assign signal_select_47 = signal_inst[167:167];
    assign signal_select_48 = signal_inst[166:151];
    assign signal_select_49 = signal_inst[150:142];
    assign signal_select_50 = signal_inst[141:141];
    assign signal_select_51 = signal_inst[140:140];
    assign signal_select_52 = signal_inst[139:124];
    assign signal_select_53 = signal_inst[123:115];
    assign signal_select_54 = signal_inst[114:106];
    assign signal_select_55 = signal_inst[105:105];
    assign signal_select_56 = signal_inst[104:100];
    assign signal_select_57 = signal_inst[99:99];
    assign signal_select_58 = signal_inst[98:83];
    assign signal_select_59 = signal_inst[82:67];
    assign signal_select_60 = signal_inst[66:62];
    assign signal_select_61 = signal_inst[61:57];
    assign signal_select_62 = signal_inst[56:56];
    assign signal_select_63 = signal_inst[55:51];
    assign signal_select_64 = signal_inst[50:50];
    assign signal_select_65 = signal_inst[49:49];
    assign signal_select_66 = signal_inst[48:48];
    assign signal_select_67 = signal_inst[47:47];
    assign signal_select_68 = signal_inst[46:42];
    assign signal_select_69 = signal_inst[41:37];
    assign signal_select_70 = signal_inst[36:34];
    assign signal_select_71 = signal_inst[33:29];
    assign signal_select_72 = signal_inst[28:24];
    assign signal_select_73 = signal_inst[23:19];
    assign signal_select_74 = signal_inst[18:14];
    assign signal_select_75 = signal_inst[13:9];
    assign signal_select_76 = signal_inst[8:8];
    assign signal_select_77 = signal_inst[7:3];
    assign signal_select_78 = signal_inst_1[603:588];
    assign signal_wire_1 = signal_select_78;
    assign signal_select_79 = signal_inst_1[587:584];
    assign signal_wire_2 = signal_select_79;
    assign signal_select_80 = signal_inst_1[583:580];
    assign signal_wire_3 = signal_select_80;
    assign signal_select_81 = signal_inst_1[554:554];
    assign signal_wire_4 = signal_select_81;
    assign signal_select_82 = signal_inst_1[553:553];
    assign signal_wire_5 = signal_select_82;
    assign signal_select_83 = signal_inst_1[552:552];
    assign signal_wire_6 = signal_select_83;
    assign signal_select_84 = signal_inst_1[551:551];
    assign signal_wire_7 = signal_select_84;
    assign signal_select_85 = signal_inst_1[550:550];
    assign signal_wire_8 = signal_select_85;
    assign signal_select_86 = signal_inst_1[549:549];
    assign signal_wire_9 = signal_select_86;
    assign signal_select_87 = signal_inst_1[578:555];
    assign signal_wire_10 = signal_select_87;
    assign signal_select_88 = signal_inst_1[543:520];
    assign signal_wire_11 = signal_select_88;
    assign signal_select_89 = signal_inst_1[389:381];
    assign signal_wire_12 = signal_select_89;
    assign signal_select_90 = signal_inst_1[278:263];
    assign signal_wire_13 = signal_select_90;
    assign signal_select_91 = signal_inst_1[262:259];
    assign signal_wire_14 = signal_select_91;
    assign signal_select_92 = signal_inst_1[258:255];
    assign signal_wire_15 = signal_select_92;
    assign signal_select_93 = signal_inst_1[229:229];
    assign signal_wire_16 = signal_select_93;
    assign signal_select_94 = signal_inst_1[228:228];
    assign signal_wire_17 = signal_select_94;
    assign signal_select_95 = signal_inst_1[227:227];
    assign signal_wire_18 = signal_select_95;
    assign signal_select_96 = signal_inst_1[226:226];
    assign signal_wire_19 = signal_select_96;
    assign signal_select_97 = signal_inst_1[225:225];
    assign signal_wire_20 = signal_select_97;
    assign signal_select_98 = signal_inst_1[224:224];
    assign signal_wire_21 = signal_select_98;
    assign signal_select_99 = signal_inst_1[253:230];
    assign signal_wire_22 = signal_select_99;
    assign signal_select_100 = signal_inst_1[218:195];
    assign signal_wire_23 = signal_select_100;
    assign signal_select_101 = signal_inst_1[64:56];
    assign signal_wire_24 = signal_select_101;
    assign signal_select_102 = signal_wire_25[2:2];
    assign signal_select_103 = signal_wire_25[1:1];
    assign signal_wire_25 = ui_in;
    assign signal_select_104 = signal_wire_25[0:0];
    host_port
        host_port
        ( .clock(signal_wire_27),
          .clear(signal_not_1),
          .sck(signal_select_104),
          .mosi(signal_select_103),
          .cs_n(signal_select_102),
          .status$pc_0(signal_wire_24),
          .status$now_0(signal_wire_23),
          .status$capture_0(signal_wire_22),
          .status$halted_0(signal_wire_21),
          .status$irq_0(signal_wire_20),
          .status$fault$underflow_0(signal_wire_19),
          .status$fault$overflow_0(signal_wire_18),
          .status$fault$missed_deadline_0(signal_wire_17),
          .status$fault$decode_0(signal_wire_16),
          .status$tx_level_0(signal_wire_15),
          .status$rx_level_0(signal_wire_14),
          .status$rx_head_0(signal_wire_13),
          .status$pc_1(signal_wire_12),
          .status$now_1(signal_wire_11),
          .status$capture_1(signal_wire_10),
          .status$halted_1(signal_wire_9),
          .status$irq_1(signal_wire_8),
          .status$fault$underflow_1(signal_wire_7),
          .status$fault$overflow_1(signal_wire_6),
          .status$fault$missed_deadline_1(signal_wire_5),
          .status$fault$decode_1(signal_wire_4),
          .status$tx_level_1(signal_wire_3),
          .status$rx_level_1(signal_wire_2),
          .status$rx_head_1(signal_wire_1),
          .miso(signal_inst[0:0]),
          .engines$config$side_set_count_0(signal_inst[2:1]),
          .engines$config$side_set_base_0(signal_inst[7:3]),
          .engines$config$side_set_pindirs_0(signal_inst[8:8]),
          .engines$config$in_base_0(signal_inst[13:9]),
          .engines$config$in_count_0(signal_inst[18:14]),
          .engines$config$out_base_0(signal_inst[23:19]),
          .engines$config$out_count_0(signal_inst[28:24]),
          .engines$config$set_base_0(signal_inst[33:29]),
          .engines$config$set_count_0(signal_inst[36:34]),
          .engines$config$jmp_pin_0(signal_inst[41:37]),
          .engines$config$capture_pin_0(signal_inst[46:42]),
          .engines$config$capture_rising_0(signal_inst[47:47]),
          .engines$config$in_shift_right_0(signal_inst[48:48]),
          .engines$config$out_shift_right_0(signal_inst[49:49]),
          .engines$config$autopush_0(signal_inst[50:50]),
          .engines$config$push_threshold_0(signal_inst[55:51]),
          .engines$config$autopull_0(signal_inst[56:56]),
          .engines$config$pull_threshold_0(signal_inst[61:57]),
          .engines$config$crc_width_0(signal_inst[66:62]),
          .engines$config$crc_poly_0(signal_inst[82:67]),
          .engines$config$crc_init_0(signal_inst[98:83]),
          .engines$config$crc_reflect_0(signal_inst[99:99]),
          .engines$config$stuff_threshold_0(signal_inst[104:100]),
          .engines$config$stuff_level_0(signal_inst[105:105]),
          .engines$config$wrap_bottom_0(signal_inst[114:106]),
          .engines$config$wrap_top_0(signal_inst[123:115]),
          .engines$config$period_fraction_0(signal_inst[139:124]),
          .engines$start_0(signal_inst[140:140]),
          .engines$program_write$valid_0(signal_inst[141:141]),
          .engines$program_write$addr_0(signal_inst[150:142]),
          .engines$program_write$data_0(signal_inst[166:151]),
          .engines$tx$valid_0(signal_inst[167:167]),
          .engines$tx$value_0(signal_inst[183:168]),
          .engines$rx_pop_0(signal_inst[184:184]),
          .engines$clear_irq_0(signal_inst[185:185]),
          .engines$stop_0(signal_inst[186:186]),
          .engines$flush_0(signal_inst[187:187]),
          .engines$config$side_set_count_1(signal_inst[189:188]),
          .engines$config$side_set_base_1(signal_inst[194:190]),
          .engines$config$side_set_pindirs_1(signal_inst[195:195]),
          .engines$config$in_base_1(signal_inst[200:196]),
          .engines$config$in_count_1(signal_inst[205:201]),
          .engines$config$out_base_1(signal_inst[210:206]),
          .engines$config$out_count_1(signal_inst[215:211]),
          .engines$config$set_base_1(signal_inst[220:216]),
          .engines$config$set_count_1(signal_inst[223:221]),
          .engines$config$jmp_pin_1(signal_inst[228:224]),
          .engines$config$capture_pin_1(signal_inst[233:229]),
          .engines$config$capture_rising_1(signal_inst[234:234]),
          .engines$config$in_shift_right_1(signal_inst[235:235]),
          .engines$config$out_shift_right_1(signal_inst[236:236]),
          .engines$config$autopush_1(signal_inst[237:237]),
          .engines$config$push_threshold_1(signal_inst[242:238]),
          .engines$config$autopull_1(signal_inst[243:243]),
          .engines$config$pull_threshold_1(signal_inst[248:244]),
          .engines$config$crc_width_1(signal_inst[253:249]),
          .engines$config$crc_poly_1(signal_inst[269:254]),
          .engines$config$crc_init_1(signal_inst[285:270]),
          .engines$config$crc_reflect_1(signal_inst[286:286]),
          .engines$config$stuff_threshold_1(signal_inst[291:287]),
          .engines$config$stuff_level_1(signal_inst[292:292]),
          .engines$config$wrap_bottom_1(signal_inst[301:293]),
          .engines$config$wrap_top_1(signal_inst[310:302]),
          .engines$config$period_fraction_1(signal_inst[326:311]),
          .engines$start_1(signal_inst[327:327]),
          .engines$program_write$valid_1(signal_inst[328:328]),
          .engines$program_write$addr_1(signal_inst[337:329]),
          .engines$program_write$data_1(signal_inst[353:338]),
          .engines$tx$valid_1(signal_inst[354:354]),
          .engines$tx$value_1(signal_inst[370:355]),
          .engines$rx_pop_1(signal_inst[371:371]),
          .engines$clear_irq_1(signal_inst[372:372]),
          .engines$stop_1(signal_inst[373:373]),
          .engines$flush_1(signal_inst[374:374]) );
    assign signal_select_105 = signal_inst[2:1];
    assign signal_const_5 = 1'b0;
    assign signal_wire_26 = rst_n;
    assign signal_not = ~ signal_wire_26;
    assign vdd = 1'b1;
    always @(posedge signal_wire_27 or posedge signal_not) begin
        if (signal_not)
            signal_reg_4 <= signal_const_5;
        else
            signal_reg_4 <= vdd;
    end
    always @(posedge signal_wire_27 or posedge signal_not) begin
        if (signal_not)
            reset_done <= signal_const_5;
        else
            reset_done <= signal_reg_4;
    end
    assign signal_not_1 = ~ reset_done;
    assign signal_wire_27 = clk;
    engines
        engines
        ( .clock(signal_wire_27),
          .clear(signal_not_1),
          .hosts$config$side_set_count_0(signal_select_105),
          .hosts$config$side_set_base_0(signal_select_77),
          .hosts$config$side_set_pindirs_0(signal_select_76),
          .hosts$config$in_base_0(signal_select_75),
          .hosts$config$in_count_0(signal_select_74),
          .hosts$config$out_base_0(signal_select_73),
          .hosts$config$out_count_0(signal_select_72),
          .hosts$config$set_base_0(signal_select_71),
          .hosts$config$set_count_0(signal_select_70),
          .hosts$config$jmp_pin_0(signal_select_69),
          .hosts$config$capture_pin_0(signal_select_68),
          .hosts$config$capture_rising_0(signal_select_67),
          .hosts$config$in_shift_right_0(signal_select_66),
          .hosts$config$out_shift_right_0(signal_select_65),
          .hosts$config$autopush_0(signal_select_64),
          .hosts$config$push_threshold_0(signal_select_63),
          .hosts$config$autopull_0(signal_select_62),
          .hosts$config$pull_threshold_0(signal_select_61),
          .hosts$config$crc_width_0(signal_select_60),
          .hosts$config$crc_poly_0(signal_select_59),
          .hosts$config$crc_init_0(signal_select_58),
          .hosts$config$crc_reflect_0(signal_select_57),
          .hosts$config$stuff_threshold_0(signal_select_56),
          .hosts$config$stuff_level_0(signal_select_55),
          .hosts$config$wrap_bottom_0(signal_select_54),
          .hosts$config$wrap_top_0(signal_select_53),
          .hosts$config$period_fraction_0(signal_select_52),
          .hosts$start_0(signal_select_51),
          .hosts$program_write$valid_0(signal_select_50),
          .hosts$program_write$addr_0(signal_select_49),
          .hosts$program_write$data_0(signal_select_48),
          .hosts$tx$valid_0(signal_select_47),
          .hosts$tx$value_0(signal_select_46),
          .hosts$rx_pop_0(signal_select_45),
          .hosts$clear_irq_0(signal_select_44),
          .hosts$stop_0(signal_select_43),
          .hosts$flush_0(signal_select_42),
          .hosts$config$side_set_count_1(signal_select_41),
          .hosts$config$side_set_base_1(signal_select_40),
          .hosts$config$side_set_pindirs_1(signal_select_39),
          .hosts$config$in_base_1(signal_select_38),
          .hosts$config$in_count_1(signal_select_37),
          .hosts$config$out_base_1(signal_select_36),
          .hosts$config$out_count_1(signal_select_35),
          .hosts$config$set_base_1(signal_select_34),
          .hosts$config$set_count_1(signal_select_33),
          .hosts$config$jmp_pin_1(signal_select_32),
          .hosts$config$capture_pin_1(signal_select_31),
          .hosts$config$capture_rising_1(signal_select_30),
          .hosts$config$in_shift_right_1(signal_select_29),
          .hosts$config$out_shift_right_1(signal_select_28),
          .hosts$config$autopush_1(signal_select_27),
          .hosts$config$push_threshold_1(signal_select_26),
          .hosts$config$autopull_1(signal_select_25),
          .hosts$config$pull_threshold_1(signal_select_24),
          .hosts$config$crc_width_1(signal_select_23),
          .hosts$config$crc_poly_1(signal_select_22),
          .hosts$config$crc_init_1(signal_select_21),
          .hosts$config$crc_reflect_1(signal_select_20),
          .hosts$config$stuff_threshold_1(signal_select_19),
          .hosts$config$stuff_level_1(signal_select_18),
          .hosts$config$wrap_bottom_1(signal_select_17),
          .hosts$config$wrap_top_1(signal_select_16),
          .hosts$config$period_fraction_1(signal_select_15),
          .hosts$start_1(signal_select_14),
          .hosts$program_write$valid_1(signal_select_13),
          .hosts$program_write$addr_1(signal_select_12),
          .hosts$program_write$data_1(signal_select_11),
          .hosts$tx$valid_1(signal_select_10),
          .hosts$tx$value_1(signal_select_9),
          .hosts$rx_pop_1(signal_select_8),
          .hosts$clear_irq_1(signal_select_7),
          .hosts$stop_1(signal_select_6),
          .hosts$flush_1(signal_select_5),
          .pads(inputs),
          .engines$pin_out_0(signal_inst_1[27:0]),
          .engines$pin_dir_0(signal_inst_1[55:28]),
          .engines$pc_0(signal_inst_1[64:56]),
          .engines$x_0(signal_inst_1[80:65]),
          .engines$y_0(signal_inst_1[96:81]),
          .engines$p_0(signal_inst_1[112:97]),
          .engines$t_0(signal_inst_1[136:113]),
          .engines$t_fraction_0(signal_inst_1[152:137]),
          .engines$osr_0(signal_inst_1[168:153]),
          .engines$osr_count_0(signal_inst_1[173:169]),
          .engines$isr_0(signal_inst_1[189:174]),
          .engines$isr_count_0(signal_inst_1[194:190]),
          .engines$now_0(signal_inst_1[218:195]),
          .engines$stall_0(signal_inst_1[223:219]),
          .engines$halted_0(signal_inst_1[224:224]),
          .engines$irq_0(signal_inst_1[225:225]),
          .engines$fault$underflow_0(signal_inst_1[226:226]),
          .engines$fault$overflow_0(signal_inst_1[227:227]),
          .engines$fault$missed_deadline_0(signal_inst_1[228:228]),
          .engines$fault$decode_0(signal_inst_1[229:229]),
          .engines$capture_0(signal_inst_1[253:230]),
          .engines$capture_armed_0(signal_inst_1[254:254]),
          .engines$tx_level_0(signal_inst_1[258:255]),
          .engines$rx_level_0(signal_inst_1[262:259]),
          .engines$rx_head_0(signal_inst_1[278:263]),
          .engines$instruction_0(signal_inst_1[294:279]),
          .engines$decode_ok_0(signal_inst_1[295:295]),
          .engines$opcode_onehot_0(signal_inst_1[303:296]),
          .engines$crc_0(signal_inst_1[319:304]),
          .engines$stuff_run_0(signal_inst_1[324:320]),
          .engines$pin_out_1(signal_inst_1[352:325]),
          .engines$pin_dir_1(signal_inst_1[380:353]),
          .engines$pc_1(signal_inst_1[389:381]),
          .engines$x_1(signal_inst_1[405:390]),
          .engines$y_1(signal_inst_1[421:406]),
          .engines$p_1(signal_inst_1[437:422]),
          .engines$t_1(signal_inst_1[461:438]),
          .engines$t_fraction_1(signal_inst_1[477:462]),
          .engines$osr_1(signal_inst_1[493:478]),
          .engines$osr_count_1(signal_inst_1[498:494]),
          .engines$isr_1(signal_inst_1[514:499]),
          .engines$isr_count_1(signal_inst_1[519:515]),
          .engines$now_1(signal_inst_1[543:520]),
          .engines$stall_1(signal_inst_1[548:544]),
          .engines$halted_1(signal_inst_1[549:549]),
          .engines$irq_1(signal_inst_1[550:550]),
          .engines$fault$underflow_1(signal_inst_1[551:551]),
          .engines$fault$overflow_1(signal_inst_1[552:552]),
          .engines$fault$missed_deadline_1(signal_inst_1[553:553]),
          .engines$fault$decode_1(signal_inst_1[554:554]),
          .engines$capture_1(signal_inst_1[578:555]),
          .engines$capture_armed_1(signal_inst_1[579:579]),
          .engines$tx_level_1(signal_inst_1[583:580]),
          .engines$rx_level_1(signal_inst_1[587:584]),
          .engines$rx_head_1(signal_inst_1[603:588]),
          .engines$instruction_1(signal_inst_1[619:604]),
          .engines$decode_ok_1(signal_inst_1[620:620]),
          .engines$opcode_onehot_1(signal_inst_1[628:621]),
          .engines$crc_1(signal_inst_1[644:629]),
          .engines$stuff_run_1(signal_inst_1[649:645]),
          .pin_out(signal_inst_1[669:650]),
          .pin_dir(signal_inst_1[689:670]) );
    assign signal_select_106 = signal_inst_1[669:650];
    assign signal_select_107 = signal_select_106[11:5];
    assign signal_cat = { signal_select_107,
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

