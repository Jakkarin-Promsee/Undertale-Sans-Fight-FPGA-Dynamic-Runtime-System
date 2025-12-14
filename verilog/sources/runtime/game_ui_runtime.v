`timescale 1ns / 1ps

module game_ui_runtime #(
    parameter integer ADDR_WIDTH = 10,              // 1024 entries
    parameter integer MAXIMUM_TIMES = 30,
    parameter integer CHARACTER_AMOUNT = 79
 ) (
    input clk_vga,
    input clk_centi_second,
    input clk_calculation,
    input reset,
    input [9:0] x,
    input [9:0] y,
    input is_trigger_player,
    
    input is_reset_stage,
    
    
    input [MAXIMUM_TIMES-1:0] current_time,
    
    output reg is_player_dead,
    output reg [ADDR_WIDTH-1:0] addr,
    
    output wire healt_bar_signal,
    output wire healt_bar_border_signal,
    output wire character_signal,
    
    output wire transparent_out_screen_display
);

    
    reg sync_ui_time;
    wire update_ui_time;
    
    wire         show_healt_text;
    wire         reset_character;
    wire [9:0]   character_amount;
    wire [9:0]   healt_current;
    reg [9:0]   healt_current_hires;
    wire [9:0]   healt_max;
//    wire         transparent_out_screen_display;
    wire         reset_when_dead;
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
        
        .show_healt_text(show_healt_text),
        .reset_character(reset_character),
        .character_amount(character_amount),
        .healt_current(healt_current),
        .healt_max(healt_max),
        .transparent_out_screen_display(transparent_out_screen_display),
        .reset_when_dead(reset_when_dead),
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
        (x < (healt_bar_pos_x) + (healt_bar_w) + BORDER) &&
        (y >= (healt_bar_pos_y) - BORDER) &&
        (y < (healt_bar_pos_y) + (healt_bar_h) + BORDER);
    
    assign healt_bar_border_signal = border_size && (~normal_size);
    
    
    wire [9:0] hp_pixels;
    assign hp_pixels =  (healt_max != 0) ? (healt_current_hires * healt_bar_w) / healt_max : 0;
    
    assign healt_bar_signal =
        (x >= healt_bar_pos_x) &&
        (x <  healt_bar_pos_x + hp_pixels) &&
        (y >= healt_bar_pos_y) &&
        (y <  healt_bar_pos_y + healt_bar_h);

    reg sync_character;
    wire update_character;
    
    reg sync_master;
    reg update_master;
    
    reg [ADDR_WIDTH-1:0] count_character_i;
    reg [ADDR_WIDTH-1:0] character_i;
    
    wire [9:0]   character_pos_x;
    wire [9:0]   character_pos_y;
    wire [7:0]   character_index;
    
    character_object_rom_reader #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) character_object_reader (
        .clk(clk_calculation),
        .reset(reset),
        .addr(character_i),

        .sync_character(sync_character),
        
        .update_character(update_character),
        
        .character_pos_x(character_pos_x),
        .character_pos_y(character_pos_y),
        .character_index(character_index)
    );
    
    localparam integer MAXIMUM_CHAR_OBJECT = 20;
    
    reg [MAXIMUM_CHAR_OBJECT-1: 0]     char_index ;
    reg [CHARACTER_AMOUNT-1: 0]        character_active_i ;
    reg [9:0]   character_pos_x_i [CHARACTER_AMOUNT-1: 0];
    reg [9:0]   character_pos_y_i [CHARACTER_AMOUNT-1: 0];
    reg [7:0]   character_index_i [CHARACTER_AMOUNT-1: 0];
    
    wire [3:0] cur_hund = healt_current_hires / 100;
    wire [3:0] cur_tens = (healt_current_hires % 100) / 10;
    wire [3:0] cur_ones = healt_current_hires % 10;
    
    wire [3:0] max_hund = healt_max / 100;
    wire [3:0] max_tens = (healt_max % 100) / 10;
    wire [3:0] max_ones = healt_max % 10;
    
    wire show_3digit = (healt_max >= 100);
    
    reg update;
    
    integer i;
    
    localparam integer  CHARACTER_W = 17;
    localparam integer  CHARACTER_H = 17;
    localparam integer  FRONT_GAP = 10;
    localparam integer  HP_FRONT_GAP = 5;
    localparam integer  BETWEEN_GAP = 1;
    
    always @(posedge clk_calculation) begin
        if(reset) begin
            sync_ui_time <= 0;
            addr <= 0;
            sync_character <= 1;
            sync_master <= 1;
            character_i <= 0;
            update <= 0;
            char_index <= 0;
            
            for(i=0; i<CHARACTER_AMOUNT; i=i+1) begin
                character_active_i <= 0;
                character_pos_x_i[i] <= 0;
                character_pos_y_i[i] <= 0;
                character_index_i[i] <= 0;
            end
            
        end else if (!sync_ui_time) begin
            if(update_ui_time) begin
                count_character_i <= 0;
                sync_ui_time <= 1;
                sync_character <= 0;
                sync_master <= 0;
                update <= 0;
                
                if(reset_character) begin
                    char_index <= 0;
                    for(i=0; i<CHARACTER_AMOUNT; i=i+1) begin
                        character_active_i[i] <= 0;
                        character_pos_x_i[i] <= 0;
                        character_pos_y_i[i] <= 0;
                        character_index_i[i] <= 0;
                    end
                end
            end
               
            
        end else begin
            if(update_master) begin
                sync_master<= 1;
                
            end 
            
            if(update_character) begin
                 sync_character <= 1;
                 
            end else if (sync_character) begin
                if (show_healt_text) begin
                    // --------------------------------------------------
                    // Default: disable all characters
                    // --------------------------------------------------
                    for (i = 0; i < 9; i = i + 1) begin
                
                        // register positions (always stable)
                        character_pos_x_i[i] <= healt_bar_pos_x
                                                + healt_bar_w
                                                + FRONT_GAP
                                                + i * (CHARACTER_W + BETWEEN_GAP)
                                                + ((i > 1)? HP_FRONT_GAP : 0);
                        character_pos_y_i[i] <= healt_bar_pos_y + ((healt_bar_h-CHARACTER_H)/2);
                    end
                
                    // --------------------------------------------------
                    // 3-digit mode : CCC/MMM
                    // --------------------------------------------------
                    if (show_3digit) begin
                        character_active_i[0] <= 1'b1;
                        character_active_i[1] <= 1'b1;
                        character_active_i[2] <= 1'b1;
                        character_active_i[3] <= 1'b1;
                        character_active_i[4] <= 1'b1;
                        character_active_i[5] <= 1'b1;
                        character_active_i[6] <= 1'b1;
                        character_active_i[7] <= 1'b1;
                        character_active_i[8] <= 1'b1;
                
                        character_index_i[0] <= 7; // 'H'
                        character_index_i[1] <= 15; // 'P;
                        
                        character_index_i[2] <= 26 + cur_hund;
                        character_index_i[3] <= 26 + cur_tens;
                        character_index_i[4] <= 26 + cur_ones;
                        character_index_i[5] <= 36; // '/'
                        character_index_i[6] <= 26 + max_hund;
                        character_index_i[7] <= 26 + max_tens;
                        character_index_i[8] <= 26 + max_ones;
                    end
                    // --------------------------------------------------
                    // 2-digit mode : CC/MM
                    // --------------------------------------------------
                    else begin
                        character_active_i[0] <= 1'b1;
                        character_active_i[1] <= 1'b1;
                        character_active_i[2] <= 1'b1;
                        character_active_i[3] <= 1'b1;
                        character_active_i[4] <= 1'b1;
                        character_active_i[5] <= 1'b1;
                        character_active_i[6] <= 1'b1;
                        
                        character_index_i[0] <= 7; // 'H'
                        character_index_i[1] <= 15; // 'P;
                                                
                        character_index_i[2] <= 26 + cur_tens;
                        character_index_i[3] <= 26 + cur_ones;
                        character_index_i[4] <= 36; // '/'
                        character_index_i[5] <= 26 + max_tens;
                        character_index_i[6] <= 26 + max_ones;
                    end
                end
                
                if(count_character_i < character_amount) begin
                    if((show_healt_text && ((CHARACTER_AMOUNT-1-char_index)>8))
                        || (!show_healt_text && ((CHARACTER_AMOUNT-char_index)>0))
                    ) begin
                    
                        count_character_i <= count_character_i + 1;
                        character_i <= character_i + 1;
                        sync_character <= 0;
                        
                        char_index <= char_index + 1;
                        
                        character_active_i[CHARACTER_AMOUNT-1-char_index] <= 1;
                        character_index_i[CHARACTER_AMOUNT-1-char_index] <= character_index;
                        character_pos_x_i[CHARACTER_AMOUNT-1-char_index] <= character_pos_x;
                        character_pos_y_i[CHARACTER_AMOUNT-1-char_index] <= character_pos_y;
                    end
                end
               
            end
            
            if(is_end || (is_reset_stage && reset_clk_centi_second)) begin
                addr <= 0;
                character_i <= 0;
                sync_ui_time <= 0;
                
            end else if(current_time >= next_ui_time) begin
                addr <= addr + 1;
                sync_ui_time <= 0;
            end
        end
    end
    
    reg hit;
    reg [7:0] hit_char;   // enough for 0..29
    reg [9:0] local_x, local_y;
    
    always @(*) begin
        hit = 0;
        hit_char = 0;
        local_x = 0;
        local_y = 0;
    
        for (i = 0; i < CHARACTER_AMOUNT; i = i + 1) begin
            if (!hit &&
                character_active_i[CHARACTER_AMOUNT-1-i] &&
                x >= character_pos_x_i[CHARACTER_AMOUNT-1-i] &&
                x <  character_pos_x_i[CHARACTER_AMOUNT-1-i] + 17 &&
                y >= character_pos_y_i[CHARACTER_AMOUNT-1-i] &&
                y <  character_pos_y_i[CHARACTER_AMOUNT-1-i] + 17
            ) begin
                hit = 1;
                hit_char = character_index_i[CHARACTER_AMOUNT-1-i];
                local_x = x - character_pos_x_i[CHARACTER_AMOUNT-1-i];
                local_y = y - character_pos_y_i[CHARACTER_AMOUNT-1-i];
            end
        end
    end
    
    
    wire is_character;
    font_data_rom_reader #(
        
    ) font_data_reader (
        .char_index(hit_char),
        .x(local_x),
        .y(local_y),
        .is_character(is_character)
    );
    
    assign character_signal = is_character;
    
    
    reg [6:0] current_healt_bar_sensitivity;
    reg reset_clk_centi_second;
    
    always@(posedge clk_centi_second) begin
        if(reset) begin
            is_player_dead <= 0;
            current_healt_bar_sensitivity <= 127;
            update_master <= 0;
            healt_current_hires <= (1<<10) - 1;
            reset_clk_centi_second <= 0;
            
        end else if (!sync_master) begin
            update_master<= 1;
            
            if(!(healt_current == 0))
                healt_current_hires <= healt_current;
                reset_clk_centi_second <= 0;
            
        end else if(is_reset_stage) begin
            healt_current_hires <= (1<<10) - 1;
            is_player_dead <= 0;
            reset_clk_centi_second <= 1;
            
        end else begin
            update_master <= 0;
            reset_clk_centi_second <= 0;
                
                
                
            if (healt_current_hires == 0)
                is_player_dead <= reset_when_dead;
            
            if(is_trigger_player) begin
                if(current_healt_bar_sensitivity==0) begin
                    // Reset Sensitivity
                    current_healt_bar_sensitivity <= healt_bar_sensitivity;
                    
                    if(healt_current_hires > 0)
                        healt_current_hires <= healt_current_hires - 1;

                end else begin
                    current_healt_bar_sensitivity <= current_healt_bar_sensitivity - 1;
                end
            
            end else begin
            
                // Reset Sensitivity
                current_healt_bar_sensitivity <= healt_bar_sensitivity;
            end
        end
    end

endmodule
