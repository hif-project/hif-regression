// Case alternatives written with several labels each, in the source.
//
// The other side of merged_case_labels. There the two labels are one the
// frontend built, by folding two alternatives that happened to have identical
// bodies; here they are written out and the parser has to keep all of them.
// The paths meet in the backend and diverge before it, which is why a fixture
// that only exercises the merge cannot say whether the source form survives.
//
// Three labels on one alternative and two on the next, with a default under
// them. A label dropped anywhere in that list falls through to the default and
// gets `a ^ b` instead of `a` or `b` - a legal case statement, a different
// answer.
module case_multi_labels(input [2:0] sel, input [3:0] a, input [3:0] b, output reg [3:0] y);
  always @(*) begin
    case (sel)
      3'd0, 3'd1, 3'd2: y = a;
      3'd3, 3'd4:       y = b;
      default:          y = a ^ b;
    endcase
  end
endmodule
