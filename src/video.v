/*
    Decodes the RLE data and outputs pixel colour or PWM samples
*/
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
    output wire shift_data
);
    reg [19:0] data_reg;
    reg [9:0] pixel_counter;
    reg enable_vga_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            pixel_counter <= 10'b0;
            colour_reg <= 9'b0;
            pwm_sample_reg <= 8'b0;
            enable_vga_reg <= 1'b0;
        end else begin

        end
    end

    assign colour = (!horizontal_blank || !vertical_blank)? data_reg[8:0] : 0; // Example: Extracting colour from data_in

endmodule