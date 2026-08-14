// Samples either side of every delay boundary, and records $time with each
// sample, so the trace states when each output moved and not merely what it
// settled to.
//
// The sample points are chosen so that a design which ignored the delay, and a
// design which applied it to the whole process, both produce a *different*
// trace from this one:
//
//   - 1 unit after a/b rise: t has not arrived yet;
//   - 3 units after: it has;
//   - 1 unit after c alone rises: y has already moved, because c does not go
//     through the delayed net.
`timescale 1ns/1ps
module assign_delay_tb;
  reg a, b, c;
  wire y, z;
  integer mut;
  integer fd;
  reg [4095:0] tracefile;

  assign_delay dut (
    .a(a), .b(b), .c(c), .y(y), .z(z)
`ifdef MUFFIN_MUT
    , .muffinMutPort(mut)
`endif
  );

  task sample;
    input [8*16:1] label;
    begin
      $fdisplay(fd, "%0s,%0t,%b,%b,%b,%b,%b", label, $time, a, b, c, y, z);
    end
  endtask

  initial begin
    if (!$value$plusargs("mut=%d", mut)) mut = 0;
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "label,time,a,b,c,y,z");

    a = 0; b = 0; c = 0;
    #10 sample("settled");

    // t rises 2 units from here.
    a = 1; b = 1;
    #1 sample("ab_rise_plus1");
    #2 sample("ab_rise_plus3");

    // c does not feed the delayed net, so y must follow it at once.
    #5 c = 1;
    #1 sample("c_rise_plus1");

    // t falls 2 units from here.
    #5 a = 0;
    #1 sample("a_fall_plus1");
    #3 sample("a_fall_plus4");

    $fclose(fd);
    $finish;
  end
endmodule
