// Stimulus for mask_invert, shared by the reference and the instrumented
// compile. The activation port exists only in the instrumented netlist.
//
// The four vectors are chosen around bit 3, the bit both injections target.
// Two of them leave sel[3] low and two drive it high, so each fault is visible
// on exactly the vectors where the fault-free value disagrees with it - and the
// two faults end up moving disjoint rows, which is what shows they are
// different points in the dataflow rather than one point named twice.
`timescale 1ns/1ps
module mask_invert_tb;
  reg [7:0] data, mask;
  wire [7:0] y;
  integer mut;
  integer fd;
  reg [4095:0] tracefile;

  mask_invert dut (
    .data(data), .mask(mask), .y(y)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  task step;
    input [7:0] vd;
    input [7:0] vm;
    begin
      data = vd;
      mask = vm;
      #5 $fdisplay(fd, "%0t,%b,%b,%b", $time, data, mask, y);
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
    $fdisplay(fd, "time,data,mask,y");

    step(8'b11111111, 8'b11111111);
    step(8'b11111111, 8'b00000000);
    step(8'b10101010, 8'b11001100);
    step(8'b01010101, 8'b11110000);

    $fclose(fd);
    $finish;
  end
endmodule
