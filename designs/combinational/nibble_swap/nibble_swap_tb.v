// Stimulus for nibble_swap, shared by the reference and the instrumented
// compile. The activation port exists only in the instrumented netlist, so it
// is connected under `ifdef MUFFIN_MUT, which the simulation supplies.
//
// The four vectors are chosen so each injected fault is detected on some and
// invisible on others. The all-zero and all-one vectors bracket every bit, and
// the two half-patterns put a 1 in exactly one nibble - which is what makes a
// fault confined to one half of `y` distinguishable from one that moved the
// whole vector.
`timescale 1ns/1ps
module nibble_swap_tb;
  reg [7:0] a;
  wire [7:0] y;
  integer mut;
  integer fd;
  reg [4095:0] tracefile;

  nibble_swap dut (
    .a(a), .y(y)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  task step;
    input [7:0] va;
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

    step(8'b00000000);
    step(8'b11111111);
    step(8'b11110000);
    step(8'b00001111);

    $fclose(fd);
    $finish;
  end
endmodule
