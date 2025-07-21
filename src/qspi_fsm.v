/*
 * QSPI FSM Module
 * FSM to control reading from external flash memory through QSPI
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
    input  wire        spi_io0,         // IO0 (for quad read)
    input  wire        spi_io1,         // DO (data output from flash) - IO1
    input  wire        spi_io2,         // IO2
    input  wire        spi_io3,         // IO3/HOLD
    input  wire        shift_data,      // Signal to have data shifted 

    // Output interface
    output wire [17:0] instruction,        // 18-bit data output
    output wire        spi_cs_oe,
    output wire        spi_di_oe,
    output wire        spi_sclk_oe,
    output wire        spi_hold_n_oe,
    output wire        valid           // High when instruction is valid
);

    // State machine states
    localparam IDLE         = 3'b100;
    localparam SEND_CMD     = 3'b001;
    localparam DUMMY_CYCLES = 3'b010;
    localparam READ_DATA    = 3'b011;
    localparam WAIT_CONSUME = 3'b101;

    // Internal signals
    reg [2:0]  cur_state;
    reg [2:0]  next_state;
    reg [5:0]  bit_counter;
    reg [23:0] instruction_buf;

    reg        valid_reg;
    reg        cs_n_reg;
    reg        di_reg;      // Data Input value
    reg [3:0]  oe_sig;      // 1 for output; 0 for input
    reg        hold_n_reg;  // IO3 Hold register value 

    wire [3:0] io_in_data;  

    // SPI clock is inverted system clock
    assign spi_clk = !clk & !cur_state[2]; // Inverted Clk only if not waiting for data
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

    // FSM next state combinational logic
    always @(*) begin
        next_state = cur_state;
        case (cur_state)
            IDLE:           next_state = SEND_CMD;                                              // Start the process by sending command
            SEND_CMD:       if (bit_counter == 7) next_state = DUMMY_CYCLES;                    // Once done sending command, start sending dummy cycles
            DUMMY_CYCLES:   if (bit_counter == 31)  next_state = READ_DATA;                     // Once done sending the 32 dummy cycles, start reading data
            READ_DATA:      if (bit_counter == 5 && shift_data == 0) next_state = WAIT_CONSUME; // After reading message, if the data is not to be shifted, wait
            WAIT_CONSUME:   if (shift_data == 1) next_state = READ_DATA;                        // Once data is shifted, start reading data again
            default:        next_state = IDLE;
        endcase
    end

    // Next State Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            cur_state <= IDLE;
            bit_counter <= 0;
            cs_n_reg <= 1'b1;
            di_reg <= 1'b0;
            valid_reg <= 1'b0;
        end else begin
            if (next_state != cur_state) begin  // State transition
                bit_counter <= 0;
                di_reg <= 1'b0;
                case (next_state)
                    IDLE: begin

                    end
                    SEND_CMD: begin
                        cs_n_reg <= 1'b0;
                    end
                    DUMMY_CYCLES: begin
                        cs_n_reg <= 1'b0;
                    end
                    READ_DATA: begin
                        cs_n_reg <= 1'b0;
                    end
                    WAIT_CONSUME: begin
                        cs_n_reg <= 1'b0;
                        valid_reg <= 1'b1;
                    end
                    default: begin
                        cs_n_reg <= 1'b1;
                    end
                endcase

            end else begin                      // State Continue
                case (next_state)
                    SEND_CMD: begin
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
                        bit_counter <= bit_counter + 1;
                    end
                    DUMMY_CYCLES: begin   
                        bit_counter <= bit_counter + 1;
                    end
                    READ_DATA: begin
                        if (bit_counter == 5) begin // Reset if one message done
                            bit_counter <= 0;
                            valid_reg <= 1'b1;
                        end else begin
                            valid_reg <= 1'b0;
                            bit_counter <= bit_counter + 1;
                        end
                    end
                    default: begin
                        bit_counter <= 0;
                    end
                endcase
            end

            cur_state <= next_state; 
        end
    end

    // Output
    always @(posedge clk) begin
        if (!rst_n) begin
            oe_sig <= 4'b1111;
            hold_n_reg <= 1'b1;
            di_reg <= 1'b0;
        end else begin
            case (next_state)
                IDLE: begin
                    cs_n_reg <= 1'b1;
                    oe_sig <= 4'b1111;
                    hold_n_reg <= 1'b1;
                    di_reg <= 1'b0;
                end
                SEND_CMD: begin
                    cs_n_reg <= 1'b0;
                    oe_sig <= 4'b1111;
                    hold_n_reg <= 1'b1; 

                end
                DUMMY_CYCLES: begin
                    cs_n_reg <= 1'b0;
                    oe_sig <= 4'b1111;
                    hold_n_reg <= 1'b1;
                    di_reg <= 1'b0;
                end
                READ_DATA: begin
                    cs_n_reg <= 1'b0;
                    oe_sig <= 4'b0100;  
                    hold_n_reg <= 1'b0; 
                end 
                WAIT_CONSUME: begin
                    cs_n_reg <= 1'b0;
                    oe_sig <= 4'b0100;  
                    hold_n_reg <= 1'b0; 
                end 
                default: begin
                    cs_n_reg <= 1'b1;
                    oe_sig <= 4'b1111;
                    hold_n_reg <= 1'b1;
                    di_reg <= 1'b0;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            instruction_buf <= 24'b0;
        end else begin 
            if (cur_state == READ_DATA) begin
                instruction_buf <= {instruction_buf[19:0], io_in_data};
            end 
        end
    end
endmodule