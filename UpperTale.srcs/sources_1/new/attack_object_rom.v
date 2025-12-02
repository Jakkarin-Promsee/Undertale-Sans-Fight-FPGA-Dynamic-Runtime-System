`timescale 1ns / 1ps

module attack_object_rom #(
    parameter integer ADDR_WIDTH = 10              // 1024 entries
)(
    input clk,
    input [ADDR_WIDTH-1:0] addr,
    input sync_attack_time,
    
    output reg update_attack_time,
    output reg  [4:0]  types,
    output reg  [1:0]  colider_type,
    output reg  [2:0]  movement_direction,
    output reg  [4:0]  speed,
    output reg  [0:0]  free_unused,
    output reg  [7:0]  pos_x,
    output reg  [7:0]  pos_y,
    output reg  [7:0]  w,
    output reg  [7:0]  h,
    output reg  [7:0]  times
);

    reg [55:0] rom [0:(1<<ADDR_WIDTH)-1];

    initial begin
        $readmemh("attack_object.mem", rom);
    end

    always @(posedge clk) begin
        if(!sync_attack_time) begin
            types               <= rom[addr][55:51];
            colider_type       <= rom[addr][50:49];
            movement_direction <= rom[addr][48:46];
            speed              <= rom[addr][45:41];
            free_unused        <= rom[addr][40];
            pos_x              <= rom[addr][39:32];
            pos_y              <= rom[addr][31:24];
            w                  <= rom[addr][23:16];
            h                  <= rom[addr][15:8];
            times               <= rom[addr][7:0];
            
            update_attack_time <= 1;
        end else begin
            update_attack_time <= 0;
        end
    end
endmodule
