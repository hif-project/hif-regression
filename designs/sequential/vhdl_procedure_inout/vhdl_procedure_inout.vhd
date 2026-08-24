-- A divide-by-two, written with the state update factored into a procedure that
-- takes its state as an `inout` parameter.
--
-- `inout` is the natural direction here and not a contrivance: the procedure has
-- to *read* the current state to invert it and *write* the new one, which is
-- exactly what `inout` means. A pair of `in`/`out` parameters would be the same
-- thing spelled worse.
--
-- It is here because of the `inout` half of hif-backend#70, which fails
-- differently from the `out` half and worse. A Verilog task's `inout` argument
-- is copied *in* at entry as well as out at return. With the assignment emitted
-- as non-blocking, each call overwrote the local with the still-stale actual
-- before scheduling the new value, so the actual could never take it:
--
--     activation 1: copy-in s = x; s <= not x scheduled; return copies back x
--     activation 2: copy-in s = x   <- overwrites what the NBA landed
--     ...
--
-- Measured over four activations the output stayed x indefinitely. The `out`
-- half drains after one activation and is merely late; this one never
-- converges, so a design that only exercised `out` would understate it.
--
-- vhdl_procedure_out covers the `out` direction, combinationally. This one is
-- clocked because state is what an `inout` parameter is for.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_procedure_inout is
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    q   : out std_logic
  );
end entity;

architecture rtl of vhdl_procedure_inout is

  signal state : std_logic;

  -- Reads its argument and writes it back, so `inout`.
  procedure toggle(signal t : inout std_logic) is
  begin
    t <= not t;
  end procedure;

begin

  divider : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= '0';
      else
        toggle(state);
      end if;
    end if;
  end process;

  q <= state;

end architecture;
