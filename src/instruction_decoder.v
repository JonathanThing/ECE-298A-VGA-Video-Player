/*
 * Instruction Decoder Module
 * Decodes 20-bit instructions into run-length encoded RGB data
 * Format: [17:8] Run length (10 bits), [7:0] RGB color (RRRGGGBB)
 */

module instruction_decoder (
    input  wire         clk,           // Clock
    input  wire         rst_n,         // Reset (active low)
    input  wire [17:0]  instruction,   // Only need 18 bits for instruction
    //input  wire         instr_valid,   // High when instruction is valid
    input  wire         pixel_req,     // Request for next pixel from VGA
    
    output wire         cont_shift,
    output wire [2:0]   red,        // Red output (3 bits)
    output wire [2:0]   green,      // Green output (3 bits) 
    output wire [1:0]   blue      // Blue output (2 bits)
);

    // Internal registers
    reg [9:0] run_length;     // Current run length (10 bits)
    reg [9:0] run_counter;    // Counter for current run
    //reg [7:0]  current_rgb;    // Current RGB value
    reg        have_data;      // Flag indicating we have valid data to output

    reg [2:0] red_reg;
    reg [2:0] green_reg;
    reg [1:0] blue_reg;

    assign cont_shift = !have_data;

    assign red = red_reg;
    assign green = green_reg;
    assign blue = blue_reg;

    // Main decoder logic - single always block
    always @(posedge clk) begin
        if (!rst_n) begin
            run_length <= 10'b0;
            run_counter <= 10'b0;
            have_data <= 1'b0;
            red_reg <= 3'b0;
            green_reg <= 3'b0;
            blue_reg <= 2'b0;
        end else begin
            // Load new instruction
            // if (instr_valid && !have_data) begin
                run_length  <= instruction[17:8];   // Extract run length
                run_counter <= 10'b0;              // Reset counter
                have_data   <= 1'b1;            
            // end
            
            // Output pixel when requested and we have data
            if (pixel_req && have_data) begin
                // Check if run is complete
                if (run_counter+2 == run_length) begin
                    have_data <= 1'b0;             // Mark that we need new data
                end else begin
                    run_counter <= run_counter + 1;    // Increment run counter 
                end
            end
         
            // RGB output logic
            if (pixel_req) begin 
                // Extract RGB components from 8-bit input (RRRGGGBB)
                red_reg <= instruction[7:5];    // Bits [7:5] = Red
                green_reg <= instruction[4:2];  // Bits [4:2] = Green  
                blue_reg <= instruction[1:0];   // Bits [1:0] = Blue
            end else begin
                // Output black when not in display area or no valid data
                red_reg <= 3'b0;
                green_reg <= 3'b0;
                blue_reg <= 2'b0;
            end
        end
    end

endmodule