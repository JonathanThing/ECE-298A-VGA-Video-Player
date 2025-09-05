`default_nettype none

// Generate PWM signal from 8-bit input
module pwm_module(
    input wire clk,
    input wire rst_n,
    input wire [7:0] sample,

    output wire pwm
);

    reg [7:0] pwm_counter;

    always @(posedge(clk)) begin
        if (!rst_n) begin
            pwm_counter <= 0;
        end else begin
            pwm_counter <= pwm_counter + 1;
        end
    end 

    assign pwm = (pwm_counter <= sample) && sample != 0;

endmodule
