// Clocked stimulus: inputs are applied, then the clock edge is awaited, then
// the result is sampled one time unit later. Reset is asserted on the first
// cycle and again on the last, and the enable is toggled so that both the
// capture and the hold paths are exercised.
`timescale 1ns/1ps
module dff_enable_tb;
  reg clk, rst, en, d;
  wire q;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  dff_enable dut (
    .clk(clk), .rst(rst), .en(en), .d(d), .q(q)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "cycle,rst,en,d,q");
    for (i = 0; i < 7; i = i + 1) begin
      case (i)
        0: begin rst = 1'b1; en = 1'b0; d = 1'b0; end
        1: begin rst = 1'b0; en = 1'b1; d = 1'b1; end
        2: begin rst = 1'b0; en = 1'b0; d = 1'b0; end
        3: begin rst = 1'b0; en = 1'b1; d = 1'b0; end
        4: begin rst = 1'b0; en = 1'b0; d = 1'b1; end
        5: begin rst = 1'b0; en = 1'b1; d = 1'b1; end
        default: begin rst = 1'b1; en = 1'b1; d = 1'b1; end
      endcase
      @(posedge clk);
      #1;
      $fdisplay(fd, "%0d,%b,%b,%b,%b", i, rst, en, d, q);
    end
    $fclose(fd);
    $finish;
  end
endmodule
