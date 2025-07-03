/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/* 
----- INPUT MAPPING -----
  INPUT           OUTPUT      BIDIR
0 SPI_Latency[0]  R[0]        HSYNC
1 SPI_Latency[1]  R[1]        VSYNC
2 IO1 (DO)        R[2]        nCS
3 IO2             G[0]        IO0 (DI)
4                 G[1]        SCLK
5                 G[2]        PWM Audio
6                 B[0]        B[2]
7                 B[1]        IO3 (HOLD)

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

    // Control signals - automatically start sequence
    wire start_seq = rst_n;     // Start when coming out of reset
    wire end_seq = 1'b0;        // Never end sequence
    
    // SPI interface signals
    wire spi_cs_n, spi_clk;
    wire [3:0] spi_quad_in, spi_quad_out, spi_quad_oe;
    
    // Map SPI quad pins to bidirectional IOs
    assign spi_quad_in = {uio_in[7], uio_in[3], uio_in[2], uio_in[4]}; // IO3, IO0, DO, SCLK as inputs for quad read
    
    // VGA output signals
    wire vga_hsync, vga_vsync;
    wire [2:0] vga_red, vga_green, vga_blue;
    wire vga_pixel_clock, display_active;
    
    // SPI to buffer interface - removed unused spi_instruction
    wire spi_data_valid;
    wire spi_busy;
    wire spi_read_enable;
    
    // Buffer chain signals
    wire [3:0] buf0_data_out, buf1_data_out, buf2_data_out;
    wire buf0_shift_out, buf1_shift_out, buf2_shift_out, buf3_shift_out;
    wire [19:0] current_instruction, prev_instruction1, prev_instruction2, prev_instruction3;
    
    // Decoder signals
    wire [8:0] pixel_color;
    wire need_next_instr, color_valid;
    
    // SPI Flash Reader
    spi_flash_reader spi_reader (
        .clk(clk),
        .rst_n(rst_n),
        .start_sequence(start_seq),
        .read_enable(spi_read_enable),
        .end_sequence(end_seq),
        
        .spi_cs_n(spi_cs_n),
        .spi_clk(spi_clk),
        .spi_quad_in(spi_quad_in),
        .spi_quad_out(spi_quad_out),
        .spi_quad_oe(spi_quad_oe),
        
        .instruction(spi_instr_unused),      // Connect to dummy wire
        .data_valid(spi_data_valid),
        .busy(spi_busy)
    );
    
    // Simple read enable logic - keep reading unless decoder needs to catch up
    assign spi_read_enable = !need_next_instr || spi_data_valid;
    
    // Instruction Buffer Chain (4 buffers for proper pipeline)
    instruction_buffer buf0 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(spi_quad_in),          // Direct from SPI quad input
        .shift_enable(spi_data_valid),   // Shift when SPI has new data
        .data_out(buf0_data_out),
        .shift_out(buf0_shift_out),
        .instruction(buf0_instr_unused)  // Connect to dummy wire
    );
    
    instruction_buffer buf1 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(buf0_data_out),
        .shift_enable(buf0_shift_out),
        .data_out(buf1_data_out),
        .shift_out(buf1_shift_out),
        .instruction(buf1_instr_unused)  // Connect to dummy wire
    );
    
    instruction_buffer buf2 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(buf1_data_out),
        .shift_enable(buf1_shift_out),
        .data_out(buf2_data_out),
        .shift_out(buf2_shift_out),
        .instruction(buf2_instr_unused)  // Connect to dummy wire
    );
    
    instruction_buffer buf3 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(buf2_data_out),
        .shift_enable(buf2_shift_out),
        .data_out(buf3_data_unused),     // Connect to dummy wire
        .shift_out(buf3_shift_out),      // Connect for decoder
        .instruction(prev_instruction3)
    );
    
    // Instruction Decoder
    decode_instr decoder (
        .clk(clk),                      // Use main clock as pixel clock
        .rst_n(rst_n),
        .instruction(prev_instruction3), // Take full 20-bit instruction from buf3
        .instruction_valid(buf3_shift_out), // New instruction when data completes in buf3
        .pixel_clock(vga_pixel_clock),
        .color_out(pixel_color),
        .need_next_instr(need_next_instr),
        .color_valid(color_valid)
    );
    
    // VGA Module
    vga_module vga (
        .clk(clk),                      // Use main clock as pixel clock
        .rst_n(rst_n),
        .color_in(pixel_color),
        .color_valid(color_valid),
        
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .red(vga_red),
        .green(vga_green),
        .blue(vga_blue),
        .pixel_clock(vga_pixel_clock),
        .display_active(display_active)
    );
    
    // Output mapping
    assign uo_out = {vga_blue[1], vga_blue[0], vga_green[2], vga_green[1], vga_green[0], vga_red[2], vga_red[1], vga_red[0]};
    
    // Bidirectional output mapping
    assign uio_out = {spi_quad_out[3], vga_vsync, spi_cs_n, spi_quad_out[0], spi_clk, 1'b0, 1'b0, vga_hsync};
    assign uio_oe = {spi_quad_oe[3], 1'b1, 1'b1, spi_quad_oe[0], 1'b1, 1'b0, 1'b0, 1'b1}; // VSYNC, CS, SCLK, HSYNC as outputs
    
    // Unused signals
    wire _unused = &{ena, ui_in, uio_in[6:5], uio_in[1:0], display_active, spi_busy,
                     vga_blue[2], spi_quad_out[2:1], spi_quad_oe[2:1],
                     buf0_instr_unused, buf1_instr_unused, buf2_instr_unused, 
                     buf3_data_unused, spi_instr_unused};
    
endmodule