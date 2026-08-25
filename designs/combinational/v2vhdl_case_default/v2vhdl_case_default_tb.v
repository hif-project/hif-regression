// Shared by both compiles in the pipeline: the untouched RTL and the same
// design after a full excursion through VHDL and back.
//
// a and b are chosen so a, b, a & b and a ^ b are four different values -
// 1100, 1010, 1000, 0110 - which is what makes each alternative identifiable
// from the trace alone.
//
// The last step drives s to x. Verilog's case matches exactly, x included, so
// xx reaches no named alternative and must land on the default; that is the
// step which distinguishes a real WHEN OTHERS from an explicit WHEN "11"
// label, since both serve 2'b11 and only OTHERS also serves a selector that is
// not a defined value.
//
// The step before it is 2'b10, not 2'b11, so a selector that matched nothing
// and left the process holding is distinguishable from one that reached the
// default: the hold would report 1000 where the default gives 0110.
`timescale 1ns/1ps
module v2vhdl_case_default_tb;
  reg [1:0] s;
  reg [3:0] a, b;
  wire [3:0] y;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_case_default dut (.s(s), .a(a), .b(b), .y(y));

  task step;
    input [1:0] vs;
    begin
      s = vs;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, s, a, b, y);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,s,a,b,y");

    a = 4'b1100;
    b = 4'b1010;
    step(2'b00);
    step(2'b01);
    step(2'b11);
    step(2'b10);
    step(2'bxx);

    $fclose(fd);
    $finish;
  end
endmodule
