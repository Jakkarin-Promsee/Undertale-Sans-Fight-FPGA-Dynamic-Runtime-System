`timescale 1ns / 1ps

module game_manager_rom #(
    parameter integer ADDR_WIDTH = 8               // Number of entries = 2^ADDR_WIDTH
)(
    input  wire clk,
    input  wire [ADDR_WIDTH-1:0] addr,
    input sync_game_manager,
    
    output reg  [7:0]  stage,
    output reg  [9:0]  attack_amount,
    output reg  [9:0]  platform_amount,
    output reg  [3:0]  free_unused,
    output reg  [7:0]  wait_time,
    output reg update_game_manager
    
);

    // ROM storage
    reg [39:0] rom [0:(1<<ADDR_WIDTH)-1];  // 40-bit per entry

    // Load ROM
    initial begin
        $readmemh("game_manager.mem", rom);
    end

    // Read and unpack fields
    always @(posedge clk) begin
        if(!sync_game_manager) begin
            stage           <= rom[addr][39:32];    // 8 bits
            attack_amount   <= rom[addr][31:22];    // 10 bits
            platform_amount <= rom[addr][21:12];    // 10 bits
            free_unused     <= rom[addr][11:8];     // 4 bits
            wait_time       <= rom[addr][7:0];      // 8 bits
            
            update_game_manager <= 1;
        end else begin
            update_game_manager <= 0;
        end
    end
endmodule