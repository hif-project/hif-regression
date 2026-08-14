// Reset, then count with the enable toggled, so both the increment and the
// hold path are exercised at the default parameter width.
`timescale 1ns/1ps
module param_counter_tb;
  reg clk, rst, en;
  wire [3:0] count;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  param_counter dut (
    .clk(clk), .rst(rst), .en(en), .count(count)
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
    $fdisplay(fd, "cycle,rst,en,count");
    for (i = 0; i < 8; i = i + 1) begin
      case (i)
        0:       begin rst = 1'b1; en = 1'b0; end
        4:       begin rst = 1'b0; en = 1'b0; end
        default: begin rst = 1'b0; en = 1'b1; end
      endcase
      @(posedge clk);
      #1;
      $fdisplay(fd, "%0d,%b,%b,%h", i, rst, en, count);
    end
    $fclose(fd);
    $finish;
  end
endmodule
