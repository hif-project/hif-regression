// Primitive gates and continuous assignments in the same module. The mixture
// is the point: the two reach HIF by different paths, and this checks they
// coexist in one design unit.
module mixed_structural_rtl(input a, input b, input c, output y, output z);
  wire ab;
  and g1(ab, a, b);
  assign y = ab ^ c;
  assign z = ~ab;
endmodule
