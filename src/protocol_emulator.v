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
    config$line_code,
    config$route,
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
    line_write$valid,
    line_write$addr,
    line_write$data,
    premises$period$valid,
    premises$period$value,
    premises$floor,
    premises$single_edge,
    route_full,
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
    free,
    irq,
    fault$underflow,
    fault$overflow,
    fault$missed_deadline,
    fault$decode,
    fault$assumption,
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
    flip_bit,
    push$valid,
    push$value,
    line_tx,
    line_rx,
    line_flag,
    line_last
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
    input config$line_code;
    input config$route;
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
    input line_write$valid;
    input [4:0] line_write$addr;
    input [15:0] line_write$data;
    input premises$period$valid;
    input [15:0] premises$period$value;
    input premises$floor;
    input premises$single_edge;
    input route_full;
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
    output free;
    output irq;
    output fault$underflow;
    output fault$overflow;
    output fault$missed_deadline;
    output fault$decode;
    output fault$assumption;
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
    output push$valid;
    output [15:0] push$value;
    output [3:0] line_tx;
    output [3:0] line_rx;
    output line_flag;
    output line_last;

    wire signal_and;
    wire [7:0] signal_cat;
    wire [15:0] signal_const;
    wire [15:0] signal_select;
    wire signal_select_1;
    wire [15:0] rx_head_0;
    wire [3:0] signal_select_2;
    wire [3:0] signal_select_3;
    wire signal_not;
    wire signal_const_1;
    wire signal_and_1;
    wire signal_or;
    wire signal_mux;
    wire signal_mux_1;
    wire signal_mux_2;
    reg signal_reg;
    wire seen;
    wire signal_eq;
    wire [4:0] signal_const_3;
    wire signal_lt;
    wire [4:0] d$wait_index;
    wire signal_eq_1;
    wire [1:0] signal_const_4;
    wire signal_eq_2;
    wire [1:0] signal_const_5;
    wire signal_eq_3;
    wire signal_or_1;
    wire signal_and_2;
    wire signal_and_3;
    wire signal_and_4;
    wire signal_and_5;
    wire signal_and_6;
    wire releases;
    wire signal_mux_3;
    wire signal_mux_4;
    wire signal_mux_5;
    reg signal_reg_1;
    wire holding;
    wire signal_and_7;
    wire signal_and_8;
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
    wire signal_select_25;
    wire signal_select_26;
    wire signal_select_27;
    wire signal_select_28;
    wire signal_select_29;
    wire signal_select_30;
    wire signal_select_31;
    reg signal_mux_6;
    wire capture_level;
    wire [3:0] signal_const_6;
    wire signal_eq_4;
    wire signal_and_9;
    wire arms;
    wire signal_and_10;
    wire signal_or_2;
    wire signal_wire;
    wire edge_off;
    wire signal_lt_1;
    wire [15:0] signal_wire_1;
    wire signal_eq_5;
    wire signal_not_1;
    wire signal_wire_2;
    wire signal_mux_7;
    wire signal_wire_3;
    wire [1:0] signal_const_8;
    wire signal_eq_6;
    wire signal_and_11;
    wire [2:0] signal_const_9;
    wire signal_eq_7;
    wire signal_and_12;
    wire signal_eq_8;
    wire [2:0] signal_const_11;
    wire signal_eq_9;
    reg is_opcode$4;
    wire signal_and_13;
    wire signal_or_3;
    wire writes_p;
    wire signal_and_14;
    wire signal_mux_8;
    wire signal_eq_10;
    wire [2:0] signal_const_13;
    wire signal_eq_11;
    reg is_opcode$5;
    wire sets_p;
    wire signal_and_15;
    wire signal_mux_9;
    wire signal_mux_10;
    reg signal_reg_2;
    wire p_loaded;
    wire [2:0] signal_const_14;
    wire signal_eq_12;
    wire signal_eq_13;
    wire [1:0] signal_const_16;
    wire signal_eq_14;
    wire signal_eq_15;
    reg is_opcode$6;
    wire signal_and_16;
    wire signal_and_17;
    wire signal_and_18;
    wire signal_and_19;
    wire signal_or_4;
    wire uses_p;
    wire signal_and_20;
    wire signal_and_21;
    wire period_off;
    wire signal_or_5;
    reg signal_reg_3;
    wire signal_not_2;
    wire signal_and_22;
    reg signal_reg_4;
    wire [23:0] signal_const_20;
    wire [23:0] signal_sub;
    wire signal_eq_16;
    wire signal_not_3;
    wire [23:0] signal_sub_1;
    wire signal_select_32;
    wire signal_not_4;
    wire deadline_late;
    wire signal_and_23;
    wire signal_and_24;
    reg signal_reg_5;
    wire signal_and_25;
    wire signal_and_26;
    reg signal_reg_6;
    wire signal_and_27;
    wire signal_and_28;
    wire signal_and_29;
    wire signal_or_6;
    wire signal_and_30;
    wire signal_or_7;
    wire signal_and_31;
    reg signal_reg_7;
    wire signal_wire_4;
    wire signal_mux_11;
    wire [3:0] signal_const_25;
    wire signal_eq_17;
    wire signal_and_32;
    wire signal_and_33;
    wire signal_mux_12;
    wire signal_wire_5;
    reg irq_0;
    wire [8:0] signal_const_26;
    wire [8:0] signal_select_33;
    wire [8:0] signal_const_28;
    wire [8:0] signal_add;
    wire [8:0] signal_mux_13;
    wire [8:0] signal_mux_14;
    wire signal_or_8;
    wire [8:0] signal_mux_15;
    wire [8:0] data_ptr_next;
    reg [8:0] signal_reg_8;
    wire [8:0] data_ptr_0;
    wire signal_and_34;
    wire signal_or_9;
    wire [27:0] signal_const_29;
    wire [15:0] signal_select_34;
    wire [11:0] signal_select_35;
    wire [27:0] signal_cat_1;
    wire [7:0] signal_select_36;
    wire [19:0] signal_select_37;
    wire [27:0] signal_cat_2;
    wire [3:0] signal_select_38;
    wire [23:0] signal_select_39;
    wire [27:0] signal_cat_3;
    wire [1:0] signal_select_40;
    wire [25:0] signal_select_41;
    wire [27:0] signal_cat_4;
    wire signal_select_42;
    wire [26:0] signal_select_43;
    wire [27:0] signal_cat_5;
    wire [10:0] signal_const_30;
    wire [15:0] signal_cat_6;
    wire [11:0] signal_const_31;
    wire [27:0] signal_cat_7;
    wire signal_select_44;
    wire [27:0] signal_mux_16;
    wire signal_select_45;
    wire [27:0] signal_mux_17;
    wire signal_select_46;
    wire [27:0] signal_mux_18;
    wire signal_select_47;
    wire [27:0] signal_mux_19;
    wire signal_select_48;
    wire [27:0] signal_mux_20;
    wire [27:0] signal_and_35;
    wire [27:0] signal_const_32;
    wire [15:0] signal_select_49;
    wire [11:0] signal_select_50;
    wire [27:0] signal_cat_8;
    wire [7:0] signal_select_51;
    wire [19:0] signal_select_52;
    wire [27:0] signal_cat_9;
    wire [3:0] signal_select_53;
    wire [23:0] signal_select_54;
    wire [27:0] signal_cat_10;
    wire [1:0] signal_select_55;
    wire [25:0] signal_select_56;
    wire [27:0] signal_cat_11;
    wire signal_select_57;
    wire [26:0] signal_select_58;
    wire [27:0] signal_cat_12;
    wire [7:0] signal_const_34;
    wire [7:0] signal_select_59;
    wire [15:0] signal_cat_13;
    wire [3:0] signal_const_35;
    wire [11:0] signal_select_60;
    wire [15:0] signal_cat_14;
    wire [13:0] signal_select_61;
    wire [15:0] signal_cat_15;
    wire [15:0] signal_const_37;
    wire [15:0] signal_const_38;
    wire signal_select_62;
    wire [15:0] signal_mux_21;
    wire signal_select_63;
    wire [15:0] signal_mux_22;
    wire signal_select_64;
    wire [15:0] signal_mux_23;
    wire signal_select_65;
    wire [15:0] signal_mux_24;
    wire signal_select_66;
    wire [15:0] signal_mux_25;
    wire [15:0] signal_not_5;
    wire [27:0] signal_cat_16;
    wire signal_select_67;
    wire [27:0] signal_mux_26;
    wire signal_select_68;
    wire [27:0] signal_mux_27;
    wire signal_select_69;
    wire [27:0] signal_mux_28;
    wire signal_select_70;
    wire [27:0] signal_mux_29;
    wire signal_select_71;
    wire [27:0] signal_mux_30;
    wire [27:0] signal_and_36;
    wire [27:0] signal_not_6;
    wire [27:0] signal_and_37;
    wire [27:0] signal_or_10;
    wire [2:0] signal_const_40;
    wire signal_eq_18;
    wire [27:0] signal_mux_31;
    wire [15:0] signal_select_72;
    wire [11:0] signal_select_73;
    wire [27:0] signal_cat_17;
    wire [7:0] signal_select_74;
    wire [19:0] signal_select_75;
    wire [27:0] signal_cat_18;
    wire [3:0] signal_select_76;
    wire [23:0] signal_select_77;
    wire [27:0] signal_cat_19;
    wire [1:0] signal_select_78;
    wire [25:0] signal_select_79;
    wire [27:0] signal_cat_20;
    wire signal_select_80;
    wire [26:0] signal_select_81;
    wire [27:0] signal_cat_21;
    wire [27:0] signal_cat_22;
    wire signal_select_82;
    wire [27:0] signal_mux_32;
    wire signal_select_83;
    wire [27:0] signal_mux_33;
    wire signal_select_84;
    wire [27:0] signal_mux_34;
    wire signal_select_85;
    wire [27:0] signal_mux_35;
    wire signal_select_86;
    wire [27:0] signal_mux_36;
    wire [27:0] signal_and_38;
    wire [15:0] signal_select_87;
    wire [11:0] signal_select_88;
    wire [27:0] signal_cat_23;
    wire [7:0] signal_select_89;
    wire [19:0] signal_select_90;
    wire [27:0] signal_cat_24;
    wire [3:0] signal_select_91;
    wire [23:0] signal_select_92;
    wire [27:0] signal_cat_25;
    wire [1:0] signal_select_93;
    wire [25:0] signal_select_94;
    wire [27:0] signal_cat_26;
    wire signal_select_95;
    wire [26:0] signal_select_96;
    wire [27:0] signal_cat_27;
    wire [7:0] signal_select_97;
    wire [15:0] signal_cat_28;
    wire [11:0] signal_select_98;
    wire [15:0] signal_cat_29;
    wire [13:0] signal_select_99;
    wire [15:0] signal_cat_30;
    wire signal_select_100;
    wire [15:0] signal_mux_37;
    wire signal_select_101;
    wire [15:0] signal_mux_38;
    wire signal_select_102;
    wire [15:0] signal_mux_39;
    wire signal_select_103;
    wire [15:0] signal_mux_40;
    wire signal_select_104;
    wire [15:0] signal_mux_41;
    wire [15:0] signal_not_7;
    wire [27:0] signal_cat_31;
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
    wire [27:0] signal_and_39;
    wire [27:0] signal_not_8;
    wire [27:0] signal_and_40;
    wire [27:0] signal_or_11;
    wire signal_eq_19;
    wire [27:0] signal_mux_47;
    wire [15:0] signal_select_110;
    wire [11:0] signal_select_111;
    wire [27:0] signal_cat_32;
    wire [7:0] signal_select_112;
    wire [19:0] signal_select_113;
    wire [27:0] signal_cat_33;
    wire [3:0] signal_select_114;
    wire [23:0] signal_select_115;
    wire [27:0] signal_cat_34;
    wire [1:0] signal_select_116;
    wire [25:0] signal_select_117;
    wire [27:0] signal_cat_35;
    wire signal_select_118;
    wire [26:0] signal_select_119;
    wire [27:0] signal_cat_36;
    wire signal_not_9;
    wire signal_select_120;
    wire [1:0] signal_cat_37;
    wire [13:0] signal_const_51;
    wire [15:0] signal_cat_38;
    wire [27:0] signal_cat_39;
    wire signal_select_121;
    wire [27:0] signal_mux_48;
    wire signal_select_122;
    wire [27:0] signal_mux_49;
    wire signal_select_123;
    wire [27:0] signal_mux_50;
    wire signal_select_124;
    wire [27:0] signal_mux_51;
    wire signal_select_125;
    wire [27:0] signal_mux_52;
    wire [27:0] signal_and_41;
    wire [15:0] signal_select_126;
    wire [11:0] signal_select_127;
    wire [27:0] signal_cat_40;
    wire [7:0] signal_select_128;
    wire [19:0] signal_select_129;
    wire [27:0] signal_cat_41;
    wire [3:0] signal_select_130;
    wire [23:0] signal_select_131;
    wire [27:0] signal_cat_42;
    wire [1:0] signal_select_132;
    wire [25:0] signal_select_133;
    wire [27:0] signal_cat_43;
    wire [27:0] signal_const_54;
    wire [27:0] signal_const_55;
    wire signal_select_134;
    wire [27:0] signal_mux_53;
    wire signal_select_135;
    wire [27:0] signal_mux_54;
    wire signal_select_136;
    wire [27:0] signal_mux_55;
    wire signal_select_137;
    wire [27:0] signal_mux_56;
    wire signal_select_138;
    wire [27:0] signal_mux_57;
    wire [27:0] signal_and_42;
    wire [27:0] signal_not_10;
    wire [27:0] signal_and_43;
    wire [27:0] signal_or_12;
    wire [15:0] signal_select_139;
    wire [11:0] signal_select_140;
    wire [27:0] signal_cat_44;
    wire [7:0] signal_select_141;
    wire [19:0] signal_select_142;
    wire [27:0] signal_cat_45;
    wire [3:0] signal_select_143;
    wire [23:0] signal_select_144;
    wire [27:0] signal_cat_46;
    wire [1:0] signal_select_145;
    wire [25:0] signal_select_146;
    wire [27:0] signal_cat_47;
    wire signal_select_147;
    wire [26:0] signal_select_148;
    wire [27:0] signal_cat_48;
    wire signal_select_149;
    wire signal_and_44;
    wire signal_select_150;
    wire line_level;
    wire signal_not_11;
    wire [1:0] signal_cat_49;
    wire [15:0] signal_cat_50;
    wire [15:0] out_pins_value;
    wire [27:0] signal_cat_51;
    wire signal_select_151;
    wire [27:0] signal_mux_58;
    wire signal_select_152;
    wire [27:0] signal_mux_59;
    wire signal_select_153;
    wire [27:0] signal_mux_60;
    wire signal_select_154;
    wire [27:0] signal_mux_61;
    wire signal_select_155;
    wire [27:0] signal_mux_62;
    wire [27:0] signal_and_45;
    wire [15:0] signal_select_156;
    wire [11:0] signal_select_157;
    wire [27:0] signal_cat_52;
    wire [7:0] signal_select_158;
    wire [19:0] signal_select_159;
    wire [27:0] signal_cat_53;
    wire [3:0] signal_select_160;
    wire [23:0] signal_select_161;
    wire [27:0] signal_cat_54;
    wire [1:0] signal_select_162;
    wire [25:0] signal_select_163;
    wire [27:0] signal_cat_55;
    wire signal_select_164;
    wire [26:0] signal_select_165;
    wire [27:0] signal_cat_56;
    wire [7:0] signal_select_166;
    wire [15:0] signal_cat_57;
    wire [11:0] signal_select_167;
    wire [15:0] signal_cat_58;
    wire [13:0] signal_select_168;
    wire [15:0] signal_cat_59;
    wire signal_select_169;
    wire [15:0] signal_mux_63;
    wire signal_select_170;
    wire [15:0] signal_mux_64;
    wire signal_select_171;
    wire [15:0] signal_mux_65;
    wire signal_select_172;
    wire [15:0] signal_mux_66;
    wire [4:0] signal_const_65;
    wire signal_lt_2;
    wire signal_not_12;
    wire [4:0] signal_mux_67;
    wire [4:0] out_pins_count;
    wire signal_select_173;
    wire [15:0] signal_mux_68;
    wire [15:0] signal_not_13;
    wire [27:0] signal_cat_60;
    wire signal_select_174;
    wire [27:0] signal_mux_69;
    wire signal_select_175;
    wire [27:0] signal_mux_70;
    wire signal_select_176;
    wire [27:0] signal_mux_71;
    wire signal_select_177;
    wire [27:0] signal_mux_72;
    wire signal_select_178;
    wire [27:0] signal_mux_73;
    wire [27:0] signal_and_46;
    wire [27:0] signal_not_14;
    wire [27:0] signal_and_47;
    wire [27:0] signal_or_13;
    wire [27:0] signal_mux_74;
    wire signal_eq_20;
    wire [27:0] signal_mux_75;
    reg [27:0] pin_out_next;
    wire signal_not_15;
    wire signal_not_16;
    wire [4:0] signal_const_68;
    wire [4:0] signal_const_71;
    wire [4:0] signal_const_72;
    wire [4:0] signal_and_48;
    wire [4:0] signal_and_49;
    wire [4:0] signal_const_74;
    wire [4:0] signal_and_50;
    reg [4:0] d$delay;
    wire [4:0] signal_sub_2;
    wire signal_eq_21;
    wire signal_not_17;
    wire [4:0] signal_mux_76;
    wire [4:0] signal_mux_77;
    wire [4:0] signal_mux_78;
    wire [4:0] stall_next;
    reg [4:0] signal_reg_9;
    wire [4:0] stall_0;
    wire signal_eq_22;
    wire [3:0] signal_const_77;
    wire signal_eq_23;
    wire signal_and_51;
    wire signal_and_52;
    wire signal_mux_79;
    wire [3:0] signal_const_78;
    wire [3:0] signal_select_179;
    wire signal_lt_3;
    wire [3:0] signal_select_180;
    wire signal_eq_24;
    wire signal_and_53;
    wire [2:0] signal_select_181;
    wire signal_lt_4;
    wire signal_select_182;
    wire signal_not_18;
    wire signal_or_14;
    wire [1:0] signal_select_183;
    wire signal_lt_5;
    wire signal_and_54;
    wire [2:0] signal_select_184;
    wire signal_lt_6;
    wire [1:0] signal_select_185;
    wire signal_lt_7;
    wire [4:0] signal_const_84;
    wire signal_lt_8;
    wire signal_not_19;
    wire [4:0] signal_select_186;
    wire signal_lt_9;
    wire signal_not_20;
    wire signal_and_55;
    wire signal_eq_25;
    wire signal_eq_26;
    wire signal_lt_10;
    wire signal_lt_11;
    wire [1:0] signal_select_187;
    reg signal_mux_80;
    wire [3:0] signal_const_90;
    wire [3:0] signal_select_188;
    wire signal_lt_12;
    wire [15:0] signal_wire_6;
    wire [8:0] signal_wire_7;
    wire [8:0] signal_wire_8;
    wire signal_eq_27;
    wire [8:0] signal_mux_81;
    wire [8:0] signal_add_1;
    wire signal_eq_28;
    wire [8:0] signal_mux_82;
    wire [8:0] signal_wire_9;
    wire [8:0] signal_add_2;
    wire [8:0] signal_wire_10;
    wire [8:0] d$jmp_target;
    wire signal_not_21;
    wire signal_not_22;
    wire signal_select_189;
    wire signal_select_190;
    wire signal_mux_83;
    wire signal_mux_84;
    wire [3:0] signal_const_100;
    wire signal_eq_29;
    wire signal_and_56;
    wire signal_and_57;
    wire signal_mux_85;
    wire signal_mux_86;
    reg signal_reg_10;
    wire line_flag_0;
    wire [4:0] signal_add_3;
    wire [4:0] stuff_run_max;
    wire signal_eq_30;
    wire [4:0] signal_mux_87;
    wire signal_wire_11;
    wire signal_eq_31;
    wire [4:0] signal_mux_88;
    wire [4:0] signal_mux_89;
    wire signal_eq_32;
    wire signal_and_58;
    wire [4:0] stuff_run_next;
    wire [4:0] signal_mux_90;
    wire [4:0] signal_mux_91;
    reg [4:0] signal_reg_11;
    wire [4:0] stuff_run_0;
    wire signal_lt_13;
    wire signal_not_23;
    wire [4:0] signal_wire_12;
    wire signal_eq_33;
    wire signal_not_24;
    wire signal_and_59;
    wire signal_mux_92;
    wire signal_lt_14;
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
    wire signal_select_212;
    wire signal_select_213;
    wire signal_select_214;
    wire signal_select_215;
    wire signal_select_216;
    wire signal_select_217;
    wire signal_select_218;
    reg signal_mux_93;
    wire signal_not_25;
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
    wire [4:0] signal_wire_13;
    reg signal_mux_94;
    wire signal_eq_34;
    wire signal_not_26;
    wire signal_eq_35;
    wire signal_not_27;
    wire signal_eq_36;
    wire signal_not_28;
    reg jmp_taken;
    wire [8:0] jmp_target_or_next;
    wire [8:0] signal_mux_95;
    wire [8:0] signal_mux_96;
    wire [8:0] pc_value_next;
    reg [8:0] signal_reg_12;
    wire [8:0] pc_0;
    wire signal_eq_37;
    wire [8:0] pc_next;
    wire [8:0] signal_mux_97;
    wire [8:0] pc_after_next;
    wire signal_or_15;
    reg refill;
    wire signal_not_29;
    wire signal_wire_14;
    wire signal_wire_15;
    wire [15:0] push_value;
    wire [15:0] signal_wire_16;
    wire signal_not_30;
    wire signal_not_31;
    wire [3:0] signal_const_111;
    wire signal_eq_38;
    wire signal_and_60;
    wire signal_and_61;
    wire pushes;
    wire signal_and_62;
    wire pushed;
    wire signal_and_63;
    wire signal_wire_17;
    wire [21:0] signal_inst;
    wire signal_select_247;
    wire signal_wire_18;
    wire rx_full;
    wire signal_not_32;
    wire signal_mux_98;
    wire [23:0] signal_xor;
    wire [23:0] signal_sub_3;
    wire [23:0] signal_cat_61;
    wire [23:0] signal_add_4;
    reg [23:0] signal_mux_99;
    wire signal_eq_39;
    wire [23:0] signal_mux_100;
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
    wire [23:0] signal_cat_62;
    wire [23:0] signal_not_33;
    reg [23:0] mov_value_t;
    wire [2:0] signal_const_115;
    wire signal_eq_40;
    wire [23:0] signal_mux_101;
    wire [23:0] signal_cat_63;
    wire signal_eq_41;
    wire [23:0] signal_mux_102;
    wire [15:0] signal_wire_19;
    wire [16:0] signal_cat_64;
    wire signal_eq_42;
    wire [15:0] signal_mux_103;
    wire signal_eq_43;
    wire [15:0] signal_mux_104;
    wire signal_eq_44;
    wire [15:0] signal_mux_105;
    wire [15:0] signal_select_272;
    wire [15:0] signal_mux_106;
    reg [15:0] t_fraction_next;
    reg [15:0] signal_reg_13;
    wire [15:0] t_fraction_0;
    wire [16:0] signal_cat_65;
    wire [16:0] fraction_sum;
    wire signal_select_273;
    wire [22:0] signal_const_125;
    wire [23:0] signal_cat_66;
    wire [23:0] signal_cat_67;
    wire [23:0] signal_add_5;
    wire [23:0] t_advanced;
    wire signal_eq_45;
    wire signal_and_64;
    wire releases_deadline;
    wire advances_deadline;
    wire [23:0] signal_mux_107;
    reg [23:0] t_next;
    reg [23:0] signal_reg_14;
    wire [23:0] t_0;
    wire [23:0] signal_sub_4;
    wire signal_select_274;
    wire deadline_ready;
    wire signal_eq_46;
    wire [27:0] signal_and_65;
    wire signal_eq_47;
    wire wait_pin_prev;
    wire signal_eq_48;
    wire signal_not_34;
    wire signal_and_66;
    wire d$wait_polarity;
    wire [27:0] signal_const_130;
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
    wire signal_and_80;
    wire signal_and_81;
    wire signal_not_35;
    wire signal_and_82;
    wire signal_and_83;
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
    wire signal_and_95;
    wire signal_and_96;
    wire signal_not_36;
    wire signal_and_97;
    wire signal_and_98;
    wire signal_and_99;
    wire signal_and_100;
    wire signal_and_101;
    wire signal_and_102;
    wire signal_and_103;
    wire signal_and_104;
    wire signal_and_105;
    wire signal_and_106;
    wire signal_and_107;
    wire signal_not_37;
    wire signal_and_108;
    wire signal_and_109;
    wire signal_and_110;
    wire signal_and_111;
    wire signal_and_112;
    wire signal_and_113;
    wire signal_and_114;
    wire signal_not_38;
    wire signal_and_115;
    wire signal_and_116;
    wire signal_and_117;
    wire signal_and_118;
    wire signal_not_39;
    wire signal_and_119;
    wire signal_and_120;
    wire signal_and_121;
    wire signal_and_122;
    wire signal_select_275;
    wire signal_select_276;
    wire signal_and_123;
    wire signal_select_277;
    wire signal_and_124;
    wire signal_select_278;
    wire signal_and_125;
    wire [4:0] signal_select_279;
    wire signal_select_280;
    wire signal_and_126;
    wire [31:0] signal_cat_68;
    wire [27:0] signal_select_281;
    reg [27:0] wait_select_0;
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
    wire signal_mux_108;
    wire signal_select_297;
    wire signal_select_298;
    wire signal_select_299;
    wire signal_mux_109;
    wire signal_select_300;
    wire signal_select_301;
    wire signal_select_302;
    wire signal_mux_110;
    wire signal_select_303;
    wire signal_select_304;
    wire signal_select_305;
    wire signal_mux_111;
    wire signal_select_306;
    wire signal_select_307;
    wire signal_select_308;
    wire signal_mux_112;
    wire signal_select_309;
    wire signal_select_310;
    wire signal_select_311;
    wire signal_mux_113;
    wire signal_select_312;
    wire signal_select_313;
    wire signal_select_314;
    wire signal_mux_114;
    wire signal_select_315;
    wire signal_select_316;
    wire [15:0] signal_select_317;
    wire [11:0] signal_select_318;
    wire [27:0] signal_cat_69;
    wire [7:0] signal_select_319;
    wire [19:0] signal_select_320;
    wire [27:0] signal_cat_70;
    wire [3:0] signal_select_321;
    wire [23:0] signal_select_322;
    wire [27:0] signal_cat_71;
    wire [1:0] signal_select_323;
    wire [25:0] signal_select_324;
    wire [27:0] signal_cat_72;
    wire signal_select_325;
    wire [26:0] signal_select_326;
    wire [27:0] signal_cat_73;
    wire [15:0] signal_cat_74;
    wire [27:0] signal_cat_75;
    wire signal_select_327;
    wire [27:0] signal_mux_115;
    wire signal_select_328;
    wire [27:0] signal_mux_116;
    wire signal_select_329;
    wire [27:0] signal_mux_117;
    wire signal_select_330;
    wire [27:0] signal_mux_118;
    wire signal_select_331;
    wire [27:0] signal_mux_119;
    wire [27:0] signal_and_127;
    wire [27:0] signal_const_134;
    wire [15:0] signal_select_332;
    wire [11:0] signal_select_333;
    wire [27:0] signal_cat_76;
    wire [7:0] signal_select_334;
    wire [19:0] signal_select_335;
    wire [27:0] signal_cat_77;
    wire [3:0] signal_select_336;
    wire [23:0] signal_select_337;
    wire [27:0] signal_cat_78;
    wire [1:0] signal_select_338;
    wire [25:0] signal_select_339;
    wire [27:0] signal_cat_79;
    wire signal_select_340;
    wire [26:0] signal_select_341;
    wire [27:0] signal_cat_80;
    wire [7:0] signal_select_342;
    wire [15:0] signal_cat_81;
    wire [11:0] signal_select_343;
    wire [15:0] signal_cat_82;
    wire [13:0] signal_select_344;
    wire [15:0] signal_cat_83;
    wire signal_select_345;
    wire [15:0] signal_mux_120;
    wire signal_select_346;
    wire [15:0] signal_mux_121;
    wire signal_select_347;
    wire [15:0] signal_mux_122;
    wire signal_select_348;
    wire [15:0] signal_mux_123;
    wire [2:0] signal_wire_20;
    wire [4:0] signal_cat_84;
    wire signal_select_349;
    wire [15:0] signal_mux_124;
    wire [15:0] signal_not_40;
    wire [27:0] signal_cat_85;
    wire signal_select_350;
    wire [27:0] signal_mux_125;
    wire signal_select_351;
    wire [27:0] signal_mux_126;
    wire signal_select_352;
    wire [27:0] signal_mux_127;
    wire signal_select_353;
    wire [27:0] signal_mux_128;
    wire [4:0] signal_wire_21;
    wire signal_select_354;
    wire [27:0] signal_mux_129;
    wire [27:0] signal_and_128;
    wire [27:0] signal_not_41;
    wire [27:0] signal_and_129;
    wire [27:0] signal_or_16;
    wire [2:0] signal_const_143;
    wire signal_eq_49;
    wire [27:0] signal_mux_130;
    wire [15:0] signal_select_355;
    wire [11:0] signal_select_356;
    wire [27:0] signal_cat_86;
    wire [7:0] signal_select_357;
    wire [19:0] signal_select_358;
    wire [27:0] signal_cat_87;
    wire [3:0] signal_select_359;
    wire [23:0] signal_select_360;
    wire [27:0] signal_cat_88;
    wire [1:0] signal_select_361;
    wire [25:0] signal_select_362;
    wire [27:0] signal_cat_89;
    wire signal_select_363;
    wire [26:0] signal_select_364;
    wire [27:0] signal_cat_90;
    wire [27:0] signal_cat_91;
    wire signal_select_365;
    wire [27:0] signal_mux_131;
    wire signal_select_366;
    wire [27:0] signal_mux_132;
    wire signal_select_367;
    wire [27:0] signal_mux_133;
    wire signal_select_368;
    wire [27:0] signal_mux_134;
    wire signal_select_369;
    wire [27:0] signal_mux_135;
    wire [27:0] signal_and_130;
    wire [15:0] signal_select_370;
    wire [11:0] signal_select_371;
    wire [27:0] signal_cat_92;
    wire [7:0] signal_select_372;
    wire [19:0] signal_select_373;
    wire [27:0] signal_cat_93;
    wire [3:0] signal_select_374;
    wire [23:0] signal_select_375;
    wire [27:0] signal_cat_94;
    wire [1:0] signal_select_376;
    wire [25:0] signal_select_377;
    wire [27:0] signal_cat_95;
    wire signal_select_378;
    wire [26:0] signal_select_379;
    wire [27:0] signal_cat_96;
    wire [7:0] signal_select_380;
    wire [15:0] signal_cat_97;
    wire [11:0] signal_select_381;
    wire [15:0] signal_cat_98;
    wire [13:0] signal_select_382;
    wire [15:0] signal_cat_99;
    wire signal_select_383;
    wire [15:0] signal_mux_136;
    wire signal_select_384;
    wire [15:0] signal_mux_137;
    wire signal_select_385;
    wire [15:0] signal_mux_138;
    wire signal_select_386;
    wire [15:0] signal_mux_139;
    wire [4:0] signal_wire_22;
    wire signal_select_387;
    wire [15:0] signal_mux_140;
    wire [15:0] signal_not_42;
    wire [27:0] signal_cat_100;
    wire signal_select_388;
    wire [27:0] signal_mux_141;
    wire signal_select_389;
    wire [27:0] signal_mux_142;
    wire signal_select_390;
    wire [27:0] signal_mux_143;
    wire signal_select_391;
    wire [27:0] signal_mux_144;
    wire signal_select_392;
    wire [27:0] signal_mux_145;
    wire [27:0] signal_and_131;
    wire [27:0] signal_not_43;
    wire [27:0] signal_and_132;
    wire [27:0] signal_or_17;
    wire signal_eq_50;
    wire [27:0] signal_mux_146;
    wire [15:0] signal_select_393;
    wire [11:0] signal_select_394;
    wire [27:0] signal_cat_101;
    wire [7:0] signal_select_395;
    wire [19:0] signal_select_396;
    wire [27:0] signal_cat_102;
    wire [3:0] signal_select_397;
    wire [23:0] signal_select_398;
    wire [27:0] signal_cat_103;
    wire [1:0] signal_select_399;
    wire [25:0] signal_select_400;
    wire [27:0] signal_cat_104;
    wire signal_select_401;
    wire [26:0] signal_select_402;
    wire [27:0] signal_cat_105;
    wire [15:0] signal_and_133;
    wire [7:0] signal_select_403;
    wire [15:0] signal_cat_106;
    wire [11:0] signal_select_404;
    wire [15:0] signal_cat_107;
    wire [13:0] signal_select_405;
    wire [15:0] signal_cat_108;
    wire [14:0] signal_select_406;
    wire [15:0] signal_cat_109;
    wire [15:0] signal_wire_23;
    wire [15:0] signal_select_407;
    wire signal_not_44;
    wire signal_and_134;
    wire [15:0] signal_mux_147;
    wire signal_select_408;
    wire signal_select_409;
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
    wire [15:0] signal_cat_110;
    wire [15:0] signal_not_45;
    wire [23:0] signal_cat_111;
    wire [23:0] signal_cat_112;
    wire [23:0] signal_cat_113;
    wire [15:0] signal_xor_1;
    wire [15:0] signal_sub_5;
    wire signal_eq_51;
    wire signal_and_135;
    wire [15:0] signal_mux_148;
    wire signal_eq_52;
    wire [15:0] signal_mux_149;
    wire signal_eq_53;
    wire [15:0] signal_mux_150;
    wire [7:0] signal_select_424;
    wire [15:0] signal_cat_114;
    wire [11:0] signal_select_425;
    wire [15:0] signal_cat_115;
    wire [13:0] signal_select_426;
    wire [15:0] signal_cat_116;
    wire [14:0] signal_select_427;
    wire [15:0] signal_cat_117;
    wire signal_select_428;
    wire [15:0] signal_mux_151;
    wire signal_select_429;
    wire [15:0] signal_mux_152;
    wire signal_select_430;
    wire [15:0] signal_mux_153;
    wire signal_select_431;
    wire [15:0] signal_mux_154;
    wire signal_select_432;
    wire [15:0] signal_mux_155;
    wire [7:0] signal_select_433;
    wire [15:0] signal_cat_118;
    wire [11:0] signal_select_434;
    wire [15:0] signal_cat_119;
    wire [13:0] signal_select_435;
    wire [15:0] signal_cat_120;
    wire [14:0] signal_select_436;
    wire [15:0] signal_cat_121;
    wire signal_select_437;
    wire [15:0] signal_mux_156;
    wire signal_select_438;
    wire [15:0] signal_mux_157;
    wire signal_select_439;
    wire [15:0] signal_mux_158;
    wire signal_select_440;
    wire [15:0] signal_mux_159;
    wire signal_select_441;
    wire [15:0] signal_mux_160;
    wire [15:0] signal_or_18;
    wire [7:0] signal_select_442;
    wire [15:0] signal_cat_122;
    wire [11:0] signal_select_443;
    wire [15:0] signal_cat_123;
    wire [13:0] signal_select_444;
    wire [15:0] signal_cat_124;
    wire signal_select_445;
    wire [15:0] signal_mux_161;
    wire signal_select_446;
    wire [15:0] signal_mux_162;
    wire signal_select_447;
    wire [15:0] signal_mux_163;
    wire signal_select_448;
    wire [15:0] signal_mux_164;
    wire signal_select_449;
    wire [15:0] signal_mux_165;
    wire [15:0] mask;
    wire signal_select_450;
    wire signal_and_136;
    wire signal_select_451;
    wire line_bit;
    wire [14:0] signal_const_187;
    wire [15:0] signal_cat_125;
    wire signal_wire_24;
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
    reg signal_mux_166;
    wire signal_eq_54;
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
    reg [27:0] signal_reg_15;
    wire [27:0] pins_sampled;
    wire signal_select_507;
    reg signal_mux_167;
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
    wire [4:0] signal_wire_25;
    reg signal_mux_168;
    wire signal_eq_55;
    wire signal_not_46;
    wire signal_eq_56;
    wire signal_and_137;
    wire signal_and_138;
    wire signal_mux_169;
    wire signal_mux_170;
    reg signal_reg_16;
    wire capture_armed_0;
    wire signal_and_139;
    wire captured;
    wire [23:0] signal_const_194;
    wire [23:0] signal_add_6;
    wire [23:0] signal_mux_171;
    reg [23:0] signal_reg_17;
    wire [23:0] now_0;
    reg [23:0] signal_reg_18;
    wire [23:0] capture_0;
    wire [15:0] signal_select_536;
    wire [15:0] signal_wire_26;
    wire [7:0] signal_select_537;
    wire [15:0] signal_cat_126;
    wire [11:0] signal_select_538;
    wire [15:0] signal_cat_127;
    wire [13:0] signal_select_539;
    wire [15:0] signal_cat_128;
    wire signal_select_540;
    wire [15:0] signal_mux_172;
    wire signal_select_541;
    wire [15:0] signal_mux_173;
    wire signal_select_542;
    wire [15:0] signal_mux_174;
    wire signal_select_543;
    wire [15:0] signal_mux_175;
    wire signal_select_544;
    wire [15:0] signal_mux_176;
    wire [15:0] signal_not_47;
    wire [15:0] signal_xor_2;
    wire [14:0] signal_select_545;
    wire [15:0] signal_cat_129;
    wire signal_select_546;
    wire signal_xor_3;
    wire [15:0] signal_mux_177;
    wire [15:0] signal_wire_27;
    wire [15:0] signal_xor_4;
    wire [14:0] signal_select_547;
    wire [15:0] signal_cat_130;
    wire signal_select_548;
    wire signal_select_549;
    wire crossing_bit;
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
    wire [4:0] signal_wire_28;
    wire [4:0] signal_sub_6;
    reg signal_mux_178;
    wire signal_xor_5;
    wire [15:0] signal_mux_179;
    wire signal_wire_29;
    wire [15:0] signal_mux_180;
    wire [15:0] crc_stepped;
    wire signal_not_48;
    wire signal_or_19;
    wire signal_eq_57;
    wire bit_crosses;
    wire bit_counts;
    wire [15:0] signal_mux_181;
    wire [3:0] signal_const_206;
    wire signal_eq_58;
    wire signal_and_140;
    wire [15:0] crc_next;
    wire [15:0] signal_mux_182;
    wire [15:0] signal_mux_183;
    reg [15:0] signal_reg_19;
    wire [15:0] crc_0;
    wire [7:0] signal_select_566;
    wire [15:0] signal_cat_131;
    wire [11:0] signal_select_567;
    wire [15:0] signal_cat_132;
    wire [13:0] signal_select_568;
    wire [15:0] signal_cat_133;
    wire signal_select_569;
    wire [15:0] signal_mux_184;
    wire signal_select_570;
    wire [15:0] signal_mux_185;
    wire signal_select_571;
    wire [15:0] signal_mux_186;
    wire signal_select_572;
    wire [15:0] signal_mux_187;
    wire signal_select_573;
    wire [15:0] signal_mux_188;
    wire [15:0] signal_not_49;
    wire [11:0] signal_select_574;
    wire [15:0] signal_select_575;
    wire [27:0] signal_cat_134;
    wire [19:0] signal_select_576;
    wire [7:0] signal_select_577;
    wire [27:0] signal_cat_135;
    wire [23:0] signal_select_578;
    wire [3:0] signal_select_579;
    wire [27:0] signal_cat_136;
    wire [25:0] signal_select_580;
    wire [1:0] signal_select_581;
    wire [27:0] signal_cat_137;
    wire [26:0] signal_select_582;
    wire signal_select_583;
    wire [27:0] signal_cat_138;
    wire signal_select_584;
    wire [27:0] signal_mux_189;
    wire signal_select_585;
    wire [27:0] signal_mux_190;
    wire signal_select_586;
    wire [27:0] signal_mux_191;
    wire signal_select_587;
    wire [27:0] signal_mux_192;
    wire signal_select_588;
    wire [27:0] signal_mux_193;
    wire [15:0] signal_select_589;
    wire [15:0] signal_and_141;
    reg [15:0] in_source_value;
    wire [15:0] signal_mux_194;
    wire [15:0] in_value;
    wire [7:0] signal_select_590;
    wire [15:0] signal_cat_139;
    wire [11:0] signal_select_591;
    wire [15:0] signal_cat_140;
    wire [13:0] signal_select_592;
    wire [15:0] signal_cat_141;
    wire [14:0] signal_select_593;
    wire [15:0] signal_cat_142;
    wire signal_select_594;
    wire [15:0] signal_mux_195;
    wire signal_select_595;
    wire [15:0] signal_mux_196;
    wire signal_select_596;
    wire [15:0] signal_mux_197;
    wire signal_select_597;
    wire [15:0] signal_mux_198;
    wire signal_select_598;
    wire [15:0] signal_mux_199;
    wire [15:0] signal_or_20;
    wire signal_wire_30;
    wire [15:0] isr_shifted;
    wire signal_not_50;
    wire [4:0] signal_wire_31;
    wire [4:0] signal_select_599;
    wire [5:0] signal_cat_143;
    wire signal_eq_59;
    wire signal_and_142;
    wire [4:0] signal_mux_200;
    wire signal_eq_60;
    wire [4:0] signal_mux_201;
    wire signal_eq_61;
    wire [4:0] signal_mux_202;
    wire [4:0] signal_mux_203;
    wire [4:0] signal_mux_204;
    reg [4:0] isr_count_next_value;
    reg [4:0] signal_reg_20;
    wire [4:0] isr_count_0;
    wire [5:0] signal_cat_144;
    wire [5:0] signal_add_7;
    wire [5:0] signal_const_224;
    wire signal_lt_15;
    wire [4:0] isr_count_next;
    wire signal_lt_16;
    wire signal_not_51;
    wire signal_wire_32;
    wire signal_and_143;
    wire autopush_now;
    wire [15:0] signal_mux_205;
    wire [5:0] signal_select_600;
    wire signal_eq_62;
    wire signal_and_144;
    wire [5:0] signal_select_601;
    wire [5:0] signal_select_602;
    wire [11:0] signal_cat_145;
    reg [11:0] line_table$15;
    wire [4:0] signal_const_227;
    wire signal_eq_63;
    wire signal_and_145;
    wire [5:0] signal_select_603;
    wire [5:0] signal_select_604;
    wire [11:0] signal_cat_146;
    reg [11:0] line_table$14;
    wire [4:0] signal_const_229;
    wire signal_eq_64;
    wire signal_and_146;
    wire [5:0] signal_select_605;
    wire [5:0] signal_select_606;
    wire [11:0] signal_cat_147;
    reg [11:0] line_table$13;
    wire [4:0] signal_const_231;
    wire signal_eq_65;
    wire signal_and_147;
    wire [5:0] signal_select_607;
    wire [5:0] signal_select_608;
    wire [11:0] signal_cat_148;
    reg [11:0] line_table$12;
    wire [4:0] signal_const_233;
    wire signal_eq_66;
    wire signal_and_148;
    wire [5:0] signal_select_609;
    wire [5:0] signal_select_610;
    wire [11:0] signal_cat_149;
    reg [11:0] line_table$11;
    wire [4:0] signal_const_235;
    wire signal_eq_67;
    wire signal_and_149;
    wire [5:0] signal_select_611;
    wire [5:0] signal_select_612;
    wire [11:0] signal_cat_150;
    reg [11:0] line_table$10;
    wire [4:0] signal_const_237;
    wire signal_eq_68;
    wire signal_and_150;
    wire [5:0] signal_select_613;
    wire [5:0] signal_select_614;
    wire [11:0] signal_cat_151;
    reg [11:0] line_table$9;
    wire [4:0] signal_const_239;
    wire signal_eq_69;
    wire signal_and_151;
    wire [5:0] signal_select_615;
    wire [5:0] signal_select_616;
    wire [11:0] signal_cat_152;
    reg [11:0] line_table$8;
    wire signal_eq_70;
    wire signal_and_152;
    wire [5:0] signal_select_617;
    wire [5:0] signal_select_618;
    wire [11:0] signal_cat_153;
    reg [11:0] line_table$7;
    wire [4:0] signal_const_243;
    wire signal_eq_71;
    wire signal_and_153;
    wire [5:0] signal_select_619;
    wire [5:0] signal_select_620;
    wire [11:0] signal_cat_154;
    reg [11:0] line_table$6;
    wire [4:0] signal_const_245;
    wire signal_eq_72;
    wire signal_and_154;
    wire [5:0] signal_select_621;
    wire [5:0] signal_select_622;
    wire [11:0] signal_cat_155;
    reg [11:0] line_table$5;
    wire [4:0] signal_const_247;
    wire signal_eq_73;
    wire signal_and_155;
    wire [5:0] signal_select_623;
    wire [5:0] signal_select_624;
    wire [11:0] signal_cat_156;
    reg [11:0] line_table$4;
    wire [4:0] signal_const_249;
    wire signal_eq_74;
    wire signal_and_156;
    wire [5:0] signal_select_625;
    wire [5:0] signal_select_626;
    wire [11:0] signal_cat_157;
    reg [11:0] line_table$3;
    wire signal_eq_75;
    wire signal_and_157;
    wire [5:0] signal_select_627;
    wire [5:0] signal_select_628;
    wire [11:0] signal_cat_158;
    reg [11:0] line_table$2;
    wire signal_eq_76;
    wire signal_and_158;
    wire [5:0] signal_select_629;
    wire [5:0] signal_select_630;
    wire [11:0] signal_cat_159;
    reg [11:0] line_table$1;
    wire signal_eq_77;
    wire signal_and_159;
    wire [5:0] signal_select_631;
    wire [5:0] signal_select_632;
    wire [11:0] signal_cat_160;
    reg [11:0] line_table$0;
    wire [3:0] line_rx_start;
    wire [3:0] signal_select_633;
    wire [3:0] signal_mux_206;
    wire [3:0] signal_mux_207;
    reg [3:0] signal_reg_21;
    wire [3:0] line_rx_0;
    wire [5:0] signal_select_634;
    wire [5:0] signal_select_635;
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
    wire signal_select_647;
    wire signal_select_648;
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
    wire [15:0] signal_select_663;
    wire [11:0] signal_select_664;
    wire [27:0] signal_cat_161;
    wire [7:0] signal_select_665;
    wire [19:0] signal_select_666;
    wire [27:0] signal_cat_162;
    wire [3:0] signal_select_667;
    wire [23:0] signal_select_668;
    wire [27:0] signal_cat_163;
    wire [1:0] signal_select_669;
    wire [25:0] signal_select_670;
    wire [27:0] signal_cat_164;
    wire signal_select_671;
    wire [26:0] signal_select_672;
    wire [27:0] signal_cat_165;
    wire [15:0] signal_cat_166;
    wire [27:0] signal_cat_167;
    wire signal_select_673;
    wire [27:0] signal_mux_208;
    wire signal_select_674;
    wire [27:0] signal_mux_209;
    wire signal_select_675;
    wire [27:0] signal_mux_210;
    wire signal_select_676;
    wire [27:0] signal_mux_211;
    wire signal_select_677;
    wire [27:0] signal_mux_212;
    wire [27:0] signal_and_160;
    wire [15:0] signal_select_678;
    wire [11:0] signal_select_679;
    wire [27:0] signal_cat_168;
    wire [7:0] signal_select_680;
    wire [19:0] signal_select_681;
    wire [27:0] signal_cat_169;
    wire [3:0] signal_select_682;
    wire [23:0] signal_select_683;
    wire [27:0] signal_cat_170;
    wire [1:0] signal_select_684;
    wire [25:0] signal_select_685;
    wire [27:0] signal_cat_171;
    wire signal_select_686;
    wire [26:0] signal_select_687;
    wire [27:0] signal_cat_172;
    wire [7:0] signal_select_688;
    wire [15:0] signal_cat_173;
    wire [11:0] signal_select_689;
    wire [15:0] signal_cat_174;
    wire [13:0] signal_select_690;
    wire [15:0] signal_cat_175;
    wire signal_select_691;
    wire [15:0] signal_mux_213;
    wire signal_select_692;
    wire [15:0] signal_mux_214;
    wire signal_select_693;
    wire [15:0] signal_mux_215;
    wire signal_select_694;
    wire [15:0] signal_mux_216;
    wire signal_select_695;
    wire [15:0] signal_mux_217;
    wire [15:0] signal_not_52;
    wire [27:0] signal_cat_176;
    wire signal_select_696;
    wire [27:0] signal_mux_218;
    wire signal_select_697;
    wire [27:0] signal_mux_219;
    wire signal_select_698;
    wire [27:0] signal_mux_220;
    wire signal_select_699;
    wire [27:0] signal_mux_221;
    wire signal_select_700;
    wire [27:0] signal_mux_222;
    wire [27:0] signal_and_161;
    wire [27:0] signal_not_53;
    wire [15:0] signal_select_701;
    wire [11:0] signal_select_702;
    wire [27:0] signal_cat_177;
    wire [7:0] signal_select_703;
    wire [19:0] signal_select_704;
    wire [27:0] signal_cat_178;
    wire [3:0] signal_select_705;
    wire [23:0] signal_select_706;
    wire [27:0] signal_cat_179;
    wire [1:0] signal_select_707;
    wire [25:0] signal_select_708;
    wire [27:0] signal_cat_180;
    wire signal_select_709;
    wire [26:0] signal_select_710;
    wire [27:0] signal_cat_181;
    wire signal_not_54;
    wire signal_select_711;
    reg signal_reg_22;
    wire flip_bit_0;
    wire signal_not_55;
    wire [1:0] signal_cat_182;
    wire [15:0] signal_cat_183;
    wire [27:0] signal_cat_184;
    wire signal_select_712;
    wire [27:0] signal_mux_223;
    wire signal_select_713;
    wire [27:0] signal_mux_224;
    wire signal_select_714;
    wire [27:0] signal_mux_225;
    wire signal_select_715;
    wire [27:0] signal_mux_226;
    wire signal_select_716;
    wire [27:0] signal_mux_227;
    wire [27:0] signal_and_162;
    wire [15:0] signal_select_717;
    wire [11:0] signal_select_718;
    wire [27:0] signal_cat_185;
    wire [7:0] signal_select_719;
    wire [19:0] signal_select_720;
    wire [27:0] signal_cat_186;
    wire [3:0] signal_select_721;
    wire [23:0] signal_select_722;
    wire [27:0] signal_cat_187;
    wire [1:0] signal_select_723;
    wire [25:0] signal_select_724;
    wire [27:0] signal_cat_188;
    wire signal_select_725;
    wire [27:0] signal_mux_228;
    wire signal_select_726;
    wire [27:0] signal_mux_229;
    wire signal_select_727;
    wire [27:0] signal_mux_230;
    wire signal_select_728;
    wire [27:0] signal_mux_231;
    wire signal_select_729;
    wire [27:0] signal_mux_232;
    wire [27:0] signal_and_163;
    wire [27:0] signal_not_56;
    wire [27:0] signal_and_164;
    wire [27:0] signal_or_21;
    wire signal_mux_233;
    wire signal_eq_78;
    wire manchester_out;
    wire signal_eq_79;
    wire signal_and_165;
    wire signal_and_166;
    wire starts_manchester_bit;
    wire signal_mux_234;
    wire signal_mux_235;
    reg signal_reg_23;
    wire flip_pending_0;
    wire [27:0] pin_out_flipped;
    wire [27:0] signal_and_167;
    wire [27:0] pin_out_side;
    wire [27:0] pin_out_base;
    wire signal_select_730;
    reg out_pin;
    wire signal_select_731;
    wire signal_and_168;
    wire signal_select_732;
    wire signal_xor_6;
    wire [5:0] line_tx_entry;
    wire [3:0] signal_select_733;
    wire signal_eq_80;
    wire signal_wire_33;
    wire signal_not_57;
    wire signal_and_169;
    wire line_out;
    wire signal_eq_81;
    wire signal_and_170;
    wire signal_and_171;
    wire line_steps_out;
    wire [3:0] signal_mux_236;
    wire [3:0] signal_mux_237;
    reg [3:0] signal_reg_24;
    wire [3:0] line_tx_0;
    wire [3:0] signal_mux_238;
    reg [11:0] line_pair;
    wire [5:0] signal_select_734;
    wire line_steps_in;
    wire signal_mux_239;
    wire signal_mux_240;
    reg signal_reg_25;
    wire line_last_0;
    wire [4:0] signal_wire_34;
    wire signal_eq_82;
    wire signal_wire_35;
    wire line_write;
    wire signal_and_172;
    wire [15:0] signal_wire_36;
    wire [7:0] signal_select_735;
    reg [7:0] line_modes;
    wire signal_select_736;
    wire signal_and_173;
    wire signal_select_737;
    wire signal_select_738;
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
    wire signal_select_755;
    wire signal_select_756;
    wire signal_select_757;
    wire signal_select_758;
    wire signal_select_759;
    wire signal_select_760;
    wire signal_select_761;
    wire signal_select_762;
    wire signal_select_763;
    wire signal_select_764;
    reg line_pin;
    wire signal_xor_7;
    wire [5:0] line_rx_entry;
    wire signal_select_765;
    wire signal_eq_83;
    wire signal_eq_84;
    wire signal_eq_85;
    reg is_opcode$2;
    wire signal_wire_37;
    wire signal_and_174;
    wire signal_and_175;
    wire line_in;
    wire line_drop;
    wire [15:0] signal_mux_241;
    reg [15:0] isr_next;
    reg [15:0] signal_reg_26;
    wire [15:0] isr_0;
    wire [15:0] signal_xor_8;
    wire [15:0] signal_sub_7;
    wire [15:0] signal_add_8;
    reg [15:0] signal_mux_242;
    wire signal_eq_86;
    wire [15:0] signal_mux_243;
    wire [15:0] signal_cat_189;
    wire signal_eq_87;
    wire [15:0] signal_mux_244;
    wire signal_eq_88;
    wire [15:0] signal_mux_245;
    wire signal_eq_89;
    wire [15:0] signal_mux_246;
    reg [15:0] p_next;
    reg [15:0] signal_reg_27;
    wire [15:0] p_0;
    wire [15:0] signal_xor_9;
    wire [15:0] signal_sub_8;
    wire [15:0] signal_add_9;
    reg [15:0] signal_mux_247;
    wire signal_eq_90;
    wire [15:0] signal_mux_248;
    wire [15:0] signal_cat_190;
    wire signal_eq_91;
    wire [15:0] signal_mux_249;
    wire signal_eq_92;
    wire [15:0] signal_mux_250;
    wire signal_eq_93;
    wire [15:0] signal_mux_251;
    wire [15:0] signal_const_299;
    wire [15:0] signal_sub_9;
    wire signal_eq_94;
    wire [15:0] signal_mux_252;
    reg [15:0] y_next;
    reg [15:0] signal_reg_28;
    wire [15:0] y_0;
    reg [15:0] signal_mux_253;
    wire [2:0] d$alu_reg$binary_variant;
    wire [2:0] d$alu_imm;
    wire [12:0] signal_const_301;
    wire [15:0] signal_cat_191;
    wire d$alu_is_reg;
    wire [15:0] alu_operand;
    wire [15:0] signal_add_10;
    wire [1:0] d$alu_op$binary_variant;
    reg [15:0] signal_mux_254;
    wire [1:0] d$alu_dest$binary_variant;
    wire signal_eq_95;
    wire [15:0] signal_mux_255;
    wire [4:0] d$set_value;
    wire [15:0] signal_cat_192;
    wire [2:0] signal_const_304;
    wire [2:0] d$set_dest$binary_variant;
    wire signal_eq_96;
    wire [15:0] signal_mux_256;
    wire signal_eq_97;
    wire [15:0] signal_mux_257;
    wire signal_eq_98;
    wire [15:0] signal_mux_258;
    wire [15:0] signal_sub_10;
    wire [3:0] d$jmp_cond$binary_variant;
    wire signal_eq_99;
    wire [15:0] signal_mux_259;
    reg [15:0] x_next;
    reg [15:0] signal_reg_29;
    wire [15:0] x_0;
    wire [23:0] signal_cat_193;
    wire [7:0] signal_select_766;
    wire [15:0] signal_cat_194;
    wire [11:0] signal_select_767;
    wire [15:0] signal_cat_195;
    wire [13:0] signal_select_768;
    wire [15:0] signal_cat_196;
    wire signal_select_769;
    wire [15:0] signal_mux_260;
    wire signal_select_770;
    wire [15:0] signal_mux_261;
    wire signal_select_771;
    wire [15:0] signal_mux_262;
    wire signal_select_772;
    wire [15:0] signal_mux_263;
    wire [4:0] signal_wire_38;
    wire signal_select_773;
    wire [15:0] signal_mux_264;
    wire [15:0] signal_not_58;
    wire [11:0] signal_select_774;
    wire [15:0] signal_select_775;
    wire [27:0] signal_cat_197;
    wire [19:0] signal_select_776;
    wire [7:0] signal_select_777;
    wire [27:0] signal_cat_198;
    wire [23:0] signal_select_778;
    wire [3:0] signal_select_779;
    wire [27:0] signal_cat_199;
    wire [25:0] signal_select_780;
    wire [1:0] signal_select_781;
    wire [27:0] signal_cat_200;
    wire [26:0] signal_select_782;
    wire signal_select_783;
    wire [27:0] signal_cat_201;
    wire signal_select_784;
    wire [27:0] signal_mux_265;
    wire signal_select_785;
    wire [27:0] signal_mux_266;
    wire signal_select_786;
    wire [27:0] signal_mux_267;
    wire signal_select_787;
    wire [27:0] signal_mux_268;
    wire [4:0] signal_wire_39;
    wire signal_select_788;
    wire [27:0] signal_mux_269;
    wire [15:0] signal_select_789;
    wire [15:0] signal_and_176;
    wire [23:0] signal_cat_202;
    wire [2:0] d$mov_source$binary_variant;
    reg [23:0] mov_value24;
    wire [15:0] signal_select_790;
    wire [1:0] d$mov_op$binary_variant;
    reg [15:0] mov_value;
    wire signal_eq_100;
    wire [15:0] signal_mux_270;
    wire [7:0] signal_select_791;
    wire [15:0] signal_cat_203;
    wire [11:0] signal_select_792;
    wire [15:0] signal_cat_204;
    wire [13:0] signal_select_793;
    wire [15:0] signal_cat_205;
    wire [14:0] signal_select_794;
    wire [15:0] signal_cat_206;
    wire signal_select_795;
    wire [15:0] signal_mux_271;
    wire signal_select_796;
    wire [15:0] signal_mux_272;
    wire signal_select_797;
    wire [15:0] signal_mux_273;
    wire signal_select_798;
    wire [15:0] signal_mux_274;
    wire signal_select_799;
    wire [15:0] signal_mux_275;
    wire [7:0] signal_select_800;
    wire [15:0] signal_cat_207;
    wire [11:0] signal_select_801;
    wire [15:0] signal_cat_208;
    wire [13:0] signal_select_802;
    wire [15:0] signal_cat_209;
    wire [14:0] signal_select_803;
    wire [15:0] signal_cat_210;
    wire signal_select_804;
    wire [15:0] signal_mux_276;
    wire signal_select_805;
    wire [15:0] signal_mux_277;
    wire signal_select_806;
    wire [15:0] signal_mux_278;
    wire signal_select_807;
    wire [15:0] signal_mux_279;
    wire signal_select_808;
    wire [15:0] signal_mux_280;
    wire [15:0] osr_shifted;
    reg [15:0] osr_next;
    reg [15:0] signal_reg_30;
    wire [15:0] osr_0;
    wire signal_wire_40;
    wire flush_0;
    wire signal_not_59;
    wire signal_and_177;
    wire signal_and_178;
    wire signal_or_22;
    wire signal_and_179;
    wire tx_pop;
    wire [15:0] signal_wire_41;
    wire signal_wire_42;
    wire [21:0] signal_inst_1;
    wire signal_select_809;
    wire signal_not_60;
    wire signal_not_61;
    wire pull_fifo;
    wire pull_ok;
    wire [15:0] signal_mux_281;
    wire signal_eq_101;
    reg is_opcode$3;
    wire signal_and_180;
    wire pulls_data;
    wire [3:0] signal_const_330;
    wire signal_eq_102;
    wire signal_and_181;
    wire seeks;
    wire signal_or_23;
    wire signal_mux_282;
    reg signal_reg_31;
    wire data_moved;
    wire signal_not_62;
    wire signal_wire_43;
    wire [4:0] signal_wire_44;
    wire [3:0] signal_const_332;
    wire [3:0] d$sys_op$binary_variant;
    wire signal_eq_103;
    wire signal_eq_104;
    reg is_opcode$7;
    wire pulls;
    wire [4:0] signal_mux_283;
    wire [4:0] osr_count_zero;
    wire [2:0] d$mov_dest$binary_variant;
    wire signal_eq_105;
    wire [4:0] signal_mux_284;
    wire [4:0] signal_select_810;
    wire [5:0] signal_cat_211;
    wire [4:0] osr_count_before;
    wire [5:0] signal_cat_212;
    wire [5:0] signal_add_11;
    wire signal_lt_17;
    wire [4:0] osr_count_next;
    reg [4:0] osr_count_next_value;
    reg [4:0] signal_reg_32;
    wire [4:0] osr_count_0;
    wire signal_lt_18;
    wire signal_not_63;
    wire signal_wire_45;
    wire pull_now;
    wire pull_data;
    wire pull_data_ok;
    wire [15:0] osr_before;
    wire signal_select_811;
    wire [15:0] signal_mux_285;
    wire signal_select_812;
    wire [15:0] signal_mux_286;
    wire signal_select_813;
    wire [15:0] signal_mux_287;
    wire signal_select_814;
    wire [15:0] signal_mux_288;
    wire [4:0] shift_back;
    wire signal_select_815;
    wire [15:0] signal_mux_289;
    wire [15:0] signal_and_182;
    wire signal_wire_46;
    wire [15:0] out_value;
    wire [27:0] signal_cat_213;
    wire signal_select_816;
    wire [27:0] signal_mux_290;
    wire signal_select_817;
    wire [27:0] signal_mux_291;
    wire signal_select_818;
    wire [27:0] signal_mux_292;
    wire signal_select_819;
    wire [27:0] signal_mux_293;
    wire signal_select_820;
    wire [27:0] signal_mux_294;
    wire [27:0] signal_and_183;
    wire [15:0] signal_select_821;
    wire [11:0] signal_select_822;
    wire [27:0] signal_cat_214;
    wire [7:0] signal_select_823;
    wire [19:0] signal_select_824;
    wire [27:0] signal_cat_215;
    wire [3:0] signal_select_825;
    wire [23:0] signal_select_826;
    wire [27:0] signal_cat_216;
    wire [1:0] signal_select_827;
    wire [25:0] signal_select_828;
    wire [27:0] signal_cat_217;
    wire signal_select_829;
    wire [26:0] signal_select_830;
    wire [27:0] signal_cat_218;
    wire [7:0] signal_select_831;
    wire [15:0] signal_cat_219;
    wire [11:0] signal_select_832;
    wire [15:0] signal_cat_220;
    wire [13:0] signal_select_833;
    wire [15:0] signal_cat_221;
    wire signal_select_834;
    wire [15:0] signal_mux_295;
    wire signal_select_835;
    wire [15:0] signal_mux_296;
    wire signal_select_836;
    wire [15:0] signal_mux_297;
    wire signal_select_837;
    wire [15:0] signal_mux_298;
    wire [4:0] d$shift_count;
    wire signal_select_838;
    wire [15:0] signal_mux_299;
    wire [15:0] signal_not_64;
    wire [27:0] signal_cat_222;
    wire signal_select_839;
    wire [27:0] signal_mux_300;
    wire signal_select_840;
    wire [27:0] signal_mux_301;
    wire signal_select_841;
    wire [27:0] signal_mux_302;
    wire signal_select_842;
    wire [27:0] signal_mux_303;
    wire [4:0] signal_wire_47;
    wire signal_select_843;
    wire [27:0] signal_mux_304;
    wire [27:0] signal_and_184;
    wire [27:0] signal_not_65;
    wire [27:0] signal_and_185;
    wire [27:0] signal_or_24;
    wire [2:0] d$out_dest$binary_variant;
    wire [2:0] d$in_source$binary_variant;
    wire signal_eq_106;
    wire [27:0] signal_mux_305;
    wire [15:0] signal_select_844;
    wire [11:0] signal_select_845;
    wire [27:0] signal_cat_223;
    wire [7:0] signal_select_846;
    wire [19:0] signal_select_847;
    wire [27:0] signal_cat_224;
    wire [3:0] signal_select_848;
    wire [23:0] signal_select_849;
    wire [27:0] signal_cat_225;
    wire [1:0] signal_select_850;
    wire [25:0] signal_select_851;
    wire [27:0] signal_cat_226;
    wire signal_select_852;
    wire [26:0] signal_select_853;
    wire [27:0] signal_cat_227;
    wire [1:0] signal_select_854;
    wire [1:0] signal_select_855;
    wire [4:0] signal_select_856;
    wire signal_select_857;
    wire [1:0] signal_cat_228;
    reg [1:0] d$side_set;
    wire [15:0] signal_cat_229;
    wire [27:0] signal_cat_230;
    wire signal_select_858;
    wire [27:0] signal_mux_306;
    wire signal_select_859;
    wire [27:0] signal_mux_307;
    wire signal_select_860;
    wire [27:0] signal_mux_308;
    wire signal_select_861;
    wire [27:0] signal_mux_309;
    wire signal_select_862;
    wire [27:0] signal_mux_310;
    wire [27:0] signal_and_186;
    wire [15:0] signal_select_863;
    wire [11:0] signal_select_864;
    wire [27:0] signal_cat_231;
    wire [7:0] signal_select_865;
    wire [19:0] signal_select_866;
    wire [27:0] signal_cat_232;
    wire [3:0] signal_select_867;
    wire [23:0] signal_select_868;
    wire [27:0] signal_cat_233;
    wire [1:0] signal_select_869;
    wire [25:0] signal_select_870;
    wire [27:0] signal_cat_234;
    wire signal_select_871;
    wire [26:0] signal_select_872;
    wire [27:0] signal_cat_235;
    wire [7:0] signal_select_873;
    wire [15:0] signal_cat_236;
    wire [11:0] signal_select_874;
    wire [15:0] signal_cat_237;
    wire [13:0] signal_select_875;
    wire [15:0] signal_cat_238;
    wire signal_select_876;
    wire [15:0] signal_mux_311;
    wire signal_select_877;
    wire [15:0] signal_mux_312;
    wire signal_select_878;
    wire [15:0] signal_mux_313;
    wire signal_select_879;
    wire [15:0] signal_mux_314;
    wire [1:0] signal_wire_48;
    wire [4:0] signal_cat_239;
    wire signal_select_880;
    wire [15:0] signal_mux_315;
    wire [15:0] signal_not_66;
    wire [27:0] signal_cat_240;
    wire signal_select_881;
    wire [27:0] signal_mux_316;
    wire signal_select_882;
    wire [27:0] signal_mux_317;
    wire signal_select_883;
    wire [27:0] signal_mux_318;
    wire signal_select_884;
    wire [27:0] signal_mux_319;
    wire [4:0] signal_wire_49;
    wire signal_select_885;
    wire [27:0] signal_mux_320;
    wire [27:0] signal_and_187;
    wire [27:0] signal_not_67;
    wire [27:0] signal_and_188;
    wire [27:0] pin_dir_side;
    wire signal_wire_50;
    wire [27:0] pin_dir_base;
    wire [2:0] d$opcode$binary_variant;
    reg [27:0] pin_dir_next;
    reg [27:0] signal_reg_33;
    wire [27:0] pin_dir_0;
    wire signal_select_886;
    wire signal_mux_321;
    wire signal_select_887;
    wire signal_select_888;
    wire signal_or_25;
    wire signal_select_889;
    wire signal_select_890;
    wire signal_or_26;
    wire signal_select_891;
    wire signal_select_892;
    wire signal_or_27;
    wire signal_select_893;
    wire signal_select_894;
    wire signal_or_28;
    wire signal_select_895;
    wire signal_select_896;
    wire signal_or_29;
    wire signal_select_897;
    wire signal_select_898;
    wire signal_or_30;
    wire signal_select_899;
    wire signal_select_900;
    wire signal_or_31;
    wire [27:0] signal_wire_51;
    wire signal_select_901;
    wire signal_select_902;
    wire signal_or_32;
    wire [27:0] sample;
    wire [27:0] signal_and_189;
    wire signal_eq_107;
    wire wait_pin_cur;
    wire signal_eq_108;
    reg [15:0] word;
    wire [1:0] d$wait_source$binary_variant;
    reg wait_ready;
    wire signal_not_68;
    wire gnd;
    wire signal_eq_109;
    reg is_opcode$1;
    wire wait_holds;
    wire signal_not_69;
    wire advance;
    wire signal_or_33;
    wire ir_load;
    wire signal_eq_110;
    reg is_opcode$0;
    wire jmp_go;
    wire [8:0] signal_mux_322;
    wire [8:0] signal_mux_323;
    wire [8:0] fetch_addr;
    wire signal_or_34;
    wire signal_not_70;
    wire free_0;
    wire signal_wire_52;
    wire program_read;
    wire [8:0] signal_mux_324;
    wire [8:0] signal_mux_325;
    wire signal_wire_53;
    wire program_write;
    wire vdd;
    wire [15:0] signal_inst_2;
    wire [15:0] signal_wire_54;
    wire [2:0] signal_select_903;
    reg signal_mux_326;
    reg decode_ok_0;
    wire signal_not_71;
    wire signal_and_190;
    wire signal_mux_327;
    wire signal_wire_55;
    wire signal_mux_328;
    wire signal_wire_56;
    wire signal_wire_57;
    wire signal_wire_58;
    reg start_0;
    wire halted_next;
    reg signal_reg_34;
    wire halted_0;
    wire signal_not_72;
    wire signal_and_191;
    wire issue;
    wire go;
    wire op_go;
    wire [27:0] signal_mux_329;
    reg [27:0] signal_reg_35;
    wire [27:0] pin_out_0;
    assign signal_and = pushed & signal_wire_18;
    assign signal_cat = { is_opcode$7,
                          is_opcode$6,
                          is_opcode$5,
                          is_opcode$4,
                          is_opcode$3,
                          is_opcode$2,
                          is_opcode$1,
                          is_opcode$0 };
    assign signal_const = 16'b0000000000000000;
    assign signal_select = signal_inst[15:0];
    assign signal_select_1 = signal_inst[20:20];
    assign rx_head_0 = signal_select_1 ? signal_const : signal_select;
    assign signal_select_2 = signal_inst[19:16];
    assign signal_select_3 = signal_inst_1[19:16];
    assign signal_not = ~ capture_level;
    assign signal_const_1 = 1'b0;
    assign signal_and_1 = holding & capture_level;
    assign signal_or = seen | signal_and_1;
    assign signal_mux = releases ? seen : signal_or;
    assign signal_mux_1 = arms ? gnd : signal_mux;
    assign signal_mux_2 = signal_wire_58 ? gnd : signal_mux_1;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg <= signal_const_1;
        else
            signal_reg <= signal_mux_2;
    end
    assign seen = signal_reg;
    assign signal_eq = d$wait_polarity == signal_wire_24;
    assign signal_const_3 = 5'b11100;
    assign signal_lt = d$wait_index < signal_const_3;
    assign d$wait_index = word[4:0];
    assign signal_eq_1 = d$wait_index == signal_wire_25;
    assign signal_const_4 = 2'b01;
    assign signal_eq_2 = d$wait_source$binary_variant == signal_const_4;
    assign signal_const_5 = 2'b00;
    assign signal_eq_3 = d$wait_source$binary_variant == signal_const_5;
    assign signal_or_1 = signal_eq_3 | signal_eq_2;
    assign signal_and_2 = advance & signal_wire;
    assign signal_and_3 = signal_and_2 & is_opcode$1;
    assign signal_and_4 = signal_and_3 & signal_or_1;
    assign signal_and_5 = signal_and_4 & signal_eq_1;
    assign signal_and_6 = signal_and_5 & signal_lt;
    assign releases = signal_and_6 & signal_eq;
    assign signal_mux_3 = releases ? gnd : holding;
    assign signal_mux_4 = arms ? vdd : signal_mux_3;
    assign signal_mux_5 = signal_wire_58 ? gnd : signal_mux_4;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_1 <= signal_const_1;
        else
            signal_reg_1 <= signal_mux_5;
    end
    assign holding = signal_reg_1;
    assign signal_and_7 = holding & seen;
    assign signal_and_8 = signal_and_7 & signal_not;
    assign signal_select_4 = sample[27:27];
    assign signal_select_5 = sample[26:26];
    assign signal_select_6 = sample[25:25];
    assign signal_select_7 = sample[24:24];
    assign signal_select_8 = sample[23:23];
    assign signal_select_9 = sample[22:22];
    assign signal_select_10 = sample[21:21];
    assign signal_select_11 = sample[20:20];
    assign signal_select_12 = sample[19:19];
    assign signal_select_13 = sample[18:18];
    assign signal_select_14 = sample[17:17];
    assign signal_select_15 = sample[16:16];
    assign signal_select_16 = sample[15:15];
    assign signal_select_17 = sample[14:14];
    assign signal_select_18 = sample[13:13];
    assign signal_select_19 = sample[12:12];
    assign signal_select_20 = sample[11:11];
    assign signal_select_21 = sample[10:10];
    assign signal_select_22 = sample[9:9];
    assign signal_select_23 = sample[8:8];
    assign signal_select_24 = sample[7:7];
    assign signal_select_25 = sample[6:6];
    assign signal_select_26 = sample[5:5];
    assign signal_select_27 = sample[4:4];
    assign signal_select_28 = sample[3:3];
    assign signal_select_29 = sample[2:2];
    assign signal_select_30 = sample[1:1];
    assign signal_select_31 = sample[0:0];
    always @* begin
        case (signal_wire_25)
        0:
            signal_mux_6 <= signal_select_31;
        1:
            signal_mux_6 <= signal_select_30;
        2:
            signal_mux_6 <= signal_select_29;
        3:
            signal_mux_6 <= signal_select_28;
        4:
            signal_mux_6 <= signal_select_27;
        5:
            signal_mux_6 <= signal_select_26;
        6:
            signal_mux_6 <= signal_select_25;
        7:
            signal_mux_6 <= signal_select_24;
        8:
            signal_mux_6 <= signal_select_23;
        9:
            signal_mux_6 <= signal_select_22;
        10:
            signal_mux_6 <= signal_select_21;
        11:
            signal_mux_6 <= signal_select_20;
        12:
            signal_mux_6 <= signal_select_19;
        13:
            signal_mux_6 <= signal_select_18;
        14:
            signal_mux_6 <= signal_select_17;
        15:
            signal_mux_6 <= signal_select_16;
        16:
            signal_mux_6 <= signal_select_15;
        17:
            signal_mux_6 <= signal_select_14;
        18:
            signal_mux_6 <= signal_select_13;
        19:
            signal_mux_6 <= signal_select_12;
        20:
            signal_mux_6 <= signal_select_11;
        21:
            signal_mux_6 <= signal_select_10;
        22:
            signal_mux_6 <= signal_select_9;
        23:
            signal_mux_6 <= signal_select_8;
        24:
            signal_mux_6 <= signal_select_7;
        25:
            signal_mux_6 <= signal_select_6;
        26:
            signal_mux_6 <= signal_select_5;
        default:
            signal_mux_6 <= signal_select_4;
        endcase
    end
    assign capture_level = signal_mux_6 == signal_wire_24;
    assign signal_const_6 = 4'b0111;
    assign signal_eq_4 = d$sys_op$binary_variant == signal_const_6;
    assign signal_and_9 = is_opcode$7 & signal_eq_4;
    assign arms = advance & signal_and_9;
    assign signal_and_10 = arms & capture_level;
    assign signal_or_2 = signal_and_10 | signal_and_8;
    assign signal_wire = premises$single_edge;
    assign edge_off = signal_wire & signal_or_2;
    assign signal_lt_1 = p_0 < signal_wire_1;
    assign signal_wire_1 = premises$period$value;
    assign signal_eq_5 = p_0 == signal_wire_1;
    assign signal_not_1 = ~ signal_eq_5;
    assign signal_wire_2 = premises$floor;
    assign signal_mux_7 = signal_wire_2 ? signal_lt_1 : signal_not_1;
    assign signal_wire_3 = premises$period$valid;
    assign signal_const_8 = 2'b10;
    assign signal_eq_6 = d$alu_dest$binary_variant == signal_const_8;
    assign signal_and_11 = is_opcode$6 & signal_eq_6;
    assign signal_const_9 = 3'b110;
    assign signal_eq_7 = d$out_dest$binary_variant == signal_const_9;
    assign signal_and_12 = is_opcode$3 & signal_eq_7;
    assign signal_eq_8 = d$mov_dest$binary_variant == signal_const_9;
    assign signal_const_11 = 3'b100;
    assign signal_eq_9 = signal_select_903 == signal_const_11;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$4 <= gnd;
        else
            if (ir_load)
                is_opcode$4 <= signal_eq_9;
    end
    assign signal_and_13 = is_opcode$4 & signal_eq_8;
    assign signal_or_3 = signal_and_13 | signal_and_12;
    assign writes_p = signal_or_3 | signal_and_11;
    assign signal_and_14 = advance & writes_p;
    assign signal_mux_8 = signal_and_14 ? vdd : p_loaded;
    assign signal_eq_10 = d$set_dest$binary_variant == signal_const_11;
    assign signal_const_13 = 3'b101;
    assign signal_eq_11 = signal_select_903 == signal_const_13;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$5 <= gnd;
        else
            if (ir_load)
                is_opcode$5 <= signal_eq_11;
    end
    assign sets_p = is_opcode$5 & signal_eq_10;
    assign signal_and_15 = advance & sets_p;
    assign signal_mux_9 = signal_and_15 ? gnd : signal_mux_8;
    assign signal_mux_10 = start_0 ? gnd : signal_mux_9;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_2 <= signal_const_1;
        else
            signal_reg_2 <= signal_mux_10;
    end
    assign p_loaded = signal_reg_2;
    assign signal_const_14 = 3'b010;
    assign signal_eq_12 = d$alu_reg$binary_variant == signal_const_14;
    assign signal_eq_13 = d$alu_op$binary_variant == signal_const_5;
    assign signal_const_16 = 2'b11;
    assign signal_eq_14 = d$alu_dest$binary_variant == signal_const_16;
    assign signal_eq_15 = signal_select_903 == signal_const_9;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$6 <= gnd;
        else
            if (ir_load)
                is_opcode$6 <= signal_eq_15;
    end
    assign signal_and_16 = is_opcode$6 & signal_eq_14;
    assign signal_and_17 = signal_and_16 & signal_eq_13;
    assign signal_and_18 = signal_and_17 & d$alu_is_reg;
    assign signal_and_19 = signal_and_18 & signal_eq_12;
    assign signal_or_4 = advances_deadline | signal_and_19;
    assign uses_p = advance & signal_or_4;
    assign signal_and_20 = uses_p & p_loaded;
    assign signal_and_21 = signal_and_20 & signal_wire_3;
    assign period_off = signal_and_21 & signal_mux_7;
    assign signal_or_5 = period_off | edge_off;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_3 <= signal_const_1;
        else
            if (signal_or_5)
                signal_reg_3 <= vdd;
    end
    assign signal_not_2 = ~ decode_ok_0;
    assign signal_and_22 = issue & signal_not_2;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_4 <= signal_const_1;
        else
            if (signal_and_22)
                signal_reg_4 <= vdd;
    end
    assign signal_const_20 = 24'b000000000000000000000000;
    assign signal_sub = now_0 - t_0;
    assign signal_eq_16 = signal_sub == signal_const_20;
    assign signal_not_3 = ~ signal_eq_16;
    assign signal_sub_1 = now_0 - t_0;
    assign signal_select_32 = signal_sub_1[23:23];
    assign signal_not_4 = ~ signal_select_32;
    assign deadline_late = signal_not_4 & signal_not_3;
    assign signal_and_23 = op_go & releases_deadline;
    assign signal_and_24 = signal_and_23 & deadline_late;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_5 <= signal_const_1;
        else
            if (signal_and_24)
                signal_reg_5 <= vdd;
    end
    assign signal_and_25 = op_go & pushes;
    assign signal_and_26 = signal_and_25 & rx_full;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_6 <= signal_const_1;
        else
            if (signal_and_26)
                signal_reg_6 <= vdd;
    end
    assign signal_and_27 = pulls & signal_select_809;
    assign signal_and_28 = pull_data & data_moved;
    assign signal_and_29 = pull_fifo & signal_select_809;
    assign signal_or_6 = signal_and_29 | signal_and_28;
    assign signal_and_30 = is_opcode$3 & signal_or_6;
    assign signal_or_7 = signal_and_30 | signal_and_27;
    assign signal_and_31 = op_go & signal_or_7;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_7 <= signal_const_1;
        else
            if (signal_and_31)
                signal_reg_7 <= vdd;
    end
    assign signal_wire_4 = clear_irq;
    assign signal_mux_11 = signal_wire_4 ? gnd : irq_0;
    assign signal_const_25 = 4'b0010;
    assign signal_eq_17 = d$sys_op$binary_variant == signal_const_25;
    assign signal_and_32 = is_opcode$7 & signal_eq_17;
    assign signal_and_33 = op_go & signal_and_32;
    assign signal_mux_12 = signal_and_33 ? vdd : signal_mux_11;
    assign signal_wire_5 = signal_mux_12;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            irq_0 <= signal_const_1;
        else
            irq_0 <= signal_wire_5;
    end
    assign signal_const_26 = 9'b000000000;
    assign signal_select_33 = x_0[8:0];
    assign signal_const_28 = 9'b000000001;
    assign signal_add = data_ptr_0 + signal_const_28;
    assign signal_mux_13 = pulls_data ? signal_add : data_ptr_0;
    assign signal_mux_14 = seeks ? signal_select_33 : signal_mux_13;
    assign signal_or_8 = signal_wire_58 | start_0;
    assign signal_mux_15 = signal_or_8 ? signal_const_26 : signal_mux_14;
    assign data_ptr_next = signal_mux_15;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_8 <= signal_const_26;
        else
            signal_reg_8 <= data_ptr_next;
    end
    assign data_ptr_0 = signal_reg_8;
    assign signal_and_34 = issue & flip_pending_0;
    assign signal_or_9 = op_go | signal_and_34;
    assign signal_const_29 = 28'b0000000000000000000000000000;
    assign signal_select_34 = signal_mux_19[27:12];
    assign signal_select_35 = signal_mux_19[11:0];
    assign signal_cat_1 = { signal_select_35,
                            signal_select_34 };
    assign signal_select_36 = signal_mux_18[27:20];
    assign signal_select_37 = signal_mux_18[19:0];
    assign signal_cat_2 = { signal_select_37,
                            signal_select_36 };
    assign signal_select_38 = signal_mux_17[27:24];
    assign signal_select_39 = signal_mux_17[23:0];
    assign signal_cat_3 = { signal_select_39,
                            signal_select_38 };
    assign signal_select_40 = signal_mux_16[27:26];
    assign signal_select_41 = signal_mux_16[25:0];
    assign signal_cat_4 = { signal_select_41,
                            signal_select_40 };
    assign signal_select_42 = signal_cat_7[27:27];
    assign signal_select_43 = signal_cat_7[26:0];
    assign signal_cat_5 = { signal_select_43,
                            signal_select_42 };
    assign signal_const_30 = 11'b00000000000;
    assign signal_cat_6 = { signal_const_30,
                            d$set_value };
    assign signal_const_31 = 12'b000000000000;
    assign signal_cat_7 = { signal_const_31,
                            signal_cat_6 };
    assign signal_select_44 = signal_wire_21[0:0];
    assign signal_mux_16 = signal_select_44 ? signal_cat_5 : signal_cat_7;
    assign signal_select_45 = signal_wire_21[1:1];
    assign signal_mux_17 = signal_select_45 ? signal_cat_4 : signal_mux_16;
    assign signal_select_46 = signal_wire_21[2:2];
    assign signal_mux_18 = signal_select_46 ? signal_cat_3 : signal_mux_17;
    assign signal_select_47 = signal_wire_21[3:3];
    assign signal_mux_19 = signal_select_47 ? signal_cat_2 : signal_mux_18;
    assign signal_select_48 = signal_wire_21[4:4];
    assign signal_mux_20 = signal_select_48 ? signal_cat_1 : signal_mux_19;
    assign signal_and_35 = signal_mux_20 & signal_and_36;
    assign signal_const_32 = 28'b1111111111111111111111100000;
    assign signal_select_49 = signal_mux_29[27:12];
    assign signal_select_50 = signal_mux_29[11:0];
    assign signal_cat_8 = { signal_select_50,
                            signal_select_49 };
    assign signal_select_51 = signal_mux_28[27:20];
    assign signal_select_52 = signal_mux_28[19:0];
    assign signal_cat_9 = { signal_select_52,
                            signal_select_51 };
    assign signal_select_53 = signal_mux_27[27:24];
    assign signal_select_54 = signal_mux_27[23:0];
    assign signal_cat_10 = { signal_select_54,
                             signal_select_53 };
    assign signal_select_55 = signal_mux_26[27:26];
    assign signal_select_56 = signal_mux_26[25:0];
    assign signal_cat_11 = { signal_select_56,
                             signal_select_55 };
    assign signal_select_57 = signal_cat_16[27:27];
    assign signal_select_58 = signal_cat_16[26:0];
    assign signal_cat_12 = { signal_select_58,
                             signal_select_57 };
    assign signal_const_34 = 8'b00000000;
    assign signal_select_59 = signal_mux_23[7:0];
    assign signal_cat_13 = { signal_select_59,
                             signal_const_34 };
    assign signal_const_35 = 4'b0000;
    assign signal_select_60 = signal_mux_22[11:0];
    assign signal_cat_14 = { signal_select_60,
                             signal_const_35 };
    assign signal_select_61 = signal_mux_21[13:0];
    assign signal_cat_15 = { signal_select_61,
                             signal_const_5 };
    assign signal_const_37 = 16'b1111111111111110;
    assign signal_const_38 = 16'b1111111111111111;
    assign signal_select_62 = signal_cat_84[0:0];
    assign signal_mux_21 = signal_select_62 ? signal_const_37 : signal_const_38;
    assign signal_select_63 = signal_cat_84[1:1];
    assign signal_mux_22 = signal_select_63 ? signal_cat_15 : signal_mux_21;
    assign signal_select_64 = signal_cat_84[2:2];
    assign signal_mux_23 = signal_select_64 ? signal_cat_14 : signal_mux_22;
    assign signal_select_65 = signal_cat_84[3:3];
    assign signal_mux_24 = signal_select_65 ? signal_cat_13 : signal_mux_23;
    assign signal_select_66 = signal_cat_84[4:4];
    assign signal_mux_25 = signal_select_66 ? signal_const : signal_mux_24;
    assign signal_not_5 = ~ signal_mux_25;
    assign signal_cat_16 = { signal_const_31,
                             signal_not_5 };
    assign signal_select_67 = signal_wire_21[0:0];
    assign signal_mux_26 = signal_select_67 ? signal_cat_12 : signal_cat_16;
    assign signal_select_68 = signal_wire_21[1:1];
    assign signal_mux_27 = signal_select_68 ? signal_cat_11 : signal_mux_26;
    assign signal_select_69 = signal_wire_21[2:2];
    assign signal_mux_28 = signal_select_69 ? signal_cat_10 : signal_mux_27;
    assign signal_select_70 = signal_wire_21[3:3];
    assign signal_mux_29 = signal_select_70 ? signal_cat_9 : signal_mux_28;
    assign signal_select_71 = signal_wire_21[4:4];
    assign signal_mux_30 = signal_select_71 ? signal_cat_8 : signal_mux_29;
    assign signal_and_36 = signal_mux_30 & signal_const_32;
    assign signal_not_6 = ~ signal_and_36;
    assign signal_and_37 = pin_out_base & signal_not_6;
    assign signal_or_10 = signal_and_37 | signal_and_35;
    assign signal_const_40 = 3'b000;
    assign signal_eq_18 = d$set_dest$binary_variant == signal_const_40;
    assign signal_mux_31 = signal_eq_18 ? signal_or_10 : pin_out_base;
    assign signal_select_72 = signal_mux_35[27:12];
    assign signal_select_73 = signal_mux_35[11:0];
    assign signal_cat_17 = { signal_select_73,
                             signal_select_72 };
    assign signal_select_74 = signal_mux_34[27:20];
    assign signal_select_75 = signal_mux_34[19:0];
    assign signal_cat_18 = { signal_select_75,
                             signal_select_74 };
    assign signal_select_76 = signal_mux_33[27:24];
    assign signal_select_77 = signal_mux_33[23:0];
    assign signal_cat_19 = { signal_select_77,
                             signal_select_76 };
    assign signal_select_78 = signal_mux_32[27:26];
    assign signal_select_79 = signal_mux_32[25:0];
    assign signal_cat_20 = { signal_select_79,
                             signal_select_78 };
    assign signal_select_80 = signal_cat_22[27:27];
    assign signal_select_81 = signal_cat_22[26:0];
    assign signal_cat_21 = { signal_select_81,
                             signal_select_80 };
    assign signal_cat_22 = { signal_const_31,
                             mov_value };
    assign signal_select_82 = signal_wire_47[0:0];
    assign signal_mux_32 = signal_select_82 ? signal_cat_21 : signal_cat_22;
    assign signal_select_83 = signal_wire_47[1:1];
    assign signal_mux_33 = signal_select_83 ? signal_cat_20 : signal_mux_32;
    assign signal_select_84 = signal_wire_47[2:2];
    assign signal_mux_34 = signal_select_84 ? signal_cat_19 : signal_mux_33;
    assign signal_select_85 = signal_wire_47[3:3];
    assign signal_mux_35 = signal_select_85 ? signal_cat_18 : signal_mux_34;
    assign signal_select_86 = signal_wire_47[4:4];
    assign signal_mux_36 = signal_select_86 ? signal_cat_17 : signal_mux_35;
    assign signal_and_38 = signal_mux_36 & signal_and_39;
    assign signal_select_87 = signal_mux_45[27:12];
    assign signal_select_88 = signal_mux_45[11:0];
    assign signal_cat_23 = { signal_select_88,
                             signal_select_87 };
    assign signal_select_89 = signal_mux_44[27:20];
    assign signal_select_90 = signal_mux_44[19:0];
    assign signal_cat_24 = { signal_select_90,
                             signal_select_89 };
    assign signal_select_91 = signal_mux_43[27:24];
    assign signal_select_92 = signal_mux_43[23:0];
    assign signal_cat_25 = { signal_select_92,
                             signal_select_91 };
    assign signal_select_93 = signal_mux_42[27:26];
    assign signal_select_94 = signal_mux_42[25:0];
    assign signal_cat_26 = { signal_select_94,
                             signal_select_93 };
    assign signal_select_95 = signal_cat_31[27:27];
    assign signal_select_96 = signal_cat_31[26:0];
    assign signal_cat_27 = { signal_select_96,
                             signal_select_95 };
    assign signal_select_97 = signal_mux_39[7:0];
    assign signal_cat_28 = { signal_select_97,
                             signal_const_34 };
    assign signal_select_98 = signal_mux_38[11:0];
    assign signal_cat_29 = { signal_select_98,
                             signal_const_35 };
    assign signal_select_99 = signal_mux_37[13:0];
    assign signal_cat_30 = { signal_select_99,
                             signal_const_5 };
    assign signal_select_100 = signal_wire_22[0:0];
    assign signal_mux_37 = signal_select_100 ? signal_const_37 : signal_const_38;
    assign signal_select_101 = signal_wire_22[1:1];
    assign signal_mux_38 = signal_select_101 ? signal_cat_30 : signal_mux_37;
    assign signal_select_102 = signal_wire_22[2:2];
    assign signal_mux_39 = signal_select_102 ? signal_cat_29 : signal_mux_38;
    assign signal_select_103 = signal_wire_22[3:3];
    assign signal_mux_40 = signal_select_103 ? signal_cat_28 : signal_mux_39;
    assign signal_select_104 = signal_wire_22[4:4];
    assign signal_mux_41 = signal_select_104 ? signal_const : signal_mux_40;
    assign signal_not_7 = ~ signal_mux_41;
    assign signal_cat_31 = { signal_const_31,
                             signal_not_7 };
    assign signal_select_105 = signal_wire_47[0:0];
    assign signal_mux_42 = signal_select_105 ? signal_cat_27 : signal_cat_31;
    assign signal_select_106 = signal_wire_47[1:1];
    assign signal_mux_43 = signal_select_106 ? signal_cat_26 : signal_mux_42;
    assign signal_select_107 = signal_wire_47[2:2];
    assign signal_mux_44 = signal_select_107 ? signal_cat_25 : signal_mux_43;
    assign signal_select_108 = signal_wire_47[3:3];
    assign signal_mux_45 = signal_select_108 ? signal_cat_24 : signal_mux_44;
    assign signal_select_109 = signal_wire_47[4:4];
    assign signal_mux_46 = signal_select_109 ? signal_cat_23 : signal_mux_45;
    assign signal_and_39 = signal_mux_46 & signal_const_32;
    assign signal_not_8 = ~ signal_and_39;
    assign signal_and_40 = pin_out_base & signal_not_8;
    assign signal_or_11 = signal_and_40 | signal_and_38;
    assign signal_eq_19 = d$mov_dest$binary_variant == signal_const_40;
    assign signal_mux_47 = signal_eq_19 ? signal_or_11 : pin_out_base;
    assign signal_select_110 = signal_mux_51[27:12];
    assign signal_select_111 = signal_mux_51[11:0];
    assign signal_cat_32 = { signal_select_111,
                             signal_select_110 };
    assign signal_select_112 = signal_mux_50[27:20];
    assign signal_select_113 = signal_mux_50[19:0];
    assign signal_cat_33 = { signal_select_113,
                             signal_select_112 };
    assign signal_select_114 = signal_mux_49[27:24];
    assign signal_select_115 = signal_mux_49[23:0];
    assign signal_cat_34 = { signal_select_115,
                             signal_select_114 };
    assign signal_select_116 = signal_mux_48[27:26];
    assign signal_select_117 = signal_mux_48[25:0];
    assign signal_cat_35 = { signal_select_117,
                             signal_select_116 };
    assign signal_select_118 = signal_cat_39[27:27];
    assign signal_select_119 = signal_cat_39[26:0];
    assign signal_cat_36 = { signal_select_119,
                             signal_select_118 };
    assign signal_not_9 = ~ signal_select_120;
    assign signal_select_120 = out_value[0:0];
    assign signal_cat_37 = { signal_select_120,
                             signal_not_9 };
    assign signal_const_51 = 14'b00000000000000;
    assign signal_cat_38 = { signal_const_51,
                             signal_cat_37 };
    assign signal_cat_39 = { signal_const_31,
                             signal_cat_38 };
    assign signal_select_121 = signal_wire_47[0:0];
    assign signal_mux_48 = signal_select_121 ? signal_cat_36 : signal_cat_39;
    assign signal_select_122 = signal_wire_47[1:1];
    assign signal_mux_49 = signal_select_122 ? signal_cat_35 : signal_mux_48;
    assign signal_select_123 = signal_wire_47[2:2];
    assign signal_mux_50 = signal_select_123 ? signal_cat_34 : signal_mux_49;
    assign signal_select_124 = signal_wire_47[3:3];
    assign signal_mux_51 = signal_select_124 ? signal_cat_33 : signal_mux_50;
    assign signal_select_125 = signal_wire_47[4:4];
    assign signal_mux_52 = signal_select_125 ? signal_cat_32 : signal_mux_51;
    assign signal_and_41 = signal_mux_52 & signal_and_42;
    assign signal_select_126 = signal_mux_56[27:12];
    assign signal_select_127 = signal_mux_56[11:0];
    assign signal_cat_40 = { signal_select_127,
                             signal_select_126 };
    assign signal_select_128 = signal_mux_55[27:20];
    assign signal_select_129 = signal_mux_55[19:0];
    assign signal_cat_41 = { signal_select_129,
                             signal_select_128 };
    assign signal_select_130 = signal_mux_54[27:24];
    assign signal_select_131 = signal_mux_54[23:0];
    assign signal_cat_42 = { signal_select_131,
                             signal_select_130 };
    assign signal_select_132 = signal_mux_53[27:26];
    assign signal_select_133 = signal_mux_53[25:0];
    assign signal_cat_43 = { signal_select_133,
                             signal_select_132 };
    assign signal_const_54 = 28'b0000000000000000000000000110;
    assign signal_const_55 = 28'b0000000000000000000000000011;
    assign signal_select_134 = signal_wire_47[0:0];
    assign signal_mux_53 = signal_select_134 ? signal_const_54 : signal_const_55;
    assign signal_select_135 = signal_wire_47[1:1];
    assign signal_mux_54 = signal_select_135 ? signal_cat_43 : signal_mux_53;
    assign signal_select_136 = signal_wire_47[2:2];
    assign signal_mux_55 = signal_select_136 ? signal_cat_42 : signal_mux_54;
    assign signal_select_137 = signal_wire_47[3:3];
    assign signal_mux_56 = signal_select_137 ? signal_cat_41 : signal_mux_55;
    assign signal_select_138 = signal_wire_47[4:4];
    assign signal_mux_57 = signal_select_138 ? signal_cat_40 : signal_mux_56;
    assign signal_and_42 = signal_mux_57 & signal_const_32;
    assign signal_not_10 = ~ signal_and_42;
    assign signal_and_43 = pin_out_base & signal_not_10;
    assign signal_or_12 = signal_and_43 | signal_and_41;
    assign signal_select_139 = signal_mux_61[27:12];
    assign signal_select_140 = signal_mux_61[11:0];
    assign signal_cat_44 = { signal_select_140,
                             signal_select_139 };
    assign signal_select_141 = signal_mux_60[27:20];
    assign signal_select_142 = signal_mux_60[19:0];
    assign signal_cat_45 = { signal_select_142,
                             signal_select_141 };
    assign signal_select_143 = signal_mux_59[27:24];
    assign signal_select_144 = signal_mux_59[23:0];
    assign signal_cat_46 = { signal_select_144,
                             signal_select_143 };
    assign signal_select_145 = signal_mux_58[27:26];
    assign signal_select_146 = signal_mux_58[25:0];
    assign signal_cat_47 = { signal_select_146,
                             signal_select_145 };
    assign signal_select_147 = signal_cat_51[27:27];
    assign signal_select_148 = signal_cat_51[26:0];
    assign signal_cat_48 = { signal_select_148,
                             signal_select_147 };
    assign signal_select_149 = line_modes[2:2];
    assign signal_and_44 = signal_select_149 & out_pin;
    assign signal_select_150 = line_tx_entry[4:4];
    assign line_level = signal_select_150 ^ signal_and_44;
    assign signal_not_11 = ~ line_level;
    assign signal_cat_49 = { signal_not_11,
                             line_level };
    assign signal_cat_50 = { signal_const_51,
                             signal_cat_49 };
    assign out_pins_value = line_out ? signal_cat_50 : out_value;
    assign signal_cat_51 = { signal_const_31,
                             out_pins_value };
    assign signal_select_151 = signal_wire_47[0:0];
    assign signal_mux_58 = signal_select_151 ? signal_cat_48 : signal_cat_51;
    assign signal_select_152 = signal_wire_47[1:1];
    assign signal_mux_59 = signal_select_152 ? signal_cat_47 : signal_mux_58;
    assign signal_select_153 = signal_wire_47[2:2];
    assign signal_mux_60 = signal_select_153 ? signal_cat_46 : signal_mux_59;
    assign signal_select_154 = signal_wire_47[3:3];
    assign signal_mux_61 = signal_select_154 ? signal_cat_45 : signal_mux_60;
    assign signal_select_155 = signal_wire_47[4:4];
    assign signal_mux_62 = signal_select_155 ? signal_cat_44 : signal_mux_61;
    assign signal_and_45 = signal_mux_62 & signal_and_46;
    assign signal_select_156 = signal_mux_72[27:12];
    assign signal_select_157 = signal_mux_72[11:0];
    assign signal_cat_52 = { signal_select_157,
                             signal_select_156 };
    assign signal_select_158 = signal_mux_71[27:20];
    assign signal_select_159 = signal_mux_71[19:0];
    assign signal_cat_53 = { signal_select_159,
                             signal_select_158 };
    assign signal_select_160 = signal_mux_70[27:24];
    assign signal_select_161 = signal_mux_70[23:0];
    assign signal_cat_54 = { signal_select_161,
                             signal_select_160 };
    assign signal_select_162 = signal_mux_69[27:26];
    assign signal_select_163 = signal_mux_69[25:0];
    assign signal_cat_55 = { signal_select_163,
                             signal_select_162 };
    assign signal_select_164 = signal_cat_60[27:27];
    assign signal_select_165 = signal_cat_60[26:0];
    assign signal_cat_56 = { signal_select_165,
                             signal_select_164 };
    assign signal_select_166 = signal_mux_65[7:0];
    assign signal_cat_57 = { signal_select_166,
                             signal_const_34 };
    assign signal_select_167 = signal_mux_64[11:0];
    assign signal_cat_58 = { signal_select_167,
                             signal_const_35 };
    assign signal_select_168 = signal_mux_63[13:0];
    assign signal_cat_59 = { signal_select_168,
                             signal_const_5 };
    assign signal_select_169 = out_pins_count[0:0];
    assign signal_mux_63 = signal_select_169 ? signal_const_37 : signal_const_38;
    assign signal_select_170 = out_pins_count[1:1];
    assign signal_mux_64 = signal_select_170 ? signal_cat_59 : signal_mux_63;
    assign signal_select_171 = out_pins_count[2:2];
    assign signal_mux_65 = signal_select_171 ? signal_cat_58 : signal_mux_64;
    assign signal_select_172 = out_pins_count[3:3];
    assign signal_mux_66 = signal_select_172 ? signal_cat_57 : signal_mux_65;
    assign signal_const_65 = 5'b00010;
    assign signal_lt_2 = signal_wire_22 < signal_const_65;
    assign signal_not_12 = ~ signal_lt_2;
    assign signal_mux_67 = signal_not_12 ? signal_const_65 : signal_wire_22;
    assign out_pins_count = line_out ? signal_mux_67 : d$shift_count;
    assign signal_select_173 = out_pins_count[4:4];
    assign signal_mux_68 = signal_select_173 ? signal_const : signal_mux_66;
    assign signal_not_13 = ~ signal_mux_68;
    assign signal_cat_60 = { signal_const_31,
                             signal_not_13 };
    assign signal_select_174 = signal_wire_47[0:0];
    assign signal_mux_69 = signal_select_174 ? signal_cat_56 : signal_cat_60;
    assign signal_select_175 = signal_wire_47[1:1];
    assign signal_mux_70 = signal_select_175 ? signal_cat_55 : signal_mux_69;
    assign signal_select_176 = signal_wire_47[2:2];
    assign signal_mux_71 = signal_select_176 ? signal_cat_54 : signal_mux_70;
    assign signal_select_177 = signal_wire_47[3:3];
    assign signal_mux_72 = signal_select_177 ? signal_cat_53 : signal_mux_71;
    assign signal_select_178 = signal_wire_47[4:4];
    assign signal_mux_73 = signal_select_178 ? signal_cat_52 : signal_mux_72;
    assign signal_and_46 = signal_mux_73 & signal_const_32;
    assign signal_not_14 = ~ signal_and_46;
    assign signal_and_47 = pin_out_base & signal_not_14;
    assign signal_or_13 = signal_and_47 | signal_and_45;
    assign signal_mux_74 = manchester_out ? signal_or_12 : signal_or_13;
    assign signal_eq_20 = d$out_dest$binary_variant == signal_const_40;
    assign signal_mux_75 = signal_eq_20 ? signal_mux_74 : pin_out_base;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            pin_out_next <= pin_out_base;
        1:
            pin_out_next <= pin_out_base;
        2:
            pin_out_next <= pin_out_base;
        3:
            pin_out_next <= signal_mux_75;
        4:
            pin_out_next <= signal_mux_47;
        5:
            pin_out_next <= signal_mux_31;
        6:
            pin_out_next <= pin_out_base;
        default:
            pin_out_next <= pin_out_base;
        endcase
    end
    assign signal_not_15 = ~ is_opcode$0;
    assign signal_not_16 = ~ start_0;
    assign signal_const_68 = 5'b00000;
    assign signal_const_71 = 5'b00001;
    assign signal_const_72 = 5'b00111;
    assign signal_and_48 = signal_select_856 & signal_const_72;
    assign signal_and_49 = signal_select_856 & signal_const_72;
    assign signal_const_74 = 5'b01111;
    assign signal_and_50 = signal_select_856 & signal_const_74;
    always @* begin
        case (signal_wire_48)
        0:
            d$delay <= signal_select_856;
        1:
            d$delay <= signal_and_50;
        2:
            d$delay <= signal_and_49;
        default:
            d$delay <= signal_and_48;
        endcase
    end
    assign signal_sub_2 = stall_0 - signal_const_71;
    assign signal_eq_21 = stall_0 == signal_const_68;
    assign signal_not_17 = ~ signal_eq_21;
    assign signal_mux_76 = signal_not_17 ? signal_sub_2 : stall_0;
    assign signal_mux_77 = advance ? d$delay : signal_mux_76;
    assign signal_mux_78 = jmp_go ? signal_const_71 : signal_mux_77;
    assign stall_next = start_0 ? signal_const_68 : signal_mux_78;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_9 <= signal_const_68;
        else
            signal_reg_9 <= stall_next;
    end
    assign stall_0 = signal_reg_9;
    assign signal_eq_22 = stall_0 == signal_const_68;
    assign signal_const_77 = 4'b0001;
    assign signal_eq_23 = d$sys_op$binary_variant == signal_const_77;
    assign signal_and_51 = is_opcode$7 & signal_eq_23;
    assign signal_and_52 = op_go & signal_and_51;
    assign signal_mux_79 = signal_and_52 ? vdd : halted_0;
    assign signal_const_78 = 4'b1001;
    assign signal_select_179 = signal_wire_54[3:0];
    assign signal_lt_3 = signal_select_179 < signal_const_78;
    assign signal_select_180 = signal_wire_54[7:4];
    assign signal_eq_24 = signal_select_180 == signal_const_35;
    assign signal_and_53 = signal_eq_24 & signal_lt_3;
    assign signal_select_181 = signal_wire_54[2:0];
    assign signal_lt_4 = signal_select_181 < signal_const_13;
    assign signal_select_182 = signal_wire_54[3:3];
    assign signal_not_18 = ~ signal_select_182;
    assign signal_or_14 = signal_not_18 | signal_lt_4;
    assign signal_select_183 = signal_wire_54[5:4];
    assign signal_lt_5 = signal_select_183 < signal_const_16;
    assign signal_and_54 = signal_lt_5 & signal_or_14;
    assign signal_select_184 = signal_wire_54[7:5];
    assign signal_lt_6 = signal_select_184 < signal_const_13;
    assign signal_select_185 = signal_wire_54[4:3];
    assign signal_lt_7 = signal_select_185 < signal_const_16;
    assign signal_const_84 = 5'b10000;
    assign signal_lt_8 = signal_const_84 < signal_select_186;
    assign signal_not_19 = ~ signal_lt_8;
    assign signal_select_186 = signal_wire_54[4:0];
    assign signal_lt_9 = signal_select_186 < signal_const_71;
    assign signal_not_20 = ~ signal_lt_9;
    assign signal_and_55 = signal_not_20 & signal_not_19;
    assign signal_eq_25 = signal_select_279 == signal_const_68;
    assign signal_eq_26 = signal_select_279 == signal_const_68;
    assign signal_lt_10 = signal_select_279 < signal_const_3;
    assign signal_lt_11 = signal_select_279 < signal_const_3;
    assign signal_select_187 = signal_wire_54[6:5];
    always @* begin
        case (signal_select_187)
        0:
            signal_mux_80 <= signal_lt_11;
        1:
            signal_mux_80 <= signal_lt_10;
        2:
            signal_mux_80 <= signal_eq_26;
        default:
            signal_mux_80 <= signal_eq_25;
        endcase
    end
    assign signal_const_90 = 4'b1100;
    assign signal_select_188 = signal_wire_54[12:9];
    assign signal_lt_12 = signal_select_188 < signal_const_90;
    assign signal_wire_6 = program_write$data;
    assign signal_wire_7 = program_write$addr;
    assign signal_wire_8 = program_read$value;
    assign signal_eq_27 = signal_const_26 == signal_wire_10;
    assign signal_mux_81 = signal_eq_27 ? signal_wire_9 : signal_const_28;
    assign signal_add_1 = pc_next + signal_const_28;
    assign signal_eq_28 = pc_next == signal_wire_10;
    assign signal_mux_82 = signal_eq_28 ? signal_wire_9 : signal_add_1;
    assign signal_wire_9 = config$wrap_bottom;
    assign signal_add_2 = pc_0 + signal_const_28;
    assign signal_wire_10 = config$wrap_top;
    assign d$jmp_target = word[8:0];
    assign signal_not_21 = ~ rx_full;
    assign signal_not_22 = ~ signal_select_809;
    assign signal_select_189 = line_tx_entry[5:5];
    assign signal_select_190 = line_rx_entry[5:5];
    assign signal_mux_83 = line_steps_in ? signal_select_190 : line_flag_0;
    assign signal_mux_84 = line_steps_out ? signal_select_189 : signal_mux_83;
    assign signal_const_100 = 4'b0110;
    assign signal_eq_29 = d$sys_op$binary_variant == signal_const_100;
    assign signal_and_56 = is_opcode$7 & signal_eq_29;
    assign signal_and_57 = op_go & signal_and_56;
    assign signal_mux_85 = signal_and_57 ? gnd : signal_mux_84;
    assign signal_mux_86 = start_0 ? gnd : signal_mux_85;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_10 <= signal_const_1;
        else
            signal_reg_10 <= signal_mux_86;
    end
    assign line_flag_0 = signal_reg_10;
    assign signal_add_3 = stuff_run_0 + signal_const_71;
    assign stuff_run_max = 5'b11111;
    assign signal_eq_30 = stuff_run_0 == stuff_run_max;
    assign signal_mux_87 = signal_eq_30 ? stuff_run_0 : signal_add_3;
    assign signal_wire_11 = config$stuff_level;
    assign signal_eq_31 = crossing_bit == signal_wire_11;
    assign signal_mux_88 = signal_eq_31 ? signal_mux_87 : signal_const_68;
    assign signal_mux_89 = bit_counts ? signal_mux_88 : stuff_run_0;
    assign signal_eq_32 = d$sys_op$binary_variant == signal_const_100;
    assign signal_and_58 = is_opcode$7 & signal_eq_32;
    assign stuff_run_next = signal_and_58 ? signal_const_68 : signal_mux_89;
    assign signal_mux_90 = go ? stuff_run_next : stuff_run_0;
    assign signal_mux_91 = start_0 ? signal_const_68 : signal_mux_90;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_11 <= signal_const_68;
        else
            signal_reg_11 <= signal_mux_91;
    end
    assign stuff_run_0 = signal_reg_11;
    assign signal_lt_13 = stuff_run_0 < signal_wire_12;
    assign signal_not_23 = ~ signal_lt_13;
    assign signal_wire_12 = config$stuff_threshold;
    assign signal_eq_33 = signal_wire_12 == signal_const_68;
    assign signal_not_24 = ~ signal_eq_33;
    assign signal_and_59 = signal_not_24 & signal_not_23;
    assign signal_mux_92 = signal_wire_37 ? line_flag_0 : signal_and_59;
    assign signal_lt_14 = osr_count_0 < signal_wire_44;
    assign signal_select_191 = sample[27:27];
    assign signal_select_192 = sample[26:26];
    assign signal_select_193 = sample[25:25];
    assign signal_select_194 = sample[24:24];
    assign signal_select_195 = sample[23:23];
    assign signal_select_196 = sample[22:22];
    assign signal_select_197 = sample[21:21];
    assign signal_select_198 = sample[20:20];
    assign signal_select_199 = sample[19:19];
    assign signal_select_200 = sample[18:18];
    assign signal_select_201 = sample[17:17];
    assign signal_select_202 = sample[16:16];
    assign signal_select_203 = sample[15:15];
    assign signal_select_204 = sample[14:14];
    assign signal_select_205 = sample[13:13];
    assign signal_select_206 = sample[12:12];
    assign signal_select_207 = sample[11:11];
    assign signal_select_208 = sample[10:10];
    assign signal_select_209 = sample[9:9];
    assign signal_select_210 = sample[8:8];
    assign signal_select_211 = sample[7:7];
    assign signal_select_212 = sample[6:6];
    assign signal_select_213 = sample[5:5];
    assign signal_select_214 = sample[4:4];
    assign signal_select_215 = sample[3:3];
    assign signal_select_216 = sample[2:2];
    assign signal_select_217 = sample[1:1];
    assign signal_select_218 = sample[0:0];
    always @* begin
        case (signal_wire_13)
        0:
            signal_mux_93 <= signal_select_218;
        1:
            signal_mux_93 <= signal_select_217;
        2:
            signal_mux_93 <= signal_select_216;
        3:
            signal_mux_93 <= signal_select_215;
        4:
            signal_mux_93 <= signal_select_214;
        5:
            signal_mux_93 <= signal_select_213;
        6:
            signal_mux_93 <= signal_select_212;
        7:
            signal_mux_93 <= signal_select_211;
        8:
            signal_mux_93 <= signal_select_210;
        9:
            signal_mux_93 <= signal_select_209;
        10:
            signal_mux_93 <= signal_select_208;
        11:
            signal_mux_93 <= signal_select_207;
        12:
            signal_mux_93 <= signal_select_206;
        13:
            signal_mux_93 <= signal_select_205;
        14:
            signal_mux_93 <= signal_select_204;
        15:
            signal_mux_93 <= signal_select_203;
        16:
            signal_mux_93 <= signal_select_202;
        17:
            signal_mux_93 <= signal_select_201;
        18:
            signal_mux_93 <= signal_select_200;
        19:
            signal_mux_93 <= signal_select_199;
        20:
            signal_mux_93 <= signal_select_198;
        21:
            signal_mux_93 <= signal_select_197;
        22:
            signal_mux_93 <= signal_select_196;
        23:
            signal_mux_93 <= signal_select_195;
        24:
            signal_mux_93 <= signal_select_194;
        25:
            signal_mux_93 <= signal_select_193;
        26:
            signal_mux_93 <= signal_select_192;
        default:
            signal_mux_93 <= signal_select_191;
        endcase
    end
    assign signal_not_25 = ~ signal_mux_93;
    assign signal_select_219 = sample[27:27];
    assign signal_select_220 = sample[26:26];
    assign signal_select_221 = sample[25:25];
    assign signal_select_222 = sample[24:24];
    assign signal_select_223 = sample[23:23];
    assign signal_select_224 = sample[22:22];
    assign signal_select_225 = sample[21:21];
    assign signal_select_226 = sample[20:20];
    assign signal_select_227 = sample[19:19];
    assign signal_select_228 = sample[18:18];
    assign signal_select_229 = sample[17:17];
    assign signal_select_230 = sample[16:16];
    assign signal_select_231 = sample[15:15];
    assign signal_select_232 = sample[14:14];
    assign signal_select_233 = sample[13:13];
    assign signal_select_234 = sample[12:12];
    assign signal_select_235 = sample[11:11];
    assign signal_select_236 = sample[10:10];
    assign signal_select_237 = sample[9:9];
    assign signal_select_238 = sample[8:8];
    assign signal_select_239 = sample[7:7];
    assign signal_select_240 = sample[6:6];
    assign signal_select_241 = sample[5:5];
    assign signal_select_242 = sample[4:4];
    assign signal_select_243 = sample[3:3];
    assign signal_select_244 = sample[2:2];
    assign signal_select_245 = sample[1:1];
    assign signal_select_246 = sample[0:0];
    assign signal_wire_13 = config$jmp_pin;
    always @* begin
        case (signal_wire_13)
        0:
            signal_mux_94 <= signal_select_246;
        1:
            signal_mux_94 <= signal_select_245;
        2:
            signal_mux_94 <= signal_select_244;
        3:
            signal_mux_94 <= signal_select_243;
        4:
            signal_mux_94 <= signal_select_242;
        5:
            signal_mux_94 <= signal_select_241;
        6:
            signal_mux_94 <= signal_select_240;
        7:
            signal_mux_94 <= signal_select_239;
        8:
            signal_mux_94 <= signal_select_238;
        9:
            signal_mux_94 <= signal_select_237;
        10:
            signal_mux_94 <= signal_select_236;
        11:
            signal_mux_94 <= signal_select_235;
        12:
            signal_mux_94 <= signal_select_234;
        13:
            signal_mux_94 <= signal_select_233;
        14:
            signal_mux_94 <= signal_select_232;
        15:
            signal_mux_94 <= signal_select_231;
        16:
            signal_mux_94 <= signal_select_230;
        17:
            signal_mux_94 <= signal_select_229;
        18:
            signal_mux_94 <= signal_select_228;
        19:
            signal_mux_94 <= signal_select_227;
        20:
            signal_mux_94 <= signal_select_226;
        21:
            signal_mux_94 <= signal_select_225;
        22:
            signal_mux_94 <= signal_select_224;
        23:
            signal_mux_94 <= signal_select_223;
        24:
            signal_mux_94 <= signal_select_222;
        25:
            signal_mux_94 <= signal_select_221;
        26:
            signal_mux_94 <= signal_select_220;
        default:
            signal_mux_94 <= signal_select_219;
        endcase
    end
    assign signal_eq_34 = x_0 == y_0;
    assign signal_not_26 = ~ signal_eq_34;
    assign signal_eq_35 = y_0 == signal_const;
    assign signal_not_27 = ~ signal_eq_35;
    assign signal_eq_36 = x_0 == signal_const;
    assign signal_not_28 = ~ signal_eq_36;
    always @* begin
        case (d$jmp_cond$binary_variant)
        0:
            jmp_taken <= vdd;
        1:
            jmp_taken <= signal_not_28;
        2:
            jmp_taken <= signal_not_27;
        3:
            jmp_taken <= signal_not_26;
        4:
            jmp_taken <= signal_mux_94;
        5:
            jmp_taken <= signal_not_25;
        6:
            jmp_taken <= signal_lt_14;
        7:
            jmp_taken <= signal_mux_92;
        8:
            jmp_taken <= signal_not_22;
        9:
            jmp_taken <= signal_select_809;
        10:
            jmp_taken <= signal_not_21;
        default:
            jmp_taken <= rx_full;
        endcase
    end
    assign jmp_target_or_next = jmp_taken ? d$jmp_target : pc_next;
    assign signal_mux_95 = advance ? pc_next : pc_0;
    assign signal_mux_96 = jmp_go ? jmp_target_or_next : signal_mux_95;
    assign pc_value_next = start_0 ? signal_const_26 : signal_mux_96;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_12 <= signal_const_26;
        else
            signal_reg_12 <= pc_value_next;
    end
    assign pc_0 = signal_reg_12;
    assign signal_eq_37 = pc_0 == signal_wire_10;
    assign pc_next = signal_eq_37 ? signal_wire_9 : signal_add_2;
    assign signal_mux_97 = advance ? signal_mux_82 : pc_next;
    assign pc_after_next = start_0 ? signal_mux_81 : signal_mux_97;
    assign signal_or_15 = jmp_go | signal_wire_58;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            refill <= signal_const_1;
        else
            refill <= signal_or_15;
    end
    assign signal_not_29 = ~ signal_select_809;
    assign signal_wire_14 = route_full;
    assign signal_wire_15 = rx_pop;
    assign push_value = is_opcode$2 ? isr_shifted : isr_0;
    assign signal_wire_16 = push_value;
    assign signal_not_30 = ~ signal_wire_18;
    assign signal_not_31 = ~ rx_full;
    assign signal_const_111 = 4'b0011;
    assign signal_eq_38 = d$sys_op$binary_variant == signal_const_111;
    assign signal_and_60 = is_opcode$7 & signal_eq_38;
    assign signal_and_61 = is_opcode$2 & autopush_now;
    assign pushes = signal_and_61 | signal_and_60;
    assign signal_and_62 = op_go & pushes;
    assign pushed = signal_and_62 & signal_not_31;
    assign signal_and_63 = pushed & signal_not_30;
    assign signal_wire_17 = signal_and_63;
    host_fifo
        rx
        ( .clock(signal_wire_57),
          .clear(signal_wire_56),
          .push$valid(signal_wire_17),
          .push$value(signal_wire_16),
          .pop(signal_wire_15),
          .flush(flush_0),
          .head(signal_inst[15:0]),
          .level(signal_inst[19:16]),
          .empty(signal_inst[20:20]),
          .full(signal_inst[21:21]) );
    assign signal_select_247 = signal_inst[21:21];
    assign signal_wire_18 = config$route;
    assign rx_full = signal_wire_18 ? signal_wire_14 : signal_select_247;
    assign signal_not_32 = ~ rx_full;
    assign signal_mux_98 = d$wait_polarity ? signal_not_29 : signal_not_32;
    assign signal_xor = t_0 ^ signal_cat_61;
    assign signal_sub_3 = t_0 - signal_cat_61;
    assign signal_cat_61 = { signal_const_34,
                             alu_operand };
    assign signal_add_4 = t_0 + signal_cat_61;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_99 <= signal_add_4;
        1:
            signal_mux_99 <= signal_sub_3;
        default:
            signal_mux_99 <= signal_xor;
        endcase
    end
    assign signal_eq_39 = d$alu_dest$binary_variant == signal_const_16;
    assign signal_mux_100 = signal_eq_39 ? signal_mux_99 : t_0;
    assign signal_select_248 = mov_value24[23:23];
    assign signal_select_249 = mov_value24[22:22];
    assign signal_select_250 = mov_value24[21:21];
    assign signal_select_251 = mov_value24[20:20];
    assign signal_select_252 = mov_value24[19:19];
    assign signal_select_253 = mov_value24[18:18];
    assign signal_select_254 = mov_value24[17:17];
    assign signal_select_255 = mov_value24[16:16];
    assign signal_select_256 = mov_value24[15:15];
    assign signal_select_257 = mov_value24[14:14];
    assign signal_select_258 = mov_value24[13:13];
    assign signal_select_259 = mov_value24[12:12];
    assign signal_select_260 = mov_value24[11:11];
    assign signal_select_261 = mov_value24[10:10];
    assign signal_select_262 = mov_value24[9:9];
    assign signal_select_263 = mov_value24[8:8];
    assign signal_select_264 = mov_value24[7:7];
    assign signal_select_265 = mov_value24[6:6];
    assign signal_select_266 = mov_value24[5:5];
    assign signal_select_267 = mov_value24[4:4];
    assign signal_select_268 = mov_value24[3:3];
    assign signal_select_269 = mov_value24[2:2];
    assign signal_select_270 = mov_value24[1:1];
    assign signal_select_271 = mov_value24[0:0];
    assign signal_cat_62 = { signal_select_271,
                             signal_select_270,
                             signal_select_269,
                             signal_select_268,
                             signal_select_267,
                             signal_select_266,
                             signal_select_265,
                             signal_select_264,
                             signal_select_263,
                             signal_select_262,
                             signal_select_261,
                             signal_select_260,
                             signal_select_259,
                             signal_select_258,
                             signal_select_257,
                             signal_select_256,
                             signal_select_255,
                             signal_select_254,
                             signal_select_253,
                             signal_select_252,
                             signal_select_251,
                             signal_select_250,
                             signal_select_249,
                             signal_select_248 };
    assign signal_not_33 = ~ mov_value24;
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value_t <= mov_value24;
        1:
            mov_value_t <= signal_not_33;
        default:
            mov_value_t <= signal_cat_62;
        endcase
    end
    assign signal_const_115 = 3'b111;
    assign signal_eq_40 = d$mov_dest$binary_variant == signal_const_115;
    assign signal_mux_101 = signal_eq_40 ? mov_value_t : t_0;
    assign signal_cat_63 = { signal_const_34,
                             out_value };
    assign signal_eq_41 = d$out_dest$binary_variant == signal_const_115;
    assign signal_mux_102 = signal_eq_41 ? signal_cat_63 : t_0;
    assign signal_wire_19 = config$period_fraction;
    assign signal_cat_64 = { gnd,
                             signal_wire_19 };
    assign signal_eq_42 = d$alu_dest$binary_variant == signal_const_16;
    assign signal_mux_103 = signal_eq_42 ? signal_const : t_fraction_0;
    assign signal_eq_43 = d$mov_dest$binary_variant == signal_const_115;
    assign signal_mux_104 = signal_eq_43 ? signal_const : t_fraction_0;
    assign signal_eq_44 = d$out_dest$binary_variant == signal_const_115;
    assign signal_mux_105 = signal_eq_44 ? signal_const : t_fraction_0;
    assign signal_select_272 = fraction_sum[15:0];
    assign signal_mux_106 = advances_deadline ? signal_select_272 : t_fraction_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_fraction_next <= t_fraction_0;
        1:
            t_fraction_next <= signal_mux_106;
        2:
            t_fraction_next <= t_fraction_0;
        3:
            t_fraction_next <= signal_mux_105;
        4:
            t_fraction_next <= signal_mux_104;
        5:
            t_fraction_next <= t_fraction_0;
        6:
            t_fraction_next <= signal_mux_103;
        default:
            t_fraction_next <= t_fraction_0;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_13 <= signal_const;
        else
            if (go)
                signal_reg_13 <= t_fraction_next;
    end
    assign t_fraction_0 = signal_reg_13;
    assign signal_cat_65 = { gnd,
                             t_fraction_0 };
    assign fraction_sum = signal_cat_65 + signal_cat_64;
    assign signal_select_273 = fraction_sum[16:16];
    assign signal_const_125 = 23'b00000000000000000000000;
    assign signal_cat_66 = { signal_const_125,
                             signal_select_273 };
    assign signal_cat_67 = { signal_const_34,
                             p_0 };
    assign signal_add_5 = t_0 + signal_cat_67;
    assign t_advanced = signal_add_5 + signal_cat_66;
    assign signal_eq_45 = d$wait_source$binary_variant == signal_const_8;
    assign signal_and_64 = is_opcode$1 & signal_eq_45;
    assign releases_deadline = signal_and_64 & wait_ready;
    assign advances_deadline = releases_deadline & d$wait_polarity;
    assign signal_mux_107 = advances_deadline ? t_advanced : t_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            t_next <= t_0;
        1:
            t_next <= signal_mux_107;
        2:
            t_next <= t_0;
        3:
            t_next <= signal_mux_102;
        4:
            t_next <= signal_mux_101;
        5:
            t_next <= t_0;
        6:
            t_next <= signal_mux_100;
        default:
            t_next <= t_0;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_14 <= signal_const_20;
        else
            if (go)
                signal_reg_14 <= t_next;
    end
    assign t_0 = signal_reg_14;
    assign signal_sub_4 = now_0 - t_0;
    assign signal_select_274 = signal_sub_4[23:23];
    assign deadline_ready = ~ signal_select_274;
    assign signal_eq_46 = wait_pin_cur == d$wait_polarity;
    assign signal_and_65 = pins_sampled & wait_select_0;
    assign signal_eq_47 = signal_and_65 == signal_const_29;
    assign wait_pin_prev = ~ signal_eq_47;
    assign signal_eq_48 = wait_pin_cur == wait_pin_prev;
    assign signal_not_34 = ~ signal_eq_48;
    assign signal_and_66 = signal_not_34 & signal_eq_46;
    assign d$wait_polarity = word[7:7];
    assign signal_const_130 = 28'b0000000000000000000000000001;
    assign signal_and_67 = signal_not_35 & signal_and_83;
    assign signal_and_68 = signal_not_35 & signal_and_85;
    assign signal_and_69 = signal_not_35 & signal_and_87;
    assign signal_and_70 = signal_not_35 & signal_and_89;
    assign signal_and_71 = signal_not_35 & signal_and_91;
    assign signal_and_72 = signal_not_35 & signal_and_93;
    assign signal_and_73 = signal_not_35 & signal_and_95;
    assign signal_and_74 = signal_not_35 & signal_and_97;
    assign signal_and_75 = signal_not_35 & signal_and_100;
    assign signal_and_76 = signal_not_35 & signal_and_103;
    assign signal_and_77 = signal_not_35 & signal_and_106;
    assign signal_and_78 = signal_not_35 & signal_and_109;
    assign signal_and_79 = signal_not_35 & signal_and_113;
    assign signal_and_80 = signal_not_35 & signal_and_117;
    assign signal_and_81 = signal_not_35 & signal_and_121;
    assign signal_not_35 = ~ signal_select_280;
    assign signal_and_82 = signal_not_35 & signal_and_125;
    assign signal_and_83 = signal_not_36 & signal_and_99;
    assign signal_and_84 = signal_select_280 & signal_and_83;
    assign signal_and_85 = signal_not_36 & signal_and_102;
    assign signal_and_86 = signal_select_280 & signal_and_85;
    assign signal_and_87 = signal_not_36 & signal_and_105;
    assign signal_and_88 = signal_select_280 & signal_and_87;
    assign signal_and_89 = signal_not_36 & signal_and_108;
    assign signal_and_90 = signal_select_280 & signal_and_89;
    assign signal_and_91 = signal_not_36 & signal_and_112;
    assign signal_and_92 = signal_select_280 & signal_and_91;
    assign signal_and_93 = signal_not_36 & signal_and_116;
    assign signal_and_94 = signal_select_280 & signal_and_93;
    assign signal_and_95 = signal_not_36 & signal_and_120;
    assign signal_and_96 = signal_select_280 & signal_and_95;
    assign signal_not_36 = ~ signal_select_278;
    assign signal_and_97 = signal_not_36 & signal_and_124;
    assign signal_and_98 = signal_select_280 & signal_and_97;
    assign signal_and_99 = signal_not_37 & signal_and_111;
    assign signal_and_100 = signal_select_278 & signal_and_99;
    assign signal_and_101 = signal_select_280 & signal_and_100;
    assign signal_and_102 = signal_not_37 & signal_and_115;
    assign signal_and_103 = signal_select_278 & signal_and_102;
    assign signal_and_104 = signal_select_280 & signal_and_103;
    assign signal_and_105 = signal_not_37 & signal_and_119;
    assign signal_and_106 = signal_select_278 & signal_and_105;
    assign signal_and_107 = signal_select_280 & signal_and_106;
    assign signal_not_37 = ~ signal_select_277;
    assign signal_and_108 = signal_not_37 & signal_and_123;
    assign signal_and_109 = signal_select_278 & signal_and_108;
    assign signal_and_110 = signal_select_280 & signal_and_109;
    assign signal_and_111 = signal_not_38 & signal_not_39;
    assign signal_and_112 = signal_select_277 & signal_and_111;
    assign signal_and_113 = signal_select_278 & signal_and_112;
    assign signal_and_114 = signal_select_280 & signal_and_113;
    assign signal_not_38 = ~ signal_select_276;
    assign signal_and_115 = signal_not_38 & signal_select_275;
    assign signal_and_116 = signal_select_277 & signal_and_115;
    assign signal_and_117 = signal_select_278 & signal_and_116;
    assign signal_and_118 = signal_select_280 & signal_and_117;
    assign signal_not_39 = ~ signal_select_275;
    assign signal_and_119 = signal_select_276 & signal_not_39;
    assign signal_and_120 = signal_select_277 & signal_and_119;
    assign signal_and_121 = signal_select_278 & signal_and_120;
    assign signal_and_122 = signal_select_280 & signal_and_121;
    assign signal_select_275 = signal_select_279[0:0];
    assign signal_select_276 = signal_select_279[1:1];
    assign signal_and_123 = signal_select_276 & signal_select_275;
    assign signal_select_277 = signal_select_279[2:2];
    assign signal_and_124 = signal_select_277 & signal_and_123;
    assign signal_select_278 = signal_select_279[3:3];
    assign signal_and_125 = signal_select_278 & signal_and_124;
    assign signal_select_279 = signal_wire_54[4:0];
    assign signal_select_280 = signal_select_279[4:4];
    assign signal_and_126 = signal_select_280 & signal_and_125;
    assign signal_cat_68 = { signal_and_126,
                             signal_and_122,
                             signal_and_118,
                             signal_and_114,
                             signal_and_110,
                             signal_and_107,
                             signal_and_104,
                             signal_and_101,
                             signal_and_98,
                             signal_and_96,
                             signal_and_94,
                             signal_and_92,
                             signal_and_90,
                             signal_and_88,
                             signal_and_86,
                             signal_and_84,
                             signal_and_82,
                             signal_and_81,
                             signal_and_80,
                             signal_and_79,
                             signal_and_78,
                             signal_and_77,
                             signal_and_76,
                             signal_and_75,
                             signal_and_74,
                             signal_and_73,
                             signal_and_72,
                             signal_and_71,
                             signal_and_70,
                             signal_and_69,
                             signal_and_68,
                             signal_and_67 };
    assign signal_select_281 = signal_cat_68[27:0];
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            wait_select_0 <= signal_const_130;
        else
            if (ir_load)
                wait_select_0 <= signal_select_281;
    end
    assign signal_select_282 = signal_wire_51[0:0];
    assign signal_select_283 = signal_wire_51[1:1];
    assign signal_select_284 = signal_wire_51[2:2];
    assign signal_select_285 = signal_wire_51[3:3];
    assign signal_select_286 = signal_wire_51[4:4];
    assign signal_select_287 = pin_out_0[5:5];
    assign signal_select_288 = pin_out_0[6:6];
    assign signal_select_289 = pin_out_0[7:7];
    assign signal_select_290 = pin_out_0[8:8];
    assign signal_select_291 = pin_out_0[9:9];
    assign signal_select_292 = pin_out_0[10:10];
    assign signal_select_293 = pin_out_0[11:11];
    assign signal_select_294 = pin_out_0[12:12];
    assign signal_select_295 = signal_wire_51[12:12];
    assign signal_select_296 = pin_dir_0[12:12];
    assign signal_mux_108 = signal_select_296 ? signal_select_294 : signal_select_295;
    assign signal_select_297 = pin_out_0[13:13];
    assign signal_select_298 = signal_wire_51[13:13];
    assign signal_select_299 = pin_dir_0[13:13];
    assign signal_mux_109 = signal_select_299 ? signal_select_297 : signal_select_298;
    assign signal_select_300 = pin_out_0[14:14];
    assign signal_select_301 = signal_wire_51[14:14];
    assign signal_select_302 = pin_dir_0[14:14];
    assign signal_mux_110 = signal_select_302 ? signal_select_300 : signal_select_301;
    assign signal_select_303 = pin_out_0[15:15];
    assign signal_select_304 = signal_wire_51[15:15];
    assign signal_select_305 = pin_dir_0[15:15];
    assign signal_mux_111 = signal_select_305 ? signal_select_303 : signal_select_304;
    assign signal_select_306 = pin_out_0[16:16];
    assign signal_select_307 = signal_wire_51[16:16];
    assign signal_select_308 = pin_dir_0[16:16];
    assign signal_mux_112 = signal_select_308 ? signal_select_306 : signal_select_307;
    assign signal_select_309 = pin_out_0[17:17];
    assign signal_select_310 = signal_wire_51[17:17];
    assign signal_select_311 = pin_dir_0[17:17];
    assign signal_mux_113 = signal_select_311 ? signal_select_309 : signal_select_310;
    assign signal_select_312 = pin_out_0[18:18];
    assign signal_select_313 = signal_wire_51[18:18];
    assign signal_select_314 = pin_dir_0[18:18];
    assign signal_mux_114 = signal_select_314 ? signal_select_312 : signal_select_313;
    assign signal_select_315 = pin_out_0[19:19];
    assign signal_select_316 = signal_wire_51[19:19];
    assign signal_select_317 = signal_mux_118[27:12];
    assign signal_select_318 = signal_mux_118[11:0];
    assign signal_cat_69 = { signal_select_318,
                             signal_select_317 };
    assign signal_select_319 = signal_mux_117[27:20];
    assign signal_select_320 = signal_mux_117[19:0];
    assign signal_cat_70 = { signal_select_320,
                             signal_select_319 };
    assign signal_select_321 = signal_mux_116[27:24];
    assign signal_select_322 = signal_mux_116[23:0];
    assign signal_cat_71 = { signal_select_322,
                             signal_select_321 };
    assign signal_select_323 = signal_mux_115[27:26];
    assign signal_select_324 = signal_mux_115[25:0];
    assign signal_cat_72 = { signal_select_324,
                             signal_select_323 };
    assign signal_select_325 = signal_cat_75[27:27];
    assign signal_select_326 = signal_cat_75[26:0];
    assign signal_cat_73 = { signal_select_326,
                             signal_select_325 };
    assign signal_cat_74 = { signal_const_30,
                             d$set_value };
    assign signal_cat_75 = { signal_const_31,
                             signal_cat_74 };
    assign signal_select_327 = signal_wire_21[0:0];
    assign signal_mux_115 = signal_select_327 ? signal_cat_73 : signal_cat_75;
    assign signal_select_328 = signal_wire_21[1:1];
    assign signal_mux_116 = signal_select_328 ? signal_cat_72 : signal_mux_115;
    assign signal_select_329 = signal_wire_21[2:2];
    assign signal_mux_117 = signal_select_329 ? signal_cat_71 : signal_mux_116;
    assign signal_select_330 = signal_wire_21[3:3];
    assign signal_mux_118 = signal_select_330 ? signal_cat_70 : signal_mux_117;
    assign signal_select_331 = signal_wire_21[4:4];
    assign signal_mux_119 = signal_select_331 ? signal_cat_69 : signal_mux_118;
    assign signal_and_127 = signal_mux_119 & signal_and_128;
    assign signal_const_134 = 28'b0000000011111111000000000000;
    assign signal_select_332 = signal_mux_128[27:12];
    assign signal_select_333 = signal_mux_128[11:0];
    assign signal_cat_76 = { signal_select_333,
                             signal_select_332 };
    assign signal_select_334 = signal_mux_127[27:20];
    assign signal_select_335 = signal_mux_127[19:0];
    assign signal_cat_77 = { signal_select_335,
                             signal_select_334 };
    assign signal_select_336 = signal_mux_126[27:24];
    assign signal_select_337 = signal_mux_126[23:0];
    assign signal_cat_78 = { signal_select_337,
                             signal_select_336 };
    assign signal_select_338 = signal_mux_125[27:26];
    assign signal_select_339 = signal_mux_125[25:0];
    assign signal_cat_79 = { signal_select_339,
                             signal_select_338 };
    assign signal_select_340 = signal_cat_85[27:27];
    assign signal_select_341 = signal_cat_85[26:0];
    assign signal_cat_80 = { signal_select_341,
                             signal_select_340 };
    assign signal_select_342 = signal_mux_122[7:0];
    assign signal_cat_81 = { signal_select_342,
                             signal_const_34 };
    assign signal_select_343 = signal_mux_121[11:0];
    assign signal_cat_82 = { signal_select_343,
                             signal_const_35 };
    assign signal_select_344 = signal_mux_120[13:0];
    assign signal_cat_83 = { signal_select_344,
                             signal_const_5 };
    assign signal_select_345 = signal_cat_84[0:0];
    assign signal_mux_120 = signal_select_345 ? signal_const_37 : signal_const_38;
    assign signal_select_346 = signal_cat_84[1:1];
    assign signal_mux_121 = signal_select_346 ? signal_cat_83 : signal_mux_120;
    assign signal_select_347 = signal_cat_84[2:2];
    assign signal_mux_122 = signal_select_347 ? signal_cat_82 : signal_mux_121;
    assign signal_select_348 = signal_cat_84[3:3];
    assign signal_mux_123 = signal_select_348 ? signal_cat_81 : signal_mux_122;
    assign signal_wire_20 = config$set_count;
    assign signal_cat_84 = { signal_const_5,
                             signal_wire_20 };
    assign signal_select_349 = signal_cat_84[4:4];
    assign signal_mux_124 = signal_select_349 ? signal_const : signal_mux_123;
    assign signal_not_40 = ~ signal_mux_124;
    assign signal_cat_85 = { signal_const_31,
                             signal_not_40 };
    assign signal_select_350 = signal_wire_21[0:0];
    assign signal_mux_125 = signal_select_350 ? signal_cat_80 : signal_cat_85;
    assign signal_select_351 = signal_wire_21[1:1];
    assign signal_mux_126 = signal_select_351 ? signal_cat_79 : signal_mux_125;
    assign signal_select_352 = signal_wire_21[2:2];
    assign signal_mux_127 = signal_select_352 ? signal_cat_78 : signal_mux_126;
    assign signal_select_353 = signal_wire_21[3:3];
    assign signal_mux_128 = signal_select_353 ? signal_cat_77 : signal_mux_127;
    assign signal_wire_21 = config$set_base;
    assign signal_select_354 = signal_wire_21[4:4];
    assign signal_mux_129 = signal_select_354 ? signal_cat_76 : signal_mux_128;
    assign signal_and_128 = signal_mux_129 & signal_const_134;
    assign signal_not_41 = ~ signal_and_128;
    assign signal_and_129 = pin_dir_base & signal_not_41;
    assign signal_or_16 = signal_and_129 | signal_and_127;
    assign signal_const_143 = 3'b011;
    assign signal_eq_49 = d$set_dest$binary_variant == signal_const_143;
    assign signal_mux_130 = signal_eq_49 ? signal_or_16 : pin_dir_base;
    assign signal_select_355 = signal_mux_134[27:12];
    assign signal_select_356 = signal_mux_134[11:0];
    assign signal_cat_86 = { signal_select_356,
                             signal_select_355 };
    assign signal_select_357 = signal_mux_133[27:20];
    assign signal_select_358 = signal_mux_133[19:0];
    assign signal_cat_87 = { signal_select_358,
                             signal_select_357 };
    assign signal_select_359 = signal_mux_132[27:24];
    assign signal_select_360 = signal_mux_132[23:0];
    assign signal_cat_88 = { signal_select_360,
                             signal_select_359 };
    assign signal_select_361 = signal_mux_131[27:26];
    assign signal_select_362 = signal_mux_131[25:0];
    assign signal_cat_89 = { signal_select_362,
                             signal_select_361 };
    assign signal_select_363 = signal_cat_91[27:27];
    assign signal_select_364 = signal_cat_91[26:0];
    assign signal_cat_90 = { signal_select_364,
                             signal_select_363 };
    assign signal_cat_91 = { signal_const_31,
                             mov_value };
    assign signal_select_365 = signal_wire_47[0:0];
    assign signal_mux_131 = signal_select_365 ? signal_cat_90 : signal_cat_91;
    assign signal_select_366 = signal_wire_47[1:1];
    assign signal_mux_132 = signal_select_366 ? signal_cat_89 : signal_mux_131;
    assign signal_select_367 = signal_wire_47[2:2];
    assign signal_mux_133 = signal_select_367 ? signal_cat_88 : signal_mux_132;
    assign signal_select_368 = signal_wire_47[3:3];
    assign signal_mux_134 = signal_select_368 ? signal_cat_87 : signal_mux_133;
    assign signal_select_369 = signal_wire_47[4:4];
    assign signal_mux_135 = signal_select_369 ? signal_cat_86 : signal_mux_134;
    assign signal_and_130 = signal_mux_135 & signal_and_131;
    assign signal_select_370 = signal_mux_144[27:12];
    assign signal_select_371 = signal_mux_144[11:0];
    assign signal_cat_92 = { signal_select_371,
                             signal_select_370 };
    assign signal_select_372 = signal_mux_143[27:20];
    assign signal_select_373 = signal_mux_143[19:0];
    assign signal_cat_93 = { signal_select_373,
                             signal_select_372 };
    assign signal_select_374 = signal_mux_142[27:24];
    assign signal_select_375 = signal_mux_142[23:0];
    assign signal_cat_94 = { signal_select_375,
                             signal_select_374 };
    assign signal_select_376 = signal_mux_141[27:26];
    assign signal_select_377 = signal_mux_141[25:0];
    assign signal_cat_95 = { signal_select_377,
                             signal_select_376 };
    assign signal_select_378 = signal_cat_100[27:27];
    assign signal_select_379 = signal_cat_100[26:0];
    assign signal_cat_96 = { signal_select_379,
                             signal_select_378 };
    assign signal_select_380 = signal_mux_138[7:0];
    assign signal_cat_97 = { signal_select_380,
                             signal_const_34 };
    assign signal_select_381 = signal_mux_137[11:0];
    assign signal_cat_98 = { signal_select_381,
                             signal_const_35 };
    assign signal_select_382 = signal_mux_136[13:0];
    assign signal_cat_99 = { signal_select_382,
                             signal_const_5 };
    assign signal_select_383 = signal_wire_22[0:0];
    assign signal_mux_136 = signal_select_383 ? signal_const_37 : signal_const_38;
    assign signal_select_384 = signal_wire_22[1:1];
    assign signal_mux_137 = signal_select_384 ? signal_cat_99 : signal_mux_136;
    assign signal_select_385 = signal_wire_22[2:2];
    assign signal_mux_138 = signal_select_385 ? signal_cat_98 : signal_mux_137;
    assign signal_select_386 = signal_wire_22[3:3];
    assign signal_mux_139 = signal_select_386 ? signal_cat_97 : signal_mux_138;
    assign signal_wire_22 = config$out_count;
    assign signal_select_387 = signal_wire_22[4:4];
    assign signal_mux_140 = signal_select_387 ? signal_const : signal_mux_139;
    assign signal_not_42 = ~ signal_mux_140;
    assign signal_cat_100 = { signal_const_31,
                              signal_not_42 };
    assign signal_select_388 = signal_wire_47[0:0];
    assign signal_mux_141 = signal_select_388 ? signal_cat_96 : signal_cat_100;
    assign signal_select_389 = signal_wire_47[1:1];
    assign signal_mux_142 = signal_select_389 ? signal_cat_95 : signal_mux_141;
    assign signal_select_390 = signal_wire_47[2:2];
    assign signal_mux_143 = signal_select_390 ? signal_cat_94 : signal_mux_142;
    assign signal_select_391 = signal_wire_47[3:3];
    assign signal_mux_144 = signal_select_391 ? signal_cat_93 : signal_mux_143;
    assign signal_select_392 = signal_wire_47[4:4];
    assign signal_mux_145 = signal_select_392 ? signal_cat_92 : signal_mux_144;
    assign signal_and_131 = signal_mux_145 & signal_const_134;
    assign signal_not_43 = ~ signal_and_131;
    assign signal_and_132 = pin_dir_base & signal_not_43;
    assign signal_or_17 = signal_and_132 | signal_and_130;
    assign signal_eq_50 = d$mov_dest$binary_variant == signal_const_143;
    assign signal_mux_146 = signal_eq_50 ? signal_or_17 : pin_dir_base;
    assign signal_select_393 = signal_mux_293[27:12];
    assign signal_select_394 = signal_mux_293[11:0];
    assign signal_cat_101 = { signal_select_394,
                              signal_select_393 };
    assign signal_select_395 = signal_mux_292[27:20];
    assign signal_select_396 = signal_mux_292[19:0];
    assign signal_cat_102 = { signal_select_396,
                              signal_select_395 };
    assign signal_select_397 = signal_mux_291[27:24];
    assign signal_select_398 = signal_mux_291[23:0];
    assign signal_cat_103 = { signal_select_398,
                              signal_select_397 };
    assign signal_select_399 = signal_mux_290[27:26];
    assign signal_select_400 = signal_mux_290[25:0];
    assign signal_cat_104 = { signal_select_400,
                              signal_select_399 };
    assign signal_select_401 = signal_cat_213[27:27];
    assign signal_select_402 = signal_cat_213[26:0];
    assign signal_cat_105 = { signal_select_402,
                              signal_select_401 };
    assign signal_and_133 = osr_before & mask;
    assign signal_select_403 = signal_mux_287[15:8];
    assign signal_cat_106 = { signal_const_34,
                              signal_select_403 };
    assign signal_select_404 = signal_mux_286[15:4];
    assign signal_cat_107 = { signal_const_35,
                              signal_select_404 };
    assign signal_select_405 = signal_mux_285[15:2];
    assign signal_cat_108 = { signal_const_5,
                              signal_select_405 };
    assign signal_select_406 = osr_before[15:1];
    assign signal_cat_109 = { signal_const_1,
                              signal_select_406 };
    assign signal_wire_23 = data_word;
    assign signal_select_407 = signal_inst_1[15:0];
    assign signal_not_44 = ~ signal_select_809;
    assign signal_and_134 = pulls & signal_not_44;
    assign signal_mux_147 = signal_and_134 ? signal_select_407 : osr_0;
    assign signal_select_408 = signal_select_790[15:15];
    assign signal_select_409 = signal_select_790[14:14];
    assign signal_select_410 = signal_select_790[13:13];
    assign signal_select_411 = signal_select_790[12:12];
    assign signal_select_412 = signal_select_790[11:11];
    assign signal_select_413 = signal_select_790[10:10];
    assign signal_select_414 = signal_select_790[9:9];
    assign signal_select_415 = signal_select_790[8:8];
    assign signal_select_416 = signal_select_790[7:7];
    assign signal_select_417 = signal_select_790[6:6];
    assign signal_select_418 = signal_select_790[5:5];
    assign signal_select_419 = signal_select_790[4:4];
    assign signal_select_420 = signal_select_790[3:3];
    assign signal_select_421 = signal_select_790[2:2];
    assign signal_select_422 = signal_select_790[1:1];
    assign signal_select_423 = signal_select_790[0:0];
    assign signal_cat_110 = { signal_select_423,
                              signal_select_422,
                              signal_select_421,
                              signal_select_420,
                              signal_select_419,
                              signal_select_418,
                              signal_select_417,
                              signal_select_416,
                              signal_select_415,
                              signal_select_414,
                              signal_select_413,
                              signal_select_412,
                              signal_select_411,
                              signal_select_410,
                              signal_select_409,
                              signal_select_408 };
    assign signal_not_45 = ~ signal_select_790;
    assign signal_cat_111 = { signal_const_34,
                              osr_0 };
    assign signal_cat_112 = { signal_const_34,
                              isr_0 };
    assign signal_cat_113 = { signal_const_34,
                              y_0 };
    assign signal_xor_1 = x_0 ^ alu_operand;
    assign signal_sub_5 = x_0 - alu_operand;
    assign signal_eq_51 = d$sys_op$binary_variant == signal_const_111;
    assign signal_and_135 = is_opcode$7 & signal_eq_51;
    assign signal_mux_148 = signal_and_135 ? signal_const : isr_0;
    assign signal_eq_52 = d$mov_dest$binary_variant == signal_const_11;
    assign signal_mux_149 = signal_eq_52 ? mov_value : isr_0;
    assign signal_eq_53 = d$out_dest$binary_variant == signal_const_13;
    assign signal_mux_150 = signal_eq_53 ? out_value : isr_0;
    assign signal_select_424 = signal_mux_153[7:0];
    assign signal_cat_114 = { signal_select_424,
                              signal_const_34 };
    assign signal_select_425 = signal_mux_152[11:0];
    assign signal_cat_115 = { signal_select_425,
                              signal_const_35 };
    assign signal_select_426 = signal_mux_151[13:0];
    assign signal_cat_116 = { signal_select_426,
                              signal_const_5 };
    assign signal_select_427 = in_value[14:0];
    assign signal_cat_117 = { signal_select_427,
                              signal_const_1 };
    assign signal_select_428 = shift_back[0:0];
    assign signal_mux_151 = signal_select_428 ? signal_cat_117 : in_value;
    assign signal_select_429 = shift_back[1:1];
    assign signal_mux_152 = signal_select_429 ? signal_cat_116 : signal_mux_151;
    assign signal_select_430 = shift_back[2:2];
    assign signal_mux_153 = signal_select_430 ? signal_cat_115 : signal_mux_152;
    assign signal_select_431 = shift_back[3:3];
    assign signal_mux_154 = signal_select_431 ? signal_cat_114 : signal_mux_153;
    assign signal_select_432 = shift_back[4:4];
    assign signal_mux_155 = signal_select_432 ? signal_const : signal_mux_154;
    assign signal_select_433 = signal_mux_158[15:8];
    assign signal_cat_118 = { signal_const_34,
                              signal_select_433 };
    assign signal_select_434 = signal_mux_157[15:4];
    assign signal_cat_119 = { signal_const_35,
                              signal_select_434 };
    assign signal_select_435 = signal_mux_156[15:2];
    assign signal_cat_120 = { signal_const_5,
                              signal_select_435 };
    assign signal_select_436 = isr_0[15:1];
    assign signal_cat_121 = { signal_const_1,
                              signal_select_436 };
    assign signal_select_437 = d$shift_count[0:0];
    assign signal_mux_156 = signal_select_437 ? signal_cat_121 : isr_0;
    assign signal_select_438 = d$shift_count[1:1];
    assign signal_mux_157 = signal_select_438 ? signal_cat_120 : signal_mux_156;
    assign signal_select_439 = d$shift_count[2:2];
    assign signal_mux_158 = signal_select_439 ? signal_cat_119 : signal_mux_157;
    assign signal_select_440 = d$shift_count[3:3];
    assign signal_mux_159 = signal_select_440 ? signal_cat_118 : signal_mux_158;
    assign signal_select_441 = d$shift_count[4:4];
    assign signal_mux_160 = signal_select_441 ? signal_const : signal_mux_159;
    assign signal_or_18 = signal_mux_160 | signal_mux_155;
    assign signal_select_442 = signal_mux_163[7:0];
    assign signal_cat_122 = { signal_select_442,
                              signal_const_34 };
    assign signal_select_443 = signal_mux_162[11:0];
    assign signal_cat_123 = { signal_select_443,
                              signal_const_35 };
    assign signal_select_444 = signal_mux_161[13:0];
    assign signal_cat_124 = { signal_select_444,
                              signal_const_5 };
    assign signal_select_445 = d$shift_count[0:0];
    assign signal_mux_161 = signal_select_445 ? signal_const_37 : signal_const_38;
    assign signal_select_446 = d$shift_count[1:1];
    assign signal_mux_162 = signal_select_446 ? signal_cat_124 : signal_mux_161;
    assign signal_select_447 = d$shift_count[2:2];
    assign signal_mux_163 = signal_select_447 ? signal_cat_123 : signal_mux_162;
    assign signal_select_448 = d$shift_count[3:3];
    assign signal_mux_164 = signal_select_448 ? signal_cat_122 : signal_mux_163;
    assign signal_select_449 = d$shift_count[4:4];
    assign signal_mux_165 = signal_select_449 ? signal_const : signal_mux_164;
    assign mask = ~ signal_mux_165;
    assign signal_select_450 = line_modes[3:3];
    assign signal_and_136 = signal_select_450 & line_last_0;
    assign signal_select_451 = line_rx_entry[4:4];
    assign line_bit = signal_select_451 ^ signal_and_136;
    assign signal_const_187 = 15'b000000000000000;
    assign signal_cat_125 = { signal_const_187,
                              line_bit };
    assign signal_wire_24 = config$capture_rising;
    assign signal_select_452 = sample[27:27];
    assign signal_select_453 = sample[26:26];
    assign signal_select_454 = sample[25:25];
    assign signal_select_455 = sample[24:24];
    assign signal_select_456 = sample[23:23];
    assign signal_select_457 = sample[22:22];
    assign signal_select_458 = sample[21:21];
    assign signal_select_459 = sample[20:20];
    assign signal_select_460 = sample[19:19];
    assign signal_select_461 = sample[18:18];
    assign signal_select_462 = sample[17:17];
    assign signal_select_463 = sample[16:16];
    assign signal_select_464 = sample[15:15];
    assign signal_select_465 = sample[14:14];
    assign signal_select_466 = sample[13:13];
    assign signal_select_467 = sample[12:12];
    assign signal_select_468 = sample[11:11];
    assign signal_select_469 = sample[10:10];
    assign signal_select_470 = sample[9:9];
    assign signal_select_471 = sample[8:8];
    assign signal_select_472 = sample[7:7];
    assign signal_select_473 = sample[6:6];
    assign signal_select_474 = sample[5:5];
    assign signal_select_475 = sample[4:4];
    assign signal_select_476 = sample[3:3];
    assign signal_select_477 = sample[2:2];
    assign signal_select_478 = sample[1:1];
    assign signal_select_479 = sample[0:0];
    always @* begin
        case (signal_wire_25)
        0:
            signal_mux_166 <= signal_select_479;
        1:
            signal_mux_166 <= signal_select_478;
        2:
            signal_mux_166 <= signal_select_477;
        3:
            signal_mux_166 <= signal_select_476;
        4:
            signal_mux_166 <= signal_select_475;
        5:
            signal_mux_166 <= signal_select_474;
        6:
            signal_mux_166 <= signal_select_473;
        7:
            signal_mux_166 <= signal_select_472;
        8:
            signal_mux_166 <= signal_select_471;
        9:
            signal_mux_166 <= signal_select_470;
        10:
            signal_mux_166 <= signal_select_469;
        11:
            signal_mux_166 <= signal_select_468;
        12:
            signal_mux_166 <= signal_select_467;
        13:
            signal_mux_166 <= signal_select_466;
        14:
            signal_mux_166 <= signal_select_465;
        15:
            signal_mux_166 <= signal_select_464;
        16:
            signal_mux_166 <= signal_select_463;
        17:
            signal_mux_166 <= signal_select_462;
        18:
            signal_mux_166 <= signal_select_461;
        19:
            signal_mux_166 <= signal_select_460;
        20:
            signal_mux_166 <= signal_select_459;
        21:
            signal_mux_166 <= signal_select_458;
        22:
            signal_mux_166 <= signal_select_457;
        23:
            signal_mux_166 <= signal_select_456;
        24:
            signal_mux_166 <= signal_select_455;
        25:
            signal_mux_166 <= signal_select_454;
        26:
            signal_mux_166 <= signal_select_453;
        default:
            signal_mux_166 <= signal_select_452;
        endcase
    end
    assign signal_eq_54 = signal_mux_166 == signal_wire_24;
    assign signal_select_480 = pins_sampled[27:27];
    assign signal_select_481 = pins_sampled[26:26];
    assign signal_select_482 = pins_sampled[25:25];
    assign signal_select_483 = pins_sampled[24:24];
    assign signal_select_484 = pins_sampled[23:23];
    assign signal_select_485 = pins_sampled[22:22];
    assign signal_select_486 = pins_sampled[21:21];
    assign signal_select_487 = pins_sampled[20:20];
    assign signal_select_488 = pins_sampled[19:19];
    assign signal_select_489 = pins_sampled[18:18];
    assign signal_select_490 = pins_sampled[17:17];
    assign signal_select_491 = pins_sampled[16:16];
    assign signal_select_492 = pins_sampled[15:15];
    assign signal_select_493 = pins_sampled[14:14];
    assign signal_select_494 = pins_sampled[13:13];
    assign signal_select_495 = pins_sampled[12:12];
    assign signal_select_496 = pins_sampled[11:11];
    assign signal_select_497 = pins_sampled[10:10];
    assign signal_select_498 = pins_sampled[9:9];
    assign signal_select_499 = pins_sampled[8:8];
    assign signal_select_500 = pins_sampled[7:7];
    assign signal_select_501 = pins_sampled[6:6];
    assign signal_select_502 = pins_sampled[5:5];
    assign signal_select_503 = pins_sampled[4:4];
    assign signal_select_504 = pins_sampled[3:3];
    assign signal_select_505 = pins_sampled[2:2];
    assign signal_select_506 = pins_sampled[1:1];
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_15 <= signal_const_29;
        else
            signal_reg_15 <= sample;
    end
    assign pins_sampled = signal_reg_15;
    assign signal_select_507 = pins_sampled[0:0];
    always @* begin
        case (signal_wire_25)
        0:
            signal_mux_167 <= signal_select_507;
        1:
            signal_mux_167 <= signal_select_506;
        2:
            signal_mux_167 <= signal_select_505;
        3:
            signal_mux_167 <= signal_select_504;
        4:
            signal_mux_167 <= signal_select_503;
        5:
            signal_mux_167 <= signal_select_502;
        6:
            signal_mux_167 <= signal_select_501;
        7:
            signal_mux_167 <= signal_select_500;
        8:
            signal_mux_167 <= signal_select_499;
        9:
            signal_mux_167 <= signal_select_498;
        10:
            signal_mux_167 <= signal_select_497;
        11:
            signal_mux_167 <= signal_select_496;
        12:
            signal_mux_167 <= signal_select_495;
        13:
            signal_mux_167 <= signal_select_494;
        14:
            signal_mux_167 <= signal_select_493;
        15:
            signal_mux_167 <= signal_select_492;
        16:
            signal_mux_167 <= signal_select_491;
        17:
            signal_mux_167 <= signal_select_490;
        18:
            signal_mux_167 <= signal_select_489;
        19:
            signal_mux_167 <= signal_select_488;
        20:
            signal_mux_167 <= signal_select_487;
        21:
            signal_mux_167 <= signal_select_486;
        22:
            signal_mux_167 <= signal_select_485;
        23:
            signal_mux_167 <= signal_select_484;
        24:
            signal_mux_167 <= signal_select_483;
        25:
            signal_mux_167 <= signal_select_482;
        26:
            signal_mux_167 <= signal_select_481;
        default:
            signal_mux_167 <= signal_select_480;
        endcase
    end
    assign signal_select_508 = sample[27:27];
    assign signal_select_509 = sample[26:26];
    assign signal_select_510 = sample[25:25];
    assign signal_select_511 = sample[24:24];
    assign signal_select_512 = sample[23:23];
    assign signal_select_513 = sample[22:22];
    assign signal_select_514 = sample[21:21];
    assign signal_select_515 = sample[20:20];
    assign signal_select_516 = sample[19:19];
    assign signal_select_517 = sample[18:18];
    assign signal_select_518 = sample[17:17];
    assign signal_select_519 = sample[16:16];
    assign signal_select_520 = sample[15:15];
    assign signal_select_521 = sample[14:14];
    assign signal_select_522 = sample[13:13];
    assign signal_select_523 = sample[12:12];
    assign signal_select_524 = sample[11:11];
    assign signal_select_525 = sample[10:10];
    assign signal_select_526 = sample[9:9];
    assign signal_select_527 = sample[8:8];
    assign signal_select_528 = sample[7:7];
    assign signal_select_529 = sample[6:6];
    assign signal_select_530 = sample[5:5];
    assign signal_select_531 = sample[4:4];
    assign signal_select_532 = sample[3:3];
    assign signal_select_533 = sample[2:2];
    assign signal_select_534 = sample[1:1];
    assign signal_select_535 = sample[0:0];
    assign signal_wire_25 = config$capture_pin;
    always @* begin
        case (signal_wire_25)
        0:
            signal_mux_168 <= signal_select_535;
        1:
            signal_mux_168 <= signal_select_534;
        2:
            signal_mux_168 <= signal_select_533;
        3:
            signal_mux_168 <= signal_select_532;
        4:
            signal_mux_168 <= signal_select_531;
        5:
            signal_mux_168 <= signal_select_530;
        6:
            signal_mux_168 <= signal_select_529;
        7:
            signal_mux_168 <= signal_select_528;
        8:
            signal_mux_168 <= signal_select_527;
        9:
            signal_mux_168 <= signal_select_526;
        10:
            signal_mux_168 <= signal_select_525;
        11:
            signal_mux_168 <= signal_select_524;
        12:
            signal_mux_168 <= signal_select_523;
        13:
            signal_mux_168 <= signal_select_522;
        14:
            signal_mux_168 <= signal_select_521;
        15:
            signal_mux_168 <= signal_select_520;
        16:
            signal_mux_168 <= signal_select_519;
        17:
            signal_mux_168 <= signal_select_518;
        18:
            signal_mux_168 <= signal_select_517;
        19:
            signal_mux_168 <= signal_select_516;
        20:
            signal_mux_168 <= signal_select_515;
        21:
            signal_mux_168 <= signal_select_514;
        22:
            signal_mux_168 <= signal_select_513;
        23:
            signal_mux_168 <= signal_select_512;
        24:
            signal_mux_168 <= signal_select_511;
        25:
            signal_mux_168 <= signal_select_510;
        26:
            signal_mux_168 <= signal_select_509;
        default:
            signal_mux_168 <= signal_select_508;
        endcase
    end
    assign signal_eq_55 = signal_mux_168 == signal_mux_167;
    assign signal_not_46 = ~ signal_eq_55;
    assign signal_eq_56 = d$sys_op$binary_variant == signal_const_6;
    assign signal_and_137 = is_opcode$7 & signal_eq_56;
    assign signal_and_138 = op_go & signal_and_137;
    assign signal_mux_169 = signal_and_138 ? vdd : capture_armed_0;
    assign signal_mux_170 = captured ? gnd : signal_mux_169;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_16 <= signal_const_1;
        else
            signal_reg_16 <= signal_mux_170;
    end
    assign capture_armed_0 = signal_reg_16;
    assign signal_and_139 = capture_armed_0 & signal_not_46;
    assign captured = signal_and_139 & signal_eq_54;
    assign signal_const_194 = 24'b000000000000000000000001;
    assign signal_add_6 = now_0 + signal_const_194;
    assign signal_mux_171 = start_0 ? signal_const_20 : signal_add_6;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_17 <= signal_const_20;
        else
            signal_reg_17 <= signal_mux_171;
    end
    assign now_0 = signal_reg_17;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_18 <= signal_const_20;
        else
            if (captured)
                signal_reg_18 <= now_0;
    end
    assign capture_0 = signal_reg_18;
    assign signal_select_536 = capture_0[15:0];
    assign signal_wire_26 = config$crc_init;
    assign signal_select_537 = signal_mux_174[7:0];
    assign signal_cat_126 = { signal_select_537,
                              signal_const_34 };
    assign signal_select_538 = signal_mux_173[11:0];
    assign signal_cat_127 = { signal_select_538,
                              signal_const_35 };
    assign signal_select_539 = signal_mux_172[13:0];
    assign signal_cat_128 = { signal_select_539,
                              signal_const_5 };
    assign signal_select_540 = signal_wire_28[0:0];
    assign signal_mux_172 = signal_select_540 ? signal_const_37 : signal_const_38;
    assign signal_select_541 = signal_wire_28[1:1];
    assign signal_mux_173 = signal_select_541 ? signal_cat_128 : signal_mux_172;
    assign signal_select_542 = signal_wire_28[2:2];
    assign signal_mux_174 = signal_select_542 ? signal_cat_127 : signal_mux_173;
    assign signal_select_543 = signal_wire_28[3:3];
    assign signal_mux_175 = signal_select_543 ? signal_cat_126 : signal_mux_174;
    assign signal_select_544 = signal_wire_28[4:4];
    assign signal_mux_176 = signal_select_544 ? signal_const : signal_mux_175;
    assign signal_not_47 = ~ signal_mux_176;
    assign signal_xor_2 = signal_cat_129 ^ signal_wire_27;
    assign signal_select_545 = crc_0[15:1];
    assign signal_cat_129 = { signal_const_1,
                              signal_select_545 };
    assign signal_select_546 = crc_0[0:0];
    assign signal_xor_3 = signal_select_546 ^ crossing_bit;
    assign signal_mux_177 = signal_xor_3 ? signal_xor_2 : signal_cat_129;
    assign signal_wire_27 = config$crc_poly;
    assign signal_xor_4 = signal_cat_130 ^ signal_wire_27;
    assign signal_select_547 = crc_0[14:0];
    assign signal_cat_130 = { signal_select_547,
                              signal_const_1 };
    assign signal_select_548 = in_value[0:0];
    assign signal_select_549 = out_value[0:0];
    assign crossing_bit = is_opcode$2 ? signal_select_548 : signal_select_549;
    assign signal_select_550 = crc_0[15:15];
    assign signal_select_551 = crc_0[14:14];
    assign signal_select_552 = crc_0[13:13];
    assign signal_select_553 = crc_0[12:12];
    assign signal_select_554 = crc_0[11:11];
    assign signal_select_555 = crc_0[10:10];
    assign signal_select_556 = crc_0[9:9];
    assign signal_select_557 = crc_0[8:8];
    assign signal_select_558 = crc_0[7:7];
    assign signal_select_559 = crc_0[6:6];
    assign signal_select_560 = crc_0[5:5];
    assign signal_select_561 = crc_0[4:4];
    assign signal_select_562 = crc_0[3:3];
    assign signal_select_563 = crc_0[2:2];
    assign signal_select_564 = crc_0[1:1];
    assign signal_select_565 = crc_0[0:0];
    assign signal_wire_28 = config$crc_width;
    assign signal_sub_6 = signal_wire_28 - signal_const_71;
    always @* begin
        case (signal_sub_6)
        0:
            signal_mux_178 <= signal_select_565;
        1:
            signal_mux_178 <= signal_select_564;
        2:
            signal_mux_178 <= signal_select_563;
        3:
            signal_mux_178 <= signal_select_562;
        4:
            signal_mux_178 <= signal_select_561;
        5:
            signal_mux_178 <= signal_select_560;
        6:
            signal_mux_178 <= signal_select_559;
        7:
            signal_mux_178 <= signal_select_558;
        8:
            signal_mux_178 <= signal_select_557;
        9:
            signal_mux_178 <= signal_select_556;
        10:
            signal_mux_178 <= signal_select_555;
        11:
            signal_mux_178 <= signal_select_554;
        12:
            signal_mux_178 <= signal_select_553;
        13:
            signal_mux_178 <= signal_select_552;
        14:
            signal_mux_178 <= signal_select_551;
        default:
            signal_mux_178 <= signal_select_550;
        endcase
    end
    assign signal_xor_5 = signal_mux_178 ^ crossing_bit;
    assign signal_mux_179 = signal_xor_5 ? signal_xor_4 : signal_cat_130;
    assign signal_wire_29 = config$crc_reflect;
    assign signal_mux_180 = signal_wire_29 ? signal_mux_177 : signal_mux_179;
    assign crc_stepped = signal_mux_180 & signal_not_47;
    assign signal_not_48 = ~ line_drop;
    assign signal_or_19 = is_opcode$2 | is_opcode$3;
    assign signal_eq_57 = d$shift_count == signal_const_71;
    assign bit_crosses = signal_eq_57 & signal_or_19;
    assign bit_counts = bit_crosses & signal_not_48;
    assign signal_mux_181 = bit_counts ? crc_stepped : crc_0;
    assign signal_const_206 = 4'b0101;
    assign signal_eq_58 = d$sys_op$binary_variant == signal_const_206;
    assign signal_and_140 = is_opcode$7 & signal_eq_58;
    assign crc_next = signal_and_140 ? signal_wire_26 : signal_mux_181;
    assign signal_mux_182 = go ? crc_next : crc_0;
    assign signal_mux_183 = start_0 ? signal_wire_26 : signal_mux_182;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_19 <= signal_const;
        else
            signal_reg_19 <= signal_mux_183;
    end
    assign crc_0 = signal_reg_19;
    assign signal_select_566 = signal_mux_186[7:0];
    assign signal_cat_131 = { signal_select_566,
                              signal_const_34 };
    assign signal_select_567 = signal_mux_185[11:0];
    assign signal_cat_132 = { signal_select_567,
                              signal_const_35 };
    assign signal_select_568 = signal_mux_184[13:0];
    assign signal_cat_133 = { signal_select_568,
                              signal_const_5 };
    assign signal_select_569 = d$shift_count[0:0];
    assign signal_mux_184 = signal_select_569 ? signal_const_37 : signal_const_38;
    assign signal_select_570 = d$shift_count[1:1];
    assign signal_mux_185 = signal_select_570 ? signal_cat_133 : signal_mux_184;
    assign signal_select_571 = d$shift_count[2:2];
    assign signal_mux_186 = signal_select_571 ? signal_cat_132 : signal_mux_185;
    assign signal_select_572 = d$shift_count[3:3];
    assign signal_mux_187 = signal_select_572 ? signal_cat_131 : signal_mux_186;
    assign signal_select_573 = d$shift_count[4:4];
    assign signal_mux_188 = signal_select_573 ? signal_const : signal_mux_187;
    assign signal_not_49 = ~ signal_mux_188;
    assign signal_select_574 = signal_mux_192[27:16];
    assign signal_select_575 = signal_mux_192[15:0];
    assign signal_cat_134 = { signal_select_575,
                              signal_select_574 };
    assign signal_select_576 = signal_mux_191[27:8];
    assign signal_select_577 = signal_mux_191[7:0];
    assign signal_cat_135 = { signal_select_577,
                              signal_select_576 };
    assign signal_select_578 = signal_mux_190[27:4];
    assign signal_select_579 = signal_mux_190[3:0];
    assign signal_cat_136 = { signal_select_579,
                              signal_select_578 };
    assign signal_select_580 = signal_mux_189[27:2];
    assign signal_select_581 = signal_mux_189[1:0];
    assign signal_cat_137 = { signal_select_581,
                              signal_select_580 };
    assign signal_select_582 = sample[27:1];
    assign signal_select_583 = sample[0:0];
    assign signal_cat_138 = { signal_select_583,
                              signal_select_582 };
    assign signal_select_584 = signal_wire_39[0:0];
    assign signal_mux_189 = signal_select_584 ? signal_cat_138 : sample;
    assign signal_select_585 = signal_wire_39[1:1];
    assign signal_mux_190 = signal_select_585 ? signal_cat_137 : signal_mux_189;
    assign signal_select_586 = signal_wire_39[2:2];
    assign signal_mux_191 = signal_select_586 ? signal_cat_136 : signal_mux_190;
    assign signal_select_587 = signal_wire_39[3:3];
    assign signal_mux_192 = signal_select_587 ? signal_cat_135 : signal_mux_191;
    assign signal_select_588 = signal_wire_39[4:4];
    assign signal_mux_193 = signal_select_588 ? signal_cat_134 : signal_mux_192;
    assign signal_select_589 = signal_mux_193[15:0];
    assign signal_and_141 = signal_select_589 & signal_not_49;
    always @* begin
        case (d$out_dest$binary_variant)
        0:
            in_source_value <= signal_and_141;
        1:
            in_source_value <= x_0;
        2:
            in_source_value <= y_0;
        3:
            in_source_value <= signal_const;
        4:
            in_source_value <= isr_0;
        5:
            in_source_value <= osr_0;
        6:
            in_source_value <= crc_0;
        default:
            in_source_value <= signal_select_536;
        endcase
    end
    assign signal_mux_194 = line_in ? signal_cat_125 : in_source_value;
    assign in_value = signal_mux_194 & mask;
    assign signal_select_590 = signal_mux_197[7:0];
    assign signal_cat_139 = { signal_select_590,
                              signal_const_34 };
    assign signal_select_591 = signal_mux_196[11:0];
    assign signal_cat_140 = { signal_select_591,
                              signal_const_35 };
    assign signal_select_592 = signal_mux_195[13:0];
    assign signal_cat_141 = { signal_select_592,
                              signal_const_5 };
    assign signal_select_593 = isr_0[14:0];
    assign signal_cat_142 = { signal_select_593,
                              signal_const_1 };
    assign signal_select_594 = d$shift_count[0:0];
    assign signal_mux_195 = signal_select_594 ? signal_cat_142 : isr_0;
    assign signal_select_595 = d$shift_count[1:1];
    assign signal_mux_196 = signal_select_595 ? signal_cat_141 : signal_mux_195;
    assign signal_select_596 = d$shift_count[2:2];
    assign signal_mux_197 = signal_select_596 ? signal_cat_140 : signal_mux_196;
    assign signal_select_597 = d$shift_count[3:3];
    assign signal_mux_198 = signal_select_597 ? signal_cat_139 : signal_mux_197;
    assign signal_select_598 = d$shift_count[4:4];
    assign signal_mux_199 = signal_select_598 ? signal_const : signal_mux_198;
    assign signal_or_20 = signal_mux_199 | in_value;
    assign signal_wire_30 = config$in_shift_right;
    assign isr_shifted = signal_wire_30 ? signal_or_18 : signal_or_20;
    assign signal_not_50 = ~ line_drop;
    assign signal_wire_31 = config$push_threshold;
    assign signal_select_599 = signal_add_7[4:0];
    assign signal_cat_143 = { gnd,
                              d$shift_count };
    assign signal_eq_59 = d$sys_op$binary_variant == signal_const_111;
    assign signal_and_142 = is_opcode$7 & signal_eq_59;
    assign signal_mux_200 = signal_and_142 ? osr_count_zero : isr_count_0;
    assign signal_eq_60 = d$mov_dest$binary_variant == signal_const_11;
    assign signal_mux_201 = signal_eq_60 ? osr_count_zero : isr_count_0;
    assign signal_eq_61 = d$out_dest$binary_variant == signal_const_13;
    assign signal_mux_202 = signal_eq_61 ? d$shift_count : isr_count_0;
    assign signal_mux_203 = autopush_now ? osr_count_zero : isr_count_next;
    assign signal_mux_204 = line_drop ? isr_count_0 : signal_mux_203;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_count_next_value <= isr_count_0;
        1:
            isr_count_next_value <= isr_count_0;
        2:
            isr_count_next_value <= signal_mux_204;
        3:
            isr_count_next_value <= signal_mux_202;
        4:
            isr_count_next_value <= signal_mux_201;
        5:
            isr_count_next_value <= isr_count_0;
        6:
            isr_count_next_value <= isr_count_0;
        default:
            isr_count_next_value <= signal_mux_200;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_20 <= signal_const_68;
        else
            if (go)
                signal_reg_20 <= isr_count_next_value;
    end
    assign isr_count_0 = signal_reg_20;
    assign signal_cat_144 = { gnd,
                              isr_count_0 };
    assign signal_add_7 = signal_cat_144 + signal_cat_143;
    assign signal_const_224 = 6'b010000;
    assign signal_lt_15 = signal_const_224 < signal_add_7;
    assign isr_count_next = signal_lt_15 ? signal_const_84 : signal_select_599;
    assign signal_lt_16 = isr_count_next < signal_wire_31;
    assign signal_not_51 = ~ signal_lt_16;
    assign signal_wire_32 = config$autopush;
    assign signal_and_143 = signal_wire_32 & signal_not_51;
    assign autopush_now = signal_and_143 & signal_not_50;
    assign signal_mux_205 = autopush_now ? signal_const : isr_shifted;
    assign signal_select_600 = line_pair[11:6];
    assign signal_eq_62 = signal_wire_34 == signal_const_74;
    assign signal_and_144 = line_write & signal_eq_62;
    assign signal_select_601 = signal_wire_36[5:0];
    assign signal_select_602 = signal_wire_36[13:8];
    assign signal_cat_145 = { signal_select_602,
                              signal_select_601 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$15 <= signal_const_31;
        else
            if (signal_and_144)
                line_table$15 <= signal_cat_145;
    end
    assign signal_const_227 = 5'b01110;
    assign signal_eq_63 = signal_wire_34 == signal_const_227;
    assign signal_and_145 = line_write & signal_eq_63;
    assign signal_select_603 = signal_wire_36[5:0];
    assign signal_select_604 = signal_wire_36[13:8];
    assign signal_cat_146 = { signal_select_604,
                              signal_select_603 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$14 <= signal_const_31;
        else
            if (signal_and_145)
                line_table$14 <= signal_cat_146;
    end
    assign signal_const_229 = 5'b01101;
    assign signal_eq_64 = signal_wire_34 == signal_const_229;
    assign signal_and_146 = line_write & signal_eq_64;
    assign signal_select_605 = signal_wire_36[5:0];
    assign signal_select_606 = signal_wire_36[13:8];
    assign signal_cat_147 = { signal_select_606,
                              signal_select_605 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$13 <= signal_const_31;
        else
            if (signal_and_146)
                line_table$13 <= signal_cat_147;
    end
    assign signal_const_231 = 5'b01100;
    assign signal_eq_65 = signal_wire_34 == signal_const_231;
    assign signal_and_147 = line_write & signal_eq_65;
    assign signal_select_607 = signal_wire_36[5:0];
    assign signal_select_608 = signal_wire_36[13:8];
    assign signal_cat_148 = { signal_select_608,
                              signal_select_607 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$12 <= signal_const_31;
        else
            if (signal_and_147)
                line_table$12 <= signal_cat_148;
    end
    assign signal_const_233 = 5'b01011;
    assign signal_eq_66 = signal_wire_34 == signal_const_233;
    assign signal_and_148 = line_write & signal_eq_66;
    assign signal_select_609 = signal_wire_36[5:0];
    assign signal_select_610 = signal_wire_36[13:8];
    assign signal_cat_149 = { signal_select_610,
                              signal_select_609 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$11 <= signal_const_31;
        else
            if (signal_and_148)
                line_table$11 <= signal_cat_149;
    end
    assign signal_const_235 = 5'b01010;
    assign signal_eq_67 = signal_wire_34 == signal_const_235;
    assign signal_and_149 = line_write & signal_eq_67;
    assign signal_select_611 = signal_wire_36[5:0];
    assign signal_select_612 = signal_wire_36[13:8];
    assign signal_cat_150 = { signal_select_612,
                              signal_select_611 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$10 <= signal_const_31;
        else
            if (signal_and_149)
                line_table$10 <= signal_cat_150;
    end
    assign signal_const_237 = 5'b01001;
    assign signal_eq_68 = signal_wire_34 == signal_const_237;
    assign signal_and_150 = line_write & signal_eq_68;
    assign signal_select_613 = signal_wire_36[5:0];
    assign signal_select_614 = signal_wire_36[13:8];
    assign signal_cat_151 = { signal_select_614,
                              signal_select_613 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$9 <= signal_const_31;
        else
            if (signal_and_150)
                line_table$9 <= signal_cat_151;
    end
    assign signal_const_239 = 5'b01000;
    assign signal_eq_69 = signal_wire_34 == signal_const_239;
    assign signal_and_151 = line_write & signal_eq_69;
    assign signal_select_615 = signal_wire_36[5:0];
    assign signal_select_616 = signal_wire_36[13:8];
    assign signal_cat_152 = { signal_select_616,
                              signal_select_615 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$8 <= signal_const_31;
        else
            if (signal_and_151)
                line_table$8 <= signal_cat_152;
    end
    assign signal_eq_70 = signal_wire_34 == signal_const_72;
    assign signal_and_152 = line_write & signal_eq_70;
    assign signal_select_617 = signal_wire_36[5:0];
    assign signal_select_618 = signal_wire_36[13:8];
    assign signal_cat_153 = { signal_select_618,
                              signal_select_617 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$7 <= signal_const_31;
        else
            if (signal_and_152)
                line_table$7 <= signal_cat_153;
    end
    assign signal_const_243 = 5'b00110;
    assign signal_eq_71 = signal_wire_34 == signal_const_243;
    assign signal_and_153 = line_write & signal_eq_71;
    assign signal_select_619 = signal_wire_36[5:0];
    assign signal_select_620 = signal_wire_36[13:8];
    assign signal_cat_154 = { signal_select_620,
                              signal_select_619 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$6 <= signal_const_31;
        else
            if (signal_and_153)
                line_table$6 <= signal_cat_154;
    end
    assign signal_const_245 = 5'b00101;
    assign signal_eq_72 = signal_wire_34 == signal_const_245;
    assign signal_and_154 = line_write & signal_eq_72;
    assign signal_select_621 = signal_wire_36[5:0];
    assign signal_select_622 = signal_wire_36[13:8];
    assign signal_cat_155 = { signal_select_622,
                              signal_select_621 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$5 <= signal_const_31;
        else
            if (signal_and_154)
                line_table$5 <= signal_cat_155;
    end
    assign signal_const_247 = 5'b00100;
    assign signal_eq_73 = signal_wire_34 == signal_const_247;
    assign signal_and_155 = line_write & signal_eq_73;
    assign signal_select_623 = signal_wire_36[5:0];
    assign signal_select_624 = signal_wire_36[13:8];
    assign signal_cat_156 = { signal_select_624,
                              signal_select_623 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$4 <= signal_const_31;
        else
            if (signal_and_155)
                line_table$4 <= signal_cat_156;
    end
    assign signal_const_249 = 5'b00011;
    assign signal_eq_74 = signal_wire_34 == signal_const_249;
    assign signal_and_156 = line_write & signal_eq_74;
    assign signal_select_625 = signal_wire_36[5:0];
    assign signal_select_626 = signal_wire_36[13:8];
    assign signal_cat_157 = { signal_select_626,
                              signal_select_625 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$3 <= signal_const_31;
        else
            if (signal_and_156)
                line_table$3 <= signal_cat_157;
    end
    assign signal_eq_75 = signal_wire_34 == signal_const_65;
    assign signal_and_157 = line_write & signal_eq_75;
    assign signal_select_627 = signal_wire_36[5:0];
    assign signal_select_628 = signal_wire_36[13:8];
    assign signal_cat_158 = { signal_select_628,
                              signal_select_627 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$2 <= signal_const_31;
        else
            if (signal_and_157)
                line_table$2 <= signal_cat_158;
    end
    assign signal_eq_76 = signal_wire_34 == signal_const_71;
    assign signal_and_158 = line_write & signal_eq_76;
    assign signal_select_629 = signal_wire_36[5:0];
    assign signal_select_630 = signal_wire_36[13:8];
    assign signal_cat_159 = { signal_select_630,
                              signal_select_629 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$1 <= signal_const_31;
        else
            if (signal_and_158)
                line_table$1 <= signal_cat_159;
    end
    assign signal_eq_77 = signal_wire_34 == signal_const_68;
    assign signal_and_159 = line_write & signal_eq_77;
    assign signal_select_631 = signal_wire_36[5:0];
    assign signal_select_632 = signal_wire_36[13:8];
    assign signal_cat_160 = { signal_select_632,
                              signal_select_631 };
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_table$0 <= signal_const_31;
        else
            if (signal_and_159)
                line_table$0 <= signal_cat_160;
    end
    assign line_rx_start = line_modes[7:4];
    assign signal_select_633 = line_rx_entry[3:0];
    assign signal_mux_206 = line_steps_in ? signal_select_633 : line_rx_0;
    assign signal_mux_207 = start_0 ? line_rx_start : signal_mux_206;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_21 <= signal_const_35;
        else
            signal_reg_21 <= signal_mux_207;
    end
    assign line_rx_0 = signal_reg_21;
    assign signal_select_634 = line_pair[11:6];
    assign signal_select_635 = line_pair[5:0];
    assign signal_select_636 = pin_out_base[27:27];
    assign signal_select_637 = pin_out_base[26:26];
    assign signal_select_638 = pin_out_base[25:25];
    assign signal_select_639 = pin_out_base[24:24];
    assign signal_select_640 = pin_out_base[23:23];
    assign signal_select_641 = pin_out_base[22:22];
    assign signal_select_642 = pin_out_base[21:21];
    assign signal_select_643 = pin_out_base[20:20];
    assign signal_select_644 = pin_out_base[19:19];
    assign signal_select_645 = pin_out_base[18:18];
    assign signal_select_646 = pin_out_base[17:17];
    assign signal_select_647 = pin_out_base[16:16];
    assign signal_select_648 = pin_out_base[15:15];
    assign signal_select_649 = pin_out_base[14:14];
    assign signal_select_650 = pin_out_base[13:13];
    assign signal_select_651 = pin_out_base[12:12];
    assign signal_select_652 = pin_out_base[11:11];
    assign signal_select_653 = pin_out_base[10:10];
    assign signal_select_654 = pin_out_base[9:9];
    assign signal_select_655 = pin_out_base[8:8];
    assign signal_select_656 = pin_out_base[7:7];
    assign signal_select_657 = pin_out_base[6:6];
    assign signal_select_658 = pin_out_base[5:5];
    assign signal_select_659 = pin_out_base[4:4];
    assign signal_select_660 = pin_out_base[3:3];
    assign signal_select_661 = pin_out_base[2:2];
    assign signal_select_662 = pin_out_base[1:1];
    assign signal_select_663 = signal_mux_211[27:12];
    assign signal_select_664 = signal_mux_211[11:0];
    assign signal_cat_161 = { signal_select_664,
                              signal_select_663 };
    assign signal_select_665 = signal_mux_210[27:20];
    assign signal_select_666 = signal_mux_210[19:0];
    assign signal_cat_162 = { signal_select_666,
                              signal_select_665 };
    assign signal_select_667 = signal_mux_209[27:24];
    assign signal_select_668 = signal_mux_209[23:0];
    assign signal_cat_163 = { signal_select_668,
                              signal_select_667 };
    assign signal_select_669 = signal_mux_208[27:26];
    assign signal_select_670 = signal_mux_208[25:0];
    assign signal_cat_164 = { signal_select_670,
                              signal_select_669 };
    assign signal_select_671 = signal_cat_167[27:27];
    assign signal_select_672 = signal_cat_167[26:0];
    assign signal_cat_165 = { signal_select_672,
                              signal_select_671 };
    assign signal_cat_166 = { signal_const_51,
                              d$side_set };
    assign signal_cat_167 = { signal_const_31,
                              signal_cat_166 };
    assign signal_select_673 = signal_wire_49[0:0];
    assign signal_mux_208 = signal_select_673 ? signal_cat_165 : signal_cat_167;
    assign signal_select_674 = signal_wire_49[1:1];
    assign signal_mux_209 = signal_select_674 ? signal_cat_164 : signal_mux_208;
    assign signal_select_675 = signal_wire_49[2:2];
    assign signal_mux_210 = signal_select_675 ? signal_cat_163 : signal_mux_209;
    assign signal_select_676 = signal_wire_49[3:3];
    assign signal_mux_211 = signal_select_676 ? signal_cat_162 : signal_mux_210;
    assign signal_select_677 = signal_wire_49[4:4];
    assign signal_mux_212 = signal_select_677 ? signal_cat_161 : signal_mux_211;
    assign signal_and_160 = signal_mux_212 & signal_and_161;
    assign signal_select_678 = signal_mux_221[27:12];
    assign signal_select_679 = signal_mux_221[11:0];
    assign signal_cat_168 = { signal_select_679,
                              signal_select_678 };
    assign signal_select_680 = signal_mux_220[27:20];
    assign signal_select_681 = signal_mux_220[19:0];
    assign signal_cat_169 = { signal_select_681,
                              signal_select_680 };
    assign signal_select_682 = signal_mux_219[27:24];
    assign signal_select_683 = signal_mux_219[23:0];
    assign signal_cat_170 = { signal_select_683,
                              signal_select_682 };
    assign signal_select_684 = signal_mux_218[27:26];
    assign signal_select_685 = signal_mux_218[25:0];
    assign signal_cat_171 = { signal_select_685,
                              signal_select_684 };
    assign signal_select_686 = signal_cat_176[27:27];
    assign signal_select_687 = signal_cat_176[26:0];
    assign signal_cat_172 = { signal_select_687,
                              signal_select_686 };
    assign signal_select_688 = signal_mux_215[7:0];
    assign signal_cat_173 = { signal_select_688,
                              signal_const_34 };
    assign signal_select_689 = signal_mux_214[11:0];
    assign signal_cat_174 = { signal_select_689,
                              signal_const_35 };
    assign signal_select_690 = signal_mux_213[13:0];
    assign signal_cat_175 = { signal_select_690,
                              signal_const_5 };
    assign signal_select_691 = signal_cat_239[0:0];
    assign signal_mux_213 = signal_select_691 ? signal_const_37 : signal_const_38;
    assign signal_select_692 = signal_cat_239[1:1];
    assign signal_mux_214 = signal_select_692 ? signal_cat_175 : signal_mux_213;
    assign signal_select_693 = signal_cat_239[2:2];
    assign signal_mux_215 = signal_select_693 ? signal_cat_174 : signal_mux_214;
    assign signal_select_694 = signal_cat_239[3:3];
    assign signal_mux_216 = signal_select_694 ? signal_cat_173 : signal_mux_215;
    assign signal_select_695 = signal_cat_239[4:4];
    assign signal_mux_217 = signal_select_695 ? signal_const : signal_mux_216;
    assign signal_not_52 = ~ signal_mux_217;
    assign signal_cat_176 = { signal_const_31,
                              signal_not_52 };
    assign signal_select_696 = signal_wire_49[0:0];
    assign signal_mux_218 = signal_select_696 ? signal_cat_172 : signal_cat_176;
    assign signal_select_697 = signal_wire_49[1:1];
    assign signal_mux_219 = signal_select_697 ? signal_cat_171 : signal_mux_218;
    assign signal_select_698 = signal_wire_49[2:2];
    assign signal_mux_220 = signal_select_698 ? signal_cat_170 : signal_mux_219;
    assign signal_select_699 = signal_wire_49[3:3];
    assign signal_mux_221 = signal_select_699 ? signal_cat_169 : signal_mux_220;
    assign signal_select_700 = signal_wire_49[4:4];
    assign signal_mux_222 = signal_select_700 ? signal_cat_168 : signal_mux_221;
    assign signal_and_161 = signal_mux_222 & signal_const_32;
    assign signal_not_53 = ~ signal_and_161;
    assign signal_select_701 = signal_mux_226[27:12];
    assign signal_select_702 = signal_mux_226[11:0];
    assign signal_cat_177 = { signal_select_702,
                              signal_select_701 };
    assign signal_select_703 = signal_mux_225[27:20];
    assign signal_select_704 = signal_mux_225[19:0];
    assign signal_cat_178 = { signal_select_704,
                              signal_select_703 };
    assign signal_select_705 = signal_mux_224[27:24];
    assign signal_select_706 = signal_mux_224[23:0];
    assign signal_cat_179 = { signal_select_706,
                              signal_select_705 };
    assign signal_select_707 = signal_mux_223[27:26];
    assign signal_select_708 = signal_mux_223[25:0];
    assign signal_cat_180 = { signal_select_708,
                              signal_select_707 };
    assign signal_select_709 = signal_cat_184[27:27];
    assign signal_select_710 = signal_cat_184[26:0];
    assign signal_cat_181 = { signal_select_710,
                              signal_select_709 };
    assign signal_not_54 = ~ signal_not_55;
    assign signal_select_711 = out_value[0:0];
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_22 <= signal_const_1;
        else
            if (starts_manchester_bit)
                signal_reg_22 <= signal_select_711;
    end
    assign flip_bit_0 = signal_reg_22;
    assign signal_not_55 = ~ flip_bit_0;
    assign signal_cat_182 = { signal_not_55,
                              signal_not_54 };
    assign signal_cat_183 = { signal_const_51,
                              signal_cat_182 };
    assign signal_cat_184 = { signal_const_31,
                              signal_cat_183 };
    assign signal_select_712 = signal_wire_47[0:0];
    assign signal_mux_223 = signal_select_712 ? signal_cat_181 : signal_cat_184;
    assign signal_select_713 = signal_wire_47[1:1];
    assign signal_mux_224 = signal_select_713 ? signal_cat_180 : signal_mux_223;
    assign signal_select_714 = signal_wire_47[2:2];
    assign signal_mux_225 = signal_select_714 ? signal_cat_179 : signal_mux_224;
    assign signal_select_715 = signal_wire_47[3:3];
    assign signal_mux_226 = signal_select_715 ? signal_cat_178 : signal_mux_225;
    assign signal_select_716 = signal_wire_47[4:4];
    assign signal_mux_227 = signal_select_716 ? signal_cat_177 : signal_mux_226;
    assign signal_and_162 = signal_mux_227 & signal_and_163;
    assign signal_select_717 = signal_mux_231[27:12];
    assign signal_select_718 = signal_mux_231[11:0];
    assign signal_cat_185 = { signal_select_718,
                              signal_select_717 };
    assign signal_select_719 = signal_mux_230[27:20];
    assign signal_select_720 = signal_mux_230[19:0];
    assign signal_cat_186 = { signal_select_720,
                              signal_select_719 };
    assign signal_select_721 = signal_mux_229[27:24];
    assign signal_select_722 = signal_mux_229[23:0];
    assign signal_cat_187 = { signal_select_722,
                              signal_select_721 };
    assign signal_select_723 = signal_mux_228[27:26];
    assign signal_select_724 = signal_mux_228[25:0];
    assign signal_cat_188 = { signal_select_724,
                              signal_select_723 };
    assign signal_select_725 = signal_wire_47[0:0];
    assign signal_mux_228 = signal_select_725 ? signal_const_54 : signal_const_55;
    assign signal_select_726 = signal_wire_47[1:1];
    assign signal_mux_229 = signal_select_726 ? signal_cat_188 : signal_mux_228;
    assign signal_select_727 = signal_wire_47[2:2];
    assign signal_mux_230 = signal_select_727 ? signal_cat_187 : signal_mux_229;
    assign signal_select_728 = signal_wire_47[3:3];
    assign signal_mux_231 = signal_select_728 ? signal_cat_186 : signal_mux_230;
    assign signal_select_729 = signal_wire_47[4:4];
    assign signal_mux_232 = signal_select_729 ? signal_cat_185 : signal_mux_231;
    assign signal_and_163 = signal_mux_232 & signal_const_32;
    assign signal_not_56 = ~ signal_and_163;
    assign signal_and_164 = pin_out_0 & signal_not_56;
    assign signal_or_21 = signal_and_164 | signal_and_162;
    assign signal_mux_233 = issue ? gnd : flip_pending_0;
    assign signal_eq_78 = d$shift_count == signal_const_71;
    assign manchester_out = signal_wire_33 & signal_eq_78;
    assign signal_eq_79 = d$out_dest$binary_variant == signal_const_40;
    assign signal_and_165 = op_go & is_opcode$3;
    assign signal_and_166 = signal_and_165 & signal_eq_79;
    assign starts_manchester_bit = signal_and_166 & manchester_out;
    assign signal_mux_234 = starts_manchester_bit ? vdd : signal_mux_233;
    assign signal_mux_235 = start_0 ? gnd : signal_mux_234;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_23 <= signal_const_1;
        else
            signal_reg_23 <= signal_mux_235;
    end
    assign flip_pending_0 = signal_reg_23;
    assign pin_out_flipped = flip_pending_0 ? signal_or_21 : pin_out_0;
    assign signal_and_167 = pin_out_flipped & signal_not_53;
    assign pin_out_side = signal_and_167 | signal_and_160;
    assign pin_out_base = signal_wire_50 ? pin_out_flipped : pin_out_side;
    assign signal_select_730 = pin_out_base[0:0];
    always @* begin
        case (signal_wire_47)
        0:
            out_pin <= signal_select_730;
        1:
            out_pin <= signal_select_662;
        2:
            out_pin <= signal_select_661;
        3:
            out_pin <= signal_select_660;
        4:
            out_pin <= signal_select_659;
        5:
            out_pin <= signal_select_658;
        6:
            out_pin <= signal_select_657;
        7:
            out_pin <= signal_select_656;
        8:
            out_pin <= signal_select_655;
        9:
            out_pin <= signal_select_654;
        10:
            out_pin <= signal_select_653;
        11:
            out_pin <= signal_select_652;
        12:
            out_pin <= signal_select_651;
        13:
            out_pin <= signal_select_650;
        14:
            out_pin <= signal_select_649;
        15:
            out_pin <= signal_select_648;
        16:
            out_pin <= signal_select_647;
        17:
            out_pin <= signal_select_646;
        18:
            out_pin <= signal_select_645;
        19:
            out_pin <= signal_select_644;
        20:
            out_pin <= signal_select_643;
        21:
            out_pin <= signal_select_642;
        22:
            out_pin <= signal_select_641;
        23:
            out_pin <= signal_select_640;
        24:
            out_pin <= signal_select_639;
        25:
            out_pin <= signal_select_638;
        26:
            out_pin <= signal_select_637;
        default:
            out_pin <= signal_select_636;
        endcase
    end
    assign signal_select_731 = line_modes[0:0];
    assign signal_and_168 = signal_select_731 & out_pin;
    assign signal_select_732 = out_value[0:0];
    assign signal_xor_6 = signal_select_732 ^ signal_and_168;
    assign line_tx_entry = signal_xor_6 ? signal_select_634 : signal_select_635;
    assign signal_select_733 = line_tx_entry[3:0];
    assign signal_eq_80 = d$shift_count == signal_const_71;
    assign signal_wire_33 = config$manchester;
    assign signal_not_57 = ~ signal_wire_33;
    assign signal_and_169 = signal_wire_37 & signal_not_57;
    assign line_out = signal_and_169 & signal_eq_80;
    assign signal_eq_81 = d$out_dest$binary_variant == signal_const_40;
    assign signal_and_170 = op_go & is_opcode$3;
    assign signal_and_171 = signal_and_170 & signal_eq_81;
    assign line_steps_out = signal_and_171 & line_out;
    assign signal_mux_236 = line_steps_out ? signal_select_733 : line_tx_0;
    assign signal_mux_237 = start_0 ? signal_const_35 : signal_mux_236;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_24 <= signal_const_35;
        else
            signal_reg_24 <= signal_mux_237;
    end
    assign line_tx_0 = signal_reg_24;
    assign signal_mux_238 = is_opcode$2 ? line_rx_0 : line_tx_0;
    always @* begin
        case (signal_mux_238)
        0:
            line_pair <= line_table$0;
        1:
            line_pair <= line_table$1;
        2:
            line_pair <= line_table$2;
        3:
            line_pair <= line_table$3;
        4:
            line_pair <= line_table$4;
        5:
            line_pair <= line_table$5;
        6:
            line_pair <= line_table$6;
        7:
            line_pair <= line_table$7;
        8:
            line_pair <= line_table$8;
        9:
            line_pair <= line_table$9;
        10:
            line_pair <= line_table$10;
        11:
            line_pair <= line_table$11;
        12:
            line_pair <= line_table$12;
        13:
            line_pair <= line_table$13;
        14:
            line_pair <= line_table$14;
        default:
            line_pair <= line_table$15;
        endcase
    end
    assign signal_select_734 = line_pair[5:0];
    assign line_steps_in = op_go & line_in;
    assign signal_mux_239 = line_steps_in ? line_pin : line_last_0;
    assign signal_mux_240 = start_0 ? gnd : signal_mux_239;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_25 <= signal_const_1;
        else
            signal_reg_25 <= signal_mux_240;
    end
    assign line_last_0 = signal_reg_25;
    assign signal_wire_34 = line_write$addr;
    assign signal_eq_82 = signal_wire_34 == signal_const_84;
    assign signal_wire_35 = line_write$valid;
    assign line_write = signal_wire_35 & halted_0;
    assign signal_and_172 = line_write & signal_eq_82;
    assign signal_wire_36 = line_write$data;
    assign signal_select_735 = signal_wire_36[7:0];
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            line_modes <= signal_const_34;
        else
            if (signal_and_172)
                line_modes <= signal_select_735;
    end
    assign signal_select_736 = line_modes[1:1];
    assign signal_and_173 = signal_select_736 & line_last_0;
    assign signal_select_737 = sample[27:27];
    assign signal_select_738 = sample[26:26];
    assign signal_select_739 = sample[25:25];
    assign signal_select_740 = sample[24:24];
    assign signal_select_741 = sample[23:23];
    assign signal_select_742 = sample[22:22];
    assign signal_select_743 = sample[21:21];
    assign signal_select_744 = sample[20:20];
    assign signal_select_745 = sample[19:19];
    assign signal_select_746 = sample[18:18];
    assign signal_select_747 = sample[17:17];
    assign signal_select_748 = sample[16:16];
    assign signal_select_749 = sample[15:15];
    assign signal_select_750 = sample[14:14];
    assign signal_select_751 = sample[13:13];
    assign signal_select_752 = sample[12:12];
    assign signal_select_753 = sample[11:11];
    assign signal_select_754 = sample[10:10];
    assign signal_select_755 = sample[9:9];
    assign signal_select_756 = sample[8:8];
    assign signal_select_757 = sample[7:7];
    assign signal_select_758 = sample[6:6];
    assign signal_select_759 = sample[5:5];
    assign signal_select_760 = sample[4:4];
    assign signal_select_761 = sample[3:3];
    assign signal_select_762 = sample[2:2];
    assign signal_select_763 = sample[1:1];
    assign signal_select_764 = sample[0:0];
    always @* begin
        case (signal_wire_39)
        0:
            line_pin <= signal_select_764;
        1:
            line_pin <= signal_select_763;
        2:
            line_pin <= signal_select_762;
        3:
            line_pin <= signal_select_761;
        4:
            line_pin <= signal_select_760;
        5:
            line_pin <= signal_select_759;
        6:
            line_pin <= signal_select_758;
        7:
            line_pin <= signal_select_757;
        8:
            line_pin <= signal_select_756;
        9:
            line_pin <= signal_select_755;
        10:
            line_pin <= signal_select_754;
        11:
            line_pin <= signal_select_753;
        12:
            line_pin <= signal_select_752;
        13:
            line_pin <= signal_select_751;
        14:
            line_pin <= signal_select_750;
        15:
            line_pin <= signal_select_749;
        16:
            line_pin <= signal_select_748;
        17:
            line_pin <= signal_select_747;
        18:
            line_pin <= signal_select_746;
        19:
            line_pin <= signal_select_745;
        20:
            line_pin <= signal_select_744;
        21:
            line_pin <= signal_select_743;
        22:
            line_pin <= signal_select_742;
        23:
            line_pin <= signal_select_741;
        24:
            line_pin <= signal_select_740;
        25:
            line_pin <= signal_select_739;
        26:
            line_pin <= signal_select_738;
        default:
            line_pin <= signal_select_737;
        endcase
    end
    assign signal_xor_7 = line_pin ^ signal_and_173;
    assign line_rx_entry = signal_xor_7 ? signal_select_600 : signal_select_734;
    assign signal_select_765 = line_rx_entry[5:5];
    assign signal_eq_83 = d$out_dest$binary_variant == signal_const_40;
    assign signal_eq_84 = d$shift_count == signal_const_71;
    assign signal_eq_85 = signal_select_903 == signal_const_14;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$2 <= gnd;
        else
            if (ir_load)
                is_opcode$2 <= signal_eq_85;
    end
    assign signal_wire_37 = config$line_code;
    assign signal_and_174 = signal_wire_37 & is_opcode$2;
    assign signal_and_175 = signal_and_174 & signal_eq_84;
    assign line_in = signal_and_175 & signal_eq_83;
    assign line_drop = line_in & signal_select_765;
    assign signal_mux_241 = line_drop ? isr_0 : signal_mux_205;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            isr_next <= isr_0;
        1:
            isr_next <= isr_0;
        2:
            isr_next <= signal_mux_241;
        3:
            isr_next <= signal_mux_150;
        4:
            isr_next <= signal_mux_149;
        5:
            isr_next <= isr_0;
        6:
            isr_next <= isr_0;
        default:
            isr_next <= signal_mux_148;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_26 <= signal_const;
        else
            if (go)
                signal_reg_26 <= isr_next;
    end
    assign isr_0 = signal_reg_26;
    assign signal_xor_8 = p_0 ^ alu_operand;
    assign signal_sub_7 = p_0 - alu_operand;
    assign signal_add_8 = p_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_242 <= signal_add_8;
        1:
            signal_mux_242 <= signal_sub_7;
        default:
            signal_mux_242 <= signal_xor_8;
        endcase
    end
    assign signal_eq_86 = d$alu_dest$binary_variant == signal_const_8;
    assign signal_mux_243 = signal_eq_86 ? signal_mux_242 : p_0;
    assign signal_cat_189 = { signal_const_30,
                              d$set_value };
    assign signal_eq_87 = d$set_dest$binary_variant == signal_const_11;
    assign signal_mux_244 = signal_eq_87 ? signal_cat_189 : p_0;
    assign signal_eq_88 = d$mov_dest$binary_variant == signal_const_9;
    assign signal_mux_245 = signal_eq_88 ? mov_value : p_0;
    assign signal_eq_89 = d$out_dest$binary_variant == signal_const_9;
    assign signal_mux_246 = signal_eq_89 ? out_value : p_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            p_next <= p_0;
        1:
            p_next <= p_0;
        2:
            p_next <= p_0;
        3:
            p_next <= signal_mux_246;
        4:
            p_next <= signal_mux_245;
        5:
            p_next <= signal_mux_244;
        6:
            p_next <= signal_mux_243;
        default:
            p_next <= p_0;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_27 <= signal_const;
        else
            if (go)
                signal_reg_27 <= p_next;
    end
    assign p_0 = signal_reg_27;
    assign signal_xor_9 = y_0 ^ alu_operand;
    assign signal_sub_8 = y_0 - alu_operand;
    assign signal_add_9 = y_0 + alu_operand;
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_247 <= signal_add_9;
        1:
            signal_mux_247 <= signal_sub_8;
        default:
            signal_mux_247 <= signal_xor_9;
        endcase
    end
    assign signal_eq_90 = d$alu_dest$binary_variant == signal_const_4;
    assign signal_mux_248 = signal_eq_90 ? signal_mux_247 : y_0;
    assign signal_cat_190 = { signal_const_30,
                              d$set_value };
    assign signal_eq_91 = d$set_dest$binary_variant == signal_const_14;
    assign signal_mux_249 = signal_eq_91 ? signal_cat_190 : y_0;
    assign signal_eq_92 = d$mov_dest$binary_variant == signal_const_14;
    assign signal_mux_250 = signal_eq_92 ? mov_value : y_0;
    assign signal_eq_93 = d$out_dest$binary_variant == signal_const_14;
    assign signal_mux_251 = signal_eq_93 ? out_value : y_0;
    assign signal_const_299 = 16'b0000000000000001;
    assign signal_sub_9 = y_0 - signal_const_299;
    assign signal_eq_94 = d$jmp_cond$binary_variant == signal_const_25;
    assign signal_mux_252 = signal_eq_94 ? signal_sub_9 : y_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            y_next <= signal_mux_252;
        1:
            y_next <= y_0;
        2:
            y_next <= y_0;
        3:
            y_next <= signal_mux_251;
        4:
            y_next <= signal_mux_250;
        5:
            y_next <= signal_mux_249;
        6:
            y_next <= signal_mux_248;
        default:
            y_next <= y_0;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_28 <= signal_const;
        else
            if (go)
                signal_reg_28 <= y_next;
    end
    assign y_0 = signal_reg_28;
    always @* begin
        case (d$alu_reg$binary_variant)
        0:
            signal_mux_253 <= x_0;
        1:
            signal_mux_253 <= y_0;
        2:
            signal_mux_253 <= p_0;
        3:
            signal_mux_253 <= isr_0;
        default:
            signal_mux_253 <= osr_0;
        endcase
    end
    assign d$alu_reg$binary_variant = word[2:0];
    assign signal_const_301 = 13'b0000000000000;
    assign signal_cat_191 = { signal_const_301,
                              d$alu_reg$binary_variant };
    assign d$alu_is_reg = word[3:3];
    assign alu_operand = d$alu_is_reg ? signal_mux_253 : signal_cat_191;
    assign signal_add_10 = x_0 + alu_operand;
    assign d$alu_op$binary_variant = word[5:4];
    always @* begin
        case (d$alu_op$binary_variant)
        0:
            signal_mux_254 <= signal_add_10;
        1:
            signal_mux_254 <= signal_sub_5;
        default:
            signal_mux_254 <= signal_xor_1;
        endcase
    end
    assign d$alu_dest$binary_variant = word[7:6];
    assign signal_eq_95 = d$alu_dest$binary_variant == signal_const_5;
    assign signal_mux_255 = signal_eq_95 ? signal_mux_254 : x_0;
    assign d$set_value = word[4:0];
    assign signal_cat_192 = { signal_const_30,
                              d$set_value };
    assign signal_const_304 = 3'b001;
    assign d$set_dest$binary_variant = word[7:5];
    assign signal_eq_96 = d$set_dest$binary_variant == signal_const_304;
    assign signal_mux_256 = signal_eq_96 ? signal_cat_192 : x_0;
    assign signal_eq_97 = d$mov_dest$binary_variant == signal_const_304;
    assign signal_mux_257 = signal_eq_97 ? mov_value : x_0;
    assign signal_eq_98 = d$out_dest$binary_variant == signal_const_304;
    assign signal_mux_258 = signal_eq_98 ? out_value : x_0;
    assign signal_sub_10 = x_0 - signal_const_299;
    assign d$jmp_cond$binary_variant = word[12:9];
    assign signal_eq_99 = d$jmp_cond$binary_variant == signal_const_77;
    assign signal_mux_259 = signal_eq_99 ? signal_sub_10 : x_0;
    always @* begin
        case (d$opcode$binary_variant)
        0:
            x_next <= signal_mux_259;
        1:
            x_next <= x_0;
        2:
            x_next <= x_0;
        3:
            x_next <= signal_mux_258;
        4:
            x_next <= signal_mux_257;
        5:
            x_next <= signal_mux_256;
        6:
            x_next <= signal_mux_255;
        default:
            x_next <= x_0;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_29 <= signal_const;
        else
            if (go)
                signal_reg_29 <= x_next;
    end
    assign x_0 = signal_reg_29;
    assign signal_cat_193 = { signal_const_34,
                              x_0 };
    assign signal_select_766 = signal_mux_262[7:0];
    assign signal_cat_194 = { signal_select_766,
                              signal_const_34 };
    assign signal_select_767 = signal_mux_261[11:0];
    assign signal_cat_195 = { signal_select_767,
                              signal_const_35 };
    assign signal_select_768 = signal_mux_260[13:0];
    assign signal_cat_196 = { signal_select_768,
                              signal_const_5 };
    assign signal_select_769 = signal_wire_38[0:0];
    assign signal_mux_260 = signal_select_769 ? signal_const_37 : signal_const_38;
    assign signal_select_770 = signal_wire_38[1:1];
    assign signal_mux_261 = signal_select_770 ? signal_cat_196 : signal_mux_260;
    assign signal_select_771 = signal_wire_38[2:2];
    assign signal_mux_262 = signal_select_771 ? signal_cat_195 : signal_mux_261;
    assign signal_select_772 = signal_wire_38[3:3];
    assign signal_mux_263 = signal_select_772 ? signal_cat_194 : signal_mux_262;
    assign signal_wire_38 = config$in_count;
    assign signal_select_773 = signal_wire_38[4:4];
    assign signal_mux_264 = signal_select_773 ? signal_const : signal_mux_263;
    assign signal_not_58 = ~ signal_mux_264;
    assign signal_select_774 = signal_mux_268[27:16];
    assign signal_select_775 = signal_mux_268[15:0];
    assign signal_cat_197 = { signal_select_775,
                              signal_select_774 };
    assign signal_select_776 = signal_mux_267[27:8];
    assign signal_select_777 = signal_mux_267[7:0];
    assign signal_cat_198 = { signal_select_777,
                              signal_select_776 };
    assign signal_select_778 = signal_mux_266[27:4];
    assign signal_select_779 = signal_mux_266[3:0];
    assign signal_cat_199 = { signal_select_779,
                              signal_select_778 };
    assign signal_select_780 = signal_mux_265[27:2];
    assign signal_select_781 = signal_mux_265[1:0];
    assign signal_cat_200 = { signal_select_781,
                              signal_select_780 };
    assign signal_select_782 = sample[27:1];
    assign signal_select_783 = sample[0:0];
    assign signal_cat_201 = { signal_select_783,
                              signal_select_782 };
    assign signal_select_784 = signal_wire_39[0:0];
    assign signal_mux_265 = signal_select_784 ? signal_cat_201 : sample;
    assign signal_select_785 = signal_wire_39[1:1];
    assign signal_mux_266 = signal_select_785 ? signal_cat_200 : signal_mux_265;
    assign signal_select_786 = signal_wire_39[2:2];
    assign signal_mux_267 = signal_select_786 ? signal_cat_199 : signal_mux_266;
    assign signal_select_787 = signal_wire_39[3:3];
    assign signal_mux_268 = signal_select_787 ? signal_cat_198 : signal_mux_267;
    assign signal_wire_39 = config$in_base;
    assign signal_select_788 = signal_wire_39[4:4];
    assign signal_mux_269 = signal_select_788 ? signal_cat_197 : signal_mux_268;
    assign signal_select_789 = signal_mux_269[15:0];
    assign signal_and_176 = signal_select_789 & signal_not_58;
    assign signal_cat_202 = { signal_const_34,
                              signal_and_176 };
    assign d$mov_source$binary_variant = word[2:0];
    always @* begin
        case (d$mov_source$binary_variant)
        0:
            mov_value24 <= signal_cat_202;
        1:
            mov_value24 <= signal_cat_193;
        2:
            mov_value24 <= signal_cat_113;
        3:
            mov_value24 <= signal_const_20;
        4:
            mov_value24 <= signal_cat_112;
        5:
            mov_value24 <= signal_cat_111;
        6:
            mov_value24 <= now_0;
        default:
            mov_value24 <= capture_0;
        endcase
    end
    assign signal_select_790 = mov_value24[15:0];
    assign d$mov_op$binary_variant = word[4:3];
    always @* begin
        case (d$mov_op$binary_variant)
        0:
            mov_value <= signal_select_790;
        1:
            mov_value <= signal_not_45;
        default:
            mov_value <= signal_cat_110;
        endcase
    end
    assign signal_eq_100 = d$mov_dest$binary_variant == signal_const_13;
    assign signal_mux_270 = signal_eq_100 ? mov_value : osr_0;
    assign signal_select_791 = signal_mux_273[15:8];
    assign signal_cat_203 = { signal_const_34,
                              signal_select_791 };
    assign signal_select_792 = signal_mux_272[15:4];
    assign signal_cat_204 = { signal_const_35,
                              signal_select_792 };
    assign signal_select_793 = signal_mux_271[15:2];
    assign signal_cat_205 = { signal_const_5,
                              signal_select_793 };
    assign signal_select_794 = osr_before[15:1];
    assign signal_cat_206 = { signal_const_1,
                              signal_select_794 };
    assign signal_select_795 = d$shift_count[0:0];
    assign signal_mux_271 = signal_select_795 ? signal_cat_206 : osr_before;
    assign signal_select_796 = d$shift_count[1:1];
    assign signal_mux_272 = signal_select_796 ? signal_cat_205 : signal_mux_271;
    assign signal_select_797 = d$shift_count[2:2];
    assign signal_mux_273 = signal_select_797 ? signal_cat_204 : signal_mux_272;
    assign signal_select_798 = d$shift_count[3:3];
    assign signal_mux_274 = signal_select_798 ? signal_cat_203 : signal_mux_273;
    assign signal_select_799 = d$shift_count[4:4];
    assign signal_mux_275 = signal_select_799 ? signal_const : signal_mux_274;
    assign signal_select_800 = signal_mux_278[7:0];
    assign signal_cat_207 = { signal_select_800,
                              signal_const_34 };
    assign signal_select_801 = signal_mux_277[11:0];
    assign signal_cat_208 = { signal_select_801,
                              signal_const_35 };
    assign signal_select_802 = signal_mux_276[13:0];
    assign signal_cat_209 = { signal_select_802,
                              signal_const_5 };
    assign signal_select_803 = osr_before[14:0];
    assign signal_cat_210 = { signal_select_803,
                              signal_const_1 };
    assign signal_select_804 = d$shift_count[0:0];
    assign signal_mux_276 = signal_select_804 ? signal_cat_210 : osr_before;
    assign signal_select_805 = d$shift_count[1:1];
    assign signal_mux_277 = signal_select_805 ? signal_cat_209 : signal_mux_276;
    assign signal_select_806 = d$shift_count[2:2];
    assign signal_mux_278 = signal_select_806 ? signal_cat_208 : signal_mux_277;
    assign signal_select_807 = d$shift_count[3:3];
    assign signal_mux_279 = signal_select_807 ? signal_cat_207 : signal_mux_278;
    assign signal_select_808 = d$shift_count[4:4];
    assign signal_mux_280 = signal_select_808 ? signal_const : signal_mux_279;
    assign osr_shifted = signal_wire_46 ? signal_mux_275 : signal_mux_280;
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
            osr_next <= signal_mux_270;
        5:
            osr_next <= osr_0;
        6:
            osr_next <= osr_0;
        default:
            osr_next <= signal_mux_147;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_30 <= signal_const;
        else
            if (go)
                signal_reg_30 <= osr_next;
    end
    assign osr_0 = signal_reg_30;
    assign signal_wire_40 = flush;
    assign flush_0 = signal_wire_40 & halted_0;
    assign signal_not_59 = ~ signal_select_809;
    assign signal_and_177 = pulls & signal_not_59;
    assign signal_and_178 = is_opcode$3 & pull_ok;
    assign signal_or_22 = signal_and_178 | signal_and_177;
    assign signal_and_179 = op_go & signal_or_22;
    assign tx_pop = signal_and_179;
    assign signal_wire_41 = tx$value;
    assign signal_wire_42 = tx$valid;
    host_fifo
        tx
        ( .clock(signal_wire_57),
          .clear(signal_wire_56),
          .push$valid(signal_wire_42),
          .push$value(signal_wire_41),
          .pop(tx_pop),
          .flush(flush_0),
          .head(signal_inst_1[15:0]),
          .level(signal_inst_1[19:16]),
          .empty(signal_inst_1[20:20]),
          .full(signal_inst_1[21:21]) );
    assign signal_select_809 = signal_inst_1[20:20];
    assign signal_not_60 = ~ signal_select_809;
    assign signal_not_61 = ~ signal_wire_43;
    assign pull_fifo = pull_now & signal_not_61;
    assign pull_ok = pull_fifo & signal_not_60;
    assign signal_mux_281 = pull_ok ? signal_select_407 : osr_0;
    assign signal_eq_101 = signal_select_903 == signal_const_143;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$3 <= gnd;
        else
            if (ir_load)
                is_opcode$3 <= signal_eq_101;
    end
    assign signal_and_180 = op_go & is_opcode$3;
    assign pulls_data = signal_and_180 & pull_data_ok;
    assign signal_const_330 = 4'b1000;
    assign signal_eq_102 = d$sys_op$binary_variant == signal_const_330;
    assign signal_and_181 = is_opcode$7 & signal_eq_102;
    assign seeks = op_go & signal_and_181;
    assign signal_or_23 = seeks | pulls_data;
    assign signal_mux_282 = start_0 ? gnd : signal_or_23;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_31 <= signal_const_1;
        else
            signal_reg_31 <= signal_mux_282;
    end
    assign data_moved = signal_reg_31;
    assign signal_not_62 = ~ data_moved;
    assign signal_wire_43 = config$autopull_data;
    assign signal_wire_44 = config$pull_threshold;
    assign signal_const_332 = 4'b0100;
    assign d$sys_op$binary_variant = word[3:0];
    assign signal_eq_103 = d$sys_op$binary_variant == signal_const_332;
    assign signal_eq_104 = signal_select_903 == signal_const_115;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$7 <= gnd;
        else
            if (ir_load)
                is_opcode$7 <= signal_eq_104;
    end
    assign pulls = is_opcode$7 & signal_eq_103;
    assign signal_mux_283 = pulls ? osr_count_zero : osr_count_0;
    assign osr_count_zero = 5'b00000;
    assign d$mov_dest$binary_variant = word[7:5];
    assign signal_eq_105 = d$mov_dest$binary_variant == signal_const_13;
    assign signal_mux_284 = signal_eq_105 ? osr_count_zero : osr_count_0;
    assign signal_select_810 = signal_add_11[4:0];
    assign signal_cat_211 = { gnd,
                              d$shift_count };
    assign osr_count_before = pull_now ? signal_const_68 : osr_count_0;
    assign signal_cat_212 = { gnd,
                              osr_count_before };
    assign signal_add_11 = signal_cat_212 + signal_cat_211;
    assign signal_lt_17 = signal_const_224 < signal_add_11;
    assign osr_count_next = signal_lt_17 ? signal_const_84 : signal_select_810;
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
            osr_count_next_value <= signal_mux_284;
        5:
            osr_count_next_value <= osr_count_0;
        6:
            osr_count_next_value <= osr_count_0;
        default:
            osr_count_next_value <= signal_mux_283;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_32 <= signal_const_84;
        else
            if (go)
                signal_reg_32 <= osr_count_next_value;
    end
    assign osr_count_0 = signal_reg_32;
    assign signal_lt_18 = osr_count_0 < signal_wire_44;
    assign signal_not_63 = ~ signal_lt_18;
    assign signal_wire_45 = config$autopull;
    assign pull_now = signal_wire_45 & signal_not_63;
    assign pull_data = pull_now & signal_wire_43;
    assign pull_data_ok = pull_data & signal_not_62;
    assign osr_before = pull_data_ok ? signal_wire_23 : signal_mux_281;
    assign signal_select_811 = shift_back[0:0];
    assign signal_mux_285 = signal_select_811 ? signal_cat_109 : osr_before;
    assign signal_select_812 = shift_back[1:1];
    assign signal_mux_286 = signal_select_812 ? signal_cat_108 : signal_mux_285;
    assign signal_select_813 = shift_back[2:2];
    assign signal_mux_287 = signal_select_813 ? signal_cat_107 : signal_mux_286;
    assign signal_select_814 = shift_back[3:3];
    assign signal_mux_288 = signal_select_814 ? signal_cat_106 : signal_mux_287;
    assign shift_back = signal_const_84 - d$shift_count;
    assign signal_select_815 = shift_back[4:4];
    assign signal_mux_289 = signal_select_815 ? signal_const : signal_mux_288;
    assign signal_and_182 = signal_mux_289 & mask;
    assign signal_wire_46 = config$out_shift_right;
    assign out_value = signal_wire_46 ? signal_and_133 : signal_and_182;
    assign signal_cat_213 = { signal_const_31,
                              out_value };
    assign signal_select_816 = signal_wire_47[0:0];
    assign signal_mux_290 = signal_select_816 ? signal_cat_105 : signal_cat_213;
    assign signal_select_817 = signal_wire_47[1:1];
    assign signal_mux_291 = signal_select_817 ? signal_cat_104 : signal_mux_290;
    assign signal_select_818 = signal_wire_47[2:2];
    assign signal_mux_292 = signal_select_818 ? signal_cat_103 : signal_mux_291;
    assign signal_select_819 = signal_wire_47[3:3];
    assign signal_mux_293 = signal_select_819 ? signal_cat_102 : signal_mux_292;
    assign signal_select_820 = signal_wire_47[4:4];
    assign signal_mux_294 = signal_select_820 ? signal_cat_101 : signal_mux_293;
    assign signal_and_183 = signal_mux_294 & signal_and_184;
    assign signal_select_821 = signal_mux_303[27:12];
    assign signal_select_822 = signal_mux_303[11:0];
    assign signal_cat_214 = { signal_select_822,
                              signal_select_821 };
    assign signal_select_823 = signal_mux_302[27:20];
    assign signal_select_824 = signal_mux_302[19:0];
    assign signal_cat_215 = { signal_select_824,
                              signal_select_823 };
    assign signal_select_825 = signal_mux_301[27:24];
    assign signal_select_826 = signal_mux_301[23:0];
    assign signal_cat_216 = { signal_select_826,
                              signal_select_825 };
    assign signal_select_827 = signal_mux_300[27:26];
    assign signal_select_828 = signal_mux_300[25:0];
    assign signal_cat_217 = { signal_select_828,
                              signal_select_827 };
    assign signal_select_829 = signal_cat_222[27:27];
    assign signal_select_830 = signal_cat_222[26:0];
    assign signal_cat_218 = { signal_select_830,
                              signal_select_829 };
    assign signal_select_831 = signal_mux_297[7:0];
    assign signal_cat_219 = { signal_select_831,
                              signal_const_34 };
    assign signal_select_832 = signal_mux_296[11:0];
    assign signal_cat_220 = { signal_select_832,
                              signal_const_35 };
    assign signal_select_833 = signal_mux_295[13:0];
    assign signal_cat_221 = { signal_select_833,
                              signal_const_5 };
    assign signal_select_834 = d$shift_count[0:0];
    assign signal_mux_295 = signal_select_834 ? signal_const_37 : signal_const_38;
    assign signal_select_835 = d$shift_count[1:1];
    assign signal_mux_296 = signal_select_835 ? signal_cat_221 : signal_mux_295;
    assign signal_select_836 = d$shift_count[2:2];
    assign signal_mux_297 = signal_select_836 ? signal_cat_220 : signal_mux_296;
    assign signal_select_837 = d$shift_count[3:3];
    assign signal_mux_298 = signal_select_837 ? signal_cat_219 : signal_mux_297;
    assign d$shift_count = word[4:0];
    assign signal_select_838 = d$shift_count[4:4];
    assign signal_mux_299 = signal_select_838 ? signal_const : signal_mux_298;
    assign signal_not_64 = ~ signal_mux_299;
    assign signal_cat_222 = { signal_const_31,
                              signal_not_64 };
    assign signal_select_839 = signal_wire_47[0:0];
    assign signal_mux_300 = signal_select_839 ? signal_cat_218 : signal_cat_222;
    assign signal_select_840 = signal_wire_47[1:1];
    assign signal_mux_301 = signal_select_840 ? signal_cat_217 : signal_mux_300;
    assign signal_select_841 = signal_wire_47[2:2];
    assign signal_mux_302 = signal_select_841 ? signal_cat_216 : signal_mux_301;
    assign signal_select_842 = signal_wire_47[3:3];
    assign signal_mux_303 = signal_select_842 ? signal_cat_215 : signal_mux_302;
    assign signal_wire_47 = config$out_base;
    assign signal_select_843 = signal_wire_47[4:4];
    assign signal_mux_304 = signal_select_843 ? signal_cat_214 : signal_mux_303;
    assign signal_and_184 = signal_mux_304 & signal_const_134;
    assign signal_not_65 = ~ signal_and_184;
    assign signal_and_185 = pin_dir_base & signal_not_65;
    assign signal_or_24 = signal_and_185 | signal_and_183;
    assign d$out_dest$binary_variant = word[7:5];
    assign signal_eq_106 = d$out_dest$binary_variant == signal_const_11;
    assign signal_mux_305 = signal_eq_106 ? signal_or_24 : pin_dir_base;
    assign signal_select_844 = signal_mux_309[27:12];
    assign signal_select_845 = signal_mux_309[11:0];
    assign signal_cat_223 = { signal_select_845,
                              signal_select_844 };
    assign signal_select_846 = signal_mux_308[27:20];
    assign signal_select_847 = signal_mux_308[19:0];
    assign signal_cat_224 = { signal_select_847,
                              signal_select_846 };
    assign signal_select_848 = signal_mux_307[27:24];
    assign signal_select_849 = signal_mux_307[23:0];
    assign signal_cat_225 = { signal_select_849,
                              signal_select_848 };
    assign signal_select_850 = signal_mux_306[27:26];
    assign signal_select_851 = signal_mux_306[25:0];
    assign signal_cat_226 = { signal_select_851,
                              signal_select_850 };
    assign signal_select_852 = signal_cat_230[27:27];
    assign signal_select_853 = signal_cat_230[26:0];
    assign signal_cat_227 = { signal_select_853,
                              signal_select_852 };
    assign signal_select_854 = signal_select_856[4:3];
    assign signal_select_855 = signal_select_856[4:3];
    assign signal_select_856 = word[12:8];
    assign signal_select_857 = signal_select_856[4:4];
    assign signal_cat_228 = { gnd,
                              signal_select_857 };
    always @* begin
        case (signal_wire_48)
        0:
            d$side_set <= signal_const_5;
        1:
            d$side_set <= signal_cat_228;
        2:
            d$side_set <= signal_select_855;
        default:
            d$side_set <= signal_select_854;
        endcase
    end
    assign signal_cat_229 = { signal_const_51,
                              d$side_set };
    assign signal_cat_230 = { signal_const_31,
                              signal_cat_229 };
    assign signal_select_858 = signal_wire_49[0:0];
    assign signal_mux_306 = signal_select_858 ? signal_cat_227 : signal_cat_230;
    assign signal_select_859 = signal_wire_49[1:1];
    assign signal_mux_307 = signal_select_859 ? signal_cat_226 : signal_mux_306;
    assign signal_select_860 = signal_wire_49[2:2];
    assign signal_mux_308 = signal_select_860 ? signal_cat_225 : signal_mux_307;
    assign signal_select_861 = signal_wire_49[3:3];
    assign signal_mux_309 = signal_select_861 ? signal_cat_224 : signal_mux_308;
    assign signal_select_862 = signal_wire_49[4:4];
    assign signal_mux_310 = signal_select_862 ? signal_cat_223 : signal_mux_309;
    assign signal_and_186 = signal_mux_310 & signal_and_187;
    assign signal_select_863 = signal_mux_319[27:12];
    assign signal_select_864 = signal_mux_319[11:0];
    assign signal_cat_231 = { signal_select_864,
                              signal_select_863 };
    assign signal_select_865 = signal_mux_318[27:20];
    assign signal_select_866 = signal_mux_318[19:0];
    assign signal_cat_232 = { signal_select_866,
                              signal_select_865 };
    assign signal_select_867 = signal_mux_317[27:24];
    assign signal_select_868 = signal_mux_317[23:0];
    assign signal_cat_233 = { signal_select_868,
                              signal_select_867 };
    assign signal_select_869 = signal_mux_316[27:26];
    assign signal_select_870 = signal_mux_316[25:0];
    assign signal_cat_234 = { signal_select_870,
                              signal_select_869 };
    assign signal_select_871 = signal_cat_240[27:27];
    assign signal_select_872 = signal_cat_240[26:0];
    assign signal_cat_235 = { signal_select_872,
                              signal_select_871 };
    assign signal_select_873 = signal_mux_313[7:0];
    assign signal_cat_236 = { signal_select_873,
                              signal_const_34 };
    assign signal_select_874 = signal_mux_312[11:0];
    assign signal_cat_237 = { signal_select_874,
                              signal_const_35 };
    assign signal_select_875 = signal_mux_311[13:0];
    assign signal_cat_238 = { signal_select_875,
                              signal_const_5 };
    assign signal_select_876 = signal_cat_239[0:0];
    assign signal_mux_311 = signal_select_876 ? signal_const_37 : signal_const_38;
    assign signal_select_877 = signal_cat_239[1:1];
    assign signal_mux_312 = signal_select_877 ? signal_cat_238 : signal_mux_311;
    assign signal_select_878 = signal_cat_239[2:2];
    assign signal_mux_313 = signal_select_878 ? signal_cat_237 : signal_mux_312;
    assign signal_select_879 = signal_cat_239[3:3];
    assign signal_mux_314 = signal_select_879 ? signal_cat_236 : signal_mux_313;
    assign signal_wire_48 = config$side_set_count;
    assign signal_cat_239 = { signal_const_40,
                              signal_wire_48 };
    assign signal_select_880 = signal_cat_239[4:4];
    assign signal_mux_315 = signal_select_880 ? signal_const : signal_mux_314;
    assign signal_not_66 = ~ signal_mux_315;
    assign signal_cat_240 = { signal_const_31,
                              signal_not_66 };
    assign signal_select_881 = signal_wire_49[0:0];
    assign signal_mux_316 = signal_select_881 ? signal_cat_235 : signal_cat_240;
    assign signal_select_882 = signal_wire_49[1:1];
    assign signal_mux_317 = signal_select_882 ? signal_cat_234 : signal_mux_316;
    assign signal_select_883 = signal_wire_49[2:2];
    assign signal_mux_318 = signal_select_883 ? signal_cat_233 : signal_mux_317;
    assign signal_select_884 = signal_wire_49[3:3];
    assign signal_mux_319 = signal_select_884 ? signal_cat_232 : signal_mux_318;
    assign signal_wire_49 = config$side_set_base;
    assign signal_select_885 = signal_wire_49[4:4];
    assign signal_mux_320 = signal_select_885 ? signal_cat_231 : signal_mux_319;
    assign signal_and_187 = signal_mux_320 & signal_const_134;
    assign signal_not_67 = ~ signal_and_187;
    assign signal_and_188 = pin_dir_0 & signal_not_67;
    assign pin_dir_side = signal_and_188 | signal_and_186;
    assign signal_wire_50 = config$side_set_pindirs;
    assign pin_dir_base = signal_wire_50 ? pin_dir_side : pin_dir_0;
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
            pin_dir_next <= signal_mux_305;
        4:
            pin_dir_next <= signal_mux_146;
        5:
            pin_dir_next <= signal_mux_130;
        6:
            pin_dir_next <= pin_dir_base;
        default:
            pin_dir_next <= pin_dir_base;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_33 <= signal_const_29;
        else
            if (op_go)
                signal_reg_33 <= pin_dir_next;
    end
    assign pin_dir_0 = signal_reg_33;
    assign signal_select_886 = pin_dir_0[19:19];
    assign signal_mux_321 = signal_select_886 ? signal_select_315 : signal_select_316;
    assign signal_select_887 = signal_wire_51[20:20];
    assign signal_select_888 = pin_out_0[20:20];
    assign signal_or_25 = signal_select_888 | signal_select_887;
    assign signal_select_889 = signal_wire_51[21:21];
    assign signal_select_890 = pin_out_0[21:21];
    assign signal_or_26 = signal_select_890 | signal_select_889;
    assign signal_select_891 = signal_wire_51[22:22];
    assign signal_select_892 = pin_out_0[22:22];
    assign signal_or_27 = signal_select_892 | signal_select_891;
    assign signal_select_893 = signal_wire_51[23:23];
    assign signal_select_894 = pin_out_0[23:23];
    assign signal_or_28 = signal_select_894 | signal_select_893;
    assign signal_select_895 = signal_wire_51[24:24];
    assign signal_select_896 = pin_out_0[24:24];
    assign signal_or_29 = signal_select_896 | signal_select_895;
    assign signal_select_897 = signal_wire_51[25:25];
    assign signal_select_898 = pin_out_0[25:25];
    assign signal_or_30 = signal_select_898 | signal_select_897;
    assign signal_select_899 = signal_wire_51[26:26];
    assign signal_select_900 = pin_out_0[26:26];
    assign signal_or_31 = signal_select_900 | signal_select_899;
    assign signal_wire_51 = inputs;
    assign signal_select_901 = signal_wire_51[27:27];
    assign signal_select_902 = pin_out_0[27:27];
    assign signal_or_32 = signal_select_902 | signal_select_901;
    assign sample = { signal_or_32,
                      signal_or_31,
                      signal_or_30,
                      signal_or_29,
                      signal_or_28,
                      signal_or_27,
                      signal_or_26,
                      signal_or_25,
                      signal_mux_321,
                      signal_mux_114,
                      signal_mux_113,
                      signal_mux_112,
                      signal_mux_111,
                      signal_mux_110,
                      signal_mux_109,
                      signal_mux_108,
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
    assign signal_and_189 = sample & wait_select_0;
    assign signal_eq_107 = signal_and_189 == signal_const_29;
    assign wait_pin_cur = ~ signal_eq_107;
    assign signal_eq_108 = wait_pin_cur == d$wait_polarity;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            word <= signal_const;
        else
            if (ir_load)
                word <= signal_wire_54;
    end
    assign d$wait_source$binary_variant = word[6:5];
    always @* begin
        case (d$wait_source$binary_variant)
        0:
            wait_ready <= signal_eq_108;
        1:
            wait_ready <= signal_and_66;
        2:
            wait_ready <= deadline_ready;
        default:
            wait_ready <= signal_mux_98;
        endcase
    end
    assign signal_not_68 = ~ wait_ready;
    assign gnd = 1'b0;
    assign signal_eq_109 = signal_select_903 == signal_const_304;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$1 <= gnd;
        else
            if (ir_load)
                is_opcode$1 <= signal_eq_109;
    end
    assign wait_holds = is_opcode$1 & signal_not_68;
    assign signal_not_69 = ~ wait_holds;
    assign advance = op_go & signal_not_69;
    assign signal_or_33 = advance | refill;
    assign ir_load = signal_or_33;
    assign signal_eq_110 = signal_select_903 == signal_const_40;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            is_opcode$0 <= vdd;
        else
            if (ir_load)
                is_opcode$0 <= signal_eq_110;
    end
    assign jmp_go = go & is_opcode$0;
    assign signal_mux_322 = jmp_go ? jmp_target_or_next : pc_after_next;
    assign signal_mux_323 = signal_wire_58 ? signal_const_26 : signal_mux_322;
    assign fetch_addr = signal_mux_323;
    assign signal_or_34 = signal_wire_58 | start_0;
    assign signal_not_70 = ~ signal_or_34;
    assign free_0 = halted_0 & signal_not_70;
    assign signal_wire_52 = program_read$valid;
    assign program_read = signal_wire_52 & free_0;
    assign signal_mux_324 = program_read ? signal_wire_8 : fetch_addr;
    assign signal_mux_325 = program_write ? signal_wire_7 : signal_mux_324;
    assign signal_wire_53 = program_write$valid;
    assign program_write = signal_wire_53 & halted_0;
    assign vdd = 1'b1;
    sram_macro
        sram_macro
        ( .clock(signal_wire_57),
          .men(vdd),
          .wen(program_write),
          .ren(vdd),
          .addr(signal_mux_325),
          .din(signal_wire_6),
          .bm(signal_const_38),
          .dout(signal_inst_2[15:0]) );
    assign signal_wire_54 = signal_inst_2;
    assign signal_select_903 = signal_wire_54[15:13];
    always @* begin
        case (signal_select_903)
        0:
            signal_mux_326 <= signal_lt_12;
        1:
            signal_mux_326 <= signal_mux_80;
        2:
            signal_mux_326 <= signal_and_55;
        3:
            signal_mux_326 <= signal_and_55;
        4:
            signal_mux_326 <= signal_lt_7;
        5:
            signal_mux_326 <= signal_lt_6;
        6:
            signal_mux_326 <= signal_and_54;
        default:
            signal_mux_326 <= signal_and_53;
        endcase
    end
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            decode_ok_0 <= vdd;
        else
            if (ir_load)
                decode_ok_0 <= signal_mux_326;
    end
    assign signal_not_71 = ~ decode_ok_0;
    assign signal_and_190 = issue & signal_not_71;
    assign signal_mux_327 = signal_and_190 ? vdd : signal_mux_79;
    assign signal_wire_55 = stop;
    assign signal_mux_328 = signal_wire_55 ? vdd : signal_mux_327;
    assign signal_wire_56 = clear;
    assign signal_wire_57 = clock;
    assign signal_wire_58 = start;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            start_0 <= signal_const_1;
        else
            start_0 <= signal_wire_58;
    end
    assign halted_next = start_0 ? gnd : signal_mux_328;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_34 <= vdd;
        else
            signal_reg_34 <= halted_next;
    end
    assign halted_0 = signal_reg_34;
    assign signal_not_72 = ~ halted_0;
    assign signal_and_191 = signal_not_72 & signal_eq_22;
    assign issue = signal_and_191 & signal_not_16;
    assign go = issue & decode_ok_0;
    assign op_go = go & signal_not_15;
    assign signal_mux_329 = op_go ? pin_out_next : pin_out_flipped;
    always @(posedge signal_wire_57) begin
        if (signal_wire_56)
            signal_reg_35 <= signal_const_29;
        else
            if (signal_or_9)
                signal_reg_35 <= signal_mux_329;
    end
    assign pin_out_0 = signal_reg_35;
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
    assign free = free_0;
    assign irq = irq_0;
    assign fault$underflow = signal_reg_7;
    assign fault$overflow = signal_reg_6;
    assign fault$missed_deadline = signal_reg_5;
    assign fault$decode = signal_reg_4;
    assign fault$assumption = signal_reg_3;
    assign capture = capture_0;
    assign capture_armed = capture_armed_0;
    assign tx_level = signal_select_3;
    assign rx_level = signal_select_2;
    assign rx_head = rx_head_0;
    assign instruction = word;
    assign program_word = signal_wire_54;
    assign decode_ok = decode_ok_0;
    assign opcode_onehot = signal_cat;
    assign wait_select = wait_select_0;
    assign crc = crc_0;
    assign stuff_run = stuff_run_0;
    assign flip_pending = flip_pending_0;
    assign flip_bit = flip_bit_0;
    assign push$valid = signal_and;
    assign push$value = push_value;
    assign line_tx = line_tx_0;
    assign line_rx = line_rx_0;
    assign line_flag = line_flag_0;
    assign line_last = line_last_0;

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
    config$line_code,
    config$manchester,
    config$out_base,
    config$out_count,
    config$out_shift_right,
    config$pull_threshold,
    config$push_threshold,
    config$route,
    config$set_base,
    config$set_count,
    config$side_set_base,
    config$side_set_pindirs,
    config$stuff_level,
    config$stuff_threshold,
    setup$floor,
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
    input config$line_code;
    input config$manchester;
    input [4:0] config$out_base;
    input [4:0] config$out_count;
    input config$out_shift_right;
    input [4:0] config$pull_threshold;
    input [4:0] config$push_threshold;
    input config$route;
    input [4:0] config$set_base;
    input [2:0] config$set_count;
    input [4:0] config$side_set_base;
    input config$side_set_pindirs;
    input config$stuff_level;
    input [4:0] config$stuff_threshold;
    input setup$floor;
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
    wire [4:0] signal_const_15;
    wire [4:0] signal_mux_10;
    wire [4:0] signal_const_16;
    wire [4:0] signal_mux_11;
    wire [4:0] signal_mux_12;
    wire [4:0] signal_mux_13;
    wire [4:0] signal_const_17;
    wire [4:0] signal_mux_14;
    wire signal_not;
    wire signal_not_1;
    wire signal_not_2;
    wire signal_or;
    wire signal_not_3;
    wire signal_not_4;
    wire signal_or_1;
    wire signal_or_2;
    wire signal_or_3;
    wire signal_not_5;
    wire signal_not_6;
    wire signal_or_4;
    wire signal_not_7;
    wire signal_not_8;
    wire signal_or_5;
    wire signal_or_6;
    wire signal_not_9;
    wire signal_not_10;
    wire signal_or_7;
    wire signal_or_8;
    wire signal_or_9;
    wire [4:0] next_reason;
    wire [4:0] signal_const_20;
    wire [4:0] signal_mux_15;
    wire [4:0] signal_mux_16;
    wire [4:0] signal_const_22;
    wire [4:0] signal_const_23;
    wire [4:0] signal_mux_17;
    wire [4:0] signal_const_24;
    wire [4:0] signal_const_25;
    wire [4:0] signal_mux_18;
    wire [4:0] signal_mux_19;
    wire [4:0] signal_const_26;
    wire [4:0] signal_const_27;
    wire [4:0] signal_mux_20;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_mux_22;
    wire [4:0] signal_mux_23;
    wire signal_not_11;
    wire signal_not_12;
    wire signal_not_13;
    wire signal_or_10;
    wire signal_or_11;
    wire signal_not_14;
    wire signal_not_15;
    wire signal_or_12;
    wire signal_not_16;
    wire signal_not_17;
    wire signal_or_13;
    wire signal_or_14;
    wire signal_or_15;
    wire signal_not_18;
    wire signal_not_19;
    wire signal_or_16;
    wire signal_not_20;
    wire signal_or_17;
    wire signal_or_18;
    wire [4:0] target_reason;
    wire [4:0] signal_mux_24;
    wire [4:0] signal_mux_25;
    wire [4:0] signal_const_30;
    wire [4:0] signal_mux_26;
    wire [4:0] signal_mux_27;
    wire [4:0] signal_mux_28;
    reg [4:0] signal_cases;
    wire [4:0] signal_mux_29;
    wire [4:0] signal_wire;
    reg [4:0] reason_0;
    wire [9:0] signal_const_31;
    wire [9:0] signal_cat;
    wire [9:0] signal_const_32;
    wire [9:0] signal_mux_30;
    wire [9:0] signal_cat_1;
    wire [9:0] signal_cat_2;
    wire [9:0] signal_mux_31;
    wire [9:0] signal_mux_32;
    wire [9:0] signal_cat_3;
    wire [9:0] signal_mux_33;
    wire [9:0] signal_mux_34;
    wire [9:0] signal_mux_35;
    reg [9:0] signal_cases_1;
    wire [9:0] signal_mux_36;
    wire [9:0] signal_wire_1;
    reg [9:0] reject_pc_0;
    wire signal_const_33;
    wire signal_mux_37;
    wire signal_mux_38;
    wire signal_mux_39;
    wire signal_mux_40;
    wire signal_mux_41;
    wire signal_mux_42;
    reg signal_cases_2;
    wire signal_mux_43;
    wire signal_wire_2;
    reg accepted_0;
    wire signal_mux_44;
    wire signal_mux_45;
    wire signal_mux_46;
    wire signal_mux_47;
    wire signal_mux_48;
    wire signal_mux_49;
    reg signal_cases_3;
    wire signal_mux_50;
    wire signal_wire_3;
    reg finished_0;
    wire signal_eq;
    wire signal_not_21;
    wire [8:0] signal_const_35;
    wire [6:0] signal_const_36;
    wire [8:0] signal_cat_4;
    wire [7:0] signal_select;
    wire [8:0] signal_cat_5;
    wire [6:0] signal_const_38;
    wire [6:0] signal_sub;
    wire [1:0] signal_const_39;
    wire [8:0] signal_cat_6;
    wire [8:0] signal_add;
    wire [8:0] signal_add_1;
    wire [6:0] signal_sub_1;
    wire [8:0] signal_cat_7;
    wire [7:0] signal_select_1;
    wire [8:0] signal_cat_8;
    wire [7:0] signal_select_2;
    wire [8:0] signal_cat_9;
    wire [7:0] signal_const_44;
    wire [7:0] signal_select_3;
    wire [7:0] signal_mux_51;
    wire [7:0] signal_mux_52;
    reg [7:0] signal_cases_4;
    wire [7:0] signal_wire_4;
    reg [7:0] wide_count;
    wire [8:0] signal_cat_10;
    wire [8:0] signal_add_2;
    wire [7:0] signal_select_4;
    wire [8:0] signal_cat_11;
    wire [8:0] signal_cat_12;
    wire [8:0] signal_add_3;
    wire [8:0] wide_at;
    wire [8:0] narrow_at;
    wire [8:0] signal_add_4;
    wire [8:0] signal_mux_53;
    wire [8:0] interval_at;
    wire [8:0] signal_mux_54;
    wire [8:0] signal_mux_55;
    wire [8:0] signal_cat_13;
    wire [7:0] signal_select_5;
    wire [8:0] signal_cat_14;
    wire [7:0] signal_mux_56;
    wire [7:0] signal_mux_57;
    wire [7:0] signal_mux_58;
    wire [7:0] signal_mux_59;
    wire [7:0] signal_mux_60;
    wire [7:0] signal_mux_61;
    wire [7:0] signal_mux_62;
    wire [7:0] signal_mux_63;
    reg [7:0] signal_cases_5;
    wire [7:0] signal_wire_5;
    reg [7:0] sel;
    wire [8:0] signal_cat_15;
    wire [8:0] signal_add_5;
    wire [8:0] signal_add_6;
    wire [8:0] signal_add_7;
    wire [7:0] signal_select_6;
    wire [8:0] signal_cat_16;
    wire [8:0] signal_cat_17;
    wire [8:0] signal_add_8;
    wire [8:0] signal_add_9;
    wire [8:0] signal_mux_64;
    wire [8:0] signal_cat_18;
    wire [7:0] signal_select_7;
    wire [8:0] signal_cat_19;
    wire [8:0] signal_cat_20;
    wire [8:0] signal_add_10;
    wire [8:0] signal_const_52;
    wire [8:0] entries_at;
    wire [8:0] signal_add_11;
    wire [8:0] signal_add_12;
    wire [8:0] signal_mux_65;
    wire [8:0] signal_cat_21;
    wire [8:0] signal_wire_6;
    reg [8:0] setup$base_0;
    wire [8:0] signal_add_13;
    reg [8:0] signal_cases_6;
    wire [8:0] data_addr;
    reg [8:0] read_at;
    reg read_valid;
    wire [3:0] signal_const_57;
    wire signal_eq_1;
    wire [3:0] signal_mux_66;
    wire [3:0] signal_mux_67;
    wire [3:0] signal_mux_68;
    wire [3:0] signal_mux_69;
    wire [3:0] signal_mux_70;
    wire [3:0] signal_mux_71;
    wire [3:0] signal_mux_72;
    wire [3:0] signal_mux_73;
    wire [3:0] signal_mux_74;
    reg [3:0] signal_cases_7;
    wire [3:0] signal_mux_75;
    wire [3:0] signal_const_58;
    wire [3:0] signal_mux_76;
    wire [3:0] signal_const_337;
    reg [3:0] signal_cases_8;
    wire [3:0] signal_mux_77;
    wire [3:0] signal_mux_78;
    wire [3:0] signal_mux_79;
    wire [3:0] signal_const_311;
    wire [3:0] signal_mux_80;
    wire [3:0] signal_mux_81;
    wire [3:0] signal_mux_82;
    wire [3:0] signal_mux_83;
    wire [3:0] signal_mux_84;
    wire [3:0] signal_const_354;
    wire [3:0] signal_const_335;
    wire [3:0] signal_mux_85;
    wire [3:0] signal_mux_86;
    wire [3:0] signal_mux_87;
    wire [3:0] signal_const_353;
    wire [3:0] signal_mux_88;
    wire [3:0] signal_const_345;
    wire [3:0] signal_mux_89;
    wire signal_lt;
    wire signal_not_22;
    wire [3:0] signal_mux_90;
    wire [3:0] signal_mux_91;
    wire [3:0] signal_const_352;
    wire [3:0] signal_mux_92;
    wire [3:0] signal_const_356;
    wire [3:0] signal_mux_93;
    wire [3:0] signal_mux_94;
    wire [1:0] signal_const_59;
    wire [1:0] signal_const_61;
    wire [1:0] signal_add_14;
    wire signal_not_23;
    wire signal_mux_95;
    wire signal_mux_96;
    wire signal_mux_97;
    wire [7:0] signal_mux_98;
    wire [7:0] signal_mux_99;
    wire [7:0] signal_mux_100;
    reg [7:0] signal_cases_9;
    wire [7:0] signal_mux_101;
    wire [7:0] signal_cat_22;
    wire [7:0] signal_add_15;
    reg [7:0] signal_cases_10;
    wire [2:0] signal_const_65;
    wire [2:0] signal_const_66;
    wire [2:0] signal_mux_102;
    wire [2:0] signal_mux_103;
    wire [2:0] signal_const_68;
    wire [2:0] signal_add_16;
    wire [2:0] signal_add_17;
    wire [2:0] signal_mux_104;
    wire [2:0] signal_mux_105;
    wire [2:0] signal_mux_106;
    wire [2:0] signal_add_18;
    wire [2:0] signal_mux_107;
    wire [2:0] signal_mux_108;
    wire [2:0] signal_mux_109;
    wire [2:0] signal_mux_110;
    wire [2:0] signal_mux_111;
    wire [7:0] signal_mux_112;
    wire [7:0] signal_mux_113;
    wire [7:0] signal_const_75;
    wire signal_eq_2;
    wire [7:0] signal_mux_114;
    wire [7:0] signal_mux_115;
    wire [7:0] signal_mux_116;
    wire [7:0] signal_mux_117;
    wire [7:0] signal_mux_118;
    wire [7:0] signal_mux_119;
    wire [7:0] signal_select_8;
    wire signal_eq_3;
    wire [7:0] signal_mux_120;
    wire [7:0] signal_mux_121;
    reg [7:0] signal_cases_11;
    wire [7:0] signal_wire_7;
    reg [7:0] count;
    wire [7:0] signal_mux_122;
    wire [7:0] signal_mux_123;
    reg [7:0] signal_cases_12;
    wire [7:0] signal_wire_8;
    reg [7:0] hi;
    wire [8:0] signal_cat_23;
    wire [8:0] signal_cat_24;
    wire [8:0] signal_add_19;
    wire [7:0] signal_select_9;
    wire [8:0] signal_cat_25;
    wire [7:0] mid;
    wire [7:0] signal_add_20;
    wire signal_lt_1;
    wire [7:0] signal_mux_124;
    wire [7:0] signal_mux_125;
    wire [7:0] signal_mux_126;
    wire [7:0] signal_mux_127;
    wire signal_eq_4;
    wire [7:0] signal_mux_128;
    wire [15:0] signal_wire_9;
    wire [1:0] signal_mux_129;
    wire [1:0] signal_mux_130;
    wire [1:0] signal_mux_131;
    wire [1:0] signal_mux_132;
    wire [1:0] signal_mux_133;
    wire [1:0] signal_mux_134;
    wire [1:0] signal_mux_135;
    reg [1:0] signal_cases_13;
    wire [1:0] signal_mux_136;
    wire [1:0] signal_mux_137;
    reg [1:0] signal_cases_14;
    wire [1:0] signal_add_21;
    wire [1:0] signal_mux_138;
    wire [1:0] signal_mux_139;
    wire [1:0] signal_mux_140;
    wire [1:0] signal_mux_141;
    wire [1:0] signal_add_22;
    wire [1:0] signal_mux_142;
    wire [1:0] signal_mux_143;
    wire [8:0] signal_wire_10;
    wire [8:0] signal_const_97;
    wire [8:0] signal_add_23;
    wire [8:0] signal_wire_11;
    wire [8:0] signal_mux_144;
    wire [8:0] signal_mux_145;
    wire [8:0] signal_mux_146;
    wire [8:0] signal_mux_147;
    wire [8:0] signal_mux_148;
    reg [8:0] signal_cases_15;
    wire [2:0] signal_const_99;
    wire signal_eq_5;
    wire [8:0] signal_mux_149;
    wire [8:0] signal_select_10;
    wire [8:0] signal_const_100;
    wire signal_eq_6;
    wire [8:0] signal_mux_150;
    wire [2:0] signal_mux_151;
    wire [2:0] signal_mux_152;
    reg signal_cases_16;
    wire signal_mux_153;
    wire signal_mux_154;
    reg signal_cases_17;
    wire signal_wire_12;
    reg failed_next$edge_b;
    wire signal_not_24;
    reg signal_cases_18;
    wire signal_mux_155;
    wire signal_mux_156;
    reg signal_cases_19;
    wire signal_wire_13;
    reg failed_next$edge_a;
    wire signal_not_25;
    wire signal_not_26;
    reg signal_cases_20;
    wire signal_mux_157;
    wire signal_mux_158;
    reg signal_cases_21;
    wire signal_wire_14;
    reg failed_next$awaiting;
    wire signal_not_27;
    wire signal_not_28;
    reg signal_cases_22;
    wire signal_mux_159;
    wire signal_mux_160;
    reg signal_cases_23;
    wire signal_wire_15;
    reg failed_next$captured;
    wire signal_not_29;
    wire signal_not_30;
    reg signal_cases_24;
    wire signal_mux_161;
    wire signal_mux_162;
    reg signal_cases_25;
    wire signal_wire_16;
    reg failed_next$arm;
    wire signal_not_31;
    wire signal_not_32;
    reg signal_cases_26;
    wire signal_mux_163;
    wire signal_mux_164;
    reg signal_cases_27;
    wire signal_wire_17;
    reg failed_next$y;
    wire signal_not_33;
    wire signal_not_34;
    reg signal_cases_28;
    wire signal_mux_165;
    wire signal_mux_166;
    reg signal_cases_29;
    wire signal_wire_18;
    reg failed_next$x;
    wire signal_not_35;
    wire signal_not_36;
    reg signal_cases_30;
    wire signal_mux_167;
    wire signal_mux_168;
    reg signal_cases_31;
    wire signal_wire_19;
    reg failed_next$period;
    wire signal_not_37;
    reg signal_cases_32;
    wire signal_mux_169;
    wire signal_mux_170;
    reg signal_cases_33;
    wire signal_wire_20;
    reg failed_next$offset;
    wire signal_not_38;
    wire signal_not_39;
    reg signal_cases_34;
    wire signal_mux_171;
    wire signal_mux_172;
    reg signal_cases_35;
    wire signal_wire_21;
    reg failed_next$phase;
    wire signal_not_40;
    wire [22:0] signal_select_11;
    wire signal_select_12;
    wire signal_not_41;
    wire [23:0] signal_cat_26;
    wire [23:0] signal_const_110;
    wire signal_lt_2;
    wire signal_not_42;
    wire signal_not_43;
    wire [3:0] signal_const_111;
    wire signal_eq_7;
    wire [2:0] signal_const_112;
    wire signal_eq_8;
    wire signal_and;
    wire [3:0] signal_select_13;
    wire signal_lt_3;
    wire [3:0] signal_select_14;
    wire signal_eq_9;
    wire signal_and_1;
    wire signal_lt_4;
    wire signal_not_44;
    wire signal_or_19;
    wire signal_lt_5;
    wire signal_and_2;
    wire signal_lt_6;
    wire signal_lt_7;
    wire signal_lt_8;
    wire signal_not_45;
    wire [4:0] signal_select_15;
    wire signal_lt_9;
    wire signal_not_46;
    wire signal_and_3;
    wire signal_eq_10;
    wire signal_eq_11;
    wire [4:0] signal_const_123;
    wire signal_lt_10;
    wire signal_lt_11;
    reg signal_mux_173;
    wire [3:0] signal_const_125;
    wire [3:0] signal_select_16;
    wire signal_lt_12;
    reg signal_mux_174;
    wire signal_not_47;
    wire signal_or_20;
    wire signal_not_48;
    wire signal_lt_13;
    wire signal_lt_14;
    wire signal_lt_15;
    wire signal_lt_16;
    wire [22:0] signal_select_17;
    wire signal_select_18;
    wire signal_not_49;
    wire [23:0] signal_cat_27;
    wire [22:0] signal_select_19;
    wire [23:0] signal_mux_175;
    wire [23:0] signal_mux_176;
    wire [23:0] signal_mux_177;
    wire [23:0] signal_mux_178;
    wire [47:0] signal_mux_179;
    wire [47:0] signal_const_126;
    wire [47:0] signal_const_129;
    wire [47:0] signal_const_130;
    reg [47:0] signal_mux_180;
    wire [31:0] signal_cat_28;
    wire [15:0] signal_const_131;
    wire [47:0] signal_cat_29;
    wire [31:0] signal_cat_30;
    wire [47:0] signal_cat_31;
    wire [31:0] signal_cat_32;
    wire [47:0] signal_cat_33;
    wire [47:0] signal_cat_34;
    wire [23:0] signal_select_20;
    wire [23:0] signal_const_134;
    wire [23:0] signal_mux_181;
    wire [23:0] signal_const_135;
    wire [23:0] fell$phase_hi;
    wire [23:0] signal_select_21;
    wire [24:0] signal_select_22;
    wire signal_select_23;
    wire signal_not_50;
    wire [25:0] signal_cat_35;
    wire [25:0] signal_const_137;
    wire signal_lt_17;
    wire signal_not_51;
    wire [25:0] signal_const_138;
    wire [24:0] signal_select_24;
    wire signal_select_25;
    wire signal_not_52;
    wire [25:0] signal_cat_36;
    wire signal_lt_18;
    wire signal_not_53;
    wire signal_and_4;
    wire signal_and_5;
    wire [23:0] signal_mux_182;
    wire signal_eq_12;
    wire signal_eq_13;
    wire signal_lt_19;
    wire signal_not_54;
    wire [15:0] signal_const_141;
    wire [15:0] signal_sub_2;
    wire [15:0] signal_mux_183;
    wire [15:0] signal_mux_184;
    wire [15:0] signal_mux_185;
    wire [15:0] signal_mux_186;
    wire [15:0] signal_mux_187;
    wire [15:0] fell$y_hi;
    wire [15:0] signal_mux_188;
    wire [15:0] signal_mux_189;
    reg signal_cases_36;
    wire signal_mux_190;
    wire signal_mux_191;
    reg signal_cases_37;
    wire signal_wire_22;
    reg failed_target$edge_b;
    wire signal_not_55;
    reg signal_cases_38;
    wire signal_mux_192;
    wire signal_mux_193;
    reg signal_cases_39;
    wire signal_wire_23;
    reg failed_target$edge_a;
    wire signal_not_56;
    wire signal_not_57;
    wire signal_or_21;
    wire held$awaiting;
    wire signal_wire_24;
    wire signal_eq_14;
    wire signal_and_6;
    wire signal_eq_15;
    wire checked_awaiting;
    wire signal_not_58;
    wire signal_or_22;
    wire signal_not_59;
    wire signal_or_23;
    wire way$awaiting;
    wire signal_not_60;
    reg signal_cases_40;
    wire signal_mux_194;
    wire signal_mux_195;
    reg signal_cases_41;
    wire signal_wire_25;
    reg failed_target$awaiting;
    wire signal_not_61;
    wire signal_not_62;
    wire signal_or_24;
    wire held$captured;
    wire signal_wire_26;
    wire signal_eq_16;
    wire signal_and_7;
    wire signal_eq_17;
    wire checked_captured;
    wire signal_not_63;
    wire signal_or_25;
    wire signal_not_64;
    wire signal_or_26;
    wire way$captured;
    wire signal_not_65;
    reg signal_cases_42;
    wire signal_mux_196;
    wire signal_mux_197;
    reg signal_cases_43;
    wire signal_wire_27;
    reg failed_target$captured;
    wire signal_not_66;
    wire signal_not_67;
    wire signal_or_27;
    wire [25:0] signal_cat_37;
    wire signal_lt_20;
    wire signal_not_68;
    wire [25:0] signal_cat_38;
    wire signal_lt_21;
    wire signal_not_69;
    wire signal_and_8;
    wire signal_and_9;
    wire [23:0] signal_const_147;
    wire signal_eq_18;
    wire signal_eq_19;
    wire signal_and_10;
    wire signal_or_28;
    wire signal_not_70;
    wire signal_or_29;
    wire way$arm;
    wire signal_not_71;
    reg signal_cases_44;
    wire signal_mux_198;
    wire signal_mux_199;
    reg signal_cases_45;
    wire signal_wire_28;
    reg failed_target$arm;
    wire signal_not_72;
    wire signal_not_73;
    wire signal_or_30;
    wire signal_eq_20;
    wire signal_eq_21;
    wire signal_and_11;
    wire [15:0] signal_sub_3;
    wire [15:0] signal_mux_200;
    wire [15:0] signal_mux_201;
    wire [15:0] signal_mux_202;
    wire [15:0] signal_mux_203;
    wire signal_lt_22;
    wire signal_not_74;
    wire [15:0] signal_sub_4;
    wire signal_eq_22;
    wire [15:0] signal_mux_204;
    wire [15:0] signal_mux_205;
    wire signal_not_75;
    wire signal_and_12;
    wire [15:0] signal_mux_206;
    wire [15:0] signal_mux_207;
    wire [15:0] signal_mux_208;
    wire signal_lt_23;
    wire signal_not_76;
    wire signal_and_13;
    wire signal_mux_209;
    wire signal_not_77;
    wire signal_or_31;
    wire way$y;
    wire signal_not_78;
    reg signal_cases_46;
    wire signal_mux_210;
    wire signal_mux_211;
    reg signal_cases_47;
    wire signal_wire_29;
    reg failed_target$y;
    wire signal_not_79;
    wire signal_not_80;
    wire signal_or_32;
    wire signal_eq_23;
    wire signal_eq_24;
    wire signal_and_14;
    wire [15:0] signal_sub_5;
    wire [15:0] signal_mux_212;
    wire [15:0] signal_mux_213;
    wire [15:0] signal_mux_214;
    wire [15:0] signal_mux_215;
    wire signal_lt_24;
    wire signal_not_81;
    wire [15:0] signal_sub_6;
    wire signal_eq_25;
    wire [15:0] signal_mux_216;
    wire [15:0] signal_mux_217;
    wire signal_not_82;
    wire signal_and_15;
    wire [15:0] signal_mux_218;
    wire [15:0] signal_mux_219;
    wire [15:0] signal_mux_220;
    wire signal_lt_25;
    wire signal_not_83;
    wire signal_and_16;
    wire signal_mux_221;
    wire signal_not_84;
    wire signal_or_33;
    wire way$x;
    wire signal_not_85;
    reg signal_cases_48;
    wire signal_mux_222;
    wire signal_mux_223;
    reg signal_cases_49;
    wire signal_wire_30;
    reg failed_target$x;
    wire signal_not_86;
    wire signal_not_87;
    wire signal_or_34;
    wire signal_eq_26;
    wire signal_eq_27;
    wire signal_and_17;
    wire [15:0] signal_mux_224;
    wire [15:0] signal_mux_225;
    wire [15:0] signal_select_26;
    wire signal_lt_26;
    wire signal_not_88;
    wire [15:0] signal_select_27;
    wire [15:0] signal_mux_226;
    wire [15:0] signal_mux_227;
    wire signal_lt_27;
    wire signal_not_89;
    wire signal_and_18;
    wire signal_not_90;
    wire signal_and_19;
    wire signal_mux_228;
    wire signal_not_91;
    wire signal_or_35;
    wire way$period;
    wire signal_not_92;
    reg signal_cases_50;
    wire signal_mux_229;
    wire signal_mux_230;
    reg signal_cases_51;
    wire signal_wire_31;
    reg failed_target$period;
    wire signal_not_93;
    reg signal_cases_52;
    wire signal_mux_231;
    wire signal_mux_232;
    reg signal_cases_53;
    wire signal_wire_32;
    reg failed_target$offset;
    wire signal_not_94;
    wire signal_eq_28;
    wire signal_not_95;
    wire signal_eq_29;
    wire signal_not_96;
    wire signal_eq_30;
    wire signal_eq_31;
    wire signal_eq_32;
    wire signal_and_20;
    wire signal_and_21;
    wire signal_not_97;
    wire signal_mux_233;
    wire signal_mux_234;
    wire signal_mux_235;
    wire signal_mux_236;
    wire signal_and_22;
    wire signal_and_23;
    wire signal_and_24;
    wire signal_not_98;
    wire signal_or_36;
    wire [24:0] signal_select_28;
    wire signal_select_29;
    wire signal_not_99;
    wire [25:0] signal_cat_39;
    wire [24:0] signal_select_30;
    wire signal_select_31;
    wire [1:0] signal_cat_40;
    wire [25:0] signal_cat_41;
    wire signal_select_32;
    wire signal_not_100;
    wire [25:0] signal_cat_42;
    wire signal_lt_28;
    wire signal_not_101;
    wire [24:0] signal_select_33;
    wire signal_select_34;
    wire [1:0] signal_cat_43;
    wire [25:0] signal_cat_44;
    wire signal_select_35;
    wire signal_not_102;
    wire [25:0] signal_cat_45;
    wire [24:0] signal_select_36;
    wire signal_select_37;
    wire signal_not_103;
    wire [25:0] signal_cat_46;
    wire signal_lt_29;
    wire signal_not_104;
    wire [24:0] signal_select_38;
    wire [15:0] signal_mux_237;
    wire [15:0] signal_mux_238;
    wire [15:0] signal_mux_239;
    wire [15:0] fell$period_lo;
    wire [15:0] signal_mux_240;
    wire [15:0] signal_mux_241;
    wire [15:0] signal_mux_242;
    wire [15:0] signal_mux_243;
    reg [15:0] signal_cases_54;
    wire [15:0] signal_mux_244;
    wire [15:0] signal_mux_245;
    wire [15:0] signal_mux_246;
    wire [15:0] signal_mux_247;
    wire [15:0] signal_mux_248;
    wire [15:0] signal_mux_249;
    wire [15:0] signal_mux_250;
    wire [15:0] signal_mux_251;
    wire [15:0] signal_mux_252;
    reg [15:0] signal_cases_55;
    wire [15:0] signal_wire_33;
    reg [15:0] row$period_lo;
    wire [25:0] signal_cat_47;
    wire [25:0] signal_cat_48;
    wire [15:0] signal_sub_7;
    wire signal_eq_33;
    wire [15:0] signal_mux_253;
    wire [15:0] signal_mux_254;
    wire [15:0] signal_sub_8;
    wire signal_eq_34;
    wire [15:0] signal_mux_255;
    wire [15:0] signal_mux_256;
    wire [15:0] signal_mux_257;
    wire [15:0] signal_mux_258;
    wire [15:0] signal_mux_259;
    wire [15:0] signal_mux_260;
    wire [15:0] fell$x_lo;
    wire [15:0] signal_mux_261;
    wire [15:0] signal_mux_262;
    wire [15:0] signal_mux_263;
    wire [15:0] signal_mux_264;
    reg [15:0] signal_cases_56;
    wire [15:0] signal_mux_265;
    wire [15:0] signal_mux_266;
    wire [15:0] signal_mux_267;
    wire [15:0] signal_mux_268;
    wire [15:0] signal_mux_269;
    wire [15:0] signal_mux_270;
    wire [15:0] signal_mux_271;
    wire [15:0] signal_mux_272;
    wire [15:0] signal_mux_273;
    reg [15:0] signal_cases_57;
    wire [15:0] signal_wire_34;
    reg [15:0] row$x_lo;
    wire signal_lt_30;
    wire [15:0] signal_mux_274;
    wire signal_not_105;
    wire signal_and_25;
    wire [15:0] signal_mux_275;
    wire [15:0] signal_mux_276;
    wire [2:0] signal_const_181;
    wire signal_eq_35;
    wire signal_eq_36;
    wire signal_and_26;
    wire [15:0] signal_mux_277;
    wire signal_eq_37;
    wire [2:0] signal_const_185;
    wire signal_eq_38;
    wire signal_and_27;
    wire signal_eq_39;
    wire [2:0] signal_const_187;
    wire signal_eq_40;
    wire signal_and_28;
    wire signal_eq_41;
    wire signal_eq_42;
    wire signal_and_29;
    wire signal_or_37;
    wire signal_or_38;
    wire signal_not_106;
    wire [15:0] signal_mux_278;
    wire [15:0] fell$y_lo;
    wire [15:0] signal_mux_279;
    wire [15:0] signal_mux_280;
    wire [15:0] signal_mux_281;
    wire [15:0] signal_mux_282;
    wire [15:0] signal_select_39;
    reg [15:0] signal_cases_58;
    wire [15:0] signal_mux_283;
    wire [15:0] signal_mux_284;
    wire [15:0] signal_mux_285;
    wire [15:0] signal_mux_286;
    wire [15:0] signal_mux_287;
    wire [15:0] signal_mux_288;
    wire [15:0] signal_mux_289;
    wire [15:0] signal_mux_290;
    wire [15:0] signal_mux_291;
    reg [15:0] signal_cases_59;
    wire [15:0] signal_wire_35;
    reg [15:0] row$y_lo;
    wire [25:0] signal_cat_49;
    wire [25:0] signal_mux_292;
    wire [25:0] signal_mux_293;
    wire signal_or_39;
    wire [25:0] signal_mux_294;
    wire [25:0] signal_sub_9;
    wire [25:0] signal_const_193;
    wire [25:0] signal_const_194;
    wire [25:0] signal_cat_50;
    wire [25:0] signal_sub_10;
    wire [25:0] signal_const_197;
    wire [24:0] signal_select_40;
    wire signal_select_41;
    wire signal_not_107;
    wire [25:0] signal_cat_51;
    wire signal_lt_31;
    wire [25:0] signal_mux_295;
    wire [24:0] signal_select_42;
    wire [23:0] fell$offset_hi;
    wire [23:0] signal_mux_296;
    wire [23:0] signal_mux_297;
    wire [23:0] signal_mux_298;
    wire [23:0] signal_mux_299;
    wire [23:0] signal_mux_300;
    wire [23:0] signal_mux_301;
    wire [23:0] signal_mux_302;
    wire [23:0] signal_mux_303;
    reg [23:0] signal_cases_60;
    wire [23:0] signal_wire_36;
    reg [23:0] row$offset_hi;
    wire signal_select_43;
    wire [1:0] signal_cat_52;
    wire [25:0] signal_cat_53;
    wire signal_select_44;
    wire signal_not_108;
    wire [25:0] signal_cat_54;
    wire [24:0] signal_select_45;
    wire signal_select_46;
    wire signal_not_109;
    wire [25:0] signal_cat_55;
    wire signal_lt_32;
    wire [25:0] signal_mux_304;
    wire [25:0] signal_mux_305;
    wire [25:0] signal_mux_306;
    wire [25:0] signal_mux_307;
    wire [25:0] signal_mux_308;
    wire [25:0] signal_add_24;
    wire signal_select_47;
    wire signal_not_110;
    wire [25:0] signal_cat_56;
    wire signal_lt_33;
    wire signal_not_111;
    wire [24:0] signal_select_48;
    wire [15:0] signal_wire_37;
    wire signal_eq_43;
    wire signal_not_112;
    wire signal_and_30;
    wire [24:0] signal_const_204;
    wire [25:0] signal_cat_57;
    wire [15:0] signal_wire_38;
    reg [15:0] setup$loaded$value_0;
    wire [15:0] signal_mux_309;
    wire signal_eq_44;
    wire signal_eq_45;
    wire signal_and_31;
    wire [15:0] signal_mux_310;
    wire signal_wire_39;
    reg setup$loaded$valid_0;
    wire signal_not_113;
    wire [1:0] signal_const_209;
    wire signal_eq_46;
    wire signal_eq_47;
    wire signal_and_32;
    wire signal_eq_48;
    wire signal_eq_49;
    wire signal_and_33;
    wire signal_eq_50;
    wire signal_eq_51;
    wire signal_and_34;
    wire signal_or_40;
    wire signal_or_41;
    wire signal_and_35;
    wire signal_not_114;
    wire [15:0] signal_mux_311;
    wire [15:0] fell$period_hi;
    wire [15:0] signal_mux_312;
    wire [15:0] signal_mux_313;
    wire [15:0] signal_mux_314;
    wire [15:0] signal_mux_315;
    reg [15:0] signal_cases_61;
    wire [15:0] signal_mux_316;
    wire [15:0] signal_mux_317;
    wire [15:0] signal_mux_318;
    wire [15:0] signal_mux_319;
    wire [15:0] signal_mux_320;
    wire [15:0] signal_mux_321;
    wire [15:0] signal_mux_322;
    wire [15:0] signal_mux_323;
    wire [15:0] signal_const_217;
    wire [15:0] signal_mux_324;
    reg [15:0] signal_cases_62;
    wire [15:0] signal_wire_40;
    reg [15:0] row$period_hi;
    wire [25:0] signal_cat_58;
    wire [25:0] signal_add_25;
    wire [4:0] signal_select_49;
    wire [10:0] signal_const_219;
    wire [15:0] signal_cat_59;
    wire [15:0] signal_sub_11;
    wire [15:0] signal_mux_325;
    wire signal_lt_34;
    wire [15:0] signal_mux_326;
    wire signal_not_115;
    wire signal_and_36;
    wire [15:0] signal_mux_327;
    wire [15:0] signal_mux_328;
    wire [2:0] signal_select_50;
    wire signal_eq_52;
    wire signal_eq_53;
    wire signal_and_37;
    wire [15:0] signal_mux_329;
    wire signal_eq_54;
    wire signal_eq_55;
    wire signal_and_38;
    wire signal_eq_56;
    wire signal_eq_57;
    wire signal_and_39;
    wire signal_eq_58;
    wire signal_eq_59;
    wire signal_and_40;
    wire signal_or_42;
    wire signal_or_43;
    wire signal_not_116;
    wire [15:0] signal_mux_330;
    wire [15:0] fell$x_hi;
    wire [15:0] signal_mux_331;
    wire [15:0] signal_mux_332;
    wire [15:0] signal_mux_333;
    wire [15:0] signal_mux_334;
    reg [15:0] signal_cases_63;
    wire [15:0] signal_mux_335;
    wire [15:0] signal_mux_336;
    wire [15:0] signal_mux_337;
    wire [15:0] signal_mux_338;
    wire [15:0] signal_mux_339;
    wire [15:0] signal_mux_340;
    wire [15:0] signal_mux_341;
    wire [15:0] signal_mux_342;
    wire [15:0] signal_mux_343;
    reg [15:0] signal_cases_64;
    wire [15:0] signal_wire_41;
    reg [15:0] row$x_hi;
    wire [25:0] signal_cat_60;
    wire [25:0] signal_cat_61;
    wire [20:0] signal_const_235;
    wire [23:0] signal_cat_62;
    wire [25:0] signal_cat_63;
    wire [25:0] signal_sub_12;
    wire [25:0] signal_mux_344;
    wire [25:0] signal_mux_345;
    wire signal_eq_60;
    wire signal_and_41;
    wire signal_and_42;
    wire signal_and_43;
    wire [25:0] signal_mux_346;
    wire signal_eq_61;
    wire signal_and_44;
    wire signal_and_45;
    wire signal_and_46;
    wire [25:0] signal_mux_347;
    wire signal_eq_62;
    wire signal_and_47;
    wire signal_and_48;
    wire signal_and_49;
    wire signal_and_50;
    wire signal_or_44;
    wire [25:0] signal_mux_348;
    wire [25:0] signal_cat_64;
    wire [25:0] signal_sub_13;
    wire [24:0] signal_select_51;
    wire signal_select_52;
    wire signal_not_117;
    wire [25:0] signal_cat_65;
    wire signal_lt_35;
    wire [25:0] signal_mux_349;
    wire [24:0] signal_select_53;
    wire signal_select_54;
    wire signal_not_118;
    wire [25:0] signal_cat_66;
    wire [24:0] signal_select_55;
    wire [23:0] fell$offset_lo;
    wire [23:0] signal_mux_350;
    wire [23:0] signal_mux_351;
    wire [23:0] signal_mux_352;
    wire [23:0] signal_mux_353;
    wire [23:0] signal_mux_354;
    wire [23:0] signal_mux_355;
    wire [23:0] signal_mux_356;
    wire [23:0] signal_mux_357;
    reg [23:0] signal_cases_65;
    wire [23:0] signal_wire_42;
    reg [23:0] row$offset_lo;
    wire signal_select_56;
    wire [1:0] signal_cat_67;
    wire [25:0] signal_cat_68;
    wire signal_select_57;
    wire signal_not_119;
    wire [25:0] signal_cat_69;
    wire signal_lt_36;
    wire [25:0] signal_mux_358;
    wire signal_not_120;
    wire signal_and_51;
    wire [25:0] signal_mux_359;
    wire [25:0] signal_mux_360;
    wire [25:0] signal_mux_361;
    wire [25:0] signal_mux_362;
    wire [25:0] signal_add_26;
    wire signal_select_58;
    wire signal_not_121;
    wire [25:0] signal_cat_70;
    wire signal_lt_37;
    wire signal_not_122;
    wire signal_and_52;
    wire signal_eq_63;
    wire [24:0] signal_select_59;
    wire signal_select_60;
    wire [1:0] signal_cat_71;
    wire [25:0] signal_cat_72;
    wire [25:0] signal_sub_14;
    wire signal_select_61;
    wire signal_not_123;
    wire [25:0] signal_cat_73;
    wire signal_lt_38;
    wire [25:0] signal_mux_363;
    wire [25:0] signal_cat_74;
    wire [25:0] signal_add_27;
    wire [25:0] signal_add_28;
    wire [25:0] signal_cat_75;
    wire [25:0] signal_add_29;
    wire [25:0] signal_mux_364;
    wire [25:0] signal_mux_365;
    wire [23:0] signal_select_62;
    wire [25:0] signal_const_258;
    wire [24:0] signal_select_63;
    wire [23:0] signal_const_261;
    wire [23:0] signal_mux_366;
    wire [23:0] signal_mux_367;
    wire [23:0] signal_mux_368;
    wire [23:0] signal_mux_369;
    reg [23:0] signal_cases_66;
    wire [23:0] signal_mux_370;
    wire [23:0] signal_mux_371;
    wire [23:0] signal_mux_372;
    wire [23:0] signal_mux_373;
    wire [23:0] signal_mux_374;
    wire [23:0] signal_mux_375;
    wire [23:0] signal_mux_376;
    wire [23:0] signal_mux_377;
    wire [23:0] signal_mux_378;
    reg [23:0] signal_cases_67;
    wire [23:0] signal_wire_43;
    reg [23:0] row$phase_lo;
    wire signal_select_64;
    wire [1:0] signal_cat_76;
    wire [25:0] signal_cat_77;
    wire [25:0] signal_sub_15;
    wire signal_select_65;
    wire signal_not_124;
    wire [25:0] signal_cat_78;
    wire signal_lt_39;
    wire [25:0] signal_mux_379;
    wire [25:0] signal_cat_79;
    wire [25:0] signal_add_30;
    wire [25:0] signal_add_31;
    wire [23:0] signal_const_265;
    wire [4:0] signal_and_53;
    wire [4:0] signal_and_54;
    wire [4:0] signal_and_55;
    wire [4:0] signal_select_66;
    wire [1:0] signal_wire_44;
    reg [4:0] signal_mux_380;
    wire [18:0] signal_const_270;
    wire [23:0] signal_cat_80;
    wire [23:0] signal_add_32;
    wire [23:0] signal_mux_381;
    wire [25:0] signal_cat_81;
    wire [23:0] signal_select_67;
    wire [23:0] signal_mux_382;
    wire [23:0] fell$arm_hi;
    wire [23:0] signal_mux_383;
    wire [23:0] signal_mux_384;
    wire [23:0] signal_mux_385;
    wire [23:0] signal_mux_386;
    reg [23:0] signal_cases_68;
    wire [23:0] signal_mux_387;
    wire [23:0] signal_mux_388;
    wire [23:0] signal_mux_389;
    wire [23:0] signal_mux_390;
    wire [23:0] signal_mux_391;
    wire [23:0] signal_mux_392;
    wire [23:0] signal_mux_393;
    wire [23:0] signal_mux_394;
    wire [23:0] signal_mux_395;
    reg [23:0] signal_cases_69;
    wire [23:0] signal_wire_45;
    reg [23:0] row$arm_hi;
    wire [25:0] signal_cat_82;
    wire [25:0] signal_add_33;
    wire [25:0] signal_mux_396;
    wire [25:0] signal_mux_397;
    wire signal_lt_40;
    wire signal_not_125;
    wire signal_not_126;
    wire signal_eq_64;
    wire signal_and_56;
    wire signal_and_57;
    wire signal_not_127;
    wire signal_and_58;
    wire signal_and_59;
    wire signal_or_45;
    wire [23:0] signal_mux_398;
    wire [23:0] fell$arm_lo;
    wire [23:0] signal_mux_399;
    wire [23:0] signal_mux_400;
    wire [23:0] signal_mux_401;
    wire [23:0] signal_mux_402;
    wire [23:0] signal_select_68;
    reg [23:0] signal_cases_70;
    wire [23:0] signal_mux_403;
    wire [23:0] signal_mux_404;
    wire [23:0] signal_mux_405;
    wire [23:0] signal_mux_406;
    wire [23:0] signal_mux_407;
    wire [23:0] signal_mux_408;
    wire [23:0] signal_mux_409;
    wire [23:0] signal_mux_410;
    wire [23:0] signal_mux_411;
    reg [23:0] signal_cases_71;
    wire [23:0] signal_wire_46;
    reg [23:0] row$arm_lo;
    wire signal_eq_65;
    wire signal_and_60;
    wire signal_not_128;
    wire signal_not_129;
    wire signal_and_61;
    wire signal_mux_412;
    wire fell$awaiting;
    wire signal_mux_413;
    wire signal_mux_414;
    wire signal_mux_415;
    wire signal_mux_416;
    wire arriving$awaiting;
    wire signal_mux_417;
    wire signal_mux_418;
    wire signal_mux_419;
    wire signal_mux_420;
    reg signal_cases_72;
    wire signal_wire_47;
    reg row$awaiting;
    wire signal_wire_48;
    wire signal_select_69;
    wire signal_eq_66;
    wire [4:0] signal_wire_49;
    wire [4:0] signal_select_70;
    wire signal_eq_67;
    wire signal_eq_68;
    wire signal_and_62;
    wire signal_wire_50;
    reg setup$single_edge_0;
    wire signal_eq_69;
    wire signal_eq_70;
    wire signal_or_46;
    wire signal_eq_71;
    wire signal_and_63;
    wire signal_and_64;
    wire signal_and_65;
    wire signal_and_66;
    wire signal_and_67;
    wire signal_and_68;
    wire signal_or_47;
    wire [3:0] signal_select_71;
    wire signal_eq_72;
    wire signal_eq_73;
    wire signal_and_69;
    wire signal_mux_421;
    wire fell$captured;
    wire signal_mux_422;
    wire signal_mux_423;
    wire signal_mux_424;
    wire signal_mux_425;
    wire [45:0] signal_select_72;
    wire arriving$captured;
    wire signal_mux_426;
    wire signal_mux_427;
    wire signal_mux_428;
    wire signal_mux_429;
    reg signal_cases_73;
    wire signal_wire_51;
    reg row$captured;
    wire signal_eq_74;
    wire signal_eq_75;
    wire signal_and_70;
    wire signal_and_71;
    wire signal_and_72;
    wire signal_and_73;
    wire signal_not_130;
    wire signal_eq_76;
    wire signal_and_74;
    wire signal_and_75;
    wire signal_eq_77;
    wire signal_and_76;
    wire signal_and_77;
    wire signal_and_78;
    wire signal_eq_78;
    wire signal_and_79;
    wire signal_and_80;
    wire signal_and_81;
    wire [2:0] signal_select_73;
    wire signal_eq_79;
    wire signal_and_82;
    wire signal_and_83;
    wire signal_and_84;
    wire signal_select_74;
    wire signal_not_131;
    wire [1:0] signal_select_75;
    wire signal_eq_80;
    wire signal_and_85;
    wire signal_and_86;
    wire signal_or_48;
    wire signal_or_49;
    wire signal_or_50;
    wire signal_or_51;
    wire signal_not_132;
    wire [1:0] signal_select_76;
    wire signal_eq_81;
    wire signal_eq_82;
    wire signal_and_87;
    wire signal_and_88;
    wire [2:0] signal_select_77;
    wire signal_eq_83;
    wire signal_eq_84;
    wire signal_and_89;
    wire [2:0] signal_select_78;
    wire signal_eq_85;
    wire [1:0] signal_select_79;
    wire signal_eq_86;
    wire signal_and_90;
    wire signal_and_91;
    wire signal_not_133;
    wire [2:0] signal_select_80;
    wire signal_eq_87;
    wire signal_eq_88;
    wire signal_and_92;
    wire signal_and_93;
    wire [1:0] signal_select_81;
    wire signal_eq_89;
    wire signal_eq_90;
    wire signal_and_94;
    wire signal_not_134;
    wire signal_eq_91;
    wire signal_and_95;
    wire signal_or_52;
    wire signal_or_53;
    wire signal_or_54;
    wire signal_not_135;
    wire signal_or_55;
    wire signal_and_96;
    wire signal_and_97;
    wire signal_and_98;
    wire [25:0] signal_const_308;
    wire [23:0] signal_select_82;
    wire signal_select_83;
    wire [1:0] signal_cat_83;
    wire [25:0] signal_cat_84;
    wire signal_eq_92;
    wire [25:0] signal_const_309;
    wire [23:0] signal_select_84;
    wire signal_select_85;
    wire [1:0] signal_cat_85;
    wire [25:0] signal_cat_86;
    wire signal_eq_93;
    wire signal_and_99;
    wire signal_or_56;
    wire signal_eq_94;
    wire signal_not_136;
    wire signal_and_100;
    wire signal_not_137;
    wire signal_or_57;
    wire way$phase;
    wire signal_not_138;
    reg signal_cases_74;
    wire signal_eq_95;
    wire signal_mux_430;
    wire signal_mux_431;
    reg signal_cases_75;
    wire signal_wire_52;
    reg failed_target$phase;
    wire signal_not_139;
    wire signal_and_101;
    wire signal_and_102;
    wire signal_and_103;
    wire signal_and_104;
    wire signal_and_105;
    wire signal_and_106;
    wire signal_and_107;
    wire signal_and_108;
    wire signal_and_109;
    wire target_fails;
    wire [15:0] signal_mux_432;
    wire [15:0] signal_mux_433;
    wire [15:0] signal_select_86;
    reg [15:0] signal_cases_76;
    wire [15:0] signal_mux_434;
    wire [15:0] signal_mux_435;
    wire [15:0] signal_mux_436;
    wire [15:0] signal_mux_437;
    wire [15:0] signal_mux_438;
    wire [15:0] signal_mux_439;
    wire [15:0] signal_mux_440;
    wire [15:0] signal_mux_441;
    wire [15:0] signal_mux_442;
    reg [15:0] signal_cases_77;
    wire [15:0] signal_wire_53;
    reg [15:0] row$y_hi;
    wire signal_lt_41;
    wire signal_not_140;
    wire signal_and_110;
    wire signal_eq_96;
    wire signal_and_111;
    wire signal_mux_443;
    wire [3:0] signal_const_315;
    wire signal_eq_97;
    wire signal_and_112;
    wire signal_mux_444;
    wire signal_eq_98;
    wire signal_and_113;
    wire signal_mux_445;
    wire [3:0] signal_select_87;
    wire signal_eq_99;
    wire signal_and_114;
    wire signal_mux_446;
    wire [2:0] signal_select_88;
    wire signal_eq_100;
    wire signal_not_141;
    wire signal_or_58;
    wire signal_and_115;
    wire [23:0] fell$phase_lo;
    wire [47:0] signal_cat_87;
    reg [47:0] signal_mux_447;
    wire [47:0] signal_const_319;
    wire [47:0] signal_const_323;
    reg [47:0] signal_mux_448;
    wire signal_eq_101;
    wire [47:0] signal_mux_449;
    wire signal_eq_102;
    wire [47:0] stand_in;
    wire signal_eq_103;
    wire [47:0] signal_mux_450;
    wire [47:0] signal_mux_451;
    wire [47:0] signal_mux_452;
    reg [47:0] signal_cases_78;
    wire [47:0] signal_wire_54;
    reg [47:0] acc;
    wire [31:0] signal_select_89;
    wire [47:0] shifted;
    wire [23:0] signal_select_90;
    reg [23:0] signal_cases_79;
    wire signal_eq_104;
    wire [23:0] signal_mux_453;
    wire signal_eq_105;
    wire signal_eq_106;
    wire wide;
    wire last_word;
    wire [23:0] signal_mux_454;
    wire [23:0] signal_mux_455;
    wire [6:0] held$y;
    wire [6:0] held$x;
    wire [6:0] held$period;
    wire [6:0] held$arm;
    wire [31:0] signal_select_91;
    wire [47:0] entry_shifted;
    wire [47:0] signal_mux_456;
    reg [47:0] signal_cases_80;
    wire [47:0] signal_wire_55;
    reg [47:0] entry;
    wire [45:0] signal_select_92;
    wire [6:0] held$phase;
    reg [6:0] index;
    wire signal_eq_107;
    wire signal_not_142;
    wire [1:0] signal_mux_457;
    wire [1:0] signal_mux_458;
    wire [1:0] signal_mux_459;
    wire [1:0] signal_mux_460;
    wire [1:0] signal_mux_461;
    reg [1:0] signal_cases_81;
    wire [1:0] signal_wire_56;
    (* fsm_encoding="one_hot" *)
    reg [1:0] source;
    wire signal_eq_108;
    wire from_dictionary;
    wire [23:0] signal_mux_462;
    wire [23:0] signal_mux_463;
    wire signal_eq_109;
    wire [23:0] signal_mux_464;
    wire signal_eq_110;
    wire [23:0] signal_mux_465;
    wire [23:0] signal_mux_466;
    wire [23:0] signal_mux_467;
    reg [23:0] signal_cases_82;
    wire [23:0] signal_wire_57;
    reg [23:0] row$phase_hi;
    wire signal_select_93;
    wire signal_not_143;
    wire [23:0] signal_cat_88;
    wire signal_lt_42;
    wire signal_or_59;
    wire signal_or_60;
    wire signal_or_61;
    wire signal_or_62;
    wire signal_not_144;
    wire signal_and_116;
    wire signal_not_145;
    wire signal_or_63;
    wire signal_or_64;
    wire signal_and_117;
    wire signal_and_118;
    wire signal_and_119;
    wire signal_and_120;
    wire signal_and_121;
    wire signal_and_122;
    wire signal_and_123;
    wire signal_and_124;
    wire signal_and_125;
    wire signal_and_126;
    wire next_fails;
    wire [2:0] signal_mux_468;
    wire signal_wire_58;
    wire signal_wire_59;
    wire [9:0] signal_const_341;
    wire [9:0] signal_cat_89;
    wire [9:0] next_pc;
    wire [9:0] signal_cat_90;
    wire signal_eq_111;
    wire signal_mux_469;
    wire signal_mux_470;
    reg signal_cases_83;
    wire signal_wire_60;
    reg stored;
    wire [2:0] signal_mux_471;
    wire [2:0] signal_mux_472;
    wire [2:0] signal_mux_473;
    reg [2:0] signal_cases_84;
    wire [2:0] signal_wire_61;
    (* fsm_encoding="one_hot" *)
    reg [2:0] purpose;
    reg [8:0] signal_cases_85;
    wire [8:0] signal_mux_474;
    wire [8:0] signal_mux_475;
    reg [8:0] signal_cases_86;
    wire [8:0] signal_wire_62;
    reg [8:0] pc;
    wire signal_eq_112;
    wire [8:0] following;
    wire gnd;
    wire [9:0] signal_cat_91;
    wire falls_to_next;
    wire [8:0] signal_mux_476;
    wire [8:0] jump_target;
    wire [8:0] signal_mux_477;
    reg [8:0] signal_cases_87;
    wire [8:0] signal_wire_63;
    reg [8:0] key;
    wire [15:0] signal_wire_64;
    wire [8:0] entry_tag;
    wire signal_eq_113;
    wire [1:0] signal_mux_478;
    wire [1:0] signal_mux_479;
    wire [1:0] signal_mux_480;
    wire [1:0] signal_add_34;
    wire [1:0] signal_mux_481;
    wire [1:0] signal_add_35;
    wire signal_eq_114;
    wire [1:0] signal_mux_482;
    wire [1:0] signal_mux_483;
    wire [1:0] signal_mux_484;
    reg [1:0] signal_cases_88;
    wire [1:0] signal_wire_65;
    reg [1:0] k;
    wire signal_eq_115;
    wire [15:0] signal_mux_485;
    reg [15:0] signal_cases_89;
    wire [15:0] signal_wire_66;
    reg [15:0] word;
    wire [2:0] signal_select_94;
    wire is_jump;
    wire [7:0] signal_mux_486;
    reg [7:0] signal_cases_90;
    wire [7:0] signal_wire_67;
    reg [7:0] lo;
    wire signal_lt_43;
    wire signal_not_146;
    wire [2:0] signal_mux_487;
    reg [2:0] signal_cases_91;
    wire [2:0] signal_wire_68;
    reg [2:0] field;
    wire signal_eq_116;
    wire [7:0] signal_mux_488;
    wire [7:0] signal_mux_489;
    reg [7:0] signal_cases_92;
    wire [7:0] signal_wire_69;
    reg [7:0] ptr;
    wire signal_lt_44;
    wire signal_mux_490;
    wire vdd;
    reg signal_cases_93;
    wire reading;
    wire signal_and_127;
    wire [1:0] signal_mux_491;
    wire [1:0] signal_wire_70;
    reg [1:0] \wait ;
    wire read_done;
    wire [3:0] signal_mux_492;
    wire signal_wire_71;
    wire [3:0] signal_mux_493;
    reg [3:0] signal_cases_94;
    wire signal_eq_117;
    wire signal_not_147;
    wire signal_wire_72;
    wire signal_and_128;
    wire [3:0] signal_mux_494;
    wire [3:0] signal_wire_73;
    (* fsm_encoding="one_hot" *)
    reg [3:0] sm;
    wire signal_eq_118;
    assign signal_const = 5'b00000;
    assign signal_const_1 = 5'b11101;
    assign signal_const_2 = 5'b11111;
    assign signal_mux = signal_eq_1 ? reason_0 : signal_const_2;
    assign signal_const_4 = 5'b00001;
    assign signal_mux_1 = signal_not_10 ? signal_const : signal_const_4;
    assign signal_const_5 = 5'b00011;
    assign signal_mux_2 = signal_not_10 ? signal_mux_1 : signal_const_5;
    assign signal_const_6 = 5'b00100;
    assign signal_const_7 = 5'b00101;
    assign signal_mux_3 = signal_not_8 ? signal_const_6 : signal_const_7;
    assign signal_const_8 = 5'b00110;
    assign signal_const_9 = 5'b00111;
    assign signal_mux_4 = signal_not_6 ? signal_const_8 : signal_const_9;
    assign signal_mux_5 = signal_or_5 ? signal_mux_3 : signal_mux_4;
    assign signal_mux_6 = signal_or_7 ? signal_mux_2 : signal_mux_5;
    assign signal_const_10 = 5'b01000;
    assign signal_const_11 = 5'b01001;
    assign signal_mux_7 = signal_not_4 ? signal_const_10 : signal_const_11;
    assign signal_const_12 = 5'b01010;
    assign signal_const_13 = 5'b01011;
    assign signal_mux_8 = signal_not_2 ? signal_const_12 : signal_const_13;
    assign signal_mux_9 = signal_or_1 ? signal_mux_7 : signal_mux_8;
    assign signal_const_14 = 5'b01100;
    assign signal_const_15 = 5'b01101;
    assign signal_mux_10 = signal_not ? signal_const_14 : signal_const_15;
    assign signal_const_16 = 5'b01111;
    assign signal_mux_11 = signal_not ? signal_mux_10 : signal_const_16;
    assign signal_mux_12 = signal_or_2 ? signal_mux_9 : signal_mux_11;
    assign signal_mux_13 = signal_or_8 ? signal_mux_6 : signal_mux_12;
    assign signal_const_17 = 5'b10110;
    assign signal_mux_14 = signal_or_9 ? signal_mux_13 : signal_const_17;
    assign signal_not = ~ signal_not_24;
    assign signal_not_1 = ~ signal_not_25;
    assign signal_not_2 = ~ signal_not_27;
    assign signal_or = signal_not_2 | signal_not_1;
    assign signal_not_3 = ~ signal_not_29;
    assign signal_not_4 = ~ signal_not_31;
    assign signal_or_1 = signal_not_4 | signal_not_3;
    assign signal_or_2 = signal_or_1 | signal_or;
    assign signal_or_3 = signal_or_2 | signal_not;
    assign signal_not_5 = ~ signal_not_33;
    assign signal_not_6 = ~ signal_not_35;
    assign signal_or_4 = signal_not_6 | signal_not_5;
    assign signal_not_7 = ~ signal_not_37;
    assign signal_not_8 = ~ signal_not_38;
    assign signal_or_5 = signal_not_8 | signal_not_7;
    assign signal_or_6 = signal_or_5 | signal_or_4;
    assign signal_not_9 = ~ signal_not_40;
    assign signal_not_10 = ~ signal_or_64;
    assign signal_or_7 = signal_not_10 | signal_not_9;
    assign signal_or_8 = signal_or_7 | signal_or_6;
    assign signal_or_9 = signal_or_8 | signal_or_3;
    assign next_reason = signal_or_9 ? signal_mux_14 : signal_const;
    assign signal_const_20 = 5'b01110;
    assign signal_mux_15 = signal_not_19 ? signal_const_20 : signal_const_16;
    assign signal_mux_16 = signal_not_20 ? signal_const_15 : signal_mux_15;
    assign signal_const_22 = 5'b10000;
    assign signal_const_23 = 5'b10001;
    assign signal_mux_17 = signal_not_17 ? signal_const_22 : signal_const_23;
    assign signal_const_24 = 5'b10010;
    assign signal_const_25 = 5'b10011;
    assign signal_mux_18 = signal_not_15 ? signal_const_24 : signal_const_25;
    assign signal_mux_19 = signal_or_13 ? signal_mux_17 : signal_mux_18;
    assign signal_const_26 = 5'b10100;
    assign signal_const_27 = 5'b10101;
    assign signal_mux_20 = signal_not_13 ? signal_const_26 : signal_const_27;
    assign signal_mux_21 = signal_or_10 ? signal_mux_20 : signal_const_17;
    assign signal_mux_22 = signal_or_14 ? signal_mux_19 : signal_mux_21;
    assign signal_mux_23 = signal_or_17 ? signal_mux_16 : signal_mux_22;
    assign signal_not_11 = ~ signal_not_55;
    assign signal_not_12 = ~ signal_not_56;
    assign signal_not_13 = ~ signal_not_61;
    assign signal_or_10 = signal_not_13 | signal_not_12;
    assign signal_or_11 = signal_or_10 | signal_not_11;
    assign signal_not_14 = ~ signal_not_66;
    assign signal_not_15 = ~ signal_not_72;
    assign signal_or_12 = signal_not_15 | signal_not_14;
    assign signal_not_16 = ~ signal_not_79;
    assign signal_not_17 = ~ signal_not_86;
    assign signal_or_13 = signal_not_17 | signal_not_16;
    assign signal_or_14 = signal_or_13 | signal_or_12;
    assign signal_or_15 = signal_or_14 | signal_or_11;
    assign signal_not_18 = ~ signal_not_93;
    assign signal_not_19 = ~ signal_not_94;
    assign signal_or_16 = signal_not_19 | signal_not_18;
    assign signal_not_20 = ~ signal_not_139;
    assign signal_or_17 = signal_not_20 | signal_or_16;
    assign signal_or_18 = signal_or_17 | signal_or_15;
    assign target_reason = signal_or_18 ? signal_mux_23 : signal_const;
    assign signal_mux_24 = target_fails ? target_reason : reason_0;
    assign signal_mux_25 = next_fails ? next_reason : signal_mux_24;
    assign signal_const_30 = 5'b11110;
    assign signal_mux_26 = signal_not_22 ? signal_const_30 : reason_0;
    assign signal_mux_27 = read_done ? signal_mux_26 : reason_0;
    assign signal_mux_28 = signal_lt_44 ? signal_mux_27 : reason_0;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases <= signal_mux_28;
        4'b1010:
            signal_cases <= signal_mux_25;
        4'b1011:
            signal_cases <= signal_mux;
        default:
            signal_cases <= reason_0;
        endcase
    end
    assign signal_mux_29 = signal_and_128 ? signal_const_1 : signal_cases;
    assign signal_wire = signal_mux_29;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            reason_0 <= signal_const;
        else
            reason_0 <= signal_wire;
    end
    assign signal_const_31 = 10'b0000000000;
    assign signal_cat = { gnd,
                          pc };
    assign signal_const_32 = 10'b1000000000;
    assign signal_mux_30 = signal_eq_1 ? reject_pc_0 : signal_const_32;
    assign signal_cat_1 = { gnd,
                            pc };
    assign signal_cat_2 = { gnd,
                            pc };
    assign signal_mux_31 = target_fails ? signal_cat_2 : reject_pc_0;
    assign signal_mux_32 = next_fails ? signal_cat_1 : signal_mux_31;
    assign signal_cat_3 = { gnd,
                            pc };
    assign signal_mux_33 = signal_not_22 ? signal_cat_3 : reject_pc_0;
    assign signal_mux_34 = read_done ? signal_mux_33 : reject_pc_0;
    assign signal_mux_35 = signal_lt_44 ? signal_mux_34 : reject_pc_0;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_1 <= signal_mux_35;
        4'b1010:
            signal_cases_1 <= signal_mux_32;
        4'b1011:
            signal_cases_1 <= signal_mux_30;
        default:
            signal_cases_1 <= reject_pc_0;
        endcase
    end
    assign signal_mux_36 = signal_and_128 ? signal_cat : signal_cases_1;
    assign signal_wire_1 = signal_mux_36;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            reject_pc_0 <= signal_const_31;
        else
            reject_pc_0 <= signal_wire_1;
    end
    assign signal_const_33 = 1'b0;
    assign signal_mux_37 = signal_eq_1 ? vdd : gnd;
    assign signal_mux_38 = target_fails ? gnd : accepted_0;
    assign signal_mux_39 = next_fails ? gnd : signal_mux_38;
    assign signal_mux_40 = signal_not_22 ? gnd : accepted_0;
    assign signal_mux_41 = read_done ? signal_mux_40 : accepted_0;
    assign signal_mux_42 = signal_lt_44 ? signal_mux_41 : accepted_0;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_2 <= signal_mux_42;
        4'b1010:
            signal_cases_2 <= signal_mux_39;
        4'b1011:
            signal_cases_2 <= signal_mux_37;
        default:
            signal_cases_2 <= accepted_0;
        endcase
    end
    assign signal_mux_43 = signal_and_128 ? gnd : signal_cases_2;
    assign signal_wire_2 = signal_mux_43;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            accepted_0 <= signal_const_33;
        else
            accepted_0 <= signal_wire_2;
    end
    assign signal_mux_44 = signal_eq_1 ? vdd : vdd;
    assign signal_mux_45 = target_fails ? vdd : gnd;
    assign signal_mux_46 = next_fails ? vdd : signal_mux_45;
    assign signal_mux_47 = signal_not_22 ? vdd : gnd;
    assign signal_mux_48 = read_done ? signal_mux_47 : gnd;
    assign signal_mux_49 = signal_lt_44 ? signal_mux_48 : gnd;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_3 <= signal_mux_49;
        4'b1010:
            signal_cases_3 <= signal_mux_46;
        4'b1011:
            signal_cases_3 <= signal_mux_44;
        default:
            signal_cases_3 <= gnd;
        endcase
    end
    assign signal_mux_50 = signal_and_128 ? vdd : signal_cases_3;
    assign signal_wire_3 = signal_mux_50;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            finished_0 <= signal_const_33;
        else
            finished_0 <= signal_wire_3;
    end
    assign signal_eq = signal_const_57 == sm;
    assign signal_not_21 = ~ signal_eq;
    assign signal_const_35 = 9'b000000000;
    assign signal_const_36 = 7'b0000000;
    assign signal_cat_4 = { signal_const_36,
                            k };
    assign signal_select = signal_cat_6[7:0];
    assign signal_cat_5 = { signal_select,
                            signal_const_33 };
    assign signal_const_38 = 7'b0000001;
    assign signal_sub = index - signal_const_38;
    assign signal_const_39 = 2'b00;
    assign signal_cat_6 = { signal_const_39,
                            signal_sub };
    assign signal_add = signal_cat_6 + signal_cat_5;
    assign signal_add_1 = wide_at + signal_add;
    assign signal_sub_1 = index - signal_const_38;
    assign signal_cat_7 = { signal_const_39,
                            signal_sub_1 };
    assign signal_select_1 = signal_cat_7[7:0];
    assign signal_cat_8 = { signal_select_1,
                            signal_const_33 };
    assign signal_select_2 = signal_cat_10[7:0];
    assign signal_cat_9 = { signal_select_2,
                            signal_const_33 };
    assign signal_const_44 = 8'b00000000;
    assign signal_select_3 = signal_wire_64[7:0];
    assign signal_mux_51 = signal_eq_3 ? wide_count : signal_select_3;
    assign signal_mux_52 = read_done ? signal_mux_51 : wide_count;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_4 <= signal_mux_52;
        default:
            signal_cases_4 <= wide_count;
        endcase
    end
    assign signal_wire_4 = signal_cases_4;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            wide_count <= signal_const_44;
        else
            wide_count <= signal_wire_4;
    end
    assign signal_cat_10 = { gnd,
                             wide_count };
    assign signal_add_2 = signal_cat_10 + signal_cat_9;
    assign signal_select_4 = signal_cat_12[7:0];
    assign signal_cat_11 = { signal_select_4,
                             signal_const_33 };
    assign signal_cat_12 = { gnd,
                             count };
    assign signal_add_3 = signal_cat_12 + signal_cat_11;
    assign wide_at = entries_at + signal_add_3;
    assign narrow_at = wide_at + signal_add_2;
    assign signal_add_4 = narrow_at + signal_cat_8;
    assign signal_mux_53 = wide ? signal_add_1 : signal_add_4;
    assign interval_at = signal_mux_53 + signal_cat_4;
    assign signal_mux_54 = from_dictionary ? interval_at : signal_const_35;
    assign signal_mux_55 = signal_eq_116 ? signal_const_35 : signal_mux_54;
    assign signal_cat_13 = { signal_const_36,
                             k };
    assign signal_select_5 = signal_cat_15[7:0];
    assign signal_cat_14 = { signal_select_5,
                             signal_const_33 };
    assign signal_mux_56 = stored ? ptr : sel;
    assign signal_mux_57 = target_fails ? sel : signal_mux_56;
    assign signal_mux_58 = next_fails ? sel : signal_mux_57;
    assign signal_mux_59 = stored ? ptr : sel;
    assign signal_mux_60 = falls_to_next ? signal_mux_59 : sel;
    assign signal_mux_61 = signal_eq_113 ? mid : sel;
    assign signal_mux_62 = read_done ? signal_mux_61 : sel;
    assign signal_mux_63 = signal_not_146 ? sel : signal_mux_62;
    always @* begin
        case (sm)
        4'b0101:
            signal_cases_5 <= signal_mux_63;
        4'b1001:
            signal_cases_5 <= signal_mux_60;
        4'b1010:
            signal_cases_5 <= signal_mux_58;
        default:
            signal_cases_5 <= sel;
        endcase
    end
    assign signal_wire_5 = signal_cases_5;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            sel <= signal_const_44;
        else
            sel <= signal_wire_5;
    end
    assign signal_cat_15 = { gnd,
                             sel };
    assign signal_add_5 = signal_cat_15 + signal_cat_14;
    assign signal_add_6 = entries_at + signal_add_5;
    assign signal_add_7 = signal_add_6 + signal_cat_13;
    assign signal_select_6 = signal_cat_17[7:0];
    assign signal_cat_16 = { signal_select_6,
                             signal_const_33 };
    assign signal_cat_17 = { gnd,
                             mid };
    assign signal_add_8 = signal_cat_17 + signal_cat_16;
    assign signal_add_9 = entries_at + signal_add_8;
    assign signal_mux_64 = signal_not_146 ? signal_const_35 : signal_add_9;
    assign signal_cat_18 = { signal_const_36,
                             k };
    assign signal_select_7 = signal_cat_20[7:0];
    assign signal_cat_19 = { signal_select_7,
                             signal_const_33 };
    assign signal_cat_20 = { gnd,
                             ptr };
    assign signal_add_10 = signal_cat_20 + signal_cat_19;
    assign signal_const_52 = 9'b000000010;
    assign entries_at = setup$base_0 + signal_const_52;
    assign signal_add_11 = entries_at + signal_add_10;
    assign signal_add_12 = signal_add_11 + signal_cat_18;
    assign signal_mux_65 = signal_lt_44 ? signal_add_12 : signal_const_35;
    assign signal_cat_21 = { signal_const_36,
                             k };
    assign signal_wire_6 = setup$base;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            setup$base_0 <= signal_const_35;
        else
            if (signal_and_62)
                setup$base_0 <= signal_wire_6;
    end
    assign signal_add_13 = setup$base_0 + signal_cat_21;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_6 <= signal_add_13;
        4'b0011:
            signal_cases_6 <= signal_mux_65;
        4'b0101:
            signal_cases_6 <= signal_mux_64;
        4'b0110:
            signal_cases_6 <= signal_add_7;
        4'b0111:
            signal_cases_6 <= signal_mux_55;
        default:
            signal_cases_6 <= signal_const_35;
        endcase
    end
    assign data_addr = signal_cases_6;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            read_at <= signal_const_35;
        else
            read_at <= data_addr;
    end
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            read_valid <= signal_const_33;
        else
            read_valid <= reading;
    end
    assign signal_const_57 = 4'b0000;
    assign signal_eq_1 = ptr == count;
    assign signal_mux_66 = signal_eq_1 ? signal_const_57 : signal_const_57;
    assign signal_mux_67 = signal_eq_6 ? signal_const_58 : signal_const_315;
    assign signal_mux_68 = stored ? signal_const_335 : signal_mux_67;
    assign signal_mux_69 = target_fails ? signal_const_57 : signal_mux_68;
    assign signal_mux_70 = next_fails ? signal_const_57 : signal_mux_69;
    assign signal_mux_71 = stored ? signal_const_335 : signal_const_354;
    assign signal_mux_72 = signal_eq_2 ? signal_const_337 : signal_const_353;
    assign signal_mux_73 = falls_to_next ? signal_mux_71 : signal_mux_72;
    assign signal_mux_74 = signal_eq_6 ? signal_const_58 : signal_const_315;
    always @* begin
        case (purpose)
        3'b000:
            signal_cases_7 <= signal_const_345;
        3'b001:
            signal_cases_7 <= signal_const_337;
        3'b010:
            signal_cases_7 <= signal_const_337;
        3'b011:
            signal_cases_7 <= signal_const_337;
        3'b100:
            signal_cases_7 <= signal_mux_74;
        default:
            signal_cases_7 <= sm;
        endcase
    end
    assign signal_mux_75 = signal_eq_5 ? signal_cases_7 : signal_const_354;
    assign signal_const_58 = 4'b1011;
    assign signal_mux_76 = signal_eq_6 ? signal_const_58 : signal_const_315;
    assign signal_const_337 = 4'b1010;
    always @* begin
        case (purpose)
        3'b000:
            signal_cases_8 <= signal_const_345;
        3'b001:
            signal_cases_8 <= signal_const_337;
        3'b010:
            signal_cases_8 <= signal_const_337;
        3'b011:
            signal_cases_8 <= signal_const_337;
        3'b100:
            signal_cases_8 <= signal_mux_76;
        default:
            signal_cases_8 <= sm;
        endcase
    end
    assign signal_mux_77 = signal_eq_104 ? sm : signal_const_311;
    assign signal_mux_78 = last_word ? signal_mux_77 : sm;
    assign signal_mux_79 = read_done ? signal_mux_78 : sm;
    assign signal_const_311 = 4'b1000;
    assign signal_mux_80 = signal_eq_103 ? sm : signal_const_311;
    assign signal_mux_81 = from_dictionary ? signal_mux_79 : signal_mux_80;
    assign signal_mux_82 = signal_eq_116 ? signal_cases_8 : signal_mux_81;
    assign signal_mux_83 = signal_eq_110 ? signal_const_354 : sm;
    assign signal_mux_84 = read_done ? signal_mux_83 : sm;
    assign signal_const_354 = 4'b0111;
    assign signal_const_335 = 4'b0110;
    assign signal_mux_85 = signal_eq_113 ? signal_const_335 : sm;
    assign signal_mux_86 = read_done ? signal_mux_85 : sm;
    assign signal_mux_87 = signal_not_146 ? signal_const_354 : signal_mux_86;
    assign signal_const_353 = 4'b0101;
    assign signal_mux_88 = signal_eq_4 ? signal_const_345 : signal_const_353;
    assign signal_const_345 = 4'b1001;
    assign signal_mux_89 = is_jump ? signal_mux_88 : signal_const_345;
    assign signal_lt = pc < entry_tag;
    assign signal_not_22 = ~ signal_lt;
    assign signal_mux_90 = signal_not_22 ? signal_const_57 : signal_const_352;
    assign signal_mux_91 = read_done ? signal_mux_90 : sm;
    assign signal_const_352 = 4'b0100;
    assign signal_mux_92 = signal_lt_44 ? signal_mux_91 : signal_const_352;
    assign signal_const_356 = 4'b0011;
    assign signal_mux_93 = signal_eq_115 ? signal_const_356 : sm;
    assign signal_mux_94 = signal_eq_114 ? signal_const_315 : sm;
    assign signal_const_59 = 2'b11;
    assign signal_const_61 = 2'b01;
    assign signal_add_14 = \wait  + signal_const_61;
    assign signal_not_23 = ~ read_done;
    assign signal_mux_95 = from_dictionary ? vdd : gnd;
    assign signal_mux_96 = signal_eq_116 ? gnd : signal_mux_95;
    assign signal_mux_97 = signal_not_146 ? gnd : vdd;
    assign signal_mux_98 = stored ? ptr : signal_add_15;
    assign signal_mux_99 = target_fails ? ptr : signal_mux_98;
    assign signal_mux_100 = next_fails ? ptr : signal_mux_99;
    always @* begin
        case (purpose)
        3'b100:
            signal_cases_9 <= signal_add_15;
        default:
            signal_cases_9 <= ptr;
        endcase
    end
    assign signal_mux_101 = signal_eq_5 ? signal_cases_9 : ptr;
    assign signal_cat_22 = { signal_const_36,
                             stored };
    assign signal_add_15 = ptr + signal_cat_22;
    always @* begin
        case (purpose)
        3'b100:
            signal_cases_10 <= signal_add_15;
        default:
            signal_cases_10 <= ptr;
        endcase
    end
    assign signal_const_65 = 3'b101;
    assign signal_const_66 = 3'b000;
    assign signal_mux_102 = stored ? field : signal_const_66;
    assign signal_mux_103 = falls_to_next ? signal_mux_102 : field;
    assign signal_const_68 = 3'b001;
    assign signal_add_16 = field + signal_const_68;
    assign signal_add_17 = field + signal_const_68;
    assign signal_mux_104 = signal_eq_104 ? signal_add_17 : field;
    assign signal_mux_105 = last_word ? signal_mux_104 : field;
    assign signal_mux_106 = read_done ? signal_mux_105 : field;
    assign signal_add_18 = field + signal_const_68;
    assign signal_mux_107 = signal_eq_103 ? signal_add_18 : field;
    assign signal_mux_108 = from_dictionary ? signal_mux_106 : signal_mux_107;
    assign signal_mux_109 = signal_eq_116 ? field : signal_mux_108;
    assign signal_mux_110 = signal_eq_110 ? signal_const_66 : field;
    assign signal_mux_111 = read_done ? signal_mux_110 : field;
    assign signal_mux_112 = signal_eq_2 ? lo : signal_const_44;
    assign signal_mux_113 = falls_to_next ? lo : signal_mux_112;
    assign signal_const_75 = 8'b00000001;
    assign signal_eq_2 = following == signal_const_35;
    assign signal_mux_114 = signal_eq_2 ? hi : count;
    assign signal_mux_115 = falls_to_next ? hi : signal_mux_114;
    assign signal_mux_116 = signal_lt_1 ? hi : mid;
    assign signal_mux_117 = signal_eq_113 ? hi : signal_mux_116;
    assign signal_mux_118 = read_done ? signal_mux_117 : hi;
    assign signal_mux_119 = signal_not_146 ? hi : signal_mux_118;
    assign signal_select_8 = signal_wire_64[7:0];
    assign signal_eq_3 = k == signal_const_39;
    assign signal_mux_120 = signal_eq_3 ? signal_select_8 : count;
    assign signal_mux_121 = read_done ? signal_mux_120 : count;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_11 <= signal_mux_121;
        default:
            signal_cases_11 <= count;
        endcase
    end
    assign signal_wire_7 = signal_cases_11;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            count <= signal_const_44;
        else
            count <= signal_wire_7;
    end
    assign signal_mux_122 = signal_eq_4 ? hi : count;
    assign signal_mux_123 = is_jump ? signal_mux_122 : hi;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_12 <= signal_mux_123;
        4'b0101:
            signal_cases_12 <= signal_mux_119;
        4'b1001:
            signal_cases_12 <= signal_mux_115;
        default:
            signal_cases_12 <= hi;
        endcase
    end
    assign signal_wire_8 = signal_cases_12;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            hi <= signal_const_44;
        else
            hi <= signal_wire_8;
    end
    assign signal_cat_23 = { gnd,
                             hi };
    assign signal_cat_24 = { gnd,
                             lo };
    assign signal_add_19 = signal_cat_24 + signal_cat_23;
    assign signal_select_9 = signal_add_19[8:1];
    assign signal_cat_25 = { signal_const_33,
                             signal_select_9 };
    assign mid = signal_cat_25[7:0];
    assign signal_add_20 = mid + signal_const_75;
    assign signal_lt_1 = entry_tag < key;
    assign signal_mux_124 = signal_lt_1 ? signal_add_20 : lo;
    assign signal_mux_125 = signal_eq_113 ? lo : signal_mux_124;
    assign signal_mux_126 = read_done ? signal_mux_125 : lo;
    assign signal_mux_127 = signal_not_146 ? lo : signal_mux_126;
    assign signal_eq_4 = jump_target == signal_const_35;
    assign signal_mux_128 = signal_eq_4 ? lo : signal_const_44;
    assign signal_wire_9 = program_word;
    assign signal_mux_129 = signal_eq_6 ? k : signal_const_39;
    assign signal_mux_130 = stored ? signal_const_39 : signal_mux_129;
    assign signal_mux_131 = target_fails ? k : signal_mux_130;
    assign signal_mux_132 = next_fails ? k : signal_mux_131;
    assign signal_mux_133 = stored ? signal_const_39 : signal_const_39;
    assign signal_mux_134 = falls_to_next ? signal_mux_133 : k;
    assign signal_mux_135 = signal_eq_6 ? k : signal_const_39;
    always @* begin
        case (purpose)
        3'b100:
            signal_cases_13 <= signal_mux_135;
        default:
            signal_cases_13 <= k;
        endcase
    end
    assign signal_mux_136 = signal_eq_5 ? signal_cases_13 : k;
    assign signal_mux_137 = signal_eq_6 ? k : signal_const_39;
    always @* begin
        case (purpose)
        3'b100:
            signal_cases_14 <= signal_mux_137;
        default:
            signal_cases_14 <= k;
        endcase
    end
    assign signal_add_21 = k + signal_const_61;
    assign signal_mux_138 = last_word ? signal_const_39 : signal_add_21;
    assign signal_mux_139 = read_done ? signal_mux_138 : k;
    assign signal_mux_140 = from_dictionary ? signal_mux_139 : k;
    assign signal_mux_141 = signal_eq_116 ? signal_cases_14 : signal_mux_140;
    assign signal_add_22 = k + signal_const_61;
    assign signal_mux_142 = signal_eq_110 ? signal_const_39 : signal_add_22;
    assign signal_mux_143 = read_done ? signal_mux_142 : k;
    assign signal_wire_10 = config$wrap_bottom;
    assign signal_const_97 = 9'b000000001;
    assign signal_add_23 = pc + signal_const_97;
    assign signal_wire_11 = config$wrap_top;
    assign signal_mux_144 = signal_eq_6 ? pc : signal_select_10;
    assign signal_mux_145 = stored ? pc : signal_mux_144;
    assign signal_mux_146 = target_fails ? pc : signal_mux_145;
    assign signal_mux_147 = next_fails ? pc : signal_mux_146;
    assign signal_mux_148 = signal_eq_6 ? pc : signal_select_10;
    always @* begin
        case (purpose)
        3'b100:
            signal_cases_15 <= signal_mux_148;
        default:
            signal_cases_15 <= pc;
        endcase
    end
    assign signal_const_99 = 3'b100;
    assign signal_eq_5 = field == signal_const_99;
    assign signal_mux_149 = signal_eq_5 ? signal_cases_15 : pc;
    assign signal_select_10 = next_pc[8:0];
    assign signal_const_100 = 9'b111111111;
    assign signal_eq_6 = pc == signal_const_100;
    assign signal_mux_150 = signal_eq_6 ? pc : signal_select_10;
    assign signal_mux_151 = stored ? signal_const_99 : purpose;
    assign signal_mux_152 = target_fails ? purpose : signal_mux_151;
    always @* begin
        case (field)
        3'b100:
            signal_cases_16 <= signal_const_33;
        default:
            signal_cases_16 <= failed_next$edge_b;
        endcase
    end
    assign signal_mux_153 = signal_eq_95 ? failed_next$edge_b : signal_cases_16;
    assign signal_mux_154 = signal_eq_115 ? gnd : failed_next$edge_b;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_17 <= signal_mux_154;
        4'b1000:
            signal_cases_17 <= signal_mux_153;
        default:
            signal_cases_17 <= failed_next$edge_b;
        endcase
    end
    assign signal_wire_12 = signal_cases_17;
    always @(posedge signal_wire_59) begin
        failed_next$edge_b <= signal_wire_12;
    end
    assign signal_not_24 = ~ failed_next$edge_b;
    always @* begin
        case (field)
        3'b100:
            signal_cases_18 <= signal_const_33;
        default:
            signal_cases_18 <= failed_next$edge_a;
        endcase
    end
    assign signal_mux_155 = signal_eq_95 ? failed_next$edge_a : signal_cases_18;
    assign signal_mux_156 = signal_eq_115 ? gnd : failed_next$edge_a;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_19 <= signal_mux_156;
        4'b1000:
            signal_cases_19 <= signal_mux_155;
        default:
            signal_cases_19 <= failed_next$edge_a;
        endcase
    end
    assign signal_wire_13 = signal_cases_19;
    always @(posedge signal_wire_59) begin
        failed_next$edge_a <= signal_wire_13;
    end
    assign signal_not_25 = ~ failed_next$edge_a;
    assign signal_not_26 = ~ way$awaiting;
    always @* begin
        case (field)
        3'b100:
            signal_cases_20 <= signal_not_26;
        default:
            signal_cases_20 <= failed_next$awaiting;
        endcase
    end
    assign signal_mux_157 = signal_eq_95 ? failed_next$awaiting : signal_cases_20;
    assign signal_mux_158 = signal_eq_115 ? gnd : failed_next$awaiting;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_21 <= signal_mux_158;
        4'b1000:
            signal_cases_21 <= signal_mux_157;
        default:
            signal_cases_21 <= failed_next$awaiting;
        endcase
    end
    assign signal_wire_14 = signal_cases_21;
    always @(posedge signal_wire_59) begin
        failed_next$awaiting <= signal_wire_14;
    end
    assign signal_not_27 = ~ failed_next$awaiting;
    assign signal_not_28 = ~ way$captured;
    always @* begin
        case (field)
        3'b100:
            signal_cases_22 <= signal_not_28;
        default:
            signal_cases_22 <= failed_next$captured;
        endcase
    end
    assign signal_mux_159 = signal_eq_95 ? failed_next$captured : signal_cases_22;
    assign signal_mux_160 = signal_eq_115 ? gnd : failed_next$captured;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_23 <= signal_mux_160;
        4'b1000:
            signal_cases_23 <= signal_mux_159;
        default:
            signal_cases_23 <= failed_next$captured;
        endcase
    end
    assign signal_wire_15 = signal_cases_23;
    always @(posedge signal_wire_59) begin
        failed_next$captured <= signal_wire_15;
    end
    assign signal_not_29 = ~ failed_next$captured;
    assign signal_not_30 = ~ way$arm;
    always @* begin
        case (field)
        3'b001:
            signal_cases_24 <= signal_not_30;
        default:
            signal_cases_24 <= failed_next$arm;
        endcase
    end
    assign signal_mux_161 = signal_eq_95 ? failed_next$arm : signal_cases_24;
    assign signal_mux_162 = signal_eq_115 ? gnd : failed_next$arm;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_25 <= signal_mux_162;
        4'b1000:
            signal_cases_25 <= signal_mux_161;
        default:
            signal_cases_25 <= failed_next$arm;
        endcase
    end
    assign signal_wire_16 = signal_cases_25;
    always @(posedge signal_wire_59) begin
        failed_next$arm <= signal_wire_16;
    end
    assign signal_not_31 = ~ failed_next$arm;
    assign signal_not_32 = ~ way$y;
    always @* begin
        case (field)
        3'b100:
            signal_cases_26 <= signal_not_32;
        default:
            signal_cases_26 <= failed_next$y;
        endcase
    end
    assign signal_mux_163 = signal_eq_95 ? failed_next$y : signal_cases_26;
    assign signal_mux_164 = signal_eq_115 ? gnd : failed_next$y;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_27 <= signal_mux_164;
        4'b1000:
            signal_cases_27 <= signal_mux_163;
        default:
            signal_cases_27 <= failed_next$y;
        endcase
    end
    assign signal_wire_17 = signal_cases_27;
    always @(posedge signal_wire_59) begin
        failed_next$y <= signal_wire_17;
    end
    assign signal_not_33 = ~ failed_next$y;
    assign signal_not_34 = ~ way$x;
    always @* begin
        case (field)
        3'b011:
            signal_cases_28 <= signal_not_34;
        default:
            signal_cases_28 <= failed_next$x;
        endcase
    end
    assign signal_mux_165 = signal_eq_95 ? failed_next$x : signal_cases_28;
    assign signal_mux_166 = signal_eq_115 ? gnd : failed_next$x;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_29 <= signal_mux_166;
        4'b1000:
            signal_cases_29 <= signal_mux_165;
        default:
            signal_cases_29 <= failed_next$x;
        endcase
    end
    assign signal_wire_18 = signal_cases_29;
    always @(posedge signal_wire_59) begin
        failed_next$x <= signal_wire_18;
    end
    assign signal_not_35 = ~ failed_next$x;
    assign signal_not_36 = ~ way$period;
    always @* begin
        case (field)
        3'b010:
            signal_cases_30 <= signal_not_36;
        default:
            signal_cases_30 <= failed_next$period;
        endcase
    end
    assign signal_mux_167 = signal_eq_95 ? failed_next$period : signal_cases_30;
    assign signal_mux_168 = signal_eq_115 ? gnd : failed_next$period;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_31 <= signal_mux_168;
        4'b1000:
            signal_cases_31 <= signal_mux_167;
        default:
            signal_cases_31 <= failed_next$period;
        endcase
    end
    assign signal_wire_19 = signal_cases_31;
    always @(posedge signal_wire_59) begin
        failed_next$period <= signal_wire_19;
    end
    assign signal_not_37 = ~ failed_next$period;
    always @* begin
        case (field)
        3'b100:
            signal_cases_32 <= signal_const_33;
        default:
            signal_cases_32 <= failed_next$offset;
        endcase
    end
    assign signal_mux_169 = signal_eq_95 ? failed_next$offset : signal_cases_32;
    assign signal_mux_170 = signal_eq_115 ? gnd : failed_next$offset;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_33 <= signal_mux_170;
        4'b1000:
            signal_cases_33 <= signal_mux_169;
        default:
            signal_cases_33 <= failed_next$offset;
        endcase
    end
    assign signal_wire_20 = signal_cases_33;
    always @(posedge signal_wire_59) begin
        failed_next$offset <= signal_wire_20;
    end
    assign signal_not_38 = ~ failed_next$offset;
    assign signal_not_39 = ~ way$phase;
    always @* begin
        case (field)
        3'b000:
            signal_cases_34 <= signal_not_39;
        default:
            signal_cases_34 <= failed_next$phase;
        endcase
    end
    assign signal_mux_171 = signal_eq_95 ? failed_next$phase : signal_cases_34;
    assign signal_mux_172 = signal_eq_115 ? gnd : failed_next$phase;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_35 <= signal_mux_172;
        4'b1000:
            signal_cases_35 <= signal_mux_171;
        default:
            signal_cases_35 <= failed_next$phase;
        endcase
    end
    assign signal_wire_21 = signal_cases_35;
    always @(posedge signal_wire_59) begin
        failed_next$phase <= signal_wire_21;
    end
    assign signal_not_40 = ~ failed_next$phase;
    assign signal_select_11 = row$phase_hi[22:0];
    assign signal_select_12 = row$phase_hi[23:23];
    assign signal_not_41 = ~ signal_select_12;
    assign signal_cat_26 = { signal_not_41,
                             signal_select_11 };
    assign signal_const_110 = 24'b100000000000000000000000;
    assign signal_lt_2 = signal_const_110 < signal_cat_26;
    assign signal_not_42 = ~ signal_lt_2;
    assign signal_not_43 = ~ signal_and_94;
    assign signal_const_111 = 4'b0001;
    assign signal_eq_7 = signal_select_71 == signal_const_111;
    assign signal_const_112 = 3'b111;
    assign signal_eq_8 = signal_select_88 == signal_const_112;
    assign signal_and = signal_eq_8 & signal_eq_7;
    assign signal_select_13 = word[3:0];
    assign signal_lt_3 = signal_select_13 < signal_const_345;
    assign signal_select_14 = word[7:4];
    assign signal_eq_9 = signal_select_14 == signal_const_57;
    assign signal_and_1 = signal_eq_9 & signal_lt_3;
    assign signal_lt_4 = signal_select_73 < signal_const_65;
    assign signal_not_44 = ~ signal_select_74;
    assign signal_or_19 = signal_not_44 | signal_lt_4;
    assign signal_lt_5 = signal_select_75 < signal_const_59;
    assign signal_and_2 = signal_lt_5 & signal_or_19;
    assign signal_lt_6 = signal_select_50 < signal_const_65;
    assign signal_lt_7 = signal_select_79 < signal_const_59;
    assign signal_lt_8 = signal_const_22 < signal_select_15;
    assign signal_not_45 = ~ signal_lt_8;
    assign signal_select_15 = word[4:0];
    assign signal_lt_9 = signal_select_15 < signal_const_4;
    assign signal_not_46 = ~ signal_lt_9;
    assign signal_and_3 = signal_not_46 & signal_not_45;
    assign signal_eq_10 = signal_select_70 == signal_const;
    assign signal_eq_11 = signal_select_70 == signal_const;
    assign signal_const_123 = 5'b11100;
    assign signal_lt_10 = signal_select_70 < signal_const_123;
    assign signal_lt_11 = signal_select_70 < signal_const_123;
    always @* begin
        case (signal_select_81)
        0:
            signal_mux_173 <= signal_lt_11;
        1:
            signal_mux_173 <= signal_lt_10;
        2:
            signal_mux_173 <= signal_eq_11;
        default:
            signal_mux_173 <= signal_eq_10;
        endcase
    end
    assign signal_const_125 = 4'b1100;
    assign signal_select_16 = word[12:9];
    assign signal_lt_12 = signal_select_16 < signal_const_125;
    always @* begin
        case (signal_select_88)
        0:
            signal_mux_174 <= signal_lt_12;
        1:
            signal_mux_174 <= signal_mux_173;
        2:
            signal_mux_174 <= signal_and_3;
        3:
            signal_mux_174 <= signal_and_3;
        4:
            signal_mux_174 <= signal_lt_7;
        5:
            signal_mux_174 <= signal_lt_6;
        6:
            signal_mux_174 <= signal_and_2;
        default:
            signal_mux_174 <= signal_and_1;
        endcase
    end
    assign signal_not_47 = ~ signal_mux_174;
    assign signal_or_20 = signal_not_47 | signal_and;
    assign signal_not_48 = ~ signal_or_20;
    assign signal_lt_13 = row$arm_hi < row$arm_lo;
    assign signal_lt_14 = row$y_hi < row$y_lo;
    assign signal_lt_15 = row$x_hi < row$x_lo;
    assign signal_lt_16 = row$period_hi < row$period_lo;
    assign signal_select_17 = row$phase_lo[22:0];
    assign signal_select_18 = row$phase_lo[23:23];
    assign signal_not_49 = ~ signal_select_18;
    assign signal_cat_27 = { signal_not_49,
                             signal_select_17 };
    assign signal_select_19 = row$phase_hi[22:0];
    assign signal_mux_175 = falls_to_next ? fell$phase_hi : signal_const_135;
    assign signal_mux_176 = stored ? row$phase_hi : signal_mux_175;
    assign signal_mux_177 = target_fails ? row$phase_hi : signal_mux_176;
    assign signal_mux_178 = next_fails ? row$phase_hi : signal_mux_177;
    assign signal_mux_179 = read_done ? shifted : acc;
    assign signal_const_126 = 48'b000000000000000000000000000000001111111111111111;
    assign signal_const_129 = 48'b000000000000000000000000111111111111111111111111;
    assign signal_const_130 = 48'b100000000000000000000000011111111111111111111111;
    always @* begin
        case (field)
        0:
            signal_mux_180 <= signal_const_130;
        1:
            signal_mux_180 <= signal_const_129;
        2:
            signal_mux_180 <= signal_const_126;
        3:
            signal_mux_180 <= signal_const_126;
        default:
            signal_mux_180 <= signal_const_126;
        endcase
    end
    assign signal_cat_28 = { fell$y_lo,
                             fell$y_hi };
    assign signal_const_131 = 16'b0000000000000000;
    assign signal_cat_29 = { signal_const_131,
                             signal_cat_28 };
    assign signal_cat_30 = { fell$x_lo,
                             fell$x_hi };
    assign signal_cat_31 = { signal_const_131,
                             signal_cat_30 };
    assign signal_cat_32 = { fell$period_lo,
                             fell$period_hi };
    assign signal_cat_33 = { signal_const_131,
                             signal_cat_32 };
    assign signal_cat_34 = { fell$arm_lo,
                             fell$arm_hi };
    assign signal_select_20 = signal_add_24[23:0];
    assign signal_const_134 = 24'b011111111111111111111111;
    assign signal_mux_181 = signal_and_5 ? signal_select_20 : signal_const_134;
    assign signal_const_135 = 24'b000000000000000000000000;
    assign fell$phase_hi = signal_and_115 ? signal_mux_181 : signal_const_135;
    assign signal_select_21 = signal_add_26[23:0];
    assign signal_select_22 = signal_add_24[24:0];
    assign signal_select_23 = signal_add_24[25:25];
    assign signal_not_50 = ~ signal_select_23;
    assign signal_cat_35 = { signal_not_50,
                             signal_select_22 };
    assign signal_const_137 = 26'b10011111111111111111111111;
    assign signal_lt_17 = signal_const_137 < signal_cat_35;
    assign signal_not_51 = ~ signal_lt_17;
    assign signal_const_138 = 26'b01100000000000000000000000;
    assign signal_select_24 = signal_add_26[24:0];
    assign signal_select_25 = signal_add_26[25:25];
    assign signal_not_52 = ~ signal_select_25;
    assign signal_cat_36 = { signal_not_52,
                             signal_select_24 };
    assign signal_lt_18 = signal_cat_36 < signal_const_138;
    assign signal_not_53 = ~ signal_lt_18;
    assign signal_and_4 = signal_or_55 & signal_not_53;
    assign signal_and_5 = signal_and_4 & signal_not_51;
    assign signal_mux_182 = signal_and_5 ? signal_select_21 : signal_const_110;
    assign signal_eq_12 = row$x_lo == signal_const_131;
    assign signal_eq_13 = row$y_lo == signal_const_131;
    assign signal_lt_19 = row$x_hi < row$y_lo;
    assign signal_not_54 = ~ signal_lt_19;
    assign signal_const_141 = 16'b0000000000000001;
    assign signal_sub_2 = row$y_hi - signal_const_141;
    assign signal_mux_183 = signal_eq_94 ? signal_sub_2 : signal_const_217;
    assign signal_mux_184 = signal_and_25 ? signal_mux_326 : row$y_hi;
    assign signal_mux_185 = signal_and_112 ? signal_mux_183 : signal_mux_184;
    assign signal_mux_186 = signal_and_26 ? signal_cat_59 : signal_mux_185;
    assign signal_mux_187 = signal_not_106 ? signal_mux_186 : signal_const_217;
    assign fell$y_hi = signal_and_115 ? signal_mux_187 : signal_const_131;
    assign signal_mux_188 = falls_to_next ? fell$y_hi : signal_const_131;
    assign signal_mux_189 = stored ? row$y_hi : signal_mux_188;
    always @* begin
        case (field)
        3'b100:
            signal_cases_36 <= signal_const_33;
        default:
            signal_cases_36 <= failed_target$edge_b;
        endcase
    end
    assign signal_mux_190 = signal_eq_95 ? signal_cases_36 : failed_target$edge_b;
    assign signal_mux_191 = signal_eq_115 ? gnd : failed_target$edge_b;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_37 <= signal_mux_191;
        4'b1000:
            signal_cases_37 <= signal_mux_190;
        default:
            signal_cases_37 <= failed_target$edge_b;
        endcase
    end
    assign signal_wire_22 = signal_cases_37;
    always @(posedge signal_wire_59) begin
        failed_target$edge_b <= signal_wire_22;
    end
    assign signal_not_55 = ~ failed_target$edge_b;
    always @* begin
        case (field)
        3'b100:
            signal_cases_38 <= signal_const_33;
        default:
            signal_cases_38 <= failed_target$edge_a;
        endcase
    end
    assign signal_mux_192 = signal_eq_95 ? signal_cases_38 : failed_target$edge_a;
    assign signal_mux_193 = signal_eq_115 ? gnd : failed_target$edge_a;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_39 <= signal_mux_193;
        4'b1000:
            signal_cases_39 <= signal_mux_192;
        default:
            signal_cases_39 <= failed_target$edge_a;
        endcase
    end
    assign signal_wire_23 = signal_cases_39;
    always @(posedge signal_wire_59) begin
        failed_target$edge_a <= signal_wire_23;
    end
    assign signal_not_56 = ~ failed_target$edge_a;
    assign signal_not_57 = ~ signal_and_24;
    assign signal_or_21 = signal_not_57 | signal_or_22;
    assign held$awaiting = signal_select_92[35:35];
    assign signal_wire_24 = fell$awaiting;
    assign signal_eq_14 = signal_const_209 == source;
    assign signal_and_6 = signal_eq_14 & signal_wire_24;
    assign signal_eq_15 = signal_const_39 == source;
    assign checked_awaiting = signal_eq_15 ? held$awaiting : signal_and_6;
    assign signal_not_58 = ~ checked_awaiting;
    assign signal_or_22 = signal_not_58 | signal_mux_412;
    assign signal_not_59 = ~ signal_and_100;
    assign signal_or_23 = signal_not_59 | signal_or_22;
    assign way$awaiting = signal_or_23 & signal_or_21;
    assign signal_not_60 = ~ way$awaiting;
    always @* begin
        case (field)
        3'b100:
            signal_cases_40 <= signal_not_60;
        default:
            signal_cases_40 <= failed_target$awaiting;
        endcase
    end
    assign signal_mux_194 = signal_eq_95 ? signal_cases_40 : failed_target$awaiting;
    assign signal_mux_195 = signal_eq_115 ? gnd : failed_target$awaiting;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_41 <= signal_mux_195;
        4'b1000:
            signal_cases_41 <= signal_mux_194;
        default:
            signal_cases_41 <= failed_target$awaiting;
        endcase
    end
    assign signal_wire_25 = signal_cases_41;
    always @(posedge signal_wire_59) begin
        failed_target$awaiting <= signal_wire_25;
    end
    assign signal_not_61 = ~ failed_target$awaiting;
    assign signal_not_62 = ~ signal_and_24;
    assign signal_or_24 = signal_not_62 | signal_or_25;
    assign held$captured = signal_select_92[36:36];
    assign signal_wire_26 = fell$captured;
    assign signal_eq_16 = signal_const_209 == source;
    assign signal_and_7 = signal_eq_16 & signal_wire_26;
    assign signal_eq_17 = signal_const_39 == source;
    assign checked_captured = signal_eq_17 ? held$captured : signal_and_7;
    assign signal_not_63 = ~ checked_captured;
    assign signal_or_25 = signal_not_63 | signal_mux_421;
    assign signal_not_64 = ~ signal_and_100;
    assign signal_or_26 = signal_not_64 | signal_or_25;
    assign way$captured = signal_or_26 & signal_or_24;
    assign signal_not_65 = ~ way$captured;
    always @* begin
        case (field)
        3'b100:
            signal_cases_42 <= signal_not_65;
        default:
            signal_cases_42 <= failed_target$captured;
        endcase
    end
    assign signal_mux_196 = signal_eq_95 ? signal_cases_42 : failed_target$captured;
    assign signal_mux_197 = signal_eq_115 ? gnd : failed_target$captured;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_43 <= signal_mux_197;
        4'b1000:
            signal_cases_43 <= signal_mux_196;
        default:
            signal_cases_43 <= failed_target$captured;
        endcase
    end
    assign signal_wire_27 = signal_cases_43;
    always @(posedge signal_wire_59) begin
        failed_target$captured <= signal_wire_27;
    end
    assign signal_not_66 = ~ failed_target$captured;
    assign signal_not_67 = ~ signal_and_24;
    assign signal_or_27 = signal_not_67 | signal_or_28;
    assign signal_cat_37 = { signal_const_39,
                             signal_select_82 };
    assign signal_lt_20 = signal_cat_37 < signal_mux_397;
    assign signal_not_68 = ~ signal_lt_20;
    assign signal_cat_38 = { signal_const_39,
                             signal_select_84 };
    assign signal_lt_21 = signal_mux_365 < signal_cat_38;
    assign signal_not_69 = ~ signal_lt_21;
    assign signal_and_8 = signal_or_45 & signal_not_69;
    assign signal_and_9 = signal_and_8 & signal_not_68;
    assign signal_const_147 = 24'b111111111111111111111111;
    assign signal_eq_18 = signal_select_82 == signal_const_147;
    assign signal_eq_19 = signal_select_84 == signal_const_135;
    assign signal_and_10 = signal_eq_19 & signal_eq_18;
    assign signal_or_28 = signal_and_10 | signal_and_9;
    assign signal_not_70 = ~ signal_and_100;
    assign signal_or_29 = signal_not_70 | signal_or_28;
    assign way$arm = signal_or_29 & signal_or_27;
    assign signal_not_71 = ~ way$arm;
    always @* begin
        case (field)
        3'b001:
            signal_cases_44 <= signal_not_71;
        default:
            signal_cases_44 <= failed_target$arm;
        endcase
    end
    assign signal_mux_198 = signal_eq_95 ? signal_cases_44 : failed_target$arm;
    assign signal_mux_199 = signal_eq_115 ? gnd : failed_target$arm;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_45 <= signal_mux_199;
        4'b1000:
            signal_cases_45 <= signal_mux_198;
        default:
            signal_cases_45 <= failed_target$arm;
        endcase
    end
    assign signal_wire_28 = signal_cases_45;
    always @(posedge signal_wire_59) begin
        failed_target$arm <= signal_wire_28;
    end
    assign signal_not_72 = ~ failed_target$arm;
    assign signal_not_73 = ~ signal_and_24;
    assign signal_or_30 = signal_not_73 | signal_mux_209;
    assign signal_eq_20 = signal_select_26 == signal_const_217;
    assign signal_eq_21 = signal_select_27 == signal_const_131;
    assign signal_and_11 = signal_eq_21 & signal_eq_20;
    assign signal_sub_3 = row$y_hi - signal_const_141;
    assign signal_mux_200 = signal_eq_94 ? signal_sub_3 : signal_const_217;
    assign signal_mux_201 = signal_and_12 ? signal_mux_326 : row$y_hi;
    assign signal_mux_202 = signal_and_112 ? signal_mux_200 : signal_mux_201;
    assign signal_mux_203 = signal_and_26 ? signal_cat_59 : signal_mux_202;
    assign signal_lt_22 = signal_select_26 < signal_mux_203;
    assign signal_not_74 = ~ signal_lt_22;
    assign signal_sub_4 = row$y_lo - signal_const_141;
    assign signal_eq_22 = row$y_lo == signal_const_131;
    assign signal_mux_204 = signal_eq_22 ? signal_const_131 : signal_sub_4;
    assign signal_mux_205 = signal_eq_94 ? signal_mux_204 : signal_const_217;
    assign signal_not_75 = ~ signal_eq_94;
    assign signal_and_12 = signal_not_75 & signal_and_111;
    assign signal_mux_206 = signal_and_12 ? signal_mux_274 : row$y_lo;
    assign signal_mux_207 = signal_and_112 ? signal_mux_205 : signal_mux_206;
    assign signal_mux_208 = signal_and_26 ? signal_cat_59 : signal_mux_207;
    assign signal_lt_23 = signal_mux_208 < signal_select_27;
    assign signal_not_76 = ~ signal_lt_23;
    assign signal_and_13 = signal_not_76 & signal_not_74;
    assign signal_mux_209 = signal_or_38 ? signal_and_11 : signal_and_13;
    assign signal_not_77 = ~ signal_and_100;
    assign signal_or_31 = signal_not_77 | signal_mux_209;
    assign way$y = signal_or_31 & signal_or_30;
    assign signal_not_78 = ~ way$y;
    always @* begin
        case (field)
        3'b100:
            signal_cases_46 <= signal_not_78;
        default:
            signal_cases_46 <= failed_target$y;
        endcase
    end
    assign signal_mux_210 = signal_eq_95 ? signal_cases_46 : failed_target$y;
    assign signal_mux_211 = signal_eq_115 ? gnd : failed_target$y;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_47 <= signal_mux_211;
        4'b1000:
            signal_cases_47 <= signal_mux_210;
        default:
            signal_cases_47 <= failed_target$y;
        endcase
    end
    assign signal_wire_29 = signal_cases_47;
    always @(posedge signal_wire_59) begin
        failed_target$y <= signal_wire_29;
    end
    assign signal_not_79 = ~ failed_target$y;
    assign signal_not_80 = ~ signal_and_24;
    assign signal_or_32 = signal_not_80 | signal_mux_221;
    assign signal_eq_23 = signal_select_26 == signal_const_217;
    assign signal_eq_24 = signal_select_27 == signal_const_131;
    assign signal_and_14 = signal_eq_24 & signal_eq_23;
    assign signal_sub_5 = row$x_hi - signal_const_141;
    assign signal_mux_212 = signal_eq_94 ? signal_sub_5 : signal_const_217;
    assign signal_mux_213 = signal_and_15 ? signal_mux_326 : row$x_hi;
    assign signal_mux_214 = signal_and_113 ? signal_mux_212 : signal_mux_213;
    assign signal_mux_215 = signal_and_37 ? signal_cat_59 : signal_mux_214;
    assign signal_lt_24 = signal_select_26 < signal_mux_215;
    assign signal_not_81 = ~ signal_lt_24;
    assign signal_sub_6 = row$x_lo - signal_const_141;
    assign signal_eq_25 = row$x_lo == signal_const_131;
    assign signal_mux_216 = signal_eq_25 ? signal_const_131 : signal_sub_6;
    assign signal_mux_217 = signal_eq_94 ? signal_mux_216 : signal_const_217;
    assign signal_not_82 = ~ signal_eq_94;
    assign signal_and_15 = signal_not_82 & signal_and_111;
    assign signal_mux_218 = signal_and_15 ? signal_mux_274 : row$x_lo;
    assign signal_mux_219 = signal_and_113 ? signal_mux_217 : signal_mux_218;
    assign signal_mux_220 = signal_and_37 ? signal_cat_59 : signal_mux_219;
    assign signal_lt_25 = signal_mux_220 < signal_select_27;
    assign signal_not_83 = ~ signal_lt_25;
    assign signal_and_16 = signal_not_83 & signal_not_81;
    assign signal_mux_221 = signal_or_43 ? signal_and_14 : signal_and_16;
    assign signal_not_84 = ~ signal_and_100;
    assign signal_or_33 = signal_not_84 | signal_mux_221;
    assign way$x = signal_or_33 & signal_or_32;
    assign signal_not_85 = ~ way$x;
    always @* begin
        case (field)
        3'b011:
            signal_cases_48 <= signal_not_85;
        default:
            signal_cases_48 <= failed_target$x;
        endcase
    end
    assign signal_mux_222 = signal_eq_95 ? signal_cases_48 : failed_target$x;
    assign signal_mux_223 = signal_eq_115 ? gnd : failed_target$x;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_49 <= signal_mux_223;
        4'b1000:
            signal_cases_49 <= signal_mux_222;
        default:
            signal_cases_49 <= failed_target$x;
        endcase
    end
    assign signal_wire_30 = signal_cases_49;
    always @(posedge signal_wire_59) begin
        failed_target$x <= signal_wire_30;
    end
    assign signal_not_86 = ~ failed_target$x;
    assign signal_not_87 = ~ signal_and_24;
    assign signal_or_34 = signal_not_87 | signal_mux_228;
    assign signal_eq_26 = signal_select_26 == signal_const_217;
    assign signal_eq_27 = signal_select_27 == signal_const_131;
    assign signal_and_17 = signal_eq_27 & signal_eq_26;
    assign signal_mux_224 = signal_or_41 ? setup$loaded$value_0 : row$period_hi;
    assign signal_mux_225 = signal_and_31 ? signal_cat_59 : signal_mux_224;
    assign signal_select_26 = acc[15:0];
    assign signal_lt_26 = signal_select_26 < signal_mux_225;
    assign signal_not_88 = ~ signal_lt_26;
    assign signal_select_27 = acc[31:16];
    assign signal_mux_226 = signal_or_41 ? setup$loaded$value_0 : row$period_lo;
    assign signal_mux_227 = signal_and_31 ? signal_cat_59 : signal_mux_226;
    assign signal_lt_27 = signal_mux_227 < signal_select_27;
    assign signal_not_89 = ~ signal_lt_27;
    assign signal_and_18 = signal_not_89 & signal_not_88;
    assign signal_not_90 = ~ setup$loaded$valid_0;
    assign signal_and_19 = signal_or_41 & signal_not_90;
    assign signal_mux_228 = signal_and_19 ? signal_and_17 : signal_and_18;
    assign signal_not_91 = ~ signal_and_100;
    assign signal_or_35 = signal_not_91 | signal_mux_228;
    assign way$period = signal_or_35 & signal_or_34;
    assign signal_not_92 = ~ way$period;
    always @* begin
        case (field)
        3'b010:
            signal_cases_50 <= signal_not_92;
        default:
            signal_cases_50 <= failed_target$period;
        endcase
    end
    assign signal_mux_229 = signal_eq_95 ? signal_cases_50 : failed_target$period;
    assign signal_mux_230 = signal_eq_115 ? gnd : failed_target$period;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_51 <= signal_mux_230;
        4'b1000:
            signal_cases_51 <= signal_mux_229;
        default:
            signal_cases_51 <= failed_target$period;
        endcase
    end
    assign signal_wire_31 = signal_cases_51;
    always @(posedge signal_wire_59) begin
        failed_target$period <= signal_wire_31;
    end
    assign signal_not_93 = ~ failed_target$period;
    always @* begin
        case (field)
        3'b100:
            signal_cases_52 <= signal_const_33;
        default:
            signal_cases_52 <= failed_target$offset;
        endcase
    end
    assign signal_mux_231 = signal_eq_95 ? signal_cases_52 : failed_target$offset;
    assign signal_mux_232 = signal_eq_115 ? gnd : failed_target$offset;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_53 <= signal_mux_232;
        4'b1000:
            signal_cases_53 <= signal_mux_231;
        default:
            signal_cases_53 <= failed_target$offset;
        endcase
    end
    assign signal_wire_32 = signal_cases_53;
    always @(posedge signal_wire_59) begin
        failed_target$offset <= signal_wire_32;
    end
    assign signal_not_94 = ~ failed_target$offset;
    assign signal_eq_28 = row$x_hi == signal_const_131;
    assign signal_not_95 = ~ signal_eq_28;
    assign signal_eq_29 = row$y_hi == signal_const_131;
    assign signal_not_96 = ~ signal_eq_29;
    assign signal_eq_30 = row$x_lo == row$y_lo;
    assign signal_eq_31 = row$y_lo == row$y_hi;
    assign signal_eq_32 = row$x_lo == row$x_hi;
    assign signal_and_20 = signal_eq_32 & signal_eq_31;
    assign signal_and_21 = signal_and_20 & signal_eq_30;
    assign signal_not_97 = ~ signal_and_21;
    assign signal_mux_233 = signal_and_111 ? signal_not_97 : vdd;
    assign signal_mux_234 = signal_and_112 ? signal_not_96 : signal_mux_233;
    assign signal_mux_235 = signal_and_113 ? signal_not_95 : signal_mux_234;
    assign signal_mux_236 = signal_and_114 ? vdd : signal_mux_235;
    assign signal_and_22 = signal_and_116 & signal_eq_100;
    assign signal_and_23 = signal_and_22 & signal_mux_236;
    assign signal_and_24 = signal_and_23 & signal_eq_94;
    assign signal_not_98 = ~ signal_and_24;
    assign signal_or_36 = signal_not_98 | signal_or_56;
    assign signal_select_28 = signal_add_24[24:0];
    assign signal_select_29 = signal_add_24[25:25];
    assign signal_not_99 = ~ signal_select_29;
    assign signal_cat_39 = { signal_not_99,
                             signal_select_28 };
    assign signal_select_30 = signal_cat_41[24:0];
    assign signal_select_31 = signal_select_82[23:23];
    assign signal_cat_40 = { signal_select_31,
                             signal_select_31 };
    assign signal_cat_41 = { signal_cat_40,
                             signal_select_82 };
    assign signal_select_32 = signal_cat_41[25:25];
    assign signal_not_100 = ~ signal_select_32;
    assign signal_cat_42 = { signal_not_100,
                             signal_select_30 };
    assign signal_lt_28 = signal_cat_42 < signal_cat_39;
    assign signal_not_101 = ~ signal_lt_28;
    assign signal_select_33 = signal_cat_44[24:0];
    assign signal_select_34 = signal_select_84[23:23];
    assign signal_cat_43 = { signal_select_34,
                             signal_select_34 };
    assign signal_cat_44 = { signal_cat_43,
                             signal_select_84 };
    assign signal_select_35 = signal_cat_44[25:25];
    assign signal_not_102 = ~ signal_select_35;
    assign signal_cat_45 = { signal_not_102,
                             signal_select_33 };
    assign signal_select_36 = signal_add_26[24:0];
    assign signal_select_37 = signal_add_26[25:25];
    assign signal_not_103 = ~ signal_select_37;
    assign signal_cat_46 = { signal_not_103,
                             signal_select_36 };
    assign signal_lt_29 = signal_cat_46 < signal_cat_45;
    assign signal_not_104 = ~ signal_lt_29;
    assign signal_select_38 = signal_add_24[24:0];
    assign signal_mux_237 = signal_or_41 ? setup$loaded$value_0 : row$period_lo;
    assign signal_mux_238 = signal_and_31 ? signal_cat_59 : signal_mux_237;
    assign signal_mux_239 = signal_not_114 ? signal_mux_238 : signal_const_131;
    assign fell$period_lo = signal_and_115 ? signal_mux_239 : signal_const_131;
    assign signal_mux_240 = falls_to_next ? fell$period_lo : signal_const_131;
    assign signal_mux_241 = stored ? row$period_lo : signal_mux_240;
    assign signal_mux_242 = target_fails ? row$period_lo : signal_mux_241;
    assign signal_mux_243 = next_fails ? row$period_lo : signal_mux_242;
    always @* begin
        case (field)
        3'b010:
            signal_cases_54 <= signal_select_39;
        default:
            signal_cases_54 <= row$period_lo;
        endcase
    end
    assign signal_mux_244 = signal_eq_104 ? signal_cases_54 : row$period_lo;
    assign signal_mux_245 = last_word ? signal_mux_244 : row$period_lo;
    assign signal_mux_246 = read_done ? signal_mux_245 : row$period_lo;
    assign signal_mux_247 = from_dictionary ? signal_mux_246 : row$period_lo;
    assign signal_mux_248 = signal_eq_116 ? row$period_lo : signal_mux_247;
    assign signal_mux_249 = signal_eq_109 ? signal_const_131 : row$period_lo;
    assign signal_mux_250 = signal_eq_110 ? signal_mux_249 : row$period_lo;
    assign signal_mux_251 = read_done ? signal_mux_250 : row$period_lo;
    assign signal_mux_252 = signal_wire_71 ? signal_const_131 : row$period_lo;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_55 <= signal_mux_252;
        4'b0110:
            signal_cases_55 <= signal_mux_251;
        4'b0111:
            signal_cases_55 <= signal_mux_248;
        4'b1010:
            signal_cases_55 <= signal_mux_243;
        default:
            signal_cases_55 <= row$period_lo;
        endcase
    end
    assign signal_wire_33 = signal_cases_55;
    always @(posedge signal_wire_59) begin
        row$period_lo <= signal_wire_33;
    end
    assign signal_cat_47 = { signal_const_31,
                             row$period_lo };
    assign signal_cat_48 = { signal_const_31,
                             row$x_lo };
    assign signal_sub_7 = row$y_lo - signal_const_141;
    assign signal_eq_33 = row$y_lo == signal_const_131;
    assign signal_mux_253 = signal_eq_33 ? signal_const_131 : signal_sub_7;
    assign signal_mux_254 = signal_eq_94 ? signal_mux_253 : signal_const_217;
    assign signal_sub_8 = row$x_lo - signal_const_141;
    assign signal_eq_34 = row$x_lo == signal_const_131;
    assign signal_mux_255 = signal_eq_34 ? signal_const_131 : signal_sub_8;
    assign signal_mux_256 = signal_eq_94 ? signal_mux_255 : signal_const_217;
    assign signal_mux_257 = signal_and_36 ? signal_mux_274 : row$x_lo;
    assign signal_mux_258 = signal_and_113 ? signal_mux_256 : signal_mux_257;
    assign signal_mux_259 = signal_and_37 ? signal_cat_59 : signal_mux_258;
    assign signal_mux_260 = signal_not_116 ? signal_mux_259 : signal_const_131;
    assign fell$x_lo = signal_and_115 ? signal_mux_260 : signal_const_131;
    assign signal_mux_261 = falls_to_next ? fell$x_lo : signal_const_131;
    assign signal_mux_262 = stored ? row$x_lo : signal_mux_261;
    assign signal_mux_263 = target_fails ? row$x_lo : signal_mux_262;
    assign signal_mux_264 = next_fails ? row$x_lo : signal_mux_263;
    always @* begin
        case (field)
        3'b011:
            signal_cases_56 <= signal_select_39;
        default:
            signal_cases_56 <= row$x_lo;
        endcase
    end
    assign signal_mux_265 = signal_eq_104 ? signal_cases_56 : row$x_lo;
    assign signal_mux_266 = last_word ? signal_mux_265 : row$x_lo;
    assign signal_mux_267 = read_done ? signal_mux_266 : row$x_lo;
    assign signal_mux_268 = from_dictionary ? signal_mux_267 : row$x_lo;
    assign signal_mux_269 = signal_eq_116 ? row$x_lo : signal_mux_268;
    assign signal_mux_270 = signal_eq_109 ? signal_const_131 : row$x_lo;
    assign signal_mux_271 = signal_eq_110 ? signal_mux_270 : row$x_lo;
    assign signal_mux_272 = read_done ? signal_mux_271 : row$x_lo;
    assign signal_mux_273 = signal_wire_71 ? signal_const_131 : row$x_lo;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_57 <= signal_mux_273;
        4'b0110:
            signal_cases_57 <= signal_mux_272;
        4'b0111:
            signal_cases_57 <= signal_mux_269;
        4'b1010:
            signal_cases_57 <= signal_mux_264;
        default:
            signal_cases_57 <= row$x_lo;
        endcase
    end
    assign signal_wire_34 = signal_cases_57;
    always @(posedge signal_wire_59) begin
        row$x_lo <= signal_wire_34;
    end
    assign signal_lt_30 = row$y_lo < row$x_lo;
    assign signal_mux_274 = signal_lt_30 ? row$x_lo : row$y_lo;
    assign signal_not_105 = ~ signal_eq_94;
    assign signal_and_25 = signal_not_105 & signal_and_111;
    assign signal_mux_275 = signal_and_25 ? signal_mux_274 : row$y_lo;
    assign signal_mux_276 = signal_and_112 ? signal_mux_254 : signal_mux_275;
    assign signal_const_181 = 3'b010;
    assign signal_eq_35 = signal_select_50 == signal_const_181;
    assign signal_eq_36 = signal_select_88 == signal_const_65;
    assign signal_and_26 = signal_eq_36 & signal_eq_35;
    assign signal_mux_277 = signal_and_26 ? signal_cat_59 : signal_mux_276;
    assign signal_eq_37 = signal_select_76 == signal_const_61;
    assign signal_const_185 = 3'b110;
    assign signal_eq_38 = signal_select_88 == signal_const_185;
    assign signal_and_27 = signal_eq_38 & signal_eq_37;
    assign signal_eq_39 = signal_select_77 == signal_const_181;
    assign signal_const_187 = 3'b011;
    assign signal_eq_40 = signal_select_88 == signal_const_187;
    assign signal_and_28 = signal_eq_40 & signal_eq_39;
    assign signal_eq_41 = signal_select_80 == signal_const_181;
    assign signal_eq_42 = signal_select_88 == signal_const_99;
    assign signal_and_29 = signal_eq_42 & signal_eq_41;
    assign signal_or_37 = signal_and_29 | signal_and_28;
    assign signal_or_38 = signal_or_37 | signal_and_27;
    assign signal_not_106 = ~ signal_or_38;
    assign signal_mux_278 = signal_not_106 ? signal_mux_277 : signal_const_131;
    assign fell$y_lo = signal_and_115 ? signal_mux_278 : signal_const_131;
    assign signal_mux_279 = falls_to_next ? fell$y_lo : signal_const_131;
    assign signal_mux_280 = stored ? row$y_lo : signal_mux_279;
    assign signal_mux_281 = target_fails ? row$y_lo : signal_mux_280;
    assign signal_mux_282 = next_fails ? row$y_lo : signal_mux_281;
    assign signal_select_39 = shifted[31:16];
    always @* begin
        case (field)
        3'b100:
            signal_cases_58 <= signal_select_39;
        default:
            signal_cases_58 <= row$y_lo;
        endcase
    end
    assign signal_mux_283 = signal_eq_104 ? signal_cases_58 : row$y_lo;
    assign signal_mux_284 = last_word ? signal_mux_283 : row$y_lo;
    assign signal_mux_285 = read_done ? signal_mux_284 : row$y_lo;
    assign signal_mux_286 = from_dictionary ? signal_mux_285 : row$y_lo;
    assign signal_mux_287 = signal_eq_116 ? row$y_lo : signal_mux_286;
    assign signal_mux_288 = signal_eq_109 ? signal_const_131 : row$y_lo;
    assign signal_mux_289 = signal_eq_110 ? signal_mux_288 : row$y_lo;
    assign signal_mux_290 = read_done ? signal_mux_289 : row$y_lo;
    assign signal_mux_291 = signal_wire_71 ? signal_const_131 : row$y_lo;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_59 <= signal_mux_291;
        4'b0110:
            signal_cases_59 <= signal_mux_290;
        4'b0111:
            signal_cases_59 <= signal_mux_287;
        4'b1010:
            signal_cases_59 <= signal_mux_282;
        default:
            signal_cases_59 <= row$y_lo;
        endcase
    end
    assign signal_wire_35 = signal_cases_59;
    always @(posedge signal_wire_59) begin
        row$y_lo <= signal_wire_35;
    end
    assign signal_cat_49 = { signal_const_31,
                             row$y_lo };
    assign signal_mux_292 = signal_and_43 ? signal_cat_49 : signal_mux_345;
    assign signal_mux_293 = signal_and_46 ? signal_cat_48 : signal_mux_292;
    assign signal_or_39 = signal_and_50 | signal_and_49;
    assign signal_mux_294 = signal_or_39 ? signal_cat_47 : signal_mux_293;
    assign signal_sub_9 = signal_cat_64 - signal_mux_294;
    assign signal_const_193 = 26'b00000000000000000000000000;
    assign signal_const_194 = 26'b00000000000000000000000001;
    assign signal_cat_50 = { signal_const_39,
                             row$arm_hi };
    assign signal_sub_10 = signal_cat_50 - signal_const_194;
    assign signal_const_197 = 26'b10000000000000000000000000;
    assign signal_select_40 = signal_mux_305[24:0];
    assign signal_select_41 = signal_mux_305[25:25];
    assign signal_not_107 = ~ signal_select_41;
    assign signal_cat_51 = { signal_not_107,
                             signal_select_40 };
    assign signal_lt_31 = signal_cat_51 < signal_const_197;
    assign signal_mux_295 = signal_lt_31 ? signal_const_193 : signal_mux_305;
    assign signal_select_42 = signal_cat_53[24:0];
    assign fell$offset_hi = signal_and_115 ? signal_const_134 : signal_const_134;
    assign signal_mux_296 = falls_to_next ? fell$offset_hi : signal_const_134;
    assign signal_mux_297 = stored ? row$offset_hi : signal_mux_296;
    assign signal_mux_298 = target_fails ? row$offset_hi : signal_mux_297;
    assign signal_mux_299 = next_fails ? row$offset_hi : signal_mux_298;
    assign signal_mux_300 = signal_eq_109 ? signal_const_134 : row$offset_hi;
    assign signal_mux_301 = signal_eq_110 ? signal_mux_300 : row$offset_hi;
    assign signal_mux_302 = read_done ? signal_mux_301 : row$offset_hi;
    assign signal_mux_303 = signal_wire_71 ? signal_const_134 : row$offset_hi;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_60 <= signal_mux_303;
        4'b0110:
            signal_cases_60 <= signal_mux_302;
        4'b1010:
            signal_cases_60 <= signal_mux_299;
        default:
            signal_cases_60 <= row$offset_hi;
        endcase
    end
    assign signal_wire_36 = signal_cases_60;
    always @(posedge signal_wire_59) begin
        row$offset_hi <= signal_wire_36;
    end
    assign signal_select_43 = row$offset_hi[23:23];
    assign signal_cat_52 = { signal_select_43,
                             signal_select_43 };
    assign signal_cat_53 = { signal_cat_52,
                             row$offset_hi };
    assign signal_select_44 = signal_cat_53[25:25];
    assign signal_not_108 = ~ signal_select_44;
    assign signal_cat_54 = { signal_not_108,
                             signal_select_42 };
    assign signal_select_45 = signal_cat_72[24:0];
    assign signal_select_46 = signal_cat_72[25:25];
    assign signal_not_109 = ~ signal_select_46;
    assign signal_cat_55 = { signal_not_109,
                             signal_select_45 };
    assign signal_lt_32 = signal_cat_55 < signal_cat_54;
    assign signal_mux_304 = signal_lt_32 ? signal_cat_72 : signal_cat_53;
    assign signal_mux_305 = signal_and_51 ? signal_mux_304 : signal_cat_72;
    assign signal_mux_306 = signal_and_94 ? signal_mux_295 : signal_mux_305;
    assign signal_mux_307 = signal_and_73 ? signal_sub_10 : signal_mux_306;
    assign signal_mux_308 = signal_and_91 ? signal_const_193 : signal_mux_307;
    assign signal_add_24 = signal_mux_308 + signal_sub_9;
    assign signal_select_47 = signal_add_24[25:25];
    assign signal_not_110 = ~ signal_select_47;
    assign signal_cat_56 = { signal_not_110,
                             signal_select_38 };
    assign signal_lt_33 = signal_const_137 < signal_cat_56;
    assign signal_not_111 = ~ signal_lt_33;
    assign signal_select_48 = signal_add_26[24:0];
    assign signal_wire_37 = config$period_fraction;
    assign signal_eq_43 = signal_wire_37 == signal_const_131;
    assign signal_not_112 = ~ signal_eq_43;
    assign signal_and_30 = signal_and_50 & signal_not_112;
    assign signal_const_204 = 25'b0000000000000000000000000;
    assign signal_cat_57 = { signal_const_204,
                             signal_and_30 };
    assign signal_wire_38 = setup$loaded$value;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            setup$loaded$value_0 <= signal_const_131;
        else
            if (signal_and_62)
                setup$loaded$value_0 <= signal_wire_38;
    end
    assign signal_mux_309 = signal_or_41 ? setup$loaded$value_0 : row$period_hi;
    assign signal_eq_44 = signal_select_50 == signal_const_99;
    assign signal_eq_45 = signal_select_88 == signal_const_65;
    assign signal_and_31 = signal_eq_45 & signal_eq_44;
    assign signal_mux_310 = signal_and_31 ? signal_cat_59 : signal_mux_309;
    assign signal_wire_39 = setup$loaded$valid;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            setup$loaded$valid_0 <= signal_const_33;
        else
            if (signal_and_62)
                setup$loaded$valid_0 <= signal_wire_39;
    end
    assign signal_not_113 = ~ setup$loaded$valid_0;
    assign signal_const_209 = 2'b10;
    assign signal_eq_46 = signal_select_76 == signal_const_209;
    assign signal_eq_47 = signal_select_88 == signal_const_185;
    assign signal_and_32 = signal_eq_47 & signal_eq_46;
    assign signal_eq_48 = signal_select_77 == signal_const_185;
    assign signal_eq_49 = signal_select_88 == signal_const_187;
    assign signal_and_33 = signal_eq_49 & signal_eq_48;
    assign signal_eq_50 = signal_select_80 == signal_const_185;
    assign signal_eq_51 = signal_select_88 == signal_const_99;
    assign signal_and_34 = signal_eq_51 & signal_eq_50;
    assign signal_or_40 = signal_and_34 | signal_and_33;
    assign signal_or_41 = signal_or_40 | signal_and_32;
    assign signal_and_35 = signal_or_41 & signal_not_113;
    assign signal_not_114 = ~ signal_and_35;
    assign signal_mux_311 = signal_not_114 ? signal_mux_310 : signal_const_217;
    assign fell$period_hi = signal_and_115 ? signal_mux_311 : signal_const_131;
    assign signal_mux_312 = falls_to_next ? fell$period_hi : signal_const_131;
    assign signal_mux_313 = stored ? row$period_hi : signal_mux_312;
    assign signal_mux_314 = target_fails ? row$period_hi : signal_mux_313;
    assign signal_mux_315 = next_fails ? row$period_hi : signal_mux_314;
    always @* begin
        case (field)
        3'b010:
            signal_cases_61 <= signal_select_86;
        default:
            signal_cases_61 <= row$period_hi;
        endcase
    end
    assign signal_mux_316 = signal_eq_104 ? signal_cases_61 : row$period_hi;
    assign signal_mux_317 = last_word ? signal_mux_316 : row$period_hi;
    assign signal_mux_318 = read_done ? signal_mux_317 : row$period_hi;
    assign signal_mux_319 = from_dictionary ? signal_mux_318 : row$period_hi;
    assign signal_mux_320 = signal_eq_116 ? row$period_hi : signal_mux_319;
    assign signal_mux_321 = signal_eq_109 ? signal_const_217 : row$period_hi;
    assign signal_mux_322 = signal_eq_110 ? signal_mux_321 : row$period_hi;
    assign signal_mux_323 = read_done ? signal_mux_322 : row$period_hi;
    assign signal_const_217 = 16'b1111111111111111;
    assign signal_mux_324 = signal_wire_71 ? signal_const_217 : row$period_hi;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_62 <= signal_mux_324;
        4'b0110:
            signal_cases_62 <= signal_mux_323;
        4'b0111:
            signal_cases_62 <= signal_mux_320;
        4'b1010:
            signal_cases_62 <= signal_mux_315;
        default:
            signal_cases_62 <= row$period_hi;
        endcase
    end
    assign signal_wire_40 = signal_cases_62;
    always @(posedge signal_wire_59) begin
        row$period_hi <= signal_wire_40;
    end
    assign signal_cat_58 = { signal_const_31,
                             row$period_hi };
    assign signal_add_25 = signal_cat_58 + signal_cat_57;
    assign signal_select_49 = word[4:0];
    assign signal_const_219 = 11'b00000000000;
    assign signal_cat_59 = { signal_const_219,
                             signal_select_49 };
    assign signal_sub_11 = row$x_hi - signal_const_141;
    assign signal_mux_325 = signal_eq_94 ? signal_sub_11 : signal_const_217;
    assign signal_lt_34 = row$x_hi < row$y_hi;
    assign signal_mux_326 = signal_lt_34 ? row$x_hi : row$y_hi;
    assign signal_not_115 = ~ signal_eq_94;
    assign signal_and_36 = signal_not_115 & signal_and_111;
    assign signal_mux_327 = signal_and_36 ? signal_mux_326 : row$x_hi;
    assign signal_mux_328 = signal_and_113 ? signal_mux_325 : signal_mux_327;
    assign signal_select_50 = word[7:5];
    assign signal_eq_52 = signal_select_50 == signal_const_68;
    assign signal_eq_53 = signal_select_88 == signal_const_65;
    assign signal_and_37 = signal_eq_53 & signal_eq_52;
    assign signal_mux_329 = signal_and_37 ? signal_cat_59 : signal_mux_328;
    assign signal_eq_54 = signal_select_76 == signal_const_39;
    assign signal_eq_55 = signal_select_88 == signal_const_185;
    assign signal_and_38 = signal_eq_55 & signal_eq_54;
    assign signal_eq_56 = signal_select_77 == signal_const_68;
    assign signal_eq_57 = signal_select_88 == signal_const_187;
    assign signal_and_39 = signal_eq_57 & signal_eq_56;
    assign signal_eq_58 = signal_select_80 == signal_const_68;
    assign signal_eq_59 = signal_select_88 == signal_const_99;
    assign signal_and_40 = signal_eq_59 & signal_eq_58;
    assign signal_or_42 = signal_and_40 | signal_and_39;
    assign signal_or_43 = signal_or_42 | signal_and_38;
    assign signal_not_116 = ~ signal_or_43;
    assign signal_mux_330 = signal_not_116 ? signal_mux_329 : signal_const_217;
    assign fell$x_hi = signal_and_115 ? signal_mux_330 : signal_const_131;
    assign signal_mux_331 = falls_to_next ? fell$x_hi : signal_const_131;
    assign signal_mux_332 = stored ? row$x_hi : signal_mux_331;
    assign signal_mux_333 = target_fails ? row$x_hi : signal_mux_332;
    assign signal_mux_334 = next_fails ? row$x_hi : signal_mux_333;
    always @* begin
        case (field)
        3'b011:
            signal_cases_63 <= signal_select_86;
        default:
            signal_cases_63 <= row$x_hi;
        endcase
    end
    assign signal_mux_335 = signal_eq_104 ? signal_cases_63 : row$x_hi;
    assign signal_mux_336 = last_word ? signal_mux_335 : row$x_hi;
    assign signal_mux_337 = read_done ? signal_mux_336 : row$x_hi;
    assign signal_mux_338 = from_dictionary ? signal_mux_337 : row$x_hi;
    assign signal_mux_339 = signal_eq_116 ? row$x_hi : signal_mux_338;
    assign signal_mux_340 = signal_eq_109 ? signal_const_217 : row$x_hi;
    assign signal_mux_341 = signal_eq_110 ? signal_mux_340 : row$x_hi;
    assign signal_mux_342 = read_done ? signal_mux_341 : row$x_hi;
    assign signal_mux_343 = signal_wire_71 ? signal_const_217 : row$x_hi;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_64 <= signal_mux_343;
        4'b0110:
            signal_cases_64 <= signal_mux_342;
        4'b0111:
            signal_cases_64 <= signal_mux_339;
        4'b1010:
            signal_cases_64 <= signal_mux_334;
        default:
            signal_cases_64 <= row$x_hi;
        endcase
    end
    assign signal_wire_41 = signal_cases_64;
    always @(posedge signal_wire_59) begin
        row$x_hi <= signal_wire_41;
    end
    assign signal_cat_60 = { signal_const_31,
                             row$x_hi };
    assign signal_cat_61 = { signal_const_31,
                             row$y_hi };
    assign signal_const_235 = 21'b000000000000000000000;
    assign signal_cat_62 = { signal_const_235,
                             signal_select_73 };
    assign signal_cat_63 = { signal_const_39,
                             signal_cat_62 };
    assign signal_sub_12 = signal_const_193 - signal_cat_63;
    assign signal_mux_344 = signal_and_75 ? signal_sub_12 : signal_const_193;
    assign signal_mux_345 = signal_and_86 ? signal_cat_63 : signal_mux_344;
    assign signal_eq_60 = signal_select_73 == signal_const_68;
    assign signal_and_41 = signal_and_87 & signal_eq_80;
    assign signal_and_42 = signal_and_41 & signal_select_74;
    assign signal_and_43 = signal_and_42 & signal_eq_60;
    assign signal_mux_346 = signal_and_43 ? signal_cat_61 : signal_mux_345;
    assign signal_eq_61 = signal_select_73 == signal_const_66;
    assign signal_and_44 = signal_and_87 & signal_eq_80;
    assign signal_and_45 = signal_and_44 & signal_select_74;
    assign signal_and_46 = signal_and_45 & signal_eq_61;
    assign signal_mux_347 = signal_and_46 ? signal_cat_60 : signal_mux_346;
    assign signal_eq_62 = signal_select_73 == signal_const_181;
    assign signal_and_47 = signal_and_87 & signal_eq_80;
    assign signal_and_48 = signal_and_47 & signal_select_74;
    assign signal_and_49 = signal_and_48 & signal_eq_62;
    assign signal_and_50 = signal_and_94 & signal_select_69;
    assign signal_or_44 = signal_and_50 | signal_and_49;
    assign signal_mux_348 = signal_or_44 ? signal_add_25 : signal_mux_347;
    assign signal_cat_64 = { signal_const_39,
                             signal_mux_381 };
    assign signal_sub_13 = signal_cat_64 - signal_mux_348;
    assign signal_select_51 = signal_mux_359[24:0];
    assign signal_select_52 = signal_mux_359[25:25];
    assign signal_not_117 = ~ signal_select_52;
    assign signal_cat_65 = { signal_not_117,
                             signal_select_51 };
    assign signal_lt_35 = signal_cat_65 < signal_const_197;
    assign signal_mux_349 = signal_lt_35 ? signal_const_193 : signal_mux_359;
    assign signal_select_53 = signal_cat_77[24:0];
    assign signal_select_54 = signal_cat_77[25:25];
    assign signal_not_118 = ~ signal_select_54;
    assign signal_cat_66 = { signal_not_118,
                             signal_select_53 };
    assign signal_select_55 = signal_cat_68[24:0];
    assign fell$offset_lo = signal_and_115 ? signal_const_110 : signal_const_110;
    assign signal_mux_350 = falls_to_next ? fell$offset_lo : signal_const_110;
    assign signal_mux_351 = stored ? row$offset_lo : signal_mux_350;
    assign signal_mux_352 = target_fails ? row$offset_lo : signal_mux_351;
    assign signal_mux_353 = next_fails ? row$offset_lo : signal_mux_352;
    assign signal_mux_354 = signal_eq_109 ? signal_const_110 : row$offset_lo;
    assign signal_mux_355 = signal_eq_110 ? signal_mux_354 : row$offset_lo;
    assign signal_mux_356 = read_done ? signal_mux_355 : row$offset_lo;
    assign signal_mux_357 = signal_wire_71 ? signal_const_110 : row$offset_lo;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_65 <= signal_mux_357;
        4'b0110:
            signal_cases_65 <= signal_mux_356;
        4'b1010:
            signal_cases_65 <= signal_mux_353;
        default:
            signal_cases_65 <= row$offset_lo;
        endcase
    end
    assign signal_wire_42 = signal_cases_65;
    always @(posedge signal_wire_59) begin
        row$offset_lo <= signal_wire_42;
    end
    assign signal_select_56 = row$offset_lo[23:23];
    assign signal_cat_67 = { signal_select_56,
                             signal_select_56 };
    assign signal_cat_68 = { signal_cat_67,
                             row$offset_lo };
    assign signal_select_57 = signal_cat_68[25:25];
    assign signal_not_119 = ~ signal_select_57;
    assign signal_cat_69 = { signal_not_119,
                             signal_select_55 };
    assign signal_lt_36 = signal_cat_69 < signal_cat_66;
    assign signal_mux_358 = signal_lt_36 ? signal_cat_77 : signal_cat_68;
    assign signal_not_120 = ~ signal_eq_94;
    assign signal_and_51 = signal_and_113 & signal_not_120;
    assign signal_mux_359 = signal_and_51 ? signal_mux_358 : signal_cat_77;
    assign signal_mux_360 = signal_and_94 ? signal_mux_349 : signal_mux_359;
    assign signal_mux_361 = signal_and_73 ? signal_const_194 : signal_mux_360;
    assign signal_mux_362 = signal_and_91 ? signal_const_193 : signal_mux_361;
    assign signal_add_26 = signal_mux_362 + signal_sub_13;
    assign signal_select_58 = signal_add_26[25:25];
    assign signal_not_121 = ~ signal_select_58;
    assign signal_cat_70 = { signal_not_121,
                             signal_select_48 };
    assign signal_lt_37 = signal_cat_70 < signal_const_138;
    assign signal_not_122 = ~ signal_lt_37;
    assign signal_and_52 = signal_not_122 & signal_not_111;
    assign signal_eq_63 = row$arm_hi == signal_const_147;
    assign signal_select_59 = signal_sub_14[24:0];
    assign signal_select_60 = row$phase_hi[23:23];
    assign signal_cat_71 = { signal_select_60,
                             signal_select_60 };
    assign signal_cat_72 = { signal_cat_71,
                             row$phase_hi };
    assign signal_sub_14 = signal_const_193 - signal_cat_72;
    assign signal_select_61 = signal_sub_14[25:25];
    assign signal_not_123 = ~ signal_select_61;
    assign signal_cat_73 = { signal_not_123,
                             signal_select_59 };
    assign signal_lt_38 = signal_cat_73 < signal_const_197;
    assign signal_mux_363 = signal_lt_38 ? signal_const_193 : signal_sub_14;
    assign signal_cat_74 = { signal_const_39,
                             row$arm_lo };
    assign signal_add_27 = signal_cat_74 + signal_mux_363;
    assign signal_add_28 = signal_add_27 + signal_cat_81;
    assign signal_cat_75 = { signal_const_39,
                             row$arm_lo };
    assign signal_add_29 = signal_cat_75 + signal_cat_81;
    assign signal_mux_364 = signal_and_94 ? signal_add_28 : signal_add_29;
    assign signal_mux_365 = signal_and_69 ? signal_cat_81 : signal_mux_364;
    assign signal_select_62 = signal_mux_365[23:0];
    assign signal_const_258 = 26'b00100000000000000000000000;
    assign signal_select_63 = signal_sub_15[24:0];
    assign signal_const_261 = 24'b000000000000000000000001;
    assign signal_mux_366 = falls_to_next ? fell$phase_lo : signal_const_261;
    assign signal_mux_367 = stored ? row$phase_lo : signal_mux_366;
    assign signal_mux_368 = target_fails ? row$phase_lo : signal_mux_367;
    assign signal_mux_369 = next_fails ? row$phase_lo : signal_mux_368;
    always @* begin
        case (field)
        3'b000:
            signal_cases_66 <= signal_select_68;
        default:
            signal_cases_66 <= row$phase_lo;
        endcase
    end
    assign signal_mux_370 = signal_eq_104 ? signal_cases_66 : row$phase_lo;
    assign signal_mux_371 = last_word ? signal_mux_370 : row$phase_lo;
    assign signal_mux_372 = read_done ? signal_mux_371 : row$phase_lo;
    assign signal_mux_373 = from_dictionary ? signal_mux_372 : row$phase_lo;
    assign signal_mux_374 = signal_eq_116 ? row$phase_lo : signal_mux_373;
    assign signal_mux_375 = signal_eq_109 ? signal_const_110 : row$phase_lo;
    assign signal_mux_376 = signal_eq_110 ? signal_mux_375 : row$phase_lo;
    assign signal_mux_377 = read_done ? signal_mux_376 : row$phase_lo;
    assign signal_mux_378 = signal_wire_71 ? signal_const_110 : row$phase_lo;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_67 <= signal_mux_378;
        4'b0110:
            signal_cases_67 <= signal_mux_377;
        4'b0111:
            signal_cases_67 <= signal_mux_374;
        4'b1010:
            signal_cases_67 <= signal_mux_369;
        default:
            signal_cases_67 <= row$phase_lo;
        endcase
    end
    assign signal_wire_43 = signal_cases_67;
    always @(posedge signal_wire_59) begin
        row$phase_lo <= signal_wire_43;
    end
    assign signal_select_64 = row$phase_lo[23:23];
    assign signal_cat_76 = { signal_select_64,
                             signal_select_64 };
    assign signal_cat_77 = { signal_cat_76,
                             row$phase_lo };
    assign signal_sub_15 = signal_const_193 - signal_cat_77;
    assign signal_select_65 = signal_sub_15[25:25];
    assign signal_not_124 = ~ signal_select_65;
    assign signal_cat_78 = { signal_not_124,
                             signal_select_63 };
    assign signal_lt_39 = signal_cat_78 < signal_const_197;
    assign signal_mux_379 = signal_lt_39 ? signal_const_193 : signal_sub_15;
    assign signal_cat_79 = { signal_const_39,
                             row$arm_hi };
    assign signal_add_30 = signal_cat_79 + signal_mux_379;
    assign signal_add_31 = signal_add_30 + signal_cat_81;
    assign signal_const_265 = 24'b000000000000000000000010;
    assign signal_and_53 = signal_select_66 & signal_const_9;
    assign signal_and_54 = signal_select_66 & signal_const_9;
    assign signal_and_55 = signal_select_66 & signal_const_16;
    assign signal_select_66 = word[12:8];
    assign signal_wire_44 = config$side_set_count;
    always @* begin
        case (signal_wire_44)
        0:
            signal_mux_380 <= signal_select_66;
        1:
            signal_mux_380 <= signal_and_55;
        2:
            signal_mux_380 <= signal_and_54;
        default:
            signal_mux_380 <= signal_and_53;
        endcase
    end
    assign signal_const_270 = 19'b0000000000000000000;
    assign signal_cat_80 = { signal_const_270,
                             signal_mux_380 };
    assign signal_add_32 = signal_cat_80 + signal_const_261;
    assign signal_mux_381 = signal_eq_100 ? signal_const_265 : signal_add_32;
    assign signal_cat_81 = { signal_const_39,
                             signal_mux_381 };
    assign signal_select_67 = signal_mux_397[23:0];
    assign signal_mux_382 = signal_or_45 ? signal_select_67 : signal_const_147;
    assign fell$arm_hi = signal_and_115 ? signal_mux_382 : signal_const_135;
    assign signal_mux_383 = falls_to_next ? fell$arm_hi : signal_const_135;
    assign signal_mux_384 = stored ? row$arm_hi : signal_mux_383;
    assign signal_mux_385 = target_fails ? row$arm_hi : signal_mux_384;
    assign signal_mux_386 = next_fails ? row$arm_hi : signal_mux_385;
    always @* begin
        case (field)
        3'b001:
            signal_cases_68 <= signal_select_90;
        default:
            signal_cases_68 <= row$arm_hi;
        endcase
    end
    assign signal_mux_387 = signal_eq_104 ? signal_cases_68 : row$arm_hi;
    assign signal_mux_388 = last_word ? signal_mux_387 : row$arm_hi;
    assign signal_mux_389 = read_done ? signal_mux_388 : row$arm_hi;
    assign signal_mux_390 = from_dictionary ? signal_mux_389 : row$arm_hi;
    assign signal_mux_391 = signal_eq_116 ? row$arm_hi : signal_mux_390;
    assign signal_mux_392 = signal_eq_109 ? signal_const_147 : row$arm_hi;
    assign signal_mux_393 = signal_eq_110 ? signal_mux_392 : row$arm_hi;
    assign signal_mux_394 = read_done ? signal_mux_393 : row$arm_hi;
    assign signal_mux_395 = signal_wire_71 ? signal_const_147 : row$arm_hi;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_69 <= signal_mux_395;
        4'b0110:
            signal_cases_69 <= signal_mux_394;
        4'b0111:
            signal_cases_69 <= signal_mux_391;
        4'b1010:
            signal_cases_69 <= signal_mux_386;
        default:
            signal_cases_69 <= row$arm_hi;
        endcase
    end
    assign signal_wire_45 = signal_cases_69;
    always @(posedge signal_wire_59) begin
        row$arm_hi <= signal_wire_45;
    end
    assign signal_cat_82 = { signal_const_39,
                             row$arm_hi };
    assign signal_add_33 = signal_cat_82 + signal_cat_81;
    assign signal_mux_396 = signal_and_94 ? signal_add_31 : signal_add_33;
    assign signal_mux_397 = signal_and_69 ? signal_cat_81 : signal_mux_396;
    assign signal_lt_40 = signal_mux_397 < signal_const_258;
    assign signal_not_125 = ~ signal_and_67;
    assign signal_not_126 = ~ signal_and_94;
    assign signal_eq_64 = signal_select_88 == signal_const_68;
    assign signal_and_56 = signal_eq_64 & signal_not_126;
    assign signal_and_57 = signal_and_56 & signal_not_125;
    assign signal_not_127 = ~ signal_and_57;
    assign signal_and_58 = signal_not_128 & signal_not_127;
    assign signal_and_59 = signal_and_58 & signal_lt_40;
    assign signal_or_45 = signal_and_69 | signal_and_59;
    assign signal_mux_398 = signal_or_45 ? signal_select_62 : signal_const_135;
    assign fell$arm_lo = signal_and_115 ? signal_mux_398 : signal_const_135;
    assign signal_mux_399 = falls_to_next ? fell$arm_lo : signal_const_135;
    assign signal_mux_400 = stored ? row$arm_lo : signal_mux_399;
    assign signal_mux_401 = target_fails ? row$arm_lo : signal_mux_400;
    assign signal_mux_402 = next_fails ? row$arm_lo : signal_mux_401;
    assign signal_select_68 = shifted[47:24];
    always @* begin
        case (field)
        3'b001:
            signal_cases_70 <= signal_select_68;
        default:
            signal_cases_70 <= row$arm_lo;
        endcase
    end
    assign signal_mux_403 = signal_eq_104 ? signal_cases_70 : row$arm_lo;
    assign signal_mux_404 = last_word ? signal_mux_403 : row$arm_lo;
    assign signal_mux_405 = read_done ? signal_mux_404 : row$arm_lo;
    assign signal_mux_406 = from_dictionary ? signal_mux_405 : row$arm_lo;
    assign signal_mux_407 = signal_eq_116 ? row$arm_lo : signal_mux_406;
    assign signal_mux_408 = signal_eq_109 ? signal_const_135 : row$arm_lo;
    assign signal_mux_409 = signal_eq_110 ? signal_mux_408 : row$arm_lo;
    assign signal_mux_410 = read_done ? signal_mux_409 : row$arm_lo;
    assign signal_mux_411 = signal_wire_71 ? signal_const_135 : row$arm_lo;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_71 <= signal_mux_411;
        4'b0110:
            signal_cases_71 <= signal_mux_410;
        4'b0111:
            signal_cases_71 <= signal_mux_407;
        4'b1010:
            signal_cases_71 <= signal_mux_402;
        default:
            signal_cases_71 <= row$arm_lo;
        endcase
    end
    assign signal_wire_46 = signal_cases_71;
    always @(posedge signal_wire_59) begin
        row$arm_lo <= signal_wire_46;
    end
    assign signal_eq_65 = row$arm_lo == signal_const_135;
    assign signal_and_60 = signal_eq_65 & signal_eq_63;
    assign signal_not_128 = ~ signal_and_60;
    assign signal_not_129 = ~ signal_and_66;
    assign signal_and_61 = row$awaiting & signal_not_129;
    assign signal_mux_412 = signal_and_69 ? vdd : signal_and_61;
    assign fell$awaiting = signal_and_115 ? signal_mux_412 : signal_const_33;
    assign signal_mux_413 = falls_to_next ? fell$awaiting : signal_const_33;
    assign signal_mux_414 = stored ? row$awaiting : signal_mux_413;
    assign signal_mux_415 = target_fails ? row$awaiting : signal_mux_414;
    assign signal_mux_416 = next_fails ? row$awaiting : signal_mux_415;
    assign arriving$awaiting = signal_select_72[35:35];
    assign signal_mux_417 = signal_eq_109 ? arriving$awaiting : row$awaiting;
    assign signal_mux_418 = signal_eq_110 ? signal_mux_417 : row$awaiting;
    assign signal_mux_419 = read_done ? signal_mux_418 : row$awaiting;
    assign signal_mux_420 = signal_wire_71 ? signal_const_33 : row$awaiting;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_72 <= signal_mux_420;
        4'b0110:
            signal_cases_72 <= signal_mux_419;
        4'b1010:
            signal_cases_72 <= signal_mux_416;
        default:
            signal_cases_72 <= row$awaiting;
        endcase
    end
    assign signal_wire_47 = signal_cases_72;
    always @(posedge signal_wire_59) begin
        row$awaiting <= signal_wire_47;
    end
    assign signal_wire_48 = config$capture_rising;
    assign signal_select_69 = word[7:7];
    assign signal_eq_66 = signal_select_69 == signal_wire_48;
    assign signal_wire_49 = config$capture_pin;
    assign signal_select_70 = word[4:0];
    assign signal_eq_67 = signal_select_70 == signal_wire_49;
    assign signal_eq_68 = signal_const_57 == sm;
    assign signal_and_62 = signal_eq_68 & signal_wire_71;
    assign signal_wire_50 = setup$single_edge;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            setup$single_edge_0 <= signal_const_33;
        else
            if (signal_and_62)
                setup$single_edge_0 <= signal_wire_50;
    end
    assign signal_eq_69 = signal_select_81 == signal_const_61;
    assign signal_eq_70 = signal_select_81 == signal_const_39;
    assign signal_or_46 = signal_eq_70 | signal_eq_69;
    assign signal_eq_71 = signal_select_88 == signal_const_68;
    assign signal_and_63 = signal_eq_71 & signal_or_46;
    assign signal_and_64 = signal_and_63 & setup$single_edge_0;
    assign signal_and_65 = signal_and_64 & signal_eq_67;
    assign signal_and_66 = signal_and_65 & signal_eq_66;
    assign signal_and_67 = signal_and_66 & row$awaiting;
    assign signal_and_68 = signal_and_67 & signal_not_128;
    assign signal_or_47 = row$captured | signal_and_68;
    assign signal_select_71 = word[3:0];
    assign signal_eq_72 = signal_select_71 == signal_const_354;
    assign signal_eq_73 = signal_select_88 == signal_const_112;
    assign signal_and_69 = signal_eq_73 & signal_eq_72;
    assign signal_mux_421 = signal_and_69 ? gnd : signal_or_47;
    assign fell$captured = signal_and_115 ? signal_mux_421 : signal_const_33;
    assign signal_mux_422 = falls_to_next ? fell$captured : signal_const_33;
    assign signal_mux_423 = stored ? row$captured : signal_mux_422;
    assign signal_mux_424 = target_fails ? row$captured : signal_mux_423;
    assign signal_mux_425 = next_fails ? row$captured : signal_mux_424;
    assign signal_select_72 = entry_shifted[47:2];
    assign arriving$captured = signal_select_72[36:36];
    assign signal_mux_426 = signal_eq_109 ? arriving$captured : row$captured;
    assign signal_mux_427 = signal_eq_110 ? signal_mux_426 : row$captured;
    assign signal_mux_428 = read_done ? signal_mux_427 : row$captured;
    assign signal_mux_429 = signal_wire_71 ? signal_const_33 : row$captured;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_73 <= signal_mux_429;
        4'b0110:
            signal_cases_73 <= signal_mux_428;
        4'b1010:
            signal_cases_73 <= signal_mux_425;
        default:
            signal_cases_73 <= row$captured;
        endcase
    end
    assign signal_wire_51 = signal_cases_73;
    always @(posedge signal_wire_59) begin
        row$captured <= signal_wire_51;
    end
    assign signal_eq_74 = signal_select_78 == signal_const_112;
    assign signal_eq_75 = signal_select_79 == signal_const_39;
    assign signal_and_70 = signal_and_92 & signal_eq_75;
    assign signal_and_71 = signal_and_70 & signal_eq_74;
    assign signal_and_72 = signal_and_71 & row$captured;
    assign signal_and_73 = signal_and_72 & signal_not_128;
    assign signal_not_130 = ~ signal_select_74;
    assign signal_eq_76 = signal_select_75 == signal_const_61;
    assign signal_and_74 = signal_and_87 & signal_eq_76;
    assign signal_and_75 = signal_and_74 & signal_not_130;
    assign signal_eq_77 = signal_select_73 == signal_const_68;
    assign signal_and_76 = signal_and_87 & signal_eq_80;
    assign signal_and_77 = signal_and_76 & signal_select_74;
    assign signal_and_78 = signal_and_77 & signal_eq_77;
    assign signal_eq_78 = signal_select_73 == signal_const_66;
    assign signal_and_79 = signal_and_87 & signal_eq_80;
    assign signal_and_80 = signal_and_79 & signal_select_74;
    assign signal_and_81 = signal_and_80 & signal_eq_78;
    assign signal_select_73 = word[2:0];
    assign signal_eq_79 = signal_select_73 == signal_const_181;
    assign signal_and_82 = signal_and_87 & signal_eq_80;
    assign signal_and_83 = signal_and_82 & signal_select_74;
    assign signal_and_84 = signal_and_83 & signal_eq_79;
    assign signal_select_74 = word[3:3];
    assign signal_not_131 = ~ signal_select_74;
    assign signal_select_75 = word[5:4];
    assign signal_eq_80 = signal_select_75 == signal_const_39;
    assign signal_and_85 = signal_and_87 & signal_eq_80;
    assign signal_and_86 = signal_and_85 & signal_not_131;
    assign signal_or_48 = signal_and_86 | signal_and_84;
    assign signal_or_49 = signal_or_48 | signal_and_81;
    assign signal_or_50 = signal_or_49 | signal_and_78;
    assign signal_or_51 = signal_or_50 | signal_and_75;
    assign signal_not_132 = ~ signal_or_51;
    assign signal_select_76 = word[7:6];
    assign signal_eq_81 = signal_select_76 == signal_const_59;
    assign signal_eq_82 = signal_select_88 == signal_const_185;
    assign signal_and_87 = signal_eq_82 & signal_eq_81;
    assign signal_and_88 = signal_and_87 & signal_not_132;
    assign signal_select_77 = word[7:5];
    assign signal_eq_83 = signal_select_77 == signal_const_112;
    assign signal_eq_84 = signal_select_88 == signal_const_187;
    assign signal_and_89 = signal_eq_84 & signal_eq_83;
    assign signal_select_78 = word[2:0];
    assign signal_eq_85 = signal_select_78 == signal_const_185;
    assign signal_select_79 = word[4:3];
    assign signal_eq_86 = signal_select_79 == signal_const_39;
    assign signal_and_90 = signal_and_92 & signal_eq_86;
    assign signal_and_91 = signal_and_90 & signal_eq_85;
    assign signal_not_133 = ~ signal_and_91;
    assign signal_select_80 = word[7:5];
    assign signal_eq_87 = signal_select_80 == signal_const_112;
    assign signal_eq_88 = signal_select_88 == signal_const_99;
    assign signal_and_92 = signal_eq_88 & signal_eq_87;
    assign signal_and_93 = signal_and_92 & signal_not_133;
    assign signal_select_81 = word[6:5];
    assign signal_eq_89 = signal_select_81 == signal_const_209;
    assign signal_eq_90 = signal_select_88 == signal_const_68;
    assign signal_and_94 = signal_eq_90 & signal_eq_89;
    assign signal_not_134 = ~ signal_and_94;
    assign signal_eq_91 = signal_select_88 == signal_const_68;
    assign signal_and_95 = signal_eq_91 & signal_not_134;
    assign signal_or_52 = signal_and_95 | signal_and_93;
    assign signal_or_53 = signal_or_52 | signal_and_89;
    assign signal_or_54 = signal_or_53 | signal_and_88;
    assign signal_not_135 = ~ signal_or_54;
    assign signal_or_55 = signal_not_135 | signal_and_73;
    assign signal_and_96 = signal_or_55 & signal_and_52;
    assign signal_and_97 = signal_and_96 & signal_not_104;
    assign signal_and_98 = signal_and_97 & signal_not_101;
    assign signal_const_308 = 26'b00011111111111111111111111;
    assign signal_select_82 = acc[23:0];
    assign signal_select_83 = signal_select_82[23:23];
    assign signal_cat_83 = { signal_select_83,
                             signal_select_83 };
    assign signal_cat_84 = { signal_cat_83,
                             signal_select_82 };
    assign signal_eq_92 = signal_cat_84 == signal_const_308;
    assign signal_const_309 = 26'b11100000000000000000000000;
    assign signal_select_84 = acc[47:24];
    assign signal_select_85 = signal_select_84[23:23];
    assign signal_cat_85 = { signal_select_85,
                             signal_select_85 };
    assign signal_cat_86 = { signal_cat_85,
                             signal_select_84 };
    assign signal_eq_93 = signal_cat_86 == signal_const_309;
    assign signal_and_99 = signal_eq_93 & signal_eq_92;
    assign signal_or_56 = signal_and_99 | signal_and_98;
    assign signal_eq_94 = signal_const_66 == purpose;
    assign signal_not_136 = ~ signal_eq_94;
    assign signal_and_100 = signal_and_115 & signal_not_136;
    assign signal_not_137 = ~ signal_and_100;
    assign signal_or_57 = signal_not_137 | signal_or_56;
    assign way$phase = signal_or_57 & signal_or_36;
    assign signal_not_138 = ~ way$phase;
    always @* begin
        case (field)
        3'b000:
            signal_cases_74 <= signal_not_138;
        default:
            signal_cases_74 <= failed_target$phase;
        endcase
    end
    assign signal_eq_95 = signal_const_66 == purpose;
    assign signal_mux_430 = signal_eq_95 ? signal_cases_74 : failed_target$phase;
    assign signal_mux_431 = signal_eq_115 ? gnd : failed_target$phase;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_75 <= signal_mux_431;
        4'b1000:
            signal_cases_75 <= signal_mux_430;
        default:
            signal_cases_75 <= failed_target$phase;
        endcase
    end
    assign signal_wire_52 = signal_cases_75;
    always @(posedge signal_wire_59) begin
        failed_target$phase <= signal_wire_52;
    end
    assign signal_not_139 = ~ failed_target$phase;
    assign signal_and_101 = signal_not_139 & signal_not_94;
    assign signal_and_102 = signal_and_101 & signal_not_93;
    assign signal_and_103 = signal_and_102 & signal_not_86;
    assign signal_and_104 = signal_and_103 & signal_not_79;
    assign signal_and_105 = signal_and_104 & signal_not_72;
    assign signal_and_106 = signal_and_105 & signal_not_66;
    assign signal_and_107 = signal_and_106 & signal_not_61;
    assign signal_and_108 = signal_and_107 & signal_not_56;
    assign signal_and_109 = signal_and_108 & signal_not_55;
    assign target_fails = ~ signal_and_109;
    assign signal_mux_432 = target_fails ? row$y_hi : signal_mux_189;
    assign signal_mux_433 = next_fails ? row$y_hi : signal_mux_432;
    assign signal_select_86 = shifted[15:0];
    always @* begin
        case (field)
        3'b100:
            signal_cases_76 <= signal_select_86;
        default:
            signal_cases_76 <= row$y_hi;
        endcase
    end
    assign signal_mux_434 = signal_eq_104 ? signal_cases_76 : row$y_hi;
    assign signal_mux_435 = last_word ? signal_mux_434 : row$y_hi;
    assign signal_mux_436 = read_done ? signal_mux_435 : row$y_hi;
    assign signal_mux_437 = from_dictionary ? signal_mux_436 : row$y_hi;
    assign signal_mux_438 = signal_eq_116 ? row$y_hi : signal_mux_437;
    assign signal_mux_439 = signal_eq_109 ? signal_const_217 : row$y_hi;
    assign signal_mux_440 = signal_eq_110 ? signal_mux_439 : row$y_hi;
    assign signal_mux_441 = read_done ? signal_mux_440 : row$y_hi;
    assign signal_mux_442 = signal_wire_71 ? signal_const_217 : row$y_hi;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_77 <= signal_mux_442;
        4'b0110:
            signal_cases_77 <= signal_mux_441;
        4'b0111:
            signal_cases_77 <= signal_mux_438;
        4'b1010:
            signal_cases_77 <= signal_mux_433;
        default:
            signal_cases_77 <= row$y_hi;
        endcase
    end
    assign signal_wire_53 = signal_cases_77;
    always @(posedge signal_wire_59) begin
        row$y_hi <= signal_wire_53;
    end
    assign signal_lt_41 = row$y_hi < row$x_lo;
    assign signal_not_140 = ~ signal_lt_41;
    assign signal_and_110 = signal_not_140 & signal_not_54;
    assign signal_eq_96 = signal_select_87 == signal_const_356;
    assign signal_and_111 = signal_eq_100 & signal_eq_96;
    assign signal_mux_443 = signal_and_111 ? signal_and_110 : vdd;
    assign signal_const_315 = 4'b0010;
    assign signal_eq_97 = signal_select_87 == signal_const_315;
    assign signal_and_112 = signal_eq_100 & signal_eq_97;
    assign signal_mux_444 = signal_and_112 ? signal_eq_13 : signal_mux_443;
    assign signal_eq_98 = signal_select_87 == signal_const_111;
    assign signal_and_113 = signal_eq_100 & signal_eq_98;
    assign signal_mux_445 = signal_and_113 ? signal_eq_12 : signal_mux_444;
    assign signal_select_87 = word[12:9];
    assign signal_eq_99 = signal_select_87 == signal_const_57;
    assign signal_and_114 = signal_eq_100 & signal_eq_99;
    assign signal_mux_446 = signal_and_114 ? gnd : signal_mux_445;
    assign signal_select_88 = word[15:13];
    assign signal_eq_100 = signal_select_88 == signal_const_66;
    assign signal_not_141 = ~ signal_eq_100;
    assign signal_or_58 = signal_not_141 | signal_mux_446;
    assign signal_and_115 = signal_and_116 & signal_or_58;
    assign fell$phase_lo = signal_and_115 ? signal_mux_182 : signal_const_261;
    assign signal_cat_87 = { fell$phase_lo,
                             fell$phase_hi };
    always @* begin
        case (field)
        0:
            signal_mux_447 <= signal_cat_87;
        1:
            signal_mux_447 <= signal_cat_34;
        2:
            signal_mux_447 <= signal_cat_33;
        3:
            signal_mux_447 <= signal_cat_31;
        default:
            signal_mux_447 <= signal_cat_29;
        endcase
    end
    assign signal_const_319 = 48'b000000000000000000000000000000000000000000000000;
    assign signal_const_323 = 48'b000000000000000000000001000000000000000000000000;
    always @* begin
        case (field)
        0:
            signal_mux_448 <= signal_const_323;
        1:
            signal_mux_448 <= signal_const_319;
        2:
            signal_mux_448 <= signal_const_319;
        3:
            signal_mux_448 <= signal_const_319;
        default:
            signal_mux_448 <= signal_const_319;
        endcase
    end
    assign signal_eq_101 = signal_const_209 == source;
    assign signal_mux_449 = signal_eq_101 ? signal_mux_447 : signal_mux_448;
    assign signal_eq_102 = signal_const_39 == source;
    assign stand_in = signal_eq_102 ? signal_mux_180 : signal_mux_449;
    assign signal_eq_103 = signal_const_99 == purpose;
    assign signal_mux_450 = signal_eq_103 ? acc : stand_in;
    assign signal_mux_451 = from_dictionary ? signal_mux_179 : signal_mux_450;
    assign signal_mux_452 = signal_eq_116 ? acc : signal_mux_451;
    always @* begin
        case (sm)
        4'b0111:
            signal_cases_78 <= signal_mux_452;
        default:
            signal_cases_78 <= acc;
        endcase
    end
    assign signal_wire_54 = signal_cases_78;
    always @(posedge signal_wire_59) begin
        acc <= signal_wire_54;
    end
    assign signal_select_89 = acc[31:0];
    assign shifted = { signal_select_89,
                       signal_wire_64 };
    assign signal_select_90 = shifted[23:0];
    always @* begin
        case (field)
        3'b000:
            signal_cases_79 <= signal_select_90;
        default:
            signal_cases_79 <= row$phase_hi;
        endcase
    end
    assign signal_eq_104 = signal_const_99 == purpose;
    assign signal_mux_453 = signal_eq_104 ? signal_cases_79 : row$phase_hi;
    assign signal_eq_105 = k == signal_const_209;
    assign signal_eq_106 = k == signal_const_61;
    assign wide = field < signal_const_181;
    assign last_word = wide ? signal_eq_105 : signal_eq_106;
    assign signal_mux_454 = last_word ? signal_mux_453 : row$phase_hi;
    assign signal_mux_455 = read_done ? signal_mux_454 : row$phase_hi;
    assign held$y = signal_select_92[6:0];
    assign held$x = signal_select_92[13:7];
    assign held$period = signal_select_92[20:14];
    assign held$arm = signal_select_92[27:21];
    assign signal_select_91 = entry[31:0];
    assign entry_shifted = { signal_select_91,
                             signal_wire_64 };
    assign signal_mux_456 = read_done ? entry_shifted : entry;
    always @* begin
        case (sm)
        4'b0110:
            signal_cases_80 <= signal_mux_456;
        default:
            signal_cases_80 <= entry;
        endcase
    end
    assign signal_wire_55 = signal_cases_80;
    always @(posedge signal_wire_59) begin
        entry <= signal_wire_55;
    end
    assign signal_select_92 = entry[47:2];
    assign held$phase = signal_select_92[34:28];
    always @* begin
        case (field)
        0:
            index <= held$phase;
        1:
            index <= held$arm;
        2:
            index <= held$period;
        3:
            index <= held$x;
        default:
            index <= held$y;
        endcase
    end
    assign signal_eq_107 = index == signal_const_36;
    assign signal_not_142 = ~ signal_eq_107;
    assign signal_mux_457 = stored ? source : signal_const_209;
    assign signal_mux_458 = falls_to_next ? signal_mux_457 : source;
    assign signal_mux_459 = signal_eq_110 ? signal_const_39 : source;
    assign signal_mux_460 = read_done ? signal_mux_459 : source;
    assign signal_mux_461 = signal_not_146 ? signal_const_61 : source;
    always @* begin
        case (sm)
        4'b0101:
            signal_cases_81 <= signal_mux_461;
        4'b0110:
            signal_cases_81 <= signal_mux_460;
        4'b1001:
            signal_cases_81 <= signal_mux_458;
        default:
            signal_cases_81 <= source;
        endcase
    end
    assign signal_wire_56 = signal_cases_81;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            source <= signal_const_39;
        else
            source <= signal_wire_56;
    end
    assign signal_eq_108 = signal_const_39 == source;
    assign from_dictionary = signal_eq_108 & signal_not_142;
    assign signal_mux_462 = from_dictionary ? signal_mux_455 : row$phase_hi;
    assign signal_mux_463 = signal_eq_116 ? row$phase_hi : signal_mux_462;
    assign signal_eq_109 = signal_const_99 == purpose;
    assign signal_mux_464 = signal_eq_109 ? signal_const_134 : row$phase_hi;
    assign signal_eq_110 = k == signal_const_209;
    assign signal_mux_465 = signal_eq_110 ? signal_mux_464 : row$phase_hi;
    assign signal_mux_466 = read_done ? signal_mux_465 : row$phase_hi;
    assign signal_mux_467 = signal_wire_71 ? signal_const_134 : row$phase_hi;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_82 <= signal_mux_467;
        4'b0110:
            signal_cases_82 <= signal_mux_466;
        4'b0111:
            signal_cases_82 <= signal_mux_463;
        4'b1010:
            signal_cases_82 <= signal_mux_178;
        default:
            signal_cases_82 <= row$phase_hi;
        endcase
    end
    assign signal_wire_57 = signal_cases_82;
    always @(posedge signal_wire_59) begin
        row$phase_hi <= signal_wire_57;
    end
    assign signal_select_93 = row$phase_hi[23:23];
    assign signal_not_143 = ~ signal_select_93;
    assign signal_cat_88 = { signal_not_143,
                             signal_select_19 };
    assign signal_lt_42 = signal_cat_88 < signal_cat_27;
    assign signal_or_59 = signal_lt_42 | signal_lt_16;
    assign signal_or_60 = signal_or_59 | signal_lt_15;
    assign signal_or_61 = signal_or_60 | signal_lt_14;
    assign signal_or_62 = signal_or_61 | signal_lt_13;
    assign signal_not_144 = ~ signal_or_62;
    assign signal_and_116 = signal_not_144 & signal_not_48;
    assign signal_not_145 = ~ signal_and_116;
    assign signal_or_63 = signal_not_145 | signal_not_43;
    assign signal_or_64 = signal_or_63 | signal_not_42;
    assign signal_and_117 = signal_or_64 & signal_not_40;
    assign signal_and_118 = signal_and_117 & signal_not_38;
    assign signal_and_119 = signal_and_118 & signal_not_37;
    assign signal_and_120 = signal_and_119 & signal_not_35;
    assign signal_and_121 = signal_and_120 & signal_not_33;
    assign signal_and_122 = signal_and_121 & signal_not_31;
    assign signal_and_123 = signal_and_122 & signal_not_29;
    assign signal_and_124 = signal_and_123 & signal_not_27;
    assign signal_and_125 = signal_and_124 & signal_not_25;
    assign signal_and_126 = signal_and_125 & signal_not_24;
    assign next_fails = ~ signal_and_126;
    assign signal_mux_468 = next_fails ? purpose : signal_mux_152;
    assign signal_wire_58 = clear;
    assign signal_wire_59 = clock;
    assign signal_const_341 = 10'b0000000001;
    assign signal_cat_89 = { gnd,
                             pc };
    assign next_pc = signal_cat_89 + signal_const_341;
    assign signal_cat_90 = { gnd,
                             entry_tag };
    assign signal_eq_111 = signal_cat_90 == next_pc;
    assign signal_mux_469 = read_done ? signal_eq_111 : stored;
    assign signal_mux_470 = signal_lt_44 ? signal_mux_469 : gnd;
    always @* begin
        case (sm)
        4'b0011:
            signal_cases_83 <= signal_mux_470;
        default:
            signal_cases_83 <= stored;
        endcase
    end
    assign signal_wire_60 = signal_cases_83;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            stored <= signal_const_33;
        else
            stored <= signal_wire_60;
    end
    assign signal_mux_471 = stored ? signal_const_181 : signal_const_187;
    assign signal_mux_472 = falls_to_next ? signal_mux_471 : signal_const_68;
    assign signal_mux_473 = is_jump ? signal_const_66 : purpose;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_84 <= signal_mux_473;
        4'b1001:
            signal_cases_84 <= signal_mux_472;
        4'b1010:
            signal_cases_84 <= signal_mux_468;
        default:
            signal_cases_84 <= purpose;
        endcase
    end
    assign signal_wire_61 = signal_cases_84;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            purpose <= signal_const_66;
        else
            purpose <= signal_wire_61;
    end
    always @* begin
        case (purpose)
        3'b100:
            signal_cases_85 <= signal_mux_150;
        default:
            signal_cases_85 <= pc;
        endcase
    end
    assign signal_mux_474 = signal_eq_116 ? signal_cases_85 : pc;
    assign signal_mux_475 = signal_wire_71 ? signal_const_35 : pc;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_86 <= signal_mux_475;
        4'b0111:
            signal_cases_86 <= signal_mux_474;
        4'b1000:
            signal_cases_86 <= signal_mux_149;
        4'b1010:
            signal_cases_86 <= signal_mux_147;
        default:
            signal_cases_86 <= pc;
        endcase
    end
    assign signal_wire_62 = signal_cases_86;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            pc <= signal_const_35;
        else
            pc <= signal_wire_62;
    end
    assign signal_eq_112 = pc == signal_wire_11;
    assign following = signal_eq_112 ? signal_wire_10 : signal_add_23;
    assign gnd = 1'b0;
    assign signal_cat_91 = { gnd,
                             following };
    assign falls_to_next = signal_cat_91 == next_pc;
    assign signal_mux_476 = falls_to_next ? key : following;
    assign jump_target = word[8:0];
    assign signal_mux_477 = is_jump ? jump_target : key;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_87 <= signal_mux_477;
        4'b1001:
            signal_cases_87 <= signal_mux_476;
        default:
            signal_cases_87 <= key;
        endcase
    end
    assign signal_wire_63 = signal_cases_87;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            key <= signal_const_35;
        else
            key <= signal_wire_63;
    end
    assign signal_wire_64 = data_word;
    assign entry_tag = signal_wire_64[15:7];
    assign signal_eq_113 = entry_tag == key;
    assign signal_mux_478 = signal_eq_113 ? signal_const_39 : k;
    assign signal_mux_479 = read_done ? signal_mux_478 : k;
    assign signal_mux_480 = signal_not_146 ? signal_const_39 : signal_mux_479;
    assign signal_add_34 = k + signal_const_61;
    assign signal_mux_481 = signal_eq_115 ? signal_const_39 : signal_add_34;
    assign signal_add_35 = k + signal_const_61;
    assign signal_eq_114 = k == signal_const_61;
    assign signal_mux_482 = signal_eq_114 ? signal_const_39 : signal_add_35;
    assign signal_mux_483 = read_done ? signal_mux_482 : k;
    assign signal_mux_484 = signal_wire_71 ? signal_const_39 : k;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_88 <= signal_mux_484;
        4'b0001:
            signal_cases_88 <= signal_mux_483;
        4'b0010:
            signal_cases_88 <= signal_mux_481;
        4'b0101:
            signal_cases_88 <= signal_mux_480;
        4'b0110:
            signal_cases_88 <= signal_mux_143;
        4'b0111:
            signal_cases_88 <= signal_mux_141;
        4'b1000:
            signal_cases_88 <= signal_mux_136;
        4'b1001:
            signal_cases_88 <= signal_mux_134;
        4'b1010:
            signal_cases_88 <= signal_mux_132;
        default:
            signal_cases_88 <= k;
        endcase
    end
    assign signal_wire_65 = signal_cases_88;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            k <= signal_const_39;
        else
            k <= signal_wire_65;
    end
    assign signal_eq_115 = k == signal_const_61;
    assign signal_mux_485 = signal_eq_115 ? signal_wire_9 : word;
    always @* begin
        case (sm)
        4'b0010:
            signal_cases_89 <= signal_mux_485;
        default:
            signal_cases_89 <= word;
        endcase
    end
    assign signal_wire_66 = signal_cases_89;
    always @(posedge signal_wire_59) begin
        word <= signal_wire_66;
    end
    assign signal_select_94 = word[15:13];
    assign is_jump = signal_select_94 == signal_const_66;
    assign signal_mux_486 = is_jump ? signal_mux_128 : lo;
    always @* begin
        case (sm)
        4'b0100:
            signal_cases_90 <= signal_mux_486;
        4'b0101:
            signal_cases_90 <= signal_mux_127;
        4'b1001:
            signal_cases_90 <= signal_mux_113;
        default:
            signal_cases_90 <= lo;
        endcase
    end
    assign signal_wire_67 = signal_cases_90;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            lo <= signal_const_44;
        else
            lo <= signal_wire_67;
    end
    assign signal_lt_43 = lo < hi;
    assign signal_not_146 = ~ signal_lt_43;
    assign signal_mux_487 = signal_not_146 ? signal_const_66 : field;
    always @* begin
        case (sm)
        4'b0101:
            signal_cases_91 <= signal_mux_487;
        4'b0110:
            signal_cases_91 <= signal_mux_111;
        4'b0111:
            signal_cases_91 <= signal_mux_109;
        4'b1000:
            signal_cases_91 <= signal_add_16;
        4'b1001:
            signal_cases_91 <= signal_mux_103;
        default:
            signal_cases_91 <= field;
        endcase
    end
    assign signal_wire_68 = signal_cases_91;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            field <= signal_const_66;
        else
            field <= signal_wire_68;
    end
    assign signal_eq_116 = field == signal_const_65;
    assign signal_mux_488 = signal_eq_116 ? signal_cases_10 : ptr;
    assign signal_mux_489 = signal_wire_71 ? signal_const_44 : ptr;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_92 <= signal_mux_489;
        4'b0111:
            signal_cases_92 <= signal_mux_488;
        4'b1000:
            signal_cases_92 <= signal_mux_101;
        4'b1010:
            signal_cases_92 <= signal_mux_100;
        default:
            signal_cases_92 <= ptr;
        endcase
    end
    assign signal_wire_69 = signal_cases_92;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            ptr <= signal_const_44;
        else
            ptr <= signal_wire_69;
    end
    assign signal_lt_44 = ptr < count;
    assign signal_mux_490 = signal_lt_44 ? vdd : gnd;
    assign vdd = 1'b1;
    always @* begin
        case (sm)
        4'b0001:
            signal_cases_93 <= vdd;
        4'b0011:
            signal_cases_93 <= signal_mux_490;
        4'b0101:
            signal_cases_93 <= signal_mux_97;
        4'b0110:
            signal_cases_93 <= vdd;
        4'b0111:
            signal_cases_93 <= signal_mux_96;
        default:
            signal_cases_93 <= gnd;
        endcase
    end
    assign reading = signal_cases_93;
    assign signal_and_127 = reading & signal_not_23;
    assign signal_mux_491 = signal_and_127 ? signal_add_14 : signal_const_39;
    assign signal_wire_70 = signal_mux_491;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            \wait  <= signal_const_39;
        else
            \wait  <= signal_wire_70;
    end
    assign read_done = \wait  == signal_const_59;
    assign signal_mux_492 = read_done ? signal_mux_94 : sm;
    assign signal_wire_71 = check;
    assign signal_mux_493 = signal_wire_71 ? signal_const_111 : sm;
    always @* begin
        case (sm)
        4'b0000:
            signal_cases_94 <= signal_mux_493;
        4'b0001:
            signal_cases_94 <= signal_mux_492;
        4'b0010:
            signal_cases_94 <= signal_mux_93;
        4'b0011:
            signal_cases_94 <= signal_mux_92;
        4'b0100:
            signal_cases_94 <= signal_mux_89;
        4'b0101:
            signal_cases_94 <= signal_mux_87;
        4'b0110:
            signal_cases_94 <= signal_mux_84;
        4'b0111:
            signal_cases_94 <= signal_mux_82;
        4'b1000:
            signal_cases_94 <= signal_mux_75;
        4'b1001:
            signal_cases_94 <= signal_mux_73;
        4'b1010:
            signal_cases_94 <= signal_mux_70;
        4'b1011:
            signal_cases_94 <= signal_mux_66;
        default:
            signal_cases_94 <= sm;
        endcase
    end
    assign signal_eq_117 = signal_const_57 == sm;
    assign signal_not_147 = ~ signal_eq_117;
    assign signal_wire_72 = abort;
    assign signal_and_128 = signal_wire_72 & signal_not_147;
    assign signal_mux_494 = signal_and_128 ? signal_const_57 : signal_cases_94;
    assign signal_wire_73 = signal_mux_494;
    always @(posedge signal_wire_59) begin
        if (signal_wire_58)
            sm <= signal_const_57;
        else
            sm <= signal_wire_73;
    end
    assign signal_eq_118 = signal_const_315 == sm;
    assign program_read$valid = signal_eq_118;
    assign program_read$value = pc;
    assign data_read$valid = read_valid;
    assign data_read$value = read_at;
    assign busy = signal_not_21;
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
    hosts$config$line_code_0,
    hosts$config$route_0,
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
    hosts$line_write$valid_0,
    hosts$line_write$addr_0,
    hosts$line_write$data_0,
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
    hosts$config$line_code_1,
    hosts$config$route_1,
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
    hosts$line_write$valid_1,
    hosts$line_write$addr_1,
    hosts$line_write$data_1,
    pads,
    check_setup$base,
    check_setup$loaded$valid,
    check_setup$loaded$value,
    check_setup$floor,
    check_setup$single_edge,
    start_all,
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
    engines$free_0,
    engines$irq_0,
    engines$fault$underflow_0,
    engines$fault$overflow_0,
    engines$fault$missed_deadline_0,
    engines$fault$decode_0,
    engines$fault$assumption_0,
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
    engines$push$valid_0,
    engines$push$value_0,
    engines$line_tx_0,
    engines$line_rx_0,
    engines$line_flag_0,
    engines$line_last_0,
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
    engines$free_1,
    engines$irq_1,
    engines$fault$underflow_1,
    engines$fault$overflow_1,
    engines$fault$missed_deadline_1,
    engines$fault$decode_1,
    engines$fault$assumption_1,
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
    engines$push$valid_1,
    engines$push$value_1,
    engines$line_tx_1,
    engines$line_rx_1,
    engines$line_flag_1,
    engines$line_last_1,
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
    input hosts$config$line_code_0;
    input hosts$config$route_0;
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
    input hosts$line_write$valid_0;
    input [4:0] hosts$line_write$addr_0;
    input [15:0] hosts$line_write$data_0;
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
    input hosts$config$line_code_1;
    input hosts$config$route_1;
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
    input hosts$line_write$valid_1;
    input [4:0] hosts$line_write$addr_1;
    input [15:0] hosts$line_write$data_1;
    input [19:0] pads;
    input [8:0] check_setup$base;
    input check_setup$loaded$valid;
    input [15:0] check_setup$loaded$value;
    input check_setup$floor;
    input check_setup$single_edge;
    input start_all;
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
    output engines$free_0;
    output engines$irq_0;
    output engines$fault$underflow_0;
    output engines$fault$overflow_0;
    output engines$fault$missed_deadline_0;
    output engines$fault$decode_0;
    output engines$fault$assumption_0;
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
    output engines$push$valid_0;
    output [15:0] engines$push$value_0;
    output [3:0] engines$line_tx_0;
    output [3:0] engines$line_rx_0;
    output engines$line_flag_0;
    output engines$line_last_0;
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
    output engines$free_1;
    output engines$irq_1;
    output engines$fault$underflow_1;
    output engines$fault$overflow_1;
    output engines$fault$missed_deadline_1;
    output engines$fault$decode_1;
    output engines$fault$assumption_1;
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
    output engines$push$valid_1;
    output [15:0] engines$push$value_1;
    output [3:0] engines$line_tx_1;
    output [3:0] engines$line_rx_1;
    output engines$line_flag_1;
    output engines$line_last_1;
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
    wire signal_or;
    wire signal_and;
    wire signal_mux;
    wire signal_const_1;
    wire signal_eq;
    wire signal_and_1;
    wire signal_mux_1;
    wire signal_wire;
    reg refused$1;
    wire signal_not_1;
    wire signal_or_1;
    wire signal_and_2;
    wire signal_mux_2;
    wire signal_eq_1;
    wire signal_and_3;
    wire signal_mux_3;
    wire signal_wire_1;
    reg refused$0;
    wire [4:0] signal_select;
    wire [4:0] signal_wire_2;
    wire [9:0] signal_select_1;
    wire [9:0] signal_wire_3;
    wire [27:0] signal_or_2;
    wire [19:0] signal_select_2;
    wire [27:0] signal_or_3;
    wire [27:0] signal_and_4;
    wire [27:0] signal_const_4;
    wire [27:0] signal_or_4;
    wire [27:0] signal_and_5;
    wire [27:0] signal_or_5;
    wire [19:0] signal_select_3;
    wire signal_select_4;
    wire signal_wire_4;
    wire signal_select_5;
    wire signal_wire_5;
    wire [3:0] signal_select_6;
    wire [3:0] signal_wire_6;
    wire [3:0] signal_select_7;
    wire [3:0] signal_wire_7;
    wire signal_select_8;
    wire signal_wire_8;
    wire signal_select_9;
    wire signal_wire_9;
    wire [4:0] signal_select_10;
    wire [4:0] signal_wire_10;
    wire [15:0] signal_select_11;
    wire [15:0] signal_wire_11;
    wire [27:0] signal_select_12;
    wire [27:0] signal_wire_12;
    wire [7:0] signal_select_13;
    wire [7:0] signal_wire_13;
    wire signal_select_14;
    wire signal_wire_14;
    wire [15:0] signal_select_15;
    wire [15:0] signal_wire_15;
    wire [15:0] signal_select_16;
    wire [15:0] signal_wire_16;
    wire [3:0] signal_select_17;
    wire [3:0] signal_wire_17;
    wire signal_select_18;
    wire signal_wire_18;
    wire [23:0] signal_select_19;
    wire [23:0] signal_wire_19;
    wire signal_select_20;
    wire signal_wire_20;
    wire signal_select_21;
    wire signal_wire_21;
    wire signal_select_22;
    wire signal_wire_22;
    wire signal_select_23;
    wire signal_wire_23;
    wire signal_select_24;
    wire signal_wire_24;
    wire signal_select_25;
    wire signal_wire_25;
    wire [4:0] signal_select_26;
    wire [4:0] signal_wire_26;
    wire [23:0] signal_select_27;
    wire [23:0] signal_wire_27;
    wire [4:0] signal_select_28;
    wire [4:0] signal_wire_28;
    wire [15:0] signal_select_29;
    wire [15:0] signal_wire_29;
    wire [4:0] signal_select_30;
    wire [4:0] signal_wire_30;
    wire [15:0] signal_select_31;
    wire [15:0] signal_wire_31;
    wire [15:0] signal_select_32;
    wire [15:0] signal_wire_32;
    wire [23:0] signal_select_33;
    wire [23:0] signal_wire_33;
    wire [15:0] signal_select_34;
    wire [15:0] signal_wire_34;
    wire [15:0] signal_select_35;
    wire [15:0] signal_wire_35;
    wire [15:0] signal_select_36;
    wire [15:0] signal_wire_36;
    wire [8:0] signal_select_37;
    wire [8:0] signal_wire_37;
    wire [8:0] signal_select_38;
    wire [8:0] signal_wire_38;
    wire signal_select_39;
    wire signal_wire_39;
    wire signal_select_40;
    wire signal_wire_40;
    wire [3:0] signal_select_41;
    wire [3:0] signal_wire_41;
    wire [3:0] signal_select_42;
    wire [3:0] signal_wire_42;
    wire signal_select_43;
    wire signal_wire_43;
    wire signal_select_44;
    wire signal_wire_44;
    wire [4:0] signal_select_45;
    wire [4:0] signal_wire_45;
    wire [15:0] signal_select_46;
    wire [15:0] signal_wire_46;
    wire [27:0] signal_select_47;
    wire [27:0] signal_wire_47;
    wire [7:0] signal_select_48;
    wire [7:0] signal_wire_48;
    wire signal_select_49;
    wire signal_wire_49;
    wire [15:0] signal_select_50;
    wire [15:0] signal_wire_50;
    wire [15:0] signal_select_51;
    wire [15:0] signal_wire_51;
    wire [3:0] signal_select_52;
    wire [3:0] signal_wire_52;
    wire signal_select_53;
    wire signal_wire_53;
    wire [23:0] signal_select_54;
    wire [23:0] signal_wire_54;
    wire signal_select_55;
    wire signal_wire_55;
    wire signal_select_56;
    wire signal_wire_56;
    wire signal_select_57;
    wire signal_wire_57;
    wire signal_select_58;
    wire signal_wire_58;
    wire signal_select_59;
    wire signal_wire_59;
    wire signal_select_60;
    wire signal_wire_60;
    wire [4:0] signal_select_61;
    wire [4:0] signal_wire_61;
    wire [23:0] signal_select_62;
    wire [23:0] signal_wire_62;
    wire [4:0] signal_select_63;
    wire [4:0] signal_wire_63;
    wire [15:0] signal_select_64;
    wire [15:0] signal_wire_64;
    wire [4:0] signal_select_65;
    wire [4:0] signal_wire_65;
    wire [15:0] signal_select_66;
    wire [15:0] signal_wire_66;
    wire [15:0] signal_select_67;
    wire [15:0] signal_wire_67;
    wire [23:0] signal_select_68;
    wire [23:0] signal_wire_68;
    wire [15:0] signal_select_69;
    wire [15:0] signal_wire_69;
    wire [15:0] signal_select_70;
    wire [15:0] signal_wire_70;
    wire [15:0] signal_select_71;
    wire [15:0] signal_wire_71;
    wire [8:0] signal_select_72;
    wire [8:0] signal_wire_72;
    wire [8:0] signal_select_73;
    wire [8:0] signal_wire_73;
    wire [3:0] signal_const_5;
    wire [3:0] signal_select_74;
    wire [3:0] signal_wire_74;
    wire route_full$0;
    reg signal_reg;
    reg signal_reg_1;
    wire [15:0] signal_const_8;
    reg [15:0] signal_reg_2;
    wire signal_eq_2;
    wire signal_and_6;
    reg signal_reg_3;
    wire [15:0] signal_wire_75;
    wire [4:0] signal_wire_76;
    wire [27:0] signal_const_11;
    wire [27:0] signal_or_6;
    wire [27:0] signal_select_75;
    wire [27:0] signal_wire_77;
    wire [27:0] signal_and_7;
    wire [27:0] signal_select_76;
    wire [27:0] signal_wire_78;
    wire [27:0] signal_not_2;
    wire [7:0] signal_const_12;
    wire [27:0] signal_cat;
    wire [27:0] signal_and_8;
    wire [27:0] signal_or_7;
    wire signal_wire_79;
    wire signal_wire_80;
    wire signal_wire_81;
    wire signal_wire_82;
    wire [15:0] signal_select_77;
    wire [15:0] signal_wire_83;
    wire [15:0] signal_wire_84;
    wire [15:0] signal_mux_4;
    wire signal_select_78;
    wire signal_wire_85;
    wire signal_wire_86;
    wire signal_mux_5;
    wire signal_and_9;
    wire [15:0] signal_wire_87;
    wire [8:0] signal_wire_88;
    wire signal_eq_3;
    wire signal_and_10;
    wire signal_mux_6;
    wire signal_eq_4;
    wire signal_or_8;
    wire [15:0] signal_select_79;
    wire [15:0] signal_mux_7;
    wire [15:0] signal_select_80;
    wire [15:0] signal_wire_89;
    wire [15:0] signal_select_81;
    wire [15:0] signal_wire_90;
    wire [15:0] signal_mux_8;
    wire [8:0] signal_wire_91;
    wire signal_mux_9;
    wire signal_mux_10;
    wire signal_mux_11;
    wire signal_mux_12;
    wire [15:0] signal_mux_13;
    wire [8:0] signal_mux_14;
    wire [8:0] signal_mux_15;
    wire signal_mux_16;
    wire [4:0] signal_mux_17;
    wire signal_mux_18;
    wire [15:0] signal_mux_19;
    wire [15:0] signal_mux_20;
    wire [4:0] signal_mux_21;
    wire [4:0] signal_mux_22;
    wire signal_mux_23;
    wire [4:0] signal_mux_24;
    wire signal_mux_25;
    wire signal_mux_26;
    wire signal_mux_27;
    wire signal_mux_28;
    wire [4:0] signal_mux_29;
    wire [4:0] signal_mux_30;
    wire [2:0] signal_mux_31;
    wire [4:0] signal_mux_32;
    wire [4:0] signal_mux_33;
    wire [4:0] signal_mux_34;
    wire [4:0] signal_mux_35;
    wire [4:0] signal_mux_36;
    wire signal_mux_37;
    wire [4:0] signal_mux_38;
    wire [1:0] signal_mux_39;
    wire signal_not_3;
    wire signal_not_4;
    wire signal_mux_40;
    wire signal_or_9;
    wire signal_or_10;
    wire signal_or_11;
    wire signal_or_12;
    wire signal_mux_41;
    wire [3:0] signal_select_82;
    wire [3:0] signal_wire_92;
    wire route_full$1;
    wire signal_wire_93;
    reg signal_reg_4;
    wire signal_wire_94;
    reg signal_reg_5;
    wire [15:0] signal_wire_95;
    reg [15:0] signal_reg_6;
    wire signal_eq_5;
    wire signal_and_11;
    wire signal_wire_96;
    reg signal_reg_7;
    wire [15:0] signal_wire_97;
    wire [4:0] signal_wire_98;
    wire [27:0] signal_or_13;
    wire [27:0] signal_and_12;
    wire [27:0] signal_select_83;
    wire [27:0] signal_wire_99;
    wire [27:0] signal_not_5;
    wire [19:0] signal_wire_100;
    wire [27:0] signal_cat_1;
    wire [27:0] signal_and_13;
    wire [27:0] signal_or_14;
    wire signal_wire_101;
    wire signal_wire_102;
    wire signal_wire_103;
    wire signal_wire_104;
    wire [15:0] signal_select_84;
    wire [15:0] signal_wire_105;
    wire [15:0] signal_wire_106;
    wire [15:0] signal_mux_42;
    wire signal_select_85;
    wire signal_wire_107;
    wire signal_wire_108;
    wire signal_mux_43;
    wire [8:0] signal_select_86;
    wire [8:0] signal_wire_109;
    wire signal_and_14;
    wire [8:0] signal_mux_44;
    wire [8:0] signal_select_87;
    wire [8:0] signal_wire_110;
    wire [8:0] signal_select_88;
    wire [8:0] signal_wire_111;
    wire signal_select_89;
    wire signal_wire_112;
    wire signal_select_90;
    wire signal_wire_113;
    wire signal_eq_6;
    wire signal_and_15;
    wire lent$0;
    wire signal_and_16;
    wire [8:0] signal_mux_45;
    wire [15:0] signal_wire_114;
    wire [8:0] signal_wire_115;
    wire [15:0] signal_wire_116;
    wire [8:0] signal_wire_117;
    wire [31:0] signal_inst;
    wire [15:0] signal_select_91;
    wire [8:0] signal_select_92;
    wire [8:0] signal_wire_118;
    wire signal_select_93;
    wire signal_wire_119;
    wire signal_select_94;
    wire signal_wire_120;
    wire signal_eq_7;
    wire signal_and_17;
    wire lent$1;
    wire signal_and_18;
    wire [15:0] signal_wire_121;
    wire [8:0] signal_wire_122;
    wire signal_and_19;
    wire signal_and_20;
    wire all_ready;
    wire signal_wire_123;
    wire starts_all;
    wire gnd;
    wire vdd;
    wire signal_eq_8;
    wire signal_select_95;
    wire signal_wire_124;
    wire signal_select_96;
    wire signal_wire_125;
    wire accepts;
    wire signal_and_21;
    wire signal_mux_46;
    wire signal_eq_9;
    wire signal_and_22;
    wire signal_wire_126;
    wire signal_wire_127;
    wire signal_wire_128;
    wire signal_or_15;
    wire signal_or_16;
    wire signal_or_17;
    wire signal_mux_47;
    wire signal_wire_129;
    reg certified$1;
    wire signal_wire_130;
    wire signal_and_23;
    wire signal_or_18;
    wire signal_wire_131;
    wire signal_wire_132;
    wire signal_wire_133;
    wire signal_wire_134;
    wire [15:0] signal_wire_135;
    wire [8:0] signal_wire_136;
    wire [8:0] signal_wire_137;
    wire signal_wire_138;
    wire [4:0] signal_wire_139;
    wire signal_wire_140;
    wire [15:0] signal_wire_141;
    wire [15:0] signal_wire_142;
    wire [4:0] signal_wire_143;
    wire [4:0] signal_wire_144;
    wire signal_wire_145;
    wire [4:0] signal_wire_146;
    wire signal_wire_147;
    wire signal_wire_148;
    wire signal_wire_149;
    wire signal_wire_150;
    wire [4:0] signal_wire_151;
    wire [4:0] signal_wire_152;
    wire [2:0] signal_wire_153;
    wire [4:0] signal_wire_154;
    wire [4:0] signal_wire_155;
    wire [4:0] signal_wire_156;
    wire [4:0] signal_wire_157;
    wire [4:0] signal_wire_158;
    wire signal_wire_159;
    wire [4:0] signal_wire_160;
    wire [1:0] signal_wire_161;
    wire [417:0] signal_inst_1;
    wire signal_select_97;
    wire signal_wire_162;
    wire signal_wire_163;
    wire asks$1;
    wire signal_select_98;
    wire signal_wire_164;
    wire signal_wire_165;
    wire asks$0;
    wire signal_or_19;
    wire chosen;
    reg signal_reg_8;
    wire checked;
    wire signal_mux_48;
    wire signal_wire_166;
    wire signal_wire_167;
    wire signal_or_20;
    wire signal_or_21;
    wire signal_or_22;
    wire abort;
    wire [37:0] signal_inst_2;
    wire signal_select_99;
    wire checking;
    wire signal_not_6;
    wire go;
    wire signal_and_24;
    wire signal_wire_168;
    wire signal_wire_169;
    wire signal_wire_170;
    wire signal_or_23;
    wire signal_or_24;
    wire signal_or_25;
    wire signal_mux_49;
    wire signal_wire_171;
    reg certified$0;
    wire signal_wire_172;
    wire signal_and_25;
    wire signal_or_26;
    wire signal_wire_173;
    wire signal_wire_174;
    wire signal_wire_175;
    wire signal_wire_176;
    wire [15:0] signal_wire_177;
    wire [8:0] signal_wire_178;
    wire [8:0] signal_wire_179;
    wire signal_wire_180;
    wire [4:0] signal_wire_181;
    wire signal_wire_182;
    wire [15:0] signal_wire_183;
    wire [15:0] signal_wire_184;
    wire [4:0] signal_wire_185;
    wire [4:0] signal_wire_186;
    wire signal_wire_187;
    wire [4:0] signal_wire_188;
    wire signal_wire_189;
    wire signal_wire_190;
    wire signal_wire_191;
    wire signal_wire_192;
    wire [4:0] signal_wire_193;
    wire [4:0] signal_wire_194;
    wire [2:0] signal_wire_195;
    wire [4:0] signal_wire_196;
    wire [4:0] signal_wire_197;
    wire [4:0] signal_wire_198;
    wire [4:0] signal_wire_199;
    wire [4:0] signal_wire_200;
    wire signal_wire_201;
    wire [4:0] signal_wire_202;
    wire [1:0] signal_wire_203;
    wire signal_wire_204;
    wire signal_wire_205;
    wire [417:0] signal_inst_3;
    wire [27:0] signal_select_100;
    wire [27:0] signal_wire_206;
    assign signal_const = 1'b0;
    assign signal_not = ~ certified$1;
    assign signal_or = signal_wire_130 | signal_wire_123;
    assign signal_and = signal_or & signal_not;
    assign signal_mux = signal_and ? vdd : refused$1;
    assign signal_const_1 = 1'b1;
    assign signal_eq = chosen == signal_const_1;
    assign signal_and_1 = go & signal_eq;
    assign signal_mux_1 = signal_and_1 ? gnd : signal_mux;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            refused$1 <= signal_const;
        else
            refused$1 <= signal_wire;
    end
    assign signal_not_1 = ~ certified$0;
    assign signal_or_1 = signal_wire_172 | signal_wire_123;
    assign signal_and_2 = signal_or_1 & signal_not_1;
    assign signal_mux_2 = signal_and_2 ? vdd : refused$0;
    assign signal_eq_1 = chosen == signal_const;
    assign signal_and_3 = go & signal_eq_1;
    assign signal_mux_3 = signal_and_3 ? gnd : signal_mux_2;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            refused$0 <= signal_const;
        else
            refused$0 <= signal_wire_1;
    end
    assign signal_select = signal_inst_2[37:33];
    assign signal_wire_2 = signal_select;
    assign signal_select_1 = signal_inst_2[32:23];
    assign signal_wire_3 = signal_select_1;
    assign signal_or_2 = signal_wire_99 | signal_wire_78;
    assign signal_select_2 = signal_or_2[19:0];
    assign signal_or_3 = signal_wire_78 | signal_const_4;
    assign signal_and_4 = signal_wire_77 & signal_or_3;
    assign signal_const_4 = 28'b0000000000000000111111111111;
    assign signal_or_4 = signal_wire_99 | signal_const_4;
    assign signal_and_5 = signal_wire_206 & signal_or_4;
    assign signal_or_5 = signal_and_5 | signal_and_4;
    assign signal_select_3 = signal_or_5[19:0];
    assign signal_select_4 = signal_inst_1[417:417];
    assign signal_wire_4 = signal_select_4;
    assign signal_select_5 = signal_inst_1[416:416];
    assign signal_wire_5 = signal_select_5;
    assign signal_select_6 = signal_inst_1[415:412];
    assign signal_wire_6 = signal_select_6;
    assign signal_select_7 = signal_inst_1[411:408];
    assign signal_wire_7 = signal_select_7;
    assign signal_select_8 = signal_inst_1[390:390];
    assign signal_wire_8 = signal_select_8;
    assign signal_select_9 = signal_inst_1[389:389];
    assign signal_wire_9 = signal_select_9;
    assign signal_select_10 = signal_inst_1[388:384];
    assign signal_wire_10 = signal_select_10;
    assign signal_select_11 = signal_inst_1[383:368];
    assign signal_wire_11 = signal_select_11;
    assign signal_select_12 = signal_inst_1[367:340];
    assign signal_wire_12 = signal_select_12;
    assign signal_select_13 = signal_inst_1[339:332];
    assign signal_wire_13 = signal_select_13;
    assign signal_select_14 = signal_inst_1[331:331];
    assign signal_wire_14 = signal_select_14;
    assign signal_select_15 = signal_inst_1[314:299];
    assign signal_wire_15 = signal_select_15;
    assign signal_select_16 = signal_inst_1[298:283];
    assign signal_wire_16 = signal_select_16;
    assign signal_select_17 = signal_inst_1[282:279];
    assign signal_wire_17 = signal_select_17;
    assign signal_select_18 = signal_inst_1[274:274];
    assign signal_wire_18 = signal_select_18;
    assign signal_select_19 = signal_inst_1[273:250];
    assign signal_wire_19 = signal_select_19;
    assign signal_select_20 = signal_inst_1[249:249];
    assign signal_wire_20 = signal_select_20;
    assign signal_select_21 = signal_inst_1[248:248];
    assign signal_wire_21 = signal_select_21;
    assign signal_select_22 = signal_inst_1[247:247];
    assign signal_wire_22 = signal_select_22;
    assign signal_select_23 = signal_inst_1[246:246];
    assign signal_wire_23 = signal_select_23;
    assign signal_select_24 = signal_inst_1[245:245];
    assign signal_wire_24 = signal_select_24;
    assign signal_select_25 = signal_inst_1[244:244];
    assign signal_wire_25 = signal_select_25;
    assign signal_select_26 = signal_inst_1[241:237];
    assign signal_wire_26 = signal_select_26;
    assign signal_select_27 = signal_inst_1[236:213];
    assign signal_wire_27 = signal_select_27;
    assign signal_select_28 = signal_inst_1[212:208];
    assign signal_wire_28 = signal_select_28;
    assign signal_select_29 = signal_inst_1[207:192];
    assign signal_wire_29 = signal_select_29;
    assign signal_select_30 = signal_inst_1[191:187];
    assign signal_wire_30 = signal_select_30;
    assign signal_select_31 = signal_inst_1[186:171];
    assign signal_wire_31 = signal_select_31;
    assign signal_select_32 = signal_inst_1[170:155];
    assign signal_wire_32 = signal_select_32;
    assign signal_select_33 = signal_inst_1[154:131];
    assign signal_wire_33 = signal_select_33;
    assign signal_select_34 = signal_inst_1[130:115];
    assign signal_wire_34 = signal_select_34;
    assign signal_select_35 = signal_inst_1[114:99];
    assign signal_wire_35 = signal_select_35;
    assign signal_select_36 = signal_inst_1[98:83];
    assign signal_wire_36 = signal_select_36;
    assign signal_select_37 = signal_inst_1[73:65];
    assign signal_wire_37 = signal_select_37;
    assign signal_select_38 = signal_inst_1[64:56];
    assign signal_wire_38 = signal_select_38;
    assign signal_select_39 = signal_inst_3[417:417];
    assign signal_wire_39 = signal_select_39;
    assign signal_select_40 = signal_inst_3[416:416];
    assign signal_wire_40 = signal_select_40;
    assign signal_select_41 = signal_inst_3[415:412];
    assign signal_wire_41 = signal_select_41;
    assign signal_select_42 = signal_inst_3[411:408];
    assign signal_wire_42 = signal_select_42;
    assign signal_select_43 = signal_inst_3[390:390];
    assign signal_wire_43 = signal_select_43;
    assign signal_select_44 = signal_inst_3[389:389];
    assign signal_wire_44 = signal_select_44;
    assign signal_select_45 = signal_inst_3[388:384];
    assign signal_wire_45 = signal_select_45;
    assign signal_select_46 = signal_inst_3[383:368];
    assign signal_wire_46 = signal_select_46;
    assign signal_select_47 = signal_inst_3[367:340];
    assign signal_wire_47 = signal_select_47;
    assign signal_select_48 = signal_inst_3[339:332];
    assign signal_wire_48 = signal_select_48;
    assign signal_select_49 = signal_inst_3[331:331];
    assign signal_wire_49 = signal_select_49;
    assign signal_select_50 = signal_inst_3[314:299];
    assign signal_wire_50 = signal_select_50;
    assign signal_select_51 = signal_inst_3[298:283];
    assign signal_wire_51 = signal_select_51;
    assign signal_select_52 = signal_inst_3[282:279];
    assign signal_wire_52 = signal_select_52;
    assign signal_select_53 = signal_inst_3[274:274];
    assign signal_wire_53 = signal_select_53;
    assign signal_select_54 = signal_inst_3[273:250];
    assign signal_wire_54 = signal_select_54;
    assign signal_select_55 = signal_inst_3[249:249];
    assign signal_wire_55 = signal_select_55;
    assign signal_select_56 = signal_inst_3[248:248];
    assign signal_wire_56 = signal_select_56;
    assign signal_select_57 = signal_inst_3[247:247];
    assign signal_wire_57 = signal_select_57;
    assign signal_select_58 = signal_inst_3[246:246];
    assign signal_wire_58 = signal_select_58;
    assign signal_select_59 = signal_inst_3[245:245];
    assign signal_wire_59 = signal_select_59;
    assign signal_select_60 = signal_inst_3[244:244];
    assign signal_wire_60 = signal_select_60;
    assign signal_select_61 = signal_inst_3[241:237];
    assign signal_wire_61 = signal_select_61;
    assign signal_select_62 = signal_inst_3[236:213];
    assign signal_wire_62 = signal_select_62;
    assign signal_select_63 = signal_inst_3[212:208];
    assign signal_wire_63 = signal_select_63;
    assign signal_select_64 = signal_inst_3[207:192];
    assign signal_wire_64 = signal_select_64;
    assign signal_select_65 = signal_inst_3[191:187];
    assign signal_wire_65 = signal_select_65;
    assign signal_select_66 = signal_inst_3[186:171];
    assign signal_wire_66 = signal_select_66;
    assign signal_select_67 = signal_inst_3[170:155];
    assign signal_wire_67 = signal_select_67;
    assign signal_select_68 = signal_inst_3[154:131];
    assign signal_wire_68 = signal_select_68;
    assign signal_select_69 = signal_inst_3[130:115];
    assign signal_wire_69 = signal_select_69;
    assign signal_select_70 = signal_inst_3[114:99];
    assign signal_wire_70 = signal_select_70;
    assign signal_select_71 = signal_inst_3[98:83];
    assign signal_wire_71 = signal_select_71;
    assign signal_select_72 = signal_inst_3[73:65];
    assign signal_wire_72 = signal_select_72;
    assign signal_select_73 = signal_inst_3[64:56];
    assign signal_wire_73 = signal_select_73;
    assign signal_const_5 = 4'b1000;
    assign signal_select_74 = signal_inst_1[278:275];
    assign signal_wire_74 = signal_select_74;
    assign route_full$0 = signal_wire_74 == signal_const_5;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg <= signal_const;
        else
            if (signal_and_6)
                signal_reg <= signal_wire_93;
    end
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_1 <= signal_const;
        else
            if (signal_and_6)
                signal_reg_1 <= signal_wire_94;
    end
    assign signal_const_8 = 16'b0000000000000000;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_2 <= signal_const_8;
        else
            if (signal_and_6)
                signal_reg_2 <= signal_wire_95;
    end
    assign signal_eq_2 = chosen == signal_const;
    assign signal_and_6 = go & signal_eq_2;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_3 <= signal_const;
        else
            if (signal_and_6)
                signal_reg_3 <= signal_wire_96;
    end
    assign signal_wire_75 = hosts$line_write$data_0;
    assign signal_wire_76 = hosts$line_write$addr_0;
    assign signal_const_11 = 28'b1111111100000000000000000000;
    assign signal_or_6 = signal_wire_78 | signal_const_11;
    assign signal_select_75 = signal_inst_1[27:0];
    assign signal_wire_77 = signal_select_75;
    assign signal_and_7 = signal_wire_77 & signal_or_6;
    assign signal_select_76 = signal_inst_1[55:28];
    assign signal_wire_78 = signal_select_76;
    assign signal_not_2 = ~ signal_wire_78;
    assign signal_const_12 = 8'b00000000;
    assign signal_cat = { signal_const_12,
                          signal_wire_100 };
    assign signal_and_8 = signal_cat & signal_not_2;
    assign signal_or_7 = signal_and_8 | signal_and_7;
    assign signal_wire_79 = hosts$flush_0;
    assign signal_wire_80 = hosts$stop_0;
    assign signal_wire_81 = hosts$clear_irq_0;
    assign signal_wire_82 = hosts$rx_pop_0;
    assign signal_select_77 = signal_inst_1[407:392];
    assign signal_wire_83 = signal_select_77;
    assign signal_wire_84 = hosts$tx$value_0;
    assign signal_mux_4 = signal_wire_131 ? signal_wire_83 : signal_wire_84;
    assign signal_select_78 = signal_inst_1[391:391];
    assign signal_wire_85 = signal_select_78;
    assign signal_wire_86 = hosts$tx$valid_0;
    assign signal_mux_5 = signal_wire_131 ? signal_wire_85 : signal_wire_86;
    assign signal_and_9 = lent$0 & signal_wire_119;
    assign signal_wire_87 = hosts$program_write$data_0;
    assign signal_wire_88 = hosts$program_write$addr_0;
    assign signal_eq_3 = checked == signal_const;
    assign signal_and_10 = accepts & signal_eq_3;
    assign signal_mux_6 = signal_and_10 ? vdd : certified$0;
    assign signal_eq_4 = chosen == signal_const;
    assign signal_or_8 = asks$0 | asks$1;
    assign signal_select_79 = signal_inst[15:0];
    assign signal_mux_7 = checked ? signal_select_91 : signal_select_79;
    assign signal_select_80 = signal_inst_1[330:315];
    assign signal_wire_89 = signal_select_80;
    assign signal_select_81 = signal_inst_3[330:315];
    assign signal_wire_90 = signal_select_81;
    assign signal_mux_8 = checked ? signal_wire_89 : signal_wire_90;
    assign signal_wire_91 = check_setup$base;
    assign signal_mux_9 = checked ? signal_wire_131 : signal_wire_173;
    assign signal_mux_10 = checked ? signal_wire_132 : signal_wire_174;
    assign signal_mux_11 = checked ? signal_wire_133 : signal_wire_175;
    assign signal_mux_12 = checked ? signal_wire_134 : signal_wire_176;
    assign signal_mux_13 = checked ? signal_wire_135 : signal_wire_177;
    assign signal_mux_14 = checked ? signal_wire_136 : signal_wire_178;
    assign signal_mux_15 = checked ? signal_wire_137 : signal_wire_179;
    assign signal_mux_16 = checked ? signal_wire_138 : signal_wire_180;
    assign signal_mux_17 = checked ? signal_wire_139 : signal_wire_181;
    assign signal_mux_18 = checked ? signal_wire_140 : signal_wire_182;
    assign signal_mux_19 = checked ? signal_wire_141 : signal_wire_183;
    assign signal_mux_20 = checked ? signal_wire_142 : signal_wire_184;
    assign signal_mux_21 = checked ? signal_wire_143 : signal_wire_185;
    assign signal_mux_22 = checked ? signal_wire_144 : signal_wire_186;
    assign signal_mux_23 = checked ? signal_wire_145 : signal_wire_187;
    assign signal_mux_24 = checked ? signal_wire_146 : signal_wire_188;
    assign signal_mux_25 = checked ? signal_wire_147 : signal_wire_189;
    assign signal_mux_26 = checked ? signal_wire_148 : signal_wire_190;
    assign signal_mux_27 = checked ? signal_wire_149 : signal_wire_191;
    assign signal_mux_28 = checked ? signal_wire_150 : signal_wire_192;
    assign signal_mux_29 = checked ? signal_wire_151 : signal_wire_193;
    assign signal_mux_30 = checked ? signal_wire_152 : signal_wire_194;
    assign signal_mux_31 = checked ? signal_wire_153 : signal_wire_195;
    assign signal_mux_32 = checked ? signal_wire_154 : signal_wire_196;
    assign signal_mux_33 = checked ? signal_wire_155 : signal_wire_197;
    assign signal_mux_34 = checked ? signal_wire_156 : signal_wire_198;
    assign signal_mux_35 = checked ? signal_wire_157 : signal_wire_199;
    assign signal_mux_36 = checked ? signal_wire_158 : signal_wire_200;
    assign signal_mux_37 = checked ? signal_wire_159 : signal_wire_201;
    assign signal_mux_38 = checked ? signal_wire_160 : signal_wire_202;
    assign signal_mux_39 = checked ? signal_wire_161 : signal_wire_203;
    assign signal_not_3 = ~ lent$1;
    assign signal_not_4 = ~ lent$0;
    assign signal_mux_40 = checked ? signal_not_3 : signal_not_4;
    assign signal_or_9 = signal_wire_128 | signal_wire_127;
    assign signal_or_10 = signal_or_9 | signal_wire_126;
    assign signal_or_11 = signal_wire_170 | signal_wire_169;
    assign signal_or_12 = signal_or_11 | signal_wire_168;
    assign signal_mux_41 = asks$0 ? signal_const : signal_const_1;
    assign signal_select_82 = signal_inst_3[278:275];
    assign signal_wire_92 = signal_select_82;
    assign route_full$1 = signal_wire_92 == signal_const_5;
    assign signal_wire_93 = check_setup$single_edge;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_4 <= signal_const;
        else
            if (signal_and_11)
                signal_reg_4 <= signal_wire_93;
    end
    assign signal_wire_94 = check_setup$floor;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_5 <= signal_const;
        else
            if (signal_and_11)
                signal_reg_5 <= signal_wire_94;
    end
    assign signal_wire_95 = check_setup$loaded$value;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_6 <= signal_const_8;
        else
            if (signal_and_11)
                signal_reg_6 <= signal_wire_95;
    end
    assign signal_eq_5 = chosen == signal_const_1;
    assign signal_and_11 = go & signal_eq_5;
    assign signal_wire_96 = check_setup$loaded$valid;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_7 <= signal_const;
        else
            if (signal_and_11)
                signal_reg_7 <= signal_wire_96;
    end
    assign signal_wire_97 = hosts$line_write$data_1;
    assign signal_wire_98 = hosts$line_write$addr_1;
    assign signal_or_13 = signal_wire_99 | signal_const_11;
    assign signal_and_12 = signal_wire_206 & signal_or_13;
    assign signal_select_83 = signal_inst_3[55:28];
    assign signal_wire_99 = signal_select_83;
    assign signal_not_5 = ~ signal_wire_99;
    assign signal_wire_100 = pads;
    assign signal_cat_1 = { signal_const_12,
                            signal_wire_100 };
    assign signal_and_13 = signal_cat_1 & signal_not_5;
    assign signal_or_14 = signal_and_13 | signal_and_12;
    assign signal_wire_101 = hosts$flush_1;
    assign signal_wire_102 = hosts$stop_1;
    assign signal_wire_103 = hosts$clear_irq_1;
    assign signal_wire_104 = hosts$rx_pop_1;
    assign signal_select_84 = signal_inst_3[407:392];
    assign signal_wire_105 = signal_select_84;
    assign signal_wire_106 = hosts$tx$value_1;
    assign signal_mux_42 = signal_wire_173 ? signal_wire_105 : signal_wire_106;
    assign signal_select_85 = signal_inst_3[391:391];
    assign signal_wire_107 = signal_select_85;
    assign signal_wire_108 = hosts$tx$valid_1;
    assign signal_mux_43 = signal_wire_173 ? signal_wire_107 : signal_wire_108;
    assign signal_select_86 = signal_inst_1[82:74];
    assign signal_wire_109 = signal_select_86;
    assign signal_and_14 = lent$1 & signal_wire_112;
    assign signal_mux_44 = signal_and_14 ? signal_wire_110 : signal_wire_109;
    assign signal_select_87 = signal_inst_2[19:11];
    assign signal_wire_110 = signal_select_87;
    assign signal_select_88 = signal_inst_3[82:74];
    assign signal_wire_111 = signal_select_88;
    assign signal_select_89 = signal_inst_2[10:10];
    assign signal_wire_112 = signal_select_89;
    assign signal_select_90 = signal_inst_3[243:243];
    assign signal_wire_113 = signal_select_90;
    assign signal_eq_6 = checked == signal_const;
    assign signal_and_15 = checking & signal_eq_6;
    assign lent$0 = signal_and_15 & signal_wire_113;
    assign signal_and_16 = lent$0 & signal_wire_112;
    assign signal_mux_45 = signal_and_16 ? signal_wire_110 : signal_wire_111;
    assign signal_wire_114 = hosts$data_write$data_1;
    assign signal_wire_115 = hosts$data_write$addr_1;
    assign signal_wire_116 = hosts$data_write$data_0;
    assign signal_wire_117 = hosts$data_write$addr_0;
    data_memory
        data_memory
        ( .clock(signal_wire_205),
          .clear(signal_wire_204),
          .halted_0(signal_wire_164),
          .halted_1(signal_wire_162),
          .writes$valid_0(signal_wire_167),
          .writes$addr_0(signal_wire_117),
          .writes$data_0(signal_wire_116),
          .writes$valid_1(signal_wire_166),
          .writes$addr_1(signal_wire_115),
          .writes$data_1(signal_wire_114),
          .reads_0(signal_mux_45),
          .reads_1(signal_mux_44),
          .words_0(signal_inst[15:0]),
          .words_1(signal_inst[31:16]) );
    assign signal_select_91 = signal_inst[31:16];
    assign signal_select_92 = signal_inst_2[9:1];
    assign signal_wire_118 = signal_select_92;
    assign signal_select_93 = signal_inst_2[0:0];
    assign signal_wire_119 = signal_select_93;
    assign signal_select_94 = signal_inst_1[243:243];
    assign signal_wire_120 = signal_select_94;
    assign signal_eq_7 = checked == signal_const_1;
    assign signal_and_17 = checking & signal_eq_7;
    assign lent$1 = signal_and_17 & signal_wire_120;
    assign signal_and_18 = lent$1 & signal_wire_119;
    assign signal_wire_121 = hosts$program_write$data_1;
    assign signal_wire_122 = hosts$program_write$addr_1;
    assign signal_and_19 = signal_wire_162 & certified$1;
    assign signal_and_20 = signal_wire_164 & certified$0;
    assign all_ready = signal_and_20 & signal_and_19;
    assign signal_wire_123 = start_all;
    assign starts_all = signal_wire_123 & all_ready;
    assign gnd = 1'b0;
    assign vdd = 1'b1;
    assign signal_eq_8 = checked == signal_const_1;
    assign signal_select_95 = signal_inst_2[22:22];
    assign signal_wire_124 = signal_select_95;
    assign signal_select_96 = signal_inst_2[21:21];
    assign signal_wire_125 = signal_select_96;
    assign accepts = signal_wire_125 & signal_wire_124;
    assign signal_and_21 = accepts & signal_eq_8;
    assign signal_mux_46 = signal_and_21 ? vdd : certified$1;
    assign signal_eq_9 = chosen == signal_const_1;
    assign signal_and_22 = go & signal_eq_9;
    assign signal_wire_126 = hosts$line_write$valid_1;
    assign signal_wire_127 = hosts$config_written_1;
    assign signal_wire_128 = hosts$program_write$valid_1;
    assign signal_or_15 = signal_wire_128 | signal_wire_127;
    assign signal_or_16 = signal_or_15 | signal_wire_126;
    assign signal_or_17 = signal_or_16 | signal_and_22;
    assign signal_mux_47 = signal_or_17 ? gnd : signal_mux_46;
    assign signal_wire_129 = signal_mux_47;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            certified$1 <= signal_const;
        else
            certified$1 <= signal_wire_129;
    end
    assign signal_wire_130 = hosts$start_1;
    assign signal_and_23 = signal_wire_130 & certified$1;
    assign signal_or_18 = signal_and_23 | starts_all;
    assign signal_wire_131 = hosts$config$route_1;
    assign signal_wire_132 = hosts$config$line_code_1;
    assign signal_wire_133 = hosts$config$manchester_1;
    assign signal_wire_134 = hosts$config$autopull_data_1;
    assign signal_wire_135 = hosts$config$period_fraction_1;
    assign signal_wire_136 = hosts$config$wrap_top_1;
    assign signal_wire_137 = hosts$config$wrap_bottom_1;
    assign signal_wire_138 = hosts$config$stuff_level_1;
    assign signal_wire_139 = hosts$config$stuff_threshold_1;
    assign signal_wire_140 = hosts$config$crc_reflect_1;
    assign signal_wire_141 = hosts$config$crc_init_1;
    assign signal_wire_142 = hosts$config$crc_poly_1;
    assign signal_wire_143 = hosts$config$crc_width_1;
    assign signal_wire_144 = hosts$config$pull_threshold_1;
    assign signal_wire_145 = hosts$config$autopull_1;
    assign signal_wire_146 = hosts$config$push_threshold_1;
    assign signal_wire_147 = hosts$config$autopush_1;
    assign signal_wire_148 = hosts$config$out_shift_right_1;
    assign signal_wire_149 = hosts$config$in_shift_right_1;
    assign signal_wire_150 = hosts$config$capture_rising_1;
    assign signal_wire_151 = hosts$config$capture_pin_1;
    assign signal_wire_152 = hosts$config$jmp_pin_1;
    assign signal_wire_153 = hosts$config$set_count_1;
    assign signal_wire_154 = hosts$config$set_base_1;
    assign signal_wire_155 = hosts$config$out_count_1;
    assign signal_wire_156 = hosts$config$out_base_1;
    assign signal_wire_157 = hosts$config$in_count_1;
    assign signal_wire_158 = hosts$config$in_base_1;
    assign signal_wire_159 = hosts$config$side_set_pindirs_1;
    assign signal_wire_160 = hosts$config$side_set_base_1;
    assign signal_wire_161 = hosts$config$side_set_count_1;
    engine
        engine_1
        ( .clock(signal_wire_205),
          .clear(signal_wire_204),
          .config$side_set_count(signal_wire_161),
          .config$side_set_base(signal_wire_160),
          .config$side_set_pindirs(signal_wire_159),
          .config$in_base(signal_wire_158),
          .config$in_count(signal_wire_157),
          .config$out_base(signal_wire_156),
          .config$out_count(signal_wire_155),
          .config$set_base(signal_wire_154),
          .config$set_count(signal_wire_153),
          .config$jmp_pin(signal_wire_152),
          .config$capture_pin(signal_wire_151),
          .config$capture_rising(signal_wire_150),
          .config$in_shift_right(signal_wire_149),
          .config$out_shift_right(signal_wire_148),
          .config$autopush(signal_wire_147),
          .config$push_threshold(signal_wire_146),
          .config$autopull(signal_wire_145),
          .config$pull_threshold(signal_wire_144),
          .config$crc_width(signal_wire_143),
          .config$crc_poly(signal_wire_142),
          .config$crc_init(signal_wire_141),
          .config$crc_reflect(signal_wire_140),
          .config$stuff_threshold(signal_wire_139),
          .config$stuff_level(signal_wire_138),
          .config$wrap_bottom(signal_wire_137),
          .config$wrap_top(signal_wire_136),
          .config$period_fraction(signal_wire_135),
          .config$autopull_data(signal_wire_134),
          .config$manchester(signal_wire_133),
          .config$line_code(signal_wire_132),
          .config$route(signal_wire_131),
          .start(signal_or_18),
          .program_write$valid(signal_wire_128),
          .program_write$addr(signal_wire_122),
          .program_write$data(signal_wire_121),
          .program_read$valid(signal_and_18),
          .program_read$value(signal_wire_118),
          .data_word(signal_select_91),
          .tx$valid(signal_mux_43),
          .tx$value(signal_mux_42),
          .rx_pop(signal_wire_104),
          .clear_irq(signal_wire_103),
          .stop(signal_wire_102),
          .flush(signal_wire_101),
          .inputs(signal_or_14),
          .line_write$valid(signal_wire_126),
          .line_write$addr(signal_wire_98),
          .line_write$data(signal_wire_97),
          .premises$period$valid(signal_reg_7),
          .premises$period$value(signal_reg_6),
          .premises$floor(signal_reg_5),
          .premises$single_edge(signal_reg_4),
          .route_full(route_full$1),
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
          .free(signal_inst_1[243:243]),
          .irq(signal_inst_1[244:244]),
          .fault$underflow(signal_inst_1[245:245]),
          .fault$overflow(signal_inst_1[246:246]),
          .fault$missed_deadline(signal_inst_1[247:247]),
          .fault$decode(signal_inst_1[248:248]),
          .fault$assumption(signal_inst_1[249:249]),
          .capture(signal_inst_1[273:250]),
          .capture_armed(signal_inst_1[274:274]),
          .tx_level(signal_inst_1[278:275]),
          .rx_level(signal_inst_1[282:279]),
          .rx_head(signal_inst_1[298:283]),
          .instruction(signal_inst_1[314:299]),
          .program_word(signal_inst_1[330:315]),
          .decode_ok(signal_inst_1[331:331]),
          .opcode_onehot(signal_inst_1[339:332]),
          .wait_select(signal_inst_1[367:340]),
          .crc(signal_inst_1[383:368]),
          .stuff_run(signal_inst_1[388:384]),
          .flip_pending(signal_inst_1[389:389]),
          .flip_bit(signal_inst_1[390:390]),
          .push$valid(signal_inst_1[391:391]),
          .push$value(signal_inst_1[407:392]),
          .line_tx(signal_inst_1[411:408]),
          .line_rx(signal_inst_1[415:412]),
          .line_flag(signal_inst_1[416:416]),
          .line_last(signal_inst_1[417:417]) );
    assign signal_select_97 = signal_inst_1[242:242];
    assign signal_wire_162 = signal_select_97;
    assign signal_wire_163 = hosts$check_1;
    assign asks$1 = signal_wire_163 & signal_wire_162;
    assign signal_select_98 = signal_inst_3[242:242];
    assign signal_wire_164 = signal_select_98;
    assign signal_wire_165 = hosts$check_0;
    assign asks$0 = signal_wire_165 & signal_wire_164;
    assign signal_or_19 = asks$0 | asks$1;
    assign chosen = signal_or_19 ? signal_mux_41 : signal_const;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            signal_reg_8 <= signal_const;
        else
            if (go)
                signal_reg_8 <= chosen;
    end
    assign checked = signal_reg_8;
    assign signal_mux_48 = checked ? signal_or_10 : signal_or_12;
    assign signal_wire_166 = hosts$data_write$valid_1;
    assign signal_wire_167 = hosts$data_write$valid_0;
    assign signal_or_20 = signal_wire_167 | signal_wire_166;
    assign signal_or_21 = signal_or_20 | signal_mux_48;
    assign signal_or_22 = signal_or_21 | signal_mux_40;
    assign abort = checking & signal_or_22;
    load_checker
        load_checker
        ( .clock(signal_wire_205),
          .clear(signal_wire_204),
          .check(go),
          .abort(abort),
          .config$side_set_count(signal_mux_39),
          .config$side_set_base(signal_mux_38),
          .config$side_set_pindirs(signal_mux_37),
          .config$in_base(signal_mux_36),
          .config$in_count(signal_mux_35),
          .config$out_base(signal_mux_34),
          .config$out_count(signal_mux_33),
          .config$set_base(signal_mux_32),
          .config$set_count(signal_mux_31),
          .config$jmp_pin(signal_mux_30),
          .config$capture_pin(signal_mux_29),
          .config$capture_rising(signal_mux_28),
          .config$in_shift_right(signal_mux_27),
          .config$out_shift_right(signal_mux_26),
          .config$autopush(signal_mux_25),
          .config$push_threshold(signal_mux_24),
          .config$autopull(signal_mux_23),
          .config$pull_threshold(signal_mux_22),
          .config$crc_width(signal_mux_21),
          .config$crc_poly(signal_mux_20),
          .config$crc_init(signal_mux_19),
          .config$crc_reflect(signal_mux_18),
          .config$stuff_threshold(signal_mux_17),
          .config$stuff_level(signal_mux_16),
          .config$wrap_bottom(signal_mux_15),
          .config$wrap_top(signal_mux_14),
          .config$period_fraction(signal_mux_13),
          .config$autopull_data(signal_mux_12),
          .config$manchester(signal_mux_11),
          .config$line_code(signal_mux_10),
          .config$route(signal_mux_9),
          .setup$base(signal_wire_91),
          .setup$loaded$valid(signal_wire_96),
          .setup$loaded$value(signal_wire_95),
          .setup$floor(signal_wire_94),
          .setup$single_edge(signal_wire_93),
          .program_word(signal_mux_8),
          .data_word(signal_mux_7),
          .program_read$valid(signal_inst_2[0:0]),
          .program_read$value(signal_inst_2[9:1]),
          .data_read$valid(signal_inst_2[10:10]),
          .data_read$value(signal_inst_2[19:11]),
          .busy(signal_inst_2[20:20]),
          .finished(signal_inst_2[21:21]),
          .accepted(signal_inst_2[22:22]),
          .reject_pc(signal_inst_2[32:23]),
          .reason(signal_inst_2[37:33]) );
    assign signal_select_99 = signal_inst_2[20:20];
    assign checking = signal_select_99;
    assign signal_not_6 = ~ checking;
    assign go = signal_not_6 & signal_or_8;
    assign signal_and_24 = go & signal_eq_4;
    assign signal_wire_168 = hosts$line_write$valid_0;
    assign signal_wire_169 = hosts$config_written_0;
    assign signal_wire_170 = hosts$program_write$valid_0;
    assign signal_or_23 = signal_wire_170 | signal_wire_169;
    assign signal_or_24 = signal_or_23 | signal_wire_168;
    assign signal_or_25 = signal_or_24 | signal_and_24;
    assign signal_mux_49 = signal_or_25 ? gnd : signal_mux_6;
    assign signal_wire_171 = signal_mux_49;
    always @(posedge signal_wire_205) begin
        if (signal_wire_204)
            certified$0 <= signal_const;
        else
            certified$0 <= signal_wire_171;
    end
    assign signal_wire_172 = hosts$start_0;
    assign signal_and_25 = signal_wire_172 & certified$0;
    assign signal_or_26 = signal_and_25 | starts_all;
    assign signal_wire_173 = hosts$config$route_0;
    assign signal_wire_174 = hosts$config$line_code_0;
    assign signal_wire_175 = hosts$config$manchester_0;
    assign signal_wire_176 = hosts$config$autopull_data_0;
    assign signal_wire_177 = hosts$config$period_fraction_0;
    assign signal_wire_178 = hosts$config$wrap_top_0;
    assign signal_wire_179 = hosts$config$wrap_bottom_0;
    assign signal_wire_180 = hosts$config$stuff_level_0;
    assign signal_wire_181 = hosts$config$stuff_threshold_0;
    assign signal_wire_182 = hosts$config$crc_reflect_0;
    assign signal_wire_183 = hosts$config$crc_init_0;
    assign signal_wire_184 = hosts$config$crc_poly_0;
    assign signal_wire_185 = hosts$config$crc_width_0;
    assign signal_wire_186 = hosts$config$pull_threshold_0;
    assign signal_wire_187 = hosts$config$autopull_0;
    assign signal_wire_188 = hosts$config$push_threshold_0;
    assign signal_wire_189 = hosts$config$autopush_0;
    assign signal_wire_190 = hosts$config$out_shift_right_0;
    assign signal_wire_191 = hosts$config$in_shift_right_0;
    assign signal_wire_192 = hosts$config$capture_rising_0;
    assign signal_wire_193 = hosts$config$capture_pin_0;
    assign signal_wire_194 = hosts$config$jmp_pin_0;
    assign signal_wire_195 = hosts$config$set_count_0;
    assign signal_wire_196 = hosts$config$set_base_0;
    assign signal_wire_197 = hosts$config$out_count_0;
    assign signal_wire_198 = hosts$config$out_base_0;
    assign signal_wire_199 = hosts$config$in_count_0;
    assign signal_wire_200 = hosts$config$in_base_0;
    assign signal_wire_201 = hosts$config$side_set_pindirs_0;
    assign signal_wire_202 = hosts$config$side_set_base_0;
    assign signal_wire_203 = hosts$config$side_set_count_0;
    assign signal_wire_204 = clear;
    assign signal_wire_205 = clock;
    engine
        engine_0
        ( .clock(signal_wire_205),
          .clear(signal_wire_204),
          .config$side_set_count(signal_wire_203),
          .config$side_set_base(signal_wire_202),
          .config$side_set_pindirs(signal_wire_201),
          .config$in_base(signal_wire_200),
          .config$in_count(signal_wire_199),
          .config$out_base(signal_wire_198),
          .config$out_count(signal_wire_197),
          .config$set_base(signal_wire_196),
          .config$set_count(signal_wire_195),
          .config$jmp_pin(signal_wire_194),
          .config$capture_pin(signal_wire_193),
          .config$capture_rising(signal_wire_192),
          .config$in_shift_right(signal_wire_191),
          .config$out_shift_right(signal_wire_190),
          .config$autopush(signal_wire_189),
          .config$push_threshold(signal_wire_188),
          .config$autopull(signal_wire_187),
          .config$pull_threshold(signal_wire_186),
          .config$crc_width(signal_wire_185),
          .config$crc_poly(signal_wire_184),
          .config$crc_init(signal_wire_183),
          .config$crc_reflect(signal_wire_182),
          .config$stuff_threshold(signal_wire_181),
          .config$stuff_level(signal_wire_180),
          .config$wrap_bottom(signal_wire_179),
          .config$wrap_top(signal_wire_178),
          .config$period_fraction(signal_wire_177),
          .config$autopull_data(signal_wire_176),
          .config$manchester(signal_wire_175),
          .config$line_code(signal_wire_174),
          .config$route(signal_wire_173),
          .start(signal_or_26),
          .program_write$valid(signal_wire_170),
          .program_write$addr(signal_wire_88),
          .program_write$data(signal_wire_87),
          .program_read$valid(signal_and_9),
          .program_read$value(signal_wire_118),
          .data_word(signal_select_79),
          .tx$valid(signal_mux_5),
          .tx$value(signal_mux_4),
          .rx_pop(signal_wire_82),
          .clear_irq(signal_wire_81),
          .stop(signal_wire_80),
          .flush(signal_wire_79),
          .inputs(signal_or_7),
          .line_write$valid(signal_wire_168),
          .line_write$addr(signal_wire_76),
          .line_write$data(signal_wire_75),
          .premises$period$valid(signal_reg_3),
          .premises$period$value(signal_reg_2),
          .premises$floor(signal_reg_1),
          .premises$single_edge(signal_reg),
          .route_full(route_full$0),
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
          .free(signal_inst_3[243:243]),
          .irq(signal_inst_3[244:244]),
          .fault$underflow(signal_inst_3[245:245]),
          .fault$overflow(signal_inst_3[246:246]),
          .fault$missed_deadline(signal_inst_3[247:247]),
          .fault$decode(signal_inst_3[248:248]),
          .fault$assumption(signal_inst_3[249:249]),
          .capture(signal_inst_3[273:250]),
          .capture_armed(signal_inst_3[274:274]),
          .tx_level(signal_inst_3[278:275]),
          .rx_level(signal_inst_3[282:279]),
          .rx_head(signal_inst_3[298:283]),
          .instruction(signal_inst_3[314:299]),
          .program_word(signal_inst_3[330:315]),
          .decode_ok(signal_inst_3[331:331]),
          .opcode_onehot(signal_inst_3[339:332]),
          .wait_select(signal_inst_3[367:340]),
          .crc(signal_inst_3[383:368]),
          .stuff_run(signal_inst_3[388:384]),
          .flip_pending(signal_inst_3[389:389]),
          .flip_bit(signal_inst_3[390:390]),
          .push$valid(signal_inst_3[391:391]),
          .push$value(signal_inst_3[407:392]),
          .line_tx(signal_inst_3[411:408]),
          .line_rx(signal_inst_3[415:412]),
          .line_flag(signal_inst_3[416:416]),
          .line_last(signal_inst_3[417:417]) );
    assign signal_select_100 = signal_inst_3[27:0];
    assign signal_wire_206 = signal_select_100;
    assign engines$pin_out_0 = signal_wire_206;
    assign engines$pin_dir_0 = signal_wire_99;
    assign engines$pc_0 = signal_wire_73;
    assign engines$data_ptr_0 = signal_wire_72;
    assign engines$data_addr_0 = signal_wire_111;
    assign engines$x_0 = signal_wire_71;
    assign engines$y_0 = signal_wire_70;
    assign engines$p_0 = signal_wire_69;
    assign engines$t_0 = signal_wire_68;
    assign engines$t_fraction_0 = signal_wire_67;
    assign engines$osr_0 = signal_wire_66;
    assign engines$osr_count_0 = signal_wire_65;
    assign engines$isr_0 = signal_wire_64;
    assign engines$isr_count_0 = signal_wire_63;
    assign engines$now_0 = signal_wire_62;
    assign engines$stall_0 = signal_wire_61;
    assign engines$halted_0 = signal_wire_164;
    assign engines$free_0 = signal_wire_113;
    assign engines$irq_0 = signal_wire_60;
    assign engines$fault$underflow_0 = signal_wire_59;
    assign engines$fault$overflow_0 = signal_wire_58;
    assign engines$fault$missed_deadline_0 = signal_wire_57;
    assign engines$fault$decode_0 = signal_wire_56;
    assign engines$fault$assumption_0 = signal_wire_55;
    assign engines$capture_0 = signal_wire_54;
    assign engines$capture_armed_0 = signal_wire_53;
    assign engines$tx_level_0 = signal_wire_92;
    assign engines$rx_level_0 = signal_wire_52;
    assign engines$rx_head_0 = signal_wire_51;
    assign engines$instruction_0 = signal_wire_50;
    assign engines$program_word_0 = signal_wire_90;
    assign engines$decode_ok_0 = signal_wire_49;
    assign engines$opcode_onehot_0 = signal_wire_48;
    assign engines$wait_select_0 = signal_wire_47;
    assign engines$crc_0 = signal_wire_46;
    assign engines$stuff_run_0 = signal_wire_45;
    assign engines$flip_pending_0 = signal_wire_44;
    assign engines$flip_bit_0 = signal_wire_43;
    assign engines$push$valid_0 = signal_wire_107;
    assign engines$push$value_0 = signal_wire_105;
    assign engines$line_tx_0 = signal_wire_42;
    assign engines$line_rx_0 = signal_wire_41;
    assign engines$line_flag_0 = signal_wire_40;
    assign engines$line_last_0 = signal_wire_39;
    assign engines$pin_out_1 = signal_wire_77;
    assign engines$pin_dir_1 = signal_wire_78;
    assign engines$pc_1 = signal_wire_38;
    assign engines$data_ptr_1 = signal_wire_37;
    assign engines$data_addr_1 = signal_wire_109;
    assign engines$x_1 = signal_wire_36;
    assign engines$y_1 = signal_wire_35;
    assign engines$p_1 = signal_wire_34;
    assign engines$t_1 = signal_wire_33;
    assign engines$t_fraction_1 = signal_wire_32;
    assign engines$osr_1 = signal_wire_31;
    assign engines$osr_count_1 = signal_wire_30;
    assign engines$isr_1 = signal_wire_29;
    assign engines$isr_count_1 = signal_wire_28;
    assign engines$now_1 = signal_wire_27;
    assign engines$stall_1 = signal_wire_26;
    assign engines$halted_1 = signal_wire_162;
    assign engines$free_1 = signal_wire_120;
    assign engines$irq_1 = signal_wire_25;
    assign engines$fault$underflow_1 = signal_wire_24;
    assign engines$fault$overflow_1 = signal_wire_23;
    assign engines$fault$missed_deadline_1 = signal_wire_22;
    assign engines$fault$decode_1 = signal_wire_21;
    assign engines$fault$assumption_1 = signal_wire_20;
    assign engines$capture_1 = signal_wire_19;
    assign engines$capture_armed_1 = signal_wire_18;
    assign engines$tx_level_1 = signal_wire_74;
    assign engines$rx_level_1 = signal_wire_17;
    assign engines$rx_head_1 = signal_wire_16;
    assign engines$instruction_1 = signal_wire_15;
    assign engines$program_word_1 = signal_wire_89;
    assign engines$decode_ok_1 = signal_wire_14;
    assign engines$opcode_onehot_1 = signal_wire_13;
    assign engines$wait_select_1 = signal_wire_12;
    assign engines$crc_1 = signal_wire_11;
    assign engines$stuff_run_1 = signal_wire_10;
    assign engines$flip_pending_1 = signal_wire_9;
    assign engines$flip_bit_1 = signal_wire_8;
    assign engines$push$valid_1 = signal_wire_85;
    assign engines$push$value_1 = signal_wire_83;
    assign engines$line_tx_1 = signal_wire_7;
    assign engines$line_rx_1 = signal_wire_6;
    assign engines$line_flag_1 = signal_wire_5;
    assign engines$line_last_1 = signal_wire_4;
    assign pin_out = signal_select_3;
    assign pin_dir = signal_select_2;
    assign check$verdict$busy = checking;
    assign check$verdict$accepted = signal_wire_124;
    assign check$verdict$reject_pc = signal_wire_3;
    assign check$verdict$reason = signal_wire_2;
    assign check$certified_0 = certified$0;
    assign check$certified_1 = certified$1;
    assign check$refused_0 = refused$0;
    assign check$refused_1 = refused$1;

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
    status$fault$assumption_0,
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
    status$fault$assumption_1,
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
    engines$config$line_code_0,
    engines$config$route_0,
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
    engines$line_write$valid_0,
    engines$line_write$addr_0,
    engines$line_write$data_0,
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
    engines$config$line_code_1,
    engines$config$route_1,
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
    engines$line_write$valid_1,
    engines$line_write$addr_1,
    engines$line_write$data_1,
    check_setup$base,
    check_setup$loaded$valid,
    check_setup$loaded$value,
    check_setup$floor,
    check_setup$single_edge,
    start_all
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
    input status$fault$assumption_0;
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
    input status$fault$assumption_1;
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
    output engines$config$line_code_0;
    output engines$config$route_0;
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
    output engines$line_write$valid_0;
    output [4:0] engines$line_write$addr_0;
    output [15:0] engines$line_write$data_0;
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
    output engines$config$line_code_1;
    output engines$config$route_1;
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
    output engines$line_write$valid_1;
    output [4:0] engines$line_write$addr_1;
    output [15:0] engines$line_write$data_1;
    output [8:0] check_setup$base;
    output check_setup$loaded$valid;
    output [15:0] check_setup$loaded$value;
    output check_setup$floor;
    output check_setup$single_edge;
    output start_all;

    wire signal_select;
    wire [6:0] signal_const;
    wire signal_eq;
    wire signal_and;
    wire signal_and_1;
    wire signal_select_1;
    wire signal_select_2;
    wire signal_select_3;
    wire signal_const_1;
    wire signal_eq_1;
    wire [6:0] signal_const_2;
    wire signal_eq_2;
    wire signal_and_2;
    wire signal_and_3;
    wire signal_eq_3;
    wire signal_and_4;
    wire signal_and_5;
    wire signal_eq_4;
    wire signal_select_4;
    wire signal_eq_5;
    wire signal_and_6;
    wire signal_and_7;
    wire signal_and_8;
    wire signal_eq_6;
    wire signal_select_5;
    wire signal_eq_7;
    wire signal_and_9;
    wire signal_and_10;
    wire signal_and_11;
    wire signal_eq_8;
    wire signal_select_6;
    wire signal_eq_9;
    wire signal_and_12;
    wire signal_and_13;
    wire signal_and_14;
    wire signal_eq_10;
    wire signal_select_7;
    wire signal_eq_11;
    wire signal_and_15;
    wire signal_and_16;
    wire signal_and_17;
    wire signal_eq_12;
    wire [6:0] signal_const_13;
    wire signal_eq_13;
    wire signal_and_18;
    wire signal_and_19;
    wire signal_eq_14;
    wire [6:0] signal_const_15;
    wire signal_eq_15;
    wire signal_and_20;
    wire signal_and_21;
    wire signal_eq_16;
    wire [6:0] signal_const_17;
    wire signal_eq_17;
    wire signal_and_22;
    wire signal_and_23;
    wire signal_eq_18;
    wire [6:0] signal_const_19;
    wire signal_eq_19;
    wire signal_and_24;
    wire signal_and_25;
    wire signal_eq_20;
    wire signal_select_8;
    wire signal_eq_21;
    wire signal_and_26;
    wire signal_and_27;
    wire signal_and_28;
    wire signal_const_22;
    wire signal_select_9;
    wire signal_eq_22;
    wire [6:0] signal_const_24;
    wire signal_eq_23;
    wire signal_and_29;
    wire signal_and_30;
    wire signal_mux;
    wire signal_mux_1;
    wire signal_wire;
    reg signal_reg;
    wire signal_select_10;
    wire signal_eq_24;
    wire [6:0] signal_const_27;
    wire signal_eq_25;
    wire signal_and_31;
    wire signal_and_32;
    wire signal_mux_2;
    wire signal_mux_3;
    wire signal_wire_1;
    reg signal_reg_1;
    wire signal_select_11;
    wire signal_eq_26;
    wire [6:0] signal_const_30;
    wire signal_eq_27;
    wire signal_and_33;
    wire signal_and_34;
    wire signal_mux_4;
    wire signal_mux_5;
    wire signal_wire_2;
    reg signal_reg_2;
    wire signal_select_12;
    wire signal_eq_28;
    wire [6:0] signal_const_33;
    wire signal_eq_29;
    wire signal_and_35;
    wire signal_and_36;
    wire signal_mux_6;
    wire signal_mux_7;
    wire signal_wire_3;
    reg signal_reg_3;
    wire [15:0] signal_const_34;
    wire signal_eq_30;
    wire [6:0] signal_const_36;
    wire signal_eq_31;
    wire signal_and_37;
    wire signal_and_38;
    wire [15:0] signal_mux_8;
    wire [15:0] signal_mux_9;
    wire [15:0] signal_wire_4;
    reg [15:0] signal_reg_4;
    wire [8:0] signal_const_37;
    wire [8:0] signal_select_13;
    wire signal_eq_32;
    wire [6:0] signal_const_39;
    wire signal_eq_33;
    wire signal_and_39;
    wire signal_and_40;
    wire [8:0] signal_mux_10;
    wire [8:0] signal_mux_11;
    wire [8:0] signal_wire_5;
    reg [8:0] signal_reg_5;
    wire [8:0] signal_select_14;
    wire signal_eq_34;
    wire [6:0] signal_const_42;
    wire signal_eq_35;
    wire signal_and_41;
    wire signal_and_42;
    wire [8:0] signal_mux_12;
    wire [8:0] signal_mux_13;
    wire [8:0] signal_wire_6;
    reg [8:0] signal_reg_6;
    wire signal_select_15;
    wire signal_eq_36;
    wire [6:0] signal_const_45;
    wire signal_eq_37;
    wire signal_and_43;
    wire signal_and_44;
    wire signal_mux_14;
    wire signal_mux_15;
    wire signal_wire_7;
    reg signal_reg_7;
    wire [4:0] signal_const_46;
    wire [4:0] signal_select_16;
    wire signal_eq_38;
    wire [6:0] signal_const_48;
    wire signal_eq_39;
    wire signal_and_45;
    wire signal_and_46;
    wire [4:0] signal_mux_16;
    wire [4:0] signal_mux_17;
    wire [4:0] signal_wire_8;
    reg [4:0] signal_reg_8;
    wire signal_select_17;
    wire signal_eq_40;
    wire [6:0] signal_const_51;
    wire signal_eq_41;
    wire signal_and_47;
    wire signal_and_48;
    wire signal_mux_18;
    wire signal_mux_19;
    wire signal_wire_9;
    reg signal_reg_9;
    wire signal_eq_42;
    wire [6:0] signal_const_54;
    wire signal_eq_43;
    wire signal_and_49;
    wire signal_and_50;
    wire [15:0] signal_mux_20;
    wire [15:0] signal_mux_21;
    wire [15:0] signal_wire_10;
    reg [15:0] signal_reg_10;
    wire signal_eq_44;
    wire [6:0] signal_const_57;
    wire signal_eq_45;
    wire signal_and_51;
    wire signal_and_52;
    wire [15:0] signal_mux_22;
    wire [15:0] signal_mux_23;
    wire [15:0] signal_wire_11;
    reg [15:0] signal_reg_11;
    wire [4:0] signal_select_18;
    wire signal_eq_46;
    wire [6:0] signal_const_60;
    wire signal_eq_47;
    wire signal_and_53;
    wire signal_and_54;
    wire [4:0] signal_mux_24;
    wire [4:0] signal_mux_25;
    wire [4:0] signal_wire_12;
    reg [4:0] signal_reg_12;
    wire [4:0] signal_select_19;
    wire signal_eq_48;
    wire [6:0] signal_const_63;
    wire signal_eq_49;
    wire signal_and_55;
    wire signal_and_56;
    wire [4:0] signal_mux_26;
    wire [4:0] signal_mux_27;
    wire [4:0] signal_wire_13;
    reg [4:0] signal_reg_13;
    wire signal_select_20;
    wire signal_eq_50;
    wire [6:0] signal_const_66;
    wire signal_eq_51;
    wire signal_and_57;
    wire signal_and_58;
    wire signal_mux_28;
    wire signal_mux_29;
    wire signal_wire_14;
    reg signal_reg_14;
    wire [4:0] signal_select_21;
    wire signal_eq_52;
    wire [6:0] signal_const_69;
    wire signal_eq_53;
    wire signal_and_59;
    wire signal_and_60;
    wire [4:0] signal_mux_30;
    wire [4:0] signal_mux_31;
    wire [4:0] signal_wire_15;
    reg [4:0] signal_reg_15;
    wire signal_select_22;
    wire signal_eq_54;
    wire [6:0] signal_const_72;
    wire signal_eq_55;
    wire signal_and_61;
    wire signal_and_62;
    wire signal_mux_32;
    wire signal_mux_33;
    wire signal_wire_16;
    reg signal_reg_16;
    wire signal_select_23;
    wire signal_eq_56;
    wire [6:0] signal_const_75;
    wire signal_eq_57;
    wire signal_and_63;
    wire signal_and_64;
    wire signal_mux_34;
    wire signal_mux_35;
    wire signal_wire_17;
    reg signal_reg_17;
    wire signal_select_24;
    wire signal_eq_58;
    wire [6:0] signal_const_78;
    wire signal_eq_59;
    wire signal_and_65;
    wire signal_and_66;
    wire signal_mux_36;
    wire signal_mux_37;
    wire signal_wire_18;
    reg signal_reg_18;
    wire signal_select_25;
    wire signal_eq_60;
    wire [6:0] signal_const_81;
    wire signal_eq_61;
    wire signal_and_67;
    wire signal_and_68;
    wire signal_mux_38;
    wire signal_mux_39;
    wire signal_wire_19;
    reg signal_reg_19;
    wire [4:0] signal_select_26;
    wire signal_eq_62;
    wire [6:0] signal_const_84;
    wire signal_eq_63;
    wire signal_and_69;
    wire signal_and_70;
    wire [4:0] signal_mux_40;
    wire [4:0] signal_mux_41;
    wire [4:0] signal_wire_20;
    reg [4:0] signal_reg_20;
    wire [4:0] signal_select_27;
    wire signal_eq_64;
    wire [6:0] signal_const_87;
    wire signal_eq_65;
    wire signal_and_71;
    wire signal_and_72;
    wire [4:0] signal_mux_42;
    wire [4:0] signal_mux_43;
    wire [4:0] signal_wire_21;
    reg [4:0] signal_reg_21;
    wire [2:0] signal_const_88;
    wire [2:0] signal_select_28;
    wire signal_eq_66;
    wire [6:0] signal_const_90;
    wire signal_eq_67;
    wire signal_and_73;
    wire signal_and_74;
    wire [2:0] signal_mux_44;
    wire [2:0] signal_mux_45;
    wire [2:0] signal_wire_22;
    reg [2:0] signal_reg_22;
    wire [4:0] signal_select_29;
    wire signal_eq_68;
    wire [6:0] signal_const_93;
    wire signal_eq_69;
    wire signal_and_75;
    wire signal_and_76;
    wire [4:0] signal_mux_46;
    wire [4:0] signal_mux_47;
    wire [4:0] signal_wire_23;
    reg [4:0] signal_reg_23;
    wire [4:0] signal_select_30;
    wire signal_eq_70;
    wire [6:0] signal_const_96;
    wire signal_eq_71;
    wire signal_and_77;
    wire signal_and_78;
    wire [4:0] signal_mux_48;
    wire [4:0] signal_mux_49;
    wire [4:0] signal_wire_24;
    reg [4:0] signal_reg_24;
    wire [4:0] signal_select_31;
    wire signal_eq_72;
    wire [6:0] signal_const_99;
    wire signal_eq_73;
    wire signal_and_79;
    wire signal_and_80;
    wire [4:0] signal_mux_50;
    wire [4:0] signal_mux_51;
    wire [4:0] signal_wire_25;
    reg [4:0] signal_reg_25;
    wire [4:0] signal_select_32;
    wire signal_eq_74;
    wire [6:0] signal_const_102;
    wire signal_eq_75;
    wire signal_and_81;
    wire signal_and_82;
    wire [4:0] signal_mux_52;
    wire [4:0] signal_mux_53;
    wire [4:0] signal_wire_26;
    reg [4:0] signal_reg_26;
    wire [4:0] signal_select_33;
    wire signal_eq_76;
    wire [6:0] signal_const_105;
    wire signal_eq_77;
    wire signal_and_83;
    wire signal_and_84;
    wire [4:0] signal_mux_54;
    wire [4:0] signal_mux_55;
    wire [4:0] signal_wire_27;
    reg [4:0] signal_reg_27;
    wire signal_select_34;
    wire signal_eq_78;
    wire [6:0] signal_const_108;
    wire signal_eq_79;
    wire signal_and_85;
    wire signal_and_86;
    wire signal_mux_56;
    wire signal_mux_57;
    wire signal_wire_28;
    reg signal_reg_28;
    wire [4:0] signal_select_35;
    wire signal_eq_80;
    wire [6:0] signal_const_111;
    wire signal_eq_81;
    wire signal_and_87;
    wire signal_and_88;
    wire [4:0] signal_mux_58;
    wire [4:0] signal_mux_59;
    wire [4:0] signal_wire_29;
    reg [4:0] signal_reg_29;
    wire [1:0] signal_const_112;
    wire [1:0] signal_select_36;
    wire signal_eq_82;
    wire [6:0] signal_const_114;
    wire signal_eq_83;
    wire signal_and_89;
    wire signal_and_90;
    wire [1:0] signal_mux_60;
    wire [1:0] signal_mux_61;
    wire [1:0] signal_wire_30;
    reg [1:0] signal_reg_30;
    wire signal_eq_84;
    wire signal_eq_85;
    wire signal_and_91;
    wire signal_and_92;
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
    wire signal_eq_107;
    wire signal_eq_108;
    wire signal_eq_109;
    wire signal_eq_110;
    wire signal_eq_111;
    wire signal_eq_112;
    wire signal_eq_113;
    wire signal_eq_114;
    wire signal_eq_115;
    wire signal_eq_116;
    wire signal_eq_117;
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
    wire signal_or_28;
    wire signal_or_29;
    wire writes_config;
    wire signal_and_93;
    wire signal_and_94;
    wire signal_eq_118;
    wire signal_select_37;
    wire signal_eq_119;
    wire signal_and_95;
    wire signal_and_96;
    wire signal_and_97;
    wire signal_eq_120;
    wire signal_select_38;
    wire signal_eq_121;
    wire signal_and_98;
    wire signal_and_99;
    wire signal_and_100;
    wire signal_eq_122;
    wire signal_select_39;
    wire signal_eq_123;
    wire signal_and_101;
    wire signal_and_102;
    wire signal_and_103;
    wire signal_eq_124;
    wire signal_select_40;
    wire signal_eq_125;
    wire signal_and_104;
    wire signal_and_105;
    wire signal_and_106;
    wire signal_eq_126;
    wire signal_eq_127;
    wire signal_and_107;
    wire signal_and_108;
    wire signal_eq_128;
    wire signal_eq_129;
    wire signal_and_109;
    wire signal_and_110;
    wire signal_eq_130;
    wire signal_eq_131;
    wire signal_and_111;
    wire signal_and_112;
    wire signal_eq_132;
    wire signal_eq_133;
    wire signal_and_113;
    wire signal_and_114;
    wire signal_eq_134;
    wire signal_select_41;
    wire signal_eq_135;
    wire signal_and_115;
    wire signal_and_116;
    wire signal_and_117;
    wire signal_select_42;
    wire signal_eq_136;
    wire signal_eq_137;
    wire signal_and_118;
    wire signal_and_119;
    wire signal_mux_62;
    wire signal_mux_63;
    wire signal_wire_31;
    reg signal_reg_31;
    wire signal_select_43;
    wire signal_eq_138;
    wire signal_eq_139;
    wire signal_and_120;
    wire signal_and_121;
    wire signal_mux_64;
    wire signal_mux_65;
    wire signal_wire_32;
    reg signal_reg_32;
    wire signal_select_44;
    wire signal_eq_140;
    wire signal_eq_141;
    wire signal_and_122;
    wire signal_and_123;
    wire signal_mux_66;
    wire signal_mux_67;
    wire signal_wire_33;
    reg signal_reg_33;
    wire signal_select_45;
    wire signal_eq_142;
    wire signal_eq_143;
    wire signal_and_124;
    wire signal_and_125;
    wire signal_mux_68;
    wire signal_mux_69;
    wire signal_wire_34;
    reg signal_reg_34;
    wire signal_eq_144;
    wire signal_eq_145;
    wire signal_and_126;
    wire signal_and_127;
    wire [15:0] signal_mux_70;
    wire [15:0] signal_mux_71;
    wire [15:0] signal_wire_35;
    reg [15:0] signal_reg_35;
    wire [8:0] signal_select_46;
    wire signal_eq_146;
    wire signal_eq_147;
    wire signal_and_128;
    wire signal_and_129;
    wire [8:0] signal_mux_72;
    wire [8:0] signal_mux_73;
    wire [8:0] signal_wire_36;
    reg [8:0] signal_reg_36;
    wire [8:0] signal_select_47;
    wire signal_eq_148;
    wire signal_eq_149;
    wire signal_and_130;
    wire signal_and_131;
    wire [8:0] signal_mux_74;
    wire [8:0] signal_mux_75;
    wire [8:0] signal_wire_37;
    reg [8:0] signal_reg_37;
    wire signal_select_48;
    wire signal_eq_150;
    wire signal_eq_151;
    wire signal_and_132;
    wire signal_and_133;
    wire signal_mux_76;
    wire signal_mux_77;
    wire signal_wire_38;
    reg signal_reg_38;
    wire [4:0] signal_select_49;
    wire signal_eq_152;
    wire signal_eq_153;
    wire signal_and_134;
    wire signal_and_135;
    wire [4:0] signal_mux_78;
    wire [4:0] signal_mux_79;
    wire [4:0] signal_wire_39;
    reg [4:0] signal_reg_39;
    wire signal_select_50;
    wire signal_eq_154;
    wire signal_eq_155;
    wire signal_and_136;
    wire signal_and_137;
    wire signal_mux_80;
    wire signal_mux_81;
    wire signal_wire_40;
    reg signal_reg_40;
    wire signal_eq_156;
    wire signal_eq_157;
    wire signal_and_138;
    wire signal_and_139;
    wire [15:0] signal_mux_82;
    wire [15:0] signal_mux_83;
    wire [15:0] signal_wire_41;
    reg [15:0] signal_reg_41;
    wire signal_eq_158;
    wire signal_eq_159;
    wire signal_and_140;
    wire signal_and_141;
    wire [15:0] signal_mux_84;
    wire [15:0] signal_mux_85;
    wire [15:0] signal_wire_42;
    reg [15:0] signal_reg_42;
    wire [4:0] signal_select_51;
    wire signal_eq_160;
    wire signal_eq_161;
    wire signal_and_142;
    wire signal_and_143;
    wire [4:0] signal_mux_86;
    wire [4:0] signal_mux_87;
    wire [4:0] signal_wire_43;
    reg [4:0] signal_reg_43;
    wire [4:0] signal_select_52;
    wire signal_eq_162;
    wire signal_eq_163;
    wire signal_and_144;
    wire signal_and_145;
    wire [4:0] signal_mux_88;
    wire [4:0] signal_mux_89;
    wire [4:0] signal_wire_44;
    reg [4:0] signal_reg_44;
    wire signal_select_53;
    wire signal_eq_164;
    wire signal_eq_165;
    wire signal_and_146;
    wire signal_and_147;
    wire signal_mux_90;
    wire signal_mux_91;
    wire signal_wire_45;
    reg signal_reg_45;
    wire [4:0] signal_select_54;
    wire signal_eq_166;
    wire signal_eq_167;
    wire signal_and_148;
    wire signal_and_149;
    wire [4:0] signal_mux_92;
    wire [4:0] signal_mux_93;
    wire [4:0] signal_wire_46;
    reg [4:0] signal_reg_46;
    wire signal_select_55;
    wire signal_eq_168;
    wire signal_eq_169;
    wire signal_and_150;
    wire signal_and_151;
    wire signal_mux_94;
    wire signal_mux_95;
    wire signal_wire_47;
    reg signal_reg_47;
    wire signal_select_56;
    wire signal_eq_170;
    wire signal_eq_171;
    wire signal_and_152;
    wire signal_and_153;
    wire signal_mux_96;
    wire signal_mux_97;
    wire signal_wire_48;
    reg signal_reg_48;
    wire signal_select_57;
    wire signal_eq_172;
    wire signal_eq_173;
    wire signal_and_154;
    wire signal_and_155;
    wire signal_mux_98;
    wire signal_mux_99;
    wire signal_wire_49;
    reg signal_reg_49;
    wire signal_select_58;
    wire signal_eq_174;
    wire signal_eq_175;
    wire signal_and_156;
    wire signal_and_157;
    wire signal_mux_100;
    wire signal_mux_101;
    wire signal_wire_50;
    reg signal_reg_50;
    wire [4:0] signal_select_59;
    wire signal_eq_176;
    wire signal_eq_177;
    wire signal_and_158;
    wire signal_and_159;
    wire [4:0] signal_mux_102;
    wire [4:0] signal_mux_103;
    wire [4:0] signal_wire_51;
    reg [4:0] signal_reg_51;
    wire [4:0] signal_select_60;
    wire signal_eq_178;
    wire signal_eq_179;
    wire signal_and_160;
    wire signal_and_161;
    wire [4:0] signal_mux_104;
    wire [4:0] signal_mux_105;
    wire [4:0] signal_wire_52;
    reg [4:0] signal_reg_52;
    wire [2:0] signal_select_61;
    wire signal_eq_180;
    wire signal_eq_181;
    wire signal_and_162;
    wire signal_and_163;
    wire [2:0] signal_mux_106;
    wire [2:0] signal_mux_107;
    wire [2:0] signal_wire_53;
    reg [2:0] signal_reg_53;
    wire [4:0] signal_select_62;
    wire signal_eq_182;
    wire signal_eq_183;
    wire signal_and_164;
    wire signal_and_165;
    wire [4:0] signal_mux_108;
    wire [4:0] signal_mux_109;
    wire [4:0] signal_wire_54;
    reg [4:0] signal_reg_54;
    wire [4:0] signal_select_63;
    wire signal_eq_184;
    wire signal_eq_185;
    wire signal_and_166;
    wire signal_and_167;
    wire [4:0] signal_mux_110;
    wire [4:0] signal_mux_111;
    wire [4:0] signal_wire_55;
    reg [4:0] signal_reg_55;
    wire [4:0] signal_select_64;
    wire signal_eq_186;
    wire signal_eq_187;
    wire signal_and_168;
    wire signal_and_169;
    wire [4:0] signal_mux_112;
    wire [4:0] signal_mux_113;
    wire [4:0] signal_wire_56;
    reg [4:0] signal_reg_56;
    wire [4:0] signal_select_65;
    wire signal_eq_188;
    wire signal_eq_189;
    wire signal_and_170;
    wire signal_and_171;
    wire [4:0] signal_mux_114;
    wire [4:0] signal_mux_115;
    wire [4:0] signal_wire_57;
    reg [4:0] signal_reg_57;
    wire [4:0] signal_select_66;
    wire signal_eq_190;
    wire signal_eq_191;
    wire signal_and_172;
    wire signal_and_173;
    wire [4:0] signal_mux_116;
    wire [4:0] signal_mux_117;
    wire [4:0] signal_wire_58;
    reg [4:0] signal_reg_58;
    wire signal_select_67;
    wire signal_eq_192;
    wire signal_eq_193;
    wire signal_and_174;
    wire signal_and_175;
    wire signal_mux_118;
    wire signal_mux_119;
    wire signal_wire_59;
    reg signal_reg_59;
    wire [4:0] signal_select_68;
    wire signal_eq_194;
    wire signal_eq_195;
    wire signal_and_176;
    wire signal_and_177;
    wire [4:0] signal_mux_120;
    wire [4:0] signal_mux_121;
    wire [4:0] signal_wire_60;
    reg [4:0] signal_reg_60;
    wire [1:0] signal_select_69;
    wire signal_eq_196;
    wire signal_eq_197;
    wire signal_and_178;
    wire signal_and_179;
    wire [1:0] signal_mux_122;
    wire [1:0] signal_mux_123;
    wire [1:0] signal_wire_61;
    reg [1:0] signal_reg_61;
    wire [7:0] signal_select_70;
    wire [15:0] rx_head;
    wire [15:0] signal_wire_62;
    wire [7:0] signal_select_71;
    wire [7:0] signal_const_263;
    wire [15:0] signal_cat;
    wire [23:0] signal_wire_63;
    wire [15:0] signal_select_72;
    wire [7:0] signal_select_73;
    wire [15:0] signal_cat_1;
    wire [23:0] signal_wire_64;
    wire [15:0] signal_select_74;
    wire [8:0] signal_wire_65;
    wire [15:0] signal_cat_2;
    wire signal_wire_66;
    wire signal_wire_67;
    wire signal_wire_68;
    wire signal_wire_69;
    wire signal_wire_70;
    wire [3:0] signal_wire_71;
    wire [3:0] signal_wire_72;
    wire signal_wire_73;
    wire [15:0] signal_cat_3;
    reg [15:0] signal_cases;
    wire [15:0] signal_wire_74;
    wire [7:0] signal_select_75;
    wire [15:0] signal_cat_4;
    wire [23:0] signal_wire_75;
    wire [15:0] signal_select_76;
    wire [7:0] signal_select_77;
    wire [15:0] signal_cat_5;
    wire [23:0] signal_wire_76;
    wire [15:0] signal_select_78;
    wire [8:0] signal_wire_77;
    wire [15:0] signal_cat_6;
    wire signal_wire_78;
    wire signal_wire_79;
    wire signal_wire_80;
    wire signal_wire_81;
    wire signal_wire_82;
    wire signal_wire_83;
    wire [3:0] signal_wire_84;
    wire [3:0] signal_wire_85;
    wire signal_wire_86;
    wire signal_wire_87;
    wire [15:0] signal_cat_7;
    reg [15:0] signal_cases_1;
    wire [15:0] signal_mux_124;
    wire [14:0] signal_const_283;
    wire [15:0] signal_cat_8;
    wire [4:0] signal_const_286;
    wire [4:0] signal_add;
    wire [4:0] signal_select_79;
    wire [6:0] signal_const_287;
    wire signal_eq_198;
    wire [4:0] signal_mux_125;
    wire signal_eq_199;
    wire [4:0] signal_mux_126;
    wire [4:0] signal_mux_127;
    wire [4:0] signal_wire_88;
    reg [4:0] line_addr;
    wire [10:0] signal_const_289;
    wire [15:0] signal_cat_9;
    wire [4:0] signal_wire_89;
    wire [15:0] signal_cat_10;
    wire [9:0] signal_wire_90;
    wire [5:0] signal_const_293;
    wire [15:0] signal_cat_11;
    wire signal_wire_91;
    wire signal_wire_92;
    wire signal_wire_93;
    wire signal_wire_94;
    wire signal_mux_128;
    wire signal_wire_95;
    wire signal_wire_96;
    wire signal_select_80;
    wire [6:0] signal_const_296;
    wire signal_eq_200;
    wire signal_mux_129;
    wire signal_mux_130;
    wire signal_wire_97;
    reg select;
    wire signal_mux_131;
    wire [3:0] check_status;
    wire [11:0] signal_const_297;
    wire [15:0] signal_cat_12;
    wire [2:0] signal_select_81;
    wire [6:0] signal_const_300;
    wire signal_eq_201;
    wire [2:0] signal_mux_132;
    wire [2:0] signal_mux_133;
    wire [2:0] signal_wire_98;
    reg [2:0] check_flags;
    wire [12:0] signal_const_301;
    wire [15:0] signal_cat_13;
    wire [6:0] signal_const_304;
    wire signal_eq_202;
    wire [15:0] signal_mux_134;
    wire [15:0] signal_mux_135;
    wire [15:0] signal_wire_99;
    reg [15:0] check_loaded;
    wire [8:0] signal_select_82;
    wire [6:0] signal_const_307;
    wire signal_eq_203;
    wire [8:0] signal_mux_136;
    wire [8:0] signal_mux_137;
    wire [8:0] signal_wire_100;
    reg [8:0] check_base;
    wire [15:0] signal_cat_14;
    wire [8:0] signal_const_311;
    wire [8:0] signal_add_1;
    wire [8:0] signal_select_83;
    wire [6:0] signal_const_312;
    wire signal_eq_204;
    wire [8:0] signal_mux_138;
    wire signal_eq_205;
    wire [8:0] signal_mux_139;
    wire [8:0] signal_mux_140;
    wire [8:0] signal_wire_101;
    reg [8:0] data_addr;
    wire [15:0] signal_cat_15;
    wire [8:0] signal_add_2;
    reg [7:0] signal_cases_2;
    wire [7:0] signal_mux_141;
    wire [7:0] signal_wire_102;
    reg [7:0] high;
    wire [15:0] value;
    wire [8:0] signal_select_84;
    wire [6:0] signal_const_319;
    wire signal_eq_206;
    wire [8:0] signal_mux_142;
    wire signal_eq_207;
    wire [8:0] signal_mux_143;
    wire signal_mux_144;
    reg signal_cases_3;
    wire signal_mux_145;
    wire write;
    wire [8:0] signal_mux_146;
    wire [8:0] signal_wire_103;
    reg [8:0] program_addr;
    wire [15:0] signal_cat_16;
    wire [7:0] spi_rx_byte;
    wire [6:0] signal_select_85;
    wire signal_eq_208;
    wire [6:0] read_addr;
    reg [15:0] read_value;
    reg [15:0] signal_cases_4;
    wire [15:0] signal_mux_147;
    wire vdd;
    wire is_write;
    wire signal_mux_148;
    reg signal_cases_5;
    wire gnd;
    wire signal_mux_149;
    wire read_done;
    wire [15:0] signal_mux_150;
    wire [15:0] signal_wire_104;
    reg [15:0] word;
    wire [7:0] signal_select_86;
    reg [7:0] signal_cases_6;
    wire [7:0] signal_mux_151;
    wire [7:0] signal_wire_105;
    reg [7:0] cmd;
    wire [6:0] addr;
    wire signal_eq_209;
    wire [15:0] tx_word;
    wire [7:0] signal_select_87;
    wire [1:0] signal_const_326;
    reg [1:0] signal_cases_7;
    wire signal_select_88;
    wire [1:0] signal_mux_152;
    wire signal_select_89;
    wire [1:0] signal_mux_153;
    wire [1:0] signal_wire_106;
    (* fsm_encoding="one_hot" *)
    reg [1:0] sm;
    wire [1:0] signal_const_328;
    wire signal_eq_210;
    wire [7:0] signal_mux_154;
    wire signal_wire_107;
    wire signal_wire_108;
    wire signal_wire_109;
    wire signal_wire_110;
    wire signal_wire_111;
    wire [11:0] signal_inst;
    wire signal_select_90;
    assign signal_select = value[5:5];
    assign signal_const = 7'b0000000;
    assign signal_eq = addr == signal_const;
    assign signal_and = write & signal_eq;
    assign signal_and_1 = signal_and & signal_select;
    assign signal_select_1 = check_flags[1:1];
    assign signal_select_2 = check_flags[2:2];
    assign signal_select_3 = check_flags[0:0];
    assign signal_const_1 = 1'b1;
    assign signal_eq_1 = select == signal_const_1;
    assign signal_const_2 = 7'b1000111;
    assign signal_eq_2 = addr == signal_const_2;
    assign signal_and_2 = write & signal_eq_2;
    assign signal_and_3 = signal_and_2 & signal_eq_1;
    assign signal_eq_3 = select == signal_const_1;
    assign signal_and_4 = writes_config & signal_eq_3;
    assign signal_and_5 = signal_and_4 & signal_wire_66;
    assign signal_eq_4 = select == signal_const_1;
    assign signal_select_4 = value[4:4];
    assign signal_eq_5 = addr == signal_const;
    assign signal_and_6 = write & signal_eq_5;
    assign signal_and_7 = signal_and_6 & signal_select_4;
    assign signal_and_8 = signal_and_7 & signal_eq_4;
    assign signal_eq_6 = select == signal_const_1;
    assign signal_select_5 = value[3:3];
    assign signal_eq_7 = addr == signal_const;
    assign signal_and_9 = write & signal_eq_7;
    assign signal_and_10 = signal_and_9 & signal_select_5;
    assign signal_and_11 = signal_and_10 & signal_eq_6;
    assign signal_eq_8 = select == signal_const_1;
    assign signal_select_6 = value[2:2];
    assign signal_eq_9 = addr == signal_const;
    assign signal_and_12 = write & signal_eq_9;
    assign signal_and_13 = signal_and_12 & signal_select_6;
    assign signal_and_14 = signal_and_13 & signal_eq_8;
    assign signal_eq_10 = select == signal_const_1;
    assign signal_select_7 = value[1:1];
    assign signal_eq_11 = addr == signal_const;
    assign signal_and_15 = write & signal_eq_11;
    assign signal_and_16 = signal_and_15 & signal_select_7;
    assign signal_and_17 = signal_and_16 & signal_eq_10;
    assign signal_eq_12 = select == signal_const_1;
    assign signal_const_13 = 7'b0001000;
    assign signal_eq_13 = addr == signal_const_13;
    assign signal_and_18 = read_done & signal_eq_13;
    assign signal_and_19 = signal_and_18 & signal_eq_12;
    assign signal_eq_14 = select == signal_const_1;
    assign signal_const_15 = 7'b0000111;
    assign signal_eq_15 = addr == signal_const_15;
    assign signal_and_20 = write & signal_eq_15;
    assign signal_and_21 = signal_and_20 & signal_eq_14;
    assign signal_eq_16 = select == signal_const_1;
    assign signal_const_17 = 7'b0001101;
    assign signal_eq_17 = addr == signal_const_17;
    assign signal_and_22 = write & signal_eq_17;
    assign signal_and_23 = signal_and_22 & signal_eq_16;
    assign signal_eq_18 = select == signal_const_1;
    assign signal_const_19 = 7'b0001010;
    assign signal_eq_19 = addr == signal_const_19;
    assign signal_and_24 = write & signal_eq_19;
    assign signal_and_25 = signal_and_24 & signal_eq_18;
    assign signal_eq_20 = select == signal_const_1;
    assign signal_select_8 = value[0:0];
    assign signal_eq_21 = addr == signal_const;
    assign signal_and_26 = write & signal_eq_21;
    assign signal_and_27 = signal_and_26 & signal_select_8;
    assign signal_and_28 = signal_and_27 & signal_eq_20;
    assign signal_const_22 = 1'b0;
    assign signal_select_9 = value[0:0];
    assign signal_eq_22 = select == signal_const_1;
    assign signal_const_24 = 7'b0110000;
    assign signal_eq_23 = addr == signal_const_24;
    assign signal_and_29 = signal_eq_23 & signal_eq_22;
    assign signal_and_30 = signal_and_29 & signal_wire_66;
    assign signal_mux = signal_and_30 ? signal_select_9 : signal_reg;
    assign signal_mux_1 = write ? signal_mux : signal_reg;
    assign signal_wire = signal_mux_1;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg <= signal_const_22;
        else
            signal_reg <= signal_wire;
    end
    assign signal_select_10 = value[0:0];
    assign signal_eq_24 = select == signal_const_1;
    assign signal_const_27 = 7'b0101111;
    assign signal_eq_25 = addr == signal_const_27;
    assign signal_and_31 = signal_eq_25 & signal_eq_24;
    assign signal_and_32 = signal_and_31 & signal_wire_66;
    assign signal_mux_2 = signal_and_32 ? signal_select_10 : signal_reg_1;
    assign signal_mux_3 = write ? signal_mux_2 : signal_reg_1;
    assign signal_wire_1 = signal_mux_3;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_1 <= signal_const_22;
        else
            signal_reg_1 <= signal_wire_1;
    end
    assign signal_select_11 = value[0:0];
    assign signal_eq_26 = select == signal_const_1;
    assign signal_const_30 = 7'b0101110;
    assign signal_eq_27 = addr == signal_const_30;
    assign signal_and_33 = signal_eq_27 & signal_eq_26;
    assign signal_and_34 = signal_and_33 & signal_wire_66;
    assign signal_mux_4 = signal_and_34 ? signal_select_11 : signal_reg_2;
    assign signal_mux_5 = write ? signal_mux_4 : signal_reg_2;
    assign signal_wire_2 = signal_mux_5;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_2 <= signal_const_22;
        else
            signal_reg_2 <= signal_wire_2;
    end
    assign signal_select_12 = value[0:0];
    assign signal_eq_28 = select == signal_const_1;
    assign signal_const_33 = 7'b0101101;
    assign signal_eq_29 = addr == signal_const_33;
    assign signal_and_35 = signal_eq_29 & signal_eq_28;
    assign signal_and_36 = signal_and_35 & signal_wire_66;
    assign signal_mux_6 = signal_and_36 ? signal_select_12 : signal_reg_3;
    assign signal_mux_7 = write ? signal_mux_6 : signal_reg_3;
    assign signal_wire_3 = signal_mux_7;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_3 <= signal_const_22;
        else
            signal_reg_3 <= signal_wire_3;
    end
    assign signal_const_34 = 16'b0000000000000000;
    assign signal_eq_30 = select == signal_const_1;
    assign signal_const_36 = 7'b0101010;
    assign signal_eq_31 = addr == signal_const_36;
    assign signal_and_37 = signal_eq_31 & signal_eq_30;
    assign signal_and_38 = signal_and_37 & signal_wire_66;
    assign signal_mux_8 = signal_and_38 ? value : signal_reg_4;
    assign signal_mux_9 = write ? signal_mux_8 : signal_reg_4;
    assign signal_wire_4 = signal_mux_9;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_4 <= signal_const_34;
        else
            signal_reg_4 <= signal_wire_4;
    end
    assign signal_const_37 = 9'b000000000;
    assign signal_select_13 = value[8:0];
    assign signal_eq_32 = select == signal_const_1;
    assign signal_const_39 = 7'b0101001;
    assign signal_eq_33 = addr == signal_const_39;
    assign signal_and_39 = signal_eq_33 & signal_eq_32;
    assign signal_and_40 = signal_and_39 & signal_wire_66;
    assign signal_mux_10 = signal_and_40 ? signal_select_13 : signal_reg_5;
    assign signal_mux_11 = write ? signal_mux_10 : signal_reg_5;
    assign signal_wire_5 = signal_mux_11;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_5 <= signal_const_37;
        else
            signal_reg_5 <= signal_wire_5;
    end
    assign signal_select_14 = value[8:0];
    assign signal_eq_34 = select == signal_const_1;
    assign signal_const_42 = 7'b0101000;
    assign signal_eq_35 = addr == signal_const_42;
    assign signal_and_41 = signal_eq_35 & signal_eq_34;
    assign signal_and_42 = signal_and_41 & signal_wire_66;
    assign signal_mux_12 = signal_and_42 ? signal_select_14 : signal_reg_6;
    assign signal_mux_13 = write ? signal_mux_12 : signal_reg_6;
    assign signal_wire_6 = signal_mux_13;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_6 <= signal_const_37;
        else
            signal_reg_6 <= signal_wire_6;
    end
    assign signal_select_15 = value[0:0];
    assign signal_eq_36 = select == signal_const_1;
    assign signal_const_45 = 7'b0100111;
    assign signal_eq_37 = addr == signal_const_45;
    assign signal_and_43 = signal_eq_37 & signal_eq_36;
    assign signal_and_44 = signal_and_43 & signal_wire_66;
    assign signal_mux_14 = signal_and_44 ? signal_select_15 : signal_reg_7;
    assign signal_mux_15 = write ? signal_mux_14 : signal_reg_7;
    assign signal_wire_7 = signal_mux_15;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_7 <= signal_const_22;
        else
            signal_reg_7 <= signal_wire_7;
    end
    assign signal_const_46 = 5'b00000;
    assign signal_select_16 = value[4:0];
    assign signal_eq_38 = select == signal_const_1;
    assign signal_const_48 = 7'b0100110;
    assign signal_eq_39 = addr == signal_const_48;
    assign signal_and_45 = signal_eq_39 & signal_eq_38;
    assign signal_and_46 = signal_and_45 & signal_wire_66;
    assign signal_mux_16 = signal_and_46 ? signal_select_16 : signal_reg_8;
    assign signal_mux_17 = write ? signal_mux_16 : signal_reg_8;
    assign signal_wire_8 = signal_mux_17;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_8 <= signal_const_46;
        else
            signal_reg_8 <= signal_wire_8;
    end
    assign signal_select_17 = value[0:0];
    assign signal_eq_40 = select == signal_const_1;
    assign signal_const_51 = 7'b0100101;
    assign signal_eq_41 = addr == signal_const_51;
    assign signal_and_47 = signal_eq_41 & signal_eq_40;
    assign signal_and_48 = signal_and_47 & signal_wire_66;
    assign signal_mux_18 = signal_and_48 ? signal_select_17 : signal_reg_9;
    assign signal_mux_19 = write ? signal_mux_18 : signal_reg_9;
    assign signal_wire_9 = signal_mux_19;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_9 <= signal_const_22;
        else
            signal_reg_9 <= signal_wire_9;
    end
    assign signal_eq_42 = select == signal_const_1;
    assign signal_const_54 = 7'b0100100;
    assign signal_eq_43 = addr == signal_const_54;
    assign signal_and_49 = signal_eq_43 & signal_eq_42;
    assign signal_and_50 = signal_and_49 & signal_wire_66;
    assign signal_mux_20 = signal_and_50 ? value : signal_reg_10;
    assign signal_mux_21 = write ? signal_mux_20 : signal_reg_10;
    assign signal_wire_10 = signal_mux_21;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_10 <= signal_const_34;
        else
            signal_reg_10 <= signal_wire_10;
    end
    assign signal_eq_44 = select == signal_const_1;
    assign signal_const_57 = 7'b0100011;
    assign signal_eq_45 = addr == signal_const_57;
    assign signal_and_51 = signal_eq_45 & signal_eq_44;
    assign signal_and_52 = signal_and_51 & signal_wire_66;
    assign signal_mux_22 = signal_and_52 ? value : signal_reg_11;
    assign signal_mux_23 = write ? signal_mux_22 : signal_reg_11;
    assign signal_wire_11 = signal_mux_23;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_11 <= signal_const_34;
        else
            signal_reg_11 <= signal_wire_11;
    end
    assign signal_select_18 = value[4:0];
    assign signal_eq_46 = select == signal_const_1;
    assign signal_const_60 = 7'b0100010;
    assign signal_eq_47 = addr == signal_const_60;
    assign signal_and_53 = signal_eq_47 & signal_eq_46;
    assign signal_and_54 = signal_and_53 & signal_wire_66;
    assign signal_mux_24 = signal_and_54 ? signal_select_18 : signal_reg_12;
    assign signal_mux_25 = write ? signal_mux_24 : signal_reg_12;
    assign signal_wire_12 = signal_mux_25;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_12 <= signal_const_46;
        else
            signal_reg_12 <= signal_wire_12;
    end
    assign signal_select_19 = value[4:0];
    assign signal_eq_48 = select == signal_const_1;
    assign signal_const_63 = 7'b0100001;
    assign signal_eq_49 = addr == signal_const_63;
    assign signal_and_55 = signal_eq_49 & signal_eq_48;
    assign signal_and_56 = signal_and_55 & signal_wire_66;
    assign signal_mux_26 = signal_and_56 ? signal_select_19 : signal_reg_13;
    assign signal_mux_27 = write ? signal_mux_26 : signal_reg_13;
    assign signal_wire_13 = signal_mux_27;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_13 <= signal_const_46;
        else
            signal_reg_13 <= signal_wire_13;
    end
    assign signal_select_20 = value[0:0];
    assign signal_eq_50 = select == signal_const_1;
    assign signal_const_66 = 7'b0100000;
    assign signal_eq_51 = addr == signal_const_66;
    assign signal_and_57 = signal_eq_51 & signal_eq_50;
    assign signal_and_58 = signal_and_57 & signal_wire_66;
    assign signal_mux_28 = signal_and_58 ? signal_select_20 : signal_reg_14;
    assign signal_mux_29 = write ? signal_mux_28 : signal_reg_14;
    assign signal_wire_14 = signal_mux_29;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_14 <= signal_const_22;
        else
            signal_reg_14 <= signal_wire_14;
    end
    assign signal_select_21 = value[4:0];
    assign signal_eq_52 = select == signal_const_1;
    assign signal_const_69 = 7'b0011111;
    assign signal_eq_53 = addr == signal_const_69;
    assign signal_and_59 = signal_eq_53 & signal_eq_52;
    assign signal_and_60 = signal_and_59 & signal_wire_66;
    assign signal_mux_30 = signal_and_60 ? signal_select_21 : signal_reg_15;
    assign signal_mux_31 = write ? signal_mux_30 : signal_reg_15;
    assign signal_wire_15 = signal_mux_31;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_15 <= signal_const_46;
        else
            signal_reg_15 <= signal_wire_15;
    end
    assign signal_select_22 = value[0:0];
    assign signal_eq_54 = select == signal_const_1;
    assign signal_const_72 = 7'b0011110;
    assign signal_eq_55 = addr == signal_const_72;
    assign signal_and_61 = signal_eq_55 & signal_eq_54;
    assign signal_and_62 = signal_and_61 & signal_wire_66;
    assign signal_mux_32 = signal_and_62 ? signal_select_22 : signal_reg_16;
    assign signal_mux_33 = write ? signal_mux_32 : signal_reg_16;
    assign signal_wire_16 = signal_mux_33;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_16 <= signal_const_22;
        else
            signal_reg_16 <= signal_wire_16;
    end
    assign signal_select_23 = value[0:0];
    assign signal_eq_56 = select == signal_const_1;
    assign signal_const_75 = 7'b0011101;
    assign signal_eq_57 = addr == signal_const_75;
    assign signal_and_63 = signal_eq_57 & signal_eq_56;
    assign signal_and_64 = signal_and_63 & signal_wire_66;
    assign signal_mux_34 = signal_and_64 ? signal_select_23 : signal_reg_17;
    assign signal_mux_35 = write ? signal_mux_34 : signal_reg_17;
    assign signal_wire_17 = signal_mux_35;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_17 <= signal_const_22;
        else
            signal_reg_17 <= signal_wire_17;
    end
    assign signal_select_24 = value[0:0];
    assign signal_eq_58 = select == signal_const_1;
    assign signal_const_78 = 7'b0011100;
    assign signal_eq_59 = addr == signal_const_78;
    assign signal_and_65 = signal_eq_59 & signal_eq_58;
    assign signal_and_66 = signal_and_65 & signal_wire_66;
    assign signal_mux_36 = signal_and_66 ? signal_select_24 : signal_reg_18;
    assign signal_mux_37 = write ? signal_mux_36 : signal_reg_18;
    assign signal_wire_18 = signal_mux_37;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_18 <= signal_const_22;
        else
            signal_reg_18 <= signal_wire_18;
    end
    assign signal_select_25 = value[0:0];
    assign signal_eq_60 = select == signal_const_1;
    assign signal_const_81 = 7'b0011011;
    assign signal_eq_61 = addr == signal_const_81;
    assign signal_and_67 = signal_eq_61 & signal_eq_60;
    assign signal_and_68 = signal_and_67 & signal_wire_66;
    assign signal_mux_38 = signal_and_68 ? signal_select_25 : signal_reg_19;
    assign signal_mux_39 = write ? signal_mux_38 : signal_reg_19;
    assign signal_wire_19 = signal_mux_39;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_19 <= signal_const_22;
        else
            signal_reg_19 <= signal_wire_19;
    end
    assign signal_select_26 = value[4:0];
    assign signal_eq_62 = select == signal_const_1;
    assign signal_const_84 = 7'b0011010;
    assign signal_eq_63 = addr == signal_const_84;
    assign signal_and_69 = signal_eq_63 & signal_eq_62;
    assign signal_and_70 = signal_and_69 & signal_wire_66;
    assign signal_mux_40 = signal_and_70 ? signal_select_26 : signal_reg_20;
    assign signal_mux_41 = write ? signal_mux_40 : signal_reg_20;
    assign signal_wire_20 = signal_mux_41;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_20 <= signal_const_46;
        else
            signal_reg_20 <= signal_wire_20;
    end
    assign signal_select_27 = value[4:0];
    assign signal_eq_64 = select == signal_const_1;
    assign signal_const_87 = 7'b0011001;
    assign signal_eq_65 = addr == signal_const_87;
    assign signal_and_71 = signal_eq_65 & signal_eq_64;
    assign signal_and_72 = signal_and_71 & signal_wire_66;
    assign signal_mux_42 = signal_and_72 ? signal_select_27 : signal_reg_21;
    assign signal_mux_43 = write ? signal_mux_42 : signal_reg_21;
    assign signal_wire_21 = signal_mux_43;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_21 <= signal_const_46;
        else
            signal_reg_21 <= signal_wire_21;
    end
    assign signal_const_88 = 3'b000;
    assign signal_select_28 = value[2:0];
    assign signal_eq_66 = select == signal_const_1;
    assign signal_const_90 = 7'b0011000;
    assign signal_eq_67 = addr == signal_const_90;
    assign signal_and_73 = signal_eq_67 & signal_eq_66;
    assign signal_and_74 = signal_and_73 & signal_wire_66;
    assign signal_mux_44 = signal_and_74 ? signal_select_28 : signal_reg_22;
    assign signal_mux_45 = write ? signal_mux_44 : signal_reg_22;
    assign signal_wire_22 = signal_mux_45;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_22 <= signal_const_88;
        else
            signal_reg_22 <= signal_wire_22;
    end
    assign signal_select_29 = value[4:0];
    assign signal_eq_68 = select == signal_const_1;
    assign signal_const_93 = 7'b0010111;
    assign signal_eq_69 = addr == signal_const_93;
    assign signal_and_75 = signal_eq_69 & signal_eq_68;
    assign signal_and_76 = signal_and_75 & signal_wire_66;
    assign signal_mux_46 = signal_and_76 ? signal_select_29 : signal_reg_23;
    assign signal_mux_47 = write ? signal_mux_46 : signal_reg_23;
    assign signal_wire_23 = signal_mux_47;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_23 <= signal_const_46;
        else
            signal_reg_23 <= signal_wire_23;
    end
    assign signal_select_30 = value[4:0];
    assign signal_eq_70 = select == signal_const_1;
    assign signal_const_96 = 7'b0010110;
    assign signal_eq_71 = addr == signal_const_96;
    assign signal_and_77 = signal_eq_71 & signal_eq_70;
    assign signal_and_78 = signal_and_77 & signal_wire_66;
    assign signal_mux_48 = signal_and_78 ? signal_select_30 : signal_reg_24;
    assign signal_mux_49 = write ? signal_mux_48 : signal_reg_24;
    assign signal_wire_24 = signal_mux_49;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_24 <= signal_const_46;
        else
            signal_reg_24 <= signal_wire_24;
    end
    assign signal_select_31 = value[4:0];
    assign signal_eq_72 = select == signal_const_1;
    assign signal_const_99 = 7'b0010101;
    assign signal_eq_73 = addr == signal_const_99;
    assign signal_and_79 = signal_eq_73 & signal_eq_72;
    assign signal_and_80 = signal_and_79 & signal_wire_66;
    assign signal_mux_50 = signal_and_80 ? signal_select_31 : signal_reg_25;
    assign signal_mux_51 = write ? signal_mux_50 : signal_reg_25;
    assign signal_wire_25 = signal_mux_51;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_25 <= signal_const_46;
        else
            signal_reg_25 <= signal_wire_25;
    end
    assign signal_select_32 = value[4:0];
    assign signal_eq_74 = select == signal_const_1;
    assign signal_const_102 = 7'b0010100;
    assign signal_eq_75 = addr == signal_const_102;
    assign signal_and_81 = signal_eq_75 & signal_eq_74;
    assign signal_and_82 = signal_and_81 & signal_wire_66;
    assign signal_mux_52 = signal_and_82 ? signal_select_32 : signal_reg_26;
    assign signal_mux_53 = write ? signal_mux_52 : signal_reg_26;
    assign signal_wire_26 = signal_mux_53;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_26 <= signal_const_46;
        else
            signal_reg_26 <= signal_wire_26;
    end
    assign signal_select_33 = value[4:0];
    assign signal_eq_76 = select == signal_const_1;
    assign signal_const_105 = 7'b0010011;
    assign signal_eq_77 = addr == signal_const_105;
    assign signal_and_83 = signal_eq_77 & signal_eq_76;
    assign signal_and_84 = signal_and_83 & signal_wire_66;
    assign signal_mux_54 = signal_and_84 ? signal_select_33 : signal_reg_27;
    assign signal_mux_55 = write ? signal_mux_54 : signal_reg_27;
    assign signal_wire_27 = signal_mux_55;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_27 <= signal_const_46;
        else
            signal_reg_27 <= signal_wire_27;
    end
    assign signal_select_34 = value[0:0];
    assign signal_eq_78 = select == signal_const_1;
    assign signal_const_108 = 7'b0010010;
    assign signal_eq_79 = addr == signal_const_108;
    assign signal_and_85 = signal_eq_79 & signal_eq_78;
    assign signal_and_86 = signal_and_85 & signal_wire_66;
    assign signal_mux_56 = signal_and_86 ? signal_select_34 : signal_reg_28;
    assign signal_mux_57 = write ? signal_mux_56 : signal_reg_28;
    assign signal_wire_28 = signal_mux_57;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_28 <= signal_const_22;
        else
            signal_reg_28 <= signal_wire_28;
    end
    assign signal_select_35 = value[4:0];
    assign signal_eq_80 = select == signal_const_1;
    assign signal_const_111 = 7'b0010001;
    assign signal_eq_81 = addr == signal_const_111;
    assign signal_and_87 = signal_eq_81 & signal_eq_80;
    assign signal_and_88 = signal_and_87 & signal_wire_66;
    assign signal_mux_58 = signal_and_88 ? signal_select_35 : signal_reg_29;
    assign signal_mux_59 = write ? signal_mux_58 : signal_reg_29;
    assign signal_wire_29 = signal_mux_59;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_29 <= signal_const_46;
        else
            signal_reg_29 <= signal_wire_29;
    end
    assign signal_const_112 = 2'b00;
    assign signal_select_36 = value[1:0];
    assign signal_eq_82 = select == signal_const_1;
    assign signal_const_114 = 7'b0010000;
    assign signal_eq_83 = addr == signal_const_114;
    assign signal_and_89 = signal_eq_83 & signal_eq_82;
    assign signal_and_90 = signal_and_89 & signal_wire_66;
    assign signal_mux_60 = signal_and_90 ? signal_select_36 : signal_reg_30;
    assign signal_mux_61 = write ? signal_mux_60 : signal_reg_30;
    assign signal_wire_30 = signal_mux_61;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_30 <= signal_const_112;
        else
            signal_reg_30 <= signal_wire_30;
    end
    assign signal_eq_84 = select == signal_const_22;
    assign signal_eq_85 = addr == signal_const_2;
    assign signal_and_91 = write & signal_eq_85;
    assign signal_and_92 = signal_and_91 & signal_eq_84;
    assign signal_eq_86 = select == signal_const_22;
    assign signal_eq_87 = addr == signal_const_24;
    assign signal_eq_88 = addr == signal_const_27;
    assign signal_eq_89 = addr == signal_const_30;
    assign signal_eq_90 = addr == signal_const_33;
    assign signal_eq_91 = addr == signal_const_36;
    assign signal_eq_92 = addr == signal_const_39;
    assign signal_eq_93 = addr == signal_const_42;
    assign signal_eq_94 = addr == signal_const_45;
    assign signal_eq_95 = addr == signal_const_48;
    assign signal_eq_96 = addr == signal_const_51;
    assign signal_eq_97 = addr == signal_const_54;
    assign signal_eq_98 = addr == signal_const_57;
    assign signal_eq_99 = addr == signal_const_60;
    assign signal_eq_100 = addr == signal_const_63;
    assign signal_eq_101 = addr == signal_const_66;
    assign signal_eq_102 = addr == signal_const_69;
    assign signal_eq_103 = addr == signal_const_72;
    assign signal_eq_104 = addr == signal_const_75;
    assign signal_eq_105 = addr == signal_const_78;
    assign signal_eq_106 = addr == signal_const_81;
    assign signal_eq_107 = addr == signal_const_84;
    assign signal_eq_108 = addr == signal_const_87;
    assign signal_eq_109 = addr == signal_const_90;
    assign signal_eq_110 = addr == signal_const_93;
    assign signal_eq_111 = addr == signal_const_96;
    assign signal_eq_112 = addr == signal_const_99;
    assign signal_eq_113 = addr == signal_const_102;
    assign signal_eq_114 = addr == signal_const_105;
    assign signal_eq_115 = addr == signal_const_108;
    assign signal_eq_116 = addr == signal_const_111;
    assign signal_eq_117 = addr == signal_const_114;
    assign signal_or = signal_eq_117 | signal_eq_116;
    assign signal_or_1 = signal_or | signal_eq_115;
    assign signal_or_2 = signal_or_1 | signal_eq_114;
    assign signal_or_3 = signal_or_2 | signal_eq_113;
    assign signal_or_4 = signal_or_3 | signal_eq_112;
    assign signal_or_5 = signal_or_4 | signal_eq_111;
    assign signal_or_6 = signal_or_5 | signal_eq_110;
    assign signal_or_7 = signal_or_6 | signal_eq_109;
    assign signal_or_8 = signal_or_7 | signal_eq_108;
    assign signal_or_9 = signal_or_8 | signal_eq_107;
    assign signal_or_10 = signal_or_9 | signal_eq_106;
    assign signal_or_11 = signal_or_10 | signal_eq_105;
    assign signal_or_12 = signal_or_11 | signal_eq_104;
    assign signal_or_13 = signal_or_12 | signal_eq_103;
    assign signal_or_14 = signal_or_13 | signal_eq_102;
    assign signal_or_15 = signal_or_14 | signal_eq_101;
    assign signal_or_16 = signal_or_15 | signal_eq_100;
    assign signal_or_17 = signal_or_16 | signal_eq_99;
    assign signal_or_18 = signal_or_17 | signal_eq_98;
    assign signal_or_19 = signal_or_18 | signal_eq_97;
    assign signal_or_20 = signal_or_19 | signal_eq_96;
    assign signal_or_21 = signal_or_20 | signal_eq_95;
    assign signal_or_22 = signal_or_21 | signal_eq_94;
    assign signal_or_23 = signal_or_22 | signal_eq_93;
    assign signal_or_24 = signal_or_23 | signal_eq_92;
    assign signal_or_25 = signal_or_24 | signal_eq_91;
    assign signal_or_26 = signal_or_25 | signal_eq_90;
    assign signal_or_27 = signal_or_26 | signal_eq_89;
    assign signal_or_28 = signal_or_27 | signal_eq_88;
    assign signal_or_29 = signal_or_28 | signal_eq_87;
    assign writes_config = write & signal_or_29;
    assign signal_and_93 = writes_config & signal_eq_86;
    assign signal_and_94 = signal_and_93 & signal_wire_78;
    assign signal_eq_118 = select == signal_const_22;
    assign signal_select_37 = value[4:4];
    assign signal_eq_119 = addr == signal_const;
    assign signal_and_95 = write & signal_eq_119;
    assign signal_and_96 = signal_and_95 & signal_select_37;
    assign signal_and_97 = signal_and_96 & signal_eq_118;
    assign signal_eq_120 = select == signal_const_22;
    assign signal_select_38 = value[3:3];
    assign signal_eq_121 = addr == signal_const;
    assign signal_and_98 = write & signal_eq_121;
    assign signal_and_99 = signal_and_98 & signal_select_38;
    assign signal_and_100 = signal_and_99 & signal_eq_120;
    assign signal_eq_122 = select == signal_const_22;
    assign signal_select_39 = value[2:2];
    assign signal_eq_123 = addr == signal_const;
    assign signal_and_101 = write & signal_eq_123;
    assign signal_and_102 = signal_and_101 & signal_select_39;
    assign signal_and_103 = signal_and_102 & signal_eq_122;
    assign signal_eq_124 = select == signal_const_22;
    assign signal_select_40 = value[1:1];
    assign signal_eq_125 = addr == signal_const;
    assign signal_and_104 = write & signal_eq_125;
    assign signal_and_105 = signal_and_104 & signal_select_40;
    assign signal_and_106 = signal_and_105 & signal_eq_124;
    assign signal_eq_126 = select == signal_const_22;
    assign signal_eq_127 = addr == signal_const_13;
    assign signal_and_107 = read_done & signal_eq_127;
    assign signal_and_108 = signal_and_107 & signal_eq_126;
    assign signal_eq_128 = select == signal_const_22;
    assign signal_eq_129 = addr == signal_const_15;
    assign signal_and_109 = write & signal_eq_129;
    assign signal_and_110 = signal_and_109 & signal_eq_128;
    assign signal_eq_130 = select == signal_const_22;
    assign signal_eq_131 = addr == signal_const_17;
    assign signal_and_111 = write & signal_eq_131;
    assign signal_and_112 = signal_and_111 & signal_eq_130;
    assign signal_eq_132 = select == signal_const_22;
    assign signal_eq_133 = addr == signal_const_19;
    assign signal_and_113 = write & signal_eq_133;
    assign signal_and_114 = signal_and_113 & signal_eq_132;
    assign signal_eq_134 = select == signal_const_22;
    assign signal_select_41 = value[0:0];
    assign signal_eq_135 = addr == signal_const;
    assign signal_and_115 = write & signal_eq_135;
    assign signal_and_116 = signal_and_115 & signal_select_41;
    assign signal_and_117 = signal_and_116 & signal_eq_134;
    assign signal_select_42 = value[0:0];
    assign signal_eq_136 = select == signal_const_22;
    assign signal_eq_137 = addr == signal_const_24;
    assign signal_and_118 = signal_eq_137 & signal_eq_136;
    assign signal_and_119 = signal_and_118 & signal_wire_78;
    assign signal_mux_62 = signal_and_119 ? signal_select_42 : signal_reg_31;
    assign signal_mux_63 = write ? signal_mux_62 : signal_reg_31;
    assign signal_wire_31 = signal_mux_63;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_31 <= signal_const_22;
        else
            signal_reg_31 <= signal_wire_31;
    end
    assign signal_select_43 = value[0:0];
    assign signal_eq_138 = select == signal_const_22;
    assign signal_eq_139 = addr == signal_const_27;
    assign signal_and_120 = signal_eq_139 & signal_eq_138;
    assign signal_and_121 = signal_and_120 & signal_wire_78;
    assign signal_mux_64 = signal_and_121 ? signal_select_43 : signal_reg_32;
    assign signal_mux_65 = write ? signal_mux_64 : signal_reg_32;
    assign signal_wire_32 = signal_mux_65;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_32 <= signal_const_22;
        else
            signal_reg_32 <= signal_wire_32;
    end
    assign signal_select_44 = value[0:0];
    assign signal_eq_140 = select == signal_const_22;
    assign signal_eq_141 = addr == signal_const_30;
    assign signal_and_122 = signal_eq_141 & signal_eq_140;
    assign signal_and_123 = signal_and_122 & signal_wire_78;
    assign signal_mux_66 = signal_and_123 ? signal_select_44 : signal_reg_33;
    assign signal_mux_67 = write ? signal_mux_66 : signal_reg_33;
    assign signal_wire_33 = signal_mux_67;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_33 <= signal_const_22;
        else
            signal_reg_33 <= signal_wire_33;
    end
    assign signal_select_45 = value[0:0];
    assign signal_eq_142 = select == signal_const_22;
    assign signal_eq_143 = addr == signal_const_33;
    assign signal_and_124 = signal_eq_143 & signal_eq_142;
    assign signal_and_125 = signal_and_124 & signal_wire_78;
    assign signal_mux_68 = signal_and_125 ? signal_select_45 : signal_reg_34;
    assign signal_mux_69 = write ? signal_mux_68 : signal_reg_34;
    assign signal_wire_34 = signal_mux_69;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_34 <= signal_const_22;
        else
            signal_reg_34 <= signal_wire_34;
    end
    assign signal_eq_144 = select == signal_const_22;
    assign signal_eq_145 = addr == signal_const_36;
    assign signal_and_126 = signal_eq_145 & signal_eq_144;
    assign signal_and_127 = signal_and_126 & signal_wire_78;
    assign signal_mux_70 = signal_and_127 ? value : signal_reg_35;
    assign signal_mux_71 = write ? signal_mux_70 : signal_reg_35;
    assign signal_wire_35 = signal_mux_71;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_35 <= signal_const_34;
        else
            signal_reg_35 <= signal_wire_35;
    end
    assign signal_select_46 = value[8:0];
    assign signal_eq_146 = select == signal_const_22;
    assign signal_eq_147 = addr == signal_const_39;
    assign signal_and_128 = signal_eq_147 & signal_eq_146;
    assign signal_and_129 = signal_and_128 & signal_wire_78;
    assign signal_mux_72 = signal_and_129 ? signal_select_46 : signal_reg_36;
    assign signal_mux_73 = write ? signal_mux_72 : signal_reg_36;
    assign signal_wire_36 = signal_mux_73;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_36 <= signal_const_37;
        else
            signal_reg_36 <= signal_wire_36;
    end
    assign signal_select_47 = value[8:0];
    assign signal_eq_148 = select == signal_const_22;
    assign signal_eq_149 = addr == signal_const_42;
    assign signal_and_130 = signal_eq_149 & signal_eq_148;
    assign signal_and_131 = signal_and_130 & signal_wire_78;
    assign signal_mux_74 = signal_and_131 ? signal_select_47 : signal_reg_37;
    assign signal_mux_75 = write ? signal_mux_74 : signal_reg_37;
    assign signal_wire_37 = signal_mux_75;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_37 <= signal_const_37;
        else
            signal_reg_37 <= signal_wire_37;
    end
    assign signal_select_48 = value[0:0];
    assign signal_eq_150 = select == signal_const_22;
    assign signal_eq_151 = addr == signal_const_45;
    assign signal_and_132 = signal_eq_151 & signal_eq_150;
    assign signal_and_133 = signal_and_132 & signal_wire_78;
    assign signal_mux_76 = signal_and_133 ? signal_select_48 : signal_reg_38;
    assign signal_mux_77 = write ? signal_mux_76 : signal_reg_38;
    assign signal_wire_38 = signal_mux_77;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_38 <= signal_const_22;
        else
            signal_reg_38 <= signal_wire_38;
    end
    assign signal_select_49 = value[4:0];
    assign signal_eq_152 = select == signal_const_22;
    assign signal_eq_153 = addr == signal_const_48;
    assign signal_and_134 = signal_eq_153 & signal_eq_152;
    assign signal_and_135 = signal_and_134 & signal_wire_78;
    assign signal_mux_78 = signal_and_135 ? signal_select_49 : signal_reg_39;
    assign signal_mux_79 = write ? signal_mux_78 : signal_reg_39;
    assign signal_wire_39 = signal_mux_79;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_39 <= signal_const_46;
        else
            signal_reg_39 <= signal_wire_39;
    end
    assign signal_select_50 = value[0:0];
    assign signal_eq_154 = select == signal_const_22;
    assign signal_eq_155 = addr == signal_const_51;
    assign signal_and_136 = signal_eq_155 & signal_eq_154;
    assign signal_and_137 = signal_and_136 & signal_wire_78;
    assign signal_mux_80 = signal_and_137 ? signal_select_50 : signal_reg_40;
    assign signal_mux_81 = write ? signal_mux_80 : signal_reg_40;
    assign signal_wire_40 = signal_mux_81;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_40 <= signal_const_22;
        else
            signal_reg_40 <= signal_wire_40;
    end
    assign signal_eq_156 = select == signal_const_22;
    assign signal_eq_157 = addr == signal_const_54;
    assign signal_and_138 = signal_eq_157 & signal_eq_156;
    assign signal_and_139 = signal_and_138 & signal_wire_78;
    assign signal_mux_82 = signal_and_139 ? value : signal_reg_41;
    assign signal_mux_83 = write ? signal_mux_82 : signal_reg_41;
    assign signal_wire_41 = signal_mux_83;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_41 <= signal_const_34;
        else
            signal_reg_41 <= signal_wire_41;
    end
    assign signal_eq_158 = select == signal_const_22;
    assign signal_eq_159 = addr == signal_const_57;
    assign signal_and_140 = signal_eq_159 & signal_eq_158;
    assign signal_and_141 = signal_and_140 & signal_wire_78;
    assign signal_mux_84 = signal_and_141 ? value : signal_reg_42;
    assign signal_mux_85 = write ? signal_mux_84 : signal_reg_42;
    assign signal_wire_42 = signal_mux_85;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_42 <= signal_const_34;
        else
            signal_reg_42 <= signal_wire_42;
    end
    assign signal_select_51 = value[4:0];
    assign signal_eq_160 = select == signal_const_22;
    assign signal_eq_161 = addr == signal_const_60;
    assign signal_and_142 = signal_eq_161 & signal_eq_160;
    assign signal_and_143 = signal_and_142 & signal_wire_78;
    assign signal_mux_86 = signal_and_143 ? signal_select_51 : signal_reg_43;
    assign signal_mux_87 = write ? signal_mux_86 : signal_reg_43;
    assign signal_wire_43 = signal_mux_87;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_43 <= signal_const_46;
        else
            signal_reg_43 <= signal_wire_43;
    end
    assign signal_select_52 = value[4:0];
    assign signal_eq_162 = select == signal_const_22;
    assign signal_eq_163 = addr == signal_const_63;
    assign signal_and_144 = signal_eq_163 & signal_eq_162;
    assign signal_and_145 = signal_and_144 & signal_wire_78;
    assign signal_mux_88 = signal_and_145 ? signal_select_52 : signal_reg_44;
    assign signal_mux_89 = write ? signal_mux_88 : signal_reg_44;
    assign signal_wire_44 = signal_mux_89;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_44 <= signal_const_46;
        else
            signal_reg_44 <= signal_wire_44;
    end
    assign signal_select_53 = value[0:0];
    assign signal_eq_164 = select == signal_const_22;
    assign signal_eq_165 = addr == signal_const_66;
    assign signal_and_146 = signal_eq_165 & signal_eq_164;
    assign signal_and_147 = signal_and_146 & signal_wire_78;
    assign signal_mux_90 = signal_and_147 ? signal_select_53 : signal_reg_45;
    assign signal_mux_91 = write ? signal_mux_90 : signal_reg_45;
    assign signal_wire_45 = signal_mux_91;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_45 <= signal_const_22;
        else
            signal_reg_45 <= signal_wire_45;
    end
    assign signal_select_54 = value[4:0];
    assign signal_eq_166 = select == signal_const_22;
    assign signal_eq_167 = addr == signal_const_69;
    assign signal_and_148 = signal_eq_167 & signal_eq_166;
    assign signal_and_149 = signal_and_148 & signal_wire_78;
    assign signal_mux_92 = signal_and_149 ? signal_select_54 : signal_reg_46;
    assign signal_mux_93 = write ? signal_mux_92 : signal_reg_46;
    assign signal_wire_46 = signal_mux_93;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_46 <= signal_const_46;
        else
            signal_reg_46 <= signal_wire_46;
    end
    assign signal_select_55 = value[0:0];
    assign signal_eq_168 = select == signal_const_22;
    assign signal_eq_169 = addr == signal_const_72;
    assign signal_and_150 = signal_eq_169 & signal_eq_168;
    assign signal_and_151 = signal_and_150 & signal_wire_78;
    assign signal_mux_94 = signal_and_151 ? signal_select_55 : signal_reg_47;
    assign signal_mux_95 = write ? signal_mux_94 : signal_reg_47;
    assign signal_wire_47 = signal_mux_95;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_47 <= signal_const_22;
        else
            signal_reg_47 <= signal_wire_47;
    end
    assign signal_select_56 = value[0:0];
    assign signal_eq_170 = select == signal_const_22;
    assign signal_eq_171 = addr == signal_const_75;
    assign signal_and_152 = signal_eq_171 & signal_eq_170;
    assign signal_and_153 = signal_and_152 & signal_wire_78;
    assign signal_mux_96 = signal_and_153 ? signal_select_56 : signal_reg_48;
    assign signal_mux_97 = write ? signal_mux_96 : signal_reg_48;
    assign signal_wire_48 = signal_mux_97;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_48 <= signal_const_22;
        else
            signal_reg_48 <= signal_wire_48;
    end
    assign signal_select_57 = value[0:0];
    assign signal_eq_172 = select == signal_const_22;
    assign signal_eq_173 = addr == signal_const_78;
    assign signal_and_154 = signal_eq_173 & signal_eq_172;
    assign signal_and_155 = signal_and_154 & signal_wire_78;
    assign signal_mux_98 = signal_and_155 ? signal_select_57 : signal_reg_49;
    assign signal_mux_99 = write ? signal_mux_98 : signal_reg_49;
    assign signal_wire_49 = signal_mux_99;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_49 <= signal_const_22;
        else
            signal_reg_49 <= signal_wire_49;
    end
    assign signal_select_58 = value[0:0];
    assign signal_eq_174 = select == signal_const_22;
    assign signal_eq_175 = addr == signal_const_81;
    assign signal_and_156 = signal_eq_175 & signal_eq_174;
    assign signal_and_157 = signal_and_156 & signal_wire_78;
    assign signal_mux_100 = signal_and_157 ? signal_select_58 : signal_reg_50;
    assign signal_mux_101 = write ? signal_mux_100 : signal_reg_50;
    assign signal_wire_50 = signal_mux_101;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_50 <= signal_const_22;
        else
            signal_reg_50 <= signal_wire_50;
    end
    assign signal_select_59 = value[4:0];
    assign signal_eq_176 = select == signal_const_22;
    assign signal_eq_177 = addr == signal_const_84;
    assign signal_and_158 = signal_eq_177 & signal_eq_176;
    assign signal_and_159 = signal_and_158 & signal_wire_78;
    assign signal_mux_102 = signal_and_159 ? signal_select_59 : signal_reg_51;
    assign signal_mux_103 = write ? signal_mux_102 : signal_reg_51;
    assign signal_wire_51 = signal_mux_103;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_51 <= signal_const_46;
        else
            signal_reg_51 <= signal_wire_51;
    end
    assign signal_select_60 = value[4:0];
    assign signal_eq_178 = select == signal_const_22;
    assign signal_eq_179 = addr == signal_const_87;
    assign signal_and_160 = signal_eq_179 & signal_eq_178;
    assign signal_and_161 = signal_and_160 & signal_wire_78;
    assign signal_mux_104 = signal_and_161 ? signal_select_60 : signal_reg_52;
    assign signal_mux_105 = write ? signal_mux_104 : signal_reg_52;
    assign signal_wire_52 = signal_mux_105;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_52 <= signal_const_46;
        else
            signal_reg_52 <= signal_wire_52;
    end
    assign signal_select_61 = value[2:0];
    assign signal_eq_180 = select == signal_const_22;
    assign signal_eq_181 = addr == signal_const_90;
    assign signal_and_162 = signal_eq_181 & signal_eq_180;
    assign signal_and_163 = signal_and_162 & signal_wire_78;
    assign signal_mux_106 = signal_and_163 ? signal_select_61 : signal_reg_53;
    assign signal_mux_107 = write ? signal_mux_106 : signal_reg_53;
    assign signal_wire_53 = signal_mux_107;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_53 <= signal_const_88;
        else
            signal_reg_53 <= signal_wire_53;
    end
    assign signal_select_62 = value[4:0];
    assign signal_eq_182 = select == signal_const_22;
    assign signal_eq_183 = addr == signal_const_93;
    assign signal_and_164 = signal_eq_183 & signal_eq_182;
    assign signal_and_165 = signal_and_164 & signal_wire_78;
    assign signal_mux_108 = signal_and_165 ? signal_select_62 : signal_reg_54;
    assign signal_mux_109 = write ? signal_mux_108 : signal_reg_54;
    assign signal_wire_54 = signal_mux_109;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_54 <= signal_const_46;
        else
            signal_reg_54 <= signal_wire_54;
    end
    assign signal_select_63 = value[4:0];
    assign signal_eq_184 = select == signal_const_22;
    assign signal_eq_185 = addr == signal_const_96;
    assign signal_and_166 = signal_eq_185 & signal_eq_184;
    assign signal_and_167 = signal_and_166 & signal_wire_78;
    assign signal_mux_110 = signal_and_167 ? signal_select_63 : signal_reg_55;
    assign signal_mux_111 = write ? signal_mux_110 : signal_reg_55;
    assign signal_wire_55 = signal_mux_111;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_55 <= signal_const_46;
        else
            signal_reg_55 <= signal_wire_55;
    end
    assign signal_select_64 = value[4:0];
    assign signal_eq_186 = select == signal_const_22;
    assign signal_eq_187 = addr == signal_const_99;
    assign signal_and_168 = signal_eq_187 & signal_eq_186;
    assign signal_and_169 = signal_and_168 & signal_wire_78;
    assign signal_mux_112 = signal_and_169 ? signal_select_64 : signal_reg_56;
    assign signal_mux_113 = write ? signal_mux_112 : signal_reg_56;
    assign signal_wire_56 = signal_mux_113;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_56 <= signal_const_46;
        else
            signal_reg_56 <= signal_wire_56;
    end
    assign signal_select_65 = value[4:0];
    assign signal_eq_188 = select == signal_const_22;
    assign signal_eq_189 = addr == signal_const_102;
    assign signal_and_170 = signal_eq_189 & signal_eq_188;
    assign signal_and_171 = signal_and_170 & signal_wire_78;
    assign signal_mux_114 = signal_and_171 ? signal_select_65 : signal_reg_57;
    assign signal_mux_115 = write ? signal_mux_114 : signal_reg_57;
    assign signal_wire_57 = signal_mux_115;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_57 <= signal_const_46;
        else
            signal_reg_57 <= signal_wire_57;
    end
    assign signal_select_66 = value[4:0];
    assign signal_eq_190 = select == signal_const_22;
    assign signal_eq_191 = addr == signal_const_105;
    assign signal_and_172 = signal_eq_191 & signal_eq_190;
    assign signal_and_173 = signal_and_172 & signal_wire_78;
    assign signal_mux_116 = signal_and_173 ? signal_select_66 : signal_reg_58;
    assign signal_mux_117 = write ? signal_mux_116 : signal_reg_58;
    assign signal_wire_58 = signal_mux_117;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_58 <= signal_const_46;
        else
            signal_reg_58 <= signal_wire_58;
    end
    assign signal_select_67 = value[0:0];
    assign signal_eq_192 = select == signal_const_22;
    assign signal_eq_193 = addr == signal_const_108;
    assign signal_and_174 = signal_eq_193 & signal_eq_192;
    assign signal_and_175 = signal_and_174 & signal_wire_78;
    assign signal_mux_118 = signal_and_175 ? signal_select_67 : signal_reg_59;
    assign signal_mux_119 = write ? signal_mux_118 : signal_reg_59;
    assign signal_wire_59 = signal_mux_119;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_59 <= signal_const_22;
        else
            signal_reg_59 <= signal_wire_59;
    end
    assign signal_select_68 = value[4:0];
    assign signal_eq_194 = select == signal_const_22;
    assign signal_eq_195 = addr == signal_const_111;
    assign signal_and_176 = signal_eq_195 & signal_eq_194;
    assign signal_and_177 = signal_and_176 & signal_wire_78;
    assign signal_mux_120 = signal_and_177 ? signal_select_68 : signal_reg_60;
    assign signal_mux_121 = write ? signal_mux_120 : signal_reg_60;
    assign signal_wire_60 = signal_mux_121;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_60 <= signal_const_46;
        else
            signal_reg_60 <= signal_wire_60;
    end
    assign signal_select_69 = value[1:0];
    assign signal_eq_196 = select == signal_const_22;
    assign signal_eq_197 = addr == signal_const_114;
    assign signal_and_178 = signal_eq_197 & signal_eq_196;
    assign signal_and_179 = signal_and_178 & signal_wire_78;
    assign signal_mux_122 = signal_and_179 ? signal_select_69 : signal_reg_61;
    assign signal_mux_123 = write ? signal_mux_122 : signal_reg_61;
    assign signal_wire_61 = signal_mux_123;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            signal_reg_61 <= signal_const_112;
        else
            signal_reg_61 <= signal_wire_61;
    end
    assign signal_select_70 = tx_word[7:0];
    assign rx_head = select ? signal_wire_62 : signal_wire_74;
    assign signal_wire_62 = status$rx_head_1;
    assign signal_select_71 = signal_wire_63[23:16];
    assign signal_const_263 = 8'b00000000;
    assign signal_cat = { signal_const_263,
                          signal_select_71 };
    assign signal_wire_63 = status$capture_1;
    assign signal_select_72 = signal_wire_63[15:0];
    assign signal_select_73 = signal_wire_64[23:16];
    assign signal_cat_1 = { signal_const_263,
                            signal_select_73 };
    assign signal_wire_64 = status$now_1;
    assign signal_select_74 = signal_wire_64[15:0];
    assign signal_wire_65 = status$pc_1;
    assign signal_cat_2 = { signal_const,
                            signal_wire_65 };
    assign signal_wire_66 = status$halted_1;
    assign signal_wire_67 = status$fault$underflow_1;
    assign signal_wire_68 = status$fault$overflow_1;
    assign signal_wire_69 = status$fault$missed_deadline_1;
    assign signal_wire_70 = status$fault$decode_1;
    assign signal_wire_71 = status$tx_level_1;
    assign signal_wire_72 = status$rx_level_1;
    assign signal_wire_73 = status$fault$assumption_1;
    assign signal_cat_3 = { signal_wire_79,
                            signal_wire_73,
                            signal_wire_72,
                            signal_wire_71,
                            signal_wire_70,
                            signal_wire_69,
                            signal_wire_68,
                            signal_wire_67,
                            signal_wire_87,
                            signal_wire_66 };
    always @* begin
        case (read_addr)
        7'b0000001:
            signal_cases <= signal_cat_3;
        7'b0000010:
            signal_cases <= signal_cat_2;
        7'b0000011:
            signal_cases <= signal_select_74;
        7'b0000100:
            signal_cases <= signal_cat_1;
        7'b0000101:
            signal_cases <= signal_select_72;
        7'b0000110:
            signal_cases <= signal_cat;
        7'b0001000:
            signal_cases <= signal_wire_62;
        default:
            signal_cases <= signal_const_34;
        endcase
    end
    assign signal_wire_74 = status$rx_head_0;
    assign signal_select_75 = signal_wire_75[23:16];
    assign signal_cat_4 = { signal_const_263,
                            signal_select_75 };
    assign signal_wire_75 = status$capture_0;
    assign signal_select_76 = signal_wire_75[15:0];
    assign signal_select_77 = signal_wire_76[23:16];
    assign signal_cat_5 = { signal_const_263,
                            signal_select_77 };
    assign signal_wire_76 = status$now_0;
    assign signal_select_78 = signal_wire_76[15:0];
    assign signal_wire_77 = status$pc_0;
    assign signal_cat_6 = { signal_const,
                            signal_wire_77 };
    assign signal_wire_78 = status$halted_0;
    assign signal_wire_79 = status$irq_0;
    assign signal_wire_80 = status$fault$underflow_0;
    assign signal_wire_81 = status$fault$overflow_0;
    assign signal_wire_82 = status$fault$missed_deadline_0;
    assign signal_wire_83 = status$fault$decode_0;
    assign signal_wire_84 = status$tx_level_0;
    assign signal_wire_85 = status$rx_level_0;
    assign signal_wire_86 = status$fault$assumption_0;
    assign signal_wire_87 = status$irq_1;
    assign signal_cat_7 = { signal_wire_87,
                            signal_wire_86,
                            signal_wire_85,
                            signal_wire_84,
                            signal_wire_83,
                            signal_wire_82,
                            signal_wire_81,
                            signal_wire_80,
                            signal_wire_79,
                            signal_wire_78 };
    always @* begin
        case (read_addr)
        7'b0000001:
            signal_cases_1 <= signal_cat_7;
        7'b0000010:
            signal_cases_1 <= signal_cat_6;
        7'b0000011:
            signal_cases_1 <= signal_select_78;
        7'b0000100:
            signal_cases_1 <= signal_cat_5;
        7'b0000101:
            signal_cases_1 <= signal_select_76;
        7'b0000110:
            signal_cases_1 <= signal_cat_4;
        7'b0001000:
            signal_cases_1 <= signal_wire_74;
        default:
            signal_cases_1 <= signal_const_34;
        endcase
    end
    assign signal_mux_124 = select ? signal_cases : signal_cases_1;
    assign signal_const_283 = 15'b000000000000000;
    assign signal_cat_8 = { signal_const_283,
                            select };
    assign signal_const_286 = 5'b00001;
    assign signal_add = line_addr + signal_const_286;
    assign signal_select_79 = value[4:0];
    assign signal_const_287 = 7'b1000110;
    assign signal_eq_198 = addr == signal_const_287;
    assign signal_mux_125 = signal_eq_198 ? signal_select_79 : line_addr;
    assign signal_eq_199 = addr == signal_const_2;
    assign signal_mux_126 = signal_eq_199 ? signal_add : signal_mux_125;
    assign signal_mux_127 = write ? signal_mux_126 : line_addr;
    assign signal_wire_88 = signal_mux_127;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            line_addr <= signal_const_46;
        else
            line_addr <= signal_wire_88;
    end
    assign signal_const_289 = 11'b00000000000;
    assign signal_cat_9 = { signal_const_289,
                            line_addr };
    assign signal_wire_89 = check$reason;
    assign signal_cat_10 = { signal_const_289,
                             signal_wire_89 };
    assign signal_wire_90 = check$reject_pc;
    assign signal_const_293 = 6'b000000;
    assign signal_cat_11 = { signal_const_293,
                             signal_wire_90 };
    assign signal_wire_91 = check$busy;
    assign signal_wire_92 = check$accepted;
    assign signal_wire_93 = status$certified_1;
    assign signal_wire_94 = status$certified_0;
    assign signal_mux_128 = select ? signal_wire_93 : signal_wire_94;
    assign signal_wire_95 = status$refused_1;
    assign signal_wire_96 = status$refused_0;
    assign signal_select_80 = value[0:0];
    assign signal_const_296 = 7'b0001011;
    assign signal_eq_200 = addr == signal_const_296;
    assign signal_mux_129 = signal_eq_200 ? signal_select_80 : select;
    assign signal_mux_130 = write ? signal_mux_129 : select;
    assign signal_wire_97 = signal_mux_130;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            select <= signal_const_22;
        else
            select <= signal_wire_97;
    end
    assign signal_mux_131 = select ? signal_wire_95 : signal_wire_96;
    assign check_status = { signal_mux_131,
                            signal_mux_128,
                            signal_wire_92,
                            signal_wire_91 };
    assign signal_const_297 = 12'b000000000000;
    assign signal_cat_12 = { signal_const_297,
                             check_status };
    assign signal_select_81 = value[2:0];
    assign signal_const_300 = 7'b1000010;
    assign signal_eq_201 = addr == signal_const_300;
    assign signal_mux_132 = signal_eq_201 ? signal_select_81 : check_flags;
    assign signal_mux_133 = write ? signal_mux_132 : check_flags;
    assign signal_wire_98 = signal_mux_133;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            check_flags <= signal_const_88;
        else
            check_flags <= signal_wire_98;
    end
    assign signal_const_301 = 13'b0000000000000;
    assign signal_cat_13 = { signal_const_301,
                             check_flags };
    assign signal_const_304 = 7'b1000001;
    assign signal_eq_202 = addr == signal_const_304;
    assign signal_mux_134 = signal_eq_202 ? value : check_loaded;
    assign signal_mux_135 = write ? signal_mux_134 : check_loaded;
    assign signal_wire_99 = signal_mux_135;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            check_loaded <= signal_const_34;
        else
            check_loaded <= signal_wire_99;
    end
    assign signal_select_82 = value[8:0];
    assign signal_const_307 = 7'b1000000;
    assign signal_eq_203 = addr == signal_const_307;
    assign signal_mux_136 = signal_eq_203 ? signal_select_82 : check_base;
    assign signal_mux_137 = write ? signal_mux_136 : check_base;
    assign signal_wire_100 = signal_mux_137;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            check_base <= signal_const_37;
        else
            check_base <= signal_wire_100;
    end
    assign signal_cat_14 = { signal_const,
                             check_base };
    assign signal_const_311 = 9'b000000001;
    assign signal_add_1 = data_addr + signal_const_311;
    assign signal_select_83 = value[8:0];
    assign signal_const_312 = 7'b0001100;
    assign signal_eq_204 = addr == signal_const_312;
    assign signal_mux_138 = signal_eq_204 ? signal_select_83 : data_addr;
    assign signal_eq_205 = addr == signal_const_17;
    assign signal_mux_139 = signal_eq_205 ? signal_add_1 : signal_mux_138;
    assign signal_mux_140 = write ? signal_mux_139 : data_addr;
    assign signal_wire_101 = signal_mux_140;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            data_addr <= signal_const_37;
        else
            data_addr <= signal_wire_101;
    end
    assign signal_cat_15 = { signal_const,
                             data_addr };
    assign signal_add_2 = program_addr + signal_const_311;
    always @* begin
        case (sm)
        2'b01:
            signal_cases_2 <= signal_select_86;
        default:
            signal_cases_2 <= high;
        endcase
    end
    assign signal_mux_141 = signal_select_89 ? signal_cases_2 : high;
    assign signal_wire_102 = signal_mux_141;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            high <= signal_const_263;
        else
            high <= signal_wire_102;
    end
    assign value = { high,
                     signal_select_86 };
    assign signal_select_84 = value[8:0];
    assign signal_const_319 = 7'b0001001;
    assign signal_eq_206 = addr == signal_const_319;
    assign signal_mux_142 = signal_eq_206 ? signal_select_84 : program_addr;
    assign signal_eq_207 = addr == signal_const_19;
    assign signal_mux_143 = signal_eq_207 ? signal_add_2 : signal_mux_142;
    assign signal_mux_144 = is_write ? vdd : gnd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_3 <= signal_mux_144;
        default:
            signal_cases_3 <= gnd;
        endcase
    end
    assign signal_mux_145 = signal_select_89 ? signal_cases_3 : gnd;
    assign write = signal_mux_145;
    assign signal_mux_146 = write ? signal_mux_143 : program_addr;
    assign signal_wire_103 = signal_mux_146;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            program_addr <= signal_const_37;
        else
            program_addr <= signal_wire_103;
    end
    assign signal_cat_16 = { signal_const,
                             program_addr };
    assign spi_rx_byte = signal_select_86;
    assign signal_select_85 = spi_rx_byte[6:0];
    assign signal_eq_208 = signal_const_112 == sm;
    assign read_addr = signal_eq_208 ? signal_select_85 : addr;
    always @* begin
        case (read_addr)
        7'b0001001:
            read_value <= signal_cat_16;
        7'b0001100:
            read_value <= signal_cat_15;
        7'b1000000:
            read_value <= signal_cat_14;
        7'b1000001:
            read_value <= check_loaded;
        7'b1000010:
            read_value <= signal_cat_13;
        7'b1000011:
            read_value <= signal_cat_12;
        7'b1000100:
            read_value <= signal_cat_11;
        7'b1000101:
            read_value <= signal_cat_10;
        7'b1000110:
            read_value <= signal_cat_9;
        7'b0001011:
            read_value <= signal_cat_8;
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
    assign signal_mux_147 = signal_select_89 ? signal_cases_4 : word;
    assign vdd = 1'b1;
    assign is_write = cmd[7:7];
    assign signal_mux_148 = is_write ? gnd : vdd;
    always @* begin
        case (sm)
        2'b10:
            signal_cases_5 <= signal_mux_148;
        default:
            signal_cases_5 <= gnd;
        endcase
    end
    assign gnd = 1'b0;
    assign signal_mux_149 = signal_select_89 ? signal_cases_5 : gnd;
    assign read_done = signal_mux_149;
    assign signal_mux_150 = read_done ? read_value : signal_mux_147;
    assign signal_wire_104 = signal_mux_150;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            word <= signal_const_34;
        else
            word <= signal_wire_104;
    end
    assign signal_select_86 = signal_inst[8:1];
    always @* begin
        case (sm)
        2'b00:
            signal_cases_6 <= signal_select_86;
        default:
            signal_cases_6 <= cmd;
        endcase
    end
    assign signal_mux_151 = signal_select_89 ? signal_cases_6 : cmd;
    assign signal_wire_105 = signal_mux_151;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            cmd <= signal_const_263;
        else
            cmd <= signal_wire_105;
    end
    assign addr = cmd[6:0];
    assign signal_eq_209 = addr == signal_const_13;
    assign tx_word = signal_eq_209 ? rx_head : word;
    assign signal_select_87 = tx_word[15:8];
    assign signal_const_326 = 2'b01;
    always @* begin
        case (sm)
        2'b00:
            signal_cases_7 <= signal_const_326;
        2'b01:
            signal_cases_7 <= signal_const_328;
        2'b10:
            signal_cases_7 <= signal_const_326;
        default:
            signal_cases_7 <= signal_mux_152;
        endcase
    end
    assign signal_select_88 = signal_inst[10:10];
    assign signal_mux_152 = signal_select_88 ? signal_const_112 : sm;
    assign signal_select_89 = signal_inst[9:9];
    assign signal_mux_153 = signal_select_89 ? signal_cases_7 : signal_mux_152;
    assign signal_wire_106 = signal_mux_153;
    always @(posedge signal_wire_111) begin
        if (signal_wire_110)
            sm <= signal_const_112;
        else
            sm <= signal_wire_106;
    end
    assign signal_const_328 = 2'b10;
    assign signal_eq_210 = signal_const_328 == sm;
    assign signal_mux_154 = signal_eq_210 ? signal_select_70 : signal_select_87;
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
          .tx_byte(signal_mux_154),
          .miso(signal_inst[0:0]),
          .rx_byte(signal_inst[8:1]),
          .rx_valid(signal_inst[9:9]),
          .frame_start(signal_inst[10:10]),
          .frame_end(signal_inst[11:11]) );
    assign signal_select_90 = signal_inst[0:0];
    assign miso = signal_select_90;
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
    assign engines$config$autopull_data_0 = signal_reg_34;
    assign engines$config$manchester_0 = signal_reg_33;
    assign engines$config$line_code_0 = signal_reg_32;
    assign engines$config$route_0 = signal_reg_31;
    assign engines$start_0 = signal_and_117;
    assign engines$program_write$valid_0 = signal_and_114;
    assign engines$program_write$addr_0 = program_addr;
    assign engines$program_write$data_0 = value;
    assign engines$data_write$valid_0 = signal_and_112;
    assign engines$data_write$addr_0 = data_addr;
    assign engines$data_write$data_0 = value;
    assign engines$tx$valid_0 = signal_and_110;
    assign engines$tx$value_0 = value;
    assign engines$rx_pop_0 = signal_and_108;
    assign engines$clear_irq_0 = signal_and_106;
    assign engines$stop_0 = signal_and_103;
    assign engines$flush_0 = signal_and_100;
    assign engines$check_0 = signal_and_97;
    assign engines$config_written_0 = signal_and_94;
    assign engines$line_write$valid_0 = signal_and_92;
    assign engines$line_write$addr_0 = line_addr;
    assign engines$line_write$data_0 = value;
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
    assign engines$config$autopull_data_1 = signal_reg_3;
    assign engines$config$manchester_1 = signal_reg_2;
    assign engines$config$line_code_1 = signal_reg_1;
    assign engines$config$route_1 = signal_reg;
    assign engines$start_1 = signal_and_28;
    assign engines$program_write$valid_1 = signal_and_25;
    assign engines$program_write$addr_1 = program_addr;
    assign engines$program_write$data_1 = value;
    assign engines$data_write$valid_1 = signal_and_23;
    assign engines$data_write$addr_1 = data_addr;
    assign engines$data_write$data_1 = value;
    assign engines$tx$valid_1 = signal_and_21;
    assign engines$tx$value_1 = value;
    assign engines$rx_pop_1 = signal_and_19;
    assign engines$clear_irq_1 = signal_and_17;
    assign engines$stop_1 = signal_and_14;
    assign engines$flush_1 = signal_and_11;
    assign engines$check_1 = signal_and_8;
    assign engines$config_written_1 = signal_and_5;
    assign engines$line_write$valid_1 = signal_and_3;
    assign engines$line_write$addr_1 = line_addr;
    assign engines$line_write$data_1 = value;
    assign check_setup$base = check_base;
    assign check_setup$loaded$valid = signal_select_3;
    assign check_setup$loaded$value = check_loaded;
    assign check_setup$floor = signal_select_2;
    assign check_setup$single_edge = signal_select_1;
    assign start_all = signal_and_1;

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
    wire signal_select_5;
    wire signal_select_6;
    wire [15:0] signal_select_7;
    wire signal_select_8;
    wire [8:0] signal_select_9;
    wire [4:0] signal_const;
    wire [4:0] signal_select_10;
    reg [4:0] signal_reg;
    reg [4:0] signal_reg_1;
    wire [6:0] signal_const_2;
    wire [7:0] signal_const_3;
    wire [7:0] signal_wire;
    reg [7:0] signal_reg_2;
    reg [7:0] signal_reg_3;
    wire [19:0] inputs;
    wire [15:0] signal_select_11;
    wire [4:0] signal_select_12;
    wire signal_select_13;
    wire signal_select_14;
    wire signal_select_15;
    wire signal_select_16;
    wire signal_select_17;
    wire signal_select_18;
    wire signal_select_19;
    wire [15:0] signal_select_20;
    wire signal_select_21;
    wire [15:0] signal_select_22;
    wire [8:0] signal_select_23;
    wire signal_select_24;
    wire [15:0] signal_select_25;
    wire [8:0] signal_select_26;
    wire signal_select_27;
    wire signal_select_28;
    wire signal_select_29;
    wire signal_select_30;
    wire signal_select_31;
    wire signal_select_32;
    wire [15:0] signal_select_33;
    wire [8:0] signal_select_34;
    wire [8:0] signal_select_35;
    wire signal_select_36;
    wire [4:0] signal_select_37;
    wire signal_select_38;
    wire [15:0] signal_select_39;
    wire [15:0] signal_select_40;
    wire [4:0] signal_select_41;
    wire [4:0] signal_select_42;
    wire signal_select_43;
    wire [4:0] signal_select_44;
    wire signal_select_45;
    wire signal_select_46;
    wire signal_select_47;
    wire signal_select_48;
    wire [4:0] signal_select_49;
    wire [4:0] signal_select_50;
    wire [2:0] signal_select_51;
    wire [4:0] signal_select_52;
    wire [4:0] signal_select_53;
    wire [4:0] signal_select_54;
    wire [4:0] signal_select_55;
    wire [4:0] signal_select_56;
    wire signal_select_57;
    wire [4:0] signal_select_58;
    wire [1:0] signal_select_59;
    wire [15:0] signal_select_60;
    wire [4:0] signal_select_61;
    wire signal_select_62;
    wire signal_select_63;
    wire signal_select_64;
    wire signal_select_65;
    wire signal_select_66;
    wire signal_select_67;
    wire signal_select_68;
    wire [15:0] signal_select_69;
    wire signal_select_70;
    wire [15:0] signal_select_71;
    wire [8:0] signal_select_72;
    wire signal_select_73;
    wire [15:0] signal_select_74;
    wire [8:0] signal_select_75;
    wire signal_select_76;
    wire signal_select_77;
    wire signal_select_78;
    wire signal_select_79;
    wire signal_select_80;
    wire signal_select_81;
    wire [15:0] signal_select_82;
    wire [8:0] signal_select_83;
    wire [8:0] signal_select_84;
    wire signal_select_85;
    wire [4:0] signal_select_86;
    wire signal_select_87;
    wire [15:0] signal_select_88;
    wire [15:0] signal_select_89;
    wire [4:0] signal_select_90;
    wire [4:0] signal_select_91;
    wire signal_select_92;
    wire [4:0] signal_select_93;
    wire signal_select_94;
    wire signal_select_95;
    wire signal_select_96;
    wire signal_select_97;
    wire [4:0] signal_select_98;
    wire [4:0] signal_select_99;
    wire [2:0] signal_select_100;
    wire [4:0] signal_select_101;
    wire [4:0] signal_select_102;
    wire [4:0] signal_select_103;
    wire [4:0] signal_select_104;
    wire [4:0] signal_select_105;
    wire signal_select_106;
    wire [4:0] signal_select_107;
    wire [4:0] signal_select_108;
    wire [4:0] signal_wire_1;
    wire [9:0] signal_select_109;
    wire [9:0] signal_wire_2;
    wire signal_select_110;
    wire signal_wire_3;
    wire signal_select_111;
    wire signal_wire_4;
    wire signal_select_112;
    wire signal_wire_5;
    wire signal_select_113;
    wire signal_wire_6;
    wire [15:0] signal_select_114;
    wire [15:0] signal_wire_7;
    wire [3:0] signal_select_115;
    wire [3:0] signal_wire_8;
    wire [3:0] signal_select_116;
    wire [3:0] signal_wire_9;
    wire signal_select_117;
    wire signal_wire_10;
    wire signal_select_118;
    wire signal_wire_11;
    wire signal_select_119;
    wire signal_wire_12;
    wire signal_select_120;
    wire signal_wire_13;
    wire signal_select_121;
    wire signal_wire_14;
    wire signal_select_122;
    wire signal_wire_15;
    wire signal_select_123;
    wire signal_wire_16;
    wire [23:0] signal_select_124;
    wire [23:0] signal_wire_17;
    wire [23:0] signal_select_125;
    wire [23:0] signal_wire_18;
    wire [8:0] signal_select_126;
    wire [8:0] signal_wire_19;
    wire signal_select_127;
    wire signal_wire_20;
    wire signal_select_128;
    wire signal_wire_21;
    wire [15:0] signal_select_129;
    wire [15:0] signal_wire_22;
    wire [3:0] signal_select_130;
    wire [3:0] signal_wire_23;
    wire [3:0] signal_select_131;
    wire [3:0] signal_wire_24;
    wire signal_select_132;
    wire signal_wire_25;
    wire signal_select_133;
    wire signal_wire_26;
    wire signal_select_134;
    wire signal_wire_27;
    wire signal_select_135;
    wire signal_wire_28;
    wire signal_select_136;
    wire signal_wire_29;
    wire signal_select_137;
    wire signal_wire_30;
    wire signal_select_138;
    wire signal_wire_31;
    wire [23:0] signal_select_139;
    wire [23:0] signal_wire_32;
    wire [23:0] signal_select_140;
    wire [23:0] signal_wire_33;
    wire [8:0] signal_select_141;
    wire [8:0] signal_wire_34;
    wire signal_select_142;
    wire signal_select_143;
    wire [7:0] signal_wire_35;
    wire signal_select_144;
    wire [511:0] signal_inst;
    wire [1:0] signal_select_145;
    wire signal_const_5;
    wire signal_wire_36;
    wire signal_not;
    wire vdd;
    reg signal_reg_4;
    reg reset_done;
    wire signal_not_1;
    wire signal_wire_37;
    wire [896:0] signal_inst_1;
    wire [19:0] signal_select_146;
    wire [6:0] signal_select_147;
    wire [7:0] signal_cat;
    assign signal_select = signal_inst_1[875:856];
    assign signal_select_1 = signal_select[19:12];
    assign signal_select_2 = signal_select_146[19:12];
    assign signal_select_3 = signal_inst[0:0];
    assign signal_select_4 = signal_inst[511:511];
    assign signal_select_5 = signal_inst[510:510];
    assign signal_select_6 = signal_inst[509:509];
    assign signal_select_7 = signal_inst[508:493];
    assign signal_select_8 = signal_inst[492:492];
    assign signal_select_9 = signal_inst[491:483];
    assign signal_const = 5'b00000;
    assign signal_select_10 = signal_wire_35[7:3];
    always @(posedge signal_wire_37) begin
        if (signal_not_1)
            signal_reg <= signal_const;
        else
            signal_reg <= signal_select_10;
    end
    always @(posedge signal_wire_37) begin
        if (signal_not_1)
            signal_reg_1 <= signal_const;
        else
            signal_reg_1 <= signal_reg;
    end
    assign signal_const_2 = 7'b0000000;
    assign signal_const_3 = 8'b00000000;
    assign signal_wire = uio_in;
    always @(posedge signal_wire_37) begin
        if (signal_not_1)
            signal_reg_2 <= signal_const_3;
        else
            signal_reg_2 <= signal_wire;
    end
    always @(posedge signal_wire_37) begin
        if (signal_not_1)
            signal_reg_3 <= signal_const_3;
        else
            signal_reg_3 <= signal_reg_2;
    end
    assign inputs = { signal_reg_3,
                      signal_const_2,
                      signal_reg_1 };
    assign signal_select_11 = signal_inst[482:467];
    assign signal_select_12 = signal_inst[466:462];
    assign signal_select_13 = signal_inst[461:461];
    assign signal_select_14 = signal_inst[460:460];
    assign signal_select_15 = signal_inst[459:459];
    assign signal_select_16 = signal_inst[458:458];
    assign signal_select_17 = signal_inst[457:457];
    assign signal_select_18 = signal_inst[456:456];
    assign signal_select_19 = signal_inst[455:455];
    assign signal_select_20 = signal_inst[454:439];
    assign signal_select_21 = signal_inst[438:438];
    assign signal_select_22 = signal_inst[437:422];
    assign signal_select_23 = signal_inst[421:413];
    assign signal_select_24 = signal_inst[412:412];
    assign signal_select_25 = signal_inst[411:396];
    assign signal_select_26 = signal_inst[395:387];
    assign signal_select_27 = signal_inst[386:386];
    assign signal_select_28 = signal_inst[385:385];
    assign signal_select_29 = signal_inst[384:384];
    assign signal_select_30 = signal_inst[383:383];
    assign signal_select_31 = signal_inst[382:382];
    assign signal_select_32 = signal_inst[381:381];
    assign signal_select_33 = signal_inst[380:365];
    assign signal_select_34 = signal_inst[364:356];
    assign signal_select_35 = signal_inst[355:347];
    assign signal_select_36 = signal_inst[346:346];
    assign signal_select_37 = signal_inst[345:341];
    assign signal_select_38 = signal_inst[340:340];
    assign signal_select_39 = signal_inst[339:324];
    assign signal_select_40 = signal_inst[323:308];
    assign signal_select_41 = signal_inst[307:303];
    assign signal_select_42 = signal_inst[302:298];
    assign signal_select_43 = signal_inst[297:297];
    assign signal_select_44 = signal_inst[296:292];
    assign signal_select_45 = signal_inst[291:291];
    assign signal_select_46 = signal_inst[290:290];
    assign signal_select_47 = signal_inst[289:289];
    assign signal_select_48 = signal_inst[288:288];
    assign signal_select_49 = signal_inst[287:283];
    assign signal_select_50 = signal_inst[282:278];
    assign signal_select_51 = signal_inst[277:275];
    assign signal_select_52 = signal_inst[274:270];
    assign signal_select_53 = signal_inst[269:265];
    assign signal_select_54 = signal_inst[264:260];
    assign signal_select_55 = signal_inst[259:255];
    assign signal_select_56 = signal_inst[254:250];
    assign signal_select_57 = signal_inst[249:249];
    assign signal_select_58 = signal_inst[248:244];
    assign signal_select_59 = signal_inst[243:242];
    assign signal_select_60 = signal_inst[241:226];
    assign signal_select_61 = signal_inst[225:221];
    assign signal_select_62 = signal_inst[220:220];
    assign signal_select_63 = signal_inst[219:219];
    assign signal_select_64 = signal_inst[218:218];
    assign signal_select_65 = signal_inst[217:217];
    assign signal_select_66 = signal_inst[216:216];
    assign signal_select_67 = signal_inst[215:215];
    assign signal_select_68 = signal_inst[214:214];
    assign signal_select_69 = signal_inst[213:198];
    assign signal_select_70 = signal_inst[197:197];
    assign signal_select_71 = signal_inst[196:181];
    assign signal_select_72 = signal_inst[180:172];
    assign signal_select_73 = signal_inst[171:171];
    assign signal_select_74 = signal_inst[170:155];
    assign signal_select_75 = signal_inst[154:146];
    assign signal_select_76 = signal_inst[145:145];
    assign signal_select_77 = signal_inst[144:144];
    assign signal_select_78 = signal_inst[143:143];
    assign signal_select_79 = signal_inst[142:142];
    assign signal_select_80 = signal_inst[141:141];
    assign signal_select_81 = signal_inst[140:140];
    assign signal_select_82 = signal_inst[139:124];
    assign signal_select_83 = signal_inst[123:115];
    assign signal_select_84 = signal_inst[114:106];
    assign signal_select_85 = signal_inst[105:105];
    assign signal_select_86 = signal_inst[104:100];
    assign signal_select_87 = signal_inst[99:99];
    assign signal_select_88 = signal_inst[98:83];
    assign signal_select_89 = signal_inst[82:67];
    assign signal_select_90 = signal_inst[66:62];
    assign signal_select_91 = signal_inst[61:57];
    assign signal_select_92 = signal_inst[56:56];
    assign signal_select_93 = signal_inst[55:51];
    assign signal_select_94 = signal_inst[50:50];
    assign signal_select_95 = signal_inst[49:49];
    assign signal_select_96 = signal_inst[48:48];
    assign signal_select_97 = signal_inst[47:47];
    assign signal_select_98 = signal_inst[46:42];
    assign signal_select_99 = signal_inst[41:37];
    assign signal_select_100 = signal_inst[36:34];
    assign signal_select_101 = signal_inst[33:29];
    assign signal_select_102 = signal_inst[28:24];
    assign signal_select_103 = signal_inst[23:19];
    assign signal_select_104 = signal_inst[18:14];
    assign signal_select_105 = signal_inst[13:9];
    assign signal_select_106 = signal_inst[8:8];
    assign signal_select_107 = signal_inst[7:3];
    assign signal_select_108 = signal_inst_1[892:888];
    assign signal_wire_1 = signal_select_108;
    assign signal_select_109 = signal_inst_1[887:878];
    assign signal_wire_2 = signal_select_109;
    assign signal_select_110 = signal_inst_1[877:877];
    assign signal_wire_3 = signal_select_110;
    assign signal_select_111 = signal_inst_1[876:876];
    assign signal_wire_4 = signal_select_111;
    assign signal_select_112 = signal_inst_1[896:896];
    assign signal_wire_5 = signal_select_112;
    assign signal_select_113 = signal_inst_1[894:894];
    assign signal_wire_6 = signal_select_113;
    assign signal_select_114 = signal_inst_1[716:701];
    assign signal_wire_7 = signal_select_114;
    assign signal_select_115 = signal_inst_1[700:697];
    assign signal_wire_8 = signal_select_115;
    assign signal_select_116 = signal_inst_1[696:693];
    assign signal_wire_9 = signal_select_116;
    assign signal_select_117 = signal_inst_1[667:667];
    assign signal_wire_10 = signal_select_117;
    assign signal_select_118 = signal_inst_1[666:666];
    assign signal_wire_11 = signal_select_118;
    assign signal_select_119 = signal_inst_1[665:665];
    assign signal_wire_12 = signal_select_119;
    assign signal_select_120 = signal_inst_1[664:664];
    assign signal_wire_13 = signal_select_120;
    assign signal_select_121 = signal_inst_1[663:663];
    assign signal_wire_14 = signal_select_121;
    assign signal_select_122 = signal_inst_1[662:662];
    assign signal_wire_15 = signal_select_122;
    assign signal_select_123 = signal_inst_1[660:660];
    assign signal_wire_16 = signal_select_123;
    assign signal_select_124 = signal_inst_1[691:668];
    assign signal_wire_17 = signal_select_124;
    assign signal_select_125 = signal_inst_1[654:631];
    assign signal_wire_18 = signal_select_125;
    assign signal_select_126 = signal_inst_1[482:474];
    assign signal_wire_19 = signal_select_126;
    assign signal_select_127 = signal_inst_1[895:895];
    assign signal_wire_20 = signal_select_127;
    assign signal_select_128 = signal_inst_1[893:893];
    assign signal_wire_21 = signal_select_128;
    assign signal_select_129 = signal_inst_1[298:283];
    assign signal_wire_22 = signal_select_129;
    assign signal_select_130 = signal_inst_1[282:279];
    assign signal_wire_23 = signal_select_130;
    assign signal_select_131 = signal_inst_1[278:275];
    assign signal_wire_24 = signal_select_131;
    assign signal_select_132 = signal_inst_1[249:249];
    assign signal_wire_25 = signal_select_132;
    assign signal_select_133 = signal_inst_1[248:248];
    assign signal_wire_26 = signal_select_133;
    assign signal_select_134 = signal_inst_1[247:247];
    assign signal_wire_27 = signal_select_134;
    assign signal_select_135 = signal_inst_1[246:246];
    assign signal_wire_28 = signal_select_135;
    assign signal_select_136 = signal_inst_1[245:245];
    assign signal_wire_29 = signal_select_136;
    assign signal_select_137 = signal_inst_1[244:244];
    assign signal_wire_30 = signal_select_137;
    assign signal_select_138 = signal_inst_1[242:242];
    assign signal_wire_31 = signal_select_138;
    assign signal_select_139 = signal_inst_1[273:250];
    assign signal_wire_32 = signal_select_139;
    assign signal_select_140 = signal_inst_1[236:213];
    assign signal_wire_33 = signal_select_140;
    assign signal_select_141 = signal_inst_1[64:56];
    assign signal_wire_34 = signal_select_141;
    assign signal_select_142 = signal_wire_35[2:2];
    assign signal_select_143 = signal_wire_35[1:1];
    assign signal_wire_35 = ui_in;
    assign signal_select_144 = signal_wire_35[0:0];
    host_port
        host_port
        ( .clock(signal_wire_37),
          .clear(signal_not_1),
          .sck(signal_select_144),
          .mosi(signal_select_143),
          .cs_n(signal_select_142),
          .status$pc_0(signal_wire_34),
          .status$now_0(signal_wire_33),
          .status$capture_0(signal_wire_32),
          .status$halted_0(signal_wire_31),
          .status$irq_0(signal_wire_30),
          .status$fault$underflow_0(signal_wire_29),
          .status$fault$overflow_0(signal_wire_28),
          .status$fault$missed_deadline_0(signal_wire_27),
          .status$fault$decode_0(signal_wire_26),
          .status$fault$assumption_0(signal_wire_25),
          .status$tx_level_0(signal_wire_24),
          .status$rx_level_0(signal_wire_23),
          .status$rx_head_0(signal_wire_22),
          .status$certified_0(signal_wire_21),
          .status$refused_0(signal_wire_20),
          .status$pc_1(signal_wire_19),
          .status$now_1(signal_wire_18),
          .status$capture_1(signal_wire_17),
          .status$halted_1(signal_wire_16),
          .status$irq_1(signal_wire_15),
          .status$fault$underflow_1(signal_wire_14),
          .status$fault$overflow_1(signal_wire_13),
          .status$fault$missed_deadline_1(signal_wire_12),
          .status$fault$decode_1(signal_wire_11),
          .status$fault$assumption_1(signal_wire_10),
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
          .engines$config$line_code_0(signal_inst[142:142]),
          .engines$config$route_0(signal_inst[143:143]),
          .engines$start_0(signal_inst[144:144]),
          .engines$program_write$valid_0(signal_inst[145:145]),
          .engines$program_write$addr_0(signal_inst[154:146]),
          .engines$program_write$data_0(signal_inst[170:155]),
          .engines$data_write$valid_0(signal_inst[171:171]),
          .engines$data_write$addr_0(signal_inst[180:172]),
          .engines$data_write$data_0(signal_inst[196:181]),
          .engines$tx$valid_0(signal_inst[197:197]),
          .engines$tx$value_0(signal_inst[213:198]),
          .engines$rx_pop_0(signal_inst[214:214]),
          .engines$clear_irq_0(signal_inst[215:215]),
          .engines$stop_0(signal_inst[216:216]),
          .engines$flush_0(signal_inst[217:217]),
          .engines$check_0(signal_inst[218:218]),
          .engines$config_written_0(signal_inst[219:219]),
          .engines$line_write$valid_0(signal_inst[220:220]),
          .engines$line_write$addr_0(signal_inst[225:221]),
          .engines$line_write$data_0(signal_inst[241:226]),
          .engines$config$side_set_count_1(signal_inst[243:242]),
          .engines$config$side_set_base_1(signal_inst[248:244]),
          .engines$config$side_set_pindirs_1(signal_inst[249:249]),
          .engines$config$in_base_1(signal_inst[254:250]),
          .engines$config$in_count_1(signal_inst[259:255]),
          .engines$config$out_base_1(signal_inst[264:260]),
          .engines$config$out_count_1(signal_inst[269:265]),
          .engines$config$set_base_1(signal_inst[274:270]),
          .engines$config$set_count_1(signal_inst[277:275]),
          .engines$config$jmp_pin_1(signal_inst[282:278]),
          .engines$config$capture_pin_1(signal_inst[287:283]),
          .engines$config$capture_rising_1(signal_inst[288:288]),
          .engines$config$in_shift_right_1(signal_inst[289:289]),
          .engines$config$out_shift_right_1(signal_inst[290:290]),
          .engines$config$autopush_1(signal_inst[291:291]),
          .engines$config$push_threshold_1(signal_inst[296:292]),
          .engines$config$autopull_1(signal_inst[297:297]),
          .engines$config$pull_threshold_1(signal_inst[302:298]),
          .engines$config$crc_width_1(signal_inst[307:303]),
          .engines$config$crc_poly_1(signal_inst[323:308]),
          .engines$config$crc_init_1(signal_inst[339:324]),
          .engines$config$crc_reflect_1(signal_inst[340:340]),
          .engines$config$stuff_threshold_1(signal_inst[345:341]),
          .engines$config$stuff_level_1(signal_inst[346:346]),
          .engines$config$wrap_bottom_1(signal_inst[355:347]),
          .engines$config$wrap_top_1(signal_inst[364:356]),
          .engines$config$period_fraction_1(signal_inst[380:365]),
          .engines$config$autopull_data_1(signal_inst[381:381]),
          .engines$config$manchester_1(signal_inst[382:382]),
          .engines$config$line_code_1(signal_inst[383:383]),
          .engines$config$route_1(signal_inst[384:384]),
          .engines$start_1(signal_inst[385:385]),
          .engines$program_write$valid_1(signal_inst[386:386]),
          .engines$program_write$addr_1(signal_inst[395:387]),
          .engines$program_write$data_1(signal_inst[411:396]),
          .engines$data_write$valid_1(signal_inst[412:412]),
          .engines$data_write$addr_1(signal_inst[421:413]),
          .engines$data_write$data_1(signal_inst[437:422]),
          .engines$tx$valid_1(signal_inst[438:438]),
          .engines$tx$value_1(signal_inst[454:439]),
          .engines$rx_pop_1(signal_inst[455:455]),
          .engines$clear_irq_1(signal_inst[456:456]),
          .engines$stop_1(signal_inst[457:457]),
          .engines$flush_1(signal_inst[458:458]),
          .engines$check_1(signal_inst[459:459]),
          .engines$config_written_1(signal_inst[460:460]),
          .engines$line_write$valid_1(signal_inst[461:461]),
          .engines$line_write$addr_1(signal_inst[466:462]),
          .engines$line_write$data_1(signal_inst[482:467]),
          .check_setup$base(signal_inst[491:483]),
          .check_setup$loaded$valid(signal_inst[492:492]),
          .check_setup$loaded$value(signal_inst[508:493]),
          .check_setup$floor(signal_inst[509:509]),
          .check_setup$single_edge(signal_inst[510:510]),
          .start_all(signal_inst[511:511]) );
    assign signal_select_145 = signal_inst[2:1];
    assign signal_const_5 = 1'b0;
    assign signal_wire_36 = rst_n;
    assign signal_not = ~ signal_wire_36;
    assign vdd = 1'b1;
    always @(posedge signal_wire_37 or posedge signal_not) begin
        if (signal_not)
            signal_reg_4 <= signal_const_5;
        else
            signal_reg_4 <= vdd;
    end
    always @(posedge signal_wire_37 or posedge signal_not) begin
        if (signal_not)
            reset_done <= signal_const_5;
        else
            reset_done <= signal_reg_4;
    end
    assign signal_not_1 = ~ reset_done;
    assign signal_wire_37 = clk;
    engines
        engines
        ( .clock(signal_wire_37),
          .clear(signal_not_1),
          .hosts$config$side_set_count_0(signal_select_145),
          .hosts$config$side_set_base_0(signal_select_107),
          .hosts$config$side_set_pindirs_0(signal_select_106),
          .hosts$config$in_base_0(signal_select_105),
          .hosts$config$in_count_0(signal_select_104),
          .hosts$config$out_base_0(signal_select_103),
          .hosts$config$out_count_0(signal_select_102),
          .hosts$config$set_base_0(signal_select_101),
          .hosts$config$set_count_0(signal_select_100),
          .hosts$config$jmp_pin_0(signal_select_99),
          .hosts$config$capture_pin_0(signal_select_98),
          .hosts$config$capture_rising_0(signal_select_97),
          .hosts$config$in_shift_right_0(signal_select_96),
          .hosts$config$out_shift_right_0(signal_select_95),
          .hosts$config$autopush_0(signal_select_94),
          .hosts$config$push_threshold_0(signal_select_93),
          .hosts$config$autopull_0(signal_select_92),
          .hosts$config$pull_threshold_0(signal_select_91),
          .hosts$config$crc_width_0(signal_select_90),
          .hosts$config$crc_poly_0(signal_select_89),
          .hosts$config$crc_init_0(signal_select_88),
          .hosts$config$crc_reflect_0(signal_select_87),
          .hosts$config$stuff_threshold_0(signal_select_86),
          .hosts$config$stuff_level_0(signal_select_85),
          .hosts$config$wrap_bottom_0(signal_select_84),
          .hosts$config$wrap_top_0(signal_select_83),
          .hosts$config$period_fraction_0(signal_select_82),
          .hosts$config$autopull_data_0(signal_select_81),
          .hosts$config$manchester_0(signal_select_80),
          .hosts$config$line_code_0(signal_select_79),
          .hosts$config$route_0(signal_select_78),
          .hosts$start_0(signal_select_77),
          .hosts$program_write$valid_0(signal_select_76),
          .hosts$program_write$addr_0(signal_select_75),
          .hosts$program_write$data_0(signal_select_74),
          .hosts$data_write$valid_0(signal_select_73),
          .hosts$data_write$addr_0(signal_select_72),
          .hosts$data_write$data_0(signal_select_71),
          .hosts$tx$valid_0(signal_select_70),
          .hosts$tx$value_0(signal_select_69),
          .hosts$rx_pop_0(signal_select_68),
          .hosts$clear_irq_0(signal_select_67),
          .hosts$stop_0(signal_select_66),
          .hosts$flush_0(signal_select_65),
          .hosts$check_0(signal_select_64),
          .hosts$config_written_0(signal_select_63),
          .hosts$line_write$valid_0(signal_select_62),
          .hosts$line_write$addr_0(signal_select_61),
          .hosts$line_write$data_0(signal_select_60),
          .hosts$config$side_set_count_1(signal_select_59),
          .hosts$config$side_set_base_1(signal_select_58),
          .hosts$config$side_set_pindirs_1(signal_select_57),
          .hosts$config$in_base_1(signal_select_56),
          .hosts$config$in_count_1(signal_select_55),
          .hosts$config$out_base_1(signal_select_54),
          .hosts$config$out_count_1(signal_select_53),
          .hosts$config$set_base_1(signal_select_52),
          .hosts$config$set_count_1(signal_select_51),
          .hosts$config$jmp_pin_1(signal_select_50),
          .hosts$config$capture_pin_1(signal_select_49),
          .hosts$config$capture_rising_1(signal_select_48),
          .hosts$config$in_shift_right_1(signal_select_47),
          .hosts$config$out_shift_right_1(signal_select_46),
          .hosts$config$autopush_1(signal_select_45),
          .hosts$config$push_threshold_1(signal_select_44),
          .hosts$config$autopull_1(signal_select_43),
          .hosts$config$pull_threshold_1(signal_select_42),
          .hosts$config$crc_width_1(signal_select_41),
          .hosts$config$crc_poly_1(signal_select_40),
          .hosts$config$crc_init_1(signal_select_39),
          .hosts$config$crc_reflect_1(signal_select_38),
          .hosts$config$stuff_threshold_1(signal_select_37),
          .hosts$config$stuff_level_1(signal_select_36),
          .hosts$config$wrap_bottom_1(signal_select_35),
          .hosts$config$wrap_top_1(signal_select_34),
          .hosts$config$period_fraction_1(signal_select_33),
          .hosts$config$autopull_data_1(signal_select_32),
          .hosts$config$manchester_1(signal_select_31),
          .hosts$config$line_code_1(signal_select_30),
          .hosts$config$route_1(signal_select_29),
          .hosts$start_1(signal_select_28),
          .hosts$program_write$valid_1(signal_select_27),
          .hosts$program_write$addr_1(signal_select_26),
          .hosts$program_write$data_1(signal_select_25),
          .hosts$data_write$valid_1(signal_select_24),
          .hosts$data_write$addr_1(signal_select_23),
          .hosts$data_write$data_1(signal_select_22),
          .hosts$tx$valid_1(signal_select_21),
          .hosts$tx$value_1(signal_select_20),
          .hosts$rx_pop_1(signal_select_19),
          .hosts$clear_irq_1(signal_select_18),
          .hosts$stop_1(signal_select_17),
          .hosts$flush_1(signal_select_16),
          .hosts$check_1(signal_select_15),
          .hosts$config_written_1(signal_select_14),
          .hosts$line_write$valid_1(signal_select_13),
          .hosts$line_write$addr_1(signal_select_12),
          .hosts$line_write$data_1(signal_select_11),
          .pads(inputs),
          .check_setup$base(signal_select_9),
          .check_setup$loaded$valid(signal_select_8),
          .check_setup$loaded$value(signal_select_7),
          .check_setup$floor(signal_select_6),
          .check_setup$single_edge(signal_select_5),
          .start_all(signal_select_4),
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
          .engines$free_0(signal_inst_1[243:243]),
          .engines$irq_0(signal_inst_1[244:244]),
          .engines$fault$underflow_0(signal_inst_1[245:245]),
          .engines$fault$overflow_0(signal_inst_1[246:246]),
          .engines$fault$missed_deadline_0(signal_inst_1[247:247]),
          .engines$fault$decode_0(signal_inst_1[248:248]),
          .engines$fault$assumption_0(signal_inst_1[249:249]),
          .engines$capture_0(signal_inst_1[273:250]),
          .engines$capture_armed_0(signal_inst_1[274:274]),
          .engines$tx_level_0(signal_inst_1[278:275]),
          .engines$rx_level_0(signal_inst_1[282:279]),
          .engines$rx_head_0(signal_inst_1[298:283]),
          .engines$instruction_0(signal_inst_1[314:299]),
          .engines$program_word_0(signal_inst_1[330:315]),
          .engines$decode_ok_0(signal_inst_1[331:331]),
          .engines$opcode_onehot_0(signal_inst_1[339:332]),
          .engines$wait_select_0(signal_inst_1[367:340]),
          .engines$crc_0(signal_inst_1[383:368]),
          .engines$stuff_run_0(signal_inst_1[388:384]),
          .engines$flip_pending_0(signal_inst_1[389:389]),
          .engines$flip_bit_0(signal_inst_1[390:390]),
          .engines$push$valid_0(signal_inst_1[391:391]),
          .engines$push$value_0(signal_inst_1[407:392]),
          .engines$line_tx_0(signal_inst_1[411:408]),
          .engines$line_rx_0(signal_inst_1[415:412]),
          .engines$line_flag_0(signal_inst_1[416:416]),
          .engines$line_last_0(signal_inst_1[417:417]),
          .engines$pin_out_1(signal_inst_1[445:418]),
          .engines$pin_dir_1(signal_inst_1[473:446]),
          .engines$pc_1(signal_inst_1[482:474]),
          .engines$data_ptr_1(signal_inst_1[491:483]),
          .engines$data_addr_1(signal_inst_1[500:492]),
          .engines$x_1(signal_inst_1[516:501]),
          .engines$y_1(signal_inst_1[532:517]),
          .engines$p_1(signal_inst_1[548:533]),
          .engines$t_1(signal_inst_1[572:549]),
          .engines$t_fraction_1(signal_inst_1[588:573]),
          .engines$osr_1(signal_inst_1[604:589]),
          .engines$osr_count_1(signal_inst_1[609:605]),
          .engines$isr_1(signal_inst_1[625:610]),
          .engines$isr_count_1(signal_inst_1[630:626]),
          .engines$now_1(signal_inst_1[654:631]),
          .engines$stall_1(signal_inst_1[659:655]),
          .engines$halted_1(signal_inst_1[660:660]),
          .engines$free_1(signal_inst_1[661:661]),
          .engines$irq_1(signal_inst_1[662:662]),
          .engines$fault$underflow_1(signal_inst_1[663:663]),
          .engines$fault$overflow_1(signal_inst_1[664:664]),
          .engines$fault$missed_deadline_1(signal_inst_1[665:665]),
          .engines$fault$decode_1(signal_inst_1[666:666]),
          .engines$fault$assumption_1(signal_inst_1[667:667]),
          .engines$capture_1(signal_inst_1[691:668]),
          .engines$capture_armed_1(signal_inst_1[692:692]),
          .engines$tx_level_1(signal_inst_1[696:693]),
          .engines$rx_level_1(signal_inst_1[700:697]),
          .engines$rx_head_1(signal_inst_1[716:701]),
          .engines$instruction_1(signal_inst_1[732:717]),
          .engines$program_word_1(signal_inst_1[748:733]),
          .engines$decode_ok_1(signal_inst_1[749:749]),
          .engines$opcode_onehot_1(signal_inst_1[757:750]),
          .engines$wait_select_1(signal_inst_1[785:758]),
          .engines$crc_1(signal_inst_1[801:786]),
          .engines$stuff_run_1(signal_inst_1[806:802]),
          .engines$flip_pending_1(signal_inst_1[807:807]),
          .engines$flip_bit_1(signal_inst_1[808:808]),
          .engines$push$valid_1(signal_inst_1[809:809]),
          .engines$push$value_1(signal_inst_1[825:810]),
          .engines$line_tx_1(signal_inst_1[829:826]),
          .engines$line_rx_1(signal_inst_1[833:830]),
          .engines$line_flag_1(signal_inst_1[834:834]),
          .engines$line_last_1(signal_inst_1[835:835]),
          .pin_out(signal_inst_1[855:836]),
          .pin_dir(signal_inst_1[875:856]),
          .check$verdict$busy(signal_inst_1[876:876]),
          .check$verdict$accepted(signal_inst_1[877:877]),
          .check$verdict$reject_pc(signal_inst_1[887:878]),
          .check$verdict$reason(signal_inst_1[892:888]),
          .check$certified_0(signal_inst_1[893:893]),
          .check$certified_1(signal_inst_1[894:894]),
          .check$refused_0(signal_inst_1[895:895]),
          .check$refused_1(signal_inst_1[896:896]) );
    assign signal_select_146 = signal_inst_1[855:836];
    assign signal_select_147 = signal_select_146[11:5];
    assign signal_cat = { signal_select_147,
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

