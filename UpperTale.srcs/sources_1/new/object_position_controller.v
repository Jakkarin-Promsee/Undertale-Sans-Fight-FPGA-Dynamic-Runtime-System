`timescale 1ns / 1ps

module object_position_controller (
    input clk_centi_second,
    input clk_object_control,
    input reset,
    
    input [2:0] movement_direction,
    input [9:0] object_pos_x,
    input [9:0] object_pos_y,
    input [4:0] object_speed,
    input [7:0] object_destroy_time,
    input [1:0] object_destroy_trigger,
    input sync_object_position,
    
    input  [9:0]  display_pos_x1,
    input  [9:0]  display_pos_y1,
    input  [9:0]  display_pos_x2,
    input  [9:0]  display_pos_y2,
    
    input [9:0]  object_w,
    input [9:0]  object_h,
        
    output reg update_object_position,
    output reg [9:0] object_override_w,
    output reg [9:0] object_override_h,
    output wire [9:0] object_override_pos_x,
    output wire [9:0] object_override_pos_y,
    
    output reg object_free
);
    localparam SCALE_FACTOR_BITS = 3;
    localparam SCALE_FACTOR = 8;
    
    reg [9+SCALE_FACTOR_BITS:0] object_override_pos_x_hired;
    reg [9+SCALE_FACTOR_BITS:0] object_override_pos_y_hired;
    reg [2:0] movement_direction_hired;
    reg [4:0] object_speed_hired;
    
    reg [9+SCALE_FACTOR_BITS:0] display_pos_x1_hired;
    reg [9+SCALE_FACTOR_BITS:0] display_pos_y1_hired;
    reg [9+SCALE_FACTOR_BITS:0] display_pos_x2_hired;
    reg [9+SCALE_FACTOR_BITS:0] display_pos_y2_hired;
    
    assign object_override_pos_x = object_override_pos_x_hired >> SCALE_FACTOR_BITS;
    assign object_override_pos_y = object_override_pos_y_hired >> SCALE_FACTOR_BITS;
    
    reg [7:0] object_destroy_time_count;
    reg [6:0] centi_second;
    
    always @(posedge clk_centi_second) begin
        if(reset) begin
            centi_second <= 0;
            object_destroy_time_count <= 255;
        end else begin
            if(centi_second == 100) begin
                centi_second = 0;
                
                if(sync_object_position && (object_destroy_time_count > 0))
                    object_destroy_time_count <= object_destroy_time_count - 1;
                
            end else begin
                centi_second <= centi_second + 1;
            end
            
            if(sync_object_position && (object_destroy_time_count == 0)) begin
                object_free <= 1;
            end 
        end
    end

    always @(posedge clk_object_control) begin
        if(reset) begin

            update_object_position <= 0;
            object_override_pos_x_hired <= 0;
            object_override_pos_y_hired <= 0;
            object_free <= 1;
            
            display_pos_x1_hired <= 0;
            display_pos_y1_hired <= 0;
            display_pos_x2_hired <= 0;
            display_pos_y2_hired <= 0;
            
            object_override_w <= 0;
            object_override_h <= 0;
            
            movement_direction_hired <= movement_direction;
            object_speed_hired <= object_speed;
        end else begin
            if (!sync_object_position) begin
                object_override_pos_x_hired <= object_pos_x << SCALE_FACTOR_BITS;
                object_override_pos_y_hired <= object_pos_y << SCALE_FACTOR_BITS;
                
                movement_direction_hired <= movement_direction;
                object_speed_hired <= object_speed;
                
                display_pos_x1_hired <=  display_pos_x1 << SCALE_FACTOR_BITS;
                display_pos_y1_hired <=  display_pos_y1 << SCALE_FACTOR_BITS;
                display_pos_x2_hired <=  display_pos_x2 << SCALE_FACTOR_BITS;
                display_pos_y2_hired <=  display_pos_y2 << SCALE_FACTOR_BITS;
                
                object_override_w <= object_w;
                object_override_h <= object_h;
                
                object_destroy_time_count <= object_destroy_time;
                update_object_position <= 1;
                object_free <= 0;
                
            end else if (object_free) begin
                object_override_pos_x_hired <= 0;
                object_override_pos_y_hired <= 0;
                
                object_override_w <= 0;
                object_override_h <= 0;
            
            end else begin
                update_object_position <= 0;
                
                // Check destroy trigger
                case (object_destroy_trigger)
                    // 0 is non trigger destroy
                    
                    1: begin
                        if (object_override_pos_x_hired > 640*SCALE_FACTOR ||
                            object_override_pos_x_hired + (object_override_w<<SCALE_FACTOR_BITS) < 0   ||
                            object_override_pos_y_hired > 480*SCALE_FACTOR ||
                            object_override_pos_y_hired + (object_override_h<<SCALE_FACTOR_BITS) < 0) begin
                            
                            object_free <= 1;
                        end
                    end
                    
                    2: begin
                        if (object_override_pos_x_hired > display_pos_x2_hired||
                            object_override_pos_x_hired + (object_override_w<<SCALE_FACTOR_BITS) < display_pos_x1_hired   ||
                            object_override_pos_y_hired > display_pos_y2_hired ||
                            object_override_pos_y_hired + (object_override_h<<SCALE_FACTOR_BITS) < display_pos_y1_hired) begin
                            
                            object_free <= 1;
                        end
                    end
                endcase
                
                // Move position
                case (movement_direction_hired)
                    // Upper
                    0: begin
                        object_override_pos_y_hired <= object_override_pos_y_hired - object_speed_hired;
                    end
                    
                    // Upper Right
                    1: begin
                        object_override_pos_y_hired <= object_override_pos_y_hired - object_speed_hired;
                        object_override_pos_x_hired <= object_override_pos_x_hired + object_speed_hired;       
                    end
                    
                    // Right
                    2: begin
                        object_override_pos_x_hired <= object_override_pos_x_hired + object_speed_hired;       
                    end
                    
                    // Bottom Right
                    3: begin
                        object_override_pos_y_hired <= object_override_pos_y_hired + object_speed_hired;
                        object_override_pos_x_hired <= object_override_pos_x_hired + object_speed_hired;       
                    end
                    
                    // Bottom
                    4: begin
                        object_override_pos_y_hired <= object_override_pos_y_hired + object_speed_hired;   
                    end
                    
                    // Bottom Left
                    5: begin
                        object_override_pos_y_hired <= object_override_pos_y_hired + object_speed_hired;
                        object_override_pos_x_hired <= object_override_pos_x_hired - object_speed_hired;       
                    end
                    
                    // Left
                    6: begin
                        object_override_pos_x_hired <= object_override_pos_x_hired - object_speed_hired;       
                    end
                    
                    // Upper Left
                    7: begin
                        object_override_pos_y_hired <= object_override_pos_y_hired - object_speed_hired;
                        object_override_pos_x_hired <= object_override_pos_x_hired - object_speed_hired;       
                    end
                endcase
            end
        end
    end
    

    
    
    

endmodule
