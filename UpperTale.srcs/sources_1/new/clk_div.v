`timescale 1ns / 1ps

module clk_div #(
    parameter integer DIV_FACTOR = 4,
    parameter integer DIV_FACTOR_BIT = 2
)(
    input wire rst_ni,
    input wire clk_i,
    output wire clk_o
);

    // Using only 0-499_999 (maximum 524_288)
    reg [DIV_FACTOR_BIT-2:0] counter_r;
    reg clk_r;

    always @(posedge clk_i) begin
    // If sw0 = false, reset condition
      if (!rst_ni) begin
        clk_r <= 0;
        counter_r <= 0;
     
    // Else reduce Hz from 100MHz to 100HZ (100fps)
      end else begin
        if (counter_r == (DIV_FACTOR/2) - 1) begin
          clk_r <= ~clk_r;
          counter_r <= 0;
        end else begin
          counter_r <= counter_r + 1;
        end
      end
    end
    
    assign clk_o = clk_r;

endmodule
