// A Verilog blocking assignment read back later in the same clocked process,
// carried through VHDL and returned. No open issue - regression protection for
// the hardest mapping on this path.
//
// Verilog's `=` takes effect immediately, so the second statement sees the
// value the first just wrote. A VHDL signal does not: it keeps its old value
// until the process suspends, so the same two statements written against
// signals would read the previous edge's intermediate. The only VHDL construct
// with Verilog's blocking behaviour is a variable, so this is the case that
// forces hif2vhdl to choose one and get it right.
//
// The process is clocked rather than combinational, and that is the whole
// reason the design works. A combinational lowering puts the intermediate in
// its own sensitivity list, so a stale read re-triggers and settles to the same
// fixed point - measured, and it made the first version of this design pass a
// stale-read mutation unchanged. A clocked process runs once per edge and does
// not re-trigger, so staleness survives to the next sample.
//
// acc is a ^ b and q is acc ^ a, so q must equal b at every edge. A stale read
// yields the previous edge's intermediate xor the current a, which is not b.
module v2vhdl_blocking_readback(
    input  clk,
    input  [3:0] a,
    input  [3:0] b,
    output reg [3:0] acc,
    output reg [3:0] q
);
  always @(posedge clk) begin
    acc = a ^ b;
    q   = acc ^ a;
  end
endmodule
