// Parameterized mask built by replication rather than by $clog2.
//
// This fixture originally used $clog2 to derive an address width. It does not,
// because $clog2 does not currently survive a round trip: hif2verilog emits it
// as a system function call that verilog2hif cannot resolve on reparse - see
// docs/findings/2026-08-14-backend-codegen.md (finding 4). Adding a construct
// the toolchain cannot round-trip would only inflate the corpus.
module param_bitmask #(parameter WIDTH = 8) (
    input [WIDTH-1:0] d,
    output [WIDTH-1:0] low_bit,
    output [WIDTH-1:0] inverted,
    output any
);
  assign low_bit  = d & {{(WIDTH-1){1'b0}}, 1'b1};
  assign inverted = ~d;
  assign any      = |d;
endmodule
