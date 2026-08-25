-- A VHDL process variable, which updates immediately, next to signal
-- assignments, which do not.
--
-- This is the distinction VHDL makes that Verilog spells with `=` against
-- `<=`, and it is the one an intermediate representation is most likely to
-- flatten: `t` is written, read back, written again and read back again inside
-- a single process execution, and every read has to see the write before it.
-- Turn `t` into a signal and the process still has four statements, still
-- drives both outputs and still regenerates - it just publishes the *previous*
-- execution's value, so `y` lags one step behind the inputs.
--
-- The stimulus makes `a and b` alternate on every step, so a `y` that lagged
-- disagrees on every row rather than on the few where the value happened to
-- change.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_variable_process is
  port (a : in  std_logic;
        b : in  std_logic;
        c : in  std_logic;
        y : out std_logic;
        z : out std_logic);
end vhdl_variable_process;

architecture rtl of vhdl_variable_process is
begin
  process (a, b, c)
    variable t : std_logic;
  begin
    t := a and b;
    y <= t;
    t := t or c;
    z <= t;
  end process;
end rtl;
