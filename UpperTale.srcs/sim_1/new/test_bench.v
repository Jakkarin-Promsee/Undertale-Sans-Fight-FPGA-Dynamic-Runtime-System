`timescale 1ns/1ps

module topModule_tb;

    // Clock and reset
    reg clk;
    reg reset;

    // Controller inputs
    reg switch_up;
    reg switch_down;
    reg switch_left;
    reg switch_right;

    // Outputs
    wire HS;
    wire VS;
    wire [3:0] RED;
    wire [3:0] GREEN;
    wire [3:0] BLUE;

    // DUT
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

    //--------------------------------------------------
    // Clock generation (100 MHz)
    //--------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //--------------------------------------------------
    // Dump ALL internal wires
    //--------------------------------------------------
    initial begin
        $dumpfile("full_engine_dump.vcd");
        $dumpvars(0, dut);  // dump ALL levels in hierarchy
    end

    //--------------------------------------------------
    // Minimal stimulus
    //--------------------------------------------------
    initial begin
        reset = 0;
        switch_up = 0;
        switch_down = 0;
        switch_left = 0;
        switch_right = 0;

        #50 reset = 1;

        #100_000 switch_right = 1;
        #100_000 switch_right = 0;

        #200_000 switch_up = 1;
        #50_000 switch_up = 0;

        #2_000_000;
        $stop;
    end

endmodule
