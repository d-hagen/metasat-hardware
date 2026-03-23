module VX_dcr_data import VX_gpu_pkg::*; (
    input wire              clk,
    input wire              reset,
    VX_dcr_bus_if.slave     dcr_bus_if,
    output base_dcrs_t      base_dcrs
);
    base_dcrs_t dcrs;
    always @(posedge clk) begin
       if (dcr_bus_if.write_valid) begin
            case (dcr_bus_if.write_addr)
            12'h001 : dcrs.startup_addr[31:0] <= dcr_bus_if.write_data;
            12'h003 : dcrs.mpm_class <= dcr_bus_if.write_data[7:0];
            default:;
            endcase
        end
    end
    assign base_dcrs = dcrs;
endmodule
