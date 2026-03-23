package VX_gpu_pkg;
    typedef struct packed {
        logic                    valid;
        logic [4-1:0] tmask;
    } tmc_t;
    typedef struct packed {
        logic                   valid;
        logic [4-1:0]  wmask;
        logic [32-1:0]       pc;
    } wspawn_t;
    typedef struct packed {
        logic                    valid;
        logic                    is_dvg;
        logic [4-1:0] then_tmask;
        logic [4-1:0] else_tmask;
        logic [32-1:0]        next_pc;
    } split_t;
    typedef struct packed {
        logic valid;
        logic is_dvg;
    } join_t;
    typedef struct packed {
        logic                   valid;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]   id;
        logic                   is_global;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]   size_m1;
    } barrier_t;
    typedef struct packed {
        logic [32-1:0]   startup_addr;
        logic [7:0]         mpm_class;
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
    /*verilator lint_off UNUSED*/ 
    localparam ICACHE_WORD_SIZE	    = 4;
    localparam ICACHE_ADDR_WIDTH	= (32 - $clog2(ICACHE_WORD_SIZE));
    localparam ICACHE_LINE_SIZE	    = ((0 || 0) ? 16 : 16);
    localparam ICACHE_TAG_ID_BITS	= ((($clog2(4)) != 0) ? ($clog2(4)) : 1);
    localparam ICACHE_TAG_WIDTH	    = (1 + ICACHE_TAG_ID_BITS);
    localparam ICACHE_MEM_DATA_WIDTH = (ICACHE_LINE_SIZE * 8);
    localparam ICACHE_MEM_TAG_WIDTH = 
        (
        ($clog2(16) + $clog2(1) + 1) + ((((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1) > 1) ? $clog2((((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1) + 1 - 1) / 1) : 0));
    localparam DCACHE_WORD_SIZE	    = (32 / 8);
    localparam DCACHE_ADDR_WIDTH	= (32 - $clog2(DCACHE_WORD_SIZE));
    localparam DCACHE_LINE_SIZE 	= ((0 || 0) ? 16 : 16);
    localparam DCACHE_NUM_REQS	    = (((((((4) < (4)) ? (4) : (4)))) > (((((4) < (4)) ? (4) : (4))))) ? (((((4) < (4)) ? (4) : (4)))) : (((((4) < (4)) ? (4) : (4)))));
    localparam LSU_MEM_REQS	        = (((4) < (4)) ? (4) : (4));
    localparam DCACHE_NUM_BATCHES	= ((LSU_MEM_REQS + DCACHE_NUM_REQS - 1) / DCACHE_NUM_REQS);
    localparam DCACHE_BATCH_SEL_BITS = $clog2(DCACHE_NUM_BATCHES);
    localparam LSUQ_TAG_BITS	    = ($clog2((2 * (4 / (((4) < (4)) ? (4) : (4))))) + DCACHE_BATCH_SEL_BITS);
    localparam DCACHE_TAG_ID_BITS	= (LSUQ_TAG_BITS + (1 + 1));
    localparam DCACHE_TAG_WIDTH	    = (1 + DCACHE_TAG_ID_BITS);
    localparam DCACHE_NOSM_TAG_WIDTH = (DCACHE_TAG_WIDTH - 1);
    localparam DCACHE_MEM_DATA_WIDTH = (DCACHE_LINE_SIZE * 8);
    localparam DCACHE_MEM_TAG_WIDTH = 
        ((((
        ($clog2(16) + $clog2(((((4) < (4)) ? (4) : (4)))) + 1)) > (
        ($clog2(DCACHE_NUM_REQS) + $clog2(DCACHE_LINE_SIZE / DCACHE_WORD_SIZE) + 
        (DCACHE_NOSM_TAG_WIDTH + (((((4) < (1)) ? (4) : (1)) > ((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1)) ? $clog2(((((4) < (1)) ? (4) : (1)) + ((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1) - 1) / ((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1)) : 0))))) ? (
        ($clog2(16) + $clog2(((((4) < (4)) ? (4) : (4)))) + 1)) : (
        ($clog2(DCACHE_NUM_REQS) + $clog2(DCACHE_LINE_SIZE / DCACHE_WORD_SIZE) + 
        (DCACHE_NOSM_TAG_WIDTH + (((((4) < (1)) ? (4) : (1)) > ((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1)) ? $clog2(((((4) < (1)) ? (4) : (1)) + ((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1) - 1) / ((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1)) : 0))))) + ((((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1) > 1) ? $clog2((((((((1 / 4) != 0) ? (1 / 4) : 1)) != 0) ? ((((1 / 4) != 0) ? (1 / 4) : 1)) : 1) + 1 - 1) / 1) : 0));
    localparam L1_MEM_TAG_WIDTH     = (((ICACHE_MEM_TAG_WIDTH) > (DCACHE_MEM_TAG_WIDTH)) ? (ICACHE_MEM_TAG_WIDTH) : (DCACHE_MEM_TAG_WIDTH));
    localparam L1_MEM_ARB_TAG_WIDTH	= (L1_MEM_TAG_WIDTH + $clog2(2));
    localparam L2_WORD_SIZE	        = ((0 || 0) ? 16 : 16);
    localparam L2_NUM_REQS	        = (((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1);
    localparam L2_TAG_WIDTH	        = L1_MEM_ARB_TAG_WIDTH;
    localparam L2_MEM_DATA_WIDTH	= (((0 || 0) ? 16 : 16) * 8);
    localparam L2_MEM_TAG_WIDTH     = 
        ($clog2(L2_NUM_REQS) + $clog2(((0 || 0) ? 16 : 16) / L2_WORD_SIZE) + L2_TAG_WIDTH);
    localparam L3_WORD_SIZE	        = ((0 || 0) ? 16 : 16);
    localparam L3_NUM_REQS	        = 1;
    localparam L3_TAG_WIDTH	        = L2_MEM_TAG_WIDTH;
    localparam L3_MEM_DATA_WIDTH	= (((0 || 0) ? 16 : 16) * 8);
    localparam L3_MEM_TAG_WIDTH     = 
        ($clog2(L3_NUM_REQS) + $clog2(((0 || 0) ? 16 : 16) / L3_WORD_SIZE) + L3_TAG_WIDTH);
    /*verilator lint_on UNUSED*/ 
    localparam ISSUE_IDX_W = ((((((4) < (4)) ? (4) : (4))) > 1) ? $clog2((((4) < (4)) ? (4) : (4))) : 1);    
    localparam ISSUE_RATIO = 4 / (((4) < (4)) ? (4) : (4));
    localparam ISSUE_WIS_W = (((ISSUE_RATIO) > 1) ? $clog2(ISSUE_RATIO) : 1);
    localparam ISSUE_ADDRW = (((32 * (ISSUE_RATIO)) > 1) ? $clog2(32 * (ISSUE_RATIO)) : 1);
    function logic [ISSUE_IDX_W-1:0] wid_to_isw(
        input logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wid
    );
        if ((((4) < (4)) ? (4) : (4)) > 1) begin    
            wid_to_isw = ISSUE_IDX_W'(wid);
        end else begin
            wid_to_isw = 0;
        end
    endfunction
    function logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wis_to_wid(
        input logic [ISSUE_WIS_W-1:0] wis, 
        input logic [ISSUE_IDX_W-1:0] isw
    );
        wis_to_wid = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'({wis, isw} >> (ISSUE_IDX_W-$clog2((((4) < (4)) ? (4) : (4)))));
    endfunction
    function logic [ISSUE_WIS_W-1:0] wid_to_wis(
        input logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wid
    );
        wid_to_wis = ISSUE_WIS_W'(wid >> $clog2((((4) < (4)) ? (4) : (4))));
    endfunction
    function logic [ISSUE_ADDRW-1:0] wis_to_addr(
        input logic [$clog2(32)-1:0] rid,
        input logic [ISSUE_WIS_W-1:0] wis        
    );
        wis_to_addr = ISSUE_ADDRW'({rid, wis} >> (ISSUE_WIS_W-$clog2(ISSUE_RATIO)));
    endfunction
endpackage
