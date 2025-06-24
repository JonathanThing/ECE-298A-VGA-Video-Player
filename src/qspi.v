module qspi(
    input wire clk,
    input wire rst_n,

    input wire [1:0] spi_latency,
    
    output wire spi_clk,
    output wire spi_do,
    input wire [3:0] spi_di,
    output wire io_direction,
    output wire cs_n,

    input wire shift_data,
    output wire data_ready,
    output wire [19:0] data_out,
);

endmodule