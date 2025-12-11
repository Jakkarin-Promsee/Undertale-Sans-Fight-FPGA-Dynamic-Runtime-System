`timescale 1ns / 1ps

module topModule#(
    parameter integer IS_SIM = 0
)(
    // Setting Inputs
    input clk,
    input clk_reset,
    
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
    
    //----------------------------------------- List of Contents -----------------------------------------
    // To use it, select name of topic, then use search (ctrl + F) to find next word
    
    
    // Clock Dividers Section
    
    // Synchonus Reset Section
    
    // VGA Translator Section
    
    // Game Runtime && ROM Reader Section 
    
    // Game Display Section
    
    // Game Display Section
    
    // Collider Object Runtimes Section
    
    // Trigger Object Runtimes Section
    
    // Player Controller Section
    
    // Universal Renderer Section
    
    
    //----------------------------------- Clock Dividers Section -----------------------------------------
    // The Main clock is running at 100MHz
    
    // Connect to clk_div_vga 25KHz)
    // To match vga signal speed, current for 480x680 60Hz
    localparam integer CLK_DIV_FACTOR_VGA = 4;
    localparam integer CLK_DIV_FACTOR_BIT_VGA = 2;

    // Conect to clk_div_player_control (100Hz)
    // To maintain player module.
    // Such as switch_control, player_pos, player_gravity, player_render, etc.
    localparam integer CLK_DIV_FACTOR_PLAYER_CONTROL = 1_000_000;
    localparam integer CLK_DIV_FACTOR_PLAYER_CONTROL_SIM = 10;
    localparam integer CLK_DIV_FACTOR_BIT_PLAYER_CONTROL = 20;

    
    // Conect to clk_div_object_control (100Hz)
    // To maintain object module. Seperate to coliders and triggers type (100+ objects)
    // Such as objects_runtime, objects_position, objects_render
    localparam integer CLK_DIV_FACTOR_OBJECT_CONTROL = 1_000_000;
    localparam integer CLK_DIV_FACTOR_OBJECT_CONTROL_SIM = 10;
    localparam integer CLK_DIV_FACTOR_BIT_OBJECT_CONTROL = 20;

    // Conect to clk_div_centi_second (100Hz)
    // To maintain run-time module. Require precise 0.01clk/s to count time
    // For main runtime module that read dynamic task from ROM file
    localparam integer CLK_DIV_FACTOR_CENTI_SECOND = 1_000_000;
    localparam integer CLK_DIV_FACTOR_CENTI_SECOND_SIM = 10;
    localparam integer CLK_DIV_FACTOR_BIT_CENTI_SECOND = 20;

    // Conect to clk_div_calculation (1kHz)
    // To maintain object collidion and tringger check or heavy calculation
    // This clock should faster than main clk to keep it synchonus
    localparam integer CLK_DIV_FACTOR_CALCULATION = 100_000;
    localparam integer CLK_DIV_FACTOR_CALCULATION_SIM = 5;
    localparam integer CLK_DIV_FACTOR_BIT_CALCULATION = 20;
    

    // Internal Clock Wire Variable
    wire clk_vga;
    wire clk_player_control;
    wire clk_object_control;
    wire clk_centi_second;
    wire clk_calculation;
    
    clk_div #(
        .DIV_FACTOR(CLK_DIV_FACTOR_VGA),
        .DIV_FACTOR_BIT(CLK_DIV_FACTOR_BIT_VGA)
    ) clk_div_vga (
        .clk_i(clk), 
        .rst_ni(clk_reset), 
        
        .clk_o(clk_vga)
    );
    
    clk_div #(
        .DIV_FACTOR(IS_SIM? CLK_DIV_FACTOR_PLAYER_CONTROL_SIM : CLK_DIV_FACTOR_PLAYER_CONTROL),
        .DIV_FACTOR_BIT(CLK_DIV_FACTOR_BIT_PLAYER_CONTROL)
    ) clk_div_player_control (
        .clk_i(clk), 
        .rst_ni(clk_reset), 
        
        .clk_o(clk_player_control)
    );
    
    clk_div #(
        .DIV_FACTOR(IS_SIM? CLK_DIV_FACTOR_OBJECT_CONTROL_SIM : CLK_DIV_FACTOR_OBJECT_CONTROL),
        .DIV_FACTOR_BIT(CLK_DIV_FACTOR_BIT_OBJECT_CONTROL)
    ) clk_div_object_control (
        .clk_i(clk), 
        .rst_ni(clk_reset), 
        
        .clk_o(clk_object_control)
    );
    
    clk_div #(
        .DIV_FACTOR(IS_SIM? CLK_DIV_FACTOR_CENTI_SECOND_SIM : CLK_DIV_FACTOR_CENTI_SECOND),
        .DIV_FACTOR_BIT(CLK_DIV_FACTOR_BIT_CENTI_SECOND)
    ) clk_div_centi_second (
        .clk_i(clk), 
        .rst_ni(clk_reset), 
        
        .clk_o(clk_centi_second)
    );
    
    clk_div #(
        .DIV_FACTOR(IS_SIM? CLK_DIV_FACTOR_CALCULATION_SIM : CLK_DIV_FACTOR_CALCULATION),
        .DIV_FACTOR_BIT(CLK_DIV_FACTOR_BIT_CALCULATION)
    ) clk_div_calculation (
        .clk_i(clk), 
        .rst_ni(clk_reset), 
        
        .clk_o(clk_calculation)
    );
    
    //----------------------------------- Synchonus Reset Section -----------------------------------------
    // To sync clock reset and other flip-flop reset (1s)
    localparam integer WAIT_TIME_FOR_CLK_SYNC = 100_000_000;
    localparam integer WAIT_TIME_FOR_CLK_SYNC_SIM = 100;

    
    reg sync_reset; // To prevent bufg to share real pin to many module
    reg [27:0] wait_sync_reset; // To synchonus all modules setup
    
    // Wait Clock reset done first, then hold a time to wait other flip-flop reset
    always @(posedge clk) begin
        if(clk_reset) begin
            wait_sync_reset <= 0;
            sync_reset <= 1;
        end else begin
            if(wait_sync_reset <= (IS_SIM ? WAIT_TIME_FOR_CLK_SYNC_SIM : WAIT_TIME_FOR_CLK_SYNC)) begin
                wait_sync_reset <= wait_sync_reset + 1;
                sync_reset <= 1;
            end else begin
                sync_reset <= 0;
            end
        end
    end
    
    //----------------------------------- VGA Translator Section -----------------------------------------
    
    wire [9:0] x, y; // Current pixels x and y
    wire blank; // Is this in blank screen
    
    vga_translator vga_translate (
        .clk_display(clk_vga),
        .reset(sync_reset),
        
        .HS(HS),
        .VS(VS),
        .x(x),
        .y(y),
        .blank(blank)
    );
    
    //----------------------------------- Game Runtime && ROM Reader Section -----------------------------------------
    // TO declare size of hold memeory variable
    localparam integer MAXIMUM_STAGE = 8; // 256 stages
    localparam integer MAXIMUM_TIMES = 30; // 10,000,000.00 seconds
    localparam integer MAXIMUM_ATTACK_OBJECT = 20; // 1,000,000 objects
    localparam integer MAXIMUM_PLATFORM_OBJECT = 20; // 1,000,000 objects
    
    // To recursive stage when all data in rom was readed
    localparam integer INITIAL_STAGE = 0; // Default Start at stages 1
    localparam integer LAST_STAGE = 5; // Default End at stages 2
    
    // Internal Data Stream   
    // Assign with game_manager_contorl
    wire [MAXIMUM_STAGE-1:0] current_stage;
    wire [MAXIMUM_TIMES-1:0] current_time;
    wire [MAXIMUM_ATTACK_OBJECT-1:0] attack_i;
    wire [MAXIMUM_PLATFORM_OBJECT-1:0] platform_i;
    
    wire [2:0]  gravity_direction;
    wire [9:0]  display_pos_x1;
    wire [9:0]  display_pos_y1;
    wire [9:0]  display_pos_x2;
    wire [9:0]  display_pos_y2;
    
    // Assign with attack_object reader and platform_object_reader
    wire [MAXIMUM_TIMES-1:0] next_attack_time;
    wire [MAXIMUM_TIMES-1:0] next_platform_time;
    
    // Sychonus signal from game_manager_contorl (Normal: 1, Require update: 0)
    // Turn 0 when next_attack_time or next_platform_time >= current time
    // Turn 1 when update_attack_time or update_platfom_time = 1
    wire sync_attack_time;
    wire sync_platform_time;
    
    // Sychonus signal from attack_object reader and platform_object_reader (Normal: 0, Updated: 1)
    // Turn 1 when sync_attack_time or sync_platform_time = 0 (it will read data from rom and set next_time)
    // Trun 0 when sync_attack_time or sync_platform_time back to 1
    wire update_attack_time;
    wire update_platform_time;
    
    game_runtime #(
        .INITIAL_STAGE(INITIAL_STAGE),
        .MAXIMUM_STAGE(MAXIMUM_STAGE),
        .MAXIMUM_TIMES(MAXIMUM_TIMES),
        .MAXIMUM_ATTACK_OBJECT(MAXIMUM_ATTACK_OBJECT),
        .MAXIMUM_PLATFORM_OBJECT(MAXIMUM_PLATFORM_OBJECT),
        .LAST_STAGE(LAST_STAGE)
    ) game_runtime_execute (
        .clk(clk),
        .clk_centi_second(clk_centi_second),
        .reset(sync_reset),
        .next_attack_time(next_attack_time),
        .next_platform_time(next_platform_time),
        .update_attack_time(update_attack_time),
        .update_platform_time(update_platform_time),
        
        .gravity_direction(gravity_direction),
        .display_pos_x1(display_pos_x1),
        .display_pos_y1(display_pos_y1),
        .display_pos_x2(display_pos_x2),
        .display_pos_y2(display_pos_y2),
                
        .current_stage(current_stage),
        .current_time(current_time),
        .attack_i(attack_i),
        .platform_i(platform_i),
        .sync_attack_time(sync_attack_time),
        .sync_platform_time(sync_platform_time)
    );
    
    // Attack Object Data Stream   
    wire sync_attack_position;
    wire update_object_trigger_position;
    wire  [4:0]  attack_type;
    wire  [1:0]  attack_colider_type;
    wire  [2:0]  attack_movement_direction;
    wire  [4:0]  attack_speed;
    wire  [9:0]  attack_pos_x;
    wire  [9:0]  attack_pos_y;
    wire  [9:0]  attack_w;
    wire  [9:0]  attack_h;
    wire  [7:0]  attack_destroy_time;
    wire  [1:0]  attack_destroy_trigger;
    
    attack_object_rom #(
        .ADDR_WIDTH(MAXIMUM_ATTACK_OBJECT),
        .MAXIMUM_TIMES(MAXIMUM_TIMES)
    ) attack_object_reader (
        .clk(clk),
        .reset(sync_reset),
        .addr(attack_i),
        .current_time(current_time),
        .sync_attack_time(sync_attack_time),
        .update_attack_position(update_object_trigger_position),
        
        .update_attack_time(update_attack_time),
        .sync_attack_position(sync_attack_position),
        .next_attack_time(next_attack_time),
        .types(attack_type),
        .colider_type(attack_colider_type),
        .movement_direction(attack_movement_direction),
        .speed(attack_speed),
        .pos_x(attack_pos_x),
        .pos_y(attack_pos_y),
        .w(attack_w),
        .h(attack_h),
        .destroy_time(attack_destroy_time),
        .destroy_trigger(attack_destroy_trigger)
    );
    
    
    // Platform Object Data Stream   
    wire sync_platform_position;
    wire update_object_collider_position;
    wire  [2:0]  platform_movement_direction;
    wire  [4:0]  platform_speed;
    wire  [9:0]  platform_pos_x;
    wire  [9:0]  platform_pos_y;
    wire  [9:0]  platform_w;
    wire  [9:0]  platform_h;
    wire  [7:0]  platform_destroy_time;
    wire  [1:0]  platform_destroy_trigger;
        
    platform_object_rom #(
        .ADDR_WIDTH(MAXIMUM_PLATFORM_OBJECT),
        .MAXIMUM_TIMES(MAXIMUM_TIMES)
    ) platform_object_reader (
        .clk(clk),
        .reset(sync_reset),
        .addr(platform_i),
        .current_time(current_time),
        .sync_platform_time(sync_platform_time),
        .update_platform_position(update_object_collider_position),
        
        .update_platform_time(update_platform_time),
        .sync_platform_position(sync_platform_position),
        .next_platform_time(next_platform_time),
        .movement_direction(platform_movement_direction),
        .speed(platform_speed),
        .pos_x(platform_pos_x),
        .pos_y(platform_pos_y),
        .w(platform_w),
        .h(platform_h),
        .destroy_time(platform_destroy_time),
        .destroy_trigger(platform_destroy_trigger)
    );
    
    
    //----------------------------------- Game Display Section -----------------------------------------
    
    // Initialize Game Display parameters
    localparam integer GAME_DISPLAY_X0 = 130;
    localparam integer GAME_DISPLAY_Y0 = 251;
    localparam integer GAME_DISPLAY_X1 = 506;
    localparam integer GAME_DISPLAY_Y1 = 391;
    localparam integer GAME_DISPLAY_BORDER = 5;

    wire [9:0] game_display_x0;
    wire [9:0] game_display_y0;
    wire [9:0] game_display_x1;
    wire [9:0] game_display_y1;
    wire game_display_border_signal;
    
    game_display_controller #(
        .GAME_DISPLAY_X0(GAME_DISPLAY_X0),
        .GAME_DISPLAY_Y0(GAME_DISPLAY_Y0),
        .GAME_DISPLAY_X1(GAME_DISPLAY_X1),
        .GAME_DISPLAY_Y1(GAME_DISPLAY_Y1)
  
    ) game_display_control (
        .clk_object_control(clk_object_control),
        .reset(sync_reset),
        
        .display_pos_x1(display_pos_x1),
        .display_pos_y1(display_pos_y1),
        .display_pos_x2(display_pos_x2),
        .display_pos_y2(display_pos_y2),
        
        .game_display_x0(game_display_x0),
        .game_display_y0(game_display_y0),
        .game_display_x1(game_display_x1),
        .game_display_y1(game_display_y1)
    );
    
    game_display_renderer #(
        .BORDER(GAME_DISPLAY_BORDER)
   ) game_display_render (
       .x(x),
       .y(y),
       .game_display_x0(game_display_x0),
       .game_display_y0(game_display_y0),
       .game_display_x1(game_display_x1),
       .game_display_y1(game_display_y1),
       
       .render(game_display_border_signal)
   );
   
    //----------------------------------- Collider Object Runtimes Section  -----------------------------------------
    
    localparam MAXIMUM_COLLIDER_OBJECT_AMOUT = 30;
    
    wire object_colider_signal;
    wire [9:0] collider_ground_h_player;
    wire is_collider_ground_player;
    
    wire [9:0] player_pos_x;
    wire [9:0] player_pos_y;
    wire [9:0] player_w;
    wire [9:0] player_h;

    multi_object_collider_runtime # (
        .OBJECT_AMOUNT(MAXIMUM_COLLIDER_OBJECT_AMOUT)
    ) multi_object_collider_runtime_execute (
        .clk_object_control(clk_object_control),
        .clk_centi_second(clk_centi_second),
        .clk_calculation(clk_calculation),
        .reset(sync_reset),
        .x(x),
        .y(y),
        
        .player_pos_x(player_pos_x),
        .player_pos_y(player_pos_y),
        .player_w(player_w),
        .player_h(player_h),
        
        .object_movement_direction(platform_movement_direction),
        .object_pos_x(platform_pos_x),
        .object_pos_y(platform_pos_y),
        .object_w(platform_w),
        .object_h(platform_h),
        .object_speed(platform_speed),
        .object_destroy_time(platform_destroy_time),
        .object_destroy_trigger(platform_destroy_trigger),
        
        .display_pos_x1(display_pos_x1),
        .display_pos_y1(display_pos_y1),
        .display_pos_x2(display_pos_x2),
        .display_pos_y2(display_pos_y2),
        
        .sync_object_position(sync_platform_position),
        
        .update_object_position(update_object_collider_position),    
        .object_signal(object_colider_signal),
        
        .collider_ground_h_player(collider_ground_h_player),
        .is_collider_ground_player(is_collider_ground_player)
        
    );
    
    //----------------------------------- Trigger Object Runtimes Section -----------------------------------------
    
    localparam MAXIMUM_TRIGGER_OBJECT_AMOUT = 100;
    
    wire object_trigger_signal;
    wire trigger_player;
    
     multi_object_trigger_runtime #(
        .OBJECT_AMOUNT(MAXIMUM_TRIGGER_OBJECT_AMOUT)
     ) muti_object_trigger_runtime_execute (
       .clk_object_control(clk_object_control),
       .clk_centi_second(clk_centi_second),
       .clk_calculation(clk_calculation),
       .reset(sync_reset),
       .x(x),
       .y(y),
       
       .object_movement_direction(attack_movement_direction),
       .object_pos_x(attack_pos_x),
       .object_pos_y(attack_pos_y),
       .object_w(attack_w),
       .object_h(attack_h),
       .object_speed(attack_speed),
       .object_destroy_time(attack_destroy_time),
       .object_destroy_trigger(attack_destroy_trigger),
       
       .display_pos_x1(display_pos_x1),
       .display_pos_y1(display_pos_y1),
       .display_pos_x2(display_pos_x2),
       .display_pos_y2(display_pos_y2),
       
       .sync_object_position(sync_attack_position),
       
       .update_object_position(update_object_trigger_position),    
       .object_signal(object_trigger_signal)
   );
  
            
    //----------------------------------- Player Controller Section ----------------------------------------- 
    
    // Initialize Player parameters
    localparam integer INIT_PLAYER_POS_X = 316;
    localparam integer INIT_PLAYER_POS_y = 314;
    localparam integer INIT_PLAYER_W = 17;
    localparam integer INIT_PLAYER_H = 17;
    
    // Initialize Physic parameters
    localparam integer HORIZONTAL_SPEED = 15;
    localparam integer VERTICAL_SPEED = 22;  // 1/16 scale
    localparam integer GRAVITY = 8;  // 1/16 scale
    localparam integer MAX_FALLING_SPEED = 35; // 1/16 scale 
    localparam integer JUMP_H = 80; 


    // Player Data Stream
    wire player_render_signal;
    reg active_gravity = 1;
    
    player_position_controller #(
        .PLAYER_POS_X(INIT_PLAYER_POS_X),
        .PLAYER_POS_Y(INIT_PLAYER_POS_y),
        .PLAYER_W(INIT_PLAYER_W),
        .PLAYER_H(INIT_PLAYER_H)
        
    ) player_position(
        .clk_player_control(clk_player_control),
        .reset(sync_reset),
        .switch_up(switch_up),
        .switch_down(switch_down),
        .switch_left(switch_left),
        .switch_right(switch_right),
        .game_display_x0(game_display_x0),
        .game_display_y0(game_display_y0),
        .game_display_x1(game_display_x1),
        .game_display_y1(game_display_y1),
        .gravity_direction(gravity_direction),
        
        .collider_ground_h_player(collider_ground_h_player),
        .is_collider_ground_player(is_collider_ground_player),
        
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
    
    
    //----------------------------------- Universal Renderer Section  ----------------------------------------- 
    universal_renderer universal_render(
        .reset(sync_reset),
        .x(x),
        .y(y),
        .blank(blank),
        
        .game_display_border_render(game_display_border_signal),
        .object_colider_signal(object_colider_signal),
        .object_trigger_signal(object_trigger_signal),
        .player_render(player_render_signal),
        
        .RED(RED),
        .GREEN(GREEN),
        .BLUE(BLUE)
    );
    
endmodule