/*
 * Copyright (c) 2026 Marcos Ashton
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Usb_frame_rx alone on an Icepi Zero, in place of the chip: D+ pulled up on the first
// USB-C port, so the host that port is plugged into talks full speed to it. Each packet
// lands in a 512-word ring, the receiver rearmed the cycle after, and goes out on OUT0
// (header 8, Pico B GP1) at 1 Mbaud: 0xa5, flags, words, packets lost so far, then the
// words low byte first. Flags, bit 0 up: crc5_ok crc16_ok half aligned stuff_error
// dropped. Header 15 high detaches; the button resets.
module usb_fs_check (
    input  wire       clk,
    input  wire       button_n,
    output wire [7:0] uo,
    input  wire       usb_dp,
    input  wire       usb_dn,
    output wire       usb_pull_dp,
    output wire       usb_pull_dn,
    input  wire       usb_detach
);

  wire clk_48;
  wire clk_feedback;
  wire locked;

  // icepi_top's PLL at 48 MHz
  (* FREQUENCY_PIN_CLKI = "50" *)
  (* FREQUENCY_PIN_CLKOS = "48" *)
  (* ICP_CURRENT = "12" *)
  (* LPF_RESISTOR = "8" *)
  (* MFG_ENABLE_FILTEROPAMP = "1" *)
  (* MFG_GMCREF_SEL = "2" *)
  EHXPLLL #(
      .PLLRST_ENA("DISABLED"),
      .INTFB_WAKE("DISABLED"),
      .STDBY_ENABLE("DISABLED"),
      .DPHASE_SOURCE("DISABLED"),
      .OUTDIVIDER_MUXA("DIVA"),
      .OUTDIVIDER_MUXB("DIVB"),
      .OUTDIVIDER_MUXC("DIVC"),
      .OUTDIVIDER_MUXD("DIVD"),
      .CLKI_DIV(5),
      .CLKOP_ENABLE("ENABLED"),
      .CLKOP_DIV(48),
      .CLKOP_CPHASE(9),
      .CLKOP_FPHASE(0),
      .CLKOS_ENABLE("ENABLED"),
      .CLKOS_DIV(10),
      .CLKOS_CPHASE(0),
      .CLKOS_FPHASE(0),
      .FEEDBK_PATH("CLKOP"),
      .CLKFB_DIV(1)
  ) pll (
      .RST(1'b0),
      .STDBY(1'b0),
      .CLKI(clk),
      .CLKOP(clk_feedback),
      .CLKOS(clk_48),
      .CLKFB(clk_feedback),
      .CLKINTFB(),
      .PHASESEL0(1'b0),
      .PHASESEL1(1'b0),
      .PHASEDIR(1'b1),
      .PHASESTEP(1'b1),
      .PHASELOADREG(1'b1),
      .PLLWAKESYNC(1'b0),
      .ENCLKOP(1'b0),
      .LOCK(locked)
  );

  reg [1:0] reset_sync = 2'b11;
  always @(posedge clk_48) reset_sync <= {reset_sync[0], ~(locked & button_n)};
  wire clear = reset_sync[1];

  OBZ pull_dp_pad (
      .I(1'b1),
      .T(usb_detach),
      .O(usb_pull_dp)
  );

  OBZ pull_dn_pad (
      .I(1'b0),
      .T(1'b1),
      .O(usb_pull_dn)
  );

  // Both_edges: two flops on each edge, the falling side onto the rising, earlier in bit 0
  reg [1:0] dp_rising, dm_rising, dp_falling, dm_falling;
  reg dp_fell, dm_fell;
  always @(posedge clk_48) begin
    dp_rising <= {dp_rising[0], usb_dp};
    dm_rising <= {dm_rising[0], usb_dn};
    dp_fell   <= dp_falling[1];
    dm_fell   <= dm_falling[1];
  end
  always @(negedge clk_48) begin
    dp_falling <= {dp_falling[0], usb_dp};
    dm_falling <= {dm_falling[0], usb_dn};
  end

  reg arm;
  reg [8:0] base;
  wire write_valid;
  wire [8:0] write_addr;
  wire [15:0] write_data;
  wire [9:0] words;
  wire finished, crc5_ok, crc16_ok, half, aligned, stuff_error, dropped;

  usb_frame_rx_top rx (
      .clock(clk_48),
      .clear(clear),
      .dp({dp_rising[1], dp_fell}),
      .dm({dm_rising[1], dm_fell}),
      .control$arm(arm),
      .control$base(base),
      .may_write(1'b1),
      .write$valid(write_valid),
      .write$addr(write_addr),
      .write$data(write_data),
      .status$words(words),
      .status$finished(finished),
      .status$crc5_ok(crc5_ok),
      .status$crc16_ok(crc16_ok),
      .status$half(half),
      .status$aligned(aligned),
      .status$stuff_error(stuff_error),
      .status$dropped(dropped),
      .status$receiving(),
      .status$armed()
  );

  reg [15:0] ring[0:511];
  always @(posedge clk_48) if (write_valid) ring[write_addr] <= write_data;

  // Finished packets wait here for the UART: base, words and flags.
  localparam QUEUE_BITS = 4;
  reg [22:0] queue[0:(1<<QUEUE_BITS)-1];
  reg [QUEUE_BITS:0] queue_head, queue_tail;
  reg [7:0] lost;
  wire [QUEUE_BITS:0] queue_used = queue_tail - queue_head;
  wire queue_full = queue_used[QUEUE_BITS];
  wire [7:0] count = words > 255 ? 8'd255 : words[7:0];
  // a packet may run to 64 words past its base before the ring wraps
  wire [9:0] next_base = base + words;

  always @(posedge clk_48) begin
    arm <= 1'b0;
    if (clear) begin
      arm <= 1'b1;
      base <= 9'd0;
      queue_tail <= 0;
      lost <= 8'd0;
    end else if (finished && !arm) begin
      if (queue_full) lost <= lost + 1'b1;
      else begin
        queue[queue_tail[QUEUE_BITS-1:0]] <= {
          base, count, dropped, stuff_error, aligned, half, crc16_ok, crc5_ok
        };
        queue_tail <= queue_tail + 1'b1;
      end
      base <= next_base > 512 - 64 ? 9'd0 : next_base[8:0];
      arm  <= 1'b1;
    end
  end

  // 8N1 at 48 cycles a bit
  reg [9:0] shift;
  reg [5:0] tick;
  reg [3:0] bits_left;
  wire tx_idle = bits_left == 0;
  reg tx_load;
  reg [7:0] tx_byte;
  always @(posedge clk_48) begin
    if (clear) begin
      shift <= 10'h3ff;
      bits_left <= 0;
    end else if (tx_load) begin
      shift <= {1'b1, tx_byte, 1'b0};
      bits_left <= 10;
      tick <= 47;
    end else if (!tx_idle) begin
      if (tick == 0) begin
        shift <= {1'b1, shift[9:1]};
        bits_left <= bits_left - 1'b1;
        tick <= 47;
      end else tick <= tick - 1'b1;
    end
  end

  // header bytes 0 to 3, then two a word
  reg [22:0] packet;
  reg [8:0] read_addr;
  reg [8:0] byte_index;
  reg sending;
  reg [15:0] read_word;
  always @(posedge clk_48) read_word <= ring[read_addr];
  wire [8:0] packet_bytes = 9'd4 + {packet[13:6], 1'b0};

  always @(posedge clk_48) begin
    tx_load <= 1'b0;
    if (clear) begin
      queue_head <= 0;
      sending <= 1'b0;
    end else if (!sending) begin
      if (queue_head != queue_tail) begin
        packet <= queue[queue_head[QUEUE_BITS-1:0]];
        queue_head <= queue_head + 1'b1;
        byte_index <= 0;
        sending <= 1'b1;
      end
    end else if (tx_idle && !tx_load) begin
      read_addr <= packet[22:14] + ((byte_index - 9'd3) >> 1);
      case (byte_index)
        0: tx_byte <= 8'ha5;
        1: tx_byte <= {2'b00, packet[5:0]};
        2: tx_byte <= packet[13:6];
        3: tx_byte <= lost;
        default: tx_byte <= byte_index[0] ? read_word[15:8] : read_word[7:0];
      endcase
      if (byte_index == packet_bytes) sending <= 1'b0;
      else begin
        tx_load <= 1'b1;
        byte_index <= byte_index + 1'b1;
      end
    end
  end

  // OUT0 the UART, OUT1 (CAN's D) and OUT6 (the flash's CS) high, the rest low
  assign uo = {1'b1, 4'b0000, 1'b1, shift[0], 1'b0};

endmodule
