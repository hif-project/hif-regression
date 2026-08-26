// Five rows. Bit 7 is on the left in every `%b` below, and `dout[k]` is the
// parity of `din[2k+1], din[2k]`.
//
//   din       dout  what it pins
//   00000000  0000  the quiet baseline
//   10101010  1111  every pair has exactly one bit set
//   00001100  0000  a pair with *both* bits set is even - parity, not "any bit"
//   10000100  1010  one pair per output bit, so each lane is pinned on its own
//   00100001  0101  the mirror of the row above
//
// The last two rows are the discriminating pair. Each sets exactly two bits of
// `din`, in different pairs, so every output bit is decided by one pair and
// only that pair. Under hif-core#24 the loop ran over 0, 1, 2, 3 instead of
// 0, 2, 4, 6: `dout[2]` and `dout[3]` would have no driver at all and the two
// low lanes would have two each, so neither row can be reproduced by a shifted
// window whatever it reads.
//
// Rows one and three matter for a different reason - they are the pair that
// keeps the oracle honest about the operator. Both leave every output at 0
// while differing in `din`, so an implementation that or-reduced each pair
// rather than xor-ing it fails row three while passing row one.
`timescale 1ns/1ps
module for_generate_strided_tb;
  reg [7:0] din;
  wire [3:0] dout;
  integer fd;
  reg [4095:0] tracefile;

  for_generate_strided dut (.din(din), .dout(dout));

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
    step(8'b10101010);
    step(8'b00001100);
    step(8'b10000100);
    step(8'b00100001);

    $fclose(fd);
    $finish;
  end
endmodule
