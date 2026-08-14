// Runs the machine around its cycle twice, with `go` deasserted on the second
// pass at the point where it mattered on the first - so the Mealy output
// differs between the two passes while the Moore output does not.
`timescale 1ns/1ps
module fsm_moore_mealy_tb;
  reg clk, rst, go;
  wire [1:0] state;
  wire moore, mealy;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  fsm_moore_mealy dut (
    .clk(clk), .rst(rst), .go(go), .state(state), .moore(moore), .mealy(mealy)
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
    $fdisplay(fd, "cycle,rst,go,state,moore,mealy");
    for (i = 0; i < 7; i = i + 1) begin
      case (i)
        0:       begin rst = 1'b1; go = 1'b0; end
        1:       begin rst = 1'b0; go = 1'b1; end
        2:       begin rst = 1'b0; go = 1'b1; end
        3:       begin rst = 1'b0; go = 1'b0; end
        4:       begin rst = 1'b0; go = 1'b1; end
        default: begin rst = 1'b0; go = 1'b0; end
      endcase
      @(posedge clk);
      #1;
      $fdisplay(fd, "%0d,%b,%b,%0d,%b,%b", i, rst, go, state, moore, mealy);
    end
    $fclose(fd);
    $finish;
  end
endmodule
