/*
 * 20-bit Instruction Buffer
 * Shifts in 4 bits at a time and outputs complete 20-bit instructions
 * Provides valid signal when a complete instruction is ready
 */

module instruction_buffer (
    input  wire        clk,         // Clock
    input  wire        rst_n,       // Reset (active low)
    input  wire        shift_en,    // Enable shifting in new data
    input  wire [19:0] data_in,     // 20-bit data input (upper 4 bits used)
    input  wire        prev_empty,
    
    output wire [19:0] instruction, // 20-bit instruction output
    output wire        valid        // High when instruction is complete and valid
);

    // Internal registers
    reg [19:0] shift_reg;    // 20-bit shift register
    reg [2:0]  bit_count;    // Count of 4-bit nibbles received (0-4)
    reg        valid_reg;    // Valid flag register
    
    // Output assignments
    assign instruction = shift_reg;
    assign valid = valid_reg;
    
    // Main logic
    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= 20'b0;
            bit_count <= 3'b0;
            valid_reg <= 1'b0;
        end else begin
            if (shift_en) begin
                // Shift in upper 4 bits (MSB first)
                shift_reg <= {shift_reg[15:0], data_in[19:16]};
                
                // Update bit count only when previous was not empty
                if (!prev_empty) begin
                    if (bit_count == 3'd4) begin
                        bit_count <= 3'b0;         // Reset counter after 5 nibbles (20 bits)
                        valid_reg <= 1'b1;         // Signal that instruction is complete
                    end else begin
                        bit_count <= bit_count + 1;
                        valid_reg <= 1'b0;         // Clear valid while receiving
                    end
                end
            end else begin
                // Hold valid for one cycle, then clear
                if (valid_reg) begin
                    valid_reg <= 1'b0;
                end
            end
        end
    end

endmodule