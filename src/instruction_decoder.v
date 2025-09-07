/*
 * Instruction Decoder Module
 * Decodes 18-bit RLE instruciton and outputs the RGB values for VGA display 
 * Format: [17:8] Run length (10 bits), [7:0] RGB colour (RRRGGGBB)
 */

module instruction_decoder (
    input  wire         clk,           // Clock
    input  wire         rst_n,         // Reset (active low)
    input  wire [17:0]  instruction,   // Only need 18 bits for instruction
    input  wire         pixel_req,     // Request for next pixel from VGA
    input  wire         mixed_region,  // Region where audio and colour can be buffered together

    output wire         cont_shift,
    output wire [2:0]   red,            // Red output (3 bits)
    output wire [2:0]   green,          // Green output (3 bits) 
    output wire [1:0]   blue,           // Blue output (2 bits)
    output wire         stop_detected,
    output wire [7:0]   pwm_sample
);

    // Internal registers
    reg [9:0] run_length;     // Current run length (10 bits)
    reg [9:0] run_counter;    // Counter for current run
    reg        have_data;     // Flag indicating we have valid data to output
    reg [7:0] pwm_sample_reg;

    assign pwm_sample = pwm_sample_reg;
    assign cont_shift = !have_data; // Shift if does not have data

    // RGB output registers
    reg [2:0] red_reg;
    reg [2:0] green_reg;
    reg [1:0] blue_reg;

    assign red = red_reg;
    assign green = green_reg;
    assign blue = blue_reg;

    // Stop detection register
    reg stop_detected_reg;
    assign stop_detected = stop_detected_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            run_length <= 10'b0;
            run_counter <= 10'b0;
            have_data <= 1'b0;
            red_reg <= 3'b0;
            green_reg <= 3'b0;
            blue_reg <= 2'b0;
            stop_detected_reg <= 1'b0;
            pwm_sample_reg <= 8'b0;
        end else begin
            // Default Behaviour
            run_length  <= instruction[17:8];   // Extract run length from instruction register (outside module)
            run_counter <= 10'b0;               // Reset counter
            have_data   <= 1'b1;                // Mark that we have data to output
            if (instruction == 18'h30000) begin   // If stop code is the next instruction
                stop_detected_reg <= 1'b1;
            end else begin
                stop_detected_reg <= 1'b0;
                if (instruction >= 18'h3FF00) begin // Audio data
                    pwm_sample_reg <= instruction[7:0];
                    run_counter <= run_counter + 1;             // Increment run counter 
                    if ((run_counter == 157 && mixed_region) || run_counter == 799 ) begin                 // Make sure that new data isn't loaded too quickly
                        have_data <= 1'b0;                      // Mark that we need new data instead
                        run_counter <= 10'b0;                   // Reset run counter
                    end
                end 
            end

            // Output pixel when requesting pixels and we have data
            if (pixel_req && have_data) begin
                run_counter <= run_counter + 1;         // Increment run counter instead 
                if (run_counter + 2 == run_length) begin    // If run is complete
                    have_data <= 1'b0;                      // Mark that we need new data instead
                end
            end

            // The reason why we do run_counter + 2 is because:
            // 1. Outputting a pixel has 1 clock cycle delay because of the FF logic
            //    This causes the first pixel to be outputed when run_counter is 1
            // 2. Shifting data also has 1 clock cycle delay beacuse of the FF logic too
            // So we trigger the shift flag 2 cycles before the run is complete
            // This accounts for the both the delay from outputting and shifting the data

            // RGB output logic
            if (pixel_req) begin    // If pixel requested
                red_reg <= instruction[7:5];    // Bits [7:5] = Red
                green_reg <= instruction[4:2];  // Bits [4:2] = Green  
                blue_reg <= instruction[1:0];   // Bits [1:0] = Blue
            end else begin          // If pixel not requested, output black
                red_reg <= 3'b0;
                green_reg <= 3'b0;
                blue_reg <= 2'b0;
            end
        end
    end

endmodule