-- A VHDL component instantiation with named port association, which nothing in
-- this corpus reached: every hierarchical design here is Verilog, and the
-- Verilog frontend flattens child instances into the parent's body before the
-- backend ever sees them (regenerate small_hierarchy and only `top` comes out).
-- The VHDL path keeps them as instances, so this is the only route on which an
-- instance survives to the emitter at all.
--
-- The property is named association. VHDL binds a port map by name, so the
-- association order need not be the declaration order - u1 below writes q, r, p
-- against a component declared p, q, r. A lowering that reads the map
-- positionally, or that re-sorts it into declaration order and drops the names,
-- silently wires u1 the way u0 is wired. The cell is non-commutative and the
-- two instances receive a and b in opposite orders, so that mistake is a wrong
-- value on y1 and not a coincidence.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_hierarchy is
  port (a  : in  std_logic_vector(3 downto 0);
        b  : in  std_logic_vector(3 downto 0);
        y0 : out std_logic_vector(3 downto 0);
        y1 : out std_logic_vector(3 downto 0));
end vhdl_hierarchy;

architecture rtl of vhdl_hierarchy is
  component vhdl_hierarchy_cell
    port (p : in  std_logic_vector(3 downto 0);
          q : in  std_logic_vector(3 downto 0);
          r : out std_logic_vector(3 downto 0));
  end component;
begin
  u0 : vhdl_hierarchy_cell port map (p => a, q => b, r => y0);
  u1 : vhdl_hierarchy_cell port map (q => a, r => y1, p => b);
end rtl;
