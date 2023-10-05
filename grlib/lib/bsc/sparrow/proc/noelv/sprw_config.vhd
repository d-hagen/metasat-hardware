library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.noelv_cfg.all;

package sprw_config is
    constant SPRW_VLEN : integer := NV_XLEN; -- Vector length
end package;
