# Broad waveform logging — captures the full GPU/AFU hierarchy so any signal
# in the design is available in the WLF for post-run inspection. The trade-
# off is WLF file size; on this design at 3-4 ms of sim a full-hierarchy
# capture is typically a few hundred MB, which is fine for one-off runs.

# AFU control + AXI-master fires (the level your existing $display already
# annotates in the transcript)
log -r /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/*
log -r /testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/*

# Full Vortex core hierarchy — scheduler, decode, issue, execute, commit,
# LSU, CSR, divergence stack, everything below /core
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/*}

# AXI handshakes at the testbench boundary (so you can see the GPU's reads
# and writes land on the AHB/AXI fabric)
log -r /testbench/soc/sys/gpusys/vortex/wrap/m_axi_mem_*

run 20000000 ns
quit -f
