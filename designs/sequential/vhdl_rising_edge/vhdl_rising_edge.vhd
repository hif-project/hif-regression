-- The canonical VHDL clocked process: `if rising_edge(clk)` inside a process
-- sensitive to clk.
--
-- The corpus had no VHDL sequential logic at all. Every clocked design here is
-- Verilog, where the edge is written into the sensitivity list itself; in VHDL
-- the sensitivity list says only "clk" and the edge is a condition in the body,
-- so hif2verilog has to recognise that condition and rebuild `always @(posedge
-- clk)` from it - hif-backend#51. Get that wrong and the process becomes
-- level-sensitive on clk, which is a latch that reloads on both edges: valid
-- Verilog, same ports, different machine.
--
-- The enable is what makes the difference visible. Without it a register that
-- reloaded on the falling edge as well would still show `d` in every sample;
-- with it, the design has to hold, and a process that ran at the wrong time
-- picks up whatever `d` had moved on to.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_rising_edge is
  port (clk : in  std_logic;
        en  : in  std_logic;
        d   : in  std_logic_vector(3 downto 0);
        q   : out std_logic_vector(3 downto 0));
end vhdl_rising_edge;

architecture rtl of vhdl_rising_edge is
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if en = '1' then
        q <= d;
      end if;
    end if;
  end process;
end rtl;
