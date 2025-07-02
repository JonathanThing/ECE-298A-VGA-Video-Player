module vga_unit (
    input wire clk,
    input wire rst_n,

    input wire enable,

    input [8:0] colour_in, // rrrgggbbb
    
    output [9:0] x_pos, // debugging
    output [9:0] y_pos, // debugging

    output wire vsync,
    output wire hsync,

    output [8:0] colour_out, // rrrgggbbb
    output blank,

    output next_frame,
    output next_line
);

// Macros
localparam [1:0] V_ACTIVE = 2'b00;  // 0
localparam [1:0] V_FP = 2'b01;      // 1    
localparam [1:0] V_PULSE = 2'b10;   // 2
localparam [1:0] V_BP = 2'b11;      // 3

localparam [1:0] H_ACTIVE = 2'b00;  // 0
localparam [1:0] H_FP = 2'b01;      // 1    
localparam [1:0] H_PULSE = 2'b10;   // 2
localparam [1:0] H_BP = 2'b11;      // 3

localparam [9:0] V_ACTIVE_COUNT = 640;  
localparam [9:0] V_FP_COUNT = 16;        
localparam [9:0] V_PULSE_COUNT = 96;   
localparam [9:0] V_BP_COUNT = 48;    

localparam [9:0] H_ACTIVE_COUNT = 480;  
localparam [9:0] H_FP_COUNT = 10;        
localparam [9:0] H_PULSE_COUNT = 2;   
localparam [9:0] H_BP_COUNT = 33;   

// Control
reg [1:0] v_state
reg [1:0] h_state

reg [9:0] v_counter;
reg [9:0] h_counter;

reg next_line;

reg vsync_reg;
reg hsync_reg;

// Logic Section
always @(posedge clk) begin
    if (!rst_n || enable) begin
        v_counter <= '0;
        h_counter <= '0;

        v_state <= V_ACTIVE;
        h_state <= H_ACTIVE;

        next_line <= '0;
    end

    else begin
        if(h_state == H_ACTIVE) begin
            h_counter <= (h_counter < (H_ACTIVE_COUNT - 1)) ? h_counter + 1 : '0;
            h_state <= (h_counter < (H_ACTIVE_COUNT - 1)) ? H_ACTIVE : H_FP;

            hsync_reg <= 1;
            next_line <= 0;
        end

        if(h_state == H_FP) begin
            h_counter <= (h_counter < (H_FP_COUNT - 1)) ? h_counter + 1 : '0;
            h_state <= (h_counter < (H_FP_COUNT - 1)) ? H_FP : H_PULSE;

            hsync_reg <= 1;
        end

        if(h_state == H_PULSE) begin
            h_counter <= (h_counter < (H_PULSE_COUNT - 1)) ? h_counter + 1 : '0;
            h_state <= (h_counter < (H_PULSE_COUNT - 1)) ? H_PULSE : H_BP;

            hsync_reg <= 0;
        end

        if(h_state == H_BP) begin
            h_counter <= (h_counter < (H_BP_COUNT - 1)) ? h_counter + 1 : '0;
            h_state <= (h_counter < (H_BP_COUNT - 1)) ? H_BP : H_ACTIVE;

            hsync_reg <= 1;

            next_line <= (h_counter == (H_BP_COUNT - 2)) ? 1 : 0;
        end

        // only edit vertical states if next line requested
        if(next_line) begin
            if(v_state == V_ACTIVE) begin
                // only increment vertical counter if next line requested
                // if will exceed active region, reset the counter
                v_counter <= (v_counter < (V_ACTIVE_COUNT - 1)) ? v_counter + 1 : '0;

                // if will exceed active region, progress to next state
                v_state <= (v_counter < (V_ACTIVE_COUNT - 1)) ? V_ACTIVE : V_FP; 

                vsync_reg <= 1;
            end

            if(v_state == V_FP) begin
                // if will exceed front porch region, reset the counter
                v_counter <= (v_counter < (V_FP_COUNT - 1)) ? v_counter + 1 : '0;

                // if will exceed region, progress to next state
                v_state <= (v_counter < (V_FP_COUNT - 1)) ? V_FP : V_PULSE; 

                vsync_reg <= 1;
            end

            if(v_state == V_PULSE) begin
                // if will exceed pulse region, reset the counter
                v_counter <= (v_counter < (V_PULSE_COUNT - 1)) ? v_counter + 1 : '0;

                // if will exceed region, progress to next state
                v_state <= (v_counter < (V_PULSE_COUNT - 1)) ? V_PULSE : V_BP; 
                
                vsync_reg <= 0;
            end

            if(v_state == V_BP) begin
                // if will exceed back porch region, reset the counter
                v_counter <= (v_counter < (V_BP_COUNT - 1)) ? v_counter + 1 : '0;

                // if will exceed region, progress to next state
                v_state <= (v_counter < (V_BP_COUNT - 1)) ? V_BP : V_ACTIVE; 
                
                vsync_reg <= 1;
            end
        end
    end
end

assign colour_out = (v_state == V_ACTIVE) ? ((h_state == H_ACTIVE) ? colour_in : '0) : '0;
assign vsync = vsync_reg;
assign hsync = hsync_reg;
assign blank = (v_state == V_FP || v_state == V_PULSE || v_state == V_BP) ? 1 : ((h_state == H_FP || h_state == H_PULSE || h_state == H_BP) ? 1 : 0)

assign x_pos = (h_state == H_ACTIVE) ? h_counter : '0;
assign y_pos = (v_state == V_ACTIVE) ? v_counter : '0;

assign next_frame = v_counter == (V_BP_COUNT - 1);
assign next_line = h_counter == (H_BP_COUNT - 1);
endmodule