interface VX_commit_csr_if ();
    wire [44-1:0] instret;
    modport master (
        output instret
    );
    modport slave (
        input instret
    );
endinterface
