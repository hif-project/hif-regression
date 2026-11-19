`timescale 1ns/1ps
module shift_chain_contexts_tb;
  reg signed [7:0] s;
  reg [2:0] n;
  wire signed [7:0] chain;
  wire signed [7:0] wide;
  integer fd;
  reg [4095:0] tracefile;

  shift_chain_contexts dut (.s(s), .n(n), .chain(chain), .wide(wide));

  task step;
    input [7:0] v_s;
    input [2:0] v_n;
    begin
      s = v_s;
      n = v_n;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d", $time, s, n, chain, wide);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,s,n,chain,wide");

    step(8'd0, 3'd7);
    step(8'd1, 3'd7);
    step(8'd128, 3'd5);
    step(8'd127, 3'd2);
    step(8'd255, 3'd7);
    step(8'd85, 3'd0);
    step(8'd170, 3'd0);
    step(8'd15, 3'd1);
    step(8'd240, 3'd0);
    step(8'd67, 3'd3);
    step(8'd159, 3'd2);
    step(8'd85, 3'd7);
    step(8'd181, 3'd7);
    step(8'd182, 3'd3);
    step(8'd220, 3'd1);
    step(8'd175, 3'd5);
    step(8'd196, 3'd6);
    step(8'd33, 3'd2);
    step(8'd236, 3'd1);
    step(8'd148, 3'd5);
    step(8'd16, 3'd0);
    step(8'd240, 3'd6);
    step(8'd44, 3'd0);
    step(8'd230, 3'd1);
    step(8'd112, 3'd5);
    step(8'd60, 3'd2);
    step(8'd58, 3'd0);
    step(8'd50, 3'd6);
    step(8'd72, 3'd1);
    step(8'd177, 3'd3);
    step(8'd154, 3'd2);
    step(8'd123, 3'd4);
    step(8'd225, 3'd3);
    step(8'd169, 3'd7);
    step(8'd106, 3'd1);
    step(8'd215, 3'd0);
    step(8'd77, 3'd2);
    step(8'd71, 3'd1);
    step(8'd144, 3'd5);
    step(8'd187, 3'd2);
    step(8'd134, 3'd0);
    step(8'd126, 3'd1);
    step(8'd228, 3'd1);
    step(8'd200, 3'd3);
    step(8'd45, 3'd4);
    step(8'd217, 3'd1);
    step(8'd81, 3'd2);
    step(8'd192, 3'd5);

    $fclose(fd);
    $finish;
  end
endmodule
