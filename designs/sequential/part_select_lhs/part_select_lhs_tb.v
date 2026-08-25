// Samples on the falling edge, so each row reads what the rising edge before it
// wrote.
//
//   top  bot          q     what the row states
//   101  00011  10100011    both fields carry a mixed pattern
//   111  00000  11100000    all of the top field, none of the bottom
//   000  11111  00011111    the complement: the boundary is at bit 5
//   010  10101  01010101    alternating across the boundary
//   001  00001  00100001    the lowest bit of each field
//
// Rows three and five are where the boundary is pinned: a bound off by one
// puts a 1 on the wrong side of bit 5, and the alternating pattern in row four
// means it cannot land on the same value by accident.
`timescale 1ns/1ps
module part_select_lhs_tb;
  reg clk;
  reg [2:0] top;
  reg [4:0] bot;
  wire [7:0] q;
  integer fd;
  reg [4095:0] tracefile;

  part_select_lhs dut (.clk(clk), .top(top), .bot(bot), .q(q));

  always #5 clk = ~clk;

  task step;
    input [2:0] xtop;
    input [4:0] xbot;
    begin
      top = xtop;
      bot = xbot;
      @(negedge clk);
      $fdisplay(fd, "%0t,%b,%b,%b", $time, top, bot, q);
    end
  endtask

  initial begin
    if (!$value$plusargs("trace=%s", tracefile)) tracefile = "trace.csv";
    fd = $fopen(tracefile, "w");
    if (fd == 0) begin
      $display("ERROR: cannot open trace file");
      $finish;
    end
    $fdisplay(fd, "time,top,bot,q");

    clk = 1'b0;
    step(3'b101, 5'b00011);
    step(3'b111, 5'b00000);
    step(3'b000, 5'b11111);
    step(3'b010, 5'b10101);
    step(3'b001, 5'b00001);

    $fclose(fd);
    $finish;
  end
endmodule
