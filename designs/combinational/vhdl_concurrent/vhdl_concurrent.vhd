-- The corpus's first VHDL -> Verilog design, and the reason it exists.
--
-- hif-backend#32: hif2verilog never printed a view's GlobalAction, which is
-- where vhdl2hif puts every VHDL concurrent signal assignment. A VHDL design
-- therefore regenerated as a Verilog module with the correct ports and an
-- empty body - valid Verilog, exit code 0, reparses cleanly, drives nothing.
--
-- Nothing here could have caught it. vhdl_and2 goes VHDL -> HIF -> VHDL, and
-- every other design is Verilog; verilog2hif rewrites continuous assignments
-- into processes, so no Verilog-sourced design ever reaches the backend with a
-- GlobalAction at all. The cross-language direction was simply not covered.
--
-- This is also the only place in the corpus where a VHDL-sourced design can be
-- validated by simulation: there is no VHDL simulator available (no ghdl, no
-- nvc, locally or in CI), but the regenerated *Verilog* has one. That is why
-- the oracle is a checked-in expected trace rather than a comparison against a
-- reference run of the source - see behavior.yaml.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_concurrent is
  port (a : in  std_logic;
        b : in  std_logic;
        c : in  std_logic;
        y : out std_logic;
        z : out std_logic;
        w : out std_logic);
end vhdl_concurrent;

architecture rtl of vhdl_concurrent is
  -- Driven concurrently and read by another concurrent assignment, so the
  -- regenerated Verilog has to declare it as a net: a continuous assign
  -- cannot drive a reg.
  signal s : std_logic;
begin
  s <= a and b;
  y <= s;
  z <= s or c;
  -- A VHDL "after" delay. The machinery for it was added by hif-backend#24,
  -- but no VHDL-derived assignment was ever emitted to carry it, so this is
  -- the only cross-repository coverage of that path.
  w <= a xor b after 2 ns;
end rtl;
