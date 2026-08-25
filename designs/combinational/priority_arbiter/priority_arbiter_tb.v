// Stimulus for priority_arbiter, shared by the reference and the instrumented
// compile. The activation port exists only in the instrumented netlist.
//
// Every branch is taken at least once, and two of the vectors assert more than
// one request so the priority order is exercised rather than assumed. That
// matters here: a fault in the first branch has to stay invisible on a vector
// where req[0] is low, and has to appear on a vector where req[0] is set
// *together with* a higher request - which is only a distinct claim if some
// vector does assert two requests at once.
`timescale 1ns/1ps
module priority_arbiter_tb;
  reg [2:0] req;
  wire [2:0] grant;
  integer mut;
  integer fd;
  reg [4095:0] tracefile;

  priority_arbiter dut (
    .req(req), .grant(grant)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  task step;
    input [2:0] vr;
    begin
      req = vr;
      #5 $fdisplay(fd, "%0t,%b,%b", $time, req, grant);
    end
  endtask

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,req,grant");

    step(3'b001);
    step(3'b010);
    step(3'b100);
    step(3'b000);
    step(3'b011);
    step(3'b110);

    $fclose(fd);
    $finish;
  end
endmodule
