/*
 * SPI Flash Reader Module for 6Bh Fast Read Quad Output
 * Sequential Read Mode Only (Figure 21b)
 * Continuous reading of 20-bit instructions from Winbond flash memory
 * Simplified single-edge approach
 */

module spi_flash_reader (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_sequence,  // Pulse to start sequential read mode
    input  wire        read_enable,     // High to continuously read, low to pause
    input  wire        end_sequence,    // Pulse to end sequential read and raise CS
    
    // SPI Interface (matching your pin mapping)
    output reg         spi_cs_n,        // Chip select (active low)
    output reg         spi_clk,         // SPI clock
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
    localparam INIT_DUMMY = 2'h1;       // Initial dummy cycles
    localparam CONTINUOUS_READ = 2'h2;   // Continuous reading mode
    
    reg [1:0] state;
    
    // Internal registers
    reg [6:0] cycle_counter;    // Counts cycles (dummy + data)
    reg [2:0] bit_counter;      // Counts quad cycles for 20 bits
    reg [19:0] data_shift_reg;
    reg sequential_active;      // Flag to indicate we're in sequential mode
    // Use inverted clock for SPI - much simpler!
    
    // Main logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            spi_cs_n <= 1'b1;
            spi_clk <= 1'b0;
            spi_quad_out <= 4'h0;
            spi_quad_oe <= 4'h0;
            cycle_counter <= 7'd0;
            bit_counter <= 3'd0;
            data_shift_reg <= 20'h0;
            instruction <= 20'h0;
            data_valid <= 1'b0;
            busy <= 1'b0;
            sequential_active <= 1'b0;
        end else begin
            // Default assignments
            data_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    spi_clk <= 1'b0;
                    busy <= 1'b0;
                    
                    if (start_sequence) begin
                        state <= INIT_DUMMY;
                        spi_cs_n <= 1'b0;
                        sequential_active <= 1'b1;
                        spi_quad_oe <= 4'h0;  // All inputs
                        busy <= 1'b1;
                        cycle_counter <= 7'd0;
                        bit_counter <= 3'd0;
                    end else if (end_sequence) begin
                        spi_cs_n <= 1'b1;
                        sequential_active <= 1'b0;
                    end
                end
                
                INIT_DUMMY: begin
                    // Simple SPI clock generation and dummy cycle counting
                    spi_clk <= ~clk;  // Inverted main clock
                    
                    cycle_counter <= cycle_counter + 1;
                    if (cycle_counter >= 7'd31) begin  // 32 dummy cycles
                        state <= CONTINUOUS_READ;
                        cycle_counter <= 7'd0;
                        bit_counter <= 3'd0;
                    end
                end
                
                CONTINUOUS_READ: begin
                    if (end_sequence) begin
                        state <= IDLE;
                        spi_cs_n <= 1'b1;
                        sequential_active <= 1'b0;
                        busy <= 1'b0;
                        spi_clk <= 1'b0;
                    end else if (read_enable) begin
                        busy <= 1'b1;
                        spi_clk <= ~clk;  // Inverted main clock
                        
                        // Capture data on rising edge of main clock (falling edge of SPI clock)
                        data_shift_reg <= {data_shift_reg[15:0], spi_quad_in};
                        bit_counter <= bit_counter + 1;
                        
                        if (bit_counter == 3'd4) begin  // 5 quad cycles = 20 bits
                            bit_counter <= 3'd0;
                            instruction <= {data_shift_reg[15:0], spi_quad_in};
                            data_valid <= 1'b1;
                        end
                    end else begin
                        busy <= 1'b0;
                        spi_clk <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule