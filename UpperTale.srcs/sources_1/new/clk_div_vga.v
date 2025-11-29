`timescale 1ns / 1ps

module clk_div_vga (
  input wire rst_ni,
  input wire clk_i,
  output wire clk_o
);

// Using only 0-1 value
reg [1:0] counter_r;
reg clk_r;

always @(posedge clk_i) begin
    // If rst_ni = false, reset condition
    if (!rst_ni) begin
        clk_r <= 0;
        counter_r <= 0;
        
    // Else reduce Hz from 100MHz to 25MHz (640x480 @ 60Hz)
    end else begin
        if (counter_r == 3) begin 
            clk_r <= ~clk_r;          
            counter_r <= 0;       
        end else begin
            counter_r <= counter_r + 1;
        end
    end
end

assign clk_o = counter_r;

endmodule
