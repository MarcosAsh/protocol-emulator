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
    config$break_enable,
    config$break_pc,
    config$autopull_data,
    start,
    program_write$valid,
    program_write$addr,
    program_write$data,
    data_write$valid,
    data_write$addr,
    data_write$data,
    tx$valid,
    tx$value,
    rx_pop,
    clear_irq,
    stop,
    flush,
    resume,
    single_step,
    inputs,
    pin_out,
    pin_dir,
    pc,
    data_ptr,
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
    resumed,
    stepping,
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
    input config$break_enable;
    input [8:0] config$break_pc;
    input config$autopull_data;
    input start;
    input program_write$valid;
    input [8:0] program_write$addr;
    input [15:0] program_write$data;
    input data_write$valid;
    input [8:0] data_write$addr;
    input [15:0] data_write$data;
    input tx$valid;
    input [15:0] tx$value;
    input rx_pop;
    input clear_irq;
    input stop;
    input flush;
    input resume;
    input single_step;
    input [27:0] inputs;
    output [27:0] pin_out;
    output [27:0] pin_dir;
    output [8:0] pc;
    output [8:0] data_ptr;
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
    output resumed;
    output stepping;
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
    wire [3:0] signal_const_9;
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
    wire [8:0] signal_mux_67;
    wire [8:0] pc_after_next;
    wire [8:0] signal_mux_68;
    wire [8:0] signal_mux_69;
    wire [8:0] signal_mux_70;
    wire [8:0] fetch_addr;
    wire [8:0] signal_mux_71;
    wire [3:0] signal_const_58;
    wire signal_eq_10;
    wire signal_and_23;
    wire signal_and_24;
    wire signal_mux_72;
    wire signal_not_11;
    wire signal_and_25;
    wire signal_and_26;
    reg step_asked;
    wire signal_mux_73;
    wire signal_mux_74;
    wire signal_mux_75;
    reg signal_reg_4;
    wire stepping_0;
    wire signal_and_27;
    wire signal_mux_76;
    wire signal_not_12;
    wire signal_and_28;
    wire signal_mux_77;
    wire completes;
    wire signal_mux_78;
    wire signal_mux_79;
    wire signal_mux_80;
    reg signal_reg_5;
    wire resumed_0;
    wire signal_not_13;
    wire [8:0] signal_wire_4;
    wire [8:0] d$jmp_target;
    wire signal_not_14;
    wire signal_not_15;
    wire [4:0] signal_const_64;
    wire [4:0] signal_const_67;
    wire [4:0] signal_add_1;
    wire [4:0] stuff_run_max;
    wire signal_eq_11;
    wire [4:0] signal_mux_81;
    wire signal_wire_5;
    wire signal_eq_12;
    wire [4:0] signal_mux_82;
    wire [4:0] signal_mux_83;
    wire [3:0] signal_const_69;
    wire signal_eq_13;
    wire signal_and_29;
    wire [4:0] stuff_run_next;
    wire [4:0] signal_mux_84;
    wire [4:0] signal_mux_85;
    reg [4:0] signal_reg_6;
    wire [4:0] stuff_run_0;
    wire signal_lt;
    wire signal_not_16;
    wire [4:0] signal_wire_6;
    wire signal_eq_14;
    wire signal_not_17;
    wire signal_and_30;
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
    reg signal_mux_86;
    wire signal_not_18;
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
    wire [4:0] signal_wire_7;
    reg signal_mux_87;
    wire signal_eq_15;
    wire signal_not_19;
    wire signal_eq_16;
    wire signal_not_20;
    wire signal_eq_17;
    wire signal_not_21;
    reg jmp_taken;
    wire [8:0] jmp_target_or_next;
    wire [8:0] signal_wire_8;
    wire [8:0] signal_add_2;
    wire [8:0] signal_wire_9;
    wire signal_eq_18;
    wire [8:0] pc_next;
    reg [8:0] signal_reg_7;
    wire [8:0] pc_0;
    wire [8:0] signal_mux_88;
    wire [8:0] signal_mux_89;
    wire [8:0] pc_value_next;
    wire signal_eq_19;
    reg signal_reg_8;
    wire at_break;
    wire signal_wire_10;
    wire signal_not_22;
    wire [4:0] signal_const_79;
    wire [4:0] signal_and_31;
    wire [4:0] signal_and_32;
    wire [4:0] signal_const_81;
    wire [4:0] signal_and_33;
    reg [4:0] d$delay;
    wire [4:0] signal_sub_2;
    wire signal_eq_20;
    wire signal_not_23;
    wire [4:0] signal_mux_90;
    wire [4:0] signal_mux_91;
    wire signal_or_4;
    wire signal_or_5;
    reg refill;
    wire signal_not_24;
    wire signal_wire_11;
    wire [15:0] signal_mux_92;
    wire [15:0] signal_wire_12;
    wire signal_not_25;
    wire [3:0] signal_const_85;
    wire signal_eq_21;
    wire signal_and_34;
    wire signal_and_35;
    wire pushes;
    wire signal_and_36;
    wire signal_and_37;
    wire signal_wire_13;
    wire [21:0] signal_inst;
    wire signal_select_212;
    wire signal_not_26;
    wire signal_mux_93;
    wire [23:0] signal_xor;
    wire [23:0] signal_sub_3;
    wire [23:0] signal_cat_63;
    wire [23:0] signal_add_3;
    reg [23:0] signal_mux_94;
    wire [1:0] signal_const_88;
    wire signal_eq_22;
    wire [23:0] signal_mux_95;
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
    wire [23:0] signal_not_27;
    reg [23:0] mov_value_t;
    wire [2:0] signal_const_89;
    wire signal_eq_23;
    wire [23:0] signal_mux_96;
    wire [23:0] signal_cat_65;
    wire signal_eq_24;
    wire [23:0] signal_mux_97;
    wire [15:0] signal_wire_14;
    wire [16:0] signal_cat_66;
    wire signal_eq_25;
    wire [15:0] signal_mux_98;
    wire signal_eq_26;
    wire [15:0] signal_mux_99;
    wire signal_eq_27;
    wire [15:0] signal_mux_100;
    wire [15:0] signal_select_237;
    wire [15:0] signal_mux_101;
    reg [15:0] t_fraction_next;
    reg [15:0] signal_reg_9;
    wire [15:0] t_fraction_0;
    wire [16:0] signal_cat_67;
    wire [16:0] fraction_sum;
    wire signal_select_238;
    wire [22:0] signal_const_99;
    wire [23:0] signal_cat_68;
    wire [23:0] signal_cat_69;
    wire [23:0] signal_add_4;
    wire [23:0] t_advanced;
    wire [1:0] signal_const_101;
    wire signal_eq_28;
    wire signal_and_38;
    wire releases_deadline;
    wire advances_deadline;
    wire [23:0] signal_mux_102;
    reg [23:0] t_next;
    reg [23:0] signal_reg_10;
    wire [23:0] t_0;
    wire [23:0] signal_sub_4;
    wire signal_select_239;
    wire deadline_ready;
    wire signal_eq_29;
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
    wire signal_eq_30;
    wire signal_not_28;
    wire signal_and_39;
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
    wire signal_mux_103;
    wire signal_select_310;
    wire signal_select_311;
    wire signal_select_312;
    wire signal_mux_104;
    wire signal_select_313;
    wire signal_select_314;
    wire signal_select_315;
    wire signal_mux_105;
    wire signal_select_316;
    wire signal_select_317;
    wire signal_select_318;
    wire signal_mux_106;
    wire signal_select_319;
    wire signal_select_320;
    wire signal_select_321;
    wire signal_mux_107;
    wire signal_select_322;
    wire signal_select_323;
    wire signal_select_324;
    wire signal_mux_108;
    wire signal_select_325;
    wire signal_select_326;
    wire signal_select_327;
    wire signal_mux_109;
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
    wire [27:0] signal_mux_110;
    wire signal_select_341;
    wire [27:0] signal_mux_111;
    wire signal_select_342;
    wire [27:0] signal_mux_112;
    wire signal_select_343;
    wire [27:0] signal_mux_113;
    wire signal_select_344;
    wire [27:0] signal_mux_114;
    wire [27:0] signal_and_40;
    wire [27:0] signal_const_105;
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
    wire [15:0] signal_mux_115;
    wire signal_select_359;
    wire [15:0] signal_mux_116;
    wire signal_select_360;
    wire [15:0] signal_mux_117;
    wire signal_select_361;
    wire [15:0] signal_mux_118;
    wire [2:0] signal_wire_15;
    wire [4:0] signal_cat_85;
    wire signal_select_362;
    wire [15:0] signal_mux_119;
    wire [15:0] signal_not_29;
    wire [27:0] signal_cat_86;
    wire signal_select_363;
    wire [27:0] signal_mux_120;
    wire signal_select_364;
    wire [27:0] signal_mux_121;
    wire signal_select_365;
    wire [27:0] signal_mux_122;
    wire signal_select_366;
    wire [27:0] signal_mux_123;
    wire [4:0] signal_wire_16;
    wire signal_select_367;
    wire [27:0] signal_mux_124;
    wire [27:0] signal_and_41;
    wire [27:0] signal_not_30;
    wire [27:0] signal_and_42;
    wire [27:0] signal_or_6;
    wire [2:0] signal_const_114;
    wire signal_eq_31;
    wire [27:0] signal_mux_125;
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
    wire [27:0] signal_mux_126;
    wire signal_select_379;
    wire [27:0] signal_mux_127;
    wire signal_select_380;
    wire [27:0] signal_mux_128;
    wire signal_select_381;
    wire [27:0] signal_mux_129;
    wire signal_select_382;
    wire [27:0] signal_mux_130;
    wire [27:0] signal_and_43;
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
    wire [15:0] signal_mux_131;
    wire signal_select_397;
    wire [15:0] signal_mux_132;
    wire signal_select_398;
    wire [15:0] signal_mux_133;
    wire signal_select_399;
    wire [15:0] signal_mux_134;
    wire [4:0] signal_wire_17;
    wire signal_select_400;
    wire [15:0] signal_mux_135;
    wire [15:0] signal_not_31;
    wire [27:0] signal_cat_101;
    wire signal_select_401;
    wire [27:0] signal_mux_136;
    wire signal_select_402;
    wire [27:0] signal_mux_137;
    wire signal_select_403;
    wire [27:0] signal_mux_138;
    wire signal_select_404;
    wire [27:0] signal_mux_139;
    wire signal_select_405;
    wire [27:0] signal_mux_140;
    wire [27:0] signal_and_44;
    wire [27:0] signal_not_32;
    wire [27:0] signal_and_45;
    wire [27:0] signal_or_7;
    wire signal_eq_32;
    wire [27:0] signal_mux_141;
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
    wire [15:0] signal_and_46;
    wire [7:0] signal_select_416;
    wire [15:0] signal_cat_107;
    wire [11:0] signal_select_417;
    wire [15:0] signal_cat_108;
    wire [13:0] signal_select_418;
    wire [15:0] signal_cat_109;
    wire [14:0] signal_select_419;
    wire [15:0] signal_cat_110;
    wire [15:0] signal_wire_18;
    wire [8:0] signal_wire_19;
    wire [8:0] signal_select_420;
    wire [8:0] signal_add_5;
    reg [8:0] signal_reg_11;
    wire [8:0] data_ptr_0;
    wire signal_and_47;
    wire signal_and_48;
    wire [8:0] signal_mux_142;
    wire [3:0] signal_const_134;
    wire signal_eq_33;
    wire signal_and_49;
    wire signal_and_50;
    wire [8:0] signal_mux_143;
    wire [8:0] signal_mux_144;
    wire [8:0] data_ptr_next;
    wire [8:0] signal_mux_145;
    wire signal_wire_20;
    wire data_write;
    wire [15:0] signal_inst_1;
    wire [15:0] signal_wire_21;
    wire [15:0] signal_select_421;
    wire signal_not_33;
    wire signal_and_51;
    wire [15:0] signal_mux_146;
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
    wire signal_select_437;
    wire [15:0] signal_cat_111;
    wire [15:0] signal_not_34;
    wire [23:0] signal_cat_112;
    wire [23:0] signal_cat_113;
    wire [23:0] signal_cat_114;
    wire [15:0] signal_xor_1;
    wire [15:0] signal_sub_5;
    wire signal_eq_34;
    wire signal_and_52;
    wire [15:0] signal_mux_147;
    wire signal_eq_35;
    wire [15:0] signal_mux_148;
    wire signal_eq_36;
    wire [15:0] signal_mux_149;
    wire [7:0] signal_select_438;
    wire [15:0] signal_cat_115;
    wire [11:0] signal_select_439;
    wire [15:0] signal_cat_116;
    wire [13:0] signal_select_440;
    wire [15:0] signal_cat_117;
    wire [14:0] signal_select_441;
    wire [15:0] signal_cat_118;
    wire signal_select_442;
    wire [15:0] signal_mux_150;
    wire signal_select_443;
    wire [15:0] signal_mux_151;
    wire signal_select_444;
    wire [15:0] signal_mux_152;
    wire signal_select_445;
    wire [15:0] signal_mux_153;
    wire signal_select_446;
    wire [15:0] signal_mux_154;
    wire [7:0] signal_select_447;
    wire [15:0] signal_cat_119;
    wire [11:0] signal_select_448;
    wire [15:0] signal_cat_120;
    wire [13:0] signal_select_449;
    wire [15:0] signal_cat_121;
    wire [14:0] signal_select_450;
    wire [15:0] signal_cat_122;
    wire signal_select_451;
    wire [15:0] signal_mux_155;
    wire signal_select_452;
    wire [15:0] signal_mux_156;
    wire signal_select_453;
    wire [15:0] signal_mux_157;
    wire signal_select_454;
    wire [15:0] signal_mux_158;
    wire signal_select_455;
    wire [15:0] signal_mux_159;
    wire [15:0] signal_or_8;
    wire [7:0] signal_select_456;
    wire [15:0] signal_cat_123;
    wire [11:0] signal_select_457;
    wire [15:0] signal_cat_124;
    wire [13:0] signal_select_458;
    wire [15:0] signal_cat_125;
    wire signal_select_459;
    wire [15:0] signal_mux_160;
    wire signal_select_460;
    wire [15:0] signal_mux_161;
    wire signal_select_461;
    wire [15:0] signal_mux_162;
    wire signal_select_462;
    wire [15:0] signal_mux_163;
    wire signal_select_463;
    wire [15:0] signal_mux_164;
    wire [15:0] mask;
    wire signal_wire_22;
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
    wire signal_select_491;
    reg signal_mux_165;
    wire signal_eq_37;
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
    wire signal_select_518;
    reg [27:0] signal_reg_12;
    wire [27:0] pins_sampled;
    wire signal_select_519;
    reg signal_mux_166;
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
    wire signal_select_547;
    wire [4:0] signal_wire_23;
    reg signal_mux_167;
    wire signal_eq_38;
    wire signal_not_35;
    wire [3:0] signal_const_165;
    wire signal_eq_39;
    wire signal_and_53;
    wire signal_and_54;
    wire signal_mux_168;
    wire signal_mux_169;
    reg signal_reg_13;
    wire capture_armed_0;
    wire signal_and_55;
    wire captured;
    wire [23:0] signal_const_169;
    wire [23:0] signal_add_6;
    wire [23:0] signal_mux_170;
    reg [23:0] signal_reg_14;
    wire [23:0] now_0;
    reg [23:0] signal_reg_15;
    wire [23:0] capture_0;
    wire [15:0] signal_select_548;
    wire [15:0] signal_wire_24;
    wire [7:0] signal_select_549;
    wire [15:0] signal_cat_126;
    wire [11:0] signal_select_550;
    wire [15:0] signal_cat_127;
    wire [13:0] signal_select_551;
    wire [15:0] signal_cat_128;
    wire signal_select_552;
    wire [15:0] signal_mux_171;
    wire signal_select_553;
    wire [15:0] signal_mux_172;
    wire signal_select_554;
    wire [15:0] signal_mux_173;
    wire signal_select_555;
    wire [15:0] signal_mux_174;
    wire signal_select_556;
    wire [15:0] signal_mux_175;
    wire [15:0] signal_not_36;
    wire [15:0] signal_xor_2;
    wire [14:0] signal_select_557;
    wire [15:0] signal_cat_129;
    wire signal_select_558;
    wire signal_xor_3;
    wire [15:0] signal_mux_176;
    wire [15:0] signal_wire_25;
    wire [15:0] signal_xor_4;
    wire [14:0] signal_select_559;
    wire [15:0] signal_cat_130;
    wire signal_select_560;
    wire signal_select_561;
    wire crossing_bit;
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
    wire signal_select_577;
    wire [4:0] signal_wire_26;
    wire [4:0] signal_sub_6;
    reg signal_mux_177;
    wire signal_xor_5;
    wire [15:0] signal_mux_178;
    wire signal_wire_27;
    wire [15:0] signal_mux_179;
    wire [15:0] crc_stepped;
    wire [2:0] signal_const_180;
    wire signal_eq_40;
    reg is_opcode$2;
    wire signal_or_9;
    wire signal_eq_41;
    wire bit_crosses;
    wire [15:0] signal_mux_180;
    wire [3:0] signal_const_182;
    wire signal_eq_42;
    wire signal_and_56;
    wire [15:0] crc_next;
    wire [15:0] signal_mux_181;
    wire [15:0] signal_mux_182;
    reg [15:0] signal_reg_16;
    wire [15:0] crc_0;
    wire [7:0] signal_select_578;
    wire [15:0] signal_cat_131;
    wire [11:0] signal_select_579;
    wire [15:0] signal_cat_132;
    wire [13:0] signal_select_580;
    wire [15:0] signal_cat_133;
    wire signal_select_581;
    wire [15:0] signal_mux_183;
    wire signal_select_582;
    wire [15:0] signal_mux_184;
    wire signal_select_583;
    wire [15:0] signal_mux_185;
    wire signal_select_584;
    wire [15:0] signal_mux_186;
    wire signal_select_585;
    wire [15:0] signal_mux_187;
    wire [15:0] signal_not_37;
    wire [11:0] signal_select_586;
    wire [15:0] signal_select_587;
    wire [27:0] signal_cat_134;
    wire [19:0] signal_select_588;
    wire [7:0] signal_select_589;
    wire [27:0] signal_cat_135;
    wire [23:0] signal_select_590;
    wire [3:0] signal_select_591;
    wire [27:0] signal_cat_136;
    wire [25:0] signal_select_592;
    wire [1:0] signal_select_593;
    wire [27:0] signal_cat_137;
    wire [26:0] signal_select_594;
    wire signal_select_595;
    wire [27:0] signal_cat_138;
    wire signal_select_596;
    wire [27:0] signal_mux_188;
    wire signal_select_597;
    wire [27:0] signal_mux_189;
    wire signal_select_598;
    wire [27:0] signal_mux_190;
    wire signal_select_599;
    wire [27:0] signal_mux_191;
    wire signal_select_600;
    wire [27:0] signal_mux_192;
    wire [15:0] signal_select_601;
    wire [15:0] signal_and_57;
    reg [15:0] signal_mux_193;
    wire [15:0] in_value;
    wire [7:0] signal_select_602;
    wire [15:0] signal_cat_139;
    wire [11:0] signal_select_603;
    wire [15:0] signal_cat_140;
    wire [13:0] signal_select_604;
    wire [15:0] signal_cat_141;
    wire [14:0] signal_select_605;
    wire [15:0] signal_cat_142;
    wire signal_select_606;
    wire [15:0] signal_mux_194;
    wire signal_select_607;
    wire [15:0] signal_mux_195;
    wire signal_select_608;
    wire [15:0] signal_mux_196;
    wire signal_select_609;
    wire [15:0] signal_mux_197;
    wire signal_select_610;
    wire [15:0] signal_mux_198;
    wire [15:0] signal_or_10;
    wire signal_wire_28;
    wire [15:0] isr_shifted;
    wire [4:0] signal_wire_29;
    wire [4:0] signal_const_195;
    wire [4:0] signal_select_611;
    wire [5:0] signal_cat_143;
    wire signal_eq_43;
    wire signal_and_58;
    wire [4:0] signal_mux_199;
    wire signal_eq_44;
    wire [4:0] signal_mux_200;
    wire signal_eq_45;
    wire [4:0] signal_mux_201;
    wire [4:0] signal_mux_202;
    reg [4:0] isr_count_next_value;
    reg [4:0] signal_reg_17;
    wire [4:0] isr_count_0;
    wire [5:0] signal_cat_144;
    wire [5:0] signal_add_7;
    wire [5:0] signal_const_200;
    wire signal_lt_2;
    wire [4:0] isr_count_next;
    wire signal_lt_3;
    wire signal_not_38;
    wire signal_wire_30;
    wire autopush_now;
    wire [15:0] signal_mux_203;
    reg [15:0] isr_next;
    reg [15:0] signal_reg_18;
    wire [15:0] isr_0;
    wire [15:0] signal_xor_6;
    wire [15:0] signal_sub_7;
    wire [15:0] signal_add_8;
    reg [15:0] signal_mux_204;
    wire signal_eq_46;
    wire [15:0] signal_mux_205;
    wire [15:0] signal_cat_145;
    wire signal_eq_47;
    wire [15:0] signal_mux_206;
    wire signal_eq_48;
    wire [15:0] signal_mux_207;
    wire signal_eq_49;
    wire [15:0] signal_mux_208;
    reg [15:0] p_next;
    reg [15:0] signal_reg_19;
    wire [15:0] p_0;
    wire [15:0] signal_xor_7;
    wire [15:0] signal_sub_8;
    wire [15:0] signal_add_9;
    reg [15:0] signal_mux_209;
    wire [1:0] signal_const_208;
    wire signal_eq_50;
    wire [15:0] signal_mux_210;
    wire [15:0] signal_cat_146;
    wire signal_eq_51;
    wire [15:0] signal_mux_211;
    wire signal_eq_52;
    wire [15:0] signal_mux_212;
    wire signal_eq_53;
    wire [15:0] signal_mux_213;
    wire [15:0] signal_const_213;
    wire [15:0] signal_sub_9;
    wire signal_eq_54;
    wire [15:0] signal_mux_214;
    reg [15:0] y_next;
    reg [15:0] signal_reg_20;
    wire [15:0] y_0;
    reg [15:0] signal_mux_215;
    wire [2:0] d$alu_reg$binary_variant;
    wire [2:0] d$alu_imm;
    wire [12:0] signal_const_215;
    wire [15:0] signal_cat_147;
    wire d$alu_is_reg;
    wire [15:0] alu_operand;
    wire [15:0] signal_add_10;
    wire [1:0] d$alu_op$binary_variant;
    reg [15:0] signal_mux_216;
    wire [1:0] d$alu_dest$binary_variant;
    wire signal_eq_55;
    wire [15:0] signal_mux_217;
    wire [4:0] d$set_value;
    wire [15:0] signal_cat_148;
    wire [2:0] signal_const_218;
    wire [2:0] d$set_dest$binary_variant;
    wire signal_eq_56;
    wire [15:0] signal_mux_218;
    wire signal_eq_57;
    wire [15:0] signal_mux_219;
    wire signal_eq_58;
    wire [15:0] signal_mux_220;
    wire [15:0] signal_sub_10;
    wire [3:0] d$jmp_cond$binary_variant;
    wire signal_eq_59;
    wire [15:0] signal_mux_221;
    reg [15:0] x_next;
    reg [15:0] signal_reg_21;
    wire [15:0] x_0;
    wire [23:0] signal_cat_149;
    wire [7:0] signal_select_612;
    wire [15:0] signal_cat_150;
    wire [11:0] signal_select_613;
    wire [15:0] signal_cat_151;
    wire [13:0] signal_select_614;
    wire [15:0] signal_cat_152;
    wire signal_select_615;
    wire [15:0] signal_mux_222;
    wire signal_select_616;
    wire [15:0] signal_mux_223;
    wire signal_select_617;
    wire [15:0] signal_mux_224;
    wire signal_select_618;
    wire [15:0] signal_mux_225;
    wire [4:0] signal_wire_31;
    wire signal_select_619;
    wire [15:0] signal_mux_226;
    wire [15:0] signal_not_39;
    wire [11:0] signal_select_620;
    wire [15:0] signal_select_621;
    wire [27:0] signal_cat_153;
    wire [19:0] signal_select_622;
    wire [7:0] signal_select_623;
    wire [27:0] signal_cat_154;
    wire [23:0] signal_select_624;
    wire [3:0] signal_select_625;
    wire [27:0] signal_cat_155;
    wire [25:0] signal_select_626;
    wire [1:0] signal_select_627;
    wire [27:0] signal_cat_156;
    wire [26:0] signal_select_628;
    wire signal_select_629;
    wire [27:0] signal_cat_157;
    wire signal_select_630;
    wire [27:0] signal_mux_227;
    wire signal_select_631;
    wire [27:0] signal_mux_228;
    wire signal_select_632;
    wire [27:0] signal_mux_229;
    wire signal_select_633;
    wire [27:0] signal_mux_230;
    wire [4:0] signal_wire_32;
    wire signal_select_634;
    wire [27:0] signal_mux_231;
    wire [15:0] signal_select_635;
    wire [15:0] signal_and_59;
    wire [23:0] signal_cat_158;
    wire [2:0] d$mov_source$binary_variant;
    reg [23:0] mov_value24;
    wire [15:0] signal_select_636;
    wire [1:0] d$mov_op$binary_variant;
    reg [15:0] mov_value;
    wire signal_eq_60;
    wire [15:0] signal_mux_232;
    wire [7:0] signal_select_637;
    wire [15:0] signal_cat_159;
    wire [11:0] signal_select_638;
    wire [15:0] signal_cat_160;
    wire [13:0] signal_select_639;
    wire [15:0] signal_cat_161;
    wire [14:0] signal_select_640;
    wire [15:0] signal_cat_162;
    wire signal_select_641;
    wire [15:0] signal_mux_233;
    wire signal_select_642;
    wire [15:0] signal_mux_234;
    wire signal_select_643;
    wire [15:0] signal_mux_235;
    wire signal_select_644;
    wire [15:0] signal_mux_236;
    wire signal_select_645;
    wire [15:0] signal_mux_237;
    wire [7:0] signal_select_646;
    wire [15:0] signal_cat_163;
    wire [11:0] signal_select_647;
    wire [15:0] signal_cat_164;
    wire [13:0] signal_select_648;
    wire [15:0] signal_cat_165;
    wire [14:0] signal_select_649;
    wire [15:0] signal_cat_166;
    wire signal_select_650;
    wire [15:0] signal_mux_238;
    wire signal_select_651;
    wire [15:0] signal_mux_239;
    wire signal_select_652;
    wire [15:0] signal_mux_240;
    wire signal_select_653;
    wire [15:0] signal_mux_241;
    wire signal_select_654;
    wire [15:0] signal_mux_242;
    wire [15:0] osr_shifted;
    reg [15:0] osr_next;
    reg [15:0] signal_reg_22;
    wire [15:0] osr_0;
    wire signal_wire_33;
    wire flush_0;
    wire signal_not_40;
    wire signal_and_60;
    wire signal_eq_61;
    reg is_opcode$3;
    wire signal_and_61;
    wire signal_or_11;
    wire signal_and_62;
    wire tx_pop;
    wire [15:0] signal_wire_34;
    wire signal_wire_35;
    wire [21:0] signal_inst_2;
    wire signal_select_655;
    wire signal_not_41;
    wire signal_not_42;
    wire pull_fifo;
    wire pull_ok;
    wire [15:0] signal_mux_243;
    wire signal_wire_36;
    wire [4:0] signal_wire_37;
    wire [3:0] signal_const_244;
    wire [3:0] d$sys_op$binary_variant;
    wire signal_eq_62;
    wire signal_eq_63;
    reg is_opcode$7;
    wire pulls;
    wire [4:0] signal_mux_244;
    wire [4:0] osr_count_zero;
    wire [2:0] d$mov_dest$binary_variant;
    wire signal_eq_64;
    wire [4:0] signal_mux_245;
    wire [4:0] signal_select_656;
    wire [5:0] signal_cat_167;
    wire [4:0] osr_count_before;
    wire [5:0] signal_cat_168;
    wire [5:0] signal_add_11;
    wire signal_lt_4;
    wire [4:0] osr_count_next;
    reg [4:0] osr_count_next_value;
    reg [4:0] signal_reg_23;
    wire [4:0] osr_count_0;
    wire signal_lt_5;
    wire signal_not_43;
    wire signal_wire_38;
    wire pull_now;
    wire pull_data;
    wire [15:0] osr_before;
    wire signal_select_657;
    wire [15:0] signal_mux_246;
    wire signal_select_658;
    wire [15:0] signal_mux_247;
    wire signal_select_659;
    wire [15:0] signal_mux_248;
    wire signal_select_660;
    wire [15:0] signal_mux_249;
    wire [4:0] shift_back;
    wire signal_select_661;
    wire [15:0] signal_mux_250;
    wire [15:0] signal_and_63;
    wire signal_wire_39;
    wire [15:0] out_value;
    wire [27:0] signal_cat_169;
    wire signal_select_662;
    wire [27:0] signal_mux_251;
    wire signal_select_663;
    wire [27:0] signal_mux_252;
    wire signal_select_664;
    wire [27:0] signal_mux_253;
    wire signal_select_665;
    wire [27:0] signal_mux_254;
    wire signal_select_666;
    wire [27:0] signal_mux_255;
    wire [27:0] signal_and_64;
    wire [15:0] signal_select_667;
    wire [11:0] signal_select_668;
    wire [27:0] signal_cat_170;
    wire [7:0] signal_select_669;
    wire [19:0] signal_select_670;
    wire [27:0] signal_cat_171;
    wire [3:0] signal_select_671;
    wire [23:0] signal_select_672;
    wire [27:0] signal_cat_172;
    wire [1:0] signal_select_673;
    wire [25:0] signal_select_674;
    wire [27:0] signal_cat_173;
    wire signal_select_675;
    wire [26:0] signal_select_676;
    wire [27:0] signal_cat_174;
    wire [7:0] signal_select_677;
    wire [15:0] signal_cat_175;
    wire [11:0] signal_select_678;
    wire [15:0] signal_cat_176;
    wire [13:0] signal_select_679;
    wire [15:0] signal_cat_177;
    wire signal_select_680;
    wire [15:0] signal_mux_256;
    wire signal_select_681;
    wire [15:0] signal_mux_257;
    wire signal_select_682;
    wire [15:0] signal_mux_258;
    wire signal_select_683;
    wire [15:0] signal_mux_259;
    wire [4:0] d$shift_count;
    wire signal_select_684;
    wire [15:0] signal_mux_260;
    wire [15:0] signal_not_44;
    wire [27:0] signal_cat_178;
    wire signal_select_685;
    wire [27:0] signal_mux_261;
    wire signal_select_686;
    wire [27:0] signal_mux_262;
    wire signal_select_687;
    wire [27:0] signal_mux_263;
    wire signal_select_688;
    wire [27:0] signal_mux_264;
    wire [4:0] signal_wire_40;
    wire signal_select_689;
    wire [27:0] signal_mux_265;
    wire [27:0] signal_and_65;
    wire [27:0] signal_not_45;
    wire [27:0] signal_and_66;
    wire [27:0] signal_or_12;
    wire [2:0] d$out_dest$binary_variant;
    wire [2:0] d$in_source$binary_variant;
    wire signal_eq_65;
    wire [27:0] signal_mux_266;
    wire [15:0] signal_select_690;
    wire [11:0] signal_select_691;
    wire [27:0] signal_cat_179;
    wire [7:0] signal_select_692;
    wire [19:0] signal_select_693;
    wire [27:0] signal_cat_180;
    wire [3:0] signal_select_694;
    wire [23:0] signal_select_695;
    wire [27:0] signal_cat_181;
    wire [1:0] signal_select_696;
    wire [25:0] signal_select_697;
    wire [27:0] signal_cat_182;
    wire signal_select_698;
    wire [26:0] signal_select_699;
    wire [27:0] signal_cat_183;
    wire [1:0] signal_select_700;
    wire [1:0] signal_select_701;
    wire [4:0] signal_select_702;
    wire signal_select_703;
    wire [1:0] signal_cat_184;
    reg [1:0] d$side_set;
    wire [15:0] signal_cat_185;
    wire [27:0] signal_cat_186;
    wire signal_select_704;
    wire [27:0] signal_mux_267;
    wire signal_select_705;
    wire [27:0] signal_mux_268;
    wire signal_select_706;
    wire [27:0] signal_mux_269;
    wire signal_select_707;
    wire [27:0] signal_mux_270;
    wire signal_select_708;
    wire [27:0] signal_mux_271;
    wire [27:0] signal_and_67;
    wire [15:0] signal_select_709;
    wire [11:0] signal_select_710;
    wire [27:0] signal_cat_187;
    wire [7:0] signal_select_711;
    wire [19:0] signal_select_712;
    wire [27:0] signal_cat_188;
    wire [3:0] signal_select_713;
    wire [23:0] signal_select_714;
    wire [27:0] signal_cat_189;
    wire [1:0] signal_select_715;
    wire [25:0] signal_select_716;
    wire [27:0] signal_cat_190;
    wire signal_select_717;
    wire [26:0] signal_select_718;
    wire [27:0] signal_cat_191;
    wire [7:0] signal_select_719;
    wire [15:0] signal_cat_192;
    wire [11:0] signal_select_720;
    wire [15:0] signal_cat_193;
    wire [13:0] signal_select_721;
    wire [15:0] signal_cat_194;
    wire signal_select_722;
    wire [15:0] signal_mux_272;
    wire signal_select_723;
    wire [15:0] signal_mux_273;
    wire signal_select_724;
    wire [15:0] signal_mux_274;
    wire signal_select_725;
    wire [15:0] signal_mux_275;
    wire [1:0] signal_wire_41;
    wire [4:0] signal_cat_195;
    wire signal_select_726;
    wire [15:0] signal_mux_276;
    wire [15:0] signal_not_46;
    wire [27:0] signal_cat_196;
    wire signal_select_727;
    wire [27:0] signal_mux_277;
    wire signal_select_728;
    wire [27:0] signal_mux_278;
    wire signal_select_729;
    wire [27:0] signal_mux_279;
    wire signal_select_730;
    wire [27:0] signal_mux_280;
    wire [4:0] signal_wire_42;
    wire signal_select_731;
    wire [27:0] signal_mux_281;
    wire [27:0] signal_and_68;
    wire [27:0] signal_not_47;
    wire [27:0] signal_and_69;
    wire [27:0] pin_dir_side;
    wire signal_wire_43;
    wire [27:0] pin_dir_base;
    reg [27:0] pin_dir_next;
    reg [27:0] signal_reg_24;
    wire [27:0] pin_dir_0;
    wire signal_select_732;
    wire signal_mux_282;
    wire signal_select_733;
    wire signal_select_734;
    wire signal_or_13;
    wire signal_select_735;
    wire signal_select_736;
    wire signal_or_14;
    wire signal_select_737;
    wire signal_select_738;
    wire signal_or_15;
    wire signal_select_739;
    wire signal_select_740;
    wire signal_or_16;
    wire signal_select_741;
    wire signal_select_742;
    wire signal_or_17;
    wire signal_select_743;
    wire signal_select_744;
    wire signal_or_18;
    wire signal_select_745;
    wire signal_select_746;
    wire signal_or_19;
    wire [27:0] signal_wire_44;
    wire signal_select_747;
    wire signal_select_748;
    wire signal_or_20;
    wire [27:0] sample;
    wire signal_select_749;
    wire [4:0] d$wait_index;
    reg wait_pin_cur;
    wire signal_eq_66;
    wire [1:0] d$wait_source$binary_variant;
    reg wait_ready;
    wire signal_not_48;
    wire gnd;
    wire signal_eq_67;
    reg is_opcode$1;
    wire wait_holds;
    wire signal_not_49;
    wire signal_eq_68;
    reg is_opcode$0;
    wire signal_not_50;
    wire op_go;
    wire advance;
    wire signal_or_21;
    wire ir_load;
    wire [3:0] signal_const_275;
    wire [3:0] signal_select_750;
    wire signal_lt_6;
    wire [3:0] signal_select_751;
    wire signal_eq_69;
    wire signal_and_70;
    wire [2:0] signal_select_752;
    wire signal_lt_7;
    wire signal_select_753;
    wire signal_not_51;
    wire signal_or_22;
    wire [1:0] signal_select_754;
    wire signal_lt_8;
    wire signal_and_71;
    wire [2:0] signal_select_755;
    wire signal_lt_9;
    wire [1:0] signal_select_756;
    wire signal_lt_10;
    wire signal_lt_11;
    wire signal_not_52;
    wire [4:0] signal_select_757;
    wire signal_lt_12;
    wire signal_not_53;
    wire signal_and_72;
    wire signal_eq_70;
    wire signal_eq_71;
    wire [4:0] signal_const_285;
    wire signal_lt_13;
    wire [4:0] signal_select_758;
    wire signal_lt_14;
    wire [1:0] signal_select_759;
    reg signal_mux_283;
    wire [3:0] signal_const_287;
    wire [3:0] signal_select_760;
    wire signal_lt_15;
    wire [2:0] signal_select_761;
    reg signal_mux_284;
    reg decode_ok_0;
    wire signal_not_54;
    wire issue;
    wire go;
    wire jmp_go;
    wire [4:0] signal_mux_285;
    wire [4:0] stall_next;
    reg [4:0] signal_reg_25;
    wire [4:0] stall_0;
    wire signal_eq_72;
    wire signal_not_55;
    wire signal_and_73;
    wire ready;
    wire signal_and_74;
    wire signal_and_75;
    wire breaks;
    wire signal_mux_286;
    wire signal_wire_45;
    wire signal_mux_287;
    wire signal_not_56;
    wire signal_wire_46;
    wire signal_wire_47;
    wire signal_or_23;
    wire signal_and_76;
    wire resume_asked;
    reg signal_reg_26;
    wire resume_0;
    wire signal_mux_288;
    wire signal_wire_48;
    wire signal_wire_49;
    reg start_0;
    wire halted_next;
    reg signal_reg_27;
    wire halted_0;
    wire signal_wire_50;
    wire program_write;
    wire vdd;
    wire signal_wire_51;
    wire [15:0] signal_inst_3;
    wire [15:0] signal_wire_52;
    reg [15:0] word;
    wire [2:0] d$opcode$binary_variant;
    reg [27:0] pin_out_next;
    reg [27:0] signal_reg_28;
    wire [27:0] pin_out_0;
    assign signal_const = 3'b100;
    assign signal_eq = signal_select_761 == signal_const;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            is_opcode$4 <= gnd;
        else
            if (ir_load)
                is_opcode$4 <= signal_eq;
    end
    assign signal_const_1 = 3'b101;
    assign signal_eq_1 = signal_select_761 == signal_const_1;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            is_opcode$5 <= gnd;
        else
            if (ir_load)
                is_opcode$5 <= signal_eq_1;
    end
    assign signal_const_2 = 3'b110;
    assign signal_eq_2 = signal_select_761 == signal_const_2;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
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
    assign signal_select_2 = signal_inst_2[19:16];
    assign signal_not = ~ decode_ok_0;
    assign signal_and = issue & signal_not;
    assign signal_const_3 = 1'b0;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
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
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_1 <= signal_const_3;
        else
            if (signal_and_2)
                signal_reg_1 <= vdd;
    end
    assign signal_and_3 = op_go & pushes;
    assign signal_and_4 = signal_and_3 & signal_select_212;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_2 <= signal_const_3;
        else
            if (signal_and_4)
                signal_reg_2 <= vdd;
    end
    assign signal_and_5 = pulls & signal_select_655;
    assign signal_and_6 = is_opcode$3 & pull_fifo;
    assign signal_and_7 = signal_and_6 & signal_select_655;
    assign signal_or = signal_and_7 | signal_and_5;
    assign signal_and_8 = op_go & signal_or;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_3 <= signal_const_3;
        else
            if (signal_and_8)
                signal_reg_3 <= vdd;
    end
    assign signal_wire = clear_irq;
    assign signal_mux = signal_wire ? gnd : irq_0;
    assign signal_const_9 = 4'b0010;
    assign signal_eq_4 = d$sys_op$binary_variant == signal_const_9;
    assign signal_and_9 = is_opcode$7 & signal_eq_4;
    assign signal_and_10 = op_go & signal_and_9;
    assign signal_mux_1 = signal_and_10 ? vdd : signal_mux;
    assign signal_wire_1 = signal_mux_1;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
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
    assign signal_select_14 = signal_wire_16[0:0];
    assign signal_mux_2 = signal_select_14 ? signal_cat_5 : signal_cat_7;
    assign signal_select_15 = signal_wire_16[1:1];
    assign signal_mux_3 = signal_select_15 ? signal_cat_4 : signal_mux_2;
    assign signal_select_16 = signal_wire_16[2:2];
    assign signal_mux_4 = signal_select_16 ? signal_cat_3 : signal_mux_3;
    assign signal_select_17 = signal_wire_16[3:3];
    assign signal_mux_5 = signal_select_17 ? signal_cat_2 : signal_mux_4;
    assign signal_select_18 = signal_wire_16[4:4];
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
    assign signal_select_37 = signal_wire_16[0:0];
    assign signal_mux_12 = signal_select_37 ? signal_cat_12 : signal_cat_16;
    assign signal_select_38 = signal_wire_16[1:1];
    assign signal_mux_13 = signal_select_38 ? signal_cat_11 : signal_mux_12;
    assign signal_select_39 = signal_wire_16[2:2];
    assign signal_mux_14 = signal_select_39 ? signal_cat_10 : signal_mux_13;
    assign signal_select_40 = signal_wire_16[3:3];
    assign signal_mux_15 = signal_select_40 ? signal_cat_9 : signal_mux_14;
    assign signal_select_41 = signal_wire_16[4:4];
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
    assign signal_select_52 = signal_wire_40[0:0];
    assign signal_mux_18 = signal_select_52 ? signal_cat_21 : signal_cat_22;
    assign signal_select_53 = signal_wire_40[1:1];
    assign signal_mux_19 = signal_select_53 ? signal_cat_20 : signal_mux_18;
    assign signal_select_54 = signal_wire_40[2:2];
    assign signal_mux_20 = signal_select_54 ? signal_cat_19 : signal_mux_19;
    assign signal_select_55 = signal_wire_40[3:3];
    assign signal_mux_21 = signal_select_55 ? signal_cat_18 : signal_mux_20;
    assign signal_select_56 = signal_wire_40[4:4];
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
    assign signal_select_70 = signal_wire_17[0:0];
    assign signal_mux_23 = signal_select_70 ? signal_const_18 : signal_const_19;
    assign signal_select_71 = signal_wire_17[1:1];
    assign signal_mux_24 = signal_select_71 ? signal_cat_30 : signal_mux_23;
    assign signal_select_72 = signal_wire_17[2:2];
    assign signal_mux_25 = signal_select_72 ? signal_cat_29 : signal_mux_24;
    assign signal_select_73 = signal_wire_17[3:3];
    assign signal_mux_26 = signal_select_73 ? signal_cat_28 : signal_mux_25;
    assign signal_select_74 = signal_wire_17[4:4];
    assign signal_mux_27 = signal_select_74 ? signal_const_14 : signal_mux_26;
    assign signal_not_5 = ~ signal_mux_27;
    assign signal_cat_31 = { signal_const_12,
                             signal_not_5 };
    assign signal_select_75 = signal_wire_40[0:0];
    assign signal_mux_28 = signal_select_75 ? signal_cat_27 : signal_cat_31;
    assign signal_select_76 = signal_wire_40[1:1];
    assign signal_mux_29 = signal_select_76 ? signal_cat_26 : signal_mux_28;
    assign signal_select_77 = signal_wire_40[2:2];
    assign signal_mux_30 = signal_select_77 ? signal_cat_25 : signal_mux_29;
    assign signal_select_78 = signal_wire_40[3:3];
    assign signal_mux_31 = signal_select_78 ? signal_cat_24 : signal_mux_30;
    assign signal_select_79 = signal_wire_40[4:4];
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
    assign signal_select_90 = signal_wire_40[0:0];
    assign signal_mux_34 = signal_select_90 ? signal_cat_36 : signal_cat_37;
    assign signal_select_91 = signal_wire_40[1:1];
    assign signal_mux_35 = signal_select_91 ? signal_cat_35 : signal_mux_34;
    assign signal_select_92 = signal_wire_40[2:2];
    assign signal_mux_36 = signal_select_92 ? signal_cat_34 : signal_mux_35;
    assign signal_select_93 = signal_wire_40[3:3];
    assign signal_mux_37 = signal_select_93 ? signal_cat_33 : signal_mux_36;
    assign signal_select_94 = signal_wire_40[4:4];
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
    assign signal_select_113 = signal_wire_40[0:0];
    assign signal_mux_44 = signal_select_113 ? signal_cat_42 : signal_cat_46;
    assign signal_select_114 = signal_wire_40[1:1];
    assign signal_mux_45 = signal_select_114 ? signal_cat_41 : signal_mux_44;
    assign signal_select_115 = signal_wire_40[2:2];
    assign signal_mux_46 = signal_select_115 ? signal_cat_40 : signal_mux_45;
    assign signal_select_116 = signal_wire_40[3:3];
    assign signal_mux_47 = signal_select_116 ? signal_cat_39 : signal_mux_46;
    assign signal_select_117 = signal_wire_40[4:4];
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
    assign signal_select_128 = signal_wire_42[0:0];
    assign signal_mux_50 = signal_select_128 ? signal_cat_51 : signal_cat_53;
    assign signal_select_129 = signal_wire_42[1:1];
    assign signal_mux_51 = signal_select_129 ? signal_cat_50 : signal_mux_50;
    assign signal_select_130 = signal_wire_42[2:2];
    assign signal_mux_52 = signal_select_130 ? signal_cat_49 : signal_mux_51;
    assign signal_select_131 = signal_wire_42[3:3];
    assign signal_mux_53 = signal_select_131 ? signal_cat_48 : signal_mux_52;
    assign signal_select_132 = signal_wire_42[4:4];
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
    assign signal_select_151 = signal_wire_42[0:0];
    assign signal_mux_60 = signal_select_151 ? signal_cat_58 : signal_cat_62;
    assign signal_select_152 = signal_wire_42[1:1];
    assign signal_mux_61 = signal_select_152 ? signal_cat_57 : signal_mux_60;
    assign signal_select_153 = signal_wire_42[2:2];
    assign signal_mux_62 = signal_select_153 ? signal_cat_56 : signal_mux_61;
    assign signal_select_154 = signal_wire_42[3:3];
    assign signal_mux_63 = signal_select_154 ? signal_cat_55 : signal_mux_62;
    assign signal_select_155 = signal_wire_42[4:4];
    assign signal_mux_64 = signal_select_155 ? signal_cat_54 : signal_mux_63;
    assign signal_and_21 = signal_mux_64 & signal_const_13;
    assign signal_not_10 = ~ signal_and_21;
    assign signal_and_22 = pin_out_0 & signal_not_10;
    assign pin_out_side = signal_and_22 | signal_and_20;
    assign pin_out_base = signal_wire_43 ? pin_out_0 : pin_out_side;
    assign signal_wire_2 = program_write$data;
    assign signal_wire_3 = program_write$addr;
    assign signal_const_54 = 9'b000000000;
    assign signal_const_55 = 9'b000000001;
    assign signal_eq_8 = signal_const_54 == signal_wire_9;
    assign signal_mux_65 = signal_eq_8 ? signal_wire_8 : signal_const_55;
    assign signal_add = pc_next + signal_const_55;
    assign signal_eq_9 = pc_next == signal_wire_9;
    assign signal_mux_66 = signal_eq_9 ? signal_wire_8 : signal_add;
    assign signal_mux_67 = advance ? signal_mux_66 : pc_next;
    assign pc_after_next = start_0 ? signal_mux_65 : signal_mux_67;
    assign signal_mux_68 = jmp_go ? jmp_target_or_next : pc_after_next;
    assign signal_mux_69 = resume_asked ? pc_0 : signal_mux_68;
    assign signal_mux_70 = signal_wire_49 ? signal_const_54 : signal_mux_69;
    assign fetch_addr = signal_mux_70;
    assign signal_mux_71 = program_write ? signal_wire_3 : fetch_addr;
    assign signal_const_58 = 4'b0001;
    assign signal_eq_10 = d$sys_op$binary_variant == signal_const_58;
    assign signal_and_23 = is_opcode$7 & signal_eq_10;
    assign signal_and_24 = op_go & signal_and_23;
    assign signal_mux_72 = signal_and_24 ? vdd : halted_0;
    assign signal_not_11 = ~ resume_0;
    assign signal_and_25 = signal_wire_46 & halted_0;
    assign signal_and_26 = signal_and_25 & signal_not_11;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            step_asked <= signal_const_3;
        else
            step_asked <= signal_and_26;
    end
    assign signal_mux_73 = completes ? gnd : stepping_0;
    assign signal_mux_74 = resume_0 ? step_asked : signal_mux_73;
    assign signal_mux_75 = start_0 ? gnd : signal_mux_74;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_4 <= signal_const_3;
        else
            signal_reg_4 <= signal_mux_75;
    end
    assign stepping_0 = signal_reg_4;
    assign signal_and_27 = stepping_0 & completes;
    assign signal_mux_76 = signal_and_27 ? vdd : signal_mux_72;
    assign signal_not_12 = ~ decode_ok_0;
    assign signal_and_28 = issue & signal_not_12;
    assign signal_mux_77 = signal_and_28 ? vdd : signal_mux_76;
    assign completes = jmp_go | advance;
    assign signal_mux_78 = completes ? gnd : resumed_0;
    assign signal_mux_79 = resume_0 ? vdd : signal_mux_78;
    assign signal_mux_80 = start_0 ? gnd : signal_mux_79;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_5 <= signal_const_3;
        else
            signal_reg_5 <= signal_mux_80;
    end
    assign resumed_0 = signal_reg_5;
    assign signal_not_13 = ~ resumed_0;
    assign signal_wire_4 = config$break_pc;
    assign d$jmp_target = word[8:0];
    assign signal_not_14 = ~ signal_select_212;
    assign signal_not_15 = ~ signal_select_655;
    assign signal_const_64 = 5'b00000;
    assign signal_const_67 = 5'b00001;
    assign signal_add_1 = stuff_run_0 + signal_const_67;
    assign stuff_run_max = 5'b11111;
    assign signal_eq_11 = stuff_run_0 == stuff_run_max;
    assign signal_mux_81 = signal_eq_11 ? stuff_run_0 : signal_add_1;
    assign signal_wire_5 = config$stuff_level;
    assign signal_eq_12 = crossing_bit == signal_wire_5;
    assign signal_mux_82 = signal_eq_12 ? signal_mux_81 : signal_const_64;
    assign signal_mux_83 = bit_crosses ? signal_mux_82 : stuff_run_0;
    assign signal_const_69 = 4'b0110;
    assign signal_eq_13 = d$sys_op$binary_variant == signal_const_69;
    assign signal_and_29 = is_opcode$7 & signal_eq_13;
    assign stuff_run_next = signal_and_29 ? signal_const_64 : signal_mux_83;
    assign signal_mux_84 = go ? stuff_run_next : stuff_run_0;
    assign signal_mux_85 = start_0 ? signal_const_64 : signal_mux_84;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_6 <= signal_const_64;
        else
            signal_reg_6 <= signal_mux_85;
    end
    assign stuff_run_0 = signal_reg_6;
    assign signal_lt = stuff_run_0 < signal_wire_6;
    assign signal_not_16 = ~ signal_lt;
    assign signal_wire_6 = config$stuff_threshold;
    assign signal_eq_14 = signal_wire_6 == signal_const_64;
    assign signal_not_17 = ~ signal_eq_14;
    assign signal_and_30 = signal_not_17 & signal_not_16;
    assign signal_lt_1 = osr_count_0 < signal_wire_37;
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
        case (signal_wire_7)
        0:
            signal_mux_86 <= signal_select_183;
        1:
            signal_mux_86 <= signal_select_182;
        2:
            signal_mux_86 <= signal_select_181;
        3:
            signal_mux_86 <= signal_select_180;
        4:
            signal_mux_86 <= signal_select_179;
        5:
            signal_mux_86 <= signal_select_178;
        6:
            signal_mux_86 <= signal_select_177;
        7:
            signal_mux_86 <= signal_select_176;
        8:
            signal_mux_86 <= signal_select_175;
        9:
            signal_mux_86 <= signal_select_174;
        10:
            signal_mux_86 <= signal_select_173;
        11:
            signal_mux_86 <= signal_select_172;
        12:
            signal_mux_86 <= signal_select_171;
        13:
            signal_mux_86 <= signal_select_170;
        14:
            signal_mux_86 <= signal_select_169;
        15:
            signal_mux_86 <= signal_select_168;
        16:
            signal_mux_86 <= signal_select_167;
        17:
            signal_mux_86 <= signal_select_166;
        18:
            signal_mux_86 <= signal_select_165;
        19:
            signal_mux_86 <= signal_select_164;
        20:
            signal_mux_86 <= signal_select_163;
        21:
            signal_mux_86 <= signal_select_162;
        22:
            signal_mux_86 <= signal_select_161;
        23:
            signal_mux_86 <= signal_select_160;
        24:
            signal_mux_86 <= signal_select_159;
        25:
            signal_mux_86 <= signal_select_158;
        26:
            signal_mux_86 <= signal_select_157;
        default:
            signal_mux_86 <= signal_select_156;
        endcase
    end
    assign signal_not_18 = ~ signal_mux_86;
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
    assign signal_wire_7 = config$jmp_pin;
    always @* begin
        case (signal_wire_7)
        0:
            signal_mux_87 <= signal_select_211;
        1:
            signal_mux_87 <= signal_select_210;
        2:
            signal_mux_87 <= signal_select_209;
        3:
            signal_mux_87 <= signal_select_208;
        4:
            signal_mux_87 <= signal_select_207;
        5:
            signal_mux_87 <= signal_select_206;
        6:
            signal_mux_87 <= signal_select_205;
        7:
            signal_mux_87 <= signal_select_204;
        8:
            signal_mux_87 <= signal_select_203;
        9:
            signal_mux_87 <= signal_select_202;
        10:
            signal_mux_87 <= signal_select_201;
        11:
            signal_mux_87 <= signal_select_200;
        12:
            signal_mux_87 <= signal_select_199;
        13:
            signal_mux_87 <= signal_select_198;
        14:
            signal_mux_87 <= signal_select_197;
        15:
            signal_mux_87 <= signal_select_196;
        16:
            signal_mux_87 <= signal_select_195;
        17:
            signal_mux_87 <= signal_select_194;
        18:
            signal_mux_87 <= signal_select_193;
        19:
            signal_mux_87 <= signal_select_192;
        20:
            signal_mux_87 <= signal_select_191;
        21:
            signal_mux_87 <= signal_select_190;
        22:
            signal_mux_87 <= signal_select_189;
        23:
            signal_mux_87 <= signal_select_188;
        24:
            signal_mux_87 <= signal_select_187;
        25:
            signal_mux_87 <= signal_select_186;
        26:
            signal_mux_87 <= signal_select_185;
        default:
            signal_mux_87 <= signal_select_184;
        endcase
    end
    assign signal_eq_15 = x_0 == y_0;
    assign signal_not_19 = ~ signal_eq_15;
    assign signal_eq_16 = y_0 == signal_const_14;
    assign signal_not_20 = ~ signal_eq_16;
    assign signal_eq_17 = x_0 == signal_const_14;
    assign signal_not_21 = ~ signal_eq_17;
    always @* begin
        case (d$jmp_cond$binary_variant)
        0:
            jmp_taken <= vdd;
        1:
            jmp_taken <= signal_not_21;
        2:
            jmp_taken <= signal_not_20;
        3:
            jmp_taken <= signal_not_19;
        4:
            jmp_taken <= signal_mux_87;
        5:
            jmp_taken <= signal_not_18;
        6:
            jmp_taken <= signal_lt_1;
        7:
            jmp_taken <= signal_and_30;
        8:
            jmp_taken <= signal_not_15;
        9:
            jmp_taken <= signal_select_655;
        10:
            jmp_taken <= signal_not_14;
        default:
            jmp_taken <= signal_select_212;
        endcase
    end
    assign jmp_target_or_next = jmp_taken ? d$jmp_target : pc_next;
    assign signal_wire_8 = config$wrap_bottom;
    assign signal_add_2 = pc_0 + signal_const_55;
    assign signal_wire_9 = config$wrap_top;
    assign signal_eq_18 = pc_0 == signal_wire_9;
    assign pc_next = signal_eq_18 ? signal_wire_8 : signal_add_2;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_7 <= signal_const_54;
        else
            signal_reg_7 <= pc_value_next;
    end
    assign pc_0 = signal_reg_7;
    assign signal_mux_88 = advance ? pc_next : pc_0;
    assign signal_mux_89 = jmp_go ? jmp_target_or_next : signal_mux_88;
    assign pc_value_next = start_0 ? signal_const_54 : signal_mux_89;
    assign signal_eq_19 = pc_value_next == signal_wire_4;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_8 <= signal_const_3;
        else
            signal_reg_8 <= signal_eq_19;
    end
    assign at_break = signal_reg_8;
    assign signal_wire_10 = config$break_enable;
    assign signal_not_22 = ~ start_0;
    assign signal_const_79 = 5'b00111;
    assign signal_and_31 = signal_select_702 & signal_const_79;
    assign signal_and_32 = signal_select_702 & signal_const_79;
    assign signal_const_81 = 5'b01111;
    assign signal_and_33 = signal_select_702 & signal_const_81;
    always @* begin
        case (signal_wire_41)
        0:
            d$delay <= signal_select_702;
        1:
            d$delay <= signal_and_33;
        2:
            d$delay <= signal_and_32;
        default:
            d$delay <= signal_and_31;
        endcase
    end
    assign signal_sub_2 = stall_0 - signal_const_67;
    assign signal_eq_20 = stall_0 == signal_const_64;
    assign signal_not_23 = ~ signal_eq_20;
    assign signal_mux_90 = signal_not_23 ? signal_sub_2 : stall_0;
    assign signal_mux_91 = advance ? d$delay : signal_mux_90;
    assign signal_or_4 = jmp_go | signal_wire_49;
    assign signal_or_5 = signal_or_4 | resume_asked;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            refill <= signal_const_3;
        else
            refill <= signal_or_5;
    end
    assign signal_not_24 = ~ signal_select_655;
    assign signal_wire_11 = rx_pop;
    assign signal_mux_92 = is_opcode$2 ? isr_shifted : isr_0;
    assign signal_wire_12 = signal_mux_92;
    assign signal_not_25 = ~ signal_select_212;
    assign signal_const_85 = 4'b0011;
    assign signal_eq_21 = d$sys_op$binary_variant == signal_const_85;
    assign signal_and_34 = is_opcode$7 & signal_eq_21;
    assign signal_and_35 = is_opcode$2 & autopush_now;
    assign pushes = signal_and_35 | signal_and_34;
    assign signal_and_36 = op_go & pushes;
    assign signal_and_37 = signal_and_36 & signal_not_25;
    assign signal_wire_13 = signal_and_37;
    host_fifo
        rx
        ( .clock(signal_wire_51),
          .clear(signal_wire_48),
          .push$valid(signal_wire_13),
          .push$value(signal_wire_12),
          .pop(signal_wire_11),
          .flush(flush_0),
          .head(signal_inst[15:0]),
          .level(signal_inst[19:16]),
          .empty(signal_inst[20:20]),
          .full(signal_inst[21:21]) );
    assign signal_select_212 = signal_inst[21:21];
    assign signal_not_26 = ~ signal_select_212;
    assign signal_mux_93 = d$wait_polarity ? signal_not_24 : signal_not_26;
    assign signal_xor = t_0 ^ signal_cat_63;
    assign signal_sub_3 = t_0 - signal_cat_63;
    assign signal_cat_63 = { signal_const_15,
                             alu_operand };
    assign signal_add_3 = t_0 + signal_cat_63;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_94 <= signal_add_3;
        1:
            signal_mux_94 <= signal_sub_3;
        default:
            signal_mux_94 <= signal_xor;
        endcase
    end
    assign signal_const_88 = 2'b11;
    assign signal_eq_22 = d$alu_dest$binary_variant == signal_const_88;
    assign signal_mux_95 = signal_eq_22 ? signal_mux_94 : t_0;
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
    assign signal_not_27 = ~ mov_value24;
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value_t <= mov_value24;
        1:
            mov_value_t <= signal_not_27;
        default:
            mov_value_t <= signal_cat_64;
        endcase
    end
    assign signal_const_89 = 3'b111;
    assign signal_eq_23 = d$mov_dest$binary_variant == signal_const_89;
    assign signal_mux_96 = signal_eq_23 ? mov_value_t : t_0;
    assign signal_cat_65 = { signal_const_15,
                             out_value };
    assign signal_eq_24 = d$out_dest$binary_variant == signal_const_89;
    assign signal_mux_97 = signal_eq_24 ? signal_cat_65 : t_0;
    assign signal_wire_14 = config$period_fraction;
    assign signal_cat_66 = { gnd,
                             signal_wire_14 };
    assign signal_eq_25 = d$alu_dest$binary_variant == signal_const_88;
    assign signal_mux_98 = signal_eq_25 ? signal_const_14 : t_fraction_0;
    assign signal_eq_26 = d$mov_dest$binary_variant == signal_const_89;
    assign signal_mux_99 = signal_eq_26 ? signal_const_14 : t_fraction_0;
    assign signal_eq_27 = d$out_dest$binary_variant == signal_const_89;
    assign signal_mux_100 = signal_eq_27 ? signal_const_14 : t_fraction_0;
    assign signal_select_237 = fraction_sum[15:0];
    assign signal_mux_101 = advances_deadline ? signal_select_237 : t_fraction_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_fraction_next <= t_fraction_0;
        1:
            t_fraction_next <= signal_mux_101;
        2:
            t_fraction_next <= t_fraction_0;
        3:
            t_fraction_next <= signal_mux_100;
        4:
            t_fraction_next <= signal_mux_99;
        5:
            t_fraction_next <= t_fraction_0;
        6:
            t_fraction_next <= signal_mux_98;
        default:
            t_fraction_next <= t_fraction_0;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_9 <= signal_const_14;
        else
            if (go)
                signal_reg_9 <= t_fraction_next;
    end
    assign t_fraction_0 = signal_reg_9;
    assign signal_cat_67 = { gnd,
                             t_fraction_0 };
    assign fraction_sum = signal_cat_67 + signal_cat_66;
    assign signal_select_238 = fraction_sum[16:16];
    assign signal_const_99 = 23'b00000000000000000000000;
    assign signal_cat_68 = { signal_const_99,
                             signal_select_238 };
    assign signal_cat_69 = { signal_const_15,
                             p_0 };
    assign signal_add_4 = t_0 + signal_cat_69;
    assign t_advanced = signal_add_4 + signal_cat_68;
    assign signal_const_101 = 2'b10;
    assign signal_eq_28 = d$wait_source$binary_variant == signal_const_101;
    assign signal_and_38 = is_opcode$1 & signal_eq_28;
    assign releases_deadline = signal_and_38 & wait_ready;
    assign advances_deadline = releases_deadline & d$wait_polarity;
    assign signal_mux_102 = advances_deadline ? t_advanced : t_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_next <= t_0;
        1:
            t_next <= signal_mux_102;
        2:
            t_next <= t_0;
        3:
            t_next <= signal_mux_97;
        4:
            t_next <= signal_mux_96;
        5:
            t_next <= t_0;
        6:
            t_next <= signal_mux_95;
        default:
            t_next <= t_0;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_10 <= signal_const_4;
        else
            if (go)
                signal_reg_10 <= t_next;
    end
    assign t_0 = signal_reg_10;
    assign signal_sub_4 = now_0 - t_0;
    assign signal_select_239 = signal_sub_4[23:23];
    assign deadline_ready = ~ signal_select_239;
    assign signal_eq_29 = wait_pin_cur == d$wait_polarity;
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
    assign signal_eq_30 = wait_pin_cur == wait_pin_prev;
    assign signal_not_28 = ~ signal_eq_30;
    assign signal_and_39 = signal_not_28 & signal_eq_29;
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
    assign signal_select_295 = signal_wire_44[0:0];
    assign signal_select_296 = signal_wire_44[1:1];
    assign signal_select_297 = signal_wire_44[2:2];
    assign signal_select_298 = signal_wire_44[3:3];
    assign signal_select_299 = signal_wire_44[4:4];
    assign signal_select_300 = pin_out_0[5:5];
    assign signal_select_301 = pin_out_0[6:6];
    assign signal_select_302 = pin_out_0[7:7];
    assign signal_select_303 = pin_out_0[8:8];
    assign signal_select_304 = pin_out_0[9:9];
    assign signal_select_305 = pin_out_0[10:10];
    assign signal_select_306 = pin_out_0[11:11];
    assign signal_select_307 = pin_out_0[12:12];
    assign signal_select_308 = signal_wire_44[12:12];
    assign signal_select_309 = pin_dir_0[12:12];
    assign signal_mux_103 = signal_select_309 ? signal_select_307 : signal_select_308;
    assign signal_select_310 = pin_out_0[13:13];
    assign signal_select_311 = signal_wire_44[13:13];
    assign signal_select_312 = pin_dir_0[13:13];
    assign signal_mux_104 = signal_select_312 ? signal_select_310 : signal_select_311;
    assign signal_select_313 = pin_out_0[14:14];
    assign signal_select_314 = signal_wire_44[14:14];
    assign signal_select_315 = pin_dir_0[14:14];
    assign signal_mux_105 = signal_select_315 ? signal_select_313 : signal_select_314;
    assign signal_select_316 = pin_out_0[15:15];
    assign signal_select_317 = signal_wire_44[15:15];
    assign signal_select_318 = pin_dir_0[15:15];
    assign signal_mux_106 = signal_select_318 ? signal_select_316 : signal_select_317;
    assign signal_select_319 = pin_out_0[16:16];
    assign signal_select_320 = signal_wire_44[16:16];
    assign signal_select_321 = pin_dir_0[16:16];
    assign signal_mux_107 = signal_select_321 ? signal_select_319 : signal_select_320;
    assign signal_select_322 = pin_out_0[17:17];
    assign signal_select_323 = signal_wire_44[17:17];
    assign signal_select_324 = pin_dir_0[17:17];
    assign signal_mux_108 = signal_select_324 ? signal_select_322 : signal_select_323;
    assign signal_select_325 = pin_out_0[18:18];
    assign signal_select_326 = signal_wire_44[18:18];
    assign signal_select_327 = pin_dir_0[18:18];
    assign signal_mux_109 = signal_select_327 ? signal_select_325 : signal_select_326;
    assign signal_select_328 = pin_out_0[19:19];
    assign signal_select_329 = signal_wire_44[19:19];
    assign signal_select_330 = signal_mux_113[27:12];
    assign signal_select_331 = signal_mux_113[11:0];
    assign signal_cat_70 = { signal_select_331,
                             signal_select_330 };
    assign signal_select_332 = signal_mux_112[27:20];
    assign signal_select_333 = signal_mux_112[19:0];
    assign signal_cat_71 = { signal_select_333,
                             signal_select_332 };
    assign signal_select_334 = signal_mux_111[27:24];
    assign signal_select_335 = signal_mux_111[23:0];
    assign signal_cat_72 = { signal_select_335,
                             signal_select_334 };
    assign signal_select_336 = signal_mux_110[27:26];
    assign signal_select_337 = signal_mux_110[25:0];
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
    assign signal_select_340 = signal_wire_16[0:0];
    assign signal_mux_110 = signal_select_340 ? signal_cat_74 : signal_cat_76;
    assign signal_select_341 = signal_wire_16[1:1];
    assign signal_mux_111 = signal_select_341 ? signal_cat_73 : signal_mux_110;
    assign signal_select_342 = signal_wire_16[2:2];
    assign signal_mux_112 = signal_select_342 ? signal_cat_72 : signal_mux_111;
    assign signal_select_343 = signal_wire_16[3:3];
    assign signal_mux_113 = signal_select_343 ? signal_cat_71 : signal_mux_112;
    assign signal_select_344 = signal_wire_16[4:4];
    assign signal_mux_114 = signal_select_344 ? signal_cat_70 : signal_mux_113;
    assign signal_and_40 = signal_mux_114 & signal_and_41;
    assign signal_const_105 = 28'b0000000011111111000000000000;
    assign signal_select_345 = signal_mux_123[27:12];
    assign signal_select_346 = signal_mux_123[11:0];
    assign signal_cat_77 = { signal_select_346,
                             signal_select_345 };
    assign signal_select_347 = signal_mux_122[27:20];
    assign signal_select_348 = signal_mux_122[19:0];
    assign signal_cat_78 = { signal_select_348,
                             signal_select_347 };
    assign signal_select_349 = signal_mux_121[27:24];
    assign signal_select_350 = signal_mux_121[23:0];
    assign signal_cat_79 = { signal_select_350,
                             signal_select_349 };
    assign signal_select_351 = signal_mux_120[27:26];
    assign signal_select_352 = signal_mux_120[25:0];
    assign signal_cat_80 = { signal_select_352,
                             signal_select_351 };
    assign signal_select_353 = signal_cat_86[27:27];
    assign signal_select_354 = signal_cat_86[26:0];
    assign signal_cat_81 = { signal_select_354,
                             signal_select_353 };
    assign signal_select_355 = signal_mux_117[7:0];
    assign signal_cat_82 = { signal_select_355,
                             signal_const_15 };
    assign signal_select_356 = signal_mux_116[11:0];
    assign signal_cat_83 = { signal_select_356,
                             signal_const_16 };
    assign signal_select_357 = signal_mux_115[13:0];
    assign signal_cat_84 = { signal_select_357,
                             signal_const_17 };
    assign signal_select_358 = signal_cat_85[0:0];
    assign signal_mux_115 = signal_select_358 ? signal_const_18 : signal_const_19;
    assign signal_select_359 = signal_cat_85[1:1];
    assign signal_mux_116 = signal_select_359 ? signal_cat_84 : signal_mux_115;
    assign signal_select_360 = signal_cat_85[2:2];
    assign signal_mux_117 = signal_select_360 ? signal_cat_83 : signal_mux_116;
    assign signal_select_361 = signal_cat_85[3:3];
    assign signal_mux_118 = signal_select_361 ? signal_cat_82 : signal_mux_117;
    assign signal_wire_15 = config$set_count;
    assign signal_cat_85 = { signal_const_17,
                             signal_wire_15 };
    assign signal_select_362 = signal_cat_85[4:4];
    assign signal_mux_119 = signal_select_362 ? signal_const_14 : signal_mux_118;
    assign signal_not_29 = ~ signal_mux_119;
    assign signal_cat_86 = { signal_const_12,
                             signal_not_29 };
    assign signal_select_363 = signal_wire_16[0:0];
    assign signal_mux_120 = signal_select_363 ? signal_cat_81 : signal_cat_86;
    assign signal_select_364 = signal_wire_16[1:1];
    assign signal_mux_121 = signal_select_364 ? signal_cat_80 : signal_mux_120;
    assign signal_select_365 = signal_wire_16[2:2];
    assign signal_mux_122 = signal_select_365 ? signal_cat_79 : signal_mux_121;
    assign signal_select_366 = signal_wire_16[3:3];
    assign signal_mux_123 = signal_select_366 ? signal_cat_78 : signal_mux_122;
    assign signal_wire_16 = config$set_base;
    assign signal_select_367 = signal_wire_16[4:4];
    assign signal_mux_124 = signal_select_367 ? signal_cat_77 : signal_mux_123;
    assign signal_and_41 = signal_mux_124 & signal_const_105;
    assign signal_not_30 = ~ signal_and_41;
    assign signal_and_42 = pin_dir_base & signal_not_30;
    assign signal_or_6 = signal_and_42 | signal_and_40;
    assign signal_const_114 = 3'b011;
    assign signal_eq_31 = d$set_dest$binary_variant == signal_const_114;
    assign signal_mux_125 = signal_eq_31 ? signal_or_6 : pin_dir_base;
    assign signal_select_368 = signal_mux_129[27:12];
    assign signal_select_369 = signal_mux_129[11:0];
    assign signal_cat_87 = { signal_select_369,
                             signal_select_368 };
    assign signal_select_370 = signal_mux_128[27:20];
    assign signal_select_371 = signal_mux_128[19:0];
    assign signal_cat_88 = { signal_select_371,
                             signal_select_370 };
    assign signal_select_372 = signal_mux_127[27:24];
    assign signal_select_373 = signal_mux_127[23:0];
    assign signal_cat_89 = { signal_select_373,
                             signal_select_372 };
    assign signal_select_374 = signal_mux_126[27:26];
    assign signal_select_375 = signal_mux_126[25:0];
    assign signal_cat_90 = { signal_select_375,
                             signal_select_374 };
    assign signal_select_376 = signal_cat_92[27:27];
    assign signal_select_377 = signal_cat_92[26:0];
    assign signal_cat_91 = { signal_select_377,
                             signal_select_376 };
    assign signal_cat_92 = { signal_const_12,
                             mov_value };
    assign signal_select_378 = signal_wire_40[0:0];
    assign signal_mux_126 = signal_select_378 ? signal_cat_91 : signal_cat_92;
    assign signal_select_379 = signal_wire_40[1:1];
    assign signal_mux_127 = signal_select_379 ? signal_cat_90 : signal_mux_126;
    assign signal_select_380 = signal_wire_40[2:2];
    assign signal_mux_128 = signal_select_380 ? signal_cat_89 : signal_mux_127;
    assign signal_select_381 = signal_wire_40[3:3];
    assign signal_mux_129 = signal_select_381 ? signal_cat_88 : signal_mux_128;
    assign signal_select_382 = signal_wire_40[4:4];
    assign signal_mux_130 = signal_select_382 ? signal_cat_87 : signal_mux_129;
    assign signal_and_43 = signal_mux_130 & signal_and_44;
    assign signal_select_383 = signal_mux_139[27:12];
    assign signal_select_384 = signal_mux_139[11:0];
    assign signal_cat_93 = { signal_select_384,
                             signal_select_383 };
    assign signal_select_385 = signal_mux_138[27:20];
    assign signal_select_386 = signal_mux_138[19:0];
    assign signal_cat_94 = { signal_select_386,
                             signal_select_385 };
    assign signal_select_387 = signal_mux_137[27:24];
    assign signal_select_388 = signal_mux_137[23:0];
    assign signal_cat_95 = { signal_select_388,
                             signal_select_387 };
    assign signal_select_389 = signal_mux_136[27:26];
    assign signal_select_390 = signal_mux_136[25:0];
    assign signal_cat_96 = { signal_select_390,
                             signal_select_389 };
    assign signal_select_391 = signal_cat_101[27:27];
    assign signal_select_392 = signal_cat_101[26:0];
    assign signal_cat_97 = { signal_select_392,
                             signal_select_391 };
    assign signal_select_393 = signal_mux_133[7:0];
    assign signal_cat_98 = { signal_select_393,
                             signal_const_15 };
    assign signal_select_394 = signal_mux_132[11:0];
    assign signal_cat_99 = { signal_select_394,
                             signal_const_16 };
    assign signal_select_395 = signal_mux_131[13:0];
    assign signal_cat_100 = { signal_select_395,
                              signal_const_17 };
    assign signal_select_396 = signal_wire_17[0:0];
    assign signal_mux_131 = signal_select_396 ? signal_const_18 : signal_const_19;
    assign signal_select_397 = signal_wire_17[1:1];
    assign signal_mux_132 = signal_select_397 ? signal_cat_100 : signal_mux_131;
    assign signal_select_398 = signal_wire_17[2:2];
    assign signal_mux_133 = signal_select_398 ? signal_cat_99 : signal_mux_132;
    assign signal_select_399 = signal_wire_17[3:3];
    assign signal_mux_134 = signal_select_399 ? signal_cat_98 : signal_mux_133;
    assign signal_wire_17 = config$out_count;
    assign signal_select_400 = signal_wire_17[4:4];
    assign signal_mux_135 = signal_select_400 ? signal_const_14 : signal_mux_134;
    assign signal_not_31 = ~ signal_mux_135;
    assign signal_cat_101 = { signal_const_12,
                              signal_not_31 };
    assign signal_select_401 = signal_wire_40[0:0];
    assign signal_mux_136 = signal_select_401 ? signal_cat_97 : signal_cat_101;
    assign signal_select_402 = signal_wire_40[1:1];
    assign signal_mux_137 = signal_select_402 ? signal_cat_96 : signal_mux_136;
    assign signal_select_403 = signal_wire_40[2:2];
    assign signal_mux_138 = signal_select_403 ? signal_cat_95 : signal_mux_137;
    assign signal_select_404 = signal_wire_40[3:3];
    assign signal_mux_139 = signal_select_404 ? signal_cat_94 : signal_mux_138;
    assign signal_select_405 = signal_wire_40[4:4];
    assign signal_mux_140 = signal_select_405 ? signal_cat_93 : signal_mux_139;
    assign signal_and_44 = signal_mux_140 & signal_const_105;
    assign signal_not_32 = ~ signal_and_44;
    assign signal_and_45 = pin_dir_base & signal_not_32;
    assign signal_or_7 = signal_and_45 | signal_and_43;
    assign signal_eq_32 = d$mov_dest$binary_variant == signal_const_114;
    assign signal_mux_141 = signal_eq_32 ? signal_or_7 : pin_dir_base;
    assign signal_select_406 = signal_mux_254[27:12];
    assign signal_select_407 = signal_mux_254[11:0];
    assign signal_cat_102 = { signal_select_407,
                              signal_select_406 };
    assign signal_select_408 = signal_mux_253[27:20];
    assign signal_select_409 = signal_mux_253[19:0];
    assign signal_cat_103 = { signal_select_409,
                              signal_select_408 };
    assign signal_select_410 = signal_mux_252[27:24];
    assign signal_select_411 = signal_mux_252[23:0];
    assign signal_cat_104 = { signal_select_411,
                              signal_select_410 };
    assign signal_select_412 = signal_mux_251[27:26];
    assign signal_select_413 = signal_mux_251[25:0];
    assign signal_cat_105 = { signal_select_413,
                              signal_select_412 };
    assign signal_select_414 = signal_cat_169[27:27];
    assign signal_select_415 = signal_cat_169[26:0];
    assign signal_cat_106 = { signal_select_415,
                              signal_select_414 };
    assign signal_and_46 = osr_before & mask;
    assign signal_select_416 = signal_mux_248[15:8];
    assign signal_cat_107 = { signal_const_15,
                              signal_select_416 };
    assign signal_select_417 = signal_mux_247[15:4];
    assign signal_cat_108 = { signal_const_16,
                              signal_select_417 };
    assign signal_select_418 = signal_mux_246[15:2];
    assign signal_cat_109 = { signal_const_17,
                              signal_select_418 };
    assign signal_select_419 = osr_before[15:1];
    assign signal_cat_110 = { signal_const_3,
                              signal_select_419 };
    assign signal_wire_18 = data_write$data;
    assign signal_wire_19 = data_write$addr;
    assign signal_select_420 = x_0[8:0];
    assign signal_add_5 = data_ptr_0 + signal_const_55;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_11 <= signal_const_54;
        else
            signal_reg_11 <= data_ptr_next;
    end
    assign data_ptr_0 = signal_reg_11;
    assign signal_and_47 = op_go & is_opcode$3;
    assign signal_and_48 = signal_and_47 & pull_data;
    assign signal_mux_142 = signal_and_48 ? signal_add_5 : data_ptr_0;
    assign signal_const_134 = 4'b1000;
    assign signal_eq_33 = d$sys_op$binary_variant == signal_const_134;
    assign signal_and_49 = is_opcode$7 & signal_eq_33;
    assign signal_and_50 = op_go & signal_and_49;
    assign signal_mux_143 = signal_and_50 ? signal_select_420 : signal_mux_142;
    assign signal_mux_144 = start_0 ? signal_const_54 : signal_mux_143;
    assign data_ptr_next = signal_mux_144;
    assign signal_mux_145 = data_write ? signal_wire_19 : data_ptr_next;
    assign signal_wire_20 = data_write$valid;
    assign data_write = signal_wire_20 & halted_0;
    sram_macro
        data_memory
        ( .clock(signal_wire_51),
          .men(vdd),
          .wen(data_write),
          .ren(vdd),
          .addr(signal_mux_145),
          .din(signal_wire_18),
          .bm(signal_const_19),
          .dout(signal_inst_1[15:0]) );
    assign signal_wire_21 = signal_inst_1;
    assign signal_select_421 = signal_inst_2[15:0];
    assign signal_not_33 = ~ signal_select_655;
    assign signal_and_51 = pulls & signal_not_33;
    assign signal_mux_146 = signal_and_51 ? signal_select_421 : osr_0;
    assign signal_select_422 = signal_select_636[15:15];
    assign signal_select_423 = signal_select_636[14:14];
    assign signal_select_424 = signal_select_636[13:13];
    assign signal_select_425 = signal_select_636[12:12];
    assign signal_select_426 = signal_select_636[11:11];
    assign signal_select_427 = signal_select_636[10:10];
    assign signal_select_428 = signal_select_636[9:9];
    assign signal_select_429 = signal_select_636[8:8];
    assign signal_select_430 = signal_select_636[7:7];
    assign signal_select_431 = signal_select_636[6:6];
    assign signal_select_432 = signal_select_636[5:5];
    assign signal_select_433 = signal_select_636[4:4];
    assign signal_select_434 = signal_select_636[3:3];
    assign signal_select_435 = signal_select_636[2:2];
    assign signal_select_436 = signal_select_636[1:1];
    assign signal_select_437 = signal_select_636[0:0];
    assign signal_cat_111 = { signal_select_437,
                              signal_select_436,
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
                              signal_select_422 };
    assign signal_not_34 = ~ signal_select_636;
    assign signal_cat_112 = { signal_const_15,
                              osr_0 };
    assign signal_cat_113 = { signal_const_15,
                              isr_0 };
    assign signal_cat_114 = { signal_const_15,
                              y_0 };
    assign signal_xor_1 = x_0 ^ alu_operand;
    assign signal_sub_5 = x_0 - alu_operand;
    assign signal_eq_34 = d$sys_op$binary_variant == signal_const_85;
    assign signal_and_52 = is_opcode$7 & signal_eq_34;
    assign signal_mux_147 = signal_and_52 ? signal_const_14 : isr_0;
    assign signal_eq_35 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_148 = signal_eq_35 ? mov_value : isr_0;
    assign signal_eq_36 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_149 = signal_eq_36 ? out_value : isr_0;
    assign signal_select_438 = signal_mux_152[7:0];
    assign signal_cat_115 = { signal_select_438,
                              signal_const_15 };
    assign signal_select_439 = signal_mux_151[11:0];
    assign signal_cat_116 = { signal_select_439,
                              signal_const_16 };
    assign signal_select_440 = signal_mux_150[13:0];
    assign signal_cat_117 = { signal_select_440,
                              signal_const_17 };
    assign signal_select_441 = in_value[14:0];
    assign signal_cat_118 = { signal_select_441,
                              signal_const_3 };
    assign signal_select_442 = shift_back[0:0];
    assign signal_mux_150 = signal_select_442 ? signal_cat_118 : in_value;
    assign signal_select_443 = shift_back[1:1];
    assign signal_mux_151 = signal_select_443 ? signal_cat_117 : signal_mux_150;
    assign signal_select_444 = shift_back[2:2];
    assign signal_mux_152 = signal_select_444 ? signal_cat_116 : signal_mux_151;
    assign signal_select_445 = shift_back[3:3];
    assign signal_mux_153 = signal_select_445 ? signal_cat_115 : signal_mux_152;
    assign signal_select_446 = shift_back[4:4];
    assign signal_mux_154 = signal_select_446 ? signal_const_14 : signal_mux_153;
    assign signal_select_447 = signal_mux_157[15:8];
    assign signal_cat_119 = { signal_const_15,
                              signal_select_447 };
    assign signal_select_448 = signal_mux_156[15:4];
    assign signal_cat_120 = { signal_const_16,
                              signal_select_448 };
    assign signal_select_449 = signal_mux_155[15:2];
    assign signal_cat_121 = { signal_const_17,
                              signal_select_449 };
    assign signal_select_450 = isr_0[15:1];
    assign signal_cat_122 = { signal_const_3,
                              signal_select_450 };
    assign signal_select_451 = d$shift_count[0:0];
    assign signal_mux_155 = signal_select_451 ? signal_cat_122 : isr_0;
    assign signal_select_452 = d$shift_count[1:1];
    assign signal_mux_156 = signal_select_452 ? signal_cat_121 : signal_mux_155;
    assign signal_select_453 = d$shift_count[2:2];
    assign signal_mux_157 = signal_select_453 ? signal_cat_120 : signal_mux_156;
    assign signal_select_454 = d$shift_count[3:3];
    assign signal_mux_158 = signal_select_454 ? signal_cat_119 : signal_mux_157;
    assign signal_select_455 = d$shift_count[4:4];
    assign signal_mux_159 = signal_select_455 ? signal_const_14 : signal_mux_158;
    assign signal_or_8 = signal_mux_159 | signal_mux_154;
    assign signal_select_456 = signal_mux_162[7:0];
    assign signal_cat_123 = { signal_select_456,
                              signal_const_15 };
    assign signal_select_457 = signal_mux_161[11:0];
    assign signal_cat_124 = { signal_select_457,
                              signal_const_16 };
    assign signal_select_458 = signal_mux_160[13:0];
    assign signal_cat_125 = { signal_select_458,
                              signal_const_17 };
    assign signal_select_459 = d$shift_count[0:0];
    assign signal_mux_160 = signal_select_459 ? signal_const_18 : signal_const_19;
    assign signal_select_460 = d$shift_count[1:1];
    assign signal_mux_161 = signal_select_460 ? signal_cat_125 : signal_mux_160;
    assign signal_select_461 = d$shift_count[2:2];
    assign signal_mux_162 = signal_select_461 ? signal_cat_124 : signal_mux_161;
    assign signal_select_462 = d$shift_count[3:3];
    assign signal_mux_163 = signal_select_462 ? signal_cat_123 : signal_mux_162;
    assign signal_select_463 = d$shift_count[4:4];
    assign signal_mux_164 = signal_select_463 ? signal_const_14 : signal_mux_163;
    assign mask = ~ signal_mux_164;
    assign signal_wire_22 = config$capture_rising;
    assign signal_select_464 = sample[27:27];
    assign signal_select_465 = sample[26:26];
    assign signal_select_466 = sample[25:25];
    assign signal_select_467 = sample[24:24];
    assign signal_select_468 = sample[23:23];
    assign signal_select_469 = sample[22:22];
    assign signal_select_470 = sample[21:21];
    assign signal_select_471 = sample[20:20];
    assign signal_select_472 = sample[19:19];
    assign signal_select_473 = sample[18:18];
    assign signal_select_474 = sample[17:17];
    assign signal_select_475 = sample[16:16];
    assign signal_select_476 = sample[15:15];
    assign signal_select_477 = sample[14:14];
    assign signal_select_478 = sample[13:13];
    assign signal_select_479 = sample[12:12];
    assign signal_select_480 = sample[11:11];
    assign signal_select_481 = sample[10:10];
    assign signal_select_482 = sample[9:9];
    assign signal_select_483 = sample[8:8];
    assign signal_select_484 = sample[7:7];
    assign signal_select_485 = sample[6:6];
    assign signal_select_486 = sample[5:5];
    assign signal_select_487 = sample[4:4];
    assign signal_select_488 = sample[3:3];
    assign signal_select_489 = sample[2:2];
    assign signal_select_490 = sample[1:1];
    assign signal_select_491 = sample[0:0];
    always @* begin
        case (signal_wire_23)
        0:
            signal_mux_165 <= signal_select_491;
        1:
            signal_mux_165 <= signal_select_490;
        2:
            signal_mux_165 <= signal_select_489;
        3:
            signal_mux_165 <= signal_select_488;
        4:
            signal_mux_165 <= signal_select_487;
        5:
            signal_mux_165 <= signal_select_486;
        6:
            signal_mux_165 <= signal_select_485;
        7:
            signal_mux_165 <= signal_select_484;
        8:
            signal_mux_165 <= signal_select_483;
        9:
            signal_mux_165 <= signal_select_482;
        10:
            signal_mux_165 <= signal_select_481;
        11:
            signal_mux_165 <= signal_select_480;
        12:
            signal_mux_165 <= signal_select_479;
        13:
            signal_mux_165 <= signal_select_478;
        14:
            signal_mux_165 <= signal_select_477;
        15:
            signal_mux_165 <= signal_select_476;
        16:
            signal_mux_165 <= signal_select_475;
        17:
            signal_mux_165 <= signal_select_474;
        18:
            signal_mux_165 <= signal_select_473;
        19:
            signal_mux_165 <= signal_select_472;
        20:
            signal_mux_165 <= signal_select_471;
        21:
            signal_mux_165 <= signal_select_470;
        22:
            signal_mux_165 <= signal_select_469;
        23:
            signal_mux_165 <= signal_select_468;
        24:
            signal_mux_165 <= signal_select_467;
        25:
            signal_mux_165 <= signal_select_466;
        26:
            signal_mux_165 <= signal_select_465;
        default:
            signal_mux_165 <= signal_select_464;
        endcase
    end
    assign signal_eq_37 = signal_mux_165 == signal_wire_22;
    assign signal_select_492 = pins_sampled[27:27];
    assign signal_select_493 = pins_sampled[26:26];
    assign signal_select_494 = pins_sampled[25:25];
    assign signal_select_495 = pins_sampled[24:24];
    assign signal_select_496 = pins_sampled[23:23];
    assign signal_select_497 = pins_sampled[22:22];
    assign signal_select_498 = pins_sampled[21:21];
    assign signal_select_499 = pins_sampled[20:20];
    assign signal_select_500 = pins_sampled[19:19];
    assign signal_select_501 = pins_sampled[18:18];
    assign signal_select_502 = pins_sampled[17:17];
    assign signal_select_503 = pins_sampled[16:16];
    assign signal_select_504 = pins_sampled[15:15];
    assign signal_select_505 = pins_sampled[14:14];
    assign signal_select_506 = pins_sampled[13:13];
    assign signal_select_507 = pins_sampled[12:12];
    assign signal_select_508 = pins_sampled[11:11];
    assign signal_select_509 = pins_sampled[10:10];
    assign signal_select_510 = pins_sampled[9:9];
    assign signal_select_511 = pins_sampled[8:8];
    assign signal_select_512 = pins_sampled[7:7];
    assign signal_select_513 = pins_sampled[6:6];
    assign signal_select_514 = pins_sampled[5:5];
    assign signal_select_515 = pins_sampled[4:4];
    assign signal_select_516 = pins_sampled[3:3];
    assign signal_select_517 = pins_sampled[2:2];
    assign signal_select_518 = pins_sampled[1:1];
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_12 <= signal_const_10;
        else
            signal_reg_12 <= sample;
    end
    assign pins_sampled = signal_reg_12;
    assign signal_select_519 = pins_sampled[0:0];
    always @* begin
        case (signal_wire_23)
        0:
            signal_mux_166 <= signal_select_519;
        1:
            signal_mux_166 <= signal_select_518;
        2:
            signal_mux_166 <= signal_select_517;
        3:
            signal_mux_166 <= signal_select_516;
        4:
            signal_mux_166 <= signal_select_515;
        5:
            signal_mux_166 <= signal_select_514;
        6:
            signal_mux_166 <= signal_select_513;
        7:
            signal_mux_166 <= signal_select_512;
        8:
            signal_mux_166 <= signal_select_511;
        9:
            signal_mux_166 <= signal_select_510;
        10:
            signal_mux_166 <= signal_select_509;
        11:
            signal_mux_166 <= signal_select_508;
        12:
            signal_mux_166 <= signal_select_507;
        13:
            signal_mux_166 <= signal_select_506;
        14:
            signal_mux_166 <= signal_select_505;
        15:
            signal_mux_166 <= signal_select_504;
        16:
            signal_mux_166 <= signal_select_503;
        17:
            signal_mux_166 <= signal_select_502;
        18:
            signal_mux_166 <= signal_select_501;
        19:
            signal_mux_166 <= signal_select_500;
        20:
            signal_mux_166 <= signal_select_499;
        21:
            signal_mux_166 <= signal_select_498;
        22:
            signal_mux_166 <= signal_select_497;
        23:
            signal_mux_166 <= signal_select_496;
        24:
            signal_mux_166 <= signal_select_495;
        25:
            signal_mux_166 <= signal_select_494;
        26:
            signal_mux_166 <= signal_select_493;
        default:
            signal_mux_166 <= signal_select_492;
        endcase
    end
    assign signal_select_520 = sample[27:27];
    assign signal_select_521 = sample[26:26];
    assign signal_select_522 = sample[25:25];
    assign signal_select_523 = sample[24:24];
    assign signal_select_524 = sample[23:23];
    assign signal_select_525 = sample[22:22];
    assign signal_select_526 = sample[21:21];
    assign signal_select_527 = sample[20:20];
    assign signal_select_528 = sample[19:19];
    assign signal_select_529 = sample[18:18];
    assign signal_select_530 = sample[17:17];
    assign signal_select_531 = sample[16:16];
    assign signal_select_532 = sample[15:15];
    assign signal_select_533 = sample[14:14];
    assign signal_select_534 = sample[13:13];
    assign signal_select_535 = sample[12:12];
    assign signal_select_536 = sample[11:11];
    assign signal_select_537 = sample[10:10];
    assign signal_select_538 = sample[9:9];
    assign signal_select_539 = sample[8:8];
    assign signal_select_540 = sample[7:7];
    assign signal_select_541 = sample[6:6];
    assign signal_select_542 = sample[5:5];
    assign signal_select_543 = sample[4:4];
    assign signal_select_544 = sample[3:3];
    assign signal_select_545 = sample[2:2];
    assign signal_select_546 = sample[1:1];
    assign signal_select_547 = sample[0:0];
    assign signal_wire_23 = config$capture_pin;
    always @* begin
        case (signal_wire_23)
        0:
            signal_mux_167 <= signal_select_547;
        1:
            signal_mux_167 <= signal_select_546;
        2:
            signal_mux_167 <= signal_select_545;
        3:
            signal_mux_167 <= signal_select_544;
        4:
            signal_mux_167 <= signal_select_543;
        5:
            signal_mux_167 <= signal_select_542;
        6:
            signal_mux_167 <= signal_select_541;
        7:
            signal_mux_167 <= signal_select_540;
        8:
            signal_mux_167 <= signal_select_539;
        9:
            signal_mux_167 <= signal_select_538;
        10:
            signal_mux_167 <= signal_select_537;
        11:
            signal_mux_167 <= signal_select_536;
        12:
            signal_mux_167 <= signal_select_535;
        13:
            signal_mux_167 <= signal_select_534;
        14:
            signal_mux_167 <= signal_select_533;
        15:
            signal_mux_167 <= signal_select_532;
        16:
            signal_mux_167 <= signal_select_531;
        17:
            signal_mux_167 <= signal_select_530;
        18:
            signal_mux_167 <= signal_select_529;
        19:
            signal_mux_167 <= signal_select_528;
        20:
            signal_mux_167 <= signal_select_527;
        21:
            signal_mux_167 <= signal_select_526;
        22:
            signal_mux_167 <= signal_select_525;
        23:
            signal_mux_167 <= signal_select_524;
        24:
            signal_mux_167 <= signal_select_523;
        25:
            signal_mux_167 <= signal_select_522;
        26:
            signal_mux_167 <= signal_select_521;
        default:
            signal_mux_167 <= signal_select_520;
        endcase
    end
    assign signal_eq_38 = signal_mux_167 == signal_mux_166;
    assign signal_not_35 = ~ signal_eq_38;
    assign signal_const_165 = 4'b0111;
    assign signal_eq_39 = d$sys_op$binary_variant == signal_const_165;
    assign signal_and_53 = is_opcode$7 & signal_eq_39;
    assign signal_and_54 = op_go & signal_and_53;
    assign signal_mux_168 = signal_and_54 ? vdd : capture_armed_0;
    assign signal_mux_169 = captured ? gnd : signal_mux_168;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_13 <= signal_const_3;
        else
            signal_reg_13 <= signal_mux_169;
    end
    assign capture_armed_0 = signal_reg_13;
    assign signal_and_55 = capture_armed_0 & signal_not_35;
    assign captured = signal_and_55 & signal_eq_37;
    assign signal_const_169 = 24'b000000000000000000000001;
    assign signal_add_6 = now_0 + signal_const_169;
    assign signal_mux_170 = start_0 ? signal_const_4 : signal_add_6;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_14 <= signal_const_4;
        else
            signal_reg_14 <= signal_mux_170;
    end
    assign now_0 = signal_reg_14;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_15 <= signal_const_4;
        else
            if (captured)
                signal_reg_15 <= now_0;
    end
    assign capture_0 = signal_reg_15;
    assign signal_select_548 = capture_0[15:0];
    assign signal_wire_24 = config$crc_init;
    assign signal_select_549 = signal_mux_173[7:0];
    assign signal_cat_126 = { signal_select_549,
                              signal_const_15 };
    assign signal_select_550 = signal_mux_172[11:0];
    assign signal_cat_127 = { signal_select_550,
                              signal_const_16 };
    assign signal_select_551 = signal_mux_171[13:0];
    assign signal_cat_128 = { signal_select_551,
                              signal_const_17 };
    assign signal_select_552 = signal_wire_26[0:0];
    assign signal_mux_171 = signal_select_552 ? signal_const_18 : signal_const_19;
    assign signal_select_553 = signal_wire_26[1:1];
    assign signal_mux_172 = signal_select_553 ? signal_cat_128 : signal_mux_171;
    assign signal_select_554 = signal_wire_26[2:2];
    assign signal_mux_173 = signal_select_554 ? signal_cat_127 : signal_mux_172;
    assign signal_select_555 = signal_wire_26[3:3];
    assign signal_mux_174 = signal_select_555 ? signal_cat_126 : signal_mux_173;
    assign signal_select_556 = signal_wire_26[4:4];
    assign signal_mux_175 = signal_select_556 ? signal_const_14 : signal_mux_174;
    assign signal_not_36 = ~ signal_mux_175;
    assign signal_xor_2 = signal_cat_129 ^ signal_wire_25;
    assign signal_select_557 = crc_0[15:1];
    assign signal_cat_129 = { signal_const_3,
                              signal_select_557 };
    assign signal_select_558 = crc_0[0:0];
    assign signal_xor_3 = signal_select_558 ^ crossing_bit;
    assign signal_mux_176 = signal_xor_3 ? signal_xor_2 : signal_cat_129;
    assign signal_wire_25 = config$crc_poly;
    assign signal_xor_4 = signal_cat_130 ^ signal_wire_25;
    assign signal_select_559 = crc_0[14:0];
    assign signal_cat_130 = { signal_select_559,
                              signal_const_3 };
    assign signal_select_560 = in_value[0:0];
    assign signal_select_561 = out_value[0:0];
    assign crossing_bit = is_opcode$2 ? signal_select_560 : signal_select_561;
    assign signal_select_562 = crc_0[15:15];
    assign signal_select_563 = crc_0[14:14];
    assign signal_select_564 = crc_0[13:13];
    assign signal_select_565 = crc_0[12:12];
    assign signal_select_566 = crc_0[11:11];
    assign signal_select_567 = crc_0[10:10];
    assign signal_select_568 = crc_0[9:9];
    assign signal_select_569 = crc_0[8:8];
    assign signal_select_570 = crc_0[7:7];
    assign signal_select_571 = crc_0[6:6];
    assign signal_select_572 = crc_0[5:5];
    assign signal_select_573 = crc_0[4:4];
    assign signal_select_574 = crc_0[3:3];
    assign signal_select_575 = crc_0[2:2];
    assign signal_select_576 = crc_0[1:1];
    assign signal_select_577 = crc_0[0:0];
    assign signal_wire_26 = config$crc_width;
    assign signal_sub_6 = signal_wire_26 - signal_const_67;
    always @* begin
        case (signal_sub_6)
        0:
            signal_mux_177 <= signal_select_577;
        1:
            signal_mux_177 <= signal_select_576;
        2:
            signal_mux_177 <= signal_select_575;
        3:
            signal_mux_177 <= signal_select_574;
        4:
            signal_mux_177 <= signal_select_573;
        5:
            signal_mux_177 <= signal_select_572;
        6:
            signal_mux_177 <= signal_select_571;
        7:
            signal_mux_177 <= signal_select_570;
        8:
            signal_mux_177 <= signal_select_569;
        9:
            signal_mux_177 <= signal_select_568;
        10:
            signal_mux_177 <= signal_select_567;
        11:
            signal_mux_177 <= signal_select_566;
        12:
            signal_mux_177 <= signal_select_565;
        13:
            signal_mux_177 <= signal_select_564;
        14:
            signal_mux_177 <= signal_select_563;
        default:
            signal_mux_177 <= signal_select_562;
        endcase
    end
    assign signal_xor_5 = signal_mux_177 ^ crossing_bit;
    assign signal_mux_178 = signal_xor_5 ? signal_xor_4 : signal_cat_130;
    assign signal_wire_27 = config$crc_reflect;
    assign signal_mux_179 = signal_wire_27 ? signal_mux_176 : signal_mux_178;
    assign crc_stepped = signal_mux_179 & signal_not_36;
    assign signal_const_180 = 3'b010;
    assign signal_eq_40 = signal_select_761 == signal_const_180;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            is_opcode$2 <= gnd;
        else
            if (ir_load)
                is_opcode$2 <= signal_eq_40;
    end
    assign signal_or_9 = is_opcode$2 | is_opcode$3;
    assign signal_eq_41 = d$shift_count == signal_const_67;
    assign bit_crosses = signal_eq_41 & signal_or_9;
    assign signal_mux_180 = bit_crosses ? crc_stepped : crc_0;
    assign signal_const_182 = 4'b0101;
    assign signal_eq_42 = d$sys_op$binary_variant == signal_const_182;
    assign signal_and_56 = is_opcode$7 & signal_eq_42;
    assign crc_next = signal_and_56 ? signal_wire_24 : signal_mux_180;
    assign signal_mux_181 = go ? crc_next : crc_0;
    assign signal_mux_182 = start_0 ? signal_wire_24 : signal_mux_181;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_16 <= signal_const_14;
        else
            signal_reg_16 <= signal_mux_182;
    end
    assign crc_0 = signal_reg_16;
    assign signal_select_578 = signal_mux_185[7:0];
    assign signal_cat_131 = { signal_select_578,
                              signal_const_15 };
    assign signal_select_579 = signal_mux_184[11:0];
    assign signal_cat_132 = { signal_select_579,
                              signal_const_16 };
    assign signal_select_580 = signal_mux_183[13:0];
    assign signal_cat_133 = { signal_select_580,
                              signal_const_17 };
    assign signal_select_581 = d$shift_count[0:0];
    assign signal_mux_183 = signal_select_581 ? signal_const_18 : signal_const_19;
    assign signal_select_582 = d$shift_count[1:1];
    assign signal_mux_184 = signal_select_582 ? signal_cat_133 : signal_mux_183;
    assign signal_select_583 = d$shift_count[2:2];
    assign signal_mux_185 = signal_select_583 ? signal_cat_132 : signal_mux_184;
    assign signal_select_584 = d$shift_count[3:3];
    assign signal_mux_186 = signal_select_584 ? signal_cat_131 : signal_mux_185;
    assign signal_select_585 = d$shift_count[4:4];
    assign signal_mux_187 = signal_select_585 ? signal_const_14 : signal_mux_186;
    assign signal_not_37 = ~ signal_mux_187;
    assign signal_select_586 = signal_mux_191[27:16];
    assign signal_select_587 = signal_mux_191[15:0];
    assign signal_cat_134 = { signal_select_587,
                              signal_select_586 };
    assign signal_select_588 = signal_mux_190[27:8];
    assign signal_select_589 = signal_mux_190[7:0];
    assign signal_cat_135 = { signal_select_589,
                              signal_select_588 };
    assign signal_select_590 = signal_mux_189[27:4];
    assign signal_select_591 = signal_mux_189[3:0];
    assign signal_cat_136 = { signal_select_591,
                              signal_select_590 };
    assign signal_select_592 = signal_mux_188[27:2];
    assign signal_select_593 = signal_mux_188[1:0];
    assign signal_cat_137 = { signal_select_593,
                              signal_select_592 };
    assign signal_select_594 = sample[27:1];
    assign signal_select_595 = sample[0:0];
    assign signal_cat_138 = { signal_select_595,
                              signal_select_594 };
    assign signal_select_596 = signal_wire_32[0:0];
    assign signal_mux_188 = signal_select_596 ? signal_cat_138 : sample;
    assign signal_select_597 = signal_wire_32[1:1];
    assign signal_mux_189 = signal_select_597 ? signal_cat_137 : signal_mux_188;
    assign signal_select_598 = signal_wire_32[2:2];
    assign signal_mux_190 = signal_select_598 ? signal_cat_136 : signal_mux_189;
    assign signal_select_599 = signal_wire_32[3:3];
    assign signal_mux_191 = signal_select_599 ? signal_cat_135 : signal_mux_190;
    assign signal_select_600 = signal_wire_32[4:4];
    assign signal_mux_192 = signal_select_600 ? signal_cat_134 : signal_mux_191;
    assign signal_select_601 = signal_mux_192[15:0];
    assign signal_and_57 = signal_select_601 & signal_not_37;
    always @* begin
        case (d$out_dest$binary_variant)
        0:
            signal_mux_193 <= signal_and_57;
        1:
            signal_mux_193 <= x_0;
        2:
            signal_mux_193 <= y_0;
        3:
            signal_mux_193 <= signal_const_14;
        4:
            signal_mux_193 <= isr_0;
        5:
            signal_mux_193 <= osr_0;
        6:
            signal_mux_193 <= crc_0;
        default:
            signal_mux_193 <= signal_select_548;
        endcase
    end
    assign in_value = signal_mux_193 & mask;
    assign signal_select_602 = signal_mux_196[7:0];
    assign signal_cat_139 = { signal_select_602,
                              signal_const_15 };
    assign signal_select_603 = signal_mux_195[11:0];
    assign signal_cat_140 = { signal_select_603,
                              signal_const_16 };
    assign signal_select_604 = signal_mux_194[13:0];
    assign signal_cat_141 = { signal_select_604,
                              signal_const_17 };
    assign signal_select_605 = isr_0[14:0];
    assign signal_cat_142 = { signal_select_605,
                              signal_const_3 };
    assign signal_select_606 = d$shift_count[0:0];
    assign signal_mux_194 = signal_select_606 ? signal_cat_142 : isr_0;
    assign signal_select_607 = d$shift_count[1:1];
    assign signal_mux_195 = signal_select_607 ? signal_cat_141 : signal_mux_194;
    assign signal_select_608 = d$shift_count[2:2];
    assign signal_mux_196 = signal_select_608 ? signal_cat_140 : signal_mux_195;
    assign signal_select_609 = d$shift_count[3:3];
    assign signal_mux_197 = signal_select_609 ? signal_cat_139 : signal_mux_196;
    assign signal_select_610 = d$shift_count[4:4];
    assign signal_mux_198 = signal_select_610 ? signal_const_14 : signal_mux_197;
    assign signal_or_10 = signal_mux_198 | in_value;
    assign signal_wire_28 = config$in_shift_right;
    assign isr_shifted = signal_wire_28 ? signal_or_8 : signal_or_10;
    assign signal_wire_29 = config$push_threshold;
    assign signal_const_195 = 5'b10000;
    assign signal_select_611 = signal_add_7[4:0];
    assign signal_cat_143 = { gnd,
                              d$shift_count };
    assign signal_eq_43 = d$sys_op$binary_variant == signal_const_85;
    assign signal_and_58 = is_opcode$7 & signal_eq_43;
    assign signal_mux_199 = signal_and_58 ? osr_count_zero : isr_count_0;
    assign signal_eq_44 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_200 = signal_eq_44 ? osr_count_zero : isr_count_0;
    assign signal_eq_45 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_201 = signal_eq_45 ? d$shift_count : isr_count_0;
    assign signal_mux_202 = autopush_now ? osr_count_zero : isr_count_next;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_count_next_value <= isr_count_0;
        1:
            isr_count_next_value <= isr_count_0;
        2:
            isr_count_next_value <= signal_mux_202;
        3:
            isr_count_next_value <= signal_mux_201;
        4:
            isr_count_next_value <= signal_mux_200;
        5:
            isr_count_next_value <= isr_count_0;
        6:
            isr_count_next_value <= isr_count_0;
        default:
            isr_count_next_value <= signal_mux_199;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_17 <= signal_const_64;
        else
            if (go)
                signal_reg_17 <= isr_count_next_value;
    end
    assign isr_count_0 = signal_reg_17;
    assign signal_cat_144 = { gnd,
                              isr_count_0 };
    assign signal_add_7 = signal_cat_144 + signal_cat_143;
    assign signal_const_200 = 6'b010000;
    assign signal_lt_2 = signal_const_200 < signal_add_7;
    assign isr_count_next = signal_lt_2 ? signal_const_195 : signal_select_611;
    assign signal_lt_3 = isr_count_next < signal_wire_29;
    assign signal_not_38 = ~ signal_lt_3;
    assign signal_wire_30 = config$autopush;
    assign autopush_now = signal_wire_30 & signal_not_38;
    assign signal_mux_203 = autopush_now ? signal_const_14 : isr_shifted;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_next <= isr_0;
        1:
            isr_next <= isr_0;
        2:
            isr_next <= signal_mux_203;
        3:
            isr_next <= signal_mux_149;
        4:
            isr_next <= signal_mux_148;
        5:
            isr_next <= isr_0;
        6:
            isr_next <= isr_0;
        default:
            isr_next <= signal_mux_147;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_18 <= signal_const_14;
        else
            if (go)
                signal_reg_18 <= isr_next;
    end
    assign isr_0 = signal_reg_18;
    assign signal_xor_6 = p_0 ^ alu_operand;
    assign signal_sub_7 = p_0 - alu_operand;
    assign signal_add_8 = p_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_204 <= signal_add_8;
        1:
            signal_mux_204 <= signal_sub_7;
        default:
            signal_mux_204 <= signal_xor_6;
        endcase
    end
    assign signal_eq_46 = d$alu_dest$binary_variant == signal_const_101;
    assign signal_mux_205 = signal_eq_46 ? signal_mux_204 : p_0;
    assign signal_cat_145 = { signal_const_11,
                              d$set_value };
    assign signal_eq_47 = d$set_dest$binary_variant == signal_const;
    assign signal_mux_206 = signal_eq_47 ? signal_cat_145 : p_0;
    assign signal_eq_48 = d$mov_dest$binary_variant == signal_const_2;
    assign signal_mux_207 = signal_eq_48 ? mov_value : p_0;
    assign signal_eq_49 = d$out_dest$binary_variant == signal_const_2;
    assign signal_mux_208 = signal_eq_49 ? out_value : p_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            p_next <= p_0;
        1:
            p_next <= p_0;
        2:
            p_next <= p_0;
        3:
            p_next <= signal_mux_208;
        4:
            p_next <= signal_mux_207;
        5:
            p_next <= signal_mux_206;
        6:
            p_next <= signal_mux_205;
        default:
            p_next <= p_0;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_19 <= signal_const_14;
        else
            if (go)
                signal_reg_19 <= p_next;
    end
    assign p_0 = signal_reg_19;
    assign signal_xor_7 = y_0 ^ alu_operand;
    assign signal_sub_8 = y_0 - alu_operand;
    assign signal_add_9 = y_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_209 <= signal_add_9;
        1:
            signal_mux_209 <= signal_sub_8;
        default:
            signal_mux_209 <= signal_xor_7;
        endcase
    end
    assign signal_const_208 = 2'b01;
    assign signal_eq_50 = d$alu_dest$binary_variant == signal_const_208;
    assign signal_mux_210 = signal_eq_50 ? signal_mux_209 : y_0;
    assign signal_cat_146 = { signal_const_11,
                              d$set_value };
    assign signal_eq_51 = d$set_dest$binary_variant == signal_const_180;
    assign signal_mux_211 = signal_eq_51 ? signal_cat_146 : y_0;
    assign signal_eq_52 = d$mov_dest$binary_variant == signal_const_180;
    assign signal_mux_212 = signal_eq_52 ? mov_value : y_0;
    assign signal_eq_53 = d$out_dest$binary_variant == signal_const_180;
    assign signal_mux_213 = signal_eq_53 ? out_value : y_0;
    assign signal_const_213 = 16'b0000000000000001;
    assign signal_sub_9 = y_0 - signal_const_213;
    assign signal_eq_54 = d$jmp_cond$binary_variant == signal_const_9;
    assign signal_mux_214 = signal_eq_54 ? signal_sub_9 : y_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            y_next <= signal_mux_214;
        1:
            y_next <= y_0;
        2:
            y_next <= y_0;
        3:
            y_next <= signal_mux_213;
        4:
            y_next <= signal_mux_212;
        5:
            y_next <= signal_mux_211;
        6:
            y_next <= signal_mux_210;
        default:
            y_next <= y_0;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_20 <= signal_const_14;
        else
            if (go)
                signal_reg_20 <= y_next;
    end
    assign y_0 = signal_reg_20;
    always @* begin
        case (d$alu_reg$binary_variant)
        0:
            signal_mux_215 <= x_0;
        1:
            signal_mux_215 <= y_0;
        2:
            signal_mux_215 <= p_0;
        3:
            signal_mux_215 <= isr_0;
        default:
            signal_mux_215 <= osr_0;
        endcase
    end
    assign d$alu_reg$binary_variant = word[2:0];
    assign signal_const_215 = 13'b0000000000000;
    assign signal_cat_147 = { signal_const_215,
                              d$alu_reg$binary_variant };
    assign d$alu_is_reg = word[3:3];
    assign alu_operand = d$alu_is_reg ? signal_mux_215 : signal_cat_147;
    assign signal_add_10 = x_0 + alu_operand;
    assign d$alu_op$binary_variant = word[5:4];
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_216 <= signal_add_10;
        1:
            signal_mux_216 <= signal_sub_5;
        default:
            signal_mux_216 <= signal_xor_1;
        endcase
    end
    assign d$alu_dest$binary_variant = word[7:6];
    assign signal_eq_55 = d$alu_dest$binary_variant == signal_const_17;
    assign signal_mux_217 = signal_eq_55 ? signal_mux_216 : x_0;
    assign d$set_value = word[4:0];
    assign signal_cat_148 = { signal_const_11,
                              d$set_value };
    assign signal_const_218 = 3'b001;
    assign d$set_dest$binary_variant = word[7:5];
    assign signal_eq_56 = d$set_dest$binary_variant == signal_const_218;
    assign signal_mux_218 = signal_eq_56 ? signal_cat_148 : x_0;
    assign signal_eq_57 = d$mov_dest$binary_variant == signal_const_218;
    assign signal_mux_219 = signal_eq_57 ? mov_value : x_0;
    assign signal_eq_58 = d$out_dest$binary_variant == signal_const_218;
    assign signal_mux_220 = signal_eq_58 ? out_value : x_0;
    assign signal_sub_10 = x_0 - signal_const_213;
    assign d$jmp_cond$binary_variant = word[12:9];
    assign signal_eq_59 = d$jmp_cond$binary_variant == signal_const_58;
    assign signal_mux_221 = signal_eq_59 ? signal_sub_10 : x_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            x_next <= signal_mux_221;
        1:
            x_next <= x_0;
        2:
            x_next <= x_0;
        3:
            x_next <= signal_mux_220;
        4:
            x_next <= signal_mux_219;
        5:
            x_next <= signal_mux_218;
        6:
            x_next <= signal_mux_217;
        default:
            x_next <= x_0;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_21 <= signal_const_14;
        else
            if (go)
                signal_reg_21 <= x_next;
    end
    assign x_0 = signal_reg_21;
    assign signal_cat_149 = { signal_const_15,
                              x_0 };
    assign signal_select_612 = signal_mux_224[7:0];
    assign signal_cat_150 = { signal_select_612,
                              signal_const_15 };
    assign signal_select_613 = signal_mux_223[11:0];
    assign signal_cat_151 = { signal_select_613,
                              signal_const_16 };
    assign signal_select_614 = signal_mux_222[13:0];
    assign signal_cat_152 = { signal_select_614,
                              signal_const_17 };
    assign signal_select_615 = signal_wire_31[0:0];
    assign signal_mux_222 = signal_select_615 ? signal_const_18 : signal_const_19;
    assign signal_select_616 = signal_wire_31[1:1];
    assign signal_mux_223 = signal_select_616 ? signal_cat_152 : signal_mux_222;
    assign signal_select_617 = signal_wire_31[2:2];
    assign signal_mux_224 = signal_select_617 ? signal_cat_151 : signal_mux_223;
    assign signal_select_618 = signal_wire_31[3:3];
    assign signal_mux_225 = signal_select_618 ? signal_cat_150 : signal_mux_224;
    assign signal_wire_31 = config$in_count;
    assign signal_select_619 = signal_wire_31[4:4];
    assign signal_mux_226 = signal_select_619 ? signal_const_14 : signal_mux_225;
    assign signal_not_39 = ~ signal_mux_226;
    assign signal_select_620 = signal_mux_230[27:16];
    assign signal_select_621 = signal_mux_230[15:0];
    assign signal_cat_153 = { signal_select_621,
                              signal_select_620 };
    assign signal_select_622 = signal_mux_229[27:8];
    assign signal_select_623 = signal_mux_229[7:0];
    assign signal_cat_154 = { signal_select_623,
                              signal_select_622 };
    assign signal_select_624 = signal_mux_228[27:4];
    assign signal_select_625 = signal_mux_228[3:0];
    assign signal_cat_155 = { signal_select_625,
                              signal_select_624 };
    assign signal_select_626 = signal_mux_227[27:2];
    assign signal_select_627 = signal_mux_227[1:0];
    assign signal_cat_156 = { signal_select_627,
                              signal_select_626 };
    assign signal_select_628 = sample[27:1];
    assign signal_select_629 = sample[0:0];
    assign signal_cat_157 = { signal_select_629,
                              signal_select_628 };
    assign signal_select_630 = signal_wire_32[0:0];
    assign signal_mux_227 = signal_select_630 ? signal_cat_157 : sample;
    assign signal_select_631 = signal_wire_32[1:1];
    assign signal_mux_228 = signal_select_631 ? signal_cat_156 : signal_mux_227;
    assign signal_select_632 = signal_wire_32[2:2];
    assign signal_mux_229 = signal_select_632 ? signal_cat_155 : signal_mux_228;
    assign signal_select_633 = signal_wire_32[3:3];
    assign signal_mux_230 = signal_select_633 ? signal_cat_154 : signal_mux_229;
    assign signal_wire_32 = config$in_base;
    assign signal_select_634 = signal_wire_32[4:4];
    assign signal_mux_231 = signal_select_634 ? signal_cat_153 : signal_mux_230;
    assign signal_select_635 = signal_mux_231[15:0];
    assign signal_and_59 = signal_select_635 & signal_not_39;
    assign signal_cat_158 = { signal_const_15,
                              signal_and_59 };
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
    assign signal_select_636 = mov_value24[15:0];
    assign d$mov_op$binary_variant = word[4:3];
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value <= signal_select_636;
        1:
            mov_value <= signal_not_34;
        default:
            mov_value <= signal_cat_111;
        endcase
    end
    assign signal_eq_60 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_232 = signal_eq_60 ? mov_value : osr_0;
    assign signal_select_637 = signal_mux_235[15:8];
    assign signal_cat_159 = { signal_const_15,
                              signal_select_637 };
    assign signal_select_638 = signal_mux_234[15:4];
    assign signal_cat_160 = { signal_const_16,
                              signal_select_638 };
    assign signal_select_639 = signal_mux_233[15:2];
    assign signal_cat_161 = { signal_const_17,
                              signal_select_639 };
    assign signal_select_640 = osr_before[15:1];
    assign signal_cat_162 = { signal_const_3,
                              signal_select_640 };
    assign signal_select_641 = d$shift_count[0:0];
    assign signal_mux_233 = signal_select_641 ? signal_cat_162 : osr_before;
    assign signal_select_642 = d$shift_count[1:1];
    assign signal_mux_234 = signal_select_642 ? signal_cat_161 : signal_mux_233;
    assign signal_select_643 = d$shift_count[2:2];
    assign signal_mux_235 = signal_select_643 ? signal_cat_160 : signal_mux_234;
    assign signal_select_644 = d$shift_count[3:3];
    assign signal_mux_236 = signal_select_644 ? signal_cat_159 : signal_mux_235;
    assign signal_select_645 = d$shift_count[4:4];
    assign signal_mux_237 = signal_select_645 ? signal_const_14 : signal_mux_236;
    assign signal_select_646 = signal_mux_240[7:0];
    assign signal_cat_163 = { signal_select_646,
                              signal_const_15 };
    assign signal_select_647 = signal_mux_239[11:0];
    assign signal_cat_164 = { signal_select_647,
                              signal_const_16 };
    assign signal_select_648 = signal_mux_238[13:0];
    assign signal_cat_165 = { signal_select_648,
                              signal_const_17 };
    assign signal_select_649 = osr_before[14:0];
    assign signal_cat_166 = { signal_select_649,
                              signal_const_3 };
    assign signal_select_650 = d$shift_count[0:0];
    assign signal_mux_238 = signal_select_650 ? signal_cat_166 : osr_before;
    assign signal_select_651 = d$shift_count[1:1];
    assign signal_mux_239 = signal_select_651 ? signal_cat_165 : signal_mux_238;
    assign signal_select_652 = d$shift_count[2:2];
    assign signal_mux_240 = signal_select_652 ? signal_cat_164 : signal_mux_239;
    assign signal_select_653 = d$shift_count[3:3];
    assign signal_mux_241 = signal_select_653 ? signal_cat_163 : signal_mux_240;
    assign signal_select_654 = d$shift_count[4:4];
    assign signal_mux_242 = signal_select_654 ? signal_const_14 : signal_mux_241;
    assign osr_shifted = signal_wire_39 ? signal_mux_237 : signal_mux_242;
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
            osr_next <= signal_mux_232;
        5:
            osr_next <= osr_0;
        6:
            osr_next <= osr_0;
        default:
            osr_next <= signal_mux_146;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_22 <= signal_const_14;
        else
            if (go)
                signal_reg_22 <= osr_next;
    end
    assign osr_0 = signal_reg_22;
    assign signal_wire_33 = flush;
    assign flush_0 = signal_wire_33 & halted_0;
    assign signal_not_40 = ~ signal_select_655;
    assign signal_and_60 = pulls & signal_not_40;
    assign signal_eq_61 = signal_select_761 == signal_const_114;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            is_opcode$3 <= gnd;
        else
            if (ir_load)
                is_opcode$3 <= signal_eq_61;
    end
    assign signal_and_61 = is_opcode$3 & pull_ok;
    assign signal_or_11 = signal_and_61 | signal_and_60;
    assign signal_and_62 = op_go & signal_or_11;
    assign tx_pop = signal_and_62;
    assign signal_wire_34 = tx$value;
    assign signal_wire_35 = tx$valid;
    host_fifo
        tx
        ( .clock(signal_wire_51),
          .clear(signal_wire_48),
          .push$valid(signal_wire_35),
          .push$value(signal_wire_34),
          .pop(tx_pop),
          .flush(flush_0),
          .head(signal_inst_2[15:0]),
          .level(signal_inst_2[19:16]),
          .empty(signal_inst_2[20:20]),
          .full(signal_inst_2[21:21]) );
    assign signal_select_655 = signal_inst_2[20:20];
    assign signal_not_41 = ~ signal_select_655;
    assign signal_not_42 = ~ signal_wire_36;
    assign pull_fifo = pull_now & signal_not_42;
    assign pull_ok = pull_fifo & signal_not_41;
    assign signal_mux_243 = pull_ok ? signal_select_421 : osr_0;
    assign signal_wire_36 = config$autopull_data;
    assign signal_wire_37 = config$pull_threshold;
    assign signal_const_244 = 4'b0100;
    assign d$sys_op$binary_variant = word[3:0];
    assign signal_eq_62 = d$sys_op$binary_variant == signal_const_244;
    assign signal_eq_63 = signal_select_761 == signal_const_89;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            is_opcode$7 <= gnd;
        else
            if (ir_load)
                is_opcode$7 <= signal_eq_63;
    end
    assign pulls = is_opcode$7 & signal_eq_62;
    assign signal_mux_244 = pulls ? osr_count_zero : osr_count_0;
    assign osr_count_zero = 5'b00000;
    assign d$mov_dest$binary_variant = word[7:5];
    assign signal_eq_64 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_245 = signal_eq_64 ? osr_count_zero : osr_count_0;
    assign signal_select_656 = signal_add_11[4:0];
    assign signal_cat_167 = { gnd,
                              d$shift_count };
    assign osr_count_before = pull_now ? signal_const_64 : osr_count_0;
    assign signal_cat_168 = { gnd,
                              osr_count_before };
    assign signal_add_11 = signal_cat_168 + signal_cat_167;
    assign signal_lt_4 = signal_const_200 < signal_add_11;
    assign osr_count_next = signal_lt_4 ? signal_const_195 : signal_select_656;
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
            osr_count_next_value <= signal_mux_245;
        5:
            osr_count_next_value <= osr_count_0;
        6:
            osr_count_next_value <= osr_count_0;
        default:
            osr_count_next_value <= signal_mux_244;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_23 <= signal_const_195;
        else
            if (go)
                signal_reg_23 <= osr_count_next_value;
    end
    assign osr_count_0 = signal_reg_23;
    assign signal_lt_5 = osr_count_0 < signal_wire_37;
    assign signal_not_43 = ~ signal_lt_5;
    assign signal_wire_38 = config$autopull;
    assign pull_now = signal_wire_38 & signal_not_43;
    assign pull_data = pull_now & signal_wire_36;
    assign osr_before = pull_data ? signal_wire_21 : signal_mux_243;
    assign signal_select_657 = shift_back[0:0];
    assign signal_mux_246 = signal_select_657 ? signal_cat_110 : osr_before;
    assign signal_select_658 = shift_back[1:1];
    assign signal_mux_247 = signal_select_658 ? signal_cat_109 : signal_mux_246;
    assign signal_select_659 = shift_back[2:2];
    assign signal_mux_248 = signal_select_659 ? signal_cat_108 : signal_mux_247;
    assign signal_select_660 = shift_back[3:3];
    assign signal_mux_249 = signal_select_660 ? signal_cat_107 : signal_mux_248;
    assign shift_back = signal_const_195 - d$shift_count;
    assign signal_select_661 = shift_back[4:4];
    assign signal_mux_250 = signal_select_661 ? signal_const_14 : signal_mux_249;
    assign signal_and_63 = signal_mux_250 & mask;
    assign signal_wire_39 = config$out_shift_right;
    assign out_value = signal_wire_39 ? signal_and_46 : signal_and_63;
    assign signal_cat_169 = { signal_const_12,
                              out_value };
    assign signal_select_662 = signal_wire_40[0:0];
    assign signal_mux_251 = signal_select_662 ? signal_cat_106 : signal_cat_169;
    assign signal_select_663 = signal_wire_40[1:1];
    assign signal_mux_252 = signal_select_663 ? signal_cat_105 : signal_mux_251;
    assign signal_select_664 = signal_wire_40[2:2];
    assign signal_mux_253 = signal_select_664 ? signal_cat_104 : signal_mux_252;
    assign signal_select_665 = signal_wire_40[3:3];
    assign signal_mux_254 = signal_select_665 ? signal_cat_103 : signal_mux_253;
    assign signal_select_666 = signal_wire_40[4:4];
    assign signal_mux_255 = signal_select_666 ? signal_cat_102 : signal_mux_254;
    assign signal_and_64 = signal_mux_255 & signal_and_65;
    assign signal_select_667 = signal_mux_264[27:12];
    assign signal_select_668 = signal_mux_264[11:0];
    assign signal_cat_170 = { signal_select_668,
                              signal_select_667 };
    assign signal_select_669 = signal_mux_263[27:20];
    assign signal_select_670 = signal_mux_263[19:0];
    assign signal_cat_171 = { signal_select_670,
                              signal_select_669 };
    assign signal_select_671 = signal_mux_262[27:24];
    assign signal_select_672 = signal_mux_262[23:0];
    assign signal_cat_172 = { signal_select_672,
                              signal_select_671 };
    assign signal_select_673 = signal_mux_261[27:26];
    assign signal_select_674 = signal_mux_261[25:0];
    assign signal_cat_173 = { signal_select_674,
                              signal_select_673 };
    assign signal_select_675 = signal_cat_178[27:27];
    assign signal_select_676 = signal_cat_178[26:0];
    assign signal_cat_174 = { signal_select_676,
                              signal_select_675 };
    assign signal_select_677 = signal_mux_258[7:0];
    assign signal_cat_175 = { signal_select_677,
                              signal_const_15 };
    assign signal_select_678 = signal_mux_257[11:0];
    assign signal_cat_176 = { signal_select_678,
                              signal_const_16 };
    assign signal_select_679 = signal_mux_256[13:0];
    assign signal_cat_177 = { signal_select_679,
                              signal_const_17 };
    assign signal_select_680 = d$shift_count[0:0];
    assign signal_mux_256 = signal_select_680 ? signal_const_18 : signal_const_19;
    assign signal_select_681 = d$shift_count[1:1];
    assign signal_mux_257 = signal_select_681 ? signal_cat_177 : signal_mux_256;
    assign signal_select_682 = d$shift_count[2:2];
    assign signal_mux_258 = signal_select_682 ? signal_cat_176 : signal_mux_257;
    assign signal_select_683 = d$shift_count[3:3];
    assign signal_mux_259 = signal_select_683 ? signal_cat_175 : signal_mux_258;
    assign d$shift_count = word[4:0];
    assign signal_select_684 = d$shift_count[4:4];
    assign signal_mux_260 = signal_select_684 ? signal_const_14 : signal_mux_259;
    assign signal_not_44 = ~ signal_mux_260;
    assign signal_cat_178 = { signal_const_12,
                              signal_not_44 };
    assign signal_select_685 = signal_wire_40[0:0];
    assign signal_mux_261 = signal_select_685 ? signal_cat_174 : signal_cat_178;
    assign signal_select_686 = signal_wire_40[1:1];
    assign signal_mux_262 = signal_select_686 ? signal_cat_173 : signal_mux_261;
    assign signal_select_687 = signal_wire_40[2:2];
    assign signal_mux_263 = signal_select_687 ? signal_cat_172 : signal_mux_262;
    assign signal_select_688 = signal_wire_40[3:3];
    assign signal_mux_264 = signal_select_688 ? signal_cat_171 : signal_mux_263;
    assign signal_wire_40 = config$out_base;
    assign signal_select_689 = signal_wire_40[4:4];
    assign signal_mux_265 = signal_select_689 ? signal_cat_170 : signal_mux_264;
    assign signal_and_65 = signal_mux_265 & signal_const_105;
    assign signal_not_45 = ~ signal_and_65;
    assign signal_and_66 = pin_dir_base & signal_not_45;
    assign signal_or_12 = signal_and_66 | signal_and_64;
    assign d$out_dest$binary_variant = word[7:5];
    assign signal_eq_65 = d$out_dest$binary_variant == signal_const;
    assign signal_mux_266 = signal_eq_65 ? signal_or_12 : pin_dir_base;
    assign signal_select_690 = signal_mux_270[27:12];
    assign signal_select_691 = signal_mux_270[11:0];
    assign signal_cat_179 = { signal_select_691,
                              signal_select_690 };
    assign signal_select_692 = signal_mux_269[27:20];
    assign signal_select_693 = signal_mux_269[19:0];
    assign signal_cat_180 = { signal_select_693,
                              signal_select_692 };
    assign signal_select_694 = signal_mux_268[27:24];
    assign signal_select_695 = signal_mux_268[23:0];
    assign signal_cat_181 = { signal_select_695,
                              signal_select_694 };
    assign signal_select_696 = signal_mux_267[27:26];
    assign signal_select_697 = signal_mux_267[25:0];
    assign signal_cat_182 = { signal_select_697,
                              signal_select_696 };
    assign signal_select_698 = signal_cat_186[27:27];
    assign signal_select_699 = signal_cat_186[26:0];
    assign signal_cat_183 = { signal_select_699,
                              signal_select_698 };
    assign signal_select_700 = signal_select_702[4:3];
    assign signal_select_701 = signal_select_702[4:3];
    assign signal_select_702 = word[12:8];
    assign signal_select_703 = signal_select_702[4:4];
    assign signal_cat_184 = { gnd,
                              signal_select_703 };
    always @* begin
        case (signal_wire_41)
        0:
            d$side_set <= signal_const_17;
        1:
            d$side_set <= signal_cat_184;
        2:
            d$side_set <= signal_select_701;
        default:
            d$side_set <= signal_select_700;
        endcase
    end
    assign signal_cat_185 = { signal_const_42,
                              d$side_set };
    assign signal_cat_186 = { signal_const_12,
                              signal_cat_185 };
    assign signal_select_704 = signal_wire_42[0:0];
    assign signal_mux_267 = signal_select_704 ? signal_cat_183 : signal_cat_186;
    assign signal_select_705 = signal_wire_42[1:1];
    assign signal_mux_268 = signal_select_705 ? signal_cat_182 : signal_mux_267;
    assign signal_select_706 = signal_wire_42[2:2];
    assign signal_mux_269 = signal_select_706 ? signal_cat_181 : signal_mux_268;
    assign signal_select_707 = signal_wire_42[3:3];
    assign signal_mux_270 = signal_select_707 ? signal_cat_180 : signal_mux_269;
    assign signal_select_708 = signal_wire_42[4:4];
    assign signal_mux_271 = signal_select_708 ? signal_cat_179 : signal_mux_270;
    assign signal_and_67 = signal_mux_271 & signal_and_68;
    assign signal_select_709 = signal_mux_280[27:12];
    assign signal_select_710 = signal_mux_280[11:0];
    assign signal_cat_187 = { signal_select_710,
                              signal_select_709 };
    assign signal_select_711 = signal_mux_279[27:20];
    assign signal_select_712 = signal_mux_279[19:0];
    assign signal_cat_188 = { signal_select_712,
                              signal_select_711 };
    assign signal_select_713 = signal_mux_278[27:24];
    assign signal_select_714 = signal_mux_278[23:0];
    assign signal_cat_189 = { signal_select_714,
                              signal_select_713 };
    assign signal_select_715 = signal_mux_277[27:26];
    assign signal_select_716 = signal_mux_277[25:0];
    assign signal_cat_190 = { signal_select_716,
                              signal_select_715 };
    assign signal_select_717 = signal_cat_196[27:27];
    assign signal_select_718 = signal_cat_196[26:0];
    assign signal_cat_191 = { signal_select_718,
                              signal_select_717 };
    assign signal_select_719 = signal_mux_274[7:0];
    assign signal_cat_192 = { signal_select_719,
                              signal_const_15 };
    assign signal_select_720 = signal_mux_273[11:0];
    assign signal_cat_193 = { signal_select_720,
                              signal_const_16 };
    assign signal_select_721 = signal_mux_272[13:0];
    assign signal_cat_194 = { signal_select_721,
                              signal_const_17 };
    assign signal_select_722 = signal_cat_195[0:0];
    assign signal_mux_272 = signal_select_722 ? signal_const_18 : signal_const_19;
    assign signal_select_723 = signal_cat_195[1:1];
    assign signal_mux_273 = signal_select_723 ? signal_cat_194 : signal_mux_272;
    assign signal_select_724 = signal_cat_195[2:2];
    assign signal_mux_274 = signal_select_724 ? signal_cat_193 : signal_mux_273;
    assign signal_select_725 = signal_cat_195[3:3];
    assign signal_mux_275 = signal_select_725 ? signal_cat_192 : signal_mux_274;
    assign signal_wire_41 = config$side_set_count;
    assign signal_cat_195 = { signal_const_21,
                              signal_wire_41 };
    assign signal_select_726 = signal_cat_195[4:4];
    assign signal_mux_276 = signal_select_726 ? signal_const_14 : signal_mux_275;
    assign signal_not_46 = ~ signal_mux_276;
    assign signal_cat_196 = { signal_const_12,
                              signal_not_46 };
    assign signal_select_727 = signal_wire_42[0:0];
    assign signal_mux_277 = signal_select_727 ? signal_cat_191 : signal_cat_196;
    assign signal_select_728 = signal_wire_42[1:1];
    assign signal_mux_278 = signal_select_728 ? signal_cat_190 : signal_mux_277;
    assign signal_select_729 = signal_wire_42[2:2];
    assign signal_mux_279 = signal_select_729 ? signal_cat_189 : signal_mux_278;
    assign signal_select_730 = signal_wire_42[3:3];
    assign signal_mux_280 = signal_select_730 ? signal_cat_188 : signal_mux_279;
    assign signal_wire_42 = config$side_set_base;
    assign signal_select_731 = signal_wire_42[4:4];
    assign signal_mux_281 = signal_select_731 ? signal_cat_187 : signal_mux_280;
    assign signal_and_68 = signal_mux_281 & signal_const_105;
    assign signal_not_47 = ~ signal_and_68;
    assign signal_and_69 = pin_dir_0 & signal_not_47;
    assign pin_dir_side = signal_and_69 | signal_and_67;
    assign signal_wire_43 = config$side_set_pindirs;
    assign pin_dir_base = signal_wire_43 ? pin_dir_side : pin_dir_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            pin_dir_next <= pin_dir_base;
        1:
            pin_dir_next <= pin_dir_base;
        2:
            pin_dir_next <= pin_dir_base;
        3:
            pin_dir_next <= signal_mux_266;
        4:
            pin_dir_next <= signal_mux_141;
        5:
            pin_dir_next <= signal_mux_125;
        6:
            pin_dir_next <= pin_dir_base;
        default:
            pin_dir_next <= pin_dir_base;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_24 <= signal_const_10;
        else
            if (op_go)
                signal_reg_24 <= pin_dir_next;
    end
    assign pin_dir_0 = signal_reg_24;
    assign signal_select_732 = pin_dir_0[19:19];
    assign signal_mux_282 = signal_select_732 ? signal_select_328 : signal_select_329;
    assign signal_select_733 = signal_wire_44[20:20];
    assign signal_select_734 = pin_out_0[20:20];
    assign signal_or_13 = signal_select_734 | signal_select_733;
    assign signal_select_735 = signal_wire_44[21:21];
    assign signal_select_736 = pin_out_0[21:21];
    assign signal_or_14 = signal_select_736 | signal_select_735;
    assign signal_select_737 = signal_wire_44[22:22];
    assign signal_select_738 = pin_out_0[22:22];
    assign signal_or_15 = signal_select_738 | signal_select_737;
    assign signal_select_739 = signal_wire_44[23:23];
    assign signal_select_740 = pin_out_0[23:23];
    assign signal_or_16 = signal_select_740 | signal_select_739;
    assign signal_select_741 = signal_wire_44[24:24];
    assign signal_select_742 = pin_out_0[24:24];
    assign signal_or_17 = signal_select_742 | signal_select_741;
    assign signal_select_743 = signal_wire_44[25:25];
    assign signal_select_744 = pin_out_0[25:25];
    assign signal_or_18 = signal_select_744 | signal_select_743;
    assign signal_select_745 = signal_wire_44[26:26];
    assign signal_select_746 = pin_out_0[26:26];
    assign signal_or_19 = signal_select_746 | signal_select_745;
    assign signal_wire_44 = inputs;
    assign signal_select_747 = signal_wire_44[27:27];
    assign signal_select_748 = pin_out_0[27:27];
    assign signal_or_20 = signal_select_748 | signal_select_747;
    assign sample = { signal_or_20,
                      signal_or_19,
                      signal_or_18,
                      signal_or_17,
                      signal_or_16,
                      signal_or_15,
                      signal_or_14,
                      signal_or_13,
                      signal_mux_282,
                      signal_mux_109,
                      signal_mux_108,
                      signal_mux_107,
                      signal_mux_106,
                      signal_mux_105,
                      signal_mux_104,
                      signal_mux_103,
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
    assign signal_select_749 = sample[0:0];
    assign d$wait_index = word[4:0];
    always @* begin
        case (d$wait_index)
        0:
            wait_pin_cur <= signal_select_749;
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
    assign signal_eq_66 = wait_pin_cur == d$wait_polarity;
    assign d$wait_source$binary_variant = word[6:5];
    always @* begin
        case (d$wait_source$binary_variant)
        0:
            wait_ready <= signal_eq_66;
        1:
            wait_ready <= signal_and_39;
        2:
            wait_ready <= deadline_ready;
        default:
            wait_ready <= signal_mux_93;
        endcase
    end
    assign signal_not_48 = ~ wait_ready;
    assign gnd = 1'b0;
    assign signal_eq_67 = signal_select_761 == signal_const_218;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            is_opcode$1 <= gnd;
        else
            if (ir_load)
                is_opcode$1 <= signal_eq_67;
    end
    assign wait_holds = is_opcode$1 & signal_not_48;
    assign signal_not_49 = ~ wait_holds;
    assign signal_eq_68 = signal_select_761 == signal_const_21;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            is_opcode$0 <= vdd;
        else
            if (ir_load)
                is_opcode$0 <= signal_eq_68;
    end
    assign signal_not_50 = ~ is_opcode$0;
    assign op_go = go & signal_not_50;
    assign advance = op_go & signal_not_49;
    assign signal_or_21 = advance | refill;
    assign ir_load = signal_or_21;
    assign signal_const_275 = 4'b1001;
    assign signal_select_750 = signal_wire_52[3:0];
    assign signal_lt_6 = signal_select_750 < signal_const_275;
    assign signal_select_751 = signal_wire_52[7:4];
    assign signal_eq_69 = signal_select_751 == signal_const_16;
    assign signal_and_70 = signal_eq_69 & signal_lt_6;
    assign signal_select_752 = signal_wire_52[2:0];
    assign signal_lt_7 = signal_select_752 < signal_const_1;
    assign signal_select_753 = signal_wire_52[3:3];
    assign signal_not_51 = ~ signal_select_753;
    assign signal_or_22 = signal_not_51 | signal_lt_7;
    assign signal_select_754 = signal_wire_52[5:4];
    assign signal_lt_8 = signal_select_754 < signal_const_88;
    assign signal_and_71 = signal_lt_8 & signal_or_22;
    assign signal_select_755 = signal_wire_52[7:5];
    assign signal_lt_9 = signal_select_755 < signal_const_1;
    assign signal_select_756 = signal_wire_52[4:3];
    assign signal_lt_10 = signal_select_756 < signal_const_88;
    assign signal_lt_11 = signal_const_195 < signal_select_757;
    assign signal_not_52 = ~ signal_lt_11;
    assign signal_select_757 = signal_wire_52[4:0];
    assign signal_lt_12 = signal_select_757 < signal_const_67;
    assign signal_not_53 = ~ signal_lt_12;
    assign signal_and_72 = signal_not_53 & signal_not_52;
    assign signal_eq_70 = signal_select_758 == signal_const_64;
    assign signal_eq_71 = signal_select_758 == signal_const_64;
    assign signal_const_285 = 5'b11100;
    assign signal_lt_13 = signal_select_758 < signal_const_285;
    assign signal_select_758 = signal_wire_52[4:0];
    assign signal_lt_14 = signal_select_758 < signal_const_285;
    assign signal_select_759 = signal_wire_52[6:5];
    always @* begin
        case (signal_select_759)
        0:
            signal_mux_283 <= signal_lt_14;
        1:
            signal_mux_283 <= signal_lt_13;
        2:
            signal_mux_283 <= signal_eq_71;
        default:
            signal_mux_283 <= signal_eq_70;
        endcase
    end
    assign signal_const_287 = 4'b1100;
    assign signal_select_760 = signal_wire_52[12:9];
    assign signal_lt_15 = signal_select_760 < signal_const_287;
    assign signal_select_761 = signal_wire_52[15:13];
    always @* begin
        case (signal_select_761)
        0:
            signal_mux_284 <= signal_lt_15;
        1:
            signal_mux_284 <= signal_mux_283;
        2:
            signal_mux_284 <= signal_and_72;
        3:
            signal_mux_284 <= signal_and_72;
        4:
            signal_mux_284 <= signal_lt_10;
        5:
            signal_mux_284 <= signal_lt_9;
        6:
            signal_mux_284 <= signal_and_71;
        default:
            signal_mux_284 <= signal_and_70;
        endcase
    end
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            decode_ok_0 <= vdd;
        else
            if (ir_load)
                decode_ok_0 <= signal_mux_284;
    end
    assign signal_not_54 = ~ breaks;
    assign issue = ready & signal_not_54;
    assign go = issue & decode_ok_0;
    assign jmp_go = go & is_opcode$0;
    assign signal_mux_285 = jmp_go ? signal_const_67 : signal_mux_91;
    assign stall_next = start_0 ? signal_const_64 : signal_mux_285;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_25 <= signal_const_64;
        else
            signal_reg_25 <= stall_next;
    end
    assign stall_0 = signal_reg_25;
    assign signal_eq_72 = stall_0 == signal_const_64;
    assign signal_not_55 = ~ halted_0;
    assign signal_and_73 = signal_not_55 & signal_eq_72;
    assign ready = signal_and_73 & signal_not_22;
    assign signal_and_74 = ready & signal_wire_10;
    assign signal_and_75 = signal_and_74 & at_break;
    assign breaks = signal_and_75 & signal_not_13;
    assign signal_mux_286 = breaks ? vdd : signal_mux_77;
    assign signal_wire_45 = stop;
    assign signal_mux_287 = signal_wire_45 ? vdd : signal_mux_286;
    assign signal_not_56 = ~ resume_0;
    assign signal_wire_46 = single_step;
    assign signal_wire_47 = resume;
    assign signal_or_23 = signal_wire_47 | signal_wire_46;
    assign signal_and_76 = signal_or_23 & halted_0;
    assign resume_asked = signal_and_76 & signal_not_56;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_26 <= signal_const_3;
        else
            signal_reg_26 <= resume_asked;
    end
    assign resume_0 = signal_reg_26;
    assign signal_mux_288 = resume_0 ? gnd : signal_mux_287;
    assign signal_wire_48 = clear;
    assign signal_wire_49 = start;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            start_0 <= signal_const_3;
        else
            start_0 <= signal_wire_49;
    end
    assign halted_next = start_0 ? gnd : signal_mux_288;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_27 <= vdd;
        else
            signal_reg_27 <= halted_next;
    end
    assign halted_0 = signal_reg_27;
    assign signal_wire_50 = program_write$valid;
    assign program_write = signal_wire_50 & halted_0;
    assign vdd = 1'b1;
    assign signal_wire_51 = clock;
    sram_macro
        sram_macro
        ( .clock(signal_wire_51),
          .men(vdd),
          .wen(program_write),
          .ren(vdd),
          .addr(signal_mux_71),
          .din(signal_wire_2),
          .bm(signal_const_19),
          .dout(signal_inst_3[15:0]) );
    assign signal_wire_52 = signal_inst_3;
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            word <= signal_const_14;
        else
            if (ir_load)
                word <= signal_wire_52;
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
    always @(posedge signal_wire_51) begin
        if (signal_wire_48)
            signal_reg_28 <= signal_const_10;
        else
            if (op_go)
                signal_reg_28 <= pin_out_next;
    end
    assign pin_out_0 = signal_reg_28;
    assign d$alu_imm = d$alu_reg$binary_variant;
    assign d$in_source$binary_variant = d$out_dest$binary_variant;
    assign pin_out = pin_out_0;
    assign pin_dir = pin_dir_0;
    assign pc = pc_0;
    assign data_ptr = data_ptr_0;
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
    assign resumed = resumed_0;
    assign stepping = stepping_0;
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
    hosts$config$break_enable_0,
    hosts$config$break_pc_0,
    hosts$config$autopull_data_0,
    hosts$start_0,
    hosts$program_write$valid_0,
    hosts$program_write$addr_0,
    hosts$program_write$data_0,
    hosts$data_write$valid_0,
    hosts$data_write$addr_0,
    hosts$data_write$data_0,
    hosts$tx$valid_0,
    hosts$tx$value_0,
    hosts$rx_pop_0,
    hosts$clear_irq_0,
    hosts$stop_0,
    hosts$flush_0,
    hosts$resume_0,
    hosts$single_step_0,
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
    hosts$config$break_enable_1,
    hosts$config$break_pc_1,
    hosts$config$autopull_data_1,
    hosts$start_1,
    hosts$program_write$valid_1,
    hosts$program_write$addr_1,
    hosts$program_write$data_1,
    hosts$data_write$valid_1,
    hosts$data_write$addr_1,
    hosts$data_write$data_1,
    hosts$tx$valid_1,
    hosts$tx$value_1,
    hosts$rx_pop_1,
    hosts$clear_irq_1,
    hosts$stop_1,
    hosts$flush_1,
    hosts$resume_1,
    hosts$single_step_1,
    pads,
    engines$pin_out_0,
    engines$pin_dir_0,
    engines$pc_0,
    engines$data_ptr_0,
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
    engines$resumed_0,
    engines$stepping_0,
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
    engines$data_ptr_1,
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
    engines$resumed_1,
    engines$stepping_1,
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
    input hosts$config$break_enable_0;
    input [8:0] hosts$config$break_pc_0;
    input hosts$config$autopull_data_0;
    input hosts$start_0;
    input hosts$program_write$valid_0;
    input [8:0] hosts$program_write$addr_0;
    input [15:0] hosts$program_write$data_0;
    input hosts$data_write$valid_0;
    input [8:0] hosts$data_write$addr_0;
    input [15:0] hosts$data_write$data_0;
    input hosts$tx$valid_0;
    input [15:0] hosts$tx$value_0;
    input hosts$rx_pop_0;
    input hosts$clear_irq_0;
    input hosts$stop_0;
    input hosts$flush_0;
    input hosts$resume_0;
    input hosts$single_step_0;
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
    input hosts$config$break_enable_1;
    input [8:0] hosts$config$break_pc_1;
    input hosts$config$autopull_data_1;
    input hosts$start_1;
    input hosts$program_write$valid_1;
    input [8:0] hosts$program_write$addr_1;
    input [15:0] hosts$program_write$data_1;
    input hosts$data_write$valid_1;
    input [8:0] hosts$data_write$addr_1;
    input [15:0] hosts$data_write$data_1;
    input hosts$tx$valid_1;
    input [15:0] hosts$tx$value_1;
    input hosts$rx_pop_1;
    input hosts$clear_irq_1;
    input hosts$stop_1;
    input hosts$flush_1;
    input hosts$resume_1;
    input hosts$single_step_1;
    input [19:0] pads;
    output [27:0] engines$pin_out_0;
    output [27:0] engines$pin_dir_0;
    output [8:0] engines$pc_0;
    output [8:0] engines$data_ptr_0;
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
    output engines$resumed_0;
    output engines$stepping_0;
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
    output [8:0] engines$data_ptr_1;
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
    output engines$resumed_1;
    output engines$stepping_1;
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
    wire signal_select_18;
    wire signal_wire_16;
    wire signal_select_19;
    wire signal_wire_17;
    wire [4:0] signal_select_20;
    wire [4:0] signal_wire_18;
    wire [23:0] signal_select_21;
    wire [23:0] signal_wire_19;
    wire [4:0] signal_select_22;
    wire [4:0] signal_wire_20;
    wire [15:0] signal_select_23;
    wire [15:0] signal_wire_21;
    wire [4:0] signal_select_24;
    wire [4:0] signal_wire_22;
    wire [15:0] signal_select_25;
    wire [15:0] signal_wire_23;
    wire [15:0] signal_select_26;
    wire [15:0] signal_wire_24;
    wire [23:0] signal_select_27;
    wire [23:0] signal_wire_25;
    wire [15:0] signal_select_28;
    wire [15:0] signal_wire_26;
    wire [15:0] signal_select_29;
    wire [15:0] signal_wire_27;
    wire [15:0] signal_select_30;
    wire [15:0] signal_wire_28;
    wire [8:0] signal_select_31;
    wire [8:0] signal_wire_29;
    wire [8:0] signal_select_32;
    wire [8:0] signal_wire_30;
    wire [4:0] signal_select_33;
    wire [4:0] signal_wire_31;
    wire [15:0] signal_select_34;
    wire [15:0] signal_wire_32;
    wire [7:0] signal_select_35;
    wire [7:0] signal_wire_33;
    wire signal_select_36;
    wire signal_wire_34;
    wire [15:0] signal_select_37;
    wire [15:0] signal_wire_35;
    wire [15:0] signal_select_38;
    wire [15:0] signal_wire_36;
    wire [3:0] signal_select_39;
    wire [3:0] signal_wire_37;
    wire [3:0] signal_select_40;
    wire [3:0] signal_wire_38;
    wire signal_select_41;
    wire signal_wire_39;
    wire [23:0] signal_select_42;
    wire [23:0] signal_wire_40;
    wire signal_select_43;
    wire signal_wire_41;
    wire signal_select_44;
    wire signal_wire_42;
    wire signal_select_45;
    wire signal_wire_43;
    wire signal_select_46;
    wire signal_wire_44;
    wire signal_select_47;
    wire signal_wire_45;
    wire signal_select_48;
    wire signal_wire_46;
    wire signal_select_49;
    wire signal_wire_47;
    wire signal_select_50;
    wire signal_wire_48;
    wire [4:0] signal_select_51;
    wire [4:0] signal_wire_49;
    wire [23:0] signal_select_52;
    wire [23:0] signal_wire_50;
    wire [4:0] signal_select_53;
    wire [4:0] signal_wire_51;
    wire [15:0] signal_select_54;
    wire [15:0] signal_wire_52;
    wire [4:0] signal_select_55;
    wire [4:0] signal_wire_53;
    wire [15:0] signal_select_56;
    wire [15:0] signal_wire_54;
    wire [15:0] signal_select_57;
    wire [15:0] signal_wire_55;
    wire [23:0] signal_select_58;
    wire [23:0] signal_wire_56;
    wire [15:0] signal_select_59;
    wire [15:0] signal_wire_57;
    wire [15:0] signal_select_60;
    wire [15:0] signal_wire_58;
    wire [15:0] signal_select_61;
    wire [15:0] signal_wire_59;
    wire [8:0] signal_select_62;
    wire [8:0] signal_wire_60;
    wire [8:0] signal_select_63;
    wire [8:0] signal_wire_61;
    wire [27:0] signal_const_1;
    wire [27:0] signal_or_4;
    wire [27:0] signal_select_64;
    wire [27:0] signal_wire_62;
    wire [27:0] signal_and_2;
    wire [27:0] signal_or_5;
    wire [27:0] signal_and_3;
    wire [27:0] signal_select_65;
    wire [27:0] signal_wire_63;
    wire [27:0] signal_not;
    wire [7:0] signal_const_3;
    wire [27:0] signal_cat;
    wire [27:0] signal_and_4;
    wire [27:0] signal_or_6;
    wire signal_wire_64;
    wire signal_wire_65;
    wire signal_wire_66;
    wire signal_wire_67;
    wire signal_wire_68;
    wire signal_wire_69;
    wire [15:0] signal_wire_70;
    wire signal_wire_71;
    wire [15:0] signal_wire_72;
    wire [8:0] signal_wire_73;
    wire signal_wire_74;
    wire [15:0] signal_wire_75;
    wire [8:0] signal_wire_76;
    wire signal_wire_77;
    wire signal_wire_78;
    wire signal_wire_79;
    wire [8:0] signal_wire_80;
    wire signal_wire_81;
    wire [15:0] signal_wire_82;
    wire [8:0] signal_wire_83;
    wire [8:0] signal_wire_84;
    wire signal_wire_85;
    wire [4:0] signal_wire_86;
    wire signal_wire_87;
    wire [15:0] signal_wire_88;
    wire [15:0] signal_wire_89;
    wire [4:0] signal_wire_90;
    wire [4:0] signal_wire_91;
    wire signal_wire_92;
    wire [4:0] signal_wire_93;
    wire signal_wire_94;
    wire signal_wire_95;
    wire signal_wire_96;
    wire signal_wire_97;
    wire [4:0] signal_wire_98;
    wire [4:0] signal_wire_99;
    wire [2:0] signal_wire_100;
    wire [4:0] signal_wire_101;
    wire [4:0] signal_wire_102;
    wire [4:0] signal_wire_103;
    wire [4:0] signal_wire_104;
    wire [4:0] signal_wire_105;
    wire signal_wire_106;
    wire [4:0] signal_wire_107;
    wire [1:0] signal_wire_108;
    wire [335:0] signal_inst;
    wire [27:0] signal_select_66;
    wire [27:0] signal_wire_109;
    wire [27:0] signal_not_1;
    wire [19:0] signal_wire_110;
    wire [27:0] signal_cat_1;
    wire [27:0] signal_and_5;
    wire [27:0] signal_or_7;
    wire signal_wire_111;
    wire signal_wire_112;
    wire signal_wire_113;
    wire signal_wire_114;
    wire signal_wire_115;
    wire signal_wire_116;
    wire [15:0] signal_wire_117;
    wire signal_wire_118;
    wire [15:0] signal_wire_119;
    wire [8:0] signal_wire_120;
    wire signal_wire_121;
    wire [15:0] signal_wire_122;
    wire [8:0] signal_wire_123;
    wire signal_wire_124;
    wire signal_wire_125;
    wire signal_wire_126;
    wire [8:0] signal_wire_127;
    wire signal_wire_128;
    wire [15:0] signal_wire_129;
    wire [8:0] signal_wire_130;
    wire [8:0] signal_wire_131;
    wire signal_wire_132;
    wire [4:0] signal_wire_133;
    wire signal_wire_134;
    wire [15:0] signal_wire_135;
    wire [15:0] signal_wire_136;
    wire [4:0] signal_wire_137;
    wire [4:0] signal_wire_138;
    wire signal_wire_139;
    wire [4:0] signal_wire_140;
    wire signal_wire_141;
    wire signal_wire_142;
    wire signal_wire_143;
    wire signal_wire_144;
    wire [4:0] signal_wire_145;
    wire [4:0] signal_wire_146;
    wire [2:0] signal_wire_147;
    wire [4:0] signal_wire_148;
    wire [4:0] signal_wire_149;
    wire [4:0] signal_wire_150;
    wire [4:0] signal_wire_151;
    wire [4:0] signal_wire_152;
    wire signal_wire_153;
    wire [4:0] signal_wire_154;
    wire [1:0] signal_wire_155;
    wire signal_wire_156;
    wire signal_wire_157;
    wire [335:0] signal_inst_1;
    wire [27:0] signal_select_67;
    wire [27:0] signal_wire_158;
    assign signal_or = signal_wire_63 | signal_wire_109;
    assign signal_select = signal_or[19:0];
    assign signal_or_1 = signal_wire_109 | signal_const;
    assign signal_and = signal_wire_62 & signal_or_1;
    assign signal_const = 28'b0000000000000000111111111111;
    assign signal_or_2 = signal_wire_63 | signal_const;
    assign signal_and_1 = signal_wire_158 & signal_or_2;
    assign signal_or_3 = signal_and_1 | signal_and;
    assign signal_select_1 = signal_or_3[19:0];
    assign signal_select_2 = signal_inst[335:331];
    assign signal_wire = signal_select_2;
    assign signal_select_3 = signal_inst[330:315];
    assign signal_wire_1 = signal_select_3;
    assign signal_select_4 = signal_inst[314:307];
    assign signal_wire_2 = signal_select_4;
    assign signal_select_5 = signal_inst[306:306];
    assign signal_wire_3 = signal_select_5;
    assign signal_select_6 = signal_inst[305:290];
    assign signal_wire_4 = signal_select_6;
    assign signal_select_7 = signal_inst[289:274];
    assign signal_wire_5 = signal_select_7;
    assign signal_select_8 = signal_inst[273:270];
    assign signal_wire_6 = signal_select_8;
    assign signal_select_9 = signal_inst[269:266];
    assign signal_wire_7 = signal_select_9;
    assign signal_select_10 = signal_inst[265:265];
    assign signal_wire_8 = signal_select_10;
    assign signal_select_11 = signal_inst[264:241];
    assign signal_wire_9 = signal_select_11;
    assign signal_select_12 = signal_inst[240:240];
    assign signal_wire_10 = signal_select_12;
    assign signal_select_13 = signal_inst[239:239];
    assign signal_wire_11 = signal_select_13;
    assign signal_select_14 = signal_inst[238:238];
    assign signal_wire_12 = signal_select_14;
    assign signal_select_15 = signal_inst[237:237];
    assign signal_wire_13 = signal_select_15;
    assign signal_select_16 = signal_inst[236:236];
    assign signal_wire_14 = signal_select_16;
    assign signal_select_17 = signal_inst[235:235];
    assign signal_wire_15 = signal_select_17;
    assign signal_select_18 = signal_inst[234:234];
    assign signal_wire_16 = signal_select_18;
    assign signal_select_19 = signal_inst[233:233];
    assign signal_wire_17 = signal_select_19;
    assign signal_select_20 = signal_inst[232:228];
    assign signal_wire_18 = signal_select_20;
    assign signal_select_21 = signal_inst[227:204];
    assign signal_wire_19 = signal_select_21;
    assign signal_select_22 = signal_inst[203:199];
    assign signal_wire_20 = signal_select_22;
    assign signal_select_23 = signal_inst[198:183];
    assign signal_wire_21 = signal_select_23;
    assign signal_select_24 = signal_inst[182:178];
    assign signal_wire_22 = signal_select_24;
    assign signal_select_25 = signal_inst[177:162];
    assign signal_wire_23 = signal_select_25;
    assign signal_select_26 = signal_inst[161:146];
    assign signal_wire_24 = signal_select_26;
    assign signal_select_27 = signal_inst[145:122];
    assign signal_wire_25 = signal_select_27;
    assign signal_select_28 = signal_inst[121:106];
    assign signal_wire_26 = signal_select_28;
    assign signal_select_29 = signal_inst[105:90];
    assign signal_wire_27 = signal_select_29;
    assign signal_select_30 = signal_inst[89:74];
    assign signal_wire_28 = signal_select_30;
    assign signal_select_31 = signal_inst[73:65];
    assign signal_wire_29 = signal_select_31;
    assign signal_select_32 = signal_inst[64:56];
    assign signal_wire_30 = signal_select_32;
    assign signal_select_33 = signal_inst_1[335:331];
    assign signal_wire_31 = signal_select_33;
    assign signal_select_34 = signal_inst_1[330:315];
    assign signal_wire_32 = signal_select_34;
    assign signal_select_35 = signal_inst_1[314:307];
    assign signal_wire_33 = signal_select_35;
    assign signal_select_36 = signal_inst_1[306:306];
    assign signal_wire_34 = signal_select_36;
    assign signal_select_37 = signal_inst_1[305:290];
    assign signal_wire_35 = signal_select_37;
    assign signal_select_38 = signal_inst_1[289:274];
    assign signal_wire_36 = signal_select_38;
    assign signal_select_39 = signal_inst_1[273:270];
    assign signal_wire_37 = signal_select_39;
    assign signal_select_40 = signal_inst_1[269:266];
    assign signal_wire_38 = signal_select_40;
    assign signal_select_41 = signal_inst_1[265:265];
    assign signal_wire_39 = signal_select_41;
    assign signal_select_42 = signal_inst_1[264:241];
    assign signal_wire_40 = signal_select_42;
    assign signal_select_43 = signal_inst_1[240:240];
    assign signal_wire_41 = signal_select_43;
    assign signal_select_44 = signal_inst_1[239:239];
    assign signal_wire_42 = signal_select_44;
    assign signal_select_45 = signal_inst_1[238:238];
    assign signal_wire_43 = signal_select_45;
    assign signal_select_46 = signal_inst_1[237:237];
    assign signal_wire_44 = signal_select_46;
    assign signal_select_47 = signal_inst_1[236:236];
    assign signal_wire_45 = signal_select_47;
    assign signal_select_48 = signal_inst_1[235:235];
    assign signal_wire_46 = signal_select_48;
    assign signal_select_49 = signal_inst_1[234:234];
    assign signal_wire_47 = signal_select_49;
    assign signal_select_50 = signal_inst_1[233:233];
    assign signal_wire_48 = signal_select_50;
    assign signal_select_51 = signal_inst_1[232:228];
    assign signal_wire_49 = signal_select_51;
    assign signal_select_52 = signal_inst_1[227:204];
    assign signal_wire_50 = signal_select_52;
    assign signal_select_53 = signal_inst_1[203:199];
    assign signal_wire_51 = signal_select_53;
    assign signal_select_54 = signal_inst_1[198:183];
    assign signal_wire_52 = signal_select_54;
    assign signal_select_55 = signal_inst_1[182:178];
    assign signal_wire_53 = signal_select_55;
    assign signal_select_56 = signal_inst_1[177:162];
    assign signal_wire_54 = signal_select_56;
    assign signal_select_57 = signal_inst_1[161:146];
    assign signal_wire_55 = signal_select_57;
    assign signal_select_58 = signal_inst_1[145:122];
    assign signal_wire_56 = signal_select_58;
    assign signal_select_59 = signal_inst_1[121:106];
    assign signal_wire_57 = signal_select_59;
    assign signal_select_60 = signal_inst_1[105:90];
    assign signal_wire_58 = signal_select_60;
    assign signal_select_61 = signal_inst_1[89:74];
    assign signal_wire_59 = signal_select_61;
    assign signal_select_62 = signal_inst_1[73:65];
    assign signal_wire_60 = signal_select_62;
    assign signal_select_63 = signal_inst_1[64:56];
    assign signal_wire_61 = signal_select_63;
    assign signal_const_1 = 28'b1111111100000000000000000000;
    assign signal_or_4 = signal_wire_109 | signal_const_1;
    assign signal_select_64 = signal_inst[27:0];
    assign signal_wire_62 = signal_select_64;
    assign signal_and_2 = signal_wire_62 & signal_or_4;
    assign signal_or_5 = signal_wire_63 | signal_const_1;
    assign signal_and_3 = signal_wire_158 & signal_or_5;
    assign signal_select_65 = signal_inst_1[55:28];
    assign signal_wire_63 = signal_select_65;
    assign signal_not = ~ signal_wire_63;
    assign signal_const_3 = 8'b00000000;
    assign signal_cat = { signal_const_3,
                          signal_wire_110 };
    assign signal_and_4 = signal_cat & signal_not;
    assign signal_or_6 = signal_and_4 | signal_and_3;
    assign signal_wire_64 = hosts$single_step_1;
    assign signal_wire_65 = hosts$resume_1;
    assign signal_wire_66 = hosts$flush_1;
    assign signal_wire_67 = hosts$stop_1;
    assign signal_wire_68 = hosts$clear_irq_1;
    assign signal_wire_69 = hosts$rx_pop_1;
    assign signal_wire_70 = hosts$tx$value_1;
    assign signal_wire_71 = hosts$tx$valid_1;
    assign signal_wire_72 = hosts$data_write$data_1;
    assign signal_wire_73 = hosts$data_write$addr_1;
    assign signal_wire_74 = hosts$data_write$valid_1;
    assign signal_wire_75 = hosts$program_write$data_1;
    assign signal_wire_76 = hosts$program_write$addr_1;
    assign signal_wire_77 = hosts$program_write$valid_1;
    assign signal_wire_78 = hosts$start_1;
    assign signal_wire_79 = hosts$config$autopull_data_1;
    assign signal_wire_80 = hosts$config$break_pc_1;
    assign signal_wire_81 = hosts$config$break_enable_1;
    assign signal_wire_82 = hosts$config$period_fraction_1;
    assign signal_wire_83 = hosts$config$wrap_top_1;
    assign signal_wire_84 = hosts$config$wrap_bottom_1;
    assign signal_wire_85 = hosts$config$stuff_level_1;
    assign signal_wire_86 = hosts$config$stuff_threshold_1;
    assign signal_wire_87 = hosts$config$crc_reflect_1;
    assign signal_wire_88 = hosts$config$crc_init_1;
    assign signal_wire_89 = hosts$config$crc_poly_1;
    assign signal_wire_90 = hosts$config$crc_width_1;
    assign signal_wire_91 = hosts$config$pull_threshold_1;
    assign signal_wire_92 = hosts$config$autopull_1;
    assign signal_wire_93 = hosts$config$push_threshold_1;
    assign signal_wire_94 = hosts$config$autopush_1;
    assign signal_wire_95 = hosts$config$out_shift_right_1;
    assign signal_wire_96 = hosts$config$in_shift_right_1;
    assign signal_wire_97 = hosts$config$capture_rising_1;
    assign signal_wire_98 = hosts$config$capture_pin_1;
    assign signal_wire_99 = hosts$config$jmp_pin_1;
    assign signal_wire_100 = hosts$config$set_count_1;
    assign signal_wire_101 = hosts$config$set_base_1;
    assign signal_wire_102 = hosts$config$out_count_1;
    assign signal_wire_103 = hosts$config$out_base_1;
    assign signal_wire_104 = hosts$config$in_count_1;
    assign signal_wire_105 = hosts$config$in_base_1;
    assign signal_wire_106 = hosts$config$side_set_pindirs_1;
    assign signal_wire_107 = hosts$config$side_set_base_1;
    assign signal_wire_108 = hosts$config$side_set_count_1;
    engine
        engine_1
        ( .clock(signal_wire_157),
          .clear(signal_wire_156),
          .config$side_set_count(signal_wire_108),
          .config$side_set_base(signal_wire_107),
          .config$side_set_pindirs(signal_wire_106),
          .config$in_base(signal_wire_105),
          .config$in_count(signal_wire_104),
          .config$out_base(signal_wire_103),
          .config$out_count(signal_wire_102),
          .config$set_base(signal_wire_101),
          .config$set_count(signal_wire_100),
          .config$jmp_pin(signal_wire_99),
          .config$capture_pin(signal_wire_98),
          .config$capture_rising(signal_wire_97),
          .config$in_shift_right(signal_wire_96),
          .config$out_shift_right(signal_wire_95),
          .config$autopush(signal_wire_94),
          .config$push_threshold(signal_wire_93),
          .config$autopull(signal_wire_92),
          .config$pull_threshold(signal_wire_91),
          .config$crc_width(signal_wire_90),
          .config$crc_poly(signal_wire_89),
          .config$crc_init(signal_wire_88),
          .config$crc_reflect(signal_wire_87),
          .config$stuff_threshold(signal_wire_86),
          .config$stuff_level(signal_wire_85),
          .config$wrap_bottom(signal_wire_84),
          .config$wrap_top(signal_wire_83),
          .config$period_fraction(signal_wire_82),
          .config$break_enable(signal_wire_81),
          .config$break_pc(signal_wire_80),
          .config$autopull_data(signal_wire_79),
          .start(signal_wire_78),
          .program_write$valid(signal_wire_77),
          .program_write$addr(signal_wire_76),
          .program_write$data(signal_wire_75),
          .data_write$valid(signal_wire_74),
          .data_write$addr(signal_wire_73),
          .data_write$data(signal_wire_72),
          .tx$valid(signal_wire_71),
          .tx$value(signal_wire_70),
          .rx_pop(signal_wire_69),
          .clear_irq(signal_wire_68),
          .stop(signal_wire_67),
          .flush(signal_wire_66),
          .resume(signal_wire_65),
          .single_step(signal_wire_64),
          .inputs(signal_or_6),
          .pin_out(signal_inst[27:0]),
          .pin_dir(signal_inst[55:28]),
          .pc(signal_inst[64:56]),
          .data_ptr(signal_inst[73:65]),
          .x(signal_inst[89:74]),
          .y(signal_inst[105:90]),
          .p(signal_inst[121:106]),
          .t(signal_inst[145:122]),
          .t_fraction(signal_inst[161:146]),
          .osr(signal_inst[177:162]),
          .osr_count(signal_inst[182:178]),
          .isr(signal_inst[198:183]),
          .isr_count(signal_inst[203:199]),
          .now(signal_inst[227:204]),
          .stall(signal_inst[232:228]),
          .halted(signal_inst[233:233]),
          .resumed(signal_inst[234:234]),
          .stepping(signal_inst[235:235]),
          .irq(signal_inst[236:236]),
          .fault$underflow(signal_inst[237:237]),
          .fault$overflow(signal_inst[238:238]),
          .fault$missed_deadline(signal_inst[239:239]),
          .fault$decode(signal_inst[240:240]),
          .capture(signal_inst[264:241]),
          .capture_armed(signal_inst[265:265]),
          .tx_level(signal_inst[269:266]),
          .rx_level(signal_inst[273:270]),
          .rx_head(signal_inst[289:274]),
          .instruction(signal_inst[305:290]),
          .decode_ok(signal_inst[306:306]),
          .opcode_onehot(signal_inst[314:307]),
          .crc(signal_inst[330:315]),
          .stuff_run(signal_inst[335:331]) );
    assign signal_select_66 = signal_inst[55:28];
    assign signal_wire_109 = signal_select_66;
    assign signal_not_1 = ~ signal_wire_109;
    assign signal_wire_110 = pads;
    assign signal_cat_1 = { signal_const_3,
                            signal_wire_110 };
    assign signal_and_5 = signal_cat_1 & signal_not_1;
    assign signal_or_7 = signal_and_5 | signal_and_2;
    assign signal_wire_111 = hosts$single_step_0;
    assign signal_wire_112 = hosts$resume_0;
    assign signal_wire_113 = hosts$flush_0;
    assign signal_wire_114 = hosts$stop_0;
    assign signal_wire_115 = hosts$clear_irq_0;
    assign signal_wire_116 = hosts$rx_pop_0;
    assign signal_wire_117 = hosts$tx$value_0;
    assign signal_wire_118 = hosts$tx$valid_0;
    assign signal_wire_119 = hosts$data_write$data_0;
    assign signal_wire_120 = hosts$data_write$addr_0;
    assign signal_wire_121 = hosts$data_write$valid_0;
    assign signal_wire_122 = hosts$program_write$data_0;
    assign signal_wire_123 = hosts$program_write$addr_0;
    assign signal_wire_124 = hosts$program_write$valid_0;
    assign signal_wire_125 = hosts$start_0;
    assign signal_wire_126 = hosts$config$autopull_data_0;
    assign signal_wire_127 = hosts$config$break_pc_0;
    assign signal_wire_128 = hosts$config$break_enable_0;
    assign signal_wire_129 = hosts$config$period_fraction_0;
    assign signal_wire_130 = hosts$config$wrap_top_0;
    assign signal_wire_131 = hosts$config$wrap_bottom_0;
    assign signal_wire_132 = hosts$config$stuff_level_0;
    assign signal_wire_133 = hosts$config$stuff_threshold_0;
    assign signal_wire_134 = hosts$config$crc_reflect_0;
    assign signal_wire_135 = hosts$config$crc_init_0;
    assign signal_wire_136 = hosts$config$crc_poly_0;
    assign signal_wire_137 = hosts$config$crc_width_0;
    assign signal_wire_138 = hosts$config$pull_threshold_0;
    assign signal_wire_139 = hosts$config$autopull_0;
    assign signal_wire_140 = hosts$config$push_threshold_0;
    assign signal_wire_141 = hosts$config$autopush_0;
    assign signal_wire_142 = hosts$config$out_shift_right_0;
    assign signal_wire_143 = hosts$config$in_shift_right_0;
    assign signal_wire_144 = hosts$config$capture_rising_0;
    assign signal_wire_145 = hosts$config$capture_pin_0;
    assign signal_wire_146 = hosts$config$jmp_pin_0;
    assign signal_wire_147 = hosts$config$set_count_0;
    assign signal_wire_148 = hosts$config$set_base_0;
    assign signal_wire_149 = hosts$config$out_count_0;
    assign signal_wire_150 = hosts$config$out_base_0;
    assign signal_wire_151 = hosts$config$in_count_0;
    assign signal_wire_152 = hosts$config$in_base_0;
    assign signal_wire_153 = hosts$config$side_set_pindirs_0;
    assign signal_wire_154 = hosts$config$side_set_base_0;
    assign signal_wire_155 = hosts$config$side_set_count_0;
    assign signal_wire_156 = clear;
    assign signal_wire_157 = clock;
    engine
        engine_0
        ( .clock(signal_wire_157),
          .clear(signal_wire_156),
          .config$side_set_count(signal_wire_155),
          .config$side_set_base(signal_wire_154),
          .config$side_set_pindirs(signal_wire_153),
          .config$in_base(signal_wire_152),
          .config$in_count(signal_wire_151),
          .config$out_base(signal_wire_150),
          .config$out_count(signal_wire_149),
          .config$set_base(signal_wire_148),
          .config$set_count(signal_wire_147),
          .config$jmp_pin(signal_wire_146),
          .config$capture_pin(signal_wire_145),
          .config$capture_rising(signal_wire_144),
          .config$in_shift_right(signal_wire_143),
          .config$out_shift_right(signal_wire_142),
          .config$autopush(signal_wire_141),
          .config$push_threshold(signal_wire_140),
          .config$autopull(signal_wire_139),
          .config$pull_threshold(signal_wire_138),
          .config$crc_width(signal_wire_137),
          .config$crc_poly(signal_wire_136),
          .config$crc_init(signal_wire_135),
          .config$crc_reflect(signal_wire_134),
          .config$stuff_threshold(signal_wire_133),
          .config$stuff_level(signal_wire_132),
          .config$wrap_bottom(signal_wire_131),
          .config$wrap_top(signal_wire_130),
          .config$period_fraction(signal_wire_129),
          .config$break_enable(signal_wire_128),
          .config$break_pc(signal_wire_127),
          .config$autopull_data(signal_wire_126),
          .start(signal_wire_125),
          .program_write$valid(signal_wire_124),
          .program_write$addr(signal_wire_123),
          .program_write$data(signal_wire_122),
          .data_write$valid(signal_wire_121),
          .data_write$addr(signal_wire_120),
          .data_write$data(signal_wire_119),
          .tx$valid(signal_wire_118),
          .tx$value(signal_wire_117),
          .rx_pop(signal_wire_116),
          .clear_irq(signal_wire_115),
          .stop(signal_wire_114),
          .flush(signal_wire_113),
          .resume(signal_wire_112),
          .single_step(signal_wire_111),
          .inputs(signal_or_7),
          .pin_out(signal_inst_1[27:0]),
          .pin_dir(signal_inst_1[55:28]),
          .pc(signal_inst_1[64:56]),
          .data_ptr(signal_inst_1[73:65]),
          .x(signal_inst_1[89:74]),
          .y(signal_inst_1[105:90]),
          .p(signal_inst_1[121:106]),
          .t(signal_inst_1[145:122]),
          .t_fraction(signal_inst_1[161:146]),
          .osr(signal_inst_1[177:162]),
          .osr_count(signal_inst_1[182:178]),
          .isr(signal_inst_1[198:183]),
          .isr_count(signal_inst_1[203:199]),
          .now(signal_inst_1[227:204]),
          .stall(signal_inst_1[232:228]),
          .halted(signal_inst_1[233:233]),
          .resumed(signal_inst_1[234:234]),
          .stepping(signal_inst_1[235:235]),
          .irq(signal_inst_1[236:236]),
          .fault$underflow(signal_inst_1[237:237]),
          .fault$overflow(signal_inst_1[238:238]),
          .fault$missed_deadline(signal_inst_1[239:239]),
          .fault$decode(signal_inst_1[240:240]),
          .capture(signal_inst_1[264:241]),
          .capture_armed(signal_inst_1[265:265]),
          .tx_level(signal_inst_1[269:266]),
          .rx_level(signal_inst_1[273:270]),
          .rx_head(signal_inst_1[289:274]),
          .instruction(signal_inst_1[305:290]),
          .decode_ok(signal_inst_1[306:306]),
          .opcode_onehot(signal_inst_1[314:307]),
          .crc(signal_inst_1[330:315]),
          .stuff_run(signal_inst_1[335:331]) );
    assign signal_select_67 = signal_inst_1[27:0];
    assign signal_wire_158 = signal_select_67;
    assign engines$pin_out_0 = signal_wire_158;
    assign engines$pin_dir_0 = signal_wire_63;
    assign engines$pc_0 = signal_wire_61;
    assign engines$data_ptr_0 = signal_wire_60;
    assign engines$x_0 = signal_wire_59;
    assign engines$y_0 = signal_wire_58;
    assign engines$p_0 = signal_wire_57;
    assign engines$t_0 = signal_wire_56;
    assign engines$t_fraction_0 = signal_wire_55;
    assign engines$osr_0 = signal_wire_54;
    assign engines$osr_count_0 = signal_wire_53;
    assign engines$isr_0 = signal_wire_52;
    assign engines$isr_count_0 = signal_wire_51;
    assign engines$now_0 = signal_wire_50;
    assign engines$stall_0 = signal_wire_49;
    assign engines$halted_0 = signal_wire_48;
    assign engines$resumed_0 = signal_wire_47;
    assign engines$stepping_0 = signal_wire_46;
    assign engines$irq_0 = signal_wire_45;
    assign engines$fault$underflow_0 = signal_wire_44;
    assign engines$fault$overflow_0 = signal_wire_43;
    assign engines$fault$missed_deadline_0 = signal_wire_42;
    assign engines$fault$decode_0 = signal_wire_41;
    assign engines$capture_0 = signal_wire_40;
    assign engines$capture_armed_0 = signal_wire_39;
    assign engines$tx_level_0 = signal_wire_38;
    assign engines$rx_level_0 = signal_wire_37;
    assign engines$rx_head_0 = signal_wire_36;
    assign engines$instruction_0 = signal_wire_35;
    assign engines$decode_ok_0 = signal_wire_34;
    assign engines$opcode_onehot_0 = signal_wire_33;
    assign engines$crc_0 = signal_wire_32;
    assign engines$stuff_run_0 = signal_wire_31;
    assign engines$pin_out_1 = signal_wire_62;
    assign engines$pin_dir_1 = signal_wire_109;
    assign engines$pc_1 = signal_wire_30;
    assign engines$data_ptr_1 = signal_wire_29;
    assign engines$x_1 = signal_wire_28;
    assign engines$y_1 = signal_wire_27;
    assign engines$p_1 = signal_wire_26;
    assign engines$t_1 = signal_wire_25;
    assign engines$t_fraction_1 = signal_wire_24;
    assign engines$osr_1 = signal_wire_23;
    assign engines$osr_count_1 = signal_wire_22;
    assign engines$isr_1 = signal_wire_21;
    assign engines$isr_count_1 = signal_wire_20;
    assign engines$now_1 = signal_wire_19;
    assign engines$stall_1 = signal_wire_18;
    assign engines$halted_1 = signal_wire_17;
    assign engines$resumed_1 = signal_wire_16;
    assign engines$stepping_1 = signal_wire_15;
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
    status$x_0,
    status$y_0,
    status$p_0,
    status$t_0,
    status$isr_0,
    status$osr_0,
    status$isr_count_0,
    status$osr_count_0,
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
    status$x_1,
    status$y_1,
    status$p_1,
    status$t_1,
    status$isr_1,
    status$osr_1,
    status$isr_count_1,
    status$osr_count_1,
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
    engines$config$break_enable_0,
    engines$config$break_pc_0,
    engines$config$autopull_data_0,
    engines$start_0,
    engines$program_write$valid_0,
    engines$program_write$addr_0,
    engines$program_write$data_0,
    engines$data_write$valid_0,
    engines$data_write$addr_0,
    engines$data_write$data_0,
    engines$tx$valid_0,
    engines$tx$value_0,
    engines$rx_pop_0,
    engines$clear_irq_0,
    engines$stop_0,
    engines$flush_0,
    engines$resume_0,
    engines$single_step_0,
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
    engines$config$break_enable_1,
    engines$config$break_pc_1,
    engines$config$autopull_data_1,
    engines$start_1,
    engines$program_write$valid_1,
    engines$program_write$addr_1,
    engines$program_write$data_1,
    engines$data_write$valid_1,
    engines$data_write$addr_1,
    engines$data_write$data_1,
    engines$tx$valid_1,
    engines$tx$value_1,
    engines$rx_pop_1,
    engines$clear_irq_1,
    engines$stop_1,
    engines$flush_1,
    engines$resume_1,
    engines$single_step_1
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
    input [15:0] status$x_0;
    input [15:0] status$y_0;
    input [15:0] status$p_0;
    input [23:0] status$t_0;
    input [15:0] status$isr_0;
    input [15:0] status$osr_0;
    input [4:0] status$isr_count_0;
    input [4:0] status$osr_count_0;
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
    input [15:0] status$x_1;
    input [15:0] status$y_1;
    input [15:0] status$p_1;
    input [23:0] status$t_1;
    input [15:0] status$isr_1;
    input [15:0] status$osr_1;
    input [4:0] status$isr_count_1;
    input [4:0] status$osr_count_1;
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
    output engines$config$break_enable_0;
    output [8:0] engines$config$break_pc_0;
    output engines$config$autopull_data_0;
    output engines$start_0;
    output engines$program_write$valid_0;
    output [8:0] engines$program_write$addr_0;
    output [15:0] engines$program_write$data_0;
    output engines$data_write$valid_0;
    output [8:0] engines$data_write$addr_0;
    output [15:0] engines$data_write$data_0;
    output engines$tx$valid_0;
    output [15:0] engines$tx$value_0;
    output engines$rx_pop_0;
    output engines$clear_irq_0;
    output engines$stop_0;
    output engines$flush_0;
    output engines$resume_0;
    output engines$single_step_0;
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
    output engines$config$break_enable_1;
    output [8:0] engines$config$break_pc_1;
    output engines$config$autopull_data_1;
    output engines$start_1;
    output engines$program_write$valid_1;
    output [8:0] engines$program_write$addr_1;
    output [15:0] engines$program_write$data_1;
    output engines$data_write$valid_1;
    output [8:0] engines$data_write$addr_1;
    output [15:0] engines$data_write$data_1;
    output engines$tx$valid_1;
    output [15:0] engines$tx$value_1;
    output engines$rx_pop_1;
    output engines$clear_irq_1;
    output engines$stop_1;
    output engines$flush_1;
    output engines$resume_1;
    output engines$single_step_1;

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
    wire signal_select_3;
    wire signal_eq_7;
    wire signal_and_9;
    wire signal_and_10;
    wire signal_and_11;
    wire signal_eq_8;
    wire signal_select_4;
    wire signal_eq_9;
    wire signal_and_12;
    wire signal_and_13;
    wire signal_and_14;
    wire signal_eq_10;
    wire [6:0] signal_const_11;
    wire signal_eq_11;
    wire signal_and_15;
    wire signal_and_16;
    wire signal_eq_12;
    wire [6:0] signal_const_13;
    wire signal_eq_13;
    wire signal_and_17;
    wire signal_and_18;
    wire signal_eq_14;
    wire [6:0] signal_const_15;
    wire signal_eq_15;
    wire signal_and_19;
    wire signal_and_20;
    wire signal_eq_16;
    wire [6:0] signal_const_17;
    wire signal_eq_17;
    wire signal_and_21;
    wire signal_and_22;
    wire signal_eq_18;
    wire signal_select_5;
    wire signal_eq_19;
    wire signal_and_23;
    wire signal_and_24;
    wire signal_and_25;
    wire signal_const_20;
    wire signal_eq_20;
    wire signal_select_6;
    wire signal_eq_21;
    wire signal_and_26;
    wire signal_and_27;
    wire signal_and_28;
    wire signal_eq_22;
    wire signal_select_7;
    wire signal_eq_23;
    wire signal_and_29;
    wire signal_and_30;
    wire signal_and_31;
    wire signal_eq_24;
    wire signal_select_8;
    wire signal_eq_25;
    wire signal_and_32;
    wire signal_and_33;
    wire signal_and_34;
    wire signal_eq_26;
    wire signal_select_9;
    wire signal_eq_27;
    wire signal_and_35;
    wire signal_and_36;
    wire signal_and_37;
    wire signal_eq_28;
    wire signal_select_10;
    wire signal_eq_29;
    wire signal_and_38;
    wire signal_and_39;
    wire signal_and_40;
    wire signal_eq_30;
    wire signal_eq_31;
    wire signal_and_41;
    wire signal_and_42;
    wire signal_eq_32;
    wire signal_eq_33;
    wire signal_and_43;
    wire signal_and_44;
    wire signal_eq_34;
    wire signal_eq_35;
    wire signal_and_45;
    wire signal_and_46;
    wire signal_eq_36;
    wire signal_eq_37;
    wire signal_and_47;
    wire signal_and_48;
    wire signal_eq_38;
    wire signal_select_11;
    wire signal_eq_39;
    wire signal_and_49;
    wire signal_and_50;
    wire signal_and_51;
    wire [7:0] signal_select_12;
    wire [15:0] signal_const_40;
    wire [14:0] signal_const_42;
    wire [15:0] signal_cat;
    wire [15:0] signal_cat_1;
    wire [15:0] signal_cat_2;
    wire [15:0] signal_cat_3;
    wire [15:0] signal_cat_4;
    wire [15:0] signal_cat_5;
    wire [10:0] signal_const_55;
    wire [15:0] signal_cat_6;
    wire [15:0] signal_cat_7;
    wire [15:0] signal_cat_8;
    wire [15:0] signal_cat_9;
    wire [15:0] signal_cat_10;
    wire [15:0] signal_cat_11;
    wire [15:0] signal_cat_12;
    wire [15:0] signal_cat_13;
    wire [15:0] signal_cat_14;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_cat_16;
    wire [15:0] signal_cat_17;
    wire [12:0] signal_const_81;
    wire [15:0] signal_cat_18;
    wire [15:0] signal_cat_19;
    wire [15:0] signal_cat_20;
    wire [15:0] signal_cat_21;
    wire [15:0] signal_cat_22;
    wire [15:0] signal_cat_23;
    wire [15:0] signal_cat_24;
    wire [15:0] signal_cat_25;
    wire [13:0] signal_const_97;
    wire [15:0] signal_cat_26;
    wire [15:0] signal_cat_27;
    wire [2:0] signal_const_101;
    wire [7:0] signal_cat_28;
    wire [12:0] signal_cat_29;
    wire [15:0] signal_cat_30;
    wire [7:0] signal_select_13;
    wire [7:0] signal_const_106;
    wire [15:0] signal_cat_31;
    wire [15:0] signal_select_14;
    wire [15:0] signal_cat_32;
    wire [15:0] signal_cat_33;
    wire [7:0] signal_select_15;
    wire [15:0] signal_cat_34;
    wire [15:0] signal_select_16;
    wire [7:0] signal_select_17;
    wire [15:0] signal_cat_35;
    wire [15:0] signal_select_18;
    wire [15:0] signal_cat_36;
    reg [15:0] read_value;
    wire signal_select_19;
    wire signal_eq_40;
    wire [6:0] signal_const_129;
    wire signal_eq_41;
    wire signal_and_52;
    wire signal_and_53;
    wire signal_mux;
    wire signal_mux_1;
    wire signal_wire;
    reg signal_reg;
    wire signal_select_20;
    wire signal_eq_42;
    wire signal_eq_43;
    wire signal_and_54;
    wire signal_and_55;
    wire signal_mux_2;
    wire signal_mux_3;
    wire signal_wire_1;
    reg signal_reg_1;
    wire signal_mux_4;
    wire [15:0] signal_cat_37;
    wire [8:0] signal_const_135;
    wire [8:0] signal_select_21;
    wire signal_eq_44;
    wire [6:0] signal_const_137;
    wire signal_eq_45;
    wire signal_and_56;
    wire signal_and_57;
    wire [8:0] signal_mux_5;
    wire [8:0] signal_mux_6;
    wire [8:0] signal_wire_2;
    reg [8:0] signal_reg_2;
    wire [8:0] signal_select_22;
    wire signal_eq_46;
    wire signal_eq_47;
    wire signal_and_58;
    wire signal_and_59;
    wire [8:0] signal_mux_7;
    wire [8:0] signal_mux_8;
    wire [8:0] signal_wire_3;
    reg [8:0] signal_reg_3;
    wire [8:0] signal_mux_9;
    wire [15:0] signal_cat_38;
    wire signal_select_23;
    wire signal_eq_48;
    wire [6:0] signal_const_145;
    wire signal_eq_49;
    wire signal_and_60;
    wire signal_and_61;
    wire signal_mux_10;
    wire signal_mux_11;
    wire signal_wire_4;
    reg signal_reg_4;
    wire signal_select_24;
    wire signal_eq_50;
    wire signal_eq_51;
    wire signal_and_62;
    wire signal_and_63;
    wire signal_mux_12;
    wire signal_mux_13;
    wire signal_wire_5;
    reg signal_reg_5;
    wire signal_mux_14;
    wire [15:0] signal_cat_39;
    wire signal_eq_52;
    wire [6:0] signal_const_153;
    wire signal_eq_53;
    wire signal_and_64;
    wire signal_and_65;
    wire [15:0] signal_mux_15;
    wire [15:0] signal_mux_16;
    wire [15:0] signal_wire_6;
    reg [15:0] signal_reg_6;
    wire signal_eq_54;
    wire signal_eq_55;
    wire signal_and_66;
    wire signal_and_67;
    wire [15:0] signal_mux_17;
    wire [15:0] signal_mux_18;
    wire [15:0] signal_wire_7;
    reg [15:0] signal_reg_7;
    wire [15:0] signal_mux_19;
    wire [8:0] signal_select_25;
    wire signal_eq_56;
    wire [6:0] signal_const_160;
    wire signal_eq_57;
    wire signal_and_68;
    wire signal_and_69;
    wire [8:0] signal_mux_20;
    wire [8:0] signal_mux_21;
    wire [8:0] signal_wire_8;
    reg [8:0] signal_reg_8;
    wire [8:0] signal_select_26;
    wire signal_eq_58;
    wire signal_eq_59;
    wire signal_and_70;
    wire signal_and_71;
    wire [8:0] signal_mux_22;
    wire [8:0] signal_mux_23;
    wire [8:0] signal_wire_9;
    reg [8:0] signal_reg_9;
    wire [8:0] signal_mux_24;
    wire [15:0] signal_cat_40;
    wire [8:0] signal_select_27;
    wire signal_eq_60;
    wire [6:0] signal_const_168;
    wire signal_eq_61;
    wire signal_and_72;
    wire signal_and_73;
    wire [8:0] signal_mux_25;
    wire [8:0] signal_mux_26;
    wire [8:0] signal_wire_10;
    reg [8:0] signal_reg_10;
    wire [8:0] signal_select_28;
    wire signal_eq_62;
    wire signal_eq_63;
    wire signal_and_74;
    wire signal_and_75;
    wire [8:0] signal_mux_27;
    wire [8:0] signal_mux_28;
    wire [8:0] signal_wire_11;
    reg [8:0] signal_reg_11;
    wire [8:0] signal_mux_29;
    wire [15:0] signal_cat_41;
    wire signal_select_29;
    wire signal_eq_64;
    wire [6:0] signal_const_176;
    wire signal_eq_65;
    wire signal_and_76;
    wire signal_and_77;
    wire signal_mux_30;
    wire signal_mux_31;
    wire signal_wire_12;
    reg signal_reg_12;
    wire signal_select_30;
    wire signal_eq_66;
    wire signal_eq_67;
    wire signal_and_78;
    wire signal_and_79;
    wire signal_mux_32;
    wire signal_mux_33;
    wire signal_wire_13;
    reg signal_reg_13;
    wire signal_mux_34;
    wire [15:0] signal_cat_42;
    wire [4:0] signal_const_182;
    wire [4:0] signal_select_31;
    wire signal_eq_68;
    wire [6:0] signal_const_184;
    wire signal_eq_69;
    wire signal_and_80;
    wire signal_and_81;
    wire [4:0] signal_mux_35;
    wire [4:0] signal_mux_36;
    wire [4:0] signal_wire_14;
    reg [4:0] signal_reg_14;
    wire [4:0] signal_select_32;
    wire signal_eq_70;
    wire signal_eq_71;
    wire signal_and_82;
    wire signal_and_83;
    wire [4:0] signal_mux_37;
    wire [4:0] signal_mux_38;
    wire [4:0] signal_wire_15;
    reg [4:0] signal_reg_15;
    wire [4:0] signal_mux_39;
    wire [15:0] signal_cat_43;
    wire signal_select_33;
    wire signal_eq_72;
    wire [6:0] signal_const_192;
    wire signal_eq_73;
    wire signal_and_84;
    wire signal_and_85;
    wire signal_mux_40;
    wire signal_mux_41;
    wire signal_wire_16;
    reg signal_reg_16;
    wire signal_select_34;
    wire signal_eq_74;
    wire signal_eq_75;
    wire signal_and_86;
    wire signal_and_87;
    wire signal_mux_42;
    wire signal_mux_43;
    wire signal_wire_17;
    reg signal_reg_17;
    wire signal_mux_44;
    wire [15:0] signal_cat_44;
    wire signal_eq_76;
    wire [6:0] signal_const_200;
    wire signal_eq_77;
    wire signal_and_88;
    wire signal_and_89;
    wire [15:0] signal_mux_45;
    wire [15:0] signal_mux_46;
    wire [15:0] signal_wire_18;
    reg [15:0] signal_reg_18;
    wire signal_eq_78;
    wire signal_eq_79;
    wire signal_and_90;
    wire signal_and_91;
    wire [15:0] signal_mux_47;
    wire [15:0] signal_mux_48;
    wire [15:0] signal_wire_19;
    reg [15:0] signal_reg_19;
    wire [15:0] signal_mux_49;
    wire signal_eq_80;
    wire [6:0] signal_const_207;
    wire signal_eq_81;
    wire signal_and_92;
    wire signal_and_93;
    wire [15:0] signal_mux_50;
    wire [15:0] signal_mux_51;
    wire [15:0] signal_wire_20;
    reg [15:0] signal_reg_20;
    wire signal_eq_82;
    wire signal_eq_83;
    wire signal_and_94;
    wire signal_and_95;
    wire [15:0] signal_mux_52;
    wire [15:0] signal_mux_53;
    wire [15:0] signal_wire_21;
    reg [15:0] signal_reg_21;
    wire [15:0] signal_mux_54;
    wire [4:0] signal_select_35;
    wire signal_eq_84;
    wire [6:0] signal_const_214;
    wire signal_eq_85;
    wire signal_and_96;
    wire signal_and_97;
    wire [4:0] signal_mux_55;
    wire [4:0] signal_mux_56;
    wire [4:0] signal_wire_22;
    reg [4:0] signal_reg_22;
    wire [4:0] signal_select_36;
    wire signal_eq_86;
    wire signal_eq_87;
    wire signal_and_98;
    wire signal_and_99;
    wire [4:0] signal_mux_57;
    wire [4:0] signal_mux_58;
    wire [4:0] signal_wire_23;
    reg [4:0] signal_reg_23;
    wire [4:0] signal_mux_59;
    wire [15:0] signal_cat_45;
    wire [4:0] signal_select_37;
    wire signal_eq_88;
    wire [6:0] signal_const_222;
    wire signal_eq_89;
    wire signal_and_100;
    wire signal_and_101;
    wire [4:0] signal_mux_60;
    wire [4:0] signal_mux_61;
    wire [4:0] signal_wire_24;
    reg [4:0] signal_reg_24;
    wire [4:0] signal_select_38;
    wire signal_eq_90;
    wire signal_eq_91;
    wire signal_and_102;
    wire signal_and_103;
    wire [4:0] signal_mux_62;
    wire [4:0] signal_mux_63;
    wire [4:0] signal_wire_25;
    reg [4:0] signal_reg_25;
    wire [4:0] signal_mux_64;
    wire [15:0] signal_cat_46;
    wire signal_select_39;
    wire signal_eq_92;
    wire [6:0] signal_const_230;
    wire signal_eq_93;
    wire signal_and_104;
    wire signal_and_105;
    wire signal_mux_65;
    wire signal_mux_66;
    wire signal_wire_26;
    reg signal_reg_26;
    wire signal_select_40;
    wire signal_eq_94;
    wire signal_eq_95;
    wire signal_and_106;
    wire signal_and_107;
    wire signal_mux_67;
    wire signal_mux_68;
    wire signal_wire_27;
    reg signal_reg_27;
    wire signal_mux_69;
    wire [15:0] signal_cat_47;
    wire [4:0] signal_select_41;
    wire signal_eq_96;
    wire [6:0] signal_const_238;
    wire signal_eq_97;
    wire signal_and_108;
    wire signal_and_109;
    wire [4:0] signal_mux_70;
    wire [4:0] signal_mux_71;
    wire [4:0] signal_wire_28;
    reg [4:0] signal_reg_28;
    wire [4:0] signal_select_42;
    wire signal_eq_98;
    wire signal_eq_99;
    wire signal_and_110;
    wire signal_and_111;
    wire [4:0] signal_mux_72;
    wire [4:0] signal_mux_73;
    wire [4:0] signal_wire_29;
    reg [4:0] signal_reg_29;
    wire [4:0] signal_mux_74;
    wire [15:0] signal_cat_48;
    wire signal_select_43;
    wire signal_eq_100;
    wire [6:0] signal_const_246;
    wire signal_eq_101;
    wire signal_and_112;
    wire signal_and_113;
    wire signal_mux_75;
    wire signal_mux_76;
    wire signal_wire_30;
    reg signal_reg_30;
    wire signal_select_44;
    wire signal_eq_102;
    wire signal_eq_103;
    wire signal_and_114;
    wire signal_and_115;
    wire signal_mux_77;
    wire signal_mux_78;
    wire signal_wire_31;
    reg signal_reg_31;
    wire signal_mux_79;
    wire [15:0] signal_cat_49;
    wire signal_select_45;
    wire signal_eq_104;
    wire [6:0] signal_const_254;
    wire signal_eq_105;
    wire signal_and_116;
    wire signal_and_117;
    wire signal_mux_80;
    wire signal_mux_81;
    wire signal_wire_32;
    reg signal_reg_32;
    wire signal_select_46;
    wire signal_eq_106;
    wire signal_eq_107;
    wire signal_and_118;
    wire signal_and_119;
    wire signal_mux_82;
    wire signal_mux_83;
    wire signal_wire_33;
    reg signal_reg_33;
    wire signal_mux_84;
    wire [15:0] signal_cat_50;
    wire signal_select_47;
    wire signal_eq_108;
    wire [6:0] signal_const_262;
    wire signal_eq_109;
    wire signal_and_120;
    wire signal_and_121;
    wire signal_mux_85;
    wire signal_mux_86;
    wire signal_wire_34;
    reg signal_reg_34;
    wire signal_select_48;
    wire signal_eq_110;
    wire signal_eq_111;
    wire signal_and_122;
    wire signal_and_123;
    wire signal_mux_87;
    wire signal_mux_88;
    wire signal_wire_35;
    reg signal_reg_35;
    wire signal_mux_89;
    wire [15:0] signal_cat_51;
    wire signal_select_49;
    wire signal_eq_112;
    wire [6:0] signal_const_270;
    wire signal_eq_113;
    wire signal_and_124;
    wire signal_and_125;
    wire signal_mux_90;
    wire signal_mux_91;
    wire signal_wire_36;
    reg signal_reg_36;
    wire signal_select_50;
    wire signal_eq_114;
    wire signal_eq_115;
    wire signal_and_126;
    wire signal_and_127;
    wire signal_mux_92;
    wire signal_mux_93;
    wire signal_wire_37;
    reg signal_reg_37;
    wire signal_mux_94;
    wire [15:0] signal_cat_52;
    wire [4:0] signal_select_51;
    wire signal_eq_116;
    wire [6:0] signal_const_278;
    wire signal_eq_117;
    wire signal_and_128;
    wire signal_and_129;
    wire [4:0] signal_mux_95;
    wire [4:0] signal_mux_96;
    wire [4:0] signal_wire_38;
    reg [4:0] signal_reg_38;
    wire [4:0] signal_select_52;
    wire signal_eq_118;
    wire signal_eq_119;
    wire signal_and_130;
    wire signal_and_131;
    wire [4:0] signal_mux_97;
    wire [4:0] signal_mux_98;
    wire [4:0] signal_wire_39;
    reg [4:0] signal_reg_39;
    wire [4:0] signal_mux_99;
    wire [15:0] signal_cat_53;
    wire [4:0] signal_select_53;
    wire signal_eq_120;
    wire [6:0] signal_const_286;
    wire signal_eq_121;
    wire signal_and_132;
    wire signal_and_133;
    wire [4:0] signal_mux_100;
    wire [4:0] signal_mux_101;
    wire [4:0] signal_wire_40;
    reg [4:0] signal_reg_40;
    wire [4:0] signal_select_54;
    wire signal_eq_122;
    wire signal_eq_123;
    wire signal_and_134;
    wire signal_and_135;
    wire [4:0] signal_mux_102;
    wire [4:0] signal_mux_103;
    wire [4:0] signal_wire_41;
    reg [4:0] signal_reg_41;
    wire [4:0] signal_mux_104;
    wire [15:0] signal_cat_54;
    wire [2:0] signal_select_55;
    wire signal_eq_124;
    wire [6:0] signal_const_294;
    wire signal_eq_125;
    wire signal_and_136;
    wire signal_and_137;
    wire [2:0] signal_mux_105;
    wire [2:0] signal_mux_106;
    wire [2:0] signal_wire_42;
    reg [2:0] signal_reg_42;
    wire [2:0] signal_select_56;
    wire signal_eq_126;
    wire signal_eq_127;
    wire signal_and_138;
    wire signal_and_139;
    wire [2:0] signal_mux_107;
    wire [2:0] signal_mux_108;
    wire [2:0] signal_wire_43;
    reg [2:0] signal_reg_43;
    wire [2:0] signal_mux_109;
    wire [15:0] signal_cat_55;
    wire [4:0] signal_select_57;
    wire signal_eq_128;
    wire [6:0] signal_const_302;
    wire signal_eq_129;
    wire signal_and_140;
    wire signal_and_141;
    wire [4:0] signal_mux_110;
    wire [4:0] signal_mux_111;
    wire [4:0] signal_wire_44;
    reg [4:0] signal_reg_44;
    wire [4:0] signal_select_58;
    wire signal_eq_130;
    wire signal_eq_131;
    wire signal_and_142;
    wire signal_and_143;
    wire [4:0] signal_mux_112;
    wire [4:0] signal_mux_113;
    wire [4:0] signal_wire_45;
    reg [4:0] signal_reg_45;
    wire [4:0] signal_mux_114;
    wire [15:0] signal_cat_56;
    wire [4:0] signal_select_59;
    wire signal_eq_132;
    wire [6:0] signal_const_310;
    wire signal_eq_133;
    wire signal_and_144;
    wire signal_and_145;
    wire [4:0] signal_mux_115;
    wire [4:0] signal_mux_116;
    wire [4:0] signal_wire_46;
    reg [4:0] signal_reg_46;
    wire [4:0] signal_select_60;
    wire signal_eq_134;
    wire signal_eq_135;
    wire signal_and_146;
    wire signal_and_147;
    wire [4:0] signal_mux_117;
    wire [4:0] signal_mux_118;
    wire [4:0] signal_wire_47;
    reg [4:0] signal_reg_47;
    wire [4:0] signal_mux_119;
    wire [15:0] signal_cat_57;
    wire [4:0] signal_select_61;
    wire signal_eq_136;
    wire [6:0] signal_const_318;
    wire signal_eq_137;
    wire signal_and_148;
    wire signal_and_149;
    wire [4:0] signal_mux_120;
    wire [4:0] signal_mux_121;
    wire [4:0] signal_wire_48;
    reg [4:0] signal_reg_48;
    wire [4:0] signal_select_62;
    wire signal_eq_138;
    wire signal_eq_139;
    wire signal_and_150;
    wire signal_and_151;
    wire [4:0] signal_mux_122;
    wire [4:0] signal_mux_123;
    wire [4:0] signal_wire_49;
    reg [4:0] signal_reg_49;
    wire [4:0] signal_mux_124;
    wire [15:0] signal_cat_58;
    wire [4:0] signal_select_63;
    wire signal_eq_140;
    wire [6:0] signal_const_326;
    wire signal_eq_141;
    wire signal_and_152;
    wire signal_and_153;
    wire [4:0] signal_mux_125;
    wire [4:0] signal_mux_126;
    wire [4:0] signal_wire_50;
    reg [4:0] signal_reg_50;
    wire [4:0] signal_select_64;
    wire signal_eq_142;
    wire signal_eq_143;
    wire signal_and_154;
    wire signal_and_155;
    wire [4:0] signal_mux_127;
    wire [4:0] signal_mux_128;
    wire [4:0] signal_wire_51;
    reg [4:0] signal_reg_51;
    wire [4:0] signal_mux_129;
    wire [15:0] signal_cat_59;
    wire [4:0] signal_select_65;
    wire signal_eq_144;
    wire [6:0] signal_const_334;
    wire signal_eq_145;
    wire signal_and_156;
    wire signal_and_157;
    wire [4:0] signal_mux_130;
    wire [4:0] signal_mux_131;
    wire [4:0] signal_wire_52;
    reg [4:0] signal_reg_52;
    wire [4:0] signal_select_66;
    wire signal_eq_146;
    wire signal_eq_147;
    wire signal_and_158;
    wire signal_and_159;
    wire [4:0] signal_mux_132;
    wire [4:0] signal_mux_133;
    wire [4:0] signal_wire_53;
    reg [4:0] signal_reg_53;
    wire [4:0] signal_mux_134;
    wire [15:0] signal_cat_60;
    wire signal_select_67;
    wire signal_eq_148;
    wire [6:0] signal_const_342;
    wire signal_eq_149;
    wire signal_and_160;
    wire signal_and_161;
    wire signal_mux_135;
    wire signal_mux_136;
    wire signal_wire_54;
    reg signal_reg_54;
    wire signal_select_68;
    wire signal_eq_150;
    wire signal_eq_151;
    wire signal_and_162;
    wire signal_and_163;
    wire signal_mux_137;
    wire signal_mux_138;
    wire signal_wire_55;
    reg signal_reg_55;
    wire signal_mux_139;
    wire [15:0] signal_cat_61;
    wire [4:0] signal_select_69;
    wire signal_eq_152;
    wire [6:0] signal_const_350;
    wire signal_eq_153;
    wire signal_and_164;
    wire signal_and_165;
    wire [4:0] signal_mux_140;
    wire [4:0] signal_mux_141;
    wire [4:0] signal_wire_56;
    reg [4:0] signal_reg_56;
    wire [4:0] signal_select_70;
    wire signal_eq_154;
    wire signal_eq_155;
    wire signal_and_166;
    wire signal_and_167;
    wire [4:0] signal_mux_142;
    wire [4:0] signal_mux_143;
    wire [4:0] signal_wire_57;
    reg [4:0] signal_reg_57;
    wire [4:0] signal_mux_144;
    wire [15:0] signal_cat_62;
    wire [1:0] signal_const_356;
    wire [1:0] signal_select_71;
    wire signal_eq_156;
    wire [6:0] signal_const_358;
    wire signal_eq_157;
    wire signal_and_168;
    wire signal_and_169;
    wire [1:0] signal_mux_145;
    wire [1:0] signal_mux_146;
    wire [1:0] signal_wire_58;
    reg [1:0] signal_reg_58;
    wire [1:0] signal_select_72;
    wire signal_eq_158;
    wire signal_eq_159;
    wire signal_and_170;
    wire signal_and_171;
    wire [1:0] signal_mux_147;
    wire [1:0] signal_mux_148;
    wire [1:0] signal_wire_59;
    reg [1:0] signal_reg_59;
    wire [1:0] signal_mux_149;
    wire [15:0] signal_cat_63;
    wire [15:0] signal_cat_64;
    wire [4:0] signal_wire_60;
    wire [4:0] signal_wire_61;
    wire [4:0] signal_mux_150;
    wire [7:0] signal_cat_65;
    wire [4:0] signal_wire_62;
    wire [4:0] signal_wire_63;
    wire [4:0] signal_mux_151;
    wire [12:0] signal_cat_66;
    wire [15:0] signal_cat_67;
    wire [15:0] signal_wire_64;
    wire [15:0] signal_wire_65;
    wire [15:0] signal_mux_152;
    wire [15:0] signal_wire_66;
    wire [15:0] signal_wire_67;
    wire [15:0] signal_mux_153;
    wire [7:0] signal_select_73;
    wire [15:0] signal_cat_68;
    wire [23:0] signal_wire_68;
    wire [23:0] signal_wire_69;
    wire [23:0] signal_mux_154;
    wire [15:0] signal_select_74;
    wire [15:0] signal_wire_70;
    wire [15:0] signal_wire_71;
    wire [15:0] signal_mux_155;
    wire [15:0] signal_wire_72;
    wire [15:0] signal_wire_73;
    wire [15:0] signal_mux_156;
    wire [15:0] signal_wire_74;
    wire [15:0] signal_wire_75;
    wire [15:0] signal_mux_157;
    wire [8:0] signal_const_378;
    wire [8:0] signal_add;
    wire [8:0] signal_select_75;
    wire [6:0] signal_const_379;
    wire signal_eq_160;
    wire [8:0] signal_mux_158;
    wire signal_eq_161;
    wire [8:0] signal_mux_159;
    wire [8:0] signal_mux_160;
    wire [8:0] signal_wire_76;
    reg [8:0] data_addr;
    wire [15:0] signal_cat_69;
    wire [8:0] signal_add_1;
    wire [8:0] signal_select_76;
    wire [6:0] signal_const_385;
    wire signal_eq_162;
    wire [8:0] signal_mux_161;
    wire signal_eq_163;
    wire [8:0] signal_mux_162;
    wire [8:0] signal_mux_163;
    wire [8:0] signal_wire_77;
    reg [8:0] program_addr;
    wire [15:0] signal_cat_70;
    wire [15:0] signal_wire_78;
    wire [15:0] signal_wire_79;
    wire [15:0] signal_mux_164;
    wire [7:0] signal_select_77;
    wire [15:0] signal_cat_71;
    wire [23:0] signal_wire_80;
    wire [23:0] signal_wire_81;
    wire [23:0] signal_mux_165;
    wire [15:0] signal_select_78;
    wire [7:0] signal_select_79;
    wire [15:0] signal_cat_72;
    wire [23:0] signal_wire_82;
    wire [23:0] signal_wire_83;
    wire [23:0] signal_mux_166;
    wire [15:0] signal_select_80;
    wire [8:0] signal_wire_84;
    wire [8:0] signal_wire_85;
    wire [8:0] signal_mux_167;
    wire [15:0] signal_cat_73;
    wire signal_wire_86;
    wire signal_wire_87;
    wire signal_mux_168;
    wire signal_mux_169;
    wire signal_wire_88;
    wire signal_wire_89;
    wire signal_mux_170;
    wire signal_wire_90;
    wire signal_wire_91;
    wire signal_mux_171;
    wire signal_wire_92;
    wire signal_wire_93;
    wire signal_mux_172;
    wire signal_wire_94;
    wire signal_wire_95;
    wire signal_mux_173;
    wire [3:0] signal_wire_96;
    wire [3:0] signal_wire_97;
    wire [3:0] signal_mux_174;
    wire [3:0] signal_wire_98;
    wire [3:0] signal_wire_99;
    wire [3:0] signal_mux_175;
    wire signal_wire_100;
    wire signal_wire_101;
    reg [7:0] signal_cases;
    wire [7:0] signal_mux_176;
    wire [7:0] signal_wire_102;
    reg [7:0] high;
    wire [15:0] value;
    wire signal_select_81;
    wire [6:0] signal_const_401;
    wire signal_eq_164;
    wire signal_mux_177;
    wire signal_mux_178;
    reg signal_cases_1;
    wire signal_mux_179;
    wire write;
    wire signal_mux_180;
    wire signal_wire_103;
    reg select;
    wire signal_mux_181;
    wire [15:0] signal_cat_74;
    wire [6:0] signal_select_82;
    reg [15:0] first_read;
    reg [15:0] signal_cases_2;
    wire [15:0] signal_mux_182;
    wire vdd;
    wire is_write;
    wire signal_mux_183;
    reg signal_cases_3;
    wire gnd;
    wire signal_mux_184;
    wire read_done;
    wire [15:0] signal_mux_185;
    wire [15:0] signal_wire_104;
    reg [15:0] word;
    wire [7:0] signal_select_83;
    reg [7:0] signal_cases_4;
    wire [7:0] signal_mux_186;
    wire [7:0] signal_wire_105;
    reg [7:0] cmd;
    wire [6:0] addr;
    wire signal_eq_165;
    wire [15:0] tx_word;
    wire [7:0] signal_select_84;
    wire [1:0] signal_const_406;
    reg [1:0] signal_cases_5;
    wire signal_select_85;
    wire [1:0] signal_mux_187;
    wire signal_select_86;
    wire [1:0] signal_mux_188;
    wire [1:0] signal_wire_106;
    (* fsm_encoding="one_hot" *)
    reg [1:0] sm;
    wire [1:0] signal_const_408;
    wire signal_eq_166;
    wire [7:0] signal_mux_189;
    wire signal_wire_107;
    wire signal_wire_108;
    wire signal_wire_109;
    wire signal_wire_110;
    wire signal_wire_111;
    wire [11:0] signal_inst;
    wire signal_select_87;
    assign signal_const = 1'b1;
    assign signal_eq = select == signal_const;
    assign signal_select = value[5:5];
    assign signal_const_1 = 7'b0000000;
    assign signal_eq_1 = addr == signal_const_1;
    assign signal_and = write & signal_eq_1;
    assign signal_and_1 = signal_and & signal_select;
    assign signal_and_2 = signal_and_1 & signal_eq;
    assign signal_eq_2 = select == signal_const;
    assign signal_select_1 = value[4:4];
    assign signal_eq_3 = addr == signal_const_1;
    assign signal_and_3 = write & signal_eq_3;
    assign signal_and_4 = signal_and_3 & signal_select_1;
    assign signal_and_5 = signal_and_4 & signal_eq_2;
    assign signal_eq_4 = select == signal_const;
    assign signal_select_2 = value[3:3];
    assign signal_eq_5 = addr == signal_const_1;
    assign signal_and_6 = write & signal_eq_5;
    assign signal_and_7 = signal_and_6 & signal_select_2;
    assign signal_and_8 = signal_and_7 & signal_eq_4;
    assign signal_eq_6 = select == signal_const;
    assign signal_select_3 = value[2:2];
    assign signal_eq_7 = addr == signal_const_1;
    assign signal_and_9 = write & signal_eq_7;
    assign signal_and_10 = signal_and_9 & signal_select_3;
    assign signal_and_11 = signal_and_10 & signal_eq_6;
    assign signal_eq_8 = select == signal_const;
    assign signal_select_4 = value[1:1];
    assign signal_eq_9 = addr == signal_const_1;
    assign signal_and_12 = write & signal_eq_9;
    assign signal_and_13 = signal_and_12 & signal_select_4;
    assign signal_and_14 = signal_and_13 & signal_eq_8;
    assign signal_eq_10 = select == signal_const;
    assign signal_const_11 = 7'b0001000;
    assign signal_eq_11 = addr == signal_const_11;
    assign signal_and_15 = read_done & signal_eq_11;
    assign signal_and_16 = signal_and_15 & signal_eq_10;
    assign signal_eq_12 = select == signal_const;
    assign signal_const_13 = 7'b0000111;
    assign signal_eq_13 = addr == signal_const_13;
    assign signal_and_17 = write & signal_eq_13;
    assign signal_and_18 = signal_and_17 & signal_eq_12;
    assign signal_eq_14 = select == signal_const;
    assign signal_const_15 = 7'b0001101;
    assign signal_eq_15 = addr == signal_const_15;
    assign signal_and_19 = write & signal_eq_15;
    assign signal_and_20 = signal_and_19 & signal_eq_14;
    assign signal_eq_16 = select == signal_const;
    assign signal_const_17 = 7'b0001010;
    assign signal_eq_17 = addr == signal_const_17;
    assign signal_and_21 = write & signal_eq_17;
    assign signal_and_22 = signal_and_21 & signal_eq_16;
    assign signal_eq_18 = select == signal_const;
    assign signal_select_5 = value[0:0];
    assign signal_eq_19 = addr == signal_const_1;
    assign signal_and_23 = write & signal_eq_19;
    assign signal_and_24 = signal_and_23 & signal_select_5;
    assign signal_and_25 = signal_and_24 & signal_eq_18;
    assign signal_const_20 = 1'b0;
    assign signal_eq_20 = select == signal_const_20;
    assign signal_select_6 = value[5:5];
    assign signal_eq_21 = addr == signal_const_1;
    assign signal_and_26 = write & signal_eq_21;
    assign signal_and_27 = signal_and_26 & signal_select_6;
    assign signal_and_28 = signal_and_27 & signal_eq_20;
    assign signal_eq_22 = select == signal_const_20;
    assign signal_select_7 = value[4:4];
    assign signal_eq_23 = addr == signal_const_1;
    assign signal_and_29 = write & signal_eq_23;
    assign signal_and_30 = signal_and_29 & signal_select_7;
    assign signal_and_31 = signal_and_30 & signal_eq_22;
    assign signal_eq_24 = select == signal_const_20;
    assign signal_select_8 = value[3:3];
    assign signal_eq_25 = addr == signal_const_1;
    assign signal_and_32 = write & signal_eq_25;
    assign signal_and_33 = signal_and_32 & signal_select_8;
    assign signal_and_34 = signal_and_33 & signal_eq_24;
    assign signal_eq_26 = select == signal_const_20;
    assign signal_select_9 = value[2:2];
    assign signal_eq_27 = addr == signal_const_1;
    assign signal_and_35 = write & signal_eq_27;
    assign signal_and_36 = signal_and_35 & signal_select_9;
    assign signal_and_37 = signal_and_36 & signal_eq_26;
    assign signal_eq_28 = select == signal_const_20;
    assign signal_select_10 = value[1:1];
    assign signal_eq_29 = addr == signal_const_1;
    assign signal_and_38 = write & signal_eq_29;
    assign signal_and_39 = signal_and_38 & signal_select_10;
    assign signal_and_40 = signal_and_39 & signal_eq_28;
    assign signal_eq_30 = select == signal_const_20;
    assign signal_eq_31 = addr == signal_const_11;
    assign signal_and_41 = read_done & signal_eq_31;
    assign signal_and_42 = signal_and_41 & signal_eq_30;
    assign signal_eq_32 = select == signal_const_20;
    assign signal_eq_33 = addr == signal_const_13;
    assign signal_and_43 = write & signal_eq_33;
    assign signal_and_44 = signal_and_43 & signal_eq_32;
    assign signal_eq_34 = select == signal_const_20;
    assign signal_eq_35 = addr == signal_const_15;
    assign signal_and_45 = write & signal_eq_35;
    assign signal_and_46 = signal_and_45 & signal_eq_34;
    assign signal_eq_36 = select == signal_const_20;
    assign signal_eq_37 = addr == signal_const_17;
    assign signal_and_47 = write & signal_eq_37;
    assign signal_and_48 = signal_and_47 & signal_eq_36;
    assign signal_eq_38 = select == signal_const_20;
    assign signal_select_11 = value[0:0];
    assign signal_eq_39 = addr == signal_const_1;
    assign signal_and_49 = write & signal_eq_39;
    assign signal_and_50 = signal_and_49 & signal_select_11;
    assign signal_and_51 = signal_and_50 & signal_eq_38;
    assign signal_select_12 = tx_word[7:0];
    assign signal_const_40 = 16'b0000000000000000;
    assign signal_const_42 = 15'b000000000000000;
    assign signal_cat = { signal_const_42,
                          signal_mux_4 };
    assign signal_cat_1 = { signal_const_1,
                            signal_mux_9 };
    assign signal_cat_2 = { signal_const_42,
                            signal_mux_14 };
    assign signal_cat_3 = { signal_const_1,
                            signal_mux_24 };
    assign signal_cat_4 = { signal_const_1,
                            signal_mux_29 };
    assign signal_cat_5 = { signal_const_42,
                            signal_mux_34 };
    assign signal_const_55 = 11'b00000000000;
    assign signal_cat_6 = { signal_const_55,
                            signal_mux_39 };
    assign signal_cat_7 = { signal_const_42,
                            signal_mux_44 };
    assign signal_cat_8 = { signal_const_55,
                            signal_mux_59 };
    assign signal_cat_9 = { signal_const_55,
                            signal_mux_64 };
    assign signal_cat_10 = { signal_const_42,
                             signal_mux_69 };
    assign signal_cat_11 = { signal_const_55,
                             signal_mux_74 };
    assign signal_cat_12 = { signal_const_42,
                             signal_mux_79 };
    assign signal_cat_13 = { signal_const_42,
                             signal_mux_84 };
    assign signal_cat_14 = { signal_const_42,
                             signal_mux_89 };
    assign signal_cat_15 = { signal_const_42,
                             signal_mux_94 };
    assign signal_cat_16 = { signal_const_55,
                             signal_mux_99 };
    assign signal_cat_17 = { signal_const_55,
                             signal_mux_104 };
    assign signal_const_81 = 13'b0000000000000;
    assign signal_cat_18 = { signal_const_81,
                             signal_mux_109 };
    assign signal_cat_19 = { signal_const_55,
                             signal_mux_114 };
    assign signal_cat_20 = { signal_const_55,
                             signal_mux_119 };
    assign signal_cat_21 = { signal_const_55,
                             signal_mux_124 };
    assign signal_cat_22 = { signal_const_55,
                             signal_mux_129 };
    assign signal_cat_23 = { signal_const_55,
                             signal_mux_134 };
    assign signal_cat_24 = { signal_const_42,
                             signal_mux_139 };
    assign signal_cat_25 = { signal_const_55,
                             signal_mux_144 };
    assign signal_const_97 = 14'b00000000000000;
    assign signal_cat_26 = { signal_const_97,
                             signal_mux_149 };
    assign signal_cat_27 = { signal_const_42,
                             select };
    assign signal_const_101 = 3'b000;
    assign signal_cat_28 = { signal_const_101,
                             signal_mux_150 };
    assign signal_cat_29 = { signal_mux_151,
                             signal_cat_28 };
    assign signal_cat_30 = { signal_const_101,
                             signal_cat_29 };
    assign signal_select_13 = signal_mux_154[23:16];
    assign signal_const_106 = 8'b00000000;
    assign signal_cat_31 = { signal_const_106,
                             signal_select_13 };
    assign signal_select_14 = signal_mux_154[15:0];
    assign signal_cat_32 = { signal_const_1,
                             data_addr };
    assign signal_cat_33 = { signal_const_1,
                             program_addr };
    assign signal_select_15 = signal_mux_165[23:16];
    assign signal_cat_34 = { signal_const_106,
                             signal_select_15 };
    assign signal_select_16 = signal_mux_165[15:0];
    assign signal_select_17 = signal_mux_166[23:16];
    assign signal_cat_35 = { signal_const_106,
                             signal_select_17 };
    assign signal_select_18 = signal_mux_166[15:0];
    assign signal_cat_36 = { signal_const_1,
                             signal_mux_167 };
    always @* begin
        case (addr)
        7'b0000001:
            read_value <= signal_cat_74;
        7'b0000010:
            read_value <= signal_cat_36;
        7'b0000011:
            read_value <= signal_select_18;
        7'b0000100:
            read_value <= signal_cat_35;
        7'b0000101:
            read_value <= signal_select_16;
        7'b0000110:
            read_value <= signal_cat_34;
        7'b0001000:
            read_value <= signal_mux_164;
        7'b0001001:
            read_value <= signal_cat_33;
        7'b0001100:
            read_value <= signal_cat_32;
        7'b1000000:
            read_value <= signal_mux_157;
        7'b1000001:
            read_value <= signal_mux_156;
        7'b1000010:
            read_value <= signal_mux_155;
        7'b1000011:
            read_value <= signal_select_14;
        7'b1000100:
            read_value <= signal_cat_31;
        7'b1000101:
            read_value <= signal_mux_153;
        7'b1000110:
            read_value <= signal_mux_152;
        7'b1000111:
            read_value <= signal_cat_30;
        7'b0001011:
            read_value <= signal_cat_27;
        7'b0010000:
            read_value <= signal_cat_26;
        7'b0010001:
            read_value <= signal_cat_25;
        7'b0010010:
            read_value <= signal_cat_24;
        7'b0010011:
            read_value <= signal_cat_23;
        7'b0010100:
            read_value <= signal_cat_22;
        7'b0010101:
            read_value <= signal_cat_21;
        7'b0010110:
            read_value <= signal_cat_20;
        7'b0010111:
            read_value <= signal_cat_19;
        7'b0011000:
            read_value <= signal_cat_18;
        7'b0011001:
            read_value <= signal_cat_17;
        7'b0011010:
            read_value <= signal_cat_16;
        7'b0011011:
            read_value <= signal_cat_15;
        7'b0011100:
            read_value <= signal_cat_14;
        7'b0011101:
            read_value <= signal_cat_13;
        7'b0011110:
            read_value <= signal_cat_12;
        7'b0011111:
            read_value <= signal_cat_11;
        7'b0100000:
            read_value <= signal_cat_10;
        7'b0100001:
            read_value <= signal_cat_9;
        7'b0100010:
            read_value <= signal_cat_8;
        7'b0100011:
            read_value <= signal_mux_54;
        7'b0100100:
            read_value <= signal_mux_49;
        7'b0100101:
            read_value <= signal_cat_7;
        7'b0100110:
            read_value <= signal_cat_6;
        7'b0100111:
            read_value <= signal_cat_5;
        7'b0101000:
            read_value <= signal_cat_4;
        7'b0101001:
            read_value <= signal_cat_3;
        7'b0101010:
            read_value <= signal_mux_19;
        7'b0101011:
            read_value <= signal_cat_2;
        7'b0101100:
            read_value <= signal_cat_1;
        7'b0101101:
            read_value <= signal_cat;
        default:
            read_value <= signal_const_40;
        endcase
    end
    assign signal_select_19 = value[0:0];
    assign signal_eq_40 = select == signal_const;
    assign signal_const_129 = 7'b0101101;
    assign signal_eq_41 = addr == signal_const_129;
    assign signal_and_52 = signal_eq_41 & signal_eq_40;
    assign signal_and_53 = signal_and_52 & signal_wire_86;
    assign signal_mux = signal_and_53 ? signal_select_19 : signal_reg;
    assign signal_mux_1 = write ? signal_mux : signal_reg;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg <= signal_const_20;
        else
            signal_reg <= signal_wire;
    end
    assign signal_select_20 = value[0:0];
    assign signal_eq_42 = select == signal_const_20;
    assign signal_eq_43 = addr == signal_const_129;
    assign signal_and_54 = signal_eq_43 & signal_eq_42;
    assign signal_and_55 = signal_and_54 & signal_wire_87;
    assign signal_mux_2 = signal_and_55 ? signal_select_20 : signal_reg_1;
    assign signal_mux_3 = write ? signal_mux_2 : signal_reg_1;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_1 <= signal_const_20;
        else
            signal_reg_1 <= signal_wire_1;
    end
    assign signal_mux_4 = select ? signal_reg : signal_reg_1;
    assign signal_cat_37 = { signal_const_42,
                             signal_mux_4 };
    assign signal_const_135 = 9'b000000000;
    assign signal_select_21 = value[8:0];
    assign signal_eq_44 = select == signal_const;
    assign signal_const_137 = 7'b0101100;
    assign signal_eq_45 = addr == signal_const_137;
    assign signal_and_56 = signal_eq_45 & signal_eq_44;
    assign signal_and_57 = signal_and_56 & signal_wire_86;
    assign signal_mux_5 = signal_and_57 ? signal_select_21 : signal_reg_2;
    assign signal_mux_6 = write ? signal_mux_5 : signal_reg_2;
    assign signal_wire_2 = signal_mux_6;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_2 <= signal_const_135;
        else
            signal_reg_2 <= signal_wire_2;
    end
    assign signal_select_22 = value[8:0];
    assign signal_eq_46 = select == signal_const_20;
    assign signal_eq_47 = addr == signal_const_137;
    assign signal_and_58 = signal_eq_47 & signal_eq_46;
    assign signal_and_59 = signal_and_58 & signal_wire_87;
    assign signal_mux_7 = signal_and_59 ? signal_select_22 : signal_reg_3;
    assign signal_mux_8 = write ? signal_mux_7 : signal_reg_3;
    assign signal_wire_3 = signal_mux_8;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_3 <= signal_const_135;
        else
            signal_reg_3 <= signal_wire_3;
    end
    assign signal_mux_9 = select ? signal_reg_2 : signal_reg_3;
    assign signal_cat_38 = { signal_const_1,
                             signal_mux_9 };
    assign signal_select_23 = value[0:0];
    assign signal_eq_48 = select == signal_const;
    assign signal_const_145 = 7'b0101011;
    assign signal_eq_49 = addr == signal_const_145;
    assign signal_and_60 = signal_eq_49 & signal_eq_48;
    assign signal_and_61 = signal_and_60 & signal_wire_86;
    assign signal_mux_10 = signal_and_61 ? signal_select_23 : signal_reg_4;
    assign signal_mux_11 = write ? signal_mux_10 : signal_reg_4;
    assign signal_wire_4 = signal_mux_11;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_4 <= signal_const_20;
        else
            signal_reg_4 <= signal_wire_4;
    end
    assign signal_select_24 = value[0:0];
    assign signal_eq_50 = select == signal_const_20;
    assign signal_eq_51 = addr == signal_const_145;
    assign signal_and_62 = signal_eq_51 & signal_eq_50;
    assign signal_and_63 = signal_and_62 & signal_wire_87;
    assign signal_mux_12 = signal_and_63 ? signal_select_24 : signal_reg_5;
    assign signal_mux_13 = write ? signal_mux_12 : signal_reg_5;
    assign signal_wire_5 = signal_mux_13;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_5 <= signal_const_20;
        else
            signal_reg_5 <= signal_wire_5;
    end
    assign signal_mux_14 = select ? signal_reg_4 : signal_reg_5;
    assign signal_cat_39 = { signal_const_42,
                             signal_mux_14 };
    assign signal_eq_52 = select == signal_const;
    assign signal_const_153 = 7'b0101010;
    assign signal_eq_53 = addr == signal_const_153;
    assign signal_and_64 = signal_eq_53 & signal_eq_52;
    assign signal_and_65 = signal_and_64 & signal_wire_86;
    assign signal_mux_15 = signal_and_65 ? value : signal_reg_6;
    assign signal_mux_16 = write ? signal_mux_15 : signal_reg_6;
    assign signal_wire_6 = signal_mux_16;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_6 <= signal_const_40;
        else
            signal_reg_6 <= signal_wire_6;
    end
    assign signal_eq_54 = select == signal_const_20;
    assign signal_eq_55 = addr == signal_const_153;
    assign signal_and_66 = signal_eq_55 & signal_eq_54;
    assign signal_and_67 = signal_and_66 & signal_wire_87;
    assign signal_mux_17 = signal_and_67 ? value : signal_reg_7;
    assign signal_mux_18 = write ? signal_mux_17 : signal_reg_7;
    assign signal_wire_7 = signal_mux_18;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_7 <= signal_const_40;
        else
            signal_reg_7 <= signal_wire_7;
    end
    assign signal_mux_19 = select ? signal_reg_6 : signal_reg_7;
    assign signal_select_25 = value[8:0];
    assign signal_eq_56 = select == signal_const;
    assign signal_const_160 = 7'b0101001;
    assign signal_eq_57 = addr == signal_const_160;
    assign signal_and_68 = signal_eq_57 & signal_eq_56;
    assign signal_and_69 = signal_and_68 & signal_wire_86;
    assign signal_mux_20 = signal_and_69 ? signal_select_25 : signal_reg_8;
    assign signal_mux_21 = write ? signal_mux_20 : signal_reg_8;
    assign signal_wire_8 = signal_mux_21;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_8 <= signal_const_135;
        else
            signal_reg_8 <= signal_wire_8;
    end
    assign signal_select_26 = value[8:0];
    assign signal_eq_58 = select == signal_const_20;
    assign signal_eq_59 = addr == signal_const_160;
    assign signal_and_70 = signal_eq_59 & signal_eq_58;
    assign signal_and_71 = signal_and_70 & signal_wire_87;
    assign signal_mux_22 = signal_and_71 ? signal_select_26 : signal_reg_9;
    assign signal_mux_23 = write ? signal_mux_22 : signal_reg_9;
    assign signal_wire_9 = signal_mux_23;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_9 <= signal_const_135;
        else
            signal_reg_9 <= signal_wire_9;
    end
    assign signal_mux_24 = select ? signal_reg_8 : signal_reg_9;
    assign signal_cat_40 = { signal_const_1,
                             signal_mux_24 };
    assign signal_select_27 = value[8:0];
    assign signal_eq_60 = select == signal_const;
    assign signal_const_168 = 7'b0101000;
    assign signal_eq_61 = addr == signal_const_168;
    assign signal_and_72 = signal_eq_61 & signal_eq_60;
    assign signal_and_73 = signal_and_72 & signal_wire_86;
    assign signal_mux_25 = signal_and_73 ? signal_select_27 : signal_reg_10;
    assign signal_mux_26 = write ? signal_mux_25 : signal_reg_10;
    assign signal_wire_10 = signal_mux_26;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_10 <= signal_const_135;
        else
            signal_reg_10 <= signal_wire_10;
    end
    assign signal_select_28 = value[8:0];
    assign signal_eq_62 = select == signal_const_20;
    assign signal_eq_63 = addr == signal_const_168;
    assign signal_and_74 = signal_eq_63 & signal_eq_62;
    assign signal_and_75 = signal_and_74 & signal_wire_87;
    assign signal_mux_27 = signal_and_75 ? signal_select_28 : signal_reg_11;
    assign signal_mux_28 = write ? signal_mux_27 : signal_reg_11;
    assign signal_wire_11 = signal_mux_28;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_11 <= signal_const_135;
        else
            signal_reg_11 <= signal_wire_11;
    end
    assign signal_mux_29 = select ? signal_reg_10 : signal_reg_11;
    assign signal_cat_41 = { signal_const_1,
                             signal_mux_29 };
    assign signal_select_29 = value[0:0];
    assign signal_eq_64 = select == signal_const;
    assign signal_const_176 = 7'b0100111;
    assign signal_eq_65 = addr == signal_const_176;
    assign signal_and_76 = signal_eq_65 & signal_eq_64;
    assign signal_and_77 = signal_and_76 & signal_wire_86;
    assign signal_mux_30 = signal_and_77 ? signal_select_29 : signal_reg_12;
    assign signal_mux_31 = write ? signal_mux_30 : signal_reg_12;
    assign signal_wire_12 = signal_mux_31;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_12 <= signal_const_20;
        else
            signal_reg_12 <= signal_wire_12;
    end
    assign signal_select_30 = value[0:0];
    assign signal_eq_66 = select == signal_const_20;
    assign signal_eq_67 = addr == signal_const_176;
    assign signal_and_78 = signal_eq_67 & signal_eq_66;
    assign signal_and_79 = signal_and_78 & signal_wire_87;
    assign signal_mux_32 = signal_and_79 ? signal_select_30 : signal_reg_13;
    assign signal_mux_33 = write ? signal_mux_32 : signal_reg_13;
    assign signal_wire_13 = signal_mux_33;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_13 <= signal_const_20;
        else
            signal_reg_13 <= signal_wire_13;
    end
    assign signal_mux_34 = select ? signal_reg_12 : signal_reg_13;
    assign signal_cat_42 = { signal_const_42,
                             signal_mux_34 };
    assign signal_const_182 = 5'b00000;
    assign signal_select_31 = value[4:0];
    assign signal_eq_68 = select == signal_const;
    assign signal_const_184 = 7'b0100110;
    assign signal_eq_69 = addr == signal_const_184;
    assign signal_and_80 = signal_eq_69 & signal_eq_68;
    assign signal_and_81 = signal_and_80 & signal_wire_86;
    assign signal_mux_35 = signal_and_81 ? signal_select_31 : signal_reg_14;
    assign signal_mux_36 = write ? signal_mux_35 : signal_reg_14;
    assign signal_wire_14 = signal_mux_36;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_14 <= signal_const_182;
        else
            signal_reg_14 <= signal_wire_14;
    end
    assign signal_select_32 = value[4:0];
    assign signal_eq_70 = select == signal_const_20;
    assign signal_eq_71 = addr == signal_const_184;
    assign signal_and_82 = signal_eq_71 & signal_eq_70;
    assign signal_and_83 = signal_and_82 & signal_wire_87;
    assign signal_mux_37 = signal_and_83 ? signal_select_32 : signal_reg_15;
    assign signal_mux_38 = write ? signal_mux_37 : signal_reg_15;
    assign signal_wire_15 = signal_mux_38;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_15 <= signal_const_182;
        else
            signal_reg_15 <= signal_wire_15;
    end
    assign signal_mux_39 = select ? signal_reg_14 : signal_reg_15;
    assign signal_cat_43 = { signal_const_55,
                             signal_mux_39 };
    assign signal_select_33 = value[0:0];
    assign signal_eq_72 = select == signal_const;
    assign signal_const_192 = 7'b0100101;
    assign signal_eq_73 = addr == signal_const_192;
    assign signal_and_84 = signal_eq_73 & signal_eq_72;
    assign signal_and_85 = signal_and_84 & signal_wire_86;
    assign signal_mux_40 = signal_and_85 ? signal_select_33 : signal_reg_16;
    assign signal_mux_41 = write ? signal_mux_40 : signal_reg_16;
    assign signal_wire_16 = signal_mux_41;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_16 <= signal_const_20;
        else
            signal_reg_16 <= signal_wire_16;
    end
    assign signal_select_34 = value[0:0];
    assign signal_eq_74 = select == signal_const_20;
    assign signal_eq_75 = addr == signal_const_192;
    assign signal_and_86 = signal_eq_75 & signal_eq_74;
    assign signal_and_87 = signal_and_86 & signal_wire_87;
    assign signal_mux_42 = signal_and_87 ? signal_select_34 : signal_reg_17;
    assign signal_mux_43 = write ? signal_mux_42 : signal_reg_17;
    assign signal_wire_17 = signal_mux_43;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_17 <= signal_const_20;
        else
            signal_reg_17 <= signal_wire_17;
    end
    assign signal_mux_44 = select ? signal_reg_16 : signal_reg_17;
    assign signal_cat_44 = { signal_const_42,
                             signal_mux_44 };
    assign signal_eq_76 = select == signal_const;
    assign signal_const_200 = 7'b0100100;
    assign signal_eq_77 = addr == signal_const_200;
    assign signal_and_88 = signal_eq_77 & signal_eq_76;
    assign signal_and_89 = signal_and_88 & signal_wire_86;
    assign signal_mux_45 = signal_and_89 ? value : signal_reg_18;
    assign signal_mux_46 = write ? signal_mux_45 : signal_reg_18;
    assign signal_wire_18 = signal_mux_46;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_18 <= signal_const_40;
        else
            signal_reg_18 <= signal_wire_18;
    end
    assign signal_eq_78 = select == signal_const_20;
    assign signal_eq_79 = addr == signal_const_200;
    assign signal_and_90 = signal_eq_79 & signal_eq_78;
    assign signal_and_91 = signal_and_90 & signal_wire_87;
    assign signal_mux_47 = signal_and_91 ? value : signal_reg_19;
    assign signal_mux_48 = write ? signal_mux_47 : signal_reg_19;
    assign signal_wire_19 = signal_mux_48;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_19 <= signal_const_40;
        else
            signal_reg_19 <= signal_wire_19;
    end
    assign signal_mux_49 = select ? signal_reg_18 : signal_reg_19;
    assign signal_eq_80 = select == signal_const;
    assign signal_const_207 = 7'b0100011;
    assign signal_eq_81 = addr == signal_const_207;
    assign signal_and_92 = signal_eq_81 & signal_eq_80;
    assign signal_and_93 = signal_and_92 & signal_wire_86;
    assign signal_mux_50 = signal_and_93 ? value : signal_reg_20;
    assign signal_mux_51 = write ? signal_mux_50 : signal_reg_20;
    assign signal_wire_20 = signal_mux_51;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_20 <= signal_const_40;
        else
            signal_reg_20 <= signal_wire_20;
    end
    assign signal_eq_82 = select == signal_const_20;
    assign signal_eq_83 = addr == signal_const_207;
    assign signal_and_94 = signal_eq_83 & signal_eq_82;
    assign signal_and_95 = signal_and_94 & signal_wire_87;
    assign signal_mux_52 = signal_and_95 ? value : signal_reg_21;
    assign signal_mux_53 = write ? signal_mux_52 : signal_reg_21;
    assign signal_wire_21 = signal_mux_53;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_21 <= signal_const_40;
        else
            signal_reg_21 <= signal_wire_21;
    end
    assign signal_mux_54 = select ? signal_reg_20 : signal_reg_21;
    assign signal_select_35 = value[4:0];
    assign signal_eq_84 = select == signal_const;
    assign signal_const_214 = 7'b0100010;
    assign signal_eq_85 = addr == signal_const_214;
    assign signal_and_96 = signal_eq_85 & signal_eq_84;
    assign signal_and_97 = signal_and_96 & signal_wire_86;
    assign signal_mux_55 = signal_and_97 ? signal_select_35 : signal_reg_22;
    assign signal_mux_56 = write ? signal_mux_55 : signal_reg_22;
    assign signal_wire_22 = signal_mux_56;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_22 <= signal_const_182;
        else
            signal_reg_22 <= signal_wire_22;
    end
    assign signal_select_36 = value[4:0];
    assign signal_eq_86 = select == signal_const_20;
    assign signal_eq_87 = addr == signal_const_214;
    assign signal_and_98 = signal_eq_87 & signal_eq_86;
    assign signal_and_99 = signal_and_98 & signal_wire_87;
    assign signal_mux_57 = signal_and_99 ? signal_select_36 : signal_reg_23;
    assign signal_mux_58 = write ? signal_mux_57 : signal_reg_23;
    assign signal_wire_23 = signal_mux_58;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_23 <= signal_const_182;
        else
            signal_reg_23 <= signal_wire_23;
    end
    assign signal_mux_59 = select ? signal_reg_22 : signal_reg_23;
    assign signal_cat_45 = { signal_const_55,
                             signal_mux_59 };
    assign signal_select_37 = value[4:0];
    assign signal_eq_88 = select == signal_const;
    assign signal_const_222 = 7'b0100001;
    assign signal_eq_89 = addr == signal_const_222;
    assign signal_and_100 = signal_eq_89 & signal_eq_88;
    assign signal_and_101 = signal_and_100 & signal_wire_86;
    assign signal_mux_60 = signal_and_101 ? signal_select_37 : signal_reg_24;
    assign signal_mux_61 = write ? signal_mux_60 : signal_reg_24;
    assign signal_wire_24 = signal_mux_61;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_24 <= signal_const_182;
        else
            signal_reg_24 <= signal_wire_24;
    end
    assign signal_select_38 = value[4:0];
    assign signal_eq_90 = select == signal_const_20;
    assign signal_eq_91 = addr == signal_const_222;
    assign signal_and_102 = signal_eq_91 & signal_eq_90;
    assign signal_and_103 = signal_and_102 & signal_wire_87;
    assign signal_mux_62 = signal_and_103 ? signal_select_38 : signal_reg_25;
    assign signal_mux_63 = write ? signal_mux_62 : signal_reg_25;
    assign signal_wire_25 = signal_mux_63;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_25 <= signal_const_182;
        else
            signal_reg_25 <= signal_wire_25;
    end
    assign signal_mux_64 = select ? signal_reg_24 : signal_reg_25;
    assign signal_cat_46 = { signal_const_55,
                             signal_mux_64 };
    assign signal_select_39 = value[0:0];
    assign signal_eq_92 = select == signal_const;
    assign signal_const_230 = 7'b0100000;
    assign signal_eq_93 = addr == signal_const_230;
    assign signal_and_104 = signal_eq_93 & signal_eq_92;
    assign signal_and_105 = signal_and_104 & signal_wire_86;
    assign signal_mux_65 = signal_and_105 ? signal_select_39 : signal_reg_26;
    assign signal_mux_66 = write ? signal_mux_65 : signal_reg_26;
    assign signal_wire_26 = signal_mux_66;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_26 <= signal_const_20;
        else
            signal_reg_26 <= signal_wire_26;
    end
    assign signal_select_40 = value[0:0];
    assign signal_eq_94 = select == signal_const_20;
    assign signal_eq_95 = addr == signal_const_230;
    assign signal_and_106 = signal_eq_95 & signal_eq_94;
    assign signal_and_107 = signal_and_106 & signal_wire_87;
    assign signal_mux_67 = signal_and_107 ? signal_select_40 : signal_reg_27;
    assign signal_mux_68 = write ? signal_mux_67 : signal_reg_27;
    assign signal_wire_27 = signal_mux_68;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_27 <= signal_const_20;
        else
            signal_reg_27 <= signal_wire_27;
    end
    assign signal_mux_69 = select ? signal_reg_26 : signal_reg_27;
    assign signal_cat_47 = { signal_const_42,
                             signal_mux_69 };
    assign signal_select_41 = value[4:0];
    assign signal_eq_96 = select == signal_const;
    assign signal_const_238 = 7'b0011111;
    assign signal_eq_97 = addr == signal_const_238;
    assign signal_and_108 = signal_eq_97 & signal_eq_96;
    assign signal_and_109 = signal_and_108 & signal_wire_86;
    assign signal_mux_70 = signal_and_109 ? signal_select_41 : signal_reg_28;
    assign signal_mux_71 = write ? signal_mux_70 : signal_reg_28;
    assign signal_wire_28 = signal_mux_71;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_28 <= signal_const_182;
        else
            signal_reg_28 <= signal_wire_28;
    end
    assign signal_select_42 = value[4:0];
    assign signal_eq_98 = select == signal_const_20;
    assign signal_eq_99 = addr == signal_const_238;
    assign signal_and_110 = signal_eq_99 & signal_eq_98;
    assign signal_and_111 = signal_and_110 & signal_wire_87;
    assign signal_mux_72 = signal_and_111 ? signal_select_42 : signal_reg_29;
    assign signal_mux_73 = write ? signal_mux_72 : signal_reg_29;
    assign signal_wire_29 = signal_mux_73;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_29 <= signal_const_182;
        else
            signal_reg_29 <= signal_wire_29;
    end
    assign signal_mux_74 = select ? signal_reg_28 : signal_reg_29;
    assign signal_cat_48 = { signal_const_55,
                             signal_mux_74 };
    assign signal_select_43 = value[0:0];
    assign signal_eq_100 = select == signal_const;
    assign signal_const_246 = 7'b0011110;
    assign signal_eq_101 = addr == signal_const_246;
    assign signal_and_112 = signal_eq_101 & signal_eq_100;
    assign signal_and_113 = signal_and_112 & signal_wire_86;
    assign signal_mux_75 = signal_and_113 ? signal_select_43 : signal_reg_30;
    assign signal_mux_76 = write ? signal_mux_75 : signal_reg_30;
    assign signal_wire_30 = signal_mux_76;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_30 <= signal_const_20;
        else
            signal_reg_30 <= signal_wire_30;
    end
    assign signal_select_44 = value[0:0];
    assign signal_eq_102 = select == signal_const_20;
    assign signal_eq_103 = addr == signal_const_246;
    assign signal_and_114 = signal_eq_103 & signal_eq_102;
    assign signal_and_115 = signal_and_114 & signal_wire_87;
    assign signal_mux_77 = signal_and_115 ? signal_select_44 : signal_reg_31;
    assign signal_mux_78 = write ? signal_mux_77 : signal_reg_31;
    assign signal_wire_31 = signal_mux_78;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_31 <= signal_const_20;
        else
            signal_reg_31 <= signal_wire_31;
    end
    assign signal_mux_79 = select ? signal_reg_30 : signal_reg_31;
    assign signal_cat_49 = { signal_const_42,
                             signal_mux_79 };
    assign signal_select_45 = value[0:0];
    assign signal_eq_104 = select == signal_const;
    assign signal_const_254 = 7'b0011101;
    assign signal_eq_105 = addr == signal_const_254;
    assign signal_and_116 = signal_eq_105 & signal_eq_104;
    assign signal_and_117 = signal_and_116 & signal_wire_86;
    assign signal_mux_80 = signal_and_117 ? signal_select_45 : signal_reg_32;
    assign signal_mux_81 = write ? signal_mux_80 : signal_reg_32;
    assign signal_wire_32 = signal_mux_81;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_32 <= signal_const_20;
        else
            signal_reg_32 <= signal_wire_32;
    end
    assign signal_select_46 = value[0:0];
    assign signal_eq_106 = select == signal_const_20;
    assign signal_eq_107 = addr == signal_const_254;
    assign signal_and_118 = signal_eq_107 & signal_eq_106;
    assign signal_and_119 = signal_and_118 & signal_wire_87;
    assign signal_mux_82 = signal_and_119 ? signal_select_46 : signal_reg_33;
    assign signal_mux_83 = write ? signal_mux_82 : signal_reg_33;
    assign signal_wire_33 = signal_mux_83;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_33 <= signal_const_20;
        else
            signal_reg_33 <= signal_wire_33;
    end
    assign signal_mux_84 = select ? signal_reg_32 : signal_reg_33;
    assign signal_cat_50 = { signal_const_42,
                             signal_mux_84 };
    assign signal_select_47 = value[0:0];
    assign signal_eq_108 = select == signal_const;
    assign signal_const_262 = 7'b0011100;
    assign signal_eq_109 = addr == signal_const_262;
    assign signal_and_120 = signal_eq_109 & signal_eq_108;
    assign signal_and_121 = signal_and_120 & signal_wire_86;
    assign signal_mux_85 = signal_and_121 ? signal_select_47 : signal_reg_34;
    assign signal_mux_86 = write ? signal_mux_85 : signal_reg_34;
    assign signal_wire_34 = signal_mux_86;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_34 <= signal_const_20;
        else
            signal_reg_34 <= signal_wire_34;
    end
    assign signal_select_48 = value[0:0];
    assign signal_eq_110 = select == signal_const_20;
    assign signal_eq_111 = addr == signal_const_262;
    assign signal_and_122 = signal_eq_111 & signal_eq_110;
    assign signal_and_123 = signal_and_122 & signal_wire_87;
    assign signal_mux_87 = signal_and_123 ? signal_select_48 : signal_reg_35;
    assign signal_mux_88 = write ? signal_mux_87 : signal_reg_35;
    assign signal_wire_35 = signal_mux_88;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_35 <= signal_const_20;
        else
            signal_reg_35 <= signal_wire_35;
    end
    assign signal_mux_89 = select ? signal_reg_34 : signal_reg_35;
    assign signal_cat_51 = { signal_const_42,
                             signal_mux_89 };
    assign signal_select_49 = value[0:0];
    assign signal_eq_112 = select == signal_const;
    assign signal_const_270 = 7'b0011011;
    assign signal_eq_113 = addr == signal_const_270;
    assign signal_and_124 = signal_eq_113 & signal_eq_112;
    assign signal_and_125 = signal_and_124 & signal_wire_86;
    assign signal_mux_90 = signal_and_125 ? signal_select_49 : signal_reg_36;
    assign signal_mux_91 = write ? signal_mux_90 : signal_reg_36;
    assign signal_wire_36 = signal_mux_91;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_36 <= signal_const_20;
        else
            signal_reg_36 <= signal_wire_36;
    end
    assign signal_select_50 = value[0:0];
    assign signal_eq_114 = select == signal_const_20;
    assign signal_eq_115 = addr == signal_const_270;
    assign signal_and_126 = signal_eq_115 & signal_eq_114;
    assign signal_and_127 = signal_and_126 & signal_wire_87;
    assign signal_mux_92 = signal_and_127 ? signal_select_50 : signal_reg_37;
    assign signal_mux_93 = write ? signal_mux_92 : signal_reg_37;
    assign signal_wire_37 = signal_mux_93;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_37 <= signal_const_20;
        else
            signal_reg_37 <= signal_wire_37;
    end
    assign signal_mux_94 = select ? signal_reg_36 : signal_reg_37;
    assign signal_cat_52 = { signal_const_42,
                             signal_mux_94 };
    assign signal_select_51 = value[4:0];
    assign signal_eq_116 = select == signal_const;
    assign signal_const_278 = 7'b0011010;
    assign signal_eq_117 = addr == signal_const_278;
    assign signal_and_128 = signal_eq_117 & signal_eq_116;
    assign signal_and_129 = signal_and_128 & signal_wire_86;
    assign signal_mux_95 = signal_and_129 ? signal_select_51 : signal_reg_38;
    assign signal_mux_96 = write ? signal_mux_95 : signal_reg_38;
    assign signal_wire_38 = signal_mux_96;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_38 <= signal_const_182;
        else
            signal_reg_38 <= signal_wire_38;
    end
    assign signal_select_52 = value[4:0];
    assign signal_eq_118 = select == signal_const_20;
    assign signal_eq_119 = addr == signal_const_278;
    assign signal_and_130 = signal_eq_119 & signal_eq_118;
    assign signal_and_131 = signal_and_130 & signal_wire_87;
    assign signal_mux_97 = signal_and_131 ? signal_select_52 : signal_reg_39;
    assign signal_mux_98 = write ? signal_mux_97 : signal_reg_39;
    assign signal_wire_39 = signal_mux_98;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_39 <= signal_const_182;
        else
            signal_reg_39 <= signal_wire_39;
    end
    assign signal_mux_99 = select ? signal_reg_38 : signal_reg_39;
    assign signal_cat_53 = { signal_const_55,
                             signal_mux_99 };
    assign signal_select_53 = value[4:0];
    assign signal_eq_120 = select == signal_const;
    assign signal_const_286 = 7'b0011001;
    assign signal_eq_121 = addr == signal_const_286;
    assign signal_and_132 = signal_eq_121 & signal_eq_120;
    assign signal_and_133 = signal_and_132 & signal_wire_86;
    assign signal_mux_100 = signal_and_133 ? signal_select_53 : signal_reg_40;
    assign signal_mux_101 = write ? signal_mux_100 : signal_reg_40;
    assign signal_wire_40 = signal_mux_101;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_40 <= signal_const_182;
        else
            signal_reg_40 <= signal_wire_40;
    end
    assign signal_select_54 = value[4:0];
    assign signal_eq_122 = select == signal_const_20;
    assign signal_eq_123 = addr == signal_const_286;
    assign signal_and_134 = signal_eq_123 & signal_eq_122;
    assign signal_and_135 = signal_and_134 & signal_wire_87;
    assign signal_mux_102 = signal_and_135 ? signal_select_54 : signal_reg_41;
    assign signal_mux_103 = write ? signal_mux_102 : signal_reg_41;
    assign signal_wire_41 = signal_mux_103;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_41 <= signal_const_182;
        else
            signal_reg_41 <= signal_wire_41;
    end
    assign signal_mux_104 = select ? signal_reg_40 : signal_reg_41;
    assign signal_cat_54 = { signal_const_55,
                             signal_mux_104 };
    assign signal_select_55 = value[2:0];
    assign signal_eq_124 = select == signal_const;
    assign signal_const_294 = 7'b0011000;
    assign signal_eq_125 = addr == signal_const_294;
    assign signal_and_136 = signal_eq_125 & signal_eq_124;
    assign signal_and_137 = signal_and_136 & signal_wire_86;
    assign signal_mux_105 = signal_and_137 ? signal_select_55 : signal_reg_42;
    assign signal_mux_106 = write ? signal_mux_105 : signal_reg_42;
    assign signal_wire_42 = signal_mux_106;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_42 <= signal_const_101;
        else
            signal_reg_42 <= signal_wire_42;
    end
    assign signal_select_56 = value[2:0];
    assign signal_eq_126 = select == signal_const_20;
    assign signal_eq_127 = addr == signal_const_294;
    assign signal_and_138 = signal_eq_127 & signal_eq_126;
    assign signal_and_139 = signal_and_138 & signal_wire_87;
    assign signal_mux_107 = signal_and_139 ? signal_select_56 : signal_reg_43;
    assign signal_mux_108 = write ? signal_mux_107 : signal_reg_43;
    assign signal_wire_43 = signal_mux_108;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_43 <= signal_const_101;
        else
            signal_reg_43 <= signal_wire_43;
    end
    assign signal_mux_109 = select ? signal_reg_42 : signal_reg_43;
    assign signal_cat_55 = { signal_const_81,
                             signal_mux_109 };
    assign signal_select_57 = value[4:0];
    assign signal_eq_128 = select == signal_const;
    assign signal_const_302 = 7'b0010111;
    assign signal_eq_129 = addr == signal_const_302;
    assign signal_and_140 = signal_eq_129 & signal_eq_128;
    assign signal_and_141 = signal_and_140 & signal_wire_86;
    assign signal_mux_110 = signal_and_141 ? signal_select_57 : signal_reg_44;
    assign signal_mux_111 = write ? signal_mux_110 : signal_reg_44;
    assign signal_wire_44 = signal_mux_111;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_44 <= signal_const_182;
        else
            signal_reg_44 <= signal_wire_44;
    end
    assign signal_select_58 = value[4:0];
    assign signal_eq_130 = select == signal_const_20;
    assign signal_eq_131 = addr == signal_const_302;
    assign signal_and_142 = signal_eq_131 & signal_eq_130;
    assign signal_and_143 = signal_and_142 & signal_wire_87;
    assign signal_mux_112 = signal_and_143 ? signal_select_58 : signal_reg_45;
    assign signal_mux_113 = write ? signal_mux_112 : signal_reg_45;
    assign signal_wire_45 = signal_mux_113;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_45 <= signal_const_182;
        else
            signal_reg_45 <= signal_wire_45;
    end
    assign signal_mux_114 = select ? signal_reg_44 : signal_reg_45;
    assign signal_cat_56 = { signal_const_55,
                             signal_mux_114 };
    assign signal_select_59 = value[4:0];
    assign signal_eq_132 = select == signal_const;
    assign signal_const_310 = 7'b0010110;
    assign signal_eq_133 = addr == signal_const_310;
    assign signal_and_144 = signal_eq_133 & signal_eq_132;
    assign signal_and_145 = signal_and_144 & signal_wire_86;
    assign signal_mux_115 = signal_and_145 ? signal_select_59 : signal_reg_46;
    assign signal_mux_116 = write ? signal_mux_115 : signal_reg_46;
    assign signal_wire_46 = signal_mux_116;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_46 <= signal_const_182;
        else
            signal_reg_46 <= signal_wire_46;
    end
    assign signal_select_60 = value[4:0];
    assign signal_eq_134 = select == signal_const_20;
    assign signal_eq_135 = addr == signal_const_310;
    assign signal_and_146 = signal_eq_135 & signal_eq_134;
    assign signal_and_147 = signal_and_146 & signal_wire_87;
    assign signal_mux_117 = signal_and_147 ? signal_select_60 : signal_reg_47;
    assign signal_mux_118 = write ? signal_mux_117 : signal_reg_47;
    assign signal_wire_47 = signal_mux_118;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_47 <= signal_const_182;
        else
            signal_reg_47 <= signal_wire_47;
    end
    assign signal_mux_119 = select ? signal_reg_46 : signal_reg_47;
    assign signal_cat_57 = { signal_const_55,
                             signal_mux_119 };
    assign signal_select_61 = value[4:0];
    assign signal_eq_136 = select == signal_const;
    assign signal_const_318 = 7'b0010101;
    assign signal_eq_137 = addr == signal_const_318;
    assign signal_and_148 = signal_eq_137 & signal_eq_136;
    assign signal_and_149 = signal_and_148 & signal_wire_86;
    assign signal_mux_120 = signal_and_149 ? signal_select_61 : signal_reg_48;
    assign signal_mux_121 = write ? signal_mux_120 : signal_reg_48;
    assign signal_wire_48 = signal_mux_121;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_48 <= signal_const_182;
        else
            signal_reg_48 <= signal_wire_48;
    end
    assign signal_select_62 = value[4:0];
    assign signal_eq_138 = select == signal_const_20;
    assign signal_eq_139 = addr == signal_const_318;
    assign signal_and_150 = signal_eq_139 & signal_eq_138;
    assign signal_and_151 = signal_and_150 & signal_wire_87;
    assign signal_mux_122 = signal_and_151 ? signal_select_62 : signal_reg_49;
    assign signal_mux_123 = write ? signal_mux_122 : signal_reg_49;
    assign signal_wire_49 = signal_mux_123;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_49 <= signal_const_182;
        else
            signal_reg_49 <= signal_wire_49;
    end
    assign signal_mux_124 = select ? signal_reg_48 : signal_reg_49;
    assign signal_cat_58 = { signal_const_55,
                             signal_mux_124 };
    assign signal_select_63 = value[4:0];
    assign signal_eq_140 = select == signal_const;
    assign signal_const_326 = 7'b0010100;
    assign signal_eq_141 = addr == signal_const_326;
    assign signal_and_152 = signal_eq_141 & signal_eq_140;
    assign signal_and_153 = signal_and_152 & signal_wire_86;
    assign signal_mux_125 = signal_and_153 ? signal_select_63 : signal_reg_50;
    assign signal_mux_126 = write ? signal_mux_125 : signal_reg_50;
    assign signal_wire_50 = signal_mux_126;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_50 <= signal_const_182;
        else
            signal_reg_50 <= signal_wire_50;
    end
    assign signal_select_64 = value[4:0];
    assign signal_eq_142 = select == signal_const_20;
    assign signal_eq_143 = addr == signal_const_326;
    assign signal_and_154 = signal_eq_143 & signal_eq_142;
    assign signal_and_155 = signal_and_154 & signal_wire_87;
    assign signal_mux_127 = signal_and_155 ? signal_select_64 : signal_reg_51;
    assign signal_mux_128 = write ? signal_mux_127 : signal_reg_51;
    assign signal_wire_51 = signal_mux_128;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_51 <= signal_const_182;
        else
            signal_reg_51 <= signal_wire_51;
    end
    assign signal_mux_129 = select ? signal_reg_50 : signal_reg_51;
    assign signal_cat_59 = { signal_const_55,
                             signal_mux_129 };
    assign signal_select_65 = value[4:0];
    assign signal_eq_144 = select == signal_const;
    assign signal_const_334 = 7'b0010011;
    assign signal_eq_145 = addr == signal_const_334;
    assign signal_and_156 = signal_eq_145 & signal_eq_144;
    assign signal_and_157 = signal_and_156 & signal_wire_86;
    assign signal_mux_130 = signal_and_157 ? signal_select_65 : signal_reg_52;
    assign signal_mux_131 = write ? signal_mux_130 : signal_reg_52;
    assign signal_wire_52 = signal_mux_131;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_52 <= signal_const_182;
        else
            signal_reg_52 <= signal_wire_52;
    end
    assign signal_select_66 = value[4:0];
    assign signal_eq_146 = select == signal_const_20;
    assign signal_eq_147 = addr == signal_const_334;
    assign signal_and_158 = signal_eq_147 & signal_eq_146;
    assign signal_and_159 = signal_and_158 & signal_wire_87;
    assign signal_mux_132 = signal_and_159 ? signal_select_66 : signal_reg_53;
    assign signal_mux_133 = write ? signal_mux_132 : signal_reg_53;
    assign signal_wire_53 = signal_mux_133;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_53 <= signal_const_182;
        else
            signal_reg_53 <= signal_wire_53;
    end
    assign signal_mux_134 = select ? signal_reg_52 : signal_reg_53;
    assign signal_cat_60 = { signal_const_55,
                             signal_mux_134 };
    assign signal_select_67 = value[0:0];
    assign signal_eq_148 = select == signal_const;
    assign signal_const_342 = 7'b0010010;
    assign signal_eq_149 = addr == signal_const_342;
    assign signal_and_160 = signal_eq_149 & signal_eq_148;
    assign signal_and_161 = signal_and_160 & signal_wire_86;
    assign signal_mux_135 = signal_and_161 ? signal_select_67 : signal_reg_54;
    assign signal_mux_136 = write ? signal_mux_135 : signal_reg_54;
    assign signal_wire_54 = signal_mux_136;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_54 <= signal_const_20;
        else
            signal_reg_54 <= signal_wire_54;
    end
    assign signal_select_68 = value[0:0];
    assign signal_eq_150 = select == signal_const_20;
    assign signal_eq_151 = addr == signal_const_342;
    assign signal_and_162 = signal_eq_151 & signal_eq_150;
    assign signal_and_163 = signal_and_162 & signal_wire_87;
    assign signal_mux_137 = signal_and_163 ? signal_select_68 : signal_reg_55;
    assign signal_mux_138 = write ? signal_mux_137 : signal_reg_55;
    assign signal_wire_55 = signal_mux_138;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_55 <= signal_const_20;
        else
            signal_reg_55 <= signal_wire_55;
    end
    assign signal_mux_139 = select ? signal_reg_54 : signal_reg_55;
    assign signal_cat_61 = { signal_const_42,
                             signal_mux_139 };
    assign signal_select_69 = value[4:0];
    assign signal_eq_152 = select == signal_const;
    assign signal_const_350 = 7'b0010001;
    assign signal_eq_153 = addr == signal_const_350;
    assign signal_and_164 = signal_eq_153 & signal_eq_152;
    assign signal_and_165 = signal_and_164 & signal_wire_86;
    assign signal_mux_140 = signal_and_165 ? signal_select_69 : signal_reg_56;
    assign signal_mux_141 = write ? signal_mux_140 : signal_reg_56;
    assign signal_wire_56 = signal_mux_141;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_56 <= signal_const_182;
        else
            signal_reg_56 <= signal_wire_56;
    end
    assign signal_select_70 = value[4:0];
    assign signal_eq_154 = select == signal_const_20;
    assign signal_eq_155 = addr == signal_const_350;
    assign signal_and_166 = signal_eq_155 & signal_eq_154;
    assign signal_and_167 = signal_and_166 & signal_wire_87;
    assign signal_mux_142 = signal_and_167 ? signal_select_70 : signal_reg_57;
    assign signal_mux_143 = write ? signal_mux_142 : signal_reg_57;
    assign signal_wire_57 = signal_mux_143;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_57 <= signal_const_182;
        else
            signal_reg_57 <= signal_wire_57;
    end
    assign signal_mux_144 = select ? signal_reg_56 : signal_reg_57;
    assign signal_cat_62 = { signal_const_55,
                             signal_mux_144 };
    assign signal_const_356 = 2'b00;
    assign signal_select_71 = value[1:0];
    assign signal_eq_156 = select == signal_const;
    assign signal_const_358 = 7'b0010000;
    assign signal_eq_157 = addr == signal_const_358;
    assign signal_and_168 = signal_eq_157 & signal_eq_156;
    assign signal_and_169 = signal_and_168 & signal_wire_86;
    assign signal_mux_145 = signal_and_169 ? signal_select_71 : signal_reg_58;
    assign signal_mux_146 = write ? signal_mux_145 : signal_reg_58;
    assign signal_wire_58 = signal_mux_146;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_58 <= signal_const_356;
        else
            signal_reg_58 <= signal_wire_58;
    end
    assign signal_select_72 = value[1:0];
    assign signal_eq_158 = select == signal_const_20;
    assign signal_eq_159 = addr == signal_const_358;
    assign signal_and_170 = signal_eq_159 & signal_eq_158;
    assign signal_and_171 = signal_and_170 & signal_wire_87;
    assign signal_mux_147 = signal_and_171 ? signal_select_72 : signal_reg_59;
    assign signal_mux_148 = write ? signal_mux_147 : signal_reg_59;
    assign signal_wire_59 = signal_mux_148;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_59 <= signal_const_356;
        else
            signal_reg_59 <= signal_wire_59;
    end
    assign signal_mux_149 = select ? signal_reg_58 : signal_reg_59;
    assign signal_cat_63 = { signal_const_97,
                             signal_mux_149 };
    assign signal_cat_64 = { signal_const_42,
                             select };
    assign signal_wire_60 = status$isr_count_1;
    assign signal_wire_61 = status$isr_count_0;
    assign signal_mux_150 = select ? signal_wire_60 : signal_wire_61;
    assign signal_cat_65 = { signal_const_101,
                             signal_mux_150 };
    assign signal_wire_62 = status$osr_count_1;
    assign signal_wire_63 = status$osr_count_0;
    assign signal_mux_151 = select ? signal_wire_62 : signal_wire_63;
    assign signal_cat_66 = { signal_mux_151,
                             signal_cat_65 };
    assign signal_cat_67 = { signal_const_101,
                             signal_cat_66 };
    assign signal_wire_64 = status$osr_1;
    assign signal_wire_65 = status$osr_0;
    assign signal_mux_152 = select ? signal_wire_64 : signal_wire_65;
    assign signal_wire_66 = status$isr_1;
    assign signal_wire_67 = status$isr_0;
    assign signal_mux_153 = select ? signal_wire_66 : signal_wire_67;
    assign signal_select_73 = signal_mux_154[23:16];
    assign signal_cat_68 = { signal_const_106,
                             signal_select_73 };
    assign signal_wire_68 = status$t_1;
    assign signal_wire_69 = status$t_0;
    assign signal_mux_154 = select ? signal_wire_68 : signal_wire_69;
    assign signal_select_74 = signal_mux_154[15:0];
    assign signal_wire_70 = status$p_1;
    assign signal_wire_71 = status$p_0;
    assign signal_mux_155 = select ? signal_wire_70 : signal_wire_71;
    assign signal_wire_72 = status$y_1;
    assign signal_wire_73 = status$y_0;
    assign signal_mux_156 = select ? signal_wire_72 : signal_wire_73;
    assign signal_wire_74 = status$x_1;
    assign signal_wire_75 = status$x_0;
    assign signal_mux_157 = select ? signal_wire_74 : signal_wire_75;
    assign signal_const_378 = 9'b000000001;
    assign signal_add = data_addr + signal_const_378;
    assign signal_select_75 = value[8:0];
    assign signal_const_379 = 7'b0001100;
    assign signal_eq_160 = addr == signal_const_379;
    assign signal_mux_158 = signal_eq_160 ? signal_select_75 : data_addr;
    assign signal_eq_161 = addr == signal_const_15;
    assign signal_mux_159 = signal_eq_161 ? signal_add : signal_mux_158;
    assign signal_mux_160 = write ? signal_mux_159 : data_addr;
    assign signal_wire_76 = signal_mux_160;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            data_addr <= signal_const_135;
        else
            data_addr <= signal_wire_76;
    end
    assign signal_cat_69 = { signal_const_1,
                             data_addr };
    assign signal_add_1 = program_addr + signal_const_378;
    assign signal_select_76 = value[8:0];
    assign signal_const_385 = 7'b0001001;
    assign signal_eq_162 = addr == signal_const_385;
    assign signal_mux_161 = signal_eq_162 ? signal_select_76 : program_addr;
    assign signal_eq_163 = addr == signal_const_17;
    assign signal_mux_162 = signal_eq_163 ? signal_add_1 : signal_mux_161;
    assign signal_mux_163 = write ? signal_mux_162 : program_addr;
    assign signal_wire_77 = signal_mux_163;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            program_addr <= signal_const_135;
        else
            program_addr <= signal_wire_77;
    end
    assign signal_cat_70 = { signal_const_1,
                             program_addr };
    assign signal_wire_78 = status$rx_head_1;
    assign signal_wire_79 = status$rx_head_0;
    assign signal_mux_164 = select ? signal_wire_78 : signal_wire_79;
    assign signal_select_77 = signal_mux_165[23:16];
    assign signal_cat_71 = { signal_const_106,
                             signal_select_77 };
    assign signal_wire_80 = status$capture_1;
    assign signal_wire_81 = status$capture_0;
    assign signal_mux_165 = select ? signal_wire_80 : signal_wire_81;
    assign signal_select_78 = signal_mux_165[15:0];
    assign signal_select_79 = signal_mux_166[23:16];
    assign signal_cat_72 = { signal_const_106,
                             signal_select_79 };
    assign signal_wire_82 = status$now_1;
    assign signal_wire_83 = status$now_0;
    assign signal_mux_166 = select ? signal_wire_82 : signal_wire_83;
    assign signal_select_80 = signal_mux_166[15:0];
    assign signal_wire_84 = status$pc_1;
    assign signal_wire_85 = status$pc_0;
    assign signal_mux_167 = select ? signal_wire_84 : signal_wire_85;
    assign signal_cat_73 = { signal_const_1,
                             signal_mux_167 };
    assign signal_wire_86 = status$halted_1;
    assign signal_wire_87 = status$halted_0;
    assign signal_mux_168 = select ? signal_wire_86 : signal_wire_87;
    assign signal_mux_169 = select ? signal_wire_101 : signal_wire_100;
    assign signal_wire_88 = status$fault$underflow_1;
    assign signal_wire_89 = status$fault$underflow_0;
    assign signal_mux_170 = select ? signal_wire_88 : signal_wire_89;
    assign signal_wire_90 = status$fault$overflow_1;
    assign signal_wire_91 = status$fault$overflow_0;
    assign signal_mux_171 = select ? signal_wire_90 : signal_wire_91;
    assign signal_wire_92 = status$fault$missed_deadline_1;
    assign signal_wire_93 = status$fault$missed_deadline_0;
    assign signal_mux_172 = select ? signal_wire_92 : signal_wire_93;
    assign signal_wire_94 = status$fault$decode_1;
    assign signal_wire_95 = status$fault$decode_0;
    assign signal_mux_173 = select ? signal_wire_94 : signal_wire_95;
    assign signal_wire_96 = status$tx_level_1;
    assign signal_wire_97 = status$tx_level_0;
    assign signal_mux_174 = select ? signal_wire_96 : signal_wire_97;
    assign signal_wire_98 = status$rx_level_1;
    assign signal_wire_99 = status$rx_level_0;
    assign signal_mux_175 = select ? signal_wire_98 : signal_wire_99;
    assign signal_wire_100 = status$irq_0;
    assign signal_wire_101 = status$irq_1;
    always @* begin
        case (sm)
        2'b01:
            signal_cases <= signal_select_83;
        default:
            signal_cases <= high;
        endcase
    end
    assign signal_mux_176 = signal_select_86 ? signal_cases : high;
    assign signal_wire_102 = signal_mux_176;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            high <= signal_const_106;
        else
            high <= signal_wire_102;
    end
    assign value = { high,
                     signal_select_83 };
    assign signal_select_81 = value[0:0];
    assign signal_const_401 = 7'b0001011;
    assign signal_eq_164 = addr == signal_const_401;
    assign signal_mux_177 = signal_eq_164 ? signal_select_81 : select;
    assign signal_mux_178 = is_write ? vdd : gnd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_1 <= signal_mux_178;
        default:
            signal_cases_1 <= gnd;
        endcase
    end
    assign signal_mux_179 = signal_select_86 ? signal_cases_1 : gnd;
    assign write = signal_mux_179;
    assign signal_mux_180 = write ? signal_mux_177 : select;
    assign signal_wire_103 = signal_mux_180;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            select <= signal_const_20;
        else
            select <= signal_wire_103;
    end
    assign signal_mux_181 = select ? signal_wire_100 : signal_wire_101;
    assign signal_cat_74 = { signal_mux_181,
                             signal_const_20,
                             signal_mux_175,
                             signal_mux_174,
                             signal_mux_173,
                             signal_mux_172,
                             signal_mux_171,
                             signal_mux_170,
                             signal_mux_169,
                             signal_mux_168 };
    assign signal_select_82 = signal_select_83[6:0];
    always @* begin
        case (signal_select_82)
        7'b0000001:
            first_read <= signal_cat_74;
        7'b0000010:
            first_read <= signal_cat_73;
        7'b0000011:
            first_read <= signal_select_80;
        7'b0000100:
            first_read <= signal_cat_72;
        7'b0000101:
            first_read <= signal_select_78;
        7'b0000110:
            first_read <= signal_cat_71;
        7'b0001000:
            first_read <= signal_mux_164;
        7'b0001001:
            first_read <= signal_cat_70;
        7'b0001100:
            first_read <= signal_cat_69;
        7'b1000000:
            first_read <= signal_mux_157;
        7'b1000001:
            first_read <= signal_mux_156;
        7'b1000010:
            first_read <= signal_mux_155;
        7'b1000011:
            first_read <= signal_select_74;
        7'b1000100:
            first_read <= signal_cat_68;
        7'b1000101:
            first_read <= signal_mux_153;
        7'b1000110:
            first_read <= signal_mux_152;
        7'b1000111:
            first_read <= signal_cat_67;
        7'b0001011:
            first_read <= signal_cat_64;
        7'b0010000:
            first_read <= signal_cat_63;
        7'b0010001:
            first_read <= signal_cat_62;
        7'b0010010:
            first_read <= signal_cat_61;
        7'b0010011:
            first_read <= signal_cat_60;
        7'b0010100:
            first_read <= signal_cat_59;
        7'b0010101:
            first_read <= signal_cat_58;
        7'b0010110:
            first_read <= signal_cat_57;
        7'b0010111:
            first_read <= signal_cat_56;
        7'b0011000:
            first_read <= signal_cat_55;
        7'b0011001:
            first_read <= signal_cat_54;
        7'b0011010:
            first_read <= signal_cat_53;
        7'b0011011:
            first_read <= signal_cat_52;
        7'b0011100:
            first_read <= signal_cat_51;
        7'b0011101:
            first_read <= signal_cat_50;
        7'b0011110:
            first_read <= signal_cat_49;
        7'b0011111:
            first_read <= signal_cat_48;
        7'b0100000:
            first_read <= signal_cat_47;
        7'b0100001:
            first_read <= signal_cat_46;
        7'b0100010:
            first_read <= signal_cat_45;
        7'b0100011:
            first_read <= signal_mux_54;
        7'b0100100:
            first_read <= signal_mux_49;
        7'b0100101:
            first_read <= signal_cat_44;
        7'b0100110:
            first_read <= signal_cat_43;
        7'b0100111:
            first_read <= signal_cat_42;
        7'b0101000:
            first_read <= signal_cat_41;
        7'b0101001:
            first_read <= signal_cat_40;
        7'b0101010:
            first_read <= signal_mux_19;
        7'b0101011:
            first_read <= signal_cat_39;
        7'b0101100:
            first_read <= signal_cat_38;
        7'b0101101:
            first_read <= signal_cat_37;
        default:
            first_read <= signal_const_40;
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
    assign signal_mux_182 = signal_select_86 ? signal_cases_2 : word;
    assign vdd = 1'b1;
    assign is_write = cmd[7:7];
    assign signal_mux_183 = is_write ? gnd : vdd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_3 <= signal_mux_183;
        default:
            signal_cases_3 <= gnd;
        endcase
    end
    assign gnd = 1'b0;
    assign signal_mux_184 = signal_select_86 ? signal_cases_3 : gnd;
    assign read_done = signal_mux_184;
    assign signal_mux_185 = read_done ? read_value : signal_mux_182;
    assign signal_wire_104 = signal_mux_185;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            word <= signal_const_40;
        else
            word <= signal_wire_104;
    end
    assign signal_select_83 = signal_inst[8:1];
    always @* begin
        case (sm)
        2'b00:
            signal_cases_4 <= signal_select_83;
        default:
            signal_cases_4 <= cmd;
        endcase
    end
    assign signal_mux_186 = signal_select_86 ? signal_cases_4 : cmd;
    assign signal_wire_105 = signal_mux_186;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            cmd <= signal_const_106;
        else
            cmd <= signal_wire_105;
    end
    assign addr = cmd[6:0];
    assign signal_eq_165 = addr == signal_const_11;
    assign tx_word = signal_eq_165 ? signal_mux_164 : word;
    assign signal_select_84 = tx_word[15:8];
    assign signal_const_406 = 2'b01;
    always @* begin
        case (sm)
        2'b00:
            signal_cases_5 <= signal_const_406;
        2'b01:
            signal_cases_5 <= signal_const_408;
        2'b10:
            signal_cases_5 <= signal_const_406;
        default:
            signal_cases_5 <= signal_mux_187;
        endcase
    end
    assign signal_select_85 = signal_inst[10:10];
    assign signal_mux_187 = signal_select_85 ? signal_const_356 : sm;
    assign signal_select_86 = signal_inst[9:9];
    assign signal_mux_188 = signal_select_86 ? signal_cases_5 : signal_mux_187;
    assign signal_wire_106 = signal_mux_188;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            sm <= signal_const_356;
        else
            sm <= signal_wire_106;
    end
    assign signal_const_408 = 2'b10;
    assign signal_eq_166 = signal_const_408 == sm;
    assign signal_mux_189 = signal_eq_166 ? signal_select_12 : signal_select_84;
    assign signal_wire_107 = cs_n;
    assign signal_wire_108 = mosi;
    assign signal_wire_109 = sck;
    assign signal_wire_110 = clear;
    assign signal_wire_111 = clock;
    host_spi
        host_spi
        ( .clock(signal_wire_111),
          .clear(signal_wire_110),
          .sck(signal_wire_109),
          .mosi(signal_wire_108),
          .cs_n(signal_wire_107),
          .tx_byte(signal_mux_189),
          .miso(signal_inst[0:0]),
          .rx_byte(signal_inst[8:1]),
          .rx_valid(signal_inst[9:9]),
          .frame_start(signal_inst[10:10]),
          .frame_end(signal_inst[11:11]) );
    assign signal_select_87 = signal_inst[0:0];
    assign miso = signal_select_87;
    assign engines$config$side_set_count_0 = signal_reg_59;
    assign engines$config$side_set_base_0 = signal_reg_57;
    assign engines$config$side_set_pindirs_0 = signal_reg_55;
    assign engines$config$in_base_0 = signal_reg_53;
    assign engines$config$in_count_0 = signal_reg_51;
    assign engines$config$out_base_0 = signal_reg_49;
    assign engines$config$out_count_0 = signal_reg_47;
    assign engines$config$set_base_0 = signal_reg_45;
    assign engines$config$set_count_0 = signal_reg_43;
    assign engines$config$jmp_pin_0 = signal_reg_41;
    assign engines$config$capture_pin_0 = signal_reg_39;
    assign engines$config$capture_rising_0 = signal_reg_37;
    assign engines$config$in_shift_right_0 = signal_reg_35;
    assign engines$config$out_shift_right_0 = signal_reg_33;
    assign engines$config$autopush_0 = signal_reg_31;
    assign engines$config$push_threshold_0 = signal_reg_29;
    assign engines$config$autopull_0 = signal_reg_27;
    assign engines$config$pull_threshold_0 = signal_reg_25;
    assign engines$config$crc_width_0 = signal_reg_23;
    assign engines$config$crc_poly_0 = signal_reg_21;
    assign engines$config$crc_init_0 = signal_reg_19;
    assign engines$config$crc_reflect_0 = signal_reg_17;
    assign engines$config$stuff_threshold_0 = signal_reg_15;
    assign engines$config$stuff_level_0 = signal_reg_13;
    assign engines$config$wrap_bottom_0 = signal_reg_11;
    assign engines$config$wrap_top_0 = signal_reg_9;
    assign engines$config$period_fraction_0 = signal_reg_7;
    assign engines$config$break_enable_0 = signal_reg_5;
    assign engines$config$break_pc_0 = signal_reg_3;
    assign engines$config$autopull_data_0 = signal_reg_1;
    assign engines$start_0 = signal_and_51;
    assign engines$program_write$valid_0 = signal_and_48;
    assign engines$program_write$addr_0 = program_addr;
    assign engines$program_write$data_0 = value;
    assign engines$data_write$valid_0 = signal_and_46;
    assign engines$data_write$addr_0 = data_addr;
    assign engines$data_write$data_0 = value;
    assign engines$tx$valid_0 = signal_and_44;
    assign engines$tx$value_0 = value;
    assign engines$rx_pop_0 = signal_and_42;
    assign engines$clear_irq_0 = signal_and_40;
    assign engines$stop_0 = signal_and_37;
    assign engines$flush_0 = signal_and_34;
    assign engines$resume_0 = signal_and_31;
    assign engines$single_step_0 = signal_and_28;
    assign engines$config$side_set_count_1 = signal_reg_58;
    assign engines$config$side_set_base_1 = signal_reg_56;
    assign engines$config$side_set_pindirs_1 = signal_reg_54;
    assign engines$config$in_base_1 = signal_reg_52;
    assign engines$config$in_count_1 = signal_reg_50;
    assign engines$config$out_base_1 = signal_reg_48;
    assign engines$config$out_count_1 = signal_reg_46;
    assign engines$config$set_base_1 = signal_reg_44;
    assign engines$config$set_count_1 = signal_reg_42;
    assign engines$config$jmp_pin_1 = signal_reg_40;
    assign engines$config$capture_pin_1 = signal_reg_38;
    assign engines$config$capture_rising_1 = signal_reg_36;
    assign engines$config$in_shift_right_1 = signal_reg_34;
    assign engines$config$out_shift_right_1 = signal_reg_32;
    assign engines$config$autopush_1 = signal_reg_30;
    assign engines$config$push_threshold_1 = signal_reg_28;
    assign engines$config$autopull_1 = signal_reg_26;
    assign engines$config$pull_threshold_1 = signal_reg_24;
    assign engines$config$crc_width_1 = signal_reg_22;
    assign engines$config$crc_poly_1 = signal_reg_20;
    assign engines$config$crc_init_1 = signal_reg_18;
    assign engines$config$crc_reflect_1 = signal_reg_16;
    assign engines$config$stuff_threshold_1 = signal_reg_14;
    assign engines$config$stuff_level_1 = signal_reg_12;
    assign engines$config$wrap_bottom_1 = signal_reg_10;
    assign engines$config$wrap_top_1 = signal_reg_8;
    assign engines$config$period_fraction_1 = signal_reg_6;
    assign engines$config$break_enable_1 = signal_reg_4;
    assign engines$config$break_pc_1 = signal_reg_2;
    assign engines$config$autopull_data_1 = signal_reg;
    assign engines$start_1 = signal_and_25;
    assign engines$program_write$valid_1 = signal_and_22;
    assign engines$program_write$addr_1 = program_addr;
    assign engines$program_write$data_1 = value;
    assign engines$data_write$valid_1 = signal_and_20;
    assign engines$data_write$addr_1 = data_addr;
    assign engines$data_write$data_1 = value;
    assign engines$tx$valid_1 = signal_and_18;
    assign engines$tx$value_1 = value;
    assign engines$rx_pop_1 = signal_and_16;
    assign engines$clear_irq_1 = signal_and_14;
    assign engines$stop_1 = signal_and_11;
    assign engines$flush_1 = signal_and_8;
    assign engines$resume_1 = signal_and_5;
    assign engines$single_step_1 = signal_and_2;

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
    wire signal_select_9;
    wire signal_select_10;
    wire [15:0] signal_select_11;
    wire signal_select_12;
    wire [15:0] signal_select_13;
    wire [8:0] signal_select_14;
    wire signal_select_15;
    wire [15:0] signal_select_16;
    wire [8:0] signal_select_17;
    wire signal_select_18;
    wire signal_select_19;
    wire signal_select_20;
    wire [8:0] signal_select_21;
    wire signal_select_22;
    wire [15:0] signal_select_23;
    wire [8:0] signal_select_24;
    wire [8:0] signal_select_25;
    wire signal_select_26;
    wire [4:0] signal_select_27;
    wire signal_select_28;
    wire [15:0] signal_select_29;
    wire [15:0] signal_select_30;
    wire [4:0] signal_select_31;
    wire [4:0] signal_select_32;
    wire signal_select_33;
    wire [4:0] signal_select_34;
    wire signal_select_35;
    wire signal_select_36;
    wire signal_select_37;
    wire signal_select_38;
    wire [4:0] signal_select_39;
    wire [4:0] signal_select_40;
    wire [2:0] signal_select_41;
    wire [4:0] signal_select_42;
    wire [4:0] signal_select_43;
    wire [4:0] signal_select_44;
    wire [4:0] signal_select_45;
    wire [4:0] signal_select_46;
    wire signal_select_47;
    wire [4:0] signal_select_48;
    wire [1:0] signal_select_49;
    wire signal_select_50;
    wire signal_select_51;
    wire signal_select_52;
    wire signal_select_53;
    wire signal_select_54;
    wire signal_select_55;
    wire [15:0] signal_select_56;
    wire signal_select_57;
    wire [15:0] signal_select_58;
    wire [8:0] signal_select_59;
    wire signal_select_60;
    wire [15:0] signal_select_61;
    wire [8:0] signal_select_62;
    wire signal_select_63;
    wire signal_select_64;
    wire signal_select_65;
    wire [8:0] signal_select_66;
    wire signal_select_67;
    wire [15:0] signal_select_68;
    wire [8:0] signal_select_69;
    wire [8:0] signal_select_70;
    wire signal_select_71;
    wire [4:0] signal_select_72;
    wire signal_select_73;
    wire [15:0] signal_select_74;
    wire [15:0] signal_select_75;
    wire [4:0] signal_select_76;
    wire [4:0] signal_select_77;
    wire signal_select_78;
    wire [4:0] signal_select_79;
    wire signal_select_80;
    wire signal_select_81;
    wire signal_select_82;
    wire signal_select_83;
    wire [4:0] signal_select_84;
    wire [4:0] signal_select_85;
    wire [2:0] signal_select_86;
    wire [4:0] signal_select_87;
    wire [4:0] signal_select_88;
    wire [4:0] signal_select_89;
    wire [4:0] signal_select_90;
    wire [4:0] signal_select_91;
    wire signal_select_92;
    wire [4:0] signal_select_93;
    wire [4:0] signal_select_94;
    wire [4:0] signal_wire_1;
    wire [4:0] signal_select_95;
    wire [4:0] signal_wire_2;
    wire [15:0] signal_select_96;
    wire [15:0] signal_wire_3;
    wire [15:0] signal_select_97;
    wire [15:0] signal_wire_4;
    wire [23:0] signal_select_98;
    wire [23:0] signal_wire_5;
    wire [15:0] signal_select_99;
    wire [15:0] signal_wire_6;
    wire [15:0] signal_select_100;
    wire [15:0] signal_wire_7;
    wire [15:0] signal_select_101;
    wire [15:0] signal_wire_8;
    wire [15:0] signal_select_102;
    wire [15:0] signal_wire_9;
    wire [3:0] signal_select_103;
    wire [3:0] signal_wire_10;
    wire [3:0] signal_select_104;
    wire [3:0] signal_wire_11;
    wire signal_select_105;
    wire signal_wire_12;
    wire signal_select_106;
    wire signal_wire_13;
    wire signal_select_107;
    wire signal_wire_14;
    wire signal_select_108;
    wire signal_wire_15;
    wire signal_select_109;
    wire signal_wire_16;
    wire signal_select_110;
    wire signal_wire_17;
    wire [23:0] signal_select_111;
    wire [23:0] signal_wire_18;
    wire [23:0] signal_select_112;
    wire [23:0] signal_wire_19;
    wire [8:0] signal_select_113;
    wire [8:0] signal_wire_20;
    wire [4:0] signal_select_114;
    wire [4:0] signal_wire_21;
    wire [4:0] signal_select_115;
    wire [4:0] signal_wire_22;
    wire [15:0] signal_select_116;
    wire [15:0] signal_wire_23;
    wire [15:0] signal_select_117;
    wire [15:0] signal_wire_24;
    wire [23:0] signal_select_118;
    wire [23:0] signal_wire_25;
    wire [15:0] signal_select_119;
    wire [15:0] signal_wire_26;
    wire [15:0] signal_select_120;
    wire [15:0] signal_wire_27;
    wire [15:0] signal_select_121;
    wire [15:0] signal_wire_28;
    wire [15:0] signal_select_122;
    wire [15:0] signal_wire_29;
    wire [3:0] signal_select_123;
    wire [3:0] signal_wire_30;
    wire [3:0] signal_select_124;
    wire [3:0] signal_wire_31;
    wire signal_select_125;
    wire signal_wire_32;
    wire signal_select_126;
    wire signal_wire_33;
    wire signal_select_127;
    wire signal_wire_34;
    wire signal_select_128;
    wire signal_wire_35;
    wire signal_select_129;
    wire signal_wire_36;
    wire signal_select_130;
    wire signal_wire_37;
    wire [23:0] signal_select_131;
    wire [23:0] signal_wire_38;
    wire [23:0] signal_select_132;
    wire [23:0] signal_wire_39;
    wire [8:0] signal_select_133;
    wire [8:0] signal_wire_40;
    wire signal_select_134;
    wire signal_select_135;
    wire [7:0] signal_wire_41;
    wire signal_select_136;
    wire [452:0] signal_inst;
    wire [1:0] signal_select_137;
    wire signal_const_5;
    wire signal_wire_42;
    wire signal_not;
    wire vdd;
    reg signal_reg_4;
    reg reset_done;
    wire signal_not_1;
    wire signal_wire_43;
    wire [711:0] signal_inst_1;
    wire [19:0] signal_select_138;
    wire [6:0] signal_select_139;
    wire [7:0] signal_cat;
    assign signal_select = signal_inst_1[711:692];
    assign signal_select_1 = signal_select[19:12];
    assign signal_select_2 = signal_select_138[19:12];
    assign signal_select_3 = signal_inst[0:0];
    assign signal_const = 5'b00000;
    assign signal_select_4 = signal_wire_41[7:3];
    always @(posedge signal_wire_43) begin
        if (signal_not_1)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_select_4;
    end
    always @(posedge signal_wire_43) begin
        if (signal_not_1)
            signal_reg_1 <= signal_const;
        else
            signal_reg_1 <= signal_reg;
    end
    assign signal_const_2 = 7'b0000000;
    assign signal_const_3 = 8'b00000000;
    assign signal_wire = uio_in;
    always @(posedge signal_wire_43) begin
        if (signal_not_1)
            signal_reg_2 <= signal_const_3;
        else
            signal_reg_2 <= signal_wire;
    end
    always @(posedge signal_wire_43) begin
        if (signal_not_1)
            signal_reg_3 <= signal_const_3;
        else
            signal_reg_3 <= signal_reg_2;
    end
    assign inputs = { signal_reg_3,
                      signal_const_2,
                      signal_reg_1 };
    assign signal_select_5 = signal_inst[452:452];
    assign signal_select_6 = signal_inst[451:451];
    assign signal_select_7 = signal_inst[450:450];
    assign signal_select_8 = signal_inst[449:449];
    assign signal_select_9 = signal_inst[448:448];
    assign signal_select_10 = signal_inst[447:447];
    assign signal_select_11 = signal_inst[446:431];
    assign signal_select_12 = signal_inst[430:430];
    assign signal_select_13 = signal_inst[429:414];
    assign signal_select_14 = signal_inst[413:405];
    assign signal_select_15 = signal_inst[404:404];
    assign signal_select_16 = signal_inst[403:388];
    assign signal_select_17 = signal_inst[387:379];
    assign signal_select_18 = signal_inst[378:378];
    assign signal_select_19 = signal_inst[377:377];
    assign signal_select_20 = signal_inst[376:376];
    assign signal_select_21 = signal_inst[375:367];
    assign signal_select_22 = signal_inst[366:366];
    assign signal_select_23 = signal_inst[365:350];
    assign signal_select_24 = signal_inst[349:341];
    assign signal_select_25 = signal_inst[340:332];
    assign signal_select_26 = signal_inst[331:331];
    assign signal_select_27 = signal_inst[330:326];
    assign signal_select_28 = signal_inst[325:325];
    assign signal_select_29 = signal_inst[324:309];
    assign signal_select_30 = signal_inst[308:293];
    assign signal_select_31 = signal_inst[292:288];
    assign signal_select_32 = signal_inst[287:283];
    assign signal_select_33 = signal_inst[282:282];
    assign signal_select_34 = signal_inst[281:277];
    assign signal_select_35 = signal_inst[276:276];
    assign signal_select_36 = signal_inst[275:275];
    assign signal_select_37 = signal_inst[274:274];
    assign signal_select_38 = signal_inst[273:273];
    assign signal_select_39 = signal_inst[272:268];
    assign signal_select_40 = signal_inst[267:263];
    assign signal_select_41 = signal_inst[262:260];
    assign signal_select_42 = signal_inst[259:255];
    assign signal_select_43 = signal_inst[254:250];
    assign signal_select_44 = signal_inst[249:245];
    assign signal_select_45 = signal_inst[244:240];
    assign signal_select_46 = signal_inst[239:235];
    assign signal_select_47 = signal_inst[234:234];
    assign signal_select_48 = signal_inst[233:229];
    assign signal_select_49 = signal_inst[228:227];
    assign signal_select_50 = signal_inst[226:226];
    assign signal_select_51 = signal_inst[225:225];
    assign signal_select_52 = signal_inst[224:224];
    assign signal_select_53 = signal_inst[223:223];
    assign signal_select_54 = signal_inst[222:222];
    assign signal_select_55 = signal_inst[221:221];
    assign signal_select_56 = signal_inst[220:205];
    assign signal_select_57 = signal_inst[204:204];
    assign signal_select_58 = signal_inst[203:188];
    assign signal_select_59 = signal_inst[187:179];
    assign signal_select_60 = signal_inst[178:178];
    assign signal_select_61 = signal_inst[177:162];
    assign signal_select_62 = signal_inst[161:153];
    assign signal_select_63 = signal_inst[152:152];
    assign signal_select_64 = signal_inst[151:151];
    assign signal_select_65 = signal_inst[150:150];
    assign signal_select_66 = signal_inst[149:141];
    assign signal_select_67 = signal_inst[140:140];
    assign signal_select_68 = signal_inst[139:124];
    assign signal_select_69 = signal_inst[123:115];
    assign signal_select_70 = signal_inst[114:106];
    assign signal_select_71 = signal_inst[105:105];
    assign signal_select_72 = signal_inst[104:100];
    assign signal_select_73 = signal_inst[99:99];
    assign signal_select_74 = signal_inst[98:83];
    assign signal_select_75 = signal_inst[82:67];
    assign signal_select_76 = signal_inst[66:62];
    assign signal_select_77 = signal_inst[61:57];
    assign signal_select_78 = signal_inst[56:56];
    assign signal_select_79 = signal_inst[55:51];
    assign signal_select_80 = signal_inst[50:50];
    assign signal_select_81 = signal_inst[49:49];
    assign signal_select_82 = signal_inst[48:48];
    assign signal_select_83 = signal_inst[47:47];
    assign signal_select_84 = signal_inst[46:42];
    assign signal_select_85 = signal_inst[41:37];
    assign signal_select_86 = signal_inst[36:34];
    assign signal_select_87 = signal_inst[33:29];
    assign signal_select_88 = signal_inst[28:24];
    assign signal_select_89 = signal_inst[23:19];
    assign signal_select_90 = signal_inst[18:14];
    assign signal_select_91 = signal_inst[13:9];
    assign signal_select_92 = signal_inst[8:8];
    assign signal_select_93 = signal_inst[7:3];
    assign signal_select_94 = signal_inst_1[518:514];
    assign signal_wire_1 = signal_select_94;
    assign signal_select_95 = signal_inst_1[539:535];
    assign signal_wire_2 = signal_select_95;
    assign signal_select_96 = signal_inst_1[513:498];
    assign signal_wire_3 = signal_select_96;
    assign signal_select_97 = signal_inst_1[534:519];
    assign signal_wire_4 = signal_select_97;
    assign signal_select_98 = signal_inst_1[481:458];
    assign signal_wire_5 = signal_select_98;
    assign signal_select_99 = signal_inst_1[457:442];
    assign signal_wire_6 = signal_select_99;
    assign signal_select_100 = signal_inst_1[441:426];
    assign signal_wire_7 = signal_select_100;
    assign signal_select_101 = signal_inst_1[425:410];
    assign signal_wire_8 = signal_select_101;
    assign signal_select_102 = signal_inst_1[625:610];
    assign signal_wire_9 = signal_select_102;
    assign signal_select_103 = signal_inst_1[609:606];
    assign signal_wire_10 = signal_select_103;
    assign signal_select_104 = signal_inst_1[605:602];
    assign signal_wire_11 = signal_select_104;
    assign signal_select_105 = signal_inst_1[576:576];
    assign signal_wire_12 = signal_select_105;
    assign signal_select_106 = signal_inst_1[575:575];
    assign signal_wire_13 = signal_select_106;
    assign signal_select_107 = signal_inst_1[574:574];
    assign signal_wire_14 = signal_select_107;
    assign signal_select_108 = signal_inst_1[573:573];
    assign signal_wire_15 = signal_select_108;
    assign signal_select_109 = signal_inst_1[572:572];
    assign signal_wire_16 = signal_select_109;
    assign signal_select_110 = signal_inst_1[569:569];
    assign signal_wire_17 = signal_select_110;
    assign signal_select_111 = signal_inst_1[600:577];
    assign signal_wire_18 = signal_select_111;
    assign signal_select_112 = signal_inst_1[563:540];
    assign signal_wire_19 = signal_select_112;
    assign signal_select_113 = signal_inst_1[400:392];
    assign signal_wire_20 = signal_select_113;
    assign signal_select_114 = signal_inst_1[182:178];
    assign signal_wire_21 = signal_select_114;
    assign signal_select_115 = signal_inst_1[203:199];
    assign signal_wire_22 = signal_select_115;
    assign signal_select_116 = signal_inst_1[177:162];
    assign signal_wire_23 = signal_select_116;
    assign signal_select_117 = signal_inst_1[198:183];
    assign signal_wire_24 = signal_select_117;
    assign signal_select_118 = signal_inst_1[145:122];
    assign signal_wire_25 = signal_select_118;
    assign signal_select_119 = signal_inst_1[121:106];
    assign signal_wire_26 = signal_select_119;
    assign signal_select_120 = signal_inst_1[105:90];
    assign signal_wire_27 = signal_select_120;
    assign signal_select_121 = signal_inst_1[89:74];
    assign signal_wire_28 = signal_select_121;
    assign signal_select_122 = signal_inst_1[289:274];
    assign signal_wire_29 = signal_select_122;
    assign signal_select_123 = signal_inst_1[273:270];
    assign signal_wire_30 = signal_select_123;
    assign signal_select_124 = signal_inst_1[269:266];
    assign signal_wire_31 = signal_select_124;
    assign signal_select_125 = signal_inst_1[240:240];
    assign signal_wire_32 = signal_select_125;
    assign signal_select_126 = signal_inst_1[239:239];
    assign signal_wire_33 = signal_select_126;
    assign signal_select_127 = signal_inst_1[238:238];
    assign signal_wire_34 = signal_select_127;
    assign signal_select_128 = signal_inst_1[237:237];
    assign signal_wire_35 = signal_select_128;
    assign signal_select_129 = signal_inst_1[236:236];
    assign signal_wire_36 = signal_select_129;
    assign signal_select_130 = signal_inst_1[233:233];
    assign signal_wire_37 = signal_select_130;
    assign signal_select_131 = signal_inst_1[264:241];
    assign signal_wire_38 = signal_select_131;
    assign signal_select_132 = signal_inst_1[227:204];
    assign signal_wire_39 = signal_select_132;
    assign signal_select_133 = signal_inst_1[64:56];
    assign signal_wire_40 = signal_select_133;
    assign signal_select_134 = signal_wire_41[2:2];
    assign signal_select_135 = signal_wire_41[1:1];
    assign signal_wire_41 = ui_in;
    assign signal_select_136 = signal_wire_41[0:0];
    host_port
        host_port
        ( .clock(signal_wire_43),
          .clear(signal_not_1),
          .sck(signal_select_136),
          .mosi(signal_select_135),
          .cs_n(signal_select_134),
          .status$pc_0(signal_wire_40),
          .status$now_0(signal_wire_39),
          .status$capture_0(signal_wire_38),
          .status$halted_0(signal_wire_37),
          .status$irq_0(signal_wire_36),
          .status$fault$underflow_0(signal_wire_35),
          .status$fault$overflow_0(signal_wire_34),
          .status$fault$missed_deadline_0(signal_wire_33),
          .status$fault$decode_0(signal_wire_32),
          .status$tx_level_0(signal_wire_31),
          .status$rx_level_0(signal_wire_30),
          .status$rx_head_0(signal_wire_29),
          .status$x_0(signal_wire_28),
          .status$y_0(signal_wire_27),
          .status$p_0(signal_wire_26),
          .status$t_0(signal_wire_25),
          .status$isr_0(signal_wire_24),
          .status$osr_0(signal_wire_23),
          .status$isr_count_0(signal_wire_22),
          .status$osr_count_0(signal_wire_21),
          .status$pc_1(signal_wire_20),
          .status$now_1(signal_wire_19),
          .status$capture_1(signal_wire_18),
          .status$halted_1(signal_wire_17),
          .status$irq_1(signal_wire_16),
          .status$fault$underflow_1(signal_wire_15),
          .status$fault$overflow_1(signal_wire_14),
          .status$fault$missed_deadline_1(signal_wire_13),
          .status$fault$decode_1(signal_wire_12),
          .status$tx_level_1(signal_wire_11),
          .status$rx_level_1(signal_wire_10),
          .status$rx_head_1(signal_wire_9),
          .status$x_1(signal_wire_8),
          .status$y_1(signal_wire_7),
          .status$p_1(signal_wire_6),
          .status$t_1(signal_wire_5),
          .status$isr_1(signal_wire_4),
          .status$osr_1(signal_wire_3),
          .status$isr_count_1(signal_wire_2),
          .status$osr_count_1(signal_wire_1),
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
          .engines$config$break_enable_0(signal_inst[140:140]),
          .engines$config$break_pc_0(signal_inst[149:141]),
          .engines$config$autopull_data_0(signal_inst[150:150]),
          .engines$start_0(signal_inst[151:151]),
          .engines$program_write$valid_0(signal_inst[152:152]),
          .engines$program_write$addr_0(signal_inst[161:153]),
          .engines$program_write$data_0(signal_inst[177:162]),
          .engines$data_write$valid_0(signal_inst[178:178]),
          .engines$data_write$addr_0(signal_inst[187:179]),
          .engines$data_write$data_0(signal_inst[203:188]),
          .engines$tx$valid_0(signal_inst[204:204]),
          .engines$tx$value_0(signal_inst[220:205]),
          .engines$rx_pop_0(signal_inst[221:221]),
          .engines$clear_irq_0(signal_inst[222:222]),
          .engines$stop_0(signal_inst[223:223]),
          .engines$flush_0(signal_inst[224:224]),
          .engines$resume_0(signal_inst[225:225]),
          .engines$single_step_0(signal_inst[226:226]),
          .engines$config$side_set_count_1(signal_inst[228:227]),
          .engines$config$side_set_base_1(signal_inst[233:229]),
          .engines$config$side_set_pindirs_1(signal_inst[234:234]),
          .engines$config$in_base_1(signal_inst[239:235]),
          .engines$config$in_count_1(signal_inst[244:240]),
          .engines$config$out_base_1(signal_inst[249:245]),
          .engines$config$out_count_1(signal_inst[254:250]),
          .engines$config$set_base_1(signal_inst[259:255]),
          .engines$config$set_count_1(signal_inst[262:260]),
          .engines$config$jmp_pin_1(signal_inst[267:263]),
          .engines$config$capture_pin_1(signal_inst[272:268]),
          .engines$config$capture_rising_1(signal_inst[273:273]),
          .engines$config$in_shift_right_1(signal_inst[274:274]),
          .engines$config$out_shift_right_1(signal_inst[275:275]),
          .engines$config$autopush_1(signal_inst[276:276]),
          .engines$config$push_threshold_1(signal_inst[281:277]),
          .engines$config$autopull_1(signal_inst[282:282]),
          .engines$config$pull_threshold_1(signal_inst[287:283]),
          .engines$config$crc_width_1(signal_inst[292:288]),
          .engines$config$crc_poly_1(signal_inst[308:293]),
          .engines$config$crc_init_1(signal_inst[324:309]),
          .engines$config$crc_reflect_1(signal_inst[325:325]),
          .engines$config$stuff_threshold_1(signal_inst[330:326]),
          .engines$config$stuff_level_1(signal_inst[331:331]),
          .engines$config$wrap_bottom_1(signal_inst[340:332]),
          .engines$config$wrap_top_1(signal_inst[349:341]),
          .engines$config$period_fraction_1(signal_inst[365:350]),
          .engines$config$break_enable_1(signal_inst[366:366]),
          .engines$config$break_pc_1(signal_inst[375:367]),
          .engines$config$autopull_data_1(signal_inst[376:376]),
          .engines$start_1(signal_inst[377:377]),
          .engines$program_write$valid_1(signal_inst[378:378]),
          .engines$program_write$addr_1(signal_inst[387:379]),
          .engines$program_write$data_1(signal_inst[403:388]),
          .engines$data_write$valid_1(signal_inst[404:404]),
          .engines$data_write$addr_1(signal_inst[413:405]),
          .engines$data_write$data_1(signal_inst[429:414]),
          .engines$tx$valid_1(signal_inst[430:430]),
          .engines$tx$value_1(signal_inst[446:431]),
          .engines$rx_pop_1(signal_inst[447:447]),
          .engines$clear_irq_1(signal_inst[448:448]),
          .engines$stop_1(signal_inst[449:449]),
          .engines$flush_1(signal_inst[450:450]),
          .engines$resume_1(signal_inst[451:451]),
          .engines$single_step_1(signal_inst[452:452]) );
    assign signal_select_137 = signal_inst[2:1];
    assign signal_const_5 = 1'b0;
    assign signal_wire_42 = rst_n;
    assign signal_not = ~ signal_wire_42;
    assign vdd = 1'b1;
    always @(posedge signal_wire_43 or posedge signal_not) begin
        if (signal_not)
            signal_reg_4 <= signal_const_5;
        else
            signal_reg_4 <= vdd;
    end
    always @(posedge signal_wire_43 or posedge signal_not) begin
        if (signal_not)
            reset_done <= signal_const_5;
        else
            reset_done <= signal_reg_4;
    end
    assign signal_not_1 = ~ reset_done;
    assign signal_wire_43 = clk;
    engines
        engines
        ( .clock(signal_wire_43),
          .clear(signal_not_1),
          .hosts$config$side_set_count_0(signal_select_137),
          .hosts$config$side_set_base_0(signal_select_93),
          .hosts$config$side_set_pindirs_0(signal_select_92),
          .hosts$config$in_base_0(signal_select_91),
          .hosts$config$in_count_0(signal_select_90),
          .hosts$config$out_base_0(signal_select_89),
          .hosts$config$out_count_0(signal_select_88),
          .hosts$config$set_base_0(signal_select_87),
          .hosts$config$set_count_0(signal_select_86),
          .hosts$config$jmp_pin_0(signal_select_85),
          .hosts$config$capture_pin_0(signal_select_84),
          .hosts$config$capture_rising_0(signal_select_83),
          .hosts$config$in_shift_right_0(signal_select_82),
          .hosts$config$out_shift_right_0(signal_select_81),
          .hosts$config$autopush_0(signal_select_80),
          .hosts$config$push_threshold_0(signal_select_79),
          .hosts$config$autopull_0(signal_select_78),
          .hosts$config$pull_threshold_0(signal_select_77),
          .hosts$config$crc_width_0(signal_select_76),
          .hosts$config$crc_poly_0(signal_select_75),
          .hosts$config$crc_init_0(signal_select_74),
          .hosts$config$crc_reflect_0(signal_select_73),
          .hosts$config$stuff_threshold_0(signal_select_72),
          .hosts$config$stuff_level_0(signal_select_71),
          .hosts$config$wrap_bottom_0(signal_select_70),
          .hosts$config$wrap_top_0(signal_select_69),
          .hosts$config$period_fraction_0(signal_select_68),
          .hosts$config$break_enable_0(signal_select_67),
          .hosts$config$break_pc_0(signal_select_66),
          .hosts$config$autopull_data_0(signal_select_65),
          .hosts$start_0(signal_select_64),
          .hosts$program_write$valid_0(signal_select_63),
          .hosts$program_write$addr_0(signal_select_62),
          .hosts$program_write$data_0(signal_select_61),
          .hosts$data_write$valid_0(signal_select_60),
          .hosts$data_write$addr_0(signal_select_59),
          .hosts$data_write$data_0(signal_select_58),
          .hosts$tx$valid_0(signal_select_57),
          .hosts$tx$value_0(signal_select_56),
          .hosts$rx_pop_0(signal_select_55),
          .hosts$clear_irq_0(signal_select_54),
          .hosts$stop_0(signal_select_53),
          .hosts$flush_0(signal_select_52),
          .hosts$resume_0(signal_select_51),
          .hosts$single_step_0(signal_select_50),
          .hosts$config$side_set_count_1(signal_select_49),
          .hosts$config$side_set_base_1(signal_select_48),
          .hosts$config$side_set_pindirs_1(signal_select_47),
          .hosts$config$in_base_1(signal_select_46),
          .hosts$config$in_count_1(signal_select_45),
          .hosts$config$out_base_1(signal_select_44),
          .hosts$config$out_count_1(signal_select_43),
          .hosts$config$set_base_1(signal_select_42),
          .hosts$config$set_count_1(signal_select_41),
          .hosts$config$jmp_pin_1(signal_select_40),
          .hosts$config$capture_pin_1(signal_select_39),
          .hosts$config$capture_rising_1(signal_select_38),
          .hosts$config$in_shift_right_1(signal_select_37),
          .hosts$config$out_shift_right_1(signal_select_36),
          .hosts$config$autopush_1(signal_select_35),
          .hosts$config$push_threshold_1(signal_select_34),
          .hosts$config$autopull_1(signal_select_33),
          .hosts$config$pull_threshold_1(signal_select_32),
          .hosts$config$crc_width_1(signal_select_31),
          .hosts$config$crc_poly_1(signal_select_30),
          .hosts$config$crc_init_1(signal_select_29),
          .hosts$config$crc_reflect_1(signal_select_28),
          .hosts$config$stuff_threshold_1(signal_select_27),
          .hosts$config$stuff_level_1(signal_select_26),
          .hosts$config$wrap_bottom_1(signal_select_25),
          .hosts$config$wrap_top_1(signal_select_24),
          .hosts$config$period_fraction_1(signal_select_23),
          .hosts$config$break_enable_1(signal_select_22),
          .hosts$config$break_pc_1(signal_select_21),
          .hosts$config$autopull_data_1(signal_select_20),
          .hosts$start_1(signal_select_19),
          .hosts$program_write$valid_1(signal_select_18),
          .hosts$program_write$addr_1(signal_select_17),
          .hosts$program_write$data_1(signal_select_16),
          .hosts$data_write$valid_1(signal_select_15),
          .hosts$data_write$addr_1(signal_select_14),
          .hosts$data_write$data_1(signal_select_13),
          .hosts$tx$valid_1(signal_select_12),
          .hosts$tx$value_1(signal_select_11),
          .hosts$rx_pop_1(signal_select_10),
          .hosts$clear_irq_1(signal_select_9),
          .hosts$stop_1(signal_select_8),
          .hosts$flush_1(signal_select_7),
          .hosts$resume_1(signal_select_6),
          .hosts$single_step_1(signal_select_5),
          .pads(inputs),
          .engines$pin_out_0(signal_inst_1[27:0]),
          .engines$pin_dir_0(signal_inst_1[55:28]),
          .engines$pc_0(signal_inst_1[64:56]),
          .engines$data_ptr_0(signal_inst_1[73:65]),
          .engines$x_0(signal_inst_1[89:74]),
          .engines$y_0(signal_inst_1[105:90]),
          .engines$p_0(signal_inst_1[121:106]),
          .engines$t_0(signal_inst_1[145:122]),
          .engines$t_fraction_0(signal_inst_1[161:146]),
          .engines$osr_0(signal_inst_1[177:162]),
          .engines$osr_count_0(signal_inst_1[182:178]),
          .engines$isr_0(signal_inst_1[198:183]),
          .engines$isr_count_0(signal_inst_1[203:199]),
          .engines$now_0(signal_inst_1[227:204]),
          .engines$stall_0(signal_inst_1[232:228]),
          .engines$halted_0(signal_inst_1[233:233]),
          .engines$resumed_0(signal_inst_1[234:234]),
          .engines$stepping_0(signal_inst_1[235:235]),
          .engines$irq_0(signal_inst_1[236:236]),
          .engines$fault$underflow_0(signal_inst_1[237:237]),
          .engines$fault$overflow_0(signal_inst_1[238:238]),
          .engines$fault$missed_deadline_0(signal_inst_1[239:239]),
          .engines$fault$decode_0(signal_inst_1[240:240]),
          .engines$capture_0(signal_inst_1[264:241]),
          .engines$capture_armed_0(signal_inst_1[265:265]),
          .engines$tx_level_0(signal_inst_1[269:266]),
          .engines$rx_level_0(signal_inst_1[273:270]),
          .engines$rx_head_0(signal_inst_1[289:274]),
          .engines$instruction_0(signal_inst_1[305:290]),
          .engines$decode_ok_0(signal_inst_1[306:306]),
          .engines$opcode_onehot_0(signal_inst_1[314:307]),
          .engines$crc_0(signal_inst_1[330:315]),
          .engines$stuff_run_0(signal_inst_1[335:331]),
          .engines$pin_out_1(signal_inst_1[363:336]),
          .engines$pin_dir_1(signal_inst_1[391:364]),
          .engines$pc_1(signal_inst_1[400:392]),
          .engines$data_ptr_1(signal_inst_1[409:401]),
          .engines$x_1(signal_inst_1[425:410]),
          .engines$y_1(signal_inst_1[441:426]),
          .engines$p_1(signal_inst_1[457:442]),
          .engines$t_1(signal_inst_1[481:458]),
          .engines$t_fraction_1(signal_inst_1[497:482]),
          .engines$osr_1(signal_inst_1[513:498]),
          .engines$osr_count_1(signal_inst_1[518:514]),
          .engines$isr_1(signal_inst_1[534:519]),
          .engines$isr_count_1(signal_inst_1[539:535]),
          .engines$now_1(signal_inst_1[563:540]),
          .engines$stall_1(signal_inst_1[568:564]),
          .engines$halted_1(signal_inst_1[569:569]),
          .engines$resumed_1(signal_inst_1[570:570]),
          .engines$stepping_1(signal_inst_1[571:571]),
          .engines$irq_1(signal_inst_1[572:572]),
          .engines$fault$underflow_1(signal_inst_1[573:573]),
          .engines$fault$overflow_1(signal_inst_1[574:574]),
          .engines$fault$missed_deadline_1(signal_inst_1[575:575]),
          .engines$fault$decode_1(signal_inst_1[576:576]),
          .engines$capture_1(signal_inst_1[600:577]),
          .engines$capture_armed_1(signal_inst_1[601:601]),
          .engines$tx_level_1(signal_inst_1[605:602]),
          .engines$rx_level_1(signal_inst_1[609:606]),
          .engines$rx_head_1(signal_inst_1[625:610]),
          .engines$instruction_1(signal_inst_1[641:626]),
          .engines$decode_ok_1(signal_inst_1[642:642]),
          .engines$opcode_onehot_1(signal_inst_1[650:643]),
          .engines$crc_1(signal_inst_1[666:651]),
          .engines$stuff_run_1(signal_inst_1[671:667]),
          .pin_out(signal_inst_1[691:672]),
          .pin_dir(signal_inst_1[711:692]) );
    assign signal_select_138 = signal_inst_1[691:672];
    assign signal_select_139 = signal_select_138[11:5];
    assign signal_cat = { signal_select_139,
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

