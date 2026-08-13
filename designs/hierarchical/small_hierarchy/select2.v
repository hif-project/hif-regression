module select2(input x, input y, input sel, output z);
  assign z = sel ? y : x;
endmodule
