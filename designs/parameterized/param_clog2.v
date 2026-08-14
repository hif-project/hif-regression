// Address width derived with $clog2 - the round trip hif-backend#19 broke.
//
// hif2verilog used to emit $clog2 under its internal name
// (hif_verilog__system_clog2), which no simulator accepts and the reparse
// step could not resolve, so this construct was deliberately kept out of the
// corpus. Fixed in hif-project/hif-backend#28; this fixture is what keeps it
// fixed.
//
// $clog2 appears in both positions the backend reaches it from: a port's
// declared width, and an ordinary expression in the body.
module param_clog2 #(parameter DEPTH = 16) (
    input [$clog2(DEPTH)-1:0] addr,
    input en,
    output [$clog2(DEPTH)-1:0] next_addr,
    output at_top
);
  assign next_addr = en ? (addr + 1'b1) : addr;
  assign at_top    = (addr == ($clog2(DEPTH) - 1));
endmodule
