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
    config$autopull_data,
    config$manchester,
    start,
    program_write$valid,
    program_write$addr,
    program_write$data,
    program_read$valid,
    program_read$value,
    data_word,
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
    data_ptr,
    data_addr,
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
    program_word,
    decode_ok,
    opcode_onehot,
    wait_select,
    crc,
    stuff_run,
    flip_pending,
    flip_bit
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
    input config$autopull_data;
    input config$manchester;
    input start;
    input program_write$valid;
    input [8:0] program_write$addr;
    input [15:0] program_write$data;
    input program_read$valid;
    input [8:0] program_read$value;
    input [15:0] data_word;
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
    output [8:0] data_ptr;
    output [8:0] data_addr;
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
    output [15:0] program_word;
    output decode_ok;
    output [7:0] opcode_onehot;
    output [27:0] wait_select;
    output [15:0] crc;
    output [4:0] stuff_run;
    output flip_pending;
    output flip_bit;

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
    wire [15:0] signal_const_3;
    wire [15:0] signal_select;
    wire signal_select_1;
    wire [15:0] rx_head_0;
    wire [3:0] signal_select_2;
    wire [3:0] signal_select_3;
    wire signal_not;
    wire signal_and;
    wire signal_const_4;
    reg signal_reg;
    wire [23:0] signal_const_5;
    wire [23:0] signal_sub;
    wire signal_eq_3;
    wire signal_not_1;
    wire [23:0] signal_sub_1;
    wire signal_select_4;
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
    wire signal_or_1;
    wire signal_and_9;
    reg signal_reg_3;
    wire signal_wire;
    wire signal_mux;
    wire [3:0] signal_const_10;
    wire signal_eq_4;
    wire signal_and_10;
    wire signal_and_11;
    wire signal_mux_1;
    wire signal_wire_1;
    reg irq_0;
    wire [8:0] signal_const_11;
    wire [8:0] signal_select_5;
    wire [8:0] signal_const_13;
    wire [8:0] signal_add;
    wire [8:0] signal_mux_2;
    wire [8:0] signal_mux_3;
    wire signal_or_2;
    wire [8:0] signal_mux_4;
    wire [8:0] data_ptr_next;
    reg [8:0] signal_reg_4;
    wire [8:0] data_ptr_0;
    wire signal_and_12;
    wire signal_or_3;
    wire [27:0] signal_const_14;
    wire [15:0] signal_select_6;
    wire [11:0] signal_select_7;
    wire [27:0] signal_cat_1;
    wire [7:0] signal_select_8;
    wire [19:0] signal_select_9;
    wire [27:0] signal_cat_2;
    wire [3:0] signal_select_10;
    wire [23:0] signal_select_11;
    wire [27:0] signal_cat_3;
    wire [1:0] signal_select_12;
    wire [25:0] signal_select_13;
    wire [27:0] signal_cat_4;
    wire signal_select_14;
    wire [26:0] signal_select_15;
    wire [27:0] signal_cat_5;
    wire [10:0] signal_const_15;
    wire [15:0] signal_cat_6;
    wire [11:0] signal_const_16;
    wire [27:0] signal_cat_7;
    wire signal_select_16;
    wire [27:0] signal_mux_5;
    wire signal_select_17;
    wire [27:0] signal_mux_6;
    wire signal_select_18;
    wire [27:0] signal_mux_7;
    wire signal_select_19;
    wire [27:0] signal_mux_8;
    wire signal_select_20;
    wire [27:0] signal_mux_9;
    wire [27:0] signal_and_13;
    wire [27:0] signal_const_17;
    wire [15:0] signal_select_21;
    wire [11:0] signal_select_22;
    wire [27:0] signal_cat_8;
    wire [7:0] signal_select_23;
    wire [19:0] signal_select_24;
    wire [27:0] signal_cat_9;
    wire [3:0] signal_select_25;
    wire [23:0] signal_select_26;
    wire [27:0] signal_cat_10;
    wire [1:0] signal_select_27;
    wire [25:0] signal_select_28;
    wire [27:0] signal_cat_11;
    wire signal_select_29;
    wire [26:0] signal_select_30;
    wire [27:0] signal_cat_12;
    wire [7:0] signal_const_19;
    wire [7:0] signal_select_31;
    wire [15:0] signal_cat_13;
    wire [3:0] signal_const_20;
    wire [11:0] signal_select_32;
    wire [15:0] signal_cat_14;
    wire [1:0] signal_const_21;
    wire [13:0] signal_select_33;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_const_22;
    wire [15:0] signal_const_23;
    wire signal_select_34;
    wire [15:0] signal_mux_10;
    wire signal_select_35;
    wire [15:0] signal_mux_11;
    wire signal_select_36;
    wire [15:0] signal_mux_12;
    wire signal_select_37;
    wire [15:0] signal_mux_13;
    wire signal_select_38;
    wire [15:0] signal_mux_14;
    wire [15:0] signal_not_3;
    wire [27:0] signal_cat_16;
    wire signal_select_39;
    wire [27:0] signal_mux_15;
    wire signal_select_40;
    wire [27:0] signal_mux_16;
    wire signal_select_41;
    wire [27:0] signal_mux_17;
    wire signal_select_42;
    wire [27:0] signal_mux_18;
    wire signal_select_43;
    wire [27:0] signal_mux_19;
    wire [27:0] signal_and_14;
    wire [27:0] signal_not_4;
    wire [27:0] signal_and_15;
    wire [27:0] signal_or_4;
    wire [2:0] signal_const_25;
    wire signal_eq_5;
    wire [27:0] signal_mux_20;
    wire [15:0] signal_select_44;
    wire [11:0] signal_select_45;
    wire [27:0] signal_cat_17;
    wire [7:0] signal_select_46;
    wire [19:0] signal_select_47;
    wire [27:0] signal_cat_18;
    wire [3:0] signal_select_48;
    wire [23:0] signal_select_49;
    wire [27:0] signal_cat_19;
    wire [1:0] signal_select_50;
    wire [25:0] signal_select_51;
    wire [27:0] signal_cat_20;
    wire signal_select_52;
    wire [26:0] signal_select_53;
    wire [27:0] signal_cat_21;
    wire [27:0] signal_cat_22;
    wire signal_select_54;
    wire [27:0] signal_mux_21;
    wire signal_select_55;
    wire [27:0] signal_mux_22;
    wire signal_select_56;
    wire [27:0] signal_mux_23;
    wire signal_select_57;
    wire [27:0] signal_mux_24;
    wire signal_select_58;
    wire [27:0] signal_mux_25;
    wire [27:0] signal_and_16;
    wire [15:0] signal_select_59;
    wire [11:0] signal_select_60;
    wire [27:0] signal_cat_23;
    wire [7:0] signal_select_61;
    wire [19:0] signal_select_62;
    wire [27:0] signal_cat_24;
    wire [3:0] signal_select_63;
    wire [23:0] signal_select_64;
    wire [27:0] signal_cat_25;
    wire [1:0] signal_select_65;
    wire [25:0] signal_select_66;
    wire [27:0] signal_cat_26;
    wire signal_select_67;
    wire [26:0] signal_select_68;
    wire [27:0] signal_cat_27;
    wire [7:0] signal_select_69;
    wire [15:0] signal_cat_28;
    wire [11:0] signal_select_70;
    wire [15:0] signal_cat_29;
    wire [13:0] signal_select_71;
    wire [15:0] signal_cat_30;
    wire signal_select_72;
    wire [15:0] signal_mux_26;
    wire signal_select_73;
    wire [15:0] signal_mux_27;
    wire signal_select_74;
    wire [15:0] signal_mux_28;
    wire signal_select_75;
    wire [15:0] signal_mux_29;
    wire signal_select_76;
    wire [15:0] signal_mux_30;
    wire [15:0] signal_not_5;
    wire [27:0] signal_cat_31;
    wire signal_select_77;
    wire [27:0] signal_mux_31;
    wire signal_select_78;
    wire [27:0] signal_mux_32;
    wire signal_select_79;
    wire [27:0] signal_mux_33;
    wire signal_select_80;
    wire [27:0] signal_mux_34;
    wire signal_select_81;
    wire [27:0] signal_mux_35;
    wire [27:0] signal_and_17;
    wire [27:0] signal_not_6;
    wire [27:0] signal_and_18;
    wire [27:0] signal_or_5;
    wire signal_eq_6;
    wire [27:0] signal_mux_36;
    wire [15:0] signal_select_82;
    wire [11:0] signal_select_83;
    wire [27:0] signal_cat_32;
    wire [7:0] signal_select_84;
    wire [19:0] signal_select_85;
    wire [27:0] signal_cat_33;
    wire [3:0] signal_select_86;
    wire [23:0] signal_select_87;
    wire [27:0] signal_cat_34;
    wire [1:0] signal_select_88;
    wire [25:0] signal_select_89;
    wire [27:0] signal_cat_35;
    wire signal_select_90;
    wire [26:0] signal_select_91;
    wire [27:0] signal_cat_36;
    wire signal_not_7;
    wire signal_select_92;
    wire [1:0] signal_cat_37;
    wire [13:0] signal_const_36;
    wire [15:0] signal_cat_38;
    wire [27:0] signal_cat_39;
    wire signal_select_93;
    wire [27:0] signal_mux_37;
    wire signal_select_94;
    wire [27:0] signal_mux_38;
    wire signal_select_95;
    wire [27:0] signal_mux_39;
    wire signal_select_96;
    wire [27:0] signal_mux_40;
    wire signal_select_97;
    wire [27:0] signal_mux_41;
    wire [27:0] signal_and_19;
    wire [15:0] signal_select_98;
    wire [11:0] signal_select_99;
    wire [27:0] signal_cat_40;
    wire [7:0] signal_select_100;
    wire [19:0] signal_select_101;
    wire [27:0] signal_cat_41;
    wire [3:0] signal_select_102;
    wire [23:0] signal_select_103;
    wire [27:0] signal_cat_42;
    wire [1:0] signal_select_104;
    wire [25:0] signal_select_105;
    wire [27:0] signal_cat_43;
    wire [27:0] signal_const_39;
    wire [27:0] signal_const_40;
    wire signal_select_106;
    wire [27:0] signal_mux_42;
    wire signal_select_107;
    wire [27:0] signal_mux_43;
    wire signal_select_108;
    wire [27:0] signal_mux_44;
    wire signal_select_109;
    wire [27:0] signal_mux_45;
    wire signal_select_110;
    wire [27:0] signal_mux_46;
    wire [27:0] signal_and_20;
    wire [27:0] signal_not_8;
    wire [27:0] signal_and_21;
    wire [27:0] signal_or_6;
    wire [15:0] signal_select_111;
    wire [11:0] signal_select_112;
    wire [27:0] signal_cat_44;
    wire [7:0] signal_select_113;
    wire [19:0] signal_select_114;
    wire [27:0] signal_cat_45;
    wire [3:0] signal_select_115;
    wire [23:0] signal_select_116;
    wire [27:0] signal_cat_46;
    wire [1:0] signal_select_117;
    wire [25:0] signal_select_118;
    wire [27:0] signal_cat_47;
    wire signal_select_119;
    wire [26:0] signal_select_120;
    wire [27:0] signal_cat_48;
    wire [27:0] signal_cat_49;
    wire signal_select_121;
    wire [27:0] signal_mux_47;
    wire signal_select_122;
    wire [27:0] signal_mux_48;
    wire signal_select_123;
    wire [27:0] signal_mux_49;
    wire signal_select_124;
    wire [27:0] signal_mux_50;
    wire signal_select_125;
    wire [27:0] signal_mux_51;
    wire [27:0] signal_and_22;
    wire [15:0] signal_select_126;
    wire [11:0] signal_select_127;
    wire [27:0] signal_cat_50;
    wire [7:0] signal_select_128;
    wire [19:0] signal_select_129;
    wire [27:0] signal_cat_51;
    wire [3:0] signal_select_130;
    wire [23:0] signal_select_131;
    wire [27:0] signal_cat_52;
    wire [1:0] signal_select_132;
    wire [25:0] signal_select_133;
    wire [27:0] signal_cat_53;
    wire signal_select_134;
    wire [26:0] signal_select_135;
    wire [27:0] signal_cat_54;
    wire [7:0] signal_select_136;
    wire [15:0] signal_cat_55;
    wire [11:0] signal_select_137;
    wire [15:0] signal_cat_56;
    wire [13:0] signal_select_138;
    wire [15:0] signal_cat_57;
    wire signal_select_139;
    wire [15:0] signal_mux_52;
    wire signal_select_140;
    wire [15:0] signal_mux_53;
    wire signal_select_141;
    wire [15:0] signal_mux_54;
    wire signal_select_142;
    wire [15:0] signal_mux_55;
    wire signal_select_143;
    wire [15:0] signal_mux_56;
    wire [15:0] signal_not_9;
    wire [27:0] signal_cat_58;
    wire signal_select_144;
    wire [27:0] signal_mux_57;
    wire signal_select_145;
    wire [27:0] signal_mux_58;
    wire signal_select_146;
    wire [27:0] signal_mux_59;
    wire signal_select_147;
    wire [27:0] signal_mux_60;
    wire signal_select_148;
    wire [27:0] signal_mux_61;
    wire [27:0] signal_and_23;
    wire [27:0] signal_not_10;
    wire [27:0] signal_and_24;
    wire [27:0] signal_or_7;
    wire [27:0] signal_mux_62;
    wire signal_eq_7;
    wire [27:0] signal_mux_63;
    wire [15:0] signal_select_149;
    wire [11:0] signal_select_150;
    wire [27:0] signal_cat_59;
    wire [7:0] signal_select_151;
    wire [19:0] signal_select_152;
    wire [27:0] signal_cat_60;
    wire [3:0] signal_select_153;
    wire [23:0] signal_select_154;
    wire [27:0] signal_cat_61;
    wire [1:0] signal_select_155;
    wire [25:0] signal_select_156;
    wire [27:0] signal_cat_62;
    wire signal_select_157;
    wire [26:0] signal_select_158;
    wire [27:0] signal_cat_63;
    wire [15:0] signal_cat_64;
    wire [27:0] signal_cat_65;
    wire signal_select_159;
    wire [27:0] signal_mux_64;
    wire signal_select_160;
    wire [27:0] signal_mux_65;
    wire signal_select_161;
    wire [27:0] signal_mux_66;
    wire signal_select_162;
    wire [27:0] signal_mux_67;
    wire signal_select_163;
    wire [27:0] signal_mux_68;
    wire [27:0] signal_and_25;
    wire [15:0] signal_select_164;
    wire [11:0] signal_select_165;
    wire [27:0] signal_cat_66;
    wire [7:0] signal_select_166;
    wire [19:0] signal_select_167;
    wire [27:0] signal_cat_67;
    wire [3:0] signal_select_168;
    wire [23:0] signal_select_169;
    wire [27:0] signal_cat_68;
    wire [1:0] signal_select_170;
    wire [25:0] signal_select_171;
    wire [27:0] signal_cat_69;
    wire signal_select_172;
    wire [26:0] signal_select_173;
    wire [27:0] signal_cat_70;
    wire [7:0] signal_select_174;
    wire [15:0] signal_cat_71;
    wire [11:0] signal_select_175;
    wire [15:0] signal_cat_72;
    wire [13:0] signal_select_176;
    wire [15:0] signal_cat_73;
    wire signal_select_177;
    wire [15:0] signal_mux_69;
    wire signal_select_178;
    wire [15:0] signal_mux_70;
    wire signal_select_179;
    wire [15:0] signal_mux_71;
    wire signal_select_180;
    wire [15:0] signal_mux_72;
    wire signal_select_181;
    wire [15:0] signal_mux_73;
    wire [15:0] signal_not_11;
    wire [27:0] signal_cat_74;
    wire signal_select_182;
    wire [27:0] signal_mux_74;
    wire signal_select_183;
    wire [27:0] signal_mux_75;
    wire signal_select_184;
    wire [27:0] signal_mux_76;
    wire signal_select_185;
    wire [27:0] signal_mux_77;
    wire signal_select_186;
    wire [27:0] signal_mux_78;
    wire [27:0] signal_and_26;
    wire [27:0] signal_not_12;
    wire [27:0] signal_and_27;
    wire [27:0] pin_out_side;
    wire [27:0] pin_out_base;
    reg [27:0] pin_out_next;
    wire [15:0] signal_select_187;
    wire [11:0] signal_select_188;
    wire [27:0] signal_cat_75;
    wire [7:0] signal_select_189;
    wire [19:0] signal_select_190;
    wire [27:0] signal_cat_76;
    wire [3:0] signal_select_191;
    wire [23:0] signal_select_192;
    wire [27:0] signal_cat_77;
    wire [1:0] signal_select_193;
    wire [25:0] signal_select_194;
    wire [27:0] signal_cat_78;
    wire signal_select_195;
    wire [26:0] signal_select_196;
    wire [27:0] signal_cat_79;
    wire signal_not_13;
    wire signal_select_197;
    reg signal_reg_5;
    wire flip_bit_0;
    wire signal_not_14;
    wire [1:0] signal_cat_80;
    wire [15:0] signal_cat_81;
    wire [27:0] signal_cat_82;
    wire signal_select_198;
    wire [27:0] signal_mux_79;
    wire signal_select_199;
    wire [27:0] signal_mux_80;
    wire signal_select_200;
    wire [27:0] signal_mux_81;
    wire signal_select_201;
    wire [27:0] signal_mux_82;
    wire signal_select_202;
    wire [27:0] signal_mux_83;
    wire [27:0] signal_and_28;
    wire [15:0] signal_select_203;
    wire [11:0] signal_select_204;
    wire [27:0] signal_cat_83;
    wire [7:0] signal_select_205;
    wire [19:0] signal_select_206;
    wire [27:0] signal_cat_84;
    wire [3:0] signal_select_207;
    wire [23:0] signal_select_208;
    wire [27:0] signal_cat_85;
    wire [1:0] signal_select_209;
    wire [25:0] signal_select_210;
    wire [27:0] signal_cat_86;
    wire signal_select_211;
    wire [27:0] signal_mux_84;
    wire signal_select_212;
    wire [27:0] signal_mux_85;
    wire signal_select_213;
    wire [27:0] signal_mux_86;
    wire signal_select_214;
    wire [27:0] signal_mux_87;
    wire signal_select_215;
    wire [27:0] signal_mux_88;
    wire [27:0] signal_and_29;
    wire [27:0] signal_not_15;
    wire [27:0] signal_and_30;
    wire [27:0] signal_or_8;
    wire signal_mux_89;
    wire [4:0] signal_const_68;
    wire signal_eq_8;
    wire signal_wire_2;
    wire manchester_out;
    wire signal_eq_9;
    wire signal_and_31;
    wire signal_and_32;
    wire starts_manchester_bit;
    wire signal_mux_90;
    wire signal_mux_91;
    reg signal_reg_6;
    wire flip_pending_0;
    wire [27:0] pin_out_flipped;
    wire signal_not_16;
    wire signal_not_17;
    wire [4:0] signal_const_70;
    wire [4:0] signal_const_74;
    wire [4:0] signal_and_33;
    wire [4:0] signal_and_34;
    wire [4:0] signal_const_76;
    wire [4:0] signal_and_35;
    reg [4:0] d$delay;
    wire [4:0] signal_sub_2;
    wire signal_eq_10;
    wire signal_not_18;
    wire [4:0] signal_mux_92;
    wire [4:0] signal_mux_93;
    wire [4:0] signal_mux_94;
    wire [4:0] stall_next;
    reg [4:0] signal_reg_7;
    wire [4:0] stall_0;
    wire signal_eq_11;
    wire [3:0] signal_const_79;
    wire signal_eq_12;
    wire signal_and_36;
    wire signal_and_37;
    wire signal_mux_95;
    wire [3:0] signal_const_80;
    wire [3:0] signal_select_216;
    wire signal_lt;
    wire [3:0] signal_select_217;
    wire signal_eq_13;
    wire signal_and_38;
    wire [2:0] signal_select_218;
    wire signal_lt_1;
    wire signal_select_219;
    wire signal_not_19;
    wire signal_or_9;
    wire [1:0] signal_const_83;
    wire [1:0] signal_select_220;
    wire signal_lt_2;
    wire signal_and_39;
    wire [2:0] signal_select_221;
    wire signal_lt_3;
    wire [1:0] signal_select_222;
    wire signal_lt_4;
    wire [4:0] signal_const_86;
    wire signal_lt_5;
    wire signal_not_20;
    wire [4:0] signal_select_223;
    wire signal_lt_6;
    wire signal_not_21;
    wire signal_and_40;
    wire signal_eq_14;
    wire signal_eq_15;
    wire [4:0] signal_const_90;
    wire signal_lt_7;
    wire signal_lt_8;
    wire [1:0] signal_select_224;
    reg signal_mux_96;
    wire [3:0] signal_const_92;
    wire [3:0] signal_select_225;
    wire signal_lt_9;
    wire [15:0] signal_wire_3;
    wire [8:0] signal_wire_4;
    wire [8:0] signal_wire_5;
    wire signal_eq_16;
    wire [8:0] signal_mux_97;
    wire [8:0] signal_add_1;
    wire signal_eq_17;
    wire [8:0] signal_mux_98;
    wire [8:0] signal_wire_6;
    wire [8:0] signal_add_2;
    wire [8:0] signal_wire_7;
    wire [8:0] d$jmp_target;
    wire signal_not_22;
    wire signal_not_23;
    wire [4:0] signal_add_3;
    wire [4:0] stuff_run_max;
    wire signal_eq_18;
    wire [4:0] signal_mux_99;
    wire signal_wire_8;
    wire signal_eq_19;
    wire [4:0] signal_mux_100;
    wire [4:0] signal_mux_101;
    wire [3:0] signal_const_106;
    wire signal_eq_20;
    wire signal_and_41;
    wire [4:0] stuff_run_next;
    wire [4:0] signal_mux_102;
    wire [4:0] signal_mux_103;
    reg [4:0] signal_reg_8;
    wire [4:0] stuff_run_0;
    wire signal_lt_10;
    wire signal_not_24;
    wire [4:0] signal_wire_9;
    wire signal_eq_21;
    wire signal_not_25;
    wire signal_and_42;
    wire signal_lt_11;
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
    reg signal_mux_104;
    wire signal_not_26;
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
    wire signal_select_276;
    wire signal_select_277;
    wire signal_select_278;
    wire signal_select_279;
    wire signal_select_280;
    wire signal_select_281;
    wire [4:0] signal_wire_10;
    reg signal_mux_105;
    wire signal_eq_22;
    wire signal_not_27;
    wire signal_eq_23;
    wire signal_not_28;
    wire signal_eq_24;
    wire signal_not_29;
    reg jmp_taken;
    wire [8:0] jmp_target_or_next;
    wire [8:0] signal_mux_106;
    wire [8:0] signal_mux_107;
    wire [8:0] pc_value_next;
    reg [8:0] signal_reg_9;
    wire [8:0] pc_0;
    wire signal_eq_25;
    wire [8:0] pc_next;
    wire [8:0] signal_mux_108;
    wire [8:0] pc_after_next;
    wire signal_or_10;
    reg refill;
    wire signal_not_30;
    wire signal_wire_11;
    wire [15:0] signal_mux_109;
    wire [15:0] signal_wire_12;
    wire signal_not_31;
    wire [3:0] signal_const_111;
    wire signal_eq_26;
    wire signal_and_43;
    wire signal_and_44;
    wire pushes;
    wire signal_and_45;
    wire signal_and_46;
    wire signal_wire_13;
    wire [21:0] signal_inst;
    wire signal_select_282;
    wire signal_not_32;
    wire signal_mux_110;
    wire [23:0] signal_xor;
    wire [23:0] signal_sub_3;
    wire [23:0] signal_cat_87;
    wire [23:0] signal_add_4;
    reg [23:0] signal_mux_111;
    wire signal_eq_27;
    wire [23:0] signal_mux_112;
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
    wire [23:0] signal_cat_88;
    wire [23:0] signal_not_33;
    reg [23:0] mov_value_t;
    wire [2:0] signal_const_115;
    wire signal_eq_28;
    wire [23:0] signal_mux_113;
    wire [23:0] signal_cat_89;
    wire signal_eq_29;
    wire [23:0] signal_mux_114;
    wire [15:0] signal_wire_14;
    wire [16:0] signal_cat_90;
    wire signal_eq_30;
    wire [15:0] signal_mux_115;
    wire signal_eq_31;
    wire [15:0] signal_mux_116;
    wire signal_eq_32;
    wire [15:0] signal_mux_117;
    wire [15:0] signal_select_307;
    wire [15:0] signal_mux_118;
    reg [15:0] t_fraction_next;
    reg [15:0] signal_reg_10;
    wire [15:0] t_fraction_0;
    wire [16:0] signal_cat_91;
    wire [16:0] fraction_sum;
    wire signal_select_308;
    wire [22:0] signal_const_125;
    wire [23:0] signal_cat_92;
    wire [23:0] signal_cat_93;
    wire [23:0] signal_add_5;
    wire [23:0] t_advanced;
    wire [1:0] signal_const_127;
    wire signal_eq_33;
    wire signal_and_47;
    wire releases_deadline;
    wire advances_deadline;
    wire [23:0] signal_mux_119;
    reg [23:0] t_next;
    reg [23:0] signal_reg_11;
    wire [23:0] t_0;
    wire [23:0] signal_sub_4;
    wire signal_select_309;
    wire deadline_ready;
    wire signal_eq_34;
    wire [27:0] signal_and_48;
    wire signal_eq_35;
    wire wait_pin_prev;
    wire signal_eq_36;
    wire signal_not_34;
    wire signal_and_49;
    wire d$wait_polarity;
    wire [27:0] signal_const_130;
    wire signal_and_50;
    wire signal_and_51;
    wire signal_and_52;
    wire signal_and_53;
    wire signal_and_54;
    wire signal_and_55;
    wire signal_and_56;
    wire signal_and_57;
    wire signal_and_58;
    wire signal_and_59;
    wire signal_and_60;
    wire signal_and_61;
    wire signal_and_62;
    wire signal_and_63;
    wire signal_and_64;
    wire signal_not_35;
    wire signal_and_65;
    wire signal_and_66;
    wire signal_and_67;
    wire signal_and_68;
    wire signal_and_69;
    wire signal_and_70;
    wire signal_and_71;
    wire signal_and_72;
    wire signal_and_73;
    wire signal_and_74;
    wire signal_and_75;
    wire signal_and_76;
    wire signal_and_77;
    wire signal_and_78;
    wire signal_and_79;
    wire signal_not_36;
    wire signal_and_80;
    wire signal_and_81;
    wire signal_and_82;
    wire signal_and_83;
    wire signal_and_84;
    wire signal_and_85;
    wire signal_and_86;
    wire signal_and_87;
    wire signal_and_88;
    wire signal_and_89;
    wire signal_and_90;
    wire signal_not_37;
    wire signal_and_91;
    wire signal_and_92;
    wire signal_and_93;
    wire signal_and_94;
    wire signal_and_95;
    wire signal_and_96;
    wire signal_and_97;
    wire signal_not_38;
    wire signal_and_98;
    wire signal_and_99;
    wire signal_and_100;
    wire signal_and_101;
    wire signal_not_39;
    wire signal_and_102;
    wire signal_and_103;
    wire signal_and_104;
    wire signal_and_105;
    wire signal_select_310;
    wire signal_select_311;
    wire signal_and_106;
    wire signal_select_312;
    wire signal_and_107;
    wire signal_select_313;
    wire signal_and_108;
    wire [4:0] signal_select_314;
    wire signal_select_315;
    wire signal_and_109;
    wire [31:0] signal_cat_94;
    wire [27:0] signal_select_316;
    reg [27:0] wait_select_0;
    wire signal_select_317;
    wire signal_select_318;
    wire signal_select_319;
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
    wire signal_mux_120;
    wire signal_select_332;
    wire signal_select_333;
    wire signal_select_334;
    wire signal_mux_121;
    wire signal_select_335;
    wire signal_select_336;
    wire signal_select_337;
    wire signal_mux_122;
    wire signal_select_338;
    wire signal_select_339;
    wire signal_select_340;
    wire signal_mux_123;
    wire signal_select_341;
    wire signal_select_342;
    wire signal_select_343;
    wire signal_mux_124;
    wire signal_select_344;
    wire signal_select_345;
    wire signal_select_346;
    wire signal_mux_125;
    wire signal_select_347;
    wire signal_select_348;
    wire signal_select_349;
    wire signal_mux_126;
    wire signal_select_350;
    wire signal_select_351;
    wire [15:0] signal_select_352;
    wire [11:0] signal_select_353;
    wire [27:0] signal_cat_95;
    wire [7:0] signal_select_354;
    wire [19:0] signal_select_355;
    wire [27:0] signal_cat_96;
    wire [3:0] signal_select_356;
    wire [23:0] signal_select_357;
    wire [27:0] signal_cat_97;
    wire [1:0] signal_select_358;
    wire [25:0] signal_select_359;
    wire [27:0] signal_cat_98;
    wire signal_select_360;
    wire [26:0] signal_select_361;
    wire [27:0] signal_cat_99;
    wire [15:0] signal_cat_100;
    wire [27:0] signal_cat_101;
    wire signal_select_362;
    wire [27:0] signal_mux_127;
    wire signal_select_363;
    wire [27:0] signal_mux_128;
    wire signal_select_364;
    wire [27:0] signal_mux_129;
    wire signal_select_365;
    wire [27:0] signal_mux_130;
    wire signal_select_366;
    wire [27:0] signal_mux_131;
    wire [27:0] signal_and_110;
    wire [27:0] signal_const_134;
    wire [15:0] signal_select_367;
    wire [11:0] signal_select_368;
    wire [27:0] signal_cat_102;
    wire [7:0] signal_select_369;
    wire [19:0] signal_select_370;
    wire [27:0] signal_cat_103;
    wire [3:0] signal_select_371;
    wire [23:0] signal_select_372;
    wire [27:0] signal_cat_104;
    wire [1:0] signal_select_373;
    wire [25:0] signal_select_374;
    wire [27:0] signal_cat_105;
    wire signal_select_375;
    wire [26:0] signal_select_376;
    wire [27:0] signal_cat_106;
    wire [7:0] signal_select_377;
    wire [15:0] signal_cat_107;
    wire [11:0] signal_select_378;
    wire [15:0] signal_cat_108;
    wire [13:0] signal_select_379;
    wire [15:0] signal_cat_109;
    wire signal_select_380;
    wire [15:0] signal_mux_132;
    wire signal_select_381;
    wire [15:0] signal_mux_133;
    wire signal_select_382;
    wire [15:0] signal_mux_134;
    wire signal_select_383;
    wire [15:0] signal_mux_135;
    wire [2:0] signal_wire_15;
    wire [4:0] signal_cat_110;
    wire signal_select_384;
    wire [15:0] signal_mux_136;
    wire [15:0] signal_not_40;
    wire [27:0] signal_cat_111;
    wire signal_select_385;
    wire [27:0] signal_mux_137;
    wire signal_select_386;
    wire [27:0] signal_mux_138;
    wire signal_select_387;
    wire [27:0] signal_mux_139;
    wire signal_select_388;
    wire [27:0] signal_mux_140;
    wire [4:0] signal_wire_16;
    wire signal_select_389;
    wire [27:0] signal_mux_141;
    wire [27:0] signal_and_111;
    wire [27:0] signal_not_41;
    wire [27:0] signal_and_112;
    wire [27:0] signal_or_11;
    wire [2:0] signal_const_143;
    wire signal_eq_37;
    wire [27:0] signal_mux_142;
    wire [15:0] signal_select_390;
    wire [11:0] signal_select_391;
    wire [27:0] signal_cat_112;
    wire [7:0] signal_select_392;
    wire [19:0] signal_select_393;
    wire [27:0] signal_cat_113;
    wire [3:0] signal_select_394;
    wire [23:0] signal_select_395;
    wire [27:0] signal_cat_114;
    wire [1:0] signal_select_396;
    wire [25:0] signal_select_397;
    wire [27:0] signal_cat_115;
    wire signal_select_398;
    wire [26:0] signal_select_399;
    wire [27:0] signal_cat_116;
    wire [27:0] signal_cat_117;
    wire signal_select_400;
    wire [27:0] signal_mux_143;
    wire signal_select_401;
    wire [27:0] signal_mux_144;
    wire signal_select_402;
    wire [27:0] signal_mux_145;
    wire signal_select_403;
    wire [27:0] signal_mux_146;
    wire signal_select_404;
    wire [27:0] signal_mux_147;
    wire [27:0] signal_and_113;
    wire [15:0] signal_select_405;
    wire [11:0] signal_select_406;
    wire [27:0] signal_cat_118;
    wire [7:0] signal_select_407;
    wire [19:0] signal_select_408;
    wire [27:0] signal_cat_119;
    wire [3:0] signal_select_409;
    wire [23:0] signal_select_410;
    wire [27:0] signal_cat_120;
    wire [1:0] signal_select_411;
    wire [25:0] signal_select_412;
    wire [27:0] signal_cat_121;
    wire signal_select_413;
    wire [26:0] signal_select_414;
    wire [27:0] signal_cat_122;
    wire [7:0] signal_select_415;
    wire [15:0] signal_cat_123;
    wire [11:0] signal_select_416;
    wire [15:0] signal_cat_124;
    wire [13:0] signal_select_417;
    wire [15:0] signal_cat_125;
    wire signal_select_418;
    wire [15:0] signal_mux_148;
    wire signal_select_419;
    wire [15:0] signal_mux_149;
    wire signal_select_420;
    wire [15:0] signal_mux_150;
    wire signal_select_421;
    wire [15:0] signal_mux_151;
    wire [4:0] signal_wire_17;
    wire signal_select_422;
    wire [15:0] signal_mux_152;
    wire [15:0] signal_not_42;
    wire [27:0] signal_cat_126;
    wire signal_select_423;
    wire [27:0] signal_mux_153;
    wire signal_select_424;
    wire [27:0] signal_mux_154;
    wire signal_select_425;
    wire [27:0] signal_mux_155;
    wire signal_select_426;
    wire [27:0] signal_mux_156;
    wire signal_select_427;
    wire [27:0] signal_mux_157;
    wire [27:0] signal_and_114;
    wire [27:0] signal_not_43;
    wire [27:0] signal_and_115;
    wire [27:0] signal_or_12;
    wire signal_eq_38;
    wire [27:0] signal_mux_158;
    wire [15:0] signal_select_428;
    wire [11:0] signal_select_429;
    wire [27:0] signal_cat_127;
    wire [7:0] signal_select_430;
    wire [19:0] signal_select_431;
    wire [27:0] signal_cat_128;
    wire [3:0] signal_select_432;
    wire [23:0] signal_select_433;
    wire [27:0] signal_cat_129;
    wire [1:0] signal_select_434;
    wire [25:0] signal_select_435;
    wire [27:0] signal_cat_130;
    wire signal_select_436;
    wire [26:0] signal_select_437;
    wire [27:0] signal_cat_131;
    wire [15:0] signal_and_116;
    wire [7:0] signal_select_438;
    wire [15:0] signal_cat_132;
    wire [11:0] signal_select_439;
    wire [15:0] signal_cat_133;
    wire [13:0] signal_select_440;
    wire [15:0] signal_cat_134;
    wire [14:0] signal_select_441;
    wire [15:0] signal_cat_135;
    wire [15:0] signal_wire_18;
    wire [15:0] signal_select_442;
    wire signal_not_44;
    wire signal_and_117;
    wire [15:0] signal_mux_159;
    wire signal_select_443;
    wire signal_select_444;
    wire signal_select_445;
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
    wire [15:0] signal_cat_136;
    wire [15:0] signal_not_45;
    wire [23:0] signal_cat_137;
    wire [23:0] signal_cat_138;
    wire [23:0] signal_cat_139;
    wire [15:0] signal_xor_1;
    wire [15:0] signal_sub_5;
    wire signal_eq_39;
    wire signal_and_118;
    wire [15:0] signal_mux_160;
    wire signal_eq_40;
    wire [15:0] signal_mux_161;
    wire signal_eq_41;
    wire [15:0] signal_mux_162;
    wire [7:0] signal_select_459;
    wire [15:0] signal_cat_140;
    wire [11:0] signal_select_460;
    wire [15:0] signal_cat_141;
    wire [13:0] signal_select_461;
    wire [15:0] signal_cat_142;
    wire [14:0] signal_select_462;
    wire [15:0] signal_cat_143;
    wire signal_select_463;
    wire [15:0] signal_mux_163;
    wire signal_select_464;
    wire [15:0] signal_mux_164;
    wire signal_select_465;
    wire [15:0] signal_mux_165;
    wire signal_select_466;
    wire [15:0] signal_mux_166;
    wire signal_select_467;
    wire [15:0] signal_mux_167;
    wire [7:0] signal_select_468;
    wire [15:0] signal_cat_144;
    wire [11:0] signal_select_469;
    wire [15:0] signal_cat_145;
    wire [13:0] signal_select_470;
    wire [15:0] signal_cat_146;
    wire [14:0] signal_select_471;
    wire [15:0] signal_cat_147;
    wire signal_select_472;
    wire [15:0] signal_mux_168;
    wire signal_select_473;
    wire [15:0] signal_mux_169;
    wire signal_select_474;
    wire [15:0] signal_mux_170;
    wire signal_select_475;
    wire [15:0] signal_mux_171;
    wire signal_select_476;
    wire [15:0] signal_mux_172;
    wire [15:0] signal_or_13;
    wire [7:0] signal_select_477;
    wire [15:0] signal_cat_148;
    wire [11:0] signal_select_478;
    wire [15:0] signal_cat_149;
    wire [13:0] signal_select_479;
    wire [15:0] signal_cat_150;
    wire signal_select_480;
    wire [15:0] signal_mux_173;
    wire signal_select_481;
    wire [15:0] signal_mux_174;
    wire signal_select_482;
    wire [15:0] signal_mux_175;
    wire signal_select_483;
    wire [15:0] signal_mux_176;
    wire signal_select_484;
    wire [15:0] signal_mux_177;
    wire [15:0] mask;
    wire signal_wire_19;
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
    reg signal_mux_178;
    wire signal_eq_42;
    wire signal_select_513;
    wire signal_select_514;
    wire signal_select_515;
    wire signal_select_516;
    wire signal_select_517;
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
    wire signal_select_534;
    wire signal_select_535;
    wire signal_select_536;
    wire signal_select_537;
    wire signal_select_538;
    wire signal_select_539;
    reg [27:0] signal_reg_12;
    wire [27:0] pins_sampled;
    wire signal_select_540;
    reg signal_mux_179;
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
    wire signal_select_552;
    wire signal_select_553;
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
    wire [4:0] signal_wire_20;
    reg signal_mux_180;
    wire signal_eq_43;
    wire signal_not_46;
    wire [3:0] signal_const_189;
    wire signal_eq_44;
    wire signal_and_119;
    wire signal_and_120;
    wire signal_mux_181;
    wire signal_mux_182;
    reg signal_reg_13;
    wire capture_armed_0;
    wire signal_and_121;
    wire captured;
    wire [23:0] signal_const_193;
    wire [23:0] signal_add_6;
    wire [23:0] signal_mux_183;
    reg [23:0] signal_reg_14;
    wire [23:0] now_0;
    reg [23:0] signal_reg_15;
    wire [23:0] capture_0;
    wire [15:0] signal_select_569;
    wire [15:0] signal_wire_21;
    wire [7:0] signal_select_570;
    wire [15:0] signal_cat_151;
    wire [11:0] signal_select_571;
    wire [15:0] signal_cat_152;
    wire [13:0] signal_select_572;
    wire [15:0] signal_cat_153;
    wire signal_select_573;
    wire [15:0] signal_mux_184;
    wire signal_select_574;
    wire [15:0] signal_mux_185;
    wire signal_select_575;
    wire [15:0] signal_mux_186;
    wire signal_select_576;
    wire [15:0] signal_mux_187;
    wire signal_select_577;
    wire [15:0] signal_mux_188;
    wire [15:0] signal_not_47;
    wire [15:0] signal_xor_2;
    wire [14:0] signal_select_578;
    wire [15:0] signal_cat_154;
    wire signal_select_579;
    wire signal_xor_3;
    wire [15:0] signal_mux_189;
    wire [15:0] signal_wire_22;
    wire [15:0] signal_xor_4;
    wire [14:0] signal_select_580;
    wire [15:0] signal_cat_155;
    wire signal_select_581;
    wire signal_select_582;
    wire crossing_bit;
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
    wire signal_select_593;
    wire signal_select_594;
    wire signal_select_595;
    wire signal_select_596;
    wire signal_select_597;
    wire signal_select_598;
    wire [4:0] signal_wire_23;
    wire [4:0] signal_sub_6;
    reg signal_mux_190;
    wire signal_xor_5;
    wire [15:0] signal_mux_191;
    wire signal_wire_24;
    wire [15:0] signal_mux_192;
    wire [15:0] crc_stepped;
    wire [2:0] signal_const_204;
    wire signal_eq_45;
    reg is_opcode$2;
    wire signal_or_14;
    wire signal_eq_46;
    wire bit_crosses;
    wire [15:0] signal_mux_193;
    wire [3:0] signal_const_206;
    wire signal_eq_47;
    wire signal_and_122;
    wire [15:0] crc_next;
    wire [15:0] signal_mux_194;
    wire [15:0] signal_mux_195;
    reg [15:0] signal_reg_16;
    wire [15:0] crc_0;
    wire [7:0] signal_select_599;
    wire [15:0] signal_cat_156;
    wire [11:0] signal_select_600;
    wire [15:0] signal_cat_157;
    wire [13:0] signal_select_601;
    wire [15:0] signal_cat_158;
    wire signal_select_602;
    wire [15:0] signal_mux_196;
    wire signal_select_603;
    wire [15:0] signal_mux_197;
    wire signal_select_604;
    wire [15:0] signal_mux_198;
    wire signal_select_605;
    wire [15:0] signal_mux_199;
    wire signal_select_606;
    wire [15:0] signal_mux_200;
    wire [15:0] signal_not_48;
    wire [11:0] signal_select_607;
    wire [15:0] signal_select_608;
    wire [27:0] signal_cat_159;
    wire [19:0] signal_select_609;
    wire [7:0] signal_select_610;
    wire [27:0] signal_cat_160;
    wire [23:0] signal_select_611;
    wire [3:0] signal_select_612;
    wire [27:0] signal_cat_161;
    wire [25:0] signal_select_613;
    wire [1:0] signal_select_614;
    wire [27:0] signal_cat_162;
    wire [26:0] signal_select_615;
    wire signal_select_616;
    wire [27:0] signal_cat_163;
    wire signal_select_617;
    wire [27:0] signal_mux_201;
    wire signal_select_618;
    wire [27:0] signal_mux_202;
    wire signal_select_619;
    wire [27:0] signal_mux_203;
    wire signal_select_620;
    wire [27:0] signal_mux_204;
    wire signal_select_621;
    wire [27:0] signal_mux_205;
    wire [15:0] signal_select_622;
    wire [15:0] signal_and_123;
    reg [15:0] signal_mux_206;
    wire [15:0] in_value;
    wire [7:0] signal_select_623;
    wire [15:0] signal_cat_164;
    wire [11:0] signal_select_624;
    wire [15:0] signal_cat_165;
    wire [13:0] signal_select_625;
    wire [15:0] signal_cat_166;
    wire [14:0] signal_select_626;
    wire [15:0] signal_cat_167;
    wire signal_select_627;
    wire [15:0] signal_mux_207;
    wire signal_select_628;
    wire [15:0] signal_mux_208;
    wire signal_select_629;
    wire [15:0] signal_mux_209;
    wire signal_select_630;
    wire [15:0] signal_mux_210;
    wire signal_select_631;
    wire [15:0] signal_mux_211;
    wire [15:0] signal_or_15;
    wire signal_wire_25;
    wire [15:0] isr_shifted;
    wire [4:0] signal_wire_26;
    wire [4:0] signal_select_632;
    wire [5:0] signal_cat_168;
    wire signal_eq_48;
    wire signal_and_124;
    wire [4:0] signal_mux_212;
    wire signal_eq_49;
    wire [4:0] signal_mux_213;
    wire signal_eq_50;
    wire [4:0] signal_mux_214;
    wire [4:0] signal_mux_215;
    reg [4:0] isr_count_next_value;
    reg [4:0] signal_reg_17;
    wire [4:0] isr_count_0;
    wire [5:0] signal_cat_169;
    wire [5:0] signal_add_7;
    wire [5:0] signal_const_224;
    wire signal_lt_12;
    wire [4:0] isr_count_next;
    wire signal_lt_13;
    wire signal_not_49;
    wire signal_wire_27;
    wire autopush_now;
    wire [15:0] signal_mux_216;
    reg [15:0] isr_next;
    reg [15:0] signal_reg_18;
    wire [15:0] isr_0;
    wire [15:0] signal_xor_6;
    wire [15:0] signal_sub_7;
    wire [15:0] signal_add_8;
    reg [15:0] signal_mux_217;
    wire signal_eq_51;
    wire [15:0] signal_mux_218;
    wire [15:0] signal_cat_170;
    wire signal_eq_52;
    wire [15:0] signal_mux_219;
    wire signal_eq_53;
    wire [15:0] signal_mux_220;
    wire signal_eq_54;
    wire [15:0] signal_mux_221;
    reg [15:0] p_next;
    reg [15:0] signal_reg_19;
    wire [15:0] p_0;
    wire [15:0] signal_xor_7;
    wire [15:0] signal_sub_8;
    wire [15:0] signal_add_9;
    reg [15:0] signal_mux_222;
    wire [1:0] signal_const_232;
    wire signal_eq_55;
    wire [15:0] signal_mux_223;
    wire [15:0] signal_cat_171;
    wire signal_eq_56;
    wire [15:0] signal_mux_224;
    wire signal_eq_57;
    wire [15:0] signal_mux_225;
    wire signal_eq_58;
    wire [15:0] signal_mux_226;
    wire [15:0] signal_const_237;
    wire [15:0] signal_sub_9;
    wire signal_eq_59;
    wire [15:0] signal_mux_227;
    reg [15:0] y_next;
    reg [15:0] signal_reg_20;
    wire [15:0] y_0;
    reg [15:0] signal_mux_228;
    wire [2:0] d$alu_reg$binary_variant;
    wire [2:0] d$alu_imm;
    wire [12:0] signal_const_239;
    wire [15:0] signal_cat_172;
    wire d$alu_is_reg;
    wire [15:0] alu_operand;
    wire [15:0] signal_add_10;
    wire [1:0] d$alu_op$binary_variant;
    reg [15:0] signal_mux_229;
    wire [1:0] d$alu_dest$binary_variant;
    wire signal_eq_60;
    wire [15:0] signal_mux_230;
    wire [4:0] d$set_value;
    wire [15:0] signal_cat_173;
    wire [2:0] signal_const_242;
    wire [2:0] d$set_dest$binary_variant;
    wire signal_eq_61;
    wire [15:0] signal_mux_231;
    wire signal_eq_62;
    wire [15:0] signal_mux_232;
    wire signal_eq_63;
    wire [15:0] signal_mux_233;
    wire [15:0] signal_sub_10;
    wire [3:0] d$jmp_cond$binary_variant;
    wire signal_eq_64;
    wire [15:0] signal_mux_234;
    reg [15:0] x_next;
    reg [15:0] signal_reg_21;
    wire [15:0] x_0;
    wire [23:0] signal_cat_174;
    wire [7:0] signal_select_633;
    wire [15:0] signal_cat_175;
    wire [11:0] signal_select_634;
    wire [15:0] signal_cat_176;
    wire [13:0] signal_select_635;
    wire [15:0] signal_cat_177;
    wire signal_select_636;
    wire [15:0] signal_mux_235;
    wire signal_select_637;
    wire [15:0] signal_mux_236;
    wire signal_select_638;
    wire [15:0] signal_mux_237;
    wire signal_select_639;
    wire [15:0] signal_mux_238;
    wire [4:0] signal_wire_28;
    wire signal_select_640;
    wire [15:0] signal_mux_239;
    wire [15:0] signal_not_50;
    wire [11:0] signal_select_641;
    wire [15:0] signal_select_642;
    wire [27:0] signal_cat_178;
    wire [19:0] signal_select_643;
    wire [7:0] signal_select_644;
    wire [27:0] signal_cat_179;
    wire [23:0] signal_select_645;
    wire [3:0] signal_select_646;
    wire [27:0] signal_cat_180;
    wire [25:0] signal_select_647;
    wire [1:0] signal_select_648;
    wire [27:0] signal_cat_181;
    wire [26:0] signal_select_649;
    wire signal_select_650;
    wire [27:0] signal_cat_182;
    wire signal_select_651;
    wire [27:0] signal_mux_240;
    wire signal_select_652;
    wire [27:0] signal_mux_241;
    wire signal_select_653;
    wire [27:0] signal_mux_242;
    wire signal_select_654;
    wire [27:0] signal_mux_243;
    wire [4:0] signal_wire_29;
    wire signal_select_655;
    wire [27:0] signal_mux_244;
    wire [15:0] signal_select_656;
    wire [15:0] signal_and_125;
    wire [23:0] signal_cat_183;
    wire [2:0] d$mov_source$binary_variant;
    reg [23:0] mov_value24;
    wire [15:0] signal_select_657;
    wire [1:0] d$mov_op$binary_variant;
    reg [15:0] mov_value;
    wire signal_eq_65;
    wire [15:0] signal_mux_245;
    wire [7:0] signal_select_658;
    wire [15:0] signal_cat_184;
    wire [11:0] signal_select_659;
    wire [15:0] signal_cat_185;
    wire [13:0] signal_select_660;
    wire [15:0] signal_cat_186;
    wire [14:0] signal_select_661;
    wire [15:0] signal_cat_187;
    wire signal_select_662;
    wire [15:0] signal_mux_246;
    wire signal_select_663;
    wire [15:0] signal_mux_247;
    wire signal_select_664;
    wire [15:0] signal_mux_248;
    wire signal_select_665;
    wire [15:0] signal_mux_249;
    wire signal_select_666;
    wire [15:0] signal_mux_250;
    wire [7:0] signal_select_667;
    wire [15:0] signal_cat_188;
    wire [11:0] signal_select_668;
    wire [15:0] signal_cat_189;
    wire [13:0] signal_select_669;
    wire [15:0] signal_cat_190;
    wire [14:0] signal_select_670;
    wire [15:0] signal_cat_191;
    wire signal_select_671;
    wire [15:0] signal_mux_251;
    wire signal_select_672;
    wire [15:0] signal_mux_252;
    wire signal_select_673;
    wire [15:0] signal_mux_253;
    wire signal_select_674;
    wire [15:0] signal_mux_254;
    wire signal_select_675;
    wire [15:0] signal_mux_255;
    wire [15:0] osr_shifted;
    reg [15:0] osr_next;
    reg [15:0] signal_reg_22;
    wire [15:0] osr_0;
    wire signal_wire_30;
    wire flush_0;
    wire signal_not_51;
    wire signal_and_126;
    wire signal_and_127;
    wire signal_or_16;
    wire signal_and_128;
    wire tx_pop;
    wire [15:0] signal_wire_31;
    wire signal_wire_32;
    wire [21:0] signal_inst_1;
    wire signal_select_676;
    wire signal_not_52;
    wire signal_not_53;
    wire pull_fifo;
    wire pull_ok;
    wire [15:0] signal_mux_256;
    wire signal_eq_66;
    reg is_opcode$3;
    wire signal_and_129;
    wire pulls_data;
    wire [3:0] signal_const_268;
    wire signal_eq_67;
    wire signal_and_130;
    wire seeks;
    wire signal_or_17;
    wire signal_mux_257;
    reg signal_reg_23;
    wire data_moved;
    wire signal_not_54;
    wire signal_wire_33;
    wire [4:0] signal_wire_34;
    wire [3:0] signal_const_270;
    wire [3:0] d$sys_op$binary_variant;
    wire signal_eq_68;
    wire signal_eq_69;
    reg is_opcode$7;
    wire pulls;
    wire [4:0] signal_mux_258;
    wire [4:0] osr_count_zero;
    wire [2:0] d$mov_dest$binary_variant;
    wire signal_eq_70;
    wire [4:0] signal_mux_259;
    wire [4:0] signal_select_677;
    wire [5:0] signal_cat_192;
    wire [4:0] osr_count_before;
    wire [5:0] signal_cat_193;
    wire [5:0] signal_add_11;
    wire signal_lt_14;
    wire [4:0] osr_count_next;
    reg [4:0] osr_count_next_value;
    reg [4:0] signal_reg_24;
    wire [4:0] osr_count_0;
    wire signal_lt_15;
    wire signal_not_55;
    wire signal_wire_35;
    wire pull_now;
    wire pull_data;
    wire pull_data_ok;
    wire [15:0] osr_before;
    wire signal_select_678;
    wire [15:0] signal_mux_260;
    wire signal_select_679;
    wire [15:0] signal_mux_261;
    wire signal_select_680;
    wire [15:0] signal_mux_262;
    wire signal_select_681;
    wire [15:0] signal_mux_263;
    wire [4:0] shift_back;
    wire signal_select_682;
    wire [15:0] signal_mux_264;
    wire [15:0] signal_and_131;
    wire signal_wire_36;
    wire [15:0] out_value;
    wire [27:0] signal_cat_194;
    wire signal_select_683;
    wire [27:0] signal_mux_265;
    wire signal_select_684;
    wire [27:0] signal_mux_266;
    wire signal_select_685;
    wire [27:0] signal_mux_267;
    wire signal_select_686;
    wire [27:0] signal_mux_268;
    wire signal_select_687;
    wire [27:0] signal_mux_269;
    wire [27:0] signal_and_132;
    wire [15:0] signal_select_688;
    wire [11:0] signal_select_689;
    wire [27:0] signal_cat_195;
    wire [7:0] signal_select_690;
    wire [19:0] signal_select_691;
    wire [27:0] signal_cat_196;
    wire [3:0] signal_select_692;
    wire [23:0] signal_select_693;
    wire [27:0] signal_cat_197;
    wire [1:0] signal_select_694;
    wire [25:0] signal_select_695;
    wire [27:0] signal_cat_198;
    wire signal_select_696;
    wire [26:0] signal_select_697;
    wire [27:0] signal_cat_199;
    wire [7:0] signal_select_698;
    wire [15:0] signal_cat_200;
    wire [11:0] signal_select_699;
    wire [15:0] signal_cat_201;
    wire [13:0] signal_select_700;
    wire [15:0] signal_cat_202;
    wire signal_select_701;
    wire [15:0] signal_mux_270;
    wire signal_select_702;
    wire [15:0] signal_mux_271;
    wire signal_select_703;
    wire [15:0] signal_mux_272;
    wire signal_select_704;
    wire [15:0] signal_mux_273;
    wire [4:0] d$shift_count;
    wire signal_select_705;
    wire [15:0] signal_mux_274;
    wire [15:0] signal_not_56;
    wire [27:0] signal_cat_203;
    wire signal_select_706;
    wire [27:0] signal_mux_275;
    wire signal_select_707;
    wire [27:0] signal_mux_276;
    wire signal_select_708;
    wire [27:0] signal_mux_277;
    wire signal_select_709;
    wire [27:0] signal_mux_278;
    wire [4:0] signal_wire_37;
    wire signal_select_710;
    wire [27:0] signal_mux_279;
    wire [27:0] signal_and_133;
    wire [27:0] signal_not_57;
    wire [27:0] signal_and_134;
    wire [27:0] signal_or_18;
    wire [2:0] d$out_dest$binary_variant;
    wire [2:0] d$in_source$binary_variant;
    wire signal_eq_71;
    wire [27:0] signal_mux_280;
    wire [15:0] signal_select_711;
    wire [11:0] signal_select_712;
    wire [27:0] signal_cat_204;
    wire [7:0] signal_select_713;
    wire [19:0] signal_select_714;
    wire [27:0] signal_cat_205;
    wire [3:0] signal_select_715;
    wire [23:0] signal_select_716;
    wire [27:0] signal_cat_206;
    wire [1:0] signal_select_717;
    wire [25:0] signal_select_718;
    wire [27:0] signal_cat_207;
    wire signal_select_719;
    wire [26:0] signal_select_720;
    wire [27:0] signal_cat_208;
    wire [1:0] signal_select_721;
    wire [1:0] signal_select_722;
    wire [4:0] signal_select_723;
    wire signal_select_724;
    wire [1:0] signal_cat_209;
    reg [1:0] d$side_set;
    wire [15:0] signal_cat_210;
    wire [27:0] signal_cat_211;
    wire signal_select_725;
    wire [27:0] signal_mux_281;
    wire signal_select_726;
    wire [27:0] signal_mux_282;
    wire signal_select_727;
    wire [27:0] signal_mux_283;
    wire signal_select_728;
    wire [27:0] signal_mux_284;
    wire signal_select_729;
    wire [27:0] signal_mux_285;
    wire [27:0] signal_and_135;
    wire [15:0] signal_select_730;
    wire [11:0] signal_select_731;
    wire [27:0] signal_cat_212;
    wire [7:0] signal_select_732;
    wire [19:0] signal_select_733;
    wire [27:0] signal_cat_213;
    wire [3:0] signal_select_734;
    wire [23:0] signal_select_735;
    wire [27:0] signal_cat_214;
    wire [1:0] signal_select_736;
    wire [25:0] signal_select_737;
    wire [27:0] signal_cat_215;
    wire signal_select_738;
    wire [26:0] signal_select_739;
    wire [27:0] signal_cat_216;
    wire [7:0] signal_select_740;
    wire [15:0] signal_cat_217;
    wire [11:0] signal_select_741;
    wire [15:0] signal_cat_218;
    wire [13:0] signal_select_742;
    wire [15:0] signal_cat_219;
    wire signal_select_743;
    wire [15:0] signal_mux_286;
    wire signal_select_744;
    wire [15:0] signal_mux_287;
    wire signal_select_745;
    wire [15:0] signal_mux_288;
    wire signal_select_746;
    wire [15:0] signal_mux_289;
    wire [1:0] signal_wire_38;
    wire [4:0] signal_cat_220;
    wire signal_select_747;
    wire [15:0] signal_mux_290;
    wire [15:0] signal_not_58;
    wire [27:0] signal_cat_221;
    wire signal_select_748;
    wire [27:0] signal_mux_291;
    wire signal_select_749;
    wire [27:0] signal_mux_292;
    wire signal_select_750;
    wire [27:0] signal_mux_293;
    wire signal_select_751;
    wire [27:0] signal_mux_294;
    wire [4:0] signal_wire_39;
    wire signal_select_752;
    wire [27:0] signal_mux_295;
    wire [27:0] signal_and_136;
    wire [27:0] signal_not_59;
    wire [27:0] signal_and_137;
    wire [27:0] pin_dir_side;
    wire signal_wire_40;
    wire [27:0] pin_dir_base;
    wire [2:0] d$opcode$binary_variant;
    reg [27:0] pin_dir_next;
    reg [27:0] signal_reg_25;
    wire [27:0] pin_dir_0;
    wire signal_select_753;
    wire signal_mux_296;
    wire signal_select_754;
    wire signal_select_755;
    wire signal_or_19;
    wire signal_select_756;
    wire signal_select_757;
    wire signal_or_20;
    wire signal_select_758;
    wire signal_select_759;
    wire signal_or_21;
    wire signal_select_760;
    wire signal_select_761;
    wire signal_or_22;
    wire signal_select_762;
    wire signal_select_763;
    wire signal_or_23;
    wire signal_select_764;
    wire signal_select_765;
    wire signal_or_24;
    wire signal_select_766;
    wire signal_select_767;
    wire signal_or_25;
    wire [27:0] signal_wire_41;
    wire signal_select_768;
    wire signal_select_769;
    wire signal_or_26;
    wire [27:0] sample;
    wire [27:0] signal_and_138;
    wire signal_eq_72;
    wire wait_pin_cur;
    wire signal_eq_73;
    reg [15:0] word;
    wire [1:0] d$wait_source$binary_variant;
    reg wait_ready;
    wire signal_not_60;
    wire gnd;
    wire signal_eq_74;
    reg is_opcode$1;
    wire wait_holds;
    wire signal_not_61;
    wire advance;
    wire signal_or_27;
    wire ir_load;
    wire signal_eq_75;
    reg is_opcode$0;
    wire jmp_go;
    wire [8:0] signal_mux_297;
    wire [8:0] signal_mux_298;
    wire [8:0] fetch_addr;
    wire signal_wire_42;
    wire program_read;
    wire [8:0] signal_mux_299;
    wire [8:0] signal_mux_300;
    wire signal_wire_43;
    wire program_write;
    wire vdd;
    wire [15:0] signal_inst_2;
    wire [15:0] signal_wire_44;
    wire [2:0] signal_select_770;
    reg signal_mux_301;
    reg decode_ok_0;
    wire signal_not_62;
    wire signal_and_139;
    wire signal_mux_302;
    wire signal_wire_45;
    wire signal_mux_303;
    wire signal_wire_46;
    wire signal_wire_47;
    wire signal_wire_48;
    reg start_0;
    wire halted_next;
    reg signal_reg_26;
    wire halted_0;
    wire signal_not_63;
    wire signal_and_140;
    wire issue;
    wire go;
    wire op_go;
    wire [27:0] signal_mux_304;
    reg [27:0] signal_reg_27;
    wire [27:0] pin_out_0;
    assign signal_const = 3'b100;
    assign signal_eq = signal_select_770 == signal_const;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            is_opcode$4 <= gnd;
        else
            if (ir_load)
                is_opcode$4 <= signal_eq;
    end
    assign signal_const_1 = 3'b101;
    assign signal_eq_1 = signal_select_770 == signal_const_1;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            is_opcode$5 <= gnd;
        else
            if (ir_load)
                is_opcode$5 <= signal_eq_1;
    end
    assign signal_const_2 = 3'b110;
    assign signal_eq_2 = signal_select_770 == signal_const_2;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
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
    assign signal_const_3 = 16'b0000000000000000;
    assign signal_select = signal_inst[15:0];
    assign signal_select_1 = signal_inst[20:20];
    assign rx_head_0 = signal_select_1 ? signal_const_3 : signal_select;
    assign signal_select_2 = signal_inst[19:16];
    assign signal_select_3 = signal_inst_1[19:16];
    assign signal_not = ~ decode_ok_0;
    assign signal_and = issue & signal_not;
    assign signal_const_4 = 1'b0;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg <= signal_const_4;
        else
            if (signal_and)
                signal_reg <= vdd;
    end
    assign signal_const_5 = 24'b000000000000000000000000;
    assign signal_sub = now_0 - t_0;
    assign signal_eq_3 = signal_sub == signal_const_5;
    assign signal_not_1 = ~ signal_eq_3;
    assign signal_sub_1 = now_0 - t_0;
    assign signal_select_4 = signal_sub_1[23:23];
    assign signal_not_2 = ~ signal_select_4;
    assign deadline_late = signal_not_2 & signal_not_1;
    assign signal_and_1 = op_go & releases_deadline;
    assign signal_and_2 = signal_and_1 & deadline_late;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_1 <= signal_const_4;
        else
            if (signal_and_2)
                signal_reg_1 <= vdd;
    end
    assign signal_and_3 = op_go & pushes;
    assign signal_and_4 = signal_and_3 & signal_select_282;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_2 <= signal_const_4;
        else
            if (signal_and_4)
                signal_reg_2 <= vdd;
    end
    assign signal_and_5 = pulls & signal_select_676;
    assign signal_and_6 = pull_data & data_moved;
    assign signal_and_7 = pull_fifo & signal_select_676;
    assign signal_or = signal_and_7 | signal_and_6;
    assign signal_and_8 = is_opcode$3 & signal_or;
    assign signal_or_1 = signal_and_8 | signal_and_5;
    assign signal_and_9 = op_go & signal_or_1;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_3 <= signal_const_4;
        else
            if (signal_and_9)
                signal_reg_3 <= vdd;
    end
    assign signal_wire = clear_irq;
    assign signal_mux = signal_wire ? gnd : irq_0;
    assign signal_const_10 = 4'b0010;
    assign signal_eq_4 = d$sys_op$binary_variant == signal_const_10;
    assign signal_and_10 = is_opcode$7 & signal_eq_4;
    assign signal_and_11 = op_go & signal_and_10;
    assign signal_mux_1 = signal_and_11 ? vdd : signal_mux;
    assign signal_wire_1 = signal_mux_1;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            irq_0 <= signal_const_4;
        else
            irq_0 <= signal_wire_1;
    end
    assign signal_const_11 = 9'b000000000;
    assign signal_select_5 = x_0[8:0];
    assign signal_const_13 = 9'b000000001;
    assign signal_add = data_ptr_0 + signal_const_13;
    assign signal_mux_2 = pulls_data ? signal_add : data_ptr_0;
    assign signal_mux_3 = seeks ? signal_select_5 : signal_mux_2;
    assign signal_or_2 = signal_wire_48 | start_0;
    assign signal_mux_4 = signal_or_2 ? signal_const_11 : signal_mux_3;
    assign data_ptr_next = signal_mux_4;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_4 <= signal_const_11;
        else
            signal_reg_4 <= data_ptr_next;
    end
    assign data_ptr_0 = signal_reg_4;
    assign signal_and_12 = issue & flip_pending_0;
    assign signal_or_3 = op_go | signal_and_12;
    assign signal_const_14 = 28'b0000000000000000000000000000;
    assign signal_select_6 = signal_mux_8[27:12];
    assign signal_select_7 = signal_mux_8[11:0];
    assign signal_cat_1 = { signal_select_7,
                            signal_select_6 };
    assign signal_select_8 = signal_mux_7[27:20];
    assign signal_select_9 = signal_mux_7[19:0];
    assign signal_cat_2 = { signal_select_9,
                            signal_select_8 };
    assign signal_select_10 = signal_mux_6[27:24];
    assign signal_select_11 = signal_mux_6[23:0];
    assign signal_cat_3 = { signal_select_11,
                            signal_select_10 };
    assign signal_select_12 = signal_mux_5[27:26];
    assign signal_select_13 = signal_mux_5[25:0];
    assign signal_cat_4 = { signal_select_13,
                            signal_select_12 };
    assign signal_select_14 = signal_cat_7[27:27];
    assign signal_select_15 = signal_cat_7[26:0];
    assign signal_cat_5 = { signal_select_15,
                            signal_select_14 };
    assign signal_const_15 = 11'b00000000000;
    assign signal_cat_6 = { signal_const_15,
                            d$set_value };
    assign signal_const_16 = 12'b000000000000;
    assign signal_cat_7 = { signal_const_16,
                            signal_cat_6 };
    assign signal_select_16 = signal_wire_16[0:0];
    assign signal_mux_5 = signal_select_16 ? signal_cat_5 : signal_cat_7;
    assign signal_select_17 = signal_wire_16[1:1];
    assign signal_mux_6 = signal_select_17 ? signal_cat_4 : signal_mux_5;
    assign signal_select_18 = signal_wire_16[2:2];
    assign signal_mux_7 = signal_select_18 ? signal_cat_3 : signal_mux_6;
    assign signal_select_19 = signal_wire_16[3:3];
    assign signal_mux_8 = signal_select_19 ? signal_cat_2 : signal_mux_7;
    assign signal_select_20 = signal_wire_16[4:4];
    assign signal_mux_9 = signal_select_20 ? signal_cat_1 : signal_mux_8;
    assign signal_and_13 = signal_mux_9 & signal_and_14;
    assign signal_const_17 = 28'b1111111111111111111111100000;
    assign signal_select_21 = signal_mux_18[27:12];
    assign signal_select_22 = signal_mux_18[11:0];
    assign signal_cat_8 = { signal_select_22,
                            signal_select_21 };
    assign signal_select_23 = signal_mux_17[27:20];
    assign signal_select_24 = signal_mux_17[19:0];
    assign signal_cat_9 = { signal_select_24,
                            signal_select_23 };
    assign signal_select_25 = signal_mux_16[27:24];
    assign signal_select_26 = signal_mux_16[23:0];
    assign signal_cat_10 = { signal_select_26,
                             signal_select_25 };
    assign signal_select_27 = signal_mux_15[27:26];
    assign signal_select_28 = signal_mux_15[25:0];
    assign signal_cat_11 = { signal_select_28,
                             signal_select_27 };
    assign signal_select_29 = signal_cat_16[27:27];
    assign signal_select_30 = signal_cat_16[26:0];
    assign signal_cat_12 = { signal_select_30,
                             signal_select_29 };
    assign signal_const_19 = 8'b00000000;
    assign signal_select_31 = signal_mux_12[7:0];
    assign signal_cat_13 = { signal_select_31,
                             signal_const_19 };
    assign signal_const_20 = 4'b0000;
    assign signal_select_32 = signal_mux_11[11:0];
    assign signal_cat_14 = { signal_select_32,
                             signal_const_20 };
    assign signal_const_21 = 2'b00;
    assign signal_select_33 = signal_mux_10[13:0];
    assign signal_cat_15 = { signal_select_33,
                             signal_const_21 };
    assign signal_const_22 = 16'b1111111111111110;
    assign signal_const_23 = 16'b1111111111111111;
    assign signal_select_34 = signal_cat_110[0:0];
    assign signal_mux_10 = signal_select_34 ? signal_const_22 : signal_const_23;
    assign signal_select_35 = signal_cat_110[1:1];
    assign signal_mux_11 = signal_select_35 ? signal_cat_15 : signal_mux_10;
    assign signal_select_36 = signal_cat_110[2:2];
    assign signal_mux_12 = signal_select_36 ? signal_cat_14 : signal_mux_11;
    assign signal_select_37 = signal_cat_110[3:3];
    assign signal_mux_13 = signal_select_37 ? signal_cat_13 : signal_mux_12;
    assign signal_select_38 = signal_cat_110[4:4];
    assign signal_mux_14 = signal_select_38 ? signal_const_3 : signal_mux_13;
    assign signal_not_3 = ~ signal_mux_14;
    assign signal_cat_16 = { signal_const_16,
                             signal_not_3 };
    assign signal_select_39 = signal_wire_16[0:0];
    assign signal_mux_15 = signal_select_39 ? signal_cat_12 : signal_cat_16;
    assign signal_select_40 = signal_wire_16[1:1];
    assign signal_mux_16 = signal_select_40 ? signal_cat_11 : signal_mux_15;
    assign signal_select_41 = signal_wire_16[2:2];
    assign signal_mux_17 = signal_select_41 ? signal_cat_10 : signal_mux_16;
    assign signal_select_42 = signal_wire_16[3:3];
    assign signal_mux_18 = signal_select_42 ? signal_cat_9 : signal_mux_17;
    assign signal_select_43 = signal_wire_16[4:4];
    assign signal_mux_19 = signal_select_43 ? signal_cat_8 : signal_mux_18;
    assign signal_and_14 = signal_mux_19 & signal_const_17;
    assign signal_not_4 = ~ signal_and_14;
    assign signal_and_15 = pin_out_base & signal_not_4;
    assign signal_or_4 = signal_and_15 | signal_and_13;
    assign signal_const_25 = 3'b000;
    assign signal_eq_5 = d$set_dest$binary_variant == signal_const_25;
    assign signal_mux_20 = signal_eq_5 ? signal_or_4 : pin_out_base;
    assign signal_select_44 = signal_mux_24[27:12];
    assign signal_select_45 = signal_mux_24[11:0];
    assign signal_cat_17 = { signal_select_45,
                             signal_select_44 };
    assign signal_select_46 = signal_mux_23[27:20];
    assign signal_select_47 = signal_mux_23[19:0];
    assign signal_cat_18 = { signal_select_47,
                             signal_select_46 };
    assign signal_select_48 = signal_mux_22[27:24];
    assign signal_select_49 = signal_mux_22[23:0];
    assign signal_cat_19 = { signal_select_49,
                             signal_select_48 };
    assign signal_select_50 = signal_mux_21[27:26];
    assign signal_select_51 = signal_mux_21[25:0];
    assign signal_cat_20 = { signal_select_51,
                             signal_select_50 };
    assign signal_select_52 = signal_cat_22[27:27];
    assign signal_select_53 = signal_cat_22[26:0];
    assign signal_cat_21 = { signal_select_53,
                             signal_select_52 };
    assign signal_cat_22 = { signal_const_16,
                             mov_value };
    assign signal_select_54 = signal_wire_37[0:0];
    assign signal_mux_21 = signal_select_54 ? signal_cat_21 : signal_cat_22;
    assign signal_select_55 = signal_wire_37[1:1];
    assign signal_mux_22 = signal_select_55 ? signal_cat_20 : signal_mux_21;
    assign signal_select_56 = signal_wire_37[2:2];
    assign signal_mux_23 = signal_select_56 ? signal_cat_19 : signal_mux_22;
    assign signal_select_57 = signal_wire_37[3:3];
    assign signal_mux_24 = signal_select_57 ? signal_cat_18 : signal_mux_23;
    assign signal_select_58 = signal_wire_37[4:4];
    assign signal_mux_25 = signal_select_58 ? signal_cat_17 : signal_mux_24;
    assign signal_and_16 = signal_mux_25 & signal_and_17;
    assign signal_select_59 = signal_mux_34[27:12];
    assign signal_select_60 = signal_mux_34[11:0];
    assign signal_cat_23 = { signal_select_60,
                             signal_select_59 };
    assign signal_select_61 = signal_mux_33[27:20];
    assign signal_select_62 = signal_mux_33[19:0];
    assign signal_cat_24 = { signal_select_62,
                             signal_select_61 };
    assign signal_select_63 = signal_mux_32[27:24];
    assign signal_select_64 = signal_mux_32[23:0];
    assign signal_cat_25 = { signal_select_64,
                             signal_select_63 };
    assign signal_select_65 = signal_mux_31[27:26];
    assign signal_select_66 = signal_mux_31[25:0];
    assign signal_cat_26 = { signal_select_66,
                             signal_select_65 };
    assign signal_select_67 = signal_cat_31[27:27];
    assign signal_select_68 = signal_cat_31[26:0];
    assign signal_cat_27 = { signal_select_68,
                             signal_select_67 };
    assign signal_select_69 = signal_mux_28[7:0];
    assign signal_cat_28 = { signal_select_69,
                             signal_const_19 };
    assign signal_select_70 = signal_mux_27[11:0];
    assign signal_cat_29 = { signal_select_70,
                             signal_const_20 };
    assign signal_select_71 = signal_mux_26[13:0];
    assign signal_cat_30 = { signal_select_71,
                             signal_const_21 };
    assign signal_select_72 = signal_wire_17[0:0];
    assign signal_mux_26 = signal_select_72 ? signal_const_22 : signal_const_23;
    assign signal_select_73 = signal_wire_17[1:1];
    assign signal_mux_27 = signal_select_73 ? signal_cat_30 : signal_mux_26;
    assign signal_select_74 = signal_wire_17[2:2];
    assign signal_mux_28 = signal_select_74 ? signal_cat_29 : signal_mux_27;
    assign signal_select_75 = signal_wire_17[3:3];
    assign signal_mux_29 = signal_select_75 ? signal_cat_28 : signal_mux_28;
    assign signal_select_76 = signal_wire_17[4:4];
    assign signal_mux_30 = signal_select_76 ? signal_const_3 : signal_mux_29;
    assign signal_not_5 = ~ signal_mux_30;
    assign signal_cat_31 = { signal_const_16,
                             signal_not_5 };
    assign signal_select_77 = signal_wire_37[0:0];
    assign signal_mux_31 = signal_select_77 ? signal_cat_27 : signal_cat_31;
    assign signal_select_78 = signal_wire_37[1:1];
    assign signal_mux_32 = signal_select_78 ? signal_cat_26 : signal_mux_31;
    assign signal_select_79 = signal_wire_37[2:2];
    assign signal_mux_33 = signal_select_79 ? signal_cat_25 : signal_mux_32;
    assign signal_select_80 = signal_wire_37[3:3];
    assign signal_mux_34 = signal_select_80 ? signal_cat_24 : signal_mux_33;
    assign signal_select_81 = signal_wire_37[4:4];
    assign signal_mux_35 = signal_select_81 ? signal_cat_23 : signal_mux_34;
    assign signal_and_17 = signal_mux_35 & signal_const_17;
    assign signal_not_6 = ~ signal_and_17;
    assign signal_and_18 = pin_out_base & signal_not_6;
    assign signal_or_5 = signal_and_18 | signal_and_16;
    assign signal_eq_6 = d$mov_dest$binary_variant == signal_const_25;
    assign signal_mux_36 = signal_eq_6 ? signal_or_5 : pin_out_base;
    assign signal_select_82 = signal_mux_40[27:12];
    assign signal_select_83 = signal_mux_40[11:0];
    assign signal_cat_32 = { signal_select_83,
                             signal_select_82 };
    assign signal_select_84 = signal_mux_39[27:20];
    assign signal_select_85 = signal_mux_39[19:0];
    assign signal_cat_33 = { signal_select_85,
                             signal_select_84 };
    assign signal_select_86 = signal_mux_38[27:24];
    assign signal_select_87 = signal_mux_38[23:0];
    assign signal_cat_34 = { signal_select_87,
                             signal_select_86 };
    assign signal_select_88 = signal_mux_37[27:26];
    assign signal_select_89 = signal_mux_37[25:0];
    assign signal_cat_35 = { signal_select_89,
                             signal_select_88 };
    assign signal_select_90 = signal_cat_39[27:27];
    assign signal_select_91 = signal_cat_39[26:0];
    assign signal_cat_36 = { signal_select_91,
                             signal_select_90 };
    assign signal_not_7 = ~ signal_select_92;
    assign signal_select_92 = out_value[0:0];
    assign signal_cat_37 = { signal_select_92,
                             signal_not_7 };
    assign signal_const_36 = 14'b00000000000000;
    assign signal_cat_38 = { signal_const_36,
                             signal_cat_37 };
    assign signal_cat_39 = { signal_const_16,
                             signal_cat_38 };
    assign signal_select_93 = signal_wire_37[0:0];
    assign signal_mux_37 = signal_select_93 ? signal_cat_36 : signal_cat_39;
    assign signal_select_94 = signal_wire_37[1:1];
    assign signal_mux_38 = signal_select_94 ? signal_cat_35 : signal_mux_37;
    assign signal_select_95 = signal_wire_37[2:2];
    assign signal_mux_39 = signal_select_95 ? signal_cat_34 : signal_mux_38;
    assign signal_select_96 = signal_wire_37[3:3];
    assign signal_mux_40 = signal_select_96 ? signal_cat_33 : signal_mux_39;
    assign signal_select_97 = signal_wire_37[4:4];
    assign signal_mux_41 = signal_select_97 ? signal_cat_32 : signal_mux_40;
    assign signal_and_19 = signal_mux_41 & signal_and_20;
    assign signal_select_98 = signal_mux_45[27:12];
    assign signal_select_99 = signal_mux_45[11:0];
    assign signal_cat_40 = { signal_select_99,
                             signal_select_98 };
    assign signal_select_100 = signal_mux_44[27:20];
    assign signal_select_101 = signal_mux_44[19:0];
    assign signal_cat_41 = { signal_select_101,
                             signal_select_100 };
    assign signal_select_102 = signal_mux_43[27:24];
    assign signal_select_103 = signal_mux_43[23:0];
    assign signal_cat_42 = { signal_select_103,
                             signal_select_102 };
    assign signal_select_104 = signal_mux_42[27:26];
    assign signal_select_105 = signal_mux_42[25:0];
    assign signal_cat_43 = { signal_select_105,
                             signal_select_104 };
    assign signal_const_39 = 28'b0000000000000000000000000110;
    assign signal_const_40 = 28'b0000000000000000000000000011;
    assign signal_select_106 = signal_wire_37[0:0];
    assign signal_mux_42 = signal_select_106 ? signal_const_39 : signal_const_40;
    assign signal_select_107 = signal_wire_37[1:1];
    assign signal_mux_43 = signal_select_107 ? signal_cat_43 : signal_mux_42;
    assign signal_select_108 = signal_wire_37[2:2];
    assign signal_mux_44 = signal_select_108 ? signal_cat_42 : signal_mux_43;
    assign signal_select_109 = signal_wire_37[3:3];
    assign signal_mux_45 = signal_select_109 ? signal_cat_41 : signal_mux_44;
    assign signal_select_110 = signal_wire_37[4:4];
    assign signal_mux_46 = signal_select_110 ? signal_cat_40 : signal_mux_45;
    assign signal_and_20 = signal_mux_46 & signal_const_17;
    assign signal_not_8 = ~ signal_and_20;
    assign signal_and_21 = pin_out_base & signal_not_8;
    assign signal_or_6 = signal_and_21 | signal_and_19;
    assign signal_select_111 = signal_mux_50[27:12];
    assign signal_select_112 = signal_mux_50[11:0];
    assign signal_cat_44 = { signal_select_112,
                             signal_select_111 };
    assign signal_select_113 = signal_mux_49[27:20];
    assign signal_select_114 = signal_mux_49[19:0];
    assign signal_cat_45 = { signal_select_114,
                             signal_select_113 };
    assign signal_select_115 = signal_mux_48[27:24];
    assign signal_select_116 = signal_mux_48[23:0];
    assign signal_cat_46 = { signal_select_116,
                             signal_select_115 };
    assign signal_select_117 = signal_mux_47[27:26];
    assign signal_select_118 = signal_mux_47[25:0];
    assign signal_cat_47 = { signal_select_118,
                             signal_select_117 };
    assign signal_select_119 = signal_cat_49[27:27];
    assign signal_select_120 = signal_cat_49[26:0];
    assign signal_cat_48 = { signal_select_120,
                             signal_select_119 };
    assign signal_cat_49 = { signal_const_16,
                             out_value };
    assign signal_select_121 = signal_wire_37[0:0];
    assign signal_mux_47 = signal_select_121 ? signal_cat_48 : signal_cat_49;
    assign signal_select_122 = signal_wire_37[1:1];
    assign signal_mux_48 = signal_select_122 ? signal_cat_47 : signal_mux_47;
    assign signal_select_123 = signal_wire_37[2:2];
    assign signal_mux_49 = signal_select_123 ? signal_cat_46 : signal_mux_48;
    assign signal_select_124 = signal_wire_37[3:3];
    assign signal_mux_50 = signal_select_124 ? signal_cat_45 : signal_mux_49;
    assign signal_select_125 = signal_wire_37[4:4];
    assign signal_mux_51 = signal_select_125 ? signal_cat_44 : signal_mux_50;
    assign signal_and_22 = signal_mux_51 & signal_and_23;
    assign signal_select_126 = signal_mux_60[27:12];
    assign signal_select_127 = signal_mux_60[11:0];
    assign signal_cat_50 = { signal_select_127,
                             signal_select_126 };
    assign signal_select_128 = signal_mux_59[27:20];
    assign signal_select_129 = signal_mux_59[19:0];
    assign signal_cat_51 = { signal_select_129,
                             signal_select_128 };
    assign signal_select_130 = signal_mux_58[27:24];
    assign signal_select_131 = signal_mux_58[23:0];
    assign signal_cat_52 = { signal_select_131,
                             signal_select_130 };
    assign signal_select_132 = signal_mux_57[27:26];
    assign signal_select_133 = signal_mux_57[25:0];
    assign signal_cat_53 = { signal_select_133,
                             signal_select_132 };
    assign signal_select_134 = signal_cat_58[27:27];
    assign signal_select_135 = signal_cat_58[26:0];
    assign signal_cat_54 = { signal_select_135,
                             signal_select_134 };
    assign signal_select_136 = signal_mux_54[7:0];
    assign signal_cat_55 = { signal_select_136,
                             signal_const_19 };
    assign signal_select_137 = signal_mux_53[11:0];
    assign signal_cat_56 = { signal_select_137,
                             signal_const_20 };
    assign signal_select_138 = signal_mux_52[13:0];
    assign signal_cat_57 = { signal_select_138,
                             signal_const_21 };
    assign signal_select_139 = d$shift_count[0:0];
    assign signal_mux_52 = signal_select_139 ? signal_const_22 : signal_const_23;
    assign signal_select_140 = d$shift_count[1:1];
    assign signal_mux_53 = signal_select_140 ? signal_cat_57 : signal_mux_52;
    assign signal_select_141 = d$shift_count[2:2];
    assign signal_mux_54 = signal_select_141 ? signal_cat_56 : signal_mux_53;
    assign signal_select_142 = d$shift_count[3:3];
    assign signal_mux_55 = signal_select_142 ? signal_cat_55 : signal_mux_54;
    assign signal_select_143 = d$shift_count[4:4];
    assign signal_mux_56 = signal_select_143 ? signal_const_3 : signal_mux_55;
    assign signal_not_9 = ~ signal_mux_56;
    assign signal_cat_58 = { signal_const_16,
                             signal_not_9 };
    assign signal_select_144 = signal_wire_37[0:0];
    assign signal_mux_57 = signal_select_144 ? signal_cat_54 : signal_cat_58;
    assign signal_select_145 = signal_wire_37[1:1];
    assign signal_mux_58 = signal_select_145 ? signal_cat_53 : signal_mux_57;
    assign signal_select_146 = signal_wire_37[2:2];
    assign signal_mux_59 = signal_select_146 ? signal_cat_52 : signal_mux_58;
    assign signal_select_147 = signal_wire_37[3:3];
    assign signal_mux_60 = signal_select_147 ? signal_cat_51 : signal_mux_59;
    assign signal_select_148 = signal_wire_37[4:4];
    assign signal_mux_61 = signal_select_148 ? signal_cat_50 : signal_mux_60;
    assign signal_and_23 = signal_mux_61 & signal_const_17;
    assign signal_not_10 = ~ signal_and_23;
    assign signal_and_24 = pin_out_base & signal_not_10;
    assign signal_or_7 = signal_and_24 | signal_and_22;
    assign signal_mux_62 = manchester_out ? signal_or_6 : signal_or_7;
    assign signal_eq_7 = d$out_dest$binary_variant == signal_const_25;
    assign signal_mux_63 = signal_eq_7 ? signal_mux_62 : pin_out_base;
    assign signal_select_149 = signal_mux_67[27:12];
    assign signal_select_150 = signal_mux_67[11:0];
    assign signal_cat_59 = { signal_select_150,
                             signal_select_149 };
    assign signal_select_151 = signal_mux_66[27:20];
    assign signal_select_152 = signal_mux_66[19:0];
    assign signal_cat_60 = { signal_select_152,
                             signal_select_151 };
    assign signal_select_153 = signal_mux_65[27:24];
    assign signal_select_154 = signal_mux_65[23:0];
    assign signal_cat_61 = { signal_select_154,
                             signal_select_153 };
    assign signal_select_155 = signal_mux_64[27:26];
    assign signal_select_156 = signal_mux_64[25:0];
    assign signal_cat_62 = { signal_select_156,
                             signal_select_155 };
    assign signal_select_157 = signal_cat_65[27:27];
    assign signal_select_158 = signal_cat_65[26:0];
    assign signal_cat_63 = { signal_select_158,
                             signal_select_157 };
    assign signal_cat_64 = { signal_const_36,
                             d$side_set };
    assign signal_cat_65 = { signal_const_16,
                             signal_cat_64 };
    assign signal_select_159 = signal_wire_39[0:0];
    assign signal_mux_64 = signal_select_159 ? signal_cat_63 : signal_cat_65;
    assign signal_select_160 = signal_wire_39[1:1];
    assign signal_mux_65 = signal_select_160 ? signal_cat_62 : signal_mux_64;
    assign signal_select_161 = signal_wire_39[2:2];
    assign signal_mux_66 = signal_select_161 ? signal_cat_61 : signal_mux_65;
    assign signal_select_162 = signal_wire_39[3:3];
    assign signal_mux_67 = signal_select_162 ? signal_cat_60 : signal_mux_66;
    assign signal_select_163 = signal_wire_39[4:4];
    assign signal_mux_68 = signal_select_163 ? signal_cat_59 : signal_mux_67;
    assign signal_and_25 = signal_mux_68 & signal_and_26;
    assign signal_select_164 = signal_mux_77[27:12];
    assign signal_select_165 = signal_mux_77[11:0];
    assign signal_cat_66 = { signal_select_165,
                             signal_select_164 };
    assign signal_select_166 = signal_mux_76[27:20];
    assign signal_select_167 = signal_mux_76[19:0];
    assign signal_cat_67 = { signal_select_167,
                             signal_select_166 };
    assign signal_select_168 = signal_mux_75[27:24];
    assign signal_select_169 = signal_mux_75[23:0];
    assign signal_cat_68 = { signal_select_169,
                             signal_select_168 };
    assign signal_select_170 = signal_mux_74[27:26];
    assign signal_select_171 = signal_mux_74[25:0];
    assign signal_cat_69 = { signal_select_171,
                             signal_select_170 };
    assign signal_select_172 = signal_cat_74[27:27];
    assign signal_select_173 = signal_cat_74[26:0];
    assign signal_cat_70 = { signal_select_173,
                             signal_select_172 };
    assign signal_select_174 = signal_mux_71[7:0];
    assign signal_cat_71 = { signal_select_174,
                             signal_const_19 };
    assign signal_select_175 = signal_mux_70[11:0];
    assign signal_cat_72 = { signal_select_175,
                             signal_const_20 };
    assign signal_select_176 = signal_mux_69[13:0];
    assign signal_cat_73 = { signal_select_176,
                             signal_const_21 };
    assign signal_select_177 = signal_cat_220[0:0];
    assign signal_mux_69 = signal_select_177 ? signal_const_22 : signal_const_23;
    assign signal_select_178 = signal_cat_220[1:1];
    assign signal_mux_70 = signal_select_178 ? signal_cat_73 : signal_mux_69;
    assign signal_select_179 = signal_cat_220[2:2];
    assign signal_mux_71 = signal_select_179 ? signal_cat_72 : signal_mux_70;
    assign signal_select_180 = signal_cat_220[3:3];
    assign signal_mux_72 = signal_select_180 ? signal_cat_71 : signal_mux_71;
    assign signal_select_181 = signal_cat_220[4:4];
    assign signal_mux_73 = signal_select_181 ? signal_const_3 : signal_mux_72;
    assign signal_not_11 = ~ signal_mux_73;
    assign signal_cat_74 = { signal_const_16,
                             signal_not_11 };
    assign signal_select_182 = signal_wire_39[0:0];
    assign signal_mux_74 = signal_select_182 ? signal_cat_70 : signal_cat_74;
    assign signal_select_183 = signal_wire_39[1:1];
    assign signal_mux_75 = signal_select_183 ? signal_cat_69 : signal_mux_74;
    assign signal_select_184 = signal_wire_39[2:2];
    assign signal_mux_76 = signal_select_184 ? signal_cat_68 : signal_mux_75;
    assign signal_select_185 = signal_wire_39[3:3];
    assign signal_mux_77 = signal_select_185 ? signal_cat_67 : signal_mux_76;
    assign signal_select_186 = signal_wire_39[4:4];
    assign signal_mux_78 = signal_select_186 ? signal_cat_66 : signal_mux_77;
    assign signal_and_26 = signal_mux_78 & signal_const_17;
    assign signal_not_12 = ~ signal_and_26;
    assign signal_and_27 = pin_out_flipped & signal_not_12;
    assign pin_out_side = signal_and_27 | signal_and_25;
    assign pin_out_base = signal_wire_40 ? pin_out_flipped : pin_out_side;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            pin_out_next <= pin_out_base;
        1:
            pin_out_next <= pin_out_base;
        2:
            pin_out_next <= pin_out_base;
        3:
            pin_out_next <= signal_mux_63;
        4:
            pin_out_next <= signal_mux_36;
        5:
            pin_out_next <= signal_mux_20;
        6:
            pin_out_next <= pin_out_base;
        default:
            pin_out_next <= pin_out_base;
        endcase
    end
    assign signal_select_187 = signal_mux_82[27:12];
    assign signal_select_188 = signal_mux_82[11:0];
    assign signal_cat_75 = { signal_select_188,
                             signal_select_187 };
    assign signal_select_189 = signal_mux_81[27:20];
    assign signal_select_190 = signal_mux_81[19:0];
    assign signal_cat_76 = { signal_select_190,
                             signal_select_189 };
    assign signal_select_191 = signal_mux_80[27:24];
    assign signal_select_192 = signal_mux_80[23:0];
    assign signal_cat_77 = { signal_select_192,
                             signal_select_191 };
    assign signal_select_193 = signal_mux_79[27:26];
    assign signal_select_194 = signal_mux_79[25:0];
    assign signal_cat_78 = { signal_select_194,
                             signal_select_193 };
    assign signal_select_195 = signal_cat_82[27:27];
    assign signal_select_196 = signal_cat_82[26:0];
    assign signal_cat_79 = { signal_select_196,
                             signal_select_195 };
    assign signal_not_13 = ~ signal_not_14;
    assign signal_select_197 = out_value[0:0];
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_5 <= signal_const_4;
        else
            if (starts_manchester_bit)
                signal_reg_5 <= signal_select_197;
    end
    assign flip_bit_0 = signal_reg_5;
    assign signal_not_14 = ~ flip_bit_0;
    assign signal_cat_80 = { signal_not_14,
                             signal_not_13 };
    assign signal_cat_81 = { signal_const_36,
                             signal_cat_80 };
    assign signal_cat_82 = { signal_const_16,
                             signal_cat_81 };
    assign signal_select_198 = signal_wire_37[0:0];
    assign signal_mux_79 = signal_select_198 ? signal_cat_79 : signal_cat_82;
    assign signal_select_199 = signal_wire_37[1:1];
    assign signal_mux_80 = signal_select_199 ? signal_cat_78 : signal_mux_79;
    assign signal_select_200 = signal_wire_37[2:2];
    assign signal_mux_81 = signal_select_200 ? signal_cat_77 : signal_mux_80;
    assign signal_select_201 = signal_wire_37[3:3];
    assign signal_mux_82 = signal_select_201 ? signal_cat_76 : signal_mux_81;
    assign signal_select_202 = signal_wire_37[4:4];
    assign signal_mux_83 = signal_select_202 ? signal_cat_75 : signal_mux_82;
    assign signal_and_28 = signal_mux_83 & signal_and_29;
    assign signal_select_203 = signal_mux_87[27:12];
    assign signal_select_204 = signal_mux_87[11:0];
    assign signal_cat_83 = { signal_select_204,
                             signal_select_203 };
    assign signal_select_205 = signal_mux_86[27:20];
    assign signal_select_206 = signal_mux_86[19:0];
    assign signal_cat_84 = { signal_select_206,
                             signal_select_205 };
    assign signal_select_207 = signal_mux_85[27:24];
    assign signal_select_208 = signal_mux_85[23:0];
    assign signal_cat_85 = { signal_select_208,
                             signal_select_207 };
    assign signal_select_209 = signal_mux_84[27:26];
    assign signal_select_210 = signal_mux_84[25:0];
    assign signal_cat_86 = { signal_select_210,
                             signal_select_209 };
    assign signal_select_211 = signal_wire_37[0:0];
    assign signal_mux_84 = signal_select_211 ? signal_const_39 : signal_const_40;
    assign signal_select_212 = signal_wire_37[1:1];
    assign signal_mux_85 = signal_select_212 ? signal_cat_86 : signal_mux_84;
    assign signal_select_213 = signal_wire_37[2:2];
    assign signal_mux_86 = signal_select_213 ? signal_cat_85 : signal_mux_85;
    assign signal_select_214 = signal_wire_37[3:3];
    assign signal_mux_87 = signal_select_214 ? signal_cat_84 : signal_mux_86;
    assign signal_select_215 = signal_wire_37[4:4];
    assign signal_mux_88 = signal_select_215 ? signal_cat_83 : signal_mux_87;
    assign signal_and_29 = signal_mux_88 & signal_const_17;
    assign signal_not_15 = ~ signal_and_29;
    assign signal_and_30 = pin_out_0 & signal_not_15;
    assign signal_or_8 = signal_and_30 | signal_and_28;
    assign signal_mux_89 = issue ? gnd : flip_pending_0;
    assign signal_const_68 = 5'b00001;
    assign signal_eq_8 = d$shift_count == signal_const_68;
    assign signal_wire_2 = config$manchester;
    assign manchester_out = signal_wire_2 & signal_eq_8;
    assign signal_eq_9 = d$out_dest$binary_variant == signal_const_25;
    assign signal_and_31 = op_go & is_opcode$3;
    assign signal_and_32 = signal_and_31 & signal_eq_9;
    assign starts_manchester_bit = signal_and_32 & manchester_out;
    assign signal_mux_90 = starts_manchester_bit ? vdd : signal_mux_89;
    assign signal_mux_91 = start_0 ? gnd : signal_mux_90;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_6 <= signal_const_4;
        else
            signal_reg_6 <= signal_mux_91;
    end
    assign flip_pending_0 = signal_reg_6;
    assign pin_out_flipped = flip_pending_0 ? signal_or_8 : pin_out_0;
    assign signal_not_16 = ~ is_opcode$0;
    assign signal_not_17 = ~ start_0;
    assign signal_const_70 = 5'b00000;
    assign signal_const_74 = 5'b00111;
    assign signal_and_33 = signal_select_723 & signal_const_74;
    assign signal_and_34 = signal_select_723 & signal_const_74;
    assign signal_const_76 = 5'b01111;
    assign signal_and_35 = signal_select_723 & signal_const_76;
    always @* begin
        case (signal_wire_38)
        0:
            d$delay <= signal_select_723;
        1:
            d$delay <= signal_and_35;
        2:
            d$delay <= signal_and_34;
        default:
            d$delay <= signal_and_33;
        endcase
    end
    assign signal_sub_2 = stall_0 - signal_const_68;
    assign signal_eq_10 = stall_0 == signal_const_70;
    assign signal_not_18 = ~ signal_eq_10;
    assign signal_mux_92 = signal_not_18 ? signal_sub_2 : stall_0;
    assign signal_mux_93 = advance ? d$delay : signal_mux_92;
    assign signal_mux_94 = jmp_go ? signal_const_68 : signal_mux_93;
    assign stall_next = start_0 ? signal_const_70 : signal_mux_94;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_7 <= signal_const_70;
        else
            signal_reg_7 <= stall_next;
    end
    assign stall_0 = signal_reg_7;
    assign signal_eq_11 = stall_0 == signal_const_70;
    assign signal_const_79 = 4'b0001;
    assign signal_eq_12 = d$sys_op$binary_variant == signal_const_79;
    assign signal_and_36 = is_opcode$7 & signal_eq_12;
    assign signal_and_37 = op_go & signal_and_36;
    assign signal_mux_95 = signal_and_37 ? vdd : halted_0;
    assign signal_const_80 = 4'b1001;
    assign signal_select_216 = signal_wire_44[3:0];
    assign signal_lt = signal_select_216 < signal_const_80;
    assign signal_select_217 = signal_wire_44[7:4];
    assign signal_eq_13 = signal_select_217 == signal_const_20;
    assign signal_and_38 = signal_eq_13 & signal_lt;
    assign signal_select_218 = signal_wire_44[2:0];
    assign signal_lt_1 = signal_select_218 < signal_const_1;
    assign signal_select_219 = signal_wire_44[3:3];
    assign signal_not_19 = ~ signal_select_219;
    assign signal_or_9 = signal_not_19 | signal_lt_1;
    assign signal_const_83 = 2'b11;
    assign signal_select_220 = signal_wire_44[5:4];
    assign signal_lt_2 = signal_select_220 < signal_const_83;
    assign signal_and_39 = signal_lt_2 & signal_or_9;
    assign signal_select_221 = signal_wire_44[7:5];
    assign signal_lt_3 = signal_select_221 < signal_const_1;
    assign signal_select_222 = signal_wire_44[4:3];
    assign signal_lt_4 = signal_select_222 < signal_const_83;
    assign signal_const_86 = 5'b10000;
    assign signal_lt_5 = signal_const_86 < signal_select_223;
    assign signal_not_20 = ~ signal_lt_5;
    assign signal_select_223 = signal_wire_44[4:0];
    assign signal_lt_6 = signal_select_223 < signal_const_68;
    assign signal_not_21 = ~ signal_lt_6;
    assign signal_and_40 = signal_not_21 & signal_not_20;
    assign signal_eq_14 = signal_select_314 == signal_const_70;
    assign signal_eq_15 = signal_select_314 == signal_const_70;
    assign signal_const_90 = 5'b11100;
    assign signal_lt_7 = signal_select_314 < signal_const_90;
    assign signal_lt_8 = signal_select_314 < signal_const_90;
    assign signal_select_224 = signal_wire_44[6:5];
    always @* begin
        case (signal_select_224)
        0:
            signal_mux_96 <= signal_lt_8;
        1:
            signal_mux_96 <= signal_lt_7;
        2:
            signal_mux_96 <= signal_eq_15;
        default:
            signal_mux_96 <= signal_eq_14;
        endcase
    end
    assign signal_const_92 = 4'b1100;
    assign signal_select_225 = signal_wire_44[12:9];
    assign signal_lt_9 = signal_select_225 < signal_const_92;
    assign signal_wire_3 = program_write$data;
    assign signal_wire_4 = program_write$addr;
    assign signal_wire_5 = program_read$value;
    assign signal_eq_16 = signal_const_11 == signal_wire_7;
    assign signal_mux_97 = signal_eq_16 ? signal_wire_6 : signal_const_13;
    assign signal_add_1 = pc_next + signal_const_13;
    assign signal_eq_17 = pc_next == signal_wire_7;
    assign signal_mux_98 = signal_eq_17 ? signal_wire_6 : signal_add_1;
    assign signal_wire_6 = config$wrap_bottom;
    assign signal_add_2 = pc_0 + signal_const_13;
    assign signal_wire_7 = config$wrap_top;
    assign d$jmp_target = word[8:0];
    assign signal_not_22 = ~ signal_select_282;
    assign signal_not_23 = ~ signal_select_676;
    assign signal_add_3 = stuff_run_0 + signal_const_68;
    assign stuff_run_max = 5'b11111;
    assign signal_eq_18 = stuff_run_0 == stuff_run_max;
    assign signal_mux_99 = signal_eq_18 ? stuff_run_0 : signal_add_3;
    assign signal_wire_8 = config$stuff_level;
    assign signal_eq_19 = crossing_bit == signal_wire_8;
    assign signal_mux_100 = signal_eq_19 ? signal_mux_99 : signal_const_70;
    assign signal_mux_101 = bit_crosses ? signal_mux_100 : stuff_run_0;
    assign signal_const_106 = 4'b0110;
    assign signal_eq_20 = d$sys_op$binary_variant == signal_const_106;
    assign signal_and_41 = is_opcode$7 & signal_eq_20;
    assign stuff_run_next = signal_and_41 ? signal_const_70 : signal_mux_101;
    assign signal_mux_102 = go ? stuff_run_next : stuff_run_0;
    assign signal_mux_103 = start_0 ? signal_const_70 : signal_mux_102;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_8 <= signal_const_70;
        else
            signal_reg_8 <= signal_mux_103;
    end
    assign stuff_run_0 = signal_reg_8;
    assign signal_lt_10 = stuff_run_0 < signal_wire_9;
    assign signal_not_24 = ~ signal_lt_10;
    assign signal_wire_9 = config$stuff_threshold;
    assign signal_eq_21 = signal_wire_9 == signal_const_70;
    assign signal_not_25 = ~ signal_eq_21;
    assign signal_and_42 = signal_not_25 & signal_not_24;
    assign signal_lt_11 = osr_count_0 < signal_wire_34;
    assign signal_select_226 = sample[27:27];
    assign signal_select_227 = sample[26:26];
    assign signal_select_228 = sample[25:25];
    assign signal_select_229 = sample[24:24];
    assign signal_select_230 = sample[23:23];
    assign signal_select_231 = sample[22:22];
    assign signal_select_232 = sample[21:21];
    assign signal_select_233 = sample[20:20];
    assign signal_select_234 = sample[19:19];
    assign signal_select_235 = sample[18:18];
    assign signal_select_236 = sample[17:17];
    assign signal_select_237 = sample[16:16];
    assign signal_select_238 = sample[15:15];
    assign signal_select_239 = sample[14:14];
    assign signal_select_240 = sample[13:13];
    assign signal_select_241 = sample[12:12];
    assign signal_select_242 = sample[11:11];
    assign signal_select_243 = sample[10:10];
    assign signal_select_244 = sample[9:9];
    assign signal_select_245 = sample[8:8];
    assign signal_select_246 = sample[7:7];
    assign signal_select_247 = sample[6:6];
    assign signal_select_248 = sample[5:5];
    assign signal_select_249 = sample[4:4];
    assign signal_select_250 = sample[3:3];
    assign signal_select_251 = sample[2:2];
    assign signal_select_252 = sample[1:1];
    assign signal_select_253 = sample[0:0];
    always @* begin
        case (signal_wire_10)
        0:
            signal_mux_104 <= signal_select_253;
        1:
            signal_mux_104 <= signal_select_252;
        2:
            signal_mux_104 <= signal_select_251;
        3:
            signal_mux_104 <= signal_select_250;
        4:
            signal_mux_104 <= signal_select_249;
        5:
            signal_mux_104 <= signal_select_248;
        6:
            signal_mux_104 <= signal_select_247;
        7:
            signal_mux_104 <= signal_select_246;
        8:
            signal_mux_104 <= signal_select_245;
        9:
            signal_mux_104 <= signal_select_244;
        10:
            signal_mux_104 <= signal_select_243;
        11:
            signal_mux_104 <= signal_select_242;
        12:
            signal_mux_104 <= signal_select_241;
        13:
            signal_mux_104 <= signal_select_240;
        14:
            signal_mux_104 <= signal_select_239;
        15:
            signal_mux_104 <= signal_select_238;
        16:
            signal_mux_104 <= signal_select_237;
        17:
            signal_mux_104 <= signal_select_236;
        18:
            signal_mux_104 <= signal_select_235;
        19:
            signal_mux_104 <= signal_select_234;
        20:
            signal_mux_104 <= signal_select_233;
        21:
            signal_mux_104 <= signal_select_232;
        22:
            signal_mux_104 <= signal_select_231;
        23:
            signal_mux_104 <= signal_select_230;
        24:
            signal_mux_104 <= signal_select_229;
        25:
            signal_mux_104 <= signal_select_228;
        26:
            signal_mux_104 <= signal_select_227;
        default:
            signal_mux_104 <= signal_select_226;
        endcase
    end
    assign signal_not_26 = ~ signal_mux_104;
    assign signal_select_254 = sample[27:27];
    assign signal_select_255 = sample[26:26];
    assign signal_select_256 = sample[25:25];
    assign signal_select_257 = sample[24:24];
    assign signal_select_258 = sample[23:23];
    assign signal_select_259 = sample[22:22];
    assign signal_select_260 = sample[21:21];
    assign signal_select_261 = sample[20:20];
    assign signal_select_262 = sample[19:19];
    assign signal_select_263 = sample[18:18];
    assign signal_select_264 = sample[17:17];
    assign signal_select_265 = sample[16:16];
    assign signal_select_266 = sample[15:15];
    assign signal_select_267 = sample[14:14];
    assign signal_select_268 = sample[13:13];
    assign signal_select_269 = sample[12:12];
    assign signal_select_270 = sample[11:11];
    assign signal_select_271 = sample[10:10];
    assign signal_select_272 = sample[9:9];
    assign signal_select_273 = sample[8:8];
    assign signal_select_274 = sample[7:7];
    assign signal_select_275 = sample[6:6];
    assign signal_select_276 = sample[5:5];
    assign signal_select_277 = sample[4:4];
    assign signal_select_278 = sample[3:3];
    assign signal_select_279 = sample[2:2];
    assign signal_select_280 = sample[1:1];
    assign signal_select_281 = sample[0:0];
    assign signal_wire_10 = config$jmp_pin;
    always @* begin
        case (signal_wire_10)
        0:
            signal_mux_105 <= signal_select_281;
        1:
            signal_mux_105 <= signal_select_280;
        2:
            signal_mux_105 <= signal_select_279;
        3:
            signal_mux_105 <= signal_select_278;
        4:
            signal_mux_105 <= signal_select_277;
        5:
            signal_mux_105 <= signal_select_276;
        6:
            signal_mux_105 <= signal_select_275;
        7:
            signal_mux_105 <= signal_select_274;
        8:
            signal_mux_105 <= signal_select_273;
        9:
            signal_mux_105 <= signal_select_272;
        10:
            signal_mux_105 <= signal_select_271;
        11:
            signal_mux_105 <= signal_select_270;
        12:
            signal_mux_105 <= signal_select_269;
        13:
            signal_mux_105 <= signal_select_268;
        14:
            signal_mux_105 <= signal_select_267;
        15:
            signal_mux_105 <= signal_select_266;
        16:
            signal_mux_105 <= signal_select_265;
        17:
            signal_mux_105 <= signal_select_264;
        18:
            signal_mux_105 <= signal_select_263;
        19:
            signal_mux_105 <= signal_select_262;
        20:
            signal_mux_105 <= signal_select_261;
        21:
            signal_mux_105 <= signal_select_260;
        22:
            signal_mux_105 <= signal_select_259;
        23:
            signal_mux_105 <= signal_select_258;
        24:
            signal_mux_105 <= signal_select_257;
        25:
            signal_mux_105 <= signal_select_256;
        26:
            signal_mux_105 <= signal_select_255;
        default:
            signal_mux_105 <= signal_select_254;
        endcase
    end
    assign signal_eq_22 = x_0 == y_0;
    assign signal_not_27 = ~ signal_eq_22;
    assign signal_eq_23 = y_0 == signal_const_3;
    assign signal_not_28 = ~ signal_eq_23;
    assign signal_eq_24 = x_0 == signal_const_3;
    assign signal_not_29 = ~ signal_eq_24;
    always @* begin
        case (d$jmp_cond$binary_variant)
        0:
            jmp_taken <= vdd;
        1:
            jmp_taken <= signal_not_29;
        2:
            jmp_taken <= signal_not_28;
        3:
            jmp_taken <= signal_not_27;
        4:
            jmp_taken <= signal_mux_105;
        5:
            jmp_taken <= signal_not_26;
        6:
            jmp_taken <= signal_lt_11;
        7:
            jmp_taken <= signal_and_42;
        8:
            jmp_taken <= signal_not_23;
        9:
            jmp_taken <= signal_select_676;
        10:
            jmp_taken <= signal_not_22;
        default:
            jmp_taken <= signal_select_282;
        endcase
    end
    assign jmp_target_or_next = jmp_taken ? d$jmp_target : pc_next;
    assign signal_mux_106 = advance ? pc_next : pc_0;
    assign signal_mux_107 = jmp_go ? jmp_target_or_next : signal_mux_106;
    assign pc_value_next = start_0 ? signal_const_11 : signal_mux_107;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_9 <= signal_const_11;
        else
            signal_reg_9 <= pc_value_next;
    end
    assign pc_0 = signal_reg_9;
    assign signal_eq_25 = pc_0 == signal_wire_7;
    assign pc_next = signal_eq_25 ? signal_wire_6 : signal_add_2;
    assign signal_mux_108 = advance ? signal_mux_98 : pc_next;
    assign pc_after_next = start_0 ? signal_mux_97 : signal_mux_108;
    assign signal_or_10 = jmp_go | signal_wire_48;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            refill <= signal_const_4;
        else
            refill <= signal_or_10;
    end
    assign signal_not_30 = ~ signal_select_676;
    assign signal_wire_11 = rx_pop;
    assign signal_mux_109 = is_opcode$2 ? isr_shifted : isr_0;
    assign signal_wire_12 = signal_mux_109;
    assign signal_not_31 = ~ signal_select_282;
    assign signal_const_111 = 4'b0011;
    assign signal_eq_26 = d$sys_op$binary_variant == signal_const_111;
    assign signal_and_43 = is_opcode$7 & signal_eq_26;
    assign signal_and_44 = is_opcode$2 & autopush_now;
    assign pushes = signal_and_44 | signal_and_43;
    assign signal_and_45 = op_go & pushes;
    assign signal_and_46 = signal_and_45 & signal_not_31;
    assign signal_wire_13 = signal_and_46;
    host_fifo
        rx
        ( .clock(signal_wire_47),
          .clear(signal_wire_46),
          .push$valid(signal_wire_13),
          .push$value(signal_wire_12),
          .pop(signal_wire_11),
          .flush(flush_0),
          .head(signal_inst[15:0]),
          .level(signal_inst[19:16]),
          .empty(signal_inst[20:20]),
          .full(signal_inst[21:21]) );
    assign signal_select_282 = signal_inst[21:21];
    assign signal_not_32 = ~ signal_select_282;
    assign signal_mux_110 = d$wait_polarity ? signal_not_30 : signal_not_32;
    assign signal_xor = t_0 ^ signal_cat_87;
    assign signal_sub_3 = t_0 - signal_cat_87;
    assign signal_cat_87 = { signal_const_19,
                             alu_operand };
    assign signal_add_4 = t_0 + signal_cat_87;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_111 <= signal_add_4;
        1:
            signal_mux_111 <= signal_sub_3;
        default:
            signal_mux_111 <= signal_xor;
        endcase
    end
    assign signal_eq_27 = d$alu_dest$binary_variant == signal_const_83;
    assign signal_mux_112 = signal_eq_27 ? signal_mux_111 : t_0;
    assign signal_select_283 = mov_value24[23:23];
    assign signal_select_284 = mov_value24[22:22];
    assign signal_select_285 = mov_value24[21:21];
    assign signal_select_286 = mov_value24[20:20];
    assign signal_select_287 = mov_value24[19:19];
    assign signal_select_288 = mov_value24[18:18];
    assign signal_select_289 = mov_value24[17:17];
    assign signal_select_290 = mov_value24[16:16];
    assign signal_select_291 = mov_value24[15:15];
    assign signal_select_292 = mov_value24[14:14];
    assign signal_select_293 = mov_value24[13:13];
    assign signal_select_294 = mov_value24[12:12];
    assign signal_select_295 = mov_value24[11:11];
    assign signal_select_296 = mov_value24[10:10];
    assign signal_select_297 = mov_value24[9:9];
    assign signal_select_298 = mov_value24[8:8];
    assign signal_select_299 = mov_value24[7:7];
    assign signal_select_300 = mov_value24[6:6];
    assign signal_select_301 = mov_value24[5:5];
    assign signal_select_302 = mov_value24[4:4];
    assign signal_select_303 = mov_value24[3:3];
    assign signal_select_304 = mov_value24[2:2];
    assign signal_select_305 = mov_value24[1:1];
    assign signal_select_306 = mov_value24[0:0];
    assign signal_cat_88 = { signal_select_306,
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
                             signal_select_295,
                             signal_select_294,
                             signal_select_293,
                             signal_select_292,
                             signal_select_291,
                             signal_select_290,
                             signal_select_289,
                             signal_select_288,
                             signal_select_287,
                             signal_select_286,
                             signal_select_285,
                             signal_select_284,
                             signal_select_283 };
    assign signal_not_33 = ~ mov_value24;
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value_t <= mov_value24;
        1:
            mov_value_t <= signal_not_33;
        default:
            mov_value_t <= signal_cat_88;
        endcase
    end
    assign signal_const_115 = 3'b111;
    assign signal_eq_28 = d$mov_dest$binary_variant == signal_const_115;
    assign signal_mux_113 = signal_eq_28 ? mov_value_t : t_0;
    assign signal_cat_89 = { signal_const_19,
                             out_value };
    assign signal_eq_29 = d$out_dest$binary_variant == signal_const_115;
    assign signal_mux_114 = signal_eq_29 ? signal_cat_89 : t_0;
    assign signal_wire_14 = config$period_fraction;
    assign signal_cat_90 = { gnd,
                             signal_wire_14 };
    assign signal_eq_30 = d$alu_dest$binary_variant == signal_const_83;
    assign signal_mux_115 = signal_eq_30 ? signal_const_3 : t_fraction_0;
    assign signal_eq_31 = d$mov_dest$binary_variant == signal_const_115;
    assign signal_mux_116 = signal_eq_31 ? signal_const_3 : t_fraction_0;
    assign signal_eq_32 = d$out_dest$binary_variant == signal_const_115;
    assign signal_mux_117 = signal_eq_32 ? signal_const_3 : t_fraction_0;
    assign signal_select_307 = fraction_sum[15:0];
    assign signal_mux_118 = advances_deadline ? signal_select_307 : t_fraction_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_fraction_next <= t_fraction_0;
        1:
            t_fraction_next <= signal_mux_118;
        2:
            t_fraction_next <= t_fraction_0;
        3:
            t_fraction_next <= signal_mux_117;
        4:
            t_fraction_next <= signal_mux_116;
        5:
            t_fraction_next <= t_fraction_0;
        6:
            t_fraction_next <= signal_mux_115;
        default:
            t_fraction_next <= t_fraction_0;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_10 <= signal_const_3;
        else
            if (go)
                signal_reg_10 <= t_fraction_next;
    end
    assign t_fraction_0 = signal_reg_10;
    assign signal_cat_91 = { gnd,
                             t_fraction_0 };
    assign fraction_sum = signal_cat_91 + signal_cat_90;
    assign signal_select_308 = fraction_sum[16:16];
    assign signal_const_125 = 23'b00000000000000000000000;
    assign signal_cat_92 = { signal_const_125,
                             signal_select_308 };
    assign signal_cat_93 = { signal_const_19,
                             p_0 };
    assign signal_add_5 = t_0 + signal_cat_93;
    assign t_advanced = signal_add_5 + signal_cat_92;
    assign signal_const_127 = 2'b10;
    assign signal_eq_33 = d$wait_source$binary_variant == signal_const_127;
    assign signal_and_47 = is_opcode$1 & signal_eq_33;
    assign releases_deadline = signal_and_47 & wait_ready;
    assign advances_deadline = releases_deadline & d$wait_polarity;
    assign signal_mux_119 = advances_deadline ? t_advanced : t_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_next <= t_0;
        1:
            t_next <= signal_mux_119;
        2:
            t_next <= t_0;
        3:
            t_next <= signal_mux_114;
        4:
            t_next <= signal_mux_113;
        5:
            t_next <= t_0;
        6:
            t_next <= signal_mux_112;
        default:
            t_next <= t_0;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_11 <= signal_const_5;
        else
            if (go)
                signal_reg_11 <= t_next;
    end
    assign t_0 = signal_reg_11;
    assign signal_sub_4 = now_0 - t_0;
    assign signal_select_309 = signal_sub_4[23:23];
    assign deadline_ready = ~ signal_select_309;
    assign signal_eq_34 = wait_pin_cur == d$wait_polarity;
    assign signal_and_48 = pins_sampled & wait_select_0;
    assign signal_eq_35 = signal_and_48 == signal_const_14;
    assign wait_pin_prev = ~ signal_eq_35;
    assign signal_eq_36 = wait_pin_cur == wait_pin_prev;
    assign signal_not_34 = ~ signal_eq_36;
    assign signal_and_49 = signal_not_34 & signal_eq_34;
    assign d$wait_polarity = word[7:7];
    assign signal_const_130 = 28'b0000000000000000000000000001;
    assign signal_and_50 = signal_not_35 & signal_and_66;
    assign signal_and_51 = signal_not_35 & signal_and_68;
    assign signal_and_52 = signal_not_35 & signal_and_70;
    assign signal_and_53 = signal_not_35 & signal_and_72;
    assign signal_and_54 = signal_not_35 & signal_and_74;
    assign signal_and_55 = signal_not_35 & signal_and_76;
    assign signal_and_56 = signal_not_35 & signal_and_78;
    assign signal_and_57 = signal_not_35 & signal_and_80;
    assign signal_and_58 = signal_not_35 & signal_and_83;
    assign signal_and_59 = signal_not_35 & signal_and_86;
    assign signal_and_60 = signal_not_35 & signal_and_89;
    assign signal_and_61 = signal_not_35 & signal_and_92;
    assign signal_and_62 = signal_not_35 & signal_and_96;
    assign signal_and_63 = signal_not_35 & signal_and_100;
    assign signal_and_64 = signal_not_35 & signal_and_104;
    assign signal_not_35 = ~ signal_select_315;
    assign signal_and_65 = signal_not_35 & signal_and_108;
    assign signal_and_66 = signal_not_36 & signal_and_82;
    assign signal_and_67 = signal_select_315 & signal_and_66;
    assign signal_and_68 = signal_not_36 & signal_and_85;
    assign signal_and_69 = signal_select_315 & signal_and_68;
    assign signal_and_70 = signal_not_36 & signal_and_88;
    assign signal_and_71 = signal_select_315 & signal_and_70;
    assign signal_and_72 = signal_not_36 & signal_and_91;
    assign signal_and_73 = signal_select_315 & signal_and_72;
    assign signal_and_74 = signal_not_36 & signal_and_95;
    assign signal_and_75 = signal_select_315 & signal_and_74;
    assign signal_and_76 = signal_not_36 & signal_and_99;
    assign signal_and_77 = signal_select_315 & signal_and_76;
    assign signal_and_78 = signal_not_36 & signal_and_103;
    assign signal_and_79 = signal_select_315 & signal_and_78;
    assign signal_not_36 = ~ signal_select_313;
    assign signal_and_80 = signal_not_36 & signal_and_107;
    assign signal_and_81 = signal_select_315 & signal_and_80;
    assign signal_and_82 = signal_not_37 & signal_and_94;
    assign signal_and_83 = signal_select_313 & signal_and_82;
    assign signal_and_84 = signal_select_315 & signal_and_83;
    assign signal_and_85 = signal_not_37 & signal_and_98;
    assign signal_and_86 = signal_select_313 & signal_and_85;
    assign signal_and_87 = signal_select_315 & signal_and_86;
    assign signal_and_88 = signal_not_37 & signal_and_102;
    assign signal_and_89 = signal_select_313 & signal_and_88;
    assign signal_and_90 = signal_select_315 & signal_and_89;
    assign signal_not_37 = ~ signal_select_312;
    assign signal_and_91 = signal_not_37 & signal_and_106;
    assign signal_and_92 = signal_select_313 & signal_and_91;
    assign signal_and_93 = signal_select_315 & signal_and_92;
    assign signal_and_94 = signal_not_38 & signal_not_39;
    assign signal_and_95 = signal_select_312 & signal_and_94;
    assign signal_and_96 = signal_select_313 & signal_and_95;
    assign signal_and_97 = signal_select_315 & signal_and_96;
    assign signal_not_38 = ~ signal_select_311;
    assign signal_and_98 = signal_not_38 & signal_select_310;
    assign signal_and_99 = signal_select_312 & signal_and_98;
    assign signal_and_100 = signal_select_313 & signal_and_99;
    assign signal_and_101 = signal_select_315 & signal_and_100;
    assign signal_not_39 = ~ signal_select_310;
    assign signal_and_102 = signal_select_311 & signal_not_39;
    assign signal_and_103 = signal_select_312 & signal_and_102;
    assign signal_and_104 = signal_select_313 & signal_and_103;
    assign signal_and_105 = signal_select_315 & signal_and_104;
    assign signal_select_310 = signal_select_314[0:0];
    assign signal_select_311 = signal_select_314[1:1];
    assign signal_and_106 = signal_select_311 & signal_select_310;
    assign signal_select_312 = signal_select_314[2:2];
    assign signal_and_107 = signal_select_312 & signal_and_106;
    assign signal_select_313 = signal_select_314[3:3];
    assign signal_and_108 = signal_select_313 & signal_and_107;
    assign signal_select_314 = signal_wire_44[4:0];
    assign signal_select_315 = signal_select_314[4:4];
    assign signal_and_109 = signal_select_315 & signal_and_108;
    assign signal_cat_94 = { signal_and_109,
                             signal_and_105,
                             signal_and_101,
                             signal_and_97,
                             signal_and_93,
                             signal_and_90,
                             signal_and_87,
                             signal_and_84,
                             signal_and_81,
                             signal_and_79,
                             signal_and_77,
                             signal_and_75,
                             signal_and_73,
                             signal_and_71,
                             signal_and_69,
                             signal_and_67,
                             signal_and_65,
                             signal_and_64,
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
                             signal_and_50 };
    assign signal_select_316 = signal_cat_94[27:0];
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            wait_select_0 <= signal_const_130;
        else
            if (ir_load)
                wait_select_0 <= signal_select_316;
    end
    assign signal_select_317 = signal_wire_41[0:0];
    assign signal_select_318 = signal_wire_41[1:1];
    assign signal_select_319 = signal_wire_41[2:2];
    assign signal_select_320 = signal_wire_41[3:3];
    assign signal_select_321 = signal_wire_41[4:4];
    assign signal_select_322 = pin_out_0[5:5];
    assign signal_select_323 = pin_out_0[6:6];
    assign signal_select_324 = pin_out_0[7:7];
    assign signal_select_325 = pin_out_0[8:8];
    assign signal_select_326 = pin_out_0[9:9];
    assign signal_select_327 = pin_out_0[10:10];
    assign signal_select_328 = pin_out_0[11:11];
    assign signal_select_329 = pin_out_0[12:12];
    assign signal_select_330 = signal_wire_41[12:12];
    assign signal_select_331 = pin_dir_0[12:12];
    assign signal_mux_120 = signal_select_331 ? signal_select_329 : signal_select_330;
    assign signal_select_332 = pin_out_0[13:13];
    assign signal_select_333 = signal_wire_41[13:13];
    assign signal_select_334 = pin_dir_0[13:13];
    assign signal_mux_121 = signal_select_334 ? signal_select_332 : signal_select_333;
    assign signal_select_335 = pin_out_0[14:14];
    assign signal_select_336 = signal_wire_41[14:14];
    assign signal_select_337 = pin_dir_0[14:14];
    assign signal_mux_122 = signal_select_337 ? signal_select_335 : signal_select_336;
    assign signal_select_338 = pin_out_0[15:15];
    assign signal_select_339 = signal_wire_41[15:15];
    assign signal_select_340 = pin_dir_0[15:15];
    assign signal_mux_123 = signal_select_340 ? signal_select_338 : signal_select_339;
    assign signal_select_341 = pin_out_0[16:16];
    assign signal_select_342 = signal_wire_41[16:16];
    assign signal_select_343 = pin_dir_0[16:16];
    assign signal_mux_124 = signal_select_343 ? signal_select_341 : signal_select_342;
    assign signal_select_344 = pin_out_0[17:17];
    assign signal_select_345 = signal_wire_41[17:17];
    assign signal_select_346 = pin_dir_0[17:17];
    assign signal_mux_125 = signal_select_346 ? signal_select_344 : signal_select_345;
    assign signal_select_347 = pin_out_0[18:18];
    assign signal_select_348 = signal_wire_41[18:18];
    assign signal_select_349 = pin_dir_0[18:18];
    assign signal_mux_126 = signal_select_349 ? signal_select_347 : signal_select_348;
    assign signal_select_350 = pin_out_0[19:19];
    assign signal_select_351 = signal_wire_41[19:19];
    assign signal_select_352 = signal_mux_130[27:12];
    assign signal_select_353 = signal_mux_130[11:0];
    assign signal_cat_95 = { signal_select_353,
                             signal_select_352 };
    assign signal_select_354 = signal_mux_129[27:20];
    assign signal_select_355 = signal_mux_129[19:0];
    assign signal_cat_96 = { signal_select_355,
                             signal_select_354 };
    assign signal_select_356 = signal_mux_128[27:24];
    assign signal_select_357 = signal_mux_128[23:0];
    assign signal_cat_97 = { signal_select_357,
                             signal_select_356 };
    assign signal_select_358 = signal_mux_127[27:26];
    assign signal_select_359 = signal_mux_127[25:0];
    assign signal_cat_98 = { signal_select_359,
                             signal_select_358 };
    assign signal_select_360 = signal_cat_101[27:27];
    assign signal_select_361 = signal_cat_101[26:0];
    assign signal_cat_99 = { signal_select_361,
                             signal_select_360 };
    assign signal_cat_100 = { signal_const_15,
                              d$set_value };
    assign signal_cat_101 = { signal_const_16,
                              signal_cat_100 };
    assign signal_select_362 = signal_wire_16[0:0];
    assign signal_mux_127 = signal_select_362 ? signal_cat_99 : signal_cat_101;
    assign signal_select_363 = signal_wire_16[1:1];
    assign signal_mux_128 = signal_select_363 ? signal_cat_98 : signal_mux_127;
    assign signal_select_364 = signal_wire_16[2:2];
    assign signal_mux_129 = signal_select_364 ? signal_cat_97 : signal_mux_128;
    assign signal_select_365 = signal_wire_16[3:3];
    assign signal_mux_130 = signal_select_365 ? signal_cat_96 : signal_mux_129;
    assign signal_select_366 = signal_wire_16[4:4];
    assign signal_mux_131 = signal_select_366 ? signal_cat_95 : signal_mux_130;
    assign signal_and_110 = signal_mux_131 & signal_and_111;
    assign signal_const_134 = 28'b0000000011111111000000000000;
    assign signal_select_367 = signal_mux_140[27:12];
    assign signal_select_368 = signal_mux_140[11:0];
    assign signal_cat_102 = { signal_select_368,
                              signal_select_367 };
    assign signal_select_369 = signal_mux_139[27:20];
    assign signal_select_370 = signal_mux_139[19:0];
    assign signal_cat_103 = { signal_select_370,
                              signal_select_369 };
    assign signal_select_371 = signal_mux_138[27:24];
    assign signal_select_372 = signal_mux_138[23:0];
    assign signal_cat_104 = { signal_select_372,
                              signal_select_371 };
    assign signal_select_373 = signal_mux_137[27:26];
    assign signal_select_374 = signal_mux_137[25:0];
    assign signal_cat_105 = { signal_select_374,
                              signal_select_373 };
    assign signal_select_375 = signal_cat_111[27:27];
    assign signal_select_376 = signal_cat_111[26:0];
    assign signal_cat_106 = { signal_select_376,
                              signal_select_375 };
    assign signal_select_377 = signal_mux_134[7:0];
    assign signal_cat_107 = { signal_select_377,
                              signal_const_19 };
    assign signal_select_378 = signal_mux_133[11:0];
    assign signal_cat_108 = { signal_select_378,
                              signal_const_20 };
    assign signal_select_379 = signal_mux_132[13:0];
    assign signal_cat_109 = { signal_select_379,
                              signal_const_21 };
    assign signal_select_380 = signal_cat_110[0:0];
    assign signal_mux_132 = signal_select_380 ? signal_const_22 : signal_const_23;
    assign signal_select_381 = signal_cat_110[1:1];
    assign signal_mux_133 = signal_select_381 ? signal_cat_109 : signal_mux_132;
    assign signal_select_382 = signal_cat_110[2:2];
    assign signal_mux_134 = signal_select_382 ? signal_cat_108 : signal_mux_133;
    assign signal_select_383 = signal_cat_110[3:3];
    assign signal_mux_135 = signal_select_383 ? signal_cat_107 : signal_mux_134;
    assign signal_wire_15 = config$set_count;
    assign signal_cat_110 = { signal_const_21,
                              signal_wire_15 };
    assign signal_select_384 = signal_cat_110[4:4];
    assign signal_mux_136 = signal_select_384 ? signal_const_3 : signal_mux_135;
    assign signal_not_40 = ~ signal_mux_136;
    assign signal_cat_111 = { signal_const_16,
                              signal_not_40 };
    assign signal_select_385 = signal_wire_16[0:0];
    assign signal_mux_137 = signal_select_385 ? signal_cat_106 : signal_cat_111;
    assign signal_select_386 = signal_wire_16[1:1];
    assign signal_mux_138 = signal_select_386 ? signal_cat_105 : signal_mux_137;
    assign signal_select_387 = signal_wire_16[2:2];
    assign signal_mux_139 = signal_select_387 ? signal_cat_104 : signal_mux_138;
    assign signal_select_388 = signal_wire_16[3:3];
    assign signal_mux_140 = signal_select_388 ? signal_cat_103 : signal_mux_139;
    assign signal_wire_16 = config$set_base;
    assign signal_select_389 = signal_wire_16[4:4];
    assign signal_mux_141 = signal_select_389 ? signal_cat_102 : signal_mux_140;
    assign signal_and_111 = signal_mux_141 & signal_const_134;
    assign signal_not_41 = ~ signal_and_111;
    assign signal_and_112 = pin_dir_base & signal_not_41;
    assign signal_or_11 = signal_and_112 | signal_and_110;
    assign signal_const_143 = 3'b011;
    assign signal_eq_37 = d$set_dest$binary_variant == signal_const_143;
    assign signal_mux_142 = signal_eq_37 ? signal_or_11 : pin_dir_base;
    assign signal_select_390 = signal_mux_146[27:12];
    assign signal_select_391 = signal_mux_146[11:0];
    assign signal_cat_112 = { signal_select_391,
                              signal_select_390 };
    assign signal_select_392 = signal_mux_145[27:20];
    assign signal_select_393 = signal_mux_145[19:0];
    assign signal_cat_113 = { signal_select_393,
                              signal_select_392 };
    assign signal_select_394 = signal_mux_144[27:24];
    assign signal_select_395 = signal_mux_144[23:0];
    assign signal_cat_114 = { signal_select_395,
                              signal_select_394 };
    assign signal_select_396 = signal_mux_143[27:26];
    assign signal_select_397 = signal_mux_143[25:0];
    assign signal_cat_115 = { signal_select_397,
                              signal_select_396 };
    assign signal_select_398 = signal_cat_117[27:27];
    assign signal_select_399 = signal_cat_117[26:0];
    assign signal_cat_116 = { signal_select_399,
                              signal_select_398 };
    assign signal_cat_117 = { signal_const_16,
                              mov_value };
    assign signal_select_400 = signal_wire_37[0:0];
    assign signal_mux_143 = signal_select_400 ? signal_cat_116 : signal_cat_117;
    assign signal_select_401 = signal_wire_37[1:1];
    assign signal_mux_144 = signal_select_401 ? signal_cat_115 : signal_mux_143;
    assign signal_select_402 = signal_wire_37[2:2];
    assign signal_mux_145 = signal_select_402 ? signal_cat_114 : signal_mux_144;
    assign signal_select_403 = signal_wire_37[3:3];
    assign signal_mux_146 = signal_select_403 ? signal_cat_113 : signal_mux_145;
    assign signal_select_404 = signal_wire_37[4:4];
    assign signal_mux_147 = signal_select_404 ? signal_cat_112 : signal_mux_146;
    assign signal_and_113 = signal_mux_147 & signal_and_114;
    assign signal_select_405 = signal_mux_156[27:12];
    assign signal_select_406 = signal_mux_156[11:0];
    assign signal_cat_118 = { signal_select_406,
                              signal_select_405 };
    assign signal_select_407 = signal_mux_155[27:20];
    assign signal_select_408 = signal_mux_155[19:0];
    assign signal_cat_119 = { signal_select_408,
                              signal_select_407 };
    assign signal_select_409 = signal_mux_154[27:24];
    assign signal_select_410 = signal_mux_154[23:0];
    assign signal_cat_120 = { signal_select_410,
                              signal_select_409 };
    assign signal_select_411 = signal_mux_153[27:26];
    assign signal_select_412 = signal_mux_153[25:0];
    assign signal_cat_121 = { signal_select_412,
                              signal_select_411 };
    assign signal_select_413 = signal_cat_126[27:27];
    assign signal_select_414 = signal_cat_126[26:0];
    assign signal_cat_122 = { signal_select_414,
                              signal_select_413 };
    assign signal_select_415 = signal_mux_150[7:0];
    assign signal_cat_123 = { signal_select_415,
                              signal_const_19 };
    assign signal_select_416 = signal_mux_149[11:0];
    assign signal_cat_124 = { signal_select_416,
                              signal_const_20 };
    assign signal_select_417 = signal_mux_148[13:0];
    assign signal_cat_125 = { signal_select_417,
                              signal_const_21 };
    assign signal_select_418 = signal_wire_17[0:0];
    assign signal_mux_148 = signal_select_418 ? signal_const_22 : signal_const_23;
    assign signal_select_419 = signal_wire_17[1:1];
    assign signal_mux_149 = signal_select_419 ? signal_cat_125 : signal_mux_148;
    assign signal_select_420 = signal_wire_17[2:2];
    assign signal_mux_150 = signal_select_420 ? signal_cat_124 : signal_mux_149;
    assign signal_select_421 = signal_wire_17[3:3];
    assign signal_mux_151 = signal_select_421 ? signal_cat_123 : signal_mux_150;
    assign signal_wire_17 = config$out_count;
    assign signal_select_422 = signal_wire_17[4:4];
    assign signal_mux_152 = signal_select_422 ? signal_const_3 : signal_mux_151;
    assign signal_not_42 = ~ signal_mux_152;
    assign signal_cat_126 = { signal_const_16,
                              signal_not_42 };
    assign signal_select_423 = signal_wire_37[0:0];
    assign signal_mux_153 = signal_select_423 ? signal_cat_122 : signal_cat_126;
    assign signal_select_424 = signal_wire_37[1:1];
    assign signal_mux_154 = signal_select_424 ? signal_cat_121 : signal_mux_153;
    assign signal_select_425 = signal_wire_37[2:2];
    assign signal_mux_155 = signal_select_425 ? signal_cat_120 : signal_mux_154;
    assign signal_select_426 = signal_wire_37[3:3];
    assign signal_mux_156 = signal_select_426 ? signal_cat_119 : signal_mux_155;
    assign signal_select_427 = signal_wire_37[4:4];
    assign signal_mux_157 = signal_select_427 ? signal_cat_118 : signal_mux_156;
    assign signal_and_114 = signal_mux_157 & signal_const_134;
    assign signal_not_43 = ~ signal_and_114;
    assign signal_and_115 = pin_dir_base & signal_not_43;
    assign signal_or_12 = signal_and_115 | signal_and_113;
    assign signal_eq_38 = d$mov_dest$binary_variant == signal_const_143;
    assign signal_mux_158 = signal_eq_38 ? signal_or_12 : pin_dir_base;
    assign signal_select_428 = signal_mux_268[27:12];
    assign signal_select_429 = signal_mux_268[11:0];
    assign signal_cat_127 = { signal_select_429,
                              signal_select_428 };
    assign signal_select_430 = signal_mux_267[27:20];
    assign signal_select_431 = signal_mux_267[19:0];
    assign signal_cat_128 = { signal_select_431,
                              signal_select_430 };
    assign signal_select_432 = signal_mux_266[27:24];
    assign signal_select_433 = signal_mux_266[23:0];
    assign signal_cat_129 = { signal_select_433,
                              signal_select_432 };
    assign signal_select_434 = signal_mux_265[27:26];
    assign signal_select_435 = signal_mux_265[25:0];
    assign signal_cat_130 = { signal_select_435,
                              signal_select_434 };
    assign signal_select_436 = signal_cat_194[27:27];
    assign signal_select_437 = signal_cat_194[26:0];
    assign signal_cat_131 = { signal_select_437,
                              signal_select_436 };
    assign signal_and_116 = osr_before & mask;
    assign signal_select_438 = signal_mux_262[15:8];
    assign signal_cat_132 = { signal_const_19,
                              signal_select_438 };
    assign signal_select_439 = signal_mux_261[15:4];
    assign signal_cat_133 = { signal_const_20,
                              signal_select_439 };
    assign signal_select_440 = signal_mux_260[15:2];
    assign signal_cat_134 = { signal_const_21,
                              signal_select_440 };
    assign signal_select_441 = osr_before[15:1];
    assign signal_cat_135 = { signal_const_4,
                              signal_select_441 };
    assign signal_wire_18 = data_word;
    assign signal_select_442 = signal_inst_1[15:0];
    assign signal_not_44 = ~ signal_select_676;
    assign signal_and_117 = pulls & signal_not_44;
    assign signal_mux_159 = signal_and_117 ? signal_select_442 : osr_0;
    assign signal_select_443 = signal_select_657[15:15];
    assign signal_select_444 = signal_select_657[14:14];
    assign signal_select_445 = signal_select_657[13:13];
    assign signal_select_446 = signal_select_657[12:12];
    assign signal_select_447 = signal_select_657[11:11];
    assign signal_select_448 = signal_select_657[10:10];
    assign signal_select_449 = signal_select_657[9:9];
    assign signal_select_450 = signal_select_657[8:8];
    assign signal_select_451 = signal_select_657[7:7];
    assign signal_select_452 = signal_select_657[6:6];
    assign signal_select_453 = signal_select_657[5:5];
    assign signal_select_454 = signal_select_657[4:4];
    assign signal_select_455 = signal_select_657[3:3];
    assign signal_select_456 = signal_select_657[2:2];
    assign signal_select_457 = signal_select_657[1:1];
    assign signal_select_458 = signal_select_657[0:0];
    assign signal_cat_136 = { signal_select_458,
                              signal_select_457,
                              signal_select_456,
                              signal_select_455,
                              signal_select_454,
                              signal_select_453,
                              signal_select_452,
                              signal_select_451,
                              signal_select_450,
                              signal_select_449,
                              signal_select_448,
                              signal_select_447,
                              signal_select_446,
                              signal_select_445,
                              signal_select_444,
                              signal_select_443 };
    assign signal_not_45 = ~ signal_select_657;
    assign signal_cat_137 = { signal_const_19,
                              osr_0 };
    assign signal_cat_138 = { signal_const_19,
                              isr_0 };
    assign signal_cat_139 = { signal_const_19,
                              y_0 };
    assign signal_xor_1 = x_0 ^ alu_operand;
    assign signal_sub_5 = x_0 - alu_operand;
    assign signal_eq_39 = d$sys_op$binary_variant == signal_const_111;
    assign signal_and_118 = is_opcode$7 & signal_eq_39;
    assign signal_mux_160 = signal_and_118 ? signal_const_3 : isr_0;
    assign signal_eq_40 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_161 = signal_eq_40 ? mov_value : isr_0;
    assign signal_eq_41 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_162 = signal_eq_41 ? out_value : isr_0;
    assign signal_select_459 = signal_mux_165[7:0];
    assign signal_cat_140 = { signal_select_459,
                              signal_const_19 };
    assign signal_select_460 = signal_mux_164[11:0];
    assign signal_cat_141 = { signal_select_460,
                              signal_const_20 };
    assign signal_select_461 = signal_mux_163[13:0];
    assign signal_cat_142 = { signal_select_461,
                              signal_const_21 };
    assign signal_select_462 = in_value[14:0];
    assign signal_cat_143 = { signal_select_462,
                              signal_const_4 };
    assign signal_select_463 = shift_back[0:0];
    assign signal_mux_163 = signal_select_463 ? signal_cat_143 : in_value;
    assign signal_select_464 = shift_back[1:1];
    assign signal_mux_164 = signal_select_464 ? signal_cat_142 : signal_mux_163;
    assign signal_select_465 = shift_back[2:2];
    assign signal_mux_165 = signal_select_465 ? signal_cat_141 : signal_mux_164;
    assign signal_select_466 = shift_back[3:3];
    assign signal_mux_166 = signal_select_466 ? signal_cat_140 : signal_mux_165;
    assign signal_select_467 = shift_back[4:4];
    assign signal_mux_167 = signal_select_467 ? signal_const_3 : signal_mux_166;
    assign signal_select_468 = signal_mux_170[15:8];
    assign signal_cat_144 = { signal_const_19,
                              signal_select_468 };
    assign signal_select_469 = signal_mux_169[15:4];
    assign signal_cat_145 = { signal_const_20,
                              signal_select_469 };
    assign signal_select_470 = signal_mux_168[15:2];
    assign signal_cat_146 = { signal_const_21,
                              signal_select_470 };
    assign signal_select_471 = isr_0[15:1];
    assign signal_cat_147 = { signal_const_4,
                              signal_select_471 };
    assign signal_select_472 = d$shift_count[0:0];
    assign signal_mux_168 = signal_select_472 ? signal_cat_147 : isr_0;
    assign signal_select_473 = d$shift_count[1:1];
    assign signal_mux_169 = signal_select_473 ? signal_cat_146 : signal_mux_168;
    assign signal_select_474 = d$shift_count[2:2];
    assign signal_mux_170 = signal_select_474 ? signal_cat_145 : signal_mux_169;
    assign signal_select_475 = d$shift_count[3:3];
    assign signal_mux_171 = signal_select_475 ? signal_cat_144 : signal_mux_170;
    assign signal_select_476 = d$shift_count[4:4];
    assign signal_mux_172 = signal_select_476 ? signal_const_3 : signal_mux_171;
    assign signal_or_13 = signal_mux_172 | signal_mux_167;
    assign signal_select_477 = signal_mux_175[7:0];
    assign signal_cat_148 = { signal_select_477,
                              signal_const_19 };
    assign signal_select_478 = signal_mux_174[11:0];
    assign signal_cat_149 = { signal_select_478,
                              signal_const_20 };
    assign signal_select_479 = signal_mux_173[13:0];
    assign signal_cat_150 = { signal_select_479,
                              signal_const_21 };
    assign signal_select_480 = d$shift_count[0:0];
    assign signal_mux_173 = signal_select_480 ? signal_const_22 : signal_const_23;
    assign signal_select_481 = d$shift_count[1:1];
    assign signal_mux_174 = signal_select_481 ? signal_cat_150 : signal_mux_173;
    assign signal_select_482 = d$shift_count[2:2];
    assign signal_mux_175 = signal_select_482 ? signal_cat_149 : signal_mux_174;
    assign signal_select_483 = d$shift_count[3:3];
    assign signal_mux_176 = signal_select_483 ? signal_cat_148 : signal_mux_175;
    assign signal_select_484 = d$shift_count[4:4];
    assign signal_mux_177 = signal_select_484 ? signal_const_3 : signal_mux_176;
    assign mask = ~ signal_mux_177;
    assign signal_wire_19 = config$capture_rising;
    assign signal_select_485 = sample[27:27];
    assign signal_select_486 = sample[26:26];
    assign signal_select_487 = sample[25:25];
    assign signal_select_488 = sample[24:24];
    assign signal_select_489 = sample[23:23];
    assign signal_select_490 = sample[22:22];
    assign signal_select_491 = sample[21:21];
    assign signal_select_492 = sample[20:20];
    assign signal_select_493 = sample[19:19];
    assign signal_select_494 = sample[18:18];
    assign signal_select_495 = sample[17:17];
    assign signal_select_496 = sample[16:16];
    assign signal_select_497 = sample[15:15];
    assign signal_select_498 = sample[14:14];
    assign signal_select_499 = sample[13:13];
    assign signal_select_500 = sample[12:12];
    assign signal_select_501 = sample[11:11];
    assign signal_select_502 = sample[10:10];
    assign signal_select_503 = sample[9:9];
    assign signal_select_504 = sample[8:8];
    assign signal_select_505 = sample[7:7];
    assign signal_select_506 = sample[6:6];
    assign signal_select_507 = sample[5:5];
    assign signal_select_508 = sample[4:4];
    assign signal_select_509 = sample[3:3];
    assign signal_select_510 = sample[2:2];
    assign signal_select_511 = sample[1:1];
    assign signal_select_512 = sample[0:0];
    always @* begin
        case (signal_wire_20)
        0:
            signal_mux_178 <= signal_select_512;
        1:
            signal_mux_178 <= signal_select_511;
        2:
            signal_mux_178 <= signal_select_510;
        3:
            signal_mux_178 <= signal_select_509;
        4:
            signal_mux_178 <= signal_select_508;
        5:
            signal_mux_178 <= signal_select_507;
        6:
            signal_mux_178 <= signal_select_506;
        7:
            signal_mux_178 <= signal_select_505;
        8:
            signal_mux_178 <= signal_select_504;
        9:
            signal_mux_178 <= signal_select_503;
        10:
            signal_mux_178 <= signal_select_502;
        11:
            signal_mux_178 <= signal_select_501;
        12:
            signal_mux_178 <= signal_select_500;
        13:
            signal_mux_178 <= signal_select_499;
        14:
            signal_mux_178 <= signal_select_498;
        15:
            signal_mux_178 <= signal_select_497;
        16:
            signal_mux_178 <= signal_select_496;
        17:
            signal_mux_178 <= signal_select_495;
        18:
            signal_mux_178 <= signal_select_494;
        19:
            signal_mux_178 <= signal_select_493;
        20:
            signal_mux_178 <= signal_select_492;
        21:
            signal_mux_178 <= signal_select_491;
        22:
            signal_mux_178 <= signal_select_490;
        23:
            signal_mux_178 <= signal_select_489;
        24:
            signal_mux_178 <= signal_select_488;
        25:
            signal_mux_178 <= signal_select_487;
        26:
            signal_mux_178 <= signal_select_486;
        default:
            signal_mux_178 <= signal_select_485;
        endcase
    end
    assign signal_eq_42 = signal_mux_178 == signal_wire_19;
    assign signal_select_513 = pins_sampled[27:27];
    assign signal_select_514 = pins_sampled[26:26];
    assign signal_select_515 = pins_sampled[25:25];
    assign signal_select_516 = pins_sampled[24:24];
    assign signal_select_517 = pins_sampled[23:23];
    assign signal_select_518 = pins_sampled[22:22];
    assign signal_select_519 = pins_sampled[21:21];
    assign signal_select_520 = pins_sampled[20:20];
    assign signal_select_521 = pins_sampled[19:19];
    assign signal_select_522 = pins_sampled[18:18];
    assign signal_select_523 = pins_sampled[17:17];
    assign signal_select_524 = pins_sampled[16:16];
    assign signal_select_525 = pins_sampled[15:15];
    assign signal_select_526 = pins_sampled[14:14];
    assign signal_select_527 = pins_sampled[13:13];
    assign signal_select_528 = pins_sampled[12:12];
    assign signal_select_529 = pins_sampled[11:11];
    assign signal_select_530 = pins_sampled[10:10];
    assign signal_select_531 = pins_sampled[9:9];
    assign signal_select_532 = pins_sampled[8:8];
    assign signal_select_533 = pins_sampled[7:7];
    assign signal_select_534 = pins_sampled[6:6];
    assign signal_select_535 = pins_sampled[5:5];
    assign signal_select_536 = pins_sampled[4:4];
    assign signal_select_537 = pins_sampled[3:3];
    assign signal_select_538 = pins_sampled[2:2];
    assign signal_select_539 = pins_sampled[1:1];
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_12 <= signal_const_14;
        else
            signal_reg_12 <= sample;
    end
    assign pins_sampled = signal_reg_12;
    assign signal_select_540 = pins_sampled[0:0];
    always @* begin
        case (signal_wire_20)
        0:
            signal_mux_179 <= signal_select_540;
        1:
            signal_mux_179 <= signal_select_539;
        2:
            signal_mux_179 <= signal_select_538;
        3:
            signal_mux_179 <= signal_select_537;
        4:
            signal_mux_179 <= signal_select_536;
        5:
            signal_mux_179 <= signal_select_535;
        6:
            signal_mux_179 <= signal_select_534;
        7:
            signal_mux_179 <= signal_select_533;
        8:
            signal_mux_179 <= signal_select_532;
        9:
            signal_mux_179 <= signal_select_531;
        10:
            signal_mux_179 <= signal_select_530;
        11:
            signal_mux_179 <= signal_select_529;
        12:
            signal_mux_179 <= signal_select_528;
        13:
            signal_mux_179 <= signal_select_527;
        14:
            signal_mux_179 <= signal_select_526;
        15:
            signal_mux_179 <= signal_select_525;
        16:
            signal_mux_179 <= signal_select_524;
        17:
            signal_mux_179 <= signal_select_523;
        18:
            signal_mux_179 <= signal_select_522;
        19:
            signal_mux_179 <= signal_select_521;
        20:
            signal_mux_179 <= signal_select_520;
        21:
            signal_mux_179 <= signal_select_519;
        22:
            signal_mux_179 <= signal_select_518;
        23:
            signal_mux_179 <= signal_select_517;
        24:
            signal_mux_179 <= signal_select_516;
        25:
            signal_mux_179 <= signal_select_515;
        26:
            signal_mux_179 <= signal_select_514;
        default:
            signal_mux_179 <= signal_select_513;
        endcase
    end
    assign signal_select_541 = sample[27:27];
    assign signal_select_542 = sample[26:26];
    assign signal_select_543 = sample[25:25];
    assign signal_select_544 = sample[24:24];
    assign signal_select_545 = sample[23:23];
    assign signal_select_546 = sample[22:22];
    assign signal_select_547 = sample[21:21];
    assign signal_select_548 = sample[20:20];
    assign signal_select_549 = sample[19:19];
    assign signal_select_550 = sample[18:18];
    assign signal_select_551 = sample[17:17];
    assign signal_select_552 = sample[16:16];
    assign signal_select_553 = sample[15:15];
    assign signal_select_554 = sample[14:14];
    assign signal_select_555 = sample[13:13];
    assign signal_select_556 = sample[12:12];
    assign signal_select_557 = sample[11:11];
    assign signal_select_558 = sample[10:10];
    assign signal_select_559 = sample[9:9];
    assign signal_select_560 = sample[8:8];
    assign signal_select_561 = sample[7:7];
    assign signal_select_562 = sample[6:6];
    assign signal_select_563 = sample[5:5];
    assign signal_select_564 = sample[4:4];
    assign signal_select_565 = sample[3:3];
    assign signal_select_566 = sample[2:2];
    assign signal_select_567 = sample[1:1];
    assign signal_select_568 = sample[0:0];
    assign signal_wire_20 = config$capture_pin;
    always @* begin
        case (signal_wire_20)
        0:
            signal_mux_180 <= signal_select_568;
        1:
            signal_mux_180 <= signal_select_567;
        2:
            signal_mux_180 <= signal_select_566;
        3:
            signal_mux_180 <= signal_select_565;
        4:
            signal_mux_180 <= signal_select_564;
        5:
            signal_mux_180 <= signal_select_563;
        6:
            signal_mux_180 <= signal_select_562;
        7:
            signal_mux_180 <= signal_select_561;
        8:
            signal_mux_180 <= signal_select_560;
        9:
            signal_mux_180 <= signal_select_559;
        10:
            signal_mux_180 <= signal_select_558;
        11:
            signal_mux_180 <= signal_select_557;
        12:
            signal_mux_180 <= signal_select_556;
        13:
            signal_mux_180 <= signal_select_555;
        14:
            signal_mux_180 <= signal_select_554;
        15:
            signal_mux_180 <= signal_select_553;
        16:
            signal_mux_180 <= signal_select_552;
        17:
            signal_mux_180 <= signal_select_551;
        18:
            signal_mux_180 <= signal_select_550;
        19:
            signal_mux_180 <= signal_select_549;
        20:
            signal_mux_180 <= signal_select_548;
        21:
            signal_mux_180 <= signal_select_547;
        22:
            signal_mux_180 <= signal_select_546;
        23:
            signal_mux_180 <= signal_select_545;
        24:
            signal_mux_180 <= signal_select_544;
        25:
            signal_mux_180 <= signal_select_543;
        26:
            signal_mux_180 <= signal_select_542;
        default:
            signal_mux_180 <= signal_select_541;
        endcase
    end
    assign signal_eq_43 = signal_mux_180 == signal_mux_179;
    assign signal_not_46 = ~ signal_eq_43;
    assign signal_const_189 = 4'b0111;
    assign signal_eq_44 = d$sys_op$binary_variant == signal_const_189;
    assign signal_and_119 = is_opcode$7 & signal_eq_44;
    assign signal_and_120 = op_go & signal_and_119;
    assign signal_mux_181 = signal_and_120 ? vdd : capture_armed_0;
    assign signal_mux_182 = captured ? gnd : signal_mux_181;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_13 <= signal_const_4;
        else
            signal_reg_13 <= signal_mux_182;
    end
    assign capture_armed_0 = signal_reg_13;
    assign signal_and_121 = capture_armed_0 & signal_not_46;
    assign captured = signal_and_121 & signal_eq_42;
    assign signal_const_193 = 24'b000000000000000000000001;
    assign signal_add_6 = now_0 + signal_const_193;
    assign signal_mux_183 = start_0 ? signal_const_5 : signal_add_6;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_14 <= signal_const_5;
        else
            signal_reg_14 <= signal_mux_183;
    end
    assign now_0 = signal_reg_14;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_15 <= signal_const_5;
        else
            if (captured)
                signal_reg_15 <= now_0;
    end
    assign capture_0 = signal_reg_15;
    assign signal_select_569 = capture_0[15:0];
    assign signal_wire_21 = config$crc_init;
    assign signal_select_570 = signal_mux_186[7:0];
    assign signal_cat_151 = { signal_select_570,
                              signal_const_19 };
    assign signal_select_571 = signal_mux_185[11:0];
    assign signal_cat_152 = { signal_select_571,
                              signal_const_20 };
    assign signal_select_572 = signal_mux_184[13:0];
    assign signal_cat_153 = { signal_select_572,
                              signal_const_21 };
    assign signal_select_573 = signal_wire_23[0:0];
    assign signal_mux_184 = signal_select_573 ? signal_const_22 : signal_const_23;
    assign signal_select_574 = signal_wire_23[1:1];
    assign signal_mux_185 = signal_select_574 ? signal_cat_153 : signal_mux_184;
    assign signal_select_575 = signal_wire_23[2:2];
    assign signal_mux_186 = signal_select_575 ? signal_cat_152 : signal_mux_185;
    assign signal_select_576 = signal_wire_23[3:3];
    assign signal_mux_187 = signal_select_576 ? signal_cat_151 : signal_mux_186;
    assign signal_select_577 = signal_wire_23[4:4];
    assign signal_mux_188 = signal_select_577 ? signal_const_3 : signal_mux_187;
    assign signal_not_47 = ~ signal_mux_188;
    assign signal_xor_2 = signal_cat_154 ^ signal_wire_22;
    assign signal_select_578 = crc_0[15:1];
    assign signal_cat_154 = { signal_const_4,
                              signal_select_578 };
    assign signal_select_579 = crc_0[0:0];
    assign signal_xor_3 = signal_select_579 ^ crossing_bit;
    assign signal_mux_189 = signal_xor_3 ? signal_xor_2 : signal_cat_154;
    assign signal_wire_22 = config$crc_poly;
    assign signal_xor_4 = signal_cat_155 ^ signal_wire_22;
    assign signal_select_580 = crc_0[14:0];
    assign signal_cat_155 = { signal_select_580,
                              signal_const_4 };
    assign signal_select_581 = in_value[0:0];
    assign signal_select_582 = out_value[0:0];
    assign crossing_bit = is_opcode$2 ? signal_select_581 : signal_select_582;
    assign signal_select_583 = crc_0[15:15];
    assign signal_select_584 = crc_0[14:14];
    assign signal_select_585 = crc_0[13:13];
    assign signal_select_586 = crc_0[12:12];
    assign signal_select_587 = crc_0[11:11];
    assign signal_select_588 = crc_0[10:10];
    assign signal_select_589 = crc_0[9:9];
    assign signal_select_590 = crc_0[8:8];
    assign signal_select_591 = crc_0[7:7];
    assign signal_select_592 = crc_0[6:6];
    assign signal_select_593 = crc_0[5:5];
    assign signal_select_594 = crc_0[4:4];
    assign signal_select_595 = crc_0[3:3];
    assign signal_select_596 = crc_0[2:2];
    assign signal_select_597 = crc_0[1:1];
    assign signal_select_598 = crc_0[0:0];
    assign signal_wire_23 = config$crc_width;
    assign signal_sub_6 = signal_wire_23 - signal_const_68;
    always @* begin
        case (signal_sub_6)
        0:
            signal_mux_190 <= signal_select_598;
        1:
            signal_mux_190 <= signal_select_597;
        2:
            signal_mux_190 <= signal_select_596;
        3:
            signal_mux_190 <= signal_select_595;
        4:
            signal_mux_190 <= signal_select_594;
        5:
            signal_mux_190 <= signal_select_593;
        6:
            signal_mux_190 <= signal_select_592;
        7:
            signal_mux_190 <= signal_select_591;
        8:
            signal_mux_190 <= signal_select_590;
        9:
            signal_mux_190 <= signal_select_589;
        10:
            signal_mux_190 <= signal_select_588;
        11:
            signal_mux_190 <= signal_select_587;
        12:
            signal_mux_190 <= signal_select_586;
        13:
            signal_mux_190 <= signal_select_585;
        14:
            signal_mux_190 <= signal_select_584;
        default:
            signal_mux_190 <= signal_select_583;
        endcase
    end
    assign signal_xor_5 = signal_mux_190 ^ crossing_bit;
    assign signal_mux_191 = signal_xor_5 ? signal_xor_4 : signal_cat_155;
    assign signal_wire_24 = config$crc_reflect;
    assign signal_mux_192 = signal_wire_24 ? signal_mux_189 : signal_mux_191;
    assign crc_stepped = signal_mux_192 & signal_not_47;
    assign signal_const_204 = 3'b010;
    assign signal_eq_45 = signal_select_770 == signal_const_204;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            is_opcode$2 <= gnd;
        else
            if (ir_load)
                is_opcode$2 <= signal_eq_45;
    end
    assign signal_or_14 = is_opcode$2 | is_opcode$3;
    assign signal_eq_46 = d$shift_count == signal_const_68;
    assign bit_crosses = signal_eq_46 & signal_or_14;
    assign signal_mux_193 = bit_crosses ? crc_stepped : crc_0;
    assign signal_const_206 = 4'b0101;
    assign signal_eq_47 = d$sys_op$binary_variant == signal_const_206;
    assign signal_and_122 = is_opcode$7 & signal_eq_47;
    assign crc_next = signal_and_122 ? signal_wire_21 : signal_mux_193;
    assign signal_mux_194 = go ? crc_next : crc_0;
    assign signal_mux_195 = start_0 ? signal_wire_21 : signal_mux_194;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_16 <= signal_const_3;
        else
            signal_reg_16 <= signal_mux_195;
    end
    assign crc_0 = signal_reg_16;
    assign signal_select_599 = signal_mux_198[7:0];
    assign signal_cat_156 = { signal_select_599,
                              signal_const_19 };
    assign signal_select_600 = signal_mux_197[11:0];
    assign signal_cat_157 = { signal_select_600,
                              signal_const_20 };
    assign signal_select_601 = signal_mux_196[13:0];
    assign signal_cat_158 = { signal_select_601,
                              signal_const_21 };
    assign signal_select_602 = d$shift_count[0:0];
    assign signal_mux_196 = signal_select_602 ? signal_const_22 : signal_const_23;
    assign signal_select_603 = d$shift_count[1:1];
    assign signal_mux_197 = signal_select_603 ? signal_cat_158 : signal_mux_196;
    assign signal_select_604 = d$shift_count[2:2];
    assign signal_mux_198 = signal_select_604 ? signal_cat_157 : signal_mux_197;
    assign signal_select_605 = d$shift_count[3:3];
    assign signal_mux_199 = signal_select_605 ? signal_cat_156 : signal_mux_198;
    assign signal_select_606 = d$shift_count[4:4];
    assign signal_mux_200 = signal_select_606 ? signal_const_3 : signal_mux_199;
    assign signal_not_48 = ~ signal_mux_200;
    assign signal_select_607 = signal_mux_204[27:16];
    assign signal_select_608 = signal_mux_204[15:0];
    assign signal_cat_159 = { signal_select_608,
                              signal_select_607 };
    assign signal_select_609 = signal_mux_203[27:8];
    assign signal_select_610 = signal_mux_203[7:0];
    assign signal_cat_160 = { signal_select_610,
                              signal_select_609 };
    assign signal_select_611 = signal_mux_202[27:4];
    assign signal_select_612 = signal_mux_202[3:0];
    assign signal_cat_161 = { signal_select_612,
                              signal_select_611 };
    assign signal_select_613 = signal_mux_201[27:2];
    assign signal_select_614 = signal_mux_201[1:0];
    assign signal_cat_162 = { signal_select_614,
                              signal_select_613 };
    assign signal_select_615 = sample[27:1];
    assign signal_select_616 = sample[0:0];
    assign signal_cat_163 = { signal_select_616,
                              signal_select_615 };
    assign signal_select_617 = signal_wire_29[0:0];
    assign signal_mux_201 = signal_select_617 ? signal_cat_163 : sample;
    assign signal_select_618 = signal_wire_29[1:1];
    assign signal_mux_202 = signal_select_618 ? signal_cat_162 : signal_mux_201;
    assign signal_select_619 = signal_wire_29[2:2];
    assign signal_mux_203 = signal_select_619 ? signal_cat_161 : signal_mux_202;
    assign signal_select_620 = signal_wire_29[3:3];
    assign signal_mux_204 = signal_select_620 ? signal_cat_160 : signal_mux_203;
    assign signal_select_621 = signal_wire_29[4:4];
    assign signal_mux_205 = signal_select_621 ? signal_cat_159 : signal_mux_204;
    assign signal_select_622 = signal_mux_205[15:0];
    assign signal_and_123 = signal_select_622 & signal_not_48;
    always @* begin
        case (d$out_dest$binary_variant)
        0:
            signal_mux_206 <= signal_and_123;
        1:
            signal_mux_206 <= x_0;
        2:
            signal_mux_206 <= y_0;
        3:
            signal_mux_206 <= signal_const_3;
        4:
            signal_mux_206 <= isr_0;
        5:
            signal_mux_206 <= osr_0;
        6:
            signal_mux_206 <= crc_0;
        default:
            signal_mux_206 <= signal_select_569;
        endcase
    end
    assign in_value = signal_mux_206 & mask;
    assign signal_select_623 = signal_mux_209[7:0];
    assign signal_cat_164 = { signal_select_623,
                              signal_const_19 };
    assign signal_select_624 = signal_mux_208[11:0];
    assign signal_cat_165 = { signal_select_624,
                              signal_const_20 };
    assign signal_select_625 = signal_mux_207[13:0];
    assign signal_cat_166 = { signal_select_625,
                              signal_const_21 };
    assign signal_select_626 = isr_0[14:0];
    assign signal_cat_167 = { signal_select_626,
                              signal_const_4 };
    assign signal_select_627 = d$shift_count[0:0];
    assign signal_mux_207 = signal_select_627 ? signal_cat_167 : isr_0;
    assign signal_select_628 = d$shift_count[1:1];
    assign signal_mux_208 = signal_select_628 ? signal_cat_166 : signal_mux_207;
    assign signal_select_629 = d$shift_count[2:2];
    assign signal_mux_209 = signal_select_629 ? signal_cat_165 : signal_mux_208;
    assign signal_select_630 = d$shift_count[3:3];
    assign signal_mux_210 = signal_select_630 ? signal_cat_164 : signal_mux_209;
    assign signal_select_631 = d$shift_count[4:4];
    assign signal_mux_211 = signal_select_631 ? signal_const_3 : signal_mux_210;
    assign signal_or_15 = signal_mux_211 | in_value;
    assign signal_wire_25 = config$in_shift_right;
    assign isr_shifted = signal_wire_25 ? signal_or_13 : signal_or_15;
    assign signal_wire_26 = config$push_threshold;
    assign signal_select_632 = signal_add_7[4:0];
    assign signal_cat_168 = { gnd,
                              d$shift_count };
    assign signal_eq_48 = d$sys_op$binary_variant == signal_const_111;
    assign signal_and_124 = is_opcode$7 & signal_eq_48;
    assign signal_mux_212 = signal_and_124 ? osr_count_zero : isr_count_0;
    assign signal_eq_49 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_213 = signal_eq_49 ? osr_count_zero : isr_count_0;
    assign signal_eq_50 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_214 = signal_eq_50 ? d$shift_count : isr_count_0;
    assign signal_mux_215 = autopush_now ? osr_count_zero : isr_count_next;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_count_next_value <= isr_count_0;
        1:
            isr_count_next_value <= isr_count_0;
        2:
            isr_count_next_value <= signal_mux_215;
        3:
            isr_count_next_value <= signal_mux_214;
        4:
            isr_count_next_value <= signal_mux_213;
        5:
            isr_count_next_value <= isr_count_0;
        6:
            isr_count_next_value <= isr_count_0;
        default:
            isr_count_next_value <= signal_mux_212;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_17 <= signal_const_70;
        else
            if (go)
                signal_reg_17 <= isr_count_next_value;
    end
    assign isr_count_0 = signal_reg_17;
    assign signal_cat_169 = { gnd,
                              isr_count_0 };
    assign signal_add_7 = signal_cat_169 + signal_cat_168;
    assign signal_const_224 = 6'b010000;
    assign signal_lt_12 = signal_const_224 < signal_add_7;
    assign isr_count_next = signal_lt_12 ? signal_const_86 : signal_select_632;
    assign signal_lt_13 = isr_count_next < signal_wire_26;
    assign signal_not_49 = ~ signal_lt_13;
    assign signal_wire_27 = config$autopush;
    assign autopush_now = signal_wire_27 & signal_not_49;
    assign signal_mux_216 = autopush_now ? signal_const_3 : isr_shifted;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_next <= isr_0;
        1:
            isr_next <= isr_0;
        2:
            isr_next <= signal_mux_216;
        3:
            isr_next <= signal_mux_162;
        4:
            isr_next <= signal_mux_161;
        5:
            isr_next <= isr_0;
        6:
            isr_next <= isr_0;
        default:
            isr_next <= signal_mux_160;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_18 <= signal_const_3;
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
            signal_mux_217 <= signal_add_8;
        1:
            signal_mux_217 <= signal_sub_7;
        default:
            signal_mux_217 <= signal_xor_6;
        endcase
    end
    assign signal_eq_51 = d$alu_dest$binary_variant == signal_const_127;
    assign signal_mux_218 = signal_eq_51 ? signal_mux_217 : p_0;
    assign signal_cat_170 = { signal_const_15,
                              d$set_value };
    assign signal_eq_52 = d$set_dest$binary_variant == signal_const;
    assign signal_mux_219 = signal_eq_52 ? signal_cat_170 : p_0;
    assign signal_eq_53 = d$mov_dest$binary_variant == signal_const_2;
    assign signal_mux_220 = signal_eq_53 ? mov_value : p_0;
    assign signal_eq_54 = d$out_dest$binary_variant == signal_const_2;
    assign signal_mux_221 = signal_eq_54 ? out_value : p_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            p_next <= p_0;
        1:
            p_next <= p_0;
        2:
            p_next <= p_0;
        3:
            p_next <= signal_mux_221;
        4:
            p_next <= signal_mux_220;
        5:
            p_next <= signal_mux_219;
        6:
            p_next <= signal_mux_218;
        default:
            p_next <= p_0;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_19 <= signal_const_3;
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
            signal_mux_222 <= signal_add_9;
        1:
            signal_mux_222 <= signal_sub_8;
        default:
            signal_mux_222 <= signal_xor_7;
        endcase
    end
    assign signal_const_232 = 2'b01;
    assign signal_eq_55 = d$alu_dest$binary_variant == signal_const_232;
    assign signal_mux_223 = signal_eq_55 ? signal_mux_222 : y_0;
    assign signal_cat_171 = { signal_const_15,
                              d$set_value };
    assign signal_eq_56 = d$set_dest$binary_variant == signal_const_204;
    assign signal_mux_224 = signal_eq_56 ? signal_cat_171 : y_0;
    assign signal_eq_57 = d$mov_dest$binary_variant == signal_const_204;
    assign signal_mux_225 = signal_eq_57 ? mov_value : y_0;
    assign signal_eq_58 = d$out_dest$binary_variant == signal_const_204;
    assign signal_mux_226 = signal_eq_58 ? out_value : y_0;
    assign signal_const_237 = 16'b0000000000000001;
    assign signal_sub_9 = y_0 - signal_const_237;
    assign signal_eq_59 = d$jmp_cond$binary_variant == signal_const_10;
    assign signal_mux_227 = signal_eq_59 ? signal_sub_9 : y_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            y_next <= signal_mux_227;
        1:
            y_next <= y_0;
        2:
            y_next <= y_0;
        3:
            y_next <= signal_mux_226;
        4:
            y_next <= signal_mux_225;
        5:
            y_next <= signal_mux_224;
        6:
            y_next <= signal_mux_223;
        default:
            y_next <= y_0;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_20 <= signal_const_3;
        else
            if (go)
                signal_reg_20 <= y_next;
    end
    assign y_0 = signal_reg_20;
    always @* begin
        case (d$alu_reg$binary_variant)
        0:
            signal_mux_228 <= x_0;
        1:
            signal_mux_228 <= y_0;
        2:
            signal_mux_228 <= p_0;
        3:
            signal_mux_228 <= isr_0;
        default:
            signal_mux_228 <= osr_0;
        endcase
    end
    assign d$alu_reg$binary_variant = word[2:0];
    assign signal_const_239 = 13'b0000000000000;
    assign signal_cat_172 = { signal_const_239,
                              d$alu_reg$binary_variant };
    assign d$alu_is_reg = word[3:3];
    assign alu_operand = d$alu_is_reg ? signal_mux_228 : signal_cat_172;
    assign signal_add_10 = x_0 + alu_operand;
    assign d$alu_op$binary_variant = word[5:4];
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_229 <= signal_add_10;
        1:
            signal_mux_229 <= signal_sub_5;
        default:
            signal_mux_229 <= signal_xor_1;
        endcase
    end
    assign d$alu_dest$binary_variant = word[7:6];
    assign signal_eq_60 = d$alu_dest$binary_variant == signal_const_21;
    assign signal_mux_230 = signal_eq_60 ? signal_mux_229 : x_0;
    assign d$set_value = word[4:0];
    assign signal_cat_173 = { signal_const_15,
                              d$set_value };
    assign signal_const_242 = 3'b001;
    assign d$set_dest$binary_variant = word[7:5];
    assign signal_eq_61 = d$set_dest$binary_variant == signal_const_242;
    assign signal_mux_231 = signal_eq_61 ? signal_cat_173 : x_0;
    assign signal_eq_62 = d$mov_dest$binary_variant == signal_const_242;
    assign signal_mux_232 = signal_eq_62 ? mov_value : x_0;
    assign signal_eq_63 = d$out_dest$binary_variant == signal_const_242;
    assign signal_mux_233 = signal_eq_63 ? out_value : x_0;
    assign signal_sub_10 = x_0 - signal_const_237;
    assign d$jmp_cond$binary_variant = word[12:9];
    assign signal_eq_64 = d$jmp_cond$binary_variant == signal_const_79;
    assign signal_mux_234 = signal_eq_64 ? signal_sub_10 : x_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            x_next <= signal_mux_234;
        1:
            x_next <= x_0;
        2:
            x_next <= x_0;
        3:
            x_next <= signal_mux_233;
        4:
            x_next <= signal_mux_232;
        5:
            x_next <= signal_mux_231;
        6:
            x_next <= signal_mux_230;
        default:
            x_next <= x_0;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_21 <= signal_const_3;
        else
            if (go)
                signal_reg_21 <= x_next;
    end
    assign x_0 = signal_reg_21;
    assign signal_cat_174 = { signal_const_19,
                              x_0 };
    assign signal_select_633 = signal_mux_237[7:0];
    assign signal_cat_175 = { signal_select_633,
                              signal_const_19 };
    assign signal_select_634 = signal_mux_236[11:0];
    assign signal_cat_176 = { signal_select_634,
                              signal_const_20 };
    assign signal_select_635 = signal_mux_235[13:0];
    assign signal_cat_177 = { signal_select_635,
                              signal_const_21 };
    assign signal_select_636 = signal_wire_28[0:0];
    assign signal_mux_235 = signal_select_636 ? signal_const_22 : signal_const_23;
    assign signal_select_637 = signal_wire_28[1:1];
    assign signal_mux_236 = signal_select_637 ? signal_cat_177 : signal_mux_235;
    assign signal_select_638 = signal_wire_28[2:2];
    assign signal_mux_237 = signal_select_638 ? signal_cat_176 : signal_mux_236;
    assign signal_select_639 = signal_wire_28[3:3];
    assign signal_mux_238 = signal_select_639 ? signal_cat_175 : signal_mux_237;
    assign signal_wire_28 = config$in_count;
    assign signal_select_640 = signal_wire_28[4:4];
    assign signal_mux_239 = signal_select_640 ? signal_const_3 : signal_mux_238;
    assign signal_not_50 = ~ signal_mux_239;
    assign signal_select_641 = signal_mux_243[27:16];
    assign signal_select_642 = signal_mux_243[15:0];
    assign signal_cat_178 = { signal_select_642,
                              signal_select_641 };
    assign signal_select_643 = signal_mux_242[27:8];
    assign signal_select_644 = signal_mux_242[7:0];
    assign signal_cat_179 = { signal_select_644,
                              signal_select_643 };
    assign signal_select_645 = signal_mux_241[27:4];
    assign signal_select_646 = signal_mux_241[3:0];
    assign signal_cat_180 = { signal_select_646,
                              signal_select_645 };
    assign signal_select_647 = signal_mux_240[27:2];
    assign signal_select_648 = signal_mux_240[1:0];
    assign signal_cat_181 = { signal_select_648,
                              signal_select_647 };
    assign signal_select_649 = sample[27:1];
    assign signal_select_650 = sample[0:0];
    assign signal_cat_182 = { signal_select_650,
                              signal_select_649 };
    assign signal_select_651 = signal_wire_29[0:0];
    assign signal_mux_240 = signal_select_651 ? signal_cat_182 : sample;
    assign signal_select_652 = signal_wire_29[1:1];
    assign signal_mux_241 = signal_select_652 ? signal_cat_181 : signal_mux_240;
    assign signal_select_653 = signal_wire_29[2:2];
    assign signal_mux_242 = signal_select_653 ? signal_cat_180 : signal_mux_241;
    assign signal_select_654 = signal_wire_29[3:3];
    assign signal_mux_243 = signal_select_654 ? signal_cat_179 : signal_mux_242;
    assign signal_wire_29 = config$in_base;
    assign signal_select_655 = signal_wire_29[4:4];
    assign signal_mux_244 = signal_select_655 ? signal_cat_178 : signal_mux_243;
    assign signal_select_656 = signal_mux_244[15:0];
    assign signal_and_125 = signal_select_656 & signal_not_50;
    assign signal_cat_183 = { signal_const_19,
                              signal_and_125 };
    assign d$mov_source$binary_variant = word[2:0];
    always @* begin
        case (d$mov_source$binary_variant)
        0:
            mov_value24 <= signal_cat_183;
        1:
            mov_value24 <= signal_cat_174;
        2:
            mov_value24 <= signal_cat_139;
        3:
            mov_value24 <= signal_const_5;
        4:
            mov_value24 <= signal_cat_138;
        5:
            mov_value24 <= signal_cat_137;
        6:
            mov_value24 <= now_0;
        default:
            mov_value24 <= capture_0;
        endcase
    end
    assign signal_select_657 = mov_value24[15:0];
    assign d$mov_op$binary_variant = word[4:3];
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value <= signal_select_657;
        1:
            mov_value <= signal_not_45;
        default:
            mov_value <= signal_cat_136;
        endcase
    end
    assign signal_eq_65 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_245 = signal_eq_65 ? mov_value : osr_0;
    assign signal_select_658 = signal_mux_248[15:8];
    assign signal_cat_184 = { signal_const_19,
                              signal_select_658 };
    assign signal_select_659 = signal_mux_247[15:4];
    assign signal_cat_185 = { signal_const_20,
                              signal_select_659 };
    assign signal_select_660 = signal_mux_246[15:2];
    assign signal_cat_186 = { signal_const_21,
                              signal_select_660 };
    assign signal_select_661 = osr_before[15:1];
    assign signal_cat_187 = { signal_const_4,
                              signal_select_661 };
    assign signal_select_662 = d$shift_count[0:0];
    assign signal_mux_246 = signal_select_662 ? signal_cat_187 : osr_before;
    assign signal_select_663 = d$shift_count[1:1];
    assign signal_mux_247 = signal_select_663 ? signal_cat_186 : signal_mux_246;
    assign signal_select_664 = d$shift_count[2:2];
    assign signal_mux_248 = signal_select_664 ? signal_cat_185 : signal_mux_247;
    assign signal_select_665 = d$shift_count[3:3];
    assign signal_mux_249 = signal_select_665 ? signal_cat_184 : signal_mux_248;
    assign signal_select_666 = d$shift_count[4:4];
    assign signal_mux_250 = signal_select_666 ? signal_const_3 : signal_mux_249;
    assign signal_select_667 = signal_mux_253[7:0];
    assign signal_cat_188 = { signal_select_667,
                              signal_const_19 };
    assign signal_select_668 = signal_mux_252[11:0];
    assign signal_cat_189 = { signal_select_668,
                              signal_const_20 };
    assign signal_select_669 = signal_mux_251[13:0];
    assign signal_cat_190 = { signal_select_669,
                              signal_const_21 };
    assign signal_select_670 = osr_before[14:0];
    assign signal_cat_191 = { signal_select_670,
                              signal_const_4 };
    assign signal_select_671 = d$shift_count[0:0];
    assign signal_mux_251 = signal_select_671 ? signal_cat_191 : osr_before;
    assign signal_select_672 = d$shift_count[1:1];
    assign signal_mux_252 = signal_select_672 ? signal_cat_190 : signal_mux_251;
    assign signal_select_673 = d$shift_count[2:2];
    assign signal_mux_253 = signal_select_673 ? signal_cat_189 : signal_mux_252;
    assign signal_select_674 = d$shift_count[3:3];
    assign signal_mux_254 = signal_select_674 ? signal_cat_188 : signal_mux_253;
    assign signal_select_675 = d$shift_count[4:4];
    assign signal_mux_255 = signal_select_675 ? signal_const_3 : signal_mux_254;
    assign osr_shifted = signal_wire_36 ? signal_mux_250 : signal_mux_255;
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
            osr_next <= signal_mux_245;
        5:
            osr_next <= osr_0;
        6:
            osr_next <= osr_0;
        default:
            osr_next <= signal_mux_159;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_22 <= signal_const_3;
        else
            if (go)
                signal_reg_22 <= osr_next;
    end
    assign osr_0 = signal_reg_22;
    assign signal_wire_30 = flush;
    assign flush_0 = signal_wire_30 & halted_0;
    assign signal_not_51 = ~ signal_select_676;
    assign signal_and_126 = pulls & signal_not_51;
    assign signal_and_127 = is_opcode$3 & pull_ok;
    assign signal_or_16 = signal_and_127 | signal_and_126;
    assign signal_and_128 = op_go & signal_or_16;
    assign tx_pop = signal_and_128;
    assign signal_wire_31 = tx$value;
    assign signal_wire_32 = tx$valid;
    host_fifo
        tx
        ( .clock(signal_wire_47),
          .clear(signal_wire_46),
          .push$valid(signal_wire_32),
          .push$value(signal_wire_31),
          .pop(tx_pop),
          .flush(flush_0),
          .head(signal_inst_1[15:0]),
          .level(signal_inst_1[19:16]),
          .empty(signal_inst_1[20:20]),
          .full(signal_inst_1[21:21]) );
    assign signal_select_676 = signal_inst_1[20:20];
    assign signal_not_52 = ~ signal_select_676;
    assign signal_not_53 = ~ signal_wire_33;
    assign pull_fifo = pull_now & signal_not_53;
    assign pull_ok = pull_fifo & signal_not_52;
    assign signal_mux_256 = pull_ok ? signal_select_442 : osr_0;
    assign signal_eq_66 = signal_select_770 == signal_const_143;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            is_opcode$3 <= gnd;
        else
            if (ir_load)
                is_opcode$3 <= signal_eq_66;
    end
    assign signal_and_129 = op_go & is_opcode$3;
    assign pulls_data = signal_and_129 & pull_data_ok;
    assign signal_const_268 = 4'b1000;
    assign signal_eq_67 = d$sys_op$binary_variant == signal_const_268;
    assign signal_and_130 = is_opcode$7 & signal_eq_67;
    assign seeks = op_go & signal_and_130;
    assign signal_or_17 = seeks | pulls_data;
    assign signal_mux_257 = start_0 ? gnd : signal_or_17;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_23 <= signal_const_4;
        else
            signal_reg_23 <= signal_mux_257;
    end
    assign data_moved = signal_reg_23;
    assign signal_not_54 = ~ data_moved;
    assign signal_wire_33 = config$autopull_data;
    assign signal_wire_34 = config$pull_threshold;
    assign signal_const_270 = 4'b0100;
    assign d$sys_op$binary_variant = word[3:0];
    assign signal_eq_68 = d$sys_op$binary_variant == signal_const_270;
    assign signal_eq_69 = signal_select_770 == signal_const_115;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            is_opcode$7 <= gnd;
        else
            if (ir_load)
                is_opcode$7 <= signal_eq_69;
    end
    assign pulls = is_opcode$7 & signal_eq_68;
    assign signal_mux_258 = pulls ? osr_count_zero : osr_count_0;
    assign osr_count_zero = 5'b00000;
    assign d$mov_dest$binary_variant = word[7:5];
    assign signal_eq_70 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_259 = signal_eq_70 ? osr_count_zero : osr_count_0;
    assign signal_select_677 = signal_add_11[4:0];
    assign signal_cat_192 = { gnd,
                              d$shift_count };
    assign osr_count_before = pull_now ? signal_const_70 : osr_count_0;
    assign signal_cat_193 = { gnd,
                              osr_count_before };
    assign signal_add_11 = signal_cat_193 + signal_cat_192;
    assign signal_lt_14 = signal_const_224 < signal_add_11;
    assign osr_count_next = signal_lt_14 ? signal_const_86 : signal_select_677;
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
            osr_count_next_value <= signal_mux_259;
        5:
            osr_count_next_value <= osr_count_0;
        6:
            osr_count_next_value <= osr_count_0;
        default:
            osr_count_next_value <= signal_mux_258;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_24 <= signal_const_86;
        else
            if (go)
                signal_reg_24 <= osr_count_next_value;
    end
    assign osr_count_0 = signal_reg_24;
    assign signal_lt_15 = osr_count_0 < signal_wire_34;
    assign signal_not_55 = ~ signal_lt_15;
    assign signal_wire_35 = config$autopull;
    assign pull_now = signal_wire_35 & signal_not_55;
    assign pull_data = pull_now & signal_wire_33;
    assign pull_data_ok = pull_data & signal_not_54;
    assign osr_before = pull_data_ok ? signal_wire_18 : signal_mux_256;
    assign signal_select_678 = shift_back[0:0];
    assign signal_mux_260 = signal_select_678 ? signal_cat_135 : osr_before;
    assign signal_select_679 = shift_back[1:1];
    assign signal_mux_261 = signal_select_679 ? signal_cat_134 : signal_mux_260;
    assign signal_select_680 = shift_back[2:2];
    assign signal_mux_262 = signal_select_680 ? signal_cat_133 : signal_mux_261;
    assign signal_select_681 = shift_back[3:3];
    assign signal_mux_263 = signal_select_681 ? signal_cat_132 : signal_mux_262;
    assign shift_back = signal_const_86 - d$shift_count;
    assign signal_select_682 = shift_back[4:4];
    assign signal_mux_264 = signal_select_682 ? signal_const_3 : signal_mux_263;
    assign signal_and_131 = signal_mux_264 & mask;
    assign signal_wire_36 = config$out_shift_right;
    assign out_value = signal_wire_36 ? signal_and_116 : signal_and_131;
    assign signal_cat_194 = { signal_const_16,
                              out_value };
    assign signal_select_683 = signal_wire_37[0:0];
    assign signal_mux_265 = signal_select_683 ? signal_cat_131 : signal_cat_194;
    assign signal_select_684 = signal_wire_37[1:1];
    assign signal_mux_266 = signal_select_684 ? signal_cat_130 : signal_mux_265;
    assign signal_select_685 = signal_wire_37[2:2];
    assign signal_mux_267 = signal_select_685 ? signal_cat_129 : signal_mux_266;
    assign signal_select_686 = signal_wire_37[3:3];
    assign signal_mux_268 = signal_select_686 ? signal_cat_128 : signal_mux_267;
    assign signal_select_687 = signal_wire_37[4:4];
    assign signal_mux_269 = signal_select_687 ? signal_cat_127 : signal_mux_268;
    assign signal_and_132 = signal_mux_269 & signal_and_133;
    assign signal_select_688 = signal_mux_278[27:12];
    assign signal_select_689 = signal_mux_278[11:0];
    assign signal_cat_195 = { signal_select_689,
                              signal_select_688 };
    assign signal_select_690 = signal_mux_277[27:20];
    assign signal_select_691 = signal_mux_277[19:0];
    assign signal_cat_196 = { signal_select_691,
                              signal_select_690 };
    assign signal_select_692 = signal_mux_276[27:24];
    assign signal_select_693 = signal_mux_276[23:0];
    assign signal_cat_197 = { signal_select_693,
                              signal_select_692 };
    assign signal_select_694 = signal_mux_275[27:26];
    assign signal_select_695 = signal_mux_275[25:0];
    assign signal_cat_198 = { signal_select_695,
                              signal_select_694 };
    assign signal_select_696 = signal_cat_203[27:27];
    assign signal_select_697 = signal_cat_203[26:0];
    assign signal_cat_199 = { signal_select_697,
                              signal_select_696 };
    assign signal_select_698 = signal_mux_272[7:0];
    assign signal_cat_200 = { signal_select_698,
                              signal_const_19 };
    assign signal_select_699 = signal_mux_271[11:0];
    assign signal_cat_201 = { signal_select_699,
                              signal_const_20 };
    assign signal_select_700 = signal_mux_270[13:0];
    assign signal_cat_202 = { signal_select_700,
                              signal_const_21 };
    assign signal_select_701 = d$shift_count[0:0];
    assign signal_mux_270 = signal_select_701 ? signal_const_22 : signal_const_23;
    assign signal_select_702 = d$shift_count[1:1];
    assign signal_mux_271 = signal_select_702 ? signal_cat_202 : signal_mux_270;
    assign signal_select_703 = d$shift_count[2:2];
    assign signal_mux_272 = signal_select_703 ? signal_cat_201 : signal_mux_271;
    assign signal_select_704 = d$shift_count[3:3];
    assign signal_mux_273 = signal_select_704 ? signal_cat_200 : signal_mux_272;
    assign d$shift_count = word[4:0];
    assign signal_select_705 = d$shift_count[4:4];
    assign signal_mux_274 = signal_select_705 ? signal_const_3 : signal_mux_273;
    assign signal_not_56 = ~ signal_mux_274;
    assign signal_cat_203 = { signal_const_16,
                              signal_not_56 };
    assign signal_select_706 = signal_wire_37[0:0];
    assign signal_mux_275 = signal_select_706 ? signal_cat_199 : signal_cat_203;
    assign signal_select_707 = signal_wire_37[1:1];
    assign signal_mux_276 = signal_select_707 ? signal_cat_198 : signal_mux_275;
    assign signal_select_708 = signal_wire_37[2:2];
    assign signal_mux_277 = signal_select_708 ? signal_cat_197 : signal_mux_276;
    assign signal_select_709 = signal_wire_37[3:3];
    assign signal_mux_278 = signal_select_709 ? signal_cat_196 : signal_mux_277;
    assign signal_wire_37 = config$out_base;
    assign signal_select_710 = signal_wire_37[4:4];
    assign signal_mux_279 = signal_select_710 ? signal_cat_195 : signal_mux_278;
    assign signal_and_133 = signal_mux_279 & signal_const_134;
    assign signal_not_57 = ~ signal_and_133;
    assign signal_and_134 = pin_dir_base & signal_not_57;
    assign signal_or_18 = signal_and_134 | signal_and_132;
    assign d$out_dest$binary_variant = word[7:5];
    assign signal_eq_71 = d$out_dest$binary_variant == signal_const;
    assign signal_mux_280 = signal_eq_71 ? signal_or_18 : pin_dir_base;
    assign signal_select_711 = signal_mux_284[27:12];
    assign signal_select_712 = signal_mux_284[11:0];
    assign signal_cat_204 = { signal_select_712,
                              signal_select_711 };
    assign signal_select_713 = signal_mux_283[27:20];
    assign signal_select_714 = signal_mux_283[19:0];
    assign signal_cat_205 = { signal_select_714,
                              signal_select_713 };
    assign signal_select_715 = signal_mux_282[27:24];
    assign signal_select_716 = signal_mux_282[23:0];
    assign signal_cat_206 = { signal_select_716,
                              signal_select_715 };
    assign signal_select_717 = signal_mux_281[27:26];
    assign signal_select_718 = signal_mux_281[25:0];
    assign signal_cat_207 = { signal_select_718,
                              signal_select_717 };
    assign signal_select_719 = signal_cat_211[27:27];
    assign signal_select_720 = signal_cat_211[26:0];
    assign signal_cat_208 = { signal_select_720,
                              signal_select_719 };
    assign signal_select_721 = signal_select_723[4:3];
    assign signal_select_722 = signal_select_723[4:3];
    assign signal_select_723 = word[12:8];
    assign signal_select_724 = signal_select_723[4:4];
    assign signal_cat_209 = { gnd,
                              signal_select_724 };
    always @* begin
        case (signal_wire_38)
        0:
            d$side_set <= signal_const_21;
        1:
            d$side_set <= signal_cat_209;
        2:
            d$side_set <= signal_select_722;
        default:
            d$side_set <= signal_select_721;
        endcase
    end
    assign signal_cat_210 = { signal_const_36,
                              d$side_set };
    assign signal_cat_211 = { signal_const_16,
                              signal_cat_210 };
    assign signal_select_725 = signal_wire_39[0:0];
    assign signal_mux_281 = signal_select_725 ? signal_cat_208 : signal_cat_211;
    assign signal_select_726 = signal_wire_39[1:1];
    assign signal_mux_282 = signal_select_726 ? signal_cat_207 : signal_mux_281;
    assign signal_select_727 = signal_wire_39[2:2];
    assign signal_mux_283 = signal_select_727 ? signal_cat_206 : signal_mux_282;
    assign signal_select_728 = signal_wire_39[3:3];
    assign signal_mux_284 = signal_select_728 ? signal_cat_205 : signal_mux_283;
    assign signal_select_729 = signal_wire_39[4:4];
    assign signal_mux_285 = signal_select_729 ? signal_cat_204 : signal_mux_284;
    assign signal_and_135 = signal_mux_285 & signal_and_136;
    assign signal_select_730 = signal_mux_294[27:12];
    assign signal_select_731 = signal_mux_294[11:0];
    assign signal_cat_212 = { signal_select_731,
                              signal_select_730 };
    assign signal_select_732 = signal_mux_293[27:20];
    assign signal_select_733 = signal_mux_293[19:0];
    assign signal_cat_213 = { signal_select_733,
                              signal_select_732 };
    assign signal_select_734 = signal_mux_292[27:24];
    assign signal_select_735 = signal_mux_292[23:0];
    assign signal_cat_214 = { signal_select_735,
                              signal_select_734 };
    assign signal_select_736 = signal_mux_291[27:26];
    assign signal_select_737 = signal_mux_291[25:0];
    assign signal_cat_215 = { signal_select_737,
                              signal_select_736 };
    assign signal_select_738 = signal_cat_221[27:27];
    assign signal_select_739 = signal_cat_221[26:0];
    assign signal_cat_216 = { signal_select_739,
                              signal_select_738 };
    assign signal_select_740 = signal_mux_288[7:0];
    assign signal_cat_217 = { signal_select_740,
                              signal_const_19 };
    assign signal_select_741 = signal_mux_287[11:0];
    assign signal_cat_218 = { signal_select_741,
                              signal_const_20 };
    assign signal_select_742 = signal_mux_286[13:0];
    assign signal_cat_219 = { signal_select_742,
                              signal_const_21 };
    assign signal_select_743 = signal_cat_220[0:0];
    assign signal_mux_286 = signal_select_743 ? signal_const_22 : signal_const_23;
    assign signal_select_744 = signal_cat_220[1:1];
    assign signal_mux_287 = signal_select_744 ? signal_cat_219 : signal_mux_286;
    assign signal_select_745 = signal_cat_220[2:2];
    assign signal_mux_288 = signal_select_745 ? signal_cat_218 : signal_mux_287;
    assign signal_select_746 = signal_cat_220[3:3];
    assign signal_mux_289 = signal_select_746 ? signal_cat_217 : signal_mux_288;
    assign signal_wire_38 = config$side_set_count;
    assign signal_cat_220 = { signal_const_25,
                              signal_wire_38 };
    assign signal_select_747 = signal_cat_220[4:4];
    assign signal_mux_290 = signal_select_747 ? signal_const_3 : signal_mux_289;
    assign signal_not_58 = ~ signal_mux_290;
    assign signal_cat_221 = { signal_const_16,
                              signal_not_58 };
    assign signal_select_748 = signal_wire_39[0:0];
    assign signal_mux_291 = signal_select_748 ? signal_cat_216 : signal_cat_221;
    assign signal_select_749 = signal_wire_39[1:1];
    assign signal_mux_292 = signal_select_749 ? signal_cat_215 : signal_mux_291;
    assign signal_select_750 = signal_wire_39[2:2];
    assign signal_mux_293 = signal_select_750 ? signal_cat_214 : signal_mux_292;
    assign signal_select_751 = signal_wire_39[3:3];
    assign signal_mux_294 = signal_select_751 ? signal_cat_213 : signal_mux_293;
    assign signal_wire_39 = config$side_set_base;
    assign signal_select_752 = signal_wire_39[4:4];
    assign signal_mux_295 = signal_select_752 ? signal_cat_212 : signal_mux_294;
    assign signal_and_136 = signal_mux_295 & signal_const_134;
    assign signal_not_59 = ~ signal_and_136;
    assign signal_and_137 = pin_dir_0 & signal_not_59;
    assign pin_dir_side = signal_and_137 | signal_and_135;
    assign signal_wire_40 = config$side_set_pindirs;
    assign pin_dir_base = signal_wire_40 ? pin_dir_side : pin_dir_0;
    assign d$opcode$binary_variant = word[15:13];
    always @* begin
        case (d$opcode$binary_variant)
        0:
            pin_dir_next <= pin_dir_base;
        1:
            pin_dir_next <= pin_dir_base;
        2:
            pin_dir_next <= pin_dir_base;
        3:
            pin_dir_next <= signal_mux_280;
        4:
            pin_dir_next <= signal_mux_158;
        5:
            pin_dir_next <= signal_mux_142;
        6:
            pin_dir_next <= pin_dir_base;
        default:
            pin_dir_next <= pin_dir_base;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_25 <= signal_const_14;
        else
            if (op_go)
                signal_reg_25 <= pin_dir_next;
    end
    assign pin_dir_0 = signal_reg_25;
    assign signal_select_753 = pin_dir_0[19:19];
    assign signal_mux_296 = signal_select_753 ? signal_select_350 : signal_select_351;
    assign signal_select_754 = signal_wire_41[20:20];
    assign signal_select_755 = pin_out_0[20:20];
    assign signal_or_19 = signal_select_755 | signal_select_754;
    assign signal_select_756 = signal_wire_41[21:21];
    assign signal_select_757 = pin_out_0[21:21];
    assign signal_or_20 = signal_select_757 | signal_select_756;
    assign signal_select_758 = signal_wire_41[22:22];
    assign signal_select_759 = pin_out_0[22:22];
    assign signal_or_21 = signal_select_759 | signal_select_758;
    assign signal_select_760 = signal_wire_41[23:23];
    assign signal_select_761 = pin_out_0[23:23];
    assign signal_or_22 = signal_select_761 | signal_select_760;
    assign signal_select_762 = signal_wire_41[24:24];
    assign signal_select_763 = pin_out_0[24:24];
    assign signal_or_23 = signal_select_763 | signal_select_762;
    assign signal_select_764 = signal_wire_41[25:25];
    assign signal_select_765 = pin_out_0[25:25];
    assign signal_or_24 = signal_select_765 | signal_select_764;
    assign signal_select_766 = signal_wire_41[26:26];
    assign signal_select_767 = pin_out_0[26:26];
    assign signal_or_25 = signal_select_767 | signal_select_766;
    assign signal_wire_41 = inputs;
    assign signal_select_768 = signal_wire_41[27:27];
    assign signal_select_769 = pin_out_0[27:27];
    assign signal_or_26 = signal_select_769 | signal_select_768;
    assign sample = { signal_or_26,
                      signal_or_25,
                      signal_or_24,
                      signal_or_23,
                      signal_or_22,
                      signal_or_21,
                      signal_or_20,
                      signal_or_19,
                      signal_mux_296,
                      signal_mux_126,
                      signal_mux_125,
                      signal_mux_124,
                      signal_mux_123,
                      signal_mux_122,
                      signal_mux_121,
                      signal_mux_120,
                      signal_select_328,
                      signal_select_327,
                      signal_select_326,
                      signal_select_325,
                      signal_select_324,
                      signal_select_323,
                      signal_select_322,
                      signal_select_321,
                      signal_select_320,
                      signal_select_319,
                      signal_select_318,
                      signal_select_317 };
    assign signal_and_138 = sample & wait_select_0;
    assign signal_eq_72 = signal_and_138 == signal_const_14;
    assign wait_pin_cur = ~ signal_eq_72;
    assign signal_eq_73 = wait_pin_cur == d$wait_polarity;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            word <= signal_const_3;
        else
            if (ir_load)
                word <= signal_wire_44;
    end
    assign d$wait_source$binary_variant = word[6:5];
    always @* begin
        case (d$wait_source$binary_variant)
        0:
            wait_ready <= signal_eq_73;
        1:
            wait_ready <= signal_and_49;
        2:
            wait_ready <= deadline_ready;
        default:
            wait_ready <= signal_mux_110;
        endcase
    end
    assign signal_not_60 = ~ wait_ready;
    assign gnd = 1'b0;
    assign signal_eq_74 = signal_select_770 == signal_const_242;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            is_opcode$1 <= gnd;
        else
            if (ir_load)
                is_opcode$1 <= signal_eq_74;
    end
    assign wait_holds = is_opcode$1 & signal_not_60;
    assign signal_not_61 = ~ wait_holds;
    assign advance = op_go & signal_not_61;
    assign signal_or_27 = advance | refill;
    assign ir_load = signal_or_27;
    assign signal_eq_75 = signal_select_770 == signal_const_25;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            is_opcode$0 <= vdd;
        else
            if (ir_load)
                is_opcode$0 <= signal_eq_75;
    end
    assign jmp_go = go & is_opcode$0;
    assign signal_mux_297 = jmp_go ? jmp_target_or_next : pc_after_next;
    assign signal_mux_298 = signal_wire_48 ? signal_const_11 : signal_mux_297;
    assign fetch_addr = signal_mux_298;
    assign signal_wire_42 = program_read$valid;
    assign program_read = signal_wire_42 & halted_0;
    assign signal_mux_299 = program_read ? signal_wire_5 : fetch_addr;
    assign signal_mux_300 = program_write ? signal_wire_4 : signal_mux_299;
    assign signal_wire_43 = program_write$valid;
    assign program_write = signal_wire_43 & halted_0;
    assign vdd = 1'b1;
    sram_macro
        sram_macro
        ( .clock(signal_wire_47),
          .men(vdd),
          .wen(program_write),
          .ren(vdd),
          .addr(signal_mux_300),
          .din(signal_wire_3),
          .bm(signal_const_23),
          .dout(signal_inst_2[15:0]) );
    assign signal_wire_44 = signal_inst_2;
    assign signal_select_770 = signal_wire_44[15:13];
    always @* begin
        case (signal_select_770)
        0:
            signal_mux_301 <= signal_lt_9;
        1:
            signal_mux_301 <= signal_mux_96;
        2:
            signal_mux_301 <= signal_and_40;
        3:
            signal_mux_301 <= signal_and_40;
        4:
            signal_mux_301 <= signal_lt_4;
        5:
            signal_mux_301 <= signal_lt_3;
        6:
            signal_mux_301 <= signal_and_39;
        default:
            signal_mux_301 <= signal_and_38;
        endcase
    end
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            decode_ok_0 <= vdd;
        else
            if (ir_load)
                decode_ok_0 <= signal_mux_301;
    end
    assign signal_not_62 = ~ decode_ok_0;
    assign signal_and_139 = issue & signal_not_62;
    assign signal_mux_302 = signal_and_139 ? vdd : signal_mux_95;
    assign signal_wire_45 = stop;
    assign signal_mux_303 = signal_wire_45 ? vdd : signal_mux_302;
    assign signal_wire_46 = clear;
    assign signal_wire_47 = clock;
    assign signal_wire_48 = start;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            start_0 <= signal_const_4;
        else
            start_0 <= signal_wire_48;
    end
    assign halted_next = start_0 ? gnd : signal_mux_303;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_26 <= vdd;
        else
            signal_reg_26 <= halted_next;
    end
    assign halted_0 = signal_reg_26;
    assign signal_not_63 = ~ halted_0;
    assign signal_and_140 = signal_not_63 & signal_eq_11;
    assign issue = signal_and_140 & signal_not_17;
    assign go = issue & decode_ok_0;
    assign op_go = go & signal_not_16;
    assign signal_mux_304 = op_go ? pin_out_next : pin_out_flipped;
    always @(posedge signal_wire_47) begin
        if (signal_wire_46)
            signal_reg_27 <= signal_const_14;
        else
            if (signal_or_3)
                signal_reg_27 <= signal_mux_304;
    end
    assign pin_out_0 = signal_reg_27;
    assign d$alu_imm = d$alu_reg$binary_variant;
    assign d$in_source$binary_variant = d$out_dest$binary_variant;
    assign pin_out = pin_out_0;
    assign pin_dir = pin_dir_0;
    assign pc = pc_0;
    assign data_ptr = data_ptr_0;
    assign data_addr = data_ptr_next;
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
    assign tx_level = signal_select_3;
    assign rx_level = signal_select_2;
    assign rx_head = rx_head_0;
    assign instruction = word;
    assign program_word = signal_wire_44;
    assign decode_ok = decode_ok_0;
    assign opcode_onehot = signal_cat;
    assign wait_select = wait_select_0;
    assign crc = crc_0;
    assign stuff_run = stuff_run_0;
    assign flip_pending = flip_pending_0;
    assign flip_bit = flip_bit_0;

endmodule
module load_checker (
    clock,
    clear,
    check,
    abort,
    config$side_set_count,
    config$capture_pin,
    config$capture_rising,
    config$wrap_bottom,
    config$wrap_top,
    config$period_fraction,
    setup$base,
    setup$loaded$valid,
    setup$loaded$value,
    setup$single_edge,
    program_word,
    data_word,
    config$autopull,
    config$autopull_data,
    config$autopush,
    config$crc_init,
    config$crc_poly,
    config$crc_reflect,
    config$crc_width,
    config$in_base,
    config$in_count,
    config$in_shift_right,
    config$jmp_pin,
    config$manchester,
    config$out_base,
    config$out_count,
    config$out_shift_right,
    config$pull_threshold,
    config$push_threshold,
    config$set_base,
    config$set_count,
    config$side_set_base,
    config$side_set_pindirs,
    config$stuff_level,
    config$stuff_threshold,
    program_read$valid,
    program_read$value,
    data_read$valid,
    data_read$value,
    busy,
    finished,
    accepted,
    reject_pc,
    reason
);

    input clock;
    input clear;
    input check;
    input abort;
    input [1:0] config$side_set_count;
    input [4:0] config$capture_pin;
    input config$capture_rising;
    input [8:0] config$wrap_bottom;
    input [8:0] config$wrap_top;
    input [15:0] config$period_fraction;
    input [8:0] setup$base;
    input setup$loaded$valid;
    input [15:0] setup$loaded$value;
    input setup$single_edge;
    input [15:0] program_word;
    input [15:0] data_word;
    input config$autopull;
    input config$autopull_data;
    input config$autopush;
    input [15:0] config$crc_init;
    input [15:0] config$crc_poly;
    input config$crc_reflect;
    input [4:0] config$crc_width;
    input [4:0] config$in_base;
    input [4:0] config$in_count;
    input config$in_shift_right;
    input [4:0] config$jmp_pin;
    input config$manchester;
    input [4:0] config$out_base;
    input [4:0] config$out_count;
    input config$out_shift_right;
    input [4:0] config$pull_threshold;
    input [4:0] config$push_threshold;
    input [4:0] config$set_base;
    input [2:0] config$set_count;
    input [4:0] config$side_set_base;
    input config$side_set_pindirs;
    input config$stuff_level;
    input [4:0] config$stuff_threshold;
    output program_read$valid;
    output [8:0] program_read$value;
    output data_read$valid;
    output [8:0] data_read$value;
    output busy;
    output finished;
    output accepted;
    output [9:0] reject_pc;
    output [4:0] reason;

    wire [4:0] signal_const;
    wire [4:0] signal_const_1;
    wire [4:0] signal_const_2;
    wire [4:0] signal_mux;
    wire [4:0] signal_const_4;
    wire [4:0] signal_mux_1;
    wire [4:0] signal_const_5;
    wire [4:0] signal_mux_2;
    wire [4:0] signal_const_6;
    wire [4:0] signal_const_7;
    wire [4:0] signal_mux_3;
    wire [4:0] signal_const_8;
    wire [4:0] signal_const_9;
    wire [4:0] signal_mux_4;
    wire [4:0] signal_mux_5;
    wire [4:0] signal_mux_6;
    wire [4:0] signal_const_10;
    wire [4:0] signal_const_11;
    wire [4:0] signal_mux_7;
    wire [4:0] signal_const_12;
    wire [4:0] signal_const_13;
    wire [4:0] signal_mux_8;
    wire [4:0] signal_mux_9;
    wire [4:0] signal_const_14;
    wire [4:0] signal_mux_10;
    wire [4:0] signal_mux_11;
    wire signal_not;
    wire signal_not_1;
    wire signal_not_2;
    wire signal_or;
    wire signal_or_1;
    wire signal_not_3;
    wire signal_not_4;
    wire signal_or_2;
    wire signal_not_5;
    wire signal_not_6;
    wire signal_or_3;
    wire signal_or_4;
    wire signal_not_7;
    wire signal_not_8;
    wire signal_or_5;
    wire signal_or_6;
    wire signal_or_7;
    wire [4:0] next_reason;
    wire [4:0] signal_const_17;
    wire [4:0] signal_const_18;
    wire [4:0] signal_mux_12;
    wire [4:0] signal_const_19;
    wire [4:0] signal_const_20;
    wire [4:0] signal_mux_13;
    wire [4:0] signal_mux_14;
    wire [4:0] signal_const_21;
    wire [4:0] signal_const_22;
    wire [4:0] signal_mux_15;
    wire [4:0] signal_const_23;
    wire [4:0] signal_const_24;
    wire [4:0] signal_mux_16;
    wire [4:0] signal_mux_17;
    wire [4:0] signal_mux_18;
    wire [4:0] signal_const_25;
    wire [4:0] signal_mux_19;
    wire signal_not_9;
    wire signal_not_10;
    wire signal_or_8;
    wire signal_not_11;
    wire signal_not_12;
    wire signal_or_9;
    wire signal_or_10;
    wire signal_not_13;
    wire signal_not_14;
    wire signal_or_11;
    wire signal_not_15;
    wire signal_not_16;
    wire signal_or_12;
    wire signal_or_13;
    wire signal_or_14;
    wire [4:0] target_reason_now;
    reg [4:0] signal_cases;
    wire [4:0] signal_wire;
    reg [4:0] target_reason;
    wire [4:0] signal_mux_20;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_const_27;
    wire [4:0] signal_mux_22;
    wire [4:0] signal_mux_23;
    wire [4:0] signal_mux_24;
    reg [4:0] signal_cases_1;
    wire [4:0] signal_mux_25;
    wire [4:0] signal_wire_1;
    reg [4:0] reason_0;
    wire [9:0] signal_const_28;
    wire [9:0] signal_cat;
    wire [9:0] signal_const_29;
    wire [9:0] signal_mux_26;
    wire [9:0] signal_cat_1;
    wire [9:0] signal_cat_2;
    wire [9:0] signal_mux_27;
    wire [9:0] signal_mux_28;
    wire [9:0] signal_cat_3;
    wire [9:0] signal_mux_29;
    wire [9:0] signal_mux_30;
    wire [9:0] signal_mux_31;
    reg [9:0] signal_cases_2;
    wire [9:0] signal_mux_32;
    wire [9:0] signal_wire_2;
    reg [9:0] reject_pc_0;
    wire signal_const_30;
    wire signal_mux_33;
    wire signal_mux_34;
    wire signal_mux_35;
    wire signal_mux_36;
    wire signal_mux_37;
    wire signal_mux_38;
    reg signal_cases_3;
    wire signal_mux_39;
    wire signal_wire_3;
    reg accepted_0;
    wire signal_mux_40;
    wire signal_mux_41;
    wire signal_mux_42;
    wire signal_mux_43;
    wire signal_mux_44;
    wire signal_mux_45;
    reg signal_cases_4;
    wire signal_mux_46;
    wire signal_wire_4;
    reg finished_0;
    wire signal_eq;
    wire signal_not_17;
    wire [6:0] signal_const_32;
    wire [8:0] signal_cat_4;
    wire [1:0] signal_const_33;
    wire [6:0] signal_const_34;
    wire [6:0] signal_sub;
    wire [1:0] signal_const_35;
    wire [8:0] signal_cat_5;
    wire [10:0] signal_mulu;
    wire [8:0] signal_select;
    wire [8:0] signal_add;
    wire [6:0] signal_sub_1;
    wire [8:0] signal_cat_6;
    wire [7:0] signal_select_1;
    wire [8:0] signal_cat_7;
    wire [7:0] signal_const_40;
    wire [7:0] signal_select_2;
    wire [7:0] signal_mux_47;
    wire [7:0] signal_mux_48;
    reg [7:0] signal_cases_5;
    wire [7:0] signal_wire_5;
    reg [7:0] wide_count;
    wire [8:0] signal_cat_8;
    wire [10:0] signal_mulu_1;
    wire [8:0] signal_select_3;
    wire [8:0] signal_cat_9;
    wire [10:0] signal_mulu_2;
    wire [8:0] signal_select_4;
    wire [8:0] wide_at;
    wire [8:0] narrow_at;
    wire [8:0] signal_add_1;
    wire [8:0] signal_mux_49;
    wire [8:0] interval_at;
    wire [8:0] signal_mux_50;
    wire [8:0] signal_mux_51;
    wire [8:0] signal_cat_10;
    wire [7:0] signal_mux_52;
    wire [7:0] signal_mux_53;
    wire [7:0] signal_mux_54;
    wire [7:0] signal_mux_55;
    wire [7:0] signal_mux_56;
    wire [7:0] signal_mux_57;
    wire [7:0] signal_mux_58;
    reg [7:0] signal_cases_6;
    wire [7:0] signal_wire_6;
    reg [7:0] sel;
    wire [8:0] signal_cat_11;
    wire [10:0] signal_mulu_3;
    wire [8:0] signal_select_5;
    wire [8:0] signal_add_2;
    wire [8:0] signal_add_3;
    wire [8:0] signal_cat_12;
    wire [10:0] signal_mulu_4;
    wire [8:0] signal_select_6;
    wire [8:0] signal_add_4;
    wire [8:0] signal_mux_59;
    wire [8:0] signal_cat_13;
    wire [8:0] signal_cat_14;
    wire [10:0] signal_mulu_5;
    wire [8:0] signal_select_7;
    wire [8:0] signal_const_48;
    wire [8:0] entries_at;
    wire [8:0] signal_add_5;
    wire [8:0] signal_add_6;
    wire [8:0] signal_const_49;
    wire [8:0] signal_mux_60;
    wire [8:0] signal_cat_15;
    wire [8:0] signal_wire_7;
    wire [8:0] signal_add_7;
    reg [8:0] signal_cases_7;
    wire [8:0] data_addr;
    wire [3:0] signal_const_51;
    wire signal_eq_1;
    wire [3:0] signal_mux_61;
    wire [3:0] signal_mux_62;
    wire [3:0] signal_mux_63;
    wire [3:0] signal_const_52;
    wire [3:0] signal_mux_64;
    wire [3:0] signal_mux_65;
    wire [3:0] signal_mux_66;
    wire [3:0] signal_const_478;
    wire signal_mux_67;
    wire signal_mux_68;
    wire signal_not_18;
    wire signal_or_15;
    wire signal_not_19;
    wire signal_or_16;
    wire signal_not_20;
    wire signal_or_17;
    wire signal_not_21;
    wire signal_or_18;
    wire [25:0] signal_cat_16;
    wire signal_lt;
    wire signal_not_22;
    wire [25:0] signal_cat_17;
    wire signal_lt_1;
    wire signal_not_23;
    wire signal_and;
    wire signal_and_1;
    wire [23:0] signal_const_56;
    wire signal_eq_2;
    wire [23:0] signal_const_57;
    wire signal_eq_3;
    wire signal_and_2;
    wire signal_or_19;
    wire signal_not_24;
    wire signal_or_20;
    wire signal_eq_4;
    wire [15:0] signal_const_58;
    wire signal_eq_5;
    wire signal_and_3;
    wire [15:0] signal_const_59;
    wire [15:0] signal_sub_2;
    wire [15:0] signal_mux_69;
    wire [15:0] signal_mux_70;
    wire signal_lt_2;
    wire signal_not_25;
    wire [15:0] signal_sub_3;
    wire signal_eq_6;
    wire [15:0] signal_mux_71;
    wire [15:0] signal_mux_72;
    wire [15:0] signal_mux_73;
    wire signal_lt_3;
    wire signal_not_26;
    wire signal_and_4;
    wire signal_mux_74;
    wire signal_not_27;
    wire signal_or_21;
    wire signal_eq_7;
    wire signal_eq_8;
    wire signal_and_5;
    wire [15:0] signal_sub_4;
    wire [15:0] signal_mux_75;
    wire [15:0] signal_mux_76;
    wire signal_lt_4;
    wire signal_not_28;
    wire [15:0] signal_sub_5;
    wire signal_eq_9;
    wire [15:0] signal_mux_77;
    wire [15:0] signal_mux_78;
    wire [15:0] signal_mux_79;
    wire signal_lt_5;
    wire signal_not_29;
    wire signal_and_6;
    wire signal_mux_80;
    wire signal_not_30;
    wire signal_or_22;
    wire signal_eq_10;
    wire signal_eq_11;
    wire signal_and_7;
    wire [15:0] signal_mux_81;
    wire [15:0] signal_mux_82;
    wire signal_lt_6;
    wire signal_not_31;
    wire [15:0] signal_mux_83;
    wire [15:0] signal_mux_84;
    wire signal_lt_7;
    wire signal_not_32;
    wire signal_and_8;
    wire signal_not_33;
    wire signal_and_9;
    wire signal_mux_85;
    wire signal_not_34;
    wire signal_or_23;
    wire [29:0] signal_select_8;
    wire signal_select_9;
    wire [1:0] signal_cat_18;
    wire [3:0] signal_cat_19;
    wire [4:0] signal_cat_20;
    wire [30:0] signal_cat_21;
    wire [30:0] signal_sub_6;
    wire signal_select_10;
    wire [1:0] signal_cat_22;
    wire [25:0] signal_cat_23;
    wire [25:0] signal_add_8;
    wire [25:0] signal_mux_86;
    wire signal_select_11;
    wire [1:0] signal_cat_24;
    wire [3:0] signal_cat_25;
    wire [4:0] signal_cat_26;
    wire [30:0] signal_cat_27;
    wire [30:0] signal_mux_87;
    wire signal_select_12;
    wire signal_not_35;
    wire [30:0] signal_cat_28;
    wire [29:0] signal_select_13;
    wire [2:0] signal_cat_29;
    wire signal_select_14;
    wire [1:0] signal_cat_30;
    wire [3:0] signal_cat_31;
    wire [6:0] signal_cat_32;
    wire [30:0] signal_cat_33;
    wire signal_select_15;
    wire signal_not_36;
    wire [30:0] signal_cat_34;
    wire signal_lt_8;
    wire signal_not_37;
    wire [29:0] signal_select_16;
    wire [2:0] signal_cat_35;
    wire signal_select_17;
    wire [1:0] signal_cat_36;
    wire [3:0] signal_cat_37;
    wire [6:0] signal_cat_38;
    wire [30:0] signal_cat_39;
    wire signal_select_18;
    wire signal_not_38;
    wire [30:0] signal_cat_40;
    wire [29:0] signal_select_19;
    wire [29:0] signal_muls;
    wire signal_select_20;
    wire [30:0] signal_cat_41;
    wire signal_select_21;
    wire [1:0] signal_cat_42;
    wire [3:0] signal_cat_43;
    wire [4:0] signal_cat_44;
    wire [30:0] signal_cat_45;
    wire [30:0] signal_sub_7;
    wire signal_select_22;
    wire [1:0] signal_cat_46;
    wire [25:0] signal_cat_47;
    wire [25:0] signal_add_9;
    wire [25:0] signal_mux_88;
    wire signal_select_23;
    wire [1:0] signal_cat_48;
    wire [3:0] signal_cat_49;
    wire [4:0] signal_cat_50;
    wire [30:0] signal_cat_51;
    wire [30:0] signal_mux_89;
    wire signal_select_24;
    wire signal_not_39;
    wire [30:0] signal_cat_52;
    wire signal_lt_9;
    wire signal_not_40;
    wire signal_eq_12;
    wire signal_not_41;
    wire signal_and_10;
    wire signal_and_11;
    wire signal_mux_90;
    wire signal_and_12;
    wire signal_and_13;
    wire signal_select_25;
    wire [1:0] signal_cat_53;
    wire [25:0] signal_cat_54;
    wire signal_eq_13;
    wire signal_select_26;
    wire [1:0] signal_cat_55;
    wire [25:0] signal_cat_56;
    wire signal_eq_14;
    wire signal_and_14;
    wire signal_or_24;
    wire signal_not_42;
    wire signal_or_25;
    wire [24:0] signal_select_27;
    wire signal_select_28;
    wire signal_not_43;
    wire [25:0] signal_cat_57;
    wire [24:0] signal_select_29;
    wire signal_select_30;
    wire [1:0] signal_cat_58;
    wire [25:0] signal_cat_59;
    wire signal_select_31;
    wire signal_not_44;
    wire [25:0] signal_cat_60;
    wire signal_lt_10;
    wire signal_not_45;
    wire [24:0] signal_select_32;
    wire signal_select_33;
    wire [1:0] signal_cat_61;
    wire [25:0] signal_cat_62;
    wire signal_select_34;
    wire signal_not_46;
    wire [25:0] signal_cat_63;
    wire [24:0] signal_select_35;
    wire signal_select_36;
    wire signal_not_47;
    wire [25:0] signal_cat_64;
    wire signal_lt_11;
    wire signal_not_48;
    wire [24:0] signal_select_37;
    wire signal_select_38;
    wire signal_not_49;
    wire [25:0] signal_cat_65;
    wire [25:0] signal_const_69;
    wire signal_lt_12;
    wire signal_not_50;
    wire [25:0] signal_const_70;
    wire [24:0] signal_select_39;
    wire signal_select_40;
    wire signal_not_51;
    wire [25:0] signal_cat_66;
    wire signal_lt_13;
    wire signal_not_52;
    wire signal_and_15;
    wire signal_and_16;
    wire signal_and_17;
    wire signal_and_18;
    wire signal_select_41;
    wire [1:0] signal_cat_67;
    wire [25:0] signal_cat_68;
    wire signal_eq_15;
    wire signal_select_42;
    wire [1:0] signal_cat_69;
    wire [25:0] signal_cat_70;
    wire signal_eq_16;
    wire signal_and_19;
    wire signal_or_26;
    wire signal_eq_17;
    wire signal_not_53;
    wire signal_eq_18;
    wire signal_not_54;
    wire signal_eq_19;
    wire signal_eq_20;
    wire signal_eq_21;
    wire signal_and_20;
    wire signal_and_21;
    wire signal_not_55;
    wire signal_mux_91;
    wire signal_mux_92;
    wire signal_mux_93;
    wire signal_mux_94;
    wire signal_and_22;
    wire signal_and_23;
    wire signal_not_56;
    wire signal_or_27;
    wire signal_and_24;
    wire signal_and_25;
    wire signal_and_26;
    wire signal_and_27;
    wire signal_and_28;
    wire signal_and_29;
    wire signal_and_30;
    wire target_fails_now;
    wire signal_mux_95;
    reg signal_cases_8;
    wire signal_wire_8;
    reg target_fails;
    wire [3:0] signal_mux_96;
    wire signal_not_57;
    wire signal_and_31;
    wire signal_mux_97;
    wire signal_not_58;
    wire signal_or_28;
    wire signal_not_59;
    wire signal_or_29;
    wire signal_and_32;
    wire signal_or_30;
    wire signal_mux_98;
    wire signal_not_60;
    wire signal_or_31;
    wire signal_not_61;
    wire signal_or_32;
    wire [25:0] signal_cat_71;
    wire signal_lt_14;
    wire signal_not_62;
    wire [25:0] signal_cat_72;
    wire [25:0] signal_const_75;
    wire [25:0] signal_const_76;
    wire [24:0] signal_select_43;
    wire [25:0] signal_sub_8;
    wire signal_select_44;
    wire signal_not_63;
    wire [25:0] signal_cat_73;
    wire signal_lt_15;
    wire [25:0] signal_mux_99;
    wire [25:0] signal_cat_74;
    wire [25:0] signal_add_10;
    wire [25:0] signal_add_11;
    wire [25:0] signal_cat_75;
    wire [25:0] signal_add_12;
    wire [25:0] signal_mux_100;
    wire [25:0] signal_mux_101;
    wire signal_lt_16;
    wire signal_not_64;
    wire [25:0] signal_const_80;
    wire [24:0] signal_select_45;
    wire [25:0] signal_sub_9;
    wire signal_select_46;
    wire signal_not_65;
    wire [25:0] signal_cat_76;
    wire signal_lt_17;
    wire [25:0] signal_mux_102;
    wire [25:0] signal_cat_77;
    wire [25:0] signal_add_13;
    wire [25:0] signal_add_14;
    wire [25:0] signal_cat_78;
    wire [25:0] signal_cat_79;
    wire [25:0] signal_add_15;
    wire [25:0] signal_mux_103;
    wire [25:0] signal_mux_104;
    wire signal_lt_18;
    wire signal_eq_22;
    wire signal_eq_23;
    wire [1:0] signal_const_87;
    wire signal_eq_24;
    wire signal_eq_25;
    wire signal_or_33;
    wire [2:0] signal_const_89;
    wire signal_eq_26;
    wire signal_and_33;
    wire signal_and_34;
    wire signal_and_35;
    wire signal_and_36;
    wire signal_and_37;
    wire signal_not_66;
    wire signal_not_67;
    wire signal_eq_27;
    wire signal_and_38;
    wire signal_and_39;
    wire signal_not_68;
    wire signal_and_40;
    wire signal_and_41;
    wire [3:0] signal_const_91;
    wire signal_eq_28;
    wire [2:0] signal_const_92;
    wire signal_eq_29;
    wire signal_and_42;
    wire signal_or_34;
    wire signal_and_43;
    wire signal_and_44;
    wire signal_eq_30;
    wire signal_eq_31;
    wire signal_and_45;
    wire signal_or_35;
    wire signal_not_69;
    wire signal_or_36;
    wire signal_eq_32;
    wire signal_eq_33;
    wire signal_and_46;
    wire [15:0] signal_mux_105;
    wire [15:0] signal_mux_106;
    wire [15:0] signal_mux_107;
    wire signal_lt_19;
    wire signal_not_70;
    wire [15:0] signal_mux_108;
    wire [15:0] signal_mux_109;
    wire [2:0] signal_const_96;
    wire signal_eq_34;
    wire [2:0] signal_const_97;
    wire signal_eq_35;
    wire signal_and_47;
    wire [15:0] signal_mux_110;
    wire signal_lt_20;
    wire signal_not_71;
    wire signal_and_48;
    wire signal_eq_36;
    wire [2:0] signal_const_99;
    wire signal_eq_37;
    wire signal_and_49;
    wire signal_eq_38;
    wire [2:0] signal_const_101;
    wire signal_eq_39;
    wire signal_and_50;
    wire signal_eq_40;
    wire [2:0] signal_const_103;
    wire signal_eq_41;
    wire signal_and_51;
    wire signal_or_37;
    wire signal_or_38;
    wire signal_mux_111;
    wire signal_not_72;
    wire signal_or_39;
    wire signal_eq_42;
    wire signal_eq_43;
    wire signal_and_52;
    wire signal_lt_21;
    wire [15:0] signal_mux_112;
    wire [15:0] signal_mux_113;
    wire [15:0] signal_mux_114;
    wire [15:0] signal_mux_115;
    wire signal_lt_22;
    wire signal_not_73;
    wire signal_lt_23;
    wire [15:0] signal_mux_116;
    wire [15:0] signal_mux_117;
    wire [15:0] signal_mux_118;
    wire [15:0] signal_mux_119;
    wire signal_lt_24;
    wire signal_not_74;
    wire signal_and_53;
    wire signal_mux_120;
    wire signal_not_75;
    wire signal_or_40;
    wire signal_eq_44;
    wire signal_eq_45;
    wire signal_and_54;
    wire [15:0] signal_mux_121;
    wire [15:0] signal_mux_122;
    wire signal_lt_25;
    wire signal_not_76;
    wire [15:0] signal_mux_123;
    wire signal_eq_46;
    wire signal_eq_47;
    wire signal_and_55;
    wire [15:0] signal_mux_124;
    wire signal_lt_26;
    wire signal_not_77;
    wire signal_and_56;
    wire signal_not_78;
    wire [1:0] signal_const_108;
    wire signal_eq_48;
    wire signal_eq_49;
    wire signal_and_57;
    wire signal_eq_50;
    wire signal_eq_51;
    wire signal_and_58;
    wire signal_eq_52;
    wire signal_eq_53;
    wire signal_and_59;
    wire signal_or_41;
    wire signal_or_42;
    wire signal_and_60;
    wire signal_mux_125;
    wire signal_not_79;
    wire signal_or_43;
    wire [29:0] signal_select_47;
    wire signal_select_48;
    wire [1:0] signal_cat_80;
    wire [3:0] signal_cat_81;
    wire [4:0] signal_cat_82;
    wire [30:0] signal_cat_83;
    wire [30:0] signal_sub_10;
    wire [25:0] signal_add_16;
    wire signal_select_49;
    wire [1:0] signal_cat_84;
    wire [3:0] signal_cat_85;
    wire [4:0] signal_cat_86;
    wire [30:0] signal_cat_87;
    wire [30:0] signal_mux_126;
    wire signal_select_50;
    wire signal_not_80;
    wire [30:0] signal_cat_88;
    wire [29:0] signal_select_51;
    wire [2:0] signal_cat_89;
    wire signal_select_52;
    wire [1:0] signal_cat_90;
    wire [3:0] signal_cat_91;
    wire [6:0] signal_cat_92;
    wire [30:0] signal_cat_93;
    wire signal_select_53;
    wire signal_not_81;
    wire [30:0] signal_cat_94;
    wire signal_lt_27;
    wire signal_not_82;
    wire [29:0] signal_select_54;
    wire [2:0] signal_cat_95;
    wire signal_select_55;
    wire [1:0] signal_cat_96;
    wire [3:0] signal_cat_97;
    wire [6:0] signal_cat_98;
    wire [30:0] signal_cat_99;
    wire signal_select_56;
    wire signal_not_83;
    wire [30:0] signal_cat_100;
    wire [29:0] signal_select_57;
    wire [4:0] signal_select_58;
    wire [10:0] signal_const_114;
    wire [15:0] signal_cat_101;
    wire [4:0] signal_select_59;
    wire [5:0] signal_cat_102;
    wire [29:0] signal_muls_1;
    wire signal_select_60;
    wire [30:0] signal_cat_103;
    wire signal_select_61;
    wire [1:0] signal_cat_104;
    wire [3:0] signal_cat_105;
    wire [4:0] signal_cat_106;
    wire [30:0] signal_cat_107;
    wire [30:0] signal_sub_11;
    wire [25:0] signal_add_17;
    wire signal_select_62;
    wire [1:0] signal_cat_108;
    wire [3:0] signal_cat_109;
    wire [4:0] signal_cat_110;
    wire [30:0] signal_cat_111;
    wire [30:0] signal_mux_127;
    wire signal_select_63;
    wire signal_not_84;
    wire [30:0] signal_cat_112;
    wire signal_lt_28;
    wire signal_not_85;
    wire [23:0] signal_mux_128;
    wire [23:0] signal_mux_129;
    wire [23:0] signal_mux_130;
    reg [23:0] signal_cases_9;
    wire [23:0] signal_wire_9;
    reg [23:0] signal_reg;
    wire [23:0] signal_mux_131;
    wire [23:0] signal_mux_132;
    wire [23:0] signal_mux_133;
    wire [23:0] signal_mux_134;
    wire [23:0] signal_mux_135;
    wire [23:0] signal_mux_136;
    wire [23:0] signal_mux_137;
    wire [23:0] signal_mux_138;
    wire [23:0] signal_mux_139;
    reg [23:0] signal_cases_10;
    wire [23:0] signal_wire_10;
    reg [23:0] signal_reg_1;
    wire signal_eq_54;
    wire signal_eq_55;
    wire signal_eq_56;
    wire signal_and_61;
    wire signal_eq_57;
    wire signal_eq_58;
    wire signal_and_62;
    wire signal_eq_59;
    wire signal_eq_60;
    wire signal_and_63;
    wire signal_or_44;
    wire signal_or_45;
    wire signal_or_46;
    wire signal_not_86;
    wire signal_not_87;
    wire signal_not_88;
    wire signal_and_64;
    wire signal_and_65;
    wire signal_and_66;
    wire signal_and_67;
    wire signal_eq_61;
    wire signal_eq_62;
    wire signal_and_68;
    wire signal_mux_140;
    wire signal_and_69;
    wire signal_and_70;
    wire signal_select_64;
    wire [1:0] signal_cat_113;
    wire [25:0] signal_cat_114;
    wire signal_eq_63;
    wire signal_select_65;
    wire [1:0] signal_cat_115;
    wire [25:0] signal_cat_116;
    wire signal_eq_64;
    wire signal_and_71;
    wire signal_or_47;
    wire signal_not_89;
    wire signal_or_48;
    wire [24:0] signal_select_66;
    wire signal_select_67;
    wire signal_not_90;
    wire [25:0] signal_cat_117;
    wire [24:0] signal_select_68;
    wire signal_select_69;
    wire [1:0] signal_cat_118;
    wire [25:0] signal_cat_119;
    wire signal_select_70;
    wire signal_not_91;
    wire [25:0] signal_cat_120;
    wire signal_lt_29;
    wire signal_not_92;
    wire [24:0] signal_select_71;
    wire signal_select_72;
    wire [1:0] signal_cat_121;
    wire [25:0] signal_cat_122;
    wire signal_select_73;
    wire signal_not_93;
    wire [25:0] signal_cat_123;
    wire [24:0] signal_select_74;
    wire signal_select_75;
    wire signal_not_94;
    wire [25:0] signal_cat_124;
    wire signal_lt_30;
    wire signal_not_95;
    wire [24:0] signal_select_76;
    wire [25:0] signal_const_129;
    wire [25:0] signal_cat_125;
    wire [25:0] signal_sub_12;
    wire [24:0] signal_select_77;
    wire signal_select_78;
    wire signal_not_96;
    wire [25:0] signal_cat_126;
    wire signal_lt_31;
    wire [25:0] signal_mux_141;
    wire [24:0] signal_select_79;
    wire signal_select_80;
    wire [1:0] signal_cat_127;
    wire [25:0] signal_cat_128;
    wire signal_select_81;
    wire signal_not_97;
    wire [25:0] signal_cat_129;
    wire [24:0] signal_select_82;
    wire signal_select_83;
    wire signal_not_98;
    wire [25:0] signal_cat_130;
    wire signal_lt_32;
    wire [25:0] signal_mux_142;
    wire [25:0] signal_mux_143;
    wire [25:0] signal_mux_144;
    wire [25:0] signal_mux_145;
    wire [25:0] signal_add_18;
    wire [25:0] signal_cat_131;
    wire [25:0] signal_cat_132;
    wire [25:0] signal_cat_133;
    wire [25:0] signal_mux_146;
    wire [25:0] signal_mux_147;
    wire signal_or_49;
    wire [25:0] signal_mux_148;
    wire [25:0] signal_sub_13;
    wire [25:0] signal_cat_134;
    wire [25:0] signal_sub_14;
    wire [24:0] signal_select_84;
    wire signal_select_85;
    wire signal_not_99;
    wire [25:0] signal_cat_135;
    wire signal_lt_33;
    wire [25:0] signal_mux_149;
    wire signal_select_86;
    wire [1:0] signal_cat_136;
    wire [25:0] signal_cat_137;
    wire [25:0] signal_mux_150;
    wire [25:0] signal_mux_151;
    wire [25:0] signal_mux_152;
    wire [25:0] signal_add_19;
    wire [25:0] signal_mux_153;
    wire signal_select_87;
    wire signal_not_100;
    wire [25:0] signal_cat_138;
    wire signal_lt_34;
    wire signal_not_101;
    wire [24:0] signal_select_88;
    wire [24:0] signal_select_89;
    wire signal_select_90;
    wire signal_not_102;
    wire [25:0] signal_cat_139;
    wire signal_lt_35;
    wire [25:0] signal_mux_154;
    wire [24:0] signal_select_91;
    wire signal_select_92;
    wire signal_not_103;
    wire [25:0] signal_cat_140;
    wire [24:0] signal_select_93;
    wire signal_select_94;
    wire [1:0] signal_cat_141;
    wire [25:0] signal_cat_142;
    wire signal_select_95;
    wire signal_not_104;
    wire [25:0] signal_cat_143;
    wire signal_lt_36;
    wire [25:0] signal_mux_155;
    wire [25:0] signal_mux_156;
    wire [25:0] signal_mux_157;
    wire [25:0] signal_mux_158;
    wire [25:0] signal_add_20;
    wire signal_and_72;
    wire [24:0] signal_const_147;
    wire [25:0] signal_cat_144;
    wire [25:0] signal_cat_145;
    wire [25:0] signal_add_21;
    wire [25:0] signal_cat_146;
    wire [25:0] signal_cat_147;
    wire [20:0] signal_const_151;
    wire [23:0] signal_cat_148;
    wire [25:0] signal_cat_149;
    wire [25:0] signal_sub_15;
    wire [25:0] signal_mux_159;
    wire [25:0] signal_mux_160;
    wire signal_eq_65;
    wire signal_and_73;
    wire signal_and_74;
    wire signal_and_75;
    wire [25:0] signal_mux_161;
    wire [2:0] signal_const_156;
    wire signal_eq_66;
    wire signal_and_76;
    wire signal_and_77;
    wire signal_and_78;
    wire [25:0] signal_mux_162;
    wire signal_eq_67;
    wire signal_and_79;
    wire signal_and_80;
    wire signal_and_81;
    wire signal_select_96;
    wire signal_and_82;
    wire signal_or_50;
    wire [25:0] signal_mux_163;
    wire [23:0] signal_const_158;
    wire [23:0] signal_const_159;
    wire [4:0] signal_and_83;
    wire [4:0] signal_and_84;
    wire [4:0] signal_and_85;
    wire [4:0] signal_select_97;
    reg [4:0] signal_mux_164;
    wire [18:0] signal_const_163;
    wire [23:0] signal_cat_150;
    wire [23:0] signal_add_22;
    wire [23:0] signal_mux_165;
    wire [25:0] signal_cat_151;
    wire [25:0] signal_sub_16;
    wire [24:0] signal_select_98;
    wire signal_select_99;
    wire signal_not_105;
    wire [25:0] signal_cat_152;
    wire signal_lt_37;
    wire [25:0] signal_mux_166;
    wire signal_select_100;
    wire [1:0] signal_cat_153;
    wire [25:0] signal_cat_154;
    wire [25:0] signal_mux_167;
    wire [25:0] signal_mux_168;
    wire [25:0] signal_mux_169;
    wire [25:0] signal_add_23;
    wire [25:0] signal_mux_170;
    wire signal_select_101;
    wire signal_not_106;
    wire [25:0] signal_cat_155;
    wire signal_lt_38;
    wire signal_not_107;
    wire signal_and_86;
    wire signal_eq_68;
    wire signal_eq_69;
    wire signal_and_87;
    wire signal_not_108;
    wire signal_eq_70;
    wire signal_eq_71;
    wire signal_and_88;
    wire signal_and_89;
    wire signal_and_90;
    wire signal_and_91;
    wire signal_not_109;
    wire signal_eq_72;
    wire signal_and_92;
    wire signal_and_93;
    wire signal_eq_73;
    wire signal_and_94;
    wire signal_and_95;
    wire signal_and_96;
    wire signal_eq_74;
    wire signal_and_97;
    wire signal_and_98;
    wire signal_and_99;
    wire signal_eq_75;
    wire signal_and_100;
    wire signal_and_101;
    wire signal_and_102;
    wire signal_not_110;
    wire signal_eq_76;
    wire signal_and_103;
    wire signal_and_104;
    wire signal_or_51;
    wire signal_or_52;
    wire signal_or_53;
    wire signal_or_54;
    wire signal_not_111;
    wire [1:0] signal_select_102;
    wire signal_eq_77;
    wire signal_eq_78;
    wire signal_and_105;
    wire signal_and_106;
    wire [2:0] signal_select_103;
    wire signal_eq_79;
    wire signal_eq_80;
    wire signal_and_107;
    wire [2:0] signal_select_104;
    wire signal_eq_81;
    wire signal_eq_82;
    wire signal_and_108;
    wire signal_and_109;
    wire signal_not_112;
    wire [2:0] signal_select_105;
    wire signal_eq_83;
    wire signal_eq_84;
    wire signal_and_110;
    wire signal_and_111;
    wire signal_not_113;
    wire signal_eq_85;
    wire signal_and_112;
    wire signal_or_55;
    wire signal_or_56;
    wire signal_or_57;
    wire signal_not_114;
    wire signal_or_58;
    wire signal_and_113;
    wire signal_and_114;
    wire signal_and_115;
    wire [25:0] signal_const_187;
    wire signal_select_106;
    wire [1:0] signal_cat_156;
    wire [25:0] signal_cat_157;
    wire signal_eq_86;
    wire [25:0] signal_const_188;
    wire signal_select_107;
    wire [1:0] signal_cat_158;
    wire [25:0] signal_cat_159;
    wire signal_eq_87;
    wire signal_and_116;
    wire signal_or_59;
    wire signal_eq_88;
    wire signal_eq_89;
    wire signal_lt_39;
    wire signal_not_115;
    wire signal_lt_40;
    wire signal_not_116;
    wire signal_and_117;
    wire [3:0] signal_const_191;
    wire signal_eq_90;
    wire signal_and_118;
    wire signal_mux_171;
    wire [3:0] signal_const_192;
    wire signal_eq_91;
    wire signal_and_119;
    wire signal_mux_172;
    wire [3:0] signal_const_193;
    wire signal_eq_92;
    wire signal_and_120;
    wire signal_mux_173;
    wire [3:0] signal_select_108;
    wire signal_eq_93;
    wire signal_and_121;
    wire signal_mux_174;
    wire signal_eq_94;
    wire signal_not_117;
    wire signal_or_60;
    wire signal_and_122;
    wire signal_not_118;
    wire signal_or_61;
    wire [22:0] signal_select_109;
    wire signal_select_110;
    wire signal_not_119;
    wire [23:0] signal_cat_160;
    wire [23:0] signal_const_196;
    wire signal_lt_41;
    wire signal_not_120;
    wire signal_eq_95;
    wire signal_eq_96;
    wire signal_and_123;
    wire signal_not_121;
    wire [3:0] signal_select_111;
    wire signal_eq_97;
    wire signal_eq_98;
    wire signal_and_124;
    wire [3:0] signal_const_201;
    wire [3:0] signal_select_112;
    wire signal_lt_42;
    wire [3:0] signal_select_113;
    wire signal_eq_99;
    wire signal_and_125;
    wire [2:0] signal_select_114;
    wire signal_lt_43;
    wire signal_select_115;
    wire signal_not_122;
    wire signal_or_62;
    wire [1:0] signal_select_116;
    wire signal_lt_44;
    wire signal_and_126;
    wire [2:0] signal_select_117;
    wire signal_lt_45;
    wire [1:0] signal_select_118;
    wire signal_lt_46;
    wire signal_lt_47;
    wire signal_not_123;
    wire [4:0] signal_select_119;
    wire signal_lt_48;
    wire signal_not_124;
    wire signal_and_127;
    wire signal_eq_100;
    wire signal_eq_101;
    wire [4:0] signal_const_211;
    wire signal_lt_49;
    wire [4:0] signal_select_120;
    wire signal_lt_50;
    wire [1:0] signal_select_121;
    reg signal_mux_175;
    wire [3:0] signal_const_213;
    wire [3:0] signal_select_122;
    wire signal_lt_51;
    wire [2:0] signal_select_123;
    reg signal_mux_176;
    wire signal_not_125;
    wire signal_or_63;
    wire signal_not_126;
    wire signal_lt_52;
    wire signal_lt_53;
    wire signal_lt_54;
    wire signal_lt_55;
    wire [22:0] signal_select_124;
    wire signal_select_125;
    wire signal_not_127;
    wire [23:0] signal_cat_161;
    wire [22:0] signal_select_126;
    wire [23:0] signal_select_127;
    wire [23:0] signal_const_216;
    wire [23:0] signal_mux_177;
    wire signal_eq_102;
    wire signal_eq_103;
    wire signal_lt_56;
    wire signal_not_128;
    wire signal_lt_57;
    wire signal_not_129;
    wire signal_and_128;
    wire signal_mux_178;
    wire signal_mux_179;
    wire signal_mux_180;
    wire signal_eq_104;
    wire signal_and_129;
    wire signal_mux_181;
    wire signal_not_130;
    wire signal_or_64;
    wire signal_eq_105;
    wire signal_eq_106;
    wire signal_and_130;
    wire [3:0] signal_select_128;
    wire signal_lt_58;
    wire [3:0] signal_select_129;
    wire signal_eq_107;
    wire signal_and_131;
    wire signal_lt_59;
    wire signal_not_131;
    wire signal_or_65;
    wire signal_lt_60;
    wire signal_and_132;
    wire signal_lt_61;
    wire signal_lt_62;
    wire signal_lt_63;
    wire signal_not_132;
    wire [4:0] signal_select_130;
    wire signal_lt_64;
    wire signal_not_133;
    wire signal_and_133;
    wire signal_eq_108;
    wire signal_eq_109;
    wire signal_lt_65;
    wire signal_lt_66;
    reg signal_mux_182;
    wire [3:0] signal_select_131;
    wire signal_lt_67;
    reg signal_mux_183;
    wire signal_not_134;
    wire signal_or_66;
    wire signal_not_135;
    wire signal_lt_68;
    wire signal_lt_69;
    wire signal_lt_70;
    wire signal_lt_71;
    wire [22:0] signal_select_132;
    wire [23:0] signal_select_133;
    wire [24:0] signal_select_134;
    wire [25:0] signal_cat_162;
    wire [25:0] signal_sub_17;
    wire [24:0] signal_select_135;
    wire signal_select_136;
    wire signal_not_136;
    wire [25:0] signal_cat_163;
    wire signal_lt_72;
    wire [25:0] signal_mux_184;
    wire [24:0] signal_select_137;
    wire [23:0] signal_mux_185;
    wire [23:0] signal_mux_186;
    wire [23:0] signal_mux_187;
    wire [23:0] signal_mux_188;
    wire [23:0] signal_mux_189;
    wire [23:0] signal_mux_190;
    wire [23:0] signal_mux_191;
    wire [23:0] signal_mux_192;
    wire [23:0] signal_mux_193;
    reg [23:0] signal_cases_11;
    wire [23:0] signal_wire_11;
    reg [23:0] signal_reg_2;
    wire [23:0] signal_mux_194;
    wire [23:0] signal_mux_195;
    wire [23:0] signal_mux_196;
    reg [23:0] signal_cases_12;
    wire [23:0] signal_wire_12;
    reg [23:0] signal_reg_3;
    wire signal_select_138;
    wire [1:0] signal_cat_164;
    wire [25:0] signal_cat_165;
    wire signal_select_139;
    wire signal_not_137;
    wire [25:0] signal_cat_166;
    wire [24:0] signal_select_140;
    wire signal_select_141;
    wire signal_not_138;
    wire [25:0] signal_cat_167;
    wire signal_lt_73;
    wire [25:0] signal_mux_197;
    wire [25:0] signal_mux_198;
    wire [25:0] signal_mux_199;
    wire [25:0] signal_mux_200;
    wire [25:0] signal_add_24;
    wire [15:0] signal_mux_201;
    wire [15:0] signal_mux_202;
    wire [15:0] signal_mux_203;
    wire [15:0] signal_mux_204;
    wire [15:0] signal_mux_205;
    wire [15:0] signal_mux_206;
    wire [15:0] signal_mux_207;
    reg [15:0] signal_cases_13;
    wire [15:0] signal_mux_208;
    wire [15:0] signal_mux_209;
    wire [15:0] signal_mux_210;
    wire [15:0] signal_mux_211;
    wire [15:0] signal_mux_212;
    wire [15:0] signal_mux_213;
    wire [15:0] signal_mux_214;
    wire [15:0] signal_mux_215;
    wire [15:0] signal_mux_216;
    reg [15:0] signal_cases_14;
    wire [15:0] signal_wire_13;
    reg [15:0] signal_reg_4;
    wire [15:0] signal_mux_217;
    wire [15:0] signal_mux_218;
    wire [15:0] signal_mux_219;
    reg [15:0] signal_cases_15;
    wire [15:0] signal_wire_14;
    reg [15:0] signal_reg_5;
    wire [25:0] signal_cat_168;
    wire [25:0] signal_cat_169;
    wire [15:0] signal_mux_220;
    wire [15:0] signal_mux_221;
    wire [15:0] signal_mux_222;
    wire [15:0] signal_mux_223;
    wire [15:0] signal_mux_224;
    wire [15:0] signal_mux_225;
    wire [15:0] signal_mux_226;
    wire [15:0] signal_mux_227;
    reg [15:0] signal_cases_16;
    wire [15:0] signal_mux_228;
    wire [15:0] signal_mux_229;
    wire [15:0] signal_mux_230;
    wire [15:0] signal_mux_231;
    wire [15:0] signal_mux_232;
    wire [15:0] signal_mux_233;
    wire [15:0] signal_mux_234;
    wire [15:0] signal_mux_235;
    wire [15:0] signal_mux_236;
    reg [15:0] signal_cases_17;
    wire [15:0] signal_wire_15;
    reg [15:0] signal_reg_6;
    wire [15:0] signal_mux_237;
    wire [15:0] signal_mux_238;
    wire [15:0] signal_mux_239;
    reg [15:0] signal_cases_18;
    wire [15:0] signal_wire_16;
    reg [15:0] signal_reg_7;
    wire signal_lt_74;
    wire [15:0] signal_mux_240;
    wire [15:0] signal_mux_241;
    wire [15:0] signal_mux_242;
    wire [15:0] signal_mux_243;
    wire [15:0] signal_mux_244;
    wire [15:0] signal_mux_245;
    wire [15:0] signal_mux_246;
    wire [15:0] signal_mux_247;
    wire [15:0] signal_mux_248;
    wire [15:0] signal_select_142;
    reg [15:0] signal_cases_19;
    wire [15:0] signal_mux_249;
    wire [15:0] signal_mux_250;
    wire [15:0] signal_mux_251;
    wire [15:0] signal_mux_252;
    wire [15:0] signal_mux_253;
    wire [15:0] signal_mux_254;
    wire [15:0] signal_mux_255;
    wire [15:0] signal_mux_256;
    wire [15:0] signal_mux_257;
    reg [15:0] signal_cases_20;
    wire [15:0] signal_wire_17;
    reg [15:0] signal_reg_8;
    wire [15:0] signal_mux_258;
    wire [15:0] signal_mux_259;
    wire [15:0] signal_mux_260;
    reg [15:0] signal_cases_21;
    wire [15:0] signal_wire_18;
    reg [15:0] signal_reg_9;
    wire [25:0] signal_cat_170;
    wire [25:0] signal_mux_261;
    wire [25:0] signal_mux_262;
    wire signal_or_67;
    wire [25:0] signal_mux_263;
    wire [25:0] signal_sub_18;
    wire [25:0] signal_cat_171;
    wire [25:0] signal_sub_19;
    wire [24:0] signal_select_143;
    wire signal_select_144;
    wire signal_not_139;
    wire [25:0] signal_cat_172;
    wire signal_lt_75;
    wire [25:0] signal_mux_264;
    wire [25:0] signal_mux_265;
    wire [25:0] signal_mux_266;
    wire [25:0] signal_mux_267;
    wire [25:0] signal_add_25;
    wire [25:0] signal_mux_268;
    wire signal_select_145;
    wire signal_not_140;
    wire [25:0] signal_cat_173;
    wire signal_lt_76;
    wire signal_not_141;
    wire [24:0] signal_select_146;
    wire [24:0] signal_select_147;
    wire signal_select_148;
    wire signal_not_142;
    wire [25:0] signal_cat_174;
    wire signal_lt_77;
    wire [25:0] signal_mux_269;
    wire [24:0] signal_select_149;
    wire signal_select_150;
    wire signal_not_143;
    wire [25:0] signal_cat_175;
    wire [24:0] signal_select_151;
    wire [23:0] signal_mux_270;
    wire [23:0] signal_mux_271;
    wire [23:0] signal_mux_272;
    wire [23:0] signal_mux_273;
    wire [23:0] signal_mux_274;
    wire [23:0] signal_mux_275;
    wire [23:0] signal_mux_276;
    wire [23:0] signal_mux_277;
    wire [23:0] signal_mux_278;
    reg [23:0] signal_cases_22;
    wire [23:0] signal_wire_19;
    reg [23:0] signal_reg_10;
    wire [23:0] signal_mux_279;
    wire [23:0] signal_mux_280;
    wire [23:0] signal_mux_281;
    reg [23:0] signal_cases_23;
    wire [23:0] signal_wire_20;
    reg [23:0] signal_reg_11;
    wire signal_select_152;
    wire [1:0] signal_cat_176;
    wire [25:0] signal_cat_177;
    wire signal_select_153;
    wire signal_not_144;
    wire [25:0] signal_cat_178;
    wire signal_lt_78;
    wire [25:0] signal_mux_282;
    wire [25:0] signal_mux_283;
    wire [25:0] signal_mux_284;
    wire [25:0] signal_mux_285;
    wire [25:0] signal_add_26;
    wire [15:0] signal_wire_21;
    wire signal_eq_110;
    wire signal_not_145;
    wire signal_and_134;
    wire [25:0] signal_cat_179;
    wire [15:0] signal_wire_22;
    wire [15:0] signal_mux_286;
    wire signal_eq_111;
    wire signal_eq_112;
    wire signal_and_135;
    wire [15:0] signal_mux_287;
    wire signal_wire_23;
    wire signal_not_146;
    wire signal_eq_113;
    wire signal_eq_114;
    wire signal_and_136;
    wire signal_eq_115;
    wire signal_eq_116;
    wire signal_and_137;
    wire signal_eq_117;
    wire signal_eq_118;
    wire signal_and_138;
    wire signal_or_68;
    wire signal_or_69;
    wire signal_and_139;
    wire signal_not_147;
    wire [15:0] signal_mux_288;
    wire [15:0] signal_mux_289;
    wire [15:0] signal_mux_290;
    wire [15:0] signal_mux_291;
    wire [15:0] signal_mux_292;
    reg [15:0] signal_cases_24;
    wire [15:0] signal_mux_293;
    wire [15:0] signal_mux_294;
    wire [15:0] signal_mux_295;
    wire [15:0] signal_mux_296;
    wire [15:0] signal_mux_297;
    wire [15:0] signal_mux_298;
    wire [15:0] signal_mux_299;
    wire [15:0] signal_mux_300;
    wire [15:0] signal_mux_301;
    reg [15:0] signal_cases_25;
    wire [15:0] signal_wire_24;
    reg [15:0] signal_reg_12;
    wire [15:0] signal_mux_302;
    wire [15:0] signal_mux_303;
    wire [15:0] signal_const_296;
    wire [15:0] signal_mux_304;
    reg [15:0] signal_cases_26;
    wire [15:0] signal_wire_25;
    reg [15:0] signal_reg_13;
    wire [25:0] signal_cat_180;
    wire [25:0] signal_add_27;
    wire [25:0] signal_cat_181;
    wire [4:0] signal_select_154;
    wire [15:0] signal_cat_182;
    wire [15:0] signal_mux_305;
    wire [15:0] signal_mux_306;
    wire signal_eq_119;
    wire signal_eq_120;
    wire signal_and_140;
    wire [15:0] signal_mux_307;
    wire signal_eq_121;
    wire signal_eq_122;
    wire signal_and_141;
    wire signal_eq_123;
    wire signal_eq_124;
    wire signal_and_142;
    wire signal_eq_125;
    wire signal_eq_126;
    wire signal_and_143;
    wire signal_or_70;
    wire signal_or_71;
    wire signal_not_148;
    wire [15:0] signal_mux_308;
    wire [15:0] signal_mux_309;
    wire [15:0] signal_mux_310;
    wire [15:0] signal_mux_311;
    wire [15:0] signal_mux_312;
    reg [15:0] signal_cases_27;
    wire [15:0] signal_mux_313;
    wire [15:0] signal_mux_314;
    wire [15:0] signal_mux_315;
    wire [15:0] signal_mux_316;
    wire [15:0] signal_mux_317;
    wire [15:0] signal_mux_318;
    wire [15:0] signal_mux_319;
    wire [15:0] signal_mux_320;
    wire [15:0] signal_mux_321;
    reg [15:0] signal_cases_28;
    wire [15:0] signal_wire_26;
    reg [15:0] signal_reg_14;
    wire [15:0] signal_mux_322;
    wire [15:0] signal_mux_323;
    wire [15:0] signal_mux_324;
    reg [15:0] signal_cases_29;
    wire [15:0] signal_wire_27;
    reg [15:0] signal_reg_15;
    wire signal_lt_79;
    wire [15:0] signal_mux_325;
    wire signal_eq_127;
    wire signal_and_144;
    wire [15:0] signal_mux_326;
    wire signal_eq_128;
    wire signal_and_145;
    wire [15:0] signal_mux_327;
    wire [2:0] signal_select_155;
    wire signal_eq_129;
    wire signal_eq_130;
    wire signal_and_146;
    wire [15:0] signal_mux_328;
    wire signal_eq_131;
    wire signal_eq_132;
    wire signal_and_147;
    wire signal_eq_133;
    wire signal_eq_134;
    wire signal_and_148;
    wire signal_eq_135;
    wire signal_eq_136;
    wire signal_and_149;
    wire signal_or_72;
    wire signal_or_73;
    wire signal_not_149;
    wire [15:0] signal_mux_329;
    wire [15:0] signal_mux_330;
    wire [15:0] signal_mux_331;
    wire [15:0] signal_mux_332;
    wire [15:0] signal_mux_333;
    wire [15:0] signal_select_156;
    reg [15:0] signal_cases_30;
    wire [15:0] signal_mux_334;
    wire [15:0] signal_mux_335;
    wire [15:0] signal_mux_336;
    wire [15:0] signal_mux_337;
    wire [15:0] signal_mux_338;
    wire [15:0] signal_mux_339;
    wire [15:0] signal_mux_340;
    wire [15:0] signal_mux_341;
    wire [15:0] signal_mux_342;
    reg [15:0] signal_cases_31;
    wire [15:0] signal_wire_28;
    reg [15:0] signal_reg_16;
    wire [15:0] signal_mux_343;
    wire [15:0] signal_mux_344;
    wire [15:0] signal_mux_345;
    reg [15:0] signal_cases_32;
    wire [15:0] signal_wire_29;
    reg [15:0] signal_reg_17;
    wire [25:0] signal_cat_183;
    wire [23:0] signal_cat_184;
    wire [25:0] signal_cat_185;
    wire [25:0] signal_sub_20;
    wire [25:0] signal_mux_346;
    wire [25:0] signal_mux_347;
    wire signal_eq_137;
    wire signal_and_150;
    wire signal_and_151;
    wire signal_and_152;
    wire [25:0] signal_mux_348;
    wire signal_eq_138;
    wire signal_and_153;
    wire signal_and_154;
    wire signal_and_155;
    wire [25:0] signal_mux_349;
    wire signal_eq_139;
    wire signal_and_156;
    wire signal_and_157;
    wire signal_and_158;
    wire signal_and_159;
    wire signal_or_74;
    wire [25:0] signal_mux_350;
    wire [25:0] signal_cat_186;
    wire [25:0] signal_sub_21;
    wire [24:0] signal_select_157;
    wire signal_select_158;
    wire signal_not_150;
    wire [25:0] signal_cat_187;
    wire signal_lt_80;
    wire [25:0] signal_mux_351;
    wire [25:0] signal_mux_352;
    wire [25:0] signal_mux_353;
    wire [25:0] signal_mux_354;
    wire [25:0] signal_add_28;
    wire [3:0] signal_select_159;
    wire signal_eq_140;
    wire signal_and_160;
    wire [25:0] signal_mux_355;
    wire signal_select_160;
    wire signal_not_151;
    wire [25:0] signal_cat_188;
    wire signal_lt_81;
    wire signal_not_152;
    wire signal_eq_141;
    wire [24:0] signal_select_161;
    wire signal_select_162;
    wire [1:0] signal_cat_189;
    wire [25:0] signal_cat_190;
    wire [25:0] signal_sub_22;
    wire signal_select_163;
    wire signal_not_153;
    wire [25:0] signal_cat_191;
    wire signal_lt_82;
    wire [25:0] signal_mux_356;
    wire [25:0] signal_cat_192;
    wire [25:0] signal_add_29;
    wire [25:0] signal_add_30;
    wire [25:0] signal_cat_193;
    wire [25:0] signal_add_31;
    wire [25:0] signal_mux_357;
    wire [25:0] signal_mux_358;
    wire [23:0] signal_select_164;
    wire [24:0] signal_select_165;
    wire signal_select_166;
    wire [1:0] signal_cat_194;
    wire [25:0] signal_cat_195;
    wire [25:0] signal_sub_23;
    wire signal_select_167;
    wire signal_not_154;
    wire [25:0] signal_cat_196;
    wire signal_lt_83;
    wire [25:0] signal_mux_359;
    wire [25:0] signal_cat_197;
    wire [25:0] signal_add_32;
    wire [25:0] signal_add_33;
    wire [4:0] signal_and_161;
    wire [4:0] signal_and_162;
    wire [4:0] signal_and_163;
    wire [4:0] signal_select_168;
    wire [1:0] signal_wire_30;
    reg [4:0] signal_mux_360;
    wire [23:0] signal_cat_198;
    wire [23:0] signal_add_34;
    wire signal_eq_142;
    wire [23:0] signal_mux_361;
    wire [25:0] signal_cat_199;
    wire [23:0] signal_select_169;
    wire [23:0] signal_mux_362;
    wire [23:0] signal_mux_363;
    wire [23:0] signal_mux_364;
    wire [23:0] signal_mux_365;
    wire [23:0] signal_mux_366;
    reg [23:0] signal_cases_33;
    wire [23:0] signal_mux_367;
    wire [23:0] signal_mux_368;
    wire [23:0] signal_mux_369;
    wire [23:0] signal_mux_370;
    wire [23:0] signal_mux_371;
    wire [23:0] signal_mux_372;
    wire [23:0] signal_mux_373;
    wire [23:0] signal_mux_374;
    wire [23:0] signal_mux_375;
    reg [23:0] signal_cases_34;
    wire [23:0] signal_wire_31;
    reg [23:0] signal_reg_18;
    wire [23:0] signal_mux_376;
    wire [23:0] signal_mux_377;
    wire [23:0] signal_mux_378;
    reg [23:0] signal_cases_35;
    wire [23:0] signal_wire_32;
    reg [23:0] signal_reg_19;
    wire [25:0] signal_cat_200;
    wire [25:0] signal_add_35;
    wire [25:0] signal_mux_379;
    wire [25:0] signal_mux_380;
    wire signal_lt_84;
    wire signal_not_155;
    wire signal_not_156;
    wire signal_eq_143;
    wire signal_and_164;
    wire signal_and_165;
    wire signal_not_157;
    wire signal_and_166;
    wire signal_and_167;
    wire signal_or_75;
    wire [23:0] signal_mux_381;
    wire [23:0] signal_mux_382;
    wire [23:0] signal_mux_383;
    wire [23:0] signal_mux_384;
    wire [23:0] signal_mux_385;
    reg [23:0] signal_cases_36;
    wire [23:0] signal_mux_386;
    wire [23:0] signal_mux_387;
    wire [23:0] signal_mux_388;
    wire [23:0] signal_mux_389;
    wire [23:0] signal_mux_390;
    wire [23:0] signal_mux_391;
    wire [23:0] signal_mux_392;
    wire [23:0] signal_mux_393;
    wire [23:0] signal_mux_394;
    reg [23:0] signal_cases_37;
    wire [23:0] signal_wire_33;
    reg [23:0] signal_reg_20;
    wire [23:0] signal_mux_395;
    wire [23:0] signal_mux_396;
    wire [23:0] signal_mux_397;
    reg [23:0] signal_cases_38;
    wire [23:0] signal_wire_34;
    reg [23:0] signal_reg_21;
    wire signal_eq_144;
    wire signal_and_168;
    wire signal_not_158;
    wire signal_not_159;
    wire signal_and_169;
    wire signal_mux_398;
    wire signal_mux_399;
    wire signal_mux_400;
    wire signal_mux_401;
    wire signal_mux_402;
    wire signal_select_170;
    wire signal_mux_403;
    wire signal_mux_404;
    wire signal_mux_405;
    wire signal_mux_406;
    wire signal_mux_407;
    reg signal_cases_39;
    wire signal_wire_35;
    reg signal_reg_22;
    wire signal_mux_408;
    wire signal_mux_409;
    wire signal_mux_410;
    reg signal_cases_40;
    wire signal_wire_36;
    reg signal_reg_23;
    wire signal_wire_37;
    wire signal_select_171;
    wire signal_eq_145;
    wire [4:0] signal_wire_38;
    wire [4:0] signal_select_172;
    wire signal_eq_146;
    wire signal_wire_39;
    wire signal_eq_147;
    wire signal_eq_148;
    wire signal_or_76;
    wire signal_eq_149;
    wire signal_and_170;
    wire signal_and_171;
    wire signal_and_172;
    wire signal_and_173;
    wire signal_and_174;
    wire signal_and_175;
    wire signal_or_77;
    wire [3:0] signal_select_173;
    wire signal_eq_150;
    wire signal_eq_151;
    wire signal_and_176;
    wire signal_mux_411;
    wire signal_mux_412;
    wire signal_mux_413;
    wire signal_mux_414;
    wire signal_mux_415;
    wire signal_select_174;
    wire signal_mux_416;
    wire signal_mux_417;
    wire signal_mux_418;
    wire signal_mux_419;
    wire signal_mux_420;
    reg signal_cases_41;
    wire signal_wire_40;
    reg signal_reg_24;
    wire signal_mux_421;
    wire signal_mux_422;
    wire signal_mux_423;
    reg signal_cases_42;
    wire signal_wire_41;
    reg signal_reg_25;
    wire signal_eq_152;
    wire signal_eq_153;
    wire signal_and_177;
    wire signal_and_178;
    wire signal_and_179;
    wire signal_and_180;
    wire signal_not_160;
    wire signal_eq_154;
    wire signal_and_181;
    wire signal_and_182;
    wire signal_eq_155;
    wire signal_and_183;
    wire signal_and_184;
    wire signal_and_185;
    wire signal_eq_156;
    wire signal_and_186;
    wire signal_and_187;
    wire signal_and_188;
    wire [2:0] signal_select_175;
    wire signal_eq_157;
    wire signal_and_189;
    wire signal_and_190;
    wire signal_and_191;
    wire signal_select_176;
    wire signal_not_161;
    wire [1:0] signal_select_177;
    wire signal_eq_158;
    wire signal_and_192;
    wire signal_and_193;
    wire signal_or_78;
    wire signal_or_79;
    wire signal_or_80;
    wire signal_or_81;
    wire signal_not_162;
    wire [1:0] signal_select_178;
    wire signal_eq_159;
    wire signal_eq_160;
    wire signal_and_194;
    wire signal_and_195;
    wire [2:0] signal_select_179;
    wire signal_eq_161;
    wire signal_eq_162;
    wire signal_and_196;
    wire [2:0] signal_select_180;
    wire signal_eq_163;
    wire [1:0] signal_select_181;
    wire signal_eq_164;
    wire signal_and_197;
    wire signal_and_198;
    wire signal_not_163;
    wire [2:0] signal_select_182;
    wire signal_eq_165;
    wire signal_eq_166;
    wire signal_and_199;
    wire signal_and_200;
    wire [1:0] signal_select_183;
    wire signal_eq_167;
    wire signal_eq_168;
    wire signal_and_201;
    wire signal_not_164;
    wire [2:0] signal_select_184;
    wire signal_eq_169;
    wire signal_and_202;
    wire signal_or_82;
    wire signal_or_83;
    wire signal_or_84;
    wire signal_not_165;
    wire signal_or_85;
    wire signal_and_203;
    wire signal_and_204;
    wire [23:0] signal_mux_424;
    wire [23:0] signal_mux_425;
    wire [23:0] signal_mux_426;
    wire [23:0] signal_mux_427;
    wire [23:0] signal_mux_428;
    wire [23:0] signal_select_185;
    reg [23:0] signal_cases_43;
    wire [23:0] signal_mux_429;
    wire [23:0] signal_mux_430;
    wire [23:0] signal_mux_431;
    wire [23:0] signal_mux_432;
    wire [23:0] signal_mux_433;
    wire [23:0] signal_mux_434;
    wire [23:0] signal_mux_435;
    wire [23:0] signal_mux_436;
    wire [23:0] signal_mux_437;
    reg [23:0] signal_cases_44;
    wire [23:0] signal_wire_42;
    reg [23:0] signal_reg_26;
    wire [23:0] signal_mux_438;
    wire [23:0] signal_mux_439;
    wire [23:0] signal_mux_440;
    reg [23:0] signal_cases_45;
    wire [23:0] signal_wire_43;
    reg [23:0] signal_reg_27;
    wire signal_select_186;
    wire signal_not_166;
    wire [23:0] signal_cat_201;
    wire [22:0] signal_select_187;
    wire signal_select_188;
    wire signal_not_167;
    wire [23:0] signal_cat_202;
    wire signal_lt_85;
    wire signal_or_86;
    wire signal_or_87;
    wire signal_or_88;
    wire signal_or_89;
    wire signal_not_168;
    wire signal_and_205;
    wire signal_and_206;
    wire [23:0] signal_mux_441;
    wire [23:0] signal_mux_442;
    wire [23:0] signal_mux_443;
    wire [23:0] signal_mux_444;
    wire [47:0] signal_const_409;
    wire [47:0] signal_mux_445;
    wire [47:0] signal_mux_446;
    wire [47:0] signal_mux_447;
    reg [47:0] signal_cases_46;
    wire [47:0] signal_wire_44;
    reg [47:0] acc;
    wire [31:0] signal_select_189;
    wire [47:0] shifted;
    wire [23:0] signal_select_190;
    reg [23:0] signal_cases_47;
    wire [23:0] signal_mux_448;
    wire [23:0] signal_mux_449;
    wire [23:0] signal_mux_450;
    wire [23:0] signal_mux_451;
    wire [23:0] signal_mux_452;
    wire [23:0] signal_mux_453;
    wire [23:0] signal_mux_454;
    wire [23:0] signal_mux_455;
    wire [23:0] signal_mux_456;
    reg [23:0] signal_cases_48;
    wire [23:0] signal_wire_45;
    reg [23:0] signal_reg_28;
    wire [23:0] signal_mux_457;
    wire [23:0] signal_mux_458;
    wire [23:0] signal_mux_459;
    reg [23:0] signal_cases_49;
    wire [23:0] signal_wire_46;
    reg [23:0] signal_reg_29;
    wire signal_select_191;
    wire signal_not_169;
    wire [23:0] signal_cat_203;
    wire signal_lt_86;
    wire signal_or_90;
    wire signal_or_91;
    wire signal_or_92;
    wire signal_or_93;
    wire signal_not_170;
    wire signal_and_207;
    wire signal_not_171;
    wire signal_or_94;
    wire signal_or_95;
    wire signal_and_208;
    wire signal_and_209;
    wire signal_and_210;
    wire signal_and_211;
    wire signal_and_212;
    wire signal_and_213;
    wire signal_and_214;
    wire signal_and_215;
    wire next_fails;
    wire [3:0] signal_mux_460;
    wire [3:0] signal_mux_461;
    wire [3:0] signal_mux_462;
    wire [3:0] signal_mux_463;
    reg [3:0] signal_cases_50;
    wire [3:0] signal_mux_464;
    wire [3:0] signal_mux_465;
    wire [3:0] signal_mux_466;
    wire [3:0] signal_const_413;
    wire [1:0] signal_mux_467;
    wire [1:0] signal_mux_468;
    wire [1:0] signal_mux_469;
    wire [1:0] signal_mux_470;
    wire [1:0] signal_mux_471;
    reg [1:0] signal_cases_51;
    wire [1:0] signal_wire_47;
    (* fsm_encoding="one_hot" *)
    reg [1:0] purpose;
    reg [3:0] signal_cases_52;
    wire [3:0] signal_const_446;
    wire [3:0] signal_mux_472;
    wire [3:0] signal_mux_473;
    wire [3:0] signal_mux_474;
    wire [3:0] signal_const_419;
    wire [3:0] signal_const_461;
    wire [3:0] signal_mux_475;
    wire [3:0] signal_mux_476;
    wire signal_lt_87;
    wire signal_not_172;
    wire [3:0] signal_mux_477;
    wire [3:0] signal_mux_478;
    wire [3:0] signal_const_460;
    wire [3:0] signal_mux_479;
    wire [3:0] signal_mux_480;
    wire [3:0] signal_mux_481;
    wire [1:0] signal_add_36;
    wire signal_not_173;
    wire signal_mux_482;
    wire signal_mux_483;
    wire signal_mux_484;
    wire [7:0] signal_select_192;
    wire [1:0] signal_mux_485;
    wire [1:0] signal_mux_486;
    wire [1:0] signal_mux_487;
    wire [1:0] signal_mux_488;
    wire [1:0] signal_mux_489;
    wire [1:0] signal_mux_490;
    wire [1:0] signal_mux_491;
    wire [1:0] signal_add_37;
    wire [1:0] signal_mux_492;
    wire [1:0] signal_mux_493;
    wire [1:0] signal_mux_494;
    wire [2:0] signal_add_38;
    wire [2:0] signal_add_39;
    wire signal_eq_170;
    wire signal_eq_171;
    wire wide;
    wire last_word;
    wire [2:0] signal_mux_495;
    wire [2:0] signal_mux_496;
    wire [6:0] signal_select_193;
    wire [6:0] signal_select_194;
    wire [6:0] signal_select_195;
    wire [6:0] signal_select_196;
    wire [31:0] signal_select_197;
    wire [47:0] entry_shifted;
    wire [47:0] signal_mux_497;
    reg [47:0] signal_cases_53;
    wire [47:0] signal_wire_48;
    reg [47:0] entry;
    wire [6:0] signal_select_198;
    reg [6:0] index;
    wire signal_eq_172;
    wire [2:0] signal_mux_498;
    wire [2:0] signal_mux_499;
    wire [2:0] signal_mux_500;
    wire [2:0] signal_mux_501;
    reg [2:0] signal_cases_54;
    wire [2:0] signal_wire_49;
    reg [2:0] field;
    wire signal_eq_173;
    wire [1:0] signal_mux_502;
    wire [1:0] signal_add_40;
    wire signal_eq_174;
    wire [1:0] signal_mux_503;
    wire [1:0] signal_mux_504;
    wire [1:0] signal_mux_505;
    wire [1:0] signal_mux_506;
    wire [7:0] signal_mux_507;
    wire [7:0] signal_mux_508;
    wire [7:0] signal_const_450;
    wire signal_eq_175;
    wire [7:0] signal_mux_509;
    wire [7:0] signal_mux_510;
    wire [7:0] signal_mux_511;
    wire [7:0] signal_mux_512;
    wire [7:0] signal_mux_513;
    wire [7:0] signal_mux_514;
    wire [7:0] signal_mux_515;
    wire [7:0] signal_mux_516;
    reg [7:0] signal_cases_55;
    wire [7:0] signal_wire_50;
    reg [7:0] hi;
    wire [8:0] signal_cat_204;
    wire [8:0] signal_cat_205;
    wire [8:0] signal_add_41;
    wire [7:0] signal_select_199;
    wire [8:0] signal_cat_206;
    wire [7:0] mid;
    wire [7:0] signal_add_42;
    wire signal_lt_88;
    wire [7:0] signal_mux_517;
    wire [8:0] signal_mux_518;
    wire [8:0] signal_mux_519;
    reg [8:0] signal_cases_56;
    wire [8:0] signal_wire_51;
    reg [8:0] key;
    wire signal_eq_176;
    wire [7:0] signal_mux_520;
    wire [7:0] signal_mux_521;
    wire [7:0] signal_mux_522;
    wire [8:0] jump_target;
    wire signal_eq_177;
    wire [7:0] signal_mux_523;
    wire [15:0] signal_wire_52;
    wire [15:0] signal_mux_524;
    reg [15:0] signal_cases_57;
    wire [15:0] signal_wire_53;
    reg [15:0] word;
    wire [2:0] signal_select_200;
    wire is_jump;
    wire [7:0] signal_mux_525;
    reg [7:0] signal_cases_58;
    wire [7:0] signal_wire_54;
    reg [7:0] lo;
    wire signal_lt_89;
    wire signal_not_174;
    wire [1:0] signal_mux_526;
    wire [1:0] signal_add_43;
    wire signal_eq_178;
    wire [1:0] signal_mux_527;
    wire [1:0] signal_add_44;
    wire signal_eq_179;
    wire [1:0] signal_mux_528;
    wire [1:0] signal_mux_529;
    wire [1:0] signal_mux_530;
    reg [1:0] signal_cases_59;
    wire [1:0] signal_wire_55;
    reg [1:0] k;
    wire signal_eq_180;
    wire [7:0] signal_mux_531;
    wire [7:0] signal_mux_532;
    reg [7:0] signal_cases_60;
    wire [7:0] signal_wire_56;
    reg [7:0] count;
    wire [7:0] signal_cat_207;
    wire [7:0] signal_add_45;
    wire [7:0] signal_mux_533;
    wire [8:0] signal_wire_57;
    wire [8:0] signal_const_471;
    wire [8:0] signal_add_46;
    wire [8:0] signal_wire_58;
    wire [8:0] signal_mux_534;
    wire [8:0] signal_mux_535;
    wire [8:0] signal_select_201;
    wire [8:0] signal_const_474;
    wire signal_eq_181;
    wire [8:0] signal_mux_536;
    wire signal_wire_59;
    wire signal_wire_60;
    wire [9:0] signal_const_476;
    wire [9:0] signal_cat_208;
    wire [9:0] next_pc;
    wire [15:0] signal_wire_61;
    wire [8:0] entry_tag;
    wire [9:0] signal_cat_209;
    wire signal_eq_182;
    wire signal_mux_537;
    wire signal_mux_538;
    reg signal_cases_61;
    wire signal_wire_62;
    reg stored;
    wire [8:0] signal_mux_539;
    wire [8:0] signal_mux_540;
    wire [8:0] signal_mux_541;
    reg [8:0] signal_cases_62;
    wire [8:0] signal_wire_63;
    reg [8:0] pc;
    wire signal_eq_183;
    wire [8:0] following;
    wire gnd;
    wire [9:0] signal_cat_210;
    wire falls_to_next;
    wire [7:0] signal_mux_542;
    wire [7:0] signal_mux_543;
    reg [7:0] signal_cases_63;
    wire [7:0] signal_wire_64;
    reg [7:0] ptr;
    wire signal_lt_90;
    wire signal_mux_544;
    wire vdd;
    reg signal_cases_64;
    wire reading;
    wire signal_and_216;
    wire [1:0] signal_mux_545;
    wire [1:0] signal_wire_65;
    reg [1:0] \wait ;
    wire read_done;
    wire [3:0] signal_mux_546;
    wire signal_wire_66;
    wire [3:0] signal_mux_547;
    reg [3:0] signal_cases_65;
    wire signal_eq_184;
    wire signal_not_175;
    wire signal_wire_67;
    wire signal_and_217;
    wire [3:0] signal_mux_548;
    wire [3:0] signal_wire_68;
    (* fsm_encoding="one_hot" *)
    reg [3:0] sm;
    wire signal_eq_185;
    assign signal_const = 5'b00000;
    assign signal_const_1 = 5'b11101;
    assign signal_const_2 = 5'b11111;
    assign signal_mux = signal_eq_1 ? reason_0 : signal_const_2;
    assign signal_const_4 = 5'b00001;
    assign signal_mux_1 = signal_not_8 ? signal_const : signal_const_4;
    assign signal_const_5 = 5'b00011;
    assign signal_mux_2 = signal_not_8 ? signal_mux_1 : signal_const_5;
    assign signal_const_6 = 5'b00100;
    assign signal_const_7 = 5'b00101;
    assign signal_mux_3 = signal_not_6 ? signal_const_6 : signal_const_7;
    assign signal_const_8 = 5'b00110;
    assign signal_const_9 = 5'b00111;
    assign signal_mux_4 = signal_not_4 ? signal_const_8 : signal_const_9;
    assign signal_mux_5 = signal_or_3 ? signal_mux_3 : signal_mux_4;
    assign signal_mux_6 = signal_or_5 ? signal_mux_2 : signal_mux_5;
    assign signal_const_10 = 5'b01000;
    assign signal_const_11 = 5'b01001;
    assign signal_mux_7 = signal_not_2 ? signal_const_10 : signal_const_11;
    assign signal_const_12 = 5'b01010;
    assign signal_const_13 = 5'b01011;
    assign signal_mux_8 = signal_not ? signal_const_12 : signal_const_13;
    assign signal_mux_9 = signal_or ? signal_mux_7 : signal_mux_8;
    assign signal_const_14 = 5'b01100;
    assign signal_mux_10 = signal_or_1 ? signal_mux_9 : signal_const_14;
    assign signal_mux_11 = signal_or_6 ? signal_mux_6 : signal_mux_10;
    assign signal_not = ~ signal_or_29;
    assign signal_not_1 = ~ signal_or_32;
    assign signal_not_2 = ~ signal_or_36;
    assign signal_or = signal_not_2 | signal_not_1;
    assign signal_or_1 = signal_or | signal_not;
    assign signal_not_3 = ~ signal_or_39;
    assign signal_not_4 = ~ signal_or_40;
    assign signal_or_2 = signal_not_4 | signal_not_3;
    assign signal_not_5 = ~ signal_or_43;
    assign signal_not_6 = ~ signal_or_48;
    assign signal_or_3 = signal_not_6 | signal_not_5;
    assign signal_or_4 = signal_or_3 | signal_or_2;
    assign signal_not_7 = ~ signal_or_61;
    assign signal_not_8 = ~ signal_or_95;
    assign signal_or_5 = signal_not_8 | signal_not_7;
    assign signal_or_6 = signal_or_5 | signal_or_4;
    assign signal_or_7 = signal_or_6 | signal_or_1;
    assign next_reason = signal_or_7 ? signal_mux_11 : signal_const;
    assign signal_const_17 = 5'b01101;
    assign signal_const_18 = 5'b01110;
    assign signal_mux_12 = signal_not_16 ? signal_const_17 : signal_const_18;
    assign signal_const_19 = 5'b01111;
    assign signal_const_20 = 5'b10000;
    assign signal_mux_13 = signal_not_14 ? signal_const_19 : signal_const_20;
    assign signal_mux_14 = signal_or_12 ? signal_mux_12 : signal_mux_13;
    assign signal_const_21 = 5'b10001;
    assign signal_const_22 = 5'b10010;
    assign signal_mux_15 = signal_not_12 ? signal_const_21 : signal_const_22;
    assign signal_const_23 = 5'b10011;
    assign signal_const_24 = 5'b10100;
    assign signal_mux_16 = signal_not_10 ? signal_const_23 : signal_const_24;
    assign signal_mux_17 = signal_or_9 ? signal_mux_15 : signal_mux_16;
    assign signal_mux_18 = signal_or_13 ? signal_mux_14 : signal_mux_17;
    assign signal_const_25 = 5'b10110;
    assign signal_mux_19 = signal_or_14 ? signal_mux_18 : signal_const_25;
    assign signal_not_9 = ~ signal_or_16;
    assign signal_not_10 = ~ signal_or_18;
    assign signal_or_8 = signal_not_10 | signal_not_9;
    assign signal_not_11 = ~ signal_or_20;
    assign signal_not_12 = ~ signal_or_21;
    assign signal_or_9 = signal_not_12 | signal_not_11;
    assign signal_or_10 = signal_or_9 | signal_or_8;
    assign signal_not_13 = ~ signal_or_22;
    assign signal_not_14 = ~ signal_or_23;
    assign signal_or_11 = signal_not_14 | signal_not_13;
    assign signal_not_15 = ~ signal_or_25;
    assign signal_not_16 = ~ signal_or_27;
    assign signal_or_12 = signal_not_16 | signal_not_15;
    assign signal_or_13 = signal_or_12 | signal_or_11;
    assign signal_or_14 = signal_or_13 | signal_or_10;
    assign target_reason_now = signal_or_14 ? signal_mux_19 : signal_const;
    always @* begin
        case (sm)
        4'b1000:
            signal_cases <= target_reason_now;
        default:
            signal_cases <= target_reason;
        endcase
    end
    assign signal_wire = signal_cases;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            target_reason <= signal_const;
        else
            target_reason <= signal_wire;
    end
    assign signal_mux_20 = target_fails ? target_reason : reason_0;
    assign signal_mux_21 = next_fails ? next_reason : signal_mux_20;
    assign signal_const_27 = 5'b11110;
    assign signal_mux_22 = signal_not_172 ? signal_const_27 : reason_0;
    assign signal_mux_23 = read_done ? signal_mux_22 : reason_0;
    assign signal_mux_24 = signal_lt_90 ? signal_mux_23 : reason_0;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_1 <= signal_mux_24;
        4'b1010:
            signal_cases_1 <= signal_mux_21;
        4'b1101:
            signal_cases_1 <= signal_mux;
        default:
            signal_cases_1 <= reason_0;
        endcase
    end
    assign signal_mux_25 = signal_and_217 ? signal_const_1 : signal_cases_1;
    assign signal_wire_1 = signal_mux_25;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            reason_0 <= signal_const;
        else
            reason_0 <= signal_wire_1;
    end
    assign signal_const_28 = 10'b0000000000;
    assign signal_cat = { gnd,
                          pc };
    assign signal_const_29 = 10'b1000000000;
    assign signal_mux_26 = signal_eq_1 ? reject_pc_0 : signal_const_29;
    assign signal_cat_1 = { gnd,
                            pc };
    assign signal_cat_2 = { gnd,
                            pc };
    assign signal_mux_27 = target_fails ? signal_cat_2 : reject_pc_0;
    assign signal_mux_28 = next_fails ? signal_cat_1 : signal_mux_27;
    assign signal_cat_3 = { gnd,
                            pc };
    assign signal_mux_29 = signal_not_172 ? signal_cat_3 : reject_pc_0;
    assign signal_mux_30 = read_done ? signal_mux_29 : reject_pc_0;
    assign signal_mux_31 = signal_lt_90 ? signal_mux_30 : reject_pc_0;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_2 <= signal_mux_31;
        4'b1010:
            signal_cases_2 <= signal_mux_28;
        4'b1101:
            signal_cases_2 <= signal_mux_26;
        default:
            signal_cases_2 <= reject_pc_0;
        endcase
    end
    assign signal_mux_32 = signal_and_217 ? signal_cat : signal_cases_2;
    assign signal_wire_2 = signal_mux_32;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            reject_pc_0 <= signal_const_28;
        else
            reject_pc_0 <= signal_wire_2;
    end
    assign signal_const_30 = 1'b0;
    assign signal_mux_33 = signal_eq_1 ? vdd : gnd;
    assign signal_mux_34 = target_fails ? gnd : accepted_0;
    assign signal_mux_35 = next_fails ? gnd : signal_mux_34;
    assign signal_mux_36 = signal_not_172 ? gnd : accepted_0;
    assign signal_mux_37 = read_done ? signal_mux_36 : accepted_0;
    assign signal_mux_38 = signal_lt_90 ? signal_mux_37 : accepted_0;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_3 <= signal_mux_38;
        4'b1010:
            signal_cases_3 <= signal_mux_35;
        4'b1101:
            signal_cases_3 <= signal_mux_33;
        default:
            signal_cases_3 <= accepted_0;
        endcase
    end
    assign signal_mux_39 = signal_and_217 ? gnd : signal_cases_3;
    assign signal_wire_3 = signal_mux_39;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            accepted_0 <= signal_const_30;
        else
            accepted_0 <= signal_wire_3;
    end
    assign signal_mux_40 = signal_eq_1 ? vdd : vdd;
    assign signal_mux_41 = target_fails ? vdd : gnd;
    assign signal_mux_42 = next_fails ? vdd : signal_mux_41;
    assign signal_mux_43 = signal_not_172 ? vdd : gnd;
    assign signal_mux_44 = read_done ? signal_mux_43 : gnd;
    assign signal_mux_45 = signal_lt_90 ? signal_mux_44 : gnd;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_4 <= signal_mux_45;
        4'b1010:
            signal_cases_4 <= signal_mux_42;
        4'b1101:
            signal_cases_4 <= signal_mux_40;
        default:
            signal_cases_4 <= gnd;
        endcase
    end
    assign signal_mux_46 = signal_and_217 ? vdd : signal_cases_4;
    assign signal_wire_4 = signal_mux_46;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            finished_0 <= signal_const_30;
        else
            finished_0 <= signal_wire_4;
    end
    assign signal_eq = signal_const_51 == sm;
    assign signal_not_17 = ~ signal_eq;
    assign signal_const_32 = 7'b0000000;
    assign signal_cat_4 = { signal_const_32,
                            k };
    assign signal_const_33 = 2'b11;
    assign signal_const_34 = 7'b0000001;
    assign signal_sub = index - signal_const_34;
    assign signal_const_35 = 2'b00;
    assign signal_cat_5 = { signal_const_35,
                            signal_sub };
    assign signal_mulu = signal_cat_5 * signal_const_33;
    assign signal_select = signal_mulu[8:0];
    assign signal_add = wide_at + signal_select;
    assign signal_sub_1 = index - signal_const_34;
    assign signal_cat_6 = { signal_const_35,
                            signal_sub_1 };
    assign signal_select_1 = signal_cat_6[7:0];
    assign signal_cat_7 = { signal_select_1,
                            signal_const_30 };
    assign signal_const_40 = 8'b00000000;
    assign signal_select_2 = signal_wire_61[7:0];
    assign signal_mux_47 = signal_eq_180 ? wide_count : signal_select_2;
    assign signal_mux_48 = read_done ? signal_mux_47 : wide_count;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_5 <= signal_mux_48;
        default:
            signal_cases_5 <= wide_count;
        endcase
    end
    assign signal_wire_5 = signal_cases_5;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            wide_count <= signal_const_40;
        else
            wide_count <= signal_wire_5;
    end
    assign signal_cat_8 = { gnd,
                            wide_count };
    assign signal_mulu_1 = signal_cat_8 * signal_const_33;
    assign signal_select_3 = signal_mulu_1[8:0];
    assign signal_cat_9 = { gnd,
                            count };
    assign signal_mulu_2 = signal_cat_9 * signal_const_33;
    assign signal_select_4 = signal_mulu_2[8:0];
    assign wide_at = entries_at + signal_select_4;
    assign narrow_at = wide_at + signal_select_3;
    assign signal_add_1 = narrow_at + signal_cat_7;
    assign signal_mux_49 = wide ? signal_add : signal_add_1;
    assign interval_at = signal_mux_49 + signal_cat_4;
    assign signal_mux_50 = signal_eq_172 ? signal_const_49 : interval_at;
    assign signal_mux_51 = signal_eq_173 ? signal_const_49 : signal_mux_50;
    assign signal_cat_10 = { signal_const_32,
                             k };
    assign signal_mux_52 = stored ? ptr : sel;
    assign signal_mux_53 = falls_to_next ? sel : signal_mux_52;
    assign signal_mux_54 = stored ? ptr : sel;
    assign signal_mux_55 = falls_to_next ? signal_mux_54 : sel;
    assign signal_mux_56 = signal_eq_176 ? mid : sel;
    assign signal_mux_57 = read_done ? signal_mux_56 : sel;
    assign signal_mux_58 = signal_not_174 ? sel : signal_mux_57;
    always @* begin
        case (sm)
        4'b0101:
            signal_cases_6 <= signal_mux_58;
        4'b1001:
            signal_cases_6 <= signal_mux_55;
        4'b1011:
            signal_cases_6 <= signal_mux_53;
        default:
            signal_cases_6 <= sel;
        endcase
    end
    assign signal_wire_6 = signal_cases_6;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            sel <= signal_const_40;
        else
            sel <= signal_wire_6;
    end
    assign signal_cat_11 = { gnd,
                             sel };
    assign signal_mulu_3 = signal_cat_11 * signal_const_33;
    assign signal_select_5 = signal_mulu_3[8:0];
    assign signal_add_2 = entries_at + signal_select_5;
    assign signal_add_3 = signal_add_2 + signal_cat_10;
    assign signal_cat_12 = { gnd,
                             mid };
    assign signal_mulu_4 = signal_cat_12 * signal_const_33;
    assign signal_select_6 = signal_mulu_4[8:0];
    assign signal_add_4 = entries_at + signal_select_6;
    assign signal_mux_59 = signal_not_174 ? signal_const_49 : signal_add_4;
    assign signal_cat_13 = { signal_const_32,
                             k };
    assign signal_cat_14 = { gnd,
                             ptr };
    assign signal_mulu_5 = signal_cat_14 * signal_const_33;
    assign signal_select_7 = signal_mulu_5[8:0];
    assign signal_const_48 = 9'b000000010;
    assign entries_at = signal_wire_7 + signal_const_48;
    assign signal_add_5 = entries_at + signal_select_7;
    assign signal_add_6 = signal_add_5 + signal_cat_13;
    assign signal_const_49 = 9'b000000000;
    assign signal_mux_60 = signal_lt_90 ? signal_add_6 : signal_const_49;
    assign signal_cat_15 = { signal_const_32,
                             k };
    assign signal_wire_7 = setup$base;
    assign signal_add_7 = signal_wire_7 + signal_cat_15;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_7 <= signal_add_7;
        4'b0011:
            signal_cases_7 <= signal_mux_60;
        4'b0101:
            signal_cases_7 <= signal_mux_59;
        4'b0110:
            signal_cases_7 <= signal_add_3;
        4'b0111:
            signal_cases_7 <= signal_mux_51;
        default:
            signal_cases_7 <= signal_const_49;
        endcase
    end
    assign data_addr = signal_cases_7;
    assign signal_const_51 = 4'b0000;
    assign signal_eq_1 = ptr == count;
    assign signal_mux_61 = signal_eq_1 ? signal_const_51 : signal_const_51;
    assign signal_mux_62 = signal_eq_181 ? signal_const_52 : signal_const_192;
    assign signal_mux_63 = signal_eq_181 ? signal_const_52 : signal_const_192;
    assign signal_const_52 = 4'b1101;
    assign signal_mux_64 = signal_eq_181 ? signal_const_52 : signal_const_192;
    assign signal_mux_65 = stored ? signal_const_446 : signal_mux_64;
    assign signal_mux_66 = falls_to_next ? signal_mux_63 : signal_mux_65;
    assign signal_const_478 = 4'b1011;
    assign signal_mux_67 = stored ? target_fails : gnd;
    assign signal_mux_68 = falls_to_next ? gnd : signal_mux_67;
    assign signal_not_18 = ~ signal_reg_22;
    assign signal_or_15 = signal_not_18 | signal_mux_97;
    assign signal_not_19 = ~ signal_and_23;
    assign signal_or_16 = signal_not_19 | signal_or_15;
    assign signal_not_20 = ~ signal_reg_24;
    assign signal_or_17 = signal_not_20 | signal_mux_98;
    assign signal_not_21 = ~ signal_and_23;
    assign signal_or_18 = signal_not_21 | signal_or_17;
    assign signal_cat_16 = { signal_const_35,
                             signal_reg_18 };
    assign signal_lt = signal_cat_16 < signal_mux_104;
    assign signal_not_22 = ~ signal_lt;
    assign signal_cat_17 = { signal_const_35,
                             signal_reg_20 };
    assign signal_lt_1 = signal_mux_101 < signal_cat_17;
    assign signal_not_23 = ~ signal_lt_1;
    assign signal_and = signal_or_34 & signal_not_23;
    assign signal_and_1 = signal_and & signal_not_22;
    assign signal_const_56 = 24'b111111111111111111111111;
    assign signal_eq_2 = signal_reg_18 == signal_const_56;
    assign signal_const_57 = 24'b000000000000000000000000;
    assign signal_eq_3 = signal_reg_20 == signal_const_57;
    assign signal_and_2 = signal_eq_3 & signal_eq_2;
    assign signal_or_19 = signal_and_2 | signal_and_1;
    assign signal_not_24 = ~ signal_and_23;
    assign signal_or_20 = signal_not_24 | signal_or_19;
    assign signal_eq_4 = signal_reg_16 == signal_const_296;
    assign signal_const_58 = 16'b0000000000000000;
    assign signal_eq_5 = signal_reg_8 == signal_const_58;
    assign signal_and_3 = signal_eq_5 & signal_eq_4;
    assign signal_const_59 = 16'b0000000000000001;
    assign signal_sub_2 = signal_reg_17 - signal_const_59;
    assign signal_mux_69 = signal_and_119 ? signal_sub_2 : signal_reg_17;
    assign signal_mux_70 = signal_and_47 ? signal_cat_101 : signal_mux_69;
    assign signal_lt_2 = signal_reg_16 < signal_mux_70;
    assign signal_not_25 = ~ signal_lt_2;
    assign signal_sub_3 = signal_reg_9 - signal_const_59;
    assign signal_eq_6 = signal_reg_9 == signal_const_58;
    assign signal_mux_71 = signal_eq_6 ? signal_const_58 : signal_sub_3;
    assign signal_mux_72 = signal_and_119 ? signal_mux_71 : signal_reg_9;
    assign signal_mux_73 = signal_and_47 ? signal_cat_101 : signal_mux_72;
    assign signal_lt_3 = signal_mux_73 < signal_reg_8;
    assign signal_not_26 = ~ signal_lt_3;
    assign signal_and_4 = signal_not_26 & signal_not_25;
    assign signal_mux_74 = signal_or_38 ? signal_and_3 : signal_and_4;
    assign signal_not_27 = ~ signal_and_23;
    assign signal_or_21 = signal_not_27 | signal_mux_74;
    assign signal_eq_7 = signal_reg_14 == signal_const_296;
    assign signal_eq_8 = signal_reg_6 == signal_const_58;
    assign signal_and_5 = signal_eq_8 & signal_eq_7;
    assign signal_sub_4 = signal_reg_15 - signal_const_59;
    assign signal_mux_75 = signal_and_120 ? signal_sub_4 : signal_reg_15;
    assign signal_mux_76 = signal_and_68 ? signal_cat_101 : signal_mux_75;
    assign signal_lt_4 = signal_reg_14 < signal_mux_76;
    assign signal_not_28 = ~ signal_lt_4;
    assign signal_sub_5 = signal_reg_7 - signal_const_59;
    assign signal_eq_9 = signal_reg_7 == signal_const_58;
    assign signal_mux_77 = signal_eq_9 ? signal_const_58 : signal_sub_5;
    assign signal_mux_78 = signal_and_120 ? signal_mux_77 : signal_reg_7;
    assign signal_mux_79 = signal_and_68 ? signal_cat_101 : signal_mux_78;
    assign signal_lt_5 = signal_mux_79 < signal_reg_6;
    assign signal_not_29 = ~ signal_lt_5;
    assign signal_and_6 = signal_not_29 & signal_not_28;
    assign signal_mux_80 = signal_or_45 ? signal_and_5 : signal_and_6;
    assign signal_not_30 = ~ signal_and_23;
    assign signal_or_22 = signal_not_30 | signal_mux_80;
    assign signal_eq_10 = signal_reg_12 == signal_const_296;
    assign signal_eq_11 = signal_reg_4 == signal_const_58;
    assign signal_and_7 = signal_eq_11 & signal_eq_10;
    assign signal_mux_81 = signal_or_42 ? signal_wire_22 : signal_reg_13;
    assign signal_mux_82 = signal_and_55 ? signal_cat_101 : signal_mux_81;
    assign signal_lt_6 = signal_reg_12 < signal_mux_82;
    assign signal_not_31 = ~ signal_lt_6;
    assign signal_mux_83 = signal_or_42 ? signal_wire_22 : signal_reg_5;
    assign signal_mux_84 = signal_and_55 ? signal_cat_101 : signal_mux_83;
    assign signal_lt_7 = signal_mux_84 < signal_reg_4;
    assign signal_not_32 = ~ signal_lt_7;
    assign signal_and_8 = signal_not_32 & signal_not_31;
    assign signal_not_33 = ~ signal_wire_23;
    assign signal_and_9 = signal_or_42 & signal_not_33;
    assign signal_mux_85 = signal_and_9 ? signal_and_7 : signal_and_8;
    assign signal_not_34 = ~ signal_and_23;
    assign signal_or_23 = signal_not_34 | signal_mux_85;
    assign signal_select_8 = signal_mux_87[29:0];
    assign signal_select_9 = signal_add_19[25:25];
    assign signal_cat_18 = { signal_select_9,
                             signal_select_9 };
    assign signal_cat_19 = { signal_cat_18,
                             signal_cat_18 };
    assign signal_cat_20 = { signal_cat_19,
                             signal_select_9 };
    assign signal_cat_21 = { signal_cat_20,
                             signal_add_19 };
    assign signal_sub_6 = signal_cat_21 - signal_cat_41;
    assign signal_select_10 = signal_reg[23:23];
    assign signal_cat_22 = { signal_select_10,
                             signal_select_10 };
    assign signal_cat_23 = { signal_cat_22,
                             signal_reg };
    assign signal_add_8 = signal_add_16 + signal_cat_23;
    assign signal_mux_86 = signal_and_120 ? signal_add_8 : signal_add_16;
    assign signal_select_11 = signal_mux_86[25:25];
    assign signal_cat_24 = { signal_select_11,
                             signal_select_11 };
    assign signal_cat_25 = { signal_cat_24,
                             signal_cat_24 };
    assign signal_cat_26 = { signal_cat_25,
                             signal_select_11 };
    assign signal_cat_27 = { signal_cat_26,
                             signal_mux_86 };
    assign signal_mux_87 = signal_and_68 ? signal_sub_6 : signal_cat_27;
    assign signal_select_12 = signal_mux_87[30:30];
    assign signal_not_35 = ~ signal_select_12;
    assign signal_cat_28 = { signal_not_35,
                             signal_select_8 };
    assign signal_select_13 = signal_cat_33[29:0];
    assign signal_cat_29 = { signal_cat_30,
                             signal_select_14 };
    assign signal_select_14 = signal_reg_2[23:23];
    assign signal_cat_30 = { signal_select_14,
                             signal_select_14 };
    assign signal_cat_31 = { signal_cat_30,
                             signal_cat_30 };
    assign signal_cat_32 = { signal_cat_31,
                             signal_cat_29 };
    assign signal_cat_33 = { signal_cat_32,
                             signal_reg_2 };
    assign signal_select_15 = signal_cat_33[30:30];
    assign signal_not_36 = ~ signal_select_15;
    assign signal_cat_34 = { signal_not_36,
                             signal_select_13 };
    assign signal_lt_8 = signal_cat_34 < signal_cat_28;
    assign signal_not_37 = ~ signal_lt_8;
    assign signal_select_16 = signal_cat_39[29:0];
    assign signal_cat_35 = { signal_cat_36,
                             signal_select_17 };
    assign signal_select_17 = signal_reg_10[23:23];
    assign signal_cat_36 = { signal_select_17,
                             signal_select_17 };
    assign signal_cat_37 = { signal_cat_36,
                             signal_cat_36 };
    assign signal_cat_38 = { signal_cat_37,
                             signal_cat_35 };
    assign signal_cat_39 = { signal_cat_38,
                             signal_reg_10 };
    assign signal_select_18 = signal_cat_39[30:30];
    assign signal_not_38 = ~ signal_select_18;
    assign signal_cat_40 = { signal_not_38,
                             signal_select_16 };
    assign signal_select_19 = signal_mux_89[29:0];
    assign signal_muls = $signed(signal_reg_1) * $signed(signal_cat_102);
    assign signal_select_20 = signal_muls[29:29];
    assign signal_cat_41 = { signal_select_20,
                             signal_muls };
    assign signal_select_21 = signal_add_23[25:25];
    assign signal_cat_42 = { signal_select_21,
                             signal_select_21 };
    assign signal_cat_43 = { signal_cat_42,
                             signal_cat_42 };
    assign signal_cat_44 = { signal_cat_43,
                             signal_select_21 };
    assign signal_cat_45 = { signal_cat_44,
                             signal_add_23 };
    assign signal_sub_7 = signal_cat_45 - signal_cat_41;
    assign signal_select_22 = signal_reg[23:23];
    assign signal_cat_46 = { signal_select_22,
                             signal_select_22 };
    assign signal_cat_47 = { signal_cat_46,
                             signal_reg };
    assign signal_add_9 = signal_add_17 + signal_cat_47;
    assign signal_mux_88 = signal_and_120 ? signal_add_9 : signal_add_17;
    assign signal_select_23 = signal_mux_88[25:25];
    assign signal_cat_48 = { signal_select_23,
                             signal_select_23 };
    assign signal_cat_49 = { signal_cat_48,
                             signal_cat_48 };
    assign signal_cat_50 = { signal_cat_49,
                             signal_select_23 };
    assign signal_cat_51 = { signal_cat_50,
                             signal_mux_88 };
    assign signal_mux_89 = signal_and_68 ? signal_sub_7 : signal_cat_51;
    assign signal_select_24 = signal_mux_89[30:30];
    assign signal_not_39 = ~ signal_select_24;
    assign signal_cat_52 = { signal_not_39,
                             signal_select_19 };
    assign signal_lt_9 = signal_cat_52 < signal_cat_40;
    assign signal_not_40 = ~ signal_lt_9;
    assign signal_eq_12 = signal_reg_1 == signal_reg;
    assign signal_not_41 = ~ signal_or_45;
    assign signal_and_10 = signal_and_65 & signal_not_41;
    assign signal_and_11 = signal_and_10 & signal_eq_12;
    assign signal_mux_90 = signal_and_68 ? signal_or_58 : signal_and_11;
    assign signal_and_12 = signal_mux_90 & signal_not_40;
    assign signal_and_13 = signal_and_12 & signal_not_37;
    assign signal_select_25 = signal_reg_2[23:23];
    assign signal_cat_53 = { signal_select_25,
                             signal_select_25 };
    assign signal_cat_54 = { signal_cat_53,
                             signal_reg_2 };
    assign signal_eq_13 = signal_cat_54 == signal_const_187;
    assign signal_select_26 = signal_reg_10[23:23];
    assign signal_cat_55 = { signal_select_26,
                             signal_select_26 };
    assign signal_cat_56 = { signal_cat_55,
                             signal_reg_10 };
    assign signal_eq_14 = signal_cat_56 == signal_const_188;
    assign signal_and_14 = signal_eq_14 & signal_eq_13;
    assign signal_or_24 = signal_and_14 | signal_and_13;
    assign signal_not_42 = ~ signal_and_23;
    assign signal_or_25 = signal_not_42 | signal_or_24;
    assign signal_select_27 = signal_add_19[24:0];
    assign signal_select_28 = signal_add_19[25:25];
    assign signal_not_43 = ~ signal_select_28;
    assign signal_cat_57 = { signal_not_43,
                             signal_select_27 };
    assign signal_select_29 = signal_cat_59[24:0];
    assign signal_select_30 = signal_reg_28[23:23];
    assign signal_cat_58 = { signal_select_30,
                             signal_select_30 };
    assign signal_cat_59 = { signal_cat_58,
                             signal_reg_28 };
    assign signal_select_31 = signal_cat_59[25:25];
    assign signal_not_44 = ~ signal_select_31;
    assign signal_cat_60 = { signal_not_44,
                             signal_select_29 };
    assign signal_lt_10 = signal_cat_60 < signal_cat_57;
    assign signal_not_45 = ~ signal_lt_10;
    assign signal_select_32 = signal_cat_62[24:0];
    assign signal_select_33 = signal_reg_26[23:23];
    assign signal_cat_61 = { signal_select_33,
                             signal_select_33 };
    assign signal_cat_62 = { signal_cat_61,
                             signal_reg_26 };
    assign signal_select_34 = signal_cat_62[25:25];
    assign signal_not_46 = ~ signal_select_34;
    assign signal_cat_63 = { signal_not_46,
                             signal_select_32 };
    assign signal_select_35 = signal_add_23[24:0];
    assign signal_select_36 = signal_add_23[25:25];
    assign signal_not_47 = ~ signal_select_36;
    assign signal_cat_64 = { signal_not_47,
                             signal_select_35 };
    assign signal_lt_11 = signal_cat_64 < signal_cat_63;
    assign signal_not_48 = ~ signal_lt_11;
    assign signal_select_37 = signal_add_19[24:0];
    assign signal_select_38 = signal_add_19[25:25];
    assign signal_not_49 = ~ signal_select_38;
    assign signal_cat_65 = { signal_not_49,
                             signal_select_37 };
    assign signal_const_69 = 26'b10011111111111111111111111;
    assign signal_lt_12 = signal_const_69 < signal_cat_65;
    assign signal_not_50 = ~ signal_lt_12;
    assign signal_const_70 = 26'b01100000000000000000000000;
    assign signal_select_39 = signal_add_23[24:0];
    assign signal_select_40 = signal_add_23[25:25];
    assign signal_not_51 = ~ signal_select_40;
    assign signal_cat_66 = { signal_not_51,
                             signal_select_39 };
    assign signal_lt_13 = signal_cat_66 < signal_const_70;
    assign signal_not_52 = ~ signal_lt_13;
    assign signal_and_15 = signal_not_52 & signal_not_50;
    assign signal_and_16 = signal_or_58 & signal_and_15;
    assign signal_and_17 = signal_and_16 & signal_not_48;
    assign signal_and_18 = signal_and_17 & signal_not_45;
    assign signal_select_41 = signal_reg_28[23:23];
    assign signal_cat_67 = { signal_select_41,
                             signal_select_41 };
    assign signal_cat_68 = { signal_cat_67,
                             signal_reg_28 };
    assign signal_eq_15 = signal_cat_68 == signal_const_187;
    assign signal_select_42 = signal_reg_26[23:23];
    assign signal_cat_69 = { signal_select_42,
                             signal_select_42 };
    assign signal_cat_70 = { signal_cat_69,
                             signal_reg_26 };
    assign signal_eq_16 = signal_cat_70 == signal_const_188;
    assign signal_and_19 = signal_eq_16 & signal_eq_15;
    assign signal_or_26 = signal_and_19 | signal_and_18;
    assign signal_eq_17 = signal_reg_15 == signal_const_58;
    assign signal_not_53 = ~ signal_eq_17;
    assign signal_eq_18 = signal_reg_17 == signal_const_58;
    assign signal_not_54 = ~ signal_eq_18;
    assign signal_eq_19 = signal_reg_7 == signal_reg_9;
    assign signal_eq_20 = signal_reg_9 == signal_reg_17;
    assign signal_eq_21 = signal_reg_7 == signal_reg_15;
    assign signal_and_20 = signal_eq_21 & signal_eq_20;
    assign signal_and_21 = signal_and_20 & signal_eq_19;
    assign signal_not_55 = ~ signal_and_21;
    assign signal_mux_91 = signal_and_118 ? signal_not_55 : vdd;
    assign signal_mux_92 = signal_and_119 ? signal_not_54 : signal_mux_91;
    assign signal_mux_93 = signal_and_120 ? signal_not_53 : signal_mux_92;
    assign signal_mux_94 = signal_and_121 ? vdd : signal_mux_93;
    assign signal_and_22 = signal_and_207 & signal_eq_94;
    assign signal_and_23 = signal_and_22 & signal_mux_94;
    assign signal_not_56 = ~ signal_and_23;
    assign signal_or_27 = signal_not_56 | signal_or_26;
    assign signal_and_24 = signal_or_27 & signal_or_25;
    assign signal_and_25 = signal_and_24 & signal_or_23;
    assign signal_and_26 = signal_and_25 & signal_or_22;
    assign signal_and_27 = signal_and_26 & signal_or_21;
    assign signal_and_28 = signal_and_27 & signal_or_20;
    assign signal_and_29 = signal_and_28 & signal_or_18;
    assign signal_and_30 = signal_and_29 & signal_or_16;
    assign target_fails_now = ~ signal_and_30;
    assign signal_mux_95 = signal_wire_66 ? gnd : target_fails;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_8 <= signal_mux_95;
        4'b1000:
            signal_cases_8 <= target_fails_now;
        4'b1011:
            signal_cases_8 <= signal_mux_68;
        4'b1100:
            signal_cases_8 <= gnd;
        default:
            signal_cases_8 <= target_fails;
        endcase
    end
    assign signal_wire_8 = signal_cases_8;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            target_fails <= signal_const_30;
        else
            target_fails <= signal_wire_8;
    end
    assign signal_mux_96 = target_fails ? signal_const_51 : signal_const_478;
    assign signal_not_57 = ~ signal_and_36;
    assign signal_and_31 = signal_reg_23 & signal_not_57;
    assign signal_mux_97 = signal_and_42 ? vdd : signal_and_31;
    assign signal_not_58 = ~ signal_reg_22;
    assign signal_or_28 = signal_not_58 | signal_mux_97;
    assign signal_not_59 = ~ signal_and_122;
    assign signal_or_29 = signal_not_59 | signal_or_28;
    assign signal_and_32 = signal_and_37 & signal_not_108;
    assign signal_or_30 = signal_reg_25 | signal_and_32;
    assign signal_mux_98 = signal_and_42 ? gnd : signal_or_30;
    assign signal_not_60 = ~ signal_reg_24;
    assign signal_or_31 = signal_not_60 | signal_mux_98;
    assign signal_not_61 = ~ signal_and_122;
    assign signal_or_32 = signal_not_61 | signal_or_31;
    assign signal_cat_71 = { signal_const_35,
                             signal_reg_18 };
    assign signal_lt_14 = signal_cat_71 < signal_mux_104;
    assign signal_not_62 = ~ signal_lt_14;
    assign signal_cat_72 = { signal_const_35,
                             signal_reg_20 };
    assign signal_const_75 = 26'b00000000000000000000000000;
    assign signal_const_76 = 26'b10000000000000000000000000;
    assign signal_select_43 = signal_sub_8[24:0];
    assign signal_sub_8 = signal_const_75 - signal_cat_137;
    assign signal_select_44 = signal_sub_8[25:25];
    assign signal_not_63 = ~ signal_select_44;
    assign signal_cat_73 = { signal_not_63,
                             signal_select_43 };
    assign signal_lt_15 = signal_cat_73 < signal_const_76;
    assign signal_mux_99 = signal_lt_15 ? signal_const_75 : signal_sub_8;
    assign signal_cat_74 = { signal_const_35,
                             signal_reg_21 };
    assign signal_add_10 = signal_cat_74 + signal_mux_99;
    assign signal_add_11 = signal_add_10 + signal_cat_78;
    assign signal_cat_75 = { signal_const_35,
                             signal_reg_21 };
    assign signal_add_12 = signal_cat_75 + signal_cat_78;
    assign signal_mux_100 = signal_and_123 ? signal_add_11 : signal_add_12;
    assign signal_mux_101 = signal_and_42 ? signal_cat_78 : signal_mux_100;
    assign signal_lt_16 = signal_mux_101 < signal_cat_72;
    assign signal_not_64 = ~ signal_lt_16;
    assign signal_const_80 = 26'b00100000000000000000000000;
    assign signal_select_45 = signal_sub_9[24:0];
    assign signal_sub_9 = signal_const_75 - signal_cat_154;
    assign signal_select_46 = signal_sub_9[25:25];
    assign signal_not_65 = ~ signal_select_46;
    assign signal_cat_76 = { signal_not_65,
                             signal_select_45 };
    assign signal_lt_17 = signal_cat_76 < signal_const_76;
    assign signal_mux_102 = signal_lt_17 ? signal_const_75 : signal_sub_9;
    assign signal_cat_77 = { signal_const_35,
                             signal_reg_19 };
    assign signal_add_13 = signal_cat_77 + signal_mux_102;
    assign signal_add_14 = signal_add_13 + signal_cat_78;
    assign signal_cat_78 = { signal_const_35,
                             signal_mux_165 };
    assign signal_cat_79 = { signal_const_35,
                             signal_reg_19 };
    assign signal_add_15 = signal_cat_79 + signal_cat_78;
    assign signal_mux_103 = signal_and_123 ? signal_add_14 : signal_add_15;
    assign signal_mux_104 = signal_and_42 ? signal_cat_78 : signal_mux_103;
    assign signal_lt_18 = signal_mux_104 < signal_const_80;
    assign signal_eq_22 = signal_select_96 == signal_wire_37;
    assign signal_eq_23 = signal_select_120 == signal_wire_38;
    assign signal_const_87 = 2'b01;
    assign signal_eq_24 = signal_select_121 == signal_const_87;
    assign signal_eq_25 = signal_select_121 == signal_const_35;
    assign signal_or_33 = signal_eq_25 | signal_eq_24;
    assign signal_const_89 = 3'b001;
    assign signal_eq_26 = signal_select_123 == signal_const_89;
    assign signal_and_33 = signal_eq_26 & signal_or_33;
    assign signal_and_34 = signal_and_33 & signal_wire_39;
    assign signal_and_35 = signal_and_34 & signal_eq_23;
    assign signal_and_36 = signal_and_35 & signal_eq_22;
    assign signal_and_37 = signal_and_36 & signal_reg_23;
    assign signal_not_66 = ~ signal_and_37;
    assign signal_not_67 = ~ signal_and_123;
    assign signal_eq_27 = signal_select_123 == signal_const_89;
    assign signal_and_38 = signal_eq_27 & signal_not_67;
    assign signal_and_39 = signal_and_38 & signal_not_66;
    assign signal_not_68 = ~ signal_and_39;
    assign signal_and_40 = signal_not_108 & signal_not_68;
    assign signal_and_41 = signal_and_40 & signal_lt_18;
    assign signal_const_91 = 4'b0111;
    assign signal_eq_28 = signal_select_111 == signal_const_91;
    assign signal_const_92 = 3'b111;
    assign signal_eq_29 = signal_select_123 == signal_const_92;
    assign signal_and_42 = signal_eq_29 & signal_eq_28;
    assign signal_or_34 = signal_and_42 | signal_and_41;
    assign signal_and_43 = signal_or_34 & signal_not_64;
    assign signal_and_44 = signal_and_43 & signal_not_62;
    assign signal_eq_30 = signal_reg_18 == signal_const_56;
    assign signal_eq_31 = signal_reg_20 == signal_const_57;
    assign signal_and_45 = signal_eq_31 & signal_eq_30;
    assign signal_or_35 = signal_and_45 | signal_and_44;
    assign signal_not_69 = ~ signal_and_122;
    assign signal_or_36 = signal_not_69 | signal_or_35;
    assign signal_eq_32 = signal_reg_16 == signal_const_296;
    assign signal_eq_33 = signal_reg_8 == signal_const_58;
    assign signal_and_46 = signal_eq_33 & signal_eq_32;
    assign signal_mux_105 = signal_and_118 ? signal_mux_112 : signal_reg_17;
    assign signal_mux_106 = signal_and_119 ? signal_const_296 : signal_mux_105;
    assign signal_mux_107 = signal_and_47 ? signal_cat_101 : signal_mux_106;
    assign signal_lt_19 = signal_reg_16 < signal_mux_107;
    assign signal_not_70 = ~ signal_lt_19;
    assign signal_mux_108 = signal_and_118 ? signal_mux_116 : signal_reg_9;
    assign signal_mux_109 = signal_and_119 ? signal_const_296 : signal_mux_108;
    assign signal_const_96 = 3'b010;
    assign signal_eq_34 = signal_select_117 == signal_const_96;
    assign signal_const_97 = 3'b101;
    assign signal_eq_35 = signal_select_123 == signal_const_97;
    assign signal_and_47 = signal_eq_35 & signal_eq_34;
    assign signal_mux_110 = signal_and_47 ? signal_cat_101 : signal_mux_109;
    assign signal_lt_20 = signal_mux_110 < signal_reg_8;
    assign signal_not_71 = ~ signal_lt_20;
    assign signal_and_48 = signal_not_71 & signal_not_70;
    assign signal_eq_36 = signal_select_102 == signal_const_87;
    assign signal_const_99 = 3'b110;
    assign signal_eq_37 = signal_select_123 == signal_const_99;
    assign signal_and_49 = signal_eq_37 & signal_eq_36;
    assign signal_eq_38 = signal_select_103 == signal_const_96;
    assign signal_const_101 = 3'b011;
    assign signal_eq_39 = signal_select_123 == signal_const_101;
    assign signal_and_50 = signal_eq_39 & signal_eq_38;
    assign signal_eq_40 = signal_select_105 == signal_const_96;
    assign signal_const_103 = 3'b100;
    assign signal_eq_41 = signal_select_123 == signal_const_103;
    assign signal_and_51 = signal_eq_41 & signal_eq_40;
    assign signal_or_37 = signal_and_51 | signal_and_50;
    assign signal_or_38 = signal_or_37 | signal_and_49;
    assign signal_mux_111 = signal_or_38 ? signal_and_46 : signal_and_48;
    assign signal_not_72 = ~ signal_and_122;
    assign signal_or_39 = signal_not_72 | signal_mux_111;
    assign signal_eq_42 = signal_reg_14 == signal_const_296;
    assign signal_eq_43 = signal_reg_6 == signal_const_58;
    assign signal_and_52 = signal_eq_43 & signal_eq_42;
    assign signal_lt_21 = signal_reg_15 < signal_reg_17;
    assign signal_mux_112 = signal_lt_21 ? signal_reg_15 : signal_reg_17;
    assign signal_mux_113 = signal_and_118 ? signal_mux_112 : signal_reg_15;
    assign signal_mux_114 = signal_and_120 ? signal_const_296 : signal_mux_113;
    assign signal_mux_115 = signal_and_68 ? signal_cat_101 : signal_mux_114;
    assign signal_lt_22 = signal_reg_14 < signal_mux_115;
    assign signal_not_73 = ~ signal_lt_22;
    assign signal_lt_23 = signal_reg_9 < signal_reg_7;
    assign signal_mux_116 = signal_lt_23 ? signal_reg_7 : signal_reg_9;
    assign signal_mux_117 = signal_and_118 ? signal_mux_116 : signal_reg_7;
    assign signal_mux_118 = signal_and_120 ? signal_const_296 : signal_mux_117;
    assign signal_mux_119 = signal_and_68 ? signal_cat_101 : signal_mux_118;
    assign signal_lt_24 = signal_mux_119 < signal_reg_6;
    assign signal_not_74 = ~ signal_lt_24;
    assign signal_and_53 = signal_not_74 & signal_not_73;
    assign signal_mux_120 = signal_or_45 ? signal_and_52 : signal_and_53;
    assign signal_not_75 = ~ signal_and_122;
    assign signal_or_40 = signal_not_75 | signal_mux_120;
    assign signal_eq_44 = signal_reg_12 == signal_const_296;
    assign signal_eq_45 = signal_reg_4 == signal_const_58;
    assign signal_and_54 = signal_eq_45 & signal_eq_44;
    assign signal_mux_121 = signal_or_42 ? signal_wire_22 : signal_reg_13;
    assign signal_mux_122 = signal_and_55 ? signal_cat_101 : signal_mux_121;
    assign signal_lt_25 = signal_reg_12 < signal_mux_122;
    assign signal_not_76 = ~ signal_lt_25;
    assign signal_mux_123 = signal_or_42 ? signal_wire_22 : signal_reg_5;
    assign signal_eq_46 = signal_select_117 == signal_const_103;
    assign signal_eq_47 = signal_select_123 == signal_const_97;
    assign signal_and_55 = signal_eq_47 & signal_eq_46;
    assign signal_mux_124 = signal_and_55 ? signal_cat_101 : signal_mux_123;
    assign signal_lt_26 = signal_mux_124 < signal_reg_4;
    assign signal_not_77 = ~ signal_lt_26;
    assign signal_and_56 = signal_not_77 & signal_not_76;
    assign signal_not_78 = ~ signal_wire_23;
    assign signal_const_108 = 2'b10;
    assign signal_eq_48 = signal_select_102 == signal_const_108;
    assign signal_eq_49 = signal_select_123 == signal_const_99;
    assign signal_and_57 = signal_eq_49 & signal_eq_48;
    assign signal_eq_50 = signal_select_103 == signal_const_99;
    assign signal_eq_51 = signal_select_123 == signal_const_101;
    assign signal_and_58 = signal_eq_51 & signal_eq_50;
    assign signal_eq_52 = signal_select_105 == signal_const_99;
    assign signal_eq_53 = signal_select_123 == signal_const_103;
    assign signal_and_59 = signal_eq_53 & signal_eq_52;
    assign signal_or_41 = signal_and_59 | signal_and_58;
    assign signal_or_42 = signal_or_41 | signal_and_57;
    assign signal_and_60 = signal_or_42 & signal_not_78;
    assign signal_mux_125 = signal_and_60 ? signal_and_54 : signal_and_56;
    assign signal_not_79 = ~ signal_and_122;
    assign signal_or_43 = signal_not_79 | signal_mux_125;
    assign signal_select_47 = signal_mux_126[29:0];
    assign signal_select_48 = signal_mux_153[25:25];
    assign signal_cat_80 = { signal_select_48,
                             signal_select_48 };
    assign signal_cat_81 = { signal_cat_80,
                             signal_cat_80 };
    assign signal_cat_82 = { signal_cat_81,
                             signal_select_48 };
    assign signal_cat_83 = { signal_cat_82,
                             signal_mux_153 };
    assign signal_sub_10 = signal_cat_83 - signal_cat_103;
    assign signal_add_16 = signal_cat_128 + signal_sub_13;
    assign signal_select_49 = signal_add_16[25:25];
    assign signal_cat_84 = { signal_select_49,
                             signal_select_49 };
    assign signal_cat_85 = { signal_cat_84,
                             signal_cat_84 };
    assign signal_cat_86 = { signal_cat_85,
                             signal_select_49 };
    assign signal_cat_87 = { signal_cat_86,
                             signal_add_16 };
    assign signal_mux_126 = signal_and_68 ? signal_sub_10 : signal_cat_87;
    assign signal_select_50 = signal_mux_126[30:30];
    assign signal_not_80 = ~ signal_select_50;
    assign signal_cat_88 = { signal_not_80,
                             signal_select_47 };
    assign signal_select_51 = signal_cat_93[29:0];
    assign signal_cat_89 = { signal_cat_90,
                             signal_select_52 };
    assign signal_select_52 = signal_reg_2[23:23];
    assign signal_cat_90 = { signal_select_52,
                             signal_select_52 };
    assign signal_cat_91 = { signal_cat_90,
                             signal_cat_90 };
    assign signal_cat_92 = { signal_cat_91,
                             signal_cat_89 };
    assign signal_cat_93 = { signal_cat_92,
                             signal_reg_2 };
    assign signal_select_53 = signal_cat_93[30:30];
    assign signal_not_81 = ~ signal_select_53;
    assign signal_cat_94 = { signal_not_81,
                             signal_select_51 };
    assign signal_lt_27 = signal_cat_94 < signal_cat_88;
    assign signal_not_82 = ~ signal_lt_27;
    assign signal_select_54 = signal_cat_99[29:0];
    assign signal_cat_95 = { signal_cat_96,
                             signal_select_55 };
    assign signal_select_55 = signal_reg_10[23:23];
    assign signal_cat_96 = { signal_select_55,
                             signal_select_55 };
    assign signal_cat_97 = { signal_cat_96,
                             signal_cat_96 };
    assign signal_cat_98 = { signal_cat_97,
                             signal_cat_95 };
    assign signal_cat_99 = { signal_cat_98,
                             signal_reg_10 };
    assign signal_select_56 = signal_cat_99[30:30];
    assign signal_not_83 = ~ signal_select_56;
    assign signal_cat_100 = { signal_not_83,
                              signal_select_54 };
    assign signal_select_57 = signal_mux_127[29:0];
    assign signal_select_58 = word[4:0];
    assign signal_const_114 = 11'b00000000000;
    assign signal_cat_101 = { signal_const_114,
                              signal_select_58 };
    assign signal_select_59 = signal_cat_101[4:0];
    assign signal_cat_102 = { gnd,
                              signal_select_59 };
    assign signal_muls_1 = $signed(signal_reg_1) * $signed(signal_cat_102);
    assign signal_select_60 = signal_muls_1[29:29];
    assign signal_cat_103 = { signal_select_60,
                              signal_muls_1 };
    assign signal_select_61 = signal_mux_170[25:25];
    assign signal_cat_104 = { signal_select_61,
                              signal_select_61 };
    assign signal_cat_105 = { signal_cat_104,
                              signal_cat_104 };
    assign signal_cat_106 = { signal_cat_105,
                              signal_select_61 };
    assign signal_cat_107 = { signal_cat_106,
                              signal_mux_170 };
    assign signal_sub_11 = signal_cat_107 - signal_cat_103;
    assign signal_add_17 = signal_cat_142 + signal_sub_16;
    assign signal_select_62 = signal_add_17[25:25];
    assign signal_cat_108 = { signal_select_62,
                              signal_select_62 };
    assign signal_cat_109 = { signal_cat_108,
                              signal_cat_108 };
    assign signal_cat_110 = { signal_cat_109,
                              signal_select_62 };
    assign signal_cat_111 = { signal_cat_110,
                              signal_add_17 };
    assign signal_mux_127 = signal_and_68 ? signal_sub_11 : signal_cat_111;
    assign signal_select_63 = signal_mux_127[30:30];
    assign signal_not_84 = ~ signal_select_63;
    assign signal_cat_112 = { signal_not_84,
                              signal_select_57 };
    assign signal_lt_28 = signal_cat_112 < signal_cat_100;
    assign signal_not_85 = ~ signal_lt_28;
    assign signal_mux_128 = stored ? signal_reg : signal_const_57;
    assign signal_mux_129 = falls_to_next ? signal_reg_1 : signal_mux_128;
    assign signal_mux_130 = signal_wire_66 ? signal_const_57 : signal_reg;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_9 <= signal_mux_130;
        4'b1011:
            signal_cases_9 <= signal_mux_129;
        4'b1100:
            signal_cases_9 <= signal_reg_1;
        default:
            signal_cases_9 <= signal_reg;
        endcase
    end
    assign signal_wire_9 = signal_cases_9;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg <= signal_const_57;
        else
            signal_reg <= signal_wire_9;
    end
    assign signal_mux_131 = signal_and_206 ? signal_const_57 : signal_const_57;
    assign signal_mux_132 = stored ? signal_reg_1 : signal_mux_131;
    assign signal_mux_133 = signal_eq_175 ? signal_const_57 : signal_reg_1;
    assign signal_mux_134 = falls_to_next ? signal_mux_132 : signal_mux_133;
    assign signal_mux_135 = signal_eq_174 ? signal_const_57 : signal_reg_1;
    assign signal_mux_136 = read_done ? signal_mux_135 : signal_reg_1;
    assign signal_mux_137 = signal_not_174 ? signal_const_57 : signal_reg_1;
    assign signal_mux_138 = signal_eq_177 ? signal_const_57 : signal_reg_1;
    assign signal_mux_139 = is_jump ? signal_mux_138 : signal_reg_1;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_10 <= signal_mux_139;
        4'b0101:
            signal_cases_10 <= signal_mux_137;
        4'b0110:
            signal_cases_10 <= signal_mux_136;
        4'b1001:
            signal_cases_10 <= signal_mux_134;
        default:
            signal_cases_10 <= signal_reg_1;
        endcase
    end
    assign signal_wire_10 = signal_cases_10;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_1 <= signal_const_57;
        else
            signal_reg_1 <= signal_wire_10;
    end
    assign signal_eq_54 = signal_reg_1 == signal_reg;
    assign signal_eq_55 = signal_select_102 == signal_const_35;
    assign signal_eq_56 = signal_select_123 == signal_const_99;
    assign signal_and_61 = signal_eq_56 & signal_eq_55;
    assign signal_eq_57 = signal_select_103 == signal_const_89;
    assign signal_eq_58 = signal_select_123 == signal_const_101;
    assign signal_and_62 = signal_eq_58 & signal_eq_57;
    assign signal_eq_59 = signal_select_105 == signal_const_89;
    assign signal_eq_60 = signal_select_123 == signal_const_103;
    assign signal_and_63 = signal_eq_60 & signal_eq_59;
    assign signal_or_44 = signal_and_63 | signal_and_62;
    assign signal_or_45 = signal_or_44 | signal_and_61;
    assign signal_or_46 = signal_or_45 | signal_and_120;
    assign signal_not_86 = ~ signal_or_46;
    assign signal_not_87 = ~ signal_and_123;
    assign signal_not_88 = ~ signal_and_109;
    assign signal_and_64 = signal_not_114 & signal_not_88;
    assign signal_and_65 = signal_and_64 & signal_not_87;
    assign signal_and_66 = signal_and_65 & signal_not_86;
    assign signal_and_67 = signal_and_66 & signal_eq_54;
    assign signal_eq_61 = signal_select_117 == signal_const_89;
    assign signal_eq_62 = signal_select_123 == signal_const_97;
    assign signal_and_68 = signal_eq_62 & signal_eq_61;
    assign signal_mux_140 = signal_and_68 ? signal_or_58 : signal_and_67;
    assign signal_and_69 = signal_mux_140 & signal_not_85;
    assign signal_and_70 = signal_and_69 & signal_not_82;
    assign signal_select_64 = signal_reg_2[23:23];
    assign signal_cat_113 = { signal_select_64,
                              signal_select_64 };
    assign signal_cat_114 = { signal_cat_113,
                              signal_reg_2 };
    assign signal_eq_63 = signal_cat_114 == signal_const_187;
    assign signal_select_65 = signal_reg_10[23:23];
    assign signal_cat_115 = { signal_select_65,
                              signal_select_65 };
    assign signal_cat_116 = { signal_cat_115,
                              signal_reg_10 };
    assign signal_eq_64 = signal_cat_116 == signal_const_188;
    assign signal_and_71 = signal_eq_64 & signal_eq_63;
    assign signal_or_47 = signal_and_71 | signal_and_70;
    assign signal_not_89 = ~ signal_and_122;
    assign signal_or_48 = signal_not_89 | signal_or_47;
    assign signal_select_66 = signal_mux_153[24:0];
    assign signal_select_67 = signal_mux_153[25:25];
    assign signal_not_90 = ~ signal_select_67;
    assign signal_cat_117 = { signal_not_90,
                              signal_select_66 };
    assign signal_select_68 = signal_cat_119[24:0];
    assign signal_select_69 = signal_reg_28[23:23];
    assign signal_cat_118 = { signal_select_69,
                              signal_select_69 };
    assign signal_cat_119 = { signal_cat_118,
                              signal_reg_28 };
    assign signal_select_70 = signal_cat_119[25:25];
    assign signal_not_91 = ~ signal_select_70;
    assign signal_cat_120 = { signal_not_91,
                              signal_select_68 };
    assign signal_lt_29 = signal_cat_120 < signal_cat_117;
    assign signal_not_92 = ~ signal_lt_29;
    assign signal_select_71 = signal_cat_122[24:0];
    assign signal_select_72 = signal_reg_26[23:23];
    assign signal_cat_121 = { signal_select_72,
                              signal_select_72 };
    assign signal_cat_122 = { signal_cat_121,
                              signal_reg_26 };
    assign signal_select_73 = signal_cat_122[25:25];
    assign signal_not_93 = ~ signal_select_73;
    assign signal_cat_123 = { signal_not_93,
                              signal_select_71 };
    assign signal_select_74 = signal_mux_170[24:0];
    assign signal_select_75 = signal_mux_170[25:25];
    assign signal_not_94 = ~ signal_select_75;
    assign signal_cat_124 = { signal_not_94,
                              signal_select_74 };
    assign signal_lt_30 = signal_cat_124 < signal_cat_123;
    assign signal_not_95 = ~ signal_lt_30;
    assign signal_select_76 = signal_mux_153[24:0];
    assign signal_const_129 = 26'b00000000000000000000000001;
    assign signal_cat_125 = { signal_const_35,
                              signal_reg_19 };
    assign signal_sub_12 = signal_cat_125 - signal_const_129;
    assign signal_select_77 = signal_mux_142[24:0];
    assign signal_select_78 = signal_mux_142[25:25];
    assign signal_not_96 = ~ signal_select_78;
    assign signal_cat_126 = { signal_not_96,
                              signal_select_77 };
    assign signal_lt_31 = signal_cat_126 < signal_const_76;
    assign signal_mux_141 = signal_lt_31 ? signal_const_75 : signal_mux_142;
    assign signal_select_79 = signal_cat_128[24:0];
    assign signal_select_80 = signal_reg_3[23:23];
    assign signal_cat_127 = { signal_select_80,
                              signal_select_80 };
    assign signal_cat_128 = { signal_cat_127,
                              signal_reg_3 };
    assign signal_select_81 = signal_cat_128[25:25];
    assign signal_not_97 = ~ signal_select_81;
    assign signal_cat_129 = { signal_not_97,
                              signal_select_79 };
    assign signal_select_82 = signal_cat_137[24:0];
    assign signal_select_83 = signal_cat_137[25:25];
    assign signal_not_98 = ~ signal_select_83;
    assign signal_cat_130 = { signal_not_98,
                              signal_select_82 };
    assign signal_lt_32 = signal_cat_130 < signal_cat_129;
    assign signal_mux_142 = signal_lt_32 ? signal_cat_137 : signal_cat_128;
    assign signal_mux_143 = signal_and_123 ? signal_mux_141 : signal_mux_142;
    assign signal_mux_144 = signal_and_91 ? signal_sub_12 : signal_mux_143;
    assign signal_mux_145 = signal_and_109 ? signal_const_75 : signal_mux_144;
    assign signal_add_18 = signal_mux_145 + signal_sub_13;
    assign signal_cat_131 = { signal_const_28,
                              signal_reg_5 };
    assign signal_cat_132 = { signal_const_28,
                              signal_reg_7 };
    assign signal_cat_133 = { signal_const_28,
                              signal_reg_9 };
    assign signal_mux_146 = signal_and_75 ? signal_cat_133 : signal_mux_160;
    assign signal_mux_147 = signal_and_78 ? signal_cat_132 : signal_mux_146;
    assign signal_or_49 = signal_and_82 | signal_and_81;
    assign signal_mux_148 = signal_or_49 ? signal_cat_131 : signal_mux_147;
    assign signal_sub_13 = signal_cat_151 - signal_mux_148;
    assign signal_cat_134 = { signal_const_35,
                              signal_reg_19 };
    assign signal_sub_14 = signal_cat_134 - signal_const_129;
    assign signal_select_84 = signal_cat_137[24:0];
    assign signal_select_85 = signal_cat_137[25:25];
    assign signal_not_99 = ~ signal_select_85;
    assign signal_cat_135 = { signal_not_99,
                              signal_select_84 };
    assign signal_lt_33 = signal_cat_135 < signal_const_76;
    assign signal_mux_149 = signal_lt_33 ? signal_const_75 : signal_cat_137;
    assign signal_select_86 = signal_reg_29[23:23];
    assign signal_cat_136 = { signal_select_86,
                              signal_select_86 };
    assign signal_cat_137 = { signal_cat_136,
                              signal_reg_29 };
    assign signal_mux_150 = signal_and_123 ? signal_mux_149 : signal_cat_137;
    assign signal_mux_151 = signal_and_91 ? signal_sub_14 : signal_mux_150;
    assign signal_mux_152 = signal_and_109 ? signal_const_75 : signal_mux_151;
    assign signal_add_19 = signal_mux_152 + signal_sub_13;
    assign signal_mux_153 = signal_and_120 ? signal_add_18 : signal_add_19;
    assign signal_select_87 = signal_mux_153[25:25];
    assign signal_not_100 = ~ signal_select_87;
    assign signal_cat_138 = { signal_not_100,
                              signal_select_76 };
    assign signal_lt_34 = signal_const_69 < signal_cat_138;
    assign signal_not_101 = ~ signal_lt_34;
    assign signal_select_88 = signal_mux_170[24:0];
    assign signal_select_89 = signal_mux_155[24:0];
    assign signal_select_90 = signal_mux_155[25:25];
    assign signal_not_102 = ~ signal_select_90;
    assign signal_cat_139 = { signal_not_102,
                              signal_select_89 };
    assign signal_lt_35 = signal_cat_139 < signal_const_76;
    assign signal_mux_154 = signal_lt_35 ? signal_const_75 : signal_mux_155;
    assign signal_select_91 = signal_cat_154[24:0];
    assign signal_select_92 = signal_cat_154[25:25];
    assign signal_not_103 = ~ signal_select_92;
    assign signal_cat_140 = { signal_not_103,
                              signal_select_91 };
    assign signal_select_93 = signal_cat_142[24:0];
    assign signal_select_94 = signal_reg_11[23:23];
    assign signal_cat_141 = { signal_select_94,
                              signal_select_94 };
    assign signal_cat_142 = { signal_cat_141,
                              signal_reg_11 };
    assign signal_select_95 = signal_cat_142[25:25];
    assign signal_not_104 = ~ signal_select_95;
    assign signal_cat_143 = { signal_not_104,
                              signal_select_93 };
    assign signal_lt_36 = signal_cat_143 < signal_cat_140;
    assign signal_mux_155 = signal_lt_36 ? signal_cat_154 : signal_cat_142;
    assign signal_mux_156 = signal_and_123 ? signal_mux_154 : signal_mux_155;
    assign signal_mux_157 = signal_and_91 ? signal_const_129 : signal_mux_156;
    assign signal_mux_158 = signal_and_109 ? signal_const_75 : signal_mux_157;
    assign signal_add_20 = signal_mux_158 + signal_sub_16;
    assign signal_and_72 = signal_and_82 & signal_not_145;
    assign signal_const_147 = 25'b0000000000000000000000000;
    assign signal_cat_144 = { signal_const_147,
                              signal_and_72 };
    assign signal_cat_145 = { signal_const_28,
                              signal_reg_13 };
    assign signal_add_21 = signal_cat_145 + signal_cat_144;
    assign signal_cat_146 = { signal_const_28,
                              signal_reg_15 };
    assign signal_cat_147 = { signal_const_28,
                              signal_reg_17 };
    assign signal_const_151 = 21'b000000000000000000000;
    assign signal_cat_148 = { signal_const_151,
                              signal_select_114 };
    assign signal_cat_149 = { signal_const_35,
                              signal_cat_148 };
    assign signal_sub_15 = signal_const_75 - signal_cat_149;
    assign signal_mux_159 = signal_and_93 ? signal_sub_15 : signal_const_75;
    assign signal_mux_160 = signal_and_104 ? signal_cat_149 : signal_mux_159;
    assign signal_eq_65 = signal_select_114 == signal_const_89;
    assign signal_and_73 = signal_and_105 & signal_eq_76;
    assign signal_and_74 = signal_and_73 & signal_select_115;
    assign signal_and_75 = signal_and_74 & signal_eq_65;
    assign signal_mux_161 = signal_and_75 ? signal_cat_147 : signal_mux_160;
    assign signal_const_156 = 3'b000;
    assign signal_eq_66 = signal_select_114 == signal_const_156;
    assign signal_and_76 = signal_and_105 & signal_eq_76;
    assign signal_and_77 = signal_and_76 & signal_select_115;
    assign signal_and_78 = signal_and_77 & signal_eq_66;
    assign signal_mux_162 = signal_and_78 ? signal_cat_146 : signal_mux_161;
    assign signal_eq_67 = signal_select_114 == signal_const_96;
    assign signal_and_79 = signal_and_105 & signal_eq_76;
    assign signal_and_80 = signal_and_79 & signal_select_115;
    assign signal_and_81 = signal_and_80 & signal_eq_67;
    assign signal_select_96 = word[7:7];
    assign signal_and_82 = signal_and_123 & signal_select_96;
    assign signal_or_50 = signal_and_82 | signal_and_81;
    assign signal_mux_163 = signal_or_50 ? signal_add_21 : signal_mux_162;
    assign signal_const_158 = 24'b000000000000000000000010;
    assign signal_const_159 = 24'b000000000000000000000001;
    assign signal_and_83 = signal_select_97 & signal_const_9;
    assign signal_and_84 = signal_select_97 & signal_const_9;
    assign signal_and_85 = signal_select_97 & signal_const_19;
    assign signal_select_97 = word[12:8];
    always @* begin
        case (signal_wire_30)
        0:
            signal_mux_164 <= signal_select_97;
        1:
            signal_mux_164 <= signal_and_85;
        2:
            signal_mux_164 <= signal_and_84;
        default:
            signal_mux_164 <= signal_and_83;
        endcase
    end
    assign signal_const_163 = 19'b0000000000000000000;
    assign signal_cat_150 = { signal_const_163,
                              signal_mux_164 };
    assign signal_add_22 = signal_cat_150 + signal_const_159;
    assign signal_mux_165 = signal_eq_94 ? signal_const_158 : signal_add_22;
    assign signal_cat_151 = { signal_const_35,
                              signal_mux_165 };
    assign signal_sub_16 = signal_cat_151 - signal_mux_163;
    assign signal_select_98 = signal_cat_154[24:0];
    assign signal_select_99 = signal_cat_154[25:25];
    assign signal_not_105 = ~ signal_select_99;
    assign signal_cat_152 = { signal_not_105,
                              signal_select_98 };
    assign signal_lt_37 = signal_cat_152 < signal_const_76;
    assign signal_mux_166 = signal_lt_37 ? signal_const_75 : signal_cat_154;
    assign signal_select_100 = signal_reg_27[23:23];
    assign signal_cat_153 = { signal_select_100,
                              signal_select_100 };
    assign signal_cat_154 = { signal_cat_153,
                              signal_reg_27 };
    assign signal_mux_167 = signal_and_123 ? signal_mux_166 : signal_cat_154;
    assign signal_mux_168 = signal_and_91 ? signal_const_129 : signal_mux_167;
    assign signal_mux_169 = signal_and_109 ? signal_const_75 : signal_mux_168;
    assign signal_add_23 = signal_mux_169 + signal_sub_16;
    assign signal_mux_170 = signal_and_120 ? signal_add_20 : signal_add_23;
    assign signal_select_101 = signal_mux_170[25:25];
    assign signal_not_106 = ~ signal_select_101;
    assign signal_cat_155 = { signal_not_106,
                              signal_select_88 };
    assign signal_lt_38 = signal_cat_155 < signal_const_70;
    assign signal_not_107 = ~ signal_lt_38;
    assign signal_and_86 = signal_not_107 & signal_not_101;
    assign signal_eq_68 = signal_reg_19 == signal_const_56;
    assign signal_eq_69 = signal_reg_21 == signal_const_57;
    assign signal_and_87 = signal_eq_69 & signal_eq_68;
    assign signal_not_108 = ~ signal_and_87;
    assign signal_eq_70 = signal_select_104 == signal_const_92;
    assign signal_eq_71 = signal_select_118 == signal_const_35;
    assign signal_and_88 = signal_and_110 & signal_eq_71;
    assign signal_and_89 = signal_and_88 & signal_eq_70;
    assign signal_and_90 = signal_and_89 & signal_reg_25;
    assign signal_and_91 = signal_and_90 & signal_not_108;
    assign signal_not_109 = ~ signal_select_115;
    assign signal_eq_72 = signal_select_116 == signal_const_87;
    assign signal_and_92 = signal_and_105 & signal_eq_72;
    assign signal_and_93 = signal_and_92 & signal_not_109;
    assign signal_eq_73 = signal_select_114 == signal_const_89;
    assign signal_and_94 = signal_and_105 & signal_eq_76;
    assign signal_and_95 = signal_and_94 & signal_select_115;
    assign signal_and_96 = signal_and_95 & signal_eq_73;
    assign signal_eq_74 = signal_select_114 == signal_const_156;
    assign signal_and_97 = signal_and_105 & signal_eq_76;
    assign signal_and_98 = signal_and_97 & signal_select_115;
    assign signal_and_99 = signal_and_98 & signal_eq_74;
    assign signal_eq_75 = signal_select_114 == signal_const_96;
    assign signal_and_100 = signal_and_105 & signal_eq_76;
    assign signal_and_101 = signal_and_100 & signal_select_115;
    assign signal_and_102 = signal_and_101 & signal_eq_75;
    assign signal_not_110 = ~ signal_select_115;
    assign signal_eq_76 = signal_select_116 == signal_const_35;
    assign signal_and_103 = signal_and_105 & signal_eq_76;
    assign signal_and_104 = signal_and_103 & signal_not_110;
    assign signal_or_51 = signal_and_104 | signal_and_102;
    assign signal_or_52 = signal_or_51 | signal_and_99;
    assign signal_or_53 = signal_or_52 | signal_and_96;
    assign signal_or_54 = signal_or_53 | signal_and_93;
    assign signal_not_111 = ~ signal_or_54;
    assign signal_select_102 = word[7:6];
    assign signal_eq_77 = signal_select_102 == signal_const_33;
    assign signal_eq_78 = signal_select_123 == signal_const_99;
    assign signal_and_105 = signal_eq_78 & signal_eq_77;
    assign signal_and_106 = signal_and_105 & signal_not_111;
    assign signal_select_103 = word[7:5];
    assign signal_eq_79 = signal_select_103 == signal_const_92;
    assign signal_eq_80 = signal_select_123 == signal_const_101;
    assign signal_and_107 = signal_eq_80 & signal_eq_79;
    assign signal_select_104 = word[2:0];
    assign signal_eq_81 = signal_select_104 == signal_const_99;
    assign signal_eq_82 = signal_select_118 == signal_const_35;
    assign signal_and_108 = signal_and_110 & signal_eq_82;
    assign signal_and_109 = signal_and_108 & signal_eq_81;
    assign signal_not_112 = ~ signal_and_109;
    assign signal_select_105 = word[7:5];
    assign signal_eq_83 = signal_select_105 == signal_const_92;
    assign signal_eq_84 = signal_select_123 == signal_const_103;
    assign signal_and_110 = signal_eq_84 & signal_eq_83;
    assign signal_and_111 = signal_and_110 & signal_not_112;
    assign signal_not_113 = ~ signal_and_123;
    assign signal_eq_85 = signal_select_123 == signal_const_89;
    assign signal_and_112 = signal_eq_85 & signal_not_113;
    assign signal_or_55 = signal_and_112 | signal_and_111;
    assign signal_or_56 = signal_or_55 | signal_and_107;
    assign signal_or_57 = signal_or_56 | signal_and_106;
    assign signal_not_114 = ~ signal_or_57;
    assign signal_or_58 = signal_not_114 | signal_and_91;
    assign signal_and_113 = signal_or_58 & signal_and_86;
    assign signal_and_114 = signal_and_113 & signal_not_95;
    assign signal_and_115 = signal_and_114 & signal_not_92;
    assign signal_const_187 = 26'b00011111111111111111111111;
    assign signal_select_106 = signal_reg_28[23:23];
    assign signal_cat_156 = { signal_select_106,
                              signal_select_106 };
    assign signal_cat_157 = { signal_cat_156,
                              signal_reg_28 };
    assign signal_eq_86 = signal_cat_157 == signal_const_187;
    assign signal_const_188 = 26'b11100000000000000000000000;
    assign signal_select_107 = signal_reg_26[23:23];
    assign signal_cat_158 = { signal_select_107,
                              signal_select_107 };
    assign signal_cat_159 = { signal_cat_158,
                              signal_reg_26 };
    assign signal_eq_87 = signal_cat_159 == signal_const_188;
    assign signal_and_116 = signal_eq_87 & signal_eq_86;
    assign signal_or_59 = signal_and_116 | signal_and_115;
    assign signal_eq_88 = signal_reg_7 == signal_const_58;
    assign signal_eq_89 = signal_reg_9 == signal_const_58;
    assign signal_lt_39 = signal_reg_15 < signal_reg_9;
    assign signal_not_115 = ~ signal_lt_39;
    assign signal_lt_40 = signal_reg_17 < signal_reg_7;
    assign signal_not_116 = ~ signal_lt_40;
    assign signal_and_117 = signal_not_116 & signal_not_115;
    assign signal_const_191 = 4'b0011;
    assign signal_eq_90 = signal_select_108 == signal_const_191;
    assign signal_and_118 = signal_eq_94 & signal_eq_90;
    assign signal_mux_171 = signal_and_118 ? signal_and_117 : vdd;
    assign signal_const_192 = 4'b0010;
    assign signal_eq_91 = signal_select_108 == signal_const_192;
    assign signal_and_119 = signal_eq_94 & signal_eq_91;
    assign signal_mux_172 = signal_and_119 ? signal_eq_89 : signal_mux_171;
    assign signal_const_193 = 4'b0001;
    assign signal_eq_92 = signal_select_108 == signal_const_193;
    assign signal_and_120 = signal_eq_94 & signal_eq_92;
    assign signal_mux_173 = signal_and_120 ? signal_eq_88 : signal_mux_172;
    assign signal_select_108 = word[12:9];
    assign signal_eq_93 = signal_select_108 == signal_const_51;
    assign signal_and_121 = signal_eq_94 & signal_eq_93;
    assign signal_mux_174 = signal_and_121 ? gnd : signal_mux_173;
    assign signal_eq_94 = signal_select_123 == signal_const_156;
    assign signal_not_117 = ~ signal_eq_94;
    assign signal_or_60 = signal_not_117 | signal_mux_174;
    assign signal_and_122 = signal_and_207 & signal_or_60;
    assign signal_not_118 = ~ signal_and_122;
    assign signal_or_61 = signal_not_118 | signal_or_59;
    assign signal_select_109 = signal_reg_29[22:0];
    assign signal_select_110 = signal_reg_29[23:23];
    assign signal_not_119 = ~ signal_select_110;
    assign signal_cat_160 = { signal_not_119,
                              signal_select_109 };
    assign signal_const_196 = 24'b100000000000000000000000;
    assign signal_lt_41 = signal_const_196 < signal_cat_160;
    assign signal_not_120 = ~ signal_lt_41;
    assign signal_eq_95 = signal_select_121 == signal_const_108;
    assign signal_eq_96 = signal_select_123 == signal_const_89;
    assign signal_and_123 = signal_eq_96 & signal_eq_95;
    assign signal_not_121 = ~ signal_and_123;
    assign signal_select_111 = word[3:0];
    assign signal_eq_97 = signal_select_111 == signal_const_193;
    assign signal_eq_98 = signal_select_123 == signal_const_92;
    assign signal_and_124 = signal_eq_98 & signal_eq_97;
    assign signal_const_201 = 4'b1001;
    assign signal_select_112 = word[3:0];
    assign signal_lt_42 = signal_select_112 < signal_const_201;
    assign signal_select_113 = word[7:4];
    assign signal_eq_99 = signal_select_113 == signal_const_51;
    assign signal_and_125 = signal_eq_99 & signal_lt_42;
    assign signal_select_114 = word[2:0];
    assign signal_lt_43 = signal_select_114 < signal_const_97;
    assign signal_select_115 = word[3:3];
    assign signal_not_122 = ~ signal_select_115;
    assign signal_or_62 = signal_not_122 | signal_lt_43;
    assign signal_select_116 = word[5:4];
    assign signal_lt_44 = signal_select_116 < signal_const_33;
    assign signal_and_126 = signal_lt_44 & signal_or_62;
    assign signal_select_117 = word[7:5];
    assign signal_lt_45 = signal_select_117 < signal_const_97;
    assign signal_select_118 = word[4:3];
    assign signal_lt_46 = signal_select_118 < signal_const_33;
    assign signal_lt_47 = signal_const_20 < signal_select_119;
    assign signal_not_123 = ~ signal_lt_47;
    assign signal_select_119 = word[4:0];
    assign signal_lt_48 = signal_select_119 < signal_const_4;
    assign signal_not_124 = ~ signal_lt_48;
    assign signal_and_127 = signal_not_124 & signal_not_123;
    assign signal_eq_100 = signal_select_120 == signal_const;
    assign signal_eq_101 = signal_select_120 == signal_const;
    assign signal_const_211 = 5'b11100;
    assign signal_lt_49 = signal_select_120 < signal_const_211;
    assign signal_select_120 = word[4:0];
    assign signal_lt_50 = signal_select_120 < signal_const_211;
    assign signal_select_121 = word[6:5];
    always @* begin
        case (signal_select_121)
        0:
            signal_mux_175 <= signal_lt_50;
        1:
            signal_mux_175 <= signal_lt_49;
        2:
            signal_mux_175 <= signal_eq_101;
        default:
            signal_mux_175 <= signal_eq_100;
        endcase
    end
    assign signal_const_213 = 4'b1100;
    assign signal_select_122 = word[12:9];
    assign signal_lt_51 = signal_select_122 < signal_const_213;
    assign signal_select_123 = word[15:13];
    always @* begin
        case (signal_select_123)
        0:
            signal_mux_176 <= signal_lt_51;
        1:
            signal_mux_176 <= signal_mux_175;
        2:
            signal_mux_176 <= signal_and_127;
        3:
            signal_mux_176 <= signal_and_127;
        4:
            signal_mux_176 <= signal_lt_46;
        5:
            signal_mux_176 <= signal_lt_45;
        6:
            signal_mux_176 <= signal_and_126;
        default:
            signal_mux_176 <= signal_and_125;
        endcase
    end
    assign signal_not_125 = ~ signal_mux_176;
    assign signal_or_63 = signal_not_125 | signal_and_124;
    assign signal_not_126 = ~ signal_or_63;
    assign signal_lt_52 = signal_reg_19 < signal_reg_21;
    assign signal_lt_53 = signal_reg_17 < signal_reg_9;
    assign signal_lt_54 = signal_reg_15 < signal_reg_7;
    assign signal_lt_55 = signal_reg_13 < signal_reg_5;
    assign signal_select_124 = signal_reg_27[22:0];
    assign signal_select_125 = signal_reg_27[23:23];
    assign signal_not_127 = ~ signal_select_125;
    assign signal_cat_161 = { signal_not_127,
                              signal_select_124 };
    assign signal_select_126 = signal_reg_29[22:0];
    assign signal_select_127 = signal_mux_268[23:0];
    assign signal_const_216 = 24'b011111111111111111111111;
    assign signal_mux_177 = signal_and_204 ? signal_select_127 : signal_const_216;
    assign signal_eq_102 = signal_reg_7 == signal_const_58;
    assign signal_eq_103 = signal_reg_9 == signal_const_58;
    assign signal_lt_56 = signal_reg_15 < signal_reg_9;
    assign signal_not_128 = ~ signal_lt_56;
    assign signal_lt_57 = signal_reg_17 < signal_reg_7;
    assign signal_not_129 = ~ signal_lt_57;
    assign signal_and_128 = signal_not_129 & signal_not_128;
    assign signal_mux_178 = signal_and_144 ? signal_and_128 : vdd;
    assign signal_mux_179 = signal_and_145 ? signal_eq_103 : signal_mux_178;
    assign signal_mux_180 = signal_and_160 ? signal_eq_102 : signal_mux_179;
    assign signal_eq_104 = signal_select_159 == signal_const_51;
    assign signal_and_129 = signal_eq_142 & signal_eq_104;
    assign signal_mux_181 = signal_and_129 ? gnd : signal_mux_180;
    assign signal_not_130 = ~ signal_eq_142;
    assign signal_or_64 = signal_not_130 | signal_mux_181;
    assign signal_eq_105 = signal_select_173 == signal_const_193;
    assign signal_eq_106 = signal_select_184 == signal_const_92;
    assign signal_and_130 = signal_eq_106 & signal_eq_105;
    assign signal_select_128 = word[3:0];
    assign signal_lt_58 = signal_select_128 < signal_const_201;
    assign signal_select_129 = word[7:4];
    assign signal_eq_107 = signal_select_129 == signal_const_51;
    assign signal_and_131 = signal_eq_107 & signal_lt_58;
    assign signal_lt_59 = signal_select_175 < signal_const_97;
    assign signal_not_131 = ~ signal_select_176;
    assign signal_or_65 = signal_not_131 | signal_lt_59;
    assign signal_lt_60 = signal_select_177 < signal_const_33;
    assign signal_and_132 = signal_lt_60 & signal_or_65;
    assign signal_lt_61 = signal_select_155 < signal_const_97;
    assign signal_lt_62 = signal_select_181 < signal_const_33;
    assign signal_lt_63 = signal_const_20 < signal_select_130;
    assign signal_not_132 = ~ signal_lt_63;
    assign signal_select_130 = word[4:0];
    assign signal_lt_64 = signal_select_130 < signal_const_4;
    assign signal_not_133 = ~ signal_lt_64;
    assign signal_and_133 = signal_not_133 & signal_not_132;
    assign signal_eq_108 = signal_select_172 == signal_const;
    assign signal_eq_109 = signal_select_172 == signal_const;
    assign signal_lt_65 = signal_select_172 < signal_const_211;
    assign signal_lt_66 = signal_select_172 < signal_const_211;
    always @* begin
        case (signal_select_183)
        0:
            signal_mux_182 <= signal_lt_66;
        1:
            signal_mux_182 <= signal_lt_65;
        2:
            signal_mux_182 <= signal_eq_109;
        default:
            signal_mux_182 <= signal_eq_108;
        endcase
    end
    assign signal_select_131 = word[12:9];
    assign signal_lt_67 = signal_select_131 < signal_const_213;
    always @* begin
        case (signal_select_184)
        0:
            signal_mux_183 <= signal_lt_67;
        1:
            signal_mux_183 <= signal_mux_182;
        2:
            signal_mux_183 <= signal_and_133;
        3:
            signal_mux_183 <= signal_and_133;
        4:
            signal_mux_183 <= signal_lt_62;
        5:
            signal_mux_183 <= signal_lt_61;
        6:
            signal_mux_183 <= signal_and_132;
        default:
            signal_mux_183 <= signal_and_131;
        endcase
    end
    assign signal_not_134 = ~ signal_mux_183;
    assign signal_or_66 = signal_not_134 | signal_and_130;
    assign signal_not_135 = ~ signal_or_66;
    assign signal_lt_68 = signal_reg_19 < signal_reg_21;
    assign signal_lt_69 = signal_reg_17 < signal_reg_9;
    assign signal_lt_70 = signal_reg_15 < signal_reg_7;
    assign signal_lt_71 = signal_reg_13 < signal_reg_5;
    assign signal_select_132 = signal_reg_27[22:0];
    assign signal_select_133 = signal_mux_355[23:0];
    assign signal_select_134 = signal_mux_268[24:0];
    assign signal_cat_162 = { signal_const_35,
                              signal_reg_19 };
    assign signal_sub_17 = signal_cat_162 - signal_const_129;
    assign signal_select_135 = signal_mux_197[24:0];
    assign signal_select_136 = signal_mux_197[25:25];
    assign signal_not_136 = ~ signal_select_136;
    assign signal_cat_163 = { signal_not_136,
                              signal_select_135 };
    assign signal_lt_72 = signal_cat_163 < signal_const_76;
    assign signal_mux_184 = signal_lt_72 ? signal_const_75 : signal_mux_197;
    assign signal_select_137 = signal_cat_165[24:0];
    assign signal_mux_185 = signal_and_206 ? signal_const_216 : signal_const_216;
    assign signal_mux_186 = stored ? signal_reg_2 : signal_mux_185;
    assign signal_mux_187 = signal_eq_175 ? signal_const_216 : signal_reg_2;
    assign signal_mux_188 = falls_to_next ? signal_mux_186 : signal_mux_187;
    assign signal_mux_189 = signal_eq_174 ? signal_const_216 : signal_reg_2;
    assign signal_mux_190 = read_done ? signal_mux_189 : signal_reg_2;
    assign signal_mux_191 = signal_not_174 ? signal_const_216 : signal_reg_2;
    assign signal_mux_192 = signal_eq_177 ? signal_const_216 : signal_reg_2;
    assign signal_mux_193 = is_jump ? signal_mux_192 : signal_reg_2;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_11 <= signal_mux_193;
        4'b0101:
            signal_cases_11 <= signal_mux_191;
        4'b0110:
            signal_cases_11 <= signal_mux_190;
        4'b1001:
            signal_cases_11 <= signal_mux_188;
        default:
            signal_cases_11 <= signal_reg_2;
        endcase
    end
    assign signal_wire_11 = signal_cases_11;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_2 <= signal_const_57;
        else
            signal_reg_2 <= signal_wire_11;
    end
    assign signal_mux_194 = stored ? signal_reg_3 : signal_const_216;
    assign signal_mux_195 = falls_to_next ? signal_reg_2 : signal_mux_194;
    assign signal_mux_196 = signal_wire_66 ? signal_const_216 : signal_reg_3;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_12 <= signal_mux_196;
        4'b1011:
            signal_cases_12 <= signal_mux_195;
        4'b1100:
            signal_cases_12 <= signal_reg_2;
        default:
            signal_cases_12 <= signal_reg_3;
        endcase
    end
    assign signal_wire_12 = signal_cases_12;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_3 <= signal_const_57;
        else
            signal_reg_3 <= signal_wire_12;
    end
    assign signal_select_138 = signal_reg_3[23:23];
    assign signal_cat_164 = { signal_select_138,
                              signal_select_138 };
    assign signal_cat_165 = { signal_cat_164,
                              signal_reg_3 };
    assign signal_select_139 = signal_cat_165[25:25];
    assign signal_not_137 = ~ signal_select_139;
    assign signal_cat_166 = { signal_not_137,
                              signal_select_137 };
    assign signal_select_140 = signal_cat_190[24:0];
    assign signal_select_141 = signal_cat_190[25:25];
    assign signal_not_138 = ~ signal_select_141;
    assign signal_cat_167 = { signal_not_138,
                              signal_select_140 };
    assign signal_lt_73 = signal_cat_167 < signal_cat_166;
    assign signal_mux_197 = signal_lt_73 ? signal_cat_190 : signal_cat_165;
    assign signal_mux_198 = signal_and_201 ? signal_mux_184 : signal_mux_197;
    assign signal_mux_199 = signal_and_180 ? signal_sub_17 : signal_mux_198;
    assign signal_mux_200 = signal_and_198 ? signal_const_75 : signal_mux_199;
    assign signal_add_24 = signal_mux_200 + signal_sub_18;
    assign signal_mux_201 = signal_or_69 ? signal_wire_22 : signal_reg_5;
    assign signal_mux_202 = signal_and_135 ? signal_cat_182 : signal_mux_201;
    assign signal_mux_203 = signal_not_147 ? signal_mux_202 : signal_const_58;
    assign signal_mux_204 = signal_and_206 ? signal_mux_203 : signal_const_58;
    assign signal_mux_205 = stored ? signal_reg_4 : signal_mux_204;
    assign signal_mux_206 = signal_eq_175 ? signal_const_58 : signal_reg_4;
    assign signal_mux_207 = falls_to_next ? signal_mux_205 : signal_mux_206;
    always @* begin
        case (field)
        3'b010:
            signal_cases_13 <= signal_select_142;
        default:
            signal_cases_13 <= signal_reg_4;
        endcase
    end
    assign signal_mux_208 = last_word ? signal_cases_13 : signal_reg_4;
    assign signal_mux_209 = read_done ? signal_mux_208 : signal_reg_4;
    assign signal_mux_210 = signal_eq_172 ? signal_reg_4 : signal_mux_209;
    assign signal_mux_211 = signal_eq_173 ? signal_reg_4 : signal_mux_210;
    assign signal_mux_212 = signal_eq_174 ? signal_const_58 : signal_reg_4;
    assign signal_mux_213 = read_done ? signal_mux_212 : signal_reg_4;
    assign signal_mux_214 = signal_not_174 ? signal_const_58 : signal_reg_4;
    assign signal_mux_215 = signal_eq_177 ? signal_const_58 : signal_reg_4;
    assign signal_mux_216 = is_jump ? signal_mux_215 : signal_reg_4;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_14 <= signal_mux_216;
        4'b0101:
            signal_cases_14 <= signal_mux_214;
        4'b0110:
            signal_cases_14 <= signal_mux_213;
        4'b0111:
            signal_cases_14 <= signal_mux_211;
        4'b1001:
            signal_cases_14 <= signal_mux_207;
        default:
            signal_cases_14 <= signal_reg_4;
        endcase
    end
    assign signal_wire_13 = signal_cases_14;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_4 <= signal_const_58;
        else
            signal_reg_4 <= signal_wire_13;
    end
    assign signal_mux_217 = stored ? signal_reg_5 : signal_const_58;
    assign signal_mux_218 = falls_to_next ? signal_reg_4 : signal_mux_217;
    assign signal_mux_219 = signal_wire_66 ? signal_const_58 : signal_reg_5;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_15 <= signal_mux_219;
        4'b1011:
            signal_cases_15 <= signal_mux_218;
        4'b1100:
            signal_cases_15 <= signal_reg_4;
        default:
            signal_cases_15 <= signal_reg_5;
        endcase
    end
    assign signal_wire_14 = signal_cases_15;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_5 <= signal_const_58;
        else
            signal_reg_5 <= signal_wire_14;
    end
    assign signal_cat_168 = { signal_const_28,
                              signal_reg_5 };
    assign signal_cat_169 = { signal_const_28,
                              signal_reg_7 };
    assign signal_mux_220 = signal_and_144 ? signal_mux_240 : signal_reg_7;
    assign signal_mux_221 = signal_and_160 ? signal_const_296 : signal_mux_220;
    assign signal_mux_222 = signal_and_140 ? signal_cat_182 : signal_mux_221;
    assign signal_mux_223 = signal_not_148 ? signal_mux_222 : signal_const_58;
    assign signal_mux_224 = signal_and_206 ? signal_mux_223 : signal_const_58;
    assign signal_mux_225 = stored ? signal_reg_6 : signal_mux_224;
    assign signal_mux_226 = signal_eq_175 ? signal_const_58 : signal_reg_6;
    assign signal_mux_227 = falls_to_next ? signal_mux_225 : signal_mux_226;
    always @* begin
        case (field)
        3'b011:
            signal_cases_16 <= signal_select_142;
        default:
            signal_cases_16 <= signal_reg_6;
        endcase
    end
    assign signal_mux_228 = last_word ? signal_cases_16 : signal_reg_6;
    assign signal_mux_229 = read_done ? signal_mux_228 : signal_reg_6;
    assign signal_mux_230 = signal_eq_172 ? signal_reg_6 : signal_mux_229;
    assign signal_mux_231 = signal_eq_173 ? signal_reg_6 : signal_mux_230;
    assign signal_mux_232 = signal_eq_174 ? signal_const_58 : signal_reg_6;
    assign signal_mux_233 = read_done ? signal_mux_232 : signal_reg_6;
    assign signal_mux_234 = signal_not_174 ? signal_const_58 : signal_reg_6;
    assign signal_mux_235 = signal_eq_177 ? signal_const_58 : signal_reg_6;
    assign signal_mux_236 = is_jump ? signal_mux_235 : signal_reg_6;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_17 <= signal_mux_236;
        4'b0101:
            signal_cases_17 <= signal_mux_234;
        4'b0110:
            signal_cases_17 <= signal_mux_233;
        4'b0111:
            signal_cases_17 <= signal_mux_231;
        4'b1001:
            signal_cases_17 <= signal_mux_227;
        default:
            signal_cases_17 <= signal_reg_6;
        endcase
    end
    assign signal_wire_15 = signal_cases_17;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_6 <= signal_const_58;
        else
            signal_reg_6 <= signal_wire_15;
    end
    assign signal_mux_237 = stored ? signal_reg_7 : signal_const_58;
    assign signal_mux_238 = falls_to_next ? signal_reg_6 : signal_mux_237;
    assign signal_mux_239 = signal_wire_66 ? signal_const_58 : signal_reg_7;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_18 <= signal_mux_239;
        4'b1011:
            signal_cases_18 <= signal_mux_238;
        4'b1100:
            signal_cases_18 <= signal_reg_6;
        default:
            signal_cases_18 <= signal_reg_7;
        endcase
    end
    assign signal_wire_16 = signal_cases_18;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_7 <= signal_const_58;
        else
            signal_reg_7 <= signal_wire_16;
    end
    assign signal_lt_74 = signal_reg_9 < signal_reg_7;
    assign signal_mux_240 = signal_lt_74 ? signal_reg_7 : signal_reg_9;
    assign signal_mux_241 = signal_and_144 ? signal_mux_240 : signal_reg_9;
    assign signal_mux_242 = signal_and_145 ? signal_const_296 : signal_mux_241;
    assign signal_mux_243 = signal_and_146 ? signal_cat_182 : signal_mux_242;
    assign signal_mux_244 = signal_not_149 ? signal_mux_243 : signal_const_58;
    assign signal_mux_245 = signal_and_206 ? signal_mux_244 : signal_const_58;
    assign signal_mux_246 = stored ? signal_reg_8 : signal_mux_245;
    assign signal_mux_247 = signal_eq_175 ? signal_const_58 : signal_reg_8;
    assign signal_mux_248 = falls_to_next ? signal_mux_246 : signal_mux_247;
    assign signal_select_142 = shifted[31:16];
    always @* begin
        case (field)
        3'b100:
            signal_cases_19 <= signal_select_142;
        default:
            signal_cases_19 <= signal_reg_8;
        endcase
    end
    assign signal_mux_249 = last_word ? signal_cases_19 : signal_reg_8;
    assign signal_mux_250 = read_done ? signal_mux_249 : signal_reg_8;
    assign signal_mux_251 = signal_eq_172 ? signal_reg_8 : signal_mux_250;
    assign signal_mux_252 = signal_eq_173 ? signal_reg_8 : signal_mux_251;
    assign signal_mux_253 = signal_eq_174 ? signal_const_58 : signal_reg_8;
    assign signal_mux_254 = read_done ? signal_mux_253 : signal_reg_8;
    assign signal_mux_255 = signal_not_174 ? signal_const_58 : signal_reg_8;
    assign signal_mux_256 = signal_eq_177 ? signal_const_58 : signal_reg_8;
    assign signal_mux_257 = is_jump ? signal_mux_256 : signal_reg_8;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_20 <= signal_mux_257;
        4'b0101:
            signal_cases_20 <= signal_mux_255;
        4'b0110:
            signal_cases_20 <= signal_mux_254;
        4'b0111:
            signal_cases_20 <= signal_mux_252;
        4'b1001:
            signal_cases_20 <= signal_mux_248;
        default:
            signal_cases_20 <= signal_reg_8;
        endcase
    end
    assign signal_wire_17 = signal_cases_20;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_8 <= signal_const_58;
        else
            signal_reg_8 <= signal_wire_17;
    end
    assign signal_mux_258 = stored ? signal_reg_9 : signal_const_58;
    assign signal_mux_259 = falls_to_next ? signal_reg_8 : signal_mux_258;
    assign signal_mux_260 = signal_wire_66 ? signal_const_58 : signal_reg_9;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_21 <= signal_mux_260;
        4'b1011:
            signal_cases_21 <= signal_mux_259;
        4'b1100:
            signal_cases_21 <= signal_reg_8;
        default:
            signal_cases_21 <= signal_reg_9;
        endcase
    end
    assign signal_wire_18 = signal_cases_21;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_9 <= signal_const_58;
        else
            signal_reg_9 <= signal_wire_18;
    end
    assign signal_cat_170 = { signal_const_28,
                              signal_reg_9 };
    assign signal_mux_261 = signal_and_152 ? signal_cat_170 : signal_mux_347;
    assign signal_mux_262 = signal_and_155 ? signal_cat_169 : signal_mux_261;
    assign signal_or_67 = signal_and_159 | signal_and_158;
    assign signal_mux_263 = signal_or_67 ? signal_cat_168 : signal_mux_262;
    assign signal_sub_18 = signal_cat_186 - signal_mux_263;
    assign signal_cat_171 = { signal_const_35,
                              signal_reg_19 };
    assign signal_sub_19 = signal_cat_171 - signal_const_129;
    assign signal_select_143 = signal_cat_190[24:0];
    assign signal_select_144 = signal_cat_190[25:25];
    assign signal_not_139 = ~ signal_select_144;
    assign signal_cat_172 = { signal_not_139,
                              signal_select_143 };
    assign signal_lt_75 = signal_cat_172 < signal_const_76;
    assign signal_mux_264 = signal_lt_75 ? signal_const_75 : signal_cat_190;
    assign signal_mux_265 = signal_and_201 ? signal_mux_264 : signal_cat_190;
    assign signal_mux_266 = signal_and_180 ? signal_sub_19 : signal_mux_265;
    assign signal_mux_267 = signal_and_198 ? signal_const_75 : signal_mux_266;
    assign signal_add_25 = signal_mux_267 + signal_sub_18;
    assign signal_mux_268 = signal_and_160 ? signal_add_24 : signal_add_25;
    assign signal_select_145 = signal_mux_268[25:25];
    assign signal_not_140 = ~ signal_select_145;
    assign signal_cat_173 = { signal_not_140,
                              signal_select_134 };
    assign signal_lt_76 = signal_const_69 < signal_cat_173;
    assign signal_not_141 = ~ signal_lt_76;
    assign signal_select_146 = signal_mux_355[24:0];
    assign signal_select_147 = signal_mux_282[24:0];
    assign signal_select_148 = signal_mux_282[25:25];
    assign signal_not_142 = ~ signal_select_148;
    assign signal_cat_174 = { signal_not_142,
                              signal_select_147 };
    assign signal_lt_77 = signal_cat_174 < signal_const_76;
    assign signal_mux_269 = signal_lt_77 ? signal_const_75 : signal_mux_282;
    assign signal_select_149 = signal_cat_195[24:0];
    assign signal_select_150 = signal_cat_195[25:25];
    assign signal_not_143 = ~ signal_select_150;
    assign signal_cat_175 = { signal_not_143,
                              signal_select_149 };
    assign signal_select_151 = signal_cat_177[24:0];
    assign signal_mux_270 = signal_and_206 ? signal_const_196 : signal_const_196;
    assign signal_mux_271 = stored ? signal_reg_10 : signal_mux_270;
    assign signal_mux_272 = signal_eq_175 ? signal_const_196 : signal_reg_10;
    assign signal_mux_273 = falls_to_next ? signal_mux_271 : signal_mux_272;
    assign signal_mux_274 = signal_eq_174 ? signal_const_196 : signal_reg_10;
    assign signal_mux_275 = read_done ? signal_mux_274 : signal_reg_10;
    assign signal_mux_276 = signal_not_174 ? signal_const_196 : signal_reg_10;
    assign signal_mux_277 = signal_eq_177 ? signal_const_196 : signal_reg_10;
    assign signal_mux_278 = is_jump ? signal_mux_277 : signal_reg_10;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_22 <= signal_mux_278;
        4'b0101:
            signal_cases_22 <= signal_mux_276;
        4'b0110:
            signal_cases_22 <= signal_mux_275;
        4'b1001:
            signal_cases_22 <= signal_mux_273;
        default:
            signal_cases_22 <= signal_reg_10;
        endcase
    end
    assign signal_wire_19 = signal_cases_22;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_10 <= signal_const_57;
        else
            signal_reg_10 <= signal_wire_19;
    end
    assign signal_mux_279 = stored ? signal_reg_11 : signal_const_196;
    assign signal_mux_280 = falls_to_next ? signal_reg_10 : signal_mux_279;
    assign signal_mux_281 = signal_wire_66 ? signal_const_196 : signal_reg_11;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_23 <= signal_mux_281;
        4'b1011:
            signal_cases_23 <= signal_mux_280;
        4'b1100:
            signal_cases_23 <= signal_reg_10;
        default:
            signal_cases_23 <= signal_reg_11;
        endcase
    end
    assign signal_wire_20 = signal_cases_23;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_11 <= signal_const_57;
        else
            signal_reg_11 <= signal_wire_20;
    end
    assign signal_select_152 = signal_reg_11[23:23];
    assign signal_cat_176 = { signal_select_152,
                              signal_select_152 };
    assign signal_cat_177 = { signal_cat_176,
                              signal_reg_11 };
    assign signal_select_153 = signal_cat_177[25:25];
    assign signal_not_144 = ~ signal_select_153;
    assign signal_cat_178 = { signal_not_144,
                              signal_select_151 };
    assign signal_lt_78 = signal_cat_178 < signal_cat_175;
    assign signal_mux_282 = signal_lt_78 ? signal_cat_195 : signal_cat_177;
    assign signal_mux_283 = signal_and_201 ? signal_mux_269 : signal_mux_282;
    assign signal_mux_284 = signal_and_180 ? signal_const_129 : signal_mux_283;
    assign signal_mux_285 = signal_and_198 ? signal_const_75 : signal_mux_284;
    assign signal_add_26 = signal_mux_285 + signal_sub_21;
    assign signal_wire_21 = config$period_fraction;
    assign signal_eq_110 = signal_wire_21 == signal_const_58;
    assign signal_not_145 = ~ signal_eq_110;
    assign signal_and_134 = signal_and_159 & signal_not_145;
    assign signal_cat_179 = { signal_const_147,
                              signal_and_134 };
    assign signal_wire_22 = setup$loaded$value;
    assign signal_mux_286 = signal_or_69 ? signal_wire_22 : signal_reg_13;
    assign signal_eq_111 = signal_select_155 == signal_const_103;
    assign signal_eq_112 = signal_select_184 == signal_const_97;
    assign signal_and_135 = signal_eq_112 & signal_eq_111;
    assign signal_mux_287 = signal_and_135 ? signal_cat_182 : signal_mux_286;
    assign signal_wire_23 = setup$loaded$valid;
    assign signal_not_146 = ~ signal_wire_23;
    assign signal_eq_113 = signal_select_178 == signal_const_108;
    assign signal_eq_114 = signal_select_184 == signal_const_99;
    assign signal_and_136 = signal_eq_114 & signal_eq_113;
    assign signal_eq_115 = signal_select_179 == signal_const_99;
    assign signal_eq_116 = signal_select_184 == signal_const_101;
    assign signal_and_137 = signal_eq_116 & signal_eq_115;
    assign signal_eq_117 = signal_select_182 == signal_const_99;
    assign signal_eq_118 = signal_select_184 == signal_const_103;
    assign signal_and_138 = signal_eq_118 & signal_eq_117;
    assign signal_or_68 = signal_and_138 | signal_and_137;
    assign signal_or_69 = signal_or_68 | signal_and_136;
    assign signal_and_139 = signal_or_69 & signal_not_146;
    assign signal_not_147 = ~ signal_and_139;
    assign signal_mux_288 = signal_not_147 ? signal_mux_287 : signal_const_296;
    assign signal_mux_289 = signal_and_206 ? signal_mux_288 : signal_const_58;
    assign signal_mux_290 = stored ? signal_reg_12 : signal_mux_289;
    assign signal_mux_291 = signal_eq_175 ? signal_const_296 : signal_reg_12;
    assign signal_mux_292 = falls_to_next ? signal_mux_290 : signal_mux_291;
    always @* begin
        case (field)
        3'b010:
            signal_cases_24 <= signal_select_156;
        default:
            signal_cases_24 <= signal_reg_12;
        endcase
    end
    assign signal_mux_293 = last_word ? signal_cases_24 : signal_reg_12;
    assign signal_mux_294 = read_done ? signal_mux_293 : signal_reg_12;
    assign signal_mux_295 = signal_eq_172 ? signal_reg_12 : signal_mux_294;
    assign signal_mux_296 = signal_eq_173 ? signal_reg_12 : signal_mux_295;
    assign signal_mux_297 = signal_eq_174 ? signal_const_296 : signal_reg_12;
    assign signal_mux_298 = read_done ? signal_mux_297 : signal_reg_12;
    assign signal_mux_299 = signal_not_174 ? signal_const_58 : signal_reg_12;
    assign signal_mux_300 = signal_eq_177 ? signal_const_296 : signal_reg_12;
    assign signal_mux_301 = is_jump ? signal_mux_300 : signal_reg_12;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_25 <= signal_mux_301;
        4'b0101:
            signal_cases_25 <= signal_mux_299;
        4'b0110:
            signal_cases_25 <= signal_mux_298;
        4'b0111:
            signal_cases_25 <= signal_mux_296;
        4'b1001:
            signal_cases_25 <= signal_mux_292;
        default:
            signal_cases_25 <= signal_reg_12;
        endcase
    end
    assign signal_wire_24 = signal_cases_25;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_12 <= signal_const_58;
        else
            signal_reg_12 <= signal_wire_24;
    end
    assign signal_mux_302 = stored ? signal_reg_13 : signal_const_58;
    assign signal_mux_303 = falls_to_next ? signal_reg_12 : signal_mux_302;
    assign signal_const_296 = 16'b1111111111111111;
    assign signal_mux_304 = signal_wire_66 ? signal_const_296 : signal_reg_13;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_26 <= signal_mux_304;
        4'b1011:
            signal_cases_26 <= signal_mux_303;
        4'b1100:
            signal_cases_26 <= signal_reg_12;
        default:
            signal_cases_26 <= signal_reg_13;
        endcase
    end
    assign signal_wire_25 = signal_cases_26;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_13 <= signal_const_58;
        else
            signal_reg_13 <= signal_wire_25;
    end
    assign signal_cat_180 = { signal_const_28,
                              signal_reg_13 };
    assign signal_add_27 = signal_cat_180 + signal_cat_179;
    assign signal_cat_181 = { signal_const_28,
                              signal_reg_15 };
    assign signal_select_154 = word[4:0];
    assign signal_cat_182 = { signal_const_114,
                              signal_select_154 };
    assign signal_mux_305 = signal_and_144 ? signal_mux_325 : signal_reg_15;
    assign signal_mux_306 = signal_and_160 ? signal_const_296 : signal_mux_305;
    assign signal_eq_119 = signal_select_155 == signal_const_89;
    assign signal_eq_120 = signal_select_184 == signal_const_97;
    assign signal_and_140 = signal_eq_120 & signal_eq_119;
    assign signal_mux_307 = signal_and_140 ? signal_cat_182 : signal_mux_306;
    assign signal_eq_121 = signal_select_178 == signal_const_35;
    assign signal_eq_122 = signal_select_184 == signal_const_99;
    assign signal_and_141 = signal_eq_122 & signal_eq_121;
    assign signal_eq_123 = signal_select_179 == signal_const_89;
    assign signal_eq_124 = signal_select_184 == signal_const_101;
    assign signal_and_142 = signal_eq_124 & signal_eq_123;
    assign signal_eq_125 = signal_select_182 == signal_const_89;
    assign signal_eq_126 = signal_select_184 == signal_const_103;
    assign signal_and_143 = signal_eq_126 & signal_eq_125;
    assign signal_or_70 = signal_and_143 | signal_and_142;
    assign signal_or_71 = signal_or_70 | signal_and_141;
    assign signal_not_148 = ~ signal_or_71;
    assign signal_mux_308 = signal_not_148 ? signal_mux_307 : signal_const_296;
    assign signal_mux_309 = signal_and_206 ? signal_mux_308 : signal_const_58;
    assign signal_mux_310 = stored ? signal_reg_14 : signal_mux_309;
    assign signal_mux_311 = signal_eq_175 ? signal_const_296 : signal_reg_14;
    assign signal_mux_312 = falls_to_next ? signal_mux_310 : signal_mux_311;
    always @* begin
        case (field)
        3'b011:
            signal_cases_27 <= signal_select_156;
        default:
            signal_cases_27 <= signal_reg_14;
        endcase
    end
    assign signal_mux_313 = last_word ? signal_cases_27 : signal_reg_14;
    assign signal_mux_314 = read_done ? signal_mux_313 : signal_reg_14;
    assign signal_mux_315 = signal_eq_172 ? signal_reg_14 : signal_mux_314;
    assign signal_mux_316 = signal_eq_173 ? signal_reg_14 : signal_mux_315;
    assign signal_mux_317 = signal_eq_174 ? signal_const_296 : signal_reg_14;
    assign signal_mux_318 = read_done ? signal_mux_317 : signal_reg_14;
    assign signal_mux_319 = signal_not_174 ? signal_const_58 : signal_reg_14;
    assign signal_mux_320 = signal_eq_177 ? signal_const_296 : signal_reg_14;
    assign signal_mux_321 = is_jump ? signal_mux_320 : signal_reg_14;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_28 <= signal_mux_321;
        4'b0101:
            signal_cases_28 <= signal_mux_319;
        4'b0110:
            signal_cases_28 <= signal_mux_318;
        4'b0111:
            signal_cases_28 <= signal_mux_316;
        4'b1001:
            signal_cases_28 <= signal_mux_312;
        default:
            signal_cases_28 <= signal_reg_14;
        endcase
    end
    assign signal_wire_26 = signal_cases_28;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_14 <= signal_const_58;
        else
            signal_reg_14 <= signal_wire_26;
    end
    assign signal_mux_322 = stored ? signal_reg_15 : signal_const_58;
    assign signal_mux_323 = falls_to_next ? signal_reg_14 : signal_mux_322;
    assign signal_mux_324 = signal_wire_66 ? signal_const_296 : signal_reg_15;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_29 <= signal_mux_324;
        4'b1011:
            signal_cases_29 <= signal_mux_323;
        4'b1100:
            signal_cases_29 <= signal_reg_14;
        default:
            signal_cases_29 <= signal_reg_15;
        endcase
    end
    assign signal_wire_27 = signal_cases_29;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_15 <= signal_const_58;
        else
            signal_reg_15 <= signal_wire_27;
    end
    assign signal_lt_79 = signal_reg_15 < signal_reg_17;
    assign signal_mux_325 = signal_lt_79 ? signal_reg_15 : signal_reg_17;
    assign signal_eq_127 = signal_select_159 == signal_const_191;
    assign signal_and_144 = signal_eq_142 & signal_eq_127;
    assign signal_mux_326 = signal_and_144 ? signal_mux_325 : signal_reg_17;
    assign signal_eq_128 = signal_select_159 == signal_const_192;
    assign signal_and_145 = signal_eq_142 & signal_eq_128;
    assign signal_mux_327 = signal_and_145 ? signal_const_296 : signal_mux_326;
    assign signal_select_155 = word[7:5];
    assign signal_eq_129 = signal_select_155 == signal_const_96;
    assign signal_eq_130 = signal_select_184 == signal_const_97;
    assign signal_and_146 = signal_eq_130 & signal_eq_129;
    assign signal_mux_328 = signal_and_146 ? signal_cat_182 : signal_mux_327;
    assign signal_eq_131 = signal_select_178 == signal_const_87;
    assign signal_eq_132 = signal_select_184 == signal_const_99;
    assign signal_and_147 = signal_eq_132 & signal_eq_131;
    assign signal_eq_133 = signal_select_179 == signal_const_96;
    assign signal_eq_134 = signal_select_184 == signal_const_101;
    assign signal_and_148 = signal_eq_134 & signal_eq_133;
    assign signal_eq_135 = signal_select_182 == signal_const_96;
    assign signal_eq_136 = signal_select_184 == signal_const_103;
    assign signal_and_149 = signal_eq_136 & signal_eq_135;
    assign signal_or_72 = signal_and_149 | signal_and_148;
    assign signal_or_73 = signal_or_72 | signal_and_147;
    assign signal_not_149 = ~ signal_or_73;
    assign signal_mux_329 = signal_not_149 ? signal_mux_328 : signal_const_296;
    assign signal_mux_330 = signal_and_206 ? signal_mux_329 : signal_const_58;
    assign signal_mux_331 = stored ? signal_reg_16 : signal_mux_330;
    assign signal_mux_332 = signal_eq_175 ? signal_const_296 : signal_reg_16;
    assign signal_mux_333 = falls_to_next ? signal_mux_331 : signal_mux_332;
    assign signal_select_156 = shifted[15:0];
    always @* begin
        case (field)
        3'b100:
            signal_cases_30 <= signal_select_156;
        default:
            signal_cases_30 <= signal_reg_16;
        endcase
    end
    assign signal_mux_334 = last_word ? signal_cases_30 : signal_reg_16;
    assign signal_mux_335 = read_done ? signal_mux_334 : signal_reg_16;
    assign signal_mux_336 = signal_eq_172 ? signal_reg_16 : signal_mux_335;
    assign signal_mux_337 = signal_eq_173 ? signal_reg_16 : signal_mux_336;
    assign signal_mux_338 = signal_eq_174 ? signal_const_296 : signal_reg_16;
    assign signal_mux_339 = read_done ? signal_mux_338 : signal_reg_16;
    assign signal_mux_340 = signal_not_174 ? signal_const_58 : signal_reg_16;
    assign signal_mux_341 = signal_eq_177 ? signal_const_296 : signal_reg_16;
    assign signal_mux_342 = is_jump ? signal_mux_341 : signal_reg_16;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_31 <= signal_mux_342;
        4'b0101:
            signal_cases_31 <= signal_mux_340;
        4'b0110:
            signal_cases_31 <= signal_mux_339;
        4'b0111:
            signal_cases_31 <= signal_mux_337;
        4'b1001:
            signal_cases_31 <= signal_mux_333;
        default:
            signal_cases_31 <= signal_reg_16;
        endcase
    end
    assign signal_wire_28 = signal_cases_31;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_16 <= signal_const_58;
        else
            signal_reg_16 <= signal_wire_28;
    end
    assign signal_mux_343 = stored ? signal_reg_17 : signal_const_58;
    assign signal_mux_344 = falls_to_next ? signal_reg_16 : signal_mux_343;
    assign signal_mux_345 = signal_wire_66 ? signal_const_296 : signal_reg_17;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_32 <= signal_mux_345;
        4'b1011:
            signal_cases_32 <= signal_mux_344;
        4'b1100:
            signal_cases_32 <= signal_reg_16;
        default:
            signal_cases_32 <= signal_reg_17;
        endcase
    end
    assign signal_wire_29 = signal_cases_32;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_17 <= signal_const_58;
        else
            signal_reg_17 <= signal_wire_29;
    end
    assign signal_cat_183 = { signal_const_28,
                              signal_reg_17 };
    assign signal_cat_184 = { signal_const_151,
                              signal_select_175 };
    assign signal_cat_185 = { signal_const_35,
                              signal_cat_184 };
    assign signal_sub_20 = signal_const_75 - signal_cat_185;
    assign signal_mux_346 = signal_and_182 ? signal_sub_20 : signal_const_75;
    assign signal_mux_347 = signal_and_193 ? signal_cat_185 : signal_mux_346;
    assign signal_eq_137 = signal_select_175 == signal_const_89;
    assign signal_and_150 = signal_and_194 & signal_eq_158;
    assign signal_and_151 = signal_and_150 & signal_select_176;
    assign signal_and_152 = signal_and_151 & signal_eq_137;
    assign signal_mux_348 = signal_and_152 ? signal_cat_183 : signal_mux_347;
    assign signal_eq_138 = signal_select_175 == signal_const_156;
    assign signal_and_153 = signal_and_194 & signal_eq_158;
    assign signal_and_154 = signal_and_153 & signal_select_176;
    assign signal_and_155 = signal_and_154 & signal_eq_138;
    assign signal_mux_349 = signal_and_155 ? signal_cat_181 : signal_mux_348;
    assign signal_eq_139 = signal_select_175 == signal_const_96;
    assign signal_and_156 = signal_and_194 & signal_eq_158;
    assign signal_and_157 = signal_and_156 & signal_select_176;
    assign signal_and_158 = signal_and_157 & signal_eq_139;
    assign signal_and_159 = signal_and_201 & signal_select_171;
    assign signal_or_74 = signal_and_159 | signal_and_158;
    assign signal_mux_350 = signal_or_74 ? signal_add_27 : signal_mux_349;
    assign signal_cat_186 = { signal_const_35,
                              signal_mux_361 };
    assign signal_sub_21 = signal_cat_186 - signal_mux_350;
    assign signal_select_157 = signal_cat_195[24:0];
    assign signal_select_158 = signal_cat_195[25:25];
    assign signal_not_150 = ~ signal_select_158;
    assign signal_cat_187 = { signal_not_150,
                              signal_select_157 };
    assign signal_lt_80 = signal_cat_187 < signal_const_76;
    assign signal_mux_351 = signal_lt_80 ? signal_const_75 : signal_cat_195;
    assign signal_mux_352 = signal_and_201 ? signal_mux_351 : signal_cat_195;
    assign signal_mux_353 = signal_and_180 ? signal_const_129 : signal_mux_352;
    assign signal_mux_354 = signal_and_198 ? signal_const_75 : signal_mux_353;
    assign signal_add_28 = signal_mux_354 + signal_sub_21;
    assign signal_select_159 = word[12:9];
    assign signal_eq_140 = signal_select_159 == signal_const_193;
    assign signal_and_160 = signal_eq_142 & signal_eq_140;
    assign signal_mux_355 = signal_and_160 ? signal_add_26 : signal_add_28;
    assign signal_select_160 = signal_mux_355[25:25];
    assign signal_not_151 = ~ signal_select_160;
    assign signal_cat_188 = { signal_not_151,
                              signal_select_146 };
    assign signal_lt_81 = signal_cat_188 < signal_const_70;
    assign signal_not_152 = ~ signal_lt_81;
    assign signal_eq_141 = signal_reg_19 == signal_const_56;
    assign signal_select_161 = signal_sub_22[24:0];
    assign signal_select_162 = signal_reg_29[23:23];
    assign signal_cat_189 = { signal_select_162,
                              signal_select_162 };
    assign signal_cat_190 = { signal_cat_189,
                              signal_reg_29 };
    assign signal_sub_22 = signal_const_75 - signal_cat_190;
    assign signal_select_163 = signal_sub_22[25:25];
    assign signal_not_153 = ~ signal_select_163;
    assign signal_cat_191 = { signal_not_153,
                              signal_select_161 };
    assign signal_lt_82 = signal_cat_191 < signal_const_76;
    assign signal_mux_356 = signal_lt_82 ? signal_const_75 : signal_sub_22;
    assign signal_cat_192 = { signal_const_35,
                              signal_reg_21 };
    assign signal_add_29 = signal_cat_192 + signal_mux_356;
    assign signal_add_30 = signal_add_29 + signal_cat_199;
    assign signal_cat_193 = { signal_const_35,
                              signal_reg_21 };
    assign signal_add_31 = signal_cat_193 + signal_cat_199;
    assign signal_mux_357 = signal_and_201 ? signal_add_30 : signal_add_31;
    assign signal_mux_358 = signal_and_176 ? signal_cat_199 : signal_mux_357;
    assign signal_select_164 = signal_mux_358[23:0];
    assign signal_select_165 = signal_sub_23[24:0];
    assign signal_select_166 = signal_reg_27[23:23];
    assign signal_cat_194 = { signal_select_166,
                              signal_select_166 };
    assign signal_cat_195 = { signal_cat_194,
                              signal_reg_27 };
    assign signal_sub_23 = signal_const_75 - signal_cat_195;
    assign signal_select_167 = signal_sub_23[25:25];
    assign signal_not_154 = ~ signal_select_167;
    assign signal_cat_196 = { signal_not_154,
                              signal_select_165 };
    assign signal_lt_83 = signal_cat_196 < signal_const_76;
    assign signal_mux_359 = signal_lt_83 ? signal_const_75 : signal_sub_23;
    assign signal_cat_197 = { signal_const_35,
                              signal_reg_19 };
    assign signal_add_32 = signal_cat_197 + signal_mux_359;
    assign signal_add_33 = signal_add_32 + signal_cat_199;
    assign signal_and_161 = signal_select_168 & signal_const_9;
    assign signal_and_162 = signal_select_168 & signal_const_9;
    assign signal_and_163 = signal_select_168 & signal_const_19;
    assign signal_select_168 = word[12:8];
    assign signal_wire_30 = config$side_set_count;
    always @* begin
        case (signal_wire_30)
        0:
            signal_mux_360 <= signal_select_168;
        1:
            signal_mux_360 <= signal_and_163;
        2:
            signal_mux_360 <= signal_and_162;
        default:
            signal_mux_360 <= signal_and_161;
        endcase
    end
    assign signal_cat_198 = { signal_const_163,
                              signal_mux_360 };
    assign signal_add_34 = signal_cat_198 + signal_const_159;
    assign signal_eq_142 = signal_select_184 == signal_const_156;
    assign signal_mux_361 = signal_eq_142 ? signal_const_158 : signal_add_34;
    assign signal_cat_199 = { signal_const_35,
                              signal_mux_361 };
    assign signal_select_169 = signal_mux_380[23:0];
    assign signal_mux_362 = signal_or_75 ? signal_select_169 : signal_const_56;
    assign signal_mux_363 = signal_and_206 ? signal_mux_362 : signal_const_57;
    assign signal_mux_364 = stored ? signal_reg_18 : signal_mux_363;
    assign signal_mux_365 = signal_eq_175 ? signal_const_56 : signal_reg_18;
    assign signal_mux_366 = falls_to_next ? signal_mux_364 : signal_mux_365;
    always @* begin
        case (field)
        3'b001:
            signal_cases_33 <= signal_select_190;
        default:
            signal_cases_33 <= signal_reg_18;
        endcase
    end
    assign signal_mux_367 = last_word ? signal_cases_33 : signal_reg_18;
    assign signal_mux_368 = read_done ? signal_mux_367 : signal_reg_18;
    assign signal_mux_369 = signal_eq_172 ? signal_reg_18 : signal_mux_368;
    assign signal_mux_370 = signal_eq_173 ? signal_reg_18 : signal_mux_369;
    assign signal_mux_371 = signal_eq_174 ? signal_const_56 : signal_reg_18;
    assign signal_mux_372 = read_done ? signal_mux_371 : signal_reg_18;
    assign signal_mux_373 = signal_not_174 ? signal_const_57 : signal_reg_18;
    assign signal_mux_374 = signal_eq_177 ? signal_const_56 : signal_reg_18;
    assign signal_mux_375 = is_jump ? signal_mux_374 : signal_reg_18;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_34 <= signal_mux_375;
        4'b0101:
            signal_cases_34 <= signal_mux_373;
        4'b0110:
            signal_cases_34 <= signal_mux_372;
        4'b0111:
            signal_cases_34 <= signal_mux_370;
        4'b1001:
            signal_cases_34 <= signal_mux_366;
        default:
            signal_cases_34 <= signal_reg_18;
        endcase
    end
    assign signal_wire_31 = signal_cases_34;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_18 <= signal_const_57;
        else
            signal_reg_18 <= signal_wire_31;
    end
    assign signal_mux_376 = stored ? signal_reg_19 : signal_const_57;
    assign signal_mux_377 = falls_to_next ? signal_reg_18 : signal_mux_376;
    assign signal_mux_378 = signal_wire_66 ? signal_const_56 : signal_reg_19;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_35 <= signal_mux_378;
        4'b1011:
            signal_cases_35 <= signal_mux_377;
        4'b1100:
            signal_cases_35 <= signal_reg_18;
        default:
            signal_cases_35 <= signal_reg_19;
        endcase
    end
    assign signal_wire_32 = signal_cases_35;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_19 <= signal_const_57;
        else
            signal_reg_19 <= signal_wire_32;
    end
    assign signal_cat_200 = { signal_const_35,
                              signal_reg_19 };
    assign signal_add_35 = signal_cat_200 + signal_cat_199;
    assign signal_mux_379 = signal_and_201 ? signal_add_33 : signal_add_35;
    assign signal_mux_380 = signal_and_176 ? signal_cat_199 : signal_mux_379;
    assign signal_lt_84 = signal_mux_380 < signal_const_80;
    assign signal_not_155 = ~ signal_and_174;
    assign signal_not_156 = ~ signal_and_201;
    assign signal_eq_143 = signal_select_184 == signal_const_89;
    assign signal_and_164 = signal_eq_143 & signal_not_156;
    assign signal_and_165 = signal_and_164 & signal_not_155;
    assign signal_not_157 = ~ signal_and_165;
    assign signal_and_166 = signal_not_158 & signal_not_157;
    assign signal_and_167 = signal_and_166 & signal_lt_84;
    assign signal_or_75 = signal_and_176 | signal_and_167;
    assign signal_mux_381 = signal_or_75 ? signal_select_164 : signal_const_57;
    assign signal_mux_382 = signal_and_206 ? signal_mux_381 : signal_const_57;
    assign signal_mux_383 = stored ? signal_reg_20 : signal_mux_382;
    assign signal_mux_384 = signal_eq_175 ? signal_const_57 : signal_reg_20;
    assign signal_mux_385 = falls_to_next ? signal_mux_383 : signal_mux_384;
    always @* begin
        case (field)
        3'b001:
            signal_cases_36 <= signal_select_185;
        default:
            signal_cases_36 <= signal_reg_20;
        endcase
    end
    assign signal_mux_386 = last_word ? signal_cases_36 : signal_reg_20;
    assign signal_mux_387 = read_done ? signal_mux_386 : signal_reg_20;
    assign signal_mux_388 = signal_eq_172 ? signal_reg_20 : signal_mux_387;
    assign signal_mux_389 = signal_eq_173 ? signal_reg_20 : signal_mux_388;
    assign signal_mux_390 = signal_eq_174 ? signal_const_57 : signal_reg_20;
    assign signal_mux_391 = read_done ? signal_mux_390 : signal_reg_20;
    assign signal_mux_392 = signal_not_174 ? signal_const_57 : signal_reg_20;
    assign signal_mux_393 = signal_eq_177 ? signal_const_57 : signal_reg_20;
    assign signal_mux_394 = is_jump ? signal_mux_393 : signal_reg_20;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_37 <= signal_mux_394;
        4'b0101:
            signal_cases_37 <= signal_mux_392;
        4'b0110:
            signal_cases_37 <= signal_mux_391;
        4'b0111:
            signal_cases_37 <= signal_mux_389;
        4'b1001:
            signal_cases_37 <= signal_mux_385;
        default:
            signal_cases_37 <= signal_reg_20;
        endcase
    end
    assign signal_wire_33 = signal_cases_37;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_20 <= signal_const_57;
        else
            signal_reg_20 <= signal_wire_33;
    end
    assign signal_mux_395 = stored ? signal_reg_21 : signal_const_57;
    assign signal_mux_396 = falls_to_next ? signal_reg_20 : signal_mux_395;
    assign signal_mux_397 = signal_wire_66 ? signal_const_57 : signal_reg_21;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_38 <= signal_mux_397;
        4'b1011:
            signal_cases_38 <= signal_mux_396;
        4'b1100:
            signal_cases_38 <= signal_reg_20;
        default:
            signal_cases_38 <= signal_reg_21;
        endcase
    end
    assign signal_wire_34 = signal_cases_38;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_21 <= signal_const_57;
        else
            signal_reg_21 <= signal_wire_34;
    end
    assign signal_eq_144 = signal_reg_21 == signal_const_57;
    assign signal_and_168 = signal_eq_144 & signal_eq_141;
    assign signal_not_158 = ~ signal_and_168;
    assign signal_not_159 = ~ signal_and_173;
    assign signal_and_169 = signal_reg_23 & signal_not_159;
    assign signal_mux_398 = signal_and_176 ? vdd : signal_and_169;
    assign signal_mux_399 = signal_and_206 ? signal_mux_398 : signal_const_30;
    assign signal_mux_400 = stored ? signal_reg_22 : signal_mux_399;
    assign signal_mux_401 = signal_eq_175 ? signal_const_30 : signal_reg_22;
    assign signal_mux_402 = falls_to_next ? signal_mux_400 : signal_mux_401;
    assign signal_select_170 = entry_shifted[37:37];
    assign signal_mux_403 = signal_eq_174 ? signal_select_170 : signal_reg_22;
    assign signal_mux_404 = read_done ? signal_mux_403 : signal_reg_22;
    assign signal_mux_405 = signal_not_174 ? signal_const_30 : signal_reg_22;
    assign signal_mux_406 = signal_eq_177 ? signal_const_30 : signal_reg_22;
    assign signal_mux_407 = is_jump ? signal_mux_406 : signal_reg_22;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_39 <= signal_mux_407;
        4'b0101:
            signal_cases_39 <= signal_mux_405;
        4'b0110:
            signal_cases_39 <= signal_mux_404;
        4'b1001:
            signal_cases_39 <= signal_mux_402;
        default:
            signal_cases_39 <= signal_reg_22;
        endcase
    end
    assign signal_wire_35 = signal_cases_39;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_22 <= signal_const_30;
        else
            signal_reg_22 <= signal_wire_35;
    end
    assign signal_mux_408 = stored ? signal_reg_23 : signal_const_30;
    assign signal_mux_409 = falls_to_next ? signal_reg_22 : signal_mux_408;
    assign signal_mux_410 = signal_wire_66 ? signal_const_30 : signal_reg_23;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_40 <= signal_mux_410;
        4'b1011:
            signal_cases_40 <= signal_mux_409;
        4'b1100:
            signal_cases_40 <= signal_reg_22;
        default:
            signal_cases_40 <= signal_reg_23;
        endcase
    end
    assign signal_wire_36 = signal_cases_40;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_23 <= signal_const_30;
        else
            signal_reg_23 <= signal_wire_36;
    end
    assign signal_wire_37 = config$capture_rising;
    assign signal_select_171 = word[7:7];
    assign signal_eq_145 = signal_select_171 == signal_wire_37;
    assign signal_wire_38 = config$capture_pin;
    assign signal_select_172 = word[4:0];
    assign signal_eq_146 = signal_select_172 == signal_wire_38;
    assign signal_wire_39 = setup$single_edge;
    assign signal_eq_147 = signal_select_183 == signal_const_87;
    assign signal_eq_148 = signal_select_183 == signal_const_35;
    assign signal_or_76 = signal_eq_148 | signal_eq_147;
    assign signal_eq_149 = signal_select_184 == signal_const_89;
    assign signal_and_170 = signal_eq_149 & signal_or_76;
    assign signal_and_171 = signal_and_170 & signal_wire_39;
    assign signal_and_172 = signal_and_171 & signal_eq_146;
    assign signal_and_173 = signal_and_172 & signal_eq_145;
    assign signal_and_174 = signal_and_173 & signal_reg_23;
    assign signal_and_175 = signal_and_174 & signal_not_158;
    assign signal_or_77 = signal_reg_25 | signal_and_175;
    assign signal_select_173 = word[3:0];
    assign signal_eq_150 = signal_select_173 == signal_const_91;
    assign signal_eq_151 = signal_select_184 == signal_const_92;
    assign signal_and_176 = signal_eq_151 & signal_eq_150;
    assign signal_mux_411 = signal_and_176 ? gnd : signal_or_77;
    assign signal_mux_412 = signal_and_206 ? signal_mux_411 : signal_const_30;
    assign signal_mux_413 = stored ? signal_reg_24 : signal_mux_412;
    assign signal_mux_414 = signal_eq_175 ? signal_const_30 : signal_reg_24;
    assign signal_mux_415 = falls_to_next ? signal_mux_413 : signal_mux_414;
    assign signal_select_174 = entry_shifted[38:38];
    assign signal_mux_416 = signal_eq_174 ? signal_select_174 : signal_reg_24;
    assign signal_mux_417 = read_done ? signal_mux_416 : signal_reg_24;
    assign signal_mux_418 = signal_not_174 ? signal_const_30 : signal_reg_24;
    assign signal_mux_419 = signal_eq_177 ? signal_const_30 : signal_reg_24;
    assign signal_mux_420 = is_jump ? signal_mux_419 : signal_reg_24;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_41 <= signal_mux_420;
        4'b0101:
            signal_cases_41 <= signal_mux_418;
        4'b0110:
            signal_cases_41 <= signal_mux_417;
        4'b1001:
            signal_cases_41 <= signal_mux_415;
        default:
            signal_cases_41 <= signal_reg_24;
        endcase
    end
    assign signal_wire_40 = signal_cases_41;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_24 <= signal_const_30;
        else
            signal_reg_24 <= signal_wire_40;
    end
    assign signal_mux_421 = stored ? signal_reg_25 : signal_const_30;
    assign signal_mux_422 = falls_to_next ? signal_reg_24 : signal_mux_421;
    assign signal_mux_423 = signal_wire_66 ? signal_const_30 : signal_reg_25;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_42 <= signal_mux_423;
        4'b1011:
            signal_cases_42 <= signal_mux_422;
        4'b1100:
            signal_cases_42 <= signal_reg_24;
        default:
            signal_cases_42 <= signal_reg_25;
        endcase
    end
    assign signal_wire_41 = signal_cases_42;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_25 <= signal_const_30;
        else
            signal_reg_25 <= signal_wire_41;
    end
    assign signal_eq_152 = signal_select_180 == signal_const_92;
    assign signal_eq_153 = signal_select_181 == signal_const_35;
    assign signal_and_177 = signal_and_199 & signal_eq_153;
    assign signal_and_178 = signal_and_177 & signal_eq_152;
    assign signal_and_179 = signal_and_178 & signal_reg_25;
    assign signal_and_180 = signal_and_179 & signal_not_158;
    assign signal_not_160 = ~ signal_select_176;
    assign signal_eq_154 = signal_select_177 == signal_const_87;
    assign signal_and_181 = signal_and_194 & signal_eq_154;
    assign signal_and_182 = signal_and_181 & signal_not_160;
    assign signal_eq_155 = signal_select_175 == signal_const_89;
    assign signal_and_183 = signal_and_194 & signal_eq_158;
    assign signal_and_184 = signal_and_183 & signal_select_176;
    assign signal_and_185 = signal_and_184 & signal_eq_155;
    assign signal_eq_156 = signal_select_175 == signal_const_156;
    assign signal_and_186 = signal_and_194 & signal_eq_158;
    assign signal_and_187 = signal_and_186 & signal_select_176;
    assign signal_and_188 = signal_and_187 & signal_eq_156;
    assign signal_select_175 = word[2:0];
    assign signal_eq_157 = signal_select_175 == signal_const_96;
    assign signal_and_189 = signal_and_194 & signal_eq_158;
    assign signal_and_190 = signal_and_189 & signal_select_176;
    assign signal_and_191 = signal_and_190 & signal_eq_157;
    assign signal_select_176 = word[3:3];
    assign signal_not_161 = ~ signal_select_176;
    assign signal_select_177 = word[5:4];
    assign signal_eq_158 = signal_select_177 == signal_const_35;
    assign signal_and_192 = signal_and_194 & signal_eq_158;
    assign signal_and_193 = signal_and_192 & signal_not_161;
    assign signal_or_78 = signal_and_193 | signal_and_191;
    assign signal_or_79 = signal_or_78 | signal_and_188;
    assign signal_or_80 = signal_or_79 | signal_and_185;
    assign signal_or_81 = signal_or_80 | signal_and_182;
    assign signal_not_162 = ~ signal_or_81;
    assign signal_select_178 = word[7:6];
    assign signal_eq_159 = signal_select_178 == signal_const_33;
    assign signal_eq_160 = signal_select_184 == signal_const_99;
    assign signal_and_194 = signal_eq_160 & signal_eq_159;
    assign signal_and_195 = signal_and_194 & signal_not_162;
    assign signal_select_179 = word[7:5];
    assign signal_eq_161 = signal_select_179 == signal_const_92;
    assign signal_eq_162 = signal_select_184 == signal_const_101;
    assign signal_and_196 = signal_eq_162 & signal_eq_161;
    assign signal_select_180 = word[2:0];
    assign signal_eq_163 = signal_select_180 == signal_const_99;
    assign signal_select_181 = word[4:3];
    assign signal_eq_164 = signal_select_181 == signal_const_35;
    assign signal_and_197 = signal_and_199 & signal_eq_164;
    assign signal_and_198 = signal_and_197 & signal_eq_163;
    assign signal_not_163 = ~ signal_and_198;
    assign signal_select_182 = word[7:5];
    assign signal_eq_165 = signal_select_182 == signal_const_92;
    assign signal_eq_166 = signal_select_184 == signal_const_103;
    assign signal_and_199 = signal_eq_166 & signal_eq_165;
    assign signal_and_200 = signal_and_199 & signal_not_163;
    assign signal_select_183 = word[6:5];
    assign signal_eq_167 = signal_select_183 == signal_const_108;
    assign signal_eq_168 = signal_select_184 == signal_const_89;
    assign signal_and_201 = signal_eq_168 & signal_eq_167;
    assign signal_not_164 = ~ signal_and_201;
    assign signal_select_184 = word[15:13];
    assign signal_eq_169 = signal_select_184 == signal_const_89;
    assign signal_and_202 = signal_eq_169 & signal_not_164;
    assign signal_or_82 = signal_and_202 | signal_and_200;
    assign signal_or_83 = signal_or_82 | signal_and_196;
    assign signal_or_84 = signal_or_83 | signal_and_195;
    assign signal_not_165 = ~ signal_or_84;
    assign signal_or_85 = signal_not_165 | signal_and_180;
    assign signal_and_203 = signal_or_85 & signal_not_152;
    assign signal_and_204 = signal_and_203 & signal_not_141;
    assign signal_mux_424 = signal_and_204 ? signal_select_133 : signal_const_196;
    assign signal_mux_425 = signal_and_206 ? signal_mux_424 : signal_const_159;
    assign signal_mux_426 = stored ? signal_reg_26 : signal_mux_425;
    assign signal_mux_427 = signal_eq_175 ? signal_const_196 : signal_reg_26;
    assign signal_mux_428 = falls_to_next ? signal_mux_426 : signal_mux_427;
    assign signal_select_185 = shifted[47:24];
    always @* begin
        case (field)
        3'b000:
            signal_cases_43 <= signal_select_185;
        default:
            signal_cases_43 <= signal_reg_26;
        endcase
    end
    assign signal_mux_429 = last_word ? signal_cases_43 : signal_reg_26;
    assign signal_mux_430 = read_done ? signal_mux_429 : signal_reg_26;
    assign signal_mux_431 = signal_eq_172 ? signal_reg_26 : signal_mux_430;
    assign signal_mux_432 = signal_eq_173 ? signal_reg_26 : signal_mux_431;
    assign signal_mux_433 = signal_eq_174 ? signal_const_196 : signal_reg_26;
    assign signal_mux_434 = read_done ? signal_mux_433 : signal_reg_26;
    assign signal_mux_435 = signal_not_174 ? signal_const_159 : signal_reg_26;
    assign signal_mux_436 = signal_eq_177 ? signal_const_196 : signal_reg_26;
    assign signal_mux_437 = is_jump ? signal_mux_436 : signal_reg_26;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_44 <= signal_mux_437;
        4'b0101:
            signal_cases_44 <= signal_mux_435;
        4'b0110:
            signal_cases_44 <= signal_mux_434;
        4'b0111:
            signal_cases_44 <= signal_mux_432;
        4'b1001:
            signal_cases_44 <= signal_mux_428;
        default:
            signal_cases_44 <= signal_reg_26;
        endcase
    end
    assign signal_wire_42 = signal_cases_44;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_26 <= signal_const_57;
        else
            signal_reg_26 <= signal_wire_42;
    end
    assign signal_mux_438 = stored ? signal_reg_27 : signal_const_159;
    assign signal_mux_439 = falls_to_next ? signal_reg_26 : signal_mux_438;
    assign signal_mux_440 = signal_wire_66 ? signal_const_196 : signal_reg_27;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_45 <= signal_mux_440;
        4'b1011:
            signal_cases_45 <= signal_mux_439;
        4'b1100:
            signal_cases_45 <= signal_reg_26;
        default:
            signal_cases_45 <= signal_reg_27;
        endcase
    end
    assign signal_wire_43 = signal_cases_45;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_27 <= signal_const_57;
        else
            signal_reg_27 <= signal_wire_43;
    end
    assign signal_select_186 = signal_reg_27[23:23];
    assign signal_not_166 = ~ signal_select_186;
    assign signal_cat_201 = { signal_not_166,
                              signal_select_132 };
    assign signal_select_187 = signal_reg_29[22:0];
    assign signal_select_188 = signal_reg_29[23:23];
    assign signal_not_167 = ~ signal_select_188;
    assign signal_cat_202 = { signal_not_167,
                              signal_select_187 };
    assign signal_lt_85 = signal_cat_202 < signal_cat_201;
    assign signal_or_86 = signal_lt_85 | signal_lt_71;
    assign signal_or_87 = signal_or_86 | signal_lt_70;
    assign signal_or_88 = signal_or_87 | signal_lt_69;
    assign signal_or_89 = signal_or_88 | signal_lt_68;
    assign signal_not_168 = ~ signal_or_89;
    assign signal_and_205 = signal_not_168 & signal_not_135;
    assign signal_and_206 = signal_and_205 & signal_or_64;
    assign signal_mux_441 = signal_and_206 ? signal_mux_177 : signal_const_57;
    assign signal_mux_442 = stored ? signal_reg_28 : signal_mux_441;
    assign signal_mux_443 = signal_eq_175 ? signal_const_216 : signal_reg_28;
    assign signal_mux_444 = falls_to_next ? signal_mux_442 : signal_mux_443;
    assign signal_const_409 = 48'b000000000000000000000000000000000000000000000000;
    assign signal_mux_445 = read_done ? shifted : acc;
    assign signal_mux_446 = signal_eq_172 ? acc : signal_mux_445;
    assign signal_mux_447 = signal_eq_173 ? acc : signal_mux_446;
    always @* begin
        case (sm)
        4'b0111:
            signal_cases_46 <= signal_mux_447;
        default:
            signal_cases_46 <= acc;
        endcase
    end
    assign signal_wire_44 = signal_cases_46;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            acc <= signal_const_409;
        else
            acc <= signal_wire_44;
    end
    assign signal_select_189 = acc[31:0];
    assign shifted = { signal_select_189,
                       signal_wire_61 };
    assign signal_select_190 = shifted[23:0];
    always @* begin
        case (field)
        3'b000:
            signal_cases_47 <= signal_select_190;
        default:
            signal_cases_47 <= signal_reg_28;
        endcase
    end
    assign signal_mux_448 = last_word ? signal_cases_47 : signal_reg_28;
    assign signal_mux_449 = read_done ? signal_mux_448 : signal_reg_28;
    assign signal_mux_450 = signal_eq_172 ? signal_reg_28 : signal_mux_449;
    assign signal_mux_451 = signal_eq_173 ? signal_reg_28 : signal_mux_450;
    assign signal_mux_452 = signal_eq_174 ? signal_const_216 : signal_reg_28;
    assign signal_mux_453 = read_done ? signal_mux_452 : signal_reg_28;
    assign signal_mux_454 = signal_not_174 ? signal_const_57 : signal_reg_28;
    assign signal_mux_455 = signal_eq_177 ? signal_const_216 : signal_reg_28;
    assign signal_mux_456 = is_jump ? signal_mux_455 : signal_reg_28;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_48 <= signal_mux_456;
        4'b0101:
            signal_cases_48 <= signal_mux_454;
        4'b0110:
            signal_cases_48 <= signal_mux_453;
        4'b0111:
            signal_cases_48 <= signal_mux_451;
        4'b1001:
            signal_cases_48 <= signal_mux_444;
        default:
            signal_cases_48 <= signal_reg_28;
        endcase
    end
    assign signal_wire_45 = signal_cases_48;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_28 <= signal_const_57;
        else
            signal_reg_28 <= signal_wire_45;
    end
    assign signal_mux_457 = stored ? signal_reg_29 : signal_const_57;
    assign signal_mux_458 = falls_to_next ? signal_reg_28 : signal_mux_457;
    assign signal_mux_459 = signal_wire_66 ? signal_const_216 : signal_reg_29;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_49 <= signal_mux_459;
        4'b1011:
            signal_cases_49 <= signal_mux_458;
        4'b1100:
            signal_cases_49 <= signal_reg_28;
        default:
            signal_cases_49 <= signal_reg_29;
        endcase
    end
    assign signal_wire_46 = signal_cases_49;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            signal_reg_29 <= signal_const_57;
        else
            signal_reg_29 <= signal_wire_46;
    end
    assign signal_select_191 = signal_reg_29[23:23];
    assign signal_not_169 = ~ signal_select_191;
    assign signal_cat_203 = { signal_not_169,
                              signal_select_126 };
    assign signal_lt_86 = signal_cat_203 < signal_cat_161;
    assign signal_or_90 = signal_lt_86 | signal_lt_55;
    assign signal_or_91 = signal_or_90 | signal_lt_54;
    assign signal_or_92 = signal_or_91 | signal_lt_53;
    assign signal_or_93 = signal_or_92 | signal_lt_52;
    assign signal_not_170 = ~ signal_or_93;
    assign signal_and_207 = signal_not_170 & signal_not_126;
    assign signal_not_171 = ~ signal_and_207;
    assign signal_or_94 = signal_not_171 | signal_not_121;
    assign signal_or_95 = signal_or_94 | signal_not_120;
    assign signal_and_208 = signal_or_95 & signal_or_61;
    assign signal_and_209 = signal_and_208 & signal_or_48;
    assign signal_and_210 = signal_and_209 & signal_or_43;
    assign signal_and_211 = signal_and_210 & signal_or_40;
    assign signal_and_212 = signal_and_211 & signal_or_39;
    assign signal_and_213 = signal_and_212 & signal_or_36;
    assign signal_and_214 = signal_and_213 & signal_or_32;
    assign signal_and_215 = signal_and_214 & signal_or_29;
    assign next_fails = ~ signal_and_215;
    assign signal_mux_460 = next_fails ? signal_const_51 : signal_mux_96;
    assign signal_mux_461 = stored ? signal_const_446 : signal_const_413;
    assign signal_mux_462 = signal_eq_175 ? signal_const_413 : signal_const_461;
    assign signal_mux_463 = falls_to_next ? signal_mux_461 : signal_mux_462;
    always @* begin
        case (purpose)
        2'b00:
            signal_cases_50 <= signal_const_419;
        2'b01:
            signal_cases_50 <= signal_const_413;
        2'b10:
            signal_cases_50 <= signal_const_413;
        2'b11:
            signal_cases_50 <= signal_const_213;
        default:
            signal_cases_50 <= sm;
        endcase
    end
    assign signal_mux_464 = signal_eq_173 ? signal_cases_50 : sm;
    assign signal_mux_465 = signal_eq_174 ? signal_const_91 : sm;
    assign signal_mux_466 = read_done ? signal_mux_465 : sm;
    assign signal_const_413 = 4'b1010;
    assign signal_mux_467 = stored ? signal_const_33 : purpose;
    assign signal_mux_468 = falls_to_next ? purpose : signal_mux_467;
    assign signal_mux_469 = stored ? signal_const_108 : purpose;
    assign signal_mux_470 = falls_to_next ? signal_mux_469 : signal_const_87;
    assign signal_mux_471 = is_jump ? signal_const_35 : purpose;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_51 <= signal_mux_471;
        4'b1001:
            signal_cases_51 <= signal_mux_470;
        4'b1011:
            signal_cases_51 <= signal_mux_468;
        default:
            signal_cases_51 <= purpose;
        endcase
    end
    assign signal_wire_47 = signal_cases_51;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            purpose <= signal_const_35;
        else
            purpose <= signal_wire_47;
    end
    always @* begin
        case (purpose)
        2'b00:
            signal_cases_52 <= signal_const_419;
        2'b01:
            signal_cases_52 <= signal_const_413;
        2'b10:
            signal_cases_52 <= signal_const_413;
        2'b11:
            signal_cases_52 <= signal_const_213;
        default:
            signal_cases_52 <= sm;
        endcase
    end
    assign signal_const_446 = 4'b0110;
    assign signal_mux_472 = signal_eq_176 ? signal_const_446 : sm;
    assign signal_mux_473 = read_done ? signal_mux_472 : sm;
    assign signal_mux_474 = signal_not_174 ? signal_cases_52 : signal_mux_473;
    assign signal_const_419 = 4'b1000;
    assign signal_const_461 = 4'b0101;
    assign signal_mux_475 = signal_eq_177 ? signal_const_419 : signal_const_461;
    assign signal_mux_476 = is_jump ? signal_mux_475 : signal_const_201;
    assign signal_lt_87 = pc < entry_tag;
    assign signal_not_172 = ~ signal_lt_87;
    assign signal_mux_477 = signal_not_172 ? signal_const_51 : signal_const_460;
    assign signal_mux_478 = read_done ? signal_mux_477 : sm;
    assign signal_const_460 = 4'b0100;
    assign signal_mux_479 = signal_lt_90 ? signal_mux_478 : signal_const_460;
    assign signal_mux_480 = signal_eq_178 ? signal_const_191 : sm;
    assign signal_mux_481 = signal_eq_179 ? signal_const_192 : sm;
    assign signal_add_36 = \wait  + signal_const_87;
    assign signal_not_173 = ~ read_done;
    assign signal_mux_482 = signal_eq_172 ? gnd : vdd;
    assign signal_mux_483 = signal_eq_173 ? gnd : signal_mux_482;
    assign signal_mux_484 = signal_not_174 ? gnd : vdd;
    assign signal_select_192 = signal_wire_61[7:0];
    assign signal_mux_485 = signal_eq_181 ? k : signal_const_35;
    assign signal_mux_486 = signal_eq_181 ? k : signal_const_35;
    assign signal_mux_487 = signal_eq_181 ? k : signal_const_35;
    assign signal_mux_488 = stored ? signal_const_35 : signal_mux_487;
    assign signal_mux_489 = falls_to_next ? signal_mux_486 : signal_mux_488;
    assign signal_mux_490 = stored ? signal_const_35 : k;
    assign signal_mux_491 = falls_to_next ? signal_mux_490 : k;
    assign signal_add_37 = k + signal_const_87;
    assign signal_mux_492 = last_word ? signal_const_35 : signal_add_37;
    assign signal_mux_493 = read_done ? signal_mux_492 : k;
    assign signal_mux_494 = signal_eq_172 ? k : signal_mux_493;
    assign signal_add_38 = field + signal_const_89;
    assign signal_add_39 = field + signal_const_89;
    assign signal_eq_170 = k == signal_const_108;
    assign signal_eq_171 = k == signal_const_87;
    assign wide = field < signal_const_96;
    assign last_word = wide ? signal_eq_170 : signal_eq_171;
    assign signal_mux_495 = last_word ? signal_add_39 : field;
    assign signal_mux_496 = read_done ? signal_mux_495 : field;
    assign signal_select_193 = entry[8:2];
    assign signal_select_194 = entry[15:9];
    assign signal_select_195 = entry[22:16];
    assign signal_select_196 = entry[29:23];
    assign signal_select_197 = entry[31:0];
    assign entry_shifted = { signal_select_197,
                             signal_wire_61 };
    assign signal_mux_497 = read_done ? entry_shifted : entry;
    always @* begin
        case (sm)
        4'b0110:
            signal_cases_53 <= signal_mux_497;
        default:
            signal_cases_53 <= entry;
        endcase
    end
    assign signal_wire_48 = signal_cases_53;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            entry <= signal_const_409;
        else
            entry <= signal_wire_48;
    end
    assign signal_select_198 = entry[36:30];
    always @* begin
        case (field)
        0:
            index <= signal_select_198;
        1:
            index <= signal_select_196;
        2:
            index <= signal_select_195;
        3:
            index <= signal_select_194;
        default:
            index <= signal_select_193;
        endcase
    end
    assign signal_eq_172 = index == signal_const_32;
    assign signal_mux_498 = signal_eq_172 ? signal_add_38 : signal_mux_496;
    assign signal_mux_499 = signal_eq_173 ? field : signal_mux_498;
    assign signal_mux_500 = signal_eq_174 ? signal_const_156 : field;
    assign signal_mux_501 = read_done ? signal_mux_500 : field;
    always @* begin
        case (sm)
        4'b0110:
            signal_cases_54 <= signal_mux_501;
        4'b0111:
            signal_cases_54 <= signal_mux_499;
        default:
            signal_cases_54 <= field;
        endcase
    end
    assign signal_wire_49 = signal_cases_54;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            field <= signal_const_156;
        else
            field <= signal_wire_49;
    end
    assign signal_eq_173 = field == signal_const_97;
    assign signal_mux_502 = signal_eq_173 ? k : signal_mux_494;
    assign signal_add_40 = k + signal_const_87;
    assign signal_eq_174 = k == signal_const_108;
    assign signal_mux_503 = signal_eq_174 ? signal_const_35 : signal_add_40;
    assign signal_mux_504 = read_done ? signal_mux_503 : k;
    assign signal_mux_505 = signal_eq_176 ? signal_const_35 : k;
    assign signal_mux_506 = read_done ? signal_mux_505 : k;
    assign signal_mux_507 = signal_eq_175 ? lo : signal_const_40;
    assign signal_mux_508 = falls_to_next ? lo : signal_mux_507;
    assign signal_const_450 = 8'b00000001;
    assign signal_eq_175 = following == signal_const_49;
    assign signal_mux_509 = signal_eq_175 ? hi : count;
    assign signal_mux_510 = falls_to_next ? hi : signal_mux_509;
    assign signal_mux_511 = signal_lt_88 ? hi : mid;
    assign signal_mux_512 = signal_eq_176 ? hi : signal_mux_511;
    assign signal_mux_513 = read_done ? signal_mux_512 : hi;
    assign signal_mux_514 = signal_not_174 ? hi : signal_mux_513;
    assign signal_mux_515 = signal_eq_177 ? hi : count;
    assign signal_mux_516 = is_jump ? signal_mux_515 : hi;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_55 <= signal_mux_516;
        4'b0101:
            signal_cases_55 <= signal_mux_514;
        4'b1001:
            signal_cases_55 <= signal_mux_510;
        default:
            signal_cases_55 <= hi;
        endcase
    end
    assign signal_wire_50 = signal_cases_55;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            hi <= signal_const_40;
        else
            hi <= signal_wire_50;
    end
    assign signal_cat_204 = { gnd,
                              hi };
    assign signal_cat_205 = { gnd,
                              lo };
    assign signal_add_41 = signal_cat_205 + signal_cat_204;
    assign signal_select_199 = signal_add_41[8:1];
    assign signal_cat_206 = { signal_const_30,
                              signal_select_199 };
    assign mid = signal_cat_206[7:0];
    assign signal_add_42 = mid + signal_const_450;
    assign signal_lt_88 = entry_tag < key;
    assign signal_mux_517 = signal_lt_88 ? signal_add_42 : lo;
    assign signal_mux_518 = falls_to_next ? key : following;
    assign signal_mux_519 = is_jump ? jump_target : key;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_56 <= signal_mux_519;
        4'b1001:
            signal_cases_56 <= signal_mux_518;
        default:
            signal_cases_56 <= key;
        endcase
    end
    assign signal_wire_51 = signal_cases_56;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            key <= signal_const_49;
        else
            key <= signal_wire_51;
    end
    assign signal_eq_176 = entry_tag == key;
    assign signal_mux_520 = signal_eq_176 ? lo : signal_mux_517;
    assign signal_mux_521 = read_done ? signal_mux_520 : lo;
    assign signal_mux_522 = signal_not_174 ? lo : signal_mux_521;
    assign jump_target = word[8:0];
    assign signal_eq_177 = jump_target == signal_const_49;
    assign signal_mux_523 = signal_eq_177 ? lo : signal_const_40;
    assign signal_wire_52 = program_word;
    assign signal_mux_524 = signal_eq_178 ? signal_wire_52 : word;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_57 <= signal_mux_524;
        default:
            signal_cases_57 <= word;
        endcase
    end
    assign signal_wire_53 = signal_cases_57;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            word <= signal_const_58;
        else
            word <= signal_wire_53;
    end
    assign signal_select_200 = word[15:13];
    assign is_jump = signal_select_200 == signal_const_156;
    assign signal_mux_525 = is_jump ? signal_mux_523 : lo;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_58 <= signal_mux_525;
        4'b0101:
            signal_cases_58 <= signal_mux_522;
        4'b1001:
            signal_cases_58 <= signal_mux_508;
        default:
            signal_cases_58 <= lo;
        endcase
    end
    assign signal_wire_54 = signal_cases_58;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            lo <= signal_const_40;
        else
            lo <= signal_wire_54;
    end
    assign signal_lt_89 = lo < hi;
    assign signal_not_174 = ~ signal_lt_89;
    assign signal_mux_526 = signal_not_174 ? k : signal_mux_506;
    assign signal_add_43 = k + signal_const_87;
    assign signal_eq_178 = k == signal_const_87;
    assign signal_mux_527 = signal_eq_178 ? signal_const_35 : signal_add_43;
    assign signal_add_44 = k + signal_const_87;
    assign signal_eq_179 = k == signal_const_87;
    assign signal_mux_528 = signal_eq_179 ? signal_const_35 : signal_add_44;
    assign signal_mux_529 = read_done ? signal_mux_528 : k;
    assign signal_mux_530 = signal_wire_66 ? signal_const_35 : k;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_59 <= signal_mux_530;
        4'b0001:
            signal_cases_59 <= signal_mux_529;
        4'b0010:
            signal_cases_59 <= signal_mux_527;
        4'b0101:
            signal_cases_59 <= signal_mux_526;
        4'b0110:
            signal_cases_59 <= signal_mux_504;
        4'b0111:
            signal_cases_59 <= signal_mux_502;
        4'b1001:
            signal_cases_59 <= signal_mux_491;
        4'b1011:
            signal_cases_59 <= signal_mux_489;
        4'b1100:
            signal_cases_59 <= signal_mux_485;
        default:
            signal_cases_59 <= k;
        endcase
    end
    assign signal_wire_55 = signal_cases_59;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            k <= signal_const_35;
        else
            k <= signal_wire_55;
    end
    assign signal_eq_180 = k == signal_const_35;
    assign signal_mux_531 = signal_eq_180 ? signal_select_192 : count;
    assign signal_mux_532 = read_done ? signal_mux_531 : count;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_60 <= signal_mux_532;
        default:
            signal_cases_60 <= count;
        endcase
    end
    assign signal_wire_56 = signal_cases_60;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            count <= signal_const_40;
        else
            count <= signal_wire_56;
    end
    assign signal_cat_207 = { signal_const_32,
                              stored };
    assign signal_add_45 = ptr + signal_cat_207;
    assign signal_mux_533 = stored ? ptr : signal_add_45;
    assign signal_wire_57 = config$wrap_bottom;
    assign signal_const_471 = 9'b000000001;
    assign signal_add_46 = pc + signal_const_471;
    assign signal_wire_58 = config$wrap_top;
    assign signal_mux_534 = signal_eq_181 ? pc : signal_select_201;
    assign signal_mux_535 = signal_eq_181 ? pc : signal_select_201;
    assign signal_select_201 = next_pc[8:0];
    assign signal_const_474 = 9'b111111111;
    assign signal_eq_181 = pc == signal_const_474;
    assign signal_mux_536 = signal_eq_181 ? pc : signal_select_201;
    assign signal_wire_59 = clear;
    assign signal_wire_60 = clock;
    assign signal_const_476 = 10'b0000000001;
    assign signal_cat_208 = { gnd,
                              pc };
    assign next_pc = signal_cat_208 + signal_const_476;
    assign signal_wire_61 = data_word;
    assign entry_tag = signal_wire_61[15:7];
    assign signal_cat_209 = { gnd,
                              entry_tag };
    assign signal_eq_182 = signal_cat_209 == next_pc;
    assign signal_mux_537 = read_done ? signal_eq_182 : stored;
    assign signal_mux_538 = signal_lt_90 ? signal_mux_537 : gnd;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_61 <= signal_mux_538;
        default:
            signal_cases_61 <= stored;
        endcase
    end
    assign signal_wire_62 = signal_cases_61;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            stored <= signal_const_30;
        else
            stored <= signal_wire_62;
    end
    assign signal_mux_539 = stored ? pc : signal_mux_536;
    assign signal_mux_540 = falls_to_next ? signal_mux_535 : signal_mux_539;
    assign signal_mux_541 = signal_wire_66 ? signal_const_49 : pc;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_62 <= signal_mux_541;
        4'b1011:
            signal_cases_62 <= signal_mux_540;
        4'b1100:
            signal_cases_62 <= signal_mux_534;
        default:
            signal_cases_62 <= pc;
        endcase
    end
    assign signal_wire_63 = signal_cases_62;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            pc <= signal_const_49;
        else
            pc <= signal_wire_63;
    end
    assign signal_eq_183 = pc == signal_wire_58;
    assign following = signal_eq_183 ? signal_wire_57 : signal_add_46;
    assign gnd = 1'b0;
    assign signal_cat_210 = { gnd,
                              following };
    assign falls_to_next = signal_cat_210 == next_pc;
    assign signal_mux_542 = falls_to_next ? signal_add_45 : signal_mux_533;
    assign signal_mux_543 = signal_wire_66 ? signal_const_40 : ptr;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_63 <= signal_mux_543;
        4'b1011:
            signal_cases_63 <= signal_mux_542;
        4'b1100:
            signal_cases_63 <= signal_add_45;
        default:
            signal_cases_63 <= ptr;
        endcase
    end
    assign signal_wire_64 = signal_cases_63;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            ptr <= signal_const_40;
        else
            ptr <= signal_wire_64;
    end
    assign signal_lt_90 = ptr < count;
    assign signal_mux_544 = signal_lt_90 ? vdd : gnd;
    assign vdd = 1'b1;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_64 <= vdd;
        4'b0011:
            signal_cases_64 <= signal_mux_544;
        4'b0101:
            signal_cases_64 <= signal_mux_484;
        4'b0110:
            signal_cases_64 <= vdd;
        4'b0111:
            signal_cases_64 <= signal_mux_483;
        default:
            signal_cases_64 <= gnd;
        endcase
    end
    assign reading = signal_cases_64;
    assign signal_and_216 = reading & signal_not_173;
    assign signal_mux_545 = signal_and_216 ? signal_add_36 : signal_const_35;
    assign signal_wire_65 = signal_mux_545;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            \wait  <= signal_const_35;
        else
            \wait  <= signal_wire_65;
    end
    assign read_done = \wait  == signal_const_108;
    assign signal_mux_546 = read_done ? signal_mux_481 : sm;
    assign signal_wire_66 = check;
    assign signal_mux_547 = signal_wire_66 ? signal_const_193 : sm;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_65 <= signal_mux_547;
        4'b0001:
            signal_cases_65 <= signal_mux_546;
        4'b0010:
            signal_cases_65 <= signal_mux_480;
        4'b0011:
            signal_cases_65 <= signal_mux_479;
        4'b0100:
            signal_cases_65 <= signal_mux_476;
        4'b0101:
            signal_cases_65 <= signal_mux_474;
        4'b0110:
            signal_cases_65 <= signal_mux_466;
        4'b0111:
            signal_cases_65 <= signal_mux_464;
        4'b1000:
            signal_cases_65 <= signal_const_201;
        4'b1001:
            signal_cases_65 <= signal_mux_463;
        4'b1010:
            signal_cases_65 <= signal_mux_460;
        4'b1011:
            signal_cases_65 <= signal_mux_66;
        4'b1100:
            signal_cases_65 <= signal_mux_62;
        4'b1101:
            signal_cases_65 <= signal_mux_61;
        default:
            signal_cases_65 <= sm;
        endcase
    end
    assign signal_eq_184 = signal_const_51 == sm;
    assign signal_not_175 = ~ signal_eq_184;
    assign signal_wire_67 = abort;
    assign signal_and_217 = signal_wire_67 & signal_not_175;
    assign signal_mux_548 = signal_and_217 ? signal_const_51 : signal_cases_65;
    assign signal_wire_68 = signal_mux_548;
    always @(posedge signal_wire_60) begin
        if (signal_wire_59)
            sm <= signal_const_51;
        else
            sm <= signal_wire_68;
    end
    assign signal_eq_185 = signal_const_192 == sm;
    assign program_read$valid = signal_eq_185;
    assign program_read$value = pc;
    assign data_read$valid = reading;
    assign data_read$value = data_addr;
    assign busy = signal_not_17;
    assign finished = finished_0;
    assign accepted = accepted_0;
    assign reject_pc = reject_pc_0;
    assign reason = reason_0;

endmodule
module data_memory (
    clock,
    clear,
    halted_0,
    halted_1,
    writes$valid_0,
    writes$addr_0,
    writes$data_0,
    writes$valid_1,
    writes$addr_1,
    writes$data_1,
    reads_0,
    reads_1,
    words_0,
    words_1
);

    input clock;
    input clear;
    input halted_0;
    input halted_1;
    input writes$valid_0;
    input [8:0] writes$addr_0;
    input [15:0] writes$data_0;
    input writes$valid_1;
    input [8:0] writes$addr_1;
    input [15:0] writes$data_1;
    input [8:0] reads_0;
    input [8:0] reads_1;
    output [15:0] words_0;
    output [15:0] words_1;

    wire [15:0] signal_const;
    reg [15:0] last;
    wire signal_const_1;
    wire signal_not;
    wire signal_const_2;
    wire signal_eq;
    wire signal_and;
    reg mine;
    wire [15:0] signal_mux;
    wire [15:0] signal_const_4;
    wire [15:0] signal_wire;
    wire [15:0] signal_wire_1;
    wire [15:0] signal_mux_1;
    wire signal_or;
    wire [15:0] signal_mux_2;
    wire [8:0] signal_wire_2;
    wire [8:0] signal_wire_3;
    wire [8:0] signal_mux_3;
    wire [8:0] signal_const_6;
    wire signal_or_1;
    wire [8:0] signal_mux_4;
    wire [8:0] signal_wire_4;
    wire [8:0] signal_wire_5;
    wire [8:0] read_addr;
    wire [8:0] signal_mux_5;
    wire vdd;
    wire [15:0] signal_inst;
    wire [15:0] signal_wire_6;
    reg [15:0] last_1;
    wire signal_wire_7;
    wire signal_wire_8;
    wire signal_or_2;
    wire signal_wire_9;
    wire signal_wire_10;
    wire writes_open;
    wire write;
    wire signal_not_1;
    wire signal_wire_11;
    wire signal_wire_12;
    wire signal_not_2;
    reg signal_reg;
    wire turn;
    wire signal_eq_1;
    wire signal_and_1;
    reg mine_1;
    wire [15:0] signal_mux_6;
    assign signal_const = 16'b0000000000000000;
    always @(posedge signal_wire_12) begin
        if (signal_wire_11)
            last <= signal_const;
        else
            if (mine)
                last <= signal_wire_6;
    end
    assign signal_const_1 = 1'b0;
    assign signal_not = ~ write;
    assign signal_const_2 = 1'b1;
    assign signal_eq = turn == signal_const_2;
    assign signal_and = signal_eq & signal_not;
    always @(posedge signal_wire_12) begin
        if (signal_wire_11)
            mine <= signal_const_1;
        else
            mine <= signal_and;
    end
    assign signal_mux = mine ? signal_wire_6 : last;
    assign signal_const_4 = 16'b1111111111111111;
    assign signal_wire = writes$data_0;
    assign signal_wire_1 = writes$data_1;
    assign signal_mux_1 = signal_wire_8 ? signal_wire : signal_wire_1;
    assign signal_or = signal_wire_8 | signal_wire_7;
    assign signal_mux_2 = signal_or ? signal_mux_1 : signal_const;
    assign signal_wire_2 = writes$addr_0;
    assign signal_wire_3 = writes$addr_1;
    assign signal_mux_3 = signal_wire_8 ? signal_wire_2 : signal_wire_3;
    assign signal_const_6 = 9'b000000000;
    assign signal_or_1 = signal_wire_8 | signal_wire_7;
    assign signal_mux_4 = signal_or_1 ? signal_mux_3 : signal_const_6;
    assign signal_wire_4 = reads_1;
    assign signal_wire_5 = reads_0;
    assign read_addr = turn ? signal_wire_4 : signal_wire_5;
    assign signal_mux_5 = write ? signal_mux_4 : read_addr;
    assign vdd = 1'b1;
    sram_macro
        sram_macro
        ( .clock(signal_wire_12),
          .men(vdd),
          .wen(write),
          .ren(vdd),
          .addr(signal_mux_5),
          .din(signal_mux_2),
          .bm(signal_const_4),
          .dout(signal_inst[15:0]) );
    assign signal_wire_6 = signal_inst;
    always @(posedge signal_wire_12) begin
        if (signal_wire_11)
            last_1 <= signal_const;
        else
            if (mine_1)
                last_1 <= signal_wire_6;
    end
    assign signal_wire_7 = writes$valid_1;
    assign signal_wire_8 = writes$valid_0;
    assign signal_or_2 = signal_wire_8 | signal_wire_7;
    assign signal_wire_9 = halted_1;
    assign signal_wire_10 = halted_0;
    assign writes_open = signal_wire_10 & signal_wire_9;
    assign write = writes_open & signal_or_2;
    assign signal_not_1 = ~ write;
    assign signal_wire_11 = clear;
    assign signal_wire_12 = clock;
    assign signal_not_2 = ~ turn;
    always @(posedge signal_wire_12) begin
        if (signal_wire_11)
            signal_reg <= signal_const_1;
        else
            signal_reg <= signal_not_2;
    end
    assign turn = signal_reg;
    assign signal_eq_1 = turn == signal_const_1;
    assign signal_and_1 = signal_eq_1 & signal_not_1;
    always @(posedge signal_wire_12) begin
        if (signal_wire_11)
            mine_1 <= signal_const_1;
        else
            mine_1 <= signal_and_1;
    end
    assign signal_mux_6 = mine_1 ? signal_wire_6 : last_1;
    assign words_0 = signal_mux_6;
    assign words_1 = signal_mux;

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
    hosts$config$autopull_data_0,
    hosts$config$manchester_0,
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
    hosts$check_0,
    hosts$config_written_0,
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
    hosts$config$autopull_data_1,
    hosts$config$manchester_1,
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
    hosts$check_1,
    hosts$config_written_1,
    pads,
    check_setup$base,
    check_setup$loaded$valid,
    check_setup$loaded$value,
    check_setup$single_edge,
    engines$pin_out_0,
    engines$pin_dir_0,
    engines$pc_0,
    engines$data_ptr_0,
    engines$data_addr_0,
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
    engines$program_word_0,
    engines$decode_ok_0,
    engines$opcode_onehot_0,
    engines$wait_select_0,
    engines$crc_0,
    engines$stuff_run_0,
    engines$flip_pending_0,
    engines$flip_bit_0,
    engines$pin_out_1,
    engines$pin_dir_1,
    engines$pc_1,
    engines$data_ptr_1,
    engines$data_addr_1,
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
    engines$program_word_1,
    engines$decode_ok_1,
    engines$opcode_onehot_1,
    engines$wait_select_1,
    engines$crc_1,
    engines$stuff_run_1,
    engines$flip_pending_1,
    engines$flip_bit_1,
    pin_out,
    pin_dir,
    check$verdict$busy,
    check$verdict$accepted,
    check$verdict$reject_pc,
    check$verdict$reason,
    check$certified_0,
    check$certified_1,
    check$refused_0,
    check$refused_1
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
    input hosts$config$autopull_data_0;
    input hosts$config$manchester_0;
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
    input hosts$check_0;
    input hosts$config_written_0;
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
    input hosts$config$autopull_data_1;
    input hosts$config$manchester_1;
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
    input hosts$check_1;
    input hosts$config_written_1;
    input [19:0] pads;
    input [8:0] check_setup$base;
    input check_setup$loaded$valid;
    input [15:0] check_setup$loaded$value;
    input check_setup$single_edge;
    output [27:0] engines$pin_out_0;
    output [27:0] engines$pin_dir_0;
    output [8:0] engines$pc_0;
    output [8:0] engines$data_ptr_0;
    output [8:0] engines$data_addr_0;
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
    output [15:0] engines$program_word_0;
    output engines$decode_ok_0;
    output [7:0] engines$opcode_onehot_0;
    output [27:0] engines$wait_select_0;
    output [15:0] engines$crc_0;
    output [4:0] engines$stuff_run_0;
    output engines$flip_pending_0;
    output engines$flip_bit_0;
    output [27:0] engines$pin_out_1;
    output [27:0] engines$pin_dir_1;
    output [8:0] engines$pc_1;
    output [8:0] engines$data_ptr_1;
    output [8:0] engines$data_addr_1;
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
    output [15:0] engines$program_word_1;
    output engines$decode_ok_1;
    output [7:0] engines$opcode_onehot_1;
    output [27:0] engines$wait_select_1;
    output [15:0] engines$crc_1;
    output [4:0] engines$stuff_run_1;
    output engines$flip_pending_1;
    output engines$flip_bit_1;
    output [19:0] pin_out;
    output [19:0] pin_dir;
    output check$verdict$busy;
    output check$verdict$accepted;
    output [9:0] check$verdict$reject_pc;
    output [4:0] check$verdict$reason;
    output check$certified_0;
    output check$certified_1;
    output check$refused_0;
    output check$refused_1;

    wire signal_const;
    wire signal_not;
    wire signal_and;
    wire signal_mux;
    wire signal_mux_1;
    wire signal_wire;
    reg refused;
    wire signal_not_1;
    wire signal_and_1;
    wire signal_mux_2;
    wire signal_mux_3;
    wire signal_wire_1;
    reg refused_1;
    wire [4:0] signal_select;
    wire [4:0] signal_wire_2;
    wire [9:0] signal_select_1;
    wire [9:0] signal_wire_3;
    wire [27:0] signal_or;
    wire [19:0] signal_select_2;
    wire [27:0] signal_or_1;
    wire [27:0] signal_and_2;
    wire [27:0] signal_const_2;
    wire [27:0] signal_or_2;
    wire [27:0] signal_and_3;
    wire [27:0] signal_or_3;
    wire [19:0] signal_select_3;
    wire signal_select_4;
    wire signal_wire_4;
    wire signal_select_5;
    wire signal_wire_5;
    wire [4:0] signal_select_6;
    wire [4:0] signal_wire_6;
    wire [15:0] signal_select_7;
    wire [15:0] signal_wire_7;
    wire [27:0] signal_select_8;
    wire [27:0] signal_wire_8;
    wire [7:0] signal_select_9;
    wire [7:0] signal_wire_9;
    wire signal_select_10;
    wire signal_wire_10;
    wire [15:0] signal_select_11;
    wire [15:0] signal_wire_11;
    wire [15:0] signal_select_12;
    wire [15:0] signal_wire_12;
    wire [3:0] signal_select_13;
    wire [3:0] signal_wire_13;
    wire [3:0] signal_select_14;
    wire [3:0] signal_wire_14;
    wire signal_select_15;
    wire signal_wire_15;
    wire [23:0] signal_select_16;
    wire [23:0] signal_wire_16;
    wire signal_select_17;
    wire signal_wire_17;
    wire signal_select_18;
    wire signal_wire_18;
    wire signal_select_19;
    wire signal_wire_19;
    wire signal_select_20;
    wire signal_wire_20;
    wire signal_select_21;
    wire signal_wire_21;
    wire [4:0] signal_select_22;
    wire [4:0] signal_wire_22;
    wire [23:0] signal_select_23;
    wire [23:0] signal_wire_23;
    wire [4:0] signal_select_24;
    wire [4:0] signal_wire_24;
    wire [15:0] signal_select_25;
    wire [15:0] signal_wire_25;
    wire [4:0] signal_select_26;
    wire [4:0] signal_wire_26;
    wire [15:0] signal_select_27;
    wire [15:0] signal_wire_27;
    wire [15:0] signal_select_28;
    wire [15:0] signal_wire_28;
    wire [23:0] signal_select_29;
    wire [23:0] signal_wire_29;
    wire [15:0] signal_select_30;
    wire [15:0] signal_wire_30;
    wire [15:0] signal_select_31;
    wire [15:0] signal_wire_31;
    wire [15:0] signal_select_32;
    wire [15:0] signal_wire_32;
    wire [8:0] signal_select_33;
    wire [8:0] signal_wire_33;
    wire [8:0] signal_select_34;
    wire [8:0] signal_wire_34;
    wire signal_select_35;
    wire signal_wire_35;
    wire signal_select_36;
    wire signal_wire_36;
    wire [4:0] signal_select_37;
    wire [4:0] signal_wire_37;
    wire [15:0] signal_select_38;
    wire [15:0] signal_wire_38;
    wire [27:0] signal_select_39;
    wire [27:0] signal_wire_39;
    wire [7:0] signal_select_40;
    wire [7:0] signal_wire_40;
    wire signal_select_41;
    wire signal_wire_41;
    wire [15:0] signal_select_42;
    wire [15:0] signal_wire_42;
    wire [15:0] signal_select_43;
    wire [15:0] signal_wire_43;
    wire [3:0] signal_select_44;
    wire [3:0] signal_wire_44;
    wire [3:0] signal_select_45;
    wire [3:0] signal_wire_45;
    wire signal_select_46;
    wire signal_wire_46;
    wire [23:0] signal_select_47;
    wire [23:0] signal_wire_47;
    wire signal_select_48;
    wire signal_wire_48;
    wire signal_select_49;
    wire signal_wire_49;
    wire signal_select_50;
    wire signal_wire_50;
    wire signal_select_51;
    wire signal_wire_51;
    wire signal_select_52;
    wire signal_wire_52;
    wire [4:0] signal_select_53;
    wire [4:0] signal_wire_53;
    wire [23:0] signal_select_54;
    wire [23:0] signal_wire_54;
    wire [4:0] signal_select_55;
    wire [4:0] signal_wire_55;
    wire [15:0] signal_select_56;
    wire [15:0] signal_wire_56;
    wire [4:0] signal_select_57;
    wire [4:0] signal_wire_57;
    wire [15:0] signal_select_58;
    wire [15:0] signal_wire_58;
    wire [15:0] signal_select_59;
    wire [15:0] signal_wire_59;
    wire [23:0] signal_select_60;
    wire [23:0] signal_wire_60;
    wire [15:0] signal_select_61;
    wire [15:0] signal_wire_61;
    wire [15:0] signal_select_62;
    wire [15:0] signal_wire_62;
    wire [15:0] signal_select_63;
    wire [15:0] signal_wire_63;
    wire [8:0] signal_select_64;
    wire [8:0] signal_wire_64;
    wire [8:0] signal_select_65;
    wire [8:0] signal_wire_65;
    wire [27:0] signal_const_3;
    wire [27:0] signal_or_4;
    wire [27:0] signal_select_66;
    wire [27:0] signal_wire_66;
    wire [27:0] signal_and_4;
    wire [27:0] signal_select_67;
    wire [27:0] signal_wire_67;
    wire [27:0] signal_not_2;
    wire [7:0] signal_const_4;
    wire [27:0] signal_cat;
    wire [27:0] signal_and_5;
    wire [27:0] signal_or_5;
    wire signal_wire_68;
    wire signal_wire_69;
    wire signal_wire_70;
    wire signal_wire_71;
    wire [15:0] signal_wire_72;
    wire signal_wire_73;
    wire signal_eq;
    wire signal_and_6;
    wire signal_and_7;
    wire [15:0] signal_wire_74;
    wire [8:0] signal_wire_75;
    wire signal_eq_1;
    wire signal_and_8;
    wire signal_mux_4;
    wire signal_eq_2;
    wire signal_or_6;
    wire [15:0] signal_select_68;
    wire [15:0] signal_mux_5;
    wire [15:0] signal_select_69;
    wire [15:0] signal_wire_76;
    wire [15:0] signal_select_70;
    wire [15:0] signal_wire_77;
    wire [15:0] signal_mux_6;
    wire signal_wire_78;
    wire [15:0] signal_wire_79;
    wire signal_wire_80;
    wire [8:0] signal_wire_81;
    wire signal_mux_7;
    wire signal_mux_8;
    wire [15:0] signal_mux_9;
    wire [8:0] signal_mux_10;
    wire [8:0] signal_mux_11;
    wire signal_mux_12;
    wire [4:0] signal_mux_13;
    wire signal_mux_14;
    wire [15:0] signal_mux_15;
    wire [15:0] signal_mux_16;
    wire [4:0] signal_mux_17;
    wire [4:0] signal_mux_18;
    wire signal_mux_19;
    wire [4:0] signal_mux_20;
    wire signal_mux_21;
    wire signal_mux_22;
    wire signal_mux_23;
    wire signal_mux_24;
    wire [4:0] signal_mux_25;
    wire [4:0] signal_mux_26;
    wire [2:0] signal_mux_27;
    wire [4:0] signal_mux_28;
    wire [4:0] signal_mux_29;
    wire [4:0] signal_mux_30;
    wire [4:0] signal_mux_31;
    wire [4:0] signal_mux_32;
    wire signal_mux_33;
    wire [4:0] signal_mux_34;
    wire [1:0] signal_mux_35;
    wire signal_or_7;
    wire signal_or_8;
    wire signal_const_11;
    wire signal_mux_36;
    wire [27:0] signal_or_9;
    wire [27:0] signal_and_9;
    wire [27:0] signal_select_71;
    wire [27:0] signal_wire_82;
    wire [27:0] signal_not_3;
    wire [19:0] signal_wire_83;
    wire [27:0] signal_cat_1;
    wire [27:0] signal_and_10;
    wire [27:0] signal_or_10;
    wire signal_wire_84;
    wire signal_wire_85;
    wire signal_wire_86;
    wire signal_wire_87;
    wire [15:0] signal_wire_88;
    wire signal_wire_89;
    wire [8:0] signal_select_72;
    wire [8:0] signal_wire_90;
    wire signal_eq_3;
    wire signal_and_11;
    wire signal_and_12;
    wire [8:0] signal_mux_37;
    wire [8:0] signal_select_73;
    wire [8:0] signal_wire_91;
    wire [8:0] signal_select_74;
    wire [8:0] signal_wire_92;
    wire signal_select_75;
    wire signal_wire_93;
    wire signal_eq_4;
    wire signal_and_13;
    wire signal_and_14;
    wire [8:0] signal_mux_38;
    wire [15:0] signal_wire_94;
    wire [8:0] signal_wire_95;
    wire [15:0] signal_wire_96;
    wire [8:0] signal_wire_97;
    wire [31:0] signal_inst;
    wire [15:0] signal_select_76;
    wire [8:0] signal_select_77;
    wire [8:0] signal_wire_98;
    wire signal_select_78;
    wire signal_wire_99;
    wire signal_eq_5;
    wire signal_and_15;
    wire signal_and_16;
    wire [15:0] signal_wire_100;
    wire [8:0] signal_wire_101;
    wire gnd;
    wire vdd;
    wire signal_eq_6;
    wire signal_select_79;
    wire signal_wire_102;
    wire signal_select_80;
    wire signal_wire_103;
    wire accepts;
    wire signal_and_17;
    wire signal_mux_39;
    wire signal_eq_7;
    wire signal_and_18;
    wire signal_wire_104;
    wire signal_wire_105;
    wire signal_or_11;
    wire signal_or_12;
    wire signal_mux_40;
    wire signal_wire_106;
    reg certified;
    wire signal_wire_107;
    wire signal_and_19;
    wire signal_wire_108;
    wire signal_wire_109;
    wire [15:0] signal_wire_110;
    wire [8:0] signal_wire_111;
    wire [8:0] signal_wire_112;
    wire signal_wire_113;
    wire [4:0] signal_wire_114;
    wire signal_wire_115;
    wire [15:0] signal_wire_116;
    wire [15:0] signal_wire_117;
    wire [4:0] signal_wire_118;
    wire [4:0] signal_wire_119;
    wire signal_wire_120;
    wire [4:0] signal_wire_121;
    wire signal_wire_122;
    wire signal_wire_123;
    wire signal_wire_124;
    wire signal_wire_125;
    wire [4:0] signal_wire_126;
    wire [4:0] signal_wire_127;
    wire [2:0] signal_wire_128;
    wire [4:0] signal_wire_129;
    wire [4:0] signal_wire_130;
    wire [4:0] signal_wire_131;
    wire [4:0] signal_wire_132;
    wire [4:0] signal_wire_133;
    wire signal_wire_134;
    wire [4:0] signal_wire_135;
    wire [1:0] signal_wire_136;
    wire [388:0] signal_inst_1;
    wire signal_select_81;
    wire signal_wire_137;
    wire signal_wire_138;
    wire asks$1;
    wire signal_select_82;
    wire signal_wire_139;
    wire signal_wire_140;
    wire asks$0;
    wire signal_or_13;
    wire chosen;
    reg signal_reg;
    wire checked;
    wire signal_mux_41;
    wire signal_wire_141;
    wire signal_wire_142;
    wire signal_or_14;
    wire signal_or_15;
    wire abort;
    wire [37:0] signal_inst_2;
    wire signal_select_83;
    wire checking;
    wire signal_not_4;
    wire go;
    wire signal_and_20;
    wire signal_wire_143;
    wire signal_wire_144;
    wire signal_or_16;
    wire signal_or_17;
    wire signal_mux_42;
    wire signal_wire_145;
    reg certified_1;
    wire signal_wire_146;
    wire signal_and_21;
    wire signal_wire_147;
    wire signal_wire_148;
    wire [15:0] signal_wire_149;
    wire [8:0] signal_wire_150;
    wire [8:0] signal_wire_151;
    wire signal_wire_152;
    wire [4:0] signal_wire_153;
    wire signal_wire_154;
    wire [15:0] signal_wire_155;
    wire [15:0] signal_wire_156;
    wire [4:0] signal_wire_157;
    wire [4:0] signal_wire_158;
    wire signal_wire_159;
    wire [4:0] signal_wire_160;
    wire signal_wire_161;
    wire signal_wire_162;
    wire signal_wire_163;
    wire signal_wire_164;
    wire [4:0] signal_wire_165;
    wire [4:0] signal_wire_166;
    wire [2:0] signal_wire_167;
    wire [4:0] signal_wire_168;
    wire [4:0] signal_wire_169;
    wire [4:0] signal_wire_170;
    wire [4:0] signal_wire_171;
    wire [4:0] signal_wire_172;
    wire signal_wire_173;
    wire [4:0] signal_wire_174;
    wire [1:0] signal_wire_175;
    wire signal_wire_176;
    wire signal_wire_177;
    wire [388:0] signal_inst_3;
    wire [27:0] signal_select_84;
    wire [27:0] signal_wire_178;
    assign signal_const = 1'b0;
    assign signal_not = ~ certified;
    assign signal_and = signal_wire_107 & signal_not;
    assign signal_mux = signal_and ? vdd : refused;
    assign signal_mux_1 = signal_and_18 ? gnd : signal_mux;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_177) begin
        if (signal_wire_176)
            refused <= signal_const;
        else
            refused <= signal_wire;
    end
    assign signal_not_1 = ~ certified_1;
    assign signal_and_1 = signal_wire_146 & signal_not_1;
    assign signal_mux_2 = signal_and_1 ? vdd : refused_1;
    assign signal_mux_3 = signal_and_20 ? gnd : signal_mux_2;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_177) begin
        if (signal_wire_176)
            refused_1 <= signal_const;
        else
            refused_1 <= signal_wire_1;
    end
    assign signal_select = signal_inst_2[37:33];
    assign signal_wire_2 = signal_select;
    assign signal_select_1 = signal_inst_2[32:23];
    assign signal_wire_3 = signal_select_1;
    assign signal_or = signal_wire_82 | signal_wire_67;
    assign signal_select_2 = signal_or[19:0];
    assign signal_or_1 = signal_wire_67 | signal_const_2;
    assign signal_and_2 = signal_wire_66 & signal_or_1;
    assign signal_const_2 = 28'b0000000000000000111111111111;
    assign signal_or_2 = signal_wire_82 | signal_const_2;
    assign signal_and_3 = signal_wire_178 & signal_or_2;
    assign signal_or_3 = signal_and_3 | signal_and_2;
    assign signal_select_3 = signal_or_3[19:0];
    assign signal_select_4 = signal_inst_1[388:388];
    assign signal_wire_4 = signal_select_4;
    assign signal_select_5 = signal_inst_1[387:387];
    assign signal_wire_5 = signal_select_5;
    assign signal_select_6 = signal_inst_1[386:382];
    assign signal_wire_6 = signal_select_6;
    assign signal_select_7 = signal_inst_1[381:366];
    assign signal_wire_7 = signal_select_7;
    assign signal_select_8 = signal_inst_1[365:338];
    assign signal_wire_8 = signal_select_8;
    assign signal_select_9 = signal_inst_1[337:330];
    assign signal_wire_9 = signal_select_9;
    assign signal_select_10 = signal_inst_1[329:329];
    assign signal_wire_10 = signal_select_10;
    assign signal_select_11 = signal_inst_1[312:297];
    assign signal_wire_11 = signal_select_11;
    assign signal_select_12 = signal_inst_1[296:281];
    assign signal_wire_12 = signal_select_12;
    assign signal_select_13 = signal_inst_1[280:277];
    assign signal_wire_13 = signal_select_13;
    assign signal_select_14 = signal_inst_1[276:273];
    assign signal_wire_14 = signal_select_14;
    assign signal_select_15 = signal_inst_1[272:272];
    assign signal_wire_15 = signal_select_15;
    assign signal_select_16 = signal_inst_1[271:248];
    assign signal_wire_16 = signal_select_16;
    assign signal_select_17 = signal_inst_1[247:247];
    assign signal_wire_17 = signal_select_17;
    assign signal_select_18 = signal_inst_1[246:246];
    assign signal_wire_18 = signal_select_18;
    assign signal_select_19 = signal_inst_1[245:245];
    assign signal_wire_19 = signal_select_19;
    assign signal_select_20 = signal_inst_1[244:244];
    assign signal_wire_20 = signal_select_20;
    assign signal_select_21 = signal_inst_1[243:243];
    assign signal_wire_21 = signal_select_21;
    assign signal_select_22 = signal_inst_1[241:237];
    assign signal_wire_22 = signal_select_22;
    assign signal_select_23 = signal_inst_1[236:213];
    assign signal_wire_23 = signal_select_23;
    assign signal_select_24 = signal_inst_1[212:208];
    assign signal_wire_24 = signal_select_24;
    assign signal_select_25 = signal_inst_1[207:192];
    assign signal_wire_25 = signal_select_25;
    assign signal_select_26 = signal_inst_1[191:187];
    assign signal_wire_26 = signal_select_26;
    assign signal_select_27 = signal_inst_1[186:171];
    assign signal_wire_27 = signal_select_27;
    assign signal_select_28 = signal_inst_1[170:155];
    assign signal_wire_28 = signal_select_28;
    assign signal_select_29 = signal_inst_1[154:131];
    assign signal_wire_29 = signal_select_29;
    assign signal_select_30 = signal_inst_1[130:115];
    assign signal_wire_30 = signal_select_30;
    assign signal_select_31 = signal_inst_1[114:99];
    assign signal_wire_31 = signal_select_31;
    assign signal_select_32 = signal_inst_1[98:83];
    assign signal_wire_32 = signal_select_32;
    assign signal_select_33 = signal_inst_1[73:65];
    assign signal_wire_33 = signal_select_33;
    assign signal_select_34 = signal_inst_1[64:56];
    assign signal_wire_34 = signal_select_34;
    assign signal_select_35 = signal_inst_3[388:388];
    assign signal_wire_35 = signal_select_35;
    assign signal_select_36 = signal_inst_3[387:387];
    assign signal_wire_36 = signal_select_36;
    assign signal_select_37 = signal_inst_3[386:382];
    assign signal_wire_37 = signal_select_37;
    assign signal_select_38 = signal_inst_3[381:366];
    assign signal_wire_38 = signal_select_38;
    assign signal_select_39 = signal_inst_3[365:338];
    assign signal_wire_39 = signal_select_39;
    assign signal_select_40 = signal_inst_3[337:330];
    assign signal_wire_40 = signal_select_40;
    assign signal_select_41 = signal_inst_3[329:329];
    assign signal_wire_41 = signal_select_41;
    assign signal_select_42 = signal_inst_3[312:297];
    assign signal_wire_42 = signal_select_42;
    assign signal_select_43 = signal_inst_3[296:281];
    assign signal_wire_43 = signal_select_43;
    assign signal_select_44 = signal_inst_3[280:277];
    assign signal_wire_44 = signal_select_44;
    assign signal_select_45 = signal_inst_3[276:273];
    assign signal_wire_45 = signal_select_45;
    assign signal_select_46 = signal_inst_3[272:272];
    assign signal_wire_46 = signal_select_46;
    assign signal_select_47 = signal_inst_3[271:248];
    assign signal_wire_47 = signal_select_47;
    assign signal_select_48 = signal_inst_3[247:247];
    assign signal_wire_48 = signal_select_48;
    assign signal_select_49 = signal_inst_3[246:246];
    assign signal_wire_49 = signal_select_49;
    assign signal_select_50 = signal_inst_3[245:245];
    assign signal_wire_50 = signal_select_50;
    assign signal_select_51 = signal_inst_3[244:244];
    assign signal_wire_51 = signal_select_51;
    assign signal_select_52 = signal_inst_3[243:243];
    assign signal_wire_52 = signal_select_52;
    assign signal_select_53 = signal_inst_3[241:237];
    assign signal_wire_53 = signal_select_53;
    assign signal_select_54 = signal_inst_3[236:213];
    assign signal_wire_54 = signal_select_54;
    assign signal_select_55 = signal_inst_3[212:208];
    assign signal_wire_55 = signal_select_55;
    assign signal_select_56 = signal_inst_3[207:192];
    assign signal_wire_56 = signal_select_56;
    assign signal_select_57 = signal_inst_3[191:187];
    assign signal_wire_57 = signal_select_57;
    assign signal_select_58 = signal_inst_3[186:171];
    assign signal_wire_58 = signal_select_58;
    assign signal_select_59 = signal_inst_3[170:155];
    assign signal_wire_59 = signal_select_59;
    assign signal_select_60 = signal_inst_3[154:131];
    assign signal_wire_60 = signal_select_60;
    assign signal_select_61 = signal_inst_3[130:115];
    assign signal_wire_61 = signal_select_61;
    assign signal_select_62 = signal_inst_3[114:99];
    assign signal_wire_62 = signal_select_62;
    assign signal_select_63 = signal_inst_3[98:83];
    assign signal_wire_63 = signal_select_63;
    assign signal_select_64 = signal_inst_3[73:65];
    assign signal_wire_64 = signal_select_64;
    assign signal_select_65 = signal_inst_3[64:56];
    assign signal_wire_65 = signal_select_65;
    assign signal_const_3 = 28'b1111111100000000000000000000;
    assign signal_or_4 = signal_wire_67 | signal_const_3;
    assign signal_select_66 = signal_inst_1[27:0];
    assign signal_wire_66 = signal_select_66;
    assign signal_and_4 = signal_wire_66 & signal_or_4;
    assign signal_select_67 = signal_inst_1[55:28];
    assign signal_wire_67 = signal_select_67;
    assign signal_not_2 = ~ signal_wire_67;
    assign signal_const_4 = 8'b00000000;
    assign signal_cat = { signal_const_4,
                          signal_wire_83 };
    assign signal_and_5 = signal_cat & signal_not_2;
    assign signal_or_5 = signal_and_5 | signal_and_4;
    assign signal_wire_68 = hosts$flush_0;
    assign signal_wire_69 = hosts$stop_0;
    assign signal_wire_70 = hosts$clear_irq_0;
    assign signal_wire_71 = hosts$rx_pop_0;
    assign signal_wire_72 = hosts$tx$value_0;
    assign signal_wire_73 = hosts$tx$valid_0;
    assign signal_eq = checked == signal_const;
    assign signal_and_6 = checking & signal_eq;
    assign signal_and_7 = signal_and_6 & signal_wire_99;
    assign signal_wire_74 = hosts$program_write$data_0;
    assign signal_wire_75 = hosts$program_write$addr_0;
    assign signal_eq_1 = checked == signal_const;
    assign signal_and_8 = accepts & signal_eq_1;
    assign signal_mux_4 = signal_and_8 ? vdd : certified_1;
    assign signal_eq_2 = chosen == signal_const;
    assign signal_or_6 = asks$0 | asks$1;
    assign signal_select_68 = signal_inst[15:0];
    assign signal_mux_5 = checked ? signal_select_76 : signal_select_68;
    assign signal_select_69 = signal_inst_1[328:313];
    assign signal_wire_76 = signal_select_69;
    assign signal_select_70 = signal_inst_3[328:313];
    assign signal_wire_77 = signal_select_70;
    assign signal_mux_6 = checked ? signal_wire_76 : signal_wire_77;
    assign signal_wire_78 = check_setup$single_edge;
    assign signal_wire_79 = check_setup$loaded$value;
    assign signal_wire_80 = check_setup$loaded$valid;
    assign signal_wire_81 = check_setup$base;
    assign signal_mux_7 = checked ? signal_wire_108 : signal_wire_147;
    assign signal_mux_8 = checked ? signal_wire_109 : signal_wire_148;
    assign signal_mux_9 = checked ? signal_wire_110 : signal_wire_149;
    assign signal_mux_10 = checked ? signal_wire_111 : signal_wire_150;
    assign signal_mux_11 = checked ? signal_wire_112 : signal_wire_151;
    assign signal_mux_12 = checked ? signal_wire_113 : signal_wire_152;
    assign signal_mux_13 = checked ? signal_wire_114 : signal_wire_153;
    assign signal_mux_14 = checked ? signal_wire_115 : signal_wire_154;
    assign signal_mux_15 = checked ? signal_wire_116 : signal_wire_155;
    assign signal_mux_16 = checked ? signal_wire_117 : signal_wire_156;
    assign signal_mux_17 = checked ? signal_wire_118 : signal_wire_157;
    assign signal_mux_18 = checked ? signal_wire_119 : signal_wire_158;
    assign signal_mux_19 = checked ? signal_wire_120 : signal_wire_159;
    assign signal_mux_20 = checked ? signal_wire_121 : signal_wire_160;
    assign signal_mux_21 = checked ? signal_wire_122 : signal_wire_161;
    assign signal_mux_22 = checked ? signal_wire_123 : signal_wire_162;
    assign signal_mux_23 = checked ? signal_wire_124 : signal_wire_163;
    assign signal_mux_24 = checked ? signal_wire_125 : signal_wire_164;
    assign signal_mux_25 = checked ? signal_wire_126 : signal_wire_165;
    assign signal_mux_26 = checked ? signal_wire_127 : signal_wire_166;
    assign signal_mux_27 = checked ? signal_wire_128 : signal_wire_167;
    assign signal_mux_28 = checked ? signal_wire_129 : signal_wire_168;
    assign signal_mux_29 = checked ? signal_wire_130 : signal_wire_169;
    assign signal_mux_30 = checked ? signal_wire_131 : signal_wire_170;
    assign signal_mux_31 = checked ? signal_wire_132 : signal_wire_171;
    assign signal_mux_32 = checked ? signal_wire_133 : signal_wire_172;
    assign signal_mux_33 = checked ? signal_wire_134 : signal_wire_173;
    assign signal_mux_34 = checked ? signal_wire_135 : signal_wire_174;
    assign signal_mux_35 = checked ? signal_wire_136 : signal_wire_175;
    assign signal_or_7 = signal_wire_105 | signal_wire_104;
    assign signal_or_8 = signal_wire_144 | signal_wire_143;
    assign signal_const_11 = 1'b1;
    assign signal_mux_36 = asks$0 ? signal_const : signal_const_11;
    assign signal_or_9 = signal_wire_82 | signal_const_3;
    assign signal_and_9 = signal_wire_178 & signal_or_9;
    assign signal_select_71 = signal_inst_3[55:28];
    assign signal_wire_82 = signal_select_71;
    assign signal_not_3 = ~ signal_wire_82;
    assign signal_wire_83 = pads;
    assign signal_cat_1 = { signal_const_4,
                            signal_wire_83 };
    assign signal_and_10 = signal_cat_1 & signal_not_3;
    assign signal_or_10 = signal_and_10 | signal_and_9;
    assign signal_wire_84 = hosts$flush_1;
    assign signal_wire_85 = hosts$stop_1;
    assign signal_wire_86 = hosts$clear_irq_1;
    assign signal_wire_87 = hosts$rx_pop_1;
    assign signal_wire_88 = hosts$tx$value_1;
    assign signal_wire_89 = hosts$tx$valid_1;
    assign signal_select_72 = signal_inst_1[82:74];
    assign signal_wire_90 = signal_select_72;
    assign signal_eq_3 = checked == signal_const_11;
    assign signal_and_11 = checking & signal_eq_3;
    assign signal_and_12 = signal_and_11 & signal_wire_93;
    assign signal_mux_37 = signal_and_12 ? signal_wire_91 : signal_wire_90;
    assign signal_select_73 = signal_inst_2[19:11];
    assign signal_wire_91 = signal_select_73;
    assign signal_select_74 = signal_inst_3[82:74];
    assign signal_wire_92 = signal_select_74;
    assign signal_select_75 = signal_inst_2[10:10];
    assign signal_wire_93 = signal_select_75;
    assign signal_eq_4 = checked == signal_const;
    assign signal_and_13 = checking & signal_eq_4;
    assign signal_and_14 = signal_and_13 & signal_wire_93;
    assign signal_mux_38 = signal_and_14 ? signal_wire_91 : signal_wire_92;
    assign signal_wire_94 = hosts$data_write$data_1;
    assign signal_wire_95 = hosts$data_write$addr_1;
    assign signal_wire_96 = hosts$data_write$data_0;
    assign signal_wire_97 = hosts$data_write$addr_0;
    data_memory
        data_memory
        ( .clock(signal_wire_177),
          .clear(signal_wire_176),
          .halted_0(signal_wire_139),
          .halted_1(signal_wire_137),
          .writes$valid_0(signal_wire_142),
          .writes$addr_0(signal_wire_97),
          .writes$data_0(signal_wire_96),
          .writes$valid_1(signal_wire_141),
          .writes$addr_1(signal_wire_95),
          .writes$data_1(signal_wire_94),
          .reads_0(signal_mux_38),
          .reads_1(signal_mux_37),
          .words_0(signal_inst[15:0]),
          .words_1(signal_inst[31:16]) );
    assign signal_select_76 = signal_inst[31:16];
    assign signal_select_77 = signal_inst_2[9:1];
    assign signal_wire_98 = signal_select_77;
    assign signal_select_78 = signal_inst_2[0:0];
    assign signal_wire_99 = signal_select_78;
    assign signal_eq_5 = checked == signal_const_11;
    assign signal_and_15 = checking & signal_eq_5;
    assign signal_and_16 = signal_and_15 & signal_wire_99;
    assign signal_wire_100 = hosts$program_write$data_1;
    assign signal_wire_101 = hosts$program_write$addr_1;
    assign gnd = 1'b0;
    assign vdd = 1'b1;
    assign signal_eq_6 = checked == signal_const_11;
    assign signal_select_79 = signal_inst_2[22:22];
    assign signal_wire_102 = signal_select_79;
    assign signal_select_80 = signal_inst_2[21:21];
    assign signal_wire_103 = signal_select_80;
    assign accepts = signal_wire_103 & signal_wire_102;
    assign signal_and_17 = accepts & signal_eq_6;
    assign signal_mux_39 = signal_and_17 ? vdd : certified;
    assign signal_eq_7 = chosen == signal_const_11;
    assign signal_and_18 = go & signal_eq_7;
    assign signal_wire_104 = hosts$config_written_1;
    assign signal_wire_105 = hosts$program_write$valid_1;
    assign signal_or_11 = signal_wire_105 | signal_wire_104;
    assign signal_or_12 = signal_or_11 | signal_and_18;
    assign signal_mux_40 = signal_or_12 ? gnd : signal_mux_39;
    assign signal_wire_106 = signal_mux_40;
    always @(posedge signal_wire_177) begin
        if (signal_wire_176)
            certified <= signal_const;
        else
            certified <= signal_wire_106;
    end
    assign signal_wire_107 = hosts$start_1;
    assign signal_and_19 = signal_wire_107 & certified;
    assign signal_wire_108 = hosts$config$manchester_1;
    assign signal_wire_109 = hosts$config$autopull_data_1;
    assign signal_wire_110 = hosts$config$period_fraction_1;
    assign signal_wire_111 = hosts$config$wrap_top_1;
    assign signal_wire_112 = hosts$config$wrap_bottom_1;
    assign signal_wire_113 = hosts$config$stuff_level_1;
    assign signal_wire_114 = hosts$config$stuff_threshold_1;
    assign signal_wire_115 = hosts$config$crc_reflect_1;
    assign signal_wire_116 = hosts$config$crc_init_1;
    assign signal_wire_117 = hosts$config$crc_poly_1;
    assign signal_wire_118 = hosts$config$crc_width_1;
    assign signal_wire_119 = hosts$config$pull_threshold_1;
    assign signal_wire_120 = hosts$config$autopull_1;
    assign signal_wire_121 = hosts$config$push_threshold_1;
    assign signal_wire_122 = hosts$config$autopush_1;
    assign signal_wire_123 = hosts$config$out_shift_right_1;
    assign signal_wire_124 = hosts$config$in_shift_right_1;
    assign signal_wire_125 = hosts$config$capture_rising_1;
    assign signal_wire_126 = hosts$config$capture_pin_1;
    assign signal_wire_127 = hosts$config$jmp_pin_1;
    assign signal_wire_128 = hosts$config$set_count_1;
    assign signal_wire_129 = hosts$config$set_base_1;
    assign signal_wire_130 = hosts$config$out_count_1;
    assign signal_wire_131 = hosts$config$out_base_1;
    assign signal_wire_132 = hosts$config$in_count_1;
    assign signal_wire_133 = hosts$config$in_base_1;
    assign signal_wire_134 = hosts$config$side_set_pindirs_1;
    assign signal_wire_135 = hosts$config$side_set_base_1;
    assign signal_wire_136 = hosts$config$side_set_count_1;
    engine
        engine_1
        ( .clock(signal_wire_177),
          .clear(signal_wire_176),
          .config$side_set_count(signal_wire_136),
          .config$side_set_base(signal_wire_135),
          .config$side_set_pindirs(signal_wire_134),
          .config$in_base(signal_wire_133),
          .config$in_count(signal_wire_132),
          .config$out_base(signal_wire_131),
          .config$out_count(signal_wire_130),
          .config$set_base(signal_wire_129),
          .config$set_count(signal_wire_128),
          .config$jmp_pin(signal_wire_127),
          .config$capture_pin(signal_wire_126),
          .config$capture_rising(signal_wire_125),
          .config$in_shift_right(signal_wire_124),
          .config$out_shift_right(signal_wire_123),
          .config$autopush(signal_wire_122),
          .config$push_threshold(signal_wire_121),
          .config$autopull(signal_wire_120),
          .config$pull_threshold(signal_wire_119),
          .config$crc_width(signal_wire_118),
          .config$crc_poly(signal_wire_117),
          .config$crc_init(signal_wire_116),
          .config$crc_reflect(signal_wire_115),
          .config$stuff_threshold(signal_wire_114),
          .config$stuff_level(signal_wire_113),
          .config$wrap_bottom(signal_wire_112),
          .config$wrap_top(signal_wire_111),
          .config$period_fraction(signal_wire_110),
          .config$autopull_data(signal_wire_109),
          .config$manchester(signal_wire_108),
          .start(signal_and_19),
          .program_write$valid(signal_wire_105),
          .program_write$addr(signal_wire_101),
          .program_write$data(signal_wire_100),
          .program_read$valid(signal_and_16),
          .program_read$value(signal_wire_98),
          .data_word(signal_select_76),
          .tx$valid(signal_wire_89),
          .tx$value(signal_wire_88),
          .rx_pop(signal_wire_87),
          .clear_irq(signal_wire_86),
          .stop(signal_wire_85),
          .flush(signal_wire_84),
          .inputs(signal_or_10),
          .pin_out(signal_inst_1[27:0]),
          .pin_dir(signal_inst_1[55:28]),
          .pc(signal_inst_1[64:56]),
          .data_ptr(signal_inst_1[73:65]),
          .data_addr(signal_inst_1[82:74]),
          .x(signal_inst_1[98:83]),
          .y(signal_inst_1[114:99]),
          .p(signal_inst_1[130:115]),
          .t(signal_inst_1[154:131]),
          .t_fraction(signal_inst_1[170:155]),
          .osr(signal_inst_1[186:171]),
          .osr_count(signal_inst_1[191:187]),
          .isr(signal_inst_1[207:192]),
          .isr_count(signal_inst_1[212:208]),
          .now(signal_inst_1[236:213]),
          .stall(signal_inst_1[241:237]),
          .halted(signal_inst_1[242:242]),
          .irq(signal_inst_1[243:243]),
          .fault$underflow(signal_inst_1[244:244]),
          .fault$overflow(signal_inst_1[245:245]),
          .fault$missed_deadline(signal_inst_1[246:246]),
          .fault$decode(signal_inst_1[247:247]),
          .capture(signal_inst_1[271:248]),
          .capture_armed(signal_inst_1[272:272]),
          .tx_level(signal_inst_1[276:273]),
          .rx_level(signal_inst_1[280:277]),
          .rx_head(signal_inst_1[296:281]),
          .instruction(signal_inst_1[312:297]),
          .program_word(signal_inst_1[328:313]),
          .decode_ok(signal_inst_1[329:329]),
          .opcode_onehot(signal_inst_1[337:330]),
          .wait_select(signal_inst_1[365:338]),
          .crc(signal_inst_1[381:366]),
          .stuff_run(signal_inst_1[386:382]),
          .flip_pending(signal_inst_1[387:387]),
          .flip_bit(signal_inst_1[388:388]) );
    assign signal_select_81 = signal_inst_1[242:242];
    assign signal_wire_137 = signal_select_81;
    assign signal_wire_138 = hosts$check_1;
    assign asks$1 = signal_wire_138 & signal_wire_137;
    assign signal_select_82 = signal_inst_3[242:242];
    assign signal_wire_139 = signal_select_82;
    assign signal_wire_140 = hosts$check_0;
    assign asks$0 = signal_wire_140 & signal_wire_139;
    assign signal_or_13 = asks$0 | asks$1;
    assign chosen = signal_or_13 ? signal_mux_36 : signal_const;
    always @(posedge signal_wire_177) begin
        if (signal_wire_176)
            signal_reg <= signal_const;
        else
            if (go)
                signal_reg <= chosen;
    end
    assign checked = signal_reg;
    assign signal_mux_41 = checked ? signal_or_7 : signal_or_8;
    assign signal_wire_141 = hosts$data_write$valid_1;
    assign signal_wire_142 = hosts$data_write$valid_0;
    assign signal_or_14 = signal_wire_142 | signal_wire_141;
    assign signal_or_15 = signal_or_14 | signal_mux_41;
    assign abort = checking & signal_or_15;
    load_checker
        load_checker
        ( .clock(signal_wire_177),
          .clear(signal_wire_176),
          .check(go),
          .abort(abort),
          .config$side_set_count(signal_mux_35),
          .config$side_set_base(signal_mux_34),
          .config$side_set_pindirs(signal_mux_33),
          .config$in_base(signal_mux_32),
          .config$in_count(signal_mux_31),
          .config$out_base(signal_mux_30),
          .config$out_count(signal_mux_29),
          .config$set_base(signal_mux_28),
          .config$set_count(signal_mux_27),
          .config$jmp_pin(signal_mux_26),
          .config$capture_pin(signal_mux_25),
          .config$capture_rising(signal_mux_24),
          .config$in_shift_right(signal_mux_23),
          .config$out_shift_right(signal_mux_22),
          .config$autopush(signal_mux_21),
          .config$push_threshold(signal_mux_20),
          .config$autopull(signal_mux_19),
          .config$pull_threshold(signal_mux_18),
          .config$crc_width(signal_mux_17),
          .config$crc_poly(signal_mux_16),
          .config$crc_init(signal_mux_15),
          .config$crc_reflect(signal_mux_14),
          .config$stuff_threshold(signal_mux_13),
          .config$stuff_level(signal_mux_12),
          .config$wrap_bottom(signal_mux_11),
          .config$wrap_top(signal_mux_10),
          .config$period_fraction(signal_mux_9),
          .config$autopull_data(signal_mux_8),
          .config$manchester(signal_mux_7),
          .setup$base(signal_wire_81),
          .setup$loaded$valid(signal_wire_80),
          .setup$loaded$value(signal_wire_79),
          .setup$single_edge(signal_wire_78),
          .program_word(signal_mux_6),
          .data_word(signal_mux_5),
          .program_read$valid(signal_inst_2[0:0]),
          .program_read$value(signal_inst_2[9:1]),
          .data_read$valid(signal_inst_2[10:10]),
          .data_read$value(signal_inst_2[19:11]),
          .busy(signal_inst_2[20:20]),
          .finished(signal_inst_2[21:21]),
          .accepted(signal_inst_2[22:22]),
          .reject_pc(signal_inst_2[32:23]),
          .reason(signal_inst_2[37:33]) );
    assign signal_select_83 = signal_inst_2[20:20];
    assign checking = signal_select_83;
    assign signal_not_4 = ~ checking;
    assign go = signal_not_4 & signal_or_6;
    assign signal_and_20 = go & signal_eq_2;
    assign signal_wire_143 = hosts$config_written_0;
    assign signal_wire_144 = hosts$program_write$valid_0;
    assign signal_or_16 = signal_wire_144 | signal_wire_143;
    assign signal_or_17 = signal_or_16 | signal_and_20;
    assign signal_mux_42 = signal_or_17 ? gnd : signal_mux_4;
    assign signal_wire_145 = signal_mux_42;
    always @(posedge signal_wire_177) begin
        if (signal_wire_176)
            certified_1 <= signal_const;
        else
            certified_1 <= signal_wire_145;
    end
    assign signal_wire_146 = hosts$start_0;
    assign signal_and_21 = signal_wire_146 & certified_1;
    assign signal_wire_147 = hosts$config$manchester_0;
    assign signal_wire_148 = hosts$config$autopull_data_0;
    assign signal_wire_149 = hosts$config$period_fraction_0;
    assign signal_wire_150 = hosts$config$wrap_top_0;
    assign signal_wire_151 = hosts$config$wrap_bottom_0;
    assign signal_wire_152 = hosts$config$stuff_level_0;
    assign signal_wire_153 = hosts$config$stuff_threshold_0;
    assign signal_wire_154 = hosts$config$crc_reflect_0;
    assign signal_wire_155 = hosts$config$crc_init_0;
    assign signal_wire_156 = hosts$config$crc_poly_0;
    assign signal_wire_157 = hosts$config$crc_width_0;
    assign signal_wire_158 = hosts$config$pull_threshold_0;
    assign signal_wire_159 = hosts$config$autopull_0;
    assign signal_wire_160 = hosts$config$push_threshold_0;
    assign signal_wire_161 = hosts$config$autopush_0;
    assign signal_wire_162 = hosts$config$out_shift_right_0;
    assign signal_wire_163 = hosts$config$in_shift_right_0;
    assign signal_wire_164 = hosts$config$capture_rising_0;
    assign signal_wire_165 = hosts$config$capture_pin_0;
    assign signal_wire_166 = hosts$config$jmp_pin_0;
    assign signal_wire_167 = hosts$config$set_count_0;
    assign signal_wire_168 = hosts$config$set_base_0;
    assign signal_wire_169 = hosts$config$out_count_0;
    assign signal_wire_170 = hosts$config$out_base_0;
    assign signal_wire_171 = hosts$config$in_count_0;
    assign signal_wire_172 = hosts$config$in_base_0;
    assign signal_wire_173 = hosts$config$side_set_pindirs_0;
    assign signal_wire_174 = hosts$config$side_set_base_0;
    assign signal_wire_175 = hosts$config$side_set_count_0;
    assign signal_wire_176 = clear;
    assign signal_wire_177 = clock;
    engine
        engine_0
        ( .clock(signal_wire_177),
          .clear(signal_wire_176),
          .config$side_set_count(signal_wire_175),
          .config$side_set_base(signal_wire_174),
          .config$side_set_pindirs(signal_wire_173),
          .config$in_base(signal_wire_172),
          .config$in_count(signal_wire_171),
          .config$out_base(signal_wire_170),
          .config$out_count(signal_wire_169),
          .config$set_base(signal_wire_168),
          .config$set_count(signal_wire_167),
          .config$jmp_pin(signal_wire_166),
          .config$capture_pin(signal_wire_165),
          .config$capture_rising(signal_wire_164),
          .config$in_shift_right(signal_wire_163),
          .config$out_shift_right(signal_wire_162),
          .config$autopush(signal_wire_161),
          .config$push_threshold(signal_wire_160),
          .config$autopull(signal_wire_159),
          .config$pull_threshold(signal_wire_158),
          .config$crc_width(signal_wire_157),
          .config$crc_poly(signal_wire_156),
          .config$crc_init(signal_wire_155),
          .config$crc_reflect(signal_wire_154),
          .config$stuff_threshold(signal_wire_153),
          .config$stuff_level(signal_wire_152),
          .config$wrap_bottom(signal_wire_151),
          .config$wrap_top(signal_wire_150),
          .config$period_fraction(signal_wire_149),
          .config$autopull_data(signal_wire_148),
          .config$manchester(signal_wire_147),
          .start(signal_and_21),
          .program_write$valid(signal_wire_144),
          .program_write$addr(signal_wire_75),
          .program_write$data(signal_wire_74),
          .program_read$valid(signal_and_7),
          .program_read$value(signal_wire_98),
          .data_word(signal_select_68),
          .tx$valid(signal_wire_73),
          .tx$value(signal_wire_72),
          .rx_pop(signal_wire_71),
          .clear_irq(signal_wire_70),
          .stop(signal_wire_69),
          .flush(signal_wire_68),
          .inputs(signal_or_5),
          .pin_out(signal_inst_3[27:0]),
          .pin_dir(signal_inst_3[55:28]),
          .pc(signal_inst_3[64:56]),
          .data_ptr(signal_inst_3[73:65]),
          .data_addr(signal_inst_3[82:74]),
          .x(signal_inst_3[98:83]),
          .y(signal_inst_3[114:99]),
          .p(signal_inst_3[130:115]),
          .t(signal_inst_3[154:131]),
          .t_fraction(signal_inst_3[170:155]),
          .osr(signal_inst_3[186:171]),
          .osr_count(signal_inst_3[191:187]),
          .isr(signal_inst_3[207:192]),
          .isr_count(signal_inst_3[212:208]),
          .now(signal_inst_3[236:213]),
          .stall(signal_inst_3[241:237]),
          .halted(signal_inst_3[242:242]),
          .irq(signal_inst_3[243:243]),
          .fault$underflow(signal_inst_3[244:244]),
          .fault$overflow(signal_inst_3[245:245]),
          .fault$missed_deadline(signal_inst_3[246:246]),
          .fault$decode(signal_inst_3[247:247]),
          .capture(signal_inst_3[271:248]),
          .capture_armed(signal_inst_3[272:272]),
          .tx_level(signal_inst_3[276:273]),
          .rx_level(signal_inst_3[280:277]),
          .rx_head(signal_inst_3[296:281]),
          .instruction(signal_inst_3[312:297]),
          .program_word(signal_inst_3[328:313]),
          .decode_ok(signal_inst_3[329:329]),
          .opcode_onehot(signal_inst_3[337:330]),
          .wait_select(signal_inst_3[365:338]),
          .crc(signal_inst_3[381:366]),
          .stuff_run(signal_inst_3[386:382]),
          .flip_pending(signal_inst_3[387:387]),
          .flip_bit(signal_inst_3[388:388]) );
    assign signal_select_84 = signal_inst_3[27:0];
    assign signal_wire_178 = signal_select_84;
    assign engines$pin_out_0 = signal_wire_178;
    assign engines$pin_dir_0 = signal_wire_82;
    assign engines$pc_0 = signal_wire_65;
    assign engines$data_ptr_0 = signal_wire_64;
    assign engines$data_addr_0 = signal_wire_92;
    assign engines$x_0 = signal_wire_63;
    assign engines$y_0 = signal_wire_62;
    assign engines$p_0 = signal_wire_61;
    assign engines$t_0 = signal_wire_60;
    assign engines$t_fraction_0 = signal_wire_59;
    assign engines$osr_0 = signal_wire_58;
    assign engines$osr_count_0 = signal_wire_57;
    assign engines$isr_0 = signal_wire_56;
    assign engines$isr_count_0 = signal_wire_55;
    assign engines$now_0 = signal_wire_54;
    assign engines$stall_0 = signal_wire_53;
    assign engines$halted_0 = signal_wire_139;
    assign engines$irq_0 = signal_wire_52;
    assign engines$fault$underflow_0 = signal_wire_51;
    assign engines$fault$overflow_0 = signal_wire_50;
    assign engines$fault$missed_deadline_0 = signal_wire_49;
    assign engines$fault$decode_0 = signal_wire_48;
    assign engines$capture_0 = signal_wire_47;
    assign engines$capture_armed_0 = signal_wire_46;
    assign engines$tx_level_0 = signal_wire_45;
    assign engines$rx_level_0 = signal_wire_44;
    assign engines$rx_head_0 = signal_wire_43;
    assign engines$instruction_0 = signal_wire_42;
    assign engines$program_word_0 = signal_wire_77;
    assign engines$decode_ok_0 = signal_wire_41;
    assign engines$opcode_onehot_0 = signal_wire_40;
    assign engines$wait_select_0 = signal_wire_39;
    assign engines$crc_0 = signal_wire_38;
    assign engines$stuff_run_0 = signal_wire_37;
    assign engines$flip_pending_0 = signal_wire_36;
    assign engines$flip_bit_0 = signal_wire_35;
    assign engines$pin_out_1 = signal_wire_66;
    assign engines$pin_dir_1 = signal_wire_67;
    assign engines$pc_1 = signal_wire_34;
    assign engines$data_ptr_1 = signal_wire_33;
    assign engines$data_addr_1 = signal_wire_90;
    assign engines$x_1 = signal_wire_32;
    assign engines$y_1 = signal_wire_31;
    assign engines$p_1 = signal_wire_30;
    assign engines$t_1 = signal_wire_29;
    assign engines$t_fraction_1 = signal_wire_28;
    assign engines$osr_1 = signal_wire_27;
    assign engines$osr_count_1 = signal_wire_26;
    assign engines$isr_1 = signal_wire_25;
    assign engines$isr_count_1 = signal_wire_24;
    assign engines$now_1 = signal_wire_23;
    assign engines$stall_1 = signal_wire_22;
    assign engines$halted_1 = signal_wire_137;
    assign engines$irq_1 = signal_wire_21;
    assign engines$fault$underflow_1 = signal_wire_20;
    assign engines$fault$overflow_1 = signal_wire_19;
    assign engines$fault$missed_deadline_1 = signal_wire_18;
    assign engines$fault$decode_1 = signal_wire_17;
    assign engines$capture_1 = signal_wire_16;
    assign engines$capture_armed_1 = signal_wire_15;
    assign engines$tx_level_1 = signal_wire_14;
    assign engines$rx_level_1 = signal_wire_13;
    assign engines$rx_head_1 = signal_wire_12;
    assign engines$instruction_1 = signal_wire_11;
    assign engines$program_word_1 = signal_wire_76;
    assign engines$decode_ok_1 = signal_wire_10;
    assign engines$opcode_onehot_1 = signal_wire_9;
    assign engines$wait_select_1 = signal_wire_8;
    assign engines$crc_1 = signal_wire_7;
    assign engines$stuff_run_1 = signal_wire_6;
    assign engines$flip_pending_1 = signal_wire_5;
    assign engines$flip_bit_1 = signal_wire_4;
    assign pin_out = signal_select_3;
    assign pin_dir = signal_select_2;
    assign check$verdict$busy = checking;
    assign check$verdict$accepted = signal_wire_102;
    assign check$verdict$reject_pc = signal_wire_3;
    assign check$verdict$reason = signal_wire_2;
    assign check$certified_0 = certified_1;
    assign check$certified_1 = certified;
    assign check$refused_0 = refused_1;
    assign check$refused_1 = refused;

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
    status$certified_0,
    status$refused_0,
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
    status$certified_1,
    status$refused_1,
    check$busy,
    check$accepted,
    check$reject_pc,
    check$reason,
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
    engines$config$autopull_data_0,
    engines$config$manchester_0,
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
    engines$check_0,
    engines$config_written_0,
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
    engines$config$autopull_data_1,
    engines$config$manchester_1,
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
    engines$check_1,
    engines$config_written_1,
    check_setup$base,
    check_setup$loaded$valid,
    check_setup$loaded$value,
    check_setup$single_edge
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
    input status$certified_0;
    input status$refused_0;
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
    input status$certified_1;
    input status$refused_1;
    input check$busy;
    input check$accepted;
    input [9:0] check$reject_pc;
    input [4:0] check$reason;
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
    output engines$config$autopull_data_0;
    output engines$config$manchester_0;
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
    output engines$check_0;
    output engines$config_written_0;
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
    output engines$config$autopull_data_1;
    output engines$config$manchester_1;
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
    output engines$check_1;
    output engines$config_written_1;
    output [8:0] check_setup$base;
    output check_setup$loaded$valid;
    output [15:0] check_setup$loaded$value;
    output check_setup$single_edge;

    wire signal_select;
    wire signal_select_1;
    wire signal_const;
    wire signal_eq;
    wire signal_and;
    wire signal_and_1;
    wire signal_eq_1;
    wire signal_select_2;
    wire [6:0] signal_const_2;
    wire signal_eq_2;
    wire signal_and_2;
    wire signal_and_3;
    wire signal_and_4;
    wire signal_eq_3;
    wire signal_select_3;
    wire signal_eq_4;
    wire signal_and_5;
    wire signal_and_6;
    wire signal_and_7;
    wire signal_eq_5;
    wire signal_select_4;
    wire signal_eq_6;
    wire signal_and_8;
    wire signal_and_9;
    wire signal_and_10;
    wire signal_eq_7;
    wire signal_select_5;
    wire signal_eq_8;
    wire signal_and_11;
    wire signal_and_12;
    wire signal_and_13;
    wire signal_eq_9;
    wire [6:0] signal_const_10;
    wire signal_eq_10;
    wire signal_and_14;
    wire signal_and_15;
    wire signal_eq_11;
    wire [6:0] signal_const_12;
    wire signal_eq_12;
    wire signal_and_16;
    wire signal_and_17;
    wire signal_eq_13;
    wire [6:0] signal_const_14;
    wire signal_eq_14;
    wire signal_and_18;
    wire signal_and_19;
    wire signal_eq_15;
    wire [6:0] signal_const_16;
    wire signal_eq_16;
    wire signal_and_20;
    wire signal_and_21;
    wire signal_eq_17;
    wire signal_select_6;
    wire signal_eq_18;
    wire signal_and_22;
    wire signal_and_23;
    wire signal_and_24;
    wire signal_const_19;
    wire signal_select_7;
    wire signal_eq_19;
    wire [6:0] signal_const_21;
    wire signal_eq_20;
    wire signal_and_25;
    wire signal_and_26;
    wire signal_mux;
    wire signal_mux_1;
    wire signal_wire;
    reg signal_reg;
    wire signal_select_8;
    wire signal_eq_21;
    wire [6:0] signal_const_24;
    wire signal_eq_22;
    wire signal_and_27;
    wire signal_and_28;
    wire signal_mux_2;
    wire signal_mux_3;
    wire signal_wire_1;
    reg signal_reg_1;
    wire [15:0] signal_const_25;
    wire signal_eq_23;
    wire [6:0] signal_const_27;
    wire signal_eq_24;
    wire signal_and_29;
    wire signal_and_30;
    wire [15:0] signal_mux_4;
    wire [15:0] signal_mux_5;
    wire [15:0] signal_wire_2;
    reg [15:0] signal_reg_2;
    wire [8:0] signal_const_28;
    wire [8:0] signal_select_9;
    wire signal_eq_25;
    wire [6:0] signal_const_30;
    wire signal_eq_26;
    wire signal_and_31;
    wire signal_and_32;
    wire [8:0] signal_mux_6;
    wire [8:0] signal_mux_7;
    wire [8:0] signal_wire_3;
    reg [8:0] signal_reg_3;
    wire [8:0] signal_select_10;
    wire signal_eq_27;
    wire [6:0] signal_const_33;
    wire signal_eq_28;
    wire signal_and_33;
    wire signal_and_34;
    wire [8:0] signal_mux_8;
    wire [8:0] signal_mux_9;
    wire [8:0] signal_wire_4;
    reg [8:0] signal_reg_4;
    wire signal_select_11;
    wire signal_eq_29;
    wire [6:0] signal_const_36;
    wire signal_eq_30;
    wire signal_and_35;
    wire signal_and_36;
    wire signal_mux_10;
    wire signal_mux_11;
    wire signal_wire_5;
    reg signal_reg_5;
    wire [4:0] signal_const_37;
    wire [4:0] signal_select_12;
    wire signal_eq_31;
    wire [6:0] signal_const_39;
    wire signal_eq_32;
    wire signal_and_37;
    wire signal_and_38;
    wire [4:0] signal_mux_12;
    wire [4:0] signal_mux_13;
    wire [4:0] signal_wire_6;
    reg [4:0] signal_reg_6;
    wire signal_select_13;
    wire signal_eq_33;
    wire [6:0] signal_const_42;
    wire signal_eq_34;
    wire signal_and_39;
    wire signal_and_40;
    wire signal_mux_14;
    wire signal_mux_15;
    wire signal_wire_7;
    reg signal_reg_7;
    wire signal_eq_35;
    wire [6:0] signal_const_45;
    wire signal_eq_36;
    wire signal_and_41;
    wire signal_and_42;
    wire [15:0] signal_mux_16;
    wire [15:0] signal_mux_17;
    wire [15:0] signal_wire_8;
    reg [15:0] signal_reg_8;
    wire signal_eq_37;
    wire [6:0] signal_const_48;
    wire signal_eq_38;
    wire signal_and_43;
    wire signal_and_44;
    wire [15:0] signal_mux_18;
    wire [15:0] signal_mux_19;
    wire [15:0] signal_wire_9;
    reg [15:0] signal_reg_9;
    wire [4:0] signal_select_14;
    wire signal_eq_39;
    wire [6:0] signal_const_51;
    wire signal_eq_40;
    wire signal_and_45;
    wire signal_and_46;
    wire [4:0] signal_mux_20;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_wire_10;
    reg [4:0] signal_reg_10;
    wire [4:0] signal_select_15;
    wire signal_eq_41;
    wire [6:0] signal_const_54;
    wire signal_eq_42;
    wire signal_and_47;
    wire signal_and_48;
    wire [4:0] signal_mux_22;
    wire [4:0] signal_mux_23;
    wire [4:0] signal_wire_11;
    reg [4:0] signal_reg_11;
    wire signal_select_16;
    wire signal_eq_43;
    wire [6:0] signal_const_57;
    wire signal_eq_44;
    wire signal_and_49;
    wire signal_and_50;
    wire signal_mux_24;
    wire signal_mux_25;
    wire signal_wire_12;
    reg signal_reg_12;
    wire [4:0] signal_select_17;
    wire signal_eq_45;
    wire [6:0] signal_const_60;
    wire signal_eq_46;
    wire signal_and_51;
    wire signal_and_52;
    wire [4:0] signal_mux_26;
    wire [4:0] signal_mux_27;
    wire [4:0] signal_wire_13;
    reg [4:0] signal_reg_13;
    wire signal_select_18;
    wire signal_eq_47;
    wire [6:0] signal_const_63;
    wire signal_eq_48;
    wire signal_and_53;
    wire signal_and_54;
    wire signal_mux_28;
    wire signal_mux_29;
    wire signal_wire_14;
    reg signal_reg_14;
    wire signal_select_19;
    wire signal_eq_49;
    wire [6:0] signal_const_66;
    wire signal_eq_50;
    wire signal_and_55;
    wire signal_and_56;
    wire signal_mux_30;
    wire signal_mux_31;
    wire signal_wire_15;
    reg signal_reg_15;
    wire signal_select_20;
    wire signal_eq_51;
    wire [6:0] signal_const_69;
    wire signal_eq_52;
    wire signal_and_57;
    wire signal_and_58;
    wire signal_mux_32;
    wire signal_mux_33;
    wire signal_wire_16;
    reg signal_reg_16;
    wire signal_select_21;
    wire signal_eq_53;
    wire [6:0] signal_const_72;
    wire signal_eq_54;
    wire signal_and_59;
    wire signal_and_60;
    wire signal_mux_34;
    wire signal_mux_35;
    wire signal_wire_17;
    reg signal_reg_17;
    wire [4:0] signal_select_22;
    wire signal_eq_55;
    wire [6:0] signal_const_75;
    wire signal_eq_56;
    wire signal_and_61;
    wire signal_and_62;
    wire [4:0] signal_mux_36;
    wire [4:0] signal_mux_37;
    wire [4:0] signal_wire_18;
    reg [4:0] signal_reg_18;
    wire [4:0] signal_select_23;
    wire signal_eq_57;
    wire [6:0] signal_const_78;
    wire signal_eq_58;
    wire signal_and_63;
    wire signal_and_64;
    wire [4:0] signal_mux_38;
    wire [4:0] signal_mux_39;
    wire [4:0] signal_wire_19;
    reg [4:0] signal_reg_19;
    wire [2:0] signal_const_79;
    wire [2:0] signal_select_24;
    wire signal_eq_59;
    wire [6:0] signal_const_81;
    wire signal_eq_60;
    wire signal_and_65;
    wire signal_and_66;
    wire [2:0] signal_mux_40;
    wire [2:0] signal_mux_41;
    wire [2:0] signal_wire_20;
    reg [2:0] signal_reg_20;
    wire [4:0] signal_select_25;
    wire signal_eq_61;
    wire [6:0] signal_const_84;
    wire signal_eq_62;
    wire signal_and_67;
    wire signal_and_68;
    wire [4:0] signal_mux_42;
    wire [4:0] signal_mux_43;
    wire [4:0] signal_wire_21;
    reg [4:0] signal_reg_21;
    wire [4:0] signal_select_26;
    wire signal_eq_63;
    wire [6:0] signal_const_87;
    wire signal_eq_64;
    wire signal_and_69;
    wire signal_and_70;
    wire [4:0] signal_mux_44;
    wire [4:0] signal_mux_45;
    wire [4:0] signal_wire_22;
    reg [4:0] signal_reg_22;
    wire [4:0] signal_select_27;
    wire signal_eq_65;
    wire [6:0] signal_const_90;
    wire signal_eq_66;
    wire signal_and_71;
    wire signal_and_72;
    wire [4:0] signal_mux_46;
    wire [4:0] signal_mux_47;
    wire [4:0] signal_wire_23;
    reg [4:0] signal_reg_23;
    wire [4:0] signal_select_28;
    wire signal_eq_67;
    wire [6:0] signal_const_93;
    wire signal_eq_68;
    wire signal_and_73;
    wire signal_and_74;
    wire [4:0] signal_mux_48;
    wire [4:0] signal_mux_49;
    wire [4:0] signal_wire_24;
    reg [4:0] signal_reg_24;
    wire [4:0] signal_select_29;
    wire signal_eq_69;
    wire [6:0] signal_const_96;
    wire signal_eq_70;
    wire signal_and_75;
    wire signal_and_76;
    wire [4:0] signal_mux_50;
    wire [4:0] signal_mux_51;
    wire [4:0] signal_wire_25;
    reg [4:0] signal_reg_25;
    wire signal_select_30;
    wire signal_eq_71;
    wire [6:0] signal_const_99;
    wire signal_eq_72;
    wire signal_and_77;
    wire signal_and_78;
    wire signal_mux_52;
    wire signal_mux_53;
    wire signal_wire_26;
    reg signal_reg_26;
    wire [4:0] signal_select_31;
    wire signal_eq_73;
    wire [6:0] signal_const_102;
    wire signal_eq_74;
    wire signal_and_79;
    wire signal_and_80;
    wire [4:0] signal_mux_54;
    wire [4:0] signal_mux_55;
    wire [4:0] signal_wire_27;
    reg [4:0] signal_reg_27;
    wire [1:0] signal_const_103;
    wire [1:0] signal_select_32;
    wire signal_eq_75;
    wire [6:0] signal_const_105;
    wire signal_eq_76;
    wire signal_and_81;
    wire signal_and_82;
    wire [1:0] signal_mux_56;
    wire [1:0] signal_mux_57;
    wire [1:0] signal_wire_28;
    reg [1:0] signal_reg_28;
    wire signal_eq_77;
    wire signal_eq_78;
    wire signal_eq_79;
    wire signal_eq_80;
    wire signal_eq_81;
    wire signal_eq_82;
    wire signal_eq_83;
    wire signal_eq_84;
    wire signal_eq_85;
    wire signal_eq_86;
    wire signal_eq_87;
    wire signal_eq_88;
    wire signal_eq_89;
    wire signal_eq_90;
    wire signal_eq_91;
    wire signal_eq_92;
    wire signal_eq_93;
    wire signal_eq_94;
    wire signal_eq_95;
    wire signal_eq_96;
    wire signal_eq_97;
    wire signal_eq_98;
    wire signal_eq_99;
    wire signal_eq_100;
    wire signal_eq_101;
    wire signal_eq_102;
    wire signal_eq_103;
    wire signal_eq_104;
    wire signal_eq_105;
    wire signal_eq_106;
    wire signal_or;
    wire signal_or_1;
    wire signal_or_2;
    wire signal_or_3;
    wire signal_or_4;
    wire signal_or_5;
    wire signal_or_6;
    wire signal_or_7;
    wire signal_or_8;
    wire signal_or_9;
    wire signal_or_10;
    wire signal_or_11;
    wire signal_or_12;
    wire signal_or_13;
    wire signal_or_14;
    wire signal_or_15;
    wire signal_or_16;
    wire signal_or_17;
    wire signal_or_18;
    wire signal_or_19;
    wire signal_or_20;
    wire signal_or_21;
    wire signal_or_22;
    wire signal_or_23;
    wire signal_or_24;
    wire signal_or_25;
    wire signal_or_26;
    wire signal_or_27;
    wire writes_config;
    wire signal_and_83;
    wire signal_and_84;
    wire signal_eq_107;
    wire signal_select_33;
    wire signal_eq_108;
    wire signal_and_85;
    wire signal_and_86;
    wire signal_and_87;
    wire signal_eq_109;
    wire signal_select_34;
    wire signal_eq_110;
    wire signal_and_88;
    wire signal_and_89;
    wire signal_and_90;
    wire signal_eq_111;
    wire signal_select_35;
    wire signal_eq_112;
    wire signal_and_91;
    wire signal_and_92;
    wire signal_and_93;
    wire signal_eq_113;
    wire signal_select_36;
    wire signal_eq_114;
    wire signal_and_94;
    wire signal_and_95;
    wire signal_and_96;
    wire signal_eq_115;
    wire signal_eq_116;
    wire signal_and_97;
    wire signal_and_98;
    wire signal_eq_117;
    wire signal_eq_118;
    wire signal_and_99;
    wire signal_and_100;
    wire signal_eq_119;
    wire signal_eq_120;
    wire signal_and_101;
    wire signal_and_102;
    wire signal_eq_121;
    wire signal_eq_122;
    wire signal_and_103;
    wire signal_and_104;
    wire signal_eq_123;
    wire signal_select_37;
    wire signal_eq_124;
    wire signal_and_105;
    wire signal_and_106;
    wire signal_and_107;
    wire signal_select_38;
    wire signal_eq_125;
    wire signal_eq_126;
    wire signal_and_108;
    wire signal_and_109;
    wire signal_mux_58;
    wire signal_mux_59;
    wire signal_wire_29;
    reg signal_reg_29;
    wire signal_select_39;
    wire signal_eq_127;
    wire signal_eq_128;
    wire signal_and_110;
    wire signal_and_111;
    wire signal_mux_60;
    wire signal_mux_61;
    wire signal_wire_30;
    reg signal_reg_30;
    wire signal_eq_129;
    wire signal_eq_130;
    wire signal_and_112;
    wire signal_and_113;
    wire [15:0] signal_mux_62;
    wire [15:0] signal_mux_63;
    wire [15:0] signal_wire_31;
    reg [15:0] signal_reg_31;
    wire [8:0] signal_select_40;
    wire signal_eq_131;
    wire signal_eq_132;
    wire signal_and_114;
    wire signal_and_115;
    wire [8:0] signal_mux_64;
    wire [8:0] signal_mux_65;
    wire [8:0] signal_wire_32;
    reg [8:0] signal_reg_32;
    wire [8:0] signal_select_41;
    wire signal_eq_133;
    wire signal_eq_134;
    wire signal_and_116;
    wire signal_and_117;
    wire [8:0] signal_mux_66;
    wire [8:0] signal_mux_67;
    wire [8:0] signal_wire_33;
    reg [8:0] signal_reg_33;
    wire signal_select_42;
    wire signal_eq_135;
    wire signal_eq_136;
    wire signal_and_118;
    wire signal_and_119;
    wire signal_mux_68;
    wire signal_mux_69;
    wire signal_wire_34;
    reg signal_reg_34;
    wire [4:0] signal_select_43;
    wire signal_eq_137;
    wire signal_eq_138;
    wire signal_and_120;
    wire signal_and_121;
    wire [4:0] signal_mux_70;
    wire [4:0] signal_mux_71;
    wire [4:0] signal_wire_35;
    reg [4:0] signal_reg_35;
    wire signal_select_44;
    wire signal_eq_139;
    wire signal_eq_140;
    wire signal_and_122;
    wire signal_and_123;
    wire signal_mux_72;
    wire signal_mux_73;
    wire signal_wire_36;
    reg signal_reg_36;
    wire signal_eq_141;
    wire signal_eq_142;
    wire signal_and_124;
    wire signal_and_125;
    wire [15:0] signal_mux_74;
    wire [15:0] signal_mux_75;
    wire [15:0] signal_wire_37;
    reg [15:0] signal_reg_37;
    wire signal_eq_143;
    wire signal_eq_144;
    wire signal_and_126;
    wire signal_and_127;
    wire [15:0] signal_mux_76;
    wire [15:0] signal_mux_77;
    wire [15:0] signal_wire_38;
    reg [15:0] signal_reg_38;
    wire [4:0] signal_select_45;
    wire signal_eq_145;
    wire signal_eq_146;
    wire signal_and_128;
    wire signal_and_129;
    wire [4:0] signal_mux_78;
    wire [4:0] signal_mux_79;
    wire [4:0] signal_wire_39;
    reg [4:0] signal_reg_39;
    wire [4:0] signal_select_46;
    wire signal_eq_147;
    wire signal_eq_148;
    wire signal_and_130;
    wire signal_and_131;
    wire [4:0] signal_mux_80;
    wire [4:0] signal_mux_81;
    wire [4:0] signal_wire_40;
    reg [4:0] signal_reg_40;
    wire signal_select_47;
    wire signal_eq_149;
    wire signal_eq_150;
    wire signal_and_132;
    wire signal_and_133;
    wire signal_mux_82;
    wire signal_mux_83;
    wire signal_wire_41;
    reg signal_reg_41;
    wire [4:0] signal_select_48;
    wire signal_eq_151;
    wire signal_eq_152;
    wire signal_and_134;
    wire signal_and_135;
    wire [4:0] signal_mux_84;
    wire [4:0] signal_mux_85;
    wire [4:0] signal_wire_42;
    reg [4:0] signal_reg_42;
    wire signal_select_49;
    wire signal_eq_153;
    wire signal_eq_154;
    wire signal_and_136;
    wire signal_and_137;
    wire signal_mux_86;
    wire signal_mux_87;
    wire signal_wire_43;
    reg signal_reg_43;
    wire signal_select_50;
    wire signal_eq_155;
    wire signal_eq_156;
    wire signal_and_138;
    wire signal_and_139;
    wire signal_mux_88;
    wire signal_mux_89;
    wire signal_wire_44;
    reg signal_reg_44;
    wire signal_select_51;
    wire signal_eq_157;
    wire signal_eq_158;
    wire signal_and_140;
    wire signal_and_141;
    wire signal_mux_90;
    wire signal_mux_91;
    wire signal_wire_45;
    reg signal_reg_45;
    wire signal_select_52;
    wire signal_eq_159;
    wire signal_eq_160;
    wire signal_and_142;
    wire signal_and_143;
    wire signal_mux_92;
    wire signal_mux_93;
    wire signal_wire_46;
    reg signal_reg_46;
    wire [4:0] signal_select_53;
    wire signal_eq_161;
    wire signal_eq_162;
    wire signal_and_144;
    wire signal_and_145;
    wire [4:0] signal_mux_94;
    wire [4:0] signal_mux_95;
    wire [4:0] signal_wire_47;
    reg [4:0] signal_reg_47;
    wire [4:0] signal_select_54;
    wire signal_eq_163;
    wire signal_eq_164;
    wire signal_and_146;
    wire signal_and_147;
    wire [4:0] signal_mux_96;
    wire [4:0] signal_mux_97;
    wire [4:0] signal_wire_48;
    reg [4:0] signal_reg_48;
    wire [2:0] signal_select_55;
    wire signal_eq_165;
    wire signal_eq_166;
    wire signal_and_148;
    wire signal_and_149;
    wire [2:0] signal_mux_98;
    wire [2:0] signal_mux_99;
    wire [2:0] signal_wire_49;
    reg [2:0] signal_reg_49;
    wire [4:0] signal_select_56;
    wire signal_eq_167;
    wire signal_eq_168;
    wire signal_and_150;
    wire signal_and_151;
    wire [4:0] signal_mux_100;
    wire [4:0] signal_mux_101;
    wire [4:0] signal_wire_50;
    reg [4:0] signal_reg_50;
    wire [4:0] signal_select_57;
    wire signal_eq_169;
    wire signal_eq_170;
    wire signal_and_152;
    wire signal_and_153;
    wire [4:0] signal_mux_102;
    wire [4:0] signal_mux_103;
    wire [4:0] signal_wire_51;
    reg [4:0] signal_reg_51;
    wire [4:0] signal_select_58;
    wire signal_eq_171;
    wire signal_eq_172;
    wire signal_and_154;
    wire signal_and_155;
    wire [4:0] signal_mux_104;
    wire [4:0] signal_mux_105;
    wire [4:0] signal_wire_52;
    reg [4:0] signal_reg_52;
    wire [4:0] signal_select_59;
    wire signal_eq_173;
    wire signal_eq_174;
    wire signal_and_156;
    wire signal_and_157;
    wire [4:0] signal_mux_106;
    wire [4:0] signal_mux_107;
    wire [4:0] signal_wire_53;
    reg [4:0] signal_reg_53;
    wire [4:0] signal_select_60;
    wire signal_eq_175;
    wire signal_eq_176;
    wire signal_and_158;
    wire signal_and_159;
    wire [4:0] signal_mux_108;
    wire [4:0] signal_mux_109;
    wire [4:0] signal_wire_54;
    reg [4:0] signal_reg_54;
    wire signal_select_61;
    wire signal_eq_177;
    wire signal_eq_178;
    wire signal_and_160;
    wire signal_and_161;
    wire signal_mux_110;
    wire signal_mux_111;
    wire signal_wire_55;
    reg signal_reg_55;
    wire [4:0] signal_select_62;
    wire signal_eq_179;
    wire signal_eq_180;
    wire signal_and_162;
    wire signal_and_163;
    wire [4:0] signal_mux_112;
    wire [4:0] signal_mux_113;
    wire [4:0] signal_wire_56;
    reg [4:0] signal_reg_56;
    wire [1:0] signal_select_63;
    wire signal_eq_181;
    wire signal_eq_182;
    wire signal_and_164;
    wire signal_and_165;
    wire [1:0] signal_mux_114;
    wire [1:0] signal_mux_115;
    wire [1:0] signal_wire_57;
    reg [1:0] signal_reg_57;
    wire [7:0] signal_select_64;
    wire [15:0] rx_head;
    wire [15:0] signal_wire_58;
    wire [7:0] signal_select_65;
    wire [7:0] signal_const_244;
    wire [15:0] signal_cat;
    wire [23:0] signal_wire_59;
    wire [15:0] signal_select_66;
    wire [7:0] signal_select_67;
    wire [15:0] signal_cat_1;
    wire [23:0] signal_wire_60;
    wire [15:0] signal_select_68;
    wire [8:0] signal_wire_61;
    wire [15:0] signal_cat_2;
    wire signal_wire_62;
    wire signal_wire_63;
    wire signal_wire_64;
    wire signal_wire_65;
    wire signal_wire_66;
    wire [3:0] signal_wire_67;
    wire [3:0] signal_wire_68;
    wire [15:0] signal_cat_3;
    reg [15:0] signal_cases;
    wire [15:0] signal_wire_69;
    wire [7:0] signal_select_69;
    wire [15:0] signal_cat_4;
    wire [23:0] signal_wire_70;
    wire [15:0] signal_select_70;
    wire [7:0] signal_select_71;
    wire [15:0] signal_cat_5;
    wire [23:0] signal_wire_71;
    wire [15:0] signal_select_72;
    wire [8:0] signal_wire_72;
    wire [15:0] signal_cat_6;
    wire signal_wire_73;
    wire signal_wire_74;
    wire signal_wire_75;
    wire signal_wire_76;
    wire signal_wire_77;
    wire signal_wire_78;
    wire [3:0] signal_wire_79;
    wire [3:0] signal_wire_80;
    wire signal_wire_81;
    wire [15:0] signal_cat_7;
    reg [15:0] signal_cases_1;
    wire [15:0] signal_mux_116;
    wire [14:0] signal_const_266;
    wire [15:0] signal_cat_8;
    wire [4:0] signal_wire_82;
    wire [10:0] signal_const_268;
    wire [15:0] signal_cat_9;
    wire [9:0] signal_wire_83;
    wire [5:0] signal_const_270;
    wire [15:0] signal_cat_10;
    wire signal_wire_84;
    wire signal_wire_85;
    wire signal_wire_86;
    wire signal_wire_87;
    wire signal_mux_117;
    wire signal_wire_88;
    wire signal_wire_89;
    wire signal_select_73;
    wire [6:0] signal_const_273;
    wire signal_eq_183;
    wire signal_mux_118;
    wire signal_mux_119;
    wire signal_wire_90;
    reg select;
    wire signal_mux_120;
    wire [3:0] check_status;
    wire [11:0] signal_const_274;
    wire [15:0] signal_cat_11;
    wire [1:0] signal_select_74;
    wire [6:0] signal_const_277;
    wire signal_eq_184;
    wire [1:0] signal_mux_121;
    wire [1:0] signal_mux_122;
    wire [1:0] signal_wire_91;
    reg [1:0] check_flags;
    wire [13:0] signal_const_278;
    wire [15:0] signal_cat_12;
    wire [6:0] signal_const_281;
    wire signal_eq_185;
    wire [15:0] signal_mux_123;
    wire [15:0] signal_mux_124;
    wire [15:0] signal_wire_92;
    reg [15:0] check_loaded;
    wire [8:0] signal_select_75;
    wire [6:0] signal_const_284;
    wire signal_eq_186;
    wire [8:0] signal_mux_125;
    wire [8:0] signal_mux_126;
    wire [8:0] signal_wire_93;
    reg [8:0] check_base;
    wire [15:0] signal_cat_13;
    wire [8:0] signal_const_288;
    wire [8:0] signal_add;
    wire [8:0] signal_select_76;
    wire [6:0] signal_const_289;
    wire signal_eq_187;
    wire [8:0] signal_mux_127;
    wire signal_eq_188;
    wire [8:0] signal_mux_128;
    wire [8:0] signal_mux_129;
    wire [8:0] signal_wire_94;
    reg [8:0] data_addr;
    wire [15:0] signal_cat_14;
    wire [8:0] signal_add_1;
    reg [7:0] signal_cases_2;
    wire [7:0] signal_mux_130;
    wire [7:0] signal_wire_95;
    reg [7:0] high;
    wire [15:0] value;
    wire [8:0] signal_select_77;
    wire [6:0] signal_const_296;
    wire signal_eq_189;
    wire [8:0] signal_mux_131;
    wire signal_eq_190;
    wire [8:0] signal_mux_132;
    wire signal_mux_133;
    reg signal_cases_3;
    wire signal_mux_134;
    wire write;
    wire [8:0] signal_mux_135;
    wire [8:0] signal_wire_96;
    reg [8:0] program_addr;
    wire [15:0] signal_cat_15;
    wire [7:0] spi_rx_byte;
    wire [6:0] signal_select_78;
    wire signal_eq_191;
    wire [6:0] read_addr;
    reg [15:0] read_value;
    reg [15:0] signal_cases_4;
    wire [15:0] signal_mux_136;
    wire vdd;
    wire is_write;
    wire signal_mux_137;
    reg signal_cases_5;
    wire gnd;
    wire signal_mux_138;
    wire read_done;
    wire [15:0] signal_mux_139;
    wire [15:0] signal_wire_97;
    reg [15:0] word;
    wire [7:0] signal_select_79;
    reg [7:0] signal_cases_6;
    wire [7:0] signal_mux_140;
    wire [7:0] signal_wire_98;
    reg [7:0] cmd;
    wire [6:0] addr;
    wire signal_eq_192;
    wire [15:0] tx_word;
    wire [7:0] signal_select_80;
    wire [1:0] signal_const_303;
    reg [1:0] signal_cases_7;
    wire signal_select_81;
    wire [1:0] signal_mux_141;
    wire signal_select_82;
    wire [1:0] signal_mux_142;
    wire [1:0] signal_wire_99;
    (* fsm_encoding="one_hot" *)
    reg [1:0] sm;
    wire [1:0] signal_const_305;
    wire signal_eq_193;
    wire [7:0] signal_mux_143;
    wire signal_wire_100;
    wire signal_wire_101;
    wire signal_wire_102;
    wire signal_wire_103;
    wire signal_wire_104;
    wire [11:0] signal_inst;
    wire signal_select_83;
    assign signal_select = check_flags[1:1];
    assign signal_select_1 = check_flags[0:0];
    assign signal_const = 1'b1;
    assign signal_eq = select == signal_const;
    assign signal_and = writes_config & signal_eq;
    assign signal_and_1 = signal_and & signal_wire_62;
    assign signal_eq_1 = select == signal_const;
    assign signal_select_2 = value[4:4];
    assign signal_const_2 = 7'b0000000;
    assign signal_eq_2 = addr == signal_const_2;
    assign signal_and_2 = write & signal_eq_2;
    assign signal_and_3 = signal_and_2 & signal_select_2;
    assign signal_and_4 = signal_and_3 & signal_eq_1;
    assign signal_eq_3 = select == signal_const;
    assign signal_select_3 = value[3:3];
    assign signal_eq_4 = addr == signal_const_2;
    assign signal_and_5 = write & signal_eq_4;
    assign signal_and_6 = signal_and_5 & signal_select_3;
    assign signal_and_7 = signal_and_6 & signal_eq_3;
    assign signal_eq_5 = select == signal_const;
    assign signal_select_4 = value[2:2];
    assign signal_eq_6 = addr == signal_const_2;
    assign signal_and_8 = write & signal_eq_6;
    assign signal_and_9 = signal_and_8 & signal_select_4;
    assign signal_and_10 = signal_and_9 & signal_eq_5;
    assign signal_eq_7 = select == signal_const;
    assign signal_select_5 = value[1:1];
    assign signal_eq_8 = addr == signal_const_2;
    assign signal_and_11 = write & signal_eq_8;
    assign signal_and_12 = signal_and_11 & signal_select_5;
    assign signal_and_13 = signal_and_12 & signal_eq_7;
    assign signal_eq_9 = select == signal_const;
    assign signal_const_10 = 7'b0001000;
    assign signal_eq_10 = addr == signal_const_10;
    assign signal_and_14 = read_done & signal_eq_10;
    assign signal_and_15 = signal_and_14 & signal_eq_9;
    assign signal_eq_11 = select == signal_const;
    assign signal_const_12 = 7'b0000111;
    assign signal_eq_12 = addr == signal_const_12;
    assign signal_and_16 = write & signal_eq_12;
    assign signal_and_17 = signal_and_16 & signal_eq_11;
    assign signal_eq_13 = select == signal_const;
    assign signal_const_14 = 7'b0001101;
    assign signal_eq_14 = addr == signal_const_14;
    assign signal_and_18 = write & signal_eq_14;
    assign signal_and_19 = signal_and_18 & signal_eq_13;
    assign signal_eq_15 = select == signal_const;
    assign signal_const_16 = 7'b0001010;
    assign signal_eq_16 = addr == signal_const_16;
    assign signal_and_20 = write & signal_eq_16;
    assign signal_and_21 = signal_and_20 & signal_eq_15;
    assign signal_eq_17 = select == signal_const;
    assign signal_select_6 = value[0:0];
    assign signal_eq_18 = addr == signal_const_2;
    assign signal_and_22 = write & signal_eq_18;
    assign signal_and_23 = signal_and_22 & signal_select_6;
    assign signal_and_24 = signal_and_23 & signal_eq_17;
    assign signal_const_19 = 1'b0;
    assign signal_select_7 = value[0:0];
    assign signal_eq_19 = select == signal_const;
    assign signal_const_21 = 7'b0101110;
    assign signal_eq_20 = addr == signal_const_21;
    assign signal_and_25 = signal_eq_20 & signal_eq_19;
    assign signal_and_26 = signal_and_25 & signal_wire_62;
    assign signal_mux = signal_and_26 ? signal_select_7 : signal_reg;
    assign signal_mux_1 = write ? signal_mux : signal_reg;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg <= signal_const_19;
        else
            signal_reg <= signal_wire;
    end
    assign signal_select_8 = value[0:0];
    assign signal_eq_21 = select == signal_const;
    assign signal_const_24 = 7'b0101101;
    assign signal_eq_22 = addr == signal_const_24;
    assign signal_and_27 = signal_eq_22 & signal_eq_21;
    assign signal_and_28 = signal_and_27 & signal_wire_62;
    assign signal_mux_2 = signal_and_28 ? signal_select_8 : signal_reg_1;
    assign signal_mux_3 = write ? signal_mux_2 : signal_reg_1;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_1 <= signal_const_19;
        else
            signal_reg_1 <= signal_wire_1;
    end
    assign signal_const_25 = 16'b0000000000000000;
    assign signal_eq_23 = select == signal_const;
    assign signal_const_27 = 7'b0101010;
    assign signal_eq_24 = addr == signal_const_27;
    assign signal_and_29 = signal_eq_24 & signal_eq_23;
    assign signal_and_30 = signal_and_29 & signal_wire_62;
    assign signal_mux_4 = signal_and_30 ? value : signal_reg_2;
    assign signal_mux_5 = write ? signal_mux_4 : signal_reg_2;
    assign signal_wire_2 = signal_mux_5;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_2 <= signal_const_25;
        else
            signal_reg_2 <= signal_wire_2;
    end
    assign signal_const_28 = 9'b000000000;
    assign signal_select_9 = value[8:0];
    assign signal_eq_25 = select == signal_const;
    assign signal_const_30 = 7'b0101001;
    assign signal_eq_26 = addr == signal_const_30;
    assign signal_and_31 = signal_eq_26 & signal_eq_25;
    assign signal_and_32 = signal_and_31 & signal_wire_62;
    assign signal_mux_6 = signal_and_32 ? signal_select_9 : signal_reg_3;
    assign signal_mux_7 = write ? signal_mux_6 : signal_reg_3;
    assign signal_wire_3 = signal_mux_7;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_3 <= signal_const_28;
        else
            signal_reg_3 <= signal_wire_3;
    end
    assign signal_select_10 = value[8:0];
    assign signal_eq_27 = select == signal_const;
    assign signal_const_33 = 7'b0101000;
    assign signal_eq_28 = addr == signal_const_33;
    assign signal_and_33 = signal_eq_28 & signal_eq_27;
    assign signal_and_34 = signal_and_33 & signal_wire_62;
    assign signal_mux_8 = signal_and_34 ? signal_select_10 : signal_reg_4;
    assign signal_mux_9 = write ? signal_mux_8 : signal_reg_4;
    assign signal_wire_4 = signal_mux_9;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_4 <= signal_const_28;
        else
            signal_reg_4 <= signal_wire_4;
    end
    assign signal_select_11 = value[0:0];
    assign signal_eq_29 = select == signal_const;
    assign signal_const_36 = 7'b0100111;
    assign signal_eq_30 = addr == signal_const_36;
    assign signal_and_35 = signal_eq_30 & signal_eq_29;
    assign signal_and_36 = signal_and_35 & signal_wire_62;
    assign signal_mux_10 = signal_and_36 ? signal_select_11 : signal_reg_5;
    assign signal_mux_11 = write ? signal_mux_10 : signal_reg_5;
    assign signal_wire_5 = signal_mux_11;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_5 <= signal_const_19;
        else
            signal_reg_5 <= signal_wire_5;
    end
    assign signal_const_37 = 5'b00000;
    assign signal_select_12 = value[4:0];
    assign signal_eq_31 = select == signal_const;
    assign signal_const_39 = 7'b0100110;
    assign signal_eq_32 = addr == signal_const_39;
    assign signal_and_37 = signal_eq_32 & signal_eq_31;
    assign signal_and_38 = signal_and_37 & signal_wire_62;
    assign signal_mux_12 = signal_and_38 ? signal_select_12 : signal_reg_6;
    assign signal_mux_13 = write ? signal_mux_12 : signal_reg_6;
    assign signal_wire_6 = signal_mux_13;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_6 <= signal_const_37;
        else
            signal_reg_6 <= signal_wire_6;
    end
    assign signal_select_13 = value[0:0];
    assign signal_eq_33 = select == signal_const;
    assign signal_const_42 = 7'b0100101;
    assign signal_eq_34 = addr == signal_const_42;
    assign signal_and_39 = signal_eq_34 & signal_eq_33;
    assign signal_and_40 = signal_and_39 & signal_wire_62;
    assign signal_mux_14 = signal_and_40 ? signal_select_13 : signal_reg_7;
    assign signal_mux_15 = write ? signal_mux_14 : signal_reg_7;
    assign signal_wire_7 = signal_mux_15;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_7 <= signal_const_19;
        else
            signal_reg_7 <= signal_wire_7;
    end
    assign signal_eq_35 = select == signal_const;
    assign signal_const_45 = 7'b0100100;
    assign signal_eq_36 = addr == signal_const_45;
    assign signal_and_41 = signal_eq_36 & signal_eq_35;
    assign signal_and_42 = signal_and_41 & signal_wire_62;
    assign signal_mux_16 = signal_and_42 ? value : signal_reg_8;
    assign signal_mux_17 = write ? signal_mux_16 : signal_reg_8;
    assign signal_wire_8 = signal_mux_17;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_8 <= signal_const_25;
        else
            signal_reg_8 <= signal_wire_8;
    end
    assign signal_eq_37 = select == signal_const;
    assign signal_const_48 = 7'b0100011;
    assign signal_eq_38 = addr == signal_const_48;
    assign signal_and_43 = signal_eq_38 & signal_eq_37;
    assign signal_and_44 = signal_and_43 & signal_wire_62;
    assign signal_mux_18 = signal_and_44 ? value : signal_reg_9;
    assign signal_mux_19 = write ? signal_mux_18 : signal_reg_9;
    assign signal_wire_9 = signal_mux_19;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_9 <= signal_const_25;
        else
            signal_reg_9 <= signal_wire_9;
    end
    assign signal_select_14 = value[4:0];
    assign signal_eq_39 = select == signal_const;
    assign signal_const_51 = 7'b0100010;
    assign signal_eq_40 = addr == signal_const_51;
    assign signal_and_45 = signal_eq_40 & signal_eq_39;
    assign signal_and_46 = signal_and_45 & signal_wire_62;
    assign signal_mux_20 = signal_and_46 ? signal_select_14 : signal_reg_10;
    assign signal_mux_21 = write ? signal_mux_20 : signal_reg_10;
    assign signal_wire_10 = signal_mux_21;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_10 <= signal_const_37;
        else
            signal_reg_10 <= signal_wire_10;
    end
    assign signal_select_15 = value[4:0];
    assign signal_eq_41 = select == signal_const;
    assign signal_const_54 = 7'b0100001;
    assign signal_eq_42 = addr == signal_const_54;
    assign signal_and_47 = signal_eq_42 & signal_eq_41;
    assign signal_and_48 = signal_and_47 & signal_wire_62;
    assign signal_mux_22 = signal_and_48 ? signal_select_15 : signal_reg_11;
    assign signal_mux_23 = write ? signal_mux_22 : signal_reg_11;
    assign signal_wire_11 = signal_mux_23;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_11 <= signal_const_37;
        else
            signal_reg_11 <= signal_wire_11;
    end
    assign signal_select_16 = value[0:0];
    assign signal_eq_43 = select == signal_const;
    assign signal_const_57 = 7'b0100000;
    assign signal_eq_44 = addr == signal_const_57;
    assign signal_and_49 = signal_eq_44 & signal_eq_43;
    assign signal_and_50 = signal_and_49 & signal_wire_62;
    assign signal_mux_24 = signal_and_50 ? signal_select_16 : signal_reg_12;
    assign signal_mux_25 = write ? signal_mux_24 : signal_reg_12;
    assign signal_wire_12 = signal_mux_25;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_12 <= signal_const_19;
        else
            signal_reg_12 <= signal_wire_12;
    end
    assign signal_select_17 = value[4:0];
    assign signal_eq_45 = select == signal_const;
    assign signal_const_60 = 7'b0011111;
    assign signal_eq_46 = addr == signal_const_60;
    assign signal_and_51 = signal_eq_46 & signal_eq_45;
    assign signal_and_52 = signal_and_51 & signal_wire_62;
    assign signal_mux_26 = signal_and_52 ? signal_select_17 : signal_reg_13;
    assign signal_mux_27 = write ? signal_mux_26 : signal_reg_13;
    assign signal_wire_13 = signal_mux_27;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_13 <= signal_const_37;
        else
            signal_reg_13 <= signal_wire_13;
    end
    assign signal_select_18 = value[0:0];
    assign signal_eq_47 = select == signal_const;
    assign signal_const_63 = 7'b0011110;
    assign signal_eq_48 = addr == signal_const_63;
    assign signal_and_53 = signal_eq_48 & signal_eq_47;
    assign signal_and_54 = signal_and_53 & signal_wire_62;
    assign signal_mux_28 = signal_and_54 ? signal_select_18 : signal_reg_14;
    assign signal_mux_29 = write ? signal_mux_28 : signal_reg_14;
    assign signal_wire_14 = signal_mux_29;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_14 <= signal_const_19;
        else
            signal_reg_14 <= signal_wire_14;
    end
    assign signal_select_19 = value[0:0];
    assign signal_eq_49 = select == signal_const;
    assign signal_const_66 = 7'b0011101;
    assign signal_eq_50 = addr == signal_const_66;
    assign signal_and_55 = signal_eq_50 & signal_eq_49;
    assign signal_and_56 = signal_and_55 & signal_wire_62;
    assign signal_mux_30 = signal_and_56 ? signal_select_19 : signal_reg_15;
    assign signal_mux_31 = write ? signal_mux_30 : signal_reg_15;
    assign signal_wire_15 = signal_mux_31;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_15 <= signal_const_19;
        else
            signal_reg_15 <= signal_wire_15;
    end
    assign signal_select_20 = value[0:0];
    assign signal_eq_51 = select == signal_const;
    assign signal_const_69 = 7'b0011100;
    assign signal_eq_52 = addr == signal_const_69;
    assign signal_and_57 = signal_eq_52 & signal_eq_51;
    assign signal_and_58 = signal_and_57 & signal_wire_62;
    assign signal_mux_32 = signal_and_58 ? signal_select_20 : signal_reg_16;
    assign signal_mux_33 = write ? signal_mux_32 : signal_reg_16;
    assign signal_wire_16 = signal_mux_33;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_16 <= signal_const_19;
        else
            signal_reg_16 <= signal_wire_16;
    end
    assign signal_select_21 = value[0:0];
    assign signal_eq_53 = select == signal_const;
    assign signal_const_72 = 7'b0011011;
    assign signal_eq_54 = addr == signal_const_72;
    assign signal_and_59 = signal_eq_54 & signal_eq_53;
    assign signal_and_60 = signal_and_59 & signal_wire_62;
    assign signal_mux_34 = signal_and_60 ? signal_select_21 : signal_reg_17;
    assign signal_mux_35 = write ? signal_mux_34 : signal_reg_17;
    assign signal_wire_17 = signal_mux_35;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_17 <= signal_const_19;
        else
            signal_reg_17 <= signal_wire_17;
    end
    assign signal_select_22 = value[4:0];
    assign signal_eq_55 = select == signal_const;
    assign signal_const_75 = 7'b0011010;
    assign signal_eq_56 = addr == signal_const_75;
    assign signal_and_61 = signal_eq_56 & signal_eq_55;
    assign signal_and_62 = signal_and_61 & signal_wire_62;
    assign signal_mux_36 = signal_and_62 ? signal_select_22 : signal_reg_18;
    assign signal_mux_37 = write ? signal_mux_36 : signal_reg_18;
    assign signal_wire_18 = signal_mux_37;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_18 <= signal_const_37;
        else
            signal_reg_18 <= signal_wire_18;
    end
    assign signal_select_23 = value[4:0];
    assign signal_eq_57 = select == signal_const;
    assign signal_const_78 = 7'b0011001;
    assign signal_eq_58 = addr == signal_const_78;
    assign signal_and_63 = signal_eq_58 & signal_eq_57;
    assign signal_and_64 = signal_and_63 & signal_wire_62;
    assign signal_mux_38 = signal_and_64 ? signal_select_23 : signal_reg_19;
    assign signal_mux_39 = write ? signal_mux_38 : signal_reg_19;
    assign signal_wire_19 = signal_mux_39;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_19 <= signal_const_37;
        else
            signal_reg_19 <= signal_wire_19;
    end
    assign signal_const_79 = 3'b000;
    assign signal_select_24 = value[2:0];
    assign signal_eq_59 = select == signal_const;
    assign signal_const_81 = 7'b0011000;
    assign signal_eq_60 = addr == signal_const_81;
    assign signal_and_65 = signal_eq_60 & signal_eq_59;
    assign signal_and_66 = signal_and_65 & signal_wire_62;
    assign signal_mux_40 = signal_and_66 ? signal_select_24 : signal_reg_20;
    assign signal_mux_41 = write ? signal_mux_40 : signal_reg_20;
    assign signal_wire_20 = signal_mux_41;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_20 <= signal_const_79;
        else
            signal_reg_20 <= signal_wire_20;
    end
    assign signal_select_25 = value[4:0];
    assign signal_eq_61 = select == signal_const;
    assign signal_const_84 = 7'b0010111;
    assign signal_eq_62 = addr == signal_const_84;
    assign signal_and_67 = signal_eq_62 & signal_eq_61;
    assign signal_and_68 = signal_and_67 & signal_wire_62;
    assign signal_mux_42 = signal_and_68 ? signal_select_25 : signal_reg_21;
    assign signal_mux_43 = write ? signal_mux_42 : signal_reg_21;
    assign signal_wire_21 = signal_mux_43;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_21 <= signal_const_37;
        else
            signal_reg_21 <= signal_wire_21;
    end
    assign signal_select_26 = value[4:0];
    assign signal_eq_63 = select == signal_const;
    assign signal_const_87 = 7'b0010110;
    assign signal_eq_64 = addr == signal_const_87;
    assign signal_and_69 = signal_eq_64 & signal_eq_63;
    assign signal_and_70 = signal_and_69 & signal_wire_62;
    assign signal_mux_44 = signal_and_70 ? signal_select_26 : signal_reg_22;
    assign signal_mux_45 = write ? signal_mux_44 : signal_reg_22;
    assign signal_wire_22 = signal_mux_45;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_22 <= signal_const_37;
        else
            signal_reg_22 <= signal_wire_22;
    end
    assign signal_select_27 = value[4:0];
    assign signal_eq_65 = select == signal_const;
    assign signal_const_90 = 7'b0010101;
    assign signal_eq_66 = addr == signal_const_90;
    assign signal_and_71 = signal_eq_66 & signal_eq_65;
    assign signal_and_72 = signal_and_71 & signal_wire_62;
    assign signal_mux_46 = signal_and_72 ? signal_select_27 : signal_reg_23;
    assign signal_mux_47 = write ? signal_mux_46 : signal_reg_23;
    assign signal_wire_23 = signal_mux_47;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_23 <= signal_const_37;
        else
            signal_reg_23 <= signal_wire_23;
    end
    assign signal_select_28 = value[4:0];
    assign signal_eq_67 = select == signal_const;
    assign signal_const_93 = 7'b0010100;
    assign signal_eq_68 = addr == signal_const_93;
    assign signal_and_73 = signal_eq_68 & signal_eq_67;
    assign signal_and_74 = signal_and_73 & signal_wire_62;
    assign signal_mux_48 = signal_and_74 ? signal_select_28 : signal_reg_24;
    assign signal_mux_49 = write ? signal_mux_48 : signal_reg_24;
    assign signal_wire_24 = signal_mux_49;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_24 <= signal_const_37;
        else
            signal_reg_24 <= signal_wire_24;
    end
    assign signal_select_29 = value[4:0];
    assign signal_eq_69 = select == signal_const;
    assign signal_const_96 = 7'b0010011;
    assign signal_eq_70 = addr == signal_const_96;
    assign signal_and_75 = signal_eq_70 & signal_eq_69;
    assign signal_and_76 = signal_and_75 & signal_wire_62;
    assign signal_mux_50 = signal_and_76 ? signal_select_29 : signal_reg_25;
    assign signal_mux_51 = write ? signal_mux_50 : signal_reg_25;
    assign signal_wire_25 = signal_mux_51;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_25 <= signal_const_37;
        else
            signal_reg_25 <= signal_wire_25;
    end
    assign signal_select_30 = value[0:0];
    assign signal_eq_71 = select == signal_const;
    assign signal_const_99 = 7'b0010010;
    assign signal_eq_72 = addr == signal_const_99;
    assign signal_and_77 = signal_eq_72 & signal_eq_71;
    assign signal_and_78 = signal_and_77 & signal_wire_62;
    assign signal_mux_52 = signal_and_78 ? signal_select_30 : signal_reg_26;
    assign signal_mux_53 = write ? signal_mux_52 : signal_reg_26;
    assign signal_wire_26 = signal_mux_53;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_26 <= signal_const_19;
        else
            signal_reg_26 <= signal_wire_26;
    end
    assign signal_select_31 = value[4:0];
    assign signal_eq_73 = select == signal_const;
    assign signal_const_102 = 7'b0010001;
    assign signal_eq_74 = addr == signal_const_102;
    assign signal_and_79 = signal_eq_74 & signal_eq_73;
    assign signal_and_80 = signal_and_79 & signal_wire_62;
    assign signal_mux_54 = signal_and_80 ? signal_select_31 : signal_reg_27;
    assign signal_mux_55 = write ? signal_mux_54 : signal_reg_27;
    assign signal_wire_27 = signal_mux_55;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_27 <= signal_const_37;
        else
            signal_reg_27 <= signal_wire_27;
    end
    assign signal_const_103 = 2'b00;
    assign signal_select_32 = value[1:0];
    assign signal_eq_75 = select == signal_const;
    assign signal_const_105 = 7'b0010000;
    assign signal_eq_76 = addr == signal_const_105;
    assign signal_and_81 = signal_eq_76 & signal_eq_75;
    assign signal_and_82 = signal_and_81 & signal_wire_62;
    assign signal_mux_56 = signal_and_82 ? signal_select_32 : signal_reg_28;
    assign signal_mux_57 = write ? signal_mux_56 : signal_reg_28;
    assign signal_wire_28 = signal_mux_57;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_28 <= signal_const_103;
        else
            signal_reg_28 <= signal_wire_28;
    end
    assign signal_eq_77 = select == signal_const_19;
    assign signal_eq_78 = addr == signal_const_21;
    assign signal_eq_79 = addr == signal_const_24;
    assign signal_eq_80 = addr == signal_const_27;
    assign signal_eq_81 = addr == signal_const_30;
    assign signal_eq_82 = addr == signal_const_33;
    assign signal_eq_83 = addr == signal_const_36;
    assign signal_eq_84 = addr == signal_const_39;
    assign signal_eq_85 = addr == signal_const_42;
    assign signal_eq_86 = addr == signal_const_45;
    assign signal_eq_87 = addr == signal_const_48;
    assign signal_eq_88 = addr == signal_const_51;
    assign signal_eq_89 = addr == signal_const_54;
    assign signal_eq_90 = addr == signal_const_57;
    assign signal_eq_91 = addr == signal_const_60;
    assign signal_eq_92 = addr == signal_const_63;
    assign signal_eq_93 = addr == signal_const_66;
    assign signal_eq_94 = addr == signal_const_69;
    assign signal_eq_95 = addr == signal_const_72;
    assign signal_eq_96 = addr == signal_const_75;
    assign signal_eq_97 = addr == signal_const_78;
    assign signal_eq_98 = addr == signal_const_81;
    assign signal_eq_99 = addr == signal_const_84;
    assign signal_eq_100 = addr == signal_const_87;
    assign signal_eq_101 = addr == signal_const_90;
    assign signal_eq_102 = addr == signal_const_93;
    assign signal_eq_103 = addr == signal_const_96;
    assign signal_eq_104 = addr == signal_const_99;
    assign signal_eq_105 = addr == signal_const_102;
    assign signal_eq_106 = addr == signal_const_105;
    assign signal_or = signal_eq_106 | signal_eq_105;
    assign signal_or_1 = signal_or | signal_eq_104;
    assign signal_or_2 = signal_or_1 | signal_eq_103;
    assign signal_or_3 = signal_or_2 | signal_eq_102;
    assign signal_or_4 = signal_or_3 | signal_eq_101;
    assign signal_or_5 = signal_or_4 | signal_eq_100;
    assign signal_or_6 = signal_or_5 | signal_eq_99;
    assign signal_or_7 = signal_or_6 | signal_eq_98;
    assign signal_or_8 = signal_or_7 | signal_eq_97;
    assign signal_or_9 = signal_or_8 | signal_eq_96;
    assign signal_or_10 = signal_or_9 | signal_eq_95;
    assign signal_or_11 = signal_or_10 | signal_eq_94;
    assign signal_or_12 = signal_or_11 | signal_eq_93;
    assign signal_or_13 = signal_or_12 | signal_eq_92;
    assign signal_or_14 = signal_or_13 | signal_eq_91;
    assign signal_or_15 = signal_or_14 | signal_eq_90;
    assign signal_or_16 = signal_or_15 | signal_eq_89;
    assign signal_or_17 = signal_or_16 | signal_eq_88;
    assign signal_or_18 = signal_or_17 | signal_eq_87;
    assign signal_or_19 = signal_or_18 | signal_eq_86;
    assign signal_or_20 = signal_or_19 | signal_eq_85;
    assign signal_or_21 = signal_or_20 | signal_eq_84;
    assign signal_or_22 = signal_or_21 | signal_eq_83;
    assign signal_or_23 = signal_or_22 | signal_eq_82;
    assign signal_or_24 = signal_or_23 | signal_eq_81;
    assign signal_or_25 = signal_or_24 | signal_eq_80;
    assign signal_or_26 = signal_or_25 | signal_eq_79;
    assign signal_or_27 = signal_or_26 | signal_eq_78;
    assign writes_config = write & signal_or_27;
    assign signal_and_83 = writes_config & signal_eq_77;
    assign signal_and_84 = signal_and_83 & signal_wire_73;
    assign signal_eq_107 = select == signal_const_19;
    assign signal_select_33 = value[4:4];
    assign signal_eq_108 = addr == signal_const_2;
    assign signal_and_85 = write & signal_eq_108;
    assign signal_and_86 = signal_and_85 & signal_select_33;
    assign signal_and_87 = signal_and_86 & signal_eq_107;
    assign signal_eq_109 = select == signal_const_19;
    assign signal_select_34 = value[3:3];
    assign signal_eq_110 = addr == signal_const_2;
    assign signal_and_88 = write & signal_eq_110;
    assign signal_and_89 = signal_and_88 & signal_select_34;
    assign signal_and_90 = signal_and_89 & signal_eq_109;
    assign signal_eq_111 = select == signal_const_19;
    assign signal_select_35 = value[2:2];
    assign signal_eq_112 = addr == signal_const_2;
    assign signal_and_91 = write & signal_eq_112;
    assign signal_and_92 = signal_and_91 & signal_select_35;
    assign signal_and_93 = signal_and_92 & signal_eq_111;
    assign signal_eq_113 = select == signal_const_19;
    assign signal_select_36 = value[1:1];
    assign signal_eq_114 = addr == signal_const_2;
    assign signal_and_94 = write & signal_eq_114;
    assign signal_and_95 = signal_and_94 & signal_select_36;
    assign signal_and_96 = signal_and_95 & signal_eq_113;
    assign signal_eq_115 = select == signal_const_19;
    assign signal_eq_116 = addr == signal_const_10;
    assign signal_and_97 = read_done & signal_eq_116;
    assign signal_and_98 = signal_and_97 & signal_eq_115;
    assign signal_eq_117 = select == signal_const_19;
    assign signal_eq_118 = addr == signal_const_12;
    assign signal_and_99 = write & signal_eq_118;
    assign signal_and_100 = signal_and_99 & signal_eq_117;
    assign signal_eq_119 = select == signal_const_19;
    assign signal_eq_120 = addr == signal_const_14;
    assign signal_and_101 = write & signal_eq_120;
    assign signal_and_102 = signal_and_101 & signal_eq_119;
    assign signal_eq_121 = select == signal_const_19;
    assign signal_eq_122 = addr == signal_const_16;
    assign signal_and_103 = write & signal_eq_122;
    assign signal_and_104 = signal_and_103 & signal_eq_121;
    assign signal_eq_123 = select == signal_const_19;
    assign signal_select_37 = value[0:0];
    assign signal_eq_124 = addr == signal_const_2;
    assign signal_and_105 = write & signal_eq_124;
    assign signal_and_106 = signal_and_105 & signal_select_37;
    assign signal_and_107 = signal_and_106 & signal_eq_123;
    assign signal_select_38 = value[0:0];
    assign signal_eq_125 = select == signal_const_19;
    assign signal_eq_126 = addr == signal_const_21;
    assign signal_and_108 = signal_eq_126 & signal_eq_125;
    assign signal_and_109 = signal_and_108 & signal_wire_73;
    assign signal_mux_58 = signal_and_109 ? signal_select_38 : signal_reg_29;
    assign signal_mux_59 = write ? signal_mux_58 : signal_reg_29;
    assign signal_wire_29 = signal_mux_59;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_29 <= signal_const_19;
        else
            signal_reg_29 <= signal_wire_29;
    end
    assign signal_select_39 = value[0:0];
    assign signal_eq_127 = select == signal_const_19;
    assign signal_eq_128 = addr == signal_const_24;
    assign signal_and_110 = signal_eq_128 & signal_eq_127;
    assign signal_and_111 = signal_and_110 & signal_wire_73;
    assign signal_mux_60 = signal_and_111 ? signal_select_39 : signal_reg_30;
    assign signal_mux_61 = write ? signal_mux_60 : signal_reg_30;
    assign signal_wire_30 = signal_mux_61;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_30 <= signal_const_19;
        else
            signal_reg_30 <= signal_wire_30;
    end
    assign signal_eq_129 = select == signal_const_19;
    assign signal_eq_130 = addr == signal_const_27;
    assign signal_and_112 = signal_eq_130 & signal_eq_129;
    assign signal_and_113 = signal_and_112 & signal_wire_73;
    assign signal_mux_62 = signal_and_113 ? value : signal_reg_31;
    assign signal_mux_63 = write ? signal_mux_62 : signal_reg_31;
    assign signal_wire_31 = signal_mux_63;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_31 <= signal_const_25;
        else
            signal_reg_31 <= signal_wire_31;
    end
    assign signal_select_40 = value[8:0];
    assign signal_eq_131 = select == signal_const_19;
    assign signal_eq_132 = addr == signal_const_30;
    assign signal_and_114 = signal_eq_132 & signal_eq_131;
    assign signal_and_115 = signal_and_114 & signal_wire_73;
    assign signal_mux_64 = signal_and_115 ? signal_select_40 : signal_reg_32;
    assign signal_mux_65 = write ? signal_mux_64 : signal_reg_32;
    assign signal_wire_32 = signal_mux_65;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_32 <= signal_const_28;
        else
            signal_reg_32 <= signal_wire_32;
    end
    assign signal_select_41 = value[8:0];
    assign signal_eq_133 = select == signal_const_19;
    assign signal_eq_134 = addr == signal_const_33;
    assign signal_and_116 = signal_eq_134 & signal_eq_133;
    assign signal_and_117 = signal_and_116 & signal_wire_73;
    assign signal_mux_66 = signal_and_117 ? signal_select_41 : signal_reg_33;
    assign signal_mux_67 = write ? signal_mux_66 : signal_reg_33;
    assign signal_wire_33 = signal_mux_67;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_33 <= signal_const_28;
        else
            signal_reg_33 <= signal_wire_33;
    end
    assign signal_select_42 = value[0:0];
    assign signal_eq_135 = select == signal_const_19;
    assign signal_eq_136 = addr == signal_const_36;
    assign signal_and_118 = signal_eq_136 & signal_eq_135;
    assign signal_and_119 = signal_and_118 & signal_wire_73;
    assign signal_mux_68 = signal_and_119 ? signal_select_42 : signal_reg_34;
    assign signal_mux_69 = write ? signal_mux_68 : signal_reg_34;
    assign signal_wire_34 = signal_mux_69;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_34 <= signal_const_19;
        else
            signal_reg_34 <= signal_wire_34;
    end
    assign signal_select_43 = value[4:0];
    assign signal_eq_137 = select == signal_const_19;
    assign signal_eq_138 = addr == signal_const_39;
    assign signal_and_120 = signal_eq_138 & signal_eq_137;
    assign signal_and_121 = signal_and_120 & signal_wire_73;
    assign signal_mux_70 = signal_and_121 ? signal_select_43 : signal_reg_35;
    assign signal_mux_71 = write ? signal_mux_70 : signal_reg_35;
    assign signal_wire_35 = signal_mux_71;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_35 <= signal_const_37;
        else
            signal_reg_35 <= signal_wire_35;
    end
    assign signal_select_44 = value[0:0];
    assign signal_eq_139 = select == signal_const_19;
    assign signal_eq_140 = addr == signal_const_42;
    assign signal_and_122 = signal_eq_140 & signal_eq_139;
    assign signal_and_123 = signal_and_122 & signal_wire_73;
    assign signal_mux_72 = signal_and_123 ? signal_select_44 : signal_reg_36;
    assign signal_mux_73 = write ? signal_mux_72 : signal_reg_36;
    assign signal_wire_36 = signal_mux_73;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_36 <= signal_const_19;
        else
            signal_reg_36 <= signal_wire_36;
    end
    assign signal_eq_141 = select == signal_const_19;
    assign signal_eq_142 = addr == signal_const_45;
    assign signal_and_124 = signal_eq_142 & signal_eq_141;
    assign signal_and_125 = signal_and_124 & signal_wire_73;
    assign signal_mux_74 = signal_and_125 ? value : signal_reg_37;
    assign signal_mux_75 = write ? signal_mux_74 : signal_reg_37;
    assign signal_wire_37 = signal_mux_75;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_37 <= signal_const_25;
        else
            signal_reg_37 <= signal_wire_37;
    end
    assign signal_eq_143 = select == signal_const_19;
    assign signal_eq_144 = addr == signal_const_48;
    assign signal_and_126 = signal_eq_144 & signal_eq_143;
    assign signal_and_127 = signal_and_126 & signal_wire_73;
    assign signal_mux_76 = signal_and_127 ? value : signal_reg_38;
    assign signal_mux_77 = write ? signal_mux_76 : signal_reg_38;
    assign signal_wire_38 = signal_mux_77;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_38 <= signal_const_25;
        else
            signal_reg_38 <= signal_wire_38;
    end
    assign signal_select_45 = value[4:0];
    assign signal_eq_145 = select == signal_const_19;
    assign signal_eq_146 = addr == signal_const_51;
    assign signal_and_128 = signal_eq_146 & signal_eq_145;
    assign signal_and_129 = signal_and_128 & signal_wire_73;
    assign signal_mux_78 = signal_and_129 ? signal_select_45 : signal_reg_39;
    assign signal_mux_79 = write ? signal_mux_78 : signal_reg_39;
    assign signal_wire_39 = signal_mux_79;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_39 <= signal_const_37;
        else
            signal_reg_39 <= signal_wire_39;
    end
    assign signal_select_46 = value[4:0];
    assign signal_eq_147 = select == signal_const_19;
    assign signal_eq_148 = addr == signal_const_54;
    assign signal_and_130 = signal_eq_148 & signal_eq_147;
    assign signal_and_131 = signal_and_130 & signal_wire_73;
    assign signal_mux_80 = signal_and_131 ? signal_select_46 : signal_reg_40;
    assign signal_mux_81 = write ? signal_mux_80 : signal_reg_40;
    assign signal_wire_40 = signal_mux_81;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_40 <= signal_const_37;
        else
            signal_reg_40 <= signal_wire_40;
    end
    assign signal_select_47 = value[0:0];
    assign signal_eq_149 = select == signal_const_19;
    assign signal_eq_150 = addr == signal_const_57;
    assign signal_and_132 = signal_eq_150 & signal_eq_149;
    assign signal_and_133 = signal_and_132 & signal_wire_73;
    assign signal_mux_82 = signal_and_133 ? signal_select_47 : signal_reg_41;
    assign signal_mux_83 = write ? signal_mux_82 : signal_reg_41;
    assign signal_wire_41 = signal_mux_83;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_41 <= signal_const_19;
        else
            signal_reg_41 <= signal_wire_41;
    end
    assign signal_select_48 = value[4:0];
    assign signal_eq_151 = select == signal_const_19;
    assign signal_eq_152 = addr == signal_const_60;
    assign signal_and_134 = signal_eq_152 & signal_eq_151;
    assign signal_and_135 = signal_and_134 & signal_wire_73;
    assign signal_mux_84 = signal_and_135 ? signal_select_48 : signal_reg_42;
    assign signal_mux_85 = write ? signal_mux_84 : signal_reg_42;
    assign signal_wire_42 = signal_mux_85;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_42 <= signal_const_37;
        else
            signal_reg_42 <= signal_wire_42;
    end
    assign signal_select_49 = value[0:0];
    assign signal_eq_153 = select == signal_const_19;
    assign signal_eq_154 = addr == signal_const_63;
    assign signal_and_136 = signal_eq_154 & signal_eq_153;
    assign signal_and_137 = signal_and_136 & signal_wire_73;
    assign signal_mux_86 = signal_and_137 ? signal_select_49 : signal_reg_43;
    assign signal_mux_87 = write ? signal_mux_86 : signal_reg_43;
    assign signal_wire_43 = signal_mux_87;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_43 <= signal_const_19;
        else
            signal_reg_43 <= signal_wire_43;
    end
    assign signal_select_50 = value[0:0];
    assign signal_eq_155 = select == signal_const_19;
    assign signal_eq_156 = addr == signal_const_66;
    assign signal_and_138 = signal_eq_156 & signal_eq_155;
    assign signal_and_139 = signal_and_138 & signal_wire_73;
    assign signal_mux_88 = signal_and_139 ? signal_select_50 : signal_reg_44;
    assign signal_mux_89 = write ? signal_mux_88 : signal_reg_44;
    assign signal_wire_44 = signal_mux_89;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_44 <= signal_const_19;
        else
            signal_reg_44 <= signal_wire_44;
    end
    assign signal_select_51 = value[0:0];
    assign signal_eq_157 = select == signal_const_19;
    assign signal_eq_158 = addr == signal_const_69;
    assign signal_and_140 = signal_eq_158 & signal_eq_157;
    assign signal_and_141 = signal_and_140 & signal_wire_73;
    assign signal_mux_90 = signal_and_141 ? signal_select_51 : signal_reg_45;
    assign signal_mux_91 = write ? signal_mux_90 : signal_reg_45;
    assign signal_wire_45 = signal_mux_91;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_45 <= signal_const_19;
        else
            signal_reg_45 <= signal_wire_45;
    end
    assign signal_select_52 = value[0:0];
    assign signal_eq_159 = select == signal_const_19;
    assign signal_eq_160 = addr == signal_const_72;
    assign signal_and_142 = signal_eq_160 & signal_eq_159;
    assign signal_and_143 = signal_and_142 & signal_wire_73;
    assign signal_mux_92 = signal_and_143 ? signal_select_52 : signal_reg_46;
    assign signal_mux_93 = write ? signal_mux_92 : signal_reg_46;
    assign signal_wire_46 = signal_mux_93;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_46 <= signal_const_19;
        else
            signal_reg_46 <= signal_wire_46;
    end
    assign signal_select_53 = value[4:0];
    assign signal_eq_161 = select == signal_const_19;
    assign signal_eq_162 = addr == signal_const_75;
    assign signal_and_144 = signal_eq_162 & signal_eq_161;
    assign signal_and_145 = signal_and_144 & signal_wire_73;
    assign signal_mux_94 = signal_and_145 ? signal_select_53 : signal_reg_47;
    assign signal_mux_95 = write ? signal_mux_94 : signal_reg_47;
    assign signal_wire_47 = signal_mux_95;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_47 <= signal_const_37;
        else
            signal_reg_47 <= signal_wire_47;
    end
    assign signal_select_54 = value[4:0];
    assign signal_eq_163 = select == signal_const_19;
    assign signal_eq_164 = addr == signal_const_78;
    assign signal_and_146 = signal_eq_164 & signal_eq_163;
    assign signal_and_147 = signal_and_146 & signal_wire_73;
    assign signal_mux_96 = signal_and_147 ? signal_select_54 : signal_reg_48;
    assign signal_mux_97 = write ? signal_mux_96 : signal_reg_48;
    assign signal_wire_48 = signal_mux_97;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_48 <= signal_const_37;
        else
            signal_reg_48 <= signal_wire_48;
    end
    assign signal_select_55 = value[2:0];
    assign signal_eq_165 = select == signal_const_19;
    assign signal_eq_166 = addr == signal_const_81;
    assign signal_and_148 = signal_eq_166 & signal_eq_165;
    assign signal_and_149 = signal_and_148 & signal_wire_73;
    assign signal_mux_98 = signal_and_149 ? signal_select_55 : signal_reg_49;
    assign signal_mux_99 = write ? signal_mux_98 : signal_reg_49;
    assign signal_wire_49 = signal_mux_99;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_49 <= signal_const_79;
        else
            signal_reg_49 <= signal_wire_49;
    end
    assign signal_select_56 = value[4:0];
    assign signal_eq_167 = select == signal_const_19;
    assign signal_eq_168 = addr == signal_const_84;
    assign signal_and_150 = signal_eq_168 & signal_eq_167;
    assign signal_and_151 = signal_and_150 & signal_wire_73;
    assign signal_mux_100 = signal_and_151 ? signal_select_56 : signal_reg_50;
    assign signal_mux_101 = write ? signal_mux_100 : signal_reg_50;
    assign signal_wire_50 = signal_mux_101;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_50 <= signal_const_37;
        else
            signal_reg_50 <= signal_wire_50;
    end
    assign signal_select_57 = value[4:0];
    assign signal_eq_169 = select == signal_const_19;
    assign signal_eq_170 = addr == signal_const_87;
    assign signal_and_152 = signal_eq_170 & signal_eq_169;
    assign signal_and_153 = signal_and_152 & signal_wire_73;
    assign signal_mux_102 = signal_and_153 ? signal_select_57 : signal_reg_51;
    assign signal_mux_103 = write ? signal_mux_102 : signal_reg_51;
    assign signal_wire_51 = signal_mux_103;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_51 <= signal_const_37;
        else
            signal_reg_51 <= signal_wire_51;
    end
    assign signal_select_58 = value[4:0];
    assign signal_eq_171 = select == signal_const_19;
    assign signal_eq_172 = addr == signal_const_90;
    assign signal_and_154 = signal_eq_172 & signal_eq_171;
    assign signal_and_155 = signal_and_154 & signal_wire_73;
    assign signal_mux_104 = signal_and_155 ? signal_select_58 : signal_reg_52;
    assign signal_mux_105 = write ? signal_mux_104 : signal_reg_52;
    assign signal_wire_52 = signal_mux_105;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_52 <= signal_const_37;
        else
            signal_reg_52 <= signal_wire_52;
    end
    assign signal_select_59 = value[4:0];
    assign signal_eq_173 = select == signal_const_19;
    assign signal_eq_174 = addr == signal_const_93;
    assign signal_and_156 = signal_eq_174 & signal_eq_173;
    assign signal_and_157 = signal_and_156 & signal_wire_73;
    assign signal_mux_106 = signal_and_157 ? signal_select_59 : signal_reg_53;
    assign signal_mux_107 = write ? signal_mux_106 : signal_reg_53;
    assign signal_wire_53 = signal_mux_107;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_53 <= signal_const_37;
        else
            signal_reg_53 <= signal_wire_53;
    end
    assign signal_select_60 = value[4:0];
    assign signal_eq_175 = select == signal_const_19;
    assign signal_eq_176 = addr == signal_const_96;
    assign signal_and_158 = signal_eq_176 & signal_eq_175;
    assign signal_and_159 = signal_and_158 & signal_wire_73;
    assign signal_mux_108 = signal_and_159 ? signal_select_60 : signal_reg_54;
    assign signal_mux_109 = write ? signal_mux_108 : signal_reg_54;
    assign signal_wire_54 = signal_mux_109;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_54 <= signal_const_37;
        else
            signal_reg_54 <= signal_wire_54;
    end
    assign signal_select_61 = value[0:0];
    assign signal_eq_177 = select == signal_const_19;
    assign signal_eq_178 = addr == signal_const_99;
    assign signal_and_160 = signal_eq_178 & signal_eq_177;
    assign signal_and_161 = signal_and_160 & signal_wire_73;
    assign signal_mux_110 = signal_and_161 ? signal_select_61 : signal_reg_55;
    assign signal_mux_111 = write ? signal_mux_110 : signal_reg_55;
    assign signal_wire_55 = signal_mux_111;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_55 <= signal_const_19;
        else
            signal_reg_55 <= signal_wire_55;
    end
    assign signal_select_62 = value[4:0];
    assign signal_eq_179 = select == signal_const_19;
    assign signal_eq_180 = addr == signal_const_102;
    assign signal_and_162 = signal_eq_180 & signal_eq_179;
    assign signal_and_163 = signal_and_162 & signal_wire_73;
    assign signal_mux_112 = signal_and_163 ? signal_select_62 : signal_reg_56;
    assign signal_mux_113 = write ? signal_mux_112 : signal_reg_56;
    assign signal_wire_56 = signal_mux_113;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_56 <= signal_const_37;
        else
            signal_reg_56 <= signal_wire_56;
    end
    assign signal_select_63 = value[1:0];
    assign signal_eq_181 = select == signal_const_19;
    assign signal_eq_182 = addr == signal_const_105;
    assign signal_and_164 = signal_eq_182 & signal_eq_181;
    assign signal_and_165 = signal_and_164 & signal_wire_73;
    assign signal_mux_114 = signal_and_165 ? signal_select_63 : signal_reg_57;
    assign signal_mux_115 = write ? signal_mux_114 : signal_reg_57;
    assign signal_wire_57 = signal_mux_115;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            signal_reg_57 <= signal_const_103;
        else
            signal_reg_57 <= signal_wire_57;
    end
    assign signal_select_64 = tx_word[7:0];
    assign rx_head = select ? signal_wire_58 : signal_wire_69;
    assign signal_wire_58 = status$rx_head_1;
    assign signal_select_65 = signal_wire_59[23:16];
    assign signal_const_244 = 8'b00000000;
    assign signal_cat = { signal_const_244,
                          signal_select_65 };
    assign signal_wire_59 = status$capture_1;
    assign signal_select_66 = signal_wire_59[15:0];
    assign signal_select_67 = signal_wire_60[23:16];
    assign signal_cat_1 = { signal_const_244,
                            signal_select_67 };
    assign signal_wire_60 = status$now_1;
    assign signal_select_68 = signal_wire_60[15:0];
    assign signal_wire_61 = status$pc_1;
    assign signal_cat_2 = { signal_const_2,
                            signal_wire_61 };
    assign signal_wire_62 = status$halted_1;
    assign signal_wire_63 = status$fault$underflow_1;
    assign signal_wire_64 = status$fault$overflow_1;
    assign signal_wire_65 = status$fault$missed_deadline_1;
    assign signal_wire_66 = status$fault$decode_1;
    assign signal_wire_67 = status$tx_level_1;
    assign signal_wire_68 = status$rx_level_1;
    assign signal_cat_3 = { signal_wire_74,
                            signal_const_19,
                            signal_wire_68,
                            signal_wire_67,
                            signal_wire_66,
                            signal_wire_65,
                            signal_wire_64,
                            signal_wire_63,
                            signal_wire_81,
                            signal_wire_62 };
    always @* begin
        case (read_addr)
        7'b0000001:
            signal_cases <= signal_cat_3;
        7'b0000010:
            signal_cases <= signal_cat_2;
        7'b0000011:
            signal_cases <= signal_select_68;
        7'b0000100:
            signal_cases <= signal_cat_1;
        7'b0000101:
            signal_cases <= signal_select_66;
        7'b0000110:
            signal_cases <= signal_cat;
        7'b0001000:
            signal_cases <= signal_wire_58;
        default:
            signal_cases <= signal_const_25;
        endcase
    end
    assign signal_wire_69 = status$rx_head_0;
    assign signal_select_69 = signal_wire_70[23:16];
    assign signal_cat_4 = { signal_const_244,
                            signal_select_69 };
    assign signal_wire_70 = status$capture_0;
    assign signal_select_70 = signal_wire_70[15:0];
    assign signal_select_71 = signal_wire_71[23:16];
    assign signal_cat_5 = { signal_const_244,
                            signal_select_71 };
    assign signal_wire_71 = status$now_0;
    assign signal_select_72 = signal_wire_71[15:0];
    assign signal_wire_72 = status$pc_0;
    assign signal_cat_6 = { signal_const_2,
                            signal_wire_72 };
    assign signal_wire_73 = status$halted_0;
    assign signal_wire_74 = status$irq_0;
    assign signal_wire_75 = status$fault$underflow_0;
    assign signal_wire_76 = status$fault$overflow_0;
    assign signal_wire_77 = status$fault$missed_deadline_0;
    assign signal_wire_78 = status$fault$decode_0;
    assign signal_wire_79 = status$tx_level_0;
    assign signal_wire_80 = status$rx_level_0;
    assign signal_wire_81 = status$irq_1;
    assign signal_cat_7 = { signal_wire_81,
                            signal_const_19,
                            signal_wire_80,
                            signal_wire_79,
                            signal_wire_78,
                            signal_wire_77,
                            signal_wire_76,
                            signal_wire_75,
                            signal_wire_74,
                            signal_wire_73 };
    always @* begin
        case (read_addr)
        7'b0000001:
            signal_cases_1 <= signal_cat_7;
        7'b0000010:
            signal_cases_1 <= signal_cat_6;
        7'b0000011:
            signal_cases_1 <= signal_select_72;
        7'b0000100:
            signal_cases_1 <= signal_cat_5;
        7'b0000101:
            signal_cases_1 <= signal_select_70;
        7'b0000110:
            signal_cases_1 <= signal_cat_4;
        7'b0001000:
            signal_cases_1 <= signal_wire_69;
        default:
            signal_cases_1 <= signal_const_25;
        endcase
    end
    assign signal_mux_116 = select ? signal_cases : signal_cases_1;
    assign signal_const_266 = 15'b000000000000000;
    assign signal_cat_8 = { signal_const_266,
                            select };
    assign signal_wire_82 = check$reason;
    assign signal_const_268 = 11'b00000000000;
    assign signal_cat_9 = { signal_const_268,
                            signal_wire_82 };
    assign signal_wire_83 = check$reject_pc;
    assign signal_const_270 = 6'b000000;
    assign signal_cat_10 = { signal_const_270,
                             signal_wire_83 };
    assign signal_wire_84 = check$busy;
    assign signal_wire_85 = check$accepted;
    assign signal_wire_86 = status$certified_1;
    assign signal_wire_87 = status$certified_0;
    assign signal_mux_117 = select ? signal_wire_86 : signal_wire_87;
    assign signal_wire_88 = status$refused_1;
    assign signal_wire_89 = status$refused_0;
    assign signal_select_73 = value[0:0];
    assign signal_const_273 = 7'b0001011;
    assign signal_eq_183 = addr == signal_const_273;
    assign signal_mux_118 = signal_eq_183 ? signal_select_73 : select;
    assign signal_mux_119 = write ? signal_mux_118 : select;
    assign signal_wire_90 = signal_mux_119;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            select <= signal_const_19;
        else
            select <= signal_wire_90;
    end
    assign signal_mux_120 = select ? signal_wire_88 : signal_wire_89;
    assign check_status = { signal_mux_120,
                            signal_mux_117,
                            signal_wire_85,
                            signal_wire_84 };
    assign signal_const_274 = 12'b000000000000;
    assign signal_cat_11 = { signal_const_274,
                             check_status };
    assign signal_select_74 = value[1:0];
    assign signal_const_277 = 7'b1000010;
    assign signal_eq_184 = addr == signal_const_277;
    assign signal_mux_121 = signal_eq_184 ? signal_select_74 : check_flags;
    assign signal_mux_122 = write ? signal_mux_121 : check_flags;
    assign signal_wire_91 = signal_mux_122;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            check_flags <= signal_const_103;
        else
            check_flags <= signal_wire_91;
    end
    assign signal_const_278 = 14'b00000000000000;
    assign signal_cat_12 = { signal_const_278,
                             check_flags };
    assign signal_const_281 = 7'b1000001;
    assign signal_eq_185 = addr == signal_const_281;
    assign signal_mux_123 = signal_eq_185 ? value : check_loaded;
    assign signal_mux_124 = write ? signal_mux_123 : check_loaded;
    assign signal_wire_92 = signal_mux_124;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            check_loaded <= signal_const_25;
        else
            check_loaded <= signal_wire_92;
    end
    assign signal_select_75 = value[8:0];
    assign signal_const_284 = 7'b1000000;
    assign signal_eq_186 = addr == signal_const_284;
    assign signal_mux_125 = signal_eq_186 ? signal_select_75 : check_base;
    assign signal_mux_126 = write ? signal_mux_125 : check_base;
    assign signal_wire_93 = signal_mux_126;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            check_base <= signal_const_28;
        else
            check_base <= signal_wire_93;
    end
    assign signal_cat_13 = { signal_const_2,
                             check_base };
    assign signal_const_288 = 9'b000000001;
    assign signal_add = data_addr + signal_const_288;
    assign signal_select_76 = value[8:0];
    assign signal_const_289 = 7'b0001100;
    assign signal_eq_187 = addr == signal_const_289;
    assign signal_mux_127 = signal_eq_187 ? signal_select_76 : data_addr;
    assign signal_eq_188 = addr == signal_const_14;
    assign signal_mux_128 = signal_eq_188 ? signal_add : signal_mux_127;
    assign signal_mux_129 = write ? signal_mux_128 : data_addr;
    assign signal_wire_94 = signal_mux_129;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            data_addr <= signal_const_28;
        else
            data_addr <= signal_wire_94;
    end
    assign signal_cat_14 = { signal_const_2,
                             data_addr };
    assign signal_add_1 = program_addr + signal_const_288;
    always @* begin
        case (sm)
        2'b01:
            signal_cases_2 <= signal_select_79;
        default:
            signal_cases_2 <= high;
        endcase
    end
    assign signal_mux_130 = signal_select_82 ? signal_cases_2 : high;
    assign signal_wire_95 = signal_mux_130;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            high <= signal_const_244;
        else
            high <= signal_wire_95;
    end
    assign value = { high,
                     signal_select_79 };
    assign signal_select_77 = value[8:0];
    assign signal_const_296 = 7'b0001001;
    assign signal_eq_189 = addr == signal_const_296;
    assign signal_mux_131 = signal_eq_189 ? signal_select_77 : program_addr;
    assign signal_eq_190 = addr == signal_const_16;
    assign signal_mux_132 = signal_eq_190 ? signal_add_1 : signal_mux_131;
    assign signal_mux_133 = is_write ? vdd : gnd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_3 <= signal_mux_133;
        default:
            signal_cases_3 <= gnd;
        endcase
    end
    assign signal_mux_134 = signal_select_82 ? signal_cases_3 : gnd;
    assign write = signal_mux_134;
    assign signal_mux_135 = write ? signal_mux_132 : program_addr;
    assign signal_wire_96 = signal_mux_135;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            program_addr <= signal_const_28;
        else
            program_addr <= signal_wire_96;
    end
    assign signal_cat_15 = { signal_const_2,
                             program_addr };
    assign spi_rx_byte = signal_select_79;
    assign signal_select_78 = spi_rx_byte[6:0];
    assign signal_eq_191 = signal_const_103 == sm;
    assign read_addr = signal_eq_191 ? signal_select_78 : addr;
    always @* begin
        case (read_addr)
        7'b0001001:
            read_value <= signal_cat_15;
        7'b0001100:
            read_value <= signal_cat_14;
        7'b1000000:
            read_value <= signal_cat_13;
        7'b1000001:
            read_value <= check_loaded;
        7'b1000010:
            read_value <= signal_cat_12;
        7'b1000011:
            read_value <= signal_cat_11;
        7'b1000100:
            read_value <= signal_cat_10;
        7'b1000101:
            read_value <= signal_cat_9;
        7'b0001011:
            read_value <= signal_cat_8;
        default:
            read_value <= signal_mux_116;
        endcase
    end
    always @* begin
        case (sm)
        2'b00:
            signal_cases_4 <= read_value;
        default:
            signal_cases_4 <= word;
        endcase
    end
    assign signal_mux_136 = signal_select_82 ? signal_cases_4 : word;
    assign vdd = 1'b1;
    assign is_write = cmd[7:7];
    assign signal_mux_137 = is_write ? gnd : vdd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_5 <= signal_mux_137;
        default:
            signal_cases_5 <= gnd;
        endcase
    end
    assign gnd = 1'b0;
    assign signal_mux_138 = signal_select_82 ? signal_cases_5 : gnd;
    assign read_done = signal_mux_138;
    assign signal_mux_139 = read_done ? read_value : signal_mux_136;
    assign signal_wire_97 = signal_mux_139;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            word <= signal_const_25;
        else
            word <= signal_wire_97;
    end
    assign signal_select_79 = signal_inst[8:1];
    always @* begin
        case (sm)
        2'b00:
            signal_cases_6 <= signal_select_79;
        default:
            signal_cases_6 <= cmd;
        endcase
    end
    assign signal_mux_140 = signal_select_82 ? signal_cases_6 : cmd;
    assign signal_wire_98 = signal_mux_140;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            cmd <= signal_const_244;
        else
            cmd <= signal_wire_98;
    end
    assign addr = cmd[6:0];
    assign signal_eq_192 = addr == signal_const_10;
    assign tx_word = signal_eq_192 ? rx_head : word;
    assign signal_select_80 = tx_word[15:8];
    assign signal_const_303 = 2'b01;
    always @* begin
        case (sm)
        2'b00:
            signal_cases_7 <= signal_const_303;
        2'b01:
            signal_cases_7 <= signal_const_305;
        2'b10:
            signal_cases_7 <= signal_const_303;
        default:
            signal_cases_7 <= signal_mux_141;
        endcase
    end
    assign signal_select_81 = signal_inst[10:10];
    assign signal_mux_141 = signal_select_81 ? signal_const_103 : sm;
    assign signal_select_82 = signal_inst[9:9];
    assign signal_mux_142 = signal_select_82 ? signal_cases_7 : signal_mux_141;
    assign signal_wire_99 = signal_mux_142;
    always @(posedge signal_wire_104) begin
        if (signal_wire_103)
            sm <= signal_const_103;
        else
            sm <= signal_wire_99;
    end
    assign signal_const_305 = 2'b10;
    assign signal_eq_193 = signal_const_305 == sm;
    assign signal_mux_143 = signal_eq_193 ? signal_select_64 : signal_select_80;
    assign signal_wire_100 = cs_n;
    assign signal_wire_101 = mosi;
    assign signal_wire_102 = sck;
    assign signal_wire_103 = clear;
    assign signal_wire_104 = clock;
    host_spi
        host_spi
        ( .clock(signal_wire_104),
          .clear(signal_wire_103),
          .sck(signal_wire_102),
          .mosi(signal_wire_101),
          .cs_n(signal_wire_100),
          .tx_byte(signal_mux_143),
          .miso(signal_inst[0:0]),
          .rx_byte(signal_inst[8:1]),
          .rx_valid(signal_inst[9:9]),
          .frame_start(signal_inst[10:10]),
          .frame_end(signal_inst[11:11]) );
    assign signal_select_83 = signal_inst[0:0];
    assign miso = signal_select_83;
    assign engines$config$side_set_count_0 = signal_reg_57;
    assign engines$config$side_set_base_0 = signal_reg_56;
    assign engines$config$side_set_pindirs_0 = signal_reg_55;
    assign engines$config$in_base_0 = signal_reg_54;
    assign engines$config$in_count_0 = signal_reg_53;
    assign engines$config$out_base_0 = signal_reg_52;
    assign engines$config$out_count_0 = signal_reg_51;
    assign engines$config$set_base_0 = signal_reg_50;
    assign engines$config$set_count_0 = signal_reg_49;
    assign engines$config$jmp_pin_0 = signal_reg_48;
    assign engines$config$capture_pin_0 = signal_reg_47;
    assign engines$config$capture_rising_0 = signal_reg_46;
    assign engines$config$in_shift_right_0 = signal_reg_45;
    assign engines$config$out_shift_right_0 = signal_reg_44;
    assign engines$config$autopush_0 = signal_reg_43;
    assign engines$config$push_threshold_0 = signal_reg_42;
    assign engines$config$autopull_0 = signal_reg_41;
    assign engines$config$pull_threshold_0 = signal_reg_40;
    assign engines$config$crc_width_0 = signal_reg_39;
    assign engines$config$crc_poly_0 = signal_reg_38;
    assign engines$config$crc_init_0 = signal_reg_37;
    assign engines$config$crc_reflect_0 = signal_reg_36;
    assign engines$config$stuff_threshold_0 = signal_reg_35;
    assign engines$config$stuff_level_0 = signal_reg_34;
    assign engines$config$wrap_bottom_0 = signal_reg_33;
    assign engines$config$wrap_top_0 = signal_reg_32;
    assign engines$config$period_fraction_0 = signal_reg_31;
    assign engines$config$autopull_data_0 = signal_reg_30;
    assign engines$config$manchester_0 = signal_reg_29;
    assign engines$start_0 = signal_and_107;
    assign engines$program_write$valid_0 = signal_and_104;
    assign engines$program_write$addr_0 = program_addr;
    assign engines$program_write$data_0 = value;
    assign engines$data_write$valid_0 = signal_and_102;
    assign engines$data_write$addr_0 = data_addr;
    assign engines$data_write$data_0 = value;
    assign engines$tx$valid_0 = signal_and_100;
    assign engines$tx$value_0 = value;
    assign engines$rx_pop_0 = signal_and_98;
    assign engines$clear_irq_0 = signal_and_96;
    assign engines$stop_0 = signal_and_93;
    assign engines$flush_0 = signal_and_90;
    assign engines$check_0 = signal_and_87;
    assign engines$config_written_0 = signal_and_84;
    assign engines$config$side_set_count_1 = signal_reg_28;
    assign engines$config$side_set_base_1 = signal_reg_27;
    assign engines$config$side_set_pindirs_1 = signal_reg_26;
    assign engines$config$in_base_1 = signal_reg_25;
    assign engines$config$in_count_1 = signal_reg_24;
    assign engines$config$out_base_1 = signal_reg_23;
    assign engines$config$out_count_1 = signal_reg_22;
    assign engines$config$set_base_1 = signal_reg_21;
    assign engines$config$set_count_1 = signal_reg_20;
    assign engines$config$jmp_pin_1 = signal_reg_19;
    assign engines$config$capture_pin_1 = signal_reg_18;
    assign engines$config$capture_rising_1 = signal_reg_17;
    assign engines$config$in_shift_right_1 = signal_reg_16;
    assign engines$config$out_shift_right_1 = signal_reg_15;
    assign engines$config$autopush_1 = signal_reg_14;
    assign engines$config$push_threshold_1 = signal_reg_13;
    assign engines$config$autopull_1 = signal_reg_12;
    assign engines$config$pull_threshold_1 = signal_reg_11;
    assign engines$config$crc_width_1 = signal_reg_10;
    assign engines$config$crc_poly_1 = signal_reg_9;
    assign engines$config$crc_init_1 = signal_reg_8;
    assign engines$config$crc_reflect_1 = signal_reg_7;
    assign engines$config$stuff_threshold_1 = signal_reg_6;
    assign engines$config$stuff_level_1 = signal_reg_5;
    assign engines$config$wrap_bottom_1 = signal_reg_4;
    assign engines$config$wrap_top_1 = signal_reg_3;
    assign engines$config$period_fraction_1 = signal_reg_2;
    assign engines$config$autopull_data_1 = signal_reg_1;
    assign engines$config$manchester_1 = signal_reg;
    assign engines$start_1 = signal_and_24;
    assign engines$program_write$valid_1 = signal_and_21;
    assign engines$program_write$addr_1 = program_addr;
    assign engines$program_write$data_1 = value;
    assign engines$data_write$valid_1 = signal_and_19;
    assign engines$data_write$addr_1 = data_addr;
    assign engines$data_write$data_1 = value;
    assign engines$tx$valid_1 = signal_and_17;
    assign engines$tx$value_1 = value;
    assign engines$rx_pop_1 = signal_and_15;
    assign engines$clear_irq_1 = signal_and_13;
    assign engines$stop_1 = signal_and_10;
    assign engines$flush_1 = signal_and_7;
    assign engines$check_1 = signal_and_4;
    assign engines$config_written_1 = signal_and_1;
    assign check_setup$base = check_base;
    assign check_setup$loaded$valid = signal_select_1;
    assign check_setup$loaded$value = check_loaded;
    assign check_setup$single_edge = signal_select;

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
    wire signal_select_4;
    wire [15:0] signal_select_5;
    wire signal_select_6;
    wire [8:0] signal_select_7;
    wire [4:0] signal_const;
    wire [4:0] signal_select_8;
    reg [4:0] signal_reg;
    reg [4:0] signal_reg_1;
    wire [6:0] signal_const_2;
    wire [7:0] signal_const_3;
    wire [7:0] signal_wire;
    reg [7:0] signal_reg_2;
    reg [7:0] signal_reg_3;
    wire [19:0] inputs;
    wire signal_select_9;
    wire signal_select_10;
    wire signal_select_11;
    wire signal_select_12;
    wire signal_select_13;
    wire signal_select_14;
    wire [15:0] signal_select_15;
    wire signal_select_16;
    wire [15:0] signal_select_17;
    wire [8:0] signal_select_18;
    wire signal_select_19;
    wire [15:0] signal_select_20;
    wire [8:0] signal_select_21;
    wire signal_select_22;
    wire signal_select_23;
    wire signal_select_24;
    wire signal_select_25;
    wire [15:0] signal_select_26;
    wire [8:0] signal_select_27;
    wire [8:0] signal_select_28;
    wire signal_select_29;
    wire [4:0] signal_select_30;
    wire signal_select_31;
    wire [15:0] signal_select_32;
    wire [15:0] signal_select_33;
    wire [4:0] signal_select_34;
    wire [4:0] signal_select_35;
    wire signal_select_36;
    wire [4:0] signal_select_37;
    wire signal_select_38;
    wire signal_select_39;
    wire signal_select_40;
    wire signal_select_41;
    wire [4:0] signal_select_42;
    wire [4:0] signal_select_43;
    wire [2:0] signal_select_44;
    wire [4:0] signal_select_45;
    wire [4:0] signal_select_46;
    wire [4:0] signal_select_47;
    wire [4:0] signal_select_48;
    wire [4:0] signal_select_49;
    wire signal_select_50;
    wire [4:0] signal_select_51;
    wire [1:0] signal_select_52;
    wire signal_select_53;
    wire signal_select_54;
    wire signal_select_55;
    wire signal_select_56;
    wire signal_select_57;
    wire signal_select_58;
    wire [15:0] signal_select_59;
    wire signal_select_60;
    wire [15:0] signal_select_61;
    wire [8:0] signal_select_62;
    wire signal_select_63;
    wire [15:0] signal_select_64;
    wire [8:0] signal_select_65;
    wire signal_select_66;
    wire signal_select_67;
    wire signal_select_68;
    wire signal_select_69;
    wire [15:0] signal_select_70;
    wire [8:0] signal_select_71;
    wire [8:0] signal_select_72;
    wire signal_select_73;
    wire [4:0] signal_select_74;
    wire signal_select_75;
    wire [15:0] signal_select_76;
    wire [15:0] signal_select_77;
    wire [4:0] signal_select_78;
    wire [4:0] signal_select_79;
    wire signal_select_80;
    wire [4:0] signal_select_81;
    wire signal_select_82;
    wire signal_select_83;
    wire signal_select_84;
    wire signal_select_85;
    wire [4:0] signal_select_86;
    wire [4:0] signal_select_87;
    wire [2:0] signal_select_88;
    wire [4:0] signal_select_89;
    wire [4:0] signal_select_90;
    wire [4:0] signal_select_91;
    wire [4:0] signal_select_92;
    wire [4:0] signal_select_93;
    wire signal_select_94;
    wire [4:0] signal_select_95;
    wire [4:0] signal_select_96;
    wire [4:0] signal_wire_1;
    wire [9:0] signal_select_97;
    wire [9:0] signal_wire_2;
    wire signal_select_98;
    wire signal_wire_3;
    wire signal_select_99;
    wire signal_wire_4;
    wire signal_select_100;
    wire signal_wire_5;
    wire signal_select_101;
    wire signal_wire_6;
    wire [15:0] signal_select_102;
    wire [15:0] signal_wire_7;
    wire [3:0] signal_select_103;
    wire [3:0] signal_wire_8;
    wire [3:0] signal_select_104;
    wire [3:0] signal_wire_9;
    wire signal_select_105;
    wire signal_wire_10;
    wire signal_select_106;
    wire signal_wire_11;
    wire signal_select_107;
    wire signal_wire_12;
    wire signal_select_108;
    wire signal_wire_13;
    wire signal_select_109;
    wire signal_wire_14;
    wire signal_select_110;
    wire signal_wire_15;
    wire [23:0] signal_select_111;
    wire [23:0] signal_wire_16;
    wire [23:0] signal_select_112;
    wire [23:0] signal_wire_17;
    wire [8:0] signal_select_113;
    wire [8:0] signal_wire_18;
    wire signal_select_114;
    wire signal_wire_19;
    wire signal_select_115;
    wire signal_wire_20;
    wire [15:0] signal_select_116;
    wire [15:0] signal_wire_21;
    wire [3:0] signal_select_117;
    wire [3:0] signal_wire_22;
    wire [3:0] signal_select_118;
    wire [3:0] signal_wire_23;
    wire signal_select_119;
    wire signal_wire_24;
    wire signal_select_120;
    wire signal_wire_25;
    wire signal_select_121;
    wire signal_wire_26;
    wire signal_select_122;
    wire signal_wire_27;
    wire signal_select_123;
    wire signal_wire_28;
    wire signal_select_124;
    wire signal_wire_29;
    wire [23:0] signal_select_125;
    wire [23:0] signal_wire_30;
    wire [23:0] signal_select_126;
    wire [23:0] signal_wire_31;
    wire [8:0] signal_select_127;
    wire [8:0] signal_wire_32;
    wire signal_select_128;
    wire signal_select_129;
    wire [7:0] signal_wire_33;
    wire signal_select_130;
    wire [461:0] signal_inst;
    wire [1:0] signal_select_131;
    wire signal_const_5;
    wire signal_wire_34;
    wire signal_not;
    wire vdd;
    reg signal_reg_4;
    reg reset_done;
    wire signal_not_1;
    wire signal_wire_35;
    wire [838:0] signal_inst_1;
    wire [19:0] signal_select_132;
    wire [6:0] signal_select_133;
    wire [7:0] signal_cat;
    assign signal_select = signal_inst_1[817:798];
    assign signal_select_1 = signal_select[19:12];
    assign signal_select_2 = signal_select_132[19:12];
    assign signal_select_3 = signal_inst[0:0];
    assign signal_select_4 = signal_inst[461:461];
    assign signal_select_5 = signal_inst[460:445];
    assign signal_select_6 = signal_inst[444:444];
    assign signal_select_7 = signal_inst[443:435];
    assign signal_const = 5'b00000;
    assign signal_select_8 = signal_wire_33[7:3];
    always @(posedge signal_wire_35) begin
        if (signal_not_1)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_select_8;
    end
    always @(posedge signal_wire_35) begin
        if (signal_not_1)
            signal_reg_1 <= signal_const;
        else
            signal_reg_1 <= signal_reg;
    end
    assign signal_const_2 = 7'b0000000;
    assign signal_const_3 = 8'b00000000;
    assign signal_wire = uio_in;
    always @(posedge signal_wire_35) begin
        if (signal_not_1)
            signal_reg_2 <= signal_const_3;
        else
            signal_reg_2 <= signal_wire;
    end
    always @(posedge signal_wire_35) begin
        if (signal_not_1)
            signal_reg_3 <= signal_const_3;
        else
            signal_reg_3 <= signal_reg_2;
    end
    assign inputs = { signal_reg_3,
                      signal_const_2,
                      signal_reg_1 };
    assign signal_select_9 = signal_inst[434:434];
    assign signal_select_10 = signal_inst[433:433];
    assign signal_select_11 = signal_inst[432:432];
    assign signal_select_12 = signal_inst[431:431];
    assign signal_select_13 = signal_inst[430:430];
    assign signal_select_14 = signal_inst[429:429];
    assign signal_select_15 = signal_inst[428:413];
    assign signal_select_16 = signal_inst[412:412];
    assign signal_select_17 = signal_inst[411:396];
    assign signal_select_18 = signal_inst[395:387];
    assign signal_select_19 = signal_inst[386:386];
    assign signal_select_20 = signal_inst[385:370];
    assign signal_select_21 = signal_inst[369:361];
    assign signal_select_22 = signal_inst[360:360];
    assign signal_select_23 = signal_inst[359:359];
    assign signal_select_24 = signal_inst[358:358];
    assign signal_select_25 = signal_inst[357:357];
    assign signal_select_26 = signal_inst[356:341];
    assign signal_select_27 = signal_inst[340:332];
    assign signal_select_28 = signal_inst[331:323];
    assign signal_select_29 = signal_inst[322:322];
    assign signal_select_30 = signal_inst[321:317];
    assign signal_select_31 = signal_inst[316:316];
    assign signal_select_32 = signal_inst[315:300];
    assign signal_select_33 = signal_inst[299:284];
    assign signal_select_34 = signal_inst[283:279];
    assign signal_select_35 = signal_inst[278:274];
    assign signal_select_36 = signal_inst[273:273];
    assign signal_select_37 = signal_inst[272:268];
    assign signal_select_38 = signal_inst[267:267];
    assign signal_select_39 = signal_inst[266:266];
    assign signal_select_40 = signal_inst[265:265];
    assign signal_select_41 = signal_inst[264:264];
    assign signal_select_42 = signal_inst[263:259];
    assign signal_select_43 = signal_inst[258:254];
    assign signal_select_44 = signal_inst[253:251];
    assign signal_select_45 = signal_inst[250:246];
    assign signal_select_46 = signal_inst[245:241];
    assign signal_select_47 = signal_inst[240:236];
    assign signal_select_48 = signal_inst[235:231];
    assign signal_select_49 = signal_inst[230:226];
    assign signal_select_50 = signal_inst[225:225];
    assign signal_select_51 = signal_inst[224:220];
    assign signal_select_52 = signal_inst[219:218];
    assign signal_select_53 = signal_inst[217:217];
    assign signal_select_54 = signal_inst[216:216];
    assign signal_select_55 = signal_inst[215:215];
    assign signal_select_56 = signal_inst[214:214];
    assign signal_select_57 = signal_inst[213:213];
    assign signal_select_58 = signal_inst[212:212];
    assign signal_select_59 = signal_inst[211:196];
    assign signal_select_60 = signal_inst[195:195];
    assign signal_select_61 = signal_inst[194:179];
    assign signal_select_62 = signal_inst[178:170];
    assign signal_select_63 = signal_inst[169:169];
    assign signal_select_64 = signal_inst[168:153];
    assign signal_select_65 = signal_inst[152:144];
    assign signal_select_66 = signal_inst[143:143];
    assign signal_select_67 = signal_inst[142:142];
    assign signal_select_68 = signal_inst[141:141];
    assign signal_select_69 = signal_inst[140:140];
    assign signal_select_70 = signal_inst[139:124];
    assign signal_select_71 = signal_inst[123:115];
    assign signal_select_72 = signal_inst[114:106];
    assign signal_select_73 = signal_inst[105:105];
    assign signal_select_74 = signal_inst[104:100];
    assign signal_select_75 = signal_inst[99:99];
    assign signal_select_76 = signal_inst[98:83];
    assign signal_select_77 = signal_inst[82:67];
    assign signal_select_78 = signal_inst[66:62];
    assign signal_select_79 = signal_inst[61:57];
    assign signal_select_80 = signal_inst[56:56];
    assign signal_select_81 = signal_inst[55:51];
    assign signal_select_82 = signal_inst[50:50];
    assign signal_select_83 = signal_inst[49:49];
    assign signal_select_84 = signal_inst[48:48];
    assign signal_select_85 = signal_inst[47:47];
    assign signal_select_86 = signal_inst[46:42];
    assign signal_select_87 = signal_inst[41:37];
    assign signal_select_88 = signal_inst[36:34];
    assign signal_select_89 = signal_inst[33:29];
    assign signal_select_90 = signal_inst[28:24];
    assign signal_select_91 = signal_inst[23:19];
    assign signal_select_92 = signal_inst[18:14];
    assign signal_select_93 = signal_inst[13:9];
    assign signal_select_94 = signal_inst[8:8];
    assign signal_select_95 = signal_inst[7:3];
    assign signal_select_96 = signal_inst_1[834:830];
    assign signal_wire_1 = signal_select_96;
    assign signal_select_97 = signal_inst_1[829:820];
    assign signal_wire_2 = signal_select_97;
    assign signal_select_98 = signal_inst_1[819:819];
    assign signal_wire_3 = signal_select_98;
    assign signal_select_99 = signal_inst_1[818:818];
    assign signal_wire_4 = signal_select_99;
    assign signal_select_100 = signal_inst_1[838:838];
    assign signal_wire_5 = signal_select_100;
    assign signal_select_101 = signal_inst_1[836:836];
    assign signal_wire_6 = signal_select_101;
    assign signal_select_102 = signal_inst_1[685:670];
    assign signal_wire_7 = signal_select_102;
    assign signal_select_103 = signal_inst_1[669:666];
    assign signal_wire_8 = signal_select_103;
    assign signal_select_104 = signal_inst_1[665:662];
    assign signal_wire_9 = signal_select_104;
    assign signal_select_105 = signal_inst_1[636:636];
    assign signal_wire_10 = signal_select_105;
    assign signal_select_106 = signal_inst_1[635:635];
    assign signal_wire_11 = signal_select_106;
    assign signal_select_107 = signal_inst_1[634:634];
    assign signal_wire_12 = signal_select_107;
    assign signal_select_108 = signal_inst_1[633:633];
    assign signal_wire_13 = signal_select_108;
    assign signal_select_109 = signal_inst_1[632:632];
    assign signal_wire_14 = signal_select_109;
    assign signal_select_110 = signal_inst_1[631:631];
    assign signal_wire_15 = signal_select_110;
    assign signal_select_111 = signal_inst_1[660:637];
    assign signal_wire_16 = signal_select_111;
    assign signal_select_112 = signal_inst_1[625:602];
    assign signal_wire_17 = signal_select_112;
    assign signal_select_113 = signal_inst_1[453:445];
    assign signal_wire_18 = signal_select_113;
    assign signal_select_114 = signal_inst_1[837:837];
    assign signal_wire_19 = signal_select_114;
    assign signal_select_115 = signal_inst_1[835:835];
    assign signal_wire_20 = signal_select_115;
    assign signal_select_116 = signal_inst_1[296:281];
    assign signal_wire_21 = signal_select_116;
    assign signal_select_117 = signal_inst_1[280:277];
    assign signal_wire_22 = signal_select_117;
    assign signal_select_118 = signal_inst_1[276:273];
    assign signal_wire_23 = signal_select_118;
    assign signal_select_119 = signal_inst_1[247:247];
    assign signal_wire_24 = signal_select_119;
    assign signal_select_120 = signal_inst_1[246:246];
    assign signal_wire_25 = signal_select_120;
    assign signal_select_121 = signal_inst_1[245:245];
    assign signal_wire_26 = signal_select_121;
    assign signal_select_122 = signal_inst_1[244:244];
    assign signal_wire_27 = signal_select_122;
    assign signal_select_123 = signal_inst_1[243:243];
    assign signal_wire_28 = signal_select_123;
    assign signal_select_124 = signal_inst_1[242:242];
    assign signal_wire_29 = signal_select_124;
    assign signal_select_125 = signal_inst_1[271:248];
    assign signal_wire_30 = signal_select_125;
    assign signal_select_126 = signal_inst_1[236:213];
    assign signal_wire_31 = signal_select_126;
    assign signal_select_127 = signal_inst_1[64:56];
    assign signal_wire_32 = signal_select_127;
    assign signal_select_128 = signal_wire_33[2:2];
    assign signal_select_129 = signal_wire_33[1:1];
    assign signal_wire_33 = ui_in;
    assign signal_select_130 = signal_wire_33[0:0];
    host_port
        host_port
        ( .clock(signal_wire_35),
          .clear(signal_not_1),
          .sck(signal_select_130),
          .mosi(signal_select_129),
          .cs_n(signal_select_128),
          .status$pc_0(signal_wire_32),
          .status$now_0(signal_wire_31),
          .status$capture_0(signal_wire_30),
          .status$halted_0(signal_wire_29),
          .status$irq_0(signal_wire_28),
          .status$fault$underflow_0(signal_wire_27),
          .status$fault$overflow_0(signal_wire_26),
          .status$fault$missed_deadline_0(signal_wire_25),
          .status$fault$decode_0(signal_wire_24),
          .status$tx_level_0(signal_wire_23),
          .status$rx_level_0(signal_wire_22),
          .status$rx_head_0(signal_wire_21),
          .status$certified_0(signal_wire_20),
          .status$refused_0(signal_wire_19),
          .status$pc_1(signal_wire_18),
          .status$now_1(signal_wire_17),
          .status$capture_1(signal_wire_16),
          .status$halted_1(signal_wire_15),
          .status$irq_1(signal_wire_14),
          .status$fault$underflow_1(signal_wire_13),
          .status$fault$overflow_1(signal_wire_12),
          .status$fault$missed_deadline_1(signal_wire_11),
          .status$fault$decode_1(signal_wire_10),
          .status$tx_level_1(signal_wire_9),
          .status$rx_level_1(signal_wire_8),
          .status$rx_head_1(signal_wire_7),
          .status$certified_1(signal_wire_6),
          .status$refused_1(signal_wire_5),
          .check$busy(signal_wire_4),
          .check$accepted(signal_wire_3),
          .check$reject_pc(signal_wire_2),
          .check$reason(signal_wire_1),
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
          .engines$config$autopull_data_0(signal_inst[140:140]),
          .engines$config$manchester_0(signal_inst[141:141]),
          .engines$start_0(signal_inst[142:142]),
          .engines$program_write$valid_0(signal_inst[143:143]),
          .engines$program_write$addr_0(signal_inst[152:144]),
          .engines$program_write$data_0(signal_inst[168:153]),
          .engines$data_write$valid_0(signal_inst[169:169]),
          .engines$data_write$addr_0(signal_inst[178:170]),
          .engines$data_write$data_0(signal_inst[194:179]),
          .engines$tx$valid_0(signal_inst[195:195]),
          .engines$tx$value_0(signal_inst[211:196]),
          .engines$rx_pop_0(signal_inst[212:212]),
          .engines$clear_irq_0(signal_inst[213:213]),
          .engines$stop_0(signal_inst[214:214]),
          .engines$flush_0(signal_inst[215:215]),
          .engines$check_0(signal_inst[216:216]),
          .engines$config_written_0(signal_inst[217:217]),
          .engines$config$side_set_count_1(signal_inst[219:218]),
          .engines$config$side_set_base_1(signal_inst[224:220]),
          .engines$config$side_set_pindirs_1(signal_inst[225:225]),
          .engines$config$in_base_1(signal_inst[230:226]),
          .engines$config$in_count_1(signal_inst[235:231]),
          .engines$config$out_base_1(signal_inst[240:236]),
          .engines$config$out_count_1(signal_inst[245:241]),
          .engines$config$set_base_1(signal_inst[250:246]),
          .engines$config$set_count_1(signal_inst[253:251]),
          .engines$config$jmp_pin_1(signal_inst[258:254]),
          .engines$config$capture_pin_1(signal_inst[263:259]),
          .engines$config$capture_rising_1(signal_inst[264:264]),
          .engines$config$in_shift_right_1(signal_inst[265:265]),
          .engines$config$out_shift_right_1(signal_inst[266:266]),
          .engines$config$autopush_1(signal_inst[267:267]),
          .engines$config$push_threshold_1(signal_inst[272:268]),
          .engines$config$autopull_1(signal_inst[273:273]),
          .engines$config$pull_threshold_1(signal_inst[278:274]),
          .engines$config$crc_width_1(signal_inst[283:279]),
          .engines$config$crc_poly_1(signal_inst[299:284]),
          .engines$config$crc_init_1(signal_inst[315:300]),
          .engines$config$crc_reflect_1(signal_inst[316:316]),
          .engines$config$stuff_threshold_1(signal_inst[321:317]),
          .engines$config$stuff_level_1(signal_inst[322:322]),
          .engines$config$wrap_bottom_1(signal_inst[331:323]),
          .engines$config$wrap_top_1(signal_inst[340:332]),
          .engines$config$period_fraction_1(signal_inst[356:341]),
          .engines$config$autopull_data_1(signal_inst[357:357]),
          .engines$config$manchester_1(signal_inst[358:358]),
          .engines$start_1(signal_inst[359:359]),
          .engines$program_write$valid_1(signal_inst[360:360]),
          .engines$program_write$addr_1(signal_inst[369:361]),
          .engines$program_write$data_1(signal_inst[385:370]),
          .engines$data_write$valid_1(signal_inst[386:386]),
          .engines$data_write$addr_1(signal_inst[395:387]),
          .engines$data_write$data_1(signal_inst[411:396]),
          .engines$tx$valid_1(signal_inst[412:412]),
          .engines$tx$value_1(signal_inst[428:413]),
          .engines$rx_pop_1(signal_inst[429:429]),
          .engines$clear_irq_1(signal_inst[430:430]),
          .engines$stop_1(signal_inst[431:431]),
          .engines$flush_1(signal_inst[432:432]),
          .engines$check_1(signal_inst[433:433]),
          .engines$config_written_1(signal_inst[434:434]),
          .check_setup$base(signal_inst[443:435]),
          .check_setup$loaded$valid(signal_inst[444:444]),
          .check_setup$loaded$value(signal_inst[460:445]),
          .check_setup$single_edge(signal_inst[461:461]) );
    assign signal_select_131 = signal_inst[2:1];
    assign signal_const_5 = 1'b0;
    assign signal_wire_34 = rst_n;
    assign signal_not = ~ signal_wire_34;
    assign vdd = 1'b1;
    always @(posedge signal_wire_35 or posedge signal_not) begin
        if (signal_not)
            signal_reg_4 <= signal_const_5;
        else
            signal_reg_4 <= vdd;
    end
    always @(posedge signal_wire_35 or posedge signal_not) begin
        if (signal_not)
            reset_done <= signal_const_5;
        else
            reset_done <= signal_reg_4;
    end
    assign signal_not_1 = ~ reset_done;
    assign signal_wire_35 = clk;
    engines
        engines
        ( .clock(signal_wire_35),
          .clear(signal_not_1),
          .hosts$config$side_set_count_0(signal_select_131),
          .hosts$config$side_set_base_0(signal_select_95),
          .hosts$config$side_set_pindirs_0(signal_select_94),
          .hosts$config$in_base_0(signal_select_93),
          .hosts$config$in_count_0(signal_select_92),
          .hosts$config$out_base_0(signal_select_91),
          .hosts$config$out_count_0(signal_select_90),
          .hosts$config$set_base_0(signal_select_89),
          .hosts$config$set_count_0(signal_select_88),
          .hosts$config$jmp_pin_0(signal_select_87),
          .hosts$config$capture_pin_0(signal_select_86),
          .hosts$config$capture_rising_0(signal_select_85),
          .hosts$config$in_shift_right_0(signal_select_84),
          .hosts$config$out_shift_right_0(signal_select_83),
          .hosts$config$autopush_0(signal_select_82),
          .hosts$config$push_threshold_0(signal_select_81),
          .hosts$config$autopull_0(signal_select_80),
          .hosts$config$pull_threshold_0(signal_select_79),
          .hosts$config$crc_width_0(signal_select_78),
          .hosts$config$crc_poly_0(signal_select_77),
          .hosts$config$crc_init_0(signal_select_76),
          .hosts$config$crc_reflect_0(signal_select_75),
          .hosts$config$stuff_threshold_0(signal_select_74),
          .hosts$config$stuff_level_0(signal_select_73),
          .hosts$config$wrap_bottom_0(signal_select_72),
          .hosts$config$wrap_top_0(signal_select_71),
          .hosts$config$period_fraction_0(signal_select_70),
          .hosts$config$autopull_data_0(signal_select_69),
          .hosts$config$manchester_0(signal_select_68),
          .hosts$start_0(signal_select_67),
          .hosts$program_write$valid_0(signal_select_66),
          .hosts$program_write$addr_0(signal_select_65),
          .hosts$program_write$data_0(signal_select_64),
          .hosts$data_write$valid_0(signal_select_63),
          .hosts$data_write$addr_0(signal_select_62),
          .hosts$data_write$data_0(signal_select_61),
          .hosts$tx$valid_0(signal_select_60),
          .hosts$tx$value_0(signal_select_59),
          .hosts$rx_pop_0(signal_select_58),
          .hosts$clear_irq_0(signal_select_57),
          .hosts$stop_0(signal_select_56),
          .hosts$flush_0(signal_select_55),
          .hosts$check_0(signal_select_54),
          .hosts$config_written_0(signal_select_53),
          .hosts$config$side_set_count_1(signal_select_52),
          .hosts$config$side_set_base_1(signal_select_51),
          .hosts$config$side_set_pindirs_1(signal_select_50),
          .hosts$config$in_base_1(signal_select_49),
          .hosts$config$in_count_1(signal_select_48),
          .hosts$config$out_base_1(signal_select_47),
          .hosts$config$out_count_1(signal_select_46),
          .hosts$config$set_base_1(signal_select_45),
          .hosts$config$set_count_1(signal_select_44),
          .hosts$config$jmp_pin_1(signal_select_43),
          .hosts$config$capture_pin_1(signal_select_42),
          .hosts$config$capture_rising_1(signal_select_41),
          .hosts$config$in_shift_right_1(signal_select_40),
          .hosts$config$out_shift_right_1(signal_select_39),
          .hosts$config$autopush_1(signal_select_38),
          .hosts$config$push_threshold_1(signal_select_37),
          .hosts$config$autopull_1(signal_select_36),
          .hosts$config$pull_threshold_1(signal_select_35),
          .hosts$config$crc_width_1(signal_select_34),
          .hosts$config$crc_poly_1(signal_select_33),
          .hosts$config$crc_init_1(signal_select_32),
          .hosts$config$crc_reflect_1(signal_select_31),
          .hosts$config$stuff_threshold_1(signal_select_30),
          .hosts$config$stuff_level_1(signal_select_29),
          .hosts$config$wrap_bottom_1(signal_select_28),
          .hosts$config$wrap_top_1(signal_select_27),
          .hosts$config$period_fraction_1(signal_select_26),
          .hosts$config$autopull_data_1(signal_select_25),
          .hosts$config$manchester_1(signal_select_24),
          .hosts$start_1(signal_select_23),
          .hosts$program_write$valid_1(signal_select_22),
          .hosts$program_write$addr_1(signal_select_21),
          .hosts$program_write$data_1(signal_select_20),
          .hosts$data_write$valid_1(signal_select_19),
          .hosts$data_write$addr_1(signal_select_18),
          .hosts$data_write$data_1(signal_select_17),
          .hosts$tx$valid_1(signal_select_16),
          .hosts$tx$value_1(signal_select_15),
          .hosts$rx_pop_1(signal_select_14),
          .hosts$clear_irq_1(signal_select_13),
          .hosts$stop_1(signal_select_12),
          .hosts$flush_1(signal_select_11),
          .hosts$check_1(signal_select_10),
          .hosts$config_written_1(signal_select_9),
          .pads(inputs),
          .check_setup$base(signal_select_7),
          .check_setup$loaded$valid(signal_select_6),
          .check_setup$loaded$value(signal_select_5),
          .check_setup$single_edge(signal_select_4),
          .engines$pin_out_0(signal_inst_1[27:0]),
          .engines$pin_dir_0(signal_inst_1[55:28]),
          .engines$pc_0(signal_inst_1[64:56]),
          .engines$data_ptr_0(signal_inst_1[73:65]),
          .engines$data_addr_0(signal_inst_1[82:74]),
          .engines$x_0(signal_inst_1[98:83]),
          .engines$y_0(signal_inst_1[114:99]),
          .engines$p_0(signal_inst_1[130:115]),
          .engines$t_0(signal_inst_1[154:131]),
          .engines$t_fraction_0(signal_inst_1[170:155]),
          .engines$osr_0(signal_inst_1[186:171]),
          .engines$osr_count_0(signal_inst_1[191:187]),
          .engines$isr_0(signal_inst_1[207:192]),
          .engines$isr_count_0(signal_inst_1[212:208]),
          .engines$now_0(signal_inst_1[236:213]),
          .engines$stall_0(signal_inst_1[241:237]),
          .engines$halted_0(signal_inst_1[242:242]),
          .engines$irq_0(signal_inst_1[243:243]),
          .engines$fault$underflow_0(signal_inst_1[244:244]),
          .engines$fault$overflow_0(signal_inst_1[245:245]),
          .engines$fault$missed_deadline_0(signal_inst_1[246:246]),
          .engines$fault$decode_0(signal_inst_1[247:247]),
          .engines$capture_0(signal_inst_1[271:248]),
          .engines$capture_armed_0(signal_inst_1[272:272]),
          .engines$tx_level_0(signal_inst_1[276:273]),
          .engines$rx_level_0(signal_inst_1[280:277]),
          .engines$rx_head_0(signal_inst_1[296:281]),
          .engines$instruction_0(signal_inst_1[312:297]),
          .engines$program_word_0(signal_inst_1[328:313]),
          .engines$decode_ok_0(signal_inst_1[329:329]),
          .engines$opcode_onehot_0(signal_inst_1[337:330]),
          .engines$wait_select_0(signal_inst_1[365:338]),
          .engines$crc_0(signal_inst_1[381:366]),
          .engines$stuff_run_0(signal_inst_1[386:382]),
          .engines$flip_pending_0(signal_inst_1[387:387]),
          .engines$flip_bit_0(signal_inst_1[388:388]),
          .engines$pin_out_1(signal_inst_1[416:389]),
          .engines$pin_dir_1(signal_inst_1[444:417]),
          .engines$pc_1(signal_inst_1[453:445]),
          .engines$data_ptr_1(signal_inst_1[462:454]),
          .engines$data_addr_1(signal_inst_1[471:463]),
          .engines$x_1(signal_inst_1[487:472]),
          .engines$y_1(signal_inst_1[503:488]),
          .engines$p_1(signal_inst_1[519:504]),
          .engines$t_1(signal_inst_1[543:520]),
          .engines$t_fraction_1(signal_inst_1[559:544]),
          .engines$osr_1(signal_inst_1[575:560]),
          .engines$osr_count_1(signal_inst_1[580:576]),
          .engines$isr_1(signal_inst_1[596:581]),
          .engines$isr_count_1(signal_inst_1[601:597]),
          .engines$now_1(signal_inst_1[625:602]),
          .engines$stall_1(signal_inst_1[630:626]),
          .engines$halted_1(signal_inst_1[631:631]),
          .engines$irq_1(signal_inst_1[632:632]),
          .engines$fault$underflow_1(signal_inst_1[633:633]),
          .engines$fault$overflow_1(signal_inst_1[634:634]),
          .engines$fault$missed_deadline_1(signal_inst_1[635:635]),
          .engines$fault$decode_1(signal_inst_1[636:636]),
          .engines$capture_1(signal_inst_1[660:637]),
          .engines$capture_armed_1(signal_inst_1[661:661]),
          .engines$tx_level_1(signal_inst_1[665:662]),
          .engines$rx_level_1(signal_inst_1[669:666]),
          .engines$rx_head_1(signal_inst_1[685:670]),
          .engines$instruction_1(signal_inst_1[701:686]),
          .engines$program_word_1(signal_inst_1[717:702]),
          .engines$decode_ok_1(signal_inst_1[718:718]),
          .engines$opcode_onehot_1(signal_inst_1[726:719]),
          .engines$wait_select_1(signal_inst_1[754:727]),
          .engines$crc_1(signal_inst_1[770:755]),
          .engines$stuff_run_1(signal_inst_1[775:771]),
          .engines$flip_pending_1(signal_inst_1[776:776]),
          .engines$flip_bit_1(signal_inst_1[777:777]),
          .pin_out(signal_inst_1[797:778]),
          .pin_dir(signal_inst_1[817:798]),
          .check$verdict$busy(signal_inst_1[818:818]),
          .check$verdict$accepted(signal_inst_1[819:819]),
          .check$verdict$reject_pc(signal_inst_1[829:820]),
          .check$verdict$reason(signal_inst_1[834:830]),
          .check$certified_0(signal_inst_1[835:835]),
          .check$certified_1(signal_inst_1[836:836]),
          .check$refused_0(signal_inst_1[837:837]),
          .check$refused_1(signal_inst_1[838:838]) );
    assign signal_select_132 = signal_inst_1[797:778];
    assign signal_select_133 = signal_select_132[11:5];
    assign signal_cat = { signal_select_133,
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

