// Four steps, enough to state every replication in the design.
//
//   d=1011 sel=0   mask=1111  y=0000  wide=00001111
//   d=1011 sel=1   mask=1111  y=1011  wide=00001111
//   d=0100 sel=1   mask=1111  y=0100  wide=00001111
//   d=1111 sel=0   mask=1111  y=0000  wide=00001111
//
// `mask` and `wide` never move - they are constants, and the claim about them
// is that they are the *right* constants, four ones and four zeros above four
// ones, in a design where they were built by replication rather than written
// out. `y` moves with both inputs, so the replication of a signal is pinned by
// the rows where sel is high and by the rows where it is not.
`timescale 1ns/1ps
module replicated_bit_literal_tb;
  reg [3:0] d;
  reg sel;
  wire [3:0] mask, y;
  wire [7:0] wide;
  integer fd;
  reg [4095:0] tracefile;

  replicated_bit_literal dut (.d(d), .sel(sel), .mask(mask), .y(y), .wide(wide));

  task step;
    input [3:0] xd;
    input xsel;
    begin
      d = xd;
      sel = xsel;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b", $time, d, sel, mask, y, wide);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,d,sel,mask,y,wide");

    step(4'b1011, 1'b0);
    step(4'b1011, 1'b1);
    step(4'b0100, 1'b1);
    step(4'b1111, 1'b0);

    $fclose(fd);
    $finish;
  end
endmodule
