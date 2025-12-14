`timescale 1ns / 1ps

// Testbench for the topModule, designed to observe timing and control signals.
module Topsim_Collider_pipline_test;
    reg clk;
    reg reset;
    reg switch_up;
    reg switch_down;
    reg switch_left;
    reg switch_right;
    
    wire HS, VS;
    wire [3:0] RED, GREEN, BLUE;

    topModule #(
        .IS_SIM(1)
    ) dut (
        .clk(clk),
        .clk_reset(reset),
        .switch_up(switch_up),
        .switch_down(switch_down),
        .switch_left(switch_left),
        .switch_right(switch_right),
        .HS(HS),
        .VS(VS),
        .RED(RED),
        .GREEN(GREEN),
        .BLUE(BLUE)
    );

    always #1 clk = ~clk;

    initial begin
        // Initialize inputs
        clk <= 1'b1;
        reset <= 1'b1; // Start in reset
        
        switch_up <= 1'b0;
        switch_down <= 1'b0;
        switch_left <= 1'b0;
        switch_right <= 1'b0;

        // De-assert reset after 100ns
        #100 reset <= 1'b0;
        // Run for a longer period to ensure Game Manager cycles
        // Game manager clock is 10ms. Running for 100ms should show events.
        #1_000_000_000 // Wait 100ms (100,000,000 ns)

        // End simulation
        $finish;
    end
    
    wire [10-1:0] x;
    wire [10-1:0] y;
    
    assign x = dut.x;
    assign y = dut.y;
    
    wire [10-1:0] attack_i;
    wire [10-1:0] platform_i;
    assign attack_i        = dut.attack_i;
    assign platform_i      = dut.platform_i;
    
    // Display Log
    wire [9:0]  display_pos_x1;
    wire [9:0]  display_pos_y1;
    wire [9:0]  display_pos_x2;
    wire [9:0]  display_pos_y2;
    
    assign display_pos_x1 = dut.display_pos_x1;
    assign display_pos_y1 = dut.display_pos_y1;
    assign display_pos_x2 = dut.display_pos_x2;
    assign display_pos_y2 = dut.display_pos_y2;
    
    // Player Log
    wire on_ground;
    wire [13:0] jump_height_hires;
    wire [13:0] player_pos_x;
    wire [9:0] player_pos_y;
    wire [9:0] player_w;
    wire [13:0] falling_speed;
    
    assign jump_height_hires = dut.player_position.jump_height_hires;
    assign falling_speed = dut.player_position.falling_speed;
    assign on_ground = dut.player_position.on_ground;
    assign player_pos_x = dut.player_position.player_pos_x_hires;
    assign player_pos_y = dut.player_pos_y;
    assign player_w = dut.player_w;
    
    wire is_trigger_player;
    assign is_trigger_player = dut.is_trigger_player;
    
    
     wire is_collider_ground_player;
     wire [9:0] collider_ground_h_player;
     wire [9:0] collider_ground_w_player;
     
     assign collider_ground_h_player = dut.collider_ground_h_player;
     assign collider_ground_w_player = dut.multi_object_collider_runtime_execute.collider_ground_w_player;
     assign is_collider_ground_player = dut.is_collider_ground_player;
     
     wire [29:0] next_attack_time;
     assign next_attack_time = dut.game_runtime_execute.next_attack_time;
     
     wire is_end_game_manager;
     wire sync_game_manager;
     wire update_game_manager;
     
     assign is_end_game_manager = dut.game_runtime_execute.is_end;
     assign sync_game_manager = dut.game_runtime_execute.sync_game_manager;
     assign update_game_manager = dut.game_runtime_execute.update_game_manager;
     assign sync_attack_time = dut.game_runtime_execute.sync_attack_time;
     assign sync_platform_time = dut.game_runtime_execute.sync_platform_time;
     
     wire clk_centi_second;
//     wire [7:0] centi_second;
     wire [7:0] object_destroy_time;
     assign object_destroy_time = dut.multi_object_collider_runtime_execute.object_destroy_time;
     assign clk_centi_second = dut.multi_object_collider_runtime_execute.clk_centi_second;
//     assign centi_second = dut.multi_object_collider_runtime_execute.object_collider_position_control[i].centi_second;

    // Iterator Log
    localparam integer OBJECT_AMOUNT = 30;   
    wire [OBJECT_AMOUNT-1: 0] object_ready_state;
    
    assign object_ready_state = dut.multi_object_collider_runtime_execute.object_ready_state;
    
    wire [7:0] destroy_time;
    assign destroy_time = dut.attack_object_reader.destroy_time;
    
    wire [9:0] object_pos_y;
    wire sync_object_position;
    assign object_pos_y = dut.muti_object_trigger_runtime_execute.OBJECTS[79].object_collider_position_control.object_pos_y;
    assign object_free = dut.muti_object_trigger_runtime_execute.OBJECTS[79].object_collider_position_control.object_free;
    assign sync_object_position = dut.muti_object_trigger_runtime_execute.OBJECTS[79].object_collider_position_control.sync_object_position;
    
    // Iterator Log
    localparam integer OBJECT_AMOUNT_T = 80;   
    wire [OBJECT_AMOUNT_T-1: 0] object_ready_state_T;
    
    wire [10-1:0] ui_addr;
    wire ui_signal;
    wire reset_healt_status;
    wire [9:0]   healt_bar_pos_x;
    wire [9:0]   healt_bar_pos_y;
    wire [9:0]   healt_bar_w;
    wire [9:0]   healt_bar_h;
    wire [9:0]   healt_bar_w_minus;
    wire [6:0]   healt_bar_sensitivity;
    wire [15:0]  wait_time;
    wire [29:0]  next_ui_time;
    wire object_trigger_signal;
    wire update_ui_time;
    wire sync_ui_time;
    
    assign ui_signal = dut.ui_signal;
    assign object_trigger_signal = dut.object_trigger_signal;
    assign update_ui_time = dut.game_ui_runtime_execute.update_ui_time;
    assign sync_ui_time = dut.game_ui_runtime_execute.sync_ui_time;
    assign ui_addr = dut.game_ui_runtime_execute.addr;
    assign is_reset_stage = dut.is_reset_stage;
    assign healt_bar_pos_x = dut.game_ui_runtime_execute.healt_bar_pos_x;
    assign healt_bar_pos_y = dut.game_ui_runtime_execute.healt_bar_pos_y;
    assign healt_bar_w = dut.game_ui_runtime_execute.healt_bar_w;
    assign healt_bar_h = dut.game_ui_runtime_execute.healt_bar_h;
    assign healt_bar_w_minus = dut.game_ui_runtime_execute.healt_bar_w_minus;
    assign healt_bar_sensitivity = dut.game_ui_runtime_execute.healt_bar_sensitivity;
    assign wait_time = dut.game_ui_runtime_execute.wait_time;
    assign next_ui_time = dut.game_ui_runtime_execute.next_ui_time;
    
    assign object_ready_state_T = dut.muti_object_trigger_runtime_execute.object_ready_state;

    wire [19:0] character_i;
    wire [9:0] character_pos_x;
    
    assign character_i = dut.game_ui_runtime_execute.character_i;
    assign character_pos_x = dut.game_ui_runtime_execute.character_pos_x;

endmodule