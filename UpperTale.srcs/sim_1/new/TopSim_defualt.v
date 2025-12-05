`timescale 1ns / 1ps

// Testbench for the topModule, designed to observe timing and control signals.
module TopSim_Defalt;
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

endmodule