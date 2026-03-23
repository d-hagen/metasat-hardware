module VX_cluster import VX_gpu_pkg::*; #(
    parameter CLUSTER_ID = 0
) ( 
    input  wire                 clk,
    input  wire                 reset,
    VX_dcr_bus_if.slave         dcr_bus_if,
    VX_mem_bus_if.master        mem_bus_if,
    output wire                 sim_ebreak,
    output wire [32-1:0][32-1:0] sim_wb_value,
    output wire                 busy
);
    VX_mem_bus_if #(
        .DATA_SIZE (((0 || 0) ? 16 : 16)),
        .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    ) per_socket_mem_bus_if[(((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)]();
    wire [1-1:0] l2_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __l2_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (l2_reset)                          
    );
    VX_cache_wrap #(
        .INSTANCE_ID    ("l2cache"),
        .CACHE_SIZE     (1048576),
        .LINE_SIZE      (((0 || 0) ? 16 : 16)),
        .NUM_BANKS      ((((4) < ((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1))) ? (4) : ((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)))),
        .NUM_WAYS       (4),
        .WORD_SIZE      (L2_WORD_SIZE),
        .NUM_REQS       (L2_NUM_REQS),
        .CRSQ_SIZE      (2),
        .MSHR_SIZE      (16),
        .MRSQ_SIZE      (0),
        .MREQ_SIZE      (4),
        .TAG_WIDTH      (L1_MEM_ARB_TAG_WIDTH),
        .WRITE_ENABLE   (1),
        .UUID_WIDTH     (1),  
        .CORE_OUT_REG   (2),
        .MEM_OUT_REG    (2),
        .NC_ENABLE      (1),
        .PASSTHRU       (!0)
    ) l2cache (
        .clk            (clk),
        .reset          (l2_reset),
        .core_bus_if    (per_socket_mem_bus_if),
        .mem_bus_if     (mem_bus_if)
    );
    wire [(((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)-1:0] per_socket_sim_ebreak;
    wire [(((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)-1:0][32-1:0][32-1:0] per_socket_sim_wb_value;
    assign sim_ebreak = per_socket_sim_ebreak[0];
    assign sim_wb_value = per_socket_sim_wb_value[0];
    VX_dcr_bus_if socket_dcr_bus_tmp_if();
    assign socket_dcr_bus_tmp_if.write_valid = dcr_bus_if.write_valid && (dcr_bus_if.write_addr >= 12'h001 && dcr_bus_if.write_addr < 12'h004);
    assign socket_dcr_bus_tmp_if.write_addr  = dcr_bus_if.write_addr;
    assign socket_dcr_bus_tmp_if.write_data  = dcr_bus_if.write_data;
    wire [(((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)-1:0] per_socket_busy;
    logic [(1 + 12 + 32)-1:0] __socket_dcr_bus_if; 
    if (((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1) > 1)) begin 
        always @(posedge clk) begin 
            __socket_dcr_bus_if <= {socket_dcr_bus_tmp_if.write_valid, socket_dcr_bus_tmp_if.write_addr, socket_dcr_bus_tmp_if.write_data}; 
        end 
    end else begin 
        assign __socket_dcr_bus_if = {socket_dcr_bus_tmp_if.write_valid, socket_dcr_bus_tmp_if.write_addr, socket_dcr_bus_tmp_if.write_data}; 
    end 
    VX_dcr_bus_if socket_dcr_bus_if(); 
    assign {socket_dcr_bus_if.write_valid, socket_dcr_bus_if.write_addr, socket_dcr_bus_if.write_data} = __socket_dcr_bus_if;
    for (genvar i = 0; i < (((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1); ++i) begin
    wire [1-1:0] socket_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __socket_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (socket_reset)                          
    );
        VX_socket #(
            .SOCKET_ID ((CLUSTER_ID * (((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1)) + i)
        ) socket (
            .clk            (clk),
            .reset          (socket_reset),
            .dcr_bus_if     (socket_dcr_bus_if),
            .mem_bus_if     (per_socket_mem_bus_if[i]),
            .sim_ebreak     (per_socket_sim_ebreak[i]),
            .sim_wb_value   (per_socket_sim_wb_value[i]),
            .busy           (per_socket_busy[i])
        );
    end
    logic __busy; 
    if (((((1 / (((4) < (1)) ? (4) : (1))) != 0) ? (1 / (((4) < (1)) ? (4) : (1))) : 1) > 1)) begin 
        always @(posedge clk) begin 
            if (reset) begin 
                __busy <= 1'b0; 
            end else begin 
                __busy <= (| per_socket_busy); 
            end 
        end 
    end else begin 
        assign __busy = (| per_socket_busy); 
    end 
    assign busy = __busy;
endmodule
