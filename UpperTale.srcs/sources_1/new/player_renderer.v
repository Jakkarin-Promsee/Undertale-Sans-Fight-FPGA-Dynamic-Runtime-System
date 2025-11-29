`timescale 1ns / 1ps

module player_renderer (
    input [9:0] x,
    input [9:0] y,
    input [9:0] player_pos_x,
    input [9:0] player_pos_y,
    input [9:0] player_w,
    input [9:0] player_h,
    
    output render
);
    
    // Player rectable 30*30 shape
    assign render = (x>=player_pos_x) && (x<player_pos_x+player_w) && (y>=player_pos_y) && (y<player_pos_y+player_h) ;

endmodule
