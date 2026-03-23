module VX_skid_buffer #(
    parameter DATAW    = 32,
    parameter PASSTHRU = 0,
    parameter OUT_REG  = 0
) ( 
    input  wire             clk,
    input  wire             reset,
    input  wire             valid_in,
    output wire             ready_in,        
    input  wire [DATAW-1:0] data_in,
    output wire [DATAW-1:0] data_out,
    input  wire             ready_out,
    output wire             valid_out
);
    if (PASSTHRU != 0) begin
        assign valid_out = valid_in;
        assign data_out  = data_in;
        assign ready_in  = ready_out;
    end else if (OUT_REG == 0) begin
        reg [1:0][DATAW-1:0] shift_reg;
        reg valid_out_r, ready_in_r, rd_ptr_r;
        wire push = valid_in && ready_in;
        wire pop = valid_out_r && ready_out;
        always @(posedge clk) begin
            if (reset) begin
                valid_out_r <= 0;
                ready_in_r  <= 1;
                rd_ptr_r    <= 1;
            end else begin
                if (push) begin
                    if (!pop) begin                            
                        ready_in_r  <= rd_ptr_r;
                        valid_out_r <= 1;
                    end
                end else if (pop) begin
                    ready_in_r  <= 1;
                    valid_out_r <= rd_ptr_r;
                end
                rd_ptr_r <= rd_ptr_r ^ (push ^ pop);
            end                   
        end
        always @(posedge clk) begin
            if (push) begin
                shift_reg[1] <= shift_reg[0];
                shift_reg[0] <= data_in;
            end
        end
        assign ready_in  = ready_in_r;
        assign valid_out = valid_out_r;
        assign data_out  = shift_reg[rd_ptr_r];
    end else if (OUT_REG == 1) begin
        reg [DATAW-1:0] data_out_r;
        reg [DATAW-1:0] buffer;
        reg             valid_out_r;
        reg             use_buffer;
        wire push = valid_in && ready_in;
        wire stall_out = valid_out_r && ~ready_out;
        always @(posedge clk) begin
            if (reset) begin
                valid_out_r <= 0; 
                use_buffer  <= 0;
            end else begin
                if (ready_out) begin
                    use_buffer <= 0;
                end else if (valid_in && valid_out) begin
                    use_buffer <= 1;
                end
                if (~stall_out) begin
                    valid_out_r <= valid_in || use_buffer;
                end
            end
        end
        always @(posedge clk) begin
            if (push) begin
                buffer <= data_in;
            end
            if (~stall_out) begin
                data_out_r <= use_buffer ? buffer : data_in;
            end
        end
        assign ready_in  = ~use_buffer;
        assign valid_out = valid_out_r;
        assign data_out  = data_out_r;
    end else begin
        reg [DATAW-1:0] data_out_r;
        reg has_data;
        always @(posedge clk) begin
            if (reset) begin
                has_data <= 0;
            end else begin
                if (~has_data) begin
                    has_data <= valid_in;
                end else if (ready_out) begin
                    has_data <= 0;
                end 
            end
            if (~has_data) begin
                data_out_r <= data_in;
            end
        end
        assign ready_in  = ~has_data;
        assign valid_out = has_data;
        assign data_out  = data_out_r;
    end
endmodule
