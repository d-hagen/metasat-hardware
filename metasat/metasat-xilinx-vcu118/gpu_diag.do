# gpu_diag.do — vsim TCL diagnostic for Vortex AFU memory bus activity.
#
# Used by setup_sim.mk's `run-sim-diag` target. Monitors Vortex's AXI master
# outputs in the testbench and prints a line per successful handshake. With
# the per-line HH:MM:SS prefix from setup_sim.mk's perl filter, the log shows
# exactly when each memory event happens.
#
# Hierarchy:
#   testbench (top) > soc:metasat > sys:metasatcore > gpusys generate
#     > vortex:Vortex_if (VHDL wrapper) > wrap:vortex_afu (SV core)
#
# What you'll see:
#   [GPU AW] addr=...   Vortex master initiated a write (one per write burst)
#   [GPU AR] addr=...   Vortex master initiated a read
#   [GPU W last]        End of a write burst (data fully drained)
#   [AFU cmd] type=...  Host wrote CMD_TYPE register inside the AFU (e.g. CMD_RUN)
#
# Volume note: during normal execution there will be hundreds to thousands of
# AR events (Vortex fetching its own code, then src array). Writes are sparser
# — for our test kernel, exactly 16 writes to the dest[] array after CMD_RUN.
# Counting writes after the AFU goes "running" tells us how far the kernel got.

# --- Write address channel: Vortex started a memory write ---
when -label gpu_axi_aw {
    sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.aw.valid == '1' and
    sim:/testbench/soc/sys/gpusys/vortex/mem_aximi.aw.ready == '1'
} {
    echo "[GPU AW] addr=" [examine -radix hex sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.aw.addr] " id=" [examine -radix hex sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.aw.id]
}

# --- Write last beat: write data fully sent ---
when -label gpu_axi_wlast {
    sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.w.valid == '1' and
    sim:/testbench/soc/sys/gpusys/vortex/mem_aximi.w.ready == '1' and
    sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.w.last == '1'
} {
    echo "[GPU W last]"
}

# --- Read address channel: Vortex requested a read ---
when -label gpu_axi_ar {
    sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.ar.valid == '1' and
    sim:/testbench/soc/sys/gpusys/vortex/mem_aximi.ar.ready == '1'
} {
    echo "[GPU AR] addr=" [examine -radix hex sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.ar.addr] " id=" [examine -radix hex sim:/testbench/soc/sys/gpusys/vortex/mem_aximo.ar.id]
}

# --- Run the simulation to completion ---
run -all
quit -f
