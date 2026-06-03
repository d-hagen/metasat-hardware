module Vortex import VX_gpu_pkg::*; (
    input  wire                             clk,
    input  wire                             reset,
    output wire                             mem_req_valid,
    output wire                             mem_req_rw,
    output wire [16-1:0]  mem_req_byteen,
    output wire [(32 - $clog2(16))-1:0]    mem_req_addr,
    output wire [(16 * 8)-1:0]    mem_req_data,
    output wire [L3_MEM_TAG_WIDTH-1:0]     mem_req_tag,
    input  wire                             mem_req_ready,
    input wire                              mem_rsp_valid,
    input wire [(16 * 8)-1:0]     mem_rsp_data,
    input wire [L3_MEM_TAG_WIDTH-1:0]      mem_rsp_tag,
    output wire                             mem_rsp_ready,
    input  wire                             dcr_wr_valid,
    input  wire [12-1:0]    dcr_wr_addr,
    input  wire [32-1:0]    dcr_wr_data,
    output wire                             busy
);
    VX_mem_bus_if #(
        .DATA_SIZE (16),
        .TAG_WIDTH (L2_MEM_TAG_WIDTH)
    ) per_cluster_mem_bus_if[1]();
    VX_mem_bus_if #(
        .DATA_SIZE (16),
        .TAG_WIDTH (L3_MEM_TAG_WIDTH)
    ) mem_bus_if();
    wire [1-1:0] l3_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __l3_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (l3_reset)                          
    );
    VX_cache_wrap #(
        .INSTANCE_ID    ("l3cache"),
        .CACHE_SIZE     (1048576),
        .LINE_SIZE      (16),
        .NUM_BANKS      ((((4) < (1)) ? (4) : (1))),
        .NUM_WAYS       (4),
        .WORD_SIZE      (L3_WORD_SIZE),
        .NUM_REQS       (L3_NUM_REQS),
        .CRSQ_SIZE      (2),
        .MSHR_SIZE      (16),
        .MRSQ_SIZE      (0),
        .MREQ_SIZE      (0 ? 16 : 4),
        .TAG_WIDTH      (L2_MEM_TAG_WIDTH),
        .WRITE_ENABLE   (1),
        .WRITEBACK      (0),
        .DIRTY_BYTES    (0),
        .UUID_WIDTH     (1),
        .CORE_OUT_BUF   (2),
        .MEM_OUT_BUF    (2),
        .NC_ENABLE      (1),
        .PASSTHRU       (!0)
    ) l3cache (
        .clk            (clk),
        .reset          (l3_reset),
        .core_bus_if    (per_cluster_mem_bus_if),
        .mem_bus_if     (mem_bus_if)
    );
    assign mem_req_valid = mem_bus_if.req_valid;
    assign mem_req_rw    = mem_bus_if.req_data.rw;
    assign mem_req_byteen= mem_bus_if.req_data.byteen;
    assign mem_req_addr  = mem_bus_if.req_data.addr;
    assign mem_req_data  = mem_bus_if.req_data.data;
    assign mem_req_tag   = mem_bus_if.req_data.tag;
    assign mem_bus_if.req_ready = mem_req_ready;
    assign mem_bus_if.rsp_valid = mem_rsp_valid;
    assign mem_bus_if.rsp_data.data  = mem_rsp_data;
    assign mem_bus_if.rsp_data.tag   = mem_rsp_tag;
    assign mem_rsp_ready = mem_bus_if.rsp_ready;
    wire mem_req_fire = mem_req_valid && mem_req_ready;
    wire mem_rsp_fire = mem_rsp_valid && mem_rsp_ready;
    VX_dcr_bus_if dcr_bus_if();
    assign dcr_bus_if.write_valid = dcr_wr_valid;
    assign dcr_bus_if.write_addr  = dcr_wr_addr;
    assign dcr_bus_if.write_data  = dcr_wr_data;
    wire [1-1:0] per_cluster_busy;
    for (genvar cluster_id = 0; cluster_id < 1; ++cluster_id) begin : clusters
    wire [1-1:0] cluster_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __cluster_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (cluster_reset)                          
    );
        VX_dcr_bus_if cluster_dcr_bus_if();
    if ((1 > 1)) begin 
        reg [(1 + 12 + 32)-1:0] __dst; 
        always @(posedge clk) begin 
            __dst <= {dcr_bus_if.write_valid, dcr_bus_if.write_addr, dcr_bus_if.write_data}; 
        end 
        assign {cluster_dcr_bus_if.write_valid, cluster_dcr_bus_if.write_addr, cluster_dcr_bus_if.write_data} = __dst; 
    end else begin 
        assign {cluster_dcr_bus_if.write_valid, cluster_dcr_bus_if.write_addr, cluster_dcr_bus_if.write_data} = {dcr_bus_if.write_valid, dcr_bus_if.write_addr, dcr_bus_if.write_data}; 
    end;
        VX_cluster #(
            .CLUSTER_ID (cluster_id),
            .INSTANCE_ID ($sformatf("cluster%0d", cluster_id))
        ) cluster (
            .clk                (clk),
            .reset              (cluster_reset),
            .dcr_bus_if         (cluster_dcr_bus_if),
            .mem_bus_if         (per_cluster_mem_bus_if[cluster_id]),
            .busy               (per_cluster_busy[cluster_id])
        );
    end
    VX_pipe_register #( 
        .DATAW  ($bits(busy)), 
        .RESETW ($bits(busy)), 
        .DEPTH  ((1 > 1)) 
    ) __busy__ ( 
        .clk      (clk), 
        .reset    (reset), 
        .enable   (1'b1), 
        .data_in  ((| per_cluster_busy)), 
        .data_out (busy) 
    );
endmodule
