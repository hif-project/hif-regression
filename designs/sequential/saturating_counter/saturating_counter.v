// A counter that counts to nine and then stops, written with the three branches
// such a counter has.
//
// `count` is a register assigned in all three, so it carries three fault
// locations. Every other sequential Muffin design here has exactly one location
// per register on purpose - counter_load says so in a comment, and pipeline3
// and param_counter do too - so the per-assignment rule had never been tested
// on state, only on wires.
//
// State is what makes this different from priority_arbiter, where a branch
// fault is visible exactly on the vectors that take the branch. Here `count`
// feeds the branch condition, so a fault does not merely change an output: it
// changes which branch runs next, and the damage compounds across cycles. The
// increment fault below never lets the counter take an even value again, and
// the hold fault turns the saturated state into an oscillation.
//
// LINE NUMBERS ARE LOAD-BEARING. behavior.yaml selects branches by source line,
// the only attribute separating the three locations.
module saturating_counter(input clk, input rst, output reg [3:0] count);
  always @(posedge clk) begin
    if (rst)                count <= 4'd0;
    else if (count == 4'd9) count <= count;
    else                    count <= count + 1'b1;
  end
endmodule
