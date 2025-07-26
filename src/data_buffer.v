/*
 * A 18-bit Data Buffer
 */

module data_buffer (
    input  wire         clk,            // Clock
    input  wire         rst_n,          // Reset (active low)
    input  wire         shift_data,     // Shift data 
    input  wire         prev_empty,     // 1 is previous buffer is empty, 0 is not empty
    input  wire [17:0]  data_in,        // Input Data

    output wire         empty,          // 1 is this buffer is empty
    output wire [17:0]  data_out        // Output
);

    // Internal registers
    reg [17:0] buf_reg;    // 18-bit shift register
    reg        empty_reg;    // Valid flag register

    // Output assignments
    assign data_out = buf_reg;
    assign empty = empty_reg;

    // Main logic
    always @(posedge clk) begin
        if (!rst_n) begin
            buf_reg <= 18'b0;
            empty_reg <= 1'b1;
        end else begin
            if (shift_data | empty_reg) begin           // Shift Data is requested
                if (prev_empty) begin                   // If previous is empty
                    buf_reg <= 18'b0;
                    empty_reg <= 1'b1;
                end else begin                          // If previous is not empty
                    buf_reg <= data_in[17:0]; 
                    empty_reg <= 1'b0;
                end
            end
        end
    end

endmodule