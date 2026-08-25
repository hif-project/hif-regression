// A three-way priority arbiter: the lowest-numbered request wins, and no
// request at all grants nothing.
//
// Four branches assign `grant`, so `grant` carries four fault locations rather
// than one. That is the point. Every Muffin design in this corpus before
// nibble_swap and this one was written with a single assignment per signal so
// that {signal, bit, type} names exactly one fault; here it names four, and the
// selectors have to say which branch by source line.
//
// The property under test is conditional observability. A fault injected into
// one branch is inert until that branch is taken, so its detectability is a
// property of the stimulus reaching the branch - not of the fault. An
// instrumentation that hoisted the injection out of the conditional, applying
// it to `grant` wherever it was assigned, would produce valid RTL that changes
// vectors the real fault leaves alone.
//
// LINE NUMBERS ARE LOAD-BEARING. behavior.yaml selects branches by source line,
// which is the only attribute distinguishing the four locations.
module priority_arbiter(input [2:0] req, output reg [2:0] grant);
  always @(*) begin
    if      (req[0]) grant = 3'b001;
    else if (req[1]) grant = 3'b010;
    else if (req[2]) grant = 3'b100;
    else             grant = 3'b000;
  end
endmodule
