// Changes `d` while `en` is low, which is the only stimulus that can tell a
// latch from a wire.
//
//   en  d       q      what the row states
//    1  1010  1010   transparent: q follows d
//    0  0101  1010   opaque: d moved, q did not
//    0  1111  1010   and again, from a different d
//    1  0011  0011   transparent again, a new value is captured
//    0  1000  0011   and held
//
// Rows two, three and five are the design. If `q` followed `d` there, the
// latch became a wire; if `q` went to x or 0 there, the hold was replaced by a
// supplied else branch.
`timescale 1ns/1ps
module latch_enable_tb;
  reg en;
  reg [3:0] d;
  wire [3:0] q;
  integer fd;
  reg [4095:0] tracefile;

  latch_enable dut (.en(en), .d(d), .q(q));

  task step;
    input xen;
    input [3:0] xd;
    begin
      en = xen;
      d  = xd;
      #1 $fdisplay(fd, "%0t,%b,%b,%b", $time, en, d, q);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,en,d,q");

    step(1'b1, 4'b1010);
    step(1'b0, 4'b0101);
    step(1'b0, 4'b1111);
    step(1'b1, 4'b0011);
    step(1'b0, 4'b1000);

    $fclose(fd);
    $finish;
  end
endmodule
