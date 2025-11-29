`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/22/2025 04:32:22 PM
// Design Name: 
// Module Name: render_areas_color
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


module render_areas_color(
    // REMOVE clk_display - This module must be combinational
    input [9:0] x,
    input [9:0] y,
    
    input blank,        // <-- ADDED: Input for the blanking signal
    input game_display_border_render,
    input player_render,
    
    // Outputs must be 'reg' since they are driven from inside an always @(*) block
    output reg [3:0] RED,  
    output reg [3:0] GREEN,
    output reg [3:0] BLUE
);

    // --- Combinational Logic Block (Priority MUX) ---
    // The always @(*) block ensures outputs update instantly when inputs change.
    always @(*) begin
        
        // Use blocking assignments (=) for combinational logic
        
        // 1. Highest Priority: Blanking Area (Black)
        // If 'blank' is 1 (Active Low blanking is ~blank, Active High blanking is blank)
        if (blank) begin 
            RED   = 0;
            GREEN = 0;
            BLUE  = 0;
        end 
        
        else if (game_display_border_render) begin
            RED   = 15;
            GREEN = 15;
            BLUE  = 15;
        end
                
        // 2. Next Priority: Player Area (Green)
        else if (player_render) begin // <-- FIXED SYNTAX: 'else if'
            RED   = 0;
            GREEN = 15;
            BLUE  = 0;
        end 
        
        // 3. Lowest Priority: Default Background (White)
        else begin
            RED   = 0;
            GREEN = 0;
            BLUE  = 0;
        end
    end

endmodule