`timescale 1ns / 1ps

module game_manager_rom #(
    parameter integer ADDR_WIDTH = 8               // Number of entries = 2^ADDR_WIDTH
)(
    input  wire clk,
    input wire  reset,
    input  wire [ADDR_WIDTH-1:0] addr,
    input sync_game_manager,
    
    output reg  [7:0]  stage,
    output reg  [9:0]  attack_amount,
    output reg  [9:0]  platform_amount,
    output reg  [2:0]  gravity_direction,
    output reg  [9:0]  display_pos_x1,
    output reg  [9:0]  display_pos_y1,
    output reg  [9:0]  display_pos_x2,
    output reg  [9:0]  display_pos_y2,
    output reg  [7:0]  wait_time,
    
    output reg update_game_manager,
    
    output reg is_end
    
);

    // ROM storage
    reg [71:0] rom [0:(1<<ADDR_WIDTH)-1];  // 40-bit per entry
    
    reg update_data;

    // Read and unpack fields
    always @(posedge clk) begin
        // Load ROM
        if(reset) begin
            $readmemh("game_manager.mem", rom);
            is_end <= 0;
            update_data <= 0;
            
        end else if(!sync_game_manager) begin
            if(!update_data) begin
                stage            <= rom[addr][71:64];
                attack_amount    <= rom[addr][63:54];
                platform_amount  <= rom[addr][53:44];
                gravity_direction<= rom[addr][43:41];
                display_pos_x1   <= rom[addr][40:33] << 2;
                display_pos_y1   <= rom[addr][32:25] << 2;
                display_pos_x2   <= rom[addr][24:17] << 2;
                display_pos_y2   <= rom[addr][16:9]  << 2;
                wait_time        <= rom[addr][8:1];
                
                update_data <= 1;
                is_end <= &rom[addr];
                
            end else begin
                update_game_manager <= 1;
            end
            
        end else begin
            update_game_manager <= 0;
            update_data <= 0;
        end
    end
endmodule