interface VX_fpu_to_csr_if import VX_fpu_pkg::*; ();
    wire                    write_enable;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    write_wid;
    fflags_t                write_fflags;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    read_wid;
    wire [3-1:0] read_frm;
    modport master (
        output write_enable,
        output write_wid,
        output write_fflags,
        output read_wid,
        input  read_frm
    );
    modport slave (
        input  write_enable,
        input  write_wid,
        input  write_fflags,
        input  read_wid,
        output read_frm
    );
endinterface
