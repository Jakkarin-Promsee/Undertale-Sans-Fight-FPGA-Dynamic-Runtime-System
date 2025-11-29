`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/22/2025 03:01:44 PM
// Design Name: 
// Module Name: topModule
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


module topModule(
    // Setting Inputs
    input clk,
    input reset,
    
    // Controller Input
    input switch_up,
    input switch_down,
    input switch_left,
    input switch_right,
    
    // Output
    output HS,
    output VS,
    output [3:0] RED, 
    output [3:0] GREEN,
    output [3:0] BLUE
    );
    
    // Internal Variable
    wire clk_vga;
    wire clk_player_control;
    wire clk_update_position;
    wire clk_calculation;
    
    // Connect vga clk (25KHz)
    clk_div_vga c1_clk_vga (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_vga)
    );
    
    // Conect player control clk (100Hz)
    clk_div_player_control c2_clk_player_control (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_player_control)
    );
    
    // Conect update position clk (100Hz)
    clk_div_update_position c3_clk_update_position (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_update_position)
    );
    
    // Conect calculation clk (1kHz)
    clk_div_calculation c4_clk_calculation (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_calculation)
    );
    
    //----------------------------------------- VGA -----------------------------------------
        
    // VGA Translate Variable
    wire [9:0] x, y; // Current pixels (0-1024)
    wire blank; // Is in blank screen
    
    vga_translator t1_vga_translator (
        .clk_display(clk_vga),
        .reset(reset),
        
        .HS(HS),
        .VS(VS),
        .x(x),
        .y(y),
        .blank(blank)
    );
    
    wire player_areas_signal;
    wire [9:0] p_x;
    wire [9:0] p_y;
    wire [9:0] c_p_x;
    wire [9:0] c_p_y;
    
    player_colider p_c(
        .clk_control(clk_player_control),
        .reset(reset),
        .switch_up(switch_up),
        .switch_down(switch_down),
        .switch_left(switch_left),
        .switch_right(switch_right),
        
        .p_x(p_x),
        .p_y(p_y),
        .c_p_x(c_p_x),
        .c_p_y(c_p_y)
    );
    
    player_areas p_a (
        .x(x),
        .y(y),
        .p_x(p_x),
        .p_y(p_y),
        .c_p_x(c_p_x),
        .c_p_y(c_p_y),
        
        .player_area(player_areas_signal)
    );
    
    render_areas_color renderer(
        .x(x),
        .y(y),
        .blank(blank),
        .player_areas(player_areas_signal),
        
        .RED(RED),
        .GREEN(GREEN),
        .BLUE(BLUE)
    );
endmodule
