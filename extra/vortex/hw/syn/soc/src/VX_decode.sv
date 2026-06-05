module VX_decode import VX_gpu_pkg::*, VX_trace_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_fetch_if.slave       fetch_if,
    VX_decode_if.master     decode_if,
    VX_decode_sched_if.master decode_sched_if
);
    localparam DATAW = 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + 4 + (32-1) + $clog2((3 + 1)) + 4 + $bits(op_args_t) + 1 + ($clog2((2 * 32)) * 4);
    reg [$clog2((3 + 1))-1:0] ex_type;
    reg [4-1:0] op_type;
    op_args_t op_args;
    reg [$clog2((2 * 32))-1:0] rd_r, rs1_r, rs2_r, rs3_r;
    reg use_rd, use_rs1, use_rs2, use_rs3;
    reg is_wstall;
    wire [31:0] instr = fetch_if.data.instr;
    wire [6:0] opcode = instr[6:0];
    wire [1:0] func2  = instr[26:25];
    wire [2:0] func3  = instr[14:12];
    wire [4:0] func5  = instr[31:27];
    wire [6:0] func7  = instr[31:25];
    wire [11:0] u_12  = instr[31:20];
    wire [4:0] rd  = instr[11:7];
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20];
    wire [4:0] rs3 = instr[31:27];
    wire is_itype_sh = func3[0] && ~func3[1];
    wire is_fpu_csr = (u_12 <= 12'h003);
    wire [19:0] ui_imm  = instr[31:12];
    wire [11:0] i_imm   = is_itype_sh ? {7'b0, instr[24:20]} : u_12;
    wire [11:0] s_imm   = {func7, rd};
    wire [12:0] b_imm   = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [20:0] jal_imm = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    reg [4-1:0] r_type;
    always @(*) begin
        case (func3)
            3'h0: r_type = (opcode[5] && func7[5]) ? 4'b0111 : 4'b0000;
            3'h1: r_type = 4'b1111;
            3'h2: r_type = 4'b0101;
            3'h3: r_type = 4'b0100;
            3'h4: r_type = 4'b1110;
            3'h5: r_type = func7[5] ? 4'b1001 : 4'b1000;
            3'h6: r_type = 4'b1101;
            3'h7: r_type = 4'b1100;
        endcase
    end
    reg [4-1:0] b_type;
    always @(*) begin
        case (func3)
            3'h0: b_type = 4'b0000;
            3'h1: b_type = 4'b0010;
            3'h4: b_type = 4'b0101;
            3'h5: b_type = 4'b0111;
            3'h6: b_type = 4'b0100;
            3'h7: b_type = 4'b0110;
            default: b_type = 'x;
        endcase
    end
    reg [4-1:0] s_type;
    always @(*) begin
        case (u_12)
            12'h000: s_type = 4'(4'b1010);
            12'h001: s_type = 4'(4'b1011);
            12'h002: s_type = 4'(4'b1100);
            12'h102: s_type = 4'(4'b1101);
            12'h302: s_type = 4'(4'b1110);
            default: s_type = 'x;
        endcase
    end
    reg [3-1:0] m_type;
    always @(*) begin
        case (func3)
            3'h0: m_type = 3'b000;
            3'h1: m_type = 3'b010;
            3'h2: m_type = 3'b011;
            3'h3: m_type = 3'b001;
            3'h4: m_type = 3'b100;
            3'h5: m_type = 3'b101;
            3'h6: m_type = 3'b110;
            3'h7: m_type = 3'b111;
        endcase
    end
    ;
    ;
    ;
    ;
    ;
    always @(*) begin
        ex_type   = '0;
        op_type   = 'x;
        op_args   = 'x;
        rd_r      = '0;
        rs1_r     = '0;
        rs2_r     = '0;
        rs3_r     = '0;
        use_rd    = 0;
        use_rs1   = 0;
        use_rs2   = 0;
        use_rs3   = 0;
        is_wstall = 0;
        case (opcode)
            7'b0010011: begin
                ex_type = 0;
                op_type = 4'(r_type);
                op_args.alu.xtype = 0;
                op_args.alu.is_w = 0;
                op_args.alu.use_PC = 0;
                op_args.alu.use_imm = 1;
                op_args.alu.imm = {{(32-$bits(i_imm)+1){i_imm[$bits(i_imm)-1]}}, i_imm[$bits(i_imm)-2:0]};
                use_rd = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
            end
            7'b0110011: begin
                ex_type = 0;
                op_args.alu.is_w = 0;
                op_args.alu.use_PC = 0;
                op_args.alu.use_imm = 0;
                use_rd = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b0, rs2}; 
        use_rs2 = 1;
                case (func7)
                    7'b0000001: begin
                        op_type = 4'(m_type);
                        op_args.alu.xtype = 2;
                    end
                    7'b0000111: begin
                        op_type = func3[1] ? 4'(4'b1011) : 4'(4'b1010);
                        op_args.alu.xtype = 0;
                    end
                    default: begin
                        op_type = 4'(r_type);
                        op_args.alu.xtype = 0;
                    end
                endcase
            end
            7'b0110111: begin
                ex_type = 0;
                op_type = 4'(4'b0010);
                op_args.alu.xtype = 0;
                op_args.alu.is_w = 0;
                op_args.alu.use_PC = 0;
                op_args.alu.use_imm = 1;
                op_args.alu.imm = {{32-31{ui_imm[19]}}, ui_imm[18:0], 12'(0)};
                use_rd  = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
            end
            7'b0010111: begin
                ex_type = 0;
                op_type = 4'(4'b0011);
                op_args.alu.xtype = 0;
                op_args.alu.is_w = 0;
                op_args.alu.use_PC = 1;
                op_args.alu.use_imm = 1;
                op_args.alu.imm = {{32-31{ui_imm[19]}}, ui_imm[18:0], 12'(0)};
                use_rd = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
            end
            7'b1101111: begin
                ex_type = 0;
                op_type = 4'(4'b1000);
                op_args.alu.xtype = 1;
                op_args.alu.is_w = 0;
                op_args.alu.use_PC = 1;
                op_args.alu.use_imm = 1;
                op_args.alu.imm = {{(32-$bits(jal_imm)+1){jal_imm[$bits(jal_imm)-1]}}, jal_imm[$bits(jal_imm)-2:0]};
                use_rd  = 1;
                is_wstall = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
            end
            7'b1100111: begin
                ex_type = 0;
                op_type = 4'(4'b1001);
                op_args.alu.xtype = 1;
                op_args.alu.is_w = 0;
                op_args.alu.use_PC = 0;
                op_args.alu.use_imm = 1;
                op_args.alu.imm = {{(32-$bits(u_12)+1){u_12[$bits(u_12)-1]}}, u_12[$bits(u_12)-2:0]};
                use_rd  = 1;
                is_wstall = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
            end
            7'b1100011: begin
                ex_type = 0;
                op_type = 4'(b_type);
                op_args.alu.xtype = 1;
                op_args.alu.is_w = 0;
                op_args.alu.use_PC = 1;
                op_args.alu.use_imm = 1;
                op_args.alu.imm = {{(32-$bits(b_imm)+1){b_imm[$bits(b_imm)-1]}}, b_imm[$bits(b_imm)-2:0]};
                is_wstall = 1;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b0, rs2}; 
        use_rs2 = 1;
            end
            7'b0001111: begin
                ex_type = 1;
                op_type = 4'b1111;
                op_args.lsu.is_store = 0;
                op_args.lsu.is_float = 0;
                op_args.lsu.offset = 0;
            end
            7'b1110011 : begin
                if (func3[1:0] != 0) begin
                    ex_type = 2;
                    op_type = 4'((4'h6 + 4'(func3[1:0]) - 4'h1));
                    op_args.csr.addr = u_12;
                    op_args.csr.use_imm = func3[2];
                    use_rd  = 1;
                    is_wstall = is_fpu_csr;  
        rd_r = {1'b0, rd}; 
        use_rd = 1;
                    if (func3[2]) begin
                        op_args.csr.imm = rs1;
                    end else begin
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
                    end
                end else begin
                    ex_type = 0;
                    op_type = 4'(s_type);
                    op_args.alu.xtype = 1;
                    op_args.alu.is_w = 0;
                    op_args.alu.use_imm = 1;
                    op_args.alu.use_PC  = 1;
                    op_args.alu.imm = 32'd4;
                    use_rd  = 1;
                    is_wstall = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
                end
            end
            7'b0000111,
            7'b0000011: begin
                ex_type = 1;
                op_type = 4'({1'b0, func3});
                op_args.lsu.is_store = 0;
                op_args.lsu.is_float = opcode[2];
                op_args.lsu.offset = u_12;
                use_rd  = 1;
                if (opcode[2]) begin
        rd_r = {1'b1, rd}; 
        use_rd = 1;
                end else
        rd_r = {1'b0, rd}; 
        use_rd = 1;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
            end
            7'b0100111,
            7'b0100011: begin
                ex_type = 1;
                op_type = 4'({1'b1, func3});
                op_args.lsu.is_store = 1;
                op_args.lsu.is_float = opcode[2];
                op_args.lsu.offset = s_imm;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
                if (opcode[2]) begin
        rs2_r = {1'b1, rs2}; 
        use_rs2 = 1;
                end else
        rs2_r = {1'b0, rs2}; 
        use_rs2 = 1;
            end
            7'b1000011,
            7'b1000111,
            7'b1001011,
            7'b1001111: begin
                ex_type = (2 + 1);
                op_type = 4'({2'b11, opcode[3:2]});
                op_args.fpu.frm = func3;
                op_args.fpu.fmt[0] = func2[0];  
                use_rd  = 1;
        rd_r = {1'b1, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b1, rs2}; 
        use_rs2 = 1;
        rs3_r = {1'b1, rs3}; 
        use_rs3 = 1;
            end
            7'b1010011: begin
                ex_type = (2 + 1);
                op_args.fpu.frm = func3;
                op_args.fpu.fmt[0] = func2[0];  
                op_args.fpu.fmt[1] = rs2[1];    
                use_rd  = 1;
                case (func5)
                    5'b00000,  
                    5'b00001,  
                    5'b00010,  
                    5'b00011: begin  
                        op_type = 4'(func5[1:0]);
        rd_r = {1'b1, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b1, rs2}; 
        use_rs2 = 1;
                    end
                    5'b00100: begin
                        op_type = 4'(4'b0111);
                        op_args.fpu.frm = 3'(func3[1:0]);
        rd_r = {1'b1, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b1, rs2}; 
        use_rs2 = 1;
                    end
                    5'b00101: begin
                        op_type = 4'(4'b0111);
                        op_args.fpu.frm = 3'(func3[0] ? 7 : 6);
        rd_r = {1'b1, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b1, rs2}; 
        use_rs2 = 1;
                    end
                    5'b01011: begin
                        op_type = 4'(4'b0100);
        rd_r = {1'b1, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
                    end
                    5'b10100: begin
                        op_type = 4'(4'b0101);
        rd_r = {1'b0, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b1, rs2}; 
        use_rs2 = 1;
                    end
                    5'b11000: begin
                        op_type = (rs2[0]) ? 4'(4'b1001) : 4'(4'b1000);
        rd_r = {1'b0, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
                    end
                    5'b11010: begin
                        op_type = (rs2[0]) ? 4'(4'b1011) : 4'(4'b1010);
        rd_r = {1'b1, rd}; 
        use_rd = 1;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
                    end
                    5'b11100: begin
                        if (func3[0]) begin
                            op_type = 4'(4'b0111);
                            op_args.fpu.frm = 3'(3);
                        end else begin
                            op_type = 4'(4'b0111);
                            op_args.fpu.frm = 3'(4);
                        end
        rd_r = {1'b0, rd}; 
        use_rd = 1;
        rs1_r = {1'b1, rs1}; 
        use_rs1 = 1;
                    end
                    5'b11110: begin
                        op_type = 4'(4'b0111);
                        op_args.fpu.frm = 3'(5);
        rd_r = {1'b1, rd}; 
        use_rd = 1;
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
                    end
                default:;
                endcase
            end
            7'b0001011: begin
                case (func7)
                    7'h00: begin
                        ex_type = 2;
                        is_wstall = 1;
                        case (func3)
                            3'h0: begin  
                                op_type = 4'(4'h0);
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
                            end
                            3'h1: begin  
                                op_type = 4'(4'h1);
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b0, rs2}; 
        use_rs2 = 1;
                            end
                            3'h2: begin  
                                op_type = 4'(4'h2);
                                use_rd    = 1;
                                op_args.wctl.is_neg = rs2[0];
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
        rd_r = {1'b0, rd}; 
        use_rd = 1;
                            end
                            3'h3: begin  
                                op_type = 4'(4'h3);
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
                            end
                            3'h4: begin  
                                op_type = 4'(4'h4);
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b0, rs2}; 
        use_rs2 = 1;
                            end
                            3'h5: begin  
                                op_type = 4'(4'h5);
                                op_args.wctl.is_neg = rd[0];
        rs1_r = {1'b0, rs1}; 
        use_rs1 = 1;
        rs2_r = {1'b0, rs2}; 
        use_rs2 = 1;
                            end
                            default:;
                        endcase
                    end
                    default:;
                endcase
            end
            default:;
        endcase
    end
    wire wb = use_rd && (rd_r != 0);
    VX_elastic_buffer #(
        .DATAW (DATAW),
        .SIZE  (0)
    ) req_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (fetch_if.valid),
        .ready_in  (fetch_if.ready),
        .data_in   ({fetch_if.data.uuid, fetch_if.data.wid, fetch_if.data.tmask, fetch_if.data.PC, ex_type, op_type, op_args, wb, rd_r, rs1_r, rs2_r, rs3_r}),
        .data_out  ({decode_if.data.uuid, decode_if.data.wid, decode_if.data.tmask, decode_if.data.PC, decode_if.data.ex_type, decode_if.data.op_type, decode_if.data.op_args, decode_if.data.wb, decode_if.data.rd, decode_if.data.rs1, decode_if.data.rs2, decode_if.data.rs3}),
        .valid_out (decode_if.valid),
        .ready_out (decode_if.ready)
    );
    wire fetch_fire = fetch_if.valid && fetch_if.ready;
    assign decode_sched_if.valid    = fetch_fire;
    assign decode_sched_if.wid      = fetch_if.data.wid;
    assign decode_sched_if.is_wstall = is_wstall;
endmodule
