-- The other spelling of a VHDL clock edge: `clk'event and clk = '1'`, the
-- pre-1993 form that predates rising_edge and is still everywhere in existing
-- code.
--
-- It is a separate design from vhdl_rising_edge because the two do not converge
-- until the backend. vhdl2hif builds an FCall to hif_vhdl_rising_edge for one
-- and, for this one, an `&&` expression over an FCall to hif_vhdl_event and an
-- `===` comparison against '1' - measured, by diffing the two HIF trees. So
-- hif2verilog has two structurally different conditions to recognise as the
-- same edge, and a fixture for one says nothing about the other.
--
-- The synchronous reset is inside the edge, which is the second thing this
-- design states: the reset must not become asynchronous when the edge
-- condition is rebuilt, and it must not disappear into the sensitivity list.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_event_edge is
  port (clk : in  std_logic;
        rst : in  std_logic;
        d   : in  std_logic_vector(3 downto 0);
        q   : out std_logic_vector(3 downto 0));
end vhdl_event_edge;

architecture rtl of vhdl_event_edge is
begin
  process (clk)
  begin
    if clk'event and clk = '1' then
      if rst = '1' then
        q <= "0000";
      else
        q <= d;
      end if;
    end if;
  end process;
end rtl;
