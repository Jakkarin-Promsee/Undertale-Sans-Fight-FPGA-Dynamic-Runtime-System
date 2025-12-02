`timescale 1ns / 1ps

module platform_object_rom #(
    parameter ADDR_WIDTH = 10              // 1024 entries
)(
    input  clk,
    input  [ADDR_WIDTH-1:0] addr,
    input  sync_platform_time,
    
    output reg  update_platform_time,
    output reg  [2:0]  movement_direction,
    output reg  [4:0]  speed,
    output reg  [7:0]  pos_x,
    output reg  [7:0]  pos_y,
    output reg  [7:0]  w,
    output reg  [7:0]  h,
    output reg  [7:0]  times
);

    reg [47:0] rom [0:(1<<ADDR_WIDTH)-1];

    initial begin
        $readmemh("platform_object.mem", rom);
    end

    always @(posedge clk) begin
        if(!sync_platform_time) begin
            movement_direction <= rom[addr][47:45];
            speed              <= rom[addr][44:40];
            pos_x              <= rom[addr][39:32];
            pos_y              <= rom[addr][31:24];
            w                  <= rom[addr][23:16];
            h                  <= rom[addr][15:8];
            times               <= rom[addr][7:0];
            
            update_platform_time <= 1;
        end else begin
            update_platform_time <= 0;
        end
    end
endmodule