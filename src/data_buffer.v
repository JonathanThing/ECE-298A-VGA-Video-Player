module data_buffer (
    input wire clk,
    input wire rst_n,

    input wire [19:0] data_in,
    output wire [19:0] data_out,
    
    input wire shift_data
);

reg [19:0] data_buffer; 

always @(posedge clk) begin
    if (!rst_n) begin
        data_buffer <= 20b'0;
    end else if (shift_data) begin
        data_buffer <= data_in;
    end
end

assign data_out = data_buffer;

endmodule