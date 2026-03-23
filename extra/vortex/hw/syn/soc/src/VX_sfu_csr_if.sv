interface VX_sfu_csr_if  #(
    parameter NUM_LANES = (((4) < (4)) ? (4) : (4)),
    parameter PID_WIDTH = (((4 / NUM_LANES) > 1) ? $clog2(4 / NUM_LANES) : 1)
) ();
    wire                        read_enable;
    wire [1-1:0]      read_uuid;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]        read_wid;
    wire [NUM_LANES-1:0]        read_tmask;
    wire [PID_WIDTH-1:0]        read_pid;
    wire [12-1:0] read_addr;
    wire [NUM_LANES-1:0][31:0]  read_data;
    wire                        write_enable; 
    wire [1-1:0]      write_uuid;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]        write_wid;
    wire [NUM_LANES-1:0]        write_tmask;
    wire [PID_WIDTH-1:0]        write_pid;
    wire [12-1:0] write_addr;
    wire [NUM_LANES-1:0][31:0]  write_data;
    modport master (
        output read_enable,
        output read_uuid,
        output read_wid,
        output read_tmask,
        output read_pid,
        output read_addr,
        input  read_data,
        output write_enable,
        output write_uuid,
        output write_wid,
        output write_tmask,
        output write_pid,
        output write_addr,
        output write_data
    );
    modport slave (
        input  read_enable,
        input  read_uuid,
        input  read_wid,
        input  read_tmask,
        input  read_pid,
        input  read_addr,
        output read_data,
        input  write_enable,
        input  write_uuid,
        input  write_wid,
        input  write_tmask,
        input  write_pid,
        input  write_addr,
        input  write_data
    );
endinterface
