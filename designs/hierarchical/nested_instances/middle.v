// Middle level: instantiates the leaf and adds logic of its own, so the
// hierarchy is three deep rather than two.
module middle(input a, input b, input c, output y);
  wire leaf_out;
  leaf u_leaf(.a(a), .b(b), .y(leaf_out));
  assign y = leaf_out | c;
endmodule
