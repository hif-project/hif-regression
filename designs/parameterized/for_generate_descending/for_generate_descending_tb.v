// Six rows. Bit 7 is on the left in every `%b` below, and `dout[k]` is set when
// `din[k+1]` differs from `din[k]`.
//
//   din       dout     what it pins
//   00000000  0000000  no transitions
//   11111111  0000000  no transitions either - a transition, not a set bit
//   00001111  0001000  one transition, in the middle
//   10101010  1111111  a transition at every position
//   00000001  0000001  the bottom lane, driven only by i = 1
//   10000000  1000000  the top lane, driven only by i = 7
//
// The last two rows are the discriminating pair, and they sit at the two ends
// for a reason. Under the `op_gt` half of hif-core#24 the loop ran i = 6 down
// to 0 rather than 7 down to 1: `dout[6]` then has no driver, so row six cannot
// be produced at all, and i = 0 would index `din[-1]`, which the source never
// asks for. A window that merely slid could otherwise be mistaken for the bits
// being numbered the other way round; a row at each end leaves nowhere for that
// reading to go.
//
// Rows one and two are the pair that keeps the oracle honest about the
// operator: both are transition-free while differing in every bit of `din`, so
// an implementation reading the bit itself rather than the change between two
// bits fails row two while passing row one.
`timescale 1ns/1ps
module for_generate_descending_tb;
  reg [7:0] din;
  wire [6:0] dout;
  integer fd;
  reg [4095:0] tracefile;

  for_generate_descending dut (.din(din), .dout(dout));

  task step;
    input [7:0] d;
    begin
      din = d;
      #1 $fdisplay(fd, "%0t,%b,%b", $time, din, dout);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,din,dout");

    step(8'b00000000);
    step(8'b11111111);
    step(8'b00001111);
    step(8'b10101010);
    step(8'b00000001);
    step(8'b10000000);

    $fclose(fd);
    $finish;
  end
endmodule
