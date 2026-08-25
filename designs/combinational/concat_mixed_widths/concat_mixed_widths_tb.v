// Four patterns chosen so that each field is distinguishable from its
// neighbours in the result.
//
//   s w        n       packed_out         = {s, w, n, 101}
//   1 11000011 1001    1110000111001101
//   0 00000000 1111    0000000001111101   the byte is all zeros: its extent shows
//   1 11111111 0000    1111111110000101   and all ones: the same boundary again
//   0 01010101 1010    0010101011010101   alternating across every boundary
//
// The constant tail 101 is the anchor - it must be the bottom three bits of
// every row - and the all-zeros and all-ones bytes bracket the byte field, so
// a field placed one bit out changes the result rather than blending in.
`timescale 1ns/1ps
module concat_mixed_widths_tb;
  reg [7:0] w;
  reg [3:0] n;
  reg s;
  wire [15:0] packed_out;
  wire [7:0] mixed;
  integer fd;
  reg [4095:0] tracefile;

  concat_mixed_widths dut (.w(w), .n(n), .s(s), .packed_out(packed_out), .mixed(mixed));

  task step;
    input [7:0] xw;
    input [3:0] xn;
    input xs;
    begin
      w = xw;
      n = xn;
      s = xs;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b", $time, w, n, s, packed_out, mixed);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,w,n,s,packed_out,mixed");

    step(8'b1100_0011, 4'b1001, 1'b1);
    step(8'b0000_0000, 4'b1111, 1'b0);
    step(8'b1111_1111, 4'b0000, 1'b1);
    step(8'b0101_0101, 4'b1010, 1'b0);

    $fclose(fd);
    $finish;
  end
endmodule
