module VX_cache_mshr #(
    parameter  INSTANCE_ID= "",
    parameter BANK_ID           = 0,
    parameter LINE_SIZE         = 16, 
    parameter NUM_BANKS         = 1,
    parameter MSHR_SIZE         = 4,
    parameter UUID_WIDTH        = 0,
    parameter DATA_WIDTH        = 1,
    parameter MSHR_ADDR_WIDTH   = (((MSHR_SIZE) > 1) ? $clog2(MSHR_SIZE) : 1)
) (
    input wire clk,
    input wire reset,
    input wire[(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0]     deq_req_uuid,
    input wire[(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0]     lkp_req_uuid,
    input wire[(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0]     fin_req_uuid,
    input wire                          allocate_valid,
    input wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] allocate_addr,
    input wire                          allocate_rw,
    input wire [DATA_WIDTH-1:0]         allocate_data,
    output wire [MSHR_ADDR_WIDTH-1:0]   allocate_id,
    output wire [MSHR_ADDR_WIDTH-1:0]   allocate_tail,
    output wire                         allocate_ready,
    input wire                          lookup_valid,
    input wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] lookup_addr,
    output wire [MSHR_SIZE-1:0]         lookup_matches,
    input wire                          fill_valid,
    input wire [MSHR_ADDR_WIDTH-1:0]    fill_id,
    output wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] fill_addr,
    output wire                         dequeue_valid,
    output wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] dequeue_addr,
    output wire                         dequeue_rw,
    output wire [DATA_WIDTH-1:0]        dequeue_data,
    output wire [MSHR_ADDR_WIDTH-1:0]   dequeue_id,
    input wire                          dequeue_ready,
    input wire                          finalize_valid,
    input wire                          finalize_release,
    input wire                          finalize_pending,
    input wire [MSHR_ADDR_WIDTH-1:0]    finalize_id,
    input wire [MSHR_ADDR_WIDTH-1:0]    finalize_tail
);
    reg [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] addr_table [MSHR_SIZE-1:0];
    reg [MSHR_ADDR_WIDTH-1:0] next_index [MSHR_SIZE-1:0];
    reg [MSHR_SIZE-1:0] valid_table, valid_table_n;
    reg [MSHR_SIZE-1:0] next_table, next_table_x, next_table_n;
    reg [MSHR_SIZE-1:0] write_table;
    reg allocate_rdy, allocate_rdy_n;
    reg [MSHR_ADDR_WIDTH-1:0] allocate_id_r, allocate_id_n;
    reg dequeue_val, dequeue_val_n;
    reg [MSHR_ADDR_WIDTH-1:0] dequeue_id_r, dequeue_id_n;
    wire [MSHR_ADDR_WIDTH-1:0] tail_idx;
    wire allocate_fire = allocate_valid && allocate_ready;
    wire dequeue_fire = dequeue_valid && dequeue_ready;
    wire [MSHR_SIZE-1:0] addr_matches;
    for (genvar i = 0; i < MSHR_SIZE; ++i) begin
        assign addr_matches[i] = valid_table[i] && (addr_table[i] == lookup_addr);
    end
    VX_lzc #(
        .N (MSHR_SIZE),
        .REVERSE (1)
    ) allocate_sel (
        .data_in   (~valid_table_n),
        .data_out  (allocate_id_n),
        .valid_out (allocate_rdy_n)
    );
    VX_onehot_encoder #(
        .N (MSHR_SIZE)
    ) tail_sel (
        .data_in (addr_matches & ~next_table_x),
        .data_out (tail_idx),
        . valid_out ()
    );
    always @(*) begin
        valid_table_n = valid_table;
        next_table_x  = next_table;
        dequeue_val_n = dequeue_val;
        dequeue_id_n  = dequeue_id;
        if (fill_valid) begin
            dequeue_val_n = 1;
            dequeue_id_n = fill_id;
        end
        if (dequeue_fire) begin
            valid_table_n[dequeue_id] = 0;
            if (next_table[dequeue_id]) begin
                dequeue_id_n = next_index[dequeue_id];
            end else begin
                dequeue_val_n = 0;
            end
        end
        if (finalize_valid) begin
            if (finalize_release) begin
                valid_table_n[finalize_id] = 0;
            end
            if (finalize_pending) begin
                next_table_x[finalize_tail] = 1;
            end
        end
        next_table_n = next_table_x;
        if (allocate_fire) begin
            valid_table_n[allocate_id] = 1;
            next_table_n[allocate_id] = 0;
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            valid_table  <= '0;
            allocate_rdy <= 0;
            dequeue_val  <= 0;
        end else begin
            valid_table  <= valid_table_n;
            allocate_rdy <= allocate_rdy_n;
            dequeue_val  <= dequeue_val_n;
        end
        if (allocate_fire) begin
            addr_table[allocate_id]  <= allocate_addr;
            write_table[allocate_id] <= allocate_rw;
        end
        if (finalize_valid && finalize_pending) begin
            next_index[finalize_tail] <= finalize_id;
        end
        dequeue_id_r  <= dequeue_id_n;
        allocate_id_r <= allocate_id_n;
        next_table    <= next_table_n;
    end
    VX_dp_ram #(
        .DATAW  (DATA_WIDTH),
        .SIZE   (MSHR_SIZE),
        .LUTRAM (1)
    ) entries (
        .clk   (clk),
        .read  (1'b1),
        .write (allocate_valid),
        . wren (),               
        .waddr (allocate_id_r),     
        .wdata (allocate_data),
        .raddr (dequeue_id_r),
        .rdata (dequeue_data)
    );
    assign fill_addr = addr_table[fill_id];
    assign allocate_ready = allocate_rdy;
    assign allocate_id    = allocate_id_r;
    assign allocate_tail  = tail_idx;
    assign dequeue_valid  = dequeue_val;
    assign dequeue_addr   = addr_table[dequeue_id_r];
    assign dequeue_rw     = write_table[dequeue_id_r];
    assign dequeue_id     = dequeue_id_r;
    assign lookup_matches = addr_matches & ~write_table;
endmodule
