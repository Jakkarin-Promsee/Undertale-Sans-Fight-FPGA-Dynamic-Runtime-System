`timescale 1ns / 1ps

module game_display_renderer #(
    parameter integer BORDER = 5
    ) (
    input [9:0] x,
    input [9:0] y,
    input [9:0] game_display_x0,
    input [9:0] game_display_y0,
    input [9:0] game_display_x1,
    input [9:0] game_display_y1,
    
    output render
);
    
    // Border logic
    wire normal_size =
        (x >= game_display_x0) &&
        (x <= game_display_x1) &&
        (y >= game_display_y0) &&
        (y <= game_display_y1);
    
    wire border_size =
        (x >= game_display_x0 - BORDER) &&
        (x <= game_display_x1 + BORDER) &&
        (y >= game_display_y0 - BORDER) &&
        (y <= game_display_y1 + BORDER);
    
    assign render = border_size && (~normal_size);

endmodule
