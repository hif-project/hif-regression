// Deliberately drives only unequal operand pairs. That choice is what makes
// `eq` stuck-at-0 unobservable here - eq is already 0 on every vector - while
// leaving lt and gt fully exercised in both directions.
`timescale 1ns/1ps
module comparator_tb;
  reg [3:0] a, b;
  wire eq, lt, gt;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  comparator dut (
    .a(a), .b(b), .eq(eq), .lt(lt), .gt(gt)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,b,eq,lt,gt");
    for (i = 0; i < 4; i = i + 1) begin
      case (i)
        0: begin a = 4'd2; b = 4'd5; end
        1: begin a = 4'd7; b = 4'd1; end
        2: begin a = 4'd1; b = 4'd6; end
        default: begin a = 4'd6; b = 4'd2; end
      endcase
      #5;
      $fdisplay(fd, "%0t,%0d,%0d,%b,%b,%b", $time, a, b, eq, lt, gt);
    end
    $fclose(fd);
    $finish;
  end
endmodule
