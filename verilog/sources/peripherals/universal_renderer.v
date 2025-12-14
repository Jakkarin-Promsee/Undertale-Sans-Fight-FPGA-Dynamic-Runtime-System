`timescale 1ns / 1ps

module universal_renderer(
    input reset,
    input [9:0] x,
    input [9:0] y,
    input blank,   
    
    input is_trigger_player, 
    
    input transparent_out_screen_display,
    
    input object_colider_signal,
    input object_trigger_signal,
    input game_display_border_render,
    input out_side_display_signal,
    input healt_bar_signal,
    input healt_bar_border_signal,
    input character_signal,
    input player_render,
    
    output reg [3:0] RED,  
    output reg [3:0] GREEN,
    output reg [3:0] BLUE
);


    always @(*) begin
        if(!reset) begin
            // Blank Screen 
            if (blank) begin 
                RED   <= 0;
                GREEN <= 0;
                BLUE  <= 0;
            end 
            
            // Object Colider
            else if (object_colider_signal && !(out_side_display_signal && !transparent_out_screen_display)) begin
                RED   <= 0;
                GREEN <= 15;
                BLUE  <= 15;
            end 
            
            // Object Trigger
            else if (object_trigger_signal && !(out_side_display_signal && !transparent_out_screen_display)) begin
                RED   <= 15;
                GREEN <= 0;
                BLUE  <= 0;
            end
                        
            // Game display border
            else if (game_display_border_render) begin
                RED   <= 15;
                GREEN <= 15;
                BLUE  <= 15;
            end
            
            // Player
            else if (player_render) begin 
                RED   <= 0;
                GREEN <= 0;
                BLUE  <= 15;
            end 
            
            else if (healt_bar_border_signal) begin
                RED   <= 15;
                GREEN <= 15;
                BLUE  <= 15;
            end
            
            else if (healt_bar_signal) begin
                RED   <= 15;
                GREEN <= 5;
                BLUE  <= 5;
            end
            
            else if (character_signal) begin
                RED   <= 15;
                GREEN <= 15;
                BLUE  <= 15;
            end
            
            // Background
            else begin
                if(is_trigger_player && 0) begin
                    RED   <= 4;
                    GREEN <= 4;
                    BLUE  <= 4;
                    
                end else begin
                    RED <= 0;
                    GREEN <= 0;
                    BLUE  <= 0;
                end
                    
            end
        end
    end
endmodule