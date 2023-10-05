-----------------------------------------------------------------------------
-- Demonstration design test bench configuration
-- Copyright (C) 2018 Cobham Gaisler AB
------------------------------------------------------------------------------
library techmap;
use techmap.gencomp.all;
package config is
-- Technology and synthesis options
  constant CFG_FABTECH : integer := ultrascale;
  constant CFG_MEMTECH : integer := ultrascale;
  constant CFG_PADTECH : integer := ultrascale;
-- Clock generator
  constant CFG_CLKTECH : integer := ultrascale;
  constant CFG_CLKMUL : integer := (2);
  constant CFG_CLKDIV : integer := (6);
  constant CFG_FREQ   : integer := 300000; -- input frequency in KHz

-- System Settings
  constant CFG_DISAS : integer := 0; -- Dissassembly 
  constant CFG_DUART : integer := 1; -- Debug UART
  constant CFG_AHB_UART : integer := 1; -- AHB UART
  constant CFG_UART1_EN : integer := 1; -- APB UART
  constant CFG_UART1_FIFO : integer := 32;
  
-- MIG
  constant CFG_MIG_EN : integer := 1; -- Use MIG
end;
