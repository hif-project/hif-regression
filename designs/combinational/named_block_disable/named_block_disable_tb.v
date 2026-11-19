`timescale 1ns/1ps
module named_block_disable_tb;
  reg [7:0] d;
  wire [2:0] first_set;
  wire found;
  integer fd;
  reg [4095:0] tracefile;

  named_block_disable dut (.d(d), .first_set(first_set), .found(found));

  task step;
    input [7:0] x;
    begin
      d = x;
      #1 $fdisplay(fd, "%0t,%b,%0d,%b", $time, d, first_set, found);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,d,first_set,found");

    step(8'b0000_0000);
    step(8'b1001_0110);
    step(8'b0000_0001);
    step(8'b1000_0000);
    step(8'b1111_1111);
    step(8'b0101_0100);

    $fclose(fd);
    $finish;
  end
endmodule
