// Asynchronous reset: the reset edge is in the sensitivity list, so q clears
// without waiting for a clock edge. Contrast with dff_sync_reset.
//
// Behavioral, and deliberately so. This construct was already in the corpus
// as a structural design when hif-backend#21 regenerated it as
// `always @(posedge clk)` - dropping `negedge rst_n` entirely and turning the
// asynchronous reset into a synchronous one. Nothing caught it: the output
// parsed, reparsed, and was a perfectly plausible flip-flop.
//
// The lesson is that having the construct in the corpus is not the same as
// exercising it. A testbench that only moves its inputs on a clock edge
// cannot tell an asynchronous reset from a synchronous one - both produce
// identical traces. So the stimulus here moves rst_n while the clock is
// idle, which is the only stimulus that can see the difference.
// Written as a single assignment, like dff_enable, so that q has exactly one
// fault location and {signal, bit, type} stays an unambiguous selector. The
// if/else form gives q two assignments and therefore two stuck-at sites per
// polarity. What this fixture exists to protect - the two-edge sensitivity
// list, and reset taking effect without a clock edge - is unaffected.
module dff_async_reset(input clk, input rst_n, input d, output reg q);
  always @(posedge clk or negedge rst_n) begin
    q <= !rst_n ? 1'b0 : d;
  end
endmodule
