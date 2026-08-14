// Full 8-vector truth table over a, b and cin, so both half adders are
// exercised in both polarities and every carry path is driven.
//
// The `sum` output is the one that matters here: it is the output furthest
// from the primary inputs, reached through s1 which the second half adder
// produces. That is the path that read a stale value before hif-backend#16.
`timescale 1ns/1ps
module hier_adder_tb;
  reg a, b, cin;
  wire sum, cout;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  hier_adder dut (
    .a(a), .b(b), .cin(cin), .sum(sum), .cout(cout)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,cin,sum,cout");
    for (i = 0; i < 8; i = i + 1) begin
      {a, b, cin} = i[2:0];
      #5;
      $fdisplay(fd, "%0t,%b,%b,%b,%b,%b", $time, a, b, cin, sum, cout);
    end
    $fclose(fd);
    $finish;
  end
endmodule
