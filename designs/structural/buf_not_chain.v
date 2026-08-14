// Chains of single-input primitives. The buffer chain should be transparent
// and the inverter chain should invert exactly twice, which makes an injected
// fault anywhere along either chain easy to reason about.
module buf_not_chain(input a, output y_buf, output y_inv);
  wire b1, b2, n1;

  buf u_b1(b1, a);
  buf u_b2(b2, b1);
  buf u_b3(y_buf, b2);

  not u_n1(n1, a);
  not u_n2(y_inv, n1);
endmodule
