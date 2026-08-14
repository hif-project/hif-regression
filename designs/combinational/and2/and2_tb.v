// Stimulus for and2, shared by both the reference and the instrumented
// compile. The activation port only exists in the instrumented netlist, so it
// is connected under `ifdef MUFFIN_MUT - which the simulation operation
// supplies via `defines`. Runtime fault selection and the trace path both
// arrive as plusargs, so one compiled binary serves every run.
`timescale 1ns/1ps
module and2_tb;
  reg a, b;
  wire y;
  integer mut;
  integer fd;
  integer i;
  reg [1023:0] tracefile;

  and2 dut (
    .a(a), .b(b), .y(y)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    $fdisplay(fd, "time,a,b,y");
    for (i = 0; i < 4; i = i + 1) begin
      {a, b} = i[1:0];
      #5;
      $fdisplay(fd, "%0t,%b,%b,%b", $time, a, b, y);
    end
    $fclose(fd);
    $finish;
  end
endmodule
