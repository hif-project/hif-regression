// Stimulus for nibble_popcount, shared by the reference and the instrumented
// compile. The activation port exists only in the instrumented netlist.
//
// The vectors give the two nibbles different populations on three of the four
// rows, which is what lets a fault on the shared function result be told apart
// from one on a single call's assignment: the shared fault has to move `hi` as
// well as `lo`, and `hi` can only be seen to move where its own value is not
// already what the fault forces.
`timescale 1ns/1ps
module nibble_popcount_tb;
  reg [7:0] a;
  wire [2:0] lo, hi;
  integer mut;
  integer fd;
  reg [4095:0] tracefile;

  nibble_popcount dut (
    .a(a), .lo(lo), .hi(hi)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  task step;
    input [7:0] va;
    begin
      a = va;
      #5 $fdisplay(fd, "%0t,%b,%b,%b", $time, a, lo, hi);
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
    $fdisplay(fd, "time,a,lo,hi");

    step(8'b00000000);
    step(8'b11111111);
    step(8'b00010111);
    step(8'b11110000);

    $fclose(fd);
    $finish;
  end
endmodule
