module pwm (
    input clk,
    input rst_n,
    
    input [7:0] sample_value, 
    output pwm_out
);

    reg [7:0] counter;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= 8'b0;
        end else begin
            counter <= counter + 1;
            if (counter == 8'hFE) begin // Reset before it reaches max, so 255 sample_value is always on
                counter <= 8'b0; 
            end
        end
    end
    
    assign pwm_out = (counter < sample_value) ? 1'b1 : 1'b0; 
endmodule