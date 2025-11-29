`timescale 1ns / 1ps

module vga_translator (
    input  wire clk_display,  // 25 MHz clock
    input  wire reset,
    output wire HS,
    output wire VS,
    output wire [9:0] x,
    output wire [9:0] y,
    output wire blank
);

    // Horizontal timing (pixels)
    localparam H_DISPLAY = 640;
    localparam H_FPORCH  = 16;
    localparam H_SYNC    = 96;
    localparam H_BPORCH  = 48;
    localparam H_TOTAL   = 800; // 640 + 16 + 96 + 48 = 800

    // Vertical timing (lines)
    localparam V_DISPLAY = 480;
    localparam V_FPORCH  = 10;
    localparam V_SYNC    = 2;
    localparam V_BPORCH  = 33;
    localparam V_TOTAL   = 525; // 480 + 10 + 2 + 33 = 525

    // Counters
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    // Horizontal counter (Synchronous Reset)
    always @(posedge clk_display) begin
        if (!reset)
            h_count <= 0;
        else if (h_count == H_TOTAL - 1)
            h_count <= 0;
        else
            h_count <= h_count + 1;
    end

    // Vertical counter (FIXED: Uses Synchronous Reset)
    always @(posedge clk_display) begin
        if (!reset)
            v_count <= 0;
        else if (h_count == H_TOTAL - 1) begin // Check only when horizontal counter is about to reset
            if (v_count == V_TOTAL - 1)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end
    end

    // Sync signals (active low)
    assign HS = ~((h_count >= H_DISPLAY + H_FPORCH) &&
                  (h_count <  H_DISPLAY + H_FPORCH + H_SYNC));

    assign VS = ~((v_count >= V_DISPLAY + V_FPORCH) &&
                  (v_count <  V_DISPLAY + V_FPORCH + V_SYNC));

    // Current pixel coordinates (only valid during visible area)
    assign x = (h_count < H_DISPLAY) ? h_count : 10'd0;
    assign y = (v_count < V_DISPLAY) ? v_count : 10'd0;

    // Blank signal (1 = outside visible area)
    assign blank = ~((h_count < H_DISPLAY) && (v_count < V_DISPLAY));

endmodule