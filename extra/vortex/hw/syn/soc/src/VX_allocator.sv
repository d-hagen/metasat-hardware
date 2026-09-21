module VX_allocator #(
    parameter SIZE  = 1,
    parameter ADDRW = (((SIZE) > 1) ? $clog2(SIZE) : 1)
) (
    input  wire             clk,
    input  wire             reset,
    input  wire             acquire_en,    
    output wire [ADDRW-1:0] acquire_addr,      
    input  wire             release_en,
    input  wire [ADDRW-1:0] release_addr,    
    output wire             empty,
    output wire             full    
);
    reg [SIZE-1:0] free_slots, free_slots_n;
    reg [ADDRW-1:0] acquire_addr_r;
    reg empty_r, full_r;    
    wire [ADDRW-1:0] free_index;
    wire free_valid;
    always @(*) begin
        free_slots_n = free_slots;
        if (release_en) begin
            free_slots_n[release_addr] = 1;                
        end
        if (acquire_en) begin
            free_slots_n[acquire_addr_r] = 0;
        end            
    end
    VX_lzc #(
        .N (SIZE),
        .REVERSE (1)
    ) free_slots_sel (
        .data_in   (free_slots_n),
        .data_out  (free_index),
        .valid_out (free_valid)
    );  
    always @(posedge clk) begin
        if (reset) begin
            acquire_addr_r <= ADDRW'(1'b0);
            free_slots     <= {SIZE{1'b1}};
            empty_r        <= 1'b1;
            full_r         <= 1'b0;            
        end else begin
            if (release_en) begin
                ;
            end
            if (acquire_en) begin                
                ;
            end            
            if (acquire_en || (release_en && full_r)) begin
                acquire_addr_r <= free_index;
            end
            free_slots <= free_slots_n;           
            empty_r    <= (& free_slots_n);
            full_r     <= ~free_valid;
        end        
    end
    assign acquire_addr = acquire_addr_r;
    assign empty        = empty_r;
    assign full         = full_r;
endmodule
