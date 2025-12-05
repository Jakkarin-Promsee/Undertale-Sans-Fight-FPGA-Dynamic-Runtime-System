`timescale 1ns / 1ps

// Testbench for the topModule, designed to observe timing and control signals.
module tb_topModule;
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

    // -----------------------------------------------------
    // 3.5. Internal Signal Mirroring (for easy debugging/graph)
    // -----------------------------------------------------
    // Assign top-level wires to the DUT's internal signals via hierarchical reference
    localparam integer MAXIMUM_STAGE = 8; // 256 stages
    localparam integer MAXIMUM_TIMES = 30; // 10,000,000.00 seconds
    localparam integer MAXIMUM_ATTACK_OBJECT = 20; // 1,000,000 objects
    localparam integer MAXIMUM_PLATFORM_OBJECT = 20; // 1,000,000 objects
        
    wire [MAXIMUM_STAGE-1:0] current_stage;
    wire [MAXIMUM_TIMES-1:0] current_time;
    wire [MAXIMUM_ATTACK_OBJECT-1:0] attack_i;
    wire [MAXIMUM_PLATFORM_OBJECT-1:0] platform_i;
    
    assign sync_reset = dut.sync_reset;
    assign current_stage = dut.current_stage;
    assign current_time    = dut.current_time;
    assign attack_i        = dut.attack_i;
    assign platform_i      = dut.platform_i;
    assign sync_attack     = dut.sync_attack_time;
    assign update_attack   = dut.update_attack_time;
    assign sync_platform   = dut.sync_platform_time;
    assign update_platform = dut.update_platform_time;
    
    
    wire [1:0] platform_destroy_trigger;
    assign platform_destroy_trigger = dut.platform_destroy_trigger;
    
    wire [9:0]  display_pos_x1;
    wire [9:0]  display_pos_y1;
    wire [9:0]  display_pos_x2;
    wire [9:0]  display_pos_y2;
    
    wire [9:0] player_pos_x;
    wire [9:0] player_pos_y;
    wire [9:0] collider_ground_h_player;
    
    assign player_pos_x = dut.player_pos_x;
    assign player_pos_y = dut.player_pos_y;
    assign is_collider_ground_player = dut.is_collider_ground_player;
    assign collider_ground_h_player = dut.collider_ground_h_player;
    
    assign display_pos_x1 = dut.display_pos_x1;
    assign display_pos_y1 = dut.display_pos_y1;
    assign display_pos_x2 = dut.display_pos_x2;
    assign display_pos_y2 = dut.display_pos_y2;
    
    assign attack_pos_x = dut.attack_object_reader.pos_x;
    assign attack_movement_direection = dut.attack_object_reader.movement_direction;
    
    assign sync_game_manager = dut.game_runtime_execute.sync_game_manager;
    assign update_game_manager = dut.game_runtime_execute.update_game_manager;
    
    
    localparam integer OBJECT_AMOUNT = 20;
    wire [OBJECT_AMOUNT-1: 0] object_ready_state ;  
    wire [OBJECT_AMOUNT-1: 0] sync_object_position_i ;
    wire [OBJECT_AMOUNT-1: 0] update_object_position_i ;
    wire [OBJECT_AMOUNT-1: 0] object_signal_i ;
    wire [OBJECT_AMOUNT-1: 0] object_free_i ;
    
    assign itertor_ready_state = dut.multi_object_collider_runtime_execute.itertor_ready_state;
   
    assign update_object_position_i = dut.multi_object_collider_runtime_execute.update_object_position_i;
    assign object_signal_i = dut.multi_object_collider_runtime_execute.object_signal_i;
    
    assign sync_object_position = dut.multi_object_collider_runtime_execute.sync_object_position;
    assign get_itertor_ready_state_state = dut.multi_object_collider_runtime_execute.get_itertor_ready_state_state;
    assign object_ready_state = dut.multi_object_collider_runtime_execute.object_ready_state;
    
    assign sync_object_position = dut.multi_object_collider_runtime_execute.sync_object_position;
    assign sync_object_position_i = dut.multi_object_collider_runtime_execute.sync_object_position_i;
    assign object_free_i = dut.multi_object_collider_runtime_execute.object_free_i;
    

    initial begin
        // Initialize inputs
        clk <= 1'b1;
        reset <= 1'b1; // Start in reset
        switch_up <= 1'b0;
        switch_down <= 1'b0;
        switch_left <= 1'b0;
        switch_right <= 1'b0;

        // Setup Waveform Tracing
        $dumpfile("topModule_sim.vcd");
        // Dump all signals from the current scope (tb_topModule) and its children (dut)
        $dumpvars(0, tb_topModule);

        // De-assert reset after 100ns
        #100 reset <= 1'b0;

        // Apply a brief input stimulus after reset is released
        #500
        switch_left <= 1'b0; // Move player left
        
        // Wait for player control clock to potentially tick (100Hz -> 10ms period)
        #200_000 // 200 us, ensuring several player control cycles
        switch_left <= 1'b0;

        // Wait longer to see ROM reading and synchronization events
        // The game manager clock is 100Hz (10ms period), so let's run for 50ms
        #500_000 // 500 us (0.5ms) - Still quite short, but enough to see divider outputs
        
        // Final stimulus to check another direction
        switch_up <= 1'b1;
        #100_000
        switch_up <= 1'b0;

        // Run for a longer period to ensure Game Manager cycles
        // Game manager clock is 10ms. Running for 100ms should show events.
        #1_000_000_000 // Wait 100ms (100,000,000 ns)

        // End simulation
        $finish;
    end
    
    reg [55:0] rom [0:10];
    wire  [7:0]  times;
    wire  [7:0]  pos_x;
    wire  [7:0]  w;
    
    assign times = rom[0][7:0];
    assign pos_x = rom[0][39:32];
    assign w = rom[0][23:16];
    
    initial begin
        $readmemh("attack_object.mem", rom);
        $display("ROM[0] = %h", rom[0]);
        
        
    end

    // -----------------------------------------------------
    // 5. Monitoring Internal Signals (for text output)
    // -----------------------------------------------------
    // Monitor Game Manager State (Time and Iterators) on the centi-second clock edge
//    always @(posedge dut.clk_centi_second) begin
//        $display("Time: %t | [GAME STATE] Time (centi-sec): %d | Attack Index (i): %d | Platform Index (i): %d",
//                 $time, tb_current_time, tb_attack_i, tb_platform_i);
//    end
    
    // Monitors the sync and update signals for the ROM readers on the main clock edge
//    always @(posedge clk) begin
//        if (tb_sync_attack)
//            $display("Time: %t | >>> ATTACK SYNC: Requesting next attack time.", $time);
//        if (tb_update_attack)
//            $display("Time: %t | !!! ATTACK UPDATE: New attack time received (Index: %d).", $time, tb_attack_i);
//        if (tb_sync_platform)
//            $display("Time: %t | >>> PLATFORM SYNC: Requesting next platform time.", $time);
//        if (tb_update_platform)
//            $display("Time: %t | !!! PLATFORM UPDATE: New platform time received (Index: %d).", $time, tb_platform_i);
//    end

endmodule