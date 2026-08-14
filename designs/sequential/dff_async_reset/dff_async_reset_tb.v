// Stimulus that can actually distinguish an asynchronous reset from a
// synchronous one.
//
// The clock is driven by hand rather than free-running, because what matters
// is precisely *when* rst_n moves relative to the edges. Every reset
// transition below happens with the clock idle at 0. On this design q must
// respond immediately; on a design whose reset had been folded into the
// clocked branch, q would hold its old value until the next rising edge.
//
// The `rst_asserted_idle` sample is the one that carries the whole point: it
// reads 0 here and would read 1 if `negedge rst_n` were ever dropped from
// the sensitivity list again (hif-backend#21).
`timescale 1ns/1ps
module dff_async_reset_tb;
  reg clk, rst_n, d;
  wire q;
  integer mut;
  integer fd;
  reg [4095:0] tracefile;

  dff_async_reset dut (
    .clk(clk), .rst_n(rst_n), .d(d), .q(q)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  task tick;                 // one rising edge, returning to idle low
    begin
      #5 clk = 1'b1;
      #5 clk = 1'b0;
      #1;
    end
  endtask

  task sample;
    input [8*24-1:0] phase;
    begin
      $fdisplay(fd, "%0s,%b,%b,%b", phase, rst_n, d, q);
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
    $fdisplay(fd, "phase,rst_n,d,q");

    clk = 1'b0; rst_n = 1'b1; d = 1'b1;

    tick;                        // capture d=1
    sample("after_load");        // q = 1

    #5 rst_n = 1'b0; #1;         // assert reset with the clock idle
    sample("rst_asserted_idle"); // q = 0 asynchronously - the decisive row

    #5 rst_n = 1'b1; #1;         // release it, still with no clock edge
    sample("rst_released_idle"); // q stays 0: releasing reset reloads nothing

    d = 1'b1;
    tick;
    sample("after_reload");      // q = 1

    d = 1'b0;
    tick;
    sample("after_capture_0");   // q = 0

    d = 1'b1;
    #5 rst_n = 1'b0; #1;         // reset again while d is high and clk idle
    sample("rst_again_idle");    // q = 0, and d is ignored

    #5 rst_n = 1'b1; #1;
    tick;                        // only now may d reach q
    sample("final");             // q = 1

    $fclose(fd);
    $finish;
  end
endmodule
