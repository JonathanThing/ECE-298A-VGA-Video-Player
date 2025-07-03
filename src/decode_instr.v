/*
 * Instruction Decoder for VGA RLE Display
 * Decodes 20-bit RLE instructions and outputs color for run length duration
 * Format: [19:9] run length (11 bits), [8:0] color RRRGGGBBB (9 bits)
 * Keeps outputting the same color for the specified run length
 */

module decode_instr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [19:0] instruction,      // 20-bit RLE instruction
    input  wire        instruction_valid, // Pulse when new instruction arrives
    input  wire        pixel_clock,      // Pixel clock from VGA (request next pixel)
    output reg [8:0]   color_out,        // 9-bit color output (RRRGGGBBB)
    output reg         need_next_instr,  // High when current run is complete
    output reg         color_valid       // High when color output is valid
);

    // Internal registers
    reg [10:0] run_counter;     // Counts down from run_length to 0
    reg [8:0]  current_color;   // Current color being output
    reg        run_active;      // High when we're in the middle of a run
    
    // Main logic
    always @(posedge clk) begin
        if (!rst_n) begin
            run_counter <= 11'h0;
            current_color <= 9'h0;
            color_out <= 9'h0;
            need_next_instr <= 1'b1;  // Need instruction to start
            color_valid <= 1'b0;
            run_active <= 1'b0;
        end else begin
            
            // Load new instruction when it arrives
            if (instruction_valid) begin
                run_counter <= instruction[19:9];     // Load run length
                current_color <= instruction[8:0];    // Load color
                color_out <= instruction[8:0];        // Output color immediately
                color_valid <= 1'b1;
                need_next_instr <= 1'b0;
                run_active <= 1'b1;
            end
            
            // Count down on each pixel clock
            else if (pixel_clock && run_active) begin
                if (run_counter == 11'h0) begin
                    // Run complete - need next instruction
                    need_next_instr <= 1'b1;
                    color_valid <= 1'b0;
                    run_active <= 1'b0;
                end else begin
                    // Continue run - decrement counter, keep color
                    run_counter <= run_counter - 1;
                    color_out <= current_color;
                    color_valid <= 1'b1;
                end
            end
            
            // Keep outputting current color when not pixel_clock
            else if (run_active) begin
                color_out <= current_color;
                color_valid <= 1'b1;
            end
        end
    end

endmodule