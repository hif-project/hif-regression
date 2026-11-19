`timescale 1ns/1ps
module shift_result_compare_tb;
  reg signed [7:0] s;
  wire [0:0] y;
  integer fd;
  reg [4095:0] tracefile;

  shift_result_compare dut (.s(s), .y(y));

  task step;
    input [7:0] v_s;
    begin
      s = v_s;
      #1 $fdisplay(fd, "%0t,%0d,%0d", $time, s, y);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,s,y");

    step(8'd0);
    step(8'd1);
    step(8'd128);
    step(8'd127);
    step(8'd255);
    step(8'd85);
    step(8'd170);
    step(8'd15);
    step(8'd240);
    step(8'd228);
    step(8'd204);
    step(8'd11);
    step(8'd148);
    step(8'd230);
    step(8'd238);
    step(8'd173);
    step(8'd139);
    step(8'd96);
    step(8'd239);
    step(8'd189);
    step(8'd184);
    step(8'd243);
    step(8'd162);
    step(8'd18);
    step(8'd30);
    step(8'd58);
    step(8'd14);
    step(8'd132);
    step(8'd32);
    step(8'd241);
    step(8'd212);
    step(8'd53);
    step(8'd232);
    step(8'd162);
    step(8'd157);
    step(8'd236);
    step(8'd22);
    step(8'd242);
    step(8'd129);
    step(8'd44);
    step(8'd60);
    step(8'd124);
    step(8'd149);
    step(8'd204);
    step(8'd187);
    step(8'd42);
    step(8'd41);
    step(8'd22);

    $fclose(fd);
    $finish;
  end
endmodule
