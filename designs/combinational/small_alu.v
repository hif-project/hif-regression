module small_alu(input [3:0] a, input [3:0] b, input [1:0] op, output [3:0] result);
  assign result = (op == 2'b00) ? (a + b) :
                  (op == 2'b01) ? (a - b) :
                  (op == 2'b10) ? (a & b) :
                                  (a | b);
endmodule
