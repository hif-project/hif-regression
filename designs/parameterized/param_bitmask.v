// Parameterized mask built by replication rather than by $clog2.
//
// This fixture originally used $clog2 to derive an address width, and kept the
// replication form because $clog2 did not survive a round trip
// (hif-project/hif-backend#19). That is now fixed, and param_clog2.v covers
// $clog2 directly; this fixture stays as it is, since replication and
// reduction are what it is actually here to exercise.
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
