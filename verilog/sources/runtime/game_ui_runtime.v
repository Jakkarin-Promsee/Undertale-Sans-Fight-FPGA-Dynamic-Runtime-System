`timescale 1ns / 1ps

module game_ui_runtime #(
    parameter integer ADDR_WIDTH = 10,              // 1024 entries
    parameter integer MAXIMUM_TIMES = 30
 ) (
    input clk_centi_second,
    input clk_calculation,
    input reset,
    input [9:0] x,
    input [9:0] y,
    input is_trigger_player,
    
    
    input [MAXIMUM_TIMES-1:0] current_time,
    
    output reg is_player_dead,
    output reg [ADDR_WIDTH-1:0] addr,
    output wire ui_signal
);
    
    reg sync_ui_time;
    wire update_ui_time;
    
    wire reset_healt_status;
    wire [9:0]   healt_bar_pos_x;
    wire [9:0]   healt_bar_pos_y;
    wire [9:0]   healt_bar_w;
    wire [9:0]   healt_bar_h;
    wire [6:0]   healt_bar_sensitivity;
    wire [15:0]  wait_time;
    
    wire [MAXIMUM_TIMES-1:0] next_ui_time;
    
    wire is_end;


    game_ui_rom_reader #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAXIMUM_TIMES(MAXIMUM_TIMES)
    ) game_uireader (
        .clk(clk_calculation),
        .reset(reset),
        .addr(addr),
        .current_time(current_time),
        .sync_ui_time(sync_ui_time),
        
        .update_ui_time(update_ui_time),
        
        .reset_healt_status(reset_healt_status),
        .healt_bar_pos_x(healt_bar_pos_x),
        .healt_bar_pos_y(healt_bar_pos_y),
        .healt_bar_w(healt_bar_w),
        .healt_bar_h(healt_bar_h),
        .healt_bar_sensitivity(healt_bar_sensitivity),
        .wait_time(wait_time),
        
        .next_ui_time(next_ui_time),
        
        .is_end(is_end)
    );
    
    // Border logic
    localparam BORDER = 2;
    wire normal_size =
        (x >= (healt_bar_pos_x)) &&
        (x <= (healt_bar_pos_x) + (healt_bar_w)) &&
        (y >= (healt_bar_pos_y)) &&
        (y <= (healt_bar_pos_y) + (healt_bar_h));
    
    wire border_size =
        (x >= (healt_bar_pos_x) - BORDER) &&
        (x <= (healt_bar_pos_x) + (healt_bar_w) + BORDER) &&
        (y >= (healt_bar_pos_y) - BORDER) &&
        (y <= (healt_bar_pos_y) + (healt_bar_h) + BORDER);
    
    wire healt_border;
    assign healt_border = border_size && (~normal_size);
    
    wire healt_amount = (x >= (healt_bar_pos_x)) && (x < (healt_bar_pos_x) + (healt_bar_w - healt_bar_w_minus)) 
                            && (y >= (healt_bar_pos_y)) && (y < (healt_bar_pos_y) + (healt_bar_h));
    
    assign ui_signal = healt_border || healt_amount;
    
    always @(posedge clk_calculation) begin
        if(reset) begin
            sync_ui_time <= 0;
            addr <= 0;
            
        end else if (!sync_ui_time) begin
            if(update_ui_time) begin
                sync_ui_time <= 1;
            end
                
        end else begin
            if(is_end) begin
                addr <= 0;
                sync_ui_time <= 0;
                
            end else if(current_time >= next_ui_time) begin
                addr <= addr + 1;
                sync_ui_time <= 0;
            end
        
        end
        
    end
    
    reg [6:0] current_healt_bar_sensitivity;
    reg [9:0] healt_bar_w_minus;
    
    always@(posedge clk_centi_second) begin
        if(reset) begin
            is_player_dead <= 0;
            current_healt_bar_sensitivity <= 127;
            healt_bar_w_minus <= 0;
            
        end else begin
            if(is_trigger_player) begin
                if(current_healt_bar_sensitivity==0) begin
                    // Reset Sensitivity
                    current_healt_bar_sensitivity <= healt_bar_sensitivity;
                    
                    if(healt_bar_w_minus < healt_bar_w)
                        healt_bar_w_minus <= healt_bar_w_minus + 1;
                    
                    
                end else begin
                    current_healt_bar_sensitivity <= current_healt_bar_sensitivity - 1;
                end
            
            end else begin
                if(healt_bar_w_minus < healt_bar_w)
                    is_player_dead <= 0;
                else
                    is_player_dead <= 1;
            
                // Reset Sensitivity
                current_healt_bar_sensitivity <= healt_bar_sensitivity;
            end
        end
    end
    

endmodule
