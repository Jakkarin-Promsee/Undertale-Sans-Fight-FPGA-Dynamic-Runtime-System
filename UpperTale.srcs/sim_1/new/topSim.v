`timescale 1ns / 1ps

// Testbench for the topModule, designed to observe timing and control signals.
module tb_topModule;

    // -----------------------------------------------------
    // 1. Testbench Signals (Registers and Wires)
    // -----------------------------------------------------

    // Clock and Reset
    reg clk;
    reg reset;

    // Controller Inputs (Mock Stimulus)
    reg switch_up;
    reg switch_down;
    reg switch_left;
    reg switch_right;

    // Outputs from the DUT (not strictly needed for testing logic, but required for instantiation)
    wire HS, VS;
    wire [3:0] RED, GREEN, BLUE;

    // Clock Period definition (50MHz clock -> 20ns period)
    parameter CLK_PERIOD = 20; // 20ns for a 50MHz clock

    // Monitored Internal Game Signals (Mirrors of DUT internal wires)
    // Assuming MAXIMUM_TIMES=30, MAXIMUM_ATTACK=20, MAXIMUM_PLATFORM=20 from topModule
    wire [29:0] tb_current_time;
    wire [19:0] tb_attack_i;
    wire [19:0] tb_platform_i;
    wire tb_sync_attack;
    wire tb_update_attack;
    wire tb_sync_platform;
    wire tb_update_platform;
    
    wire [29:0] next_attack_time;
        wire [29:0] next_platform_time;
        wire [29:0] attack_current_time;
        
        wire [7:0] attack_times;
         wire [7:0] attack_pos_x;
        
        wire sync_game_manager;
        wire update_game_manager;

    // -----------------------------------------------------
    // 2. Instantiate the Device Under Test (DUT)
    // -----------------------------------------------------

    topModule dut (
        .clk(clk),
        .reset(reset),
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

    // -----------------------------------------------------
    // 3. Clock Generation
    // -----------------------------------------------------

    always #1 clk = ~clk;

    // -----------------------------------------------------
    // 3.5. Internal Signal Mirroring (for easy debugging/graph)
    // -----------------------------------------------------
    // Assign top-level wires to the DUT's internal signals via hierarchical reference
    assign tb_current_time    = dut.current_time;
    assign tb_attack_i        = dut.attack_i;
    assign tb_platform_i      = dut.platform_i;
    assign tb_sync_attack     = dut.sync_attack_time;
    assign tb_update_attack   = dut.update_attack_time;
    assign tb_sync_platform   = dut.sync_platform_time;
    assign tb_update_platform = dut.update_platform_time;
    assign next_attack_time = dut.next_attack_time;
    assign next_platform_time = dut.next_platform_time;
    assign attack_current_time = dut.attack_object_reader.current_time;
    assign attack_times = dut.attack_object_reader.times;
    assign attack_pos_x = dut.attack_object_reader.pos_x;
    assign attack_update_data = dut.attack_object_reader.update_data;
    
    assign sync_game_manager = dut.game_manager_contorl.sync_game_manager;
    assign update_game_manager = dut.game_manager_contorl.update_game_manager;
    
    

    // -----------------------------------------------------
    // 4. Initialization and Stimulus
    // -----------------------------------------------------

    initial begin
        // Initialize inputs
        clk <= 1'b0;
        reset <= 1'b0; // Start in reset
        switch_up <= 1'b0;
        switch_down <= 1'b0;
        switch_left <= 1'b0;
        switch_right <= 1'b0;

        // Setup Waveform Tracing
        $dumpfile("topModule_sim.vcd");
        // Dump all signals from the current scope (tb_topModule) and its children (dut)
        $dumpvars(0, tb_topModule);

        // De-assert reset after 100ns
        #100 reset <= 1'b1;

        // Apply a brief input stimulus after reset is released
        #500
        switch_left <= 1'b1; // Move player left
        
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
    
    wire  [7:0]  times;
    wire  [7:0]  pos_x;
    wire  [7:0]  w;
    
    assign times = rom[0][7:0];
    assign pos_x = rom[0][39:32];
    assign w = rom[0][23:16];
    
    reg [55:0] rom [0:10];
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