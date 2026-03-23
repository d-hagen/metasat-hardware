module VX_index_buffer #(
    parameter DATAW  = 1,
    parameter SIZE   = 1,
    parameter LUTRAM = 1,
    parameter ADDRW  = (((SIZE) > 1) ? $clog2(SIZE) : 1)
) (
    input  wire             clk,
    input  wire             reset,
    output wire [ADDRW-1:0] write_addr,
    input  wire [DATAW-1:0] write_data,            
    input  wire             acquire_en,
    input  wire [ADDRW-1:0] read_addr,
    output wire [DATAW-1:0] read_data,
    input  wire             release_en,
    output wire             empty,
    output wire             full    
);
    VX_allocator #(
        .SIZE (SIZE)
    ) allocator (
        .clk        (clk),
        .reset      (reset),
        .acquire_en (acquire_en),
        .acquire_addr (write_addr),
        .release_en (release_en),
        .release_addr (read_addr),    
        .empty      (empty),
        .full       (full)   
    );
    VX_dp_ram #(
        .DATAW  (DATAW),
        .SIZE   (SIZE),
        .LUTRAM (LUTRAM)
    ) data_table (
        .clk   (clk),
        .read  (1'b1),
        .write (acquire_en),
        . wren (),
        .waddr (write_addr),
        .wdata (write_data),
        .raddr (read_addr),
        .rdata (read_data)
    );
endmodule
