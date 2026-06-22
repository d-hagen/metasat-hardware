module VX_lmem_unit import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_lsu_mem_if.slave     lsu_mem_in_if [1],
    VX_lsu_mem_if.master    lsu_mem_out_if [1]
);
    localparam REQ_DATAW = 4 + 1 + 4 * (LSU_WORD_SIZE + LSU_ADDR_WIDTH + (2 + 1) + LSU_WORD_SIZE * 8) + LSU_TAG_WIDTH;
    localparam RSP_DATAW = 4 + 4 * (LSU_WORD_SIZE * 8) + LSU_TAG_WIDTH;
    localparam LMEM_ADDR_WIDTH = 14 - $clog2(LSU_WORD_SIZE);
     VX_lsu_mem_if #(
        .NUM_LANES (4),
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lsu_switch_if[1]();
    wire [1-1:0] block_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(1)) __block_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (block_reset)                          
    );
    for (genvar i = 0; i < 1; ++i) begin
        wire [4-1:0] is_addr_local_mask;
        for (genvar j = 0; j < 4; ++j) begin
            assign is_addr_local_mask[j] = lsu_mem_in_if[i].req_data.atype[j][2];
        end
        wire is_addr_global = | (lsu_mem_in_if[i].req_data.mask & ~is_addr_local_mask);
        wire is_addr_local = | (lsu_mem_in_if[i].req_data.mask & is_addr_local_mask);
        wire req_global_ready;
        wire req_local_ready;
        VX_elastic_buffer #(
            .DATAW   (REQ_DATAW),
            .SIZE    (2),
            .OUT_REG (1)
        ) req_global_buf (
            .clk       (clk),
            .reset     (block_reset[i]),
            .valid_in  (lsu_mem_in_if[i].req_valid && is_addr_global),
            .data_in   ({
                lsu_mem_in_if[i].req_data.mask & ~is_addr_local_mask,
                lsu_mem_in_if[i].req_data.rw,
                lsu_mem_in_if[i].req_data.byteen,
                lsu_mem_in_if[i].req_data.addr,
                lsu_mem_in_if[i].req_data.atype,
                lsu_mem_in_if[i].req_data.data,
                lsu_mem_in_if[i].req_data.tag
            }),
            .ready_in  (req_global_ready),
            .valid_out (lsu_mem_out_if[i].req_valid),
            .data_out  ({
                lsu_mem_out_if[i].req_data.mask,
                lsu_mem_out_if[i].req_data.rw,
                lsu_mem_out_if[i].req_data.byteen,
                lsu_mem_out_if[i].req_data.addr,
                lsu_mem_out_if[i].req_data.atype,
                lsu_mem_out_if[i].req_data.data,
                lsu_mem_out_if[i].req_data.tag
            }),
            .ready_out (lsu_mem_out_if[i].req_ready)
        );
        VX_elastic_buffer #(
            .DATAW   (REQ_DATAW),
            .SIZE    (0),
            .OUT_REG (0)
        ) req_local_buf (
            .clk       (clk),
            .reset     (block_reset[i]),
            .valid_in  (lsu_mem_in_if[i].req_valid && is_addr_local),
            .data_in   ({
                lsu_mem_in_if[i].req_data.mask & is_addr_local_mask,
                lsu_mem_in_if[i].req_data.rw,
                lsu_mem_in_if[i].req_data.byteen,
                lsu_mem_in_if[i].req_data.addr,
                lsu_mem_in_if[i].req_data.atype,
                lsu_mem_in_if[i].req_data.data,
                lsu_mem_in_if[i].req_data.tag
            }),
            .ready_in  (req_local_ready),
            .valid_out (lsu_switch_if[i].req_valid),
            .data_out  ({
                lsu_switch_if[i].req_data.mask,
                lsu_switch_if[i].req_data.rw,
                lsu_switch_if[i].req_data.byteen,
                lsu_switch_if[i].req_data.addr,
                lsu_switch_if[i].req_data.atype,
                lsu_switch_if[i].req_data.data,
                lsu_switch_if[i].req_data.tag
            }),
            .ready_out (lsu_switch_if[i].req_ready)
        );
        assign lsu_mem_in_if[i].req_ready = (req_global_ready && is_addr_global)
                                         || (req_local_ready && is_addr_local);
        VX_stream_arb #(
            .NUM_INPUTS (2),
            .DATAW      (RSP_DATAW),
            .ARBITER    ("R"),
            .OUT_BUF    (1)
        ) rsp_arb (
            .clk       (clk),
            .reset     (block_reset[i]),
            .valid_in  ({
                lsu_switch_if[i].rsp_valid,
                lsu_mem_out_if[i].rsp_valid
            }),
            .ready_in  ({
                lsu_switch_if[i].rsp_ready,
                lsu_mem_out_if[i].rsp_ready
            }),
            .data_in   ({
                lsu_switch_if[i].rsp_data,
                lsu_mem_out_if[i].rsp_data
            }),
            .data_out  (lsu_mem_in_if[i].rsp_data),
            .valid_out (lsu_mem_in_if[i].rsp_valid),
            .ready_out (lsu_mem_in_if[i].rsp_ready),
            . sel_out ()
        );
    end
    VX_mem_bus_if #(
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lmem_bus_if[LSU_NUM_REQS]();
    for (genvar i = 0; i < 1; ++i) begin
        VX_mem_bus_if #(
            .DATA_SIZE (LSU_WORD_SIZE),
            .TAG_WIDTH (LSU_TAG_WIDTH)
        ) lmem_bus_tmp_if[4]();
        VX_lsu_adapter #(
            .NUM_LANES    (4),
            .DATA_SIZE    (LSU_WORD_SIZE),
            .TAG_WIDTH    (LSU_TAG_WIDTH),
            .TAG_SEL_BITS (LSU_TAG_WIDTH - 23),
            .ARBITER      ("P"),
            .REQ_OUT_BUF  (3),
            .RSP_OUT_BUF  (0)
        ) lsu_adapter (
            .clk        (clk),
            .reset      (block_reset[i]),
            .lsu_mem_if (lsu_switch_if[i]),
            .mem_bus_if (lmem_bus_tmp_if)
        );
        for (genvar j = 0; j < 4; ++j) begin
    assign lmem_bus_if[i * 4 + j].req_valid  = lmem_bus_tmp_if[j].req_valid; 
    assign lmem_bus_if[i * 4 + j].req_data   = lmem_bus_tmp_if[j].req_data; 
    assign lmem_bus_tmp_if[j].req_ready  = lmem_bus_if[i * 4 + j].req_ready; 
    assign lmem_bus_tmp_if[j].rsp_valid  = lmem_bus_if[i * 4 + j].rsp_valid; 
    assign lmem_bus_tmp_if[j].rsp_data   = lmem_bus_if[i * 4 + j].rsp_data; 
    assign lmem_bus_if[i * 4 + j].rsp_ready  = lmem_bus_tmp_if[j].rsp_ready;
        end
    end
    wire [1-1:0] lmem_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __lmem_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (lmem_reset)                          
    );
    VX_local_mem #(
        .INSTANCE_ID($sformatf("%s-lmem", INSTANCE_ID)),
        .SIZE       (1 << 14),
        .NUM_REQS   (LSU_NUM_REQS),
        .NUM_BANKS  (4),
        .WORD_SIZE  (LSU_WORD_SIZE),
        .ADDR_WIDTH (LMEM_ADDR_WIDTH),
        .UUID_WIDTH (23),
        .TAG_WIDTH  (LSU_TAG_WIDTH),
        .OUT_BUF    (3)
    ) local_mem (
        .clk        (clk),
        .reset      (lmem_reset),
        .mem_bus_if (lmem_bus_if)
    );
endmodule
