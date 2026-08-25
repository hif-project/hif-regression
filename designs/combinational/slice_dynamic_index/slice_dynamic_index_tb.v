// Walks the index across an asymmetric pattern, so no two index values give
// the same answer by chance.
//
// d = 1001_0110, read bit by bit:
//
//   idx  d[idx]  pair = {d[idx], d[0]}
//     0       0   00     the low end, and d[0] against itself
//     1       1   10
//     4       1   10     the middle
//     7       1   10     the high end
//
// then two patterns that separate "the index is used" from "the index is
// ignored":
//
//   d = 0000_0001, idx = 7   d[7] = 0, d[0] = 1  ->  01
//   d = 1111_1110, idx = 0   d[0] = 0, d[7] = 1  ->  00
//
// Those last two rows are the discriminating ones: an index folded to a
// constant, or reversed, reads the opposite end of the vector and the two
// columns disagree.
`timescale 1ns/1ps
module slice_dynamic_index_tb;
  reg [7:0] d;
  reg [2:0] idx;
  wire bit_at;
  wire [1:0] pair;
  integer fd;
  reg [4095:0] tracefile;

  slice_dynamic_index dut (.d(d), .idx(idx), .bit_at(bit_at), .pair(pair));

  task step;
    input [7:0] xd;
    input [2:0] xidx;
    begin
      d = xd;
      idx = xidx;
      #1 $fdisplay(fd, "%0t,%b,%0d,%b,%b", $time, d, idx, bit_at, pair);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,d,idx,bit_at,pair");

    step(8'b1001_0110, 3'd0);
    step(8'b1001_0110, 3'd1);
    step(8'b1001_0110, 3'd4);
    step(8'b1001_0110, 3'd7);
    step(8'b0000_0001, 3'd7);
    step(8'b1111_1110, 3'd0);

    $fclose(fd);
    $finish;
  end
endmodule
