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
    input  update_platform_position,
    
    output reg  sync_platform_position,
    output reg  update_platform_time,
    output reg  [MAXIMUM_TIMES-1:0] next_platform_time,
    output reg  [2:0]  movement_direction,
    output reg  [4:0]  speed,
    output reg  [9:0]  pos_x,
    output reg  [9:0]  pos_y,
    output reg  [9:0]  w,
    output reg  [9:0]  h,
    output reg  [7:0]  wait_time,
    output reg  [7:0]  destroy_time,
    output reg  [1:0]  destroy_trigger
);

    reg [63:0] rom [0:(1<<ADDR_WIDTH)-1];
    reg update_data;
        
    always @(posedge clk) begin
        if(reset) begin
            $readmemh("platform_object.mem", rom);
            update_data <= 0; 
            next_platform_time <= 0;
            sync_platform_position <= 1;
                        
        end else if(!sync_platform_time) begin
            // Update data sync with game runtime
            if(!update_data) begin
                movement_direction    <= rom[addr][63:61];
                speed           <= rom[addr][60:56];
                pos_x           <= rom[addr][55:48] << 2;
                pos_y           <= rom[addr][47:40] << 2;
                w               <= rom[addr][39:32] << 2;
                h               <= rom[addr][31:24] << 2;
                wait_time       <= rom[addr][23:16];
                destroy_time    <= rom[addr][15:8];
                destroy_trigger <= rom[addr][7:6];
                
                update_data <= 1;
            
            // Wait 1 cycle to sync flip flop update       
            end else begin
                // Set next platform time
                
                if(wait_time==0)
                    next_platform_time <= current_time + 3;
                else
                    next_platform_time <= current_time + wait_time*10;
                
                // Send out update to sync with game runtime module
                update_platform_time <= 1;
                
                // Send out sync to activate object_position_control module
                sync_platform_position <= 0;
            end
        
        // If sync_attack_time from game runtime module
        end else begin
            // Communicate with object_position module
            if(update_platform_position) begin
                sync_platform_position <= 1;
            end 
                    
            update_platform_time <= 0;
            update_data <= 0;
        end
    end
endmodule