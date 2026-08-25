-- A VHDL case statement inside a combinational process, with `when others`.
--
-- Verilog-sourced case statements are already covered several ways here, but
-- none of them arrives through vhdl2hif. VHDL requires the choices to be
-- exhaustive, so a design like this always has an `others` alternative, and
-- the question is what hif2verilog does with it: the natural Verilog form is
-- `default`, and an `others` emitted as an ordinary label - or dropped, on the
-- grounds that the earlier alternatives already cover every value of a
-- two-bit selector - changes what happens on the last one.
--
-- Every alternative computes something different from every other, so a
-- selector routed to the wrong branch is a wrong value rather than a
-- coincidence.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_case is
  port (sel : in  std_logic_vector(1 downto 0);
        a   : in  std_logic_vector(3 downto 0);
        b   : in  std_logic_vector(3 downto 0);
        y   : out std_logic_vector(3 downto 0));
end vhdl_case;

architecture rtl of vhdl_case is
begin
  process (sel, a, b)
  begin
    case sel is
      when "00"   => y <= a;
      when "01"   => y <= b;
      when "10"   => y <= a and b;
      when others => y <= a xor b;
    end case;
  end process;
end rtl;
