module qspi(
    input clk,
    input rst_n,

    input [1:0] spi_latency,
    
    output spi_clk,
    output spi_di,
    output spi_hold_n,
    input [3:0] spi_inputs,
    output reg [3:0] io_direction,
    output cs_n,

    input shift_data,
    input stop_read,
    output data_ready,
    output [19:0] data_out
);

/* STATE DEFINITIONS */
localparam STATE_START = 0; // 00
localparam STATE_DUMMY = 1; // 01
localparam STATE_RUN = 2;   // 10
localparam STATE_IDLE = 3;  // 11

// Internal Controls
reg [4:0] shift_count;
reg [1:0] fsm_state;
reg cs_n_reg;

// Internal Registers
reg spi_di_out;
reg [19:0] data_out_reg;

reg [3:0] miso;

always @(posedge clk) begin
    if(!rst_n) begin
        fsm_state <= STATE_IDLE;
        shift_count <= '0;
        io_direction <= 4'b0000;
        cs_n_reg <= 1'b1;  // CS inactive on reset
        data_out_reg <= 20'b0;
    end
    else begin
        // startup sequence: pass opcode/mode
        if (fsm_state == STATE_IDLE) begin
            cs_n_reg <= 1'b1;  // CS inactive in idle
            if(shift_data && !stop_read) begin
                io_direction <= 4'b0111;
                fsm_state <= STATE_START;
                cs_n_reg <= 1'b0;  // Activate CS when starting
                shift_count <= '0;
            end
        end
        else if (fsm_state == STATE_START) begin
            cs_n_reg <= 1'b0;  // Keep CS active
            io_direction <= 4'b0111;
            case(shift_count[2:0])
                // pass in the code 6Bh (0110 1011)
                3'b000: spi_di_out <= 0;
                3'b001: spi_di_out <= 1;
                3'b010: spi_di_out <= 1;
                3'b011: spi_di_out <= 0;
                3'b100: spi_di_out <= 1;
                3'b101: spi_di_out <= 0;
                3'b110: spi_di_out <= 1;
                3'b111: spi_di_out <= 1;           
                default: spi_di_out <= 0;
            endcase
            
            if(shift_count[2:0] == 3'b111) begin 
                fsm_state <= STATE_DUMMY;
                shift_count <= '0;
            end
            else begin
                shift_count <= shift_count + 1;
            end
            
            // Check for stop condition
            if(stop_read) begin
                fsm_state <= STATE_IDLE;
                cs_n_reg <= 1'b1;
            end
        end
        // startup sequence: wait 32 dummy cycles
        else if (fsm_state == STATE_DUMMY) begin
            cs_n_reg <= 1'b0;  // Keep CS active
            io_direction <= 4'b0101;
            if(shift_count == 5'd31) begin 
                fsm_state <= STATE_RUN;
                shift_count <= '0;
            end
            else begin
                shift_count <= shift_count + 1;
            end
            
            // Check for stop condition
            if(stop_read) begin
                fsm_state <= STATE_IDLE;
                cs_n_reg <= 1'b1;
            end
        end

        // should take a total of 40 cycles to get to this point since enabling CS
        else if(fsm_state == STATE_RUN) begin
            cs_n_reg <= 1'b0;  // Keep CS active during run
            
            if(shift_count < 5) begin
                io_direction <= 4'b0101;
                // we take 20 bits of data, so we expect it should take 5 cycles to read 1 instruction
                miso <= spi_inputs;
                data_out_reg <= {data_out_reg[15:0], miso};
                shift_count <= shift_count + 1;
            end
            else begin
                if(shift_data && !stop_read) begin
                    shift_count <= '0;
                end
                else begin
                    // hold
                    io_direction <= 4'b1101;
                end
            end
            
            // Check for stop condition - this can happen any time
            if(stop_read) begin
                fsm_state <= STATE_IDLE;
                cs_n_reg <= 1'b1;
            end
        end
    end 
end

assign cs_n = cs_n_reg;
assign spi_clk = !clk;
assign spi_di = (fsm_state == STATE_START) ? spi_di_out : 1'b0;
assign spi_hold_n = (fsm_state == STATE_START || fsm_state == STATE_IDLE) ? 1'b1 : 
                    ((fsm_state == STATE_RUN && shift_data) ? 1'b1 : 1'b0);
assign data_ready = (fsm_state == STATE_RUN && shift_count >= 5) ? 1'b1 : 1'b0;
assign data_out = data_out_reg;

wire _unused = &{spi_latency};

endmodule