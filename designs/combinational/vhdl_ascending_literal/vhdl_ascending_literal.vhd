-- A vector literal whose type has an ascending range. Covers the sizing half
-- of hif-backend#91.
--
-- vhdl_ascending_range covers the other half of that issue - which end index 0
-- names - and deliberately declares no ascending-typed constant, because the
-- two defects in one fixture would make neither attributable. This design is
-- the other side: it indexes nothing and only holds a constant.
--
-- hif2verilog sizes a bitvector literal as left-right+1, which is the width
-- only for a descending range. For (0 to 3) that is -2, and the constant is
-- emitted as `-2'b1100`: iverilog takes two bits, truncates to 2'b00, negates
-- to zero, warns twice and exits 0. The mask becomes all zeros, so the design
-- outputs nothing at all rather than the two bits it should keep.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_ascending_literal is
  port (a : in  std_logic_vector(3 downto 0);
        y : out std_logic_vector(3 downto 0));
end vhdl_ascending_literal;

architecture rtl of vhdl_ascending_literal is
  constant MASK : std_logic_vector(0 to 3) := "1100";
begin
  y <= a and MASK;
end rtl;
