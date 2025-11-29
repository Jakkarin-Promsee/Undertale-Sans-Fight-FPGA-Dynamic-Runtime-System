`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/22/2025 04:12:04 PM
// Design Name: 
// Module Name: topSim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module topSim();
    
    // Inputs (Initialized at declaration to prevent Z/X states)
    reg clk          = 1'b0;
    reg reset        = 1'b1; // Assuming reset is active-low (rst_ni) and starts DE-asserted
    reg switch_up    = 1'b0;
    reg switch_down  = 1'b0;
    reg switch_left  = 1'b0;
    reg switch_right = 1'b0;
    
    // Outputs
    wire HS;
    wire VS;
    wire [3:0] RED;
    wire [3:0] GREEN;
    wire [3:0] BLUE;
    
    // Internal Wires (for probing signals within topModule)
    wire clk_vga;
    wire clk_player_control;
    wire clk_update_position;
    wire clk_calculation;
    wire [9:0] x, y;
    wire blank;
    wire player_areas_signal;
    wire [9:0] p_x;
    wire [9:0] p_y;

    // Instantiate the Device Under Test (DUT)
    topModule DUT (
        .clk(clk),
        .reset(reset),
        .switch_up(switch_up),
        .switch_down(switch_down),
        .switch_left(switch_left),
        .switch_right(switch_right),
        .HS(HS),
        .VS(VS),
        .RED(RED),
        .GREEN(GREEN),
        .BLUE(BLUE)
    );
    
    // Connections to internal wires (Must be done explicitly for probing if they are not module outputs)
    assign clk_vga = DUT.clk_vga;
    assign clk_player_control = DUT.clk_player_control;
    assign clk_update_position = DUT.clk_update_position;
    assign clk_calculation = DUT.clk_calculation;
    assign x = DUT.x;
    assign y = DUT.y;
    assign blank = DUT.blank;
    assign player_areas_signal = DUT.player_areas_signal;
    assign p_x = DUT.p_x;
    assign p_y = DUT.p_y;
    
    // Clock Generation (100MHz - period 10ns)
    initial begin 
        forever #1 clk = ~clk;
    end
    
    // Stimulus
    initial begin
       $dumpvars(0, topSim);
       $dumpfile("waveform.vcd");
       
      // 1. Initial Reset Phase (Assert Active-Low Reset)
      // Assuming rst_ni means active-low reset.
      reset = 1'b0; // Assert Reset
      #20;
      reset = 1'b1; // De-assert Reset (System starts running)
      
      #100; // Wait for system to settle
      
      // 2. Controller Stimulus: Move Up
      switch_up = 1'b1;
      #50000; // Hold for 50us (50,000ns)
//      switch_right = 1'b0;
      
      #10_000_000;
      $finish;
     end
    
endmodule