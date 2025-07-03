/*
 * Instruction Decoder Module
 * Decodes 20-bit instructions into run-length encoded RGB data
 * Format: [19:9] Run length (11 bits), [8:0] RGB color (3 bits each: RRRGGGBBB)
 */

module instruction_decoder (
    input  wire        clk,           // Clock
    input  wire        rst_n,         // Reset (active low)
    input  wire [19:0] instruction,   // 20-bit instruction input
    input  wire        instr_valid,   // High when instruction is valid
    input  wire        pixel_req,     // Request for next pixel from VGA
    
    output wire [8:0]  rgb_out,       // 9-bit RGB output (RRRGGGBBB)
    output wire        rgb_valid      // High when RGB output is valid
);

    // Internal registers
    reg [10:0] run_length;     // Current run length (11 bits: 0-2047)
    reg [10:0] run_counter;    // Counter for current run
    reg [8:0]  current_rgb;    // Current RGB value
    reg        rgb_valid_reg;  // RGB valid flag
    reg        have_data;      // Flag indicating we have valid data to output

    // Output assignments
    assign rgb_out = current_rgb;
    assign rgb_valid = rgb_valid_reg;

    // Main decoder logic - single always block
    always @(posedge clk) begin
        if (!rst_n) begin
            run_length <= 11'b0;
            run_counter <= 11'b0;
            current_rgb <= 9'b0;
            rgb_valid_reg <= 1'b0;
            have_data <= 1'b0;
        end else begin
            // Default: clear valid signal
            rgb_valid_reg <= 1'b0;
            
            // Load new instruction
            if (instr_valid) begin
                run_length <= instruction[19:9];   // Extract run length
                current_rgb <= instruction[8:0];   // Extract RGB color
                run_counter <= 11'b0;              // Reset counter
                have_data <= 1'b1;                 // Mark that we have data
            end
            
            // Output pixel when requested and we have data
            if (pixel_req && have_data) begin
                rgb_valid_reg <= 1'b1;             // Assert valid output
                run_counter <= run_counter + 1;    // Increment run counter
                
                // Check if run is complete
                if (run_counter >= run_length) begin
                    have_data <= 1'b0;             // Mark that we need new data
                end
            end
        end
    end

endmodule