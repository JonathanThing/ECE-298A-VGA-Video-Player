/*
 * QSPI FSM
 * FSM to control the Flash memory through QSPI
 */

module qspi_fsm (
    input  wire        clk,        // 25MHz pixel clock
    input  wire        rst_n,      // Reset (active low)
    
    // SPI Flash interface
    output wire        spi_clk,    // SPI clock = !clk
    output wire        spi_cs_n,   // Chip select (active low)
    output wire        spi_di,     // DI (data input to flash) - IO0
    output wire        spi_hold_n,   // HOLD (We have to hold it high during setup)

    // Input Wires
    input  wire        spi_io0,    // IO0 (for quad read)
    input  wire        spi_io1,     // DO (data output from flash) - IO1
    input  wire        spi_io2,    // IO2
    input  wire        spi_io3,     // IO3/HOLD
    input  wire        shift_data,  // Shift data through the buffers

    // Output interface
    output wire [17:0] instruction,        // 18-bit data output
    output wire        spi_cs_oe,
    output wire        spi_di_oe,
    output wire        spi_sclk_oe,
    output wire        spi_hold_n_oe,
    output wire        valid           // High when instruction is valid
);

    // State machine states
    localparam IDLE         = 3'b000;
    localparam SEND_CMD     = 3'b001;
    localparam DUMMY_CYCLES = 3'b010;
    localparam READ_DATA    = 3'b011;
    localparam WAIT_CONSUME = 3'b100;

    // Internal signals
    reg [2:0]  cur_state;
    reg [2:0]  next_state;
    reg [5:0]  bit_counter;
    reg [23:0] instruction_buf;

    reg        valid_reg;
    reg        cs_n_reg;
    reg        di_reg;      // Data Input value
    reg [3:0]  oe_sig;      // 1 for output; 0 for input
    reg        hold_n_reg;  // IO3 Hold register value      // Theoretically can omit
    reg        pause_sclk;   // Pause SCLK value
    
    wire [3:0] io_in_data;  

    // SPI clock is inverted system clock
    assign spi_clk = !clk & !pause_sclk;
    assign spi_cs_n = cs_n_reg;
    assign spi_di = di_reg;
    assign spi_hold_n = hold_n_reg;

    // Quad data input (IO3, IO2, IO1/DO, IO0)
    assign io_in_data = {spi_io3, spi_io2, spi_io1, spi_io0};
    
    // Output assignments
    assign instruction = instruction_buf[17:0];
    assign valid = valid_reg;
    assign spi_cs_oe = oe_sig[0];
    assign spi_di_oe = oe_sig[1];
    assign spi_sclk_oe = oe_sig[2];
    assign spi_hold_n_oe = oe_sig[3];

    // FSM next state sequential logic
    always @(posedge clk) begin
        if (!rst_n) begin
            cur_state <= IDLE;
        end else begin
            if (cur_state != next_state) begin  // Changing state, reset bit counter
                bit_counter <= 6'b0;
            end else if (next_state == READ_DATA && bit_counter == 5) begin      // If instruciton has been read, reset bit counter to read next
                bit_counter <= 6'b0;
            end
            cur_state <= next_state;
        end
    end

    // FSM next state combinational logic
    always @(*) begin
        next_state = cur_state;
        valid_reg = 1'b0;
        case (cur_state)
            IDLE: begin                         // If Idle, start the transcation
                next_state = SEND_CMD;
            end
            SEND_CMD: begin                     // Send the 8 bit command
                if (bit_counter == 7) begin     // Finish sending the 8 bits
                    next_state = DUMMY_CYCLES;
                end
            end
            DUMMY_CYCLES: begin                 // Send 32 dummy cycles
                if (bit_counter == 31) begin    // Finish sending the dummy cycles
                    next_state = READ_DATA;
                end
            end
            READ_DATA: begin                    // Read Data, it takes 6 clock cycles to generate one valid data
                if (bit_counter == 5) begin// If generated value but not being consumed
                    valid_reg = 1'b1;
                    if (shift_data == 0) begin
                        next_state = WAIT_CONSUME;
                    end 
                end
            end
            WAIT_CONSUME: begin                 // Wait until consumed then return to getting data
                if (shift_data == 1) begin
                    next_state = READ_DATA;
                end 
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // FSM current state sequential logic
    always @(posedge clk) begin
        if (!rst_n) begin
            bit_counter <= 6'b0;
            instruction_buf <= 24'b0;
        end else begin
            case (cur_state)
                SEND_CMD, DUMMY_CYCLES: begin
                    bit_counter <= bit_counter + 1;
                end
                READ_DATA: begin
                    instruction_buf <= {instruction_buf[19:0], io_in_data};
                    bit_counter <= bit_counter + 1;
                end
                default: begin
                    bit_counter <= 6'b0;
                end
            endcase
        end
    end

    // FSM current state combinational output
    always @(*) begin
        cs_n_reg = 1'b0;
        case (cur_state)
            SEND_CMD: begin
                oe_sig = 4'b1111;
                hold_n_reg = 1'b1;
                pause_sclk = 1'b0;

                case (bit_counter)
                    0: di_reg = 1'b0;  // bit 7
                    1: di_reg = 1'b1;  // bit 6
                    2: di_reg = 1'b1;  // bit 5
                    3: di_reg = 1'b0;  // bit 4
                    4: di_reg = 1'b1;  // bit 3
                    5: di_reg = 1'b0;  // bit 2
                    6: di_reg = 1'b1;  // bit 1
                    7: di_reg = 1'b1;  // bit 0
                    default: di_reg = 1'b0;
                endcase
            end

            DUMMY_CYCLES: begin
                oe_sig = 4'b1111;
                hold_n_reg = 1'b1;
                pause_sclk = 1'b0;
                di_reg = 1'b0;
            end

            READ_DATA: begin
                oe_sig = 4'b1010;
                pause_sclk = 1'b0;
            end

            WAIT_CONSUME: begin
                oe_sig = 4'b1010;
                pause_sclk = 1'b1;
            end

            default: begin
                cs_n_reg = 1'b1;
                di_reg = 1'b0;
                oe_sig = 4'b0000;
                hold_n_reg = 1'b0;
                pause_sclk = 1'b0;
            end
        endcase
    end

endmodule