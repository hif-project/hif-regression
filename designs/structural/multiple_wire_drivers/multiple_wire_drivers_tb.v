// Each device drives alone, then neither does. That is the whole point: a net
// with two drivers only means anything when the drivers disagree about who is
// asserting.
//
//   a_en a     b_en b       bus     what the row states
//    1   1010   0   0101    1010    the a driver alone; b has released
//    0   1010   1   0101    0101    the b driver alone; a has released
//    0   1010   0   0101    zzzz    neither drives: the net floats
//    1   1111   0   0000    1111    a again, with a different value
//
// Rows one and four are where a reg with two writers fails: the released
// driver overwrites the asserting one and the bus reads zzzz. Row two survives
// by accident, because there the process that runs last is the asserting one.
`timescale 1ns/1ps
module multiple_wire_drivers_tb;
  reg a_en, b_en;
  reg [3:0] a, b;
  wire [3:0] bus;
  integer fd;
  reg [4095:0] tracefile;

  multiple_wire_drivers dut (.a_en(a_en), .a(a), .b_en(b_en), .b(b), .bus(bus));

  task step;
    input xae;
    input [3:0] xa;
    input xbe;
    input [3:0] xb;
    begin
      a_en = xae;
      a    = xa;
      b_en = xbe;
      b    = xb;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b", $time, a_en, a, b_en, b, bus);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a_en,a,b_en,b,bus");

    step(1'b1, 4'b1010, 1'b0, 4'b0101);
    step(1'b0, 4'b1010, 1'b1, 4'b0101);
    step(1'b0, 4'b1010, 1'b0, 4'b0101);
    step(1'b1, 4'b1111, 1'b0, 4'b0000);

    $fclose(fd);
    $finish;
  end
endmodule
