// The same static `if generate`, with a module instance in one branch instead
// of a continuous assignment - which is what selecting between implementations
// usually means.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// This one does not reach the backend at all: verilog2hif aborts in hif-core's
// simplify.cpp - hif-frontend#32. if_generate.v, whose branches hold
// continuous assignments, translates at exit 0 and fails later, in the
// backend. So the instance inside the generate is a separate defect in a
// separate repository, and the pair is what separates them.
module if_generate_instance_leaf(input [3:0] a, input [3:0] b, output [3:0] y);
  assign y = a & b;
endmodule

module if_generate_instance #(parameter USE_LEAF = 1) (input [3:0] a, input [3:0] b, output [3:0] y);
  generate
    if (USE_LEAF) begin : with_leaf
      if_generate_instance_leaf u (.a(a), .b(b), .y(y));
    end else begin : without_leaf
      assign y = a | b;
    end
  endgenerate
endmodule
