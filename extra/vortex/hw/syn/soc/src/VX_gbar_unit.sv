module VX_gbar_unit #(    
    parameter  INSTANCE_ID = ""
) (
    input wire clk,
    input wire reset,
    VX_gbar_bus_if.slave gbar_bus_if
);
    reg [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0][1-1:0] barrier_masks;
    wire [$clog2(1+1)-1:0] active_barrier_count;
    wire [1-1:0] curr_barrier_mask = barrier_masks[gbar_bus_if.req_id];
    VX_popcount #( 
        .N ($bits(curr_barrier_mask)), 
        .MODEL (1) 
    ) __active_barrier_count ( 
        .data_in  (curr_barrier_mask), 
        .data_out (active_barrier_count) 
    );
    reg rsp_valid;
    reg [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] rsp_bar_id;
    always @(posedge clk) begin
        if (reset) begin
            barrier_masks <= '0;
            rsp_valid <= 0;
        end else begin
            if (rsp_valid) begin
                rsp_valid <= 0;
            end
            if (gbar_bus_if.req_valid) begin
                if (active_barrier_count[((($clog2(1)) != 0) ? ($clog2(1)) : 1)-1:0] == gbar_bus_if.req_size_m1) begin
                    barrier_masks[gbar_bus_if.req_id] <= '0;
                    rsp_bar_id <= gbar_bus_if.req_id;
                    rsp_valid  <= 1;
                end else begin
                    barrier_masks[gbar_bus_if.req_id][gbar_bus_if.req_core_id] <= 1;
                end
            end
        end
    end
    assign gbar_bus_if.rsp_valid = rsp_valid;
    assign gbar_bus_if.rsp_id    = rsp_bar_id;
    assign gbar_bus_if.req_ready = 1;  
endmodule
