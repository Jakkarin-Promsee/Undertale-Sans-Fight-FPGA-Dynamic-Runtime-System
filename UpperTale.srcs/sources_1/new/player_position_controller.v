`timescale 1ns / 1ps

module player_position_controller#(
    parameter integer PLAYER_POS_X = 320,
    parameter integer PLAYER_POS_Y = 240,
    parameter integer PLAYER_W = 30,
    parameter integer PLAYER_H  = 30,
    parameter integer SPEED = 3,
    parameter integer GRAVITY = 2
    )(
    input clk_control,
    input reset,
    input switch_up,
    input switch_down,
    input switch_left,
    input switch_right,
    input [9:0] game_display_x0,
    input [9:0] game_display_y0,
    input [9:0] game_display_x1,
    input [9:0] game_display_y1,
    
    output reg [9:0] player_pos_x,
    output reg [9:0] player_pos_y,
    output reg [9:0] player_w,
    output reg [9:0] player_h
    );
    
    // Intial Postion Player at center display
    initial begin
        player_pos_x = PLAYER_POS_X;
        player_pos_y = PLAYER_POS_Y;
        player_w = PLAYER_W;
        player_h = PLAYER_H;
    end
        
    // physic clock work at 100Hz
    always @(posedge clk_control) begin
        // Set player center in display
        if (!reset) begin
            player_pos_x = PLAYER_POS_X;
            player_pos_y = PLAYER_POS_Y;
            player_w = PLAYER_W;
            player_h = PLAYER_H;
            
        end else begin
            if(switch_up) begin
                if (player_pos_y > game_display_y0)
                    player_pos_y <= player_pos_y - SPEED;
            end else begin
                if (player_pos_y < game_display_y1 - player_h) 
                    player_pos_y <= player_pos_y + GRAVITY;
            end
            
            if(switch_down) begin
                if (player_pos_y < game_display_y1 - player_h) 
                    player_pos_y <= player_pos_y + SPEED;
            end 
            
            if(switch_left) begin
                if (player_pos_x > game_display_x0)
                    player_pos_x <= player_pos_x - SPEED;
            end
            
            if(switch_right) begin
                if (player_pos_x < game_display_x1 - player_w)
                    player_pos_x <= player_pos_x + SPEED;
            end   
        end
    end
endmodule
