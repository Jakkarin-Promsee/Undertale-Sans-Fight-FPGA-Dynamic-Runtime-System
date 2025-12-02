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
    
    //----------------------------------------- Game Runtime ROM Reader -----------------------------------------
    localparam integer INITIAL_STAGE = 0;
    localparam integer MAXIMUM_STAGE = 8; // 256 stage
    localparam integer MAXIMUM_TIMES = 30; // 10,000,000.00 second
    localparam integer MAXIMUM_ATTACK = 20; // 1,000,000
    localparam integer MAXIMUM_PLATFORM = 20; // 1,000,000
        
    wire [MAXIMUM_TIMES-1:0] next_attack_time;
    wire [MAXIMUM_TIMES-1:0] next_platform_time;
    wire update_attack_time;
    wire update_platform_time;
    
    wire [MAXIMUM_STAGE-1:0] current_stage;
    wire [MAXIMUM_TIMES-1:0] current_time;
    wire [MAXIMUM_ATTACK-1:0] attack_i;
    wire [MAXIMUM_PLATFORM-1:0] platform_i;
    wire sync_attack_time;
    wire sync_platform_time;
    
    game_manager_contorller #(
        .INITIAL_STAGE(INITIAL_STAGE),
        .MAXIMUM_STAGE(MAXIMUM_STAGE),
        .MAXIMUM_TIMES(MAXIMUM_TIMES),
        .MAXIMUM_ATTACK(MAXIMUM_ATTACK),
        .MAXIMUM_PLATFORM(MAXIMUM_PLATFORM)
        
    ) game_manager_contorl (
        .clk(clk),
        .clk_centi_second(clk_centi_second),
        .reset(reset),
        .next_attack_time(next_attack_time),
        .next_platform_time(next_platform_time),
        .update_attack_time(update_attack_time),
        .update_platform_time(update_platform_time),
        
        .current_stage(current_stage),
        .current_time(current_time),
        .attack_i(attack_i),
        .platform_i(platform_i),
        .sync_attack_time(sync_attack_time),
        .sync_platform_time(sync_platform_time)
    );
    
    // Attack object data
    wire  [4:0]  attack_type;
    wire  [1:0]  attack_colider_type;
    wire  [2:0]  attack_movement_direction;
    wire  [4:0]  attack_speed;
    wire  [7:0]  attack_pos_x;
    wire  [7:0]  attack_pos_y;
    wire  [7:0]  attack_w;
    wire  [7:0]  attack_h;
    wire  [7:0]  attack_time;
    
    attack_object_rom #(
        .ADDR_WIDTH(MAXIMUM_ATTACK),
        .MAXIMUM_TIMES(MAXIMUM_TIMES)
    ) attack_object_reader (
        .clk(clk),
        .addr(attack_i),
        .current_time(current_time),
        .sync_attack_time(sync_attack_time),
        
        .update_attack_time(update_attack_time),
        .next_attack_time(next_attack_time),
        .types(attack_type),
        .colider_type(attack_colider_type),
        .movement_direction(attack_movement_direction),
        .speed(attack_speed),
        .pos_x(attack_pos_x),
        .pos_y(attack_pos_y),
        .w(attack_w),
        .h(attack_h),
        .times(attack_time)
    );
    
    
    // Platform object data
    wire  [2:0]  platform_movement_direction;
    wire  [4:0]  platform_speed;
    wire  [7:0]  platform_pos_x;
    wire  [7:0]  platform_pos_y;
    wire  [7:0]  platform_w;
    wire  [7:0]  platform_h;
    wire  [7:0]  platform_time;
        
    platform_object_rom #(
        .ADDR_WIDTH(MAXIMUM_PLATFORM),
        .MAXIMUM_TIMES(MAXIMUM_TIMES)
    ) platform_object_reader (
        .clk(clk),
        .addr(platform_i),
        .current_time(current_time),
        .sync_platform_time(sync_platform_time),
        
        .update_platform_time(update_platform_time),
        .next_platform_time(next_platform_time),
        .movement_direction(platform_movement_direction),
        .speed(platform_speed),
        .pos_x(platform_pos_x),
        .pos_y(platform_pos_y),
        .w(platform_w),
        .h(platform_h),
        .times(platform_time)
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
    wire object_colider1_signal;
    object_renderer object_colider1 (
        .x(x),
        .y(y),
        .object_pos_x(attack_pos_x),
        .object_pos_y(attack_pos_y),
        .object_w(attack_w),
        .object_h(attack_h),
        
        .render(object_colider1_signal)
    );
    
    //----------------------------------------- Trigger -----------------------------------------
    
    wire object_trigger1_signal;
    object_renderer object_trigger1 (
        .x(x),
        .y(y),
        .object_pos_x(platform_pos_x),
        .object_pos_y(platform_pos_y),
        .object_w(platform_w),
        .object_h(platform_h),
        
        .render(object_trigger1_signal)
    );
            
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
        .object_colider_signal(object_colider1_signal),
        .object_trigger_signal(object_trigger1_signal),
        .player_render(player_render_signal),
        
        .RED(RED),
        .GREEN(GREEN),
        .BLUE(BLUE)
    );
endmodule
