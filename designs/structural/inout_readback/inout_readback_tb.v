// The testbench is the other device on the pin. Without one, this design reads
// back only its own driver and a broken read-back is indistinguishable from a
// correct one.
//
//   oe  tb drives   bus     sensed   what the row states
//    1     no       1010     1010    this design drives and senses its own value
//    0     yes      0110     0110    it released; the pin carries the other device
//    0     no       zzzz     zzzz    nobody drives
//    1     no       0011     0011    it drives again, a different value
//
// Row two is the design. It is the only row where the pin carries something
// this design did not put there, and therefore the only row that can tell a
// read of the net from a read of its own driver.
`timescale 1ns/1ps
module inout_readback_tb;
  reg [3:0] d, tb_drv;
  reg oe, tb_oe;
  wire [3:0] bus, sensed;
  integer fd;
  reg [4095:0] tracefile;

  inout_readback dut (.d(d), .oe(oe), .bus(bus), .sensed(sensed));

  // The other device on the pin.
  assign bus = tb_oe ? tb_drv : 4'bzzzz;

  task step;
    input [3:0] xd;
    input xoe;
    input [3:0] xtb;
    input xtboe;
    begin
      d      = xd;
      oe     = xoe;
      tb_drv = xtb;
      tb_oe  = xtboe;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b", $time, d, oe, tb_drv, tb_oe, bus, sensed);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,d,oe,tb_drv,tb_oe,bus,sensed");

    step(4'b1010, 1'b1, 4'b0000, 1'b0);
    step(4'b1010, 1'b0, 4'b0110, 1'b1);
    step(4'b1010, 1'b0, 4'b0000, 1'b0);
    step(4'b0011, 1'b1, 4'b0000, 1'b0);

    $fclose(fd);
    $finish;
  end
endmodule
