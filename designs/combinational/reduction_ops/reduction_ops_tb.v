// Patterns chosen so every output varies across the trace: all-zero, all-one,
// both nibble halves, a single set bit (the only odd-parity vector), and an
// alternating pattern.
`timescale 1ns/1ps
module reduction_ops_tb;
  reg [7:0] d;
  wire all_ones, any_one, parity;
  wire [7:0] masked;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  reduction_ops dut (
    .d(d), .all_ones(all_ones), .any_one(any_one), .parity(parity), .masked(masked)
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
    $fdisplay(fd, "time,d,all_ones,any_one,parity,masked");
    for (i = 0; i < 6; i = i + 1) begin
      case (i)
        0: d = 8'h00;
        1: d = 8'hFF;
        2: d = 8'hF0;
        3: d = 8'h0F;
        4: d = 8'h01;
        default: d = 8'hA5;
      endcase
      #5;
      $fdisplay(fd, "%0t,%h,%b,%b,%b,%h", $time, d, all_ones, any_one, parity, masked);
    end
    $fclose(fd);
    $finish;
  end
endmodule
