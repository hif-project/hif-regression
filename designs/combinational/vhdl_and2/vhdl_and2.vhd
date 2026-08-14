-- The corpus's first VHDL design, and the reason it exists.
--
-- hif-backend#27 left the design unit hif2vhdl emitted last as a zero-byte
-- file. With a single design unit that is the only unit, so hif2vhdl produced
-- nothing at all while exiting 0. Nothing here could have caught it: every
-- other design in this corpus is Verilog, so vhdl2hif and hif2vhdl were
-- declared in tools.yaml and never actually run.
--
-- Deliberately one entity. The backend writes one file per design unit, and
-- the runner requires a declared artifact to resolve to exactly one file, so a
-- multi-unit VHDL design cannot be expressed here yet - and would be testing
-- the runner rather than the toolchain. The single-unit case is also the
-- sharpest form of #27.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_and2 is
  port (a, b : in std_logic; y : out std_logic);
end vhdl_and2;

architecture rtl of vhdl_and2 is
begin
  y <= a and b;
end rtl;
