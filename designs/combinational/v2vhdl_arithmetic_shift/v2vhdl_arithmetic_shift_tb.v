`timescale 1ns/1ps
module v2vhdl_arithmetic_shift_tb;
  reg signed [7:0] s;
  reg [7:0] u;
  reg [2:0] n;
  wire signed [7:0] sr, sl, sr1, sl1;
  wire [7:0] ur;
  wire [8:0] nested;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_arithmetic_shift dut (.s(s), .u(u), .n(n), .sr(sr), .sl(sl), .ur(ur), .sr1(sr1), .sl1(sl1), .nested(nested));

  task step;
    input [7:0] vs;
    input [7:0] vu;
    input [2:0] vn;
    begin
      s = vs;
      u = vu;
      n = vn;
      #1 $fdisplay(fd, "%0t,%b,%b,%0d,%b,%b,%b,%b,%b,%b", $time, s, u, n, sr, sl, ur, sr1, sl1, nested);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,s,u,n,sr,sl,ur,sr1,sl1,nested");

    step(8'd128, 8'd129, 3'd0);
    step(8'd129, 8'd255, 3'd1);
    step(8'd127, 8'd85, 3'd2);
    step(8'd255, 8'd1, 3'd3);
    step(8'd240, 8'd128, 3'd4);
    step(8'd85, 8'd127, 3'd5);
    step(8'd170, 8'd240, 3'd6);
    step(8'd1, 8'd170, 3'd7);
    step(8'd0, 8'd0, 3'd0);
    step(8'd204, 8'd64, 3'd2);
    step(8'd50, 8'd61, 3'd1);
    step(8'd210, 8'd240, 3'd0);
    step(8'd74, 8'd121, 3'd7);
    step(8'd142, 8'd255, 3'd4);
    step(8'd60, 8'd37, 3'd4);
    step(8'd161, 8'd169, 3'd4);
    step(8'd0, 8'd217, 3'd2);
    step(8'd7, 8'd213, 3'd7);
    step(8'd127, 8'd44, 3'd6);
    step(8'd208, 8'd48, 3'd4);
    step(8'd255, 8'd213, 3'd3);
    step(8'd46, 8'd84, 3'd2);
    step(8'd30, 8'd22, 3'd4);
    step(8'd199, 8'd66, 3'd4);
    step(8'd120, 8'd52, 3'd1);
    step(8'd49, 8'd18, 3'd0);
    step(8'd216, 8'd51, 3'd5);
    step(8'd143, 8'd230, 3'd3);
    step(8'd152, 8'd180, 3'd4);
    step(8'd19, 8'd25, 3'd6);
    step(8'd205, 8'd251, 3'd5);
    step(8'd189, 8'd54, 3'd5);
    step(8'd84, 8'd217, 3'd0);
    step(8'd24, 8'd147, 3'd3);
    step(8'd211, 8'd20, 3'd7);
    step(8'd200, 8'd200, 3'd4);
    step(8'd249, 8'd27, 3'd2);
    step(8'd113, 8'd160, 3'd6);
    step(8'd235, 8'd141, 3'd7);
    step(8'd31, 8'd89, 3'd7);

    $fclose(fd);
    $finish;
  end
endmodule
