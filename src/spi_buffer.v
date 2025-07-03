/*
 * 20-bit Instruction Buffer
 * Simple shift register buffer for pipelining SPI instruction reads
 * Shifts in 4 bits at a time to match SPI quad read
 */

module instruction_buffer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  data_in,     // 4-bit data from SPI (or previous buffer)
    input  wire        shift_enable, // Enable shifting (from SPI or previous buffer)
    output wire [3:0]  data_out,    // 4-bit data to next buffer
    output wire        shift_out,   // Shift enable to next buffer
    output wire [19:0] instruction  // Complete 20-bit instruction
);

    // 20-bit shift register (5 stages of 4 bits each)
    reg [19:0] shift_reg;
    
    // Shift register logic
    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= 20'h0;
        end else if (shift_enable) begin
            shift_reg <= {shift_reg[15:0], data_in};
        end
    end
    
    // Outputs
    assign data_out = shift_reg[19:16];    // Top 4 bits to next buffer
    assign shift_out = shift_enable;       // Pass shift enable to next buffer
    assign instruction = shift_reg;        // Current 20-bit instruction
    
endmodule