-- The leaf of vhdl_hierarchy. Deliberately non-commutative: `p and not q` is
-- not `q and not p`, so an instance whose operands reach it in the wrong order
-- produces a different value rather than the same one.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_hierarchy_cell is
  port (p : in  std_logic_vector(3 downto 0);
        q : in  std_logic_vector(3 downto 0);
        r : out std_logic_vector(3 downto 0));
end vhdl_hierarchy_cell;

architecture rtl of vhdl_hierarchy_cell is
begin
  r <= p and not q;
end rtl;
