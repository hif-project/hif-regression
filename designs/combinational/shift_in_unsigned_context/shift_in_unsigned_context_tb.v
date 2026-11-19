`timescale 1ns/1ps
module shift_in_unsigned_context_tb;
  reg signed [7:0] s;
  reg [7:0] a;
  reg [2:0] n;
  wire [8:0] unsigned_ctx;
  wire [7:0] bare;
  integer fd;
  reg [4095:0] tracefile;

  shift_in_unsigned_context dut (.s(s), .a(a), .n(n), .unsigned_ctx(unsigned_ctx), .bare(bare));

  task step;
    input [7:0] vs;
    input [7:0] va;
    input [2:0] vn;
    begin
      s = vs;
      a = va;
      n = vn;
      #1 $fdisplay(fd, "%0t,%b,%b,%0d,%b,%b", $time, s, a, n, unsigned_ctx, bare);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,s,a,n,unsigned_ctx,bare");

    step(8'd128, 8'd129, 3'd0);
    step(8'd129, 8'd255, 3'd1);
    step(8'd127, 8'd85, 3'd2);
    step(8'd255, 8'd1, 3'd3);
    step(8'd240, 8'd128, 3'd4);
    step(8'd85, 8'd127, 3'd5);
    step(8'd170, 8'd240, 3'd6);
    step(8'd1, 8'd170, 3'd7);
    step(8'd0, 8'd0, 3'd0);
    step(8'd103, 8'd97, 3'd1);
    step(8'd153, 8'd45, 3'd1);
    step(8'd63, 8'd34, 3'd6);
    step(8'd22, 8'd64, 3'd5);
    step(8'd98, 8'd135, 3'd5);
    step(8'd179, 8'd137, 3'd0);
    step(8'd240, 8'd159, 3'd3);
    step(8'd51, 8'd107, 3'd5);
    step(8'd156, 8'd150, 3'd1);
    step(8'd202, 8'd230, 3'd6);
    step(8'd95, 8'd210, 3'd3);
    step(8'd220, 8'd174, 3'd1);
    step(8'd38, 8'd118, 3'd5);
    step(8'd45, 8'd217, 3'd4);
    step(8'd86, 8'd21, 3'd7);
    step(8'd183, 8'd135, 3'd5);
    step(8'd198, 8'd22, 3'd3);
    step(8'd80, 8'd103, 3'd0);
    step(8'd68, 8'd142, 3'd0);
    step(8'd108, 8'd52, 3'd2);
    step(8'd253, 8'd238, 3'd4);
    step(8'd20, 8'd118, 3'd4);
    step(8'd230, 8'd50, 3'd4);
    step(8'd118, 8'd250, 3'd0);
    step(8'd91, 8'd33, 3'd1);
    step(8'd243, 8'd235, 3'd5);
    step(8'd41, 8'd191, 3'd6);
    step(8'd113, 8'd152, 3'd7);
    step(8'd251, 8'd45, 3'd7);
    step(8'd128, 8'd169, 3'd1);
    step(8'd9, 8'd28, 3'd0);
    step(8'd43, 8'd121, 3'd5);
    step(8'd209, 8'd107, 3'd0);
    step(8'd239, 8'd108, 3'd5);
    step(8'd22, 8'd36, 3'd2);
    step(8'd158, 8'd1, 3'd3);
    step(8'd84, 8'd34, 3'd4);
    step(8'd103, 8'd51, 3'd7);
    step(8'd201, 8'd249, 3'd0);

    $fclose(fd);
    $finish;
  end
endmodule
