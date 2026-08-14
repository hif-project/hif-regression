// A 2:1 multiplexer built entirely from primitive gates. Fault locations here
// come from gate instances rather than from continuous assignments, which is
// what makes this worth simulating separately from the RTL muxes.
module struct_mux(input a, input b, input sel, output y);
  wire nsel, a_gated, b_gated;

  not g_not(nsel, sel);
  and g_a(a_gated, a, nsel);
  and g_b(b_gated, b, sel);
  or  g_y(y, a_gated, b_gated);
endmodule
