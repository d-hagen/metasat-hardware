package VX_gpu_pkg;
    typedef struct packed {
        logic                    valid;
        logic [4-1:0] tmask;
    } tmc_t;
    typedef struct packed {
        logic                   valid;
        logic [4-1:0]  wmask;
        logic [(32-1)-1:0]    pc;
    } wspawn_t;
    typedef struct packed {
        logic                    valid;
        logic                    is_dvg;
        logic [4-1:0] then_tmask;
        logic [4-1:0] else_tmask;
        logic [(32-1)-1:0]     next_pc;
    } split_t;
    typedef struct packed {
        logic valid;
        logic [((($clog2((((4-1) != 0) ? (4-1) : 1))) != 0) ? ($clog2((((4-1) != 0) ? (4-1) : 1))) : 1)-1:0] stack_ptr;
    } join_t;
    typedef struct packed {
        logic                   valid;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]   id;
        logic                   is_global;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]   size_m1;
        logic                   is_noop;
    } barrier_t;
    typedef struct packed {
        logic [32-1:0]       startup_addr;
        logic [32-1:0]       startup_arg;
        logic [7:0]             mpm_class;
    } base_dcrs_t;
    typedef struct packed {
        logic [44-1:0] reads;
        logic [44-1:0] writes;
        logic [44-1:0] read_misses;
        logic [44-1:0] write_misses;
        logic [44-1:0] bank_stalls;
        logic [44-1:0] mshr_stalls;
        logic [44-1:0] mem_stalls;
        logic [44-1:0] crsp_stalls;
    } cache_perf_t;
    typedef struct packed {
        logic [44-1:0] reads;
        logic [44-1:0] writes;
        logic [44-1:0] latency;
    } mem_perf_t;
    typedef struct packed {
        logic [44-1:0] idles;
        logic [44-1:0] stalls;
    } sched_perf_t;
    typedef struct packed {
        logic [44-1:0] ibf_stalls;
        logic [44-1:0] scb_stalls;
        logic [44-1:0] opd_stalls;
        logic [(3 + 0)-1:0][44-1:0] units_uses;
        logic [(2)-1:0][44-1:0] sfu_uses;
    } issue_perf_t;
    typedef struct packed {
        logic use_PC;
        logic use_imm;
        logic is_w;
        logic [2-1:0] xtype;
        logic [32-1:0] imm;
    } alu_args_t;
    typedef struct packed {
        logic [($bits(alu_args_t)-3-2)-1:0] __padding;
        logic [3-1:0] frm;
        logic [2-1:0] fmt;
    } fpu_args_t;
    typedef struct packed {
        logic [($bits(alu_args_t)-1-1-12)-1:0] __padding;
        logic is_store;
        logic is_float;
        logic [12-1:0] offset;
    } lsu_args_t;
    typedef struct packed {
        logic [($bits(alu_args_t)-1-12-5)-1:0] __padding;
        logic use_imm;
        logic [12-1:0] addr;
        logic [4:0] imm;
    } csr_args_t;
    typedef struct packed {
        logic [($bits(alu_args_t)-1)-1:0] __padding;
        logic is_neg;
    } wctl_args_t;
    typedef union packed {
        alu_args_t  alu;
        fpu_args_t  fpu;
        lsu_args_t  lsu;
        csr_args_t  csr;
        wctl_args_t wctl;
    } op_args_t;
    localparam LSU_WORD_SIZE        = 32 / 8;
    localparam LSU_ADDR_WIDTH	    = (32 - $clog2(LSU_WORD_SIZE));
    localparam LSU_MEM_BATCHES      = 1;
    localparam LSU_TAG_ID_BITS      = ($clog2((2 * (4 / 4))) + $clog2(LSU_MEM_BATCHES));
    localparam LSU_TAG_WIDTH        = (1 + LSU_TAG_ID_BITS);
    localparam LSU_NUM_REQS	        = 1 * 4;
    localparam ICACHE_WORD_SIZE	    = 4;
    localparam ICACHE_ADDR_WIDTH	= (32 - $clog2(ICACHE_WORD_SIZE));
    localparam ICACHE_LINE_SIZE	    = 16;
    localparam ICACHE_TAG_ID_BITS	= ((($clog2(4)) != 0) ? ($clog2(4)) : 1);
    localparam ICACHE_TAG_WIDTH	    = (1 + ICACHE_TAG_ID_BITS);
    localparam ICACHE_MEM_DATA_WIDTH = (ICACHE_LINE_SIZE * 8);
    localparam ICACHE_MEM_TAG_WIDTH = 
        (
        ($clog2(16) + $clog2(1)) + (((((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1) > 1) ? $clog2((((((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1) + 1 - 1) / (1))) : 0));
    localparam DCACHE_WORD_SIZE	    = (((4 * (32 / 8)) < (16)) ? (4 * (32 / 8)) : (16));
    localparam DCACHE_ADDR_WIDTH	= (32 - $clog2(DCACHE_WORD_SIZE));
    localparam DCACHE_LINE_SIZE 	= 16;
    localparam DCACHE_CHANNELS	    = ((((4 * LSU_WORD_SIZE) / DCACHE_WORD_SIZE) != 0) ? ((4 * LSU_WORD_SIZE) / DCACHE_WORD_SIZE) : 1);
    localparam DCACHE_NUM_REQS	    = 1 * DCACHE_CHANNELS;
    localparam DCACHE_MERGED_REQS   = (4 * LSU_WORD_SIZE) / DCACHE_WORD_SIZE;
    localparam DCACHE_MEM_BATCHES   = ((DCACHE_MERGED_REQS + DCACHE_CHANNELS - 1) / (DCACHE_CHANNELS));
    localparam DCACHE_TAG_ID_BITS   = ($clog2(((((2 * (4 / 4))) > ((((4 * (32 / 8)) < (16)) ? (4 * (32 / 8)) : (16)) / (32 / 8))) ? ((2 * (4 / 4))) : ((((4 * (32 / 8)) < (16)) ? (4 * (32 / 8)) : (16)) / (32 / 8)))) + $clog2(DCACHE_MEM_BATCHES));
    localparam DCACHE_TAG_WIDTH	    = (1 + DCACHE_TAG_ID_BITS);
    localparam DCACHE_MEM_DATA_WIDTH = (DCACHE_LINE_SIZE * 8);
    localparam DCACHE_MEM_TAG_WIDTH = 
        (
        ((((
        ($clog2(16) + $clog2((((4) < (4)) ? (4) : (4))))) > (
        ($clog2(DCACHE_NUM_REQS) + $clog2(DCACHE_LINE_SIZE / DCACHE_WORD_SIZE) + 
        (DCACHE_TAG_WIDTH + (((((4) < (1)) ? (4) : (1)) > (((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1)) ? $clog2((((((4) < (1)) ? (4) : (1)) + (((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1) - 1) / ((((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1)))) : 0))))) ? (
        ($clog2(16) + $clog2((((4) < (4)) ? (4) : (4))))) : (
        ($clog2(DCACHE_NUM_REQS) + $clog2(DCACHE_LINE_SIZE / DCACHE_WORD_SIZE) + 
        (DCACHE_TAG_WIDTH + (((((4) < (1)) ? (4) : (1)) > (((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1)) ? $clog2((((((4) < (1)) ? (4) : (1)) + (((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1) - 1) / ((((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1)))) : 0))))) + 1) + (((((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1) > 1) ? $clog2((((((((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) != 0) ? (((((((4) < (1)) ? (4) : (1)) / 4) != 0) ? ((((4) < (1)) ? (4) : (1)) / 4) : 1)) : 1) + 1 - 1) / (1))) : 0));
    localparam L1_MEM_TAG_WIDTH     = (((ICACHE_MEM_TAG_WIDTH) > (DCACHE_MEM_TAG_WIDTH)) ? (ICACHE_MEM_TAG_WIDTH) : (DCACHE_MEM_TAG_WIDTH));
    localparam L1_MEM_ARB_TAG_WIDTH = (L1_MEM_TAG_WIDTH + $clog2(2));
    localparam ICACHE_MEM_ARB_IDX = 0;
    localparam DCACHE_MEM_ARB_IDX = ICACHE_MEM_ARB_IDX + 1;
    localparam L2_WORD_SIZE	        = 16;
    localparam L2_NUM_REQS	        = (((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1);
    localparam L2_TAG_WIDTH	        = L1_MEM_ARB_TAG_WIDTH;
    localparam L2_MEM_DATA_WIDTH	= (16 * 8);
    localparam L2_MEM_TAG_WIDTH     = 
        ($clog2(L2_NUM_REQS) + $clog2(16 / L2_WORD_SIZE) + L2_TAG_WIDTH);
    localparam L3_WORD_SIZE	        = 16;
    localparam L3_NUM_REQS	        = 1;
    localparam L3_TAG_WIDTH	        = L2_MEM_TAG_WIDTH;
    localparam L3_MEM_DATA_WIDTH	= (16 * 8);
    localparam L3_MEM_TAG_WIDTH     = 
        ($clog2(L3_NUM_REQS) + $clog2(16 / L3_WORD_SIZE) + L3_TAG_WIDTH);
    localparam ISSUE_ISW   = $clog2((((4 / 8) != 0) ? (4 / 8) : 1));
    localparam ISSUE_ISW_W = (((ISSUE_ISW) != 0) ? (ISSUE_ISW) : 1);
    localparam PER_ISSUE_WARPS = 4 / (((4 / 8) != 0) ? (4 / 8) : 1);
    localparam ISSUE_WIS   = $clog2(PER_ISSUE_WARPS);
    localparam ISSUE_WIS_W = (((ISSUE_WIS) != 0) ? (ISSUE_WIS) : 1);
    function logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wis_to_wid(
        input logic [ISSUE_WIS_W-1:0] wis,
        input logic [ISSUE_ISW_W-1:0] isw
    );
        if (ISSUE_WIS == 0) begin
            wis_to_wid = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(isw);
        end else if (ISSUE_ISW == 0) begin
            wis_to_wid = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(wis);
        end else begin
            wis_to_wid = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'({wis, isw});
        end
    endfunction
    function logic [ISSUE_ISW_W-1:0] wid_to_isw(
        input logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wid
    );
        if (ISSUE_ISW != 0) begin
            wid_to_isw = wid[ISSUE_ISW_W-1:0];
        end else begin
            wid_to_isw = 0;
        end
    endfunction
    function logic [ISSUE_WIS_W-1:0] wid_to_wis(
        input logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wid
    );
        if (ISSUE_WIS != 0) begin
            wid_to_wis = ISSUE_WIS_W'(wid >> ISSUE_ISW);
        end else begin
            wid_to_wis = 0;
        end
    endfunction
    function logic [((($clog2((2))) != 0) ? ($clog2((2))) : 1)-1:0] op_to_sfu_type(
        input logic [4-1:0] op_type
    );
        case (op_type)
        4'h6,
        4'h7,
        4'h8: op_to_sfu_type = 0;
        default: op_to_sfu_type = 1;
        endcase
    endfunction
endpackage
