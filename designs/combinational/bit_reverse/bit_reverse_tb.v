// Stimulus for bit_reverse, shared by the reference and the instrumented
// compile. The activation port exists only in the instrumented netlist.
//
// The vectors are chosen so the three bits an injection must NOT touch carry
// real, differing values. Under an all-zero or all-one input a corrupted
// sibling is indistinguishable from a correct one, so 1010 and 1000 do the
// work: they put both values on the untouched bits while the injected bit is
// pinned.
`timescale 1ns/1ps
module bit_reverse_tb;
  reg [3:0] a;
  wire [3:0] y;
  integer mut;
  integer fd;
  reg [4095:0] tracefile;

  bit_reverse dut (
    .a(a), .y(y)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  task step;
    input [3:0] va;
    begin
      a = va;
      #5 $fdisplay(fd, "%0t,%b,%b", $time, a, y);
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
    $fdisplay(fd, "time,a,y");

    step(4'b0000);
    step(4'b1111);
    step(4'b1010);
    step(4'b1000);

    $fclose(fd);
    $finish;
  end
endmodule
