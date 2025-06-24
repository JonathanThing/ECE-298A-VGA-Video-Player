module vga_timing(
    input wire clk,
    input wire rst_n,

    input wire enable,
    
    output wire hsync_pulse,
    output wire vsync_pulse,
    output wire horizontal_blank,
    output wire vertical_blank,
);

always @(posedge clk) begin

end



endmodule