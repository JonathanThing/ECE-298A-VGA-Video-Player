/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/* 
----- INPUT MAPPING -----
  INPUT           OUTPUT      BIDIR
0 SPI_Latency[0]  R[0]        HSYNC     (OUT ONLY)
1 SPI_Latency[1]  R[1]        VSYNC     (OUT ONLY)
2 IO1 (DO)        R[2]        nCS       (OUT ONLY)
3 IO2             G[0]        IO0 (DI)  (I/O)
4                 G[1]        SCLK      (OUT ONLY)
5                 G[2]        PWM Audio (OUT ONLY)
6                 B[0]        B[2]      (OUT ONLY)
7                 B[1]        IO3 (HOLD)(I/O)

*/

module tt_um_jonathan_thing_vga (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock (~25MHz pixel clock)
    input  wire       rst_n     // reset_n - low to reset
);

    wire spi_ready;
    wire [19:0] spi_data;
    wire spi_active;

    assign uio_oe[5] = 0;
    assign uio_out[5] = 0;

    assign uio_oe[1:0] = 2'b11;
    assign uio_oe[6] = 1;

    qspi_controller qspi_cont_inst (
        .clk(clk),
        .rst_n(rst_n),
        .spi_clk(uio_out[4]),
        .spi_cs_n(uio_out[2]),
        .spi_di(uio_out[3]),
        .spi_hold_n(uio_out[7]),

        .spi_io0(uio_in[3]),
        .spi_io1(ui_in[2]),
        .spi_io2(ui_in[3]),
        .spi_io3(uio_in[7]),
        
        .instruction(spi_data),
        .spi_cs_oe(uio_oe[2]),
        .spi_di_oe(uio_oe[3]),
        .spi_sclk_oe(uio_oe[4]),
        .spi_hold_n_oe(uio_oe[7]),
        .valid(spi_ready),       // High when instruction is valid
        .active(spi_active)
    );

    wire [19:0] data_1;
    wire [19:0] data_2;
    wire [19:0] data_3;
    wire [19:0] data_4;

    wire data_1_ready;
    wire data_2_ready;
    wire data_3_ready;
    wire data_4_ready;

    data_buffer buf0(
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(spi_active),
        
        .data_in(spi_data),
        .prev_empty(!spi_ready),
        .instruction(data_1),
        .valid(data_1_ready)
    );

    data_buffer buf1(
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(spi_active),

        .data_in(data_1),
        .prev_empty(!data_1_ready),
        .instruction(data_2),
        .valid(data_2_ready)
    );

    data_buffer buf2(
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(spi_active),

        .data_in(data_2),
        .prev_empty(!data_2_ready),
        .instruction(data_3),
        .valid(data_3_ready)
    );

    data_buffer buf3(
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(spi_active),

        .data_in(data_3),
        .prev_empty(!data_3_ready),
        .instruction(data_4),
        .valid(data_4_ready)
    );

    wire [8:0] colour_in;
    wire req_next_pix;
    wire pixel_ready;

    instruction_decoder decoder(
        .clk(clk),
        .rst_n(rst_n),

        .instruction(data_4),
        .instr_valid(data_4_ready),
        .pixel_req(req_next_pix),

        .rgb_out(colour_in),
        .rgb_valid(pixel_ready)
    );

    vga_module vga_inst(
        .clk(clk),
        .rst_n(rst_n),

        .rgb_in(colour_in),
        .rgb_valid(pixel_ready),
        
        .hsync(uio_out[0]),
        .vsync(uio_out[1]),
        .red(uo_out[2:0]),
        .green(uo_out[5:3]),
        .blue({uio_out[6], uo_out[7:6]}),
        .pixel_req(req_next_pix)
    );
    
    // Unused signals
    wire _unused = &{ena, ui_in[7:4], ui_in[1:0], uio_in[6:4], uio_in[2:0], uio_oe[5], uio_out[5], uio_in[5]};
    
endmodule