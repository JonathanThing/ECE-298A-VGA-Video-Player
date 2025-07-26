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
6                 B[0]        IO3 (HOLD)(I/O)
7                 B[1]        

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
    wire [17:0] spi_data;
    //wire spi_active;

    //wire decode_allow_shift;

    assign uio_oe[5] = 0;
    assign uio_out[5] = 0;
    assign uio_oe[7] = 0;
    assign uio_out[7] = 0;

    assign uio_oe[1:0] = 2'b11;
    wire [17:0] data_1;
    wire [17:0] data_2;
    wire [17:0] data_3;
    wire [17:0] data_4;
    wire [17:0] data_5;
    wire [17:0] data_6;

    wire data_1_empty;
    wire data_2_empty;
    wire data_3_empty;
    wire data_4_empty;
    wire data_5_empty;
    wire data_6_empty;

    wire global_shift;
    wire upper_shift;
    wire lower_shift;

    wire stop_detected;
    reg reset_n_req;

    assign upper_shift = data_1_empty | data_2_empty | data_3_empty;
    assign lower_shift = data_4_empty | data_5_empty | data_6_empty;

    qspi_fsm qspi_cont_inst (
        .clk(clk),
        .rst_n(rst_n & reset_n_req),
        .spi_clk(uio_out[4]),
        .spi_cs_n(uio_out[2]),
        .spi_di(uio_out[3]),
        .spi_hold_n(uio_out[6]),

        .spi_io0(uio_in[3]),
        .spi_io1(ui_in[2]),
        .spi_io2(ui_in[3]),
        .spi_io3(uio_in[6]),

        .instruction(spi_data),
        .spi_cs_oe(uio_oe[2]),
        .spi_di_oe(uio_oe[3]),
        .spi_sclk_oe(uio_oe[4]),
        .spi_hold_n_oe(uio_oe[6]),
        .valid(spi_ready),       // High when instruction is valid
        .shift_data(global_shift | lower_shift | upper_shift)
    );

    data_buffer buf1(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),
        .shift_data(global_shift | data_2_empty | data_3_empty | data_4_empty | lower_shift),
        
        .data_in(spi_data),
        .prev_empty(!spi_ready),
        .data_out(data_1),
        .empty(data_1_empty)
    );

    data_buffer buf2(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),
        .shift_data(global_shift | data_3_empty | data_4_empty | lower_shift),

        .data_in(data_1),
        .prev_empty(data_1_empty),
        .data_out(data_2),
        .empty(data_2_empty)
    );

    data_buffer buf3(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),
        .shift_data(global_shift | data_4_empty | lower_shift),

        .data_in(data_2),
        .prev_empty(data_2_empty),
        .data_out(data_3),
        .empty(data_3_empty)
    );

    data_buffer buf4(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),
        .shift_data(global_shift | lower_shift),

        .data_in(data_3),
        .prev_empty(data_3_empty),
        .data_out(data_4),
        .empty(data_4_empty)
    );

    data_buffer buf5(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),
        .shift_data(global_shift | data_5_empty | data_6_empty),

        .data_in(data_4),
        .prev_empty(data_4_empty),
        .data_out(data_5),
        .empty(data_5_empty)
    );

    data_buffer buf6(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),
        .shift_data(global_shift | data_6_empty),

        .data_in(data_5),
        .prev_empty(data_5_empty),
        .data_out(data_6),
        .empty(data_6_empty)
    );

    wire req_next_pix;

    instruction_decoder decoder(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),

        .instruction(data_6),
        .pixel_req(req_next_pix),
        
        .cont_shift(global_shift),
        .red(uo_out[2:0]),
        .green(uo_out[5:3]),
        .blue(uo_out[7:6]),
        .stop_detected(stop_detected)
    );

    vga_module vga_inst(
        .clk(clk),
        .rst_n(rst_n & reset_n_req),

        .hsync(uio_out[0]),
        .vsync(uio_out[1]),
        .pixel_req(req_next_pix)
    );
    
    // Synchronous reset signal triggered by stop instruction
    always @(posedge clk) begin
        if (!rst_n) reset_n_req <= 1;
        else if (stop_detected) reset_n_req <= 0;
        else reset_n_req <= 1;
    end

    // Unused signals
    wire _unused = &{ena, ui_in[7:4], ui_in[1:0], uio_in[6:4], uio_in[2:0], uio_oe[5], uio_out[5], uio_in[5], uio_out[7], uio_in[7]};
    
endmodule