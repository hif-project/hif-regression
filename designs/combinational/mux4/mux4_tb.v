// Sweeps every select value twice, under complementary data patterns, so the
// fault-free output alternates rather than sitting at one value - a trace that
// is constant would make SA0 and SA1 indistinguishable.
`timescale 1ns/1ps
module mux4_tb;
  reg [3:0] d;
  reg [1:0] sel;
  wire y;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  mux4 dut (
    .d(d), .sel(sel), .y(y)
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
    $fdisplay(fd, "time,d,sel,y");
    for (i = 0; i < 8; i = i + 1) begin
      d   = (i < 4) ? 4'b1010 : 4'b0101;
      sel = i[1:0];
      #5;
      $fdisplay(fd, "%0t,%h,%0d,%b", $time, d, sel, y);
    end
    $fclose(fd);
    $finish;
  end
endmodule
