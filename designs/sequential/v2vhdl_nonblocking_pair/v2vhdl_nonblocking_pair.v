// A Verilog non-blocking pair carried through VHDL and returned. No open issue
// - regression protection, and the complement of
// sequential/v2vhdl_blocking_readback.
//
// Both statements are non-blocking, so both right-hand sides are evaluated with
// the values standing at the edge: q receives p's previous contents, not the d
// that p is taking this edge. The two statements form a two-stage shift
// register precisely because neither sees the other's effect.
//
// This is the mapping VHDL gets for free where Verilog needs a rule: a VHDL
// signal assignment inside a process is already deferred to suspension, so a
// faithful lowering is a pair of signal assignments and nothing else. The way
// to get it wrong is to make one of them immediate - a variable, or a blocking
// assignment on the way back - which collapses the shift register into a single
// stage and makes q equal p.
//
// d is driven one-hot so consecutive stages never share a value and the
// one-edge lag is visible on every row.
module v2vhdl_nonblocking_pair(
    input  clk,
    input  [3:0] d,
    output reg [3:0] p,
    output reg [3:0] q
);
  always @(posedge clk) begin
    p <= d;
    q <= p;
  end
endmodule
