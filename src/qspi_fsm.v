/*
 * QSPI FSM Module
 * FSM to control reading from external flash memory through QSPI
 */

module qspi_fsm (
    input wire          clk,
    input wire          rst_n,      // Reset (active low)

    // SPI Flash interface
    output wire         spi_clk,    // SPI clock = ~clk
    output wire         spi_cs_n,   // Chip select (active low)
    output wire         spi_di,     // DI (data input to flash) - IO0
    output wire         spi_hold_n, // HOLD (We have to hold it high during setup)

    // Input Wires
    input wire [3:0]    spi_io,
    input wire          shift_data, // Signal to have data shifted
    input wire          vsync,      // Vertical sync signal from VGA controller, used as known ready point

    // Output interface
    output wire [17:0]  instruction,    // 18-bit data output
    output wire         spi_di_oe,  
    output wire         spi_hold_n_oe,
    output wire         valid           // High when instruction is valid
);

    // State machine states
    localparam IDLE         = 3'b100;
    localparam RESET_PAGE   = 3'b110;
    localparam AWAIT_READY  = 3'b111;
    localparam SEND_CMD     = 3'b001;
    localparam DUMMY_CYCLES = 3'b010;
    localparam READ_DATA    = 3'b011;
    localparam WAIT_CONSUME = 3'b101;
    
    // Internal signals
    reg [2:0]  cur_state;
    reg [2:0]  next_state;
    reg [5:0]  bit_counter;
    reg [23:0] instruction_buf;

    // Output Registers
    reg valid_reg;
    reg cs_n_reg;
    reg di_reg;         // Flash IC Data Input
    reg hold_oe_reg;    // Output enable for HOLD
    reg d0_oe_reg;      // Output enable for D0
    reg hold_n_reg;     // IO3 Hold register value

    // SPI clock is inverted system clock
    assign spi_clk = (cur_state == WAIT_CONSUME || cur_state == AWAIT_READY) ? 1'b0 : ~clk;
    assign spi_cs_n = cs_n_reg;
    assign spi_di = di_reg;
    assign spi_hold_n = hold_n_reg;
    
    // Output assignments
    assign instruction = instruction_buf[17:0];
    assign valid = valid_reg;
    assign spi_di_oe = d0_oe_reg;
    assign spi_hold_n_oe = hold_oe_reg;

    // FSM Next State Combinational Logic
    always @(*) begin
        next_state = cur_state;
        case (cur_state)
            IDLE:           if (bit_counter == 3) next_state = RESET_PAGE;                      // Start the process by sending command (0x6B)
            RESET_PAGE:     if (bit_counter == 35) next_state = AWAIT_READY;                    // Extra clock cycle for cs reset
            AWAIT_READY:    if (!vsync) next_state = SEND_CMD;                                  // Extra cycle for read latency and cs margin
            SEND_CMD:       if (bit_counter == 7) next_state = DUMMY_CYCLES;                    // Once done sending command, send 32 dummy cycles
            DUMMY_CYCLES:   if (bit_counter == 31)  next_state = READ_DATA;                     // Once done sending the 32 dummy cycles, start reading data
            READ_DATA:      if (bit_counter == 5 && shift_data == 0) next_state = WAIT_CONSUME; // After reading the nibble, if the data is not to be shifted, wait
            WAIT_CONSUME:   if (shift_data == 1) next_state = READ_DATA;                        // Once data is shifted, start reading data again
            default:        next_state = IDLE;
        endcase
    end

    // FF Logic, handles data output, state transitions, and bit counting
    always @(posedge clk) begin
        if (!rst_n) begin
            cur_state <= IDLE;
            bit_counter <= 0;
            valid_reg <= 1'b0;
            di_reg <= 1'b0;
        end else begin
            cur_state <= next_state; // Update current state to next state

            if (next_state != cur_state) begin // State transition
                // Reset the bit counter and data output
                bit_counter <= 0;               
                di_reg <= 1'b0;

                if (next_state == WAIT_CONSUME) begin   // If going to wait state, set valid to be 1
                    valid_reg <= 1'b1;
                end
            end else begin // Same state
                di_reg <= 1'b0;
                bit_counter <= bit_counter + 1;
                valid_reg <= 1'b0;

                case (next_state) // Determine data output values
                    RESET_PAGE: begin
                        // 0x13, Page Data Read
                        case (bit_counter)      // Get next value given current bit
                            0: di_reg <= 1'b0;  // bit 6
                            1: di_reg <= 1'b0;  // bit 5
                            2: di_reg <= 1'b1;  // bit 4
                            3: di_reg <= 1'b0;  // bit 3
                            4: di_reg <= 1'b0;  // bit 2
                            5: di_reg <= 1'b1;  // bit 1
                            6: di_reg <= 1'b1;  // bit 0
                            default: di_reg <= 1'b0;
                        endcase  
                    end

                    SEND_CMD: begin
                        // 0x6B, Fast Read Quad I/O
                        case (bit_counter)      // Get next value given current bit
                            0: di_reg <= 1'b1;  // bit 6
                            1: di_reg <= 1'b1;  // bit 5
                            2: di_reg <= 1'b0;  // bit 4
                            3: di_reg <= 1'b1;  // bit 3
                            4: di_reg <= 1'b0;  // bit 2
                            5: di_reg <= 1'b1;  // bit 1
                            6: di_reg <= 1'b1;  // bit 0
                            default: di_reg <= 1'b0;
                        endcase    
                    end

                    READ_DATA: begin
                        if (bit_counter == 5) begin // Reset if one message done
                            bit_counter <= 0;
                            valid_reg <= 1'b1;
                        end
                    end

                    WAIT_CONSUME: begin     
                        bit_counter <= 0;
                        valid_reg <= 1'b1;
                    end

                    default: begin // IDLE and DUMMY_CYCLES, erroneous states
                        // Do nothing, keep the default values
                    end
                endcase                    
            end
        end
    end

    // FF logic, handles chip select and output enables
    always @(posedge clk) begin
        if (!rst_n) begin
            hold_oe_reg <= 1'b1;
            d0_oe_reg <= 1'b1;
            hold_n_reg <= 1'b1;
            cs_n_reg <= 1'b1;
        end else begin
            cs_n_reg <= 1'b1;
            hold_oe_reg <= 1'b1;
            d0_oe_reg <= 1'b1;
            hold_n_reg <= 1'b1;

            case (next_state)
                RESET_PAGE: begin
                    if (bit_counter > 30) begin
                        cs_n_reg <= 1'b1;   // Pull CS high after transmission
                    end else begin
                        cs_n_reg <= 1'b0;   // Want to pull CS low during transmission
                    end
                end
                SEND_CMD: begin
                    d0_oe_reg <= 1'b1;    // Set to output mode
                    cs_n_reg <= 1'b0;   // Want to pull CS low during transmission
                end
                DUMMY_CYCLES: begin
                    cs_n_reg <= 1'b0;
                end
                READ_DATA, WAIT_CONSUME: begin
                    cs_n_reg <= 1'b0;
                    hold_oe_reg <= 1'b0;
                    d0_oe_reg <= 1'b0;
                    hold_n_reg <= 1'b0; 
                end 
                default: begin // IDLE, and erroneous states
                    // Do nothing, keep the default values
                end
            endcase
        end
    end

    // Read Instruction Buffer Logic, (Looks at current state not next state)
    always @(posedge clk) begin
        if (!rst_n) begin
            instruction_buf <= 24'b0;
        end else begin 
            if (cur_state == READ_DATA) begin 
                instruction_buf <= {instruction_buf[19:0], spi_io};
            end 
        end
    end

    wire _unused = &{instruction_buf[23:20]};
endmodule