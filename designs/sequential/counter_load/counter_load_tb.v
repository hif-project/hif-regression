// Reset, two free-running increments, a parallel load, then four more
// increments - so a fault on the count register keeps re-applying every cycle
// and its effect compounds through the counter's own feedback.
`timescale 1ns/1ps
module counter_load_tb;
  reg clk, rst, load;
  reg [3:0] din;
  wire [3:0] count;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  counter_load dut (
    .clk(clk), .rst(rst), .load(load), .din(din), .count(count)
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
    $fdisplay(fd, "cycle,rst,load,din,count");
    for (i = 0; i < 8; i = i + 1) begin
      case (i)
        0:       begin rst = 1'b1; load = 1'b0; din = 4'h0; end
        3:       begin rst = 1'b0; load = 1'b1; din = 4'h9; end
        default: begin rst = 1'b0; load = 1'b0; din = 4'h0; end
      endcase
      @(posedge clk);
      #1;
      $fdisplay(fd, "%0d,%b,%b,%h,%h", i, rst, load, din, count);
    end
    $fclose(fd);
    $finish;
  end
endmodule
