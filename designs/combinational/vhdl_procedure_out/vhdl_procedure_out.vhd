-- A full adder written the way VHDL usually writes one when the logic is
-- shared: a procedure that returns its results through `out` parameters.
--
-- A procedure with `out` parameters is *the* ordinary way a VHDL procedure
-- returns anything - a function returns one value, a procedure returns several -
-- so this is not an exotic spelling. The corpus had no procedure at all.
--
-- It is here because of hif-backend#70. A Verilog task's `output` argument is
-- copied back to its actual when the task *returns*, while a non-blocking
-- assignment updates the task-local storage only at the end of the time step -
-- after the copy-back has already run. hif2verilog emitted the assignment
-- inside the task with `<=`, so every call published the value computed by the
-- *previous* call, and the first published x:
--
--     a b cin      correct s      as emitted
--     0 0 0            0              x        <- first activation
--     1 0 0            1              0        <- previous activation's result
--     1 1 0            0              1
--
-- The regenerated design compiles, reparses and simulates. It is simply one
-- activation late, which is invisible to anything but a value check - and the
-- values have to be read at the first activation, because the lag drains.
--
-- The sum and carry depend on the inputs rather than being literals, which is
-- what makes the lag show up as a wrong answer rather than as a late-but-equal
-- one.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_procedure_out is
  port (
    a    : in  std_logic;
    b    : in  std_logic;
    cin  : in  std_logic;
    s    : out std_logic;
    cout : out std_logic
  );
end entity;

architecture rtl of vhdl_procedure_out is

  -- Two results, so a procedure with `out` parameters rather than a function.
  procedure full_add(signal x, y, ci : in  std_logic;
                     signal sum, carry : out std_logic) is
  begin
    sum   <= x xor y xor ci;
    carry <= (x and y) or (x and ci) or (y and ci);
  end procedure;

begin

  adder : process(a, b, cin)
  begin
    full_add(a, b, cin, s, cout);
  end process;

end architecture;
