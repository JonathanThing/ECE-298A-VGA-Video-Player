/*
 * VGA Display Module
 * Generates VGA timing signals for 640x480 @ 60Hz resolution
 */

module vga_module (
    input  wire       clk,        
    input  wire       rst_n,      // Reset (active low)

    output wire       hsync,      // Horizontal sync
    output wire       vsync,      // Vertical sync
    output wire       pixel_req,  // Request for next pixel
    output wire       mixed_region  // Region where audio and colour can be buffered together
);

    // VGA timing parameters for 640x480 @ 60Hz with 25MHz clock
    localparam H_DISPLAY    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 800
    localparam H_PULSE_START = H_DISPLAY + H_FRONT; 
    localparam H_PULSE_END   = H_DISPLAY + H_FRONT + H_SYNC;

    localparam V_DISPLAY    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 525
    localparam V_PULSE_START = V_DISPLAY + V_FRONT;
    localparam V_PULSE_END   = V_DISPLAY + V_FRONT + V_SYNC;

    // Internal counters
    reg [9:0] h_counter;    // Horizontal counter (0-799)
    reg [9:0] v_counter;    // Vertical counter (0-524)
    
    // Sync output registers
    reg hsync_reg;
    reg vsync_reg;
    
    // Display area flags
    wire h_display_area;
    wire v_display_area;
    wire v_edge_case;
    wire h_edge_case;
    
    // Assign outputs
    assign hsync = hsync_reg;
    assign vsync = vsync_reg;
    
    // Determine if in display area
    assign h_display_area = (h_counter < H_DISPLAY - 1);
    assign v_display_area = (v_counter < V_DISPLAY);
    assign h_edge_case = (h_counter == H_TOTAL - 1) && (v_counter < V_DISPLAY - 1);  // The clock cycle before start of new line
    assign v_edge_case = (h_counter == H_TOTAL - 1) && (v_counter == V_TOTAL - 1);  // The clock cycle before start of frame

    // Pixel request: assert when in the display area
    assign pixel_req = h_display_area && v_display_area || v_edge_case || h_edge_case;

    assign mixed_region = (v_display_area && v_counter != 479) || v_counter == 524; // Region where audio and colour can be buffered together

    // Main VGA logic
    always @(posedge clk) begin
        if (!rst_n) begin
            h_counter <= H_DISPLAY; // Start in blanking area to give time to fill the buffers and to sync
            v_counter <= V_DISPLAY;
            hsync_reg <= 1'b1;
            vsync_reg <= 1'b1;
        end else begin
            // Horizontal and vertical counters
            if (h_counter == H_TOTAL - 1) begin
                h_counter <= 10'b0;
                // Vertical counter
                if (v_counter == V_TOTAL - 1) begin
                    v_counter <= 10'b0;
                end else begin
                    v_counter <= v_counter + 1;
                end
            end else begin
                h_counter <= h_counter + 1;
            end
            
            // Sync signal generation
            // HSYNC: active low during sync period
            hsync_reg <= ~((h_counter >= H_PULSE_START) && 
                          (h_counter < H_PULSE_END));
            
            // VSYNC: active low during sync period  
            vsync_reg <= ~(v_counter >= (V_PULSE_START) && 
                          (v_counter < V_PULSE_END));
        end
    end

endmodule