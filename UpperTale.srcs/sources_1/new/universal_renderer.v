`timescale 1ns / 1ps

module universal_renderer(
    input [9:0] x,
    input [9:0] y,
    input blank,   
       
    input game_display_border_render,
    input player_render,
    
    output reg [3:0] RED,  
    output reg [3:0] GREEN,
    output reg [3:0] BLUE
);


    always @(*) begin
        // Blank Screen 
        if (blank) begin 
            RED   = 0;
            GREEN = 0;
            BLUE  = 0;
        end 
        
        // Game display border
        else if (game_display_border_render) begin
            RED   = 15;
            GREEN = 15;
            BLUE  = 15;
        end
        
        // Player
        else if (player_render) begin 
            RED   = 0;
            GREEN = 15;
            BLUE  = 0;
        end 
        
        // Background
        else begin
            RED   = 0;
            GREEN = 0;
            BLUE  = 0;
        end
    end

endmodule