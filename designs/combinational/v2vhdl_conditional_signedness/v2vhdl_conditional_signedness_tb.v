`timescale 1ns/1ps
module v2vhdl_conditional_signedness_tb;
  reg [7:0] a;
  reg signed [3:0] t;
  reg [2:0] n;
  wire [7:0] y;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_conditional_signedness dut (.a(a), .t(t), .n(n), .y(y));

  task step;
    input [7:0] v_a;
    input [3:0] v_t;
    input [2:0] v_n;
    begin
      a = v_a;
      t = v_t;
      n = v_n;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d", $time, a, t, n, y);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,t,n,y");

    step(8'd0, 4'd15, 3'd2);
    step(8'd1, 4'd15, 3'd7);
    step(8'd128, 4'd5, 3'd0);
    step(8'd127, 4'd10, 3'd0);
    step(8'd255, 4'd15, 3'd1);
    step(8'd85, 4'd0, 3'd0);
    step(8'd170, 4'd0, 3'd7);
    step(8'd15, 4'd1, 3'd7);
    step(8'd240, 4'd0, 3'd5);
    step(8'd120, 4'd2, 3'd5);
    step(8'd148, 4'd4, 3'd1);
    step(8'd227, 4'd11, 3'd3);
    step(8'd193, 4'd11, 3'd6);
    step(8'd67, 4'd8, 3'd1);
    step(8'd162, 4'd13, 3'd5);
    step(8'd127, 4'd5, 3'd3);
    step(8'd134, 4'd11, 3'd4);
    step(8'd246, 4'd3, 3'd2);
    step(8'd139, 4'd11, 3'd2);
    step(8'd132, 4'd1, 3'd5);
    step(8'd198, 4'd15, 3'd6);
    step(8'd52, 4'd11, 3'd6);
    step(8'd186, 4'd7, 3'd7);
    step(8'd181, 4'd13, 3'd6);
    step(8'd167, 4'd2, 3'd4);
    step(8'd54, 4'd13, 3'd3);
    step(8'd250, 4'd0, 3'd6);
    step(8'd89, 4'd10, 3'd3);
    step(8'd119, 4'd1, 3'd5);
    step(8'd190, 4'd2, 3'd6);
    step(8'd83, 4'd6, 3'd2);
    step(8'd88, 4'd12, 3'd1);
    step(8'd83, 4'd6, 3'd3);
    step(8'd81, 4'd9, 3'd1);
    step(8'd231, 4'd13, 3'd3);
    step(8'd58, 4'd3, 3'd0);
    step(8'd191, 4'd3, 3'd6);
    step(8'd4, 4'd15, 3'd6);
    step(8'd66, 4'd13, 3'd4);
    step(8'd81, 4'd12, 3'd7);
    step(8'd145, 4'd12, 3'd5);
    step(8'd107, 4'd9, 3'd0);
    step(8'd84, 4'd13, 3'd5);
    step(8'd155, 4'd12, 3'd1);
    step(8'd60, 4'd15, 3'd3);
    step(8'd93, 4'd2, 3'd1);
    step(8'd94, 4'd7, 3'd4);
    step(8'd214, 4'd10, 3'd1);

    $fclose(fd);
    $finish;
  end
endmodule
