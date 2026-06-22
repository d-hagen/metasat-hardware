module VX_csr_data
import VX_gpu_pkg::*;
#(
    parameter  INSTANCE_ID = "",
    parameter CORE_ID = 0
) (
    input wire                          clk,
    input wire                          reset,
    input base_dcrs_t                   base_dcrs,
    VX_commit_csr_if.slave              commit_csr_if,
    input wire [44-1:0]     cycles,
    input wire [4-1:0]         active_warps,
    input wire [4-1:0][4-1:0] thread_masks,
    input wire                          read_enable,
    input wire [1-1:0]        read_uuid,
    input wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]          read_wid,
    input wire [12-1:0]  read_addr,
    output wire [32-1:0]             read_data_ro,
    output wire [32-1:0]             read_data_rw,
    input wire                          write_enable,
    input wire [1-1:0]        write_uuid,
    input wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]          write_wid,
    input wire [12-1:0]  write_addr,
    input wire [32-1:0]              write_data
);
    reg [32-1:0] mscratch;
    always @(posedge clk) begin
        if (reset) begin
            mscratch <= base_dcrs.startup_arg;
        end
        if (write_enable) begin
            case (write_addr)
                12'h180,
                12'h300,
                12'h744,
                12'h302,
                12'h303,
                12'h304,
                12'h305,
                12'h341,
                12'h3A0,
                12'h3B0: begin
                end
                12'h340: begin
                    mscratch <= write_data;
                end
                default: begin
                    ;
                end
            endcase
        end
    end
    reg [32-1:0] read_data_ro_r;
    reg [32-1:0] read_data_rw_r;
    reg read_addr_valid_r;
    always @(*) begin
        read_data_ro_r    = '0;
        read_data_rw_r    = '0;
        read_addr_valid_r = 1;
        case (read_addr)
            12'hF11  : read_data_ro_r = 32'(0);
            12'hF12    : read_data_ro_r = 32'(0);
            12'hF13     : read_data_ro_r = 32'(0);
            12'h301       : read_data_ro_r = 32'({2'($clog2(32/16)), 30'((0 <<  0)   
                | (0 <<  1)   
                | (0 <<  2)   
                | (0 <<  3)   
                | (0 <<  4)   
                | (0 << 5)   
                | (0 <<  6)   
                | (0 <<  7)   
                | (1 <<  8)   
                | (0 <<  9)   
                | (0 << 10)   
                | (0 << 11)   
                | (1 << 12)   
                | (0 << 13)   
                | (0 << 14)   
                | (0 << 15)   
                | (0 << 16)   
                | (0 << 17)   
                | (0 << 18)   
                | (0 << 19)   
                | (1 << 20)   
                | (0 << 21)   
                | (0 << 22)   
                | (1 << 23)   
                | (0 << 24)   
                | (0 << 25)  )});
            12'h340   : read_data_rw_r = mscratch;
            12'hCC1    : read_data_ro_r = 32'(read_wid);
            12'hCC2    : read_data_ro_r = 32'(CORE_ID);
            12'hCC4: read_data_ro_r = 32'(thread_masks[read_wid]);
            12'hCC3: read_data_ro_r = 32'(active_warps);
            12'hFC0: read_data_ro_r = 32'(4);
            12'hFC1  : read_data_ro_r = 32'(4);
            12'hFC2  : read_data_ro_r = 32'(8 * 1);
            12'hFC3: read_data_ro_r = 32'(2130706432);
        12'hB00 : read_data_ro_r = cycles[31:0]; 
        12'hB00+12'h80 : read_data_ro_r = 32'(cycles[$bits(cycles)-1:32]);
            12'hB01 : read_data_ro_r = 'x;
            12'hB81 : read_data_ro_r = 'x;
        12'hB02 : read_data_ro_r = commit_csr_if.instret[31:0]; 
        12'hB02+12'h80 : read_data_ro_r = 32'(commit_csr_if.instret[$bits(commit_csr_if.instret)-1:32]);
            12'h180,
            12'h300,
            12'h744,
            12'h302,
            12'h303,
            12'h304,
            12'h305,
            12'h341,
            12'h3A0,
            12'h3B0 : read_data_ro_r = 32'(0);
            default: begin
                read_addr_valid_r = 0;
                if ((read_addr >= 12'hB03   && read_addr < (12'hB03 + 32))
                 || (read_addr >= 12'hB83 && read_addr < (12'hB83 + 32))) begin
                    read_addr_valid_r = 1;
                end
            end
        endcase
    end
    assign read_data_ro = read_data_ro_r;
    assign read_data_rw = read_data_rw_r;
endmodule
