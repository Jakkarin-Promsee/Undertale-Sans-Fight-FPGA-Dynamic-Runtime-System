`timescale 1ns / 1ps

module game_ui_rom_reader #(
    parameter integer ADDR_WIDTH = 10,              // 1024 entries
    parameter integer MAXIMUM_TIMES = 30
)(
    input clk,
    input reset,
    input [ADDR_WIDTH-1:0] addr,
    input [MAXIMUM_TIMES-1:0] current_time,
    input sync_ui_time,
    
    output reg update_ui_time,
    
    output reg         show_healt_text,
    output reg         reset_character,
    output reg [9:0]   character_amount,
    output reg [9:0]   healt_current,
    output reg [9:0]   healt_max,
    output reg         transparent_out_screen_display,
    output reg         reset_when_dead,
    output reg [9:0]   healt_bar_pos_x,
    output reg [9:0]   healt_bar_pos_y,
    output reg [9:0]   healt_bar_w,
    output reg [9:0]   healt_bar_h,
    output reg [6:0]   healt_bar_sensitivity,
    output reg [15:0]  wait_time,
    output reg [MAXIMUM_TIMES-1:0] next_ui_time,
    
    output reg is_end
);

    reg [87:0] rom [0:(1<<ADDR_WIDTH)-1];
    reg update_data;

    always @(posedge clk) begin
        if(reset) begin
            $readmemh("game_ui.mem", rom);
            update_data <= 0; 
            next_ui_time <= 0;
            is_end <= 0;
            
        end else if(!sync_ui_time) begin
            // Update data sync with game runtime
            if(!update_data) begin
                show_healt_text   = rom[addr][84];
                reset_character   = rom[addr][83];
                character_amount  = rom[addr][82:73];
                healt_current     = rom[addr][72:65] << 2;
                healt_max         = rom[addr][64:57] << 2;
                transparent_out_screen_display    = rom[addr][56];
                reset_when_dead       = rom[addr][55];
                healt_bar_pos_x       = rom[addr][54:47] << 2;
                healt_bar_pos_y       = rom[addr][46:39] << 2;
                healt_bar_w           = rom[addr][38:31] << 2;
                healt_bar_h           = rom[addr][30:23] << 2;
                healt_bar_sensitivity = rom[addr][22:16];
                wait_time             = rom[addr][15:0];

                update_data <= 1;
                
                is_end = &rom[addr];
            
            // Wait 1 cycle to sync flip flop update                   
            end else begin
                // Set next attack time
                if(wait_time==0)
                    next_ui_time <= current_time + 3;
                else
                    next_ui_time <= current_time + wait_time*10;
                
                // Send out update to sync with game runtime module
                update_ui_time <= 1;
            end
            
        // If sync_attack_time from game runtime module
        end else begin  
            update_data <= 0;                  
            update_ui_time <= 0;
        end
    end
endmodule