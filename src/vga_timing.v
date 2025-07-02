/*
    Generates the timing signals for a VGA display.
*/
module vga_timing(
    input wire clk,
    input wire rst_n,

    input wire enable,
    
    output wire hsync_pulse,
    output wire vsync_pulse,
    output wire hv_blank,
    output wire new_line,
    output wire new_frame
);
    // 640x480 @ 60Hz
    localparam H_ACTIVE = 640;
    localparam V_ACTIVE = 480;

    localparam H_TOTAL = 800; 
    localparam V_TOTAL = 525;

    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_PULSE = 96; 
    localparam H_BACK_PORCH = 48;
    localparam H_BLANK = H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_PULSE = 2; 
    localparam V_BACK_PORCH = 33; 
    localparam V_BLANK = V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    reg [9:0] h_counter;
    reg [9:0] v_counter; 

    always @(posedge clk) begin
        if (!rst_n || enable) begin
            h_counter <= 10'b0;
            v_counter <= 10'b0;        
        end else begin
            h_counter <= h_counter + 1;
            if (h_counter > H_TOTAL) begin
                h_counter <= 10'b0;
                v_counter <= v_counter + 1;
                if (v_counter > V_TOTAL) begin
                    v_counter <= 10'b0;
                end
            end
        end
    end

    assign horizontal_blank = (h_counter <= H_BLANK)? 1 : 0;
    assign vertical_blank = (v_counter <= V_BLANK)? 1 : 0;
    assign hsync_pulse = (h_counter > H_FRONT_PORCH && h_counter <= H_SYNC_PULSE + H_FRONT_PORCH)? 1 : 0; 
    assign vsync_pulse = (v_counter > V_FRONT_PORCH && v_counter <= V_SYNC_PULSE + V_FRONT_PORCH)? 1 : 0;
endmodule