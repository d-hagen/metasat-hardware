# GPU side (unchanged from previous broad capture).
log -r /testbench/soc/sys/gpusys/vortex/wrap/afu_ctrl/*
log -r /testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/*
log -r {/testbench/soc/sys/gpusys/vortex/wrap/vortex_axi/vortex/clusters[0]/cluster/sockets[0]/socket/cores[0]/core/*}
log -r /testbench/soc/sys/gpusys/vortex/wrap/m_axi_mem_*

# CPU side -- targeted, not full hierarchy, to keep WLF size bounded.
# noelvsys (NOEL-V subsystem) is at /testbench/soc/sys/cpusys.
# These are the three things that diagnose a host-side hang:
#
# 1. AHB master/slave signals at the bus level -- shows whether the CPU is
#    issuing memory transactions (htrans, haddr, hwrite, hwdata, hready,
#    hresp, hrdata). If these are alive the CPU is making forward progress;
#    if frozen, the CPU is wedged.
log -r /testbench/soc/sys/ahbmi
log -r /testbench/soc/sys/ahbmo
log -r /testbench/soc/sys/ahbsi
log -r /testbench/soc/sys/ahbso
#
# 2. APB bus -- the UART (slot 0 / slot 10 / slot 11 per the noelvsys trace)
#    lives here. UART activity tells us whether the CPU is trying to print.
log -r /testbench/soc/sys/apbi
log -r /testbench/soc/sys/apbo
#
# 3. NOEL-V CPU itself (top level only -- holdn and pc are the two key
#    signals). Recursive on the whole cpusys would be huge; the AHB/APB
#    signals above already tell us most of what we need, and we can dig
#    deeper into cpusys interactively in the wave viewer if needed.
log /testbench/soc/sys/cpusys/rstn
log /testbench/soc/sys/cpusys/clk

run 20000000 ns
quit -f
