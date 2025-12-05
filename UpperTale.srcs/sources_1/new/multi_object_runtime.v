`timescale 1ns / 1ps

module multi_object_runtime #(
    parameter integer OBJECT_AMOUNT = 5
) (
    input clk_centi_second,
    input clk_object_control,
    input clk_calculation,
    input reset,
    input [9:0] x,
    input [9:0] y,
    
    input [2:0] object_movement_direction,
    input [9:0] object_pos_x,
    input [9:0] object_pos_y,
    input [9:0] object_w,
    input [9:0] object_h,
    input [4:0] object_speed,
    input [7:0] object_destroy_time,
    input [1:0] object_destroy_trigger,
    
    input  [9:0]  display_pos_x1,
    input  [9:0]  display_pos_y1,
    input  [9:0]  display_pos_x2,
    input  [9:0]  display_pos_y2,
    
    input sync_object_position,
    
    output reg update_object_position,
    output wire object_signal
);
    genvar i;
    integer it;
    integer k;
    
    
    
    // Object Interotor Data Stream
    reg get_itertor_ready_state_state;
    reg [9:0] itertor_ready_state;
    reg [OBJECT_AMOUNT-1: 0] object_ready_state ;
    wire [9:0] object_override_pos_x_hired [OBJECT_AMOUNT-1: 0];
    wire [9:0] object_override_pos_y_hired [OBJECT_AMOUNT-1: 0];
    wire [9:0] object_override_w_hired [OBJECT_AMOUNT-1: 0];
    wire [9:0] object_override_h_hired [OBJECT_AMOUNT-1: 0];
    
    reg [OBJECT_AMOUNT-1: 0] sync_object_position_i ;
    wire [OBJECT_AMOUNT-1: 0] update_object_position_i ;
    wire [OBJECT_AMOUNT-1: 0] object_signal_i ;
    wire [OBJECT_AMOUNT-1: 0] object_free_i;
    
    reg second_sync; 
    
    
    assign object_signal = |object_signal_i;    
    
    
    always @(posedge clk_calculation) begin
        if(reset) begin
            update_object_position <= 0;
            itertor_ready_state <= 0;
            get_itertor_ready_state_state <= 0;
            second_sync <= 0;
            
            for (it = 0; it < OBJECT_AMOUNT; it = it + 1) begin
                object_ready_state[it] <= 1'b1;        // all ready
                sync_object_position_i[it] <= 1'b1;    // clear sync
            end
            
        end else begin
            // If new object throw data to our module
            if (!sync_object_position) begin
                // If iterator isn't ready
                if(!get_itertor_ready_state_state) begin
                    
                    // Find and update iterator
                    for(it = 0; it < OBJECT_AMOUNT; it = it + 1) begin
                        if(object_ready_state[it]) begin
                            itertor_ready_state <= it; 
                        end
                    end
                    
                    get_itertor_ready_state_state <= 1;
                 
                 // If iterator is ready
                 end else begin
                    object_ready_state[itertor_ready_state] <= 0; // busy
                    sync_object_position_i[itertor_ready_state] <= 0;
                 
                    // If submodule has done load this data
                    if (update_object_position_i[itertor_ready_state]) begin
                        // Send signal back to submodule to said we are sync
                        sync_object_position_i[itertor_ready_state] <= 1'b1;
                    
                        // Send signal back to rom modules to set sync
                        update_object_position <= 1;
                        
                        get_itertor_ready_state_state <= 0;
                        
                    end 
//                    else begin
//                        // Send signal to submodule [i] we're not sync
//                        sync_object_position_i [it] <= 0;
//                    end
                 end
            
            // Normal state
            end else begin
                // Send signal back to rom module we are IDLE
                update_object_position <= 0;
                get_itertor_ready_state_state <= 0;
                
                 for (it = 0; it < OBJECT_AMOUNT; it = it + 1) begin
                   sync_object_position_i[it] <= 1'b1;    // clear sync
                   
                   if(object_free_i[it]) begin
                        object_ready_state[it] <= 1;
                   end
               end
                
            end
        end
    end
    
    generate
        for (i = 0; i < OBJECT_AMOUNT; i = i + 1) begin : OBJECTS
            object_position_controller object_collider_position_control (
                .clk_centi_second(clk_centi_second),
                .clk_object_control(clk_object_control),
                .reset(reset),
                .movement_direction(object_movement_direction),
                .object_pos_x(object_pos_x),
                .object_pos_y(object_pos_y),
                .object_speed(object_speed),
                .object_destroy_time(object_destroy_time),
                .object_destroy_trigger(object_destroy_trigger),
                .sync_object_position(sync_object_position_i[i]),
                
                .display_pos_x1(display_pos_x1),
                .display_pos_y1(display_pos_y1),
                .display_pos_x2(display_pos_x2),
                .display_pos_y2(display_pos_y2),
                
                .object_w(object_w),
                .object_h(object_h),
                
                .update_object_position(update_object_position_i[i]),
                .object_override_pos_x(object_override_pos_x_hired[i]),
                .object_override_pos_y(object_override_pos_y_hired[i]),
                .object_override_w(object_override_w_hired[i]),
                .object_override_h(object_override_h_hired[i]),
                
                .object_free(object_free_i[i])
            );
            
            object_renderer object_colider_render (
                .x(x),
                .y(y),
                .object_pos_x(object_override_pos_x_hired[i]),
                .object_pos_y(object_override_pos_y_hired[i]),
                .object_w(object_override_w_hired[i]),
                .object_h(object_override_h_hired[i]),
                      
                .render(object_signal_i[i])
            );
        end
    endgenerate

endmodule
