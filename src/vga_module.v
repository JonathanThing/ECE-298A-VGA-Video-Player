/*
 * VGA 640x480 Display Module
 * Generates VGA timing signals and outputs RGB data
 * 25.175 MHz pixel clock required for 60Hz refresh rate
 */

module vga_module (
    input  wire        clk,          // 25.175 MHz pixel clock
    input  wire        rst_n,
    input  wire [8:0]  color_in,     // 9-bit color input (RRRGGGBBB)
    input  wire        color_valid,  // High when color input is valid
    
    // VGA outputs
    output reg         hsync,        // Horizontal sync
    output reg         vsync,        // Vertical sync
    output reg [2:0]   red,          // 3-bit red output
    output reg [2:0]   green,        // 3-bit green output
    output reg [2:0]   blue,         // 3-bit blue output
    output wire        pixel_clock,  // Pixel clock output for decoder
    output wire        display_active // High during active display area
);

    // VGA 640x480 @ 60Hz timing parameters
    // Horizontal timing (pixels)
    localparam H_DISPLAY   = 640;   // Active display width
    localparam H_FRONT     = 16;    // Front porch
    localparam H_SYNC      = 96;    // Sync pulse width
    localparam H_BACK      = 48;    // Back porch
    localparam H_TOTAL     = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 800
    
    // Vertical timing (lines)
    localparam V_DISPLAY   = 480;   // Active display height
    localparam V_FRONT     = 10;    // Front porch
    localparam V_SYNC      = 2;     // Sync pulse width
    localparam V_BACK      = 33;    // Back porch
    localparam V_TOTAL     = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 525
    
    // Counters
    reg [9:0] h_count;  // Horizontal pixel counter (0-799)
    reg [9:0] v_count;  // Vertical line counter (0-524)
    
    // Timing signals
    wire h_display_active;
    wire v_display_active;
    wire h_sync_pulse;
    wire v_sync_pulse;
    
    // Display active area detection
    assign h_display_active = (h_count < H_DISPLAY);
    assign v_display_active = (v_count < V_DISPLAY);
    assign display_active = h_display_active && v_display_active;
    
    // Sync pulse generation
    assign h_sync_pulse = (h_count >= (H_DISPLAY + H_FRONT)) && 
                         (h_count < (H_DISPLAY + H_FRONT + H_SYNC));
    assign v_sync_pulse = (v_count >= (V_DISPLAY + V_FRONT)) && 
                         (v_count < (V_DISPLAY + V_FRONT + V_SYNC));
    
    // Pixel clock output (same as input clock for decoder timing)
    assign pixel_clock = clk && display_active;
    
    // Horizontal counter
    always @(posedge clk) begin
        if (!rst_n) begin
            h_count <= 10'h0;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= 10'h0;
        end else begin
            h_count <= h_count + 1;
        end
    end
    
    // Vertical counter
    always @(posedge clk) begin
        if (!rst_n) begin
            v_count <= 10'h0;
        end else if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1) begin
                v_count <= 10'h0;
            end else begin
                v_count <= v_count + 1;
            end
        end
    end
    
    // Sync signal generation
    always @(posedge clk) begin
        if (!rst_n) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            hsync <= ~h_sync_pulse;  // VGA hsync is active low
            vsync <= ~v_sync_pulse;  // VGA vsync is active low
        end
    end
    
    // RGB output generation
    always @(posedge clk) begin
        if (!rst_n) begin
            red <= 3'h0;
            green <= 3'h0;
            blue <= 3'h0;
        end else if (display_active && color_valid) begin
            // Extract RGB from 9-bit color input (RRRGGGBBB)
            red <= color_in[8:6];    // Bits [8:6] = red
            green <= color_in[5:3];  // Bits [5:3] = green
            blue <= color_in[2:0];   // Bits [2:0] = blue
        end else begin
            // Output black during blanking periods
            red <= 3'h0;
            green <= 3'h0;
            blue <= 3'h0;
        end
    end

endmodule