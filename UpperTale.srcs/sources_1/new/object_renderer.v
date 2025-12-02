`timescale 1ns / 1ps

module object_renderer(
    input [9:0] x,
    input [9:0] y,
    input [9:0] object_pos_x,
    input [9:0] object_pos_y,
    input [9:0] object_w,
    input [9:0] object_h,
    
    output render
);
    
    assign render = (x >= (object_pos_x<<2)) && (x < (object_pos_x<<2) + (object_w<<2)) 
                    && (y >= (object_pos_y<<2)) && (y < (object_pos_y<<2) + (object_h<<2)) ;

endmodule
