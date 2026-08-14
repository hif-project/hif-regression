// Full truth table over a, b and sel, so each gate in the structural mux is
// exercised in both polarities.
`timescale 1ns/1ps
module struct_mux_tb;
  reg a, b, sel;
  wire y;
  integer mut;
  integer fd;
  integer i;
  reg [4095:0] tracefile;

  struct_mux dut (
    .a(a), .b(b), .sel(sel), .y(y)
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
    $fdisplay(fd, "time,a,b,sel,y");
    for (i = 0; i < 8; i = i + 1) begin
      {a, b, sel} = i[2:0];
      #5;
      $fdisplay(fd, "%0t,%b,%b,%b,%b", $time, a, b, sel, y);
    end
    $fclose(fd);
    $finish;
  end
endmodule
