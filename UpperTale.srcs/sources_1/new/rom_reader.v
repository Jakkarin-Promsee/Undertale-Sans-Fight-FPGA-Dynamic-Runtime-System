`timescale 1ns / 1ps

module rom_reader #(
    parameter DATA_WIDTH = 8,       // Bit width of each ROM entry
    parameter ADDR_WIDTH = 8,        // Enough to address all entries
    parameter MEM_FILE   = "file.mem"  // Path to .mem file
)(
    input  wire clk,
    input  wire [ADDR_WIDTH-1:0] addr,
    output reg  [DATA_WIDTH-1:0] data_out
);

    // ----------------------------
    // ROM storage
    // ----------------------------
    reg [DATA_WIDTH-1:0] rom [0:(1<<ADDR_WIDTH)-1];

    // ----------------------------
    // Load ROM contents
    // ----------------------------
    initial begin
        $readmemb(MEM_FILE, rom); // Use $readmemh(MEM_FILE, rom); if your file is in hex
    end

    // ----------------------------
    // Read logic
    // ----------------------------
    always @(posedge clk) begin
        data_out <= rom[addr];
    end

endmodule