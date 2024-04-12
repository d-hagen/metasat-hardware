library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;
use grlib.amba.all;

library gaisler;
use gaisler.axi.all;

library vortex;
use vortex.libvx.all;

entity Vortex_if is
  port (
    clk         : in std_ulogic;
    reset       : in std_ulogic;
    -- Control AXI-Lite
    ctrl_aximi  : out axi_somi_type;
    ctrl_aximo  : in  axi_mosi_type;
    -- Memory AXI4
    mem_aximi   : in axi_somi_type;
    mem_aximo   : out axi4_mosi_type;
    -- Interrupt
    interrupt   : out std_logic
  );
end;

architecture rtl of Vortex_if is
begin

  wrap : Vortex_afu
  generic map (
    C_S_AXI_CTRL_ADDR_WIDTH => 32,
    C_S_AXI_CTRL_DATA_WIDTH => AXIDW,
    C_M_AXI_MEM_ID_WIDTH    => AXI_ID_WIDTH,
    C_M_AXI_MEM_ADDR_WIDTH  => 32,
    C_M_AXI_MEM_DATA_WIDTH  => AXIDW)
  port map (
    clk                         => clk,
    reset                       => reset,
    -- Memory AXI4
    m_axi_mem_awvalid           => mem_aximo.aw.valid,
    m_axi_mem_awready           => mem_aximi.aw.ready,
    m_axi_mem_awaddr            => mem_aximo.aw.addr,
    m_axi_mem_awid              => mem_aximo.aw.id,
    m_axi_mem_awlen             => mem_aximo.aw.len,
    m_axi_mem_wvalid            => mem_aximo.w.valid,
    m_axi_mem_wready            => mem_aximi.w.ready,
    m_axi_mem_wdata             => mem_aximo.w.data,
    m_axi_mem_wstrb             => mem_aximo.w.strb,
    m_axi_mem_wlast             => mem_aximo.w.last,
    m_axi_mem_arvalid		=> mem_aximo.ar.valid,
    m_axi_mem_arready		=> mem_aximi.ar.ready,
    m_axi_mem_araddr		=> mem_aximo.ar.addr,
    m_axi_mem_arid		=> mem_aximo.ar.id,
    m_axi_mem_arlen		=> mem_aximo.ar.len,
    m_axi_mem_rvalid		=> mem_aximi.r.valid,
    m_axi_mem_rready		=> mem_aximo.r.ready,
    m_axi_mem_rdata		=> mem_aximi.r.data,
    m_axi_mem_rlast		=> mem_aximi.r.last,
    m_axi_mem_rid		=> mem_aximi.r.id,
    m_axi_mem_rresp		=> mem_aximi.r.resp,
    m_axi_mem_bvalid		=> mem_aximi.b.valid,
    m_axi_mem_bready		=> mem_aximo.b.ready,
    m_axi_mem_bresp		=> mem_aximi.b.resp,
    m_axi_mem_bid		=> mem_aximi.b.id,
    -- Control AXI-Lite
    s_axi_ctrl_awvalid		=> ctrl_aximo.aw.valid,
    s_axi_ctrl_awready		=> ctrl_aximi.aw.ready,
    s_axi_ctrl_awaddr		=> ctrl_aximo.aw.addr,
    s_axi_ctrl_wvalid		=> ctrl_aximo.w.valid,
    s_axi_ctrl_wready		=> ctrl_aximi.w.ready,
    s_axi_ctrl_wdata		=> ctrl_aximo.w.data,
    s_axi_ctrl_wstrb		=> ctrl_aximo.w.strb,
    s_axi_ctrl_arvalid		=> ctrl_aximo.ar.valid,
    s_axi_ctrl_arready		=> ctrl_aximi.ar.ready,
    s_axi_ctrl_araddr		=> ctrl_aximo.ar.addr,
    s_axi_ctrl_rvalid		=> ctrl_aximi.r.valid,
    s_axi_ctrl_rready		=> ctrl_aximo.r.ready,
    s_axi_ctrl_rdata		=> ctrl_aximi.r.data,
    s_axi_ctrl_rresp		=> ctrl_aximi.r.resp,
    s_axi_ctrl_bvalid		=> ctrl_aximi.b.valid,
    s_axi_ctrl_bready		=> ctrl_aximo.b.ready,
    s_axi_ctrl_bresp		=> ctrl_aximi.b.resp,
    -- Interrupt
    interrupt                   => interrupt
  );

end rtl;
