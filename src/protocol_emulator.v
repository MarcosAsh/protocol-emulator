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
    config$manchester,
    start,
    program_write$valid,
    program_write$addr,
    program_write$data,
    data_word,
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
    input config$break_enable;
    input [8:0] config$break_pc;
    input config$autopull_data;
    input config$manchester;
    input start;
    input program_write$valid;
    input [8:0] program_write$addr;
    input [15:0] program_write$data;
    input [15:0] data_word;
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
    wire signal_or_1;
    wire signal_and_9;
    reg signal_reg_3;
    wire signal_wire;
    wire signal_mux;
    wire [3:0] signal_const_9;
    wire signal_eq_4;
    wire signal_and_10;
    wire signal_and_11;
    wire signal_mux_1;
    wire signal_wire_1;
    reg irq_0;
    wire [8:0] signal_const_10;
    wire [8:0] signal_select_4;
    wire [8:0] signal_const_12;
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
    wire [27:0] signal_const_13;
    wire [15:0] signal_select_5;
    wire [11:0] signal_select_6;
    wire [27:0] signal_cat_1;
    wire [7:0] signal_select_7;
    wire [19:0] signal_select_8;
    wire [27:0] signal_cat_2;
    wire [3:0] signal_select_9;
    wire [23:0] signal_select_10;
    wire [27:0] signal_cat_3;
    wire [1:0] signal_select_11;
    wire [25:0] signal_select_12;
    wire [27:0] signal_cat_4;
    wire signal_select_13;
    wire [26:0] signal_select_14;
    wire [27:0] signal_cat_5;
    wire [10:0] signal_const_14;
    wire [15:0] signal_cat_6;
    wire [11:0] signal_const_15;
    wire [27:0] signal_cat_7;
    wire signal_select_15;
    wire [27:0] signal_mux_5;
    wire signal_select_16;
    wire [27:0] signal_mux_6;
    wire signal_select_17;
    wire [27:0] signal_mux_7;
    wire signal_select_18;
    wire [27:0] signal_mux_8;
    wire signal_select_19;
    wire [27:0] signal_mux_9;
    wire [27:0] signal_and_13;
    wire [27:0] signal_const_16;
    wire [15:0] signal_select_20;
    wire [11:0] signal_select_21;
    wire [27:0] signal_cat_8;
    wire [7:0] signal_select_22;
    wire [19:0] signal_select_23;
    wire [27:0] signal_cat_9;
    wire [3:0] signal_select_24;
    wire [23:0] signal_select_25;
    wire [27:0] signal_cat_10;
    wire [1:0] signal_select_26;
    wire [25:0] signal_select_27;
    wire [27:0] signal_cat_11;
    wire signal_select_28;
    wire [26:0] signal_select_29;
    wire [27:0] signal_cat_12;
    wire [15:0] signal_const_17;
    wire [7:0] signal_const_18;
    wire [7:0] signal_select_30;
    wire [15:0] signal_cat_13;
    wire [3:0] signal_const_19;
    wire [11:0] signal_select_31;
    wire [15:0] signal_cat_14;
    wire [1:0] signal_const_20;
    wire [13:0] signal_select_32;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_const_21;
    wire [15:0] signal_const_22;
    wire signal_select_33;
    wire [15:0] signal_mux_10;
    wire signal_select_34;
    wire [15:0] signal_mux_11;
    wire signal_select_35;
    wire [15:0] signal_mux_12;
    wire signal_select_36;
    wire [15:0] signal_mux_13;
    wire signal_select_37;
    wire [15:0] signal_mux_14;
    wire [15:0] signal_not_3;
    wire [27:0] signal_cat_16;
    wire signal_select_38;
    wire [27:0] signal_mux_15;
    wire signal_select_39;
    wire [27:0] signal_mux_16;
    wire signal_select_40;
    wire [27:0] signal_mux_17;
    wire signal_select_41;
    wire [27:0] signal_mux_18;
    wire signal_select_42;
    wire [27:0] signal_mux_19;
    wire [27:0] signal_and_14;
    wire [27:0] signal_not_4;
    wire [27:0] signal_and_15;
    wire [27:0] signal_or_4;
    wire [2:0] signal_const_24;
    wire signal_eq_5;
    wire [27:0] signal_mux_20;
    wire [15:0] signal_select_43;
    wire [11:0] signal_select_44;
    wire [27:0] signal_cat_17;
    wire [7:0] signal_select_45;
    wire [19:0] signal_select_46;
    wire [27:0] signal_cat_18;
    wire [3:0] signal_select_47;
    wire [23:0] signal_select_48;
    wire [27:0] signal_cat_19;
    wire [1:0] signal_select_49;
    wire [25:0] signal_select_50;
    wire [27:0] signal_cat_20;
    wire signal_select_51;
    wire [26:0] signal_select_52;
    wire [27:0] signal_cat_21;
    wire [27:0] signal_cat_22;
    wire signal_select_53;
    wire [27:0] signal_mux_21;
    wire signal_select_54;
    wire [27:0] signal_mux_22;
    wire signal_select_55;
    wire [27:0] signal_mux_23;
    wire signal_select_56;
    wire [27:0] signal_mux_24;
    wire signal_select_57;
    wire [27:0] signal_mux_25;
    wire [27:0] signal_and_16;
    wire [15:0] signal_select_58;
    wire [11:0] signal_select_59;
    wire [27:0] signal_cat_23;
    wire [7:0] signal_select_60;
    wire [19:0] signal_select_61;
    wire [27:0] signal_cat_24;
    wire [3:0] signal_select_62;
    wire [23:0] signal_select_63;
    wire [27:0] signal_cat_25;
    wire [1:0] signal_select_64;
    wire [25:0] signal_select_65;
    wire [27:0] signal_cat_26;
    wire signal_select_66;
    wire [26:0] signal_select_67;
    wire [27:0] signal_cat_27;
    wire [7:0] signal_select_68;
    wire [15:0] signal_cat_28;
    wire [11:0] signal_select_69;
    wire [15:0] signal_cat_29;
    wire [13:0] signal_select_70;
    wire [15:0] signal_cat_30;
    wire signal_select_71;
    wire [15:0] signal_mux_26;
    wire signal_select_72;
    wire [15:0] signal_mux_27;
    wire signal_select_73;
    wire [15:0] signal_mux_28;
    wire signal_select_74;
    wire [15:0] signal_mux_29;
    wire signal_select_75;
    wire [15:0] signal_mux_30;
    wire [15:0] signal_not_5;
    wire [27:0] signal_cat_31;
    wire signal_select_76;
    wire [27:0] signal_mux_31;
    wire signal_select_77;
    wire [27:0] signal_mux_32;
    wire signal_select_78;
    wire [27:0] signal_mux_33;
    wire signal_select_79;
    wire [27:0] signal_mux_34;
    wire signal_select_80;
    wire [27:0] signal_mux_35;
    wire [27:0] signal_and_17;
    wire [27:0] signal_not_6;
    wire [27:0] signal_and_18;
    wire [27:0] signal_or_5;
    wire signal_eq_6;
    wire [27:0] signal_mux_36;
    wire [15:0] signal_select_81;
    wire [11:0] signal_select_82;
    wire [27:0] signal_cat_32;
    wire [7:0] signal_select_83;
    wire [19:0] signal_select_84;
    wire [27:0] signal_cat_33;
    wire [3:0] signal_select_85;
    wire [23:0] signal_select_86;
    wire [27:0] signal_cat_34;
    wire [1:0] signal_select_87;
    wire [25:0] signal_select_88;
    wire [27:0] signal_cat_35;
    wire signal_select_89;
    wire [26:0] signal_select_90;
    wire [27:0] signal_cat_36;
    wire signal_not_7;
    wire signal_select_91;
    wire [1:0] signal_cat_37;
    wire [13:0] signal_const_35;
    wire [15:0] signal_cat_38;
    wire [27:0] signal_cat_39;
    wire signal_select_92;
    wire [27:0] signal_mux_37;
    wire signal_select_93;
    wire [27:0] signal_mux_38;
    wire signal_select_94;
    wire [27:0] signal_mux_39;
    wire signal_select_95;
    wire [27:0] signal_mux_40;
    wire signal_select_96;
    wire [27:0] signal_mux_41;
    wire [27:0] signal_and_19;
    wire [15:0] signal_select_97;
    wire [11:0] signal_select_98;
    wire [27:0] signal_cat_40;
    wire [7:0] signal_select_99;
    wire [19:0] signal_select_100;
    wire [27:0] signal_cat_41;
    wire [3:0] signal_select_101;
    wire [23:0] signal_select_102;
    wire [27:0] signal_cat_42;
    wire [1:0] signal_select_103;
    wire [25:0] signal_select_104;
    wire [27:0] signal_cat_43;
    wire [27:0] signal_const_38;
    wire [27:0] signal_const_39;
    wire signal_select_105;
    wire [27:0] signal_mux_42;
    wire signal_select_106;
    wire [27:0] signal_mux_43;
    wire signal_select_107;
    wire [27:0] signal_mux_44;
    wire signal_select_108;
    wire [27:0] signal_mux_45;
    wire signal_select_109;
    wire [27:0] signal_mux_46;
    wire [27:0] signal_and_20;
    wire [27:0] signal_not_8;
    wire [27:0] signal_and_21;
    wire [27:0] signal_or_6;
    wire [15:0] signal_select_110;
    wire [11:0] signal_select_111;
    wire [27:0] signal_cat_44;
    wire [7:0] signal_select_112;
    wire [19:0] signal_select_113;
    wire [27:0] signal_cat_45;
    wire [3:0] signal_select_114;
    wire [23:0] signal_select_115;
    wire [27:0] signal_cat_46;
    wire [1:0] signal_select_116;
    wire [25:0] signal_select_117;
    wire [27:0] signal_cat_47;
    wire signal_select_118;
    wire [26:0] signal_select_119;
    wire [27:0] signal_cat_48;
    wire [27:0] signal_cat_49;
    wire signal_select_120;
    wire [27:0] signal_mux_47;
    wire signal_select_121;
    wire [27:0] signal_mux_48;
    wire signal_select_122;
    wire [27:0] signal_mux_49;
    wire signal_select_123;
    wire [27:0] signal_mux_50;
    wire signal_select_124;
    wire [27:0] signal_mux_51;
    wire [27:0] signal_and_22;
    wire [15:0] signal_select_125;
    wire [11:0] signal_select_126;
    wire [27:0] signal_cat_50;
    wire [7:0] signal_select_127;
    wire [19:0] signal_select_128;
    wire [27:0] signal_cat_51;
    wire [3:0] signal_select_129;
    wire [23:0] signal_select_130;
    wire [27:0] signal_cat_52;
    wire [1:0] signal_select_131;
    wire [25:0] signal_select_132;
    wire [27:0] signal_cat_53;
    wire signal_select_133;
    wire [26:0] signal_select_134;
    wire [27:0] signal_cat_54;
    wire [7:0] signal_select_135;
    wire [15:0] signal_cat_55;
    wire [11:0] signal_select_136;
    wire [15:0] signal_cat_56;
    wire [13:0] signal_select_137;
    wire [15:0] signal_cat_57;
    wire signal_select_138;
    wire [15:0] signal_mux_52;
    wire signal_select_139;
    wire [15:0] signal_mux_53;
    wire signal_select_140;
    wire [15:0] signal_mux_54;
    wire signal_select_141;
    wire [15:0] signal_mux_55;
    wire signal_select_142;
    wire [15:0] signal_mux_56;
    wire [15:0] signal_not_9;
    wire [27:0] signal_cat_58;
    wire signal_select_143;
    wire [27:0] signal_mux_57;
    wire signal_select_144;
    wire [27:0] signal_mux_58;
    wire signal_select_145;
    wire [27:0] signal_mux_59;
    wire signal_select_146;
    wire [27:0] signal_mux_60;
    wire signal_select_147;
    wire [27:0] signal_mux_61;
    wire [27:0] signal_and_23;
    wire [27:0] signal_not_10;
    wire [27:0] signal_and_24;
    wire [27:0] signal_or_7;
    wire [27:0] signal_mux_62;
    wire signal_eq_7;
    wire [27:0] signal_mux_63;
    wire [15:0] signal_select_148;
    wire [11:0] signal_select_149;
    wire [27:0] signal_cat_59;
    wire [7:0] signal_select_150;
    wire [19:0] signal_select_151;
    wire [27:0] signal_cat_60;
    wire [3:0] signal_select_152;
    wire [23:0] signal_select_153;
    wire [27:0] signal_cat_61;
    wire [1:0] signal_select_154;
    wire [25:0] signal_select_155;
    wire [27:0] signal_cat_62;
    wire signal_select_156;
    wire [26:0] signal_select_157;
    wire [27:0] signal_cat_63;
    wire [15:0] signal_cat_64;
    wire [27:0] signal_cat_65;
    wire signal_select_158;
    wire [27:0] signal_mux_64;
    wire signal_select_159;
    wire [27:0] signal_mux_65;
    wire signal_select_160;
    wire [27:0] signal_mux_66;
    wire signal_select_161;
    wire [27:0] signal_mux_67;
    wire signal_select_162;
    wire [27:0] signal_mux_68;
    wire [27:0] signal_and_25;
    wire [15:0] signal_select_163;
    wire [11:0] signal_select_164;
    wire [27:0] signal_cat_66;
    wire [7:0] signal_select_165;
    wire [19:0] signal_select_166;
    wire [27:0] signal_cat_67;
    wire [3:0] signal_select_167;
    wire [23:0] signal_select_168;
    wire [27:0] signal_cat_68;
    wire [1:0] signal_select_169;
    wire [25:0] signal_select_170;
    wire [27:0] signal_cat_69;
    wire signal_select_171;
    wire [26:0] signal_select_172;
    wire [27:0] signal_cat_70;
    wire [7:0] signal_select_173;
    wire [15:0] signal_cat_71;
    wire [11:0] signal_select_174;
    wire [15:0] signal_cat_72;
    wire [13:0] signal_select_175;
    wire [15:0] signal_cat_73;
    wire signal_select_176;
    wire [15:0] signal_mux_69;
    wire signal_select_177;
    wire [15:0] signal_mux_70;
    wire signal_select_178;
    wire [15:0] signal_mux_71;
    wire signal_select_179;
    wire [15:0] signal_mux_72;
    wire signal_select_180;
    wire [15:0] signal_mux_73;
    wire [15:0] signal_not_11;
    wire [27:0] signal_cat_74;
    wire signal_select_181;
    wire [27:0] signal_mux_74;
    wire signal_select_182;
    wire [27:0] signal_mux_75;
    wire signal_select_183;
    wire [27:0] signal_mux_76;
    wire signal_select_184;
    wire [27:0] signal_mux_77;
    wire signal_select_185;
    wire [27:0] signal_mux_78;
    wire [27:0] signal_and_26;
    wire [27:0] signal_not_12;
    wire [27:0] signal_and_27;
    wire [27:0] pin_out_side;
    wire [27:0] pin_out_base;
    reg [27:0] pin_out_next;
    wire [15:0] signal_select_186;
    wire [11:0] signal_select_187;
    wire [27:0] signal_cat_75;
    wire [7:0] signal_select_188;
    wire [19:0] signal_select_189;
    wire [27:0] signal_cat_76;
    wire [3:0] signal_select_190;
    wire [23:0] signal_select_191;
    wire [27:0] signal_cat_77;
    wire [1:0] signal_select_192;
    wire [25:0] signal_select_193;
    wire [27:0] signal_cat_78;
    wire signal_select_194;
    wire [26:0] signal_select_195;
    wire [27:0] signal_cat_79;
    wire signal_not_13;
    wire signal_select_196;
    reg signal_reg_5;
    wire flip_bit_0;
    wire signal_not_14;
    wire [1:0] signal_cat_80;
    wire [15:0] signal_cat_81;
    wire [27:0] signal_cat_82;
    wire signal_select_197;
    wire [27:0] signal_mux_79;
    wire signal_select_198;
    wire [27:0] signal_mux_80;
    wire signal_select_199;
    wire [27:0] signal_mux_81;
    wire signal_select_200;
    wire [27:0] signal_mux_82;
    wire signal_select_201;
    wire [27:0] signal_mux_83;
    wire [27:0] signal_and_28;
    wire [15:0] signal_select_202;
    wire [11:0] signal_select_203;
    wire [27:0] signal_cat_83;
    wire [7:0] signal_select_204;
    wire [19:0] signal_select_205;
    wire [27:0] signal_cat_84;
    wire [3:0] signal_select_206;
    wire [23:0] signal_select_207;
    wire [27:0] signal_cat_85;
    wire [1:0] signal_select_208;
    wire [25:0] signal_select_209;
    wire [27:0] signal_cat_86;
    wire signal_select_210;
    wire [27:0] signal_mux_84;
    wire signal_select_211;
    wire [27:0] signal_mux_85;
    wire signal_select_212;
    wire [27:0] signal_mux_86;
    wire signal_select_213;
    wire [27:0] signal_mux_87;
    wire signal_select_214;
    wire [27:0] signal_mux_88;
    wire [27:0] signal_and_29;
    wire [27:0] signal_not_15;
    wire [27:0] signal_and_30;
    wire [27:0] signal_or_8;
    wire signal_mux_89;
    wire [4:0] signal_const_67;
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
    wire signal_not_18;
    wire [4:0] signal_const_69;
    wire [4:0] signal_const_73;
    wire [4:0] signal_and_33;
    wire [4:0] signal_and_34;
    wire [4:0] signal_const_75;
    wire [4:0] signal_and_35;
    reg [4:0] d$delay;
    wire [4:0] signal_sub_2;
    wire signal_eq_10;
    wire signal_not_19;
    wire [4:0] signal_mux_92;
    wire [4:0] signal_mux_93;
    wire [4:0] signal_mux_94;
    wire [4:0] stall_next;
    reg [4:0] signal_reg_7;
    wire [4:0] stall_0;
    wire signal_eq_11;
    wire [3:0] signal_const_78;
    wire signal_eq_12;
    wire signal_and_36;
    wire signal_and_37;
    wire signal_mux_95;
    wire signal_not_20;
    wire signal_and_38;
    wire signal_and_39;
    reg step_asked;
    wire signal_mux_96;
    wire signal_mux_97;
    wire signal_mux_98;
    reg signal_reg_8;
    wire stepping_0;
    wire signal_and_40;
    wire signal_mux_99;
    wire [3:0] signal_const_81;
    wire [3:0] signal_select_215;
    wire signal_lt;
    wire [3:0] signal_select_216;
    wire signal_eq_13;
    wire signal_and_41;
    wire [2:0] signal_select_217;
    wire signal_lt_1;
    wire signal_select_218;
    wire signal_not_21;
    wire signal_or_9;
    wire [1:0] signal_const_84;
    wire [1:0] signal_select_219;
    wire signal_lt_2;
    wire signal_and_42;
    wire [2:0] signal_select_220;
    wire signal_lt_3;
    wire [1:0] signal_select_221;
    wire signal_lt_4;
    wire [4:0] signal_const_87;
    wire signal_lt_5;
    wire signal_not_22;
    wire [4:0] signal_select_222;
    wire signal_lt_6;
    wire signal_not_23;
    wire signal_and_43;
    wire signal_eq_14;
    wire signal_eq_15;
    wire [4:0] signal_const_91;
    wire signal_lt_7;
    wire signal_lt_8;
    wire [1:0] signal_select_223;
    reg signal_mux_100;
    wire [3:0] signal_const_93;
    wire [3:0] signal_select_224;
    wire signal_lt_9;
    reg signal_mux_101;
    reg decode_ok_0;
    wire signal_not_24;
    wire signal_and_44;
    wire signal_mux_102;
    wire completes;
    wire signal_mux_103;
    wire signal_mux_104;
    wire signal_mux_105;
    reg signal_reg_9;
    wire resumed_0;
    wire signal_not_25;
    wire [8:0] signal_wire_3;
    wire [8:0] signal_mux_106;
    wire [15:0] signal_wire_4;
    wire [8:0] signal_wire_5;
    wire [8:0] d$jmp_target;
    wire signal_not_26;
    wire signal_not_27;
    wire [4:0] signal_add_1;
    wire [4:0] stuff_run_max;
    wire signal_eq_16;
    wire [4:0] signal_mux_107;
    wire signal_wire_6;
    wire signal_eq_17;
    wire [4:0] signal_mux_108;
    wire [4:0] signal_mux_109;
    wire [3:0] signal_const_105;
    wire signal_eq_18;
    wire signal_and_45;
    wire [4:0] stuff_run_next;
    wire [4:0] signal_mux_110;
    wire [4:0] signal_mux_111;
    reg [4:0] signal_reg_10;
    wire [4:0] stuff_run_0;
    wire signal_lt_10;
    wire signal_not_28;
    wire [4:0] signal_wire_7;
    wire signal_eq_19;
    wire signal_not_29;
    wire signal_and_46;
    wire signal_lt_11;
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
    reg signal_mux_112;
    wire signal_not_30;
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
    wire signal_select_276;
    wire signal_select_277;
    wire signal_select_278;
    wire signal_select_279;
    wire signal_select_280;
    wire [4:0] signal_wire_8;
    reg signal_mux_113;
    wire signal_eq_20;
    wire signal_not_31;
    wire signal_eq_21;
    wire signal_not_32;
    wire signal_eq_22;
    wire signal_not_33;
    reg jmp_taken;
    wire [8:0] jmp_target_or_next;
    wire signal_eq_23;
    wire [8:0] signal_mux_114;
    wire [8:0] signal_add_2;
    wire signal_eq_24;
    wire [8:0] signal_mux_115;
    wire [8:0] signal_wire_9;
    wire [8:0] signal_add_3;
    wire [8:0] signal_wire_10;
    reg [8:0] signal_reg_11;
    wire [8:0] pc_0;
    wire signal_eq_25;
    wire [8:0] pc_next;
    wire signal_not_34;
    wire signal_wire_11;
    wire [15:0] signal_mux_116;
    wire [15:0] signal_wire_12;
    wire signal_not_35;
    wire [3:0] signal_const_114;
    wire signal_eq_26;
    wire signal_and_47;
    wire signal_and_48;
    wire pushes;
    wire signal_and_49;
    wire signal_and_50;
    wire signal_wire_13;
    wire [21:0] signal_inst;
    wire signal_select_281;
    wire signal_not_36;
    wire signal_mux_117;
    wire [23:0] signal_xor;
    wire [23:0] signal_sub_3;
    wire [23:0] signal_cat_87;
    wire [23:0] signal_add_4;
    reg [23:0] signal_mux_118;
    wire signal_eq_27;
    wire [23:0] signal_mux_119;
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
    wire [23:0] signal_cat_88;
    wire [23:0] signal_not_37;
    reg [23:0] mov_value_t;
    wire [2:0] signal_const_118;
    wire signal_eq_28;
    wire [23:0] signal_mux_120;
    wire [23:0] signal_cat_89;
    wire signal_eq_29;
    wire [23:0] signal_mux_121;
    wire [15:0] signal_wire_14;
    wire [16:0] signal_cat_90;
    wire signal_eq_30;
    wire [15:0] signal_mux_122;
    wire signal_eq_31;
    wire [15:0] signal_mux_123;
    wire signal_eq_32;
    wire [15:0] signal_mux_124;
    wire [15:0] signal_select_306;
    wire [15:0] signal_mux_125;
    reg [15:0] t_fraction_next;
    reg [15:0] signal_reg_12;
    wire [15:0] t_fraction_0;
    wire [16:0] signal_cat_91;
    wire [16:0] fraction_sum;
    wire signal_select_307;
    wire [22:0] signal_const_128;
    wire [23:0] signal_cat_92;
    wire [23:0] signal_cat_93;
    wire [23:0] signal_add_5;
    wire [23:0] t_advanced;
    wire [1:0] signal_const_130;
    wire signal_eq_33;
    wire signal_and_51;
    wire releases_deadline;
    wire advances_deadline;
    wire [23:0] signal_mux_126;
    reg [23:0] t_next;
    reg [23:0] signal_reg_13;
    wire [23:0] t_0;
    wire [23:0] signal_sub_4;
    wire signal_select_308;
    wire deadline_ready;
    wire signal_eq_34;
    wire [27:0] signal_and_52;
    wire signal_eq_35;
    wire wait_pin_prev;
    wire signal_eq_36;
    wire signal_not_38;
    wire signal_and_53;
    wire d$wait_polarity;
    wire [27:0] signal_const_133;
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
    wire signal_and_65;
    wire signal_and_66;
    wire signal_and_67;
    wire signal_and_68;
    wire signal_not_39;
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
    wire signal_and_80;
    wire signal_and_81;
    wire signal_and_82;
    wire signal_and_83;
    wire signal_not_40;
    wire signal_and_84;
    wire signal_and_85;
    wire signal_and_86;
    wire signal_and_87;
    wire signal_and_88;
    wire signal_and_89;
    wire signal_and_90;
    wire signal_and_91;
    wire signal_and_92;
    wire signal_and_93;
    wire signal_and_94;
    wire signal_not_41;
    wire signal_and_95;
    wire signal_and_96;
    wire signal_and_97;
    wire signal_and_98;
    wire signal_and_99;
    wire signal_and_100;
    wire signal_and_101;
    wire signal_not_42;
    wire signal_and_102;
    wire signal_and_103;
    wire signal_and_104;
    wire signal_and_105;
    wire signal_not_43;
    wire signal_and_106;
    wire signal_and_107;
    wire signal_and_108;
    wire signal_and_109;
    wire signal_select_309;
    wire signal_select_310;
    wire signal_and_110;
    wire signal_select_311;
    wire signal_and_111;
    wire signal_select_312;
    wire signal_and_112;
    wire [4:0] signal_select_313;
    wire signal_select_314;
    wire signal_and_113;
    wire [31:0] signal_cat_94;
    wire [27:0] signal_select_315;
    reg [27:0] wait_select_0;
    wire signal_select_316;
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
    wire signal_mux_127;
    wire signal_select_331;
    wire signal_select_332;
    wire signal_select_333;
    wire signal_mux_128;
    wire signal_select_334;
    wire signal_select_335;
    wire signal_select_336;
    wire signal_mux_129;
    wire signal_select_337;
    wire signal_select_338;
    wire signal_select_339;
    wire signal_mux_130;
    wire signal_select_340;
    wire signal_select_341;
    wire signal_select_342;
    wire signal_mux_131;
    wire signal_select_343;
    wire signal_select_344;
    wire signal_select_345;
    wire signal_mux_132;
    wire signal_select_346;
    wire signal_select_347;
    wire signal_select_348;
    wire signal_mux_133;
    wire signal_select_349;
    wire signal_select_350;
    wire [15:0] signal_select_351;
    wire [11:0] signal_select_352;
    wire [27:0] signal_cat_95;
    wire [7:0] signal_select_353;
    wire [19:0] signal_select_354;
    wire [27:0] signal_cat_96;
    wire [3:0] signal_select_355;
    wire [23:0] signal_select_356;
    wire [27:0] signal_cat_97;
    wire [1:0] signal_select_357;
    wire [25:0] signal_select_358;
    wire [27:0] signal_cat_98;
    wire signal_select_359;
    wire [26:0] signal_select_360;
    wire [27:0] signal_cat_99;
    wire [15:0] signal_cat_100;
    wire [27:0] signal_cat_101;
    wire signal_select_361;
    wire [27:0] signal_mux_134;
    wire signal_select_362;
    wire [27:0] signal_mux_135;
    wire signal_select_363;
    wire [27:0] signal_mux_136;
    wire signal_select_364;
    wire [27:0] signal_mux_137;
    wire signal_select_365;
    wire [27:0] signal_mux_138;
    wire [27:0] signal_and_114;
    wire [27:0] signal_const_137;
    wire [15:0] signal_select_366;
    wire [11:0] signal_select_367;
    wire [27:0] signal_cat_102;
    wire [7:0] signal_select_368;
    wire [19:0] signal_select_369;
    wire [27:0] signal_cat_103;
    wire [3:0] signal_select_370;
    wire [23:0] signal_select_371;
    wire [27:0] signal_cat_104;
    wire [1:0] signal_select_372;
    wire [25:0] signal_select_373;
    wire [27:0] signal_cat_105;
    wire signal_select_374;
    wire [26:0] signal_select_375;
    wire [27:0] signal_cat_106;
    wire [7:0] signal_select_376;
    wire [15:0] signal_cat_107;
    wire [11:0] signal_select_377;
    wire [15:0] signal_cat_108;
    wire [13:0] signal_select_378;
    wire [15:0] signal_cat_109;
    wire signal_select_379;
    wire [15:0] signal_mux_139;
    wire signal_select_380;
    wire [15:0] signal_mux_140;
    wire signal_select_381;
    wire [15:0] signal_mux_141;
    wire signal_select_382;
    wire [15:0] signal_mux_142;
    wire [2:0] signal_wire_15;
    wire [4:0] signal_cat_110;
    wire signal_select_383;
    wire [15:0] signal_mux_143;
    wire [15:0] signal_not_44;
    wire [27:0] signal_cat_111;
    wire signal_select_384;
    wire [27:0] signal_mux_144;
    wire signal_select_385;
    wire [27:0] signal_mux_145;
    wire signal_select_386;
    wire [27:0] signal_mux_146;
    wire signal_select_387;
    wire [27:0] signal_mux_147;
    wire [4:0] signal_wire_16;
    wire signal_select_388;
    wire [27:0] signal_mux_148;
    wire [27:0] signal_and_115;
    wire [27:0] signal_not_45;
    wire [27:0] signal_and_116;
    wire [27:0] signal_or_10;
    wire [2:0] signal_const_146;
    wire signal_eq_37;
    wire [27:0] signal_mux_149;
    wire [15:0] signal_select_389;
    wire [11:0] signal_select_390;
    wire [27:0] signal_cat_112;
    wire [7:0] signal_select_391;
    wire [19:0] signal_select_392;
    wire [27:0] signal_cat_113;
    wire [3:0] signal_select_393;
    wire [23:0] signal_select_394;
    wire [27:0] signal_cat_114;
    wire [1:0] signal_select_395;
    wire [25:0] signal_select_396;
    wire [27:0] signal_cat_115;
    wire signal_select_397;
    wire [26:0] signal_select_398;
    wire [27:0] signal_cat_116;
    wire [27:0] signal_cat_117;
    wire signal_select_399;
    wire [27:0] signal_mux_150;
    wire signal_select_400;
    wire [27:0] signal_mux_151;
    wire signal_select_401;
    wire [27:0] signal_mux_152;
    wire signal_select_402;
    wire [27:0] signal_mux_153;
    wire signal_select_403;
    wire [27:0] signal_mux_154;
    wire [27:0] signal_and_117;
    wire [15:0] signal_select_404;
    wire [11:0] signal_select_405;
    wire [27:0] signal_cat_118;
    wire [7:0] signal_select_406;
    wire [19:0] signal_select_407;
    wire [27:0] signal_cat_119;
    wire [3:0] signal_select_408;
    wire [23:0] signal_select_409;
    wire [27:0] signal_cat_120;
    wire [1:0] signal_select_410;
    wire [25:0] signal_select_411;
    wire [27:0] signal_cat_121;
    wire signal_select_412;
    wire [26:0] signal_select_413;
    wire [27:0] signal_cat_122;
    wire [7:0] signal_select_414;
    wire [15:0] signal_cat_123;
    wire [11:0] signal_select_415;
    wire [15:0] signal_cat_124;
    wire [13:0] signal_select_416;
    wire [15:0] signal_cat_125;
    wire signal_select_417;
    wire [15:0] signal_mux_155;
    wire signal_select_418;
    wire [15:0] signal_mux_156;
    wire signal_select_419;
    wire [15:0] signal_mux_157;
    wire signal_select_420;
    wire [15:0] signal_mux_158;
    wire [4:0] signal_wire_17;
    wire signal_select_421;
    wire [15:0] signal_mux_159;
    wire [15:0] signal_not_46;
    wire [27:0] signal_cat_126;
    wire signal_select_422;
    wire [27:0] signal_mux_160;
    wire signal_select_423;
    wire [27:0] signal_mux_161;
    wire signal_select_424;
    wire [27:0] signal_mux_162;
    wire signal_select_425;
    wire [27:0] signal_mux_163;
    wire signal_select_426;
    wire [27:0] signal_mux_164;
    wire [27:0] signal_and_118;
    wire [27:0] signal_not_47;
    wire [27:0] signal_and_119;
    wire [27:0] signal_or_11;
    wire signal_eq_38;
    wire [27:0] signal_mux_165;
    wire [15:0] signal_select_427;
    wire [11:0] signal_select_428;
    wire [27:0] signal_cat_127;
    wire [7:0] signal_select_429;
    wire [19:0] signal_select_430;
    wire [27:0] signal_cat_128;
    wire [3:0] signal_select_431;
    wire [23:0] signal_select_432;
    wire [27:0] signal_cat_129;
    wire [1:0] signal_select_433;
    wire [25:0] signal_select_434;
    wire [27:0] signal_cat_130;
    wire signal_select_435;
    wire [26:0] signal_select_436;
    wire [27:0] signal_cat_131;
    wire [15:0] signal_and_120;
    wire [7:0] signal_select_437;
    wire [15:0] signal_cat_132;
    wire [11:0] signal_select_438;
    wire [15:0] signal_cat_133;
    wire [13:0] signal_select_439;
    wire [15:0] signal_cat_134;
    wire [14:0] signal_select_440;
    wire [15:0] signal_cat_135;
    wire [15:0] signal_wire_18;
    wire [15:0] signal_select_441;
    wire signal_not_48;
    wire signal_and_121;
    wire [15:0] signal_mux_166;
    wire signal_select_442;
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
    wire [15:0] signal_cat_136;
    wire [15:0] signal_not_49;
    wire [23:0] signal_cat_137;
    wire [23:0] signal_cat_138;
    wire [23:0] signal_cat_139;
    wire [15:0] signal_xor_1;
    wire [15:0] signal_sub_5;
    wire signal_eq_39;
    wire signal_and_122;
    wire [15:0] signal_mux_167;
    wire signal_eq_40;
    wire [15:0] signal_mux_168;
    wire signal_eq_41;
    wire [15:0] signal_mux_169;
    wire [7:0] signal_select_458;
    wire [15:0] signal_cat_140;
    wire [11:0] signal_select_459;
    wire [15:0] signal_cat_141;
    wire [13:0] signal_select_460;
    wire [15:0] signal_cat_142;
    wire [14:0] signal_select_461;
    wire [15:0] signal_cat_143;
    wire signal_select_462;
    wire [15:0] signal_mux_170;
    wire signal_select_463;
    wire [15:0] signal_mux_171;
    wire signal_select_464;
    wire [15:0] signal_mux_172;
    wire signal_select_465;
    wire [15:0] signal_mux_173;
    wire signal_select_466;
    wire [15:0] signal_mux_174;
    wire [7:0] signal_select_467;
    wire [15:0] signal_cat_144;
    wire [11:0] signal_select_468;
    wire [15:0] signal_cat_145;
    wire [13:0] signal_select_469;
    wire [15:0] signal_cat_146;
    wire [14:0] signal_select_470;
    wire [15:0] signal_cat_147;
    wire signal_select_471;
    wire [15:0] signal_mux_175;
    wire signal_select_472;
    wire [15:0] signal_mux_176;
    wire signal_select_473;
    wire [15:0] signal_mux_177;
    wire signal_select_474;
    wire [15:0] signal_mux_178;
    wire signal_select_475;
    wire [15:0] signal_mux_179;
    wire [15:0] signal_or_12;
    wire [7:0] signal_select_476;
    wire [15:0] signal_cat_148;
    wire [11:0] signal_select_477;
    wire [15:0] signal_cat_149;
    wire [13:0] signal_select_478;
    wire [15:0] signal_cat_150;
    wire signal_select_479;
    wire [15:0] signal_mux_180;
    wire signal_select_480;
    wire [15:0] signal_mux_181;
    wire signal_select_481;
    wire [15:0] signal_mux_182;
    wire signal_select_482;
    wire [15:0] signal_mux_183;
    wire signal_select_483;
    wire [15:0] signal_mux_184;
    wire [15:0] mask;
    wire signal_wire_19;
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
    reg signal_mux_185;
    wire signal_eq_42;
    wire signal_select_512;
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
    reg [27:0] signal_reg_14;
    wire [27:0] pins_sampled;
    wire signal_select_539;
    reg signal_mux_186;
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
    wire [4:0] signal_wire_20;
    reg signal_mux_187;
    wire signal_eq_43;
    wire signal_not_50;
    wire [3:0] signal_const_192;
    wire signal_eq_44;
    wire signal_and_123;
    wire signal_and_124;
    wire signal_mux_188;
    wire signal_mux_189;
    reg signal_reg_15;
    wire capture_armed_0;
    wire signal_and_125;
    wire captured;
    wire [23:0] signal_const_196;
    wire [23:0] signal_add_6;
    wire [23:0] signal_mux_190;
    reg [23:0] signal_reg_16;
    wire [23:0] now_0;
    reg [23:0] signal_reg_17;
    wire [23:0] capture_0;
    wire [15:0] signal_select_568;
    wire [15:0] signal_wire_21;
    wire [7:0] signal_select_569;
    wire [15:0] signal_cat_151;
    wire [11:0] signal_select_570;
    wire [15:0] signal_cat_152;
    wire [13:0] signal_select_571;
    wire [15:0] signal_cat_153;
    wire signal_select_572;
    wire [15:0] signal_mux_191;
    wire signal_select_573;
    wire [15:0] signal_mux_192;
    wire signal_select_574;
    wire [15:0] signal_mux_193;
    wire signal_select_575;
    wire [15:0] signal_mux_194;
    wire signal_select_576;
    wire [15:0] signal_mux_195;
    wire [15:0] signal_not_51;
    wire [15:0] signal_xor_2;
    wire [14:0] signal_select_577;
    wire [15:0] signal_cat_154;
    wire signal_select_578;
    wire signal_xor_3;
    wire [15:0] signal_mux_196;
    wire [15:0] signal_wire_22;
    wire [15:0] signal_xor_4;
    wire [14:0] signal_select_579;
    wire [15:0] signal_cat_155;
    wire signal_select_580;
    wire signal_select_581;
    wire crossing_bit;
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
    wire signal_select_593;
    wire signal_select_594;
    wire signal_select_595;
    wire signal_select_596;
    wire signal_select_597;
    wire [4:0] signal_wire_23;
    wire [4:0] signal_sub_6;
    reg signal_mux_197;
    wire signal_xor_5;
    wire [15:0] signal_mux_198;
    wire signal_wire_24;
    wire [15:0] signal_mux_199;
    wire [15:0] crc_stepped;
    wire [2:0] signal_const_207;
    wire signal_eq_45;
    reg is_opcode$2;
    wire signal_or_13;
    wire signal_eq_46;
    wire bit_crosses;
    wire [15:0] signal_mux_200;
    wire [3:0] signal_const_209;
    wire signal_eq_47;
    wire signal_and_126;
    wire [15:0] crc_next;
    wire [15:0] signal_mux_201;
    wire [15:0] signal_mux_202;
    reg [15:0] signal_reg_18;
    wire [15:0] crc_0;
    wire [7:0] signal_select_598;
    wire [15:0] signal_cat_156;
    wire [11:0] signal_select_599;
    wire [15:0] signal_cat_157;
    wire [13:0] signal_select_600;
    wire [15:0] signal_cat_158;
    wire signal_select_601;
    wire [15:0] signal_mux_203;
    wire signal_select_602;
    wire [15:0] signal_mux_204;
    wire signal_select_603;
    wire [15:0] signal_mux_205;
    wire signal_select_604;
    wire [15:0] signal_mux_206;
    wire signal_select_605;
    wire [15:0] signal_mux_207;
    wire [15:0] signal_not_52;
    wire [11:0] signal_select_606;
    wire [15:0] signal_select_607;
    wire [27:0] signal_cat_159;
    wire [19:0] signal_select_608;
    wire [7:0] signal_select_609;
    wire [27:0] signal_cat_160;
    wire [23:0] signal_select_610;
    wire [3:0] signal_select_611;
    wire [27:0] signal_cat_161;
    wire [25:0] signal_select_612;
    wire [1:0] signal_select_613;
    wire [27:0] signal_cat_162;
    wire [26:0] signal_select_614;
    wire signal_select_615;
    wire [27:0] signal_cat_163;
    wire signal_select_616;
    wire [27:0] signal_mux_208;
    wire signal_select_617;
    wire [27:0] signal_mux_209;
    wire signal_select_618;
    wire [27:0] signal_mux_210;
    wire signal_select_619;
    wire [27:0] signal_mux_211;
    wire signal_select_620;
    wire [27:0] signal_mux_212;
    wire [15:0] signal_select_621;
    wire [15:0] signal_and_127;
    reg [15:0] signal_mux_213;
    wire [15:0] in_value;
    wire [7:0] signal_select_622;
    wire [15:0] signal_cat_164;
    wire [11:0] signal_select_623;
    wire [15:0] signal_cat_165;
    wire [13:0] signal_select_624;
    wire [15:0] signal_cat_166;
    wire [14:0] signal_select_625;
    wire [15:0] signal_cat_167;
    wire signal_select_626;
    wire [15:0] signal_mux_214;
    wire signal_select_627;
    wire [15:0] signal_mux_215;
    wire signal_select_628;
    wire [15:0] signal_mux_216;
    wire signal_select_629;
    wire [15:0] signal_mux_217;
    wire signal_select_630;
    wire [15:0] signal_mux_218;
    wire [15:0] signal_or_14;
    wire signal_wire_25;
    wire [15:0] isr_shifted;
    wire [4:0] signal_wire_26;
    wire [4:0] signal_select_631;
    wire [5:0] signal_cat_168;
    wire signal_eq_48;
    wire signal_and_128;
    wire [4:0] signal_mux_219;
    wire signal_eq_49;
    wire [4:0] signal_mux_220;
    wire signal_eq_50;
    wire [4:0] signal_mux_221;
    wire [4:0] signal_mux_222;
    reg [4:0] isr_count_next_value;
    reg [4:0] signal_reg_19;
    wire [4:0] isr_count_0;
    wire [5:0] signal_cat_169;
    wire [5:0] signal_add_7;
    wire [5:0] signal_const_227;
    wire signal_lt_12;
    wire [4:0] isr_count_next;
    wire signal_lt_13;
    wire signal_not_53;
    wire signal_wire_27;
    wire autopush_now;
    wire [15:0] signal_mux_223;
    reg [15:0] isr_next;
    reg [15:0] signal_reg_20;
    wire [15:0] isr_0;
    wire [15:0] signal_xor_6;
    wire [15:0] signal_sub_7;
    wire [15:0] signal_add_8;
    reg [15:0] signal_mux_224;
    wire signal_eq_51;
    wire [15:0] signal_mux_225;
    wire [15:0] signal_cat_170;
    wire signal_eq_52;
    wire [15:0] signal_mux_226;
    wire signal_eq_53;
    wire [15:0] signal_mux_227;
    wire signal_eq_54;
    wire [15:0] signal_mux_228;
    reg [15:0] p_next;
    reg [15:0] signal_reg_21;
    wire [15:0] p_0;
    wire [15:0] signal_xor_7;
    wire [15:0] signal_sub_8;
    wire [15:0] signal_add_9;
    reg [15:0] signal_mux_229;
    wire [1:0] signal_const_235;
    wire signal_eq_55;
    wire [15:0] signal_mux_230;
    wire [15:0] signal_cat_171;
    wire signal_eq_56;
    wire [15:0] signal_mux_231;
    wire signal_eq_57;
    wire [15:0] signal_mux_232;
    wire signal_eq_58;
    wire [15:0] signal_mux_233;
    wire [15:0] signal_const_240;
    wire [15:0] signal_sub_9;
    wire signal_eq_59;
    wire [15:0] signal_mux_234;
    reg [15:0] y_next;
    reg [15:0] signal_reg_22;
    wire [15:0] y_0;
    reg [15:0] signal_mux_235;
    wire [2:0] d$alu_reg$binary_variant;
    wire [2:0] d$alu_imm;
    wire [12:0] signal_const_242;
    wire [15:0] signal_cat_172;
    wire d$alu_is_reg;
    wire [15:0] alu_operand;
    wire [15:0] signal_add_10;
    wire [1:0] d$alu_op$binary_variant;
    reg [15:0] signal_mux_236;
    wire [1:0] d$alu_dest$binary_variant;
    wire signal_eq_60;
    wire [15:0] signal_mux_237;
    wire [4:0] d$set_value;
    wire [15:0] signal_cat_173;
    wire [2:0] signal_const_245;
    wire [2:0] d$set_dest$binary_variant;
    wire signal_eq_61;
    wire [15:0] signal_mux_238;
    wire signal_eq_62;
    wire [15:0] signal_mux_239;
    wire signal_eq_63;
    wire [15:0] signal_mux_240;
    wire [15:0] signal_sub_10;
    wire [3:0] d$jmp_cond$binary_variant;
    wire signal_eq_64;
    wire [15:0] signal_mux_241;
    reg [15:0] x_next;
    reg [15:0] signal_reg_23;
    wire [15:0] x_0;
    wire [23:0] signal_cat_174;
    wire [7:0] signal_select_632;
    wire [15:0] signal_cat_175;
    wire [11:0] signal_select_633;
    wire [15:0] signal_cat_176;
    wire [13:0] signal_select_634;
    wire [15:0] signal_cat_177;
    wire signal_select_635;
    wire [15:0] signal_mux_242;
    wire signal_select_636;
    wire [15:0] signal_mux_243;
    wire signal_select_637;
    wire [15:0] signal_mux_244;
    wire signal_select_638;
    wire [15:0] signal_mux_245;
    wire [4:0] signal_wire_28;
    wire signal_select_639;
    wire [15:0] signal_mux_246;
    wire [15:0] signal_not_54;
    wire [11:0] signal_select_640;
    wire [15:0] signal_select_641;
    wire [27:0] signal_cat_178;
    wire [19:0] signal_select_642;
    wire [7:0] signal_select_643;
    wire [27:0] signal_cat_179;
    wire [23:0] signal_select_644;
    wire [3:0] signal_select_645;
    wire [27:0] signal_cat_180;
    wire [25:0] signal_select_646;
    wire [1:0] signal_select_647;
    wire [27:0] signal_cat_181;
    wire [26:0] signal_select_648;
    wire signal_select_649;
    wire [27:0] signal_cat_182;
    wire signal_select_650;
    wire [27:0] signal_mux_247;
    wire signal_select_651;
    wire [27:0] signal_mux_248;
    wire signal_select_652;
    wire [27:0] signal_mux_249;
    wire signal_select_653;
    wire [27:0] signal_mux_250;
    wire [4:0] signal_wire_29;
    wire signal_select_654;
    wire [27:0] signal_mux_251;
    wire [15:0] signal_select_655;
    wire [15:0] signal_and_129;
    wire [23:0] signal_cat_183;
    wire [2:0] d$mov_source$binary_variant;
    reg [23:0] mov_value24;
    wire [15:0] signal_select_656;
    wire [1:0] d$mov_op$binary_variant;
    reg [15:0] mov_value;
    wire signal_eq_65;
    wire [15:0] signal_mux_252;
    wire [7:0] signal_select_657;
    wire [15:0] signal_cat_184;
    wire [11:0] signal_select_658;
    wire [15:0] signal_cat_185;
    wire [13:0] signal_select_659;
    wire [15:0] signal_cat_186;
    wire [14:0] signal_select_660;
    wire [15:0] signal_cat_187;
    wire signal_select_661;
    wire [15:0] signal_mux_253;
    wire signal_select_662;
    wire [15:0] signal_mux_254;
    wire signal_select_663;
    wire [15:0] signal_mux_255;
    wire signal_select_664;
    wire [15:0] signal_mux_256;
    wire signal_select_665;
    wire [15:0] signal_mux_257;
    wire [7:0] signal_select_666;
    wire [15:0] signal_cat_188;
    wire [11:0] signal_select_667;
    wire [15:0] signal_cat_189;
    wire [13:0] signal_select_668;
    wire [15:0] signal_cat_190;
    wire [14:0] signal_select_669;
    wire [15:0] signal_cat_191;
    wire signal_select_670;
    wire [15:0] signal_mux_258;
    wire signal_select_671;
    wire [15:0] signal_mux_259;
    wire signal_select_672;
    wire [15:0] signal_mux_260;
    wire signal_select_673;
    wire [15:0] signal_mux_261;
    wire signal_select_674;
    wire [15:0] signal_mux_262;
    wire [15:0] osr_shifted;
    reg [15:0] osr_next;
    reg [15:0] signal_reg_24;
    wire [15:0] osr_0;
    wire signal_wire_30;
    wire flush_0;
    wire signal_not_55;
    wire signal_and_130;
    wire signal_and_131;
    wire signal_or_15;
    wire signal_and_132;
    wire tx_pop;
    wire [15:0] signal_wire_31;
    wire signal_wire_32;
    wire [21:0] signal_inst_1;
    wire signal_select_675;
    wire signal_not_56;
    wire signal_not_57;
    wire pull_fifo;
    wire pull_ok;
    wire [15:0] signal_mux_263;
    wire signal_eq_66;
    reg is_opcode$3;
    wire signal_and_133;
    wire pulls_data;
    wire [3:0] signal_const_271;
    wire signal_eq_67;
    wire signal_and_134;
    wire seeks;
    wire signal_or_16;
    wire signal_mux_264;
    reg signal_reg_25;
    wire data_moved;
    wire signal_not_58;
    wire signal_wire_33;
    wire [4:0] signal_wire_34;
    wire [3:0] signal_const_273;
    wire [3:0] d$sys_op$binary_variant;
    wire signal_eq_68;
    wire signal_eq_69;
    reg is_opcode$7;
    wire pulls;
    wire [4:0] signal_mux_265;
    wire [4:0] osr_count_zero;
    wire [2:0] d$mov_dest$binary_variant;
    wire signal_eq_70;
    wire [4:0] signal_mux_266;
    wire [4:0] signal_select_676;
    wire [5:0] signal_cat_192;
    wire [4:0] osr_count_before;
    wire [5:0] signal_cat_193;
    wire [5:0] signal_add_11;
    wire signal_lt_14;
    wire [4:0] osr_count_next;
    reg [4:0] osr_count_next_value;
    reg [4:0] signal_reg_26;
    wire [4:0] osr_count_0;
    wire signal_lt_15;
    wire signal_not_59;
    wire signal_wire_35;
    wire pull_now;
    wire pull_data;
    wire pull_data_ok;
    wire [15:0] osr_before;
    wire signal_select_677;
    wire [15:0] signal_mux_267;
    wire signal_select_678;
    wire [15:0] signal_mux_268;
    wire signal_select_679;
    wire [15:0] signal_mux_269;
    wire signal_select_680;
    wire [15:0] signal_mux_270;
    wire [4:0] shift_back;
    wire signal_select_681;
    wire [15:0] signal_mux_271;
    wire [15:0] signal_and_135;
    wire signal_wire_36;
    wire [15:0] out_value;
    wire [27:0] signal_cat_194;
    wire signal_select_682;
    wire [27:0] signal_mux_272;
    wire signal_select_683;
    wire [27:0] signal_mux_273;
    wire signal_select_684;
    wire [27:0] signal_mux_274;
    wire signal_select_685;
    wire [27:0] signal_mux_275;
    wire signal_select_686;
    wire [27:0] signal_mux_276;
    wire [27:0] signal_and_136;
    wire [15:0] signal_select_687;
    wire [11:0] signal_select_688;
    wire [27:0] signal_cat_195;
    wire [7:0] signal_select_689;
    wire [19:0] signal_select_690;
    wire [27:0] signal_cat_196;
    wire [3:0] signal_select_691;
    wire [23:0] signal_select_692;
    wire [27:0] signal_cat_197;
    wire [1:0] signal_select_693;
    wire [25:0] signal_select_694;
    wire [27:0] signal_cat_198;
    wire signal_select_695;
    wire [26:0] signal_select_696;
    wire [27:0] signal_cat_199;
    wire [7:0] signal_select_697;
    wire [15:0] signal_cat_200;
    wire [11:0] signal_select_698;
    wire [15:0] signal_cat_201;
    wire [13:0] signal_select_699;
    wire [15:0] signal_cat_202;
    wire signal_select_700;
    wire [15:0] signal_mux_277;
    wire signal_select_701;
    wire [15:0] signal_mux_278;
    wire signal_select_702;
    wire [15:0] signal_mux_279;
    wire signal_select_703;
    wire [15:0] signal_mux_280;
    wire [4:0] d$shift_count;
    wire signal_select_704;
    wire [15:0] signal_mux_281;
    wire [15:0] signal_not_60;
    wire [27:0] signal_cat_203;
    wire signal_select_705;
    wire [27:0] signal_mux_282;
    wire signal_select_706;
    wire [27:0] signal_mux_283;
    wire signal_select_707;
    wire [27:0] signal_mux_284;
    wire signal_select_708;
    wire [27:0] signal_mux_285;
    wire [4:0] signal_wire_37;
    wire signal_select_709;
    wire [27:0] signal_mux_286;
    wire [27:0] signal_and_137;
    wire [27:0] signal_not_61;
    wire [27:0] signal_and_138;
    wire [27:0] signal_or_17;
    wire [2:0] d$out_dest$binary_variant;
    wire [2:0] d$in_source$binary_variant;
    wire signal_eq_71;
    wire [27:0] signal_mux_287;
    wire [15:0] signal_select_710;
    wire [11:0] signal_select_711;
    wire [27:0] signal_cat_204;
    wire [7:0] signal_select_712;
    wire [19:0] signal_select_713;
    wire [27:0] signal_cat_205;
    wire [3:0] signal_select_714;
    wire [23:0] signal_select_715;
    wire [27:0] signal_cat_206;
    wire [1:0] signal_select_716;
    wire [25:0] signal_select_717;
    wire [27:0] signal_cat_207;
    wire signal_select_718;
    wire [26:0] signal_select_719;
    wire [27:0] signal_cat_208;
    wire [1:0] signal_select_720;
    wire [1:0] signal_select_721;
    wire [4:0] signal_select_722;
    wire signal_select_723;
    wire [1:0] signal_cat_209;
    reg [1:0] d$side_set;
    wire [15:0] signal_cat_210;
    wire [27:0] signal_cat_211;
    wire signal_select_724;
    wire [27:0] signal_mux_288;
    wire signal_select_725;
    wire [27:0] signal_mux_289;
    wire signal_select_726;
    wire [27:0] signal_mux_290;
    wire signal_select_727;
    wire [27:0] signal_mux_291;
    wire signal_select_728;
    wire [27:0] signal_mux_292;
    wire [27:0] signal_and_139;
    wire [15:0] signal_select_729;
    wire [11:0] signal_select_730;
    wire [27:0] signal_cat_212;
    wire [7:0] signal_select_731;
    wire [19:0] signal_select_732;
    wire [27:0] signal_cat_213;
    wire [3:0] signal_select_733;
    wire [23:0] signal_select_734;
    wire [27:0] signal_cat_214;
    wire [1:0] signal_select_735;
    wire [25:0] signal_select_736;
    wire [27:0] signal_cat_215;
    wire signal_select_737;
    wire [26:0] signal_select_738;
    wire [27:0] signal_cat_216;
    wire [7:0] signal_select_739;
    wire [15:0] signal_cat_217;
    wire [11:0] signal_select_740;
    wire [15:0] signal_cat_218;
    wire [13:0] signal_select_741;
    wire [15:0] signal_cat_219;
    wire signal_select_742;
    wire [15:0] signal_mux_293;
    wire signal_select_743;
    wire [15:0] signal_mux_294;
    wire signal_select_744;
    wire [15:0] signal_mux_295;
    wire signal_select_745;
    wire [15:0] signal_mux_296;
    wire [1:0] signal_wire_38;
    wire [4:0] signal_cat_220;
    wire signal_select_746;
    wire [15:0] signal_mux_297;
    wire [15:0] signal_not_62;
    wire [27:0] signal_cat_221;
    wire signal_select_747;
    wire [27:0] signal_mux_298;
    wire signal_select_748;
    wire [27:0] signal_mux_299;
    wire signal_select_749;
    wire [27:0] signal_mux_300;
    wire signal_select_750;
    wire [27:0] signal_mux_301;
    wire [4:0] signal_wire_39;
    wire signal_select_751;
    wire [27:0] signal_mux_302;
    wire [27:0] signal_and_140;
    wire [27:0] signal_not_63;
    wire [27:0] signal_and_141;
    wire [27:0] pin_dir_side;
    wire signal_wire_40;
    wire [27:0] pin_dir_base;
    wire [2:0] d$opcode$binary_variant;
    reg [27:0] pin_dir_next;
    reg [27:0] signal_reg_27;
    wire [27:0] pin_dir_0;
    wire signal_select_752;
    wire signal_mux_303;
    wire signal_select_753;
    wire signal_select_754;
    wire signal_or_18;
    wire signal_select_755;
    wire signal_select_756;
    wire signal_or_19;
    wire signal_select_757;
    wire signal_select_758;
    wire signal_or_20;
    wire signal_select_759;
    wire signal_select_760;
    wire signal_or_21;
    wire signal_select_761;
    wire signal_select_762;
    wire signal_or_22;
    wire signal_select_763;
    wire signal_select_764;
    wire signal_or_23;
    wire signal_select_765;
    wire signal_select_766;
    wire signal_or_24;
    wire [27:0] signal_wire_41;
    wire signal_select_767;
    wire signal_select_768;
    wire signal_or_25;
    wire [27:0] sample;
    wire [27:0] signal_and_142;
    wire signal_eq_72;
    wire wait_pin_cur;
    wire signal_eq_73;
    reg [15:0] word;
    wire [1:0] d$wait_source$binary_variant;
    reg wait_ready;
    wire signal_not_64;
    wire signal_or_26;
    wire signal_or_27;
    reg refill;
    wire signal_or_28;
    wire ir_load;
    wire gnd;
    wire signal_eq_74;
    reg is_opcode$1;
    wire wait_holds;
    wire signal_not_65;
    wire advance;
    wire [8:0] signal_mux_304;
    wire [8:0] pc_after_next;
    wire [8:0] signal_mux_305;
    wire [8:0] signal_mux_306;
    wire [8:0] signal_mux_307;
    wire [8:0] fetch_addr;
    wire [8:0] signal_mux_308;
    wire signal_wire_42;
    wire program_write;
    wire vdd;
    wire [15:0] signal_inst_2;
    wire [15:0] signal_wire_43;
    wire [2:0] signal_select_769;
    wire signal_eq_75;
    reg is_opcode$0;
    wire jmp_go;
    wire [8:0] signal_mux_309;
    wire [8:0] pc_value_next;
    wire signal_eq_76;
    reg signal_reg_28;
    wire at_break;
    wire signal_wire_44;
    wire signal_and_143;
    wire signal_and_144;
    wire breaks;
    wire signal_mux_310;
    wire signal_wire_45;
    wire signal_mux_311;
    wire signal_not_66;
    wire signal_wire_46;
    wire signal_wire_47;
    wire signal_or_29;
    wire signal_and_145;
    wire resume_asked;
    reg signal_reg_29;
    wire resume_0;
    wire signal_mux_312;
    wire signal_wire_48;
    wire signal_wire_49;
    wire signal_wire_50;
    reg start_0;
    wire halted_next;
    reg signal_reg_30;
    wire halted_0;
    wire signal_not_67;
    wire signal_and_146;
    wire ready;
    wire issue;
    wire go;
    wire op_go;
    wire [27:0] signal_mux_313;
    reg [27:0] signal_reg_31;
    wire [27:0] pin_out_0;
    assign signal_const = 3'b100;
    assign signal_eq = signal_select_769 == signal_const;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            is_opcode$4 <= gnd;
        else
            if (ir_load)
                is_opcode$4 <= signal_eq;
    end
    assign signal_const_1 = 3'b101;
    assign signal_eq_1 = signal_select_769 == signal_const_1;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            is_opcode$5 <= gnd;
        else
            if (ir_load)
                is_opcode$5 <= signal_eq_1;
    end
    assign signal_const_2 = 3'b110;
    assign signal_eq_2 = signal_select_769 == signal_const_2;
    always @(posedge signal_wire_49) begin
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
    assign signal_select_2 = signal_inst_1[19:16];
    assign signal_not = ~ decode_ok_0;
    assign signal_and = issue & signal_not;
    assign signal_const_3 = 1'b0;
    always @(posedge signal_wire_49) begin
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
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_1 <= signal_const_3;
        else
            if (signal_and_2)
                signal_reg_1 <= vdd;
    end
    assign signal_and_3 = op_go & pushes;
    assign signal_and_4 = signal_and_3 & signal_select_281;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_2 <= signal_const_3;
        else
            if (signal_and_4)
                signal_reg_2 <= vdd;
    end
    assign signal_and_5 = pulls & signal_select_675;
    assign signal_and_6 = pull_data & data_moved;
    assign signal_and_7 = pull_fifo & signal_select_675;
    assign signal_or = signal_and_7 | signal_and_6;
    assign signal_and_8 = is_opcode$3 & signal_or;
    assign signal_or_1 = signal_and_8 | signal_and_5;
    assign signal_and_9 = op_go & signal_or_1;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_3 <= signal_const_3;
        else
            if (signal_and_9)
                signal_reg_3 <= vdd;
    end
    assign signal_wire = clear_irq;
    assign signal_mux = signal_wire ? gnd : irq_0;
    assign signal_const_9 = 4'b0010;
    assign signal_eq_4 = d$sys_op$binary_variant == signal_const_9;
    assign signal_and_10 = is_opcode$7 & signal_eq_4;
    assign signal_and_11 = op_go & signal_and_10;
    assign signal_mux_1 = signal_and_11 ? vdd : signal_mux;
    assign signal_wire_1 = signal_mux_1;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            irq_0 <= signal_const_3;
        else
            irq_0 <= signal_wire_1;
    end
    assign signal_const_10 = 9'b000000000;
    assign signal_select_4 = x_0[8:0];
    assign signal_const_12 = 9'b000000001;
    assign signal_add = data_ptr_0 + signal_const_12;
    assign signal_mux_2 = pulls_data ? signal_add : data_ptr_0;
    assign signal_mux_3 = seeks ? signal_select_4 : signal_mux_2;
    assign signal_or_2 = signal_wire_50 | start_0;
    assign signal_mux_4 = signal_or_2 ? signal_const_10 : signal_mux_3;
    assign data_ptr_next = signal_mux_4;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_4 <= signal_const_10;
        else
            signal_reg_4 <= data_ptr_next;
    end
    assign data_ptr_0 = signal_reg_4;
    assign signal_and_12 = issue & flip_pending_0;
    assign signal_or_3 = op_go | signal_and_12;
    assign signal_const_13 = 28'b0000000000000000000000000000;
    assign signal_select_5 = signal_mux_8[27:12];
    assign signal_select_6 = signal_mux_8[11:0];
    assign signal_cat_1 = { signal_select_6,
                            signal_select_5 };
    assign signal_select_7 = signal_mux_7[27:20];
    assign signal_select_8 = signal_mux_7[19:0];
    assign signal_cat_2 = { signal_select_8,
                            signal_select_7 };
    assign signal_select_9 = signal_mux_6[27:24];
    assign signal_select_10 = signal_mux_6[23:0];
    assign signal_cat_3 = { signal_select_10,
                            signal_select_9 };
    assign signal_select_11 = signal_mux_5[27:26];
    assign signal_select_12 = signal_mux_5[25:0];
    assign signal_cat_4 = { signal_select_12,
                            signal_select_11 };
    assign signal_select_13 = signal_cat_7[27:27];
    assign signal_select_14 = signal_cat_7[26:0];
    assign signal_cat_5 = { signal_select_14,
                            signal_select_13 };
    assign signal_const_14 = 11'b00000000000;
    assign signal_cat_6 = { signal_const_14,
                            d$set_value };
    assign signal_const_15 = 12'b000000000000;
    assign signal_cat_7 = { signal_const_15,
                            signal_cat_6 };
    assign signal_select_15 = signal_wire_16[0:0];
    assign signal_mux_5 = signal_select_15 ? signal_cat_5 : signal_cat_7;
    assign signal_select_16 = signal_wire_16[1:1];
    assign signal_mux_6 = signal_select_16 ? signal_cat_4 : signal_mux_5;
    assign signal_select_17 = signal_wire_16[2:2];
    assign signal_mux_7 = signal_select_17 ? signal_cat_3 : signal_mux_6;
    assign signal_select_18 = signal_wire_16[3:3];
    assign signal_mux_8 = signal_select_18 ? signal_cat_2 : signal_mux_7;
    assign signal_select_19 = signal_wire_16[4:4];
    assign signal_mux_9 = signal_select_19 ? signal_cat_1 : signal_mux_8;
    assign signal_and_13 = signal_mux_9 & signal_and_14;
    assign signal_const_16 = 28'b1111111111111111111111100000;
    assign signal_select_20 = signal_mux_18[27:12];
    assign signal_select_21 = signal_mux_18[11:0];
    assign signal_cat_8 = { signal_select_21,
                            signal_select_20 };
    assign signal_select_22 = signal_mux_17[27:20];
    assign signal_select_23 = signal_mux_17[19:0];
    assign signal_cat_9 = { signal_select_23,
                            signal_select_22 };
    assign signal_select_24 = signal_mux_16[27:24];
    assign signal_select_25 = signal_mux_16[23:0];
    assign signal_cat_10 = { signal_select_25,
                             signal_select_24 };
    assign signal_select_26 = signal_mux_15[27:26];
    assign signal_select_27 = signal_mux_15[25:0];
    assign signal_cat_11 = { signal_select_27,
                             signal_select_26 };
    assign signal_select_28 = signal_cat_16[27:27];
    assign signal_select_29 = signal_cat_16[26:0];
    assign signal_cat_12 = { signal_select_29,
                             signal_select_28 };
    assign signal_const_17 = 16'b0000000000000000;
    assign signal_const_18 = 8'b00000000;
    assign signal_select_30 = signal_mux_12[7:0];
    assign signal_cat_13 = { signal_select_30,
                             signal_const_18 };
    assign signal_const_19 = 4'b0000;
    assign signal_select_31 = signal_mux_11[11:0];
    assign signal_cat_14 = { signal_select_31,
                             signal_const_19 };
    assign signal_const_20 = 2'b00;
    assign signal_select_32 = signal_mux_10[13:0];
    assign signal_cat_15 = { signal_select_32,
                             signal_const_20 };
    assign signal_const_21 = 16'b1111111111111110;
    assign signal_const_22 = 16'b1111111111111111;
    assign signal_select_33 = signal_cat_110[0:0];
    assign signal_mux_10 = signal_select_33 ? signal_const_21 : signal_const_22;
    assign signal_select_34 = signal_cat_110[1:1];
    assign signal_mux_11 = signal_select_34 ? signal_cat_15 : signal_mux_10;
    assign signal_select_35 = signal_cat_110[2:2];
    assign signal_mux_12 = signal_select_35 ? signal_cat_14 : signal_mux_11;
    assign signal_select_36 = signal_cat_110[3:3];
    assign signal_mux_13 = signal_select_36 ? signal_cat_13 : signal_mux_12;
    assign signal_select_37 = signal_cat_110[4:4];
    assign signal_mux_14 = signal_select_37 ? signal_const_17 : signal_mux_13;
    assign signal_not_3 = ~ signal_mux_14;
    assign signal_cat_16 = { signal_const_15,
                             signal_not_3 };
    assign signal_select_38 = signal_wire_16[0:0];
    assign signal_mux_15 = signal_select_38 ? signal_cat_12 : signal_cat_16;
    assign signal_select_39 = signal_wire_16[1:1];
    assign signal_mux_16 = signal_select_39 ? signal_cat_11 : signal_mux_15;
    assign signal_select_40 = signal_wire_16[2:2];
    assign signal_mux_17 = signal_select_40 ? signal_cat_10 : signal_mux_16;
    assign signal_select_41 = signal_wire_16[3:3];
    assign signal_mux_18 = signal_select_41 ? signal_cat_9 : signal_mux_17;
    assign signal_select_42 = signal_wire_16[4:4];
    assign signal_mux_19 = signal_select_42 ? signal_cat_8 : signal_mux_18;
    assign signal_and_14 = signal_mux_19 & signal_const_16;
    assign signal_not_4 = ~ signal_and_14;
    assign signal_and_15 = pin_out_base & signal_not_4;
    assign signal_or_4 = signal_and_15 | signal_and_13;
    assign signal_const_24 = 3'b000;
    assign signal_eq_5 = d$set_dest$binary_variant == signal_const_24;
    assign signal_mux_20 = signal_eq_5 ? signal_or_4 : pin_out_base;
    assign signal_select_43 = signal_mux_24[27:12];
    assign signal_select_44 = signal_mux_24[11:0];
    assign signal_cat_17 = { signal_select_44,
                             signal_select_43 };
    assign signal_select_45 = signal_mux_23[27:20];
    assign signal_select_46 = signal_mux_23[19:0];
    assign signal_cat_18 = { signal_select_46,
                             signal_select_45 };
    assign signal_select_47 = signal_mux_22[27:24];
    assign signal_select_48 = signal_mux_22[23:0];
    assign signal_cat_19 = { signal_select_48,
                             signal_select_47 };
    assign signal_select_49 = signal_mux_21[27:26];
    assign signal_select_50 = signal_mux_21[25:0];
    assign signal_cat_20 = { signal_select_50,
                             signal_select_49 };
    assign signal_select_51 = signal_cat_22[27:27];
    assign signal_select_52 = signal_cat_22[26:0];
    assign signal_cat_21 = { signal_select_52,
                             signal_select_51 };
    assign signal_cat_22 = { signal_const_15,
                             mov_value };
    assign signal_select_53 = signal_wire_37[0:0];
    assign signal_mux_21 = signal_select_53 ? signal_cat_21 : signal_cat_22;
    assign signal_select_54 = signal_wire_37[1:1];
    assign signal_mux_22 = signal_select_54 ? signal_cat_20 : signal_mux_21;
    assign signal_select_55 = signal_wire_37[2:2];
    assign signal_mux_23 = signal_select_55 ? signal_cat_19 : signal_mux_22;
    assign signal_select_56 = signal_wire_37[3:3];
    assign signal_mux_24 = signal_select_56 ? signal_cat_18 : signal_mux_23;
    assign signal_select_57 = signal_wire_37[4:4];
    assign signal_mux_25 = signal_select_57 ? signal_cat_17 : signal_mux_24;
    assign signal_and_16 = signal_mux_25 & signal_and_17;
    assign signal_select_58 = signal_mux_34[27:12];
    assign signal_select_59 = signal_mux_34[11:0];
    assign signal_cat_23 = { signal_select_59,
                             signal_select_58 };
    assign signal_select_60 = signal_mux_33[27:20];
    assign signal_select_61 = signal_mux_33[19:0];
    assign signal_cat_24 = { signal_select_61,
                             signal_select_60 };
    assign signal_select_62 = signal_mux_32[27:24];
    assign signal_select_63 = signal_mux_32[23:0];
    assign signal_cat_25 = { signal_select_63,
                             signal_select_62 };
    assign signal_select_64 = signal_mux_31[27:26];
    assign signal_select_65 = signal_mux_31[25:0];
    assign signal_cat_26 = { signal_select_65,
                             signal_select_64 };
    assign signal_select_66 = signal_cat_31[27:27];
    assign signal_select_67 = signal_cat_31[26:0];
    assign signal_cat_27 = { signal_select_67,
                             signal_select_66 };
    assign signal_select_68 = signal_mux_28[7:0];
    assign signal_cat_28 = { signal_select_68,
                             signal_const_18 };
    assign signal_select_69 = signal_mux_27[11:0];
    assign signal_cat_29 = { signal_select_69,
                             signal_const_19 };
    assign signal_select_70 = signal_mux_26[13:0];
    assign signal_cat_30 = { signal_select_70,
                             signal_const_20 };
    assign signal_select_71 = signal_wire_17[0:0];
    assign signal_mux_26 = signal_select_71 ? signal_const_21 : signal_const_22;
    assign signal_select_72 = signal_wire_17[1:1];
    assign signal_mux_27 = signal_select_72 ? signal_cat_30 : signal_mux_26;
    assign signal_select_73 = signal_wire_17[2:2];
    assign signal_mux_28 = signal_select_73 ? signal_cat_29 : signal_mux_27;
    assign signal_select_74 = signal_wire_17[3:3];
    assign signal_mux_29 = signal_select_74 ? signal_cat_28 : signal_mux_28;
    assign signal_select_75 = signal_wire_17[4:4];
    assign signal_mux_30 = signal_select_75 ? signal_const_17 : signal_mux_29;
    assign signal_not_5 = ~ signal_mux_30;
    assign signal_cat_31 = { signal_const_15,
                             signal_not_5 };
    assign signal_select_76 = signal_wire_37[0:0];
    assign signal_mux_31 = signal_select_76 ? signal_cat_27 : signal_cat_31;
    assign signal_select_77 = signal_wire_37[1:1];
    assign signal_mux_32 = signal_select_77 ? signal_cat_26 : signal_mux_31;
    assign signal_select_78 = signal_wire_37[2:2];
    assign signal_mux_33 = signal_select_78 ? signal_cat_25 : signal_mux_32;
    assign signal_select_79 = signal_wire_37[3:3];
    assign signal_mux_34 = signal_select_79 ? signal_cat_24 : signal_mux_33;
    assign signal_select_80 = signal_wire_37[4:4];
    assign signal_mux_35 = signal_select_80 ? signal_cat_23 : signal_mux_34;
    assign signal_and_17 = signal_mux_35 & signal_const_16;
    assign signal_not_6 = ~ signal_and_17;
    assign signal_and_18 = pin_out_base & signal_not_6;
    assign signal_or_5 = signal_and_18 | signal_and_16;
    assign signal_eq_6 = d$mov_dest$binary_variant == signal_const_24;
    assign signal_mux_36 = signal_eq_6 ? signal_or_5 : pin_out_base;
    assign signal_select_81 = signal_mux_40[27:12];
    assign signal_select_82 = signal_mux_40[11:0];
    assign signal_cat_32 = { signal_select_82,
                             signal_select_81 };
    assign signal_select_83 = signal_mux_39[27:20];
    assign signal_select_84 = signal_mux_39[19:0];
    assign signal_cat_33 = { signal_select_84,
                             signal_select_83 };
    assign signal_select_85 = signal_mux_38[27:24];
    assign signal_select_86 = signal_mux_38[23:0];
    assign signal_cat_34 = { signal_select_86,
                             signal_select_85 };
    assign signal_select_87 = signal_mux_37[27:26];
    assign signal_select_88 = signal_mux_37[25:0];
    assign signal_cat_35 = { signal_select_88,
                             signal_select_87 };
    assign signal_select_89 = signal_cat_39[27:27];
    assign signal_select_90 = signal_cat_39[26:0];
    assign signal_cat_36 = { signal_select_90,
                             signal_select_89 };
    assign signal_not_7 = ~ signal_select_91;
    assign signal_select_91 = out_value[0:0];
    assign signal_cat_37 = { signal_select_91,
                             signal_not_7 };
    assign signal_const_35 = 14'b00000000000000;
    assign signal_cat_38 = { signal_const_35,
                             signal_cat_37 };
    assign signal_cat_39 = { signal_const_15,
                             signal_cat_38 };
    assign signal_select_92 = signal_wire_37[0:0];
    assign signal_mux_37 = signal_select_92 ? signal_cat_36 : signal_cat_39;
    assign signal_select_93 = signal_wire_37[1:1];
    assign signal_mux_38 = signal_select_93 ? signal_cat_35 : signal_mux_37;
    assign signal_select_94 = signal_wire_37[2:2];
    assign signal_mux_39 = signal_select_94 ? signal_cat_34 : signal_mux_38;
    assign signal_select_95 = signal_wire_37[3:3];
    assign signal_mux_40 = signal_select_95 ? signal_cat_33 : signal_mux_39;
    assign signal_select_96 = signal_wire_37[4:4];
    assign signal_mux_41 = signal_select_96 ? signal_cat_32 : signal_mux_40;
    assign signal_and_19 = signal_mux_41 & signal_and_20;
    assign signal_select_97 = signal_mux_45[27:12];
    assign signal_select_98 = signal_mux_45[11:0];
    assign signal_cat_40 = { signal_select_98,
                             signal_select_97 };
    assign signal_select_99 = signal_mux_44[27:20];
    assign signal_select_100 = signal_mux_44[19:0];
    assign signal_cat_41 = { signal_select_100,
                             signal_select_99 };
    assign signal_select_101 = signal_mux_43[27:24];
    assign signal_select_102 = signal_mux_43[23:0];
    assign signal_cat_42 = { signal_select_102,
                             signal_select_101 };
    assign signal_select_103 = signal_mux_42[27:26];
    assign signal_select_104 = signal_mux_42[25:0];
    assign signal_cat_43 = { signal_select_104,
                             signal_select_103 };
    assign signal_const_38 = 28'b0000000000000000000000000110;
    assign signal_const_39 = 28'b0000000000000000000000000011;
    assign signal_select_105 = signal_wire_37[0:0];
    assign signal_mux_42 = signal_select_105 ? signal_const_38 : signal_const_39;
    assign signal_select_106 = signal_wire_37[1:1];
    assign signal_mux_43 = signal_select_106 ? signal_cat_43 : signal_mux_42;
    assign signal_select_107 = signal_wire_37[2:2];
    assign signal_mux_44 = signal_select_107 ? signal_cat_42 : signal_mux_43;
    assign signal_select_108 = signal_wire_37[3:3];
    assign signal_mux_45 = signal_select_108 ? signal_cat_41 : signal_mux_44;
    assign signal_select_109 = signal_wire_37[4:4];
    assign signal_mux_46 = signal_select_109 ? signal_cat_40 : signal_mux_45;
    assign signal_and_20 = signal_mux_46 & signal_const_16;
    assign signal_not_8 = ~ signal_and_20;
    assign signal_and_21 = pin_out_base & signal_not_8;
    assign signal_or_6 = signal_and_21 | signal_and_19;
    assign signal_select_110 = signal_mux_50[27:12];
    assign signal_select_111 = signal_mux_50[11:0];
    assign signal_cat_44 = { signal_select_111,
                             signal_select_110 };
    assign signal_select_112 = signal_mux_49[27:20];
    assign signal_select_113 = signal_mux_49[19:0];
    assign signal_cat_45 = { signal_select_113,
                             signal_select_112 };
    assign signal_select_114 = signal_mux_48[27:24];
    assign signal_select_115 = signal_mux_48[23:0];
    assign signal_cat_46 = { signal_select_115,
                             signal_select_114 };
    assign signal_select_116 = signal_mux_47[27:26];
    assign signal_select_117 = signal_mux_47[25:0];
    assign signal_cat_47 = { signal_select_117,
                             signal_select_116 };
    assign signal_select_118 = signal_cat_49[27:27];
    assign signal_select_119 = signal_cat_49[26:0];
    assign signal_cat_48 = { signal_select_119,
                             signal_select_118 };
    assign signal_cat_49 = { signal_const_15,
                             out_value };
    assign signal_select_120 = signal_wire_37[0:0];
    assign signal_mux_47 = signal_select_120 ? signal_cat_48 : signal_cat_49;
    assign signal_select_121 = signal_wire_37[1:1];
    assign signal_mux_48 = signal_select_121 ? signal_cat_47 : signal_mux_47;
    assign signal_select_122 = signal_wire_37[2:2];
    assign signal_mux_49 = signal_select_122 ? signal_cat_46 : signal_mux_48;
    assign signal_select_123 = signal_wire_37[3:3];
    assign signal_mux_50 = signal_select_123 ? signal_cat_45 : signal_mux_49;
    assign signal_select_124 = signal_wire_37[4:4];
    assign signal_mux_51 = signal_select_124 ? signal_cat_44 : signal_mux_50;
    assign signal_and_22 = signal_mux_51 & signal_and_23;
    assign signal_select_125 = signal_mux_60[27:12];
    assign signal_select_126 = signal_mux_60[11:0];
    assign signal_cat_50 = { signal_select_126,
                             signal_select_125 };
    assign signal_select_127 = signal_mux_59[27:20];
    assign signal_select_128 = signal_mux_59[19:0];
    assign signal_cat_51 = { signal_select_128,
                             signal_select_127 };
    assign signal_select_129 = signal_mux_58[27:24];
    assign signal_select_130 = signal_mux_58[23:0];
    assign signal_cat_52 = { signal_select_130,
                             signal_select_129 };
    assign signal_select_131 = signal_mux_57[27:26];
    assign signal_select_132 = signal_mux_57[25:0];
    assign signal_cat_53 = { signal_select_132,
                             signal_select_131 };
    assign signal_select_133 = signal_cat_58[27:27];
    assign signal_select_134 = signal_cat_58[26:0];
    assign signal_cat_54 = { signal_select_134,
                             signal_select_133 };
    assign signal_select_135 = signal_mux_54[7:0];
    assign signal_cat_55 = { signal_select_135,
                             signal_const_18 };
    assign signal_select_136 = signal_mux_53[11:0];
    assign signal_cat_56 = { signal_select_136,
                             signal_const_19 };
    assign signal_select_137 = signal_mux_52[13:0];
    assign signal_cat_57 = { signal_select_137,
                             signal_const_20 };
    assign signal_select_138 = d$shift_count[0:0];
    assign signal_mux_52 = signal_select_138 ? signal_const_21 : signal_const_22;
    assign signal_select_139 = d$shift_count[1:1];
    assign signal_mux_53 = signal_select_139 ? signal_cat_57 : signal_mux_52;
    assign signal_select_140 = d$shift_count[2:2];
    assign signal_mux_54 = signal_select_140 ? signal_cat_56 : signal_mux_53;
    assign signal_select_141 = d$shift_count[3:3];
    assign signal_mux_55 = signal_select_141 ? signal_cat_55 : signal_mux_54;
    assign signal_select_142 = d$shift_count[4:4];
    assign signal_mux_56 = signal_select_142 ? signal_const_17 : signal_mux_55;
    assign signal_not_9 = ~ signal_mux_56;
    assign signal_cat_58 = { signal_const_15,
                             signal_not_9 };
    assign signal_select_143 = signal_wire_37[0:0];
    assign signal_mux_57 = signal_select_143 ? signal_cat_54 : signal_cat_58;
    assign signal_select_144 = signal_wire_37[1:1];
    assign signal_mux_58 = signal_select_144 ? signal_cat_53 : signal_mux_57;
    assign signal_select_145 = signal_wire_37[2:2];
    assign signal_mux_59 = signal_select_145 ? signal_cat_52 : signal_mux_58;
    assign signal_select_146 = signal_wire_37[3:3];
    assign signal_mux_60 = signal_select_146 ? signal_cat_51 : signal_mux_59;
    assign signal_select_147 = signal_wire_37[4:4];
    assign signal_mux_61 = signal_select_147 ? signal_cat_50 : signal_mux_60;
    assign signal_and_23 = signal_mux_61 & signal_const_16;
    assign signal_not_10 = ~ signal_and_23;
    assign signal_and_24 = pin_out_base & signal_not_10;
    assign signal_or_7 = signal_and_24 | signal_and_22;
    assign signal_mux_62 = manchester_out ? signal_or_6 : signal_or_7;
    assign signal_eq_7 = d$out_dest$binary_variant == signal_const_24;
    assign signal_mux_63 = signal_eq_7 ? signal_mux_62 : pin_out_base;
    assign signal_select_148 = signal_mux_67[27:12];
    assign signal_select_149 = signal_mux_67[11:0];
    assign signal_cat_59 = { signal_select_149,
                             signal_select_148 };
    assign signal_select_150 = signal_mux_66[27:20];
    assign signal_select_151 = signal_mux_66[19:0];
    assign signal_cat_60 = { signal_select_151,
                             signal_select_150 };
    assign signal_select_152 = signal_mux_65[27:24];
    assign signal_select_153 = signal_mux_65[23:0];
    assign signal_cat_61 = { signal_select_153,
                             signal_select_152 };
    assign signal_select_154 = signal_mux_64[27:26];
    assign signal_select_155 = signal_mux_64[25:0];
    assign signal_cat_62 = { signal_select_155,
                             signal_select_154 };
    assign signal_select_156 = signal_cat_65[27:27];
    assign signal_select_157 = signal_cat_65[26:0];
    assign signal_cat_63 = { signal_select_157,
                             signal_select_156 };
    assign signal_cat_64 = { signal_const_35,
                             d$side_set };
    assign signal_cat_65 = { signal_const_15,
                             signal_cat_64 };
    assign signal_select_158 = signal_wire_39[0:0];
    assign signal_mux_64 = signal_select_158 ? signal_cat_63 : signal_cat_65;
    assign signal_select_159 = signal_wire_39[1:1];
    assign signal_mux_65 = signal_select_159 ? signal_cat_62 : signal_mux_64;
    assign signal_select_160 = signal_wire_39[2:2];
    assign signal_mux_66 = signal_select_160 ? signal_cat_61 : signal_mux_65;
    assign signal_select_161 = signal_wire_39[3:3];
    assign signal_mux_67 = signal_select_161 ? signal_cat_60 : signal_mux_66;
    assign signal_select_162 = signal_wire_39[4:4];
    assign signal_mux_68 = signal_select_162 ? signal_cat_59 : signal_mux_67;
    assign signal_and_25 = signal_mux_68 & signal_and_26;
    assign signal_select_163 = signal_mux_77[27:12];
    assign signal_select_164 = signal_mux_77[11:0];
    assign signal_cat_66 = { signal_select_164,
                             signal_select_163 };
    assign signal_select_165 = signal_mux_76[27:20];
    assign signal_select_166 = signal_mux_76[19:0];
    assign signal_cat_67 = { signal_select_166,
                             signal_select_165 };
    assign signal_select_167 = signal_mux_75[27:24];
    assign signal_select_168 = signal_mux_75[23:0];
    assign signal_cat_68 = { signal_select_168,
                             signal_select_167 };
    assign signal_select_169 = signal_mux_74[27:26];
    assign signal_select_170 = signal_mux_74[25:0];
    assign signal_cat_69 = { signal_select_170,
                             signal_select_169 };
    assign signal_select_171 = signal_cat_74[27:27];
    assign signal_select_172 = signal_cat_74[26:0];
    assign signal_cat_70 = { signal_select_172,
                             signal_select_171 };
    assign signal_select_173 = signal_mux_71[7:0];
    assign signal_cat_71 = { signal_select_173,
                             signal_const_18 };
    assign signal_select_174 = signal_mux_70[11:0];
    assign signal_cat_72 = { signal_select_174,
                             signal_const_19 };
    assign signal_select_175 = signal_mux_69[13:0];
    assign signal_cat_73 = { signal_select_175,
                             signal_const_20 };
    assign signal_select_176 = signal_cat_220[0:0];
    assign signal_mux_69 = signal_select_176 ? signal_const_21 : signal_const_22;
    assign signal_select_177 = signal_cat_220[1:1];
    assign signal_mux_70 = signal_select_177 ? signal_cat_73 : signal_mux_69;
    assign signal_select_178 = signal_cat_220[2:2];
    assign signal_mux_71 = signal_select_178 ? signal_cat_72 : signal_mux_70;
    assign signal_select_179 = signal_cat_220[3:3];
    assign signal_mux_72 = signal_select_179 ? signal_cat_71 : signal_mux_71;
    assign signal_select_180 = signal_cat_220[4:4];
    assign signal_mux_73 = signal_select_180 ? signal_const_17 : signal_mux_72;
    assign signal_not_11 = ~ signal_mux_73;
    assign signal_cat_74 = { signal_const_15,
                             signal_not_11 };
    assign signal_select_181 = signal_wire_39[0:0];
    assign signal_mux_74 = signal_select_181 ? signal_cat_70 : signal_cat_74;
    assign signal_select_182 = signal_wire_39[1:1];
    assign signal_mux_75 = signal_select_182 ? signal_cat_69 : signal_mux_74;
    assign signal_select_183 = signal_wire_39[2:2];
    assign signal_mux_76 = signal_select_183 ? signal_cat_68 : signal_mux_75;
    assign signal_select_184 = signal_wire_39[3:3];
    assign signal_mux_77 = signal_select_184 ? signal_cat_67 : signal_mux_76;
    assign signal_select_185 = signal_wire_39[4:4];
    assign signal_mux_78 = signal_select_185 ? signal_cat_66 : signal_mux_77;
    assign signal_and_26 = signal_mux_78 & signal_const_16;
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
    assign signal_select_186 = signal_mux_82[27:12];
    assign signal_select_187 = signal_mux_82[11:0];
    assign signal_cat_75 = { signal_select_187,
                             signal_select_186 };
    assign signal_select_188 = signal_mux_81[27:20];
    assign signal_select_189 = signal_mux_81[19:0];
    assign signal_cat_76 = { signal_select_189,
                             signal_select_188 };
    assign signal_select_190 = signal_mux_80[27:24];
    assign signal_select_191 = signal_mux_80[23:0];
    assign signal_cat_77 = { signal_select_191,
                             signal_select_190 };
    assign signal_select_192 = signal_mux_79[27:26];
    assign signal_select_193 = signal_mux_79[25:0];
    assign signal_cat_78 = { signal_select_193,
                             signal_select_192 };
    assign signal_select_194 = signal_cat_82[27:27];
    assign signal_select_195 = signal_cat_82[26:0];
    assign signal_cat_79 = { signal_select_195,
                             signal_select_194 };
    assign signal_not_13 = ~ signal_not_14;
    assign signal_select_196 = out_value[0:0];
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_5 <= signal_const_3;
        else
            if (starts_manchester_bit)
                signal_reg_5 <= signal_select_196;
    end
    assign flip_bit_0 = signal_reg_5;
    assign signal_not_14 = ~ flip_bit_0;
    assign signal_cat_80 = { signal_not_14,
                             signal_not_13 };
    assign signal_cat_81 = { signal_const_35,
                             signal_cat_80 };
    assign signal_cat_82 = { signal_const_15,
                             signal_cat_81 };
    assign signal_select_197 = signal_wire_37[0:0];
    assign signal_mux_79 = signal_select_197 ? signal_cat_79 : signal_cat_82;
    assign signal_select_198 = signal_wire_37[1:1];
    assign signal_mux_80 = signal_select_198 ? signal_cat_78 : signal_mux_79;
    assign signal_select_199 = signal_wire_37[2:2];
    assign signal_mux_81 = signal_select_199 ? signal_cat_77 : signal_mux_80;
    assign signal_select_200 = signal_wire_37[3:3];
    assign signal_mux_82 = signal_select_200 ? signal_cat_76 : signal_mux_81;
    assign signal_select_201 = signal_wire_37[4:4];
    assign signal_mux_83 = signal_select_201 ? signal_cat_75 : signal_mux_82;
    assign signal_and_28 = signal_mux_83 & signal_and_29;
    assign signal_select_202 = signal_mux_87[27:12];
    assign signal_select_203 = signal_mux_87[11:0];
    assign signal_cat_83 = { signal_select_203,
                             signal_select_202 };
    assign signal_select_204 = signal_mux_86[27:20];
    assign signal_select_205 = signal_mux_86[19:0];
    assign signal_cat_84 = { signal_select_205,
                             signal_select_204 };
    assign signal_select_206 = signal_mux_85[27:24];
    assign signal_select_207 = signal_mux_85[23:0];
    assign signal_cat_85 = { signal_select_207,
                             signal_select_206 };
    assign signal_select_208 = signal_mux_84[27:26];
    assign signal_select_209 = signal_mux_84[25:0];
    assign signal_cat_86 = { signal_select_209,
                             signal_select_208 };
    assign signal_select_210 = signal_wire_37[0:0];
    assign signal_mux_84 = signal_select_210 ? signal_const_38 : signal_const_39;
    assign signal_select_211 = signal_wire_37[1:1];
    assign signal_mux_85 = signal_select_211 ? signal_cat_86 : signal_mux_84;
    assign signal_select_212 = signal_wire_37[2:2];
    assign signal_mux_86 = signal_select_212 ? signal_cat_85 : signal_mux_85;
    assign signal_select_213 = signal_wire_37[3:3];
    assign signal_mux_87 = signal_select_213 ? signal_cat_84 : signal_mux_86;
    assign signal_select_214 = signal_wire_37[4:4];
    assign signal_mux_88 = signal_select_214 ? signal_cat_83 : signal_mux_87;
    assign signal_and_29 = signal_mux_88 & signal_const_16;
    assign signal_not_15 = ~ signal_and_29;
    assign signal_and_30 = pin_out_0 & signal_not_15;
    assign signal_or_8 = signal_and_30 | signal_and_28;
    assign signal_mux_89 = issue ? gnd : flip_pending_0;
    assign signal_const_67 = 5'b00001;
    assign signal_eq_8 = d$shift_count == signal_const_67;
    assign signal_wire_2 = config$manchester;
    assign manchester_out = signal_wire_2 & signal_eq_8;
    assign signal_eq_9 = d$out_dest$binary_variant == signal_const_24;
    assign signal_and_31 = op_go & is_opcode$3;
    assign signal_and_32 = signal_and_31 & signal_eq_9;
    assign starts_manchester_bit = signal_and_32 & manchester_out;
    assign signal_mux_90 = starts_manchester_bit ? vdd : signal_mux_89;
    assign signal_mux_91 = start_0 ? gnd : signal_mux_90;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_6 <= signal_const_3;
        else
            signal_reg_6 <= signal_mux_91;
    end
    assign flip_pending_0 = signal_reg_6;
    assign pin_out_flipped = flip_pending_0 ? signal_or_8 : pin_out_0;
    assign signal_not_16 = ~ is_opcode$0;
    assign signal_not_17 = ~ breaks;
    assign signal_not_18 = ~ start_0;
    assign signal_const_69 = 5'b00000;
    assign signal_const_73 = 5'b00111;
    assign signal_and_33 = signal_select_722 & signal_const_73;
    assign signal_and_34 = signal_select_722 & signal_const_73;
    assign signal_const_75 = 5'b01111;
    assign signal_and_35 = signal_select_722 & signal_const_75;
    always @* begin
        case (signal_wire_38)
        0:
            d$delay <= signal_select_722;
        1:
            d$delay <= signal_and_35;
        2:
            d$delay <= signal_and_34;
        default:
            d$delay <= signal_and_33;
        endcase
    end
    assign signal_sub_2 = stall_0 - signal_const_67;
    assign signal_eq_10 = stall_0 == signal_const_69;
    assign signal_not_19 = ~ signal_eq_10;
    assign signal_mux_92 = signal_not_19 ? signal_sub_2 : stall_0;
    assign signal_mux_93 = advance ? d$delay : signal_mux_92;
    assign signal_mux_94 = jmp_go ? signal_const_67 : signal_mux_93;
    assign stall_next = start_0 ? signal_const_69 : signal_mux_94;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_7 <= signal_const_69;
        else
            signal_reg_7 <= stall_next;
    end
    assign stall_0 = signal_reg_7;
    assign signal_eq_11 = stall_0 == signal_const_69;
    assign signal_const_78 = 4'b0001;
    assign signal_eq_12 = d$sys_op$binary_variant == signal_const_78;
    assign signal_and_36 = is_opcode$7 & signal_eq_12;
    assign signal_and_37 = op_go & signal_and_36;
    assign signal_mux_95 = signal_and_37 ? vdd : halted_0;
    assign signal_not_20 = ~ resume_0;
    assign signal_and_38 = signal_wire_46 & halted_0;
    assign signal_and_39 = signal_and_38 & signal_not_20;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            step_asked <= signal_const_3;
        else
            step_asked <= signal_and_39;
    end
    assign signal_mux_96 = completes ? gnd : stepping_0;
    assign signal_mux_97 = resume_0 ? step_asked : signal_mux_96;
    assign signal_mux_98 = start_0 ? gnd : signal_mux_97;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_8 <= signal_const_3;
        else
            signal_reg_8 <= signal_mux_98;
    end
    assign stepping_0 = signal_reg_8;
    assign signal_and_40 = stepping_0 & completes;
    assign signal_mux_99 = signal_and_40 ? vdd : signal_mux_95;
    assign signal_const_81 = 4'b1001;
    assign signal_select_215 = signal_wire_43[3:0];
    assign signal_lt = signal_select_215 < signal_const_81;
    assign signal_select_216 = signal_wire_43[7:4];
    assign signal_eq_13 = signal_select_216 == signal_const_19;
    assign signal_and_41 = signal_eq_13 & signal_lt;
    assign signal_select_217 = signal_wire_43[2:0];
    assign signal_lt_1 = signal_select_217 < signal_const_1;
    assign signal_select_218 = signal_wire_43[3:3];
    assign signal_not_21 = ~ signal_select_218;
    assign signal_or_9 = signal_not_21 | signal_lt_1;
    assign signal_const_84 = 2'b11;
    assign signal_select_219 = signal_wire_43[5:4];
    assign signal_lt_2 = signal_select_219 < signal_const_84;
    assign signal_and_42 = signal_lt_2 & signal_or_9;
    assign signal_select_220 = signal_wire_43[7:5];
    assign signal_lt_3 = signal_select_220 < signal_const_1;
    assign signal_select_221 = signal_wire_43[4:3];
    assign signal_lt_4 = signal_select_221 < signal_const_84;
    assign signal_const_87 = 5'b10000;
    assign signal_lt_5 = signal_const_87 < signal_select_222;
    assign signal_not_22 = ~ signal_lt_5;
    assign signal_select_222 = signal_wire_43[4:0];
    assign signal_lt_6 = signal_select_222 < signal_const_67;
    assign signal_not_23 = ~ signal_lt_6;
    assign signal_and_43 = signal_not_23 & signal_not_22;
    assign signal_eq_14 = signal_select_313 == signal_const_69;
    assign signal_eq_15 = signal_select_313 == signal_const_69;
    assign signal_const_91 = 5'b11100;
    assign signal_lt_7 = signal_select_313 < signal_const_91;
    assign signal_lt_8 = signal_select_313 < signal_const_91;
    assign signal_select_223 = signal_wire_43[6:5];
    always @* begin
        case (signal_select_223)
        0:
            signal_mux_100 <= signal_lt_8;
        1:
            signal_mux_100 <= signal_lt_7;
        2:
            signal_mux_100 <= signal_eq_15;
        default:
            signal_mux_100 <= signal_eq_14;
        endcase
    end
    assign signal_const_93 = 4'b1100;
    assign signal_select_224 = signal_wire_43[12:9];
    assign signal_lt_9 = signal_select_224 < signal_const_93;
    always @* begin
        case (signal_select_769)
        0:
            signal_mux_101 <= signal_lt_9;
        1:
            signal_mux_101 <= signal_mux_100;
        2:
            signal_mux_101 <= signal_and_43;
        3:
            signal_mux_101 <= signal_and_43;
        4:
            signal_mux_101 <= signal_lt_4;
        5:
            signal_mux_101 <= signal_lt_3;
        6:
            signal_mux_101 <= signal_and_42;
        default:
            signal_mux_101 <= signal_and_41;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            decode_ok_0 <= vdd;
        else
            if (ir_load)
                decode_ok_0 <= signal_mux_101;
    end
    assign signal_not_24 = ~ decode_ok_0;
    assign signal_and_44 = issue & signal_not_24;
    assign signal_mux_102 = signal_and_44 ? vdd : signal_mux_99;
    assign completes = jmp_go | advance;
    assign signal_mux_103 = completes ? gnd : resumed_0;
    assign signal_mux_104 = resume_0 ? vdd : signal_mux_103;
    assign signal_mux_105 = start_0 ? gnd : signal_mux_104;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_9 <= signal_const_3;
        else
            signal_reg_9 <= signal_mux_105;
    end
    assign resumed_0 = signal_reg_9;
    assign signal_not_25 = ~ resumed_0;
    assign signal_wire_3 = config$break_pc;
    assign signal_mux_106 = advance ? pc_next : pc_0;
    assign signal_wire_4 = program_write$data;
    assign signal_wire_5 = program_write$addr;
    assign d$jmp_target = word[8:0];
    assign signal_not_26 = ~ signal_select_281;
    assign signal_not_27 = ~ signal_select_675;
    assign signal_add_1 = stuff_run_0 + signal_const_67;
    assign stuff_run_max = 5'b11111;
    assign signal_eq_16 = stuff_run_0 == stuff_run_max;
    assign signal_mux_107 = signal_eq_16 ? stuff_run_0 : signal_add_1;
    assign signal_wire_6 = config$stuff_level;
    assign signal_eq_17 = crossing_bit == signal_wire_6;
    assign signal_mux_108 = signal_eq_17 ? signal_mux_107 : signal_const_69;
    assign signal_mux_109 = bit_crosses ? signal_mux_108 : stuff_run_0;
    assign signal_const_105 = 4'b0110;
    assign signal_eq_18 = d$sys_op$binary_variant == signal_const_105;
    assign signal_and_45 = is_opcode$7 & signal_eq_18;
    assign stuff_run_next = signal_and_45 ? signal_const_69 : signal_mux_109;
    assign signal_mux_110 = go ? stuff_run_next : stuff_run_0;
    assign signal_mux_111 = start_0 ? signal_const_69 : signal_mux_110;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_10 <= signal_const_69;
        else
            signal_reg_10 <= signal_mux_111;
    end
    assign stuff_run_0 = signal_reg_10;
    assign signal_lt_10 = stuff_run_0 < signal_wire_7;
    assign signal_not_28 = ~ signal_lt_10;
    assign signal_wire_7 = config$stuff_threshold;
    assign signal_eq_19 = signal_wire_7 == signal_const_69;
    assign signal_not_29 = ~ signal_eq_19;
    assign signal_and_46 = signal_not_29 & signal_not_28;
    assign signal_lt_11 = osr_count_0 < signal_wire_34;
    assign signal_select_225 = sample[27:27];
    assign signal_select_226 = sample[26:26];
    assign signal_select_227 = sample[25:25];
    assign signal_select_228 = sample[24:24];
    assign signal_select_229 = sample[23:23];
    assign signal_select_230 = sample[22:22];
    assign signal_select_231 = sample[21:21];
    assign signal_select_232 = sample[20:20];
    assign signal_select_233 = sample[19:19];
    assign signal_select_234 = sample[18:18];
    assign signal_select_235 = sample[17:17];
    assign signal_select_236 = sample[16:16];
    assign signal_select_237 = sample[15:15];
    assign signal_select_238 = sample[14:14];
    assign signal_select_239 = sample[13:13];
    assign signal_select_240 = sample[12:12];
    assign signal_select_241 = sample[11:11];
    assign signal_select_242 = sample[10:10];
    assign signal_select_243 = sample[9:9];
    assign signal_select_244 = sample[8:8];
    assign signal_select_245 = sample[7:7];
    assign signal_select_246 = sample[6:6];
    assign signal_select_247 = sample[5:5];
    assign signal_select_248 = sample[4:4];
    assign signal_select_249 = sample[3:3];
    assign signal_select_250 = sample[2:2];
    assign signal_select_251 = sample[1:1];
    assign signal_select_252 = sample[0:0];
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_112 <= signal_select_252;
        1:
            signal_mux_112 <= signal_select_251;
        2:
            signal_mux_112 <= signal_select_250;
        3:
            signal_mux_112 <= signal_select_249;
        4:
            signal_mux_112 <= signal_select_248;
        5:
            signal_mux_112 <= signal_select_247;
        6:
            signal_mux_112 <= signal_select_246;
        7:
            signal_mux_112 <= signal_select_245;
        8:
            signal_mux_112 <= signal_select_244;
        9:
            signal_mux_112 <= signal_select_243;
        10:
            signal_mux_112 <= signal_select_242;
        11:
            signal_mux_112 <= signal_select_241;
        12:
            signal_mux_112 <= signal_select_240;
        13:
            signal_mux_112 <= signal_select_239;
        14:
            signal_mux_112 <= signal_select_238;
        15:
            signal_mux_112 <= signal_select_237;
        16:
            signal_mux_112 <= signal_select_236;
        17:
            signal_mux_112 <= signal_select_235;
        18:
            signal_mux_112 <= signal_select_234;
        19:
            signal_mux_112 <= signal_select_233;
        20:
            signal_mux_112 <= signal_select_232;
        21:
            signal_mux_112 <= signal_select_231;
        22:
            signal_mux_112 <= signal_select_230;
        23:
            signal_mux_112 <= signal_select_229;
        24:
            signal_mux_112 <= signal_select_228;
        25:
            signal_mux_112 <= signal_select_227;
        26:
            signal_mux_112 <= signal_select_226;
        default:
            signal_mux_112 <= signal_select_225;
        endcase
    end
    assign signal_not_30 = ~ signal_mux_112;
    assign signal_select_253 = sample[27:27];
    assign signal_select_254 = sample[26:26];
    assign signal_select_255 = sample[25:25];
    assign signal_select_256 = sample[24:24];
    assign signal_select_257 = sample[23:23];
    assign signal_select_258 = sample[22:22];
    assign signal_select_259 = sample[21:21];
    assign signal_select_260 = sample[20:20];
    assign signal_select_261 = sample[19:19];
    assign signal_select_262 = sample[18:18];
    assign signal_select_263 = sample[17:17];
    assign signal_select_264 = sample[16:16];
    assign signal_select_265 = sample[15:15];
    assign signal_select_266 = sample[14:14];
    assign signal_select_267 = sample[13:13];
    assign signal_select_268 = sample[12:12];
    assign signal_select_269 = sample[11:11];
    assign signal_select_270 = sample[10:10];
    assign signal_select_271 = sample[9:9];
    assign signal_select_272 = sample[8:8];
    assign signal_select_273 = sample[7:7];
    assign signal_select_274 = sample[6:6];
    assign signal_select_275 = sample[5:5];
    assign signal_select_276 = sample[4:4];
    assign signal_select_277 = sample[3:3];
    assign signal_select_278 = sample[2:2];
    assign signal_select_279 = sample[1:1];
    assign signal_select_280 = sample[0:0];
    assign signal_wire_8 = config$jmp_pin;
    always @* begin
        case (signal_wire_8)
        0:
            signal_mux_113 <= signal_select_280;
        1:
            signal_mux_113 <= signal_select_279;
        2:
            signal_mux_113 <= signal_select_278;
        3:
            signal_mux_113 <= signal_select_277;
        4:
            signal_mux_113 <= signal_select_276;
        5:
            signal_mux_113 <= signal_select_275;
        6:
            signal_mux_113 <= signal_select_274;
        7:
            signal_mux_113 <= signal_select_273;
        8:
            signal_mux_113 <= signal_select_272;
        9:
            signal_mux_113 <= signal_select_271;
        10:
            signal_mux_113 <= signal_select_270;
        11:
            signal_mux_113 <= signal_select_269;
        12:
            signal_mux_113 <= signal_select_268;
        13:
            signal_mux_113 <= signal_select_267;
        14:
            signal_mux_113 <= signal_select_266;
        15:
            signal_mux_113 <= signal_select_265;
        16:
            signal_mux_113 <= signal_select_264;
        17:
            signal_mux_113 <= signal_select_263;
        18:
            signal_mux_113 <= signal_select_262;
        19:
            signal_mux_113 <= signal_select_261;
        20:
            signal_mux_113 <= signal_select_260;
        21:
            signal_mux_113 <= signal_select_259;
        22:
            signal_mux_113 <= signal_select_258;
        23:
            signal_mux_113 <= signal_select_257;
        24:
            signal_mux_113 <= signal_select_256;
        25:
            signal_mux_113 <= signal_select_255;
        26:
            signal_mux_113 <= signal_select_254;
        default:
            signal_mux_113 <= signal_select_253;
        endcase
    end
    assign signal_eq_20 = x_0 == y_0;
    assign signal_not_31 = ~ signal_eq_20;
    assign signal_eq_21 = y_0 == signal_const_17;
    assign signal_not_32 = ~ signal_eq_21;
    assign signal_eq_22 = x_0 == signal_const_17;
    assign signal_not_33 = ~ signal_eq_22;
    always @* begin
        case (d$jmp_cond$binary_variant)
        0:
            jmp_taken <= vdd;
        1:
            jmp_taken <= signal_not_33;
        2:
            jmp_taken <= signal_not_32;
        3:
            jmp_taken <= signal_not_31;
        4:
            jmp_taken <= signal_mux_113;
        5:
            jmp_taken <= signal_not_30;
        6:
            jmp_taken <= signal_lt_11;
        7:
            jmp_taken <= signal_and_46;
        8:
            jmp_taken <= signal_not_27;
        9:
            jmp_taken <= signal_select_675;
        10:
            jmp_taken <= signal_not_26;
        default:
            jmp_taken <= signal_select_281;
        endcase
    end
    assign jmp_target_or_next = jmp_taken ? d$jmp_target : pc_next;
    assign signal_eq_23 = signal_const_10 == signal_wire_10;
    assign signal_mux_114 = signal_eq_23 ? signal_wire_9 : signal_const_12;
    assign signal_add_2 = pc_next + signal_const_12;
    assign signal_eq_24 = pc_next == signal_wire_10;
    assign signal_mux_115 = signal_eq_24 ? signal_wire_9 : signal_add_2;
    assign signal_wire_9 = config$wrap_bottom;
    assign signal_add_3 = pc_0 + signal_const_12;
    assign signal_wire_10 = config$wrap_top;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_11 <= signal_const_10;
        else
            signal_reg_11 <= pc_value_next;
    end
    assign pc_0 = signal_reg_11;
    assign signal_eq_25 = pc_0 == signal_wire_10;
    assign pc_next = signal_eq_25 ? signal_wire_9 : signal_add_3;
    assign signal_not_34 = ~ signal_select_675;
    assign signal_wire_11 = rx_pop;
    assign signal_mux_116 = is_opcode$2 ? isr_shifted : isr_0;
    assign signal_wire_12 = signal_mux_116;
    assign signal_not_35 = ~ signal_select_281;
    assign signal_const_114 = 4'b0011;
    assign signal_eq_26 = d$sys_op$binary_variant == signal_const_114;
    assign signal_and_47 = is_opcode$7 & signal_eq_26;
    assign signal_and_48 = is_opcode$2 & autopush_now;
    assign pushes = signal_and_48 | signal_and_47;
    assign signal_and_49 = op_go & pushes;
    assign signal_and_50 = signal_and_49 & signal_not_35;
    assign signal_wire_13 = signal_and_50;
    host_fifo
        rx
        ( .clock(signal_wire_49),
          .clear(signal_wire_48),
          .push$valid(signal_wire_13),
          .push$value(signal_wire_12),
          .pop(signal_wire_11),
          .flush(flush_0),
          .head(signal_inst[15:0]),
          .level(signal_inst[19:16]),
          .empty(signal_inst[20:20]),
          .full(signal_inst[21:21]) );
    assign signal_select_281 = signal_inst[21:21];
    assign signal_not_36 = ~ signal_select_281;
    assign signal_mux_117 = d$wait_polarity ? signal_not_34 : signal_not_36;
    assign signal_xor = t_0 ^ signal_cat_87;
    assign signal_sub_3 = t_0 - signal_cat_87;
    assign signal_cat_87 = { signal_const_18,
                             alu_operand };
    assign signal_add_4 = t_0 + signal_cat_87;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_118 <= signal_add_4;
        1:
            signal_mux_118 <= signal_sub_3;
        default:
            signal_mux_118 <= signal_xor;
        endcase
    end
    assign signal_eq_27 = d$alu_dest$binary_variant == signal_const_84;
    assign signal_mux_119 = signal_eq_27 ? signal_mux_118 : t_0;
    assign signal_select_282 = mov_value24[23:23];
    assign signal_select_283 = mov_value24[22:22];
    assign signal_select_284 = mov_value24[21:21];
    assign signal_select_285 = mov_value24[20:20];
    assign signal_select_286 = mov_value24[19:19];
    assign signal_select_287 = mov_value24[18:18];
    assign signal_select_288 = mov_value24[17:17];
    assign signal_select_289 = mov_value24[16:16];
    assign signal_select_290 = mov_value24[15:15];
    assign signal_select_291 = mov_value24[14:14];
    assign signal_select_292 = mov_value24[13:13];
    assign signal_select_293 = mov_value24[12:12];
    assign signal_select_294 = mov_value24[11:11];
    assign signal_select_295 = mov_value24[10:10];
    assign signal_select_296 = mov_value24[9:9];
    assign signal_select_297 = mov_value24[8:8];
    assign signal_select_298 = mov_value24[7:7];
    assign signal_select_299 = mov_value24[6:6];
    assign signal_select_300 = mov_value24[5:5];
    assign signal_select_301 = mov_value24[4:4];
    assign signal_select_302 = mov_value24[3:3];
    assign signal_select_303 = mov_value24[2:2];
    assign signal_select_304 = mov_value24[1:1];
    assign signal_select_305 = mov_value24[0:0];
    assign signal_cat_88 = { signal_select_305,
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
                             signal_select_283,
                             signal_select_282 };
    assign signal_not_37 = ~ mov_value24;
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value_t <= mov_value24;
        1:
            mov_value_t <= signal_not_37;
        default:
            mov_value_t <= signal_cat_88;
        endcase
    end
    assign signal_const_118 = 3'b111;
    assign signal_eq_28 = d$mov_dest$binary_variant == signal_const_118;
    assign signal_mux_120 = signal_eq_28 ? mov_value_t : t_0;
    assign signal_cat_89 = { signal_const_18,
                             out_value };
    assign signal_eq_29 = d$out_dest$binary_variant == signal_const_118;
    assign signal_mux_121 = signal_eq_29 ? signal_cat_89 : t_0;
    assign signal_wire_14 = config$period_fraction;
    assign signal_cat_90 = { gnd,
                             signal_wire_14 };
    assign signal_eq_30 = d$alu_dest$binary_variant == signal_const_84;
    assign signal_mux_122 = signal_eq_30 ? signal_const_17 : t_fraction_0;
    assign signal_eq_31 = d$mov_dest$binary_variant == signal_const_118;
    assign signal_mux_123 = signal_eq_31 ? signal_const_17 : t_fraction_0;
    assign signal_eq_32 = d$out_dest$binary_variant == signal_const_118;
    assign signal_mux_124 = signal_eq_32 ? signal_const_17 : t_fraction_0;
    assign signal_select_306 = fraction_sum[15:0];
    assign signal_mux_125 = advances_deadline ? signal_select_306 : t_fraction_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_fraction_next <= t_fraction_0;
        1:
            t_fraction_next <= signal_mux_125;
        2:
            t_fraction_next <= t_fraction_0;
        3:
            t_fraction_next <= signal_mux_124;
        4:
            t_fraction_next <= signal_mux_123;
        5:
            t_fraction_next <= t_fraction_0;
        6:
            t_fraction_next <= signal_mux_122;
        default:
            t_fraction_next <= t_fraction_0;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_12 <= signal_const_17;
        else
            if (go)
                signal_reg_12 <= t_fraction_next;
    end
    assign t_fraction_0 = signal_reg_12;
    assign signal_cat_91 = { gnd,
                             t_fraction_0 };
    assign fraction_sum = signal_cat_91 + signal_cat_90;
    assign signal_select_307 = fraction_sum[16:16];
    assign signal_const_128 = 23'b00000000000000000000000;
    assign signal_cat_92 = { signal_const_128,
                             signal_select_307 };
    assign signal_cat_93 = { signal_const_18,
                             p_0 };
    assign signal_add_5 = t_0 + signal_cat_93;
    assign t_advanced = signal_add_5 + signal_cat_92;
    assign signal_const_130 = 2'b10;
    assign signal_eq_33 = d$wait_source$binary_variant == signal_const_130;
    assign signal_and_51 = is_opcode$1 & signal_eq_33;
    assign releases_deadline = signal_and_51 & wait_ready;
    assign advances_deadline = releases_deadline & d$wait_polarity;
    assign signal_mux_126 = advances_deadline ? t_advanced : t_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_next <= t_0;
        1:
            t_next <= signal_mux_126;
        2:
            t_next <= t_0;
        3:
            t_next <= signal_mux_121;
        4:
            t_next <= signal_mux_120;
        5:
            t_next <= t_0;
        6:
            t_next <= signal_mux_119;
        default:
            t_next <= t_0;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_13 <= signal_const_4;
        else
            if (go)
                signal_reg_13 <= t_next;
    end
    assign t_0 = signal_reg_13;
    assign signal_sub_4 = now_0 - t_0;
    assign signal_select_308 = signal_sub_4[23:23];
    assign deadline_ready = ~ signal_select_308;
    assign signal_eq_34 = wait_pin_cur == d$wait_polarity;
    assign signal_and_52 = pins_sampled & wait_select_0;
    assign signal_eq_35 = signal_and_52 == signal_const_13;
    assign wait_pin_prev = ~ signal_eq_35;
    assign signal_eq_36 = wait_pin_cur == wait_pin_prev;
    assign signal_not_38 = ~ signal_eq_36;
    assign signal_and_53 = signal_not_38 & signal_eq_34;
    assign d$wait_polarity = word[7:7];
    assign signal_const_133 = 28'b0000000000000000000000000001;
    assign signal_and_54 = signal_not_39 & signal_and_70;
    assign signal_and_55 = signal_not_39 & signal_and_72;
    assign signal_and_56 = signal_not_39 & signal_and_74;
    assign signal_and_57 = signal_not_39 & signal_and_76;
    assign signal_and_58 = signal_not_39 & signal_and_78;
    assign signal_and_59 = signal_not_39 & signal_and_80;
    assign signal_and_60 = signal_not_39 & signal_and_82;
    assign signal_and_61 = signal_not_39 & signal_and_84;
    assign signal_and_62 = signal_not_39 & signal_and_87;
    assign signal_and_63 = signal_not_39 & signal_and_90;
    assign signal_and_64 = signal_not_39 & signal_and_93;
    assign signal_and_65 = signal_not_39 & signal_and_96;
    assign signal_and_66 = signal_not_39 & signal_and_100;
    assign signal_and_67 = signal_not_39 & signal_and_104;
    assign signal_and_68 = signal_not_39 & signal_and_108;
    assign signal_not_39 = ~ signal_select_314;
    assign signal_and_69 = signal_not_39 & signal_and_112;
    assign signal_and_70 = signal_not_40 & signal_and_86;
    assign signal_and_71 = signal_select_314 & signal_and_70;
    assign signal_and_72 = signal_not_40 & signal_and_89;
    assign signal_and_73 = signal_select_314 & signal_and_72;
    assign signal_and_74 = signal_not_40 & signal_and_92;
    assign signal_and_75 = signal_select_314 & signal_and_74;
    assign signal_and_76 = signal_not_40 & signal_and_95;
    assign signal_and_77 = signal_select_314 & signal_and_76;
    assign signal_and_78 = signal_not_40 & signal_and_99;
    assign signal_and_79 = signal_select_314 & signal_and_78;
    assign signal_and_80 = signal_not_40 & signal_and_103;
    assign signal_and_81 = signal_select_314 & signal_and_80;
    assign signal_and_82 = signal_not_40 & signal_and_107;
    assign signal_and_83 = signal_select_314 & signal_and_82;
    assign signal_not_40 = ~ signal_select_312;
    assign signal_and_84 = signal_not_40 & signal_and_111;
    assign signal_and_85 = signal_select_314 & signal_and_84;
    assign signal_and_86 = signal_not_41 & signal_and_98;
    assign signal_and_87 = signal_select_312 & signal_and_86;
    assign signal_and_88 = signal_select_314 & signal_and_87;
    assign signal_and_89 = signal_not_41 & signal_and_102;
    assign signal_and_90 = signal_select_312 & signal_and_89;
    assign signal_and_91 = signal_select_314 & signal_and_90;
    assign signal_and_92 = signal_not_41 & signal_and_106;
    assign signal_and_93 = signal_select_312 & signal_and_92;
    assign signal_and_94 = signal_select_314 & signal_and_93;
    assign signal_not_41 = ~ signal_select_311;
    assign signal_and_95 = signal_not_41 & signal_and_110;
    assign signal_and_96 = signal_select_312 & signal_and_95;
    assign signal_and_97 = signal_select_314 & signal_and_96;
    assign signal_and_98 = signal_not_42 & signal_not_43;
    assign signal_and_99 = signal_select_311 & signal_and_98;
    assign signal_and_100 = signal_select_312 & signal_and_99;
    assign signal_and_101 = signal_select_314 & signal_and_100;
    assign signal_not_42 = ~ signal_select_310;
    assign signal_and_102 = signal_not_42 & signal_select_309;
    assign signal_and_103 = signal_select_311 & signal_and_102;
    assign signal_and_104 = signal_select_312 & signal_and_103;
    assign signal_and_105 = signal_select_314 & signal_and_104;
    assign signal_not_43 = ~ signal_select_309;
    assign signal_and_106 = signal_select_310 & signal_not_43;
    assign signal_and_107 = signal_select_311 & signal_and_106;
    assign signal_and_108 = signal_select_312 & signal_and_107;
    assign signal_and_109 = signal_select_314 & signal_and_108;
    assign signal_select_309 = signal_select_313[0:0];
    assign signal_select_310 = signal_select_313[1:1];
    assign signal_and_110 = signal_select_310 & signal_select_309;
    assign signal_select_311 = signal_select_313[2:2];
    assign signal_and_111 = signal_select_311 & signal_and_110;
    assign signal_select_312 = signal_select_313[3:3];
    assign signal_and_112 = signal_select_312 & signal_and_111;
    assign signal_select_313 = signal_wire_43[4:0];
    assign signal_select_314 = signal_select_313[4:4];
    assign signal_and_113 = signal_select_314 & signal_and_112;
    assign signal_cat_94 = { signal_and_113,
                             signal_and_109,
                             signal_and_105,
                             signal_and_101,
                             signal_and_97,
                             signal_and_94,
                             signal_and_91,
                             signal_and_88,
                             signal_and_85,
                             signal_and_83,
                             signal_and_81,
                             signal_and_79,
                             signal_and_77,
                             signal_and_75,
                             signal_and_73,
                             signal_and_71,
                             signal_and_69,
                             signal_and_68,
                             signal_and_67,
                             signal_and_66,
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
                             signal_and_54 };
    assign signal_select_315 = signal_cat_94[27:0];
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            wait_select_0 <= signal_const_133;
        else
            if (ir_load)
                wait_select_0 <= signal_select_315;
    end
    assign signal_select_316 = signal_wire_41[0:0];
    assign signal_select_317 = signal_wire_41[1:1];
    assign signal_select_318 = signal_wire_41[2:2];
    assign signal_select_319 = signal_wire_41[3:3];
    assign signal_select_320 = signal_wire_41[4:4];
    assign signal_select_321 = pin_out_0[5:5];
    assign signal_select_322 = pin_out_0[6:6];
    assign signal_select_323 = pin_out_0[7:7];
    assign signal_select_324 = pin_out_0[8:8];
    assign signal_select_325 = pin_out_0[9:9];
    assign signal_select_326 = pin_out_0[10:10];
    assign signal_select_327 = pin_out_0[11:11];
    assign signal_select_328 = pin_out_0[12:12];
    assign signal_select_329 = signal_wire_41[12:12];
    assign signal_select_330 = pin_dir_0[12:12];
    assign signal_mux_127 = signal_select_330 ? signal_select_328 : signal_select_329;
    assign signal_select_331 = pin_out_0[13:13];
    assign signal_select_332 = signal_wire_41[13:13];
    assign signal_select_333 = pin_dir_0[13:13];
    assign signal_mux_128 = signal_select_333 ? signal_select_331 : signal_select_332;
    assign signal_select_334 = pin_out_0[14:14];
    assign signal_select_335 = signal_wire_41[14:14];
    assign signal_select_336 = pin_dir_0[14:14];
    assign signal_mux_129 = signal_select_336 ? signal_select_334 : signal_select_335;
    assign signal_select_337 = pin_out_0[15:15];
    assign signal_select_338 = signal_wire_41[15:15];
    assign signal_select_339 = pin_dir_0[15:15];
    assign signal_mux_130 = signal_select_339 ? signal_select_337 : signal_select_338;
    assign signal_select_340 = pin_out_0[16:16];
    assign signal_select_341 = signal_wire_41[16:16];
    assign signal_select_342 = pin_dir_0[16:16];
    assign signal_mux_131 = signal_select_342 ? signal_select_340 : signal_select_341;
    assign signal_select_343 = pin_out_0[17:17];
    assign signal_select_344 = signal_wire_41[17:17];
    assign signal_select_345 = pin_dir_0[17:17];
    assign signal_mux_132 = signal_select_345 ? signal_select_343 : signal_select_344;
    assign signal_select_346 = pin_out_0[18:18];
    assign signal_select_347 = signal_wire_41[18:18];
    assign signal_select_348 = pin_dir_0[18:18];
    assign signal_mux_133 = signal_select_348 ? signal_select_346 : signal_select_347;
    assign signal_select_349 = pin_out_0[19:19];
    assign signal_select_350 = signal_wire_41[19:19];
    assign signal_select_351 = signal_mux_137[27:12];
    assign signal_select_352 = signal_mux_137[11:0];
    assign signal_cat_95 = { signal_select_352,
                             signal_select_351 };
    assign signal_select_353 = signal_mux_136[27:20];
    assign signal_select_354 = signal_mux_136[19:0];
    assign signal_cat_96 = { signal_select_354,
                             signal_select_353 };
    assign signal_select_355 = signal_mux_135[27:24];
    assign signal_select_356 = signal_mux_135[23:0];
    assign signal_cat_97 = { signal_select_356,
                             signal_select_355 };
    assign signal_select_357 = signal_mux_134[27:26];
    assign signal_select_358 = signal_mux_134[25:0];
    assign signal_cat_98 = { signal_select_358,
                             signal_select_357 };
    assign signal_select_359 = signal_cat_101[27:27];
    assign signal_select_360 = signal_cat_101[26:0];
    assign signal_cat_99 = { signal_select_360,
                             signal_select_359 };
    assign signal_cat_100 = { signal_const_14,
                              d$set_value };
    assign signal_cat_101 = { signal_const_15,
                              signal_cat_100 };
    assign signal_select_361 = signal_wire_16[0:0];
    assign signal_mux_134 = signal_select_361 ? signal_cat_99 : signal_cat_101;
    assign signal_select_362 = signal_wire_16[1:1];
    assign signal_mux_135 = signal_select_362 ? signal_cat_98 : signal_mux_134;
    assign signal_select_363 = signal_wire_16[2:2];
    assign signal_mux_136 = signal_select_363 ? signal_cat_97 : signal_mux_135;
    assign signal_select_364 = signal_wire_16[3:3];
    assign signal_mux_137 = signal_select_364 ? signal_cat_96 : signal_mux_136;
    assign signal_select_365 = signal_wire_16[4:4];
    assign signal_mux_138 = signal_select_365 ? signal_cat_95 : signal_mux_137;
    assign signal_and_114 = signal_mux_138 & signal_and_115;
    assign signal_const_137 = 28'b0000000011111111000000000000;
    assign signal_select_366 = signal_mux_147[27:12];
    assign signal_select_367 = signal_mux_147[11:0];
    assign signal_cat_102 = { signal_select_367,
                              signal_select_366 };
    assign signal_select_368 = signal_mux_146[27:20];
    assign signal_select_369 = signal_mux_146[19:0];
    assign signal_cat_103 = { signal_select_369,
                              signal_select_368 };
    assign signal_select_370 = signal_mux_145[27:24];
    assign signal_select_371 = signal_mux_145[23:0];
    assign signal_cat_104 = { signal_select_371,
                              signal_select_370 };
    assign signal_select_372 = signal_mux_144[27:26];
    assign signal_select_373 = signal_mux_144[25:0];
    assign signal_cat_105 = { signal_select_373,
                              signal_select_372 };
    assign signal_select_374 = signal_cat_111[27:27];
    assign signal_select_375 = signal_cat_111[26:0];
    assign signal_cat_106 = { signal_select_375,
                              signal_select_374 };
    assign signal_select_376 = signal_mux_141[7:0];
    assign signal_cat_107 = { signal_select_376,
                              signal_const_18 };
    assign signal_select_377 = signal_mux_140[11:0];
    assign signal_cat_108 = { signal_select_377,
                              signal_const_19 };
    assign signal_select_378 = signal_mux_139[13:0];
    assign signal_cat_109 = { signal_select_378,
                              signal_const_20 };
    assign signal_select_379 = signal_cat_110[0:0];
    assign signal_mux_139 = signal_select_379 ? signal_const_21 : signal_const_22;
    assign signal_select_380 = signal_cat_110[1:1];
    assign signal_mux_140 = signal_select_380 ? signal_cat_109 : signal_mux_139;
    assign signal_select_381 = signal_cat_110[2:2];
    assign signal_mux_141 = signal_select_381 ? signal_cat_108 : signal_mux_140;
    assign signal_select_382 = signal_cat_110[3:3];
    assign signal_mux_142 = signal_select_382 ? signal_cat_107 : signal_mux_141;
    assign signal_wire_15 = config$set_count;
    assign signal_cat_110 = { signal_const_20,
                              signal_wire_15 };
    assign signal_select_383 = signal_cat_110[4:4];
    assign signal_mux_143 = signal_select_383 ? signal_const_17 : signal_mux_142;
    assign signal_not_44 = ~ signal_mux_143;
    assign signal_cat_111 = { signal_const_15,
                              signal_not_44 };
    assign signal_select_384 = signal_wire_16[0:0];
    assign signal_mux_144 = signal_select_384 ? signal_cat_106 : signal_cat_111;
    assign signal_select_385 = signal_wire_16[1:1];
    assign signal_mux_145 = signal_select_385 ? signal_cat_105 : signal_mux_144;
    assign signal_select_386 = signal_wire_16[2:2];
    assign signal_mux_146 = signal_select_386 ? signal_cat_104 : signal_mux_145;
    assign signal_select_387 = signal_wire_16[3:3];
    assign signal_mux_147 = signal_select_387 ? signal_cat_103 : signal_mux_146;
    assign signal_wire_16 = config$set_base;
    assign signal_select_388 = signal_wire_16[4:4];
    assign signal_mux_148 = signal_select_388 ? signal_cat_102 : signal_mux_147;
    assign signal_and_115 = signal_mux_148 & signal_const_137;
    assign signal_not_45 = ~ signal_and_115;
    assign signal_and_116 = pin_dir_base & signal_not_45;
    assign signal_or_10 = signal_and_116 | signal_and_114;
    assign signal_const_146 = 3'b011;
    assign signal_eq_37 = d$set_dest$binary_variant == signal_const_146;
    assign signal_mux_149 = signal_eq_37 ? signal_or_10 : pin_dir_base;
    assign signal_select_389 = signal_mux_153[27:12];
    assign signal_select_390 = signal_mux_153[11:0];
    assign signal_cat_112 = { signal_select_390,
                              signal_select_389 };
    assign signal_select_391 = signal_mux_152[27:20];
    assign signal_select_392 = signal_mux_152[19:0];
    assign signal_cat_113 = { signal_select_392,
                              signal_select_391 };
    assign signal_select_393 = signal_mux_151[27:24];
    assign signal_select_394 = signal_mux_151[23:0];
    assign signal_cat_114 = { signal_select_394,
                              signal_select_393 };
    assign signal_select_395 = signal_mux_150[27:26];
    assign signal_select_396 = signal_mux_150[25:0];
    assign signal_cat_115 = { signal_select_396,
                              signal_select_395 };
    assign signal_select_397 = signal_cat_117[27:27];
    assign signal_select_398 = signal_cat_117[26:0];
    assign signal_cat_116 = { signal_select_398,
                              signal_select_397 };
    assign signal_cat_117 = { signal_const_15,
                              mov_value };
    assign signal_select_399 = signal_wire_37[0:0];
    assign signal_mux_150 = signal_select_399 ? signal_cat_116 : signal_cat_117;
    assign signal_select_400 = signal_wire_37[1:1];
    assign signal_mux_151 = signal_select_400 ? signal_cat_115 : signal_mux_150;
    assign signal_select_401 = signal_wire_37[2:2];
    assign signal_mux_152 = signal_select_401 ? signal_cat_114 : signal_mux_151;
    assign signal_select_402 = signal_wire_37[3:3];
    assign signal_mux_153 = signal_select_402 ? signal_cat_113 : signal_mux_152;
    assign signal_select_403 = signal_wire_37[4:4];
    assign signal_mux_154 = signal_select_403 ? signal_cat_112 : signal_mux_153;
    assign signal_and_117 = signal_mux_154 & signal_and_118;
    assign signal_select_404 = signal_mux_163[27:12];
    assign signal_select_405 = signal_mux_163[11:0];
    assign signal_cat_118 = { signal_select_405,
                              signal_select_404 };
    assign signal_select_406 = signal_mux_162[27:20];
    assign signal_select_407 = signal_mux_162[19:0];
    assign signal_cat_119 = { signal_select_407,
                              signal_select_406 };
    assign signal_select_408 = signal_mux_161[27:24];
    assign signal_select_409 = signal_mux_161[23:0];
    assign signal_cat_120 = { signal_select_409,
                              signal_select_408 };
    assign signal_select_410 = signal_mux_160[27:26];
    assign signal_select_411 = signal_mux_160[25:0];
    assign signal_cat_121 = { signal_select_411,
                              signal_select_410 };
    assign signal_select_412 = signal_cat_126[27:27];
    assign signal_select_413 = signal_cat_126[26:0];
    assign signal_cat_122 = { signal_select_413,
                              signal_select_412 };
    assign signal_select_414 = signal_mux_157[7:0];
    assign signal_cat_123 = { signal_select_414,
                              signal_const_18 };
    assign signal_select_415 = signal_mux_156[11:0];
    assign signal_cat_124 = { signal_select_415,
                              signal_const_19 };
    assign signal_select_416 = signal_mux_155[13:0];
    assign signal_cat_125 = { signal_select_416,
                              signal_const_20 };
    assign signal_select_417 = signal_wire_17[0:0];
    assign signal_mux_155 = signal_select_417 ? signal_const_21 : signal_const_22;
    assign signal_select_418 = signal_wire_17[1:1];
    assign signal_mux_156 = signal_select_418 ? signal_cat_125 : signal_mux_155;
    assign signal_select_419 = signal_wire_17[2:2];
    assign signal_mux_157 = signal_select_419 ? signal_cat_124 : signal_mux_156;
    assign signal_select_420 = signal_wire_17[3:3];
    assign signal_mux_158 = signal_select_420 ? signal_cat_123 : signal_mux_157;
    assign signal_wire_17 = config$out_count;
    assign signal_select_421 = signal_wire_17[4:4];
    assign signal_mux_159 = signal_select_421 ? signal_const_17 : signal_mux_158;
    assign signal_not_46 = ~ signal_mux_159;
    assign signal_cat_126 = { signal_const_15,
                              signal_not_46 };
    assign signal_select_422 = signal_wire_37[0:0];
    assign signal_mux_160 = signal_select_422 ? signal_cat_122 : signal_cat_126;
    assign signal_select_423 = signal_wire_37[1:1];
    assign signal_mux_161 = signal_select_423 ? signal_cat_121 : signal_mux_160;
    assign signal_select_424 = signal_wire_37[2:2];
    assign signal_mux_162 = signal_select_424 ? signal_cat_120 : signal_mux_161;
    assign signal_select_425 = signal_wire_37[3:3];
    assign signal_mux_163 = signal_select_425 ? signal_cat_119 : signal_mux_162;
    assign signal_select_426 = signal_wire_37[4:4];
    assign signal_mux_164 = signal_select_426 ? signal_cat_118 : signal_mux_163;
    assign signal_and_118 = signal_mux_164 & signal_const_137;
    assign signal_not_47 = ~ signal_and_118;
    assign signal_and_119 = pin_dir_base & signal_not_47;
    assign signal_or_11 = signal_and_119 | signal_and_117;
    assign signal_eq_38 = d$mov_dest$binary_variant == signal_const_146;
    assign signal_mux_165 = signal_eq_38 ? signal_or_11 : pin_dir_base;
    assign signal_select_427 = signal_mux_275[27:12];
    assign signal_select_428 = signal_mux_275[11:0];
    assign signal_cat_127 = { signal_select_428,
                              signal_select_427 };
    assign signal_select_429 = signal_mux_274[27:20];
    assign signal_select_430 = signal_mux_274[19:0];
    assign signal_cat_128 = { signal_select_430,
                              signal_select_429 };
    assign signal_select_431 = signal_mux_273[27:24];
    assign signal_select_432 = signal_mux_273[23:0];
    assign signal_cat_129 = { signal_select_432,
                              signal_select_431 };
    assign signal_select_433 = signal_mux_272[27:26];
    assign signal_select_434 = signal_mux_272[25:0];
    assign signal_cat_130 = { signal_select_434,
                              signal_select_433 };
    assign signal_select_435 = signal_cat_194[27:27];
    assign signal_select_436 = signal_cat_194[26:0];
    assign signal_cat_131 = { signal_select_436,
                              signal_select_435 };
    assign signal_and_120 = osr_before & mask;
    assign signal_select_437 = signal_mux_269[15:8];
    assign signal_cat_132 = { signal_const_18,
                              signal_select_437 };
    assign signal_select_438 = signal_mux_268[15:4];
    assign signal_cat_133 = { signal_const_19,
                              signal_select_438 };
    assign signal_select_439 = signal_mux_267[15:2];
    assign signal_cat_134 = { signal_const_20,
                              signal_select_439 };
    assign signal_select_440 = osr_before[15:1];
    assign signal_cat_135 = { signal_const_3,
                              signal_select_440 };
    assign signal_wire_18 = data_word;
    assign signal_select_441 = signal_inst_1[15:0];
    assign signal_not_48 = ~ signal_select_675;
    assign signal_and_121 = pulls & signal_not_48;
    assign signal_mux_166 = signal_and_121 ? signal_select_441 : osr_0;
    assign signal_select_442 = signal_select_656[15:15];
    assign signal_select_443 = signal_select_656[14:14];
    assign signal_select_444 = signal_select_656[13:13];
    assign signal_select_445 = signal_select_656[12:12];
    assign signal_select_446 = signal_select_656[11:11];
    assign signal_select_447 = signal_select_656[10:10];
    assign signal_select_448 = signal_select_656[9:9];
    assign signal_select_449 = signal_select_656[8:8];
    assign signal_select_450 = signal_select_656[7:7];
    assign signal_select_451 = signal_select_656[6:6];
    assign signal_select_452 = signal_select_656[5:5];
    assign signal_select_453 = signal_select_656[4:4];
    assign signal_select_454 = signal_select_656[3:3];
    assign signal_select_455 = signal_select_656[2:2];
    assign signal_select_456 = signal_select_656[1:1];
    assign signal_select_457 = signal_select_656[0:0];
    assign signal_cat_136 = { signal_select_457,
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
                              signal_select_443,
                              signal_select_442 };
    assign signal_not_49 = ~ signal_select_656;
    assign signal_cat_137 = { signal_const_18,
                              osr_0 };
    assign signal_cat_138 = { signal_const_18,
                              isr_0 };
    assign signal_cat_139 = { signal_const_18,
                              y_0 };
    assign signal_xor_1 = x_0 ^ alu_operand;
    assign signal_sub_5 = x_0 - alu_operand;
    assign signal_eq_39 = d$sys_op$binary_variant == signal_const_114;
    assign signal_and_122 = is_opcode$7 & signal_eq_39;
    assign signal_mux_167 = signal_and_122 ? signal_const_17 : isr_0;
    assign signal_eq_40 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_168 = signal_eq_40 ? mov_value : isr_0;
    assign signal_eq_41 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_169 = signal_eq_41 ? out_value : isr_0;
    assign signal_select_458 = signal_mux_172[7:0];
    assign signal_cat_140 = { signal_select_458,
                              signal_const_18 };
    assign signal_select_459 = signal_mux_171[11:0];
    assign signal_cat_141 = { signal_select_459,
                              signal_const_19 };
    assign signal_select_460 = signal_mux_170[13:0];
    assign signal_cat_142 = { signal_select_460,
                              signal_const_20 };
    assign signal_select_461 = in_value[14:0];
    assign signal_cat_143 = { signal_select_461,
                              signal_const_3 };
    assign signal_select_462 = shift_back[0:0];
    assign signal_mux_170 = signal_select_462 ? signal_cat_143 : in_value;
    assign signal_select_463 = shift_back[1:1];
    assign signal_mux_171 = signal_select_463 ? signal_cat_142 : signal_mux_170;
    assign signal_select_464 = shift_back[2:2];
    assign signal_mux_172 = signal_select_464 ? signal_cat_141 : signal_mux_171;
    assign signal_select_465 = shift_back[3:3];
    assign signal_mux_173 = signal_select_465 ? signal_cat_140 : signal_mux_172;
    assign signal_select_466 = shift_back[4:4];
    assign signal_mux_174 = signal_select_466 ? signal_const_17 : signal_mux_173;
    assign signal_select_467 = signal_mux_177[15:8];
    assign signal_cat_144 = { signal_const_18,
                              signal_select_467 };
    assign signal_select_468 = signal_mux_176[15:4];
    assign signal_cat_145 = { signal_const_19,
                              signal_select_468 };
    assign signal_select_469 = signal_mux_175[15:2];
    assign signal_cat_146 = { signal_const_20,
                              signal_select_469 };
    assign signal_select_470 = isr_0[15:1];
    assign signal_cat_147 = { signal_const_3,
                              signal_select_470 };
    assign signal_select_471 = d$shift_count[0:0];
    assign signal_mux_175 = signal_select_471 ? signal_cat_147 : isr_0;
    assign signal_select_472 = d$shift_count[1:1];
    assign signal_mux_176 = signal_select_472 ? signal_cat_146 : signal_mux_175;
    assign signal_select_473 = d$shift_count[2:2];
    assign signal_mux_177 = signal_select_473 ? signal_cat_145 : signal_mux_176;
    assign signal_select_474 = d$shift_count[3:3];
    assign signal_mux_178 = signal_select_474 ? signal_cat_144 : signal_mux_177;
    assign signal_select_475 = d$shift_count[4:4];
    assign signal_mux_179 = signal_select_475 ? signal_const_17 : signal_mux_178;
    assign signal_or_12 = signal_mux_179 | signal_mux_174;
    assign signal_select_476 = signal_mux_182[7:0];
    assign signal_cat_148 = { signal_select_476,
                              signal_const_18 };
    assign signal_select_477 = signal_mux_181[11:0];
    assign signal_cat_149 = { signal_select_477,
                              signal_const_19 };
    assign signal_select_478 = signal_mux_180[13:0];
    assign signal_cat_150 = { signal_select_478,
                              signal_const_20 };
    assign signal_select_479 = d$shift_count[0:0];
    assign signal_mux_180 = signal_select_479 ? signal_const_21 : signal_const_22;
    assign signal_select_480 = d$shift_count[1:1];
    assign signal_mux_181 = signal_select_480 ? signal_cat_150 : signal_mux_180;
    assign signal_select_481 = d$shift_count[2:2];
    assign signal_mux_182 = signal_select_481 ? signal_cat_149 : signal_mux_181;
    assign signal_select_482 = d$shift_count[3:3];
    assign signal_mux_183 = signal_select_482 ? signal_cat_148 : signal_mux_182;
    assign signal_select_483 = d$shift_count[4:4];
    assign signal_mux_184 = signal_select_483 ? signal_const_17 : signal_mux_183;
    assign mask = ~ signal_mux_184;
    assign signal_wire_19 = config$capture_rising;
    assign signal_select_484 = sample[27:27];
    assign signal_select_485 = sample[26:26];
    assign signal_select_486 = sample[25:25];
    assign signal_select_487 = sample[24:24];
    assign signal_select_488 = sample[23:23];
    assign signal_select_489 = sample[22:22];
    assign signal_select_490 = sample[21:21];
    assign signal_select_491 = sample[20:20];
    assign signal_select_492 = sample[19:19];
    assign signal_select_493 = sample[18:18];
    assign signal_select_494 = sample[17:17];
    assign signal_select_495 = sample[16:16];
    assign signal_select_496 = sample[15:15];
    assign signal_select_497 = sample[14:14];
    assign signal_select_498 = sample[13:13];
    assign signal_select_499 = sample[12:12];
    assign signal_select_500 = sample[11:11];
    assign signal_select_501 = sample[10:10];
    assign signal_select_502 = sample[9:9];
    assign signal_select_503 = sample[8:8];
    assign signal_select_504 = sample[7:7];
    assign signal_select_505 = sample[6:6];
    assign signal_select_506 = sample[5:5];
    assign signal_select_507 = sample[4:4];
    assign signal_select_508 = sample[3:3];
    assign signal_select_509 = sample[2:2];
    assign signal_select_510 = sample[1:1];
    assign signal_select_511 = sample[0:0];
    always @* begin
        case (signal_wire_20)
        0:
            signal_mux_185 <= signal_select_511;
        1:
            signal_mux_185 <= signal_select_510;
        2:
            signal_mux_185 <= signal_select_509;
        3:
            signal_mux_185 <= signal_select_508;
        4:
            signal_mux_185 <= signal_select_507;
        5:
            signal_mux_185 <= signal_select_506;
        6:
            signal_mux_185 <= signal_select_505;
        7:
            signal_mux_185 <= signal_select_504;
        8:
            signal_mux_185 <= signal_select_503;
        9:
            signal_mux_185 <= signal_select_502;
        10:
            signal_mux_185 <= signal_select_501;
        11:
            signal_mux_185 <= signal_select_500;
        12:
            signal_mux_185 <= signal_select_499;
        13:
            signal_mux_185 <= signal_select_498;
        14:
            signal_mux_185 <= signal_select_497;
        15:
            signal_mux_185 <= signal_select_496;
        16:
            signal_mux_185 <= signal_select_495;
        17:
            signal_mux_185 <= signal_select_494;
        18:
            signal_mux_185 <= signal_select_493;
        19:
            signal_mux_185 <= signal_select_492;
        20:
            signal_mux_185 <= signal_select_491;
        21:
            signal_mux_185 <= signal_select_490;
        22:
            signal_mux_185 <= signal_select_489;
        23:
            signal_mux_185 <= signal_select_488;
        24:
            signal_mux_185 <= signal_select_487;
        25:
            signal_mux_185 <= signal_select_486;
        26:
            signal_mux_185 <= signal_select_485;
        default:
            signal_mux_185 <= signal_select_484;
        endcase
    end
    assign signal_eq_42 = signal_mux_185 == signal_wire_19;
    assign signal_select_512 = pins_sampled[27:27];
    assign signal_select_513 = pins_sampled[26:26];
    assign signal_select_514 = pins_sampled[25:25];
    assign signal_select_515 = pins_sampled[24:24];
    assign signal_select_516 = pins_sampled[23:23];
    assign signal_select_517 = pins_sampled[22:22];
    assign signal_select_518 = pins_sampled[21:21];
    assign signal_select_519 = pins_sampled[20:20];
    assign signal_select_520 = pins_sampled[19:19];
    assign signal_select_521 = pins_sampled[18:18];
    assign signal_select_522 = pins_sampled[17:17];
    assign signal_select_523 = pins_sampled[16:16];
    assign signal_select_524 = pins_sampled[15:15];
    assign signal_select_525 = pins_sampled[14:14];
    assign signal_select_526 = pins_sampled[13:13];
    assign signal_select_527 = pins_sampled[12:12];
    assign signal_select_528 = pins_sampled[11:11];
    assign signal_select_529 = pins_sampled[10:10];
    assign signal_select_530 = pins_sampled[9:9];
    assign signal_select_531 = pins_sampled[8:8];
    assign signal_select_532 = pins_sampled[7:7];
    assign signal_select_533 = pins_sampled[6:6];
    assign signal_select_534 = pins_sampled[5:5];
    assign signal_select_535 = pins_sampled[4:4];
    assign signal_select_536 = pins_sampled[3:3];
    assign signal_select_537 = pins_sampled[2:2];
    assign signal_select_538 = pins_sampled[1:1];
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_14 <= signal_const_13;
        else
            signal_reg_14 <= sample;
    end
    assign pins_sampled = signal_reg_14;
    assign signal_select_539 = pins_sampled[0:0];
    always @* begin
        case (signal_wire_20)
        0:
            signal_mux_186 <= signal_select_539;
        1:
            signal_mux_186 <= signal_select_538;
        2:
            signal_mux_186 <= signal_select_537;
        3:
            signal_mux_186 <= signal_select_536;
        4:
            signal_mux_186 <= signal_select_535;
        5:
            signal_mux_186 <= signal_select_534;
        6:
            signal_mux_186 <= signal_select_533;
        7:
            signal_mux_186 <= signal_select_532;
        8:
            signal_mux_186 <= signal_select_531;
        9:
            signal_mux_186 <= signal_select_530;
        10:
            signal_mux_186 <= signal_select_529;
        11:
            signal_mux_186 <= signal_select_528;
        12:
            signal_mux_186 <= signal_select_527;
        13:
            signal_mux_186 <= signal_select_526;
        14:
            signal_mux_186 <= signal_select_525;
        15:
            signal_mux_186 <= signal_select_524;
        16:
            signal_mux_186 <= signal_select_523;
        17:
            signal_mux_186 <= signal_select_522;
        18:
            signal_mux_186 <= signal_select_521;
        19:
            signal_mux_186 <= signal_select_520;
        20:
            signal_mux_186 <= signal_select_519;
        21:
            signal_mux_186 <= signal_select_518;
        22:
            signal_mux_186 <= signal_select_517;
        23:
            signal_mux_186 <= signal_select_516;
        24:
            signal_mux_186 <= signal_select_515;
        25:
            signal_mux_186 <= signal_select_514;
        26:
            signal_mux_186 <= signal_select_513;
        default:
            signal_mux_186 <= signal_select_512;
        endcase
    end
    assign signal_select_540 = sample[27:27];
    assign signal_select_541 = sample[26:26];
    assign signal_select_542 = sample[25:25];
    assign signal_select_543 = sample[24:24];
    assign signal_select_544 = sample[23:23];
    assign signal_select_545 = sample[22:22];
    assign signal_select_546 = sample[21:21];
    assign signal_select_547 = sample[20:20];
    assign signal_select_548 = sample[19:19];
    assign signal_select_549 = sample[18:18];
    assign signal_select_550 = sample[17:17];
    assign signal_select_551 = sample[16:16];
    assign signal_select_552 = sample[15:15];
    assign signal_select_553 = sample[14:14];
    assign signal_select_554 = sample[13:13];
    assign signal_select_555 = sample[12:12];
    assign signal_select_556 = sample[11:11];
    assign signal_select_557 = sample[10:10];
    assign signal_select_558 = sample[9:9];
    assign signal_select_559 = sample[8:8];
    assign signal_select_560 = sample[7:7];
    assign signal_select_561 = sample[6:6];
    assign signal_select_562 = sample[5:5];
    assign signal_select_563 = sample[4:4];
    assign signal_select_564 = sample[3:3];
    assign signal_select_565 = sample[2:2];
    assign signal_select_566 = sample[1:1];
    assign signal_select_567 = sample[0:0];
    assign signal_wire_20 = config$capture_pin;
    always @* begin
        case (signal_wire_20)
        0:
            signal_mux_187 <= signal_select_567;
        1:
            signal_mux_187 <= signal_select_566;
        2:
            signal_mux_187 <= signal_select_565;
        3:
            signal_mux_187 <= signal_select_564;
        4:
            signal_mux_187 <= signal_select_563;
        5:
            signal_mux_187 <= signal_select_562;
        6:
            signal_mux_187 <= signal_select_561;
        7:
            signal_mux_187 <= signal_select_560;
        8:
            signal_mux_187 <= signal_select_559;
        9:
            signal_mux_187 <= signal_select_558;
        10:
            signal_mux_187 <= signal_select_557;
        11:
            signal_mux_187 <= signal_select_556;
        12:
            signal_mux_187 <= signal_select_555;
        13:
            signal_mux_187 <= signal_select_554;
        14:
            signal_mux_187 <= signal_select_553;
        15:
            signal_mux_187 <= signal_select_552;
        16:
            signal_mux_187 <= signal_select_551;
        17:
            signal_mux_187 <= signal_select_550;
        18:
            signal_mux_187 <= signal_select_549;
        19:
            signal_mux_187 <= signal_select_548;
        20:
            signal_mux_187 <= signal_select_547;
        21:
            signal_mux_187 <= signal_select_546;
        22:
            signal_mux_187 <= signal_select_545;
        23:
            signal_mux_187 <= signal_select_544;
        24:
            signal_mux_187 <= signal_select_543;
        25:
            signal_mux_187 <= signal_select_542;
        26:
            signal_mux_187 <= signal_select_541;
        default:
            signal_mux_187 <= signal_select_540;
        endcase
    end
    assign signal_eq_43 = signal_mux_187 == signal_mux_186;
    assign signal_not_50 = ~ signal_eq_43;
    assign signal_const_192 = 4'b0111;
    assign signal_eq_44 = d$sys_op$binary_variant == signal_const_192;
    assign signal_and_123 = is_opcode$7 & signal_eq_44;
    assign signal_and_124 = op_go & signal_and_123;
    assign signal_mux_188 = signal_and_124 ? vdd : capture_armed_0;
    assign signal_mux_189 = captured ? gnd : signal_mux_188;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_15 <= signal_const_3;
        else
            signal_reg_15 <= signal_mux_189;
    end
    assign capture_armed_0 = signal_reg_15;
    assign signal_and_125 = capture_armed_0 & signal_not_50;
    assign captured = signal_and_125 & signal_eq_42;
    assign signal_const_196 = 24'b000000000000000000000001;
    assign signal_add_6 = now_0 + signal_const_196;
    assign signal_mux_190 = start_0 ? signal_const_4 : signal_add_6;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_16 <= signal_const_4;
        else
            signal_reg_16 <= signal_mux_190;
    end
    assign now_0 = signal_reg_16;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_17 <= signal_const_4;
        else
            if (captured)
                signal_reg_17 <= now_0;
    end
    assign capture_0 = signal_reg_17;
    assign signal_select_568 = capture_0[15:0];
    assign signal_wire_21 = config$crc_init;
    assign signal_select_569 = signal_mux_193[7:0];
    assign signal_cat_151 = { signal_select_569,
                              signal_const_18 };
    assign signal_select_570 = signal_mux_192[11:0];
    assign signal_cat_152 = { signal_select_570,
                              signal_const_19 };
    assign signal_select_571 = signal_mux_191[13:0];
    assign signal_cat_153 = { signal_select_571,
                              signal_const_20 };
    assign signal_select_572 = signal_wire_23[0:0];
    assign signal_mux_191 = signal_select_572 ? signal_const_21 : signal_const_22;
    assign signal_select_573 = signal_wire_23[1:1];
    assign signal_mux_192 = signal_select_573 ? signal_cat_153 : signal_mux_191;
    assign signal_select_574 = signal_wire_23[2:2];
    assign signal_mux_193 = signal_select_574 ? signal_cat_152 : signal_mux_192;
    assign signal_select_575 = signal_wire_23[3:3];
    assign signal_mux_194 = signal_select_575 ? signal_cat_151 : signal_mux_193;
    assign signal_select_576 = signal_wire_23[4:4];
    assign signal_mux_195 = signal_select_576 ? signal_const_17 : signal_mux_194;
    assign signal_not_51 = ~ signal_mux_195;
    assign signal_xor_2 = signal_cat_154 ^ signal_wire_22;
    assign signal_select_577 = crc_0[15:1];
    assign signal_cat_154 = { signal_const_3,
                              signal_select_577 };
    assign signal_select_578 = crc_0[0:0];
    assign signal_xor_3 = signal_select_578 ^ crossing_bit;
    assign signal_mux_196 = signal_xor_3 ? signal_xor_2 : signal_cat_154;
    assign signal_wire_22 = config$crc_poly;
    assign signal_xor_4 = signal_cat_155 ^ signal_wire_22;
    assign signal_select_579 = crc_0[14:0];
    assign signal_cat_155 = { signal_select_579,
                              signal_const_3 };
    assign signal_select_580 = in_value[0:0];
    assign signal_select_581 = out_value[0:0];
    assign crossing_bit = is_opcode$2 ? signal_select_580 : signal_select_581;
    assign signal_select_582 = crc_0[15:15];
    assign signal_select_583 = crc_0[14:14];
    assign signal_select_584 = crc_0[13:13];
    assign signal_select_585 = crc_0[12:12];
    assign signal_select_586 = crc_0[11:11];
    assign signal_select_587 = crc_0[10:10];
    assign signal_select_588 = crc_0[9:9];
    assign signal_select_589 = crc_0[8:8];
    assign signal_select_590 = crc_0[7:7];
    assign signal_select_591 = crc_0[6:6];
    assign signal_select_592 = crc_0[5:5];
    assign signal_select_593 = crc_0[4:4];
    assign signal_select_594 = crc_0[3:3];
    assign signal_select_595 = crc_0[2:2];
    assign signal_select_596 = crc_0[1:1];
    assign signal_select_597 = crc_0[0:0];
    assign signal_wire_23 = config$crc_width;
    assign signal_sub_6 = signal_wire_23 - signal_const_67;
    always @* begin
        case (signal_sub_6)
        0:
            signal_mux_197 <= signal_select_597;
        1:
            signal_mux_197 <= signal_select_596;
        2:
            signal_mux_197 <= signal_select_595;
        3:
            signal_mux_197 <= signal_select_594;
        4:
            signal_mux_197 <= signal_select_593;
        5:
            signal_mux_197 <= signal_select_592;
        6:
            signal_mux_197 <= signal_select_591;
        7:
            signal_mux_197 <= signal_select_590;
        8:
            signal_mux_197 <= signal_select_589;
        9:
            signal_mux_197 <= signal_select_588;
        10:
            signal_mux_197 <= signal_select_587;
        11:
            signal_mux_197 <= signal_select_586;
        12:
            signal_mux_197 <= signal_select_585;
        13:
            signal_mux_197 <= signal_select_584;
        14:
            signal_mux_197 <= signal_select_583;
        default:
            signal_mux_197 <= signal_select_582;
        endcase
    end
    assign signal_xor_5 = signal_mux_197 ^ crossing_bit;
    assign signal_mux_198 = signal_xor_5 ? signal_xor_4 : signal_cat_155;
    assign signal_wire_24 = config$crc_reflect;
    assign signal_mux_199 = signal_wire_24 ? signal_mux_196 : signal_mux_198;
    assign crc_stepped = signal_mux_199 & signal_not_51;
    assign signal_const_207 = 3'b010;
    assign signal_eq_45 = signal_select_769 == signal_const_207;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            is_opcode$2 <= gnd;
        else
            if (ir_load)
                is_opcode$2 <= signal_eq_45;
    end
    assign signal_or_13 = is_opcode$2 | is_opcode$3;
    assign signal_eq_46 = d$shift_count == signal_const_67;
    assign bit_crosses = signal_eq_46 & signal_or_13;
    assign signal_mux_200 = bit_crosses ? crc_stepped : crc_0;
    assign signal_const_209 = 4'b0101;
    assign signal_eq_47 = d$sys_op$binary_variant == signal_const_209;
    assign signal_and_126 = is_opcode$7 & signal_eq_47;
    assign crc_next = signal_and_126 ? signal_wire_21 : signal_mux_200;
    assign signal_mux_201 = go ? crc_next : crc_0;
    assign signal_mux_202 = start_0 ? signal_wire_21 : signal_mux_201;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_18 <= signal_const_17;
        else
            signal_reg_18 <= signal_mux_202;
    end
    assign crc_0 = signal_reg_18;
    assign signal_select_598 = signal_mux_205[7:0];
    assign signal_cat_156 = { signal_select_598,
                              signal_const_18 };
    assign signal_select_599 = signal_mux_204[11:0];
    assign signal_cat_157 = { signal_select_599,
                              signal_const_19 };
    assign signal_select_600 = signal_mux_203[13:0];
    assign signal_cat_158 = { signal_select_600,
                              signal_const_20 };
    assign signal_select_601 = d$shift_count[0:0];
    assign signal_mux_203 = signal_select_601 ? signal_const_21 : signal_const_22;
    assign signal_select_602 = d$shift_count[1:1];
    assign signal_mux_204 = signal_select_602 ? signal_cat_158 : signal_mux_203;
    assign signal_select_603 = d$shift_count[2:2];
    assign signal_mux_205 = signal_select_603 ? signal_cat_157 : signal_mux_204;
    assign signal_select_604 = d$shift_count[3:3];
    assign signal_mux_206 = signal_select_604 ? signal_cat_156 : signal_mux_205;
    assign signal_select_605 = d$shift_count[4:4];
    assign signal_mux_207 = signal_select_605 ? signal_const_17 : signal_mux_206;
    assign signal_not_52 = ~ signal_mux_207;
    assign signal_select_606 = signal_mux_211[27:16];
    assign signal_select_607 = signal_mux_211[15:0];
    assign signal_cat_159 = { signal_select_607,
                              signal_select_606 };
    assign signal_select_608 = signal_mux_210[27:8];
    assign signal_select_609 = signal_mux_210[7:0];
    assign signal_cat_160 = { signal_select_609,
                              signal_select_608 };
    assign signal_select_610 = signal_mux_209[27:4];
    assign signal_select_611 = signal_mux_209[3:0];
    assign signal_cat_161 = { signal_select_611,
                              signal_select_610 };
    assign signal_select_612 = signal_mux_208[27:2];
    assign signal_select_613 = signal_mux_208[1:0];
    assign signal_cat_162 = { signal_select_613,
                              signal_select_612 };
    assign signal_select_614 = sample[27:1];
    assign signal_select_615 = sample[0:0];
    assign signal_cat_163 = { signal_select_615,
                              signal_select_614 };
    assign signal_select_616 = signal_wire_29[0:0];
    assign signal_mux_208 = signal_select_616 ? signal_cat_163 : sample;
    assign signal_select_617 = signal_wire_29[1:1];
    assign signal_mux_209 = signal_select_617 ? signal_cat_162 : signal_mux_208;
    assign signal_select_618 = signal_wire_29[2:2];
    assign signal_mux_210 = signal_select_618 ? signal_cat_161 : signal_mux_209;
    assign signal_select_619 = signal_wire_29[3:3];
    assign signal_mux_211 = signal_select_619 ? signal_cat_160 : signal_mux_210;
    assign signal_select_620 = signal_wire_29[4:4];
    assign signal_mux_212 = signal_select_620 ? signal_cat_159 : signal_mux_211;
    assign signal_select_621 = signal_mux_212[15:0];
    assign signal_and_127 = signal_select_621 & signal_not_52;
    always @* begin
        case (d$out_dest$binary_variant)
        0:
            signal_mux_213 <= signal_and_127;
        1:
            signal_mux_213 <= x_0;
        2:
            signal_mux_213 <= y_0;
        3:
            signal_mux_213 <= signal_const_17;
        4:
            signal_mux_213 <= isr_0;
        5:
            signal_mux_213 <= osr_0;
        6:
            signal_mux_213 <= crc_0;
        default:
            signal_mux_213 <= signal_select_568;
        endcase
    end
    assign in_value = signal_mux_213 & mask;
    assign signal_select_622 = signal_mux_216[7:0];
    assign signal_cat_164 = { signal_select_622,
                              signal_const_18 };
    assign signal_select_623 = signal_mux_215[11:0];
    assign signal_cat_165 = { signal_select_623,
                              signal_const_19 };
    assign signal_select_624 = signal_mux_214[13:0];
    assign signal_cat_166 = { signal_select_624,
                              signal_const_20 };
    assign signal_select_625 = isr_0[14:0];
    assign signal_cat_167 = { signal_select_625,
                              signal_const_3 };
    assign signal_select_626 = d$shift_count[0:0];
    assign signal_mux_214 = signal_select_626 ? signal_cat_167 : isr_0;
    assign signal_select_627 = d$shift_count[1:1];
    assign signal_mux_215 = signal_select_627 ? signal_cat_166 : signal_mux_214;
    assign signal_select_628 = d$shift_count[2:2];
    assign signal_mux_216 = signal_select_628 ? signal_cat_165 : signal_mux_215;
    assign signal_select_629 = d$shift_count[3:3];
    assign signal_mux_217 = signal_select_629 ? signal_cat_164 : signal_mux_216;
    assign signal_select_630 = d$shift_count[4:4];
    assign signal_mux_218 = signal_select_630 ? signal_const_17 : signal_mux_217;
    assign signal_or_14 = signal_mux_218 | in_value;
    assign signal_wire_25 = config$in_shift_right;
    assign isr_shifted = signal_wire_25 ? signal_or_12 : signal_or_14;
    assign signal_wire_26 = config$push_threshold;
    assign signal_select_631 = signal_add_7[4:0];
    assign signal_cat_168 = { gnd,
                              d$shift_count };
    assign signal_eq_48 = d$sys_op$binary_variant == signal_const_114;
    assign signal_and_128 = is_opcode$7 & signal_eq_48;
    assign signal_mux_219 = signal_and_128 ? osr_count_zero : isr_count_0;
    assign signal_eq_49 = d$mov_dest$binary_variant == signal_const;
    assign signal_mux_220 = signal_eq_49 ? osr_count_zero : isr_count_0;
    assign signal_eq_50 = d$out_dest$binary_variant == signal_const_1;
    assign signal_mux_221 = signal_eq_50 ? d$shift_count : isr_count_0;
    assign signal_mux_222 = autopush_now ? osr_count_zero : isr_count_next;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_count_next_value <= isr_count_0;
        1:
            isr_count_next_value <= isr_count_0;
        2:
            isr_count_next_value <= signal_mux_222;
        3:
            isr_count_next_value <= signal_mux_221;
        4:
            isr_count_next_value <= signal_mux_220;
        5:
            isr_count_next_value <= isr_count_0;
        6:
            isr_count_next_value <= isr_count_0;
        default:
            isr_count_next_value <= signal_mux_219;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_19 <= signal_const_69;
        else
            if (go)
                signal_reg_19 <= isr_count_next_value;
    end
    assign isr_count_0 = signal_reg_19;
    assign signal_cat_169 = { gnd,
                              isr_count_0 };
    assign signal_add_7 = signal_cat_169 + signal_cat_168;
    assign signal_const_227 = 6'b010000;
    assign signal_lt_12 = signal_const_227 < signal_add_7;
    assign isr_count_next = signal_lt_12 ? signal_const_87 : signal_select_631;
    assign signal_lt_13 = isr_count_next < signal_wire_26;
    assign signal_not_53 = ~ signal_lt_13;
    assign signal_wire_27 = config$autopush;
    assign autopush_now = signal_wire_27 & signal_not_53;
    assign signal_mux_223 = autopush_now ? signal_const_17 : isr_shifted;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_next <= isr_0;
        1:
            isr_next <= isr_0;
        2:
            isr_next <= signal_mux_223;
        3:
            isr_next <= signal_mux_169;
        4:
            isr_next <= signal_mux_168;
        5:
            isr_next <= isr_0;
        6:
            isr_next <= isr_0;
        default:
            isr_next <= signal_mux_167;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_20 <= signal_const_17;
        else
            if (go)
                signal_reg_20 <= isr_next;
    end
    assign isr_0 = signal_reg_20;
    assign signal_xor_6 = p_0 ^ alu_operand;
    assign signal_sub_7 = p_0 - alu_operand;
    assign signal_add_8 = p_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_224 <= signal_add_8;
        1:
            signal_mux_224 <= signal_sub_7;
        default:
            signal_mux_224 <= signal_xor_6;
        endcase
    end
    assign signal_eq_51 = d$alu_dest$binary_variant == signal_const_130;
    assign signal_mux_225 = signal_eq_51 ? signal_mux_224 : p_0;
    assign signal_cat_170 = { signal_const_14,
                              d$set_value };
    assign signal_eq_52 = d$set_dest$binary_variant == signal_const;
    assign signal_mux_226 = signal_eq_52 ? signal_cat_170 : p_0;
    assign signal_eq_53 = d$mov_dest$binary_variant == signal_const_2;
    assign signal_mux_227 = signal_eq_53 ? mov_value : p_0;
    assign signal_eq_54 = d$out_dest$binary_variant == signal_const_2;
    assign signal_mux_228 = signal_eq_54 ? out_value : p_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            p_next <= p_0;
        1:
            p_next <= p_0;
        2:
            p_next <= p_0;
        3:
            p_next <= signal_mux_228;
        4:
            p_next <= signal_mux_227;
        5:
            p_next <= signal_mux_226;
        6:
            p_next <= signal_mux_225;
        default:
            p_next <= p_0;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_21 <= signal_const_17;
        else
            if (go)
                signal_reg_21 <= p_next;
    end
    assign p_0 = signal_reg_21;
    assign signal_xor_7 = y_0 ^ alu_operand;
    assign signal_sub_8 = y_0 - alu_operand;
    assign signal_add_9 = y_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_229 <= signal_add_9;
        1:
            signal_mux_229 <= signal_sub_8;
        default:
            signal_mux_229 <= signal_xor_7;
        endcase
    end
    assign signal_const_235 = 2'b01;
    assign signal_eq_55 = d$alu_dest$binary_variant == signal_const_235;
    assign signal_mux_230 = signal_eq_55 ? signal_mux_229 : y_0;
    assign signal_cat_171 = { signal_const_14,
                              d$set_value };
    assign signal_eq_56 = d$set_dest$binary_variant == signal_const_207;
    assign signal_mux_231 = signal_eq_56 ? signal_cat_171 : y_0;
    assign signal_eq_57 = d$mov_dest$binary_variant == signal_const_207;
    assign signal_mux_232 = signal_eq_57 ? mov_value : y_0;
    assign signal_eq_58 = d$out_dest$binary_variant == signal_const_207;
    assign signal_mux_233 = signal_eq_58 ? out_value : y_0;
    assign signal_const_240 = 16'b0000000000000001;
    assign signal_sub_9 = y_0 - signal_const_240;
    assign signal_eq_59 = d$jmp_cond$binary_variant == signal_const_9;
    assign signal_mux_234 = signal_eq_59 ? signal_sub_9 : y_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            y_next <= signal_mux_234;
        1:
            y_next <= y_0;
        2:
            y_next <= y_0;
        3:
            y_next <= signal_mux_233;
        4:
            y_next <= signal_mux_232;
        5:
            y_next <= signal_mux_231;
        6:
            y_next <= signal_mux_230;
        default:
            y_next <= y_0;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_22 <= signal_const_17;
        else
            if (go)
                signal_reg_22 <= y_next;
    end
    assign y_0 = signal_reg_22;
    always @* begin
        case (d$alu_reg$binary_variant)
        0:
            signal_mux_235 <= x_0;
        1:
            signal_mux_235 <= y_0;
        2:
            signal_mux_235 <= p_0;
        3:
            signal_mux_235 <= isr_0;
        default:
            signal_mux_235 <= osr_0;
        endcase
    end
    assign d$alu_reg$binary_variant = word[2:0];
    assign signal_const_242 = 13'b0000000000000;
    assign signal_cat_172 = { signal_const_242,
                              d$alu_reg$binary_variant };
    assign d$alu_is_reg = word[3:3];
    assign alu_operand = d$alu_is_reg ? signal_mux_235 : signal_cat_172;
    assign signal_add_10 = x_0 + alu_operand;
    assign d$alu_op$binary_variant = word[5:4];
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_236 <= signal_add_10;
        1:
            signal_mux_236 <= signal_sub_5;
        default:
            signal_mux_236 <= signal_xor_1;
        endcase
    end
    assign d$alu_dest$binary_variant = word[7:6];
    assign signal_eq_60 = d$alu_dest$binary_variant == signal_const_20;
    assign signal_mux_237 = signal_eq_60 ? signal_mux_236 : x_0;
    assign d$set_value = word[4:0];
    assign signal_cat_173 = { signal_const_14,
                              d$set_value };
    assign signal_const_245 = 3'b001;
    assign d$set_dest$binary_variant = word[7:5];
    assign signal_eq_61 = d$set_dest$binary_variant == signal_const_245;
    assign signal_mux_238 = signal_eq_61 ? signal_cat_173 : x_0;
    assign signal_eq_62 = d$mov_dest$binary_variant == signal_const_245;
    assign signal_mux_239 = signal_eq_62 ? mov_value : x_0;
    assign signal_eq_63 = d$out_dest$binary_variant == signal_const_245;
    assign signal_mux_240 = signal_eq_63 ? out_value : x_0;
    assign signal_sub_10 = x_0 - signal_const_240;
    assign d$jmp_cond$binary_variant = word[12:9];
    assign signal_eq_64 = d$jmp_cond$binary_variant == signal_const_78;
    assign signal_mux_241 = signal_eq_64 ? signal_sub_10 : x_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            x_next <= signal_mux_241;
        1:
            x_next <= x_0;
        2:
            x_next <= x_0;
        3:
            x_next <= signal_mux_240;
        4:
            x_next <= signal_mux_239;
        5:
            x_next <= signal_mux_238;
        6:
            x_next <= signal_mux_237;
        default:
            x_next <= x_0;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_23 <= signal_const_17;
        else
            if (go)
                signal_reg_23 <= x_next;
    end
    assign x_0 = signal_reg_23;
    assign signal_cat_174 = { signal_const_18,
                              x_0 };
    assign signal_select_632 = signal_mux_244[7:0];
    assign signal_cat_175 = { signal_select_632,
                              signal_const_18 };
    assign signal_select_633 = signal_mux_243[11:0];
    assign signal_cat_176 = { signal_select_633,
                              signal_const_19 };
    assign signal_select_634 = signal_mux_242[13:0];
    assign signal_cat_177 = { signal_select_634,
                              signal_const_20 };
    assign signal_select_635 = signal_wire_28[0:0];
    assign signal_mux_242 = signal_select_635 ? signal_const_21 : signal_const_22;
    assign signal_select_636 = signal_wire_28[1:1];
    assign signal_mux_243 = signal_select_636 ? signal_cat_177 : signal_mux_242;
    assign signal_select_637 = signal_wire_28[2:2];
    assign signal_mux_244 = signal_select_637 ? signal_cat_176 : signal_mux_243;
    assign signal_select_638 = signal_wire_28[3:3];
    assign signal_mux_245 = signal_select_638 ? signal_cat_175 : signal_mux_244;
    assign signal_wire_28 = config$in_count;
    assign signal_select_639 = signal_wire_28[4:4];
    assign signal_mux_246 = signal_select_639 ? signal_const_17 : signal_mux_245;
    assign signal_not_54 = ~ signal_mux_246;
    assign signal_select_640 = signal_mux_250[27:16];
    assign signal_select_641 = signal_mux_250[15:0];
    assign signal_cat_178 = { signal_select_641,
                              signal_select_640 };
    assign signal_select_642 = signal_mux_249[27:8];
    assign signal_select_643 = signal_mux_249[7:0];
    assign signal_cat_179 = { signal_select_643,
                              signal_select_642 };
    assign signal_select_644 = signal_mux_248[27:4];
    assign signal_select_645 = signal_mux_248[3:0];
    assign signal_cat_180 = { signal_select_645,
                              signal_select_644 };
    assign signal_select_646 = signal_mux_247[27:2];
    assign signal_select_647 = signal_mux_247[1:0];
    assign signal_cat_181 = { signal_select_647,
                              signal_select_646 };
    assign signal_select_648 = sample[27:1];
    assign signal_select_649 = sample[0:0];
    assign signal_cat_182 = { signal_select_649,
                              signal_select_648 };
    assign signal_select_650 = signal_wire_29[0:0];
    assign signal_mux_247 = signal_select_650 ? signal_cat_182 : sample;
    assign signal_select_651 = signal_wire_29[1:1];
    assign signal_mux_248 = signal_select_651 ? signal_cat_181 : signal_mux_247;
    assign signal_select_652 = signal_wire_29[2:2];
    assign signal_mux_249 = signal_select_652 ? signal_cat_180 : signal_mux_248;
    assign signal_select_653 = signal_wire_29[3:3];
    assign signal_mux_250 = signal_select_653 ? signal_cat_179 : signal_mux_249;
    assign signal_wire_29 = config$in_base;
    assign signal_select_654 = signal_wire_29[4:4];
    assign signal_mux_251 = signal_select_654 ? signal_cat_178 : signal_mux_250;
    assign signal_select_655 = signal_mux_251[15:0];
    assign signal_and_129 = signal_select_655 & signal_not_54;
    assign signal_cat_183 = { signal_const_18,
                              signal_and_129 };
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
            mov_value24 <= signal_const_4;
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
    assign signal_select_656 = mov_value24[15:0];
    assign d$mov_op$binary_variant = word[4:3];
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value <= signal_select_656;
        1:
            mov_value <= signal_not_49;
        default:
            mov_value <= signal_cat_136;
        endcase
    end
    assign signal_eq_65 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_252 = signal_eq_65 ? mov_value : osr_0;
    assign signal_select_657 = signal_mux_255[15:8];
    assign signal_cat_184 = { signal_const_18,
                              signal_select_657 };
    assign signal_select_658 = signal_mux_254[15:4];
    assign signal_cat_185 = { signal_const_19,
                              signal_select_658 };
    assign signal_select_659 = signal_mux_253[15:2];
    assign signal_cat_186 = { signal_const_20,
                              signal_select_659 };
    assign signal_select_660 = osr_before[15:1];
    assign signal_cat_187 = { signal_const_3,
                              signal_select_660 };
    assign signal_select_661 = d$shift_count[0:0];
    assign signal_mux_253 = signal_select_661 ? signal_cat_187 : osr_before;
    assign signal_select_662 = d$shift_count[1:1];
    assign signal_mux_254 = signal_select_662 ? signal_cat_186 : signal_mux_253;
    assign signal_select_663 = d$shift_count[2:2];
    assign signal_mux_255 = signal_select_663 ? signal_cat_185 : signal_mux_254;
    assign signal_select_664 = d$shift_count[3:3];
    assign signal_mux_256 = signal_select_664 ? signal_cat_184 : signal_mux_255;
    assign signal_select_665 = d$shift_count[4:4];
    assign signal_mux_257 = signal_select_665 ? signal_const_17 : signal_mux_256;
    assign signal_select_666 = signal_mux_260[7:0];
    assign signal_cat_188 = { signal_select_666,
                              signal_const_18 };
    assign signal_select_667 = signal_mux_259[11:0];
    assign signal_cat_189 = { signal_select_667,
                              signal_const_19 };
    assign signal_select_668 = signal_mux_258[13:0];
    assign signal_cat_190 = { signal_select_668,
                              signal_const_20 };
    assign signal_select_669 = osr_before[14:0];
    assign signal_cat_191 = { signal_select_669,
                              signal_const_3 };
    assign signal_select_670 = d$shift_count[0:0];
    assign signal_mux_258 = signal_select_670 ? signal_cat_191 : osr_before;
    assign signal_select_671 = d$shift_count[1:1];
    assign signal_mux_259 = signal_select_671 ? signal_cat_190 : signal_mux_258;
    assign signal_select_672 = d$shift_count[2:2];
    assign signal_mux_260 = signal_select_672 ? signal_cat_189 : signal_mux_259;
    assign signal_select_673 = d$shift_count[3:3];
    assign signal_mux_261 = signal_select_673 ? signal_cat_188 : signal_mux_260;
    assign signal_select_674 = d$shift_count[4:4];
    assign signal_mux_262 = signal_select_674 ? signal_const_17 : signal_mux_261;
    assign osr_shifted = signal_wire_36 ? signal_mux_257 : signal_mux_262;
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
            osr_next <= signal_mux_252;
        5:
            osr_next <= osr_0;
        6:
            osr_next <= osr_0;
        default:
            osr_next <= signal_mux_166;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_24 <= signal_const_17;
        else
            if (go)
                signal_reg_24 <= osr_next;
    end
    assign osr_0 = signal_reg_24;
    assign signal_wire_30 = flush;
    assign flush_0 = signal_wire_30 & halted_0;
    assign signal_not_55 = ~ signal_select_675;
    assign signal_and_130 = pulls & signal_not_55;
    assign signal_and_131 = is_opcode$3 & pull_ok;
    assign signal_or_15 = signal_and_131 | signal_and_130;
    assign signal_and_132 = op_go & signal_or_15;
    assign tx_pop = signal_and_132;
    assign signal_wire_31 = tx$value;
    assign signal_wire_32 = tx$valid;
    host_fifo
        tx
        ( .clock(signal_wire_49),
          .clear(signal_wire_48),
          .push$valid(signal_wire_32),
          .push$value(signal_wire_31),
          .pop(tx_pop),
          .flush(flush_0),
          .head(signal_inst_1[15:0]),
          .level(signal_inst_1[19:16]),
          .empty(signal_inst_1[20:20]),
          .full(signal_inst_1[21:21]) );
    assign signal_select_675 = signal_inst_1[20:20];
    assign signal_not_56 = ~ signal_select_675;
    assign signal_not_57 = ~ signal_wire_33;
    assign pull_fifo = pull_now & signal_not_57;
    assign pull_ok = pull_fifo & signal_not_56;
    assign signal_mux_263 = pull_ok ? signal_select_441 : osr_0;
    assign signal_eq_66 = signal_select_769 == signal_const_146;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            is_opcode$3 <= gnd;
        else
            if (ir_load)
                is_opcode$3 <= signal_eq_66;
    end
    assign signal_and_133 = op_go & is_opcode$3;
    assign pulls_data = signal_and_133 & pull_data_ok;
    assign signal_const_271 = 4'b1000;
    assign signal_eq_67 = d$sys_op$binary_variant == signal_const_271;
    assign signal_and_134 = is_opcode$7 & signal_eq_67;
    assign seeks = op_go & signal_and_134;
    assign signal_or_16 = seeks | pulls_data;
    assign signal_mux_264 = start_0 ? gnd : signal_or_16;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_25 <= signal_const_3;
        else
            signal_reg_25 <= signal_mux_264;
    end
    assign data_moved = signal_reg_25;
    assign signal_not_58 = ~ data_moved;
    assign signal_wire_33 = config$autopull_data;
    assign signal_wire_34 = config$pull_threshold;
    assign signal_const_273 = 4'b0100;
    assign d$sys_op$binary_variant = word[3:0];
    assign signal_eq_68 = d$sys_op$binary_variant == signal_const_273;
    assign signal_eq_69 = signal_select_769 == signal_const_118;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            is_opcode$7 <= gnd;
        else
            if (ir_load)
                is_opcode$7 <= signal_eq_69;
    end
    assign pulls = is_opcode$7 & signal_eq_68;
    assign signal_mux_265 = pulls ? osr_count_zero : osr_count_0;
    assign osr_count_zero = 5'b00000;
    assign d$mov_dest$binary_variant = word[7:5];
    assign signal_eq_70 = d$mov_dest$binary_variant == signal_const_1;
    assign signal_mux_266 = signal_eq_70 ? osr_count_zero : osr_count_0;
    assign signal_select_676 = signal_add_11[4:0];
    assign signal_cat_192 = { gnd,
                              d$shift_count };
    assign osr_count_before = pull_now ? signal_const_69 : osr_count_0;
    assign signal_cat_193 = { gnd,
                              osr_count_before };
    assign signal_add_11 = signal_cat_193 + signal_cat_192;
    assign signal_lt_14 = signal_const_227 < signal_add_11;
    assign osr_count_next = signal_lt_14 ? signal_const_87 : signal_select_676;
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
            osr_count_next_value <= signal_mux_266;
        5:
            osr_count_next_value <= osr_count_0;
        6:
            osr_count_next_value <= osr_count_0;
        default:
            osr_count_next_value <= signal_mux_265;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_26 <= signal_const_87;
        else
            if (go)
                signal_reg_26 <= osr_count_next_value;
    end
    assign osr_count_0 = signal_reg_26;
    assign signal_lt_15 = osr_count_0 < signal_wire_34;
    assign signal_not_59 = ~ signal_lt_15;
    assign signal_wire_35 = config$autopull;
    assign pull_now = signal_wire_35 & signal_not_59;
    assign pull_data = pull_now & signal_wire_33;
    assign pull_data_ok = pull_data & signal_not_58;
    assign osr_before = pull_data_ok ? signal_wire_18 : signal_mux_263;
    assign signal_select_677 = shift_back[0:0];
    assign signal_mux_267 = signal_select_677 ? signal_cat_135 : osr_before;
    assign signal_select_678 = shift_back[1:1];
    assign signal_mux_268 = signal_select_678 ? signal_cat_134 : signal_mux_267;
    assign signal_select_679 = shift_back[2:2];
    assign signal_mux_269 = signal_select_679 ? signal_cat_133 : signal_mux_268;
    assign signal_select_680 = shift_back[3:3];
    assign signal_mux_270 = signal_select_680 ? signal_cat_132 : signal_mux_269;
    assign shift_back = signal_const_87 - d$shift_count;
    assign signal_select_681 = shift_back[4:4];
    assign signal_mux_271 = signal_select_681 ? signal_const_17 : signal_mux_270;
    assign signal_and_135 = signal_mux_271 & mask;
    assign signal_wire_36 = config$out_shift_right;
    assign out_value = signal_wire_36 ? signal_and_120 : signal_and_135;
    assign signal_cat_194 = { signal_const_15,
                              out_value };
    assign signal_select_682 = signal_wire_37[0:0];
    assign signal_mux_272 = signal_select_682 ? signal_cat_131 : signal_cat_194;
    assign signal_select_683 = signal_wire_37[1:1];
    assign signal_mux_273 = signal_select_683 ? signal_cat_130 : signal_mux_272;
    assign signal_select_684 = signal_wire_37[2:2];
    assign signal_mux_274 = signal_select_684 ? signal_cat_129 : signal_mux_273;
    assign signal_select_685 = signal_wire_37[3:3];
    assign signal_mux_275 = signal_select_685 ? signal_cat_128 : signal_mux_274;
    assign signal_select_686 = signal_wire_37[4:4];
    assign signal_mux_276 = signal_select_686 ? signal_cat_127 : signal_mux_275;
    assign signal_and_136 = signal_mux_276 & signal_and_137;
    assign signal_select_687 = signal_mux_285[27:12];
    assign signal_select_688 = signal_mux_285[11:0];
    assign signal_cat_195 = { signal_select_688,
                              signal_select_687 };
    assign signal_select_689 = signal_mux_284[27:20];
    assign signal_select_690 = signal_mux_284[19:0];
    assign signal_cat_196 = { signal_select_690,
                              signal_select_689 };
    assign signal_select_691 = signal_mux_283[27:24];
    assign signal_select_692 = signal_mux_283[23:0];
    assign signal_cat_197 = { signal_select_692,
                              signal_select_691 };
    assign signal_select_693 = signal_mux_282[27:26];
    assign signal_select_694 = signal_mux_282[25:0];
    assign signal_cat_198 = { signal_select_694,
                              signal_select_693 };
    assign signal_select_695 = signal_cat_203[27:27];
    assign signal_select_696 = signal_cat_203[26:0];
    assign signal_cat_199 = { signal_select_696,
                              signal_select_695 };
    assign signal_select_697 = signal_mux_279[7:0];
    assign signal_cat_200 = { signal_select_697,
                              signal_const_18 };
    assign signal_select_698 = signal_mux_278[11:0];
    assign signal_cat_201 = { signal_select_698,
                              signal_const_19 };
    assign signal_select_699 = signal_mux_277[13:0];
    assign signal_cat_202 = { signal_select_699,
                              signal_const_20 };
    assign signal_select_700 = d$shift_count[0:0];
    assign signal_mux_277 = signal_select_700 ? signal_const_21 : signal_const_22;
    assign signal_select_701 = d$shift_count[1:1];
    assign signal_mux_278 = signal_select_701 ? signal_cat_202 : signal_mux_277;
    assign signal_select_702 = d$shift_count[2:2];
    assign signal_mux_279 = signal_select_702 ? signal_cat_201 : signal_mux_278;
    assign signal_select_703 = d$shift_count[3:3];
    assign signal_mux_280 = signal_select_703 ? signal_cat_200 : signal_mux_279;
    assign d$shift_count = word[4:0];
    assign signal_select_704 = d$shift_count[4:4];
    assign signal_mux_281 = signal_select_704 ? signal_const_17 : signal_mux_280;
    assign signal_not_60 = ~ signal_mux_281;
    assign signal_cat_203 = { signal_const_15,
                              signal_not_60 };
    assign signal_select_705 = signal_wire_37[0:0];
    assign signal_mux_282 = signal_select_705 ? signal_cat_199 : signal_cat_203;
    assign signal_select_706 = signal_wire_37[1:1];
    assign signal_mux_283 = signal_select_706 ? signal_cat_198 : signal_mux_282;
    assign signal_select_707 = signal_wire_37[2:2];
    assign signal_mux_284 = signal_select_707 ? signal_cat_197 : signal_mux_283;
    assign signal_select_708 = signal_wire_37[3:3];
    assign signal_mux_285 = signal_select_708 ? signal_cat_196 : signal_mux_284;
    assign signal_wire_37 = config$out_base;
    assign signal_select_709 = signal_wire_37[4:4];
    assign signal_mux_286 = signal_select_709 ? signal_cat_195 : signal_mux_285;
    assign signal_and_137 = signal_mux_286 & signal_const_137;
    assign signal_not_61 = ~ signal_and_137;
    assign signal_and_138 = pin_dir_base & signal_not_61;
    assign signal_or_17 = signal_and_138 | signal_and_136;
    assign d$out_dest$binary_variant = word[7:5];
    assign signal_eq_71 = d$out_dest$binary_variant == signal_const;
    assign signal_mux_287 = signal_eq_71 ? signal_or_17 : pin_dir_base;
    assign signal_select_710 = signal_mux_291[27:12];
    assign signal_select_711 = signal_mux_291[11:0];
    assign signal_cat_204 = { signal_select_711,
                              signal_select_710 };
    assign signal_select_712 = signal_mux_290[27:20];
    assign signal_select_713 = signal_mux_290[19:0];
    assign signal_cat_205 = { signal_select_713,
                              signal_select_712 };
    assign signal_select_714 = signal_mux_289[27:24];
    assign signal_select_715 = signal_mux_289[23:0];
    assign signal_cat_206 = { signal_select_715,
                              signal_select_714 };
    assign signal_select_716 = signal_mux_288[27:26];
    assign signal_select_717 = signal_mux_288[25:0];
    assign signal_cat_207 = { signal_select_717,
                              signal_select_716 };
    assign signal_select_718 = signal_cat_211[27:27];
    assign signal_select_719 = signal_cat_211[26:0];
    assign signal_cat_208 = { signal_select_719,
                              signal_select_718 };
    assign signal_select_720 = signal_select_722[4:3];
    assign signal_select_721 = signal_select_722[4:3];
    assign signal_select_722 = word[12:8];
    assign signal_select_723 = signal_select_722[4:4];
    assign signal_cat_209 = { gnd,
                              signal_select_723 };
    always @* begin
        case (signal_wire_38)
        0:
            d$side_set <= signal_const_20;
        1:
            d$side_set <= signal_cat_209;
        2:
            d$side_set <= signal_select_721;
        default:
            d$side_set <= signal_select_720;
        endcase
    end
    assign signal_cat_210 = { signal_const_35,
                              d$side_set };
    assign signal_cat_211 = { signal_const_15,
                              signal_cat_210 };
    assign signal_select_724 = signal_wire_39[0:0];
    assign signal_mux_288 = signal_select_724 ? signal_cat_208 : signal_cat_211;
    assign signal_select_725 = signal_wire_39[1:1];
    assign signal_mux_289 = signal_select_725 ? signal_cat_207 : signal_mux_288;
    assign signal_select_726 = signal_wire_39[2:2];
    assign signal_mux_290 = signal_select_726 ? signal_cat_206 : signal_mux_289;
    assign signal_select_727 = signal_wire_39[3:3];
    assign signal_mux_291 = signal_select_727 ? signal_cat_205 : signal_mux_290;
    assign signal_select_728 = signal_wire_39[4:4];
    assign signal_mux_292 = signal_select_728 ? signal_cat_204 : signal_mux_291;
    assign signal_and_139 = signal_mux_292 & signal_and_140;
    assign signal_select_729 = signal_mux_301[27:12];
    assign signal_select_730 = signal_mux_301[11:0];
    assign signal_cat_212 = { signal_select_730,
                              signal_select_729 };
    assign signal_select_731 = signal_mux_300[27:20];
    assign signal_select_732 = signal_mux_300[19:0];
    assign signal_cat_213 = { signal_select_732,
                              signal_select_731 };
    assign signal_select_733 = signal_mux_299[27:24];
    assign signal_select_734 = signal_mux_299[23:0];
    assign signal_cat_214 = { signal_select_734,
                              signal_select_733 };
    assign signal_select_735 = signal_mux_298[27:26];
    assign signal_select_736 = signal_mux_298[25:0];
    assign signal_cat_215 = { signal_select_736,
                              signal_select_735 };
    assign signal_select_737 = signal_cat_221[27:27];
    assign signal_select_738 = signal_cat_221[26:0];
    assign signal_cat_216 = { signal_select_738,
                              signal_select_737 };
    assign signal_select_739 = signal_mux_295[7:0];
    assign signal_cat_217 = { signal_select_739,
                              signal_const_18 };
    assign signal_select_740 = signal_mux_294[11:0];
    assign signal_cat_218 = { signal_select_740,
                              signal_const_19 };
    assign signal_select_741 = signal_mux_293[13:0];
    assign signal_cat_219 = { signal_select_741,
                              signal_const_20 };
    assign signal_select_742 = signal_cat_220[0:0];
    assign signal_mux_293 = signal_select_742 ? signal_const_21 : signal_const_22;
    assign signal_select_743 = signal_cat_220[1:1];
    assign signal_mux_294 = signal_select_743 ? signal_cat_219 : signal_mux_293;
    assign signal_select_744 = signal_cat_220[2:2];
    assign signal_mux_295 = signal_select_744 ? signal_cat_218 : signal_mux_294;
    assign signal_select_745 = signal_cat_220[3:3];
    assign signal_mux_296 = signal_select_745 ? signal_cat_217 : signal_mux_295;
    assign signal_wire_38 = config$side_set_count;
    assign signal_cat_220 = { signal_const_24,
                              signal_wire_38 };
    assign signal_select_746 = signal_cat_220[4:4];
    assign signal_mux_297 = signal_select_746 ? signal_const_17 : signal_mux_296;
    assign signal_not_62 = ~ signal_mux_297;
    assign signal_cat_221 = { signal_const_15,
                              signal_not_62 };
    assign signal_select_747 = signal_wire_39[0:0];
    assign signal_mux_298 = signal_select_747 ? signal_cat_216 : signal_cat_221;
    assign signal_select_748 = signal_wire_39[1:1];
    assign signal_mux_299 = signal_select_748 ? signal_cat_215 : signal_mux_298;
    assign signal_select_749 = signal_wire_39[2:2];
    assign signal_mux_300 = signal_select_749 ? signal_cat_214 : signal_mux_299;
    assign signal_select_750 = signal_wire_39[3:3];
    assign signal_mux_301 = signal_select_750 ? signal_cat_213 : signal_mux_300;
    assign signal_wire_39 = config$side_set_base;
    assign signal_select_751 = signal_wire_39[4:4];
    assign signal_mux_302 = signal_select_751 ? signal_cat_212 : signal_mux_301;
    assign signal_and_140 = signal_mux_302 & signal_const_137;
    assign signal_not_63 = ~ signal_and_140;
    assign signal_and_141 = pin_dir_0 & signal_not_63;
    assign pin_dir_side = signal_and_141 | signal_and_139;
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
            pin_dir_next <= signal_mux_287;
        4:
            pin_dir_next <= signal_mux_165;
        5:
            pin_dir_next <= signal_mux_149;
        6:
            pin_dir_next <= pin_dir_base;
        default:
            pin_dir_next <= pin_dir_base;
        endcase
    end
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_27 <= signal_const_13;
        else
            if (op_go)
                signal_reg_27 <= pin_dir_next;
    end
    assign pin_dir_0 = signal_reg_27;
    assign signal_select_752 = pin_dir_0[19:19];
    assign signal_mux_303 = signal_select_752 ? signal_select_349 : signal_select_350;
    assign signal_select_753 = signal_wire_41[20:20];
    assign signal_select_754 = pin_out_0[20:20];
    assign signal_or_18 = signal_select_754 | signal_select_753;
    assign signal_select_755 = signal_wire_41[21:21];
    assign signal_select_756 = pin_out_0[21:21];
    assign signal_or_19 = signal_select_756 | signal_select_755;
    assign signal_select_757 = signal_wire_41[22:22];
    assign signal_select_758 = pin_out_0[22:22];
    assign signal_or_20 = signal_select_758 | signal_select_757;
    assign signal_select_759 = signal_wire_41[23:23];
    assign signal_select_760 = pin_out_0[23:23];
    assign signal_or_21 = signal_select_760 | signal_select_759;
    assign signal_select_761 = signal_wire_41[24:24];
    assign signal_select_762 = pin_out_0[24:24];
    assign signal_or_22 = signal_select_762 | signal_select_761;
    assign signal_select_763 = signal_wire_41[25:25];
    assign signal_select_764 = pin_out_0[25:25];
    assign signal_or_23 = signal_select_764 | signal_select_763;
    assign signal_select_765 = signal_wire_41[26:26];
    assign signal_select_766 = pin_out_0[26:26];
    assign signal_or_24 = signal_select_766 | signal_select_765;
    assign signal_wire_41 = inputs;
    assign signal_select_767 = signal_wire_41[27:27];
    assign signal_select_768 = pin_out_0[27:27];
    assign signal_or_25 = signal_select_768 | signal_select_767;
    assign sample = { signal_or_25,
                      signal_or_24,
                      signal_or_23,
                      signal_or_22,
                      signal_or_21,
                      signal_or_20,
                      signal_or_19,
                      signal_or_18,
                      signal_mux_303,
                      signal_mux_133,
                      signal_mux_132,
                      signal_mux_131,
                      signal_mux_130,
                      signal_mux_129,
                      signal_mux_128,
                      signal_mux_127,
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
                      signal_select_317,
                      signal_select_316 };
    assign signal_and_142 = sample & wait_select_0;
    assign signal_eq_72 = signal_and_142 == signal_const_13;
    assign wait_pin_cur = ~ signal_eq_72;
    assign signal_eq_73 = wait_pin_cur == d$wait_polarity;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            word <= signal_const_17;
        else
            if (ir_load)
                word <= signal_wire_43;
    end
    assign d$wait_source$binary_variant = word[6:5];
    always @* begin
        case (d$wait_source$binary_variant)
        0:
            wait_ready <= signal_eq_73;
        1:
            wait_ready <= signal_and_53;
        2:
            wait_ready <= deadline_ready;
        default:
            wait_ready <= signal_mux_117;
        endcase
    end
    assign signal_not_64 = ~ wait_ready;
    assign signal_or_26 = jmp_go | signal_wire_50;
    assign signal_or_27 = signal_or_26 | resume_asked;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            refill <= signal_const_3;
        else
            refill <= signal_or_27;
    end
    assign signal_or_28 = advance | refill;
    assign ir_load = signal_or_28;
    assign gnd = 1'b0;
    assign signal_eq_74 = signal_select_769 == signal_const_245;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            is_opcode$1 <= gnd;
        else
            if (ir_load)
                is_opcode$1 <= signal_eq_74;
    end
    assign wait_holds = is_opcode$1 & signal_not_64;
    assign signal_not_65 = ~ wait_holds;
    assign advance = op_go & signal_not_65;
    assign signal_mux_304 = advance ? signal_mux_115 : pc_next;
    assign pc_after_next = start_0 ? signal_mux_114 : signal_mux_304;
    assign signal_mux_305 = jmp_go ? jmp_target_or_next : pc_after_next;
    assign signal_mux_306 = resume_asked ? pc_0 : signal_mux_305;
    assign signal_mux_307 = signal_wire_50 ? signal_const_10 : signal_mux_306;
    assign fetch_addr = signal_mux_307;
    assign signal_mux_308 = program_write ? signal_wire_5 : fetch_addr;
    assign signal_wire_42 = program_write$valid;
    assign program_write = signal_wire_42 & halted_0;
    assign vdd = 1'b1;
    sram_macro
        sram_macro
        ( .clock(signal_wire_49),
          .men(vdd),
          .wen(program_write),
          .ren(vdd),
          .addr(signal_mux_308),
          .din(signal_wire_4),
          .bm(signal_const_22),
          .dout(signal_inst_2[15:0]) );
    assign signal_wire_43 = signal_inst_2;
    assign signal_select_769 = signal_wire_43[15:13];
    assign signal_eq_75 = signal_select_769 == signal_const_24;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            is_opcode$0 <= vdd;
        else
            if (ir_load)
                is_opcode$0 <= signal_eq_75;
    end
    assign jmp_go = go & is_opcode$0;
    assign signal_mux_309 = jmp_go ? jmp_target_or_next : signal_mux_106;
    assign pc_value_next = start_0 ? signal_const_10 : signal_mux_309;
    assign signal_eq_76 = pc_value_next == signal_wire_3;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_28 <= signal_const_3;
        else
            signal_reg_28 <= signal_eq_76;
    end
    assign at_break = signal_reg_28;
    assign signal_wire_44 = config$break_enable;
    assign signal_and_143 = ready & signal_wire_44;
    assign signal_and_144 = signal_and_143 & at_break;
    assign breaks = signal_and_144 & signal_not_25;
    assign signal_mux_310 = breaks ? vdd : signal_mux_102;
    assign signal_wire_45 = stop;
    assign signal_mux_311 = signal_wire_45 ? vdd : signal_mux_310;
    assign signal_not_66 = ~ resume_0;
    assign signal_wire_46 = single_step;
    assign signal_wire_47 = resume;
    assign signal_or_29 = signal_wire_47 | signal_wire_46;
    assign signal_and_145 = signal_or_29 & halted_0;
    assign resume_asked = signal_and_145 & signal_not_66;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_29 <= signal_const_3;
        else
            signal_reg_29 <= resume_asked;
    end
    assign resume_0 = signal_reg_29;
    assign signal_mux_312 = resume_0 ? gnd : signal_mux_311;
    assign signal_wire_48 = clear;
    assign signal_wire_49 = clock;
    assign signal_wire_50 = start;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            start_0 <= signal_const_3;
        else
            start_0 <= signal_wire_50;
    end
    assign halted_next = start_0 ? gnd : signal_mux_312;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_30 <= vdd;
        else
            signal_reg_30 <= halted_next;
    end
    assign halted_0 = signal_reg_30;
    assign signal_not_67 = ~ halted_0;
    assign signal_and_146 = signal_not_67 & signal_eq_11;
    assign ready = signal_and_146 & signal_not_18;
    assign issue = ready & signal_not_17;
    assign go = issue & decode_ok_0;
    assign op_go = go & signal_not_16;
    assign signal_mux_313 = op_go ? pin_out_next : pin_out_flipped;
    always @(posedge signal_wire_49) begin
        if (signal_wire_48)
            signal_reg_31 <= signal_const_13;
        else
            if (signal_or_3)
                signal_reg_31 <= signal_mux_313;
    end
    assign pin_out_0 = signal_reg_31;
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
    assign wait_select = wait_select_0;
    assign crc = crc_0;
    assign stuff_run = stuff_run_0;
    assign flip_pending = flip_pending_0;
    assign flip_bit = flip_bit_0;

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
    hosts$config$break_enable_0,
    hosts$config$break_pc_0,
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
    hosts$resume_1,
    hosts$single_step_1,
    pads,
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
    engines$wait_select_1,
    engines$crc_1,
    engines$stuff_run_1,
    engines$flip_pending_1,
    engines$flip_bit_1,
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
    input hosts$resume_1;
    input hosts$single_step_1;
    input [19:0] pads;
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
    output [27:0] engines$wait_select_1;
    output [15:0] engines$crc_1;
    output [4:0] engines$stuff_run_1;
    output engines$flip_pending_1;
    output engines$flip_bit_1;
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
    wire signal_select_2;
    wire signal_wire;
    wire signal_select_3;
    wire signal_wire_1;
    wire [4:0] signal_select_4;
    wire [4:0] signal_wire_2;
    wire [15:0] signal_select_5;
    wire [15:0] signal_wire_3;
    wire [27:0] signal_select_6;
    wire [27:0] signal_wire_4;
    wire [7:0] signal_select_7;
    wire [7:0] signal_wire_5;
    wire signal_select_8;
    wire signal_wire_6;
    wire [15:0] signal_select_9;
    wire [15:0] signal_wire_7;
    wire [15:0] signal_select_10;
    wire [15:0] signal_wire_8;
    wire [3:0] signal_select_11;
    wire [3:0] signal_wire_9;
    wire [3:0] signal_select_12;
    wire [3:0] signal_wire_10;
    wire signal_select_13;
    wire signal_wire_11;
    wire [23:0] signal_select_14;
    wire [23:0] signal_wire_12;
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
    wire signal_select_20;
    wire signal_wire_18;
    wire signal_select_21;
    wire signal_wire_19;
    wire [4:0] signal_select_22;
    wire [4:0] signal_wire_20;
    wire [23:0] signal_select_23;
    wire [23:0] signal_wire_21;
    wire [4:0] signal_select_24;
    wire [4:0] signal_wire_22;
    wire [15:0] signal_select_25;
    wire [15:0] signal_wire_23;
    wire [4:0] signal_select_26;
    wire [4:0] signal_wire_24;
    wire [15:0] signal_select_27;
    wire [15:0] signal_wire_25;
    wire [15:0] signal_select_28;
    wire [15:0] signal_wire_26;
    wire [23:0] signal_select_29;
    wire [23:0] signal_wire_27;
    wire [15:0] signal_select_30;
    wire [15:0] signal_wire_28;
    wire [15:0] signal_select_31;
    wire [15:0] signal_wire_29;
    wire [15:0] signal_select_32;
    wire [15:0] signal_wire_30;
    wire [8:0] signal_select_33;
    wire [8:0] signal_wire_31;
    wire [8:0] signal_select_34;
    wire [8:0] signal_wire_32;
    wire signal_select_35;
    wire signal_wire_33;
    wire signal_select_36;
    wire signal_wire_34;
    wire [4:0] signal_select_37;
    wire [4:0] signal_wire_35;
    wire [15:0] signal_select_38;
    wire [15:0] signal_wire_36;
    wire [27:0] signal_select_39;
    wire [27:0] signal_wire_37;
    wire [7:0] signal_select_40;
    wire [7:0] signal_wire_38;
    wire signal_select_41;
    wire signal_wire_39;
    wire [15:0] signal_select_42;
    wire [15:0] signal_wire_40;
    wire [15:0] signal_select_43;
    wire [15:0] signal_wire_41;
    wire [3:0] signal_select_44;
    wire [3:0] signal_wire_42;
    wire [3:0] signal_select_45;
    wire [3:0] signal_wire_43;
    wire signal_select_46;
    wire signal_wire_44;
    wire [23:0] signal_select_47;
    wire [23:0] signal_wire_45;
    wire signal_select_48;
    wire signal_wire_46;
    wire signal_select_49;
    wire signal_wire_47;
    wire signal_select_50;
    wire signal_wire_48;
    wire signal_select_51;
    wire signal_wire_49;
    wire signal_select_52;
    wire signal_wire_50;
    wire signal_select_53;
    wire signal_wire_51;
    wire signal_select_54;
    wire signal_wire_52;
    wire [4:0] signal_select_55;
    wire [4:0] signal_wire_53;
    wire [23:0] signal_select_56;
    wire [23:0] signal_wire_54;
    wire [4:0] signal_select_57;
    wire [4:0] signal_wire_55;
    wire [15:0] signal_select_58;
    wire [15:0] signal_wire_56;
    wire [4:0] signal_select_59;
    wire [4:0] signal_wire_57;
    wire [15:0] signal_select_60;
    wire [15:0] signal_wire_58;
    wire [15:0] signal_select_61;
    wire [15:0] signal_wire_59;
    wire [23:0] signal_select_62;
    wire [23:0] signal_wire_60;
    wire [15:0] signal_select_63;
    wire [15:0] signal_wire_61;
    wire [15:0] signal_select_64;
    wire [15:0] signal_wire_62;
    wire [15:0] signal_select_65;
    wire [15:0] signal_wire_63;
    wire [8:0] signal_select_66;
    wire [8:0] signal_wire_64;
    wire [8:0] signal_select_67;
    wire [8:0] signal_wire_65;
    wire [27:0] signal_const_1;
    wire [27:0] signal_or_4;
    wire [27:0] signal_select_68;
    wire [27:0] signal_wire_66;
    wire [27:0] signal_and_2;
    wire [27:0] signal_select_69;
    wire [27:0] signal_wire_67;
    wire [27:0] signal_not;
    wire [7:0] signal_const_2;
    wire [27:0] signal_cat;
    wire [27:0] signal_and_3;
    wire [27:0] signal_or_5;
    wire signal_wire_68;
    wire signal_wire_69;
    wire signal_wire_70;
    wire signal_wire_71;
    wire signal_wire_72;
    wire signal_wire_73;
    wire [15:0] signal_wire_74;
    wire signal_wire_75;
    wire [8:0] signal_select_70;
    wire [8:0] signal_wire_76;
    wire [8:0] signal_select_71;
    wire [8:0] signal_wire_77;
    wire [15:0] signal_wire_78;
    wire [8:0] signal_wire_79;
    wire signal_wire_80;
    wire [15:0] signal_wire_81;
    wire [8:0] signal_wire_82;
    wire signal_wire_83;
    wire [27:0] signal_or_6;
    wire [27:0] signal_and_4;
    wire [27:0] signal_select_72;
    wire [27:0] signal_wire_84;
    wire [27:0] signal_not_1;
    wire [19:0] signal_wire_85;
    wire [27:0] signal_cat_1;
    wire [27:0] signal_and_5;
    wire [27:0] signal_or_7;
    wire signal_wire_86;
    wire signal_wire_87;
    wire signal_wire_88;
    wire signal_wire_89;
    wire signal_wire_90;
    wire signal_wire_91;
    wire [15:0] signal_wire_92;
    wire signal_wire_93;
    wire [15:0] signal_select_73;
    wire [15:0] signal_wire_94;
    wire [8:0] signal_wire_95;
    wire signal_wire_96;
    wire signal_wire_97;
    wire signal_wire_98;
    wire signal_wire_99;
    wire [8:0] signal_wire_100;
    wire signal_wire_101;
    wire [15:0] signal_wire_102;
    wire [8:0] signal_wire_103;
    wire [8:0] signal_wire_104;
    wire signal_wire_105;
    wire [4:0] signal_wire_106;
    wire signal_wire_107;
    wire [15:0] signal_wire_108;
    wire [15:0] signal_wire_109;
    wire [4:0] signal_wire_110;
    wire [4:0] signal_wire_111;
    wire signal_wire_112;
    wire [4:0] signal_wire_113;
    wire signal_wire_114;
    wire signal_wire_115;
    wire signal_wire_116;
    wire signal_wire_117;
    wire [4:0] signal_wire_118;
    wire [4:0] signal_wire_119;
    wire [2:0] signal_wire_120;
    wire [4:0] signal_wire_121;
    wire [4:0] signal_wire_122;
    wire [4:0] signal_wire_123;
    wire [4:0] signal_wire_124;
    wire [4:0] signal_wire_125;
    wire signal_wire_126;
    wire [4:0] signal_wire_127;
    wire [1:0] signal_wire_128;
    wire [374:0] signal_inst;
    wire signal_select_74;
    wire signal_wire_129;
    wire signal_select_75;
    wire signal_wire_130;
    wire [31:0] signal_inst_1;
    wire [15:0] signal_select_76;
    wire [15:0] signal_wire_131;
    wire [8:0] signal_wire_132;
    wire signal_wire_133;
    wire signal_wire_134;
    wire signal_wire_135;
    wire signal_wire_136;
    wire [8:0] signal_wire_137;
    wire signal_wire_138;
    wire [15:0] signal_wire_139;
    wire [8:0] signal_wire_140;
    wire [8:0] signal_wire_141;
    wire signal_wire_142;
    wire [4:0] signal_wire_143;
    wire signal_wire_144;
    wire [15:0] signal_wire_145;
    wire [15:0] signal_wire_146;
    wire [4:0] signal_wire_147;
    wire [4:0] signal_wire_148;
    wire signal_wire_149;
    wire [4:0] signal_wire_150;
    wire signal_wire_151;
    wire signal_wire_152;
    wire signal_wire_153;
    wire signal_wire_154;
    wire [4:0] signal_wire_155;
    wire [4:0] signal_wire_156;
    wire [2:0] signal_wire_157;
    wire [4:0] signal_wire_158;
    wire [4:0] signal_wire_159;
    wire [4:0] signal_wire_160;
    wire [4:0] signal_wire_161;
    wire [4:0] signal_wire_162;
    wire signal_wire_163;
    wire [4:0] signal_wire_164;
    wire [1:0] signal_wire_165;
    wire signal_wire_166;
    wire signal_wire_167;
    wire [374:0] signal_inst_2;
    wire [27:0] signal_select_77;
    wire [27:0] signal_wire_168;
    assign signal_or = signal_wire_84 | signal_wire_67;
    assign signal_select = signal_or[19:0];
    assign signal_or_1 = signal_wire_67 | signal_const;
    assign signal_and = signal_wire_66 & signal_or_1;
    assign signal_const = 28'b0000000000000000111111111111;
    assign signal_or_2 = signal_wire_84 | signal_const;
    assign signal_and_1 = signal_wire_168 & signal_or_2;
    assign signal_or_3 = signal_and_1 | signal_and;
    assign signal_select_1 = signal_or_3[19:0];
    assign signal_select_2 = signal_inst[374:374];
    assign signal_wire = signal_select_2;
    assign signal_select_3 = signal_inst[373:373];
    assign signal_wire_1 = signal_select_3;
    assign signal_select_4 = signal_inst[372:368];
    assign signal_wire_2 = signal_select_4;
    assign signal_select_5 = signal_inst[367:352];
    assign signal_wire_3 = signal_select_5;
    assign signal_select_6 = signal_inst[351:324];
    assign signal_wire_4 = signal_select_6;
    assign signal_select_7 = signal_inst[323:316];
    assign signal_wire_5 = signal_select_7;
    assign signal_select_8 = signal_inst[315:315];
    assign signal_wire_6 = signal_select_8;
    assign signal_select_9 = signal_inst[314:299];
    assign signal_wire_7 = signal_select_9;
    assign signal_select_10 = signal_inst[298:283];
    assign signal_wire_8 = signal_select_10;
    assign signal_select_11 = signal_inst[282:279];
    assign signal_wire_9 = signal_select_11;
    assign signal_select_12 = signal_inst[278:275];
    assign signal_wire_10 = signal_select_12;
    assign signal_select_13 = signal_inst[274:274];
    assign signal_wire_11 = signal_select_13;
    assign signal_select_14 = signal_inst[273:250];
    assign signal_wire_12 = signal_select_14;
    assign signal_select_15 = signal_inst[249:249];
    assign signal_wire_13 = signal_select_15;
    assign signal_select_16 = signal_inst[248:248];
    assign signal_wire_14 = signal_select_16;
    assign signal_select_17 = signal_inst[247:247];
    assign signal_wire_15 = signal_select_17;
    assign signal_select_18 = signal_inst[246:246];
    assign signal_wire_16 = signal_select_18;
    assign signal_select_19 = signal_inst[245:245];
    assign signal_wire_17 = signal_select_19;
    assign signal_select_20 = signal_inst[244:244];
    assign signal_wire_18 = signal_select_20;
    assign signal_select_21 = signal_inst[243:243];
    assign signal_wire_19 = signal_select_21;
    assign signal_select_22 = signal_inst[241:237];
    assign signal_wire_20 = signal_select_22;
    assign signal_select_23 = signal_inst[236:213];
    assign signal_wire_21 = signal_select_23;
    assign signal_select_24 = signal_inst[212:208];
    assign signal_wire_22 = signal_select_24;
    assign signal_select_25 = signal_inst[207:192];
    assign signal_wire_23 = signal_select_25;
    assign signal_select_26 = signal_inst[191:187];
    assign signal_wire_24 = signal_select_26;
    assign signal_select_27 = signal_inst[186:171];
    assign signal_wire_25 = signal_select_27;
    assign signal_select_28 = signal_inst[170:155];
    assign signal_wire_26 = signal_select_28;
    assign signal_select_29 = signal_inst[154:131];
    assign signal_wire_27 = signal_select_29;
    assign signal_select_30 = signal_inst[130:115];
    assign signal_wire_28 = signal_select_30;
    assign signal_select_31 = signal_inst[114:99];
    assign signal_wire_29 = signal_select_31;
    assign signal_select_32 = signal_inst[98:83];
    assign signal_wire_30 = signal_select_32;
    assign signal_select_33 = signal_inst[73:65];
    assign signal_wire_31 = signal_select_33;
    assign signal_select_34 = signal_inst[64:56];
    assign signal_wire_32 = signal_select_34;
    assign signal_select_35 = signal_inst_2[374:374];
    assign signal_wire_33 = signal_select_35;
    assign signal_select_36 = signal_inst_2[373:373];
    assign signal_wire_34 = signal_select_36;
    assign signal_select_37 = signal_inst_2[372:368];
    assign signal_wire_35 = signal_select_37;
    assign signal_select_38 = signal_inst_2[367:352];
    assign signal_wire_36 = signal_select_38;
    assign signal_select_39 = signal_inst_2[351:324];
    assign signal_wire_37 = signal_select_39;
    assign signal_select_40 = signal_inst_2[323:316];
    assign signal_wire_38 = signal_select_40;
    assign signal_select_41 = signal_inst_2[315:315];
    assign signal_wire_39 = signal_select_41;
    assign signal_select_42 = signal_inst_2[314:299];
    assign signal_wire_40 = signal_select_42;
    assign signal_select_43 = signal_inst_2[298:283];
    assign signal_wire_41 = signal_select_43;
    assign signal_select_44 = signal_inst_2[282:279];
    assign signal_wire_42 = signal_select_44;
    assign signal_select_45 = signal_inst_2[278:275];
    assign signal_wire_43 = signal_select_45;
    assign signal_select_46 = signal_inst_2[274:274];
    assign signal_wire_44 = signal_select_46;
    assign signal_select_47 = signal_inst_2[273:250];
    assign signal_wire_45 = signal_select_47;
    assign signal_select_48 = signal_inst_2[249:249];
    assign signal_wire_46 = signal_select_48;
    assign signal_select_49 = signal_inst_2[248:248];
    assign signal_wire_47 = signal_select_49;
    assign signal_select_50 = signal_inst_2[247:247];
    assign signal_wire_48 = signal_select_50;
    assign signal_select_51 = signal_inst_2[246:246];
    assign signal_wire_49 = signal_select_51;
    assign signal_select_52 = signal_inst_2[245:245];
    assign signal_wire_50 = signal_select_52;
    assign signal_select_53 = signal_inst_2[244:244];
    assign signal_wire_51 = signal_select_53;
    assign signal_select_54 = signal_inst_2[243:243];
    assign signal_wire_52 = signal_select_54;
    assign signal_select_55 = signal_inst_2[241:237];
    assign signal_wire_53 = signal_select_55;
    assign signal_select_56 = signal_inst_2[236:213];
    assign signal_wire_54 = signal_select_56;
    assign signal_select_57 = signal_inst_2[212:208];
    assign signal_wire_55 = signal_select_57;
    assign signal_select_58 = signal_inst_2[207:192];
    assign signal_wire_56 = signal_select_58;
    assign signal_select_59 = signal_inst_2[191:187];
    assign signal_wire_57 = signal_select_59;
    assign signal_select_60 = signal_inst_2[186:171];
    assign signal_wire_58 = signal_select_60;
    assign signal_select_61 = signal_inst_2[170:155];
    assign signal_wire_59 = signal_select_61;
    assign signal_select_62 = signal_inst_2[154:131];
    assign signal_wire_60 = signal_select_62;
    assign signal_select_63 = signal_inst_2[130:115];
    assign signal_wire_61 = signal_select_63;
    assign signal_select_64 = signal_inst_2[114:99];
    assign signal_wire_62 = signal_select_64;
    assign signal_select_65 = signal_inst_2[98:83];
    assign signal_wire_63 = signal_select_65;
    assign signal_select_66 = signal_inst_2[73:65];
    assign signal_wire_64 = signal_select_66;
    assign signal_select_67 = signal_inst_2[64:56];
    assign signal_wire_65 = signal_select_67;
    assign signal_const_1 = 28'b1111111100000000000000000000;
    assign signal_or_4 = signal_wire_67 | signal_const_1;
    assign signal_select_68 = signal_inst[27:0];
    assign signal_wire_66 = signal_select_68;
    assign signal_and_2 = signal_wire_66 & signal_or_4;
    assign signal_select_69 = signal_inst[55:28];
    assign signal_wire_67 = signal_select_69;
    assign signal_not = ~ signal_wire_67;
    assign signal_const_2 = 8'b00000000;
    assign signal_cat = { signal_const_2,
                          signal_wire_85 };
    assign signal_and_3 = signal_cat & signal_not;
    assign signal_or_5 = signal_and_3 | signal_and_2;
    assign signal_wire_68 = hosts$single_step_0;
    assign signal_wire_69 = hosts$resume_0;
    assign signal_wire_70 = hosts$flush_0;
    assign signal_wire_71 = hosts$stop_0;
    assign signal_wire_72 = hosts$clear_irq_0;
    assign signal_wire_73 = hosts$rx_pop_0;
    assign signal_wire_74 = hosts$tx$value_0;
    assign signal_wire_75 = hosts$tx$valid_0;
    assign signal_select_70 = signal_inst[82:74];
    assign signal_wire_76 = signal_select_70;
    assign signal_select_71 = signal_inst_2[82:74];
    assign signal_wire_77 = signal_select_71;
    assign signal_wire_78 = hosts$data_write$data_1;
    assign signal_wire_79 = hosts$data_write$addr_1;
    assign signal_wire_80 = hosts$data_write$valid_1;
    assign signal_wire_81 = hosts$data_write$data_0;
    assign signal_wire_82 = hosts$data_write$addr_0;
    assign signal_wire_83 = hosts$data_write$valid_0;
    assign signal_or_6 = signal_wire_84 | signal_const_1;
    assign signal_and_4 = signal_wire_168 & signal_or_6;
    assign signal_select_72 = signal_inst_2[55:28];
    assign signal_wire_84 = signal_select_72;
    assign signal_not_1 = ~ signal_wire_84;
    assign signal_wire_85 = pads;
    assign signal_cat_1 = { signal_const_2,
                            signal_wire_85 };
    assign signal_and_5 = signal_cat_1 & signal_not_1;
    assign signal_or_7 = signal_and_5 | signal_and_4;
    assign signal_wire_86 = hosts$single_step_1;
    assign signal_wire_87 = hosts$resume_1;
    assign signal_wire_88 = hosts$flush_1;
    assign signal_wire_89 = hosts$stop_1;
    assign signal_wire_90 = hosts$clear_irq_1;
    assign signal_wire_91 = hosts$rx_pop_1;
    assign signal_wire_92 = hosts$tx$value_1;
    assign signal_wire_93 = hosts$tx$valid_1;
    assign signal_select_73 = signal_inst_1[31:16];
    assign signal_wire_94 = hosts$program_write$data_1;
    assign signal_wire_95 = hosts$program_write$addr_1;
    assign signal_wire_96 = hosts$program_write$valid_1;
    assign signal_wire_97 = hosts$start_1;
    assign signal_wire_98 = hosts$config$manchester_1;
    assign signal_wire_99 = hosts$config$autopull_data_1;
    assign signal_wire_100 = hosts$config$break_pc_1;
    assign signal_wire_101 = hosts$config$break_enable_1;
    assign signal_wire_102 = hosts$config$period_fraction_1;
    assign signal_wire_103 = hosts$config$wrap_top_1;
    assign signal_wire_104 = hosts$config$wrap_bottom_1;
    assign signal_wire_105 = hosts$config$stuff_level_1;
    assign signal_wire_106 = hosts$config$stuff_threshold_1;
    assign signal_wire_107 = hosts$config$crc_reflect_1;
    assign signal_wire_108 = hosts$config$crc_init_1;
    assign signal_wire_109 = hosts$config$crc_poly_1;
    assign signal_wire_110 = hosts$config$crc_width_1;
    assign signal_wire_111 = hosts$config$pull_threshold_1;
    assign signal_wire_112 = hosts$config$autopull_1;
    assign signal_wire_113 = hosts$config$push_threshold_1;
    assign signal_wire_114 = hosts$config$autopush_1;
    assign signal_wire_115 = hosts$config$out_shift_right_1;
    assign signal_wire_116 = hosts$config$in_shift_right_1;
    assign signal_wire_117 = hosts$config$capture_rising_1;
    assign signal_wire_118 = hosts$config$capture_pin_1;
    assign signal_wire_119 = hosts$config$jmp_pin_1;
    assign signal_wire_120 = hosts$config$set_count_1;
    assign signal_wire_121 = hosts$config$set_base_1;
    assign signal_wire_122 = hosts$config$out_count_1;
    assign signal_wire_123 = hosts$config$out_base_1;
    assign signal_wire_124 = hosts$config$in_count_1;
    assign signal_wire_125 = hosts$config$in_base_1;
    assign signal_wire_126 = hosts$config$side_set_pindirs_1;
    assign signal_wire_127 = hosts$config$side_set_base_1;
    assign signal_wire_128 = hosts$config$side_set_count_1;
    engine
        engine_1
        ( .clock(signal_wire_167),
          .clear(signal_wire_166),
          .config$side_set_count(signal_wire_128),
          .config$side_set_base(signal_wire_127),
          .config$side_set_pindirs(signal_wire_126),
          .config$in_base(signal_wire_125),
          .config$in_count(signal_wire_124),
          .config$out_base(signal_wire_123),
          .config$out_count(signal_wire_122),
          .config$set_base(signal_wire_121),
          .config$set_count(signal_wire_120),
          .config$jmp_pin(signal_wire_119),
          .config$capture_pin(signal_wire_118),
          .config$capture_rising(signal_wire_117),
          .config$in_shift_right(signal_wire_116),
          .config$out_shift_right(signal_wire_115),
          .config$autopush(signal_wire_114),
          .config$push_threshold(signal_wire_113),
          .config$autopull(signal_wire_112),
          .config$pull_threshold(signal_wire_111),
          .config$crc_width(signal_wire_110),
          .config$crc_poly(signal_wire_109),
          .config$crc_init(signal_wire_108),
          .config$crc_reflect(signal_wire_107),
          .config$stuff_threshold(signal_wire_106),
          .config$stuff_level(signal_wire_105),
          .config$wrap_bottom(signal_wire_104),
          .config$wrap_top(signal_wire_103),
          .config$period_fraction(signal_wire_102),
          .config$break_enable(signal_wire_101),
          .config$break_pc(signal_wire_100),
          .config$autopull_data(signal_wire_99),
          .config$manchester(signal_wire_98),
          .start(signal_wire_97),
          .program_write$valid(signal_wire_96),
          .program_write$addr(signal_wire_95),
          .program_write$data(signal_wire_94),
          .data_word(signal_select_73),
          .tx$valid(signal_wire_93),
          .tx$value(signal_wire_92),
          .rx_pop(signal_wire_91),
          .clear_irq(signal_wire_90),
          .stop(signal_wire_89),
          .flush(signal_wire_88),
          .resume(signal_wire_87),
          .single_step(signal_wire_86),
          .inputs(signal_or_7),
          .pin_out(signal_inst[27:0]),
          .pin_dir(signal_inst[55:28]),
          .pc(signal_inst[64:56]),
          .data_ptr(signal_inst[73:65]),
          .data_addr(signal_inst[82:74]),
          .x(signal_inst[98:83]),
          .y(signal_inst[114:99]),
          .p(signal_inst[130:115]),
          .t(signal_inst[154:131]),
          .t_fraction(signal_inst[170:155]),
          .osr(signal_inst[186:171]),
          .osr_count(signal_inst[191:187]),
          .isr(signal_inst[207:192]),
          .isr_count(signal_inst[212:208]),
          .now(signal_inst[236:213]),
          .stall(signal_inst[241:237]),
          .halted(signal_inst[242:242]),
          .resumed(signal_inst[243:243]),
          .stepping(signal_inst[244:244]),
          .irq(signal_inst[245:245]),
          .fault$underflow(signal_inst[246:246]),
          .fault$overflow(signal_inst[247:247]),
          .fault$missed_deadline(signal_inst[248:248]),
          .fault$decode(signal_inst[249:249]),
          .capture(signal_inst[273:250]),
          .capture_armed(signal_inst[274:274]),
          .tx_level(signal_inst[278:275]),
          .rx_level(signal_inst[282:279]),
          .rx_head(signal_inst[298:283]),
          .instruction(signal_inst[314:299]),
          .decode_ok(signal_inst[315:315]),
          .opcode_onehot(signal_inst[323:316]),
          .wait_select(signal_inst[351:324]),
          .crc(signal_inst[367:352]),
          .stuff_run(signal_inst[372:368]),
          .flip_pending(signal_inst[373:373]),
          .flip_bit(signal_inst[374:374]) );
    assign signal_select_74 = signal_inst[242:242];
    assign signal_wire_129 = signal_select_74;
    assign signal_select_75 = signal_inst_2[242:242];
    assign signal_wire_130 = signal_select_75;
    data_memory
        data_memory
        ( .clock(signal_wire_167),
          .clear(signal_wire_166),
          .halted_0(signal_wire_130),
          .halted_1(signal_wire_129),
          .writes$valid_0(signal_wire_83),
          .writes$addr_0(signal_wire_82),
          .writes$data_0(signal_wire_81),
          .writes$valid_1(signal_wire_80),
          .writes$addr_1(signal_wire_79),
          .writes$data_1(signal_wire_78),
          .reads_0(signal_wire_77),
          .reads_1(signal_wire_76),
          .words_0(signal_inst_1[15:0]),
          .words_1(signal_inst_1[31:16]) );
    assign signal_select_76 = signal_inst_1[15:0];
    assign signal_wire_131 = hosts$program_write$data_0;
    assign signal_wire_132 = hosts$program_write$addr_0;
    assign signal_wire_133 = hosts$program_write$valid_0;
    assign signal_wire_134 = hosts$start_0;
    assign signal_wire_135 = hosts$config$manchester_0;
    assign signal_wire_136 = hosts$config$autopull_data_0;
    assign signal_wire_137 = hosts$config$break_pc_0;
    assign signal_wire_138 = hosts$config$break_enable_0;
    assign signal_wire_139 = hosts$config$period_fraction_0;
    assign signal_wire_140 = hosts$config$wrap_top_0;
    assign signal_wire_141 = hosts$config$wrap_bottom_0;
    assign signal_wire_142 = hosts$config$stuff_level_0;
    assign signal_wire_143 = hosts$config$stuff_threshold_0;
    assign signal_wire_144 = hosts$config$crc_reflect_0;
    assign signal_wire_145 = hosts$config$crc_init_0;
    assign signal_wire_146 = hosts$config$crc_poly_0;
    assign signal_wire_147 = hosts$config$crc_width_0;
    assign signal_wire_148 = hosts$config$pull_threshold_0;
    assign signal_wire_149 = hosts$config$autopull_0;
    assign signal_wire_150 = hosts$config$push_threshold_0;
    assign signal_wire_151 = hosts$config$autopush_0;
    assign signal_wire_152 = hosts$config$out_shift_right_0;
    assign signal_wire_153 = hosts$config$in_shift_right_0;
    assign signal_wire_154 = hosts$config$capture_rising_0;
    assign signal_wire_155 = hosts$config$capture_pin_0;
    assign signal_wire_156 = hosts$config$jmp_pin_0;
    assign signal_wire_157 = hosts$config$set_count_0;
    assign signal_wire_158 = hosts$config$set_base_0;
    assign signal_wire_159 = hosts$config$out_count_0;
    assign signal_wire_160 = hosts$config$out_base_0;
    assign signal_wire_161 = hosts$config$in_count_0;
    assign signal_wire_162 = hosts$config$in_base_0;
    assign signal_wire_163 = hosts$config$side_set_pindirs_0;
    assign signal_wire_164 = hosts$config$side_set_base_0;
    assign signal_wire_165 = hosts$config$side_set_count_0;
    assign signal_wire_166 = clear;
    assign signal_wire_167 = clock;
    engine
        engine_0
        ( .clock(signal_wire_167),
          .clear(signal_wire_166),
          .config$side_set_count(signal_wire_165),
          .config$side_set_base(signal_wire_164),
          .config$side_set_pindirs(signal_wire_163),
          .config$in_base(signal_wire_162),
          .config$in_count(signal_wire_161),
          .config$out_base(signal_wire_160),
          .config$out_count(signal_wire_159),
          .config$set_base(signal_wire_158),
          .config$set_count(signal_wire_157),
          .config$jmp_pin(signal_wire_156),
          .config$capture_pin(signal_wire_155),
          .config$capture_rising(signal_wire_154),
          .config$in_shift_right(signal_wire_153),
          .config$out_shift_right(signal_wire_152),
          .config$autopush(signal_wire_151),
          .config$push_threshold(signal_wire_150),
          .config$autopull(signal_wire_149),
          .config$pull_threshold(signal_wire_148),
          .config$crc_width(signal_wire_147),
          .config$crc_poly(signal_wire_146),
          .config$crc_init(signal_wire_145),
          .config$crc_reflect(signal_wire_144),
          .config$stuff_threshold(signal_wire_143),
          .config$stuff_level(signal_wire_142),
          .config$wrap_bottom(signal_wire_141),
          .config$wrap_top(signal_wire_140),
          .config$period_fraction(signal_wire_139),
          .config$break_enable(signal_wire_138),
          .config$break_pc(signal_wire_137),
          .config$autopull_data(signal_wire_136),
          .config$manchester(signal_wire_135),
          .start(signal_wire_134),
          .program_write$valid(signal_wire_133),
          .program_write$addr(signal_wire_132),
          .program_write$data(signal_wire_131),
          .data_word(signal_select_76),
          .tx$valid(signal_wire_75),
          .tx$value(signal_wire_74),
          .rx_pop(signal_wire_73),
          .clear_irq(signal_wire_72),
          .stop(signal_wire_71),
          .flush(signal_wire_70),
          .resume(signal_wire_69),
          .single_step(signal_wire_68),
          .inputs(signal_or_5),
          .pin_out(signal_inst_2[27:0]),
          .pin_dir(signal_inst_2[55:28]),
          .pc(signal_inst_2[64:56]),
          .data_ptr(signal_inst_2[73:65]),
          .data_addr(signal_inst_2[82:74]),
          .x(signal_inst_2[98:83]),
          .y(signal_inst_2[114:99]),
          .p(signal_inst_2[130:115]),
          .t(signal_inst_2[154:131]),
          .t_fraction(signal_inst_2[170:155]),
          .osr(signal_inst_2[186:171]),
          .osr_count(signal_inst_2[191:187]),
          .isr(signal_inst_2[207:192]),
          .isr_count(signal_inst_2[212:208]),
          .now(signal_inst_2[236:213]),
          .stall(signal_inst_2[241:237]),
          .halted(signal_inst_2[242:242]),
          .resumed(signal_inst_2[243:243]),
          .stepping(signal_inst_2[244:244]),
          .irq(signal_inst_2[245:245]),
          .fault$underflow(signal_inst_2[246:246]),
          .fault$overflow(signal_inst_2[247:247]),
          .fault$missed_deadline(signal_inst_2[248:248]),
          .fault$decode(signal_inst_2[249:249]),
          .capture(signal_inst_2[273:250]),
          .capture_armed(signal_inst_2[274:274]),
          .tx_level(signal_inst_2[278:275]),
          .rx_level(signal_inst_2[282:279]),
          .rx_head(signal_inst_2[298:283]),
          .instruction(signal_inst_2[314:299]),
          .decode_ok(signal_inst_2[315:315]),
          .opcode_onehot(signal_inst_2[323:316]),
          .wait_select(signal_inst_2[351:324]),
          .crc(signal_inst_2[367:352]),
          .stuff_run(signal_inst_2[372:368]),
          .flip_pending(signal_inst_2[373:373]),
          .flip_bit(signal_inst_2[374:374]) );
    assign signal_select_77 = signal_inst_2[27:0];
    assign signal_wire_168 = signal_select_77;
    assign engines$pin_out_0 = signal_wire_168;
    assign engines$pin_dir_0 = signal_wire_84;
    assign engines$pc_0 = signal_wire_65;
    assign engines$data_ptr_0 = signal_wire_64;
    assign engines$data_addr_0 = signal_wire_77;
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
    assign engines$halted_0 = signal_wire_130;
    assign engines$resumed_0 = signal_wire_52;
    assign engines$stepping_0 = signal_wire_51;
    assign engines$irq_0 = signal_wire_50;
    assign engines$fault$underflow_0 = signal_wire_49;
    assign engines$fault$overflow_0 = signal_wire_48;
    assign engines$fault$missed_deadline_0 = signal_wire_47;
    assign engines$fault$decode_0 = signal_wire_46;
    assign engines$capture_0 = signal_wire_45;
    assign engines$capture_armed_0 = signal_wire_44;
    assign engines$tx_level_0 = signal_wire_43;
    assign engines$rx_level_0 = signal_wire_42;
    assign engines$rx_head_0 = signal_wire_41;
    assign engines$instruction_0 = signal_wire_40;
    assign engines$decode_ok_0 = signal_wire_39;
    assign engines$opcode_onehot_0 = signal_wire_38;
    assign engines$wait_select_0 = signal_wire_37;
    assign engines$crc_0 = signal_wire_36;
    assign engines$stuff_run_0 = signal_wire_35;
    assign engines$flip_pending_0 = signal_wire_34;
    assign engines$flip_bit_0 = signal_wire_33;
    assign engines$pin_out_1 = signal_wire_66;
    assign engines$pin_dir_1 = signal_wire_67;
    assign engines$pc_1 = signal_wire_32;
    assign engines$data_ptr_1 = signal_wire_31;
    assign engines$data_addr_1 = signal_wire_76;
    assign engines$x_1 = signal_wire_30;
    assign engines$y_1 = signal_wire_29;
    assign engines$p_1 = signal_wire_28;
    assign engines$t_1 = signal_wire_27;
    assign engines$t_fraction_1 = signal_wire_26;
    assign engines$osr_1 = signal_wire_25;
    assign engines$osr_count_1 = signal_wire_24;
    assign engines$isr_1 = signal_wire_23;
    assign engines$isr_count_1 = signal_wire_22;
    assign engines$now_1 = signal_wire_21;
    assign engines$stall_1 = signal_wire_20;
    assign engines$halted_1 = signal_wire_129;
    assign engines$resumed_1 = signal_wire_19;
    assign engines$stepping_1 = signal_wire_18;
    assign engines$irq_1 = signal_wire_17;
    assign engines$fault$underflow_1 = signal_wire_16;
    assign engines$fault$overflow_1 = signal_wire_15;
    assign engines$fault$missed_deadline_1 = signal_wire_14;
    assign engines$fault$decode_1 = signal_wire_13;
    assign engines$capture_1 = signal_wire_12;
    assign engines$capture_armed_1 = signal_wire_11;
    assign engines$tx_level_1 = signal_wire_10;
    assign engines$rx_level_1 = signal_wire_9;
    assign engines$rx_head_1 = signal_wire_8;
    assign engines$instruction_1 = signal_wire_7;
    assign engines$decode_ok_1 = signal_wire_6;
    assign engines$opcode_onehot_1 = signal_wire_5;
    assign engines$wait_select_1 = signal_wire_4;
    assign engines$crc_1 = signal_wire_3;
    assign engines$stuff_run_1 = signal_wire_2;
    assign engines$flip_pending_1 = signal_wire_1;
    assign engines$flip_bit_1 = signal_wire;
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
    wire signal_select_6;
    wire signal_eq_20;
    wire [6:0] signal_const_22;
    wire signal_eq_21;
    wire signal_and_26;
    wire signal_and_27;
    wire signal_mux;
    wire signal_mux_1;
    wire signal_wire;
    reg signal_reg;
    wire signal_select_7;
    wire signal_eq_22;
    wire [6:0] signal_const_25;
    wire signal_eq_23;
    wire signal_and_28;
    wire signal_and_29;
    wire signal_mux_2;
    wire signal_mux_3;
    wire signal_wire_1;
    reg signal_reg_1;
    wire [8:0] signal_const_26;
    wire [8:0] signal_select_8;
    wire signal_eq_24;
    wire [6:0] signal_const_28;
    wire signal_eq_25;
    wire signal_and_30;
    wire signal_and_31;
    wire [8:0] signal_mux_4;
    wire [8:0] signal_mux_5;
    wire [8:0] signal_wire_2;
    reg [8:0] signal_reg_2;
    wire signal_select_9;
    wire signal_eq_26;
    wire [6:0] signal_const_31;
    wire signal_eq_27;
    wire signal_and_32;
    wire signal_and_33;
    wire signal_mux_6;
    wire signal_mux_7;
    wire signal_wire_3;
    reg signal_reg_3;
    wire [15:0] signal_const_32;
    wire signal_eq_28;
    wire [6:0] signal_const_34;
    wire signal_eq_29;
    wire signal_and_34;
    wire signal_and_35;
    wire [15:0] signal_mux_8;
    wire [15:0] signal_mux_9;
    wire [15:0] signal_wire_4;
    reg [15:0] signal_reg_4;
    wire [8:0] signal_select_10;
    wire signal_eq_30;
    wire [6:0] signal_const_37;
    wire signal_eq_31;
    wire signal_and_36;
    wire signal_and_37;
    wire [8:0] signal_mux_10;
    wire [8:0] signal_mux_11;
    wire [8:0] signal_wire_5;
    reg [8:0] signal_reg_5;
    wire [8:0] signal_select_11;
    wire signal_eq_32;
    wire [6:0] signal_const_40;
    wire signal_eq_33;
    wire signal_and_38;
    wire signal_and_39;
    wire [8:0] signal_mux_12;
    wire [8:0] signal_mux_13;
    wire [8:0] signal_wire_6;
    reg [8:0] signal_reg_6;
    wire signal_select_12;
    wire signal_eq_34;
    wire [6:0] signal_const_43;
    wire signal_eq_35;
    wire signal_and_40;
    wire signal_and_41;
    wire signal_mux_14;
    wire signal_mux_15;
    wire signal_wire_7;
    reg signal_reg_7;
    wire [4:0] signal_const_44;
    wire [4:0] signal_select_13;
    wire signal_eq_36;
    wire [6:0] signal_const_46;
    wire signal_eq_37;
    wire signal_and_42;
    wire signal_and_43;
    wire [4:0] signal_mux_16;
    wire [4:0] signal_mux_17;
    wire [4:0] signal_wire_8;
    reg [4:0] signal_reg_8;
    wire signal_select_14;
    wire signal_eq_38;
    wire [6:0] signal_const_49;
    wire signal_eq_39;
    wire signal_and_44;
    wire signal_and_45;
    wire signal_mux_18;
    wire signal_mux_19;
    wire signal_wire_9;
    reg signal_reg_9;
    wire signal_eq_40;
    wire [6:0] signal_const_52;
    wire signal_eq_41;
    wire signal_and_46;
    wire signal_and_47;
    wire [15:0] signal_mux_20;
    wire [15:0] signal_mux_21;
    wire [15:0] signal_wire_10;
    reg [15:0] signal_reg_10;
    wire signal_eq_42;
    wire [6:0] signal_const_55;
    wire signal_eq_43;
    wire signal_and_48;
    wire signal_and_49;
    wire [15:0] signal_mux_22;
    wire [15:0] signal_mux_23;
    wire [15:0] signal_wire_11;
    reg [15:0] signal_reg_11;
    wire [4:0] signal_select_15;
    wire signal_eq_44;
    wire [6:0] signal_const_58;
    wire signal_eq_45;
    wire signal_and_50;
    wire signal_and_51;
    wire [4:0] signal_mux_24;
    wire [4:0] signal_mux_25;
    wire [4:0] signal_wire_12;
    reg [4:0] signal_reg_12;
    wire [4:0] signal_select_16;
    wire signal_eq_46;
    wire [6:0] signal_const_61;
    wire signal_eq_47;
    wire signal_and_52;
    wire signal_and_53;
    wire [4:0] signal_mux_26;
    wire [4:0] signal_mux_27;
    wire [4:0] signal_wire_13;
    reg [4:0] signal_reg_13;
    wire signal_select_17;
    wire signal_eq_48;
    wire [6:0] signal_const_64;
    wire signal_eq_49;
    wire signal_and_54;
    wire signal_and_55;
    wire signal_mux_28;
    wire signal_mux_29;
    wire signal_wire_14;
    reg signal_reg_14;
    wire [4:0] signal_select_18;
    wire signal_eq_50;
    wire [6:0] signal_const_67;
    wire signal_eq_51;
    wire signal_and_56;
    wire signal_and_57;
    wire [4:0] signal_mux_30;
    wire [4:0] signal_mux_31;
    wire [4:0] signal_wire_15;
    reg [4:0] signal_reg_15;
    wire signal_select_19;
    wire signal_eq_52;
    wire [6:0] signal_const_70;
    wire signal_eq_53;
    wire signal_and_58;
    wire signal_and_59;
    wire signal_mux_32;
    wire signal_mux_33;
    wire signal_wire_16;
    reg signal_reg_16;
    wire signal_select_20;
    wire signal_eq_54;
    wire [6:0] signal_const_73;
    wire signal_eq_55;
    wire signal_and_60;
    wire signal_and_61;
    wire signal_mux_34;
    wire signal_mux_35;
    wire signal_wire_17;
    reg signal_reg_17;
    wire signal_select_21;
    wire signal_eq_56;
    wire [6:0] signal_const_76;
    wire signal_eq_57;
    wire signal_and_62;
    wire signal_and_63;
    wire signal_mux_36;
    wire signal_mux_37;
    wire signal_wire_18;
    reg signal_reg_18;
    wire signal_select_22;
    wire signal_eq_58;
    wire [6:0] signal_const_79;
    wire signal_eq_59;
    wire signal_and_64;
    wire signal_and_65;
    wire signal_mux_38;
    wire signal_mux_39;
    wire signal_wire_19;
    reg signal_reg_19;
    wire [4:0] signal_select_23;
    wire signal_eq_60;
    wire [6:0] signal_const_82;
    wire signal_eq_61;
    wire signal_and_66;
    wire signal_and_67;
    wire [4:0] signal_mux_40;
    wire [4:0] signal_mux_41;
    wire [4:0] signal_wire_20;
    reg [4:0] signal_reg_20;
    wire [4:0] signal_select_24;
    wire signal_eq_62;
    wire [6:0] signal_const_85;
    wire signal_eq_63;
    wire signal_and_68;
    wire signal_and_69;
    wire [4:0] signal_mux_42;
    wire [4:0] signal_mux_43;
    wire [4:0] signal_wire_21;
    reg [4:0] signal_reg_21;
    wire [2:0] signal_const_86;
    wire [2:0] signal_select_25;
    wire signal_eq_64;
    wire [6:0] signal_const_88;
    wire signal_eq_65;
    wire signal_and_70;
    wire signal_and_71;
    wire [2:0] signal_mux_44;
    wire [2:0] signal_mux_45;
    wire [2:0] signal_wire_22;
    reg [2:0] signal_reg_22;
    wire [4:0] signal_select_26;
    wire signal_eq_66;
    wire [6:0] signal_const_91;
    wire signal_eq_67;
    wire signal_and_72;
    wire signal_and_73;
    wire [4:0] signal_mux_46;
    wire [4:0] signal_mux_47;
    wire [4:0] signal_wire_23;
    reg [4:0] signal_reg_23;
    wire [4:0] signal_select_27;
    wire signal_eq_68;
    wire [6:0] signal_const_94;
    wire signal_eq_69;
    wire signal_and_74;
    wire signal_and_75;
    wire [4:0] signal_mux_48;
    wire [4:0] signal_mux_49;
    wire [4:0] signal_wire_24;
    reg [4:0] signal_reg_24;
    wire [4:0] signal_select_28;
    wire signal_eq_70;
    wire [6:0] signal_const_97;
    wire signal_eq_71;
    wire signal_and_76;
    wire signal_and_77;
    wire [4:0] signal_mux_50;
    wire [4:0] signal_mux_51;
    wire [4:0] signal_wire_25;
    reg [4:0] signal_reg_25;
    wire [4:0] signal_select_29;
    wire signal_eq_72;
    wire [6:0] signal_const_100;
    wire signal_eq_73;
    wire signal_and_78;
    wire signal_and_79;
    wire [4:0] signal_mux_52;
    wire [4:0] signal_mux_53;
    wire [4:0] signal_wire_26;
    reg [4:0] signal_reg_26;
    wire [4:0] signal_select_30;
    wire signal_eq_74;
    wire [6:0] signal_const_103;
    wire signal_eq_75;
    wire signal_and_80;
    wire signal_and_81;
    wire [4:0] signal_mux_54;
    wire [4:0] signal_mux_55;
    wire [4:0] signal_wire_27;
    reg [4:0] signal_reg_27;
    wire signal_select_31;
    wire signal_eq_76;
    wire [6:0] signal_const_106;
    wire signal_eq_77;
    wire signal_and_82;
    wire signal_and_83;
    wire signal_mux_56;
    wire signal_mux_57;
    wire signal_wire_28;
    reg signal_reg_28;
    wire [4:0] signal_select_32;
    wire signal_eq_78;
    wire [6:0] signal_const_109;
    wire signal_eq_79;
    wire signal_and_84;
    wire signal_and_85;
    wire [4:0] signal_mux_58;
    wire [4:0] signal_mux_59;
    wire [4:0] signal_wire_29;
    reg [4:0] signal_reg_29;
    wire [1:0] signal_const_110;
    wire [1:0] signal_select_33;
    wire signal_eq_80;
    wire [6:0] signal_const_112;
    wire signal_eq_81;
    wire signal_and_86;
    wire signal_and_87;
    wire [1:0] signal_mux_60;
    wire [1:0] signal_mux_61;
    wire [1:0] signal_wire_30;
    reg [1:0] signal_reg_30;
    wire signal_eq_82;
    wire signal_select_34;
    wire signal_eq_83;
    wire signal_and_88;
    wire signal_and_89;
    wire signal_and_90;
    wire signal_eq_84;
    wire signal_select_35;
    wire signal_eq_85;
    wire signal_and_91;
    wire signal_and_92;
    wire signal_and_93;
    wire signal_eq_86;
    wire signal_select_36;
    wire signal_eq_87;
    wire signal_and_94;
    wire signal_and_95;
    wire signal_and_96;
    wire signal_eq_88;
    wire signal_select_37;
    wire signal_eq_89;
    wire signal_and_97;
    wire signal_and_98;
    wire signal_and_99;
    wire signal_eq_90;
    wire signal_select_38;
    wire signal_eq_91;
    wire signal_and_100;
    wire signal_and_101;
    wire signal_and_102;
    wire signal_eq_92;
    wire signal_eq_93;
    wire signal_and_103;
    wire signal_and_104;
    wire signal_eq_94;
    wire signal_eq_95;
    wire signal_and_105;
    wire signal_and_106;
    wire signal_eq_96;
    wire signal_eq_97;
    wire signal_and_107;
    wire signal_and_108;
    wire signal_eq_98;
    wire signal_eq_99;
    wire signal_and_109;
    wire signal_and_110;
    wire signal_eq_100;
    wire signal_select_39;
    wire signal_eq_101;
    wire signal_and_111;
    wire signal_and_112;
    wire signal_and_113;
    wire signal_select_40;
    wire signal_eq_102;
    wire signal_eq_103;
    wire signal_and_114;
    wire signal_and_115;
    wire signal_mux_62;
    wire signal_mux_63;
    wire signal_wire_31;
    reg signal_reg_31;
    wire signal_select_41;
    wire signal_eq_104;
    wire signal_eq_105;
    wire signal_and_116;
    wire signal_and_117;
    wire signal_mux_64;
    wire signal_mux_65;
    wire signal_wire_32;
    reg signal_reg_32;
    wire [8:0] signal_select_42;
    wire signal_eq_106;
    wire signal_eq_107;
    wire signal_and_118;
    wire signal_and_119;
    wire [8:0] signal_mux_66;
    wire [8:0] signal_mux_67;
    wire [8:0] signal_wire_33;
    reg [8:0] signal_reg_33;
    wire signal_select_43;
    wire signal_eq_108;
    wire signal_eq_109;
    wire signal_and_120;
    wire signal_and_121;
    wire signal_mux_68;
    wire signal_mux_69;
    wire signal_wire_34;
    reg signal_reg_34;
    wire signal_eq_110;
    wire signal_eq_111;
    wire signal_and_122;
    wire signal_and_123;
    wire [15:0] signal_mux_70;
    wire [15:0] signal_mux_71;
    wire [15:0] signal_wire_35;
    reg [15:0] signal_reg_35;
    wire [8:0] signal_select_44;
    wire signal_eq_112;
    wire signal_eq_113;
    wire signal_and_124;
    wire signal_and_125;
    wire [8:0] signal_mux_72;
    wire [8:0] signal_mux_73;
    wire [8:0] signal_wire_36;
    reg [8:0] signal_reg_36;
    wire [8:0] signal_select_45;
    wire signal_eq_114;
    wire signal_eq_115;
    wire signal_and_126;
    wire signal_and_127;
    wire [8:0] signal_mux_74;
    wire [8:0] signal_mux_75;
    wire [8:0] signal_wire_37;
    reg [8:0] signal_reg_37;
    wire signal_select_46;
    wire signal_eq_116;
    wire signal_eq_117;
    wire signal_and_128;
    wire signal_and_129;
    wire signal_mux_76;
    wire signal_mux_77;
    wire signal_wire_38;
    reg signal_reg_38;
    wire [4:0] signal_select_47;
    wire signal_eq_118;
    wire signal_eq_119;
    wire signal_and_130;
    wire signal_and_131;
    wire [4:0] signal_mux_78;
    wire [4:0] signal_mux_79;
    wire [4:0] signal_wire_39;
    reg [4:0] signal_reg_39;
    wire signal_select_48;
    wire signal_eq_120;
    wire signal_eq_121;
    wire signal_and_132;
    wire signal_and_133;
    wire signal_mux_80;
    wire signal_mux_81;
    wire signal_wire_40;
    reg signal_reg_40;
    wire signal_eq_122;
    wire signal_eq_123;
    wire signal_and_134;
    wire signal_and_135;
    wire [15:0] signal_mux_82;
    wire [15:0] signal_mux_83;
    wire [15:0] signal_wire_41;
    reg [15:0] signal_reg_41;
    wire signal_eq_124;
    wire signal_eq_125;
    wire signal_and_136;
    wire signal_and_137;
    wire [15:0] signal_mux_84;
    wire [15:0] signal_mux_85;
    wire [15:0] signal_wire_42;
    reg [15:0] signal_reg_42;
    wire [4:0] signal_select_49;
    wire signal_eq_126;
    wire signal_eq_127;
    wire signal_and_138;
    wire signal_and_139;
    wire [4:0] signal_mux_86;
    wire [4:0] signal_mux_87;
    wire [4:0] signal_wire_43;
    reg [4:0] signal_reg_43;
    wire [4:0] signal_select_50;
    wire signal_eq_128;
    wire signal_eq_129;
    wire signal_and_140;
    wire signal_and_141;
    wire [4:0] signal_mux_88;
    wire [4:0] signal_mux_89;
    wire [4:0] signal_wire_44;
    reg [4:0] signal_reg_44;
    wire signal_select_51;
    wire signal_eq_130;
    wire signal_eq_131;
    wire signal_and_142;
    wire signal_and_143;
    wire signal_mux_90;
    wire signal_mux_91;
    wire signal_wire_45;
    reg signal_reg_45;
    wire [4:0] signal_select_52;
    wire signal_eq_132;
    wire signal_eq_133;
    wire signal_and_144;
    wire signal_and_145;
    wire [4:0] signal_mux_92;
    wire [4:0] signal_mux_93;
    wire [4:0] signal_wire_46;
    reg [4:0] signal_reg_46;
    wire signal_select_53;
    wire signal_eq_134;
    wire signal_eq_135;
    wire signal_and_146;
    wire signal_and_147;
    wire signal_mux_94;
    wire signal_mux_95;
    wire signal_wire_47;
    reg signal_reg_47;
    wire signal_select_54;
    wire signal_eq_136;
    wire signal_eq_137;
    wire signal_and_148;
    wire signal_and_149;
    wire signal_mux_96;
    wire signal_mux_97;
    wire signal_wire_48;
    reg signal_reg_48;
    wire signal_select_55;
    wire signal_eq_138;
    wire signal_eq_139;
    wire signal_and_150;
    wire signal_and_151;
    wire signal_mux_98;
    wire signal_mux_99;
    wire signal_wire_49;
    reg signal_reg_49;
    wire signal_select_56;
    wire signal_eq_140;
    wire signal_eq_141;
    wire signal_and_152;
    wire signal_and_153;
    wire signal_mux_100;
    wire signal_mux_101;
    wire signal_wire_50;
    reg signal_reg_50;
    wire [4:0] signal_select_57;
    wire signal_eq_142;
    wire signal_eq_143;
    wire signal_and_154;
    wire signal_and_155;
    wire [4:0] signal_mux_102;
    wire [4:0] signal_mux_103;
    wire [4:0] signal_wire_51;
    reg [4:0] signal_reg_51;
    wire [4:0] signal_select_58;
    wire signal_eq_144;
    wire signal_eq_145;
    wire signal_and_156;
    wire signal_and_157;
    wire [4:0] signal_mux_104;
    wire [4:0] signal_mux_105;
    wire [4:0] signal_wire_52;
    reg [4:0] signal_reg_52;
    wire [2:0] signal_select_59;
    wire signal_eq_146;
    wire signal_eq_147;
    wire signal_and_158;
    wire signal_and_159;
    wire [2:0] signal_mux_106;
    wire [2:0] signal_mux_107;
    wire [2:0] signal_wire_53;
    reg [2:0] signal_reg_53;
    wire [4:0] signal_select_60;
    wire signal_eq_148;
    wire signal_eq_149;
    wire signal_and_160;
    wire signal_and_161;
    wire [4:0] signal_mux_108;
    wire [4:0] signal_mux_109;
    wire [4:0] signal_wire_54;
    reg [4:0] signal_reg_54;
    wire [4:0] signal_select_61;
    wire signal_eq_150;
    wire signal_eq_151;
    wire signal_and_162;
    wire signal_and_163;
    wire [4:0] signal_mux_110;
    wire [4:0] signal_mux_111;
    wire [4:0] signal_wire_55;
    reg [4:0] signal_reg_55;
    wire [4:0] signal_select_62;
    wire signal_eq_152;
    wire signal_eq_153;
    wire signal_and_164;
    wire signal_and_165;
    wire [4:0] signal_mux_112;
    wire [4:0] signal_mux_113;
    wire [4:0] signal_wire_56;
    reg [4:0] signal_reg_56;
    wire [4:0] signal_select_63;
    wire signal_eq_154;
    wire signal_eq_155;
    wire signal_and_166;
    wire signal_and_167;
    wire [4:0] signal_mux_114;
    wire [4:0] signal_mux_115;
    wire [4:0] signal_wire_57;
    reg [4:0] signal_reg_57;
    wire [4:0] signal_select_64;
    wire signal_eq_156;
    wire signal_eq_157;
    wire signal_and_168;
    wire signal_and_169;
    wire [4:0] signal_mux_116;
    wire [4:0] signal_mux_117;
    wire [4:0] signal_wire_58;
    reg [4:0] signal_reg_58;
    wire signal_select_65;
    wire signal_eq_158;
    wire signal_eq_159;
    wire signal_and_170;
    wire signal_and_171;
    wire signal_mux_118;
    wire signal_mux_119;
    wire signal_wire_59;
    reg signal_reg_59;
    wire [4:0] signal_select_66;
    wire signal_eq_160;
    wire signal_eq_161;
    wire signal_and_172;
    wire signal_and_173;
    wire [4:0] signal_mux_120;
    wire [4:0] signal_mux_121;
    wire [4:0] signal_wire_60;
    reg [4:0] signal_reg_60;
    wire [1:0] signal_select_67;
    wire signal_eq_162;
    wire signal_eq_163;
    wire signal_and_174;
    wire signal_and_175;
    wire [1:0] signal_mux_122;
    wire [1:0] signal_mux_123;
    wire [1:0] signal_wire_61;
    reg [1:0] signal_reg_61;
    wire [7:0] signal_select_68;
    wire [15:0] rx_head;
    wire [4:0] signal_wire_62;
    wire [7:0] signal_cat;
    wire [4:0] signal_wire_63;
    wire [12:0] signal_cat_1;
    wire [15:0] signal_cat_2;
    wire [15:0] signal_wire_64;
    wire [15:0] signal_wire_65;
    wire [7:0] signal_select_69;
    wire [7:0] signal_const_233;
    wire [15:0] signal_cat_3;
    wire [23:0] signal_wire_66;
    wire [15:0] signal_select_70;
    wire [15:0] signal_wire_67;
    wire [15:0] signal_wire_68;
    wire [15:0] signal_wire_69;
    wire [15:0] signal_wire_70;
    wire [7:0] signal_select_71;
    wire [15:0] signal_cat_4;
    wire [23:0] signal_wire_71;
    wire [15:0] signal_select_72;
    wire [7:0] signal_select_73;
    wire [15:0] signal_cat_5;
    wire [23:0] signal_wire_72;
    wire [15:0] signal_select_74;
    wire [8:0] signal_wire_73;
    wire [15:0] signal_cat_6;
    wire signal_wire_74;
    wire signal_wire_75;
    wire signal_wire_76;
    wire signal_wire_77;
    wire signal_wire_78;
    wire [3:0] signal_wire_79;
    wire [3:0] signal_wire_80;
    wire [15:0] signal_cat_7;
    reg [15:0] signal_cases;
    wire [4:0] signal_wire_81;
    wire [7:0] signal_cat_8;
    wire [4:0] signal_wire_82;
    wire [12:0] signal_cat_9;
    wire [15:0] signal_cat_10;
    wire [15:0] signal_wire_83;
    wire [15:0] signal_wire_84;
    wire [7:0] signal_select_75;
    wire [15:0] signal_cat_11;
    wire [23:0] signal_wire_85;
    wire [15:0] signal_select_76;
    wire [15:0] signal_wire_86;
    wire [15:0] signal_wire_87;
    wire [15:0] signal_wire_88;
    wire [15:0] signal_wire_89;
    wire [7:0] signal_select_77;
    wire [15:0] signal_cat_12;
    wire [23:0] signal_wire_90;
    wire [15:0] signal_select_78;
    wire [7:0] signal_select_79;
    wire [15:0] signal_cat_13;
    wire [23:0] signal_wire_91;
    wire [15:0] signal_select_80;
    wire [8:0] signal_wire_92;
    wire [15:0] signal_cat_14;
    wire signal_wire_93;
    wire signal_wire_94;
    wire signal_wire_95;
    wire signal_wire_96;
    wire signal_wire_97;
    wire signal_wire_98;
    wire [3:0] signal_wire_99;
    wire [3:0] signal_wire_100;
    wire signal_wire_101;
    wire [15:0] signal_cat_15;
    reg [15:0] signal_cases_1;
    wire [15:0] signal_mux_124;
    wire signal_select_81;
    wire [6:0] signal_const_274;
    wire signal_eq_164;
    wire signal_mux_125;
    wire signal_mux_126;
    wire signal_wire_102;
    reg select;
    wire [14:0] signal_const_275;
    wire [15:0] signal_cat_16;
    wire [8:0] signal_const_278;
    wire [8:0] signal_add;
    wire [8:0] signal_select_82;
    wire [6:0] signal_const_279;
    wire signal_eq_165;
    wire [8:0] signal_mux_127;
    wire signal_eq_166;
    wire [8:0] signal_mux_128;
    wire [8:0] signal_mux_129;
    wire [8:0] signal_wire_103;
    reg [8:0] data_addr;
    wire [15:0] signal_cat_17;
    wire [8:0] signal_add_1;
    reg [7:0] signal_cases_2;
    wire [7:0] signal_mux_130;
    wire [7:0] signal_wire_104;
    reg [7:0] high;
    wire [15:0] value;
    wire [8:0] signal_select_83;
    wire [6:0] signal_const_286;
    wire signal_eq_167;
    wire [8:0] signal_mux_131;
    wire signal_eq_168;
    wire [8:0] signal_mux_132;
    wire signal_mux_133;
    reg signal_cases_3;
    wire signal_mux_134;
    wire write;
    wire [8:0] signal_mux_135;
    wire [8:0] signal_wire_105;
    reg [8:0] program_addr;
    wire [15:0] signal_cat_18;
    wire [7:0] spi_rx_byte;
    wire [6:0] signal_select_84;
    wire signal_eq_169;
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
    wire [15:0] signal_wire_106;
    reg [15:0] word;
    wire [7:0] signal_select_85;
    reg [7:0] signal_cases_6;
    wire [7:0] signal_mux_140;
    wire [7:0] signal_wire_107;
    reg [7:0] cmd;
    wire [6:0] addr;
    wire signal_eq_170;
    wire [15:0] tx_word;
    wire [7:0] signal_select_86;
    wire [1:0] signal_const_293;
    reg [1:0] signal_cases_7;
    wire signal_select_87;
    wire [1:0] signal_mux_141;
    wire signal_select_88;
    wire [1:0] signal_mux_142;
    wire [1:0] signal_wire_108;
    (* fsm_encoding="one_hot" *)
    reg [1:0] sm;
    wire [1:0] signal_const_295;
    wire signal_eq_171;
    wire [7:0] signal_mux_143;
    wire signal_wire_109;
    wire signal_wire_110;
    wire signal_wire_111;
    wire signal_wire_112;
    wire signal_wire_113;
    wire [11:0] signal_inst;
    wire signal_select_89;
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
    assign signal_select_6 = value[0:0];
    assign signal_eq_20 = select == signal_const;
    assign signal_const_22 = 7'b0101110;
    assign signal_eq_21 = addr == signal_const_22;
    assign signal_and_26 = signal_eq_21 & signal_eq_20;
    assign signal_and_27 = signal_and_26 & signal_wire_74;
    assign signal_mux = signal_and_27 ? signal_select_6 : signal_reg;
    assign signal_mux_1 = write ? signal_mux : signal_reg;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg <= signal_const_20;
        else
            signal_reg <= signal_wire;
    end
    assign signal_select_7 = value[0:0];
    assign signal_eq_22 = select == signal_const;
    assign signal_const_25 = 7'b0101101;
    assign signal_eq_23 = addr == signal_const_25;
    assign signal_and_28 = signal_eq_23 & signal_eq_22;
    assign signal_and_29 = signal_and_28 & signal_wire_74;
    assign signal_mux_2 = signal_and_29 ? signal_select_7 : signal_reg_1;
    assign signal_mux_3 = write ? signal_mux_2 : signal_reg_1;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_1 <= signal_const_20;
        else
            signal_reg_1 <= signal_wire_1;
    end
    assign signal_const_26 = 9'b000000000;
    assign signal_select_8 = value[8:0];
    assign signal_eq_24 = select == signal_const;
    assign signal_const_28 = 7'b0101100;
    assign signal_eq_25 = addr == signal_const_28;
    assign signal_and_30 = signal_eq_25 & signal_eq_24;
    assign signal_and_31 = signal_and_30 & signal_wire_74;
    assign signal_mux_4 = signal_and_31 ? signal_select_8 : signal_reg_2;
    assign signal_mux_5 = write ? signal_mux_4 : signal_reg_2;
    assign signal_wire_2 = signal_mux_5;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_2 <= signal_const_26;
        else
            signal_reg_2 <= signal_wire_2;
    end
    assign signal_select_9 = value[0:0];
    assign signal_eq_26 = select == signal_const;
    assign signal_const_31 = 7'b0101011;
    assign signal_eq_27 = addr == signal_const_31;
    assign signal_and_32 = signal_eq_27 & signal_eq_26;
    assign signal_and_33 = signal_and_32 & signal_wire_74;
    assign signal_mux_6 = signal_and_33 ? signal_select_9 : signal_reg_3;
    assign signal_mux_7 = write ? signal_mux_6 : signal_reg_3;
    assign signal_wire_3 = signal_mux_7;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_3 <= signal_const_20;
        else
            signal_reg_3 <= signal_wire_3;
    end
    assign signal_const_32 = 16'b0000000000000000;
    assign signal_eq_28 = select == signal_const;
    assign signal_const_34 = 7'b0101010;
    assign signal_eq_29 = addr == signal_const_34;
    assign signal_and_34 = signal_eq_29 & signal_eq_28;
    assign signal_and_35 = signal_and_34 & signal_wire_74;
    assign signal_mux_8 = signal_and_35 ? value : signal_reg_4;
    assign signal_mux_9 = write ? signal_mux_8 : signal_reg_4;
    assign signal_wire_4 = signal_mux_9;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_4 <= signal_const_32;
        else
            signal_reg_4 <= signal_wire_4;
    end
    assign signal_select_10 = value[8:0];
    assign signal_eq_30 = select == signal_const;
    assign signal_const_37 = 7'b0101001;
    assign signal_eq_31 = addr == signal_const_37;
    assign signal_and_36 = signal_eq_31 & signal_eq_30;
    assign signal_and_37 = signal_and_36 & signal_wire_74;
    assign signal_mux_10 = signal_and_37 ? signal_select_10 : signal_reg_5;
    assign signal_mux_11 = write ? signal_mux_10 : signal_reg_5;
    assign signal_wire_5 = signal_mux_11;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_5 <= signal_const_26;
        else
            signal_reg_5 <= signal_wire_5;
    end
    assign signal_select_11 = value[8:0];
    assign signal_eq_32 = select == signal_const;
    assign signal_const_40 = 7'b0101000;
    assign signal_eq_33 = addr == signal_const_40;
    assign signal_and_38 = signal_eq_33 & signal_eq_32;
    assign signal_and_39 = signal_and_38 & signal_wire_74;
    assign signal_mux_12 = signal_and_39 ? signal_select_11 : signal_reg_6;
    assign signal_mux_13 = write ? signal_mux_12 : signal_reg_6;
    assign signal_wire_6 = signal_mux_13;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_6 <= signal_const_26;
        else
            signal_reg_6 <= signal_wire_6;
    end
    assign signal_select_12 = value[0:0];
    assign signal_eq_34 = select == signal_const;
    assign signal_const_43 = 7'b0100111;
    assign signal_eq_35 = addr == signal_const_43;
    assign signal_and_40 = signal_eq_35 & signal_eq_34;
    assign signal_and_41 = signal_and_40 & signal_wire_74;
    assign signal_mux_14 = signal_and_41 ? signal_select_12 : signal_reg_7;
    assign signal_mux_15 = write ? signal_mux_14 : signal_reg_7;
    assign signal_wire_7 = signal_mux_15;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_7 <= signal_const_20;
        else
            signal_reg_7 <= signal_wire_7;
    end
    assign signal_const_44 = 5'b00000;
    assign signal_select_13 = value[4:0];
    assign signal_eq_36 = select == signal_const;
    assign signal_const_46 = 7'b0100110;
    assign signal_eq_37 = addr == signal_const_46;
    assign signal_and_42 = signal_eq_37 & signal_eq_36;
    assign signal_and_43 = signal_and_42 & signal_wire_74;
    assign signal_mux_16 = signal_and_43 ? signal_select_13 : signal_reg_8;
    assign signal_mux_17 = write ? signal_mux_16 : signal_reg_8;
    assign signal_wire_8 = signal_mux_17;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_8 <= signal_const_44;
        else
            signal_reg_8 <= signal_wire_8;
    end
    assign signal_select_14 = value[0:0];
    assign signal_eq_38 = select == signal_const;
    assign signal_const_49 = 7'b0100101;
    assign signal_eq_39 = addr == signal_const_49;
    assign signal_and_44 = signal_eq_39 & signal_eq_38;
    assign signal_and_45 = signal_and_44 & signal_wire_74;
    assign signal_mux_18 = signal_and_45 ? signal_select_14 : signal_reg_9;
    assign signal_mux_19 = write ? signal_mux_18 : signal_reg_9;
    assign signal_wire_9 = signal_mux_19;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_9 <= signal_const_20;
        else
            signal_reg_9 <= signal_wire_9;
    end
    assign signal_eq_40 = select == signal_const;
    assign signal_const_52 = 7'b0100100;
    assign signal_eq_41 = addr == signal_const_52;
    assign signal_and_46 = signal_eq_41 & signal_eq_40;
    assign signal_and_47 = signal_and_46 & signal_wire_74;
    assign signal_mux_20 = signal_and_47 ? value : signal_reg_10;
    assign signal_mux_21 = write ? signal_mux_20 : signal_reg_10;
    assign signal_wire_10 = signal_mux_21;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_10 <= signal_const_32;
        else
            signal_reg_10 <= signal_wire_10;
    end
    assign signal_eq_42 = select == signal_const;
    assign signal_const_55 = 7'b0100011;
    assign signal_eq_43 = addr == signal_const_55;
    assign signal_and_48 = signal_eq_43 & signal_eq_42;
    assign signal_and_49 = signal_and_48 & signal_wire_74;
    assign signal_mux_22 = signal_and_49 ? value : signal_reg_11;
    assign signal_mux_23 = write ? signal_mux_22 : signal_reg_11;
    assign signal_wire_11 = signal_mux_23;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_11 <= signal_const_32;
        else
            signal_reg_11 <= signal_wire_11;
    end
    assign signal_select_15 = value[4:0];
    assign signal_eq_44 = select == signal_const;
    assign signal_const_58 = 7'b0100010;
    assign signal_eq_45 = addr == signal_const_58;
    assign signal_and_50 = signal_eq_45 & signal_eq_44;
    assign signal_and_51 = signal_and_50 & signal_wire_74;
    assign signal_mux_24 = signal_and_51 ? signal_select_15 : signal_reg_12;
    assign signal_mux_25 = write ? signal_mux_24 : signal_reg_12;
    assign signal_wire_12 = signal_mux_25;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_12 <= signal_const_44;
        else
            signal_reg_12 <= signal_wire_12;
    end
    assign signal_select_16 = value[4:0];
    assign signal_eq_46 = select == signal_const;
    assign signal_const_61 = 7'b0100001;
    assign signal_eq_47 = addr == signal_const_61;
    assign signal_and_52 = signal_eq_47 & signal_eq_46;
    assign signal_and_53 = signal_and_52 & signal_wire_74;
    assign signal_mux_26 = signal_and_53 ? signal_select_16 : signal_reg_13;
    assign signal_mux_27 = write ? signal_mux_26 : signal_reg_13;
    assign signal_wire_13 = signal_mux_27;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_13 <= signal_const_44;
        else
            signal_reg_13 <= signal_wire_13;
    end
    assign signal_select_17 = value[0:0];
    assign signal_eq_48 = select == signal_const;
    assign signal_const_64 = 7'b0100000;
    assign signal_eq_49 = addr == signal_const_64;
    assign signal_and_54 = signal_eq_49 & signal_eq_48;
    assign signal_and_55 = signal_and_54 & signal_wire_74;
    assign signal_mux_28 = signal_and_55 ? signal_select_17 : signal_reg_14;
    assign signal_mux_29 = write ? signal_mux_28 : signal_reg_14;
    assign signal_wire_14 = signal_mux_29;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_14 <= signal_const_20;
        else
            signal_reg_14 <= signal_wire_14;
    end
    assign signal_select_18 = value[4:0];
    assign signal_eq_50 = select == signal_const;
    assign signal_const_67 = 7'b0011111;
    assign signal_eq_51 = addr == signal_const_67;
    assign signal_and_56 = signal_eq_51 & signal_eq_50;
    assign signal_and_57 = signal_and_56 & signal_wire_74;
    assign signal_mux_30 = signal_and_57 ? signal_select_18 : signal_reg_15;
    assign signal_mux_31 = write ? signal_mux_30 : signal_reg_15;
    assign signal_wire_15 = signal_mux_31;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_15 <= signal_const_44;
        else
            signal_reg_15 <= signal_wire_15;
    end
    assign signal_select_19 = value[0:0];
    assign signal_eq_52 = select == signal_const;
    assign signal_const_70 = 7'b0011110;
    assign signal_eq_53 = addr == signal_const_70;
    assign signal_and_58 = signal_eq_53 & signal_eq_52;
    assign signal_and_59 = signal_and_58 & signal_wire_74;
    assign signal_mux_32 = signal_and_59 ? signal_select_19 : signal_reg_16;
    assign signal_mux_33 = write ? signal_mux_32 : signal_reg_16;
    assign signal_wire_16 = signal_mux_33;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_16 <= signal_const_20;
        else
            signal_reg_16 <= signal_wire_16;
    end
    assign signal_select_20 = value[0:0];
    assign signal_eq_54 = select == signal_const;
    assign signal_const_73 = 7'b0011101;
    assign signal_eq_55 = addr == signal_const_73;
    assign signal_and_60 = signal_eq_55 & signal_eq_54;
    assign signal_and_61 = signal_and_60 & signal_wire_74;
    assign signal_mux_34 = signal_and_61 ? signal_select_20 : signal_reg_17;
    assign signal_mux_35 = write ? signal_mux_34 : signal_reg_17;
    assign signal_wire_17 = signal_mux_35;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_17 <= signal_const_20;
        else
            signal_reg_17 <= signal_wire_17;
    end
    assign signal_select_21 = value[0:0];
    assign signal_eq_56 = select == signal_const;
    assign signal_const_76 = 7'b0011100;
    assign signal_eq_57 = addr == signal_const_76;
    assign signal_and_62 = signal_eq_57 & signal_eq_56;
    assign signal_and_63 = signal_and_62 & signal_wire_74;
    assign signal_mux_36 = signal_and_63 ? signal_select_21 : signal_reg_18;
    assign signal_mux_37 = write ? signal_mux_36 : signal_reg_18;
    assign signal_wire_18 = signal_mux_37;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_18 <= signal_const_20;
        else
            signal_reg_18 <= signal_wire_18;
    end
    assign signal_select_22 = value[0:0];
    assign signal_eq_58 = select == signal_const;
    assign signal_const_79 = 7'b0011011;
    assign signal_eq_59 = addr == signal_const_79;
    assign signal_and_64 = signal_eq_59 & signal_eq_58;
    assign signal_and_65 = signal_and_64 & signal_wire_74;
    assign signal_mux_38 = signal_and_65 ? signal_select_22 : signal_reg_19;
    assign signal_mux_39 = write ? signal_mux_38 : signal_reg_19;
    assign signal_wire_19 = signal_mux_39;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_19 <= signal_const_20;
        else
            signal_reg_19 <= signal_wire_19;
    end
    assign signal_select_23 = value[4:0];
    assign signal_eq_60 = select == signal_const;
    assign signal_const_82 = 7'b0011010;
    assign signal_eq_61 = addr == signal_const_82;
    assign signal_and_66 = signal_eq_61 & signal_eq_60;
    assign signal_and_67 = signal_and_66 & signal_wire_74;
    assign signal_mux_40 = signal_and_67 ? signal_select_23 : signal_reg_20;
    assign signal_mux_41 = write ? signal_mux_40 : signal_reg_20;
    assign signal_wire_20 = signal_mux_41;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_20 <= signal_const_44;
        else
            signal_reg_20 <= signal_wire_20;
    end
    assign signal_select_24 = value[4:0];
    assign signal_eq_62 = select == signal_const;
    assign signal_const_85 = 7'b0011001;
    assign signal_eq_63 = addr == signal_const_85;
    assign signal_and_68 = signal_eq_63 & signal_eq_62;
    assign signal_and_69 = signal_and_68 & signal_wire_74;
    assign signal_mux_42 = signal_and_69 ? signal_select_24 : signal_reg_21;
    assign signal_mux_43 = write ? signal_mux_42 : signal_reg_21;
    assign signal_wire_21 = signal_mux_43;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_21 <= signal_const_44;
        else
            signal_reg_21 <= signal_wire_21;
    end
    assign signal_const_86 = 3'b000;
    assign signal_select_25 = value[2:0];
    assign signal_eq_64 = select == signal_const;
    assign signal_const_88 = 7'b0011000;
    assign signal_eq_65 = addr == signal_const_88;
    assign signal_and_70 = signal_eq_65 & signal_eq_64;
    assign signal_and_71 = signal_and_70 & signal_wire_74;
    assign signal_mux_44 = signal_and_71 ? signal_select_25 : signal_reg_22;
    assign signal_mux_45 = write ? signal_mux_44 : signal_reg_22;
    assign signal_wire_22 = signal_mux_45;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_22 <= signal_const_86;
        else
            signal_reg_22 <= signal_wire_22;
    end
    assign signal_select_26 = value[4:0];
    assign signal_eq_66 = select == signal_const;
    assign signal_const_91 = 7'b0010111;
    assign signal_eq_67 = addr == signal_const_91;
    assign signal_and_72 = signal_eq_67 & signal_eq_66;
    assign signal_and_73 = signal_and_72 & signal_wire_74;
    assign signal_mux_46 = signal_and_73 ? signal_select_26 : signal_reg_23;
    assign signal_mux_47 = write ? signal_mux_46 : signal_reg_23;
    assign signal_wire_23 = signal_mux_47;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_23 <= signal_const_44;
        else
            signal_reg_23 <= signal_wire_23;
    end
    assign signal_select_27 = value[4:0];
    assign signal_eq_68 = select == signal_const;
    assign signal_const_94 = 7'b0010110;
    assign signal_eq_69 = addr == signal_const_94;
    assign signal_and_74 = signal_eq_69 & signal_eq_68;
    assign signal_and_75 = signal_and_74 & signal_wire_74;
    assign signal_mux_48 = signal_and_75 ? signal_select_27 : signal_reg_24;
    assign signal_mux_49 = write ? signal_mux_48 : signal_reg_24;
    assign signal_wire_24 = signal_mux_49;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_24 <= signal_const_44;
        else
            signal_reg_24 <= signal_wire_24;
    end
    assign signal_select_28 = value[4:0];
    assign signal_eq_70 = select == signal_const;
    assign signal_const_97 = 7'b0010101;
    assign signal_eq_71 = addr == signal_const_97;
    assign signal_and_76 = signal_eq_71 & signal_eq_70;
    assign signal_and_77 = signal_and_76 & signal_wire_74;
    assign signal_mux_50 = signal_and_77 ? signal_select_28 : signal_reg_25;
    assign signal_mux_51 = write ? signal_mux_50 : signal_reg_25;
    assign signal_wire_25 = signal_mux_51;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_25 <= signal_const_44;
        else
            signal_reg_25 <= signal_wire_25;
    end
    assign signal_select_29 = value[4:0];
    assign signal_eq_72 = select == signal_const;
    assign signal_const_100 = 7'b0010100;
    assign signal_eq_73 = addr == signal_const_100;
    assign signal_and_78 = signal_eq_73 & signal_eq_72;
    assign signal_and_79 = signal_and_78 & signal_wire_74;
    assign signal_mux_52 = signal_and_79 ? signal_select_29 : signal_reg_26;
    assign signal_mux_53 = write ? signal_mux_52 : signal_reg_26;
    assign signal_wire_26 = signal_mux_53;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_26 <= signal_const_44;
        else
            signal_reg_26 <= signal_wire_26;
    end
    assign signal_select_30 = value[4:0];
    assign signal_eq_74 = select == signal_const;
    assign signal_const_103 = 7'b0010011;
    assign signal_eq_75 = addr == signal_const_103;
    assign signal_and_80 = signal_eq_75 & signal_eq_74;
    assign signal_and_81 = signal_and_80 & signal_wire_74;
    assign signal_mux_54 = signal_and_81 ? signal_select_30 : signal_reg_27;
    assign signal_mux_55 = write ? signal_mux_54 : signal_reg_27;
    assign signal_wire_27 = signal_mux_55;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_27 <= signal_const_44;
        else
            signal_reg_27 <= signal_wire_27;
    end
    assign signal_select_31 = value[0:0];
    assign signal_eq_76 = select == signal_const;
    assign signal_const_106 = 7'b0010010;
    assign signal_eq_77 = addr == signal_const_106;
    assign signal_and_82 = signal_eq_77 & signal_eq_76;
    assign signal_and_83 = signal_and_82 & signal_wire_74;
    assign signal_mux_56 = signal_and_83 ? signal_select_31 : signal_reg_28;
    assign signal_mux_57 = write ? signal_mux_56 : signal_reg_28;
    assign signal_wire_28 = signal_mux_57;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_28 <= signal_const_20;
        else
            signal_reg_28 <= signal_wire_28;
    end
    assign signal_select_32 = value[4:0];
    assign signal_eq_78 = select == signal_const;
    assign signal_const_109 = 7'b0010001;
    assign signal_eq_79 = addr == signal_const_109;
    assign signal_and_84 = signal_eq_79 & signal_eq_78;
    assign signal_and_85 = signal_and_84 & signal_wire_74;
    assign signal_mux_58 = signal_and_85 ? signal_select_32 : signal_reg_29;
    assign signal_mux_59 = write ? signal_mux_58 : signal_reg_29;
    assign signal_wire_29 = signal_mux_59;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_29 <= signal_const_44;
        else
            signal_reg_29 <= signal_wire_29;
    end
    assign signal_const_110 = 2'b00;
    assign signal_select_33 = value[1:0];
    assign signal_eq_80 = select == signal_const;
    assign signal_const_112 = 7'b0010000;
    assign signal_eq_81 = addr == signal_const_112;
    assign signal_and_86 = signal_eq_81 & signal_eq_80;
    assign signal_and_87 = signal_and_86 & signal_wire_74;
    assign signal_mux_60 = signal_and_87 ? signal_select_33 : signal_reg_30;
    assign signal_mux_61 = write ? signal_mux_60 : signal_reg_30;
    assign signal_wire_30 = signal_mux_61;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_30 <= signal_const_110;
        else
            signal_reg_30 <= signal_wire_30;
    end
    assign signal_eq_82 = select == signal_const_20;
    assign signal_select_34 = value[5:5];
    assign signal_eq_83 = addr == signal_const_1;
    assign signal_and_88 = write & signal_eq_83;
    assign signal_and_89 = signal_and_88 & signal_select_34;
    assign signal_and_90 = signal_and_89 & signal_eq_82;
    assign signal_eq_84 = select == signal_const_20;
    assign signal_select_35 = value[4:4];
    assign signal_eq_85 = addr == signal_const_1;
    assign signal_and_91 = write & signal_eq_85;
    assign signal_and_92 = signal_and_91 & signal_select_35;
    assign signal_and_93 = signal_and_92 & signal_eq_84;
    assign signal_eq_86 = select == signal_const_20;
    assign signal_select_36 = value[3:3];
    assign signal_eq_87 = addr == signal_const_1;
    assign signal_and_94 = write & signal_eq_87;
    assign signal_and_95 = signal_and_94 & signal_select_36;
    assign signal_and_96 = signal_and_95 & signal_eq_86;
    assign signal_eq_88 = select == signal_const_20;
    assign signal_select_37 = value[2:2];
    assign signal_eq_89 = addr == signal_const_1;
    assign signal_and_97 = write & signal_eq_89;
    assign signal_and_98 = signal_and_97 & signal_select_37;
    assign signal_and_99 = signal_and_98 & signal_eq_88;
    assign signal_eq_90 = select == signal_const_20;
    assign signal_select_38 = value[1:1];
    assign signal_eq_91 = addr == signal_const_1;
    assign signal_and_100 = write & signal_eq_91;
    assign signal_and_101 = signal_and_100 & signal_select_38;
    assign signal_and_102 = signal_and_101 & signal_eq_90;
    assign signal_eq_92 = select == signal_const_20;
    assign signal_eq_93 = addr == signal_const_11;
    assign signal_and_103 = read_done & signal_eq_93;
    assign signal_and_104 = signal_and_103 & signal_eq_92;
    assign signal_eq_94 = select == signal_const_20;
    assign signal_eq_95 = addr == signal_const_13;
    assign signal_and_105 = write & signal_eq_95;
    assign signal_and_106 = signal_and_105 & signal_eq_94;
    assign signal_eq_96 = select == signal_const_20;
    assign signal_eq_97 = addr == signal_const_15;
    assign signal_and_107 = write & signal_eq_97;
    assign signal_and_108 = signal_and_107 & signal_eq_96;
    assign signal_eq_98 = select == signal_const_20;
    assign signal_eq_99 = addr == signal_const_17;
    assign signal_and_109 = write & signal_eq_99;
    assign signal_and_110 = signal_and_109 & signal_eq_98;
    assign signal_eq_100 = select == signal_const_20;
    assign signal_select_39 = value[0:0];
    assign signal_eq_101 = addr == signal_const_1;
    assign signal_and_111 = write & signal_eq_101;
    assign signal_and_112 = signal_and_111 & signal_select_39;
    assign signal_and_113 = signal_and_112 & signal_eq_100;
    assign signal_select_40 = value[0:0];
    assign signal_eq_102 = select == signal_const_20;
    assign signal_eq_103 = addr == signal_const_22;
    assign signal_and_114 = signal_eq_103 & signal_eq_102;
    assign signal_and_115 = signal_and_114 & signal_wire_93;
    assign signal_mux_62 = signal_and_115 ? signal_select_40 : signal_reg_31;
    assign signal_mux_63 = write ? signal_mux_62 : signal_reg_31;
    assign signal_wire_31 = signal_mux_63;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_31 <= signal_const_20;
        else
            signal_reg_31 <= signal_wire_31;
    end
    assign signal_select_41 = value[0:0];
    assign signal_eq_104 = select == signal_const_20;
    assign signal_eq_105 = addr == signal_const_25;
    assign signal_and_116 = signal_eq_105 & signal_eq_104;
    assign signal_and_117 = signal_and_116 & signal_wire_93;
    assign signal_mux_64 = signal_and_117 ? signal_select_41 : signal_reg_32;
    assign signal_mux_65 = write ? signal_mux_64 : signal_reg_32;
    assign signal_wire_32 = signal_mux_65;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_32 <= signal_const_20;
        else
            signal_reg_32 <= signal_wire_32;
    end
    assign signal_select_42 = value[8:0];
    assign signal_eq_106 = select == signal_const_20;
    assign signal_eq_107 = addr == signal_const_28;
    assign signal_and_118 = signal_eq_107 & signal_eq_106;
    assign signal_and_119 = signal_and_118 & signal_wire_93;
    assign signal_mux_66 = signal_and_119 ? signal_select_42 : signal_reg_33;
    assign signal_mux_67 = write ? signal_mux_66 : signal_reg_33;
    assign signal_wire_33 = signal_mux_67;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_33 <= signal_const_26;
        else
            signal_reg_33 <= signal_wire_33;
    end
    assign signal_select_43 = value[0:0];
    assign signal_eq_108 = select == signal_const_20;
    assign signal_eq_109 = addr == signal_const_31;
    assign signal_and_120 = signal_eq_109 & signal_eq_108;
    assign signal_and_121 = signal_and_120 & signal_wire_93;
    assign signal_mux_68 = signal_and_121 ? signal_select_43 : signal_reg_34;
    assign signal_mux_69 = write ? signal_mux_68 : signal_reg_34;
    assign signal_wire_34 = signal_mux_69;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_34 <= signal_const_20;
        else
            signal_reg_34 <= signal_wire_34;
    end
    assign signal_eq_110 = select == signal_const_20;
    assign signal_eq_111 = addr == signal_const_34;
    assign signal_and_122 = signal_eq_111 & signal_eq_110;
    assign signal_and_123 = signal_and_122 & signal_wire_93;
    assign signal_mux_70 = signal_and_123 ? value : signal_reg_35;
    assign signal_mux_71 = write ? signal_mux_70 : signal_reg_35;
    assign signal_wire_35 = signal_mux_71;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_35 <= signal_const_32;
        else
            signal_reg_35 <= signal_wire_35;
    end
    assign signal_select_44 = value[8:0];
    assign signal_eq_112 = select == signal_const_20;
    assign signal_eq_113 = addr == signal_const_37;
    assign signal_and_124 = signal_eq_113 & signal_eq_112;
    assign signal_and_125 = signal_and_124 & signal_wire_93;
    assign signal_mux_72 = signal_and_125 ? signal_select_44 : signal_reg_36;
    assign signal_mux_73 = write ? signal_mux_72 : signal_reg_36;
    assign signal_wire_36 = signal_mux_73;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_36 <= signal_const_26;
        else
            signal_reg_36 <= signal_wire_36;
    end
    assign signal_select_45 = value[8:0];
    assign signal_eq_114 = select == signal_const_20;
    assign signal_eq_115 = addr == signal_const_40;
    assign signal_and_126 = signal_eq_115 & signal_eq_114;
    assign signal_and_127 = signal_and_126 & signal_wire_93;
    assign signal_mux_74 = signal_and_127 ? signal_select_45 : signal_reg_37;
    assign signal_mux_75 = write ? signal_mux_74 : signal_reg_37;
    assign signal_wire_37 = signal_mux_75;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_37 <= signal_const_26;
        else
            signal_reg_37 <= signal_wire_37;
    end
    assign signal_select_46 = value[0:0];
    assign signal_eq_116 = select == signal_const_20;
    assign signal_eq_117 = addr == signal_const_43;
    assign signal_and_128 = signal_eq_117 & signal_eq_116;
    assign signal_and_129 = signal_and_128 & signal_wire_93;
    assign signal_mux_76 = signal_and_129 ? signal_select_46 : signal_reg_38;
    assign signal_mux_77 = write ? signal_mux_76 : signal_reg_38;
    assign signal_wire_38 = signal_mux_77;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_38 <= signal_const_20;
        else
            signal_reg_38 <= signal_wire_38;
    end
    assign signal_select_47 = value[4:0];
    assign signal_eq_118 = select == signal_const_20;
    assign signal_eq_119 = addr == signal_const_46;
    assign signal_and_130 = signal_eq_119 & signal_eq_118;
    assign signal_and_131 = signal_and_130 & signal_wire_93;
    assign signal_mux_78 = signal_and_131 ? signal_select_47 : signal_reg_39;
    assign signal_mux_79 = write ? signal_mux_78 : signal_reg_39;
    assign signal_wire_39 = signal_mux_79;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_39 <= signal_const_44;
        else
            signal_reg_39 <= signal_wire_39;
    end
    assign signal_select_48 = value[0:0];
    assign signal_eq_120 = select == signal_const_20;
    assign signal_eq_121 = addr == signal_const_49;
    assign signal_and_132 = signal_eq_121 & signal_eq_120;
    assign signal_and_133 = signal_and_132 & signal_wire_93;
    assign signal_mux_80 = signal_and_133 ? signal_select_48 : signal_reg_40;
    assign signal_mux_81 = write ? signal_mux_80 : signal_reg_40;
    assign signal_wire_40 = signal_mux_81;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_40 <= signal_const_20;
        else
            signal_reg_40 <= signal_wire_40;
    end
    assign signal_eq_122 = select == signal_const_20;
    assign signal_eq_123 = addr == signal_const_52;
    assign signal_and_134 = signal_eq_123 & signal_eq_122;
    assign signal_and_135 = signal_and_134 & signal_wire_93;
    assign signal_mux_82 = signal_and_135 ? value : signal_reg_41;
    assign signal_mux_83 = write ? signal_mux_82 : signal_reg_41;
    assign signal_wire_41 = signal_mux_83;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_41 <= signal_const_32;
        else
            signal_reg_41 <= signal_wire_41;
    end
    assign signal_eq_124 = select == signal_const_20;
    assign signal_eq_125 = addr == signal_const_55;
    assign signal_and_136 = signal_eq_125 & signal_eq_124;
    assign signal_and_137 = signal_and_136 & signal_wire_93;
    assign signal_mux_84 = signal_and_137 ? value : signal_reg_42;
    assign signal_mux_85 = write ? signal_mux_84 : signal_reg_42;
    assign signal_wire_42 = signal_mux_85;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_42 <= signal_const_32;
        else
            signal_reg_42 <= signal_wire_42;
    end
    assign signal_select_49 = value[4:0];
    assign signal_eq_126 = select == signal_const_20;
    assign signal_eq_127 = addr == signal_const_58;
    assign signal_and_138 = signal_eq_127 & signal_eq_126;
    assign signal_and_139 = signal_and_138 & signal_wire_93;
    assign signal_mux_86 = signal_and_139 ? signal_select_49 : signal_reg_43;
    assign signal_mux_87 = write ? signal_mux_86 : signal_reg_43;
    assign signal_wire_43 = signal_mux_87;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_43 <= signal_const_44;
        else
            signal_reg_43 <= signal_wire_43;
    end
    assign signal_select_50 = value[4:0];
    assign signal_eq_128 = select == signal_const_20;
    assign signal_eq_129 = addr == signal_const_61;
    assign signal_and_140 = signal_eq_129 & signal_eq_128;
    assign signal_and_141 = signal_and_140 & signal_wire_93;
    assign signal_mux_88 = signal_and_141 ? signal_select_50 : signal_reg_44;
    assign signal_mux_89 = write ? signal_mux_88 : signal_reg_44;
    assign signal_wire_44 = signal_mux_89;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_44 <= signal_const_44;
        else
            signal_reg_44 <= signal_wire_44;
    end
    assign signal_select_51 = value[0:0];
    assign signal_eq_130 = select == signal_const_20;
    assign signal_eq_131 = addr == signal_const_64;
    assign signal_and_142 = signal_eq_131 & signal_eq_130;
    assign signal_and_143 = signal_and_142 & signal_wire_93;
    assign signal_mux_90 = signal_and_143 ? signal_select_51 : signal_reg_45;
    assign signal_mux_91 = write ? signal_mux_90 : signal_reg_45;
    assign signal_wire_45 = signal_mux_91;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_45 <= signal_const_20;
        else
            signal_reg_45 <= signal_wire_45;
    end
    assign signal_select_52 = value[4:0];
    assign signal_eq_132 = select == signal_const_20;
    assign signal_eq_133 = addr == signal_const_67;
    assign signal_and_144 = signal_eq_133 & signal_eq_132;
    assign signal_and_145 = signal_and_144 & signal_wire_93;
    assign signal_mux_92 = signal_and_145 ? signal_select_52 : signal_reg_46;
    assign signal_mux_93 = write ? signal_mux_92 : signal_reg_46;
    assign signal_wire_46 = signal_mux_93;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_46 <= signal_const_44;
        else
            signal_reg_46 <= signal_wire_46;
    end
    assign signal_select_53 = value[0:0];
    assign signal_eq_134 = select == signal_const_20;
    assign signal_eq_135 = addr == signal_const_70;
    assign signal_and_146 = signal_eq_135 & signal_eq_134;
    assign signal_and_147 = signal_and_146 & signal_wire_93;
    assign signal_mux_94 = signal_and_147 ? signal_select_53 : signal_reg_47;
    assign signal_mux_95 = write ? signal_mux_94 : signal_reg_47;
    assign signal_wire_47 = signal_mux_95;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_47 <= signal_const_20;
        else
            signal_reg_47 <= signal_wire_47;
    end
    assign signal_select_54 = value[0:0];
    assign signal_eq_136 = select == signal_const_20;
    assign signal_eq_137 = addr == signal_const_73;
    assign signal_and_148 = signal_eq_137 & signal_eq_136;
    assign signal_and_149 = signal_and_148 & signal_wire_93;
    assign signal_mux_96 = signal_and_149 ? signal_select_54 : signal_reg_48;
    assign signal_mux_97 = write ? signal_mux_96 : signal_reg_48;
    assign signal_wire_48 = signal_mux_97;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_48 <= signal_const_20;
        else
            signal_reg_48 <= signal_wire_48;
    end
    assign signal_select_55 = value[0:0];
    assign signal_eq_138 = select == signal_const_20;
    assign signal_eq_139 = addr == signal_const_76;
    assign signal_and_150 = signal_eq_139 & signal_eq_138;
    assign signal_and_151 = signal_and_150 & signal_wire_93;
    assign signal_mux_98 = signal_and_151 ? signal_select_55 : signal_reg_49;
    assign signal_mux_99 = write ? signal_mux_98 : signal_reg_49;
    assign signal_wire_49 = signal_mux_99;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_49 <= signal_const_20;
        else
            signal_reg_49 <= signal_wire_49;
    end
    assign signal_select_56 = value[0:0];
    assign signal_eq_140 = select == signal_const_20;
    assign signal_eq_141 = addr == signal_const_79;
    assign signal_and_152 = signal_eq_141 & signal_eq_140;
    assign signal_and_153 = signal_and_152 & signal_wire_93;
    assign signal_mux_100 = signal_and_153 ? signal_select_56 : signal_reg_50;
    assign signal_mux_101 = write ? signal_mux_100 : signal_reg_50;
    assign signal_wire_50 = signal_mux_101;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_50 <= signal_const_20;
        else
            signal_reg_50 <= signal_wire_50;
    end
    assign signal_select_57 = value[4:0];
    assign signal_eq_142 = select == signal_const_20;
    assign signal_eq_143 = addr == signal_const_82;
    assign signal_and_154 = signal_eq_143 & signal_eq_142;
    assign signal_and_155 = signal_and_154 & signal_wire_93;
    assign signal_mux_102 = signal_and_155 ? signal_select_57 : signal_reg_51;
    assign signal_mux_103 = write ? signal_mux_102 : signal_reg_51;
    assign signal_wire_51 = signal_mux_103;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_51 <= signal_const_44;
        else
            signal_reg_51 <= signal_wire_51;
    end
    assign signal_select_58 = value[4:0];
    assign signal_eq_144 = select == signal_const_20;
    assign signal_eq_145 = addr == signal_const_85;
    assign signal_and_156 = signal_eq_145 & signal_eq_144;
    assign signal_and_157 = signal_and_156 & signal_wire_93;
    assign signal_mux_104 = signal_and_157 ? signal_select_58 : signal_reg_52;
    assign signal_mux_105 = write ? signal_mux_104 : signal_reg_52;
    assign signal_wire_52 = signal_mux_105;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_52 <= signal_const_44;
        else
            signal_reg_52 <= signal_wire_52;
    end
    assign signal_select_59 = value[2:0];
    assign signal_eq_146 = select == signal_const_20;
    assign signal_eq_147 = addr == signal_const_88;
    assign signal_and_158 = signal_eq_147 & signal_eq_146;
    assign signal_and_159 = signal_and_158 & signal_wire_93;
    assign signal_mux_106 = signal_and_159 ? signal_select_59 : signal_reg_53;
    assign signal_mux_107 = write ? signal_mux_106 : signal_reg_53;
    assign signal_wire_53 = signal_mux_107;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_53 <= signal_const_86;
        else
            signal_reg_53 <= signal_wire_53;
    end
    assign signal_select_60 = value[4:0];
    assign signal_eq_148 = select == signal_const_20;
    assign signal_eq_149 = addr == signal_const_91;
    assign signal_and_160 = signal_eq_149 & signal_eq_148;
    assign signal_and_161 = signal_and_160 & signal_wire_93;
    assign signal_mux_108 = signal_and_161 ? signal_select_60 : signal_reg_54;
    assign signal_mux_109 = write ? signal_mux_108 : signal_reg_54;
    assign signal_wire_54 = signal_mux_109;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_54 <= signal_const_44;
        else
            signal_reg_54 <= signal_wire_54;
    end
    assign signal_select_61 = value[4:0];
    assign signal_eq_150 = select == signal_const_20;
    assign signal_eq_151 = addr == signal_const_94;
    assign signal_and_162 = signal_eq_151 & signal_eq_150;
    assign signal_and_163 = signal_and_162 & signal_wire_93;
    assign signal_mux_110 = signal_and_163 ? signal_select_61 : signal_reg_55;
    assign signal_mux_111 = write ? signal_mux_110 : signal_reg_55;
    assign signal_wire_55 = signal_mux_111;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_55 <= signal_const_44;
        else
            signal_reg_55 <= signal_wire_55;
    end
    assign signal_select_62 = value[4:0];
    assign signal_eq_152 = select == signal_const_20;
    assign signal_eq_153 = addr == signal_const_97;
    assign signal_and_164 = signal_eq_153 & signal_eq_152;
    assign signal_and_165 = signal_and_164 & signal_wire_93;
    assign signal_mux_112 = signal_and_165 ? signal_select_62 : signal_reg_56;
    assign signal_mux_113 = write ? signal_mux_112 : signal_reg_56;
    assign signal_wire_56 = signal_mux_113;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_56 <= signal_const_44;
        else
            signal_reg_56 <= signal_wire_56;
    end
    assign signal_select_63 = value[4:0];
    assign signal_eq_154 = select == signal_const_20;
    assign signal_eq_155 = addr == signal_const_100;
    assign signal_and_166 = signal_eq_155 & signal_eq_154;
    assign signal_and_167 = signal_and_166 & signal_wire_93;
    assign signal_mux_114 = signal_and_167 ? signal_select_63 : signal_reg_57;
    assign signal_mux_115 = write ? signal_mux_114 : signal_reg_57;
    assign signal_wire_57 = signal_mux_115;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_57 <= signal_const_44;
        else
            signal_reg_57 <= signal_wire_57;
    end
    assign signal_select_64 = value[4:0];
    assign signal_eq_156 = select == signal_const_20;
    assign signal_eq_157 = addr == signal_const_103;
    assign signal_and_168 = signal_eq_157 & signal_eq_156;
    assign signal_and_169 = signal_and_168 & signal_wire_93;
    assign signal_mux_116 = signal_and_169 ? signal_select_64 : signal_reg_58;
    assign signal_mux_117 = write ? signal_mux_116 : signal_reg_58;
    assign signal_wire_58 = signal_mux_117;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_58 <= signal_const_44;
        else
            signal_reg_58 <= signal_wire_58;
    end
    assign signal_select_65 = value[0:0];
    assign signal_eq_158 = select == signal_const_20;
    assign signal_eq_159 = addr == signal_const_106;
    assign signal_and_170 = signal_eq_159 & signal_eq_158;
    assign signal_and_171 = signal_and_170 & signal_wire_93;
    assign signal_mux_118 = signal_and_171 ? signal_select_65 : signal_reg_59;
    assign signal_mux_119 = write ? signal_mux_118 : signal_reg_59;
    assign signal_wire_59 = signal_mux_119;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_59 <= signal_const_20;
        else
            signal_reg_59 <= signal_wire_59;
    end
    assign signal_select_66 = value[4:0];
    assign signal_eq_160 = select == signal_const_20;
    assign signal_eq_161 = addr == signal_const_109;
    assign signal_and_172 = signal_eq_161 & signal_eq_160;
    assign signal_and_173 = signal_and_172 & signal_wire_93;
    assign signal_mux_120 = signal_and_173 ? signal_select_66 : signal_reg_60;
    assign signal_mux_121 = write ? signal_mux_120 : signal_reg_60;
    assign signal_wire_60 = signal_mux_121;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_60 <= signal_const_44;
        else
            signal_reg_60 <= signal_wire_60;
    end
    assign signal_select_67 = value[1:0];
    assign signal_eq_162 = select == signal_const_20;
    assign signal_eq_163 = addr == signal_const_112;
    assign signal_and_174 = signal_eq_163 & signal_eq_162;
    assign signal_and_175 = signal_and_174 & signal_wire_93;
    assign signal_mux_122 = signal_and_175 ? signal_select_67 : signal_reg_61;
    assign signal_mux_123 = write ? signal_mux_122 : signal_reg_61;
    assign signal_wire_61 = signal_mux_123;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            signal_reg_61 <= signal_const_110;
        else
            signal_reg_61 <= signal_wire_61;
    end
    assign signal_select_68 = tx_word[7:0];
    assign rx_head = select ? signal_wire_70 : signal_wire_89;
    assign signal_wire_62 = status$isr_count_1;
    assign signal_cat = { signal_const_86,
                          signal_wire_62 };
    assign signal_wire_63 = status$osr_count_1;
    assign signal_cat_1 = { signal_wire_63,
                            signal_cat };
    assign signal_cat_2 = { signal_const_86,
                            signal_cat_1 };
    assign signal_wire_64 = status$osr_1;
    assign signal_wire_65 = status$isr_1;
    assign signal_select_69 = signal_wire_66[23:16];
    assign signal_const_233 = 8'b00000000;
    assign signal_cat_3 = { signal_const_233,
                            signal_select_69 };
    assign signal_wire_66 = status$t_1;
    assign signal_select_70 = signal_wire_66[15:0];
    assign signal_wire_67 = status$p_1;
    assign signal_wire_68 = status$y_1;
    assign signal_wire_69 = status$x_1;
    assign signal_wire_70 = status$rx_head_1;
    assign signal_select_71 = signal_wire_71[23:16];
    assign signal_cat_4 = { signal_const_233,
                            signal_select_71 };
    assign signal_wire_71 = status$capture_1;
    assign signal_select_72 = signal_wire_71[15:0];
    assign signal_select_73 = signal_wire_72[23:16];
    assign signal_cat_5 = { signal_const_233,
                            signal_select_73 };
    assign signal_wire_72 = status$now_1;
    assign signal_select_74 = signal_wire_72[15:0];
    assign signal_wire_73 = status$pc_1;
    assign signal_cat_6 = { signal_const_1,
                            signal_wire_73 };
    assign signal_wire_74 = status$halted_1;
    assign signal_wire_75 = status$fault$underflow_1;
    assign signal_wire_76 = status$fault$overflow_1;
    assign signal_wire_77 = status$fault$missed_deadline_1;
    assign signal_wire_78 = status$fault$decode_1;
    assign signal_wire_79 = status$tx_level_1;
    assign signal_wire_80 = status$rx_level_1;
    assign signal_cat_7 = { signal_wire_94,
                            signal_const_20,
                            signal_wire_80,
                            signal_wire_79,
                            signal_wire_78,
                            signal_wire_77,
                            signal_wire_76,
                            signal_wire_75,
                            signal_wire_101,
                            signal_wire_74 };
    always @* begin
        case (read_addr)
        7'b0000001:
            signal_cases <= signal_cat_7;
        7'b0000010:
            signal_cases <= signal_cat_6;
        7'b0000011:
            signal_cases <= signal_select_74;
        7'b0000100:
            signal_cases <= signal_cat_5;
        7'b0000101:
            signal_cases <= signal_select_72;
        7'b0000110:
            signal_cases <= signal_cat_4;
        7'b0001000:
            signal_cases <= signal_wire_70;
        7'b1000000:
            signal_cases <= signal_wire_69;
        7'b1000001:
            signal_cases <= signal_wire_68;
        7'b1000010:
            signal_cases <= signal_wire_67;
        7'b1000011:
            signal_cases <= signal_select_70;
        7'b1000100:
            signal_cases <= signal_cat_3;
        7'b1000101:
            signal_cases <= signal_wire_65;
        7'b1000110:
            signal_cases <= signal_wire_64;
        7'b1000111:
            signal_cases <= signal_cat_2;
        default:
            signal_cases <= signal_const_32;
        endcase
    end
    assign signal_wire_81 = status$isr_count_0;
    assign signal_cat_8 = { signal_const_86,
                            signal_wire_81 };
    assign signal_wire_82 = status$osr_count_0;
    assign signal_cat_9 = { signal_wire_82,
                            signal_cat_8 };
    assign signal_cat_10 = { signal_const_86,
                             signal_cat_9 };
    assign signal_wire_83 = status$osr_0;
    assign signal_wire_84 = status$isr_0;
    assign signal_select_75 = signal_wire_85[23:16];
    assign signal_cat_11 = { signal_const_233,
                             signal_select_75 };
    assign signal_wire_85 = status$t_0;
    assign signal_select_76 = signal_wire_85[15:0];
    assign signal_wire_86 = status$p_0;
    assign signal_wire_87 = status$y_0;
    assign signal_wire_88 = status$x_0;
    assign signal_wire_89 = status$rx_head_0;
    assign signal_select_77 = signal_wire_90[23:16];
    assign signal_cat_12 = { signal_const_233,
                             signal_select_77 };
    assign signal_wire_90 = status$capture_0;
    assign signal_select_78 = signal_wire_90[15:0];
    assign signal_select_79 = signal_wire_91[23:16];
    assign signal_cat_13 = { signal_const_233,
                             signal_select_79 };
    assign signal_wire_91 = status$now_0;
    assign signal_select_80 = signal_wire_91[15:0];
    assign signal_wire_92 = status$pc_0;
    assign signal_cat_14 = { signal_const_1,
                             signal_wire_92 };
    assign signal_wire_93 = status$halted_0;
    assign signal_wire_94 = status$irq_0;
    assign signal_wire_95 = status$fault$underflow_0;
    assign signal_wire_96 = status$fault$overflow_0;
    assign signal_wire_97 = status$fault$missed_deadline_0;
    assign signal_wire_98 = status$fault$decode_0;
    assign signal_wire_99 = status$tx_level_0;
    assign signal_wire_100 = status$rx_level_0;
    assign signal_wire_101 = status$irq_1;
    assign signal_cat_15 = { signal_wire_101,
                             signal_const_20,
                             signal_wire_100,
                             signal_wire_99,
                             signal_wire_98,
                             signal_wire_97,
                             signal_wire_96,
                             signal_wire_95,
                             signal_wire_94,
                             signal_wire_93 };
    always @* begin
        case (read_addr)
        7'b0000001:
            signal_cases_1 <= signal_cat_15;
        7'b0000010:
            signal_cases_1 <= signal_cat_14;
        7'b0000011:
            signal_cases_1 <= signal_select_80;
        7'b0000100:
            signal_cases_1 <= signal_cat_13;
        7'b0000101:
            signal_cases_1 <= signal_select_78;
        7'b0000110:
            signal_cases_1 <= signal_cat_12;
        7'b0001000:
            signal_cases_1 <= signal_wire_89;
        7'b1000000:
            signal_cases_1 <= signal_wire_88;
        7'b1000001:
            signal_cases_1 <= signal_wire_87;
        7'b1000010:
            signal_cases_1 <= signal_wire_86;
        7'b1000011:
            signal_cases_1 <= signal_select_76;
        7'b1000100:
            signal_cases_1 <= signal_cat_11;
        7'b1000101:
            signal_cases_1 <= signal_wire_84;
        7'b1000110:
            signal_cases_1 <= signal_wire_83;
        7'b1000111:
            signal_cases_1 <= signal_cat_10;
        default:
            signal_cases_1 <= signal_const_32;
        endcase
    end
    assign signal_mux_124 = select ? signal_cases : signal_cases_1;
    assign signal_select_81 = value[0:0];
    assign signal_const_274 = 7'b0001011;
    assign signal_eq_164 = addr == signal_const_274;
    assign signal_mux_125 = signal_eq_164 ? signal_select_81 : select;
    assign signal_mux_126 = write ? signal_mux_125 : select;
    assign signal_wire_102 = signal_mux_126;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            select <= signal_const_20;
        else
            select <= signal_wire_102;
    end
    assign signal_const_275 = 15'b000000000000000;
    assign signal_cat_16 = { signal_const_275,
                             select };
    assign signal_const_278 = 9'b000000001;
    assign signal_add = data_addr + signal_const_278;
    assign signal_select_82 = value[8:0];
    assign signal_const_279 = 7'b0001100;
    assign signal_eq_165 = addr == signal_const_279;
    assign signal_mux_127 = signal_eq_165 ? signal_select_82 : data_addr;
    assign signal_eq_166 = addr == signal_const_15;
    assign signal_mux_128 = signal_eq_166 ? signal_add : signal_mux_127;
    assign signal_mux_129 = write ? signal_mux_128 : data_addr;
    assign signal_wire_103 = signal_mux_129;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            data_addr <= signal_const_26;
        else
            data_addr <= signal_wire_103;
    end
    assign signal_cat_17 = { signal_const_1,
                             data_addr };
    assign signal_add_1 = program_addr + signal_const_278;
    always @* begin
        case (sm)
        2'b01:
            signal_cases_2 <= signal_select_85;
        default:
            signal_cases_2 <= high;
        endcase
    end
    assign signal_mux_130 = signal_select_88 ? signal_cases_2 : high;
    assign signal_wire_104 = signal_mux_130;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            high <= signal_const_233;
        else
            high <= signal_wire_104;
    end
    assign value = { high,
                     signal_select_85 };
    assign signal_select_83 = value[8:0];
    assign signal_const_286 = 7'b0001001;
    assign signal_eq_167 = addr == signal_const_286;
    assign signal_mux_131 = signal_eq_167 ? signal_select_83 : program_addr;
    assign signal_eq_168 = addr == signal_const_17;
    assign signal_mux_132 = signal_eq_168 ? signal_add_1 : signal_mux_131;
    assign signal_mux_133 = is_write ? vdd : gnd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_3 <= signal_mux_133;
        default:
            signal_cases_3 <= gnd;
        endcase
    end
    assign signal_mux_134 = signal_select_88 ? signal_cases_3 : gnd;
    assign write = signal_mux_134;
    assign signal_mux_135 = write ? signal_mux_132 : program_addr;
    assign signal_wire_105 = signal_mux_135;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            program_addr <= signal_const_26;
        else
            program_addr <= signal_wire_105;
    end
    assign signal_cat_18 = { signal_const_1,
                             program_addr };
    assign spi_rx_byte = signal_select_85;
    assign signal_select_84 = spi_rx_byte[6:0];
    assign signal_eq_169 = signal_const_110 == sm;
    assign read_addr = signal_eq_169 ? signal_select_84 : addr;
    always @* begin
        case (read_addr)
        7'b0001001:
            read_value <= signal_cat_18;
        7'b0001100:
            read_value <= signal_cat_17;
        7'b0001011:
            read_value <= signal_cat_16;
        default:
            read_value <= signal_mux_124;
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
    assign signal_mux_136 = signal_select_88 ? signal_cases_4 : word;
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
    assign signal_mux_138 = signal_select_88 ? signal_cases_5 : gnd;
    assign read_done = signal_mux_138;
    assign signal_mux_139 = read_done ? read_value : signal_mux_136;
    assign signal_wire_106 = signal_mux_139;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            word <= signal_const_32;
        else
            word <= signal_wire_106;
    end
    assign signal_select_85 = signal_inst[8:1];
    always @* begin
        case (sm)
        2'b00:
            signal_cases_6 <= signal_select_85;
        default:
            signal_cases_6 <= cmd;
        endcase
    end
    assign signal_mux_140 = signal_select_88 ? signal_cases_6 : cmd;
    assign signal_wire_107 = signal_mux_140;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            cmd <= signal_const_233;
        else
            cmd <= signal_wire_107;
    end
    assign addr = cmd[6:0];
    assign signal_eq_170 = addr == signal_const_11;
    assign tx_word = signal_eq_170 ? rx_head : word;
    assign signal_select_86 = tx_word[15:8];
    assign signal_const_293 = 2'b01;
    always @* begin
        case (sm)
        2'b00:
            signal_cases_7 <= signal_const_293;
        2'b01:
            signal_cases_7 <= signal_const_295;
        2'b10:
            signal_cases_7 <= signal_const_293;
        default:
            signal_cases_7 <= signal_mux_141;
        endcase
    end
    assign signal_select_87 = signal_inst[10:10];
    assign signal_mux_141 = signal_select_87 ? signal_const_110 : sm;
    assign signal_select_88 = signal_inst[9:9];
    assign signal_mux_142 = signal_select_88 ? signal_cases_7 : signal_mux_141;
    assign signal_wire_108 = signal_mux_142;
    always @(posedge signal_wire_113) begin
        if (signal_wire_112)
            sm <= signal_const_110;
        else
            sm <= signal_wire_108;
    end
    assign signal_const_295 = 2'b10;
    assign signal_eq_171 = signal_const_295 == sm;
    assign signal_mux_143 = signal_eq_171 ? signal_select_68 : signal_select_86;
    assign signal_wire_109 = cs_n;
    assign signal_wire_110 = mosi;
    assign signal_wire_111 = sck;
    assign signal_wire_112 = clear;
    assign signal_wire_113 = clock;
    host_spi
        host_spi
        ( .clock(signal_wire_113),
          .clear(signal_wire_112),
          .sck(signal_wire_111),
          .mosi(signal_wire_110),
          .cs_n(signal_wire_109),
          .tx_byte(signal_mux_143),
          .miso(signal_inst[0:0]),
          .rx_byte(signal_inst[8:1]),
          .rx_valid(signal_inst[9:9]),
          .frame_start(signal_inst[10:10]),
          .frame_end(signal_inst[11:11]) );
    assign signal_select_89 = signal_inst[0:0];
    assign miso = signal_select_89;
    assign engines$config$side_set_count_0 = signal_reg_61;
    assign engines$config$side_set_base_0 = signal_reg_60;
    assign engines$config$side_set_pindirs_0 = signal_reg_59;
    assign engines$config$in_base_0 = signal_reg_58;
    assign engines$config$in_count_0 = signal_reg_57;
    assign engines$config$out_base_0 = signal_reg_56;
    assign engines$config$out_count_0 = signal_reg_55;
    assign engines$config$set_base_0 = signal_reg_54;
    assign engines$config$set_count_0 = signal_reg_53;
    assign engines$config$jmp_pin_0 = signal_reg_52;
    assign engines$config$capture_pin_0 = signal_reg_51;
    assign engines$config$capture_rising_0 = signal_reg_50;
    assign engines$config$in_shift_right_0 = signal_reg_49;
    assign engines$config$out_shift_right_0 = signal_reg_48;
    assign engines$config$autopush_0 = signal_reg_47;
    assign engines$config$push_threshold_0 = signal_reg_46;
    assign engines$config$autopull_0 = signal_reg_45;
    assign engines$config$pull_threshold_0 = signal_reg_44;
    assign engines$config$crc_width_0 = signal_reg_43;
    assign engines$config$crc_poly_0 = signal_reg_42;
    assign engines$config$crc_init_0 = signal_reg_41;
    assign engines$config$crc_reflect_0 = signal_reg_40;
    assign engines$config$stuff_threshold_0 = signal_reg_39;
    assign engines$config$stuff_level_0 = signal_reg_38;
    assign engines$config$wrap_bottom_0 = signal_reg_37;
    assign engines$config$wrap_top_0 = signal_reg_36;
    assign engines$config$period_fraction_0 = signal_reg_35;
    assign engines$config$break_enable_0 = signal_reg_34;
    assign engines$config$break_pc_0 = signal_reg_33;
    assign engines$config$autopull_data_0 = signal_reg_32;
    assign engines$config$manchester_0 = signal_reg_31;
    assign engines$start_0 = signal_and_113;
    assign engines$program_write$valid_0 = signal_and_110;
    assign engines$program_write$addr_0 = program_addr;
    assign engines$program_write$data_0 = value;
    assign engines$data_write$valid_0 = signal_and_108;
    assign engines$data_write$addr_0 = data_addr;
    assign engines$data_write$data_0 = value;
    assign engines$tx$valid_0 = signal_and_106;
    assign engines$tx$value_0 = value;
    assign engines$rx_pop_0 = signal_and_104;
    assign engines$clear_irq_0 = signal_and_102;
    assign engines$stop_0 = signal_and_99;
    assign engines$flush_0 = signal_and_96;
    assign engines$resume_0 = signal_and_93;
    assign engines$single_step_0 = signal_and_90;
    assign engines$config$side_set_count_1 = signal_reg_30;
    assign engines$config$side_set_base_1 = signal_reg_29;
    assign engines$config$side_set_pindirs_1 = signal_reg_28;
    assign engines$config$in_base_1 = signal_reg_27;
    assign engines$config$in_count_1 = signal_reg_26;
    assign engines$config$out_base_1 = signal_reg_25;
    assign engines$config$out_count_1 = signal_reg_24;
    assign engines$config$set_base_1 = signal_reg_23;
    assign engines$config$set_count_1 = signal_reg_22;
    assign engines$config$jmp_pin_1 = signal_reg_21;
    assign engines$config$capture_pin_1 = signal_reg_20;
    assign engines$config$capture_rising_1 = signal_reg_19;
    assign engines$config$in_shift_right_1 = signal_reg_18;
    assign engines$config$out_shift_right_1 = signal_reg_17;
    assign engines$config$autopush_1 = signal_reg_16;
    assign engines$config$push_threshold_1 = signal_reg_15;
    assign engines$config$autopull_1 = signal_reg_14;
    assign engines$config$pull_threshold_1 = signal_reg_13;
    assign engines$config$crc_width_1 = signal_reg_12;
    assign engines$config$crc_poly_1 = signal_reg_11;
    assign engines$config$crc_init_1 = signal_reg_10;
    assign engines$config$crc_reflect_1 = signal_reg_9;
    assign engines$config$stuff_threshold_1 = signal_reg_8;
    assign engines$config$stuff_level_1 = signal_reg_7;
    assign engines$config$wrap_bottom_1 = signal_reg_6;
    assign engines$config$wrap_top_1 = signal_reg_5;
    assign engines$config$period_fraction_1 = signal_reg_4;
    assign engines$config$break_enable_1 = signal_reg_3;
    assign engines$config$break_pc_1 = signal_reg_2;
    assign engines$config$autopull_data_1 = signal_reg_1;
    assign engines$config$manchester_1 = signal_reg;
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
    wire signal_select_21;
    wire [8:0] signal_select_22;
    wire signal_select_23;
    wire [15:0] signal_select_24;
    wire [8:0] signal_select_25;
    wire [8:0] signal_select_26;
    wire signal_select_27;
    wire [4:0] signal_select_28;
    wire signal_select_29;
    wire [15:0] signal_select_30;
    wire [15:0] signal_select_31;
    wire [4:0] signal_select_32;
    wire [4:0] signal_select_33;
    wire signal_select_34;
    wire [4:0] signal_select_35;
    wire signal_select_36;
    wire signal_select_37;
    wire signal_select_38;
    wire signal_select_39;
    wire [4:0] signal_select_40;
    wire [4:0] signal_select_41;
    wire [2:0] signal_select_42;
    wire [4:0] signal_select_43;
    wire [4:0] signal_select_44;
    wire [4:0] signal_select_45;
    wire [4:0] signal_select_46;
    wire [4:0] signal_select_47;
    wire signal_select_48;
    wire [4:0] signal_select_49;
    wire [1:0] signal_select_50;
    wire signal_select_51;
    wire signal_select_52;
    wire signal_select_53;
    wire signal_select_54;
    wire signal_select_55;
    wire signal_select_56;
    wire [15:0] signal_select_57;
    wire signal_select_58;
    wire [15:0] signal_select_59;
    wire [8:0] signal_select_60;
    wire signal_select_61;
    wire [15:0] signal_select_62;
    wire [8:0] signal_select_63;
    wire signal_select_64;
    wire signal_select_65;
    wire signal_select_66;
    wire signal_select_67;
    wire [8:0] signal_select_68;
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
    wire [4:0] signal_select_97;
    wire [4:0] signal_wire_2;
    wire [15:0] signal_select_98;
    wire [15:0] signal_wire_3;
    wire [15:0] signal_select_99;
    wire [15:0] signal_wire_4;
    wire [23:0] signal_select_100;
    wire [23:0] signal_wire_5;
    wire [15:0] signal_select_101;
    wire [15:0] signal_wire_6;
    wire [15:0] signal_select_102;
    wire [15:0] signal_wire_7;
    wire [15:0] signal_select_103;
    wire [15:0] signal_wire_8;
    wire [15:0] signal_select_104;
    wire [15:0] signal_wire_9;
    wire [3:0] signal_select_105;
    wire [3:0] signal_wire_10;
    wire [3:0] signal_select_106;
    wire [3:0] signal_wire_11;
    wire signal_select_107;
    wire signal_wire_12;
    wire signal_select_108;
    wire signal_wire_13;
    wire signal_select_109;
    wire signal_wire_14;
    wire signal_select_110;
    wire signal_wire_15;
    wire signal_select_111;
    wire signal_wire_16;
    wire signal_select_112;
    wire signal_wire_17;
    wire [23:0] signal_select_113;
    wire [23:0] signal_wire_18;
    wire [23:0] signal_select_114;
    wire [23:0] signal_wire_19;
    wire [8:0] signal_select_115;
    wire [8:0] signal_wire_20;
    wire [4:0] signal_select_116;
    wire [4:0] signal_wire_21;
    wire [4:0] signal_select_117;
    wire [4:0] signal_wire_22;
    wire [15:0] signal_select_118;
    wire [15:0] signal_wire_23;
    wire [15:0] signal_select_119;
    wire [15:0] signal_wire_24;
    wire [23:0] signal_select_120;
    wire [23:0] signal_wire_25;
    wire [15:0] signal_select_121;
    wire [15:0] signal_wire_26;
    wire [15:0] signal_select_122;
    wire [15:0] signal_wire_27;
    wire [15:0] signal_select_123;
    wire [15:0] signal_wire_28;
    wire [15:0] signal_select_124;
    wire [15:0] signal_wire_29;
    wire [3:0] signal_select_125;
    wire [3:0] signal_wire_30;
    wire [3:0] signal_select_126;
    wire [3:0] signal_wire_31;
    wire signal_select_127;
    wire signal_wire_32;
    wire signal_select_128;
    wire signal_wire_33;
    wire signal_select_129;
    wire signal_wire_34;
    wire signal_select_130;
    wire signal_wire_35;
    wire signal_select_131;
    wire signal_wire_36;
    wire signal_select_132;
    wire signal_wire_37;
    wire [23:0] signal_select_133;
    wire [23:0] signal_wire_38;
    wire [23:0] signal_select_134;
    wire [23:0] signal_wire_39;
    wire [8:0] signal_select_135;
    wire [8:0] signal_wire_40;
    wire signal_select_136;
    wire signal_select_137;
    wire [7:0] signal_wire_41;
    wire signal_select_138;
    wire [454:0] signal_inst;
    wire [1:0] signal_select_139;
    wire signal_const_5;
    wire signal_wire_42;
    wire signal_not;
    wire vdd;
    reg signal_reg_4;
    reg reset_done;
    wire signal_not_1;
    wire signal_wire_43;
    wire [789:0] signal_inst_1;
    wire [19:0] signal_select_140;
    wire [6:0] signal_select_141;
    wire [7:0] signal_cat;
    assign signal_select = signal_inst_1[789:770];
    assign signal_select_1 = signal_select[19:12];
    assign signal_select_2 = signal_select_140[19:12];
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
    assign signal_select_5 = signal_inst[454:454];
    assign signal_select_6 = signal_inst[453:453];
    assign signal_select_7 = signal_inst[452:452];
    assign signal_select_8 = signal_inst[451:451];
    assign signal_select_9 = signal_inst[450:450];
    assign signal_select_10 = signal_inst[449:449];
    assign signal_select_11 = signal_inst[448:433];
    assign signal_select_12 = signal_inst[432:432];
    assign signal_select_13 = signal_inst[431:416];
    assign signal_select_14 = signal_inst[415:407];
    assign signal_select_15 = signal_inst[406:406];
    assign signal_select_16 = signal_inst[405:390];
    assign signal_select_17 = signal_inst[389:381];
    assign signal_select_18 = signal_inst[380:380];
    assign signal_select_19 = signal_inst[379:379];
    assign signal_select_20 = signal_inst[378:378];
    assign signal_select_21 = signal_inst[377:377];
    assign signal_select_22 = signal_inst[376:368];
    assign signal_select_23 = signal_inst[367:367];
    assign signal_select_24 = signal_inst[366:351];
    assign signal_select_25 = signal_inst[350:342];
    assign signal_select_26 = signal_inst[341:333];
    assign signal_select_27 = signal_inst[332:332];
    assign signal_select_28 = signal_inst[331:327];
    assign signal_select_29 = signal_inst[326:326];
    assign signal_select_30 = signal_inst[325:310];
    assign signal_select_31 = signal_inst[309:294];
    assign signal_select_32 = signal_inst[293:289];
    assign signal_select_33 = signal_inst[288:284];
    assign signal_select_34 = signal_inst[283:283];
    assign signal_select_35 = signal_inst[282:278];
    assign signal_select_36 = signal_inst[277:277];
    assign signal_select_37 = signal_inst[276:276];
    assign signal_select_38 = signal_inst[275:275];
    assign signal_select_39 = signal_inst[274:274];
    assign signal_select_40 = signal_inst[273:269];
    assign signal_select_41 = signal_inst[268:264];
    assign signal_select_42 = signal_inst[263:261];
    assign signal_select_43 = signal_inst[260:256];
    assign signal_select_44 = signal_inst[255:251];
    assign signal_select_45 = signal_inst[250:246];
    assign signal_select_46 = signal_inst[245:241];
    assign signal_select_47 = signal_inst[240:236];
    assign signal_select_48 = signal_inst[235:235];
    assign signal_select_49 = signal_inst[234:230];
    assign signal_select_50 = signal_inst[229:228];
    assign signal_select_51 = signal_inst[227:227];
    assign signal_select_52 = signal_inst[226:226];
    assign signal_select_53 = signal_inst[225:225];
    assign signal_select_54 = signal_inst[224:224];
    assign signal_select_55 = signal_inst[223:223];
    assign signal_select_56 = signal_inst[222:222];
    assign signal_select_57 = signal_inst[221:206];
    assign signal_select_58 = signal_inst[205:205];
    assign signal_select_59 = signal_inst[204:189];
    assign signal_select_60 = signal_inst[188:180];
    assign signal_select_61 = signal_inst[179:179];
    assign signal_select_62 = signal_inst[178:163];
    assign signal_select_63 = signal_inst[162:154];
    assign signal_select_64 = signal_inst[153:153];
    assign signal_select_65 = signal_inst[152:152];
    assign signal_select_66 = signal_inst[151:151];
    assign signal_select_67 = signal_inst[150:150];
    assign signal_select_68 = signal_inst[149:141];
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
    assign signal_select_96 = signal_inst_1[566:562];
    assign signal_wire_1 = signal_select_96;
    assign signal_select_97 = signal_inst_1[587:583];
    assign signal_wire_2 = signal_select_97;
    assign signal_select_98 = signal_inst_1[561:546];
    assign signal_wire_3 = signal_select_98;
    assign signal_select_99 = signal_inst_1[582:567];
    assign signal_wire_4 = signal_select_99;
    assign signal_select_100 = signal_inst_1[529:506];
    assign signal_wire_5 = signal_select_100;
    assign signal_select_101 = signal_inst_1[505:490];
    assign signal_wire_6 = signal_select_101;
    assign signal_select_102 = signal_inst_1[489:474];
    assign signal_wire_7 = signal_select_102;
    assign signal_select_103 = signal_inst_1[473:458];
    assign signal_wire_8 = signal_select_103;
    assign signal_select_104 = signal_inst_1[673:658];
    assign signal_wire_9 = signal_select_104;
    assign signal_select_105 = signal_inst_1[657:654];
    assign signal_wire_10 = signal_select_105;
    assign signal_select_106 = signal_inst_1[653:650];
    assign signal_wire_11 = signal_select_106;
    assign signal_select_107 = signal_inst_1[624:624];
    assign signal_wire_12 = signal_select_107;
    assign signal_select_108 = signal_inst_1[623:623];
    assign signal_wire_13 = signal_select_108;
    assign signal_select_109 = signal_inst_1[622:622];
    assign signal_wire_14 = signal_select_109;
    assign signal_select_110 = signal_inst_1[621:621];
    assign signal_wire_15 = signal_select_110;
    assign signal_select_111 = signal_inst_1[620:620];
    assign signal_wire_16 = signal_select_111;
    assign signal_select_112 = signal_inst_1[617:617];
    assign signal_wire_17 = signal_select_112;
    assign signal_select_113 = signal_inst_1[648:625];
    assign signal_wire_18 = signal_select_113;
    assign signal_select_114 = signal_inst_1[611:588];
    assign signal_wire_19 = signal_select_114;
    assign signal_select_115 = signal_inst_1[439:431];
    assign signal_wire_20 = signal_select_115;
    assign signal_select_116 = signal_inst_1[191:187];
    assign signal_wire_21 = signal_select_116;
    assign signal_select_117 = signal_inst_1[212:208];
    assign signal_wire_22 = signal_select_117;
    assign signal_select_118 = signal_inst_1[186:171];
    assign signal_wire_23 = signal_select_118;
    assign signal_select_119 = signal_inst_1[207:192];
    assign signal_wire_24 = signal_select_119;
    assign signal_select_120 = signal_inst_1[154:131];
    assign signal_wire_25 = signal_select_120;
    assign signal_select_121 = signal_inst_1[130:115];
    assign signal_wire_26 = signal_select_121;
    assign signal_select_122 = signal_inst_1[114:99];
    assign signal_wire_27 = signal_select_122;
    assign signal_select_123 = signal_inst_1[98:83];
    assign signal_wire_28 = signal_select_123;
    assign signal_select_124 = signal_inst_1[298:283];
    assign signal_wire_29 = signal_select_124;
    assign signal_select_125 = signal_inst_1[282:279];
    assign signal_wire_30 = signal_select_125;
    assign signal_select_126 = signal_inst_1[278:275];
    assign signal_wire_31 = signal_select_126;
    assign signal_select_127 = signal_inst_1[249:249];
    assign signal_wire_32 = signal_select_127;
    assign signal_select_128 = signal_inst_1[248:248];
    assign signal_wire_33 = signal_select_128;
    assign signal_select_129 = signal_inst_1[247:247];
    assign signal_wire_34 = signal_select_129;
    assign signal_select_130 = signal_inst_1[246:246];
    assign signal_wire_35 = signal_select_130;
    assign signal_select_131 = signal_inst_1[245:245];
    assign signal_wire_36 = signal_select_131;
    assign signal_select_132 = signal_inst_1[242:242];
    assign signal_wire_37 = signal_select_132;
    assign signal_select_133 = signal_inst_1[273:250];
    assign signal_wire_38 = signal_select_133;
    assign signal_select_134 = signal_inst_1[236:213];
    assign signal_wire_39 = signal_select_134;
    assign signal_select_135 = signal_inst_1[64:56];
    assign signal_wire_40 = signal_select_135;
    assign signal_select_136 = signal_wire_41[2:2];
    assign signal_select_137 = signal_wire_41[1:1];
    assign signal_wire_41 = ui_in;
    assign signal_select_138 = signal_wire_41[0:0];
    host_port
        host_port
        ( .clock(signal_wire_43),
          .clear(signal_not_1),
          .sck(signal_select_138),
          .mosi(signal_select_137),
          .cs_n(signal_select_136),
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
          .engines$config$manchester_0(signal_inst[151:151]),
          .engines$start_0(signal_inst[152:152]),
          .engines$program_write$valid_0(signal_inst[153:153]),
          .engines$program_write$addr_0(signal_inst[162:154]),
          .engines$program_write$data_0(signal_inst[178:163]),
          .engines$data_write$valid_0(signal_inst[179:179]),
          .engines$data_write$addr_0(signal_inst[188:180]),
          .engines$data_write$data_0(signal_inst[204:189]),
          .engines$tx$valid_0(signal_inst[205:205]),
          .engines$tx$value_0(signal_inst[221:206]),
          .engines$rx_pop_0(signal_inst[222:222]),
          .engines$clear_irq_0(signal_inst[223:223]),
          .engines$stop_0(signal_inst[224:224]),
          .engines$flush_0(signal_inst[225:225]),
          .engines$resume_0(signal_inst[226:226]),
          .engines$single_step_0(signal_inst[227:227]),
          .engines$config$side_set_count_1(signal_inst[229:228]),
          .engines$config$side_set_base_1(signal_inst[234:230]),
          .engines$config$side_set_pindirs_1(signal_inst[235:235]),
          .engines$config$in_base_1(signal_inst[240:236]),
          .engines$config$in_count_1(signal_inst[245:241]),
          .engines$config$out_base_1(signal_inst[250:246]),
          .engines$config$out_count_1(signal_inst[255:251]),
          .engines$config$set_base_1(signal_inst[260:256]),
          .engines$config$set_count_1(signal_inst[263:261]),
          .engines$config$jmp_pin_1(signal_inst[268:264]),
          .engines$config$capture_pin_1(signal_inst[273:269]),
          .engines$config$capture_rising_1(signal_inst[274:274]),
          .engines$config$in_shift_right_1(signal_inst[275:275]),
          .engines$config$out_shift_right_1(signal_inst[276:276]),
          .engines$config$autopush_1(signal_inst[277:277]),
          .engines$config$push_threshold_1(signal_inst[282:278]),
          .engines$config$autopull_1(signal_inst[283:283]),
          .engines$config$pull_threshold_1(signal_inst[288:284]),
          .engines$config$crc_width_1(signal_inst[293:289]),
          .engines$config$crc_poly_1(signal_inst[309:294]),
          .engines$config$crc_init_1(signal_inst[325:310]),
          .engines$config$crc_reflect_1(signal_inst[326:326]),
          .engines$config$stuff_threshold_1(signal_inst[331:327]),
          .engines$config$stuff_level_1(signal_inst[332:332]),
          .engines$config$wrap_bottom_1(signal_inst[341:333]),
          .engines$config$wrap_top_1(signal_inst[350:342]),
          .engines$config$period_fraction_1(signal_inst[366:351]),
          .engines$config$break_enable_1(signal_inst[367:367]),
          .engines$config$break_pc_1(signal_inst[376:368]),
          .engines$config$autopull_data_1(signal_inst[377:377]),
          .engines$config$manchester_1(signal_inst[378:378]),
          .engines$start_1(signal_inst[379:379]),
          .engines$program_write$valid_1(signal_inst[380:380]),
          .engines$program_write$addr_1(signal_inst[389:381]),
          .engines$program_write$data_1(signal_inst[405:390]),
          .engines$data_write$valid_1(signal_inst[406:406]),
          .engines$data_write$addr_1(signal_inst[415:407]),
          .engines$data_write$data_1(signal_inst[431:416]),
          .engines$tx$valid_1(signal_inst[432:432]),
          .engines$tx$value_1(signal_inst[448:433]),
          .engines$rx_pop_1(signal_inst[449:449]),
          .engines$clear_irq_1(signal_inst[450:450]),
          .engines$stop_1(signal_inst[451:451]),
          .engines$flush_1(signal_inst[452:452]),
          .engines$resume_1(signal_inst[453:453]),
          .engines$single_step_1(signal_inst[454:454]) );
    assign signal_select_139 = signal_inst[2:1];
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
          .hosts$config$side_set_count_0(signal_select_139),
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
          .hosts$config$break_enable_0(signal_select_69),
          .hosts$config$break_pc_0(signal_select_68),
          .hosts$config$autopull_data_0(signal_select_67),
          .hosts$config$manchester_0(signal_select_66),
          .hosts$start_0(signal_select_65),
          .hosts$program_write$valid_0(signal_select_64),
          .hosts$program_write$addr_0(signal_select_63),
          .hosts$program_write$data_0(signal_select_62),
          .hosts$data_write$valid_0(signal_select_61),
          .hosts$data_write$addr_0(signal_select_60),
          .hosts$data_write$data_0(signal_select_59),
          .hosts$tx$valid_0(signal_select_58),
          .hosts$tx$value_0(signal_select_57),
          .hosts$rx_pop_0(signal_select_56),
          .hosts$clear_irq_0(signal_select_55),
          .hosts$stop_0(signal_select_54),
          .hosts$flush_0(signal_select_53),
          .hosts$resume_0(signal_select_52),
          .hosts$single_step_0(signal_select_51),
          .hosts$config$side_set_count_1(signal_select_50),
          .hosts$config$side_set_base_1(signal_select_49),
          .hosts$config$side_set_pindirs_1(signal_select_48),
          .hosts$config$in_base_1(signal_select_47),
          .hosts$config$in_count_1(signal_select_46),
          .hosts$config$out_base_1(signal_select_45),
          .hosts$config$out_count_1(signal_select_44),
          .hosts$config$set_base_1(signal_select_43),
          .hosts$config$set_count_1(signal_select_42),
          .hosts$config$jmp_pin_1(signal_select_41),
          .hosts$config$capture_pin_1(signal_select_40),
          .hosts$config$capture_rising_1(signal_select_39),
          .hosts$config$in_shift_right_1(signal_select_38),
          .hosts$config$out_shift_right_1(signal_select_37),
          .hosts$config$autopush_1(signal_select_36),
          .hosts$config$push_threshold_1(signal_select_35),
          .hosts$config$autopull_1(signal_select_34),
          .hosts$config$pull_threshold_1(signal_select_33),
          .hosts$config$crc_width_1(signal_select_32),
          .hosts$config$crc_poly_1(signal_select_31),
          .hosts$config$crc_init_1(signal_select_30),
          .hosts$config$crc_reflect_1(signal_select_29),
          .hosts$config$stuff_threshold_1(signal_select_28),
          .hosts$config$stuff_level_1(signal_select_27),
          .hosts$config$wrap_bottom_1(signal_select_26),
          .hosts$config$wrap_top_1(signal_select_25),
          .hosts$config$period_fraction_1(signal_select_24),
          .hosts$config$break_enable_1(signal_select_23),
          .hosts$config$break_pc_1(signal_select_22),
          .hosts$config$autopull_data_1(signal_select_21),
          .hosts$config$manchester_1(signal_select_20),
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
          .engines$resumed_0(signal_inst_1[243:243]),
          .engines$stepping_0(signal_inst_1[244:244]),
          .engines$irq_0(signal_inst_1[245:245]),
          .engines$fault$underflow_0(signal_inst_1[246:246]),
          .engines$fault$overflow_0(signal_inst_1[247:247]),
          .engines$fault$missed_deadline_0(signal_inst_1[248:248]),
          .engines$fault$decode_0(signal_inst_1[249:249]),
          .engines$capture_0(signal_inst_1[273:250]),
          .engines$capture_armed_0(signal_inst_1[274:274]),
          .engines$tx_level_0(signal_inst_1[278:275]),
          .engines$rx_level_0(signal_inst_1[282:279]),
          .engines$rx_head_0(signal_inst_1[298:283]),
          .engines$instruction_0(signal_inst_1[314:299]),
          .engines$decode_ok_0(signal_inst_1[315:315]),
          .engines$opcode_onehot_0(signal_inst_1[323:316]),
          .engines$wait_select_0(signal_inst_1[351:324]),
          .engines$crc_0(signal_inst_1[367:352]),
          .engines$stuff_run_0(signal_inst_1[372:368]),
          .engines$flip_pending_0(signal_inst_1[373:373]),
          .engines$flip_bit_0(signal_inst_1[374:374]),
          .engines$pin_out_1(signal_inst_1[402:375]),
          .engines$pin_dir_1(signal_inst_1[430:403]),
          .engines$pc_1(signal_inst_1[439:431]),
          .engines$data_ptr_1(signal_inst_1[448:440]),
          .engines$data_addr_1(signal_inst_1[457:449]),
          .engines$x_1(signal_inst_1[473:458]),
          .engines$y_1(signal_inst_1[489:474]),
          .engines$p_1(signal_inst_1[505:490]),
          .engines$t_1(signal_inst_1[529:506]),
          .engines$t_fraction_1(signal_inst_1[545:530]),
          .engines$osr_1(signal_inst_1[561:546]),
          .engines$osr_count_1(signal_inst_1[566:562]),
          .engines$isr_1(signal_inst_1[582:567]),
          .engines$isr_count_1(signal_inst_1[587:583]),
          .engines$now_1(signal_inst_1[611:588]),
          .engines$stall_1(signal_inst_1[616:612]),
          .engines$halted_1(signal_inst_1[617:617]),
          .engines$resumed_1(signal_inst_1[618:618]),
          .engines$stepping_1(signal_inst_1[619:619]),
          .engines$irq_1(signal_inst_1[620:620]),
          .engines$fault$underflow_1(signal_inst_1[621:621]),
          .engines$fault$overflow_1(signal_inst_1[622:622]),
          .engines$fault$missed_deadline_1(signal_inst_1[623:623]),
          .engines$fault$decode_1(signal_inst_1[624:624]),
          .engines$capture_1(signal_inst_1[648:625]),
          .engines$capture_armed_1(signal_inst_1[649:649]),
          .engines$tx_level_1(signal_inst_1[653:650]),
          .engines$rx_level_1(signal_inst_1[657:654]),
          .engines$rx_head_1(signal_inst_1[673:658]),
          .engines$instruction_1(signal_inst_1[689:674]),
          .engines$decode_ok_1(signal_inst_1[690:690]),
          .engines$opcode_onehot_1(signal_inst_1[698:691]),
          .engines$wait_select_1(signal_inst_1[726:699]),
          .engines$crc_1(signal_inst_1[742:727]),
          .engines$stuff_run_1(signal_inst_1[747:743]),
          .engines$flip_pending_1(signal_inst_1[748:748]),
          .engines$flip_bit_1(signal_inst_1[749:749]),
          .pin_out(signal_inst_1[769:750]),
          .pin_dir(signal_inst_1[789:770]) );
    assign signal_select_140 = signal_inst_1[769:750];
    assign signal_select_141 = signal_select_140[11:5];
    assign signal_cat = { signal_select_141,
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

