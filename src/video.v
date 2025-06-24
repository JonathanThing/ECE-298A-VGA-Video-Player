module video(
    input wire clk,
    input wire rst_n,

    input wire [19:0] data_in,

    input wire horizontal_blank,
    input wire vertical_blank,

    output wire [8:0] colour,
    output wire [7:0] pwm_sample,

    output wire enable_vga,

    input wire data_ready,
    output wire shift_data,
);

endmodule