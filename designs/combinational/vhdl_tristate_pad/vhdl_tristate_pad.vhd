-- A bidirectional I/O pad: the smallest design that is genuinely bidirectional.
--
-- The device drives `pad` when its output enable is asserted and releases the
-- pin otherwise, and it samples whatever is actually on the pin - which is not
-- necessarily what it is driving, because somebody else may be. That is the
-- whole contract of a bidirectional pin, and it is what makes this a real
-- design rather than a defect fragment.
--
-- It is here because of hif-backend#71. A VHDL `inout` port driven by a process
-- was emitted as a bare Verilog `inout` - a net - while the process assigned to
-- it procedurally. A net is not a valid procedural l-value, so the regenerated
-- design did not elaborate, while hif2verilog exited 0 and verilog2hif reparsed
-- the output cleanly. Nothing in the corpus was bidirectional, so nothing could
-- have caught it: every other VHDL design here is `in`/`out` only.
--
-- Three properties have to survive the round trip, and each is a separate way
-- for the lowering to be wrong while still elaborating:
--
--   drive     with oe = '1', the pin carries din;
--   release   with oe = '0', the pin goes high impedance and the *external*
--             driver wins. VHDL spells release as a value, 'Z', not as a
--             separate enable, so a lowering that drove unconditionally would
--             pass the drive check and fail here;
--   sample    dout follows the pin, including while another device drives it.
--             The read must stay on the port and not follow the process's own
--             write onto whatever internal register the backend introduces -
--             otherwise the device reads back what it last drove instead of
--             what is on the wire, which is silent and only differs when
--             somebody else is driving.
library ieee;
use ieee.std_logic_1164.all;

entity vhdl_tristate_pad is
  port (
    oe   : in    std_logic;  -- output enable
    din  : in    std_logic;  -- value to drive onto the pin
    pad  : inout std_logic;  -- the bidirectional pin itself
    dout : out   std_logic   -- value sampled from the pin
  );
end entity;

architecture rtl of vhdl_tristate_pad is
begin

  pad_driver : process(oe, din, pad)
  begin
    if oe = '1' then
      pad <= din;
    else
      pad <= 'Z';
    end if;

    -- Sampled from the pin, not from din: with oe = '0' this is whatever the
    -- outside world is driving.
    dout <= pad;
  end process;

end architecture;
