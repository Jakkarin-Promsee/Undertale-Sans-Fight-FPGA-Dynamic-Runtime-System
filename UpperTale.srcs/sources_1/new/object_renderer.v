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
    
    assign render = (x >= (object_pos_x)) && (x < (object_pos_x) + (object_w)) 
                    && (y >= (object_pos_y)) && (y < (object_pos_y) + (object_h)) ;

endmodule
