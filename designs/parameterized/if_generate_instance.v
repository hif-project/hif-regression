// The same static `if generate`, with a module instance in one branch instead
// of a continuous assignment - which is what selecting between implementations
// usually means.
//
// This design used to fail deliberately: verilog2hif aborted in hif-core's
// simplify.cpp with "Cannot resolve if generate condition" - hif-frontend#32.
//
// The condition was never the problem, despite what the diagnostic said. Verilog
// lowers `if (<cond>)` to `or_reduce(<cond>)` and builds the else branch as the
// negation of that, and hif-core's constant folder had a `// TODO` where a
// reduction over a constant should be folded - so the else condition stayed an
// Expression where _simplifyIfGenerate needs a ConstValue, and a literal
// `if (1)` failed exactly as this parameterised one did. Nor did the instance
// have to be inside the generate: it is only what makes partialFlattening run
// flattenDesign, which is what asks for generate expansion at all.
//
// Fixed by hif-core c726127, plus hif-frontend 329b178 for the half that
// surfaced once branches could actually be removed: a losing branch holding the
// only instance of a module left partialFlattening looping forever.
//
// Still paired with if_generate.v, which continues to fail in the backend on
// hif-backend#86. That pairing is more useful now than when both failed: one
// half passes, so a regression in either is attributable on its own.
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
