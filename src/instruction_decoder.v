/*
 * Instruction Decoder Module
 * Decodes 20-bit instructions into run-length encoded RGB data
 * Format: [18:8] Run length (11 bits), [7:0] RGB color (RRRGGGBB)
 */

module instruction_decoder (
    input  wire        clk,           // Clock
    input  wire        rst_n,         // Reset (active low)
    input  wire [18:0] instruction,   // Only need 19 bits for instruction
    input  wire        instr_valid,   // High when instruction is valid
    input  wire        pixel_req,     // Request for next pixel from VGA
    
    output wire [7:0]  rgb_out,       // 8-bit RGB output (RRRGGGBB)
    output wire        rgb_valid,      // High when RGB output is valid
    output wire        cont_shift
);

    // Internal registers
    reg [9:0] run_length;     // Current run length (11 bits: 0-2047)               TODO: Change run length to 10 bits as
    reg [9:0] run_counter;    // Counter for current run
    reg [7:0]  current_rgb;    // Current RGB value
    reg        rgb_valid_reg;  // RGB valid flag
    reg        have_data;      // Flag indicating we have valid data to output

    // Output assignments
    assign rgb_out = current_rgb;
    assign rgb_valid = rgb_valid_reg;
    assign cont_shift = !have_data;

    // Main decoder logic - single always block
    always @(posedge clk) begin
        if (!rst_n) begin
            run_length <= 10'b0;
            run_counter <= 10'b0;
            current_rgb <= 8'b0;
            rgb_valid_reg <= 1'b0;
            have_data <= 1'b0;
        end else begin
            // Default: clear valid signal
            rgb_valid_reg <= 1'b0;
            
            // Load new instruction
            if (instr_valid) begin
                run_length <= instruction[18:8];   // Extract run length
                current_rgb <= instruction[7:0];   // Extract RGB color
                run_counter <= 10'b0;              // Reset counter
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