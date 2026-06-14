module VX_cluster import VX_gpu_pkg::*; #(
    parameter CLUSTER_ID = 0,
    parameter  INSTANCE_ID = ""
) (
    input  wire                 clk,
    input  wire                 reset,
    VX_dcr_bus_if.slave         dcr_bus_if,
    VX_mem_bus_if.master        mem_bus_if,
    output wire                 busy
);
    VX_mem_bus_if #(
        .DATA_SIZE (16),
        .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    ) per_socket_mem_bus_if[(((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)]();
    wire [1-1:0] l2_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __l2_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (l2_reset)                          
    );
    VX_cache_wrap #(
        .INSTANCE_ID    ($sformatf("%s-l2cache", INSTANCE_ID)),
        .CACHE_SIZE     (1048576),
        .LINE_SIZE      (16),
        .NUM_BANKS      ((((4) < ((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1))) ? (4) : ((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)))),
        .NUM_WAYS       (2),
        .WORD_SIZE      (L2_WORD_SIZE),
        .NUM_REQS       (L2_NUM_REQS),
        .CRSQ_SIZE      (2),
        .MSHR_SIZE      (16),
        .MRSQ_SIZE      (0),
        .MREQ_SIZE      (0 ? 16 : 4),
        .TAG_WIDTH      (L2_TAG_WIDTH),
        .WRITE_ENABLE   (1),
        .WRITEBACK      (0),
        .DIRTY_BYTES    (0),
        .UUID_WIDTH     (1),
        .CORE_OUT_BUF   (2),
        .MEM_OUT_BUF    (2),
        .NC_ENABLE      (1),
        .PASSTHRU       (!0)
    ) l2cache (
        .clk            (clk),
        .reset          (l2_reset),
        .core_bus_if    (per_socket_mem_bus_if),
        .mem_bus_if     (mem_bus_if)
    );
    VX_dcr_bus_if socket_dcr_bus_tmp_if();
    assign socket_dcr_bus_tmp_if.write_valid = dcr_bus_if.write_valid && (dcr_bus_if.write_addr >= 12'h001 && dcr_bus_if.write_addr < 12'h006);
    assign socket_dcr_bus_tmp_if.write_addr  = dcr_bus_if.write_addr;
    assign socket_dcr_bus_tmp_if.write_data  = dcr_bus_if.write_data;
    wire [(((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)-1:0] per_socket_busy;
    VX_dcr_bus_if socket_dcr_bus_if();
    if (((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1) > 1)) begin 
        reg [(1 + 12 + 32)-1:0] __dst; 
        always @(posedge clk) begin 
            __dst <= {socket_dcr_bus_tmp_if.write_valid, socket_dcr_bus_tmp_if.write_addr, socket_dcr_bus_tmp_if.write_data}; 
        end 
        assign {socket_dcr_bus_if.write_valid, socket_dcr_bus_if.write_addr, socket_dcr_bus_if.write_data} = __dst; 
    end else begin 
        assign {socket_dcr_bus_if.write_valid, socket_dcr_bus_if.write_addr, socket_dcr_bus_if.write_data} = {socket_dcr_bus_tmp_if.write_valid, socket_dcr_bus_tmp_if.write_addr, socket_dcr_bus_tmp_if.write_data}; 
    end;
    for (genvar socket_id = 0; socket_id < (((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1); ++socket_id) begin : sockets
    wire [1-1:0] socket_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __socket_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (socket_reset)                          
    );
        VX_socket #(
            .SOCKET_ID ((CLUSTER_ID * (((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)) + socket_id),
            .INSTANCE_ID ($sformatf("%s-socket%0d", INSTANCE_ID, socket_id))
        ) socket (
            .clk            (clk),
            .reset          (socket_reset),
            .dcr_bus_if     (socket_dcr_bus_if),
            .mem_bus_if     (per_socket_mem_bus_if[socket_id]),
            .busy           (per_socket_busy[socket_id])
        );
    end
    VX_pipe_register #( 
        .DATAW  ($bits(busy)), 
        .RESETW ($bits(busy)), 
        .DEPTH  (((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1) > 1)) 
    ) __busy__ ( 
        .clk      (clk), 
        .reset    (reset), 
        .enable   (1'b1), 
        .data_in  ((| per_socket_busy)), 
        .data_out (busy) 
    );
endmodule
