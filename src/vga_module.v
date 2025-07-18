/*
 * VGA Display Module
 * Generates VGA timing signals for 640x480 @ 60Hz resolution
 * Takes RGB input from instruction decoder and drives VGA outputs
 */

module vga_module (
    input  wire       clk,        // 25MHz pixel clock
    input  wire       rst_n,      // Reset (active low)
    input  wire [7:0] rgb_in,     // 8-bit RGB input (RRRGGGBB)

    output wire       hsync,      // Horizontal sync
    output wire       vsync,      // Vertical sync
    output wire [2:0] red,        // Red output (3 bits)
    output wire [2:0] green,      // Green output (3 bits) 
    output wire [1:0] blue,       // Blue output (2 bits)
    output wire       pixel_req   // Request for next pixel
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
    
    // Sync and RGB output registers
    reg hsync_reg;
    reg vsync_reg;
    reg [2:0] red_reg;
    reg [2:0] green_reg;
    reg [1:0] blue_reg;
    
    // Display area flags
    wire h_display_area;
    wire v_display_area;
    wire display_area;
    
    // Assign outputs
    assign hsync = hsync_reg;
    assign vsync = vsync_reg;
    assign red = red_reg;
    assign green = green_reg;
    assign blue = blue_reg;
    
    // Determine if in display area
    assign h_display_area = (h_counter < H_DISPLAY); 
    assign v_display_area = (v_counter < V_DISPLAY);
    assign display_area = h_display_area && v_display_area;
    
    // Pixel request: assert when in the display area
    assign pixel_req = display_area;
    
    // Main VGA logic - single always block
    always @(posedge clk) begin
        if (!rst_n) begin
            h_counter <= H_DISPLAY; // Start in blanking area to sync with the display
            v_counter <= V_DISPLAY;
            hsync_reg <= 1'b1;
            vsync_reg <= 1'b1;
            red_reg <= 3'b0;
            green_reg <= 3'b0;
            blue_reg <= 2'b0;
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
            
            // RGB output logic
            if (display_area) begin 
                // Extract RGB components from 8-bit input (RRRGGGBB)
                red_reg <= rgb_in[7:5];    // Bits [7:5] = Red
                green_reg <= rgb_in[4:2];  // Bits [4:2] = Green  
                blue_reg <= rgb_in[1:0];   // Bits [1:0] = Blue
            end else begin
                // Output black when not in display area or no valid data
                red_reg <= 3'b0;
                green_reg <= 3'b0;
                blue_reg <= 2'b0;
            end
        end
    end

endmodule