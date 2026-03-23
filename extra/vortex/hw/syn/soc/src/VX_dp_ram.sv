module VX_dp_ram #(
    parameter DATAW       = 1,
    parameter SIZE        = 1,
    parameter WRENW       = 1,
    parameter OUT_REG     = 0,
    parameter NO_RWCHECK  = 0,
    parameter LUTRAM      = 0,    
    parameter INIT_ENABLE = 0,
    parameter INIT_FILE   = "",
    parameter [DATAW-1:0] INIT_VALUE = 0,
    parameter ADDRW       = (((SIZE) > 1) ? $clog2(SIZE) : 1)
) ( 
    input wire               clk,
    input wire               read,
    input wire               write,
    input wire [WRENW-1:0]   wren,
    input wire [ADDRW-1:0]   waddr,        
    input wire [DATAW-1:0]   wdata,
    input wire [ADDRW-1:0]   raddr,
    output wire [DATAW-1:0]  rdata
);
    localparam WSELW = DATAW / WRENW;
    if (WRENW > 1) begin
        if (LUTRAM != 0) begin
            (* ram_style = "distributed" *) reg [DATAW-1:0] ram [SIZE-1:0];
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
            if (OUT_REG != 0) begin            
                reg [DATAW-1:0] rdata_r;
                always @(posedge clk) begin
                    if (write) begin
                        for (integer i = 0; i < WRENW; ++i) begin
                            if (wren[i])
                                ram[waddr][i * WSELW +: WSELW] <= wdata[i * WSELW +: WSELW];
                        end
                    end
                    if (read) begin
                        rdata_r <= ram[raddr];
                    end
                end
                assign rdata = rdata_r;
            end else begin
                always @(posedge clk) begin
                    if (write) begin
                        for (integer i = 0; i < WRENW; ++i) begin
                            if (wren[i])
                                ram[waddr][i * WSELW +: WSELW] <= wdata[i * WSELW +: WSELW];
                        end
                    end
                end
                assign rdata = ram[raddr];
            end
        end else begin
            if (OUT_REG != 0) begin
                reg [DATAW-1:0] ram [SIZE-1:0];
                reg [DATAW-1:0] rdata_r;
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
                always @(posedge clk) begin
                    if (write) begin
                        for (integer i = 0; i < WRENW; ++i) begin
                            if (wren[i])
                                ram[waddr][i * WSELW +: WSELW] <= wdata[i * WSELW +: WSELW];
                        end
                    end
                    if (read) begin
                        rdata_r <= ram[raddr];
                    end
                end
                assign rdata = rdata_r;
            end else begin
                if (NO_RWCHECK != 0) begin
                    (* rw_addr_collision = "no" *) reg [DATAW-1:0] ram [SIZE-1:0];
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
                    always @(posedge clk) begin
                        if (write) begin
                            for (integer i = 0; i < WRENW; ++i) begin
                                if (wren[i])
                                    ram[waddr][i * WSELW +: WSELW] <= wdata[i * WSELW +: WSELW];
                            end
                        end
                    end
                    assign rdata = ram[raddr];
                end else begin
                    reg [DATAW-1:0] ram [SIZE-1:0];
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
                    always @(posedge clk) begin
                        if (write) begin
                            for (integer i = 0; i < WRENW; ++i) begin
                                if (wren[i])
                                    ram[waddr][i * WSELW +: WSELW] <= wdata[i * WSELW +: WSELW];
                            end
                        end
                    end
                    assign rdata = ram[raddr];
                end
            end
        end
    end else begin
        if (LUTRAM != 0) begin
            (* ram_style = "distributed" *) reg [DATAW-1:0] ram [SIZE-1:0];
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
            if (OUT_REG != 0) begin            
                reg [DATAW-1:0] rdata_r;
                always @(posedge clk) begin
                    if (write) begin
                        ram[waddr] <= wdata;
                    end
                    if (read) begin
                        rdata_r <= ram[raddr];
                    end
                end
                assign rdata = rdata_r;
            end else begin
                always @(posedge clk) begin
                    if (write) begin
                        ram[waddr] <= wdata;
                    end
                end
                assign rdata = ram[raddr];
            end
        end else begin
            if (OUT_REG != 0) begin
                reg [DATAW-1:0] ram [SIZE-1:0];
                reg [DATAW-1:0] rdata_r;
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
                always @(posedge clk) begin
                    if (write) begin
                        ram[waddr] <= wdata;
                    end
                    if (read) begin
                        rdata_r <= ram[raddr];
                    end
                end
                assign rdata = rdata_r;
            end else begin
                if (NO_RWCHECK != 0) begin
                    (* rw_addr_collision = "no" *) reg [DATAW-1:0] ram [SIZE-1:0];
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
                    always @(posedge clk) begin
                        if (write) begin
                            ram[waddr] <= wdata;
                        end
                    end
                    assign rdata = ram[raddr];
                end else begin
                    reg [DATAW-1:0] ram [SIZE-1:0];
    if (INIT_ENABLE != 0) begin                    
        if (INIT_FILE != "") begin                 
            initial $readmemh(INIT_FILE, ram);     
        end else begin                             
            initial                                
                for (integer i = 0; i < SIZE; ++i) 
                    ram[i] = INIT_VALUE;           
        end                                        
    end
                    always @(posedge clk) begin
                        if (write) begin
                            ram[waddr] <= wdata;
                        end
                    end
                    assign rdata = ram[raddr];
                end
            end
        end
    end    
endmodule
