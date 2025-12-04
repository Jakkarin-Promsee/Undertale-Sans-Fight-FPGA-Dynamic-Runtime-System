`timescale 1ns / 1ps

module game_runtime#(
    parameter integer INITIAL_STAGE = 0,
    parameter integer MAXIMUM_STAGE = 8,    // Stage index bit width (e.g., 8 bits for 256 stages)
    parameter integer MAXIMUM_TIMES = 30,   // Time index bit width (e.g., 30 bits)
    parameter integer MAXIMUM_ATTACK_OBJECT = 20,  // Attack index bit width
    parameter integer MAXIMUM_PLATFORM_OBJECT = 20, // Platform index bit width
    parameter integer LAST_STAGE = 2
)(
    input clk,
    input clk_centi_second,
    input reset,
    
    // Inputs from external Attack/Platform modules (next spawn time and update acknowledgment)
    input [MAXIMUM_TIMES-1:0] next_attack_time,
    input [MAXIMUM_TIMES-1:0] next_platform_time,
    input update_attack_time,   // Asserted by external module when time is updated
    input update_platform_time, // Asserted by external module when time is updated
    
    // Outputs
    output wire [2:0] gravity_direction,
    output wire [9:0] display_pos_x1,
    output wire [9:0] display_pos_y1,
    output wire [9:0] display_pos_x2,
    output wire [9:0] display_pos_y2,
    
    output reg [MAXIMUM_STAGE-1:0] current_stage,
    output reg [MAXIMUM_TIMES-1:0] current_time,
    output reg [MAXIMUM_ATTACK_OBJECT-1:0] attack_i,
    output reg [MAXIMUM_PLATFORM_OBJECT-1:0] platform_i,
    output reg sync_attack_time,   // Request/Enable signal for attack spawning
    output reg sync_platform_time  // Request/Enable signal for platform spawning
    );
    
    // Wires from the ROM module
    wire [7:0] stage;
    wire [9:0] attack_amount;
    wire [9:0] platform_amount;
    wire [7:0] wait_time;
    
    reg [MAXIMUM_TIMES-1:0] next_game_manager_time;
    reg  sync_game_manager;      // State machine signal: 1=Spawning, 0=Stage Transition/Wait
    wire update_game_manager;   // Asserted by ROM module when data is ready

    // Instantiate ROM reader (Note: 'game_manager_rom' module assumed to be defined elsewhere)
    game_manager_rom game_manager_reader (
        .clk(clk),
        .reset(reset),
        .addr(current_stage),
        .sync_game_manager(sync_game_manager),
        
        .stage(stage),
        .attack_amount(attack_amount),
        .platform_amount(platform_amount),
        .gravity_direction(gravity_direction),
        .display_pos_x1(display_pos_x1),
        .display_pos_y1(display_pos_y1),
        .display_pos_x2(display_pos_x2),
        .display_pos_y2(display_pos_y2),
       
        .wait_time(wait_time),
        .update_game_manager(update_game_manager)
    );
    
    reg [9:0] count_attack;   // Counts attacks spawned in the current stage
    reg [9:0] count_platform; // Counts platforms spawned in the current stage
    
    // Main FSM and Spawning Logic
    always @(posedge clk) begin
        if(reset) begin
            // Asynchronous Reset
            current_stage <= INITIAL_STAGE;
            
            attack_i <= 0;
            platform_i <= 0;
            
            count_attack <= 0;
            count_platform <= 0;
            
            next_game_manager_time <= 0;
            
            sync_game_manager <= 0;
            sync_attack_time <= 0;
            sync_platform_time <= 0;
            
        end else begin
            
            // --- State 1: Synchronized (Spawning Events) ---
            if(sync_game_manager) begin
                
                // 1. Attack Spawning Logic (2-Cycle Handshake)
                // Trigger condition: Current time reached spawn time, external module is NOT busy, and we are ready to spawn (sync_attack_time=1)
                if(current_time >= next_attack_time && sync_attack_time) begin
    
                    if(count_attack + 1 >= attack_amount) begin
                        // Stage End: Attack limit reached -> Transition to waiting state
                        if(current_stage + 1 < LAST_STAGE) begin
                            current_stage <= current_stage + 1;
                            attack_i <= attack_i + 1;
                            platform_i <= platform_i + 1;
                        end else begin

                            current_stage <= 0;
                            attack_i <= 0;
                            platform_i <= 0;
                        end
                            
                        sync_game_manager <= 0;
                        next_game_manager_time <= current_time + wait_time;
                    end else begin
                        // Spawn Next Attack
                        attack_i <= attack_i + 1;
                        count_attack <= count_attack + 1;
                        sync_attack_time <= 0; // Request external module to update next_attack_time
                    end
                end 
                
                // Acknowledgment from external module: Allows next spawn
                if(update_attack_time) begin
                    sync_attack_time <= 1;
                end
                
                
                // 2. Platform Spawning Logic (2-Cycle Handshake)
                // Trigger condition: Current time reached spawn time, external module is NOT busy, and we are ready to spawn (sync_platform_time=1)
                if(current_time >= next_platform_time && sync_platform_time) begin
                    
                    if(count_platform + 1 >= platform_amount) begin
                        // Stage End: Platform limit reached -> Transition to waiting state
//                        if(current_stage + 1 < LAST_STAGE) begin
//                            current_stage <= current_stage + 1;
//                        end else begin
//                            current_stage <= 0;
//                            attack_i <= 0;
//                            platform_i <= 0;
//                        end
                                                    
//                        sync_game_manager <= 0;
//                        next_game_manager_time <= current_time + wait_time;
                    end else begin
                        // Spawn Next Platform
                        platform_i <= platform_i + 1;
                        count_platform <= count_platform + 1;
                        sync_platform_time <= 0; // Request external module to update next_platform_time
                    end
                end 
                
                // Acknowledgment from external module: Allows next spawn
                if(update_platform_time) begin
                    sync_platform_time <= 1;
                end
            
            // --- State 0: Desynchronized (Waiting for ROM/Wait Time) ---
            end else begin
            
                // Transition Back to Spawning State
                // Condition: ROM data is ready (update_game_manager) AND wait time has passed
                if(update_game_manager && current_time >= next_game_manager_time) begin
                    
                    sync_game_manager <= 1; // Re-enter spawning state
                    
                    // Reset count for the new stage
                    count_attack <= 0;
                    count_platform <= 0;
                    
                    // Request external modules to calculate initial spawn times for the new stage
                    sync_attack_time <= 0;
                    sync_platform_time <= 0;
                end
            end
        end
    end
    
    // Time Keeping Logic (using clk_centi_second, e.g., 100Hz)
    reg [MAXIMUM_TIMES: 0] centi_time;
    
    always @(posedge clk_centi_second) begin
        if(reset) begin
            centi_time <= 0;
            current_time <= 0;
        end else begin
            centi_time <= centi_time + 1;
            
            // current_time updates every 10 centi_seconds (e.g., 100ms/1 decisecond unit)
            // This is an integer division, assuming time unit is 100ms
            current_time <= centi_time/10;
        end
    end
    
endmodule