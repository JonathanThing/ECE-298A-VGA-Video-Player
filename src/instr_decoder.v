module instr_decoder (
    input wire clk,
    input wire rst_n,

    
    input data_ready,
    input [19:0] data,
    input next_frame,
    input next_line,
    input next_pixel,

    output get_next,
    output [8:0] colour_out


);

reg [10:0] length;
reg [8:0] colour;

reg start;
reg sig_next;

always @(posedge clk) begin
    if(!rst_n) begin
        length <= ~0;
        sig_next <= 0;
        start <= 0;
        colour <= 0;
    end
    else begin
        sig_next <= 0;

        // boot sequence
        if(length == ~0) begin
            length <= 1;
            start <= 1;
            colour <= 0;
        end

        if (start) begin
            if(next_frame && data_ready) begin
                length <= data[19:9];
                colour <= data[8:0];
                start <= 0;
                sig_next <= 1;
            end
        end

        else begin
            // Run Length has ended
            if(length == 0) begin
                if(data_ready) begin
                    length <= data[19:9];
                    colour <= data[8:0];
                    sig_next <= 1;
                end
            end

            // Send the next pixel
            else if(next_pixel) begin
                // if data is ready and the next pixel is the last for the run
                if(length == 1 && data_ready) begin
                    length <= data[19:9];
                    colour <= data[8:0];
                    sig_next <= 1;
                end
                else length <= length - 1;
            end
        end
    end
end

assign get_next = sig_next;

endmodule