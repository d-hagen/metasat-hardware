module VX_pending_size #(
    parameter SIZE      = 1,
    parameter INCRW     = 1,
    parameter DECRW     = 1,
    parameter ALM_FULL  = (SIZE - 1),
    parameter ALM_EMPTY = 1,
    parameter SIZEW     = $clog2(SIZE+1)
) (
    input wire  clk,
    input wire  reset,
    input wire [INCRW-1:0] incr,
    input wire [DECRW-1:0] decr,
    output wire empty,
    output wire alm_empty,
    output wire full,
    output wire alm_full,
    output wire [SIZEW-1:0] size
);
    localparam ADDRW = (((SIZE) > 1) ? $clog2(SIZE) : 1);
    reg empty_r, alm_empty_r;
    reg full_r, alm_full_r;
    if (INCRW != 1 || DECRW != 1) begin
        reg [SIZEW-1:0] size_r;
        wire [SIZEW-1:0] size_n = size_r + SIZEW'(incr) - SIZEW'(decr);
        always @(posedge clk) begin
            if (reset) begin
                empty_r     <= 1;
                alm_empty_r <= 1;
                alm_full_r  <= 0;
                full_r      <= 0;
                size_r      <= '0;
            end else begin
                ;
                ;
                size_r      <= size_n;
                empty_r     <= (size_n == SIZEW'(0));
                alm_empty_r <= (size_n == SIZEW'(ALM_EMPTY));
                full_r      <= (size_n == SIZEW'(SIZE));
                alm_full_r  <= (size_n == SIZEW'(ALM_FULL));
            end
        end
        assign size = size_r;
    end else begin
        reg [ADDRW-1:0] used_r;
        wire [ADDRW-1:0] used_n;
        always @(posedge clk) begin
            if (reset) begin
                empty_r     <= 1;
                alm_empty_r <= 1;
                full_r      <= 0;
                alm_full_r  <= 0;
                used_r      <= '0;
            end else begin
                ;
                ;
                if (incr) begin
                    if (~decr) begin
                        empty_r <= 0;
                        if (used_r == ADDRW'(ALM_EMPTY))
                            alm_empty_r <= 0;
                        if (used_r == ADDRW'(SIZE-1))
                            full_r <= 1;
                        if (used_r == ADDRW'(ALM_FULL-1))
                            alm_full_r <= 1;
                    end
                end else if (decr) begin
                    if (used_r == ADDRW'(1))
                        empty_r <= 1;
                    if (used_r == ADDRW'(ALM_EMPTY+1))
                        alm_empty_r <= 1;
                    full_r <= 0;
                    if (used_r == ADDRW'(ALM_FULL))
                        alm_full_r <= 0;
                end
                used_r <= used_n;
            end
        end
        if (SIZE == 2) begin
            assign used_n = used_r ^ (incr ^ decr);
        end else begin
            assign used_n = $signed(used_r) + ADDRW'($signed(2'(incr) - 2'(decr)));
        end
        if (SIZE > 1) begin
            if (SIZEW > ADDRW) begin
                assign size = {full_r, used_r};
            end else begin
                assign size = used_r;
            end
        end else begin
            assign size = full_r;
        end
    end
    assign empty     = empty_r;
    assign alm_empty = alm_empty_r;
    assign alm_full  = alm_full_r;
    assign full      = full_r;
endmodule
