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

  // All output pins must be assigned. If not used, assign to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire spi_data [19:0];
  wire next_data;

  // vga
  wire vga_blank;
  wire vga_next_frame;
  wire vga_next_line;

  qspi qspi_inst(
    .clk(clk),
    .rst_n(rst_n),
    .spi_latency(ui_in[1:0]),
    .spi_clk(uio_out[4]),
    .spi_di(uio_out[3]),
    .spi_hold_n(uio_out[7]),
    .spi_inputs({uio_in[7], ui_in[3], ui_in[2], uio_in[3]}),
    .io_direction({uio_oe[7], uio_oe[4], uio_oe[3], uio_oe[2]}),
    .cs_n(uio_out[2]),
    .shift_data(next_data),
    .data_ready(),
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

  // video video_inst();

  // vga_timing vga_timing_inst ();

  wire [8:0] colour_dec;

  instr_decoder instr_decoder_inst(
    .clk(clk),
    .rst_n(rst_n),

    .data_ready(),
    .data(buffer_data_3),
    .next_frame(vga_next_frame),
    .next_line(vga_next_line),
    .next_pixel(!vga_blank),
    
    .get_next(next_data),
    .colour_out(colour_dec)
  );

  vga_unit vga_unit_inst(
    .clk(clk),
    .rst_n(rst_n),
    .enable(),
    .colour_in(colour_dec),
    .x_pos(),
    .y_pos(),
    .vsync(uio_out[1]),
    .hsync(uio_out[0]),
    .colour_out({uo_out[2:0], uo_out[5:3], uio_out[6], uo_out[7:6]}),
    .blank(vga_blank),
    .next_frame(vga_next_frame),
    .next_line(vga_next_line)
  );

  // pwm pwm_inst();

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:5], uio_in[7:6], 1'b0};
endmodule
