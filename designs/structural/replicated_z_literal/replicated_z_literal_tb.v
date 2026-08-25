// Drives the bus from the testbench as a second device, so that releasing the
// pin and driving it are distinguishable.
//
//   d     oe  tb_drv tb_oe   bus     what the row states
//   1010   1    0000    0    1010    this design drives, alone
//   1010   0    0110    1    0110    it released; the other device wins the pin
//   0011   1    0000    0    0011    it drives again, a different value
//   0011   0    0000    0    zzzz    nobody drives: the pin floats
//   1111   0    1001    1    1001    released again, other device again
//
// Row two and row five are the ones that need the second driver. A pad that
// drove 0, 1 or X where the source drives Z would collide with the testbench
// there and the bus would read x - and row four is what says the released
// value is Z and not merely "not the data".
`timescale 1ns/1ps
module replicated_z_literal_tb;
  reg [3:0] d;
  reg oe;
  reg [3:0] tb_drv;
  reg tb_oe;
  wire [3:0] bus;
  integer fd;
  reg [4095:0] tracefile;

  replicated_z_literal dut (.d(d), .oe(oe), .bus(bus));

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
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b", $time, d, oe, tb_drv, tb_oe, bus);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,d,oe,tb_drv,tb_oe,bus");

    step(4'b1010, 1'b1, 4'b0000, 1'b0);
    step(4'b1010, 1'b0, 4'b0110, 1'b1);
    step(4'b0011, 1'b1, 4'b0000, 1'b0);
    step(4'b0011, 1'b0, 4'b0000, 1'b0);
    step(4'b1111, 1'b0, 4'b1001, 1'b1);

    $fclose(fd);
    $finish;
  end
endmodule
