module VX_cache_wrap import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID    = "",
    parameter NUM_REQS              = 4,
    parameter CACHE_SIZE            = 4096, 
    parameter LINE_SIZE             = 64, 
    parameter NUM_BANKS             = 1,
    parameter NUM_WAYS              = 1,
    parameter WORD_SIZE             = 4, 
    parameter CRSQ_SIZE             = 2,
    parameter MSHR_SIZE             = 8, 
    parameter MRSQ_SIZE             = 0,
    parameter MREQ_SIZE             = 4,
    parameter WRITE_ENABLE          = 1,
    parameter UUID_WIDTH            = 0,
    parameter TAG_WIDTH             = UUID_WIDTH + 1,
    parameter NC_TAG_BIT            = 0,
    parameter NC_ENABLE             = 0,
    parameter PASSTHRU              = 0,
    parameter CORE_OUT_REG          = 0,
    parameter MEM_OUT_REG           = 0
 ) (
    input wire clk,
    input wire reset,
    VX_mem_bus_if.slave     core_bus_if [NUM_REQS],
    VX_mem_bus_if.master    mem_bus_if
);
    localparam MSHR_ADDR_WIDTH  = (((MSHR_SIZE) > 1) ? $clog2(MSHR_SIZE) : 1);    
    localparam CORE_TAG_X_WIDTH = TAG_WIDTH - NC_ENABLE;
    localparam MEM_TAG_X_WIDTH  = MSHR_ADDR_WIDTH + $clog2(NUM_BANKS);
    localparam MEM_TAG_WIDTH    = PASSTHRU ? (NC_ENABLE ? 
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + TAG_WIDTH) : 
        (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + TAG_WIDTH) + 1)) : 
                                             (NC_ENABLE ? 
        (((
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS) + 1)) > (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + TAG_WIDTH))) ? (
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS) + 1)) : (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + TAG_WIDTH))) :
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS) + 1));
    localparam NC_BYPASS = (NC_ENABLE || PASSTHRU);
    localparam DIRECT_PASSTHRU = PASSTHRU && ($clog2((LINE_SIZE / WORD_SIZE)) == 0) && (NUM_REQS == 1);
    wire [NUM_REQS-1:0]                     core_req_valid;
    wire [NUM_REQS-1:0]                     core_req_rw;
    wire [NUM_REQS-1:0][(32-$clog2(WORD_SIZE))-1:0] core_req_addr;
    wire [NUM_REQS-1:0][WORD_SIZE-1:0]      core_req_byteen;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_req_data;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0]      core_req_tag;
    wire [NUM_REQS-1:0]                     core_req_ready;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_req_valid[i]  = core_bus_if[i].req_valid;
        assign core_req_rw[i]     = core_bus_if[i].req_data.rw;
        assign core_req_addr[i]   = core_bus_if[i].req_data.addr;
        assign core_req_byteen[i] = core_bus_if[i].req_data.byteen;
        assign core_req_data[i]   = core_bus_if[i].req_data.data;
        assign core_req_tag[i]    = core_bus_if[i].req_data.tag;
        assign core_bus_if[i].req_ready = core_req_ready[i];
    end
    wire [NUM_REQS-1:0]                  core_rsp_valid_s;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_rsp_data_s;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0]   core_rsp_tag_s;
    wire [NUM_REQS-1:0]                  core_rsp_ready_s;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
    wire [1-1:0] core_rsp_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __core_rsp_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (core_rsp_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW   ((8 * WORD_SIZE) + TAG_WIDTH),
            .SIZE    ((NC_BYPASS && !DIRECT_PASSTHRU) ? (((CORE_OUT_REG) < (2)) ? (CORE_OUT_REG) : (2)) : 0),
            .OUT_REG (((CORE_OUT_REG & 1) + ((CORE_OUT_REG >> 2) << 1)))
        ) core_rsp_buf (
            .clk       (clk),
            .reset     (core_rsp_reset),
            .valid_in  (core_rsp_valid_s[i]),
            .ready_in  (core_rsp_ready_s[i]),
            .data_in   ({core_rsp_data_s[i], core_rsp_tag_s[i]}),
            .data_out  ({core_bus_if[i].rsp_data.data, core_bus_if[i].rsp_data.tag}), 
            .valid_out (core_bus_if[i].rsp_valid),
            .ready_out (core_bus_if[i].rsp_ready)
        );
    end
    wire                             mem_req_valid_s;
    wire                             mem_req_rw_s;
    wire [LINE_SIZE-1:0]             mem_req_byteen_s;   
    wire [(32-$clog2(LINE_SIZE))-1:0]    mem_req_addr_s;
    wire [(8 * LINE_SIZE)-1:0]        mem_req_data_s;
    wire [MEM_TAG_WIDTH-1:0]         mem_req_tag_s;
    wire                             mem_req_ready_s;
    VX_elastic_buffer #(
        .DATAW   (1 + LINE_SIZE + (32-$clog2(LINE_SIZE)) + (8 * LINE_SIZE) + MEM_TAG_WIDTH),
        .SIZE    ((NC_BYPASS && !DIRECT_PASSTHRU) ? (((MEM_OUT_REG) < (2)) ? (MEM_OUT_REG) : (2)) : 0),
        .OUT_REG (((MEM_OUT_REG & 1) + ((MEM_OUT_REG >> 2) << 1)))
    ) mem_req_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (mem_req_valid_s), 
        .ready_in  (mem_req_ready_s), 
        .data_in   ({mem_req_rw_s, mem_req_byteen_s, mem_req_addr_s, mem_req_data_s, mem_req_tag_s}),
        .data_out  ({mem_bus_if.req_data.rw, mem_bus_if.req_data.byteen, mem_bus_if.req_data.addr, mem_bus_if.req_data.data, mem_bus_if.req_data.tag}), 
        .valid_out (mem_bus_if.req_valid), 
        .ready_out (mem_bus_if.req_ready)
    );
    wire [NUM_REQS-1:0]                     core_req_valid_b;
    wire [NUM_REQS-1:0]                     core_req_rw_b;
    wire [NUM_REQS-1:0][(32-$clog2(WORD_SIZE))-1:0] core_req_addr_b;
    wire [NUM_REQS-1:0][WORD_SIZE-1:0]      core_req_byteen_b;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_req_data_b;
    wire [NUM_REQS-1:0][CORE_TAG_X_WIDTH-1:0] core_req_tag_b;
    wire [NUM_REQS-1:0]                     core_req_ready_b;
    wire [NUM_REQS-1:0]                     core_rsp_valid_b;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_rsp_data_b;
    wire [NUM_REQS-1:0][CORE_TAG_X_WIDTH-1:0] core_rsp_tag_b;
    wire [NUM_REQS-1:0]                     core_rsp_ready_b;
    wire                            mem_req_valid_b;
    wire                            mem_req_rw_b;
    wire [(32-$clog2(LINE_SIZE))-1:0]   mem_req_addr_b;
    wire [LINE_SIZE-1:0]            mem_req_byteen_b;
    wire [(8 * LINE_SIZE)-1:0]       mem_req_data_b;
    wire [MEM_TAG_X_WIDTH-1:0]      mem_req_tag_b;
    wire                            mem_req_ready_b;
    wire                            mem_rsp_valid_b;
    wire [(8 * LINE_SIZE)-1:0]       mem_rsp_data_b;
    wire [MEM_TAG_X_WIDTH-1:0]      mem_rsp_tag_b;
    wire                            mem_rsp_ready_b;
    if (NC_BYPASS) begin
    wire [1-1:0] nc_bypass_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __nc_bypass_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (nc_bypass_reset)                          
    );
        VX_cache_bypass #(
            .NUM_REQS          (NUM_REQS),
            .NC_TAG_BIT        (NC_TAG_BIT),
            .NC_ENABLE         (NC_ENABLE),
            .PASSTHRU          (PASSTHRU),
            .CORE_ADDR_WIDTH   ((32-$clog2(WORD_SIZE))),
            .CORE_DATA_SIZE    (WORD_SIZE), 
            .CORE_TAG_IN_WIDTH (TAG_WIDTH),
            .MEM_ADDR_WIDTH    ((32-$clog2(LINE_SIZE))),
            .MEM_DATA_SIZE     (LINE_SIZE),
            .MEM_TAG_IN_WIDTH  (MEM_TAG_X_WIDTH),
            .MEM_TAG_OUT_WIDTH (MEM_TAG_WIDTH),
            .UUID_WIDTH        (UUID_WIDTH)
        ) cache_bypass (
            .clk                (clk),
            .reset              (nc_bypass_reset),
            .core_req_valid_in  (core_req_valid),
            .core_req_rw_in     (core_req_rw),
            .core_req_byteen_in (core_req_byteen),
            .core_req_addr_in   (core_req_addr),
            .core_req_data_in   (core_req_data), 
            .core_req_tag_in    (core_req_tag),
            .core_req_ready_in  (core_req_ready),
            .core_req_valid_out (core_req_valid_b),
            .core_req_rw_out    (core_req_rw_b),
            .core_req_byteen_out(core_req_byteen_b),
            .core_req_addr_out  (core_req_addr_b),
            .core_req_data_out  (core_req_data_b), 
            .core_req_tag_out   (core_req_tag_b),
            .core_req_ready_out (core_req_ready_b),
            .core_rsp_valid_in  (core_rsp_valid_b),
            .core_rsp_data_in   (core_rsp_data_b),
            .core_rsp_tag_in    (core_rsp_tag_b),
            .core_rsp_ready_in  (core_rsp_ready_b),
            .core_rsp_valid_out (core_rsp_valid_s),
            .core_rsp_data_out  (core_rsp_data_s),
            .core_rsp_tag_out   (core_rsp_tag_s),
            .core_rsp_ready_out (core_rsp_ready_s),
            .mem_req_valid_in   (mem_req_valid_b),
            .mem_req_rw_in      (mem_req_rw_b), 
            .mem_req_addr_in    (mem_req_addr_b),
            .mem_req_byteen_in  (mem_req_byteen_b),
            .mem_req_data_in    (mem_req_data_b),
            .mem_req_tag_in     (mem_req_tag_b),
            .mem_req_ready_in   (mem_req_ready_b),
            .mem_req_valid_out  (mem_req_valid_s),
            .mem_req_addr_out   (mem_req_addr_s),
            .mem_req_rw_out     (mem_req_rw_s),
            .mem_req_byteen_out (mem_req_byteen_s),
            .mem_req_data_out   (mem_req_data_s),
            .mem_req_tag_out    (mem_req_tag_s),
            .mem_req_ready_out  (mem_req_ready_s),
            .mem_rsp_valid_in   (mem_bus_if.rsp_valid), 
            .mem_rsp_data_in    (mem_bus_if.rsp_data.data),
            .mem_rsp_tag_in     (mem_bus_if.rsp_data.tag),
            .mem_rsp_ready_in   (mem_bus_if.rsp_ready),
            .mem_rsp_valid_out  (mem_rsp_valid_b), 
            .mem_rsp_data_out   (mem_rsp_data_b),
            .mem_rsp_tag_out    (mem_rsp_tag_b),
            .mem_rsp_ready_out  (mem_rsp_ready_b)
        );
    end else begin        
        assign core_req_valid_b = core_req_valid;
        assign core_req_rw_b    = core_req_rw;
        assign core_req_addr_b  = core_req_addr;
        assign core_req_byteen_b= core_req_byteen;
        assign core_req_data_b  = core_req_data;
        assign core_req_tag_b   = core_req_tag;
        assign core_req_ready   = core_req_ready_b;
        assign core_rsp_valid_s = core_rsp_valid_b;
        assign core_rsp_data_s  = core_rsp_data_b;
        assign core_rsp_tag_s   = core_rsp_tag_b;
        assign core_rsp_ready_b = core_rsp_ready_s;
        assign mem_req_valid_s  = mem_req_valid_b;
        assign mem_req_addr_s   = mem_req_addr_b;
        assign mem_req_rw_s     = mem_req_rw_b;
        assign mem_req_byteen_s = mem_req_byteen_b;
        assign mem_req_data_s   = mem_req_data_b;
        assign mem_req_ready_b  = mem_req_ready_s;
        VX_bits_insert #( 
            .N   (MEM_TAG_WIDTH-1),
            .POS (NC_TAG_BIT)
        ) mem_req_tag_insert (
            .data_in  (mem_req_tag_b),
            .sel_in   (1'b0),
            .data_out (mem_req_tag_s)
        );
        assign mem_rsp_valid_b = mem_bus_if.rsp_valid;
        assign mem_rsp_data_b  = mem_bus_if.rsp_data.data;
        assign mem_bus_if.rsp_ready = mem_rsp_ready_b;
        VX_bits_remove #( 
            .N   (MEM_TAG_WIDTH),
            .POS (NC_TAG_BIT)
        ) mem_rsp_tag_remove (
            .data_in  (mem_bus_if.rsp_data.tag),
            .data_out (mem_rsp_tag_b)
        );
    end 
    if (PASSTHRU != 0) begin
        assign core_req_ready_b = '0;
        assign core_rsp_valid_b = '0;
        assign core_rsp_data_b  = '0;
        assign core_rsp_tag_b   = '0;
        assign mem_req_valid_b  = 0;
        assign mem_req_addr_b   = '0;
        assign mem_req_rw_b     = '0;
        assign mem_req_byteen_b = '0;
        assign mem_req_data_b   = '0;
        assign mem_req_tag_b    = '0;
        assign mem_rsp_ready_b = 0;
    end else begin
        VX_mem_bus_if #(
            .DATA_SIZE (WORD_SIZE),
            .TAG_WIDTH (CORE_TAG_X_WIDTH)
        ) core_bus_wrap_if[NUM_REQS]();
        VX_mem_bus_if #(
            .DATA_SIZE (LINE_SIZE), 
            .TAG_WIDTH (MEM_TAG_X_WIDTH)
        ) mem_bus_wrap_if();
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign core_bus_wrap_if[i].req_valid  = core_req_valid_b[i];
            assign core_bus_wrap_if[i].req_data.rw     = core_req_rw_b[i];
            assign core_bus_wrap_if[i].req_data.addr   = core_req_addr_b[i];
            assign core_bus_wrap_if[i].req_data.byteen = core_req_byteen_b[i];
            assign core_bus_wrap_if[i].req_data.data   = core_req_data_b[i];
            assign core_bus_wrap_if[i].req_data.tag    = core_req_tag_b[i];
            assign core_req_ready_b[i] = core_bus_wrap_if[i].req_ready;
        end
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign core_rsp_valid_b[i] = core_bus_wrap_if[i].rsp_valid;
            assign core_rsp_data_b[i]  = core_bus_wrap_if[i].rsp_data.data;
            assign core_rsp_tag_b[i]   = core_bus_wrap_if[i].rsp_data.tag;
            assign core_bus_wrap_if[i].rsp_ready = core_rsp_ready_b[i];
        end
        assign mem_req_valid_b  = mem_bus_wrap_if.req_valid;
        assign mem_req_addr_b   = mem_bus_wrap_if.req_data.addr;
        assign mem_req_rw_b     = mem_bus_wrap_if.req_data.rw;
        assign mem_req_byteen_b = mem_bus_wrap_if.req_data.byteen;
        assign mem_req_data_b   = mem_bus_wrap_if.req_data.data;
        assign mem_req_tag_b    = mem_bus_wrap_if.req_data.tag;
        assign mem_bus_wrap_if.req_ready = mem_req_ready_b;
        assign mem_bus_wrap_if.rsp_valid = mem_rsp_valid_b;
        assign mem_bus_wrap_if.rsp_data.data  = mem_rsp_data_b;
        assign mem_bus_wrap_if.rsp_data.tag   = mem_rsp_tag_b;
        assign mem_rsp_ready_b = mem_bus_wrap_if.rsp_ready;
    wire [1-1:0] cache_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __cache_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (cache_reset)                          
    );
        VX_cache #(
            .INSTANCE_ID  (INSTANCE_ID),
            .CACHE_SIZE   (CACHE_SIZE),
            .LINE_SIZE    (LINE_SIZE),
            .NUM_BANKS    (NUM_BANKS),
            .NUM_WAYS     (NUM_WAYS),
            .WORD_SIZE    (WORD_SIZE),
            .NUM_REQS     (NUM_REQS),
            .CRSQ_SIZE    (CRSQ_SIZE),
            .MSHR_SIZE    (MSHR_SIZE),
            .MRSQ_SIZE    (MRSQ_SIZE),
            .MREQ_SIZE    (MREQ_SIZE),
            .WRITE_ENABLE (WRITE_ENABLE),
            .UUID_WIDTH   (UUID_WIDTH),
            .TAG_WIDTH    (CORE_TAG_X_WIDTH),
            .CORE_OUT_REG (NC_BYPASS ? 1 : CORE_OUT_REG),
            .MEM_OUT_REG  (NC_BYPASS ? 1 : MEM_OUT_REG)
        ) cache (
            .clk            (clk),
            .reset          (cache_reset),
            .core_bus_if    (core_bus_wrap_if),
            .mem_bus_if     (mem_bus_wrap_if)
        );
    end
endmodule
