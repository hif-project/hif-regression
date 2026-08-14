// Toggles the one real input so the trace is not constant, and samples the
// tie-offs alongside it. A design whose outputs were all constant would
// produce a trace that compared equal to itself even if both sides were
// broken; `gated` moving is what keeps the comparison honest.
`timescale 1ns/1ps
module constant_tieoff_tb;
  reg en;
  wire [31:0] id;
  wire [7:0]  mask;
  wire        ready;
  wire [3:0]  gated;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  constant_tieoff dut (.en(en), .id(id), .mask(mask), .ready(ready), .gated(gated));

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,en,id,mask,ready,gated");
    for (i = 0; i < 4; i = i + 1) begin
      en = i[0];
      #5;
      $fdisplay(fd, "%0t,%b,%0d,%h,%b,%b", $time, en, id, mask, ready, gated);
    end
    $fclose(fd);
    $finish;
  end
endmodule
