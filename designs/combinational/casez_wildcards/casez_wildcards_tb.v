// Every request pattern that exercises the priority, plus the two that do not
// rely on a wildcard at all.
//
//   req    grant any   which alternative
//   0001     0    1    ???1, exactly
//   0011     0    1    ???1 wins over ??10 by priority
//   0010     1    1    ??10
//   0110     1    1    ??10, with a higher bit also set
//   0100     2    1    ?100
//   1000     3    1    1000 - the one alternative with no wildcard in it
//   0000     0    0    nothing matches: the default
//   1111     0    1    ???1 again, every bit set
//
// The 1000 row and the 0000 row are the controls: neither needs a wildcard, so
// both survive the defect. Everything else falls through to the default when
// the wildcards stop matching, which is what makes the failure legible as
// "the wildcards are gone" rather than as a scrambled encoder.
`timescale 1ns/1ps
module casez_wildcards_tb;
  reg [3:0] req;
  wire [1:0] grant;
  wire any;
  integer fd;
  reg [4095:0] tracefile;

  casez_wildcards dut (.req(req), .grant(grant), .any(any));

  task step;
    input [3:0] r;
    begin
      req = r;
      #1 $fdisplay(fd, "%0t,%b,%0d,%b", $time, req, grant, any);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,req,grant,any");

    step(4'b0001);
    step(4'b0011);
    step(4'b0010);
    step(4'b0110);
    step(4'b0100);
    step(4'b1000);
    step(4'b0000);
    step(4'b1111);

    $fclose(fd);
    $finish;
  end
endmodule
