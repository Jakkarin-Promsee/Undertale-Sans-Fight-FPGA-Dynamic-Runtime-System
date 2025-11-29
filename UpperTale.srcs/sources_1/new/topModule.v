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
    
    //----------------------------------------- Clock Divider -----------------------------------------
    
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
    
    //----------------------------------------- Collider -----------------------------------------
    wire [9:0] game_display_x0;
    wire [9:0] game_display_y0;
    wire [9:0] game_display_x1;
    wire [9:0] game_display_y1;
    wire game_display_border_signal;
    
    game_display_controller #(
        .GAME_DISPLAY_X0(130),
        .GAME_DISPLAY_Y0(251),
        .GAME_DISPLAY_X1(506),
        .GAME_DISPLAY_Y1(391)
  
    ) game_display_control (
        .clk_update_position(clk_update_position),
        .reset(reset),
        .game_display_x0(game_display_x0),
        .game_display_y0(game_display_y0),
        .game_display_x1(game_display_x1),
        .game_display_y1(game_display_y1)
    );
    
    game_display_renderer #(
        .BORDER(7)
   ) game_display_render (
       .x(x),
       .y(y),
       .game_display_x0(game_display_x0),
       .game_display_y0(game_display_y0),
       .game_display_x1(game_display_x1),
       .game_display_y1(game_display_y1),
       
       .render(game_display_border_signal)
   );
    
    //----------------------------------------- Trigger -----------------------------------------
    
    //----------------------------------------- Player ----------------------------------------- 
    wire player_render_signal;
    wire [9:0] player_pos_x;
    wire [9:0] player_pos_y;
    wire [9:0] player_w;
    wire [9:0] player_h;
    
    player_position_controller #(
        .PLAYER_POS_X(316),
        .PLAYER_POS_Y(314),
        .PLAYER_W(17),
        .PLAYER_H(17),
        .SPEED(3),
        .GRAVITY(2)
        
    ) player_position(
        .clk_control(clk_player_control),
        .reset(reset),
        .switch_up(switch_up),
        .switch_down(switch_down),
        .switch_left(switch_left),
        .switch_right(switch_right),
        .game_display_x0(game_display_x0),
        .game_display_y0(game_display_y0),
        .game_display_x1(game_display_x1),
        .game_display_y1(game_display_y1),
        
        .player_pos_x(player_pos_x),
        .player_pos_y(player_pos_y),
        .player_w(player_w),
        .player_h(player_h)
    );
    
    player_renderer player_render (
        .x(x),
        .y(y),
        .player_pos_x(player_pos_x),
        .player_pos_y(player_pos_y),
        .player_w(player_w),
        .player_h(player_h),
        
        .render(player_render_signal)
    );
    
    universal_renderer universal_render(
        .x(x),
        .y(y),
        .blank(blank),
        
        .game_display_border_render(game_display_border_signal),
        .player_render(player_render_signal),
        
        .RED(RED),
        .GREEN(GREEN),
        .BLUE(BLUE)
    );
endmodule
