/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_jonathan_thing_vga (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire [19:0] spi_data;
  wire next_data;

  // vga
  wire vga_blank;
  wire vga_next_frame;
  wire vga_next_line;
  wire data_ready_wire;

  wire stop_sig;

  // QSPI control signals
  wire spi_clk_wire;
  wire spi_di_wire;
  wire spi_hold_n_wire;
  wire cs_n_wire;
  wire [3:0] io_direction_wire;

  qspi qspi_inst(
    .clk(clk),
    .rst_n(rst_n),
    .spi_latency(ui_in[1:0]),
    .spi_clk(spi_clk_wire),
    .spi_di(spi_di_wire),
    .spi_hold_n(spi_hold_n_wire),
    .spi_inputs({uio_in[7], ui_in[3], ui_in[2], uio_in[3]}),
    .io_direction(io_direction_wire),
    .cs_n(cs_n_wire),
    .shift_data(next_data),
    .stop_read(stop_sig),
    .data_ready(data_ready_wire),
    .data_out(spi_data)
  );

  wire [19:0] buffer_data_1;
  wire [19:0] buffer_data_2;
  wire [19:0] buffer_data_3;

  data_buffer buffer1(
    .clk(clk),
    .rst_n(rst_n),
    .data_in(spi_data),
    .data_out(buffer_data_1),
    .shift_data(next_data)
  );

  data_buffer buffer2(
    .clk(clk),
    .rst_n(rst_n),
    .data_in(buffer_data_1),
    .data_out(buffer_data_2),
    .shift_data(next_data)
  );

  data_buffer buffer3(
    .clk(clk),
    .rst_n(rst_n),
    .data_in(buffer_data_2),
    .data_out(buffer_data_3),
    .shift_data(next_data)
  );

  wire [8:0] colour_dec;

  instr_decoder instr_decoder_inst(
    .clk(clk),
    .rst_n(rst_n),
    .data_ready(data_ready_wire),
    .data(buffer_data_3),
    .next_frame(vga_next_frame),
    .next_line(vga_next_line),
    .next_pixel(!vga_blank),
    .get_next(next_data),
    .colour_out(colour_dec),
    .stop_signal(stop_sig)
  );

  wire [9:0] x_temp;
  wire [9:0] y_temp;

  vga_unit vga_unit_inst(
    .clk(clk),
    .rst_n(rst_n),
    .enable(1'b0),
    .colour_in(colour_dec),
    .x_pos(x_temp),
    .y_pos(y_temp),
    .vsync(vsync_wire),
    .hsync(hsync_wire),
    .colour_out(colour_wire),
    .blank(vga_blank),
    .next_frame(vga_next_frame),
    .next_line(vga_next_line)
  );

  // VGA control signals
  wire vsync_wire;
  wire hsync_wire;
  wire [8:0] colour_wire;

  // Properly assign uio_out pins instead of assigning all to 0
  assign uio_out[0] = hsync_wire;
  assign uio_out[1] = vsync_wire;  
  assign uio_out[2] = cs_n_wire;
  assign uio_out[3] = spi_di_wire;
  assign uio_out[4] = spi_clk_wire;
  assign uio_out[5] = 1'b0; // unused
  assign uio_out[6] = colour_wire[0]; // least significant bit of colour
  assign uio_out[7] = spi_hold_n_wire;

  // Properly assign uio_oe pins based on io_direction from QSPI
  assign uio_oe[0] = 1'b1; // hsync output
  assign uio_oe[1] = 1'b1; // vsync output
  assign uio_oe[2] = io_direction_wire[0]; // cs_n
  assign uio_oe[3] = io_direction_wire[1]; // spi_di
  assign uio_oe[4] = io_direction_wire[2]; // spi_clk
  assign uio_oe[5] = 1'b0; // unused, set as input
  assign uio_oe[6] = 1'b1; // colour output
  assign uio_oe[7] = io_direction_wire[3]; // spi_hold_n

  // Assign the remaining colour bits to uo_out
  assign uo_out[2:0] = colour_wire[2:0];   // RGB lower bits
  assign uo_out[5:3] = colour_wire[5:3];   // RGB middle bits  
  assign uo_out[7:6] = colour_wire[7:6];   // RGB upper bits

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:4], uio_in[6:4], uio_in[2:0], 1'b0, x_temp, y_temp};
endmodule