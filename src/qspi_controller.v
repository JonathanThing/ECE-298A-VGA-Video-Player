/*
 * QSPI Module
 * Continuously reads 20-bit instructions from SPI flash
 */

module qspi_controller (
    input  wire        clk,        // 25MHz pixel clock
    input  wire        rst_n,      // Reset (active low)
    
    // SPI Flash interface
    output wire        spi_clk,    // SPI clock = !clk
    output wire        spi_cs_n,   // Chip select (active low)
    output wire        spi_di,     // DI (data input to flash) - IO0
    output wire        spi_hold_n,   // HOLD (We have to hold it high during setup)

    input  wire        spi_io0,    // IO0 (for quad read)
    input  wire        spi_io1,     // DO (data output from flash) - IO1
    input  wire        spi_io2,    // IO2
    input  wire        spi_io3     // IO3/HOLD
    
    // Output interface
    output wire [19:0] instruction, // 20-bit instruction output
    output wire        spi_cs_oe,
    output wire        spi_di_oe,
    output wire        spi_sclk_oe,
    output wire        spi_hold_n_oe,
    output wire        valid,       // High when instruction is valid

    output wire        active       // whether the spi is active
);

    // State machine states
    localparam IDLE         = 3'b000;
    localparam SEND_CMD     = 3'b001;
    localparam DUMMY_CYCLES = 3'b010;
    localparam READ_DATA    = 3'b011;

    // Internal signals
    reg [2:0]  state;
    reg [7:0]  bit_counter;
    reg [19:0] instruction_reg;
    reg        valid_reg;
    reg        cs_n_reg;
    reg        di_reg;
    reg [3:0]  oe_sig;      // 1 for output; 0 for input
    
    wire [3:0] io_in_data;
    
    // SPI clock is inverted system clock
    assign spi_clk = !clk;
    assign spi_cs_n = cs_n_reg;
    assign spi_di = di_reg;
    
    // Quad data input (IO3, IO2, IO1/DO, IO0)
    assign io_in_data = {spi_io3, spi_io2, spi_io1, spi_io0};
    
    // Output assignments
    assign instruction = instruction_reg;
    assign valid = valid_reg;
    assign spi_cs_oe = oe_sig[0];
    assign spi_di_oe = oe_sig[1];
    assign spi_sclk_oe = oe_sig[2];
    assign spi_hold_n_oe = oe_sig[3];

    assign active = (state == READ_DATA) ? 1 : 0;
    
    // Main state machine
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_counter <= 8'b0;
            instruction_reg <= 20'b0;
            valid_reg <= 1'b0;
            cs_n_reg <= 1'b1;
            di_reg <= 1'b0;
            oe_sig <= 4'b0000;
        end else begin
            case (state)
                IDLE: begin
                    oe_sig <= 4'b1111;
                    cs_n_reg <= 1'b0;          // Assert chip select
                    bit_counter <= 8'b0;
                    valid_reg <= 1'b0;
                    di_reg <= 1'b0;
                    state <= SEND_CMD;
                end
                
                SEND_CMD: begin
                    // Send 8-bit command (6Bh = 01100011) on DI, MSB first
                    case (bit_counter)
                        0: di_reg <= 1'b0;  // bit 7
                        1: di_reg <= 1'b1;  // bit 6
                        2: di_reg <= 1'b1;  // bit 5
                        3: di_reg <= 1'b0;  // bit 4
                        4: di_reg <= 1'b1;  // bit 3
                        5: di_reg <= 1'b0;  // bit 2
                        6: di_reg <= 1'b1;  // bit 1
                        7: di_reg <= 1'b1;  // bit 0
                        default: di_reg <= 1'b0;
                    endcase
                    
                    bit_counter <= bit_counter + 1;
                    if (bit_counter == 7) begin  // 8 bits sent in 8 cycles
                        state <= DUMMY_CYCLES;
                        bit_counter <= 8'b0;
                        di_reg <= 1'b0;
                    end
                end
                
                DUMMY_CYCLES: begin
                    // Wait for dummy cycles (32 dummy clocks as per datasheet)
                    bit_counter <= bit_counter + 1;
                    if (bit_counter == 31) begin  // 32 dummy cycles
                        oe_sig <= 4'b0101;
                        state <= READ_DATA;
                        bit_counter <= 8'b0;
                    end
                end
                
                READ_DATA: begin
                    // Read 20 bits of data (5 cycles of 4 bits each)
                    instruction_reg <= {instruction_reg[15:0], io_in_data};
                    bit_counter <= bit_counter + 1;
                    
                    if (bit_counter == 4) begin  // 20 bits received (5 cycles)
                        valid_reg <= 1'b1;
                        bit_counter <= 8'b0;
                        // Continue reading next instruction
                        // In sequential mode, we just keep reading
                    end else begin
                        valid_reg <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    oe_sig <= 4'b1101;
                end
            endcase
        end
    end

endmodule