// A `for generate` whose index advances by two, folding a byte into the parity
// of each adjacent pair of bits. The strided loop is the ordinary way to write
// "two bits at a time", and every output bit is driven exactly once, so the
// design has no undriven state and nothing here depends on how a floating bit
// reads.
//
// This is the design hif-core#24 made wrong. Expanding a generate substituted
// the iteration *ordinal* for the genvar instead of the value it takes, so a
// loop over 0, 2, 4, 6 elaborated over 0, 1, 2, 3: every iteration would read
// its neighbour's pair, `dout[2]` and `dout[3]` would be driven by nobody, and
// `dout[0]` and `dout[1]` by two iterations each. Exit 0, no diagnostic and
// valid Verilog out. Fixed in hif-core 5603a2a.
//
// hif-core's own tests own the exhaustive loop-header matrix. What this design
// asks is narrower and cannot be asked there: that ordinary HDL reaches the
// corrected semantics through the real toolchain, end to end and by simulation.
module for_generate_strided (input [7:0] din, output wire [3:0] dout);
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 2) begin : fold
      assign dout[i / 2] = din[i] ^ din[i + 1];
    end
  endgenerate
endmodule
