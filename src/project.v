`default_nettype none

/* 
Top File for the RLE VGA Video Player project

----- INPUT MAPPING -----
  INPUT           OUTPUT      BIDIR
0 IO_2            R[1]        VSYNC     (OUT ONLY)
1                 G[0]        PWM       (OUT ONLY)
2                 G[2]        SCLK      (OUT ONLY)
3                 B[1]        IO0 (DI)  (I/O)
4 IO_1            R[0]        HSYNC     (OUT ONLY)
5                 R[2]        
6                 G[1]        IO3 (HOLD)(I/O)
7                 B[0]        nCS       (OUT ONLY)
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

    // Bidir 
    wire HSYNC;
    wire VSYNC;
    wire PWM;
    wire SCLK;
    wire DI;
    wire HOLD;
    wire nCS;
    wire HOLD_OE;
    wire DI_OE;

    // Input
    wire [3:0] IO;

    // Output
    wire [2:0] red;
    wire [2:0] green;
    wire [1:0] blue;
    

    // IO mapping
    assign uio_out = {
        nCS,        
        HOLD,        
        1'b0,       
        HSYNC,      
        DI,         
        SCLK,       
        PWM,        
        VSYNC       
    };

    assign uio_oe = {
        1'b1,
        HOLD_OE,
        1'b0,
        1'b1,
        DI_OE,
        1'b1,
        1'b1,
        1'b1
    };

    // Input
    assign IO[0] = uio_in[3];
    assign IO[1] = ui_in[4];
    assign IO[2] = ui_in[0];
    assign IO[3] = uio_in[6];

    // Output
    assign uo_out = {blue[0], green[1], red[2], red[0], blue[1], green[2], green[0], red[1]};

    // Data buffers
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

    // SPI signals
    wire spi_ready;
    wire [17:0] spi_data;

    // Shift signals
    wire global_shift;  // Shift all data buffers, triggered by instruction decoder
    wire upper_shift;   // Shift data buffers 1, 2, 3
    wire lower_shift;   // Shift data buffers 4, 5, 6

    assign upper_shift = data_1_empty | data_2_empty | data_3_empty;
    assign lower_shift = data_4_empty | data_5_empty | data_6_empty;

    // Software reset signals
    wire stop_detected;
    reg reset_n_req;  
    wire system_reset_n = rst_n & reset_n_req; 

    // Synchronous reset signal triggered by stop signal
    always @(posedge clk) begin
        if (rst_n && stop_detected) reset_n_req <= 0;
        else reset_n_req <= 1;
    end

    // ------------------------------- QSPI -------------------------------

    qspi_fsm qspi_cont_inst (
        .clk(clk),
        .rst_n(system_reset_n),
        .spi_clk(SCLK),
        .spi_cs_n(nCS),
        .spi_di(DI),
        .spi_hold_n(HOLD),

        .spi_io(IO),

        .spi_di_oe(DI_OE),
        .spi_hold_n_oe(HOLD_OE),

        .instruction(spi_data),
        .valid(spi_ready),       
        .shift_data(global_shift | lower_shift | upper_shift),
        .vsync(VSYNC)
    );

    // ------------------------------- Data Buffers -------------------------------
    // Data buffers are shifted if the instruction decoder requests it (global shift).
    // A buffer will also shift if it is empty and the buffer before it is not empty,
    // This will shift all the buffers that come before it.

    data_buffer buf1(
        .clk(clk),
        .rst_n(system_reset_n),
        .shift_data(global_shift | data_2_empty | data_3_empty | data_4_empty | lower_shift),
        
        .data_in(spi_data),
        .prev_empty(!spi_ready),
        .data_out(data_1),
        .empty(data_1_empty)
    );

    data_buffer buf2(
        .clk(clk),
        .rst_n(system_reset_n),
        .shift_data(global_shift | data_3_empty | data_4_empty | lower_shift),

        .data_in(data_1),
        .prev_empty(data_1_empty),
        .data_out(data_2),
        .empty(data_2_empty)
    );

    data_buffer buf3(
        .clk(clk),
        .rst_n(system_reset_n),
        .shift_data(global_shift | data_4_empty | lower_shift),

        .data_in(data_2),
        .prev_empty(data_2_empty),
        .data_out(data_3),
        .empty(data_3_empty)
    );

    data_buffer buf4(
        .clk(clk),
        .rst_n(system_reset_n),
        .shift_data(global_shift | lower_shift),

        .data_in(data_3),
        .prev_empty(data_3_empty),
        .data_out(data_4),
        .empty(data_4_empty)
    );

    data_buffer buf5(
        .clk(clk),
        .rst_n(system_reset_n),
        .shift_data(global_shift | data_5_empty | data_6_empty),

        .data_in(data_4),
        .prev_empty(data_4_empty),
        .data_out(data_5),
        .empty(data_5_empty)
    );

    data_buffer buf6(
        .clk(clk),
        .rst_n(system_reset_n),
        .shift_data(global_shift | data_6_empty),

        .data_in(data_5),
        .prev_empty(data_5_empty),
        .data_out(data_6),
        .empty(data_6_empty)
    );

    // ------------------------- VGA Output -------------------------------

    wire req_next_pix; // Signal the instruction decoder to request the next pixel
    wire mixed_region;  // Region where audio and colour can be buffered together
    wire [7:0] pwm_sample;

    instruction_decoder decoder(
        .clk(clk),
        .rst_n(system_reset_n),

        .instruction(data_6),
        .pixel_req(req_next_pix),
        .mixed_region(mixed_region),

        .cont_shift(global_shift),
        .red(red),
        .green(green),
        .blue(blue),
        .stop_detected(stop_detected),
        .pwm_sample(pwm_sample)
    );

    vga_module vga_inst(
        .clk(clk),
        .rst_n(system_reset_n),

        .hsync(HSYNC),
        .vsync(VSYNC),
        .pixel_req(req_next_pix),
        .mixed_region(mixed_region)
    );

    pwm_module pwm_inst(
        .clk(clk),
        .rst_n(system_reset_n),

        .sample(pwm_sample),
        .pwm(PWM)
    );

    // Unused signals
    wire _unused = &{ena, ui_in[7:5], ui_in[3:1], uio_in[2:0], uio_in[5:4], uio_in[7], uio_oe[5], uio_out[5]};
    
endmodule