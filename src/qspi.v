/*
 * SPI Flash Reader Module for 6Bh Fast Read Quad Output
 * Sequential Read Mode Only (Figure 21b)
 * Continuous reading of 20-bit instructions from Winbond flash memory
 * Verilog-2001 compatible - only uses always @(posedge clk)
 */

module spi_flash_reader (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_sequence,  // Pulse to start sequential read mode
    input  wire        read_enable,     // High to continuously read, low to pause
    input  wire        end_sequence,    // Pulse to end sequential read and raise CS
    
    // SPI Interface (matching your pin mapping)
    output reg         spi_cs_n,        // Chip select (active low)
    output reg         spi_clk,         // SPI clock (1:1 with system clock)
    input  wire [3:0]  spi_quad_in,     // Quad input data (IO0-IO3)
    output reg [3:0]   spi_quad_out,    // Quad output data (unused in read mode)
    output reg [3:0]   spi_quad_oe,     // Quad output enable (all inputs for read)
    
    // Data Interface
    output reg [19:0]  instruction,     // 20-bit instruction output
    output reg         data_valid,      // Data valid flag (pulses high for one cycle)
    output reg         busy            // Module busy flag
);

    // State machine states
    localparam IDLE = 2'h0;
    localparam INIT_DUMMY = 2'h1;       // Initial 32 dummy cycles
    localparam CONTINUOUS_READ = 2'h2;   // Continuous reading mode
    
    reg [1:0] state, next_state;
    
    // Internal registers
    reg [5:0] dummy_counter;    // Counts initial 32 dummy cycles
    reg [2:0] bit_counter;      // Counts 5 quad cycles for 20 bits
    reg [19:0] data_shift_reg;
    reg sequential_active;      // Flag to indicate we're in sequential mode
    reg spi_clk_int;           // Internal SPI clock
    reg spi_clk_enable;        // Clock enable signal
    
    // All logic in single always block
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            next_state <= IDLE;
            spi_cs_n <= 1'b1;
            spi_clk <= 1'b0;
            spi_quad_out <= 4'h0;
            spi_quad_oe <= 4'h0;
            dummy_counter <= 6'd0;
            bit_counter <= 3'd0;
            data_shift_reg <= 20'h0;
            instruction <= 20'h0;
            data_valid <= 1'b0;
            busy <= 1'b0;
            sequential_active <= 1'b0;
            spi_clk_int <= 1'b0;
            spi_clk_enable <= 1'b0;
        end else begin
            // Toggle internal SPI clock
            spi_clk_int <= ~spi_clk_int;
            
            // Update state
            state <= next_state;
            
            // Next state logic
            case (state)
                IDLE: begin
                    if (start_sequence) next_state <= INIT_DUMMY;
                    else next_state <= IDLE;
                end
                INIT_DUMMY: begin
                    if (dummy_counter == 6'd31 && spi_clk_int == 1'b1) next_state <= CONTINUOUS_READ;
                    else next_state <= INIT_DUMMY;
                end
                CONTINUOUS_READ: begin
                    if (end_sequence) next_state <= IDLE;
                    else next_state <= CONTINUOUS_READ;
                end
                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // SPI clock enable logic
            if (state == INIT_DUMMY || (state == CONTINUOUS_READ && read_enable)) begin
                spi_clk_enable <= 1'b1;
            end else begin
                spi_clk_enable <= 1'b0;
            end
            
            // SPI clock output
            if (spi_clk_enable) begin
                spi_clk <= spi_clk_int;
            end else begin
                spi_clk <= 1'b0;
            end
            
            // Main control logic
            case (state)
                IDLE: begin
                    data_valid <= 1'b0;

                    // Startup sequence
                    if (start_sequence) begin
                        spi_cs_n <= 1'b0;
                        sequential_active <= 1'b1;
                        spi_quad_oe <= 4'h0;  // All inputs
                        busy <= 1'b1;
                        dummy_counter <= 6'd0;
                    end 
                    // End reading
                    else if (end_sequence) begin
                        spi_cs_n <= 1'b1;
                        sequential_active <= 1'b0;
                        busy <= 1'b0;
                    end 
                    // Idle state
                    else begin
                        if (!sequential_active) begin
                            spi_cs_n <= 1'b1;
                        end
                        busy <= 1'b0;
                    end
                end
                
                INIT_DUMMY: begin
                    // Initial 32 dummy cycles to start sequential read
                    if (spi_clk_int == 1'b1) begin  // Falling edge of SPI clock
                        if (dummy_counter == 6'd31) begin
                            dummy_counter <= 6'd0;
                            bit_counter <= 3'd0;
                        end else begin
                            dummy_counter <= dummy_counter + 1;
                        end
                    end
                end
                
                CONTINUOUS_READ: begin
                    data_valid <= 1'b0;  // Default to no new data
                    
                    if (read_enable) begin
                        busy <= 1'b1;
                        // Continuously read 20-bit instructions
                        if (spi_clk_int == 1'b0) begin  // Rising edge of SPI clock
                            // Capture 4 bits on each rising edge
                            data_shift_reg <= {data_shift_reg[15:0], spi_quad_in};
                        end else if (spi_clk_int == 1'b1) begin  // Falling edge of SPI clock
                            // Increment counter on falling edge
                            if (bit_counter == 3'd4) begin
                                // Completed 5 quad cycles (20 bits)
                                bit_counter <= 3'd0;
                                instruction <= {data_shift_reg[15:0], spi_quad_in};
                                data_valid <= 1'b1;  // Signal new data available
                            end else begin
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end else begin
                        busy <= 1'b0;
                        // Keep bit_counter where it is when paused
                    end
                    
                    if (end_sequence) begin
                        spi_cs_n <= 1'b1;
                        sequential_active <= 1'b0;
                        busy <= 1'b0;
                    end
                end
                
                default: begin
                    // Probably shouldn't ever get here idk
                end
            endcase
        end
    end
    
endmodule