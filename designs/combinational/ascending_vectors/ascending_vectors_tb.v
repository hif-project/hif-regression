`timescale 1ns/1ps
module ascending_vectors_tb;
  reg [0:7] a;
  reg [0:3] b;
  reg [11:4] c;
  wire [0:3] trunc_up;
  wire [0:7] widen_up, sum_up;
  wire [3:0] trunc_offset;
  integer fd;
  reg [4095:0] tracefile;

  ascending_vectors dut (.a(a), .b(b), .c(c), .trunc_up(trunc_up), .widen_up(widen_up), .sum_up(sum_up), .trunc_offset(trunc_offset));

  task step;
    input [7:0] va;
    input [3:0] vb;
    input [7:0] vc;
    begin
      a = va;
      b = vb;
      c = vc;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b,%b", $time, a, b, c, trunc_up, widen_up, sum_up, trunc_offset);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,c,trunc_up,widen_up,sum_up,trunc_offset");

    step(8'd255, 4'd15, 8'd255);
    step(8'd0, 4'd0, 8'd0);
    step(8'd129, 4'd9, 8'd129);
    step(8'd126, 4'd6, 8'd126);
    step(8'd126, 4'd0, 8'd208);
    step(8'd120, 4'd2, 8'd39);
    step(8'd146, 4'd12, 8'd172);
    step(8'd121, 4'd1, 8'd6);
    step(8'd32, 4'd8, 8'd36);
    step(8'd46, 4'd5, 8'd31);
    step(8'd43, 4'd11, 8'd60);
    step(8'd221, 4'd11, 8'd145);
    step(8'd171, 4'd10, 8'd59);
    step(8'd232, 4'd7, 8'd15);
    step(8'd233, 4'd4, 8'd86);
    step(8'd1, 4'd5, 8'd228);
    step(8'd43, 4'd8, 8'd86);
    step(8'd172, 4'd5, 8'd155);
    step(8'd100, 4'd6, 8'd82);
    step(8'd188, 4'd4, 8'd201);
    step(8'd42, 4'd5, 8'd153);
    step(8'd143, 4'd7, 8'd68);
    step(8'd112, 4'd1, 8'd207);
    step(8'd225, 4'd11, 8'd216);
    step(8'd122, 4'd4, 8'd42);
    step(8'd249, 4'd9, 8'd42);
    step(8'd233, 4'd4, 8'd123);
    step(8'd71, 4'd14, 8'd21);
    step(8'd226, 4'd1, 8'd186);
    step(8'd96, 4'd13, 8'd110);
    step(8'd170, 4'd15, 8'd119);
    step(8'd120, 4'd3, 8'd126);
    step(8'd57, 4'd1, 8'd158);
    step(8'd114, 4'd6, 8'd139);
    step(8'd221, 4'd6, 8'd56);
    step(8'd223, 4'd3, 8'd93);
    step(8'd182, 4'd3, 8'd135);
    step(8'd97, 4'd1, 8'd232);
    step(8'd79, 4'd14, 8'd201);
    step(8'd15, 4'd8, 8'd55);
    step(8'd25, 4'd6, 8'd2);
    step(8'd190, 4'd0, 8'd188);
    step(8'd142, 4'd6, 8'd152);
    step(8'd170, 4'd9, 8'd52);
    step(8'd203, 4'd15, 8'd64);
    step(8'd179, 4'd13, 8'd109);
    step(8'd124, 4'd15, 8'd55);
    step(8'd236, 4'd6, 8'd90);

    $fclose(fd);
    $finish;
  end
endmodule
