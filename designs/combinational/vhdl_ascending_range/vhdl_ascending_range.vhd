-- A VHDL ascending range, which nothing in this corpus used. Covers
-- hif-backend#91.
--
-- `std_logic_vector(0 to 3)` numbers the vector from the left: a(0) is the
-- leftmost element and a(3) the rightmost, the opposite of the `downto` form
-- every other VHDL design here uses. hif2verilog prints the port descending as
-- [3:0] but leaves index expressions index-preserving, so a(0) becomes a[0] -
-- the least significant bit of a descending vector, which is the other end.
--
-- Only the two ends are read. The design deliberately declares no constant of
-- an ascending type: that trips the second half of #91, where the literal's
-- size is computed as left-right+1 and comes out negative, and two defects in
-- one fixture would make the failure harder to attribute.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_ascending_range is
  port (a     : in  std_logic_vector(0 to 3);
        first : out std_logic;
        last  : out std_logic);
end vhdl_ascending_range;

architecture rtl of vhdl_ascending_range is
begin
  first <= a(0);
  last  <= a(3);
end rtl;
