`timescale 1ns/1ps
module descending_offset_vectors_tb;
  reg [7:0] p;
  reg signed [7:0] sp;
  wire [3:0] hi;
  wire [3:0] lo;
  wire signed [11:0] wide;
  wire [0:0] bit5;
  integer fd;
  reg [4095:0] tracefile;

  descending_offset_vectors dut (.p(p), .sp(sp), .hi(hi), .lo(lo), .wide(wide), .bit5(bit5));

  task step;
    input [7:0] v_p;
    input [7:0] v_sp;
    begin
      p = v_p;
      sp = v_sp;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d,%0d,%0d", $time, p, sp, hi, lo, wide, bit5);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,p,sp,hi,lo,wide,bit5");

    step(8'd0, 8'd127);
    step(8'd1, 8'd255);
    step(8'd128, 8'd85);
    step(8'd127, 8'd170);
    step(8'd255, 8'd15);
    step(8'd85, 8'd240);
    step(8'd170, 8'd0);
    step(8'd15, 8'd1);
    step(8'd240, 8'd128);
    step(8'd120, 8'd46);
    step(8'd186, 8'd148);
    step(8'd77, 8'd51);
    step(8'd227, 8'd185);
    step(8'd104, 8'd193);
    step(8'd183, 8'd194);
    step(8'd67, 8'd136);
    step(8'd62, 8'd162);
    step(8'd208, 8'd188);
    step(8'd127, 8'd90);
    step(8'd106, 8'd134);
    step(8'd186, 8'd157);
    step(8'd246, 8'd55);
    step(8'd79, 8'd139);
    step(8'd180, 8'd84);
    step(8'd132, 8'd19);
    step(8'd187, 8'd198);
    step(8'd255, 8'd221);
    step(8'd52, 8'd176);
    step(8'd192, 8'd186);
    step(8'd119, 8'd236);
    step(8'd181, 8'd212);
    step(8'd223, 8'd167);
    step(8'd37, 8'd136);
    step(8'd54, 8'd222);
    step(8'd105, 8'd250);
    step(8'd14, 8'd197);
    step(8'd89, 8'd160);
    step(8'd106, 8'd119);
    step(8'd31, 8'd185);
    step(8'd190, 8'd35);
    step(8'd195, 8'd83);
    step(8'd99, 8'd84);
    step(8'd88, 8'd203);
    step(8'd51, 8'd83);
    step(8'd109, 8'd106);
    step(8'd81, 8'd145);
    step(8'd54, 8'd231);
    step(8'd222, 8'd104);

    $fclose(fd);
    $finish;
  end
endmodule
