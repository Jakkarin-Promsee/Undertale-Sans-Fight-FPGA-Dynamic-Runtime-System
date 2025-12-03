`timescale 1ns / 1ps

module platform_object_rom #(
    parameter integer ADDR_WIDTH = 10,              // 1024 entries
    parameter integer MAXIMUM_TIMES = 30
)(
    input  clk,
    input reset,
    input  [ADDR_WIDTH-1:0] addr,
    input  [MAXIMUM_TIMES-1:0] current_time,
    input  sync_platform_time,
    
    output reg  update_platform_time,
    output reg  [MAXIMUM_TIMES-1:0] next_platform_time,
    output reg  [2:0]  movement_direction,
    output reg  [4:0]  speed,
    output reg  [9:0]  pos_x,
    output reg  [9:0]  pos_y,
    output reg  [9:0]  w,
    output reg  [9:0]  h,
    output reg  [7:0]  times
);

    reg [47:0] rom [0:(1<<ADDR_WIDTH)-1];
    reg update_data;
        
    always @(posedge clk) begin
        if(reset) begin
            $readmemh("platform_object.mem", rom);
            update_data <= 0; 
            next_platform_time <= 0;
        end else if(!sync_platform_time) begin
            if(!update_data) begin
                movement_direction <= rom[addr][47:45];
                speed              <= rom[addr][44:40];
                pos_x              <= rom[addr][39:32] << 2;
                pos_y              <= rom[addr][31:24] << 2;
                w                  <= rom[addr][23:16] << 2;
                h                  <= rom[addr][15:8] << 2;
                times               <= rom[addr][7:0];
                
                update_data <= 1;
                
            end else begin
                next_platform_time <= current_time + times;
                update_platform_time <= 1;
            end
        end else begin
            update_platform_time <= 0;
            update_data <= 0;
        end
    end
endmodule