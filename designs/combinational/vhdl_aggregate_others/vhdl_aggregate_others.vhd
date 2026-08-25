-- A VHDL aggregate with named choices and an `others` clause, which nothing in
-- this corpus used. No open issue - this design is regression protection for
-- behaviour that currently works.
--
-- The aggregate is how VHDL writes a constant vector by bit position rather
-- than as a string of characters, and it is the ordinary way to spell a reset
-- value, a one-hot code or a bit mask. The named choices say which bits are
-- set and `others` fills the rest, so it states positions where a string
-- literal states a pattern - which makes it the form that breaks if positions
-- and pattern order are confused anywhere in the lowering.
--
-- Bits 5 and 3 are chosen so the pattern is asymmetric under reversal:
-- 00101000 reversed is 00010100. A pair like 5 and 2 would have been a
-- palindrome and a reversed constant would have been indistinguishable.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_aggregate_others is
  port (a : in  std_logic_vector(7 downto 0);
        y : out std_logic_vector(7 downto 0));
end vhdl_aggregate_others;

architecture rtl of vhdl_aggregate_others is
  constant TOGGLE : std_logic_vector(7 downto 0) := (5 => '1', 3 => '1', others => '0');
begin
  y <= a xor TOGGLE;
end rtl;
