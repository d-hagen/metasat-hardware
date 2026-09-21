interface VX_dcr_bus_if ();
    wire                          write_valid;
    wire [12-1:0] write_addr;
    wire [32-1:0] write_data;
    modport master (
        output write_valid,
        output write_addr,
        output write_data
    );
    modport slave (
        input  write_valid,
        input  write_addr,
        input  write_data
    );
endinterface
