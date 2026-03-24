module VX_fetch import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input  wire             clk,
    input  wire             reset,
    VX_mem_bus_if.master    icache_bus_if,
    VX_schedule_if.slave    schedule_if,
    VX_fetch_if.master      fetch_if
);
    wire icache_req_valid;
    wire [ICACHE_ADDR_WIDTH-1:0] icache_req_addr;
    wire [ICACHE_TAG_WIDTH-1:0] icache_req_tag;
    wire icache_req_ready;
    wire [1-1:0] rsp_uuid;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] req_tag, rsp_tag;
    wire icache_req_fire = icache_req_valid && icache_req_ready;
    assign req_tag = schedule_if.data.wid;
    assign {rsp_uuid, rsp_tag} = icache_bus_if.rsp_data.tag;
    wire [(32-1)-1:0] rsp_PC;
    wire [4-1:0] rsp_tmask;
    VX_dp_ram #(
        .DATAW  ((32-1) + 4),
        .SIZE   (4),
        .LUTRAM (1)
    ) tag_store (
        .clk   (clk),
        .reset (reset),
        .read  (1'b1),
        .write (icache_req_fire),
        .wren  (1'b1),
        .waddr (req_tag),
        .wdata ({schedule_if.data.PC, schedule_if.data.tmask}),
        .raddr (rsp_tag),
        .rdata ({rsp_PC, rsp_tmask})
    );
    wire ibuf_ready = 1'b1;
    assign icache_req_valid = schedule_if.valid && ibuf_ready;
    assign icache_req_addr  = schedule_if.data.PC[1 +: ICACHE_ADDR_WIDTH];
    assign icache_req_tag   = {schedule_if.data.uuid, req_tag};
    assign schedule_if.ready = icache_req_ready && ibuf_ready;
    VX_elastic_buffer #(
        .DATAW   (ICACHE_ADDR_WIDTH + ICACHE_TAG_WIDTH),
        .SIZE    (2),
        .OUT_REG (1)  
    ) req_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (icache_req_valid),
        .ready_in  (icache_req_ready),
        .data_in   ({icache_req_addr, icache_req_tag}),
        .data_out  ({icache_bus_if.req_data.addr, icache_bus_if.req_data.tag}),
        .valid_out (icache_bus_if.req_valid),
        .ready_out (icache_bus_if.req_ready)
    );
    assign icache_bus_if.req_data.atype  = '0;
    assign icache_bus_if.req_data.rw     = 0;
    assign icache_bus_if.req_data.byteen = 4'b1111;
    assign icache_bus_if.req_data.data   = '0;
    assign fetch_if.valid = icache_bus_if.rsp_valid;
    assign fetch_if.data.tmask = rsp_tmask;
    assign fetch_if.data.wid   = rsp_tag;
    assign fetch_if.data.PC    = rsp_PC;
    assign fetch_if.data.instr = icache_bus_if.rsp_data.data;
    assign fetch_if.data.uuid  = rsp_uuid;
    assign icache_bus_if.rsp_ready = fetch_if.ready;
endmodule
