`timescale 1ns / 1ps

module clk_div_vga(
  input wire rst_ni,
  input wire clk_i,
  output wire clk_o
);

reg counter_r;
reg clk_r;

always @(posedge clk_i) begin
    if (!rst_ni) begin
        clk_r <= 1'b0;
        counter_r <= 32'b0;
    end else begin
        if (counter_r == 1) begin 
            clk_r <= ~clk_r;          // Toggles at the end of cycle 2
            counter_r <= 32'b0;       // Resets to 0
        end else begin
            counter_r <= counter_r + 1; // Counts 0 --> 1
        end
    end
end

assign clk_o = clk_r;

endmodule
