`timescale 1ns / 1ps

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
    wire clk_object_control;
    wire clk_centi_second;
    wire clk_calculation;
    
    // Connect vga clk (25KHz)
    clk_div #(
        .DIV_FACTOR(4),
        .DIV_FACTOR_BIT(2)
    ) clk_div_vga (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_vga)
    );
    
    // Conect player control clk (100Hz)
    clk_div #(
        .DIV_FACTOR(1_000_000),
        .DIV_FACTOR_BIT(20)
    ) clk_div_player_control (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_player_control)
    );
    
    // Conect object control clk (100Hz)
    clk_div #(
        .DIV_FACTOR(1_000_000),
        .DIV_FACTOR_BIT(20)
    ) clk_div_update_position (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_object_control)
    );
    
    // Conect centi second position clk (100Hz / 0.01s)
    clk_div #(
        .DIV_FACTOR(1_000_000),
        .DIV_FACTOR_BIT(20)
    ) clk_div_centi_second (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_centi_second)
    );
    
    // Conect calculation clk (1kHz)
    clk_div #(
        .DIV_FACTOR(100_000),
        .DIV_FACTOR_BIT(17)
    ) clk_div_calculation (
        .clk_i(clk), 
        .rst_ni(reset), 
        
        .clk_o(clk_calculation)
    );
    
    //----------------------------------------- VGA -----------------------------------------
        
    // VGA Translate Variable
    wire [9:0] x, y; // Current pixels (0-1024)
    wire blank; // Is in blank screen
    
    vga_translator vga_translate (
        .clk_display(clk_vga),
        .reset(reset),
        
        .HS(HS),
        .VS(VS),
        .x(x),
        .y(y),
        .blank(blank)
    );
    
    //----------------------------------------- game display -----------------------------------------
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
        .clk_object_control(clk_object_control),
        .reset(reset),
        
        .game_display_x0(game_display_x0),
        .game_display_y0(game_display_y0),
        .game_display_x1(game_display_x1),
        .game_display_y1(game_display_y1)
    );
    
    game_display_renderer #(
        .BORDER(6)
   ) game_display_render (
       .x(x),
       .y(y),
       .game_display_x0(game_display_x0),
       .game_display_y0(game_display_y0),
       .game_display_x1(game_display_x1),
       .game_display_y1(game_display_y1),
       
       .render(game_display_border_signal)
   );
   
    //----------------------------------------- Collider -----------------------------------------
    
    //----------------------------------------- Trigger -----------------------------------------
    
    //----------------------------------------- Player ----------------------------------------- 
    wire player_render_signal;
    wire [9:0] player_pos_x;
    wire [9:0] player_pos_y;
    wire [9:0] player_w;
    wire [9:0] player_h;
    reg active_gravity = 1;
    
    player_position_controller #(
        .PLAYER_POS_X(316),
        .PLAYER_POS_Y(314),
        .PLAYER_W(17),
        .PLAYER_H(17)
        
    ) player_position(
        .clk_player_control(clk_player_control),
        .reset(reset),
        .switch_up(switch_up),
        .switch_down(switch_down),
        .switch_left(switch_left),
        .switch_right(switch_right),
        .game_display_x0(game_display_x0),
        .game_display_y0(game_display_y0),
        .game_display_x1(game_display_x1),
        .game_display_y1(game_display_y1),
        .active_gravity(active_gravity),
        
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
