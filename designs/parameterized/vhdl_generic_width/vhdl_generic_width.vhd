-- A width-generic VHDL entity that slices its own port, which is how a
-- width-generic design is ordinarily written. Covers hif-backend#90.
--
-- The corpus had no VHDL design in parameterized/ at all, so nothing exercised
-- a generic reaching a width-dependent expression. The generic-to-parameter
-- mapping itself survives - `generic (WIDTH : integer := 6)` comes out as
-- `parameter width = 6` and the port widths follow it. What does not survive is
-- the slice: a(WIDTH-2 downto 0) is a slice of a parameter-width vector
-- anchored at bit 0, and hif2verilog emits it as bare `a`.
--
-- The operation is "clear the top bit". Written as a concatenation with the
-- slice on the right, so the bit the defect adds is not the bit Verilog's
-- assignment truncation removes - with the slice on the left of the concat, as
-- in a rotate, the extra bit and the truncated bit are the same one and the
-- wrong Verilog computes the right answer anyway.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_generic_width is
  generic (WIDTH : integer := 6);
  port (a : in  std_logic_vector(WIDTH-1 downto 0);
        y : out std_logic_vector(WIDTH-1 downto 0));
end vhdl_generic_width;

architecture rtl of vhdl_generic_width is
begin
  y <= '0' & a(WIDTH-2 downto 0);
end rtl;
