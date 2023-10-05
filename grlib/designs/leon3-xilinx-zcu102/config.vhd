-----------------------------------------------------------------------------
-- LEON3 Demonstration design test bench configuration
-- Copyright (C) 2009 Aeroflex Gaisler
------------------------------------------------------------------------------
library techmap;
use techmap.gencomp.all;
package config is
-- Technology and synthesis options
  constant CFG_FABTECH : integer := ultrascale;
  constant CFG_MEMTECH : integer := ultrascale;
  constant CFG_PADTECH : integer := ultrascale;
--  constant CFG_TRANSTECH : integer := TT_XGTP0;
  constant CFG_SCAN : integer := 0;
-- Clock generator
  constant CFG_CLKTECH : integer := ultrascale;
  constant CFG_CLKMUL : integer := (2);
  constant CFG_CLKDIV : integer := (6);
-- LEON processor core
  constant CFG_NCPU : integer := (4);
  constant CFG_NWIN : integer := (8);
  constant CFG_V8 : integer := 16#32# + 4*0;
  constant CFG_MAC : integer := 0;
  constant CFG_SPRW: integer := 0;
  constant CFG_SVT : integer := 1;
  constant CFG_RSTADDR : integer := 16#00000#;
  constant CFG_LDDEL : integer := (1);
  constant CFG_NWP : integer := (4);
  constant CFG_PWD : integer := 1*2;
  constant CFG_FPU : integer := (0) + 16*0 + 32*0;
  constant CFG_GRFPUSH : integer := 0;
  constant CFG_ICEN : integer := 1;
  constant CFG_ISETS : integer := 4;
  constant CFG_ISETSZ : integer := 4;
  constant CFG_ILINE : integer := 8;
  constant CFG_IREPL : integer := 0;
  constant CFG_ILOCK : integer := 0;
  constant CFG_ILRAMEN : integer := 0;
  constant CFG_ILRAMADDR: integer := 16#8E#;
  constant CFG_ILRAMSZ : integer := 1;
  constant CFG_DCEN : integer := 1;
  constant CFG_DSETS : integer := 4;
  constant CFG_DSETSZ : integer := 4;
  constant CFG_DLINE : integer := 8;
  constant CFG_DREPL : integer := 0;
  constant CFG_DLOCK : integer := 0;
  constant CFG_DSNOOP : integer := 1*2 + 4*1;
  constant CFG_DFIXED : integer := 16#0#;
  constant CFG_BWMASK : integer := 16#00F0#;
  constant CFG_CACHEBW : integer := 64;
  constant CFG_DLRAMEN : integer := 0;
  constant CFG_DLRAMADDR: integer := 16#8F#;
  constant CFG_DLRAMSZ : integer := 1;
  constant CFG_MMUEN : integer := 1;
  constant CFG_ITLBNUM : integer := 16;
  constant CFG_DTLBNUM : integer := 16;
  constant CFG_TLB_TYPE : integer := 0 + 1*2;
  constant CFG_TLB_REP : integer := 0;
  constant CFG_MMU_PAGE : integer := 0;
  constant CFG_DSU : integer := 1;
  constant CFG_ITBSZ : integer := 8; --4 + 64*1;
  constant CFG_ATBSZ : integer := 4;
  constant CFG_DISAS : integer := 0 + 0;
  constant CFG_PCLOW : integer := 2;
  constant CFG_NP_ASI : integer := 1;
  constant CFG_WRPSR : integer := 1;  
-- L3STAT settings
  constant CFG_STAT_ENABLE : integer := 1;
  constant CFG_STAT_CNT : integer := 4;
  constant CFG_STAT_NMAX : integer := 1;
-- AMBA settings
  constant CFG_DEFMST : integer := (0);
  constant CFG_RROBIN : integer := 1;
  constant CFG_SPLIT : integer := 0;
  constant CFG_FPNPEN : integer := 1;
  constant CFG_AHBIO : integer := 16#FFF#;
  constant CFG_APBADDR : integer := 16#800#;
-- DSU UART
  constant CFG_AHB_UART : integer := 1;
-- MEMORY
  constant CFG_AHBRAM_SIZE : integer := (3)*1024;
  constant CFG_MIG_ULTRASCALE : integer := 1;
-- L2 Cache
  constant CFG_L2_EN : integer := 0;
  constant CFG_L2_SIZE : integer := 128;
  constant CFG_L2_WAYS : integer := 4;
  constant CFG_L2_RAN : integer := 1;
  constant CFG_L2_LSZ : integer := 32;
  constant CFG_L2_MAP : integer := 16#00FF#;
-- AHB status register
  constant CFG_AHBSTAT : integer := 1;
  constant CFG_AHBSTATN : integer := (1);
-- AHB ROM
  constant CFG_AHBROMEN : integer := 0;
  constant CFG_AHBROPIP : integer := 0;
  constant CFG_AHBRODDR : integer := 16#000#;
  constant CFG_ROMADDR : integer := 16#000#;
  constant CFG_ROMMASK : integer := 16#E00# + 16#000#;
-- AHB RAM
  --set in leon3mp.vhd 
-- UART 1
  constant CFG_UART1_ENABLE : integer := 1;
  constant CFG_UART1_FIFO : integer := 32;
-- LEON3 interrupt controller
  constant CFG_IRQ3_ENABLE : integer := 1;
  constant CFG_IRQ3_NSEC : integer := 0;
-- GRLIB debugging
  constant CFG_DUART : integer := 1;
end;
