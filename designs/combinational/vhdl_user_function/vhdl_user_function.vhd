-- A user-defined VHDL function with an early return, declared in the
-- architecture and called from a concurrent assignment.
--
-- hif-backend#57 emitted a function's header and dropped its body, which
-- produces a module with the right ports that returns nothing. user_function.v
-- covers that from the Verilog side; this is the VHDL one, and it is a
-- different route in - a VHDL function returns a value with `return` where a
-- Verilog one assigns to its own name, so the two reach the emitter as
-- different bodies even though they leave it as the same construct.
--
-- The `return x` is deliberately *not* the last statement of an if/else. It is
-- an early return with code after it, which is the shape hif-backend#63's
-- lowering exists for: Verilog functions have no return statement, so each one
-- becomes an assignment to the function name followed by a `disable` out of a
-- named block. Written as a full if/else the disable would be redundant -
-- nothing follows either branch - and the fixture would say nothing about
-- whether it works. Written this way the `return z` below is reachable, and a
-- disable that was dropped, or that jumped to the wrong block, lets it
-- overwrite the value the early return just produced.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_user_function is
  port (a : in  std_logic_vector(3 downto 0);
        b : in  std_logic_vector(3 downto 0);
        y : out std_logic_vector(3 downto 0));
end vhdl_user_function;

architecture rtl of vhdl_user_function is

  function pick_larger(x : std_logic_vector(3 downto 0);
                       z : std_logic_vector(3 downto 0))
    return std_logic_vector is
  begin
    if x > z then
      return x;
    end if;
    return z;
  end function;

begin
  y <= pick_larger(a, b);
end rtl;
