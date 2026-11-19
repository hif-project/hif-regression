`timescale 1ns/1ps
module signedness_contexts_tb;
  reg [7:0] a;
  reg signed [7:0] s;
  reg signed [3:0] t;
  reg [3:0] u;
  reg [3:0] n;
  wire [0:0] r_lt;
  wire [0:0] r_gt;
  wire [0:0] r_eq;
  wire [7:0] mux;
  wire [8:0] nest;
  wire [7:0] shr_s;
  wire [3:0] shr_t;
  wire [0:0] s_lt_t;
  wire [0:0] t_lt_0;
  integer fd;
  reg [4095:0] tracefile;

  signedness_contexts dut (.a(a), .s(s), .t(t), .u(u), .n(n), .r_lt(r_lt), .r_gt(r_gt), .r_eq(r_eq), .mux(mux), .nest(nest), .shr_s(shr_s), .shr_t(shr_t), .s_lt_t(s_lt_t), .t_lt_0(t_lt_0));

  task step;
    input [7:0] v_a;
    input [7:0] v_s;
    input [3:0] v_t;
    input [3:0] v_u;
    input [3:0] v_n;
    begin
      a = v_a;
      s = v_s;
      t = v_t;
      u = v_u;
      n = v_n;
      #1 $fdisplay(fd, "%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d", $time, a, s, t, u, n, r_lt, r_gt, r_eq, mux, nest, shr_s, shr_t, s_lt_t, t_lt_0);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,s,t,u,n,r_lt,r_gt,r_eq,mux,nest,shr_s,shr_t,s_lt_t,t_lt_0");

    step(8'd0, 8'd127, 4'd10, 4'd0, 4'd15);
    step(8'd1, 8'd255, 4'd15, 4'd1, 4'd15);
    step(8'd128, 8'd85, 4'd0, 4'd0, 4'd5);
    step(8'd127, 8'd170, 4'd0, 4'd15, 4'd10);
    step(8'd255, 8'd15, 4'd1, 4'd15, 4'd15);
    step(8'd85, 8'd240, 4'd0, 4'd5, 4'd0);
    step(8'd170, 8'd0, 4'd15, 4'd10, 4'd0);
    step(8'd15, 8'd1, 4'd15, 4'd15, 4'd1);
    step(8'd240, 8'd128, 4'd5, 4'd0, 4'd0);
    step(8'd247, 8'd199, 4'd7, 4'd1, 4'd0);
    step(8'd23, 8'd233, 4'd15, 4'd15, 4'd12);
    step(8'd149, 8'd8, 4'd10, 4'd11, 4'd1);
    step(8'd25, 8'd196, 4'd5, 4'd3, 4'd0);
    step(8'd7, 8'd252, 4'd12, 4'd0, 4'd5);
    step(8'd165, 8'd159, 4'd7, 4'd9, 4'd7);
    step(8'd38, 8'd23, 4'd2, 4'd11, 4'd1);
    step(8'd216, 8'd3, 4'd8, 4'd7, 4'd14);
    step(8'd247, 8'd63, 4'd1, 4'd10, 4'd8);
    step(8'd233, 8'd119, 4'd1, 4'd9, 4'd10);
    step(8'd22, 8'd131, 4'd9, 4'd0, 4'd4);
    step(8'd211, 8'd142, 4'd1, 4'd10, 4'd4);
    step(8'd123, 8'd217, 4'd5, 4'd4, 4'd3);
    step(8'd167, 8'd238, 4'd3, 4'd7, 4'd14);
    step(8'd135, 8'd170, 4'd0, 4'd15, 4'd8);
    step(8'd18, 8'd1, 4'd5, 4'd2, 4'd11);
    step(8'd121, 8'd168, 4'd6, 4'd2, 4'd0);
    step(8'd19, 8'd150, 4'd7, 4'd2, 4'd1);
    step(8'd142, 8'd55, 4'd2, 4'd0, 4'd14);
    step(8'd88, 8'd197, 4'd1, 4'd15, 4'd8);
    step(8'd36, 8'd171, 4'd4, 4'd7, 4'd0);
    step(8'd106, 8'd70, 4'd10, 4'd12, 4'd0);
    step(8'd45, 8'd69, 4'd2, 4'd4, 4'd15);
    step(8'd216, 8'd39, 4'd12, 4'd13, 4'd7);
    step(8'd10, 8'd144, 4'd6, 4'd12, 4'd5);
    step(8'd126, 8'd87, 4'd9, 4'd13, 4'd7);
    step(8'd121, 8'd11, 4'd12, 4'd14, 4'd7);
    step(8'd222, 8'd209, 4'd9, 4'd14, 4'd2);
    step(8'd112, 8'd187, 4'd12, 4'd8, 4'd13);
    step(8'd112, 8'd75, 4'd4, 4'd1, 4'd12);
    step(8'd47, 8'd106, 4'd6, 4'd12, 4'd1);
    step(8'd240, 8'd135, 4'd1, 4'd13, 4'd13);
    step(8'd124, 8'd96, 4'd13, 4'd13, 4'd10);
    step(8'd65, 8'd164, 4'd3, 4'd5, 4'd1);
    step(8'd179, 8'd179, 4'd12, 4'd15, 4'd2);
    step(8'd148, 8'd232, 4'd15, 4'd4, 4'd15);
    step(8'd39, 8'd217, 4'd13, 4'd15, 4'd11);
    step(8'd82, 8'd203, 4'd12, 4'd7, 4'd11);
    step(8'd18, 8'd20, 4'd6, 4'd3, 4'd0);

    $fclose(fd);
    $finish;
  end
endmodule
