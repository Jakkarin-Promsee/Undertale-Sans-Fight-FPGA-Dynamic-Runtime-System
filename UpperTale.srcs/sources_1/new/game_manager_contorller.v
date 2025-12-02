`timescale 1ns / 1ps

module game_manager_contorller#(
    parameter integer INITIAL_STAGE = 0,
    parameter integer MAXIMUM_STAGE = 8, // 256 stage
    parameter integer MAXIMUM_TIMES = 30, // 10,000,000.00 second
    parameter integer MAXIMUM_ATTACK = 20, // 1,000,000
    parameter integer MAXIMUM_PLATFORM = 20 // 1,000,000
)(
    input clk,
    input clk_centi_second,
    input reset,
    input[MAXIMUM_TIMES-1:0] next_attack_time,
    input[MAXIMUM_TIMES-1:0] next_platform_time,
    input update_attack_time,
    input update_platform_time,
    
    output reg [MAXIMUM_STAGE-1:0] current_stage,
    output reg [MAXIMUM_TIMES-1:0] current_time,
    output reg [MAXIMUM_ATTACK-1:0] attack_i,
    output reg [MAXIMUM_PLATFORM-1:0] platform_i,
    output reg sync_attack_time,
    output reg sync_platform_time
    );
    
    wire [7:0] stage;
    wire [9:0] attack_amount;
    wire [9:0] platform_amount;
    wire [7:0] wait_time;
    
    reg [MAXIMUM_TIMES-1:0] next_game_manager_time;
    reg sync_game_manager;
    wire update_game_manager;

    game_manager_rom game_manager_reader (
        .clk(clk),
        .addr(current_stage),
        .sync_game_manage(sync_game_manager),
        
        .stage(stage),
        .attack_amount(attack_amount),
        .platform_amount(platform_amount),
        .free_unused(),
        .wait_time(wait_time),
        .update_game_manager(update_game_manager)
    );
    
    reg count_attack;
    reg count_platform;
    
    initial begin
        current_stage = INITIAL_STAGE;
        current_time = 0;
        attack_i = 0;
        platform_i = 0;
        sync_game_manager = 0;
        count_attack = 0;
        count_platform = 0;
    end
    
    always @(posedge clk) begin
        if(!reset) begin
            current_stage <= INITIAL_STAGE;
            current_time <= 0;
            attack_i <= 0;
            platform_i <= 0;
            sync_game_manager <= 0;
            count_attack <= 0;
            count_platform <= 0;
            
        end else begin
            if(sync_game_manager) begin
                // Wanting to update attack_i once, but both update and sysnc use 2 cycles
                // Making we have to and sync_attack_time again
                if(current_time >= next_attack_time && !update_attack_time && sync_attack_time) begin
       
                    // If the we reach attack limit, change sync_game_manager to 0 
                    // Making we have to update manager first
                    if(count_attack + 1 >= attack_amount) begin
                        current_stage <= current_stage + 1;
                        sync_game_manager <= 0;
                    end else begin
                        attack_i <= attack_i + 1;
                        count_attack <= count_attack+ 1;
                        sync_attack_time <= 0;
                        next_game_manager_time <= next_game_manager_time + wait_time;
                    end
                end 
                
                // If already update_attack_time, change syns back to 1 again
                if(update_attack_time) begin
                    sync_attack_time <= 1;
                end
                
                
                // Wanting to update platform_i once, but both update and sysnc use 2 cycles
                // Making we have to and sync_platform_time again
                if(current_time >= next_platform_time && !update_platform_time && sync_platform_time) begin
                    
                    // If the we reach platform limit, change sync_game_manager to 0 
                    // Making we have to update manager first
                    if(count_platform + 1 >= platform_amount) begin
                        current_stage <= current_stage + 1;
                        sync_game_manager <= 0;
                    end else begin
                        platform_i <= platform_i + 1;
                        count_platform <= count_platform + 1;
                        sync_platform_time <= 0;
                        next_game_manager_time <= next_game_manager_time + wait_time;
                    end
                end 
                
                // If already update_attack_time, change syns back to 1 again
                if(update_platform_time) begin
                    sync_platform_time <= 1;
                end
            
            // if sync_game_manager isn't sync
            end else begin
            
                // if update_game_manager has updated, mean we're synchonizing now
                // sync_platform_time and update attack and platform again
                if(update_game_manager && current_time >= next_game_manager_time) begin
                    
                    // Set back to 1 to make loop again
                    sync_game_manager <= 1;
                    
                    // Update iterator
                    attack_i <= attack_i + 1;
                    platform_i <= platform_i + 1;
                    
                    // Reset count
                    count_attack <= 0;
                    count_platform <= 0;
                    
                    // Sendsignal to update time
                    sync_attack_time <= 0;
                    sync_platform_time <= 0;
                end
            end
        end
    end
    
    // Update current time 0.01 second
    always @(posedge clk_centi_second) begin
        if(!reset) begin
            current_time <= 0;
        end else begin
            current_time <= current_time + 1;
        end
    end
    
endmodule
