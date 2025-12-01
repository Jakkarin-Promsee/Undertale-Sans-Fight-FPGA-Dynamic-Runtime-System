`timescale 1ns / 1ps

module player_position_controller#(
    parameter integer PLAYER_POS_X = 320,
    parameter integer PLAYER_POS_Y = 240,
    parameter integer PLAYER_W = 30,
    parameter integer PLAYER_H = 30,
    parameter integer HORIZONTAL_SPEED = 15,
    parameter integer VERTICAL_SPEED = 22,  // 1/16 scale
    parameter integer GRAVITY = 8,  // 1/16 scale
    parameter integer MAX_FALLING_SPEED = 35, // 1/16 scale from 1/16 Gravity (1/256)
    parameter integer JUMP_H = 80
    )(
    input clk_player_control,
    input reset,
    input switch_up,
    input switch_down,
    input switch_left,
    input switch_right,
    input [9:0] game_display_x0,
    input [9:0] game_display_y0,
    input [9:0] game_display_x1,
    input [9:0] game_display_y1,
    input active_gravity,
    
    output reg [9:0] player_pos_x,
    output reg [9:0] player_pos_y,
    output reg [9:0] player_w,
    output reg [9:0] player_h
    );

    // Scaling Factor: 16 (4 bits for fractional part)
    localparam SCALE_FACTOR_GRAVITY_BITS = 4;
    localparam SCALE_FACTOR_GRAVITY = 16;
    
    localparam SCALE_FACTOR_BITS = 4;
    localparam SCALE_FACTOR = 16;
    
    // Internal High-Resolution Registers (10 bits for integer + 4 bits for fraction = 14 bits)
    reg [9 + SCALE_FACTOR_BITS : 0] player_pos_x_hires;
    reg [9 + SCALE_FACTOR_BITS : 0] player_pos_y_hires;
    
    // Position Boundaries scaled up by SCALE_FACTOR (shifted left by 4)
    wire [9 + SCALE_FACTOR_BITS : 0] game_display_x0_hires;
    wire [9 + SCALE_FACTOR_BITS : 0] game_display_y0_hires;
    wire [9 + SCALE_FACTOR_BITS : 0] game_display_x1_hires;
    wire [9 + SCALE_FACTOR_BITS : 0] game_display_y1_hires;
    
    // Player width/height are also scaled for internal use
    wire [9 + SCALE_FACTOR_BITS : 0] player_w_hires;
    wire [9 + SCALE_FACTOR_BITS : 0] player_h_hires;

    // Scale up the boundary and size inputs
    assign game_display_x0_hires = game_display_x0 << SCALE_FACTOR_BITS;
    assign game_display_y0_hires = game_display_y0 << SCALE_FACTOR_BITS;
    assign game_display_x1_hires = game_display_x1 << SCALE_FACTOR_BITS;
    assign game_display_y1_hires = game_display_y1 << SCALE_FACTOR_BITS;
    
    assign player_w_hires = PLAYER_W << SCALE_FACTOR_BITS;
    assign player_h_hires = PLAYER_H << SCALE_FACTOR_BITS;
    
    // Player's visible size is constant
    initial begin
        player_w = PLAYER_W;
        player_h = PLAYER_H;
    end

    reg [9 + SCALE_FACTOR_GRAVITY_BITS: 0] falling_speed;
    reg on_ground;
    reg is_hold_switch_up;
    
    initial begin
        // Initialize high-resolution positions
        player_pos_x_hires = PLAYER_POS_X << SCALE_FACTOR_BITS;
        player_pos_y_hires = PLAYER_POS_Y << SCALE_FACTOR_BITS;
        
        // Initialize output positions (integer part only)
        player_pos_x = PLAYER_POS_X;
        player_pos_y = PLAYER_POS_Y;

        on_ground = 1;
        is_hold_switch_up = 0;
    end
    
    always @(posedge clk_player_control) begin
        if (!reset) begin
            // Reset high-resolution positions
            player_pos_x_hires <= PLAYER_POS_X << SCALE_FACTOR_BITS;
            player_pos_y_hires <= PLAYER_POS_Y << SCALE_FACTOR_BITS;
            
            player_w <= PLAYER_W;
            player_h <= PLAYER_H;
            is_hold_switch_up <= 0;
            on_ground <= 1;
            
        end else begin
            
            // --- Vertical Movement Logic ---
            
            // 1. Handle Jump/Up Input
            if (switch_up && ((is_hold_switch_up || on_ground)) || !active_gravity) begin
                // While player jump up, gravity set zero
                falling_speed <= 0;
            
                // If player is below upper wall, jupt up with speed
                if (player_pos_y_hires - VERTICAL_SPEED > game_display_y0_hires) begin
                    // Use SPEED directly (1 unit = 1/16th pixel)
                    player_pos_y_hires <= player_pos_y_hires - VERTICAL_SPEED; 
                    is_hold_switch_up <= 1;
                    on_ground <= 0; // Leaving the ground
                end else begin
                    player_pos_y_hires <= game_display_y0_hires; // Hit top boundary
                end
                
                // 1.1 If jump hit the upper wall
                if (player_pos_y_hires <= game_display_y0_hires) begin
                    is_hold_switch_up <= 0; // Release jump hold
                end
                
                // 1.2 If jump hit the height limit
                if (player_pos_y_hires <= game_display_y1_hires - player_h_hires - (JUMP_H*SCALE_FACTOR)) begin
                    is_hold_switch_up <= 0; // Release jump hold
                end
                
            end else begin
                is_hold_switch_up <= 0; // Release jump hold
            end

            // 2. Apply Gravity (Only if not moving up)
            if (!is_hold_switch_up) begin
                // Udpate falling speed
                if(falling_speed < (4 * SCALE_FACTOR_GRAVITY)) begin
                    falling_speed <= falling_speed + GRAVITY/3;
                end else if(falling_speed < (5 * SCALE_FACTOR_GRAVITY)) begin
                    falling_speed <= falling_speed + GRAVITY/2;
                end else if(falling_speed < (6 * SCALE_FACTOR_GRAVITY)) begin
                    falling_speed <= falling_speed + GRAVITY*2/3;
                end else if(falling_speed < (MAX_FALLING_SPEED * SCALE_FACTOR_GRAVITY)) begin
                    falling_speed <= falling_speed + GRAVITY;
                end else begin
                    falling_speed <= MAX_FALLING_SPEED * SCALE_FACTOR_GRAVITY;
                end
            
                // Use GRAVITY directly (1 unit = 1/16th pixel)
                if (player_pos_y_hires + (falling_speed>>SCALE_FACTOR_GRAVITY_BITS) - 2*SCALE_FACTOR < game_display_y1_hires - player_h_hires) begin
                    player_pos_y_hires <= player_pos_y_hires + (falling_speed>>SCALE_FACTOR_GRAVITY_BITS);
                end else begin
                    player_pos_y_hires <= game_display_y1_hires - player_h_hires + 2*SCALE_FACTOR;
                end
            end
            
            // 3. Handle Down Input
            if (switch_down && ~active_gravity) begin
                if (player_pos_y_hires + player_h_hires + VERTICAL_SPEED - 2*SCALE_FACTOR <= game_display_y1_hires) begin
                    // Use SPEED directly
                    player_pos_y_hires <= player_pos_y_hires + VERTICAL_SPEED; 
                end else begin
                   player_pos_y_hires <= (game_display_y1_hires - player_h_hires) + 2*SCALE_FACTOR;
                end
            end
            
            // 4. Update Ground Check
            // Check if the player is within GRAVITY scaled units of the bottom boundary
            if (game_display_y1_hires - player_pos_y_hires - player_h_hires + 2*SCALE_FACTOR <= GRAVITY) begin
                on_ground <= 1;
            end else begin
                on_ground <= 0;
            end
            
            // --- Horizontal Movement Logic ---
            
            // Left axis
            if(switch_left) begin
                // Use SPEED directly
                if (player_pos_x_hires - HORIZONTAL_SPEED >= game_display_x0_hires) begin
                    player_pos_x_hires <= player_pos_x_hires - HORIZONTAL_SPEED;
                end else begin
                    player_pos_x_hires <= game_display_x0_hires; // Snap to left boundary
                end
            end
            
            // Right axis
            if(switch_right) begin
                // Use SPEED directly
                if (player_pos_x_hires + player_w_hires + HORIZONTAL_SPEED - 2*SCALE_FACTOR <= game_display_x1_hires) begin
                    player_pos_x_hires <= player_pos_x_hires + HORIZONTAL_SPEED;
                end else begin
                    player_pos_x_hires <= (game_display_x1_hires - player_w_hires) + 2*SCALE_FACTOR;
                end
            end
            
            // --- Output Assignment (10-bit integer part only) ---
            // Divide by 16 by shifting right 4 bits to get the pixel integer value
            player_pos_x <= player_pos_x_hires >> SCALE_FACTOR_BITS;
            player_pos_y <= player_pos_y_hires >> SCALE_FACTOR_BITS;
            
        end
    end
endmodule