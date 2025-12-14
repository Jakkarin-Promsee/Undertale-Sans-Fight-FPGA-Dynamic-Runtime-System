`timescale 1ns / 1ps

module character_object_rom_reader #(
    parameter integer ADDR_WIDTH = 10              // 1024 entries
)(
    input clk,
    input reset,
    input [ADDR_WIDTH-1:0] addr,

    input sync_character,
    
    output reg update_character,
    
    output reg [9:0]   character_pos_x,
    output reg [9:0]   character_pos_y,
    output reg [7:0]   character_index
);

    reg [23:0] rom [0:(1<<ADDR_WIDTH)-1];
    reg update_data;

    always @(posedge clk) begin
        if(reset) begin
            $readmemh("character_object.mem", rom);
            update_data <= 0; 
            
        end else if(!sync_character) begin
            // Update data sync with game runtime
            if(!update_data) begin
                character_pos_x             = rom[addr][23:16] << 2;
                character_pos_y             = rom[addr][15:8] << 2;
                character_index             = rom[addr][7:0];

                update_data <= 1;
                
            
            // Wait 1 cycle to sync flip flop update                   
            end else begin
                update_character <= 1;
            end
            
        // If sync_attack_time from game runtime module
        end else begin  
            update_data <= 0;                  
            update_character <= 0;
        end
    end
endmodule