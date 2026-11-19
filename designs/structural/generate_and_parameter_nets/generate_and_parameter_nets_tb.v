`timescale 1ns/1ps
module generate_and_parameter_nets_tb;
  reg [3:0] en;
  reg [3:0] a;
  reg [0:0] en2;
  reg [0:0] b;
  reg [0:0] ae;
  reg [0:0] be;
  wire [3:0] partial_gen;
  wire [3:0] shared_gen;
  wire [3:0] shared_param;
  integer fd;
  reg [4095:0] tracefile;

  generate_and_parameter_nets dut (.en(en), .a(a), .en2(en2), .b(b), .ae(ae), .be(be), .partial_gen(partial_gen), .shared_gen(shared_gen), .shared_param(shared_param));

  task step;
    input [3:0] v_en;
    input [3:0] v_a;
    input [0:0] v_en2;
    input [0:0] v_b;
    input [0:0] v_ae;
    input [0:0] v_be;
    begin
      en = v_en;
      a = v_a;
      en2 = v_en2;
      b = v_b;
      ae = v_ae;
      be = v_be;
      #1 $fdisplay(fd, "%0t,%b,%b,%b,%b,%b,%b,%b,%b,%b", $time, en, a, en2, b, ae, be, partial_gen, shared_gen, shared_param);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,en,a,en2,b,ae,be,partial_gen,shared_gen,shared_param");

    step(4'd2, 4'd15, 1'd0, 1'd0, 1'd0, 1'd0);
    step(4'd15, 4'd15, 1'd1, 1'd1, 1'd0, 1'd0);
    step(4'd2, 4'd5, 1'd0, 1'd0, 1'd1, 1'd0);
    step(4'd15, 4'd10, 1'd1, 1'd1, 1'd1, 1'd0);
    step(4'd2, 4'd15, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd15, 4'd0, 1'd1, 1'd1, 1'd0, 1'd1);
    step(4'd2, 4'd0, 1'd0, 1'd0, 1'd1, 1'd1);
    step(4'd15, 4'd1, 1'd1, 1'd1, 1'd1, 1'd1);
    step(4'd0, 4'd0, 1'd1, 1'd0, 1'd0, 1'd1);
    step(4'd7, 4'd2, 1'd1, 1'd1, 1'd0, 1'd0);
    step(4'd14, 4'd11, 1'd0, 1'd1, 1'd1, 1'd1);
    step(4'd4, 4'd8, 1'd0, 1'd1, 1'd1, 1'd1);
    step(4'd7, 4'd5, 1'd0, 1'd1, 1'd1, 1'd1);
    step(4'd15, 4'd3, 1'd0, 1'd1, 1'd1, 1'd0);
    step(4'd8, 4'd1, 1'd1, 1'd1, 1'd1, 1'd1);
    step(4'd3, 4'd11, 1'd1, 1'd1, 1'd0, 1'd1);
    step(4'd11, 4'd13, 1'd1, 1'd1, 1'd0, 1'd1);
    step(4'd3, 4'd13, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd5, 4'd10, 1'd0, 1'd0, 1'd0, 1'd1);
    step(4'd11, 4'd2, 1'd1, 1'd0, 1'd0, 1'd0);
    step(4'd5, 4'd12, 1'd0, 1'd0, 1'd0, 1'd0);
    step(4'd5, 4'd9, 1'd0, 1'd1, 1'd1, 1'd0);
    step(4'd3, 4'd3, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd0, 4'd15, 1'd1, 1'd0, 1'd1, 1'd1);
    step(4'd5, 4'd12, 1'd1, 1'd1, 1'd1, 1'd1);
    step(4'd6, 4'd9, 1'd0, 1'd0, 1'd1, 1'd1);
    step(4'd9, 4'd12, 1'd0, 1'd0, 1'd1, 1'd0);
    step(4'd5, 4'd2, 1'd0, 1'd0, 1'd0, 1'd1);
    step(4'd13, 4'd10, 1'd0, 1'd0, 1'd0, 1'd1);
    step(4'd5, 4'd5, 1'd1, 1'd1, 1'd1, 1'd1);
    step(4'd7, 4'd13, 1'd0, 1'd1, 1'd1, 1'd1);
    step(4'd13, 4'd2, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd10, 4'd1, 1'd0, 1'd1, 1'd1, 1'd0);
    step(4'd0, 4'd14, 1'd0, 1'd0, 1'd1, 1'd0);
    step(4'd5, 4'd3, 1'd0, 1'd0, 1'd1, 1'd0);
    step(4'd3, 4'd11, 1'd0, 1'd1, 1'd0, 1'd0);
    step(4'd8, 4'd14, 1'd0, 1'd1, 1'd1, 1'd0);
    step(4'd3, 4'd13, 1'd0, 1'd0, 1'd0, 1'd0);
    step(4'd2, 4'd9, 1'd1, 1'd1, 1'd0, 1'd1);
    step(4'd1, 4'd7, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd6, 4'd2, 1'd1, 1'd1, 1'd0, 1'd0);
    step(4'd5, 4'd12, 1'd1, 1'd1, 1'd1, 1'd0);
    step(4'd9, 4'd14, 1'd1, 1'd1, 1'd1, 1'd0);
    step(4'd14, 4'd11, 1'd1, 1'd1, 1'd1, 1'd0);
    step(4'd1, 4'd3, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd13, 4'd3, 1'd1, 1'd1, 1'd1, 1'd1);
    step(4'd1, 4'd15, 1'd1, 1'd0, 1'd0, 1'd0);
    step(4'd9, 4'd12, 1'd1, 1'd0, 1'd0, 1'd0);
    step(4'd2, 4'd9, 1'd0, 1'd1, 1'd1, 1'd1);
    step(4'd8, 4'd12, 1'd1, 1'd1, 1'd1, 1'd0);
    step(4'd9, 4'd1, 1'd1, 1'd0, 1'd1, 1'd1);
    step(4'd5, 4'd0, 1'd0, 1'd0, 1'd0, 1'd0);
    step(4'd0, 4'd1, 1'd1, 1'd1, 1'd1, 1'd1);
    step(4'd9, 4'd11, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd3, 4'd7, 1'd0, 1'd0, 1'd0, 1'd0);
    step(4'd11, 4'd7, 1'd1, 1'd0, 1'd1, 1'd1);
    step(4'd12, 4'd13, 1'd0, 1'd0, 1'd1, 1'd1);
    step(4'd7, 4'd13, 1'd0, 1'd1, 1'd1, 1'd0);
    step(4'd14, 4'd3, 1'd0, 1'd0, 1'd0, 1'd0);
    step(4'd12, 4'd2, 1'd0, 1'd0, 1'd1, 1'd0);
    step(4'd1, 4'd5, 1'd1, 1'd0, 1'd1, 1'd0);
    step(4'd12, 4'd8, 1'd0, 1'd1, 1'd1, 1'd0);
    step(4'd3, 4'd9, 1'd0, 1'd1, 1'd0, 1'd1);
    step(4'd12, 4'd0, 1'd0, 1'd0, 1'd0, 1'd1);

    $fclose(fd);
    $finish;
  end
endmodule
