module gate_chain(input a, input b, input cin, output sum, output cout);
  wire axb, ab, axb_cin;
  xor x1(axb, a, b);
  xor x2(sum, axb, cin);
  and a1(ab, a, b);
  and a2(axb_cin, axb, cin);
  or  o1(cout, ab, axb_cin);
endmodule
