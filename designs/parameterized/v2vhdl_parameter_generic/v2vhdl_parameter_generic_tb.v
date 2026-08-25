// Shared by both compiles in the pipeline: the untouched RTL and the same
// design after a full excursion through VHDL and back.
//
// The generic is left at its default; overriding it from an instantiation is a
// different question. `top` is a[W-1], so it moves only if the parameter
// reached the body - a design whose ports were the right width but whose index
// was folded to a wrong constant still fails these rows.
`timescale 1ns/1ps
module v2vhdl_parameter_generic_tb;
  reg [4:0] a;
  wire [4:0] y;
  wire top;
  integer fd;
  reg [4095:0] tracefile;

  v2vhdl_parameter_generic dut (.a(a), .y(y), .top(top));

  task step;
    input [4:0] va;
    begin
      a = va;
      #1 $fdisplay(fd, "%0t,%b,%b,%b", $time, a, y, top);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,a,y,top");

    step(5'b10101);
    step(5'b01010);
    step(5'b11111);
    step(5'b00000);

    $fclose(fd);
    $finish;
  end
endmodule
