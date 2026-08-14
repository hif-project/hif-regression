// Pushes three distinct values in and then drains with zeros. Only dout is
// traced - the internal stages are deliberately not probed, so what is being
// checked is that a fault injected on an internal stage actually propagates to
// an observable output, and does so at the right cycle.
`timescale 1ns/1ps
module pipeline3_tb;
  reg clk, rst;
  reg [3:0] din;
  wire [3:0] dout;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  pipeline3 dut (
    .clk(clk), .rst(rst), .din(din), .dout(dout)
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
    $fdisplay(fd, "cycle,rst,din,dout");
    for (i = 0; i < 7; i = i + 1) begin
      case (i)
        0:       begin rst = 1'b1; din = 4'h0; end
        1:       begin rst = 1'b0; din = 4'h5; end
        2:       begin rst = 1'b0; din = 4'hA; end
        3:       begin rst = 1'b0; din = 4'h3; end
        default: begin rst = 1'b0; din = 4'h0; end
      endcase
      @(posedge clk);
      #1;
      $fdisplay(fd, "%0d,%b,%h,%h", i, rst, din, dout);
    end
    $fclose(fd);
    $finish;
  end
endmodule
