`timescale 1ns/1ps
module ascending_vectors_tb;
  reg [0:7] a;
  reg [0:3] b;
  reg [11:4] c;
  reg signed [2:9] sp;
  wire [0:3] trunc_up;
  wire [0:7] widen_up, sum_up;
  wire [3:0] trunc_offset;
  wire signed [11:0] sext_up;
  integer fd;
  reg [4095:0] tracefile;

  ascending_vectors dut (.a(a), .b(b), .c(c), .sp(sp), .trunc_up(trunc_up), .widen_up(widen_up), .sum_up(sum_up), .trunc_offset(trunc_offset), .sext_up(sext_up));

  task step;
    input [7:0] va;
    input [3:0] vb;
    input [7:0] vc;
    input [7:0] vsp;
    begin
      a = va;
      b = vb;
      c = vc;
      sp = vsp;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b,%b,%b,%b", $time, a, b, c, sp, trunc_up, widen_up, sum_up, trunc_offset, sext_up);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,c,sp,trunc_up,widen_up,sum_up,trunc_offset,sext_up");

    step(8'd255, 4'd15, 8'd255, 8'd3);
    step(8'd0, 4'd0, 8'd0, 8'd120);
    step(8'd129, 4'd9, 8'd129, 8'd28);
    step(8'd126, 4'd6, 8'd126, 8'd195);
    step(8'd126, 4'd0, 8'd208, 8'd100);
    step(8'd120, 4'd2, 8'd39, 8'd36);
    step(8'd146, 4'd12, 8'd172, 8'd175);
    step(8'd121, 4'd1, 8'd6, 8'd11);
    step(8'd32, 4'd8, 8'd36, 8'd35);
    step(8'd46, 4'd5, 8'd31, 8'd243);
    step(8'd43, 4'd11, 8'd60, 8'd28);
    step(8'd221, 4'd11, 8'd145, 8'd137);
    step(8'd171, 4'd10, 8'd59, 8'd59);
    step(8'd232, 4'd7, 8'd15, 8'd182);
    step(8'd233, 4'd4, 8'd86, 8'd193);
    step(8'd1, 4'd5, 8'd228, 8'd35);
    step(8'd43, 4'd8, 8'd86, 8'd37);
    step(8'd172, 4'd5, 8'd155, 8'd251);
    step(8'd100, 4'd6, 8'd82, 8'd189);
    step(8'd188, 4'd4, 8'd201, 8'd8);
    step(8'd42, 4'd5, 8'd153, 8'd169);
    step(8'd143, 4'd7, 8'd68, 8'd15);
    step(8'd112, 4'd1, 8'd207, 8'd34);
    step(8'd225, 4'd11, 8'd216, 8'd59);
    step(8'd122, 4'd4, 8'd42, 8'd137);
    step(8'd249, 4'd9, 8'd42, 8'd187);
    step(8'd233, 4'd4, 8'd123, 8'd114);
    step(8'd71, 4'd14, 8'd21, 8'd134);
    step(8'd226, 4'd1, 8'd186, 8'd105);
    step(8'd96, 4'd13, 8'd110, 8'd52);
    step(8'd170, 4'd15, 8'd119, 8'd255);
    step(8'd120, 4'd3, 8'd126, 8'd151);
    step(8'd57, 4'd1, 8'd158, 8'd23);
    step(8'd114, 4'd6, 8'd139, 8'd30);
    step(8'd221, 4'd6, 8'd56, 8'd5);
    step(8'd223, 4'd3, 8'd93, 8'd197);
    step(8'd182, 4'd3, 8'd135, 8'd240);
    step(8'd97, 4'd1, 8'd232, 8'd227);
    step(8'd79, 4'd14, 8'd201, 8'd103);
    step(8'd15, 4'd8, 8'd55, 8'd87);
    step(8'd25, 4'd6, 8'd2, 8'd50);
    step(8'd190, 4'd0, 8'd188, 8'd52);
    step(8'd142, 4'd6, 8'd152, 8'd84);
    step(8'd170, 4'd9, 8'd52, 8'd100);
    step(8'd203, 4'd15, 8'd64, 8'd93);
    step(8'd179, 4'd13, 8'd109, 8'd152);
    step(8'd124, 4'd15, 8'd55, 8'd244);
    step(8'd236, 4'd6, 8'd90, 8'd63);

    $fclose(fd);
    $finish;
  end
endmodule
