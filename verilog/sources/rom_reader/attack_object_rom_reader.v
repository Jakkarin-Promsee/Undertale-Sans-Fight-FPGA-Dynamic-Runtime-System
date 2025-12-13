`timescale 1ns / 1ps

module attack_object_rom #(
    parameter integer ADDR_WIDTH = 10,              // 1024 entries
    parameter integer MAXIMUM_TIMES = 30
)(
    input clk,
    input reset,
    input [ADDR_WIDTH-1:0] addr,
    input [MAXIMUM_TIMES-1:0] current_time,
    input sync_attack_time,
    input update_attack_position,
    
    output reg  update_attack_time,
    output reg  sync_attack_position,
    output reg  [MAXIMUM_TIMES-1:0] next_attack_time,
    output reg  [4:0]  types,
    output reg  [1:0]  colider_type,
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
    reg  [0:0]  free_unused;

    reg [71:0] rom [0:(1<<ADDR_WIDTH)-1];
    reg update_data;


    always @(posedge clk) begin
        if(reset) begin
            $readmemh("attack_object.mem", rom);
            update_data <= 0; 
            next_attack_time <= 0;
            sync_attack_position <= 1;
            
        end else if(!sync_attack_time) begin
            // Update data sync with game runtime
            if(!update_data) begin
                types           <= rom[addr][71:67];
                colider_type    <= rom[addr][66:65];
                movement_direction    <= rom[addr][64:62];
                speed           <= rom[addr][61:57];
                pos_x           <= rom[addr][56:49] << 2;
                pos_y           <= rom[addr][48:41] << 2;
                w               <= rom[addr][40:33] << 2;
                h               <= rom[addr][32:25] << 2;
                wait_time       <= rom[addr][24:17];
                destroy_time    <= rom[addr][16:9];
                destroy_trigger <= rom[addr][8:7];
            
                update_data <= 1;
            
            // Wait 1 cycle to sync flip flop update                   
            end else begin
                // Set next attack time
                if(wait_time==0)
                    next_attack_time <= current_time+1;
                else
                    next_attack_time <= current_time + wait_time*10;
                
                // Send out update to sync with game runtime module
                update_attack_time <= 1;
                
                // Send out sync to activate object_position_control module
                sync_attack_position <= 0;
            end
            
        // If sync_attack_time from game runtime module
        end else begin
            // Communicate with object_position module
            if(update_attack_position) begin
                 sync_attack_position <= 1;
            end 
                    
            update_attack_time <= 0;
            update_data <= 0;
        end
    end
endmodule
