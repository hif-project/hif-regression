`timescale 1ns/1ps
module mixed_signedness_add_tb;
  reg [7:0] a;
  reg signed [7:0] b, c;
  wire [8:0] mixed;
  wire signed [8:0] both_signed;
  integer fd;
  reg [4095:0] tracefile;

  mixed_signedness_add dut (.a(a), .b(b), .c(c), .mixed(mixed), .both_signed(both_signed));

  task step;
    input [7:0] xa;
    input [7:0] xb;
    input [7:0] xc;
    begin
      a = xa;
      b = xb;
      c = xc;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d,%0d", $time, a, b, c, mixed, both_signed);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,c,mixed,both_signed");

    step(8'd0, 8'd0, 8'd0);
    step(8'd36, 8'd129, 8'd255);
    step(8'd255, 8'd255, 8'd128);
    step(8'd1, 8'd255, 8'd127);
    step(8'd200, 8'd156, 8'd156);
    step(8'd128, 8'd127, 8'd128);
    step(8'd0, 8'd128, 8'd128);
    step(8'd255, 8'd127, 8'd127);
    step(8'd100, 8'd206, 8'd50);

    $fclose(fd);
    $finish;
  end
endmodule
