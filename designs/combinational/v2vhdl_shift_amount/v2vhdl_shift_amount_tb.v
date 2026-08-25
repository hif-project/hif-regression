// Shared by both compiles in the pipeline: the untouched RTL and the same
// design after a full excursion through VHDL and back.
//
// a is 10010011: not a palindrome and not symmetric under either shift, so a
// left shift, a right shift and a rotate all give different answers. The
// amounts include 0 - where both outputs must equal a, which is the row a
// lowering that always shifts by one fails - and an amount large enough that
// bits leave the vector entirely, which is where a rotate and a shift part
// company.
`timescale 1ns/1ps
module v2vhdl_shift_amount_tb;
  reg [7:0] a;
  reg [2:0] n;
  wire [7:0] l, r;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_shift_amount dut (.a(a), .n(n), .l(l), .r(r));

  task step;
    input [7:0] va;
    input [2:0] vn;
    begin
      a = va;
      n = vn;
      #1 $fdisplay(fd, "%0t,%b,%0d,%b,%b", $time, a, n, l, r);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,n,l,r");

    step(8'b10010011, 3'd0);
    step(8'b10010011, 3'd1);
    step(8'b10010011, 3'd3);
    step(8'b10010011, 3'd7);

    $fclose(fd);
    $finish;
  end
endmodule
