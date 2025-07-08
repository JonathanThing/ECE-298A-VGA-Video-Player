/*
 * 20-bit Instruction Buffer
 * Shifts in 4 bits at a time and outputs complete 20-bit instructions
 * Provides valid signal when a complete instruction is ready
 */

module data_buffer (
    input  wire        clk,         // Clock
    input  wire        rst_n,       // Reset (active low)
    input  wire        shift_en,    // Enable shifting in new data
    input  wire [18:0] data_in,     
    input  wire        prev_empty,
    
    output wire [18:0] instruction,
    output wire        valid        // High when instruction is complete and valid
);

    // Internal registers
    reg [18:0] shift_reg;    // 20-bit shift register
    reg [2:0]  bit_count;    // Count of 4-bit nibbles received (0-4)
    reg        valid_reg;    // Valid flag register
    
    // Output assignments
    assign instruction = shift_reg;
    assign valid = valid_reg;

    wire _unused = &{data_in[15:0]};
    
    // Main logic
    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= 19'b0;
            bit_count <= 3'b0;
            valid_reg <= 1'b0;
        end else begin
            if (shift_en) begin
                shift_reg <= data_in[18:0];
                
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