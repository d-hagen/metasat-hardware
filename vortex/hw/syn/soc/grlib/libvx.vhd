library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;
use grlib.amba.all;

package libvx is

  component Vortex_if is
    port (
      clk      : in std_ulogic;
      reset    : in std_ulogic;
      -- Control AXI-Lite
      ctrl_aximi  : out axi_somi_type;
      ctrl_aximo  : in  axi_mosi_type;
      -- Memory AXI4
      mem_aximi   : in axi_somi_type;
      mem_aximo   : out axi4_mosi_type;
      -- Interrupt
      interrupt   : out std_logic
    );
  end component;

  component Vortex_afu is
  generic (
    C_S_AXI_CTRL_ADDR_WIDTH     : integer;
    C_S_AXI_CTRL_DATA_WIDTH     : integer;
    C_M_AXI_MEM_ID_WIDTH        : integer;
    C_M_AXI_MEM_ADDR_WIDTH      : integer;
    C_M_AXI_MEM_DATA_WIDTH      : integer
  );
  port (
    clk                         : in std_logic;
    reset                       : in std_logic;
    -- Memory AXI4
    m_axi_mem_awvalid           : out std_logic;
    m_axi_mem_awready           : in std_logic;
    m_axi_mem_awaddr            : out std_logic_vector(C_M_AXI_MEM_ADDR_WIDTH-1 downto 0);
    m_axi_mem_awid              : out std_logic_vector(C_M_AXI_MEM_ID_WIDTH-1 downto 0); 
    m_axi_mem_awlen             : out std_logic_vector(7 downto 0); 
    m_axi_mem_wvalid            : out std_logic; 
    m_axi_mem_wready            : in std_logic; 
    m_axi_mem_wdata             : out std_logic_vector(C_M_AXI_MEM_DATA_WIDTH-1 downto 0);
    m_axi_mem_wstrb             : out std_logic_vector(C_M_AXI_MEM_DATA_WIDTH/8-1 downto 0);
    m_axi_mem_wlast             : out std_logic;
    m_axi_mem_arvalid		: out std_logic;
    m_axi_mem_arready		: in std_logic;
    m_axi_mem_araddr		: out std_logic_vector(C_M_AXI_MEM_ADDR_WIDTH-1 downto 0);
    m_axi_mem_arid		: out std_logic_vector(C_M_AXI_MEM_ID_WIDTH-1 downto 0);
    m_axi_mem_arlen		: out std_logic_vector(7 downto 0);
    m_axi_mem_rvalid		: in std_logic;
    m_axi_mem_rready		: out std_logic;
    m_axi_mem_rdata		: in std_logic_vector(C_M_AXI_MEM_DATA_WIDTH-1 downto 0);
    m_axi_mem_rlast		: in std_logic;
    m_axi_mem_rid		: in std_logic_vector(C_M_AXI_MEM_ID_WIDTH-1 downto 0);
    m_axi_mem_rresp		: in std_logic_vector(1 downto 0);
    m_axi_mem_bvalid		: in std_logic;
    m_axi_mem_bready		: out std_logic;
    m_axi_mem_bresp		: in std_logic_vector(1 downto 0);
    m_axi_mem_bid		: in std_logic_vector(C_M_AXI_MEM_ID_WIDTH-1 downto 0);
    -- Control AXI-Lite
    s_axi_ctrl_awvalid		: in std_logic;
    s_axi_ctrl_awready		: out std_logic;
    s_axi_ctrl_awaddr		: in std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    s_axi_ctrl_wvalid		: in std_logic;
    s_axi_ctrl_wready		: out std_logic;
    s_axi_ctrl_wdata		: in std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    s_axi_ctrl_wstrb		: in std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH/8-1 downto 0);
    s_axi_ctrl_arvalid		: in std_logic;
    s_axi_ctrl_arready		: out std_logic;
    s_axi_ctrl_araddr		: in std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    s_axi_ctrl_rvalid		: out std_logic;
    s_axi_ctrl_rready		: in std_logic;
    s_axi_ctrl_rdata		: out std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    s_axi_ctrl_rresp		: out std_logic_vector(1 downto 0);
    s_axi_ctrl_bvalid		: out std_logic;
    s_axi_ctrl_bready		: in std_logic;
    s_axi_ctrl_bresp		: out std_logic_vector(1 downto 0);
    -- Interrupt
    interrupt                   : out std_logic
  );
  end component;
end package;
