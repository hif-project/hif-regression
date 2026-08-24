-- A device sharing a bus with another device: it drives only its own lines and
-- leaves the rest of the bus alone.
--
-- This is the ordinary arrangement on any shared bus - a device owns some of
-- the wires and must keep off the others - and it is the case a bidirectional
-- port with a *whole-port* driver gets wrong. vhdl_tristate_pad covers a pin
-- this device drives entirely; this covers one it drives partially, which is a
-- different failure and needs a different design.
--
-- It is here because of the second half of hif-backend#71. The lowering gives a
-- procedurally driven `inout` port an internal register and a continuous
-- assignment from that register onto the port - but the assignment covers the
-- whole port, while the process here writes only two of the four lines. The
-- lines it never writes have to contribute nothing. Left at their default they
-- contribute 'x', which beats the other device's real driver, and the bus reads
-- x on wires this device is supposed to be keeping off:
--
--     bus_lines = xx01   instead of   1001
--
-- Output that elaborates, reparses, exits 0 and is silently wrong - so a
-- structural check cannot see it and only a second driver on the bus makes it
-- observable.
--
-- The target is a *slice* rather than a bit-select, deliberately: the lowering
-- has to reach through both to find the port, and a slice is the spelling a
-- real bus device uses.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_shared_bus is
  port (
    sel       : in    std_logic;                     -- this device selected
    code      : in    std_logic_vector(1 downto 0);  -- what it answers with
    bus_lines : inout std_logic_vector(3 downto 0)   -- shared with another device
  );
end entity;

architecture rtl of vhdl_shared_bus is
begin

  -- Lines 1..0 belong to this device. Lines 3..2 belong to somebody else and
  -- are never assigned here - not even to 'Z', because this device has no
  -- driver on them at all.
  responder : process(sel, code)
  begin
    if sel = '1' then
      bus_lines(1 downto 0) <= code;
    else
      bus_lines(1 downto 0) <= "ZZ";
    end if;
  end process;

end architecture;
